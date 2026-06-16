# Test Spec: group-jackknife

**Status:** SPEC_READY
**Feature:** `create_group_jackknife_weights()`
**Corresponding spec:** `spec-group-jackknife.md`

---

## 1. Reference Oracle

There is no direct oracle for NPS DAGJK pseudo-weights, because no reference
package implements the full delete-a-group jackknife pipeline (delete group →
refit logistic model → recompute pseudo-weights → optional calibration).

The closest available reference is `survey::as.svrepdesign()` with
`type = "JKn"`, which produces jackknife replicate weights for
probability-sample designs using the standard leave-one-PSU-out formula. This
reference tests the **structural contract** (scale, rscales, mse, column naming,
zero-weight assignment for deleted units) but does NOT test the correctness of
pseudo-weight values, because `JKn` does not refit a propensity model.

**Oracle strategy:**

- **Structural tests** (replicate weight matrix shape, scale factor, rscales,
  mse flag, zero-weight assignment): verified by inspection against expected
  values derived from the DAGJK formula.
- **Variance magnitude tests** (does DAGJK produce a variance larger than the
  naive fixed-weight jackknife?): verified by constructing a simple oracle that
  does NOT refit the model and confirming the refitting-based output produces
  larger estimated variance.
- **Scaling factor tests** (is scale `(G-1)/G` not `(n-1)/n`?): verified
  analytically — compute `(G-1)/G` from the known `groups` argument and compare
  to `@variables$scale`.
- **Reference weight adjustment tests**: verified by constructing a replicate
  manually for $g = 1$ with known group membership and comparing the adjusted
  reference weights used in model fitting.
- **Calibration refit tests**: verified by comparing replicate weights from a
  QR-only pipeline vs. a QR+calibration pipeline and checking that the latter
  produces different (not identical) replicate weights for each group.

---

## 2. Test Datasets

### Dataset A: Standard NPS with IPW history

Construct inline in tests. A `survey_nonprob` object created by calling `ipw()`
on a synthetic NPS data frame against a synthetic reference `survey_taylor`.
The NPS should have at least 100 units; the reference should have at least 100
units. Both should have at least two categorical selection variables with at
least two levels each. Use `set.seed()` for reproducibility.

Requirements:
- NPS and reference share the same categorical covariates.
- All covariate levels present in both datasets.
- All base weights positive.
- No `NA` values in selection variables.

### Dataset B: NPS with IPW + calibration history

Same as Dataset A, but after `ipw()` call, one additional `rake()` call is
applied. This produces a `survey_nonprob` with both an `"ipw"` and a
`"raking"` entry in `@metadata@weighting_history`.

### Dataset C: NPS with reference design in ipw history

Same as Dataset A, but the reference design is passed to `ipw()` via the
`reference` argument so it is stored in the ipw history entry. Used to verify
that the stored reference is used when `reference_sample = NULL`.

### Dataset D: Minimal NPS for boundary tests

Inline. Small `survey_nonprob` (minimum size that allows `groups = 2`). Used
for boundary value tests only. At least 4 NPS units and 4 reference units.

---

## 3. Test Plan: `create_group_jackknife_weights()`

### 3.1 Happy path — basic structure

| Test description | What to verify |
|-----------------|----------------|
| Returns `survey_nonprob` with correct class | `S7::S7_inherits(result, survey_nonprob)` is `TRUE` |
| Returns `G` replicate weight columns | `length(result@variables$repweights) == groups` |
| Column names follow `repwt_1`...`repwt_G` pattern | `result@variables$repweights == paste0("repwt_", seq_len(groups))` |
| All replicate columns exist in `@data` | All names in `@variables$repweights` are in `names(result@data)` |
| `@variables$scale` equals `(G-1)/G` | `result@variables$scale == (groups - 1) / groups` within `1e-12` |
| `@variables$rscales` is `rep(1, G)` | `identical(result@variables$rscales, rep(1, groups))` |
| `@variables$mse` is `TRUE` | `isTRUE(result@variables$mse)` |
| `@variables$type` is `"group-jackknife"` | `identical(result@variables$type, "group-jackknife")` |
| Each NPS unit has weight `0` in exactly one replicate column | For each row $i$, exactly `1` of the $G$ replicate columns equals `0` |
| Each NPS unit has a positive weight in $G-1$ replicate columns | For each row $i$, exactly $G-1$ replicate columns are $> 0$ |
| Original `@data` columns unchanged | Column names present before the call are still present |
| Original base weight column unchanged | Base weight values identical before and after |
| History entry added | `length(result@metadata@weighting_history)` equals previous length + 1 |
| History entry operation field | `tail(result@metadata@weighting_history, 1)[[1]]$operation == "group_jackknife_weights"` |
| History entry `groups` field | Matches the `groups` argument |
| History entry `scale` field | Equals `@variables$scale` |
| `reference_sample` argument resolves correctly | Result identical when passing reference via argument vs. relying on stored history entry |

