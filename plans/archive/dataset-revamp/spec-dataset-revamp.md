# Spec — dataset-revamp

**Status**: DRAFT
**Target version**: 0.5.0.9000
**PR range**: PR 1 (single PR)

---

## Document Purpose

This spec is the behavioral contract for revising all bundled example datasets
in surveywts. It defines the exact objects to produce, how to construct them,
the documentation structure for each pair, and all file changes required. The
builder implements from this document only. No test scenarios are included here
(see `test-spec-dataset-revamp.md`).

---

## I. Scope

### In

| Deliverable | Description |
|---|---|
| 7 new tibble objects | Full source data + harmonized demographic columns |
| 7 new `*_svy` companions | Survey design objects wrapping each tibble |
| 5 retired objects removed | Old `*_ref`/`*_ipw` objects gone from `data/` and docs |
| `data-raw/*.R` updated | Produce new objects only |
| `R/data.R` rewritten | Paired man pages for each tibble+svy pair |
| `R/ipw.R` examples updated | Reference new dataset names |
| `README.Rmd` / `README.md` updated | Reference new dataset names |
| `_pkgdown.yml` updated | Restructured "Example Datasets" section |

### Out

- No changes to any exported function behavior
- No new exported functions
- No changes to `DESCRIPTION` Imports or Suggests
- No changes to `data-raw/pew_2016/` source files (raw SAV files not touched)

### Object map

| New tibble | New survey object | Class | Replaces |
|---|---|---|---|
| `gss_2024` | `gss_2024_svy` | `survey_taylor` | `gss_ipw_ref` |
| `npors_2025` | `npors_2025_svy` | `survey_taylor` | `npors_2025_ref` |
| `npors_2025_clean` | `npors_2025_clean_svy` | `survey_taylor` | `npors_2025_clean_ref` |
| `acs_wy_2022` | `acs_wy_2022_svy` | `survey_replicate` | `acs_ipw_ref` |
| `pew_2016_optin` | `pew_2016_optin_svy` | `survey_nonprob` | (tibble unchanged; svy is new) |
| `pew_2016_synth_pop` | `pew_2016_synth_pop_svy` | `survey_taylor` | (tibble unchanged; svy is new) |
| `ns_wave1` | `ns_wave1_svy` | `survey_nonprob` | `ns_wave1_ipw` |

---

## II. Architecture

### Files touched

```
data-raw/
  ns-gss-ipw.R          REWRITE — produce gss_2024, gss_2024_svy, ns_wave1, ns_wave1_svy
  npors-acs-ipw.R       REWRITE — produce npors_2025, npors_2025_svy,
                                   npors_2025_clean, npors_2025_clean_svy,
                                   acs_wy_2022, acs_wy_2022_svy
  pew-2016.R            MODIFY — add pew_2016_optin_svy, pew_2016_synth_pop_svy
                                  (keep existing tibble logic unchanged)

data/
  REMOVE: acs_ipw_ref.rda, gss_ipw_ref.rda, npors_2025_clean_ref.rda,
          npors_2025_ref.rda, ns_wave1_ipw.rda
  ADD:    gss_2024.rda, gss_2024_svy.rda, npors_2025.rda, npors_2025_svy.rda,
          npors_2025_clean.rda, npors_2025_clean_svy.rda,
          acs_wy_2022.rda, acs_wy_2022_svy.rda,
          pew_2016_optin_svy.rda, pew_2016_synth_pop_svy.rda,
          ns_wave1.rda, ns_wave1_svy.rda
  KEEP:   pew_2016_optin.rda, pew_2016_synth_pop.rda

R/
  data.R                REWRITE — paired man pages (one page per tibble+svy pair)
  ipw.R                 MODIFY — update @examples to use new dataset names

README.Rmd              MODIFY — update dataset name references
README.md               MODIFY — update rendered dataset name references

_pkgdown.yml            MODIFY — restructure Example Datasets section
```

### usethis::use_data() call pattern

