# Spec — calibration-framework

**Status**: SPEC_READY
**Target version**: current dev (feature/calibrate-surveycore-infra)
**PR range**: PR 1–5

---

## Scope

### In

- **Delete** `R/calibrate_greg.R` entirely (no deprecated wrapper).
- **Delete** `R/calibrate_poststrat.R` entirely (no deprecated wrapper).
- **Add** `R/calibrate_linear.R` — new exported function `calibrate_linear()`.
- **Add** `R/calibrate_logit.R` — new exported function `calibrate_logit()` with user-configurable `bounds` argument (default `c(1e-6, 1e6)`).
- **Add** `R/poststratify.R` — rename of `calibrate_poststrat()` with updated
  docs and history operation string.
- **Modify** `R/calibrate_rake.R` — rename algorithm values
  (`"anesrake"` → `"classic_ipf"`, remove `"survey"`, add `"nr"`); update
  `cap` documentation. `bounds` argument removed — bounded calibration uses
  `calibrate_linear(bounds = ...)` or `calibrate_logit(bounds = ...)`.
- **Modify** `R/calibrate.R` — retarget dispatcher to
  `calibrate_linear()` / `calibrate_logit()` / `calibrate_rake()`; update
  `method` default to `"rake"`; update documentation.
- **Modify** `R/calibrate-utils.R` — add `.validate_bounds()` helper; add NR
  raking engine path; update `.format_history_step()` in `R/utils.R` to
  handle new operation strings.
- **Modify** `plans/error-messages.md` — add
  `surveywts_error_cap_not_supported_nr`,
  `surveywts_error_bounds_invalid_calibration`, and
  `surveywts_error_unit_scale_invalid` (all three now done); update four stale
  "Thrown by" entries: `surveywts_warning_negative_calibrated_weights`
  (`calibrate_greg()` → `calibrate_linear()`),
  `surveywts_warning_replicate_calibration_failed`
  (`calibrate_greg()`, `calibrate_poststrat()` → `calibrate_linear()`,
  `calibrate_logit()`, `poststratify()`),
  `surveywts_warning_control_param_ignored`
  (`calibrate_greg()` → `calibrate_linear()`, `calibrate_logit()`), and
  `surveywts_message_already_calibrated` (`"anesrake"` → `"classic_ipf"`).

### Out

- G-weight accessor function — out of scope; users access
  `obj@calibration$g_weights` directly.
- G-weight storage for `weighted_df` outputs — out of scope; `@calibration` is
  only populated for S7 survey objects.
- Continuous (numeric) auxiliary variable calibration — not supported; only
  categorical variables.
- `survey_replicate` inputs to `poststratify()` — supported (inherited from
  `calibrate_poststrat()`).

---

## Architecture

### Files touched

| File | Action | Notes |
|------|--------|-------|
| `R/calibrate_greg.R` | Delete | Replaced by `calibrate_linear.R` + `calibrate_logit.R` |
| `R/calibrate_poststrat.R` | Delete | Replaced by `poststratify.R` |
| `R/calibrate_linear.R` | Create | New export |
| `R/calibrate_logit.R` | Create | New export |
| `R/poststratify.R` | Create | Rename/rewrite of calibrate_poststrat |
| `R/calibrate_rake.R` | Modify | New algorithm values, `bounds` arg removed, docs update |
| `R/calibrate.R` | Modify | New dispatcher targets and default method |
| `R/calibrate-utils.R` | Modify | `.validate_bounds()`, NR engine path |
| `R/utils.R` | Modify | `.format_history_step()` new operation names |
| `NAMESPACE` | Generated | `devtools::document()` |
| `man/*.Rd` | Generated | `devtools::document()` |
| `plans/error-messages.md` | Modify | Two new classes added |

### Functions added

- `calibrate_linear(data, targets, weights, wt_name, bounds, bounds_scale, unit_scale, type, control, reference_design)`
- `calibrate_logit(data, targets, weights, wt_name, bounds, bounds_scale, unit_scale, type, control, reference_design)`
- `poststratify(data, targets, weights, wt_name, type, reference_design)`

### Functions modified (signature changes)

- `calibrate_rake(data, targets, weights, wt_name, type, algorithm, cap, control, reference_design)`
  — `algorithm` values change; `bounds` argument removed
- `calibrate(data, targets, weights, wt_name, type, reference_design, ..., method)`
  — `method` default changes to `"rake"`; dispatcher targets change

### Functions deleted (no wrapper)

- `calibrate_greg()`
- `calibrate_poststrat()`

### Class changes

None. `weighted_df` and `survey_nonprob` / `survey_taylor` / `survey_replicate`
class definitions are unchanged.

---

## Mathematical background

The Deville-Sarndal calibration framework (1992, 1993) adjusts survey weights
so that weighted marginal totals of auxiliary variables exactly match known
population totals. All methods in this family produce calibrated weights of the
form:

$$w_k = d_k \, F(\mathbf{x}_k' \boldsymbol{\lambda})$$

where $d_k$ are design weights (input `weights`), $\mathbf{x}_k$ is the row of
the calibration model matrix for unit $k$, and $\boldsymbol{\lambda}$ is the
Lagrange multiplier vector solved from the calibration constraint:

$$\sum_{k \in s} d_k \, F(\mathbf{x}_k' \boldsymbol{\lambda}) \, \mathbf{x}_k = \mathbf{t}_x$$

The linear GREG closed-form uses $\mathbf{T}_x = \sum_{k \in s} d_k q_k \mathbf{x}_k \mathbf{x}_k'$ (Deville & Sarndal 1992 eq. 2.5), where $q_k$ is supplied via the `unit_scale` argument and defaults to 1 for all units — see calibrate_linear() §Details.

The four $F$-function forms covered by this spec:

| Method | $F(u)$ | g-weight range |
|--------|--------|----------------|
| Linear | $1 + u$ | $(-\infty, +\infty)$ |
| Logit | $\frac{L(U-1) + U(1-L)\exp(Au)}{U - 1 + (1-L)\exp(Au)}$ | $(L, U)$ open |
| Raking (NR) | $\exp(u)$ | $(0, +\infty)$ |
| Truncated linear | clipped $1+u$ at $[L, U]$ | $[L, U]$ closed |

The g-weight is $g_k = w_k / d_k = F(\mathbf{x}_k' \boldsymbol{\lambda})$.
By default (`bounds_scale = "multiplicative"`), bounds $L$ and $U$ constrain
$g_k = w_k / d_k$. Use `bounds_scale = "absolute"` to constrain $w_k$
directly instead.

Sources: Deville & Sarndal (1992) §2 eq. (2.2); Deville, Sarndal & Sautory
(1993) §3.

---

## Function contracts

### `calibrate_linear(data, targets, weights, wt_name, bounds, bounds_scale, unit_scale, type, control, reference_design)`

#### Signature

```r
calibrate_linear(
  data,
  targets,
  weights          = NULL,
  wt_name          = "wts",
  bounds           = NULL,
  bounds_scale     = c("multiplicative", "absolute"),
  unit_scale       = NULL,
  type             = c("prop", "count"),
  control          = list(),
  reference_design = NULL
)
```

#### Purpose

Linear (GREG) calibration. Uses $F(u) = 1 + u$, which is exact in one Newton
step. When `bounds = NULL`, g-weights are unconstrained and negative calibrated
weights are possible. When `bounds = c(L, U)`, the method switches to
truncated-linear calibration where g-weights are constrained to $[L, U]$.

This function replaces `calibrate_greg(model = "linear")`.

#### @details

**Linear calibration ($F(u) = 1 + u$)**

The linear method solves the calibration constraint in a single matrix
operation:

$$\boldsymbol{\lambda} = \mathbf{T}_x^{-1}(\mathbf{t}_x - \hat{\mathbf{t}}_{x\pi})$$

where $\mathbf{T}_x = \sum_{k \in s} d_k q_k \mathbf{x}_k \mathbf{x}_k'$
(Deville & Sarndal 1992 eq. 2.5; $q_k = $ `unit_scale[k]`, defaulting to 1
when `unit_scale = NULL`) and $\hat{\mathbf{t}}_{x\pi} = \sum_{k \in s} d_k \mathbf{x}_k$ is the
Horvitz-Thompson estimate of $\mathbf{t}_x$. No iteration is needed; the first
Newton-Raphson step is exact because $F'(u) = 1$ is constant. The `maxit`
and `epsilon` control parameters are stored in the history entry for
plain-linear runs but do not affect computation — they are only active when
`bounds` is non-`NULL` (truncated-linear iteration). Default convergence
parameters `maxit = 50` and `epsilon = 1e-7` match `survey::calibrate()`
defaults; they are engineering choices, not values derived from the
Deville-Sarndal papers.

**Accepted weight types:** The `weights` argument accepts any pre-calibration
weight column — design weights ($d_k = 1/\pi_k$), nonresponse-adjusted
weights, or composite weights from a prior calibration step. The framework
adjusts whatever weights are provided to match the specified `targets`.

**SRS assumption when `weights = NULL`:** When `data` is a plain `data.frame`
and `weights = NULL`, all design weights are set to 1 (equivalent to assuming
a simple random sample). This assumption is signalled via
`surveywts_warning_srs_no_weights`. For non-probability samples or
unequal-probability designs, always supply design weights.

**Proportion-to-count conversion:** When `type = "prop"`, targets are
converted to count scale before entering the calibration constraint by
multiplying by $N = \sum_{k \in s} d_k$ (the weighted sample size under the
design weights, i.e., the estimated population total). This matches the
convention in `survey::calibrate()`.

**Note on $q_k$ (`unit_scale`):** The distance function in Deville & Sarndal
(1992) eq. (2.2) includes unit-specific scaling factors $q_k$ that control how
much each unit "resists" calibration adjustment — higher $q_k$ allows larger
deviation from the design weight at lower penalty. Setting $q_k = 1/x_k$ for a
size measure $x_k$ recovers the ratio estimator; setting $q_k$ proportional to
model error variance accommodates heteroskedastic working models. The
`unit_scale` argument provides the $q_k$ vector: `NULL` (default) sets $q_k = 1$
for all units (standard GREG); a positive numeric vector of length `nrow(data)`
sets per-unit values.

**Pitfalls:** The g-weight $w_k/d_k = 1 + \mathbf{x}_k'\boldsymbol{\lambda}$
is unbounded below. Large sample-population discrepancies can produce negative
calibrated weights, which propagate to any weighted total and may yield negative
estimates for intrinsically positive quantities. Use `calibrate_logit()` or
`calibrate_rake()` when negative weights are unacceptable.

**Truncated-linear calibration ($F(u)$ clipped to $[L, U]$)** — active when
`bounds = c(L, U)`:

$$F(u) = \begin{cases} L & u < L - 1 \\ 1 + u & L - 1 \le u \le U - 1 \\ U & u > U - 1 \end{cases}$$

With bounds, g-weights are constrained to the closed interval $[L, U]$ and
Newton-Raphson iteration is required. Negative calibrated weights are
impossible when $L > 0$. The g-weight ratio can exactly equal $L$ or $U$
(unlike the logit method, which uses an open interval).

**When to use linear over other methods:** Linear is the simplest and fastest
method. Use it when (a) negative weights are acceptable or rare given your
population targets, or (b) you want a direct, closed-form solution without
convergence concerns. Use `calibrate_logit()` or `calibrate_rake()` when
you need guaranteed-positive weights.

#### Arguments

- **`data`** — A `data.frame`, `weighted_df`, `survey_taylor`, `survey_nonprob`,
  or `survey_replicate`. Any other class triggers
  `surveywts_error_unsupported_class`. When `data` is a `survey_replicate`,
  calibration is applied independently to every replicate weight column using
  the same population `targets`. Replicate columns that fail calibration are
  kept at their original values and reported via
  `surveywts_warning_replicate_calibration_failed`; the full-sample calibration
  still completes normally.

- **`targets`** — Named list of population marginal targets (Format A) or a long
  data frame with columns `variable`, `level`, `target` (Format B). See
  `calibrate_rake()` for format specification; identical rules apply here.

- **`weights`** — `<tidy-select>` Weight column name (bare name). `NULL` means
  auto-detected: from `weighted_df` attribute, from `@variables$weights` for
  survey objects, or uniform starting weights (all 1) for plain `data.frame`.
  When plain `data.frame` + `weights = NULL`, `surveywts_warning_srs_no_weights`
  is emitted to signal the SRS assumption.

- **`wt_name`** — Character scalar. Name of the output weight column. Default
  `"wts"`. Ignored for survey objects (weight column name is controlled by the
  object). Must be a non-empty, non-NA character scalar; otherwise
  `surveywts_error_wt_name_not_scalar` or `surveywts_error_wt_name_empty`.

- **`bounds`** — `NULL` (default) or a length-2 numeric vector `c(L, U)`.
  - `NULL`: plain unbounded linear calibration. G-weights are unconstrained.
  - `c(L, U)`: truncated-linear calibration. Interpretation depends on
    `bounds_scale` (see below). Triggers
    `surveywts_error_bounds_invalid_calibration` on invalid values.

- **`bounds_scale`** — Character scalar. `"multiplicative"` (default): `bounds`
  constrain the g-weight ratio $g_k = w_k / d_k$. For example, with
  `bounds = c(0.3, 3)` and `bounds_scale = "multiplicative"`, a unit with
  design weight $d_k = 100$ has calibrated weight in $[30, 300]$. Requires
  `L < 1 < U` (both finite). `"absolute"`: `bounds` constrain the final
  calibrated weight $w_k$ directly, so `bounds = c(100, 1000)` means
  $w_k \in [100, 1000]$ regardless of design weight. Requires `0 < L < U`
  (both positive, finite). Matched with `rlang::arg_match()`. Ignored when
  `bounds = NULL`.

- **`unit_scale`** — `NULL` (default) or a positive numeric vector of length
  `nrow(data)`. Per-unit scaling factors $q_k$ for the calibration distance
  function (Deville & Sarndal 1992 eq. 2.2). Higher values allow that unit to
  absorb larger weight adjustments at lower penalty. `NULL` is equivalent to
  `rep(1, nrow(data))` (standard GREG). Triggers
  `surveywts_error_unit_scale_invalid` if not `NULL` and: not numeric, wrong
  length, contains `NA`, or contains non-positive values.

- **`type`** — Character scalar. `"prop"` (default): `targets` values are
  proportions summing to 1.0 per variable (within 1e-6 tolerance). `"count"`:
  `targets` values are population counts (all strictly positive). Matched with
  `rlang::arg_match()`.

- **`control`** — Named list of convergence parameters. Merged with defaults
  `list(maxit = 50, epsilon = 1e-7)`. Unrecognized keys trigger
  `surveywts_warning_control_param_ignored` per key. Valid keys: `maxit`,
  `epsilon`. Note: `maxit` and `epsilon` are only active when `bounds` is
  non-`NULL` (truncated-linear requires iteration); for plain linear (`bounds =
  NULL`), they are stored in the history entry but do not affect computation.

- **`reference_design`** — A `survey_taylor` object or `NULL`. When non-`NULL`,
  the `targets` were estimated from this probability survey. Stored in the
  history entry with `targets_from_reference = TRUE`. Any non-`NULL`
  non-`survey_taylor` value triggers
  `surveywts_error_reference_design_not_taylor`.

#### Returns

- `data.frame` or `weighted_df` input → `weighted_df` with the calibrated
  weight column named by `wt_name` and a history entry appended.
- `survey_taylor` input → `survey_taylor` (class preserved); only
  `@variables$weights` (the weight column) and `@calibration` are modified.
  `@variables$ids`, `@variables$strata`, `@variables$fpc`, and the Taylor
  design structure are unchanged.
- `survey_nonprob` input → `survey_nonprob` (class preserved); weight
  column updated; history entry appended; `@calibration` slot populated.
- `survey_replicate` input → `survey_replicate` (class preserved); full-sample
  weight column updated; each replicate weight column calibrated independently
  using the same `targets`. For `type = "count"` targets, each replicate's
  population totals are scaled to that replicate's effective population before
  calibration: `rep_targets = targets * (sum(rep_wt) / sum(base_wt))`. For
  `type = "prop"` targets, targets are scale-invariant and used unchanged.
  Failed replicates are kept at original values and reported via
  `surveywts_warning_replicate_calibration_failed`. `@calibration` slot
  populated including `replicate_converged`.

History entry `operation` field: `"calibrate_linear"`.

`@calibration` slot fields (survey objects only): `x_matrix`, `base_weights`,
`g_weights`, `crossproduct_inv`, `population_totals`, `discrepancy`, `lambda`
(converged $\boldsymbol{\lambda}$ vector), `method = "linear"` or
`"truncated"`, `cell_factors = NULL`, `q_weights` (the `unit_scale` vector
used, or `NULL` when `unit_scale = NULL`), `bounds_scale` (the resolved
`bounds_scale` value, or `NULL` when `bounds = NULL`), `converged`,
`n_iterations`.

#### Errors

| Class | Trigger condition |
|-------|-------------------|
| `surveywts_error_unsupported_class` | `data` is not a supported class |
| `surveywts_error_empty_data` | `nrow(data) == 0` |
| `surveywts_error_wt_name_not_scalar` | `wt_name` is not `character(1)` |
| `surveywts_error_wt_name_empty` | `wt_name` is `NA` or `""` |
| `surveywts_error_reference_design_not_taylor` | `reference_design` is non-`NULL` and not `survey_taylor` |
| `surveywts_error_weights_not_found` | Named weight column missing from `data` |
| `surveywts_error_weights_not_numeric` | Weight column is not numeric |
| `surveywts_error_weights_nonpositive` | Weight column has values ≤ 0 |
| `surveywts_error_weights_na` | Weight column has `NA` |
| `surveywts_error_targets_variable_not_found` | A `targets` name not found in `data` |
| `surveywts_error_variable_not_categorical` | Calibration variable is not character or factor |
| `surveywts_error_variable_has_na` | A calibration variable has `NA` values |
| `surveywts_error_population_level_missing` | A data level absent from `targets` |
| `surveywts_error_population_level_extra` | A `targets` level absent from `data` |
| `surveywts_error_population_totals_invalid` | `type = "prop"` proportions don't sum to 1, or `type = "count"` target ≤ 0 |
| `surveywts_error_margins_format_invalid` | `targets` is not a named list or valid long data frame |
| `surveywts_error_bounds_invalid_calibration` | `bounds` is non-`NULL` but invalid: not length-2 numeric; for `bounds_scale = "multiplicative"`, `L >= 1` or `U <= 1`; for `bounds_scale = "absolute"`, `L <= 0` or `L >= U`; or either value is `NA` or non-finite |
| `surveywts_error_unit_scale_invalid` | `unit_scale` is not `NULL` and is: not numeric, length ≠ `nrow(data)`, contains `NA`, or contains non-positive values |
| `surveywts_error_calibration_not_converged` | Max iterations reached without convergence (truncated-linear only) |
| `surveywts_error_calibration_singular_system` | `solve()` failed — `T_x` is singular (collinear or rank-deficient calibration variables) |

#### Warnings

| Class | Trigger condition |
|-------|-------------------|
| `surveywts_warning_srs_no_weights` | `data` is a plain `data.frame` and `weights = NULL` — SRS assumption applied |
| `surveywts_warning_negative_calibrated_weights` | Plain linear (`bounds = NULL`) produced one or more negative calibrated weights |
| `surveywts_warning_control_param_ignored` | An unrecognized key in `control` |
| `surveywts_warning_replicate_calibration_failed` | Calibration failed for a specific replicate weight column |

#### Edge cases

- **Empty data (`nrow(data) == 0`):** Error `surveywts_error_empty_data` before
  any computation.
- **Single-row data:** No special handling; proceeds normally. Linear is
  solvable as long as `T_x` is invertible, which may fail if the single row
  creates a degenerate system.
- **All weights equal (already calibrated):** Linear calibration converges
  trivially in one step and returns weights unchanged (no warning needed).
- **Single-level calibration variable:** The model matrix has no dummy column
  for that variable (only the intercept absorbs it). Calibration proceeds
  normally; the weight adjustment is uniform across that variable's level.
- **Zero-weight rows:** Prevented by `surveywts_error_weights_nonpositive`
  before computation.
- **`bounds = c(L, U)` with invalid values:** Error
  `surveywts_error_bounds_invalid_calibration`. For
  `bounds_scale = "multiplicative"`, must have `L < 1 < U`. For
  `bounds_scale = "absolute"`, must have `0 < L < U`.
- **`bounds = c(L, U)` with infeasible constraints (too tight):** Newton-
  Raphson diverges; error `surveywts_error_calibration_not_converged`. This
  occurs when the specified range is tighter than data allows.
- **Singular `T_x` matrix:** `solve()` failure is caught and re-raised as
  `surveywts_error_calibration_singular_system`. This occurs with perfectly
  collinear variables or single-level variables that should have been excluded
  from the model. Distinct from `surveywts_error_calibration_not_converged`
  (NR iteration exhaustion) — singular system indicates collinearity, not
  bounds infeasibility.
- **`type = "count"` with inconsistent marginal sums:** Error
  `surveywts_error_population_totals_invalid`.

---

### `calibrate_logit(data, targets, weights, wt_name, bounds, bounds_scale, unit_scale, type, control, reference_design)`

#### Signature

```r
calibrate_logit(
  data,
  targets,
  weights          = NULL,
  wt_name          = "wts",
  bounds           = c(1e-6, 1e6),
  bounds_scale     = c("multiplicative", "absolute"),
  unit_scale       = NULL,
  type             = c("prop", "count"),
  control          = list(),
  reference_design = NULL
)
```

#### Purpose

Logit-bounded calibration. Uses the logit $F$-function that keeps g-weights
in the open interval $(L, U)$, where `bounds = c(L, U)` defaults to
`c(1e-6, 1e6)` matching `survey::calibrate(calfun = "logit")`.

This function replaces `calibrate_greg(model = "logit")`.

#### @details

**Logit calibration**

With $A = (U - L) / [(1-L)(U-1)]$, the logit $F$-function is:

$$F(u) = \frac{L(U-1) + U(1-L)\exp(Au)}{U - 1 + (1-L)\exp(Au)}, \qquad F(u) \in (L, U)$$

The g-weight $w_k / d_k$ is bounded in the open interval $(L, U)$. It never
reaches $L$ or $U$ — contrast with truncated-linear, where the bounds are
achievable. Newton-Raphson iteration is required; convergence is assessed via
`control$epsilon` and capped at `control$maxit` iterations. The converged
$\boldsymbol{\lambda}$ from the NR engine is stored in `@calibration$lambda`;
it is the iteratively refined solution, **not** the linear one-step
approximation $\mathbf{T}_x^{-1}(\mathbf{t}_x - \hat{\mathbf{t}}_{x\pi})$.

The default logit bounds are $L = 10^{-6}$, $U = 10^{6}$
(`bounds = c(1e-6, 1e6)`). With these values, the scaling constant is
$A = (U - L) / [(1-L)(U-1)] \approx 1 + 10^{-6}$ (approximately 1 for all
practical purposes). These defaults match `survey::calibrate(calfun = "logit")`
and provide a very wide but finite open interval ensuring positive weights.
Default convergence parameters `maxit = 50` and `epsilon = 1e-7` match
`survey::calibrate()` defaults; they are engineering choices, not values
derived from the Deville-Sarndal papers. Users who need custom bounds (e.g.,
soft bounded raking with `bounds = c(0.3, 3)`) can pass any `c(L, U)` with
`L < 1 < U`. For hard closed-interval bounds, use
`calibrate_linear(bounds = c(L, U))` instead.

**Pitfalls:** When the required calibration adjustment is large, Newton-Raphson
can converge slowly or fail to converge if the logit bounds are effectively
binding. Even with the wide default bounds, infeasible population targets can
cause non-convergence. When convergence fails, error
`surveywts_error_calibration_not_converged` is thrown.

**When to use logit over other methods:** Use logit when (a) negative weights
are unacceptable, (b) you want soft bounds on the g-weight ratio (weights
approach but never reach the boundary), and (c) you have a single joint
calibration problem (not marginal targets per variable). Use `calibrate_rake()`
when you have separate marginal targets for multiple variables.

#### Arguments

All arguments are identical in semantics to `calibrate_linear()` except:

- **`bounds`** — Length-2 numeric vector `c(L, U)`. Default `c(1e-6, 1e6)`.
  Interpretation depends on `bounds_scale`. Unlike
  `calibrate_linear(bounds = ...)` (truncated-linear, closed interval), logit
  bounds are a soft open interval — the g-weight asymptotically approaches but
  never exactly reaches $L$ or $U$. Triggers
  `surveywts_error_bounds_invalid_calibration` on invalid values (see
  `calibrate_linear()` for validation rules by `bounds_scale`).

- **`bounds_scale`** — Same semantics as `calibrate_linear()`. Default
  `"multiplicative"`: bounds constrain the g-weight ratio $g_k = w_k / d_k$
  in the open interval $(L, U)$. `"absolute"`: bounds constrain $w_k$ directly.
  For `"multiplicative"`, requires `L < 1 < U`. For `"absolute"`, requires
  `0 < L < U`.

- **`unit_scale`** — Same semantics as `calibrate_linear()`. Per-unit $q_k$
  scaling factors for the logit distance function. `NULL` (default) sets
  $q_k = 1$ for all units.

- **`control`** — Named list of convergence parameters. Merged with defaults
  `list(maxit = 50, epsilon = 1e-7)`. Unrecognized keys trigger
  `surveywts_warning_control_param_ignored`. Valid keys: `maxit`, `epsilon`.

All other arguments (`data`, `targets`, `weights`, `wt_name`, `type`,
`reference_design`) have identical semantics to `calibrate_linear()`, including
the `surveywts_warning_srs_no_weights` behavior for plain `data.frame` +
`weights = NULL`. Refer to that function's documentation for full details.

#### Returns

Same structure as `calibrate_linear()`, with the same `survey_taylor`
preservation guarantee (only `@variables$weights` and `@calibration` modified)
and the same `survey_replicate` population-total scaling rule for `type = "count"`
(see `calibrate_linear()` Returns for details).

History entry `operation` field: `"calibrate_logit"`.

`@calibration` slot fields: identical to `calibrate_linear()` except
`method = "logit"`. The `lambda` field contains the **converged NR**
$\boldsymbol{\lambda}$ vector — the NR engine must return the final iterated
$\boldsymbol{\lambda}$, not a post-hoc linear approximation.

#### Errors

| Class | Trigger condition |
|-------|-------------------|
| `surveywts_error_unsupported_class` | `data` is not a supported class |
| `surveywts_error_empty_data` | `nrow(data) == 0` |
| `surveywts_error_wt_name_not_scalar` | `wt_name` is not `character(1)` |
| `surveywts_error_wt_name_empty` | `wt_name` is `NA` or `""` |
| `surveywts_error_reference_design_not_taylor` | `reference_design` is non-`NULL` and not `survey_taylor` |
| `surveywts_error_weights_not_found` | Named weight column missing from `data` |
| `surveywts_error_weights_not_numeric` | Weight column is not numeric |
| `surveywts_error_weights_nonpositive` | Weight column has values ≤ 0 |
| `surveywts_error_weights_na` | Weight column has `NA` |
| `surveywts_error_targets_variable_not_found` | A `targets` name not found in `data` |
| `surveywts_error_variable_not_categorical` | Calibration variable is not character or factor |
| `surveywts_error_variable_has_na` | A calibration variable has `NA` values |
| `surveywts_error_population_level_missing` | A data level absent from `targets` |
| `surveywts_error_population_level_extra` | A `targets` level absent from `data` |
| `surveywts_error_population_totals_invalid` | `type = "prop"` proportions don't sum to 1, or `type = "count"` target ≤ 0 |
| `surveywts_error_margins_format_invalid` | `targets` is not a named list or valid long data frame |
| `surveywts_error_bounds_invalid_calibration` | `bounds` is invalid: not length-2 numeric; for `bounds_scale = "multiplicative"`, `L >= 1` or `U <= 1`; for `bounds_scale = "absolute"`, `L <= 0` or `L >= U`; or either value is `NA` or non-finite |
| `surveywts_error_unit_scale_invalid` | `unit_scale` is not `NULL` and is: not numeric, length ≠ `nrow(data)`, contains `NA`, or contains non-positive values |
| `surveywts_error_calibration_not_converged` | Max iterations reached without convergence |
| `surveywts_error_calibration_singular_system` | `solve()` failed — logit Jacobian is singular |

#### Warnings

| Class | Trigger condition |
|-------|-------------------|
| `surveywts_warning_srs_no_weights` | `data` is a plain `data.frame` and `weights = NULL` — SRS assumption applied |
| `surveywts_warning_control_param_ignored` | An unrecognized key in `control` |
| `surveywts_warning_replicate_calibration_failed` | Calibration failed for a specific replicate weight column |

#### Edge cases

All edge cases from `calibrate_linear()` apply, except:

- **Negative calibrated weights:** Impossible; g-weights are bounded in the
  open interval $(L, U)$ where defaults are $(10^{-6}, 10^{6})$.
- **`bounds = c(L, U)` with invalid values:** Error
  `surveywts_error_bounds_invalid_calibration`. For
  `bounds_scale = "multiplicative"`, must have `L < 1 < U`. For
  `bounds_scale = "absolute"`, must have `0 < L < U`.
- **Infeasible population targets:** If the required adjustment pushes g-weights
  against the bounds, Newton-Raphson fails with
  `surveywts_error_calibration_not_converged`.

---

### `calibrate_rake(data, targets, weights, wt_name, type, algorithm, cap, control, reference_design)`

#### Signature

```r
calibrate_rake(
  data,
  targets,
  weights          = NULL,
  wt_name          = "wts",
  type             = c("prop", "count"),
  algorithm        = c("classic_ipf", "nr"),
  cap              = NULL,
  control          = list(),
  reference_design = NULL
)
```

#### Purpose

Iterative proportional fitting (raking) to marginal population totals. Supports
two algorithms:

- **`"classic_ipf"`** — Chi-square variable selection with improvement-based
  convergence (formerly `"anesrake"`). Internal IPF engine ported from the
  `anesrake` package. Per-step weight capping via `cap`.
- **`"nr"`** — Newton-Raphson raking using the multiplicative $F(u) = \exp(u)$
  from Deville, Sarndal & Sautory (1993) §11. Matches
  `survey::calibrate(calfun = "raking")`. `cap` is not supported with this
  algorithm. For bounded raking (constrained g-weight ratios), use
  `calibrate_linear(bounds = ...)` for hard closed-interval bounds or
  `calibrate_logit(bounds = ...)` for soft open-interval bounds.

The old `algorithm = "survey"` (fixed-order IPF via `survey::rake()`) is
removed. The old `algorithm = "anesrake"` is renamed `"classic_ipf"`.

#### @details

**Classic IPF (`algorithm = "classic_ipf"`)**

At each sweep, variables are sorted by their chi-square discrepancy. Variables
with any cell below `control$min_cell_n` unweighted observations are excluded.
Variables where the chi-square p-value exceeds `control$pval` are skipped in
that sweep. Convergence is assessed as the percentage improvement in total
chi-square between consecutive sweeps. If all variables are excluded by
`min_cell_n` in sweep 1, the behavior is identical to the already-calibrated
path: `surveywts_message_already_calibrated` is emitted and weights are
returned unchanged.

The `cap` argument applies within each step of the IPF loop. Any weight
exceeding `cap * mean(w)` is set to `cap * mean(w)` after each per-margin
adjustment. This is a post-raking trim at each step, not a one-time post-hoc
cap. `cap = NULL` (default) means no cap.

**Newton-Raphson raking (`algorithm = "nr"`)**

Uses the multiplicative $F$-function $F(u) = \exp(u)$ and solves the marginal
calibration constraints via Newton-Raphson. The NR update rule is:

$$\boldsymbol{\lambda}_{\nu+1} = \boldsymbol{\lambda}_\nu + [\phi'(\boldsymbol{\lambda}_\nu)]^{-1} \bigl[\mathbf{t}_x - \hat{\mathbf{t}}_{x\pi} - \phi(\boldsymbol{\lambda}_\nu)\bigr]$$

where $\hat{\mathbf{t}}_{x\pi} = \sum_{k \in s} d_k \mathbf{x}_k$
(Horvitz-Thompson estimate of $\mathbf{t}_x$) and
$\phi(\boldsymbol{\lambda}) = \sum_{k \in s} d_k \{F(\mathbf{x}_k'\boldsymbol{\lambda}) - 1\} \mathbf{x}_k$.

**Convergence criterion:** convergence is declared when
$\max_j |\sum_{k \in s} w_k x_{kj} - t_{x,j}| < \varepsilon$ for all $j$
— the maximum absolute discrepancy between weighted sample totals and
population targets in count scale. For `type = "prop"` targets, comparisons
are on the proportion scale after multiplying both sides by $\sum_{k \in s} d_k$.
This matches `survey::calibrate()` epsilon semantics. Default values
`maxit = 50` and `epsilon = 1e-7` match `survey::calibrate()` defaults and are
engineering choices, not values from the Deville-Sarndal papers.

**Model matrix for multi-variable raking:** For a single variable with $c$
levels, the model matrix has $c - 1$ dummy columns (one level dropped as
reference). For two-variable raking on an $r \times c$ table, the system has
$r + c - 1$ free parameters: $u_1, \ldots, u_r$ and $v_1, \ldots, v_{c-1}$
with $v_c$ fixed at 0 (one equation in the $r + c$ system is algebraically
redundant — Deville et al. 1993 §6). The NR Jacobian is
$(r + c - 1) \times (r + c - 1)$.

The converged $\boldsymbol{\lambda}$ is stored in `@calibration$lambda`. For
two-way marginal tables, the NR system reduces to classical IPF in the limit
(asymptotically equivalent). For a single sweep the NR path differs from IPF
because it solves all margins simultaneously rather than cycling.

**Pitfalls (raking in general):**
- Multiplicative raking guarantees positive weights but g-weights are unbounded
  above. Large sample-population discrepancies produce very high g-weight
  ratios (Deville et al. 1993 §12: "usually greater, sometimes substantially
  greater" than the linear method).
- Non-convergence occurs when (a) `control$maxit` is too small, or (b) population
  targets are inconsistent across margins.
- For `classic_ipf`, the one-equation redundancy in a two-way table (Deville
  et al. 1993 §6) is handled internally by the IPF cycle structure.

**Marginal raking and interaction bias:** Raking is well-suited when you have
separate marginal targets for multiple categorical variables and the targets are
defined independently per variable (not as joint cell counts). Marginal raking
minimizes distance to independent marginal targets; it does not constrain the
joint distribution. When the study variable has strong interactions across the
raking dimensions, marginal raking estimates can be conditionally biased
relative to full post-stratification (Deville et al. 1993 §8.1). Use
`poststratify()` when joint cell counts are available.

#### Arguments

- **`data`** — Same semantics as `calibrate_linear()`.

- **`targets`** — Same Format A / Format B rules as `calibrate_linear()`.

- **`weights`**, **`wt_name`**, **`type`**, **`reference_design`** — Same
  semantics as `calibrate_linear()`.

- **`algorithm`** — Character scalar. `"classic_ipf"` (default): chi-square
  variable selection IPF. `"nr"`: Newton-Raphson using $F(u) = \exp(u)$.
  Matched with `rlang::arg_match()`.

- **`cap`** — Numeric or `NULL` (default). Per-step weight cap applied to
  `algorithm = "classic_ipf"` only. Any weight exceeding `cap * mean(w)` at
  each step is capped. Must be a positive finite numeric scalar or `NULL`.
  Non-positive (`cap ≤ 0`), non-finite, or non-numeric values trigger
  `surveywts_error_cap_not_positive`. Must be `NULL` when `algorithm = "nr"`
  (triggers `surveywts_error_cap_not_supported_nr`).

- **`control`** — Named list of algorithm parameters. Merged with
  algorithm-specific defaults. Unrecognized or wrong-algorithm keys trigger
  `surveywts_warning_control_param_ignored`.

  **`algorithm = "classic_ipf"` defaults:**
  - `maxit = 1000L`: maximum full sweeps
  - `improvement = 0.01`: percentage improvement convergence threshold
  - `pval = 0.05`: chi-square p-value threshold for variable selection
  - `min_cell_n = 0L`: minimum unweighted observations per cell
  - `variable_select = "total"`: chi-square aggregation method for ranking
    variables in each sweep. `"total"` — sum of chi-square contributions
    across all cells of that variable; `"max"` — maximum single-cell
    chi-square for that variable; `"average"` — mean chi-square across all
    cells of that variable. Valid values: `"total"`, `"max"`, `"average"`.

  **`algorithm = "nr"` defaults:**
  - `maxit = 50L`: maximum Newton-Raphson iterations
  - `epsilon = 1e-7`: convergence tolerance (max absolute deviation from
    target totals)

#### Returns

Same structure as `calibrate_linear()`, with the same `survey_taylor`
preservation guarantee (only `@variables$weights` and `@calibration` modified)
and the same `survey_replicate` population-total scaling rule for `type = "count"`.
The `data` argument description for `calibrate_linear()` applies here as well,
including the `surveywts_warning_srs_no_weights` behavior.

History entry `operation` field: `"calibrate_rake"` (unchanged from current).

`@calibration` slot fields: All fields from `calibrate_linear()` apply with the
following values for rake-specific fields: `q_weights = NULL` (no `unit_scale`
argument), `bounds_scale = NULL` (no `bounds` argument), `cell_factors = NULL`
(not post-stratification). For `algorithm = "classic_ipf"`, `lambda = NULL`
and `crossproduct_inv = NULL` (no NR Jacobian). For `algorithm = "nr"`,
`lambda` is the converged NR $\boldsymbol{\lambda}$ vector and
`crossproduct_inv` is the NR Jacobian inverse at convergence (or `NULL` if not
stored by the engine). `method = "raking"` for both algorithms. `converged`
and `n_iterations` are populated for `algorithm = "nr"` (NR path); for
`algorithm = "classic_ipf"`, `converged` reflects IPF convergence and
`n_iterations` counts full sweeps.

#### Errors

| Class | Trigger condition |
|-------|-------------------|
| `surveywts_error_unsupported_class` | `data` is not a supported class |
| `surveywts_error_empty_data` | `nrow(data) == 0` |
| `surveywts_error_wt_name_not_scalar` | `wt_name` is not `character(1)` |
| `surveywts_error_wt_name_empty` | `wt_name` is `NA` or `""` |
| `surveywts_error_reference_design_not_taylor` | `reference_design` is non-`NULL` and not `survey_taylor` |
| `surveywts_error_weights_not_found` | Named weight column missing from `data` |
| `surveywts_error_weights_not_numeric` | Weight column is not numeric |
| `surveywts_error_weights_nonpositive` | Weight column has values ≤ 0 |
| `surveywts_error_weights_na` | Weight column has `NA` |
| `surveywts_error_targets_variable_not_found` | A `targets` name not found in `data` |
| `surveywts_error_variable_not_categorical` | Raking variable is not character or factor |
| `surveywts_error_variable_has_na` | A raking variable has `NA` values |
| `surveywts_error_population_level_missing` | A data level absent from `targets` |
| `surveywts_error_population_level_extra` | A `targets` level absent from `data` |
| `surveywts_error_population_totals_invalid` | `type = "prop"` proportions don't sum to 1, or `type = "count"` target ≤ 0 |
| `surveywts_error_margins_format_invalid` | `targets` is not a named list or valid long data frame |
| `surveywts_error_cap_not_positive` | `cap` is non-`NULL` and is non-positive, non-finite, or non-numeric |
| `surveywts_error_cap_not_supported_nr` | `cap` non-`NULL` with `algorithm = "nr"` |
| `surveywts_error_calibration_not_converged` | Max iterations reached without convergence |
| `surveywts_error_calibration_singular_system` | NR Jacobian is singular (collinear raking variables or rank-deficient model matrix) |

#### Warnings

| Class | Trigger condition |
|-------|-------------------|
| `surveywts_warning_srs_no_weights` | `data` is a plain `data.frame` and `weights = NULL` — SRS assumption applied |
| `surveywts_warning_control_param_ignored` | Wrong-algorithm or unrecognized key in `control` |
| `surveywts_warning_replicate_calibration_failed` | Calibration failed for a specific replicate weight column |

#### Messages

| Class | Trigger condition |
|-------|-------------------|
| `surveywts_message_already_calibrated` | `algorithm = "classic_ipf"` and all variables pass chi-square threshold in sweep 1 |

#### Edge cases

- **`cap` with `algorithm = "nr"`:** Error `surveywts_error_cap_not_supported_nr`
  before any computation.
- **All variables already at target (classic_ipf):** Message
  `surveywts_message_already_calibrated`; weights returned unchanged.
- **Singular NR Jacobian:** Error `surveywts_error_calibration_singular_system`
  (collinear raking variables).
- All remaining edge cases (empty data, single-row, zero weights, single-level
  variable) are handled identically to `calibrate_linear()`.

---

### `calibrate(data, targets, weights, wt_name, type, reference_design, ..., method)`

#### Signature

```r
calibrate(
  data,
  targets,
  weights          = NULL,
  wt_name          = "wts",
  type             = c("prop", "count"),
  reference_design = NULL,
  ...,
  method           = c("rake", "linear", "logit")
)
```

#### Purpose

Thin dispatcher to `calibrate_rake()`, `calibrate_linear()`, or
`calibrate_logit()` based on `method`. All arguments (including `...`) are
forwarded to the dispatched function. No validation or calibration logic lives
in this function — all errors propagate from the dispatched function.

Calibration is a form of "incomplete poststratification" (Deville & Sarndal
1992): it adjusts weights to match marginal auxiliary totals while minimizing a
unit-level distance from the design weights. Unlike `poststratify()`, which
matches joint cell counts exactly, `calibrate()` matches marginal totals.

#### @details

**When to use each method:**

- `method = "rake"` (default): Raking / iterative proportional fitting.
  Well-suited for multiple independent marginal targets. Always produces
  positive weights. Use when you have separate age, sex, region targets to
  match simultaneously.

- `method = "linear"`: GREG / linear calibration. Simplest and fastest.
  One-step exact solution. May produce negative weights when
  sample-population discrepancies are large. Use when speed matters and
  negative weights are acceptable or rare.

- `method = "logit"`: Logit-bounded calibration. Always positive, with soft
  bounds on g-weights. Use when negative weights are unacceptable and you need
  a single joint calibration (not marginal targets).

See `poststratify()` for "complete poststratification" that matches exact joint
cell counts rather than marginal totals.

#### Arguments

- **`method`** — Character scalar. `"rake"` (default), `"linear"`, or
  `"logit"`. Matched with `rlang::arg_match()`. Placed at the end of the
  signature so that `...` can forward all method-specific arguments
  (e.g., `algorithm`, `cap` for `calibrate_rake()`; `bounds`, `bounds_scale`,
  `unit_scale` for `calibrate_linear()` and `calibrate_logit()`) to the
  dispatched function.

- All other arguments are forwarded unchanged to the dispatched function.
  See `calibrate_rake()`, `calibrate_linear()`, or `calibrate_logit()` for
  full argument documentation.

#### Returns

Whatever the dispatched function returns. Class, attributes, and history entry
are determined by the dispatched function.

#### Errors

All errors propagate from the dispatched function. `calibrate()` itself throws
no typed errors beyond `rlang::arg_match()` failure for unknown `method`.

#### Edge cases

All edge cases are handled by the dispatched function.

---

### `poststratify(data, targets, weights, wt_name, type, reference_design)`

#### Signature

```r
poststratify(
  data,
  targets,
  weights          = NULL,
  wt_name          = "wts",
  type             = c("prop", "count"),
  reference_design = NULL
)
```

#### Purpose

Complete post-stratification to known joint population cell counts. Adjusts
weights so that the weighted cell counts (or proportions) match the population
exactly for every joint combination of stratification variables. Unlike
`calibrate()`, which matches marginal totals for independent calibration
variables, `poststratify()` matches exact cross-tabulation cells in a single
pass.

This function replaces `calibrate_poststrat()` with an updated name and
documentation. The numerical behavior is identical.

#### @details

**Complete vs. incomplete poststratification**

Poststratification is the limiting case of calibration where auxiliary
information is provided as exact joint cell counts rather than independent
marginal totals. It is "complete" in the sense that every unit is assigned to
a unique cell and the cell adjustment is exact:

$$w_k^{(\text{new})} = w_k \cdot \frac{N_h}{\hat{N}_h}$$

where $N_h$ is the known population count for cell $h$ and
$\hat{N}_h = \sum_{k \in h} d_k$ is the Horvitz-Thompson estimate for that
cell. This is a single-pass, non-iterative operation.

When the cross-tabulation is too fine-grained for the sample size (many cells
with few observations each), `calibrate()` with marginal targets is preferable.
Use `poststratify()` when the joint cell distribution is known and the cells
are adequately populated.

**Targets format (required):** `targets` must be a `data.frame` — named lists
are not accepted. It must have one column per stratification variable (names
matching columns in `data`) plus a column named `"target"`. Strata variables
are identified as `setdiff(names(targets), "target")`.

#### Arguments

All arguments are identical in semantics to `calibrate_poststrat()`. The
`targets` argument must be a `data.frame` (not a named list). See
`calibrate_poststrat()` documentation for full format specification — the same
rules apply.

- **`data`**, **`weights`**, **`wt_name`**, **`type`**, **`reference_design`**
  — Same semantics as `calibrate_linear()`.
- **`targets`** — A `data.frame` with strata variable columns plus `"target"`.
  Named lists are rejected with `surveywts_error_margins_format_invalid`.

#### Returns

Same structure as `calibrate_linear()`. For `survey_taylor` inputs, only
`@variables$weights` and `@calibration` are modified; `@variables$ids`,
`@variables$strata`, `@variables$fpc`, and design structure are unchanged.
For `survey_replicate` inputs, each replicate is post-stratified independently
with the same `targets` (no population-total scaling — cell proportions or
counts are used as provided for each replicate).

The `weights` argument applies the `surveywts_warning_srs_no_weights` behavior
for plain `data.frame` + `weights = NULL`.

History entry `operation` field: `"poststratify"` (changed from
`"calibrate_poststrat"`).

`@calibration` slot fields: identical to `calibrate_poststrat()`, including
`cell_factors` (named numeric vector of $N_h / \hat{N}_h$ ratios) and
`method = "poststrat"`.

#### Errors

| Class | Trigger condition |
|-------|-------------------|
| `surveywts_error_unsupported_class` | `data` is not a supported class |
| `surveywts_error_empty_data` | `nrow(data) == 0` |
| `surveywts_error_wt_name_not_scalar` | `wt_name` is not `character(1)` |
| `surveywts_error_wt_name_empty` | `wt_name` is `NA` or `""` |
| `surveywts_error_margins_format_invalid` | `targets` is not a `data.frame` |
| `surveywts_error_no_strata_variables` | `targets` data frame has zero non-`"target"` columns |
| `surveywts_error_targets_variable_not_found` | A strata column in `targets` not found in `data` |
| `surveywts_error_reference_design_not_taylor` | `reference_design` is non-`NULL` and not `survey_taylor` |
| `surveywts_error_weights_not_found` | Named weight column missing from `data` |
| `surveywts_error_weights_not_numeric` | Weight column is not numeric |
| `surveywts_error_weights_nonpositive` | Weight column has values ≤ 0 |
| `surveywts_error_weights_na` | Weight column has `NA` |
| `surveywts_error_variable_has_na` | A strata variable has `NA` values |
| `surveywts_error_population_totals_invalid` | `type = "prop"` targets don't sum to 1, or `type = "count"` target ≤ 0 |
| `surveywts_error_population_cell_duplicate` | A cell combination appears more than once in `targets` |
| `surveywts_error_population_cell_missing` | A data cell has no row in `targets`, or `targets` is missing required columns |
| `surveywts_error_population_cell_not_in_data` | A `targets` cell has no observations in `data` |
| `surveywts_error_empty_stratum` | `sum(replicate_weight_column[cell]) == 0` for any cell in a replicate weight column. The full-sample path cannot trigger this error because design weights are validated strictly positive before reaching cell computation. |

#### Warnings

| Class | Trigger condition |
|-------|-------------------|
| `surveywts_warning_srs_no_weights` | `data` is a plain `data.frame` and `weights = NULL` — SRS assumption applied |
| `surveywts_warning_replicate_calibration_failed` | Calibration failed for a specific replicate weight column |

#### Edge cases

- **`targets` is a named list:** Error `surveywts_error_margins_format_invalid`.
- **`targets` data frame with only a `"target"` column and no strata columns:**
  Error `surveywts_error_no_strata_variables`.
- **A cell in `data` with no matching row in `targets`:** Error
  `surveywts_error_population_cell_missing`.
- **A cell in `targets` with no observations in `data`:** Error
  `surveywts_error_population_cell_not_in_data`.
- **Single-row data:** Proceeds normally if the one row forms a valid cell.
- **Zero starting weights:** Prevented by `surveywts_error_weights_nonpositive`.
- **`type = "prop"` with targets not summing to 1.0 (within 1e-6):** Error
  `surveywts_error_population_totals_invalid`.

---

## Variance estimation

The g-weights stored in `@calibration$g_weights` are intended for downstream
calibration-adjusted variance estimation (Deville & Sarndal 1992 eq. 3.4).
The following interim status applies by output class:

**`survey_taylor` and `survey_nonprob` outputs:** g-weights are stored in
`@calibration$g_weights`. Whether `surveycore` automatically uses them for
Taylor-linearized variance adjustment is deferred to the surveycore phase. In
the interim, SEs computed on these objects use the naive calibrated weights
(design-consistent but not model-nearly-unbiased per Deville & Sarndal 1992
eq. 3.4). This is documented as a known limitation pending surveycore
integration.

**`weighted_df` outputs:** g-weights are not stored. SEs computed via
external tools (e.g., the `survey` package) on `weighted_df` calibrated weights
do not account for calibration in the variance estimator. This is a known
limitation of the `weighted_df` output class.

**`survey_replicate` outputs:** Variance is estimated via replicate reweighting.
Because each replicate is independently calibrated (with scaled population
totals for `type = "count"`), the replicate variance estimator is asymptotically
calibration-adjusted by construction — no separate g-weight adjustment is needed.

---

## Quality gates

The following invariants must hold across all inputs for all calibration
functions in this spec:

1. **Weight positivity after calibration.** For `calibrate_logit()` and
   `calibrate_rake()`, all output weights must be strictly positive. For
   `calibrate_linear()`, output weights may be negative only when
   `bounds = NULL`; `surveywts_warning_negative_calibrated_weights` is emitted
   in that case.

2. **Calibration constraint satisfaction.** For any successful calibration,
   the weighted marginal totals of the calibration variables must match the
   specified `targets` within a reasonable numerical tolerance (not checked at
   runtime, but must hold in tests against oracle).

3. **History preservation.** Each call appends exactly one history entry. The
   entry's `operation` field matches the function name convention. Previous
   history entries are unchanged.

4. **Class preservation.** Input class is preserved in output: `data.frame`
   → `weighted_df`; `survey_taylor` → `survey_taylor`; `survey_nonprob` →
   `survey_nonprob`; `survey_replicate` → `survey_replicate`.

5. **`@calibration` slot contract.** For survey objects, `@calibration` is
   populated with a named list matching the `.build_calibration_provenance()`
   contract. `g_weights = calibrated_weights / base_weights`. For
   `poststratify()`, `cell_factors` is non-`NULL`. For `calibrate_linear()`
   and `calibrate_logit()`, `lambda` is a numeric vector. For
   `calibrate_rake(algorithm = "nr")`, `lambda` is a numeric vector (the
   converged NR solution, not a post-hoc linear approximation).
   For `calibrate_rake(algorithm = "classic_ipf")`, `lambda = NULL`.

6. **Weight conservation.** After calibration with `type = "count"` targets
   using $J$ marginal variables, the sum of calibrated weights equals the
   shared population total $N = \sum_h t_{x,h}$ (which must equal the common
   total implied by all margins). After calibration with `type = "prop"`
   targets, the sum of calibrated weights equals the sum of design weights
   (since proportion-based calibration scales to 1.0).

7. **Single-step for linear calibration.** For `calibrate_linear(bounds = NULL)`,
   the engine completes in exactly one Newton step. This is stored in
   `@calibration$n_iterations` and must equal `1L` for any plain-linear
   calibration. Tests should assert `expect_equal(obj@calibration$n_iterations, 1L)`.

---

## Pipeline split

**recommended** — Five new or modified exported functions, algorithm changes,
new error classes, and deletion of two existing exports. Concurrent development
across 5 PRs is recommended to allow independent testing of each function.

---

## @references (roxygen format for each exported function)

All functions in this spec carry these references:

```
@references
- Deville, J.-C. and Sarndal, C.-E. (1992). Calibration estimators in
  survey sampling. *Journal of the American Statistical Association*,
  87(418), 376–382. http://links.jstor.org/sici?sici=0162-1459%28199206%2987%3A418%3C376%3ACEISS%3E2.0.CO%3B2-3
- Deville, J.-C., Sarndal, C.-E. and Sautory, O. (1993). Generalized raking
  procedures in survey sampling. *Journal of the American Statistical
  Association*, 88(423), 1013–1020. https://www.jstor.org/stable/2290793
```
