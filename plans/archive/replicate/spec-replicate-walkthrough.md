# Replicate Spec Walkthrough: `spec-replicate.md`

**Generated:** 2026-03-16
**Source:** `plans/spec-replicate.md` (v0.2)

Phase 1 ships `v0.2.0`. Its core purpose: **take a survey design object and produce replicate weights** for variance estimation. It does not estimate variances — it only creates the weights that make variance estimation possible.

---

## Exported Functions (8 total)

### The 6 `create_*_weights()` Functions

All six live in `R/replicate-weights.R`. They all follow the same validation order:
1. Input class check
2. `replicates` argument validity (where applicable)
3. Method-specific design requirements

All return a `survey_replicate` via `surveycore::as_survey_replicate()`.

---

**`create_bootstrap_weights(data, replicates = 500L, type = c("Rao-Wu-Yue-Beaumont", "standard"), mse = TRUE)`**

Two bootstrap variants:
- **Rao-Wu-Yue-Beaumont** (default): For each stratum with n_h PSUs, draws n_h − 1 PSUs with replacement. The replication factor is `(n_h / (n_h - 1)) * m*_{hi}`, where `m*_{hi}` is how many times PSU i was drawn. Drawing n_h − 1 (not n_h) ensures the expected value is 1.
- **Standard**: Draws n_h PSUs with replacement; factor = raw draw count. Slightly biased for small strata.

Accepts `survey_taylor`, `survey_srs`, and `survey_nonprob` (simple bootstrap — no re-calibration per replicate). Sets `@variables$type = "bootstrap"` and `@variables$scale = 1 / replicates`.

> **Open GAP:** How to handle single-PSU strata and unclustered designs (`survey_srs`/`survey_nonprob`). These inputs are accepted but behavior is pending resolution.

---

**`create_jackknife_weights(data, type = c("delete-1", "random-groups"), replicates = NULL, mse = TRUE)`**

Two jackknife variants:
- **Delete-1 (JK1)**: One replicate per PSU. For replicate k (PSU i deleted): PSU i gets factor 0, all other PSUs in the same stratum get `n_h / (n_h - 1)`, PSUs in other strata unchanged. `n_rep` = total PSU count.
- **Random-groups (JKn)**: PSUs divided into `replicates` groups. For group k: PSUs in that group get factor 0, all others get `replicates / (replicates - 1)`. `n_rep` = `replicates` argument.

`replicates = NULL` is valid for delete-1 (computed from design) but throws `surveywts_error_replicates_required_for_jkn` for random-groups.

> **Open GAPs:** JK1 behavior for stratified designs (per-stratum rscales?); JKn grouping strategy (within-stratum vs. across all strata); warning threshold for very large delete-1 designs.

---

**`create_brr_weights(data, mse = TRUE)`**

Balanced Repeated Replication. **Only accepts `survey_taylor` with exactly 2 PSUs per stratum** (a "paired PSU" design). `survey_srs` and `survey_nonprob` always error.

Uses a Hadamard matrix H of size `n_rep × n_strata`. For each replicate row r and stratum h: if H[r,h] = +1, PSU 1 gets factor 2 and PSU 2 gets factor 0; if H[r,h] = −1, PSU 2 gets factor 2 and PSU 1 gets factor 0. `n_rep` = smallest multiple of 4 ≥ number of strata.

---

**`create_fay_weights(data, replicates = 100L, rho = 0.5, mse = TRUE)`**

Fay's modified BRR. Same paired-PSU requirement as BRR. The `rho` coefficient (0 < rho < 1) softens the factors: selected PSU gets `2 - rho`; excluded PSU gets `rho`. Scale: `1 / (replicates * (1 - rho)^2)`.

Errors: `surveywts_error_brr_fay_rho_invalid` if rho ≤ 0 or ≥ 1.

---

**`create_gen_boot_weights(data, replicates = 500L, variance_estimator = c("SD1", "SD2"), mse = TRUE)`**

Generalized bootstrap (Beaumont & Patak 2012). Draws R replicate weight vectors from MVN(1, Σ), where Σ targets the Ash (2014) successive-difference estimator.
- **SD1** (non-circular): `v̂ = (1 − n/N) × n / (2(n−1)) × Σ(ỹ_k − ỹ_{k−1})²`
- **SD2** (circular): adds a wrap-around term connecting the last and first PSU.

