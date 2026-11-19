library(readr)
library(jsonlite)
library(digest)
library(zip)

preservation_hashes <- function(paths) {
  vapply(paths, function(path) digest::digest(file = path, algo = "sha256"), character(1))
}

#' Create scratch work only in an explicitly supplied location outside the project.
preservation_scratch <- function(scratch_directory, project_root = NULL) {
  scratch <- normalizePath(scratch_directory, mustWork = TRUE)
  if (!dir.exists(scratch)) stop("Scratch must be an existing directory.", call. = FALSE)
  if (!is.null(project_root) &&
      (identical(scratch, project_root) || startsWith(scratch, paste0(project_root, "/")))) {
    stop("Preservation scratch must be outside the project.", call. = FALSE)
  }
  work <- tempfile("population-preservation-", tmpdir = scratch)
  if (!dir.create(work)) stop("Cannot create scratch workspace.", call. = FALSE)
  work
}

preservation_safe_paths <- function(paths) {
  !is.na(paths) & nzchar(paths) & !grepl("(^/|^[A-Za-z]:|(^|/)\\.\\.(/|$)|\\\\)", paths)
}

#' Extract a local preservation ZIP and verify its project-payload hashes.
#'
#' Returns a report; does not execute archived code. expected_sha256 should come
#' from a separately trusted checksum, not an untrusted replacement archive.
verify_preservation_archive <- function(archive, scratch_directory, expected_sha256 = NULL) {
  archive <- normalizePath(archive, mustWork = TRUE)
  observed_hash <- unname(preservation_hashes(archive))
  if (!is.null(expected_sha256) && !identical(observed_hash, expected_sha256)) {
    stop("Archive SHA-256 does not match the expected value.", call. = FALSE)
  }
  listing <- zip::zip_list(archive)
  if (!all(preservation_safe_paths(listing$filename))) {
    stop("Archive contains unsafe extraction paths.", call. = FALSE)
  }
  work <- preservation_scratch(scratch_directory)
  zip::unzip(archive, exdir = work)
  checksums <- readr::read_csv(file.path(work, "preservation_metadata", "file_checksums.csv"),
    col_types = readr::cols(relative_path = readr::col_character(), bytes = readr::col_double(),
                           sha256 = readr::col_character()), show_col_types = FALSE)
  if (!identical(names(checksums), c("relative_path", "bytes", "sha256")) ||
      !nrow(checksums) || anyNA(checksums) || anyDuplicated(checksums$relative_path) ||
      !all(preservation_safe_paths(checksums$relative_path))) {
    stop("Embedded checksum manifest is invalid.", call. = FALSE)
  }
  payload <- file.path(work, "project", checksums$relative_path)
  observed_files <- list.files(file.path(work, "project"), recursive = TRUE,
    all.files = TRUE, no.. = TRUE, include.dirs = FALSE)
  if (!setequal(observed_files, checksums$relative_path) || !all(file.exists(payload)) ||
      any(file.info(payload)$size != checksums$bytes) ||
      !identical(unname(preservation_hashes(payload)), checksums$sha256)) {
    stop("Extracted payload does not match its checksum manifest.", call. = FALSE)
  }
  list(status = "passed", checked_utc = format(Sys.time(), tz = "UTC", usetz = TRUE),
       payload_files_verified = nrow(checksums), archive_sha256 = observed_hash,
       expected_archive_hash_checked = !is.null(expected_sha256),
       extraction_directory = work)
}

