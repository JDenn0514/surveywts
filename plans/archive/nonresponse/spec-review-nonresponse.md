## Spec Review: nonresponse — Pass 3 (2026-05-13)

### Prior Issues (Pass 2)

| # | Title | Status |
|---|---|---|
| 1 | `.validate_formula()` absent from §II shared helpers table | ✅ Resolved |
| 16 | `bounds` argument omitted from Behavior Rule 5 in §III and §IV | ✅ Resolved |
| 17 | Missing test for `surveywts_warning_negative_calibrated_weights` in `calibrate_to_survey()` | ✅ Resolved |
| 18 | Missing test for `surveywts_warning_negative_calibrated_weights` in `calibrate_to_estimate()` | ✅ Resolved |
| 19 | `surveywts_error_weights_na` and `surveywts_error_wt_name_empty` missing from `redistribute_weights()` test plan | ✅ Resolved |
| 20 | `redistribute_weights()` `control` defaults merging unspecified | ✅ Resolved |

---

### New Issues

#### Section: II — Architecture

**Issue 21: `.compute_model_matrix_totals()` is a phantom function**
Severity: REQUIRED
Violates: Lens 3 — contract completeness; Lens 5 — under-engineered

§II Source File Map lists `utils.R ← EXTEND: + .compute_model_matrix_totals(), + .validate_formula_variables()`. But `.compute_model_matrix_totals()` has no entry in §VII Shared Helpers and is not referenced in any behavior rule for any function. It does not appear anywhere else in the spec.

Since `svrep::calibrate_to_sample()` and `svrep::calibrate_to_estimate()` compute model matrix totals internally, this helper is likely a leftover from an earlier draft when totals were going to be computed manually. An implementer reading the file map would try to implement a function with no spec, no signature, no documented callers, and no tests.

Options:
- **[A]** Remove `.compute_model_matrix_totals()` from the §II file map. — Effort: trivial, Risk: none, Impact: eliminates phantom spec artifact, Maintenance: none
- **[B]** Document it in §VII with a signature and "Used by" column if it turns out to be needed. — Effort: low, Risk: low, Impact: completes the spec, Maintenance: none
- **[C] Do nothing** — Implementer can recognize the orphan and skip it.

**Recommendation: A** — If `svrep` handles totals internally (which §IV BR 5 confirms: "perturbation… is handled entirely by `svrep`"), the helper is not needed. Remove it from the map to avoid a dead-end for the implementer.

---

#### Section: V — `redistribute_weights()`

**Issue 22: "Zero-weight rows in `increase_if`" edge case cannot be triggered**
Severity: SUGGESTION
Violates: Lens 4 — edge cases; Lens 2 — test completeness

§VIII lists "Zero-weight rows in `increase_if`" as an edge case for `redistribute_weights()`. But `redistribute_weights()` inherits `surveywts_error_weights_nonpositive`, which fires before any redistribution logic runs. Zero-weight rows in `increase_if` would be caught at input validation — not at the redistribution step. The edge case is therefore either:
(a) Testing the weight validator (not redistribution behavior), or
(b) Implying that `weights_nonpositive` does not cover zero — but looking at the error table it says "non-positive values," which includes zero.

The edge case cannot test anything about the redistribution logic; it already tests `surveywts_error_weights_nonpositive`, which is covered by the error paths.

Options:
- **[A]** Remove "Zero-weight rows in `increase_if`" from edge cases (the scenario is caught earlier and already covered by the error path test). — Effort: trivial, Risk: none, Impact: spec accuracy, Maintenance: none
- **[B]** Clarify the edge case: "Zero-weight rows in `increase_if` → caught by `surveywts_error_weights_nonpositive` (before redistribution logic runs)." — Effort: trivial, Risk: none, Impact: makes the intent clear, Maintenance: none
- **[C] Do nothing** — Implementer will notice the validator fires and write a validator test, which is harmless.

**Recommendation: B** — A one-clause clarification converts the misleading edge case into an accurate test spec.

---

#### Section: VI — `adjust_nonresponse()` Propensity-Cell

**Issue 23: `surveywts_warning_class_near_empty` not tested for propensity-cell**
Severity: SUGGESTION
Violates: testing-standards.md §2 — "every row in the warning table covered by a test"

