# Current test and acceptance status

The provisional workflow has 22 passing automated test blocks. This is not a statement
that every test in the proposed acceptance specification has been implemented.

| Area | Current evidence | Remaining limitation |
|---|---|---|
| Configuration and parsing | Path guards, header changes/reordering, quoted comma, short record, malformed quote | Additional encoding and permission edge cases |
| Raw observations | Missing fields, invalid counts, code-label mismatch, duplicates, missing combinations | No independent geography list |
| Mapping and arithmetic | All 23 mappings and ten counts, total preservation, denominator and rounding checks | No official benchmark |
| Reuse safeguards | Alternative category/period fixture; omitted period denominator fails | No second real dataset adapter |
| Ordering and presentation | Approved order enforced, provisional labels tested, actual PNG visually inspected | Independent user accessibility/presentation review pending |
| Failed runs | Invalid input, zero denominator, simulated CSV/PNG export and diagnostic-storage failures are exercised; incomplete exports are not promoted; earlier CSV unchanged | Actual server permissions, quotas and abrupt process termination untested |
| Provenance | Input/config/reference/code checksums, change-detection test, session info, output/test checksums | Full original source metadata unknown |
| Interactive execution | Single root-level script runs when sourced from outside the project; working directory unchanged | User presentation review pending |
| Reproducibility | Dependency closure recorded; repeated CLI runs in fresh R processes with startup profiles disabled and DISPLAY empty produce identical CSV checksums | Linux execution, clean-library restore and other R versions untested |

Runtime validation results are not the entire automated-test report. Automated
test evidence is retained as `automated_test_results.rds` and recorded in the
latest verified run manifest. Unknown official coverage and benchmark checks
remain blocked. No official publication or routine-use sign-off is implied.
