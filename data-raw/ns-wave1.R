## data-raw/ns-wave1.R
##
## Produces:
##   ns_wave1     — full surveycore::ns_wave1 with derived demographic cols
##                  + 8 Nationscape raking recode columns (ns_*)
##   ns_wave1_svy — survey_nonprob raked to Nationscape ACS 2017 targets
##                  (raked + 5th/95th percentile trimmed; no replicate weights)
##
## Run from the package root: source("data-raw/ns-wave1.R")

library(surveycore)
pkgload::load_all(quiet = TRUE)

age_f3_bins    <- c(18, 35, 55, Inf)
age_f3_labs    <- c("18-34", "35-54", "55+")
race_f4_levels <- c("White", "Black", "Hispanic", "Other")
edu_f3_levels  <- c("Less than HS", "HS/Some college", "College+")
pid_f3_levels  <- c("Republican", "Independent", "Democrat")

## ---- ns_wave1 ---------------------------------------------------------------
## Full surveycore::ns_wave1 dataset (171 original columns).
## Column changes:
##   sex:      NEW factor column from gender (gender kept as integer)
##   age_f3:   NEW factor from age
##   race_f4:  NEW factor from race_ethnicity + hispanic (4 levels)
##   edu_f3:   NEW factor from education
##   pid_f3:   NEW factor from pid3
## Total columns: 171 + 5 harmonized + 8 ns_* = 184

ns_wave1 <- as.data.frame(surveycore::ns_wave1, stringsAsFactors = FALSE)

# sex: NEW column; original gender column (integer 1=Male, 2=Female) is KEPT
ns_wave1$sex <- factor(
  dplyr::recode_values(
    ns_wave1$gender,
    1 ~ "Male",
    2 ~ "Female",
    default = NA_character_
  ),
  levels = c("Male", "Female")
)

# age_f3: NEW column; original age column is kept unchanged
ns_wave1$age_f3 <- cut(
  ns_wave1$age,
  breaks = age_f3_bins,
  labels = age_f3_labs,
  right = FALSE
)

# race_f4: NEW column derived from race_ethnicity + hispanic
# Hispanic origin takes precedence; Asian codes 4-10 + Other code 3,11-14 -> "Other"
# race_ethnicity == 15 (some other race, non-Hispanic) -> NA
# Original race_ethnicity and hispanic columns are KEPT
race <- ns_wave1$race_ethnicity
hisp <- ns_wave1$hispanic

ns_wave1$race_f4 <- factor(
  dplyr::case_when(
    hisp != 1L             ~ "Hispanic",
    race == 1L             ~ "White",
    race == 2L             ~ "Black",
    race %in% 3L:14L       ~ "Other",
    .default = NA_character_   # race_ethnicity == 15 -> NA
  ),
  levels = race_f4_levels
)

# edu_f3: NEW column; original education column is KEPT
ns_wave1$edu_f3 <- factor(
  dplyr::recode_values(
    ns_wave1$education,
    c(1:3)  ~ "Less than HS",
    c(4:7)  ~ "HS/Some college",
    c(8:11) ~ "College+",
    default = NA_character_
  ),
  levels = edu_f3_levels
)

# pid_f3: NEW column derived from pid3
# pid3: 1=Democrat (pid7 1-2), 2=Republican (pid7 6-7), 3=Ind (pid7 3-5), 4=Other/No pref
# Code 4 mapped to Independent (not NA) to match Nationscape public methodology
ns_wave1$pid_f3 <- factor(
  dplyr::recode_values(
    ns_wave1$pid3,
    1        ~ "Democrat",
    2        ~ "Republican",
    c(3, 4)  ~ "Independent",
    default = NA_character_
  ),
  levels = pid_f3_levels
)

# ---- Nationscape raking recode columns (ns_*) -------------------------------
# 8 columns used as calibration variables when replicating Nationscape weights.
# Original source columns are kept unchanged.

# ns_region: census_region (1=NE, 2=MW, 3=S, 4=W) -> labeled factor
ns_wave1$ns_region <- factor(
  ns_wave1$census_region,
  levels = c(1L, 2L, 3L, 4L),
  labels = c("Northeast", "Midwest", "South", "West")
)

