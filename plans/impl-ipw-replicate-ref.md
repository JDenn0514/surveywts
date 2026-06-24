# Implementation Plan — ipw-replicate-ref

**Status:** COMPLETE
**Spec:** `plans/spec-ipw-replicate-ref.md`
**Test-spec:** `plans/test-spec-ipw-replicate-ref.md`
**Target:** `v0.6.0.9000`

---

## Overview

This plan delivers Part A (widen `ipw()` to accept `survey_replicate` as a
`reference` argument), Part B (convert the `cps_2023` package dataset from a
plain `data.frame` to a `survey_replicate`), and Part C (remove the retired
`acs_wy_2022` / `acs_wy_2022_svy` datasets). No new exports and no algorithmic
change — this is a type-widening + data housekeeping PR.

Parts B and C must be completed before Part A's examples and tests can run
cleanly, so the task order reflects that dependency.

---

## PR Map

- [x] PR 1: `feature/ipw-replicate-ref` — widen `ipw()` reference to accept
  `survey_replicate`, retire ACS datasets (Part B skipped: inline construction)

---

## PR 1: ipw() type widening + cps_2023 conversion + ACS removal

**Branch:** `feature/ipw-replicate-ref`
**Depends on:** none

### Files (in execution order — groundwork → data → cleanup → TDD → implementation)

**Groundwork**
- `plans/error-messages.md` — retire `surveywts_error_svydesign_not_taylor`
  (strikethrough + redirect note); add `surveywts_error_reference_not_survey_design`

**Part B — data regeneration (must come before test-datasets.R and ipw.R examples)**
- `data-raw/cps-2023.R` — replace final `usethis::use_data()` + `message()`
  with `surveycore::as_survey_replicate()` construction, structural assertions,
  and `usethis::use_data(cps_2023, overwrite = TRUE)`
- *(run `source("data-raw/cps-2023.R")` to regenerate `data/cps_2023.rda`)*
- `R/data.R` (cps_2023 block) — replace `@description`, `@format`, and
  `@examples` per spec Part B; `@format` must use S7-slot `\describe{}` form
  (no individual `\item{}` for the 160 replicate columns — codoc does not apply
  to S7 objects)

**Part C — ACS removal**
- `data/acs_wy_2022.rda` — delete
- `data/acs_wy_2022_svy.rda` — delete
- `R/data.R` (acs_wy_2022 block, lines 371–536) — remove entire block; update
  `ns_wave1` `@seealso` to remove `[acs_wy_2022]` link
- `R/trim_weights.R` — replace `trim_weights(acs_wy_2022_svy)` with
  `trim_weights(cps_2023)` in `@examples`
- `tests/testthat/test-sample-calibration.R` — update stale comment at line
  3074 (comment-only change; no logic change)
- `tests/testthat/test-datasets.R` — remove lines 18 and 29 (`acs_wy_2022*`
  entries from dataset load tests); remove ACS structural test blocks (lines
  244–324); add six `cps_2023` structural tests per test-spec §test-datasets.R

**Part A — TDD: tests first (red phase)**
- `tests/testthat/test-nonprob-ipw.R` —
  - Add `survey_replicate` fixture construction helper (inline, using
    `make_nps_reference()@data` wrapped in `survey_replicate`)
  - Add happy-path blocks H-R1 through H-R5 (all must fail until ipw.R updated)
  - Update E-1 existing test: change `class = "surveywts_error_svydesign_not_taylor"`
    → `class = "surveywts_error_reference_not_survey_design"` and regenerate snapshot
  - Add error-path blocks E-2, E-3, E-4, E-5 (survey_nonprob, NULL, list, zero
    main weight in survey_replicate)
  - Add edge-case blocks EC-1 through EC-5

**Part A — implementation: make tests pass (green phase)**
- `R/ipw.R` —
  - Behavior Rule 2: replace single-class check with two-class `&&` check; retire
    `surveywts_error_svydesign_not_taylor`; use new class
    `surveywts_error_reference_not_survey_design`; update error message text per spec
  - `@param reference`: document both accepted classes; add downstream V_p note
    with Wu (2022) citation
  - `@details` "Variance estimation — refit required" subsection: add new
    paragraph for `survey_replicate` reference V_p path (§6.2)
  - `@examples`: replace ACS block with `cps_2023` block per spec
  - `@references`: add Wu (2022) entry

