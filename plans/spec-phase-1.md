# Phase 1 Spec: Replicate Weight Generation (v0.2.0)

**Version:** 0.2
**Date:** 2026-03-11
**Status:** Draft — Stage 2 Resolve in progress (8 of 16 issues resolved; 5 blocking GAPs pending)
**Branch identifier:** `phase-1`
**Related files:** `plans/spec-review-phase-1.md` (after review),
`plans/decisions-phase-1.md` (after resolve)

---

## Document Purpose

This document is the single source of truth for Phase 1 of surveywts. It fully
specifies every exported function, error class, and test expectation required to
ship v0.2.0. Implementation may not begin until this spec is approved (Stage 2
methodology review + Stage 3 spec review + Stage 4 resolve complete).

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
| `create_fay_weights()` | Function | Yes |
| `create_gen_boot_weights()` | Function | Yes |
| `create_sdr_weights()` | Function | Yes |
| `create_replicate_weights()` | Function | Yes |
| `as_taylor_design()` | Function | Yes |

> **Scope correction (2026-03-11, updated 2026-03-12):** The original scope note
> stated that "Bootstrap variance in `survey_nonprob`" was removed from Phase 1.
> That applies only to the **re-calibrated bootstrap** (Rao & Tarozzi 2004), which
> requires calibration provenance infrastructure not yet in place (Phase 2.5 scope).
> **Simple bootstrap** for `survey_nonprob` — resampling observations without
> re-calibrating each replicate — is Phase 1 scope. `create_bootstrap_weights()`
> and `create_jackknife_weights()` accept `survey_nonprob` input and produce
> `survey_replicate` output. See §XI for the Phase 1 / Phase 2.5 split.

### Non-Deliverables (Phase 1)

The following are explicitly out of scope:

- `create_*_weights()` accepting `weighted_df` input — `survey_taylor`,
  `survey_srs`, and `survey_nonprob` (for applicable methods) are the only
  supported input classes
- `create_replicate_weights()` accepting `weighted_df` input — same restriction
- Variance estimation or analysis functions — Phase 1 only creates the weights
- `trim_weights()`, `stabilize_weights()` (Phase 4)
- `calibrate_to_survey()` (Phase 2)

### Phase 0 Stub Removal

Phase 0 includes stub errors for `survey_replicate` input in all calibration and
nonresponse functions (`surveywts_error_replicate_not_supported`). Phase 1 does NOT
remove those stubs. The existing calibration functions (`calibrate()`, `rake()`,
`poststratify()`, `adjust_nonresponse()`) continue to reject `survey_replicate`
input until a future phase specifies that behavior.

### Input/Output Class Matrix

#### `create_*_weights()` and `create_replicate_weights()`

| Input class | Output |
|-------------|--------|
| `survey_taylor` | `survey_replicate` |
| `survey_srs` | Method-dependent — see each function's §Error Table |
| `survey_nonprob` | Method-dependent — see each function's §Error Table |
| `survey_replicate` | Error: `surveywts_error_already_replicate` |
| `data.frame`, `weighted_df` | Error: `surveywts_error_not_survey_design` |
| Any other | Error: `surveywts_error_unsupported_class` |

Per-function behavior for `survey_srs` and `survey_nonprob`:

| Function | `survey_srs` | `survey_nonprob` |
|----------|-------------|-----------------|
| `create_bootstrap_weights()` | `survey_replicate` (treats obs as PSUs; pending unclustered-design GAP) | `survey_replicate` (resamples obs) |
| `create_jackknife_weights()` | `survey_replicate` (treats obs as PSUs) | `survey_replicate` (treats obs as PSUs) |
| `create_brr_weights()` | Error `surveywts_error_brr_requires_paired_design` | Error `surveywts_error_brr_requires_paired_design` |
| `create_fay_weights()` | Error `surveywts_error_brr_requires_paired_design` | Error `surveywts_error_brr_requires_paired_design` |
| `create_gen_boot_weights()` | Error `surveywts_error_no_psu_ids` | Error `surveywts_error_no_psu_ids` |
| `create_sdr_weights()` | `survey_replicate` (treats obs as ordered units) | Error `surveywts_error_no_psu_ids` |

#### `as_taylor_design()`

| Input class | Output |
|-------------|--------|
| `survey_replicate` | `survey_taylor` |
| `survey_taylor` | `survey_taylor` (identity — warning issued) |
| Any other | Error: `surveywts_error_unsupported_class` |

---

## II. Architecture

### Source File Organization

```
R/
├── replicate-weights.R   # create_bootstrap_weights(), create_jackknife_weights(),
│                         # create_brr_weights(), create_fay_weights(),
│                         # create_gen_boot_weights(), create_sdr_weights(),
│                         # plus phase-local helpers
├── conversion.R          # create_replicate_weights(), as_taylor_design()
├── vendor/
│   └── replicate-*.R     # Vendored replication algorithms (see §II.b)
└── [existing Phase 0 files unchanged]
```

### §II.a Shared Helpers

Phase 1 adds these shared internal helpers to `R/utils.R` (used by 2+ source files):