# ns_hispanic: 1 = Not Hispanic, 2 = Mexican, 3:15 = Other Hispanic
ns_wave1$ns_hispanic <- factor(
  dplyr::recode_values(
    ns_wave1$hispanic,
    1 ~ "Not Hispanic",
    2 ~ "Mexican",
    default = "Other Hispanic"
  ),
  levels = c("Not Hispanic", "Mexican", "Other Hispanic")
)

# ns_race: 4-category ACS race (distinct from the 4-category race_f4 col)
#   1=White, 2=Black, 4:14=Asian/Pacific, 3+15=Other; codes 1,2,3,4:14,15 exhaust valid values
ns_wave1$ns_race <- factor(
  dplyr::recode_values(
    ns_wave1$race_ethnicity,
    1        ~ "White",
    2        ~ "Black",
    c(4:14)  ~ "Asian/Pacific",
    c(3, 15) ~ "Other",
    default  = NA_character_
  ),
  levels = c("White", "Black", "Asian/Pacific", "Other")
)

# ns_age: 7 Nationscape age groups
ns_wave1$ns_age <- factor(
  dplyr::recode_values(
    ns_wave1$age,
    c(18:23) ~ "18-23",
    c(24:29) ~ "24-29",
    c(30:39) ~ "30-39",
    c(40:49) ~ "40-49",
    c(50:59) ~ "50-59",
    c(60:69) ~ "60-69",
    default  = "70+"
  ),
  levels = c("18-23", "24-29", "30-39", "40-49", "50-59", "60-69", "70+")
)

# ns_language: 1=Spanish, 2=Other non-English, 3=English only
ns_wave1$ns_language <- factor(
  dplyr::recode_values(
    ns_wave1$language,
    3 ~ "English only",
    1 ~ "Spanish",
    default = "Other"
  ),
  levels = c("English only", "Spanish", "Other")
)

# ns_foreign_born: 1=United States, 2=Other
ns_wave1$ns_foreign_born <- factor(
  dplyr::recode_values(
    ns_wave1$foreign_born,
    1 ~ "United States",
    default = "Other"
  ),
  levels = c("United States", "Other")
)

# ns_income: 9 ACS brackets + "No answer" for NAs (codes 1-24 -> brackets)
income <- ns_wave1$household_income
ns_wave1$ns_income <- factor(
  dplyr::recode_values(
    income,
    c(1:2) ~ "<$20k",
    c(3:5) ~ "$20-35k",
    c(6:8) ~ "$35-50k",
    c(9:11) ~ "$50-65k",
    c(12:14) ~ "$65-80k",
    c(15:18) ~ "$80-100k",
    19 ~ "$100-125k",
    c(20:22) ~ "$125-200k",
    c(23:34) ~ "≥$200k",
    default = "No answer"
  ),
  levels = c(
    "<$20k",
    "$20-35k",
    "$35-50k",
    "$50-65k",
    "$65-80k",
    "$80-100k",
    "$100-125k",
    "$125-200k",
    "≥$200k",
    "No answer"
  )
)

# ns_vote_2016: Trump/Clinton/Other/No vote (codes 7-8 -> No vote)
vote_16 <- ns_wave1$vote_2016
ns_wave1$ns_vote_2016 <- factor(
  dplyr::recode_values(
    vote_16,
    1       ~ "Trump",
    2       ~ "Clinton",
    c(3:5)  ~ "Other",
    default = "No vote"
  ),
  levels = c("Trump", "Clinton", "Other", "No vote")
)

