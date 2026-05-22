## Spec Review: propensity — Pass 1 (2026-05-19)

### New Issues

#### Section: III — `ipw()`

---

**Issue 1: Factor level mismatch between `data` and `survey_taylor@data` — uncaught crash**
Severity: BLOCKING
Violates engineering-preferences.md §4 ("Handle more edge cases, not fewer")

When `data` contains a factor or character covariate with a level absent from `survey_taylor@data`
(or vice versa), `stats::model.matrix()` on each dataset produces matrices with different column
counts. The NR algorithm then fails with a dimension-mismatch error from the matrix operations
(`t(X_ref) %*% (d_ref * pi_ref)` or `crossprod()`). This is a base R error, not a
`surveywts_*` error class — the user sees a cryptic crash rather than a helpful message.

This is a real failure mode in practice: NPS panels often have respondent subgroups with
covariate combinations absent from the reference probability sample.

Options:
- **[A]** Before calling `.fit_participation_propensity()`, align factor levels between `data`
  and `survey_taylor@data` for all `selection` variables. If mismatched levels exist, emit
  `surveywts_warning_propensity_covariate_level_mismatch` naming the variable and the orphaned
  levels, and drop those levels from the model matrix construction (or error, depending on
  severity). — Effort: medium, Risk: low, Impact: prevents user-visible crashes, Maintenance: none
- **[B]** Add a pre-fit check that compares `model.matrix()` column counts for NPS and reference;
  if they differ, throw `surveywts_error_propensity_covariate_mismatch`. — Effort: low,
  Risk: low, Impact: provides a named error instead of crash, Maintenance: none
- **[C] Do nothing** — users hit a base R dimension error with no guidance on what went wrong.

**Recommendation: A** — Aligning factor levels is the minimal correct behavior for real survey
data; option B improves the message but doesn't fix the underlying problem.

---

**Issue 2: Singular or near-singular Hessian — `solve()` throws uncaught R error**
Severity: BLOCKING
Violates engineering-preferences.md §4 ("Handle more edge cases, not fewer") and code-style.md §3
(every failure mode should surface as a `surveywts_*` class)

The NR algorithm calls `solve(hess, score)`. If the Hessian is singular or near-singular
(collinear covariates, constant covariate column in `data`, or all NPS units in one cell with
no reference analogs), `solve()` throws:
`Error in solve.default(hess, score): system is computationally singular`
This is a base R error with no `surveywts_*` class. It also shares a root cause with perfect
separation but produces a different symptom than `surveywts_error_propensity_scores_degenerate`.

The spec covers the _outcome_ of perfect separation (degenerate scores in step 11) but not the
_mechanism_ (singular Hessian during iteration). A non-converging or separated model may produce
a singular Hessian before scores are even computed.

Options:
- **[A]** Wrap `solve(hess, score)` in a `tryCatch()` and emit
  `surveywts_error_propensity_hessian_singular` with a message indicating collinear or
  degenerate covariates, and pointing the user to simplify `selection`. — Effort: low,
  Risk: low, Impact: replaces opaque crash with actionable error, Maintenance: none
- **[B]** Use `tryCatch()` and re-emit as the existing
  `surveywts_error_propensity_scores_degenerate` with an augmented message. — Effort: low,
  Risk: low, Impact: reuses existing class but conflates two distinct failure modes
- **[C] Do nothing** — users get a `solve.default` error with no indication of what failed.

**Recommendation: A** — New class is warranted; the failure mode is mechanistically distinct
from degenerate scores.

---

**Issue 3: Extreme-adjustment check formula inconsistent between §V and §VI**
Severity: BLOCKING
Direct spec contradiction; implementer cannot satisfy both sections simultaneously.

§V step 11 defines the trigger condition as:
> `max(weight_i / score_i) / mean(weight_i)` exceeds `control$max_adjust`

§VI test category 4 (warning paths for `adjust_nonresponse()`) defines the expected trigger as:
> `max(1 / score) / mean(1 / score)` exceeds `control$max_adjust`

These are different quantities. The §V formula compares the maximum adjusted weight
to the mean of the _original_ weights; the §VI formula compares the maximum score-inverse
to the mean score-inverse, ignoring original weights entirely. An implementer who uses §V's
formula will fail the §VI test and vice versa.

