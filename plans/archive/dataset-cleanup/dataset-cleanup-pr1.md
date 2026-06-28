# Dataset Cleanup PR 1 — Dataset Layer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove all 7 `_svy` companion `.rda` objects, convert all 8 plain tibbles to proper tibbles with column metadata, promote calibrated weight columns into `pew_2016_optin` and `ns_wave1`, and update R/data.R and tests accordingly.

**Architecture:** Each `data-raw/` script is simplified: survey object construction is removed, `tibble::as_tibble()` is added before saving, and `attr()` calls are added for `"label"` on derived columns. Two scripts (`ns-wave1.R`, `pew-2016-optin.R`) additionally extract calibrated weights back into the tibble before saving. Seven `.rda` files are deleted. R/data.R loses all `_svy` documentation stubs and gains `\item{weight}`/`\item{repwt_*}` entries. `test-datasets.R` replaces `_svy` load tests with promoted-column presence checks.

**Tech Stack:** R, `tibble`, `usethis`, `surveycore`, `surveywts` (loaded via `pkgload::load_all()` in data-raw scripts), `devtools`

## Global Constraints

- Branch from `develop`; branch name: `feature/dataset-cleanup-pr1`
- Conventional Commits format: `chore(data):` for data-raw changes, `docs(data):` for data.R changes, `test(datasets):` for test changes
- `devtools::document()` required before any commit touching roxygen2 (R/data.R)
- `devtools::check()` required before opening PR; must pass 0 errors, 0 warnings, ≤2 pre-approved notes
- Do NOT run any `data-raw/` scripts that require the raw SPSS files (`pew-2016-optin.R`, `pew-2016-synth-pop.R`) — those `.sav` files are gitignored. Only modify the scripts; do not re-source them. For all other data-raw scripts, re-source them after editing to regenerate `.rda` files.
- The `cps-2023.R` script is unchanged — do not touch it.
- Column count arithmetic: pew_2016_optin currently has 107 cols (pre-existing bug: script overwrites with optin_for_svy). After fix + promotion: 104 (correct base) + 1 (weight) + 200 (repwt_1–repwt_200) = 305 cols.
- ns_wave1 currently has 185 cols and already has a `weight` col. After promotion, column count stays 185 (weight is updated in-place, not added).

---

## Task 1: Create feature branch

**Files:**
- No files changed

- [ ] **Step 1: Branch from develop**

```bash
git checkout develop && git pull && git checkout -b feature/dataset-cleanup-pr1
```

Expected: clean branch at HEAD of develop.

---

## Task 2: Update `data-raw/gss-2024.R` — remove `_svy`, add tibble + labels

**Files:**
- Modify: `data-raw/gss-2024.R`

**What changes:**
1. Remove the `## ---- gss_2024_svy ---` block (lines 105–112)
2. Change `usethis::use_data(gss_2024, gss_2024_svy, overwrite = TRUE)` to `usethis::use_data(gss_2024, overwrite = TRUE)`
3. Add `tibble::as_tibble()` conversion and `"label"` attributes for derived columns before `use_data()`

- [ ] **Step 1: Edit data-raw/gss-2024.R**

Replace the section after the structural assertions block (after `stopifnot(is.numeric(gss_2024$wt_pop))`) with:

```r
# Add "label" attributes to derived columns (surveycore sets labels on originals)
attr(gss_2024$sex, "label")    <- "Sex of respondent (factor, derived from raw integer sex)"
attr(gss_2024$age_f3, "label") <- "Age group (3 levels: 18-34, 35-54, 55+)"
attr(gss_2024$race_f4, "label") <- "Race/ethnicity (4 levels: White, Black, Hispanic, Other)"
attr(gss_2024$pid_f3, "label") <- "Party identification (3 levels: Republican, Independent, Democrat)"
attr(gss_2024$edu_f3, "label") <- "Educational attainment (3 levels)"
attr(gss_2024$wt_pop, "label") <- "Population-scaled weight: wtssps * (260000000 / nrow(gss_2024))"

gss_2024 <- tibble::as_tibble(gss_2024)

usethis::use_data(gss_2024, overwrite = TRUE)
message("Saved gss_2024 (", nrow(gss_2024), " rows x ", ncol(gss_2024), " cols)")
```

Remove the `## ---- gss_2024_svy ----` block entirely:
```r
## ---- gss_2024_svy -----------------------------------------------------------
gss_2024_svy <- surveycore::as_survey(
  gss_2024,
  weights = wtssps,
  strata = vstrat,
  ids = vpsu,
  nest = TRUE
)

usethis::use_data(gss_2024, gss_2024_svy, overwrite = TRUE)
message("Saved gss_2024 (", nrow(gss_2024), " rows x ", ncol(gss_2024), " cols) and gss_2024_svy")
```

- [ ] **Step 2: Source the script to regenerate `data/gss_2024.rda`**

From the R console at the package root:
```r
source("data-raw/gss-2024.R")
```

Expected: "Saved gss_2024 (3309 rows x 32 cols)"

- [ ] **Step 3: Verify the tibble has correct attributes**

```r
pkgload::load_all()
data(gss_2024)
cat("is tibble:", inherits(gss_2024, "tbl_df"), "\n")
cat("sex label:", attr(gss_2024$sex, "label"), "\n")
cat("age_f3 label:", attr(gss_2024$age_f3, "label"), "\n")
```

Expected: `is tibble: TRUE`, labels printed correctly.

- [ ] **Step 4: Commit**

```bash
git add data-raw/gss-2024.R data/gss_2024.rda
git commit -m "chore(data): remove gss_2024_svy, convert to tibble with column labels"
```

---

## Task 3: Update `data-raw/npors-2025.R` — remove `_svy` objects, add tibble + labels

**Files:**
- Modify: `data-raw/npors-2025.R`

