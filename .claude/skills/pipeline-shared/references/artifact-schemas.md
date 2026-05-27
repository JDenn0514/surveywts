# Artifact Schemas

Every `.md` artifact in the workspace follows a fixed schema. Orchestrating
skills validate these sections before advancing state.

## `request.md`

```
# Request — {slug}

## Intent
{1–3 sentences: what the user asked for}

## Acceptance criteria
- {bullet list of observable outcomes}

## Attachments
- {any papers, PDFs, markdown files of journal articles the user provided}
- {any external references}
```

## `impact.md`

```
# Impact — {slug}

## Estimated scope
- Files touched: {count and list}
- Exported functions added/changed: {list}
- New dependencies: {list or "none"}
- CRAN-relevant: {yes/no — DESCRIPTION change, export change, new vignette}

## Smallness test
- Result: eligible-simplified | full-required
- Rationale: {one sentence}
```

## `comprehension.md` (methods-heavy only)

Required when the request involves a statistical estimator, variance formula,
algorithm, or references a paper or package implementation.

```
# Comprehension — {slug}

## Problem
{one paragraph in your own words}

## Formulas
{restated math; bind every symbol to a function argument or data column}
{use exact LaTeX or pseudocode — no prose substitutes}

## Gotchas
- {edge case} — {what to watch for}
- {e.g., zero-weight cells, single-PSU stratum, degenerate variance, negative calibrated weights}

## Reference mapping
- {paper/package} §{section/equation} → {design decision in spec}
- {e.g., Kish (1965) eq. 2.13 → effective_sample_size() formula}

## Assumptions
- {implicit constraint} — {why it matters}
```

## `spec-{id}.md`

The builder's input. Contains ONLY behavioral contract — no test scenarios,
no tolerances, no test datasets.

```
# Spec — {id}

**Status**: DRAFT | METHODS_REVIEWED | SPEC_READY
**Target version**: X.Y.Z.9000
**PR range**: PR n–m

## Scope
### In
### Out

## Architecture
- Files touched: {list}
- Functions added: {signatures}
- Functions modified: {signatures}
- Class changes: {list or "none"}

## Function contracts
For each function:
### `fn_name(args)`
- **Signature**: {full signature with defaults}
- **Arguments**: each with semantics, NULL behavior, valid range
- **Returns**: class, shape, columns, attributes
- **Errors**: one row per named error class (see plans/error-messages.md)
  | Class | Trigger condition |
  |-------|-------------------|
  | surveywts_error_* | ... |
- **Warnings**: one row per named warning class
- **Edge cases**: empty, single-row, all-NA, degenerate — exact behavior specified

## Quality gates
- {invariants that must hold across all inputs}

## Pipeline split
recommended | optional — {justification}
```

No test cases. No tolerances. No references to test-spec-{id}.md.

## `test-spec-{id}.md`

The tester's input. Contains ONLY validation scenarios — no implementation hints,
no file paths from `R/`, no internal helper names.

```
# Test-spec — {id}

## Reference oracle
- {package/function/version — e.g., survey::svymean, survey 4.2}

## Datasets
- {dataset → purpose}
- {e.g., make_surveywts_data(n=500, seed=42) → calibration test data}
- {e.g., api from survey package → numerical oracle comparison}

## Per-function test plan
### `fn_name`
- **Happy path**: {scenario, dataset, oracle call, tolerance}
  | Scenario | Dataset | Expected | Tolerance |
  |----------|---------|----------|-----------|
  | ... | ... | ... | 1e-10 |
- **Error paths**: one row per named error class
  | Error class | Trigger | Pattern |
  |-------------|---------|---------|
  | surveywts_error_* | {trigger} | expect_error(class=...) + snapshot |
- **Warning paths**: one row per named warning class
- **Edge cases**: one row per edge case from spec
  | Case | Input | Expected behavior |
  |------|-------|-------------------|
  | empty data | 0-row df | error: surveywts_error_empty_data |
- **Invariants**: `test_invariants(obj)` is first assertion for every test that
  constructs a `weighted_df` or `survey_nonprob`

## Tolerances
- Point estimates: 1e-10
- SE / variance: 1e-8
- CI bounds: 1e-6
- Deviations (with justification): {list}

## Profile gates (tester runs ALL unless skip condition applies)
- [ ] devtools::document() — NAMESPACE/man/ unchanged after run
- [ ] devtools::test() — all tests pass
- [ ] devtools::run_examples() — all @examples run clean
- [ ] R CMD check --as-cran — 0 errors, 0 warnings, notes reviewed
- [ ] pkgdown::build_site() — site builds (or SKIPPED — pre-pkgdown / scope)
- [ ] covr::package_coverage() — ≥ 95% (target 98%)
```

No implementation hints. No file paths from `R/`. No internal helper names.

## `impl-{id}.md`