**Documentation + CI**
- Run `devtools::document()` — NAMESPACE and man/ must be in sync
- Run `testthat::snapshot_review()` — review and accept updated snapshot for
  the renamed error class (E-1); approve new snapshots for E-2 and E-3
- Run `devtools::run_examples()` — verify cps_2023 examples run clean
- Run `devtools::check()` — 0 errors, 0 warnings, ≤2 notes
- `changelog/propensity/feature-ipw-replicate-ref.md` — create last, before
  opening PR; summarize the three parts (type widening, cps_2023 conversion,
  ACS removal)

---

### Acceptance Criteria

**Groundwork**
- [ ] `plans/error-messages.md` has `surveywts_error_svydesign_not_taylor`
  struck through with redirect to new class; `surveywts_error_reference_not_survey_design`
  added with correct trigger description and fired-by function

**Part B**
- [ ] `cps_2023@class` is `survey_replicate`
  (`S7::S7_inherits(cps_2023, surveycore::survey_replicate)` is TRUE)
- [ ] `cps_2023@variables$weights == "wtfinl"`
- [ ] `length(cps_2023@variables$repweights) == 160L`
- [ ] `cps_2023@data` has at least 9,000 rows (≈10,000 is the expected CPS sample)
- [ ] `R/data.R` cps_2023 `@format` uses `\describe{}` with slot-based `\item{}`
  entries; no individual repwtp column items (S7 objects exempt from codoc)
- [ ] cps_2023 `@examples` use `cps_2023` as a `survey_replicate` reference
  directly in `ipw()` — no `as_survey()` wrapper

**Part C**
- [ ] `data/acs_wy_2022.rda` and `data/acs_wy_2022_svy.rda` are absent from
  the repo (deleted)
- [ ] `R/data.R` has no `acs_wy_2022` or `acs_wy_2022_svy` documentation
- [ ] `ns_wave1` `@seealso` does not reference `[acs_wy_2022]`
- [ ] `trim_weights.R` `@examples` references `cps_2023`, not `acs_wy_2022_svy`
- [ ] `test-sample-calibration.R` line 3074 comment updated (no `acs_wy_2022_svy`)
- [ ] `test-datasets.R` ACS blocks (lines 18, 29, 244–324) removed; six
  `cps_2023` structural tests present and passing

**Part A — happy path**
- [ ] H-R1: `ipw()` with `survey_replicate` reference returns valid `survey_nonprob`;
  `test_invariants()` passes
- [ ] H-R2: all original NPS columns preserved; `"ipw_weight"` present; `nrow` unchanged
- [ ] H-R3: all IPW weights strictly positive
- [ ] H-R4: history entry `operation == "ipw"` and
  `S7::S7_inherits(entry$reference_design, surveycore::survey_replicate)` TRUE
- [ ] H-R5: `survey_replicate` and equivalent `survey_taylor` reference produce
  identical weights within `tolerance = 1e-10`
- [ ] H-T1: existing `survey_taylor` happy-path tests pass without modification

**Part A — error paths**
- [ ] E-1: `reference = data.frame(...)` → `surveywts_error_reference_not_survey_design`
  (class check + updated snapshot)
- [ ] E-2: `reference = survey_nonprob` → `surveywts_error_reference_not_survey_design`
  (class check + snapshot)
- [ ] E-3: `reference = NULL` → `surveywts_error_reference_not_survey_design`
  (class check + snapshot)
- [ ] E-4: `reference = list(...)` → `surveywts_error_reference_not_survey_design`
  (class check)
- [ ] E-5: `survey_replicate` reference with zero in main weight column →
  `surveywts_error_reference_weights_nonpositive`
- [ ] No test in `test-nonprob-ipw.R` references `surveywts_error_svydesign_not_taylor`
  after this PR

**Part A — edge cases**
- [ ] EC-1: `survey_replicate` with BRR zeros in replicate columns but positive
  main weight → accepted; weights computed normally
- [ ] EC-2: `wt_name` conflict → `surveywts_error_wt_name_conflict` (unchanged)
- [ ] EC-3: selection variable absent from `survey_replicate@data` →
  `surveywts_error_formula_variable_not_in_reference`
- [ ] EC-4: NPS factor level not in `survey_replicate@data` →
  `surveywts_error_propensity_level_not_in_reference`