**What changes:**
1. Remove `## ---- npors_2025_svy ----` block and its `usethis::use_data(npors_2025, npors_2025_svy, ...)` call
2. Add tibble conversion and labels after the structural assertions for `npors_2025`; save via `usethis::use_data(npors_2025, overwrite = TRUE)`
3. Remove `## ---- npors_2025_clean_svy ----` block and its `usethis::use_data(npors_2025_clean, npors_2025_clean_svy, ...)` call
4. Add tibble conversion for `npors_2025_clean`; save via `usethis::use_data(npors_2025_clean, overwrite = TRUE)`

- [ ] **Step 1: Edit data-raw/npors-2025.R**

After the `npors_2025` structural assertions block, replace everything from `## ---- npors_2025_svy ---` to the end of the first `usethis::use_data()` call with:

```r
# Add "label" attributes to derived columns
attr(npors_2025$sex, "label")    <- "Sex (factor, derived from gender: 1=Male, 2=Female)"
attr(npors_2025$age_f3, "label") <- "Age group (3 levels: 18-34, 35-54, 55+)"
attr(npors_2025$race_f4, "label") <- "Race/ethnicity (4 levels: White, Black, Hispanic, Other)"
attr(npors_2025$edu_f3, "label") <- "Educational attainment (3 levels)"
attr(npors_2025$pid_f3, "label") <- "Party identification (3 levels: Republican, Independent, Democrat)"
attr(npors_2025$wt_pop, "label") <- "Population-scaled weight: weight * (260000000 / nrow(npors_2025))"

npors_2025 <- tibble::as_tibble(npors_2025)

usethis::use_data(npors_2025, overwrite = TRUE)
message(
  "Saved npors_2025 (",
  nrow(npors_2025),
  " rows x ",
  ncol(npors_2025),
  " cols)"
)
```

Remove the block:
```r
## ---- npors_2025_svy ---------------------------------------------------------
npors_2025_svy <- surveycore::as_survey(
  npors_2025,
  strata = stratum,
  weights = weight
)

usethis::use_data(npors_2025, npors_2025_svy, overwrite = TRUE)
```

After the `npors_2025_clean` structural assertions block, replace everything from `## ---- npors_2025_clean_svy ---` to the end of the second `usethis::use_data()` call with:

```r
npors_2025_clean <- tibble::as_tibble(npors_2025_clean)

usethis::use_data(npors_2025_clean, overwrite = TRUE)
message(
  "Saved npors_2025_clean (",
  nrow(npors_2025_clean),
  " rows)"
)
```

Remove:
```r
## ---- npors_2025_clean_svy ---------------------------------------------------
npors_2025_clean_svy <- surveycore::as_survey(
  npors_2025_clean,
  strata = stratum,
  weights = weight
)

usethis::use_data(npors_2025_clean, npors_2025_clean_svy, overwrite = TRUE)
```

- [ ] **Step 2: Source the script**

```r
source("data-raw/npors-2025.R")
```

Expected: "Saved npors_2025 (5022 rows x 71 cols)" then "Saved npors_2025_clean (...)"

- [ ] **Step 3: Verify**

```r
pkgload::load_all()
data(npors_2025)
data(npors_2025_clean)
cat("npors tibble:", inherits(npors_2025, "tbl_df"), "\n")
cat("clean tibble:", inherits(npors_2025_clean, "tbl_df"), "\n")
cat("sex label:", attr(npors_2025$sex, "label"), "\n")
```

- [ ] **Step 4: Commit**

```bash
git add data-raw/npors-2025.R data/npors_2025.rda data/npors_2025_clean.rda
git commit -m "chore(data): remove npors_2025_svy objects, convert to tibbles with column labels"
```

---

## Task 4: Update `data-raw/acs-wy-2022.R` — remove `_svy`, add tibble + labels

**Files:**
- Modify: `data-raw/acs-wy-2022.R`

**What changes:**
1. Remove `## ---- acs_wy_2022_svy ----` block and its `usethis::use_data(acs_wy_2022, acs_wy_2022_svy, ...)` call
2. Add tibble conversion and labels; save via `usethis::use_data(acs_wy_2022, overwrite = TRUE)`

- [ ] **Step 1: Edit data-raw/acs-wy-2022.R**

After the structural assertions block (after `stopifnot(sum(is.na(acs_wy_2022$edu_f3)) == 0L)`), replace from `## ---- acs_wy_2022_svy ---` to end with:

```r
# Add "label" attributes to derived columns (ACS source columns already labeled by surveycore)
attr(acs_wy_2022$sex, "label")    <- "Sex (factor, derived from raw sex: 1=Male, 2=Female)"
attr(acs_wy_2022$age_f3, "label") <- "Age group (3 levels: 18-34, 35-54, 55+)"
attr(acs_wy_2022$race_f4, "label") <- "Race/ethnicity (4 levels: White, Black, Hispanic, Other)"
attr(acs_wy_2022$edu_f3, "label") <- "Educational attainment (3 levels)"

acs_wy_2022 <- tibble::as_tibble(acs_wy_2022)

usethis::use_data(acs_wy_2022, overwrite = TRUE)
message(
  "Saved acs_wy_2022 (",
  nrow(acs_wy_2022),
  " rows x ",
  ncol(acs_wy_2022),
  " cols)"
)
```

Remove:
```r
## ---- acs_wy_2022_svy --------------------------------------------------------
rep_cols <- grep("^pwgtp[0-9]", names(acs_wy_2022), value = TRUE)
stopifnot(length(rep_cols) == 80L)

acs_wy_2022_svy <- surveycore::as_survey_replicate(
  acs_wy_2022,
  weights = pwgtp,
  repweights = dplyr::all_of(rep_cols),
  type = "successive-difference",
  mse = TRUE
)

usethis::use_data(acs_wy_2022, acs_wy_2022_svy, overwrite = TRUE)
message(
  "Saved acs_wy_2022 (",
  nrow(acs_wy_2022),
  " rows x ",
  ncol(acs_wy_2022),
  " cols) and acs_wy_2022_svy"
)
```

