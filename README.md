# AI-PoC

## Population-processing workflow

The R workflow replaces the reviewed SAS calculation with explicit ingestion,
validation, exact age mapping, aggregation and within-sex percentages. The
original files in [Inputs](Inputs/) are preserved unchanged.

**Current outputs are provisional review artefacts, not accepted official totals.**
Only the supplied files are available; authoritative geography coverage and
official benchmark reconciliation remain blocked.

### Running

Use R 4.1 or later with the dependencies listed in
[config/dependencies.csv](config/dependencies.csv). A declared minimum is not a
claim that every R version has been tested. No entry point installs packages,
restarts your session or changes the working directory.

**Interactive use in Positron on this Mac:** open
[run_population.R](run_population.R) and source the whole file. From a console
whose working directory is the project root, `source("run_population.R")` does
the same thing. The chart appears in the Plots pane and `population_run` contains
`results`, `checks`, `csv`, `chart`, `run_directory` and the configuration used.
The script detects its own location when sourced, so sourcing it by absolute path
also works from another directory. If sending individual lines from elsewhere,
set `project_root_override` in its settings block. The script resets
`population_run` first, so a failed rerun does not leave stale results in that object.

**Programmatic use:** source
[scripts/run_population_analysis.R](scripts/run_population_analysis.R), then call
`run_population_analysis(project_root)` with an explicit absolute project root.

**Headless/server use:** the separate
[scripts/population_cli.R](scripts/population_cli.R) entry point accepts
`--project-root`, optional `--config` and optional `--library`. PNG rendering uses
`ragg::agg_png` explicitly and does not require an X display. Exit status zero
means provisional execution succeeded, not official acceptance.
See [deployment instructions](docs/deployment.md) for dependency restoration,
server prerequisites and the distinction between tested and declared compatibility.

Input locations, schema and settings are in
[config/ons_rm121_2021.yml](config/ons_rm121_2021.yml).
Paths in configuration are relative to the supplied project root, never a
personal home directory. No processing step changes the working directory.

Each run creates a new local `outputs/` directory containing validation checks,
record accounting, session information and a manifest. A successful provisional
run also contains a `review/` directory with a CSV and PNG. Failed runs are marked
failed in the manifest; do not use partial artefacts from a failed run. Generated
outputs are ignored by version control by default, not deleted.

To run ingestion/validation alone, source
[scripts/validate_population_input.R](scripts/validate_population_input.R) and
call `run_input_validation(project_root)`.

### Tests and interpretation

From the project root, set `PA_TEST_SCRATCH` to an existing writable scratch
directory, then run `testthat::test_dir("tests/testthat")`. Test fixtures are
written only to that scratch directory. Never use the source directory as scratch.

See [methodology](docs/methodology.md) for the denominator, age mapping, rounding
and interpretation limits, and [implementation progress](docs/implementation_progress.md)
for agreed decisions and remaining acceptance work.

### Preservation and handover

See [handover summary](docs/handover.md) and
[preservation instructions](docs/preservation.md). Dated bundles include all
saved output runs as well as source files and checksums. Conversation JSON/HTML
must be exported manually into [docs/conversations](docs/conversations/README.md)
before a later bundle can include the interactions. No Git commit or upload is
performed by the preservation tool.