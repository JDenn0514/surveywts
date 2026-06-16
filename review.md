# review.md — nps-calibration-path PR 2 (feature/nps-calib-dagjk) — re-review

**Verdict: PASS**
**Reviewer:** claude-sonnet-4-6
**Date:** 2026-06-16

---

## Re-review: targeted BLOCK fix verification

The single BLOCK item from the prior cycle has been resolved. `R/create_group_jackknife_weights.R` line 599 now reads:

```r
ipw_entry <- if (length(ipw_entries) > 0L) ipw_entries[[length(ipw_entries)]] else NULL
```

This matches the spec §Validation order step 5 ("Find the LAST IPW entry") and
is consistent with the QR bootstrap implementation in `R/replicate-utils.R`.
The `calib_entry` selection at lines 610–614 was also inspected and correctly
uses `calib_entries[[length(calib_entries)]]`; no other "first vs last" issues
were found in the surrounding routing logic.

Test results: `devtools::test(filter = "nps-group-jackknife")` — 293 PASS, 0
FAIL (2 documented skips, 1 expected warning). Full suite: 3675 PASS, 0 FAIL.
All other checks (tolerance integrity, scope discipline, CRAN cookbook, coverage
floor, comprehension alignment) passed in the prior cycle and were not
re-examined.
