## data-raw/npors-2025.R
##
## Produces:
##   npors_2025           — full surveycore::pew_npors_2025 with derived cols
##   npors_2025_svy       — survey_taylor companion
##   npors_2025_clean     — npors_2025 filtered to complete cases on 4 derived cols
##   npors_2025_clean_svy — survey_taylor companion for clean version
##
## Run from the package root: source("data-raw/npors-2025.R")

library(surveycore)
library(dplyr)

age_f3_labs <- c("18-34", "35-54", "55+")
race_f4_levels <- c("White", "Black", "Hispanic", "Other")
edu_f3_levels <- c("Less than HS", "HS/Some college", "College+")
pid_f3_levels <- c("Republican", "Independent", "Democrat")

US_ADULT_POP <- 260000000L

## ---- npors_2025 -------------------------------------------------------------
## Full surveycore::pew_npors_2025 dataset (65 original columns retained).
## Adds 6 derived columns: sex, age_f3, race_f4, edu_f3, pid_f3, wt_pop.
##   sex:    factor from gender col (1=Male, 2=Female; 3/99 -> NA)
##   age_f3: factor from agegrp col (1:3->"18-34", 4:7->"35-54", 8:13->"55+")
##   race_f4: factor from racethn col (1=White, 2=Black, 3=Hisp, 4/5=Other)
##   edu_f3:  factor from educcat col (1=College+, 2=HS/Some, 3=Less HS)
##   pid_f3:  factor from partysum (1=Republican, 9=Independent, 2=Democrat)
##   wt_pop:  numeric; weight * (260000000L / nrow(npors_2025))
##            population-scaled weight for IPW use
##            npors_2025_svy uses weight (normalized); IPW users use wt_pop
## Total columns: 65 + 6 new = 71
## Note: ~0.5% NA per derived column from 99-code recoding

npors_raw <- surveycore::pew_npors_2025
npors_2025 <- as.data.frame(npors_raw, stringsAsFactors = FALSE)

# gender: 1=Male, 2=Female; 3=Non-binary / 99=Refused -> NA
gender_raw <- npors_2025$gender
gender_raw[gender_raw %in% c(3L, 99L)] <- NA_integer_
npors_2025$sex <- factor(
  gender_raw,
  levels = c(1L, 2L),
  labels = c("Male", "Female")
)

# age_f3: agegrp 1-3 -> "18-34", 4-7 -> "35-54", 8-13 -> "55+"; 99 -> NA
agegrp_raw <- npors_2025$agegrp
npors_2025$age_f3 <- factor(
  dplyr::recode_values(
    agegrp_raw,
    c(1:3) ~ "18-34",
    c(4:7) ~ "35-54",
    c(8:13) ~ "55+",
    default = NA_character_
  ),
  levels = age_f3_labs
)

# race_f4: 1=White, 2=Black, 3=Hispanic, 4/5=Other (Asian collapsed); 99 -> NA
racethn_raw <- npors_2025$racethn
npors_2025$race_f4 <- factor(
  dplyr::recode_values(
    racethn_raw,
    1 ~ "White",
    2 ~ "Black",
    3 ~ "Hispanic",
    c(4, 5) ~ "Other",
    default = NA_character_
  ),
  levels = race_f4_levels
)

# edu_f3: 1=College+, 2=HS/Some college, 3=Less than HS; 99 -> NA
educcat_raw <- npors_2025$educcat
npors_2025$edu_f3 <- factor(
  dplyr::recode_values(
    educcat_raw,
    3 ~ "Less than HS",
    2 ~ "HS/Some college",
    1 ~ "College+",
    default = NA_character_
  ),
  levels = edu_f3_levels
)

# pid_f3: partysum 1=Republican, 2=Democrat, 9=Independent; other -> NA
partysum <- npors_2025$partysum
npors_2025$pid_f3 <- factor(
  dplyr::recode_values(
    partysum,
    1 ~ "Republican",
    9 ~ "Independent",
    2 ~ "Democrat",
    default = NA_character_
  ),
  levels = pid_f3_levels
)

# wt_pop: population-scaled weight for IPW use
# npors_2025_svy uses weight (normalized, correct for standard estimation)
npors_2025$wt_pop <- npors_2025$weight * (US_ADULT_POP / nrow(npors_2025))

# Structural assertions
stopifnot(nrow(npors_2025) == 5022L)
stopifnot(ncol(npors_2025) == 71L)
stopifnot(is.factor(npors_2025$sex))
stopifnot(is.factor(npors_2025$age_f3))
stopifnot(is.factor(npors_2025$race_f4))
stopifnot(is.factor(npors_2025$edu_f3))
stopifnot(is.factor(npors_2025$pid_f3))
stopifnot(is.numeric(npors_2025$wt_pop))

## ---- npors_2025_svy ---------------------------------------------------------
npors_2025_svy <- surveycore::as_survey(
  npors_2025,
  strata = stratum,
  weights = weight
)

usethis::use_data(npors_2025, npors_2025_svy, overwrite = TRUE)
message(
  "Saved npors_2025 (",
  nrow(npors_2025),
  " rows x ",
  ncol(npors_2025),
  " cols) and npors_2025_svy"
)

## ---- npors_2025_clean -------------------------------------------------------
## Filtered version of npors_2025: rows where sex, age_f3, race_f4, edu_f3,
## and pid_f3 are all non-NA. No re-scaling of weights after row removal.
## Use this when passing to ipw() to avoid the reference-NA listwise-deletion
## warning. Use npors_2025 when downstream code handles missingness itself.

npors_2025_clean <- npors_2025[
  !is.na(npors_2025$sex) &
    !is.na(npors_2025$age_f3) &
    !is.na(npors_2025$race_f4) &
    !is.na(npors_2025$edu_f3) &
    !is.na(npors_2025$pid_f3),
]

# Structural assertions
stopifnot(sum(is.na(npors_2025_clean$sex)) == 0L)
stopifnot(sum(is.na(npors_2025_clean$age_f3)) == 0L)
stopifnot(sum(is.na(npors_2025_clean$race_f4)) == 0L)
stopifnot(sum(is.na(npors_2025_clean$edu_f3)) == 0L)
stopifnot(sum(is.na(npors_2025_clean$pid_f3)) == 0L)
stopifnot(nrow(npors_2025_clean) > 4700L)

## ---- npors_2025_clean_svy ---------------------------------------------------
npors_2025_clean_svy <- surveycore::as_survey(
  npors_2025_clean,
  strata = stratum,
  weights = weight
)

usethis::use_data(npors_2025_clean, npors_2025_clean_svy, overwrite = TRUE)
message(
  "Saved npors_2025_clean (",
  nrow(npors_2025_clean),
  " rows) and npors_2025_clean_svy"
)
