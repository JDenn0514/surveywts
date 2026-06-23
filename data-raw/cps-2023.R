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
