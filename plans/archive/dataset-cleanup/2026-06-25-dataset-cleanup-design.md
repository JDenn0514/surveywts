# Dataset Cleanup & `rescale_weights()` Rename — Design Spec

**Date:** 2026-06-25
**Status:** Approved
**Branch strategy:** Two PRs (PR 1: dataset layer; PR 2: function surface)

---

## Background

surveywts bundles 15 dataset objects: 8 plain tibbles/data frames and 7
paired `_svy` survey objects (`survey_taylor`, `survey_nonprob`, or
`survey_replicate`). The survey objects add package size, complicate
examples, and force users to understand S7 survey classes before they can
run any example. This spec removes the `_svy` objects, upgrades the plain
datasets to proper tibbles with rich metadata, and folds in a long-overdue
rename of `stabilize_weights()` to `rescale_weights()`.

---

## Scope

### PR 1 — Dataset layer

1. Delete 7 `_svy` `.rda` files
2. Update `data-raw/` scripts to stop producing `_svy` objects
3. Convert all 8 datasets to tibbles (`tibble::as_tibble()`)
4. Add `attr(col, "label")` to every column
5. Add `attr(col, "labels")` (haven-style named numeric vector) to numeric
   columns; skip for factor and character columns
6. Add `attr(col, "question_preface")` to battery/select-all columns where
   applicable
7. Promote calibrated weight columns into `pew_2016_optin` and `ns_wave1`
8. Rewrite `R/data.R`: remove `_svy` stubs, update `@format` sections, add
   `\item{}` entries for promoted weight columns
9. `devtools::document()` + `devtools::check()`

### PR 2 — Function surface

**Depends on PR 1 being merged first.** The test helpers and `calibrate_to_survey()` example reference the promoted `weight` and `repwt_*` columns that PR 1 adds to `ns_wave1` and `pew_2016_optin`. Branch PR 2 from `develop` after PR 1 squash-merges.

1. Update function examples to construct survey objects inline (see patterns
   below)
2. Add three test helpers to `tests/testthat/helper-test-data.R`
3. Update ~22 test references to use helpers or inline construction
4. Rename `stabilize_weights()` → `rescale_weights()`
5. `devtools::document()` + `devtools::check()`

---

## PR 1 Detail

### Datasets and `_svy` objects removed

| `.rda` deleted | Type |
|---|---|
| `data/gss_2024_svy.rda` | `survey_taylor` |
| `data/npors_2025_svy.rda` | `survey_taylor` |
| `data/npors_2025_clean_svy.rda` | `survey_taylor` |
| `data/acs_wy_2022_svy.rda` | `survey_replicate` |
| `data/pew_2016_optin_svy.rda` | `survey_nonprob` |
| `data/pew_2016_synth_pop_svy.rda` | `survey_taylor` |
| `data/ns_wave1_svy.rda` | `survey_nonprob` |

### `data-raw/` script changes

Each script loses its survey object construction block and its
`usethis::use_data(..._svy)` call. The tibble-producing code stays.
`cps-2023.R` is unchanged (never had a `_svy` object).

### Tibble conversion and metadata

**Step 1 — `tibble::as_tibble()`** applied as the final transformation
before `usethis::use_data()`.

**Step 2 — `"label"` attribute** added to every column. Source text comes
from the existing `\item{}` descriptions in `R/data.R`. For surveycore
datasets (`gss_2024`, `npors_2025`, `npors_2025_clean`, `acs_wy_2022`,
`ns_wave1`), surveycore already sets these attributes on source columns;
only derived columns (`sex`, `age_f3`, `race_f4`, `edu_f3`, `pid_f3`,
`wt_pop`, `ns_*`) need to be set manually. For `pew_2016_optin` and
`pew_2016_synth_pop`, haven already preserves `"label"` from the SPSS
source; gaps are filled manually. For `cps_2023`, IPUMS already sets
`"label"` via `ipumsr::read_ipums_micro()`; no `zap_labels()` is called.

**Step 3 — `"labels"` attribute** (haven-style named numeric vector) added
to numeric columns only. Factor and character columns are skipped. For
datasets where haven already set `"labels"`, the existing attributes are
preserved (no `zap_labels()`). Derived numeric columns that represent
population-scaled weights or step-counts get no `"labels"` (no discrete
value mapping exists).

**Step 4 — `"question_preface"` attribute** applied to battery and
select-all columns:

- **surveycore datasets** (`gss_2024`, `npors_2025`, `npors_2025_clean`,
  `acs_wy_2022`, `ns_wave1`): already set by surveycore on source columns;
  only derived columns need attention (and derived columns are standalone,
  so none need `question_preface`).
- **`pew_2016_optin`**: add a `BATTERIES_PEW2016` list to
  `data-raw/pew-2016-optin.R` following the same structure as
  `BATTERIES_PHASE1` in surveycore. Preface text sourced from the Pew 2016
  codebook. Batteries to cover: `news_sources_*`, `group_favorability_*`,
  `cand_favorability_*`, `race_acs_*` (select-all race items), and any
  other batteries identified in the codebook.
- **`pew_2016_synth_pop`**: standalone benchmark variables only; no
  `question_preface` needed.
- **`cps_2023`**: IPUMS variables are standalone survey items; no
  `question_preface` needed.

### Weight promotion

