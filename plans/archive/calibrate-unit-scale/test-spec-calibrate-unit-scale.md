# Test-spec — calibrate-unit-scale

---

## Reference oracle

`survey::calibrate()` from the `survey` package (version >= 4.2).

**Additional oracle for absolute bounds (D6 fix):**

For `bounds_scale = "absolute"` tests, use `bounds.const = TRUE` in the
`survey::calibrate()` call. This argument tells `survey` to interpret the
`bounds` as absolute bounds on final weights (not on g-weights), matching
surveywts's `bounds_scale = "absolute"` semantics after the D6 fix:

```r
survey::calibrate(svy_design, formula = ~., population = pop_vec,
  calfun = "linear", bounds = c(L_abs, U_abs), bounds.const = TRUE)
```

Note: `bounds.const = TRUE` was added in `survey` >= 4.1. Tests should use
`skip_if_not_installed("survey")` and may additionally check
`packageVersion("survey") >= "4.1"` or use `skip()` if the feature is absent.

**Convention mapping (required for every oracle comparison):**

The `survey` package uses `variance = sigma2_k` where `sigma2_k = 1/q_k`.
surveywts uses `unit_scale = q_k` where `q_k = 1/sigma2_k`. To compare:

```r
# surveywts call
calibrate_linear(data, targets = tgts, weights = w, unit_scale = q)

# oracle call
svy_design <- survey::svydesign(ids = ~1, weights = ~w, data = data)
survey::calibrate(
  svy_design,
  formula = ~ var1 + var2,
  population = pop_vec,
  calfun = "linear",
  variance = 1 / q    # note the inverse
)
```

The `population` vector for `survey::calibrate()` includes an intercept term
equal to the sample total weight. Construct it from the same target
proportions/counts used in the surveywts call.

---

## Datasets

| Dataset | Construction | Purpose |
|---------|-------------|---------|
| `df_500` | `make_surveywts_data(n = 500, seed = 42)` | Primary calibration test data |
| `df_200` | `make_surveywts_data(n = 200, seed = 7)` | Smaller dataset for replicate loop tests |
| Inline 5-row df | Constructed in each edge-case test | Minimal, controlled inputs |
| `q_unequal` | `exp(rnorm(500, 0, 0.3))` with `set.seed(99)` | Realistic unequal q_k vector (positive, lognormal) |
| `q_all_twos` | `rep(2, 500)` | Constant non-unity q_k (tests uniform scaling) |
| `q_all_ones` | `rep(1, 500)` | Explicit all-ones q_k (regression guard) |

---

## Per-function test plan

All tests exercise `calibrate_linear()` and `calibrate_logit()` through their
public APIs. The internal engine is never referenced by name.

**Structural assertion rule:** Every `test_that()` block that produces a
`weighted_df` must call `test_invariants(result)` as its **first** assertion
before any numeric comparisons.

---

### `calibrate_linear()`

#### Happy paths