| Helper | Signature | Description |
|--------|-----------|-------------|
| `.extract_taylor_structure()` | `(data)` | Extracts PSU ids, strata, weights, FPC, nest flag from a `survey_taylor`; returns a named list |
| `.validate_replicate_count()` | `(replicates, min = 2L)` | Validates that `replicates` is a positive integer ≥ `min`; errors with `surveywts_error_replicates_not_positive` |
| `.build_survey_replicate()` | `(data, repweights, type, scale = NULL, rscales = NULL, mse = TRUE)` | Adds replicate weight columns to `data@data`, calls `surveycore::as_survey_replicate()` to construct the `survey_replicate`, then writes `$ids`, `$strata`, `$fpc`, `$nest` from `data@variables` into the output `@variables` for round-trip recovery |
| `.make_rep_col_names()` | `(prefix = "rep", n)` | Returns character vector `c("rep_1", "rep_2", ..., "rep_n")` |

> **Soft risk:** `.build_survey_replicate()` stores Taylor round-trip keys (`ids`,
> `strata`, `fpc`, `nest`) in `@variables`. The surveycore constructor sets 9 fixed
> keys; extra keys are technically accepted by S7 but are outside the intended API.
> This is a soft risk, not a blocking GAP — verify against surveycore before
> implementation begins.

Phase-local helpers (used only within `replicate-weights.R`) are defined at the
top of that file, per `code-style.md §4`.

### §II.b Vendoring Decision

> ⚠️ GAP: Should Phase 1 implement replicate weight algorithms natively (svrep as
> oracle) or vendor the algorithm code from svrep? Phase 0 vendored GREG and IPF
> from the `survey` package because those algorithms are complex matrix operations.
> The replication weight algorithms (bootstrap PSU sampling, Hadamard-based BRR,
> JK replication factors) are comparably complex.
>
> **Recommendation for Stage 2:** Vendor from svrep for bootstrap, BRR/Fay,
> jackknife, and SDR methods. Implement `gen_boot` natively (formula is simpler).
> svrep stays in `Suggests` as both the vendoring source and test oracle.
>
> If the decision is "vendor", files go in `R/vendor/replicate-*.R` following
> Phase 0 conventions with full attribution headers.

### §II.c Package Dependencies

**No new `Imports`** for Phase 1. All algorithm implementations are either
vendored or native. `svrep` remains in `Suggests` as the test oracle.

### §II.d `survey_replicate` Construction

All `create_*_weights()` functions produce a `survey_replicate` via
`surveycore::as_survey_replicate()`. The `type` string passed to that function
determines how scale factors are computed internally by surveycore:

| Function | `type` string | Default scale |
|----------|--------------|---------------|
| `create_bootstrap_weights()` | `"bootstrap"` | `1 / n_rep` |
| `create_jackknife_weights()`, delete-1 | `"JK1"` | `(n_rep - 1) / n_rep` |
| `create_jackknife_weights()`, random-groups | `"JKn"` | `(n_rep - 1) / n_rep` |
| `create_brr_weights()` | `"BRR"` | `1 / n_rep` |
| `create_fay_weights()` | `"Fay"` | `1 / (n_rep * (1 - rho)^2)` |
| `create_gen_boot_weights()` | `"bootstrap"` | `1 / n_rep` |
| `create_sdr_weights()` | `"successive-difference"` | `4 / n_rep` |

### §II.e Validation Order

All `create_*_weights()` functions validate in this order:
1. Input class check (error if not `survey_taylor`, `survey_srs`, or `survey_nonprob`)
2. `replicates` argument validity (where applicable)
3. Method-specific design requirements (e.g., 2 PSUs per stratum for BRR)

---

## III. `create_bootstrap_weights()`

### Signature

```r
create_bootstrap_weights(
  data,
  replicates = 500L,
  type = c("Rao-Wu-Yue-Beaumont", "standard"),
  mse = TRUE
)
```

### Argument Table

| Argument | Type | Default | Description |
|----------|------|---------|-------------|
| `data` | `survey_taylor`, `survey_srs`, or `survey_nonprob` | — | Input design |
| `replicates` | `integer(1)`, ≥ 2 | `500L` | Number of bootstrap replicates to generate |
| `type` | `character(1)` | `"Rao-Wu-Yue-Beaumont"` | Bootstrap variant. See §III.b |
| `mse` | `logical(1)` | `TRUE` | If `TRUE`, variance is estimated as `scale × Σ_r (θ̂_r − θ̂)²` (deviation from full-sample estimate). If `FALSE`, variance is estimated as `scale × Σ_r (θ̂_r − θ̄_rep)²` (deviation from replicate mean); this can underestimate variance for biased estimators. Passed through to `surveycore::as_survey_replicate()` |

### Output Contract

Returns a `surveycore::survey_replicate` with:
- `@data`: original columns + `replicates` new columns named `rep_1`, …, `rep_{replicates}`
- `@variables$weights`: same weight column as input
- `@variables$repweights`: `c("rep_1", ..., "rep_{replicates}")`
- `@variables$type`: `"bootstrap"`
- `@variables$scale`: `1 / replicates`
- `@variables$mse`: value of `mse` argument

### §III.b Algorithm