**Requires PSU IDs.** `survey_srs` and `survey_nonprob` always error with `surveywts_error_no_psu_ids`. Oracle: `svrep::make_gen_boot_factors()` at 1e-8 tolerance.

---

**`create_sdr_weights(data, replicates = 100L, sort_var = NULL, mse = TRUE)`**

Successive-Difference Replication (Fay & Train 1995). Uses a Hadamard matrix to approximate the successive-difference variance estimator. PSUs must be in their systematic selection order.

Key constraints:
- `replicates` must be a **multiple of 4** (Hadamard constraint); errors with `surveywts_error_sdr_replicates_not_multiple_of_4` otherwise
- `sort_var` specifies the ordering column; if NULL, row order is used; errors if `sort_var` contains NAs
- Accepts `survey_taylor` and `survey_srs`; rejects `survey_nonprob`

Replication factor: `f_{i,r} = 1 + (H[row1(i), r] − H[row2(i), r]) × 2^(−3/2)`. Scale: `4 / n_rep`. Oracle: `svrep::make_sdr_replicate_factors()`.

---

### `create_replicate_weights()` — Dispatcher (`R/conversion.R`)

```r
create_replicate_weights(data, method = c("bootstrap", "jackknife", "brr", "fay", "gen-boot", "sdr"), ...)
```

A thin dispatch layer. Maps `method` to the appropriate `create_*_weights()` function and forwards `...`. All errors from the underlying function propagate as-is, plus class-level errors (already-replicate, not-survey-design) checked first.

---

### `as_taylor_design()` — Conversion (`R/conversion.R`)

```r
as_taylor_design(data)
```

Converts a `survey_replicate` back to `survey_taylor`. The replicate weight columns are **dropped**. Works because `create_*_weights()` stores Taylor round-trip keys in `@variables`:

```r
@variables$ids    # PSU ID column names
@variables$strata # stratum column name
@variables$fpc    # FPC column name
@variables$nest   # nest flag
```

If input is already `survey_taylor`: returns it unchanged with warning `surveywts_warning_already_taylor`. Always also warns `surveywts_warning_taylor_loses_variance` when converting from replicate (informational: variance capability is lost).

> **Critical prerequisite:** This design requires `surveycore::survey_replicate@variables` to accept arbitrary list keys beyond the 9 predefined ones. Must verify against surveycore API before implementation begins.

---

## Internal Helpers (4 shared, in `R/utils.R`)

| Helper | Signature | Role |
|--------|-----------|------|
| `.extract_taylor_structure(data)` | `(data)` | Extracts PSU ids, strata, weights, FPC, nest flag from a `survey_taylor`; returns named list |
| `.validate_replicate_count(replicates, min = 2L)` | `(replicates, min)` | Validates `replicates` is a positive integer ≥ min; throws `surveywts_error_replicates_not_positive` |
| `.build_survey_replicate(data, repweights, type, scale, rscales, mse)` | 6 args | Adds rep columns to data, calls `surveycore::as_survey_replicate()`, writes Taylor round-trip keys into `@variables` |
| `.make_rep_col_names(prefix, n)` | `("rep", n)` | Returns `c("rep_1", "rep_2", ..., "rep_n")` |

Phase-local helpers (used only within `replicate-weights.R`) are defined at the top of that file.

---

## Input/Output Class Matrix

| Input | `create_bootstrap` | `create_jackknife` | `create_brr` | `create_fay` | `create_gen_boot` | `create_sdr` |
|-------|-------------------|-------------------|--------------|--------------|------------------|--------------|
| `survey_taylor` | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| `survey_srs` | ✅ (obs as PSUs) | ✅ (obs as PSUs) | ❌ brr_requires_paired | ❌ brr_requires_paired | ❌ no_psu_ids | ✅ (obs as ordered units) |
| `survey_nonprob` | ✅ (resamples obs) | ✅ (obs as PSUs) | ❌ brr_requires_paired | ❌ brr_requires_paired | ❌ no_psu_ids | ❌ no_psu_ids |
| `survey_replicate` | ❌ already_replicate | ❌ | ❌ | ❌ | ❌ | ❌ |
| `data.frame`/`weighted_df` | ❌ not_survey_design | ❌ | ❌ | ❌ | ❌ | ❌ |

---

## New Error and Warning Classes (13 total)

