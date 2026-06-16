# Review — PR 1: feature/jackknife-dagjk-engine

**Date:** 2026-06-16
**Reviewer:** reviewer agent
**Verdict: PASS**

---

## Inputs read

- `plans/spec-jackknife-merge.md`
- `plans/test-spec-jackknife-merge.md`
- `plans/comprehension-jackknife-merge.md`
- `plans/impl-jackknife-merge.md`
- `plans/audit-pr1-jackknife-merge.md`
- `R/jackknife-dagjk-utils.R` (new)
- `R/create_group_jackknife_weights.R` (modified)
- `tests/testthat/test-nps-group-jackknife.R` (modified)

Note: `plans/implementation-jackknife-merge-pr1.md` does not exist. The builder
did not produce a separate implementation artifact for PR 1. The builder's work
is instead audited directly from the changed files.

---

## Step 1 — Convergence check

**PR 1 scope per `impl-jackknife-merge.md` §PR 1:** Pure refactor. Three
helpers migrated to `R/jackknife-dagjk-utils.R`; all `dagjk_*` error/warning
class strings renamed to `jackknife_*`; no public API change.

**Spec coverage for PR 1:**

The spec (`spec-jackknife-merge.md §DAGJK internals §Error class updates`)
lists five class-string substitutions required in PR 1. All five verified
present in `R/jackknife-dagjk-utils.R`:

| Required substitution | Status |
|-----------------------|--------|
| `dagjk_degenerate_replicate` → `jackknife_degenerate_replicate` | PASS — both `.dagjk_single_replicate()` and `.dagjk_single_replicate_calib()` use `surveywts_error_jackknife_degenerate_replicate` |
| `dagjk_groups_invalid` → `jackknife_replicates_invalid` | PASS — `.validate_replicates_dagjk_arg()` line 27 |
| `dagjk_groups_not_whole_number` → `replicates_not_whole_number` | PASS — line 37 |
| `dagjk_groups_too_small` → `jackknife_replicates_too_small` | PASS — line 47 |
| `dagjk_groups_exceeds_n` → `jackknife_replicates_exceeds_n` | PASS — line 63 |

In `R/create_group_jackknife_weights.R`, the remaining six class strings
substituted per `impl-jackknife-merge.md §Task 1.4`:

| Required substitution | Status |
|-----------------------|--------|
| `dagjk_requires_nonprob` → `unsupported_class` | PASS — line 163 |
| `dagjk_no_history` → `jackknife_no_history` | PASS — line 221 |
| `dagjk_no_reference` → `jackknife_no_reference` | PASS — lines 253, 281 |
| `dagjk_all_replicates_failed` → `jackknife_all_replicates_failed` | PASS — line 416 |
| `dagjk_repweights_overwritten` → `jackknife_repweights_overwritten` | PASS — line 300 |
| `dagjk_small_groups` → `jackknife_small_groups` | PASS — line 313 |
| `dagjk_replicates_failed` → `jackknife_replicates_failed` | PASS — line 398 |
| `dagjk_negative_replicate_weights` → `jackknife_negative_replicate_weights` | PASS — line 443 |

**Test-spec coverage for PR 1:**

`test-spec-jackknife-merge.md` is a spec for the merged PR 2 API. PR 1 is
explicitly noted as maintaining the *existing* test file for the old API
(`test-nps-group-jackknife.R`). The impl plan (§PR 1 notes) states: "PR 1
covers no scenarios from `test-spec-jackknife-merge.md` directly." This is
correct and expected. The existing test suite exercises all renamed classes
via the old `create_group_jackknife_weights()` API, which is the only
applicable coverage surface for PR 1. Audit confirms 3676 tests passing.

**Audit alignment with implementation:** Audit's three grep checks confirmed
by manual grep:
- `grep -rn "surveywts_.*_dagjk" R/jackknife-dagjk-utils.R` → 0 hits: CONFIRMED
- `grep -rn "surveywts_.*_dagjk" R/create_group_jackknife_weights.R` → 0 hits: CONFIRMED
- `grep -rn ".validate_groups_arg" R/` → 0 hits: CONFIRMED

**Test file `dagjk` references:** Five occurrences of `dagjk` in
`test-nps-group-jackknife.R` are all inside prose comments explaining why a
warning is defensive — not in any `class=` assertion. No assertion uses a
retired class name. PASS.

