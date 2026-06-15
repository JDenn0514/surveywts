# Test-spec — calibration-framework

---

## Reference oracle

- `survey::calibrate`, survey package current CRAN release
  - `calfun = "linear"` — oracle for `calibrate_linear(bounds = NULL)`
  - `calfun = "truncated"` with `bounds = c(L, U)` — oracle for
    `calibrate_linear(bounds = c(L, U))`
  - `calfun = "logit"` — oracle for `calibrate_logit()` (default bounds `c(1e-6, 1e6)`)
  - `calfun = "raking"` — oracle for `calibrate_rake(algorithm = "nr")`
- `survey::postStratify` — oracle for `poststratify()`
- `survey::rake()` — secondary reference for `calibrate_rake(algorithm = "classic_ipf")`

---

## Datasets

| Dataset | Purpose |
|---------|---------|
| `make_surveywts_data(n = 500, seed = 42)` | Standard calibration test data (primary) |
| `make_surveywts_data(n = 200, seed = 7)` | Smaller dataset for edge-case and oracle tests |
| `api` from `survey` package | Numerical oracle comparison (skip_if_not_installed inside block) |
| Inline `data.frame` | Edge cases requiring exact atypical values |

Target lists constructed inline from `make_surveywts_data()` distributions for
proportions; scaled to `n` for counts.

---

## Tolerances

| Estimand | Tolerance | Justification |
|----------|-----------|---------------|
| Calibrated weights vs oracle (survey::calibrate) | `1e-8` | NR convergence in survey package matches; floating-point roundtrip |
| Post-stratified weights vs oracle (survey::postStratify) | `1e-8` | Single-step ratio; same arithmetic |
| Weight conservation (sum before vs sum after, prop type) | `1e-10` | Exact in well-conditioned cases |
| Margin constraint satisfaction post-calibration | `1e-6` | Convergence tolerance of NR algorithms |

---

## Per-function test plan

### `calibrate_linear`

#### Happy paths

| # | Scenario | Input class | Oracle call / Expected outcome |
|---|----------|-------------|-------------------------------|
| H1 | Plain `data.frame`, `bounds = NULL`, `type = "prop"` | `data.frame` | `weighted_df`; `test_invariants(obj)` first; calibrated weights match `survey::calibrate(calfun = "linear")` within `1e-8` |
| H2 | `weighted_df` input, `bounds = NULL` | `weighted_df` | Returns `weighted_df`; `test_invariants(obj)` first; class preserved; history has 2 entries |
| H3 | `survey_taylor` input | `survey_taylor` | Returns `survey_taylor`; `@calibration$g_weights` equals `new_wts / base_wts`; `@calibration$lambda` is a numeric vector; `@calibration$method == "linear"` |
| H4 | `survey_nonprob` input | `survey_nonprob` | Returns `survey_nonprob`; class preserved; `test_invariants(obj)` first |
| H5 | `survey_replicate` input | `survey_replicate` | Returns `survey_replicate`; full-sample weights updated; replicate columns calibrated |
| H6 | `bounds = c(0.3, 3)`, `type = "prop"` | `data.frame` | Returns `weighted_df`; all g-weights in `[0.3, 3]`; matches `survey::calibrate(calfun = "truncated", bounds = c(0.3, 3))` within `1e-8`; also test with `survey_taylor` input to assert `@calibration$method == "truncated"` |
| H7 | `type = "count"`, targets in count form | `data.frame` | Returns `weighted_df`; weighted column sums match targets within `1e-6` |
| H8 | `reference_design` non-`NULL` | `data.frame` | History entry has `targets_from_reference = TRUE` |
| H9 | Format B targets (long data frame) | `data.frame` | Identical result to equivalent Format A targets |
| H10 | Plain linear produces negative weights | `data.frame` | Warning `surveywts_warning_negative_calibrated_weights`; `test_invariants(result)` after warning capture |

#### Numerical oracle

| # | Scenario | Dataset | Oracle call | Tolerance |
|---|----------|---------|-------------|-----------|
| N1 | Plain linear weights match survey package | `api` from survey | `survey::calibrate(svydes, ~age_group + sex, pop_totals, calfun = "linear")` | `1e-8` |
| N2 | Truncated linear weights match survey package | `api` from survey | `survey::calibrate(svydes, ~age_group + sex, pop_totals, calfun = "truncated", bounds = c(0.5, 2.0))` | `1e-8` |

