# Methodology Review: phase-0-fixes

## Methodology Review: phase-0-fixes --- Pass 1 (2026-03-17)

### New Issues

#### Lens 1 --- Method Validity

**Issue 1: `survey::calibrate()` formula and population vector construction is underspecified**
Severity: BLOCKING
Lens: 1 --- Method Validity
Resolution type: JUDGMENT CALL

The spec says "Build a formula from vars_spec column names" and "Build a
population total vector matching the formula terms" but does not specify the
encoding. The current vendored GREG code (`.greg_linear()`, `.greg_logit()`)
constructs a **full indicator matrix** --- one column per level of each
categorical variable, no intercept, no reference-level dropping.

`survey::calibrate()` uses R's `model.matrix()` internally, which by default
uses treatment contrasts: k-1 dummy columns per k-level factor, plus an
`(Intercept)` column. The population totals vector must have entries matching
these model matrix column names exactly.

If the implementer uses a standard formula (`~factor(age_group) + factor(sex)`)
with treatment contrasts, the calibration will enforce constraints on k-1
levels per variable plus the total N (via the intercept). This produces the
same calibrated weights as the full-indicator approach only when the
population total is correct --- but the correspondence between the two
parameterizations is fragile and naming mismatches between the population
vector and the model matrix will cause either silent miscalibration or errors.

The spec must specify exactly how the formula and population vector are
constructed to replicate the current vendored behavior.

Options:
- **[A]** Use `contrasts = list(var = contr.treatment)` (R default) with an
  intercept term. Population vector includes `(Intercept) = N` plus k-1 level
  totals per variable. --- Effort: medium, Risk: medium (naming fragility),
  Impact: correct calibration, Maintenance: moderate (must match survey's
  internal naming convention)
- **[B]** Drop intercept and use sum-to-zero or full-indicator contrasts:
  `~factor(var1, contrasts = FALSE) - 1`. Population vector has k entries per
  variable (one per level). --- Effort: medium, Risk: low (full indicator is
  what we currently do), Impact: exact replication, Maintenance: low
- **[C]** Construct the model matrix manually and pass it to
  `survey::calibrate()` via the `formula` interface with pre-built column
  names. --- Effort: high, Risk: low, Impact: maximum control, Maintenance:
  higher
- **[D] Do nothing** --- An implementer guesses, potentially producing wrong
  calibration results that pass naive tests.

**Recommendation: [B]** --- Full indicator encoding without intercept matches
the current vendored behavior exactly and avoids reference-level ambiguity.
The formula would be `~factor(var1) + factor(var2) - 1` with
`contrasts.arg = list(var1 = contr.treatment(levels1, contrasts = FALSE), ...)`.

---

**Issue 2: Post-hoc cap after `survey::rake()` violates achieved marginal constraints**
Severity: REQUIRED
Lens: 1 --- Method Validity
Resolution type: UNAMBIGUOUS

The GAP in SS II identifies three options for handling `cap` with
`method = "survey"`. The spec recommends option (a): post-hoc trimming with a
warning. This is methodologically valid as a pragmatic choice, but the spec
does not state that **post-hoc capping breaks the marginal constraints** that
raking achieved. After capping, the weighted marginal totals will no longer
match the population targets.

The warning message `surveywts_warning_cap_post_hoc` should explicitly state
this consequence so the user can assess whether the trade-off is acceptable.
Additionally, the spec should document whether a marginal-check diagnostic
is emitted after capping (e.g., max relative error in marginals).

Options:
- **[A]** Add to the spec: (1) the warning message must state that marginal
  constraints are no longer exactly satisfied, and (2) after capping, compute
  and report the maximum marginal relative error as an informational message.
  --- Effort: low, Risk: low, Impact: user transparency, Maintenance: none
- **[B] Do nothing** --- Users receive a generic warning without understanding
  the methodological consequence.

**Recommendation: [A]** --- Transparency about constraint violation is a
one-line message addition with high user value.

---

**Issue 3: `survey::postStratify()` delegation: prop-to-count conversion is implicit**
Severity: SUGGESTION
Lens: 1 --- Method Validity
Resolution type: UNAMBIGUOUS

