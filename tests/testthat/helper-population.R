# Run from the project root with testthat::test_dir("tests/testthat").
test_scratch <- Sys.getenv("PA_TEST_SCRATCH")
if (!nzchar(test_scratch) || !dir.exists(test_scratch)) {
  stop("Set PA_TEST_SCRATCH to an existing writable scratch directory before running tests.")
}
project_root <- normalizePath(file.path("..", ".."), mustWork = TRUE)
for (file in c("configuration.R", "ingestion.R", "validation.R", "category_mapping.R",
               "summarisation.R", "presentation.R", "provenance.R")) {
  source(file.path(project_root, "R", file), local = TRUE)
}
test_config <- read_population_config(project_root, "config/ons_rm121_2021.yml")
test_references <- read_population_references(test_config)
test_input <- ingest_population(test_config)

expect_population_issue <- function(data, check_id) {
  error <- tryCatch(validate_population(data, test_references), population_validation_error = identity)
  testthat::expect_s3_class(error, "population_validation_error")
  testthat::expect_true(check_id %in% error$issues$check_id)
  testthat::expect_equal(nrow(error$raw_data), nrow(data))
}

# Keep generated projects and outputs away from the real source tree.
make_population_test_project <- function() {
  root <- tempfile("population project ", tmpdir = test_scratch)
  dir.create(root)
  root <- normalizePath(root, mustWork = TRUE)
  for (directory in c("R", "scripts", "config", "reference")) {
    if (!file.copy(file.path(project_root, directory), root, recursive = TRUE)) {
      stop("Could not copy test project.")
    }
  }
  for (file in c("run_population.R", "renv.lock")) {
    if (file.exists(file.path(project_root, file))) file.copy(file.path(project_root, file), file.path(root, file))
  }
  input_path <- file.path(root, test_config$input_file)
  dir.create(dirname(input_path), recursive = TRUE)
  readr::write_csv(test_input$raw_data, input_path)
  root
}
