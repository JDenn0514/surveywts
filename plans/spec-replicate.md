# Replicate Spec: Replicate Weight Generation (v0.2.0)

**Version:** 1.0
**Date:** 2026-03-20
**Status:** Draft — §XI questions resolved (see `plans/decisions-replicate.md`); ready for Stage 2/3 review
**Supersedes:** `plans/future/replicate/spec-replicate.md`
**Branch identifier:** `replicate`

---

## Document Purpose

This document is the single source of truth for Phase 1 of surveywts. It specifies
every exported function, its delegation backend, error classes, and test expectations
required to ship v0.2.0.

**Key architectural change from the prior draft:** Phase 1 delegates all replicate
weight computation to the `survey` and `svrep` packages. surveywts provides a
modern, S7-based API with consistent error handling and tidy UX. The spec focuses
on API surface and user experience, not algorithm implementation.

This spec does NOT repeat rules defined in:
- `code-style.md` — formatting, pipe, error structure, S7 patterns, argument order
- `r-package-conventions.md` — `::` usage, NAMESPACE, roxygen2, export policy
- `surveywts-conventions.md` — error/warning prefixes, return visibility
- `testing-standards.md` — `test_that()` scope, coverage targets, assertion patterns

Those rules apply by reference.

---

## I. Scope

### Deliverables (v0.2.0)

| Component | Type | Exported? |
|-----------|------|-----------|
| `create_bootstrap_weights()` | Function | Yes |
| `create_jackknife_weights()` | Function | Yes |
| `create_brr_weights()` | Function | Yes |
| `create_gen_boot_weights()` | Function | Yes |
| `create_gen_rep_weights()` | Function | Yes |
| `create_sdr_weights()` | Function | Yes |
| `create_replicate_weights()` | Function (dispatcher) | Yes |
| `as_taylor_design()` | Function | Yes |

### Non-Deliverables (Phase 1)

- Variance estimation or analysis functions — Phase 1 only creates replicate weights
- `trim_weights()`, `stabilize_weights()` (Phase 4)
- `calibrate_to_survey()`, `calibrate_to_estimate()` (Phase 2)
- Re-calibrated bootstrap for `survey_nonprob` (Phase 2.5) — Phase 1 provides
  simple bootstrap only (see §XI, Q4)
- `create_*_weights()` accepting `weighted_df` or plain `data.frame` input
- Removal of `surveywts_error_replicate_not_supported` stubs in Phase 0
  calibration/nonresponse functions — those stubs remain until a future phase
  specifies calibration behavior for replicate designs

### Input/Output Class Matrix

| Input class | Output | Notes |
|-------------|--------|-------|
| `survey_taylor` | `survey_replicate` | Primary use case; all methods supported |
| `survey_nonprob` | Method-dependent — see §XI, Q4 | Simple resampling only; no re-calibration |
| `survey_replicate` | Error: `surveywts_error_already_replicate` | |
| `data.frame`, `weighted_df` | Error: `surveywts_error_not_survey_design` | |
| Any other | Error: `surveywts_error_unsupported_class` | |

---

## II. Architecture

### §II.a Delegation Strategy

All replicate weight computation is delegated to `survey` and `svrep`. Each
`create_*_weights()` function is a thin wrapper that:

1. Validates input (surveywts error classes with CLI messages)
2. Converts surveycore S7 object to survey package object via `surveycore::as_svydesign()`
3. Calls the appropriate `survey` or `svrep` function
4. Converts the result back to surveycore via `surveycore::from_svydesign()`
5. Preserves metadata from the input object (variable labels, weighting history)
6. Returns a `survey_replicate`

```r
# Pseudocode — core conversion pipeline (shared internal helper)
.convert_and_call <- function(data, backend_fn, ...) {
  svydesign_obj <- surveycore::as_svydesign(data)
  svyrep_obj <- backend_fn(svydesign_obj, ...)
  result <- surveycore::from_svydesign(svyrep_obj)
  result@metadata <- data@metadata
  result
}
```

**Metadata note:** The survey package has no metadata system. Converting to
`svydesign` and back loses variable labels, weighting history, etc.
`create_*_weights()` manually copies `@metadata` from input to output after
the round-trip conversion.

### §II.b Backend Mapping

| surveywts function | Backend function | Package |
|---|---|---|
| `create_bootstrap_weights()` | `svrep::as_bootstrap_design()` | svrep |
| `create_jackknife_weights(type = "delete-1")` | `survey::as.svrepdesign(type = "JK1"/"JKn")` | survey |
| `create_jackknife_weights(type = "random-groups")` | `svrep::as_random_group_jackknife_design()` | svrep |
| `create_brr_weights(rho = 0)` | `survey::as.svrepdesign(type = "BRR")` | survey |
| `create_brr_weights(rho > 0)` | `survey::as.svrepdesign(type = "Fay", fay.rho = rho)` | survey |
| `create_gen_boot_weights()` | `svrep::as_gen_boot_design()` | svrep |
| `create_gen_rep_weights()` | `svrep::as_fays_gen_rep_design()` | svrep |
| `create_sdr_weights()` | `svrep::as_sdr_design()` | svrep |

### §II.c Package Dependencies

**New `Imports` for Phase 1:**

| Package | Minimum version | Why |
|---|---|---|
| `svrep` | `(>= 0.6.0)` | Bootstrap (RWYB, Antal-Tille, Preston, Canty-Davison), generalized bootstrap, generalized replication, SDR, random-group jackknife |