Options:
- **[A]** Standardize on `max(weight_i / score_i) / mean(weight_i)` (§V's formula). This
  is the more methodologically meaningful check: it detects when the propensity adjustment
  inflates any individual weight far above the sample average. Update §VI test category 4 to
  match. — Effort: low, Risk: low, Impact: resolves the contradiction, Maintenance: none
- **[B]** Standardize on `max(1 / score) / mean(1 / score)` (§VI's formula). This is purely
  a score-quality check, ignoring original weight variability. Update §V step 11 to match.
- **[C] Do nothing** — implementation will satisfy one section and silently fail the other.

**Recommendation: A** — The §V formula is more meaningful; the test is the derivative artifact
that should be updated.

---

**Issue 4: `svydesign` vs `survey_taylor` variable name used inconsistently in §III**
Severity: REQUIRED
Introduces implementer ambiguity about what R variable name to use in the function body.

The argument table names the parameter `survey_taylor`. But §III Behavior Rules and Output
Contract consistently refer to it as `svydesign`:
- Rule 2: "`svydesign` must satisfy `S7::S7_inherits(svydesign, surveycore::survey_taylor)`"
- Rule 6: "`.validate_formula_variables(selection, svydesign@data, 'svydesign')`"
- Output Contract: "`n_reference = nrow(svydesign@data)`"

An implementer writing `ipw()` must pick one name for the local variable. If they follow the
signature (`survey_taylor`), the Behavior Rules (written as `svydesign`) look wrong.

Options:
- **[A]** Standardize on `survey_taylor` throughout §III — update all Behavior Rules and
  the Output Contract to use `survey_taylor` as the variable name. — Effort: low, Risk: low
- **[B]** Standardize on `svydesign` throughout — change the argument name in the signature.
  (Less preferred: conflicts with the argument table, which correctly distinguishes the
  _argument name_ from the _class name_.)
- **[C] Do nothing** — implementer must mentally translate; error-prone for someone new to the codebase.

**Recommendation: A** — The argument name in the signature (`survey_taylor`) should be used
consistently throughout §III.

---

**Issue 5: `.trim_weights_internal()` return field for `n_trimmed` count not named**
Severity: REQUIRED
The implementer cannot write step 14 without knowing the return contract of `.trim_weights_internal()`.

§III Rule 14 says: "Use `$weights` from the result. Set `n_trimmed = sum(was_outside_upper)`
for the history entry." But `was_outside_upper` is not identified as a named field in the
result of `.trim_weights_internal()`. The spec only names `$weights`. The implementer does
not know whether to write `result$was_outside_upper`, `result$n_trimmed`, or compute it
another way.

The Utilities spec presumably defines the return contract, but this spec should cross-reference
it explicitly or restate the relevant fields.

Options:
- **[A]** Add a one-sentence cross-reference in step 14: "`.trim_weights_internal()` returns
  a list with `$weights` (trimmed weight vector) and `$n_trimmed` (count of trimmed values)
  per the Utilities spec; set `n_trimmed = result$n_trimmed`." — Effort: low, Risk: low
- **[B]** Keep current text but add a footnote pointing to the Utilities spec's return contract.
- **[C] Do nothing** — implementer guesses; may compute `n_trimmed` incorrectly.

**Recommendation: A** — One sentence eliminates the ambiguity entirely.

---

**Issue 6: `surveywts_warning_propensity_nr_no_convergence` has no test case**
Severity: REQUIRED
Violates testing-standards.md: "Every error class gets a test; every edge case in the spec gets a test."

The warning table lists `surveywts_warning_propensity_nr_no_convergence` but §VI warning paths
(category 4 for `ipw()`) only tests `surveywts_warning_extreme_propensity_scores`. There is no
test for triggering NR non-convergence.

A natural trigger: pass `maxit = 1L` with real data where one NR step is insufficient for
convergence.

Options:
- **[A]** Add to §VI category 4: "Pass `maxit = 1L` with data requiring more than one NR
  iteration → `surveywts_warning_propensity_nr_no_convergence`; result is still returned;
  `test_invariants()` passes." — Effort: low, Risk: low
- **[B]** Document a more controlled synthetic scenario designed to require many iterations.
- **[C] Do nothing** — warning is untested; could be silently broken.

**Recommendation: A** — `maxit = 1L` is a simple, reliable trigger.

---

**Issue 7: `surveywts_warning_propensity_glm_convergence` has no test case**
Severity: REQUIRED
Same as Issue 6 — warning in the table, no test in §VI.

§V specifies `surveywts_warning_propensity_glm_convergence` when `stats::glm()` emits
"algorithm did not converge", but §VI category 4 for `adjust_nonresponse()` warning paths
does not include a test for this warning.

Options:
- **[A]** Add to §VI category 4: "Construct a dataset with near-perfect separation or extreme
  weight/response combinations that causes `stats::glm()` non-convergence (pass
  `control$maxit = 1` via `glm.control`) → `surveywts_warning_propensity_glm_convergence`;
  result still returned." — Effort: low, Risk: low
- **[B]** Mark as "untestable in isolation; covered by glm.control maxit=1 in integration test."
- **[C] Do nothing** — warning untested.

**Recommendation: A** — Passing `control = glm.control(maxit = 1)` is a reliable, reproducible trigger.

---

**Issue 8: Wrong warning class cited in §VI edge case test for `adjust_nonresponse()`**
Severity: REQUIRED
Direct contradiction between §V and §VI.

§VI test category 5 (edge cases) states:
> "Very low response rate (20%): large adjustment factors; `surveywts_warning_class_near_empty` expected"

`surveywts_warning_class_near_empty` is the warning for `method = "weighting-class"` and
`method = "propensity-cell"`. §V step 11 explicitly establishes `surveywts_warning_extreme_propensity_adjustment`
as the replacement warning for `method = "propensity"`, with the note:
"(distinct from `surveywts_warning_class_near_empty`, which refers to discrete weighting classes)"

Options:
- **[A]** Change §VI category 5 to expect `surveywts_warning_extreme_propensity_adjustment`. — Effort: trivial
- **[C] Do nothing** — test will expect the wrong warning class and will fail.

**Recommendation: A** — Trivial fix.

---

**Issue 9: Zero or negative reference design weights — no validation**
Severity: REQUIRED
Violates engineering-preferences.md §4.

The pseudo-likelihood score and Hessian use reference design weights `d_ref` as multipliers.
If any `d_ref <= 0`, the weighted Hessian becomes non-negative-definite (or singular), and
the pseudo-likelihood no longer has a unique maximum. The spec validates that `data` is
non-empty and selection variables are non-NA, but does not validate that the reference design
weights are positive.

`survey_taylor` design objects from surveycore should enforce positive weights at construction,
but `ipw()` should not silently inherit a broken input.

Options:
- **[A]** Add a behavior rule: "Extract reference weights from `survey_taylor`; if
  `any(ref_weights <= 0)` → `surveywts_error_reference_weights_nonpositive`. Specify the
  new error class in §VIII." — Effort: low, Risk: low
- **[B]** Document as a precondition (not checked): "Reference design weights are assumed
  positive; `survey_taylor` construction guarantees this." — Effort: trivial, Risk: medium
  (relies on surveycore guarantee holding)
- **[C] Do nothing** — silent NR failure or invalid weights.

**Recommendation: A** — Defensive check costs nothing and produces a clear error message.

---

**Issue 10: `adjust_nonresponse(method = "propensity")` — all-respondents and all-nonrespondents
cases undefined**
Severity: REQUIRED
Violates engineering-preferences.md §4.

§V does not specify behavior when:
1. `sum(response_status == 0) == 0` — all units are respondents: the GLM outcome variable
   is constant (all 1s), which `stats::glm()` will refuse to fit or will produce boundary
   predictions. What should `adjust_nonresponse()` do?
2. `sum(response_status == 1) == 0` — no respondents: the GLM fits but returns zero rows
   in the output. Is this an error or a warning?

Options:
- **[A]** Specify explicit behavior for both cases:
  - All respondents: emit `surveywts_error_all_respondents` (or a warning + return input
    unchanged); specify the new class in §VIII.
  - No respondents: emit `surveywts_error_no_respondents` (already covered? check
    Nonresponse spec).
  The Nonresponse spec presumably addressed these for `weighting-class` — the propensity
  method spec should either reuse those classes or explicitly defer to them. — Effort: low
- **[B]** Explicitly document "same behavior as `method = 'weighting-class'` for all
  edge cases not mentioned here" and add a cross-reference. — Effort: low
- **[C] Do nothing** — users hit an opaque GLM error for degenerate response patterns.

**Recommendation: A** — Propensity method may produce different GLM errors than weighting-class;
be explicit.

---

**Issue 11: `test_invariants()` not specified for `weighted_df` and `survey_nonprob` happy
path blocks in `adjust_nonresponse()` tests**
Severity: REQUIRED
Violates testing-surveywts.md: "`test_invariants()` must be called as the first assertion in
every `test_that()` block that creates a `weighted_df` or `survey_nonprob` object."

§VI `adjust_nonresponse()` category 1 (happy path) specifies `test_invariants()` only for
the `data.frame` input block. The `weighted_df` input block (returns `weighted_df`) and the
`survey_nonprob` input block (returns `survey_nonprob`) both omit `test_invariants()`.

Options:
- **[A]** Add `test_invariants()` as the first assertion in the `weighted_df` happy path
  block and the `survey_nonprob` happy path block. — Effort: trivial
- **[C] Do nothing** — invariant checking is silently missing for two of four input classes.

**Recommendation: A** — Trivial; required by the testing standard.

---

**Issue 12: `wt_name = NA_character_` test case absent**
Severity: REQUIRED
The error table says `surveywts_error_wt_name_empty` is triggered by `wt_name = NA` or `""`.
§VI only tests `wt_name = ""`. The `NA_character_` case should be tested separately because
`NA_character_` passes `is.character()` and `length() == 1` checks but still represents an
empty/invalid name.

Options:
- **[A]** Add `wt_name = NA_character_` → `surveywts_error_wt_name_empty` to error path tests. — Effort: trivial
- **[C] Do nothing** — NA_character_ case is untested; could silently produce a column named NA.

**Recommendation: A** — One line in the test plan.

---

**Issue 13: GAP in §III console output — must be resolved before implementation begins**
Severity: REQUIRED
Already acknowledged as a GAP in §III and as a Quality Gate item.

The spec includes an unresolved note:
> "⚠️ GAP: The exact display format for `propensity_ipw` history entries in the print method
> has not been specified."

The quality gate says "GAP in §III console output section resolved before implementation begins."
This is a REQUIRED pre-implementation step that must be resolved in Stage 4 before
handing off to `/implementation-workflow`.

The resolution requires:
1. Defining the exact fields and format for the `propensity_ipw` history line (what `[...]`
   shows — which of `selection_formula`, `method`, `n_reference`, `estimated_population_size`
   appear, and how `N_hat` is formatted)
2. Determining whether `.format_history_step()` needs extension (and if so, what changes)
3. Specifying a print snapshot test for `survey_nonprob` after `ipw()`

Options:
- **[A]** Resolve the GAP in Stage 4: specify the exact history line format in the spec and
  add a print snapshot test to §VI. — Effort: low, Risk: low
- **[C] Do nothing** — implementer makes an undocumented formatting decision; print
  snapshot test cannot be written.

**Recommendation: A** — Required before handoff.

---

**Issue 14: `control$max_adjust` defaults and validation not specified**
Severity: REQUIRED
The spec references `control$max_adjust` (default 2.0) in §V step 11 but does not specify:
- Where this default is established (in `adjust_nonresponse()` control list parsing, or
  inherited from an existing default?)
- What happens if `control$max_adjust = NULL` — does it disable the check or error?
- What happens if `control$max_adjust <= 0` — is any positive value valid?

The Nonresponse spec presumably established `control$max_adjust = 2.0` as the default for
`weighting-class` and `propensity-cell`. The propensity branch inherits it, but the spec
should confirm this rather than leave it implicit.

Options:
- **[A]** Add one sentence to §V: "The `control$max_adjust` default of 2.0 is inherited
  from the existing `adjust_nonresponse()` control list; no new default is introduced.
  `control$max_adjust = NULL` disables the check (no warning emitted). Negative values
  are invalid and throw `surveywts_error_invalid_control` [or reuse an existing class]." — Effort: low
- **[B]** Add a cross-reference: "See Nonresponse spec §X for `control$max_adjust`
  specification; behavior unchanged for `method = 'propensity'`." — Effort: trivial
- **[C] Do nothing** — implementer guesses the behavior for NULL and invalid values.

**Recommendation: A** — Short, eliminates guessing.

---

#### Section: IV — `.fit_participation_propensity()`

No issues found beyond those covered in §III.

---

#### Section: V — `adjust_nonresponse(method = "propensity")`

Issues 3, 7, 8, 10, 11, 14 above. Additional:

---

#### Section: VI — Testing

Issues 6, 7, 8, 11, 12 above.

---

#### Section: III — Suggestions

---

**Issue 15: Argument name `survey_taylor` collides with the class name**
Severity: SUGGESTION

The parameter `survey_taylor` in `ipw(data, selection, survey_taylor, ...)` has the same
name as the class it must satisfy (`surveycore::survey_taylor`). This is unusual — when a
function has an argument named identically to a class, users and implementers may confuse the
class reference with the argument. Common alternatives: `reference`, `ref_design`,
`reference_design`.

Options:
- **[A]** Rename the argument to `reference` (short, clear, commonly used in NPS literature).
  Update §VIII `surveywts-conventions.md` argument order table.
- **[B]** Keep `survey_taylor` — the argument type is obvious from the name and it matches
  surveycore's class name, which may aid discoverability.
- **[C] Do nothing** — minor friction only; the spec has already committed to this name.

**Recommendation: B** — The collision is minor, and using the class name as the argument name
is a documented convention in some R ecosystems (e.g., `lm(formula = formula, ...)`). But
worth a deliberate decision before locking the API.

---

**Issue 16: History entry does not record post-trim estimated population size**
Severity: SUGGESTION

§III specifies `estimated_population_size = sum(w_before_trim)` (pre-trim). The Statistical
Notes correctly document that `N̂ = Σ w_i` is used for HT-type estimation. But after
`trim = TRUE`, the post-trim sum is different from the pre-trim sum and neither is recorded
in the history. A user who calls `ipw(trim = TRUE)` and then checks the history for `N_hat`
to use in HT estimation will get the pre-trim value — but their actual weights (the ones in
`@data`) sum to the post-trim value. This mismatch is silent.

Options:
- **[A]** Add `estimated_population_size_trimmed = sum(w_after_trim)` to the history entry
  when `trim = TRUE`; record it alongside `estimated_population_size` (the pre-trim value). — Effort: low
- **[B]** Add a `@note` to `ipw()` that `estimated_population_size` in the history is always
  the pre-trim sum; users must call `sum(result@data[[wt_name]])` for the post-trim value. — Effort: trivial
- **[C] Do nothing** — silent mismatch; the Statistical Notes section mentions unnormalized
  weights but doesn't address the trim case.

**Recommendation: B** — A documentation note is sufficient; adding a second history field
adds API surface for a narrow case.

---

**Issue 17: No print snapshot test for `survey_nonprob` result of `ipw()`**
Severity: SUGGESTION
(Contingent on Issue 13 resolution — cannot add snapshot until history format is resolved.)

Per testing-standards.md: "Print snapshot — `print()` output matches expected format (snapshot
test); required for every result class that has a `print()` method." `ipw()` returns a
`survey_nonprob`, which has a print method. After Issue 13 is resolved, a snapshot test
should be added to §VI.

Options:
- **[A]** After resolving Issue 13, add to §VI category 1: "print snapshot for `ipw()` result
  matches expected `survey_nonprob` format with `propensity_ipw` history line." — Effort: low
- **[C] Do nothing** — print output format is untested.

**Recommendation: A** — Required after Issue 13 is resolved.

---

**Issue 18: No test for `ipw()` with `maxit = 1L` confirming NR warning path**
Severity: SUGGESTION
(Related to Issue 6 — separately noting that `maxit = 1L` is a good edge case regardless.)

The spec's edge case list (§VI category 5) doesn't test the `maxit` parameter at all, only
verifying valid convergence. An `maxit = 1L` test with data requiring more iterations would
exercise the warning path and confirm that the function returns a valid (if untrustworthy)
result.

Options:
- **[A]** Add to §VI category 5: "maxit = 1L: NR non-convergence warning emitted; `test_invariants()`
  passes; all scores in (0, 1)." — Effort: trivial
- **[C] Do nothing** — edge case is covered implicitly only if Issue 6 is resolved.

**Recommendation: A** — Subsumed by Issue 6 resolution; can be combined.

---

## Pass 2: Bootstrap Compatibility Audit (2026-05-19)

Cross-checked §III Output Contract against `plans/spec-methodology-nps-bootstrap.md`
"Required `ipw()` history entry structure". The bootstrap reads this entry to re-run
propensity estimation in each draw (Level A) and to resample the reference survey (Level B).
The propensity spec history entry as currently written is incompatible with the bootstrap on
six points.

---

**Issue 19: `operation` name mismatch — bootstrap cannot find the history entry**
Severity: BLOCKING
Direct incompatibility between §III and `spec-methodology-nps-bootstrap.md`.

§III specifies `operation = "propensity_ipw"`. The bootstrap doc specifies
`operation = "ipw"`. The quasi-randomization bootstrap locates the relevant history entry by
searching `@metadata@weighting_history` for `operation == "ipw"`. With the current spec it
will find nothing and fall back to Level A or error with
`surveywts_error_qr_bootstrap_no_reference`.

Options:
- **[A]** Change §III to `operation = "ipw"` and update the quality gate, test category 6,
  and the `adjust_nonresponse()` history entry note to match. — Effort: low
- **[B]** Update the bootstrap doc to search for `"propensity_ipw"`. — Effort: low
- **[C] Do nothing** — bootstrap will silently fail to locate the history entry.

**Recommendation: A** — `"ipw"` is shorter and matches the function name; `"propensity_ipw"`
is redundant since `ipw()` is the only function that produces this entry.

---

**Issue 20: `formula` stored as deparsed string — bootstrap cannot re-run the model**
Severity: BLOCKING
The bootstrap must pass the original formula to `.fit_participation_propensity()` in each
draw. A deparsed character string is not a formula object and cannot be passed directly.

§III specifies `selection_formula = deparse(selection)` (a character scalar). The bootstrap
doc specifies `formula = <formula>` (an actual R formula object). Reconstructing a formula
from a deparsed string with `as.formula()` in the bootstrap loop is error-prone: it requires
re-evaluating the formula in the calling environment, which is not available during bootstrap
execution.

Options:
- **[A]** Change §III to store `formula = selection` (the unevaluated formula object) rather
  than `selection_formula = deparse(selection)`. The deparsed string is still useful for
  printing; if needed, it can be derived at print time from `deparse(entry$formula)`. Update
  §III Output Contract, test category 6 (history correctness), and the print format in §III
  Console Output. — Effort: low
- **[B]** Store both: `formula = selection` and `selection_formula = deparse(selection)`.
  — Effort: low, adds minor redundancy
- **[C] Do nothing** — bootstrap must call `as.formula(entry$selection_formula)` with
  environment management, which is fragile.

**Recommendation: A** — store the formula object; derive the display string from it.

---

**Issue 21: `reference_design` field missing — Level B bootstrap impossible**
Severity: BLOCKING
The most critical omission. Without the stored reference design, the bootstrap cannot
resample the reference probability sample in Level B draws, making it impossible to propagate
reference survey variance into the bootstrap estimate.

§III Output Contract does not include `reference_design`. The bootstrap doc specifies
`reference_design = <survey_taylor>`. The quasi-randomization bootstrap's automatic Level A/B
detection reads this field: if present, Level B is used; if absent, Level A is used (no
reference resampling). Without the field, Level B is permanently unavailable regardless of
what the user passes to `create_bootstrap_weights()`.

Options:
- **[A]** Add `reference_design = survey_taylor` to the §III Output Contract (store the
  full `survey_taylor` object in the history entry). Note in the spec that this may increase
  memory usage for large reference samples, but it is required for bootstrap variance to
  propagate reference survey uncertainty. — Effort: low
- **[B]** Do not store the design in the history; require the user to pass
  `reference_sample` explicitly to `create_bootstrap_weights()` for Level B. Document that
  Level B is not automatic without re-passing the reference. — Effort: low, but degrades UX
- **[C] Do nothing** — Level B bootstrap is impossible without user re-passing the reference
  every time; the history entry is not self-contained.

**Recommendation: A** — the bootstrap doc explicitly requires this field; storing the design
object makes the history entry self-contained for variance estimation.

---

**Issue 22: `estimator` field missing — bootstrap cannot reproduce weight formula**
Severity: REQUIRED
The bootstrap doc requires `estimator = "hajek"` or `"ht"` to know which formula to apply
when recomputing weights in each draw:
- Hájek: `w_i = (1 − π̂_i) / π̂_i`
- HT: `w_i = 1 / π̂_i`

§III specifies `w_i = 1 / scores` unconditionally (HT-type). The bootstrap doc treats the
estimator type as a recorded parameter. Even if `ipw()` always uses HT (as the spec implies),
the bootstrap doc anticipates future `estimator` argument support. If the field is absent,
the bootstrap must hard-code HT, making it brittle against any future Hájek addition.

Options:
- **[A]** Add `estimator = "ht"` to the §III Output Contract (hard-coded to `"ht"` since the
  spec implements only HT). When a `estimator` argument is added in a future phase, this field
  will reflect the user's choice. — Effort: trivial
- **[B]** Leave the field absent; document in the bootstrap spec that `"ht"` is assumed when
  the field is missing. — Effort: trivial, adds implicit contract
- **[C] Do nothing** — bootstrap hard-codes HT silently.

**Recommendation: A** — one field, trivial cost, makes the history entry self-describing.

---

**Issue 23: `trim` stores count (`n_trimmed`), not bounds — bootstrap cannot reproduce trimming**
Severity: REQUIRED
The bootstrap must reproduce the same trim operation in each draw. Knowing that 12 weights
were trimmed is not sufficient to reproduce trimming; knowing the bounds (`median + 5 * IQR`)
applied in the original call is.

§III specifies `n_trimmed = <integer>`. The bootstrap doc specifies
`trim = c(0.05, 0.95)` or `NULL`. (The bootstrap doc uses a different trim convention — quantile
bounds rather than the IQR-based approach — but the structural requirement is the same: store
the bounds, not the count.)

For `ipw()`, the trim bound is `median(w) + 5 * IQR(w)` — computed from the data, not a
fixed quantile. In each bootstrap draw, the weights will be different, so the bound must be
recomputed in each draw rather than replayed from the original. The stored value should
indicate whether trimming was applied (`trim = TRUE/FALSE` from the argument), not the
realized count or the exact bound.

Options:
- **[A]** Change the history entry to store `trim = <logical>` (the argument value, not the
  count). Keep `n_trimmed` as a separate diagnostic field alongside `trim`. The bootstrap
  uses `trim` to decide whether to call `.trim_weights_internal()` in each draw; the bound
  is recomputed each time from the draw's weights, matching the original function's behavior.
  — Effort: low
- **[B]** Store both `trim` (logical) and `n_trimmed` (count) — fully backward-compatible. — Effort: trivial
- **[C] Do nothing** — bootstrap cannot reproduce trimming from the count alone.

**Recommendation: A** — `trim` (logical) is the actionable field; `n_trimmed` is diagnostic
only and can be retained alongside it.

---

**Issue 24: `method` value naming inconsistency (`"logit"` vs `"logistic"`)**
Severity: REQUIRED
The propensity spec uses `"logit"`, `"probit"`, `"cloglog"` as the valid `method` argument
values (and what gets stored in the history). The bootstrap doc shows `method = "logistic"` as
the example value. The bootstrap reads `method` from the history entry to re-run
`.fit_participation_propensity()` with the same link function. If the bootstrap is written
expecting `"logistic"` and the entry stores `"logit"`, the bootstrap will silently use the
wrong link or error.

Options:
- **[A]** Update the bootstrap doc's required history entry example to use `"logit"` (matching
  the propensity spec). The propensity spec's value names are already decided; the bootstrap
  doc's example was written before the spec finalized them. — Effort: trivial
