# Spec Review: calibration-fixes

## Spec Review: calibration-fixes --- Pass 1 (2026-03-17)

### New Issues

#### Section: II. Change 1 --- Replace Vendored Algorithms with Package Calls

**Issue 1: `survey::rake()` convergence detection is unspecified for the IPF path**
Severity: BLOCKING
Violates contract completeness (Lens 3) and engineering-preferences.md SS4

The spec specifies convergence handling for four of the five delegation paths:
- Linear: no check (closed-form) --- correct
- Logit: intercept `survey::calibrate()` warning, re-throw as typed error --- correct
- Anesrake: check `$converge` flag --- correct
- Poststratify: not iterative, no check --- correct
- **IPF (`survey::rake()`): not specified**

The current vendored `.ipf_calibrate()` returns `converged = FALSE` which
`.calibrate_engine()` checks and throws `surveywts_error_calibration_not_converged`.
After delegation to `survey::rake()`, this check disappears. `survey::rake()` may
issue a warning on non-convergence (it calls `grake()` internally), or it may
silently return last-iteration weights. The spec must specify how surveywts detects
and reports non-convergence from `survey::rake()`.

Options:
- **[A]** Intercept `survey::rake()` non-convergence warning via
  `withCallingHandlers()`, suppress it, and re-throw as
  `surveywts_error_calibration_not_converged` --- consistent with the logit path.
  --- Effort: low, Risk: low, Impact: correct non-convergence reporting,
  Maintenance: low
- **[B]** Perform a post-hoc marginal check: after `survey::rake()` completes,
  verify weighted marginals match population margins within `epsilon`. If not,
  throw the convergence error. --- Effort: medium, Risk: low, Impact: definitive
  check, Maintenance: low
- **[C] Do nothing** --- Non-convergence in the IPF path is silently swallowed;
  the user receives uncalibrated or partially calibrated weights without an error.

**Recommendation: [A]** --- Consistent with the logit path and lowest effort.
If `survey::rake()` uses a different warning mechanism, [B] provides a
fallback.

---

**Issue 2: Minimum version pins not specified for `survey` and `anesrake`**
Severity: REQUIRED
Violates `r-package-conventions.md SS3`: "Specify lower bounds for all Imports
dependencies. Set the bound to the oldest version where the required feature
exists."

The spec says to move `survey` and `anesrake` from `Suggests` to `Imports`
but does not specify minimum version bounds. The current DESCRIPTION has
`survey (>= 4.2-1)` in Suggests. The Imports entry needs an explicit minimum
version for both packages.

Options:
- **[A]** Specify minimum versions: `survey (>= 4.2-1)` (already in Suggests)
  and `anesrake (>= 0.80)` (or whatever version supports the `$converge` return
  field). --- Effort: trivial, Risk: none, Impact: correct DESCRIPTION,
  Maintenance: none
- **[B] Do nothing** --- DESCRIPTION has unpinned Imports, which is fragile
  and violates conventions.

**Recommendation: [A]**

---

**Issue 3: `anesrake::anesrake()` caseid column construction not specified**
Severity: REQUIRED
Violates contract completeness (Lens 3)

The spec shows `data_df_with_id` and `id_col` in the anesrake interface
example but does not specify where they come from. `anesrake::anesrake()`
requires a `caseid` column in the input data frame. The current vendored
`.anesrake_calibrate()` handles id creation internally. After delegation, the
engine must construct this id column from the input data.

The spec should state: (a) whether to look for an existing id column or always
create a synthetic one, and (b) the creation pattern (e.g.,
`seq_len(nrow(data_df))`).

Options:
- **[A]** Add to the spec: "Create a synthetic integer id column:
  `data_df_with_id <- data_df; data_df_with_id$.anesrake_id <- seq_len(nrow(data_df))`
  and `id_col <- \".anesrake_id\"`. Remove after raking." --- Effort: trivial,
  Risk: none, Impact: unambiguous implementation, Maintenance: none
- **[B] Do nothing** --- Implementer guesses whether to find or create an id.

**Recommendation: [A]**

---