---

## Step 2 — Tolerance Integrity check

`test-spec-jackknife-merge.md §Tolerances` specifies `1e-10` for scale factors.
Tests use `1e-12` (tighter, e.g., lines 20, 771, 1346 of the test file).
Tighter tolerance is acceptable per reviewer rules — noted here, not a STOP.

No tolerance was relaxed. PASS.

---

## Step 3 — Scope discipline check

**PR 1 must NOT include:**
- Extended formula or Inf weight check (PR 2 items) — NOT present. The `is.finite`
  on line 52 of `jackknife-dagjk-utils.R` is the pre-existing Phase 1/Phase 2
  ceiling check logic (`combined_n = Inf` skips ceiling), not the Inf weight trap
  described for PR 2.
- Any changes to `create_jackknife_weights.R` — confirmed unchanged (old
  `"delete-1"` / `"random-groups"` API).
- Deletion of `create_group_jackknife_weights.R` — file still exists.
- Any changes to `create_replicate_weights.R` — confirmed unchanged (still
  has `"group-jackknife"` arm and still calls `create_group_jackknife_weights()`).

**Files touched by PR 1 (from impl plan §PR 1):**
- `R/jackknife-dagjk-utils.R` — NEW: present and correct
- `R/create_group_jackknife_weights.R` — MODIFIED: class strings updated, helpers removed
- `tests/testthat/test-nps-group-jackknife.R` — MODIFIED: class assertions updated
- `tests/testthat/_snaps/nps-group-jackknife.md` — snapshots regenerated (per audit)

No extra files were touched. PASS.

---

## Step 4 — CRAN cookbook sanity

Audit §CRAN cookbook scan shows: 0 `<<-`, 0 `library()`/`require()`, 0
`Sys.setenv()`, 0 top-level `options()`. The `set.seed()` hit (line 328 of
`create_group_jackknife_weights.R`) is inside a user function gated on a
`seed` argument — standard practice, not a cookbook violation. Audit verdict:
"No CRAN cookbook violations." PASS.

---

## Step 5 — Documentation standards

PR 1 makes no changes to exported function roxygen2 documentation.
`create_group_jackknife_weights()` roxygen is unchanged from pre-PR state.
`devtools::document()` confirmed NAMESPACE and man/ unchanged (audit §Profile
gates). No documentation standards check needed for PR 1. PASS.

---

## Step 6 — Coverage floor check

`covr::package_coverage()` = 97.86% (audit §Profile gates). Exceeds 95% floor.
PR 1 is a pure refactor — no new lines of production code were added except
renamed class strings and one new file with migrated helpers. Coverage of the
migrated helpers is maintained by the existing `test-nps-group-jackknife.R`
test suite (3676 tests passing). PASS.

---

## Step 7 — Comprehension alignment

`comprehension-jackknife-merge.md` lists 10 gotchas. PR 1 is a pure refactor
and the spec explicitly states that the extended formula (gotcha 2, n_h < G
dispatch), the Inf weight trap (gotcha 7), and the single-PSU stratum check
(gotcha 1) are PR 2 items. Comprehension alignment is evaluated at PR 2, not
PR 1. No gaps attributable to PR 1. PASS.

---

## Deferred items confirmed as PR 2 scope

The audit lists 9 deferred scenarios. All are confirmed as genuine PR 2 scope:
they all require `create_jackknife_weights()` with the new unified
`type = c("jkn", "jk1", "grouped")` signature, which does not exist until PR 2
replaces the current file. The test file rename
(`test-nps-group-jackknife.R` → `test-nps-jackknife.R`) is also correctly
deferred to PR 2 (PR 1 retains the old file to preserve existing coverage).

---

## Issues found

None.

---

## Verdict

**PASS**

All convergence, tolerance integrity, scope discipline, CRAN cookbook,
documentation, and coverage checks pass. The builder correctly migrated the
three DAGJK engine helpers to `R/jackknife-dagjk-utils.R`, renamed all 13
`dagjk_*` class strings to their `jackknife_*` replacements in both modified
R files, and left all PR 2 items (extended formula, Inf weight check, merged
public API) untouched. The audit is accurate and its PASS verdict is correct.