- **[B]** Change the propensity spec to use `"logistic"` as the method name (aligns with
  `stats::binomial(link = "logit")` argument naming where "logistic" is sometimes used).
  — Effort: low, but would require updating argument table, examples, tests
- **[C] Do nothing** — bootstrap example and spec use different names; implementer must guess.

**Recommendation: A** — the propensity spec is the authoritative source; update the bootstrap
doc example.

---

**Issue 25: `targets_from_reference` flag not addressed**
Severity: SUGGESTION
The bootstrap doc includes `targets_from_reference = FALSE` in the required `ipw()` history
entry. This flag indicates whether a subsequent `rake()` or `calibrate()` step derived its
targets from the reference survey (requiring re-estimation of targets in each Level B draw)
or from fixed population benchmarks. The propensity spec does not mention this field.

This is a forward-compatibility concern: the flag belongs in the `ipw()` history entry per
the bootstrap doc, but `ipw()` cannot know whether a subsequent `rake()`/`calibrate()` will
use its reference design as a target source. Per the bootstrap doc's Open Design Question Q3,
`rake()`/`calibrate()` would need to set this flag when called after `ipw()`.

Options:
- **[A]** Add a note in §III Output Contract: "The `targets_from_reference` flag (required by
  the quasi-randomization bootstrap, per `spec-methodology-nps-bootstrap.md`) will be set by
  a subsequent `rake()` or `calibrate()` call if targets are derived from the stored reference
  design. `ipw()` records `targets_from_reference = FALSE` as a default; downstream functions
  are responsible for updating it." — Effort: low