- [ ] EC-5: `trim = TRUE` with `survey_replicate` reference → `test_invariants()` passes;
  `entry$trim == TRUE`

**CI gates**
- [ ] All new tests confirmed failing (red) before `R/ipw.R` was modified
- [ ] `devtools::document()` run; `NAMESPACE` and `man/` unchanged from pre-PR
  state (no new exports)
- [ ] `devtools::run_examples()` clean; no errors in cps_2023 or ipw() examples
- [ ] `devtools::check()` 0 errors, 0 warnings, ≤2 pre-approved notes
- [ ] `testthat::snapshot_review()` run; all snapshot diffs reviewed and approved
- [ ] `covr::package_coverage()` ≥ 95% (CI block; internal target 98%);
  Behavior Rule 2 branch for `survey_replicate` covered

---

### Notes

**data-raw script.** `data-raw/cps-2023.R` must be sourced interactively (not
run by `devtools::build()`). After editing the script, run it in a clean R
session to regenerate `data/cps_2023.rda`. Verify with
`S7::S7_inherits(cps_2023, surveycore::survey_replicate)` before proceeding to
test-datasets.R changes.

**S7 objects and codoc.** The `cps_2023` `@format` uses slot-based `\item{}`
entries (`\item{@@data}`, `\item{@@variables$weights}`, etc.). Because
`cps_2023` is an S7 object, R CMD check's codoc tool does not apply the column
coverage requirement. The 160 `repwtp*` columns are described as a group inside
the `@@data` item — no individual `\item{repwtp1}`, etc. required.

**Snapshot regeneration.** The existing E-1 snapshot
(`"ipw() errors when reference is a data.frame"`) will no longer match after
the error class rename. Do NOT run `testthat::snapshot_accept()` blindly —
review each diff individually via `testthat::snapshot_review()`.

**`survey_replicate` fixture.** The H-R1 through H-R5 and EC-1 tests all need
an inline `survey_replicate` fixture. `make_nps_reference()@data` has columns
`age_group`, `sex`, `education`, `region`, `base_weight` — no replicate columns.
Add synthetic replicate weight columns before calling `as_survey_replicate()`:

```r
ref_df <- make_nps_reference(n = 1000L, seed = 99L)@data
set.seed(42L)
n_rows  <- nrow(ref_df)
n_reps  <- 10L
repmat  <- matrix(
  sample(c(0, 2), n_rows * n_reps, replace = TRUE) * ref_df$base_weight,
  nrow = n_rows, ncol = n_reps
)
colnames(repmat) <- paste0("repwt", seq_len(n_reps))
ref_data_reps <- cbind(ref_df, repmat)

ref_replicate <- surveycore::as_survey_replicate(
  data       = ref_data_reps,
  weights    = "base_weight",
  repweights = paste0("repwt", seq_len(n_reps)),
  type       = "bootstrap",
  scale      = 1 / n_reps,
  rscales    = rep(1, n_reps)
)
# oracle fixture for H-R5 — same data, same main weight, Taylor design
ref_taylor <- surveycore::survey_taylor(
  data      = ref_df,
  variables = list(weights = "base_weight")
)
```

For EC-1, zero out some replicate cells before constructing:
```r
repmat[seq_len(100L), c(1L, 3L, 5L)] <- 0  # BRR-style zeros; main weights positive
```

**BRR zeros (EC-1).** See the fixture recipe above — zero out some cells in
`repmat` before calling `as_survey_replicate()`. All `base_weight` values
remain positive. The test asserts `ipw()` does not error and computes positive
weights — it does not assert any specific numeric value.

**E-2 fixture.** For the E-2 error path (reference is a `survey_nonprob`), use
`make_nonprob_no_repweights()` from `tests/testthat/helper-test-data.R`. This
returns a `survey_nonprob` from `ipw()` only — no replicate weights — which is
the simplest `survey_nonprob` to pass as `reference`. Do not use
`make_nonprob_replicate_design()` (that has repweights and is more complex to
construct unnecessarily).

**ACS raw script.** `data-raw/acs-wy-2022.R` is NOT deleted per spec §Out.
Only the built `.rda` files are removed. Do not touch the raw script.

**`trim_weights.R` example.** The example `trim_weights(cps_2023)` uses the
package dataset directly; `cps_2023` is a `survey_replicate` which is a
supported input class for `trim_weights()`. Confirm this is true before writing
the example (check `trim_weights()` dispatch).
