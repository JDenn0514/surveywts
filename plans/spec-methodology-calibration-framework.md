## Methodology Review: calibration-framework — Pass 1 (2026-06-05)

_Pass 1: No prior review file exists._

---

### Scope Assessment

All five lenses apply. The spec defines:
- A Newton-Raphson iterative solver with convergence requirements
- Four F-function forms with distinct mathematical properties
- Calibrated weights with known statistical properties (g-weight ratio bounds,
  positivity guarantees)
- g-weights stored for downstream variance estimation
- Literature attached: two Deville-Sarndal papers with detailed comprehension.md
  and two extraction documents

Lens 6 (Literature Cross-Check) applies: `comprehension.md` and both extraction
documents are present.

---

### New Issues

#### Lens 1 — Method Validity

**Issue 1: `calibrate_logit()` exposes no `bounds` argument but the underlying
method requires $L$ and $U$ to be specified**
Severity: REQUIRED
Lens: 1 — Method Validity
Resolution type: JUDGMENT CALL

The spec states `calibrate_logit()` hardcodes `L = 1e-6`, `U = 1e6` and that
"No `bounds` argument is exposed; the method is inherently bounded." But the
logit method is not inherently bounded to any fixed values — $L$ and $U$ are
free user parameters that constrain the g-weight ratio $w_k/d_k$. The spec
choice of `L = 1e-6`, `U = 1e6` is not "inherently" correct; it is a specific
numerical decision that mimics `survey::calibrate(calfun = "logit")` defaults.
This is defensible as a design choice, but the spec's phrasing misrepresents the
method. More importantly, a user who needs bounds of, say, `c(0.3, 3)` has no
way to use `calibrate_logit()` for that purpose — they must use
`calibrate_linear(bounds = c(0.3, 3))` (truncated-linear), which is a
different method with different properties (closed interval vs. open interval).
The spec should acknowledge this constraint explicitly, and explain that users
who want logit-bounded calibration with custom bounds have no pathway. The
current design leaves a gap: bounded logit with user-specified bounds is not
available.

Options:
- **[A] Add a `bounds` argument to `calibrate_logit()`** with default
  `c(1e-6, 1e6)`. This makes the method's parameters fully transparent and
  matches the statistical literature (Deville et al. 1993 §3). The hardcoded
  defaults remain correct for the common case. Effort: low, Risk: low,
  Impact: logit with custom bounds becomes available, Maintenance: minor —
  bounds validation already exists for `calibrate_linear()`.
- **[B] Keep hardcoded bounds but document the gap explicitly** — add a
  `@details` note that custom logit bounds require calling the engine directly
  or using `calibrate_linear()` as an approximation. Effort: low, Risk: low,
  Impact: no new capability, user confusion reduced, Maintenance: none.
- **[C] Do nothing** — Users without the need for custom logit bounds will
  never notice, but the missing capability is a real gap vs. `survey::calibrate()`.

**Recommendation: [A]** — The logit bounds are explicitly documented as user
parameters in both papers. Hardcoding them without exposure misrepresents the
method and prevents legitimate use cases. Default `c(1e-6, 1e6)` preserves
backward compatibility.

---

**Issue 2: Behavior for `bounds = c(L, U)` with infeasible constraints leaves
error type ambiguous — singular matrix vs. NR divergence**
Severity: REQUIRED
Lens: 1 — Method Validity
Resolution type: UNAMBIGUOUS

The spec says (both `calibrate_linear()` and `calibrate_rake()` edge cases):
"Newton-Raphson diverges; error `surveywts_error_calibration_not_converged`"
for infeasible bounds. The comprehension.md §Gotchas explicitly notes: "The
existing error class `surveywts_error_calibration_not_converged` should be
re-examined to distinguish 'divergence' from 'linear algebra failure.'" The
1992 paper's extraction also distinguishes the Newton-Raphson convergence failure
(bounds too tight, algorithm diverges or oscillates) from the linear algebra
failure (Jacobian becomes singular). Both are currently mapped to
`surveywts_error_calibration_not_converged`. A user receiving this error cannot
distinguish "try wider bounds" (bounds infeasibility) from "your calibration
variables are collinear" (singular T_x). The spec's edge case for "Singular
`T_x` matrix" explicitly says "results in an R error (not a typed surveywts
error)" — this is a different behavior than the converge/not-converged error
path, creating two inconsistent error pathways for what users will perceive as
the same problem ("calibration failed").

The fix: add a new error class `surveywts_error_calibration_singular_system`
(or similar) to `plans/error-messages.md` for the `solve()` / rank-deficient
Jacobian case, distinct from `surveywts_error_calibration_not_converged` which
covers NR iteration exhaustion. The spec's "Singular T_x" edge case should use
this new class rather than propagating a bare R error.

Options:
- **[A] Add `surveywts_error_calibration_singular_system` to error-messages.md**
  and catch `solve()` failures in the engine with a `tryCatch()`, throwing the
  typed error. The spec's edge case text for singular T_x updates accordingly.
  Effort: low, Risk: low, Impact: users get actionable typed errors for both
  failure modes, Maintenance: none ongoing.
- **[B] Keep the current behavior** (bare R error from `solve()`) but document
  it explicitly in the spec as a known gap with a note about how to recognize it.
  Effort: very low, Risk: low, Impact: users still see unhelpful errors,
  Maintenance: technical debt.
- **[C] Do nothing** — Ambiguous error pathway remains. No user in the current
  release cycle is affected if no one uses collinear calibration variables, but
  the gap is real.

**Recommendation: [A]** — This is an unambiguous improvement: typed errors are
always better than bare R errors for a user-facing package. The effort is minimal.

---

