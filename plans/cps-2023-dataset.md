# Plan — CPS ASEC 2023 Dataset

**Date:** 2026-06-23
**Status:** Draft
**Branch:** `feature/cps-2023-dataset`

---

## I. Overview

Adds a national household probability sample to the package for use as the
`reference` argument in `ipw()`. The existing reference datasets are either
geographically limited (`acs_wy_2022`: Wyoming only) or opinion-survey focused
(`gss_2024`, `npors_2025`). A national CPS ASEC extract provides household
income, employment status, and urban/rural geography — variables that explain
selection into online panels beyond basic demographics, enabling a richer
propensity model in `ipw()` examples.

**Objects produced:**

| Tibble | Class | Role |
|---|---|---|
| `cps_2023` | `data.frame` / tibble | National probability reference for IPW |

No `_svy` companion object is produced. The 160 `repwtp*` columns are
retained in the tibble so users can construct a `survey_replicate` design
themselves via `surveycore::as_survey_replicate()` if needed for variance
estimation.

**Design note — no PSU/stratum variables:** The Census Bureau does not release
PSU or stratum identifiers for the CPS ASEC in public microdata; they are kept
confidential to protect geographic privacy. The official substitute for variance
estimation is 160 successive-difference replication (SDR) replicate weights
(REPWTP1–REPWTP160 in IPUMS-CPS), which are explicitly designed to enable
correct variance estimation without requiring PSU/stratum access.

**Companion PR required:** Before or alongside this PR, remove all `_svy`
companion datasets (`gss_2024_svy`, `npors_2025_svy`, `npors_2025_clean_svy`,
`ns_wave1_svy`, `pew_2016_optin_svy`, `pew_2016_synth_pop_svy`) and
`acs_wy_2022` / `acs_wy_2022_svy` from `data/`, `R/data.R`, and update the 9
function examples that currently load `_svy` objects inline. Also update all
dataset `@seealso` entries to use the comprehensive cross-referencing policy
(every dataset lists all other datasets).

**Files changed:**

```
data-raw/cps-2023.R        NEW
data-raw/cps_2023/         NEW directory (gitignored); holds raw IPUMS extract
data/cps_2023.rda          NEW
R/data.R                   MODIFY — add cps_2023 man page block
.gitignore                 MODIFY — add data-raw/cps_2023/
```

---

## II. Download Instructions

### Source

IPUMS-CPS is the recommended path. It provides harmonized variable names and
codes across years, and bundles the 160 replicate weights in the same extract.

**URL**: https://cps.ipums.org/cps/

**Account required**: yes (free registration).

### Variables to request

Create a new extract at IPUMS-CPS. Select:

- **Sample**: CPS ASEC 2023 (March 2023 supplement)
- **File format**: CSV (recommended for ease of reading)
- **Replicate weights**: enable the "Include replicate weights" option — this
  adds REPWTP (indicator) and REPWTP1–REPWTP160 to the extract

**Household-level variables:**

| Variable | Label |
|---|---|
| `SERIAL` | Household serial number |
| `HHINCOME` | Total household income |
| `FAMSIZE` | Number of persons in family |
| `NCHILD` | Number of own children in household |
| `HHTYPE` | Household type |

**Person-level variables:**

| Variable | Label |
|---|---|
| `CPSIDP` | Person identifier |
| `ASECFLAG` | ASEC respondent flag |
| `WTFINL` | Final person weight |
| `REPWTP` | Replicate weight presence indicator |
| `REPWTP1`–`REPWTP160` | 160 SDR replicate weights (added automatically when replicate weights are enabled) |
| `AGE` | Age |
| `SEX` | Sex |
| `RACE` | Race |
| `HISPAN` | Hispanic origin |
| `EDUC` | Educational attainment |
| `EMPSTAT` | Employment status |
| `CLASSWKR` | Class of worker |
| `WKSWORK2` | Weeks worked last year (intervals) |
| `UHRSWORKLY` | Usual hours worked per week |
| `INCTOT` | Total personal income |
| `MARST` | Marital status |
| `HEALTH` | Health status |
| `REGION` | Census region |
| `METRO` | Metropolitan status |
| `STATEFIP` | State FIPS code |

