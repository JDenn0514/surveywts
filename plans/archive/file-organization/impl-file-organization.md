# File Organization Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restructure `R/` so every exported function lives in a file named after it, helpers sit below their owning export, and family-shared helpers live in `{family}-utils.R` files.

**Architecture:** Pure structural refactor — no behavioral changes, no API changes. R loads all files in `R/` together, so helper visibility is unaffected by which file they live in. Each task deletes old source files only after their content has been moved to the new files. Tests pass at every commit.

**Tech Stack:** R, devtools (`devtools::check()`, `devtools::test()`), git mv for tracked renames.

---

## Pre-flight: key facts the implementer must know

- `.rake_anesrake()` and its sub-helpers (defined in `rake-anesrake-engine.R`) are called from `utils.R` via `.calibrate_engine()` — not directly from `rake.R`. Moving them to `rake.R` is fine because all `R/` files are loaded together.
- All replicate helpers (`.validate_replicate_input`, `.validate_replicates_arg`, `.snapshot_variables_for_history`, `.convert_and_call`, `.validate_reference_sample`, `.handle_repweights_overwrite`, `.quasi_randomization_bootstrap`, `.reestimate_margins_from_reference`) are called by both `replicate-weights.R` functions **and** by `nps-group-jackknife.R` — they go in `replicate-utils.R`.
- `.check_weight_utils_class` (in `weight-utils.R`) is ~15 lines with proper error handling — it is **substantive** and goes in the repurposed `weight-utils.R` utils file, not inlined.
- `sample-calibration.R` has **no** shared helpers between its two functions — `sample-calibration-utils.R` is NOT created.
- The current `nonresponse.R` header comment says "No private helpers" — this is stale. `.validate_response_status_binary` (line 1277) is shared by both functions and goes to `nonresponse-utils.R`.
- Test files are **not** renamed. The spec explicitly says no structural test changes are needed.
- Run `devtools::test()` after each task to confirm no breakage before committing.

---

## File map: before → after

| Before | After | Action |
|--------|-------|--------|
| `R/nonprob-ipw.R` | `R/ipw.R` | rename |
| `R/nps-group-jackknife.R` | `R/create_group_jackknife_weights.R` | rename |
| `R/rake-anesrake-engine.R` | *(deleted)* | merged into `rake.R` |
| `R/replicate-print.R` | *(deleted)* | merged into `methods-print.R` |
| `R/classes.R` | `R/weighted-df-dplyr.R` | rename + loses `print.weighted_df` |
| `R/diagnostics.R` | *(deleted)* | split into 4 files |
| `R/sample-calibration.R` | *(deleted)* | split into 2 files |
| `R/nonresponse.R` | *(deleted)* | split into 3 files |
| `R/weight-utils.R` | repurposed as utils file | split into 3 files |
| `R/replicate-weights.R` | *(deleted)* | split into 7 function files + utils |
| `R/replicate-dispatch.R` | *(deleted)* | split into 2 function files |

---

## Task 1: Create feature branch

- [ ] **Step 1: Create and switch to branch**

```bash
git checkout develop
git pull origin develop
git checkout -b refactor/file-organization
```

- [ ] **Step 2: Confirm you're on the right branch**

```bash
git branch --show-current
```

Expected: `refactor/file-organization`

---

## Task 2: Rename `nonprob-ipw.R` → `ipw.R`

**Files:**
- Rename: `R/nonprob-ipw.R` → `R/ipw.R`

- [ ] **Step 1: Rename with git mv**

```bash
git mv R/nonprob-ipw.R R/ipw.R
```

- [ ] **Step 2: Update the file header comment**

Open `R/ipw.R` and change the first comment line from:
```r
# R/nonprob-ipw.R
```
to:
```r
# R/ipw.R
```

- [ ] **Step 3: Run tests**

```r
devtools::test()
```

Expected: all tests pass.

- [ ] **Step 4: Commit**

```bash
git add R/ipw.R
git commit -m "refactor(propensity): rename nonprob-ipw.R to ipw.R"
```

---

## Task 3: Rename `nps-group-jackknife.R` → `create_group_jackknife_weights.R`

**Files:**
- Rename: `R/nps-group-jackknife.R` → `R/create_group_jackknife_weights.R`

- [ ] **Step 1: Rename with git mv**

```bash
git mv R/nps-group-jackknife.R R/create_group_jackknife_weights.R
```

- [ ] **Step 2: Update the file header comment**

