# Comprehension — calibration-framework

## Problem

The Deville-Sarndal calibration framework (1992 foundational paper; 1993 extension
to generalized raking) provides a unified theory for adjusting survey weights so
that weighted sample totals of auxiliary variables exactly match known population
totals. The approach frames all practical weighting methods — GREG, raking, logit
bounding, truncated linear bounding — as members of a single family: minimize a
unit-level distance between calibrated and design weights, subject to the
constraint that weighted auxiliary totals match the population. Every member of
the family produces calibrated weights of the form $w_k = d_k F(\mathbf{x}_k'
\boldsymbol{\lambda})$, where $F$ is the inverse of the derivative of the chosen
distance function. The 1992 paper establishes this framework, proves asymptotic
equivalence of all members to the GREG estimator, and specifies the shared
variance estimator. The 1993 paper extends the framework to marginal calibration
(raking on row/column totals of a cross-tabulation) and explicitly names all four
$F$-function implementations: linear, multiplicative, logit, and truncated linear.
The practical upshot is that all four methods — and any new one satisfying the
convexity conditions — share a single variance estimator and a common Newton-
Raphson solver. They differ only in the $F$ function substituted in step 9 of the
engine, and in whether the iteration terminates after one step (linear) or
requires multiple iterations.

---

## Formulas

### F1. General calibrated weight