### Placing the raw file

After downloading, place the CSV in `data-raw/cps_2023/`:

```
data-raw/cps_2023/cps_2023.csv
```

The `data-raw/cps_2023/` directory is gitignored (raw IPUMS extracts are large
and cannot be redistributed). Add to `.gitignore` if not already present:

```
data-raw/cps_2023/
```

---

## III. `cps_2023` Tibble Contract

### Row selection

1. Keep only ASEC respondents: `asecflag == 1`
2. Keep only adults: `age >= 18`
3. Drop zero-weight rows: `wtfinl > 0`
4. After filtering, draw a stratified random sample of approximately **10,000**
   persons. Stratify by `region` × `sex` to maintain geographic and sex balance.
   Use `set.seed(42L)`.

### Columns to retain

Keep these original CPS columns verbatim (before derived columns):

| Column | Type | Notes |
|---|---|---|
| `cpsidp` | character | Person identifier |
| `serial` | integer | Household serial number |
| `wtfinl` | numeric | Person final weight (population-scaled; use directly for IPW — no `wt_pop` column needed) |
| `repwtp1`–`repwtp160` | numeric | 160 SDR replicate weights; select with `grep("^repwtp[0-9]", names(raw), value = TRUE)` to exclude the `repwtp` indicator column |
| `statefip` | integer | State FIPS |
| `region` | integer | Census region: 1=NE, 2=MW, 3=S, 4=W |
| `metro` | integer | Metro status: 0=not identified, 1=not in metro, 2=central city, 3=outside central city, 4=central/non-central unclear |
| `age` | integer | Age in years |
| `sex` | integer | 1=Male, 2=Female (overwritten in-place with factor) |
| `race` | integer | IPUMS race recode |
| `hispan` | integer | Hispanic origin: 0=Not Hispanic, 100–412=Hispanic origins, 901–902=N/A |
| `educ` | integer | IPUMS educational attainment recode |
| `marst` | integer | Marital status: 1=Married/spouse present, 2=Married/spouse absent, 3=Separated, 4=Divorced, 5=Widowed, 6=Never married |
| `empstat` | integer | Employment status: 1=AF, 10=At work, 12=Has job not at work, 20–22=Unemployed, 30–36=NILF |
| `classwkr` | integer | Class of worker |
| `wkswork2` | integer | Weeks worked intervals: 1=1–13, 2=14–26, 3=27–39, 4=40–47, 5=48–49, 6=50–52 |
| `uhrsworkly` | integer | Usual hours/week; 999=N/A |
| `inctot` | integer | Total personal income; 99999999=N/A |
| `hhincome` | integer | Total household income; 99999999=N/A |
| `health` | integer | Health status: 1=Excellent, 2=Very good, 3=Good, 4=Fair, 5=Poor |
| `nchild` | integer | Number of own children in household |
| `famsize` | integer | Number of persons in family |

Do **not** retain `repwtp` (the indicator column, always 1). Use
`grep("^repwtp[0-9]", ...)` — not `starts_with("repwtp")` — to exclude it.
The `^repwtp[0-9]` pattern matches only `repwtp1`–`repwtp160` and not the
bare `repwtp` indicator.

### Derived columns

Add these after row selection and sampling.

**`sex` (overwrite in-place):**
```r
cps_2023$sex <- factor(
  cps_2023$sex,
  levels = c(1L, 2L),
  labels = c("Male", "Female")
)
# No NAs expected (sex is always observed in CPS ASEC)
```

**`age_f3`:**
```r
cps_2023$age_f3 <- cut(
  cps_2023$age,
  breaks = c(18, 35, 55, Inf),
  labels = c("18-34", "35-54", "55+"),
  right  = FALSE
)
```

**`race_f4`:**

