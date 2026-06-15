# Spec — calibrate-unit-scale

**Status**: SPEC_READY
**Review**: PASS (Pass 2r — 2026-06-09)
**Target version**: 0.1.0.9000
**PR range**: PR 1 (single PR)

---

## Scope

### In

- Add `q_weights` parameter to `.calibrate_nr_engine()` with default
  `rep(1, nrow)` behavior. Update all three uses of `u_vec`, the Jacobian,
  and the step-halving guard inside the engine to incorporate `q_weights`.
- Wire `q_for_engine` through to every `.calibrate_nr_engine()` call site in
  `calibrate_linear()` (three call sites: bounded-absolute, bounded-
  multiplicative, unbounded) and `calibrate_logit()` (two call sites:
  absolute, multiplicative).
- Wire `q_for_engine` through to every `.calibrate_nr_engine()` call in both
  functions' replicate loops.
- Fix absolute bounds per-unit scaling (D6): replace the `mean(d_k)` scale
  approximation with per-unit `L_k = L_abs / d_k`, `U_k = U_abs / d_k`,
  passed as length-n vectors to `.make_calfun_linear()` / `.make_calfun_logit()`.
  Engine receives original `weights_vec` and `population_totals_vec` (no
  scaled copies). Same fix applied in replicate loops using `rep_wt` directly.
- No new exported functions. No new public arguments. No changes to validated
  argument signatures. No changes to any other function or file.

### Out

- Pre-scaling robustness (D7): `grake()` pre-scales when the population-to-
  sample ratio exceeds 20. Our engine does not. Documented, not added.
- `MASS::ginv()` fallback (D5): `grake()` uses pseudoinverse; our engine uses
  `solve()` and surfaces `surveywts_error_calibration_singular_system`. This
  design choice is retained.
- Any change to `calibrate_rake()`, `poststratify()`, or any other function.
- Any change to validated public argument signatures (`calibrate_linear()`
  and `calibrate_logit()` signatures are unchanged).

---

## Architecture

**Files modified (write surface):**

- `R/calibrate-utils.R` — `.calibrate_nr_engine()`: add `q_weights` parameter;
  update `u_vec`, Jacobian, and step-halving guard.

  Also extend `.make_calfun_linear()` and `.make_calfun_logit()` to accept
  length-n vector `L` and `U` (per-unit bounds):

  - **`.make_calfun_linear()`**: body unchanged — `pmax(lo, pmin(hi, u))` with
    `lo = L - 1`, `hi = U - 1` vectorizes correctly for scalar or vector L/U.

  - **`.make_calfun_logit()` requires a body fix.** The `large_pos` and `normal`
    branches subset `u` to compute the exponential, but do not subset `L`, `U`,
    or `A`. When `L` and `U` are length-n vectors, `L * (U - 1)` has length n
    while `ena` has length `sum(large_pos)` — a dimension mismatch causing silent
    wrong output. Fix: subset `L` and `U` within each branch using a
    scalar-compat guard `L_sub <- if (length(L) > 1L) L[idx] else L`:

    ```r
    .eval_f <- function(u) {
      au <- A * u
      f <- numeric(length(u))

      large_pos <- au > 500
      if (any(large_pos)) {
        ena   <- exp(-au[large_pos])
        L_sub <- if (length(L) > 1L) L[large_pos] else L
        U_sub <- if (length(U) > 1L) U[large_pos] else U
        f[large_pos] <- (L_sub * (U_sub - 1) * ena + U_sub * (1 - L_sub)) /
          ((U_sub - 1) * ena + (1 - L_sub))
      }

      normal <- !large_pos
      if (any(normal)) {
        ea    <- exp(au[normal])
        L_sub <- if (length(L) > 1L) L[normal] else L
        U_sub <- if (length(U) > 1L) U[normal] else U
        f[normal] <- (L_sub * (U_sub - 1) + U_sub * (1 - L_sub) * ea) /
          (U_sub - 1 + (1 - L_sub) * ea)
      }

      pmax(L, pmin(U, f))
    }
    ```

    `dF` is unaffected — `A * (f - L) * (U - f) / (U - L)` is element-wise.