**Issue 4: Test plan missing for convergence detection paths**
Severity: REQUIRED
Violates test completeness (Lens 2, error paths)

The testing implications for Change 1 mention integration tests for
delegation round-trips and removing vendored-internal unit tests. They do not
specify tests for:

1. Logit non-convergence: verify `withCallingHandlers()` intercepts the
   `survey::calibrate()` warning and throws
   `surveywts_error_calibration_not_converged`
2. Anesrake non-convergence: verify `$converge == FALSE` throws the error
3. Anesrake already-calibrated: verify `$iterations == 0` emits
   `surveywts_message_already_calibrated`
4. IPF non-convergence (once Issue 1 is resolved): verify the chosen detection
   mechanism works

These are error-path tests that map directly to error-table entries.

Options:
- **[A]** Add explicit test items for each convergence path. --- Effort: low,
  Risk: none, Impact: complete error coverage, Maintenance: none
- **[B] Do nothing** --- Convergence error paths are untested.

**Recommendation: [A]**

---

**Issue 5: `surveywts_warning_cap_post_hoc` needs `plans/error-messages.md` entry**
Severity: REQUIRED
Violates `code-style.md SS3`: "When adding a new error or warning: 1. Add a
row to `plans/error-messages.md` first."

The spec defines `surveywts_warning_cap_post_hoc` in the Change 1 warning
table (conditional on GAP resolution). If option (a) is chosen in Stage 4,
this class needs to be added to `plans/error-messages.md`. The spec should
note this as a pending addition.

Options:
- **[A]** Add a note in the spec: "If GAP is resolved as option (a), add
  `surveywts_warning_cap_post_hoc` to `plans/error-messages.md` before
  implementation." --- Effort: trivial, Risk: none, Impact: process compliance,
  Maintenance: none
- **[B] Do nothing** --- The class exists in the spec but not the error table;
  implementation may forget to add it.

**Recommendation: [A]**

---

#### Section: III. Change 2 --- `adjust_nonresponse()`: Zero Weights

**Issue 6: S7 validator conflict --- `survey_nonprob` rejects zero weights**
Severity: BLOCKING
Violates contract completeness (Lens 3) and API coherence (Lens 6)

The `survey_nonprob` S7 validator enforces 5 conditions, including:
> 4. All values are strictly positive (> 0)

(Documented in `surveywts-conventions.md` and `testing-surveywts.md`.)

Change 2 sets nonrespondent weights to 0. When the input is a `survey_nonprob`
object, Step 16 calls `.update_survey_weights(data, new_weights, history_entry)`,
which sets `@data[[weight_col]] <- new_weights`. In S7, property assignment
via `@<-` re-triggers the class validator. The validator will reject the object
because some weights are 0.

This is an architectural conflict: the spec's new behavior (zero weights for
design preservation) directly violates the class invariant (all weights positive).

The spec discusses `.validate_weights()` handling zeros (the GAP in SS III) but
does not address the S7 class validator, which is a separate mechanism.

Options:
- **[A]** Relax the `survey_nonprob` validator: change condition 4 from
  "all positive (> 0)" to "all non-negative (>= 0), at least one positive."
  This weakens the class contract. `.validate_weights()` stays strict for
  calibration entry points (rejects zero weights before calibrating). The
  validator allows post-nonresponse objects. --- Effort: low, Risk: medium
  (class contract change ripples to surveycore), Impact: resolves conflict,
  Maintenance: must update surveycore validator + all validator tests
- **[B]** Return `weighted_df` instead of `survey_nonprob` when nonresponse
  adjustment zeros weights. This preserves the strict validator but loses the
  survey design structure (PSUs, strata, FPC) --- contradicting the stated
  motivation of Change 2. --- Effort: low, Risk: high (defeats purpose of
  the change), Impact: preserves validator, Maintenance: none
- **[C]** Add a separate `@nonresponse_mask` logical vector property to
  `survey_nonprob` instead of zeroing weights. Keep all weights positive;
  downstream functions check the mask. --- Effort: high, Risk: low (no
  validator change), Impact: clean separation of concerns, Maintenance:
  every downstream function must check the mask
