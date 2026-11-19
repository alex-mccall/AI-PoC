#' Raise a validation error carrying diagnostics for audit or automated tests.
population_abort <- function(message, issues, raw_data = NULL) {
  stop(structure(
    list(message = message, call = NULL, issues = issues, raw_data = raw_data),
    class = c("population_validation_error", "error", "condition")
  ))
}

population_issue <- function(check_id, detail, record_id = NA_integer_, field = NA_character_) {
  tibble::tibble(check_id = check_id, record_id = as.integer(record_id), field = field, detail = detail)
}

#' Read delimited text without guessing types, trimming values or discarding blanks.
#'
#' All fields remain character; malformed records carry their parser diagnostics.
read_population_text <- function(path, encoding = "UTF-8", delimiter = ",") {
  if (!file.exists(path)) stop(paste("Input does not exist:", path), call. = FALSE)
  data <- suppressWarnings(readr::read_delim(
    path, delim = delimiter, quote = '"', escape_double = TRUE,
    col_types = readr::cols(.default = readr::col_character()),
    locale = readr::locale(encoding = encoding), na = character(), trim_ws = FALSE,
    name_repair = "minimal", skip_empty_rows = FALSE,
    show_col_types = FALSE, progress = FALSE, lazy = FALSE
  ))
  parse_issues <- readr::problems(data)
  if (nrow(parse_issues)) {
    population_abort("Delimited-file parsing failed.", population_issue(
      "P0-04", paste0("Parser row ", parse_issues$row, ": expected ",
                       parse_issues$expected, "; actual ", parse_issues$actual),
      field = as.character(parse_issues$col)
    ), data)
  }
  data
}

#' Import validated headers and preserve source field text.
#'
#' record_id is the logical data-record number, not necessarily the physical line.
ingest_population <- function(config) {
  raw <- read_population_text(config$input_file_path, config$encoding, config$delimiter)
  headers <- names(raw)
  expected <- unname(config$columns)
  if (anyDuplicated(headers) || !setequal(headers, expected)) {
    population_abort("Input headers do not match the configured schema.", population_issue(
      "P0-02", paste0("Missing: ", paste(setdiff(expected, headers), collapse = "; "),
                      ". Unexpected: ", paste(setdiff(headers, expected), collapse = "; "),
                      ". Duplicate headers: ", anyDuplicated(headers) > 0)
    ), raw)
  }
  canonical <- raw[unname(config$columns)]
  names(canonical) <- names(config$columns)
  canonical <- tibble::add_column(canonical, record_id = seq_len(nrow(canonical)), .before = 1)
  list(raw_data = raw, data = canonical)
}

#' Read and validate source-category reference tables before using them as rules.
read_population_references <- function(config) {
  age <- read_population_text(config$age_reference_path)
  sex <- read_population_text(config$sex_reference_path)
  expected_age <- c("source_age_code", "source_age_label", "age_group", "age_group_order")
  if (!setequal(names(age), expected_age) || anyDuplicated(names(age)) ||
      !setequal(names(sex), c("sex_code", "sex_label")) || anyDuplicated(names(sex))) {
    stop("Category reference headers are invalid.", call. = FALSE)
  }
  for (reference in list(age, sex)) {
    if (!nrow(reference) || any(vapply(reference, function(x) any(is.na(x) | trimws(x) == ""), logical(1)))) {
      stop("Category references must be nonempty without missing fields.", call. = FALSE)
    }
  }
  if (anyDuplicated(age$source_age_code) || anyDuplicated(sex$sex_code) ||
      anyDuplicated(age$source_age_label) || anyDuplicated(sex$sex_label)) {
    stop("Category reference codes and labels must be unique.", call. = FALSE)
  }
  if (any(!grepl("^[1-9][0-9]*$", age$age_group_order))) {
    stop("Age-group order must contain positive integers.", call. = FALSE)
  }
  age$age_group_order <- readr::parse_double(age$age_group_order)
  groups <- dplyr::distinct(age, age_group, age_group_order)
  if (any(!is.finite(age$age_group_order)) || anyDuplicated(groups$age_group) ||
      anyDuplicated(groups$age_group_order)) {
    stop("Each age group must have a unique finite reporting order.", call. = FALSE)
  }
  groups <- dplyr::arrange(groups, age_group_order)
  if (!identical(groups$age_group, unname(unlist(config$analysis$age_group_order)))) {
    stop("Age mapping order does not match the approved configuration.", call. = FALSE)
  }
  list(age = age, sex = sex)
}
