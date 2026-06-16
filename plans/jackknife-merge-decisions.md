# Jackknife Merge: Design Decisions

**Status:** Decisions finalized — ready to spec  
**Goal:** Merge `create_jackknife_weights()` and `create_group_jackknife_weights()` into a single `create_jackknife_weights()` with expanded capabilities.

---

## What's Changing

The two existing jackknife functions are replaced by one. The new `create_jackknife_weights()` handles all jackknife variants via a `type` argument:

| `type` | Input class | Backend |
|--------|-------------|---------|
| `"jkn"` | `survey_taylor` only | `survey::as.svrepdesign(type = "JKn")` |
| `"jk1"` | `survey_taylor` only | `survey::as.svrepdesign(type = "JK1")` |
| `"grouped"` + `survey_taylor` | `survey_taylor` only | `svrep::as_random_group_jackknife_design()` |
| `"grouped"` + `survey_nonprob` | `survey_nonprob` only | Current DAGJK engine from `create_group_jackknife_weights()` |

---

## Function Signature

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

---

## Argument Decisions

### `type`
- Default: `"jkn"`
- Values `"jkn"`, `"jk1"`, `"grouped"` — intentional rename from the current `"delete-1"` / `"random-groups"` strings (breaking change)
- No `"jk2"` — dropped (not cleanly supported by `survey::as.svrepdesign()`)
- No auto-detection of JK1 vs JKn — user specifies explicitly

### `replicates`
- Replaces `groups` from `create_group_jackknife_weights()`
- Only meaningful for `type = "grouped"`
- **`NULL` default for all input classes** — no internally-applied default; documentation advises Valliant (2020) recommendation of 50 for `survey_nonprob`
- **Required (error if `NULL`)** when `type = "grouped"` for both `survey_taylor` and `survey_nonprob`
- Silently ignored for `"jkn"` and `"jk1"` (deterministic, no replicates argument)

### `mse`
- Exposed for all types
- Passed through to backend for `"jkn"`, `"jk1"`, and `"grouped"` + `survey_taylor`
- **Warns and fixes to `TRUE`** for `"grouped"` + `survey_nonprob` (DAGJK formula requires centering on full-sample estimate; `mse = FALSE` is not justified by the literature)

### `var_strat`, `var_strat_frac`, `sort_var`, `adj_method`, `scale_method`
- All five are arguments to `svrep::as_random_group_jackknife_design()` and only apply to the `"grouped"` + `survey_taylor` path
- **Not exposed by previous versions** — new additions to the API
- Passed through to svrep for `"grouped"` + `survey_taylor`
- **Warn and ignore** when any is non-`NULL` (or non-default for `adj_method`/`scale_method`) with `survey_nonprob` input — message: these arguments do not affect non-probability samples
- Silently ignored for `"jkn"` and `"jk1"` (those types don't use svrep)
- `adj_method` and `scale_method` default to `"variance-stratum-psus"` (svrep default)
- `sort_var` not applicable to DAGJK because: (1) DAGJK uses its own `sample()` engine, not svrep; (2) groups span the combined NPS + reference sample making a single sort variable non-trivial; (3) sorted assignment is not described in the DAGJK literature

### Arguments NOT exposed (excluded from API)
- `fpc`, `fpctype` (`survey::as.svrepdesign()`) — FPC belongs at design creation time, already stored in `survey_taylor`; exposing would encourage misuse
- `compress` (both backends) — pure memory optimization, `TRUE` is universally correct, no impact on estimates
- `group_var_name` (`svrep::as_random_group_jackknife_design()`) — internal plumbing, names a column the user never interacts with

### `reference_sample`
- Only meaningful for `"grouped"` + `survey_nonprob` (DAGJK path)
- Document clearly that it is a `survey_nonprob`-only argument

### `seed`
- Only meaningful for `type = "grouped"` (random group assignment)
- Silently ignored for `"jkn"` and `"jk1"` (those types are deterministic)

---

## Input Class Restrictions

| Input class | Allowed types |
|-------------|---------------|
| `survey_taylor` | `"jkn"`, `"jk1"`, `"grouped"` |
| `survey_nonprob` | `"grouped"` only — `"jkn"` and `"jk1"` error |
| `data.frame` / `weighted_df` / `survey_replicate` | Error (existing `.validate_replicate_input()` behavior) |

---

## Deletions

### `create_group_jackknife_weights()`
- Removed entirely — no deprecation wrapper, no soft error
- File `R/create_group_jackknife_weights.R` deleted

### `"group-jackknife"` in `create_replicate_weights()`
- Removed from the dispatcher's `method` choices
- Follows the bootstrap precedent: `type = "quasi-randomization"` is not a separate method in the dispatcher, just a `type` argument passed through `...`
- New call pattern: `create_replicate_weights(method = "jackknife", type = "grouped")`

---

## History Entry

- `operation = "jackknife_weights"` for all types
- Type-specific detail stored in `parameters$type`
- Replaces the old `"group_jackknife_weights"` operation name from DAGJK

---

## Error Classes

- All `surveywts_error_dagjk_*` class names are renamed
- The `dagjk_` prefix is dropped in favor of something consistent with the merged function name (exact names to be decided during spec writing, then added to `plans/error-messages.md`)
- This is a breaking change for any code catching DAGJK errors by class name

---

## Test Files

| File | Action |
|------|--------|
| `tests/testthat/test-replicate-weights.R` | Update jackknife section to cover `"jkn"`, `"jk1"`, and `"grouped"` + `survey_taylor` |
| `tests/testthat/test-nps-group-jackknife.R` | Rename to `test-nps-jackknife.R`; update for `type = "grouped"` + `survey_nonprob` DAGJK path |
| `tests/testthat/test-replicate-dispatch.R` | Remove `"group-jackknife"` tests; add `type = "grouped"` pass-through test |

---

## Existing Code to Reuse

The DAGJK engine internals move wholesale into the merged function (or stay in `create_group_jackknife_weights.R` which gets renamed to a new file, TBD during spec):

- `.dagjk_single_replicate()` — IPW path engine
- `.dagjk_single_replicate_calib()` — calibration-only path engine
- `.validate_groups_arg()` — rename to reflect `replicates` parameter; two-phase validation logic preserved
- `.handle_repweights_overwrite()` — unchanged, stays in `replicate-utils.R`
- `.dispatch_calibration_replay()` — unchanged
- `.reestimate_margins_from_reference()` — unchanged
- `.convert_and_call()` — used for `"jkn"`, `"jk1"`, and `"grouped"` + `survey_taylor` paths

---

## Key Constraints Inherited from Existing Specs

- `reference_sample` argument takes precedence over any reference stored in the `ipw()` history entry (silent)
- Small groups warning threshold: avg group size < 5 units
- Failed replicates warning threshold: > 10% of total replicates fail
- `@variables$type` for DAGJK output: `"group-jackknife"` (unchanged from current)
- Scale factor for DAGJK: `(G_success - 1) / G_success`
- `mse` hardcoded to `TRUE` for DAGJK because the DAGJK variance formula `v_J = (G-1)/G * sum((θ_g − θ)²)` requires centering on the full-sample estimate
