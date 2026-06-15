# PR 5 Review

## Verdict: PASS

## Summary

All five BLOCK items from round 1 are resolved. Spec coverage, tolerance
integrity, scope discipline, CRAN cookbook, coverage floor, and
comprehension alignment all pass. The round-2 audit verdict is PASS with
no outstanding issues.

---

## Tolerance Integrity

| Check | Spec tolerance | Implementation | Pass |
|-------|---------------|----------------|------|
| EC6 `cell_factors` value per cell | `1e-10` | `tolerance = 1e-10` at test line 1306 | PASS |
| Oracle N1/N2 vs `survey::postStratify` | `1e-8` | `tolerance = 1e-8` at test line 269 | PASS |
| Weight computation (rowSums, base_weights) | `1e-10` | `tolerance = 1e-10` at lines 91, 1036, 1051, 1067 | PASS |
| No tolerance relaxations found | — | — | PASS |

---

## Spec coverage

| AC item | Status | Notes |
|---------|--------|-------|
| H1–H9 happy paths | PASS | Tests 1–9 plus PT-1..14 and PR-1..9 cover all input classes |
| N1 oracle (single strata) | PASS | Covered indirectly; tester accepted single-block covering both N1 and N2 (round-1 gate 6 note) |
| N2 oracle (two-variable strata) | PASS | Test 10: `~age_group + sex`, `tolerance = 1e-8`, `skip_if_not_installed` inside block |
| E1–E18 error paths (dual pattern) | PASS | All 18 verified in round-1 audit table |
| W1 `surveywts_warning_srs_no_weights` | PASS | Test W1 at line 1343; code in `R/poststratify.R:253` |
| W2 `surveywts_warning_replicate_calibration_failed` | PASS | Test W2 at line 1360; code at `R/poststratify.R:470` |
| EC1 named list rejection | PASS | Test 21 (dual pattern) |
| EC5 `operation == "poststratify"` | PASS | Tests 8, 37 assert `"poststratify"` not `"calibrate_poststrat"` |
| EC6 `cell_factors` value assertion | PASS | Test at line 1285 iterates all cells, `tolerance = 1e-10` |
| CX4 four distinct operation strings | PASS | Test at line 1314; asserts `expect_length(unique(ops), 4L)` and all four strings present |
| `test_invariants()` first | PASS | Called first in all applicable blocks |
| `.format_history_step()` `"calibrate_linear"`/`"calibrate_logit"` arms | PASS | `R/utils.R:53–56` display variable names |
| `"calibrate_greg"` arm absent from `.format_history_step()` | PASS | No such arm in `switch()` block |
| `plans/error-messages.md` Thrown-by updated | PASS | Documented in `implementation.md` |
| `calibrate_poststrat` absent from functional code | PASS | Only in comments in `R/` and `tests/` |

---

## R CMD check

0 errors, 0 warnings, 2 pre-approved NOTEs (`CRAN incoming feasibility`,
`future file timestamps`). Confirmed by round-2 audit gate 5.

---

## Scope discipline

Write surface in `implementation.md` matches `impl-calibration-framework.md`
PR 5 entries exactly:

- Created: `R/poststratify.R`, `man/poststratify.Rd`
- Deleted: `R/calibrate_poststrat.R`, `man/calibrate_poststrat.Rd`
- Modified: `R/utils.R` (`.format_history_step()` only), `R/adjust_nonresponse.R`
  (broken `@details` link — documentation-only, noted in `implementation.md`),
  `tests/testthat/test-04-poststratify.R`, snapshot files,
  `plans/error-messages.md`, `NAMESPACE`

No extra files written outside declared scope. No regressions outside PR scope
(2933 pass, 0 fail in round 2; delta of +23 tests all within PR 5 scope).

---

## CRAN cookbook

No violations. Both audits confirm clean scan of `R/poststratify.R`:
no `T`/`F`, no `set.seed()`, no bare `print()`/`cat()`, no `options(warn=-1)`,
no `installed.packages()`, no `<<-`, no `@importFrom`, no functional
`calibrate_poststrat` references.

---

## Coverage

| Scope | Measured | Floor | Pass |
|-------|----------|-------|------|
| `poststratify.R` | 100% (133/133) | ≥ 98% | PASS |
| Overall package | 97.95% | ≥ 95% | PASS |
| New-code lines | 100% covered | no regression | PASS |
