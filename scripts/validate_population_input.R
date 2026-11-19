# Stage 1 checkpoint only: this does not aggregate or publish population results.
# Source this script, then call run_input_validation() with an explicit project root.
library(readr)
library(dplyr)
library(tidyr)
library(yaml)
library(digest)
library(jsonlite)

#' Run structural checks and save evidence, retaining failed-run diagnostics.
#'
#' Returns validated data invisibly; benchmark and national-coverage checks stay blocked.
run_input_validation <- function(project_root, config_file = "config/ons_rm121_2021.yml") {
  code_files <- c("configuration.R", "ingestion.R", "validation.R", "provenance.R")
  functions <- new.env(parent = globalenv())
  for (file in code_files) sys.source(file.path(project_root, "R", file), envir = functions)
  config <- functions$read_population_config(project_root, config_file)
  output_root <- config$output_directory_path
  dir.create(output_root, recursive = TRUE, showWarnings = FALSE)
  if (!dir.exists(output_root)) stop("Cannot create output directory.", call. = FALSE)
  run_path <- tempfile(paste0(config$dataset_id, "_input_", format(Sys.time(), "%Y%m%dT%H%M%S"), "_"), tmpdir = output_root)
  if (!dir.create(run_path)) stop("Cannot create run directory.", call. = FALSE)
  tracked <- c(config = config$config_path, input = config$input_file_path,
               age_reference = config$age_reference_path, sex_reference = config$sex_reference_path,
               stats::setNames(file.path(config$project_root, "R", code_files), code_files),
               runner = file.path(config$project_root, "scripts", "validate_population_input.R"))
  optional <- c(lockfile = file.path(config$project_root, "renv.lock"),
                dependency_manifest = file.path(config$project_root, "config", "dependencies.csv"))
  tracked <- c(tracked, optional[file.exists(optional)])
  manifest <- list(
    dataset_id = config$dataset_id, stage = "input_validation", status = "started",
    started_utc = format(Sys.time(), tz = "UTC", usetz = TRUE),
    project_root = config$project_root, config = config,
    environment = list(r_version = as.character(getRversion()), platform = R.version$platform,
                       locale = Sys.getlocale(), dependency_lock_recorded = "lockfile" %in% names(tracked)),
    provenance_status = "incomplete_supplied_files_only", official_acceptance = "blocked"
  )
  save_manifest <- function(value = manifest) jsonlite::write_json(value, file.path(run_path, "manifest.json"), auto_unbox = TRUE, pretty = TRUE, null = "null")
  tryCatch({
    manifest$sha256 <- functions$population_file_hashes(tracked)
    if (!identical(manifest$sha256$config, config$config_sha256)) {
      stop("Configuration changed after it was read.", call. = FALSE)
    }
    utils::capture.output(sessionInfo(), file = file.path(run_path, "session_info.txt"))
    save_manifest()
    references <- functions$read_population_references(config)
    imported <- functions$ingest_population(config)
    validated <- functions$validate_population(imported$data, references)
    readr::write_csv(validated$checks, file.path(run_path, "validation_checks.csv"))
    readr::write_csv(validated$accounting, file.path(run_path, "record_accounting.csv"))
    functions$assert_population_files_unchanged(tracked, manifest$sha256)
    manifest$status <- "structural_checks_passed_not_officially_validated"
    manifest$records <- nrow(validated$data)
    manifest$finished_utc <- format(Sys.time(), tz = "UTC", usetz = TRUE)
    save_manifest()
    validated$run_directory <- run_path
    validated$config <- config
    validated$references <- references
    validated$tracked_files <- tracked
    validated$tracked_hashes <- manifest$sha256
    invisible(validated)
  }, error = function(error) {
    functions$record_population_failure(error, manifest, run_path)
    stop(error)
  })
}
