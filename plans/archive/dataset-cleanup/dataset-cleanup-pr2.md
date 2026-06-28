# Dataset Cleanup PR 2 — Function Surface Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** After PR 1 merges — add three test helpers, replace all `_svy` lazy-load references in tests with helper calls, update all function examples to use inline survey construction, and rename `stabilize_weights()` to `rescale_weights()`.

**Architecture:** Pure surface changes: no new exported functions, no behavior changes. Tests call helpers that construct survey objects on demand. Examples construct inline from package tibbles. `stabilize_weights()` is renamed file-by-file to `rescale_weights()` with no deprecation shim (pre-CRAN).

**Tech Stack:** R, testthat, devtools, `surveycore::as_survey()`, `surveycore::survey_nonprob()`

## Global Constraints

- **PREREQUISITE:** PR 1 (`feature/dataset-cleanup-pr1`) must be squash-merged into `develop` before cutting this branch.
- Branch from `develop`: `feature/dataset-cleanup-pr2`
- Conventional Commits: `test(...)` for test changes, `docs(...)` for example changes, `refactor(weights):` for the rename
- `devtools::document()` required before any commit that touches roxygen2 content
- `devtools::check()` required before opening PR; must pass 0 errors, 0 warnings, ≤2 pre-approved notes
- No deprecation shim for `stabilize_weights()` — clean rename only (pre-CRAN)
- After renaming and updating tests, delete stale snapshots and regenerate via `devtools::test()` — do not run `testthat::snapshot_accept()` blindly; run `testthat::snapshot_review()` to approve each diff individually

---

## Task 1: Create feature branch

**Files:** None changed

- [ ] **Step 1: Verify PR 1 is merged, then branch**

```bash
git checkout develop && git pull
# Confirm _svy objects are gone
Rscript -e "data(package='surveywts')$results[,'Item']" | grep "_svy" || echo "OK: no _svy objects"
git checkout -b feature/dataset-cleanup-pr2
```

Expected: "OK: no _svy objects"; clean branch at HEAD of develop.

---

## Task 2: Add three test helpers to `helper-test-data.R`

**Files:**
- Modify: `tests/testthat/helper-test-data.R`

These helpers replace the pattern of lazy-loading `_svy` objects. Each constructs a fresh survey object from the promoted-weight tibble. They accept no arguments (use package data directly) and are called like functions within tests.

- [ ] **Step 1: Append the three helpers at the bottom of helper-test-data.R**

Open `tests/testthat/helper-test-data.R` and append the following block after the last existing definition:

```r
# ---- Survey object helpers (replace _svy lazy-loaded package data) ----------

make_gss_taylor <- function() {
  data(gss_2024, package = "surveywts", envir = environment())
  surveycore::as_survey(
    gss_2024,
    weights = wtssps,
    strata = vstrat,
    ids = vpsu,
    nest = TRUE
  )
}

make_ns_nonprob <- function() {
  data(ns_wave1, package = "surveywts", envir = environment())
  surveycore::survey_nonprob(
    ns_wave1,
    variables = list(weights = "weight")
  )
}

make_npors_taylor <- function() {
  data(npors_2025_clean, package = "surveywts", envir = environment())
  surveycore::as_survey(
    npors_2025_clean,
    weights = weight,
    strata = stratum
  )
}
```

- [ ] **Step 2: Run the test suite to confirm the helpers are loadable**

```r
devtools::load_all()
# In the helper's context (testthat loads it automatically), test manually:
testthat::test_file("tests/testthat/test-datasets.R")
```

Expected: no "could not find function" errors. The test file doesn't need to USE the helpers yet — just confirm the file sources cleanly.

- [ ] **Step 3: Commit**

```bash
git add tests/testthat/helper-test-data.R
git commit -m "test(helpers): add make_gss_taylor, make_ns_nonprob, make_npors_taylor helpers"
```

---

## Task 3: Update `test-replicate-weights.R` — replace `gss_2024_svy` references

**Files:**
- Modify: `tests/testthat/test-replicate-weights.R`

