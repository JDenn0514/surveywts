# Vendored Code Attribution

This file documents all code vendored from external packages into
`surveyweights`. All vendored code is reproduced and adapted under the
terms of the original license, which is GPL-2 or later — compatible with
this package's GPL-3 license.

---

## R/vendor-calibrate-greg.R

**Algorithm:** GREG (generalized regression) linear calibration and logit
calibration via IRLS (iteratively reweighted least squares)

| Field | Value |
|-------|-------|
| Source package | `survey` |
| Source version | 4.4-8 |
| Author | Thomas Lumley, Peter Gao |
| License | GPL-2+ |
| Source functions | `survey:::grake()` (logit IRLS engine); `survey:::regcalibrate.survey.design2()` (linear exact solution) |
| CRAN URL | <https://cran.r-project.org/package=survey> |

**Adaptations:**

- Removed dependency on `svydesign` objects; functions accept plain numeric
  vectors and matrices only.
- Replaced `MASS::ginv()` with `.gram_solve()`, an SVD-based Moore-Penrose
  pseudoinverse computed using base R only. The result is mathematically
  identical to `MASS::ginv()`.
- Linear and logit calibration separated into `.greg_linear()` and
  `.greg_logit()` for clarity.
- Removed survey-internal class checks, formula machinery, and sparse matrix
  support (not needed for Phase 0's categorical-variables-only scope).
- Return value is a g-weight vector (multipliers) rather than a modified
  survey design object.

**Coverage:** Numerical output verified against `survey::calibrate()` within
1e-8 tolerance in `tests/testthat/test-02-calibrate.R` and
`tests/testthat/test-03-rake.R`.

---

## R/vendor-calibrate-ipf.R

**Algorithm:** Iterative proportional fitting (IPF / raking) — multiplicative
weight adjustment to match known marginal population totals

| Field | Value |
|-------|-------|
| Source package | `survey` |
| Source version | 4.4-8 |
| Author | Thomas Lumley, Peter Gao |
| License | GPL-2+ |
| Source function | `survey:::rake()` |
| CRAN URL | <https://cran.r-project.org/package=survey> |

**Adaptations:**

- Removed dependency on `svydesign` objects and `svytable()`; function
  operates on plain numeric weight vectors and pre-computed margin structures.
- Convergence criterion adapted to use max absolute change in weighted marginal
  totals per sweep, scaled by `epsilon * sum(ww)`. This is consistent with
  `survey::rake()`'s default (`epsilon = 1`) and produces numerically
  equivalent output.
- Return value is a list of `$weights`, `$converged`, and `$iterations` rather
  than a modified survey design object.

**Coverage:** Numerical output verified against `survey::rake()` within 1e-8
tolerance in `tests/testthat/test-03-rake.R`.

---

## R/vendor-rake-anesrake.R

**Algorithm:** IPF raking with chi-square-based variable selection — variables
are ranked by chi-square discrepancy and skipped if they already meet the
chi-square p-value threshold

| Field | Value |
|-------|-------|
| Source package | `anesrake` |
| Source version | 0.92 |
| Author | Josh Pasek, with assistance from Gene Routh and Alex Tahk |
| License | GPL-2+ |
| Source function | `anesrake::anesrake()` |
| CRAN URL | <https://cran.r-project.org/package=anesrake> |

**Adaptations:**

- Extracted core IPF-with-chi-square-selection algorithm into a standalone
  function that operates on plain numeric weight vectors, character level
  vectors, and named target vectors. Removed all `data.frame`, `caseid`, and
  `svydesign` dependencies.
- Variable selection uses a chi-square p-value threshold (`pval`) rather than
  anesrake's percentage discrepancy threshold (`pctlim`), allowing a
  conventional hypothesis-testing interpretation.
- Convergence is based on percentage improvement in total chi-square between
  consecutive sweeps (`improvement` parameter), matching anesrake's `convcrit`.
- Cap is applied after each margin adjustment step (same behavior as anesrake).
- Variable selection order is re-computed at the start of each sweep using the
  current weights (not pre-computed once before all sweeps).
- Return value is a list of `$weights`, `$converged`, `$iterations`,
  `$max_error`, and `$already_calibrated`.

**Coverage:** Algorithm correctness verified by checking that calibrated weights
produce target marginals to within 1e-4 in `tests/testthat/test-03-rake.R`.

---

## adjust_nonresponse() — No Vendored File

The `adjust_nonresponse()` function uses the weighting-class nonresponse
adjustment method. This is a standard procedure in survey statistics and does
not originate from a specific package. Implementation is based on the
closed-form formula:

> For each weighting class `c`, the adjusted weight for respondent `i` in
> class `c` is: `w_adjusted_i = w_i * (sum(w_j, j in c) / sum(w_j, j in c, j responded))`

This formula redistributes the total weight of non-respondents to respondents
within the same weighting class, preserving total weight. Correctness is
validated via hand-calculation in `tests/testthat/test-05-nonresponse.R`
(see test item 5b in spec §XIII).