### 3.2 Happy path — default groups

| Test description | What to verify |
|-----------------|----------------|
| `groups = 50L` is the default | Calling without `groups` produces 50 replicate columns |
| Whole-number double `groups = 50.0` coerced silently | `length(result@variables$repweights) == 50` and no warning emitted |

### 3.3 Happy path — seed reproducibility

| Test description | What to verify |
|-----------------|----------------|
| Same seed produces identical replicate weights | Two calls with identical `seed` produce `identical()` replicate weight matrices |
| Different seeds produce different replicate weights | Two calls with different seeds produce non-identical matrices (probabilistic; expected to pass with overwhelming probability) |
| `seed = NULL` does not error | Function completes successfully |
| `seed = 0L` does not error and produces valid results | Function completes successfully; results are reproducible when the same seed is used again |

### 3.4 Happy path — with calibration history (Dataset B)

| Test description | What to verify |
|-----------------|----------------|
| Calibration step is repeated per replicate | Replicate weights from Dataset B differ from replicate weights produced by an identical run on Dataset A (QR-only); the calibration step changes the within-replicate weights |
| Within-replicate calibration satisfies margin constraints | For Dataset B with raking, each successful replicate weight column, when used to compute weighted proportions for each raking variable, is approximately equal to the raking margin target (within calibration convergence tolerance, `1e-6`). This confirms the calibration step ran within the replicate loop, not just at the full-sample level. **The raking targets must be specified as literals in the test** (e.g., `list(age_group = c("18-34" = 0.3, "35-54" = 0.4, "55+" = 0.3))`), not read from the history entry — reading from the history entry is circular and would allow a buggy implementation that skips within-replicate calibration to pass. |
| History entry contains correct `groups_used` | `groups_used` equals `groups` when no failures occur |

### 3.5 Happy path — dispatcher integration

| Test description | What to verify |
|-----------------|----------------|
| `create_replicate_weights(data, method = "group-jackknife", groups = 10L, seed = 42L)` | Returns `identical()` result to `create_group_jackknife_weights(data, groups = 10L, seed = 42L)` |

### 3.6 Error paths — input class

| Test description | Error class |
|-----------------|-------------|
| `data` is a `data.frame` | `surveywts_error_not_survey_design` |
| `data` is a `weighted_df` | `surveywts_error_not_survey_design` |
| `data` is a `survey_replicate` | `surveywts_error_already_replicate` |
| `data` is a `survey_taylor` | `surveywts_error_dagjk_requires_nonprob` |
| `data` is a plain list | `surveywts_error_unsupported_class` |

For each: `expect_error(class = ...)` + `expect_snapshot(error = TRUE, ...)`.

### 3.7 Error paths — `reference_sample`

| Test description | Error class |
|-----------------|-------------|
| `reference_sample` is `survey_replicate` | `surveywts_error_reference_sample_class` |
| `reference_sample` is a plain `data.frame` | `surveywts_error_reference_sample_class` |
| `reference_sample = NULL` and ipw history has no stored reference | `surveywts_error_dagjk_no_reference` |

For each: `expect_error(class = ...)` + `expect_snapshot(error = TRUE, ...)`.

**Snapshot review note:** The snapshot for `reference_sample = data.frame(...)` must be reviewed after generation to confirm the `'i'` bullet `"Use survey::svydesign() to convert an SRS data frame to a survey_taylor object."` appears in the captured error output. A snapshot that passes without this bullet means the `data.frame` branch in `.validate_reference_sample()` was not correctly implemented (see spec §3.4).

### 3.8 Error paths — `groups` argument