**Issue 3: Weight conservation property is not stated**
Severity: REQUIRED
Lens: 1 — Method Validity
Resolution type: UNAMBIGUOUS

The spec's "Quality gates" section lists five invariants but omits the weight
conservation property. After calibration with `type = "count"` targets, the sum
of calibrated weights must equal the population total N (the common sum of all
marginals). After calibration with `type = "prop"` targets, the sum of
calibrated weights must equal the sum of design weights (since proportion-based
calibration scales to 1.0). This is a fundamental mathematical property of the
calibration framework (it follows directly from substituting any unit-vector
auxiliary into the calibration constraint F2). Omitting it from the quality
gates means the spec does not require tests for this property, and a
buggy implementation could pass all other tests while silently violating weight
conservation.

The fix: add a sixth quality gate:
"**Weight conservation.** After calibration with `type = 'count'` targets
using $J$ marginal variables, the sum of calibrated weights equals the shared
population total $N = \sum_h t_{x,h}$ (which must equal the common total
implied by all margins). After calibration with `type = 'prop'` targets,
the sum of calibrated weights equals the sum of design weights."

Options:
- **[A] Add the weight conservation invariant to the quality gates section**
  as described. Effort: minimal, Risk: none, Impact: tester generates a
  required test for this property, Maintenance: none.
- **[B] Do nothing** — The property holds mathematically if the calibration
  is correct, so it may be considered implicit. But the quality gate list is
  precisely where "should hold mathematically" gets converted into "must be
  tested."

**Recommendation: [A]** — This is an unambiguous gap in the quality gates.

---

**Issue 4: Uniform starting weights for plain `data.frame` input are not
documented as a statistical assumption**
Severity: REQUIRED
Lens: 1 — Method Validity
Resolution type: UNAMBIGUOUS

The spec states for `weights = NULL` with plain `data.frame` input: "uniform
starting weights for plain `data.frame`." This is noted under the `weights`
argument but its statistical interpretation is not stated anywhere in the spec.
Uniform starting weights ($d_k = 1$ for all $k$) imply a simple random sample
design (SRS assumption). Calibration on top of SRS weights produces GREG
estimates that assume the SRS variance formula is appropriate — but if the data
is a convenience sample, a quota sample, or any non-probability sample without
design weights, treating them as SRS weights is a statistical assumption that
may be entirely inappropriate and will silently produce wrong estimates.

The spec says uniform starting weights are used but does not warn the user
that this is an SRS assumption. The `@details` for at least `calibrate_linear()`
or the shared `calibrate()` dispatcher should explicitly state: "When
`data` is a plain `data.frame` and `weights = NULL`, all design weights are
set to 1 (equivalent to assuming a simple random sample). This is appropriate
only if the data comes from an equal-probability sample or if you are
treating all units as having equal selection probability. For non-probability
samples or unequal-probability designs, always supply design weights."

Options:
- **[A] Add the SRS assumption note** to the `@details` of `calibrate()` and
  to each function's `weights` argument description. Effort: low, Risk: none,
  Impact: users are warned before applying calibration to inappropriately
  unweighted data, Maintenance: none.
- **[B] Emit `surveywts_warning_srs_no_weights`** (already exists in
  error-messages.md) when plain `data.frame` with `weights = NULL` is passed.
  Effort: slightly higher, Risk: low, Impact: programmatic detectable warning,
  Maintenance: none.
- **[C] Do nothing** — The SRS assumption is implicit. Users with non-probability
  samples should know to supply weights.

**Recommendation: [B]** — `surveywts_warning_srs_no_weights` already exists.
Emitting it makes the assumption machine-detectable and testable.

---

**Issue 5: `calibrate_rake()` `bounds` with `algorithm = "classic_ipf"` — warning
vs. error semantics are inconsistent with the spec's own treatment of `cap` with
`"nr"`**
Severity: REQUIRED
Lens: 1 — Method Validity
Resolution type: JUDGMENT CALL

The spec treats `cap` with `algorithm = "nr"` as a hard error
(`surveywts_error_cap_not_supported_nr`), because `cap` fundamentally changes
the IPF algorithm in a way incompatible with NR. But `bounds` with
`algorithm = "classic_ipf"` is treated as a warning that silently ignores the
argument. The spec text says: "`bounds` is ignored (with
`surveywts_warning_control_param_ignored`) if supplied with `algorithm =
'classic_ipf'`." This asymmetry is hard to justify: if `cap` + `"nr"` is
wrong enough to error, then `bounds` + `"classic_ipf"` is equally wrong (the
user explicitly asked for bounded raking and got unconstrained IPF instead). A
user who specifies `bounds = c(0.5, 2)` with `algorithm = "classic_ipf"` and
sees only a warning is likely to miss the warning and believe their weights are
bounded — they are not.

Options:
- **[A] Treat `bounds` + `algorithm = "classic_ipf"` as an error**, symmetric
  with `cap` + `"nr"`. Add `surveywts_error_bounds_not_supported_classic_ipf`
  to error-messages.md. Effort: low, Risk: low, Impact: users get a clear error
  rather than silently unconstrained weights, Maintenance: one new error class.
- **[B] Keep the warning** but change the warning class to something more
  specific than `surveywts_warning_control_param_ignored` (which is used for
  mundane key-name typos). Use a dedicated class like
  `surveywts_warning_bounds_ignored_classic_ipf`. Effort: low, Risk: low,
  Impact: machine-detectable specific warning, Maintenance: one new warning class.
- **[C] Do nothing** — The warning pattern exists elsewhere for `bounds` +
  incompatible algorithm. Users can check the warning. But the asymmetry with
  `cap` + `"nr"` remains unexplained.

**Recommendation: [A]** — The statistical consequence of silently ignoring
bounds is more severe than silently ignoring a convergence tolerance. Symmetry
with `cap` + `"nr"` treatment (error) is the right call. This is a
JUDGMENT CALL but [A] is the statistically conservative choice.