```
# Implementation plan — {id}

## Overview
{2–3 sentences: what this plan delivers and how it relates to the spec}

## PR map
- [ ] PR 1: feature/{branch-slug} — {one-line goal}
- [ ] PR 2: feature/{branch-slug} — {one-line goal}

### PR 1: {Human-readable title}

**Branch:** `feature/{name}`
**Depends on:** PR {n} (or "none")

**Tasks** (2–5 min each, TDD sub-steps explicit):
1. Update `plans/error-messages.md` with new error/warning classes
2. Write failing test for {behavior} in `tests/testthat/test-{file}.R`
3. Confirm test fails for the right reason
4. Implement {function} in `R/{file}.R`
5. Verify test passes
6. Run devtools::document()
7. Verify full test suite passes
8. Write changelog entry

**Acceptance criteria** — observable outcomes before merge:
- [ ] devtools::check() 0 errors, 0 warnings, ≤2 pre-approved notes
- [ ] All tests in PR scope pass (list specific test names)
- [ ] coverage ≥ 98% overall
- [ ] plans/error-messages.md updated (if applicable)

**Files touched** — exact write surface:
- `plans/error-messages.md` — (if new classes)
- `R/{file}.R` — created | modified
- `tests/testthat/test-{file}.R` — created | modified
- `man/{fn}.Rd` — generated by devtools::document()
- `NAMESPACE` — generated by devtools::document()
```

## `implementation.md` (per PR)

```
# Implementation — PR {n} — {id}

## Write surface
- {file} — created | modified | deleted

## Summary
{what was implemented, in 3–5 bullets}

## Task checklist
- [x] {task 1}
- [x] {task 2}

## Signals raised
- {HOLD references, if any}

## CRAN compliance
- [x] TRUE/FALSE used throughout
- [x] :: used for external calls
- [x] No bare print()/cat()
- [x] devtools::document() run
- [x] All cli_abort()/cli_warn() have class=

## Notes for tester
(Optional — neutral observations, NOT implementation details)
```

Builder does NOT write about test results here. Builder's local unit tests run;
if they fail, builder iterates. Tester's audit is separate.

## `audit.md` (per PR)

```
# Audit — PR {n} — {id}

**Verdict**: PASS | BLOCK
**Date**: {YYYY-MM-DD HH:MM}

## Per-Test Result Table
| Test | Got | Expected | Tolerance | Pass |
|------|-----|----------|-----------|------|
| {name} | {value} | {value} | {value} | ✓ / ✗ |

## Before/After Comparison
| Metric | Before PR | After PR | Δ |
|--------|-----------|----------|---|
| tests passing | {n} | {m} | +{diff} |
| coverage | {%} | {%} | {±%} |
| R CMD check notes | {n} | {m} | {diff} |

## Profile gates
| Gate | Result | Notes |
|------|--------|-------|
| devtools::document() | PASS/FAIL | {drift detected or clean} |
| devtools::test() | PASS/FAIL | {summary} |
| devtools::run_examples() | PASS/FAIL | {summary} |
| R CMD check --as-cran | PASS/FAIL | {errors, warnings, notes} |
| pkgdown::build_site() | PASS/FAIL/SKIPPED | {reason if skipped} |
| covr::package_coverage() | {%} | {drop vs baseline} |

## CRAN cookbook violations
| File | Line | Violation | Class |
|------|------|-----------|-------|
(None — or list violations here)

## BLOCKs (if any)
(See signals.md BLOCK schema)
```

## `review.md` (per PR)

```
# Review — PR {n} — {id}

**Verdict**: PASS | BLOCK | STOP
**Date**: {YYYY-MM-DD HH:MM}

## Convergence checks
- Spec coverage: {implementation covers all items in spec-{id}.md §Function contracts — y/n}
- Test-spec coverage of spec: {test-spec-{id}.md covers all items in spec-{id}.md — y/n}
- Tolerance integrity: {tester used tolerances from test-spec — y/n}
- Scope discipline: {implementation.md write surface matches plan — y/n}
- Regression safety: {audit shows no tests outside PR scope changed state — y/n}
- Comprehension alignment: {all gotchas from comprehension.md tested or deferred — y/n}

## Cross-consistency notes
{narrative where implementation and audit disagree, if any}

## Decision
{1–3 sentences: why PASS, BLOCK, or STOP}

## STOP (if verdict=STOP)
(See signals.md STOP schema)
```

## `shipper.md` (per PR)

```
# Ship — PR {n} — {id}

**Branch**: feature/{slug}
**PR URL**: {url}
**Merged**: {YYYY-MM-DD HH:MM}
**Merge commit**: {sha}

## Timeline
- {HH:MM} branch created
- {HH:MM} pushed
- {HH:MM} PR opened
- {HH:MM} CI green
- {HH:MM} merged

## CI gates
- R-CMD-check (ubuntu-latest, release): PASS

## Post-merge
- [x] Plan checkbox marked
- [x] Branch deleted (local + remote)
```

## `status.md`

Append-only log. One line per transition:

```
{timestamp ISO8601}  {state}  ({justification})
```

Example:

```
2026-05-22T14:32:11Z  NEW
2026-05-22T14:38:00Z  COMPREHENDED  (comprehension.md written)
2026-05-22T15:10:22Z  SPEC_READY    (spec-review PASS, methods-review PASS)
2026-05-22T15:45:03Z  PLAN_READY    (plan-review PASS)
2026-05-22T17:22:18Z  PIPELINES_COMPLETE  (PR 1 audit PASS)
2026-05-22T17:30:44Z  REVIEW_PASSED
2026-05-22T17:55:00Z  DONE
```

## `decisions-{id}.md`

Append-only log of HOLD and STOP signals and their resolutions. See `signals.md`
for body schemas.
