# Implementation Plan — jackknife-merge

**Status**: DRAFT
**Spec**: `plans/spec-jackknife-merge.md` (SPEC_READY)
**Test-spec**: `plans/test-spec-jackknife-merge.md`
**PR range**: PR 1–2

---

## Overview

This plan merges `create_jackknife_weights()` and `create_group_jackknife_weights()`
into a single function with a unified `type` argument, targeting version
0.7.0.9000. PR 1 is a pure refactor: it migrates the DAGJK engine helpers
to `jackknife-dagjk-utils.R` and updates all error/warning class strings
from retired `dagjk_*` names to the active `jackknife_*` names. No public
API changes in PR 1. PR 2 delivers the merged public API: replaces
`create_jackknife_weights()` with the full unified implementation, adds the
Inf weight check and extended Kott 2001 formula to the helpers, deletes
`create_group_jackknife_weights.R`, removes `"group-jackknife"` from the
dispatcher, and ships full Tier 3 documentation with three runnable
`@examples`.

---

## PR Map

- [x] PR 1: `feature/jackknife-dagjk-engine` — Migrate DAGJK engine helpers to `jackknife-dagjk-utils.R`; rename and update all error/warning class strings from `dagjk_*` to `jackknife_*`; no public API change
- [x] PR 2: `feature/jackknife-merge` — Replace `create_jackknife_weights()` with unified merged implementation; extend helpers with Inf check and extended formula; delete `create_group_jackknife_weights.R`; remove `"group-jackknife"` from dispatcher

---

### PR 1: `feature/jackknife-dagjk-engine`

**Branch:** `feature/jackknife-dagjk-engine`
**Depends on:** none

**Files (TDD order — tests first):**
- `plans/error-messages.md` — verify already-updated state; no changes expected
- `tests/testthat/test-nps-group-jackknife.R` — update all `dagjk_*` class assertions to `jackknife_*`; delete stale snapshot files → RED
- `R/jackknife-dagjk-utils.R` — NEW: three helpers migrated and renamed from `create_group_jackknife_weights.R`
- `R/create_group_jackknife_weights.R` — MODIFIED: remove helper definitions; update to call `.validate_replicates_dagjk_arg()`; update all class strings
- `tests/testthat/_snaps/test-nps-group-jackknife/` — regenerate via `testthat::snapshot_review()`
- `changelog/jackknife-merge/feature-dagjk-engine.md` — created last, before opening PR

**Acceptance criteria:**
- [ ] All tests in `test-nps-group-jackknife.R` pass GREEN
- [ ] `devtools::check()` 0 errors, 0 warnings, ≤2 pre-approved notes
- [ ] `devtools::document()` run; NAMESPACE and man/ unchanged from pre-PR state
- [ ] `R/jackknife-dagjk-utils.R` exists and defines exactly `.validate_replicates_dagjk_arg()`, `.dagjk_single_replicate()`, `.dagjk_single_replicate_calib()`
- [ ] `grep -rn "surveywts_.*_dagjk" R/jackknife-dagjk-utils.R` → 0 hits
- [ ] `grep -rn "surveywts_.*_dagjk" R/create_group_jackknife_weights.R` → 0 hits
- [ ] `grep -rn ".validate_groups_arg" R/` → 0 hits (fully replaced)
- [ ] `create_group_jackknife_weights()` still functional and exported (no API change)
- [ ] `covr::package_coverage()` ≥ 98% overall
- [ ] `plans/error-messages.md` updated with all new error/warning classes (already done; verify)
- [ ] Changelog entry written and committed on this branch

---

#### Task 1.1 — Verify `plans/error-messages.md` (2 min)

Open `plans/error-messages.md`. Confirm every `dagjk_*` class has a
strikethrough RETIRED entry AND a corresponding active `jackknife_*` class.
No code changes in this task — only reading.

Key mappings to verify:

| Retired | Active |
|---------|--------|
| `surveywts_error_dagjk_groups_invalid` | `surveywts_error_jackknife_replicates_invalid` |
| `surveywts_error_dagjk_groups_not_whole_number` | `surveywts_error_replicates_not_whole_number` (existing) |
| `surveywts_error_dagjk_groups_too_small` | `surveywts_error_jackknife_replicates_too_small` |
| `surveywts_error_dagjk_groups_exceeds_n` | `surveywts_error_jackknife_replicates_exceeds_n` |
| `surveywts_error_dagjk_degenerate_replicate` | `surveywts_error_jackknife_degenerate_replicate` |
| `surveywts_error_dagjk_no_history` | `surveywts_error_jackknife_no_history` |
| `surveywts_error_dagjk_no_reference` | `surveywts_error_jackknife_no_reference` |
| `surveywts_error_dagjk_all_replicates_failed` | `surveywts_error_jackknife_all_replicates_failed` |
| `surveywts_warning_dagjk_repweights_overwritten` | `surveywts_warning_jackknife_repweights_overwritten` |
| `surveywts_warning_dagjk_small_groups` | `surveywts_warning_jackknife_small_groups` |
| `surveywts_warning_dagjk_replicates_failed` | `surveywts_warning_jackknife_replicates_failed` |
| `surveywts_warning_dagjk_negative_replicate_weights` | `surveywts_warning_jackknife_negative_replicate_weights` |

Also confirm `surveywts_error_jackknife_degenerate_replicate` description reads
"non-positive, non-finite, or NA weights" (the B-2 resolution). If any entry
is missing, fix `error-messages.md` before writing any R code.

