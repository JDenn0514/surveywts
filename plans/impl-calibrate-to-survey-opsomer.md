# Implementation Plan — calibrate-to-survey-opsomer

**Status**: PLAN_READY
**Spec**: `plans/spec-calibrate-to-survey-opsomer.md`
**Test-spec**: `plans/test-spec-calibrate-to-survey-opsomer.md`
**Target version**: 0.6.0.9000

**Decisions from plan review (Pass 1 → resolved):**
- svrep stays in `Imports` for this PR range — `calibrate_to_estimate()` still
  calls `svrep::calibrate_to_estimate()` unconditionally (changing that is Out
  of scope per spec); DESCRIPTION change dropped from PR 2
- `.to_svyrep()` and `.method_to_calfun()` moved to `calibrate-utils.R` (not
  deleted) — both are used by `calibrate_to_estimate.R`; `calibrate-utils.R`
  added to PR 2 file list
- Mock mechanism specified: `testthat::local_mocked_bindings()`
- `.calibrate_replicate_opsomer()` named explicitly in PR 2
- Coverage criterion added to PR 1
- `@param bounds` stale note flagged for removal in PR 2 docs

---

## Overview

This plan delivers the Opsomer & Erciulescu (2022) replication variance
adjustment for `calibrate_to_survey()`: new `targets`, `type`, and `algorithm`
arguments; a self-contained Opsomer per-replicate calibration path that replaces
the existing `svrep::calibrate_to_sample()` delegation; 6 new error classes; and
updated Tier 3 documentation. svrep remains in `Imports` (not demoted to
Suggests) because `calibrate_to_estimate()` still uses it and is out of scope
for this PR range. The work is split into two PRs: the first covers signature
changes and validation; the second covers the algorithm and documentation.

---

## PR Map

- [x] PR 1: `feature/cts-opsomer-validation` — New signature, input validation (6 new error classes + scale + level checks), test helper updates
- [x] PR 2: `feature/cts-opsomer-algorithm` — Opsomer algorithm, svrep delegation removed, happy path + numerical tests, Tier 3 documentation, NEWS.md

---

## PR 1: New signature + validation + test helpers

**Branch:** `feature/cts-opsomer-validation`
**Depends on:** none

### What PR 1 delivers

- `targets`, `type`, `algorithm` added to the function signature with correct
  defaults and `rlang::arg_match()` wiring
- Validation steps 10–12 from the spec (scale_not_found, control_level_missing,
  all four targets-specific error classes)
- `make_replicate_design` and `make_nonprob_replicate_design` updated with an
  `R` parameter (backward-compatible default keeps `R = 50L`)
- Dual-pattern tests for all new error classes and regression guards for all
  existing error classes
- `svrep` delegation is kept for the `targets = NULL` path and is also called
  (incorrectly but harmlessly for test purposes) for the `targets != NULL` path;
  this stub is replaced in PR 2

### Files (TDD order)

1. `plans/error-messages.md` — verify all 6 new error classes already present
   (per decisions log they were added during spec phase); no changes expected,
   just confirm before writing any R code
2. `tests/testthat/helper-test-data.R` — add `R` parameter to both helpers
3. `tests/testthat/test-sample-calibration.R` — add new error tests
4. `R/calibrate_to_survey.R` — add new signature + validation steps 10–12
5. `changelog/calibration/feature-cts-opsomer-validation.md` — created last,
   before opening PR

**File details:**

**`tests/testthat/helper-test-data.R`**

Add `R = 50L` parameter to `make_replicate_design(n = 200L, seed = 42L)` —
change `replicates = 50L` to `replicates = R`. Keep `R = 50L` as default so all
existing call sites (`make_replicate_design(n = 200L, seed = 1L)`) are
unaffected.

Likewise add `R = 50L` parameter to `make_nonprob_replicate_design`.

Add an `R = 30L` default so the test-spec default `make_nonprob_replicate_design(n = 200, R = 30, seed = 99)` works.

Verify that both helpers produce designs where `@variables$scale` is non-NULL
(it comes from `create_bootstrap_weights()` via the survey package's scale
field).

