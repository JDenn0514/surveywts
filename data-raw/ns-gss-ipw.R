## data-raw/ns-gss-ipw.R
##
## Produces:
##   ns_wave1      — full surveycore::ns_wave1 with derived demographic cols
##   ns_wave1_svy  — survey_nonprob companion
##   gss_2024      — full surveycore::gss_2024 with derived demographic cols
##   gss_2024_svy  — survey_taylor companion
##
## Run from the package root: source("data-raw/ns-gss-ipw.R")

library(surveycore)
pkgload::load_all(quiet = TRUE)

age_bins <- c(18, 35, 55, Inf)
age_labs <- c("18-34", "35-54", "55+")

## ---- ns_wave1 ---------------------------------------------------------------
## Full surveycore::ns_wave1 dataset (171 original columns).
## Column changes:
##   gender:    overwritten in-place (integer -> factor); no new col added
##   age_group: NEW column derived from age (original age column kept)
##   race_ethn: NEW column derived from race_ethnicity + hispanic
##   educ:      NEW column derived from education
## Total columns: 171 (original) + 3 (new: age_group, race_ethn, educ) = 174

ns_wave1 <- as.data.frame(surveycore::ns_wave1, stringsAsFactors = FALSE)

# gender: overwrite in-place (integer 1 = Male, 2 = Female -> factor)
# Any value outside {1, 2} -> NA (implicit in factor coercion)
ns_wave1$gender <- factor(
  ns_wave1$gender,
  levels = c(1L, 2L),
  labels = c("Male", "Female")
)

# age_group: NEW column; original age column is kept unchanged
ns_wave1$age_group <- cut(
  ns_wave1$age,
  breaks = age_bins,
  labels = age_labs,
  right  = FALSE
)

# race_ethn: NEW column derived from race_ethnicity + hispanic
# Hispanic origin takes precedence; Asian = codes 4-10; Other = codes 3, 11-14
# race_ethnicity == 15 (some other race, non-Hispanic) -> NA
# Original race_ethnicity and hispanic columns are KEPT
race <- ns_wave1$race_ethnicity
hisp <- ns_wave1$hispanic

ns_wave1$race_ethn <- factor(
  ifelse(
    hisp != 1L, "Hispanic",
    ifelse(race == 1L, "White",
    ifelse(race == 2L, "Black",
    ifelse(race %in% 4L:10L, "Asian",
    ifelse(race %in% c(3L, 11L:14L), "Other",
    NA_character_))))),  # race == 15 -> NA
  levels = c("White", "Black", "Hispanic", "Asian", "Other")
)

# educ: NEW column; original education column is KEPT
ns_wave1$educ <- factor(
  ifelse(
    ns_wave1$education %in% 1L:3L,  "Less than HS",
    ifelse(
      ns_wave1$education %in% 4L:7L,  "HS/Some college",
      ifelse(
        ns_wave1$education %in% 8L:11L, "College+",
        NA_character_))),
  levels = c("Less than HS", "HS/Some college", "College+")
)

# Structural assertions
stopifnot(ncol(ns_wave1) == 174L)
stopifnot(nrow(ns_wave1) == 6422L)
stopifnot(is.factor(ns_wave1$gender))
stopifnot(is.factor(ns_wave1$age_group))
stopifnot(is.factor(ns_wave1$race_ethn))
stopifnot(is.factor(ns_wave1$educ))
# ~419 NAs in race_ethn (race_ethnicity == 15); 0 NAs in educ

## ---- ns_wave1_svy -----------------------------------------------------------
ns_wave1_svy <- surveycore::as_survey_nonprob(
  ns_wave1,
  weights = weight
)

## Add quasi-randomization bootstrap replicate weights (200 replicates).
## Seed fixed for reproducibility.
ns_wave1_svy <- create_bootstrap_weights(
  ns_wave1_svy,
  type = "quasi-randomization",
  seed = 2025L
)

usethis::use_data(ns_wave1, ns_wave1_svy, overwrite = TRUE)
message(
  "Saved ns_wave1 (",
  nrow(ns_wave1), " rows x ", ncol(ns_wave1), " cols) and ns_wave1_svy ",
  "(with 200 bootstrap replicate weights)"
)

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
  ifelse(gss_2024$sex == 1L, "Male",
  ifelse(gss_2024$sex == 2L, "Female", NA_character_)),
  levels = c("Male", "Female")
)

# age_group: NA for age < 18 or NA age (cut() handles this automatically)
gss_2024$age_group <- cut(
  gss_2024$age,
  breaks = age_bins,
  labels = age_labs,
  right  = FALSE
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
  strata  = vstrat,
  ids     = vpsu,
  nest    = TRUE
)

usethis::use_data(gss_2024, gss_2024_svy, overwrite = TRUE)
message(
  "Saved gss_2024 (",
  nrow(gss_2024), " rows x ", ncol(gss_2024), " cols) and gss_2024_svy"
)