**`pew_2016_optin`:** After constructing the `survey_nonprob` object (which
holds the calibrated `weight` column and `repwt_1`–`repwt_200`), extract
those columns and bind them back into the tibble before saving. The tibble
gains 201 new columns. `R/data.R` gains corresponding `\item{}` entries for
`weight` and `repwt_1`–`repwt_200`.

**`ns_wave1`:** After running the raking procedure that produces the
`survey_nonprob`, extract the `weight` column and add it to the tibble
before saving. `R/data.R` gains a `\item{weight}` entry.

### `R/data.R` changes

- Remove all 7 `#' @rdname ...\n"..._svy"` stubs
- Remove all `@seealso` references to `_svy` objects
- Remove all `## \`..._svy\`` subsections from `@format` blocks
- Update `@description` text that explains `_svy` usage — rewrite to
  describe how to construct a survey object inline from the tibble
- For `npors_2025` and `npors_2025_clean`: update the inline
  `survey_taylor` construction example in `@description` to include
  `strata = stratum` (was missing previously); update the design
  description to note that NPORS is a national address-based sample with
  stratified random sampling and differential probabilities of selection
  across strata
- Add `\item{weight}` and `\item{repwt_1}`–`\item{repwt_200}` entries to
  `pew_2016_optin` format block
- Add `\item{weight}` entry to `ns_wave1` format block

---

## PR 2 Detail

### Function example patterns

**Pattern 1 — Fresh weights** (`calibrate_rake()`, `calibrate_linear()`,
`calibrate_logit()`, `calibrate()`, `poststratify()`, `ipw()`): examples
use package data with no pre-existing weight passed. The promoted `weight`
column in `ns_wave1` and `pew_2016_optin` is simply not passed as the
`weights` argument — the function creates new weights.

**Pattern 2 — Existing weights** (`effective_sample_size()`,
`weight_variability()`, `summarize_weights()`): pass `ns_wave1` with
`weights = weight`.

**Pattern 3 — Before/after** (`trim_weights()`, `rescale_weights()`): call
`summarize_weights()` before, then after each function call to show the
change. `trim_weights()` additionally uses `cps_2023` for the replicate
weights variant.

**Pattern 4 — Inline survey construction:**

| Function(s) | Inline construction |
|---|---|
| `create_jackknife_weights()`, `create_bootstrap_weights()`, `create_brr_weights()`, `create_sdr_weights()`, `create_gen_boot_weights()`, `create_gen_rep_weights()`, `create_replicate_weights()`, `as_taylor_design()` | `surveycore::as_survey(gss_2024, weights = wtssps, strata = vstrat, ids = vpsu, nest = TRUE)` |
| `calibrate_to_survey()` | `survey_nonprob` from `pew_2016_optin` promoted weights; `survey_taylor` from `npors_2025_clean` piped into `create_bootstrap_weights()` |
| `adjust_nonresponse()`, `redistribute_weights()`, `calibrate_to_estimate()` | Fine as-is — already construct inline |

### Test helpers

Three helpers added to `tests/testthat/helper-test-data.R`:

```r
make_gss_taylor <- function() {
  data(gss_2024, package = "surveywts", envir = environment())
  surveycore::as_survey(gss_2024, weights = wtssps, strata = vstrat, ids = vpsu, nest = TRUE)
}

make_ns_nonprob <- function() {
  data(ns_wave1, package = "surveywts", envir = environment())
  surveycore::survey_nonprob(ns_wave1, variables = list(weights = "weight"))
}

make_npors_taylor <- function() {
  data(npors_2025_clean, package = "surveywts", envir = environment())
  surveycore::as_survey(npors_2025_clean, weights = weight, strata = stratum)
}
```

### Test reference updates

| Current reference | Replacement | Files |
|---|---|---|
| `gss_2024_svy` (data load + use) | `make_gss_taylor()` | `test-replicate-weights.R` (13 refs), `test-datasets.R` (2 refs) |
| `ns_wave1_svy` (data load + use) | `make_ns_nonprob()` | `test-nps-jackknife.R` (6 refs), `test-nonprob-ipw.R` (1 ref), `test-datasets.R` (1 ref) |
| `npors_2025_clean_svy` | `make_npors_taylor()` | `test-sample-calibration.R` (1 ref) |
| `pew_2016_optin_svy` | inline construction | `test-datasets.R` (1 ref) |

`test-datasets.R`: the block testing that `_svy` objects load without error
is removed and replaced with tests that promoted weight columns exist in the
tibbles (e.g. `expect_true("weight" %in% names(ns_wave1))`).

### `rescale_weights()` rename

**No deprecation shim** — pre-CRAN, clean rename only.

| File | Change |
|---|---|
| `R/stabilize_weights.R` → `R/rescale_weights.R` | Rename file; update function name; update `operation = "stabilize_weights"` → `"rescale_weights"` in history entry |
| `tests/testthat/test-weight-utils.R` | Replace all `stabilize_weights(` with `rescale_weights(`; regenerate snapshots |
| `tests/testthat/_snaps/` | Delete stale snapshot files for `stabilize_weights`; regenerate |
| `.claude/rules/surveywts-conventions.md` | Update file mapping table and family table |
| `plans/roadmap.md` | Update any references to `stabilize_weights()` |
| `NAMESPACE` | Regenerated via `devtools::document()` |

---

## Out of Scope

- Adding new datasets
- Changing the column structure of any existing dataset
- Adding vignettes (Polish release)
- Any changes to the Diagnostics phase functions
