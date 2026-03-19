## Plan Review: phase-0 — Pass 1 (2026-02-27)

### New Issues

#### Section: PR 3 — Core Classes and Internal Constructor

**Issue 1: `print.weighted_df()` calls `.compute_weight_stats()` which does not yet exist in PR 3**
Severity: BLOCKING
Violates dependency ordering: a function defined in PR 3 references a helper defined in PR 4.

The verbatim `print.weighted_df()` output in spec §IV requires displaying weight statistics:

```
# Weight: wt_final (n = 1,500, mean = 1.00, CV = 0.18, ESS = 1,189)
```

Computing n, mean, CV, and ESS requires `.compute_weight_stats()`, which the plan places in `R/07-utils.R` (PR 4). When PR 3 is checked alone (before PR 4 exists), `R CMD check` will flag `.compute_weight_stats()` as an undefined function referenced in `R/00-classes.R`. The acceptance criterion `devtools::check() 0 errors` cannot be met in PR 3 as written.

The plan says PR 3 "Depends on: Surveycore prerequisite PR; PR 2" — it has no dependency on PR 4, and PR 4 cannot precede PR 3 (utils depend on classes).

Options:
- **[A]** Implement `print.weighted_df()` in PR 3 with the stats computed inline (~4 lines: `mean`, `sd/mean`, Kish ESS formula), then in PR 4 refactor to call `.compute_weight_stats()` — two PRs touch `00-classes.R`, but both pass `R CMD check` independently — Effort: low, Risk: low, Impact: resolves the blocking check failure; snapshot must be regenerated in PR 4 (see Issue 10)
- **[B]** Move `.compute_weight_stats()` to a bootstrap location in `00-classes.R` or `01-constructors.R` in PR 3, then in PR 4 move it to `07-utils.R` — same two-PR approach, same refactor cost — Effort: low, Risk: low
- **[C]** Merge PR 3 and PR 4 into a single PR — violates the "one logical unit per PR" rule but resolves the dependency — Effort: none, Risk: medium (larger PR, harder review)
- **[D] Do nothing** — PR 3 will never pass `R CMD check`; CI fails from the first function PR onward

**Recommendation: A** — Inline computation in the print method is 4 lines, not a meaningful duplication risk. The PR 4 refactor is trivial and the pattern is common (implement inline, extract later when the helper gets a second call site).

---

#### Section: PR 1 — Package Infrastructure

**Issue 2: CI workflow has no mechanism to install non-CRAN surveycore**
Severity: REQUIRED
Violates github-strategy.md: "CI: R-CMD-check required on `main` and `develop`; all PRs."

PR 1 adds `surveycore (>= 0.1.0)` to DESCRIPTION Imports. The existing `.github/workflows/R-CMD-check.yaml` uses `r-lib/actions/setup-r-dependencies@v2` with `use-public-rspm: true`. This action installs packages from CRAN and RSPM. If `surveycore` is not on CRAN, `setup-r-dependencies` will fail to find it and CI will error on every PR from PR 1 onward — before a single line of R is written.

The `setup-r-dependencies@v2` action reads a `Remotes:` field from DESCRIPTION to handle GitHub-hosted packages. Without it, there is no path to a passing CI run until surveycore reaches CRAN.

Options:
- **[A]** Add a `Remotes:` field to DESCRIPTION in PR 1 pointing to surveycore's GitHub location (e.g., `Remotes: surveyverse/surveycore`); update when the surveycore prerequisite PR is merged and the real repo/tag is confirmed — Effort: trivial, Risk: low, Impact: CI passes from PR 1 onward
- **[B]** Add a `needs: [surveycore]` pre-install step to the CI YAML in PR 1 via `extra-packages: github::surveyverse/surveycore` — Effort: trivial, Risk: low, Impact: same as A but keeps DESCRIPTION clean of `Remotes`
- **[C] Do nothing** — Every PR fails CI until surveycore is on CRAN

**Recommendation: A** — A `Remotes:` field in DESCRIPTION is the standard pattern for surveyverse packages under development and will be removed when the package reaches CRAN. Add it in PR 1 alongside the Imports entry.

---

#### Section: PR Map / PR 6

**Issue 3: PR 6 `Depends on` field omits PR 5, but the integration test requires `calibrate()` to exist**
Severity: REQUIRED
Violates dependency ordering: a stated acceptance criterion has an unmet dependency.

PR 6's acceptance criteria explicitly include:

> "Integration: `calibrate()` → `rake()` chain produces two-entry history with step numbers 1 and 2 and correct `operation` labels"

This test calls `calibrate()`, which is implemented in PR 5. PR 6's `Depends on` field says only "PR 4." If PRs 5, 6, and 7 are worked in parallel (which the plan suggests is possible), PR 6 could be merged before PR 5, and the integration test would fail or be left as a stub permanently.

The plan's Notes section says "If working in parallel, write the test as a stub and fill it in once PR 5 lands" — but the acceptance criteria list the integration test as a required pass, creating a contradiction.

Options:
- **[A]** Add `PR 5` to PR 6's `Depends on` field; the integration test is a full passing criterion, not a stub — Effort: trivial, Risk: low, Impact: correct dependency graph; removes ambiguity
- **[B]** Move the integration test to a separate PR 6.5 or PR 10 (integration test PR) that ships after both PR 5 and PR 6 — Effort: low, Risk: low, Impact: clean parallel development; integration test has its own home
- **[C]** Keep it as a stub with explicit acceptance criterion "integration test stub written; will be completed once PR 5 merges" — Effort: trivial, Risk: medium (stub may never be completed)

**Recommendation: A** — The integration test is a spec §XIII requirement, not optional. Requiring PR 5 before PR 6 is a clean constraint with no implementation penalty (calibrate and rake are not interdependent in their logic).

---

#### Section: PRs 1–4 — Changelog Entry Inconsistency

**Issue 4: PR 1 has a changelog entry criterion; PRs 2, 3, and 4 do not — inconsistency needs a decision**
Severity: REQUIRED
Violates the stage-1-draft.md template: every PR in the standard template includes `changelog/phase-{X}/feature-[name].md`.

