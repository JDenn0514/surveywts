## data-raw/pew-2016-optin.R
##
## Produces:
##   pew_2016_optin — 2,000 opt-in respondents (3 vendors), 305 variables:
##                    104 original SPSS columns + calibrated weight + 200
##                    quasi-randomization bootstrap replicate weights.
##
## Source: Pew Research Center (used in Mercer, Lau & Kennedy 2018
##         "For Weighting Online Opt-In Samples, What Matters Most?")
## License: Academic / non-commercial use per Pew Research Center terms.
##
## Calibration: 7 marginal dimensions (sex, race_f4, edu_f3, pid_f3, age_f3,
##   division, ideo3). Targets computed from pew_2016_synth_pop
##   (unweighted proportions). Refused codes -> NA; NR algorithm;
##   5th/95th percentile trim.
##
## NOTE: pew_2016_synth_pop must be saved to data/ before running this script.
##   Run data-raw/pew-2016-synth-pop.R first.
##
## The raw .sav file is excluded from version control (see .gitignore).
## It must be placed at: data-raw/pew_2016/pew_2016_optin.sav
##
## Run from the package root: source("data-raw/pew-2016-optin.R")

library(haven)
library(janitor)
library(surveycore)
pkgload::load_all(quiet = TRUE)

OPTIN_FILE <- file.path(
  here::here(),
  "data-raw",
  "pew_2016",
  "pew_2016_optin.sav"
)

if (!file.exists(OPTIN_FILE)) {
  stop(
    "Raw file not found: ",
    OPTIN_FILE,
    "\n",
    "Place the SAV file in data-raw/pew_2016/ and re-run.\n",
    "Source: Pew Research Center (contact prc.info@pewresearch.org)"
  )
}

## ---- 1. Read ----

message("Reading pew_2016_optin.sav (~28 MB)...")
optin_raw <- read_spss(OPTIN_FILE)
message("Read ", nrow(optin_raw), " rows x ", ncol(optin_raw), " cols")

## ---- 2. Strip haven class, preserve label/labels attributes ----
##
## Converts haven_labelled vectors to plain R numeric/character vectors while
## retaining the SPSS variable label (attr "label") and value label map
## (attr "labels") on each column.

as_plain <- function(df) {
  df[] <- lapply(df, function(x) {
    if (!inherits(x, "haven_labelled")) {
      return(x)
    }
    raw <- as.vector(x)
    lbl <- attr(x, "label", exact = TRUE)
    lbvl <- attr(x, "labels", exact = TRUE)
    if (!is.null(lbl)) {
      attr(raw, "label") <- lbl
    }
    if (!is.null(lbvl)) {
      attr(raw, "labels") <- lbvl
    }
    raw
  })
  df
}

pew_2016_optin <- as_plain(as.data.frame(optin_raw))
rownames(pew_2016_optin) <- NULL

## ---- 3. Standardise column names to snake_case ----

pew_2016_optin <- clean_names(pew_2016_optin)

## ---- 4. Recode binary benchmark variables to 0/1 ----
##
## All yes/no benchmark variables are converted to integer 0/1:
##   1 = positive response (Yes, Voted, Volunteered, etc.)
##   0 = negative response (No, Did not vote, etc.)
##   NA = Refused (optin only)

make_binary <- function(
  x,
  yes_code,
  refused_codes = integer(0),
  yes_label = "Yes",
  no_label = "No"
) {
  lbl <- attr(x, "label", exact = TRUE)
  out <- ifelse(
    x == yes_code,
    1L,
    ifelse(x %in% refused_codes, NA_integer_, 0L)
  )
  attr(out, "label") <- lbl
  attr(out, "labels") <- c(0L, 1L)
  names(attr(out, "labels")) <- c(no_label, yes_label)
  out
}

optin_specs <- list(
  registered = list(yes = 1L, yes_label = "Yes", no_label = "No"),
  vote14 = list(yes = 1L, yes_label = "Voted", no_label = "Did not vote"),
  comgrp_cps = list(yes = 1L, yes_label = "Yes", no_label = "No"),
  pub_off_cps = list(yes = 1L, yes_label = "Yes", no_label = "No"),
  volsum = list(
    yes = 1L,
    yes_label = "Volunteered",
    no_label = "Did not volunteer"
  ),
  tablet_cps = list(yes = 1L, yes_label = "Yes", no_label = "No"),
  textim_cps = list(yes = 1L, yes_label = "Yes", no_label = "No"),
  social_cps = list(yes = 1L, yes_label = "Yes", no_label = "No"),
  fdstmp_cps = list(yes = 1L, yes_label = "Yes", no_label = "No"),
  owngun_gss = list(yes = 1L, yes_label = "Yes", no_label = "No")
)

for (v in names(optin_specs)) {
  s <- optin_specs[[v]]
  pew_2016_optin[[v]] <- make_binary(
    pew_2016_optin[[v]],
    yes_code = s$yes,
    refused_codes = 3L,
    yes_label = s$yes_label,
    no_label = s$no_label
  )
}