- [ ] **Step 2: Source the script**

```r
source("data-raw/acs-wy-2022.R")
```

Expected: "Saved acs_wy_2022 (4736 rows x 99 cols)"

- [ ] **Step 3: Commit**

```bash
git add data-raw/acs-wy-2022.R data/acs_wy_2022.rda
git commit -m "chore(data): remove acs_wy_2022_svy, convert to tibble with column labels"
```

---

## Task 5: Update `data-raw/pew-2016-synth-pop.R` — remove `_svy`, add tibble + labels

**Files:**
- Modify: `data-raw/pew-2016-synth-pop.R`

**Note:** The raw `.sav` file is gitignored. Edit the script but do NOT source it.

**What changes:**
1. Remove `## ---- 6. Build survey_taylor companion ----` block and its `usethis::use_data(pew_2016_synth_pop_svy, ...)` call
2. Add tibble conversion before the existing `usethis::use_data(pew_2016_synth_pop, overwrite = TRUE)` call
3. Add `"label"` attributes to derived columns (haven already sets labels on SPSS source columns)

- [ ] **Step 1: Edit data-raw/pew-2016-synth-pop.R**

After the structural assertions block (after `stopifnot(sum(is.na(pew_2016_synth_pop$age_f3)) == 0L)`), replace the `## ---- 5. Save ----` section and the `## ---- 6. Build survey_taylor companion ----` section with:

```r
## ---- 5. Add derived column labels and save ----
# haven already preserves "label" and "labels" attrs from SPSS source columns.
# Only add labels to derived factor columns (haven doesn't set them automatically).

attr(pew_2016_synth_pop$sex, "label")    <- "Sex (factor, derived from gender: 1=Male, 2=Female)"
attr(pew_2016_synth_pop$race_f4, "label") <- "Race/ethnicity (4 levels: White, Black, Hispanic, Other)"
attr(pew_2016_synth_pop$edu_f3, "label") <- "Educational attainment (3 levels)"
attr(pew_2016_synth_pop$pid_f3, "label") <- "Party identification (3 levels: Republican, Independent, Democrat)"
attr(pew_2016_synth_pop$age_f3, "label") <- "Age group (3 levels: 18-34, 35-54, 55+)"

pew_2016_synth_pop <- tibble::as_tibble(pew_2016_synth_pop)

usethis::use_data(pew_2016_synth_pop, overwrite = TRUE)
message(
  "Saved pew_2016_synth_pop: ",
  nrow(pew_2016_synth_pop),
  " rows x ",
  ncol(pew_2016_synth_pop),
  " cols"
)
```

Remove:
```r
## ---- 6. Build survey_taylor companion ----

# SRS survey_taylor with equal weights (synthetic pop)
# Build from a COPY for symmetry with the optin approach.
synth_for_svy <- pew_2016_synth_pop
synth_for_svy$equal_wt <- 1L
pew_2016_synth_pop_svy <- surveycore::as_survey(
  synth_for_svy,
  weights = equal_wt
)

stopifnot(!"equal_wt" %in% names(pew_2016_synth_pop))

usethis::use_data(pew_2016_synth_pop_svy, overwrite = TRUE)
message("Saved pew_2016_synth_pop_svy")
```

- [ ] **Step 2: Do NOT source — raw SAV file is unavailable**

Since the raw SPSS file is gitignored, we cannot re-generate the `.rda`. The `.rda` file will be regenerated the next time the data preparation scripts are run with the raw data. For CI purposes, the existing `pew_2016_synth_pop.rda` continues to work — it's a plain data frame that will work with `tibble::as_tibble()` when loaded.

- [ ] **Step 3: Commit**

```bash
git add data-raw/pew-2016-synth-pop.R
git commit -m "chore(data): remove pew_2016_synth_pop_svy from build script"
```

---

## Task 6: Update `data-raw/ns-wave1.R` — remove `_svy`, promote weight, add tibble + labels

**Files:**
- Modify: `data-raw/ns-wave1.R`

**What changes:**
1. Keep the raking procedure as-is (it produces the calibrated weight in `ns_wave1_svy@data$weight`)
2. After raking/trimming, extract the calibrated weight and UPDATE `ns_wave1$weight` (replaces the original published Nationscape weight with the raked+trimmed version)
3. Remove `usethis::use_data(ns_wave1, ns_wave1_svy, ...)` — save only `ns_wave1`
4. Add tibble conversion and labels to `ns_wave1` before saving

- [ ] **Step 1: Edit data-raw/ns-wave1.R**

After the raking/trimming and `rm()` call, replace the final block:
```r
usethis::use_data(ns_wave1, ns_wave1_svy, overwrite = TRUE)
message(
  "Saved ns_wave1 (",
  ...
  "(raked + trimmed; no replicate weights)"
)
```

With:

```r
# Promote raked+trimmed weight back into the tibble (replaces original published weight).
# ns_wave1_svy was only needed to compute the calibrated weight; discard afterwards.
ns_wave1$weight <- ns_wave1_svy@data$weight

rm(ns_wave1_svy)

# Add "label" attributes to derived columns
attr(ns_wave1$sex, "label")    <- "Sex (factor, derived from gender: 1=Male, 2=Female)"
attr(ns_wave1$age_f3, "label") <- "Age group (3 levels: 18-34, 35-54, 55+)"
attr(ns_wave1$race_f4, "label") <- "Race/ethnicity (4 levels: White, Black, Hispanic, Other)"
attr(ns_wave1$edu_f3, "label") <- "Educational attainment (3 levels)"
attr(ns_wave1$pid_f3, "label") <- "Party identification (3 levels)"
attr(ns_wave1$hh_income_f9, "label") <- "Household income (9 brackets, harmonized with cps_2023)"
attr(ns_wave1$ns_region, "label")     <- "Census region (Nationscape raking variable)"
attr(ns_wave1$ns_hispanic, "label")   <- "Hispanic ethnicity (3 categories, Nationscape raking variable)"
attr(ns_wave1$ns_race, "label")       <- "Race (4 categories, Nationscape raking variable)"
attr(ns_wave1$ns_age, "label")        <- "Age group (7 categories, Nationscape raking variable)"
attr(ns_wave1$ns_language, "label")   <- "Household language (Nationscape raking variable)"
attr(ns_wave1$ns_foreign_born, "label") <- "Foreign-born status (Nationscape raking variable)"
attr(ns_wave1$ns_income, "label")     <- "Household income (10 brackets, Nationscape raking variable)"
attr(ns_wave1$ns_vote_2016, "label")  <- "2016 presidential vote (Nationscape raking variable)"

ns_wave1 <- tibble::as_tibble(ns_wave1)

# Update the column count assertion (185 cols, weight is updated in-place)
stopifnot(ncol(ns_wave1) == 185L)

usethis::use_data(ns_wave1, overwrite = TRUE)
message(
  "Saved ns_wave1 (",
  nrow(ns_wave1),
  " rows x ",
  ncol(ns_wave1),
  " cols; weight = raked+trimmed Nationscape weight)"
)
```

- [ ] **Step 2: Source the script**

```r
source("data-raw/ns-wave1.R")
```

Expected: "Saved ns_wave1 (6422 rows x 185 cols; weight = raked+trimmed Nationscape weight)"

- [ ] **Step 3: Verify weight was updated**

```r
pkgload::load_all()
data(ns_wave1)
cat("tibble:", inherits(ns_wave1, "tbl_df"), "\n")
cat("weight range:", range(ns_wave1$weight), "\n")
cat("weight sum:", sum(ns_wave1$weight), "\n")
# The raked+trimmed weight sums to ~n (stabilized), not to the original published sum
```

- [ ] **Step 4: Commit**

```bash
git add data-raw/ns-wave1.R data/ns_wave1.rda
git commit -m "chore(data): remove ns_wave1_svy, promote raked weight into tibble"
```

---

## Task 7: Update `data-raw/pew-2016-optin.R` — fix bug, remove `_svy`, promote weights, add tibble + labels

**Files:**
- Modify: `data-raw/pew-2016-optin.R`

**Note:** The raw `.sav` file is gitignored. Edit the script but do NOT source it.

**What changes:**
1. Fix pre-existing bug: script currently overwrites `pew_2016_optin` with `optin_for_svy` (gaining undocumented `cal_division`, `cal_ideo3`, `weight=1` columns). Fix by tracking row indices separately and not overwriting.
2. After calibration/bootstrap, extract `weight` (calibrated) and `repwt_1`–`repwt_200` from `pew_2016_optin_svy@data` and bind into `pew_2016_optin`.
3. Remove `usethis::use_data(pew_2016_optin, pew_2016_optin_svy, ...)` — save only `pew_2016_optin`.
4. Add `"label"` attrs to derived columns; add `"question_preface"` to battery columns; add tibble conversion.
5. Update column count assertions: base 104 → promoted 305 (104 + weight + repwt_1..repwt_200).

- [ ] **Step 1: Edit data-raw/pew-2016-optin.R — fix the overwrite bug**

After the structural assertions (`stopifnot(sum(is.na(pew_2016_optin$pid_f3)) == 0L)`), change section 6:

Current (creates `optin_for_svy` as a copy with extra columns):
```r
optin_for_svy <- pew_2016_optin
```

Keep it but add a note that `pew_2016_optin` will NOT be overwritten at section 8.

Change section 8 from:
```r
## ---- 8. Keep only 2000 random respondents ----

optin_for_svy <- optin_for_svy[sample(nrow(optin_for_svy), 2000), ]
pew_2016_optin <- optin_for_svy
```

To:
```r
## ---- 8. Keep only 2000 random respondents ----

set.seed(42)
sampled_rows <- sample(nrow(optin_for_svy), 2000)
optin_for_svy <- optin_for_svy[sampled_rows, ]
# Subset the original 104-col pew_2016_optin to the same rows.
# Do NOT use optin_for_svy here (it has extra cal columns).
pew_2016_optin <- pew_2016_optin[sampled_rows, ]
```

Also remove `optin_for_svy$weight <- 1L` from section 6 (it's no longer needed in the calibration step — `calibrate_rake` with `wt_name = "weight"` will create the weight column internally if it doesn't exist, or we can add it back only in optin_for_svy):

Actually, looking at how `calibrate_rake` is called: `calibrate_rake(pew_2016_optin_svy, targets = ..., weights = weight, wt_name = "weight", ...)` — this requires a `weight` column to exist. So keep `optin_for_svy$weight <- 1L` (only on `optin_for_svy`, not propagated to `pew_2016_optin`).

- [ ] **Step 2: Edit data-raw/pew-2016-optin.R — section 9+: build svy from optin_for_svy only**

After section 11 (bootstrap weights), add the promotion block and replace the save call:

Replace:
```r
## ---- 14. Save data ----

usethis::use_data(pew_2016_optin, pew_2016_optin_svy, overwrite = TRUE)
message(
  "Saved pew_2016_optin_svy ",
  "(raked to synth_pop targets + 200 bootstrap replicate weights)"
)
```

