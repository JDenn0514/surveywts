# Review — calibrate-to-survey-opsomer PR 1

**Date:** 2026-06-17
**Reviewer:** reviewer agent
**Audit verdict reviewed:** PASS (audit-calibrate-to-survey-opsomer-pr1-v2.md)
**Final verdict:** PASS

---

## Summary

PR 1 (`feature/cts-opsomer-validation`) adds three new arguments to
`calibrate_to_survey()` (`targets`, `type`, `algorithm`), six new error
classes with validation helpers `.check_control_levels()` and
`.validate_targets_for_opsomer()`, regression guard tests for all existing
error classes, and an `R` parameter on both replicate-design helpers.

---

## Step 1 — Convergence check

### Spec coverage

PR 1 is responsible for spec validation order steps 10–12 and the six new
error classes. The function contracts items covered by PR 1 are:

| Contract item | impl-{id}.md acceptance criterion | Code present | Test present |
|---|---|---|---|
| `targets`, `type`, `algorithm` in signature | Yes | Yes (lines 147–154) | Yes (sections 18, 21–24) |
| `type` arg_match | Yes | Yes (line 157) | Yes (section 18) |
| `algorithm` arg_match | Yes | Yes (line 159) | Yes (section 18) |
| `surveywts_error_scale_not_found` fires on all calls | Yes | Yes (lines 352–376) | Yes (sections 19 — 4 triggers) |
| `surveywts_error_control_level_missing` fires on all calls | Yes | Yes (lines 379, 559–585) | Yes (section 20 — 2 triggers) |
| `surveywts_error_targets_not_named_list` — unnamed, empty, not-a-list | Yes | Yes (lines 591–633) | Yes (section 21 — 3 triggers) |
| `surveywts_error_targets_variable_not_found` | Yes | Yes (lines 636–654) | Yes (section 22) |
| `surveywts_error_targets_element_invalid` — string, unnamed vector | Yes | Yes (lines 656–681) | Yes (section 23 — 2 triggers) |
| `surveywts_error_targets_totals_invalid` — zero, negative, NA, prop≠1 | Yes | Yes (lines 683–731) | Yes (section 24 — 4 triggers) |
| Regression guards for 7 existing error classes without svrep skip | Yes | N/A | Yes (section 25) |

No gaps found.

### Test-spec coverage of spec

Every contract item in the spec for PR 1 (validation order 10–12, all six new
error classes) has a corresponding scenario in `test-spec-{id}.md`. The
test-spec error path table lists 16 triggers for new classes; all 16 are
present in sections 18–24 of the test file. No planner gaps.

### Implementation coverage of spec

`impl-{id}.md` PR 1 write surface:

- `plans/error-messages.md` — verified; all 6 classes present
- `tests/testthat/helper-test-data.R` — `R` parameter added to both helpers
- `tests/testthat/test-sample-calibration.R` — sections 18–25 added (+41 tests)
- `R/calibrate_to_survey.R` — new signature + validation steps 10–12 added

`implementation.md` (audit) write surface matches `impl-{id}.md` entries.

---

## Step 2 — Tolerance Integrity check

PR 1 has no numerical computation tests; all tests are error/warning path
tests. No numerical tolerances are required. The `test-spec-{id}.md §Tolerances`
table applies to PR 2 tests only. No tolerance violations possible.

---

## Step 3 — Scope discipline check

PR 1 write surface per `impl-{id}.md`:

- `plans/error-messages.md`
- `tests/testthat/helper-test-data.R`
- `tests/testthat/test-sample-calibration.R`
- `R/calibrate_to_survey.R`
- `changelog/calibration/feature-cts-opsomer-validation.md` (changelog entry)

The audit confirms: only `R/calibrate_to_survey.R` was changed in `R/`. No
extra files modified. No missing files.

The audit also confirms no regressions outside PR 1 scope: 0 previously
passing tests changed to failing state.

---

## Step 4 — CRAN cookbook sanity

Audit §CRAN Cookbook Violations: "No violations found." The `set.seed(1)` on
line 89 of `calibrate_to_survey.R` is inside an `@examples` block (confirmed
by audit), not in functional code. Audit verdict was PASS. No PASS-with-
violations contradiction.

All profile gates have results or documented skips in the audit:

| Gate | Result |
|---|---|
| devtools::document() | PASS |
| devtools::test() | PASS |
| devtools::run_examples() | PASS |
| R CMD build | PASS |
| R CMD check --as-cran | PASS (0 errors, 0 warnings, 1 pre-approved NOTE) |
| pkgdown::build_site() | SKIPPED — pre-pkgdown scope (documented) |
| covr::package_coverage() | PASS (96.47%) |

The pkgdown skip is valid: no new exported functions in PR 1 per
`r-package-profile.md` skip condition ("no skip when exports change" — PR 1
adds only arguments and internal helpers, no export changes).

---

## Step 5 — Documentation standards

PR 1 does not update the roxygen2 documentation (that is PR 2's deliverable
per `impl-{id}.md`). The `@param targets`, `@param type`, and `@param algorithm`
blocks are present in the file (lines 27–42) from PR 1's builder work — a spot
check confirms:

- `@param targets` present with type annotation and NULL behavior described
- `@param type` present with `"prop"`/`"count"` options and `rlang::arg_match()`
  noted
- `@param algorithm` present with `"classic_ipf"`/`"nr"` options and
  `method != "rake"` behavior noted

The full Tier 3 algorithm/convergence/warnings/limitations/references sections
are deferred to PR 2 per plan. The existing `@references` block is present.
The `@examples` block is a pre-PR-1 artifact using svrep — updating examples
is explicitly a PR 2 deliverable. No documentation violations for PR 1 scope.

One NOTE: `@param bounds` line 44 still has the stale note "per-unit
`bounds_scale` is not supported; use scalar bounds only." The impl plan
explicitly flags this for removal in PR 2. This is correctly deferred; no
violation for PR 1.

The `@unit_scale` `@param` on line 47 still says "Passed to svrep as the
`variance` argument" — also a PR 2 stale-note item. Deferred; no PR 1
violation.

---

## Step 6 — Coverage floor check

Coverage: 96.47% (audit). Above the 95% gate, above the 95% block threshold.
No drop in new-line coverage: the new validation helpers
`.check_control_levels()` and `.validate_targets_for_opsomer()` are exercised
by all six new error-class test blocks (16 triggers total). No uncovered new
lines detected from the audit's before/after (+41 tests, all passing).

---

## Step 7 — Comprehension alignment

No `comprehension.md` file exists for this pipeline; step not applicable.

---

## Findings

| # | Severity | Finding |
|---|---|---|
| F1 | NOTE | `@param unit_scale` and `@param bounds` contain stale svrep-specific language; both are flagged for PR 2 cleanup in `impl-{id}.md`. No action required for PR 1. |
| F2 | NOTE | `@examples` block still uses `svrep::as_bootstrap_design()` and `data(api, package = "survey")`. PR 2 deliverable per plan; guarded with `requireNamespace` is a PR 2 task. R CMD check passed (`devtools::run_examples()` gate: PASS), so no current breakage. |
| F3 | NOTE | `.check_control_levels()` is explicitly a temporary PR 1 helper per `impl-{id}.md` notes; superseded by `.compute_control_totals()` in PR 2. Builder correctly documented this with a comment at line 552–553. No action required. |

No BLOCK or STOP findings.

---

## Verdict

**PASS**

All convergence checks, tolerance integrity, scope discipline, CRAN cookbook,
documentation standards, and coverage floor checks pass. The audit verdict
(PASS) is consistent with the evidence. PR 1 is clear to proceed to PR 2.