Each data-raw script calls `usethis::use_data(tibble, svy, overwrite = TRUE)`
for each pair. The separate-pairs approach (one use_data call per pair)
is preferred over one large call at the end, so each pair can be re-generated
independently.

---

## III. Dataset Contracts

Each section below specifies: source, row selection, columns, derived columns,
and survey object construction.

### III.1 — `gss_2024` and `gss_2024_svy`

**Source**: `surveycore::gss_2024` (27 original columns)

**Row selection**: All rows (no filtering). `gss_2024` retains all respondents
including those with `NA` in `sex` or `age`. The `_svy` companion similarly
uses all rows.

**`gss_2024` tibble columns**:
- All 27 original columns from `surveycore::gss_2024`, unchanged
- Plus 3 derived columns:
  - `gender`: factor, derived from `sex`; levels `c("Male", "Female")`;
    `sex == 1L → "Male"`, `sex == 2L → "Female"`, any other value → `NA`
  - `age_group`: factor, derived from `age`;
    `cut(age, breaks = c(18, 35, 55, Inf), labels = c("18-34", "35-54", "55+"), right = FALSE)`;
    `age < 18` or `age` is `NA` → `NA`
  - `wt_pop`: numeric; `wtssps * (260000000L / nrow(gss_2024))`;
    population-scaled weight for IPW use (sums to ~260M). IPW users construct a
    reference design using `wt_pop`; the `gss_2024_svy` companion uses `wtssps`.

Total columns: 27 + 3 = **30**.

**`gss_2024_svy` construction**:
```r
gss_2024_svy <- surveycore::as_survey(
  gss_2024,
  weights = wtssps,
  strata  = vstrat,
  ids     = vpsu,
  nest    = TRUE
)
```

`gss_2024_svy` uses `wtssps` (the natural GSS normalized weight) — correct for
standard survey estimation. For IPW, users construct a reference design from
`gss_2024` using the `wt_pop` column:
```r
data(gss_2024)
ref <- surveycore::as_survey(
  gss_2024,
  weights = wt_pop, strata = vstrat, ids = vpsu, nest = TRUE
)
ipw(ns_wave1, ref, selection = ~gender + age_group)
```

---

### III.2 — `npors_2025` and `npors_2025_svy`

**Source**: `surveycore::pew_npors_2025` (64 original columns)

**Row selection**: All 5,022 rows retained.

**`npors_2025` tibble columns**:
- All 64 original columns from `surveycore::pew_npors_2025`, unchanged
- Plus 4 derived columns (same harmonization as old `npors-acs-ipw.R`):
  - `gender`: factor, levels `c("Male", "Female")`;
    `gender == 1L → "Male"`, `gender == 2L → "Female"`,
    `gender %in% c(3L, 99L) → NA`
  - `age_group`: factor, levels `c("18-34", "35-54", "55+")`;
    derived from `agegrp`: `1L:3L → "18-34"`, `4L:7L → "35-54"`,
    `8L:13L → "55+"`, `99L → NA`
  - `race_ethn`: factor, levels `c("White", "Black", "Hispanic", "Asian", "Other")`;
    derived from `racethn`: `1L → "White"`, `2L → "Black"`, `3L → "Hispanic"`,
    `5L → "Asian"`, `4L → "Other"`, `99L → NA`
  - `educ`: factor, levels `c("Less than HS", "HS/Some college", "College+")`;
    derived from `educcat`: `3L → "Less than HS"`, `2L → "HS/Some college"`,
    `1L → "College+"`, `99L → NA`

Note: ~0.5% of rows will have `NA` in each derived column (from `99` codes).

**`npors_2025` derived columns (5 total)**:
- `gender`, `age_group`, `race_ethn`, `educ`: as defined above
- `wt_pop`: numeric; `weight * (260000000L / nrow(npors_2025))`;
  population-scaled weight for IPW use. `npors_2025_svy` uses `weight`.

Total columns: 64 + 5 = **69**.

**`npors_2025_svy` construction**:
```r
npors_2025_svy <- surveycore::as_survey(npors_2025, weights = weight)
```