- **[B]** Defer entirely to the bootstrap and rake/calibrate specs. — Effort: trivial,
  leaves a gap for the implementer.
- **[C] Do nothing** — the bootstrap spec's Q3 is left unresolved.

**Recommendation: A** — document the default value and the responsibility boundary now rather
than leaving it for the bootstrap implementer to rediscover.

---

## Summary (Pass 1 + Pass 2)

| Severity | Count |
|---|---|
| BLOCKING | 6 (3 from Pass 1 + 3 from Pass 2) |
| REQUIRED | 14 (11 from Pass 1 + 3 from Pass 2) |
| SUGGESTION | 6 (5 from Pass 1 + 1 from Pass 2) |

**Total issues:** 26

**Overall assessment:** The spec is structurally sound — the pseudo-likelihood algorithm is
correctly specified, the DRY decision is well-reasoned, and the error taxonomy is nearly
complete. However, the Pass 2 audit reveals that the `ipw()` history entry is incompatible
with the quasi-randomization bootstrap on three blocking points: the `operation` string will
not match, the formula is stored as a string instead of an object, and the reference design
is not stored at all (making Level B bootstrap impossible). These must be resolved before
implementation begins, along with the three blocking issues from Pass 1.

---

## Spec Review: propensity — Pass 3 (2026-05-19)

