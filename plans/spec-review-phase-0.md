## Spec Review: phase-0 — Pass 1 (2026-02-27)

### New Issues

#### Section: VI–VIII (calibrate, rake, poststratify — Argument Order)

**Issue 1: Argument order violates code-style.md in all three calibration functions**
Severity: BLOCKING
Violates `code-style.md §4` argument order rule: required NSE before optional NSE before optional scalar.

The spec claims each function "Follows `code-style.md` argument order rules," but all three function signatures put `weights = NULL` (optional NSE, category 4) *before* the required NSE/tidy-select or required scalar arguments (categories 2 and 3):

- `calibrate(data, weights = NULL, variables, population, ...)` — `weights` (opt NSE) before `variables` (req NSE) and `population` (req scalar)
- `rake(data, weights = NULL, margins, ...)` — `weights` (opt NSE) before `margins` (req scalar)
- `poststratify(data, weights = NULL, strata, population, ...)` — `weights` (opt NSE) before `strata` (req NSE) and `population` (req scalar)

Per `code-style.md` the correct order is: `data` → required NSE → required scalar → optional NSE → optional scalar → `...`

Correct signatures:
- `calibrate(data, variables, population, weights = NULL, method = ..., type = ..., control = ...)`
- `rake(data, margins, weights = NULL, type = ..., control = ...)`
- `poststratify(data, strata, population, weights = NULL, type = ...)`

Options:
- **[A]** Fix argument order in all three calibration function signatures to match the rule — Effort: low, Risk: low (no implementation exists yet), Impact: correct API from the start
- **[B]** Add an explicit exception to code-style.md allowing `weights` in position 2 for all calibration functions (ergonomic argument; users often need to specify it) — Effort: low, Risk: medium (weakens the rule), Impact: API stays as-is but rule is updated
- **[C] Do nothing** — API is shipped with the wrong argument order; fixing post-implementation is a breaking change

**Recommendation: A** — No implementation exists yet; fix the signatures now at zero cost.

---

#### Section: V (survey_calibrated Print Method)

**Issue 2: Print method shows variance method with no mechanism specified**
Severity: BLOCKING
Violates spec completeness — behavior stated without a mechanism.

The verbatim output for `survey_calibrated` print shows:
```
# Variance method: Taylor linearization
```

But `survey_calibrated` extends `survey_base`, NOT `survey_taylor`. The spec does not specify:
1. Where the variance method string comes from
2. Whether `survey_base` has a variance method property
3. How to determine the variance method label ("Taylor linearization") from the class

Options:
- **[A]** Specify that `survey_calibrated` always displays "Taylor linearization" because Phase 0 calibration only supports Taylor-based designs as input; hardcode the string — Effort: low, Risk: low, Impact: correct for Phase 0; revisit in Phase 1
- **[B]** Add a `@variance_method` property to `survey_calibrated` set to `"taylor"` by `.new_survey_calibrated()`, and print based on that value — Effort: low, Risk: low, Impact: forward-compatible
- **[C] Do nothing** — Implementer guesses; print method silently hard-codes or reads from surveycore in an unspecified way

**Recommendation: A** — Phase 0 only accepts `survey_taylor` input; hardcoding is honest and correct. Document that Phase 1 will revisit.

---

#### Section: II / XIV (Package Dependencies)

**Issue 3: DESCRIPTION Imports not specified anywhere in the spec**
Severity: BLOCKING
Violates `r-package-conventions.md` — version-pinned Imports required, spec is the authoritative Phase 0 artifact.

The spec references multiple external packages by name (`surveycore`, `S7`, `rlang`, `dplyr`, `tibble`) but never lists what goes in `Imports` or `Suggests`, or what minimum versions are required. `dplyr_reconstruct.weighted_df()` requires dplyr in Imports; `survey_calibrated` extending `survey_base` requires surveycore in Imports. The implementer has no authoritative source for the dependency list.

Options:
- **[A]** Add a "Package Dependencies" section to the spec listing each `Imports` package with the minimum version pinned — Effort: low, Risk: low, Impact: removes implementer guesswork
- **[B]** Leave dependency specification to the implementer — Effort: none, Risk: high (wrong versions, missing packages)
- **[C] Do nothing** — Same as B

**Recommendation: A** — A five-minute addition that eliminates a class of implementation errors.

---

#### Section: VIII (poststratify — Population Cell Gap)

**Issue 4: poststratify() GAP is unresolved: warning vs error for population cells not in data**
Severity: BLOCKING
The spec itself flags this as needing resolution: "⚠️ GAP: Decision needed on whether cells in population not present in data should be a warning (current spec) or an error."

The current spec specifies a warning (`surveywts_warning_population_cell_not_in_data`) with the behavior "the cell is ignored." This is a meaningful design decision about whether unexpected extra cells in the population silently proceed or halt. The spec correctly flags it for review — and Pass 1 is the right place to resolve it.

Methodological note: Extra cells in population that have no sample observations represent a misspecification of the population frame. Silent ignorance risks masking errors in the caller's data.

Options:
- **[A]** Change to an error — Forces users to explicitly align population cells with data cells; prevents silent misspecification — Effort: low (single behavior change), Risk: low, Impact: more defensive API
- **[B]** Keep as a warning and document explicitly that extra population cells are silently ignored — Effort: low, Risk: medium (users may misspecify population and not notice), Impact: more permissive API
- **[C] Do nothing** — GAP remains open; implementer makes an architectural decision

**Recommendation: A** — Silent ignorance of extra population cells is a trap. An error forces intentional alignment. If a user genuinely wants to ignore extra cells, they can remove them from the population data frame before calling.

---

#### Section: VI–IX / XIII (Edge Case Spec: 0-row data)

**Issue 5: 0-row data behavior not specified in any function's Behavior Rules**
Severity: BLOCKING
Violates `engineering-preferences.md §4` — edge cases must be explicitly specified, not left as "reasonable behavior."

The test plans for `calibrate()` and `rake()` include `# Edge — 0-row data frame`, but the Behavior Rules sections for these functions (and poststratify, adjust_nonresponse) are silent on what happens. The test plan implies a test exists, but the spec doesn't say whether 0-row input:
- Errors immediately (what error class?)
- Returns a 0-row `weighted_df` (vacuously correct)
- Throws a warning

Without specifying the behavior, the test cannot be written correctly.

Options:
- **[A]** Add to Behavior Rules: "If `nrow(data) == 0`, error `surveywts_error_empty_data`" — new error class, add to error table and Section XII — Effort: low, Risk: low, Impact: explicit contract
- **[B]** Add to Behavior Rules: "0-row input returns a 0-row output without error" — Effort: low, Risk: low, Impact: vacuous success semantics
- **[C] Do nothing** — Test says edge case is tested but spec doesn't say what the expected outcome is

**Recommendation: A** — An error is preferable for calibration functions: 0-row data means no population totals can be calibrated, and the result would be mathematically undefined.

---

#### Section: VI–IX (Edge Case Spec: NA in Auxiliary Variables)

**Issue 6: NA in auxiliary/by/strata/response_status variables — behavior undefined for all functions**
Severity: REQUIRED
Violates `engineering-preferences.md §4` — "All-NA inputs, zero-weight rows, single-level groups, empty domains — these are not hypothetical; they appear in real survey data."

None of the function behavior rules address what happens when:
- `calibrate()`: a `variables` column has `NA` values (NA is a possible factor/character level)
- `rake()`: a `margins` variable has `NA` values
- `poststratify()`: a `strata` column has `NA` values
- `adjust_nonresponse()`: a `by` variable has `NA` values, or `response_status` has `NA` values (neither TRUE nor FALSE)

If NA is treated as a level, it would appear in population targets. If not, what happens?

Options:
- **[A]** Specify that NA in any auxiliary/grouping variable is an error (`surveywts_error_variable_has_na`); add to error tables and test plans — Effort: low, Risk: low, Impact: explicit; users must handle NAs before calling
- **[B]** Specify per-function behavior: NA treated as a level for calibration; NA rows excluded for adjustment; add this to each Behavior Rules section — Effort: medium, Risk: medium, Impact: more flexible but complex
- **[C] Do nothing** — Implementer decides; behavior is undocumented and may vary across functions

**Recommendation: A** — Consistent NA rejection with clear errors is safer and easier to test. Users cleaning survey data should know their population variables explicitly.

---

#### Section: VII–VIII (Categorical Restriction in rake/poststratify)

**Issue 7: Categorical-variable-only restriction is stated only for calibrate(), not rake() or poststratify()**
Severity: REQUIRED
The error `surveywts_error_calibrate_variable_not_categorical` and the restriction "categorical (character or factor) variables only in Phase 0" appear only in Section VI (`calibrate()`). Sections VII (`rake()`) and VIII (`poststratify()`) have no analogous restriction or error.

IPF (rake) is also a categorical-variable method. Does `rake()` silently accept a numeric variable? Does `poststratify()` allow numeric strata? If so, what happens? If not, what is the error class?