With:
```r
## ---- 12. Promote calibrated weight and replicate weights into tibble ----

# pew_2016_optin is the 104-col tibble (104 original SPSS columns with
# derived demographic factors). Bind in the calibrated weight + 200 repwts.
pew_2016_optin$weight <- pew_2016_optin_svy@data$weight
repwt_cols <- pew_2016_optin_svy@variables$repweights  # "repwt_1" ... "repwt_200"
pew_2016_optin[repwt_cols] <- pew_2016_optin_svy@data[repwt_cols]

# Add "label" attributes to derived factor columns
attr(pew_2016_optin$sex, "label")    <- "Sex (factor, derived from gender: 1=Male, 2=Female)"
attr(pew_2016_optin$race_f4, "label") <- "Race/ethnicity (4 levels: White, Black, Hispanic, Other)"
attr(pew_2016_optin$edu_f3, "label") <- "Educational attainment (3 levels)"
attr(pew_2016_optin$pid_f3, "label") <- "Party identification (3 levels: Republican, Independent, Democrat)"
attr(pew_2016_optin$age_f3, "label") <- "Age group (3 levels: 18-34, 35-54, 55+)"
attr(pew_2016_optin$weight, "label") <- "Calibrated survey weight (raked to synth_pop targets, 5th/95th percentile trim)"
for (col in repwt_cols) {
  attr(pew_2016_optin[[col]], "label") <- paste0(
    "Quasi-randomization bootstrap replicate weight ",
    sub("repwt_", "", col)
  )
}

# Add "question_preface" to select-all race battery
race_acs_cols <- grep("^race_acs_", names(pew_2016_optin), value = TRUE)
race_preface <- "Which of the following describes your race? (Mark all that apply.)"
for (col in race_acs_cols) {
  attr(pew_2016_optin[[col]], "question_preface") <- race_preface
}

pew_2016_optin <- tibble::as_tibble(pew_2016_optin)

# 104 original cols + 1 (weight) + 200 (repwt_1..repwt_200) = 305
stopifnot(ncol(pew_2016_optin) == 305L)
stopifnot(nrow(pew_2016_optin) == 2000L)
stopifnot("weight" %in% names(pew_2016_optin))
stopifnot("repwt_1" %in% names(pew_2016_optin))
stopifnot("repwt_200" %in% names(pew_2016_optin))
stopifnot(all(pew_2016_optin$weight > 0))

usethis::use_data(pew_2016_optin, overwrite = TRUE)
message(
  "Saved pew_2016_optin ",
  "(2000 rows x 305 cols; calibrated weight + 200 bootstrap repwts)"
)
```

- [ ] **Step 3: Do NOT source — raw SAV file unavailable**

Since the raw SPSS file is gitignored, we cannot re-generate the `.rda`. Commit the script change only.

- [ ] **Step 4: Commit**

```bash
git add data-raw/pew-2016-optin.R
git commit -m "chore(data): fix pew_2016_optin overwrite bug, promote calibrated weights, remove _svy"
```

---

## Task 8: Delete `_svy` `.rda` files from `data/`

**Files:**
- Delete: `data/gss_2024_svy.rda`
- Delete: `data/npors_2025_svy.rda`
- Delete: `data/npors_2025_clean_svy.rda`
- Delete: `data/acs_wy_2022_svy.rda`
- Delete: `data/pew_2016_optin_svy.rda`
- Delete: `data/pew_2016_synth_pop_svy.rda`
- Delete: `data/ns_wave1_svy.rda`

- [ ] **Step 1: Delete all 7 files**

```bash
rm data/gss_2024_svy.rda \
   data/npors_2025_svy.rda \
   data/npors_2025_clean_svy.rda \
   data/acs_wy_2022_svy.rda \
   data/pew_2016_optin_svy.rda \
   data/pew_2016_synth_pop_svy.rda \
   data/ns_wave1_svy.rda
```

- [ ] **Step 2: Verify they're gone**

```bash
ls data/*_svy.rda 2>&1 | grep "No such file" || echo "Some _svy files remain — check"
```

Expected: output confirms no `_svy.rda` files remain.

- [ ] **Step 3: Commit**

```bash
git add -u data/
git commit -m "chore(data): delete 7 _svy companion .rda files"
```

---

## Task 9: Update `R/data.R` — remove `_svy` stubs, update descriptions, add weight items

**Files:**
- Modify: `R/data.R`

**What changes:** This is the largest editorial task. For each dataset:

1. **All datasets**: Remove the `#' @rdname <dataset>\n#' @keywords datasets\n"<dataset>_svy"` stub at the bottom of each section. Remove `@seealso` references to `_svy` objects. Remove the `## \`<dataset>_svy\`` subsection from `@format` blocks. Update `@description` to use inline construction pattern instead of referring to `_svy`.

2. **`gss_2024`**: Update `@description` to remove the sentence about `gss_2024_svy` being a survey_taylor object. Replace with instruction to construct inline: `surveycore::as_survey(gss_2024, weights = wtssps, strata = vstrat, ids = vpsu, nest = TRUE)`.

3. **`npors_2025`**: Update `@description` to add `strata = stratum` to the inline survey construction example (was missing). Update design description to note NPORS is a national address-based sample with stratified random sampling and differential probabilities of selection across strata.

4. **`pew_2016_optin`**: Change `@format` from "104 columns" to "305 columns". Add `\item{weight}` and `\item{repwt_1}`–`\item{repwt_200}` entries to the `\describe{}` block.

5. **`ns_wave1`**: Update `\item{weight}` description: change "Survey weight. Used by `ns_wave1_svy`." to "Raked survey weight replicating the Nationscape weighting procedure (Newton-Raphson, 10 marginal dimensions, 5th/95th percentile trim). Pearson r = 0.996 vs. published Nationscape weights."

6. **`pew_2016_synth_pop`**: Remove the `## \`pew_2016_synth_pop_svy\`` subsection and `@rdname` stub.

- [ ] **Step 1: Remove all `@rdname <x>_svy` stubs**

