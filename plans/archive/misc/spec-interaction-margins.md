# Interaction Margins Spec: Joint Cell Calibration Targets

**Version:** 0.1 (draft)
**Date:** 2026-05-07
**Status:** Draft — Stage 1 complete; pending Stage 2 methodology review
**Branch identifier:** `interaction-margins`
**Related files:** (reviews and decisions to be created in subsequent stages)

---

## Document Purpose

This document is the single source of truth for adding joint cell calibration
targets to `rake()` and `calibrate()`. The motivation is that online opt-in
panels oversample college-educated respondents non-uniformly across racial
groups; marginal raking on education and race/ethnicity independently cannot
correct this. Including education × race/ethnicity as an explicit calibration
target — an additional IPF margin or GREG moment condition — directly
constrains the joint cell distribution while remaining consistent with the
iterative framework that gracefully handles slight inconsistencies between
independently-sourced population benchmarks.

This spec does NOT repeat rules defined in:
- `code-style.md` — formatting, pipe, error structure, S7 patterns, argument order
- `r-package-conventions.md` — `::` usage, NAMESPACE, roxygen2, export policy
- `surveywts-conventions.md` — error/warning prefixes, return visibility
- `testing-standards.md` — `test_that()` scope, coverage targets, assertion patterns
- `testing-surveywts.md` — `test_invariants()`, error testing layers, tolerances

Those rules apply by reference.

---

## I. Scope

### Deliverables

| # | Change | File | Notes |
|---|--------|------|-------|
| 1 | Add `interaction_margins` argument to `rake()` | `R/rake.R` | Supports both `"anesrake"` and `"survey"` methods |
| 2 | Add `interaction_terms` argument to `calibrate()` | `R/calibrate.R` | GREG moment condition expansion |
| 3 | `.parse_interaction_spec()` internal helper | `R/rake.R` | Converts interaction entry to canonical form; co-located in `rake.R` because `rake()` is the primary call site |
| 4 | `.validate_interaction_spec()` internal helper | `R/utils.R` | Validates an interaction spec entry against data; used by both `rake()` and `calibrate()` |
| 5 | Engine extension: `interaction_variables` in `calibration_spec` | `R/utils.R` | Used by IPF (`survey::rake()`) and GREG (`survey::calibrate()`) paths |
| 6 | Roxygen documentation updates | `R/rake.R`, `R/calibrate.R` | Updated `@param` and `@examples` |
| 7 | New error/warning classes | `plans/error-messages.md` | See error table in §III and §IV |

### Non-Deliverables

| Item | Reason |
|------|--------|
| Three-way or higher-order interactions | Deferred; current use case is 2-variable interactions only. The architecture supports N-way via the same API but testing and validation are scoped to 2-variable. |
| `poststratify()` changes | Already handles joint cells exactly. The distinction between soft raking and exact post-stratification is preserved. |
| Format B extension for `margins` (multi-variable rows in a single long data frame) | The separate `interaction_margins` / `interaction_terms` argument is cleaner and is the only supported format. |
| `interaction_margins` with `method = "anesrake"` using a full pre-defined composite sweep order | Anesrake's chi-square variable selection determines sweep order dynamically; the interaction composite is treated as one more variable and is selected/skipped per the same chi-square logic. |
| Per-interaction convergence tolerance | All margins (main and interaction) share the same `control$epsilon` / `control$improvement`. |

### Class and Method Support Matrix

| Input class | `rake()` + `interaction_margins` | `calibrate()` + `interaction_terms` |
|-------------|----------------------------------|--------------------------------------|
| `data.frame` | ✅ | ✅ |
| `weighted_df` | ✅ | ✅ |
| `survey_taylor` | ✅ | ✅ |
| `survey_nonprob` | ✅ | ✅ |
| `survey_replicate` | ❌ (existing error, unchanged) | ❌ (existing error, unchanged) |

| Method | `interaction_margins` |
|--------|-----------------------|
| `"anesrake"` | ✅ (composite variable pre-processing; see §III.B) |
| `"survey"` | ✅ (native `survey::rake()` formula interaction terms; see §III.C) |

