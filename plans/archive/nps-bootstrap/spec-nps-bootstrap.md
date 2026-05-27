# surveywts NPS Bootstrap — Implementation Spec

**Version:** 1.0
**Date:** 2026-05-22
**Status:** Stage 1 Draft — pending Stage 4 issue resolution
**Methodology:** Locked v1.1 (2026-05-20); see `plans/spec-methodology-nps-bootstrap.md`
**Spec review:** Pass 1 complete (2026-05-22); see `plans/spec-review-nps-bootstrap.md`

This document is the source of truth for implementing the NPS bootstrap types
(`"quasi-randomization"` and `"hybrid"`) in `create_bootstrap_weights()`.
It supersedes the methodology document for all implementation decisions.
The methodology document (locked v1.1) is the authoritative reference for
statistical justifications and algorithm derivations; this spec provides the
complete function contract, error specifications, test plan, and engineering
decisions.

---

## I. Scope

### Delivered in this release

| Item | Details |
|------|---------|
| `type = "quasi-randomization"` | New option for `create_bootstrap_weights()`; NPS-only |
| `type = "hybrid"` | New option; NPS-only; functional implementation deferred until `mass_imputation()` exists — error stub only in this release |
| `reference_sample` argument | New argument; accepts `survey_taylor` or `NULL` |
| `replicates = NULL` default | Replaces `replicates = 500L`; resolved to 200L (NPS) or 500L (prob-sample) internally |
| `surveywts_warning_reference_sample_ignored` | Warning emitted when `reference_sample` is supplied with a probability-sample type |
| Bootstrap history entry | `operation = "bootstrap_weights"` appended to `@metadata@weighting_history` |

### Not delivered in this release

| Item | Reason |
|------|---------|
| Analysis functions for replicate-weighted `survey_nonprob` | Future release; see §V for honest deferred-use statement |
| Hybrid bootstrap full implementation | Requires `mass_imputation()`, which is not yet implemented |
| Population total estimator in hybrid | Deferred with `mass_imputation()` scope |
| Auxiliary-weighted mass imputation path | Deferred with `mass_imputation()` scope |

### Input / output class matrix

| Input class | `type` | Output class | Notes |
|-------------|--------|-------------|-------|
| `survey_taylor` | Probability-sample types | `survey_replicate` | Unchanged behavior |
| `survey_nonprob` | Probability-sample types | `survey_replicate` | Unchanged behavior |
| `survey_nonprob` | `"quasi-randomization"` | `survey_nonprob` | New; repwt columns in `@data` |
| `survey_nonprob` | `"hybrid"` | — | Error: not yet implemented (stub) |
| `survey_taylor` | `"quasi-randomization"` or `"hybrid"` | — | Error: NPS types require `survey_nonprob` |
| `weighted_df` | `"quasi-randomization"` or `"hybrid"` | — | Error: NPS types require `survey_nonprob` |
| `data.frame` | `"quasi-randomization"` or `"hybrid"` | — | Error: caught by existing `.validate_replicate_input()` |

---

## II. Architecture

### Source file changes

```
R/replicate-weights.R   — primary changes
  ├── create_bootstrap_weights()     modified: new args, new type dispatch
  ├── .quasi_randomization_bootstrap()  new private helper
  └── (no .hybrid_bootstrap() yet — deferred until mass_imputation() release)

No other source files change in this release.
```

### Dependency map

```
.quasi_randomization_bootstrap()
  └── reads: @metadata@weighting_history  (ipw entry, optional rake/calibrate entries)
  └── calls: ipw()        (from R/nonprob-ipw.R)
  └── calls: rake()       (from R/rake.R, if in history)
  └── calls: calibrate()  (from R/calibrate.R, if in history)
```

**Q2 resolution (in-loop rake/calibrate compatibility):** `rake()` and
`calibrate()` accept `survey_nonprob` input and return `survey_nonprob`
(confirmed by reading `R/rake.R:101`). A `survey_nonprob` constructed
in-loop from the resampled NPS rows with the original weight column and
an empty `@metadata@weighting_history` is valid input for both functions.
No workaround or internal-engine call is required.

---

## III. `create_bootstrap_weights()` — Modified API

### Signature

```r
create_bootstrap_weights <- function(
  data,
  replicates = NULL,
  ...,
  type = c(
    "Rao-Wu-Yue-Beaumont", "Rao-Wu", "Antal-Tille",
    "Preston", "Canty-Davison",
    "quasi-randomization", "hybrid"
  ),
  reference_sample = NULL,
  mse = c("mse", "chrostowski", "uncentered"),
  seed = NULL
)
```