Open `R/create_group_jackknife_weights.R` and change the first comment line from:
```r
# R/nps-group-jackknife.R
```
to:
```r
# R/create_group_jackknife_weights.R
```

- [ ] **Step 3: Run tests**

```r
devtools::test()
```

Expected: all tests pass.

- [ ] **Step 4: Commit**

```bash
git add R/create_group_jackknife_weights.R
git commit -m "refactor(replicate-weights): rename nps-group-jackknife.R to create_group_jackknife_weights.R"
```

---

## Task 4: Merge `rake-anesrake-engine.R` into `rake.R`

**Files:**
- Modify: `R/rake.R`
- Delete: `R/rake-anesrake-engine.R`

- [ ] **Step 1: Append the attribution header + engine content to rake.R**

At the very end of `R/rake.R`, add a blank line followed by this attribution block and then the entire content of `R/rake-anesrake-engine.R` (excluding its existing file header comment block, lines 1–24):

```r

# ---------------------------------------------------------------------------
# Ported from the anesrake R package (CRAN: anesrake), GPL-2
# Original author: Cole Rauwerda. Logic unchanged from upstream.
# ---------------------------------------------------------------------------
```

Then paste the body of `rake-anesrake-engine.R` starting from line 25 (the first `# ===` separator before `.rake_discrep`). The complete set of helpers to append:
- `.rake_discrep()`
- `.rake_on_var()`
- `.rake_find_discrepancies()`
- `.rake_select_by_pct()`
- `.rake_list()`
- `.rake_anesrake()`

Use Read to read `R/rake-anesrake-engine.R` and identify the exact content starting from the first section separator (`# ====` line before `.rake_discrep`). Copy that content verbatim.

- [ ] **Step 2: Delete the source file**

```bash
git rm R/rake-anesrake-engine.R
```

- [ ] **Step 3: Run tests**

```r
devtools::test()
```

Expected: all tests pass. The `devtools::test()` output for `test-03-rake.R` should be fully green.

- [ ] **Step 4: Commit**

```bash
git add R/rake.R
git commit -m "refactor(calibration): merge rake-anesrake-engine.R into rake.R"
```

---

## Task 5: Merge `replicate-print.R` into `methods-print.R`; move `print.weighted_df`; rename `classes.R`

This task does three things in one commit to keep the package in a consistent state: the `print.weighted_df` method must be in `methods-print.R` before `classes.R` is renamed.

**Files:**
- Modify: `R/methods-print.R`
- Rename: `R/classes.R` → `R/weighted-df-dplyr.R`
- Delete: `R/replicate-print.R`

- [ ] **Step 1: Add `print.weighted_df` to methods-print.R**

Read `R/classes.R` and locate the `print.weighted_df` function — it starts at the line `print.weighted_df <- function(x, n = 10, ...)` and ends just before the `# ---------------------------------------------------------------------------` separator for `dplyr_reconstruct.weighted_df`. This is the entire function block including its roxygen comments and the `# ---------------------------------------------------------------------------` header comment above it.

In `R/methods-print.R`, add a blank line after the existing last `invisible(x)` return in the `survey_nonprob` print method, then add the `print.weighted_df` block. The section should look like:

```r
# ---------------------------------------------------------------------------
# print.weighted_df()
# ---------------------------------------------------------------------------

#' Print a weighted data frame
#'
#' @param x A `weighted_df` object.
#' @param n Number of rows to show (default 10).
#' @param ... Additional arguments passed to the tibble print method.
#'
#' @return `x`, invisibly.
#'
#' @keywords internal
#' @export
print.weighted_df <- function(x, n = 10, ...) {
  # ... (copy verbatim from classes.R)
}
```

- [ ] **Step 2: Append the `survey_replicate` print method from replicate-print.R**

After the `print.weighted_df` block, add a blank line, then the section header and S7 method from `R/replicate-print.R`. Copy verbatim starting from the existing `# Class defined in...` comment. The end result for the new section looks like:

```r
# ---------------------------------------------------------------------------
# print method for survey_replicate
# ---------------------------------------------------------------------------

# Class defined in surveycore (surveycore::survey_replicate)
S7::method(print, surveycore::survey_replicate) <- function(x, ...) {
  # ... (copy verbatim from replicate-print.R)
}
```

- [ ] **Step 3: Remove `print.weighted_df` from classes.R**