Hispanic origin takes precedence. IPUMS `hispan` 100–412 = Hispanic; 0 = not
Hispanic; 901–902 = N/A (treat as non-Hispanic since CPS racial classification
is collected separately). IPUMS `race` 100 = White, 200 = Black; Asian and
Pacific Islander codes (650, 651, 652) collapsed to `"Other"` to match the
package convention.

```r
cps_2023$race_f4 <- factor(
  dplyr::case_when(
    cps_2023$hispan >= 100L & cps_2023$hispan <= 412L ~ "Hispanic",
    cps_2023$race == 100L                              ~ "White",
    cps_2023$race == 200L                              ~ "Black",
    .default                                            = "Other"
  ),
  levels = c("White", "Black", "Hispanic", "Other")
)
```

**`edu_f3`:**

IPUMS `educ` codes: 000 = N/A or preschool; 001–059 = did not complete HS;
060 = HS diploma or equivalent; 071–110 = some college or associate's degree;
111–125 = bachelor's or higher.

```r
cps_2023$edu_f3 <- factor(
  dplyr::case_when(
    cps_2023$educ == 0L    ~ NA_character_,
    cps_2023$educ < 60L    ~ "Less than HS",
    cps_2023$educ <= 110L  ~ "HS/Some college",
    cps_2023$educ >= 111L  ~ "College+",
    .default               = NA_character_
  ),
  levels = c("Less than HS", "HS/Some college", "College+")
)
# Verified in structural assertions: mean(is.na(cps_2023$edu_f3)) < 0.01
```

**`empstat_f` (new):**

No other package dataset has an employment measure. It is a key predictor for
online panel selection (employed respondents are systematically more likely to
complete web surveys).

```r
cps_2023$empstat_f <- factor(
  dplyr::case_when(
    cps_2023$empstat %in% c(10L, 12L)       ~ "Employed",
    cps_2023$empstat %in% c(20L, 21L, 22L)  ~ "Unemployed",
    .default                                  = "Not in labor force"
  ),
  levels = c("Employed", "Unemployed", "Not in labor force")
)
# Armed Forces (empstat == 1) → "Not in labor force" (via .default)
```

**`inc_hh_cat` (new):**

Household income explains online panel access better than personal income.
`hhincome == 99999999` = missing → `NA`.

```r
inc <- cps_2023$hhincome
inc[inc >= 99999999L] <- NA_integer_
cps_2023$inc_hh_cat <- factor(
  dplyr::case_when(
    is.na(inc)      ~ NA_character_,
    inc < 25000L    ~ "Under $25k",
    inc < 50000L    ~ "$25k-$50k",
    inc < 75000L    ~ "$50k-$75k",
    inc < 100000L   ~ "$75k-$100k",
    .default        = "$100k+"
  ),
  levels = c("Under $25k", "$25k-$50k", "$50k-$75k", "$75k-$100k", "$100k+")
)
```

### No `wt_pop` column

`wtfinl` is already population-scaled. Use it directly for IPW. Do not add a
`wt_pop` column.

### Total column count

21 original columns (including `sex` overwritten in-place) + 160 replicate
weight columns + 5 derived (`sex` net 0 new; +5 new: `age_f3`, `race_f4`,
`edu_f3`, `empstat_f`, `inc_hh_cat`) = **186 columns**. Assert this
count explicitly in the script.

---

## IV. `data-raw/cps-2023.R` Script Structure