---

## II. Architecture

### Files Modified

```
R/
  rake.R           — add interaction_margins argument + .parse_interaction_spec()
  calibrate.R      — add interaction_terms argument
  utils.R          — add .validate_interaction_spec(); extend .calibrate_engine()
                     calibration_spec to include interaction_variables
plans/
  error-messages.md  — add new error and warning classes
```

No new files created.

### New Internal Helpers

#### `.parse_interaction_spec(entry)` — co-located in `R/rake.R`

Converts one entry from `interaction_margins` or `interaction_terms` to
canonical form. Called once per entry during margin parsing.

```r
.parse_interaction_spec(entry)
# Arguments:
#   entry: one list element from interaction_margins or interaction_terms
#          Either:
#            list(variables = c("a", "b"), targets = c("x:y" = 0.1, ...))
#            list(variables = c("a", "b"), targets = data.frame(a=..., b=..., target=...))
# Returns: list(
#   variables = character vector of variable names,
#   targets   = named numeric vector with "level1:level2" keys
# )
# Errors:
#   surveywts_error_interaction_spec_invalid  if entry is malformed
```

Single call site is in `rake.R` but this helper is also used by `calibrate.R`.
Per `code-style.md §4`, helpers used in 2+ files live in `utils.R`. Move to
`utils.R` when `calibrate.R` starts calling it (at the same time this spec is
implemented, since both are implemented together).

> ⚠️ **Decision needed before implementation:** `.parse_interaction_spec()` is
> defined here as co-located in `rake.R` during Stage 1 drafting, but because
> `calibrate()` uses it too, it should live in `utils.R` per
> `code-style.md §4`. Place in `utils.R` from the start.

Revised placement: **`R/utils.R`**.

#### `.validate_interaction_spec(entry, plain_df, type)` — in `R/utils.R`

Validates one parsed interaction spec entry against the data. Called after
`.parse_interaction_spec()`.

```r
.validate_interaction_spec(entry, plain_df, type)
# Arguments:
#   entry    : canonical entry (output of .parse_interaction_spec())
#   plain_df : plain data.frame (all rows, all columns)
#   type     : "prop" or "count"
# Returns: invisible(TRUE)
# Errors: see §III.D error table
```

---

## III. `rake()` with `interaction_margins`

### III.A Signature

```r
rake(
  data,
  margins,
  interaction_margins = NULL,
  weights  = NULL,
  wt_name  = "wts",
  type     = c("prop", "count"),
  method   = c("anesrake", "survey"),
  cap      = NULL,
  control  = list()
)
```

The `interaction_margins` argument is added between `margins` and `weights`.
This is a required-before-optional ordering: `margins` is required, `weights`
is optional, and `interaction_margins` is optional — it sits between them
because it is thematically linked to `margins`. See `code-style.md §4`
argument order rules.

### III.B Argument Table

| Argument | Type | Default | Description |
|----------|------|---------|-------------|
| `data` | `data.frame`, `weighted_df`, `survey_taylor`, `survey_nonprob` | — | Input data or survey object |
| `margins` | named list or `data.frame` | — | Per-variable marginal targets. Unchanged from current API. |
| `interaction_margins` | list or `NULL` | `NULL` | Joint cell targets for 2-variable (or higher) interactions. Each element is a named list with `variables` (character vector, length ≥ 2) and `targets` (named numeric vector or data frame). See §III.C for format details. |
| `weights` | tidy-select | `NULL` | Weight column. Unchanged. |
| `wt_name` | `character(1)` | `"wts"` | Output weight column name. Unchanged. |
| `type` | `"prop"` or `"count"` | `"prop"` | Applies to both `margins` and `interaction_margins`. |
| `method` | `"anesrake"` or `"survey"` | `"anesrake"` | Algorithm. Unchanged. |
| `cap` | numeric or `NULL` | `NULL` | Weight cap. Unchanged. |
| `control` | named list | `list()` | Algorithm parameters. Unchanged. |

### III.C `interaction_margins` Format

Each element of `interaction_margins` is a named list with exactly two keys:

