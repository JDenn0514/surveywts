# PR 4 Review — Round 3

## Verdict: PASS

## Summary
The E20 fix is correctly implemented: `surveywts_error_cap_not_positive` fires
for non-positive/non-finite/non-numeric `cap` values, the dual-pattern test
block is present and clean, the snapshot is committed and well-formed, and
`R CMD check` clears with 0 errors / 0 warnings.

## E20 check

**Production code:** `R/calibrate_rake.R` lines 203–218. Validation block placed
immediately after the `cap_not_supported_nr` guard (line 201), so a non-positive
cap with `algorithm = "classic_ipf"` hits this path correctly. Guard condition
`!is.numeric(cap) || length(cap) != 1L || !is.finite(cap) || cap <= 0` covers
non-numeric, non-scalar, non-finite, and zero/negative inputs. Error class:
`"surveywts_error_cap_not_positive"`. Message structure: `x` / `i` / `v`
bullets, all well-formed per code-style rules. `cap = 0` triggers the `<= 0`
branch correctly.

**Test:** `tests/testthat/test-03-rake.R` lines 692–708. Block labeled `E20`
uses `weights = base_weight` (no SRS-warning interference). Dual pattern
present: `expect_error(..., class = "surveywts_error_cap_not_positive")` +
`expect_snapshot(error = TRUE, ...)`.

**Snapshot:** `tests/testthat/_snaps/03-rake.md` lines 199–208. Entry
"calibrate_rake() rejects cap = 0" present, message text matches the
production `cli_abort()` bullets exactly (`x`, `i`, `v`).

**Error class in `error-messages.md`:** row for `surveywts_error_cap_not_positive`
present at line 50.

## R CMD check
0 errors / 0 warnings / 1 note (`unable to verify current time` — network,
pre-approved)

## Test run
FAIL 0 | PASS 188 (test-03-rake.R only; 16 expected warnings captured correctly)