The plan lists a changelog criterion in PR 1 ("Changelog entry written and committed on this branch") but omits it from PRs 2, 3, and 4. All four are infrastructure PRs with no user-facing exported functions. Either all four should have entries (for completeness) or none should (because `changelog/phase-0/*.md` files are assembled into NEWS.md and users don't care about test helpers or utils). The inconsistency leaves the implementer without a clear rule.

Options:
- **[A]** Remove the changelog criterion from PR 1; add a note to all four infrastructure PRs that changelog entries are omitted intentionally because no user-facing functions are added in PRs 1–4 — Effort: trivial, Risk: low, Impact: consistent; NEWS.md will only contain user-facing deliverables
- **[B]** Add changelog entries to PRs 2, 3, and 4 — Effort: trivial, Risk: low, Impact: consistent but adds internal infrastructure details to the changelog directory
- **[C] Do nothing** — Implementer follows PR 1 literally and adds changelog entries to some infrastructure PRs but not others

**Recommendation: A** — The `changelog/phase-0/` directory feeds user-facing NEWS.md content. Internal infrastructure (test helpers, S7 class definitions, utils) should not appear there. Remove the criterion from PR 1 and explicitly note the omission for PRs 1–4.

---

#### Section: PR 5 — `calibrate()`

**Issue 5: PR 5 acceptance criteria include "items 1–19" but spec item 19b has been relocated to PR 6**
Severity: REQUIRED
Violates spec coverage: the acceptance criteria are ambiguous about what is and isn't tested in PR 5.

The spec §XIII lists item 19b under the `calibrate()` test plan:
> "# 19b. History — chain calibrate() → rake() produces two-entry weighting_history"

The plan relocates this test to PR 6 (`test-03-rake.R`), which is correct. But PR 5's acceptance criteria still say:

> "All `calibrate()` test items from spec §XIII pass (items 1–19)"

This is ambiguous: does "items 1–19" include 19b? If an implementer reads the spec and sees items 1–19 with the sub-item 19b under calibrate, they may write it in `test-02-calibrate.R` instead of leaving it for PR 6. The instruction "excluding 19b, which is in PR 6" is not present.

Options:
- **[A]** Change to "items 1–19 (item 19b is relocated to `test-03-rake.R` in PR 6 — do not write it here)" — Effort: trivial, Risk: low, Impact: zero ambiguity
- **[B]** Leave as-is and rely on the Notes section mentioning the relocation — Effort: none, Risk: medium (Notes are easy to miss)

**Recommendation: A** — One parenthetical clause eliminates a likely source of duplicate test coverage.

---

#### Section: PR 4 / PR 5 / PR 6 — Shared Validation Logic

**Issue 6: Categorical variable and NA checks are duplicated across `02-calibrate.R` and `03-rake.R`**
Severity: REQUIRED
Violates `engineering-preferences.md §1`: "Duplicated logic is a bug waiting to happen. If two functions do the same thing, they should share a helper."

Both `calibrate()` and `rake()` must validate that their respective variable columns are:
1. Categorical (character or factor) — throws `surveywts_error_variable_not_categorical`
2. Free of NA values — throws `surveywts_error_variable_has_na`

The logic is structurally identical (loop over variable names, check class, check NA). The spec §XII.B and §XII.C message templates differ only in the context word ("Calibration variable" vs "Raking variable"), which is a `context =` parameter away from being shared. Without a shared helper, this validation logic will be duplicated in `02-calibrate.R` and `03-rake.R`. Any change to the check (e.g., future support for ordered factors) must be made in two places.

The plan's helper table does not include this helper; PR 4's acceptance criteria do not list it. The plan does include `.validate_population_marginals()` in utils (correctly shared by both), but the categorical/NA pre-validation step is absent.

Note: `poststratify()` does NOT enforce the categorical restriction (Issue 7 resolution), so this helper is a two-file case only — by the plan's own placement rule, it still belongs in `07-utils.R` (used by 2 source files).

Options:
- **[A]** Add `.validate_calibration_variables(data, variable_names, context)` to `R/07-utils.R`; add it to the PR 4 helpers table and acceptance criteria; both `calibrate()` and `rake()` call it with their respective `context =` string — Effort: low, Risk: low, Impact: DRY; single location for categorical + NA validation logic; message templates remain in spec §XII with the `context` variable substituted
- **[B]** Accept the duplication with an explicit code comment in both files pointing to the shared check logic — Effort: trivial, Risk: medium (next developer adds an ordered-factor case to one but not the other)
- **[C] Do nothing** — Duplicated logic; divergence risk as soon as any change is needed

**Recommendation: A** — The helper is 10–15 lines. A `context` parameter cleanly produces the per-function message text. The DRY principle is non-negotiable per engineering-preferences.md.

---

#### Section: PR Map — General

**Issue 7: `Depends on` for PRs 4–9 does not mention the surveycore prerequisite**
Severity: REQUIRED
Violates dependency ordering: every PR from PR 4 onward references surveycore classes at runtime or via `S7::S7_inherits()`, but only PR 3's `Depends on` field explicitly lists the surveycore prerequisite.

PR 4's `.update_survey_weights()` calls `S7::S7_inherits(design, survey_taylor)` and `S7::S7_inherits(design, survey_calibrated)`. Both classes require surveycore to be installed. An implementer reading only PR 4's card would not see the surveycore dependency and might attempt to implement it without the prerequisite PR merged.

This is transitive through the dependency chain (PR 4 depends on PR 3, which depends on surveycore), but implicit dependencies create confusion. The prerequisite is the most important blocking condition in the entire plan.

Options:
- **[A]** Add "Surveycore prerequisite PR" to the `Depends on` field for PR 4 explicitly; PRs 5–9 already depend on PR 4 transitively, so adding it only to PR 4 is sufficient — Effort: trivial, Risk: low, Impact: zero ambiguity; no developer attempts PR 4 before surveycore
- **[B]** Add the surveycore prerequisite to all of PRs 4–9 `Depends on` fields — Effort: trivial, Risk: low, Impact: fully explicit but repetitive
- **[C] Do nothing** — Transitive dependency is implied; risk is low since the plan header states it

**Recommendation: A** — One addition to PR 4 makes the chain explicit at the first point of use. PRs 5–9 inherit the dependency through PR 4.

---

#### Section: PR 2 — Test Infrastructure

**Issue 8: Rule stub updates (`.claude/rules/*.md`) in PR 2 should be direct commits to `develop`**
Severity: SUGGESTION
Violates github-strategy.md §What gets a branch vs. direct push: "README / docs update → No branch needed."

PR 2 includes `.claude/rules/surveywts-conventions.md` and `.claude/rules/testing-surveywts.md` in a feature branch. These are developer-facing documentation files in the `.claude/` directory, not R package artifacts. They are analogous to README or docs updates — github-strategy.md says those do not need a branch. Putting them in a feature branch adds PR review overhead for documents that have no functional effect on the R package.

The R package artifact in PR 2 (`tests/testthat/helper-test-data.R`) does warrant a branch and PR. The rule stubs don't.

Options:
- **[A]** Commit the rule stub updates directly to `develop` (no branch) before or alongside opening PR 2; remove them from PR 2's file list and acceptance criteria — Effort: trivial, Risk: low, Impact: reduces PR 2 scope to only the test helper
- **[B]** Keep them in PR 2 for convenience — Effort: none, Risk: low, Impact: slightly inflated PR scope but functionally harmless
- **[C] Do nothing** — Same as B

**Recommendation: A** — Keeping docs-only changes out of feature PRs matches the github-strategy.md rule and makes PR 2's diff easier to review.

---

#### Section: PR 4 — Shared Internal Utilities

**Issue 9: PR 4 acceptance criteria do not acknowledge that line coverage will be 0% when this PR merges**
Severity: SUGGESTION
The plan says PR 4 has no test file and "all tested indirectly via PRs 5–9." This is correct per `testing-standards.md`. But without a note in the acceptance criteria, the implementer may be alarmed when `covr::package_coverage()` reports near-zero coverage after PR 4 merges, or may feel they have failed the 98% target.

Options:
- **[A]** Add an explicit note to PR 4's acceptance criteria: "Coverage will be ~0% when this PR merges in isolation; this is expected. All helpers are covered indirectly by PRs 5–9. Do NOT add direct tests to pass coverage here." — Effort: trivial, Risk: low, Impact: sets correct expectations
- **[B]** Leave as-is and rely on the Notes section comment — Effort: none, Risk: low (same information, less authoritative location)

**Recommendation: A** — Coverage expectations in acceptance criteria prevent confusion. One line.

---

#### Section: PR 3 — Core Classes

**Issue 10: PR 3 tests must construct `weighted_df` via `structure()` since `.make_weighted_df()` is in PR 4, but the plan does not note this**
Severity: SUGGESTION

`test-00-classes.R` (PR 3) must create `weighted_df` objects to test `dplyr_reconstruct.weighted_df()`, `print.weighted_df()`, and the class vector check. The natural constructor is `.make_weighted_df()`, but that function lives in `07-utils.R` (PR 4). The test file must use raw construction instead:

```r
wdf <- structure(
  tibble::tibble(x = 1:5, w = rep(1, 5)),
  class = c("weighted_df", "tbl_df", "tbl", "data.frame"),
  weight_col = "w",
  weighting_history = list()
)
```

If an implementer tries to call `.make_weighted_df()` in PR 3 tests, they get an undefined function error. The plan should note this constraint.

Options:
- **[A]** Add a note to PR 3's Notes section: "PR 3 tests cannot call `.make_weighted_df()` (not yet defined). Construct `weighted_df` test fixtures using `structure()` with explicit class, `weight_col`, and `weighting_history` attributes." — Effort: trivial, Risk: low
- **[B]** Leave implicit — Effort: none, Risk: low (discoverable at implementation time)

**Recommendation: A** — A one-sentence note saves 15 minutes of debugging.

---

#### Section: PR 3 / PR 4 — Print Method Snapshot

**Issue 11: If PR 3 uses inline stats in `print.weighted_df()` and PR 4 refactors to `.compute_weight_stats()`, the snapshot must be regenerated in PR 4 — but PR 4's file list says only `07-utils.R`**
Severity: SUGGESTION

If Issue 1 is resolved via Option A (inline stats in PR 3, refactor in PR 4), then PR 4 will modify `R/00-classes.R` (to call `.compute_weight_stats()` instead of inline code). This modification may also cause the `print.weighted_df()` snapshot in `tests/testthat/_snaps/` to need regeneration, since the output may differ if the computation path changes (even though the numbers are the same). The plan does not list `R/00-classes.R` in PR 4's files.

Options:
- **[A]** If Issue 1 is resolved via Option A, add `R/00-classes.R` (refactor print method) and snapshot regeneration to PR 4's file list and acceptance criteria — Effort: trivial, Risk: low, Impact: complete and accurate PR 4 scope
- **[B]** Note the refactor in PR 4's Notes section without adding it to file list — Effort: trivial, Risk: low (same information, less formal)

**Recommendation: A** — This only applies if Issue 1 is resolved via Option A. Add conditionally once that decision is made.

---

#### Section: Overview — File Organization

**Issue 12: Source file numbering deviates from spec §II without explicit notation**
Severity: SUGGESTION
The spec §II states:
```
R/
├── 02-calibrate.R    # calibrate(), rake(), poststratify()
├── 03-nonresponse.R
└── 04-diagnostics.R
```

The plan's new file organization uses:
```
R/
├── 02-calibrate.R    # calibrate() only
├── 03-rake.R         # NEW
├── 04-poststratify.R # NEW
├── 05-nonresponse.R  # was 03
└── 06-diagnostics.R  # was 04
```

The test file map in spec §XIII similarly shows `test-03-nonresponse.R` and `test-04-diagnostics.R`, which the plan renames. The plan's Overview does document the new structure clearly, but does not explicitly note "this deviates from spec §II and §XIII — the spec file organization is superseded by this plan." Someone cross-referencing the spec's source file table later will be confused.

Options:
- **[A]** Add one sentence to the Overview: "The source file organization below supersedes spec §II; the `testing-surveywts.md` update in PR 2 will update the file map accordingly." — Effort: trivial, Risk: low, Impact: self-documenting deviation
- **[B]** Leave as-is; the plan's file table is unambiguous — Effort: none, Risk: low

**Recommendation: A** — One sentence prevents confusion when anyone refers back to spec §II.

---

---

## Plan & Spec Review: phase-0 — Pass 2 (2026-03-03)

Focus: missing edge cases in tests and DRY violations across both documents.
Review conducted in four sections; all 16 issues resolved interactively.
Full decisions in `plans/decisions-phase-0.md` (2026-03-03 session).

### Architecture Issues

**Issue 1: `.validate_population_cells()` listed in spec §XI as a shared util but only used by `poststratify()`**
Severity: REQUIRED
The spec §XI header "all utilities in `07-utils.R`" and then lists this helper there,
but the impl plan correctly places it in `04-poststratify.R`. Self-contradictory.
**Resolution:** Fixed spec — removed from §XI shared list; added cross-reference note;
added explicit note in §II file org comment.

**Issue 2: `.validate_calibration_variables()` in impl plan but missing from spec §XI**
Severity: REQUIRED
The impl plan introduces a shared helper for categorical/NA variable validation used by
both `calibrate()` and `rake()`, but spec §XI never defines it. Validation behavior is
described independently in §VI and §VII.
**Resolution:** Added full definition to spec §XI with signature, `context` parameter,
and error classes thrown.

**Issue 3: `population_level_missing` absent from `rake()` error table**
Severity: REQUIRED
`calibrate()` throws this error when a data level has no population entry; `rake()`'s
error table omits it. IPF would silently ignore missing-level observations.
**Resolution:** Added `surveywts_error_population_level_missing` to §VII error table
and §XII.C message template.

**Issue 4: No error class or message template for non-positive count targets**
Severity: REQUIRED
Spec §XI describes count-target validation but §XII message templates only cover
`type = "prop"`. The behavior is specified but untestable without an error class.
**Resolution:** Extended `surveywts_error_population_totals_invalid` to cover both
cases; updated message templates in §XII.B, C, D.

### Code Quality Issues

**Issue 5: `dplyr::rename()` on weight column is unspecified**
Severity: REQUIRED
`dplyr_reconstruct` treats rename the same as drop (fires warning, downgrades to tibble)
but this is neither specified nor tested. Decision: `rename.weighted_df()` lives in
`surveytidy` (not `surveywts`); spec §IV documents the rename-as-drop behavior and
§XII.G warning hint added.
**Resolution:** Added behavior note to §IV; added `"v"` hint in §XII.G warning template.

**Issue 6: `control` argument merge semantics unspecified**
Severity: REQUIRED
If user passes `control = list(maxit = 100)` without `epsilon`, `epsilon` is undefined.
**Resolution:** Added merge semantics to §II.d (`modifyList()` pattern); specified
`maxit = 0` behavior (immediate error).

**Issue 7: Spec §II and §XIII file maps are stale**
Severity: REQUIRED
Spec still showed single `02-calibrate.R` for all three calibration functions; test file
map showed old names.
**Resolution:** Updated §II source file org and §XIII test file map to split-file structure.

**Issue 8: Test item 19b location conflict between spec and impl plan**
Severity: SUGGESTION
Spec placed the calibrate→rake chain test in calibrate's list; impl plan moved it to rake.
**Resolution:** Moved to rake's test list in §XIII (as item 20b) with explanatory parenthetical.

### Test Issues

**Issue 9: Factor variables never tested in calibrate/rake**
Severity: REQUIRED
`make_surveywts_data()` returns only character columns; spec says "character or factor"
but no happy path tests factor input.
**Resolution:** Added item 1b (factor happy path) to calibrate and rake test lists.

**Issue 10: `population_level_missing` for `rake()` needs a test**
Severity: REQUIRED
New error class from Issue 3 requires a test per testing-standards.md dual pattern.
**Resolution:** Added item 15b to rake's test list.

**Issue 11: `population_totals_invalid` for `type = "count"` needs tests**
Severity: REQUIRED
Issue 4 extended the error class; all three affected functions need count-target tests.
**Resolution:** Added items 13b (calibrate), 16b (rake), 8c (poststratify).

**Issue 12: `survey_taylor` input missing from diagnostics happy paths**
Severity: SUGGESTION
Only `survey_calibrated` was tested; `survey_taylor` is a distinct input class.
**Resolution:** Added item 3b to diagnostics test list.

### Remaining Gap Issues

**Issue 13: `control$maxit = 0` behavior unspecified**
Severity: SUGGESTION
Zero iterations is almost certainly a user error; behavior was undefined.
**Resolution:** Specified in §II.d: fires `calibration_not_converged` immediately.

**Issue 14: Duplicate rows in `population` for `poststratify()` undefined**
Severity: REQUIRED
Easy user mistake that produces ambiguous targets. `survey::postStratify()` silently
uses first match; this package errors instead.
**Resolution:** Added `surveywts_error_population_cell_duplicate` to §VIII,
§XII.D, error-messages.md, and test item 8d.

**Issue 15: Factor `response_status` not in `adjust_nonresponse()` error paths**
Severity: SUGGESTION
Error already fires via `is.logical()`/`is.integer()` check but was untested and
undocumented.
**Resolution:** Added note to §IX; added test item 10b; updated §XII.E message template.

**Issue 16: Validation order unspecified**
Severity: REQUIRED
Snapshot tests require deterministic error order; order was implicit.
**Resolution:** Added fixed validation order to §II.d: class check → empty data →
weights → function-specific.

### Summary (Pass 2)

| Severity | Count |
|---|---|
| REQUIRED | 11 |
| SUGGESTION | 5 |

**Total issues:** 16

**Overall assessment:** Both documents were structurally sound but had systematic gaps in
three areas: (1) DRY violations where the impl plan introduced helpers not defined in the
spec, (2) missing tests for newly-added error classes and underspecified input types,
(3) behavioral contracts left implicit that snapshot tests depend on. All 16 issues are
resolved. Documents are ready for implementation.

---

## Summary (Pass 1)

| Severity | Count |
|---|---|
| BLOCKING | 1 |
| REQUIRED | 6 |
| SUGGESTION | 5 |

**Total issues:** 12

**Overall assessment:** The plan is structurally sound — the per-function file split is well-reasoned, helper placement is correct, and all spec §XIII test categories are accounted for. One blocking issue prevents PR 3 from passing `R CMD check` as written: `print.weighted_df()` calls a helper that doesn't exist until PR 4, which depends on PR 3. The resolution is straightforward (inline stats in PR 3, extract in PR 4). The six required issues are all low-effort fixes: a CI configuration gap that will break every PR from PR 1 onward if not addressed, a missing PR 5 dependency in PR 6, a DRY violation in the categorical variable validation that should be caught before the function PRs begin, and three labeling/consistency gaps. Resolving all seven blocking/required issues is a single editing pass; the plan will then be ready for implementation.

---

## Plan Review: phase-0 — Pass 3 (2026-03-04)

### Prior Issues (Passes 1–2)

All 28 prior issues (12 in Pass 1, 16 in Pass 2) are marked resolved in their respective sections above. This pass reviews the current `plans/impl-phase-0.md` v1.2 against `plans/spec-phase-0.md` v0.3 after all prior resolutions were applied.

---

### New Issues

#### Section: PR 4 — Shared Internal Utilities

**Issue 1: `.update_survey_weights()` has an `output_class` parameter in the plan but the spec explicitly prohibits it**
Severity: BLOCKING
Violates spec §XI, which defines the authoritative signature without `output_class`.

The plan's "Shared helpers" section defines:

```
.update_survey_weights(design, new_weights_vec, history_entry,
  output_class = c("same", "survey_calibrated"))
```

And the PR 4 acceptance criterion reads: "`.update_survey_weights()` calls `.new_survey_calibrated()` for `output_class = "survey_calibrated"`."

The spec §XI defines the function as:

```r
.update_survey_weights <- function(design, new_weights_vec, history_entry)
```

And explicitly states: **"No `output_class` parameter. Calibration functions that need to produce a `survey_calibrated` output use `.new_survey_calibrated()` instead — that is the correct path for class promotion."**

An implementer following the plan would implement a 4-argument function with a dispatch branch. An implementer following the spec would implement a 3-argument function where calibration functions call `.new_survey_calibrated()` directly. These produce different architectures with different call sites in PRs 5–7 vs PR 8.

Options:
- **[A]** Remove `output_class` from the plan's helper signature and PR 4 acceptance criteria; update the PR 4 description to state that calibration functions call `.new_survey_calibrated()` directly, and `.update_survey_weights()` is only used by `adjust_nonresponse()` (which never promotes class) — Effort: low, Risk: low, Impact: spec-conformant architecture
- **[B]** Update the spec to add `output_class` back — Effort: low, Risk: medium (spec was deliberately simplified in a prior session); would need spec re-review
- **[C] Do nothing** — Implementer must guess which document is authoritative; whichever they choose, the call sites in 4 function files will be wrong

**Recommendation: A** — The spec was explicitly updated to remove `output_class`. The plan was not synchronized. Update the plan.

---

**Issue 2: PR Map text says PRs 5, 6, and 7 are independent; PR 6 card says "Depends on: PR 4; PR 5" — direct internal contradiction**
Severity: BLOCKING
Violates dependency ordering: the PR Map and the PR 6 card give irreconcilable dependency information.

The PR Map section states:

> "PRs 5, 6, and 7 all depend on PR 4 and are independent of each other — they can be worked in parallel."

PR 6's card header states:

> **Depends on:** PR 4; PR 5

Pass 1 Issue 3 resolved the PR 6 card to add PR 5 dependency (correctly, because the integration test requires `calibrate()`). But the PR Map overview text was never updated. A developer reading the PR Map would attempt parallel PR 5/6/7 development, leading to PR 6's integration test failing or being left unwritten.

Options:
- **[A]** Update the PR Map text to: "PR 5 and PR 7 can be worked in parallel (both depend only on PR 4). PR 6 depends on both PR 4 and PR 5 — its integration test requires `calibrate()` to exist." — Effort: trivial, Risk: low, Impact: eliminates the contradiction
- **[B] Do nothing** — Developer follows the PR 6 card (which is correct) and ignores the stale PR Map text; risk is low but contradiction remains

**Recommendation: A** — Two sentences eliminates an ambiguity that directly affects work ordering.

---

#### Section: PR 3 — Core Classes and Internal Constructor

**Issue 3: PR 3 acceptance criteria for validator tests (items 8 and 9) don't specify the error class names or the "ALL NA" triggering nuance**
Severity: REQUIRED
Violates testing-standards.md: "class= on every expect_error()" must match the actual class thrown; the class here is `surveycore_error_*`, not `surveywts_error_*`.

The plan's PR 3 AC says:

> 8. `survey_calibrated` validator rejects non-positive weights (`class=` only)
> 9. `survey_calibrated` validator rejects NA weights (`class=` only)

The spec §XIII clarifies:

```
# 8. class = "surveycore_error_weights_nonpositive" (surveycore's class, not surveywts_error_*)
# 9. class = "surveycore_error_weights_na"
#    (surveycore's validator permits individual NAs; errors only when length(non_na) == 0)
```

Two problems: (1) the class names are omitted — an implementer writing `expect_error(class = "surveywts_error_weights_nonpositive")` would write a test that always passes vacuously because the actual class is `surveycore_error_*`. (2) For item 9, the triggering condition is "ALL values NA" — individual NAs are allowed by surveycore's validator. A test that passes one NA-containing weight column would not trigger the error and would give false confidence.

Options:
- **[A]** Update items 8 and 9 to: "class = `'surveycore_error_weights_nonpositive'`" and "class = `'surveycore_error_weights_na'`; trigger requires ALL values to be NA (surveycore permits individual NAs)" — Effort: trivial, Risk: low, Impact: prevents a silent test correctness failure
- **[B] Do nothing** — Developer discovers the wrong class name when the test fails; low effort to fix at implementation time

**Recommendation: A** — Naming the correct class and the non-obvious trigger takes one line each and prevents a false-green test.

---

#### Section: PR 5 — `calibrate()`

**Issue 4: PR 5 acceptance criteria omit spec items 1b (factor-typed variable) and 13b (type="count" totals_invalid)**
Severity: REQUIRED
Violates spec coverage: two spec §XIII test items have no corresponding acceptance criterion in PR 5.

The plan's PR 5 happy-path list: "data.frame→weighted_df, survey_taylor→survey_calibrated, weighted_df→weighted_df (history), survey_calibrated→survey_calibrated, method='logit', type='count', multi-variable population verified." This maps to items 1, 2, 2a, 3, 4, 5, 6. **Item 1b** (factor-typed `variables` column) is absent.

The plan's error-path list: "variable_not_categorical, variable_has_na, population_variable_not_found, population_level_missing, population_level_extra, population_totals_invalid, calibration_not_converged." This maps to items 9–14. **Item 13b** (type="count", target ≤ 0) is absent — "population_totals_invalid" appears once but the spec requires two distinct test blocks (item 13: type="prop" targets don't sum to 1; item 13b: type="count" target ≤ 0).