The spec shows the `survey::postStratify()` interface with a `Freq` column in
the population data frame. `survey::postStratify()` expects `Freq` to contain
population counts, not proportions. When `type = "prop"`, the user passes
proportions. The spec does not state where the proportion-to-count conversion
happens --- it is presumably upstream in `poststratify()` /
`.validate_population_cells()` before the engine is called, but this should be
explicit.

Options:
- **[A]** Add a one-line note to SS IX (or SS II) stating: "The engine always
  receives population counts. When `type = \"prop\"`, the calling function
  converts proportions to counts (using total weight as the population total)
  before calling `.calibrate_engine()`." --- Effort: trivial, Risk: none,
  Impact: clarity, Maintenance: none
- **[B] Do nothing** --- An implementer may insert the conversion in the wrong
  place.

**Recommendation: [A]**

---

#### Lens 2 --- Variance Estimation Validity

**Issue 4: Zero weights after nonresponse adjustment and downstream variance estimation**
Severity: REQUIRED
Lens: 2 --- Variance Estimation Validity
Resolution type: JUDGMENT CALL

Change 2 states that zeroing nonrespondent weights "preserves design structure
(FPC, strata, PSUs) for variance estimation." This is the primary motivation
for the change and is methodologically correct. However, the spec does not
document the downstream behavior:

1. **Taylor linearization with zero weights:** Zero-weight units contribute
   nothing to the point estimate but still appear in the design structure. For
   Taylor-linearized variance estimators, zero-weight units affect the degrees
   of freedom calculation (they count as sampled units). `survey::svydesign()`
   and `survey::svymean()` handle this correctly --- zero-weight PSUs are
   effectively excluded from variance calculations. But the user should know
   this.

2. **PSUs with all nonrespondents:** If a PSU has only nonrespondent units,
   all its weights are zero. The PSU contributes nothing to estimates but still
   counts as a selected PSU for variance estimation. This is the correct
   behavior (it reflects the selection, not the response), but it can produce
   slightly different standard errors than dropping those PSUs entirely.

3. **Re-calibration after nonresponse adjustment:** The spec correctly notes
   that zero weights fail `.validate_weights()`, preventing re-calibration.
   But the spec doesn't state whether the user should be guided toward
   filtering to respondents first or whether a future feature (Phase 2) will
   handle this.

Options:
- **[A]** Add a "Downstream behavior" subsection to Change 2 documenting: (1)
  Taylor linearization handles zero weights correctly (reference `survey`
  package behavior), (2) all-zero PSUs are preserved and their SE contribution
  is noted, (3) re-calibration requires filtering to respondents (with a
  cross-reference to Phase 2). --- Effort: low, Risk: none, Impact: user
  guidance, Maintenance: none
- **[B]** Document only point (3) and defer (1)/(2) to the roxygen
  documentation at implementation time. --- Effort: trivial, Risk: low,
  Impact: minimal
- **[C] Do nothing** --- Users discover the behavior empirically.

**Recommendation: [A]** --- This is a behavioral contract change; the spec
should document the downstream implications, not leave them to roxygen.

---

#### Lens 3 --- Algorithmic Correctness

**Issue 5: Convergence check for `survey::calibrate()` is inappropriate for the linear case**
Severity: REQUIRED
Lens: 3 --- Algorithmic Correctness
Resolution type: UNAMBIGUOUS

The spec says: "Check convergence by comparing weighted totals of the
calibrated design against the population vector. If max relative error exceeds
`epsilon`, throw `surveywts_error_calibration_not_converged`."

This is stated as a blanket rule for all `survey::calibrate()` calls, but:

1. **Linear calibration (GREG) is closed-form** --- it has an exact algebraic
   solution with no iteration. There is no convergence to check. Applying a
   convergence check with threshold `epsilon` (which defaults to `1e-7`) to a
   closed-form solution will either always pass (if machine precision < epsilon)
   or fail spuriously due to floating-point rounding. The check is unnecessary
   and potentially misleading.

