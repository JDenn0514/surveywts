# External Algorithm Delegation

This file documents the external packages that `surveywts` delegates
calibration algorithms to. All packages are listed in `DESCRIPTION` Imports.

---

## survey (>= 4.2-1)

| Field | Value |
|-------|-------|
| Author | Thomas Lumley |
| License | GPL-2+ |
| CRAN URL | <https://cran.r-project.org/package=survey> |

**Functions used by `.calibrate_engine()`:**

- `survey::calibrate()` — GREG linear and logit calibration
- `survey::rake()` — Iterative proportional fitting (IPF)
- `survey::postStratify()` — Post-stratification
- `survey::svydesign()` — Temporary design objects for delegation
- `survey::cal.linear`, `survey::cal.logit` — Calibration function objects

**Numerical correctness verified** against direct `survey::` calls within
1e-8 tolerance in `tests/testthat/test-02-calibrate.R`,
`tests/testthat/test-03-rake.R`, and `tests/testthat/test-04-poststratify.R`.

---

## anesrake (>= 0.80)

| Field | Value |
|-------|-------|
| Author | Josh Pasek |
| License | GPL-2+ |
| CRAN URL | <https://cran.r-project.org/package=anesrake> |

**Functions used by `.calibrate_engine()`:**

- `anesrake::anesrake()` — IPF raking with chi-square variable selection

**Notes:**

- `anesrake::anesrake()` is called with `force1 = FALSE` to preserve
  total weight (consistent with `survey::rake()` behaviour).
- Convergence is detected from the `$converge` character field:
  `"Complete convergence was achieved"` or `"Results are stable..."` are
  treated as converged.
- When all variables already meet their margins, `anesrake::selecthighestpcts()`
  throws an error which is caught and translated to a
  `surveywts_message_already_calibrated` message.

---

## adjust_nonresponse() -- No External Delegation

The `adjust_nonresponse()` function uses the weighting-class nonresponse
adjustment method. This is a standard procedure in survey statistics and does
not originate from a specific package. Implementation is based on the
closed-form formula:

> For each weighting class `c`, the adjusted weight for respondent `i` in
> class `c` is: `w_adjusted_i = w_i * (sum(w_j, j in c) / sum(w_j, j in c, j responded))`

This formula redistributes the total weight of non-respondents to respondents
within the same weighting class, preserving total weight. Correctness is
validated via hand-calculation in `tests/testthat/test-05-nonresponse.R`.