**Why:** `gss_2024_svy` was lazy-loaded from the package. After PR 1 deletes the `.rda`, any test that accesses `gss_2024_svy` will fail with "object 'gss_2024_svy' not found". Replace all 13 occurrences with `make_gss_taylor()` calls.

- [ ] **Step 1: Find all occurrences in the file**

```bash
grep -n "gss_2024_svy" tests/testthat/test-replicate-weights.R
```

Expected: 13 lines. Note each line number.

- [ ] **Step 2: Replace the inline usage pattern**

The typical test pattern is one of two forms:

**Form A** — `gss_2024_svy` is used directly as an argument with no setup line:
```r
result <- create_bootstrap_weights(gss_2024_svy, ...)
```
Replace with:
```r
result <- create_bootstrap_weights(make_gss_taylor(), ...)
```

**Form B** — `gss_2024_svy` is assigned first:
```r
svy <- gss_2024_svy
result <- create_jackknife_weights(svy, ...)
```
Replace with:
```r
svy <- make_gss_taylor()
result <- create_jackknife_weights(svy, ...)
```

Use grep output from Step 1 to make each replacement individually. Do not use global search-replace — verify each site in context before replacing.

For multi-use blocks where `gss_2024_svy` appears several times in one `test_that()` block, assign the result of `make_gss_taylor()` to a local variable at the top of the block to avoid constructing it repeatedly:

```r
test_that("...", {
  svy <- make_gss_taylor()
  result1 <- create_bootstrap_weights(svy, ...)
  result2 <- create_jackknife_weights(svy, ...)
  ...
})
```

- [ ] **Step 3: Run the replicate weights tests**

```r
devtools::test(filter = "replicate-weights")
```

Expected: all tests pass. Watch for any remaining "object not found" errors.

- [ ] **Step 4: Commit**

```bash
git add tests/testthat/test-replicate-weights.R
git commit -m "test(replicate): replace gss_2024_svy lazy loads with make_gss_taylor()"
```

---

## Task 4: Update `test-nps-jackknife.R` — replace `ns_wave1_svy` references

**Files:**
- Modify: `tests/testthat/test-nps-jackknife.R`

**Why:** The file has 6 references to `ns_wave1_svy` (3 via `data(ns_wave1_svy)` + 3 usages). Replace with `make_ns_nonprob()`.

- [ ] **Step 1: Find all occurrences**

```bash
grep -n "ns_wave1_svy" tests/testthat/test-nps-jackknife.R
```

Expected: 6 lines — 3 `data(ns_wave1_svy)` calls and 3 usages.

- [ ] **Step 2: Replace `data(ns_wave1_svy)` + usage pattern**

The `data(ns_wave1_svy)` calls don't produce a named binding in the same way — the object appears in the environment as `ns_wave1_svy`. Replace the two-line pattern:

```r
data(ns_wave1_svy)
result <- some_fn(ns_wave1_svy, ...)
```

With:

```r
ns_wave1_svy <- make_ns_nonprob()
result <- some_fn(ns_wave1_svy, ...)
```

If a `test_that()` block calls `data(ns_wave1_svy)` and then uses `ns_wave1_svy` multiple times, assign once at the top:

```r
test_that("...", {
  ns_wave1_svy <- make_ns_nonprob()
  # ... multiple uses of ns_wave1_svy ...
})
```

- [ ] **Step 3: Run the jackknife tests**

```r
devtools::test(filter = "nps-jackknife")
```

Expected: all tests pass.

- [ ] **Step 4: Commit**

```bash
git add tests/testthat/test-nps-jackknife.R
git commit -m "test(jackknife): replace ns_wave1_svy lazy loads with make_ns_nonprob()"
```

---

## Task 5: Update `test-nonprob-ipw.R` and `test-sample-calibration.R`

**Files:**
- Modify: `tests/testthat/test-nonprob-ipw.R`
- Modify: `tests/testthat/test-sample-calibration.R`

- [ ] **Step 1: Find occurrences**

