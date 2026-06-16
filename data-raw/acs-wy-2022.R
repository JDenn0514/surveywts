## data-raw/acs-wy-2022.R
##
## Produces:
##   acs_wy_2022     — surveycore::acs_pums_wy adults with derived cols
##   acs_wy_2022_svy — survey_replicate companion (SDR, mse = TRUE)
##
## Run from the package root: source("data-raw/acs-wy-2022.R")

library(surveycore)
library(dplyr)

age_bins <- c(18, 35, 55, Inf)
age_labs <- c("18-34", "35-54", "55+")

race_ethn_levels <- c("White", "Black", "Hispanic", "Asian", "Other")

## ---- acs_wy_2022 ------------------------------------------------------------
## surveycore::acs_pums_wy filtered to adults (agep >= 18).
## Result: 4,736 rows.
## All 96 original columns retained; 4 derived columns added:
##   gender:    factor from sex (1=M, 2=F; no NAs for adults)
##   age_group: factor from agep (18-34, 35-54, 55+; no NAs for adults)
##   race_ethn: factor from rac1p + hisp (White, Black, Hispanic, Asian, Other)
##   educ:      factor from schl (Less HS, HS/Some, College+; no NAs for adults)
## Total columns: 96 + 4 = 100
##
## NOTE: pwgtp is the ACS person weight (population-scaled by design).
## Use pwgtp directly with ipw() — no wt_pop column needed.
##
## acs_wy_2022_svy is survey_replicate (SDR). For ipw() use, construct a
## simple Taylor design from the tibble:
##   ref <- surveycore::as_survey(acs_wy_2022, weights = pwgtp)
##   ipw(ns_wave1, ref, selection = ~gender + age_group + race_ethn + educ)

acs_wy_2022 <- as.data.frame(
  surveycore::acs_pums_wy[surveycore::acs_pums_wy$agep >= 18L, ],
  stringsAsFactors = FALSE
)

# gender: sex 1 = Male, 2 = Female; no NAs expected for adults
acs_wy_2022$gender <- factor(
  acs_wy_2022$sex,
  levels = c(1L, 2L),
  labels = c("Male", "Female")
)

# age_group: cut on agep; all adults (agep >= 18), so no NAs expected
acs_wy_2022$age_group <- cut(
  acs_wy_2022$agep,
  breaks = age_bins,
  labels = age_labs,
  right = FALSE
)

# race_ethn: Hispanic origin takes precedence; Asian = rac1p 4-6
acs_wy_2022$race_ethn <- factor(
  dplyr::case_when(
    acs_wy_2022$hisp > 1L ~ "Hispanic",
    acs_wy_2022$rac1p == 1L ~ "White",
    acs_wy_2022$rac1p == 2L ~ "Black",
    acs_wy_2022$rac1p %in% 4L:6L ~ "Asian",
    TRUE ~ "Other"
  ),
  levels = race_ethn_levels
)

# educ: schl 1-11 = Less than HS, 12-15 = HS/Some college, 16-24 = College+
# schl has no NAs for agep >= 18 (verified)
acs_wy_2022$educ <- factor(
  dplyr::case_when(
    acs_wy_2022$schl %in% 1L:11L ~ "Less than HS",
    acs_wy_2022$schl %in% 12L:15L ~ "HS/Some college",
    acs_wy_2022$schl %in% 16L:24L ~ "College+"
  ),
  levels = c("Less than HS", "HS/Some college", "College+")
)

# Structural assertions
stopifnot(nrow(acs_wy_2022) == 4736L)
stopifnot(all(acs_wy_2022$agep >= 18L))
stopifnot(is.factor(acs_wy_2022$gender))
stopifnot(is.factor(acs_wy_2022$age_group))
stopifnot(is.factor(acs_wy_2022$race_ethn))
stopifnot(is.factor(acs_wy_2022$educ))
stopifnot(sum(is.na(acs_wy_2022$gender)) == 0L)
stopifnot(sum(is.na(acs_wy_2022$age_group)) == 0L)
stopifnot(sum(is.na(acs_wy_2022$race_ethn)) == 0L)
stopifnot(sum(is.na(acs_wy_2022$educ)) == 0L)

## ---- acs_wy_2022_svy --------------------------------------------------------
## survey_replicate companion using successive-difference replication (SDR).
## Uses pwgtp1:pwgtp80 as replicate weights.
##
## Use grep("^pwgtp[0-9]", ...) NOT starts_with("pwgtp") to exclude the main
## pwgtp column from the replicate weight set.
rep_cols <- grep("^pwgtp[0-9]", names(acs_wy_2022), value = TRUE)
stopifnot(length(rep_cols) == 80L) # pwgtp1:pwgtp80

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
