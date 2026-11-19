# Standalone entry point: no IDE, working-directory change or automatic installs.
population_cli_main <- function(args = commandArgs(trailingOnly = TRUE)) {
  usage <- paste(
    "Usage: Rscript --vanilla scripts/population_cli.R --project-root PATH",
    "[--config config/ons_rm121_2021.yml] [--library PATH]"
  )
  if (identical(args, "--help")) {
    writeLines(usage)
    return(0L)
  }
  allowed <- c("--project-root", "--config", "--library")
  if (!length(args) || length(args) %% 2L != 0L) {
    message(usage)
    return(2L)
  }
  keys <- args[seq.int(1L, length(args), 2L)]
  values <- args[seq.int(2L, length(args), 2L)]
  if (anyDuplicated(keys) || !all(keys %in% allowed) ||
      !"--project-root" %in% keys || any(!nzchar(values))) {
    message(usage)
    return(2L)
  }
  settings <- stats::setNames(as.list(values), keys)
  tryCatch({
    if (getRversion() < "4.1.0") stop("R 4.1.0 or later is required.", call. = FALSE)
    root <- normalizePath(settings[["--project-root"]], mustWork = TRUE)
    if (!dir.exists(root)) stop("Project root is not a directory.", call. = FALSE)
    if (!is.null(settings[["--library"]])) {
      library_path <- normalizePath(settings[["--library"]], mustWork = TRUE)
      if (!dir.exists(library_path)) stop("Package library is not a directory.", call. = FALSE)
      .libPaths(c(library_path, .libPaths()))
    }
    config_file <- settings[["--config"]]
    if (is.null(config_file)) config_file <- "config/ons_rm121_2021.yml"
    workflow <- new.env(parent = globalenv())
    sys.source(file.path(root, "scripts", "run_population_analysis.R"), envir = workflow)
    result <- workflow$run_population_analysis(root, config_file)
    writeLines(jsonlite::toJSON(list(
      execution_status = "provisional_review_outputs_created", official_acceptance = "blocked",
      run_directory = result$run_directory, csv = result$csv, chart = result$chart
    ), auto_unbox = TRUE))
    0L
  }, error = function(error) {
    message("Population workflow failed: ", conditionMessage(error))
    1L
  })
}

if (sys.nframe() == 0L) quit(status = population_cli_main(), save = "no")