- `R/calibrate_linear.R` — wire `q_for_engine` to all three engine call sites
  (full-sample and replicate loop). Replace absolute-bounds scaled-weights
  approach with per-unit vector-bounds approach (D6 fix).
- `R/calibrate_logit.R` — wire `q_for_engine` to all two engine call sites
  (full-sample and replicate loop). Replace absolute-bounds scaled-weights
  approach with per-unit vector-bounds approach (D6 fix). **Also add a
  pre-calfun precondition check in the absolute-bounds path (both full-sample
  and replicate-loop branches):** before building the logit calfun with vector
  bounds, verify `all(weights_vec > abs_L & weights_vec < abs_U)` (or
  `all(rep_wt > abs_L & rep_wt < abs_U)` in the replicate branch). If any
  base weight violates this, throw `surveywts_error_bounds_invalid_calibration`
  — the logit calfun is ill-defined when `L_vec[k] = L_abs / d_k >= 1`
  (i.e., `d_k <= L_abs`) or `U_vec[k] = U_abs / d_k <= 1` (i.e., `d_k >= U_abs`).

**No new exported functions.** No NAMESPACE changes. No `man/` changes. No
`DESCRIPTION` changes. No new error classes (`surveywts_error_bounds_invalid_calibration`
already exists; this adds a new trigger condition for logit per-unit bounds).
No new warning classes.

Update `plans/error-messages.md`: extend the `surveywts_error_bounds_invalid_calibration`
row's Condition column to include the new `calibrate_logit()` per-unit absolute-bounds
trigger (thrown when any base weight `d_k` is not strictly within `(L_abs, U_abs)`,
making the logit calfun ill-defined).

---

## Discrepancy table

The following documents all known differences between `.calibrate_nr_engine()`
and `survey::grake()`. Columns D1–D7 correspond to the discrepancy analysis
from the request.

| ID | Description | In-scope | Resolution |
|----|-------------|----------|------------|
| D1 | `u_k = x_k' lambda` ignores q_k | Yes | `u_vec = q_weights * drop(x_matrix %*% lambda)` |
| D2 | Jacobian missing q_weights factor | Yes | `jacobian = t(x_matrix) %*% ((weights_vec * df_vals * q_weights) * x_matrix)` |
| D3 | Step-halving guard uses unscaled u | Yes | `g_candidate = 1 + calfun$Fm1(q_weights * drop(x_matrix %*% lambda_new))` |
| D4 | Convention: q_k vs sigma2_k = 1/q_k | Documenting only | `survey::calibrate(variance = 1/unit_scale)` matches `calibrate_linear(unit_scale = q)` |
| D5 | `solve()` vs `MASS::ginv()` | Out of scope | Keep explicit error `surveywts_error_calibration_singular_system` |
| D6 | Absolute bounds: `mean(d_k)` vs per-unit d_k | **Yes** | `L_vec = L_abs / d_k`, `U_vec = U_abs / d_k`; pass length-n vectors to calfun; run engine with original `weights_vec` and `population_totals_vec` |
| D7 | Pre-scaling when `min(pop/samp) > 20` | Out of scope | Documented as known limitation |

---

## Function contracts

### `.calibrate_nr_engine()` (internal — not exported)

**Signature (after fix):**

```r
.calibrate_nr_engine <- function(
  x_matrix,
  weights_vec,
  calfun,
  population,
  q_weights = NULL,
  epsilon = 1e-7,
  maxit = 50L
)
```

**Arguments:**

| Argument | Type | Semantics |
|----------|------|-----------|
| `x_matrix` | `n x J` numeric matrix | Calibration model matrix |
| `weights_vec` | numeric length-n | Base design weights `d_k > 0` |
| `calfun` | `list(Fm1, dF)` | Calibration function from `.make_calfun_*()` |
| `population` | named numeric length-J | Population totals in count scale |
| `q_weights` | numeric length-n or `NULL` | Per-unit scaling factors `q_k`. `NULL` is equivalent to `rep(1, n)`. Must be positive. Callers supply the resolved `q_for_engine` vector, so `NULL` at the engine level means "caller chose to pass all-ones explicitly or engine resolves internally." |
| `epsilon` | numeric(1) | Convergence tolerance |
| `maxit` | integer(1) | Maximum iterations |

