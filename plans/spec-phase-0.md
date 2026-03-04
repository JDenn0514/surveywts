# Phase 0 Spec: Weighting Core (v0.1.0)

**Version:** 0.2
**Date:** 2026-02-27
**Status:** Reviewed and resolved — ready for implementation planning
**Branch identifier:** `phase-0`
**Related files:** `plans/spec-review-phase-0.md` (after review), `plans/decisions-phase-0.md` (after resolve)

---

## Document Purpose

This document is the single source of truth for Phase 0 of surveyweights. It
fully specifies every exported class, function, error class, and test
expectation required to ship v0.1.0. Implementation may not begin until this
spec is approved (Stage 2 review + Stage 3 resolve complete).

This spec does NOT repeat rules defined in:
- `code-style.md` — formatting, pipe, error structure, S7 patterns, argument order
- `r-package-conventions.md` — `::` usage, NAMESPACE, roxygen2, export policy
- `surveyweights-conventions.md` — error/warning prefixes, return visibility
- `testing-standards.md` — `test_that()` scope, coverage targets, assertion patterns

Those rules apply by reference. Where this spec makes a choice consistent with
those rules, it states the outcome without re-explaining the rule.

---

## I. Scope

### Deliverables (v0.1.0)

| Component | Type | Exported? |
|-----------|------|-----------|
| `weighted_df` | S3 class | Yes (class object; no user constructor) |
| `survey_calibrated` | S7 class | Yes |
| `calibrate()` | Function | Yes |
| `rake()` | Function | Yes |
| `poststratify()` | Function | Yes |
| `adjust_nonresponse()` | Function | Yes |
| `effective_sample_size()` | Function | Yes |
| `weight_variability()` | Function | Yes |
| `summarize_weights()` | Function | Yes |
| `print.weighted_df()` | S3 method | No (registered via `@export`) |
| `dplyr_reconstruct.weighted_df()` | S3 method | No (registered via `@export`) |
| All `.`-prefixed helpers | Internal | No |

### Non-Deliverables (Phase 0)

The following are explicitly out of scope and must not be implemented, even
partially, unless marked as a stub:

- `variance = "bootstrap"` in calibration (Phase 1) — stub error required
- `survey_replicate` input to calibration functions (Phase 1) — stub error
- `method = "propensity"` in `adjust_nonresponse()` (Phase 2) — stub error
- Calibration on continuous auxiliary variables — not supported; error if detected
- `trim_weights()` and `stabilize_weights()` (Phase 4)
- `check_balance()` and `diagnose_propensity()` (Phase 4)

### Input/Output Class Matrix

| Input class | `calibrate()` / `rake()` / `poststratify()` output | `adjust_nonresponse()` output |
|---|---|---|
| `data.frame` | `weighted_df` | `weighted_df` |
| `weighted_df` | `weighted_df` | `weighted_df` |
| `survey_taylor` | `survey_calibrated` | `survey_taylor` (same class) |
| `survey_calibrated` | `survey_calibrated` (same class) | `survey_calibrated` (same class) |
| `survey_replicate` | Error: `surveyweights_error_replicate_not_supported` | Error: `surveyweights_error_replicate_not_supported` |
| Any other | Error: `surveyweights_error_unsupported_class` | Error: `surveyweights_error_unsupported_class` |

**Rule:** Calibration of a `survey_taylor` object changes the variance class
to `survey_calibrated` because calibration changes the variance estimation
strategy. Nonresponse adjustment does NOT change the variance class because
weights are modified, not the variance method.

---

## II. Architecture

### Source File Organization

```
R/
├── 00-classes.R          # weighted_df S3 class definition; survey_calibrated S7 class + validator
├── 01-constructors.R     # .new_survey_calibrated() — internal constructor only
├── 02-calibrate.R        # calibrate()
├── 03-rake.R             # rake() + .parse_margins()
├── 04-poststratify.R     # poststratify() + .validate_population_cells() (private, not in 07-utils.R)
├── 05-nonresponse.R      # adjust_nonresponse()
├── 06-diagnostics.R      # effective_sample_size(), weight_variability(), summarize_weights()
├── 07-utils.R            # Shared internal helpers (used by 2+ source files):
│                         #   .get_weight_vec(), .get_weight_col_name(), .validate_weights(),
│                         #   .validate_calibration_variables(), .validate_population_marginals(),
│                         #   .compute_weight_stats(), .make_history_entry(),
│                         #   .calibrate_engine(), .make_weighted_df(), .update_survey_weights()
├── vendor/
│   ├── calibrate-greg.R  # Vendored GREG/logit calibration from survey::calibrate()
│   └── calibrate-ipf.R   # Vendored IPF/raking from survey::rake()
└── surveyweights-package.R  # Package doc + .onLoad() calling S7::methods_register()
tests/
└── testthat/
    ├── helper-test-data.R          # make_surveyweights_data(), test_invariants()
    ├── test-00-classes.R
    ├── test-02-calibrate.R
    ├── test-03-rake.R
    ├── test-04-poststratify.R
    ├── test-05-nonresponse.R
    └── test-06-diagnostics.R
```

> **Note:** This file organization supersedes the single-file structure described in early spec
> drafts. The implementation plan (`plans/impl-phase-0.md`) and this section are the authoritative
> source for file layout.

### Class Hierarchy

```
surveycore::survey_base  (abstract)
  ├── surveycore::survey_taylor
  ├── surveycore::survey_replicate
  └── surveyweights::survey_calibrated   ← defined in this package

S3 (independent of S7 hierarchy):
  weighted_df  ← c("weighted_df", "tbl_df", "tbl", "data.frame")
```

**`surveyweights-package.R`** must define `.onLoad()` calling `S7::methods_register()`
to register all S7 method dispatch at package load time. Without this, S7 print and
summary methods for `survey_calibrated` will silently fail to dispatch at runtime.

```r
.onLoad <- function(libname, pkgname) {
  S7::methods_register()
}
```

> ⚠️ GAP: The exact property names and inheritance path of `surveycore::survey_base`
> must be verified against the surveycore source before implementation begins. This
> spec assumes `survey_base` has `@data`, `@variables`, and `@metadata` properties.
> See Section III (Surveycore Prerequisite Contract) for the required interface.

### Shared Internal Helper Signatures

All internal helpers live in `R/07-utils.R` (used in 2+ source files per
`code-style.md` helper placement rule).

```r
.make_weighted_df(data, weight_col, history = list())
.new_survey_calibrated(design, updated_weights, history_entry)
.calibrate_engine(data, weights_vec, calibration_spec, method, control)
.make_history_entry(operation, call_str, parameters, before_stats, after_stats,
                    convergence = NULL)
.compute_weight_stats(weights_vec)
.validate_weights(data, weight_col)
.validate_population_marginals(population, variable_names, data, type)
.validate_population_cells(population, strata_names, data, type)
.get_weight_vec(x, weights_quo)
.get_weight_col_name(x, weights_quo)
```

---

## II.b Package Dependencies

DESCRIPTION `Imports` for Phase 0. All calls use `::` per `r-package-conventions.md`
(no `@importFrom`). Minimum versions are the oldest that provide the required features.

```
Imports:
    cli (>= 3.6.0),         # cli_abort() / cli_warn() with class= argument
    dplyr (>= 1.1.0),       # dplyr_reconstruct() generic for weighted_df compatibility
    rlang (>= 1.1.0),       # enquo(), as_name(), check_required()
    S7 (>= 0.2.0),          # S7::new_class(), S7::method(), S7::S7_inherits()
    surveycore (>= 0.1.0),  # survey_base, survey_taylor, survey_calibrated parent class
    tibble (>= 3.2.0)       # as_tibble(), tibble() for weighted_df and summarize output
Suggests:
    survey (>= 4.2-1),      # Numerical correctness tests only (skip_if_not_installed)
    testthat (>= 3.2.0)
```

> ⚠️ GAP: Confirm the minimum surveycore version once the prerequisite PR (Section III)
> is merged. `0.1.0` is a placeholder.

---

## II.c Vendored Code

Core statistical algorithms are vendored from reference implementations rather than
implemented from scratch. This grounds the package in peer-reviewed, production-tested
code, keeps the `survey` package in `Suggests` (not `Imports`), and provides clear
attribution for the mathematical foundation.

### Vendoring rules

- Vendored files live in `R/vendor/{descriptive-name}.R`
- Every vendored file carries a comment block at the top: original package, version,
  author, license, and the URL or function from which the code was derived
- `VENDORED.md` at the repo root is the authoritative attribution record; it must be
  updated in the same PR that adds or modifies vendored code
- Vendored code may be minimally adapted (renamed internals, removed dependencies) but
  the algorithm must remain mathematically identical to the source
- All vendored code is covered by the package's numerical correctness tests

### Phase 0 vendored algorithms

| File | Algorithm | Source | License |
|------|-----------|--------|---------|
| `R/vendor/calibrate-greg.R` | GREG (linear) and logit calibration | `survey::calibrate()` — Thomas Lumley, `survey` package | GPL-2+ |
| `R/vendor/calibrate-ipf.R` | Iterative Proportional Fitting (raking) | `survey::rake()` — Thomas Lumley, `survey` package | GPL-2+ |

GPL-2+ code is compatible with this package's GPL-3 license.