---

#### Lens 2 — Variance Estimation Validity

**Issue 6: g-weights stored in `@calibration$g_weights` — downstream use by
`surveycore` is deferred but the deferral is not explicitly stated in the spec**
Severity: REQUIRED
Lens: 2 — Variance Estimation Validity
Resolution type: UNAMBIGUOUS

The spec states "G-weight accessor function — out of scope" and "G-weight
storage for `weighted_df` outputs — out of scope." But the spec does not state,
for each input class, (a) whether SE computation on calibrated weights is valid
without g-weight-aware variance estimation, (b) what is and is not valid in the
interim, or (c) whether the user is warned about any loss.

The comprehension.md §F5 and §Gotchas both state: "Variance estimator requires
calibrated weights in residuals" — using design weights $d_k$ instead of
calibrated weights $w_k$ in the variance formula yields a design-consistent but
not model-nearly-unbiased estimator. For `weighted_df` outputs where
`@calibration` is not populated, users computing SEs after calibration have no
access to the g-weights and thus cannot apply the correct variance estimator.
The spec is silent on what SEs computed on `weighted_df` calibrated outputs
represent.

For `survey_taylor` inputs where `@calibration` is populated, the spec says
the Taylor design structure is preserved. But it does not state: does
`surveycore` automatically use the g-weights from `@calibration` when computing
Taylor-linearized SEs? Or do those SEs still use the naive calibrated-weight
linearization? This distinction determines whether the stored g-weights are
actually used, or whether they are stored but not read.

The fix: the spec must add a Variance Estimation section (at minimum a
subsection of `@details` or a standalone section) stating:
1. For `survey_taylor` and `survey_nonprob` outputs: g-weights are stored in
   `@calibration$g_weights`. Whether `surveycore` uses them for variance
   adjustment is deferred to the surveycore phase; in the interim, SEs from
   these objects are computed using the naive calibrated weights (design-
   consistent, not model-nearly-unbiased per Deville & Sarndal 1992 eq. 3.4).
2. For `weighted_df` outputs: g-weights are not stored. SEs computed via
   external tools (e.g., the `survey` package) on `weighted_df` calibrated
   weights do not account for calibration in the variance estimator. This is
   documented as a known limitation.

Options:
- **[A] Add a Variance Estimation note to the spec** for each output class,
  stating what is and is not valid. Effort: low (documentation), Risk: none,
  Impact: users understand SE validity at each stage, Maintenance: update when
  surveycore variance integration ships.
- **[B] Do nothing** — The deferral is mentioned in the "Out" section but
  its statistical implications are not stated. Users who compute SEs will get
  wrong answers without being warned.

**Recommendation: [A]** — Silence on variance estimation is the most common
source of downstream misuse. The spec must say something even if the answer is
"deferred; current SEs are conservative."

---

**Issue 7: For `survey_taylor` inputs: the spec does not state whether the
PSU/strata/FPC structure is preserved after calibration**
Severity: REQUIRED
Lens: 2 — Variance Estimation Validity
Resolution type: UNAMBIGUOUS

The Returns section for `calibrate_linear()` states "`survey_taylor` input →
same class (preserved); weight column updated." But "class preserved" is
ambiguous: does this mean the `@variables$ids`, `@variables$strata`,
`@variables$fpc`, and `@variables$weights` slots are all preserved? Or does it
mean only the class name `survey_taylor` is preserved while the design structure
could be modified?

This matters for variance estimation: if a user calls `svymean()` on the
returned `survey_taylor`, the SEs depend on which PSUs and strata are used.
If calibration changes the `@variables$ids` or `@variables$strata` slots (even
accidentally), linearized SEs will be computed on wrong design structure.

The fix: the Returns section must state explicitly: "For `survey_taylor` inputs,
`@variables$ids`, `@variables$strata`, `@variables$fpc`, and the calibration
model matrix structure are unchanged. Only `@variables$weights` (the weight
column) and `@calibration` are modified."

Options:
- **[A] Add an explicit statement** that only `@variables$weights` and
  `@calibration` are modified for S7 survey object inputs. Effort: minimal,
  Risk: none, Impact: contract is unambiguous.
- **[B] Do nothing** — "Same class preserved" is probably intended to mean
  full preservation, but the spec should say so.

**Recommendation: [A]** — Unambiguous fix; one sentence in the Returns block.

---

**Issue 8: For `survey_replicate` inputs: the spec says each replicate is
re-calibrated independently, but does not state the correct population total
scaling for each replicate**
Severity: BLOCKING
Lens: 2 — Variance Estimation Validity
Resolution type: UNAMBIGUOUS

The spec states: "calibration is applied independently to every replicate weight
column using the same population `targets`." The comprehension.md §Existing
implementation notes §4 confirms the correct approach: "The replicate loop
implements population count scaling per replicate (`rep_total_w <- sum(rep_wt)`)."
This is the critical step — for each replicate, when `type = "count"`, the
population totals must be scaled to the replicate's effective population total
rather than the full-sample total.

The spec does not state this scaling step. It says "using the same population
`targets`" — which would be wrong for `type = "count"`. A replicate that
excludes some units has a smaller effective sample size, and its population
total must be scaled proportionally: `rep_target = targets * (sum(rep_wt) /
sum(base_wt))`. Using the full-sample `targets` directly for each replicate
produces calibrated replicate weights that do not correspond to any valid
variance estimator and will produce biased SEs.

The fix: the spec's Returns section for `survey_replicate` inputs and/or the
`data` argument description must state: "For `survey_replicate` inputs, each
replicate's population totals are scaled to that replicate's effective
population (`type = 'count'`: `rep_total_w / full_total_w * targets`;
`type = 'prop'`: targets unchanged since proportions are scale-invariant)
before calibration."

