# Implementation Plan — nonprob-repweights

**Status:** DRAFT
**Spec:** `plans/spec-nonprob-repweights.md`
**Test-spec:** `plans/test-spec-nonprob-repweights.md`
**Target version:** 0.5.0.9000

---

## Overview

This plan delivers two behavioral changes: (1) extending `trim_weights()` and
`stabilize_weights()` to apply their replicate-column paths to `survey_nonprob`
objects with `@variables$repweights` non-NULL, via a new `.has_repweights()`
internal predicate; and (2) removing the `survey_replicate` rejection guard
from `.diag_validate_input()` so all three diagnostic functions accept
`survey_replicate` input.

The two behaviors are test-observable and independent — they are split into two
PRs so builder and tester work on non-overlapping file surfaces.

---

## PR map

- [x] PR 1: `feature/nonprob-repweights-utils` — Add `.has_repweights()` and extend replicate-column paths in `trim_weights()` and `stabilize_weights()`
- [x] PR 2: `feature/nonprob-repweights-diagnostics` — Remove `survey_replicate` rejection guard from `.diag_validate_input()`

---

## PR 1: Weight utilities — nonprob-repweights routing

**Branch:** `feature/nonprob-repweights-utils`
**Depends on:** none

### Files (TDD order — tests first)

- `tests/testthat/test-weight-utils.R` — add failing tests for `.has_repweights()`, new `trim_weights()` nonprob-repweights behaviors, new `stabilize_weights()` nonprob-repweights behaviors (see test-spec §`.has_repweights`, §`trim_weights`, §`stabilize_weights`)
- `R/weight-utils.R` — add `.has_repweights()` predicate below `.check_weight_utils_class()`
- `R/trim_weights.R` — replace `survey_replicate` class guard in Step 7 with `.has_repweights(data)`; replace matching guard in output-construction branch; update `@description`, `@param data`, add `@section Replicate Weights:` block
- `R/stabilize_weights.R` — replace `survey_replicate` class guards in global and per-group scaling blocks and output-construction branch with `.has_repweights(data)`; update `@description`, `@param data`, add `@section Replicate Weights:` block

### Acceptance criteria

- [ ] All new tests confirmed failing (red) before implementation began
- [ ] `devtools::check()` 0 errors, 0 warnings, ≤2 pre-approved notes
- [ ] `devtools::document()` run; NAMESPACE and `man/` in sync
- [ ] **Documentation — `trim_weights.R`**: `@description` updated to include `survey_nonprob` with repweights; `@param data` updated with forward reference to the Replicate Weights section; `@section Replicate Weights:` block present (spec §trim_weights() documentation requirements)
- [ ] **Documentation — `stabilize_weights.R`**: `@description` updated to include `survey_nonprob` with repweights; `@param data` updated with forward reference to the Replicate Weights section; `@section Replicate Weights:` block present (spec §stabilize_weights() documentation requirements)
- [ ] **`.has_repweights()` predicate**: returns `TRUE` for `survey_replicate`; returns `TRUE` for `survey_nonprob` with `@variables$repweights` length ≥ 1; returns `FALSE` for `survey_nonprob` with `NULL` repweights; returns `FALSE` for `survey_nonprob` with `character(0)` repweights; returns `FALSE` for `data.frame`, `survey_taylor`, `weighted_df` (test-spec §`.has_repweights` — happy path and edge cases)
- [ ] **`.has_repweights()` `NULL` safety**: returns `FALSE` for `NULL` input and does not throw (spec §.has_repweights() Errors contract — "must not throw")
- [ ] **`trim_weights()` class preservation**: `survey_nonprob` with repweights → result class is `survey_nonprob` (test-spec §`trim_weights` happy path row 1)
- [ ] **`trim_weights()` replicate column update**: all `@variables$repweights` columns present in `result@data`; values changed after trimming; dimensions unchanged (test-spec rows 2–4)
- [ ] **`trim_weights()` numerical bounds**: all result repweight values ≤ `upper_abs + eps`; column-sum preservation for majority of columns at tolerance `1e-8` (test-spec §Numerical correctness)
- [ ] **`trim_weights()` weighting history**: entry appended; `operation == "trim_weights"`; `upper_abs` recorded correctly (test-spec §Weighting history)
- [ ] **`trim_weights()` warning paths**: `surveywts_warning_no_weights_trimmed` fires for `nonprob_rep` with `upper = Inf` (test-spec §Warning paths)
- [ ] **`trim_weights()` error regression**: `surveywts_error_empty_data` and `surveywts_error_weights_nonpositive` still fire for `survey_nonprob` inputs (test-spec §Error paths)
- [ ] **`trim_weights()` edge cases**: all-outside-bounds replicate column (no error, no warning); single replicate column; `repweights = NULL` (no replicate path); main-within-bounds but rep-outside (warning fires, main unchanged, rep clipped) (test-spec §Edge cases)
- [ ] **`stabilize_weights()` class preservation**: `survey_nonprob` with repweights → result class is `survey_nonprob` (test-spec §`stabilize_weights` happy path row 1)
- [ ] **`stabilize_weights()` global scaling**: `sum(result_main) == n` at `1e-10`; `colSums(result_rep)` = `colSums(orig_rep) * scale_f` at `1e-10`; `scale_factor` in history matches `n / sum(orig_main)` (test-spec §Numerical correctness — global)
- [ ] **`stabilize_weights()` per-group scaling**: per-group main sum `== n_h` at `1e-10`; for each group `h` and each replicate column `j`: `sum(result_rep[h, j]) == sum(orig_rep[h, j]) * (n_h / W_h)` at `1e-10` (test-spec §Numerical correctness — per-group)
- [ ] **`stabilize_weights()` weighting history**: entry appended; `operation == "stabilize_weights"` (test-spec §Weighting history)
- [ ] **`stabilize_weights()` error regression**: `surveywts_error_empty_data` fires for 0-row `survey_nonprob` with repweights (test-spec §Error paths)
- [ ] **`stabilize_weights()` edge cases**: scale factor `1.0` when main weights already sum to `n` (columns unchanged); `repweights = NULL` no replicate scaling; single replicate column scaled correctly (test-spec §Edge cases)
- [ ] **Pre-existing tests**: all prior tests in `test-weight-utils.R` continue to pass (spec Quality gate 9)
- [ ] `covr::package_coverage()` ≥ 95%; new branches in `.has_repweights()` and the nonprob-repweights output routing must be covered (test-spec §Profile gates)
- [ ] **Changelog**: `changelog/utilities/feature-nonprob-repweights-utils.md` created and committed on this branch before opening the PR

