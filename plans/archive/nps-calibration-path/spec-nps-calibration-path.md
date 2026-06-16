# Spec — nps-calibration-path

**Status**: SPEC_READY
**Target version**: 0.6.0.9000
**PR range**: PR 1–2

## Scope

### In

- Add a calibration-only replicate path to `create_bootstrap_weights()` when
  `type = "quasi-randomization"`: when the `survey_nonprob` weighting history
  contains a supported calibration entry but no IPW entry, each bootstrap
  replicate is produced by SRSWR resampling followed by replaying the original
  calibration step (dispatching to `calibrate_rake()`, `calibrate_linear()`,
  `calibrate_logit()`, or `poststratify()` as recorded in the history).
- Add a calibration-only replicate path to `create_group_jackknife_weights()`:
  when the `survey_nonprob` weighting history contains a supported calibration
  entry but no IPW entry, each group replicate is produced by group deletion
  followed by scale-factor adjustment and replaying the original calibration
  step via the same dispatch table.
- Remove the hard IPW requirement in both functions: a `survey_nonprob` with
  only a calibration history entry is a valid input.
- Replace the `surveywts_error_qr_bootstrap_no_ipw_history` error (IPW-only
  guard in `.quasi_randomization_bootstrap()`) with a history-agnostic error
  `surveywts_error_qr_bootstrap_no_history` that fires only when no supported
  weighting history entry (IPW or calibration) is found.
- Replace the `surveywts_error_dagjk_no_ipw_history` error with
  `surveywts_error_dagjk_no_history` under the same logic.
- Fix the misleading `"i"` bullet in `surveywts_error_qr_bootstrap_requires_nonprob`
  (currently says "with IPW history") to describe the actual requirement.
- Fix the misleading `"i"` bullet in `surveywts_error_dagjk_requires_nonprob`
  (currently says "requires an IPW weighting history") to describe the actual
  requirement.
- Make the reference-sample requirement for `create_group_jackknife_weights()`
  conditional: a reference is required for the IPW path and for calibration-only
  Level B, but NOT for calibration-only Level A.
- Update `plans/error-messages.md` with all new, retired, and previously
  undocumented classes.

### Out

- No signature changes to any exported function.
- No new exported functions.
- No changes to `calibrate_rake()`, `ipw()`, or any other function outside the
  replicate weight family.
- No changes to the doubly-robust (IPW + calibration) path: that path is
  unchanged and must continue to work.
- No changes to the probability-sample bootstrap paths.
- No roxygen2 documentation updates for the function `@param` or `@details`
  blocks (documentation refresh is deferred to the Polish release).

## Architecture

- Files touched:
  - `R/replicate-utils.R` — `.quasi_randomization_bootstrap()` modified
  - `R/create_group_jackknife_weights.R` — `create_group_jackknife_weights()`
    and `.dagjk_single_replicate()` modified; `.dagjk_single_replicate_calib()`
    added as an internal helper (calibration-only engine)
  - `R/create_bootstrap_weights.R` — one `"i"` bullet text change in
    `surveywts_error_qr_bootstrap_requires_nonprob`
  - `tests/testthat/test-replicate-weights.R` — new tests for calibration-only
    QR bootstrap paths
  - `tests/testthat/test-nps-group-jackknife.R` — new tests for calibration-only
    DAGJK paths
- Functions added: none exported; one internal helper added to
  `create_group_jackknife_weights.R`
