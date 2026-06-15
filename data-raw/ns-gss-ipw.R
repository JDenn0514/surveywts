library(surveycore)

age_bins <- c(18, 35, 55, Inf)
age_labs <- c("18-34", "35-54", "55+")

# US non-institutionalised adult population (18+), Census 2024 estimate.
# The GSS wtssps weight is normalized to the sample size (mean ≈ 1).  Scaling
# by this factor converts it to a person-level population weight so that
# sum(d_ref) ≈ N_pop >> n_NPS, which is required for the pseudo-likelihood
# IPW score equations to have a valid solution.
US_ADULT_POP <- 260000000L

# --- ns_wave1_ipw ---------------------------------------------------------
nps_raw <- ns_wave1[
  , c("gender", "age", "race_ethnicity", "hispanic", "education")
]

# gender: the data-raw convention treats level 1 as "Male" to align with
# gss_2024$sex where 1 = Male.
nps_raw$gender <- factor(
  nps_raw$gender,
  levels = c(1L, 2L),
  labels = c("Male", "Female")
)

# age_group: 3 levels matching all reference datasets
nps_raw$age_group <- cut(
  nps_raw$age,
  breaks = age_bins,
  labels = age_labs,
  right  = FALSE
)
nps_raw$age <- NULL

# race_ethn: combine race_ethnicity (what race) and hispanic (hispanic origin)
#   Hispanic origin takes precedence; Asian = any of the 7 Asian sub-groups;
#   Other = AIAN + Pacific Islander; "some other race, non-Hispanic" → NA
race <- nps_raw$race_ethnicity
hisp <- nps_raw$hispanic

nps_raw$race_ethn <- factor(
  ifelse(
    hisp != 1L, "Hispanic",
    ifelse(race == 1L, "White",
    ifelse(race == 2L, "Black",
    ifelse(race %in% 4L:10L, "Asian",
    ifelse(race %in% c(3L, 11L:14L), "Other",
    NA_character_))))),   # race == 15: "some other race, non-Hispanic" → NA
  levels = c("White", "Black", "Hispanic", "Asian", "Other")
)
nps_raw$race_ethnicity <- NULL
nps_raw$hispanic       <- NULL

# educ: collapse 11-level education to 3 levels matching NPORS / ACS
nps_raw$educ <- factor(
  ifelse(
    nps_raw$education %in% 1L:3L,  "Less than HS",
    ifelse(
      nps_raw$education %in% 4L:7L,  "HS/Some college",
      ifelse(
        nps_raw$education %in% 8L:11L, "College+",
        NA_character_))),
  levels = c("Less than HS", "HS/Some college", "College+")
)
nps_raw$education <- NULL

ns_wave1_ipw <- nps_raw
# ~419 NAs in race_ethn (race_ethnicity = 15, non-Hispanic); 0 NAs elsewhere

# --- gss_ipw_ref ----------------------------------------------------------
gss_sub <- gss_2024[
  !is.na(gss_2024$sex) & !is.na(gss_2024$age),
  c("sex", "age", "vpsu", "vstrat", "wtssps")
]
names(gss_sub)[names(gss_sub) == "sex"] <- "gender"
gss_sub$gender <- factor(
  gss_sub$gender,
  levels = c(1L, 2L),
  labels = c("Male", "Female")
)
gss_sub$age_group <- cut(
  gss_sub$age,
  breaks = age_bins,
  labels = age_labs,
  right  = FALSE
)
gss_sub$age <- NULL
# Scale normalized weight to population weight; 19 NA-sex + 93 NA-age rows dropped
gss_sub$wt_pop <- gss_sub$wtssps * (US_ADULT_POP / nrow(gss_sub))
gss_ipw_ref <- surveycore::as_survey(
  gss_sub,
  weights = wt_pop,
  strata  = vstrat,
  ids     = vpsu,
  nest    = TRUE
)

usethis::use_data(ns_wave1_ipw, gss_ipw_ref, overwrite = TRUE)