#' Snapshot relevant project files, including Git-ignored analytical outputs.
#'
#' Excludes previous bundles, Git internals, personal prompts and local libraries.
#' No files are deleted and no Git state is changed. Conversation exports remain
#' pending until the user exports them; file presence is not import verification.
create_preservation_bundle <- function(project_root, scratch_directory) {
  root <- normalizePath(project_root, mustWork = TRUE)
  work <- preservation_scratch(scratch_directory, root)
  top_files <- c(".gitignore", "README.md", "renv.lock", "run_population.R")
  directories <- c("Inputs", "R", "scripts", "config", "reference", "tests", "docs", "outputs")
  selected <- top_files[file.exists(file.path(root, top_files))]
  for (directory in directories) {
    base <- file.path(root, directory)
    if (dir.exists(base)) {
      selected <- c(selected, file.path(directory, list.files(base, recursive = TRUE,
        all.files = TRUE, no.. = TRUE, include.dirs = FALSE)))
    }
  }
  clutter <- basename(selected) %in% c(".DS_Store", "Thumbs.db", ".Rhistory", ".RData") |
    grepl("(^|/)(\\.git|\\.library|\\.Rproj.user|__pycache__)(/|$)", selected)
  excluded_nested <- selected[clutter]
  selected <- sort(unique(selected[!clutter]))
  if (!length(selected) || !all(preservation_safe_paths(selected))) {
    stop("No safe project payload selected.", call. = FALSE)
  }
  suspicious <- grepl("(^\\.env($|\\.)|^\\.Renviron$|^id_(rsa|ed25519)|\\.(pem|key)$)", basename(selected))
  if (any(suspicious)) stop("Potential secret filenames need manual review before archiving.", call. = FALSE)
  originals <- file.path(root, selected)
  resolved <- normalizePath(originals, mustWork = TRUE)
  if (any(!startsWith(resolved, paste0(root, "/")))) {
    stop("Selected paths resolve outside the project; manual review required.", call. = FALSE)
  }
  if (any(nzchar(Sys.readlink(originals)))) stop("Symbolic links require explicit preservation review.", call. = FALSE)
  initial_hashes <- unname(preservation_hashes(originals))
  payload_root <- file.path(work, "project")
  metadata_root <- file.path(work, "preservation_metadata")
  dir.create(payload_root)
  dir.create(metadata_root)
  for (relative in selected) {
    destination <- file.path(payload_root, relative)
    dir.create(dirname(destination), recursive = TRUE, showWarnings = FALSE)
    if (!file.copy(file.path(root, relative), destination, copy.mode = TRUE, copy.date = TRUE)) {
      stop(paste("Could not preserve", relative), call. = FALSE)
    }
  }
  copied <- file.path(payload_root, selected)
  if (!identical(initial_hashes, unname(preservation_hashes(copied))) ||
      !identical(initial_hashes, unname(preservation_hashes(originals)))) {
    stop("Files changed while the preservation snapshot was being copied.", call. = FALSE)
  }
  checksums <- data.frame(relative_path = selected, bytes = file.info(copied)$size,
                          sha256 = initial_hashes, row.names = NULL)
  exports <- selected[startsWith(selected, "docs/conversations/")]
  has_json <- any(grepl("\\.json$", exports, ignore.case = TRUE))
  has_html <- any(grepl("\\.html?$", exports, ignore.case = TRUE))
  git_head <- suppressWarnings(system2("git", c("-C", shQuote(root), "rev-parse", "--verify", "HEAD"),
                                        stdout = TRUE, stderr = FALSE))
  if (!is.null(attr(git_head, "status")) || length(git_head) != 1L) git_head <- NULL
  stamp <- gsub(".", "", format(Sys.time(), "%Y-%m-%dT%H%M%OS6Z", tz = "UTC"), fixed = TRUE)
  bundle_root <- file.path(root, "preservation", "bundles", stamp)
  if (dir.exists(bundle_root)) stop("Dated bundle already exists; do not overwrite it.", call. = FALSE)
  if (!dir.create(bundle_root, recursive = TRUE)) stop("Cannot create bundle directory.", call. = FALSE)
  manifest <- list(
    bundle_id = stamp, created_utc = format(Sys.time(), tz = "UTC", usetz = TRUE),
    project_name = basename(root), payload_files = nrow(checksums), payload_bytes = sum(checksums$bytes),
    git_head = git_head, git_history_included = FALSE,
    conversation_exports = list(json_present = has_json, html_present = has_html,
      status = if (has_json && has_html) "files_present_manual_review_required" else "pending_exports",
      files = exports[grepl("\\.(json|html?|md)$", exports, ignore.case = TRUE) & basename(exports) != "README.md"],
      import_verification = "not_performed_by_bundle_tool"),
    official_acceptance = "blocked", source_provenance = "incomplete_supplied_files_only",
    output_run_directories = if (dir.exists(file.path(root, "outputs"))) list.dirs(file.path(root, "outputs"), recursive = FALSE, full.names = FALSE) else character(),
    excluded_top_level = setdiff(list.files(root, all.files = TRUE, no.. = TRUE), c(top_files, directories)),
    excluded_nested = excluded_nested,
    checksum_scope = "Project payload only; archive hash separately covers embedded metadata",
    privacy = "Private snapshot; paths and conversation material are not redacted",
    analytical_tests = "Not rerun by preservation; recorded evidence retained in outputs",
    tools = list(R = as.character(getRversion()), zip = as.character(utils::packageVersion("zip")),
                 digest = as.character(utils::packageVersion("digest")),
                 readr = as.character(utils::packageVersion("readr")), jsonlite = as.character(utils::packageVersion("jsonlite")))
  )
  readr::write_csv(checksums, file.path(metadata_root, "file_checksums.csv"))
  jsonlite::write_json(manifest, file.path(metadata_root, "bundle_manifest.json"),
    auto_unbox = TRUE, pretty = TRUE, null = "null")
  if (!file.copy(file.path(payload_root, "docs", "preservation.md"), file.path(metadata_root, "README.md"))) {
    stop("Could not include preservation instructions.", call. = FALSE)
  }
  archive <- file.path(bundle_root, paste0(basename(root), "_preservation_", stamp, ".zip"))
  zip::zipr(archive, files = c("project", "preservation_metadata"), root = work, mode = "mirror")
  archive_hash <- unname(preservation_hashes(archive))
  writeLines(paste(archive_hash, basename(archive), sep = "  "), paste0(archive, ".sha256"))
  file.copy(file.path(metadata_root, c("file_checksums.csv", "bundle_manifest.json")), bundle_root)
  verification <- verify_preservation_archive(archive, scratch_directory, archive_hash)
  jsonlite::write_json(verification, file.path(bundle_root, "verification.json"), auto_unbox = TRUE, pretty = TRUE)
  invisible(list(bundle_directory = bundle_root, archive = archive, archive_sha256 = archive_hash,
                 files_preserved = nrow(checksums), verification = verification$status,
                 conversation_exports = manifest$conversation_exports$status))
}