```r
## data-raw/cps-2023.R
##
## Produces:
##   cps_2023     — CPS ASEC 2023 adult sample (~10,000 rows) with derived cols
##
## Source: IPUMS-CPS, 2023 Annual Social and Economic Supplement (March 2023).
## License: Academic / non-commercial use per IPUMS terms of use.
##
## Design note: CPS ASEC PSU and stratum identifiers are not publicly released
## by the Census Bureau. The 160 SDR replicate weights (REPWTP1-REPWTP160)
## are the official substitute for variance estimation.
##
## Raw extract must be placed at:
##   data-raw/cps_2023/cps_2023.csv
##
## To download: register at https://cps.ipums.org/cps/, create an extract with
## the variables listed in plans/cps-2023-dataset.md Section II, enable
## replicate weights, select the 2023 ASEC sample, and download as CSV.
##
## Run from the package root: source("data-raw/cps-2023.R")

library(dplyr)

## ---- constants --------------------------------------------------------------
age_f3_bins    <- c(18, 35, 55, Inf)
age_f3_labs    <- c("18-34", "35-54", "55+")
race_f4_levels <- c("White", "Black", "Hispanic", "Other")
edu_f3_levels  <- c("Less than HS", "HS/Some college", "College+")
empstat_levels <- c("Employed", "Unemployed", "Not in labor force")
inc_hh_levels  <- c("Under $25k", "$25k-$50k", "$50k-$75k", "$75k-$100k", "$100k+")

## ---- read raw extract -------------------------------------------------------
CPS_FILE <- file.path(here::here(), "data-raw", "cps_2023", "cps_2023.csv")

if (!file.exists(CPS_FILE)) {
  stop(
    "Raw CPS file not found: ", CPS_FILE, "\n",
    "See plans/cps-2023-dataset.md Section II for download instructions."
  )
}

raw <- as.data.frame(
  readr::read_csv(CPS_FILE, show_col_types = FALSE),
  stringsAsFactors = FALSE
)

# Lowercase all column names (IPUMS CSV exports are uppercase by default)
names(raw) <- tolower(names(raw))

## ---- row selection ----------------------------------------------------------
raw <- raw[raw$asecflag == 1L & raw$age >= 18L & raw$wtfinl > 0, ]

# Stratified random sample: ~10,000 rows, stratified by region × sex
set.seed(42L)
strat_key <- paste(raw$region, raw$sex, sep = "_")
idx <- unlist(tapply(
  seq_len(nrow(raw)),
  strat_key,
  function(i) {
    n_draw <- max(1L, round(10000L * length(i) / nrow(raw)))
    sample(i, min(n_draw, length(i)))
  }
))
raw <- raw[sort(idx), ]

## ---- select columns ---------------------------------------------------------
rep_cols <- grep("^repwtp[0-9]", names(raw), value = TRUE)
stopifnot(length(rep_cols) == 160L)

keep_cols <- c(
  "cpsidp", "serial", "wtfinl",
  rep_cols,
  "statefip", "region", "metro",
  "age", "sex", "race", "hispan", "educ",
  "marst", "empstat", "classwkr", "wkswork2", "uhrsworkly",
  "inctot", "hhincome", "health", "nchild", "famsize"
)
cps_2023 <- raw[, keep_cols]

## ---- derived columns --------------------------------------------------------
cps_2023$sex <- factor(cps_2023$sex, levels = c(1L, 2L), labels = c("Male", "Female"))

cps_2023$age_f3 <- cut(
  cps_2023$age,
  breaks = age_f3_bins,
  labels = age_f3_labs,
  right  = FALSE
)

cps_2023$race_f4 <- factor(
  dplyr::case_when(
    cps_2023$hispan >= 100L & cps_2023$hispan <= 412L ~ "Hispanic",
    cps_2023$race == 100L                              ~ "White",
    cps_2023$race == 200L                              ~ "Black",
    .default                                            = "Other"
  ),
  levels = race_f4_levels
)

cps_2023$edu_f3 <- factor(
  dplyr::case_when(
    cps_2023$educ == 0L   ~ NA_character_,
    cps_2023$educ < 60L   ~ "Less than HS",
    cps_2023$educ <= 110L ~ "HS/Some college",
    cps_2023$educ >= 111L ~ "College+",
    .default              = NA_character_
  ),
  levels = edu_f3_levels
)

cps_2023$empstat_f <- factor(
  dplyr::case_when(
    cps_2023$empstat %in% c(10L, 12L)      ~ "Employed",
    cps_2023$empstat %in% c(20L, 21L, 22L) ~ "Unemployed",
    .default                                = "Not in labor force"
  ),
  levels = empstat_levels
)

inc <- cps_2023$hhincome
inc[inc >= 99999999L] <- NA_integer_
cps_2023$inc_hh_cat <- factor(
  dplyr::case_when(
    is.na(inc)    ~ NA_character_,
    inc < 25000L  ~ "Under $25k",
    inc < 50000L  ~ "$25k-$50k",
    inc < 75000L  ~ "$50k-$75k",
    inc < 100000L ~ "$75k-$100k",
    .default      = "$100k+"
  ),
  levels = inc_hh_levels
)

## ---- structural assertions --------------------------------------------------
stopifnot(nrow(cps_2023) >= 9000L, nrow(cps_2023) <= 11000L)
stopifnot(ncol(cps_2023) == 186L)
stopifnot(is.factor(cps_2023$sex))
stopifnot(is.factor(cps_2023$age_f3))
stopifnot(is.factor(cps_2023$race_f4))
stopifnot(is.factor(cps_2023$edu_f3))
stopifnot(mean(is.na(cps_2023$edu_f3)) < 0.01)
stopifnot(is.factor(cps_2023$empstat_f))
stopifnot(is.factor(cps_2023$inc_hh_cat))
stopifnot(all(cps_2023$wtfinl > 0))
stopifnot(sum(is.na(cps_2023$sex)) == 0L)
stopifnot(sum(is.na(cps_2023$age_f3)) == 0L)
stopifnot(sum(is.na(cps_2023$race_f4)) == 0L)
stopifnot(sum(is.na(cps_2023$empstat_f)) == 0L)

usethis::use_data(cps_2023, overwrite = TRUE)
message(
  "Saved cps_2023 (",
  nrow(cps_2023), " rows x ", ncol(cps_2023), " cols)"
)
```