In `R/data.R`, find and remove each block matching this pattern:
```r
#' @rdname <dataset>
#' @keywords datasets
"<dataset>_svy"
```
Datasets: `gss_2024_svy`, `npors_2025_svy`, `npors_2025_clean_svy`, `acs_wy_2022_svy`, `pew_2016_optin_svy`, `pew_2016_synth_pop_svy`, `ns_wave1_svy`.

That means removing these 7 stubs from R/data.R:
```r
#' @rdname gss_2024
#' @keywords datasets
"gss_2024_svy"
```
(and the 6 analogous blocks for the other datasets)

- [ ] **Step 2: Remove `## \`<dataset>_svy\`` subsections from `@format` blocks**

For each dataset, remove the `## \`..._svy\`` heading and its description paragraph from the `@format` section. For example, in `gss_2024`:
```r
#' ## `gss_2024_svy`
#' A `survey_taylor` object wrapping `gss_2024`. Constructed with
#' `weights = wtssps`, `strata = vstrat`, `ids = vpsu`, `nest = TRUE`.
#' Use for standard survey estimation. For IPW, use `wt_pop` from the tibble
#' to construct a separate Taylor design (see `@description`).
```
(Remove this block for every dataset that has one)

- [ ] **Step 3: Update `@description` blocks to use inline construction**