### Prior Issues (Pass 1 + Pass 2)

| # | Title | Status |
|---|---|---|
| 1 | Factor level mismatch — uncaught crash | ✅ Resolved |
| 2 | Singular Hessian — uncaught R error | ✅ Resolved |
| 3 | Extreme-adjustment formula inconsistency §V vs §VI | ✅ Resolved |
| 4 | `svydesign` vs `survey_taylor` variable name | ✅ Resolved |
| 5 | `.trim_weights_internal()` return field not named | ⚠️ Still open — resolution added `$n_trimmed` but function returns `$has_trimmed` |
| 6 | `surveywts_warning_propensity_nr_no_convergence` untested | ✅ Resolved |
| 7 | `surveywts_warning_propensity_glm_convergence` untested | ✅ Resolved (but see new Issue 33) |
| 8 | Wrong warning class in §VI edge case | ✅ Resolved |
| 9 | Reference design weights — no validation | ✅ Resolved |
| 10 | All-respondents / all-nonrespondents undefined | ✅ Resolved |
| 11 | `test_invariants()` missing for weighted_df and survey_nonprob blocks | ✅ Resolved |
| 12 | `wt_name = NA_character_` test case absent | ✅ Resolved |
| 13 | GAP in §III console output | ✅ Resolved |
| 14 | `control$max_adjust` defaults and validation unspecified | ✅ Resolved |
| 15 | Argument name `survey_taylor` collides with class name | ✅ Resolved |
| 16 | Post-trim population size not noted | ✅ Resolved |
| 17 | No print snapshot test | ✅ Resolved |
| 18 | No `maxit = 1L` edge case test | ✅ Resolved |
| 19 | `operation = "propensity_ipw"` vs `"ipw"` | ⚠️ Still open — Output Contract fixed; paragraph at line 381–382 still says `"propensity_ipw"` |
| 20 | Formula stored as deparsed string | ✅ Resolved |
| 21 | `reference_design` field missing | ✅ Resolved |
| 22 | `estimator` field missing | ✅ Resolved |
| 23 | `trim` stores count not bounds | ✅ Resolved |
| 24 | `method` naming inconsistency with bootstrap doc | ✅ Resolved |
| 25 | `targets_from_reference` flag unaddressed | ✅ Resolved |

