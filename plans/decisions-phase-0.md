# Decisions Log — surveyweights phase-0

This file records planning decisions made during phase-0.
Each entry corresponds to one planning session.

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
- **Decision:** A — error (`surveyweights_error_population_cell_not_in_data`)
- **Rationale:** Extra population cells indicate a misspecified frame; silent ignorance is a trap

**Q: Should 0-row input error or return vacuously (Issue 5)?**
- Options considered:
  - **Error (A):** calibration on empty data is mathematically undefined
  - **Return 0-row output (B):** vacuous success
- **Decision:** A — error (`surveyweights_error_empty_data`) for all four functions
- **Rationale:** Calibration/nonresponse adjustment has no meaningful result on empty data

**Q: How should NA in auxiliary variables be handled (Issue 6)?**
- Options considered:
  - **Consistent error across all functions (A):** `surveyweights_error_variable_has_na`
  - **Per-function behavior (B):** NA as level for calibration; exclusion for nonresponse
- **Decision:** A — uniform error; added `surveyweights_error_response_status_has_na` for the response indicator specifically
- **Rationale:** Consistent, explicit; users should clean NAs before calling

**Q: Does the categorical restriction apply to rake() and poststratify() (Issue 7)?**
- Options considered:
  - **Apply to rake(), allow numeric strata in poststratify() (A)**
  - **Apply to both (B)**
- **Decision:** A — renamed error to `surveyweights_error_variable_not_categorical` (used by calibrate and rake); poststratify documents that numeric strata are valid (it is a join-like operation)
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
- **Decision:** Yes — add `surveyweights_error_population_level_missing` to rake()'s
  error table (§VII) and message template (§XII.C).
- **Rationale:** If a raking variable has a data level absent from the margins, IPF
  silently produces wrong results. Consistent error behavior with `calibrate()` is safer
  than a silent asymmetry.

**Q: How to handle non-positive count targets (Issue 4)?**
- **Decision:** Extend `surveyweights_error_population_totals_invalid` to cover both
  `type = "prop"` and `type = "count"` cases. Update message templates in §XII.B, C, D.
- **Rationale:** The condition (invalid target value) is closely related. Extending the
  existing class keeps the error surface smaller.

### Code Quality Decisions

**Q: How should renaming the weight column work (Issue 5)?**
- **Decision:** `rename.weighted_df()` lives in `surveytidy` (not `surveyweights`).
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
- **Rationale:** The spec says "character or factor" but make_surveyweights_data() only
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
- **Decision:** Error immediately — fires `surveyweights_error_calibration_not_converged`
  with a note that 0 iterations means no calibration was attempted. Documented in §II.d.
- **Rationale:** Zero iterations is almost certainly a user mistake; fail loudly.

**Q: Duplicate rows in `population` for `poststratify()` (Issue 14)?**
- **Decision:** Error — add `surveyweights_error_population_cell_duplicate` to
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
  - **New class `surveyweights_error_population_level_extra` for calibrate()/rake() (A):** keeps poststratify's "cell" naming separate from calibrate/rake's "level" naming
  - **Rename poststratify's class to generalize (B):** fewer classes but conflates different concepts
- **Decision:** A — new `surveyweights_error_population_level_extra`; added to calibrate() prose, calibrate() error table, rake() behavior rules (new rule 4, renumbered 4→5→6→7), rake() error table, and master error table
- **Rationale:** Poststratify works on joint cells; calibrate/rake work on per-variable levels — the concepts are distinct enough to warrant separate classes

**Q: Should diagnostic functions (`effective_sample_size()`, `weight_variability()`, `summarize_weights()`) validate input class (Issue 28)?**
- Options considered:
  - **Add `unsupported_class` to diagnostic error tables and master table (A):** consistent defensive behavior across all package functions
  - **Document that diagnostics skip class validation (B):** documents current intent; simpler
- **Decision:** A — added `unsupported_class` to `effective_sample_size()` error table, added errors section to `summarize_weights()`, updated master table from "All calibration/NR functions" to "All package functions"
- **Rationale:** Users who pass wrong types to diagnostics deserve the same clear error they'd get from calibrate(); inconsistency creates confusion

### Outcome

All 8 Pass 2 issues resolved. Spec updated with: new error class
`surveyweights_error_population_level_extra` (calibrate/rake), population_totals_invalid
added to poststratify error table and test plans, explicit rake() test plan (replacing
ambiguous reference), diagnostics test plan completed (weights_not_numeric, unsupported_class),
poststratify weight validation error tests added, stale warning table threshold corrected,
parent validator assumption documented, and unsupported_class coverage extended to
diagnostics. Spec is now fully resolved and ready for implementation planning.

---
