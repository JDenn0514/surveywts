## data-raw/gss-2024.R
##
## Produces:
##   gss_2024     — full surveycore::gss_2024 with derived demographic cols
##   gss_2024_svy — survey_taylor companion
##
## Run from the package root: source("data-raw/gss-2024.R")

library(surveycore)

age_f3_bins    <- c(18, 35, 55, Inf)
age_f3_labs    <- c("18-34", "35-54", "55+")
race_f4_levels <- c("White", "Black", "Hispanic", "Other")
edu_f3_levels  <- c("Less than HS", "HS/Some college", "College+")
pid_f3_levels  <- c("Republican", "Independent", "Democrat")

## ---- gss_2024 ---------------------------------------------------------------
## Full surveycore::gss_2024 dataset (all 27 original columns retained).
## Adds 5 derived columns:
##   sex:      factor derived from sex (in-place; Male/Female/NA)
##   age_f3:   factor derived from age (NA for age < 18 or NA age)
##   race_f4:  factor from race + hispanic (4 levels; Hispanic takes precedence)
##   pid_f3:   factor from partyid (3 levels)
##   edu_f3:   factor from degree (3 levels)
##   wt_pop:   numeric; wtssps * (260000000L / nrow(gss_2024))
## Total columns: 27 + 5 = 32

gss_2024 <- as.data.frame(surveycore::gss_2024, stringsAsFactors = FALSE)

# sex: convert in-place (sex == 1 -> Male, sex == 2 -> Female, other -> NA)
sex_raw <- gss_2024$sex
gss_2024$sex <- factor(
  dplyr::recode_values(
    sex_raw,
    1 ~ "Male",
    2 ~ "Female",
    default = NA_character_
  ),
  levels = c("Male", "Female")
)

# age_f3
gss_2024$age_f3 <- cut(
  gss_2024$age,
  breaks = age_f3_bins,
  labels = age_f3_labs,
  right = FALSE
)

# race_f4: hispanic > 1 = Hispanic; else White/Black/Other by race
# hispanic: 1=Not Hispanic, 2-5=Hispanic origins
# race: 1=White, 2=Black, 3=Other (no Asian category in GSS)
hispanic <- gss_2024$hispanic
race     <- gss_2024$race
gss_2024$race_f4 <- factor(
  dplyr::case_when(
    hispanic > 1L  ~ "Hispanic",
    race == 1L     ~ "White",
    race == 2L     ~ "Black",
    !is.na(race)   ~ "Other",
    .default = NA_character_
  ),
  levels = race_f4_levels
)

# pid_f3: partyid 0-2=Democrat, 3=Independent, 4-6=Republican, 7=Other->NA
partyid <- gss_2024$partyid
gss_2024$pid_f3 <- factor(
  dplyr::case_when(
    partyid %in% 0L:2L ~ "Democrat",
    partyid == 3L      ~ "Independent",
    partyid %in% 4L:6L ~ "Republican",
    .default = NA_character_
  ),
  levels = pid_f3_levels
)

# edu_f3: degree 0=<HS, 1=HS, 2=Jr college, 3=Bachelor, 4=Graduate
degree <- gss_2024$degree
gss_2024$edu_f3 <- factor(
  dplyr::recode_values(
    degree,
    0         ~ "Less than HS",
    c(1, 2)   ~ "HS/Some college",
    c(3, 4)   ~ "College+",
    default = NA_character_
  ),
  levels = edu_f3_levels
)

# wt_pop: population-scaled weight for IPW use
US_ADULT_POP <- 260000000L
gss_2024$wt_pop <- gss_2024$wtssps * (US_ADULT_POP / nrow(gss_2024))

# Structural assertions
stopifnot(ncol(gss_2024) == 32L)
stopifnot(nrow(gss_2024) == nrow(surveycore::gss_2024))
stopifnot(is.factor(gss_2024$sex))
stopifnot(is.factor(gss_2024$age_f3))
stopifnot(is.factor(gss_2024$race_f4))
stopifnot(is.factor(gss_2024$pid_f3))
stopifnot(is.factor(gss_2024$edu_f3))
stopifnot(is.numeric(gss_2024$wt_pop))

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
