# Implementation Plan — dataset-revamp

**Status:** DRAFT
**Spec:** `plans/spec-dataset-revamp.md`
**Test-spec:** `plans/test-spec-dataset-revamp.md`
**Spec-review:** `plans/spec-review-dataset-revamp.md` — all 6 REQUIRED issues resolved; no BLOCKING issues.

---

## Overview

This plan delivers all 7 tibble + survey-design companion pairs described in
`spec-dataset-revamp.md`, retires the 5 old `*_ref`/`*_ipw` objects, rewrites
all documentation, and updates `ipw.R` examples, `_pkgdown.yml`, and README.

The spec mandates a **single PR** (§X): data, data-raw scripts, documentation,
and example updates are tightly coupled — splitting would leave the package in
a broken state mid-PR.

---

## PR Map

- [x] PR 1: `feature/dataset-revamp` — produce 7 tibble+svy pairs, retire 5
  old objects, rewrite docs, update examples and pkgdown

---

### PR 1: Dataset Revamp

**Branch:** `feature/dataset-revamp`
**Depends on:** none
**Base:** `develop`

**Files (in TDD order — tests first):**

1. `tests/testthat/test-datasets.R` — write all structural tests from
   test-spec; tests fail immediately (new objects not yet in `data/`)
2. `data-raw/ns-gss-ipw.R` — rewrite to produce `gss_2024`, `gss_2024_svy`,
   `ns_wave1`, `ns_wave1_svy`; remove `ns_wave1_ipw` and `gss_ipw_ref` logic
3. `data-raw/npors-acs-ipw.R` — rewrite to produce `npors_2025`,
   `npors_2025_svy`, `npors_2025_clean`, `npors_2025_clean_svy`,
   `acs_wy_2022`, `acs_wy_2022_svy`
4. `data-raw/pew-2016.R` — add section 6 to produce `pew_2016_optin_svy` and
   `pew_2016_synth_pop_svy`; keep existing tibble logic unchanged
5. *(run scripts)* — source all three data-raw scripts to write 12 new `.rda`
   files to `data/`; verify each file is present before proceeding
6. `data/` — delete 5 retired `.rda` files: `acs_ipw_ref.rda`,
   `gss_ipw_ref.rda`, `npors_2025_clean_ref.rda`, `npors_2025_ref.rda`,
   `ns_wave1_ipw.rda`
7. `R/data.R` — rewrite from scratch: 7 paired `@rdname` man pages; one
   `\describe{}` block per tibble covering ALL columns; 80 individual
   `\item{pwgtp1}` through `\item{pwgtp80}` entries for `acs_wy_2022`
8. *(run)* — `devtools::document()`. Verify `man/data.Rd` (and related man
   pages) are updated and commit them; no new errors in roxygen2 markup
9. `R/ipw.R` — update `@examples` per spec §VII: replace all old dataset
   names; add inline `as_survey(acs_wy_2022, weights = pwgtp)` construction
10. `_pkgdown.yml` — replace old "Example Datasets — IPW" / "Calibration"
    sections with new single subtitled section per spec §VI
11. `README.Rmd` — update dataset name references per spec §VIII
12. *(run)* — `devtools::build_readme()` to regenerate `README.md`; verify
    the updated `README.md` is staged for the PR commit
13. `NEWS.md` — add entry under current dev version noting dataset revamp

**Acceptance criteria:**
- [ ] All new tests confirmed failing (red) before any data-raw scripts are run
- [ ] `usethis::use_data(...)` completes without error for all 12 new `.rda`
  files; each file present in `data/` before retiring old files
- [ ] 5 old `.rda` files deleted from `data/`; `data("gss_ipw_ref", package =
  "surveywts")` throws an error (and likewise for each retired object)
- [ ] All 14 dataset objects loadable via `data()` — 12 new + 2 existing pew
  tibbles: no `object not found` errors (covers test-spec §Presence / absence)
- [ ] `gss_2024` structural checks pass: `ncol == 30`, factor levels correct,
  `wt_pop` numeric and positive where `wtssps` is non-NA (test-spec §gss_2024)
- [ ] `gss_2024_svy` is `survey_taylor`, uses `wtssps`, same row count as
  `gss_2024` (test-spec §gss_2024_svy)
- [ ] `npors_2025_svy` is `survey_taylor`, 5022 rows, weight column is `weight`
  (test-spec §npors_2025_svy)
- [ ] `npors_2025_clean_svy` is `survey_taylor`, row count equals
  `nrow(npors_2025_clean)` (test-spec §npors_2025_clean_svy)
- [ ] `npors_2025` structural checks: `nrow == 5022`, `ncol == 69`, all 5
  derived columns present, NA rate < 1% per derived col (test-spec §npors_2025)
- [ ] `npors_2025_clean` has zero NAs in all 4 derived cols; `nrow > 4700`
  (test-spec §npors_2025_clean)
- [ ] `acs_wy_2022` structural checks: `nrow == 4736`, all adults, `pwgtp` and
  `pwgtp1`–`pwgtp80` present, 4 derived cols factored with zero NAs
  (test-spec §acs_wy_2022)