**`variables`** — `character` vector of length ≥ 2. Names of the columns in
`data` that form the interaction. Order determines the `:` separator key order
in `targets`.

**`targets`** — either:
- A named numeric vector where each name is `"level_v1:level_v2"` (using `:`
  as separator). For a 2×4 interaction, 8 entries. For a 4×5 interaction, 20
  entries. If `type = "prop"`, values must sum to 1.0 within tolerance `1e-6`.
  If `type = "count"`, values must be strictly positive.
- A `data.frame` with one column per variable (column names must match
  `variables`) plus a `target` column. `.parse_interaction_spec()` converts
  this to the named vector form.

```r
# Named vector form (primary)
interaction_margins <- list(
  list(
    variables = c("education", "race_eth"),
    targets   = c(
      "lt_hs:white_nh"  = 0.063,
      "lt_hs:black_nh"  = 0.011,
      "lt_hs:hispanic"  = 0.013,
      "lt_hs:asian_nh"  = 0.006,
      "lt_hs:other_nh"  = 0.007,
      "hs:white_nh"     = 0.178,
      # ... all 20 cells, summing to 1.0
      "ba_plus:other_nh" = 0.008
    )
  )
)

# Data frame form (equivalent)
interaction_margins <- list(
  list(
    variables = c("education", "race_eth"),
    targets   = data.frame(
      education = c("lt_hs", "lt_hs", ...),
      race_eth  = c("white_nh", "black_nh", ...),
      target    = c(0.063, 0.011, ...)
    )
  )
)
```

The element can optionally have a name (e.g., `education_x_race_eth = list(...)`);
the name is cosmetic and used only in the history entry. If unnamed, the
history entry uses `paste(variables, collapse = ":").`

### III.D Method Dispatch with `interaction_margins`

#### `method = "anesrake"` — composite variable pre-processing

`anesrake::anesrake()` accepts only single-variable margin targets. To include
an interaction margin, `rake()` must pre-process:

1. Compute a composite column: `paste(data[[v1]], data[[v2]], sep = ":")` where
   `v1 = variables[[1]]`, `v2 = variables[[2]]`. For a 3+ variable interaction,
   extend: `paste(data[[v1]], data[[v2]], data[[v3]], sep = ":")`.
2. Name the composite column: `paste0(".interaction_", paste(variables, collapse = "_x_"))`.
   Example: `".interaction_education_x_race_eth"`. The `.` prefix signals
   internal use. The column is added to the local `data_df` copy only; it is
   never written to the output.
3. Add the composite column's target distribution to `vars_spec` as a regular
   variable entry. The named vector keys must match the composite column values
   exactly (same `:` separator).
4. The interaction column participates in anesrake's chi-square variable
   selection on equal footing with main-effect variables. If it passes the
   `control$pval` threshold, it is swept; otherwise it is skipped (correct
   behavior — the chi-square selection applies uniformly).

The composite column is **not** subject to step 6 (`validate_calibration_variables`)
because it is synthetic — it is added after validation of the user-specified
`margins` variables. The composite column must be checked separately: it cannot
contain `NA` (guaranteed if neither component variable contains `NA`, which has
already been validated). A defensive `NA` check on the composite column is
added after construction.

#### `method = "survey"` — native IPF interaction terms

`survey::rake()` supports interaction terms natively via formula notation.
When `interaction_margins` is non-NULL:

1. For each interaction entry with `variables = c(v1, v2)`, add the formula
   `stats::as.formula(paste("~", paste(variables, collapse = ":")))` to
   `sample.margins`. Example: `~education:race_eth`.
2. Build the population data frame: a `data.frame` with one column per variable
   (columns named as in `variables`) plus a `Freq` column. Columns are of
   character type. Convert `targets` named vector to this data frame by
   splitting keys on `:` and expanding.
3. Append the interaction formula to the existing `sample.margins` list (after
   all main-effect margins) and the interaction population data frame to
   `population.margins`.

The engine receives both main-effect and interaction margin specs via the
extended `calibration_spec` format described in §III.F.

#### `cap` + `interaction_margins`