---

#### Task 1.2 — Write RED tests: update `test-nps-group-jackknife.R` (4 min)

In `tests/testthat/test-nps-group-jackknife.R`:

1. Search for every `class = "surveywts_error_dagjk_*"` string and replace with
   the corresponding `surveywts_error_jackknife_*` class from the mapping in
   Task 1.1. Do the same for `class = "surveywts_warning_dagjk_*"`.

2. If there is a test using `class = "surveywts_error_dagjk_requires_nonprob"`
   (for a `survey_taylor` input to `create_group_jackknife_weights()`), update
   it to `class = "surveywts_error_unsupported_class"`.

3. Delete any snapshot files in
   `tests/testthat/_snaps/test-nps-group-jackknife/` whose content will change.
   Snapshot messages for validator errors change because
   `.validate_replicates_dagjk_arg()` says `{.arg replicates}` instead of
   `{.arg groups}` — any snapshot that shows "groups" in an error message will
   need updating.

4. Run `devtools::test(filter = "nps-group-jackknife")`. Expect FAIL RED: the
   tests now assert the new class names but the code still throws the old ones.

---

#### Task 1.3 — Create `R/jackknife-dagjk-utils.R` (5 min)

Create `R/jackknife-dagjk-utils.R`. For each of the three helpers, copy from
`R/create_group_jackknife_weights.R` and apply only the changes listed below.
**Do not add the extended formula or Inf weight check** — those come in PR 2.

**a. `.validate_replicates_dagjk_arg(replicates, combined_n = Inf)`**

Rename from `.validate_groups_arg`. Update everywhere `groups` appears as
the parameter or local variable name to `replicates`. Update CLI messages:
`{.arg groups}` → `{.arg replicates}` and suggested fix examples
`{.code groups = 50L}` → `{.code replicates = 50L}`. Update four error class
strings:

- `surveywts_error_dagjk_groups_invalid` → `surveywts_error_jackknife_replicates_invalid`
- `surveywts_error_dagjk_groups_not_whole_number` → `surveywts_error_replicates_not_whole_number`
- `surveywts_error_dagjk_groups_too_small` → `surveywts_error_jackknife_replicates_too_small`
- `surveywts_error_dagjk_groups_exceeds_n` → `surveywts_error_jackknife_replicates_exceeds_n`

**b. `.dagjk_single_replicate()`**

Copy as-is. Update all occurrences of `surveywts_error_dagjk_degenerate_replicate`
→ `surveywts_error_jackknife_degenerate_replicate`. No other changes.

**c. `.dagjk_single_replicate_calib()`**

Copy as-is. Update all occurrences of `surveywts_error_dagjk_degenerate_replicate`
→ `surveywts_error_jackknife_degenerate_replicate`. No other changes.

---

#### Task 1.4 — Update `R/create_group_jackknife_weights.R` (5 min)

**a.** Remove the three helper function definitions (`.validate_groups_arg`,
`.dagjk_single_replicate`, `.dagjk_single_replicate_calib`) — they now live
in `jackknife-dagjk-utils.R` and will be available at load time.

**b.** In the `create_group_jackknife_weights()` body, apply these substitutions:

- Both `.validate_groups_arg(groups, ...)` call sites →
  `.validate_replicates_dagjk_arg(groups, ...)` (the argument VALUE remains
  `groups` since the user-facing parameter is still named `groups`)
- `surveywts_error_dagjk_requires_nonprob` → `surveywts_error_unsupported_class`
- `surveywts_error_dagjk_no_history` → `surveywts_error_jackknife_no_history`
- `surveywts_error_dagjk_no_reference` → `surveywts_error_jackknife_no_reference`
- `surveywts_error_dagjk_all_replicates_failed` →
  `surveywts_error_jackknife_all_replicates_failed`
- `.handle_repweights_overwrite()` call: update `warning_class` argument from
  `"surveywts_warning_dagjk_repweights_overwritten"` →
  `"surveywts_warning_jackknife_repweights_overwritten"`
- `surveywts_warning_dagjk_small_groups` → `surveywts_warning_jackknife_small_groups`
- `surveywts_warning_dagjk_replicates_failed` →
  `surveywts_warning_jackknife_replicates_failed`
- `surveywts_warning_dagjk_negative_replicate_weights` →
  `surveywts_warning_jackknife_negative_replicate_weights`

**Leave unchanged:** `operation = "group_jackknife_weights"` in the history
entry — this old operation name is deleted in PR 2 along with the whole file.

---

#### Task 1.5 — Run tests GREEN (3 min)

Run `devtools::test(filter = "nps-group-jackknife")`. New-class tests now
pass; snapshot tests for error messages fail because message text changed
from `{.arg groups}` to `{.arg replicates}`. Run `testthat::snapshot_review()`
— review each diff to confirm only the `groups` → `replicates` substitution
changed, then accept. Re-run tests; all should pass GREEN.

---

#### Task 1.6 — `devtools::document()` and `devtools::check()` (2 min)

`devtools::document()` — confirm NAMESPACE and man/ are unchanged (no new or
removed exports from PR 1).

`devtools::check()` — 0 errors, 0 warnings, ≤2 pre-approved notes.

---

**Notes for PR 1:**

- PR 1 covers no scenarios from `test-spec-jackknife-merge.md` directly — the
  test-spec tests the merged `create_jackknife_weights()` which ships in PR 2.
  PR 1 only maintains existing coverage for the old API.