# Structural assertions
stopifnot(ncol(ns_wave1) == 184L)
stopifnot(nrow(ns_wave1) == 6422L)
stopifnot(is.factor(ns_wave1$sex))
stopifnot(is.factor(ns_wave1$age_f3))
stopifnot(is.factor(ns_wave1$race_f4))
stopifnot(is.factor(ns_wave1$edu_f3))
stopifnot(is.factor(ns_wave1$pid_f3))
stopifnot(all(!is.na(ns_wave1$ns_region)))
stopifnot(all(!is.na(ns_wave1$ns_hispanic)))
stopifnot(all(!is.na(ns_wave1$ns_race)))
stopifnot(all(!is.na(ns_wave1$ns_age)))
stopifnot(all(!is.na(ns_wave1$ns_language)))
stopifnot(all(!is.na(ns_wave1$ns_foreign_born)))
stopifnot(all(!is.na(ns_wave1$ns_income)))
stopifnot(all(!is.na(ns_wave1$ns_vote_2016)))
# ~491 NAs in race_f4 (race_ethnicity == 15); 0 NAs in edu_f3

## ---- ns_wave1_svy -----------------------------------------------------------

# Raking targets: ACS 2017 proportions (Nationscape Technical Report, Table 1).
# Income NAs get target = observed NA rate; the 9 ACS proportions are scaled
# by (1 - NA rate) so all 10 income targets sum to 1.0.
.income_na_rate <- mean(is.na(ns_wave1$household_income))
.income_scale <- 1 - .income_na_rate

.ns_targets <- list(
  sex = c("Male" = 0.483, "Female" = 0.517),
  ns_region = c(
    "Northeast" = 0.176,
    "Midwest" = 0.209,
    "South" = 0.378,
    "West" = 0.237
  ),
  ns_hispanic = c(
    "Not Hispanic" = 0.839,
    "Mexican" = 0.097,
    "Other Hispanic" = 0.064
  ),
  ns_race = c(
    "White" = 0.742,
    "Black" = 0.120,
    "Asian/Pacific" = 0.068,
    "Other" = 0.070
  ),
  ns_age = c(
    "18-23" = 0.095,
    "24-29" = 0.109,
    "30-39" = 0.174,
    "40-49" = 0.164,
    "50-59" = 0.174,
    "60-69" = 0.150,
    "70+" = 0.134 # 0.133 in table; +0.001 to correct rounding to 1.0
  ),
  ns_language = c(
    "English only" = 0.783,
    "Spanish" = 0.129,
    "Other" = 0.088
  ),
  ns_foreign_born = c("United States" = 0.822, "Other" = 0.178),
  ns_income = c(
    "<$20k" = 0.107 * .income_scale,
    "$20-35k" = 0.116 * .income_scale,
    "$35-50k" = 0.118 * .income_scale,
    "$50-65k" = 0.113 * .income_scale,
    "$65-80k" = 0.098 * .income_scale,
    "$80-100k" = 0.110 * .income_scale,
    "$100-125k" = 0.105 * .income_scale,
    "$125-200k" = 0.146 * .income_scale,
    "≥$200k" = 0.087 * .income_scale,
    "No answer" = .income_na_rate
  ),
  ns_vote_2016 = c(
    "Trump" = 0.272,
    "Clinton" = 0.284,
    "Other" = 0.033,
    "No vote" = 0.411 # 0.410 in table; +0.001 for rounding
  )
)

# Step 1: Create base survey_nonprob from published Nationscape weight
ns_wave1_svy <- surveycore::as_survey_nonprob(
  ns_wave1,
  weights = weight
)

# Step 2: Rake to ACS 2017 targets (NR algorithm; 5th/95th percentile trim).
# Replicates Nationscape's weighting procedure (r = 0.9962 vs published weight).
ns_wave1_svy <- calibrate_rake(
  ns_wave1_svy,
  targets = .ns_targets,
  weights = weight,
  wt_name = "weight",
  type = "prop",
  algorithm = "nr"
)
ns_wave1_svy <- trim_weights(
  ns_wave1_svy,
  weights = weight,
  lower = 0.05,
  upper = 0.95,
  type = "percentile",
  wt_name = "weight"
)

rm(.income_na_rate, .income_scale, .ns_targets)

usethis::use_data(ns_wave1, ns_wave1_svy, overwrite = TRUE)
message(
  "Saved ns_wave1 (",
  nrow(ns_wave1),
  " rows x ",
  ncol(ns_wave1),
  " cols) and ns_wave1_svy ",
  "(raked + trimmed; no replicate weights)"
)