2. **Logit calibration is iterative** --- `survey::calibrate()` with
   `cal.logit` uses Newton-Raphson and has its own internal convergence
   monitoring. It issues a warning on non-convergence. The spec doesn't clarify
   whether surveywts should: (a) suppress survey's warning and throw its own
   error, (b) let both the survey warning and surveywts error through, or (c)
   intercept survey's warning and convert it to surveywts's error class.

Options:
- **[A]** Apply the convergence check only to the logit case. For linear, skip
  the check entirely (the solution is exact). For logit, intercept
  `survey::calibrate()`'s non-convergence warning via `withCallingHandlers()`
  and re-throw as `surveywts_error_calibration_not_converged`. --- Effort: low,
  Risk: low, Impact: correct behavior, Maintenance: low
- **[B]** Apply the post-hoc check to both methods but use a generous threshold
  (e.g., `1e-6`) for linear to accommodate machine precision. --- Effort: low,
  Risk: medium (still misleading for linear), Impact: uniform code path,
  Maintenance: low
- **[C] Do nothing** --- The convergence check may produce false positives for
  linear calibration under adversarial inputs.

**Recommendation: [A]** --- Different methods require different convergence
handling; a blanket check conflates exact and iterative solutions.

---

**Issue 6: `force1 = FALSE` in `anesrake::anesrake()` without specifying weight conservation**
Severity: REQUIRED
Lens: 3 --- Algorithmic Correctness
Resolution type: JUDGMENT CALL

The spec sets `force1 = FALSE` and comments "we handle total-weight
conservation." But the spec does not specify how. After anesrake calibration
with `force1 = FALSE`:

- The weights satisfy the marginal targets (by construction of the raking
  algorithm)
- But the sum of calibrated weights may not equal the sum of input weights or
  any specific population total

The current vendored `.anesrake_calibrate()` does not force weights to sum to
any specific total either --- it returns the raked weights as-is. So
`force1 = FALSE` replicates the current behavior.

However, the spec says "we handle total-weight conservation" which implies
there is an active conservation step somewhere. If there isn't, the comment is
misleading.

Options:
- **[A]** Remove the comment "we handle total-weight conservation." Add a note
  that `force1 = FALSE` replicates the current vendored behavior, where weight
  totals are not explicitly conserved (they are implicitly approximately
  conserved because raking adjusts ratios, not absolute levels). --- Effort:
  trivial, Risk: none, Impact: accuracy, Maintenance: none
- **[B]** Add an explicit post-anesrake normalization step:
  `new_weights <- new_weights * (sum(input_weights) / sum(new_weights))`. This
  would ensure exact total-weight conservation. --- Effort: low, Risk: low
  (changes numerical output slightly), Impact: explicit conservation,
  Maintenance: none
- **[C] Do nothing** --- The misleading comment may cause an implementer to add
  a conservation step that doesn't exist, or to assume one exists and skip
  adding one.

**Recommendation: [A]** --- The current behavior doesn't conserve totals; the
comment should reflect that. If conservation is desired, that's a separate
design decision (option B), not something to sneak in via this spec.

---

**Issue 7: `after_stats` computation includes zero weights --- ESS/CV interpretation**
Severity: SUGGESTION
Lens: 3 --- Algorithmic Correctness
Resolution type: UNAMBIGUOUS

The spec says: "Step 15 (`after_stats`): Compute on ALL weights (including
zeros), since that's what downstream functions will see." Meanwhile, the GAP
recommends diagnostics filter to `w > 0` for user-facing ESS/CV computation.

This means `after_stats` in the weighting history will contain ESS and CV
values computed on the full weight vector (including zeros), while user-facing
diagnostics will exclude zeros. The values will differ, which could confuse
users who inspect the history.

Options:
- **[A]** Add a note to Change 2 stating: "`after_stats` records the raw weight
  state including zeros. Diagnostic functions (`effective_sample_size()`,
  `weight_variability()`) filter to positive weights, so their output will
  differ from the history's recorded ESS/CV." --- Effort: trivial, Risk: none,
  Impact: documentation clarity, Maintenance: none
