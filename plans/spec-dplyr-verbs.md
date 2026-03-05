# Spec: `weighted_df` dplyr Verb Completeness

**Version:** 0.1
**Date:** 2026-03-04
**Status:** Draft
**Related files:** `plans/spec-phase-0.md`, `plans/error-messages.md`

---

## Document Purpose

This spec extends `spec-phase-0.md` with complete dplyr verb coverage for
`weighted_df`. The Phase 0 spec specified only `print.weighted_df()` and
`dplyr_reconstruct.weighted_df()`. Several verbs were added during Phase 0
implementation (`select`, `rename`, `mutate`) but without a full spec. This
document specifies:

1. Which verbs need explicit `weighted_df` methods vs. which are already
   covered by `dplyr_reconstruct.weighted_df()`
2. Rename-aware metadata propagation for `rename.weighted_df()` —
   updating `weight_col`, `parameters$variables`, and `call` in
   `weighting_history`
3. `group_by.weighted_df()` and `ungroup.weighted_df()` behavior

This spec does NOT repeat rules defined in `code-style.md`,
`r-package-conventions.md`, `surveywts-conventions.md`, or
`testing-standards.md`. Those rules apply by reference.

---

## I. Scope

### Verb Coverage Matrix

| Verb | Current status | Action required |
|------|----------------|-----------------|
| `print.weighted_df()` | ✅ Implemented | No change |
| `dplyr_reconstruct.weighted_df()` | ✅ Implemented | No change |
| `select.weighted_df()` | ✅ Implemented | No change |
| `mutate.weighted_df()` | ✅ Implemented | No change |
| `rename.weighted_df()` | ⚠️ Partial — does not detect rename | Replace with metadata-aware version |
| `filter.weighted_df()` | No explicit method needed | `dplyr_reconstruct` handles — verify empirically |
| `arrange.weighted_df()` | No explicit method needed | `dplyr_reconstruct` handles — verify empirically |
| `slice_head/tail/min/max/sample.weighted_df()` | No explicit method needed | `dplyr_reconstruct` handles — verify empirically |
| `distinct.weighted_df()` | No explicit method needed | `dplyr_reconstruct` handles — verify empirically |
| `group_by.weighted_df()` | ❌ Missing | New method |
| `ungroup.weighted_df()` | ❌ Missing | New method |

### Non-Scope

The following are explicitly out of scope for this spec:

- Domain-aware filtering (surveytidy pattern) — `weighted_df` is not a survey
  design; filtering physically removes rows
- `summarise.weighted_df()` — aggregation destroys `weighted_df` structure; let
  dplyr return a plain tibble with no `weighted_df` warning
- `*_join.weighted_df()` — joins are not supported in Phase 0

---

## II. Architecture

### File Changes

All changes go in `R/00-classes.R`. No new files are created.

Changes:
- Replace current `rename.weighted_df()` with metadata-aware version
- Add `group_by.weighted_df()`
- Add `ungroup.weighted_df()`
- Add three shared internal helpers (defined at top of file, before first call
  site; move to `R/07-utils.R` in Phase 1 if they acquire a second call site)

### New Internal Helpers

These are added to `R/00-classes.R` above the `rename.weighted_df()` definition.

#### `.build_rename_map(old_names, new_names)`

```r
# Returns a named character vector mapping old column names to new column names.
# Only includes names that actually changed. Names are old names; values are new.
.build_rename_map <- function(old_names, new_names) {
  changed <- old_names != new_names
  setNames(new_names[changed], old_names[changed])
}
```

#### `.apply_rename(vars, rename_map)`

```r
# Apply a rename map to a character vector of column names.
# Returns the vector with any old names replaced by their new counterparts.
.apply_rename <- function(vars, rename_map) {
  vapply(vars, function(v) {
    if (v %in% names(rename_map)) rename_map[[v]] else v
  }, character(1L), USE.NAMES = FALSE)
}
```

#### `.rename_history_entry(entry, rename_map)`