No change to the existing restriction: `cap` with `method = "survey"` still
errors (`surveywts_error_cap_not_supported_survey`). When `method = "anesrake"`
and `cap` is non-NULL, the cap applies to all margin sweeps including the
interaction composite margin (correct behavior — the composite is one more
variable in the anesrake sweep).

### III.E Validation Rules for `interaction_margins`

Validation runs after `margins` validation and before engine dispatch:

1. **Type check:** each element of `interaction_margins` must be a list. Error:
   `surveywts_error_interaction_spec_invalid`.
2. **`variables` presence and type:** `variables` must be a character vector of
   length ≥ 2. Error: `surveywts_error_interaction_variables_invalid`.
3. **Variables in data:** each name in `variables` must be a column in `data`.
   Error: `surveywts_error_interaction_variable_not_found` (report first missing).
4. **Variables already in `margins`:** each variable named in `variables` should
   already appear in `margins`. If a variable in `interaction_margins` is NOT
   in `margins`, emit `surveywts_warning_interaction_variable_not_in_margins`.
   Rationale: raking on a joint distribution without also raking on the
   corresponding marginals is statistically unusual (the marginal is implicitly
   constrained by the joint, but not explicitly); warn but do not error.
5. **`targets` format:** must be a named numeric vector or a `data.frame` with
   the correct columns. Error: `surveywts_error_interaction_targets_invalid`.
6. **Level completeness:** every combination of levels present in `data` for
   the interaction variables must appear in `targets`. Error:
   `surveywts_error_interaction_cell_missing`.
7. **No extra levels:** every key in `targets` must correspond to a combination
   present in `data`. Error: `surveywts_error_interaction_cell_not_in_data`.
8. **Sum to 1 (prop) / positive (count):** same rules as for `margins`. Error:
   `surveywts_error_population_totals_invalid` (reuse existing class).
9. **Marginal consistency check:** for each variable in `variables`, the
   row/column marginal sums of `targets` must match the corresponding
   `margins` entry to within `1e-4`. If they differ by more than this
   tolerance, emit `surveywts_warning_interaction_marginal_inconsistency`.
   This warn-not-error design preserves the IPF's graceful handling of
   benchmark inconsistencies (which arise routinely when margins come from
   different ACS tables).

### III.F Engine Extension: `calibration_spec` with `interaction_variables`

The `calibration_spec` format is extended with an optional `interaction_variables`
key for the `"ipf"` method:

```r
calibration_spec <- list(
  type      = "ipf",
  variables = list(                          # main-effect margins (unchanged)
    list(col = "education", targets = c(...)),
    list(col = "race_eth",  targets = c(...))
  ),
  interaction_variables = list(              # interaction margins (new, optional)
    list(
      cols    = c("education", "race_eth"),  # variable names forming the interaction
      targets = c("lt_hs:white_nh" = 420, ...) # in counts (prop→count conversion done by caller)
    )
  ),
  total_n   = nrow(plain_df),
  cap       = cap
)
```

The engine, when `type == "ipf"` and `interaction_variables` is non-NULL:

1. For each interaction entry, build the formula term: `stats::as.formula(paste("~", paste(cols, collapse = ":")))`
2. Build the population data frame by splitting the names of `targets` on ":"
   into one column per variable, plus a `Freq` column.
3. Append to the `sample.margins` and `population.margins` lists.

The `anesrake` path never receives `interaction_variables` in `calibration_spec`
— the pre-processing in `rake()` folds the interaction into `vars_spec` as a
composite variable before engine dispatch.

For the `"linear"` and `"logit"` GREG paths (`calibrate()`), the engine is
extended analogously (see §IV.F).

### III.G History Entry

The history entry for a `rake()` call with `interaction_margins` stores:

```r
list(
  operation  = "raking",
  parameters = list(
    variables            = margin_var_names,       # main-effect variable names
    margins              = margins_a,              # Format A named list
    interaction_margins  = parsed_interactions,    # list of canonical interaction entries
    method               = method,
    cap                  = cap,
    control              = control_resolved
  ),
  ...
)
```

`.format_history_step()` for the `"raking"` case is extended to include
interaction variable names when present:

