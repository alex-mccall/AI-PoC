testthat::test_that("The headless CLI runs twice in clean processes outside the project", {
  root <- make_population_test_project()
  script <- file.path(root, "scripts", "population_cli.R")
  launch <- function(arguments) callr::rscript(
    script, cmdargs = arguments, wd = test_scratch,
    system_profile = FALSE, user_profile = FALSE,
    env = c(DISPLAY = "", TMPDIR = test_scratch),
    show = FALSE, fail_on_status = FALSE, timeout = 120
  )
  first <- launch(c("--project-root", root))
  testthat::expect_identical(first$status, 0L)
  first_result <- jsonlite::fromJSON(first$stdout)
  testthat::expect_identical(first_result$official_acceptance, "blocked")
  testthat::expect_true(file.exists(first_result$csv))
  testthat::expect_true(file.exists(first_result$chart))
  second <- launch(c("--project-root", root))
  testthat::expect_identical(second$status, 0L)
  second_result <- jsonlite::fromJSON(second$stdout)
  testthat::expect_false(identical(first_result$run_directory, second_result$run_directory))
  testthat::expect_identical(digest::digest(file = first_result$csv, algo = "sha256"),
                             digest::digest(file = second_result$csv, algo = "sha256"))
  invalid <- launch(c("--project-root", root, "--config", "config/missing.yml"))
  testthat::expect_identical(invalid$status, 1L)
  testthat::expect_match(invalid$stderr, "Configuration file does not exist")
  usage <- launch(c("--unknown", root))
  testthat::expect_identical(usage$status, 2L)
})