```r
# Apply a rename map to all relevant fields of one weighting_history entry.
# Updates parameters$variables and call (best-effort word-boundary substitution).
# Returns the modified entry.
.rename_history_entry <- function(entry, rename_map) {
  if (length(rename_map) == 0L) return(entry)

  # Update parameters$variables if present
  if (!is.null(entry$parameters$variables)) {
    entry$parameters$variables <- .apply_rename(
      entry$parameters$variables, rename_map
    )
  }

  # Update call string (best effort — word-boundary substitution)
  if (!is.null(entry$call)) {
    for (old_name in names(rename_map)) {
      entry$call <- gsub(
        paste0("\\b", old_name, "\\b"),
        rename_map[[old_name]],
        entry$call
      )
    }
  }

  entry
}
```

**Limitation (accepted):** The `call` field is a deparsed character string.
Word-boundary regex (`\b`) substitution is best-effort. Edge cases (column
names that appear only inside quoted strings, or as part of R object paths) may
not substitute correctly. This is acceptable — the call field is an audit aid,
not a re-executable expression.

---

## III. `rename.weighted_df()` — Metadata-Aware Rename

### Signature

```r
#' @importFrom dplyr rename
#' @export
rename.weighted_df <- function(.data, ...)
```

Argument follows `code-style.md`: `.data` first, `...` last (tidy-select
rename expressions: `new_name = old_name`).

### Output Contract

| Attribute / Property | Change |
|----------------------|--------|
| Column names in data | Renamed per `...` |
| `attr(result, "weight_col")` | Updated if the weight column was renamed; unchanged otherwise |
| `attr(result, "weighting_history")[*]$parameters$variables` | Any renamed column updated in all matching history entries |
| `attr(result, "weighting_history")[*]$call` | Word-boundary substitution applied for all renamed columns |
| class vector | `c("weighted_df", "tbl_df", "tbl", "data.frame")` — always preserved |

### Behavior Rules

1. Capture `old_names <- names(.data)`.
2. Call `result <- NextMethod()` to apply the rename to the underlying data.
3. Capture `new_names <- names(result)`.
4. Build `rename_map <- .build_rename_map(old_names, new_names)`.
5. **Update `weight_col`:** If `attr(.data, "weight_col") %in% names(rename_map)`,
   set `new_weight_col <- rename_map[[old_weight_col]]`. Otherwise keep the
   original.
6. **Update `weighting_history`:** Apply `.rename_history_entry(entry, rename_map)`
   to every entry in `attr(.data, "weighting_history")`.
7. Restore the `weighted_df` class and all updated attributes on `result`.

### Critical Behavioral Change vs. Current Implementation

The current `rename.weighted_df()` calls `.reconstruct_weighted_df()`, which
triggers `surveywts_warning_weight_col_dropped` when the weight column is
renamed (because the old `weight_col` name is no longer in `names(result)`).

**After this spec:** renaming the weight column silently updates `weight_col`
to the new name. `surveywts_warning_weight_col_dropped` is NOT issued for
rename operations — only for verbs that physically drop the weight column.

### Error / Warning Table

No new error or warning classes. `surveywts_warning_weight_col_dropped` is
NOT triggered by `rename.weighted_df()`.

---

## IV. `group_by.weighted_df()` and `ungroup.weighted_df()`

### Motivation

Without explicit methods, `group_by()` on a `weighted_df` produces a
`grouped_df` with class `c("grouped_df", "tbl_df", "tbl", "data.frame")`.
The `weighted_df` class is dropped. Although R may preserve the attributes,
`print.weighted_df()` no longer dispatches and the object is no longer
recognisable to downstream `weighted_df` methods.

### `group_by.weighted_df()`

**Signature:**

```r
#' @importFrom dplyr group_by
#' @export
group_by.weighted_df <- function(.data, ..., .add = FALSE,
                                  .drop = dplyr::group_by_drop_default(.data))
```

Argument order: `.data` (required), `...` (grouping columns, NSE), `.add`
(optional scalar), `.drop` (optional scalar).

**Output Contract:**