**Change from current implementation:** `replicates` default changed from
`500L` to `NULL`. `mse` changed from `logical(1)` to `character(1)` —
existing callers using `mse = TRUE` must update to `mse = "mse"` (the new
default); `mse = FALSE` must update to `mse = "uncentered"`. The
`reference_sample` argument is new. R does not support argument defaults
that depend on other arguments; `NULL` is resolved internally (see §III.A).

### Argument table

| Argument | Type | Default | Description |
|----------|------|---------|-------------|
| `data` | `survey_taylor` or `survey_nonprob` | — | Survey design object. `survey_replicate`, `data.frame`, `weighted_df` → error. |
| `replicates` | `integer(1)` or `NULL` | `NULL` | Number of bootstrap replicates. `NULL` resolves to `200L` for NPS types and `500L` for probability-sample types. Must be ≥ 2. Whole-number doubles coerced silently. |
| `...` | — | — | Must be empty. Forces all subsequent arguments to be named. |
| `type` | `character(1)` | `"Rao-Wu-Yue-Beaumont"` | Bootstrap variant. See §III.B for NPS type details. |
| `reference_sample` | `survey_taylor` or `NULL` | `NULL` | Reference probability sample for NPS types. When non-`NULL`, takes precedence over any reference design stored in `@metadata@weighting_history`. Ignored (with a warning) when `type` is a probability-sample type. `survey_replicate` → error. |
| `mse` | `character(1)` | `"mse"` | Variance formula to use when computing bootstrap variance from replicate weights. `"mse"`: mean squared deviation from the full-sample estimate, `(1/B) Σ (θ̂^(b) − θ̂)²` (Kolenikov 2014 §4.6). `"chrostowski"`: `(1/(B−1)) Σ (θ̂^(b) − θ̂)²` (Chrostowski et al. 2025 Eq. 5). `"uncentered"`: standard sample variance centered on the bootstrap mean, `(1/(B−1)) Σ (θ̂^(b) − θ̄^(B))²`. For probability-sample types, `"mse"` maps to `TRUE` and `"uncentered"` maps to `FALSE` in the `svrep` call; `"chrostowski"` is NPS-only and errors with probability-sample types. |
| `seed` | `integer(1)` or `NULL` | `NULL` | RNG seed. When non-`NULL`, `set.seed(seed)` is called once immediately before the bootstrap loop (or before the `svrep` call for probability-sample types), controlling the entire random sequence. Caller's global RNG state is not restored (unlike the existing `.convert_and_call()` behavior — see §III.C). |

### A. `replicates` resolution

```r
# First validation step (in create_bootstrap_weights() body, before type dispatch):
type <- rlang::arg_match(type)
if (is.null(replicates)) {
  replicates <- if (type %in% c("quasi-randomization", "hybrid")) 200L else 500L
}
replicates <- .validate_replicates_arg(replicates)
```

**`@param` documentation for `replicates`:**
> `integer(1)` or `NULL`. Number of bootstrap replicates. Default `NULL`
> resolves to `200L` for `type = "quasi-randomization"` and `type = "hybrid"`,
> and `500L` for all probability-sample types. For final published estimates
> using NPS types, `replicates = 500L` is recommended. Must be ≥ 2.
> Whole-number doubles (e.g., `500`) are coerced to integer silently.

### B. Type dispatch

After argument validation, dispatch based on `type`:

```r
if (type %in% c("quasi-randomization", "hybrid")) {
  # NPS path — bypasses .convert_and_call() entirely
  if (!S7::S7_inherits(data, surveycore::survey_nonprob)) {
    # error: surveywts_error_qr_bootstrap_requires_nonprob
    #     or surveywts_error_hybrid_bootstrap_requires_nonprob
  }
  if (!is.null(reference_sample)) {
    .validate_reference_sample(reference_sample)
  }
  if (type == "quasi-randomization") {
    .quasi_randomization_bootstrap(data, replicates, reference_sample, mse, seed)
  } else {
    # type == "hybrid": error stub until mass_imputation() is implemented
    cli::cli_abort(...)
  }
} else {
  # Probability-sample path — existing behavior
  if (!is.null(reference_sample)) {
    cli::cli_warn(...)  # surveywts_warning_reference_sample_ignored
  }
  .convert_and_call(...)
}
```

### C. `seed` behavior change note

The existing probability-sample path uses `withr::local_seed(seed)` inside
`.convert_and_call()`, which restores the caller's RNG state on exit. The NPS
path uses `set.seed(seed)` directly before the loop — the caller's RNG state
is NOT restored. This difference should be noted in the `@param seed`
documentation: "For NPS types, `set.seed()` is called once and the caller's
RNG state is not restored; for probability-sample types, the seed is applied
via `withr::local_seed()` and the caller's state is restored."