**Internal resolution of `q_weights`:**

At the top of the function body, resolve the parameter to a concrete vector:

```r
if (is.null(q_weights)) {
  q_weights <- rep(1, nrow(x_matrix))
}
```

This ensures that all downstream arithmetic uses the resolved vector, with
no conditional branches inside the iteration loop.

**Corrected pseudocode for the NR loop (D1, D2, D3 all applied):**

```
Initialize lambda = rep(0, J)
t_hat = t(X) %*% d            # Horvitz-Thompson totals
discrepancy = population - t_hat

for iter in 1..maxit:
  # D1 fix: scale the linear predictor by q_weights
  u_vec = q_weights * drop(X %*% lambda)              # n-vector

  fm1_vals = calfun$Fm1(u_vec)
  phi = t(X) %*% (d * fm1_vals)                       # J-vector
  misfit = discrepancy - phi

  df_vals = calfun$dF(u_vec)
  # D2 fix: include q_weights in the Jacobian
  jacobian = t(X) %*% ((d * df_vals * q_weights) * X) # J x J matrix

  delta_lambda = solve(jacobian, misfit)              # or throw singular error

  # Step-halving guard
  step_size = 1; n_halvings = 0
  lambda_new = lambda + step_size * delta_lambda
  # D3 fix: scale u by q_weights in step-halving candidate check
  g_candidate = 1 + calfun$Fm1(q_weights * drop(X %*% lambda_new))
  while any(!is.finite(g_candidate)) and n_halvings < 20:
    step_size = step_size / 2
    lambda_new = lambda + step_size * delta_lambda
    g_candidate = 1 + calfun$Fm1(q_weights * drop(X %*% lambda_new))
    n_halvings = n_halvings + 1

  lambda = lambda_new

  # Convergence check
  u_new = q_weights * drop(X %*% lambda)
  phi_new = t(X) %*% (d * calfun$Fm1(u_new))
  misfit_new = discrepancy - phi_new
  if max(|misfit_new| / (1 + |population|)) < epsilon:
    g_weights = 1 + calfun$Fm1(u_new)
    return list(weights=d*g_weights, lambda=lambda, n_iterations=iter, converged=TRUE)

throw surveywts_error_calibration_not_converged
```

**Returns:** Named list — same shape as before the fix:

| Field | Type | Description |
|-------|------|-------------|
| `weights` | numeric length-n | Calibrated weights `d_k * F(q_k * x_k' lambda)` |
| `lambda` | numeric length-J | Converged Lagrange multipliers |
| `n_iterations` | integer | Iterations performed |
| `converged` | logical | `TRUE` if convergence criterion was met |

**Errors (unchanged):**

| Class | Trigger |
|-------|---------|
| `surveywts_error_calibration_singular_system` | `solve(jacobian, misfit)` fails (singular Jacobian) |
| `surveywts_error_calibration_not_converged` | `maxit` reached without convergence |

**Edge cases:**

- `q_weights = NULL`: resolved to `rep(1, n)` immediately on entry; behavior
  is mathematically identical to the pre-fix behavior for all callers that
  previously passed no q_weights.
- `q_weights = rep(1, n)`: identical to `NULL` resolution; regression guard.
- `q_weights` with all values equal to a constant `c > 0`: equivalent to
  rescaling `lambda` by `1/c`; convergence is unaffected.
- Extreme `q_weights` values (e.g., `1e6` for one unit): may cause Jacobian
  to be numerically ill-conditioned; the `solve()` call will surface
  `surveywts_error_calibration_singular_system` if inversion fails.

---

### `calibrate_linear()` caller changes

**Signature:** Unchanged. No new arguments.

**What changes at each engine call site:**

The caller already computes `q_for_engine` at step 13:

```r
q_for_engine <- if (!is.null(q_weights_vec)) q_weights_vec else rep(1, nrow(plain_df))
```

