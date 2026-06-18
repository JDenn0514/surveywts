# Audit — calibrate-to-survey-opsomer PR 1

**Verdict**: BLOCK
**PR**: feature/cts-opsomer-validation
**Date**: 2026-06-17

---

## Profile gates

| # | Gate | Result | Notes |
|---|------|--------|-------|
| 1 | devtools::document() | PASS | `git diff --exit-code NAMESPACE man/` clean — no drift |
| 2 | devtools::test() | PASS | FAIL 0 \| WARN 624 \| SKIP 3 \| PASS 3624 |
| 3 | devtools::run_examples() | PASS | All 32 example files ran clean; 15 expected warnings |
| 4 | R CMD build | PASS | `surveywts_0.2.0.9000.tar.gz` built successfully |
| 5 | R CMD check --as-cran | BLOCK | 1 ERROR + 1 WARNING — see Findings below |
| 6 | pkgdown | SKIPPED — scope | No new exported functions; pre-pkgdown phase per roadmap |
| 7 | covr::package_coverage() | PASS | 96.47% total; `calibrate_to_survey.R` at 98.98% |

---

## CRAN cookbook violations

Scan performed on `R/calibrate_to_survey.R` (the only R/ file modified by this PR).

| Pattern | Result |
|---------|--------|
| `\bT\b` or `\bF\b` as logicals | None found |
| `set.seed()` without seed arg | None found (one `set.seed(1)` in `@examples` — acceptable) |
| `print(` or `cat(` at line start | None found |
| `options(warn = -1` | None found |
| `installed.packages(` | None found |
| `<<-` | None found |
| `par(` or `options(` without `on.exit()` | None found |
| `mc.cores = [3-9]` | None found |
| `@importFrom` in R/ (non-S3) | None found |

**CRAN cookbook violations: None.**

---

## R CMD check findings

### Pre-existing issue (not caused by this PR)

The WARNING and ERROR both stem from a Unicode `≥` character (U+2265) in
`man/ns_wave1.Rd` line 229. This character was introduced by commit 7713260
(`feat(data): harmonize demographic columns across all 6 bundled datasets`)
which is the commit immediately before this PR on the develop branch. It is
confirmed present in `git show HEAD~2:man/ns_wave1.Rd` (the develop baseline).
This PR's commit does not touch `man/ns_wave1.Rd`.

- `* checking PDF version of manual ... WARNING` — LaTeX cannot render `≥`
- `* checking PDF version of manual without index ... ERROR` — downstream of the WARNING

These are **pre-existing** relative to this PR and must be fixed on the develop
branch independently. They do not represent regressions introduced by this PR.

---

## Before/After Comparison

| Metric | Before PR | After PR | Delta |
|--------|-----------|----------|-------|
| Tests passing | 3589 | 3624 | +35 |
| Tests failing | 0 | 0 | 0 |
| Tests skipped | 3 | 3 | 0 |
| Test-level warnings | 851 | 624 | -227 |
| Coverage | baseline ~96% | 96.47% | neutral/+ve |
| R CMD check errors | 1 (pre-existing) | 1 (pre-existing) | 0 |
| R CMD check warnings | 1 (pre-existing) | 1 (pre-existing) | 0 |
| R CMD check notes | 2 (pre-existing) | 2 (pre-existing) | 0 |

---

## Test-spec coverage

### New error classes from test-spec-calibrate-to-survey-opsomer.md

| Error class | `expect_error` | `expect_snapshot` | Status |
|-------------|---------------|-------------------|--------|
| `surveywts_error_scale_not_found` (primary NULL, targets=NULL) | ✓ | ✓ | covered |
| `surveywts_error_scale_not_found` (control NULL, targets=NULL) | ✓ | ✓ | covered |
| `surveywts_error_scale_not_found` (primary NULL, targets non-NULL) | ✓ | missing | BLOCK |
| `surveywts_error_scale_not_found` (control NULL, targets non-NULL) | missing | missing | BLOCK |
| `surveywts_error_targets_not_named_list` (unnamed element) | ✓ | ✓ | covered |
| `surveywts_error_targets_not_named_list` (empty list) | ✓ | ✓ | covered |
| `surveywts_error_targets_not_named_list` (not a list) | ✓ | ✓ | covered |
| `surveywts_error_targets_variable_not_found` | ✓ | ✓ | covered |
| `surveywts_error_targets_element_invalid` (string element) | ✓ | ✓ | covered |
| `surveywts_error_targets_element_invalid` (unnamed vector) | ✓ | ✓ | covered |
| `surveywts_error_targets_totals_invalid` (count=0) | ✓ | ✓ | covered |
| `surveywts_error_targets_totals_invalid` (count<0) | ✓ | missing | BLOCK |
| `surveywts_error_targets_totals_invalid` (count=NA) | ✓ | missing | BLOCK |
| `surveywts_error_targets_totals_invalid` (prop sum !=1) | ✓ | ✓ | covered |
| `surveywts_error_control_level_missing` (targets=NULL) | ✓ | ✓ | covered |
| `surveywts_error_control_level_missing` (targets non-NULL) | ✓ | missing | BLOCK |