| Test description | Error class |
|-----------------|-------------|
| `groups = 1` | `surveywts_error_dagjk_groups_too_small` |
| `groups = 0` | `surveywts_error_dagjk_groups_too_small` |
| `groups = -1` | `surveywts_error_dagjk_groups_too_small` |
| `groups = 50.5` (fractional) | `surveywts_error_dagjk_groups_not_whole_number` |
| `groups = NA` | `surveywts_error_dagjk_groups_invalid` |
| `groups = "50"` (character) | `surveywts_error_dagjk_groups_invalid` |
| `groups = c(10, 20)` (length > 1) | `surveywts_error_dagjk_groups_invalid` |
| `groups` exceeds combined NPS + reference count | `surveywts_error_dagjk_groups_exceeds_n` |

For each: `expect_error(class = ...)` + `expect_snapshot(error = TRUE, ...)`.

### 3.9 Error paths — no ipw history

| Test description | Error class |
|-----------------|-------------|
| `data` is a `survey_nonprob` with no `ipw` operation in history | `surveywts_error_dagjk_no_ipw_history` |

`expect_error(class = ...)` + `expect_snapshot(error = TRUE, ...)`.

### 3.10 Error paths — all replicates fail

| Test description | Error class |
|-----------------|-------------|
| Constructed pathological `data` where every logistic model refit is guaranteed to fail (e.g., single NPS unit, groups = 2) | `surveywts_error_dagjk_all_replicates_failed` |

`expect_error(class = ...)` + `expect_snapshot(error = TRUE, ...)`.

Construction: Use a `survey_nonprob` with exactly 2 NPS units and a reference
with exactly 2 units. Call with `groups = 2`. Each replicate leaves 1 NPS unit
and 1 reference unit — insufficient observations to fit a binary logistic model
(only 1 observation per outcome class). Both replicates fail, triggering
`surveywts_error_dagjk_all_replicates_failed`. Use `set.seed()` to ensure
reproducibility.

**Internal error class: `surveywts_error_dagjk_degenerate_replicate`**

This error is thrown inside the per-replicate `tryCatch()` and is not surfaced
to the user directly. Test it by calling the internal per-replicate helper
directly with inputs that produce degenerate propensity scores (e.g., NA
predictions or a propensity score of exactly 1). Capture with `tryCatch()`:

```r
test_that("internal replicate helper throws degenerate_replicate for NA propensity scores [direct]", {
  cond <- tryCatch(
    surveywts:::.dagjk_single_replicate(...),  # builder names the function
    error = function(e) e
  )
  expect_s3_class(cond, "surveywts_error_dagjk_degenerate_replicate")
})
```

The builder should substitute the actual internal function name. The test
verifies the correct class is thrown before the outer loop catches it.

### 3.11 Warning paths

| Test description | Warning class | What to verify |
|-----------------|---------------|----------------|
| `@variables$repweights` already populated before call | `surveywts_warning_dagjk_repweights_overwritten` | Old columns removed; new columns present; no duplicates |
| More than 10% of replicates fail | `surveywts_warning_dagjk_replicates_failed` | Warning emitted after loop; `groups_failed` in history entry reflects actual count |
| Any replicate weight is negative | `surveywts_warning_dagjk_negative_replicate_weights` | Warning emitted; function still returns successfully |
| `floor(combined_N / groups) < 5` (average fewer than 5 units per group) | `surveywts_warning_dagjk_small_groups` | Warning emitted before the replication loop; function proceeds and completes |

For each warning path: `expect_warning(class = ...)` + `expect_snapshot(warning = TRUE, ...)`.

For overwrite warning: construct `data` that already has `@variables$repweights`
set, then call `create_group_jackknife_weights()`. Verify warning class with
`expect_warning(class = ...)` and snapshot the message with
`expect_snapshot(warning = TRUE, ...)`. Capture return value and verify no old
repwt columns remain.

For `> 10%` failure: construct a scenario (or use a mock) that causes exactly
1 of 9 replicates to fail when `groups = 9` — that is `11.1%` failure rate.
Verify `surveywts_warning_dagjk_replicates_failed` is emitted.

For small groups warning: use a dataset where `floor(combined_N / groups) < 5`
(e.g., combined_N = 20, groups = 9, giving floor(20/9) = 2 < 5). Verify
`surveywts_warning_dagjk_small_groups` is emitted with
`expect_warning(class = "surveywts_warning_dagjk_small_groups")`.