`survey` is already in `Imports` from Phase 0 (BRR, Fay BRR, delete-1 jackknife).

### §II.d Source File Organization

```
R/
├── replicate-weights.R     # create_bootstrap_weights(), create_jackknife_weights(),
│                            # create_brr_weights(), create_gen_boot_weights(),
│                            # create_gen_rep_weights(), create_sdr_weights(),
│                            # plus shared internal helpers
├── replicate-dispatch.R    # create_replicate_weights(), as_taylor_design()
└── [existing Phase 0 files unchanged]
```

### §II.e Shared Helpers

Phase 1 adds these internal helpers to `R/replicate-weights.R`:

| Helper | Description |
|---|---|
| `.validate_replicate_input()` | Input class check — errors for `data.frame`, `weighted_df`, `survey_replicate`, unsupported classes |
| `.validate_replicates_arg()` | Validates `replicates` is a positive integer ≥ 2 |
| `.convert_and_call()` | Core pipeline: `as_svydesign()` → backend → `from_svydesign()` → preserve metadata |

### §II.f Validation Order

All `create_*_weights()` functions validate in this order:
1. Input class check (surveywts error classes)
2. `replicates` argument validity (where applicable)
3. Method-specific requirements (e.g., paired PSUs for BRR, `rho` range)

Validation happens in surveywts before calling the backend. This ensures
consistent, well-formatted CLI error messages regardless of which backend
would eventually throw.

---

## III. `create_bootstrap_weights()`

### Signature

```r
create_bootstrap_weights(
  data,
  replicates = 500L,
  type = c("Rao-Wu-Yue-Beaumont", "Rao-Wu", "Antal-Tille",
           "Preston", "Canty-Davison"),
  mse = TRUE
)
```

### Argument Table

| Argument | Type | Default | Description |
|----------|------|---------|-------------|
| `data` | `survey_taylor` or `survey_nonprob` | — | Input design |
| `replicates` | `integer(1)`, ≥ 2 | `500L` | Number of bootstrap replicates |
| `type` | `character(1)` | `"Rao-Wu-Yue-Beaumont"` | Bootstrap variant. See §XI, Q1 for roster discussion |
| `mse` | `logical(1)` | `TRUE` | If `TRUE`, variance estimated as deviation from full-sample estimate. If `FALSE`, deviation from replicate mean (can underestimate for biased estimators) |

### Output Contract

Returns `survey_replicate` with:
- `@data`: original columns + `replicates` new replicate weight columns
- `@variables$weights`: same weight column as input
- `@variables$repweights`: character vector of replicate column names
- `@variables$type`: `"bootstrap"`
- `@variables$mse`: value of `mse` argument

### Backend

`svrep::as_bootstrap_design(design, type = type, replicates = replicates, mse = mse)`

### Error Table

| Class | Condition |
|-------|-----------|
| `surveywts_error_not_survey_design` | `data` is `data.frame` or `weighted_df` |
| `surveywts_error_unsupported_class` | `data` is not a recognized survey class |
| `surveywts_error_already_replicate` | `data` is already `survey_replicate` |
| `surveywts_error_replicates_not_positive` | `replicates` is not a positive integer ≥ 2 |

---

## IV. `create_jackknife_weights()`

### Signature

```r
create_jackknife_weights(
  data,
  type = c("delete-1", "random-groups"),
  replicates = NULL,
  mse = TRUE
)
```

### Argument Table

| Argument | Type | Default | Description |
|----------|------|---------|-------------|
| `data` | `survey_taylor` or `survey_nonprob` | — | Input design |
| `type` | `character(1)` | `"delete-1"` | `"delete-1"`: one replicate per PSU; auto-selects JK1 (unstratified) or JKn (stratified). `"random-groups"`: PSUs randomly divided into `replicates` groups |
| `replicates` | `integer(1)` ≥ 2, or `NULL` | `NULL` | Number of groups for `type = "random-groups"`. Required for random-groups; ignored for delete-1 |
| `mse` | `logical(1)` | `TRUE` | Variance deviation method |

### Output Contract

Returns `survey_replicate` with:
- `@variables$type`: `"JK1"` for unstratified delete-1; `"JKn"` for stratified
  delete-1 or random-groups
- For delete-1: `n_rep` = total number of PSUs across all strata
- For random-groups: `n_rep` = `replicates`

### Backend

- `type = "delete-1"`, unstratified: `survey::as.svrepdesign(design, type = "JK1", mse = mse)`
- `type = "delete-1"`, stratified: `survey::as.svrepdesign(design, type = "JKn", mse = mse)`
- `type = "random-groups"`: `svrep::as_random_group_jackknife_design(design, replicates = replicates, mse = mse)`

Auto-detection: stratification is determined by checking whether the input
design has strata (`data@variables$strata` is non-NULL).

### Error Table

| Class | Condition |
|-------|-----------|
| `surveywts_error_not_survey_design` | `data` is `data.frame` / `weighted_df` |
| `surveywts_error_unsupported_class` | Unrecognized class |
| `surveywts_error_already_replicate` | Already `survey_replicate` |
| `surveywts_error_replicates_required_for_jkn` | `type = "random-groups"` and `replicates` is `NULL` |
| `surveywts_error_replicates_not_positive` | `replicates` ≤ 1 or not integer (when required) |