Uses `weight` (natural NPORS normalized weight). For IPW use:
```r
data(npors_2025)
ref <- surveycore::as_survey(npors_2025, weights = wt_pop)
ipw(ns_wave1, ref, selection = ~gender + age_group + race_ethn + educ)
```

---

### III.3 — `npors_2025_clean` and `npors_2025_clean_svy`

**Source**: `npors_2025` (the object built in III.2), filtered to complete cases.

**Row selection**: Rows where `gender`, `age_group`, `race_ethn`, and `educ`
are all non-`NA`. Approximately 4,814 rows retained (5,022 minus ~208 rows
with at least one `NA` in the 4 derived columns).

**`npors_2025_clean` tibble columns**: Same as `npors_2025` (same column
structure), restricted to complete-case rows. No re-scaling of `weight` or
`wt_pop` after row removal (weights are not renormalized — same behavior
as old `npors_2025_clean_ref`).

**`npors_2025_clean_svy` construction**: Same call as `npors_2025_svy` but
applied to the filtered tibble.

---

### III.4 — `acs_wy_2022` and `acs_wy_2022_svy`

**Source**: `surveycore::acs_pums_wy`, restricted to adults (`agep >= 18`).
Result: 4,736 rows.

**`acs_wy_2022` tibble columns**:
- All columns from `surveycore::acs_pums_wy` for adult rows (includes `pwgtp`,
  `pwgtp1`–`pwgtp80`, and all other original ACS PUMS variables)
- Plus 4 derived columns (same harmonization as old `npors-acs-ipw.R`):
  - `gender`: factor, levels `c("Male", "Female")`;
    `sex == 1L → "Male"`, `sex == 2L → "Female"`; no NAs expected for adults
  - `age_group`: factor, levels `c("18-34", "35-54", "55+")`;
    `cut(agep, breaks = c(18, 35, 55, Inf), labels = c("18-34", "35-54", "55+"), right = FALSE)`
  - `race_ethn`: factor, levels `c("White", "Black", "Hispanic", "Asian", "Other")`;
    `hisp > 1L → "Hispanic"`, `rac1p == 1L → "White"`, `rac1p == 2L → "Black"`,
    `rac1p %in% 4:6 → "Asian"`, else `"Other"`; no NAs for adults
  - `educ`: factor, levels `c("Less than HS", "HS/Some college", "College+")`;
    `schl %in% 1:11 → "Less than HS"`, `schl %in% 12:15 → "HS/Some college"`,
    `schl %in% 16:24 → "College+"`; no NAs for adults (verified: `schl` has
    no NAs for `agep >= 18`)

Note: `pwgtp` is the ACS person weight. It sums to the Wyoming adult
population (not the US). This weight IS appropriate for `ipw()` directly
(ACS PUMS weights are population-scaled by design). No `wt_pop` derived
column needed.

**`acs_wy_2022_svy` construction**:
```r
rep_cols <- grep("^pwgtp[0-9]", names(acs_wy_2022), value = TRUE)  # pwgtp1:pwgtp80
acs_wy_2022_svy <- surveycore::as_survey_replicate(
  acs_wy_2022,
  weights    = pwgtp,
  repweights = dplyr::all_of(rep_cols),
  type       = "successive-difference",
  mse        = TRUE
)
```