- The CLI messages in `.validate_replicates_dagjk_arg()` say `{.arg replicates}`
  even though `create_group_jackknife_weights()` passes `groups` as the value.
  This minor transitional inconsistency resolves when the old function is
  deleted in PR 2.
- After Task 1.3, run `grep -rn ".validate_groups_arg" R/` — must return 0 hits.
- After Task 1.4, run `grep -rn "surveywts_.*_dagjk" R/create_group_jackknife_weights.R`
  — must return 0 hits.

---

### PR 2: `feature/jackknife-merge`

**Branch:** `feature/jackknife-merge`
**Depends on:** PR 1 merged to develop

**Files (TDD order — tests first):**
- `tests/testthat/test-replicate-weights.R` — expand jackknife section → RED
- `tests/testthat/test-nps-jackknife.R` — NEW (rewrite of deleted `test-nps-group-jackknife.R`) → RED
- `tests/testthat/test-replicate-dispatch.R` — update for dispatcher changes → RED
- `R/jackknife-dagjk-utils.R` — MODIFIED: add Inf check and extended formula
- `R/create_jackknife_weights.R` — REPLACED: full merged implementation + Tier 3 roxygen
- `R/create_group_jackknife_weights.R` — DELETED
- `R/create_replicate_weights.R` — MODIFIED: remove `"group-jackknife"` arm
- `devtools::document()` — regenerates man/ and NAMESPACE
- `.claude/rules/surveywts-conventions.md` — update file mapping
- `.claude/rules/testing-surveywts.md` — verify file mapping already updated (S-1)
- `changelog/jackknife-merge/feature-jackknife-merge.md` — created last, before PR

**Acceptance criteria:**

From spec §Quality gates (observable in tests):
- [ ] `create_jackknife_weights(survey_nonprob, type = "jkn")` errors with `surveywts_error_jackknife_type_nonprob_only` — test-spec error path
- [ ] `create_jackknife_weights(survey_nonprob, type = "jk1")` errors with same class — test-spec error path
- [ ] `mse = FALSE` + `type = "grouped"` + `survey_nonprob` warns with `surveywts_warning_jackknife_mse_overridden` and returns `mse == TRUE` — test-spec warning path
- [ ] History `operation == "replicate_creation"`, `method == "jackknife"` for JKn/JK1/grouped+taylor — test-spec history entry validation
- [ ] History `operation == "jackknife_weights"` (no `method` field) for DAGJK — test-spec history entry validation
- [ ] `@variables$type == "group-jackknife"` for DAGJK output — test-spec happy path
- [ ] DAGJK `@variables$scale == (G_success - 1) / G_success` — test-spec numerical oracle
- [ ] `create_replicate_weights(method = "jackknife", type = "grouped", replicates = 50L)` with `survey_nonprob` returns `survey_nonprob` with `@variables$type == "group-jackknife"` — test-spec dispatcher pass-through
- [ ] `create_replicate_weights(method = "group-jackknife")` errors — test-spec retired method test
- [ ] All tests pass GREEN
- [ ] `devtools::check()` 0 errors, 0 warnings, ≤2 pre-approved notes
- [ ] `devtools::document()` run; `man/create_group_jackknife_weights.Rd` deleted; `man/create_jackknife_weights.Rd` regenerated
- [ ] `NAMESPACE` no longer exports `create_group_jackknife_weights`
- [ ] `devtools::run_examples()` all three `@examples` run clean
- [ ] `covr::package_coverage()` ≥ 98% overall
- [ ] `create_jackknife_weights(gss_2024_svy, type = "jkn")` returns `survey_replicate` with `@variables$type == "JKn"`
- [ ] `create_jackknife_weights(gss_2024_svy, type = "jk1")` returns `survey_replicate` with `@variables$type == "JK1"`
- [ ] `create_jackknife_weights(gss_2024_svy, type = "grouped", replicates = 20L)` returns `survey_replicate` with `@variables$type == "random-group"` and `length(@variables$repweights) == 20L`
- [ ] Changelog entry written and committed on this branch

---

#### Task 2.1 — Write RED tests: expand `test-replicate-weights.R` (5 min)

Add to `tests/testthat/test-replicate-weights.R` after the existing sections.
Use `gss_2024_svy` (package data) for all probability design tests.

**Happy paths (one `test_that()` block each):**

```
test_that("create_jackknife_weights() type = 'jkn' returns survey_replicate with @variables$type == 'JKn'")
```
Assert: `S7::S7_inherits(result, surveycore::survey_replicate)`,
`result@variables$type == "JKn"`.

```
test_that("create_jackknife_weights() type = 'jk1' returns survey_replicate with @variables$type == 'JK1'")
```

```
test_that("create_jackknife_weights() type = 'grouped' returns survey_replicate with @variables$type == 'random-group'")
```
Use `replicates = 20L`. Assert `length(result@variables$repweights) == 20L`.

**Numerical oracle (skip_if_not_installed("survey") inside each block):**

```
test_that("create_jackknife_weights() jkn replicate count matches survey::as.svrepdesign oracle")
test_that("create_jackknife_weights() jk1 replicate count matches survey::as.svrepdesign oracle")
test_that("create_jackknife_weights() jkn scale factor matches survey::as.svrepdesign oracle")
```
For jkn/jk1 counts: `expect_identical`. For scale: `expect_equal(tolerance = 1e-10)`.

**History entry structure (one block per probability path):**