---

## V. `create_brr_weights()`

### Signature

```r
create_brr_weights(
  data,
  rho = 0,
  mse = TRUE
)
```

### Argument Table

| Argument | Type | Default | Description |
|----------|------|---------|-------------|
| `data` | `survey_taylor` | — | Input design. Must have exactly 2 PSUs per stratum (paired design). `survey_nonprob` is rejected — BRR requires a paired design structure |
| `rho` | `numeric(1)`, 0 ≤ rho < 1 | `0` | Fay damping coefficient. `rho = 0`: standard BRR (factors 0 and 2). `rho > 0`: Fay's BRR variant (factors `rho` and `2 - rho`). Higher `rho` produces more stable but less efficient variance estimates |
| `mse` | `logical(1)` | `TRUE` | Variance deviation method |

### Output Contract

Returns `survey_replicate` with:
- `@variables$type`: `"BRR"` if `rho == 0`; `"Fay"` if `rho > 0`
- `n_rep` determined by Hadamard matrix sizing (smallest valid order ≥ number
  of strata); handled automatically by the survey backend
- `@variables$scale`: `1 / (n_rep * (1 - rho)^2)`

### Backend

- `rho == 0`: `survey::as.svrepdesign(design, type = "BRR", mse = mse)`
- `rho > 0`: `survey::as.svrepdesign(design, type = "Fay", fay.rho = rho, mse = mse)`

### Error Table

| Class | Condition |
|-------|-----------|
| `surveywts_error_not_survey_design` | `data` is `data.frame` / `weighted_df` |
| `surveywts_error_unsupported_class` | Unrecognized class |
| `surveywts_error_already_replicate` | Already `survey_replicate` |
| `surveywts_error_brr_requires_paired_design` | Any stratum has ≠ 2 PSUs, or input is `survey_nonprob` |
| `surveywts_error_brr_rho_invalid` | `rho < 0` or `rho ≥ 1` |

---

## VI. `create_gen_boot_weights()`

### Signature

```r
create_gen_boot_weights(
  data,
  replicates = 500L,
  variance_estimator = "SD1",
  tau = 1,
  aux_var_names = NULL,
  mse = TRUE
)
```

### Argument Table

| Argument | Type | Default | Description |
|----------|------|---------|-------------|
| `data` | `survey_taylor` | — | Input design |
| `replicates` | `integer(1)`, ≥ 2 | `500L` | Number of bootstrap replicates |
| `variance_estimator` | `character(1)` | `"SD1"` | Target variance estimator. See §VI.a for options |
| `tau` | `numeric(1)` or `"auto"` | `1` | Rescaling constant to prevent negative replicate weights via the transformation `(factor + tau - 1) / tau`. `"auto"` computes the minimum value keeping all adjustment factors ≥ 0.01 |
| `aux_var_names` | `character` or `NULL` | `NULL` | Auxiliary variable names. Required when `variance_estimator = "Deville-Tille"`; ignored otherwise |
| `mse` | `logical(1)` | `TRUE` | Variance deviation method |

### §VI.a Variance Estimator Options

Shared by `create_gen_boot_weights()` and `create_gen_rep_weights()`. See §XI,
Q3 for the decision on which estimators to expose. The full svrep roster:

| Estimator | Use case | Requires `aux_var_names`? |
|-----------|----------|--------------------------|
| `"SD1"` | Successive differences (non-circular); systematic sampling | No |
| `"SD2"` | Successive differences (circular); basis of SDR | No |
| `"Horvitz-Thompson"` | General unequal-probability; needs 2nd-order inclusion probs | No |
| `"Yates-Grundy"` | General unequal-probability; needs 2nd-order inclusion probs | No |
| `"Poisson Horvitz-Thompson"` | Poisson sampling | No |
| `"Stratified Multistage SRS"` | Standard stratified multistage estimator | No |
| `"Ultimate Cluster"` | First-stage cluster totals within strata | No |
| `"Deville-1"` | Unequal-probability without replacement | No |
| `"Deville-2"` | Unequal-probability without replacement | No |
| `"Deville-Tille"` | Balanced sampling designs | **Yes** |
| `"BOSB"` | Kernel-based for systematic/finely stratified designs | No |
| `"Beaumont-Emond"` | Multistage unequal-probability without replacement | No |

### Output Contract

Returns `survey_replicate` with:
- `@variables$type`: `"bootstrap"`
- `@variables$scale`: `tau^2 / replicates` when `tau != 1`; `1 / replicates`
  otherwise

### Backend

`svrep::as_gen_boot_design(design, variance_estimator = variance_estimator, replicates = replicates, tau = tau, aux_var_names = aux_var_names, mse = mse)`

### Error Table

| Class | Condition |
|-------|-----------|
| `surveywts_error_not_survey_design` | `data` is `data.frame` / `weighted_df` |
| `surveywts_error_unsupported_class` | Unrecognized class |
| `surveywts_error_already_replicate` | Already `survey_replicate` |
| `surveywts_error_replicates_not_positive` | `replicates` ≤ 1 or not integer |
| `surveywts_error_variance_estimator_requires_aux` | `variance_estimator = "Deville-Tille"` but `aux_var_names` is `NULL` |

---

## VII. `create_gen_rep_weights()`

### Signature

