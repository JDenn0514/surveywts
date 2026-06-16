## Spec Review: calibrate-surveycore — Pass 1 (2026-06-04)

_Prior issues: none (Pass 1)._

---

### New Issues

#### Section: `@calibration` list contract

**Issue 1: `@calibration$method` valid values are inconsistent across spec, function section, and test-spec**
Severity: BLOCKING
Violates Lens 3 — Contract Completeness

The `@calibration` list contract (§ "`@calibration` list contract") defines `method` as:
> `method: One of "linear", "raking", "poststrat"`

The `calibrate_greg()` function section states:
> "`method = model` (mapped: 'linear' stays 'linear', 'logit' maps to 'linear' — both are GREG; store the actual model value)"

These two sentences contradict each other: "logit maps to linear" implies storing `"linear"`, but "store the actual model value" implies storing `"logit"`.

The test-spec resolves this differently again. CS-12 states:
> `caldata$method %in% c("linear", "logit", "raking", "poststrat")`

So the test-spec allows `"logit"` as a fourth valid value. The spec contract does not. The builder cannot determine what to store for `calibrate_greg(model = "logit")` without guessing. If surveycore expects three values and receives `"logit"`, downstream variance estimation will silently use the wrong code path (or error).

Options:
- **[A]** Update the `@calibration` contract to define four valid method values: `"linear"`, `"logit"`, `"raking"`, `"poststrat"`. Store the actual `model` argument value. Document the surveycore interpretation: `"linear"` and `"logit"` both select the GREG variance formula; surveycore distinguishes them only if it needs to interpret the distance function (which it does not for variance). Effort: low, Risk: low, Impact: removes ambiguity.
- **[B]** Map logit to `"linear"` in the stored value so the contract has three values. Remove the contradictory "store the actual model value" phrase. Add a note: `"logit"` is treated as `"linear"` for provenance purposes. Effort: low, Risk: low (but requires updating test-spec CS-12 to remove `"logit"`).
- **[C] Do nothing** — builder guesses; 50% chance of a cross-package contract mismatch.

**Recommendation: A** — The test-spec has already committed to four values. Updating the contract to match is the smaller change; removing `"logit"` from the test-spec would require verifying surveycore behavior independently.

---

#### Section: `calibrate_greg()` — When `data` is `survey_replicate`

**Issue 2: Step 4 (direct full-sample weight write) is redundant with `.update_survey_weights()` and its role is not stated**
Severity: REQUIRED
Violates Lens 5 — Engineering Level (DRY / clarity)

The replicate path for `calibrate_greg()` lists:
> "4. Write the calibrated full-sample weights to `design@data[[design@variables$weights]] <- new_weights`."
> "5. Call `.update_survey_weights(design, new_weights, history_entry, caldata = caldata)`."

The `.update_survey_weights()` contract states that its step 1 is:
> "Update `design@data[[weight_col]]` with `new_weights_vec`"

Step 4 and the first action of step 5 write the identical value to the identical slot. The redundancy is benign for correctness, but creates risk: a builder may read step 4, conclude that `.update_survey_weights()` is not needed for the weight-write, and omit step 5 (losing the history append and `@calibration` assignment). Alternatively, they may wonder why step 4 exists and whether it's serving a different purpose.

Options:
- **[A]** Remove step 4 entirely. The full-sample weight is written by `.update_survey_weights()` in step 5. Add a clarifying note: "Replicate columns are written in step 3e before calling `.update_survey_weights()`; `.update_survey_weights()` writes the full-sample column, appends history, and sets `@calibration`." Effort: trivial, Risk: none.
- **[B]** Keep step 4 and add an inline comment: "Explicit write for clarity; `.update_survey_weights()` in step 5 also writes this column." Effort: trivial, Risk: none (but still redundant).
- **[C] Do nothing** — redundancy stays and may confuse the builder.

**Recommendation: A** — Remove the redundant step; the responsibility table in `.update_survey_weights()` already documents all three operations that happen in step 5.

---

#### Section: Test-spec — `calibrate_greg()` and cross-cutting tests

**Issue 3: "NC" identifier prefix used twice — test IDs are ambiguous**
Severity: REQUIRED
Violates Lens 2 — Test Completeness (mechanic rules)

The test-spec uses `NC-1`, `NC-2`, `NC-3` twice:
- First occurrence: under `calibrate_greg()` → "Numerical correctness" (oracle against `survey` package)
- Second occurrence: under "No `@calibration` for data.frame / weighted_df outputs"