## ---- 4b. Harmonized demographic factor columns ----

race_f4_levels <- c("White", "Black", "Hispanic", "Other")
edu_f3_levels <- c("Less than HS", "HS/Some college", "College+")
pid_f3_levels <- c("Republican", "Independent", "Democrat")
age_f3_labs <- c("18-34", "35-54", "55+")

# sex: gender 1=Male, 2=Female; 3=Refused -> NA
pew_2016_optin$sex <- factor(
  dplyr::recode_values(
    pew_2016_optin$gender,
    1 ~ "Male",
    2 ~ "Female",
    default = NA_character_
  ),
  levels = c("Male", "Female")
)

# race_f4: racethn 1=White, 2=Black, 3=Hispanic, 4=Asian, 5=Other, 6=Refused->NA
#   Asian (4) collapsed into Other for 4-level consistency
pew_2016_optin$race_f4 <- factor(
  dplyr::recode_values(
    pew_2016_optin$racethn,
    1 ~ "White",
    2 ~ "Black",
    3 ~ "Hispanic",
    c(4, 5) ~ "Other",
    default = NA_character_
  ),
  levels = race_f4_levels
)

# edu_f3: educcat5 1=<HS, 2=HS, 3=Some college, 4=College, 5=Postgrad, 6=Refused->NA
pew_2016_optin$edu_f3 <- factor(
  dplyr::recode_values(
    pew_2016_optin$educcat5,
    1 ~ "Less than HS",
    c(2, 3) ~ "HS/Some college",
    c(4, 5) ~ "College+",
    default = NA_character_
  ),
  levels = edu_f3_levels
)

# pid_f3: partyscale3 (GSS-style 3-category party preference: 1=Republican,
#   2=Democrat, 3=Independent/Other/Ref). Note: optin also has partysum
#   (3-cat recode of partyscale5), but partyscale3 was chosen because it
#   uses the same question wording as synth_pop's pid_f3 calibration margin.
#   Refused codes (78 rows) are absorbed into category 3 -> "Independent".
pew_2016_optin$pid_f3 <- factor(
  dplyr::recode_values(
    pew_2016_optin$partyscale3,
    1 ~ "Republican",
    2 ~ "Democrat",
    3 ~ "Independent",
    default = NA_character_
  ),
  levels = pid_f3_levels
)

# age_f3: agecat6 1-2=18-24/25-34, 3-4=35-44/45-54, 5-6=55-64/65+
#   104 rows have NA from raw age being NA; these propagate
pew_2016_optin$age_f3 <- factor(
  dplyr::recode_values(
    pew_2016_optin$agecat6,
    c(1, 2) ~ "18-34",
    c(3, 4) ~ "35-54",
    c(5, 6) ~ "55+",
    default = NA_character_
  ),
  levels = age_f3_labs
)

# Structural assertions
stopifnot(ncol(pew_2016_optin) == 104L)
stopifnot(nrow(pew_2016_optin) == 31863L)
stopifnot(is.factor(pew_2016_optin$sex))
stopifnot(is.factor(pew_2016_optin$race_f4))
stopifnot(is.factor(pew_2016_optin$edu_f3))
stopifnot(is.factor(pew_2016_optin$pid_f3))
stopifnot(is.factor(pew_2016_optin$age_f3))
stopifnot(sum(is.na(pew_2016_optin$pid_f3)) == 0L)


## ---- 5. Load reference population for calibration targets ----

load("data/pew_2016_synth_pop.rda")

## ---- 6. Build calibration variables and targets ----
##
## 7 margins: sex, race_f4, edu_f3, pid_f3, age_f3 (from permanent columns),
##   plus division (9-level) and ideo3 (3-level) built inline.
## Targets are unweighted proportions from pew_2016_synth_pop.
## Refused codes in optin become NA — excluded from each margin automatically.

optin_for_svy <- pew_2016_optin

# division and ideo3 have no harmonized column; build factor inline
optin_for_svy$cal_division <- factor(
  optin_for_svy$division,
  levels = 1L:9L,
  labels = c(
    "E. North Central",
    "E. South Central",
    "Middle Atlantic",
    "Mountain",
    "New England",
    "Pacific",
    "South Atlantic",
    "W. North Central",
    "W. South Central"
  )
)

# ideo3: 1=Liberal, 2=Moderate, 3=Conservative; 4=Refused -> NA
optin_for_svy$cal_ideo3 <- factor(
  optin_for_svy$ideo3,
  levels = 1L:3L,
  labels = c("Liberal", "Moderate", "Conservative")
)

# Drop rows with NA in any calibration variable (Refused codes) so
# calibrate_rake() receives complete cases on all 7 margins.
.cal_vars <- c(
  "sex",
  "race_f4",
  "edu_f3",
  "pid_f3",
  "age_f3",
  "cal_division",
  "cal_ideo3"
)
optin_for_svy <- optin_for_svy[
  stats::complete.cases(optin_for_svy[.cal_vars]),
]
message(
  "Calibration subsample: ",
  nrow(optin_for_svy),
  " of 31,863 rows (complete cases on all 7 margins)"
)