- Functions modified:
  - `.quasi_randomization_bootstrap()` — routing logic, error class replacement
  - `create_group_jackknife_weights()` — routing logic, error class replacement,
    conditional reference requirement
  - `.dagjk_single_replicate()` — either modified in place or replaced by two
    dispatching helpers (builder's choice, provided contracts below are met)
- Class changes: none

### Implementation assumption: calibration parameter storage

The calibration dispatch table (see "Calibration dispatch table" in each
function contract) forwards parameters from `calib_entry$parameters` to the
dispatched calibration function. This assumes that `calibrate_linear()`,
`calibrate_logit()`, `calibrate_rake()`, and `poststratify()` store all
parameters listed in the dispatch table under `$parameters` in their history
entries (e.g., `bounds_scale`, `unit_scale`, `algorithm`, `cap`, `control`).

Before implementing dispatch, the builder must verify this assumption by
inspecting a `survey_nonprob` history entry after calling each function:

```r
nps <- calibrate_linear(nps_base, targets = ..., bounds_scale = "absolute")
nps@metadata@weighting_history[[length(nps@metadata@weighting_history)]]$parameters
```

If a parameter is not stored (returns `NULL`), the dispatched replay call will
use that function's default for the missing parameter, which is correct only if
the original call also used the default. Document any divergence discovered
during this verification as a limitation in the implementation notes.

## Function contracts

---

### `create_bootstrap_weights(data, replicates, ..., type, reference_sample, mse, seed)`

No signature change. The contract below covers only the `type = "quasi-randomization"`
dispatch path because all other paths are unchanged.

#### Signature

```
create_bootstrap_weights(
  data,
  replicates = NULL,
  ...,
  type = c("Rao-Wu-Yue-Beaumont", "Rao-Wu", "Antal-Tille",
           "Preston", "Canty-Davison", "quasi-randomization", "hybrid"),
  reference_sample = NULL,
  mse = c("mse", "chrostowski", "uncentered"),
  seed = NULL
)
```

#### Changed behavior: `type = "quasi-randomization"` input routing

After confirming `data` is `survey_nonprob` and `reference_sample` (if
supplied) is a `survey_taylor`, the function determines which replication path
to use by inspecting `data@metadata@weighting_history`. The routing is applied
in the order listed below; the first match wins.

**Routing precedence (quasi-randomization path only):**

1. **Doubly-robust path** — IPW entry AND calibration entry present: existing
   behavior unchanged. IPW refit runs first; calibration replay follows.
2. **IPW-only path** — IPW entry present, no calibration entry: existing
   behavior unchanged. IPW refit runs; no calibration replay.
3. **Calibration-only path** — calibration entry present, no IPW entry: NEW.
   See "Calibration-only bootstrap algorithm" below.
4. **No supported history** — neither IPW nor calibration entry: error
   `surveywts_error_qr_bootstrap_no_history`.

A "calibration entry" is any history entry whose `$operation` field is one of:
`"calibrate_rake"`, `"calibrate_linear"`, `"calibrate_logit"`, `"poststratify"`.
(Implementation note: the legacy string `"raking"` is treated as equivalent to
`"calibrate_rake"` for backward compatibility with objects created before the
operation string was standardized.)

When multiple calibration entries exist, the LAST entry in the history list is
used (same convention as the doubly-robust path).

#### Calibration-only bootstrap algorithm

For b = 1, …, B:

1. **SRSWR resample**: Draw `idx` of size `n_A` from `1:n_A` with replacement.
   Form `S_A_b = data@data[idx, ]`. This is identical to the SRSWR step on the
   IPW path.

2. **Skip IPW**: No propensity model refit. No step 2 from the IPW path.

3. **Set initial weights**: Assign equal initial weight `1` to every row of
   `S_A_b` (not the original raked weights). SRSWR gives each NPS unit equal
   selection probability per replicate; carrying forward the original raked
   weights would double-count calibration.

4. **Calibration replay**:
   - **Level A** (`targets_from_reference = FALSE` in the calibration history
     entry, or field absent): dispatch to the calibration function matching
     `calib_entry$operation` (see dispatch table below), passing `S_A_b` with
     equal initial weights and the fixed targets stored in
     `calib_entry$parameters$targets` (falling back to
     `calib_entry$parameters$margins` for legacy `"raking"` entries). No
     reference design needed.
   - **Level B** (`targets_from_reference = TRUE` in the calibration history
     entry): additionally SRSWR-resample `n_ref` rows from the reference
     design (same SRSWR step as the doubly-robust path). Re-estimate margin
     targets from the resampled reference rows and their design weights.
     Dispatch to the calibration function with `S_A_b` and the re-estimated
     targets. Reference design resolution is the same as for the IPW path
     (see "Reference resolution" below).

5. **Extract replicate weight vector**: The final calibrated weight column from
   step 4 is the b-th replicate weight vector.

**Calibration dispatch table** — maps `calib_entry$operation` to the function
called and the parameters forwarded from `calib_entry$parameters`:

| `$operation` | Function called | Parameters forwarded |
|---|---|---|
| `"calibrate_rake"` (or legacy `"raking"`) | `calibrate_rake()` | `targets`, `type`, `algorithm`, `cap`, `control` |
| `"calibrate_linear"` | `calibrate_linear()` | `targets`, `type`, `bounds`, `bounds_scale`, `unit_scale`, `control` |
| `"calibrate_logit"` | `calibrate_logit()` | `targets`, `type`, `bounds`, `bounds_scale`, `unit_scale`, `control` |
| `"poststratify"` | `poststratify()` | `targets`, `type` |

All four functions are called with `data` = `S_A_b` as a `data.frame` with an
equal-weight column, OR as a `survey_nonprob` constructed around `S_A_b` —
builder's choice provided the output class is one whose weight column can be
extracted. The output may be a `weighted_df` or `survey_nonprob` depending on
the input class passed. Weight extraction must handle both classes.

#### Reference resolution (calibration-only Level B)

The reference design is resolved as follows (first non-NULL wins):

1. `reference_sample` argument (already validated as `survey_taylor`)
2. `calib_entry$parameters$reference_design`

If both are NULL and `use_level_b = TRUE`, error
`surveywts_error_qr_bootstrap_no_reference`.

If both are NULL and `use_level_b = FALSE` (Level A), no reference is needed;
no error.

#### Failed draw handling (calibration-only path)

A draw fails if the dispatched calibration function throws an error (e.g.,
non-convergence). A draw also fails if the dispatched calibration function
produces any non-positive weights in the calibrated output — this case applies
to `calibrate_linear()` when `bounds = NULL`, which converges and returns a
`weighted_df` whose weight column may contain negative values. Negative-weight
draws are counted toward `surveywts_warning_bootstrap_draws_failed` and excluded
from the replicate matrix, identical to draws that raise an error.
The existing failed-draw counting, `surveywts_warning_bootstrap_draws_failed`,
and `surveywts_error_bootstrap_all_draws_failed` apply unchanged.

The `"i"` bullet of `surveywts_warning_bootstrap_draws_failed` currently reads:
"A draw fails when `ipw()` or calibration does not converge (e.g., degenerate
propensity scores in the resampled data)." The builder must update this text to
be path-agnostic. Replacement: "A draw fails when calibration or IPW
re-estimation does not converge (e.g., degenerate inputs in the resampled
data)."