### `adjust_nonresponse()` — reference implementation TBD

No direct reference implementation has been identified for the weighting-class
nonresponse method. The formula is simple (`w_new = w * sum_all / sum_respondents`
per cell), but a peer-reviewed reference package should be identified before
implementation begins to serve as the numerical oracle in tests.

> ⚠️ GAP: Identify a reference R package or validated implementation for
> weighting-class nonresponse adjustment. Candidate packages to evaluate:
> `anesrake` (Pasek & Tahk), `WeightIt` (Greifer). If no package provides
> a direct equivalent, document hand-calculation validation methodology.

---

## II.d Common Function Contracts

All calibration and nonresponse functions share the following contracts. Per-function
sections reference this section rather than repeating these definitions.

### Common Arguments

The following arguments have identical definitions across `calibrate()`, `rake()`,
`poststratify()`, and `adjust_nonresponse()`. Each function's argument table lists
these rows with "See §II.d" in place of the description.

| Arg | Type | Default | Description |
|-----|------|---------|-------------|
| `data` | `data.frame`, `weighted_df`, `survey_taylor`, `survey_calibrated` | required | Input dataset or survey design. `survey_replicate` → `surveyweights_error_replicate_not_supported`. Any other class → `surveyweights_error_unsupported_class`. |
| `weights` | bare name (NSE) | `NULL` | Weight column name. `NULL` → uniform weights (1/n for all rows). For `weighted_df`, auto-detected from `attr(data, "weight_col")`. For survey objects, auto-detected from `@variables$weights`. When specified, the column must be numeric, strictly positive, and contain no `NA`. |

### Common Validation Rules

The following errors are thrown by **all** calibration and nonresponse functions
before any function-specific logic. They are stated once here; per-function error
tables list only function-specific errors. See **Section XII.A** for full message
templates.

| Class | Trigger condition |
|-------|-------------------|
| `surveyweights_error_unsupported_class` | `data` is not a supported class (see matrix in §I) |
| `surveyweights_error_replicate_not_supported` | `data` is `survey_replicate` |
| `surveyweights_error_empty_data` | `nrow(data) == 0` |
| `surveyweights_error_weights_not_found` | Named weight column not in `data` |
| `surveyweights_error_weights_not_numeric` | Weight column is not numeric |
| `surveyweights_error_weights_nonpositive` | Weight column has values ≤ 0 |
| `surveyweights_error_weights_na` | Weight column has `NA` values |

### Output Class Rules

Output class follows the matrix in **Section I**. The rule about `adjust_nonresponse()`
not changing the variance class is stated in Section I's rule block.

When input is a plain `data.frame` and `weights = NULL`, the default weight column
is named `".weight"`. This is the authoritative definition of that default; see
`.get_weight_col_name()` in Section XI for the implementing helper.

### `control` Argument Merge Semantics

User-supplied `control` values are **merged with defaults** — any omitted key retains
its default value. Implemented via `modifyList(list(maxit = 50, epsilon = 1e-7), control)`.
Users may pass `control = list(maxit = 100)` without specifying `epsilon`; `epsilon`
falls back to `1e-7`.

`control$maxit = 0` is treated as invalid: the algorithm never runs and immediately
throws `surveyweights_error_calibration_not_converged` with a note that 0 iterations
means no calibration was attempted.

### Convergence Criterion

For iterative algorithms (`calibrate()` and `rake()`), convergence after each full
iteration is assessed as:

```
max over all cells/margins h: |calibrated_h - target_h| / target_h  <  epsilon
```

where `calibrated_h` and `target_h` are on the same scale (both proportions or both
counts). For `rake()`, one "iteration" means one full sweep through all margins. For
`calibrate()`, one "iteration" means one full optimization step.

Non-convergence within `control$maxit` → `surveyweights_error_calibration_not_converged`.

For `poststratify()` and `adjust_nonresponse()`, no iteration occurs; both are
single-pass exact operations.

### Validation Order

All calibration and nonresponse functions validate in this fixed order. When multiple
errors are present, the **first** one in this sequence is thrown:

1. Input class check (`surveyweights_error_unsupported_class` / `surveyweights_error_replicate_not_supported`)
2. Empty data check (`surveyweights_error_empty_data`)
3. Weights validation (all four weight errors via `.validate_weights()`)
4. Function-specific validation (variables, population/margins, response status)

This ordering is part of the API contract and must not vary across implementations.
Snapshot tests depend on it.

---

## III. Surveycore Prerequisite Contract

Phase 0 requires the following changes to `surveycore` to be complete and
merged **before** Phase 0 implementation begins. These are specified here as
an interface contract; implementation belongs in a separate surveycore PR.

### Required surveycore changes

1. **Add `weighting_history` property to the surveycore metadata class.**
   - Type: `list` (default: `list()`)
   - Each element is a history entry as specified in Section IV.5 (weighting history
     entry format)

2. **Update surveycore constructors** (`as_survey_taylor()`, etc.) to accept
   `weighted_df` input and promote its `weighting_history` attribute to
   `@metadata@weighting_history`.

3. **Accessor** `survey_weighting_history(x)` — extracts `@metadata@weighting_history`
   from a survey object. Returns a list (empty list if none). Exported from surveycore.

### What surveycore must provide for Phase 0

| Property / method | Where used in surveyweights |
|---|---|
| `survey_base` S7 class (parent for `survey_calibrated`) | `R/00-classes.R` |
| `@data` property on `survey_taylor` | Weight extraction, data update |
| `@variables` list (ids, weights, strata, fpc) on `survey_taylor` | Design variable lookup |
| `@metadata` with `weighting_history` list property | History tracking |
| `survey_weighting_history(x)` accessor | Diagnostics, history display |

> ⚠️ GAP: Confirm with surveycore source that `@variables$weights` is a
> character scalar (the column name of the weight variable) and not the
> weight vector itself.

---

## IV. `weighted_df` S3 Class

### Definition

`weighted_df` is an S3 subclass of tibble. It is **never** created by users
directly — only by calibration and nonresponse functions.

```r
class(x)  #=> c("weighted_df", "tbl_df", "tbl", "data.frame")
```

### Attributes

| Attribute | Type | Description |
|-----------|------|-------------|
| `weight_col` | `character(1)` | Name of the weight column in the data frame |
| `weighting_history` | `list` | Ordered list of history entries (Section IV.5) |

The weight column is always present as a regular column in the data frame.
`weight_col` is the attribute that identifies which column it is.

**Rule (from CLAUDE.md):** The weight column is sacred. It must never be silently
removed or renamed. Operations that would remove it trigger
`surveyweights_warning_weight_col_dropped`.

### Internal Constructor: `.make_weighted_df()`

```r
.make_weighted_df <- function(data, weight_col, history = list()) {
  # Promotes a plain data.frame to weighted_df.
  # data: data.frame with weight_col already present
  # weight_col: character(1) — name of weight column
  # history: list of history entries to attach
}
```

Returns a `weighted_df`. Errors if `weight_col` is not a column in `data`.

### dplyr Compatibility: `dplyr_reconstruct.weighted_df()`

Registered to restore `weighted_df` class after dplyr verbs.

**Behavior:**
1. If the weight column (`attr(x, "weight_col")`) is present in the result → restore
   `weighted_df` class and both attributes.
2. If the weight column was removed → issue `surveyweights_warning_weight_col_dropped`
   and return a plain tibble.
3. **Renaming the weight column** is treated the same as dropping it: `dplyr_reconstruct`
   does not detect renames and will trigger rule 2 above. For rename-aware behavior that
   auto-updates the `weight_col` attribute, load `surveytidy`, which provides a
   `rename.weighted_df()` S3 method.

```r
#' @export
dplyr_reconstruct.weighted_df <- function(data, template) { ... }
```

### Print Method: `print.weighted_df()`

```r
#' @export
print.weighted_df <- function(x, n = 10, ...) { ... }
```

**Verbatim console output format:**

```
# A weighted data frame: 1,500 × 12
# Weight: wt_final (n = 1,500, mean = 1.00, CV = 0.18, ESS = 1,189)
# Weighting history: 2 steps
#   Step 1 [2025-01-15]: weighting-class nonresponse (by: age, sex)
#   Step 2 [2025-01-15]: raking (margins: age, sex, education)
# ── Data ─────────────────────────────────────────────────────────────────
   id   age   sex   education  wt_final ...
   <int> <chr> <chr> <chr>      <dbl>   ...
 1     1 18-34 M     <HS         0.72   ...
 2     2 35-54 F     College     1.14   ...
...
# ℹ 1,490 more rows
```