Without item 1b, the categorical check for factor columns is untested. Without item 13b, count-target validation has no coverage.

Options:
- **[A]** Add to PR 5 AC: "1b. factor-typed `variables` column (verify factor treated same as character)" to the happy-paths list; add "population_totals_invalid (type='count', target ≤ 0) as a separate test block (item 13b)" to the error-paths list — Effort: trivial, Risk: low, Impact: closes two coverage gaps
- **[B] Do nothing** — Developer reading "items 1–19" with the detailed bullet list may not realize sub-items require separate test blocks

**Recommendation: A** — Both items were explicitly added to the spec in Pass 2. They must appear in the plan AC to be testable.

---

#### Section: PR 6 — `rake()`

**Issue 5: PR 6 acceptance criteria omit items 1b, 16b, 23, and 26b**
Severity: REQUIRED
Violates spec coverage: four spec §XIII test items have no acceptance criterion in PR 6.

Missing from PR 6's AC:

- **Item 1b**: Happy path — factor-typed margin variable. The plan's happy-path list doesn't include it (same gap as PR 5 issue 4 above). The `.validate_calibration_variables()` helper accepts factors; this must be tested.

- **Item 16b**: Error — `population_totals_invalid` (type="count", target ≤ 0). Same dual-subtest gap as item 13b in PR 5. The AC mentions "population_totals_invalid" once but the spec requires two test blocks.