| ID | Scenario | Dataset | Oracle / Expected | Tolerance |
|----|----------|---------|-------------------|-----------|
| HL-1 | `unit_scale = NULL` matches `unit_scale = rep(1, n)` exactly | `df_500` | `calibrate_linear(df_500, targets, weights=base_weight, unit_scale=NULL)` weights equal `calibrate_linear(df_500, targets, weights=base_weight, unit_scale=rep(1,500))` weights | `1e-14` (machine precision) |
| HL-2 | `unit_scale = q_unequal`, unbounded, matches `survey::calibrate(variance=1/q_unequal)` | `df_500` | `survey::calibrate(..., calfun="linear", variance=1/q_unequal)` | `1e-8` |
| HL-3 | `unit_scale = q_all_twos`, unbounded, matches oracle | `df_500` | `survey::calibrate(..., calfun="linear", variance=1/q_all_twos)` | `1e-8` |
| HL-4 | `unit_scale = q_unequal`, bounded multiplicative `bounds=c(0.3, 3)`, matches `survey::calibrate(calfun="truncated", variance=1/q_unequal)` | `df_500` | Oracle with `calfun = survey::make.calfun("truncated", list(bounds=c(0.3,3)))` | `1e-8` |
| HL-5 | Calibration constraint holds when `unit_scale != NULL`: weighted proportions match targets | `df_500` with `q_unequal` | `sum(w[var==lev]) / sum(w) == target[lev]` for each level | `1e-8` |
| HL-6 | History entry records `unit_scale` as supplied | `df_500` with `q_unequal` | `attr(result, "weighting_history")[[1]]$parameters$unit_scale` identical to `q_unequal` | exact |
| HL-7 | `unit_scale` is unchanged when `bounds = NULL` vs `bounds = c(0.5, 2)` with same q | `df_500` with `q_unequal` | Outputs differ between bounded/unbounded (different F-functions) — verify they are NOT equal | exact |
| HL-8 | `bounds_scale = "absolute"`, unequal weights, matches `survey::calibrate(bounds.const = TRUE)` | `df_500` | Oracle: `survey::calibrate(..., calfun="linear", bounds=c(L_abs, U_abs), bounds.const=TRUE)` | `1e-8` |
| HL-9 | `bounds_scale = "absolute"`, equal base weights: post-fix identical to pre-fix approximation | `df_500` with all weights set to `mean(df_500$base_weight)` | `calibrate_linear(bounds_scale="absolute")` weights equal oracle `survey::calibrate(bounds.const=TRUE)` AND equal what old `mean(d_k)` approach would have produced | `1e-8` |
| HL-10 | `bounds_scale = "absolute"`, unequal weights: post-fix output DIFFERS from old `mean(d_k)` approximation | `df_500` (unequal base weights) | The per-unit approach output is not equal to the old scaled-weights output; `max(abs(diff)) > 0` | exact inequality |
| HL-11 | `bounds_scale = "absolute"` + `unit_scale = q_unequal` combined — matches oracle `survey::calibrate(bounds.const=TRUE, variance=1/q_unequal)` | `df_500` | `survey::calibrate(..., calfun="linear", bounds=c(L_abs, U_abs), bounds.const=TRUE, variance=1/q_unequal)` | `1e-8` |
| HL-12 | Unbounded linear, `unit_scale = q_unequal`: engine converges in exactly 1 NR iteration | `df_500` | `weighting_history[[1]]$convergence$iterations == 1L`; would be `> 1` if D2 (Jacobian weighting) were missing | exact |

**Note on HL-8 oracle:** Use `survey::calibrate()` with `bounds.const = TRUE` and the
original absolute bound values. The `bounds.const = TRUE` argument makes `survey`
interpret bounds as absolute (on final weights), matching surveywts's
`bounds_scale = "absolute"`:

```r
survey::calibrate(
  svy_design,
  formula = ~ age_group + sex,
  population = pop_vec,
  calfun = "linear",
  bounds = c(L_abs, U_abs),   # e.g., c(0.5, 5.0)
  bounds.const = TRUE          # absolute bounds on final weights
)
```

**Note on HL-4:** `survey::calibrate()` with `calfun = "truncated"` and
`bounds` in the `calfun.list` argument. Construct via:

```r
survey::calibrate(
  svy_design,
  formula = ~ age_group + sex,
  population = pop_vec,
  calfun = survey::make.calfun("truncated", list(bounds = c(0.3, 3))),
  variance = 1 / q_unequal
)
```

Use `skip_if_not_installed("survey")` inside the test block. Additionally
check `packageVersion("survey") >= "4.1"` and call `skip()` if the condition
is not met — `survey::make.calfun()` behavior may differ across `survey`
versions before 4.1.

**Note on HL-11 oracle:** Combines `bounds.const = TRUE` and `variance = 1/q_unequal`
in the same `survey::calibrate()` call:

```r
survey::calibrate(
  svy_design,
  formula = ~ age_group + sex,
  population = pop_vec,
  calfun = "linear",
  bounds = c(L_abs, U_abs),
  bounds.const = TRUE,
  variance = 1 / q_unequal
)
```

Use `skip_if_not_installed("survey")` inside the block. Check
`packageVersion("survey") >= "4.1"`. This is the only test that simultaneously
exercises the D6 per-unit bounds fix and D1/D2/D3 q-weighting on the
absolute-bounds code branch.