> ⚠️ **Implementation note:** If RNG restoration for NPS types is desired,
> `withr::with_seed(seed, ...)` can be used as a wrapper. The spec as written
> uses `set.seed()` for simplicity; the implementation may use
> `withr::with_seed()` provided reproducibility is preserved.

### D. Output contract — NPS types

For `type = "quasi-randomization"`, the return value is a `survey_nonprob` with:

- **`@data`**: original `@data` columns PLUS `repwt_1`...`repwt_B` columns containing replicate weights for each draw. Each `repwt_b` column contains the final calibrated weight for unit i in draw b (the weight produced by the last step of the weighting history in that draw).
- **`@variables$weights`**: unchanged (same as the input `survey_nonprob`).
- **`@variables$repweights`**: new key added to the `@variables` list; character vector `c("repwt_1", ..., "repwt_B")`.
- **`@metadata@weighting_history`**: input history PLUS one new entry (see §VI).
- All other `@data`, `@variables`, `@metadata`, `@calibration`, and `@reference_sample` properties: preserved from the input.

**Analysis path (deferred-use statement):** Replicate weights stored in
`repwt_1`...`repwt_B` columns of `@data` are intended for use by a future
bootstrap variance analysis function. This release does not provide an analysis
function for replicate-weighted `survey_nonprob` objects. Bootstrap variance can
be computed manually by applying the estimator of interest to each replicate's
weights and averaging the squared deviations from the full-sample estimate.

**`@details` note (required in roxygen):** SRSWR resampling cannot replicate
the original NPS recruitment mechanism; bootstrap standard errors from
`"quasi-randomization"` likely understate true sampling variability (AAPOR
2022, §4), and this understatement is not reduced by increasing `replicates`.

---

## IV. Algorithm — Quasi-Randomization Bootstrap

Internal helper: `.quasi_randomization_bootstrap(data, replicates, reference_sample, mse, seed)`.
Called from `create_bootstrap_weights()` when `type = "quasi-randomization"` and
input validation passes.

### Prerequisites (validated before loop begins)

1. An `ipw` history entry exists in `data@metadata@weighting_history`
   (`operation == "ipw"` in some entry). If absent:
   → `surveywts_error_qr_bootstrap_no_ipw_history`

2. A reference design is accessible: `reference_sample` is non-NULL, OR
   the `ipw` history entry has `reference_design` that is non-NULL.
   If neither: → `surveywts_error_qr_bootstrap_no_reference`

3. `reference_sample` takes precedence over `ipw_entry$reference_design` when
   both are present.

### Level A / Level B detection

Read `targets_from_reference` from the `ipw` history entry:
- `targets_from_reference = FALSE` → **Level A** (reference held fixed)
- `targets_from_reference = TRUE` → **Level B** (reference resampled)

The `targets_from_reference` flag is set by `rake()` and `calibrate()` when
`reference_design` is non-NULL (per those functions' existing behavior, which
stores this flag in their history entries). The bootstrap reads it from the
**rake or calibrate** history entry (the last calibration step), not from the
`ipw` entry. If no calibration step follows `ipw`, `targets_from_reference` is
`FALSE` (Level A is used).

> **Implementation note:** The `ipw` history entry in the methodology doc
> includes `targets_from_reference` as a field. In practice, this flag is set
> by the downstream `rake()` / `calibrate()` call, not by `ipw()` itself.
> The implementation should read `targets_from_reference` from the last
> calibration history entry (if one exists). If no calibration entry follows
> `ipw`, use `FALSE` (Level A).

### History replay structure

Before the loop, extract from `data@metadata@weighting_history`:

```r
ipw_entry    <- <the entry with operation == "ipw">
calib_entry  <- <the last entry with operation %in% c("raking", "calibration"), or NULL>
ref_design   <- reference_sample %||% ipw_entry$reference_design
targets_from_ref <- if (!is.null(calib_entry)) isTRUE(calib_entry$targets_from_reference) else FALSE
```

### Algorithm — Level A (reference held fixed)

**Setup:** `set.seed(seed)` immediately before the loop (if seed non-NULL).

**For each draw b = 1, …, B:**

1. **Resample NPS.** Draw `n_A` row indices from `1:n_A` with replacement
   (SRS bootstrap). Construct `S_A_b` as a data frame with `n_A` rows by
   subsetting `data@data` at those indices. Each unit i appears `m_i^(b)`
   times. All columns from `data@data` are carried into each row of `S_A_b`,
   but within-draw `ipw()` ignores existing weight columns and computes fresh
   `1 / p_hat` weights from scratch.