- **Item 23**: Happy path — `control$variable_select = "max"` produces different variable selection order than `"total"`. The control defaults AC ("maxit = 1000; maxit = 100; user override") covers item 26 but not item 23. Variable selection ordering is a distinctive anesrake behavior; without a test, `variable_select` goes untested.

- **Item 26b**: Message — `surveywts_message_already_calibrated`. When all anesrake variables pass the chi-square threshold in sweep 1, `rake()` emits a `cli_inform()` message with this class. The spec §VII behavior rule 8 and test item 26b require `expect_message(class = "surveywts_message_already_calibrated")`. This class is required for testability and programmatic suppression. No AC criterion mentions it.

Options:
- **[A]** Add explicit AC bullets for items 1b, 16b, 23, and 26b — Effort: low, Risk: low, Impact: closes four coverage gaps
- **[B] Do nothing** — "items 1–26" technically includes these but the bulleted summary list is the practical checklist an implementer reads

**Recommendation: A** — Item 26b in particular involves a `cli_inform()` message with a required class — it is easy to miss without an explicit criterion.

---

#### Section: PR 7 — `poststratify()`

**Issue 6: PR 7 acceptance criteria omit item 1c (type="count" default) and don't distinguish items 8b and 8c**
Severity: REQUIRED
Violates spec coverage: item 1c is a required test for a function-specific behavioral contract (default differs from all other functions); 8b/8c are two separate error conditions requiring two test blocks.