§VI Algorithm step 5 states: "Sparse/extreme-adjustment warning fires under same conditions as weighting-class." But `surveywts_warning_class_near_empty` does not appear in the §VI Warning Table (labeled "New Warnings Only," so its absence there is intentional) and is not mentioned in the §VIII test categories for propensity-cell. The edge case "Very high propensity concentration (all scores near 0 or 1)" is present but does not explicitly assert that the sparse-cell warning fires.

Since the warning fires from propensity-cell just like from weighting-class, it should be tested — the cell structure is different (propensity quintiles instead of user-defined groups) and the same code path may not be exercised.

Options:
- **[A]** Add to §VIII propensity-cell edge cases: "`control$n_cells` with one cell containing few respondents → `surveywts_warning_class_near_empty`." — Effort: low, Risk: none, Impact: closes warning coverage gap, Maintenance: none
- **[B] Do nothing** — The warning is exercised by the weighting-class tests; coverage of the shared code path is sufficient.

**Recommendation: A** — The propensity-cell redistribution is a distinct code path from weighting-class (cells are assigned by `findInterval()` rather than user-specified `by`). A test specific to propensity-cell ensures the warning plumbing is wired correctly there too.

---

**Issue 24: History entry records `by_variables` for propensity-cell when `by` is ignored**
Severity: SUGGESTION
Violates: Lens 6 — API coherence; "methodologically correct but confusing"