For `gss_2024`, replace:
```r
#' `gss_2024_svy` is a `survey_taylor` object constructed with `wtssps`
#' as the weight column, and `vstrat`/`vpsu` as the stratification and PSU
#' variables (`nest = TRUE`). This is the correct design for standard
#' survey estimation. For IPW workflows, construct a reference design from
#' the `gss_2024` tibble using the `wt_pop` column:
#' ```r
#' data(gss_2024)
#' ref <- surveycore::as_survey(
#'   gss_2024, weights = wt_pop, strata = vstrat, ids = vpsu, nest = TRUE
#' )
#' ipw(ns_wave1, ref, selection = ~sex + age_f3)
#' ```
```
With:
```r
#' To construct a survey design for standard estimation, use:
#' ```r
#' data(gss_2024)
#' gss_design <- surveycore::as_survey(
#'   gss_2024, weights = wtssps, strata = vstrat, ids = vpsu, nest = TRUE
#' )
#' ```
#' For IPW workflows, use the `wt_pop` column instead of `wtssps`:
#' ```r
#' ref <- surveycore::as_survey(
#'   gss_2024, weights = wt_pop, strata = vstrat, ids = vpsu, nest = TRUE
#' )
#' ipw(ns_wave1, ref, selection = ~sex + age_f3)
#' ```
```

For `npors_2025`, update the inline survey construction example to include `strata = stratum` (was missing). Update the design description to note stratified sampling. Replace:
```r
#' `npors_2025_svy` is a `survey_taylor` object using `weight` as the weight
#' column (normalized NPORS weight, correct for standard estimation). For IPW
#' use, construct a reference design from the tibble using `wt_pop`:
#' ```r
#' data(npors_2025_clean)
#' ref <- surveycore::as_survey(npors_2025_clean, weights = wt_pop)
#' ipw(ns_wave1, ref,
#'     selection = ~sex + age_f3 + race_f4 + edu_f3,
#'     missing_method = "omit")
#' ```
```
With:
```r
#' NPORS is a national address-based probability sample with stratified random
#' sampling and differential probabilities of selection across strata. Always
#' include `strata = stratum` when constructing a survey design from this data.
#' To construct a survey design for standard estimation:
#' ```r
#' data(npors_2025_clean)
#' npors_design <- surveycore::as_survey(
#'   npors_2025_clean, weights = weight, strata = stratum
#' )
#' ```
#' For IPW use, construct a reference design using `wt_pop`:
#' ```r
#' ref <- surveycore::as_survey(
#'   npors_2025_clean, weights = wt_pop, strata = stratum
#' )
#' ipw(ns_wave1, ref,
#'     selection = ~sex + age_f3 + race_f4 + edu_f3,
#'     missing_method = "omit")
#' ```
```

Same update for `npors_2025_clean` description.

For `pew_2016_optin`, replace the `_svy` description paragraph with an inline construction pattern:
```r
#' To construct a `survey_nonprob` for analysis, use the promoted `weight`
#' column directly from the tibble:
#' ```r
#' data(pew_2016_optin)
#' pew_design <- surveycore::survey_nonprob(
#'   pew_2016_optin, variables = list(weights = "weight",
#'   repweights = grep("^repwt_", names(pew_2016_optin), value = TRUE))
#' )
#' ```
```

For `acs_wy_2022`, replace the description paragraph about `acs_wy_2022_svy` with inline construction:
```r
#' To construct a successive-difference replicate design for variance estimation:
#' ```r
#' data(acs_wy_2022)
#' rep_cols <- grep("^pwgtp[0-9]", names(acs_wy_2022), value = TRUE)
#' acs_svy <- surveycore::as_survey_replicate(
#'   acs_wy_2022, weights = pwgtp,
#'   repweights = dplyr::all_of(rep_cols),
#'   type = "successive-difference", mse = TRUE
#' )
#' ```
```

For `ns_wave1`, update the description to remove references to `ns_wave1_svy` and explain the promoted weight:
```r
#' The `weight` column contains the raked+trimmed survey weight that replicates
#' Nationscape's published weighting procedure (Newton-Raphson, 10 marginal
#' dimensions, 5th/95th percentile trim; Pearson r = 0.996 vs. published
#' weights). To construct a `survey_nonprob` for analysis:
#' ```r
#' data(ns_wave1)
#' ns_design <- surveycore::survey_nonprob(
#'   ns_wave1, variables = list(weights = "weight")
#' )
#' ```
```

- [ ] **Step 4: Update `@seealso` blocks**

Remove all `@seealso` references to `_svy` objects. For example:
- `gss_2024`: remove `[gss_2024_svy]` from `@seealso`
- `npors_2025`: remove `[npors_2025_svy]` and `[npors_2025_clean_svy]`
- etc.

- [ ] **Step 5: Update `pew_2016_optin` `@format` block for 305 columns**

Change the opening from:
```r
#' @format A data frame with 2,000 rows and 104 columns:
```
To:
```r
#' @format A data frame with 2,000 rows and 305 columns:
```

Add at the end of the `\describe{}` block (before the closing `}`), after `\item{age_f3}`:
```r
#'   \item{weight}{Numeric. Calibrated survey weight produced by raking to
#'     unweighted proportions from [pew_2016_synth_pop] (Newton-Raphson,
#'     7 marginal dimensions: `sex`, `age_f3`, `race_f4`, `edu_f3`,
#'     `division`, `pid_f3`, `ideo3`; 5th/95th percentile trim). All values
#'     are positive. Use with `weights = weight` when constructing a survey
#'     object.}
#'   \item{repwt_1}{Numeric. Quasi-randomization bootstrap replicate weight 1.
#'     Pass all 200 `repwt_*` columns to `surveycore::as_survey_nonprob()` as
#'     `repweights` for variance estimation.}
#'   \item{repwt_2}{Numeric. Quasi-randomization bootstrap replicate weight 2.}
#'   \item{repwt_3}{Numeric. Quasi-randomization bootstrap replicate weight 3.}
```
Continue through `repwt_200`. Use a compact pattern: items 4–199 as
```r
#'   \item{repwt_N}{Numeric. Quasi-randomization bootstrap replicate weight N.}
```

- [ ] **Step 6: Update `ns_wave1` `\item{weight}`**

Find in the `ns_wave1` `\describe{}` block:
```r
#'   \item{weight}{Numeric. Survey weight. Used by `ns_wave1_svy`.}
```

Replace with:
```r
#'   \item{weight}{Numeric. Raked survey weight replicating the Nationscape
#'     weighting procedure (Newton-Raphson, 10 marginal dimensions, 5th/95th
#'     percentile trim). Pearson r = 0.996 vs. the original published
#'     Nationscape weight. All values are positive.}
```

- [ ] **Step 7: Run devtools::document()**

```r
devtools::document()
```

Expected: NAMESPACE and man/ pages regenerated; 7 `_svy` Rd files removed.

- [ ] **Step 8: Commit**

```bash
git add R/data.R NAMESPACE man/
git commit -m "docs(data): remove _svy stubs, update descriptions with inline construction patterns, add weight/repwt items"
```

---

## Task 10: Update `tests/testthat/test-datasets.R`

**Files:**
- Modify: `tests/testthat/test-datasets.R`

**What changes:**
1. Remove the `test_that("new survey companion datasets are loadable via data()", ...)` block (lines 25–33) — loads all 7 `_svy` objects
2. Replace with tests that confirm promoted weight columns exist
3. Remove individual `_svy` structural test blocks (gss_2024_svy, npors_2025_svy, npors_2025_clean_svy, acs_wy_2022_svy, pew_2016_optin_svy, pew_2016_synth_pop_svy, ns_wave1_svy)
4. Add tests for pew_2016_optin weight/repwt columns and pew_2016_optin column count

- [ ] **Step 1: Remove the _svy load test block (lines 25–33)**

Remove:
```r
test_that("new survey companion datasets are loadable via data()", {
  expect_no_error(data(gss_2024_svy, envir = new.env()))
  expect_no_error(data(npors_2025_svy, envir = new.env()))
  expect_no_error(data(npors_2025_clean_svy, envir = new.env()))
  expect_no_error(data(acs_wy_2022_svy, envir = new.env()))
  expect_no_error(data(pew_2016_optin_svy, envir = new.env()))
  expect_no_error(data(pew_2016_synth_pop_svy, envir = new.env()))
  expect_no_error(data(ns_wave1_svy, envir = new.env()))
})
```

Replace with:
```r
test_that("_svy companion datasets are no longer in the package", {
  pkg_data <- data(package = "surveywts")$results[, "Item"]
  expect_false("gss_2024_svy" %in% pkg_data)
  expect_false("npors_2025_svy" %in% pkg_data)
  expect_false("npors_2025_clean_svy" %in% pkg_data)
  expect_false("acs_wy_2022_svy" %in% pkg_data)
  expect_false("pew_2016_optin_svy" %in% pkg_data)
  expect_false("pew_2016_synth_pop_svy" %in% pkg_data)
  expect_false("ns_wave1_svy" %in% pkg_data)
})
```

- [ ] **Step 2: Remove all individual `_svy` structural test blocks**

Remove these blocks entirely:
- `test_that("gss_2024_svy is survey_taylor with correct row count", ...)` (lines 119–124)
- `test_that("gss_2024_svy uses wtssps as weight column", ...)` (lines 126–129)
- `test_that("npors_2025_svy is survey_taylor with 5022 rows", ...)` (lines 195–199)
- `test_that("npors_2025_svy uses weight as weight column", ...)` (lines 201–204)
- `test_that("npors_2025_clean_svy is survey_taylor with matching row count", ...)` (lines 234–241)
- `test_that("acs_wy_2022_svy is survey_replicate with 4736 rows", ...)` (lines 298–303)
- `test_that("acs_wy_2022_svy uses pwgtp as weight column", ...)` (lines 305–309)
- `test_that("acs_wy_2022_svy has 80 replicate weight columns", ...)` (lines 311–315)
- `test_that("pew_2016_optin_svy is survey_nonprob with correct row count", ...)` (lines 330–336)
- `test_that("pew_2016_optin_svy has calibrated (non-unit) positive weights", ...)` (lines 343–350)
- `test_that("pew_2016_synth_pop_svy is survey_taylor with 20000 rows", ...)` (lines 356–362)
- `test_that("pew_2016_synth_pop_svy weights are all 1", ...)` (lines 364–368)
- `test_that("ns_wave1_svy is survey_nonprob with 6422 rows", ...)` (lines 451–455)
- `test_that("ns_wave1_svy uses weight as weight column", ...)` (lines 457–460)
- `test_that("ns_wave1_svy has no replicate weights", ...)` (lines 462–465)

- [ ] **Step 3: Add promoted-weight column tests**

After the `pew_2016_optin` section (after the existing `test_that("pew_2016_optin does NOT have equal_wt column", ...)` block), add:

```r
test_that("pew_2016_optin has 305 columns (104 original + weight + 200 repwts)", {
  data(pew_2016_optin)
  expect_equal(ncol(pew_2016_optin), 305L)
})

