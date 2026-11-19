testthat::test_that("P1-01 failed inputs cannot create review outputs or replace successful runs", {
  fixture_root <- tempfile("workflow-project-", tmpdir = test_scratch)
  dir.create(fixture_root)
  fixture_root <- normalizePath(fixture_root, mustWork = TRUE)
  for (directory in c("R", "scripts", "config", "Inputs", "reference")) {
    dir.create(file.path(fixture_root, directory))
  }
  testthat::expect_true(all(file.copy(list.files(file.path(project_root, "R"), full.names = TRUE),
                                      file.path(fixture_root, "R"))))
  testthat::expect_true(all(file.copy(list.files(file.path(project_root, "scripts"), full.names = TRUE),
                                      file.path(fixture_root, "scripts"))))
  config <- yaml::read_yaml(test_config$config_path, eval.expr = FALSE)
  config$input_file <- "Inputs/source.csv"
  config$age_reference <- "reference/age.csv"
  config$sex_reference <- "reference/sex.csv"
  yaml::write_yaml(config, file.path(fixture_root, "config", "analysis.yml"))
  file.copy(test_config$age_reference_path, file.path(fixture_root, "reference", "age.csv"))
  file.copy(test_config$sex_reference_path, file.path(fixture_root, "reference", "sex.csv"))
  fixture_path <- file.path(fixture_root, "Inputs", "source.csv")
  source_data <- test_input$raw_data
  readr::write_csv(source_data, fixture_path)
  workflow <- new.env(parent = globalenv())
  sys.source(file.path(fixture_root, "scripts", "run_population_analysis.R"), envir = workflow)
  success <- workflow$run_population_analysis(fixture_root, "config/analysis.yml")
  original_output_hash <- digest::digest(file = success$csv, algo = "sha256")
  success_manifest <- jsonlite::read_json(file.path(success$run_directory, "manifest.json"))
  testthat::expect_identical(success_manifest$official_acceptance, "blocked")
  testthat::expect_equal(nrow(success$results), 10L)
  testthat::expect_true(file.exists(success$chart))
  source_data[[unname(test_config$columns["population_raw"])]][1] <- ""
  readr::write_csv(source_data, fixture_path)
  testthat::expect_error(workflow$run_population_analysis(fixture_root, "config/analysis.yml"),
                         "validation failed", class = "population_validation_error")
  run_paths <- list.dirs(file.path(fixture_root, "outputs"), recursive = FALSE, full.names = TRUE)
  failed_path <- setdiff(run_paths, success$run_directory)
  testthat::expect_length(failed_path, 1L)
  failed_manifest <- jsonlite::read_json(file.path(failed_path, "manifest.json"))
  testthat::expect_identical(failed_manifest$status, "failed")
  testthat::expect_false(dir.exists(file.path(failed_path, "review")))
  testthat::expect_true(file.exists(file.path(failed_path, "validation_issues.csv")))
  testthat::expect_identical(digest::digest(file = success$csv, algo = "sha256"), original_output_hash)
  source_data <- test_input$raw_data
  source_data[[unname(test_config$columns["population_raw"])]] <- "0"
  readr::write_csv(source_data, fixture_path)
  testthat::expect_error(workflow$run_population_analysis(fixture_root, "config/analysis.yml"), "denominator must be positive")
  all_paths <- list.dirs(file.path(fixture_root, "outputs"), recursive = FALSE, full.names = TRUE)
  calculation_failure <- setdiff(all_paths, run_paths)
  testthat::expect_length(calculation_failure, 1L)
  calculation_manifest <- jsonlite::read_json(file.path(calculation_failure, "manifest.json"))
  testthat::expect_identical(calculation_manifest$status, "failed")
  testthat::expect_false(dir.exists(file.path(calculation_failure, "review")))
  testthat::expect_identical(digest::digest(file = success$csv, algo = "sha256"), original_output_hash)
})
