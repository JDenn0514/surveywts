# Spec: Port anesrake Engine + Pre-Cap Weights

**Date:** 2026-05-11
**Status:** Draft — pending implementation plan
**Scope:** `method = "anesrake"` path in `rake()`

---

## Background

The current `method = "anesrake"` path in `.calibrate_engine()` delegates to
`anesrake::anesrake()` as a black box. This means:

1. The pre-cap weight state is destroyed inside the external package and
   never returned.
2. `anesrake` is an `Imports` dependency even though it is a self-contained
   algorithm we can own.

The ANES weighting methodology (DeBell & Krosnick 2009, step 9d) explicitly
calls for recording the original uncapped weights at each capping step "for
later review and to permit documentation of the extent of capping." The
current implementation cannot satisfy this requirement.

**References:**
- DeBell, Matthew, and Jon A. Krosnick. 2009. "Computing Weights for
  American National Election Study Survey Data." ANES Technical Report
  nes012427. https://electionstudies.org/
- Pasek, Josh (with help from Jon Krosnick and some code from Alex Tahk and
  others). anesrake: ANES Raking Implementation.
  https://CRAN.R-project.org/package=anesrake

---

## Goal

Port the anesrake algorithm into surveywts as internal helpers, capturing the
pre-cap weight vector inside the raking loop and surfacing it in the
weighting history entry. Drop `anesrake` from `Imports`; move to `Suggests`
for test-only parity checking.

The public API of `rake()` is unchanged — no new arguments, no changed
return type. Pre-cap data surfaces only in `weighting_history`.

---

## Files Changed

| File | Change |
|---|---|
| `R/rake-anesrake-engine.R` | **New.** All ported internal helpers with attribution header. |
| `R/utils.R` | Replace `anesrake::anesrake()` call block with call to new internal engine. Thread `capping` result out. |
| `R/rake.R` | Pass `capping` from engine result into `.make_history_entry()`. |
| `R/utils.R` (`.make_history_entry()`) | Add optional `capping = NULL` parameter; include in returned list. |
| `DESCRIPTION` | Move `anesrake` from `Imports` to `Suggests`. |
| `tests/testthat/test-03-rake.R` | Add parity tests against `anesrake::anesrake()` and pre-cap history tests. |

No other files change.

---

## Section 1: The Ported Engine (`R/rake-anesrake-engine.R`)

A minimal port of the anesrake algorithm retaining only the code paths
reachable via the current `rake()` public API. Paths not exposed by `rake()`
are removed rather than kept dormant. Style is adapted by running `air` and
replacing `%>%` with `|>`.

**Removed from the original (not reachable via `rake()`):**

- `type` variants `"nlim"`, `"nmin"`, `"nmax"` — `rake()` always passes
  `type = "pctlim"`; removed from `.rake_anesrake()` and
  `.rake_select_n_highest()` removed entirely
- `filter` parameter — `rake()` always passes the full dataset
- `verbose` parameter and all progress print calls
- `force1` normalization — `rake()` always passes `force1 = FALSE`; inline
  removed (targets already proportions from `.calibrate_engine()`)
- Non-factor discrep methods — `.rake_discrep.default()`,
  `.rake_discrep.logical()`, `.rake_discrep.numeric()`, and `.wpct()`;
  `rake()` always converts variables to factor before calling the engine
- Unused `choosemethod` aggregation methods in `.rake_find_discrepancies()`:
  `"totalsquared"`, `"maxsquared"`, `"averagesquared"`;
  `rake()` exposes `"total"`, `"max"`, and `"average"` via `control$variable_select`
- The `if (g %in% seq(100, 10000, 50))` progress print in `.rake_list()`
- `tostop = 0, warn = 1` path in `.rake_select_by_pct()` — only called from
  removed nmin/nmax paths; the `warn = 0` silent path is kept (used by the
  pctlim iterate loop)

**Attribution header** (top of file):

```r
# R/rake-anesrake-engine.R
#
# Internal raking engine for method = "anesrake".
#
# Algorithm and logic ported from the anesrake R package:
#   Pasek, Josh (with help from Jon Krosnick and some code from
#   Alex Tahk and others). anesrake: ANES Raking Implementation.
#   https://CRAN.R-project.org/package=anesrake
#
# Weighting methodology from:
#   DeBell, Matthew, and Jon A. Krosnick. 2009. "Computing Weights for
#   American National Election Study Survey Data." ANES Technical Report
#   nes012427. https://electionstudies.org/
#
# Changes from the original (beyond style/formatting):
#   - Only code paths reachable via rake() are retained
#   - .rake_list() captures pre-cap weight vector before each capping step
#     and returns it in the result (the original destroys this state)
```

**Helpers in the ported engine:**