In `R/classes.R`, delete the roxygen block and function body for `print.weighted_df`, including its `# ---------------------------------------------------------------------------` section header comment. The file should now start immediately with the `# ---------------------------------------------------------------------------` header for `dplyr_reconstruct.weighted_df`.

Also update the file header comment block at the top of `classes.R` to remove `print.weighted_df()` from the "Includes:" list.

- [ ] **Step 4: Rename classes.R → weighted-df-dplyr.R**

```bash
git mv R/classes.R R/weighted-df-dplyr.R
```

Update the first comment line of `R/weighted-df-dplyr.R` from `# R/classes.R` to `# R/weighted-df-dplyr.R`.

- [ ] **Step 5: Delete replicate-print.R**

```bash
git rm R/replicate-print.R
```

- [ ] **Step 6: Run tests**

```r
devtools::test()
```

Expected: all tests pass, including `test-replicate-print.R` and `test-00-classes.R`.

- [ ] **Step 7: Commit**

```bash
git add R/methods-print.R R/weighted-df-dplyr.R
git commit -m "refactor(classes): merge print methods; rename classes.R to weighted-df-dplyr.R"
```

---

## Task 6: Split `diagnostics.R`

**Files:**
- Create: `R/effective_sample_size.R`
- Create: `R/weight_variability.R`
- Create: `R/summarize_weights.R`
- Create: `R/diagnostics-utils.R`
- Delete: `R/diagnostics.R`

`diagnostics.R` structure:
- Lines 1–12: file header
- Lines ~14–36: section header for `effective_sample_size`
- Lines 37–73: `effective_sample_size()` function body
- Lines ~74–116: section header + `weight_variability()` function body
- Lines ~118–175: section header + `summarize_weights()` function body
- Lines 176–end: `.diag_validate_input()` helper

- [ ] **Step 1: Create `R/effective_sample_size.R`**

```r
# R/effective_sample_size.R
#
# effective_sample_size() — Kish's ESS formula.
```

Then copy verbatim the roxygen block + function body for `effective_sample_size()` from `R/diagnostics.R` (lines ~17–73).

- [ ] **Step 2: Create `R/weight_variability.R`**

```r
# R/weight_variability.R
#
# weight_variability() — coefficient of variation and related weight spread metrics.
```

Then copy verbatim the roxygen block + function body for `weight_variability()` from `R/diagnostics.R`.

- [ ] **Step 3: Create `R/summarize_weights.R`**

```r
# R/summarize_weights.R
#
# summarize_weights() — tabular weight summary, optionally by group.
```

Then copy verbatim the roxygen block + function body for `summarize_weights()` from `R/diagnostics.R`.

- [ ] **Step 4: Create `R/diagnostics-utils.R`**

```r
# R/diagnostics-utils.R
#
# Internal helpers shared by effective_sample_size(), weight_variability(),
# and summarize_weights().
#
# .diag_validate_input() — class check, weight extraction, and required-weights check.
```

Then copy verbatim the `.diag_validate_input()` function block from `R/diagnostics.R` (line 176 to end of file).

- [ ] **Step 5: Run tests to verify the split**

```r
devtools::test(filter = "diagnostics")
```

Expected: all tests in `test-06-diagnostics.R` pass.

- [ ] **Step 6: Delete diagnostics.R**

```bash
git rm R/diagnostics.R
```

- [ ] **Step 7: Run full test suite**

```r
devtools::test()
```

Expected: all tests pass.

- [ ] **Step 8: Commit**

```bash
git add R/effective_sample_size.R R/weight_variability.R R/summarize_weights.R R/diagnostics-utils.R
git commit -m "refactor(diagnostics): split diagnostics.R into per-function files"
```

---

## Task 7: Split `sample-calibration.R`

**Files:**
- Create: `R/calibrate_to_survey.R`
- Create: `R/calibrate_to_estimate.R`
- Delete: `R/sample-calibration.R`

`sample-calibration.R` structure:
- Lines 1–9: file header
- Lines 10–46: section header for `calibrate_to_survey`
- Lines 47–277: `calibrate_to_survey()` roxygen + function body
- Lines 278–end: `calibrate_to_estimate()` roxygen + function body

There are **no shared helpers** between the two functions — no `sample-calibration-utils.R` is created.

- [ ] **Step 1: Create `R/calibrate_to_survey.R`**

```r
# R/calibrate_to_survey.R
#
# calibrate_to_survey() — calibrate a replicate design to a replicate control survey.
```

