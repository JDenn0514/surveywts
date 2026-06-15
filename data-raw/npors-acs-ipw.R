## data-raw/npors-acs-ipw.R
##
## Produces:
##   npors_2025           — full surveycore::pew_npors_2025 with derived cols
##   npors_2025_svy       — survey_taylor companion
##   npors_2025_clean     — npors_2025 filtered to complete cases on 4 derived cols
##   npors_2025_clean_svy — survey_taylor companion for clean version
##   acs_wy_2022          — surveycore::acs_pums_wy adults with derived cols
##   acs_wy_2022_svy      — survey_replicate companion (SDR, mse = TRUE)
##
## Run from the package root: source("data-raw/npors-acs-ipw.R")

library(surveycore)
library(dplyr)

age_bins <- c(18, 35, 55, Inf)
age_labs <- c("18-34", "35-54", "55+")

race_ethn_levels <- c("White", "Black", "Hispanic", "Asian", "Other")
educ_levels      <- c("Less than HS", "HS/Some college", "College+")

US_ADULT_POP <- 260000000L

## ---- npors_2025 -------------------------------------------------------------
## Full surveycore::pew_npors_2025 dataset (65 original columns retained).
## Adds 5 derived columns:
##   gender:    factor from gender col (1=M, 2=F; 3/99 -> NA)
##   age_group: factor from agegrp col (1:3->"18-34", 4:7->"35-54", 8:13->"55+")
##   race_ethn: factor from racethn col (1=White, 2=Black, 3=Hisp, 5=Asian, 4=Other)
##   educ:      factor from educcat col (1=College+, 2=HS/Some, 3=Less HS)
##   wt_pop:    numeric; weight * (260000000L / nrow(npors_2025))
##              population-scaled weight for IPW use
##              npors_2025_svy uses weight (normalized); IPW users use wt_pop
## Total columns: 65 + 4 new = 69
## (gender already exists in source and is overwritten in-place;
## age_group, race_ethn, educ, wt_pop are the 4 genuinely new columns)
## Note: ~0.5% NA per derived column from 99-code recoding

npors_raw <- surveycore::pew_npors_2025
npors_2025 <- as.data.frame(npors_raw, stringsAsFactors = FALSE)

# gender: 1=Male, 2=Female; 3=Non-binary / 99=Refused -> NA
gender_raw <- npors_2025$gender
gender_raw[gender_raw %in% c(3L, 99L)] <- NA_integer_
npors_2025$gender <- factor(
  gender_raw,
  levels = c(1L, 2L),
  labels = c("Male", "Female")
)

# age_group: agegrp 1-3 -> "18-34", 4-7 -> "35-54", 8-13 -> "55+"; 99 -> NA
agegrp_raw <- npors_2025$agegrp
agegrp_raw[agegrp_raw == 99L] <- NA_integer_
npors_2025$age_group <- factor(
  dplyr::case_when(
    agegrp_raw %in% 1L:3L  ~ "18-34",
    agegrp_raw %in% 4L:7L  ~ "35-54",
    agegrp_raw %in% 8L:13L ~ "55+"
  ),
  levels = age_labs
)

# race_ethn: 1=White, 2=Black, 3=Hispanic, 5=Asian, 4=Other; 99 -> NA
racethn_raw <- npors_2025$racethn
racethn_raw[racethn_raw == 99L] <- NA_integer_
npors_2025$race_ethn <- factor(
  dplyr::case_when(
    racethn_raw == 1L ~ "White",
    racethn_raw == 2L ~ "Black",
    racethn_raw == 3L ~ "Hispanic",
    racethn_raw == 5L ~ "Asian",
    racethn_raw == 4L ~ "Other"
  ),
  levels = race_ethn_levels
)

# educ: 1=College+, 2=HS/Some college, 3=Less than HS; 99 -> NA
educcat_raw <- npors_2025$educcat
educcat_raw[educcat_raw == 99L] <- NA_integer_
npors_2025$educ <- factor(
  dplyr::case_when(
    educcat_raw == 3L ~ "Less than HS",
    educcat_raw == 2L ~ "HS/Some college",
    educcat_raw == 1L ~ "College+"
  ),
  levels = educ_levels
)

