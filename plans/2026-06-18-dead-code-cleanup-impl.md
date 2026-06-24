# Dead Code Cleanup — `utils.R` and `calibrate-utils.R` — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove dead code accumulated after `calibrate_greg.R` was deleted in PR 4, then rename and relocate the surviving anesrake engine to the correct file.

**Architecture:** Three sequential tasks. Task 1 prunes dead branches inside two functions in `utils.R`. Task 2 cleans up `calibrate-utils.R` (dead duplicate definition + stale comment references). Task 3 renames both functions, drops the now-unused `method =` argument, moves them to `calibrate-utils.R`, updates both call sites in `calibrate_rake.R`, and syncs all table-of-contents comments. No new tests are written — existing tests serve as the regression net for all three tasks.

**Tech Stack:** R, `devtools::test()`, `devtools::check()`

## Global Constraints

- No behavioral changes — this is pure dead code removal and reorganization
- No tests should change (dead branches have no coverage; renamed functions are behavior-neutral)
- All `.`-prefixed functions remain unexported
- `devtools::check()` must pass with 0 errors, 0 warnings after Task 3

---

### Task 1: Delete dead branches from `utils.R`

**Files:**
- Modify: `R/utils.R`

**Background:** `.calibrate_engine()` contains three `# nocov start/end` blocks for calibration types that were only called from `calibrate_greg.R`, which was deleted in PR 4. `.throw_not_converged_zero_maxit()` contains one `# nocov start/end` block for the same deleted callers. This task deletes those four dead blocks. The functions remain in `utils.R` and keep their current names — that move happens in Task 3.

After this task `.calibrate_engine()` has exactly two live paths:
1. The `maxit == 0` guard → `.throw_not_converged_zero_maxit(method, control)`
2. The anesrake branch (`if (type == "anesrake") { ... }`)

And `.throw_not_converged_zero_maxit()` has a single, unconditional `cli_abort()`.

- [ ] **Step 1: Establish baseline — run existing tests**

```bash
cd /Users/jacobdennen/surveywts
Rscript -e "devtools::test()" 2>&1 | tail -20
```

All tests should pass before any edits. If tests are already failing, stop and investigate before continuing.

- [ ] **Step 2: Delete the linear/logit + ipf dead block from `.calibrate_engine()`**

In `R/utils.R`, locate `.calibrate_engine()` at line 781. Delete the block from `# nocov start` (line 790) through `# nocov end` (line 1024). This removes the comment explaining the dead branches, the `if (type %in% c("linear", "logit"))` block (~lines 795–947), and the `if (type == "ipf")` block (~lines 949–1024).

The result: after `vars_spec <- calibration_spec$variables` (line 788), the next line is the blank line before the anesrake comment `# ---- Anesrake ...` (currently line 1026).

Verify the edit left the anesrake block intact:

```bash
grep -n "type == .anesrake." R/utils.R
```

Expected: one line around what was line 1027 (now much earlier in the file).

- [ ] **Step 3: Delete the poststratify dead block from `.calibrate_engine()`**

In `R/utils.R`, after the anesrake block's closing `return(...)` and `}`, find the next `# nocov start` (was line 1177). Delete from that `# nocov start` through the matching `# nocov end` (was line 1210). This removes the entire `if (type == "poststratify") { ... }` block.

- [ ] **Step 4: Delete the catch-all `cli_abort` dead block from `.calibrate_engine()`**

In `R/utils.R`, immediately after the poststratify block you just deleted, find the remaining `# nocov start` (was line 1212). Delete from that `# nocov start` through its `# nocov end` (was line 1220) and the closing `}` of `.calibrate_engine()` (was line 1221).

The closing `}` for `.calibrate_engine()` is now the `}` that closes the anesrake `if` block's `return(...)`. Wait — the anesrake block ends with `return(list(...))` at what was line 1175, then `}` closes the `if (type == "anesrake")` block. The function itself closes on line 1221. After deleting the poststratify and catch-all blocks, the function's closing `}` immediately follows the anesrake block's closing `}`.

To verify the function boundary is correct after all three deletions:

```bash
grep -n "^\.calibrate_engine\|^}" R/utils.R | grep -A5 "calibrate_engine"
```

The function should end with two consecutive `}` lines: first closing `if (type == "anesrake")`, then closing the function.

- [ ] **Step 5: Delete the dead branch from `.throw_not_converged_zero_maxit()`**