#### Error message fix

The `"i"` bullet in `surveywts_error_qr_bootstrap_requires_nonprob` currently
reads: "The quasi-randomization bootstrap is designed for non-probability
samples with IPW history." Change to: "The quasi-randomization bootstrap is
designed for non-probability samples." (Remove "with IPW history".)

#### Errors table (quasi-randomization path — full list)

| Class | Trigger condition |
|-------|-------------------|
| `surveywts_error_qr_bootstrap_requires_nonprob` | `data` is not `survey_nonprob` |
| `surveywts_error_reference_sample_class` | `reference_sample` is non-NULL and not `survey_taylor` |
| `surveywts_error_qr_bootstrap_no_history` | Weighting history contains no IPW entry and no supported calibration entry (`calibrate_rake`, `calibrate_linear`, `calibrate_logit`, `poststratify`) |
| `surveywts_error_qr_bootstrap_no_reference` | Calibration-only Level B and no reference design available; also on IPW path when no reference design available |
| `surveywts_error_bootstrap_all_draws_failed` | All B bootstrap draws failed |
| `surveywts_error_hybrid_bootstrap_requires_nonprob` | `type = "hybrid"` and `data` is not `survey_nonprob` |
| `surveywts_error_hybrid_bootstrap_not_implemented` | `type = "hybrid"` is requested |
| `surveywts_error_mse_not_character` | `mse` is `logical` |
| `surveywts_error_chrostowski_prob_sample` | `mse = "chrostowski"` with a probability-sample type |
| `surveywts_error_not_survey_design` | `data` is `data.frame` or `weighted_df` (probability-sample path) |
| `surveywts_error_already_replicate` | `data` is `survey_replicate` (probability-sample path) |
| `surveywts_error_unsupported_class` | `data` is an unsupported class (probability-sample path) |
| `surveywts_error_replicates_invalid` | `replicates` is not a single numeric value |
| `surveywts_error_replicates_not_whole_number` | `replicates` has fractional part |
| `surveywts_error_replicates_not_positive` | `replicates` < 2 |

#### Warnings table (quasi-randomization path — full list)

| Class | Condition |
|-------|-----------|
| `surveywts_warning_repweights_overwritten` | Prior replicate columns exist and are overwritten |
| `surveywts_warning_bootstrap_draws_failed` | More than 10% of draws failed |
| `surveywts_warning_reference_sample_ignored` | `reference_sample` supplied but `type` is a probability-sample type |

