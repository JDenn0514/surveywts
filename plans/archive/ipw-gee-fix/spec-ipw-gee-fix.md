# Spec — ipw-gee-fix

**Status**: SPEC_READY
**Methodology review**: PASS (0 blocking, 0 required, 1 suggestion — resolved)
**Spec review**: PASS (0 blocking, 2 required — resolved, 2 suggestions)
**Target version**: 0.2.0.9000
**PR range**: PR 1

## Scope

### In

- GEE branch of the internal propensity-fitting helper rewritten to use
  `nleqslv::nleqslv()` in place of the hand-coded Newton-Raphson loop.
- Outer saturation guard removed from the GEE branch only (the guard that
  checks `cur_scores <= eps | cur_scores >= 1 - eps` before the score
  computation; it exists in the shared pre-branch loop body and must be moved
  inside the MLE branch so the GEE branch no longer executes it).
- Inner GEE guard (early return when `pi_nps <= eps`) removed because
  `nleqslv` damps Newton steps and does not produce diverging iterates.
- `nleqslv (>= 3.3.2)` added to `Imports` in `DESCRIPTION`.
- Roxygen2 documentation updated: `@section Algorithm` GEE subsection,
  `@section Convergence`, and the `@details` non-convergence note in `ipw()`.
- `@examples` GEE block comment updated to remove the limitation note about
  population-scale convergence.

### Out

- MLE path: no behavioral change. The existing NR loop, outer saturation guard
  (now inside the MLE branch), and singular-Hessian guard all remain unchanged.
- `ipw()` public signature: no change.
- All other `ipw()` behavior rules (0 through 13, 15–20): no change.
- Post-fit degenerate check in `ipw()` (Rule 15): retained unchanged for both
  paths.
- No new exported functions.
- No S7 class changes.
- No new error or warning classes.

## Architecture

- **Files touched**: `R/ipw.R`, `DESCRIPTION`
- **Functions added**: none
- **Functions modified**: `.fit_participation_propensity()` (internal helper,
  GEE branch only); `ipw()` roxygen2 documentation only (no behavioral change
  to the function body outside the helper call)
- **Class changes**: none

## Function contracts

### `.fit_participation_propensity()` (internal)

This is a private helper. Its public contract is expressed only through the
behavior of `ipw()`. The rules below govern the GEE branch exclusively; the
MLE branch is unchanged.

**Signature** (unchanged):

```
.fit_participation_propensity(
  selection, nps_data, ref_data, ref_weights,
  method, estimating_eq, maxit, epsilon
)
```

**Arguments** (unchanged in semantics; the GEE-specific behavioral changes are
in the rules below):

| Argument | Type | Semantics |
|---|---|---|
| `selection` | one-sided formula | model matrix formula |
| `nps_data` | data.frame | NPS rows for fitting (complete cases when `has_sep = TRUE`) |
| `ref_data` | data.frame | reference rows (post-NA-deletion) |
| `ref_weights` | numeric vector | reference design weights (post-adjustment) |
| `method` | character(1) | link function name: `"logit"`, `"probit"`, or `"cloglog"` |
| `estimating_eq` | character(1) | `"mle"` or `"gee"` |
| `maxit` | integer(1) | maximum iterations |
| `epsilon` | numeric(1) | convergence threshold |

**Returns** (unchanged):

A named list with three elements:

| Element | Type | Semantics |
|---|---|---|
| `scores` | numeric vector, length = `nrow(nps_pred)` | propensity scores on all NPS rows |
| `converged` | logical(1) | whether the algorithm declared convergence |
| `final_delta` | numeric(1) | convergence diagnostic passed back to `ipw()` |

**GEE branch behavioral rules** (replace the current hand-coded NR loop for
the GEE path; MLE path is unchanged):

**Rule GEE-1 — Pre-loop constant** (unchanged from current implementation):
Before entering any iterative block, compute `ref_totals <-
colSums(X_ref * d_ref)` once. `ref_totals` is a numeric vector of length `p`
(number of model-matrix columns) representing the reference-weighted covariate
column sums. This computation is independent of `gamma` and must not be
repeated per iteration.

**Rule GEE-2 — Outer saturation guard moved to MLE branch**:
The saturation guard (`cur_scores <= eps | cur_scores >= 1 - eps`) that
currently executes at the top of the for-loop before the `if/else` branch
must be moved inside the MLE branch. It must no longer execute on the GEE
path. The guard continues to function identically for MLE. The GEE path does
not use this guard.