Then copy verbatim the roxygen block + function body for `calibrate_to_survey()` (lines 10–277 of `sample-calibration.R`, skipping the first file header block).

- [ ] **Step 2: Create `R/calibrate_to_estimate.R`**

```r
# R/calibrate_to_estimate.R
#
# calibrate_to_estimate() — calibrate a replicate design to external point estimates.
```

Then copy verbatim the roxygen block + function body for `calibrate_to_estimate()` (lines 278–end of `sample-calibration.R`).

- [ ] **Step 3: Run tests to verify the split**

```r
devtools::test(filter = "sample-calibration")
```

Expected: all tests in `test-sample-calibration.R` pass.

- [ ] **Step 4: Delete sample-calibration.R**

```bash
git rm R/sample-calibration.R
```

- [ ] **Step 5: Run full test suite**

```r
devtools::test()
```

Expected: all tests pass.

- [ ] **Step 6: Commit**

```bash
git add R/calibrate_to_survey.R R/calibrate_to_estimate.R
git commit -m "refactor(sample-calibration): split sample-calibration.R into per-function files"
```

---

## Task 8: Split `nonresponse.R`

**Files:**
- Create: `R/adjust_nonresponse.R`
- Create: `R/redistribute_weights.R`
- Create: `R/nonresponse-utils.R`
- Delete: `R/nonresponse.R`

`nonresponse.R` structure:
- Lines 1–10: file header (note: header comment "No private helpers" is **stale** — ignore it)
- Lines 12–916: `adjust_nonresponse()` roxygen + function body
- Lines 917–1275: `redistribute_weights()` roxygen + function body
- Lines 1259–end: `.validate_response_status_binary()` helper (used by both functions)

- [ ] **Step 1: Create `R/adjust_nonresponse.R`**

```r
# R/adjust_nonresponse.R
#
# adjust_nonresponse() — weighting-class, propensity-cell, and propensity
# nonresponse adjustment. Redistributes nonrespondent weights to respondents
# within cells. Returns all rows; nonrespondent weights = 0.
```

Then copy verbatim the `adjust_nonresponse()` roxygen block + function body (lines 12–916 of `nonresponse.R`).

- [ ] **Step 2: Create `R/redistribute_weights.R`**

```r
# R/redistribute_weights.R
#
# redistribute_weights() — general-purpose weight redistribution primitive.
# Transfers weight from a "reduce" group to an "increase" group.
```

Then copy verbatim the `redistribute_weights()` roxygen block + function body (lines 917 through the closing `}` before the helper section, approximately lines 917–1257).

- [ ] **Step 3: Create `R/nonresponse-utils.R`**

```r
# R/nonresponse-utils.R
#
# Internal helpers shared by adjust_nonresponse() and redistribute_weights().
#
# .validate_response_status_binary() — validates binary 0/1 or logical indicator columns.
```

Then copy verbatim the `.validate_response_status_binary()` comment block + function definition (lines ~1259–end of `nonresponse.R`).

- [ ] **Step 4: Run tests to verify the split**

```r
devtools::test(filter = "nonresponse")
```

Expected: all tests in `test-05-nonresponse.R` pass.

- [ ] **Step 5: Delete nonresponse.R**

```bash
git rm R/nonresponse.R
```

- [ ] **Step 6: Run full test suite**

```r
devtools::test()
```

Expected: all tests pass.

- [ ] **Step 7: Commit**

```bash
git add R/adjust_nonresponse.R R/redistribute_weights.R R/nonresponse-utils.R
git commit -m "refactor(nonresponse): split nonresponse.R into per-function files"
```

---

## Task 9: Split `weight-utils.R`

**Files:**
- Create: `R/trim_weights.R`
- Create: `R/stabilize_weights.R`
- Modify: `R/weight-utils.R` → repurposed as family utils file (keep only `.check_weight_utils_class`)

`weight-utils.R` structure:
- Lines 1–9: file header
- Lines 11–94: `.check_weight_utils_class()` helper (substantive — ~15 lines, proper error class)
- Lines 96–395: `trim_weights()` roxygen + function body
- Lines 396–end: `stabilize_weights()` roxygen + function body

**Assessment:** `.check_weight_utils_class` is substantive — it checks 5 input classes with a `cli_abort()`. It stays in a repurposed `weight-utils.R`.

- [ ] **Step 1: Create `R/trim_weights.R`**