```r
create_gen_rep_weights(
  data,
  variance_estimator = "SD2",
  max_replicates = Inf,
  balanced = TRUE,
  aux_var_names = NULL,
  mse = TRUE
)
```

### Argument Table

| Argument | Type | Default | Description |
|----------|------|---------|-------------|
| `data` | `survey_taylor` | — | Input design |
| `variance_estimator` | `character(1)` | `"SD2"` | Target variance estimator. Same options as §VI.a |
| `max_replicates` | `numeric(1)` | `Inf` | Maximum number of replicates. If `Inf`, uses the natural count (rank of quadratic form matrix) |
| `balanced` | `logical(1)` | `TRUE` | If `TRUE`, replicates contribute equally to variance estimates (may slightly increase replicate count) |
| `aux_var_names` | `character` or `NULL` | `NULL` | Auxiliary variable names. Required for `"Deville-Tille"` |
| `mse` | `logical(1)` | `TRUE` | Variance deviation method |

### Output Contract

Returns `survey_replicate` with deterministic replicate weights (no randomness,
unlike bootstrap methods). Number of replicates determined by the rank of the
quadratic form matrix, bounded by `max_replicates`.

### Backend

`svrep::as_fays_gen_rep_design(design, variance_estimator = variance_estimator, max_replicates = max_replicates, balanced = balanced, aux_var_names = aux_var_names, mse = mse)`

### Error Table

| Class | Condition |
|-------|-----------|
| `surveywts_error_not_survey_design` | `data` is `data.frame` / `weighted_df` |
| `surveywts_error_unsupported_class` | Unrecognized class |
| `surveywts_error_already_replicate` | Already `survey_replicate` |
| `surveywts_error_variance_estimator_requires_aux` | `variance_estimator = "Deville-Tille"` but `aux_var_names` is `NULL` |

---

## VIII. `create_sdr_weights()`

### Signature

```r
create_sdr_weights(
  data,
  replicates = 100L,
  sort_var = NULL,
  mse = TRUE
)
```

### Argument Table

| Argument | Type | Default | Description |
|----------|------|---------|-------------|
| `data` | `survey_taylor` | — | Input design. PSUs must be in systematic selection order (or use `sort_var`) |
| `replicates` | `integer(1)`, ≥ 4 | `100L` | Target number of SDR replicates. Actual count may be slightly larger (determined by Hadamard matrix sizing in the backend). Typical range: 80–200; the ACS uses 80 |
| `sort_var` | `character(1)` or `NULL` | `NULL` | Column name in `data@data` giving systematic selection order. If `NULL`, row order is assumed to reflect selection order. Sorting happens within strata if present |
| `mse` | `logical(1)` | `TRUE` | Variance deviation method |

### Output Contract

Returns `survey_replicate` with:
- `@variables$type`: `"successive-difference"`
- `@variables$scale`: `4 / n_rep`

### Backend

`svrep::as_sdr_design(design, replicates = replicates, sort_variable = sort_var, mse = mse)`

Note the argument name translation: surveywts uses `sort_var`; svrep uses
`sort_variable`.

### Error Table

| Class | Condition |
|-------|-----------|
| `surveywts_error_not_survey_design` | `data` is `data.frame` / `weighted_df` |
| `surveywts_error_unsupported_class` | Unrecognized class |
| `surveywts_error_already_replicate` | Already `survey_replicate` |
| `surveywts_error_replicates_not_positive` | `replicates` ≤ 1 or not integer |
| `surveywts_error_sort_var_has_na` | `sort_var` column contains `NA` |

---

## IX. `create_replicate_weights()` (Dispatcher)

### Signature

```r
create_replicate_weights(
  data,
  method = c("bootstrap", "jackknife", "brr", "gen-boot", "gen-rep", "sdr"),
  ...
)
```

### Behavior

Pure dispatcher. Zero validation or default-setting logic beyond
`rlang::arg_match(method)`. All validation, defaults, and error messages
belong in the individual functions.

```r
create_replicate_weights <- function(
  data,
  method = c("bootstrap", "jackknife", "brr", "gen-boot", "gen-rep", "sdr"),
  ...
) {
  method <- rlang::arg_match(method)
  switch(method,
    bootstrap = create_bootstrap_weights(data, ...),
    jackknife = create_jackknife_weights(data, ...),
    brr       = create_brr_weights(data, ...),
    "gen-boot" = create_gen_boot_weights(data, ...),
    "gen-rep"  = create_gen_rep_weights(data, ...),
    sdr       = create_sdr_weights(data, ...)
  )
}
```

### Error Table

| Class | Condition |
|-------|-----------|
| Standard `rlang::arg_match()` error | Invalid `method` string |
| Plus all errors from dispatched function | Propagated as-is |

---

## X. `as_taylor_design()`

### Signature

```r
as_taylor_design(data)
```

### Argument Table

| Argument | Type | Default | Description |
|----------|------|---------|-------------|
| `data` | `survey_replicate` or `survey_taylor` | — | Input design |

### Output Contract

Returns a `survey_taylor` reconstructed from the replicate design. Replicate
weight columns are dropped from `@data`.

- **If input is `survey_taylor`:** Returns `data` unchanged, with warning
  `surveywts_warning_already_taylor`.
- **If input is `survey_replicate`:** Converts to `survey_taylor`, emitting
  `surveywts_warning_taylor_loses_variance`. See §XI, Q7 for how the original
  Taylor structure is recovered.