#### Returns

Same postconditions as the existing quasi-randomization path:
- Returns a `survey_nonprob`.
- `@data` contains `replicates_used` new columns named `repwt_1`, ...,
  `repwt_{replicates_used}` where `replicates_used = replicates - failed_draws`.
- `@variables$repweights` is set to those column names.
- A new history entry with `operation = "bootstrap_weights"` is appended to
  `@metadata@weighting_history`. The entry includes: `type = "quasi-randomization"`,
  `replicates` (requested), `draws_used` (successful), `level` (`"A"` or `"B"`),
  `mse`, `seed`.

#### Edge cases

| Case | Behavior |
|------|----------|
| Empty `@metadata@weighting_history` | Error `surveywts_error_qr_bootstrap_no_history` |
| Single-entry history with only `calibrate_linear` or `calibrate_logit` | Routes to calibration-only path; dispatches to the appropriate function per the dispatch table |
| Calibration-only Level B, `reference_sample` arg supplied | Arg takes precedence over stored entry; Level B proceeds normally |
| Calibration-only Level A, `reference_sample` arg supplied | Arg is accepted but not used (Level A does not resample reference); no warning |
| Calibration-only: prior replicate columns present | `surveywts_warning_repweights_overwritten` emitted; old columns cleared before loop |
| All draws fail (convergence failure in `calibrate_rake()`) | Error `surveywts_error_bootstrap_all_draws_failed` |
| Calibration entry with no `targets` and no `margins` | `calibrate_rake()` will receive `NULL` targets and error; treated as a draw failure |

---

### `create_group_jackknife_weights(data, groups, ..., reference_sample, seed)`

No signature change. The contract below covers the full function, including the
new calibration-only path.

#### Signature

```
create_group_jackknife_weights(
  data,
  groups = 50L,
  ...,
  reference_sample = NULL,
  seed = NULL
)
```

#### Validation order

The validation order below supersedes the existing order. The change is in
step 4 (IPW history check) and step 5 (reference requirement).

1. `.validate_replicate_input(data)` — rejects `data.frame`, `weighted_df`,
   `survey_replicate`, and other non-survey objects.
2. Class check: `data` must be `survey_nonprob`. Error
   `surveywts_error_dagjk_requires_nonprob` if not. The `"i"` bullet in this
   error currently reads "requires an IPW weighting history attached to a
   `survey_nonprob` object." Change to: "The DAGJK requires a weighting history
   attached to a `survey_nonprob` object."
3. `reference_sample` validation: if non-NULL, must be `survey_taylor`. Error
   `surveywts_error_reference_sample_class` if not.
4. `groups` validation (type, whole number, minimum — ceiling deferred).
5. **History routing** (replaces the old IPW-only check):
   - Find the LAST IPW entry in `data@metadata@weighting_history`
     (`$operation == "ipw"`).
   - Find the LAST calibration entry (`$operation %in% c("calibrate_rake", "calibrate_linear", "calibrate_logit", "poststratify")`, plus legacy `"raking"` — same definition as in `create_bootstrap_weights` above).
   - If neither found: error `surveywts_error_dagjk_no_history`.
   - If IPW entry found: use the IPW path (existing behavior). `ipw_entry` is set.
   - If calibration entry found but no IPW entry: use the calibration-only path.
     `calib_entry` is set. `ipw_entry` is NULL.
6. **Reference resolution** (conditional on path and level):
   - **IPW path**: reference required. Resolve: `reference_sample` arg (takes
     precedence) or `ipw_entry$reference_design`. If neither: error
     `surveywts_error_dagjk_no_reference`.
   - **Calibration-only Level A** (`targets_from_reference = FALSE` or absent
     in `calib_entry$parameters`): no reference required. `ref_design = NULL`.
   - **Calibration-only Level B** (`targets_from_reference = TRUE` in
     `calib_entry$parameters`): reference required. Resolve: `reference_sample`
     arg (takes precedence) or `calib_entry$parameters$reference_design`. If
     neither: error `surveywts_error_dagjk_no_reference`.
7. `groups` ceiling check (now that `combined_n` is known).
   - For Level A calibration-only: `combined_n = n_A` (NPS rows only, since
     no reference is used).
   - For all other paths: `combined_n = n_A + n_ref`.

#### Group assignment