**`tests/testthat/test-sample-calibration.R`** — add the following test blocks
(all TDD red-then-green):

_New `surveywts_error_scale_not_found` tests (dual pattern):_
- Primary `@variables$scale <- NULL`; `targets = NULL` — fires before any calibration (all-calls path)
- Primary `@variables$scale <- NULL`; `targets` non-NULL — same class, fires same step
- Control `@variables$scale <- NULL`; `targets = NULL`

_New `surveywts_error_targets_not_named_list` tests (dual pattern):_
- `targets = list(c(1000, 2000))` — unnamed element
- `targets = list()` — empty list (distinct message confirming "empty" wording)
- `targets = c(age = 1000)` — not a list at all

_New `surveywts_error_targets_variable_not_found` test (dual pattern):_
- `targets = list(nonexistent_col = c(a = 100))` — name absent from `primary_design@data`

_New `surveywts_error_targets_element_invalid` tests (dual pattern):_
- `targets = list(sex = "not_a_vector")` — not a named numeric vector or tibble
- `targets = list(sex = c(100, 200))` — unnamed numeric vector

_New `surveywts_error_targets_totals_invalid` tests (dual pattern):_
- `type = "count"`, a level total is `0`
- `type = "count"`, a level total is negative
- `type = "count"`, a level total is `NA`
- `type = "prop"`, proportions sum to 1.1 (not 1.0 within 1e-6)

_New `surveywts_error_control_level_missing` tests (dual pattern):_
- `variables` variable has a level in `primary_design@data` absent from
  `control_design@data`; `targets = NULL` path
- Same condition when `targets` non-NULL

_`type` / `algorithm` argument matching tests (no error expected):_
- `targets = NULL`, `type = "prop"` supplied — no error; `type` is matched but unused
- `algorithm = "nr"` supplied with `method = "linear"` — no error; matched but silently ignored

_Regression guard tests for existing error classes_ — duplicate the existing
error-path tests but WITHOUT `skip_if_not_installed("svrep")`, since after PR 2
these must pass without svrep installed. Add `targets = NULL` explicitly to each
guard test so they're forward-compatible when the svrep delegation is removed.
Label these blocks `"[regression guard]"` in the description string.

**`R/calibrate_to_survey.R`** — changes:

Add `targets = NULL`, `type = c("prop", "count")`, `algorithm = c("classic_ipf", "nr")`
to the function signature after `variables`.

At the top of the function body (after the existing `arg_match` on `method`):
```r
type      <- rlang::arg_match(type)
algorithm <- rlang::arg_match(algorithm)
```

Insert validation step 10 (after the existing replicate-scheme mismatch warning,
before the svrep call):
```r
A   <- primary_design@variables$scale
A_C <- control_design@variables$scale
if (is.null(A) || is.null(A_C)) {
  cli::cli_abort(
    c("x" = "...", "i" = "...", "v" = "..."),
    class = "surveywts_error_scale_not_found"
  )
}
```

Insert `.check_control_levels(primary_design, control_design, var_names)` call
(step 11 — a new lightweight helper that checks levels before delegation):
```r
.check_control_levels <- function(primary, control, var_names) {
  for (v in var_names) {
    p_levels <- unique(as.character(primary@data[[v]]))
    c_levels <- unique(as.character(control@data[[v]]))
    missing  <- setdiff(p_levels, c_levels)
    if (length(missing) > 0L) {
      cli::cli_abort(
        c("x" = "...", "i" = "...", "v" = "..."),
        class = "surveywts_error_control_level_missing"
      )
    }
  }
  invisible(TRUE)
}
```

Insert `.validate_targets_for_opsomer(targets, type, primary_design)` call (step
12 — fires only when `targets` is non-NULL):
```r
.validate_targets_for_opsomer <- function(targets, type, primary_design) {
  # Step 12a: named non-empty list check
  # Step 12b: variable names exist in primary_design@data
  # Step 12c: element format check (named numeric vector or tibble)
  # Step 12d: totals valid (prop sums to 1 within 1e-6, or counts > 0 non-NA)
}
```

