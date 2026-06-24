# CPS 2023 Dataset Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `cps_2023`, a national CPS ASEC 2023 adult sample (~10,000 rows, 186 columns), as a bundled package dataset for use as the `reference` argument in `ipw()` examples.

**Architecture:** The raw IPUMS-CPS extract (CSV, gitignored) is processed by `data-raw/cps-2023.R` into `data/cps_2023.rda`. The script filters to ASEC adult respondents, draws a stratified sample, selects 21 core columns + 160 replicate weight columns, and adds 5 derived factor columns. Documentation lives in `R/data.R` as a single roxygen2 block with 186 `\item{}` entries.

**Tech Stack:** R, roxygen2, readr, dplyr, usethis, devtools, IPUMS-CPS (external data source).

## Global Constraints

- All 186 columns in `cps_2023` must have a matching `\item{}` entry — codoc reads only the first `\describe{}` block and requires bidirectional coverage.
- `grep("^repwtp[0-9]", names(raw), value = TRUE)` — not `starts_with("repwtp")` — to exclude the bare `repwtp` indicator column.
- `set.seed(42L)` for the stratified sample.
- Target: `nrow(cps_2023)` between 9,000 and 11,000; `ncol(cps_2023) == 186L`.
- `devtools::document()` must be run before any commit touching `R/data.R`.
- `devtools::check()` must pass with 0 errors, 0 warnings before PR.
- Branch from `develop`, not `main`. Branch name: `feature/cps-2023-dataset`.
- **Companion PR is out of scope:** removing `_svy` datasets and `acs_wy_2022` is a separate PR.

---

## File Map

| File | Action | Purpose |
|------|--------|---------|
| `data-raw/cps-2023.R` | **Create** | Processes raw IPUMS CSV into `cps_2023.rda` |
| `data-raw/cps_2023/cps_2023.csv` | **User-downloaded** | Raw IPUMS extract (gitignored; not committed) |
| `data/cps_2023.rda` | **Generated** | Bundled dataset (committed after script runs) |
| `R/data.R` | **Modify** (append) | Roxygen2 documentation block for `cps_2023` |
| `man/cps_2023.Rd` | **Generated** | Help file produced by `devtools::document()` |
| `.gitignore` | **Modify** | Add `data-raw/cps_2023/` entry |

---

## Task 1: Branch Setup and `.gitignore`

**Files:**
- Modify: `.gitignore`

**Interfaces:**
- Produces: branch `feature/cps-2023-dataset`; `.gitignore` entry preventing raw IPUMS data from being committed

- [ ] **Step 1: Create feature branch from develop**

```bash
git checkout develop
git checkout -b feature/cps-2023-dataset
```

Expected: `Switched to a new branch 'feature/cps-2023-dataset'`

- [ ] **Step 2: Add gitignore entry**

Open `.gitignore` and append this line at the end (after the `/.quarto/` entry):

```
data-raw/cps_2023/
```

- [ ] **Step 3: Verify the entry was added**

```bash
grep "cps_2023" .gitignore
```

Expected: `data-raw/cps_2023/`

- [ ] **Step 4: Commit**

```bash
git add .gitignore
git commit -m "chore: gitignore raw CPS IPUMS extract directory"
```

---

## Task 2: Write `data-raw/cps-2023.R`

**Files:**
- Create: `data-raw/cps-2023.R`

**Interfaces:**
- Consumes: `data-raw/cps_2023/cps_2023.csv` (user-downloaded; not present yet — script has a guard)
- Produces: `data/cps_2023.rda` when run with the CSV present

- [ ] **Step 1: Create the script file**

Create `data-raw/cps-2023.R` with this exact content:

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

# Stratified random sample: ~10,000 rows, stratified by region x sex
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

- [ ] **Step 2: Verify the file exists and has the right line count**

```bash
wc -l data-raw/cps-2023.R
```

Expected: approximately 91 lines.