n_dropped <- nrow(pew_2016_optin) - nrow(optin_for_svy)
stopifnot(n_dropped < 1000L)

optin_for_svy$weight <- 1L

## ---- 7. Compute calibration targets from synth_pop permanent columns ----

.div_lvls <- c(
  "E. North Central",
  "E. South Central",
  "Middle Atlantic",
  "Mountain",
  "New England",
  "Pacific",
  "South Atlantic",
  "W. North Central",
  "W. South Central"
)
.ideo3_lvls <- c("Liberal", "Moderate", "Conservative")

synth_division <- factor(
  pew_2016_synth_pop$division,
  levels = 1L:9L,
  labels = .div_lvls
)
synth_ideo3 <- factor(
  pew_2016_synth_pop$ideo3,
  levels = 1L:3L,
  labels = .ideo3_lvls
)

.pew_targets <- list(
  sex = c(prop.table(table(pew_2016_synth_pop$sex))),
  race_f4 = c(prop.table(table(pew_2016_synth_pop$race_f4))),
  edu_f3 = c(prop.table(table(pew_2016_synth_pop$edu_f3))),
  pid_f3 = c(prop.table(table(pew_2016_synth_pop$pid_f3))),
  age_f3 = c(prop.table(table(pew_2016_synth_pop$age_f3))),
  cal_division = c(prop.table(table(synth_division))),
  cal_ideo3 = c(prop.table(table(synth_ideo3)))
)


## ---- 8. Keep only 2000 random respondents ----

# Sample within optin_for_svy (complete-case subset of pew_2016_optin).
# Track which rows we picked so we can subset the original 104-col
# pew_2016_optin to exactly the same respondents — without accidentally
# inheriting the extra cal columns (cal_division, cal_ideo3, weight)
# that optin_for_svy carries.
set.seed(42)
sampled_rows <- sample(nrow(optin_for_svy), 2000)
optin_for_svy <- optin_for_svy[sampled_rows, ]
# optin_for_svy rownames are preserved original row indices from pew_2016_optin
# (rownames were "1".."31863" after section 2's rownames(pew_2016_optin) <- NULL).
original_rows <- as.integer(rownames(optin_for_svy))
# Subset the original 104-col pew_2016_optin to the same respondents.
# Do NOT use optin_for_svy here — it has extra cal columns.
pew_2016_optin <- pew_2016_optin[original_rows, ]
rownames(pew_2016_optin) <- NULL

## ---- 9. Build survey_nonprob ----

pew_2016_optin_svy <- surveycore::as_survey_nonprob(
  optin_for_svy,
  weights = weight
)

## ---- 10. Rake to synth_pop targets (NR algorithm; 5th/95th percentile trim) ----

pew_2016_optin_svy <- calibrate_rake(
  pew_2016_optin_svy,
  targets = .pew_targets,
  weights = weight,
  wt_name = "weight",
  type = "prop",
  algorithm = "nr"
)

pew_2016_optin_svy <- trim_weights(
  pew_2016_optin_svy,
  weights = weight,
  lower = 0.05,
  upper = 0.95,
  type = "percentile",
  wt_name = "weight"
)

## ---- 11. Quasi-randomization bootstrap (200 replicates) ----

pew_2016_optin_svy <- create_bootstrap_weights(
  pew_2016_optin_svy,
  type = "quasi-randomization"
)

## ---- 12. Promote calibrated weight and replicate weights into tibble ----

# pew_2016_optin is the 104-col tibble (104 original SPSS columns with
# derived demographic factors). Bind in the calibrated weight + 200 repwts.
pew_2016_optin$weight <- pew_2016_optin_svy@data$weight
repwt_cols <- pew_2016_optin_svy@variables$repweights # "repwt_1" ... "repwt_200"
pew_2016_optin[repwt_cols] <- pew_2016_optin_svy@data[repwt_cols]

# Add "label" attributes to derived factor columns
attr(pew_2016_optin$sex, "label") <- "Sex (factor, derived from gender: 1=Male, 2=Female)"
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

## ---- 13. Remove intermediate objects ----

rm(
  .cal_vars,
  .pew_targets,
  .div_lvls,
  .ideo3_lvls,
  optin_for_svy,
  pew_2016_optin_svy,
  synth_division,
  synth_ideo3,
  original_rows,
  repwt_cols,
  race_acs_cols,
  race_preface,
  col,
  sampled_rows,
  n_dropped
)

## ---- 14. Save data ----

usethis::use_data(pew_2016_optin, overwrite = TRUE)
message(
  "Saved pew_2016_optin ",
  "(2000 rows x 305 cols; calibrated weight + 200 bootstrap repwts)"
)