**Item 1c** verifies that `type = "count"` is the default for `poststratify()` — the only function in Phase 0 that defaults to count rather than proportion. The spec explicitly requires: "call succeeds without specifying type; call fails with `population_totals_invalid` when proportions-formatted population is passed without `type = 'prop'`." Without this test, the wrong default would pass all other tests.

**Items 8b and 8c**: The AC says "population_totals_invalid" without distinguishing the two triggers. Item 8b tests type="prop" proportions that don't sum to 1; item 8c tests type="count" with a non-positive target. These are distinct error conditions with different message text; both require separate test blocks.

Options:
- **[A]** Add to PR 7 AC: "item 1c: verify type='count' is the default (call without type= succeeds; call with proportions-formatted population without type='prop' fails)"; update error-paths to "population_totals_invalid (type='prop', item 8b) and population_totals_invalid (type='count', item 8c) as separate test blocks" — Effort: trivial, Risk: low
- **[B] Do nothing** — "items 1–15" is stated; developer discovers the gap when reading spec §XIII

**Recommendation: A** — Item 1c tests a behavioral default that is unique to `poststratify()` and is easily missed without an explicit criterion.

---

#### Section: PR 8 — `adjust_nonresponse()`

**Issue 7: PR 8 acceptance criteria omit item 10b (factor response_status), miscount error classes, and miscount total test items**
Severity: REQUIRED
Violates testing-standards.md: every error class must have a test block; the count mismatch signals uncovered behavior.