### Notes

**`.has_repweights()` logic:** Returns `TRUE` if `S7::S7_inherits(x, surveycore::survey_replicate)` OR if `S7::S7_inherits(x, surveycore::survey_nonprob) && !is.null(x@variables$repweights) && length(x@variables$repweights) >= 1L`. Returns `FALSE` for everything else including `NULL` input (must not throw). Place below `.check_weight_utils_class()` in `weight-utils.R`.

**`trim_weights()` changes — three edit points:**
1. Step 7 guard: `S7::S7_inherits(data, surveycore::survey_replicate)` → `.has_repweights(data)`. The `rwnew` matrix computed inside this block is referenced in the output construction below — both guards must use the same predicate.
2. Output construction (Step 9): `else if (S7::S7_inherits(data, surveycore::survey_replicate))` → `else if (.has_repweights(data))`. The writeback `result_design@data[data@variables$repweights] <- as.data.frame(rwnew)` works for both `survey_replicate` and `survey_nonprob` because both classes carry `@variables$repweights`.
3. Roxygen: update `@description` sentence from "for `survey_replicate` input" to "for inputs carrying replicate weight columns (`survey_replicate` or `survey_nonprob` with `repweights`)"; update `@param data` to add forward reference to the Replicate Weights section; add `@section Replicate Weights:` documenting bounds applied to all replicate columns and that the `strict` loop is not applied to replicate columns.

**`stabilize_weights()` changes — four edit points:**
1. Global scaling block guard: `S7::S7_inherits(data, surveycore::survey_replicate)` → `.has_repweights(data)`
2. Per-group scaling block guard: same replacement
3. Output construction: `else if (S7::S7_inherits(data, surveycore::survey_replicate))` → `else if (.has_repweights(data))`
4. Roxygen: same pattern as `trim_weights()` — update `@description`, `@param data`, add `@section Replicate Weights:`.

**Test fixture — `nonprob_rep`:** Construct per the test-spec standard pattern (see test-spec "Standard nonprob-with-repweights fixture"). Use `surveycore::as_survey_nonprob()` with `weights = base_weight, repweights = tidyselect::starts_with("rep_"), type = "bootstrap", scale = 1 / n_rep, mse = TRUE`. For the `character(0)` edge case use `obj@variables <- modifyList(obj@variables, list(repweights = character(0)))` (S7 does not support index-assign into a property).

**Changelog:** Create `changelog/utilities/feature-nonprob-repweights-utils.md` before opening the PR. No NEWS.md entry yet (post-merge task).

---

## PR 2: Diagnostics — accept `survey_replicate` input

**Branch:** `feature/nonprob-repweights-diagnostics`
**Depends on:** none (independent of PR 1 — different files)

### Files (TDD order — tests first)

- `tests/testthat/test-06-diagnostics.R` — replace the three `survey_replicate` rejection test blocks (section 11) with new acceptance + numerical correctness tests; delete snapshot entry for the retired test (see test-spec §Diagnostic functions)
- `tests/testthat/_snaps/06-diagnostics.md` — delete the snapshot block "effective_sample_size() rejects survey_replicate input" (lines 81–90 in the current file)
- `R/diagnostics-utils.R` — remove the 9-line `survey_replicate` rejection block (lines 20–29)
- `plans/error-messages.md` — **already updated** (RETIRED annotation is already in the file; commit as-is on this branch)

### Acceptance criteria

