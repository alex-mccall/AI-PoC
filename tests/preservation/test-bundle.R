# Run separately with testthat::test_file("tests/preservation/test-bundle.R").
project_root <- normalizePath(file.path("..", ".."), mustWork = TRUE)
scratch <- Sys.getenv("PA_TEST_SCRATCH")
if (!nzchar(scratch) || !dir.exists(scratch)) stop("Set PA_TEST_SCRATCH to an existing scratch directory.")
source(file.path(project_root, "scripts", "create_preservation_bundle.R"), local = TRUE)

make_preservation_fixture <- function() {
  root <- tempfile("preservation project ", tmpdir = scratch)
  dir.create(root)
  for (directory in c("docs/conversations", "outputs/run", "config")) {
    dir.create(file.path(root, directory), recursive = TRUE)
  }
  for (file in c("README.md", "run_population.R", "renv.lock", ".gitignore",
                  "docs/preservation.md", "docs/conversations/README.md", "outputs/run/counts.csv")) {
    writeLines("Synthetic preservation-test fixture", file.path(root, file))
  }
  writeLines("Unrelated fixture", file.path(root, "Useful prompts.txt"))
  writeLines("OS fixture", file.path(root, ".DS_Store"))
  normalizePath(root, mustWork = TRUE)
}

testthat::test_that("Bundle roundtrip preserves outputs, records omissions and reports export presence", {
  root <- make_preservation_fixture()
  first <- create_preservation_bundle(root, scratch)
  testthat::expect_identical(first$verification, "passed")
  testthat::expect_identical(first$conversation_exports, "pending_exports")
  checks <- readr::read_csv(file.path(first$bundle_directory, "file_checksums.csv"), show_col_types = FALSE)
  testthat::expect_true("outputs/run/counts.csv" %in% checks$relative_path)
  testthat::expect_false(any(c("Useful prompts.txt", ".DS_Store") %in% checks$relative_path))
  verified <- verify_preservation_archive(first$archive, scratch, first$archive_sha256)
  testthat::expect_equal(verified$payload_files_verified, nrow(checks))
  writeLines('{"fixture":true}', file.path(root, "docs", "conversations", "fixture.json"))
  writeLines("<html>Fixture only</html>", file.path(root, "docs", "conversations", "fixture.html"))
  second <- create_preservation_bundle(root, scratch)
  testthat::expect_identical(second$conversation_exports, "files_present_manual_review_required")
  testthat::expect_false(identical(first$bundle_directory, second$bundle_directory))
  second_checks <- readr::read_csv(file.path(second$bundle_directory, "file_checksums.csv"), show_col_types = FALSE)
  testthat::expect_false(any(startsWith(second_checks$relative_path, "preservation/")))
})

testthat::test_that("Verification rejects a wrong archive hash and changed project payload", {
  root <- make_preservation_fixture()
  bundle <- create_preservation_bundle(root, scratch)
  testthat::expect_error(verify_preservation_archive(bundle$archive, scratch, paste(rep("0", 64), collapse = "")), "does not match")
  unpack <- preservation_scratch(scratch)
  zip::unzip(bundle$archive, exdir = unpack)
  writeLines("Changed README", file.path(unpack, "project", "README.md"))
  changed <- file.path(preservation_scratch(scratch), "changed.zip")
  zip::zipr(changed, c("project", "preservation_metadata"), root = unpack, mode = "mirror")
  testthat::expect_error(verify_preservation_archive(changed, scratch), "does not match its checksum")
})

testthat::test_that("Unsafe paths, source-local scratch and secret filenames are rejected", {
  testthat::expect_identical(preservation_safe_paths(c("../escape", "/absolute", "C:/absolute", "x\\y", "safe/file")),
                             c(FALSE, FALSE, FALSE, FALSE, TRUE))
  root <- make_preservation_fixture()
  testthat::expect_error(create_preservation_bundle(root, root), "outside the project")
  writeLines("Synthetic fixture, not a credential", file.path(root, "config", ".env"))
  testthat::expect_error(create_preservation_bundle(root, scratch), "Potential secret filenames")
})