```r
# R/trim_weights.R
#
# trim_weights() — clip survey weights to [lower, upper] and redistribute
# the trimmed mass back to untrimmed observations.
```

Then copy verbatim the `trim_weights()` roxygen block + function body from `R/weight-utils.R` (lines 96–395).

- [ ] **Step 2: Create `R/stabilize_weights.R`**

```r
# R/stabilize_weights.R
#
# stabilize_weights() — rescale weights so they sum to n (or group n).
```

Then copy verbatim the `stabilize_weights()` roxygen block + function body from `R/weight-utils.R` (lines 396–end).

- [ ] **Step 3: Rewrite `R/weight-utils.R` as the family utils file**

Replace the entire content of `R/weight-utils.R` with:

```r
# R/weight-utils.R
#
# Internal helpers shared by trim_weights() and stabilize_weights().
#
# .check_weight_utils_class() — class check accepting all 5 input types;
#   errors with surveywts_error_unsupported_class for anything else.
```

Then copy verbatim the `.check_weight_utils_class()` comment block + function definition (lines 11–94 of the original `weight-utils.R`).

- [ ] **Step 4: Run tests**

```r
devtools::test(filter = "weight-utils")
```

Expected: all tests in `test-weight-utils.R` pass.

- [ ] **Step 5: Run full test suite**

```r
devtools::test()
```

Expected: all tests pass.

- [ ] **Step 6: Commit**

```bash
git add R/trim_weights.R R/stabilize_weights.R R/weight-utils.R
git commit -m "refactor(utilities): split weight-utils.R into per-function files"
```

---

## Task 10: Split `replicate-weights.R` and `replicate-dispatch.R`

This is the largest split. It creates 9 new files from 2 old files.

**Files:**
- Create: `R/replicate-utils.R`
- Create: `R/create_bootstrap_weights.R`
- Create: `R/create_jackknife_weights.R`
- Create: `R/create_brr_weights.R`
- Create: `R/create_gen_boot_weights.R`
- Create: `R/create_gen_rep_weights.R`
- Create: `R/create_sdr_weights.R`
- Create: `R/create_replicate_weights.R`
- Create: `R/as_taylor_design.R`
- Delete: `R/replicate-weights.R`
- Delete: `R/replicate-dispatch.R`

`replicate-weights.R` structure (key boundaries):
- Lines 1–590: all shared helpers → `replicate-utils.R`
  - `.validate_replicate_input()` (line 12)
  - `.validate_replicates_arg()` (line 53)
  - `.snapshot_variables_for_history()` (line 90)
  - `.convert_and_call()` (line 113)
  - `.validate_reference_sample()` (line 184)
  - `.handle_repweights_overwrite()` (line 240)
  - `.quasi_randomization_bootstrap()` (line 284)
  - `.reestimate_margins_from_reference()` (line 566)
- Lines 591–838: `create_bootstrap_weights()` section → `create_bootstrap_weights.R`
- Lines 839–925: `create_jackknife_weights()` section → `create_jackknife_weights.R`
- Lines 926–1026: `create_brr_weights()` section → `create_brr_weights.R`
- Lines 1027–1155: `create_gen_boot_weights()` section → `create_gen_boot_weights.R`
- Lines 1156–1226: `create_gen_rep_weights()` section → `create_gen_rep_weights.R`
- Lines 1227–end: `create_sdr_weights()` section → `create_sdr_weights.R`

`replicate-dispatch.R` structure:
- Lines 1–70: `create_replicate_weights()` section → `create_replicate_weights.R`
- Lines 72–end: `as_taylor_design()` section → `as_taylor_design.R`

**Note:** All 8 helpers are called by `create_group_jackknife_weights.R` (formerly `nps-group-jackknife.R`) as well, so they all belong in `replicate-utils.R`.

- [ ] **Step 1: Create `R/replicate-utils.R`**

```r
# R/replicate-utils.R
#
# Internal helpers shared by create_bootstrap_weights(), create_jackknife_weights(),
# create_brr_weights(), create_gen_boot_weights(), create_gen_rep_weights(),
# create_sdr_weights(), and create_group_jackknife_weights().
#
# .validate_replicate_input()        — class/type guard for all create_*_weights()
# .validate_replicates_arg()         — coerce & validate the replicates integer arg
# .snapshot_variables_for_history()  — capture source design structure for history
# .convert_and_call()                — core S7-to-svydesign conversion pipeline
# .validate_reference_sample()       — check reference_sample is survey_taylor
# .handle_repweights_overwrite()     — detect/clear existing replicate weights
# .quasi_randomization_bootstrap()   — QR bootstrap implementation for NPS
# .reestimate_margins_from_reference() — re-derive margins from a replicate control
```