When the tester runs the suite and a test fails, the failure report references `NC-1` and the tester cannot tell which block failed. The duplicate prefix also makes cross-references in the review ambiguous.

Options:
- **[A]** Rename the second set to `DF-1`, `DF-2`, `DF-3` (for "data-frame"). Update any prose references. Effort: trivial, Risk: none.
- **[B] Do nothing** — identifier collision persists; tester uses surrounding context to disambiguate.

**Recommendation: A** — Unambiguous test IDs are a minimum requirement for a test spec.

---

**Issue 4: Eleven error classes from spec error tables have no test in the test-spec**
Severity: REQUIRED
Violates Lens 2 — Test Completeness (every error class must have a test)

The following error classes appear in the spec's error tables but are not covered by any scenario in the test-spec:

For `calibrate_greg()` (and rake by extension):
| Missing class | Spec trigger |
|---|---|
| `surveywts_error_weights_not_found` | Named weight column missing |
| `surveywts_error_weights_not_numeric` | Weight column is not numeric |
| `surveywts_error_wt_name_not_scalar` | `wt_name` is not `character(1)` |
| `surveywts_error_wt_name_empty` | `wt_name` is `NA` or `""` |
| `surveywts_error_variable_has_na` | A calibration variable has `NA` values |
| `surveywts_error_margins_format_invalid` | `targets` is not a valid named list or long data frame |

For `calibrate_poststrat()`:
| Missing class | Spec trigger |
|---|---|
| `surveywts_error_no_strata_variables` | `targets` has zero non-`"target"` columns |
| `surveywts_error_population_cell_duplicate` | A cell combination appears > once in `targets` |
| `surveywts_error_population_cell_missing` | A data cell has no row in `targets` |
| `surveywts_error_population_cell_not_in_data` | A `targets` cell has no observations in data |
| `surveywts_error_empty_stratum` | A stratum cell has zero weighted count (full-sample) |

Per `testing-standards.md §2`: "every typed error class from the package's error table" must have a test block.

Options:
- **[A]** Add a test block for each missing error class. Use the dual pattern: `expect_error(class = ...)` + `expect_snapshot(error = TRUE)`. Group them in the relevant function's "Error paths" table. Effort: medium (11 new blocks), Risk: none, Impact: full error coverage per standards.
- **[B] Do nothing** — 11 error paths go untested; CI coverage target may still pass but corner-case regressions will be silent.

**Recommendation: A** — These are straightforward input-validation errors; each is a one-liner to trigger.

---

**Issue 5: `surveywts_warning_control_param_ignored` has no test in the test-spec**
Severity: REQUIRED
Violates Lens 2 — Test Completeness

`surveywts_warning_control_param_ignored` appears in the `calibrate_greg()` and `calibrate_rake()` warning tables in the spec. The test-spec has no warning path block for this class.

Per `testing-standards.md §2`, every warning class must have a test. The `error-messages.md` entry describes the trigger: "An unrecognized key in `control`" (for `calibrate_greg()`), or an inapplicable parameter for a given algorithm (for `calibrate_rake()`).

Options:
- **[A]** Add a warning path block for each function: pass an unrecognized `control` key (e.g., `control = list(unknown_param = TRUE)`) and assert `expect_warning(class = "surveywts_warning_control_param_ignored")`. Effort: low, Risk: none.
- **[B] Do nothing** — warning path goes untested.

**Recommendation: A** — One test block per function; low effort.

---

#### Section: `.build_calibration_provenance()` function contract

**Issue 6: Return value description is contradictory**
Severity: REQUIRED
Violates Lens 3 — Contract Completeness

The `.build_calibration_provenance()` section contains:

> "**Returns**: `invisible(TRUE)` — never. Returns the list visibly so the caller can assign it."

The phrase "Returns: `invisible(TRUE)` — never" is parsed as: "the return value is `invisible(TRUE)`." The "— never" modifier is meant to negate this, but the negation is grammatically incoherent — a function cannot return something it "never" returns. A builder reading this in isolation will not know whether the function returns `invisible(TRUE)` or a list.

The "never" is presumably a copy-paste artifact from the internal validator convention docs, where validators return `invisible(TRUE)` and this function explicitly does not. But that intent is not clear to a reader who hasn't internalized the validator convention.