- **[B] Do nothing** --- The discrepancy exists but is unlikely to cause real
  problems.

**Recommendation: [A]** --- One sentence prevents confusion.

---

**Issue 8: `survey::calibrate()` warning handling for logit non-convergence**
Severity: SUGGESTION
Lens: 3 --- Algorithmic Correctness
Resolution type: JUDGMENT CALL

When `survey::calibrate()` with `cal.logit` fails to converge, it issues a
`warning()`. The spec says to throw
`surveywts_error_calibration_not_converged`. If both fire, the user sees a
warning from `survey` followed by an error from `surveywts`, which is noisy.

Options:
- **[A]** Intercept `survey::calibrate()`'s warning via
  `withCallingHandlers()`, suppress it, and throw the surveywts error with the
  same information. --- Effort: low, Risk: low, Impact: clean UX, Maintenance:
  fragile if survey changes warning text
- **[B]** Let both fire --- survey's warning is informational context for the
  surveywts error. --- Effort: none, Risk: none, Impact: slightly noisy,
  Maintenance: none
- **[C]** Use `suppressWarnings()` around the `survey::calibrate()` call and
  rely solely on the post-hoc convergence check. --- Effort: low, Risk: medium
  (suppresses all warnings, not just convergence), Impact: clean, Maintenance:
  low

**Recommendation: [A]** (if combined with Issue 5's recommendation to
intercept warnings selectively for the logit case).

---

#### Lens 4 --- Statistical Assumptions

**Issue 9: Zero weights assume downstream software handles them correctly**
Severity: SUGGESTION
Lens: 4 --- Statistical Assumptions
Resolution type: UNAMBIGUOUS

Change 2 sets nonrespondent weights to 0 and documents that "design structure
is preserved." The implicit assumption is that all downstream consumers of the
weighted data (survey estimation functions, user code) correctly handle zero
weights --- specifically, that zero-weight units are excluded from numerators
but included in design structure for variance estimation.

The `survey` package handles this correctly. But user-written code that
iterates over weights (e.g., manual weighted means) may divide by `sum(w)`
including zeros, producing correct results, or iterate over `w > 0` rows,
also producing correct results. The risk is low.

Options:
- **[A]** Add a documentation note to the `@details` of `adjust_nonresponse()`
  stating: "Zero-weight observations are retained for design-based variance
  estimation. Survey estimation functions (e.g., `survey::svymean()`) handle
  zero weights correctly. For manual calculations, use `w[w > 0]` to exclude
  nonrespondents." --- Effort: trivial, Risk: none, Impact: user guidance,
  Maintenance: none
- **[B] Do nothing** --- The behavior is standard in survey methodology.

**Recommendation: [A]** --- Low effort, prevents a common user confusion.

---

#### Lens 5 --- Formula Integrity

**Issue 10: `pctlim = control$improvement / 100` --- incorrect conversion**
Severity: BLOCKING
Lens: 5 --- Formula Integrity
Resolution type: UNAMBIGUOUS

The spec maps surveywts's `control$improvement` to anesrake's `pctlim` with a
division by 100, commenting "anesrake uses proportion, we use %."

This is incorrect. The current vendored `.anesrake_calibrate()` uses
`improvement` as a **proportion** (default `0.01` = 1% improvement threshold),
not a percentage. The `rake()` function's default control is also
`improvement = 0.01`. In `anesrake::anesrake()`, `pctlim` is also a
proportion (default `0.05` = 5%).

Both values are in the same unit (proportions). Dividing by 100 would make the
convergence threshold 100x tighter than intended: `0.01 / 100 = 0.0001` (0.01%
improvement threshold), causing excessive iterations or non-convergence
warnings.

The correct mapping is:

```r
pctlim = control$improvement    # both are proportions; no conversion needed
```

Options:
- **[A]** Fix the spec: `pctlim = control$improvement` (no division). Remove
  the misleading comment. --- Effort: trivial, Risk: none, Impact: correct
  behavior, Maintenance: none
- **[B] Do nothing** --- The function will iterate ~100x more than intended and
  may fail to converge for inputs that currently converge easily.

