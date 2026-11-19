# Population workflow: implementation checkpoints

## Decisions agreed with the user

Preserve the SAS analysis: Census 2021 England-and-Wales population, five age
groups (0–4, 5–15, 16–24, 25–64, 65+), percentages within each source sex category.
Deliver CSV results and a static chart, plus machine-readable validation evidence
and a run manifest. Do not create an HTML summary at this stage.

Only the supplied CSV and SAS files are available. Source URL, download date,
release, exact reference date, geography vintage, population definition and an
authoritative benchmark are unknown. Do not infer these from the filename.
Independent national coverage and official-total acceptance remain blocked.

## Checkpoint 1: ingestion and validation

The source files remain unchanged. Configuration paths are project-relative.
The supplied file is ASCII-compatible; UTF-8 is an appropriate reader setting for
this file, not a claim about all future downloads. Missing-value markers beyond
empty fields are unconfirmed; observations must currently be unsigned decimal
integer text, without grouping separators or scientific notation. Zero is valid.
No data are trimmed, deduplicated, imputed or silently excluded.

Category reference tables were transcribed from the supplied file and reviewed
SAS mapping. They are not independently sourced official codebooks. Completeness
is checked within observed geographies: a wholly absent geography cannot be
detected without an external geography reference. Counts and a checksum in tests
are regression fixtures only and are not universal processing requirements.

To run the input checkpoint, source `scripts/validate_population_input.R`, then
call `run_input_validation()` with the explicit project-root path. The function
returns validated data invisibly and writes a unique `outputs/` evidence folder.
The root path is supplied by the caller; processing does not change directories.
No population-results CSV or chart is produced until the next checkpoint.

The initial checkpoint was executed successfully against all 15,226 supplied
records, with zero rejections. The automated tests cover schema changes, quoted
fields, invalid counts, missing fields, duplicates, incomplete grids and reference
integrity. Test execution evidence is retained with the latest checkpoint run.

Run automated tests from the project root with `testthat::test_dir("tests/testthat")`.
Set `PA_TEST_SCRATCH` to a writable scratch directory before running tests;
temporary fixtures belong there, not in the source-data directory.

## Next checkpoints

The user approved provisional review exports while independent source evidence is
unavailable. Exact category joins, total-preserving aggregation, full-precision
within-sex percentages and chronological CSV/PNG outputs are now implemented.
Review outputs are labelled provisional, and official acceptance remains blocked.
The chart uses separate sex panels and a shared scale instead of colour-dependent
clustered bars. The full workflow has now been executed and the rendered chart
inspected. The first MVP checkpoint passed 17 automated test blocks, including a successful run followed
by a failed input run and a failed zero-denominator run; previous results remain
unchanged and both failure manifests are marked failed. These tests exposed and
led to correction of an error-handler scoping defect before checkpoint completion.

The initial verified MVP run was
`outputs/ons_rm121_sex_by_age_2021_input_20261119T122347_4314ff90d17/`.
It retains all ten reviewed group counts, totals 59,597,606, and contains the
provisional CSV/PNG, validation evidence, test results and checksummed manifest.
Source/reference/code changes during processing are detected, and reporting
order is checked against the approved configuration. Known period/geography
context cannot be omitted from percentage denominators.

## Interactive and server entry points

The user requires an interactive Positron entry point on this Mac and may also
run on a Red Hat–based Linux server. `run_population.R` is the single interactive
entry script: source it to show the chart and create `population_run`. It uses the
same calculations as `scripts/population_cli.R`, not a separate implementation.
No working-directory change, package installation or session restart occurs.

The dependency closure is recorded in `renv.lock` using the installed environment
and configured repositories. R 4.1 is the declared minimum for this dependency
closure; execution has only been verified here on R 4.5.3. No renv activation file
was created, and the active library has not been replaced. A lockfile records
versions; it is not evidence of a clean-library restore or Linux execution.

All 22 automated test blocks pass, including repeated clean-process CLI runs from
an unrelated working directory with an empty DISPLAY. Simulated CSV/PNG export
failures retain failed manifests and incomplete exports. Diagnostic-storage
failure does not replace the original error. Server permissions and abrupt
termination still require operational review.

The latest verified interactive run is
`outputs/ons_rm121_sex_by_age_2021_input_20261119T123433_43141f719bc4/`.
Its manifest includes the 22-block test evidence, dependency-lock checksum,
interactive-entry checksum and explicit limitations on platform verification.

Remaining portability evidence requires the Red Hat distribution/version, target
R installation, approved package repository/network policy, native libraries and
fonts, followed by restore and test execution on that server. See deployment notes.

Before claiming routine acceptance, obtain the official geography reference and
benchmark or record an explicitly restricted, non-certified use decision. A
structurally successful run is not an accepted official population result.