### Backend

> Depends on §XI, Q7 resolution. Likely approach: read stored Taylor structure
> from the `@metadata@weighting_history` entry created by `create_*_weights()`,
> then reconstruct via `surveycore::as_survey()`.

### Error/Warning Table

| Class | Condition |
|-------|-----------|
| `surveywts_warning_already_taylor` | Input is `survey_taylor`; function is a no-op |
| `surveywts_warning_taylor_loses_variance` | Converting drops replicate weights |
| `surveywts_error_unsupported_class` | Input is not `survey_replicate` or `survey_taylor` |
| `surveywts_error_no_taylor_structure` | No stored Taylor structure found and cannot reconstruct |

---

## XI. API Design Questions

These questions must be resolved before implementation begins. Each question
presents options with rationale. Resolutions go in `plans/decisions-replicate.md`.

---

### Q1: Bootstrap Type Roster

Which bootstrap variants should `create_bootstrap_weights(type = ...)` support?

**svrep offers 5 types:**

| Type | Best for | Notes |
|------|----------|-------|
| `"Rao-Wu-Yue-Beaumont"` | General-purpose; multistage, PPS, FPC | Default in svrep; most versatile |
| `"Rao-Wu"` | Simple designs; SRS within strata | Simpler; no unequal probabilities |
| `"Antal-Tille"` | Unequal probability, single-stage | Doubled half-sample method |
| `"Preston"` | Multistage with significant sampling fractions | True multistage handling |
| `"Canty-Davison"` | Single-stage with arbitrary fractions | Most restrictive applicability |

**Additionally, `survey` offers:**
- `"subbootstrap"` (McCarthy & Snowden) — draws n-1 without replacement; simple
  but niche

**Options:**
- **A:** All 5 svrep types (no subbootstrap)
- **B:** All 5 svrep types + subbootstrap from survey (6 total)
- **C:** Curate to 2-3 most useful: RWYB, Rao-Wu, Preston

**Recommendation:** Option A. The 5 svrep types cover all common designs.
Subbootstrap is niche; users who need it can call `survey::as.svrepdesign()`
directly.

---

### Q2: Type and Estimator Naming

Should surveywts use svrep's exact string names, or provide shorter aliases?

**Examples of svrep names:**
- `"Rao-Wu-Yue-Beaumont"` (bootstrap type)
- `"Stratified Multistage SRS"` (variance estimator)
- `"Poisson Horvitz-Thompson"` (variance estimator)

**Options:**
- **A:** Use svrep names exactly — consistent with documentation and literature;
  no translation layer to maintain
- **B:** Provide shorter aliases alongside svrep names — e.g., `"rwyb"` maps to
  `"Rao-Wu-Yue-Beaumont"`, accept both forms
- **C:** Use only short aliases — cleaner API but diverges from literature

**Recommendation:** Option A. The full names match the statistical literature
and svrep documentation. Users who know enough to pick a specific variant will
recognize the canonical names. Aliases add a translation layer that can cause
confusion and must be maintained.

---

### Q3: Variance Estimator Roster

`create_gen_boot_weights()` and `create_gen_rep_weights()` both accept a
`variance_estimator` argument. svrep supports 12 estimators (see §VI.a).
Which should surveywts expose?

**Options:**
- **A:** All 12 — complete coverage; they are passthrough strings to svrep
  with zero implementation cost
- **B:** Curate to the 6 most common: SD1, SD2, Horvitz-Thompson,
  Yates-Grundy, Stratified Multistage SRS, Ultimate Cluster
- **C:** All 12, but document with two tiers: "common" (with full examples
  in roxygen) and "advanced" (listed with one-line descriptions)

**Recommendation:** Option A. No implementation cost to supporting all 12.
Document the 4-5 most common ones with examples in roxygen; list the rest
with one-line descriptions.

---

### Q4: `survey_nonprob` Input Policy

Which `create_*_weights()` functions should accept `survey_nonprob` input?

`survey_nonprob` has no PSU IDs, no strata — only weights. Resampling treats
each observation as its own sampling unit (simple bootstrap / leave-one-out
jackknife). The output is a `survey_replicate` with resampled weights.

> **Note:** This is simple resampling only. Re-calibrated bootstrap (Rao &
> Tarozzi 2004), where each replicate re-applies the original calibration
> adjustments, is Phase 2.5 scope.

**Options:**
- **A:** Bootstrap + jackknife only (natural methods for unit-level resampling)
- **B:** Bootstrap + jackknife + SDR (SDR can work with ordered observations)
- **C:** All methods that don't require paired strata (everything except BRR)

**Recommendation:** Option A. Bootstrap and delete-1 jackknife are the
standard methods for non-probability samples. SDR, gen-boot, and gen-rep
assume design structure that `survey_nonprob` doesn't have.

---

### Q5: BRR Non-Paired Strata Handling

The survey package's BRR supports strata with ≠ 2 PSUs via `small` and `large`
arguments:
- `small`: `"fail"` (default), `"split"`, `"merge"` — for strata with < 2 PSUs
- `large`: `"split"` (default), `"merge"`, `"fail"` — for strata with > 2 PSUs

Should `create_brr_weights()` expose these?

**Options:**
- **A:** Error on non-paired designs — direct users to `create_gen_rep_weights()`
  or `create_gen_boot_weights()` instead (with a helpful error message)