> ⚠️ GAP: The exact replication factor formulas for `type = "Rao-Wu-Yue-Beaumont"`
> and `type = "standard"` must be verified in Stage 2 methodology review.
>
> Current understanding:
>
> **`"Rao-Wu-Yue-Beaumont"` (default):** For each bootstrap replicate and each
> stratum h with n_h PSUs:
> - Draw m_h = n_h − 1 PSUs with replacement from stratum h
> - Replication factor for PSU i in stratum h: `c_{hi} = (n_h / (n_h - 1)) * m*_{hi}`
>   where `m*_{hi}` is the number of times PSU i was selected (0, 1, or more)
> - PSUs with `m*_{hi} = 0` get replication factor 0
> - Note: drawing n_h − 1 (not n_h) ensures E[c_{hi}] = 1, calibrating the
>   correction factor. Confirmed against svrep source (`make_rwyb_bootstrap_weights.R`)
> - Supports single-PSU strata: > ⚠️ **GAP: how are single-PSU strata handled?**
>   Options: (a) force collapse of singleton strata before calling; (b) error;
>   (c) center the replication factor at 1 for singleton strata.
>
> **`"standard"`:** Simple with-replacement PSU bootstrap.
> - For each stratum h with n_h PSUs, draw n_h PSUs with replacement
> - Replication factor: `c_{hi} = m*_{hi}` (raw draw counts)
> - This does not correct for the resampling rate; variance estimates may be
>   slightly biased for small n_h

### §III.c Error Table

| Class | Condition |
|-------|-----------|
| `surveywts_error_not_survey_design` | `data` is a `data.frame` or `weighted_df` |
| `surveywts_error_unsupported_class` | `data` is not a recognized survey class |
| `surveywts_error_already_replicate` | `data` is already a `survey_replicate` |
| `surveywts_error_replicates_not_positive` | `replicates` is not a positive integer ≥ 2 |

> ⚠️ GAP: Should `create_bootstrap_weights()` work on an unclustered design (no
> PSUs), resampling individuals? Or should it require a clustered design? The
> survey package supports both; svrep requires PSU IDs. Define behavior here.
> `survey_srs` and `survey_nonprob` inputs are accepted pending this GAP resolution —
> they are treated as designs where observations are the sampling units.

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

> ⚠️ GAP: The roadmap lists `replicates` as a required argument
> (`create_jackknife_weights(data, replicates, ...)`), but for `type = "delete-1"`
> the number of replicates is determined by the number of PSUs in the design — the
> user cannot (and should not) specify it. Resolution options:
>
> - **Option A (Recommended):** `replicates = NULL`; required for
>   `type = "random-groups"`, ignored (with a message) for `type = "delete-1"`
> - **Option B:** Two separate functions (`create_jk1_weights()`,
>   `create_jkn_weights()`)
>
> If Option A is chosen: error `surveywts_error_replicates_required_for_jkn`
> when `type = "random-groups"` and `replicates` is `NULL`.

### Argument Table

| Argument | Type | Default | Description |
|----------|------|---------|-------------|
| `data` | `survey_taylor`, `survey_srs`, or `survey_nonprob` | — | Input design |
| `type` | `character(1)` | `"delete-1"` | Jackknife variant. `"delete-1"`: one replicate per PSU (JK1). `"random-groups"`: PSUs divided into `replicates` groups (JKn) |
| `replicates` | `integer(1)`, ≥ 2 or `NULL` | `NULL` | Number of groups for `type = "random-groups"`. Ignored for `type = "delete-1"` |
| `mse` | `logical(1)` | `TRUE` | If `TRUE`, variance deviates from full-sample estimate; if `FALSE`, deviates from replicate mean (can underestimate for biased estimators). See §III for full description |

### Output Contract

Returns `survey_replicate` with:
- `@variables$type`: `"JK1"` for delete-1; `"JKn"` for random-groups
- For delete-1: `n_rep` = total number of PSUs across all strata
- For random-groups: `n_rep` = `replicates`

### §IV.b Algorithm

**Delete-1 (JK1):** For each PSU i in stratum h with n_h PSUs:
- Replicate k = "PSU i deleted": PSU i gets factor 0; all other PSUs in stratum h
  get factor `n_h / (n_h - 1)`; PSUs in other strata unchanged

**Random-groups (JKn):** Divide PSUs randomly into `replicates` groups of
approximately equal size. For each group replicate k:
- PSUs in group k: factor 0
- PSUs not in group k: factor `replicates / (replicates - 1)`

> ⚠️ GAP: For delete-1 with large designs (many PSUs), the number of replicates
> can be very large (> 1000). Should there be a warning or maximum? Define the
> threshold.

### §IV.c Error Table

| Class | Condition |
|-------|-----------|
| `surveywts_error_not_survey_design` | `data` is `data.frame` / `weighted_df` |
| `surveywts_error_unsupported_class` | Unrecognized class |
| `surveywts_error_already_replicate` | `data` is already `survey_replicate` |
| `surveywts_error_replicates_not_positive` | `replicates` ≤ 1 or not integer (when used) |
| `surveywts_error_replicates_required_for_jkn` | `type = "random-groups"` and `replicates` is `NULL` |

---

## V. `create_brr_weights()`

### Signature

```r
create_brr_weights(
  data,
  mse = TRUE
)
```

### Argument Table

| Argument | Type | Default | Description |
|----------|------|---------|-------------|
| `data` | `survey_taylor` | — | Input design. Must have exactly 2 PSUs per stratum (paired PSU design). `survey_srs` and `survey_nonprob` are rejected — BRR requires a paired design structure |
| `mse` | `logical(1)` | `TRUE` | If `TRUE`, variance deviates from full-sample estimate; if `FALSE`, deviates from replicate mean (can underestimate for biased estimators). See §III for full description |

### Output Contract