Then copy verbatim lines 1–590 of `R/replicate-weights.R` (all 8 helper functions with their section headers and inline comments). Replace the existing `# R/replicate-weights.R` file header comment block with the new header above.

- [ ] **Step 2: Create `R/create_bootstrap_weights.R`**

```r
# R/create_bootstrap_weights.R
#
# create_bootstrap_weights() — bootstrap replicate weights for
# survey_taylor and survey_nonprob designs.
```

Then copy verbatim the section from `R/replicate-weights.R` starting at the `# ===` section separator before the `create_bootstrap_weights` roxygen (around line 591) through the end of the function body (line 838).

- [ ] **Step 3: Create `R/create_jackknife_weights.R`**

```r
# R/create_jackknife_weights.R
#
# create_jackknife_weights() — jackknife replicate weights.
```

Then copy verbatim the section header + roxygen + function body for `create_jackknife_weights()` (lines ~839–925 of `replicate-weights.R`).

- [ ] **Step 4: Create `R/create_brr_weights.R`**

```r
# R/create_brr_weights.R
#
# create_brr_weights() — balanced repeated replication (Fay variant) weights.
```

Then copy verbatim the section header + roxygen + function body for `create_brr_weights()` (lines ~926–1026 of `replicate-weights.R`).

- [ ] **Step 5: Create `R/create_gen_boot_weights.R`**

```r
# R/create_gen_boot_weights.R
#
# create_gen_boot_weights() — generalized bootstrap replicate weights.
```

Then copy verbatim the section header + roxygen + function body for `create_gen_boot_weights()` (lines ~1027–1155 of `replicate-weights.R`).

- [ ] **Step 6: Create `R/create_gen_rep_weights.R`**

```r
# R/create_gen_rep_weights.R
#
# create_gen_rep_weights() — generalized replication weights.
```

Then copy verbatim the section header + roxygen + function body for `create_gen_rep_weights()` (lines ~1156–1226 of `replicate-weights.R`).

- [ ] **Step 7: Create `R/create_sdr_weights.R`**

```r
# R/create_sdr_weights.R
#
# create_sdr_weights() — successive difference replication (SDR) weights.
```

Then copy verbatim the section header + roxygen + function body for `create_sdr_weights()` (lines ~1227–end of `replicate-weights.R`).

- [ ] **Step 8: Create `R/create_replicate_weights.R`**

```r
# R/create_replicate_weights.R
#
# create_replicate_weights() — dispatcher to the appropriate create_*_weights()
# function based on the method argument.
```

Then copy verbatim the `create_replicate_weights()` section from `R/replicate-dispatch.R` (the roxygen block + function body for `create_replicate_weights`, which is everything from the first section header through the closing `}` of `create_replicate_weights`).

- [ ] **Step 9: Create `R/as_taylor_design.R`**

```r
# R/as_taylor_design.R
#
# as_taylor_design() — convert a survey_replicate back to a survey_taylor
# using the stored replicate_creation history entry.
```

Then copy verbatim the `as_taylor_design()` section from `R/replicate-dispatch.R` (everything from the `# ===` section header through end of file).

- [ ] **Step 10: Run tests before deleting source files**

```r
devtools::test(filter = "replicate")
```

Expected: all tests in `test-replicate-weights.R`, `test-replicate-dispatch.R`, `test-replicate-print.R`, and `test-nps-group-jackknife.R` pass.

- [ ] **Step 11: Delete source files**

```bash
git rm R/replicate-weights.R R/replicate-dispatch.R
```

- [ ] **Step 12: Run full test suite**

```r
devtools::test()
```

Expected: all tests pass.

- [ ] **Step 13: Commit**

```bash
git add R/replicate-utils.R R/create_bootstrap_weights.R R/create_jackknife_weights.R \
  R/create_brr_weights.R R/create_gen_boot_weights.R R/create_gen_rep_weights.R \
  R/create_sdr_weights.R R/create_replicate_weights.R R/as_taylor_design.R
git commit -m "refactor(replicate-weights): split replicate-weights.R and replicate-dispatch.R into per-function files"
```

---

## Task 11: Update `.claude/rules/` files

