# Spec — nonprob-repweights

**Status**: DRAFT
**Target version**: 0.5.0.9000
**PR range**: PR 1–2

---

## Scope

### In

- `trim_weights()`: extend replicate-column trimming to cover `survey_nonprob`
  objects that carry optional replicate weight columns
  (`@variables$repweights` non-NULL).
- `stabilize_weights()`: extend replicate-column scaling (global and per-group)
  to cover the same case.
- `diagnostics-utils.R` internal helper `.diag_validate_input()`: remove the
  blocking guard that rejects `survey_replicate` objects. The Replicate release
  is complete; `survey_replicate` objects now have the same `@data` /
  `@variables$weights` extraction path as all other survey classes and must be
  accepted.
- Add the internal predicate `.has_repweights()` to `weight-utils.R`.
- Retire the error class `surveywts_error_replicate_not_supported` in
  `plans/error-messages.md` (mark as RETIRED; do not remove the row).

### Out

- No changes to `effective_sample_size()`, `weight_variability()`, or
  `summarize_weights()` public signatures or return contracts.
- No changes to the `survey_nonprob` class definition in surveycore.
- No changes to `@examples` blocks in `trim_weights.R` or `stabilize_weights.R`
  (existing examples use `data.frame` and `weighted_df` inputs, which remain
  unchanged).
- No replicate variance estimation or `survey_replicate` dispatch for diagnostic
  functions (this spec only removes the blocking guard; computation proceeds on
  the main weight column exactly as for `survey_nonprob` or `survey_taylor`).

---

## Architecture

### Files touched

| File | Action |
|------|--------|
| `R/weight-utils.R` | Add `.has_repweights()` internal predicate |
| `R/trim_weights.R` | Change Step 7 condition; extend output-construction branch |
| `R/stabilize_weights.R` | Change global and per-group replicate-scaling conditions; extend output-construction branch |
| `R/diagnostics-utils.R` | Remove `survey_replicate` rejection block from `.diag_validate_input()` |
| `plans/error-messages.md` | Mark `surveywts_error_replicate_not_supported` as RETIRED |
| `tests/testthat/test-weight-utils.R` | New tests (nonprob with repweights) |
| `tests/testthat/test-06-diagnostics.R` | New tests (survey_replicate input to diagnostic functions) |

### Functions added

- `.has_repweights(x)` — internal predicate, not exported, lives in
  `weight-utils.R`

### Functions modified (behavior change)

- `trim_weights()` — replicate-column path now also fires for `survey_nonprob`
  with `@variables$repweights` non-NULL
- `stabilize_weights()` — replicate-column path now also fires for
  `survey_nonprob` with `@variables$repweights` non-NULL
- `.diag_validate_input()` — `survey_replicate` is no longer rejected

### Class changes

None. The `survey_nonprob` class already supports `@variables$repweights`
(introduced in surveycore); this spec only teaches the three utility paths to
use it.

---

## Function contracts

### `.has_repweights(x)`

**Documentation tier**: internal helper — no `@export`, no `.Rd`

**Signature**:
```
.has_repweights(x)
```

**Arguments**:
| Argument | Type | Description |
|----------|------|-------------|
| `x` | any | Object to inspect |

**Returns**: `logical(1)`. `TRUE` when any of the following holds:
- `x` is a `survey_replicate` (inherits from `surveycore::survey_replicate`), OR
- `x` is a `survey_nonprob` (inherits from `surveycore::survey_nonprob`) AND
  `!is.null(x@variables$repweights)` AND
  `length(x@variables$repweights) >= 1L`

Returns `FALSE` for all other inputs, including `survey_nonprob` with `NULL`
`@variables$repweights`.

**Errors**: None. This is a pure Boolean predicate; it must not throw.

**Warnings**: None.

**Edge cases**:
- `survey_nonprob` with `repweights = NULL` → `FALSE`
- `survey_nonprob` with `repweights = character(0)` → `FALSE` (zero-length)
- `survey_nonprob` with `repweights = character(1)` → `TRUE`
- `survey_replicate` → always `TRUE` regardless of `@variables$repweights`
  contents (the class guarantees their presence)
- Any other class → `FALSE`

---

### `trim_weights()` — modified behavior

**Signature** (unchanged):
```
trim_weights(data, weights = NULL, lower = NULL, upper = NULL,
             k = 5, type = c("absolute", "percentile"),
             strict = FALSE, wt_name = "wts")
```

All argument semantics, error conditions, and warning conditions are unchanged.
Only the internal routing of Steps 7 and 9 (output construction) changes.

#### Behavior rules