**Note on HL-12 (D2 coverage):** For unbounded linear calibration, the NR Jacobian
`X' diag(d·q) X` equals the Hessian at the solution exactly, so the update from
`lambda = 0` with the correct Jacobian is a one-step exact solve. If D2 is missing
(Jacobian uses `diag(d)` instead of `diag(d·q)`), the first step does not reach the
fixed point and the engine iterates further — `n_iterations > 1L`. Access via:
`attr(result, "weighting_history")[[1]]$convergence$iterations`.

#### Oracle comparison setup

All oracle comparisons require `skip_if_not_installed("survey")` inside the
test block. The oracle setup is:

```r
svy_design <- survey::svydesign(
  ids = ~1,
  weights = ~base_weight,
  data = df_500
)
pop_total_w <- sum(df_500$base_weight)
pop_vec <- c(
  `(Intercept)` = pop_total_w,
  `age_group35-54` = targets[["age_group"]]["35-54"] * pop_total_w,
  `age_group55+`   = targets[["age_group"]]["55+"]  * pop_total_w,
  sexF             = targets[["sex"]]["F"]           * pop_total_w
)
```

The population vector must match the model matrix column order produced by
`survey::calibrate()` with `formula = ~ age_group + sex` and R's default
treatment coding (first level of each factor dropped).

#### Regression guard

| ID | Scenario | Expected behavior |
|----|----------|-------------------|
| HL-RG | `unit_scale = rep(1, n)` produces weights identical to `unit_scale = NULL` | Weights equal within `1e-14`; this is the non-regression guard |

#### Warning paths (no change from pre-fix behavior)

| ID | Scenario | Expected |
|----|----------|---------|
| HLW-1 | `unit_scale != NULL` and unbounded linear produces negative weights | `surveywts_warning_negative_calibrated_weights` still fires |

#### Error paths (pre-existing; verify still correct after fix)

These test that the fix did not break existing validation. All use the dual
pattern: `expect_error(class = ...)` + `expect_snapshot(error = TRUE)`.

| ID | Error class | Trigger |
|----|-------------|---------|
| HLE-1 | `surveywts_error_unit_scale_invalid` | `unit_scale = c(-1, rep(1, 499))` (contains non-positive) |
| HLE-2 | `surveywts_error_unit_scale_invalid` | `unit_scale = rep(1, 499)` with 500-row data (wrong length) |
| HLE-3 | `surveywts_error_unit_scale_invalid` | `unit_scale = c(NA_real_, rep(1, 499))` (contains NA) |
| HLE-4 | `surveywts_error_unit_scale_invalid` | `unit_scale = "1"` (not numeric) |
| HLE-5 | `surveywts_error_calibration_not_converged` | Tight bounds with `unit_scale != NULL` causing divergence; dual pattern: `expect_error(class = "surveywts_error_calibration_not_converged")` + `expect_snapshot(error = TRUE)` |

---

### `calibrate_logit()`

#### Happy paths

