# Source this whole file in Positron. All settings below are project-relative.
# Only needed when sending lines from an unrelated working directory, rather
# than sourcing the file: set project_root_override inside the local block.
population_run <- NULL
population_run <- local({
  config_file <- "config/ons_rm121_2021.yml"
  project_root_override <- NULL

  if (!is.null(project_root_override)) {
    project_root <- normalizePath(project_root_override, mustWork = TRUE)
  } else {
    # source() exposes its filename; using it avoids changing the working directory.
    source_files <- vapply(sys.frames(), function(frame) {
      path <- get0("ofile", envir = frame, inherits = FALSE)
      if (is.character(path) && length(path) == 1L && !is.na(path)) path else ""
    }, character(1))
    own_file <- source_files[basename(source_files) == "run_population.R"]
    if (length(own_file)) {
      project_root <- dirname(normalizePath(tail(own_file, 1), mustWork = TRUE))
    } else {
      project_root <- normalizePath(getwd(), mustWork = TRUE)
    }
  }
  if (!file.exists(file.path(project_root, "scripts", "run_population_analysis.R")) ||
      !file.exists(file.path(project_root, config_file))) {
    stop("Cannot find the project. Source run_population.R as a whole file, or set project_root_override.", call. = FALSE)
  }
  workflow <- new.env(parent = globalenv())
  sys.source(file.path(project_root, "scripts", "run_population_analysis.R"), envir = workflow)
  run <- workflow$run_population_analysis(project_root, config_file)
  sys.source(file.path(project_root, "R", "presentation.R"), envir = workflow)
  print(workflow$population_review_chart(run$results, run$config))
  run
})