This vector must be passed as `q_weights = q_for_engine` in all engine calls.

**Call site 1 — bounded absolute (full-sample):**

Before (pre-D6-fix): compute `scale_factor = mean(d_k)`, then run engine with
`scaled_weights = rep(1, n)`, `scaled_population = population / scale_factor`,
calfun built with scalar `L = abs_L`, `U = abs_U`:
```
.calibrate_nr_engine(x_matrix, scaled_weights, calfun, scaled_population, epsilon, maxit)
```

After (D6 fix + q_weights wiring): compute `L_vec = abs_L / weights_vec` and
`U_vec = abs_U / weights_vec` (length-n vectors), build calfun with vector
bounds `L = L_vec`, `U = U_vec`, then run engine with original `weights_vec`
and `population_totals_vec`:
```
.calibrate_nr_engine(x_matrix, weights_vec, calfun, population_totals_vec,
  q_weights = q_for_engine, epsilon, maxit)
```
No `scaled_weights` or `scaled_population` variables are created in this branch.

**Call site 2 — bounded multiplicative (full-sample):**

Before: `.calibrate_nr_engine(x_matrix, weights_vec, calfun, population_totals_vec, epsilon, maxit)`

After: `.calibrate_nr_engine(x_matrix, weights_vec, calfun, population_totals_vec, q_weights = q_for_engine, epsilon, maxit)`

**Call site 3 — unbounded linear (full-sample):**

Before: `.calibrate_nr_engine(x_matrix, weights_vec, calfun, population_totals_vec, epsilon, maxit)`

After: `.calibrate_nr_engine(x_matrix, weights_vec, calfun, population_totals_vec, q_weights = q_for_engine, epsilon, maxit)`

**Call site 4 — replicate loop, bounded-absolute branch:**

Before (pre-D6-fix): compute `rep_scale = mean(rep_wt)`, run with unit weights
and scaled population:
```
.calibrate_nr_engine(x_matrix, rep_scaled_wt, calfun, rep_scaled_pop, epsilon, maxit)
```

After (D6 fix + q_weights wiring): compute `rep_L_vec = abs_L / rep_wt` and
`rep_U_vec = abs_U / rep_wt` per replicate, build `rep_calfun` with vector
bounds, run with `rep_wt` and `rep_pop_vec` directly:
```
.calibrate_nr_engine(x_matrix, rep_wt, rep_calfun, rep_pop_vec,
  q_weights = q_for_engine, epsilon, maxit)
```
No `rep_scaled_wt` or `rep_scaled_pop` variables are created in this branch.

**Call site 5 — replicate loop, all other branches:**

Before: `.calibrate_nr_engine(x_matrix, rep_wt, calfun, rep_pop_vec, epsilon, maxit)`

After: `.calibrate_nr_engine(x_matrix, rep_wt, calfun, rep_pop_vec, q_weights = q_for_engine, epsilon, maxit)`

**Behavioral contract — unchanged outputs when `unit_scale = NULL`:**

When `unit_scale = NULL`, `q_for_engine = rep(1, n)`, and the engine resolves
`q_weights = rep(1, n)`. The NR update `u_vec = 1 * (X %*% lambda)` is
identical to `u_vec = X %*% lambda`. The Jacobian factor `d * dF * 1` equals
`d * dF`. The step-halving check `1 + Fm1(1 * u)` equals `1 + Fm1(u)`.
All results are numerically identical to pre-fix behavior.

---

### `calibrate_logit()` caller changes

**Signature:** Unchanged. No new arguments.

**What changes at each engine call site:**

Same pattern as `calibrate_linear()`. The caller already computes
`q_for_engine` at step 13.

**Call site 1 — absolute bounds (full-sample):**

Before (pre-D6-fix): compute `scale_factor = mean(d_k)`, `L_g = abs_L / scale_factor`,
`U_g = abs_U / scale_factor`, run with unit weights and scaled population, then
multiply output back by `scale_factor`.