| ID | Scenario | Dataset | Oracle / Expected | Tolerance |
|----|----------|---------|-------------------|-----------|
| HG-1 | `unit_scale = NULL` matches `unit_scale = rep(1, n)` exactly | `df_500` | Weights equal within `1e-14` | `1e-14` |
| HG-2 | `unit_scale = q_unequal`, default logit bounds, matches `survey::calibrate(calfun="logit", variance=1/q_unequal)` | `df_500` | Oracle with `calfun = "logit"`, `bounds = c(1e-6, 1e6)` | `1e-8` |
| HG-3 | `unit_scale = q_all_twos`, matches oracle | `df_500` | Same oracle pattern | `1e-8` |
| HG-4 | `unit_scale = q_unequal`, narrow bounds `c(0.3, 3)`, matches oracle | `df_500` | `survey::calibrate(..., calfun="logit", bounds=c(0.3,3), variance=1/q_unequal)` | `1e-8` |
| HG-5 | Calibration constraint holds: weighted proportions match targets | `df_500` with `q_unequal` | All target proportions matched | `1e-6` |
| HG-6 | History entry records `unit_scale` as supplied | `df_500` with `q_unequal` | `parameters$unit_scale` identical to `q_unequal` | exact |
| HG-7 | `bounds_scale = "absolute"`, unequal weights, matches `survey::calibrate(bounds.const = TRUE)` | `df_500` | Oracle: `survey::calibrate(..., calfun="logit", bounds=c(L_abs, U_abs), bounds.const=TRUE)` | `1e-8` |
| HG-8 | `bounds_scale = "absolute"`, equal base weights: post-fix identical to pre-fix approximation | `df_500` with all weights equalized | Output matches oracle (both `bounds.const = TRUE` and old mean-scale produce same answer when weights equal) | `1e-8` |
| HG-9 | `bounds_scale = "absolute"`, unequal weights: post-fix output DIFFERS from old `mean(d_k)` approximation | `df_500` (unequal base weights) | Per-unit output is not equal to old `scale_factor`-based output | exact inequality |
| HG-10 | `bounds_scale = "absolute"` + `unit_scale = q_unequal` combined, logit — matches oracle `survey::calibrate(calfun="logit", bounds.const=TRUE, variance=1/q_unequal)` | `df_500` (all base weights strictly inside `(L_abs, U_abs)`) | `survey::calibrate(..., calfun="logit", bounds=c(L_abs, U_abs), bounds.const=TRUE, variance=1/q_unequal)` | `1e-8` |

**Note on HG-7 oracle:**

```r
survey::calibrate(
  svy_design,
  formula = ~ age_group + sex,
  population = pop_vec,
  calfun = "logit",
  bounds = c(L_abs, U_abs),   # e.g., c(0.3, 8.0)
  bounds.const = TRUE          # absolute bounds on final weights
)
```

**Note on HG-2/HG-3/HG-4:** `survey::calibrate()` with `calfun = "logit"` and
`bounds` argument. The `bounds` argument in `survey::calibrate()` constrains
the g-weight ratio, matching surveywts's `bounds_scale = "multiplicative"`.

```r
survey::calibrate(
  svy_design,
  formula = ~ age_group + sex,
  population = pop_vec,
  calfun = "logit",
  bounds = c(0.3, 3),     # must match calibrate_logit(bounds = c(0.3, 3))
  variance = 1 / q_unequal
)
```

All oracle comparisons use `skip_if_not_installed("survey")` inside the block.

**Note on HG-10 oracle:** Combines `calfun = "logit"`, `bounds.const = TRUE`, and
`variance = 1/q_unequal`. Choose `L_abs` and `U_abs` so that all `df_500$base_weight`
values satisfy the logit precondition `d_k > L_abs` and `d_k < U_abs` — e.g.,
`L_abs = 0.1`, `U_abs = 15.0` given log-normal base weights. This is the only logit
test that exercises the absolute-bounds code branch together with non-unity `unit_scale`.

```r
survey::calibrate(
  svy_design,
  formula = ~ age_group + sex,
  population = pop_vec,
  calfun = "logit",
  bounds = c(L_abs, U_abs),
  bounds.const = TRUE,
  variance = 1 / q_unequal
)
```

Use `skip_if_not_installed("survey")` inside the block. Check
`packageVersion("survey") >= "4.1"`.

#### Regression guard

| ID | Scenario | Expected behavior |
|----|----------|-------------------|
| HG-RG | `unit_scale = rep(1, n)` identical to `unit_scale = NULL` | Weights equal within `1e-14` |

#### Error paths (pre-existing; verify still correct)

All use the dual pattern: `expect_error(class = ...)` + `expect_snapshot(error = TRUE)`.