Options:
- **[A]** Apply the same categorical restriction to `rake()` and `poststratify()`; either reuse `surveywts_error_calibrate_variable_not_categorical` or introduce a more general `surveywts_error_variable_not_categorical` — Effort: low, Risk: low, Impact: consistent behavior across calibration functions
- **[B]** Specify that `poststratify()` accepts numeric strata columns (it's a join-like operation, numeric key is fine); only `rake()` needs the categorical restriction — Effort: low, Risk: low, Impact: correct granularity
- **[C] Do nothing** — Ambiguous behavior; implementer decides per function

**Recommendation: A with granularity from B** — Rake requires categorical; poststratify should document whether numeric strata columns are accepted (they likely are fine as join keys).

---

#### Section: XIII (Test Plan — survey_calibrated print snapshot)

**Issue 8: survey_calibrated print method has no snapshot test in the test plan**
Severity: REQUIRED
Violates `testing-standards.md §2`: print snapshot tests are explicitly required for every result class that has a `print()` method.

The spec provides a verbatim print example for `survey_calibrated` (Section V), and print snapshot tests are explicitly required by the testing standards. The test plan in Section XIII covers `test-00-classes.R` but lists no snapshot test for `survey_calibrated`'s print method.

Options:
- **[A]** Add to `test-00-classes.R` test plan: `# Print snapshot — survey_calibrated print output matches verbatim example` — Effort: trivial, Risk: low, Impact: ensures print method is tested
- **[B]** Add the test to a new test file `test-05-print.R` — Effort: trivial, Risk: low
- **[C] Do nothing** — Print method exists with no snapshot test; message can drift undetected

**Recommendation: A** — Put it with the class tests. One line to add.

---

#### Section: XIII (Test Plan — History Accumulation)

**Issue 9: History accumulation tests missing from rake() and poststratify() test plans**
Severity: REQUIRED
The `calibrate()` test plan includes `# 23. History — weighting_history has correct structure after calibration` and `# 24. History — step number increments correctly across chained calls`. The `rake()` test plan omits both. The `poststratify()` test plan omits both. Weighting history accumulation is a core feature; all three functions must have it tested.

Options:
- **[A]** Add history structure and step increment tests to rake() and poststratify() test plans explicitly — Effort: trivial (two lines each), Risk: low, Impact: all three calibration functions have equal coverage
- **[B]** Add a note to the rake() and poststratify() test plans that items referencing "same happy paths as calibrate()" include the history tests — Effort: trivial, Risk: low (ambiguous reference)
- **[C] Do nothing** — History accumulation in rake()/poststratify() untested

**Recommendation: A** — Explicit is better than reference-by-implication. Two lines each.

---

#### Section: IV (History Entry — parameters$population)

**Issue 10: history entry parameters$population format is undefined**
Severity: REQUIRED
The history entry format (Section IV) specifies `parameters = list(variables = ..., population = list(...), control = ...)` and says "summarized, not the full object." But "summarized" is not defined. The full `population` argument could be a large named list. What goes in the history?

Options include: variable names only, full targets, a compact summary (n_levels per variable), or NULL. The implementer must decide, but this decision affects auditability (Section IV's stated goal: "rich enough to audit the weighting procedure").

Options:
- **[A]** Define "summarized" explicitly: store the full `population` argument as-is (calibrate, poststratify); for rake() with long-format input, store the converted list form — Effort: low, Risk: low, Impact: fully auditable history
- **[B]** Define "summarized" as: variable names + per-variable target counts (n levels), not the actual targets — Effort: low, Risk: low, Impact: compact but less auditable
- **[C] Do nothing** — "Summarized" is left for the implementer to interpret

**Recommendation: A** — Full population targets are small in practice (few variables × few levels), and auditability is the stated goal.

---

#### Section: IX (adjust_nonresponse — min_cell_size)

**Issue 11: min_cell threshold for class_near_empty warning is hardcoded with no rationale**
Severity: REQUIRED
The spec says "cells with fewer than 5 respondents" trigger `surveywts_warning_class_near_empty`, and it flags this as: "⚠️ GAP: Confirm minimum cell size threshold (5 respondents). This is a methodological choice; cite a reference or make it configurable."

This GAP is in the spec text. Pass 1 is the right time to resolve it.

Options:
- **[A]** Make it configurable via `adjust_nonresponse(..., control = list(min_cell = 5))`; document that 5 is the default, cite a survey methods reference — Effort: low (add `control` argument), Risk: low, Impact: user-overridable; consistent with `calibrate()` and `rake()`
- **[B]** Hardcode 5 and cite AAPOR or similar reference as justification — Effort: trivial, Risk: low, Impact: simpler API, less flexible
- **[C] Do nothing** — GAP remains open

**Recommendation: A** — Consistency with calibrate()/rake() control argument pattern. Adding control later is a breaking change; adding it now is free.

---

#### Section: X (Diagnostics — Return Value Names)

**Issue 12: effective_sample_size() and weight_variability() return value names not specified**
Severity: REQUIRED
The spec says these return "a named numeric scalar." The naming of a named scalar is part of the API contract (callers access it by name). The spec describes `n_eff` for `effective_sample_size()` and `cv` for `weight_variability()` but does not explicitly state these as the vector names.

Is the return value `c(n_eff = 1189.3)` or `c(ess = 1189.3)` or just `1189.3` (unnamed)?

Options:
- **[A]** Explicitly state the return name: `effective_sample_size()` returns `c(n_eff = <value>)`, `weight_variability()` returns `c(cv = <value>)` — Effort: trivial, Risk: low, Impact: complete API contract
- **[B]** Change to unnamed scalar (simpler, more composable with `|>` pipelines) — Effort: trivial, Risk: low, Impact: simpler; no named access
- **[C] Do nothing** — Implementer guesses; tests fail if they guess wrong

**Recommendation: A** — Named scalars are useful. State the name explicitly so it is testable.

---

#### Section: XIII (adjust_nonresponse() Test Plan)

**Issue 13: adjust_nonresponse() test plan missing weighted_df and survey_calibrated happy path tests**
Severity: REQUIRED
The output contract (Section IX) states `adjust_nonresponse()` accepts `data.frame`, `weighted_df`, `survey_taylor`, and `survey_calibrated` inputs. The test plan covers data.frame (test #1) and survey_taylor (test #2) but has no happy path test for `weighted_df` or `survey_calibrated` inputs. All four supported input types require their own happy path per `testing-standards.md §2`.

Options:
- **[A]** Add to test plan: `# 2b. Happy path — weighted_df input → weighted_df output` and `# 2c. Happy path — survey_calibrated input → survey_calibrated output` — Effort: trivial, Risk: low, Impact: full input-type coverage
- **[B]** Note that calibrate() tests already cover these types and the "same class matrix" implies coverage — Effort: trivial, Risk: medium (tests may never be written)
- **[C] Do nothing** — Two input types have no test coverage

**Recommendation: A** — Explicit tests are required by the standards.

---

#### Section: VI (calibrate() Error Messages)

**Issue 14: Error message template for calibrate_variable_not_categorical incorrectly suggests rake() for continuous variables**
Severity: REQUIRED
The `v` bullet for `surveywts_error_calibrate_variable_not_categorical` reads:
> "v: Convert to factor or character, or use {.fn rake} for continuous auxiliary variables."

But `rake()` in Phase 0 also only supports categorical variables (IPF requires categorical margins). Suggesting `rake()` for continuous variables is factually incorrect and will mislead users.

Options:
- **[A]** Remove the rake() suggestion; change to: "Convert to factor or character before calibrating." — Effort: trivial, Risk: low, Impact: correct guidance
- **[B]** Change to: "Convert to factor or character. Continuous auxiliary variable calibration is not supported in Phase 0." — Effort: trivial, Risk: low, Impact: accurate and informative about Phase 0 scope
- **[C] Do nothing** — Users misled to try rake() and get the same error

**Recommendation: B** — More informative about Phase 0 scope.

---

#### Section: II / surveywts-package.R (.onLoad specification)

**Issue 15: .onLoad() / S7::methods_register() not specified in the spec**
Severity: REQUIRED
`survey_calibrated` is an S7 class with an S7-registered print method (`S7::method(print, survey_calibrated) <- ...`). For S7 method dispatch to work at runtime, `S7::methods_register()` must be called in `.onLoad()`. The spec lists `surveywts-package.R` in the source file organization table but specifies no content for it.

From CLAUDE.md: "S7::methods_register() in `.onLoad()`" — this rule exists at the package level but the spec is silent on it.

Options:
- **[A]** Add to the Architecture section: "surveywts-package.R must include .onLoad() calling S7::methods_register()" — Effort: trivial, Risk: low, Impact: prevents runtime dispatch failure
- **[B]** Reference CLAUDE.md rule and note the spec relies on it — Effort: trivial, Risk: low
- **[C] Do nothing** — Implementer may forget; print dispatch silently fails

**Recommendation: A** — One sentence to prevent a silent runtime failure.

---

#### Section: XIII (Test Coverage — Multi-variable)

**Issue 16: Multi-variable happy path not explicit in calibrate() test plan**
Severity: SUGGESTION
The test plan for `calibrate()` has a test for single-variable population (#22) but no explicit multi-variable happy path test. The happy paths do not specify how many variables are in the population. Per `testing-standards.md`, multi-variable behavior should be explicit.

Options:
- **[A]** Add: `# 2a. Happy path — multiple variables in population (age_group + sex + education)` — Effort: trivial
- **[B]** Note that make_surveywts_data() returns multi-variable data and happy path #1 implicitly tests this — Effort: trivial (one comment)
- **[C] Do nothing** — Implicit through data generator usage

**Recommendation: B** — Note the implicit coverage; it is a low-risk gap.

---

#### Section: XIII (Test Coverage — History Chaining)

**Issue 17: Cross-function history chaining test not in any test plan**
Severity: SUGGESTION
The spec says weighting history accumulates across chained operations. But no test plan explicitly tests: `df |> calibrate(...) |> rake(...)` and verifies that the resulting `weighted_df` has two history entries with correct step numbers. This is a core use case (the print method even shows a 2-step example).

Options:
- **[A]** Add an integration test block (separate test file `test-integration.R`) testing a full calibration chain — Effort: low
- **[B]** Add to calibrate() test plan: `# 24b. History — chain calibrate() → rake() → two-entry history` — Effort: trivial
- **[C] Do nothing** — Chaining is tested implicitly through the existing history tests

**Recommendation: B** — One test block; high confidence in a core use case.

---

#### Section: IX (adjust_nonresponse() — Numerical Correctness)

**Issue 18: No reference implementation acknowledged for adjust_nonresponse() numerical correctness**
Severity: SUGGESTION
`calibrate()`, `rake()`, and `poststratify()` all have explicit numerical correctness tests against the `survey` package. `adjust_nonresponse()` has none. It is plausible there is no direct reference — the `survey` package does not provide a weighting-class nonresponse function — but the spec should acknowledge this explicitly rather than silently omitting the test.

Options:
- **[A]** Add to adjust_nonresponse() test plan: a hand-calculation verification test and explicit weight conservation check — Effort: low, Risk: low
- **[B]** Add a note: "No reference package available; correctness verified by weight conservation property and hand calculation" — Effort: trivial
- **[C] Do nothing** — Absence of the test is unexplained

**Recommendation: A** — Weight conservation is a testable invariant that substitutes for a reference package comparison. Test #5 (weight conservation) already exists; add a hand-calculation verification block.

---

#### Section: XIV (Quality Gates — Typo)

**Issue 19: Quality gate references nonexistent file "surveycore-conventions.md"**
Severity: SUGGESTION
The last QA gate reads: "[ ] `surveycore-conventions.md` stub is filled in with Phase 0 conventions." No file named `surveycore-conventions.md` exists in this package's rules. The CLAUDE.md rule files include `surveywts-conventions.md` and `testing-surveywts.md` as stubs. This is likely a typo.

Options:
- **[A]** Replace with two gates: "[ ] `surveywts-conventions.md` stub is filled in with Phase 0 conventions" and "[ ] `testing-surveywts.md` stub is filled in with test_invariants() definition and data generator" — Effort: trivial
- **[B]** Leave a single corrected gate — Effort: trivial
- **[C] Do nothing** — CI cannot verify a nonexistent file; gate is inoperable

**Recommendation: A** — Both stubs exist per CLAUDE.md and both need filling before implementation begins.

---

#### Section: VIII (poststratify() and adjust_nonresponse() — 0-row edge case)

**Issue 20: poststratify() and adjust_nonresponse() missing 0-row edge case tests**
Severity: SUGGESTION
The `calibrate()` test plan has `# 20. Edge — 0-row data frame` and `rake()` has `# 23. Edge — 0-row data`. Neither `poststratify()` nor `adjust_nonresponse()` list 0-row edge case tests. (Behavior depends on resolution of Issue 5.)

Options:
- **[A]** Add 0-row edge cases to both test plans after Issue 5 is resolved — Effort: trivial
- **[B]** Note that 0-row behavior is covered by the shared validation path — Effort: trivial
- **[C] Do nothing** — Two functions untested for empty input

**Recommendation: A** — After Issue 5 is resolved, add the corresponding tests to both functions.

---

## Summary (Pass 1)

| Severity | Count |
|---|---|
| BLOCKING | 5 |
| REQUIRED | 10 |
| SUGGESTION | 5 |

**Total issues:** 20

**Overall assessment:** The spec is architecturally sound and unusually thorough in its error contracts and test plan — but has five blocking issues that must be resolved before implementation: the consistent argument order violation across all three calibration functions (which the spec incorrectly claims is compliant with code-style.md), an undefined mechanism for the survey_calibrated print method's variance label, missing package dependency specification, an unresolved GAP in poststratify() about warning vs error for extra population cells, and undefined behavior for 0-row inputs. Resolution of these five blockers should take less than a day; the spec is otherwise implementable.

---

## Spec Review: phase-0 — Pass 2 (2026-02-27)

### Prior Issues (Pass 1)

| # | Title | Status |
|---|---|---|
| 1 | Argument order violates code-style.md in all three calibration functions | ✅ Resolved |
| 2 | Print method shows variance method with no mechanism specified | ✅ Resolved |
| 3 | DESCRIPTION Imports not specified anywhere in the spec | ✅ Resolved |
| 4 | poststratify() GAP: warning vs error for population cells not in data | ✅ Resolved |
| 5 | 0-row data behavior not specified in any function's Behavior Rules | ✅ Resolved |
| 6 | NA in auxiliary/by/strata/response_status variables — behavior undefined | ✅ Resolved |
| 7 | Categorical-variable-only restriction stated only for calibrate(), not rake() or poststratify() | ✅ Resolved |
| 8 | survey_calibrated print method has no snapshot test in the test plan | ✅ Resolved |
| 9 | History accumulation tests missing from rake() and poststratify() test plans | ✅ Resolved |
| 10 | history entry parameters$population format is undefined | ✅ Resolved |
| 11 | min_cell threshold for class_near_empty warning is hardcoded with no rationale | ✅ Resolved |
| 12 | effective_sample_size() and weight_variability() return value names not specified | ✅ Resolved |
| 13 | adjust_nonresponse() test plan missing weighted_df and survey_calibrated happy path tests | ✅ Resolved |
| 14 | Error message template incorrectly suggests rake() for continuous variables | ✅ Resolved |
| 15 | .onLoad() / S7::methods_register() not specified in the spec | ✅ Resolved |
| 16 | Multi-variable happy path not explicit in calibrate() test plan | ✅ Resolved |
| 17 | Cross-function history chaining test not in any test plan | ✅ Resolved |
| 18 | No reference implementation acknowledged for adjust_nonresponse() numerical correctness | ✅ Resolved |
| 19 | Quality gate references nonexistent file "surveycore-conventions.md" | ✅ Resolved |
| 20 | poststratify() and adjust_nonresponse() missing 0-row edge case tests | ✅ Resolved |

All 20 Pass 1 issues were resolved in the spec update.

### New Issues

#### Section: VI / VII (calibrate, rake — Population Level Direction 2)

**Issue 21: Missing error class for "population has a level absent from data" in calibrate() and rake()**
Severity: BLOCKING
No rule file cited — this is a contract completeness gap: the spec states a behavior but provides no class name for the implementer.

Section VI states: _"Levels present in `population` but absent from `data` are an error."_ This is the reverse of `surveywts_error_population_level_missing` (which covers a data level absent from `population`). For GREG calibration, a population target for a level that has no sample observations is mathematically ill-posed — the calibration system is overdetermined. For rake (IPF), the same applies: a margin entry for a level not in the data cannot be calibrated. Both functions require this error to be raised.

The Section XII master error table has no class for this condition. The poststratify analog is `surveywts_error_population_cell_not_in_data` — calibrate()/rake() have no equivalent.

The spec text for Section VI also says "Levels present in `population` but absent from `data` are an error" — twice stating behavior, zero times naming the class. An implementer reading this must invent a name, which defeats the purpose of the error class contract.

Options:
- **[A]** Add `surveywts_error_population_level_extra` to the calibrate() error table with a message template; add to Section XII master table (thrown by `calibrate()` validation and implied for `rake()` via the "all calibrate() errors apply" reference); add test items to both calibrate() and rake() test plans — Effort: low, Risk: low, Impact: complete error contract
- **[B]** Reuse the poststratify name and generalize: rename `surveywts_error_population_cell_not_in_data` to `surveywts_error_population_level_extra` covering all three functions — Effort: low, Risk: low (poststratify is unimplemented)
- **[C] Do nothing** — Spec says "an error" without a class; implementer invents a name inconsistent with the error table

**Recommendation: A** — A new, narrowly scoped class for calibrate()/rake() is cleaner than reusing poststratify's cell-based name. Both conditions are real errors that survey practitioners encounter (population frame has more levels than the sample).

---

#### Section: XIII (rake() Test Plan — Ambiguous Reference)

**Issue 22: rake() test plan items "1–6. Same happy paths as calibrate()" includes a test that doesn't exist in rake()**
Severity: REQUIRED
Violates `testing-standards.md §2` — test plan must be unambiguous; each test block must describe one observable behavior.

`rake()` has no `method` argument. calibrate() test item #5 is `"Happy path — method = 'logit'"`. The rake() test plan item `"1–6. Same happy paths as calibrate(), with margins argument"` implicitly includes a logit-method test that cannot be written for rake(). An implementer following this spec literally would either write a nonsensical test or skip item #5, breaking test plan coverage.

Additionally, test item #2a from calibrate() reads `"assert length(population) == 3, all variables calibrated correctly"` — for rake() this should reference `margins`, not `population`. The phrasing is calibrate()-specific and doesn't translate cleanly.

Options:
- **[A]** Replace the reference with explicit items: `# 1. Happy path — data.frame → weighted_df` / `# 2. Happy path — survey_taylor → survey_calibrated` / `# 2a. Happy path — multiple margins explicitly verified (assert length(margins) == 3)` / `# 3. Happy path — weighted_df → weighted_df (history accumulates)` / `# 4. Happy path — survey_calibrated → survey_calibrated` / `# 5. Happy path — type = "count"` — Effort: low, Risk: low, Impact: unambiguous test plan
- **[B]** Add a clarifying note: `"# Tests 1–4 and 6 apply; test #5 (method = 'logit') does not apply — rake() has no method argument. 2a: verify length(margins) == 3 not length(population)."` — Effort: trivial, Risk: low
- **[C] Do nothing** — Implementer may write a test that attempts `rake(..., method = "logit")`, which will fail or be skipped

**Recommendation: A** — rake() has a materially different argument set from calibrate(). Explicit test items eliminate ambiguity at near-zero cost.

---

#### Section: X / XIII (Diagnostics — Missing Error Test)

**Issue 23: Diagnostics test plan missing the `weights_not_numeric` error test**
Severity: REQUIRED
Violates the quality gate: "All error classes have a `test_that()` block with the dual pattern."

Section X diagnostic error table lists three error classes for `effective_sample_size()` and `weight_variability()`: `weights_required`, `weights_not_found`, and `weights_not_numeric`. The test plan covers `weights_required` (test #6) and `weights_not_found` (test #7). `weights_not_numeric` has no corresponding test item. The quality gate requires every error class to have a dual-pattern test block; this class will fail that gate unless a test is added.

Options:
- **[A]** Add `# 6b. Error — weights_not_numeric (pass a character-type weight column)` to the diagnostics test plan — Effort: trivial, Risk: low, Impact: closes the coverage gap
- **[B]** Remove `weights_not_numeric` from the diagnostics error table on the grounds that `.validate_weights()` is tested via calibrate() and the diagnostic functions delegate to it — Effort: trivial, Risk: medium (class disappears from diagnostics contract; users can't rely on it)
- **[C] Do nothing** — Error class is in the contract but has no test; quality gate will fail

**Recommendation: A** — The error is in the table; it needs a test. One line in the test plan.

---

#### Section: VIII / XII / XIII (poststratify and rake — population_totals_invalid)

**Issue 24: `surveywts_error_population_totals_invalid` missing from Section VIII error table and from poststratify() and rake() test plans**
Severity: REQUIRED
Internal spec inconsistency: Section XII states this class is thrown by `calibrate()`, `rake()`, AND `poststratify()`, but Section VIII's per-function error table omits it entirely, and neither the rake() nor poststratify() test plans include an explicit test for it.

Section VIII population format specifies: _"For `type = 'prop'`: values in `target` must sum to 1.0 (within 1e-6)."_ The validation logic that enforces this would throw `surveywts_error_population_totals_invalid` — but Section VIII's error table has no row for it. The rake() error table says "All errors from `calibrate()` apply" which implies it, but the rake() test plan items 11–23 (which explicitly list each error) do not include it. poststratify() is worse: neither the section error table nor the test plan mentions it.

calibrate() test item #18 `"Error — population_totals_invalid (prop does not sum to 1)"` exists ✅. Equivalent tests are absent from rake() and poststratify().

Options:
- **[A]** Add `surveywts_error_population_totals_invalid` to the Section VIII error table with a message template for the poststratify context; add explicit test items to both the rake() test plan and poststratify() test plan (`# Error — population_totals_invalid (type="prop" targets do not sum to 1)`) — Effort: low, Risk: low, Impact: complete coverage
- **[B]** For rake(): add a single explicit test item referencing the error class; for poststratify(): add to error table + test plan — Effort: same as A
- **[C] Do nothing** — Master table and function specs are inconsistent; test may never be written for rake()/poststratify()

**Recommendation: A** — The class is already in the master table and should appear in every function-level table where it can be thrown. Two test items close the gap.

---

#### Section: XIII (poststratify() Test Plan — Missing Weight Validation Error Tests)

**Issue 25: poststratify() test plan omits the explicit weight validation error tests that rake() test plan includes**
Severity: REQUIRED
Violates the quality gate: "All error classes have a `test_that()` block with the dual pattern."

The Section VIII error table states "All weight validation errors from `calibrate()` apply." rake() test plan explicitly lists these at items 14–19: `weights_not_found`, `weights_not_numeric`, `weights_nonpositive`, `weights_na`, `unsupported_class`, `replicate_not_supported`. The poststratify() test plan lists `replicate_not_supported` (#12) but omits `weights_not_found`, `weights_not_numeric`, `weights_nonpositive`, `weights_na`, and `unsupported_class`. These five classes have no tests in the poststratify() test plan.

The quality gate requires a test for every error class for every function that can throw it. "All weight validation errors from calibrate() apply" does not exempt poststratify() from needing tests — it just explains why the classes aren't listed in the error table. They still need test blocks.

Options:
- **[A]** Add explicit test items to poststratify() test plan: `# 13–17. Error paths — same weight validation errors as rake() items 14–19: weights_not_found, weights_not_numeric, weights_nonpositive, weights_na, unsupported_class` — Effort: trivial, Risk: low, Impact: all error classes tested
- **[B]** Add a single line: `# 13–17. Error paths — weight validation: same as calibrate() error tests 10–14 and unsupported_class` — Effort: trivial, Risk: low (reference is less ambiguous than rake()'s "same as calibrate()")
- **[C] Do nothing** — Five error classes have no test coverage for poststratify()

**Recommendation: A** — Explicit items prevent ambiguity. The rake() precedent is already explicit; poststratify() should match it.

---

#### Section: XII (Master Warning Table — Stale Threshold Description)

**Issue 26: Section XII master warning table for `class_near_empty` still says "fewer than 5 respondents" — not updated when Issue 11 was resolved**
Severity: REQUIRED
Internal spec inconsistency: Section IX and the test plan use `min_cell = 20` (NAEP methodology) and a dual-condition trigger (`n < min_cell` OR `adjustment_factor > max_adjust`); the master table still reflects the original hardcoded threshold of 5 respondents.

Line 1147 of the spec (Section XII warnings table):
> `surveywts_warning_class_near_empty` | `adjust_nonresponse()` | A weighting class cell has **fewer than 5 respondents**

But the resolved behavior (Section IX, Behavior Rules, and test items #15 and #15b) is:
> warns when EITHER `n_respondents < control$min_cell` (default **20**) OR `adjustment_factor > control$max_adjust` (default 2.0)

The master table is the authoritative source for `plans/error-messages.md`. If error-messages.md is updated from the stale master table, the threshold will be wrong and test item #15 (`< 20 respondents`) will contradict it.

Options:
- **[A]** Update Section XII warning table to: `A weighting class cell is sparse (fewer than control$min_cell respondents, default 20, or adjustment factor exceeds control$max_adjust, default 2.0)` — Effort: trivial, Risk: low, Impact: master table matches Section IX
- **[B]** Leave the master table as a simplified description; add a note: "See Section IX for exact threshold semantics" — Effort: trivial, Risk: low
- **[C] Do nothing** — Stale description propagates to error-messages.md; test items #15 and #15b contradict the table

**Recommendation: A** — The master table must match the behavior spec. Fixing the description is a one-line edit that prevents downstream confusion.

---

#### Section: V (survey_calibrated Validator — Reliance on Parent Validator)

**Issue 27: survey_calibrated S7 validator doesn't state whether it relies on survey_base's validator for @variables key invariants**
Severity: SUGGESTION
Violates `engineering-preferences.md §5` (explicit over clever) — an unstated assumption about parent behavior.

The Section V validator for `survey_calibrated` checks `@variables$weights` exists, is a character scalar, and the weight column is valid. But `@variables` must also contain `ids`, `strata`, `fpc`, and `nest` keys (from the class hierarchy spec). The spec is silent on whether `survey_base`'s validator (from surveycore) already enforces this, or whether `survey_calibrated` needs to add these checks.

If surveycore's `survey_base` validator does NOT check for required keys, then `survey_calibrated` objects could have a malformed `@variables` list with no validator catching it — causing silent attribute-lookup errors in the print method and downstream survey analysis.

This is Open GAP #1 dependent (verify surveycore source), but the spec should acknowledge the dependency explicitly rather than leaving it implicit.

Options:
- **[A]** Add a note to the validator section: _"@variables key presence (`ids`, `strata`, `fpc`, `nest`) is assumed to be enforced by the `survey_base` parent validator from surveycore. Verify against surveycore source (Open GAP #1). If not validated by the parent, add corresponding checks here."_ — Effort: trivial, Risk: low, Impact: removes an implicit assumption
- **[B]** Proactively add checks for all required @variables keys to the survey_calibrated validator — Effort: low, Risk: low (defensive), Impact: guaranteed coverage regardless of surveycore
- **[C] Do nothing** — Implementer may miss this dependency

**Recommendation: A** — A one-sentence note removes ambiguity at zero cost. Option B is also good but may duplicate surveycore's work — confirm GAP #1 first.

---

#### Section: X / XII (Diagnostic Functions — Unsupported Class Input)

**Issue 28: Diagnostic functions have no unsupported_class protection; non-standard input produces an uninformative R error**
Severity: SUGGESTION
Violates `engineering-preferences.md §4` — handle edge cases explicitly.

`effective_sample_size()`, `weight_variability()`, `summarize_weights()` accept `data.frame`, `weighted_df`, `survey_taylor`, and `survey_calibrated`. The master error table (Section XII) lists `surveywts_error_unsupported_class` as thrown by "All calibration/NR functions" — diagnostics are explicitly excluded. If a user passes a `matrix`, `list`, or an object from another survey package, they get an uninformative R error rather than a clear typed `surveywts_error_unsupported_class`.

The Section X error tables don't include `unsupported_class`. The quality gates don't require it. This is consistent within the spec — it's an intentional omission — but it creates a user experience gap.

Options:
- **[A]** Add `surveywts_error_unsupported_class` to the diagnostic error tables and Section XII master table; add test items to the diagnostics test plan — Effort: low, Risk: low, Impact: consistent defensive behavior across all package functions
- **[B]** Document explicitly in Section X that diagnostics do not perform class validation — any object with an accessible column may work — Effort: trivial, Risk: low (documents the current intent)
- **[C] Do nothing** — Uninformative error on unsupported class; inconsistency with calibration functions documented by implication only

**Recommendation: A** — Users who pass wrong types to diagnostic functions deserve the same clear error they'd get from calibrate(). One class, one check, a few test items. Also updates the master table from "All calibration/NR functions" to "All package functions."

---

## Summary (Pass 2)

| Severity | Count |
|---|---|
| BLOCKING | 1 |
| REQUIRED | 5 |
| SUGGESTION | 2 |

**Total issues:** 8

**Overall assessment:** The spec update resolved all 20 Pass 1 issues cleanly and thoroughly — argument order, dependency list, edge cases, test plan gaps, and error message accuracy are all addressed. One blocking issue remains: the missing error class for "population has a level absent from data" in calibrate() and rake() is a contract gap where the spec states a behavior ("an error") but names no class, leaving the implementer to invent one. Five required issues are internal consistency gaps — a stale threshold in the master warning table, a missing class in the poststratify() section error table, an ambiguous test plan reference in rake(), and missing explicit test items in two test plans. None require architectural rethinking. Resolving the 6 blocking/required issues is a single focused editing pass; the spec will then be ready for implementation planning.

---

## Spec Review: phase-0 — Pass 3 (2026-03-04)

### Prior Issues (Pass 2)

| # | Title | Status |
|---|---|---|
| 21 | Missing error class for "population has a level absent from data" in calibrate() and rake() | ✅ Resolved |
| 22 | rake() test plan items "1–6. Same happy paths as calibrate()" includes a test that doesn't exist | ✅ Resolved |
| 23 | Diagnostics test plan missing the `weights_not_numeric` error test | ✅ Resolved |
| 24 | `surveywts_error_population_totals_invalid` missing from poststratify() error table | ✅ Resolved |
| 25 | poststratify() test plan omits explicit weight validation error tests | ✅ Resolved |
| 26 | Master warning table for `class_near_empty` still says "fewer than 5 respondents" | ✅ Resolved |
| 27 | survey_calibrated validator doesn't state whether it relies on survey_base's validator | ✅ Resolved |
| 28 | Diagnostic functions have no unsupported_class protection | ✅ Resolved |

All 8 Pass 2 issues were resolved.

### Surveycore Source Verification (GAPs #1–3)

Before reviewing new issues: the surveycore package was inspected directly. The following GAPs from the spec's §XIV are now fully resolvable:

**GAP #1 — RESOLVED with surprises.** `survey_base` confirmed properties: `@data`, `@metadata`, `@variables`, `@groups`, `@call`. The spec's §V properties table omits `@groups` (character) and `@call` (ANY). More critically: surveycore already exports `survey_calibrated` as a full class with additional `@calibration` property (see Issue 29 below).

**GAP #2 — RESOLVED.** `survey_weighting_history(x)` is exported from surveycore and returns `x@metadata@weighting_history`. The `weighting_history` property already exists in `survey_metadata` as a list with default `list()`. The surveycore prerequisite PR has already been merged.

**GAP #3 — RESOLVED.** `@variables$weights` is confirmed to be a character scalar (column name). The `survey_taylor` validator reads `weights_var <- self@variables$weights` then accesses `self@data[[weights_var]]`, confirming it is a column name, not the weight vector.

**GAP #4 — RESOLVABLE.** surveycore is already installed with all prerequisite features. The minimum version in DESCRIPTION can be set by checking the installed version.

**GAP #5 — Already handled.** Hand-calculation validation is specified in test item 5b and the quality gate already requires documentation in VENDORED.md. No new spec changes needed.

**GAP #6 — See Issue 39 below (SUGGESTION).**

### New Issues

#### Section: V (survey_calibrated — Architectural Conflict)

**Issue 29: `surveycore` already defines and exports `survey_calibrated` — redefining it in `surveywts` creates a namespace conflict**
Severity: BLOCKING
No rule file cited — this is a fundamental architectural discovery from the surveycore source inspection.

The spec (§V, §I deliverables table, §II class hierarchy) plans to define `surveywts::survey_calibrated` in this package. But surveycore already defines and exports `surveycore::survey_calibrated` with this structure:

```
<surveycore::survey_calibrated> class
@ parent: <surveycore::survey_base>
@ properties:
  $ data       : S3<data.frame>
  $ metadata   : <surveycore::survey_metadata>
  $ variables  : <list>
  $ groups     : <character>
  $ call       : <ANY>
  $ calibration: <ANY>    ← NOT in spec
```

surveycore also exports `as_survey_calibrated(data, weights, calibration = NULL)` which constructs it. S7 uses fully qualified class names — `surveycore::survey_calibrated` and `surveywts::survey_calibrated` would be different classes. Defining both creates:
- Interoperability problems: `S7::S7_inherits(x, surveycore::survey_calibrated)` returns FALSE for surveywts-produced objects
- Export collisions if both packages are loaded and users type `survey_calibrated`
- Confusion: two classes named `survey_calibrated` in the ecosystem

The `@calibration` property on surveycore's class suggests it was designed to hold calibration provenance. Whether surveywts should (a) use surveycore's class directly, (b) subclass it, or (c) define its own class with a different name is an architectural decision that must be made before any implementation begins.

Options:
- **[A]** Use `surveycore::survey_calibrated` directly — surveywts is the package that fills in `@calibration` and `@metadata@weighting_history`; no new class defined in surveywts — Effort: medium (rewrite §V, §I deliverables, §II class hierarchy), Risk: low, Impact: single ecosystem class; no namespace conflict
- **[B]** Define `surveywts::survey_calibrated` as a child class of `surveycore::survey_calibrated` — extends it with surveywts-specific properties — Effort: medium, Risk: medium (double inheritance adds complexity), Impact: distinguishable class; inherits surveycore dispatch
- **[C]** Keep spec as-is (define `surveywts::survey_calibrated` as a peer class extending `survey_base`) — Effort: low, Risk: high (naming collision with surveycore's class; ecosystem confusion)

**Recommendation: A** — The surveyverse ecosystem should have one calibrated survey class. surveycore already owns it. surveywts' job is to produce properly configured instances of that class, not to redefine it. The `@calibration` property can hold calibration provenance if needed, or be left NULL with history tracked in `@metadata@weighting_history` (already implemented in surveycore).

---

**Issue 30: `surveycore::survey_calibrated` S7 validator is more permissive than spec requires — test items 8 and 9 in §XIII will fail**
Severity: BLOCKING
Violates the testing contract: the spec's validator behavior tests are written for a validator that does not exist in the actual class.

surveycore's `survey_calibrated` validator:
1. Allows NA weights — checks `non_na <- wt_col[!is.na(wt_col)]` and only errors if `length(non_na) == 0` (ALL weights NA). Individual NA weights are permitted.
2. Uses error classes `surveycore_error_*` — NOT `surveywts_error_*`

The spec's §V validator and test plan both assert:
- Test #8: validator rejects non-positive weights → `class = "surveywts_error_weights_nonpositive"` (actual class: `surveycore_error_weights_nonpositive`)
- Test #9: validator rejects NA in weight column → `class = "surveywts_error_weights_na"` (surveycore's validator does NOT reject individual NAs — it only rejects all-NA)

If surveywts uses `surveycore::survey_calibrated` (Resolution A from Issue 29), both tests are wrong: wrong error classes (surveycore's not surveywts'), and test #9 cannot pass because the NA rejection behavior specified doesn't exist.

Options:
- **[A]** If using surveycore's class (Issue 29 option A): update test items #8 and #9 to use `surveycore_error_*` class names; remove test #9 or change it to test "all-NA weights rejected" instead of "single NA rejected"; accept that per-NA validation happens at the function call level, not the class validator — Effort: low, Risk: low, Impact: correct tests
- **[B]** If defining a surveywts subclass (Issue 29 option B): add a surveywts-specific validator that enforces NA rejection and uses `surveywts_error_*` classes — Effort: medium, Risk: low, Impact: spec's validator tests work as written
- **[C] Do nothing** — Tests will fail; NA protection is silently absent if surveycore's class is used

**Recommendation: A** — Consistent with Issue 29 recommendation. The function-level validation (`.validate_weights()`) already enforces NA rejection before any calibrated object is created; the class validator doesn't need to duplicate it.

---

#### Section: V / XI (Constructor Contract)

**Issue 31: `.calibrate_engine()` returns `numeric vector` but calling functions need convergence metadata for history entries**
Severity: BLOCKING
Internal spec inconsistency: the return type stated in §XI cannot satisfy the history contract stated in §IV.

§XI states: `.calibrate_engine()` "Returns: numeric vector of calibrated weights."

But §IV history entry format requires:
```r
convergence = list(
  converged     = TRUE,
  iterations    = 12L,
  max_error     = 0.0003,
  tolerance     = 1e-6
)
```

If `.calibrate_engine()` only returns a weight vector, the calling function (`calibrate()`, `rake()`, `poststratify()`) has no way to populate `iterations` or `max_error` — these are computed inside the engine. The calling function would have to re-run the convergence computation separately, which is wasteful and fragile.

This is not a minor ambiguity — if the engine only returns weights, the history entry's `convergence` block cannot be correctly populated for iterative methods.

Options:
- **[A]** Change return type to a named list: `list(weights = numeric_vector, convergence = list(converged, iterations, max_error, tolerance))` — Effort: low (one-line spec change), Risk: low, Impact: convergence metadata available to the caller for history construction
- **[B]** Remove convergence metadata from the history entry for non-convergence-error cases; only store `list(converged = TRUE, tolerance = control$epsilon)` without `iterations` or `max_error` — Effort: low, Risk: medium (loses diagnostic value), Impact: simpler engine, less informative history
- **[C] Do nothing** — Caller cannot populate `iterations` and `max_error`; either lies in the history or is always NA/0

**Recommendation: A** — One line of spec text to change. The convergence metadata is genuinely useful for diagnosing weighting problems.

---

#### Section: II.b (Package Dependencies)

**Issue 32: `anesrake` not listed in DESCRIPTION `Suggests` despite test #24 requiring it**
Severity: REQUIRED
Violates quality gate: "`devtools::check()` passes: 0 errors, 0 warnings, ≤2 notes."

§XIII rake() test plan item #24: "Numerical correctness — method = 'anesrake' matches `anesrake::anesrake()` within 1e-8 tolerance (`skip_if_not_installed("anesrake")`, inside the test block)."

§II.b `Suggests` lists only: `survey (>= 4.2-1)` and `testthat (>= 3.2.0)`. `anesrake` is absent. Using `skip_if_not_installed("anesrake")` inside a test block is standard, but the package should still appear in `Suggests` per `r-package-conventions.md` — otherwise `R CMD check --as-cran` raises a NOTE about an undeclared suggested package.

Also: the vendored `R/vendor/rake-anesrake.R` mentioned in the decisions log (from the `method = "anesrake"` design session) is not listed in §II.c Vendored Code. §II.c only lists `calibrate-greg.R` and `calibrate-ipf.R`. If the anesrake algorithm is also vendored, it needs an entry in §II.c, a VENDORED.md row, and GPL-2+ license compatibility confirmation.

Options:
- **[A]** Add `anesrake (>= 0.92)` to `Suggests` in §II.b; add `R/vendor/rake-anesrake.R` entry to §II.c vendored code table — Effort: low, Risk: low, Impact: complete dependency declaration and attribution
- **[B]** Remove test #24 (don't cross-validate against anesrake) — Effort: low, Risk: medium (anesrake method loses numerical oracle), Impact: one less quality assurance test
- **[C] Do nothing** — `R CMD check --as-cran` note; VENDORED.md incomplete

**Recommendation: A** — Two lines in §II.b and one row in §II.c. Both are required for a CRAN-clean package.

---

#### Section: IV (Weighting History)

**Issue 33: `step` increment rule not specified — implementer must guess how to determine step numbers in chained operations**
Severity: REQUIRED
Violates `engineering-preferences.md §5` — explicit over implicit.

§IV shows `step = 1L` in the history entry example and test items say "step number increments correctly across chained calls." But no rule is stated for how `step` is determined. The implementer must know:

1. Where to read the existing step count (different for `data.frame` vs `weighted_df` vs survey objects)
2. Whether step = position in final history (1-based) or something else

The rule is: `step = length(existing_history) + 1L`, where `existing_history` is:
- `list()` for a plain `data.frame` input (no prior history)
- `attr(data, "weighting_history")` for a `weighted_df` input
- `data@metadata@weighting_history` for a survey object input

Without this rule, an implementer reading only §IV would hardcode step = 1 or use a session counter, both of which break on chained calls.

Options:
- **[A]** Add to §IV: "The `step` value is `length(.get_history(input)) + 1L`, where `.get_history()` extracts the current history list from the input object. For plain `data.frame`: `list()` (step = 1). For `weighted_df`: `attr(data, 'weighting_history')`. For survey objects: `data@metadata@weighting_history`." — Effort: trivial, Risk: low, Impact: unambiguous step numbering
- **[B]** Add a single sentence: "step = position of this entry in the final weighting_history list" — Effort: trivial, Risk: low (implicit about how to compute it)
- **[C] Do nothing** — Implementer guesses; step numbers wrong in chained calls; test #19 and #20 fail unpredictably

**Recommendation: A** — The rule is simple to state and critical to get right.

---

#### Section: X / XI (Diagnostic Functions — Weight Validation)

**Issue 34: Diagnostic functions don't specify whether `.validate_weights()` is called — `weights_nonpositive` and `weights_na` absent from error table and test plan**
Severity: REQUIRED
Violates `engineering-preferences.md §4` — edge case behavior (NA weights, zero weights) must be explicitly specified.

Section X lists these errors for `effective_sample_size()`, `weight_variability()`, `summarize_weights()`:
- `surveywts_error_unsupported_class`
- `surveywts_error_weights_required`
- `surveywts_error_weights_not_found`
- `surveywts_error_weights_not_numeric`

Notably absent: `surveywts_error_weights_nonpositive` and `surveywts_error_weights_na`. Two scenarios are possible:

1. **Diagnostics call `.validate_weights()`** → these errors ARE thrown but are missing from the error table and test plan (a spec omission)
2. **Diagnostics do NOT call `.validate_weights()`** → NA weights would silently produce `NA` ESS/CV; nonpositive weights would produce meaningless statistics (this may be intentional for diagnostics as "inspect-any-weights" tools)

Neither behavior is stated. The `summarize_weights()` use case (inspecting a broken weight column to diagnose problems) arguably benefits from NOT validating — but `effective_sample_size()` returning NA silently is a user experience problem.

Options:
- **[A]** Specify that diagnostics call `.validate_weights()` before computing; add `weights_nonpositive` and `weights_na` to the error table and test plan (7c, 7d) — Effort: low, Risk: low, Impact: consistent behavior with calibration functions; fails loudly on bad weights
- **[B]** Specify that diagnostics do NOT validate positivity/NA; document that they return `NA` or unusual values for NA/nonpositive inputs; add edge case tests verifying this silent behavior — Effort: low, Risk: low, Impact: more permissive; useful for "diagnose a broken weight column" workflow
- **[C] Do nothing** — Behavior undefined; implementer decides; tests don't cover the edge case

**Recommendation: A** — Consistent with the package's strict validation philosophy. Users can always check a column directly without calling `effective_sample_size()`.

---

#### Section: VII / XII.C (rake() — Convergence Error Message)

**Issue 35: `rake()` convergence error message is incorrect for `method = "anesrake"` — references `epsilon` and "margin error" instead of `improvement` and chi-square**
Severity: REQUIRED
Internal spec inconsistency: §VII specifies anesrake convergence criterion (chi-square improvement) but §XII.C error message references epsilon/margin-error (survey method criterion).

§XII.C `surveywts_error_calibration_not_converged` message for `rake()`:
```
x: Raking did not converge after {control$maxit} full sweeps.
i: Maximum margin error: {max_error} (tolerance: {control$epsilon}).
v: Increase {.code control$maxit}, relax {.code control$epsilon}, or verify margin totals...
```

For `method = "survey"` this is correct. For `method = "anesrake"` (the **default method**):
- `control$epsilon` doesn't exist (triggers `surveywts_warning_control_param_ignored` if set)
- "Maximum margin error" is not the convergence metric — chi-square improvement is
- `v` bullet telling users to "relax `control$epsilon`" actively misleads them

The test for this error (#17 in rake() test plan) will snapshot the message. Since the default method is `"anesrake"`, the snapshot will capture a message mentioning `control$epsilon` which is inapplicable. A user reading it will be confused.

Options:
- **[A]** Make the error message method-dependent. For `method = "anesrake"`: `"i: Chi-square improvement: {improvement_pct}% (threshold: {control$improvement}%). v: Increase {.code control$maxit} or relax {.code control$improvement}."` For `method = "survey"`: keep existing message — Effort: low, Risk: low, Impact: accurate guidance per method
- **[B]** Use a generic message that works for both methods: `"i: Calibration failed to meet the convergence criterion after {control$maxit} iterations. v: Increase {.code control$maxit} or relax the convergence threshold ({.code control$improvement} for 'anesrake', {.code control$epsilon} for 'survey')."` — Effort: low, Risk: low, Impact: correct for both methods; less specific
- **[C] Do nothing** — Default method gives misleading error message; users misled into setting epsilon when they need improvement

**Recommendation: A** — Method-dependent messages are more informative and the implementation is straightforward (check `method` before building the message).

---

#### Section: VII (rake() — anesrake with no variables selected)

**Issue 36: `rake()` `method = "anesrake"`: behavior undefined when all variables pass the chi-square threshold in a sweep**
Severity: REQUIRED
Violates `engineering-preferences.md §4` — edge cases must be explicitly specified.

§VII behavior rule 4 states: "Variables where the chi-square p-value exceeds `control$pval` are skipped in that sweep." But if ALL variables are skipped in a sweep, the result is: 0% chi-square improvement, which is below `control$improvement` (0.01%), so the algorithm would immediately "converge" without making any adjustments.

The spec is silent on whether this counts as:
- **Convergence (success):** weights already satisfy margins; 0 adjustments needed
- **An error:** no variables selected is an anomalous condition
- **A warning:** converged without doing any work

In practice, if starting weights already satisfy the margins (or are close enough), immediate convergence is correct — you shouldn't require calibration when it's not needed. But this edge case has meaningful implications for the history entry (`convergence$iterations = 0` or 1?) and the `calibration_not_converged` error trigger.

Also: if `control$min_cell_n > 0` excludes all variables from raking entirely (all variables have sparse cells), the same situation arises — all variables excluded, no iteration possible.

Options:
- **[A]** Specify: if all variables pass chi-square threshold in sweep 1, this is convergence (success) with `convergence$converged = TRUE, convergence$iterations = 1L, convergence$max_error = 0`. `control$maxit = 0` remains a separate error per §II.d — Effort: trivial, Risk: low, Impact: explicit behavior
- **[B]** Specify: if no variables are selected in any sweep (either all pass chi-square OR all excluded by min_cell_n), issue `surveywts_warning_no_variables_raked` and return weights unchanged — Effort: low, Risk: low, Impact: more defensive; warns user that nothing happened
- **[C] Do nothing** — Edge case behavior is undefined; implementer decides

**Recommendation: A** — Immediate convergence is the correct interpretation. "Already calibrated" is a valid and common state. Add to §VII behavior rules.

---

#### Section: IX (adjust_nonresponse() — Output Contract)

**Issue 37: `adjust_nonresponse()` output does not specify whether the `response_status` column is retained in the returned object**
Severity: REQUIRED
Violates contract completeness — output column set is not fully specified.

§IX specifies: "Output contains only rows where `response_status == 1`." But it is silent on whether `response_status` itself remains as a column in the returned `weighted_df` or survey object. After filtering to respondents-only, the `response_status` column would be all-1 (constant). Two behaviors are possible:

1. **Retain** the column (all values = 1) — column is semantically meaningless post-filter but preserves round-trip fidelity
2. **Drop** the column — cleaner output; column was only relevant for the operation

This affects:
- The `weighted_df` attribute `weight_col` (no impact, but the column set changes)
- User code that accesses `result$responded` after the call
- Snapshot tests if print output shows column count

Options:
- **[A]** Specify that `response_status` column is **retained** in the output — Effort: trivial, Risk: low, Impact: simpler implementation (just filter rows, don't touch columns)
- **[B]** Specify that `response_status` column is **dropped** from the output — Effort: trivial, Risk: low, Impact: cleaner output; users can't accidentally use the all-1 column
- **[C] Do nothing** — Implementer decides; test snapshots capture the decision implicitly but not intentionally

**Recommendation: A** — Retaining is simpler to implement and avoids the problem of "silently removing a user's column." If a user wants to drop it, they can do so with `dplyr::select()` afterward.

---

#### Section: V / XI (Engineering Level)

**Issue 38: `.update_survey_weights(output_class = "survey_calibrated")` is dead code per §V**
Severity: SUGGESTION
Violates `engineering-preferences.md §3` — no abstraction layer without two real call sites.

§V states: "The calibration user-facing functions (calibrate(), rake(), poststratify()) call [.new_survey_calibrated()] when input is a survey object."

§XI defines `.update_survey_weights(design, new_weights_vec, history_entry, output_class = c("same", "survey_calibrated"))`.

The `"survey_calibrated"` value in `output_class` is never reached:
- Calibration functions use `.new_survey_calibrated()` (§V)
- `adjust_nonresponse()` uses `.update_survey_weights(output_class = "same")`
- For `survey_calibrated` input to `adjust_nonresponse()`, `"same"` returns `survey_calibrated` anyway

`output_class = "survey_calibrated"` exists but has no call site in the spec. This may be an artifact of an earlier design where `.update_survey_weights()` was the unified function. Keeping a dead code path adds confusion for implementers.

Options:
- **[A]** Remove `output_class` parameter from `.update_survey_weights()` — it always returns "same class"; calibration functions use `.new_survey_calibrated()` for class promotion — Effort: trivial, Risk: low, Impact: simpler contract; no dead code
- **[B]** Keep `output_class` but add a note: "The 'survey_calibrated' value is reserved for future use" — Effort: trivial, Risk: low, Impact: documents the dead code
- **[C] Do nothing** — Implementer may implement `output_class = "survey_calibrated"` path unnecessarily

**Recommendation: A** — This is contingent on Issue 29's resolution (if surveycore's class is used directly, the `.new_survey_calibrated()` function may also be refactored, at which point the relationship between these two helpers needs a fresh look).

---

#### Section: XI (Engineering Level)

**Issue 39: `.calibrate_engine()` `calibration_spec` format missing anesrake-specific fields**
Severity: SUGGESTION
Per the user's explicit goal of addressing every GAP — this is GAP #6 from §XIV.

The `calibration_spec` structure shown in §XI:
```r
list(
  type      = "ipf",           # or "linear", "logit", "poststratify", "anesrake"
  variables = list(...),
  cells     = list(...),       # for "poststratify" only
  total_n   = 1500,
  cap       = NULL
)
```

For `type = "anesrake"`, the spec doesn't include:
- `pval` (chi-square threshold for variable selection)
- `improvement` (convergence threshold)
- `min_cell_n` (minimum observations per cell)
- `variable_select` ("total", "max", "average")

These are anesrake-specific convergence and variable-selection parameters that the engine needs to implement the algorithm. If they're not in `calibration_spec`, the engine can't access them. They'd need to be passed through `control` instead, but the spec says `control` is a parameter alongside `calibration_spec` — it's not clear which parameters go where.

Options:
- **[A]** Add anesrake fields to the `calibration_spec` format, or document that `control` is the channel for these fields when `type = "anesrake"` — Effort: low, Risk: low, Impact: implementer can write the engine without ambiguity
- **[B]** Note: "GAP #6 — anesrake-specific fields will be refined during implementation" and leave as-is — Effort: trivial, Impact: known uncertainty; acceptable since GAP #6 acknowledges this
- **[C] Do nothing** — Implementer guesses which parameters go in `calibration_spec` vs `control`

**Recommendation: A** — The spec acknowledges this gap. Resolving it now is trivially low effort.

---

#### Section: VIII (Test Plan)

**Issue 40: `poststratify()` default `type = "count"` is not explicitly verified in any test**
Severity: SUGGESTION
Minor test coverage gap — the asymmetric default is mentioned in §VIII but not directly tested.

§VIII notes: `type = c("count", "prop")` with default `"count"` and comment "(Different from other functions — most common usage)." This asymmetry is a deliberate design choice that users need to know about. If the default were accidentally changed to `"prop"` in a future refactor, no test would catch it.

The happy path tests (#1–4) presumably use the default, but they don't assert `type = "count"` is being used (they just pass population with count targets). Test #13 (`# 13. Edge — type = "prop"`) tests the non-default.

Options:
- **[A]** Add a comment to happy path test #1: "Note: happy path uses default type = 'count'; population targets are counts (not proportions)." Add a test asserting the function call succeeds without specifying `type` and fails if population is proportions-formatted — Effort: trivial, Risk: low
- **[B]** Add a dedicated test: `# 1c. Happy path — type = "count" is the default (verify by passing count targets without explicit type argument)` — Effort: trivial
- **[C] Do nothing** — Default behavior is implicitly tested; asymmetry could regress silently

**Recommendation: B** — Explicit is better than implicit, especially for an asymmetric default.

---

## Summary (Pass 3)

| Severity | Count |
|---|---|
| BLOCKING | 3 |
| REQUIRED | 7 |
| SUGGESTION | 3 |

**Total new issues:** 13

**Open GAP resolutions included in this pass:**
- GAP #1: ✅ Confirmed properties (`@data`, `@metadata`, `@variables`, `@groups`, `@call`); see Issue 29 for implications
- GAP #2: ✅ `survey_weighting_history(x)` confirmed exported; `@metadata@weighting_history` already in surveycore
- GAP #3: ✅ `@variables$weights` confirmed as character scalar (column name)
- GAP #4: ✅ surveycore installed with all prerequisite features; update DESCRIPTION min version
- GAP #5: Already handled by test item 5b and quality gate
- GAP #6: See Issue 39 (SUGGESTION)

**Overall assessment:** Three passes of intensive review have progressively tightened this spec. The most critical finding of Pass 3 is Issue 29: `surveycore` already owns `survey_calibrated` with a different structure than the spec assumes — defining a parallel class in surveywts would create ecosystem fragmentation. Resolving this architectural question (use surveycore's class vs. define a new one) unlocks resolution of Issues 30 and 38 as well. The remaining issues are either mechanical fixes (add anesrake to Suggests, fix error message for anesrake convergence, specify step increment rule) or are needed before the spec can be considered implementation-ready. Issue 31 (engine return type) is a clean internal inconsistency with a clear fix. The spec remains excellent in breadth and detail — these are edge-of-the-design issues, not structural failures.

### Resolution Status (Pass 3)

| # | Title | Status |
|---|---|---|
| 29 | `surveycore` already defines `survey_calibrated` — namespace conflict | ✅ Resolved — use surveycore's class directly |
| 30 | surveycore validator more permissive than spec — test items #8 and #9 wrong | ✅ Resolved — updated to `surveycore_error_*` classes; test #9 = all-NA |
| 31 | `.calibrate_engine()` returns numeric vector but needs convergence metadata | ✅ Resolved — return type changed to `list(weights, convergence)` |
| 32 | `anesrake` not in Suggests despite test #24 requiring it | ✅ Resolved — added to Suggests; added `rake-anesrake.R` to §II.c |
| 33 | `step` increment rule not specified | ✅ Resolved — explicit rule added to §IV |
| 34 | Diagnostic functions don't specify `.validate_weights()` — two error classes missing | ✅ Resolved — diagnostics call `.validate_weights()`; error table and tests updated |
| 35 | `rake()` convergence error message incorrect for `method = "anesrake"` | ✅ Resolved — method-dependent message templates added to §XII.C |
| 36 | `rake()` anesrake: behavior undefined when all variables pass chi-square threshold | ✅ Resolved — immediate convergence = success; `surveywts_message_already_calibrated` emitted |
| 37 | `adjust_nonresponse()` output doesn't specify whether `response_status` column retained | ⏸ Deferred — `adjust_nonresponse()` output contract review to its own session |
| 38 | `.update_survey_weights(output_class = "survey_calibrated")` is dead code | ✅ Resolved — `output_class` parameter removed from spec |
| 39 | `.calibrate_engine()` `calibration_spec` missing anesrake-specific fields | ✅ Resolved — noted that anesrake params travel through `control`, not `calibration_spec` |

---

## Spec Review: phase-0 — Pass 4 (2026-03-04)

### Focus: Missing Edge Case Tests in §XIII

This pass audits the §XIII test catalog against the spec's own behavior rules. Every item below identifies a behavior explicitly stated in §II–X that has no corresponding test item in §XIII.

---

#### Section: XIII / §II.d — `calibrate()` and `rake()`

**Issue 40: `control$maxit = 0` has no test item in `calibrate()` or `rake()` test lists**
Severity: BLOCKING
§II.d explicitly states: "`control$maxit = 0` is treated as invalid: the algorithm never runs and immediately throws `surveywts_error_calibration_not_converged` **with a note that 0 iterations means no calibration was attempted**." This is a distinct trigger with distinct message text from the ordinary non-convergence case (existing items 14 for calibrate, 17 for rake). If only the ordinary non-convergence case is tested, an implementer who handles `maxit = 0` generically (falling through to the same error path without the specific note) will pass all tests while the API contract is silently broken.

Options:
- **[A]** Add test items to both functions' §XIII test lists: `# 14b. Error — calibration_not_converged triggered by control$maxit = 0 (distinct message note)` for calibrate() and a matching item for rake() — Effort: trivial, Risk: low, Impact: contract verified; snapshot tests will catch message differences
- **[B] Do nothing** — `maxit = 0` falls through to the generic non-convergence error; the distinct message note is never verified

**Recommendation: A** — The spec explicitly calls this out as a distinct error state. The message difference is the entire point: users who pass `maxit = 0` by accident get a clearer diagnostic than users who hit the iteration limit.

---

#### Section: XIII / §IV — `weighted_df` class tests

**Issue 41: `dplyr_reconstruct.weighted_df()` after rename has no test item**
Severity: BLOCKING
§IV behavior rule 3 is explicit: "Renaming the weight column is treated the same as dropping it: `dplyr_reconstruct` does not detect renames and will trigger rule 2 above." The §XIII class test list only covers `select(-weight_col)`. There is no test item for `dplyr::rename(df, new_name = weight_col)`. A correct implementation of `dplyr_reconstruct` will pass the select test regardless of whether the rename case is handled correctly.

Options:
- **[A]** Add test item `# 2b. dplyr_reconstruct — rename(weight_col → new_name) → plain tibble + warning` to the §XIII class test list — Effort: trivial, Risk: low, Impact: rename behavior is verified
- **[B] Do nothing** — rename behavior is implicitly "covered" by the same code path as dropping; users who rely on the rename warning may find it works or not depending on implementation

**Recommendation: A** — §IV explicitly specifies this behavior and it requires an explicit test.

---

#### Section: XIII / §IV — `weighted_df` class tests

**Issue 42: `print.weighted_df()` empty-history snapshot has no test item**
Severity: BLOCKING
§IV states: "If `weighting_history` is empty, the history line reads: `# Weighting history: none`." The existing snapshot test (item 4) uses a verbatim 2-step history example from §IV. Item 5 only checks `is.list(attr(obj, "weighting_history"))`. No test item captures the "none" case. Since `print.weighted_df` is snapshot-tested, the "none" rendering is a testable, breakable contract with no test.

Options:
- **[A]** Add test item `# 4b. print.weighted_df — empty weighting_history renders "# Weighting history: none"` with a snapshot — Effort: trivial, Risk: low
- **[B] Do nothing** — the "none" branch of the print method is dead code from a testing perspective

**Recommendation: A** — One snapshot. The empty-history path is the first thing any new user sees when they construct a `weighted_df` directly via a calibration function before chaining.

---

#### Section: XIII / §IV — `weighted_df` class tests

**Issue 43: `weighted_df` class preservation through `filter()` and `mutate()` has no test**
Severity: REQUIRED
§IV specifies `dplyr_reconstruct.weighted_df()` as the mechanism for preserving class through dplyr verbs. Items 1 and 2 only exercise it via `select()`. `filter()` and `mutate()` that don't touch the weight column must also trigger `dplyr_reconstruct` and preserve the class — but these are entirely different dplyr dispatch paths. It is entirely possible to have a correct `dplyr_reconstruct` for `select` that fails for `filter` (e.g., if the method is only registered for the `select` generic rather than as a general reconstruct hook).

Options:
- **[A]** Add test items: `# 2c. dplyr_reconstruct — filter() preserving weight col → weighted_df` and `# 2d. dplyr_reconstruct — mutate() not touching weight col → weighted_df` — Effort: trivial, Risk: low
- **[B] Do nothing** — assumes dplyr_reconstruct is called identically for all verbs; this is true of dplyr internals but has surprised package authors before

**Recommendation: A** — Two tests; these are the most common dplyr operations users will run immediately after creating a `weighted_df`.

---

#### Section: XIII / §VII — `rake()` tests

**Issue 44: `control$variable_select = "average"` has no test item**
Severity: REQUIRED
§VII lists three valid values for `control$variable_select`: `"total"`, `"max"`, `"average"`. Item 23 tests `"max"` vs `"total"`. `"average"` is never tested. This is a valid code path through the vendored anesrake engine that has zero explicit coverage. If the implementation mishandles `"average"` (e.g., silently falls back to `"total"`), no test will catch it.

Options:
- **[A]** Add test item `# 23b. Happy path — control$variable_select = "average" produces valid calibrated weights (verify different variable selection order from "total")` — Effort: low, Risk: low
- **[B] Do nothing** — `"average"` is listed in the spec but coverage relies on anesrake's own test suite

**Recommendation: A** — Three valid values, only two tested. The gap is a one-liner to close.

---

#### Section: XIII / §II.d — Validation order

**Issue 45: Validation order is an API contract but has no test**
Severity: REQUIRED
§II.d states: "This ordering is part of the API contract and must not vary across implementations. Snapshot tests depend on it." The four validation steps are ordered: (1) class check, (2) empty data, (3) weights, (4) function-specific. But no §XIII test item constructs a case with two simultaneous errors at different priority levels to verify ordering. If an implementer accidentally validates weights before checking for empty data, no existing test will catch it — even the snapshot tests for individual errors can't detect ordering violations (they only test one error at a time).

Options:
- **[A]** Add a shared test item to the SE block (or as a separate item in each function's test list): `# SE-8. Validation order — 0-row data WITH invalid weight column throws empty_data (not weights_not_found)` — Effort: trivial, Risk: low, Impact: ordering contract is verified
- **[B] Do nothing** — ordering is implied; rely on code review to enforce it

**Recommendation: A** — The spec explicitly calls this an API contract. A single test item that puts SE-2 and SE-4 in tension is all that is needed.

---

#### Section: XIII / §VII — `rake()` tests

**Issue 46: `rake()` Format B input with a validation error is not tested**
Severity: REQUIRED
Items 15b (`population_level_missing`) and 15c (`population_level_extra`) cover level-validation errors in `rake()`. These presumably construct Format A margins. But `.parse_margins()` converts Format B → Format A before `.validate_population_marginals()` runs. The conversion path (B → A → validate) is distinct from the direct Format A path. A bug in `.parse_margins()` that produces structurally-valid-but-semantically-wrong Format A will pass all happy path tests and the Format A error tests, and only fail when Format B triggers a validation error.

Options:
- **[A]** Change one of items 15b or 15c to use Format B input (e.g., a Format B margins data frame containing a level absent from the data) — Effort: trivial, Risk: low, Impact: the B→A→validate path is exercised
- **[B]** Add a new test item: `# 15d. Error — population_level_extra via Format B margins (verify .parse_margins() → .validate_population_marginals() path)` — Effort: trivial
- **[C] Do nothing** — assumes .parse_margins() produces correct Format A; errors in the conversion are invisible

**Recommendation: A** — Modify an existing error item rather than adding a new one. Same coverage, no additional test count.

---

#### Section: XIII / §IX — `adjust_nonresponse()` tests

**Issue 47: Logical `response_status` has no happy path test**
Severity: REQUIRED
§IX states: "Must be `logical` or integer `0`/`1`. `1`/`TRUE` = respondent." `make_surveywts_data()` generates `responded` as integer. All happy path tests will therefore use integer. The logical type is an explicitly supported path with no test item. Item 10 tests bad types (triggers `response_status_not_binary`); item 10b tests factors. But correct handling of `TRUE`/`FALSE` is assumed, never verified.

Options:
- **[A]** Add test item `# 1b. Happy path — logical response_status (TRUE/FALSE; convert integer column to logical before calling)` — Effort: trivial, Risk: low
- **[B] Do nothing** — logical and integer 0/1 share the same condition in the implementation; coverage from integer tests is presumed sufficient

**Recommendation: A** — Two lines of test setup. The spec says logical is valid; that claim requires a test.

---

#### Section: XIII / §IX — `adjust_nonresponse()` tests

**Issue 48: Weight conservation WITH `by` grouping is not tested**
Severity: REQUIRED
Item 5 verifies `sum(weights_before) == sum(respondent_weights_after)` — globally, without `by`. The formula `w_new = w_i * (sum_all_h / sum_respondents_h)` guarantees conservation per cell, which implies global conservation by summation. But a global test can mask a cell-level implementation bug (e.g., using the wrong denominator in one cell but having errors cancel across cells). Conservation should also be verified cell-by-cell when `by` is non-NULL.

Options:
- **[A]** Add test item `# 5c. Weight conservation WITH by grouping — sum of weights within each by-cell is conserved` — Effort: low, Risk: low
- **[B] Do nothing** — global conservation implies cell conservation given the formula; test redundancy is unnecessary

**Recommendation: A** — The formula is simple but cell-level verification catches a different class of implementation bug than global verification. The by-grouping path is the primary use case for this function.

---

#### Section: XIII / §X — Diagnostics tests

**Issue 49: All-equal weights edge case missing from diagnostics tests**
Severity: REQUIRED
When all weights are equal, ESS = n exactly and CV = 0 exactly — these are mathematical identities that validate the formula implementation. `make_surveywts_data()` produces log-normal weights; item 1's hand-calculation test uses non-equal weights. The all-equal case verifies the formula reduces correctly at its boundary. Neither `effective_sample_size()` nor `weight_variability()` has this test.

Options:
- **[A]** Add test item `# 1b. All-equal weights — ESS = n and CV = 0 exactly (rep(1, n) or rep(k, n))` for both `effective_sample_size()` and `weight_variability()` — Effort: trivial, Risk: low
- **[B] Do nothing** — the formula is correct if item 1 passes; boundary identity is an exercise in algebra not implementation

**Recommendation: A** — Equal-weight input is the most common degenerate case in survey design (pre-weighting data). It takes one line to test.

---

#### Section: XIII / §X — Diagnostics tests

**Issue 50: `summarize_weights()` column order is not asserted**
Severity: REQUIRED
§X specifies a precise column order for `summarize_weights()` output: group columns, then `n`, `n_positive`, `n_zero`, `mean`, `cv`, `min`, `p25`, `p50`, `p75`, `max`, `ess`. Item 8 only checks "all columns present." Column order is part of the API contract — downstream code can reasonably use positional indexing. An implementer who produces columns in a different order (e.g., alphabetical, or ESS before mean) passes item 8 but breaks the documented contract.

Options:
- **[A]** Strengthen item 8: `# 8. summarize_weights() output has correct columns in specified order: expect_identical(names(result), c("n", "n_positive", ...))` — Effort: trivial, Risk: low
- **[B] Do nothing** — column order is enforced by code review; presence check is sufficient

**Recommendation: A** — One `expect_identical(names(result), c(...))` assertion. The spec gives an explicit ordered list.

---

#### Section: XIII / §IV.5 — History tests (all functions)

**Issue 51: History entry field completeness is not asserted — `convergence = NULL` for non-iterative functions unverified**
Severity: REQUIRED
§IV.5 defines 8 fields per history entry: `step`, `operation`, `timestamp`, `call`, `parameters`, `weight_stats`, `convergence`, `package_version`. History test items for all four functions only say "correct structure." Critically, `convergence` must be `NULL` for `poststratify()` and `adjust_nonresponse()` (non-iterative) and a populated list for `calibrate()` and `rake()`. If an implementer forgets to pass `convergence = NULL` for non-iterative functions, the history format is wrong but no test will catch it. Similarly, `package_version` being a non-empty character string is never verified.

Options:
- **[A]** Expand history structure test items to explicitly assert: (1) `convergence` is `NULL` for `poststratify()` and `adjust_nonresponse()`, (2) `convergence` is a list for `calibrate()` and `rake()`, (3) `package_version` is `as.character(packageVersion("surveywts"))`, (4) `timestamp` is POSIXct — Effort: low, Risk: low
- **[B] Do nothing** — "correct structure" is sufficient; `NULL` vs list is an implementation detail

**Recommendation: A** — The `convergence = NULL` distinction is a spec-defined behavioral contract, not an implementation detail. The history format is the primary audit trail for the package's value proposition.

---

#### Section: XIII / §II.d — Output contract

**Issue 52: Default weight column name `.weight` is never explicitly asserted**
Severity: REQUIRED
§II.d states: "When input is a plain `data.frame` and `weights = NULL`, the default weight column is named `'.weight'`. This is the authoritative definition of that default." Happy path item 1 for each calibration function tests `data.frame → weighted_df` but does not explicitly assert `attr(result, "weight_col") == ".weight"`. An implementer who names the column `"weight"` or `"wt"` will pass all happy path tests while violating the documented default.

Options:
- **[A]** Add an explicit assertion to each function's happy path item 1: `# 1. Happy path — ... (verify attr(result, 'weight_col') == ".weight" when weights = NULL and data is data.frame)` — Effort: trivial, Risk: low
- **[B] Do nothing** — the default is implied by the spec; test item 1 is sufficient

**Recommendation: A** — The spec calls this "the authoritative definition." One assertion per function (four functions). Zero ambiguity.

---

#### Section: XIII / §VII — `rake()` tests

**Issue 53: `rake()` `min_cell_n` exclusion path to "already calibrated" is not separately tested from chi-square path**
Severity: SUGGESTION
Item 26b tests the "already calibrated" message when all variables pass the chi-square threshold. But §VII rule 8 specifies the same message fires when variables are "excluded by `control$min_cell_n`." These are two distinct code paths in the anesrake engine leading to the same outcome. A bug that breaks the `min_cell_n` exclusion path (e.g., it skips the variable's sweep rather than counting it as "already calibrated") would not be caught by item 26b.

Options:
- **[A]** Add test item `# 26c. Message — already_calibrated via min_cell_n exclusion: set control$min_cell_n very large so all variables are excluded; verify surveywts_message_already_calibrated is emitted` — Effort: low, Risk: low
- **[B] Do nothing** — items 26b is sufficient; the distinction is an internal engine detail

**Recommendation: A** — Both paths lead to the same message but through different logic. Forty lines of test setup, zero risk.

---

#### Section: XIII / §VI — `calibrate()` tests

**Issue 54: Proportions-sum tolerance boundary is never tested**
Severity: SUGGESTION
§VI states proportions must sum to 1.0 "within `1e-6` tolerance." Item 13 tests the clearly-failing case (proportions that don't sum to 1). But the tolerance boundary itself is never verified: (a) proportions summing to `1.0 + 9e-7` should succeed (within tolerance), (b) proportions summing to `1.0 + 2e-6` should fail (outside tolerance). Without these boundary tests, an implementer could use `1e-4` as the tolerance and pass all existing tests.

Options:
- **[A]** Add test items: `# 13c. Happy path — proportions summing to 1.0 + 9e-7 succeeds (within 1e-6 tolerance)` and `# 13d. Error — population_totals_invalid for proportions summing to 1.0 + 2e-6 (outside tolerance)` — Effort: low, Risk: low
- **[B] Do nothing** — tolerance boundary is an implementation detail; the tolerance value is stated in the spec

**Recommendation: A** — Tolerance values in specs are wrong until tested. This applies equally to `rake()`.

---

### Summary (Pass 4)

| Severity | Count |
|---|---|
| BLOCKING | 3 |
| REQUIRED | 10 |
| SUGGESTION | 2 |

**Total new issues:** 15 (Issues 40–54)

**Focus of this pass:** §XIII test catalog completeness against the spec's own behavior rules. All issues above identify a behavior explicitly stated in §II–X with no corresponding test item in §XIII. No architectural issues were found in this pass.

### Resolution Status (Pass 4)

| # | Title | Status |
|---|---|---|
| 40 | `control$maxit = 0` has no test item in calibrate() or rake() | ✅ Resolved — items 14b (calibrate) and 17b (rake) added to §XIII |
| 41 | `dplyr_reconstruct` after rename has no test item | ✅ Resolved — item 2b added to §XIII class tests |
| 42 | `print.weighted_df` empty-history snapshot has no test item | ✅ Resolved — item 4b added to §XIII class tests |
| 43 | `weighted_df` class preservation through filter/mutate not tested | ✅ Resolved — items 2c–2g added (filter happy/0-row, mutate happy/values/drop) |
| 44 | `rake()` variable_select = "average" never tested | ✅ Resolved — item 23b added to §XIII rake tests |
| 45 | Validation order API contract has no test | ✅ Resolved — SE-8 added to standard error paths block |
| 46 | Format B + validation error code path not tested | ✅ Resolved — item 15b updated to use Format B input |
| 47 | Logical `response_status` happy path missing | ✅ Resolved — item 1b added to §XIII adjust_nonresponse tests |
| 48 | Weight conservation WITH by grouping not tested | ✅ Resolved — item 5d added to §XIII adjust_nonresponse tests |
| 49 | All-equal weights edge case missing from diagnostics | ✅ Resolved — item 1b added to §XIII diagnostics tests |
| 50 | `summarize_weights()` column order not asserted | ✅ Resolved — item 8 strengthened to assert column order |
| 51 | History entry `convergence = NULL` for non-iterative functions not verified | ✅ Resolved — items 14 (poststratify) and 17 (nonresponse) explicitly assert convergence = NULL; items 18 (calibrate) and 19 (rake) assert convergence is list |
| 52 | Default `.weight` column name never explicitly asserted | ✅ Resolved — added `.weight` assertion to item 1 of all four functions |
| 53 | `rake()` min_cell_n → already_calibrated path not separately tested | ✅ Resolved — item 26c added to §XIII rake tests |
| 54 | Proportions-sum tolerance boundary never tested | ✅ Resolved — items 13c and 13d added to §XIII calibrate tests |
| 40 | `poststratify()` default `type = "count"` not explicitly verified | ✅ Resolved — test item 1c added |
