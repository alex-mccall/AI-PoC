#' Resolve a project-relative path without depending on the working directory.
#'
#' Absolute paths and parent traversal are rejected to keep configuration portable.
population_path <- function(project_root, relative_path) {
  if (!is.character(relative_path) || length(relative_path) != 1L ||
      is.na(relative_path) || !nzchar(relative_path) ||
      grepl("^(~|/|[A-Za-z]:)|(^|[/\\\\])\\.\\.([/\\\\]|$)", relative_path)) {
    stop("Paths must be nonempty project-relative paths without '..'.", call. = FALSE)
  }
  root <- normalizePath(project_root, mustWork = TRUE)
  path <- normalizePath(file.path(root, relative_path), mustWork = FALSE)
  if (!startsWith(path, paste0(root, .Platform$file.sep))) {
    stop("Configured path escapes the project root.", call. = FALSE)
  }
  path
}

#' Load a source contract; unknown provenance remains unknown.
#'
#' Returns configuration with resolved paths. Does not create output directories.
read_population_config <- function(project_root, config_file) {
  config_path <- population_path(project_root, config_file)
  if (!file.exists(config_path)) stop("Configuration file does not exist.", call. = FALSE)
  config_hash <- digest::digest(file = config_path, algo = "sha256")
  config <- yaml::read_yaml(config_path, eval.expr = FALSE)
  if (!identical(config_hash, digest::digest(file = config_path, algo = "sha256"))) {
    stop("Configuration changed while it was being read.", call. = FALSE)
  }
  required <- c("dataset_id", "input_file", "output_directory", "encoding", "delimiter",
                "age_reference", "sex_reference", "columns", "context", "analysis", "acceptance")
  if (!is.list(config) || !all(required %in% names(config))) {
    stop("Configuration is missing required settings.", call. = FALSE)
  }
  for (field in c("dataset_id", "encoding", "delimiter")) {
    if (!is.character(config[[field]]) || length(config[[field]]) != 1L ||
        is.na(config[[field]]) || !nzchar(config[[field]])) {
      stop(paste("Invalid configuration setting:", field), call. = FALSE)
    }
  }
  if (!grepl("^[A-Za-z0-9_-]+$", config$dataset_id) || nchar(config$delimiter) != 1L) {
    stop("Invalid dataset identifier or delimiter.", call. = FALSE)
  }
  expected <- c("geography_code", "geography_name", "sex_code", "sex_label",
                "source_age_code", "source_age_label", "population_raw")
  columns <- unlist(config$columns, use.names = TRUE)
  if (!identical(sort(names(columns)), sort(expected)) || !is.character(columns) ||
      anyNA(columns) || any(!nzchar(trimws(columns))) || anyDuplicated(columns)) {
    stop("Column mapping must define the seven unique canonical fields.", call. = FALSE)
  }
  if (!isTRUE(config$analysis$complete_category_grid) ||
      !identical(config$analysis$percentage_denominator, "within_sex")) {
    stop("This implementation requires a complete grid and within-sex percentages.", call. = FALSE)
  }
  tolerance <- config$analysis$percentage_tolerance
  if (!is.numeric(tolerance) || length(tolerance) != 1L || !is.finite(tolerance) ||
      tolerance <= 0 || tolerance > 0.001) {
    stop("A positive percentage tolerance of at most 0.001 percentage points is required.", call. = FALSE)
  }
  if (!identical(config$analysis$output_policy, "provisional_review_only") ||
      !setequal(unlist(config$analysis$outputs), c("csv", "png"))) {
    stop("Only the agreed provisional CSV and PNG output policy is implemented.", call. = FALSE)
  }
  age_order <- unlist(config$analysis$age_group_order)
  if (!is.character(age_order) || !length(age_order) || anyNA(age_order) ||
      any(!nzchar(age_order)) || anyDuplicated(age_order)) {
    stop("Configure a unique ordered list of reporting age groups.", call. = FALSE)
  }
  for (field in c("geography_label", "period_label")) {
    value <- config$context[[field]]
    if (!is.character(value) || length(value) != 1L || is.na(value) || !nzchar(value)) {
      stop(paste("Missing presentation context:", field), call. = FALSE)
    }
  }
  config$columns <- columns
  config$project_root <- normalizePath(project_root, mustWork = TRUE)
  config$config_path <- config_path
  config$config_sha256 <- config_hash
  for (field in c("input_file", "output_directory", "age_reference", "sex_reference")) {
    config[[paste0(field, "_path")]] <- population_path(project_root, config[[field]])
  }
  for (field in c("input_file_path", "age_reference_path", "sex_reference_path")) {
    if (!file.exists(config[[field]]) || dir.exists(config[[field]])) {
      stop(paste("Required file does not exist:", config[[field]]), call. = FALSE)
    }
  }
  input_directory <- dirname(config$input_file_path)
  if (identical(config$output_directory_path, input_directory) ||
      startsWith(config$output_directory_path, paste0(input_directory, .Platform$file.sep))) {
    stop("Outputs must not be written into the source-data directory.", call. = FALSE)
  }
  config
}
