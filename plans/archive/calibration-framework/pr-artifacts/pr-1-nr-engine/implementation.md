# Implementation: NR Calibration Engine (PR 1)

**Branch:** `feature/calibration-nr-engine`
**Base:** `develop`
**Status:** Complete

---

## Summary

This PR adds the internal calibration engine infrastructure needed to support
the new `calibrate_linear()`, `calibrate_logit()`, and `calibrate_rake(nr)`
functions (PRs 2–4). No user-facing API changes; all new code is internal.

- Added 5 new internal helpers implementing the Deville-Sarndal (1992, 1993)
  calibration framework: 2 validators (`.validate_bounds()`,
  `.validate_unit_scale()`), 3 F-function constructors (`.make_calfun_linear()`,
  `.make_calfun_logit()`, `.make_calfun_raking()`), and 1 NR solver
  (`.calibrate_nr_engine()`).
- `.calibrate_nr_engine()` implements the Newton-Raphson loop from Deville
  et al. (1993) §11. Convergence criterion: `max(|misfit| / (1 + |t_x|)) <
  epsilon`. Linear method converges in exactly 1 iteration. Step-halving
  guard (≤20 halvings) protects against non-finite g-weights.
- `.make_calfun_logit()` uses sign-based branching on `A*u` (threshold 500)
  to avoid `exp(A*u)` overflow for large |u|.
- Updated `.build_calibration_provenance()` to accept explicit `lambda` and
  `bounds_scale` arguments, with backward-compatible fallback when `lambda =
  NULL`.
- Added 3 new error classes to `plans/error-messages.md`:
  `surveywts_error_bounds_invalid_calibration`,
  `surveywts_error_unit_scale_invalid`,
  `surveywts_error_calibration_singular_system`.

---

## Write Surface

### Modified
- `R/calibrate-utils.R` — added 6 new functions + updated
  `.build_calibration_provenance()` signature
- `plans/error-messages.md` — added 3 new error classes

### Created
- `tests/testthat/test-calibrate-utils-nr.R` — 87 unit tests
- `changelog/calibration/feature-calibration-nr-engine.md`
- `plans/calibration-framework/pr-1-nr-engine/implementation.md` (this file)

### Not modified
- No exported functions changed
- No NAMESPACE changes
- No man/ changes

---

## Task Checklist

- [x] Update `plans/error-messages.md` with new error/warning classes
- [x] `.validate_bounds(bounds, bounds_scale, allow_null)` — implemented
- [x] `.validate_unit_scale(unit_scale, n)` — implemented
- [x] `.make_calfun_linear(L = NULL, U = NULL)` — implemented
- [x] `.make_calfun_logit(L, U)` — implemented (numerically stable)
- [x] `.make_calfun_raking()` — implemented
- [x] `.calibrate_nr_engine(x_matrix, weights_vec, calfun, population, epsilon, maxit)` — implemented
- [x] Update `.build_calibration_provenance()` — lambda + bounds_scale args
- [x] Unit tests written and passing (87 tests, 0 failures)
- [x] `calibrate_rake()` regression smoke test passes
- [x] `devtools::document()` run — no NAMESPACE changes
- [x] `devtools::check()` — 0 errors, 0 warnings, 3 pre-approved notes

---

## HOLDs

None.

---

## CRAN Compliance Checklist

1. [x] TRUE/FALSE used throughout (no T/F)
2. [x] `::` used for all external calls (cli::, stats::)
3. [x] No bare `print()`/`cat()` in non-print-method code
4. [x] No randomness in these functions (no `seed` arg needed)
5. [x] No `par()`/`options()` modifications
6. [x] No file writes
7. [x] No examples/tests using > 2 cores
8. [x] `devtools::document()` run
9. [x] No `requireNamespace()` calls
10. [x] All `cli_abort()` calls have `class=`; classes in `plans/error-messages.md`

---

## Notes for Tester

- `.calibrate_nr_engine()` convergence check fires AFTER updating lambda (not
  before), so the linear method registers `n_iterations = 1L`. This is
  intentional: the first step is exact for linear, and the convergence check
  confirms it.
- The logit F-function clamps to `[L, U]` at extreme values as a final
  numerical guard. This means `dF` approaches 0 at the boundaries (correct
  behavior — g-weight is at its limit).
- `.build_calibration_provenance()` now has `bounds_scale` as a 13th field in
  the returned list. Downstream surveycore readers that pattern-match on list
  length should use named access instead.