1. Every pre-existing behavior rule for `data.frame`, `weighted_df`,
   `survey_taylor`, `survey_nonprob` (no repweights), and `survey_replicate`
   inputs is preserved exactly as documented in the prior spec.

2. When `.has_repweights(data)` is `TRUE`, Step 7 (replicate column trimming)
   is performed: the same `[lower_abs, upper_abs]` bounds that were applied to
   the main weights are applied independently to each replicate column with
   clip-and-redistribute. The strict loop is NOT applied to replicate columns
   regardless of the `strict` argument value.

3. The clip-and-redistribute logic for replicate columns is identical for
   `survey_replicate` and `survey_nonprob` inputs with repweights: for each
   replicate column `j`, values outside `[lower_abs, upper_abs]` are clipped,
   and the trimmed excess is redistributed equally among untrimmed rows in that
   column. If all rows in column `j` are outside bounds, no redistribution is
   possible and the column sum changes (no warning is emitted for individual
   replicate columns).

4. When `.has_repweights(data)` is `FALSE` and `data` is a `survey_nonprob`,
   the function falls through to the existing `else` branch (`.update_survey_weights()`
   only, no replicate column update). This path is unchanged.

5. **Output construction** — the output-class routing table is:

   | Input class | `.has_repweights()` | Output branch |
   |-------------|---------------------|---------------|
   | `data.frame` / `weighted_df` | N/A | `.make_weighted_df()` |
   | `survey_replicate` | TRUE (by definition) | `.update_survey_weights()` then update `@data[repweights]` |
   | `survey_nonprob` with repweights | TRUE | `.update_survey_weights()` then update `@data[repweights]` |
   | `survey_nonprob` without repweights | FALSE | `.update_survey_weights()` only |
   | `survey_taylor` | FALSE | `.update_survey_weights()` only |

6. The `rwnew` matrix computed in Step 7 is written back to
   `result_design@data[data@variables$repweights]` as a data frame (same
   mechanism as the existing `survey_replicate` path).

7. The returned object is the same class as the input (`survey_nonprob` in,
   `survey_nonprob` out; `survey_replicate` in, `survey_replicate` out).

8. The weighting history entry is appended regardless of input class. The
   history entry records the same `parameters` list as before (including
   `n_trimmed_lower` and `n_trimmed_upper` from the main weights only, not
   per-replicate counts).

#### `@param data` addition (documentation)

The `@param data` roxygen tag must be updated to note that `survey_nonprob`
objects carrying replicate weight columns have their replicate columns trimmed
by the same bounds. See the **Replicate Weights** section rule below.

#### `@description` update (documentation)

The existing `@description` sentence "Applies to main weights and — for
`survey_replicate` input — all replicate weight columns." must be updated to
include `survey_nonprob` with repweights. Replace with: "Applies to main
weights and — for inputs carrying replicate weight columns (`survey_replicate`
or `survey_nonprob` with `repweights`) — all replicate columns."

#### Replicate Weights section (documentation)

`trim_weights()` documentation must include a `@section Replicate Weights:`
block that states: when the input carries replicate weight columns (either
`survey_replicate` or `survey_nonprob` with repweights), the same absolute
bounds `[lower_abs, upper_abs]` are applied to each replicate column using the
same clip-and-redistribute logic. The `strict` loop is not applied to replicate
columns.

#### Errors table (unchanged)

| Class | Trigger condition |
|-------|-------------------|
| `surveywts_error_unsupported_class` | `data` is not a `data.frame` or `survey_base` subclass |
| `surveywts_error_empty_data` | `nrow(data) == 0` |
| `surveywts_error_weights_not_found` | Named weight column missing |
| `surveywts_error_weights_not_numeric` | Weight column is not numeric |
| `surveywts_error_weights_nonpositive` | Weight column has values ≤ 0 |
| `surveywts_error_weights_na` | Weight column has `NA` |
| `surveywts_error_wt_name_not_scalar` | `wt_name` is not `character(1)` |
| `surveywts_error_wt_name_empty` | `wt_name` is `NA` or `""` |
| `surveywts_error_null_bound_percentile` | `upper = NULL` with `type = "percentile"` |
| `surveywts_error_k_not_scalar` | `k` is not a single non-NA numeric |
| `surveywts_error_k_nonpositive` | `k <= 0` |
| `surveywts_error_lower_not_scalar` | `lower` is not a single non-NA numeric |
| `surveywts_error_upper_not_scalar` | `upper` is not a single non-NA numeric |
| `surveywts_error_upper_nonpositive` | `upper <= 0` when `type = "absolute"` |
| `surveywts_error_percentile_out_of_range` | `lower` or `upper` outside `[0, 1]` when `type = "percentile"` |
| `surveywts_error_bounds_invalid` | Resolved `lower_abs >= upper_abs` |