- [ ] **Step 3: Commit**

```bash
git add data-raw/cps-2023.R
git commit -m "feat(data): add data-raw/cps-2023.R processing script"
```

---

## Task 3: Write `R/data.R` Documentation Block

**Files:**
- Modify: `R/data.R` (append ~270 lines at the end)

**Interfaces:**
- Consumes: column structure specified in `plans/cps-2023-dataset.md` Section III
- Produces: roxygen2 block that, after `devtools::document()`, generates `man/cps_2023.Rd` and satisfies codoc's 186-column requirement

The documentation must use a single `\describe{}` block with exactly 186 `\item{}` entries (codoc ignores additional `\describe{}` blocks). The 160 `repwtp1`–`repwtp160` items are generated programmatically in Step 1 below.

- [ ] **Step 1: Generate the 160 repwtp `\item{}` lines**

Run this in an R session from the package root:

```r
# Run once to generate repwtp items — paste output into the doc block (Step 2)
lines <- character(160)
lines[1] <- paste0(
  "#'   \\item{repwtp1}{Numeric. Successive-difference replicate weight 1. ",
  "Pass all 160 `repwtp*` columns to `surveycore::as_survey_replicate()` ",
  "to construct a variance-estimation design.}"
)
for (i in 2:159) {
  lines[i] <- paste0(
    "#'   \\item{repwtp", i, "}{Numeric. Successive-difference replicate weight ", i, ".}"
  )
}
lines[160] <- paste0(
  "#'   \\item{repwtp160}{Numeric. Successive-difference replicate weight 160.}"
)
cat(lines, sep = "\n")
```

Copy the printed output — you will paste it into the `\describe{}` block in Step 2 between `\item{wtfinl}` and `\item{statefip}`.

- [ ] **Step 2: Append the full documentation block to `R/data.R`**

Open `R/data.R` and append the following block **after the final line** (`"ns_wave1_svy"`). Replace the `[REPWTP_ITEMS]` placeholder with the 160 lines generated in Step 1.