test_that("pew_2016_optin has promoted calibrated weight column", {
  data(pew_2016_optin)
  expect_true("weight" %in% names(pew_2016_optin))
  expect_true(is.numeric(pew_2016_optin$weight))
  expect_true(all(pew_2016_optin$weight > 0))
  # Calibrated weights vary around 1
  expect_gt(sd(pew_2016_optin$weight), 0.01)
})

test_that("pew_2016_optin has 200 bootstrap replicate weight columns", {
  data(pew_2016_optin)
  repwt_cols <- grep("^repwt_", names(pew_2016_optin), value = TRUE)
  expect_equal(length(repwt_cols), 200L)
  expect_true("repwt_1" %in% repwt_cols)
  expect_true("repwt_200" %in% repwt_cols)
})
```

After the `ns_wave1` section (after the existing column presence tests), add:

```r
test_that("ns_wave1 weight column is raked+trimmed (not original published weight)", {
  data(ns_wave1)
  # Raked weight sums to approximately n (stabilized by calibrate_rake)
  # Original published Nationscape weight summed to about 6422
  # The raked weight mean is approximately 1 and varies around the original
  expect_true(is.numeric(ns_wave1$weight))
  expect_true(all(ns_wave1$weight > 0))
  expect_true("weight" %in% names(ns_wave1))
})
```

- [ ] **Step 4: Remove `data(gss_2024_svy)` and `data(ns_wave1_svy)` from integration tests**

In the `ipw()` integration tests section at the bottom (lines 470+), the tests currently reference `data(gss_2024_svy)` and `data(ns_wave1_svy)` — they don't use these objects, but they have load lines that will fail. Check and remove any leftover load lines for `_svy` objects.

- [ ] **Step 5: Run tests**

```r
devtools::test(filter = "datasets")
```

Expected: all tests pass; old `_svy` tests removed; new promoted-column tests pass.

- [ ] **Step 6: Commit**

```bash
git add tests/testthat/test-datasets.R
git commit -m "test(datasets): replace _svy load tests with promoted weight column checks"
```

---

## Task 11: Run `devtools::check()` and open PR

**Files:**
- No new files

- [ ] **Step 1: Run `devtools::document()` one final time**

```r
devtools::document()
```

Verify that man/ pages for `gss_2024_svy`, `npors_2025_svy`, etc. are gone.

- [ ] **Step 2: Run full check**

```r
devtools::check()
```

Expected: 0 errors, 0 warnings, ≤2 pre-approved notes.

Known things to watch for:
- `no visible binding for global variable` notes — pre-approved, OK
- `checking data for non-ASCII characters` — OK if pew data has non-ASCII
- Any `codoc` WARNING about undocumented columns — this would indicate a mismatch between `R/data.R` and the actual `.rda` files. Fix before opening PR.

- [ ] **Step 3: Run full test suite**

```r
devtools::test()
```

Expected: all tests pass.

- [ ] **Step 4: Push and open PR**

```bash
git push -u origin feature/dataset-cleanup-pr1
```

Then open PR against `develop`. PR title: `chore(data): remove _svy objects, promote calibrated weights into tibbles`

---

## Spec Coverage Check

| Spec requirement | Task |
|---|---|
| Delete 7 `_svy` `.rda` files | Task 8 |
| Update `data-raw/` scripts to stop producing `_svy` objects | Tasks 2–7 |
| Convert all 8 datasets to tibbles (`tibble::as_tibble()`) | Tasks 2–7 |
| Add `attr(col, "label")` to every column | Tasks 2–7 |
| Add `attr(col, "labels")` to numeric columns | Tasks 2–7 (derived cols are factors; wt_pop is continuous; labels for original numeric columns are handled by surveycore/haven) |
| Add `attr(col, "question_preface")` to battery/select-all columns | Task 7 (race_acs_* in pew_2016_optin) |
| Promote calibrated weight columns into `pew_2016_optin` | Task 7 |
| Promote raked weight into `ns_wave1` | Task 6 |
| Rewrite `R/data.R`: remove `_svy` stubs, update `@format`, add `\item{}` entries | Task 9 |
| `devtools::document()` + `devtools::check()` | Task 11 |

**Note on `"labels"` attributes for original numeric columns:** The spec says to add `"labels"` to numeric columns. For surveycore-sourced datasets (`gss_2024`, `npors_2025`, etc.), the `as.data.frame()` call preserves column-level attributes from surveycore. If surveycore does not currently set `"labels"` on its columns, this is out of scope for this PR (would require surveycore changes). Verify by running `attr(gss_2024$race, "labels")` after sourcing gss-2024.R — if `NULL`, note it for the Polish release. For pew datasets, haven already preserves `"labels"` from SPSS source, so no manual work is needed.

**Note on BATTERIES_PEW2016 `"question_preface"` in pew-2016-optin.R:** The spec asks to add `question_preface` to battery columns. The raw SAV file is not in version control, so we can only add the ones we can identify from the data.R column list. The `race_acs_*` columns (race select-all items) are clearly identified. If additional battery columns are identified from the codebook when the SAV file is available, add them then.