After (D6 fix + q_weights wiring): compute `L_vec = abs_L / weights_vec` and
`U_vec = abs_U / weights_vec` (length-n), build calfun with vector bounds, run
with original `weights_vec` and `population_totals_vec`:
```
.calibrate_nr_engine(x_matrix, weights_vec, calfun, population_totals_vec,
  q_weights = q_for_engine, epsilon, maxit)
```
No `scaled_weights`, `scaled_population`, or post-engine `* scale_factor`
multiplication. The engine returns the final absolute weights directly.

**Call site 2 — multiplicative bounds (full-sample):**

After: add `q_weights = q_for_engine` to the engine call using `weights_vec`.

**Call site 3 — replicate loop, absolute branch:**

Before (pre-D6-fix): compute `rep_scale = mean(rep_wt)`, `rep_L_g = abs_L / rep_scale`,
`rep_U_g = abs_U / rep_scale`, build `rep_calfun` with scalar bounds, run with unit
weights and scaled population, multiply output back by `rep_scale`.

After (D6 fix + q_weights wiring): compute `rep_L_vec = abs_L / rep_wt` and
`rep_U_vec = abs_U / rep_wt` (per-unit vectors), build `rep_calfun` with vector
bounds, run with `rep_wt` and `rep_pop_vec` directly:
```
.calibrate_nr_engine(x_matrix, rep_wt, rep_calfun, rep_pop_vec,
  q_weights = q_for_engine, epsilon, maxit)
```
No `rep_scaled_wt`, `rep_scaled_pop`, or `* rep_scale` multiplication.

Note: `q_for_engine` is always the full-sample-length vector computed once per
function call; it does not change between replicates because `unit_scale` is a
per-unit property of the data, not the replicate weights.

**Call site 4 — replicate loop, multiplicative branch:**

After: add `q_weights = q_for_engine` to the engine call using `rep_wt`.

**Behavioral contract — unchanged when `unit_scale = NULL`:** Same as
`calibrate_linear()`. All results numerically identical to pre-fix behavior.

---

## Behavioral change: `bounds_scale = "absolute"` (D6 fix)

**This is a breaking change for users calling `calibrate_linear()` or
`calibrate_logit()` with `bounds_scale = "absolute"` and unequal base weights.**

| Condition | Pre-fix behavior | Post-fix behavior |
|-----------|-----------------|-------------------|
| `bounds_scale = "absolute"`, **equal** base weights | Approximate (mean-based scale) | Exact per-unit bounds; numerically identical to pre-fix because `L_abs / d_k = L_abs / mean(d_k)` when all `d_k` are equal |
| `bounds_scale = "absolute"`, **unequal** base weights | Approximation: final weights approximately in `[L_abs, U_abs]` | Exact: final weights in `[L_abs, U_abs]` per unit; matches `survey::calibrate(bounds.const = TRUE)` |
| `bounds_scale = "multiplicative"` | Unchanged | Unchanged |
| `bounds = NULL` (unbounded) | Unchanged | Unchanged |

The pre-fix approximation worked by normalizing all base weights to 1 (using
`mean(d_k)` as the scale), which only gives exact absolute bounds when all
base weights are identical. The post-fix approach passes per-unit
`L_vec[k] = L_abs / d_k` and `U_vec[k] = U_abs / d_k` to the calfun, so
the truncated-linear / logit clamp at `[L_vec[k], U_vec[k]]` in g-weight
space translates to `d_k * F(u_k) in [L_abs, U_abs]` exactly for each unit k.

---

## Error and warning classes

No new error or warning classes are added. All existing classes remain
applicable:

| Class | Still applies | Notes |
|-------|---------------|-------|
| `surveywts_error_calibration_singular_system` | Yes | Jacobian may now be more or less conditioned depending on q_weights values |
| `surveywts_error_calibration_not_converged` | Yes | Convergence behavior may differ when q_weights != 1 |
| `surveywts_error_unit_scale_invalid` | Yes | Validation happens in callers before `q_for_engine` is computed; engine receives valid vector |
| `surveywts_error_bounds_invalid_calibration` | Yes (new trigger) | `calibrate_logit()` absolute-bounds path: thrown when any base weight `d_k` is not strictly within `(L_abs, U_abs)`, making the per-unit logit calfun ill-defined (`A <= 0`) |
| `surveywts_warning_replicate_calibration_failed` | Yes | Replicate failures now propagate correct q_weights |
| `surveywts_warning_negative_calibrated_weights` | Yes | Post-calibration warning in `calibrate_linear()` unchanged |