```
test_that("create_jackknife_weights() jkn history entry has operation='replicate_creation', method='jackknife', parameters$type='jkn', parameters$mse")
test_that("create_jackknife_weights() jk1 history entry has parameters$type='jk1', parameters$mse")
test_that("create_jackknife_weights() grouped+taylor history entry has parameters$type='grouped', parameters$replicates==20L, parameters$mse")
```
For each block assert: `entry$operation == "replicate_creation"`, `entry$method == "jackknife"`,
`entry$parameters$type` matches the variant, `entry$parameters$mse == TRUE` (jkn/jk1) or the
value passed (grouped+taylor), and for grouped+taylor: `entry$parameters$replicates == 20L`.

**Edge cases (probability paths):**

```
test_that("create_jackknife_weights() type = 'jkn' succeeds on unstratified survey_taylor")
```
Construct an inline `survey_taylor` with no strata column. Assert: result is
`survey_replicate` with `@variables$type == "JKn"`. Validates that the backend
handles no-strata inputs without error.

**Argument behavior:**

```
test_that("replicates is silently ignored for type = 'jkn'")
```
Supply `replicates = 99L`; expect no error/warning; replicate count ≠ 99.

```
test_that("replicates is silently ignored for type = 'jk1'")
test_that("seed is silently ignored for type = 'jkn'")
test_that("reference_sample is silently ignored for type = 'jkn'")
```

**Error paths (dual pattern: `expect_error(class=)` + `expect_snapshot(error=TRUE)`):**

```
test_that("create_jackknife_weights() rejects data.frame input")
```
`data = data.frame(x = 1:5, w = 1)` → `surveywts_error_not_survey_design`.

```
test_that("create_jackknife_weights() rejects list input")
```
`data = list(x = 1:5, w = 1)` → `class = "surveywts_error_unsupported_class"`. Dual pattern.

```
test_that("create_jackknife_weights() rejects survey_replicate input")
test_that("create_jackknife_weights() rejects survey_nonprob with type = 'jkn'")
test_that("create_jackknife_weights() rejects survey_nonprob with type = 'jk1'")
```
For nonprob+jkn/jk1: use any inline `survey_nonprob` with calibration history.

```
test_that("create_jackknife_weights() errors when type = 'grouped' and replicates = NULL, survey_taylor input")
test_that("create_jackknife_weights() errors when type = 'grouped' and replicates = NULL, survey_nonprob input")
```
Both use `class = "surveywts_error_jackknife_replicates_required"`.

```
test_that("create_jackknife_weights() errors when ... is non-empty")
```
`create_jackknife_weights(gss_2024_svy, type = "jkn", extra = 1)` — error from
`rlang::check_dots_empty()`.

Run `devtools::test(filter = "replicate-weights")` → new blocks FAIL RED.

---

#### Task 2.2 — Write RED tests: create `test-nps-jackknife.R` (5 min)

**Delete** `tests/testthat/test-nps-group-jackknife.R` and also delete the
entire `tests/testthat/_snaps/test-nps-group-jackknife/` directory (orphaned
snapshots from PR 1 that no longer have a test file to reference them).

**Create** `tests/testthat/test-nps-jackknife.R`. All tests call
`create_jackknife_weights(..., type = "grouped")` — NOT `create_group_jackknife_weights()`.

Use `ns_wave1_svy` (package data) for the happy path and scale oracle.
Use inline `survey_nonprob` constructions (via `make_dagjk_datasets()` or
minimal inline objects) for all other scenarios.

**Happy path:**
```
test_that("create_jackknife_weights() DAGJK on ns_wave1_svy returns correct structure")
```
`create_jackknife_weights(ns_wave1_svy, type = "grouped", replicates = 50L, seed = 42)`.
`test_invariants(result)`, `result@variables$type == "group-jackknife"`,
`length(result@variables$repweights) == 50L`,
`result@variables$mse == TRUE`,
`expect_equal(result@variables$scale, 49/50, tolerance = 1e-10)`.

**DAGJK scale oracle:**
```
test_that("DAGJK scale factor equals (G_success - 1) / G_success")
```
`replicates = 10L, seed = 1`; `expect_equal(result@variables$scale, 9/10, tolerance = 1e-10)`.

**Extended formula coverage (n_h < G branch):**
```
test_that("DAGJK extended formula succeeds when one stratum has n_h < G")
```
Construct an inline `survey_nonprob` with `@variables$strata` set to a column
where one stratum has `n_h = 3` PSUs (so `n_h < G` when `replicates = 10L`).
Call `create_jackknife_weights(data, type = "grouped", replicates = 10L, seed = 1)`.
Assert: `test_invariants(result)`, `length(result@variables$repweights) <=
10L`, `result@variables$scale == (length(result@variables$repweights) - 1) /
length(result@variables$repweights)`. This test exercises all three sub-paths
of the `n_h < G` dispatch: zero-group-member (unchanged weights), deleted PSU
factor (`1 - (n_h - 1) * Z`), and retained PSU factor (`1 + Z`). If the
stratum is small enough that any replicate produces negative weights, also
`expect_warning(..., class = "surveywts_warning_jackknife_negative_replicate_weights")`.

**Structural invariants:**
```
test_that("DAGJK replicates = 2L (minimum) succeeds")
```
`test_invariants(result)`, `length(result@variables$repweights) == 2`.

```
test_that("DAGJK replicates = 50.0 (double) is coerced silently")
```
`test_invariants(result)`, `result@variables$scale == 49/50`.