#### Warnings table (unchanged plus existing)

| Class | Trigger condition |
|-------|-------------------|
| `surveywts_warning_no_weights_trimmed` | All main weights already within `[lower_abs, upper_abs]` |
| `surveywts_warning_trimming_failed` | All units outside bounds in a column; redistribution impossible |

#### Edge cases

| Case | Expected behavior |
|------|-------------------|
| `survey_nonprob` with `repweights = NULL` | Treated as plain `survey_nonprob`; replicate step skipped |
| `survey_nonprob` with `repweights = character(0)` | Treated as plain `survey_nonprob`; replicate step skipped |
| `survey_nonprob` with all repweight values outside bounds | Each column clipped to bounds; redistribution impossible per column; column sums may change |
| `survey_nonprob` + `upper = Inf` (no-op trimming) | `surveywts_warning_no_weights_trimmed` fires; replicate columns unchanged (no-op) |
| Main weights within bounds but some replicate values outside | Main weights unchanged (warning fires for main), replicate columns still clipped |

---

### `stabilize_weights()` — modified behavior

**Signature** (unchanged):
```
stabilize_weights(data, weights = NULL, by = NULL, wt_name = "wts")
```

All argument semantics, error conditions, and warning conditions are unchanged.
Only the routing of the replicate-column scaling and output construction changes.

#### Behavior rules

1. Every pre-existing behavior rule for `data.frame`, `weighted_df`,
   `survey_taylor`, `survey_nonprob` (no repweights), and `survey_replicate`
   inputs is preserved exactly.

2. When `.has_repweights(data)` is `TRUE` and `by` is `NULL` (global
   stabilization): the global scale factor `n / sum(w)` is computed from the
   main weights and applied identically to every replicate column. Each
   replicate column `j` is multiplied element-wise by the scalar `scale_factor`.

3. When `.has_repweights(data)` is `TRUE` and `by` is non-NULL (per-group
   stabilization): the per-row scale factor vector `scale_factors_vec` is
   computed from the main weights and applied element-wise to every replicate
   column. Row `i` in every replicate column is multiplied by
   `scale_factors_vec[i]`.

4. When `.has_repweights(data)` is `FALSE` and `data` is a `survey_nonprob`,
   no replicate scaling is performed (falls through to `.update_survey_weights()`
   only). This is unchanged behavior.

5. **Output construction** routing table:

   | Input class | `.has_repweights()` | Output branch |
   |-------------|---------------------|---------------|
   | `data.frame` / `weighted_df` | N/A | `.make_weighted_df()` |
   | `survey_replicate` | TRUE | `.update_survey_weights()` then update `@data[repweights]` |
   | `survey_nonprob` with repweights | TRUE | `.update_survey_weights()` then update `@data[repweights]` |
   | `survey_nonprob` without repweights | FALSE | `.update_survey_weights()` only |
   | `survey_taylor` | FALSE | `.update_survey_weights()` only |

6. The `rep_weights_new` matrix (computed in Steps 4–5) is written back to
   `result_design@data[data@variables$repweights]` as a data frame.

7. The returned object is the same class as the input.

8. The history entry `parameters$scale_factor` records the main-weight scale
   factor only (scalar for global, named vector for per-group). Replicate
   column scale factors are not recorded separately.

#### `@param data` addition (documentation)

Same requirement as `trim_weights()`: note that `survey_nonprob` objects with
repweights have replicate columns scaled by the same factor.

#### `@description` update (documentation)

The existing `@description` sentence "Applies to main weights and — for
`survey_replicate` input — all replicate weight columns." must be updated to:
"Applies to main weights and — for inputs carrying replicate weight columns
(`survey_replicate` or `survey_nonprob` with `repweights`) — all replicate
columns."

#### Replicate Weights section (documentation)

`stabilize_weights()` documentation must include a `@section Replicate Weights:`
block stating: when the input carries replicate weight columns, all replicate
columns are scaled by the same factor(s) derived from the main weights —
globally `n / sum(w)` or per group `n_h / W_h`.

#### Errors table (unchanged)