Options:
- **[A]** Replace the entire sentence with: "**Returns**: A named list conforming to the `@calibration` contract. Returned visibly (not `invisible()`) so the caller can assign the result directly." Effort: trivial, Risk: none.
- **[B] Do nothing** — contradiction stays; builder may guess wrong.

**Recommendation: A** — A two-sentence rewrite eliminates the ambiguity.

---

**Issue 7: `n_iterations` behavior for logit GREG is unspecified and untested**
Severity: REQUIRED
Violates Lens 3 (contract gap) + Lens 2 (test gap)

The spec states:
> "For linear GREG: `1L`. ... When `engine_result$convergence$iterations` is `NA_integer_` (logit/ipf paths in `.calibrate_engine()`), store `NA_integer_`."

The spec does not state what `.calibrate_engine()` actually returns for the `$convergence$iterations` field when called via `calibrate_greg(model = "logit")`. Two possibilities exist:
1. The engine returns a real integer count (number of Newton steps), in which case `n_iterations` would be `as.integer(actual_count)`.
2. The engine returns `NA_integer_` for the logit/ipf path.

The spec says "logit/ipf paths" store `NA_integer_`, but does not confirm whether `calibrate_greg(model = "logit")` actually triggers the logit/ipf path vs. the Newton path in the engine. The test-spec has HT-13 for linear (`n_iterations = 1L`) but no test for `model = "logit"`. A builder who implements this correctly but misreads which engine path logit uses will produce the wrong value silently.

Options:
- **[A]** Add a sentence to the contract: "For `calibrate_greg(model = 'logit')`, `.calibrate_engine()` uses the Newton-Raphson path with bounded distance function; `engine_result$convergence$iterations` returns the actual Newton iteration count as an integer. Store `as.integer(engine_result$convergence$iterations)`." Add a test in the test-spec: `calibrate_greg(taylor_design, targets, model = "logit")` → verify `is.integer(caldata$n_iterations) && caldata$n_iterations >= 1L`. Effort: low, Risk: low.
- **[B]** Add just the test (no spec change) to verify the current behavior. If it reveals the behavior, the spec can be updated later.
- **[C] Do nothing** — logit `n_iterations` goes unverified.

**Recommendation: A** — Explicitly state the engine behavior so the builder and tester are aligned on the same expectation.

---

#### Section: Test-spec — `calibrate_rake()` and `calibrate_poststrat()`

**Issue 8: Oracle numerical correctness tests for raking and post-stratification are implicit, not explicit**
Severity: SUGGESTION
Violates Lens 2 — Test Completeness (conditional: numerical correctness)

The `calibrate_rake()` happy path for `survey_taylor` (RT-1 through RT-9) has no numerical correctness table comparing output weights against `survey::rake()` at tolerance 1e-8. The test-spec says for the replicate path: "Same structure as `calibrate_greg()` replicate happy path (HR-1 through HR-9), with `calibrate_rake()` substituted" — but does not include a raking oracle comparison.

Similarly, `calibrate_poststrat()` has no numerical correctness table against `survey::postStratify()`.

`calibrate_greg()` has NC-1 through NC-3 (explicit oracle comparisons). The raking and post-stratification oracle comparisons are at least as important because these functions compute weights via different algorithms.

Options:
- **[A]** Add an explicit "Numerical correctness" table for both `calibrate_rake()` and `calibrate_poststrat()`, mirroring the NC-1/NC-2/NC-3 structure from `calibrate_greg()`. Include `skip_if_not_installed("survey")` inside each block. Effort: low, Risk: none.
- **[B] Do nothing** — rely on the implicit inheritance from the greg reference.

**Recommendation: A** — Raking and post-stratification have different internal algorithms; oracle comparisons are not redundant with GREG oracle comparisons.

---

**Issue 9: `calibrate_greg(model = "logit")` happy path is untested**
Severity: SUGGESTION
Violates Lens 2 — Test Completeness (input class dispatch)

The `calibrate_greg()` happy path tests (HT-1 through HT-16) all use the default `model = "linear"`. The logit model path uses a different distance function and algorithm in `.calibrate_engine()`. No happy-path block tests `model = "logit"` with a `survey_taylor` input. The logit path first appears in the error section (convergence failure), but correct behavior is never verified.

Options:
- **[A]** Add one happy-path block: `calibrate_greg(taylor_design, targets, model = "logit")` — verify output class is `survey_taylor`, `@calibration` is populated, `caldata$method` is the correct value (resolves with Issue 1), and calibrated weights satisfy the constraint within 1e-6. Effort: low, Risk: none.
- **[B] Do nothing** — logit happy path goes uncovered.