Options:
- **[A] Add the replicate-specific population total scaling rule** to the spec,
  as a bullet in the Returns section for `survey_replicate`. Effort: low,
  Risk: none, Impact: builder knows the correct algorithm; current implementation
  already does this, Maintenance: none.
- **[B] Add a cross-reference to the existing engine implementation** without
  specifying the algorithm in the spec. Effort: very low but violates the
  spec's role as a standalone behavioral contract.
- **[C] Do nothing** — The existing engine code already does this correctly, so
  the builder will replicate it. But the tester has no way to write a test for
  this property without the spec stating it.

**Recommendation: [A]** — This is a BLOCKING issue: without the scaling rule
in the spec, the tester cannot write a numerical test for replicate calibration
validity. The rule is already implemented but the spec must state it.

---

#### Lens 3 — Algorithmic Correctness

**Issue 9: The NR convergence criterion for `calibrate_rake(algorithm = "nr")`
specifies `epsilon` as "max absolute deviation from target totals" but does not
state which quantity is monitored**
Severity: REQUIRED
Lens: 3 — Algorithmic Correctness
Resolution type: UNAMBIGUOUS

The spec states `epsilon = 1e-7` as the "convergence tolerance (max absolute
deviation from target totals)" for `algorithm = "nr"`. But "target totals" is
ambiguous: is this the max of `|Σ w_k x_k - t_x|` (calibration constraint
residual in count scale)? Is it `max(|λ_{ν+1} - λ_ν|)` (Lagrange multiplier
convergence)? Is it a relative quantity? The papers leave the stopping criterion
unspecified (comprehension.md §Gotchas: "Newton-Raphson convergence tolerance
is not stated in either paper"). The existing `calibrate_greg()` implementation
delegates to `survey::calibrate()` which has its own epsilon semantics. For
the new NR raking path (if implemented as a custom loop), the spec must
precisely state what is compared to `epsilon`.

This matters because:
- Monitoring `|λ_{ν+1} - λ_ν|` can declare convergence when the constraint
  residuals are still large (if the Jacobian is ill-conditioned).
- Monitoring constraint residuals directly is the most meaningful choice
  (it measures calibration accuracy) but requires knowing the scale of totals.
- `survey::calibrate()` monitors `max(abs(Xwts - calfun@Xpop))` in count
  scale.

The fix: the spec must state: "Convergence is declared when
`max(|Σ_k w_k x_k[j] - t_x[j]|) < epsilon` for all `j` — the maximum absolute
discrepancy between weighted sample totals and population targets in count scale.
For `type = 'prop'` targets, comparisons are on the proportion scale after
multiplying both sides by `sum(d_k)`."

Options:
- **[A] State the exact convergence criterion** as the max absolute constraint
  residual in count scale, matching `survey::calibrate()` semantics. Effort:
  minimal, Risk: none, Impact: builder implements the correct stopping rule,
  Maintenance: none.
- **[B] State the criterion as max absolute change in lambda**: `max(|λ_{ν+1} -
  λ_ν|) < epsilon`. This is a valid alternative but less directly interpretable
  in survey terms.
- **[C] Do nothing** — The implementer will guess or copy `survey::calibrate()`.
  But guessing is exactly what the spec is supposed to prevent.

**Recommendation: [A]** — Matching `survey::calibrate()` semantics for
`epsilon` enables numerical comparison tests between this package and `survey`.

---

**Issue 10: `calibrate_linear(bounds = NULL)` is described as "one Newton step
is exact" but the spec also says `control` params are "stored in the history
entry but do not affect computation" — the spec should confirm the engine
does NOT enter a convergence loop**
Severity: REQUIRED
Lens: 3 — Algorithmic Correctness
Resolution type: UNAMBIGUOUS

The spec correctly states: "No iteration is needed; the first Newton-Raphson
step is exact." And: "`maxit` and `epsilon` are only active when `bounds` is
non-`NULL`." This is correct per the literature. However, the spec does not
make it a behavioral contract — it does not list "linear method does not iterate"
in the quality gates or in the algorithmic description. If the engine is
implemented by calling `survey::calibrate(calfun = "linear")` (the current
approach per comprehension.md), the single-step behavior is guaranteed by the
`survey` package. But if the engine is ever refactored to a custom NR loop, the
single-step property could be accidentally broken and no test would catch it
(because the spec does not assert it as a testable behavior).

The fix: add to the quality gates: "**Single-step for linear calibration.**
For `calibrate_linear(bounds = NULL)`, the engine completes in exactly one
Newton step (`n_iterations == 1`). This is stored in `@calibration$n_iterations`
and must equal `1L` for any plain-linear calibration."

Options:
- **[A] Add the single-step invariant to the quality gates** and store
  `n_iterations` in `@calibration` as already planned. Effort: minimal,
  Risk: none, Impact: tester can write `expect_equal(obj@calibration$n_iterations, 1L)`
  for plain linear.
- **[B] Do nothing** — The single-step property is stated in `@details` but
  not as a testable quality gate.

**Recommendation: [A]** — The single-step distinction is a core correctness
property and deserves a quality gate.

---

**Issue 11: For `calibrate_rake(algorithm = "nr")` with `bounds`, the spec does
not state which F-function is used**
Severity: BLOCKING
Lens: 3 — Algorithmic Correctness
Resolution type: JUDGMENT CALL

The spec states: "When `bounds = c(L, U)` is supplied with `algorithm = 'nr'`,
constrained raking is performed." But it does not state which F-function is used.
`calibrate_rake(algorithm = "nr")` normally uses $F(u) = \exp(u)$ (the
multiplicative raking method). When `bounds` are supplied, what F-function
constrains the g-weights?

Two valid choices from the 1993 paper:
- Use the **logit** F-function (open interval, soft bounds), replacing
  $\exp(u)$ entirely.
- Use the **truncated-linear** F-function (closed interval, hard bounds),
  replacing $\exp(u)$ entirely.

Neither choice is "constrained raking" in a pure sense — both represent a
switch to a completely different distance function. The `survey::calibrate()`
function handles this by having separate `calfun` options; it does not offer
"bounded raking" as a single mode. The spec's current design (one `bounds`
parameter for a function called `calibrate_rake()`) could produce user
confusion: a user who thinks they are getting raking but with bounded g-weights
is actually getting logit calibration on marginal targets.