**Item 10b** (factor `response_status` is not binary regardless of its levels) is a separate test block from item 10 (integer/character with wrong values). The spec §XIII requires it explicitly and §XII.E has a specific message template for it. The plan calls out items 14/14b as separate blocks (count-trigger vs factor-trigger for `class_near_empty`) but makes no similar distinction for 10/10b. Without an explicit criterion, the factor test is likely to be merged into item 10's test block or skipped.

**Error class count**: The plan says "all 8 error classes and 1 warning class in spec §XII.E." §XII.E lists 7 function-specific error classes (variable_has_na, response_status_not_found, response_status_not_binary, response_status_has_na, response_status_all_zero, class_cell_empty, propensity_requires_phase2). The correct count is 7, not 8.

**Test item count**: The plan says "17 test items" referring to spec §XIII items 1–17. The spec has 17 parent-numbered items but 5 sub-items (2b, 2c, 5b, 10b, 14b) requiring their own `test_that()` blocks. Saying "17 test items" could lead an implementer to think they've covered everything after 17 blocks when 22 are required.

Options:
- **[A]** Add explicit AC: "Separate test blocks for item 10 (integer/character wrong values) and item 10b (factor column); 22 test blocks total (17 parent items + 5 sub-items); correct error class count is 7 specific + 7 standard (SE-1–7)" — Effort: trivial, Risk: low
- **[B] Do nothing** — Developer reading the spec will encounter item 10b eventually; count discrepancies are minor

**Recommendation: A** — Item 10b's "factor columns are not binary regardless of their levels" is a non-obvious edge case that needs an explicit criterion.

---

#### Section: PR 8 — `adjust_nonresponse()` / Spec §II.c

**Issue 8: svrep numerical oracle decision not reflected in PR 8 acceptance criteria — creates an irreconcilable contradiction between spec §II.c, test item 5b, and the decisions log**
Severity: REQUIRED
Violates spec coverage: a committed architectural decision (svrep as numerical oracle) is absent from the plan's acceptance criteria.

The decisions log records: "Weighting-class method: native implementation with `svrep` as numerical oracle in tests." Spec §II.c states: "`svrep::redistribute_weights()` serves as the numerical oracle in tests via `skip_if_not_installed('svrep')` inside the affected test blocks. GAP #5 resolved."

The plan's PR 8 AC says: "Hand-calculation (item 5b): ... note in comment that no reference R package exists."

The spec §XIII test item 5b says the same: "Note: no reference R package provides weighting-class nonresponse adjustment."

These three sources contradict each other. The decisions log and spec §II.c are authoritative for the architectural decision (svrep IS the oracle). The test item 5b and the plan AC were not updated after the decision was made. The spec GAPs table still shows GAP #5 as ⬜ Open, also stale.

Consequences if unresolved: (1) `svrep` is not in DESCRIPTION Suggests, so test blocks using `skip_if_not_installed("svrep")` will always skip; (2) the plan's note "no reference R package exists" will be written into test code as a comment, contradicting the decision; (3) the GAP table is permanently stale.

Options:
- **[A]** Resolve the contradiction in favor of svrep (per decisions log): add `svrep (>= 0.6)` to DESCRIPTION Suggests in PR 1; add a svrep numerical correctness test to PR 8 AC (`skip_if_not_installed("svrep")` inside the block); remove "no reference R package" from the plan's language; update spec §XIII item 5b and the GAPs table — Effort: low, Risk: low, Impact: correct architecture; consistent documents
- **[B]** Resolve in favor of hand-calculation only: update spec §II.c to remove svrep reference; mark GAP #5 as resolved with "hand-calculation validation documented in VENDORED.md" — Effort: low, Risk: low, Impact: simpler; fewer Suggests dependencies
- **[C] Do nothing** — The contradiction persists into implementation; implementer makes a choice silently

**Recommendation: A** — The decisions log explicitly names svrep. §II.c text reflects that decision. Hand-calculation is a necessary complement, not a substitute. The svrep oracle provides an independent check that the redistribution formula gives the right numbers on real inputs.

---

#### Section: PR 9 — Diagnostics

**Issue 9: PR 9 acceptance criteria say "4 error classes" but spec §X specifies 6; items 3b, 7b, 7c, 7d not explicitly listed**
Severity: REQUIRED
Violates spec coverage: two weight validation error classes have no explicit criterion, and a survey_taylor input class has no explicit test requirement.

The plan's PR 9 AC says: "Dual pattern on all Layer 3 errors; 4 error classes tested for `effective_sample_size()` / `weight_variability()`."

Spec §X states: "Diagnostics call `.validate_weights()` before computing. This means all four weight validation errors apply (same as calibration functions)." The four weight errors are: `weights_not_found`, `weights_not_numeric`, `weights_nonpositive`, `weights_na`. Plus `unsupported_class` and `weights_required` = **6 total** for ESS and CV. The spec §XIII items 7b (not_numeric), 7c (nonpositive), 7d (na) are separate test blocks explicitly listed; the plan's AC doesn't name them.

**Item 3b** (auto-detected weights for `survey_taylor`) is listed in the spec but absent from the plan's bulleted AC. The plan says "Auto-detected weights for survey_calibrated input" (item 3) but doesn't mention `survey_taylor`. Both are required; `survey_taylor` auto-detection uses a different code path (`@variables$weights`) and must be explicitly tested.