- [ ] All new tests confirmed failing (red) before implementation began (i.e., before the guard is removed, the acceptance tests must fail with the old error)
- [ ] `devtools::check()` 0 errors, 0 warnings, ≤2 pre-approved notes
- [ ] `devtools::document()` run; NAMESPACE and `man/` in sync
- [ ] **`effective_sample_size()` accepts `survey_replicate`**: `expect_no_error()` with `make_replicate_design(seed = 1)` (test-spec §Happy path)
- [ ] **`weight_variability()` accepts `survey_replicate`**: `expect_no_error()` with `make_replicate_design(seed = 1)` (test-spec §Happy path)
- [ ] **`summarize_weights()` accepts `survey_replicate`**: `expect_no_error()` with `make_replicate_design(seed = 1)` (test-spec §Happy path)
- [ ] **Numerical correctness — `effective_sample_size()`**: result `n_eff == sum(w)^2 / sum(w^2)` from main weight column at tolerance `1e-10` (test-spec §Numerical correctness)
- [ ] **Numerical correctness — `weight_variability()`**: result `cv == sd(w) / mean(w)` from main weight column at tolerance `1e-10`
- [ ] **`survey_replicate` result matches `survey_taylor`** with same main weights: `effective_sample_size()` returns identical `n_eff` at `1e-10` (test-spec §Happy path row 4)
- [ ] **Retired error no longer thrown**: all three `expect_no_error()` assertions pass; the old `expect_error(class = "surveywts_error_replicate_not_supported")` assertions are removed
- [ ] **Snapshot deleted**: snapshot block "effective_sample_size() rejects survey_replicate input" removed from `_snaps/06-diagnostics.md`; `testthat::snapshot_review()` run and deletion accepted (test-spec §Profile gates — Snapshot review)
- [ ] **Regression — pre-existing error paths**: `surveywts_error_weights_required` still fires for plain `data.frame` with `weights = NULL`; `surveywts_error_unsupported_class` still fires for list input — both using `expect_error(class=)` + snapshot (test-spec §Regression)
- [ ] **Edge cases**: `summarize_weights()` with `survey_replicate` + `by = age_group` returns grouped tibble; `survey_replicate` with equal main weights gives `n_eff == n` and `cv == 0` (test-spec §Edge cases)
- [ ] **Pre-existing tests**: all prior tests in `test-06-diagnostics.R` (except the three retired rejection blocks) continue to pass
- [ ] `covr::package_coverage()` ≥ 95%
- [ ] **Changelog**: `changelog/utilities/feature-nonprob-repweights-diagnostics.md` created and committed on this branch before opening the PR

### Notes

**Guard removal in `diagnostics-utils.R`:** Delete lines 20–29 (the 9-line `if (S7::S7_inherits(x, surveycore::survey_replicate)) { cli::cli_abort(...) }` block). After removal, `survey_replicate` objects fall through to the existing `is_supported` check (which already accepts `survey_base` subclasses) and then to `data_df <- x@data; weight_col <- .get_weight_col_name(x, weights_quo)` — the same path used by `survey_taylor` and `survey_nonprob`. No special casing needed.

**Snapshot deletion:** The snapshot file `_snaps/06-diagnostics.md` has one snapshot block at lines 81–90 ("effective_sample_size() rejects survey_replicate input"). The other two rejection tests (`weight_variability()`, `summarize_weights()`) did not generate snapshots in the existing test suite. Delete only the snapshot block at lines 81–90 and run `testthat::snapshot_review()` to accept the deletion.

**Retiring test blocks:** The three `test_that()` blocks in section "11. survey_replicate input → surveywts_error_replicate_not_supported" must be fully replaced. Do not leave them in place with `expect_no_error()` substituted — replace with the new acceptance test blocks from the test-spec (happy path, numerical correctness, error-path retirement verification, edge cases).

**`plans/error-messages.md` is already updated** with `surveywts_error_replicate_not_supported` marked RETIRED. Commit it on this branch without modification. Do not re-edit it.

**Changelog:** Create `changelog/utilities/feature-nonprob-repweights-diagnostics.md` before opening the PR.

---

## Write-surface audit

| File | PR |
|------|----|
| `R/weight-utils.R` | PR 1 |
| `R/trim_weights.R` | PR 1 |
| `R/stabilize_weights.R` | PR 1 |
| `tests/testthat/test-weight-utils.R` | PR 1 |
| `R/diagnostics-utils.R` | PR 2 |
| `tests/testthat/test-06-diagnostics.R` | PR 2 |
| `tests/testthat/_snaps/06-diagnostics.md` | PR 2 |
| `plans/error-messages.md` | PR 2 (commit existing modification) |
| `man/trim_weights.Rd` | PR 1 (via `devtools::document()`) |
| `man/stabilize_weights.Rd` | PR 1 (via `devtools::document()`) |
| `changelog/utilities/feature-nonprob-repweights-utils.md` | PR 1 |
| `changelog/utilities/feature-nonprob-repweights-diagnostics.md` | PR 2 |

No file appears in both PRs. PRs may be opened and merged in any order.