Returns `survey_replicate` with:
- `@variables$type`: `"BRR"`
- `n_rep` = smallest multiple of 4 that is ≥ number of strata
- `@variables$scale`: `1 / n_rep`

### §V.b Algorithm

BRR uses a Hadamard matrix H of size n_rep × n_strata to assign PSUs to
half-samples. For each replicate (row) and each stratum (column):
- H[r, h] = +1: PSU 1 in stratum h is selected (full weight); PSU 2 gets factor 0
- H[r, h] = −1: PSU 2 is selected; PSU 1 gets factor 0

For standard BRR: selected PSU factor = 2, excluded factor = 0.

> ⚠️ GAP: Stage 2 should verify the exact Hadamard matrix construction algorithm.

### §V.c Error Table

| Class | Condition |
|-------|-----------|
| `surveywts_error_not_survey_design` | `data` is `data.frame` / `weighted_df` |
| `surveywts_error_unsupported_class` | Unrecognized class |
| `surveywts_error_already_replicate` | Already `survey_replicate` |
| `surveywts_error_brr_requires_paired_design` | Any stratum has ≠ 2 PSUs, or input is `survey_srs` / `survey_nonprob` |

---

## VI. `create_fay_weights()`

### Signature

```r
create_fay_weights(
  data,
  replicates = 100L,
  rho = 0.5,
  mse = TRUE
)
```

### Argument Table

| Argument | Type | Default | Description |
|----------|------|---------|-------------|
| `data` | `survey_taylor` | — | Input design. Must have exactly 2 PSUs per stratum (paired PSU design). `survey_srs` and `survey_nonprob` are rejected — Fay's method requires a paired design structure |
| `replicates` | `integer(1)`, ≥ 2 | `100L` | Number of pseudo-BRR replicates |
| `rho` | `numeric(1)`, 0 < rho < 1 | `0.5` | Fay coefficient. Required to be strictly positive. Selected PSU factor = `2 - rho`; excluded factor = `rho` |
| `mse` | `logical(1)` | `TRUE` | If `TRUE`, variance deviates from full-sample estimate; if `FALSE`, deviates from replicate mean (can underestimate for biased estimators). See §III for full description |

### Output Contract

Returns `survey_replicate` with:
- `@variables$type = "Fay"`
- `@variables$scale = 1 / (replicates * (1 - rho)^2)` — the correct Fay (1989) variance
  scale factor; confirmed against survey package source (`as.svrepdesign.default`)

### §VI.b Error Table

| Class | Condition |
|-------|-----------|
| `surveywts_error_not_survey_design` | `data` is `data.frame` / `weighted_df` |
| `surveywts_error_unsupported_class` | Unrecognized class |
| `surveywts_error_already_replicate` | Already `survey_replicate` |
| `surveywts_error_replicates_not_positive` | `replicates` ≤ 1 or not integer |
| `surveywts_error_brr_requires_paired_design` | Any stratum has ≠ 2 PSUs, or input is `survey_srs` / `survey_nonprob` |
| `surveywts_error_brr_fay_rho_invalid` | `rho` ≤ 0 or ≥ 1 |

---

## VII. `create_gen_boot_weights()`

### Signature

```r
create_gen_boot_weights(
  data,
  replicates = 500L,
  variance_estimator = c("SD1", "SD2"),
  mse = TRUE
)
```

### Argument Table

| Argument | Type | Default | Description |
|----------|------|---------|-------------|
| `data` | `survey_taylor` | — | Input design. PSU IDs required. `survey_srs` and `survey_nonprob` are rejected with `surveywts_error_no_psu_ids` |
| `replicates` | `integer(1)`, ≥ 2 | `500L` | Number of replicates |
| `variance_estimator` | `character(1)` | `"SD1"` | Variance estimator variant. `"SD1"` is for with-replacement sampling; `"SD2"` is for without-replacement |
| `mse` | `logical(1)` | `TRUE` | If `TRUE`, variance deviates from full-sample estimate; if `FALSE`, deviates from replicate mean (can underestimate for biased estimators). See §III for full description |

### §VII.a Algorithm

The generalized bootstrap (Beaumont & Patak 2012) draws R replicate weight
vectors from MVN(1, Σ), where Σ is chosen so that the resulting bootstrap
variance unbiasedly targets the Ash (2014) successive-difference estimator.

**Variance estimator targets (Ash 2014):**

**SD1 (non-circular):**
```
v̂_SD1(Ŷ) = (1 − n/N) × n / (2(n−1)) × Σ_{k=2}^n (ỹ_k − ỹ_{k−1})²
```
where ỹ_k = y_k / π_k (weighted values in PSU systematic selection order) and
n/N is the overall sampling fraction (0 for with-replacement sampling).

**SD2 (circular):**
```
v̂_SD2(Ŷ) = (1 − n/N) × (1/2) × [Σ_{k=2}^n (ỹ_k − ỹ_{k−1})² + (ỹ_n − ỹ_1)²]
```
Same as SD1 but adds a wrap-around term connecting last and first PSU.

**Implementation:** The Σ matrix encoding each estimator is computed by
`svrep::make_gen_boot_factors()`. Implementation must match this oracle at
`1e-8` tolerance. PSUs within each stratum are ordered by their systematic
selection order; this ordering must be preserved or specified via `sort_var`.

**Design requirement:** PSU IDs are required (`data@variables$ids` must be
non-NULL). Unclustered designs and `survey_srs`/`survey_nonprob` inputs are
rejected with `surveywts_error_no_psu_ids`.