### 3.12 Edge cases

| Scenario | Expected behavior |
|----------|-------------------|
| `groups = 2` (minimum valid) | Succeeds; returns 2 replicate columns |
| `groups` equals combined NPS + reference count | Each group has exactly 1 unit; many replicates may fail; function warns if > 10% fail |
| NPS has only 1 unit per group (very small NPS, small `groups`) | Model may converge or fail; test that at least one valid replicate is produced for a non-pathological case |
| Calibration history present but calibration itself fails in some replicates | Those replicates counted as failed; if > 10%, warning emitted; if all, error |
| `reference_sample` argument overrides stored reference | Result uses `reference_sample`; no warning about override |
| Dataset with all covariates perfectly predicting group membership in one group | Degenerate propensity scores in that replicate → replicate counted as failed |
| Refitted model produces NA propensity scores for any unit (covariate level absent after group deletion) | NA propensity scores → replicate counted as failed; does not propagate as NA pseudo-weights |
| N_hat_g - n_nps_g < 0 (NPS count exceeds estimated population size in a replicate) | Negative adjustment factor detected → replicate counted as failed before model fitting. **Construction:** reference with n = 5 units each with weight = 1 (so N_hat ≈ 5); NPS with n = 50 units; `groups = 10` (each group has ≈ 5 NPS units). In each replicate n_nps_g ≈ 45 >> N_hat_g ≈ 4 — the negative-adjustment condition triggers reliably. |
| No calibration history (IPW only) | No calibration step in any replicate; function completes without calibration-related errors |

### 3.13 Invariants

After every successful call, assert all of the following:

- `S7::S7_inherits(result, surveycore::survey_nonprob)` is `TRUE`
- `length(result@variables$repweights) >= 1`
- All column names in `result@variables$repweights` exist in `names(result@data)`
- All replicate weight columns are `numeric`
- In the output, each NPS unit has exactly one zero-valued entry across all
  `G_success` replicate columns: the column corresponding to the group that
  unit was assigned to. Failed replicate columns are not present in the output
  and contribute no zeros. Test by fixing `seed` to make group assignment
  deterministic, then checking the zero pattern against the expected group
  membership.
  **Simplified invariant (for tests that do not track group assignment):** No
  replicate weight is `NA`; all non-zero values are positive.
- `result@variables$scale` equals `(G_used - 1) / G_used` where `G_used =
  length(result@variables$repweights)`, within tolerance `1e-12`.
- `all(result@variables$rscales == 1)` is `TRUE`
- `isTRUE(result@variables$mse)` is `TRUE`
- `identical(result@variables$type, "group-jackknife")` is `TRUE`
- `result@variables$weights` column is unchanged (same values as input)
- The last history entry has `operation == "group_jackknife_weights"`
- No NA values in any replicate weight column (NA propensity scores cause replicate failure, not NA weight propagation)

---

## 4. Scaling Factor Correctness

The most critical numerical invariant is the scaling factor. This must be
tested explicitly as a named test:

```
test_that(
  "create_group_jackknife_weights() sets scale to (G-1)/G, not (n-1)/n",
  ...
)
```

Test logic:
- Run with `groups = 10L` on a dataset with NPS n = 100, reference n = 100.
- Verify `result@variables$scale` equals `9/10 = 0.9`, within tolerance `1e-12`.
- Verify it does NOT equal `(200-1)/200 = 0.995` (the incorrect total-n formula).

---

## 5. Model Refit Correctness

The DAGJK must refit the binary logistic model in every replicate. This is the
single most common implementation error per the literature. Test it with a
named test:

```
test_that(
  "create_group_jackknife_weights() refits the logistic model per replicate",
  ...
)
```

Strategy: Construct a dataset where one group (fixed via `seed`) contains ALL
units with a specific covariate level (e.g., `age_group = "55+"`). A correctly
refitting model must handle the missing level when group $g$ is deleted —
either by collapsing it or refitting without it — producing pseudo-weights that
are structurally different from a proportional rescaling of the full-sample
weights. A non-refitting implementation would assign the full-sample
propensity scores to the remaining units unchanged, producing weights
proportional to the full-sample weights.

Implementation approach:
1. Build a dataset where one covariate level is entirely contained within
   one group. Fix `seed` so that group assignment is deterministic.
