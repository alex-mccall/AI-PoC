# Population workflow handover

Prepared 19 November 2026. This summary supports handover; it is not a substitute
for the full conversation exports or independent official-source validation.

## Purpose and agreed scope

Replace the supplied SAS population-processing example with a modular,
Tidyverse-first R workflow. Preserve Census 2021 England-and-Wales totals as
described in the supplied files, the source sex categories, five reporting age
groups (0–4, 5–15, 16–24, 25–64, 65+) and percentages within sex.

The user chose CSV and a static chart, not an HTML analytical report. Provisional
review exports are permitted while official source evidence is unavailable.
An interactive single-script entry point is required for Positron on the Mac;
a Red Hat–based Linux server is a possible future target.

## Inputs and important review findings

The supplied files are `Inputs/ons_population_processing.sas` and
`Inputs/ons_rm121_sex_by_age_2021.csv`. The originals have been preserved.
The CSV has seven fields and 15,226 authority–sex–age records: 331 observed
authorities, two source sex categories and 23 source age categories.

The reviewed SAS age mapping and within-sex denominator were appropriate for the
supplied categories. Required corrections concerned a personal absolute input
path, deletion before audit, ineffective unknown-age detection, truncation of its
fallback label, alphabetical rather than chronological age ordering, insufficient
key/coverage/conversion checks and session-dependent output persistence.
Quoted commas were already appropriately addressed by its CSV options.

SAS was not executed, so numerical equivalence to an actual SAS run has not been
demonstrated. The R regression expectations were independently calculated from
the supplied CSV; they are not authoritative benchmark certification.

## Entry points and implementation

| Location | Responsibility |
|---|---|
| `run_population.R` | Source the whole file in Positron; shows a plot and creates `population_run` |
| `scripts/run_population_analysis.R` | Callable end-to-end workflow |
| `scripts/population_cli.R` | Headless/server command-line entry point |
| `scripts/validate_population_input.R` | Ingestion and structural validation checkpoint |
| `config/ons_rm121_2021.yml` | Paths, schema, context and approved reporting order |
| `reference/` | Explicit source category labels and reporting-age mapping |
| `R/` | Reusable ingestion, validation, mapping, aggregation, presentation and provenance functions |
| `tests/testthat/` | Analytical, entry-point and failure-path tests |
| `renv.lock` | Recorded analytical/test dependency closure, not automatic environment activation |
| `docs/methodology.md` | Denominator, mapping and interpretation limits |
| `docs/deployment.md` | Local/server operation and deployment limitations |

The scripts do not install packages, change working directory or restart sessions.
The interactive object contains results, checks, configuration and saved paths.
Outputs are generated in unique run directories. Incomplete exports are staged
separately; a completed manifest, not the presence of a CSV alone, defines a
completed provisional run. Official acceptance remains blocked.

## Numerical and test evidence

| Measure | Reviewed expectation for this supplied input |
|---|---:|
| Female total | 30,420,281 |
| Male total | 29,177,325 |
| Combined total | 59,597,606 |
| Final sex–age rows | 10 |
| Recorded passing automated test blocks | 22 |

All ten expected counts are in `tests/expected/ons_rm121_2021_results.csv`.
Percentages retain full precision; rounded male percentages total 100.1%.

The documented verified run is
`outputs/ons_rm121_sex_by_age_2021_input_20261119T123433_43141f719bc4/`.
It contains recorded 22-block test evidence, input/code/output checksums and
portability limitations. A later `...T124046_43145138df67/` run also exists but
does not contain the same test-evidence attachment. Preserve all runs, not just
the latest by timestamp. This handover does not claim a new test execution.

Verified execution is on this Mac using R 4.5.3. R 4.1 is the declared minimum
for the recorded dependency closure, not a tested compatibility matrix. Fresh
R-process headless runs were tested using existing installed libraries. Linux,
other R versions and restoration into a clean library remain unverified.

## Unresolved evidence and next steps

| Item | Status / next action |
|---|---|
| Original source URL, release and download date | Unknown; obtain original official metadata |
| Population definition and exact reference date | Unknown; do not infer from the filename |
| Geography vintage and independent authority coverage | Blocked pending an authoritative list |
| Official benchmark reconciliation | Blocked; reviewed fixture totals are not an independent benchmark |
| Source codebooks | Current references were transcribed from the supplied file, not independently authenticated |
| Linux deployment | Confirm distribution/version, R, approved repository, fonts, native libraries and permissions; restore and run tests there |
| Presentation/accessibility sign-off | User review remains pending |
| Operational edge cases | Actual server storage/quotas and abrupt process termination remain untested |
| Full interactions | Export JSON and HTML from Assistant into `docs/conversations/`, inspect and test import |
| Git history | No commits existed at the start of preservation; follow `docs/preservation.md` after reviewing files |

The original detailed review, acceptance checklist, test specification and design
discussion are in the conversation, not all separate saved documents. Exporting
that conversation is therefore an essential outstanding preservation step.

## Preservation and privacy

The bundle includes source, original inputs, references, tests, documentation,
dependency records and all saved outputs, even though outputs are Git-ignored.
It excludes Git internals, local libraries/caches, OS clutter and the unrelated
`Useful prompts.txt`. The exclusion inventory is retained in bundle metadata.
The blocked planning-file save outside the workspace did not create a project
artefact; the proposed design is preserved through the conversation instead.

Manifests and conversations may contain local paths and other personal context.
This is a private preservation bundle, not a redacted public release. Checksums
detect changes relative to a trusted copy; they do not prove authorship or source
accuracy. Keep a second copy off this computer and retain the checksum sidecars.