---

## V. `R/data.R` Documentation

Add a new block. The `\describe{}` block must document **every column**.
The 160 replicate weight columns (`repwtp1`–`repwtp160`) each need an individual
`\item{}` entry. Generate those 160 entries with text substitution rather than
typing them manually.

### Man page header

```r
#' CPS ASEC 2023 national adult sample with harmonized demographic columns
#'
#' @description
#' A person-level probability sample of U.S. adults drawn from the 2023
#' Current Population Survey Annual Social and Economic Supplement (CPS ASEC,
#' March 2023), obtained from IPUMS-CPS. The CPS ASEC is conducted by the
#' U.S. Census Bureau and Bureau of Labor Statistics and is the primary source
#' for national estimates of income, poverty, and employment. Approximately
#' 10,000 adult respondents (age 18+) are retained after stratified random
#' sampling from the full ASEC extract (stratified by census region and sex,
#' `set.seed(42)`). The person weight `wtfinl` is population-scaled by design;
#' use it directly for IPW reference construction.
#'
#' PSU and stratum identifiers are not released in the public CPS microdata.
#' The 160 SDR replicate weight columns (`repwtp1`–`repwtp160`) are the Census
#' Bureau's official substitute for variance estimation; use them to construct a
#' `survey_replicate` design via `surveycore::as_survey_replicate()` when needed.
#' For IPW workflows, construct a plain Taylor design from the tibble:
#' ```r
#' data(cps_2023)
#' cps_ref <- surveycore::as_survey(cps_2023, weights = wtfinl)
#' ipw(
#'   ns_wave1, cps_ref,
#'   selection = ~sex + age_f3 + race_f4 + edu_f3 + empstat_f + inc_hh_cat,
#'   missing_method = "omit"
#' )
#' ```
```

### Key `@format` entries for derived and novel columns

```
\item{wtfinl}{Numeric. CPS ASEC final person weight, population-scaled
  by design (values reflect the U.S. adult civilian non-institutional
  population). Use directly for IPW reference construction; no scaling
  needed.}