2. **Re-run `ipw()`.** Call:
   ```r
   ipw_result_b <- ipw(
     data           = S_A_b,
     reference      = ref_design,  # FIXED (not resampled)
     selection      = ipw_entry$formula,
     method         = ipw_entry$method,
     missing_method = ipw_entry$missing_method,
     trim           = ipw_entry$trim,
     wt_name        = data@variables$weights
   )
   ```
   `ipw_result_b` is a `survey_nonprob` with re-estimated IPW weights.

   **Trim note:** When `trim = TRUE`, the trimming threshold is re-estimated
   from within-draw weights (`median(w) + 5 * IQR(w)`) — not carried over from
   the full-sample call. This propagates trim-threshold uncertainty through the
   bootstrap and is the correct behavior.

3. **Re-run calibration (if in history).** If `calib_entry` is non-NULL:
   ```r
   calib_result_b <- rake(   # or calibrate(), per calib_entry$operation
     data    = ipw_result_b,
     margins = calib_entry$margins,  # FIXED population benchmarks
     ...                             # same params as stored in calib_entry
   )
   ```

4. **Extract replicate weight vector.** The replicate weight for draw b is the
   final weight column from the last step:
   - If calibration was re-run: `calib_result_b@data[[data@variables$weights]]`
   - If no calibration: `ipw_result_b@data[[data@variables$weights]]`

5. **Draw failure handling.** If any step in the draw raises an error (model
   non-convergence, degenerate propensity scores, calibration divergence): catch
   the error, increment `failed_draws` counter, and skip this draw. Do not store
   a replicate weight vector for failed draws.

**Post-loop:**
- If `failed_draws > 0.1 * B` (more than 10% failure rate):
  emit `surveywts_warning_bootstrap_draws_failed` with the count.
- The number of stored replicate columns = `B - failed_draws`. Document in the
  history entry as `draws_used`.
- If `failed_draws >= B` (all draws failed):
  error `surveywts_error_bootstrap_all_draws_failed`.

### Algorithm — Level B (reference resampled)

Level B differs from Level A in steps 1–3 only:

1. **Resample NPS.** Same as Level A.

2. **Resample reference.** `set.seed(seed)` is called once, immediately before
   `svrep::as_bootstrap_design(ref_design, replicates = B)` (if `seed`
   non-NULL). The reference pre-computation and the main NPS resample loop
   both draw from this initialized stream sequentially. "Independent" means
   each draw's NPS resample and reference replicate are drawn from separate
   positions in the stream — not that they use separate seeds. Given the same
   `seed`, results are exactly reproducible. Do not call `set.seed()` a
   second time before the main loop.

   Pre-compute B reference bootstrap replicates before the main loop using
   `svrep::as_bootstrap_design(ref_design, replicates = B)`. For draw b,
   extract the b-th replicate weight vector from the pre-computed reference
   bootstrap. Construct the resampled reference data frame: the original
   `ref_design@data` rows with replicate weights substituted for design
   weights. Pass this as a minimal `survey_taylor` to `ipw()`.

3. **Re-run `ipw()`.** Same as Level A, but pass the resampled reference design
   from step 2 instead of the fixed `ref_design`.

4. **Re-calibrate with perturbed targets.** Re-estimate calibration targets from
   the resampled reference `S_B_b`:
   - For `type = "prop"` margins:
     `t[j,c]^(b) = Σ_{k ∈ S_B_b, x[j,k]=c} w_k^B / Σ_{k ∈ S_B_b} w_k^B`
     where `w_k^B` are the reference design weights for unit k in the resampled
     reference.
   - For `type = "count"` margins:
     `t[j,c]^(b) = Σ_{k ∈ S_B_b, x[j,k]=c} w_k^B`
   Re-run `rake()` / `calibrate()` with the perturbed targets.

5–6. Same as Level A steps 4–5.

### Full-sample estimate (θ̂)

Used in the MSE variance formula. Computed from the original (pre-bootstrap)
`data` using the weights produced by the final step in `data@metadata@weighting_history`:
- If a calibration step follows `ipw` in history: use the final calibrated IPW
  weight column from `data@data[[data@variables$weights]]`
- If no calibration step: use the IPW weight column directly

`θ̂` is computed outside the loop and held fixed for all replicates.

### Variance formula

**`mse = "mse"` (default):**
```
V̂(θ̂) = (1/B) Σ_{b=1}^{B} (θ̂^(b) - θ̂)²
```
Empirical mean squared deviation from the full-sample estimate. The `1/B`
divisor is used because the center (θ̂) is a known fixed quantity, not
estimated from the same data as the bootstrap draws — Bessel correction
does not apply here (Kolenikov 2014 §4.6).