```
Step 2 [2026-05-07]: raking (margins: education, race_eth; interactions: education:race_eth)
```

### III.H Error Table

New error and warning classes for `rake()`:

| Class | Thrown by | Condition |
|-------|-----------|-----------|
| `surveywts_error_interaction_spec_invalid` | `rake()`, `calibrate()` | `interaction_margins` / `interaction_terms` element is not a list, or is missing `variables` or `targets` keys |
| `surveywts_error_interaction_variables_invalid` | `.validate_interaction_spec()` | `variables` is not a character vector, has length < 2, has duplicate names, or has `NA` values |
| `surveywts_error_interaction_variable_not_found` | `.validate_interaction_spec()` | A name in `variables` is not a column in `data` (reports first missing) |
| `surveywts_error_interaction_targets_invalid` | `.validate_interaction_spec()` | `targets` is not a named numeric vector or valid data frame |
| `surveywts_error_interaction_cell_missing` | `.validate_interaction_spec()` | A combination of levels present in `data` is absent from `targets` |
| `surveywts_error_interaction_cell_not_in_data` | `.validate_interaction_spec()` | A key in `targets` does not correspond to any row in `data` |

| Class | Thrown by | Condition |
|-------|-----------|-----------|
| `surveywts_warning_interaction_variable_not_in_margins` | `rake()` | A variable in `interaction_margins` is not in `margins`; raking on joint without corresponding marginal |
| `surveywts_warning_interaction_marginal_inconsistency` | `rake()`, `calibrate()` | Row/column marginal sums of an interaction target differ from corresponding `margins` / `population` entry by more than `1e-4` |

---

## IV. `calibrate()` with `interaction_terms`

### IV.A Signature

```r
calibrate(
  data,
  variables,
  population,
  interaction_terms = NULL,
  weights  = NULL,
  wt_name  = "wts",
  method   = c("linear", "logit"),
  type     = c("prop", "count"),
  control  = list(maxit = 50, epsilon = 1e-7)
)
```

`interaction_terms` is placed between `population` and `weights`. All three of
`variables`, `population`, and `interaction_terms` describe the calibration
targets; grouping them before the optional `weights` argument follows the
argument order rule.

### IV.B Argument Table

| Argument | Type | Default | Description |
|----------|------|---------|-------------|
| `data` | `data.frame`, `weighted_df`, `survey_taylor`, `survey_nonprob` | — | Unchanged |
| `variables` | tidy-select | — | Main-effect calibration variables. Unchanged. |
| `population` | named list | — | Per-variable population targets. Unchanged. |
| `interaction_terms` | list or `NULL` | `NULL` | Joint cell targets for interaction constraints. Each element is a named list with `variables` (character vector, length ≥ 2) and `targets` (named numeric vector or data frame). Same format as `rake()`'s `interaction_margins`. |
| `weights` | tidy-select | `NULL` | Unchanged |
| `wt_name` | `character(1)` | `"wts"` | Unchanged |
| `method` | `"linear"` or `"logit"` | `"linear"` | Unchanged |
| `type` | `"prop"` or `"count"` | `"prop"` | Applies to both `population` and `interaction_terms`. |
| `control` | named list | `list(maxit = 50, epsilon = 1e-7)` | Unchanged |

### IV.C Behavior with `interaction_terms`

GREG calibration constrains the weighted sample mean of each covariate to equal
the population mean. Adding an interaction term as a calibration constraint
means adding indicator variables for each joint cell of the interaction to the
GREG model matrix. For a 4×5 interaction (education × race/ethnicity), 20
(or 19, dropping one for identifiability) indicator columns are added to the
model matrix, and 20 (or 19) corresponding population totals are added to the
`pop_totals` vector passed to `survey::calibrate()`.

**Identifiability:** The interaction indicators are included alongside the
main-effect indicator columns already in the model matrix. With default
treatment contrasts (reference level for each variable), the main effects
account for `(k1 - 1) + (k2 - 1)` degrees of freedom and the interaction
accounts for `(k1 - 1) × (k2 - 1)`. The intercept absorbs the reference cell.
Total d.f. = `1 + (k1-1) + (k2-1) + (k1-1)(k2-1) = k1 × k2`. This is the
full cell parameterization, which is identified.