**Reference:** svrep `make_gen_boot_factors(variance_estimator = "SD1")` and
`make_gen_boot_factors(variance_estimator = "SD2")`.

### Output Contract

Returns `survey_replicate` with `@variables$type = "bootstrap"`.

### §VII.b Error Table

| Class | Condition |
|-------|-----------|
| `surveywts_error_not_survey_design` | `data` is `data.frame` / `weighted_df` |
| `surveywts_error_unsupported_class` | Unrecognized class |
| `surveywts_error_already_replicate` | Already `survey_replicate` |
| `surveywts_error_replicates_not_positive` | `replicates` ≤ 1 or not integer |
| `surveywts_error_no_psu_ids` | `survey_srs` or `survey_nonprob` input, or no PSU IDs in design |

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
| `data` | `survey_taylor` or `survey_srs` | — | Input design. PSUs must be in systematic selection order (see `sort_var`). `survey_nonprob` is rejected with `surveywts_error_no_psu_ids` |
| `replicates` | `integer(1)`, must be a multiple of 4 | `100L` | Number of SDR replicates. Must be a multiple of 4 (Hadamard matrix constraint). Error if not. The ACS uses 80; typical range is 80–200 |
| `sort_var` | `character(1)` or `NULL` | `NULL` | Column name in `data@data` giving systematic selection order. If `NULL`, row order in `data@data` is assumed to be the systematic selection order. Errors if `sort_var` contains `NA` |
| `mse` | `logical(1)` | `TRUE` | If `TRUE`, variance deviates from full-sample estimate; if `FALSE`, deviates from replicate mean (can underestimate for biased estimators). See §III for full description |

### §VIII.a Algorithm

SDR (Fay & Train 1995; Wolter 2007) uses a Hadamard matrix to construct
replication factors that approximate the successive-difference variance
estimator. PSUs must be ordered in their systematic selection sequence.

**Replicate count:** `n_rep` must be a multiple of 4 (Hadamard order
constraint). Error `surveywts_error_sdr_replicates_not_multiple_of_4` if not.

**Replication factor formula:**
```
f_{i,r} = 1 + (H[row1(i), r] − H[row2(i), r]) × 2^(−3/2)
```
where H is a Hadamard matrix of size n_rep × n_rep (entries ±1), and each
PSU i in the ordered sequence is assigned two rows `row1(i)` and `row2(i)`
based on its position. The differences H[row1,r] − H[row2,r] ∈ {−2, 0, +2},
giving factors in {1 − √2/2, 1, 1 + √2/2}.

**Scale:** `4 / n_rep` (confirmed from svrep documentation).

**Sort variable:** If `sort_var` is provided, rows of `data@data` are reordered
by that column before factor computation. If `sort_var = NULL`, existing row
order is used. Errors if `sort_var` has `NA` values
(`surveywts_error_sort_var_has_na`).

**Reference:** svrep `make_sdr_replicate_factors()` is the implementation
oracle. Numerical correctness test at `1e-8` tolerance.

### Output Contract

Returns `survey_replicate` with:
- `@variables$type = "successive-difference"`
- `@variables$scale = 4 / replicates`

### §VIII.b Error Table

| Class | Condition |
|-------|-----------|
| `surveywts_error_not_survey_design` | `data` is `data.frame` / `weighted_df` |
| `surveywts_error_unsupported_class` | Unrecognized class |
| `surveywts_error_already_replicate` | Already `survey_replicate` |
| `surveywts_error_replicates_not_positive` | `replicates` ≤ 1 or not integer |
| `surveywts_error_sdr_replicates_not_multiple_of_4` | `replicates` is not a multiple of 4 |
| `surveywts_error_sort_var_has_na` | `sort_var` column contains `NA` |
| `surveywts_error_no_psu_ids` | `survey_nonprob` input |

---

## IX. `create_replicate_weights()`

### Signature

```r
create_replicate_weights(
  data,
  method = c("bootstrap", "jackknife", "brr", "fay", "gen-boot", "sdr"),
  ...
)
```

### Argument Table

| Argument | Type | Default | Description |
|----------|------|---------|-------------|
| `data` | `survey_taylor`, `survey_srs`, or `survey_nonprob` | — | Input design |
| `method` | `character(1)` | (required) | Replication method. Dispatches to the corresponding `create_*_weights()` function |
| `...` | — | — | Additional arguments passed to the underlying `create_*_weights()` function |

### Dispatch Table

| `method` | Dispatches to |
|----------|--------------|
| `"bootstrap"` | `create_bootstrap_weights(data, ...)` |
| `"jackknife"` | `create_jackknife_weights(data, ...)` |
| `"brr"` | `create_brr_weights(data, ...)` |
| `"fay"` | `create_fay_weights(data, ...)` |
| `"gen-boot"` | `create_gen_boot_weights(data, ...)` |
| `"sdr"` | `create_sdr_weights(data, ...)` |

### Output Contract

Same as the dispatched `create_*_weights()` function.

### §IX.b Error Table

| Class | Condition |
|-------|-----------|
| `surveywts_error_not_survey_design` | `data` is `data.frame` / `weighted_df` |
| `surveywts_error_unsupported_class` | Unrecognized class |
| `surveywts_error_already_replicate` | Already `survey_replicate` |
| Plus all errors from the dispatched function | Propagated as-is |