**`mse = "chrostowski"`:**
```
V̂(θ̂) = (1/(B-1)) Σ_{b=1}^{B} (θ̂^(b) - θ̂)²
```
Same centering as `"mse"` but with a `1/(B-1)` divisor, as in Chrostowski
et al. (2025) Eq. 5. More conservative; recommended when directly following
that paper's methodology. NPS types only — errors for probability-sample types.

**`mse = "uncentered"`:**
```
V̂(θ̂) = (1/(B-1)) Σ_{b=1}^{B} (θ̂^(b) - θ̄^(B))²
```
where `θ̄^(B) = (1/B) Σ θ̂^(b)`. Standard Bessel-corrected sample variance
centered on the bootstrap mean rather than the full-sample estimate.

Note: The variance formula applies to any estimator computed using the
replicate weights. The replicate weight columns are the output; the user
applies their estimator to compute `θ̂^(b)` values.

### `S_A^(b)` representation

Within each draw, `S_A^(b)` is constructed as a data frame with `n_A` rows,
where unit i appears `m_i^(b)` times (duplicate rows). Within-draw `ipw()`
receives `S_A_b` as a plain data frame. It does not read or use any weight
column present in those rows; it fits the propensity model on the resampled
units and computes fresh weights as `1 / p_hat`. The IPW weights from the
full-sample call are irrelevant here.

**IPW weight convention:** IPW weights are raw `1 / p_hat` values with no
renormalization step. The sum of weights estimates the population size.

---

## V. Algorithm — Hybrid Bootstrap (Stub)

The hybrid bootstrap (`type = "hybrid"`) is not implemented in this release.
Calling `create_bootstrap_weights()` with `type = "hybrid"` raises:

```r
cli::cli_abort(
  c(
    "x" = "{.code type = \"hybrid\"} is not yet available.",
    "i" = "The hybrid bootstrap requires {.fn mass_imputation}, which is not yet implemented.",
    "v" = "Use {.code type = \"quasi-randomization\"} for IPW-weighted non-probability samples."
  ),
  class = "surveywts_error_hybrid_bootstrap_not_implemented"
)
```

This error is defined in `plans/error-messages.md` and is not a permanent
class — it will be removed when the full hybrid implementation ships.

---

## VI. History Entry

`create_bootstrap_weights()` appends one entry to
`@metadata@weighting_history` for NPS types. Structure:

```r
list(
  step        = length(data@metadata@weighting_history) + 1L,
  operation   = "bootstrap_weights",
  timestamp   = Sys.time(),
  type        = type,          # "quasi-randomization"
  replicates  = B,             # the resolved integer value
  draws_used  = n_successful,  # B minus failed draws
  level       = "A" or "B",    # Level A or Level B detection result
  mse         = mse,            # "mse", "chrostowski", or "uncentered"
  seed        = seed            # NULL if not set
)
```

For the existing probability-sample types, the history entry uses
`operation = "replicate_creation"` (unchanged behavior via `.convert_and_call()`).
NPS types use `operation = "bootstrap_weights"` to distinguish them.

---

## VII. Required `ipw()` History Entry Fields

The quasi-randomization bootstrap reads these fields from the ipw history entry.
The `ipw()` implementation must store an entry with at minimum:

```r
list(
  operation              = "ipw",
  step                   = <integer>,
  timestamp              = Sys.time(),
  formula                = <formula>,         # propensity model formula
  method                 = "logit",           # or "probit", "cloglog"
  missing_method         = "omit",            # or "separate", "impute"
  estimator              = "ht",              # IPW weights are raw 1/p_hat (unnormalized)
  trim                   = c(0.05, 0.95),     # or NULL
  reference_design       = <survey_taylor>,   # stored reference design; may be NULL
  targets_from_reference = FALSE              # set TRUE by downstream rake()/calibrate()
)
```

**`targets_from_reference`**: this field is set by the **`rake()` / `calibrate()`
call** that follows `ipw()` when `reference_design` is non-NULL. The bootstrap
reads it from the calibration history entry (not the ipw entry). If the ipw
entry carries the field, it is read from there as a fallback; but the
calibration entry is authoritative.

**`reference_design = NULL`** in the history entry counts as "no reference
found." The validation error fires when `reference_design` is `NULL` in the
history entry AND `reference_sample` is not provided to `create_bootstrap_weights()`.

---

## VIII. Validation Rules

### New validation rows (additions to existing table)