**Implementation:** The interaction formula term is added to the calibration
formula: `~var1 + var2 + var1:var2`. `stats::model.matrix()` with treatment
contrasts generates the correct interaction indicators. The corresponding
population total for each interaction indicator is the joint cell count (in
counts; proportions converted by the caller). These are appended to the
`pop_totals` named vector using the `model.matrix()` column names as keys
(e.g., `"factor(education)hs:factor(race_eth)hispanic"`).

**Engine path:** the engine receives `interaction_variables` in
`calibration_spec` alongside `variables`. When `type %in% c("linear", "logit")`
and `interaction_variables` is non-NULL:

1. Add the interaction term to the formula: extend from `~v1 + v2` to
   `~v1 + v2 + v1:v2`. Use `update()` or string construction.
2. After `stats::model.matrix()`, identify the interaction indicator columns
   (names of the form `"var1levelA:var2levelB"`).
3. For each interaction indicator column, look up the corresponding population
   total from the parsed `interaction_terms` targets and insert into
   `pop_totals`.
4. Proceed with `survey::calibrate()` as before — the interaction columns
   are just more rows in the moment conditions.

### IV.D Validation

Same validation rules as §III.E apply to `interaction_terms`. The marginal
consistency check (rule 9) compares interaction marginal sums against
`population` (not `margins`, since `calibrate()` uses `population`).

Additionally: variables in `interaction_terms` must also appear in `variables`
(the tidy-select argument). If a variable in `interaction_terms` is NOT in
`variables`, emit `surveywts_warning_interaction_variable_not_in_margins`
(same class as `rake()`; the condition is identical).

### IV.E History Entry

```r
list(
  operation  = "calibration",
  parameters = list(
    variables         = variable_names,
    population        = population,
    interaction_terms = parsed_interactions,
    method            = method,
    type              = type,
    control           = control
  ),
  ...
)
```

`.format_history_step()` for `"calibration"` is extended analogously to
`"raking"` — include interaction variable names when present.

---

## V. Shared Helper Specifications

### `.parse_interaction_spec(entry)`

**Input:** one element from `interaction_margins` or `interaction_terms`.

**Output contract:**
```r
list(
  variables = character vector,          # length >= 2, no NAs, no duplicates
  targets   = named numeric vector,      # "level1:level2" = value
  name      = character(1)               # cosmetic name; "" if entry unnamed
)
```

**Behavior:**
- If `targets` is a `data.frame`: validate columns match `variables` + `target`,
  then construct `paste(row[[v1]], row[[v2]], sep = ":")` names and `target`
  values. All column values coerced to `character` for key construction.
- If `targets` is a named numeric vector: return as-is (after checking names
  are non-empty and values are numeric).
- Error `surveywts_error_interaction_spec_invalid` if `entry` is not a list or
  is missing `variables` / `targets`.
- Error `surveywts_error_interaction_variables_invalid` if `variables` fails
  its checks (not character, length < 2, duplicates, NAs).
- Error `surveywts_error_interaction_targets_invalid` if `targets` is neither
  a named numeric vector nor a valid data frame.

### `.validate_interaction_spec(entry, plain_df, type)`

Assumes `entry` is already in canonical form (output of `.parse_interaction_spec()`).

**Behavior:**
1. Check each name in `entry$variables` exists in `plain_df`. Error:
   `surveywts_error_interaction_variable_not_found`.
2. Compute observed combination keys: `paste(plain_df[[v1]], plain_df[[v2]], sep = ":")`.
3. Check every observed key is in `names(entry$targets)`. Error:
   `surveywts_error_interaction_cell_missing` (report first missing key).
4. Check every key in `names(entry$targets)` appears in observed keys. Error:
   `surveywts_error_interaction_cell_not_in_data` (report first extra key).
5. If `type == "prop"`: check `sum(entry$targets)` is within `1e-6` of 1. Error:
   `surveywts_error_population_totals_invalid`.