2. Call `create_group_jackknife_weights()` and identify the replicate column
   corresponding to the group that contains all units with the special covariate
   level.
3. For the non-deleted units in that replicate, compute the ratio
   `repwt_g[i] / full_wt[i]` for each unit $i$.
4. Assert that this ratio is NOT constant (up to floating-point tolerance
   `1e-8`) across non-deleted units. A constant ratio would indicate the
   full-sample propensity scores were applied without refitting.
5. Assert that the replicate succeeds (does not produce NA pseudo-weights for
   remaining units — the model refits on the available covariate levels).

---

## 6. Zero-Weight Assignment

```
test_that(
  "create_group_jackknife_weights() assigns weight 0 to deleted group units",
  ...
)
```

For a known group assignment (controlled by `seed`), verify that:
- Units assigned to group 1 have `repwt_1 == 0`.
- Those same units have `repwt_g > 0` for all `g != 1`.

---

## 7. Reference Weight Adjustment

```
test_that(
  "create_group_jackknife_weights() applies reference weight adjustment per replicate",
  ...
)
```

The within-replicate reference weight adjustment is an internal implementation
detail. The adjusted reference weights are used inside the per-replicate model
fitting step and are not separately observable via the public API. This
adjustment is covered indirectly by the model refit correctness test (§5) —
if the reference weights were not adjusted, the model-fitting inputs would
differ from the correctly-adjusted inputs, and the covariate-depletion test
would detect this through the non-proportional weight pattern. No separate
direct test is written for this adjustment.

---

## 8. Gotcha Coverage

Every gotcha from `comprehension.md` must either have a test or a documented
rationale for exclusion.

| Gotcha | Coverage |
|--------|----------|
| Refit the model in every replicate | §3.4 (calibration changes replicate weights) + §5 (model refit correctness test) |
| Scaling factor is `(G-1)/G`, not `(n-1)/n` | §4 (explicit named test) |
| Minimum `G` — `G = 1` is degenerate | §3.8 (`groups = 1` error path) |
| `G` choice and group size — small groups may fail | §3.12 (groups = combined N) + §3.11 (>10% failure warning) |
| Degenerate groups / single-unit groups | §3.12 (NPS with 1 unit per group) |
| Non-convergence in a replicate | §3.11 (warning for >10% failures) + §3.10 (all fail error) |
| Groups span combined NPS + reference dataset | §3.6 (correct reference handling) + §7 (reference weight adjustment proxy) |
| Reference weight adjustment | §7 (proxy test) |
| Negative adjustment factor (N_hat_g < n_nps_g) | §3.12 (new edge case row — replicate counted as failed) |
| NA propensity scores from covariate level depletion | §3.12 (new edge case row — replicate counted as failed) |
| Negative replicate weights | §3.11 (warning test) |
| Nonsample variance component | Out of scope — documented limitation only. No test possible (requires knowing the true nonsample variance). Noted in `@details`. |
| No formal consistency proof | Out of scope — documentation only. |
| Single-PSU/single-cluster in a stratum | Covered by degenerate groups test (§3.12). The NPS analogue is a covariate cell with one unit in one group. |
| Bootstrap theory gap (jackknife preferred) | Out of scope — documentation only. |
| DR estimator bias | Out of scope per HOLD-1 resolution — documentation only, no runtime signal, no test needed. |

---

## 9. Tolerances

| Quantity | Tolerance | Rationale |
|----------|-----------|-----------|
| Scale factor `(G-1)/G` | `1e-12` | Exact rational arithmetic; floating-point should be exact for small `G` |
| Replicate weight values | `1e-10` | Consistent with package-wide weight computation tolerance |
| Logistic model convergence (epsilon passed to inner fitter) | Uses `epsilon` from ipw history entry; not separately validated in tests |

---

## 10. Profile Gates

| Gate | Pass criterion |
|------|---------------|
| Line coverage on new file | ≥ 98% |
| R CMD check | 0 errors, 0 warnings, ≤2 pre-approved notes |
| All `expect_snapshot(error = TRUE)` calls reviewed and approved | No stale snapshots |
| All `expect_warning(class = ...)` calls have corresponding snapshot | Each warning path has a `expect_snapshot(warning = TRUE)` pair |
