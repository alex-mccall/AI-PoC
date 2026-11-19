testthat::test_that("CSV export failures retain a failed manifest and incomplete review only", {
  root <- make_population_test_project()
  workflow <- new.env(parent = globalenv())
  sys.source(file.path(root, "scripts", "run_population_analysis.R"), envir = workflow)
  original_write <- readr::write_csv
  testthat::local_mocked_bindings(write_csv = function(x, file, ...) {
    if (basename(file) == "provisional_population_by_age_sex.csv") stop("Simulated CSV export failure")
    original_write(x, file, ...)
  }, .package = "readr")
  testthat::expect_error(workflow$run_population_analysis(root), "Simulated CSV export failure")
  run <- list.dirs(file.path(root, "outputs"), recursive = FALSE, full.names = TRUE)
  manifest <- jsonlite::read_json(file.path(run, "manifest.json"))
  testthat::expect_identical(manifest$status, "failed")
  testthat::expect_false(dir.exists(file.path(run, "review")))
  testthat::expect_true(dir.exists(file.path(run, "review_incomplete")))
})

testthat::test_that("PNG export failures do not promote a partial CSV to a completed review", {
  root <- make_population_test_project()
  workflow <- new.env(parent = globalenv())
  sys.source(file.path(root, "scripts", "run_population_analysis.R"), envir = workflow)
  testthat::local_mocked_bindings(ggsave = function(...) stop("Simulated PNG export failure"), .package = "ggplot2")
  testthat::expect_error(workflow$run_population_analysis(root), "Simulated PNG export failure")
  run <- list.dirs(file.path(root, "outputs"), recursive = FALSE, full.names = TRUE)
  manifest <- jsonlite::read_json(file.path(run, "manifest.json"))
  testthat::expect_identical(manifest$status, "failed")
  testthat::expect_false(dir.exists(file.path(run, "review")))
  testthat::expect_true(file.exists(file.path(run, "review_incomplete", "provisional_population_by_age_sex.csv")))
})

testthat::test_that("Diagnostic-storage failure does not mask the original validation failure", {
  run <- tempfile("failed-evidence-", tmpdir = test_scratch)
  dir.create(run)
  error <- structure(list(message = "Original validation failure", call = NULL,
                           issues = population_issue("P0-05", "Missing field")),
                     class = c("population_validation_error", "error", "condition"))
  testthat::local_mocked_bindings(write_csv = function(...) stop("Simulated diagnostic-storage failure"), .package = "readr")
  testthat::expect_message(record_population_failure(error, list(status = "started"), run), "Additional error")
  manifest <- jsonlite::read_json(file.path(run, "manifest.json"))
  testthat::expect_identical(manifest$status, "failed")
  testthat::expect_identical(manifest$error, "Original validation failure")
})