Options:
- **[A]** Update PR 9 AC to: "6 error classes for `effective_sample_size()`/`weight_variability()` (unsupported_class, weights_required, weights_not_found, weights_not_numeric, weights_nonpositive, weights_na); all use dual pattern; item 3b (survey_taylor auto-detect) required alongside item 3 (survey_calibrated)" — Effort: trivial, Risk: low
- **[B] Do nothing** — "items 1–8" covers 7b/7c/7d implicitly; 3b is easy to add at implementation time

**Recommendation: A** — Under-specifying error coverage for diagnostics is the pattern most likely to result in skipped tests. The explicit count "4" anchors an implementer's work prematurely.

---

#### Section: PR 3 / PR 4 — S7 Method File Organization

**Issue 10: No designated file for `S7::method(print, surveycore::survey_calibrated)` — code-style.md requires a dedicated methods file**
Severity: REQUIRED
Violates code-style.md §2: "Methods are grouped by type in dedicated files (`04-methods-print.R`, etc.) — not co-located with class definitions."

The plan's source file structure has no `methods-print.R` or equivalent. The plan's PR 3 section assigns `R/00-classes.R` to "`weighted_df` S3 class + `survey_calibrated` S7 class + validator." But `survey_calibrated` is defined in surveycore, not here. So `00-classes.R` in surveywts contains the `weighted_df` S3 class and its S3 methods (`print.weighted_df`, `dplyr_reconstruct.weighted_df`). The S7 method `S7::method(print, surveycore::survey_calibrated)` has no home.

code-style.md §2 is explicit: `00-s7-classes.R` = class definitions only; `04-methods-print.R` = all S7 `print`/`summary` methods. Putting the S7 print method in `00-classes.R` alongside S3 class code violates both halves of this rule. Without a designated file in the plan, the implementer will put the S7 method in an ad hoc location or mix it with the S3 class code.

Options:
- **[A]** Add `R/methods-print.R` (or `R/04-methods-print.R`) to the plan's source file structure as the home for `S7::method(print, surveycore::survey_calibrated)`; include it in PR 3's file list since it ships alongside the print snapshot test — Effort: low, Risk: low, Impact: code-style.md compliance; clean separation of class definition and method registration
- **[B]** Explicitly note in PR 3: "exception to code-style.md §2 for Phase 0 — the single S7 print method lives in `00-classes.R` alongside the S3 print method to avoid a one-method file; promote to `methods-print.R` in Phase 1 when more S7 methods exist" — Effort: trivial, Risk: low, Impact: intentional deviation, documented
- **[C] Do nothing** — Implementer places the S7 method arbitrarily; may violate code-style.md silently

**Recommendation: A** — A single methods file with one S7 method is slightly sparse but avoids tech debt and prevents R CMD check surprises from method registration order. code-style.md doesn't have a "minimum two methods" exemption.

---

#### Section: Final Quality Gate Checklist

**Issue 11: Final Quality Gate checklist omits `R/vendor/rake-anesrake.R` from the vendored-file check**
Severity: REQUIRED
Violates spec §XIV, which lists all three vendored files in the Quality Gate.

The plan's Quality Gate says:

> `R/vendor/calibrate-greg.R` and `R/vendor/calibrate-ipf.R` exist and carry attribution comment blocks

Spec §XIV says:

> `R/vendor/calibrate-greg.R`, `R/vendor/calibrate-ipf.R`, and **`R/vendor/rake-anesrake.R`** exist and carry attribution comment blocks

`rake-anesrake.R` is the vendored anesrake IPF algorithm added in PR 6. It is covered in PR 6's own acceptance criteria ("carries full attribution comment block"), but it's absent from the final gate. The Quality Gate is the release checklist; a missing item there can be overlooked even when the per-PR criterion was met.

Options:
- **[A]** Add `R/vendor/rake-anesrake.R` to the Quality Gate vendored-file check — Effort: trivial, Risk: low
- **[B] Do nothing** — PR 6 AC covers it; the gate omission is minor

**Recommendation: A** — One line; keeps the Quality Gate in sync with spec §XIV.

---

#### Section: PR 6 — `rake()` (Notes)

**Issue 12: PR 6 Notes contain stale "stub" language that contradicts the Depends On field**
Severity: SUGGESTION
The Notes section says: "If working in parallel, write the test as a stub and fill it in once PR 5 lands." But Depends On now says "PR 4; PR 5" — PRs 5 and 6 are NOT being worked in parallel. The stub language is a remnant of the pre-Pass-1 state before Issue 3 was resolved. A developer reading the Notes might misinterpret the sequencing.

Options:
- **[A]** Remove the "If working in parallel... write as a stub" sentence; replace with "PR 6 requires PR 5 to be merged first; the integration test is not a stub." — Effort: trivial
- **[B] Do nothing** — Depends On field is authoritative; Notes are secondary

**Recommendation: A** — One sentence; eliminates a contradiction that could lead to a permanently incomplete test.

---

#### Section: PR 9 / error-messages.md

**Issue 13: `surveywts_message_already_calibrated` is a required class per spec §XII.G but is not tracked in `plans/error-messages.md`**
Severity: SUGGESTION
`error-messages.md` tracks all classes for the quality gate criterion: "Every `cli_abort()` and `cli_warn()` has a `class =`." But `rake()` spec §VII behavior rule 8 adds a `cli_inform()` message with class `surveywts_message_already_calibrated`. This is listed in spec §XII.G's warnings table and is testable with `expect_message(class = ...)`. Without a row in `error-messages.md`, the Quality Gate criterion implicitly excludes message classes.

Options:
- **[A]** Add a "Messages" section to `plans/error-messages.md` with one row: `surveywts_message_already_calibrated | rake() | method="anesrake", all variables pass chi-square in sweep 1` — Effort: trivial
- **[B]** Leave as-is; argue that `cli_inform()` messages are outside the scope of `error-messages.md` — Effort: none; risk: the message class is untestable without deliberate documentation of its existence

**Recommendation: A** — The class is required for testability per the spec. Tracking it alongside errors and warnings closes the gap.

---

#### Section: PR 5 — `calibrate()`

**Issue 14: PR 5 warning dual-pattern is not explicitly stated (inconsistency with PR 6 which does state it)**
Severity: SUGGESTION
PR 5 AC says: "All error tests use dual pattern (`expect_error(class=)` + `expect_snapshot(error=TRUE)`)." PR 6 AC says: "All error tests use dual pattern; warning tests use `expect_warning(class =)` + `expect_snapshot()`."

PR 5's item 15 (`surveywts_warning_negative_calibrated_weights`) requires a warning test. The warning dual-pattern requirement (`expect_warning(class=)` + `expect_snapshot()`) is not stated for PR 5, creating an inconsistency with PR 6. An implementer following PR 5's criteria might apply only `expect_warning(class=)` without a snapshot.