---

## X. `as_taylor_design()`

### Signature

```r
as_taylor_design(data)
```

### Argument Table

| Argument | Type | Default | Description |
|----------|------|---------|-------------|
| `data` | `survey_replicate` (or `survey_taylor`) | — | Input design |

### Output Contract

Returns a `surveycore::survey_taylor` reconstructed from the replicate design's
base design structure. The replicate weight columns are dropped.

**Behavior when input is `survey_taylor`:** Returns `data` unchanged, with warning
`surveywts_warning_already_taylor`.

**What is preserved vs. lost:**
- Preserved: `@data` (base columns, not replicate columns), `@variables$weights`,
  design metadata, original Taylor structure (see below)
- Lost: replicate weight columns, `@variables$repweights`, `@variables$scale`,
  `@variables$rscales` — and therefore the ability to compute replicate-based
  variance estimates

**Taylor structure storage (Issue 6 decision — Option A):**
`create_*_weights()` stores the original Taylor design structure in the output
`survey_replicate@variables` when the input is `survey_taylor`:

```r
@variables$ids    # character vector: PSU ID column name(s) from data@variables$ids
@variables$strata # character(1) or NULL: stratum column name
@variables$fpc    # character(1) or NULL: FPC column name
@variables$nest   # logical(1): nest flag (default FALSE)
```

`as_taylor_design()` reads these keys to reconstruct the `survey_taylor`.
**Prerequisite:** `surveycore::survey_replicate@variables` must accept arbitrary
list keys beyond the predefined ones. This must be verified against the surveycore
API before implementation begins. If surveycore rejects extra keys, fall back to
Option B (store in `@metadata@weighting_history`) and update the spec.

### §X.b Warning/Error Table

| Class | Condition |
|-------|-----------|
| `surveywts_warning_already_taylor` | Input is `survey_taylor`; function is a no-op |
| `surveywts_warning_taylor_loses_variance` | Informational: converting to Taylor drops replicate weights and variance estimation capability |
| `surveywts_error_unsupported_class` | Input is not `survey_replicate` or `survey_taylor` |

---

## XI. Bootstrap Variance for `survey_nonprob` — Phase 1 (simple) / Phase 2.5 (re-calibrated)

### Phase 1 Scope: Simple Bootstrap

`survey_nonprob` is accepted by `create_bootstrap_weights()` and
`create_jackknife_weights()`. These functions resample observations (treating
each observation as its own sampling unit) without re-calibrating each replicate.
The output is a `survey_replicate` with resampled weight columns.

This is methodologically appropriate for **uncalibrated** `survey_nonprob` objects
or when the user accepts approximate variance estimates for calibrated objects.
It is the standard bootstrap for non-probability samples when design-based
replication is not possible.

### Phase 2.5 Scope: Re-calibrated Bootstrap

When a user has a calibrated `survey_nonprob` object and wants
**methodologically correct bootstrap variance** (Rao & Tarozzi 2004;
Beaumont & Patak 2012), the correct approach is to:
1. Resample observations using the base (pre-calibration) weights
2. Re-calibrate each replicate using stored calibration provenance

This requires infrastructure not yet in place:
- `survey_nonprob@calibration` provenance structure (Phase 2.5)
- A mechanism to replay calibration calls on resampled replicates

**Re-calibrated bootstrap is Phase 2.5 scope.** Phase 1 simple bootstrap does not
replay calibration — it resamples the current (calibrated) weights directly.

---

## XII. `@family` Groups

Per `surveywts-conventions.md §2`:

```r
@family replicate-weights  # create_bootstrap_weights(), create_jackknife_weights(),
                            # create_brr_weights(), create_fay_weights(),
                            # create_gen_boot_weights(), create_sdr_weights()

@family conversion          # create_replicate_weights(), as_taylor_design()
```

---

## XIII. Error and Warning Classes (New in Phase 1)

These classes must be added to `plans/error-messages.md`:

### Errors

| Class | Thrown by | Condition |
|-------|-----------|-----------|
| `surveywts_error_already_replicate` | All `create_*_weights()`, `create_replicate_weights()` | Input is already `survey_replicate` |
| `surveywts_error_not_survey_design` | All `create_*_weights()`, `create_replicate_weights()` (only for `data.frame` / `weighted_df` input; `survey_srs` and `survey_nonprob` are accepted by applicable methods) | Input is `data.frame` or `weighted_df` |
| `surveywts_error_replicates_not_positive` | `create_bootstrap_weights()`, `create_jackknife_weights()` (random-groups), `create_fay_weights()`, `create_gen_boot_weights()`, `create_sdr_weights()` | `replicates` is not a positive integer ≥ 2 |
| `surveywts_error_no_psu_ids` | `create_gen_boot_weights()` (all inputs without PSU IDs), `create_sdr_weights()` (`survey_nonprob` input) | Design has no PSU IDs |
| `surveywts_error_brr_requires_paired_design` | `create_brr_weights()`, `create_fay_weights()` | Stratum has ≠ 2 PSUs, or input is `survey_srs` / `survey_nonprob` |
| `surveywts_error_brr_fay_rho_invalid` | `create_fay_weights()` | `rho` out of valid range (≤ 0 or ≥ 1) |
| `surveywts_error_replicates_required_for_jkn` | `create_jackknife_weights()` | `type = "random-groups"` but `replicates = NULL` |
| `surveywts_error_sdr_replicates_not_multiple_of_4` | `create_sdr_weights()` | `replicates` is not a multiple of 4 |
| `surveywts_error_sort_var_has_na` | `create_sdr_weights()`, `create_gen_boot_weights()` | `sort_var` column contains `NA` |

