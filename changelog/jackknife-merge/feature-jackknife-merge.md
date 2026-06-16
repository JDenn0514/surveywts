# PR 2: Merge create_group_jackknife_weights() into create_jackknife_weights()

**Branch:** `feature/jackknife-merge`
**Type:** feat(replicate-weights) — public API change

## Summary

Merged `create_group_jackknife_weights()` into `create_jackknife_weights()` by
adding a `type` argument (`"jkn"`, `"jk1"`, `"grouped"`). The DAGJK path is
now invoked via `create_jackknife_weights(data, replicates = G, type = "grouped")`.
`create_group_jackknife_weights()` is removed. `create_replicate_weights()`
no longer accepts `method = "group-jackknife"`.

## Files changed

- `R/create_jackknife_weights.R` — REPLACED: full merged implementation with
  `type` argument, full 15-step validation, Tier 3 roxygen docs
- `R/create_group_jackknife_weights.R` — DELETED
- `R/create_replicate_weights.R` — MODIFIED: removed `"group-jackknife"` arm;
  updated docs to reference `method = "jackknife"` + `type = "grouped"`
- `tests/testthat/test-nps-jackknife.R` — NEW: all DAGJK tests (migrated from
  `test-nps-group-jackknife.R`; updated to new API)
- `tests/testthat/test-nps-group-jackknife.R` — DELETED
- `tests/testthat/_snaps/nps-group-jackknife.md` — DELETED
- `tests/testthat/test-replicate-weights.R` — MODIFIED: all old type strings
  replaced; new error/warning class names; new jkn/jk1/grouped tests
- `tests/testthat/test-replicate-dispatch.R` — MODIFIED: group-jackknife test
  replaced with jackknife+grouped test; error test for removed method added
- `tests/testthat/test-replicate-print.R` — MODIFIED: `type = "delete-1"`
  updated to `type = "jkn"`
- `tests/testthat/_snaps/replicate-weights.md` — MODIFIED: stale entries
  removed; new entries auto-generated
- `tests/testthat/_snaps/replicate-print.md` — MODIFIED: snapshot updated to
  reflect `type = "jkn"` in history entry (was `"JKn"`)
- `plans/error-messages.md` — MODIFIED: new classes added
- `.claude/rules/surveywts-conventions.md` — MODIFIED: file mapping updated
- `.claude/rules/testing-surveywts.md` — MODIFIED: file mapping updated

## API changes

| Old API | New API |
|---------|---------|
| `create_group_jackknife_weights(data, groups = G, seed = S)` | `create_jackknife_weights(data, replicates = G, type = "grouped", seed = S)` |
| `create_replicate_weights(data, method = "group-jackknife", groups = G, seed = S)` | `create_replicate_weights(data, method = "jackknife", type = "grouped", replicates = G, seed = S)` |
| `create_jackknife_weights(data, type = "delete-1")` | `create_jackknife_weights(data, type = "jkn")` |
| `create_jackknife_weights(data, type = "random-groups", replicates = G)` | `create_jackknife_weights(data, type = "grouped", replicates = G)` |

## New error/warning classes added

| Class | Trigger |
|-------|---------|
| `surveywts_error_jackknife_type_nonprob_only` | `survey_nonprob` + `type = "jkn"` or `"jk1"` |
| `surveywts_error_jackknife_replicates_required` | `type = "grouped"` + `replicates = NULL` |
| `surveywts_warning_jackknife_mse_overridden` | DAGJK path + `mse = FALSE` |
| `surveywts_warning_jackknife_svrep_args_ignored` | DAGJK path + non-default `var_strat`/`adj_method`/`scale_method` |

## History entry change

| Path | Old operation | New operation |
|------|---------------|---------------|
| DAGJK (`survey_nonprob` + `type = "grouped"`) | `"group_jackknife_weights"` | `"jackknife_weights"` |

## Notes

- 3568 tests pass; 0 failures, 3 skips (mice-related)
- 851 warnings are all expected (ipw convergence noise inside DAGJK loops,
  plus trim_weights edge cases)
- JKn and JK1 store `type = "jkn"` / `type = "jk1"` in history (the
  user-supplied string), not the backend strings `"JKn"` / `"JK1"`.
  The snapshot for `test-replicate-print.R` was updated accordingly.