**Files:**
- Modify: `.claude/rules/code-style.md`
- Modify: `.claude/rules/surveywts-conventions.md`
- Modify: `.claude/rules/testing-surveywts.md`

### 11a: Update `code-style.md` — Section 4 internal helper placement

- [ ] **Step 1: Replace the helper placement table**

In `.claude/rules/code-style.md`, find the "Internal helper placement" subsection in Section 4 (currently a two-row table). Replace the entire table and surrounding prose with:

```markdown
### Internal helper placement
| Helper used in... | Lives in... |
|-------------------|-------------|
| Exactly 1 source file | Inline in that function's `.R` file, **below** the exported function |
| 2+ functions in the same family | `{family}-utils.R` |
| 2+ functions across different families | `utils.R` |

All internal helpers are **not exported** and prefixed with `.`.
```

Also update the placement note: helpers go **below** the exported function (the current wording says "before its first call site" — remove that phrase and replace with "below the exported function body").

### 11b: Update `surveywts-conventions.md` — add File Organization section

- [ ] **Step 2: Add a new "File Organization" section to surveywts-conventions.md**

Add the following section after Section 2 (Function Families), renumbering subsequent sections:

```markdown
## 3. File Organization

### Rules
1. Every exported function lives in a `.R` file named identically to it (matching its `.Rd` filename without the extension).
2. The exported function appears at the **top** of its file; helpers used only by that function appear **below** it.
3. Helpers shared by 2+ functions in the same family go to `{family}-utils.R`.
4. Helpers used across different families stay in `utils.R`.
5. Structural/role-based files are exempt from rule 1.

### Exempt structural files

| File | Purpose |
|------|---------|
| `utils.R` | Cross-family internal helpers |
| `methods-print.R` | All S7 and S3 print methods |
| `zzz.R` | `.onLoad()` / `.onAttach()` hooks |
| `data.R` | `@docType data` documentation stubs |
| `surveywts-package.R` | Package-level documentation |

### Family utils files

| File | Shared helpers for |
|------|--------------------|
| `diagnostics-utils.R` | `effective_sample_size()`, `weight_variability()`, `summarize_weights()` |
| `nonresponse-utils.R` | `adjust_nonresponse()`, `redistribute_weights()` |
| `replicate-utils.R` | All `create_*_weights()` functions + `as_taylor_design()` + `create_group_jackknife_weights()` |
| `weight-utils.R` | `trim_weights()`, `stabilize_weights()` |

### File mapping (R/ → export)

| File | Export |
|------|--------|
| `adjust_nonresponse.R` | `adjust_nonresponse()` |
| `as_taylor_design.R` | `as_taylor_design()` |
| `calibrate.R` | `calibrate()` |
| `calibrate_to_estimate.R` | `calibrate_to_estimate()` |
| `calibrate_to_survey.R` | `calibrate_to_survey()` |
| `create_bootstrap_weights.R` | `create_bootstrap_weights()` |
| `create_brr_weights.R` | `create_brr_weights()` |
| `create_gen_boot_weights.R` | `create_gen_boot_weights()` |
| `create_gen_rep_weights.R` | `create_gen_rep_weights()` |
| `create_group_jackknife_weights.R` | `create_group_jackknife_weights()` |
| `create_jackknife_weights.R` | `create_jackknife_weights()` |
| `create_replicate_weights.R` | `create_replicate_weights()` |
| `create_sdr_weights.R` | `create_sdr_weights()` |
| `effective_sample_size.R` | `effective_sample_size()` |
| `ipw.R` | `ipw()` |
| `poststratify.R` | `poststratify()` |
| `rake.R` | `rake()` |
| `redistribute_weights.R` | `redistribute_weights()` |
| `stabilize_weights.R` | `stabilize_weights()` |
| `summarize_weights.R` | `summarize_weights()` |
| `trim_weights.R` | `trim_weights()` |
| `weight_variability.R` | `weight_variability()` |
| `weighted-df-dplyr.R` | dplyr methods for `weighted_df` |
```

### 11c: Update `testing-surveywts.md` — File Mapping table

- [ ] **Step 3: Update the file mapping table in testing-surveywts.md**

Find the "## File Mapping" section. Replace the entire table with:

```markdown
## File Mapping

| Source file(s) | Test file |
|---|---|
| `R/weighted-df-dplyr.R` + constructors | `tests/testthat/test-00-classes.R` |
| `R/calibrate.R` | `tests/testthat/test-02-calibrate.R` |
| `R/rake.R` | `tests/testthat/test-03-rake.R` |
| `R/poststratify.R` | `tests/testthat/test-04-poststratify.R` |
| `R/adjust_nonresponse.R`, `R/redistribute_weights.R`, `R/nonresponse-utils.R` | `tests/testthat/test-05-nonresponse.R` |
| `R/effective_sample_size.R`, `R/weight_variability.R`, `R/summarize_weights.R`, `R/diagnostics-utils.R` | `tests/testthat/test-06-diagnostics.R` |
| `R/calibrate_to_survey.R`, `R/calibrate_to_estimate.R` | `tests/testthat/test-sample-calibration.R` |
| `R/trim_weights.R`, `R/stabilize_weights.R`, `R/weight-utils.R` | `tests/testthat/test-weight-utils.R` |
| `R/create_bootstrap_weights.R`, and other `create_*_weights.R`, `R/replicate-utils.R` | `tests/testthat/test-replicate-weights.R` |
| `R/create_replicate_weights.R`, `R/as_taylor_design.R` | `tests/testthat/test-replicate-dispatch.R` |
| `R/methods-print.R` | `tests/testthat/test-replicate-print.R` |
| `R/ipw.R` | `tests/testthat/test-nonprob-ipw.R` |
| `R/create_group_jackknife_weights.R` | `tests/testthat/test-nps-group-jackknife.R` |
| `R/utils.R` | (tested indirectly via all test files) |
```

- [ ] **Step 4: Commit rules updates**

```bash
git add .claude/rules/code-style.md .claude/rules/surveywts-conventions.md .claude/rules/testing-surveywts.md
git commit -m "docs(rules): update file organization rules and file mapping tables"
```

---

## Task 12: Final check and PR

- [ ] **Step 1: Run `devtools::document()`**

```r
devtools::document()
```

Expected: no NAMESPACE changes (we moved no exports, only reorganized source files). If any `.Rd` files were regenerated, stage them.

- [ ] **Step 2: Run `devtools::check()`**

```r
devtools::check()
```

Expected: 0 errors, 0 warnings, ≤2 pre-approved notes.

- [ ] **Step 3: If check passes, push branch**

```bash
git push -u origin refactor/file-organization
```

- [ ] **Step 4: Open PR via GitHub CLI**

```bash
gh pr create \
  --title "refactor: reorganize R/ so each export lives in its own named file" \
  --base develop \
  --body "$(cat <<'EOF'
## What

Reorganizes `R/` so every exported function lives in a file named after it,
matching its `.Rd` file. Helpers shared within a family move to `{family}-utils.R`.
Pure structural change — no behavioral or API changes.

## Changes

- **Renames:** `nonprob-ipw.R → ipw.R`, `nps-group-jackknife.R → create_group_jackknife_weights.R`, `classes.R → weighted-df-dplyr.R`
- **Merges:** `rake-anesrake-engine.R` → `rake.R`; `replicate-print.R` + `print.weighted_df` → `methods-print.R`
- **Splits:** `diagnostics.R` (→ 3+utils), `sample-calibration.R` (→ 2), `nonresponse.R` (→ 2+utils), `weight-utils.R` (→ 2+utils), `replicate-weights.R` + `replicate-dispatch.R` (→ 8+utils)
- **Rules:** updated `code-style.md`, `surveywts-conventions.md`, `testing-surveywts.md`

## Checklist

- [ ] Tests written and passing (`devtools::test()`)
- [ ] R CMD check: 0 errors, 0 warnings (`devtools::check()`)
- [ ] Roxygen docs updated and `devtools::document()` run
- [ ] PR title is a valid Conventional Commit (`refactor: ...`)
EOF
)"
```

---

## Self-review checklist

- [x] Every exported function from the spec has a corresponding task with a target file
- [x] `sample-calibration-utils.R` correctly omitted (no shared helpers)
- [x] `.check_weight_utils_class` assessed as substantive → stays in `weight-utils.R`
- [x] All 8 replicate helpers confirmed to go in `replicate-utils.R` (used by group-jackknife too)
- [x] `print.weighted_df` move + `classes.R` rename handled in single atomic task
- [x] File header comments updated in all rename/rewrite tasks
- [x] No test file renames (spec explicitly says not required)
- [x] `devtools::test()` run before every delete step
- [x] `devtools::check()` run at the end before PR
- [x] Attribution header included for anesrake merge