### Warnings

| Class | Thrown by | Condition |
|-------|-----------|-----------|
| `surveywts_warning_already_taylor` | `as_taylor_design()` | Input is already `survey_taylor` |
| `surveywts_warning_taylor_loses_variance` | `as_taylor_design()` | Converting replicate to Taylor drops variance information |
| `surveywts_warning_delete1_many_replicates` | `create_jackknife_weights()` | Delete-1 type produces more than N replicates (threshold TBD in Stage 2) |

---

## XIV. Testing

### File Mapping

Per `testing-surveywts.md`:

| Source file | Test file |
|-------------|-----------|
| `R/replicate-weights.R` | `tests/testthat/test-replicate-weights.R` |
| `R/conversion.R` | `tests/testthat/test-conversion.R` |

### Test Data Generator

`make_surveywts_data()` already exists in `helper-test-data.R`. For Phase 1, the
helper must be extended to produce `survey_taylor` objects (not just raw data
frames):

```r
make_taylor_design(n = 500, n_strata = 4, psus_per_stratum = 5, seed = 42)
# Returns a survey_taylor with strata, PSU IDs, and weights
# psus_per_stratum: number of PSUs per stratum
# PSU sizes are unequal (realistic)
```

A paired PSU design (for BRR tests) can be created inline:

```r
# Inline paired PSU design for BRR tests
make_paired_design <- function(seed = 42) {
  # 3 strata × 2 PSUs per stratum = 6 PSUs
  ...
}
```

### Test Plan

#### `test-replicate-weights.R`

**1. `create_bootstrap_weights()` — happy path**
1a. `survey_taylor` input → `survey_replicate` output; `test_invariants()`
1b. Default `replicates = 500` produces correct number of rep columns
1c. `type = "Rao-Wu-Yue-Beaumont"` vs `type = "standard"` differ in variance
1d. `mse = FALSE` passes through to `@variables$mse`
1e. `survey_nonprob` input → `survey_replicate` (simple bootstrap; `test_invariants()`)

**2. `create_bootstrap_weights()` — numerical correctness**
2a. Compare variance of a mean estimate against `svrep` reference
    (`skip_if_not_installed("svrep")` inside block)

**3. `create_bootstrap_weights()` — errors**
3a. `data.frame` input → `surveywts_error_not_survey_design` (class + snapshot)
3b. `survey_replicate` input → `surveywts_error_already_replicate` (class + snapshot)
3c. `replicates = 0` → `surveywts_error_replicates_not_positive` (class + snapshot)
3d. `replicates = 1` → `surveywts_error_replicates_not_positive` (class + snapshot)
3e. `replicates = 1.5` (non-integer) → `surveywts_error_replicates_not_positive` (class + snapshot)

**4. `create_jackknife_weights()` — happy path**
4a. `type = "delete-1"` → `@variables$type == "JK1"`, `n_rep == n_psus`
4b. `type = "random-groups"` with `replicates = 20` → `@variables$type == "JKn"`, `n_rep == 20`
4c. `survey_nonprob` input → `survey_replicate` (treats obs as PSUs; `test_invariants()`)

**5. `create_jackknife_weights()` — errors**
5a. `type = "random-groups"`, `replicates = NULL` → `surveywts_error_replicates_required_for_jkn`
5b. `survey_replicate` input → `surveywts_error_already_replicate`

**6. `create_brr_weights()` — happy path**
6a. Paired design → `survey_replicate`; `n_rep` is multiple of 4 ≥ n_strata; `@variables$type == "BRR"`

**7. `create_brr_weights()` — errors**
7a. Non-paired design → `surveywts_error_brr_requires_paired_design` (class + snapshot)
7b. `survey_srs` input → `surveywts_error_brr_requires_paired_design` (class + snapshot)
7c. `survey_nonprob` input → `surveywts_error_brr_requires_paired_design` (class + snapshot)

**8. `create_fay_weights()` — happy path**
8a. Default arguments → `survey_replicate`, `@variables$type == "Fay"`

**9. `create_fay_weights()` — errors**
9a. `rho = 0` → `surveywts_error_brr_fay_rho_invalid`
9b. `rho = 1` → `surveywts_error_brr_fay_rho_invalid`

**10. `create_gen_boot_weights()` — happy path**
10a. `variance_estimator = "SD1"` → correct replicate count

**11. `create_sdr_weights()` — happy path**
11a. `replicates = 100` → `survey_replicate`, `@variables$type == "successive-difference"`
11b. `survey_srs` input → `survey_replicate` (treats obs as ordered units; `test_invariants()`)

**12. `create_sdr_weights()` — errors**
12a. `replicates = 5` (not multiple of 4) → `surveywts_error_sdr_replicates_not_multiple_of_4` (class + snapshot)
12b. `replicates = 6` (even but not multiple of 4) → same error (class + snapshot)
12c. `sort_var` with NA values → `surveywts_error_sort_var_has_na` (class + snapshot)
12d. `survey_nonprob` input → `surveywts_error_no_psu_ids` (class + snapshot)

#### `test-conversion.R`

