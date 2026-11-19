#' Hash named files and fail visibly if any change during a run.
population_file_hashes <- function(paths) {
  lapply(paths, function(path) digest::digest(file = path, algo = "sha256"))
}

assert_population_files_unchanged <- function(paths, expected) {
  current <- population_file_hashes(paths)
  if (!identical(current, expected)) {
    stop("Source, configuration, reference or code files changed during the run.", call. = FALSE)
  }
  invisible(TRUE)
}

#' Retain the original error even if storage also fails while saving diagnostics.
#'
#' A failure manifest is attempted first. Storage that is not writable cannot be
#' guaranteed to retain evidence; the command-line caller still returns failure.
record_population_failure <- function(error, manifest, run_path) {
  manifest$status <- "failed"
  manifest$error <- conditionMessage(error)
  manifest$official_acceptance <- "blocked"
  manifest$finished_utc <- format(Sys.time(), tz = "UTC", usetz = TRUE)
  attempt <- function(action) {
    tryCatch(action(), error = function(secondary) {
      message("Additional error saving failed-run evidence: ", conditionMessage(secondary))
      invisible(NULL)
    })
  }
  attempt(function() jsonlite::write_json(manifest, file.path(run_path, "manifest.json"),
    auto_unbox = TRUE, pretty = TRUE, null = "null"))
  if (inherits(error, "population_validation_error")) {
    attempt(function() readr::write_csv(error$issues, file.path(run_path, "validation_issues.csv")))
    if (!is.null(error$raw_data)) {
      attempt(function() saveRDS(error$raw_data, file.path(run_path, "failed_input.rds")))
    }
  }
  # Incomplete exports are retained but never presented as a completed review.
  review <- file.path(run_path, "review")
  if (dir.exists(review)) {
    attempt(function() {
      if (!file.rename(review, file.path(run_path, "review_incomplete"))) {
        stop("Could not mark partial review exports incomplete.", call. = FALSE)
      }
    })
  }
  invisible(manifest)
}