```bash
grep -n "ns_wave1_svy\|npors_2025_clean_svy" \
  tests/testthat/test-nonprob-ipw.R \
  tests/testthat/test-sample-calibration.R
```

Expected: 1 occurrence in `test-nonprob-ipw.R` (using `ns_wave1_svy`), 1 in `test-sample-calibration.R` (using `npors_2025_clean_svy`).

- [ ] **Step 2: Update test-nonprob-ipw.R**

Find the one block using `ns_wave1_svy` and apply the same pattern as Task 4:

```r
# Before
data(ns_wave1_svy)
result <- ipw(ns_wave1_svy, ref, ...)

# After
ns_svy <- make_ns_nonprob()
result <- ipw(ns_svy, ref, ...)
```

Note: `ipw()` takes a `survey_nonprob` as its first argument (`data`). `make_ns_nonprob()` returns a `survey_nonprob`. The call structure is unchanged.

- [ ] **Step 3: Update test-sample-calibration.R**

Find the one block using `npors_2025_clean_svy` and replace:

```r
# Before
data(npors_2025_clean_svy)
result <- calibrate_to_survey(primary_design, npors_2025_clean_svy, ...)

# After
npors_svy <- make_npors_taylor()
result <- calibrate_to_survey(primary_design, npors_svy, ...)
```

`make_npors_taylor()` returns a `survey_taylor` constructed from `npors_2025_clean` with `weights = weight, strata = stratum` — the same design that `npors_2025_clean_svy` previously held.

- [ ] **Step 4: Run both test files**

```r
devtools::test(filter = "nonprob-ipw")
devtools::test(filter = "sample-calibration")
```

Expected: all tests pass.

- [ ] **Step 5: Commit**

```bash
git add tests/testthat/test-nonprob-ipw.R tests/testthat/test-sample-calibration.R
git commit -m "test(ipw,sample-cal): replace _svy lazy loads with make_ns_nonprob() and make_npors_taylor()"
```

---

## Task 6: Update function examples — replicate weight functions

**Files:**
- Modify: `R/create_jackknife_weights.R`
- Modify: `R/create_bootstrap_weights.R`
- Modify: `R/create_brr_weights.R`
- Modify: `R/create_sdr_weights.R`
- Modify: `R/create_gen_boot_weights.R`
- Modify: `R/create_gen_rep_weights.R`
- Modify: `R/create_replicate_weights.R`
- Modify: `R/as_taylor_design.R`

**What changes:** Each of these functions has examples that load a `_svy` object (e.g., `gss_2024_svy`) with `data()`. Replace with inline construction from the package tibble.

**Inline construction pattern to use in all examples:**

```r
#' data(gss_2024)
#' gss_svy <- surveycore::as_survey(
#'   gss_2024, weights = wtssps, strata = vstrat, ids = vpsu, nest = TRUE
#' )
```

For `create_sdr_weights()`, the ACS replicate design uses:

```r
#' data(acs_wy_2022)
#' rep_cols <- grep("^pwgtp[0-9]", names(acs_wy_2022), value = TRUE)
#' acs_svy <- surveycore::as_survey_replicate(
#'   acs_wy_2022, weights = pwgtp,
#'   repweights = dplyr::all_of(rep_cols),
#'   type = "successive-difference", mse = TRUE
#' )
```

For `as_taylor_design()`, which converts a replicate design back to Taylor, use:

```r
#' data(gss_2024)
#' rep_cols <- grep("^pwgtp[0-9]", names(acs_wy_2022), value = TRUE)
#' # First create a replicate design from gss_2024
#' gss_svy <- surveycore::as_survey(
#'   gss_2024, weights = wtssps, strata = vstrat, ids = vpsu, nest = TRUE
#' )
#' gss_rep <- create_bootstrap_weights(gss_svy, R = 50)
#' # Convert back to a Taylor design
#' gss_taylor <- as_taylor_design(gss_rep)
```

- [ ] **Step 1: In each file, find and remove `data(<name>_svy)` calls from examples**

