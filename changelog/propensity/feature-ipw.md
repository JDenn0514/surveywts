# feat(weights): add ipw() for inverse probability weighting of non-probability samples

**Date**: 2026-05-20
**Branch**: feature/ipw
**Phase**: Propensity

## Changes

- Add `ipw()` — constructs inverse probability weights for non-probability samples
  via pseudo-likelihood Newton-Raphson. Supports `logit`, `probit`, and `cloglog` links.
  Returns a `survey_nonprob` object with full weighting history.
- Add `.fit_participation_propensity()` — internal Newton-Raphson engine for `ipw()`.
- Extend `.validate_formula_variables()` in `R/utils.R` with `error_class = NULL`
  parameter (backward-compatible) to support per-call error class customization.
- Add `"ipw"` case to `.format_history_step()` in `R/utils.R` for print output.
- Add `make_nps_reference()` to `tests/testthat/helper-test-data.R`.
- Add `nonprobsvy` to `Suggests:` in `DESCRIPTION`.
- Add 13 new error/warning classes to `plans/error-messages.md`.
- Update `.claude/rules/surveywts-conventions.md` with `propensity` family and `ipw()` arg order.

## Implementation Notes

- **Degenerate score detection**: R link functions (logit/probit/cloglog) never return
  exactly 0 or 1 — they saturate at `.Machine$double.eps` and `1 - .Machine$double.eps`.
  The degenerate check and NR overflow guard use these float boundaries rather than strict
  0/1 to catch diverging NR before the Hessian becomes singular.
- **NR overflow guard**: Added pre-Hessian guard in `.fit_participation_propensity()` that
  checks NPS scores at the top of each iteration. When scores saturate (after 1 NR step
  in perfect-separation scenarios), the function returns early, allowing `ipw()` to throw
  `surveywts_error_propensity_scores_degenerate` with the correct class rather than the
  more confusing `surveywts_error_propensity_hessian_singular`.
- **Factor level alignment**: Both datasets are aligned to reference levels before
  `model.matrix()` to ensure conformable matrices when the NPS is missing reference-only
  levels.
- **Test data design**: Tests with overrepresented NPS categories (n_nps_k > n_ref_k)
  have no feasible score equation solution; only binary/continuous variable designs where
  n_nps_k <= n_ref_k are used for convergent tests.

## Files Modified

- `R/nonprob-ipw.R` *(new)* — `.fit_participation_propensity()` + `ipw()`
- `R/utils.R` — `error_class = NULL` on `.validate_formula_variables()`; `"ipw"` case in `.format_history_step()`
- `tests/testthat/test-nonprob-ipw.R` *(new)* — full test suite (6 categories)
- `tests/testthat/helper-test-data.R` — `make_nps_reference()` added
- `DESCRIPTION` — `nonprobsvy` added to `Suggests:`
- `plans/error-messages.md` — 11 new error classes + 2 warning classes for `ipw()`
- `.claude/rules/surveywts-conventions.md` — `propensity` family + `ipw()` arg order
- `changelog/propensity/feature-ipw.md` — this file