When `ref_design` is non-NULL: assign the combined `n_A + n_ref` rows to G
groups. When `ref_design` is NULL (calibration-only Level A): assign only the
`n_A` NPS rows to G groups. Groups are formed by
`sample(rep(seq_len(G), length.out = combined_n))`.

#### Calibration-only DAGJK algorithm

For g = 1, …, G:

1. **Identify group-g units**: From the group assignment vector, find which NPS
   row indices belong to group g. (If Level B: also find which reference row
   indices belong to group g.)

2. **Form reduced NPS**: `S_A_minus_g` = NPS rows NOT assigned to group g.
   `n_Ag` = count of NPS units assigned to group g.

3. **Scale factor**: `a_g = n_A / (n_A - n_Ag)`.

4. **Apply scale factor**: For each row `i` in `S_A_minus_g`, compute
   `w_i_adj = w_i * a_g`, where `w_i` is the CURRENT weight in `data@data`
   (the post-raking weight from the original calibration step, NOT an equal
   weight).

5. **Calibration replay**: Dispatch to the calibration function matching
   `calib_entry$operation` (same dispatch table as the QR bootstrap
   calibration-only path).
   - **Level A**: call the dispatch function on `S_A_minus_g` with `w_i_adj`
     as starting weights, using fixed targets from
     `calib_entry$parameters$targets` (falling back to
     `calib_entry$parameters$margins` for legacy `"raking"` entries). Forward
     all stored parameters per the dispatch table.
   - **Level B**: form `ref_minus_g` = reference rows NOT assigned to group g.
     Re-estimate margin targets from `ref_minus_g` using its design weights.
     Call the dispatch function on `S_A_minus_g` with `w_i_adj` and the
     re-estimated targets. Forward all stored parameters per the dispatch table.

   The output may be a `weighted_df` or `survey_nonprob` depending on the input
   class passed to the dispatch function. Weight extraction must handle both
   classes.

6. **Extract replicate weight vector**: The final calibrated weight column from
   step 5 for `S_A_minus_g`. Units in group g receive weight `0` in the
   output replicate column (same convention as the IPW path).

7. **Degenerate replicate check**: If the output contains any NA or non-positive
   weights among the retained units (`S_A_minus_g`), raise
   `surveywts_error_dagjk_degenerate_replicate` inside `tryCatch()` so the
   replicate is counted as failed.

A replicate fails if:
- `S_A_minus_g` has 0 rows (all NPS units in group g) — degenerate replicate.
- The dispatch function throws an error (e.g., non-convergence, degenerate targets).
- The extracted weight vector contains NA or non-positive values.

#### Small groups warning

For calibration-only Level A: `avg_group_size = floor(n_A / G)`.
For IPW path and calibration-only Level B: `avg_group_size = floor((n_A + n_ref) / G)`.
If `avg_group_size < 5`: emit `surveywts_warning_dagjk_small_groups`.

#### Errors table (full list)

| Class | Trigger condition |
|-------|-------------------|
| `surveywts_error_not_survey_design` | `data` is `data.frame` or `weighted_df` |
| `surveywts_error_already_replicate` | `data` is `survey_replicate` |
| `surveywts_error_unsupported_class` | `data` is an unsupported class |
| `surveywts_error_dagjk_requires_nonprob` | `data` is `survey_taylor` or another supported but non-NPS class |
| `surveywts_error_reference_sample_class` | `reference_sample` is non-NULL and not `survey_taylor` |
| `surveywts_error_dagjk_groups_invalid` | `groups` is not a single non-NA numeric |
| `surveywts_error_dagjk_groups_not_whole_number` | `groups` has fractional part |
| `surveywts_error_dagjk_groups_too_small` | `groups < 2` |
| `surveywts_error_dagjk_groups_exceeds_n` | `groups > combined_n` |
| `surveywts_error_dagjk_no_history` | Weighting history contains neither an IPW entry nor a supported calibration entry (`calibrate_rake`, `calibrate_linear`, `calibrate_logit`, `poststratify`) |
| `surveywts_error_dagjk_no_reference` | IPW path or calibration-only Level B, and no reference design available |
| `surveywts_error_dagjk_degenerate_replicate` | A replicate produced non-positive or NA weights, or the reduced dataset is empty |
| `surveywts_error_dagjk_all_replicates_failed` | All G group replicates failed |

#### Warnings table (full list)