### New Issues

#### Section: III — `ipw()` Behavior Rules

---

**Issue 26: `.validate_formula_variables()` always throws `surveywts_error_formula_variable_not_found`; Behavior Rule 7 requires a different class**
Severity: BLOCKING
Direct conflict between the spec's required error class and the existing helper's hard-coded class.

Behavior Rule 6 correctly uses `.validate_formula_variables(selection, data, "data")` to throw
`surveywts_error_formula_variable_not_found`. Behavior Rule 7 says to call
`.validate_formula_variables(selection, reference@data, "reference")` to throw the distinct class
`surveywts_error_formula_variable_not_in_reference`.

The actual implementation of `.validate_formula_variables()` in `R/utils.R` hard-codes
`class = "surveywts_error_formula_variable_not_found"` regardless of which `design_label` argument
is passed. Calling it with `"reference"` will still throw `surveywts_error_formula_variable_not_found`,
not the required `surveywts_error_formula_variable_not_in_reference`. The implementer has no way
to satisfy Rule 7 using the existing helper.

Options:
- **[A]** Add an optional `error_class = NULL` parameter to `.validate_formula_variables()`. When
  `NULL`, the function uses `"surveywts_error_formula_variable_not_found"` (backward-compatible).
  When a string is supplied, it uses that class. Rule 7 calls:
  `.validate_formula_variables(selection, reference@data, "reference", error_class = "surveywts_error_formula_variable_not_in_reference")`.
  — Effort: low, Risk: low, Impact: satisfies Rule 7 without duplication, Maintenance: none