In `R/utils.R`, find `.throw_not_converged_zero_maxit()` (was line 1227). Its current structure is:

```r
.throw_not_converged_zero_maxit <- function(method, control) {

  # nocov start
  # linear/logit branch: unreachable ...
  if (method %in% c("linear", "logit")) {
    cli::cli_abort(...)
  } else {
  # nocov end
    cli::cli_abort(
      c(
        "x" = "Raking did not converge after 0 iterations.",
        "i" = "Setting {.code control$maxit = 0} means no raking is attempted.",
        "v" = "Set {.code control$maxit} to a positive integer."
      ),
      class = "surveywts_error_calibration_not_converged"
    )
  }
}
```

Delete the `# nocov start` line, the comment line, the `if (method %in% c("linear", "logit")) { cli_abort(...) } else {` lines (and the dead `cli_abort()` inside), and the `# nocov end` line. Also remove the stray `}` that closed the `else` block.

The function body after this edit is a single unconditional `cli_abort()`:

```r
.throw_not_converged_zero_maxit <- function(method, control) {
  cli::cli_abort(
    c(
      "x" = "Raking did not converge after 0 iterations.",
      "i" = "Setting {.code control$maxit = 0} means no raking is attempted.",
      "v" = "Set {.code control$maxit} to a positive integer."
    ),
    class = "surveywts_error_calibration_not_converged"
  )
}
```

Note: `method` and `control` remain in the signature for now — they get dropped in Task 3.

- [ ] **Step 6: Verify tests still pass**

```bash
Rscript -e "devtools::test()" 2>&1 | tail -20
```

Expected: same pass count as Step 1 baseline, no failures.

- [ ] **Step 7: Commit**

```bash
git checkout -b chore/dead-code-cleanup
git add R/utils.R
git commit -m "chore(utils): delete dead calibrate_greg branches from .calibrate_engine() and .throw_not_converged_zero_maxit()"
```

---

### Task 2: Clean up `calibrate-utils.R`

**Files:**
- Modify: `R/calibrate-utils.R`

**Background:** `calibrate-utils.R` has two problems. (1) It defines `.validate_reference_design()` at lines 138–159, but `utils.R` defines the same function later (lines 172–190 in the original). Because there is no `Collate:` field in DESCRIPTION, R loads files alphabetically and `utils.R` silently overwrites the `calibrate-utils.R` copy — making it dead code. (2) The file header and several error message strings reference `calibrate_greg()`, which no longer exists. Both problems are fixed here.

- [ ] **Step 1: Confirm which `.validate_reference_design()` is live**