**Seed reproducibility:**
```
test_that("DAGJK same seed produces identical results")
test_that("DAGJK different seeds produce different results")
test_that("DAGJK seed = NULL does not error")
```

**Argument behavior:**
```
test_that("mse = FALSE is warned and overridden to TRUE for DAGJK")
```
`expect_warning(result <- create_jackknife_weights(..., mse = FALSE), class = "surveywts_warning_jackknife_mse_overridden")`.
`test_invariants(result)`, `result@variables$mse == TRUE`.

```
test_that("var_strat non-NULL warns jackknife_svrep_args_ignored for nonprob")
test_that("adj_method non-default warns jackknife_svrep_args_ignored for nonprob")
test_that("multiple non-default svrep args emit exactly one warning")
test_that("adj_method at default value does not warn for nonprob")
```

```
test_that("calling twice triggers jackknife_repweights_overwritten warning")
```
`expect_warning(result <- create_jackknife_weights(already_has_repweights, ...), class = "surveywts_warning_jackknife_repweights_overwritten")`.
`test_invariants(result)`.

```
test_that("small groups triggers jackknife_small_groups warning")
```
Choose `replicates` so `floor(combined_n / replicates) < 5`.
`expect_warning(..., class = "surveywts_warning_jackknife_small_groups")`.
`test_invariants(result)`.

```
test_that("all svrep args at default emits no svrep_args_ignored warning")
test_that("type = 'grouped' + IPW-only history (no calibration entry) succeeds")
```
Construct an inline `survey_nonprob` with only an `ipw()` history entry (no
calibration entry). Call `create_jackknife_weights(..., type = "grouped",
replicates = 10L, seed = 1)`. Assert: `test_invariants(result)`,
`result@variables$type == "group-jackknife"`. Validates the `calib_entry = NULL`
branch passed to `.dagjk_single_replicate()`.

```
test_that("type = 'grouped' + both IPW and calibration history routes to IPW path")
test_that("type = 'grouped' + calibration-only Level A succeeds without reference_sample")
test_that("type = 'grouped' + calibration-only Level B succeeds when reference_sample is supplied")
```
Construct an inline `survey_nonprob` with a calibration history entry where
`targets_from_reference = TRUE` and no IPW entry. Supply `reference_sample` to
`create_jackknife_weights()`. Assert: `test_invariants(result)`,
`result@variables$type == "group-jackknife"`. Covers the Level B reference
resolution branch (Step 10) where the reference comes from `reference_sample`.

```
test_that("type = 'grouped' + calibration-only Level B succeeds when reference stored in calibration entry")
```
Same setup but store the reference design in `calib_entry$parameters$reference_design`
instead of supplying `reference_sample`. Assert the same as above. Covers the
alternate Level B resolution sub-path where the reference is embedded in history.

**Error paths (dual pattern for each):**
```
test_that("DAGJK errors when survey_nonprob has no IPW or calibration history")
```
`class = "surveywts_error_jackknife_no_history"`.

```
test_that("DAGJK errors when IPW history has no reference and reference_sample = NULL")
test_that("DAGJK errors when Level B calibration history has no reference")
test_that("DAGJK errors when replicates = 'fifty'")
test_that("DAGJK errors when replicates = 5.5")
test_that("DAGJK errors when replicates = 1L")
test_that("DAGJK errors when replicates exceeds combined row count")
test_that("DAGJK errors when reference_sample is a data.frame")
test_that("DAGJK errors when all replicates fail")
```

Classes: `surveywts_error_jackknife_no_reference` (×2),
`surveywts_error_jackknife_replicates_invalid`,
`surveywts_error_replicates_not_whole_number`,
`surveywts_error_jackknife_replicates_too_small`,
`surveywts_error_jackknife_replicates_exceeds_n`,
`surveywts_error_reference_sample_class`,
`surveywts_error_jackknife_all_replicates_failed`.

For the "all replicates fail" test: engineer a `survey_nonprob` with
calibration targets that are impossible on any leave-one-group-out subset
(e.g., extreme targets that only work with the full sample). If engineering
this dataset proves impractical, document the approach in a `skip("reason")`
and file a follow-up. Do not use mocking packages.

**Warning paths** (in addition to the blocks above, per test-spec warnings table):
```
test_that("jackknife_replicates_failed warning when > 10% replicates fail")
```
`expect_warning(..., class = "surveywts_warning_jackknife_replicates_failed")`.
`test_invariants(result)`, `length(result@variables$repweights) < replicates`,
`result@variables$scale == (G_success - 1) / G_success`.

```
test_that("jackknife_negative_replicate_weights warning when calibration produces negatives")
```
`test_invariants(result)`, at least one value in replicate matrix < 0.

**History entry validation (DAGJK path):**
```
test_that("DAGJK history entry has operation='jackknife_weights', no method field, correct parameters")
```
Assert: `entry$operation == "jackknife_weights"`, `is.null(entry$method)`,
`entry$parameters$type == "grouped"`, `entry$parameters$replicates` is integer,
`entry$parameters$replicates_used` is integer,
`entry$parameters$replicates_failed` is integer,
`entry$parameters$mse == TRUE`,
`is.numeric(entry$parameters$scale)`.

Run `devtools::test(filter = "nps-jackknife")` → all tests FAIL RED.

---

#### Task 2.3 — Write RED tests: update `test-replicate-dispatch.R` (3 min)

Add two blocks:

```
test_that("create_replicate_weights(method='jackknife', type='grouped') dispatches DAGJK when data is survey_nonprob")
```
`create_replicate_weights(data, method = "jackknife", type = "grouped", replicates = 10L, seed = 1)`
where `data` is an inline `survey_nonprob` with calibration history.
Assert: result is `survey_nonprob`, `result@variables$type == "group-jackknife"`.

```
test_that("create_replicate_weights(method='group-jackknife') errors from rlang::arg_match()")
```
Dual pattern. `method = "group-jackknife"` is no longer a valid choice after
PR 2. `rlang::arg_match()` throws its own error class (not a custom
surveywts class); use `expect_error(...)` without a specific `class=` arg, OR
capture the rlang arg_match error class from a test run and use it.
`expect_snapshot(error = TRUE, ...)` for the message.

Remove the existing `"group-jackknife"` success dispatch test (the one that
currently calls `create_group_jackknife_weights()` via the dispatcher).

Run `devtools::test(filter = "replicate-dispatch")` → new blocks FAIL RED.

---

#### Task 2.4 — Update `R/jackknife-dagjk-utils.R` (5 min)

Modify the helpers from PR 1 with two changes each:

**`.dagjk_single_replicate()`:**

1. **Inf weight check** (spec §DAGJK internals "Degenerate check"): update the
   validation guard from:
   ```r
   if (any(is.na(w_g)) || any(w_g <= 0))
   ```
   to:
   ```r
   if (any(is.na(w_g)) || any(!is.finite(w_g)) || any(w_g <= 0))
   ```
   Apply this to both `# nocov` guarded blocks within `.dagjk_single_replicate()`.

2. **Extended formula** (spec §DAGJK internals "Stratum-level dispatch"):  
   Read `plans/spec-jackknife-merge.md §DAGJK internals` and
   `plans/comprehension-jackknife-merge.md` before implementing.
   
   The extended formula applies per NPS stratum when `n_h < G` where `n_h` is
   the PSU count for stratum `h` in the NPS and `n_hg` is the count of PSUs
   from stratum `h` in group `g`. Per-stratum dispatch:
   - `n_hg == 0`: weights unchanged
   - `n_h >= G`: standard zero-and-rescale rule (existing behavior)
   - `n_h < G`: extended formula with `Z = sqrt(G / ((G-1) * n_h * (n_h-1)))`;
     deleted PSU factor = `1 - (n_h - 1) * Z`; retained stratum-h PSU
     factor = `1 + Z`

   Note: for `survey_nonprob` inputs with no explicit `@variables$strata`,
   `n_h = n_nps` and the condition `n_h < G` is prevented by
   `surveywts_error_jackknife_replicates_exceeds_n`. The extended formula path
   is only reachable when the NPS has an explicit stratum variable. Test coverage
   for this path comes from the "DAGJK routes to IPW (doubly-robust)" test.

**`.dagjk_single_replicate_calib()`:**

1. **Inf weight check**: same change as above — add `any(!is.finite(w_g))` to
   the degenerate condition.
   
2. No extended formula changes needed in the calibration-only helper (the
   stratum-level dispatch applies within the IPW path helper only).

---

#### Task 2.5 — Implement `R/create_jackknife_weights.R` (5 min)

Replace the file in full. File layout: roxygen block first, then function
body. No internal helpers — all DAGJK internals live in `jackknife-dagjk-utils.R`.

**Signature:**
```r
create_jackknife_weights <- function(
  data,
  replicates = NULL,
  ...,
  type = c("jkn", "jk1", "grouped"),
  mse = TRUE,
  var_strat = NULL,
  var_strat_frac = NULL,
  sort_var = NULL,
  adj_method = c("variance-stratum-psus", "variance-units"),
  scale_method = c("variance-stratum-psus", "variance-units"),
  reference_sample = NULL,
  seed = NULL
)
```

**Validation steps 1–4 (every path):**
1. `rlang::check_dots_empty()`
2. `.validate_replicate_input(data)` — rejects data.frame, weighted_df,
   survey_replicate, unsupported classes
3. `type <- rlang::arg_match(type)`
4. If `S7::S7_inherits(data, surveycore::survey_nonprob)` AND
   `type %in% c("jkn", "jk1")`: abort with
   `surveywts_error_jackknife_type_nonprob_only`

**Pre-dispatch: grouped + replicates = NULL check:**
After step 4, for `type == "grouped"` and `is.null(replicates)`: abort with
`surveywts_error_jackknife_replicates_required`. This applies to BOTH
`survey_taylor` and `survey_nonprob` inputs (test-spec tests both).

**JKn/JK1 dispatch** (spec §Backend contracts §JKn/JK1 path):
```r
jk_type <- if (type == "jkn") "JKn" else "JK1"
.convert_and_call(
  data       = data,
  backend_fn = function(d) survey::as.svrepdesign(d, type = jk_type, mse = mse),
  method     = "jackknife",
  params     = list(type = type, mse = mse),
  seed       = NULL
)
```
CRITICAL: never auto-detect `jk_type` from `data@variables$strata`. The old
implementation did this; the new spec replaces it with user-controlled dispatch.

