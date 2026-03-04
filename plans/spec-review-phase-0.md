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

The current spec specifies a warning (`surveyweights_warning_population_cell_not_in_data`) with the behavior "the cell is ignored." This is a meaningful design decision about whether unexpected extra cells in the population silently proceed or halt. The spec correctly flags it for review — and Pass 1 is the right place to resolve it.

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
- **[A]** Add to Behavior Rules: "If `nrow(data) == 0`, error `surveyweights_error_empty_data`" — new error class, add to error table and Section XII — Effort: low, Risk: low, Impact: explicit contract
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
- **[A]** Specify that NA in any auxiliary/grouping variable is an error (`surveyweights_error_variable_has_na`); add to error tables and test plans — Effort: low, Risk: low, Impact: explicit; users must handle NAs before calling
- **[B]** Specify per-function behavior: NA treated as a level for calibration; NA rows excluded for adjustment; add this to each Behavior Rules section — Effort: medium, Risk: medium, Impact: more flexible but complex
- **[C] Do nothing** — Implementer decides; behavior is undocumented and may vary across functions

**Recommendation: A** — Consistent NA rejection with clear errors is safer and easier to test. Users cleaning survey data should know their population variables explicitly.

---

#### Section: VII–VIII (Categorical Restriction in rake/poststratify)

**Issue 7: Categorical-variable-only restriction is stated only for calibrate(), not rake() or poststratify()**
Severity: REQUIRED
The error `surveyweights_error_calibrate_variable_not_categorical` and the restriction "categorical (character or factor) variables only in Phase 0" appear only in Section VI (`calibrate()`). Sections VII (`rake()`) and VIII (`poststratify()`) have no analogous restriction or error.

IPF (rake) is also a categorical-variable method. Does `rake()` silently accept a numeric variable? Does `poststratify()` allow numeric strata? If so, what happens? If not, what is the error class?

Options:
- **[A]** Apply the same categorical restriction to `rake()` and `poststratify()`; either reuse `surveyweights_error_calibrate_variable_not_categorical` or introduce a more general `surveyweights_error_variable_not_categorical` — Effort: low, Risk: low, Impact: consistent behavior across calibration functions
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
The spec says "cells with fewer than 5 respondents" trigger `surveyweights_warning_class_near_empty`, and it flags this as: "⚠️ GAP: Confirm minimum cell size threshold (5 respondents). This is a methodological choice; cite a reference or make it configurable."

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
The `v` bullet for `surveyweights_error_calibrate_variable_not_categorical` reads:
> "v: Convert to factor or character, or use {.fn rake} for continuous auxiliary variables."

But `rake()` in Phase 0 also only supports categorical variables (IPF requires categorical margins). Suggesting `rake()` for continuous variables is factually incorrect and will mislead users.

Options:
- **[A]** Remove the rake() suggestion; change to: "Convert to factor or character before calibrating." — Effort: trivial, Risk: low, Impact: correct guidance
- **[B]** Change to: "Convert to factor or character. Continuous auxiliary variable calibration is not supported in Phase 0." — Effort: trivial, Risk: low, Impact: accurate and informative about Phase 0 scope
- **[C] Do nothing** — Users misled to try rake() and get the same error

**Recommendation: B** — More informative about Phase 0 scope.

---

#### Section: II / surveyweights-package.R (.onLoad specification)

**Issue 15: .onLoad() / S7::methods_register() not specified in the spec**
Severity: REQUIRED
`survey_calibrated` is an S7 class with an S7-registered print method (`S7::method(print, survey_calibrated) <- ...`). For S7 method dispatch to work at runtime, `S7::methods_register()` must be called in `.onLoad()`. The spec lists `surveyweights-package.R` in the source file organization table but specifies no content for it.

From CLAUDE.md: "S7::methods_register() in `.onLoad()`" — this rule exists at the package level but the spec is silent on it.

Options:
- **[A]** Add to the Architecture section: "surveyweights-package.R must include .onLoad() calling S7::methods_register()" — Effort: trivial, Risk: low, Impact: prevents runtime dispatch failure
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
- **[B]** Note that make_surveyweights_data() returns multi-variable data and happy path #1 implicitly tests this — Effort: trivial (one comment)
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
The last QA gate reads: "[ ] `surveycore-conventions.md` stub is filled in with Phase 0 conventions." No file named `surveycore-conventions.md` exists in this package's rules. The CLAUDE.md rule files include `surveyweights-conventions.md` and `testing-surveyweights.md` as stubs. This is likely a typo.