This is a BLOCKING issue: the implementer cannot write the NR+bounds path
without knowing which F-function to use.

Options:
- **[A] Use the logit F-function** when `bounds` is supplied to
  `algorithm = "nr"`. This matches the interpretation "soft bounds on marginal
  raking" and produces open-interval g-weight constraints. Document that this
  switches from multiplicative to logit F in `@details`. Effort: medium (new
  F-function in the NR loop), Risk: medium (diverges from classical raking),
  Impact: fully bounded marginal calibration, Maintenance: additional test
  coverage needed.
- **[B] Use the truncated-linear F-function** when `bounds` is supplied.
  Hard bounds but potentially heavier weight concentration at the clipping
  boundary.
- **[C] Remove `bounds` from `calibrate_rake()` entirely** and direct users to
  `calibrate_linear(bounds = ...)` for bounded calibration. This is the
  cleanest from a design standpoint: each function has one F-function.
  `calibrate_rake()` does unbounded multiplicative raking; bounded calibration
  uses `calibrate_linear()` or `calibrate_logit()`. Effort: low (remove
  parameter), Risk: low, Impact: users who want bounded raking use separate
  functions per their desired bounds type, Maintenance: cleaner API.
- **[D] Do nothing** — Implementer guesses. Wrong F-function is chosen. Tests
  may not catch it because the spec does not specify the F-function for this
  path.

**Recommendation: [C]** — This is a JUDGMENT CALL but [C] is the methodologically
cleanest approach. "Bounded raking" is not a single well-defined method in the
Deville-Sarndal framework — it is either logit calibration or truncated-linear
calibration applied to marginal targets. Naming it `calibrate_rake(bounds = ...)` 
misrepresents the method. Remove `bounds` from `calibrate_rake()` and add a
`@details` note directing users to `calibrate_linear(bounds = ...)` for bounded
marginal targets.

---

**Issue 12: The `q_weights` argument is assumed to be all-ones but this is not
stated as an explicit constraint in the function contracts**
Severity: SUGGESTION
Lens: 3 — Algorithmic Correctness
Resolution type: UNAMBIGUOUS

The 1992 paper has explicit $q_k$ parameters in the distance minimization
(Formula 2 in extraction-deville-1992.md): $\sum_s (w_k - d_k)^2 / (d_k q_k)$.
With $q_k = 1$ (the default), GREG reduces to the standard form. But with
$q_k \ne 1$, the calibrated weights change: the 1992 paper's Example 1 shows
that $q_k = 1/x_k$ recovers the ratio estimator. The existing
`.build_calibration_provenance()` accepts `q_weights` as an argument and stores
it in `@calibration$q_weights`. The spec does not expose a `q` or `q_weights`
argument to any of the new functions — they are all implicitly $q_k = 1$.

The spec should state explicitly: "The `q_k` scaling factors from Deville &
Sarndal (1992) are fixed at $q_k = 1$ for all units. Users who need $q_k \ne 1$
(e.g., to recover a ratio estimator) cannot be served by this API in this
release." This is an explicit limitation, not a bug, but it should be
documented.

Options:
- **[A] Add a note to `@details` of `calibrate_linear()`** stating that
  $q_k = 1$ is assumed and the $q_k$ extension is not supported. Effort:
  minimal, Maintenance: none.
- **[B] Do nothing** — $q_k = 1$ is the standard choice; most users will never
  need it.

**Recommendation: [A]** — One sentence. Prevents a future "why doesn't my ratio
estimator match" support request.

---

#### Lens 4 — Statistical Assumptions

**Issue 13: The distinction between design weights and nonresponse-adjusted
weights is not stated in the calibration functions**
Severity: SUGGESTION
Lens: 4 — Statistical Assumptions
Resolution type: UNAMBIGUOUS

The spec's `weights` argument description says "Weight column name." It does
not distinguish between:
- Design weights ($d_k = 1/\pi_k$, inverse probability of selection)
- Nonresponse-adjusted weights (design weight × nonresponse adjustment factor)
- Composite weights (design × nonresponse × post-stratification from a prior step)

The 1992 paper assumes $d_k = 1/\pi_k$ (pure design weights). If a user passes
nonresponse-adjusted weights as the starting point for `calibrate_linear()`,
the resulting calibrated weights combine three adjustments: selection, nonresponse,
and calibration — a common and valid workflow. But the variance formula changes:
using calibration-weighted residuals with already-adjusted starting weights
requires care about what the "design" variance formula actually estimates.

The spec does not need to solve this problem, but the `@details` section should
acknowledge it: "The `weights` argument accepts any pre-calibration weight column
(design weights, nonresponse-adjusted weights, or composite weights from a prior
step). The calibration framework adjusts whatever weights are provided to match
the specified targets."

Options:
- **[A] Add a sentence to `@details`** acknowledging that any pre-calibration
  weight type is accepted. Effort: minimal.
- **[B] Do nothing** — This is common knowledge for survey statisticians.

