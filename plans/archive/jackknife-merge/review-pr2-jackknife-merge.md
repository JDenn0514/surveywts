# Review — PR 2: jackknife-merge (Pass 2)

**Verdict: PASS**
**Date:** 2026-06-16
**Reviewer:** pipeline-reviewer

---

## Summary

Both BLOCK items from Pass 1 are resolved. All other checks carry over as PASS
from the previous review. Coverage is 96.42%, above the 95% floor. Verdict is
PASS with a coverage note.

---

## BLOCK Item 1 — 4 Missing Test Blocks (Builder)

**Resolution: CONFIRMED FIXED**

All 4 blocks are present in `tests/testthat/test-nps-jackknife.R`:

| Block | Location | Behavior tested | Result |
|-------|----------|-----------------|--------|
| `adj_method = "variance-units"` alone warns `jackknife_svrep_args_ignored` | line 744 | Correct class emitted | PASS |
| Multiple non-default svrep args emit exactly one warning | line 755 | `n_warnings == 1L` via `withCallingHandlers()` counter | PASS |
| Default svrep args emit no `jackknife_svrep_args_ignored` warning | line 774 | `expect_no_warning()` | PASS |
| `replicates_failed` block asserts `length(result@variables$repweights) < 5L` and scale = `(G_success-1)/G_success` | lines 710–715 | Both structural and numeric assertions present; tolerance `1e-12` | PASS |

The test blocks test the correct behaviors. The "multiple args → one warning" block
uses `withCallingHandlers()` with a counter, which is the correct mechanism for
counting warning emissions. The scale assertion at line 712–715 captures the
live `G_success` from the result and validates the formula — this correctly
handles the case where any number of replicates fail, not just a hardcoded count.

Tester confirmed: 137 PASS in `nps-jackknife` filter, 3573 PASS full suite, 0
failures. Consistent with the 5 new assertions (+5 PASS over prior 3568).

---

## BLOCK Item 2 — pkgdown Gate (Planner)

**Resolution: CONFIRMED FIXED**

`plans/decisions-jackknife-merge.md` §2026-06-16 records an authorized deferral:
pipeline owner sign-off, pre-Polish phase (Diagnostics, two phases before Polish),
and documented rationale that the deleted export has no live reference page risk.

`r-package-profile.md` §pkgdown skip condition includes: "during pre-Polish phases,
pkgdown may be SKIPPED — Polish if pkgdown CI is not yet wired up." The audit
logs this as `SKIPPED — pre-pkgdown`. The label in the audit (`pre-pkgdown`)
differs from the profile label (`Polish`) by one word, but the substance is
identical: pre-Polish phase, authorized deferral, logged in both `audit.md` and
`decisions-jackknife-merge.md`. This is not an integrity violation.

Note: the profile's `SKIPPED — scope` exception (which has a hard "no skip when
exports change" clause) is distinct from the `SKIPPED — Polish` (pre-pkgdown)
exception. The planner correctly invoked the pre-pkgdown exception, not the
scope exception. The authorization is valid.

---

## Coverage

**96.42% — PASS (above 95% floor)**

Coverage improved by 0.67pp from 95.75% to 96.42% following the 4 new test
blocks. The gap vs. the 98% target is concentrated in
`R/jackknife-dagjk-utils.R` (70.90%) and `R/create_jackknife_weights.R`
(85.71%). These files contain the DAGJK engine internals including paths
reachable only under specific stratum configurations (`n_h < G` extended
formula), documented `# nocov` defensive branches, and failure-mode branches
that require pathological data to trigger.

Coverage is above the 95% floor. The drop in new code was addressed by the
4 new test blocks (the 0.67pp improvement). No new code added by this PR has
zero coverage (all code paths have at least partial exercise).

This is a WARNING, not a STOP, per the profile (95–98% range). The gap is
appropriately noted for the Diagnostics release when additional stratum
configurations will be exercised by check_balance() integration tests.

---

## All Other Checks (Carry Over from Pass 1)

| Check | Result |
|-------|--------|
| Spec coverage — all contracts covered | PASS |
| Test-spec coverage of spec | PASS (all 4 gaps now closed) |
| Implementation coverage of spec | PASS |
| Tolerance integrity — no relaxation | PASS |
| Scope discipline — write surface matches impl plan | PASS |
| CRAN cookbook — 0 violations | PASS |
| Profile gates — R CMD check 0E/0W/0N | PASS |
| Documentation tier (Tier 3, `create_jackknife_weights`) | PASS |
| Error class consistency — all classes match error-messages.md | PASS |
| Comprehension alignment — all gotchas covered | PASS |

---

## Verdict: PASS

PR 2 of jackknife-merge is ready to merge to `develop`.