All oracle tests use `skip_if_not_installed("survey")` inside the `test_that()` block.

#### Error paths

| # | Error class | Trigger | Pattern |
|---|-------------|---------|---------|
| E1 | `surveywts_error_unsupported_class` | `data = list(x = 1)` | `expect_error(class=...)` + snapshot |
| E2 | `surveywts_error_empty_data` | `data = data.frame(x = character(0), w = numeric(0))` | `expect_error(class=...)` + snapshot |
| E3 | `surveywts_error_wt_name_not_scalar` | `wt_name = c("a", "b")` | `expect_error(class=...)` + snapshot |
| E4 | `surveywts_error_wt_name_empty` | `wt_name = ""` | `expect_error(class=...)` + snapshot |
| E5 | `surveywts_error_reference_design_not_taylor` | `reference_design = data.frame(x=1)` | `expect_error(class=...)` + snapshot |
| E6 | `surveywts_error_weights_not_found` | `weights = nonexistent_col` | `expect_error(class=...)` + snapshot |
| E7 | `surveywts_error_weights_not_numeric` | Weight column is `character` | `expect_error(class=...)` + snapshot |
| E8 | `surveywts_error_weights_nonpositive` | A weight value is `0` or negative | `expect_error(class=...)` + snapshot |
| E9 | `surveywts_error_weights_na` | A weight value is `NA` | `expect_error(class=...)` + snapshot |
| E10 | `surveywts_error_targets_variable_not_found` | `targets = list(nonexistent = c("a" = 1))` | `expect_error(class=...)` + snapshot |
| E11 | `surveywts_error_variable_not_categorical` | Calibration variable is numeric | `expect_error(class=...)` + snapshot |
| E12 | `surveywts_error_variable_has_na` | Calibration variable has `NA` | `expect_error(class=...)` + snapshot |
| E13 | `surveywts_error_population_level_missing` | A data level absent from targets | `expect_error(class=...)` + snapshot |
| E14 | `surveywts_error_population_level_extra` | A targets level absent from data | `expect_error(class=...)` + snapshot |
| E15 | `surveywts_error_population_totals_invalid` | `type = "prop"`, proportions sum to 0.99 | `expect_error(class=...)` + snapshot |
| E16 | `surveywts_error_margins_format_invalid` | `targets` is a plain unnamed list | `expect_error(class=...)` + snapshot |
| E17 | `surveywts_error_bounds_invalid_calibration` — `L >= 1` | `bounds = c(1.0, 3)` | `expect_error(class=...)` + snapshot |
| E18 | `surveywts_error_bounds_invalid_calibration` — `U <= 1` | `bounds = c(0.5, 0.9)` | `expect_error(class=...)` + snapshot |
| E19 | `surveywts_error_bounds_invalid_calibration` — length != 2 | `bounds = c(0.5, 2, 3)` | `expect_error(class=...)` + snapshot |
| E20 | `surveywts_error_bounds_invalid_calibration` — `NA` value | `bounds = c(NA, 2)` | `expect_error(class=...)` + snapshot |
| E21 | `surveywts_error_calibration_not_converged` (truncated, tight bounds) | `bounds = c(0.999, 1.001)`, extreme targets | `expect_error(class=...)` + snapshot |
| E22 | `surveywts_error_calibration_singular_system` | Two perfectly collinear calibration variables | `expect_error(class=...)` + snapshot |
| E23 | `surveywts_error_unit_scale_invalid` | `unit_scale = c(-1, rep(1, nrow(data) - 1))` (non-positive value) | `expect_error(class=...)` + snapshot |

#### Warning paths

| # | Warning class | Trigger | Pattern |
|---|---------------|---------|---------|
| W1 | `surveywts_warning_srs_no_weights` | Plain `data.frame` with `weights = NULL` | `expect_warning(class=...)`; result still returned |
| W2 | `surveywts_warning_negative_calibrated_weights` | Plain linear with extreme targets | `expect_warning(class=...)`; result still returned |
| W3 | `surveywts_warning_control_param_ignored` | `control = list(unknown_key = 5)` | `expect_warning(class=...)` |
| W4 | `surveywts_warning_replicate_calibration_failed` | `survey_replicate` where one replicate has infeasible targets | `expect_warning(class=...)`; `output@calibration$replicate_converged` has `FALSE` |