Verify `utils.R` still has its own copy (it should — we didn't touch it in Task 1):

```bash
grep -n "validate_reference_design" R/utils.R R/calibrate-utils.R
```

Expected output shows the function defined in both files. The `utils.R` copy is live; the `calibrate-utils.R` copy is the shadowed duplicate that we will delete.

- [ ] **Step 2: Delete the shadowed `.validate_reference_design()` from `calibrate-utils.R`**

In `R/calibrate-utils.R`, delete lines 129–159: the section header comment block starting with `# ---` and ending after `invisible(TRUE)` and the closing `}`. The exact text to delete is:

```r
# ---------------------------------------------------------------------------
# .validate_reference_design() — validates reference_design argument
# ---------------------------------------------------------------------------

# Validates the reference_design argument. Returns invisible(TRUE) if valid.
# Throws surveywts_error_reference_design_not_taylor if non-NULL and not taylor.
#
# Arguments:
#   reference_design : user-supplied reference_design argument
.validate_reference_design <- function(reference_design) {
  if (!is.null(reference_design)) {
    if (!S7::S7_inherits(reference_design, surveycore::survey_taylor)) {
      cls <- class(reference_design)[[1L]]
      cli::cli_abort(
        c(
          "x" = paste0(
            "{.arg reference_design} must be a {.cls survey_taylor} object ",
            "or {.code NULL}."
          ),
          "i" = "Got {.cls {cls}}.",
          "v" = paste0(
            "Pass a {.cls survey_taylor} design as {.arg reference_design}, ",
            "or set {.code reference_design = NULL} to omit."
          )
        ),
        class = "surveywts_error_reference_design_not_taylor"
      )
    }
  }
  invisible(TRUE)
}
```

After deletion, verify only one definition remains across the package:

```bash
grep -rn "^\.validate_reference_design" R/
```

Expected: exactly one result, in `R/utils.R`.

- [ ] **Step 3: Update the file header comment**

In `R/calibrate-utils.R`, line 4 currently reads:

```r
# Used by calibrate_greg() and calibrate_rake().
```

Replace it with:

```r
# Used by calibrate_rake(), calibrate_linear(), and calibrate_logit().
```

- [ ] **Step 4: Remove `calibrate_greg` from error message `"v"` bullets in `.parse_margins()` and siblings**

In `R/calibrate-utils.R`, search for all remaining occurrences of `calibrate_greg`:

```bash
grep -n "calibrate_greg" R/calibrate-utils.R
```

Each occurrence is a `"v"` bullet in a `cli_abort()` call that reads:

```r
"See {.fn calibrate_rake} or {.fn calibrate_greg} documentation ",
```

Replace every such line with:

```r
"See {.fn calibrate_rake}, {.fn calibrate_linear}, or {.fn calibrate_logit} documentation ",
```

There are four such occurrences. Apply the replacement to all four.

- [ ] **Step 5: Remove remaining `calibrate_greg` references from internal comments**

Still in `R/calibrate-utils.R`, find any remaining comment lines that reference `calibrate_greg()`:

```bash
grep -n "calibrate_greg" R/calibrate-utils.R
```

This may include comments in `.build_calibration_provenance()` (around the original line 167). Update them to name the current callers (`calibrate_rake()`, `calibrate_linear()`, `calibrate_logit()`). Delete any comment that says something like "old calibrate_greg() callers".

- [ ] **Step 6: Verify no `calibrate_greg` references remain in `calibrate-utils.R`**

```bash
grep "calibrate_greg" R/calibrate-utils.R
```

Expected: no output.

- [ ] **Step 7: Run tests**

```bash
Rscript -e "devtools::test()" 2>&1 | tail -20
```

Expected: all tests pass. If the deleted `.validate_reference_design()` was somehow under test via `calibrate-utils.R` directly (it shouldn't be), you'll see failures — investigate before continuing.

- [ ] **Step 8: Commit**

```bash
git add R/calibrate-utils.R
git commit -m "chore(utils): delete shadowed .validate_reference_design() and remove calibrate_greg references from calibrate-utils.R"
```

---

### Task 3: Rename, drop `method=`, move functions, update call sites and comments

**Files:**
- Modify: `R/utils.R`
- Modify: `R/calibrate-utils.R`
- Modify: `R/calibrate_rake.R`
- Modify: `R/calibrate_to_survey.R`

**Background:** After Tasks 1 and 2, `.calibrate_engine()` is exclusively an anesrake wrapper. This task renames it to `.anesrake_engine()`, drops the now-unused `method =` argument from it and from `.throw_not_converged_zero_maxit()`, updates both call sites in `calibrate_rake.R`, moves both functions from `utils.R` into `calibrate-utils.R` (where they belong alongside `.calibrate_nr_engine()`), and updates the table-of-contents comments in both files.

**Critical invariant:** The rename + call-site updates must land in the same commit. An intermediate state where `.anesrake_engine()` is defined but `.calibrate_engine()` is still called (or vice versa) will break `devtools::test()`. Do all edits before running tests.

- [ ] **Step 1: Rename the function signature in `utils.R`**

In `R/utils.R`, find the line (after Task 1 edits, it should be around line 781 still):

```r
.calibrate_engine <- function(data_df, weights_vec, calibration_spec, method, control) {
```

Replace it with (dropping `method`):

```r
.anesrake_engine <- function(data_df, weights_vec, calibration_spec, control) {
```

- [ ] **Step 2: Update the `.throw_not_converged_zero_maxit()` call inside `.anesrake_engine()`**

Inside the newly renamed function, the first `if` block currently calls:

```r
    .throw_not_converged_zero_maxit(method, control)
```

Replace with:

```r
    .throw_not_converged_zero_maxit(control)
```

- [ ] **Step 3: Drop `method` from `.throw_not_converged_zero_maxit()` signature**

In `R/utils.R`, find:

```r
.throw_not_converged_zero_maxit <- function(method, control) {
```

Replace with:

```r
.throw_not_converged_zero_maxit <- function(control) {
```

- [ ] **Step 4: Update call site 1 in `calibrate_rake.R`**

In `R/calibrate_rake.R`, find the block starting around line 401 (search: `engine_result <- .calibrate_engine`). The current call is:

```r
    engine_result <- .calibrate_engine(
      data_df = plain_df,
      weights_vec = weights_vec,
      calibration_spec = calibration_spec,
      method = engine_method,
      control = control_resolved
    )
```

Replace with (rename + drop `method =`):

```r
    engine_result <- .anesrake_engine(
      data_df = plain_df,
      weights_vec = weights_vec,
      calibration_spec = calibration_spec,
      control = control_resolved
    )
```

- [ ] **Step 5: Update call site 2 in `calibrate_rake.R`**

In `R/calibrate_rake.R`, find the second call site around line 588 (search: `rep_engine <- .calibrate_engine`). The current call is:

```r
              rep_engine <- .calibrate_engine(
                data_df          = plain_df,
                weights_vec      = rep_wt,
                calibration_spec = rep_cal_spec,
                method           = "anesrake",
                control          = control_resolved
              )
```

Replace with:

```r
              rep_engine <- .anesrake_engine(
                data_df          = plain_df,
                weights_vec      = rep_wt,
                calibration_spec = rep_cal_spec,
                control          = control_resolved
              )
```

- [ ] **Step 6: Move both functions from `utils.R` to `calibrate-utils.R`**

In `R/utils.R`, cut the entire `.anesrake_engine()` function block (from the `# ===` section header comment through the closing `}`) and the `.throw_not_converged_zero_maxit()` function block (from its comment through its closing `}`). Paste both at the end of `R/calibrate-utils.R`.

Keep the section separator comment style consistent with the rest of `calibrate-utils.R` (use `# ---` dividers, not `# ===`).

The pasted block at the end of `calibrate-utils.R` should look like:

```r
# ---------------------------------------------------------------------------
# .throw_not_converged_zero_maxit() — error helper for maxit = 0 case
# ---------------------------------------------------------------------------

# Throws surveywts_error_calibration_not_converged when control$maxit == 0.
# Only caller: .anesrake_engine().
.throw_not_converged_zero_maxit <- function(control) {
  cli::cli_abort(
    c(
      "x" = "Raking did not converge after 0 iterations.",
      "i" = "Setting {.code control$maxit = 0} means no raking is attempted.",
      "v" = "Set {.code control$maxit} to a positive integer."
    ),
    class = "surveywts_error_calibration_not_converged"
  )
}

# ---------------------------------------------------------------------------
# .anesrake_engine() — anesrake calibration engine
# ---------------------------------------------------------------------------

# Wraps the internal anesrake engine (.rake_anesrake()). Only caller:
# calibrate_rake(algorithm = "classic_ipf").
#
# Arguments:
#   data_df          : plain data.frame
#   weights_vec      : numeric vector (length = nrow(data_df)),
#                      all positive, no NAs
#   calibration_spec : list with $type = "anesrake", $variables, $total_n,
#                      $cap
#   control          : list with at least $maxit; anesrake defaults already
#                      applied by calibrate_rake()
#
# Returns: list(
#   weights     = <numeric vector of calibrated weights>,
#   convergence = list(converged, iterations, max_error, tolerance),
#   capping     = <list or NULL>
# )
# Throws surveywts_error_calibration_not_converged on failure.
.anesrake_engine <- function(data_df, weights_vec, calibration_spec, control) {
  # Handle maxit = 0: algorithm never runs
  if (isTRUE(control$maxit == 0L) || isTRUE(control$maxit == 0)) {
    .throw_not_converged_zero_maxit(control)
  }

  type <- calibration_spec$type
  vars_spec <- calibration_spec$variables

  # ---- Anesrake (via internal .rake_anesrake()) ----------------------------
  if (type == "anesrake") {
    [... paste the full anesrake block from utils.R here verbatim ...]
  }
}
```

The `[... paste ...]` placeholder above means: copy the entire `if (type == "anesrake") { ... }` block from `R/utils.R` (everything from the `if` line through its closing `}`) without modification. Do not retype it — paste it.

- [ ] **Step 7: Fix stale `.calibrate_engine()` reference in `calibrate_to_survey.R` roxygen**

`R/calibrate_to_survey.R` never called `.calibrate_engine()` in code, but line 156 of its `@section Convergence:` documentation incorrectly names it:

Current (line ~156):
```r
#'   Convergence failure in any `.calibrate_engine()` or `survey::calibrate()`
```

`calibrate_to_survey()` internally calls `.calibrate_opsomer_single()`, which in turn calls `survey::calibrate()`. Replace with:

```r
#'   Convergence failure in any `.calibrate_opsomer_single()` or `survey::calibrate()`
```

Verify the reference is gone:
```bash
grep "calibrate_engine" R/calibrate_to_survey.R
```

Expected: no output.

- [ ] **Step 9: Remove remaining `calibrate_greg` references from `utils.R`**

After Step 6, `R/utils.R` still contains three `calibrate_greg` references outside the (already deleted) dead branches. The verification grep catches all of them:

```bash
grep -n "calibrate_greg" R/utils.R
```

Fix each one:

**Line ~344** — in `.validate_calibration_variables()`, live error message code:

Current:
```r
      fn_name <- if (context == "Calibration") "calibrate_greg" else "calibrate_rake"
```

Replace with:
```r
      fn_name <- if (context == "Calibration") "calibrate_linear" else "calibrate_rake"
```

(`calibrate_linear()` is the primary GREG function that replaced `calibrate_greg()`.)

**Line ~633** — comment inside `.update_survey_weights()`:

Current text includes: `"Used by calibrate_greg(), calibrate_rake(), calibrate_poststrat(), ..."`

Update to remove `calibrate_greg()`: `"Used by calibrate_rake(), calibrate_linear(), calibrate_logit(), calibrate_poststrat(), ..."`

**Line ~682** — comment inside `.check_input_class()`:

Current text includes: `"(calibrate_greg, calibrate_rake, calibrate_poststrat, calibrate)"`

Update to: `"(calibrate_rake, calibrate_linear, calibrate_logit, calibrate_poststrat, calibrate)"`

Verify no references remain:

```bash
grep "calibrate_greg" R/utils.R
```

Expected: no output.

- [ ] **Step 8: Update the `utils.R` table-of-contents comment**

At the top of `R/utils.R` (lines 1–30 area), find the `#   .calibrate_engine()` entry and delete it. The entry reads:

```r
#   .calibrate_engine()               — dispatches to calibration algorithms
```

Delete that line entirely.

- [ ] **Step 11: Update the `calibrate-utils.R` function list**

At the top of `R/calibrate-utils.R`, the header currently ends at line 5. The file has no explicit function list (unlike `utils.R`). Add the two new functions to the header:

Replace:

```r
# R/calibrate-utils.R
#
# Calibration-family shared helpers.
# Used by calibrate_rake(), calibrate_linear(), and calibrate_logit().
```

With:

```r
# R/calibrate-utils.R
#
# Calibration-family shared helpers.
# Used by calibrate_rake(), calibrate_linear(), and calibrate_logit().
#
# Contents (in addition to helpers defined below .parse_margins()):
#   .anesrake_engine()                — anesrake calibration engine
#   .throw_not_converged_zero_maxit() — error for maxit = 0 case
```

- [ ] **Step 12: Run the verification checklist**

```bash
# 1. No remaining references to old name or deleted function
grep -r "calibrate_engine" R/
grep -r "calibrate_greg" R/

# 2. .validate_reference_design() appears in exactly one file
grep -rn "^\.validate_reference_design" R/

# 3. Run tests
Rscript -e "devtools::test()" 2>&1 | tail -30

# 4. Run full check
Rscript -e "devtools::check()" 2>&1 | tail -40
```

Expected:
- `grep -r "calibrate_engine" R/` → no output
- `grep -r "calibrate_greg" R/` → no output
- `grep -rn "^\.validate_reference_design" R/` → exactly one line (in `utils.R`)
- `devtools::test()` → all tests pass
- `devtools::check()` → 0 errors, 0 warnings

- [ ] **Step 13: Commit**

```bash
git add R/utils.R R/calibrate-utils.R R/calibrate_rake.R R/calibrate_to_survey.R
git commit -m "refactor(utils): rename .calibrate_engine() to .anesrake_engine(), drop method= arg, move to calibrate-utils.R"
```

---

## Verification Checklist (final gate before PR)

Run these after Task 3 Step 9 passes:

- [ ] `grep -r "calibrate_engine" R/` returns no results
- [ ] `grep -r "calibrate_greg" R/` returns no results
- [ ] `.validate_reference_design` appears in exactly one file in `R/`
- [ ] `devtools::check()` passes with 0 errors, 0 warnings
- [ ] `devtools::test()` passes (no test changes expected)
