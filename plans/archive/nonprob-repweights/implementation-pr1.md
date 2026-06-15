# Implementation — PR 1 (nonprob-repweights: weight utilities routing)

**Spec**: `plans/spec-nonprob-repweights.md`
**Date**: 2026-06-15
**Branch**: `worktree-agent-a3bb51ba88f25fec2`

---

## What was implemented

- Added `.has_repweights(x)` internal predicate to `R/weight-utils.R`. Returns
  `TRUE` for `survey_replicate` (always) or `survey_nonprob` with
  `@variables$repweights` length >= 1. Returns `FALSE` for all other inputs
  including `NULL` without throwing.

- Replaced both `S7::S7_inherits(data, surveycore::survey_replicate)` class
  guards in `trim_weights()` (Step 7 and output construction) with
  `.has_repweights(data)`. The replicate-column clip-and-redistribute path now
  fires for `survey_nonprob` objects with repweights.

- Replaced three `S7::S7_inherits(data, surveycore::survey_replicate)` guards
  in `stabilize_weights()` (global scaling, per-group scaling, and output
  construction) with `.has_repweights(data)`. Both global and per-group
  replicate-column scaling now fire for `survey_nonprob` with repweights.

- Updated roxygen for `trim_weights()` and `stabilize_weights()`:
  `@description` updated to mention `survey_nonprob with repweights`;
  `@param data` updated with forward reference to Replicate Weights section;
  `@returns` updated to standard phrasing; `@section Replicate Weights:`
  block added to both. Ran `devtools::document()`.

- Added 58 new unit tests in `tests/testthat/test-weight-utils.R` covering:
  `.has_repweights()` (9 cases: survey_replicate TRUE, nonprob with reps TRUE,
  nonprob NULL reps FALSE, nonprob character(0) reps FALSE, survey_taylor FALSE,
  weighted_df FALSE, data.frame FALSE, NULL FALSE, list FALSE);
  `trim_weights()` with nonprob+repweights (7 cases: class preserved, rep
  columns updated, bounds applied to reps, history entry appended, no-rep path
  unchanged, warning fires, strict flag handled);
  `stabilize_weights()` with nonprob+repweights (7 cases: class preserved,
  global scaling, per-group scaling, history entry, no-rep path unchanged,
  scale=1 no-op, two-rep-column scaling correctness).

---

## Task checklist

- [x] Add `.has_repweights()` to `R/weight-utils.R`
- [x] Replace Step 7 guard in `trim_weights()` with `.has_repweights(data)`
- [x] Replace output-construction branch guard in `trim_weights()` with `.has_repweights(data)`
- [x] Update `trim_weights()` roxygen: `@description`, `@param data`, `@returns`, `@section Replicate Weights:`
- [x] Replace global scaling guard in `stabilize_weights()` with `.has_repweights(data)`
- [x] Replace per-group scaling guard in `stabilize_weights()` with `.has_repweights(data)`
- [x] Replace output-construction branch guard in `stabilize_weights()` with `.has_repweights(data)`
- [x] Update `stabilize_weights()` roxygen: `@description`, `@param data`, `@returns`, `@section Replicate Weights:`
- [x] Run `devtools::document()` — `man/trim_weights.Rd` and `man/stabilize_weights.Rd` regenerated
- [x] All 438 tests pass (380 pre-existing + 58 new)
- [x] `devtools::check()`: 0 errors, 0 warnings, 1 note (worktree `.git` artifact)
- [x] Created `changelog/utilities/feature-nonprob-repweights-utils.md`

---

## Deviations from spec

None.

---

## HOLDs raised

None.

---

## CRAN compliance checklist

1. [x] TRUE/FALSE used throughout (no T/F)
2. [x] `::` used for all external calls (no `@importFrom` except S3 registration)
3. [x] No bare `print()`/`cat()` in non-print-method code
4. [x] No randomness in new code (no `seed` arg needed)
5. [x] No `par()`/`options()` modification
6. [x] No file writing in new code
7. [x] No examples in new internal helpers (not exported)
8. [x] `devtools::document()` run — NAMESPACE and `man/` in sync
9. [x] `requireNamespace()` not used (no new optional dependency checks)
10. [x] All `cli_abort()`/`cli_warn()` calls have `class=`; all classes exist in `plans/error-messages.md`

---

## Write surface (files modified/created)

| File | Action |
|------|--------|
| `R/weight-utils.R` | Modified — added `.has_repweights()` |
| `R/trim_weights.R` | Modified — replaced 2 class guards; updated roxygen |
| `R/stabilize_weights.R` | Modified — replaced 3 class guards; updated roxygen |
| `man/trim_weights.Rd` | Regenerated via `devtools::document()` |
| `man/stabilize_weights.Rd` | Regenerated via `devtools::document()` |
| `tests/testthat/test-weight-utils.R` | Modified — added 58 new test blocks |
| `changelog/utilities/feature-nonprob-repweights-utils.md` | Created |
| `plans/implementation-pr1.md` | Created (this file) |

---

## Notes for tester

- The worktree branch was merged with `develop` at the start of this session to
  pick up all current package files. The `.git` note in `devtools::check()` is
  a worktree artifact only (the `.git` directory of the parent repo appears in
  the worktree's package root); it will not appear in CI or normal development.

- The test fixture `.make_nonprob_with_repweights()` uses
  `surveycore::as_survey_nonprob()` which requires >= 2 replicate weight
  columns. The "single-rep" edge case test was adjusted to use 2 columns
  and verify the first column's scaling.

- The `character(0)` repweights edge case test modifies `@variables` via
  `modifyList(nonprob_rep@variables, list(repweights = character(0)))` to
  bypass the `as_survey_nonprob()` minimum-2-replicates validation.