**Recommendation: [A]** — One sentence improves discoverability and avoids the
"are these the right weights to pass?" confusion.

---

**Issue 14: The `type = "prop"` vs `type = "count"` conversion step for the
calibration constraint is not specified**
Severity: REQUIRED
Lens: 4 — Statistical Assumptions
Resolution type: UNAMBIGUOUS

The calibration constraint (F2 in comprehension.md) is stated in count scale:
$\sum_k d_k F(x_k' \lambda) x_k = t_x$ where $t_x$ is a count. When
`type = "prop"`, the targets are proportions summing to 1.0 per variable. The
spec does not state how proportions are converted to counts before entering the
calibration constraint.

The standard conversion is: count target = proportion target × N, where N is
the population total. But what is N? Two choices:
- **N = sum of design weights** $\sum_k d_k$: the weighted sample represents
  the population; N is estimated from the sample.
- **N = sum of calibrated weights** from a prior step.
- **N is provided externally** (but there is no such argument).

The existing `calibrate_greg()` implementation and `survey::calibrate()` both
use $N = \sum_k d_k$ for the conversion. The spec should state this explicitly:
"When `type = 'prop'`, targets are converted to count scale by multiplying by
$N = \sum_k d_k$ (the weighted sample size under the design weights)."

Without this statement, the spec is incomplete and an implementer could choose
a different N, producing different calibrated weights.

Options:
- **[A] State the `type = 'prop'` conversion rule** (`proportion × sum(d_k)`)
  in `@details` or in the `type` argument description. Effort: minimal,
  Risk: none, Impact: unambiguous contract.
- **[B] Do nothing** — The existing implementation handles this, so builders
  will replicate it. But the spec should state the rule, not rely on code
  archaeology.

**Recommendation: [A]** — This is an unambiguous missing specification.

---

**Issue 15: Interaction bias in marginal raking is not documented as an
assumption in `calibrate_rake()`**
Severity: SUGGESTION
Lens: 4 — Statistical Assumptions
Resolution type: UNAMBIGUOUS

The comprehension.md §Assumptions states: "The claim that marginal calibration
is 'almost as efficient' as full post-stratification rests on the assumption
that the response variable $y$ is well-explained by additive effects of the
calibration factors, without interaction." This is documented in the 1993 paper
§8.1 as a formal bias result: when interactions exist, marginal raking is
conditionally biased.

The spec's `calibrate()` dispatcher `@details` states: "Raking is well-suited
for multiple independent marginal targets." The word "independent" gestures at
this but does not name the interaction assumption explicitly. A user who is
raking age × sex simultaneously, where the outcome of interest has a strong
age-by-sex interaction, may get biased estimates without knowing why.

The fix: add one sentence to the `calibrate_rake()` or `calibrate()` `@details`:
"Marginal raking minimizes distance to independent marginal targets; it does
not constrain the joint distribution. When the study variable has strong
interactions across the raking dimensions, marginal raking estimates can be
conditionally biased relative to full post-stratification (Deville et al. 1993,
§8.1). Use `poststratify()` when joint cell counts are available."

Options:
- **[A] Add the interaction bias note** to `@details`. Effort: minimal.
- **[B] Do nothing** — This is a statistical limitation well-known to survey
  statisticians.

**Recommendation: [A]** — The distinction between marginal and joint calibration
is the primary documented use case difference. The spec already correctly points
users toward `poststratify()` when cell counts are available; adding the
interaction bias note completes the picture.

---

#### Lens 5 — Formula Integrity

**Issue 16: The logit F-function formula in the spec is correct but the
definition of A is not bound to the function's actual arguments**
Severity: REQUIRED
Lens: 5 — Formula Integrity
Resolution type: UNAMBIGUOUS

The spec's mathematical background section states:
$$A = (U-L)/[(1-L)(U-1)]$$
and the logit row in the F-function table shows $F(u) \in (L, U)$ open. This is
correct and matches the 1993 extraction exactly.

However, `calibrate_logit()` has hardcoded `L = 1e-6`, `U = 1e6` with no
exposed bounds arguments. The formula in `@details` shows $A = (U-L)/[(1-L)(U-1)]$
without binding $L$ and $U$ to the hardcoded values. A reader of the
`calibrate_logit()` `@details` section who sees the formula but not the
hardcoded values will not know what $A$ equals in practice.

The fix: `calibrate_logit()` `@details` should state: "With the hardcoded
bounds $L = 10^{-6}$ and $U = 10^6$, the scaling constant is
$A = (U-L)/[(1-L)(U-1)] \approx 1 + 10^{-6}$ (approximately 1 for all
practical purposes)." This makes the formula concrete rather than abstract.

Options:
- **[A] Substitute the hardcoded values into the A formula** in the logit
  `@details` section. Effort: minimal.
- **[B] Do nothing** — The formula is generically correct; the hardcoding is
  stated elsewhere.

**Recommendation: [A]** — Formula plus concrete values aids implementer
verification.

---

**Issue 17: The `calibrate_linear()` closed-form formula in `@details` omits
the $q_k$ factor**
Severity: REQUIRED
Lens: 5 — Formula Integrity
Resolution type: UNAMBIGUOUS

The spec states the linear calibration formula as:
$$\lambda = T_x^{-1}(t_x - \hat{t}_{x\pi})$$
where $T_x = \sum_k d_k x_k x_k'$.

The 1992 paper (extraction Formula 5) states:
$$T_s = \sum_s d_k q_k x_k x_k'$$

The difference: the spec's $T_x$ omits $q_k$. When $q_k = 1$ (the default),
these are identical. But the existing `.build_calibration_provenance()` code
computes `C <- t(x_matrix) %*% (base_weights * q_weights * x_matrix)`, which
correctly includes $q_k$. The spec's formula is incomplete.

Since Issue 12 already recommends documenting that $q_k = 1$ is fixed, the
formula can remain in the simplified form — but the spec should note: "Here
$T_x = \sum_k d_k x_k x_k'$ (equivalent to $\sum_k d_k q_k x_k x_k'$ with
the fixed $q_k = 1$)."