- **[B]** Perform the reference validation inline in `ipw()` rather than delegating to the shared
  helper. Write the variable-not-found check directly with `cli::cli_abort(class = "surveywts_error_formula_variable_not_in_reference")`.
  — Effort: low, Risk: low, Impact: avoids modifying the shared helper, Maintenance: slightly DRY violation
- **[C] Do nothing** — Rule 7 is impossible to satisfy with the current helper; the reference
  validation will always throw the wrong error class.

**Recommendation: A** — Extending the helper maintains DRY; the parameter has a sensible default so existing callers are unaffected. Update §VIII to note that `.validate_formula_variables()` gains an `error_class` parameter.

---

**Issue 27: `.trim_weights_internal()` return field mismatch — spec says `$n_trimmed`, function returns `$has_trimmed`**
Severity: BLOCKING
Issue 5 from Pass 1 was "resolved" by adding text to Rule 16 stating that `.trim_weights_internal()`
returns `$n_trimmed`. This is factually incorrect.

Rule 16 now reads: "`.trim_weights_internal()` returns a list with `$weights` (trimmed weight vector)
and `$n_trimmed` (count of trimmed values) per the Utilities spec; set `n_trimmed = result$n_trimmed`."

The actual implementation in `R/utils.R` returns `list(weights = ..., has_trimmed = ...)`. The
`has_trimmed` field is a logical vector (TRUE for each weight that was trimmed), not an integer count.
`result$n_trimmed` evaluates to NULL. The correct expression to derive the count is
`sum(result$has_trimmed)`.

The Utilities spec (`plans/spec-utilities.md`) also confirms the return is `list(weights, has_trimmed)`.
The "resolution" of Issue 5 introduced a new factual error.

Options:
- **[A]** Correct Rule 16: replace "and `$n_trimmed` (count of trimmed values); set `n_trimmed =
  result$n_trimmed`" with "and `$has_trimmed` (logical vector; TRUE for each trimmed weight) per the
  Utilities spec; set `n_trimmed = sum(result$has_trimmed)`." — Effort: trivial, Risk: low
- **[B]** Add `n_trimmed` to the `.trim_weights_internal()` return (modify Utilities). — Effort: low
  but touches a shipped helper; requires Utilities PR
- **[C] Do nothing** — `n_trimmed` will silently be NULL in every history entry when `trim = TRUE`.

**Recommendation: A** — Correcting the spec text costs nothing. Adding a field to a shipped helper
to fix a spec error is over-engineering.

---

**Issue 28: Console Output section has three consistency errors**
Severity: REQUIRED
(Related to still-open Issue 19 and new formatting inconsistencies)

Three distinct errors in §III Console Output:

**(a)** The paragraph immediately following the first code block (lines ~381–382) reads:
> "The new `operation = "propensity_ipw"` entry renders via the same mechanism as other history
> entries."

This is a stale remnant from before Issue 19 was resolved. The Output Contract now correctly
specifies `operation = "ipw"`. The Console Output paragraph must be updated to match.

**(b)** The first code block (lines ~374–378) shows the history line as:
```
#   1  ipw  [logit, n_ref=1000, N_hat=148392]
```
The format description below it and the second code block both show the formula as the first
bracketed field:
```
#   1  ipw  [~ age_grp + sex, logit, n_ref=1000, N_hat=148392]
```
The first example is missing `deparse(formula)`. The snapshot test will use the wrong expected format.

**(c)** The overall print header shown (`# A <survey_nonprob>`, `# Weights: ... ESS = ... CV = ...`)
does not match what the current `methods-print.R` actually produces (`# A calibrated survey design:
N observations, M variables`, `# IDs: ... | Strata: ... | Weights: ...`). If the print method is
genuinely unchanged, the Console Output example should be corrected to show the actual output.

Options:
- **[A]** Fix all three: (a) replace `"propensity_ipw"` with `"ipw"` in the paragraph; (b) add
  `~ age_grp + sex` to the first code block; (c) update the header lines in both example blocks
  to match what `methods-print.R` actually produces. — Effort: low
- **[C] Do nothing** — the snapshot test specified in §VI will capture the wrong expected output;
  an implementer reading the Console Output section gets three contradictory signals.

**Recommendation: A** — All three are editorial corrections; none require architectural decisions.

---

#### Section: III — `ipw()` Weight Formula

---

**Issue 29: `.format_history_step()` has no `"ipw"` branch — default produces wrong format**
Severity: BLOCKING
The spec says the history line format is `ipw  [~ formula, logit, n_ref=N, N_hat=M]` but the
existing helper will produce `ipw` (just the operation name).

`R/utils.R`'s `.format_history_step()` is a `switch()` on `entry$operation`. The `"ipw"` operation
is not in the switch. The default case returns the operation name as the label: `op`. The full line
would then be:
```
#   Step 1 [2026-05-19]: ipw
```
This omits the formula, method, n_ref, and N_hat fields specified in the Console Output section, and
also uses the `"Step N [date]:"` prefix (which differs from the `"N  operation  [...]"` prefix shown
in the spec). The print snapshot test in §VI cannot pass without this branch.

