# Implementation Plan: Port anesrake Engine + Pre-Cap Weights

**Spec:** `plans/spec-rake-anesrake-port.md`
**Branch:** `feature/rake-anesrake-port`
**Status:** Draft

---

## Overview

This plan ports the anesrake raking algorithm into surveywts as internal
helpers, replacing the `anesrake::anesrake()` black-box call. The port adds a
single pre-cap weight snapshot inside the raking loop, which is surfaced in the
weighting history entry as a `capping` field. It also fixes a bug where
`cap = NULL` silently applied a cap of 5. `anesrake` moves from `Imports` to
`Suggests` (test-only parity checking).

---

## PR Map

- [ ] PR 1: `feature/rake-anesrake-port` — Port anesrake engine, add pre-cap history, fix cap=NULL bug, drop anesrake from Imports

---

## PR 1: Port anesrake engine + pre-cap weights

**Branch:** `feature/rake-anesrake-port`
**Depends on:** none

**Files (in TDD order — tests first):**
- `tests/testthat/test-03-rake.R` — add 3 pre-cap history tests; update existing cap=NULL test
- `R/rake-anesrake-engine.R` — new file; all ported helpers with attribution header
- `R/utils.R` — update `.make_history_entry()` and `.calibrate_engine()` anesrake block
- `R/rake.R` — pass `engine_result$capping` to `.make_history_entry()`
- `DESCRIPTION` — move `anesrake` from `Imports` to `Suggests`

**Acceptance criteria:**
- [ ] New pre-cap tests confirmed failing (red) before implementation began
- [ ] Updated cap=NULL test confirmed failing (red) before fix applied
- [ ] Existing parity test (`weights match direct anesrake::anesrake() call`) still passes after engine swap
- [ ] All 3 pre-cap history tests pass
- [ ] `devtools::check()` 0 errors, 0 warnings, ≤2 pre-approved notes
- [ ] `devtools::document()` run; NAMESPACE and man/ in sync

---

## Tasks

### Step 1 — Write failing pre-cap history tests

Add 3 new `test_that()` blocks to `tests/testthat/test-03-rake.R`. These will
be red because `capping` does not yet exist in the history entry.

```r
test_that("rake() history capping is NULL when cap = NULL", {
  # call rake() with cap = NULL (the default)
  # extract weighting_history[[1]]$capping
  # expect_null(...)
})

test_that("rake() history capping$applied is FALSE when no weight exceeds cap", {
  # call rake() with a generous cap that no weight will hit
  # expect capping$applied == FALSE, capping$n_capped == 0L
  # expect capping$precap_weights is a numeric vector of length n
})

test_that("rake() history capping records pre-cap weights correctly when cap fires", {
  # use make_surveywts_data(n = 200, seed = 1) + cap = 1.5 (tight, will fire)
  # verify: n_capped > 0, max_precap > cap, mean_excess > 0
  # verify: precap_weights[i] >= cap wherever final weight[i] == cap
  # verify: length(precap_weights) == nrow(data)
})
```

Run `devtools::test(filter = "rake")` — confirm all 3 new tests are **red**.

---

### Step 2 — Update the existing cap=NULL bug-documenting test

The current test `rake(method='anesrake', cap=NULL) substitutes anesrake's
default cap of 5` explicitly validates the bug. Rename it and flip the
expectation to match the fixed behavior: `cap = NULL` means no cap (`Inf`
internally), so `capping` in history must be `NULL`.

```r
test_that("rake(method='anesrake', cap=NULL) applies no cap", {
  # call rake() with cap = NULL
  # expect capping in history is NULL
  # expect max final weight > 5 (proving cap of 5 was NOT applied)
  # Note: requires a dataset that would exceed 5 if left uncapped
})
```

Run `devtools::test(filter = "rake")` — confirm this test is also **red**
(the bug is still present; the test now correctly rejects the buggy behavior).

---

### Step 3 — Confirm parity test baseline (green)

Run the existing parity test:

```
rake(method='anesrake') weights match direct anesrake::anesrake() call (type='prop')
```

Confirm it is **green** before touching any implementation. This is the
regression baseline — it must remain green after the engine swap.

---

### Step 4 — Create `R/rake-anesrake-engine.R`: attribution header + discrep helpers

Create `R/rake-anesrake-engine.R` with the attribution header from the spec.

Port the `discrep` family from anesrake:
- `discrep.R` → `.rake_discrep()` (S3 dispatcher via `UseMethod`)
- `discrep.default.R` → `.rake_discrep.default()`
- `discrep.factor.R` → `.rake_discrep.factor()`
- `discrep.logical.R` → `.rake_discrep.logical()`
- `discrep.numeric.R` → `.rake_discrep.numeric()`

Also port `.rake_on_var()` from `rakeonvar.R` + `rakeonvar.default.R`.

Style: run `air format R/rake-anesrake-engine.R` after each addition.

---

### Step 5 — Port variable-selection helpers

Into `R/rake-anesrake-engine.R`, add:
- `.rake_find_discrepancies()` from `anesrakefinder.R`
- `.rake_select_by_pct()` from `selecthighestpcts.R`
- `.rake_select_n_highest()` from `selectnhighest.R`

Run `air format R/rake-anesrake-engine.R`.

---

### Step 6 — Port `.rake_list()` with pre-cap snapshot

Into `R/rake-anesrake-engine.R`, port `rakelist.R` as `.rake_list()`.

The **only algorithmic change**: immediately after the variable sweep loop and
before the capping `while` block, add:

