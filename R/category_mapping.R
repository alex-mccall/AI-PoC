#' Map validated source age categories exactly, retaining the original columns.
#'
#' age_reference must have one row per source code and label. No interpolation,
#' unknown bucket, row loss or multiplication is permitted.
derive_population_age_groups <- function(data, age_reference) {
  keys <- c("source_age_code", "source_age_label")
  required <- c(keys, "age_group", "age_group_order")
  if (!all(c(keys, "population") %in% names(data)) ||
      !all(required %in% names(age_reference)) ||
      any(c("age_group", "age_group_order") %in% names(data))) {
    stop("Age derivation requires unmapped validated data and a complete mapping schema.", call. = FALSE)
  }
  if (anyDuplicated(age_reference$source_age_code) ||
      anyNA(age_reference[required]) || any(!nzchar(age_reference$age_group))) {
    stop("Age mapping must have unique source codes and no missing categories.", call. = FALSE)
  }
  groups <- dplyr::distinct(age_reference, age_group, age_group_order)
  if (!is.numeric(groups$age_group_order) || any(!is.finite(groups$age_group_order)) ||
      any(groups$age_group_order < 1 | groups$age_group_order != floor(groups$age_group_order)) ||
      anyDuplicated(groups$age_group) || anyDuplicated(groups$age_group_order)) {
    stop("Age reporting groups must have unique positive integer ordering.", call. = FALSE)
  }
  unmatched <- dplyr::anti_join(data, age_reference, by = keys)
  if (nrow(unmatched)) {
    population_abort("Age mapping contains unmatched source categories.", population_issue(
      "P0-11", "No exact code-label match in the age mapping.", unmatched$record_id,
      "source_age_code"
    ), data)
  }
  before <- safe_population_total(data$population)
  mapped <- dplyr::left_join(data, age_reference[required], by = keys, relationship = "many-to-one")
  if (nrow(mapped) != nrow(data) || safe_population_total(mapped$population) != before) {
    stop("Age mapping did not preserve records and population.", call. = FALSE)
  }
  mapped
}