---

## Edge cases (engine behavior)

| Case | Behavior |
|------|----------|
| `q_weights = NULL` (engine default) | Resolved to `rep(1, n)` at entry; identical to pre-fix behavior |
| `q_weights = rep(1, n)` (explicit all-ones) | Same as NULL resolution; regression baseline |
| `unit_scale = NULL` (caller default) | `q_for_engine = rep(1, n)` passed to engine; backward-compatible |
| `unit_scale = rep(2, n)` (constant scale) | Scales u_vec uniformly; convergence unaffected; final weights differ from unit_scale = NULL |
| `unit_scale` with unequal values | Differentially scales per-unit distance penalty; output deviates from unit_scale = NULL |
| `unit_scale` in replicate loop | Same `q_for_engine` (full-sample vector) used for every replicate; unit_scale is a sample property, not replicate-specific |
| Extreme `q_weights` (e.g., 1e8 for one unit) | Jacobian column dominated by that unit; may cause `surveywts_error_calibration_singular_system` if effectively rank-deficient |
| Single-row input | Engine handles; q_weights is length-1 vector; behavior well-defined |
| `calibrate_logit()`, `bounds_scale = "absolute"`, any `d_k <= L_abs` | Throws `surveywts_error_bounds_invalid_calibration` before building calfun; logit function is ill-defined (`L_vec[k] = L_abs / d_k >= 1`) |
| `calibrate_logit()`, `bounds_scale = "absolute"`, any `d_k >= U_abs` | Throws `surveywts_error_bounds_invalid_calibration` before building calfun; logit function is ill-defined (`U_vec[k] = U_abs / d_k <= 1`) |

---

## Mathematical note on D4 (convention difference)

Deville & Sarndal (1992) eq. 2.2 write the distance function as:

```
G_k(w, d) = (1/q_k) * g(w/d)   where q_k > 0
```

Large `q_k` makes the penalty small for unit k, allowing `w_k` to deviate
more from `d_k`. The Newton-Raphson update involves:

```
u_k = q_k * (x_k' lambda)
T = X' diag(d * F'(u) * q) X
```

The `survey` package uses the inverse convention: `variance = sigma2_k = 1/q_k`.
Callers who want to compare with `survey::calibrate()` must pass
`variance = 1/unit_scale` to the survey function.

---

## Quality gates

The following invariants must hold across all inputs after the fix:

1. When `unit_scale = NULL`, all outputs of `calibrate_linear()` and
   `calibrate_logit()` are numerically identical to outputs before the fix
   (to machine precision, since the only change is multiplying by
   `rep(1, n)`).

2. When `unit_scale` is a non-`NULL` vector of positive values, the engine
   applies it in all three places: `u_vec`, Jacobian, and step-halving.
   No location may use the raw `X %*% lambda` without the q-scaling.

3. The calibration constraint holds after convergence for any `q_weights`:
   `sum(d_k * F(q_k * x_k' lambda) * x_k) = t_x` within `epsilon`.

4. The `q_weights` vector passed to the engine has length equal to
   `nrow(x_matrix)`. Callers are responsible for this invariant via
   their existing `q_for_engine` computation.

5. Replicate loops pass the same `q_for_engine` vector as full-sample calls.
   `q_for_engine` is computed once per function call, not per replicate.

6. When `bounds_scale = "absolute"` and all `d_k` are equal (constant base
   weights), post-fix outputs are numerically identical to pre-fix outputs,
   because `L_abs / d_k = L_abs / mean(d_k)` for all units k.

7. When `bounds_scale = "absolute"` and base weights are unequal, post-fix
   outputs match `survey::calibrate(bounds.const = TRUE)` within `1e-8`.

---

## Pipeline split

**optional** — No new exported function. No new public argument. No numerical
method change visible in the public API when `unit_scale = NULL`. Three files
touched, all in the same logical unit.