#### Edge cases

| # | Case | Input | Expected behavior |
|---|------|-------|-------------------|
| EC1 | 0-row data | `data.frame(age_group = character(0), w = numeric(0))` | Error `surveywts_error_empty_data` |
| EC2 | Single-row data | 1-row data frame with valid targets | Proceeds without error; returns `weighted_df`; `test_invariants(result)` |
| EC3 | All weights equal (already calibrated) | Data already matching targets | Returns weights unchanged (or nearly so); no warning |
| EC4 | Single-level calibration variable | One variable has only one level; targets match | Proceeds normally; weight adjustment uniform across that level |
| EC5 | `bounds = c(L, U)` with L very close to 1 from below | `bounds = c(0.9999, 1.5)` | No error if numerically valid; result has all g-weights in `[0.9999, 1.5]` |
| EC6 | Plain linear + `survey_nonprob` input | `survey_nonprob` with extreme targets | May emit `surveywts_warning_negative_calibrated_weights`; class preserved; `test_invariants(result)` |
| EC7 | Gotcha: bounds constrain g-weight ratio not raw weight | `bounds = c(0.3, 3)` | Verify g-weights (`new_wt / base_wt`) are in `[0.3, 3]`, not raw weights |
| EC8 | Weight conservation (`type = "count"`) | Standard data, count targets | `sum(calibrated_wts)` equals the common population total N implied by all margins; tolerance `1e-10` |
| EC9 | Weight conservation (`type = "prop"`) | Standard data, prop targets | `sum(calibrated_wts)` equals `sum(design_wts)`; tolerance `1e-10` |
| EC10 | Single-step for plain linear | `bounds = NULL` | `obj@calibration$n_iterations == 1L` for `survey_taylor` input |
| EC11 | Truncated-linear iterates (`n_iterations > 1`) | `bounds = c(0.3, 3)` with non-trivial targets | `survey_taylor` input; assert `obj@calibration$n_iterations > 1L` |

**Gotcha coverage notes:**
- EC7 directly tests the Bounds-apply-to-g-weight gotcha (comprehension.md).
- EC8–EC9 test the weight conservation quality gate (gate 6).
- EC10 tests the single-step quality gate (gate 7).
- E22 tests the singular system error class.
- W1 tests the SRS assumption warning for plain `data.frame` + `weights = NULL`.

---

### `calibrate_logit`

#### Happy paths

| # | Scenario | Input class | Expected outcome |
|---|----------|-------------|-----------------|
| H1 | Plain `data.frame`, `type = "prop"`, default bounds | `data.frame` | `weighted_df`; `test_invariants(obj)` first; all weights strictly positive |
| H2 | `weighted_df` input | `weighted_df` | Returns `weighted_df`; class preserved; `test_invariants(obj)` first |
| H3 | `survey_taylor` input | `survey_taylor` | Returns `survey_taylor`; `@calibration$lambda` is numeric vector (converged NR); all g-weights in `(1e-6, 1e6)` |
| H4 | `survey_nonprob` input | `survey_nonprob` | Returns `survey_nonprob`; `test_invariants(obj)` first |
| H5 | `survey_replicate` input | `survey_replicate` | Replicate columns calibrated; `replicate_converged` populated |
| H6 | `type = "count"` | `data.frame` | Returns `weighted_df`; weighted column sums match targets within `1e-6` |
| H7 | `reference_design` non-`NULL` | `data.frame` | `targets_from_reference = TRUE` in history |
| H8 | Format B targets | `data.frame` | Same result as equivalent Format A |
| H9 | Custom `bounds = c(0.3, 3)` | `data.frame` | All g-weights in open interval `(0.3, 3)` (soft bounds — never exactly at boundary) |
| H10 | Default bounds warn SRS for plain df | `data.frame`, `weights = NULL` | `surveywts_warning_srs_no_weights` emitted |

#### Numerical oracle