### Regression guard tests (no skip_if_not_installed required)

| Error class | Fires without svrep skip | Status |
|-------------|--------------------------|--------|
| `surveywts_error_primary_not_replicate` | ✓ (no skip) | covered |
| `surveywts_error_primary_no_repweights` | ✓ (no skip) | covered |
| `surveywts_error_control_not_replicate` | ✓ (no skip) | covered |
| `surveywts_error_control_no_repweights` | ✓ (no skip) | covered |
| `surveywts_error_reference_design_not_taylor` | has `skip_if_not_installed("svrep")` | NOTE |
| `surveywts_error_unit_scale_invalid` | has `skip_if_not_installed("svrep")` | NOTE |
| `surveywts_error_variables_not_found` | ✓ (no skip) | covered |

NOTE: `reference_design_not_taylor` and `unit_scale_invalid` regression guards
have an unnecessary `skip_if_not_installed("svrep")`. The checks fire before
any svrep call (validation steps 3 and 4 respectively) so svrep is not needed.
The test-spec section 25 header explicitly says "no skip_if_not_installed".
However, since svrep IS installed in this environment, these tests DO run and
pass. This is a test quality issue but does not cause test failures here.

### Helper function updates

| Requirement | Status |
|-------------|--------|
| `make_replicate_design(n, R=50L, seed)` signature | ✓ present (line 165, helper-test-data.R) |
| `make_nonprob_replicate_design(n, R=30L, seed)` signature | ✓ present (line 437, helper-test-data.R) |
| `@variables$scale` populated in `make_nonprob_replicate_design` | ✓ set to `1/R` (line 455) |

### type / algorithm arg_match tests

| Scenario | Status |
|----------|--------|
| `type = "prop"` accepted with `targets = NULL` | ✓ covered (section 18) |
| `algorithm = "nr"` accepted with `method = "linear"` | ✓ covered (section 18) |

---

## Findings

### BLOCK-1: Missing dual-pattern coverage for `surveywts_error_scale_not_found` (targets non-NULL)

The test-spec (error paths table, lines 199-201) requires dual pattern for
`scale_not_found` in both the `targets=NULL` and `targets != NULL` conditions,
for both `primary_design` and `control_design`. The test file covers only the
`targets=NULL` paths with dual pattern. The `targets != NULL` / primary path
has only `expect_error` (no `expect_snapshot`). The `targets != NULL` /
control path has neither `expect_error` nor `expect_snapshot`.

**Fix required**: Add `expect_snapshot(error = TRUE, ...)` to the existing
`targets != NULL` / primary block. Add a new test block for
`control@variables$scale = NULL` with `targets != NULL` (full dual pattern).

**Classification**: `missing-dual-pattern` (3 missing snapshot calls; 1 missing
test block)

### BLOCK-2: Missing snapshots for three `targets_totals_invalid` and `control_level_missing` triggers

The test-spec requires dual pattern for all error path rows. Four triggers have
only `expect_error` without `expect_snapshot(error = TRUE, ...)`:

1. `targets_totals_invalid` — `type = "count"`, total < 0
2. `targets_totals_invalid` — `type = "count"`, total = NA
3. `control_level_missing` — `targets != NULL`

**Fix required**: Add `expect_snapshot(error = TRUE, ...)` blocks for each.

**Classification**: `missing-dual-pattern`

### NOTE-1: Pre-existing R CMD check WARNING/ERROR (not caused by this PR)

`man/ns_wave1.Rd` contains Unicode character `≥` (U+2265) that causes LaTeX
to fail when building the PDF manual. This was introduced by commit 7713260
on the develop branch before this PR was opened. It is a develop-branch issue,
not a regression from this PR's changes.

**Action**: Fix on develop branch separately (replace `≥` with `\eqn{\ge}`
in `R/data.R` and re-run `devtools::document()`). Does not block this PR if
the pre-existing baseline already had the same R CMD check status, which it
did.

However, per the profile gate definition: Gate 5 is stated as "BLOCK on any
ERROR or WARNING." The WARNING and ERROR exist in this checkout. Applying the
gate strictly: **BLOCK on Gate 5**.

---

## Summary

BLOCK. Gate 5 (R CMD check) produces 1 ERROR and 1 WARNING due to a
pre-existing Unicode character in `man/ns_wave1.Rd` (introduced before this
PR). Additionally, the test-spec dual-pattern requirement is violated for 5
error path triggers: `scale_not_found` with `targets != NULL` (missing 1
snapshot + 1 complete test block), `targets_totals_invalid` count<0 and
count=NA (2 missing snapshots), and `control_level_missing` with targets
non-NULL (1 missing snapshot). Classification: `missing-dual-pattern` for the
test gaps; the R CMD check block is `pre-existing-unicode-in-rd`.