- **[D] Do nothing** --- `.update_survey_weights()` throws an S7 validation
  error at runtime; `adjust_nonresponse()` is broken for survey object inputs.

**Recommendation: [A]** --- The validator should reflect the reality that
post-nonresponse survey objects have zero-weight units. The distinction between
"zero weights are invalid at construction" and "zero weights are valid after
nonresponse adjustment" can be enforced by `.validate_weights()` at calibration
entry points, not by the class validator.

---

**Issue 7: Test plan missing for survey object path (Step 16 changes)**
Severity: REQUIRED
Violates test completeness (Lens 2, input class dispatch)

The testing implications for Change 2 mention:
- Updating `nrow(result) == nrow(input)` tests
- Adding zero-weight tests
- Adding diagnostics tests on post-nonresponse data
- Adding re-calibration error tests

They do not mention testing the **survey object path** separately. Step 16 has
different code for data.frame/weighted_df vs. survey objects. After the change,
the survey path no longer filters `@data` --- this needs its own test block
verifying that the survey object retains all rows, nonrespondent weights are 0,
and the design structure (`@variables`, `@metadata`) is preserved.

Options:
- **[A]** Add explicit test items: "Happy path for `survey_nonprob` input:
  verify `nrow(@data)` unchanged, nonrespondent weights == 0, respondent
  weights adjusted, `@variables` and `@metadata` preserved." --- Effort:
  trivial, Risk: none, Impact: complete class coverage, Maintenance: none
- **[B] Do nothing** --- Survey object behavior is untested; bugs in the
  survey path go undetected.

**Recommendation: [A]**

---

#### Section: IV. Change 3 --- `.check_input_class()` Universal `survey_base` Check

**Issue 8: `.diag_validate_input()` error message update not specified**
Severity: REQUIRED
Violates contract completeness (Lens 3)

The spec mentions updating `.diag_validate_input()` to use `survey_base` and
shows the one-line check:

```r
is_supported <- is.data.frame(x) ||
  S7::S7_inherits(x, surveycore::survey_base)
```

But it does not specify updating the **error message text** in
`.diag_validate_input()`. The current error message likely lists specific
classes (e.g., "`data.frame`, `survey_taylor`, or `survey_nonprob`"). After
the change, it should reference `survey_base` for consistency with
`.check_input_class()`.

Options:
- **[A]** Add to the spec: "Update `.diag_validate_input()` error message to
  match `.check_input_class()`: reference `survey_base` instead of listing
  specific classes." --- Effort: trivial, Risk: none, Impact: consistent
  messaging, Maintenance: none
- **[B] Do nothing** --- Error messages in the two validation functions diverge.

**Recommendation: [A]**

---

#### Section: VI. Change 5 --- Remove `%||%` Redefinition

**Issue 9: `%||%` usage sites not enumerated**
Severity: SUGGESTION

The spec says "there are only a handful of `%||%` uses" but does not list them.
An implementer must search the codebase. Enumerating the call sites (at least
the count and files) would reduce implementation ambiguity.

Options:
- **[A]** Add a list of files and approximate count of `%||%` usage sites.
  --- Effort: trivial, Risk: none, Impact: implementation clarity,
  Maintenance: none
- **[B] Do nothing** --- Implementer searches; no functional risk.

**Recommendation: [A]** --- Low effort for reduced ambiguity.

---

#### Section: VII. Change 6 --- Fix `interaction()` in `summarize_weights()`

**Issue 10: Scope of change is larger than section title suggests**
Severity: SUGGESTION

The section title says "Fix `interaction()` in `summarize_weights()`" but the
replacement code block is a full rewrite of the grouped summarization path:
`paste()` + `split()` + `lapply()` + `dplyr::bind_cols()` +
`dplyr::bind_rows()`. This replaces both the grouping mechanism AND the
per-group computation structure.

The current implementation (from the codebase) uses `interaction()` for
grouping and then presumably iterates over groups. The replacement changes the
entire iteration pattern.

Options:
- **[A]** Rename the section to "Rewrite grouped path in `summarize_weights()`"
  and note that the scope includes both the separator fix and the iteration
  pattern. --- Effort: trivial, Risk: none, Impact: accurate scoping,
  Maintenance: none