| Class | Trigger condition |
|-------|-------------------|
| `surveywts_error_unsupported_class` | `data` is not a `data.frame` or `survey_base` subclass |
| `surveywts_error_empty_data` | `nrow(data) == 0` |
| `surveywts_error_weights_not_found` | Named weight column missing |
| `surveywts_error_weights_not_numeric` | Weight column is not numeric |
| `surveywts_error_weights_nonpositive` | Weight column has values ≤ 0 |
| `surveywts_error_weights_na` | Weight column has `NA` |
| `surveywts_error_wt_name_not_scalar` | `wt_name` is not `character(1)` |
| `surveywts_error_wt_name_empty` | `wt_name` is `NA` or `""` |
| `surveywts_error_by_variable_not_found` | `by` variable not in `data` |
| `surveywts_error_variable_has_na` | `by` variable has `NA` values |

#### Warnings table

None (no warning conditions added or changed).

#### Edge cases

| Case | Expected behavior |
|------|-------------------|
| `survey_nonprob` with `repweights = NULL` | Treated as plain `survey_nonprob`; replicate scaling skipped |
| `survey_nonprob` with `repweights = character(0)` | Treated as plain `survey_nonprob`; replicate scaling skipped |
| Global stabilization when main weights already sum to `n` | Scale factor is `1.0`; replicate columns are multiplied by `1.0` (no effective change) |
| Per-group stabilization; one group has a single observation | That group's scale factor is `1.0`; replicate column values for that row are unchanged |

---

### `.diag_validate_input()` — modified behavior

**Internal helper. No public signature change.**

#### Behavior rules

1. The block that checks `S7::S7_inherits(x, surveycore::survey_replicate)`
   and throws `surveywts_error_replicate_not_supported` is removed entirely.

2. After removal, `.diag_validate_input()` accepts these input classes:
   - `data.frame` (including `weighted_df` which inherits from it)
   - `survey_base` subclasses: `survey_taylor`, `survey_nonprob`,
     `survey_replicate`

3. For `survey_replicate` inputs, the weight extraction path
   (`data_df <- x@data`, `weight_col <- .get_weight_col_name(x, weights_quo)`)
   is the same path already used for `survey_taylor` and `survey_nonprob`. No
   special case is needed.

4. The `surveywts_error_weights_required` error (plain `data.frame` with
   `weights = NULL`) continues to fire as before. The `surveywts_error_unsupported_class`
   error for non-`data.frame` / non-`survey_base` inputs continues to fire as
   before.

5. The diagnostic functions (`effective_sample_size()`, `weight_variability()`,
   `summarize_weights()`) therefore accept `survey_replicate` inputs. They
   compute diagnostics on the main weight column only (`@variables$weights` in
   `@data`). Replicate variance of the diagnostics is not computed (this is
   out of scope for the Diagnostics release).

#### Retired error class

`surveywts_error_replicate_not_supported` is retired. In
`plans/error-messages.md`, mark the row with a strikethrough and the annotation
**RETIRED — Replicate release complete; `survey_replicate` now accepted by
diagnostic functions** (following the pattern of the existing retired row for
`surveywts_error_replicate_count_mismatch`).

#### Errors table after change

| Class | Trigger condition |
|-------|-------------------|
| `surveywts_error_weights_required` | Plain `data.frame` with `weights = NULL` |
| `surveywts_error_unsupported_class` | Input is not a `data.frame` or `survey_base` subclass |

---

## Quality gates

1. `trim_weights()` applied to a `survey_nonprob` with repweights returns a
   `survey_nonprob` (class preserved).
2. `trim_weights()` applied to a `survey_nonprob` with repweights updates all
   replicate columns in `@data`; the main weight column and replicate columns
   use the same `[lower_abs, upper_abs]` bounds.
3. `trim_weights()` applied to a `survey_nonprob` without repweights does not
   touch any replicate-related code path (equivalent to the pre-change behavior).
4. `stabilize_weights()` applied to a `survey_nonprob` with repweights returns
   a `survey_nonprob`; replicate columns are scaled by the same factor as the
   main weights.
5. `stabilize_weights()` applied to a `survey_nonprob` without repweights
   is unchanged.
6. `effective_sample_size()`, `weight_variability()`, and `summarize_weights()`
   accept `survey_replicate` inputs without error.
7. `.has_repweights(x)` returns `FALSE` for all inputs that do not carry
   accessible replicate weight columns.
8. `surveywts_error_replicate_not_supported` is never thrown after this change
   (the class is retired in `plans/error-messages.md`).
9. All pre-existing tests for `trim_weights()`, `stabilize_weights()`, and the
   diagnostic functions continue to pass unchanged.

---

## Pipeline split

recommended — two new test-observable behaviors (nonprob-repweights routing in
weight utilities, replicate accepted by diagnostics) and a new internal helper;
both warrant a separate PR each.