**Grouped + survey_taylor dispatch** (spec §Backend contracts §Grouped +
survey_taylor path):
```r
replicates <- .validate_replicates_arg(replicates)
.convert_and_call(
  data       = data,
  backend_fn = function(d)
    svrep::as_random_group_jackknife_design(
      d, replicates = replicates, mse = mse,
      var_strat = var_strat, var_strat_frac = var_strat_frac,
      sort_var = sort_var, adj_method = adj_method,
      scale_method = scale_method
    ),
  method     = "jackknife",
  params     = list(
    type = "grouped", replicates = replicates, mse = mse,
    var_strat = var_strat, var_strat_frac = var_strat_frac,
    sort_var = sort_var, adj_method = adj_method,
    scale_method = scale_method
  ),
  seed       = seed
)
```

**DAGJK dispatch** (spec §Input validation order steps 5–15 + §Backend
contracts §DAGJK path):

Steps 5–15 (implemented in order):
- Step 5: if `!is.null(reference_sample)`, call `.validate_reference_sample(reference_sample)`
- Step 6: already done (replicates required check above)
- Step 7: `.validate_replicates_dagjk_arg(replicates, combined_n = Inf)` —
  Phase 1 (type, whole-number, minimum ≥ 2)
- Step 8: scan `data@metadata@weighting_history` for ipw entries and last
  calibration entry; if neither found, abort with
  `surveywts_error_jackknife_no_history`
- Step 9: `use_level_b <- isTRUE(calib_entry$parameters$targets_from_reference)`
- Step 10: reference resolution (conditional):
  - IPW path: `ref_design <- reference_sample %||% ipw_entry$reference_design`;
    if NULL abort with `surveywts_error_jackknife_no_reference`; set `n_ref`,
    `combined_n`
  - Calibration Level B: resolve from `calib_entry$parameters$reference_design`;
    same error if NULL
  - Calibration Level A: `ref_design = NULL`, `n_ref = 0L`,
    `combined_n = n_nps`
- Step 11: `.validate_replicates_dagjk_arg(replicates, combined_n = combined_n)`
  — Phase 2 (ceiling check)
- Step 12: if `mse == FALSE`, warn `surveywts_warning_jackknife_mse_overridden`,
  set `mse <- TRUE`
- Step 13: if any of `var_strat`, `var_strat_frac`, `sort_var` is non-NULL, OR
  `adj_method != "variance-stratum-psus"`, OR
  `scale_method != "variance-stratum-psus"` — warn ONCE with
  `surveywts_warning_jackknife_svrep_args_ignored`
- Step 14: `.handle_repweights_overwrite(data, fn_name = "create_jackknife_weights", warning_class = "surveywts_warning_jackknife_repweights_overwritten")`
- Step 15: if `floor(combined_n / replicates) < 5`, warn
  `surveywts_warning_jackknife_small_groups`

Then the engine loop (spec §DAGJK backend §Engine):
```r
replicates <- as.integer(replicates)
if (!is.null(seed)) set.seed(seed)
group_assign <- sample(rep(seq_len(replicates), length.out = combined_n))

wt_col   <- data@variables$weights
nps_data <- data@data
ref_data   <- if (!is.null(ref_design)) ref_design@data else NULL
ref_wt_col <- if (!is.null(ref_design)) ref_design@variables$weights else NULL

failed_reps <- 0L
repwt_list  <- list()

for (g in seq_len(replicates)) {
  rep_ok <- tryCatch({
    if (!is.null(ipw_entry)) {
      w_rep <- .dagjk_single_replicate(g, group_assign, nps_data, ref_data,
                 ref_wt_col, ipw_entry, calib_entry, n_nps, n_ref,
                 use_level_b, ref_design, wt_col)
    } else {
      w_rep <- .dagjk_single_replicate_calib(g, group_assign, nps_data,
                 ref_data, ref_wt_col, calib_entry, n_nps, n_ref,
                 use_level_b, ref_design, wt_col)
    }
    repwt_list[[length(repwt_list) + 1L]] <- w_rep
    TRUE
  }, error = function(e) FALSE)
  if (!isTRUE(rep_ok)) failed_reps <- failed_reps + 1L
}
```

Post-loop (spec §DAGJK backend §Post-loop):
```r
if (failed_reps > 0.1 * replicates)
  cli::cli_warn(..., class = "surveywts_warning_jackknife_replicates_failed")

G_success <- replicates - failed_reps

if (G_success == 0L)
  cli::cli_abort(..., class = "surveywts_error_jackknife_all_replicates_failed")

repwt_names <- paste0("repwt_", seq_len(G_success))
for (i in seq_len(G_success)) data@data[[repwt_names[i]]] <- repwt_list[[i]]

rep_mat <- as.matrix(data@data[, repwt_names, drop = FALSE])
if (any(rep_mat < 0, na.rm = TRUE))
  cli::cli_warn(..., class = "surveywts_warning_jackknife_negative_replicate_weights")

data@variables$repweights <- repwt_names
data@variables$scale      <- (G_success - 1L) / G_success
data@variables$rscales    <- rep(1, G_success)
data@variables$mse        <- TRUE
data@variables$type       <- "group-jackknife"
```

History entry (spec §History entry schema §DAGJK path):
```r
meta <- data@metadata
meta@weighting_history <- c(meta@weighting_history, list(list(
  step              = length(meta@weighting_history) + 1L,
  operation         = "jackknife_weights",
  timestamp         = Sys.time(),
  parameters        = list(
    type              = "grouped",
    replicates        = as.integer(replicates),
    replicates_used   = as.integer(G_success),
    replicates_failed = as.integer(failed_reps),
    mse               = TRUE,
    scale             = (G_success - 1L) / G_success,
    seed              = seed
  ),
  reference_design  = ref_design,
  source_design     = .snapshot_variables_for_history(data)
)))
data@metadata <- meta
```