`grep("^pwgtp[0-9]", ...)` matches `pwgtp1`–`pwgtp80` and excludes the main
`pwgtp` column (which doesn't end in a digit immediately). This is the required
approach — do NOT use `starts_with("pwgtp")` which would include the main
weight column.

**Design note**: `acs_wy_2022_svy` is a `survey_replicate` object. It cannot
be passed directly to `ipw()` (which requires `survey_taylor`). For IPW
workflows using ACS as the reference, users construct a simple design from
the `acs_wy_2022` tibble:
```r
ref <- surveycore::as_survey(acs_wy_2022, weights = pwgtp)
result <- ipw(ns_wave1, ref, selection = ~gender + age_group + race_ethn + educ)
```
Document this pattern in the man page.

---

### III.5 — `pew_2016_optin` and `pew_2016_optin_svy`

**Source**: existing `pew_2016_optin` tibble (no changes to the tibble).

**`pew_2016_optin` tibble**: unchanged (31,863 rows × 99 columns). No
modifications to `pew-2016.R` tibble-building logic.

**`pew_2016_optin_svy` construction**: No weight column exists in the raw
opt-in data. Use equal weights (1L per row). This represents the raw panel
before any weighting; users apply `ipw()` or `calibrate()` to add real weights.
```r
pew_2016_optin$equal_wt <- 1L
pew_2016_optin_svy <- surveycore::as_survey_nonprob(
  pew_2016_optin,
  weights = equal_wt
)
pew_2016_optin$equal_wt <- NULL  # remove helper column from tibble after svy construction
```

Wait — this construction requires temporarily adding a column to the tibble
object (not the `.rda`). The correct approach: build the svy companion from a
copy so the tibble `.rda` does not include `equal_wt`:
```r
optin_for_svy <- pew_2016_optin
optin_for_svy$equal_wt <- 1L
pew_2016_optin_svy <- surveycore::as_survey_nonprob(
  optin_for_svy,
  weights = equal_wt
)
```

**Note on `as_survey_nonprob` API**: check whether `surveycore::as_survey_nonprob`
accepts `data.frame` directly or requires a `data.frame` with a weight column
already present. Based on the existing `ipw.R` code:
`surveycore::as_survey_nonprob(data = out_df, weights = !!rlang::sym(wt_name), ...)` — it accepts a
data.frame with weight column. Use the copy approach above.

---

### III.6 — `pew_2016_synth_pop` and `pew_2016_synth_pop_svy`

**Source**: existing `pew_2016_synth_pop` tibble (no changes to the tibble).

**`pew_2016_synth_pop` tibble**: unchanged (20,000 rows × 38 columns).

**`pew_2016_synth_pop_svy` construction**: Synthetic population, no complex
design. Simple SRS `survey_taylor` with equal weights:
```r
synth_for_svy <- pew_2016_synth_pop
synth_for_svy$equal_wt <- 1L
pew_2016_synth_pop_svy <- surveycore::as_survey(
  synth_for_svy,
  weights = equal_wt
)
```

---

### III.7 — `ns_wave1` and `ns_wave1_svy`

**Source**: `surveycore::ns_wave1` (171 original columns, 6,422 rows).

**`ns_wave1` tibble columns**:
- All 171 original columns from `surveycore::ns_wave1`, unchanged
- Plus 4 derived columns (same harmonization as old `ns-gss-ipw.R`):
  - `gender`: factor, overwritten in-place. The original `ns_wave1$gender`
    column is an integer coded `1L = Male`, `2L = Female`. Convert to factor
    in-place: `factor(ns_wave1$gender, levels = c(1L, 2L), labels = c("Male", "Female"))`.
    Any value outside {1, 2} → `NA`. This REPLACES the integer column; no new
    column is added. The original integer values are no longer stored directly
    (they are implicit in the factor levels).

  - `age_group`: NEW column added. Factor, levels `c("18-34", "35-54", "55+")`;
    `cut(age, breaks = c(18, 35, 55, Inf), labels = ..., right = FALSE)`.
    The original `age` column is KEPT unchanged.

  - `race_ethn`: NEW column added. Factor, levels `c("White", "Black", "Hispanic", "Asian", "Other")`;
    derived from `race_ethnicity` + `hispanic` columns (same logic as old script):
    Hispanic origin takes precedence; Asian = codes 4–10; Other = codes 3, 11–14;
    `race_ethnicity == 15` (some other race, non-Hispanic) → `NA`.
    The original `race_ethnicity` and `hispanic` columns are KEPT.

  - `educ`: NEW column added. Factor, levels `c("Less than HS", "HS/Some college", "College+")`;
    `education %in% 1:3 → "Less than HS"`, `education %in% 4:7 → "HS/Some college"`,
    `education %in% 8:11 → "College+"`. Original `education` column KEPT.

**`ns_wave1` column count**: `gender` is overwritten in-place (not added),
so total columns = 171 (original) + 3 (new: `age_group`, `race_ethn`, `educ`) = **174**.

**`ns_wave1_svy` construction**:
```r
ns_wave1_svy <- surveycore::as_survey_nonprob(
  ns_wave1,
  weights = weight
)
```

---

## IV. data-raw Script Contracts

### IV.1 — `data-raw/ns-gss-ipw.R` (REWRITE)

**Produces**: `gss_2024`, `gss_2024_svy`, `ns_wave1`, `ns_wave1_svy`

**Script structure**:
1. `library(surveycore)`
2. Define shared constants: `age_bins`, `age_labs`
3. Build `ns_wave1` (full `surveycore::ns_wave1` + derived cols; overwrite
   `gender` in-place with factor; add `age_group`, `race_ethn`, `educ`)
4. Build `ns_wave1_svy` from `ns_wave1`
5. `usethis::use_data(ns_wave1, ns_wave1_svy, overwrite = TRUE)`
6. Build `gss_2024` (full `surveycore::gss_2024` + derived `gender`, `age_group`;
   optionally add `wt_pop` per HOLD #1 resolution)
7. Build `gss_2024_svy` from `gss_2024`
8. `usethis::use_data(gss_2024, gss_2024_svy, overwrite = TRUE)`

**Remove**: all references to `ns_wave1_ipw`, `gss_ipw_ref`, `US_ADULT_POP`
(unless HOLD #1 → Option B requires it)

### IV.2 — `data-raw/npors-acs-ipw.R` (REWRITE)

**Produces**: `npors_2025`, `npors_2025_svy`, `npors_2025_clean`,
`npors_2025_clean_svy`, `acs_wy_2022`, `acs_wy_2022_svy`

**Script structure**:
1. `library(surveycore); library(dplyr)` (for `case_when`, `starts_with`)
2. Define shared constants: `age_bins`, `age_labs`, `race_ethn_levels`,
   `educ_levels`
3. Build `npors_2025` (full `pew_npors_2025` + 4 derived cols;
   optionally add `wt_pop` per HOLD #1)
4. Build `npors_2025_svy`
5. `usethis::use_data(npors_2025, npors_2025_svy, overwrite = TRUE)`
6. Build `npors_2025_clean` (filter `npors_2025` to complete cases on 4 derived cols)
7. Build `npors_2025_clean_svy`
8. `usethis::use_data(npors_2025_clean, npors_2025_clean_svy, overwrite = TRUE)`
9. Build `acs_wy_2022` (full `acs_pums_wy` adults + 4 derived cols)
10. Build `acs_wy_2022_svy` via `as_survey_replicate`
11. `usethis::use_data(acs_wy_2022, acs_wy_2022_svy, overwrite = TRUE)`

**Remove**: all references to `npors_2025_ref`, `npors_2025_clean_ref`,
`acs_ipw_ref`, `US_ADULT_POP` (unless HOLD #1 → Option B)

### IV.3 — `data-raw/pew-2016.R` (MODIFY — add svy companions only)

Add a new section at the end of the script (after the existing save call):

```r
## ---- 6. Build survey object companions ----

# pew_2016_optin_svy — survey_nonprob with equal weights (raw panel, no wt col)
optin_for_svy <- pew_2016_optin
optin_for_svy$equal_wt <- 1L
pew_2016_optin_svy <- surveycore::as_survey_nonprob(
  optin_for_svy,
  weights = equal_wt
)

# pew_2016_synth_pop_svy — SRS survey_taylor (synthetic population)
synth_for_svy <- pew_2016_synth_pop
synth_for_svy$equal_wt <- 1L
pew_2016_synth_pop_svy <- surveycore::as_survey(
  synth_for_svy,
  weights = equal_wt
)

usethis::use_data(pew_2016_optin_svy, pew_2016_synth_pop_svy, overwrite = TRUE)
```

The existing save call `usethis::use_data(pew_2016_optin, pew_2016_synth_pop, overwrite = TRUE)`
is kept as-is.

---

## V. Documentation Contracts (`R/data.R`)

`R/data.R` is rewritten from scratch. One roxygen2 block per tibble+svy pair.
Each block documents the tibble as the primary object and the `*_svy`
companion as a secondary `@rdname` entry.

### V.1 Documentation structure per pair

```r
#' {Pair title}
#'
#' @description
#' {1–2 sentence description of the tibble and what population it represents.}
#'
#' {1–2 sentences on the `*_svy` companion: what class it is, how it was
#' constructed (weight column, design variables, replicate method if applicable).}
#'
#' @format
#' ## `{tibble_name}`
#' A data frame with {N} rows and {P} columns. Columns inherited from
#' {source package}::{source_dataset} plus derived columns:
#' \describe{
#'   \item{{col1}}{{description}}
#'   ...all columns in exactly one \describe block...
#' }
#'
#' ## `{tibble_name}_svy`
#' A `{class}` object. {How constructed: design variables, weight column.}
#'
#' @source {Source reference}
#' @seealso [{companion}]
#' @keywords datasets
"{tibble_name}"

#' @rdname {tibble_name}
#' @keywords datasets
"{tibble_name}_svy"
```

### V.2 codoc rule compliance

Every `\item{}` in `\describe{}` must correspond to an actual column in the
tibble. The `\describe{}` block is a single block covering ALL columns (see
`r-package-conventions.md §2`). No split blocks.

For `gss_2024` (29+ cols): document ALL columns in one `\describe{}` block.
The original 27 GSS columns are labeled tersely (one line each); the 2 derived
columns (`gender`, `age_group`) get full descriptions.

For `npors_2025` (68 cols): same — one `\describe{}` block, all columns.
Original 64 NPORS columns labeled tersely; 4 derived columns with full descriptions.

For `acs_wy_2022` (original adult cols + 4 derived): document ALL columns.
The 80 replicate weight columns (`pwgtp1`–`pwgtp80`) MUST each have an
individual `\item{}` entry — `codoc` requires a one-to-one match between
data columns and `\item{}` names:

```
\item{pwgtp1}{ACS PUMS successive-difference replicate weight 1.}
\item{pwgtp2}{ACS PUMS successive-difference replicate weight 2.}
...
\item{pwgtp80}{ACS PUMS successive-difference replicate weight 80.}
```

Generate these 80 entries using text substitution (sed, R, or a shell loop)
rather than typing them manually. Do NOT use a grouped notation
(`\item{pwgtp1, pwgtp2, ...}`) — `codoc` reads item names literally and
will not match multi-name grouped items, causing a warning that blocks CI.

For `pew_2016_optin` and `pew_2016_synth_pop` tibbles: existing man pages
already pass `codoc`. Keep those `\describe{}` blocks intact; add the `## *_svy`
section describing the companion under the same `@rdname`.

For `ns_wave1` (174 cols = 171 original + 3 new; `gender` overwritten in-place):
same `codoc` compliance required. Terse entries for the 171 original cols; full
entries for the 3 new derived cols (`age_group`, `race_ethn`, `educ`).

---

## VI. `_pkgdown.yml` Contract

Replace the current two-section "Example Datasets" structure with:

```yaml
- title: Example Datasets
  desc: >
    Bundled datasets for IPW, calibration, and other survey methods examples.
    Each dataset has a tibble companion (raw data) and a survey object companion
    (`*_svy`, ready-to-use design).
  contents:
    - subtitle: Non-Probability Samples
    - ns_wave1
    - ns_wave1_svy
    - pew_2016_optin
    - pew_2016_optin_svy
    - subtitle: Probability Samples
    - gss_2024
    - gss_2024_svy
    - npors_2025
    - npors_2025_svy
    - npors_2025_clean
    - npors_2025_clean_svy
    - acs_wy_2022
    - acs_wy_2022_svy
    - pew_2016_synth_pop
    - pew_2016_synth_pop_svy
```

Remove the old "Example Datasets — IPW" and "Example Datasets — Calibration"
sections entirely.

---

## VII. `R/ipw.R` @examples Contract

Update the `@examples` block. Map old names → new names:

| Old name | New name |
|---|---|
| `ns_wave1_ipw` | `ns_wave1` |
| `gss_ipw_ref` | `gss_2024_svy` (or inline construction — per HOLD #1) |
| `npors_2025_ref` | `npors_2025_svy` (or inline) |
| `npors_2025_clean_ref` | `npors_2025_clean_svy` |
| `acs_ipw_ref` | `acs_wy_2022` tibble (construct Taylor design inline — see below) |

`acs_wy_2022_svy` is a `survey_replicate` and cannot be passed to `ipw()`
(which requires `survey_taylor`). The ACS IPW example must construct a
simple Taylor design inline:

```r
data(acs_wy_2022)
acs_ref <- surveycore::as_survey(acs_wy_2022, weights = pwgtp)
result_acs <- ipw(
  ns_wave1,
  acs_ref,
  selection = ~gender + age_group + race_ethn + educ,
  missing_method = "omit"
)
```

This pattern teaches users the correct workflow when using `acs_wy_2022`
with `ipw()`: the full-design `acs_wy_2022_svy` is for survey estimation;
the plain Taylor design wrapping `pwgtp` is for IPW propensity estimation.

The `*_svy` objects use normalized weights; for `ipw()` use the `wt_pop`
column from the tibble. The updated `@examples` use this pattern:

```r
data(ns_wave1)

# --- GSS 2024 as probability reference ---
data(gss_2024)
gss_ref <- surveycore::as_survey(
  gss_2024,
  weights = wt_pop, strata = vstrat, ids = vpsu, nest = TRUE
)

# Formula interface
result1 <- ipw(ns_wave1, gss_ref, selection = ~gender + age_group)

# Programmatic interface
result2 <- ipw(ns_wave1, gss_ref, predictors = c("gender", "age_group"))
```

And for NPORS:

```r
data(npors_2025_clean)
npors_ref <- surveycore::as_survey(npors_2025_clean, weights = wt_pop)

result_omit <- ipw(
  ns_wave1, npors_ref,
  selection = ~gender + age_group + race_ethn + educ,
  missing_method = "omit"
)
```

---

## VIII. README Contract

**`README.Rmd`** (lines ~112–166 per grep): Update all old dataset name
references to new names. The narrative description changes from
"`ns_wave1_ipw`... `gss_ipw_ref`" to "`ns_wave1`... `gss_2024_svy`" (or
however HOLD #1 resolves).

**`README.md`**: Re-render `README.Rmd` via `devtools::build_readme()` or
`knitr::knit("README.Rmd")` after updating `README.Rmd`. The builder does
not manually edit `README.md` — it is generated from `README.Rmd`.

> ⚠️ **GAP**: If `README.Rmd` contains runnable R code chunks that load the
> old datasets, those chunks must be updated and re-run. Verify by running
> `devtools::build_readme()` after the data-raw scripts are re-run.

---

## IX. Quality Gates

The following must all pass before the PR is opened:

- [ ] `usethis::use_data(...)` completes without error for all 12 new `.rda` files
- [ ] Old 5 `.rda` files are deleted from `data/`
- [ ] `devtools::document()` — NAMESPACE/man/ unchanged after run (no drift)
- [ ] All 14 new objects are accessible via `data()`: no `object not found` errors
- [ ] `R CMD check` (via `devtools::check()`): 0 errors, 0 warnings,
      ≤2 pre-approved notes. In particular, `codoc` check must pass
      (no "code/documentation mismatches" warning) for ALL 7 tibble pairs.
- [ ] `devtools::run_examples()`: all `@examples` in `ipw.R` run clean
- [ ] `pkgdown::build_reference()` (optional): reference index renders correctly

---

## X. Pipeline split

**Single PR**: All changes land together. Data, data-raw, documentation, and
example updates are tightly coupled — splitting would leave the package in a
broken state mid-PR (e.g., docs referencing objects that don't exist yet).