The spec says "No new print method is required" and "renders via the existing `.format_history_step()`
helper" — but it does not say whether the helper itself needs extension. Given the switch structure,
it must be extended.

Options:
- **[A]** Add an `"ipw"` case to the `switch()` in `.format_history_step()`. The case reads
  `entry$formula` (deparse it), `entry$method`, `entry$n_reference`, and `entry$estimated_population_size`
  to build the bracketed display string. Clarify in the spec that `.format_history_step()` must be
  extended for this operation. — Effort: low, Risk: low
- **[B]** Change to a generic fallback that reads from a `display_fields` element of the history
  entry, avoiding any future switch extension. — Effort: medium, Impact: broader change
- **[C] Do nothing** — the print snapshot test will fail; the history output is wrong.

**Recommendation: A** — One switch case is the minimal targeted fix; the spec should state it explicitly.

---

#### Section: III — Behavior Rules

---

**Issue 30: `maxit = 0L` produces no warning and silently wrong output**
Severity: REQUIRED
With `maxit = 0L`, `seq_len(0L)` produces an empty integer vector. The `for` loop body never
executes. `gamma` stays at `rep(0, ncol(X_nps))`. For the logit link, all NPS propensity scores
are exactly `0.5`, all IPW weights are `2`. No convergence warning is emitted because
`if (iter == maxit)` is never evaluated.

This is silent wrong behavior: the user gets valid-looking weights (all equal to 2) with no indication
that the model was never fit. The `maxit = 1L` test in §VI (Issue 6 resolution) does not cover `maxit = 0L`.

Options:
- **[A]** Add a validation rule before the NR loop: "If `maxit < 1L` →
  `surveywts_error_propensity_invalid_maxit` (new class)." — Effort: low, Risk: low
- **[B]** Emit `surveywts_warning_propensity_nr_no_convergence` with `iterations = 0` and
  `max_delta = Inf` before computing scores when `maxit == 0L`. — Effort: low, less clean
- **[C] Do nothing** — users passing `maxit = 0L` get uniform weights of 2 with no diagnostic.

**Recommendation: A** — Validation is cleaner than a special-case warning. Add
`surveywts_error_propensity_invalid_maxit` to §VIII and the error table.

---

#### Section: VI — Testing

---

**Issue 31: `surveywts_warning_propensity_glm_convergence` test specifies `control = list(maxit = 1)` which has no effect**
Severity: REQUIRED
§VI warning path 4 for `adjust_nonresponse()` states: "Construct a dataset with near-perfect
separation **or pass `control = list(maxit = 1)`** to trigger `stats::glm()` non-convergence."

But §V step 6 hard-codes the GLM's convergence control:
```r
control = stats::glm.control(maxit = 25, epsilon = 1e-8)
```
`adjust_nonresponse(control = list(maxit = 1))` would not affect this — `control$maxit` in the
`adjust_nonresponse()` control list has no defined effect on the GLM's `glm.control`. Passing
`control = list(maxit = 1)` would either be silently ignored or interpreted as `n_cells = ...`.
The GLM would still run up to 25 iterations.

The only reliable way to trigger non-convergence is the dataset approach (near-perfect separation).

Options:
- **[A]** Remove the `control = list(maxit = 1)` option from the test description; leave only
  "Construct a dataset with near-perfect separation." Add a concrete data-construction hint:
  create a binary covariate where all nonrespondents have value = 1 and all respondents have
  value = 0 (perfect separation). — Effort: low
- **[B]** Explicitly allow the GLM maxit to be set via `adjust_nonresponse(control = ...)` by
  forwarding `control$glm_maxit` to `glm.control(maxit = ...)` in §V step 6. This adds a new
  control key and requires §VIII update. — Effort: medium, significant scope expansion
- **[C] Do nothing** — the `control = list(maxit = 1)` test approach will never trigger the warning.

**Recommendation: A** — The dataset approach is the correct test method; remove the misleading
control parameter reference.

---

#### Section: All

---

**Issue 32: `epsilon` argument not validated**
Severity: SUGGESTION
If `epsilon <= 0`, the convergence criterion `max(abs(delta)) < epsilon` is never satisfied (since
`max(abs(delta)) >= 0` always), so Newton-Raphson always runs to `maxit` and emits
`surveywts_warning_propensity_nr_no_convergence`. The user gets a warning with no indication that
their `epsilon` argument was the cause. A negative `epsilon` is almost certainly a user error.

Options:
- **[A]** Add a validation rule: "If `epsilon <= 0` → `surveywts_error_propensity_invalid_epsilon`
  (new class)." — Effort: low
- **[B]** Add a note to `@param epsilon` that epsilon must be positive; no runtime check. — Effort: trivial
- **[C] Do nothing** — users with `epsilon = -1` get a confusing non-convergence warning.

**Recommendation: B** — A `@param` note is proportionate; a hard error is defensible but the
scenario is narrow. If A is chosen for Issue 30 (`maxit`), consistency argues for A here too.

---

## Summary (Pass 3)

| Severity | Count |
|---|---|
| BLOCKING | 3 |
| REQUIRED | 3 |
| SUGGESTION | 1 |

**Total new issues:** 7

**Overall assessment:** The spec successfully resolved all 25 prior issues except two that remain partially
open (Issues 5 and 19). Pass 3 found three blockers that stem from mismatches between the spec's
description of existing internal APIs and their actual implementation: `.validate_formula_variables()`
cannot produce the required error class for reference validation; `.trim_weights_internal()` returns
`$has_trimmed` not `$n_trimmed`; and `.format_history_step()` has no `"ipw"` branch and will
produce the wrong output format. These three are straightforward low-effort fixes. The remaining
required issues (Console Output consistency, `maxit = 0L` silent behavior, and an invalid test
approach for GLM convergence) are also low-effort corrections. None require architectural changes.
