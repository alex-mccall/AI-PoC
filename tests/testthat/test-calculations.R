testthat::test_that("P0-11 all 23 ages match independently specified reporting groups", {
  data <- validate_population(test_input$data, test_references)$data
  mapped <- derive_population_age_groups(data, test_references$age)
  expected <- rep(c("0-4", "5-15", "16-24", "25-64", "65+"), c(2, 4, 3, 8, 6))
  actual <- mapped |>
    dplyr::filter(geography_code == "E06000001", sex_code == "1") |>
    dplyr::arrange(as.integer(source_age_code))
  testthat::expect_equal(actual$age_group, expected)
  testthat::expect_equal(nrow(mapped), nrow(data))
  testthat::expect_equal(sum(mapped$population), sum(data$population))
  data$source_age_code[1] <- "99"
  testthat::expect_error(derive_population_age_groups(data, test_references$age), "unmatched")
  testthat::expect_error(derive_population_age_groups(mapped, test_references$age), "unmapped validated")
})

testthat::test_that("P0-13 and P0-15 aggregation matches all ten reviewed counts", {
  mapped <- derive_population_age_groups(validate_population(test_input$data, test_references)$data, test_references$age)
  keys <- c("sex_code", "sex_label", "age_group", "age_group_order")
  totals <- aggregate_population(mapped, keys, c("geography_code", "sex_code", "source_age_code")) |>
    dplyr::arrange(sex_code, age_group_order)
  expected <- readr::read_csv(file.path(project_root, "tests", "expected", "ons_rm121_2021_results.csv"),
    col_types = readr::cols(sex_code = readr::col_character()), show_col_types = FALSE)
  testthat::expect_equal(totals, expected[c(keys, "population")])
  testthat::expect_equal(sum(totals$population), 59597606)
  duplicate <- dplyr::bind_rows(mapped, mapped[1, ])
  testthat::expect_error(aggregate_population(duplicate, keys, c("geography_code", "sex_code", "source_age_code")), "unique")
})

testthat::test_that("P0-14 denominators and full-precision percentages are correct", {
  expected <- readr::read_csv(file.path(project_root, "tests", "expected", "ons_rm121_2021_results.csv"),
    col_types = readr::cols(sex_code = readr::col_character()), show_col_types = FALSE)
  keys <- c("sex_code", "sex_label", "age_group", "age_group_order")
  result <- calculate_population_percentages(expected[c(keys, "population")], keys, c("sex_code", "sex_label"))
  testthat::expect_equal(unique(result$denominator_population[result$sex_code == "1"]), 30420281)
  testthat::expect_equal(unique(result$denominator_population[result$sex_code == "2"]), 29177325)
  testthat::expect_equal(round(result$percent_of_sex, 1), expected$percent_display)
  testthat::expect_equal(sum(result$percent_of_sex[result$sex_code == "2"]), 100, tolerance = 1e-8)
  testthat::expect_equal(sum(round(result$percent_of_sex[result$sex_code == "2"], 1)), 100.1)
  expected$population[expected$sex_code == "1"] <- 0
  testthat::expect_error(calculate_population_percentages(expected[c(keys, "population")], keys, c("sex_code", "sex_label")), "positive")
})

testthat::test_that("Count totals cannot overflow the agreed exact range", {
  testthat::expect_error(safe_population_total(c(2^53 - 1, 1)), "exact numeric range")
  testthat::expect_error(safe_population_total(c(1, NA_real_)), "finite nonnegative")
})

testthat::test_that("P0-17 outputs use chronological order and provisional labels", {
  expected <- readr::read_csv(file.path(project_root, "tests", "expected", "ons_rm121_2021_results.csv"),
    col_types = readr::cols(sex_code = readr::col_character()), show_col_types = FALSE)
  review <- prepare_population_review(expected[nrow(expected):1, ], test_config)
  testthat::expect_equal(review$age_group[review$sex_code == "1"], c("0-4", "5-15", "16-24", "25-64", "65+"))
  testthat::expect_true(all(review$official_acceptance == "blocked"))
  testthat::expect_true(all(review$result_status == "provisional_review_only"))
  chart <- population_review_chart(review, test_config)
  testthat::expect_match(chart$labels$title, "PROVISIONAL")
  testthat::expect_match(chart$labels$caption, "unequal widths")
  testthat::expect_equal(levels(chart$data$age_group), c("0-4", "5-15", "16-24", "25-64", "65+"))
})

testthat::test_that("Reuse supports additional categories and explicit periods without pooling", {
  small <- tibble::tibble(
    geography_code = c("A", "A", "A", "A"), sex_code = "another_category",
    source_age_code = c("x", "y", "x", "y"), period = c("P1", "P1", "P2", "P2"),
    age_group = c("young", "older", "young", "older"), population = c(1, 3, 2, 2)
  )
  source_keys <- c("geography_code", "sex_code", "source_age_code", "period")
  group_keys <- c("sex_code", "age_group", "period")
  result <- aggregate_population(small, group_keys, source_keys) |>
    calculate_population_percentages(group_keys, c("sex_code", "period"))
  testthat::expect_equal(sort(result$percent_of_sex), c(25, 50, 50, 75))
  totals <- aggregate_population(small, group_keys, source_keys)
  testthat::expect_error(calculate_population_percentages(totals, group_keys, "sex_code"), "retain geography, period")
  testthat::expect_error(aggregate_population(small, setdiff(group_keys, "period"), source_keys), "pool different values")
})

testthat::test_that("Provenance checks detect changes rather than recording stale hashes", {
  fixture <- c(source = file.path(test_scratch, "changed-source.txt"))
  writeLines("first version", fixture)
  initial <- population_file_hashes(fixture)
  testthat::expect_true(assert_population_files_unchanged(fixture, initial))
  writeLines("second version", fixture)
  testthat::expect_error(assert_population_files_unchanged(fixture, initial), "changed during the run")
})
