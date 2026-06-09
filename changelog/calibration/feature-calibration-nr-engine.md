# Changelog: NR calibration engine infrastructure (PR 1)

**Branch:** `feature/calibration-nr-engine`
**Scope:** Internal helpers in `R/calibrate-utils.R`; new test file

## Added

- `.validate_bounds(bounds, bounds_scale, allow_null)` — validates the
  `bounds` argument for NR calibration methods. Enforces: numeric length-2,
  no NA/Inf, and scale-specific constraints (`L < 1 < U` for
  `"multiplicative"`; `0 < L < U` for `"absolute"`). Returns
  `invisible(TRUE)` on success.

- `.validate_unit_scale(unit_scale, n)` — validates the `unit_scale`
  (q-weights) argument. Enforces: numeric, length == n, no NA, all > 0.
  Returns `invisible(TRUE)` on success.

- `.make_calfun_linear(L = NULL, U = NULL)` — returns a calfun list
  `list(Fm1, dF)` for the linear method. Without bounds: `F(u) = 1 + u`
  (exact GREG). With bounds: truncated-linear clamped to `[L, U]`.

- `.make_calfun_logit(L, U)` — returns a calfun list for the logit method
  (Deville et al. 1993 §3). Numerically stable for large `|u|` via sign-
  based branching on `A*u`. `F(u) in (L, U)`.

- `.make_calfun_raking()` — returns a calfun list for the multiplicative
  method. `F(u) = exp(u)`, `F'(u) = exp(u)`. Always strictly positive.

- `.calibrate_nr_engine(x_matrix, weights_vec, calfun, population, epsilon,
  maxit)` — Newton-Raphson calibration solver implementing Deville,
  Sarndal & Sautory (1993) §11. Convergence criterion:
  `max(|misfit| / (1 + |population|)) < epsilon`. Includes step-halving
  guard (up to 20 halvings). For linear calfun, converges in exactly 1
  iteration. Throws `surveywts_error_calibration_singular_system` on rank-
  deficient Jacobian; `surveywts_error_calibration_not_converged` on maxit.

## Modified

- `.build_calibration_provenance()` — added `lambda = NULL` and
  `bounds_scale = NULL` arguments. When `lambda` is supplied explicitly,
  it is stored directly (supports NR callers that have the converged
  Lagrange vector). When `lambda = NULL`, falls back to the closed-form
  linear approximation for backward-compatible callers. `bounds_scale` is
  stored in the returned list for downstream variance estimators.
  Returned list gains `bounds_scale` field.

## Error classes added

- `surveywts_error_bounds_invalid_calibration`
- `surveywts_error_unit_scale_invalid`
- `surveywts_error_calibration_singular_system`
