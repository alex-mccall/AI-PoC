library(readr)
library(renv)

#' Record the installed dependency closure without activating a project library.
#'
#' Run after deliberate dependency changes and rerun the complete test suite.
#' Uses the caller's configured repositories; does not install/update packages.
snapshot_population_environment <- function(project_root) {
  root <- normalizePath(project_root, mustWork = TRUE)
  dependencies <- readr::read_csv(file.path(root, "config", "dependencies.csv"),
    col_types = readr::cols(.default = readr::col_character()), show_col_types = FALSE)
  if (!identical(names(dependencies), c("package", "role")) || !nrow(dependencies) ||
      anyNA(dependencies) || anyDuplicated(dependencies$package) ||
      any(!nzchar(dependencies$package))) {
    stop("Dependency manifest must list unique nonempty package names and roles.", call. = FALSE)
  }
  renv::snapshot(project = root, packages = dependencies$package,
                 lockfile = file.path(root, "renv.lock"), prompt = FALSE)
}