**Rule GEE-3 — nleqslv replaces NR loop**:
When `estimating_eq == "gee"`, the iterative block is delegated entirely to
`nleqslv::nleqslv()`. The call form is:

```
gee_fit <- nleqslv::nleqslv(
  x   = gamma,
  fn  = <score function>,
  jac = <jacobian function>,
  control = list(maxit = maxit, xtol = epsilon, ftol = epsilon)
)
```

- `x` is the starting value for `gamma`, a numeric vector of length `p`,
  initialized to `rep(0, ncol(X_nps_fit))` (unchanged from the current
  pre-loop initialization).
- `fn` is the GEE score function (Rule GEE-4).
- `jac` is the analytical Jacobian of the score (Rule GEE-5).
- `control$maxit` maps to the `maxit` argument of `.fit_participation_propensity()`.
- `control$xtol` and `control$ftol` both map to the `epsilon` argument.
  Both are set to `epsilon` so that nleqslv may declare convergence on either
  the step-size criterion or the score-norm criterion, whichever fires first.

**Rule GEE-4 — Score function** (semantics unchanged):
`fn(g)` computes the GEE score vector at coefficient vector `g`:

```
pi_g <- link(drop(X_nps_fit %*% g))
colSums(X_nps_fit / pi_g) - ref_totals
```

Where `link` is `stats::binomial(link = method)$linkinv`, evaluated at the
start of the helper (unchanged). The score function is a length-`p` numeric
vector. `fn` must be a closure over `X_nps_fit`, `link`, and `ref_totals`.

**Rule GEE-5 — Analytical Jacobian** (semantics unchanged):
`jac(g)` returns the `p × p` Jacobian matrix of the score function:

```
pi_g <- link(drop(X_nps_fit %*% g))
-crossprod(X_nps_fit, X_nps_fit * ((1 - pi_g) / pi_g))
```

`jac` must be a closure over `X_nps_fit` and `link`.

**Rule GEE-6 — Extracting the result**:
After `nleqslv::nleqslv()` returns, extract:
- `gamma <- gee_fit$x` (the solution estimate)
- `converged <- gee_fit$termcd %in% c(1L, 2L)`

**Rule GEE-7 — final_delta for nleqslv**:
`final_delta` is returned in the list as the convergence diagnostic for
`ipw()`'s non-convergence warning message. For the nleqslv path, use
`max(abs(gee_fit$fvec))` — the maximum absolute value of the score vector at
the solution — as `final_delta`. This quantity measures how close to zero
the score is, which is the natural residual for a system of equations solver.

The non-convergence warning in `ipw()` currently labels this value "max |delta|"
(a step-size label accurate only for the MLE NR path). Update the warning
message to use a path-neutral label: `"convergence diagnostic = {round(fit$final_delta, 6)}"`.
This avoids misleading the user about whether the diagnostic is a step size or
a score residual. Update both the warning message body and the `@details`
non-convergence paragraph in `ipw()` to reflect this label.

**Rule GEE-8 — termcd interpretation**:
nleqslv termination codes are interpreted as follows:

| `termcd` | Interpretation | `converged` |
|---|---|---|
| `1L` | Function criterion is near zero | `TRUE` |
| `2L` | x-criterion is near zero | `TRUE` |
| `3L` | Maximum iterations reached | `FALSE` |
| `>= 4L` | Jacobian is singular or ill-conditioned | `FALSE` |

When `converged = FALSE`, the function still returns a list with `scores`
computed from the current `gee_fit$x` estimate. The outer `ipw()` caller
will issue `surveywts_warning_propensity_nr_no_convergence` (Rule 14 in
`ipw()`; behavior unchanged).

**Rule GEE-9 — Inner guard removed**:
The inner early-return guard (`if (any(pi_nps <= eps)) { return(...) }`) that
currently exists inside the GEE branch of the hand-coded NR loop is removed.
`nleqslv` uses its own internal step-damping and does not diverge in the same
way as bare NR. The post-fit degenerate check in `ipw()` (Rule 15) handles
any residual saturation after `nleqslv` returns.

**Edge cases**:

| Case | Behavior |
|---|---|
| `maxit = 1L` | nleqslv runs a single function evaluation step; almost always `termcd = 3L`; `converged = FALSE`; warning issued by `ipw()` |
| Population-scale reference weights (`sum(d) ~ 1e6` to `1e9`) | nleqslv damps steps; converges normally; no divergence |
| Unit-scale reference weights (`base_weight = 1`) | Behavior identical to existing GEE path when it converges |
| `termcd == 4L` (singular Jacobian in nleqslv) | `converged = FALSE`; warning issued; scores returned from last iterate |
| All NPS units in a single covariate level not in reference | Never reaches nleqslv; caught by Rule 8 in `ipw()` before the helper is called (`surveywts_error_propensity_level_not_in_reference`) |

**Errors** (GEE branch — no new error classes):

| Class | Trigger condition |
|---|---|
| `surveywts_error_propensity_scores_degenerate` | Post-fit check in `ipw()` Rule 15: `any(scores <= .eps \| scores >= 1 - .eps)` after nleqslv returns; unchanged trigger logic |

**Warnings** (GEE branch — no new warning classes):

| Class | Trigger condition |
|---|---|
| `surveywts_warning_propensity_nr_no_convergence` | `gee_fit$termcd %in% c(3L, 4L, 5L, ...)` i.e., `converged = FALSE`; issued by `ipw()` Rule 14; unchanged trigger logic in `ipw()` |

---

### `ipw()` — documentation updates only

No behavioral changes to the `ipw()` function body. The following roxygen2
documentation sections require updating:

**`@section Algorithm` — GEE subsection**:
The current text describes the GEE path as using a Newton-Raphson loop with
the GEE score and Jacobian. Update to state that the GEE path uses
`nleqslv::nleqslv()` with the analytical Jacobian (Rules GEE-4 and GEE-5)
and declare convergence when `termcd %in% c(1L, 2L)`. The calibration
guarantee (`sum(w * x) = sum(d * x)`) is unchanged and need not be reworded.

**`@section Convergence`**:
Update to state that:
- MLE path convergence criterion: `max(abs(delta)) < epsilon` (unchanged).
- GEE path convergence: delegated to `nleqslv::nleqslv()`; convergence
  declared when `termcd %in% c(1L, 2L)`; non-convergence (`termcd >= 3`) issues
  `surveywts_warning_propensity_nr_no_convergence`.
- The note that GEE may fail with population-scale reference weights must be
  removed.

**`@details` — non-convergence note**:
The first sentence of the **Newton-Raphson non-convergence** details paragraph
currently describes the NR loop for both paths. Update to distinguish: "If the
MLE algorithm does not converge within `maxit` iterations, or if the GEE path
solver does not converge..." to make clear both paths can trigger the warning.

**`@examples` — GEE block**:
The comment block in the GEE example currently says: "GEE converges best when
NPS and reference are similar in size; use balanced synthetic data here to
illustrate the API." This comment incorrectly implies a convergence limitation
with unequal sizes. Replace the comment to remove that implication. The example
data and the actual `ipw()` call are unchanged.

**Documentation tier**: Tier 3 — Algorithmic (as documented in the existing
function; this spec modifies the Algorithm and Convergence sections only).

**`@references`**: unchanged (no new citations; nleqslv is a computational
tool, not a statistical method).

## Quality gates

- `devtools::check()` passes with 0 errors, 0 warnings, ≤2 pre-approved notes.
- `nleqslv` is listed under `Imports` in `DESCRIPTION` with minimum version
  `(>= 3.3.2)`.
- `nleqslv::nleqslv()` is called with `::` notation (no `@importFrom`).
- All existing `ipw()` tests (MLE path, error guards, warning guards) continue
  to pass without modification.
- GEE path with population-scale reference weights (`sum(d) ~ 1e6`) converges
  without error.
- At GEE convergence, weighted NPS covariate totals match reference totals
  (within 1e-4 for population-scale inputs).
- The outer saturation guard is present in the MLE branch and absent from the
  GEE branch.
- The inner `pi_nps <= eps` guard is absent from the GEE branch.
- `final_delta` in the returned list is `max(abs(gee_fit$fvec))` for the GEE
  path.

## Pipeline split

**optional** — No new exported function; no change to `ipw()` signature or
public contract; no new error or warning classes; only 2 files touched
(`R/ipw.R`, `DESCRIPTION`). A single PR is appropriate.