Options:
- **[A]** Replace with two gates: "[ ] `surveyweights-conventions.md` stub is filled in with Phase 0 conventions" and "[ ] `testing-surveyweights.md` stub is filled in with test_invariants() definition and data generator" — Effort: trivial
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

Section VI states: _"Levels present in `population` but absent from `data` are an error."_ This is the reverse of `surveyweights_error_population_level_missing` (which covers a data level absent from `population`). For GREG calibration, a population target for a level that has no sample observations is mathematically ill-posed — the calibration system is overdetermined. For rake (IPF), the same applies: a margin entry for a level not in the data cannot be calibrated. Both functions require this error to be raised.

The Section XII master error table has no class for this condition. The poststratify analog is `surveyweights_error_population_cell_not_in_data` — calibrate()/rake() have no equivalent.

The spec text for Section VI also says "Levels present in `population` but absent from `data` are an error" — twice stating behavior, zero times naming the class. An implementer reading this must invent a name, which defeats the purpose of the error class contract.

Options:
- **[A]** Add `surveyweights_error_population_level_extra` to the calibrate() error table with a message template; add to Section XII master table (thrown by `calibrate()` validation and implied for `rake()` via the "all calibrate() errors apply" reference); add test items to both calibrate() and rake() test plans — Effort: low, Risk: low, Impact: complete error contract
- **[B]** Reuse the poststratify name and generalize: rename `surveyweights_error_population_cell_not_in_data` to `surveyweights_error_population_level_extra` covering all three functions — Effort: low, Risk: low (poststratify is unimplemented)
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

**Issue 24: `surveyweights_error_population_totals_invalid` missing from Section VIII error table and from poststratify() and rake() test plans**
Severity: REQUIRED
Internal spec inconsistency: Section XII states this class is thrown by `calibrate()`, `rake()`, AND `poststratify()`, but Section VIII's per-function error table omits it entirely, and neither the rake() nor poststratify() test plans include an explicit test for it.

Section VIII population format specifies: _"For `type = 'prop'`: values in `target` must sum to 1.0 (within 1e-6)."_ The validation logic that enforces this would throw `surveyweights_error_population_totals_invalid` — but Section VIII's error table has no row for it. The rake() error table says "All errors from `calibrate()` apply" which implies it, but the rake() test plan items 11–23 (which explicitly list each error) do not include it. poststratify() is worse: neither the section error table nor the test plan mentions it.

calibrate() test item #18 `"Error — population_totals_invalid (prop does not sum to 1)"` exists ✅. Equivalent tests are absent from rake() and poststratify().

Options:
- **[A]** Add `surveyweights_error_population_totals_invalid` to the Section VIII error table with a message template for the poststratify context; add explicit test items to both the rake() test plan and poststratify() test plan (`# Error — population_totals_invalid (type="prop" targets do not sum to 1)`) — Effort: low, Risk: low, Impact: complete coverage
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
> `surveyweights_warning_class_near_empty` | `adjust_nonresponse()` | A weighting class cell has **fewer than 5 respondents**

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

`effective_sample_size()`, `weight_variability()`, `summarize_weights()` accept `data.frame`, `weighted_df`, `survey_taylor`, and `survey_calibrated`. The master error table (Section XII) lists `surveyweights_error_unsupported_class` as thrown by "All calibration/NR functions" — diagnostics are explicitly excluded. If a user passes a `matrix`, `list`, or an object from another survey package, they get an uninformative R error rather than a clear typed `surveyweights_error_unsupported_class`.

The Section X error tables don't include `unsupported_class`. The quality gates don't require it. This is consistent within the spec — it's an intentional omission — but it creates a user experience gap.

Options:
- **[A]** Add `surveyweights_error_unsupported_class` to the diagnostic error tables and Section XII master table; add test items to the diagnostics test plan — Effort: low, Risk: low, Impact: consistent defensive behavior across all package functions
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
