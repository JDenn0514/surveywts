## data-raw/pew-2016-synth-pop.R
##
## Produces:
##   pew_2016_synth_pop     — 20,000-row ATP-derived synthetic population, 43 variables
##   pew_2016_synth_pop_svy — survey_taylor companion (equal weights, SRS)
##
## Source: Pew Research Center (used in Mercer, Lau & Kennedy 2018
##         "For Weighting Online Opt-In Samples, What Matters Most?")
## License: Academic / non-commercial use per Pew Research Center terms.
##
## The raw .sav file is excluded from version control (see .gitignore).
## It must be placed at: data-raw/pew_2016/pew_2016_synth_pop.sav
##
## Run from the package root: source("data-raw/pew-2016-synth-pop.R")

library(haven)
library(janitor)
library(surveycore)

POP_FILE <- file.path(
  here::here(),
  "data-raw",
  "pew_2016",
  "pew_2016_synth_pop.sav"
)

if (!file.exists(POP_FILE)) {
  stop(
    "Raw file not found: ",
    POP_FILE,
    "\n",
    "Place the SAV file in data-raw/pew_2016/ and re-run.\n",
    "Source: Pew Research Center (contact prc.info@pewresearch.org)"
  )
}

## ---- 1. Read ----

message("Reading pew_2016_synth_pop.sav (~9 MB)...")
pop_raw <- read_spss(POP_FILE)
message("Read ", nrow(pop_raw), " rows x ", ncol(pop_raw), " cols")

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

pew_2016_synth_pop <- as_plain(as.data.frame(pop_raw))
rownames(pew_2016_synth_pop) <- NULL

## ---- 3. Standardise column names to snake_case ----

pew_2016_synth_pop <- clean_names(pew_2016_synth_pop)

## ---- 4. Recode binary benchmark variables to 0/1 ----
##
## In the raw synth_pop SPSS file, registered and vote14 carry the negative
## response as 1 (1 = No / 1 = Did not vote). The yes_code arguments below
## handle this reversal so both datasets end up on the same 0/1 scale.

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

synth_specs <- list(
  registered = list(yes = 2L, yes_label = "Yes", no_label = "No"),
  vote14 = list(yes = 2L, yes_label = "Voted", no_label = "Did not vote"),
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

for (v in names(synth_specs)) {
  s <- synth_specs[[v]]
  pew_2016_synth_pop[[v]] <- make_binary(
    pew_2016_synth_pop[[v]],
    yes_code = s$yes,
    refused_codes = integer(0),
    yes_label = s$yes_label,
    no_label = s$no_label
  )
}

## ---- 4b. Harmonized demographic factor columns ----
##
## Standard columns shared across all surveywts datasets.
## synth_pop has no Refused codes, so no NA values expected.

race_f4_levels <- c("White", "Black", "Hispanic", "Other")
edu_f3_levels  <- c("Less than HS", "HS/Some college", "College+")
pid_f3_levels  <- c("Republican", "Independent", "Democrat")
age_f3_labs    <- c("18-34", "35-54", "55+")

# sex: gender 1=Male, 2=Female (no Refused in synth_pop)
pew_2016_synth_pop$sex <- factor(
  dplyr::recode_values(
    pew_2016_synth_pop$gender,
    1 ~ "Male",
    2 ~ "Female",
    default = NA_character_
  ),
  levels = c("Male", "Female")
)

# race_f4: racethn 1=White, 2=Black, 3=Hispanic, 4=Asian, 5=Other
#   Asian (4) collapsed into Other for 4-level consistency
pew_2016_synth_pop$race_f4 <- factor(
  dplyr::recode_values(
    pew_2016_synth_pop$racethn,
    1        ~ "White",
    2        ~ "Black",
    3        ~ "Hispanic",
    c(4, 5)  ~ "Other",
    default = NA_character_
  ),
  levels = race_f4_levels
)

# edu_f3: educcat5 1=<HS, 2=HS, 3=Some college, 4=College, 5=Postgrad
pew_2016_synth_pop$edu_f3 <- factor(
  dplyr::recode_values(
    pew_2016_synth_pop$educcat5,
    1        ~ "Less than HS",
    c(2, 3)  ~ "HS/Some college",
    c(4, 5)  ~ "College+",
    default = NA_character_
  ),
  levels = edu_f3_levels
)

# pid_f3: partyscale5 1=Rep, 2=Lean Rep, 3=Ind, 4=Lean Dem, 5=Dem
pew_2016_synth_pop$pid_f3 <- factor(
  dplyr::recode_values(
    pew_2016_synth_pop$partyscale5,
    c(1, 2)  ~ "Republican",
    3        ~ "Independent",
    c(4, 5)  ~ "Democrat",
    default = NA_character_
  ),
  levels = pid_f3_levels
)

# age_f3: from continuous age (85 is ACS top-code; falls into 55+ bucket correctly)
pew_2016_synth_pop$age_f3 <- cut(
  pew_2016_synth_pop$age,
  breaks = c(18, 35, 55, Inf),
  labels = age_f3_labs,
  right = FALSE
)

# Structural assertions
stopifnot(ncol(pew_2016_synth_pop) == 43L)
stopifnot(nrow(pew_2016_synth_pop) == 20000L)
stopifnot(is.factor(pew_2016_synth_pop$sex))
stopifnot(is.factor(pew_2016_synth_pop$race_f4))
stopifnot(is.factor(pew_2016_synth_pop$edu_f3))
stopifnot(is.factor(pew_2016_synth_pop$pid_f3))
stopifnot(is.factor(pew_2016_synth_pop$age_f3))
stopifnot(sum(is.na(pew_2016_synth_pop$sex)) == 0L)
stopifnot(sum(is.na(pew_2016_synth_pop$race_f4)) == 0L)
stopifnot(sum(is.na(pew_2016_synth_pop$edu_f3)) == 0L)
stopifnot(sum(is.na(pew_2016_synth_pop$pid_f3)) == 0L)
stopifnot(sum(is.na(pew_2016_synth_pop$age_f3)) == 0L)

## ---- 5. Save ----

usethis::use_data(pew_2016_synth_pop, overwrite = TRUE)
message(
  "Saved pew_2016_synth_pop: ",
  nrow(pew_2016_synth_pop),
  " rows x ",
  ncol(pew_2016_synth_pop),
  " cols"
)

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
