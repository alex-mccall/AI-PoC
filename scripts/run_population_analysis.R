library(readr)
library(dplyr)
library(tidyr)
library(ggplot2)
library(yaml)
library(digest)
library(jsonlite)
library(ragg)

#' Run validated calculations and export provisional CSV/PNG review artefacts.
#'
#' This entry point cannot grant official acceptance. Prior run directories are
#' never overwritten; calculation/export failures mark this run as failed.
run_population_analysis <- function(project_root, config_file = "config/ons_rm121_2021.yml") {
  functions <- new.env(parent = globalenv())
  code_files <- c("configuration.R", "ingestion.R", "validation.R", "category_mapping.R",
                  "summarisation.R", "presentation.R", "provenance.R")
  tracked_code <- c(stats::setNames(file.path(project_root, "R", code_files), code_files),
                    analysis_runner = file.path(project_root, "scripts", "run_population_analysis.R"))
  initial_code_hashes <- lapply(tracked_code, function(path) digest::digest(file = path, algo = "sha256"))
  for (file in code_files) sys.source(file.path(project_root, "R", file), envir = functions)
  checkpoint <- new.env(parent = globalenv())
  sys.source(file.path(project_root, "scripts", "validate_population_input.R"), envir = checkpoint)
  validated <- checkpoint$run_input_validation(project_root, config_file)
  run_path <- validated$run_directory
  manifest_path <- file.path(run_path, "manifest.json")
  manifest <- list(stage = "population_analysis", status = "starting", official_acceptance = "blocked")
  save_manifest <- function(value = manifest) jsonlite::write_json(value, manifest_path, auto_unbox = TRUE, pretty = TRUE, null = "null")
  tryCatch({
    manifest <- jsonlite::read_json(manifest_path, simplifyVector = FALSE)
    manifest$stage <- "population_analysis"
    manifest$status <- "calculations_in_progress"
    save_manifest()
    config <- validated$config
    references <- validated$references
    mapped <- functions$derive_population_age_groups(validated$data, references$age)
    group_keys <- c("sex_code", "sex_label", "age_group", "age_group_order")
    denominator_keys <- c("sex_code", "sex_label")
    totals <- functions$aggregate_population(
      mapped, group_keys, c("geography_code", "sex_code", "source_age_code")
    )
    results <- functions$calculate_population_percentages(
      totals, group_keys, denominator_keys, config$analysis$percentage_tolerance
    )
    if (nrow(results) != nrow(references$sex) * dplyr::n_distinct(references$age$age_group)) {
      stop("Unexpected number of reporting groups.", call. = FALSE)
    }
    # Compare pre-aggregation sex totals with the final denominator table.
    source_totals <- validated$data |>
      dplyr::group_by(sex_code, sex_label) |>
      dplyr::summarise(expected = sum(population), .groups = "drop")
    reconciled <- results |>
      dplyr::distinct(sex_code, sex_label, denominator_population) |>
      dplyr::left_join(source_totals, by = denominator_keys, relationship = "one-to-one")
    if (anyNA(reconciled$expected) || any(reconciled$expected != reconciled$denominator_population)) {
      stop("Within-sex totals changed during processing.", call. = FALSE)
    }
    review <- functions$prepare_population_review(results, config)
    functions$assert_population_files_unchanged(validated$tracked_files, validated$tracked_hashes)
    functions$assert_population_files_unchanged(tracked_code, initial_code_hashes)
    staging_path <- file.path(run_path, "review_incomplete")
    if (!dir.create(staging_path)) stop("Cannot create review-output directory.", call. = FALSE)
    staged_csv <- file.path(staging_path, "provisional_population_by_age_sex.csv")
    staged_png <- file.path(staging_path, "provisional_population_by_age_sex.png")
    readr::write_csv(review, staged_csv)
    ggplot2::ggsave(staged_png, plot = functions$population_review_chart(review, config),
                    device = ragg::agg_png,
                    width = 11, height = 7, units = "in", dpi = 150)
    checks <- dplyr::bind_rows(validated$checks, tibble::tibble(
      check_id = c("P0-11", "P0-13", "P0-14", "P0-17"), status = "pass",
      detail = c("Exact age mapping preserves records and counts", "Overall and within-sex totals reconcile",
                 "Positive denominators and unrounded percentages reconcile", "Reporting order matches approved configuration")
    ))
    readr::write_csv(checks, file.path(run_path, "validation_checks.csv"))
    manifest$status <- "provisional_review_outputs_created_not_officially_validated"
    manifest$official_acceptance <- "blocked"
    manifest$group_keys <- group_keys
    manifest$denominator_keys <- denominator_keys
    manifest$total_population <- functions$safe_population_total(review$population)
    manifest$result_rows <- nrow(review)
    manifest$graphics_device <- "ragg::agg_png"
    manifest$finished_utc <- format(Sys.time(), tz = "UTC", usetz = TRUE)
    functions$assert_population_files_unchanged(validated$tracked_files, validated$tracked_hashes)
    functions$assert_population_files_unchanged(tracked_code, initial_code_hashes)
    manifest$analysis_code_sha256 <- initial_code_hashes
    tracked_outputs <- c(results = staged_csv, chart = staged_png,
                         validation = file.path(run_path, "validation_checks.csv"))
    manifest$output_sha256 <- lapply(tracked_outputs, function(path) digest::digest(file = path, algo = "sha256"))
    review_path <- file.path(run_path, "review")
    if (!file.rename(staging_path, review_path)) stop("Could not complete review export.", call. = FALSE)
    csv_path <- file.path(review_path, basename(staged_csv))
    png_path <- file.path(review_path, basename(staged_png))
    save_manifest()
    invisible(list(results = review, checks = checks, run_directory = run_path,
                   csv = csv_path, chart = png_path, config = config))
  }, error = function(error) {
    functions$record_population_failure(error, manifest, run_path)
    stop(error)
  })
}