6. If `type == "count"`: check all values > 0. Error:
   `surveywts_error_population_totals_invalid`.

Returns `invisible(TRUE)`.

---

## VI. Testing

### Test File Mapping

New tests are added to existing test files — no new test files created.

| Test | File |
|------|------|
| `rake()` with `interaction_margins` | `tests/testthat/test-03-rake.R` |
| `calibrate()` with `interaction_terms` | `tests/testthat/test-02-calibrate.R` |
| `.parse_interaction_spec()` | `tests/testthat/test-03-rake.R` (indirect; direct if coverage gap) |
| `.validate_interaction_spec()` | `tests/testthat/test-02-calibrate.R` and `test-03-rake.R` |

### Required Test Categories

#### `rake()` with `interaction_margins`

**Happy path:**

1. `rake()` with `method = "survey"` + 2×5 interaction: result is a `weighted_df`;
   `test_invariants()` passes; weighted joint distribution matches target to within
   `1e-4` (soft constraint — not exact); weighted marginals match `margins` to
   within `1e-4`.
2. `rake()` with `method = "survey"` + 4×5 interaction: 20-cell target; same
   assertions.
3. `rake()` with `method = "anesrake"` + 2-variable interaction: composite column
   created; result passes `test_invariants()`; weighted joint distribution matches
   target. The output `data` does NOT contain the composite column.
4. `rake()` with interaction + `survey_taylor` input: class preserved.
5. `rake()` with interaction + `survey_nonprob` input: class preserved.
6. `rake()` with `targets` as data frame form: same results as named vector form.
7. `rake()` with `interaction_margins = NULL` (default): behavior unchanged from
   current implementation (no regression).

**Numerical cross-check (conditional):**

```r
test_that("rake() interaction matches survey::rake() directly", {
  skip_if_not_installed("survey")
  # run surveywts::rake() with interaction_margins
  # run survey::rake() with equivalent ~edu:race margin directly
  # compare weights within 1e-8
})
```

**Validation error paths (dual pattern: class= + snapshot):**

8. `interaction_margins` element is not a list → `surveywts_error_interaction_spec_invalid`
9. `variables` length < 2 → `surveywts_error_interaction_variables_invalid`
10. `variables` names not in data → `surveywts_error_interaction_variable_not_found`
11. `targets` is not a named vector or data frame → `surveywts_error_interaction_targets_invalid`
12. Missing cell in `targets` (a data combination not covered) → `surveywts_error_interaction_cell_missing`
13. Extra cell in `targets` (a key not in data) → `surveywts_error_interaction_cell_not_in_data`
14. `type = "prop"` targets don't sum to 1 → `surveywts_error_population_totals_invalid`

**Warning paths:**

15. Variable in `interaction_margins` not in `margins` → `surveywts_warning_interaction_variable_not_in_margins`
16. Marginal sums of interaction targets differ from `margins` by > `1e-4` →
    `surveywts_warning_interaction_marginal_inconsistency`

#### `calibrate()` with `interaction_terms`

**Happy path:**

17. `calibrate()` with `method = "linear"` + 2×3 interaction: result is `weighted_df`;
    `test_invariants()` passes; weighted joint distribution matches target to within
    `1e-6` (GREG is a closer approximation than IPF; test at `1e-6` per numerical
    tolerances in `testing-surveywts.md`).
18. `calibrate()` with `method = "logit"` + interaction: weights are all positive.
19. `calibrate()` with interaction + `survey_taylor` input: class preserved.
20. `calibrate()` with `interaction_terms = NULL` (default): behavior unchanged.

**Numerical cross-check (conditional):**

```r
test_that("calibrate() interaction matches survey::calibrate() directly", {
  skip_if_not_installed("survey")
  # run surveywts::calibrate() with interaction_terms
  # run survey::calibrate() with formula ~edu + race + edu:race directly
  # compare weights within 1e-8
})
```

**Validation error paths (dual pattern):**

21. Same error classes as rake() (items 8–14 above), triggered via `calibrate()`

#### Edge Cases