**13. `create_replicate_weights()` — happy path**
13a. `method = "bootstrap"` dispatches correctly → `survey_replicate`
13b. `method = "jackknife"` dispatches correctly → `survey_replicate`
13c. `method = "brr"` dispatches correctly (paired design) → `survey_replicate`
13d. Extra `...` args pass through to underlying function

**14. `create_replicate_weights()` — errors**
14a. `survey_replicate` input → `surveywts_error_already_replicate`
14b. `data.frame` input → `surveywts_error_not_survey_design`
14c. Invalid `method` string → standard `match.arg()` error

**15. `as_taylor_design()` — happy path**
15a. `survey_replicate` → `survey_taylor`; replicate columns dropped
15b. Key columns preserved

**16. `as_taylor_design()` — warnings**
16a. `survey_taylor` input → `surveywts_warning_already_taylor` (class + snapshot)
16b. `survey_replicate` input → `surveywts_warning_taylor_loses_variance` (class + snapshot)

### `test_invariants()` extension

The existing `test_invariants()` in `helper-test-data.R` should be extended to
handle `survey_replicate` objects:

```r
if (S7::S7_inherits(obj, surveycore::survey_replicate)) {
  testthat::expect_true(is.character(obj@variables$weights))
  testthat::expect_true(is.character(obj@variables$repweights))
  testthat::expect_true(length(obj@variables$repweights) >= 2L)
  testthat::expect_true(
    all(obj@variables$repweights %in% names(obj@data))
  )
  testthat::expect_true(
    all(vapply(obj@variables$repweights,
               function(r) is.numeric(obj@data[[r]]), logical(1)))
  )
}
```

---

## XV. Quality Gates

Phase 1 is complete when:

- [ ] All six `create_*_weights()` functions pass `devtools::check()` with 0 errors,
  0 warnings, ≤2 pre-approved notes
- [ ] `create_replicate_weights()` and `as_taylor_design()` pass check
- [ ] Test coverage ≥ 98% for `R/replicate-weights.R` and `R/conversion.R`
- [ ] All error classes in §XIII are in `plans/error-messages.md`
- [ ] All test blocks listed in §XIV are implemented and passing
- [ ] Numerical correctness tests against svrep pass (at `1e-8` tolerance)
- [ ] `VENDORED.md` updated (or created) if any algorithms are vendored
- [ ] `plans/decisions-phase-1.md` populated with all Stage 2/3/4 resolutions
- [ ] NEWS.md updated with v0.2.0 section
- [ ] DESCRIPTION bumped to `0.2.0`
- [ ] All GAPs in §§III–XI resolved and decisions logged

---

## XVI. Integration with Downstream Packages

### surveytidy

`surveytidy` provides dplyr verbs for survey objects. `survey_replicate` from
Phase 1 must not break surveytidy's existing dispatch. If surveytidy methods
dispatch on `survey_base` (parent of both `survey_taylor` and `survey_replicate`),
Phase 1 outputs should work without surveytidy changes.

> ⚠️ GAP: Confirm that surveytidy's dplyr verbs handle `survey_replicate` input
> correctly, or document what breaks.

### Phase 2 (`calibrate_to_survey()`)

Phase 2 requires `survey_replicate` input (primary design must have replicate
weights). Phase 1's output class matrix must be compatible with Phase 2's input
requirements.

---

## XVII. Open GAPs Summary

### Resolved

| GAP | Section | Decision |
|-----|---------|----------|
| RWYB draw count | §III.b | Fixed: m_h = n_h − 1 |
| Fay scale factor | §II.d, §VI | Fixed: `1 / (n_rep * (1 - rho)^2)` |
| `mse = FALSE` behavior | all functions | Documented in all mse argument entries |
| SD1/SD2 gen-boot formulas | §VII | Specified: Ash 2014 quadratic forms; svrep oracle |
| SDR algorithm, scale, constraint | §VIII | Fixed: Hadamard formula, scale=4/R, multiple-of-4, sort_var |
| `as_taylor_design()` Taylor structure recovery | §X | Decision A: store in `@variables` |
| Bootstrap variance for `survey_nonprob` | §XI | Split: simple bootstrap in Phase 1; re-calibrated bootstrap in Phase 2.5. Confirmed 2026-03-12 |
| `create_brr_weights()` vs `create_fay_weights()` distinction | §V.b + §VI | Option C — BRR and Fay are separate functions. `fay_rho` removed from `create_brr_weights()`. Confirmed 2026-03-12 |

### Open (carry to Stage 2 Resolve Part 2)

| GAP | Section | Blocking? | Resolution |
|-----|---------|-----------|------------|
| JK1 for stratified designs: error or support with per-stratum rscales? | §IV.b | Yes | Stage 2 |
| Bootstrap single-PSU stratum handling | §III.b | Yes | Stage 2 |
| Bootstrap unclustered design support (`survey_srs` / `survey_nonprob`) | §III.c | Yes | Stage 2 |
| JKn stratified grouping: within-stratum vs. across all strata | §IV.b | Yes | Stage 2 |
| Vendoring decision for algorithm implementations | §II.b | No | Stage 2 |
| `create_jackknife_weights()` replicates for delete-1 | §IV | Yes | Stage 3 |
| Many-replicate warning threshold for delete-1 jackknife | §IV.b | No | Stage 3 |
| surveytidy compatibility with `survey_replicate` | §XVI | No | Stage 3 |