For each file listed above:
1. Open the file
2. Find the `@examples` block
3. Replace the `data(gss_2024_svy)` or `data(acs_wy_2022_svy)` line and the subsequent usage with the inline construction pattern above
4. Keep all downstream example calls unchanged (they just use the newly-constructed `gss_svy` / `acs_svy` object)

**Example for `create_bootstrap_weights.R`:**

Before:
```r
#' @examples
#' data(gss_2024_svy)
#' bsr <- create_bootstrap_weights(gss_2024_svy, R = 200)
```

After:
```r
#' @examples
#' data(gss_2024)
#' gss_svy <- surveycore::as_survey(
#'   gss_2024, weights = wtssps, strata = vstrat, ids = vpsu, nest = TRUE
#' )
#' bsr <- create_bootstrap_weights(gss_svy, R = 200)
```

Apply the same pattern to the other 7 files.

- [ ] **Step 2: Run `devtools::document()` to regenerate man/ pages**

```r
devtools::document()
```

Verify: `man/create_bootstrap_weights.Rd`, `man/create_jackknife_weights.Rd`, etc. are updated.

- [ ] **Step 3: Run `R CMD check` examples only**

```r
devtools::run_examples()
```

Expected: all examples run without error. Watch for "object not found" or "no applicable method" errors — those indicate the inline construction isn't producing the right class.

- [ ] **Step 4: Commit**

```bash
git add R/create_jackknife_weights.R R/create_bootstrap_weights.R \
        R/create_brr_weights.R R/create_sdr_weights.R \
        R/create_gen_boot_weights.R R/create_gen_rep_weights.R \
        R/create_replicate_weights.R R/as_taylor_design.R \
        man/
git commit -m "docs(replicate): update examples with inline survey construction (remove _svy loads)"
```

---

## Task 7: Update `calibrate_to_survey()` example

**Files:**
- Modify: `R/calibrate_to_survey.R`

**What changes:** The example currently loads `pew_2016_optin_svy` (primary design) and `npors_2025_clean_svy` (control design). After PR 1, construct these inline from the promoted weight columns in `pew_2016_optin` and from `npors_2025_clean`.

- [ ] **Step 1: Find the example block in R/calibrate_to_survey.R**

```bash
grep -n "pew_2016_optin_svy\|npors_2025_clean_svy\|@examples" R/calibrate_to_survey.R
```

- [ ] **Step 2: Replace the example**

Before:
```r
#' @examples
#' data(pew_2016_optin_svy)
#' data(npors_2025_clean_svy)
#' result <- calibrate_to_survey(
#'   pew_2016_optin_svy,
#'   npors_2025_clean_svy,
#'   variables = c(sex, age_f3, race_f4, edu_f3)
#' )
```

After:
```r
#' @examples
#' # Primary design: opt-in panel (non-probability) with promoted calibrated weight
#' data(pew_2016_optin)
#' repwt_cols <- grep("^repwt_", names(pew_2016_optin), value = TRUE)
#' primary <- surveycore::survey_nonprob(
#'   pew_2016_optin,
#'   variables = list(
#'     weights = "weight",
#'     repweights = repwt_cols
#'   )
#' )
#'
#' # Control design: probability reference survey with bootstrap variance
#' data(npors_2025_clean)
#' npors_svy <- surveycore::as_survey(
#'   npors_2025_clean, weights = weight, strata = stratum
#' )
#' control <- create_bootstrap_weights(npors_svy, R = 200)
#'
#' result <- calibrate_to_survey(
#'   primary,
#'   control,
#'   variables = c(sex, age_f3, race_f4, edu_f3)
#' )
```

- [ ] **Step 3: Run devtools::document() and examples**

```r
devtools::document()
devtools::run_examples(pkg = ".", start = "calibrate_to_survey")
```

Expected: example runs without error.

- [ ] **Step 4: Commit**

```bash
git add R/calibrate_to_survey.R man/calibrate_to_survey.Rd
git commit -m "docs(sample-cal): update calibrate_to_survey() example with inline construction"
```

---

## Task 8: Rename `stabilize_weights()` → `rescale_weights()` — R source