**Recommendation: [A]** --- Unambiguous fix.

---

**Issue 11: `type` parameter mapping from surveywts to `anesrake::anesrake()` conflates target format with convergence behavior**
Severity: BLOCKING
Lens: 5 --- Formula Integrity
Resolution type: UNAMBIGUOUS

The spec sets:

```r
type = if (type == "prop") "pctlim" else "nolim"
```

In surveywts, `type` controls whether population targets are **proportions** or
**counts**. In `anesrake::anesrake()`, `type` controls **convergence
behavior**:
- `"pctlim"`: variables must improve chi-square by at least `pctlim` to be
  included in raking (improvement-based variable selection)
- `"nolim"`: all variables are always included regardless of improvement

These are completely unrelated concepts. The mapping causes:
- `type = "prop"` (proportional targets) to enable improvement-based variable
  selection --- **correct by coincidence** (matches current vendored behavior)
- `type = "count"` (count targets) to disable variable selection entirely ---
  **incorrect** (changes convergence behavior based on target format)

The current vendored `.anesrake_calibrate()` always uses improvement-based
convergence (equivalent to `type = "pctlim"`) regardless of whether targets
are proportions or counts. The anesrake `type` should always be `"pctlim"` to
replicate current behavior.

Options:
- **[A]** Fix the spec: always use `type = "pctlim"` for the anesrake call.
  The surveywts `type` parameter controls target interpretation only and is
  resolved upstream before the engine is called. --- Effort: trivial, Risk:
  none, Impact: correct replication of current behavior, Maintenance: none
- **[B] Do nothing** --- When users pass `type = "count"`, anesrake skips
  variable selection entirely, potentially changing which variables are raked
  and producing different weights than the current implementation.

**Recommendation: [A]** --- Unambiguous fix. The two `type` parameters are
semantically unrelated.

---

### Summary (Pass 1)

| Severity | Count |
|---|---|
| BLOCKING | 3 |
| REQUIRED | 4 |
| SUGGESTION | 4 |

**Total issues:** 11

**Overall assessment:** The delegation strategy is sound --- replacing vendored
code with `survey`/`anesrake` calls is the right approach. However, three
blocking issues must be resolved before implementation: the `anesrake` parameter
mappings (Issues 10 and 11) would produce silently wrong convergence behavior,
and the `survey::calibrate()` formula construction (Issue 1) is the most
critical translation step but is left entirely to implementer judgment.
The nonresponse zeroing change (Change 2) is methodologically well-motivated
but needs its downstream implications documented (Issues 4 and 7).
Changes 3--7, 9, and 10 have no methodology concerns --- they are refactors,
cosmetic fixes, or API consistency improvements with no statistical content.

---

## Methodology Review: phase-0-fixes --- Pass 2 (2026-03-17)

### Prior Issues (Pass 1)

| # | Title | Lens | Status |
|---|---|---|---|
| 1 | `survey::calibrate()` formula and population vector construction underspecified | 1 | ✅ Resolved |
| 2 | Post-hoc cap after `survey::rake()` violates achieved marginal constraints | 1 | ✅ Resolved |
| 3 | `survey::postStratify()` delegation: prop-to-count conversion implicit | 1 | ✅ Resolved |
| 4 | Zero weights after nonresponse adjustment and downstream variance estimation | 2 | ✅ Resolved |
| 5 | Convergence check for `survey::calibrate()` inappropriate for linear case | 3 | ✅ Resolved |
| 6 | `force1 = FALSE` in `anesrake::anesrake()` without specifying weight conservation | 3 | ✅ Resolved |
| 7 | `after_stats` computation includes zero weights --- ESS/CV interpretation | 3 | ✅ Resolved |
| 8 | `survey::calibrate()` warning handling for logit non-convergence | 3 | ✅ Resolved |
| 9 | Zero weights assume downstream software handles them correctly | 4 | ✅ Resolved |
| 10 | `pctlim = control$improvement / 100` --- incorrect conversion | 5 | ✅ Resolved |
| 11 | `type` parameter mapping conflates target format with convergence behavior | 5 | ✅ Resolved |