$$
w_k = d_k \, F(\mathbf{x}_k' \boldsymbol{\lambda})
$$

| Symbol | Bound to |
|--------|----------|
| $w_k$ | calibrated weight column (output) |
| $d_k = 1/\pi_k$ | input `weights` column (design weight) |
| $\mathbf{x}_k$ | row $k$ of the model matrix built from calibration variable columns |
| $\boldsymbol{\lambda}$ | $J$-vector of Lagrange multipliers, solved internally |
| $F(\cdot)$ | method-specific function; see F4 |

Source: Deville & Sarndal (1992) eq. (2.2); Deville, Sarndal & Sautory (1993) eq. (2.1).

---

### F2. Calibration constraint

$$
\sum_{k \in s} d_k \, F(\mathbf{x}_k' \boldsymbol{\lambda}) \, \mathbf{x}_k
= \mathbf{t}_x
$$

| Symbol | Bound to |
|--------|----------|
| $\mathbf{t}_x$ | `population` / `targets` argument, in count scale |
| $\hat{\mathbf{t}}_{x\pi} = \sum_s d_k \mathbf{x}_k$ | Horvitz-Thompson estimate of $\mathbf{t}_x$; pre-calibration weighted column sums |

This nonlinear system is solved for $\boldsymbol{\lambda}$. For the linear method
($F(u) = 1 + u$) it reduces to a single linear system solvable in one step.

Source: Deville & Sarndal (1992) eq. (2.3); Deville et al. (1993) eq. (2.2).

---

### F3. Four $F$-function forms (primary taxonomy from the 1993 paper)

**Linear** (`method = "linear"`)

$$
F(u) = 1 + u
$$

- g-weight $w_k/d_k$ is unbounded; can be negative.
- One Newton step is exact; no iteration loop needed.
- Identical to GREG weighting.

**Multiplicative / raking** (`method = "raking"` or `"multiplicative"`)

$$
F(u) = \exp(u) > 0
$$

- g-weight always strictly positive, unbounded above.
- For a two-way marginal table, reduces to classical iterative proportional
  fitting (Deming-Stephan raking) — cell factors factor multiplicatively.

**Logit $(L, U)$** (`method = "logit"`, parameters `lower = L`, `upper = U`)

Define $A = \dfrac{U - L}{(1-L)(U-1)}$ where $L < 1 < U$.

$$
F(u) = \frac{L(U-1) + U(1-L)\exp(Au)}{U - 1 + (1-L)\exp(Au)}, \qquad F(u) \in (L, U)
$$

- Bounds are applied to the g-weight ratio $w_k/d_k$, not to $w_k$ directly.
- The ratio approaches but never reaches $L$ or $U$ (open interval).

**Truncated linear $(L, U)$** (`method = "linear"` with `bounds = c(L, U)`)

$$
F(u) = \begin{cases}
  1 + u & \text{if } u \in [L-1,\, U-1] \\
  L & \text{if } u < L - 1 \\
  U & \text{if } u > U - 1
\end{cases}
$$

- g-weight ratio can exactly equal $L$ or $U$ (closed interval).
- Heavier concentration of weight ratios at the bounds compared with logit.

| Symbol | Bound to |
|--------|----------|
| $L$ | `lower` / `bounds[1]`; must satisfy $L < 1$ |
| $U$ | `upper` / `bounds[2]`; must satisfy $U > 1$ |
| $A$ | logit scaling constant, computed internally as $(U-L)/[(1-L)(U-1)]$ |
| $x = w_k/d_k$ | g-weight ratio; the quantity bounds constrain |

Source: Deville et al. (1993) §3 (primary); Deville & Sarndal (1992) Table 1
(Cases 1, 2, 6, 7 — same family, slightly different notation).

---

### F4. Newton-Raphson solver for $\boldsymbol{\lambda}$

Define:

$$
\phi(\boldsymbol{\lambda}) = \sum_{k \in s} d_k \{F(\mathbf{x}_k' \boldsymbol{\lambda}) - 1\} \mathbf{x}_k
$$

so the calibration constraint is $\phi(\boldsymbol{\lambda}) = \mathbf{t}_x - \hat{\mathbf{t}}_{x\pi}$.

Initialize $\boldsymbol{\lambda}_0 = \mathbf{0}$. Iterate:

$$
\boldsymbol{\lambda}_{\nu+1} = \boldsymbol{\lambda}_\nu + [\phi'(\boldsymbol{\lambda}_\nu)]^{-1}
\bigl[\mathbf{t}_x - \hat{\mathbf{t}}_{x\pi} - \phi(\boldsymbol{\lambda}_\nu)\bigr]
$$

where $\phi'(\boldsymbol{\lambda}) = \sum_{k \in s} d_k F'(\mathbf{x}_k'\boldsymbol{\lambda})\,
\mathbf{x}_k \mathbf{x}_k'$ is the $J \times J$ Jacobian.

At $\boldsymbol{\lambda}_0 = \mathbf{0}$: $\phi(\mathbf{0}) = \mathbf{0}$ and
$\phi'(\mathbf{0}) = \mathbf{T}_x = \sum_{k \in s} d_k \mathbf{x}_k \mathbf{x}_k'$.

First step gives $\boldsymbol{\lambda}_1 = \mathbf{T}_x^{-1}(\mathbf{t}_x - \hat{\mathbf{t}}_{x\pi})$,
which is the GREG/linear solution. For the linear method $F(u) = 1+u$, this single
step is exact and iteration terminates.

$F'(u)$ per method:

| Method | $F'(u)$ |
|--------|---------|
| Linear | 1 |
| Multiplicative | $\exp(u)$ |
| Logit | $AF(u)(1 - F(u)/U)$ or equivalently $A \cdot \frac{(F(u)-L)(U-F(u))}{U-L}$ |
| Truncated linear | 1 if $u \in [L-1, U-1]$; 0 otherwise |

| Symbol | Bound to |
|--------|----------|
| $\nu$ | iteration counter, internal loop variable |
| $\mathbf{T}_x$ | $\sum_s d_k \mathbf{x}_k \mathbf{x}_k'$; initial Jacobian at $\boldsymbol{\lambda}=\mathbf{0}$ |
| `maxit` | maximum iterations; `control$maxit` argument |
| `epsilon` | convergence tolerance; `control$epsilon` argument |

Source: Deville et al. (1993) §11, eq. (11.1); Deville & Sarndal (1992) eq. (3.5).

---

### F5. Shared variance estimator (asymptotic equivalence result)

All calibration estimators in the family are asymptotically equivalent to GREG,
so one variance estimator applies to all methods:

$$
\hat{V}(\hat{t}_{y\mathrm{cal}}) = \sum_{k \in s}\sum_{l \in s}
\frac{\Delta_{kl}}{\pi_{kl}} (w_k e_k)(w_l e_l)
$$

where $\Delta_{kl} = \pi_{kl} - \pi_k\pi_l$, and $e_k = y_k - \mathbf{x}_k'\hat{\mathbf{B}}_{ws}$
are GREG residuals computed with calibrated weights $w_k$.

The residual regression coefficients use calibrated weights:

$$
\hat{\mathbf{B}}_{ws}: \quad
\left(\sum_{k \in s} w_k \mathbf{x}_k \mathbf{x}_k'\right)\hat{\mathbf{B}}_{ws}
= \sum_{k \in s} w_k \mathbf{x}_k y_k
$$

Using $w_k$ (not $d_k$) in the residual weighting makes the variance estimator
nearly model-unbiased in addition to design-consistent.

| Symbol | Bound to |
|--------|----------|
| $\Delta_{kl}/\pi_{kl}$ | design variance kernel; requires $\pi_{kl} > 0$ for all pairs |
| $e_k$ | GREG residual using $\hat{\mathbf{B}}_{ws}$; stored in `@calibration$g_weights` context |
| $w_k$ | calibrated weight; **not** the design weight $d_k$ |

Source: Deville & Sarndal (1992) §3, eq. (3.4) and Result 5; Deville et al. (1993) §4, eq. (4.7).

---

### F6. g-weights

$$
g_k = w_k / d_k = F(\mathbf{x}_k' \boldsymbol{\lambda})
$$

The g-weight is the ratio of calibrated to design weight. It is the quantity that
bounds $L$ and $U$ constrain. Stored in `@calibration$g_weights` for downstream
variance estimation.

Note: Deville & Sarndal (1992) does not name $g_k$ explicitly; they call the
ratio the "calibration factor." The term "g-weight" comes from the broader
Sarndal et al. (1992) sampling textbook literature.

---

### F7. Marginal calibration redundancy constraint (raking on a two-way table)

For calibration on row totals $N_{i+}$ and column totals $N_{+j}$ of an
$r \times c$ table:

$$
\sum_{j=1}^{c} \hat{N}_{ij} F(u_i + v_j) = N_{i+}, \quad i=1,\dots,r
$$

$$
\sum_{i=1}^{r} \hat{N}_{ij} F(u_i + v_j) = N_{+j}, \quad j=1,\dots,c
$$

The system has $r + c$ equations but only $r + c - 1$ degrees of freedom (the
marginal sums satisfy one linear identity). Fix $v_c = 0$ to identify the
system. The active Newton-Raphson system is $(r+c-1) \times (r+c-1)$.

Source: Deville et al. (1993) §6, eq. (6.2)–(6.3) and the paragraph below.

---

### F8. Linear (GREG) closed form

$$
w_k = d_k(1 + \mathbf{x}_k'\boldsymbol{\lambda}), \qquad
\mathbf{T}_x \boldsymbol{\lambda} = \mathbf{t}_x - \hat{\mathbf{t}}_{x\pi}
$$

$$
\boldsymbol{\lambda} = \mathbf{T}_x^{-1}(\mathbf{t}_x - \hat{\mathbf{t}}_{x\pi})
$$

This is solved in one matrix operation. No iteration loop is entered. The
engine must short-circuit to single-step for `method = "linear"`.

Source: Deville et al. (1993) §4, eqs. (4.1)–(4.4); Deville & Sarndal (1992) eqs. (1.3)–(1.5).

---

## Gotchas

**HIGH PRIORITY — appears in both papers:**

- **Bounds apply to $w_k/d_k$, not $w_k$ directly.** Parameters $L$ and $U$
  in logit and truncated-linear methods constrain the g-weight ratio $w_k/d_k$,
  not the final calibrated weight $w_k$. An implementation that checks
  `new_weights < L * base_weights` (correct) is different from one that checks
  `new_weights < L` (wrong). This is the most likely implementation error.
  (1992 paper Table 1, Cases 6–7; 1993 paper §3.)

- **Linear method is single-step.** For $F(u) = 1 + u$, Newton's first step is
  exact. The iteration loop must not run for the linear method. Running it anyway
  is harmless but wasteful; failing to iterate at all for other methods is wrong.
  (1992 §3 eq. (3.5) first-step derivation; 1993 §11.)

- **Newton-Raphson convergence tolerance is not stated in either paper.** Neither
  paper specifies a numerical stopping criterion. The reference CALMAR software
  (Sautory 1991) chose specific values not published in these papers. The
  implementer must choose `epsilon` and `maxit` based on external guidance.
  Current implementation uses `maxit = 50`, `epsilon = 1e-7` — these values are
  reasonable defaults but are not mathematically derived from the papers.
  **Design decision: the implementer must document where these defaults come from.**

- **Redundant equation in marginal calibration.** For an $r \times c$ two-way
  raking table, exactly one of the $r + c$ calibration equations is algebraically
  dependent on the others. The system is rank-deficient by one. Fix $v_c = 0$
  before entering Newton-Raphson. Failure to do so makes $\mathbf{T}_x$ singular.
  (1992 §4 eq. (4.2); 1993 §6.)

- **Singular $\mathbf{T}_x$ matrix.** The Newton-Raphson first step requires
  inverting $\mathbf{T}_x = \sum_s d_k \mathbf{x}_k \mathbf{x}_k'$. This matrix
  is singular when: (a) a calibration variable has only one distinct level in the
  sample, (b) two calibration variables are perfectly collinear in the sample, or
  (c) a poststratum (for complete poststratification) has zero sample count.
  The 1992 paper explicitly notes zero-count poststrata as an undefined case
  (Remark after Result 4). The 1993 paper treats empty cells as motivation for
  preferring marginal over complete calibration. **Neither paper provides a
  fallback.** The existing `calibrate_greg()` code passes this through to
  `solve()`, which will throw an R error. This is the correct behavior; the
  error class `surveywts_error_calibration_not_converged` should be re-examined
  to distinguish "divergence" from "linear algebra failure."

- **Non-existence of solution for bounded methods.** For logit and truncated-
  linear, there exist data-dependent limits $L_{\max} < 1$ and $U_{\min} > 1$
  such that $L > L_{\max}$ or $U < U_{\min}$ makes the calibration equations
  unsolvable. These limits cannot be computed analytically; they must be found by
  trial. The 1993 paper illustrates a $2 \times 2$ case where $L_{\max} = 2/3$.
  When bounds are too tight, Newton-Raphson diverges or the Jacobian becomes
  singular. Warn the user when convergence fails with bounded methods.

**Additional (single-paper but material):**

- **Negative calibrated weights (linear method).** $F(u) = 1 + u$ is unbounded
  below. Any unit can receive a negative calibrated weight if the adjustment is
  large. Negative weights propagate to any weighted total and can produce negative
  estimates for intrinsically positive variables. The existing
  `surveywts_warning_negative_calibrated_weights` class covers this; it must be
  retained for `calibrate_linear()`.

- **Unbounded upper g-weights (multiplicative/raking).** $F(u) = \exp(u)$
  guarantees positivity but has no upper bound. Extreme sample-population
  discrepancies can produce g-weights orders of magnitude above 1. This is
  flagged in the 1993 paper (§12, observation 2): "usually greater (sometimes
  substantially greater)" than linear method weight ratios.

- **Variance estimator requires calibrated weights in residuals.** Using design
  weights $d_k$ instead of calibrated weights $w_k$ in the variance formula
  (F5 above) yields a design-consistent but not model-nearly-unbiased estimator.
  The 1992 paper is explicit (§3, eq. (3.4) discussion): $w_k$ is preferred.
  The existing `@calibration$g_weights` are stored as $w_k/d_k$; the downstream
  variance estimator in `surveycore` must multiply by $d_k$ to recover $w_k$.
  **Verify this reconstruction is correct in the surveycore reader.**

- **Asymptotic equivalence holds only for large samples.** The claim that all
  methods have the same variance is an asymptotic ($n \to \infty$) result. For
  small samples, point estimates and variance estimates may differ meaningfully
  across methods. The 1993 §13 empirical result that "estimates are nearly
  identical" across methods is from one national survey and is not a theorem.

- **Variance estimator requires joint inclusion probabilities $\pi_{kl} > 0$.**
  Formula F5 requires $\pi_{kl}$ for all pairs. Systematic sampling with a single
  random start violates this. Neither paper provides a workaround. In practice,
  the survey package approximates $\pi_{kl}$ for most designs; this package
  defers to `surveycore` for this step.

- **Interaction bias in marginal calibration.** When the study variable $y$ has
  non-additive interactions across the table dimensions, marginal raking is
  conditionally biased. The 1993 §8.1 formula makes this explicit. This is a
  statistical limitation, not a numerical gotcha.

---

## Reference mapping

| Design decision | Justification |
|----------------|---------------|
| $w_k = d_k F(\mathbf{x}_k'\boldsymbol{\lambda})$ is the form for all methods | Deville & Sarndal (1992) §2, eq. (2.2); derives from Lagrange first-order conditions on distance minimization |
| All four methods use the same variance estimator | Deville & Sarndal (1992) §3, Result 5: all are asymptotically equivalent to GREG; eq. (3.4) applies to all |
| Linear method closes in one Newton step | Deville et al. (1993) §11: first Newton step $\boldsymbol{\lambda}_1 = \mathbf{T}_x^{-1}(\mathbf{t}_x - \hat{\mathbf{t}}_{x\pi})$ is the exact GREG solution; $F(u)=1+u$ is linear so $\phi'$ is constant and one step is exact |
| Bounds constrain the ratio $w_k/d_k$, not $w_k$ | Deville et al. (1993) §3, logit method: "Bounds $L$ and $U$ control the range of $w_k/d_k$"; Table 1 of Deville & Sarndal (1992): Cases 6–7 written as $L d_k < w_k < U d_k$, confirming the ratio is the bounded quantity |
| One equation is redundant in marginal calibration | Deville et al. (1993) §6, paragraph below eq. (6.3): "one of the $r+c$ equations is algebraically redundant"; fix $v_c = 0$ |
| Multiplicative method = classical IPF for marginals | Deville et al. (1993) §3, method 2: "for a two-way table this reduces to classical IPF (Deming-Stephan raking)"; Deville & Sarndal (1992) §4 eq. (4.2): $F(u_i+v_j)=\exp(u_i)\exp(v_j)$ matches multiplicative cell factors |
| Variance formula uses $w_k$ (calibrated), not $d_k$ | Deville & Sarndal (1992) §3, eq. (3.4) and surrounding text: "preferred for its model near-unbiasedness"; using $d_k$ is design-consistent but not model-nearly-unbiased |
| NR starting value $\boldsymbol{\lambda}_0 = \mathbf{0}$ | Deville & Sarndal (1992) eq. (3.5); Deville et al. (1993) eq. (11.1): both papers start at the origin |
| $q_k = 1$ default | Deville & Sarndal (1992) §1–2: "$q_k = 1$ is the standard choice"; only deviates for ratio estimator derivation (Example 1) |

---

## Assumptions

- **Design weights $d_k > 0$ for all $k \in s$.** Required for $g_k = w_k/d_k$
  to be well-defined. Guaranteed by the existing `.validate_weights()` check.

- **Population totals $\mathbf{t}_x$ are exact.** The papers assume census-quality
  knowledge. If targets come from a large reference survey (e.g., ACS estimates),
  the variance formula does not account for uncertainty in $\mathbf{t}_x$.
  Users supplying `reference_design` are implicitly treating those estimates as
  exact, which this package already handles via the `targets_from_reference` flag
  in history.

- **Auxiliary variables fully observed for all $k \in s$.** Neither paper
  discusses missing auxiliary data. The existing `.validate_calibration_variables()`
  check enforces this (no NAs allowed in calibration variables).

- **$\mathbf{T}_x$ is invertible.** Not stated as an explicit assumption in either
  paper, but required for all methods (at least at initialization). Violated by
  empty poststrata, single-level variables, or collinear covariates.

- **$q_k = 1$ unless explicitly overridden.** Both papers default to uniform $q_k$.
  The 1993 paper does not mention $q_k$ at all; the 1992 paper discusses it only
  in the context of recovering the ratio estimator. The new functions should
  accept a `q` argument but default to `NULL` (all ones).

- **Convergence tolerance.** The papers leave this unspecified. The implementation
  must document the choice. Current `calibrate_greg()` defaults (`maxit = 50`,
  `epsilon = 1e-7`) should be examined against the `survey` package defaults for
  comparability in numerical tests.

- **Large-sample regime.** Asymptotic equivalence and the shared variance estimator
  are large-sample results. For small surveys (say, $n < 50$), the choice of $F$
  function affects both point estimates and standard errors non-negligibly.

---

## Existing implementation notes

### What `calibrate_greg.R` has correctly

1. **F-function dispatch.** The `model` argument already routes to `"linear"` and
   `"logit"` paths inside `.calibrate_engine()`. The names will change
   (`model` → replaced by method-specific functions per the request), but the
   engine logic is sound.

2. **Single-step for linear.** Need to verify inside `.calibrate_engine()` that
   the linear path actually short-circuits after one Newton step. The current
   code delegates to `survey::calibrate()` internally (see `.calibrate_engine()`
   in the shared utils — not shown here but referenced in both functions).
   If the engine wraps `survey::calibrate(calfun = "linear")`, the short-circuit
   is handled by `survey` itself.

3. **g-weights stored.** `.build_calibration_provenance()` computes
   `g_weights = engine_result$weights / base_weights` (line 211 of
   `calibrate-utils.R`). This matches the definition $g_k = w_k/d_k$.

4. **Replicate loop.** Both `calibrate_greg()` and `calibrate_rake()` implement
   the replicate loop with population count scaling per replicate
   (`rep_total_w <- sum(rep_wt)`) and `tryCatch` with
   `surveywts_warning_replicate_calibration_failed`. This pattern is correct and
   should be replicated exactly in `calibrate_linear()` and `calibrate_logit()`.

5. **History entries.** `operation = "calibrate_greg"` naming will change to
   `"calibrate_linear"` and `"calibrate_logit"` in the new functions.

6. **`@calibration` slot.** `.build_calibration_provenance()` stores `lambda` for
   linear and logit methods, `NULL` for raking and poststrat. For the new NR
   raking path (`algorithm = "nr"`), `lambda` should also be stored (it is the
   converged $\boldsymbol{\lambda}$ vector, not just the first-step approximation).

### What needs to change or does not exist yet

1. **`calibrate_greg()` disappears.** Replaced by `calibrate_linear()` and
   `calibrate_logit()`. `calibrate_linear()` carries the `bounds` argument for
   truncated-linear. `calibrate_logit()` takes `lower` and `upper` but does not
   need a `bounds` argument (the method is inherently bounded).

2. **`calibrate_rake()` NR path is missing.** Currently `calibrate_rake()` only
   has `algorithm = "anesrake"` (chi-square variable selection) and
   `algorithm = "survey"` (fixed-order IPF via `survey::rake()`). The request
   adds `algorithm = "nr"` which implements Newton-Raphson with the multiplicative
   $F(u) = \exp(u)$, matching `survey::calibrate(calfun = "raking")`. The NR
   path also supports `bounds` (applies the logit or truncated-linear $F$-function
   to marginal calibration, not just joint calibration). The `algorithm`
   enumeration will change: `"classic_ipf"` (replaces `"anesrake"`) and `"nr"`.

3. **`calibrate()` dispatcher.** Currently routes to `calibrate_greg()`,
   `calibrate_rake()`, `calibrate_poststrat()`. After the overhaul it routes to
   `calibrate_linear()`, `calibrate_logit()`, `calibrate_rake()` only. The
   `poststratify()` rename is handled separately.

4. **`calibrate_poststrat()` → `poststratify()`.** Rename; no numerical changes.

5. **Lambda storage for NR raking.** `.build_calibration_provenance()` currently
   sets `lambda = NULL` for raking. For the NR path, the converged
   $\boldsymbol{\lambda}$ is available and should be stored — it is needed for
   the asymptotically correct variance estimator residuals.

6. **Bounds validation.** A new validator is needed for the `bounds` argument
   (or `lower`/`upper`): must have $L < 1 < U$, both finite, $L > 0$ (for
   multiplicative and logit, since $g_k \in (L, U)$ and $g_k = w_k/d_k$ must
   stay positive). Error classes for invalid bounds do not yet exist in
   `plans/error-messages.md`.

7. **`surveywts_error_calibration_not_converged` vs. singular matrix.** The
   existing error class covers both non-convergence and `solve()` failure. For
   the new API it may be worth distinguishing these; however, this is a design
   decision that should be flagged in the spec rather than resolved here.

### What the engine must provide for the new NR raking path

The engine call for `algorithm = "nr"` in `calibrate_rake()` needs:
- `method = "raking"` passed to the engine (same as current IPF path, but
  routing to Newton-Raphson internally)
- The converged $\boldsymbol{\lambda}$ returned from the engine so it can be
  stored in `@calibration$lambda`
- If `bounds` is supplied, use logit or truncated-linear $F$ in the NR loop
  rather than $\exp(u)$

The existing engine (`survey::calibrate()` wrapping) already handles this via
`calfun = "raking"`. The `bounds` extension requires checking whether the engine
supports it or whether a custom Newton-Raphson loop must be written.

---

## Citations

**Primary:**

- Deville, J.-C.; Sarndal, C.-E. (1992). Calibration Estimators in Survey
  Sampling. *Journal of the American Statistical Association*, Vol. 87, No. 418,
  pp. 376–382. URL: http://links.jstor.org/sici?sici=0162-1459%28199206%2987%3A418%3C376%3ACEISS%3E2.0.CO%3B2-3

- Deville, J.-C.; Sarndal, C.-E.; Sautory, O. (1993). Generalized Raking
  Procedures in Survey Sampling. *Journal of the American Statistical
  Association*, Vol. 88, No. 423, pp. 1013–1020.
  URL: https://www.jstor.org/stable/2290793