```r

# ============================================================================
# cps_2023
# ============================================================================

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
#' The 160 SDR replicate weight columns (`repwtp1`-`repwtp160`) are the Census
#' Bureau's official substitute for variance estimation; use them to construct a
#' `survey_replicate` design via `surveycore::as_survey_replicate()` when
#' needed. For IPW workflows, construct a plain design from the tibble:
#' ```r
#' data(cps_2023)
#' cps_ref <- surveycore::as_survey(cps_2023, weights = wtfinl)
#' ipw(
#'   ns_wave1, cps_ref,
#'   selection = ~sex + age_f3 + race_f4 + edu_f3 + empstat_f + inc_hh_cat,
#'   missing_method = "omit"
#' )
#' ```
#'
#' @format A data frame with approximately 10,000 rows and 186 columns:
#' \describe{
#'   \item{cpsidp}{Character. IPUMS-CPS person identifier (unique within the
#'     extract).}
#'   \item{serial}{Integer. Household serial number.}
#'   \item{wtfinl}{Numeric. CPS ASEC final person weight, population-scaled
#'     by design (values reflect the U.S. adult civilian non-institutional
#'     population). Use directly for IPW reference construction; no scaling
#'     needed.}
#'   [REPWTP_ITEMS]
#'   \item{statefip}{Integer. State FIPS code (numeric, e.g., 6 = California).}
#'   \item{region}{Integer. Census region: 1 = Northeast, 2 = Midwest,
#'     3 = South, 4 = West.}
#'   \item{metro}{Integer. Metropolitan status: 0 = not identified,
#'     1 = not in metropolitan area, 2 = central city of metropolitan area,
#'     3 = outside central city, 4 = central city status unclear.}
#'   \item{age}{Integer. Age in years (18+ by construction).}
#'   \item{sex}{Factor. Derived from the raw `sex` column (overwritten
#'     in-place): `1` = `"Male"`, `2` = `"Female"`. No `NA` values. Levels:
#'     `c("Male", "Female")`.}
#'   \item{race}{Integer. IPUMS race recode. Key codes: 100 = White,
#'     200 = Black/African American, 300 = American Indian/Alaska Native,
#'     650-652 = Asian or Pacific Islander groups. See `race_f4` for a
#'     derived four-category factor.}
#'   \item{hispan}{Integer. Hispanic origin. 0 = Not Hispanic;
#'     100-412 = Hispanic origins (various national groups);
#'     901-902 = Not applicable/unknown. See `race_f4` for a derived
#'     factor where Hispanic origin takes precedence over `race`.}
#'   \item{educ}{Integer. IPUMS educational attainment recode. Key codes:
#'     0 = N/A or preschool; 1-59 = did not complete high school; 60 = HS
#'     diploma or equivalent; 71-110 = some college or associate's degree;
#'     111-125 = bachelor's degree or higher. See `edu_f3` for a derived
#'     three-category factor.}
#'   \item{marst}{Integer. Marital status: 1 = Married, spouse present;
#'     2 = Married, spouse absent; 3 = Separated; 4 = Divorced;
#'     5 = Widowed; 6 = Never married/single.}
#'   \item{empstat}{Integer. Employment status. Key codes: 1 = Armed Forces;
#'     10 = At work; 12 = Has job, not at work last week; 20-22 = Unemployed;
#'     30-36 = Not in labor force. See `empstat_f` for a derived three-category
#'     factor.}
#'   \item{classwkr}{Integer. Class of worker. Key codes: 0 = N/A;
#'     10 = Self-employed; 20-28 = Private sector; 25 = Nonprofit;
#'     27 = For-profit; 28 = Private (not specified); 29 = Self-employed
#'     (not incorporated); 40-50 = Government; 99 = Unknown.}
#'   \item{wkswork2}{Integer. Weeks worked last year (interval codes):
#'     1 = 1-13 weeks; 2 = 14-26 weeks; 3 = 27-39 weeks; 4 = 40-47 weeks;
#'     5 = 48-49 weeks; 6 = 50-52 weeks. 0 = N/A (did not work).}
#'   \item{uhrsworkly}{Integer. Usual hours worked per week last year.
#'     999 = N/A (did not work or not applicable).}
#'   \item{inctot}{Integer. Total personal income in dollars.
#'     99999999 = N/A or missing.}
#'   \item{hhincome}{Integer. Total household income in dollars.
#'     99999999 = N/A or missing. See `inc_hh_cat` for a derived
#'     five-bracket factor.}
#'   \item{health}{Integer. Self-reported health status: 1 = Excellent;
#'     2 = Very good; 3 = Good; 4 = Fair; 5 = Poor.}
#'   \item{nchild}{Integer. Number of own children in the household
#'     (under age 18).}
#'   \item{famsize}{Integer. Number of persons in the family.}
#'   \item{age_f3}{Factor. Age group derived from `age`:
#'     `cut(age, breaks = c(18, 35, 55, Inf), right = FALSE)`. No `NA`
#'     values (all respondents are 18+). Levels:
#'     `c("18-34", "35-54", "55+")`.}
#'   \item{race_f4}{Factor. Race/ethnicity derived from `race` and `hispan`:
#'     Hispanic origin takes precedence (`hispan` in 100-412); `race == 100`
#'     = `"White"`; `race == 200` = `"Black"`; all other codes (including
#'     Asian/Pacific Islander codes 650-652) = `"Other"`. No `NA` values.
#'     Levels: `c("White", "Black", "Hispanic", "Other")`.}
#'   \item{edu_f3}{Factor. Educational attainment derived from `educ` (IPUMS
#'     recode): codes 1-59 = `"Less than HS"`; codes 60-110 = `"HS/Some
#'     college"` (HS diploma through associate's degree); codes 111-125 =
#'     `"College+"`. Code 0 (N/A/preschool) maps to `NA`. Levels:
#'     `c("Less than HS", "HS/Some college", "College+")`.}
#'   \item{empstat_f}{Factor. Employment status derived from `empstat`: codes
#'     10-12 = `"Employed"` (at work or has job but not at work); codes
#'     20-22 = `"Unemployed"`; all remaining codes (Armed Forces, not in
#'     labor force) = `"Not in labor force"`. No `NA` values. Levels:
#'     `c("Employed", "Unemployed", "Not in labor force")`.}
#'   \item{inc_hh_cat}{Factor. Household income brackets derived from
#'     `hhincome`. Code 99999999 (missing/N/A) maps to `NA`. Levels:
#'     `c("Under $25k", "$25k-$50k", "$50k-$75k", "$75k-$100k", "$100k+")`.
#'     Some `NA` values present.}
#' }
#'
#' @source IPUMS-CPS, 2023 Annual Social and Economic Supplement (March 2023).
#'   Sarah Flood, Miriam King, Renae Rodgers, Steven Ruggles, J. Robert Warren,
#'   Daniel Backman, Annie Chen, Grace Cooper, Stephanie Richards, Megan
#'   Schouweiler, and Michael Westberry. IPUMS CPS: Version 11.0 [dataset].
#'   Minneapolis, MN: IPUMS, 2023. \doi{10.18128/D030.V11.0}
#'   See `data-raw/cps-2023.R` for the construction script.
#' @seealso [ns_wave1], [pew_2016_optin], [npors_2025], [npors_2025_clean],
#'   [gss_2024], [pew_2016_synth_pop]
#' @keywords datasets
"cps_2023"
```

**Important:** Replace `[REPWTP_ITEMS]` with the 160 lines printed by the Step 1 script. The first item is:

```
#'   \item{repwtp1}{Numeric. Successive-difference replicate weight 1. Pass all 160 `repwtp*` columns to `surveycore::as_survey_replicate()` to construct a variance-estimation design.}
```

Items 2–159 follow the pattern:

```
#'   \item{repwtp2}{Numeric. Successive-difference replicate weight 2.}
```

The last item is:

```
#'   \item{repwtp160}{Numeric. Successive-difference replicate weight 160.}
```

- [ ] **Step 3: Count `\item{}` entries to verify 186 total**

```bash
grep -c "\\\\item{" R/data.R
```

The existing count is 604. After appending 186 new items, the new count should be **790**.

- [ ] **Step 4: Commit**

```bash
git add R/data.R
git commit -m "docs(data): add cps_2023 roxygen2 documentation block"
```

---

## Task 4: Run `devtools::document()` and Verify

**Files:**
- Modify (generated): `man/cps_2023.Rd`, `NAMESPACE`

**Interfaces:**
- Consumes: `R/data.R` with appended `cps_2023` block
- Produces: `man/cps_2023.Rd` with all 186 items rendered

- [ ] **Step 1: Run `devtools::document()`**

```r
devtools::document()
```

Expected: no errors, no warnings. Final message: `Documentation complete.`

- [ ] **Step 2: Verify `man/cps_2023.Rd` was created**

```bash
ls man/cps_2023.Rd
```

Expected: file exists.

- [ ] **Step 3: Check that codoc will not flag missing items**

Run `R CMD check` in check-only mode (no data yet — this will warn about missing `cps_2023.rda`, but the codoc check runs against the documentation source, not the data):

```r
devtools::check_man()
```

Expected: 0 errors, 0 warnings. If you see `checking for code/documentation mismatches`, there are missing `\item{}` entries — go back to Task 3 and add the missing ones.

- [ ] **Step 4: Commit generated files**

```bash
git add man/cps_2023.Rd NAMESPACE
git commit -m "docs(data): regenerate Rd after adding cps_2023 documentation"
```

---

## Task 5: Download Raw Data and Run Processing Script

**This task requires a free IPUMS-CPS account and a manual data download. The previous tasks can be completed without the data.**

**Files:**
- User-creates: `data-raw/cps_2023/cps_2023.csv` (gitignored)
- Generated: `data/cps_2023.rda` (committed)

**Interfaces:**
- Consumes: `data-raw/cps_2023/cps_2023.csv` (IPUMS extract)
- Produces: `data/cps_2023.rda` (~10,000 rows, 186 columns)

### 5a: Download the IPUMS Extract

- [ ] **Step 1: Register and create an IPUMS-CPS extract**

1. Register at https://cps.ipums.org/cps/ (free).
2. Create a new extract with these settings:
   - **Sample:** CPS ASEC 2023 (March 2023 supplement)
   - **File format:** CSV
   - **Enable replicate weights** (adds REPWTP indicator + REPWTP1–REPWTP160)
3. Select these variables (see `plans/cps-2023-dataset.md` Section II for the full table):
   - **Household:** SERIAL, HHINCOME, FAMSIZE, NCHILD, HHTYPE
   - **Person:** CPSIDP, ASECFLAG, WTFINL, REPWTP, REPWTP1–REPWTP160, AGE, SEX, RACE, HISPAN, EDUC, EMPSTAT, CLASSWKR, WKSWORK2, UHRSWORKLY, INCTOT, MARST, HEALTH, REGION, METRO, STATEFIP
4. Submit the extract and download the CSV.

- [ ] **Step 2: Place the file**

```bash
mkdir -p data-raw/cps_2023
# Move the downloaded CSV to:
# data-raw/cps_2023/cps_2023.csv
ls data-raw/cps_2023/cps_2023.csv
```

Expected: file present, size likely 100MB+.

### 5b: Run the Script

- [ ] **Step 3: Source the processing script**

```r
source("data-raw/cps-2023.R")
```

Expected terminal output (approximate):
```
Saved cps_2023 (10017 rows x 186 cols)
✔ Saving 'cps_2023' to 'data/cps_2023.rda'
```

If any `stopifnot()` assertion fails, see the diagnosis guide below.

**Diagnosis guide for assertion failures:**

| Failure | Likely cause | Fix |
|---------|-------------|-----|
| `length(rep_cols) == 160L` fails | Replicate weights not requested in IPUMS extract | Re-download with replicate weights enabled |
| `ncol(cps_2023) == 186L` | Wrong number of columns selected | Check `length(keep_cols)`: should be 21 + 160 = 181; after 5 derived = 186 |
| `nrow(cps_2023)` out of range | `asecflag` or `age` filter behaves differently | Check `table(raw$asecflag)` before filtering |
| `mean(is.na(cps_2023$edu_f3)) < 0.01` | Many `educ == 0` rows passed the ASEC filter | Inspect `table(cps_2023$educ[cps_2023$educ == 0])` |
| `sum(is.na(cps_2023$sex)) == 0L` | Unexpected sex codes | Inspect `table(cps_2023$sex, useNA = "always")` |

- [ ] **Step 4: Spot-check the result**

```r
data(cps_2023)
dim(cps_2023)                          # ~10,000 x 186
sum(cps_2023$wtfinl)                   # must be > 5e6 (population-scaled)
table(cps_2023$sex)                    # Male/Female, no NA
table(cps_2023$age_f3)                 # three non-empty levels
table(cps_2023$race_f4)                # four non-empty levels
table(cps_2023$edu_f3, useNA = "always")  # three levels + tiny NA count
table(cps_2023$empstat_f)              # three non-empty levels
table(cps_2023$inc_hh_cat, useNA = "always")  # five levels + some NAs
```

- [ ] **Step 5: Commit the data file**

```bash
git add data/cps_2023.rda
git commit -m "feat(data): add cps_2023 bundled dataset (CPS ASEC 2023, ~10k rows)"
```

---

## Task 6: Final Verification and R CMD Check

**Files:**
- No new files; verifies the complete state of the branch

- [ ] **Step 1: Run `devtools::check()`**

```r
devtools::check()
```

Expected: 0 errors, 0 warnings, ≤2 notes (pre-approved: "no visible binding" and "CRAN incoming feasibility").

If you see `checking for code/documentation mismatches ... WARNING`:
- Run `names(cps_2023)` in R to get the actual column list
- Compare against `grep("\\\\item{", readLines("R/data.R"), value = TRUE)` restricted to the cps_2023 block
- Add any missing `\item{}` entries, re-run `devtools::document()`, re-commit

- [ ] **Step 2: Verify the IPW example runs interactively**

```r
library(surveywts)
data(cps_2023)
data(ns_wave1)

