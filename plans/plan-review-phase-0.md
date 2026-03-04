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
1. Categorical (character or factor) — throws `surveyweights_error_variable_not_categorical`
2. Free of NA values — throws `surveyweights_error_variable_has_na`

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

PR 2 includes `.claude/rules/surveyweights-conventions.md` and `.claude/rules/testing-surveyweights.md` in a feature branch. These are developer-facing documentation files in the `.claude/` directory, not R package artifacts. They are analogous to README or docs updates — github-strategy.md says those do not need a branch. Putting them in a feature branch adds PR review overhead for documents that have no functional effect on the R package.

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
- **[A]** Add one sentence to the Overview: "The source file organization below supersedes spec §II; the `testing-surveyweights.md` update in PR 2 will update the file map accordingly." — Effort: trivial, Risk: low, Impact: self-documenting deviation
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
**Resolution:** Added `surveyweights_error_population_level_missing` to §VII error table
and §XII.C message template.

**Issue 4: No error class or message template for non-positive count targets**
Severity: REQUIRED
Spec §XI describes count-target validation but §XII message templates only cover
`type = "prop"`. The behavior is specified but untestable without an error class.
**Resolution:** Extended `surveyweights_error_population_totals_invalid` to cover both
cases; updated message templates in §XII.B, C, D.

### Code Quality Issues

**Issue 5: `dplyr::rename()` on weight column is unspecified**
Severity: REQUIRED
`dplyr_reconstruct` treats rename the same as drop (fires warning, downgrades to tibble)
but this is neither specified nor tested. Decision: `rename.weighted_df()` lives in
`surveytidy` (not `surveyweights`); spec §IV documents the rename-as-drop behavior and
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
`make_surveyweights_data()` returns only character columns; spec says "character or factor"
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
**Resolution:** Added `surveyweights_error_population_cell_duplicate` to §VIII,
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