| # | Scenario | Dataset | Oracle call | Tolerance |
|---|----------|---------|-------------|-----------|
| N1 | Logit weights match survey package | `api` from survey | `survey::calibrate(svydes, ~age_group + sex, pop_totals, calfun = "logit")` | `1e-8` |

Use `skip_if_not_installed("survey")` inside the block.

#### Error paths

Same error classes as `calibrate_linear()` E1–E16, substituting
`calibrate_logit()` in the trigger call. All require `expect_error(class=...)` +
snapshot.

Additionally:

| # | Error class | Trigger | Pattern |
|---|-------------|---------|---------|
| E17 | `surveywts_error_bounds_invalid_calibration` — `L >= 1` | `bounds = c(1.0, 3)` | `expect_error(class=...)` + snapshot |
| E18 | `surveywts_error_bounds_invalid_calibration` — `U <= 1` | `bounds = c(0.5, 0.9)` | `expect_error(class=...)` + snapshot |
| E19 | `surveywts_error_bounds_invalid_calibration` — length != 2 | `bounds = c(0.5, 2, 3)` | `expect_error(class=...)` + snapshot |
| E20 | `surveywts_error_bounds_invalid_calibration` — `NA` value | `bounds = c(NA, 2)` | `expect_error(class=...)` + snapshot |
| E21 | `surveywts_error_calibration_singular_system` | Two perfectly collinear calibration variables | `expect_error(class=...)` + snapshot |
| E22 | `surveywts_error_calibration_not_converged` | `control = list(maxit = 1)` with non-trivial targets | `expect_error(class=...)` + snapshot |
| E23 | `surveywts_error_unit_scale_invalid` | `unit_scale = c(-1, rep(1, nrow(data) - 1))` (non-positive value) | `expect_error(class=...)` + snapshot |

#### Warning paths

| # | Warning class | Trigger | Pattern |
|---|---------------|---------|---------|
| W1 | `surveywts_warning_srs_no_weights` | Plain `data.frame` with `weights = NULL` | `expect_warning(class=...)`; result still returned |
| W2 | `surveywts_warning_control_param_ignored` | `control = list(unknown_key = 5)` | `expect_warning(class=...)` |
| W3 | `surveywts_warning_replicate_calibration_failed` | Replicate with infeasible targets | `expect_warning(class=...)` |

#### Edge cases

All edge cases from `calibrate_linear()` apply except truncated-linear-specific ones.
Additionally:

| # | Case | Input | Expected behavior |
|---|------|-------|-------------------|
| EC1 | Infeasible targets (g-weight pushed against default bounds) | Targets that would require g-weight > 1e6 | Error `surveywts_error_calibration_not_converged` |
| EC2 | Negative weights impossible (default bounds) | Any valid input | All output weights strictly positive; assert `all(weights(result) > 0)` |
| EC3 | Custom `bounds = c(0.3, 3)`, g-weight ratio verified | `bounds = c(0.3, 3)` with well-conditioned data | All `new_wt / base_wt` in open interval `(0.3, 3)` (never exactly at boundary) |
| EC4 | Converged lambda is NR lambda, not linear approx | `survey_taylor` input with non-trivial targets | `@calibration$lambda` must satisfy the logit calibration constraint, not `T_x^{-1} * discrepancy` |

**Gotcha coverage notes:**
- EC2 directly addresses "negative calibrated weights" gotcha — logit eliminates this.
- EC3 tests "bounds apply to g-weight ratio, not raw weight" (HIGH PRIORITY gotcha).
- EC4 tests Issue 22: lambda is the converged NR solution.
- W1 tests SRS warning for plain `data.frame` + `weights = NULL`.

---

### `calibrate_rake`

#### Happy paths

