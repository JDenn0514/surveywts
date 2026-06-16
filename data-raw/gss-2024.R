## data-raw/gss-2024.R
##
## Produces:
##   gss_2024     — full surveycore::gss_2024 with derived demographic cols
##   gss_2024_svy — survey_taylor companion
##
## Run from the package root: source("data-raw/gss-2024.R")

library(surveycore)

age_bins <- c(18, 35, 55, Inf)
age_labs <- c("18-34", "35-54", "55+")

## ---- gss_2024 ---------------------------------------------------------------
## Full surveycore::gss_2024 dataset (all 27 original columns retained).
## Adds 3 derived columns:
##   gender:    factor derived from sex (all rows kept, including NA-sex rows)
##   age_group: factor derived from age (NA for age < 18 or NA age)
##   wt_pop:    numeric; wtssps * (260000000L / nrow(gss_2024))
##              population-scaled weight for IPW use (sums to ~260M)
##              gss_2024_svy uses wtssps (normalized); IPW users use wt_pop
## Total columns: 27 + 3 = 30

gss_2024 <- as.data.frame(surveycore::gss_2024, stringsAsFactors = FALSE)

# gender: sex == 1 -> Male, sex == 2 -> Female, other -> NA
gss_2024$gender <- factor(
  ifelse(
    gss_2024$sex == 1L,
    "Male",
    ifelse(gss_2024$sex == 2L, "Female", NA_character_)
  ),
  levels = c("Male", "Female")
)

# age_group: NA for age < 18 or NA age (cut() handles this automatically)
gss_2024$age_group <- cut(
  gss_2024$age,
  breaks = age_bins,
  labels = age_labs,
  right = FALSE
)

# wt_pop: population-scaled weight for IPW use
# gss_2024_svy uses wtssps (normalized, correct for standard estimation)
US_ADULT_POP <- 260000000L
gss_2024$wt_pop <- gss_2024$wtssps * (US_ADULT_POP / nrow(gss_2024))

# Structural assertions
stopifnot(ncol(gss_2024) == 30L)
stopifnot(nrow(gss_2024) == nrow(surveycore::gss_2024))
stopifnot(is.factor(gss_2024$gender))
stopifnot(is.factor(gss_2024$age_group))
stopifnot(is.numeric(gss_2024$wt_pop))

## ---- gss_2024_svy -----------------------------------------------------------
## survey_taylor companion using wtssps (normalized weight — correct for
## standard survey estimation). For IPW workflows, users construct their own
## reference design from the gss_2024 tibble using the wt_pop column:
##
##   data(gss_2024)
##   ref <- surveycore::as_survey(
##     gss_2024, weights = wt_pop, strata = vstrat, ids = vpsu, nest = TRUE
##   )
##   ipw(ns_wave1, ref, selection = ~gender + age_group)
gss_2024_svy <- surveycore::as_survey(
  gss_2024,
  weights = wtssps,
  strata = vstrat,
  ids = vpsu,
  nest = TRUE
)

usethis::use_data(gss_2024, gss_2024_svy, overwrite = TRUE)
message(
  "Saved gss_2024 (",
  nrow(gss_2024),
  " rows x ",
  ncol(gss_2024),
  " cols) and gss_2024_svy"
)