| ID | Error class | Trigger |
|----|-------------|---------|
| HGE-1 | `surveywts_error_unit_scale_invalid` | `unit_scale = c(-1, rep(1, 499))` |
| HGE-2 | `surveywts_error_unit_scale_invalid` | Wrong length vector |
| HGE-3 | `surveywts_error_unit_scale_invalid` | Contains NA |
| HGE-4 | `surveywts_error_bounds_invalid_calibration` | `calibrate_logit(df, targets, weights = base_weight, bounds = c(2.0, 8.0), bounds_scale = "absolute")` where `min(df$base_weight) < 2.0` — base weight below `L_abs` |
| HGE-5 | `surveywts_error_bounds_invalid_calibration` | `calibrate_logit(df, targets, weights = base_weight, bounds = c(0.1, 0.5), bounds_scale = "absolute")` where `max(df$base_weight) > 0.5` — base weight above `U_abs` |

HGE-4 and HGE-5 use the dual pattern: `expect_error(class = "surveywts_error_bounds_invalid_calibration")` + `expect_snapshot(error = TRUE)`. The test data should ensure at least one base weight violates the constraint. Use an inline 5-row data frame with controlled weights for clarity.

---

### Replicate loop: `unit_scale` propagation

These tests require a `survey_replicate` input. Use `make_surveywts_data(n =
200, seed = 7)` wrapped in a `survey_taylor` then `create_bootstrap_weights()`.

| ID | Scenario | Expected behavior |
|----|----------|-------------------|
| RL-1 (linear) | `calibrate_linear()` with `survey_replicate` input and `unit_scale = q_unequal` — full-sample weights match oracle | `survey_replicate` produced; full-sample weight column matches `survey::calibrate(variance=1/q)` output | `1e-8` |
| RL-2 (linear) | `unit_scale = NULL` on replicate input: output identical to `unit_scale = rep(1, n)` on same replicate input | All replicate columns equal within `1e-14` | `1e-14` |
| RL-3 (logit) | `calibrate_logit()` with `survey_replicate` and `unit_scale = q_unequal` — full-sample weights match oracle | Result is `survey_replicate`; full-sample weight column matches `survey::calibrate(calfun="logit", variance=1/q_unequal)` output; `test_invariants(result)` first | `1e-8` |
| RL-4 (logit) | `unit_scale = NULL` replicate vs `unit_scale = rep(1, n)` replicate — identical | All replicate columns equal within `1e-14` | `1e-14` |
| RL-5 (linear) | `calibrate_linear()` with `survey_replicate` input, `bounds = c(L_abs, U_abs)`, `bounds_scale = "absolute"` — D6 fix in replicate loop | `test_invariants(result)` first; all final weights in every replicate column satisfy `w_k >= L_abs` and `w_k <= U_abs`; `skip_if_not_installed("survey")` inside block | exact bounds satisfaction |
| RL-6 (logit) | `calibrate_logit()` with `survey_replicate` input, `bounds = c(L_abs, U_abs)`, `bounds_scale = "absolute"`, all base weights strictly inside `(L_abs, U_abs)` — D6 fix in replicate loop | `test_invariants(result)` first; result is `survey_replicate`; calibration constraint holds on full-sample weights; all base weights satisfy the logit precondition `d_k > L_abs` and `d_k < U_abs` | `1e-6` (constraint) |

For RL-1 and RL-3: the oracle comparison is on the **full-sample** weight
column only (not replicate columns individually, since the oracle uses a
different replicate framework). Both use `skip_if_not_installed("survey")`
inside the block. RL-3 oracle: `survey::calibrate(calfun = "logit",
variance = 1/q_unequal)` — use the same `df_200`-derived `q_200` vector
(200-element `q_unequal` subset or separately seeded) as passed to `calibrate_logit()`.

`test_invariants(result)` is the first assertion in every replicate-loop test
that produces a survey object.

---

### Edge cases

