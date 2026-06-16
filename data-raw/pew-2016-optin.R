## data-raw/pew-2016-optin.R
##
## Produces:
##   pew_2016_optin     — 31,863 opt-in respondents (3 vendors), 99 variables
##   pew_2016_optin_svy — survey_nonprob raked to pew_2016_synth_pop targets
##                        + 200 quasi-randomization bootstrap replicate weights
##
## Source: Pew Research Center (used in Mercer, Lau & Kennedy 2018
##         "For Weighting Online Opt-In Samples, What Matters Most?")
## License: Academic / non-commercial use per Pew Research Center terms.
##
## Calibration: 7 marginal dimensions (gender, agecat6, racethn, educcat5,
##   division, partyscale5, ideo3). Targets computed from pew_2016_synth_pop
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
  here::here(), "data-raw", "pew_2016",
  "pew_2016_optin.sav"
)

if (!file.exists(OPTIN_FILE)) {
  stop(
    "Raw file not found: ", OPTIN_FILE, "\n",
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
    if (!inherits(x, "haven_labelled")) return(x)
    raw  <- as.vector(x)
    lbl  <- attr(x, "label",  exact = TRUE)
    lbvl <- attr(x, "labels", exact = TRUE)
    if (!is.null(lbl))  attr(raw, "label")  <- lbl
    if (!is.null(lbvl)) attr(raw, "labels") <- lbvl
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

make_binary <- function(x, yes_code, refused_codes = integer(0),
                        yes_label = "Yes", no_label = "No") {
  lbl <- attr(x, "label", exact = TRUE)
  out <- ifelse(x == yes_code, 1L,
                ifelse(x %in% refused_codes, NA_integer_, 0L))
  attr(out, "label")  <- lbl
  attr(out, "labels") <- c(0L, 1L)
  names(attr(out, "labels")) <- c(no_label, yes_label)
  out
}

optin_specs <- list(
  registered  = list(yes = 1L, yes_label = "Yes",           no_label = "No"),
  vote14      = list(yes = 1L, yes_label = "Voted",         no_label = "Did not vote"),
  comgrp_cps  = list(yes = 1L, yes_label = "Yes",           no_label = "No"),
  pub_off_cps = list(yes = 1L, yes_label = "Yes",           no_label = "No"),
  volsum      = list(yes = 1L, yes_label = "Volunteered",   no_label = "Did not volunteer"),
  tablet_cps  = list(yes = 1L, yes_label = "Yes",           no_label = "No"),
  textim_cps  = list(yes = 1L, yes_label = "Yes",           no_label = "No"),
  social_cps  = list(yes = 1L, yes_label = "Yes",           no_label = "No"),
  fdstmp_cps  = list(yes = 1L, yes_label = "Yes",           no_label = "No"),
  owngun_gss  = list(yes = 1L, yes_label = "Yes",           no_label = "No")
)

for (v in names(optin_specs)) {
  s <- optin_specs[[v]]
  pew_2016_optin[[v]] <- make_binary(
    pew_2016_optin[[v]],
    yes_code = s$yes, refused_codes = 3L,
    yes_label = s$yes_label, no_label = s$no_label
  )
}

## ---- 5. Save pew_2016_optin tibble (no weight column) ----

usethis::use_data(pew_2016_optin, overwrite = TRUE)
message(
  "Saved pew_2016_optin: ",
  nrow(pew_2016_optin), " rows x ", ncol(pew_2016_optin), " cols"
)

## ---- 6. Load reference population for calibration targets ----

load("data/pew_2016_synth_pop.rda")

## ---- 7. Build calibration factor variables ----
##
## 7 margins: gender, agecat6, racethn, educcat5, division, partyscale5, ideo3.
## Refused codes in optin become NA (excluded from each margin automatically).
## Targets are unweighted proportions from pew_2016_synth_pop.

# Shared factor labels (same in optin and synth_pop)
.gender_lvls   <- c("Male", "Female")
.agecat6_lvls  <- c("18-24", "25-34", "35-44", "45-54", "55-64", "65+")
.racethn_lvls  <- c("White non-Hisp", "Black non-Hisp", "Hispanic", "Asian", "Other")
.educ5_lvls    <- c("Less than HS", "HS Grad", "Some college", "College grad", "Postgraduate")
.div_lvls      <- c(
  "E. North Central", "E. South Central", "Middle Atlantic",
  "Mountain", "New England", "Pacific",
  "South Atlantic", "W. North Central", "W. South Central"
)
.party5_lvls   <- c("Republican", "Lean Republican", "Ind/No Lean", "Lean Democrat", "Democrat")
.ideo3_lvls    <- c("Liberal", "Moderate", "Conservative")

# Build optin_for_svy with factor calibration cols + equal starting weight
optin_for_svy <- pew_2016_optin

# gender: 1=Male, 2=Female; 3=Refused -> NA
optin_for_svy$cal_gender <- factor(
  optin_for_svy$gender,
  levels = c(1L, 2L),
  labels = .gender_lvls
)

# agecat6: 1=18-24 ... 6=65+; values outside 1-6 -> NA
optin_for_svy$cal_agecat6 <- factor(
  optin_for_svy$agecat6,
  levels = 1L:6L,
  labels = .agecat6_lvls
)

# racethn: 1-5 categories; 6=Refused -> NA
optin_for_svy$cal_racethn <- factor(
  optin_for_svy$racethn,
  levels = 1L:5L,
  labels = .racethn_lvls
)

# educcat5: 1-5 categories; 6=Refused -> NA
optin_for_svy$cal_educcat5 <- factor(
  optin_for_svy$educcat5,
  levels = 1L:5L,
  labels = .educ5_lvls
)

# division: 1-9 (alphabetical coding); no Refused expected
optin_for_svy$cal_division <- factor(
  optin_for_svy$division,
  levels = 1L:9L,
  labels = .div_lvls
)

# partyscale5: 1-5; no Refused expected
optin_for_svy$cal_partyscale5 <- factor(
  optin_for_svy$partyscale5,
  levels = 1L:5L,
  labels = .party5_lvls
)

# ideo3: 1=Liberal, 2=Moderate, 3=Conservative; 4=Refused -> NA
optin_for_svy$cal_ideo3 <- factor(
  optin_for_svy$ideo3,
  levels = 1L:3L,
  labels = .ideo3_lvls
)

# Initial weight: equal weight used only during svy construction
optin_for_svy$weight <- 1L

## ---- 8. Compute calibration targets from synth_pop ----
##
## agecat6 is derived from continuous age using the same 6-group breaks as
## the agecat6 column in pew_2016_optin (1=18-24, 2=25-34, ..., 6=65+).

synth_gender <- factor(
  pew_2016_synth_pop$gender,
  levels = c(1L, 2L),
  labels = .gender_lvls
)

synth_agecat6 <- cut(
  pew_2016_synth_pop$age,
  breaks = c(18, 25, 35, 45, 55, 65, Inf),
  labels = .agecat6_lvls,
  right  = FALSE
)

synth_racethn <- factor(
  pew_2016_synth_pop$racethn,
  levels = 1L:5L,
  labels = .racethn_lvls
)

synth_educcat5 <- factor(
  pew_2016_synth_pop$educcat5,
  levels = 1L:5L,
  labels = .educ5_lvls
)

synth_division <- factor(
  pew_2016_synth_pop$division,
  levels = 1L:9L,
  labels = .div_lvls
)

synth_party5 <- factor(
  pew_2016_synth_pop$partyscale5,
  levels = 1L:5L,
  labels = .party5_lvls
)

synth_ideo3 <- factor(
  pew_2016_synth_pop$ideo3,
  levels = 1L:3L,
  labels = .ideo3_lvls
)

.pew_targets <- list(
  cal_gender      = c(prop.table(table(synth_gender))),
  cal_agecat6     = c(prop.table(table(synth_agecat6))),
  cal_racethn     = c(prop.table(table(synth_racethn))),
  cal_educcat5    = c(prop.table(table(synth_educcat5))),
  cal_division    = c(prop.table(table(synth_division))),
  cal_partyscale5 = c(prop.table(table(synth_party5))),
  cal_ideo3       = c(prop.table(table(synth_ideo3)))
)

## ---- 9. Build survey_nonprob ----

pew_2016_optin_svy <- surveycore::as_survey_nonprob(
  optin_for_svy,
  weights = weight
)

## ---- 10. Rake to synth_pop targets (NR algorithm; 5th/95th percentile trim) ----

pew_2016_optin_svy <- calibrate_rake(
  pew_2016_optin_svy,
  targets   = .pew_targets,
  weights   = weight,
  wt_name   = "weight",
  type      = "prop",
  algorithm = "nr"
)

pew_2016_optin_svy <- trim_weights(
  pew_2016_optin_svy,
  weights = weight,
  lower   = 0.05,
  upper   = 0.95,
  type    = "percentile",
  wt_name = "weight"
)

## ---- 11. Quasi-randomization bootstrap (200 replicates) ----

pew_2016_optin_svy <- create_bootstrap_weights(
  pew_2016_optin_svy,
  type = "quasi-randomization",
  seed = 2016L
)

rm(.pew_targets, .gender_lvls, .agecat6_lvls, .racethn_lvls, .educ5_lvls,
   .div_lvls, .party5_lvls, .ideo3_lvls, optin_for_svy,
   synth_gender, synth_agecat6, synth_racethn, synth_educcat5,
   synth_division, synth_party5, synth_ideo3)

usethis::use_data(pew_2016_optin_svy, overwrite = TRUE)
message(
  "Saved pew_2016_optin_svy ",
  "(raked to synth_pop targets + 200 bootstrap replicate weights)"
)