\item{repwtp1}{Numeric. Successive-difference replicate weight 1. Pass all
  160 `repwtp*` columns to `surveycore::as_survey_replicate()` to construct
  a variance-estimation design.}
[... repwtp2 through repwtp159 follow the same pattern ...]
\item{repwtp160}{Numeric. Successive-difference replicate weight 160.}

\item{sex}{Factor. Derived from the raw `sex` column (overwritten
  in-place): `1` = `"Male"`, `2` = `"Female"`. No `NA` values. Levels:
  `c("Male", "Female")`.}

\item{age_f3}{Factor. Derived from `age`:
  `cut(age, breaks = c(18, 35, 55, Inf), right = FALSE)`. No `NA`
  values for adult respondents. Levels: `c("18-34", "35-54", "55+")`.}

\item{race_f4}{Factor. Derived from `race` and `hispan`: Hispanic
  origin takes precedence (`hispan %in% 100:412`); `race == 100` =
  `"White"`, `race == 200` = `"Black"`, all other races (including
  Asian/Pacific Islander codes 650–652) collapsed to `"Other"`.
  No `NA` values. Levels: `c("White", "Black", "Hispanic", "Other")`.}

\item{edu_f3}{Factor. Derived from `educ` (IPUMS recode): codes
  `1:59` = `"Less than HS"`, `60:110` = `"HS/Some college"` (HS
  diploma through associate's degree), `111:125` = `"College+"`.
  Code `0` (N/A) → `NA`. Levels:
  `c("Less than HS", "HS/Some college", "College+")`.}

\item{empstat_f}{Factor. Derived from `empstat`: codes `10`–`12` =
  `"Employed"` (at work or has job but not at work), codes `20`–`22`
  = `"Unemployed"`, all remaining codes (Armed Forces, not in labor
  force) = `"Not in labor force"`. No `NA` values. Levels:
  `c("Employed", "Unemployed", "Not in labor force")`.}

\item{inc_hh_cat}{Factor. Five household income brackets derived from
  `hhincome`. Code `99999999` (missing/N/A) → `NA`. Levels:
  `c("Under $25k", "$25k-$50k", "$50k-$75k", "$75k-$100k", "$100k+")`.
  Some `NA` values present.}
```

### `@source` and `@seealso`

```r
#' @source IPUMS-CPS, 2023 Annual Social and Economic Supplement (March 2023).
#'   Sarah Flood, Miriam King, Renae Rodgers, Steven Ruggles, J. Robert Warren,
#'   Daniel Backman, Annie Chen, Grace Cooper, Stephanie Richards, Megan
#'   Schouweiler, and Michael Westberry. IPUMS CPS: Version 11.0 [dataset].
#'   Minneapolis, MN: IPUMS, 2023. https://doi.org/10.18128/D030.V11.0
#'   See `data-raw/cps-2023.R` for the construction script.
#' @seealso [ns_wave1], [pew_2016_optin], [npors_2025], [npors_2025_clean],
#'   [gss_2024], [pew_2016_synth_pop]
#' @keywords datasets
```

---

## VI. Quality Gates

Before opening a PR:

- [ ] `data-raw/cps_2023/cps_2023.csv` present
- [ ] `source("data-raw/cps-2023.R")` completes without error
- [ ] All `stopifnot()` assertions pass, including `ncol(cps_2023) == 186L`
      and `length(rep_cols) == 160L`
- [ ] `data/cps_2023.rda` saved
- [ ] `devtools::document()` — no NAMESPACE drift; `man/cps_2023.Rd` generated
- [ ] `R CMD check` (`devtools::check()`): 0 errors, 0 warnings; `codoc`
      passes (all 186 columns have a matching `\item{}` entry)
- [ ] `data(cps_2023)` loads without error
- [ ] IPW workflow example runs interactively without error
- [ ] `nrow(cps_2023)` is between 9,000 and 11,000
- [ ] `sum(cps_2023$wtfinl) > 5e6` (confirms weights are still
      population-scaled, not normalized; tighten range after first run)