Options:
- **[A] Add the $q_k = 1$ annotation to the formula definition.** Effort:
  minimal.
- **[B] Show the full formula with $q_k$** and note it is set to 1 here.

**Recommendation: [A]** — Consistency with the source papers and with
`.build_calibration_provenance()`.

---

**Issue 18: The NR update step in `calibrate_rake()` `@details` references
$\hat{t}_{x\pi}$ without defining it in that function's contract**
Severity: SUGGESTION
Lens: 5 — Formula Integrity
Resolution type: UNAMBIGUOUS

The spec's NR update rule for `algorithm = "nr"`:
$$\lambda_{\nu+1} = \lambda_\nu + [\phi'(\lambda_\nu)]^{-1}[t_x - \hat{t}_{x\pi} - \phi(\lambda_\nu)]$$

This formula is imported from the mathematical background section, which defines
$\hat{t}_{x\pi} = \sum_k d_k x_k$. But the `calibrate_rake()` `@details`
section does not include a symbol table for this formula — a reader of only
the `calibrate_rake()` contract does not know what $\hat{t}_{x\pi}$ is without
reading the mathematical background section separately.

The fix: add a two-row symbol table to the NR update rule in `calibrate_rake()`:
"where $\hat{t}_{x\pi} = \sum_k d_k x_k$ (Horvitz-Thompson estimate of $t_x$)
and $\phi(\lambda) = \sum_k d_k \{F(x_k'\lambda) - 1\} x_k$."

Options:
- **[A] Add the symbol definitions inline.** Effort: minimal.
- **[B] Cross-reference the mathematical background section.** Effort: minimal;
  avoids duplication.

**Recommendation: [A]** — Function contracts should be self-contained.
Cross-references are discouraged in specs.

---

#### Lens 6 — Literature Cross-Check

**Issue 19: Redundant equation in marginal calibration (fix $v_c = 0$) — spec
mentions it but does not specify it as a behavioral contract**
Severity: BLOCKING
Lens: 6 — Literature Cross-Check
Resolution type: UNAMBIGUOUS

The comprehension.md §F7 states: "Fix $v_c = 0$ to identify the system. The
active Newton-Raphson system is $(r+c-1) \times (r+c-1)$." The 1993 extraction
§F9 and Flags both state: "One of the $r+c$ equations is algebraically
redundant... Fix $v_c = 0$."

The spec's `calibrate_rake()` `@details` mentions: "For `classic_ipf`, the
one-equation redundancy in a two-way table (Deville et al. 1993 §6) is handled
internally by the IPF cycle structure." This correctly notes the redundancy is
handled but says nothing about how the NR path handles it. For
`algorithm = "nr"`, if the NR system is built as an $(r+c) \times (r+c)$ system
without dropping the redundant equation, the Jacobian is singular and NR fails.
The spec does not state:
1. That the NR raking system must fix $v_c = 0$ (drop the last column/variable
   coefficient to produce a $(r+c-1)$ system).
2. How the model matrix $x_k$ must be constructed for the raking NR case (one
   indicator per level minus the redundant constraint).

This is a BLOCKING issue: without this specification, the builder cannot
correctly implement the NR raking Jacobian for multi-variable raking targets.

The fix: the spec's `calibrate_rake()` `@details` for `algorithm = "nr"` must
add: "For a single variable with $c$ levels, the model matrix has $c-1$ dummy
columns (one level dropped as reference). For two-variable raking on an
$r \times c$ table, the system has $r + c - 1$ free parameters: $u_1, \ldots,
u_r$ and $v_1, \ldots, v_{c-1}$ with $v_c$ fixed at 0. The NR Jacobian is
$(r+c-1) \times (r+c-1)$."

Options:
- **[A] Add the model matrix construction rule** for the NR raking case.
  Effort: low, Risk: none, Impact: builder knows the exact Jacobian dimension
  and parameterization.
- **[B] Reference the comprehension.md formula** — but the spec cannot
  cross-reference other planning documents; it must be self-contained.
- **[C] Do nothing** — The builder might deduce this from §11 of the paper,
  but that requires reading the paper. The spec must be independently sufficient.

**Recommendation: [A]** — BLOCKING; the NR raking implementation cannot be
correct without this specification.

---

**Issue 20: Gotcha "no convergence tolerance stated in papers" — the spec does
not document that its chosen defaults are implementation decisions, not paper-
derived values**
Severity: REQUIRED
Lens: 6 — Literature Cross-Check
Resolution type: UNAMBIGUOUS

The comprehension.md §Gotchas states: "Newton-Raphson convergence tolerance is
not stated in either paper... The implementer must document where these defaults
come from." The spec sets `maxit = 50, epsilon = 1e-7` as defaults but does not
state that these values are not from the papers — they are chosen defaults.

The comprehension.md further flags: "Current `calibrate_greg()` defaults
(`maxit = 50`, `epsilon = 1e-7`) should be examined against the `survey`
package defaults for comparability in numerical tests."

The `survey::calibrate()` function uses `maxit = 50, epsilon = 1e-7` as well.
This is likely where the current defaults come from, but the spec should say so
explicitly: "`maxit = 50` and `epsilon = 1e-7` match the defaults used by
`survey::calibrate()`. Neither value is derived from the Deville-Sarndal papers;
they are engineering choices consistent with the `survey` package reference
implementation."

Options:
- **[A] Add a sentence to `@details` of each iterative function** noting the
  source of the default convergence parameters. Effort: minimal.
- **[B] Do nothing** — Users who check `survey::calibrate()` defaults will see
  they match.

**Recommendation: [A]** — The comprehension.md explicitly flags this as a
required documentation decision.

---

**Issue 21: The "bounds constrain $w_k/d_k$, not $w_k$ directly" gotcha is
documented in the spec's math background but is not repeated in the function
contracts where it would be found by a user reading only that function**
Severity: SUGGESTION
Lens: 6 — Literature Cross-Check
Resolution type: UNAMBIGUOUS

The comprehension.md marks this as "HIGH PRIORITY — appears in both papers."
The spec's mathematical background section correctly states: "Bounds $L$ and $U$
constrain $w_k/d_k$, **not** $w_k$ directly." But this statement appears only
in the top-level mathematical background section.

The `bounds` argument descriptions for `calibrate_linear()` and
`calibrate_rake()` do say "G-weight ratio $w_k/d_k$." This is correct.
However, the warning text for negative weights (`surveywts_warning_negative_calibrated_weights`)
is described as "Plain linear (`bounds = NULL`) produced one or more negative
calibrated weights." This might cause a user to think `bounds = c(L, U)` with
`L > 0` prevents negative calibrated weights because they confuse $w_k$ with
$w_k/d_k$. Since $d_k > 0$ always holds, bounded g-weights do imply bounded
$w_k$, but the bound is $L \cdot d_k < w_k < U \cdot d_k$, not $L < w_k < U$.

The fix: the `bounds` argument description should include an example:
"With `bounds = c(0.3, 3)`, the calibrated weight for a unit with design weight
$d_k = 100$ is constrained to the range $(30, 300)$, not $(0.3, 3)$."

Options:
- **[A] Add a brief concrete example** to the `bounds` argument description.
  Effort: minimal.
- **[B] Do nothing** — The spec already says "g-weight ratio $w_k/d_k$."

**Recommendation: [A]** — The most common implementation error per the papers is
confusing $w_k$ and $w_k/d_k$. A concrete example prevents it.

---

**Issue 22: `comprehension.md` assumption about $q_k$ default and the `survey`
package — spec does not verify `lambda` for logit is the converged NR solution,
not the linear approximation**
Severity: REQUIRED
Lens: 6 — Literature Cross-Check
Resolution type: UNAMBIGUOUS

The comprehension.md §Existing implementation notes states: "For raking and
poststrat: NULL [for lambda]. For the new NR raking path, `lambda` should also
be stored." The current `.build_calibration_provenance()` implementation computes
`lambda` for `method %in% c("linear", "logit")` as `crossproduct_inv %*% discrepancy` — 
this is the **linear approximation** of lambda (the first-step NR solution, i.e., 
the GREG lambda), not the converged logit lambda.

For `calibrate_logit()`, the converged $\lambda$ after multiple NR iterations
will differ from `T_x^{-1}(t_x - t_hat)` (the one-step approximation) because
$F(u) \ne 1 + u$ for logit. The spec says `@calibration$lambda` contains "the
converged $\lambda$ vector" for logit, but `.build_calibration_provenance()`
computes it as the linear one-step approximation. These are different quantities.

This is an existing implementation gap that the spec needs to surface: either
(a) the engine must return the converged lambda directly and `.build_calibration_provenance()`
must use that, or (b) the spec must clarify that for logit, `@calibration$lambda`
is the converged lambda returned by the NR engine, not recomputed post-hoc from
the linear formula.

Options:
- **[A] Clarify in the spec** that for `calibrate_logit()` and
  `calibrate_rake(algorithm = "nr")`, `@calibration$lambda` is the converged
  lambda from the NR engine (not recomputed via `T_x^{-1} discrepancy`), and
  require the engine to return it. Effort: low in spec, medium for
  `.build_calibration_provenance()` refactor.
- **[B] Accept the linear approximation** of lambda for logit and document that
  `@calibration$lambda` is the GREG-approximate lambda for logit, not the
  converged NR lambda. This changes what downstream variance consumers can do.
- **[C] Do nothing** — The existing implementation stores the linear lambda for
  logit. A surveycore consumer that uses this for variance residuals will get
  approximately correct (asymptotically equivalent) results but not the exact
  converged-weight residuals.

**Recommendation: [A]** — The variance estimator (F5 in comprehension.md) uses
$w_k$ (the calibrated weights from the converged lambda), not the linear
approximation. Storing the wrong lambda could propagate errors to downstream SE
computation. The spec should explicitly require the engine to return the
converged lambda for iterative methods.

---

### Summary (Pass 1)

| Severity | Count |
|----------|-------|
| BLOCKING | 3 |
| REQUIRED | 13 |
| SUGGESTION | 6 |

**Total issues:** 22

**Overall assessment:** The calibration framework spec is methodologically
sound at its core — the F-function taxonomy, the NR solver description, the
g-weight definition, and the F-function range properties are all correct. The
spec breaks down in three areas: (1) BLOCKING gaps in the NR raking
specification that make a correct implementation impossible without reading the
papers directly (Issues 8, 11, 19); (2) systematic under-specification of
variance estimation validity and scope for each input class (Issues 6, 7, 8);
and (3) several REQUIRED omissions where correct mathematical properties exist
(weight conservation, convergence criterion precision, type = "prop" conversion
rule, lambda storage correctness) but are not pinned in the contract. The
bounds-ignoring behavior of `calibrate_rake(algorithm = "classic_ipf", bounds = ...)`
is also inconsistent with the error-on-cap-with-nr pattern. None of the
identified issues represent wrong formulas in the spec — all formulas that are
present are correct. The issues are gaps and underspecifications rather than
errors. Resolving the three BLOCKING issues is prerequisite to implementation.