| Check | Error class |
|-------|-------------|
| `type = "quasi-randomization"` and input is `survey_taylor` | `surveywts_error_qr_bootstrap_requires_nonprob` |
| `type = "quasi-randomization"` and input is `weighted_df` | `surveywts_error_qr_bootstrap_requires_nonprob` |
| `type = "hybrid"` and input is `survey_taylor` | `surveywts_error_hybrid_bootstrap_requires_nonprob` |
| `type = "hybrid"` and input is `weighted_df` | `surveywts_error_hybrid_bootstrap_requires_nonprob` |
| `type = "quasi-randomization"`, no `ipw` operation found in history | `surveywts_error_qr_bootstrap_no_ipw_history` |
| `type = "quasi-randomization"`, no reference found (history `reference_design = NULL` AND `reference_sample` not provided) | `surveywts_error_qr_bootstrap_no_reference` |
| `type = "hybrid"` (any input) | `surveywts_error_hybrid_bootstrap_not_implemented` |
| `reference_sample` is not `NULL` and not `survey_taylor` (includes `survey_replicate`) | `surveywts_error_reference_sample_class` |
| `reference_sample` is non-`NULL` and `type` is a probability-sample type | `surveywts_warning_reference_sample_ignored` (warning, not error) |
| `mse = "chrostowski"` and `type` is a probability-sample type | `surveywts_error_chrostowski_prob_sample` |
| All draws failed (0 successful draws out of B) | `surveywts_error_bootstrap_all_draws_failed` |
| More than 10% of draws failed | `surveywts_warning_bootstrap_draws_failed` (warning, function returns) |

**Clarification on `reference_sample` class check:** The check `reference_sample
is not NULL and not survey_taylor` catches all invalid classes including
`survey_replicate`. The message template should call out `survey_replicate`
explicitly since it is the most common mistake:

```r
cli::cli_abort(
  c(
    "x" = "{.arg reference_sample} must be a {.cls survey_taylor}, not {.cls {class(reference_sample)[[1]]}}.",
    "i" = paste0(
      if (S7::S7_inherits(reference_sample, surveycore::survey_replicate))
        "A replicate-weighted reference survey is not supported here. "
      else "",
      "Only {.cls survey_taylor} (Taylor-series linearization design) is accepted."
    ),
    "v" = if (S7::S7_inherits(reference_sample, surveycore::survey_replicate))
      "Use {.fn calibrate_to_survey} for the Opsomer-Erciulescu approach with a replicate-weighted reference."
    else
      "Pass a {.cls survey_taylor} created with {.fn surveycore::as_survey}."
  ),
  class = "surveywts_error_reference_sample_class"
)
```

---

## IX. New Error and Warning Classes

All classes below must be added to `plans/error-messages.md` before
implementation begins.

### Errors

| Class | Thrown by | Trigger | `"x"` template |
|-------|-----------|---------|----------------|
| `surveywts_error_qr_bootstrap_requires_nonprob` | `create_bootstrap_weights()` | `type = "quasi-randomization"` with non-`survey_nonprob` input | `"{.code type = 'quasi-randomization'} requires a {.cls survey_nonprob}; got {.cls {class(data)[[1]]}}."` |
| `surveywts_error_hybrid_bootstrap_requires_nonprob` | `create_bootstrap_weights()` | `type = "hybrid"` with non-`survey_nonprob` input | `"{.code type = 'hybrid'} requires a {.cls survey_nonprob}; got {.cls {class(data)[[1]]}}."` |
| `surveywts_error_qr_bootstrap_no_ipw_history` | `.quasi_randomization_bootstrap()` | No `operation = "ipw"` entry in `@metadata@weighting_history` | `"No {.code ipw()} step found in the weighting history of {.arg data}."` |
| `surveywts_error_qr_bootstrap_no_reference` | `.quasi_randomization_bootstrap()` | `reference_design = NULL` in ipw history entry AND `reference_sample` not provided | `"A reference probability sample is required for {.code type = 'quasi-randomization'}."` |
| `surveywts_error_hybrid_bootstrap_not_implemented` | `create_bootstrap_weights()` | `type = "hybrid"` (any input) | `"{.code type = 'hybrid'} is not yet available."` |
| `surveywts_error_reference_sample_class` | `create_bootstrap_weights()` | `reference_sample` is non-`NULL` and not `survey_taylor` | `"{.arg reference_sample} must be a {.cls survey_taylor}, not {.cls {class(reference_sample)[[1]]}}."` |
| `surveywts_error_chrostowski_prob_sample` | `create_bootstrap_weights()` | `mse = "chrostowski"` and `type` is a probability-sample type | `"{.code mse = \"chrostowski\"} is only available for NPS types ({.code type = \"quasi-randomization\"})."` |
| `surveywts_error_bootstrap_all_draws_failed` | `.quasi_randomization_bootstrap()` | 0 successful draws out of B | `"All {B} bootstrap draws failed; no replicate weights could be produced."` |