### Errors

| Class | When |
|-------|------|
| `surveywts_error_already_replicate` | Input is already `survey_replicate` |
| `surveywts_error_not_survey_design` | Input is `data.frame` or `weighted_df` |
| `surveywts_error_replicates_not_positive` | `replicates` ≤ 1 or non-integer |
| `surveywts_error_no_psu_ids` | No PSU IDs in design |
| `surveywts_error_brr_requires_paired_design` | Not exactly 2 PSUs per stratum, or wrong input class |
| `surveywts_error_brr_fay_rho_invalid` | `rho` ≤ 0 or ≥ 1 |
| `surveywts_error_replicates_required_for_jkn` | JKn used without specifying `replicates` |
| `surveywts_error_sdr_replicates_not_multiple_of_4` | SDR `replicates` not divisible by 4 |
| `surveywts_error_sort_var_has_na` | `sort_var` column contains NA |

### Warnings

| Class | When |
|-------|------|
| `surveywts_warning_already_taylor` | `as_taylor_design()` called on a `survey_taylor` |
| `surveywts_warning_taylor_loses_variance` | Converting replicate → Taylor drops variance capability |
| `surveywts_warning_delete1_many_replicates` | Delete-1 JK produces more replicates than threshold (TBD) |

All must be added to `plans/error-messages.md` before implementation.

---

## File Organization

```
R/
├── replicate-weights.R   # all 6 create_*_weights() + phase-local helpers
├── conversion.R          # create_replicate_weights(), as_taylor_design()
├── vendor/
│   └── replicate-*.R     # vendored algorithms (decision pending)
└── utils.R               # 4 new shared helpers added here
```

---

## Testing Plan

**Two new test files:**
- `tests/testthat/test-replicate-weights.R` — 12 test groups, 27 individual test cases
- `tests/testthat/test-conversion.R` — 4 test groups covering dispatch and `as_taylor_design()`

**New test helper:** `make_taylor_design(n, n_strata, psus_per_stratum, seed)` — creates a `survey_taylor` with strata, PSU IDs, and unequal PSU sizes.

**`test_invariants()` extended** to handle `survey_replicate`: checks `@variables$weights`, `@variables$repweights`, that all rep columns exist in `@data`, and that all are numeric.

**Numerical correctness:** bootstrap and gen-boot tested against `svrep` at 1e-8 tolerance (inside `skip_if_not_installed("svrep")` blocks).

---

## Key Design Decisions Already Made

| Decision | Resolution |
|----------|------------|
| RWYB draw count | m_h = n_h − 1 (confirmed from svrep source) |
| Fay scale factor | `1 / (n_rep * (1 - rho)^2)` |
| BRR vs Fay separation | Two separate functions (no `fay_rho` on `create_brr_weights`) |
| `mse = FALSE` semantics | Deviates from replicate mean rather than full-sample estimate |
| Bootstrap for `survey_nonprob` | Simple bootstrap in Phase 1; re-calibrated bootstrap deferred to Phase 2.5 |
| `as_taylor_design()` round-trip | Store Taylor keys in `@variables` (Option A) |
| New `Imports` | None — algorithms vendored or native; `svrep` in Suggests only |

---

## Open GAPs (blocking, carry to Stage 2 Resolve Part 2)

1. **JK1 for stratified designs** — error or support with per-stratum `rscales`?
2. **Bootstrap single-PSU stratum handling** — error, collapse, or center at 1?
3. **Bootstrap unclustered design** — `survey_srs`/`survey_nonprob` as PSU-free designs?
4. **JKn stratified grouping** — within-stratum or across all strata?
5. **`create_jackknife_weights()` `replicates` arg for delete-1** — ignored with message vs. separate functions?

Non-blocking GAPs (Stage 3):
- Vendoring decision for algorithm implementations
- Many-replicate warning threshold for delete-1 jackknife
- surveytidy compatibility with `survey_replicate`

---

## What Phase 1 Does NOT Build

- Variance estimation or analysis functions (only weight creation)
- `create_*_weights()` accepting `weighted_df` input
- `trim_weights()`, `stabilize_weights()` (Phase 4)
- `calibrate_to_survey()` (Phase 2)
- Re-calibrated bootstrap (Phase 2.5)
- Removal of Phase 0 `survey_replicate` stubs in calibration functions