---

#### Task 2.6 — Write roxygen docs for `create_jackknife_weights()` (5 min)

Full Tier 3 documentation per `function-documentation.md` and spec §Roxygen
documentation contract. Minimum required sections:

- `@title` — "Construct jackknife replicate weights"
- `@description` — per spec §Roxygen documentation contract §Description
- `@param` — all 12 params per spec §`@param` contracts, type-annotation-first
  format; include the "Intentional design" note in `@param replicates`
- `@returns` — per spec §Roxygen documentation contract §`@returns`
- `@section Algorithm:` — four `**Bold sub-headers**`:
  1. JKn (stratified delete-one jackknife) — include both `\deqn{}` forms (mse=TRUE and mse=FALSE)
  2. JK1 (unstratified delete-one jackknife) — include `\deqn{}` variance estimator
  3. Grouped jackknife (probability samples) — delegated to svrep
  4. Delete-a-group jackknife for non-probability samples (DAGJK) — include
     both the standard `\deqn{}` and the extended `\deqn{}` forms from spec
- `@section Limitations:` — 5 items per spec
- `@section Warnings:` — 3 items per spec
- `@references` — 6 entries per spec
- `@seealso` — link to all `@family replicate-weights` members (7 functions)
- `@family replicate-weights`
- `@export`
- `@examples` — three examples per spec:
  1. JKn on `gss_2024_svy` (strata: `vstrat`, PSUs: `vpsu`)
  2. Grouped jackknife on `gss_2024_svy`, `replicates = 20L`
  3. DAGJK on `ns_wave1_svy`, `replicates = 50L, seed = 42`
  Section header comment style: `# Brief label --------`

Note: `@examples` must run without `\dontrun{}` during `R CMD check`. Verify
that `library(svrep)` is not needed — the backends are called via `::`. If any
example requires an explicit `library()` call per the CLAUDE.md rule ("Examples
must load Imports packages explicitly"), add it.

---

#### Task 2.7 — Delete `R/create_group_jackknife_weights.R` (1 min)

Delete the file. Confirm there are no references to
`create_group_jackknife_weights` remaining in any file under `R/` or
`tests/testthat/` (grep check).

---

#### Task 2.8 — Update `R/create_replicate_weights.R` (3 min)

- Remove `"group-jackknife"` from the `method = c(...)` choices
- Remove the `"group-jackknife" = create_group_jackknife_weights(data, ...)`
  arm from `switch()`
- Update `@param method` documentation to remove `"group-jackknife"` from the
  choices list
- Update `@return` or `@returns` to remove the note about `survey_nonprob`
  output for `method = "group-jackknife"`; add a note that DAGJK is now
  accessible via `method = "jackknife"`, `type = "grouped"`

---

#### Task 2.9 — `devtools::document()` (2 min)

Run `devtools::document()`. Verify:
- `man/create_group_jackknife_weights.Rd` is gone
- `man/create_jackknife_weights.Rd` is regenerated with new content
- `NAMESPACE` no longer contains `export(create_group_jackknife_weights)`

---

#### Task 2.10 — Run tests GREEN and update snapshots (3 min)

Run `devtools::test()`. All three updated test files should pass GREEN.
Run `testthat::snapshot_review()` for any new snapshots from the PR 2 error
path tests. Review each diff to confirm it matches the expected error message
from the spec §Error catalogue before accepting.

---

#### Task 2.11 — Update rule files (3 min)

**`.claude/rules/surveywts-conventions.md`** — "File mapping (R/ → export)" table:
- Remove the `create_group_jackknife_weights.R` row
- Update `create_jackknife_weights.R` description to note it handles JKn, JK1,
  grouped + survey_taylor, and DAGJK
- "Family utils files" table: add `jackknife-dagjk-utils.R` row describing
  DAGJK engine internals for `create_jackknife_weights()`

**`.claude/rules/testing-surveywts.md`** — "File Mapping" table:
- Confirm the row for `jackknife-dagjk-utils.R` maps to `test-nps-jackknife.R`
  (should already be done per S-1 resolution)
- If not already updated, change `test-nps-group-jackknife.R` →
  `test-nps-jackknife.R`

---

**Notes for PR 2:**

- The `replicates = NULL` + `type = "grouped"` check (nominally step 6 in the
  spec's DAGJK-specific validation order) must be placed BEFORE the
  `survey_taylor` vs `survey_nonprob` branch — both paths use it. Implement it
  immediately after the step-4 type/class incompatibility check.
- For step 13 (svrep args check), "non-default" for `adj_method` and
  `scale_method` means the first element of the character vector default was
  not chosen. After `rlang::arg_match()`, these are scalar; compare directly:
  `adj_method != "variance-stratum-psus"` and
  `scale_method != "variance-stratum-psus"`.
- Do NOT attempt to reach `create_jackknife_weights()` from within
  `create_replicate_weights()` examples — the `@examples` for
  `create_replicate_weights()` already exist and must not break.
- The "all replicates fail" error test is the hardest to trigger cleanly.
  Design an inline `survey_nonprob` with a calibration history where the
  target proportions are exact population proportions (0 or 1) — any
  leave-one-group-out subset will fail to converge. If this approach doesn't
  work within the test budget, skip with an explanatory comment and file a
  follow-up issue.
- PR 2 depends on PR 1 being merged. Branch from `develop` after PR 1 merges.
