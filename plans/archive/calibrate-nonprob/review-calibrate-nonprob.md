# Review — calibrate-nonprob

**Verdict**: PASS
**PR**: feature/calibrate-nonprob
**Reviewer**: automated
**Date**: 2026-06-15

---

## Spec Coverage

### `calibrate_to_survey()` contracts

| Spec item | Status |
|-----------|--------|
| Accepts `survey_replicate` primary (existing) | ✅ Implemented; regression guard at line 1858 |
| Accepts `survey_nonprob` with repweights as primary | ✅ Implemented; lines 141–189 of source; tested at line 1499 |
| Accepts `survey_nonprob` with repweights as control | ✅ Implemented; lines 191–237 of source; tested at line 1518 |
| Both `survey_nonprob` with repweights succeeds | ✅ Tested at line 1536 |
| Output class matches `primary_design` class | ✅ Class-dispatch at source lines 477–489; verified in all three happy-path blocks |
| `surveywts_error_primary_not_replicate` updated message | ✅ Snapshot at `_snaps/sample-calibration.md` line 7; mentions `survey_nonprob` |
| `surveywts_error_control_not_replicate` updated message | ✅ Snapshot at line 17 |
| `surveywts_error_primary_no_repweights` new class | ✅ Source line 186; dual pattern at test line 1669 |
| `surveywts_error_control_no_repweights` new class | ✅ Source line 234; dual pattern at test line 1695 |
| Validation order: primary class before control class | ✅ Test at line 1744 |
| Validation order: primary_no_repweights before control check | ✅ Test at line 1762 |
| `@variables$repweights = character(0)` triggers `primary_no_repweights` | ✅ Edge case at test line 1802 |
| `control_design` with `NULL` repweights triggers `control_no_repweights` | ✅ Covered at test line 1695 via `make_nonprob_no_repweights()` |
| History entry `operation = "calibrate_to_survey"` appended | ✅ Tested at line 1554 |
| `control_design_class` recorded correctly | ✅ Tested at lines 1575 and 1601 |
| Existing warnings unchanged | ✅ No changes to warning code paths |

### `calibrate_to_estimate()` contracts

| Spec item | Status |
|-----------|--------|
| Accepts `survey_nonprob` with repweights as `design` | ✅ Source lines 127–172; tested at line 1631 |
| Output class matches `design` class | ✅ Class-dispatch at lines 566–578; tested at line 1642 |
| `surveywts_error_design_not_replicate` updated message | ✅ Snapshot at `_snaps/sample-calibration.md` line 112 |
| `surveywts_error_design_no_repweights` new class | ✅ Source line 169; dual pattern at test line 1721 |
| Validation order: `design_no_repweights` before targets check | ✅ Test at line 1783 |
| `@variables$repweights = character(0)` triggers `design_no_repweights` | ✅ Edge case at test line 1828 |
| `targets_levels_mismatch` still fires with `survey_nonprob` design | ✅ Regression guard at line 1919 |
| History entry `operation = "calibrate_to_estimate"` appended | ✅ Tested at line 1647 |

### `plans/error-messages.md`

| Spec item | Status |
|-----------|--------|
| 3 existing `_not_replicate` rows updated | ✅ Lines 27–29 now describe expanded acceptance |
| 3 new `_no_repweights` rows added | ✅ Lines 30–32 |

---

## Scope Discipline

The feature branch was cut from commit `6588c47` (version 0.2.0 bump), and the
implementation commit `d62942b` synced all intervening `develop` work into one
commit alongside the feature code. When comparing against the branch point, the
only files with new feature logic are:

- `R/calibrate_to_survey.R` — two-step validation + class-dispatch constructor
- `R/calibrate_to_estimate.R` — same pattern
- `plans/error-messages.md` — 3 rows updated, 3 rows added
- `tests/testthat/helper-test-data.R` — two new helpers appended
- `tests/testthat/test-sample-calibration.R` — 21 new `test_that()` blocks (sections 12–17)
- `tests/testthat/_snaps/sample-calibration.md` — 3 new snapshots + 3 updated snapshots
- `changelog/calibrate-nonprob/feature-calibrate-nonprob.md` — changelog entry
- `.Rbuildignore` — 4 restored entries (BLOCK 1 fix)

The large diff against `develop` reflects the sync of develop → feature (all
other packages' R files, man/ files, data/, tests/ are carry-through from
prior PRs on develop). No files outside the write surface were modified by
the feature itself.

`.to_svyrep()` was not modified. No new exports were added. NAMESPACE diff
reflects only the sync, not new exports.