**Recommendation: A** — This is a separate code path in the engine; one block is sufficient.

---

**Issue 10: Mixed calibrated/uncalibrated replication risk is not surfaced in the spec**
Severity: SUGGESTION
Violates Lens 6 — API Coherence

When some replicates fail calibration (`replicate_converged` has `FALSE` entries), the output `survey_replicate` contains a mix: calibrated full-sample weights, calibrated successful replicate weights, and uncalibrated (original) failed replicate weights. A user who then runs variance estimation on this object will silently get a biased variance estimate — no error is thrown, and the only signal is the `surveywts_warning_replicate_calibration_failed` that was emitted earlier.

The spec does not mention this risk in the output description, quality gates, or edge case documentation. A methodologist using the package would expect either (a) all replicates are calibrated or (b) the function errors. The "partial calibration" outcome is a real scenario but is not called out as a caveat.

Options:
- **[A]** Add to the `survey_replicate` output description: "When some replicates fail (see `$replicate_converged`), the returned object has uncalibrated weights for those replicates. Variance estimates from this object will mix calibrated and uncalibrated replicate draws; users should inspect `output@calibration$replicate_converged` before computing variance estimates." Effort: low, Risk: none.
- **[B]** Add a quality gate: "If `any(!caldata$replicate_converged)`, a summary note (not a warning) is printed to the console after calibration completes listing how many replicates were uncalibrated."
- **[C] Do nothing** — risk is implicit in the warning messages.

**Recommendation: A** — Add the caveat to the output description. No code change needed; this is purely documentation.

---

**Issue 11: `discrepancy` field semantics could be mistaken for post-calibration residuals**
Severity: SUGGESTION
Violates Lens 3 — Contract Completeness (edge case: name vs. semantics)

The `@calibration` contract defines `discrepancy` as:
> "`population_totals` minus HT estimate at starting weights. Stored for diagnostics."

The name "discrepancy" is ambiguous: in calibration literature, "discrepancy" can refer to the post-calibration residual (how well constraints are met). This field stores the pre-calibration deficit — how far the sample was from the population totals before weighting. After calibration, the discrepancy should be near zero (the constraint is satisfied). A surveycore developer implementing variance routines may mistake this for the post-calibration residual and produce an incorrect estimator.

Options:
- **[A]** Rename the field to `pre_cal_deficit` and update the contract, function specs, and test-spec. Effort: medium (rename throughout), Risk: low.
- **[B]** Keep the name but add a clarifying note to the contract table: "Pre-calibration HT deficit. This is NOT the post-calibration residual (which approaches zero after convergence). Used for diagnostics and lambda computation." Effort: trivial, Risk: none.
- **[C] Do nothing** — field name stays ambiguous.

**Recommendation: B** — Adding a clarifying note costs nothing and prevents a subtle implementation error in surveycore.

---

### Section: `.check_input_class()` / regression tests

No new issues. REG-2 correctly verifies the regression: `survey_replicate` is accepted without `surveywts_error_replicate_not_supported`. The error class remains in `error-messages.md` for other functions, per spec.

---

### Section: Quality gates

No new issues. Gates 1–8 are complete and verifiable. Gate 7 (calibration constraint) uses `control$epsilon` tolerance (1e-7 default), consistent with the tolerances table in the test-spec (1e-6 for constraint checks).

---

### Section: `calibrate()` dispatcher

No issues. The dispatcher tests D-1 through D-3 cover all three method values for `survey_replicate` input. This is sufficient.

---

## Summary (Pass 1)

| Severity | Count |
|---|---|
| BLOCKING | 1 |
| REQUIRED | 6 |
| SUGGESTION | 4 |

**Total issues:** 11

**Overall assessment:** The spec is well-structured and methodologically sound (Stage 2 is PASS). One blocking ambiguity — the `@calibration$method` field for logit GREG — must be resolved before the builder commits to any implementation, as it is a cross-package contract field. The six required issues are primarily test coverage gaps (11 error classes missing, one warning class missing, logit `n_iterations` unspecified) and two spec text clarity problems. All are low-effort fixes. The four suggestions are quality improvements that don't block implementation but would improve the delivered artifact. With the one blocking issue and required fixes applied, this spec is implementable.
