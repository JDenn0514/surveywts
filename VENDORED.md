# External Algorithm Delegation

This file documents the external packages that `surveywts` delegates
calibration algorithms to, and algorithms that were ported from external
packages into internal helpers. Delegated packages are listed in
`DESCRIPTION` Imports; ported packages are in `Suggests`.

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

## anesrake (ported — `Suggests` only)

| Field | Value |
|-------|-------|
| Author | Josh Pasek |
| License | GPL-2+ |
| CRAN URL | <https://cran.r-project.org/package=anesrake> |

**Status:** Algorithm ported to `R/rake-anesrake-engine.R` as internal helpers.
`anesrake` is no longer an `Imports` dependency — it is listed in `Suggests`
and used only for numerical parity tests.

**Ported internal helpers (in `R/rake-anesrake-engine.R`):**

- `.rake_anesrake()` — top-level engine; replaces `anesrake::anesrake()`
- `.rake_list()` — iterative proportional fitting loop with capping; replaces
  `anesrake::rakelist()`
- Supporting helpers ported from anesrake source

**Notes:**

- The ported engine preserves `force1 = FALSE` semantics (total weight is
  conserved, consistent with `survey::rake()` behaviour).
- Convergence is detected from a character field on the result:
  `"Complete convergence was achieved"` or `"Results are stable..."`.
- When all variables already meet their margins, `.rake_anesrake()` emits a
  `surveywts_message_already_calibrated` message (matching the original).
- `cap = NULL` correctly means no cap (`Inf` internally). Previously, delegating
  to `anesrake::anesrake()` silently applied the package default of `cap = 5`.
- Pre-cap weight vectors are captured after each full variable sweep and
  returned as the `capping` field in `weighting_history` entries.

**Numerical correctness verified** against `anesrake::anesrake()` within
1e-8 tolerance in `tests/testthat/test-03-rake.R` (parity tests guarded with
`skip_if_not_installed("anesrake")`).

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
