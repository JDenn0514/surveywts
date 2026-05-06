# Decisions Log — surveywts phase-0

This file records planning decisions made during phase-0.
Each entry corresponds to one planning session.

---

## 2026-03-04 — `adjust_nonresponse()` Method Design and Phase Roadmap Naming

### Context

Design discussion covering three open questions about `adjust_nonresponse()`:
the vendor gap (GAP #5 in the spec), whether to expand Phase 2 method support,
and where calibration-based nonresponse adjustment should live and what it
should be called. Also surfaced a naming collision in the Phase 2/3 roadmap.

### Questions & Decisions

**Q: How should the weighting-class method be implemented — vendored or native?**
- Options considered: vendor `svrep::redistribute_weights()` (A); implement
  natively with `svrep` as numerical oracle (B)
- **Decision:** B — native implementation; `svrep::redistribute_weights()` as
  oracle in tests via `skip_if_not_installed("svrep")` inside affected blocks
- **Rationale:** The formula (`w_new = w * sum_all_h / sum_respondents_h` per cell)
  is four lines. Vendoring a package for a four-line formula is unnecessary
  complexity. Oracle pattern matches how `survey` is used for calibration tests.
- **Closes GAP #5** in spec §II.c.

**Q: Should Phase 2 include both `"propensity"` and `"propensity-cell"` methods?**
- Options considered: `"propensity"` only (A); both (B)
- **Decision:** B — Phase 2 adds both `"propensity-cell"` and `"propensity"` to
  `adjust_nonresponse()`. Both are Phase 2 API-stable stubs in Phase 0, using the
  same error class `surveywts_error_propensity_requires_phase2`.
- **Rationale:** Propensity-cell adjustment (estimate propensity → quintile cells →
  redistribute within cells) is arguably more common in practice than pure IPW
  (used by NHANES, for example). Including it in Phase 2 alongside `"propensity"`
  gives users a complete set of model-based nonresponse methods in one phase.
  Both share the same logistic-regression infrastructure; no extra phase cost.

**Q: Should calibration-as-nonresponse-adjustment be `adjust_nonresponse(method = "calibration")` or a separate function?**
- Options considered: `method = "calibration"` inside `adjust_nonresponse()` (A);
  separate `calibrate_nonresponse()` function in Phase 3 (B)
- **Decision:** B — separate `calibrate_nonresponse()` in Phase 3
- **Rationale:** Option A creates method-dependent required arguments: `by` for
  weighting-class/propensity methods, `variables` for calibration. That's a design
  smell — required arguments should not change based on another argument's value.
  Option B keeps `adjust_nonresponse()` as a coherent family (identify subgroups →
  redistribute weight). Calibration-based nonresponse is conceptually distinct: it
  uses the calibration machinery with internally-computed targets. It fits better
  alongside `calibrate_to_survey()` and `calibrate_to_estimate()` in Phase 3.

**Q: Does `calibrate_to_sample()` in Phase 2 collide with the Phase 3 nonresponse function name?**
- **Discovery:** Phase 2 already had a function called `calibrate_to_sample()`
  (calibrate replicate weights when benchmarks come from another survey design,
  mirroring `svrep::calibrate_to_sample()`). If Phase 3 adds a nonresponse
  calibration function, the names would collide.
- **Decision:** Rename Phase 2 `calibrate_to_sample()` → `calibrate_to_survey()`;
  Phase 3 nonresponse calibration → `calibrate_nonresponse()`
- **Rationale:** `calibrate_to_survey()` is more precise — the benchmarks come from
  a survey *design* object, not just "a sample". `calibrate_nonresponse()` clearly
  signals its purpose without ambiguity. Both names are full English words,
  consistent with the rest of the API. Eliminates any collision, including with
  `svrep::calibrate_to_sample()`.

### Outcome

Changes applied to:
- `plans/spec-phase-0.md`: §II.c vendor gap closed; §IX `adjust_nonresponse()`
  signature updated (add `"propensity-cell"` stub), behavior rule 1 updated,
  error table updated
- `plans/roadmap.md`: Phase 2 `calibrate_to_sample()` → `calibrate_to_survey()`;
  Phase 2 `adjust_nonresponse()` description updated to include `"propensity-cell"`;
  Phase 3 `calibrate_nonresponse()` added to deliverables and source file map;
  Phase 3 unlock updated for both propensity stubs
- `plans/error-messages.md`: `surveywts_error_propensity_requires_phase2`
  condition updated to cover both `"propensity"` and `"propensity-cell"` methods
- `plans/decisions-phase-0.md`: this entry

---

## 2026-03-04 — `rake()` Algorithm Design (method, cap, control)

### Context

Design discussion for adding multiple raking algorithm support to `rake()`.
The spec previously described a single IPF algorithm (vendored from `survey::rake()`).
This session designed the `method` argument and associated parameters.

### Questions & Decisions

**Q: Should `rake()` support multiple raking algorithms, and if so, which?**
- Options considered: single algorithm; `method` argument; separate functions
- **Decision:** `method = c("anesrake", "survey")` argument added to `rake()`
- **Rationale:** The two algorithms cover all practical survey weighting use cases.
  `"survey"`: standard IPF, fixed variable order, epsilon-based convergence —
  matches `survey::rake()`. `"anesrake"`: IPF with variable selection by
  chi-square discrepancy, improvement-based convergence, weight capping —
  matches `anesrake::anesrake()`.

**Q: Should weight capping be a top-level argument or buried in `control`?**
- Options considered: top-level `cap`; in `control`; method-specific
- **Decision:** Top-level `cap = NULL` argument applicable to both methods
- **Rationale:** Capping is a weight constraint (modeling decision), not an
  algorithm parameter. It is orthogonal to variable selection and convergence
  strategy. Applies at each IPF step (not post-hoc) for both methods — this
  differs from some implementations and must be documented in `@details`.

**Q: How should the `control` argument handle method-specific parameters?**
- Options considered: single flat `control` list; method-specific lists; no `control`
- **Decision:** Single `control = list()` in the signature; method-appropriate
  defaults applied internally before merging with user-supplied values:
  - `"anesrake"` defaults: `maxit = 1000, improvement = 0.01, pval = 0.05, min_cell_n = 0L, variable_select = "total"`
  - `"survey"` defaults: `maxit = 100, epsilon = 1e-7`
  - Parameters from the wrong method trigger `surveywts_warning_control_param_ignored`
- **Rationale:** Single list keeps the signature clean. Method-dependent defaults
  mean users don't need to override `maxit` when switching methods. Warning on
  wrong-method params catches mistakes without being fatal.

**Q: Why is `maxit` method-dependent (1000 vs 100)?**
- **Decision:** `maxit = 1000` for `"anesrake"` (matches package default);
  `maxit = 100` for `"survey"` (bump from survey package's 50; epsilon-based
  convergence stops early in practice)
- **Rationale:** The `"anesrake"` improvement criterion typically stops raking
  before 1000 iterations; the high limit is a safety net. The `"survey"` epsilon
  criterion stops earlier; 100 gives headroom for complex margin structures.

**Q: Which method should be the default?**
- Options considered: `"survey"` (simpler); `"anesrake"` (richer); no default
- **Decision:** `"anesrake"` as default
- **Rationale:** anesrake's variable selection and weight capping make it more
  robust for typical survey weighting scenarios. It is the dominant algorithm in
  political/opinion survey work, the primary use case for this package.

**Q: Which `anesrake` package arguments should be exposed?**
- **`pval`** → `control$pval = 0.05`; in `control` because rarely changed
- **`nlim`** → `control$min_cell_n = 0L`; meaningful for sparse data; naming
  parallels `min_cell` in `adjust_nonresponse()`
- **`choosemethod`** → `control$variable_select = "total"`; in `control` because
  "total" is almost always correct
- **`iterate`** → skipped; edge-case behavior, adds complexity with minimal benefit
- **`type` (anesrake)** → NOT exposed; naming collision with our `type` argument
  (prop/count); convergence behavior captured by `control$improvement = NULL` vs numeric
- **`cap`** → top-level argument (see above)
- **`maxit`** → in `control` with method-dependent default

**Q: How should `rake()` be documented — describe the algorithms or link out?**
- **Decision:** Brief description per method (enough to choose) + `@seealso` links
  to `survey::rake()` and `anesrake::anesrake()` + explicit documentation of
  any behaviors that diverge from the source package
- **Rationale:** Users who need the algorithm details read the source docs.
  Users who need to pick a method should not have to leave the help page.
  Divergent behavior (cap applied at each step, not post-hoc) is our design
  responsibility to document.

**Q: Should a third raking algorithm be added now or later?**
- **Decision:** No third algorithm in Phase 0 or later phases; two methods are sufficient
- **Rationale:** No compelling third algorithm identified. The two methods cover
  the practical landscape. Defer to a future phase if user demand arises.

### Outcome

Changes applied to:
- `plans/spec-phase-0.md` (v0.2 → v0.3): §VII rake() signature, argument table,
  output contract, behavior rules (new rules 4–7 + control defaults table),
  error/warning table, §II.d control merge semantics, §XI `.calibrate_engine()`,
  §XII.G new warning template, §XIII rake() test plan (items 21–26)
- `plans/impl-phase-0.md` (v1.1 → v1.2): PR 6 files, acceptance criteria, notes
- `plans/error-messages.md`: new `surveywts_warning_control_param_ignored` row
- `plans/decisions-phase-0.md`: this entry

---

## 2026-02-27 — Stage 3 Spec Resolution (all 20 review issues)

### Context

Resolving all issues from `plans/spec-review-phase-0.md` (Pass 1). The spec
was architecturally sound but had 5 blocking issues, 10 required issues, and
5 suggestions to address before implementation could begin.

### Questions & Decisions

**Q: Should argument order be fixed in calibrate(), rake(), poststratify() (Issue 1)?**
- Options considered:
  - **Fix signatures now (A):** no implementation yet; zero cost
  - **Add a code-style.md exception (B):** weakens the rule permanently
- **Decision:** A — fix all three signatures
- **Rationale:** Required by `code-style.md §4`; breaking change to fix after implementation

**Q: How should survey_calibrated print method determine the variance label (Issue 2)?**
- Options considered:
  - **Hardcode "Taylor linearization" (A):** honest for Phase 0 (only survey_taylor input accepted)
  - **Add @variance_method property (B):** forward-compatible but adds complexity
- **Decision:** A — hardcode for Phase 0; document that Phase 1 revisits
- **Rationale:** Phase 0 only accepts survey_taylor and survey_calibrated input; hardcoding is correct

**Q: Should poststratify() warn or error for population cells not in data (Issue 4)?**
- Options considered:
  - **Error (A):** forces explicit alignment; prevents silent misspecification
  - **Warning (B):** permissive; users may not notice misspecification
- **Decision:** A — error (`surveywts_error_population_cell_not_in_data`)
- **Rationale:** Extra population cells indicate a misspecified frame; silent ignorance is a trap

**Q: Should 0-row input error or return vacuously (Issue 5)?**
- Options considered:
  - **Error (A):** calibration on empty data is mathematically undefined
  - **Return 0-row output (B):** vacuous success
- **Decision:** A — error (`surveywts_error_empty_data`) for all four functions
- **Rationale:** Calibration/nonresponse adjustment has no meaningful result on empty data

**Q: How should NA in auxiliary variables be handled (Issue 6)?**
- Options considered:
  - **Consistent error across all functions (A):** `surveywts_error_variable_has_na`
  - **Per-function behavior (B):** NA as level for calibration; exclusion for nonresponse
- **Decision:** A — uniform error; added `surveywts_error_response_status_has_na` for the response indicator specifically
- **Rationale:** Consistent, explicit; users should clean NAs before calling

**Q: Does the categorical restriction apply to rake() and poststratify() (Issue 7)?**
- Options considered:
  - **Apply to rake(), allow numeric strata in poststratify() (A)**
  - **Apply to both (B)**
- **Decision:** A — renamed error to `surveywts_error_variable_not_categorical` (used by calibrate and rake); poststratify documents that numeric strata are valid (it is a join-like operation)
- **Rationale:** IPF requires categorical margins; poststratify is a cell-join, not a regression calibration

**Q: What is the computational foundation — full delegation to survey package or independent implementation (Architectural)**
- Options considered:
  - **Full delegation:** survey in Imports; computations delegated at runtime
  - **Validation wrapper:** algorithms implemented independently; survey in Suggests for tests only
- **Decision:** Validation wrapper — algorithms implemented from vendored code; survey stays in Suggests
- **Rationale:** Maintains independence from survey at runtime; vendored code from survey package provides the validated algorithm foundation with explicit attribution

**Q: How should vendored code be organized (Architectural)**
- Options considered:
  - **R/vendor/ directory with attribution comment blocks and VENDORED.md**
- **Decision:** Phase 0 vendors two algorithms: GREG/logit calibration from `survey::calibrate()` → `R/vendor/calibrate-greg.R`; IPF from `survey::rake()` → `R/vendor/calibrate-ipf.R`. `adjust_nonresponse()` reference TBD (GAP #5).
- **Rationale:** Mirrors surveycore pattern; provides auditability and explicit attribution

**Q: What should the min_cell threshold be for class_near_empty warning, and is 5 grounded in survey or anesrake (Issue 11)?**
- Options considered:
  - **5 respondents (original spec):** not grounded in any reference package
  - **Both count + adjustment factor (A):** `control = list(min_cell = 20, max_adjust = 2.0)`
- **Decision:** A — dual threshold: `min_cell = 20` (per NAEP methodology) and `max_adjust = 2.0` (per `survey::sparseCells()` convention). Either condition triggers the warning. Both user-configurable via `control` argument.
- **Rationale:** The threshold of 5 has no methodological grounding in either `survey` or `anesrake`. The `survey` package uses an adjustment factor threshold, not a count. NAEP uses ≥20 as the count threshold. Dual threshold is more methodologically complete.

**Q: What does "summarized" mean for parameters$population in history entries (Issue 10)?**
- Options considered:
  - **Store full population argument as-is (A)**
  - **Store variable names + target counts only (B)**
- **Decision:** A — store full population argument. For rake() with long-format input, convert to named-list form (Format A) before storing.
- **Rationale:** Auditability is the stated goal; population targets are small in practice (few variables × few levels)

### Outcome

All 20 review issues resolved. Spec updated with: corrected argument signatures,
vendoring section (Section II.c), package dependencies section (Section II.b),
.onLoad() requirement, dual-threshold control argument for adjust_nonresponse(),
renamed error classes, explicit NA/0-row/categorical error contracts, extended
test plans, and VENDORED.md quality gate. Spec is ready for implementation planning.

---

## 2026-02-28 — Stage 3 Plan Resolution (12 review issues)

### Context

Resolving all 12 issues from `plans/plan-review-phase-0.md` (Pass 1). The plan
was structurally sound but had 1 blocking issue, 6 required issues, and 5
suggestions to address before implementation could begin.

### Questions & Decisions

**Q: How should `print.weighted_df()` in PR 3 access stats before `.compute_weight_stats()` exists (Issue 1)?**
- Options considered:
  - **Inline in PR 3, refactor in PR 4 (A):** ~4 lines; PR 4 extracts to shared helper
  - **Move helper bootstrap to PR 3 (B):** same two-PR cost
  - **Merge PR 3 and PR 4 (C):** violates one-logical-unit-per-PR rule
- **Decision:** A — inline stats in PR 3; PR 4 refactors to `.compute_weight_stats()`
- **Rationale:** Common pattern: inline first, extract when a second call site appears

**Q: How should CI install non-CRAN surveycore (Issue 2)?**
- Options considered:
  - **`Remotes:` field in DESCRIPTION (A):** standard surveyverse pattern; removed before CRAN
  - **`extra-packages:` in CI YAML (B):** keeps DESCRIPTION clean
- **Decision:** A — `Remotes:` in DESCRIPTION
- **Rationale:** Standard surveyverse pattern; co-located with the Imports entry it governs

**Q: Should PR 6 depend on PR 5 (Issue 3)?**
- Options considered:
  - **Add PR 5 to Depends on (A)**
  - **Move integration test to its own PR (B)**
  - **Keep as stub (C)**
- **Decision:** A — PR 6 now `Depends on: PR 4; PR 5`
- **Rationale:** Integration test is a spec §XIII requirement, not optional

**Q: Should infrastructure PRs 1–4 have changelog entries (Issue 4)?**
- **Decision:** No changelog entries for PRs 1–4; entries begin with PR 5
- **Rationale:** `changelog/phase-0/` feeds user-facing NEWS.md; internal infrastructure does not belong there

**Q: Should `.validate_calibration_variables()` be a shared helper (Issue 6)?**
- **Decision:** Yes — added to `07-utils.R` with `context` parameter (`"Calibration"` / `"Raking"`)
- **Rationale:** DRY principle non-negotiable per `engineering-preferences.md §1`; ordered-factor support would require updating one place not two

**Q: How should the file numbering deviation from spec §II be handled (Issue 12)?**
- Options considered:
  - **Add one-sentence note to Overview (A)**
  - **Update spec to match plan numbering (B)**
- **Decision:** A — note added to Overview; spec remains as behavioral source of truth
- **Rationale:** Lower effort; spec §II describes behavior, not file organization

### Outcome

All 12 plan review issues resolved. Plan approved and ready for implementation.
Start with `/r-implement` at PR 1.

---

## 2026-03-03 — Pass 2 Plan & Spec Review (16 issues)

### Context

Adversarial review of `plans/spec-phase-0.md` (v0.2) and `plans/impl-phase-0.md` (v1.1)
focusing on missing edge cases in tests and DRY violations. Review conducted interactively
in four sections (Architecture, Code Quality, Tests, Remaining Gaps) with up to 4 issues
per section.

### Architecture Decisions

**Q: Where does `.validate_population_cells()` live (Issue 1)?**
- **Decision:** Fix the spec — remove it from §XI's shared-utils list; note it's a private
  helper in `04-poststratify.R`.
- **Rationale:** Helper used by only one function belongs co-located with that function.
  The impl plan was correct; the spec was inconsistent.

**Q: Add `.validate_calibration_variables()` to spec §XI (Issue 2)?**
- **Decision:** Yes — add full definition to spec §XI with signature, `context` parameter,
  and error classes thrown.
- **Rationale:** The impl plan introduced this shared helper but the spec never defined it.
  The spec is the truth document; helpers used by two+ functions must be spec'd.

**Q: Should `rake()` throw `population_level_missing` (Issue 3)?**
- **Decision:** Yes — add `surveywts_error_population_level_missing` to rake()'s
  error table (§VII) and message template (§XII.C).
- **Rationale:** If a raking variable has a data level absent from the margins, IPF
  silently produces wrong results. Consistent error behavior with `calibrate()` is safer
  than a silent asymmetry.

**Q: How to handle non-positive count targets (Issue 4)?**
- **Decision:** Extend `surveywts_error_population_totals_invalid` to cover both
  `type = "prop"` and `type = "count"` cases. Update message templates in §XII.B, C, D.
- **Rationale:** The condition (invalid target value) is closely related. Extending the
  existing class keeps the error surface smaller.

### Code Quality Decisions

**Q: How should renaming the weight column work (Issue 5)?**
- **Decision:** `rename.weighted_df()` lives in `surveytidy` (not `surveywts`).
  The spec §IV notes that renaming is treated as dropping in `dplyr_reconstruct`.
  The `weight_col_dropped` warning message in §XII.G adds a `"v"` hint to load
  `surveytidy` for rename-aware behavior.
- **Rationale:** `surveytidy` already has two methods for survey objects; `rename.weighted_df()`
  fits naturally as a third. The `surveyverse` metapackage loads both simultaneously,
  so load-order concerns are mitigated in practice.

**Q: `control` argument — merge with defaults or require complete list (Issue 6)?**
- **Decision:** Merge with defaults via `modifyList(list(maxit = 50, epsilon = 1e-7), control)`.
  `control$maxit = 0` fires `calibration_not_converged` immediately.
  Both behaviors documented in new §II.d subsection.
- **Rationale:** Standard R pattern; user-hostile to require complete lists.

**Q: Update spec file maps to match split-file structure (Issue 7)?**
- **Decision:** Update spec §II source file org and §XIII test file map to match the
  impl plan's per-function split (02-calibrate, 03-rake, 04-poststratify, 05-nonresponse,
  06-diagnostics).
- **Rationale:** Spec is the source of truth; it should reflect what was already decided.

**Q: Where does test item 19b (calibrate→rake chain) live (Issue 8)?**
- **Decision:** Move to rake's test list in spec §XIII (as `20b`), matching the impl plan.
  Add parenthetical noting rake is the chaining consumer.
- **Rationale:** The integration test exercises rake()'s ability to consume pre-weighted
  input; rake's test file is the right home.

### Test Decisions

**Q: Add factor variable tests to calibrate/rake (Issue 9)?**
- **Decision:** Add inline factor happy path test to each (item 1b in calibrate,
  item 1b in rake). Use `as.factor()` inline in the test.
- **Rationale:** The spec says "character or factor" but make_surveywts_data() only
  returns characters. Without this test, a character-only implementation ships silently.

**Q: Add `population_level_missing` test to rake() (Issue 10)?**
- **Decision:** Add test item 15b to rake's test list. Dual pattern required.
- **Rationale:** Every typed error class must have a test per testing-standards.md.

**Q: Test `population_totals_invalid` for `type = "count"` (Issue 11)?**
- **Decision:** Add count-target test items to calibrate (13b), rake (16b), and
  poststratify (8c).
- **Rationale:** The Issue 4 extension to the error class needs verification in all
  three functions.

**Q: Add `survey_taylor` input test to diagnostics (Issue 12)?**
- **Decision:** Add test item #3b to diagnostics test list.
- **Rationale:** Only `survey_calibrated` was tested; `survey_taylor` uses the same
  extraction path but tests an independent code path.

### Remaining Gap Decisions

**Q: `control$maxit = 0` behavior (Issue 13)?**
- **Decision:** Error immediately — fires `surveywts_error_calibration_not_converged`
  with a note that 0 iterations means no calibration was attempted. Documented in §II.d.
- **Rationale:** Zero iterations is almost certainly a user mistake; fail loudly.

**Q: Duplicate rows in `population` for `poststratify()` (Issue 14)?**
- **Decision:** Error — add `surveywts_error_population_cell_duplicate` to
  `.validate_population_cells()`, §VIII error table, §XII.D, and error-messages.md.
  Add test item 8d.
- **Note:** `survey::postStratify()` silently uses the first match; this package
  deliberately diverges from that behavior. Silent wrong answers are worse than errors.
- **Rationale:** Duplicate population rows indicate a data entry error and produce
  ambiguous calibration targets.

**Q: Factor `response_status` in `adjust_nonresponse()` (Issue 15)?**
- **Decision:** Specify and test — add note to §IX that factor columns are not binary
  regardless of levels. Add test item 10b. Update §XII.E message to include class info.
- **Rationale:** The error already fires via is.logical()/is.integer(), but without a
  test it can regress and without spec guidance the message is confusing.

**Q: Specify validation order (Issue 16)?**
- **Decision:** Add fixed validation order to §II.d: class check → empty data →
  weights → function-specific. This is part of the API contract.
- **Rationale:** Snapshot tests depend on which error fires first. Deterministic order
  prevents fragile tests.

### Outcome

All 16 issues resolved. Changes applied to:
- `plans/spec-phase-0.md`: §II file org, §II.d (control merge, validation order,
  maxit=0), §IV rename note, §VII rake error table, §VIII poststratify duplicate-cell,
  §IX factor status, §XI utility definitions, §XII.B/C/D/E/G message templates,
  §XIII test file map and all test lists
- `plans/impl-phase-0.md`: PR 4 and PR 7 acceptance criteria
- `plans/error-messages.md`: new classes, updated conditions
- `plans/decisions-phase-0.md`: this entry
- `plans/plan-review-phase-0.md`: Pass 2 section

Spec and implementation plan are now ready for implementation.

---

## 2026-02-27 — Stage 3 Spec Resolution (Pass 2 — 8 issues)

### Context

Resolving all 8 issues from `plans/spec-review-phase-0.md` (Pass 2). The spec
had one blocking issue (missing error class for population level absent from data),
five required issues (internal consistency gaps, missing test items), and two
suggestions (parent validator assumption, diagnostic class validation).

### Questions & Decisions

**Q: What error class should cover "population level present in margins/population but absent from data" (Issue 21)?**
- Options considered:
  - **New class `surveywts_error_population_level_extra` for calibrate()/rake() (A):** keeps poststratify's "cell" naming separate from calibrate/rake's "level" naming
  - **Rename poststratify's class to generalize (B):** fewer classes but conflates different concepts
- **Decision:** A — new `surveywts_error_population_level_extra`; added to calibrate() prose, calibrate() error table, rake() behavior rules (new rule 4, renumbered 4→5→6→7), rake() error table, and master error table
- **Rationale:** Poststratify works on joint cells; calibrate/rake work on per-variable levels — the concepts are distinct enough to warrant separate classes

**Q: Should diagnostic functions (`effective_sample_size()`, `weight_variability()`, `summarize_weights()`) validate input class (Issue 28)?**
- Options considered:
  - **Add `unsupported_class` to diagnostic error tables and master table (A):** consistent defensive behavior across all package functions
  - **Document that diagnostics skip class validation (B):** documents current intent; simpler
- **Decision:** A — added `unsupported_class` to `effective_sample_size()` error table, added errors section to `summarize_weights()`, updated master table from "All calibration/NR functions" to "All package functions"
- **Rationale:** Users who pass wrong types to diagnostics deserve the same clear error they'd get from calibrate(); inconsistency creates confusion

### Outcome

All 8 Pass 2 issues resolved. Spec updated with: new error class
`surveywts_error_population_level_extra` (calibrate/rake), population_totals_invalid
added to poststratify error table and test plans, explicit rake() test plan (replacing
ambiguous reference), diagnostics test plan completed (weights_not_numeric, unsupported_class),
poststratify weight validation error tests added, stale warning table threshold corrected,
parent validator assumption documented, and unsupported_class coverage extended to
diagnostics. Spec is now fully resolved and ready for implementation planning.

---

## 2026-03-04 — Stage 3 Plan Resolution (Pass 3 — 14 issues)

### Context

Resolving all 14 issues from `plans/plan-review-phase-0.md` (Pass 3). Two blocking
issues required immediate attention: a spec/plan contradiction on `.update_survey_weights()`
and a stale PR Map dependency statement. Twelve required/suggestion issues were systematic
coverage gaps in per-PR acceptance criteria (items missing from each function PR's AC,
a missing methods file, a missing vendored file in the Quality Gate, and a message class
not tracked in error-messages.md).

### Questions & Decisions

**Q: Should `.update_survey_weights()` have an `output_class` parameter (Issue 1)?**
- Options considered: remove from plan (A); add back to spec (B)
- **Decision:** A — remove `output_class` from plan; calibration functions call
  `.new_survey_calibrated()` directly; `.update_survey_weights()` is only used by
  `adjust_nonresponse()` (which never promotes class)
- **Rationale:** Spec was deliberately simplified in a prior session. Plan was not
  synchronized. Spec is authoritative.

**Q: Where should `S7::method(print, surveycore::survey_calibrated)` live (Issue 10)?**
- Options considered: add `R/methods-print.R` (A); document exception in `00-classes.R` (B)
- **Decision:** A — add `R/methods-print.R` to source file structure and PR 3 file list
- **Rationale:** code-style.md §2 has no minimum-methods exemption. A one-method file
  avoids tech debt and prevents future confusion about where to add Phase 1 S7 methods.

**Q: Should svrep be the numerical oracle for `adjust_nonresponse()` (Issue 8)?**
- Options considered: svrep oracle (A); hand-calculation only (B)
- **Decision:** A — consistent with the decisions log (2026-03-04) and spec §II.c;
  `svrep (>= 0.6)` added to DESCRIPTION Suggests in PR 1 AC; GAP #5 marked resolved
- **Rationale:** The decisions log explicitly named svrep. The spec §II.c text reflected
  that decision. PR 8 AC and spec §XIII item 5b had not been updated. Hand-calculation
  remains a complement, not a substitute.

### Outcome

All 14 Pass 3 issues resolved. Changes applied to:
- `plans/impl-phase-0.md` (v1.2 → v1.3): PR Map text (dependency clarification),
  source file structure (added `methods-print.R`), PR 1 AC (svrep in Suggests; GAP #5
  resolved), PR 1 Notes (GAP #5 resolution language), PR 3 files and AC (methods-print.R;
  surveycore error class names for items 8/9; ALL-NA trigger for item 9), PR 4 shared
  helpers and AC (remove output_class from .update_survey_weights()), PR 5 AC (item 1b
  factor; items 13/13b split; warning dual-pattern explicit), PR 6 AC (item 1b factor;
  items 16/16b split; item 23 variable_select; item 26b message class) and Notes (remove
  stub language), PR 7 AC (item 1c type="count" default; items 8b/8c split), PR 8 AC
  (22 test blocks; 7 error classes; item 10b factor; svrep oracle criterion), PR 9 AC
  (6 error classes; items 7b/7c/7d explicit; item 3b survey_taylor), Quality Gate
  (rake-anesrake.R in vendored-file check)
- `plans/error-messages.md`: new "Messages" section with
  `surveywts_message_already_calibrated`

Plan is approved and ready for implementation. Start with `/r-implement` at PR 3
(PRs 1 and 2 are already merged).

---

## 2026-03-04 — Stage 3 Spec Resolution (Pass 3 — 12 of 13 issues)

### Context

Resolving issues from `plans/spec-review-phase-0.md` (Pass 3). The pass surfaced one
architectural discovery (surveycore already owns `survey_calibrated`), two blocking
internal inconsistencies, and ten required/suggestion gaps. Issue 37 (`adjust_nonresponse()`
output column retention) was deferred to its own session.

### Questions & Decisions

**Q: Should surveywts define its own `survey_calibrated` or use surveycore's (Issue 29)?**
- Options considered: use surveycore's class directly (A); subclass it (B); define a peer class (C)
- **Decision:** A — use `surveycore::survey_calibrated` directly
- **Rationale:** surveycore already exports the class with `@calibration` property. Defining
  a parallel class would create two S7 classes with incompatible fully-qualified names,
  breaking `S7::S7_inherits()` across the ecosystem. surveywts' job is to produce
  correctly configured instances, not to redefine the class.

**Q: How do test items #8 and #9 change given surveycore's class is more permissive (Issue 30)?**
- **Decision:** Test #8 uses `surveycore_error_weights_nonpositive`. Test #9 changed to
  "all-NA weights rejected" (surveycore only errors if ALL weights are NA); class =
  `surveycore_error_weights_na`. Per-row NA/nonpositive validation remains in `.validate_weights()`
  at the function call level.

**Q: Should `.calibrate_engine()` return a numeric vector or a named list (Issue 31)?**
- **Decision:** Named list: `list(weights = <numeric>, convergence = list(converged, iterations, max_error, tolerance))`
- **Rationale:** Caller needs `iterations` and `max_error` to populate the history entry's
  convergence block. Engine is the only place that computes these.

**Q: Should rake() anesrake immediate convergence be silent or emit a message (Issue 36)?**
- Options considered: A (silent success); A+ (silent success + `cli_inform()`)
- **Decision:** A+ — emit `surveywts_message_already_calibrated` via `cli_inform()`
- **Rationale:** "Nothing happened" is easy to miss. The message surfaces the no-op at
  call time while remaining suppressible with `suppressMessages()`. Has a class for
  programmatic handling via `withCallingHandlers()`.

**Q: Should Issue 37 (adjust_nonresponse() output column retention) be decided now?**
- **Decision:** Deferred — the full output contract of `adjust_nonresponse()` (filtering,
  column retention, interaction with `weighted_df` attributes) merits its own session.

### Outcome

12 of 13 Pass 3 issues resolved. Changes applied to:
- `plans/spec-phase-0.md`: §I deliverables, §II class hierarchy and file org, §V (complete
  rewrite to use surveycore's class), §IV step increment rule, §VII behavior rule 8
  (already_calibrated), §X diagnostic error tables, §XI `.calibrate_engine()` return type
  and parameter routing note, `.update_survey_weights()` signature simplified, §XII.C
  method-dependent convergence messages, §XII.G `surveywts_message_already_calibrated`,
  §XIII test items 7c/7d (diagnostics), 26b (rake), 1c (poststratify), class test #8/#9
  updated, §XIV GAPs #1–4 and #6 marked resolved
- `plans/spec-review-phase-0.md`: Pass 3 resolution status table added
- `plans/decisions-phase-0.md`: this entry

Issue 37 (adjust_nonresponse output contract) deferred to a dedicated session.

---