| ID | Case | Input | Expected behavior |
|----|------|-------|-------------------|
| EC-1 | Single-row data with `unit_scale = c(2.0)` | 1-row df, `q = 2.0` | Calibration completes; `test_invariants(result)` passes; output weight satisfies calibration constraint |
| EC-2 | `unit_scale = rep(1e-6, n)` (uniform, very small) | `df_500`, `q = rep(1e-6, 500)` | Calibration converges; `test_invariants(result)` passes; calibration constraint holds within `1e-8`; for the unbounded-linear case, weights are numerically identical to `unit_scale = NULL` within `1e-14` (uniform `q_k` cancels in the NR update: `u_vec = q * X * lambda` and Jacobian `∝ d * F'(q*u) * q` — the scaling cancels in the one-step linear solution) |
| EC-3 | `unit_scale = rep(1e6, n)` (very large) | `df_500`, `q = 1e6` | Very loose penalty; calibration converges to same constraint-satisfying weights as q=1 (larger step sizes in NR); verify calibration constraint holds |
| EC-4 | `unit_scale` with one entry equal to `1e8`, rest equal to `1` (extreme single-unit scaling) | 20-row inline df | Converges; `test_invariants(result)` passes; calibration constraint holds within `1e-8`; a single dominant `q_k` does not make a full-rank Jacobian singular for typical calibration variables (2+ columns) |
| EC-5 | `unit_scale = rep(1, n)` (explicit, equal to default `NULL`) | `df_500` | Weights numerically identical to `unit_scale = NULL` within `1e-14` |
| EC-6 | `calibrate_linear(bounds = c(0.5, 2), unit_scale = q_unequal)` | `df_500` | Converges; all g-weights in `[0.5, 2]` (truncated-linear property); calibration constraint holds |
| EC-7 | `calibrate_logit(bounds = c(0.3, 3), unit_scale = q_unequal)` | `df_500` | Converges; all g-weights in open interval `(0.3, 3)`; calibration constraint holds |
| EC-8 | `bounds_scale = "absolute"`, all base weights equal (regression-break guard) | `df_500` with `base_weight` replaced by `rep(mean(base_weight), n)` | Linear and logit absolute-bounds output matches oracle `survey::calibrate(bounds.const = TRUE)` within `1e-8`; equal-weights case ensures pre-fix and post-fix are identical |
| EC-9 | `bounds_scale = "absolute"`, unequal base weights, linear: final weights bounded absolutely | `df_500` (log-normal `base_weight`) | All final weights satisfy `w_k >= L_abs` and `w_k <= U_abs` for every unit k; this would NOT hold with the pre-fix `mean(d_k)` approximation when weights are spread |
| EC-10 | `bounds_scale = "absolute"`, unequal base weights, logit: final weights in absolute interval | `df_500` (log-normal `base_weight`) | All final weights in `(L_abs, U_abs)` strictly; calibration constraint holds within `1e-6` |

---

## Tolerances

| Comparison | Tolerance | Justification |
|------------|-----------|---------------|
| `unit_scale = NULL` vs `unit_scale = rep(1, n)` regression guard | `1e-14` | Pure arithmetic equivalence; only difference is multiplying by `1`; machine-precision equality expected |
| surveywts vs `survey::calibrate()` oracle | `1e-8` | Both use Newton-Raphson with the same convergence criterion (`epsilon = 1e-7`); outputs match to approximately `epsilon` |
| Calibration constraint verification (`sum(w*x)/sum(w) == target`) | `1e-8` | Constraint satisfaction at NR convergence level |

Default tolerances from `testing-surveywts.md` apply:
- Point estimates (weight values): `1e-8` for oracle comparisons
- Regression guard (internal consistency): `1e-14`

Stricter `1e-14` tolerance for the regression guard is justified because
multiplying by `rep(1, n)` is a floating-point identity operation and any
deviation would indicate a code defect.

---

## Profile gates

- [ ] `devtools::document()` — `NAMESPACE`/`man/` unchanged after run (no new exports)
- [ ] `devtools::test()` — all tests pass; regression guard tests confirm no output change when `unit_scale = NULL`
- [ ] `devtools::run_examples()` — all `@examples` run clean (no example changes needed)
- [ ] `R CMD check --as-cran` — 0 errors, 0 warnings, notes reviewed
- [ ] `pkgdown::build_site()` — SKIPPED (no public API change; no new function documentation)
- [ ] `covr::package_coverage()` — >= 95% (target 98%); new branches in engine (the `q_weights` resolution) must be covered; absolute-bounds per-unit path in `calibrate_linear()` and `calibrate_logit()` must be covered (both full-sample and replicate-loop branches)