```r
precap_weightvec <- weightvec
```

`precap_weightvec` is initialized to `weightvec` before the convergence loop
so it is always defined. It is overwritten each iteration; after the loop exits
it holds the final iteration's pre-cap state.

The capping `while` loop condition changes from `range(weightvec)[2]` to
`max(weightvec)` (identical result, cleaner style per `air`).

Return value gains `precap_weightvec`:

```r
out <- list(
  weightvec        = weightvec,
  caseid           = caseid,
  iterations       = g,
  nonconvergence   = diferr,
  converge         = converge,
  varsused         = names(inputter),
  targets          = inputter,
  dataframe        = dataframe,
  prevec           = prevec,
  precap_weightvec = precap_weightvec    # NEW
)
```

Run `air format R/rake-anesrake-engine.R`.

---

### Step 7 — Port `.rake_anesrake()` top-level dispatcher

Into `R/rake-anesrake-engine.R`, port `anesrake.R` as `.rake_anesrake()`.
This is the function `.calibrate_engine()` will call instead of
`anesrake::anesrake()`.

Internal calls update: `rakelist(...)` → `.rake_list(...)`,
`anesrakefinder(...)` → `.rake_find_discrepancies(...)`, etc.

Run `air format R/rake-anesrake-engine.R`.

---

### Step 8 — Update `.make_history_entry()` in `R/utils.R`

Add `capping = NULL` as the last parameter. Include it in the returned list
parallel to `convergence`:

```r
.make_history_entry <- function(
  step, operation, weight_col, call_str,
  parameters, before_stats, after_stats,
  convergence = NULL,
  capping     = NULL    # NEW
) {
  list(
    ...
    convergence     = convergence,
    capping         = capping,    # NEW
    package_version = ...
  )
}
```

No other callers pass `capping`, so they all default to `NULL` automatically.

---

### Step 9 — Update `.calibrate_engine()` anesrake block in `R/utils.R`

Replace the `anesrake::anesrake()` call block (lines ~966–1099) with a call
to `.rake_anesrake()`.

**Fix the `cap = NULL` bug:**

```r
# OLD (buggy):
anesrake_cap <- calibration_spec$cap %||% 5

# NEW (correct):
anesrake_cap <- calibration_spec$cap %||% Inf
```

**Build the `capping` result:**

```r
precap <- result$precap_weightvec
internal_cap <- calibration_spec$cap

capping_result <- if (is.null(internal_cap)) {
  NULL
} else {
  list(
    applied        = any(precap > internal_cap),
    cap_threshold  = internal_cap,
    n_capped       = sum(precap > internal_cap),
    max_precap     = max(precap),
    mean_excess    = if (any(precap > internal_cap)) {
      mean(precap[precap > internal_cap] - internal_cap)
    } else {
      NA_real_
    },
    precap_weights = precap
  )
}
```

**Return:**

```r
return(list(
  weights     = new_weights,
  convergence = list(...),
  capping     = capping_result    # NEW
))
```

---

### Step 10 — Update `rake()` in `R/rake.R`

Extract `capping` from the engine result and pass it to `.make_history_entry()`:

```r
new_weights <- engine_result$weights
convergence <- engine_result$convergence
capping     <- engine_result$capping    # NEW

...

history_entry <- .make_history_entry(
  ...
  convergence = convergence,
  capping     = capping               # NEW
)
```

---

### Step 11 — Move `anesrake` in `DESCRIPTION`

Remove from `Imports`:
```
anesrake (>= 0.80),
```

Add to `Suggests`:
```
anesrake,
```

No version pin in Suggests — used only in tests.

---

### Step 12 — Run `devtools::document()`

Confirm NAMESPACE is unchanged (no new exports, no removed exports). The
`R/rake-anesrake-engine.R` file contains only unexported `.`-prefixed
functions; `devtools::document()` should produce no NAMESPACE changes.

---

### Step 13 — Run `devtools::check()`

Target: 0 errors, 0 warnings, ≤2 pre-approved notes.

---

### Step 14 — Run full test suite; confirm all green

```r
devtools::test(filter = "rake")
```

Verify:
- All pre-existing tests pass (including parity test against `anesrake::anesrake()`)
- 3 new pre-cap history tests pass
- Updated `cap = NULL` test passes (bug is fixed)
- No snapshot regressions

---

### Step 15 — Commit

```
feat(calibration): port anesrake engine and add pre-cap weights to history (#N)
```

---

## Implementation Notes

**S3 dispatch in ported discrep helpers:** The `discrep` family in anesrake
uses `UseMethod("discrep")`. The faithful translation uses
`UseMethod(".rake_discrep")` dispatching to `.rake_discrep.factor()`,
`.rake_discrep.default()`, etc. This is valid R and consistent with the
faithful-translation goal.

**`precap_weightvec` when cap = Inf:** When `cap = NULL` (→ `Inf` internally),
the capping `while` block never fires. `precap_weightvec` still holds the
final converged weights (same as `weightvec`) — but since `capping_result` is
`NULL` in this case, `precap_weightvec` is never read. No correctness concern.

**Existing test referencing the bug:** `rake(method='anesrake', cap=NULL)
substitutes anesrake's default cap of 5` was written to document the current
(buggy) behavior. Step 2 renames and updates it before any implementation
begins — it must be red before the fix is applied.

**`anesrake` parity test uses `skip_if_not_installed`:** The existing parity
test already contains `skip_if_not_installed("anesrake")` inside the block per
project testing standards. It remains valid after the port — it now compares our
internal engine against the original package as a regression guard.