Keep the existing svrep delegation path unchanged for now (PR 2 replaces it).
When `targets` is non-NULL and passes validation, fall through to the same svrep
delegation (with `targets` ignored). This produces wrong output for the non-NULL
targets path, but no PR 1 test exercises that path's output — PR 1 only tests
error conditions.

### Acceptance criteria — PR 1

- [ ] All new tests are confirmed failing (red) before any R source changes
- [ ] `plans/error-messages.md` — all 6 new error classes present (verified, no changes needed)
- [ ] `make_replicate_design(n, R, seed)` and `make_nonprob_replicate_design(n, R, seed)` accept `R` parameter; all existing call sites unaffected
- [ ] `surveywts_error_scale_not_found` fires (dual pattern) for all three trigger conditions
- [ ] `surveywts_error_targets_not_named_list` fires (dual pattern) for unnamed element, empty list, and non-list
- [ ] `surveywts_error_targets_variable_not_found` fires (dual pattern)
- [ ] `surveywts_error_targets_element_invalid` fires (dual pattern) for string element and unnamed vector
- [ ] `surveywts_error_targets_totals_invalid` fires (dual pattern) for zero count, negative count, NA count, prop ≠ 1
- [ ] `surveywts_error_control_level_missing` fires (dual pattern) for both `targets = NULL` and `targets` non-NULL triggers
- [ ] `type` and `algorithm` arg_match without error when `targets = NULL`
- [ ] All existing error-class regression guards pass without `skip_if_not_installed("svrep")`
- [ ] All pre-existing tests still pass (svrep delegation unchanged for `targets = NULL`)
- [ ] `devtools::check()`: 0 errors, 0 warnings, ≤2 pre-approved notes
- [ ] `devtools::document()` run; NAMESPACE and man/ in sync
- [ ] `covr::package_coverage()` ≥ 95%; new validation helpers covered by error-path tests
- [ ] `changelog/calibration/feature-cts-opsomer-validation.md` written and committed

**spec coverage:** validation order steps 10–12; all 6 new error classes from error table; `type` arg-match spec item; `algorithm` arg-match spec item; test-spec error paths section (all 16 new error triggers).

**test-spec coverage:** all error path rows for new error classes; warning path regression guards; `type`/`algorithm` arg-match edge cases.

**Notes for implementor:**