- **[B] Do nothing** --- Implementation proceeds correctly regardless of the
  title.

**Recommendation: [A]**

---

#### Section: VIII. Change 7 --- `response_status` -> `tidyselect::eval_select()`

**Issue 11: Error class semantic mismatch for multi-column selection**
Severity: SUGGESTION

The spec reuses `surveywts_error_response_status_not_found` for the condition
"selects zero or multiple columns." For the zero-selection case, "not found"
is accurate. For the 2+ selection case, "not found" is misleading --- the
columns were found, there are just too many.

The spec explicitly notes this reuse: "The existing
`surveywts_error_response_status_not_found` is reused." This is a deliberate
choice to avoid adding a new error class for an edge case.

Options:
- **[A]** Accept the reuse. The error message text ("must select exactly one
  column") is clear even if the class name is imprecise. --- Effort: none,
  Risk: none, Impact: none, Maintenance: none
- **[B]** Add a new error class `surveywts_error_response_status_multi_select`
  for the 2+ case. --- Effort: low, Risk: none, Impact: precise error typing,
  Maintenance: one more class to maintain
- **[C]** Rename to `surveywts_error_response_status_invalid_selection` to
  cover both 0 and 2+ cases. --- Effort: low, Risk: low (breaks any existing
  tests checking the old class), Impact: accurate naming, Maintenance: must
  update error table + tests

**Recommendation: [A]** --- The mismatch is minor and the message text is
clear. Adding a class for this edge case is over-engineering.

---

#### Section: XII. Quality Gates

No new issues found. The quality gates are comprehensive and match the
deliverables.

---

#### Section: XIII. GAP Summary

No new issues found. The two GAPs are correctly marked as requiring resolution
before implementation. The methodology review addressed the *content* of the
recommended options; the GAPs themselves will be resolved in Stage 4.

---

#### Section: Cross-cutting --- Testing (Lens 2 Mechanics)

**Issue 12: `test_invariants()` conflict with zero weights for `survey_nonprob`**
Severity: REQUIRED
Violates `testing-surveywts.md`: `test_invariants()` checks
`all(obj@data[[obj@variables$weights]] > 0)` for `survey_nonprob`

This is a downstream consequence of Issue 6. If the S7 validator is relaxed to
allow zero weights (Issue 6, option A), `test_invariants()` must also be
updated. The spec should note this.

Additionally, `test_invariants()` is called "as the first assertion in every
constructor test block." After Change 2, post-nonresponse `survey_nonprob`
objects will have zero weights. Tests for `adjust_nonresponse()` with
`survey_nonprob` input would fail `test_invariants()` unless it's updated.

Options:
- **[A]** Note in the spec that `test_invariants()` for `survey_nonprob` must
  be relaxed to `all(w >= 0) && any(w > 0)` (or `test_invariants()` should
  accept a `allow_zero = FALSE` parameter). --- Effort: low, Risk: none,
  Impact: tests pass, Maintenance: none
- **[B] Do nothing** --- Every post-nonresponse survey_nonprob test will fail
  at the invariant check.

**Recommendation: [A]** --- Follows from Issue 6 resolution.

---

### Summary (Pass 1)

| Severity | Count |
|---|---|
| BLOCKING | 2 |
| REQUIRED | 6 |
| SUGGESTION | 4 |

**Total issues:** 12

**Overall assessment:** The spec is well-structured and the methodology review
resolved all statistical concerns cleanly. Two blocking issues require
resolution before implementation: (1) `survey::rake()` convergence detection
is unspecified for the IPF delegation path, leaving implementers to guess; and
(2) the `survey_nonprob` S7 validator enforces all-positive weights, which
directly conflicts with Change 2's zero-weight nonrespondent behavior --- this
is an architectural issue that ripples into the class contract, test
invariants, and surveycore's validator. The six required issues are
straightforward (version pins, caseid construction, test plan gaps, error
message consistency) and can be resolved with small spec additions. The four
suggestions are quality improvements that won't block implementation.
