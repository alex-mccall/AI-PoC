testthat::test_that("P0-01 configuration is portable and protects the source directory", {
  testthat::expect_true(file.exists(test_config$input_file_path))
  testthat::expect_error(population_path(project_root, "../outside"), "project-relative")
  testthat::expect_error(population_path(project_root, "/absolute/path"), "project-relative")
})

testthat::test_that("P0-02 and P0-03 headers map by name, not position", {
  raw <- test_input$raw_data
  testthat::expect_equal(ncol(raw), 7L)
  fixture <- file.path(Sys.getenv("PA_TEST_SCRATCH"), "reordered.csv")
  readr::write_csv(raw[rev(names(raw))], fixture)
  config <- test_config
  config$input_file_path <- fixture
  testthat::expect_equal(ingest_population(config)$data, test_input$data)
  names(raw)[1] <- "unexpected_header"
  readr::write_csv(raw, fixture)
  testthat::expect_error(ingest_population(config), "headers do not match", class = "population_validation_error")
  raw <- test_input$raw_data
  raw$extra_column <- "unexpected"
  readr::write_csv(raw, fixture)
  testthat::expect_error(ingest_population(config), "headers do not match", class = "population_validation_error")
  raw <- test_input$raw_data[-1]
  readr::write_csv(raw, fixture)
  testthat::expect_error(ingest_population(config), "headers do not match", class = "population_validation_error")
  raw <- test_input$raw_data
  names(raw)[2] <- names(raw)[1]
  readr::write_csv(raw, fixture)
  testthat::expect_error(ingest_population(config), "headers do not match", class = "population_validation_error")
})

testthat::test_that("P0-04 quoted commas are preserved and short records fail", {
  testthat::expect_true("Bournemouth, Christchurch and Poole" %in% test_input$data$geography_name)
  fixture <- file.path(Sys.getenv("PA_TEST_SCRATCH"), "short.csv")
  writeLines(c("a,b,c", "1,2"), fixture)
  testthat::expect_error(read_population_text(fixture), "parsing failed", class = "population_validation_error")
  writeLines(c("a,b,c", '1,"unterminated,3'), fixture)
  testthat::expect_error(read_population_text(fixture), "parsing failed", class = "population_validation_error")
})

testthat::test_that("P0-05 missing values fail before any deletion", {
  for (field in names(test_config$columns)) {
    data <- test_input$data
    data[[field]][1] <- ""
    expect_population_issue(data, "P0-05")
  }
  expect_population_issue(test_input$data[0, ], "P0-05")
  data <- test_input$data
  data$geography_name[1] <- "   "
  expect_population_issue(data, "P0-05")
})

testthat::test_that("P0-06 zero is valid and invalid or inexact counts fail", {
  data <- test_input$data
  data$population_raw[1] <- "0"
  testthat::expect_equal(validate_population(data, test_references)$data$population[1], 0)
  for (value in c(NA_character_, "", "NA", "1,000", "1x", "-1", "1.5", "1e3", "Inf", "NaN", "9007199254740992")) {
    data$population_raw[1] <- value
    expect_population_issue(data, "P0-06")
  }
})

testthat::test_that("P0-07 invalid codes and mismatched labels fail", {
  for (field in c("sex_code", "sex_label", "source_age_code", "source_age_label")) {
    data <- test_input$data
    data[[field]][1] <- "unrecognised"
    expect_population_issue(data, "P0-07")
  }
  data <- test_input$data
  data$geography_name[1] <- "Conflicting authority label"
  expect_population_issue(data, "P0-07")
})

testthat::test_that("Reference mapping rejects duplicate codes and ambiguous reporting order", {
  fixture <- file.path(Sys.getenv("PA_TEST_SCRATCH"), "age-reference.csv")
  config <- test_config
  config$age_reference_path <- fixture
  reference <- test_references$age
  readr::write_csv(dplyr::bind_rows(reference, reference[1, ]), fixture)
  testthat::expect_error(read_population_references(config), "codes and labels must be unique")
  reference$age_group_order[1] <- 99
  readr::write_csv(reference, fixture)
  testthat::expect_error(read_population_references(config), "unique finite reporting order")
  reference <- test_references$age
  reference$age_group_order[reference$age_group == "0-4"] <- 5
  reference$age_group_order[reference$age_group == "65+"] <- 1
  readr::write_csv(reference, fixture)
  testthat::expect_error(read_population_references(config), "approved configuration")
})

testthat::test_that("P0-08 duplicates and P0-10 incomplete grids fail", {
  expect_population_issue(dplyr::bind_rows(test_input$data, test_input$data[1, ]), "P0-08")
  expect_population_issue(test_input$data[-1, ], "P0-10")
})

testthat::test_that("P0-12 and P0-15 baseline is intact but official acceptance stays blocked", {
  validated <- validate_population(test_input$data, test_references)
  testthat::expect_equal(nrow(validated$data), 15226L)
  testthat::expect_equal(dplyr::n_distinct(validated$data$geography_code), 331L)
  testthat::expect_equal(validated$accounting$rejected, 0L)
  testthat::expect_equal(sum(validated$data$population), 59597606)
  testthat::expect_equal(digest::digest(file = test_config$input_file_path, algo = "sha256"),
                         "b866e4c27549b70544e697532a217be989560de76689937ec1a88712f9582dd6")
  testthat::expect_equal(sum(validated$checks$status == "blocked"), 2L)
})