Options:
- **[A]** Add to PR 5 AC: "warning tests (item 15) use `expect_warning(class =)` + `expect_snapshot()`" — Effort: trivial
- **[B] Do nothing** — testing-standards.md documents the pattern; PR 6 provides a template

**Recommendation: A** — One line; consistent with PR 6.

---

### Summary (Pass 3)

| Severity | Count |
|---|---|
| BLOCKING | 2 |
| REQUIRED | 9 |
| SUGGESTION | 3 |

**Total issues:** 14

---

## Plan Review: phase-0 — Pass 4 (2026-03-04)

### Focus: Acceptance Criteria Gaps Surfaced by Edge Case Audit

---

#### Section: PR 8 — `adjust_nonresponse()`

**Issue 15: PR 8 acceptance criteria include svrep numerical correctness test; spec §XIII does not list it — sync gap**
Severity: REQUIRED
PR 8 AC explicitly states: "Numerical correctness vs `svrep::redistribute_weights()` within 1e-8 tolerance (inside `skip_if_not_installed("svrep")` block) — svrep is the numerical oracle per spec §II.c and decisions log." But §XIII item 5b only describes a hand-calculation test. The svrep comparison is not a §XIII test item. This means:
1. The plan and spec are out of sync — the plan promises a test the spec doesn't list.
2. If an implementer follows only the spec §XIII test catalog (the stated source of truth), the svrep test will not be written.
3. If an implementer follows only the plan, it will be written.

The svrep comparison is the right call (it's the numerical oracle per §II.c and the decisions log). The spec §XIII needs to list it.

Options:
- **[A]** Add a test item to spec §XIII for `adjust_nonresponse()`: `# 5c. Numerical correctness — matches svrep::redistribute_weights() within 1e-8 tolerance (skip_if_not_installed("svrep") inside block)` — bring spec into sync with plan — Effort: trivial, Risk: low
- **[B]** Remove the svrep criterion from PR 8 AC and rely on hand-calculation only — Effort: trivial, Risk: medium (weaker validation of a natively-implemented function)
- **[C] Do nothing** — the plan and spec will diverge; whichever the implementer follows, one validation is missing

**Recommendation: A** — The spec is the source of truth. Add the svrep item to §XIII and confirm it matches what PR 8 AC already says. The hand-calculation (item 5b) and svrep comparison (item 5c) serve different purposes: one verifies the formula, the other verifies numerical accuracy against a reference implementation.

---

#### Section: PR 3 — Core Classes

**Issue 16: PR 3 acceptance criteria do not include `weighted_df` preservation through `filter()` and `mutate()`**
Severity: REQUIRED
PR 3 AC item 1 tests "`dplyr_reconstruct` preserving weight col → `weighted_df` returned" via `select()`. Item 2 tests "`dplyr_reconstruct` dropping weight col → plain tibble + warning" via `select(-weight_col)`. Neither item covers `filter()` or `mutate()`, which are different dplyr dispatch paths and equally common user operations.

`filter()` and `mutate()` are the two most common dplyr verbs applied to survey data (filtering to subpopulations, mutating to create derived variables). If `dplyr_reconstruct` is only correctly wired for `select()`, a silent regression exists for the two most common use cases.

Options:
- **[A]** Add to PR 3 AC: "Tests for `dplyr_reconstruct` via `filter()` (preserves class) and `mutate()` (preserves class when weight col untouched)" matching spec issue 43 — Effort: trivial, Risk: low
- **[B] Do nothing** — assumes `dplyr_reconstruct` is called identically for all verbs; relies on correct dplyr dispatch behavior

**Recommendation: A** — The entire value of `dplyr_reconstruct.weighted_df()` is that users can pipe freely without thinking. If filter and mutate silently drop the class, that value proposition fails. Two test assertions; zero implementation work.

---

#### Section: PR 5, 6, 7, 8 — All calibration / nonresponse PRs

**Issue 17: No acceptance criterion across PRs 5–8 explicitly asserts the default `.weight` column name**
Severity: REQUIRED
§II.d calls the `.weight` default column name "the authoritative definition." Each of PRs 5–8 has a happy path item 1 that tests `data.frame → weighted_df` with `weights = NULL`. But no PR's acceptance criteria state that the output must satisfy `attr(result, "weight_col") == ".weight"`. An implementer who uses `"weight"` or `".wt"` will pass all stated acceptance criteria.

Options:
- **[A]** Add to each of PRs 5, 6, 7, and 8 AC: "Happy path item 1 asserts `attr(result, 'weight_col') == '.weight'` when `weights = NULL` and input is a plain `data.frame`" — Effort: trivial, Risk: low
- **[B] Do nothing** — relies on the implementer reading §II.d and inferring the name must match

**Recommendation: A** — Four lines across four PRs. The spec explicitly calls this "authoritative." Acceptance criteria should reflect authoritative behavior.

---

### Summary (Pass 4)

| Severity | Count |
|---|---|
| BLOCKING | 0 |
| REQUIRED | 3 |
| SUGGESTION | 0 |

**Total new issues:** 3 (Issues 15–17)

**Focus of this pass:** Plan acceptance criteria gaps surfaced by the Pass 4 edge case audit of the spec. Issues 15–17 are synchronization and completeness problems in PRs 3, 5–8 acceptance criteria. The corresponding spec gaps are tracked as Issues 40–54 in spec-review Pass 4.

### Resolution Status (Pass 4)

| # | Title | Status |
|---|---|---|
| 15 | PR 8 svrep test in plan AC but not in spec §XIII | ✅ Resolved — item 5c added to spec §XIII adjust_nonresponse tests |
| 16 | PR 3 AC missing filter/mutate weighted_df preservation tests | ✅ Resolved — items 2c–2g added to spec §XIII class tests; impl plan PR 3 AC updated below |
| 17 | PRs 5–8 AC missing explicit `.weight` column name assertion | ✅ Resolved — `.weight` assertion added to item 1 of all four functions in spec §XIII |

**Overall assessment:** The plan's architecture and PR sequencing are sound, and the Pass 1–2 resolutions are correctly reflected. Two blocking issues require immediate attention: the `.update_survey_weights()` signature contradicts the spec (the plan adds an `output_class` parameter the spec explicitly prohibits), and the PR Map text flatly contradicts PR 6's dependency card. Nine required issues are systematic: every function PR (5–9) has at least one spec §XIII test item missing from its acceptance criteria, with PR 6 having four gaps including the `already_calibrated` message class. The svrep oracle decision (confirmed in the decisions log and spec §II.c) is not reflected in PR 8 or DESCRIPTION Suggests. Once the two blocking issues are resolved and the per-PR test criteria are filled in, the plan will be ready for implementation.