§VI specifies the propensity-cell history entry as: `operation = "nonresponse_propensity_cell"`, parameters include `formula` (as character), `n_cells`, `by_variables`. But §VI Behavior Notes says `by` is ignored when `method = "propensity-cell"` — the `by_variables` recorded in history would always be `NULL` (or the user's ignored value, which is even more misleading).

Recording an ignored argument in the weighting history gives users a false impression that `by` was used in the propensity-cell computation.

Options:
- **[A]** Remove `by_variables` from the propensity-cell history entry parameters (since `by` is not used in this method). — Effort: trivial, Risk: none, Impact: history accurately reflects what happened, Maintenance: none
- **[B]** Record `by_variables = NULL` explicitly to show it was not used. — Effort: trivial, Risk: low, Impact: honest but adds noise, Maintenance: none
- **[C] Do nothing** — The warning covers user confusion; history is an internal detail.

**Recommendation: A** — A history entry should record the parameters that drove the computation. `by_variables` drove nothing here; omitting it is more honest than recording `NULL`.

---

## Summary (Pass 3)

| Severity | Count |
|---|---|
| BLOCKING | 0 |
| REQUIRED | 1 (Issue 21) |
| SUGGESTION | 3 (Issues 22–24) |

**Total new issues:** 4 (1 required, 3 suggestions)

**Overall assessment:** All six Pass 2 issues are resolved — the spec is now in excellent shape. The one required issue (phantom `.compute_model_matrix_totals()` function in the file map) is a trivial deletion. The three suggestions are minor polish: one edge case clarification, one missing warning test, and one history-entry accuracy fix. No structural changes needed; the spec is ready for Stage 4 resolution.

---

## Spec Review: nonresponse — Pass 2 (2026-05-12)

### Prior Issues (Pass 1)

| # | Title | Status |
|---|---|---|
| 1 | `.validate_formula()` absent from §II shared helpers table | ⚠️ Still open |
| 2 | Weight total alignment with control not in output contract | ✅ Resolved |
| 3 | Missing test — `surveywts_warning_replicate_scheme_mismatch` | ✅ Resolved |
| 4 | Logit method bounds not documented | ✅ Resolved |
| 5 | `estimate` NA values not in error table or behavior rules | ✅ Resolved |
| 6 | Missing tests — formula error paths for `calibrate_to_estimate()` | ✅ Resolved |
| 7 | `calibrate_to_estimate()` argument order — formula after estimate/vcov | ✅ Resolved |
| 8 | `wt_name` column collision behavior unspecified | ✅ Resolved |
| 9 | Missing tests — `reduce_if`/`increase_if` NA error paths | ✅ Resolved |
| 10 | Missing tests — standard weight validation errors for `redistribute_weights()` | ✅ Resolved |
| 11 | DRY — `.validate_formula_variables()` not reused for propensity-cell | ✅ Resolved |
| 12 | `surveywts_error_formula_invalid` missing from propensity-cell path | ✅ Resolved |
| 13 | No-respondents-in-propensity-cell not in error table or behavior rules | ✅ Resolved |
| 14 | Wrong test file name — `test-nonresponse.R` vs. `test-05-nonresponse.R` | ✅ Resolved |
| 15 | Dual test pattern not called out in test plans | ✅ Resolved |

---

### New Issues

#### Section: III — `calibrate_to_survey()` / IV — `calibrate_to_estimate()`

**Issue 16: `bounds` argument omitted from Behavior Rule 5 in §III and §IV**
Severity: REQUIRED
Violates: Lens 3 — contract completeness; inconsistency between argument table and behavior rules

§III Behavior Rule 5 specifies exactly what is passed to `svrep::calibrate_to_sample()`:
"`primary_rep_design`, `control_rep_design`, `cal_formula = formula`, `calfun` derived from
`method`, and `maxit`/`epsilon` from `control`." The `bounds` argument is not listed.

§IV Behavior Rule 5 has the same omission: `rep_design`, `estimate`, `vcov_estimate`,
`cal_formula = formula`, `calfun`, `maxit`/`epsilon` — no `bounds`.

Both argument tables say "Weight bounds passed to svrep," but the behavior rules — which are
the authoritative specification of what the implementation calls — omit `bounds`. An implementer
following the behavior rule literally would not pass `bounds` to svrep, silently ignoring the
user's bound specification.

Options:
- **[A]** Add `bounds` to both behavior rules: "...`maxit`/`epsilon` from `control`, and
  `bounds` (the lower/upper list) passed as appropriate to svrep." — Effort: trivial, Risk: none,
  Impact: consistent spec, Maintenance: none
- **[B] Do nothing** — argument table says "passed to svrep"; implementer will figure it out.

**Recommendation: A** — The behavior rule is the spec of record for what the function calls.
Omitting `bounds` from it creates a concrete implementation gap.

---

**Issue 17: Missing test for `surveywts_warning_negative_calibrated_weights` in `calibrate_to_survey()`**
Severity: REQUIRED
Violates: testing-standards.md §2 — "every row in the warning table covered by a test"

§III warning table lists `surveywts_warning_negative_calibrated_weights | Full-sample linear
calibration produced negative weights`. §VIII "Warning paths" for `calibrate_to_survey()` covers
only `surveywts_warning_replicate_scheme_mismatch`. There is no test block specifying that
`method = "linear"` with control totals that produce negative weights triggers the warning.
The edge case "Method `'linear'`" is listed but does not specify checking for the warning.

Options:
- **[A]** Add to §VIII warning paths for `calibrate_to_survey()`: "Linear calibration that
  produces negative full-sample weights → `surveywts_warning_negative_calibrated_weights`;
  calibration result still returned." — Effort: low, Risk: none, Impact: closes warning coverage
  gap, Maintenance: none
- **[B] Do nothing** — The edge case "Method `'linear'`" implicitly covers this.

**Recommendation: A** — Edge case tests do not substitute for warning tests; the warning must be
explicitly asserted with `expect_warning(class = ...)`.

---

**Issue 18: Missing test for `surveywts_warning_negative_calibrated_weights` in `calibrate_to_estimate()`**
Severity: REQUIRED
Violates: testing-standards.md §2 — "every row in the warning table covered by a test"

§IV warning table lists `surveywts_warning_negative_calibrated_weights`. §VIII test categories
for `calibrate_to_estimate()` have no "Warning paths" section at all. The edge case
"Method `'linear'`" is present but contains no warning assertion.

Options:
- **[A]** Add a "Warning paths" section to §VIII for `calibrate_to_estimate()`: "Linear
  calibration producing negative full-sample weights → `surveywts_warning_negative_calibrated_weights`."
  — Effort: low, Risk: none, Impact: closes warning coverage gap, Maintenance: none
- **[B] Do nothing** — Warning is "reuse existing class"; indirect coverage from `calibrate_to_survey()` test is sufficient.

**Recommendation: A** — `calibrate_to_estimate()` is a different code path from `calibrate_to_survey()`;
the warning check must be independently tested there.

---

#### Section: V — `redistribute_weights()`

**Issue 19: `surveywts_error_weights_na` and `surveywts_error_wt_name_empty` missing from test plan**
Severity: REQUIRED
Violates: testing-standards.md §2 — "every row in the error table covered by a test"

§V error table includes both `surveywts_error_weights_na` (weight column has NA) and
`surveywts_error_wt_name_empty` (`wt_name` is NA or `""`). Neither appears in §VIII error
paths for `redistribute_weights()`. The test plan lists six weight/wt_name errors but misses
these two.

Options:
- **[A]** Add to §VIII error paths for `redistribute_weights()`:
  - "Weight column has NA → `surveywts_error_weights_na`"
  - "`wt_name` is NA or `''` → `surveywts_error_wt_name_empty`"
  — Effort: trivial, Risk: none, Impact: closes two error coverage gaps, Maintenance: none
- **[B] Do nothing** — These validators are inherited from existing code; indirect coverage is sufficient.

**Recommendation: A** — `redistribute_weights()` is a new call site; each validator must be explicitly
invoked and tested there.

---

**Issue 20: `redistribute_weights()` `control` defaults merging unspecified**
Severity: SUGGESTION
Violates: Lens 3 — contract completeness; internal consistency with calibration functions

§III and §IV both say `control` is "merged with defaults" (e.g., `list(maxit = 50, epsilon = 1e-7)`).
§V describes `redistribute_weights()` with `control = list()` as the default, and the argument
table says `min_cell` defaults to 20 and `max_adjust` defaults to 2.0 — but never states these
are merged with defaults. An implementer reading §V in isolation must guess the merging mechanism.

Options:
- **[A]** Add to the `control` argument description: "Merged with defaults `list(min_cell = 20,
  max_adjust = 2.0)`." — Effort: trivial, Risk: none, Impact: consistent with calibration function
  pattern, Maintenance: none
- **[B] Do nothing** — The defaults are named inline; implementer can infer merging is needed.

**Recommendation: A** — Consistent with the `control` pattern across the spec; one clause.

---

#### Section: II — Architecture

**Issue 1 (still open): `.validate_formula()` absent from §II shared helpers table**
Severity: SUGGESTION
*(Unchanged from Pass 1 — §II table still lists only `.to_svyrep_design()` and
`.validate_formula_variables()`. `.validate_formula()` is defined in §VII and used by three
functions but has no row in the §II file map.)*

---

## Summary (Pass 2)

| Severity | Count |
|---|---|
| BLOCKING | 0 |
| REQUIRED | 4 (Issues 16–19) |
| SUGGESTION | 2 (Issues 1, 20) |

**Total new issues:** 6 (4 required, 2 suggestions)

**Overall assessment:** 14 of 15 Pass 1 issues resolved — the spec is now in strong shape.
Four required issues remain: `bounds` missing from both Behavior Rule 5 specifications (silent
silent ignore at implementation time), and three missing warning/error tests (`negative_calibrated_weights`
for both calibration functions; `weights_na` + `wt_name_empty` for `redistribute_weights()`).
None require structural changes — all are targeted additions to existing spec sections. The spec
is implementable with only minor clarifications needed.

---

## Spec Review: nonresponse — Pass 1 (2026-05-12)

### New Issues

#### Section: II — Architecture

**Issue 1: `.validate_formula()` absent from §II shared helpers table**
Severity: SUGGESTION
Violates: internal consistency — §II and §VII disagree

§II's "New Shared Helpers in `R/utils.R`" table lists `.to_svyrep_design()` and
`.validate_formula_variables()`, but §VII defines a third helper, `.validate_formula()`,
with no corresponding row in §II. An implementer reading §II would not know this helper
needs to go in `utils.R`.

Options:
- **[A]** Add `.validate_formula()` to the §II shared helpers table. — Effort: low, Risk: low, Impact: spec consistency, Maintenance: none
- **[B] Do nothing** — §VII defines it; implementer reads both sections.

**Recommendation: A** — §II is the canonical file map; all new helpers in utils.R should appear there.

---

#### Section: III — `calibrate_to_survey()`

**Issue 2: Weight total alignment with control not in output contract**
Severity: SUGGESTION
Violates: Lens 6 — API coherence; "technically correct but will cause user error" if not prominently stated

§VIII numerical correctness notes that calibrated weights sum to the control total (not
the original primary total): "Weight totals conserve to the control survey: `sum(w_new) ≈
sum(control_design@data[[...]])`, not `sum(w_original)`". This is non-obvious behavior —
users commonly expect weight totals to be preserved. It appears only in the test section,
not in the §III Output Contract or Behavior Rules.

Options:
- **[A]** Add one sentence to the §III Output Contract explicitly stating that the
  intercept constraint forces total alignment with the control survey's weight sum, not
  the primary design's. — Effort: low, Risk: low, Impact: eliminates silent confusion, Maintenance: none
- **[B] Do nothing** — The test section documents it implicitly; the behavior follows from
  calibration theory.

**Recommendation: A** — Calibration collapsing the primary survey's total is surprising
enough to warrant a sentence in the contract.

**Issue 3: Missing test — `surveywts_warning_replicate_scheme_mismatch`**
Severity: REQUIRED
Violates: testing-standards.md §2 — "Every row in the warning table covered by a test"

The §III warning table lists `surveywts_warning_replicate_scheme_mismatch`, but §VIII's
test categories for `calibrate_to_survey()` contain no test for it. There is no test
block that verifies the warning fires when `primary_design@variables$type ≠
control_design@variables$type`.

Options:
- **[A]** Add a test block to §VIII: "Scheme mismatch (e.g., `'bootstrap'` vs. `'JK1'`)
  → `surveywts_warning_replicate_scheme_mismatch`; calibration still proceeds and result
  passes `test_invariants()`." — Effort: low, Risk: low, Impact: closes coverage gap, Maintenance: none
- **[B] Do nothing** — Warning tests are easy to add at implementation time.

**Recommendation: A** — The spec is the contract; warnings without test specs get
skipped at implementation time.

**Issue 4: Logit method bounds not documented**
Severity: SUGGESTION
Violates: Lens 3 — contract completeness; behavior at boundaries

For `method = "logit"`, `survey::cal.logit` requires lower and upper weight bounds.
`svrep::calibrate_to_sample()` may expose these via an additional argument. The spec's
`control` list only documents `maxit` and `epsilon`. If svrep's API allows passing
logit bounds through `control` (or a separate argument), the spec should either expose
that parameter or explicitly state that default bounds are used (and what they are).

Options:
- **[A]** Investigate svrep's API. If bounds are exposed, add `bounds` as a `control`
  key with its default value. If not exposed, add a sentence: "Logit bounds default to
  svrep's defaults; pass `method = 'linear'` for unbounded calibration." — Effort: low, Risk: low, Impact: complete contract, Maintenance: none
- **[B] Do nothing** — svrep defaults are reasonable; document at implementation time.

**Recommendation: A** — Any parameter that affects outputs belongs in the contract, even
if the answer is "we use svrep's default."

---

#### Section: IV — `calibrate_to_estimate()`

**Issue 5: `estimate` NA values not in error table or behavior rules**
Severity: REQUIRED
Violates: engineering-preferences.md §4 — "handle edge cases, not fewer"; Lens 4

The §IV behavior rules and error table thoroughly validate `estimate` for names, length,
and name matching, but say nothing about NA values. An NA in `estimate` would flow
through to `svrep::calibrate_to_estimate()` and produce a cryptic internal error rather
than a surveywts-classed one. The `vcov_estimate` rules explicitly ban NAs; `estimate`
should too.

Options:
- **[A]** Add Behavior Rule (after Rule 2): "If `estimate` contains any `NA`, throw
  `surveywts_error_estimate_has_na`." Add to error table and §X integration list. — Effort: low, Risk: low, Impact: clean user-facing error, Maintenance: none
- **[B]** Extend Rule 2 to require `!anyNA(estimate)` without a new error class, reusing
  `surveywts_error_estimate_not_named` with an updated message. — Effort: low, Risk: medium (overloads an existing class), Maintenance: none
- **[C] Do nothing** — svrep will error with a numeric complaint.

**Recommendation: A** — One new error class; clean separation of NA from naming issues.

**Issue 6: Missing tests — formula error paths for `calibrate_to_estimate()`**
Severity: REQUIRED
Violates: testing-standards.md §2 — "every row in the error table covered by a test"

§VIII test categories for `calibrate_to_estimate()` list vcov/estimate errors and the
convergence error, but do not include tests for two errors that appear in the §IV error
table: `surveywts_error_formula_variable_not_found` and `surveywts_error_formula_invalid`.

Options:
- **[A]** Add two test blocks to §VIII `calibrate_to_estimate()` error paths:
  - Formula variable missing from `design@data` → `surveywts_error_formula_variable_not_found`
  - `formula` is not a formula object → `surveywts_error_formula_invalid`
  — Effort: low, Risk: low, Impact: closes coverage gap, Maintenance: none
- **[B] Do nothing** — These errors are tested indirectly via `calibrate_to_survey()`.

**Recommendation: A** — Indirect coverage from a different function doesn't satisfy the
error table rule; each function's error paths should be tested directly.

**Issue 7: `calibrate_to_estimate()` argument order — formula after estimate/vcov**
Severity: SUGGESTION
Violates: Lens 6 — API coherence; usability

The current signature is `(design, estimate, vcov_estimate, formula, ...)`. The `formula`
argument defines the model matrix that determines what `estimate` names must match, so
it is conceptually prior to `estimate` and `vcov_estimate`. Most users will read the
formula first to know what estimates to supply. Placing formula third forces users to
understand `estimate` before they know what `formula` they need.

Options:
- **[A]** Reorder to `(design, formula, estimate, vcov_estimate, method, control)`. — Effort: low, Risk: low, Impact: more intuitive API, Maintenance: none
- **[B] Do nothing** — Users can read the docs; order is a preference.

**Recommendation: A** — `formula` logically precedes what it defines; this matches how
`calibrate_to_survey()` places `formula` after the design objects, not after metadata.

---

#### Section: V — `redistribute_weights()`

**Issue 8: `wt_name` column collision behavior unspecified**
Severity: REQUIRED
Violates: Lens 3 — contract completeness; Lens 4 — edge cases

§V does not address what happens when `wt_name` matches an existing non-weight column in
the input data frame. With the default `wt_name = "wts"`, any input `data.frame` that
already has a column named "wts" (for any purpose) would have it silently overwritten in
the output `weighted_df`. This is a silent data corruption scenario.

The same potential issue exists in `adjust_nonresponse()`, which the spec says
`redistribute_weights()` is analogous to. The spec should state the expected behavior
explicitly, consistent with whatever `adjust_nonresponse()` does.

Options:
- **[A]** Add a Behavior Rule: "If `wt_name` matches an existing column name that is not
  the current weight column, throw `surveywts_error_wt_name_conflict`." Add error class to
  table and §X. — Effort: low, Risk: low, Impact: prevents silent overwrites, Maintenance: none
- **[B]** Overwrite silently (no error, no warning) — consistent with R's default column
  replacement behavior. State this explicitly in §V. — Effort: low, Risk: medium (surprising), Maintenance: none
- **[C] Do nothing** — Same ambiguity exists in `adjust_nonresponse()`.

**Recommendation: A** — Silent column overwrites violate the principle that "design
variables are sacred" (CLAUDE.md); an error is consistent with the package's strict
validation stance.

**Issue 9: Missing tests — `reduce_if`/`increase_if` NA error paths**
Severity: REQUIRED
Violates: testing-standards.md §2 — "every row in the error table covered by a test"

§VIII test categories for `redistribute_weights()` cover the binary validation errors
(not-found, not-binary, overlap, no-recipients, by-NA) but do not explicitly list tests
for `surveywts_error_reduce_if_has_na` or `surveywts_error_increase_if_has_na`, which
appear in the §V error table.

Options:
- **[A]** Add to §VIII error paths: "`reduce_if` column has NA → `surveywts_error_reduce_if_has_na`",
  "`increase_if` column has NA → `surveywts_error_increase_if_has_na`". — Effort: low, Risk: low, Impact: closes coverage gap, Maintenance: none
- **[B] Do nothing** — NA validation is covered implicitly by the `.validate_response_status_binary()` test.

**Recommendation: A** — The error table lists these explicitly; the test plan must cover them.

**Issue 10: Missing tests — standard weight validation errors for `redistribute_weights()`**
Severity: REQUIRED
Violates: testing-standards.md §2 — "every row in the error table covered by a test"

The §V error table includes seven reused weight validation errors (`surveywts_error_empty_data`,
`surveywts_error_weights_not_found`, `surveywts_error_weights_not_numeric`,
`surveywts_error_weights_nonpositive`, `surveywts_error_weights_na`,
`surveywts_error_wt_name_not_scalar`, `surveywts_error_wt_name_empty`). §VIII test
categories cover indicator errors and grouping errors but list no tests for these seven.

These are "reuse existing" errors but `redistribute_weights()` is a new code path — the
validators must be explicitly invoked there and each invocation must be tested.

Options:
- **[A]** Add at least one representative test per validator class to §VIII error paths
  for `redistribute_weights()`. At minimum: empty data, missing weight column,
  non-numeric weight, non-positive weight, wt_name not scalar. — Effort: low, Risk: low, Impact: closes coverage gap, Maintenance: none
- **[B] Do nothing** — These validators are already tested in other functions; indirect coverage is sufficient.

**Recommendation: A** — Each new function is an independent call site; validators may be
called in the wrong order or omitted — only direct tests catch this.

---

#### Section: VI — `adjust_nonresponse()` Propensity-Cell

**Issue 11: DRY — `.validate_formula_variables()` not reused for propensity-cell**
Severity: REQUIRED
Violates: engineering-preferences.md §1 — DRY; Lens 1

§VII defines `.validate_formula_variables(formula, data, design_label)` as a shared
helper "Used by `calibrate_to_survey()`, `calibrate_to_estimate()`". §VI (propensity-cell)
independently describes formula variable validation: "Formula variables must exist in
`plain_df`. Missing variable → `surveywts_error_formula_variable_not_found`." — without
referencing the shared helper.

This creates two code paths performing identical validation. If the error message or logic
changes, the propensity-cell path will drift.

Options:
- **[A]** Update §VI Behavior Notes to explicitly call `.validate_formula_variables()`,
  and add `adjust_nonresponse()` to the "Used by" column in §VII's helper table. — Effort: low, Risk: low, Impact: eliminates duplicate validation logic, Maintenance: none
- **[B]** Inline the check in `adjust_nonresponse()` and accept two implementations.
  Document the exception in §VII. — Effort: low, Risk: medium (drift risk), Maintenance: ongoing

**Recommendation: A** — The helper already exists and handles exactly this case; using it
is zero additional work with guaranteed consistency.

**Issue 12: `surveywts_error_formula_invalid` missing from propensity-cell path**
Severity: REQUIRED
Violates: Lens 3 — contract completeness; Lens 5 — under-engineered

§VI Error Table is labeled "(New Errors Only)" and doesn't list `surveywts_error_formula_invalid`.
§VI Behavior Notes and the algorithm steps don't mention calling `.validate_formula()`.
The result: there is no spec-mandated check that `formula` is a valid one-sided formula
object when `method = "propensity-cell"`. A user passing a two-sided formula
(e.g., `responded ~ age_group`) would get a confusing `glm()` error instead of a
surveywts-classed one.

Options:
- **[A]** Add to §VI Behavior Notes: "Call `.validate_formula(formula)` before fitting
  the model (reuses the shared helper from §VII)." Add `surveywts_error_formula_invalid`
  as a "reuse" entry in the §VI error table and add a test block in §VIII. — Effort: low, Risk: low, Impact: clean error; DRY with calibration functions, Maintenance: none
- **[B] Do nothing** — The `glm()` call will fail with a non-null formula error message.

**Recommendation: A** — Consistent formula validation across all three formula-accepting
functions; one shared helper to maintain.

**Issue 13: No-respondents-in-propensity-cell not in error table or behavior rules**
Severity: REQUIRED
Violates: Lens 4 — edge cases; engineering-preferences.md §4 — handle edge cases explicitly

§VI algorithm step 5 says within-cell redistribution uses "Same formula as weighting-class",
but the propensity-cell error table does not include a cell-level "no respondents" error.
If the propensity scores cluster such that a quantile cell contains only nonrespondents
(common with extreme propensity concentration), the redistribution step will encounter
a group with no recipients — which is `surveywts_error_no_recipients_in_group` in
`redistribute_weights()` but unspecified here.

Without a spec entry, an implementer either: silently produces Inf weights (if they
don't reuse the check) or throws an error with no test (if they do). The test plan
has no coverage for this scenario.

Options:
- **[A]** Add to §VI Behavior Rules: "If any propensity cell contains no respondents,
  throw `surveywts_error_no_respondents_in_propensity_cell` (new class for clearer
  diagnostics — cell index + propensity range in message)." Add to error table and §X.
  Add an edge case test block in §VIII. — Effort: low, Risk: low, Impact: clear user-facing error, Maintenance: none
- **[B]** Reuse `surveywts_error_no_recipients_in_group` from `redistribute_weights()`.
  Add it as a "reuse" entry to the §VI error table and a test block in §VIII. — Effort: low, Risk: low, Impact: same, Maintenance: none
- **[C] Do nothing** — The user must ensure propensity scores are not degenerate.

**Recommendation: A** — A propensity-cell-specific error with the cell index and propensity
range is far more actionable than a generic redistribution error. This is the class of
error that occurs in real survey data (near-perfect separation in propensity models).

---

#### Section: VIII — Testing

**Issue 14: Wrong test file name — `test-nonresponse.R` vs. `test-05-nonresponse.R`**
Severity: REQUIRED
Violates: Lens 5 — internal consistency with actual repo state

§VIII test file map says `tests/testthat/test-nonresponse.R (extend)` but the actual
file in the repo is `tests/testthat/test-05-nonresponse.R`. The spec would cause an
implementer to extend or create the wrong file.

Options:
- **[A]** Update §VIII test file map to `tests/testthat/test-05-nonresponse.R`. — Effort: trivial, Risk: none, Impact: implementer finds the right file, Maintenance: none
- **[B] Do nothing** — Implementer can search the repo.

**Recommendation: A** — Trivial fix; wrong file names in specs cause hard-to-diagnose
issues during implementation.

**Issue 15: Dual test pattern not called out in test plans**
Severity: SUGGESTION
Violates: testing-surveywts.md §Layer 3 — all Layer 3 errors require dual pattern

§VIII lists error path test blocks (e.g., "primary_design is survey_taylor →
`surveywts_error_primary_not_replicate`") but never specifies that these use the dual
pattern (`expect_error(class=)` + `expect_snapshot(error=TRUE)`) required by
testing-surveywts.md. An implementer reading only the spec might write class-only tests
and miss snapshots.

Options:
- **[A]** Add a one-line note to §VIII before the first test category: "All Layer 3
  error paths use the dual pattern per testing-surveywts.md: `expect_error(class=)` +
  `expect_snapshot(error=TRUE)`." — Effort: trivial, Risk: low, Impact: consistent test quality, Maintenance: none
- **[B] Do nothing** — testing-surveywts.md is authoritative; no need to repeat in the spec.

**Recommendation: A** — The testing rule is easy to miss when writing test plans; one
forward reference costs nothing and prevents the most common testing omission in this
package.

---

## Summary (Pass 1)

| Severity | Count |
|---|---|
| BLOCKING | 0 |
| REQUIRED | 9 |
| SUGGESTION | 6 |

**Total issues:** 15

**Overall assessment:** The spec is methodologically solid (Stage 2 locked) and
architecturally complete, but has nine required issues — primarily test plan coverage
gaps, one DRY violation in formula validation, two missing error table entries
(estimate NAs, no-respondents-in-propensity-cell), one wrong test file name, and a
`wt_name` collision behavior that needs a decision. None require rearchitecting; all are
resolvable with targeted additions to existing spec sections.