# wt_pop: population-scaled weight for IPW use
# npors_2025_svy uses weight (normalized, correct for standard estimation)
npors_2025$wt_pop <- npors_2025$weight * (US_ADULT_POP / nrow(npors_2025))

# Structural assertions
stopifnot(nrow(npors_2025) == 5022L)
stopifnot(ncol(npors_2025) == 69L)
stopifnot(is.factor(npors_2025$gender))
stopifnot(is.factor(npors_2025$age_group))
stopifnot(is.factor(npors_2025$race_ethn))
stopifnot(is.factor(npors_2025$educ))
stopifnot(is.numeric(npors_2025$wt_pop))

## ---- npors_2025_svy ---------------------------------------------------------
npors_2025_svy <- surveycore::as_survey(npors_2025, weights = weight)

usethis::use_data(npors_2025, npors_2025_svy, overwrite = TRUE)
message(
  "Saved npors_2025 (",
  nrow(npors_2025), " rows x ", ncol(npors_2025), " cols) and npors_2025_svy"
)

## ---- npors_2025_clean -------------------------------------------------------
## Filtered version of npors_2025: rows where gender, age_group, race_ethn,
## and educ are all non-NA. No re-scaling of weights after row removal.
## Use this when passing to ipw() to avoid the reference-NA listwise-deletion
## warning. Use npors_2025 when downstream code handles missingness itself.

npors_2025_clean <- npors_2025[
  !is.na(npors_2025$gender) &
    !is.na(npors_2025$age_group) &
    !is.na(npors_2025$race_ethn) &
    !is.na(npors_2025$educ),
]

# Structural assertions
stopifnot(sum(is.na(npors_2025_clean$gender)) == 0L)
stopifnot(sum(is.na(npors_2025_clean$age_group)) == 0L)
stopifnot(sum(is.na(npors_2025_clean$race_ethn)) == 0L)
stopifnot(sum(is.na(npors_2025_clean$educ)) == 0L)
stopifnot(nrow(npors_2025_clean) > 4700L)

## ---- npors_2025_clean_svy ---------------------------------------------------
npors_2025_clean_svy <- surveycore::as_survey(npors_2025_clean, weights = weight)

usethis::use_data(npors_2025_clean, npors_2025_clean_svy, overwrite = TRUE)
message(
  "Saved npors_2025_clean (",
  nrow(npors_2025_clean), " rows) and npors_2025_clean_svy"
)

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
  right  = FALSE
)

# race_ethn: Hispanic origin takes precedence; Asian = rac1p 4-6
acs_wy_2022$race_ethn <- factor(
  dplyr::case_when(
    acs_wy_2022$hisp > 1L             ~ "Hispanic",
    acs_wy_2022$rac1p == 1L           ~ "White",
    acs_wy_2022$rac1p == 2L           ~ "Black",
    acs_wy_2022$rac1p %in% 4L:6L     ~ "Asian",
    TRUE                               ~ "Other"
  ),
  levels = race_ethn_levels
)

# educ: schl 1-11 = Less than HS, 12-15 = HS/Some college, 16-24 = College+
# schl has no NAs for agep >= 18 (verified)
acs_wy_2022$educ <- factor(
  dplyr::case_when(
    acs_wy_2022$schl %in% 1L:11L  ~ "Less than HS",
    acs_wy_2022$schl %in% 12L:15L ~ "HS/Some college",
    acs_wy_2022$schl %in% 16L:24L ~ "College+"
  ),
  levels = educ_levels
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
stopifnot(length(rep_cols) == 80L)  # pwgtp1:pwgtp80

acs_wy_2022_svy <- surveycore::as_survey_replicate(
  acs_wy_2022,
  weights    = pwgtp,
  repweights = dplyr::all_of(rep_cols),
  type       = "successive-difference",
  mse        = TRUE
)

usethis::use_data(acs_wy_2022, acs_wy_2022_svy, overwrite = TRUE)
message(
  "Saved acs_wy_2022 (",
  nrow(acs_wy_2022), " rows x ", ncol(acs_wy_2022), " cols) and acs_wy_2022_svy"
)
