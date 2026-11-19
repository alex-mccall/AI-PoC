#' Validate observations without deleting, deduplicating or imputing records.
#'
#' On failure, raises population_validation_error with issues and original data.
#' On success, returns parsed data, record accounting and explicitly blocked checks.
validate_population <- function(data, references) {
  issues <- population_issue(character(), character(), integer(), character())
  add_issue <- function(check_id, detail, record_id = NA_integer_, field = NA_character_) {
    issues <<- dplyr::bind_rows(issues, population_issue(check_id, detail, record_id, field))
  }
  fields <- c("geography_code", "geography_name", "sex_code", "sex_label",
              "source_age_code", "source_age_label", "population_raw")
  if (!all(c("record_id", fields) %in% names(data))) {
    stop("Validator requires canonical input from ingest_population().", call. = FALSE)
  }
  if (!nrow(data)) add_issue("P0-05", "Input contains no data records.")
  for (field in fields) {
    bad <- which(is.na(data[[field]]) | trimws(data[[field]]) == "")
    if (length(bad)) add_issue("P0-05", "Required field is missing or blank.", data$record_id[bad], field)
  }
  lexical_count <- !is.na(data$population_raw) & grepl("^[0-9]+$", data$population_raw)
  population <- suppressWarnings(readr::parse_double(data$population_raw, na = character()))
  # Decimal integers above 2^53 - 1 are not safely representable as exact doubles.
  bad_count <- which(!lexical_count | !is.finite(population) |
                     population < 0 | population > 2^53 - 1 | population != floor(population))
  if (length(bad_count)) add_issue(
    "P0-06", "Count must be an unsigned decimal integer within the exact numeric range.",
    data$record_id[bad_count], "population_raw"
  )
  for (kind in c("sex", "age")) {
    keys <- if (kind == "sex") c("sex_code", "sex_label") else c("source_age_code", "source_age_label")
    bad <- dplyr::anti_join(data, references[[kind]], by = keys)
    if (nrow(bad)) add_issue("P0-07", "Code or code-label pair is not in the reference.", bad$record_id, keys[1])
  }
  keys <- c("geography_code", "sex_code", "source_age_code")
  duplicate <- duplicated(data[keys]) | duplicated(data[keys], fromLast = TRUE)
  if (any(duplicate)) add_issue("P0-08", "Duplicate authority-sex-age key.", data$record_id[duplicate])
  names_per_code <- data |>
    dplyr::distinct(geography_code, geography_name) |>
    dplyr::count(geography_code, name = "labels") |>
    dplyr::filter(labels != 1)
  if (nrow(names_per_code)) {
    bad <- data$geography_code %in% names_per_code$geography_code
    add_issue("P0-07", "Geography code has inconsistent labels.", data$record_id[bad], "geography_name")
  }
  expected <- tidyr::expand_grid(
    geography_code = unique(data$geography_code), sex_code = references$sex$sex_code,
    source_age_code = references$age$source_age_code
  )
  missing_keys <- dplyr::anti_join(expected, data, by = keys)
  if (nrow(missing_keys)) add_issue("P0-10", paste(nrow(missing_keys), "expected category combinations are absent."))
  if (nrow(issues)) population_abort("Population validation failed; no observations were silently removed.", issues, data)
  data$population <- population
  list(
    data = data,
    checks = tibble::tibble(
      check_id = c("P0-05", "P0-06", "P0-07", "P0-08", "P0-10", "P0-12", "P0-09", "P0-16"),
      status = c(rep("pass", 6), "blocked", "blocked"),
      detail = c("Required fields present", "Valid nonnegative exact integer counts",
                 "Codes and labels agree with supplied-file references", "Unique observation keys",
                 "Complete grid within observed geographies only", "All records retained",
                 "No authoritative geography list supplied", "No official benchmark supplied")
    ),
    accounting = tibble::tibble(imported = nrow(data), accepted = nrow(data), rejected = 0L)
  )
}
