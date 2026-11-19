# Methodology and current limits

This workflow preserves the reviewed SAS calculation, not its known defects.
Source counts represent authority–sex–age observations. The original text is
retained during ingestion; invalid records cause failure, not silent exclusion.
The category references are transcriptions of the supplied extract, not externally
authenticated ONS codebooks.

Age codes 1–2 map to 0–4, 3–6 to 5–15, 7–9 to 16–24, 10–17 to 25–64,
and 18–23 to 65+. These are exact unions of source categories. No estimation or
splitting of counts is performed. Every mapping must be many-to-one and complete.

Counts are summed across observed authorities within each sex and reporting age
group. A percentage is 100 times the group count divided by the sum across all
five groups for the same sex. The machine-readable result retains the denominator
and full-precision percentage. Round to one decimal place only when displaying;
the rounded male percentages total 100.1%, which is an expected rounding effect.

The supplied-file regression expectations are female 30,420,281, male 29,177,325
and combined 59,597,606. All ten reviewed group counts are in
`tests/expected/ons_rm121_2021_results.csv`. These expectations are tied to the
source checksum in the tests. They are not independently verified official totals.

CSV and PNG outputs are explicitly provisional and remain inside a run-specific
`review/` directory. The count chart uses separate sex panels with a shared
scale, so colour is not needed to identify sex. The age groups have unequal widths
and 65+ is open-ended; the bars are totals, not densities or counts per year of age.

Geography coverage is checked only within observed authorities. No authoritative
geography list or comparable official benchmark has been supplied, so independent
coverage and official acceptance remain blocked. The geographical scope and year
are descriptions inherited from the supplied files, not external certification.
The workflow cannot promote itself to official acceptance by editing a status flag.

Future adapters must validate their own source schemas and domains. Exact mappings
must respect classification boundaries. Source and grouping keys must retain
periods and other context that define separate populations. Do not sum snapshots,
overlapping geography levels, incompatible classifications, rates or percentages.