### Warnings

| Class | Thrown by | Trigger | `"!"` template |
|-------|-----------|---------|----------------|
| `surveywts_warning_reference_sample_ignored` | `create_bootstrap_weights()` | `reference_sample` non-`NULL` and `type` is a probability-sample type | `"{.arg reference_sample} is ignored for {.code type = '{type}'}."` |
| `surveywts_warning_bootstrap_draws_failed` | `.quasi_randomization_bootstrap()` | More than 10% of draws failed | `"{failed_draws} of {B} bootstrap draws failed and were skipped."` |

---

## X. Test Plan

File: `tests/testthat/test-08-nps-bootstrap.R`

### Happy-path tests

**Block 1: quasi-randomization Level A — `survey_nonprob` with ipw + rake history**
```
data    : make_surveywts_data(seed=1) |> ipw(...) |> rake(...)
                 with targets_from_reference = FALSE
type    : "quasi-randomization"
replicates : 50L (fast for tests)
Expected:
  - Return class is survey_nonprob
  - test_invariants(result) passes
  - @data has 50 repwt_1...repwt_50 columns; all numeric, all positive
  - @variables$repweights == c("repwt_1", ..., "repwt_50")
  - @variables$weights unchanged
  - @metadata@weighting_history has one new "bootstrap_weights" entry
  - history entry: type="quasi-randomization", replicates=50, level="A"
```

**Block 2: quasi-randomization Level B — `survey_nonprob` with ipw + rake history, `targets_from_reference = TRUE`**
```
data    : make_surveywts_data(seed=2) |> ipw(reference_design=ref) |>
                 rake(..., reference_design=ref)
type    : "quasi-randomization"
replicates : 50L
Expected:
  - history entry level = "B"
  - repwt columns present as in Block 1
```

**Block 3: `replicates = NULL` default resolution**
```
- NULL + prob-sample type → resolves to 500L (check @metadata history params)
- NULL + "quasi-randomization" → resolves to 200L
```

**Block 4: `seed` reproducibility**
```
Two calls with same seed produce identical repwt_1...repwt_B columns.
Two calls with different seeds produce different repwt_1...repwt_B columns.
```

**Block 5: `reference_sample` override**
```
data has ipw history with ref design A.
Call with reference_sample = ref_B (different survey_taylor).
ipw() is re-called with ref_B, not ref design A from history.
(Test via repwt column differences when two references differ meaningfully.)
```

**Block 6: probability-sample types unchanged**
```
Existing test patterns for Rao-Wu, etc. still pass.
No behavioral change.
```

### Error-path tests (dual pattern: class= + snapshot)

One block per new error class from §IX:

| Block | Call | Expected class |
|-------|------|---------------|
| E1 | `create_bootstrap_weights(survey_taylor_obj, type="quasi-randomization")` | `surveywts_error_qr_bootstrap_requires_nonprob` |
| E2 | `create_bootstrap_weights(weighted_df_obj, type="quasi-randomization")` | `surveywts_error_qr_bootstrap_requires_nonprob` |
| E3 | `create_bootstrap_weights(survey_taylor_obj, type="hybrid")` | `surveywts_error_hybrid_bootstrap_requires_nonprob` |
| E4 | `create_bootstrap_weights(nonprob_no_ipw_history, type="quasi-randomization")` | `surveywts_error_qr_bootstrap_no_ipw_history` |
| E5 | `create_bootstrap_weights(nonprob_with_ipw_no_ref, type="quasi-randomization")` (no reference_sample) | `surveywts_error_qr_bootstrap_no_reference` |
| E6 | `create_bootstrap_weights(nonprob, type="hybrid")` | `surveywts_error_hybrid_bootstrap_not_implemented` |
| E7 | `create_bootstrap_weights(nonprob, type="quasi-randomization", reference_sample=survey_replicate_obj)` | `surveywts_error_reference_sample_class` |
| E8 | `create_bootstrap_weights(nonprob, type="quasi-randomization", reference_sample=list())` | `surveywts_error_reference_sample_class` |
| E9 | `create_bootstrap_weights(survey_taylor_obj, type="Rao-Wu", mse="chrostowski")` | `surveywts_error_chrostowski_prob_sample` |

### Warning-path tests

| Block | Call | Expected class |
|-------|------|---------------|
| W1 | `create_bootstrap_weights(nonprob, type="Rao-Wu", reference_sample=ref)` | `surveywts_warning_reference_sample_ignored` |
| W2 | degenerate NPS that forces >10% draw failures | `surveywts_warning_bootstrap_draws_failed` |