**Files:**
- Rename: `R/stabilize_weights.R` → `R/rescale_weights.R` (git rename)
- Modify: `R/rescale_weights.R` (function name, history entry, error messages, examples)

**Key changes inside the file:**
- `stabilize_weights <- function(...)` → `rescale_weights <- function(...)`
- `operation = "stabilize_weights"` → `operation = "rescale_weights"` in history entry
- `{.fn stabilize_weights}` → `{.fn rescale_weights}` in the error message at line ~130
- Examples: remove `data(ns_wave1_svy)` (line 55); use inline `ns_wave1` tibble construction pattern instead
- `@family utilities` tag stays the same (family name doesn't change)
- `@export` tag stays — just the function name changes

**Example pattern for rescale_weights:** Replace the `ns_wave1_svy` example with Pattern 3 (before/after using `ns_wave1` tibble with `weights = weight`):

```r
#' @examples
#' # Show weight spread before and after rescaling
#' data(ns_wave1)
#' summarize_weights(ns_wave1, weights = weight)
#' result <- rescale_weights(ns_wave1, weights = weight)
#' summarize_weights(result, weights = wts)
```

- [ ] **Step 1: Git rename the file**

```bash
git mv R/stabilize_weights.R R/rescale_weights.R
```

- [ ] **Step 2: Update the function name, history entry, and error messages**

In `R/rescale_weights.R`:

a. Change the function declaration:
```r
# Before:
stabilize_weights <- function(data, weights = NULL, by = NULL, wt_name = "wts") {
# After:
rescale_weights <- function(data, weights = NULL, by = NULL, wt_name = "wts") {
```

b. Change the history entry's `operation` field:
```r
# Before:
operation = "stabilize_weights"
# After:
operation = "rescale_weights"
```

c. Change any `{.fn stabilize_weights}` references in error messages:
```r
# Before:
"i" = "Use {.fn stabilize_weights} with {.arg by} to restrict to a subgroup."
# After:
"i" = "Use {.fn rescale_weights} with {.arg by} to restrict to a subgroup."
```

d. Update the roxygen2 title (if it says "stabilize"):
```r
# Before:
#' Stabilize survey weights
# After:
#' Rescale survey weights to a target mean or sum
```

e. Update all `stabilize_weights` references in `@description`, `@details`, and `@examples` to `rescale_weights`.

f. Update the examples to use the Pattern 3 inline style:
```r
#' @examples
#' # Rescale weights to unit mean (default)
#' data(ns_wave1)
#' summarize_weights(ns_wave1, weights = weight)
#'
#' result <- rescale_weights(ns_wave1, weights = weight)
#' summarize_weights(result, weights = wts)
#'
#' # Rescale within groups using by =
#' result_by <- rescale_weights(ns_wave1, weights = weight, by = ns_region)
#' summarize_weights(result_by, weights = wts, by = ns_region)
```

- [ ] **Step 3: Run devtools::document()**

```r
devtools::document()
```

Verify:
- `man/stabilize_weights.Rd` is GONE (or replaced by `man/rescale_weights.Rd`)
- `NAMESPACE` exports `rescale_weights` not `stabilize_weights`
- `man/rescale_weights.Rd` exists

- [ ] **Step 4: Commit**

```bash
git add R/rescale_weights.R NAMESPACE man/rescale_weights.Rd
git rm man/stabilize_weights.Rd 2>/dev/null || true
git commit -m "refactor(weights): rename stabilize_weights() to rescale_weights()"
```

---

## Task 9: Update tests for `rescale_weights()` rename

**Files:**
- Modify: `tests/testthat/test-weight-utils.R`
- Delete stale snapshots for `stabilize_weights` in `tests/testthat/_snaps/`

- [ ] **Step 1: Find and count all stabilize_weights references in test-weight-utils.R**

```bash
grep -n "stabilize_weights" tests/testthat/test-weight-utils.R | wc -l
grep -n "stabilize_weights" tests/testthat/test-weight-utils.R
```

Expected: 30+ occurrences. Note every line number.

- [ ] **Step 2: Replace all stabilize_weights( with rescale_weights(**

Using your editor or sed, do a bulk replacement:
```bash
sed -i '' 's/stabilize_weights(/rescale_weights(/g' tests/testthat/test-weight-utils.R
```

Then verify no `stabilize_weights` references remain:
```bash
grep -n "stabilize_weights" tests/testthat/test-weight-utils.R
```

Expected: zero results.

- [ ] **Step 3: Update any snapshot references in test-weight-utils.R**

Snapshot tests use `expect_snapshot(...)`. The snapshot files contain the error/warning message text. Some may reference `stabilize_weights` in the message. After the rename, these snapshots will become stale.

Find snapshot references:
```bash
ls tests/testthat/_snaps/ | grep "weight-utils"
```

Delete the stale snapshot file(s) (they will be regenerated):
```bash
rm -f tests/testthat/_snaps/test-weight-utils.md
```

- [ ] **Step 4: Run the weight-utils tests to regenerate snapshots**

```r
devtools::test(filter = "weight-utils")
```

Expected: tests run; snapshot tests CREATE new snapshots (first run always succeeds when the snapshot file is missing). Review the generated snapshot carefully to confirm the messages now say `rescale_weights` throughout.

```bash
cat tests/testthat/_snaps/test-weight-utils.md | grep -i "stabilize\|rescale" | head -30
```

Expected: only `rescale_weights` appears; no `stabilize_weights`.

- [ ] **Step 5: Commit updated tests and new snapshots**

```bash
git add tests/testthat/test-weight-utils.R tests/testthat/_snaps/test-weight-utils.md
git commit -m "test(weights): update stabilize_weights() tests to rescale_weights()"
```

---

## Task 10: Update `.claude/rules/surveywts-conventions.md` and `plans/roadmap.md`

**Files:**
- Modify: `.claude/rules/surveywts-conventions.md`
- Modify: `plans/roadmap.md`

- [ ] **Step 1: Update surveywts-conventions.md file mapping table**

Find:
```markdown
| `stabilize_weights.R` | `stabilize_weights()` |
```

Replace with:
```markdown
| `rescale_weights.R` | `rescale_weights()` |
```

Find in the `weight-utils.R` entry:
```markdown
| `weight-utils.R` | `trim_weights()`, `stabilize_weights()` |
```

Replace with:
```markdown
| `weight-utils.R` | `trim_weights()`, `rescale_weights()` |
```

Find in the `utilities` family table:
```markdown
| `utilities` | `trim_weights()`, `stabilize_weights()` |
```

Replace with:
```markdown
| `utilities` | `trim_weights()`, `rescale_weights()` |
```

Find in the argument order table:
```markdown
| `stabilize_weights()` | `data, weights = NULL, by = NULL, wt_name = "wts"` |
```

Replace with:
```markdown
| `rescale_weights()` | `data, weights = NULL, by = NULL, wt_name = "wts"` |
```

- [ ] **Step 2: Update plans/roadmap.md**

```bash
grep -n "stabilize_weights" plans/roadmap.md
```

Replace any occurrences of `stabilize_weights()` with `rescale_weights()` in roadmap.md.

- [ ] **Step 3: Commit**

```bash
git add .claude/rules/surveywts-conventions.md plans/roadmap.md
git commit -m "docs(conventions): update file and family tables for rescale_weights() rename"
```

---

## Task 11: Final `devtools::check()` and open PR

**Files:** None new

- [ ] **Step 1: Run `devtools::document()` one final time**

```r
devtools::document()
```

Verify:
- `NAMESPACE` exports `rescale_weights`, not `stabilize_weights`
- `man/stabilize_weights.Rd` does not exist
- `man/rescale_weights.Rd` exists
- All `_svy` references are gone from `man/` pages (grep to confirm):
  ```bash
  grep -r "_svy" man/
  ```
  Expected: 0 results

- [ ] **Step 2: Run full test suite**

```r
devtools::test()
```

Expected: all tests pass; no failures. If any snapshot tests produce new unexpected output (not just the stabilize→rescale rename), run `testthat::snapshot_review()` to approve or reject each diff individually.

- [ ] **Step 3: Run `devtools::check()`**

```r
devtools::check()
```

Expected: 0 errors, 0 warnings, ≤2 pre-approved notes (`no visible binding for global variable`, `checking CRAN incoming feasibility`).

Watch specifically for:
- Any `codoc` WARNING — indicates a mismatch between `R/data.R` and actual `.rda` column lists. Go back to Task 9 in PR 1's plan and fix.
- `no export pattern for "rescale_weights"` NOTE — means `@export` tag is missing; add it.
- `no export pattern for "stabilize_weights"` NOTE — means NAMESPACE wasn't regenerated; re-run `devtools::document()`.

- [ ] **Step 4: Push and open PR**

```bash
git push -u origin feature/dataset-cleanup-pr2
```

Open PR against `develop`.

PR title: `refactor: update function examples for tibble datasets and rename rescale_weights()`

PR body:
```markdown
## What

Follows PR #<PR1_NUMBER> (dataset layer cleanup). Updates all function
surfaces that relied on the removed `_svy` package objects:

- Adds `make_gss_taylor()`, `make_ns_nonprob()`, `make_npors_taylor()`
  test helpers to `helper-test-data.R`
- Replaces 22 `_svy` lazy-load references across 5 test files with helper calls
- Updates examples in 9 function files to construct survey objects inline
  from package tibbles
- Renames `stabilize_weights()` → `rescale_weights()` (no deprecation shim,
  pre-CRAN)

## Checklist

- [ ] Tests written and passing (`devtools::test()`)
- [ ] R CMD check: 0 errors, 0 warnings (`devtools::check()`)
- [ ] Roxygen docs updated and `devtools::document()` run
- [ ] Snapshots reviewed with `testthat::snapshot_review()` after regeneration
- [ ] PR title is a valid Conventional Commit
```

---

## Spec Coverage Check

| Spec requirement | Task |
|---|---|
| Add three test helpers | Task 2 |
| Replace `gss_2024_svy` (13 refs in test-replicate-weights.R) | Task 3 |
| Replace `ns_wave1_svy` (6 refs in test-nps-jackknife.R) | Task 4 |
| Replace `ns_wave1_svy` (1 ref in test-nonprob-ipw.R) | Task 5 |
| Replace `npors_2025_clean_svy` (1 ref in test-sample-calibration.R) | Task 5 |
| Update replicate weight function examples (Pattern 4 — inline construction) | Task 6 |
| Update `calibrate_to_survey()` example | Task 7 |
| Rename `stabilize_weights()` → `rescale_weights()` in R source | Task 8 |
| Rename in tests + regenerate snapshots | Task 9 |
| Update `.claude/rules/surveywts-conventions.md` | Task 10 |
| Update `plans/roadmap.md` | Task 10 |
| `devtools::document()` + `devtools::check()` | Task 11 |

**Out of scope (not included per spec):**
- `pew_2016_optin_svy` in `test-datasets.R` — handled in PR 1 (Task 10 of PR 1 plan)
- `gss_2024_svy` / `ns_wave1_svy` refs in `test-datasets.R` — handled in PR 1
- Changes to Diagnostics phase functions (explicitly out of scope)

**Note on function examples not listed in spec (Pattern 1–3 functions):**
- `calibrate_rake()`, `calibrate_linear()`, `calibrate_logit()`, `calibrate()`, `poststratify()`, `ipw()`: examples use Pattern 1 (fresh weights from plain tibble). If these already use the plain tibble (`ns_wave1`, `pew_2016_optin`) without the `_svy` suffix, no change is needed. Verify each by running `grep -n "_svy" R/calibrate_rake.R R/ipw.R R/poststratify.R` before marking this section complete.
- `effective_sample_size()`, `weight_variability()`, `summarize_weights()`: Pattern 2 (existing weights from tibble). Same check: `grep -n "_svy" R/effective_sample_size.R R/weight_variability.R R/summarize_weights.R`. Fix any hits the same way as Task 6.
