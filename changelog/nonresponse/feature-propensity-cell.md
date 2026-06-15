# Changelog: feature/propensity-cell

**Branch:** `feature/propensity-cell`
**Phase:** Nonresponse — PR 4
**Status:** Complete

## What Changed

### Extended functions

- `adjust_nonresponse(method = "propensity-cell")`: New method for propensity-score-based
  nonresponse adjustment. Fits a logistic regression model (`stats::glm(family = binomial)`)
  on the response indicator using the supplied `formula`, computes propensity scores, assigns
  respondents and nonrespondents into quantile-based cells, and redistributes nonrespondent
  weights to respondents within each cell. Nonrespondent rows are zeroed and filtered from
  S7 output objects.

### New arguments

- `formula`: One-sided formula (`~ x1 + x2`) specifying predictors for the propensity model.
  Required when `method = "propensity-cell"`; silently unused for other methods.
- `control$n_cells` (default `5`): Number of propensity cells. Must be a whole number >= 2.

## Design Decisions

- **`by` is ignored with a warning:** The propensity-cell method operates globally (fits one
  model across all data). If `by` is non-NULL a `surveywts_warning_by_ignored_for_propensity_cell`
  warning fires and the method proceeds without grouping.

- **Formula LHS construction:** The GLM formula must include the response variable on the LHS.
  `response_status` is resolved to a column name string (`status_var`) before the model is fit:
  `stats::as.formula(paste(status_var, "~", deparse(formula[[2]])))`. Passing `formula`
  directly (no LHS) or using `update(formula, response_status_vec ~ .)` with a bare symbol
  both fail — the explicit `paste()` approach is necessary.

- **Quantile-based cell boundaries:** `stats::quantile(scores, probs = seq(0, 1, 1/n_cells))`
  gives `n_cells + 1` cut points. `findInterval(..., rightmost.closed = TRUE)` maps them into
  `1:n_cells` cells with the maximum score landing in cell `n_cells`.

- **GLM convergence warnings pass through:** `stats::glm()` may emit convergence or
  `non-integer #successes` warnings (the latter when base weights are non-integer). These are
  not suppressed — they surface to the user as standard R warnings.

- **Non-ASCII fix:** `≥` in the `n_cells` error message was replaced with `>=` to satisfy
  R CMD check portability requirements. A snapshot that captured the old `≥` message was
  updated via `testthat::snapshot_accept("05-nonresponse")`.

## Files Added / Changed

- `R/nonresponse.R` — extended `adjust_nonresponse()` with propensity-cell branch; added
  `formula` parameter; updated `control` defaults to include `n_cells = 5`; replaced `≥`
  with `>=` in n_cells error message
- `tests/testthat/test-05-nonresponse.R` — deleted propensity-cell stub test; added 17 new
  test blocks (PC-1 through PC-17)
- `tests/testthat/_snaps/05-nonresponse.md` — deleted stub snapshot; added new error/warning
  snapshots for propensity-cell paths; updated n_cells snapshot (`≥` → `>=`)
- `man/adjust_nonresponse.Rd` — re-generated with new `formula` and `n_cells` documentation
- `plans/impl-nonresponse.md` — PR 4 marked `[x]`