| Property | Value |
|----------|-------|
| Groups | Set per `...` |
| `attr(result, "weight_col")` | Preserved from `.data` |
| `attr(result, "weighting_history")` | Preserved from `.data` |
| class | `c("weighted_df", "grouped_df", "tbl_df", "tbl", "data.frame")` |

**Behavior Rules:**

1. Call `result <- NextMethod()`. Result has class
   `c("grouped_df", "tbl_df", "tbl", "data.frame")`.
2. Insert `"weighted_df"` at position 1 of the class vector.
3. Set `attr(result, "weight_col") <- attr(.data, "weight_col")`.
4. Set `attr(result, "weighting_history") <- attr(.data, "weighting_history")`.
5. Return the modified result.

**Print behavior:** `print.weighted_df()` calls `NextMethod()`, which reaches
`print.grouped_df()`. The weighted header is shown above the grouping line and
tibble body. This ordering is acceptable.

### `ungroup.weighted_df()`

**Signature:**

```r
#' @importFrom dplyr ungroup
#' @export
ungroup.weighted_df <- function(x, ...)
```

**Output Contract:**

| Property | Value |
|----------|-------|
| Groups | Cleared |
| `attr(result, "weight_col")` | Preserved from `x` |
| `attr(result, "weighting_history")` | Preserved from `x` |
| class | `c("weighted_df", "tbl_df", "tbl", "data.frame")` — `"grouped_df"` removed |

**Behavior Rules:**

1. Call `result <- NextMethod()` to remove grouping.
2. Restore class to `c("weighted_df", "tbl_df", "tbl", "data.frame")`.
3. Preserve `weight_col` and `weighting_history` attributes from `x`.
4. Return the modified result.

**Edge case:** `ungroup()` called on a non-grouped `weighted_df` — `NextMethod()`
is a no-op; the method still restores the class and attributes. No error or
warning is issued.

### Error / Warning Table

No new error or warning classes for `group_by` or `ungroup`.

---

## V. Verbs Covered by `dplyr_reconstruct.weighted_df()`

The following verbs require no explicit `weighted_df` method because dplyr
internally calls `dplyr_reconstruct()` after the operation.

| Verb | dplyr internal path | Notes |
|------|---------------------|-------|
| `filter()` | `dplyr_row_slice()` | Removes rows; preserves attributes |
| `arrange()` | `arrange.data.frame` end | Reorders rows; preserves attributes |
| `slice_head()` | row slice | Removes rows; preserves attributes |
| `slice_tail()` | row slice | Removes rows; preserves attributes |
| `slice_min()` | row slice | Removes rows; preserves attributes |
| `slice_max()` | row slice | Removes rows; preserves attributes |
| `slice_sample()` | row slice | Removes rows; preserves attributes |
| `distinct()` | row slice | Removes rows; preserves attributes |

**Verification required:** Before implementation closes, empirically confirm
each verb in this table triggers `dplyr_reconstruct.weighted_df()` with the
installed dplyr version. If any verb bypasses `dplyr_reconstruct`, add an
explicit method (not covered by this spec; requires a spec amendment).

The verification test pattern:

```r
# In test-00-classes.R
test_that("{verb}() preserves weighted_df class via dplyr_reconstruct", {
  d <- .make_weighted_df(
    make_surveywts_data(n = 50, seed = 1),
    weight_col = "base_weight",
    history = list(.make_test_history_entry())
  )
  result <- dplyr::{verb}(d, ...)
  test_invariants(result)
  expect_identical(attr(result, "weight_col"), "base_weight")
  expect_identical(
    attr(result, "weighting_history"),
    attr(d, "weighting_history")
  )
})
```

---

## VI. Testing

All tests go in `tests/testthat/test-00-classes.R`.

### `rename.weighted_df()` Tests