22. Interaction between a 2-level variable and a 5-level variable (10 cells): verify
    all validation passes and weights converge.
23. `rake()` with two separate interaction entries (e.g., `education:race` and
    `age:sex`): both processed; weights satisfy both joint constraints.
24. Interaction targets where all cells in one row are zero (a variable level absent
    from data): triggers `surveywts_error_interaction_cell_not_in_data`.
25. `type = "count"` with interaction targets: conversion to proportions happens
    correctly.
26. Marginal consistency warning fires when using ACS tables with slight demographic
    inconsistencies (simulate with targets that differ by 0.003 from marginal sums).
27. `method = "anesrake"` + interaction: composite column is NOT present in output
    `weighted_df`.
28. History entry for `rake()` with interaction includes `interaction_margins` in
    `parameters` and the display string shows both margins and interaction names.

---

## VII. Quality Gates

All of the following must be true before this spec is considered complete for
implementation:

- [ ] `rake()` accepts `interaction_margins`; `NULL` default preserves current behavior exactly
- [ ] `calibrate()` accepts `interaction_terms`; `NULL` default preserves current behavior exactly
- [ ] `.parse_interaction_spec()` in `utils.R` (not `rake.R`)
- [ ] `.validate_interaction_spec()` in `utils.R`
- [ ] `method = "anesrake"` composite column added to local `data_df` only; not in output
- [ ] `method = "survey"` builds correct `~v1:v2` formula term and multi-column population data frame
- [ ] GREG interaction: interaction indicators in model matrix; correct `pop_totals` entries
- [ ] Marginal consistency check warns (does not error) when inconsistency > `1e-4`
- [ ] Warning fires when interaction variable not in `margins` / `population`
- [ ] `plans/error-messages.md` updated with all 7 new classes (6 errors + 1 warning shared across both functions, plus 2 warnings = total new entries: `surveywts_error_interaction_spec_invalid`, `surveywts_error_interaction_variables_invalid`, `surveywts_error_interaction_variable_not_found`, `surveywts_error_interaction_targets_invalid`, `surveywts_error_interaction_cell_missing`, `surveywts_error_interaction_cell_not_in_data`, `surveywts_warning_interaction_variable_not_in_margins`, `surveywts_warning_interaction_marginal_inconsistency`)
- [ ] All 28 test cases in §VI pass
- [ ] `test_invariants()` passes on all outputs
- [ ] No composite column leaks into output `data`
- [ ] `R CMD check`: 0 errors, 0 warnings, ≤2 notes
- [ ] 98%+ line coverage maintained
- [ ] `devtools::document()` run; NAMESPACE and `.Rd` files updated

---

## VIII. Integration

### surveywts ↔ `survey` package

`survey::rake()` with interaction formula terms is the primary engine for
`method = "survey"`. This usage is not novel — `survey::rake()` documents
interaction support via `:` in formula terms. No new API usage beyond what
the `calibration-fixes` spec already established.

`survey::calibrate()` with interaction terms in the formula is similarly
established API behavior. The model matrix approach is the same as the
existing linear/logit paths; interaction terms add more columns.

### No surveycore changes

This feature does not require surveycore changes. The S7 classes and
validators are unchanged.

### Downstream: `summarize_weights()` / diagnostic functions

Unaffected. These operate on the output weights, not the calibration
procedure.

### Distinction preserved: `rake()` vs `poststratify()`

- `rake()` with `interaction_margins`: **soft** IPF constraint. The joint
  target is one more margin in the iterative sweep. Weights converge to satisfy
  all margins simultaneously to within tolerance. When margin targets are
  slightly inconsistent (as they always are when drawn from different ACS
  tables), IPF handles this gracefully.
- `calibrate()` with `interaction_terms`: **GREG** constraint. The joint is
  embedded as additional moment conditions. Weights satisfy all conditions to
  within `control$epsilon` (linear: exact; logit: to within solver tolerance).
- `poststratify()`: **hard** constraint. Every joint cell is forced to exactly
  match the population target. No iteration; not suitable when benchmarks come
  from different sources.

This distinction must be documented in the `@details` section of both
`rake()` and `calibrate()`.