- [ ] `acs_wy_2022_svy` is `survey_replicate`, 4736 rows, weight column is
  `pwgtp`, 80 replicate weight columns (`pwgtp1`–`pwgtp80`) present
  (test-spec §acs_wy_2022_svy)
- [ ] `pew_2016_optin_svy` is `survey_nonprob`, 31863 rows, weights all == 1L;
  `"equal_wt" %in% names(pew_2016_optin)` is `FALSE` (test-spec
  §pew_2016_optin_svy)
- [ ] `pew_2016_synth_pop_svy` is `survey_taylor`, 20000 rows, weights all == 1L
  (test-spec §pew_2016_synth_pop_svy)
- [ ] `ns_wave1` structural checks: `nrow == 6422`, `ncol == 174` (171 + 3 new;
  `gender` overwritten in-place), `gender` is factor, ~419 NAs in `race_ethn`
  (test-spec §ns_wave1)
- [ ] `ns_wave1_svy` is `survey_nonprob`, 6422 rows, `weight` col used
  (test-spec §ns_wave1_svy)
- [ ] `devtools::document()` — NAMESPACE and man/ unchanged after run (no drift)
- [ ] `devtools::check()` — 0 errors, 0 warnings, ≤2 pre-approved notes;
  `codoc` warning is a BLOCK — all 7 tibble man pages must pass
- [ ] `devtools::run_examples()` — all `@examples` in `ipw.Rd` run clean;
  ACS inline construction example runs without error (test-spec §Example tests)
- [ ] `ipw(ns_wave1, acs_wy_2022_svy, ...)` throws
  `surveywts_error_svydesign_not_taylor` (test-spec §acs_wy_2022_svy
  incompatibility)
- [ ] Integration: `ipw(ns_wave1, gss_ref, selection = ~gender + age_group)`
  and `ipw(ns_wave1, npors_ref, ...)` complete without error and return
  `survey_nonprob` with `ipw_weight` column (test-spec §Integration)
- [ ] Test coverage ≥ 98% overall (verify with `covr::package_coverage()`)

**Notes:**

- **ns_wave1 ncol is 174, not 175.** `gender` is overwritten in-place
  (integer → factor); three NEW columns added (`age_group`, `race_ethn`,
  `educ`). The spec-review resolved this ambiguity: spec §III.7 and test-spec
  both now say `== 174`.

- **acs_wy_2022 repweights selector.** Use
  `grep("^pwgtp[0-9]", names(acs_wy_2022), value = TRUE)` (not
  `starts_with("pwgtp")`), which would incorrectly include the main `pwgtp`
  column. Assign to `rep_cols` first, then pass as
  `repweights = dplyr::all_of(rep_cols)`.

- **acs_wy_2022 codoc compliance.** `R/data.R` must contain 80 individual
  `\item{pwgtp1}{...}` through `\item{pwgtp80}{...}` entries. Generate these
  with a shell loop or text substitution rather than typing manually. A grouped
  `\item{pwgtp1, pwgtp2, ...}` entry will NOT satisfy `codoc` and will produce
  a CI-blocking warning.

- **pew_2016_optin_svy construction.** Build from a copy to avoid adding
  `equal_wt` to the tibble's `.rda`. Pattern from spec §III.5:
  ```r
  optin_for_svy <- pew_2016_optin
  optin_for_svy$equal_wt <- 1L
  pew_2016_optin_svy <- surveycore::as_survey_nonprob(
    optin_for_svy, weights = equal_wt
  )
  ```
  Confirm `"equal_wt" %in% names(pew_2016_optin)` is `FALSE` after the save
  call (the tibble's `.rda` is saved in a prior call and not modified here).

- **Script run order.** Source `pew-2016.R` AFTER the tibbles `pew_2016_optin`
  and `pew_2016_synth_pop` are available (they are loaded from `data/` by the
  script, so the pre-existing `.rda` files are fine). `ns-gss-ipw.R` and
  `npors-acs-ipw.R` can be sourced in either order.

- **wt_pop for gss and npors svy objects.** The `_svy` companions use the
  normalized weight (`wtssps` / `weight`). The `wt_pop` column lives in the
  tibble for users who construct their own IPW reference design. This is the
  resolved behavior per spec §III.1 and §III.2 — no Option A/B ambiguity
  remains.

- **ns_wave1 in data-raw.** The current `ns-gss-ipw.R` references
  `ns_wave1` from `surveycore`. In the new script, use `surveycore::ns_wave1`
  explicitly (do not rely on an attached-package namespace lookup), consistent
  with the `library(surveycore)` at the top of the script.

- **ipw.R examples must load packages explicitly.** Per CLAUDE.md: examples
  run in a fresh session with only `library(surveywts)` loaded. The examples
  call `surveycore::as_survey(...)` — ensure the `surveycore::` prefix is
  present on every external call.

- **README.md is generated.** Do not manually edit `README.md`. Run
  `devtools::build_readme()` after updating `README.Rmd`. If the Rmd has live
  code chunks that reference old datasets, update those chunks first.

- **Single PR rationale.** The spec §X explicitly mandates a single PR
  because data, docs, and examples are tightly coupled: docs referencing new
  objects that don't exist yet, or examples referencing retired objects, both
  produce `R CMD check` errors.