| # | Scenario | Algorithm | Input class | Expected outcome |
|---|----------|-----------|-------------|-----------------|
| H1 | `"classic_ipf"`, `type = "prop"` | classic_ipf | `data.frame` | `weighted_df`; `test_invariants(obj)` first; all weights positive |
| H2 | `"classic_ipf"`, `weighted_df` input | classic_ipf | `weighted_df` | Returns `weighted_df`; `test_invariants(obj)` first |
| H3 | `"classic_ipf"`, `survey_taylor` input | classic_ipf | `survey_taylor` | Returns `survey_taylor`; `@calibration$lambda` is `NULL`; `@calibration$method = "raking"` |
| H4 | `"classic_ipf"`, `survey_nonprob` input | classic_ipf | `survey_nonprob` | Returns `survey_nonprob`; `test_invariants(obj)` first |
| H5 | `"classic_ipf"`, `survey_replicate` | classic_ipf | `survey_replicate` | Replicate columns raked; `replicate_converged` populated |
| H6 | `"nr"`, `type = "prop"` | nr | `data.frame` | `weighted_df`; `test_invariants(obj)` first; all weights positive |
| H7 | `"nr"`, `survey_taylor` input | nr | `survey_taylor` | `@calibration$lambda` is numeric vector (not `NULL`); `@calibration$method = "raking"` |
| H8 | `"nr"`, `survey_nonprob` input | nr | `survey_nonprob` | Returns `survey_nonprob`; `test_invariants(obj)` first |
| H9 | `"classic_ipf"` with `cap = 3` | classic_ipf | `data.frame` | No weights exceed `3 * mean(w)` in final result |
| H10 | `type = "count"` | nr | `data.frame` | Weighted column sums match targets within `1e-6` |
| H11 | Format B targets | classic_ipf | `data.frame` | Same result as equivalent Format A |
| H12 | `reference_design` non-`NULL` | classic_ipf | `data.frame` | `targets_from_reference = TRUE` in history |
| H13 | History `operation = "calibrate_rake"` | classic_ipf | `data.frame` | History entry `operation` field is `"calibrate_rake"` |
| H14 | Plain `data.frame` + `weights = NULL` warns SRS | classic_ipf | `data.frame` | `surveywts_warning_srs_no_weights` emitted |

#### Numerical oracle

| # | Scenario | Dataset | Oracle call | Tolerance |
|---|----------|---------|-------------|-----------|
| N1 | NR raking matches survey::calibrate | `api` from survey | `survey::calibrate(svydes, ~age_group + sex, pop_totals, calfun = "raking")` | `1e-8` |
| N2 | classic_ipf matches survey::rake | `api` from survey | `survey::rake(svydes, ...)` | `1e-6` (IPF convergence tolerance) |

Use `skip_if_not_installed("survey")` inside each block.

#### Error paths

| # | Error class | Trigger | Pattern |
|---|-------------|---------|---------|
| E1–E16 | (Same common errors as `calibrate_linear()`) | Same triggers, `calibrate_rake()` call | `expect_error(class=...)` + snapshot |
| E17 | `surveywts_error_cap_not_supported_nr` | `cap = 3`, `algorithm = "nr"` | `expect_error(class=...)` + snapshot |
| E18 | `surveywts_error_calibration_not_converged` | `control = list(maxit = 1)`, far-from-target data, `algorithm = "nr"` | `expect_error(class=...)` + snapshot |
| E19 | `surveywts_error_calibration_singular_system` | Two perfectly collinear raking variables | `expect_error(class=...)` + snapshot |
| E20 | `surveywts_error_cap_not_positive` | `cap = 0, algorithm = "classic_ipf"` | `expect_error(class=...)` + snapshot |

#### Warning paths

| # | Warning class | Trigger | Pattern |
|---|---------------|---------|---------|
| W1 | `surveywts_warning_srs_no_weights` | Plain `data.frame` with `weights = NULL` | `expect_warning(class=...)`; result still returned |
| W2 | `surveywts_warning_control_param_ignored` — wrong algorithm key | `algorithm = "nr"`, `control = list(pval = 0.05)` | `expect_warning(class=...)` |
| W3 | `surveywts_warning_control_param_ignored` — unrecognized key | `control = list(unknown = 1)` | `expect_warning(class=...)` |
| W4 | `surveywts_warning_replicate_calibration_failed` | `survey_replicate` with infeasible replicate targets | `expect_warning(class=...)` |

#### Messages

| # | Message class | Trigger | Pattern |
|---|---------------|---------|---------|
| M1 | `surveywts_message_already_calibrated` | `algorithm = "classic_ipf"`, data already at targets | `expect_message(class=...)` |

#### Edge cases