Rules:
- The tibble body is printed via `NextMethod()` (delegates to tibble's print).
- The header block (lines starting with `#`) is printed by `print.weighted_df()`.
- `n` controls the number of rows shown (default 10, same as tibble).
- History shows all steps with date (formatted as `YYYY-MM-DD`).
- If `weighting_history` is empty, the history line reads: `# Weighting history: none`
- `invisible(x)` is returned per `surveyweights-conventions.md`.

### Weighting History Entry Format

Every weighting operation produces one entry appended to `weighting_history`:

```r
list(
  step            = 1L,                    # integer, position in history
  operation       = "raking",              # character: "raking", "calibration",
                                           #   "poststratify", "nonresponse_weighting_class"
  timestamp       = Sys.time(),            # POSIXct
  call            = "rake(df, ...)",       # character: deparsed call
  parameters      = list(                  # resolved names, not expressions
    variables     = c("age", "sex"),       # for calibrate/rake/poststratify
    population    = list(...),             # full population argument stored as-is.
                                           # For calibrate() and poststratify():
                                           #   the named list / data.frame passed by
                                           #   the user, unchanged.
                                           # For rake(): always stored in named-list
                                           #   form (Format A), regardless of whether
                                           #   the user passed Format A or Format B.
                                           #   Long-format input is converted before
                                           #   storing. Goal: fully auditable targets.
    control       = list(maxit = 50, epsilon = 1e-7)
  ),
  weight_stats    = list(
    before        = list(n = 1500, n_positive = 1500, n_zero = 0,
                         mean = 1.0, cv = 0.18,
                         min = 0.3, p25 = 0.7, p50 = 0.95, p75 = 1.2,
                         max = 3.1, ess = 1189),
    after         = list(...)              # same structure
  ),
  convergence     = list(                  # NULL for non-iterative operations
    converged     = TRUE,
    iterations    = 12L,
    max_error     = 0.0003,
    tolerance     = 1e-6
  ),
  package_version = "0.1.0"               # as.character(packageVersion("surveyweights"))
)
```

### `weighted_df` Error/Warning Table

| Class | Thrown by | Condition |
|-------|-----------|-----------|
| `surveyweights_warning_weight_col_dropped` | `dplyr_reconstruct.weighted_df()` | dplyr verb removed the weight column |

---

## V. `survey_calibrated` S7 Class

### Definition and Inheritance

```r
survey_calibrated <- S7::new_class(
  "survey_calibrated",
  parent = surveycore::survey_base,
  ...
)
```

> ⚠️ GAP: Confirm the exact reference path for `survey_base` from surveycore.
> It may be `surveycore::survey_base` or registered differently.

`survey_calibrated` does NOT extend `survey_taylor`. It extends `survey_base`
to avoid accidentally inheriting Taylor-specific dispatch that would be
incorrect post-calibration.

### Properties

`survey_calibrated` inherits all properties from `survey_base` and adds none.
Weighting provenance is stored in `@metadata@weighting_history`, which is
added to the surveycore metadata class in the prerequisite update.

| Property | Type | Inherited from | Description |
|----------|------|----------------|-------------|
| `@data` | `data.frame` | `survey_base` | The survey microdata |
| `@variables` | `list` | `survey_base` | Named list: `ids`, `weights`, `strata`, `fpc`, `nest` |
| `@metadata` | surveycore metadata class | `survey_base` | Labels, history, etc. |

`@variables$weights`: character scalar — the name of the weight column in `@data`.

### S7 Validator

The validator enforces:
1. `@variables$weights` is a character scalar.
2. The column named by `@variables$weights` exists in `@data`.
3. The weight column is numeric.
4. All weight values are strictly positive (> 0).
5. No NA values in the weight column.

Validator errors use S7's native mechanism (not `cli_abort()`). They will not
have formatted CLI messages. Test with `class =` only, no snapshot.

> **Note (Open GAP #1):** `@variables` key presence (`ids`, `strata`, `fpc`, `nest`) is
> assumed to be enforced by the `survey_base` parent validator from surveycore. Verify
> against surveycore source before implementation. If the parent validator does NOT enforce
> these keys, add corresponding checks to this validator.

### Internal Constructor: `.new_survey_calibrated()`

```r
.new_survey_calibrated <- function(design, updated_data, updated_weights_col,
                                   history_entry) {
  # design: the input survey_taylor or survey_calibrated
  # updated_data: data.frame with new weight column values
  # updated_weights_col: character(1) — column name in updated_data
  # history_entry: list from .make_history_entry()
  # Returns: survey_calibrated
}
```

This function is unexported. The calibration user-facing functions (`calibrate()`,
`rake()`, `poststratify()`) call it when input is a survey object.

### Print Method

```r
S7::method(print, survey_calibrated) <- function(x, n = 10, ...) { ... }
```

**Verbatim console output format:**

```
# A calibrated survey design: 1,500 observations, 12 variables
# Variance method: Taylor linearization
# IDs: ~psu_id | Strata: ~stratum | Weights: wt_calibrated
# Weighting history: 2 steps
#   Step 1 [2025-01-15]: weighting-class nonresponse (by: age, sex)
#   Step 2 [2025-01-15]: raking (margins: age, sex, education)
```

**Variance method label:** The string `"Taylor linearization"` is hardcoded in the
print method for Phase 0. This is correct because `survey_calibrated` only accepts
`survey_taylor` or `survey_calibrated` input in Phase 0 (not `survey_replicate`).
Phase 1 will revisit this when replicate-weight designs become a supported input.

Returns `invisible(x)`.

---

## VI. `calibrate()`

### Purpose

General calibration to known marginal population totals using GREG (linear)
or logistic calibration. Supports categorical auxiliary variables only in
Phase 0. Cross-validates numerically against `survey::calibrate()`.

### Signature

```r
calibrate(
  data,
  variables,
  population,
  weights = NULL,
  method = c("linear", "logit"),
  type = c("prop", "count"),
  control = list(maxit = 50, epsilon = 1e-7)
)
```

### Argument Table

**Argument order:** `data` (1), `variables` (2, required NSE), `population` (3, required
scalar), `weights` (4, optional NSE), `method` (5, optional scalar), `type` (6, optional
scalar), `control` (7, optional scalar).

| Arg | Type | Default | Description |
|-----|------|---------|-------------|
| `data` | — | required | See **§II.d** |
| `weights` | — | `NULL` | See **§II.d** |
| `variables` | tidy-select | required | Columns to calibrate on. Must be categorical (character or factor). |
| `population` | named list | required | Marginal population targets. Names match the selected `variables`. Each element: a named numeric vector (`level = target`). |
| `method` | character | `"linear"` | Calibration method: `"linear"` (GREG) or `"logit"` (bounded). |
| `type` | character | `"prop"` | Whether `population` targets are proportions (`"prop"`) or counts (`"count"`). |
| `control` | list | `list(maxit = 50, epsilon = 1e-7)` | Convergence parameters: `maxit` (max iterations), `epsilon` (tolerance; see §II.d convergence criterion). |

### `population` Format

A **named list** where:
- Names are the column names selected by `variables`.
- Each element is a named numeric vector: `c(level = target, ...)`.
- For `type = "prop"`: each element's values must sum to 1.0 (within `1e-6` tolerance).
- For `type = "count"`: each element's values must be positive.

```r
# type = "prop" example
list(
  age_group = c("18-34" = 0.28, "35-54" = 0.37, "55+" = 0.35),
  sex       = c("M" = 0.49, "F" = 0.51)
)

# type = "count" example
list(
  age_group = c("18-34" = 42000, "35-54" = 55500, "55+" = 52500),
  sex       = c("M" = 73500, "F" = 76500)
)
```

Every level present in `data[[variable]]` must appear in the corresponding
population entry. Levels present in `population` but absent from `data` are
an error (`surveyweights_error_population_level_extra`).

### Output Contract

Class follows the matrix in **Section I**. When `weights = NULL` and input is a
plain `data.frame`, the weight column is named `".weight"` (see **§II.d**).

**History:** A history entry with `operation = "calibration"` is appended to
`weighting_history`.

### Behavior Rules

1. `variables` must be categorical (character or factor). Numeric/integer variables
   → `surveyweights_error_variable_not_categorical`. Phase 0 does not support
   calibration on continuous auxiliary variables.
2. `method = "linear"` may produce negative calibrated weights. The function returns
   the result and issues `surveyweights_warning_negative_calibrated_weights`. The
   user decides whether to accept negative weights.
3. Convergence is assessed per **§II.d**. Non-convergence within `control$maxit`
   → `surveyweights_error_calibration_not_converged`.

### Error and Warning Table

Common validation errors from **§II.d** apply. The errors below are specific to
`calibrate()`. See **Section XII.B** for full message templates.

| Class | Trigger condition |
|-------|-------------------|
| `surveyweights_error_variable_not_categorical` | A `variables` column is `numeric` or `integer` |
| `surveyweights_error_variable_has_na` | A `variables` column has `NA` values |
| `surveyweights_error_population_variable_not_found` | A `population` name not found in `data` |
| `surveyweights_error_population_level_missing` | A level in `data` has no entry in `population` |
| `surveyweights_error_population_level_extra` | A `population` level has no observations in `data` |
| `surveyweights_error_population_totals_invalid` | `type = "prop"` proportions don't sum to 1 |
| `surveyweights_error_calibration_not_converged` | Max iterations reached without convergence |
| `surveyweights_warning_negative_calibrated_weights` | `method = "linear"` produced negative weights |

---

## VII. `rake()`

### Purpose

Iterative proportional fitting (raking) to multiple marginal population totals.
This is the preferred function when multiple margins must be calibrated
simultaneously. Cross-validates numerically against `survey::rake()`.

### Signature

```r
rake(
  data,
  margins,
  weights = NULL,
  type = c("prop", "count"),
  control = list(maxit = 50, epsilon = 1e-7)
)
```

### Argument Table

**Argument order:** `data` (1), `margins` (2, required scalar), `weights` (3, optional NSE),
`type` (4, optional scalar), `control` (5, optional scalar).

| Arg | Type | Default | Description |
|-----|------|---------|-------------|
| `data` | — | required | See **§II.d** |
| `weights` | — | `NULL` | See **§II.d** |
| `margins` | named list or data.frame | required | Population targets. See formats below. |
| `type` | character | `"prop"` | Whether targets are proportions or counts. |
| `control` | list | `list(maxit = 50, epsilon = 1e-7)` | Convergence: `maxit` (max full sweeps), `epsilon` (tolerance; see §II.d convergence criterion). |

### `margins` Formats

Two formats are accepted (auto-detected by structure):

**Format A — Named list** (same structure as `calibrate()`'s `population`):
```r
list(
  age_group = c("18-34" = 0.28, "35-54" = 0.37, "55+" = 0.35),
  sex       = c("M" = 0.49, "F" = 0.51)
)
```
Auto-detected when `margins` is a named `list`.

**Format B — Long data frame** with columns `variable`, `level`, `target`:
```r
tibble(
  variable = c("age_group", "age_group", "age_group", "sex", "sex"),
  level    = c("18-34", "35-54", "55+", "M", "F"),
  target   = c(0.28, 0.37, 0.35, 0.49, 0.51)
)
```
Auto-detected when `margins` is a `data.frame` with exactly these three columns.

Values are coerced to numeric. Missing columns in Format B → error
`surveyweights_error_margins_format_invalid`.

Individual elements of Format A can be a data frame with `level` and `target`
columns (not just named vectors). This allows mixing formats:
```r
list(
  age_group = c("18-34" = 0.28, "35-54" = 0.37, "55+" = 0.35),
  sex       = tibble(level = c("M", "F"), target = c(0.49, 0.51))
)
```

### Output Contract

Class follows the matrix in **Section I** (same rules as `calibrate()`). When
`weights = NULL` and input is a plain `data.frame`, the weight column is named
`".weight"` (see **§II.d**).

**History:** Operation is `"raking"`. `parameters$variables` contains the
variable names derived from `margins` names (or the `variable` column). Input
in Format B is converted to Format A before storing in history.

### Behavior Rules

1. `margins` variables must be categorical (character or factor). Numeric/integer
   → `surveyweights_error_variable_not_categorical`. IPF requires categorical margins.
2. The IPF algorithm cycles through all margins in order until convergence or
   `control$maxit` full sweeps are completed.
3. Convergence is assessed per **§II.d** after each full sweep.

### Error and Warning Table

Common validation errors from **§II.d** apply. The errors below are specific to
`rake()`. See **Section XII.C** for full message templates.

| Class | Trigger condition |
|-------|-------------------|
| `surveyweights_error_margins_format_invalid` | `margins` is not a named list or valid long data frame |
| `surveyweights_error_margins_variable_not_found` | A `margins` variable not in `data` |
| `surveyweights_error_variable_not_categorical` | A `margins` variable is `numeric` or `integer` |
| `surveyweights_error_variable_has_na` | A `margins` variable has `NA` values |
| `surveyweights_error_population_level_missing` | A data level absent from `margins` |
| `surveyweights_error_population_level_extra` | A margins level has no observations in `data` |
| `surveyweights_error_population_totals_invalid` | `type = "prop"` proportions don't sum to 1, or `type = "count"` target ≤ 0 |
| `surveyweights_error_calibration_not_converged` | Max full sweeps reached without convergence |

---

## VIII. `poststratify()`

### Purpose

Exact post-stratification. Calibrates to known joint population cell counts or
proportions. Unlike `rake()`, this achieves exact calibration to cross-tabulation
cells, not just marginal totals. Cross-validates against `survey::postStratify()`.

### Signature

```r
poststratify(
  data,
  strata,
  population,
  weights = NULL,
  type = c("count", "prop")
)
```

### Argument Table

**Argument order:** `data` (1), `strata` (2, required NSE), `population` (3, required scalar),
`weights` (4, optional NSE), `type` (5, optional scalar).

| Arg | Type | Default | Description |
|-----|------|---------|-------------|
| `data` | — | required | See **§II.d** |
| `weights` | — | `NULL` | See **§II.d** |
| `strata` | tidy-select | required | Stratification variables (jointly define cells). |
| `population` | `data.frame` | required | One row per cell. Columns: same names as `strata` + `target`. |
| `type` | character | `"count"` | Whether `target` column is proportions or counts. Default `"count"` (different from other functions — most common usage). |

### `population` Format

A `data.frame` with:
- One column per variable selected by `strata` (column names must match exactly).
- One column named `"target"` with the cell count or proportion.
- One row per unique cell combination.
- For `type = "prop"`: values in `target` must sum to 1.0 (within 1e-6).
- For `type = "count"`: values in `target` must be positive.

```r
tribble(
  ~age_group, ~sex, ~target,
  "18-34",    "M",  14000,
  "18-34",    "F",  15000,
  "35-54",    "M",  18000,
  "35-54",    "F",  19000,
  "55+",      "M",  17000,
  "55+",      "F",  17000
)
```

Every cell combination present in `data` must appear in `population`. Cells
in `population` but absent from `data` → error
`surveyweights_error_population_cell_not_in_data`. If a user genuinely wants to
ignore extra cells, they must remove them from the population data frame before
calling — silent ignorance of extra cells risks masking misspecification.

Duplicate rows in `population` (same cell combination appearing more than once)
→ error `surveyweights_error_population_cell_duplicate`. Duplicate rows indicate
a data entry error and produce ambiguous targets.

### Output Contract

Class follows the matrix in **Section I**. When `weights = NULL` and input is a
plain `data.frame`, the weight column is named `".weight"` (see **§II.d**).

**History:** Operation is `"poststratify"`.

### Behavior Rules

1. `strata` variables may be character, factor, integer, or numeric — all are
   valid as cell keys. Unlike `calibrate()` and `rake()`, poststratify performs
   a join-like operation where numeric keys are meaningful. No categorical
   restriction applies.
2. Post-stratification is exact (no iterations): `w_i_new = w_i * (N_h / N_hat_h)`,
   where `N_h` is the population total for cell `h` and `N_hat_h` is the
   current weighted count.
3. If a data cell has zero weighted count (all weights are 0 in a cell) →
   error `surveyweights_error_empty_stratum`.

### Error and Warning Table

Common validation errors from **§II.d** apply. The errors below are specific to
`poststratify()`. See **Section XII.D** for full message templates.

| Class | Trigger condition |
|-------|-------------------|
| `surveyweights_error_variable_has_na` | A `strata` variable has `NA` values |
| `surveyweights_error_population_totals_invalid` | `type = "prop"` targets don't sum to 1, or `type = "count"` target ≤ 0 |
| `surveyweights_error_population_cell_duplicate` | A cell combination appears more than once in `population` |
| `surveyweights_error_population_cell_missing` | A data cell has no matching row in `population` |
| `surveyweights_error_population_cell_not_in_data` | A `population` cell has no observations in `data` |
| `surveyweights_error_empty_stratum` | A stratum cell has zero weighted count |

---

## IX. `adjust_nonresponse()`

### Purpose

Weighting-class nonresponse adjustment. Redistributes nonrespondent weights to
respondents within weighting classes defined by `by`. Returns only respondent
rows with adjusted weights.

### Signature

```r
adjust_nonresponse(
  data,
  response_status,
  weights = NULL,
  by = NULL,
  method = c("weighting-class"),
  control = list(min_cell = 20, max_adjust = 2.0)
)
```

### Argument Table

**Argument order:** `data` (1), `response_status` (2, required NSE), `weights`
(3, optional NSE), `by` (4, optional tidy-select), `method` (5, optional scalar),
`control` (6, optional scalar).

| Arg | Type | Default | Description |
|-----|------|---------|-------------|
| `data` | — | required | See **§II.d**. Must include BOTH respondents and nonrespondents. |
| `weights` | — | `NULL` | See **§II.d**. Uniform weights are applied to ALL rows (respondents + nonrespondents) when `NULL`. |
| `response_status` | bare name (NSE) | required | Binary response indicator column. Must be `logical` or integer `0`/`1`. `1` / `TRUE` = respondent. |
| `by` | tidy-select | `NULL` | Weighting class variables. Redistribution is performed within each cell. `NULL` → global redistribution. |
| `method` | character | `"weighting-class"` | Adjustment method. Only `"weighting-class"` is supported in Phase 0. |
| `control` | list | `list(min_cell = 20, max_adjust = 2.0)` | Warning thresholds. `min_cell`: warn when a cell has fewer than this many respondents (default 20, per NAEP methodology). `max_adjust`: warn when the nonresponse weight adjustment factor for a cell exceeds this value (default 2.0, per `survey::sparseCells()` convention). Either condition alone triggers the warning. |

### Output Contract

| Input class | Output class |
|---|---|
| `data.frame` | `weighted_df` |
| `weighted_df` | `weighted_df` |
| `survey_taylor` | `survey_taylor` (same class — no variance method change) |
| `survey_calibrated` | `survey_calibrated` (same class) |
| `survey_replicate` | Error: `surveyweights_error_replicate_not_supported` |

**Row filtering:** Output contains only rows where `response_status == 1` (or
`TRUE`). Nonrespondent rows are dropped.

**Weight update rule (within each weighting class cell `h`):**

```
w_i_new = w_i_respondent * (sum(w_h) / sum(w_h_respondents))
```

where `sum(w_h)` is the sum of all weights (respondents + nonrespondents) in
cell `h`, and `sum(w_h_respondents)` is the sum of respondent weights only.

**History:** Operation is `"nonresponse_weighting_class"`. `parameters` includes
`by_variables` (character vector of `by` variable names) and `method`.

### Behavior Rules

1. `method = "propensity"` → error `surveyweights_error_propensity_requires_phase2`.
   This is an API-stable stub for Phase 2.
2. If `by = NULL`, redistribution is global: all nonrespondent weights flow to
   all respondents proportionally.
3. Cells with zero nonrespondents (all responded) pass through unchanged.

### Error and Warning Table

Common validation errors from **§II.d** apply. The errors below are specific to
`adjust_nonresponse()`. See **Section XII.E** for full message templates.

| Class | Trigger condition |
|-------|-------------------|
| `surveyweights_error_variable_has_na` | A `by` variable has `NA` values |
| `surveyweights_error_response_status_not_found` | `response_status` column not in `data` |
| `surveyweights_error_response_status_not_binary` | Column is not 0/1 or logical (factor columns are not binary regardless of their levels) |
| `surveyweights_error_response_status_has_na` | `response_status` column has `NA` values |
| `surveyweights_error_response_status_all_zero` | No respondents in `data` |
| `surveyweights_error_class_cell_empty` | A weighting class cell has no respondents |
| `surveyweights_error_propensity_requires_phase2` | `method = "propensity"` called |
| `surveyweights_warning_class_near_empty` | A cell is sparse by count or adjustment factor |

**Threshold for `surveyweights_warning_class_near_empty`:** warns when either
condition is met — `n_respondents < control$min_cell` OR
`adjustment_factor > control$max_adjust`. Both thresholds are user-configurable.

---

## X. Diagnostics

### `effective_sample_size()`

Kish's effective sample size: `ESS = (Σw)² / Σw²`.

```r
effective_sample_size(x, weights = NULL)
```

| Arg | Type | Default | Description |
|-----|------|---------|-------------|
| `x` | `data.frame`, `weighted_df`, or survey object | required | Input |
| `weights` | bare name (NSE) | `NULL` | Weight column. Auto-detected for `weighted_df` and survey objects. Required for plain `data.frame`. |

**Returns:** A named numeric scalar: `c(n_eff = <value>)`. Not a tibble — a
single number for composability. The name `"n_eff"` is part of the API contract.

**Errors:**

| Class | Condition |
|-------|-----------|
| `surveyweights_error_unsupported_class` | `x` is not a supported class |
| `surveyweights_error_weights_required` | `x` is a plain `data.frame` and `weights = NULL` |
| `surveyweights_error_weights_not_found` | Specified column not in `x` |
| `surveyweights_error_weights_not_numeric` | Weight column is not numeric |

### `weight_variability()`

Coefficient of variation of weights: `CV = sd(w) / mean(w)`.

```r
weight_variability(x, weights = NULL)
```

Same arguments and error behavior as `effective_sample_size()`.

**Returns:** A named numeric scalar: `c(cv = <value>)`. The name `"cv"` is part
of the API contract.

### `summarize_weights()`

Full distribution summary of the weight column, optionally within groups.

```r
summarize_weights(x, weights = NULL, by = NULL)
```

| Arg | Type | Default | Description |
|-----|------|---------|-------------|
| `x` | `data.frame`, `weighted_df`, or survey object | required | Input |
| `weights` | bare name (NSE) | `NULL` | Weight column. Auto-detected for `weighted_df` and survey objects. |
| `by` | tidy-select | `NULL` | Optional grouping variables for within-group summaries. |

**Returns:** A tibble with columns:

| Column | Type | Description |
|--------|------|-------------|
| (group columns) | varies | One column per `by` variable, if `by` is specified |
| `n` | integer | Total observations in group |
| `n_positive` | integer | Observations with `weight > 0` |
| `n_zero` | integer | Observations with `weight == 0` |
| `mean` | double | Mean weight |
| `cv` | double | Coefficient of variation |
| `min` | double | Minimum weight |
| `p25` | double | 25th percentile |
| `p50` | double | Median |
| `p75` | double | 75th percentile |
| `max` | double | Maximum weight |
| `ess` | double | Effective sample size (Kish's formula) |

When `by = NULL`, returns a single-row tibble (overall summary).

**Errors:** Same error behavior as `effective_sample_size()`, including
`surveyweights_error_unsupported_class` for non-supported input classes.

---

## XI. Internal Utilities

**Shared utilities** (used by 2+ source files) live in `R/07-utils.R`. All unexported,
all `.`-prefixed.

**Exception:** `.validate_population_cells()` is a private helper co-located in
`R/04-poststratify.R` because only `poststratify()` calls it. It is NOT in `07-utils.R`.

### `.get_weight_vec(x, weights_quo)`

Extracts the weight vector from any supported input class.

```r
.get_weight_vec <- function(x, weights_quo) {
  # x: data.frame, weighted_df, survey_taylor, or survey_calibrated
  # weights_quo: quosure from rlang::enquo(weights) in the calling function
  # Returns: numeric vector of weights
  # If weights_quo is NULL and x is weighted_df or survey object: auto-detect
  # If weights_quo is NULL and x is data.frame: uniform weights (1/n_rows)
}
```

### `.get_weight_col_name(x, weights_quo)`

Returns the name of the weight column as a character string. For a plain
`data.frame` with `weights_quo = NULL`, returns `".weight"` — this is the
**authoritative definition** of the default weight column name used by all
calibration functions when no weight column is specified.

```r
.get_weight_col_name <- function(x, weights_quo)
# Returns: character(1)
```

### `.validate_weights(data, weight_col)`

Validates that the weight column exists, is numeric, all positive, no NAs.
Throws typed errors on failure. Returns `invisible(TRUE)` on success.

```r
.validate_weights <- function(data, weight_col)
# data: data.frame
# weight_col: character(1)
```

### `.validate_calibration_variables(data, variable_names, context)`

Validates that calibration/raking variables are categorical and contain no NAs.
Used by both `calibrate()` and `rake()`. Returns `invisible(TRUE)` on success.

```r
.validate_calibration_variables <- function(data, variable_names, context)
# data: data.frame
# variable_names: character vector of column names to check
# context: character(1) — "Calibration" or "Raking"; appears in error messages
# Throws:
#   surveyweights_error_variable_not_categorical if any column is not character or factor
#   surveyweights_error_variable_has_na if any column contains NA values
```

### `.validate_population_marginals(population, variable_names, data, type)`

Validates the `population` named list for `calibrate()`. Checks:
- Names in `population` match `variable_names`.
- Each element has all levels present in `data[[var]]`.
- Proportions sum to 1 (for `type = "prop"`).
- Values are positive (for `type = "count"`).

Returns `invisible(TRUE)` on success.

### `.validate_population_cells()` — private helper in `R/04-poststratify.R`

See `R/04-poststratify.R`. Not in `07-utils.R` — only `poststratify()` calls it.

Validates the `population` data frame for `poststratify()`. Checks:
- Required columns present (`strata_names` + `"target"`).
- Every cell in `data` has a matching row in `population`.
- No duplicate rows in `population` (same cell combination appearing more than once).
- Target values are valid (positive; sum to 1 if `type = "prop"`).

```r
.validate_population_cells <- function(population, strata_names, data, type)
# Returns invisible(TRUE) on success.
```

### `.compute_weight_stats(weights_vec)`

```r
.compute_weight_stats <- function(weights_vec)
# weights_vec: numeric vector
# Returns: named list with n, n_positive, n_zero, mean, cv, min, p25, p50, p75, max, ess
```

Used by `.make_history_entry()` and `summarize_weights()`.

### `.make_history_entry(operation, call_str, parameters, before_stats, after_stats, convergence = NULL)`

Creates a single history entry (see Section IV.5 for format).

```r
.make_history_entry <- function(operation, call_str, parameters,
                                before_stats, after_stats,
                                convergence = NULL)
# Returns: list matching the history entry format in Section IV.5
```

`call_str`: the deparsed call, passed from the outer function via
`deparse(match.call())`.

### `.calibrate_engine(data_df, weights_vec, calibration_spec, method, control)`

The shared computation engine used by `calibrate()`, `rake()`, and
`poststratify()`. Takes only plain data (no S7/S3 dispatch). Returns a
numeric vector of calibrated weights.

```r
.calibrate_engine <- function(data_df, weights_vec, calibration_spec,
                               method, control)
# data_df: plain data.frame
# weights_vec: numeric vector, length = nrow(data_df)
# calibration_spec: a list describing the calibration problem (see below)
# method: "linear", "logit", or "ipf" (rake uses "ipf")
# control: list(maxit, epsilon)
# Returns: numeric vector of calibrated weights
```

`calibration_spec` structure:
```r
list(
  type = "ipf",          # or "linear", "logit", "poststratify"
  variables = list(      # for "ipf" and "linear"/"logit": list of per-variable specs
    list(col = "age_group", targets = c("18-34" = 0.28, ...)),
    list(col = "sex",       targets = c("M" = 0.49, ...))
  ),
  cells = list(          # for "poststratify" only: list of cell specs
    ...
  ),
  total_n = 1500         # sample size (for converting proportions to counts)
)
```

### `.make_weighted_df(data, weight_col, history = list())`

Internal constructor for `weighted_df`. Sets class and attributes.

```r
.make_weighted_df <- function(data, weight_col, history = list())
# Returns: weighted_df
# Errors if weight_col not in names(data)
```

### `.update_survey_weights(design, new_weights_vec, history_entry)`

Updates `@data[[weight_col]]` in a survey object and appends a history entry
to `@metadata@weighting_history`. Returns a new survey object of the
appropriate class (see Section I output matrix).

```r
.update_survey_weights <- function(design, new_weights_vec, history_entry,
                                    output_class = c("same", "survey_calibrated"))
```

---

## XII. Complete Error and Warning Class Table (Phase 0)

This is the **single source of truth** for all error and warning classes, including
full `cli_abort()`/`cli_warn()` message templates. Per-function sections (VI–IX)
list only class names and trigger conditions; all message text lives here.

### XII.A Common Validation Errors

These are thrown by **all** calibration and nonresponse functions. The `v` bullet
references the calling function generically; implementations substitute the
specific function name.

| Class | Trigger | Message template |
|-------|---------|-----------------|
| `surveyweights_error_unsupported_class` | `data` is not a supported class | `x`: `data` must be a data frame, {.cls weighted_df}, {.cls survey_taylor}, or {.cls survey_calibrated}. `i`: Got {.cls {class(data)[[1]]}}. |
| `surveyweights_error_replicate_not_supported` | `data` is `survey_replicate` | `x`: {.cls survey_replicate} objects are not supported in Phase 0. `i`: Replicate-weight support requires Phase 1. `v`: Use a {.cls survey_taylor} design, or wait for Phase 1. |
| `surveyweights_error_empty_data` | `nrow(data) == 0` | `x`: {.arg data} has 0 rows. `i`: This operation is undefined on empty data. `v`: Ensure {.arg data} has at least one row. |
| `surveyweights_error_weights_not_found` | Named weight column missing from `data` | `x`: Weight column {.field {weights_var}} not found in `data`. `i`: Available columns: {.and {.field {names(data)}}}. `v`: Pass the column name as a bare name, e.g., {.code weights = wt_col}. |
| `surveyweights_error_weights_not_numeric` | Weight column is not numeric | `x`: Weight column {.field {weights_var}} must be numeric. `i`: Got {.cls {class(wt_col)[[1]]}}. `v`: Use {.code as.numeric({.field {weights_var}})} to convert. |
| `surveyweights_error_weights_nonpositive` | Weight column has values ≤ 0 | `x`: Weight column {.field {weights_var}} contains {sum(wt_col <= 0)} non-positive value(s). `i`: All starting weights must be strictly positive (> 0). `v`: Remove or replace non-positive weights before proceeding. |
| `surveyweights_error_weights_na` | Weight column has `NA` values | `x`: Weight column {.field {weights_var}} contains {sum(is.na(wt_col))} NA value(s). `i`: Weights must be fully observed. `v`: Remove rows with missing weights before proceeding. |

### XII.B `calibrate()` Errors

| Class | Message template |
|-------|-----------------|
| `surveyweights_error_variable_not_categorical` | `x`: Calibration variable {.field {var}} is {.cls {class(data[[var]])[[1]]}}. `i`: Phase 0 supports categorical (character or factor) variables only. `v`: Convert to factor or character. Continuous auxiliary variable calibration is not supported in Phase 0. |
| `surveyweights_error_variable_has_na` | `x`: Calibration variable {.field {var}} contains {sum(is.na(data[[var]]))} NA value(s). `i`: NA values in calibration variables are not allowed. `v`: Remove or impute NA values in {.field {var}} before calibrating. |
| `surveyweights_error_population_variable_not_found` | `x`: Population variable {.field {var}} not found in `data`. `i`: Names in `population` must match column names in `data`. `v`: Check spelling: available columns are {.and {.field {names(data)}}}. |
| `surveyweights_error_population_level_missing` | `x`: Level {.val {level}} of variable {.field {var}} is present in `data` but not in `population`. `i`: Every level in the data must have a corresponding population target. `v`: Add {.val {level}} to the {.field {var}} entry in `population`. |
| `surveyweights_error_population_level_extra` | `x`: Level {.val {level}} of variable {.field {var}} is present in `population` but not in `data`. `i`: Population targets for levels absent from the sample are undefined. `v`: Remove {.val {level}} from the {.field {var}} entry in `population`. |
| `surveyweights_error_population_totals_invalid` | **`type = "prop"`:** `x`: Population totals for {.field {var}} sum to {sum_val}, not 1.0. `i`: When {.code type = "prop"}, each variable's targets must sum to 1.0 (within 1e-6 tolerance). `v`: Adjust the values in {.code population${.field {var}}}. **`type = "count"`:** `x`: Population targets for {.field {var}} contain {n_nonpos} non-positive value(s). `i`: When {.code type = "count"}, all targets must be strictly positive (> 0). `v`: Remove or correct non-positive entries in {.code population${.field {var}}}. |
| `surveyweights_error_calibration_not_converged` | `x`: Calibration did not converge after {control$maxit} iterations. `i`: Maximum calibration error: {max_error} (tolerance: {control$epsilon}). `v`: Increase {.code control$maxit}, relax {.code control$epsilon}, or verify population totals are consistent with the sample. |
| `surveyweights_warning_negative_calibrated_weights` | `!`: Linear calibration produced {n_neg} negative calibrated weight(s). `i`: Negative weights can cause invalid variance estimates. `i`: Consider {.code method = "logit"} for bounded weights, or review population totals. |

### XII.C `rake()` Errors

| Class | Message template |
|-------|-----------------|
| `surveyweights_error_margins_format_invalid` | `x`: {.arg margins} must be a named list or a data frame with columns {.field variable}, {.field level}, and {.field target}. `i`: Got {.cls {class(margins)[[1]]}}. `v`: See {.fn rake} documentation for accepted formats. |
| `surveyweights_error_margins_variable_not_found` | `x`: Raking variable {.field {var}} not found in `data`. `i`: Check that all variable names in {.arg margins} exist as columns in `data`. |
| `surveyweights_error_variable_not_categorical` | `x`: Raking variable {.field {var}} is {.cls {class(data[[var]])[[1]]}}. `i`: Phase 0 supports categorical (character or factor) variables only. `v`: Convert to factor or character. Continuous variable raking is not supported in Phase 0. |
| `surveyweights_error_variable_has_na` | `x`: Raking variable {.field {var}} contains {sum(is.na(data[[var]]))} NA value(s). `i`: NA values in raking variables are not allowed. `v`: Remove or impute NA values in {.field {var}} before calling {.fn rake}. |
| `surveyweights_error_population_level_missing` | `x`: Level {.val {level}} of margin {.field {var}} is present in `data` but not in `margins`. `i`: Every level in the data must have a corresponding population target. `v`: Add {.val {level}} to the {.field {var}} entry in `margins`. |
| `surveyweights_error_population_level_extra` | `x`: Level {.val {level}} of margin {.field {var}} is present in `margins` but not in `data`. `i`: Population targets for levels absent from the sample are undefined. `v`: Remove {.val {level}} from the {.field {var}} entry in `margins`. |
| `surveyweights_error_population_totals_invalid` | **`type = "prop"`:** `x`: Population totals for {.field {var}} sum to {sum_val}, not 1.0. `i`: When {.code type = "prop"}, each variable's targets must sum to 1.0 (within 1e-6 tolerance). `v`: Adjust the values in the {.field target} column for {.field {var}}. **`type = "count"`:** `x`: Population targets for {.field {var}} contain {n_nonpos} non-positive value(s). `i`: When {.code type = "count"}, all targets must be strictly positive (> 0). `v`: Remove or correct non-positive entries in the {.field target} column for {.field {var}}. |
| `surveyweights_error_calibration_not_converged` | `x`: Raking did not converge after {control$maxit} full sweeps. `i`: Maximum margin error: {max_error} (tolerance: {control$epsilon}). `v`: Increase {.code control$maxit}, relax {.code control$epsilon}, or verify margin totals are consistent with the sample. |

### XII.D `poststratify()` Errors

| Class | Message template |
|-------|-----------------|
| `surveyweights_error_variable_has_na` | `x`: Strata variable {.field {var}} contains {sum(is.na(data[[var]]))} NA value(s). `i`: NA values in strata variables are not allowed. `v`: Remove or impute NA values in {.field {var}} before calling {.fn poststratify}. |
| `surveyweights_error_population_totals_invalid` | **`type = "prop"`:** `x`: Population targets sum to {sum_val}, not 1.0. `i`: When {.code type = "prop"}, targets in {.arg population} must sum to 1.0 (within 1e-6 tolerance). `v`: Adjust the values in the {.field target} column of {.arg population}. **`type = "count"`:** `x`: Population targets contain {n_nonpos} non-positive value(s). `i`: When {.code type = "count"}, all targets must be strictly positive (> 0). `v`: Remove or correct non-positive entries in the {.field target} column of {.arg population}. |
| `surveyweights_error_population_cell_duplicate` | `x`: Population cell {.val {cell_label}} appears {n} times in `population`. `i`: Each cell combination must appear exactly once in `population`. `v`: Remove duplicate rows for {.val {cell_label}} from `population` before calling {.fn poststratify}. |
| `surveyweights_error_population_cell_missing` | `x`: Cell {.val {cell_label}} is present in `data` but has no matching row in `population`. `i`: Every cell combination in the data must appear in `population`. `v`: Add a row for {.val {cell_label}} to `population`. |
| `surveyweights_error_population_cell_not_in_data` | `x`: Population cell {.val {cell_label}} has no observations in `data`. `i`: Extra cells in the population frame are not allowed — they may indicate a misspecified population. `v`: Remove rows for {.val {cell_label}} from `population` before calling {.fn poststratify}. |
| `surveyweights_error_empty_stratum` | `x`: Stratum cell {.val {cell_label}} has zero weighted count. `i`: Post-stratification requires at least one positive-weight observation in every cell. `v`: Collapse small cells before post-stratifying. |

### XII.E `adjust_nonresponse()` Errors

| Class | Message template |
|-------|-----------------|
| `surveyweights_error_variable_has_na` | `x`: Weighting class variable {.field {var}} contains {sum(is.na(data[[var]]))} NA value(s). `i`: NA values in weighting class variables are not allowed. `v`: Remove or impute NA values in {.field {var}} before calling {.fn adjust_nonresponse}. |
| `surveyweights_error_response_status_not_found` | `x`: Response status column {.field {status_var}} not found in `data`. `i`: Available columns: {.and {.field {names(data)}}}. `v`: Pass the column name as a bare name, e.g., {.code response_status = responded}. |
| `surveyweights_error_response_status_not_binary` | `x`: Response status column {.field {status_var}} must be binary (0/1 or logical). `i`: Got {.cls {class(data[[status_var]])[[1]]}} with values: {.val {unique(data[[status_var]])}}. `i`: Factor columns are not binary regardless of their levels. `v`: Convert to logical ({.code TRUE}/{.code FALSE}) or integer ({.code 0}/{.code 1}) before calling {.fn adjust_nonresponse}. |
| `surveyweights_error_response_status_has_na` | `x`: Response status column {.field {status_var}} contains {sum(is.na(data[[status_var]]))} NA value(s). `i`: The response indicator must be fully observed. `v`: Remove rows with missing response status before calling {.fn adjust_nonresponse}. |
| `surveyweights_error_response_status_all_zero` | `x`: No respondents found in `data`. `i`: All values of {.field {status_var}} are 0 or {.code FALSE}. `v`: Ensure `data` contains both respondents and nonrespondents before adjustment. |
| `surveyweights_error_class_cell_empty` | `x`: Weighting class cell {.val {cell_label}} has no respondents. `i`: Cannot redistribute nonrespondent weights to an empty respondent cell. `v`: Collapse weighting classes to ensure each cell has at least one respondent. |
| `surveyweights_error_propensity_requires_phase2` | `x`: Propensity-based nonresponse adjustment is not available in Phase 0. `i`: This feature requires Phase 2 (v0.3.0). `v`: Use {.code method = "weighting-class"} for now. |
| `surveyweights_warning_class_near_empty` | `!`: Weighting class cell {.val {cell_label}} is sparse ({n} respondent(s), adjustment factor {adj:.2f}×). `i`: Small or high-adjustment cells may produce extreme weights. `i`: Consider collapsing weighting classes or adjusting {.code control$min_cell} / {.code control$max_adjust}. |

### XII.F Diagnostic Errors

| Class | Thrown by | Trigger |
|-------|-----------|---------|
| `surveyweights_error_weights_required` | `effective_sample_size()`, `weight_variability()`, `summarize_weights()` | Plain `data.frame` input with `weights = NULL` |

**Message template:**
`x`: {.arg weights} is required when {.arg x} is a plain data frame. `i`: For {.cls weighted_df} and survey objects, the weight column is detected automatically. `v`: Pass the column name as a bare name, e.g., {.code weights = wt_col}.

### XII.G Warnings

| Class | Thrown by | Trigger | Message template |
|-------|-----------|---------|-----------------|
| `surveyweights_warning_weight_col_dropped` | `dplyr_reconstruct.weighted_df()` | dplyr verb removed or renamed the weight column | `!`: The weight column {.field {weight_col}} was removed by a dplyr operation. `i`: The result has been downgraded from {.cls weighted_df} to a plain tibble. `i`: Use {.fn dplyr::select} to keep {.field {weight_col}}, or re-apply weights if this was intentional. `v`: To rename the weight column, load {.pkg surveytidy} which provides a rename-aware {.fn rename.weighted_df} method. |

---

## XIII. Testing

### Test File Map

| Source file | Test file |
|---|---|
| `R/00-classes.R` | `tests/testthat/test-00-classes.R` |
| `R/02-calibrate.R` | `tests/testthat/test-02-calibrate.R` |
| `R/03-rake.R` | `tests/testthat/test-03-rake.R` |
| `R/04-poststratify.R` | `tests/testthat/test-04-poststratify.R` |
| `R/05-nonresponse.R` | `tests/testthat/test-05-nonresponse.R` |
| `R/06-diagnostics.R` | `tests/testthat/test-06-diagnostics.R` |

Internal utilities (`.calibrate_engine()` etc.) are tested indirectly through
the public API. Direct tests only if indirect coverage is impossible (see
`testing-standards.md §2`).

### `make_surveyweights_data()` — required in `helper-test-data.R`

```r
make_surveyweights_data <- function(n = 500, seed = 42, include_nonrespondents = FALSE) {
  # Returns a plain data.frame with:
  #   - id: integer row identifier
  #   - age_group: character, c("18-34", "35-54", "55+")
  #   - sex: character, c("M", "F")
  #   - education: character, c("<HS", "HS", "College", "Graduate")
  #   - region: character, c("Northeast", "South", "Midwest", "West")
  #   - base_weight: numeric, unequal positive weights (log-normal distribution)
  #   - responded: integer 0/1 (only if include_nonrespondents = TRUE)
  # Realistic variation: unequal weights, slight imbalance across groups
}
```

### `test_invariants()` — required in `helper-test-data.R`

```r
test_invariants <- function(obj) {
  # Applies for weighted_df:
  if (inherits(obj, "weighted_df")) {
    wt_col <- attr(obj, "weight_col")
    testthat::expect_true(is.character(wt_col) && length(wt_col) == 1)
    testthat::expect_true(wt_col %in% names(obj))
    testthat::expect_true(is.numeric(obj[[wt_col]]))
    testthat::expect_true(is.list(attr(obj, "weighting_history")))
  }
  # Applies for survey_calibrated:
  if (S7::S7_inherits(obj, survey_calibrated)) {
    testthat::expect_true(is.character(obj@variables$weights))
    testthat::expect_true(obj@variables$weights %in% names(obj@data))
    testthat::expect_true(is.numeric(obj@data[[obj@variables$weights]]))
    testthat::expect_true(all(obj@data[[obj@variables$weights]] > 0))
  }
}
```

### Standard Error Path Tests

The following test categories apply to `calibrate()`, `rake()`, `poststratify()`,
and `adjust_nonresponse()`. Per-function test lists reference this block as
"Standard error paths (SE-1 through SE-7)" without restating these items. All use
the dual pattern: `expect_error(class = ...)` + `expect_snapshot(error = TRUE, ...)`.

```
# SE-1. Error — unsupported_class (pass a matrix or environment as data)
# SE-2. Error — empty_data (0-row data frame)
# SE-3. Error — replicate_not_supported (survey_replicate input)
# SE-4. Error — weights_not_found (named weight column missing from data)
# SE-5. Error — weights_not_numeric (weight column is character)
# SE-6. Error — weights_nonpositive (weight column has 0 or negative value)
# SE-7. Error — weights_na (weight column has NA)
```

### Per-Function Test Categories

**`calibrate()`:**
```
# 1. Happy path — data.frame input → weighted_df output
#    (uses make_surveyweights_data() which returns multi-variable data;
#     implicitly tests multi-variable population with age_group + sex + education)
# 1b. Happy path — factor-typed variable column (verify factor treated same as character)
# 2. Happy path — survey_taylor input → survey_calibrated output
# 2a. Happy path — multiple variables in population explicitly verified
#     (assert length(population) == 3, all variables calibrated correctly)
# 3. Happy path — weighted_df input → weighted_df output (history accumulates)
# 4. Happy path — survey_calibrated input → survey_calibrated (re-calibration)
# 5. Happy path — method = "logit"
# 6. Happy path — type = "count"
# 7. Numerical correctness — matches survey::calibrate() within 1e-8 tolerance
#    (skip_if_not_installed("survey"), inside the test block)
# 8. Standard error paths (SE-1 through SE-7)
# 9. Error — variable_not_categorical (numeric variable)
# 10. Error — variable_has_na (NA in a variables column)
# 11. Error — population_variable_not_found
# 12. Error — population_level_missing
# 12b. Error — population_level_extra (population has a level absent from data)
# 13. Error — population_totals_invalid (type = "prop", does not sum to 1)
# 13b. Error — population_totals_invalid (type = "count", target ≤ 0)
# 14. Error — calibration_not_converged (inconsistent population)
# 15. Warning — negative_calibrated_weights (linear method, extreme targets)
# 16. Edge — single-row data frame
# 17. Edge — single variable in population
# 18. History — weighting_history has correct structure after calibration
# 19. History — step number increments correctly across chained calls
# Note: calibrate() → rake() chain test (item 19b) is in test-03-rake.R
```

**`rake()`:**
```
# 1. Happy path — data.frame input → weighted_df output
# 1b. Happy path — factor-typed margin variable (verify factor treated same as character)
# 2. Happy path — survey_taylor input → survey_calibrated output
# 2a. Happy path — multiple margins explicitly verified
#     (assert length(margins) == 3, all variables calibrated correctly)
# 3. Happy path — weighted_df input → weighted_df output (history accumulates)
# 4. Happy path — survey_calibrated input → survey_calibrated (re-raking)
# 5. Happy path — type = "count"
# 6. Happy path — margins as named list
# 7. Happy path — margins as long data frame
# 8. Happy path — mixed format (list with data.frame element)
# 9. Numerical correctness — matches survey::rake() within 1e-8 tolerance
#    (skip_if_not_installed("survey"), inside the test block)
# 10. Standard error paths (SE-1 through SE-7)
# 11. Error — margins_format_invalid (bad class)
# 12. Error — margins_format_invalid (data.frame missing columns)
# 13. Error — margins_variable_not_found
# 14. Error — variable_not_categorical (numeric margins variable)
# 15. Error — variable_has_na (NA in a margins variable)
# 15b. Error — population_level_missing (data level absent from margins)
# 15c. Error — population_level_extra (margins has a level absent from data)
# 16. Error — population_totals_invalid (type = "prop" targets do not sum to 1)
# 16b. Error — population_totals_invalid (type = "count", target ≤ 0)
# 17. Error — calibration_not_converged (inconsistent margins)
# 18. Edge — single margin
# 19. History — weighting_history has correct structure after raking
# 20. History — step number increments correctly across chained calls
# 20b. Integration — calibrate() → rake() chain produces two-entry weighting_history
#      with step numbers 1 and 2 and correct operation labels
#      (placed here since rake() is the chaining consumer; requires PR 5 to be merged)
```

**`poststratify()`:**
```
# 1–4. Happy paths (df, weighted_df, survey_taylor, survey_calibrated)
# 5. Happy path — numeric strata column (integer age; verifies no categorical restriction)
# 6. Numerical correctness — matches survey::postStratify() within 1e-8
#    (skip_if_not_installed("survey"), inside the test block)
# 7. Standard error paths (SE-1 through SE-7)
# 8. Error — variable_has_na (NA in a strata variable)
# 8b. Error — population_totals_invalid (type = "prop" targets do not sum to 1)
# 8c. Error — population_totals_invalid (type = "count", target ≤ 0)
# 8d. Error — population_cell_duplicate (same cell combination appears twice in population)
# 9. Error — population_cell_missing (data cell not in population)
# 10. Error — population_cell_not_in_data (population cell absent from data)
# 11. Error — empty_stratum
# 12. Edge — single stratum variable
# 13. Edge — type = "prop"
# 14. History — weighting_history has correct structure after post-stratification
# 15. History — step number increments correctly across chained calls
```

**`adjust_nonresponse()`:**
```
# 1. Happy path — data.frame input → weighted_df (respondents only returned)
# 2. Happy path — survey_taylor input → survey_taylor (same class)
# 2b. Happy path — weighted_df input → weighted_df output
# 2c. Happy path — survey_calibrated input → survey_calibrated output
# 3. Happy path — by = NULL (global redistribution)
# 4. Happy path — by = c(age_group, sex) (within-class redistribution)
# 5. Weight conservation — sum of weights before == sum of respondent weights after
# 5b. Numerical correctness — hand-calculation verification:
#     construct a 2-class example (class A: 10 respondents w=1, 2 nonrespondents w=1;
#     class B: 8 respondents w=1, 0 nonrespondents w=1). Verify adjusted weights
#     equal w * (sum_all / sum_respondents) per cell within 1e-10 tolerance.
#     Note: no reference R package provides weighting-class nonresponse adjustment;
#     correctness is validated by weight conservation and hand calculation.
# 6. Standard error paths (SE-1 through SE-7)
# 7. Error — variable_has_na (NA in a by variable)
# 8. Error — response_status_has_na (NA in response_status column)
# 9. Error — response_status_not_found
# 10. Error — response_status_not_binary (integer/character column with wrong values)
# 10b. Error — response_status_not_binary (factor column; factors are not binary)
# 11. Error — response_status_all_zero
# 12. Error — class_cell_empty (by variable creates empty respondent cell)
# 13. Error — propensity_requires_phase2
# 14. Warning — class_near_empty triggered by low count (< 20 respondents)
# 14b. Warning — class_near_empty triggered by high adjustment factor (> 2.0)
# 15. Edge — all respondents (no nonrespondents to redistribute)
# 16. Edge — single weighting class (equivalent to global)
# 17. History entry has correct operation = "nonresponse_weighting_class"
```

**`effective_sample_size()`, `weight_variability()`, `summarize_weights()`:**
```
# 1. Correct value vs hand calculation (data.frame input)
# 2. Auto-detected weights for weighted_df input
# 3. Auto-detected weights for survey_calibrated input
# 3b. Auto-detected weights for survey_taylor input
# 4. summarize_weights — by = NULL returns single-row tibble
# 5. summarize_weights — by grouping returns correct number of rows
# 5b. Error — unsupported_class (pass a matrix or list)
# 6. Error — weights_required (plain df, no weights arg)
# 7. Error — weights_not_found
# 7b. Error — weights_not_numeric (pass a character-type weight column)
# 8. All columns present in summarize_weights() output
```

**`weighted_df` class and `survey_calibrated` class:**
```
# 1. dplyr_reconstruct — select() preserving weight col → weighted_df returned
# 2. dplyr_reconstruct — select(-weight_col) → plain tibble + warning
# 3. Warning class is surveyweights_warning_weight_col_dropped
# 4. print.weighted_df — snapshot test (output matches verbatim example in Section IV)
# 5. History is empty on initial creation
# 6. Class vector is correct: c("weighted_df", "tbl_df", "tbl", "data.frame")
# 7. survey_calibrated print — snapshot test (output matches verbatim example in Section V)
# 8. survey_calibrated S7 validator — rejects non-positive weights (class= only, no snapshot)
# 9. survey_calibrated S7 validator — rejects NA in weight column (class= only, no snapshot)
```

All error path tests use the dual pattern from `testing-standards.md`:
`expect_error(class = ...)` + `expect_snapshot(error = TRUE, ...)`.

S7 validator errors (tests #8 and #9 above) use `class=` only — no snapshot —
because those messages are not CLI-formatted.

All snapshot failures block PRs.

---

## XIV. Quality Gates

"Done" for Phase 0 means ALL of the following are true and verifiable:

- [ ] `devtools::check()` passes: 0 errors, 0 warnings, ≤2 notes
- [ ] `covr::package_coverage()` ≥ 98% line coverage
- [ ] Every exported function has `@return`, runnable `@examples`, `@family`
- [ ] Every `cli_abort()` and `cli_warn()` has a `class =` argument
- [ ] All error classes in Section XII are in `plans/error-messages.md`
- [ ] All error classes have a `test_that()` block with the dual pattern
- [ ] All snapshot tests pass (`testthat::snapshot_review()` clean)
- [ ] `air::format_package()` produces no diffs
- [ ] `test_invariants()` is called in every constructor test block
- [ ] `make_surveyweights_data()` is used in all non-edge-case test blocks
- [ ] `calibrate()`, `rake()`, `poststratify()` have numerical correctness tests
  against `survey` package (each with `skip_if_not_installed("survey")` inside
  the relevant `test_that()` block)
- [ ] `R/vendor/calibrate-greg.R` and `R/vendor/calibrate-ipf.R` exist and carry
  attribution comment blocks (source package, version, author, license, URL)
- [ ] `VENDORED.md` is created and attributes all vendored code
- [ ] Reference implementation for `adjust_nonresponse()` is identified and documented
  in `VENDORED.md` (or a hand-calculation validation methodology is documented)
- [ ] `surveyweights-conventions.md` stub is filled in with Phase 0 conventions
- [ ] `testing-surveyweights.md` stub is filled in with `test_invariants()` definition
- [ ] Surveycore prerequisite PR is merged before this branch opens

---

## Open GAPs (summary)

| # | Section | Description |
|---|---------|-------------|
| 1 | II, V | Exact `survey_base` property names and `survey_calibrated` inheritance path — verify against surveycore source |
| 2 | III | Exact accessor name and API for `@metadata@weighting_history` in surveycore |
| 3 | III | Confirm `@variables$weights` is a character scalar (column name) in surveycore |
| 4 | II.b | Confirm minimum surveycore version once prerequisite PR is merged (`0.1.0` is placeholder) |
| 5 | II.c | Identify reference implementation for `adjust_nonresponse()` — evaluate `anesrake`, `WeightIt`, or document hand-calculation methodology |
| 6 | XI | `.calibrate_engine()` internal `calibration_spec` format may need refinement during implementation |