- **B:** Expose `small` and `large` arguments, mirroring survey's API
- **C:** Handle internally with sensible defaults (e.g., `small = "merge"`,
  `large = "split"`) without exposing the arguments

**Recommendation:** Option A. BRR is designed for paired-PSU designs. Handling
non-paired designs is a workaround, not the intended use. The generalized
methods are the correct tool for arbitrary designs. A clear error message
suggesting alternatives is better UX than exposing workaround arguments.

---

### Q6: Jackknife Configuration

svrep's `as_random_group_jackknife_design()` exposes `adj_method` and
`scale_method` (2 options each), yielding the GJ2 and DAGJK variants. It also
exposes `var_strat`, `var_strat_frac`, and `sort_var` for variance strata.

For delete-1 jackknife, survey handles single-PSU strata via
`options("survey.lonely.psu")` with 5 strategies (`"fail"`, `"remove"`,
`"certainty"`, `"average"`, `"adjust"`).

Should surveywts expose any of these?

**Options:**
- **A:** Hide all — use backend defaults for both types. Delete-1 uses
  survey's current `survey.lonely.psu` option setting; random-groups uses
  svrep's `"variance-stratum-psus"` defaults
- **B:** Expose `adj_method` / `scale_method` for random-groups; hide
  single-PSU strategy for delete-1
- **C:** Expose everything — full control for both variants

**Recommendation:** Option A for Phase 1. The defaults are the recommended
settings in the methodology literature. Advanced users who need GJ2 or DAGJK
configuration can call svrep directly. Can be exposed in a future phase if
demand warrants it.

---

### Q7: Taylor Round-Trip Storage

`as_taylor_design()` converts a `survey_replicate` back to `survey_taylor`.
This requires the original Taylor structure (PSU IDs, strata, FPC, nest flag).
Where should `create_*_weights()` store this information for later recovery?

**Options:**
- **A:** In `survey_replicate@variables` as extra keys (`$ids`, `$strata`,
  `$fpc`, `$nest`). Risk: surveycore's S7 validator may reject extra keys.
- **B:** In `@metadata@weighting_history` as part of the creation history
  entry. `as_taylor_design()` reads it from the most recent `create_*_weights`
  entry. Risk: if history is modified or lost, round-trip breaks.
- **C:** Don't store — `as_taylor_design()` requires the user to provide
  the original design structure as additional arguments.
- **D:** In a dedicated `@metadata` field (e.g., `@metadata@source_design`).
  Requires surveycore API change to add the field.

**Recommendation:** Option B. The weighting history already records operation
parameters. Adding `source_design = list(ids = ..., strata = ..., fpc = ...,
nest = ...)` to the history entry is natural and doesn't require surveycore
API changes. `as_taylor_design()` reads the most recent `"replicate_creation"`
history entry.

---

### Q8: Advanced Argument Exposure

Several svrep arguments are useful for specialized workflows. Which should
surveywts expose?

| Argument | Backend | What it does | Proposed |
|----------|---------|-------------|----------|
| `compress` | All svrep/survey functions | Compressed replicate weight matrix for memory efficiency | **Hide** — always `TRUE`; implementation detail |
| `tau` | `as_gen_boot_design()` | Rescaling to prevent negative weights | **Expose** — users may need this for designs with extreme weights |
| `psd_option` | `as_gen_boot_design()`, `as_fays_gen_rep_design()` | `"warn"` or `"error"` for non-PSD quadratic form matrix | **Hide** — always `"warn"`; `"error"` is unhelpful since users can't fix the matrix |
| `balanced` | `as_fays_gen_rep_design()` | Equal contribution to variance | **Expose** — default `TRUE`; users may want `FALSE` for fewer replicates |
| `samp_method_by_stage` | `as_bootstrap_design()` | Override auto-detected sampling method per stage | **Hide** — auto-detection is usually correct; very advanced |
| `aux_var_names` | `as_gen_boot_design()`, `as_fays_gen_rep_design()` | Required for `"Deville-Tille"` | **Expose** — required for one estimator |
| `exact_vcov` | `as_gen_boot_design()` | Exact variance match (needs replicates > rank(Sigma)) | **Hide** — very advanced; use svrep directly |
| `sort_var` (jackknife) | `as_random_group_jackknife_design()` | Sort before group assignment | **Hide** — rarely needed |
| `var_strat` / `var_strat_frac` | `as_random_group_jackknife_design()` | Variance strata for FPC | **Hide** for Phase 1 |
| `use_normal_hadamard` | `as_sdr_design()` | Normal vs power-of-4 Hadamard matrix | **Hide** — default `FALSE` is standard |

**Your call:** Review the "Proposed" column. Override any you disagree with.

---

### Q9: Weighting History Entries

Should `create_*_weights()` functions add an entry to
`@metadata@weighting_history`? These functions perform a design conversion,
not a weight modification (unlike `calibrate()` / `rake()` / `poststratify()`
which modify weight values).

**Options:**
- **A:** Yes — record method, parameters, timestamp. Consistent with the
  principle that weighting history tracks every significant operation on the
  object.
- **B:** No — history is reserved for weight-modifying operations only.
  Design conversion is structural, not a weighting step.