| # | Case | Input | Expected behavior |
|---|------|-------|-------------------|
| EC1 | `cap` with `algorithm = "nr"` | `cap = 3, algorithm = "nr"` | Error `surveywts_error_cap_not_supported_nr` before any computation |
| EC2 | All variables already at target (classic_ipf) | Data whose weighted marginals already match targets | Message `surveywts_message_already_calibrated`; weights returned unchanged |
| EC3 | Non-convergence within maxit (nr) | `control = list(maxit = 1)`, targets far from data | Error `surveywts_error_calibration_not_converged` |
| EC4 | Raking with single-level variable | One variable with one level | Proceeds without error; weight adjustment bypasses that variable |
| EC5 | NR lambda stored for `algorithm = "nr"` | `survey_taylor` input, `algorithm = "nr"` | `output@calibration$lambda` is a numeric vector of length equal to model matrix columns |
| EC6 | `lambda = NULL` for `algorithm = "classic_ipf"` | `survey_taylor` input, `algorithm = "classic_ipf"` | `output@calibration$lambda` is `NULL` |
| EC7 | Weight conservation (`type = "count"`) | Standard data, count targets | `sum(calibrated_wts)` equals common population total N; tolerance `1e-10` |
| EC8 | Weight conservation (`type = "prop"`) | Standard data, prop targets | `sum(calibrated_wts)` equals `sum(design_wts)`; tolerance `1e-10` |
| EC9 | Replicate scaling for `type = "count"` | `survey_replicate` input, `type = "count"` | Each replicate's effective calibration target scaled by `sum(rep_wt) / sum(base_wt)`; verify by checking per-replicate constraint satisfaction |

**Gotcha coverage notes:**
- EC7–EC8 test weight conservation quality gate (gate 6).
- EC3 tests non-convergence path.
- EC2 tests already-calibrated path.
- EC9 tests the replicate population-total scaling rule (BLOCKING issue 8, now resolved in spec).
- "Unbounded upper g-weights (multiplicative/raking)" gotcha: documented limitation, not a testable error. Address in docs.
- "Redundant equation in marginal calibration" gotcha: handled internally by engine. Tested implicitly by N1/N2 oracle comparisons.

---

### `calibrate`

#### Happy paths

| # | Scenario | Expected outcome |
|---|----------|-----------------|
| H1 | Default method (`"rake"`) | Dispatches to `calibrate_rake()`; returns `weighted_df`; `test_invariants(obj)` first |
| H2 | `method = "linear"` | Dispatches to `calibrate_linear()`; returns `weighted_df`; `test_invariants(obj)` first |
| H3 | `method = "logit"` | Dispatches to `calibrate_logit()`; returns `weighted_df`; `test_invariants(obj)` first |
| H4 | `method = "rake"` with `algorithm = "nr"` in `...` | `algorithm` forwarded to `calibrate_rake()` |
| H5 | `method = "linear"` with `bounds = c(0.3, 3)` in `...` | `bounds` forwarded to `calibrate_linear()` |
| H6 | `method = "logit"` with `bounds = c(0.3, 3)` in `...` | `bounds` forwarded to `calibrate_logit()` |
| H7 | `method = "rake"` with `cap = 3` in `...` | `cap` forwarded to `calibrate_rake()` |
| H8 | `survey_nonprob` input, default method | Returns `survey_nonprob`; `test_invariants(obj)` first |

#### Error paths

| # | Error class | Trigger | Pattern |
|---|-------------|---------|---------|
| E1 | Unknown `method` | `method = "poststrat"` | `expect_error()` — `rlang::arg_match()` failure |
| E2+ | All dispatched-function errors | Forwarded from dispatched function | Same as corresponding function's error paths |

#### Edge cases

| # | Case | Expected behavior |
|---|------|-------------------|
| EC1 | `method = "linear"` result identical to direct `calibrate_linear()` call | `expect_equal(calibrate(..., method="linear"), calibrate_linear(...))` |
| EC2 | `method = "rake"` result identical to direct `calibrate_rake()` call | `expect_equal(calibrate(..., method="rake"), calibrate_rake(...))` |
| EC3 | `method = "logit"` result identical to direct `calibrate_logit()` call | `expect_equal(calibrate(..., method="logit"), calibrate_logit(...))` |

---

### `poststratify`

#### Happy paths