### Edge-case tests

**Block EC1: Very small NPS (n = 10)**
```
A survey_nonprob with 10 rows + ipw + rake history.
create_bootstrap_weights(..., type="quasi-randomization", replicates=20L)
→ completes without error; 20 repwt columns present.
```

**Block EC2: All draws fail**
```
Constructed NPS such that every resample produces degenerate propensity scores
(e.g., single-level covariates after resampling).
→ surveywts_error_bootstrap_all_draws_failed.
```

**Block EC3: `mse` variants**
```
- mse = "mse" (default): history entry records mse = "mse"
- mse = "chrostowski": history entry records mse = "chrostowski"
- mse = "uncentered": history entry records mse = "uncentered"
- mse = "chrostowski" with a probability-sample type: errors
```

**Block EC4: `seed = NULL` (no error)**
```
create_bootstrap_weights(..., type="quasi-randomization", seed=NULL, replicates=10L)
→ completes; result is non-deterministic but valid.
```

### Variance correctness test (numerical)

**Block N1: Bootstrap SE within expected range**
```
DGP: Known population (n_pop=10000), known propensities.
NPS: n=500, reference: n=200.
B=500 quasi-randomization bootstrap.
Bootstrap SE for population mean must fall within [0.5 * theoretical_SE, 2 * theoretical_SE].
Tolerance: wide (bootstrap is stochastic); use seed for reproducibility.
skip_if_not_installed() inside block if needed.
```

---

## XI. Quality Gates

All of the following must be true before this feature is considered done:

- [ ] `devtools::check()` passes with 0 errors, 0 warnings, ≤ 2 notes
- [ ] `devtools::test()` passes; no test failures
- [ ] All new error/warning classes added to `plans/error-messages.md`
- [ ] All error-path tests use dual pattern (class= + snapshot) per `testing-standards.md`
- [ ] Bootstrap history entry present in all quasi-randomization outputs
- [ ] `@variables$repweights` populated on all quasi-randomization outputs
- [ ] `replicates = NULL` resolves to 200L for NPS types and 500L for prob-sample types
- [ ] `seed` produces identical replicate columns on identical calls
- [ ] `reference_sample` takes precedence over stored reference in ipw history
- [ ] `surveywts_warning_reference_sample_ignored` fires for all 5 probability-sample types
- [ ] Test coverage ≥ 98% on new code in `R/replicate-weights.R`
- [ ] `plans/error-messages.md` updated with all new classes before PR opens
- [ ] `R CMD check` note count ≤ 2 (pre-approved notes only)

---

## XII. Integration Notes

- **`ipw()` (R/nonprob-ipw.R):** History entry must include at minimum the
  fields listed in §VII. No changes to `ipw()` are required in this release;
  the bootstrap reads the existing history entry. If `ipw()` does not store
  `targets_from_reference`, the bootstrap defaults to Level A.

- **`rake()` / `calibrate()`:** No changes required. Both accept `survey_nonprob`
  and return `survey_nonprob`, which is sufficient for the in-loop calls. The
  `reference_design` argument to `rake()` / `calibrate()` sets
  `targets_from_reference = TRUE` in their history entries; the bootstrap reads
  this flag to detect Level B.

- **`replicate-dispatch.R`:** No changes needed. The dispatcher for
  `create_replicate_weights()` passes through to `create_bootstrap_weights()`,
  which routes NPS types correctly.

- **`svrep` (reference resampling):** Level B uses
  `svrep::as_bootstrap_design()` to resample the reference design. The `svrep`
  package is already in Imports. No new dependency is introduced.

---

## XIII. Open Questions Resolved

All four open design questions from the methodology document are resolved.
See `plans/decisions-nps-bootstrap.md` for the full log.

| Q# | Question | Resolution |
|----|----------|------------|
| Q1 | Where do new types live in `replicate-weights.R`? | Option A: private helpers `.quasi_randomization_bootstrap()` etc., bypassing `.convert_and_call()`. |
| Q2 | Can `rake()` / `calibrate()` be called in-loop with a minimal `survey_nonprob`? | Confirmed YES: `rake()` accepts `survey_nonprob` input (`R/rake.R:101`). No workaround needed. |
| Q3 | How is `targets_from_reference` detected? | Read from the last calibration history entry. The calibration functions (`rake()`, `calibrate()`) set this flag when `reference_design` is non-NULL. |
| Q4 | What should the default `replicates` be for NPS types? | 200L, with documentation recommending 500L for final estimates. See `decisions-nps-bootstrap.md`. |