- **C:** Yes, but use a distinct `operation` type (e.g.,
  `"replicate_creation"`) to distinguish from weight adjustments. Include
  enough information for `as_taylor_design()` to reconstruct the original
  Taylor design (see Q7).

**Recommendation:** Option C. The history should record this operation for
provenance and round-trip recovery, but distinguish it from actual weight
adjustments. The entry should include `source_design` metadata per Q7.

---

### Q10: Print Method for `survey_replicate`

Should surveywts add a print method for `survey_replicate` (similar to how
Phase 0 added one for `survey_nonprob`)?

**Options:**
- **A:** Yes — show weight stats, replicate type, number of replicates,
  scale factor, and weighting history. Consistent with `survey_nonprob` print.
- **B:** No — surveycore's default print is sufficient for Phase 1.
- **C:** Yes, but minimal — only add weight stats and replicate summary to
  whatever surveycore already prints.

**Recommendation:** Option A. Consistent with the `survey_nonprob` print
method. Users should see the replicate type and count at a glance without
having to inspect `@variables` directly.

---

## XII. Error and Warning Classes (New in Phase 1)

These classes must be added to `plans/error-messages.md`:

### Errors

| Class | Thrown by | Condition |
|-------|-----------|-----------|
| `surveywts_error_already_replicate` | All `create_*_weights()`, `create_replicate_weights()` | Input is already `survey_replicate` |
| `surveywts_error_not_survey_design` | All `create_*_weights()`, `create_replicate_weights()` | Input is `data.frame` or `weighted_df` |
| `surveywts_error_unsupported_class` | All `create_*_weights()`, `as_taylor_design()` | Unrecognized input class |
| `surveywts_error_replicates_not_positive` | Bootstrap, jackknife (random-groups), gen-boot, SDR | `replicates` is not a positive integer ≥ 2 |
| `surveywts_error_brr_requires_paired_design` | `create_brr_weights()` | Stratum has ≠ 2 PSUs, or input is `survey_nonprob` |
| `surveywts_error_brr_rho_invalid` | `create_brr_weights()` | `rho < 0` or `rho >= 1` |
| `surveywts_error_replicates_required_for_jkn` | `create_jackknife_weights()` | `type = "random-groups"` but `replicates` is `NULL` |
| `surveywts_error_sort_var_has_na` | `create_sdr_weights()` | `sort_var` column contains `NA` |
| `surveywts_error_variance_estimator_requires_aux` | `create_gen_boot_weights()`, `create_gen_rep_weights()` | `variance_estimator = "Deville-Tille"` but `aux_var_names` not provided |
| `surveywts_error_no_taylor_structure` | `as_taylor_design()` | No stored Taylor structure found in history; cannot reconstruct |

### Warnings

| Class | Thrown by | Condition |
|-------|-----------|-----------|
| `surveywts_warning_already_taylor` | `as_taylor_design()` | Input is already `survey_taylor`; function is a no-op |
| `surveywts_warning_taylor_loses_variance` | `as_taylor_design()` | Converting drops replicate weights and variance capability |
| `surveywts_warning_delete1_many_replicates` | `create_jackknife_weights()` | Delete-1 produces > 500 replicates (proposed threshold) |

---

## XIII. Testing

### File Mapping

| Source file | Test file |
|---|---|
| `R/replicate-weights.R` | `tests/testthat/test-replicate-weights.R` |
| `R/replicate-dispatch.R` | `tests/testthat/test-replicate-dispatch.R` |

### Test Data

`make_surveywts_data()` already exists in `helper-test-data.R`. Phase 1 adds:

```r
# Clustered, stratified design for general replicate weight testing
make_taylor_design(n = 500, n_strata = 4, psus_per_stratum = 5, seed = 42)
# Returns a survey_taylor with strata, PSU IDs, and base weights

# Paired PSU design for BRR tests
make_paired_design(n_strata = 3, obs_per_psu = 10, seed = 42)
# Returns a survey_taylor with exactly 2 PSUs per stratum
```

### Test Plan

#### `test-replicate-weights.R`

**1. `create_bootstrap_weights()` — happy path**
1a. `survey_taylor` input → `survey_replicate`; `test_invariants()`
1b. Default `replicates = 500` produces correct number of rep columns
1c. Different `type` values produce different results
1d. `mse = FALSE` passes through correctly
1e. `survey_nonprob` input → `survey_replicate` (if Q4 includes it)
1f. Metadata (variable labels, history) preserved through conversion

**2. `create_bootstrap_weights()` — equivalence with svrep**
2a. Same output as calling `svrep::as_bootstrap_design()` directly, with
    fixed seed (`skip_if_not_installed("svrep")`; tolerance `1e-10`)

**3. `create_bootstrap_weights()` — errors**
3a. `data.frame` input → `surveywts_error_not_survey_design` (class + snapshot)
3b. `survey_replicate` input → `surveywts_error_already_replicate` (class + snapshot)
3c. `replicates = 0` → `surveywts_error_replicates_not_positive` (class + snapshot)
3d. `replicates = 1.5` → `surveywts_error_replicates_not_positive` (class + snapshot)

**4. `create_jackknife_weights()` — happy path**
4a. `type = "delete-1"`, unstratified → `@variables$type == "JK1"`
4b. `type = "delete-1"`, stratified → `@variables$type == "JKn"`
4c. `type = "random-groups"`, `replicates = 20` → `@variables$type == "JKn"`, 20 reps
4d. `survey_nonprob` input → `survey_replicate` (if Q4 includes it)