| # | Scenario | Input class | Expected outcome |
|---|----------|-------------|-----------------|
| H1 | Plain `data.frame`, `type = "prop"` | `data.frame` | `weighted_df`; `test_invariants(obj)` first; weighted cell proportions match targets within `1e-8` |
| H2 | `weighted_df` input | `weighted_df` | Returns `weighted_df`; `test_invariants(obj)` first; history has 2 entries |
| H3 | `survey_taylor` input | `survey_taylor` | Returns `survey_taylor`; `@calibration$cell_factors` is a named numeric vector |
| H4 | `survey_nonprob` input | `survey_nonprob` | Returns `survey_nonprob`; `test_invariants(obj)` first |
| H5 | `survey_replicate` input | `survey_replicate` | Returns `survey_replicate`; replicate columns post-stratified; `replicate_converged` populated |
| H6 | `type = "count"` targets | `data.frame` | Returns `weighted_df`; weighted cell counts match targets within `1e-8` |
| H7 | `reference_design` non-`NULL` | `data.frame` | `targets_from_reference = TRUE` in history |
| H8 | History `operation = "poststratify"` | `data.frame` | History entry `operation` field is `"poststratify"` (not `"calibrate_poststrat"`) |
| H9 | Multi-variable strata | `data.frame` | Joint cell weights match all specified cell targets |

#### Numerical oracle

| # | Scenario | Dataset | Oracle call | Tolerance |
|---|----------|---------|-------------|-----------|
| N1 | Post-stratified weights match survey package | `api` from survey | `survey::postStratify(svydes, ~age_group, pop_df)` | `1e-8` |
| N2 | Two-variable strata | `api` from survey | `survey::postStratify(svydes, ~age_group + sex, pop_df)` | `1e-8` |

Use `skip_if_not_installed("survey")` inside each block.

#### Error paths

| # | Error class | Trigger | Pattern |
|---|-------------|---------|---------|
| E1 | `surveywts_error_unsupported_class` | `data = list(x = 1)` | `expect_error(class=...)` + snapshot |
| E2 | `surveywts_error_empty_data` | 0-row `data.frame` | `expect_error(class=...)` + snapshot |
| E3 | `surveywts_error_wt_name_not_scalar` | `wt_name = c("a", "b")` | `expect_error(class=...)` + snapshot |
| E4 | `surveywts_error_wt_name_empty` | `wt_name = ""` | `expect_error(class=...)` + snapshot |
| E5 | `surveywts_error_margins_format_invalid` | `targets = list(age_group = c("18-34" = 0.5))` (named list, not df) | `expect_error(class=...)` + snapshot |
| E6 | `surveywts_error_no_strata_variables` | `targets = data.frame(target = c(0.5, 0.5))` | `expect_error(class=...)` + snapshot |
| E7 | `surveywts_error_targets_variable_not_found` | Targets column name not in data | `expect_error(class=...)` + snapshot |
| E8 | `surveywts_error_reference_design_not_taylor` | `reference_design = data.frame(x=1)` | `expect_error(class=...)` + snapshot |
| E9 | `surveywts_error_weights_not_found` | Explicit `weights = nonexistent_col` | `expect_error(class=...)` + snapshot |
| E10 | `surveywts_error_weights_nonpositive` | A weight ≤ 0 | `expect_error(class=...)` + snapshot |
| E11 | `surveywts_error_weights_na` | A weight is `NA` | `expect_error(class=...)` + snapshot |
| E12 | `surveywts_error_variable_has_na` | A strata variable has `NA` | `expect_error(class=...)` + snapshot |
| E13 | `surveywts_error_population_totals_invalid` (prop, bad sum) | `type = "prop"`, targets sum to 0.99 | `expect_error(class=...)` + snapshot |
| E14 | `surveywts_error_population_totals_invalid` (count, non-positive) | `type = "count"`, one target is `0` | `expect_error(class=...)` + snapshot |
| E15 | `surveywts_error_population_cell_duplicate` | Same cell appears twice in targets | `expect_error(class=...)` + snapshot |
| E16 | `surveywts_error_population_cell_missing` — data cell missing from targets | Data has cell not in targets | `expect_error(class=...)` + snapshot |
| E17 | `surveywts_error_population_cell_not_in_data` — targets cell with no data | Targets has cell not in data | `expect_error(class=...)` + snapshot |
| E18 | `surveywts_error_weights_not_numeric` | Weight column is `character` | `expect_error(class=...)` + snapshot |