| Internal helper | Ported from |
|---|---|
| `.rake_discrep()` | `discrep.R` + `discrep.factor.R` only |
| `.rake_on_var()` | `rakeonvar.R` + `rakeonvar.default.R` |
| `.rake_find_discrepancies()` | `anesrakefinder.R` — `"total"`, `"max"`, `"average"` only |
| `.rake_select_by_pct()` | `selecthighestpcts.R` — `tostop=1` and silent `tostop=0` paths |
| `.rake_list()` | `rakelist.R` — plus pre-cap snapshot; minus verbose/progress prints |
| `.rake_anesrake()` | `anesrake.R` — `type = "pctlim"` path only |

**The only algorithmic change — inside `.rake_list()`:**

```r
# After each full sweep through all variables:
for (i in names(inputter)) {
  weightvec <- .rake_on_var(...)
}
precap_weightvec <- weightvec          # snapshot before truncation
while (max(weightvec) > cap + 1e-04) {
  weightvec <- pmin(weightvec, cap)
  weightvec <- weightvec / mean(weightvec)
}
```

`precap_weightvec` is overwritten each iteration. After the convergence loop
exits it holds the pre-cap state from the final converged iteration — exactly
what the ANES paper asks to record. `.rake_list()` returns it alongside the
final weights.

---

## Section 2: The `capping` Result and History Entry

**`.rake_list()` return value gains:**

```r
list(
  weightvec        = weightvec,
  iterations       = g,
  converge         = converge,
  nonconvergence   = diferr,
  precap_weightvec = precap_weightvec    # NEW
)
```

**`.calibrate_engine()` return value for `type = "anesrake"` gains:**

```r
list(
  weights    = new_weights,
  convergence = list(...),
  capping    = list(
    applied        = any(precap > cap),
    cap_threshold  = cap,
    n_capped       = sum(precap > cap),
    max_precap     = max(precap),
    mean_excess    = mean(precap[precap > cap] - cap),  # NA if none capped
    precap_weights = precap
  )
)
```

`capping` is `NULL` when `cap = NULL`. When a cap is set but no weight ever
exceeded it, `applied = FALSE` and `n_capped = 0L` — the vector is still
stored so the user can confirm nothing was truncated.

**`.make_history_entry()` gains one optional parameter:**

```r
.make_history_entry <- function(
  step, operation, weight_col, call_str,
  parameters, before_stats, after_stats,
  convergence = NULL,
  capping = NULL          # NEW
)
```

The returned list includes `capping` as a top-level key, parallel to
`convergence`:

```r
list(
  step            = ...,
  operation       = ...,
  weight_col      = ...,
  timestamp       = ...,
  call            = ...,
  parameters      = ...,
  weight_stats    = list(before = ..., after = ...),
  convergence     = ...,
  capping         = capping,    # NULL for all non-raking operations
  package_version = ...
)
```

`rake()` extracts `engine_result$capping` and passes it to
`.make_history_entry()`. All other callers (`calibrate()`, `poststratify()`,
`adjust_nonresponse()`) do not pass `capping`, so it defaults to `NULL`.

---

## Section 3: `DESCRIPTION` and Testing

**`DESCRIPTION`:** Move `anesrake` from `Imports` to `Suggests`. No version
pin required — used only in tests.

**Tests added to `tests/testthat/test-03-rake.R`:**

*Output parity against `anesrake::anesrake()`* — verifies the ported engine
produces identical final weights. Uses `skip_if_not_installed("anesrake")`
inside the block. Tolerance `1e-10`.

```r
test_that("rake() method = 'anesrake' matches anesrake::anesrake() output", {
  skip_if_not_installed("anesrake")
  # compare weight vectors
  expect_equal(surveywts_weights, anesrake_weights, tolerance = 1e-10)
})
```

*Pre-cap history — three blocks:*

```r
test_that("rake() history capping is NULL when cap = NULL", { ... })

test_that("rake() history capping$applied is FALSE when no weights exceed cap", { ... })

test_that("rake() history capping records pre-cap weights and summary correctly", {
  # small dataset + tight cap that will definitely fire
  # verify n_capped, max_precap, mean_excess, and that
  # precap_weights[i] >= cap wherever final weight == cap
})
```

---

## Bug Fix Included in This Port

The current `.calibrate_engine()` contains:

```r
anesrake_cap <- calibration_spec$cap %||% 5
```

This means `cap = NULL` (the `rake()` default, documented as "no cap") silently
applies a cap of 5. This contradicts `rake()`'s own documentation.

The port fixes this: when `cap = NULL`, the internal engine uses `Inf` (effectively
no capping), and the capping block never fires. The `capping` history key is `NULL`.

---

## What Does Not Change

- `rake()` public signature — no new arguments
- `rake()` return type — still `weighted_df` or survey object
- `method = "survey"` path — untouched
- All other callers of `.make_history_entry()` — `capping` defaults to `NULL`
- Error classes and messages — none added or changed