**Resolution details:**

- **Issue 1:** Spec now specifies full indicator encoding (`~factor(var) - 1` with
  `contrasts.arg = contr.treatment(..., contrasts = FALSE)`), k entries per
  factor in the population vector, names matching `model.matrix()` output
  (§II, lines 105--129).
- **Issue 2:** Warning must state marginal constraints are violated; max marginal
  relative error emitted as informational message (§II, lines 183--186).
- **Issue 3:** Explicit note: engine always receives counts; `poststratify()`
  converts proportions to counts upstream (§II, lines 226--229).
- **Issue 4:** Full "Downstream Behavior of Zero Weights" section added covering
  Taylor linearization, all-zero PSUs, and re-calibration guidance
  (§III, lines 368--386).
- **Issue 5:** Linear = no convergence check (closed-form). Logit = intercept
  `survey::calibrate()` warning via `withCallingHandlers()`, suppress, re-throw
  as typed error (§II, lines 136--142).
- **Issue 6:** Note clarifies totals not conserved, replicates vendored behavior,
  no normalization step (§II, lines 212--215).
- **Issue 7:** Note documents that `after_stats` includes zeros while diagnostics
  filter to positive weights; discrepancy is intentional (§III, lines 328--332).
- **Issue 8:** Logit path: intercept warning, suppress it, re-throw as
  `surveywts_error_calibration_not_converged` (§II, lines 138--142).
- **Issue 9:** `@details` documentation added for downstream zero-weight behavior
  with guidance for manual calculations (§III, lines 358--366).
- **Issue 10:** `pctlim = control$improvement` with no division; both are
  proportions (§II, line 202).
- **Issue 11:** `type = "pctlim"` always; decoupled from surveywts `type`
  parameter (§II, line 206).

### New Issues

#### Lens 1 --- Method Validity

No issues found. The delegation interfaces for `survey::calibrate()`,
`survey::rake()`, `anesrake::anesrake()`, and `survey::postStratify()` are
fully specified with correct input translations, parameter mappings, and
convergence handling. The GAPs (post-hoc capping, `.validate_weights()` zeros)
have clear recommendations with well-documented trade-offs.

#### Lens 2 --- Variance Estimation Validity

No issues found. The downstream behavior of zero weights after nonresponse
adjustment is documented for Taylor linearization, all-zero PSUs, and
re-calibration constraints. The spec correctly notes that variance estimation
after calibration is deferred to Phase 1 (replicate weight re-calibration),
and this deferral is explicit rather than silent.

#### Lens 3 --- Algorithmic Correctness

No issues found. Convergence handling is correctly differentiated: GREG is
identified as closed-form (no convergence check), logit calibration intercepts
the survey package's non-convergence warning, anesrake checks `$converge`,
and IPF delegates convergence monitoring to `survey::rake()`. Weight
conservation is explicitly documented for each path (conserved for
post-stratification, approximately conserved for anesrake, exact for GREG/logit).

#### Lens 4 --- Statistical Assumptions

No issues found. The zero-weight assumption (downstream software handles
zero-weight observations correctly) is documented in both the spec text and
the proposed roxygen documentation. The MAR assumption for nonresponse
adjustment is already documented in the existing `adjust_nonresponse()`
function and is not affected by the row-retention change.

#### Lens 5 --- Formula Integrity

No issues found. The `pctlim` and `type` parameter mappings (Issues 10--11)
are corrected. The full indicator formula encoding is specified with concrete
R syntax. All numerical interfaces show exact parameter values.

---

### Summary (Pass 2)

| Severity | Count |
|---|---|
| BLOCKING | 0 |
| REQUIRED | 0 |
| SUGGESTION | 0 |

**Total new issues:** 0

**Overall assessment:** All 11 methodology issues from Pass 1 have been
resolved in the updated spec. The delegation strategy is now fully specified:
formula encoding, convergence detection, parameter mappings, weight
conservation, and downstream zero-weight behavior are all explicit and
methodologically correct. The spec is ready for methodology lock.