- The existing validation step numbering in the code (steps 1–7 as comments) maps to validation order steps 1–9 in the spec (there's an off-by-one from the spec). Insert the new scale check after step 7 in the code (after the scheme-mismatch warning), and the targets checks after the scale check.
- `.check_control_levels()` is a PR 1 lightweight helper. In PR 2 it will be superseded by `.compute_control_totals()` which also raises this error. In PR 2, remove `.check_control_levels()` and the explicit call to it, relying on `.compute_control_totals()` for the check.
- `surveywts_error_scale_not_found` must fire even when `targets = NULL` — do not gate it on `!is.null(targets)`.
- `surveywts_error_control_level_missing` is checked inside `.check_control_levels()` (PR 1 temporary helper) and later inside `.compute_control_totals()` (PR 2). Both must raise the same error class.
- For the regression guard tests, remove `skip_if_not_installed("svrep")` because after PR 2 the function no longer calls svrep. PR 1 still uses svrep in the delegation path, so these tests pass in PR 1 even without the skip (svrep is still in Imports). After PR 2 merges, they pass because svrep is not called at all.
- The `type = "prop"` arg-match-but-unused test should call `calibrate_to_survey()` with `targets = NULL, type = "prop"` and confirm the result equals a call without `type` supplied (or just that no error is raised and a valid design is returned).

---

## PR 2: Opsomer algorithm + svrep removal + tests + documentation

**Branch:** `feature/cts-opsomer-algorithm`
**Depends on:** PR 1

### What PR 2 delivers

- Full Opsomer & Erciulescu (2022) algorithm for ALL calls (both `targets = NULL`
  and `targets` non-NULL)
- Three new internal helpers: `.compute_control_totals()`, `.calibrate_replicate_opsomer()`, updated `.validate_targets_for_opsomer()`
- Removal of svrep delegation: `.to_svyrep()`, `.svrep_calibrate_to_sample()`, `.method_to_calfun()` removed (or kept for `calibrate_to_estimate` if shared — check first)
- History entries updated: `a_constants` and `K` always present; `targets`, `type`, `fixed_variables` present when `targets` non-NULL
- `svrep` moved from `Imports` to `Suggests` in DESCRIPTION
- Updated Tier 3 roxygen2 documentation (all required sections)
- NEWS.md entries for the two breaking/additive changes
- All happy-path, numerical, gotcha, and edge-case tests from the test-spec

### Files (TDD order)

1. `tests/testthat/test-sample-calibration.R` — add happy-path and numerical tests (written first; confirmed red)
2. `R/calibrate_to_survey.R` — full Opsomer implementation (makes tests green)
3. `R/calibrate-utils.R` — receive `.to_svyrep()` and `.method_to_calfun()` moved from `calibrate_to_survey.R`
4. `NEWS.md` — document breaking default change and additive history schema change
5. `man/calibrate_to_survey.Rd` — regenerated by `devtools::document()`
6. `NAMESPACE` — regenerated by `devtools::document()`
7. `changelog/calibration/feature-cts-opsomer-algorithm.md` — created last, before opening PR

**Note:** `DESCRIPTION` is NOT changed in this PR. `svrep` remains in `Imports`
because `calibrate_to_estimate.R` still calls `svrep::calibrate_to_estimate()`
unconditionally. Demoting svrep to Suggests requires wrapping those calls in
`requireNamespace()` guards, which is out of scope (spec §Scope/Out: "Changes to
`calibrate_to_estimate()`").

**File details:**

**`tests/testthat/test-sample-calibration.R`** — add the following test blocks:

_Happy path: `targets = NULL` (Opsomer with no fixed margins):_

| Block description | Key assertions |
|-------------------|----------------|
| Returns `survey_replicate` | `S7::S7_inherits(result, surveycore::survey_replicate)` |
| Returns `survey_nonprob` | `S7::S7_inherits(result, surveycore::survey_nonprob)` |
| Weights change after calibration | `!identical(result@data[[wt_col]], original_weights)` |
| History entry operation | `last$operation == "calibrate_to_survey"` |
| History records `a_constants` (length = R_eff = R when K=1) | `length(params$a_constants) == 50L` |
| History records `K = 1L` | `params$K == 1L` |
| History `fixed_variables`, `targets`, `type` all NULL when `targets = NULL` | `is.null(params$fixed_variables)` etc. |
| `type = "prop"` supplied with `targets = NULL` — no error, `type` matched but unused | `test_invariants(result)` |

_Numerical comparison with svrep oracle (`skip_if_not_installed("svrep")` inside each block):_

| Block description | Key assertions |
|-------------------|----------------|
| `method = "linear"`, `targets = NULL` matches `svrep::calibrate_to_sample()` | `expect_equal(result_wts, svrep_wts, tolerance = 1e-8)` |
| `method = "rake"` (default) differs from svrep | `expect_false(isTRUE(all.equal(..., tolerance = 1e-4)))` |
| Default call satisfies control-survey totals | `expect_equal(calibrated_total, control_total, tolerance = 1e-6)` |

_Happy path: `targets` non-NULL (Opsomer with fixed margins):_

| Block description | Key assertions |
|-------------------|----------------|
| Returns `survey_replicate` when primary is replicate | class check |
| Returns `survey_nonprob` when primary is nonprob | class check |
| Data dimensions unchanged | `nrow`/`ncol` identical |
| History grows by exactly 1 | `n_after - n_before == 1L` |
| History records `fixed_variables` | `params$fixed_variables == "age_group"` |
| History records `a_constants` length R_eff = R when K=1 | `length == 50L` |
| History records `a_constants` length R_eff = K*R when K>1 | R=30, R_C=50, K=2 → `length == 60L` |
| History records `K = 1L` when R_C <= R | `params$K == 1L` |
| History records `K > 1L` when R_C > R | `params$K == 2L` |
| History records `type` | `params$type == "count"` |
| `type = "prop"` accepted | `test_invariants(result)` |
| `type = "count"` accepted | `test_invariants(result)` |
| Format B (tibble) targets accepted | `test_invariants` + fixed margin satisfied within 1e-6 |
| Mixed-format targets (one A, one B) accepted | Both fixed margins satisfied within 1e-6 |
| `reference_design` stored in history | `!is.null(params$reference_design)` |
| `control_col_matches` NOT in history | `!"control_col_matches" %in% names(params$control)` |

_`a_r` constants correctness (tolerance 1e-10):_

| Block description | Key assertion |
|-------------------|---------------|
| All `a_r = 1.0` when R = R_C = 50, A = A_C = 1/50 | `expect_equal(params$a_constants, rep(1.0, 50L), tolerance = 1e-10)` |
| `a_r = 0` for r > R_C when R > R_C | `expect_equal(params$a_constants[51:60], rep(0, 10L), tolerance = 1e-10)` |
| `a_r > 0` for r <= R_C when R > R_C | all positive, equal to `sqrt(A_C / A)` |
| `K = ceiling(R_C / R)` when R_C > R | `expect_identical(params$K, 2L)` |
| `A_eff = A / K` used in `a_r` when R_C > R | `a_r == sqrt(A_C / (A/2))` within 1e-10 |

_Numerical correctness — Opsomer path:_

| Block description | Tolerance |
|-------------------|-----------|
| Full-sample fixed-margin constraint satisfied | 1e-6 |
| Full-sample random-margin constraint satisfied | 1e-6 |
| Per-replicate fixed-margin constraint (one replicate) | 1e-4 |
| `type = "prop"` uses original primary weights as N | 1e-6 |
| Per-replicate calibration starts from original replicate weights (not calibrated full-sample weights) | `expect_false(isTRUE(all.equal(..., tolerance = 1e-4)))` |
| Variance comparison (only run at n=500, R=200; skip if property doesn't hold; annotate as fragile) | relaxed |

_Gotcha coverage:_

| Block description |
|-------------------|
| Fixed targets are invariant across replicates — manually construct perturbed totals and confirm fixed-margin column is unchanged |
| `@variables$scale = NULL` fires `surveywts_error_scale_not_found` (regression, fires in PR 1 already; confirm still fires after Opsomer path) |
| svrep not used in any code path — mock `svrep::calibrate_to_sample` to throw; confirm no error from valid calls (targets=NULL AND targets non-NULL) |
| R > R_C: `a_r = 0` for r > R_C; confirmed from `params$a_constants` |
| R_C > R: K = 2L, output has R (not R_C) replicate columns |
| Perturbed+fixed totals pathologically inconsistent — fires `surveywts_error_calibration_not_converged` or `surveywts_error_calibration_failed` |
| Near-zero cells (`a_r = 0` replicates): no Inf/NaN in output replicate weights |
| `control_col_matches` random by default: full-sample weights identical across seeds; replicate weights differ |
| `control_col_matches` fixed: all weights identical across two calls without `set.seed()` |

_Warning paths:_

| Block description |
|-------------------|
| `surveywts_warning_control_param_ignored` with `targets` non-NULL |
| `surveywts_warning_control_param_ignored` with `targets = NULL` (regression) |
| `surveywts_warning_replicate_scheme_mismatch` with `targets` non-NULL |
| `surveywts_warning_negative_calibrated_weights`: mock `survey::calibrate()` to return negative full-sample weight with `method = "linear"` |

_Edge cases:_

| Block description |
|-------------------|
| `targets = NULL, type = "prop"` — no error, result identical to call without `type` |
| `targets` variable overlaps with `variables` — no error; fixed margin applied |
| Single-variable, single-level `targets` — no error |
| `unit_scale` non-NULL with Opsomer path — no error; valid result |
| All `variables` also in `targets` — fixed margins take precedence |
| R = R_C = 2 (minimum) — K=1L, valid result |
| R = 1 (single primary replicate), R_C = 50 — K = 50L; 1 output replicate column |
| `method = "logit"`, finite `bounds`, valid `targets` — no error |
| `method = "linear"` with `targets` non-NULL — no error; negative replicate weights NOT clipped |
| `algorithm = "nr"` with `method = "linear"` — no error; result identical to same call without `algorithm` |
| `a_r = 0` replicates (R > R_C): no Inf/NaN in those replicates |
| Negative replicate weights do NOT trigger `surveywts_warning_negative_calibrated_weights` — confirm with `expect_no_warning` |

**`R/calibrate_to_survey.R`** — implementation changes:

Remove the svrep delegation path (steps 8–10 in the current code). Replace with:

1. **Move (do not delete) `.to_svyrep()` and `.method_to_calfun()` to `calibrate-utils.R`.**
   These are used by `calibrate_to_estimate.R` (lines 414 and 426). Delete them
   from `calibrate_to_survey.R` only after moving. `.svrep_calibrate_to_sample()`
   is specific to `calibrate_to_survey.R` and can be deleted entirely in PR 2
   (it is not referenced elsewhere).

2. Add `.compute_control_totals(control_design, var_names, primary_data)`:
   - For each variable in `var_names`, compute full-sample control totals `t̂_{Cx}`
     (weighted sum per level using `control_design@data[[v]] * control_full_weight`)
   - Compute per-replicate control totals `t̂_{Cx}^(r)` for r = 1..R_C
   - Also check level alignment here (raises `surveywts_error_control_level_missing`)
     — remove the `.check_control_levels()` call from the main function body once
     `.compute_control_totals()` is in place

3. Add `.calibrate_replicate_opsomer(weights_r, perturbed_totals, fixed_totals, calibration_spec, method, algorithm, control)`:
   - Takes original (pre-calibration) replicate weights for one virtual replicate
   - Combines `perturbed_totals` (for variables NOT in targets) and `fixed_totals`
     (for targets variables) into a single calibration spec
   - Calls `.calibrate_engine()` and returns the calibrated weight vector
   - Called once per virtual replicate in step 7

4. Implement Steps 1–8 of the Opsomer algorithm (from the spec "Opsomer algorithm" section) in the body of `calibrate_to_survey()`:
   - Steps 1–3: compute K, R_eff, A_eff, `a_r` vector
   - Step 4: call `.compute_control_totals()`
   - Step 4b: if `type = "prop"` and `targets` non-NULL, convert proportions to
     counts using N = `sum(primary_design@data[[wt_col]])`
   - Step 5: draw or use `control_col_matches`
   - Step 6: calibrate full-sample weights to combined targets via `.calibrate_engine()`
   - Step 7: for each primary replicate, repeat K times by calling
     `.calibrate_replicate_opsomer()`, average K results
   - Step 8: write back; build history entry

5. History entry: always include `a_constants` (numeric vector of length R_eff)
   and `K` (integer). When `targets` non-NULL, additionally include `targets`
   (after normalization to named numeric vectors), `type`, and `fixed_variables`.

6. Remove the `.check_control_levels()` helper introduced in PR 1 (its job is now
   done inside `.compute_control_totals()`).

7. Update the roxygen2 documentation with all required Tier 3 sections:
   - `@description` — note mixed fixed + random margins capability
   - `@param targets`, `@param type`, `@param algorithm`
   - `@param bounds` — remove the stale svrep-specific note "per-unit `bounds_scale`
     is not supported; use scalar bounds only"; replace with a description matching
     `.calibrate_engine()`'s bounds behavior (bounds on the calibrated-to-starting-
     weight ratio, applied in each `survey::calibrate()` call)
   - `@returns` — note that history always records `a_constants` and `K`
   - `@section Algorithm` — Opsomer perturbation formula using `\deqn{}`; a_r cases;
     K expansion rule; method/algorithm sub-section
   - `@section Convergence` — convergence failure on any replicate raises
     `surveywts_error_calibration_not_converged`
   - `@section Warnings` — three warning conditions in plain language
   - `@section Limitations` — independence assumption; nonprob note
   - `@references` — add Opsomer & Erciulescu (2022); keep Fuller (1998)
   - `@examples` — use `acs_wy_2022_svy` as primary; wrap any `svrep::` calls in
     `requireNamespace` guard; no `\dontrun{}`

**`R/calibrate-utils.R`** — receive `.to_svyrep()` and `.method_to_calfun()`
moved from `calibrate_to_survey.R`. No new tests required for these — they're
already covered indirectly by `calibrate_to_estimate()` tests.

**`NEWS.md`** — add two entries under the `## surveywts 0.6.0.9000` heading:
1. **Breaking default change**: `calibrate_to_survey()` default method for
   `targets = NULL` callers changes from linear GREG (svrep's default) to rake
   with `algorithm = "classic_ipf"`. Callers who need the prior behavior must
   pass `method = "linear"` explicitly.
2. **Additive history schema change**: history entry for `targets = NULL` calls
   gains `a_constants` and `K` fields. Existing key-name lookups on other fields
   are unaffected.

### Acceptance criteria — PR 2

- [ ] All new tests confirmed failing (red) before implementation begins
- [ ] spec-contract: `targets = NULL` happy path — returns correct class, weights change, history operation correct
- [ ] spec-contract: `a_constants` and `K` in history for ALL calls (including `targets = NULL`)
- [ ] spec-contract: `targets`, `type`, `fixed_variables` in history only when `targets` non-NULL
- [ ] spec-contract: `method = "linear"` full-sample weights match `svrep::calibrate_to_sample()` within 1e-8 (skip_if_not_installed in the test block)
- [ ] spec-contract: default rake call satisfies `t̂_{Cx}` totals within 1e-6
- [ ] spec-contract: full-sample fixed-margin constraint satisfied within 1e-6
- [ ] spec-contract: full-sample random-margin constraint satisfied within 1e-6
- [ ] spec-contract: `a_r` constants are correct within 1e-10 (all five sub-cases)
- [ ] spec-contract: `K = ceiling(R_C / R)` when `R_C > R`; output has R replicate columns
- [ ] spec-contract: per-replicate calibration starts from original (pre-calibration) primary replicate weights
- [ ] spec-contract: Format A, Format B, and mixed-format targets all accepted
- [ ] spec-contract: svrep is not called in any valid code path (mock test)
- [ ] spec-contract: `control_col_matches` not stored in history
- [ ] spec-contract: negative replicate weights NOT clipped (confirm `expect_no_warning` edge case passes)
- [ ] spec-contract: output object class matches `primary_design` class
- [ ] spec-contract: weighting history grows by exactly 1
- [ ] spec-contract: all gotcha tests pass
- [ ] spec-contract: all edge case tests pass
- [ ] spec-contract: svrep not called in any valid `calibrate_to_survey()` code path — verified with `testthat::local_mocked_bindings(.svrep_calibrate_to_sample = function(...) stop("must not be called"))` removed from the file (the function is deleted) and `svrep::calibrate_to_sample` mocked at the namespace level to confirm it is never reached
- [ ] `NEWS.md`: breaking default change and additive history schema change documented
- [ ] `devtools::document()` run; NAMESPACE and man/ in sync
- [ ] `devtools::check()`: 0 errors, 0 warnings, ≤2 pre-approved notes (svrep remains in Imports; confirm no NAMESPACE or R CMD check regressions from the `.to_svyrep()` / `.method_to_calfun()` move to `calibrate-utils.R`)
- [ ] `covr::package_coverage()` ≥ 95% (target 98%)
- [ ] All pre-PR-1 tests still pass; existing tests that called svrep-delegation path now exercise the Opsomer path; any `skip_if_not_installed("svrep")` in happy-path tests removed (svrep is no longer called in the calibrate_to_survey happy path)
- [ ] `changelog/calibration/feature-cts-opsomer-algorithm.md` written and committed

**spec coverage:** all items in spec §Function contracts that were not covered by PR 1; Opsomer algorithm steps 1–8; history entry schema; all edge cases table; all gotchas from comprehension.

**test-spec coverage:** all happy-path rows (both `targets = NULL` and non-NULL tables); all numerical correctness rows; all `a_r` constants correctness rows; all gotcha coverage rows; all warning path rows; all edge case rows.

**Notes for implementor:**

- `.to_svyrep()` and `.method_to_calfun()` ARE used by `calibrate_to_estimate.R` (confirmed at plan-review time). Move both to `calibrate-utils.R` before removing from `calibrate_to_survey.R`. `.svrep_calibrate_to_sample()` is only in `calibrate_to_survey.R` and can be deleted entirely.
- `.calibrate_engine()` is defined in `utils.R:781`. Its interface: `(data_df, weights_vec, calibration_spec, method, control)`. The `calibration_spec` argument requires a specific structure (`type`, `variables` as a list with `col` and `targets` per variable). Look at `calibrate_rake.R:401` for an example call.
- For the Opsomer per-replicate step (step 7), start from the *input* (pre-calibration) replicate weights `primary_design@variables$repweights[[r]]` — NOT from the calibrated full-sample weights. This distinction is tested explicitly in the numerical tests.
- For `R_C > R`: construct `R_eff = K * R` virtual replicates; for primary replicate `r`, the virtual replicates are `(r-1)*K + 1, …, r*K`. After calibrating each, average the K weight vectors to get the single output replicate. Record `K` and all `R_eff` `a_s` values in `a_constants`.
- For `type = "prop"` targets conversion: use `N = sum(primary_design@data[[primary_design@variables$weights]])` — the sum of full-sample weights in the input design (not post-calibration). Convert once; store original proportions in history (`targets` field).
- For the `control_col_matches` random draw: draw `sample(seq_len(min(R_eff, R_C)))` once per call. This draw applies to all replicates. When `K > 1`, the mapping is: virtual replicate `(r-1)*K + k` maps to control replicate `control_col_matches[[(r-1)*K + k]]` for `(r-1)*K + k <= R_C`.
- The combined target set for calibration (step 6 and step 7): combine `t̂_{Cx}` (for `variables NOT in targets`) and `T_fixed` (for `targets` variables). When a variable appears in both, `T_fixed` takes precedence (exclude that variable's control total from the random-margin set). Build the combined target as a list of `(variable, targets_per_level)` pairs that `.calibrate_engine()` can consume.
- `algorithm` is only passed to `.calibrate_engine()` when `method = "rake"`. When `method = "linear"` or `method = "logit"`, pass only `method` and `control`.
- Update the `@examples` block to use `acs_wy_2022_svy` (the only bundled dataset with `@variables$scale` populated). Construct a control design using `create_bootstrap_weights()`. All examples must run during `R CMD check` — no `\dontrun{}`. Any call to `svrep::` must be wrapped in `if (requireNamespace("svrep", quietly = TRUE)) { ... }`.
- The variance comparison edge case ("variance increase for non-calibration variable") is marked as fragile in the test-spec. Run it at `n=500, R=200` with a fixed seed. If the property doesn't hold in any seed configuration, annotate the block with a comment and use `expect_false(isTRUE(all.equal(replicate_wts_before, replicate_wts_after)))` as the minimal assertion (confirming calibration changed something) rather than a strict variance comparison.
- **Mock mechanism for "svrep not called" gotcha test**: since `.svrep_calibrate_to_sample()` is deleted in PR 2, mock at the svrep package namespace level. Use `testthat::local_mocked_bindings(calibrate_to_sample = function(...) stop("svrep must not be called"), .package = "svrep")` inside the test block. Confirm the function still returns a valid result when mocked — proving it doesn't call svrep. If `local_mocked_bindings` cannot bind to an external package's function, use the alternative: run the function with `svrep` unloaded via `detach("package:svrep")` in a `withr::defer` block and confirm no error is raised.
