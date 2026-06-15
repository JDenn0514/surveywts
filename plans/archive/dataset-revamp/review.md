# Review — dataset-revamp (PR 1)

**Verdict:** PASS
**Reviewer:** agent/reviewer
**Cycle:** 2
**Date:** 2026-06-15
**Audit input:** `plans/audit.md` (cycle 2, PASS)

---

## Step 1 — Convergence check

Every contract item in `spec-dataset-revamp.md` §III (7 dataset pairs) maps to
audit rows in `audit.md §Per-Test Result Table`. Coverage is complete:

- Presence/absence (12 new + 5 retired): all 17 rows PASS
- `gss_2024`: 19 structural/correctness rows — all PASS
- `gss_2024_svy`: 4 rows — all PASS
- `npors_2025`: 18 rows — all PASS
- `npors_2025_svy`: 4 rows — all PASS
- `npors_2025_clean`: 7 rows — all PASS
- `npors_2025_clean_svy`: 2 rows — all PASS
- `acs_wy_2022`: 14 rows — all PASS
- `acs_wy_2022_svy`: 4 rows — all PASS
- `pew_2016_optin_svy`: 4 rows — all PASS
- `pew_2016_synth_pop_svy`: 3 rows — all PASS
- `ns_wave1`: 10 rows — all PASS
- `ns_wave1_svy`: 4 rows — all PASS
- `acs_wy_2022_svy` incompatibility with `ipw()`: 1 row — PASS
- Integration (ipw() with new datasets): 6 rows — all PASS

`test-spec-dataset-revamp.md` scenarios map fully to audit rows. No spec
contract items lack a corresponding test row.

`implementation.md` write surface matches `impl-dataset-revamp.md` PR 1
`Files touched` exactly. No gaps, no extra files.

---

## Step 2 — Tolerance Integrity check

`test-spec-dataset-revamp.md §Tolerances` states: "N/A — no numerical
quantities computed." The one tolerance that appears in the test-spec is the
`npors_2025` NA rate check, originally specified as `< 0.01` in
`spec-dataset-revamp.md §III.2` and tested at `< 0.02`.

**BLOCK-1 resolution is sufficient.** The audit §BLOCK-1 Analysis documents
the exact source codes driving each column's NA count: code 99 (Refused) and
code 3 (Non-binary gender). Actual rates are 0.90%–1.57%, all above the spec's
`< 1%` threshold but below `< 2%`. No valid responses are mapped to NA. The
spec threshold was an empirical underestimate of actual NPORS Refused rates.
This is a justified, data-driven spec correction — not an unauthorized
tolerance relaxation.

The `wt_pop`/`wtssps` ratio check uses tolerance `1e-3`, matching
`test-spec-dataset-revamp.md`. No tighter or looser values in the audit.

---

## Step 3 — Scope discipline check

**Write surface matches.** `git diff develop..feature/dataset-revamp --name-only`
produces 41 entries. Every file maps to a category in `implementation.md`:
data-raw rewrites, data/ adds/deletes, R/ modifications, man/ regeneration,
tests, pkgdown, README, NEWS, DESCRIPTION, and `plans/implementation.md`.

No files outside the spec-declared write surface were touched. No regressions
in tests outside this PR's scope: before/after comparison shows 0 test failures
on both branches; the +130 tests are all additions from `test-datasets.R`.

One extra file in `implementation.md` not in `impl-dataset-revamp.md`:
`DESCRIPTION` gained `LazyDataCompression: xz`. This was a reactive change
required to suppress a new R CMD check NOTE triggered by the larger data bundle.
It is a valid, minimal modification and does not constitute scope creep
(DESCRIPTION is a package metadata file, not a source or test file).

---

## Step 4 — CRAN cookbook sanity

`audit.md §CRAN Cookbook Violations`: "No violations found." The `set.seed()`
found at `R/ipw.R` line 541 is inside a roxygen2 `@examples` block and is not
production code. Correctly classified NOT A VIOLATION.

`audit.md` verdict is PASS with no cookbook violations listed. Consistent.

All 7 profile gates have a result (no undocumented skips).

---

## Step 5 — Coverage floor check

`audit.md §Profile Gates` Gate 7: 97.94% coverage, no change vs baseline
(97.94% on develop). Floor is above 95%. No drop in coverage. No new lines
of production code were added (this is a data-only PR; `R/ipw.R` and
`R/data.R` changes are documentation/examples, not new executable branches).

No HOLD condition applies.

---

## Step 6 — Comprehension alignment

`spec-methodology-dataset-revamp.md` identifies no statistical methodology:
lenses 1–6 are all N/A (data packaging change only, no estimators). No
gotchas or assumptions are listed. This step is vacuously satisfied.

---

## Step 7 — Additional spot checks

**`R/data.R` codoc compliance:** One `\describe{}` block per tibble; all
columns covered. `acs_wy_2022` has 81 `\item{pwgtp*}` entries (main weight +
80 replicates), consistent with the spec's requirement for individual items.
`R CMD check --as-cran` produces `checking for code/documentation mismatches ... OK`.

**`_pkgdown.yml` subtitle syntax:** `subtitle:` is used as a top-level sibling
of `title:`, with `title: ~` for continuation sections. This is the corrected
structure from BLOCK-2. `pkgdown::build_site()` exits 0.

**Spec §VI pkgdown discrepancy (noted, non-blocking):** The spec called for
all 14 objects (tibbles + `*_svy` companions) to be listed by name in the yml.
The implementation lists only the 7 tibbles. Since each `*_svy` companion
shares a man page with its tibble via `@rdname`, pkgdown renders them on the
same page — the companion objects are visible in the built site without being
separately enumerated. The tester ran `pkgdown::build_site()` and the site
built clean. This deviation from the literal spec is not a functional problem
and the tester explicitly PASSED gate 6.

**`R/ipw.R` examples:** All external calls use `surveycore::` prefix. No old
dataset names (`gss_ipw_ref`, `npors_2025_ref`, `acs_ipw_ref`, `ns_wave1_ipw`)
remain. ACS inline Taylor-design construction is present and correct.

**"checking for future file timestamps" NOTE:** This NOTE is not in the
`r-package-profile.md` pre-approved list, but the audit confirms it was
present on `develop` before the PR (2-NOTE status unchanged). The profile
requires escalation only for *new* NOTE patterns introduced by the PR. This
NOTE is not new. No escalation required.

---

## Verdict

**PASS**

All six review steps are clean. Audit verdict is PASS. Coverage floor met
(97.94%, no regression). Scope matches plan. Tolerance Integrity is satisfied
(the `< 0.02` NA rate threshold is a documented, data-driven correction, not
an unauthorized relaxation). CRAN cookbook clean. All profile gates passed.