**5. `create_jackknife_weights()` — errors**
5a. `type = "random-groups"`, `replicates = NULL` → error (class + snapshot)
5b. `survey_replicate` input → error (class + snapshot)

**6. `create_brr_weights()` — happy path**
6a. Paired design, `rho = 0` → `@variables$type == "BRR"`
6b. Paired design, `rho = 0.5` → `@variables$type == "Fay"`

**7. `create_brr_weights()` — equivalence with survey**
7a. Same output as `survey::as.svrepdesign(type = "BRR")` (tolerance `1e-10`)

**8. `create_brr_weights()` — errors**
8a. Non-paired design → `surveywts_error_brr_requires_paired_design` (class + snapshot)
8b. `survey_nonprob` → `surveywts_error_brr_requires_paired_design` (class + snapshot)
8c. `rho = -0.1` → `surveywts_error_brr_rho_invalid` (class + snapshot)
8d. `rho = 1.0` → `surveywts_error_brr_rho_invalid` (class + snapshot)

**9. `create_gen_boot_weights()` — happy path**
9a. Default args → `survey_replicate`, `@variables$type == "bootstrap"`
9b. `variance_estimator = "SD2"` produces different output than `"SD1"`
9c. `tau = "auto"` produces non-negative replicate weights

**10. `create_gen_rep_weights()` — happy path**
10a. Default args → `survey_replicate` (deterministic — same result each time)
10b. `max_replicates = 20` limits replicate count
10c. `balanced = FALSE` may produce fewer replicates than `balanced = TRUE`

**11. `create_sdr_weights()` — happy path**
11a. `replicates = 100` → `survey_replicate`, `@variables$type == "successive-difference"`
11b. `sort_var` reorders before computing (different result than without)

**12. `create_sdr_weights()` — errors**
12a. `sort_var` column with NA → `surveywts_error_sort_var_has_na` (class + snapshot)

**13. Shared error paths**
13a. Each `create_*_weights()` with `data.frame` → `surveywts_error_not_survey_design`
13b. Each `create_*_weights()` with `survey_replicate` → `surveywts_error_already_replicate`

#### `test-replicate-dispatch.R`

**14. `create_replicate_weights()` — dispatch**
14a. `method = "bootstrap"` dispatches correctly → `survey_replicate`
14b. `method = "jackknife"` dispatches correctly → `survey_replicate`
14c. `method = "brr"` dispatches correctly (paired design) → `survey_replicate`
14d. `method = "gen-boot"` dispatches correctly → `survey_replicate`
14e. `method = "gen-rep"` dispatches correctly → `survey_replicate`
14f. `method = "sdr"` dispatches correctly → `survey_replicate`
14g. Extra `...` args pass through to underlying function
14h. Invalid method → standard `rlang::arg_match()` error

**15. `as_taylor_design()` — happy path**
15a. `survey_replicate` → `survey_taylor`; replicate columns dropped
15b. Original design structure preserved (ids, strata, etc.)
15c. Metadata preserved

**16. `as_taylor_design()` — warnings**
16a. `survey_taylor` input → `surveywts_warning_already_taylor` (class + snapshot)
16b. `survey_replicate` input → `surveywts_warning_taylor_loses_variance`
    (class + snapshot)

**17. `as_taylor_design()` — errors**
17a. Unsupported input → `surveywts_error_unsupported_class` (class + snapshot)
17b. No Taylor structure stored → `surveywts_error_no_taylor_structure` (if
    applicable per Q7 resolution)

### `test_invariants()` Extension

Extend `test_invariants()` in `helper-test-data.R` for `survey_replicate`:

```r
if (S7::S7_inherits(obj, surveycore::survey_replicate)) {
  testthat::expect_true(is.character(obj@variables$weights))
  testthat::expect_true(is.character(obj@variables$repweights))
  testthat::expect_true(length(obj@variables$repweights) >= 2L)
  testthat::expect_true(
    all(obj@variables$repweights %in% names(obj@data))
  )
}
```

---

## XIV. `@family` Groups

```r
@family replicate-weights  # create_bootstrap_weights(), create_jackknife_weights(),
                            # create_brr_weights(), create_gen_boot_weights(),
                            # create_gen_rep_weights(), create_sdr_weights()

@family conversion          # create_replicate_weights(), as_taylor_design()
```

---

## XV. Quality Gates

Phase 1 is complete when:

- [ ] All six `create_*_weights()` functions pass `devtools::check()` with
  0 errors, 0 warnings, ≤2 pre-approved notes
- [ ] `create_replicate_weights()` and `as_taylor_design()` pass check
- [ ] Test coverage ≥ 98% for `R/replicate-weights.R` and `R/replicate-dispatch.R`
- [ ] All error classes in §XII are in `plans/error-messages.md`
- [ ] All test blocks listed in §XIII are implemented and passing
- [ ] Equivalence tests against svrep/survey pass (tolerance `1e-10`)
- [ ] Metadata preservation verified (labels, history survive the conversion
  pipeline)
- [ ] All API design questions in §XI are resolved and logged in
  `plans/decisions-replicate.md`
- [ ] `svrep` added to DESCRIPTION `Imports` with minimum version
- [ ] NEWS.md updated with v0.2.0 section
- [ ] DESCRIPTION version bumped to `0.2.0`