| Class | Condition |
|-------|-----------|
| `surveywts_warning_dagjk_repweights_overwritten` | Prior replicate columns exist and are overwritten |
| `surveywts_warning_dagjk_small_groups` | Average group size < 5 |
| `surveywts_warning_dagjk_replicates_failed` | More than 10% of group replicates failed |
| `surveywts_warning_dagjk_negative_replicate_weights` | One or more replicate weight values are negative |

#### Returns

Same postconditions as the existing IPW path:
- Returns a `survey_nonprob`.
- `@data` contains `G_success` new replicate columns named `repwt_1`, ...,
  `repwt_{G_success}`.
- `@variables$repweights` set to those column names.
- `@variables$scale` set to `(G_success - 1) / G_success`.
- `@variables$rscales` set to `rep(1, G_success)`.
- `@variables$mse` set to `TRUE`.
- `@variables$type` set to `"group-jackknife"`.
- A new history entry with `operation = "group_jackknife_weights"` appended to
  `@metadata@weighting_history`. The entry includes: `groups` (requested),
  `groups_used` (`G_success`), `groups_failed`, `seed`, `scale`,
  `reference_design` (if used, else `NULL`), `source_design`.
- Replicate columns for group-g-deleted replicates have `0` for units
  assigned to group g and positive values for all other NPS units (or possibly
  negative values if calibration produced negative weights, which triggers
  `surveywts_warning_dagjk_negative_replicate_weights`).

#### Edge cases

| Case | Behavior |
|------|----------|
| Empty `@metadata@weighting_history` | Error `surveywts_error_dagjk_no_history` |
| History with only `calibrate_linear` or `calibrate_logit` | Routes to calibration-only path; dispatches to the appropriate function per the dispatch table |
| Calibration-only Level A, `reference_sample` supplied | Arg accepted but not used; no warning |
| Calibration-only Level B, `reference_sample` arg supplied | Arg takes precedence over stored entry |
| Calibration-only Level A, groups ceiling check uses `n_A` only | Groups must not exceed `n_A`; reference row count is not included |
| All group replicates fail | Error `surveywts_error_dagjk_all_replicates_failed` |
| `> 10%` of group replicates fail but not all | Warning `surveywts_warning_dagjk_replicates_failed`; successful replicates returned |
| Calibration-only: negative replicate weights produced | Warning `surveywts_warning_dagjk_negative_replicate_weights` |
| Prior replicate columns exist | `surveywts_warning_dagjk_repweights_overwritten`; old columns cleared before loop |

---

## Quality gates

- Every call that constructs a `survey_nonprob` result must satisfy:
  - `@variables$weights` is a character scalar.
  - The weight column named by `@variables$weights` exists in `@data` and is
    numeric with all values `> 0` (main weights) or `>= 0` (replicate columns,
    which may contain `0` for group-deleted units).
  - `@variables$repweights` is non-NULL, non-empty, and every named column
    exists in `@data`.
  - The length of `@variables$repweights` equals the number of successful
    draws/replicates.
- The existing doubly-robust path (IPW + calibration entry) must produce
  identical results before and after this change (no regression).
- The existing IPW-only path must produce identical results before and after
  this change (no regression).
- Error class names used in `cli_abort()` must match `plans/error-messages.md`
  exactly.

## Documentation tier

- `create_bootstrap_weights()` — Tier 3 (Algorithmic). No new roxygen2 section
  text required in this PR. The `@param data` and `@details` blocks will be
  updated in the Polish release.
- `create_group_jackknife_weights()` — Tier 3 (Algorithmic). Same deferral.

## References

- Elliott, M.R. and Valliant, R. (2017). Inference for nonprobability samples.
  *Statistical Science* **32**(2), 249--264.
- Wu, C. (2022). Statistical inference with non-probability survey samples.
  *Survey Methodology* **48**(2), 283--311.
- Kolenikov, S. (2014). Calibrating survey data using iterative proportional
  fitting (raking). *Survey Methodology* **40**(1), 21--38.
- Valliant, R. (2020). Comparing alternatives for estimation from nonprobability
  samples. *Journal of Survey Statistics and Methodology* **8**, 231--263.
- Chrostowski, M.J., Guzman, C.A. and Malm, L. (2025). Variance estimation for
  non-probability surveys. *Journal of Survey Statistics and Methodology*
  (forthcoming).

## Pipeline split

recommended — algorithmic change to variance estimation replication loops,
touches 4–5 files, introduces new routing logic.