#### Warning paths

| # | Warning class | Trigger | Pattern |
|---|---------------|---------|---------|
| W1 | `surveywts_warning_srs_no_weights` | Plain `data.frame` with `weights = NULL` | `expect_warning(class=...)`; result still returned |
| W2 | `surveywts_warning_replicate_calibration_failed` (exercises `surveywts_error_empty_stratum` path) | `survey_replicate` input where one replicate weight column has `sum(rep_wt[cell]) == 0` for a stratum cell (manually zero one replicate column's weights for one cell) | `expect_warning(class = "surveywts_warning_replicate_calibration_failed")`; corresponding `replicate_converged` entry is `FALSE`; full-sample weights are unchanged |

#### Edge cases

| # | Case | Input | Expected behavior |
|---|------|-------|-------------------|
| EC1 | `targets` is a named list (wrong type) | `targets = list(age_group = c("18-34" = 0.5, "35+" = 0.5))` | Error `surveywts_error_margins_format_invalid` |
| EC2 | 0-row data | `data.frame()` | Error `surveywts_error_empty_data` |
| EC3 | Single-row data with 1-cell targets | 1-row data, 1-cell targets | Proceeds; weight set to `target_count / 1`; `test_invariants(result)` |
| EC4 | Targets with extra cell not in data | `targets` has a cell with no observations | Error `surveywts_error_population_cell_not_in_data` |
| EC5 | History `operation` field is `"poststratify"` not `"calibrate_poststrat"` | Any valid call | Assert `history[[length(history)]]$operation == "poststratify"` |
| EC6 | `cell_factors` stored correctly | `survey_taylor` input | Assert `output@calibration$cell_factors` equals `target_counts / ht_estimates` per cell |
| EC7 | `type = "count"` single-cell | One cell, large count target | Weight = `target / old_sum_in_cell * old_weight`; `test_invariants(result)` |

**Gotcha coverage notes:**
- EC5 directly tests history operation string update (critical for downstream surveycore compatibility).
- EC6 tests cell_factors storage for variance estimation.
- "Singular T_x matrix" gotcha: post-stratification uses cell ratios not NR; not directly applicable. Covered by EC4 (empty cell in data triggers error).

---

## Cross-function tests

| # | Scenario | Expected behavior |
|---|----------|-----------------|
| CX1 | `calibrate(method = "rake")` and `calibrate_rake()` produce identical results | `expect_equal(result_dispatch, result_direct)` for same arguments |
| CX2 | `calibrate(method = "linear")` and `calibrate_linear()` produce identical results | `expect_equal(result_dispatch, result_direct)` |
| CX3 | `calibrate(method = "logit")` and `calibrate_logit()` produce identical results | `expect_equal(result_dispatch, result_direct)` |
| CX4 | History `operation` strings are distinct per function | One call each to `calibrate_linear`, `calibrate_logit`, `calibrate_rake`, `poststratify`; assert four distinct `operation` values |

---

## Invariants

- `test_invariants(obj)` is called as the **first assertion** in every
  `test_that()` block that constructs a `weighted_df` or `survey_nonprob`.
- For `survey_taylor` and `survey_replicate` outputs, manually assert:
  - `S7::S7_inherits(obj, surveycore::survey_taylor)` (or replicate)
  - `obj@variables$weights %in% names(obj@data)`
  - `all(obj@data[[obj@variables$weights]] > 0)` (except post-warning check
    for `calibrate_linear()` negative weights)

---

## Profile gates (tester runs ALL unless skip condition applies)

- [ ] `devtools::document()` — NAMESPACE/man/ unchanged after run
- [ ] `devtools::test()` — all tests pass
- [ ] `devtools::run_examples()` — all `@examples` run clean
- [ ] `R CMD check --as-cran` — 0 errors, 0 warnings, notes reviewed
- [ ] `pkgdown::build_site()` — SKIPPED (pre-pkgdown scope)
- [ ] `covr::package_coverage()` — >= 95% (target 98%)
