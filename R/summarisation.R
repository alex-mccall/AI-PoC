#' Sum only finite nonnegative whole counts that remain exactly representable.
safe_population_total <- function(population) {
  if (!is.numeric(population) || any(!is.finite(population)) ||
      any(population < 0 | population != floor(population))) {
    stop("Population must contain finite nonnegative whole counts.", call. = FALSE)
  }
  total <- sum(population)
  if (!is.finite(total) || total > 2^53 - 1) {
    stop("Population total exceeds the exact numeric range.", call. = FALSE)
  }
  total
}

#' Aggregate a validated single-release dataset using explicit grouping keys.
#'
#' observation_keys describe the full source grain. Future period-aware adapters
#' must include period in both the observation keys and retained grouping keys.
aggregate_population <- function(data, group_keys, observation_keys) {
  required <- unique(c(group_keys, observation_keys, "population"))
  if (!length(group_keys) || !length(observation_keys) ||
      !all(required %in% names(data)) || "population" %in% c(group_keys, observation_keys) ||
      anyDuplicated(group_keys) || anyDuplicated(observation_keys) || !nrow(data)) {
    stop("Aggregation requires explicit valid keys and nonempty data.", call. = FALSE)
  }
  if (anyNA(data[unique(c(group_keys, observation_keys))]) ||
      anyDuplicated(data[observation_keys])) {
    stop("Source observation keys must be nonmissing and unique.", call. = FALSE)
  }
  # Known context dimensions may never be silently pooled across their values.
  context_keys <- intersect(c("period", "release_id", "geography_version", "measure",
                              "sex_classification", "age_classification"), names(data))
  for (key in setdiff(context_keys, group_keys)) {
    if (dplyr::n_distinct(data[[key]]) > 1L) {
      stop(paste("Aggregation would pool different values of", key), call. = FALSE)
    }
  }
  before <- safe_population_total(data$population)
  result <- data |>
    dplyr::group_by(dplyr::across(dplyr::all_of(group_keys))) |>
    dplyr::summarise(population = sum(population), .groups = "drop")
  if (safe_population_total(result$population) != before || anyDuplicated(result[group_keys])) {
    stop("Aggregation reconciliation failed.", call. = FALSE)
  }
  result
}

#' Calculate full-precision percentages using explicit denominator dimensions.
#'
#' Denominator keys must include period/context when those define separate totals.
#' No rounding or missing-value removal is performed here.
calculate_population_percentages <- function(totals, group_keys, denominator_keys,
                                             tolerance = 1e-8) {
  if (!length(denominator_keys) || !all(denominator_keys %in% group_keys) ||
      !all(c(group_keys, "population") %in% names(totals)) ||
      anyDuplicated(group_keys) || anyDuplicated(denominator_keys) ||
      anyDuplicated(totals[group_keys]) || anyNA(totals[group_keys]) || !nrow(totals)) {
    stop("Percentage keys must identify unique nonmissing groups and denominator dimensions.", call. = FALSE)
  }
  context_keys <- intersect(c("period", "release_id", "geography_code", "geography_name",
                              "geography_version", "measure", "sex_classification",
                              "age_classification"), group_keys)
  if (!all(context_keys %in% denominator_keys)) {
    stop("Percentage denominators must retain geography, period and classification context.", call. = FALSE)
  }
  if (!is.numeric(tolerance) || length(tolerance) != 1L || !is.finite(tolerance) ||
      tolerance <= 0 || tolerance > 0.001) {
    stop("Invalid percentage tolerance.", call. = FALSE)
  }
  safe_population_total(totals$population)
  denominators <- totals |>
    dplyr::group_by(dplyr::across(dplyr::all_of(denominator_keys))) |>
    dplyr::summarise(denominator_population = sum(population), .groups = "drop")
  if (any(denominators$denominator_population <= 0)) {
    stop("Percentage denominator must be positive.", call. = FALSE)
  }
  result <- totals |>
    dplyr::left_join(denominators, by = denominator_keys, relationship = "many-to-one") |>
    dplyr::mutate(percent_of_sex = 100 * population / denominator_population)
  sums <- result |>
    dplyr::group_by(dplyr::across(dplyr::all_of(denominator_keys))) |>
    dplyr::summarise(percentage_sum = sum(percent_of_sex), .groups = "drop")
  if (any(!is.finite(result$percent_of_sex)) || any(abs(sums$percentage_sum - 100) > tolerance)) {
    stop("Unrounded percentages do not reconcile to 100 within denominator groups.", call. = FALSE)
  }
  result
}