cps_ref <- surveycore::as_survey(cps_2023, weights = wtfinl)
result <- ipw(
  ns_wave1,
  cps_ref,
  selection = ~sex + age_f3 + race_f4 + edu_f3 + empstat_f + inc_hh_cat,
  missing_method = "omit"
)
summarize_weights(result)
```

Expected: no errors; `summarize_weights()` prints a weight summary table.

- [ ] **Step 3: Check the weight sum sanity gate**

```r
sum(cps_2023$wtfinl)   # confirm > 5e6
```

If greater than 5e6, record the actual value and update `plans/cps-2023-dataset.md` quality gate with the tightened range.

- [ ] **Step 4: Open the PR**

Use `/commit-and-pr` or run manually:

```bash
git push -u origin feature/cps-2023-dataset
```

Then open a PR against `develop` with title:
```
feat(data): add cps_2023 national probability reference dataset
```

PR checklist:
- [ ] `data/cps_2023.rda` saved
- [ ] `devtools::document()` run — `man/cps_2023.Rd` generated
- [ ] `R CMD check`: 0 errors, 0 warnings
- [ ] `codoc` passes (all 186 columns have `\item{}`)
- [ ] `data(cps_2023)` loads without error
- [ ] IPW workflow example runs interactively without error
- [ ] `nrow(cps_2023)` between 9,000 and 11,000
- [ ] `sum(cps_2023$wtfinl) > 5e6`

---

## Self-Review

**Spec coverage:**

| Spec section | Task covering it |
|---|---|
| §I Objects produced: `cps_2023` tibble, no `_svy` companion | Task 2 (script) + spec constraint (out of scope) |
| §I No PSU/stratum variables — design note in docs | Task 3 (documented in `@description`) |
| §II Download instructions | Task 5a |
| §III Row selection (asecflag, age, wtfinl, stratified sample, seed 42) | Task 2 |
| §III `rep_cols` selection pattern `^repwtp[0-9]` | Task 2 |
| §III All 21 original columns retained | Task 2 |
| §III All 5 derived columns (sex overwrite, age_f3, race_f4, edu_f3, empstat_f, inc_hh_cat) | Task 2 |
| §III `ncol(cps_2023) == 186L` assertion | Task 2 |
| §IV Full `data-raw/cps-2023.R` script | Task 2 |
| §V Man page header + `@description` | Task 3 |
| §V All 186 `\item{}` entries in single `\describe{}` block | Task 3 |
| §V `@source` with IPUMS citation and DOI | Task 3 |
| §V `@seealso` | Task 3 |
| §VI Quality gates | Task 5b + Task 6 |
| §I Companion PR (remove `_svy` datasets) | **Out of scope — separate PR** |

**Placeholder scan:** No TBD, no "implement later", no "handle edge cases" without specifics. The `[REPWTP_ITEMS]` placeholder in Task 3 Step 2 has explicit generation code (Step 1) and explicit first/middle/last examples — it is not a deferred placeholder.

**Type consistency:** `rep_cols` grep pattern (`^repwtp[0-9]`) is used identically in the script and described identically in the plan. `ncol == 186L` arithmetic is verified: 21 original + 160 replicate + 5 derived = 186.