```
# 1. Happy path — rename a non-weight, non-history column
#    - Renamed column name is correct in names(result)
#    - attr(result, "weight_col") unchanged (old weight col not renamed)
#    - weighting_history unchanged
#    - No warning issued
#    - test_invariants(result) passes

# 2. Happy path — rename the weight column
#    - attr(result, "weight_col") updated to new name
#    - Column with new name is present in names(result)
#    - class(result)[1] == "weighted_df" (no downgrade)
#    - No surveywts_warning_weight_col_dropped issued
#    - test_invariants(result) passes

# 3. Happy path — rename a column that appears in parameters$variables
#    - weighting_history entry$parameters$variables updated to new name
#    - weight_col unchanged
#    - test_invariants(result) passes

# 4. Happy path — rename a column that appears in the call string
#    - weighting_history entry$call updated (word-boundary substitution)
#    - test_invariants(result) passes

# 5. Happy path — rename multiple columns in one call
#    - All renamed columns updated consistently across weight_col, parameters,
#      and call fields
#    - test_invariants(result) passes

# 6. Edge case — rename a column whose name is a substring of another column
#    (e.g., "sex" when "sex_category" also exists)
#    - Only the standalone "sex" column/reference is renamed; "sex_category"
#      is unchanged (word-boundary regex works correctly)
```

### `group_by.weighted_df()` Tests

```
# 1. Happy path — group_by one column
#    - class(result) == c("weighted_df", "grouped_df", "tbl_df", "tbl", "data.frame")
#    - dplyr::groups(result) shows the expected groups
#    - attr(result, "weight_col") identical to original
#    - attr(result, "weighting_history") identical to original
#    - test_invariants(result) passes

# 2. Happy path — group_by multiple columns
#    - dplyr::groups(result) shows all grouping columns
#    - class contains both "weighted_df" and "grouped_df"

# 3. Pipeline: group_by → filter → ungroup
#    - weighted_df class survives throughout
#    - After ungroup, "grouped_df" is absent from class vector

# 4. Pipeline: group_by → arrange
#    - weighted_df class survives
```

### `ungroup.weighted_df()` Tests

```
# 1. Happy path — ungroup a grouped weighted_df
#    - class(result) == c("weighted_df", "tbl_df", "tbl", "data.frame")
#    - "grouped_df" is absent
#    - dplyr::groups(result) is empty / NULL
#    - attr(result, "weight_col") and weighting_history preserved
#    - test_invariants(result) passes

# 2. Edge case — ungroup a non-grouped weighted_df
#    - No error or warning
#    - class(result) == c("weighted_df", "tbl_df", "tbl", "data.frame")
#    - Attributes preserved
```

### `dplyr_reconstruct`-covered verbs (empirical verification)

```
# For each verb in Section V:
# test_that("{verb}() preserves weighted_df class and attributes", {
#   - Apply verb to weighted_df with populated weighting_history
#   - test_invariants(result) passes
#   - attr(result, "weight_col") unchanged
#   - attr(result, "weighting_history") unchanged
# })
```

---

## VII. Quality Gates

Implementation is complete when all of the following pass:

- [ ] **`rename.weighted_df()`** — renaming the weight column updates
  `attr(x, "weight_col")` to the new name; `surveywts_warning_weight_col_dropped`
  is NOT issued
- [ ] **`rename.weighted_df()`** — renaming a calibration variable updates
  `parameters$variables` in all matching history entries
- [ ] **`rename.weighted_df()`** — renaming a variable updates `call` strings
  via word-boundary substitution
- [ ] **`group_by.weighted_df()`** — result class includes both `"weighted_df"`
  and `"grouped_df"` at positions 1 and 2
- [ ] **`ungroup.weighted_df()`** — result class is
  `c("weighted_df", "tbl_df", "tbl", "data.frame")` with no `"grouped_df"`
- [ ] **Empirical verification** — all verbs in Section V confirmed to preserve
  `weighted_df` class via `dplyr_reconstruct` with the installed dplyr version
- [ ] All tests passing: `devtools::test()`
- [ ] `R CMD check`: 0 errors, 0 warnings, ≤2 notes: `devtools::check()`
- [ ] `plans/error-messages.md` — no new error/warning classes introduced by
  this spec; confirm no update needed
