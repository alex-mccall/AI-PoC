# Local and Red Hat–based server execution

## One workflow, two entry points

For interactive Positron use, source the root-level `run_population.R`. It detects
its own location, runs the workflow, shows the chart, and leaves `population_run`
with results, validation checks and output paths. Source the whole file rather
than sending an arbitrary subset of its lines. No personal absolute path is built
into it. Configuration stays in `config/ons_rm121_2021.yml`.

For a server, run the command-line entry point. Example paths below are
placeholders, not an existing deployment:

```sh
Rscript --vanilla /srv/population/scripts/population_cli.R \
  --project-root /srv/population \
  --config config/ons_rm121_2021.yml \
  --library /srv/population/.library
```

The optional library path is preferred ahead of existing libraries; it is not
proof of isolation or a version check. Validate the installed environment against
the lockfile. Exit status 0 means a provisional run completed, 1 indicates a
runtime failure, and 2 indicates invalid command-line arguments. JSON success
output goes to stdout; errors go to stderr. Official acceptance remains blocked.

PNG export explicitly uses `ragg::agg_png`; no X server or display is required.
Titles and notes are wrapped for interactive viewing. Fonts/rendering may differ
across systems: compare numerical data, inspect graphics, and do not require
cross-platform PNG checksum equality.

## Dependency restoration

`renv.lock` records R 4.5.3 and the dependency closure used here. The declared
minimum R version is 4.1, based on the source features and package requirements;
other R versions are not verified merely because installation is possible. Start
with the recorded R version where practical. Test any alternative version before
operational acceptance, and retain its environment evidence.

No `.Rprofile` or automatic project activation was installed. The lockfile was
created without replacing the current library. On a deployment machine, an
administrator/operator should install renv through the approved repository, then
restore into a dedicated writable library. For example, in that machine's R:

```r
dir.create("/srv/population/.library", recursive = TRUE, showWarnings = FALSE)
renv::restore(
  project = "/srv/population",
  library = "/srv/population/.library",
  prompt = FALSE
)
renv::status(project = "/srv/population", library = "/srv/population/.library")
```

Repository settings, credentials and network access must follow the server's
policy. Review the repository recorded in the lockfile for compatibility with the
server; preserve package versions if an approved mirror is substituted. A restore
may need historical source packages or compatible binaries. Do not copy the Mac
package library to Linux. Refresh the lockfile only after deliberate dependency
changes, then rerun tests; `scripts/snapshot_environment.R` provides that action.

## Server prerequisites still to confirm

The exact Red Hat derivative/version and repositories are unknown, so there is
no verified distribution-specific system-package installation command yet.
Source installation may require a compiler toolchain and development libraries
for font discovery/rendering, text shaping, image codecs and ICU, depending on
the approved binary/source package source. These requirements arise particularly
from ragg, systemfonts, textshaping and stringi. Review their requirements with the
administrator rather than assuming OS package names. Install usable fonts and
record their selection if consistent appearance matters.

The service account needs read access to source/config/reference files, a writable
configured output directory under the project, and a writable temporary directory.
Current configuration deliberately requires project-relative paths. If a server
requires read-only code with output storage outside the project, agree a separate
output-root design before deployment; do not work around permission boundaries.

## Server verification and failure handling

Set `PA_TEST_SCRATCH` to a dedicated writable scratch directory and run the full
test suite using the restored library. Retain test evidence. Execute the CLI from
outside the project directory without DISPLAY, compare all ten counts and
denominators with the reviewed expectations, inspect the chart, and verify exit
statuses and manifests for intentional invalid inputs.

Exports are written first to `review_incomplete/`, then renamed to `review/` only
after calculations and exports complete. Consume results only when the manifest
records a completed provisional run; a crash before the final manifest update
does not imply success. Failed runs retain diagnostics and incomplete artefacts.
If storage itself is unavailable, evidence may be impossible to write; the CLI
still fails and reports the original error. Early configuration or output-root
failures may occur before any run directory exists.

Local fresh-process tests use existing installed libraries, not a newly restored
empty library. Linux execution and restoration remain unverified until performed
on the target server. Technical success does not resolve missing official source
provenance, geography coverage or benchmark reconciliation.
