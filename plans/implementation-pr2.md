# Implementation — PR 2 — nonprob-repweights

## Write surface

- `R/diagnostics-utils.R` — modified (removed 9-line `survey_replicate` rejection block from `.diag_validate_input()`)
- `tests/testthat/test-06-diagnostics.R` — modified (replaced 3 rejection blocks in section 11 with 10 new acceptance + numerical correctness + regression + edge case blocks)
- `tests/testthat/_snaps/06-diagnostics.md` — modified (deleted "effective_sample_size() rejects survey_replicate input" block; snapshot deletion was already applied by the develop merge)
- `plans/error-messages.md` — committed as-is (RETIRED annotation already present in develop; no re-edit)
- `changelog/utilities/feature-nonprob-repweights-diagnostics.md` — created

## Summary

- Removed the `if (S7::S7_inherits(x, surveycore::survey_replicate))` guard from `.diag_validate_input()` in `R/diagnostics-utils.R`; `survey_replicate` now falls through to the existing `survey_base` path, which already accepted it structurally.
- All three diagnostic functions (`effective_sample_size()`, `weight_variability()`, `summarize_weights()`) now accept `survey_replicate` inputs and compute diagnostics on the main weight column only (`@variables$weights` in `@data`).
- Replaced the three rejection `test_that()` blocks in section 11 of `test-06-diagnostics.R` with 10 new blocks covering: happy path (accept without error), numerical correctness (ESS and CV formulas verified at `1e-10`), cross-class agreement (survey_replicate matches survey_taylor with same main weights), regression (pre-existing error classes still fire), and edge cases (by-grouping, equal-weight).
- Deleted the snapshot block "effective_sample_size() rejects survey_replicate input" from `_snaps/06-diagnostics.md` (deletion was already present in the develop merge).
- `devtools::check()` passes with 0 errors, 0 warnings, 1 note (environment artifact — acceptable).

## Task checklist

- [x] Read `R/diagnostics-utils.R` to locate the guard block
- [x] Read `tests/testthat/test-06-diagnostics.R` to understand the three rejection blocks in section 11
- [x] Read `tests/testthat/_snaps/06-diagnostics.md` to locate the snapshot to delete
- [x] Wrote failing acceptance tests (TDD red step) — confirmed 8 failures with `surveywts_error_replicate_not_supported`
- [x] Removed the 9-line `survey_replicate` rejection block from `.diag_validate_input()`
- [x] Snapshot block already deleted by develop merge — no manual edit needed
- [x] Ran `devtools::test(filter = "06-diagnostics")` — 65 pass, 0 fail
- [x] Ran `devtools::test()` (full suite) — 3473 pass, 0 fail
- [x] Ran `devtools::document()` — no NAMESPACE or man/ drift
- [x] Ran `devtools::check()` — 0 errors, 0 warnings, 1 note
- [x] Created `changelog/utilities/feature-nonprob-repweights-diagnostics.md`
- [x] Committed all changes on `worktree-agent-a8991cfa783658738` branch

## Signals raised

None. No HOLDs.

## CRAN compliance

- [x] TRUE/FALSE used throughout (no T/F)
- [x] `::` used for all external calls (no `@importFrom` added)
- [x] No bare `print()`/`cat()` in non-print-method code
- [x] No randomness added — `seed` argument not applicable
- [x] No `par()`/`options()` modifications — `on.exit()` not needed
- [x] No file writing — `tempdir()` not needed
- [x] ≤2 cores in examples/tests — no parallel code added
- [x] `devtools::document()` run — NAMESPACE and `man/` in sync
- [x] No `requireNamespace()` calls added
- [x] All remaining `cli_abort()`/`cli_warn()` have `class=` — removed block used `class=`; remaining calls are unchanged

## Notes for tester

- The `make_replicate_design(seed = 1)` helper already existed in `tests/testthat/helper-test-data.R` and was used as the shared fixture across all new section 11 blocks.
- The snapshot block deletion was already present in the develop merge (the file in the worktree after merging develop already lacked the block). The diff confirms the deletion is committed.
- All new tests use `skip_if_not_installed("svrep")` at block level as required (svrep is a Suggests dependency used by the bootstrap weight creation pipeline).
- Test count before this PR in `test-06-diagnostics.R`: 54 passing, 3 rejection tests (which were erroneous in the new context). After: 65 passing, 0 rejection tests for the retired error class.