---

## Cross-artifact Consistency

| Check | Result |
|-------|--------|
| `implementation.md` write surface matches PR commits | ✅ Match; "Created" label in impl.md for modified files is a description artifact only |
| `audit.md` PASS verdict consistent with test results (3586 PASS, 0 FAIL) | ✅ Consistent |
| Error messages in source match spec §Error message format | ✅ All three new error classes match spec verbatim; `control_no_repweights` correctly omits "before calibrating" in the `"v"` bullet |
| BLOCK 1 documented in audit and resolved in commit `1ed5964` | ✅ Documented and resolved; re-run shows 0 notes |

---

## Code Quality

| Check | Result |
|-------|--------|
| All `cli_abort()` calls have `class=` | ✅ 6 new calls (3 `_no_repweights`, 3 updated `_not_replicate`); all have `class=` |
| `S7::S7_inherits()` used (not string-based `inherits()`) for S7 checks | ✅ All 6 S7 checks use fully-qualified class objects |
| Two-step validation structure (class check → repweights check) | ✅ Present in both functions with correct gating logic |
| `is_nonprob_primary` / `is_nonprob_design` cached before conditional | ✅ Avoids redundant S7 calls |
| Line length consistent with 80-char convention | ✅ `paste0()` used appropriately for long strings |
| No `@importFrom` added | ✅ Confirmed |
| Native `|>` pipe (not `%>%`) | ✅ Not applicable — no pipes in modified functions |
| `TRUE`/`FALSE` not `T`/`F` | ✅ CRAN compliance checklist confirms |

---

## Documentation

| Check | Result |
|-------|--------|
| `@param primary_design` describes both accepted types | ✅ `man/calibrate_to_survey.Rd` line 19 |
| `@param control_design` describes both accepted types | ✅ `man/calibrate_to_survey.Rd` line 23 |
| `@param design` in `calibrate_to_estimate.R` updated | ✅ `man/calibrate_to_estimate.Rd` line 19 |
| `@returns` (not `@return`) used | ✅ Both source files use `@returns` |
| `@returns` documents class-preservation rule | ✅ Both `.Rd` files state the class-matching rule |
| `@details` updated to reflect relaxed constraint | ✅ Both files replace "must be `survey_replicate`" with "must carry replicate weights — either as `survey_replicate` or `survey_nonprob`" |
| `man/*.Rd` files regenerated | ✅ `devtools::document()` confirmed by profile gate |
| Tier classification (Tier 2 — Standard) appropriate | ✅ No new algorithm; behavioral change only |
| `@seealso` missing for sibling functions | Note: pre-existing; not introduced by this PR; out of scope per spec |
| `@examples` use external `survey` package data | Note: pre-existing; not introduced by this PR; out of scope per spec |

---

## Test Quality

| Check | Result |
|-------|--------|
| Dual pattern (`expect_error` + `expect_snapshot`) for all 3 new error classes | ✅ Lines 1669, 1695, 1721 |
| `test_invariants(result)` called on every happy-path result | ✅ Present in all 5 happy-path blocks |
| `skip_if_not_installed("svrep")` present as first line in every new block | ✅ 21/21 new blocks have it |
| New snapshot entries committed | ✅ 3 new snapshots in `_snaps/sample-calibration.md` lines 277–308 |
| Updated `_not_replicate` snapshots accepted and committed | ✅ Lines 7, 17, 112 mention `survey_nonprob` |
| Regression guard: `survey_replicate` + `survey_replicate` returns `survey_replicate` | ✅ Line 1858; also asserts NOT `survey_nonprob` |
| Regression guard: `_not_replicate` errors still fire for wrong types | ✅ Lines 1873, 1887, 1904 |
| Validation order tests present | ✅ 3 tests at lines 1744, 1762, 1783 |
| Edge case `character(0)` repweights tested | ✅ Lines 1802, 1828 (primary and design) |
| History metadata assertions | ✅ history grows by 1; `operation` correct; `control_design_class` correct |

---

## Coverage Floor Check

| Metric | Value | Floor | Status |
|--------|-------|-------|--------|
| `covr::package_coverage()` | 97.98% | 95% | ✅ Above floor |
| Drop vs baseline (97.94%) | +0.04% | No drop | ✅ Increased |
| New lines coverage | All new paths covered by 39 new tests | — | ✅ |

---

## CRAN Cookbook Violations

None found per audit. `devtools::check()` returns 0 errors, 0 warnings, 0 notes at commit `1ed5964`.

---

## BLOCK/STOP Items

None. All checks pass.
