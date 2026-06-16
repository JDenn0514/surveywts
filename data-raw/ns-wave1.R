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
  right = FALSE
)

# race_ethn: NEW column derived from race_ethnicity + hispanic
# Hispanic origin takes precedence; Asian = codes 4-10; Other = codes 3, 11-14
# race_ethnicity == 15 (some other race, non-Hispanic) -> NA
# Original race_ethnicity and hispanic columns are KEPT
race <- ns_wave1$race_ethnicity
hisp <- ns_wave1$hispanic

ns_wave1$race_ethn <- factor(
  ifelse(
    hisp != 1L,
    "Hispanic",
    ifelse(
      race == 1L,
      "White",
      ifelse(
        race == 2L,
        "Black",
        ifelse(
          race %in% 4L:10L,
          "Asian",
          ifelse(race %in% c(3L, 11L:14L), "Other", NA_character_)
        )
      )
    )
  ),
  levels = c("White", "Black", "Hispanic", "Asian", "Other")
)

# educ: NEW column; original education column is KEPT
ns_wave1$educ <- factor(
  ifelse(
    ns_wave1$education %in% 1L:3L,
    "Less than HS",
    ifelse(
      ns_wave1$education %in% 4L:7L,
      "HS/Some college",
      ifelse(
        ns_wave1$education %in% 8L:11L,
        "College+",
        NA_character_
      )
    )
  ),
  levels = c("Less than HS", "HS/Some college", "College+")
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
  ifelse(
    ns_wave1$hispanic == 1L,
    "Not Hispanic",
    ifelse(ns_wave1$hispanic == 2L, "Mexican", "Other Hispanic")
  ),
  levels = c("Not Hispanic", "Mexican", "Other Hispanic")
)

# ns_race: 4-category ACS race (distinct from the 5-category race_ethn col)
#   1=White, 2=Black, 4:14=Asian/Pacific, 3+15=Other
ns_wave1$ns_race <- factor(
  ifelse(
    ns_wave1$race_ethnicity == 1L,
    "White",
    ifelse(
      ns_wave1$race_ethnicity == 2L,
      "Black",
      ifelse(
        ns_wave1$race_ethnicity %in% 4L:14L,
        "Asian/Pacific",
        ifelse(ns_wave1$race_ethnicity %in% c(3L, 15L), "Other", NA_character_)
      )
    )
  ),
  levels = c("White", "Black", "Asian/Pacific", "Other")
)

# ns_age: 7 Nationscape age groups
ns_wave1$ns_age <- factor(
  ifelse(
    ns_wave1$age %in% 18L:23L,
    "18-23",
    ifelse(
      ns_wave1$age %in% 24L:29L,
      "24-29",
      ifelse(
        ns_wave1$age %in% 30L:39L,
        "30-39",
        ifelse(
          ns_wave1$age %in% 40L:49L,
          "40-49",
          ifelse(
            ns_wave1$age %in% 50L:59L,
            "50-59",
            ifelse(
              ns_wave1$age %in% 60L:69L,
              "60-69",
              ifelse(ns_wave1$age >= 70L, "70+", NA_character_)
            )
          )
        )
      )
    )
  ),
  levels = c("18-23", "24-29", "30-39", "40-49", "50-59", "60-69", "70+")
)

# ns_language: 1=Spanish, 2=Other non-English, 3=English only
ns_wave1$ns_language <- factor(
  ifelse(
    ns_wave1$language == 3L,
    "English only",
    ifelse(ns_wave1$language == 1L, "Spanish", "Other")
  ),
  levels = c("English only", "Spanish", "Other")
)

# ns_foreign_born: 1=United States, 2=Other
ns_wave1$ns_foreign_born <- factor(
  ifelse(ns_wave1$foreign_born == 1L, "United States", "Other"),
  levels = c("United States", "Other")
)

# ns_income: 9 ACS brackets + "No answer" for NAs (codes 1-24 -> brackets)
ns_wave1$ns_income <- factor(
  ifelse(
    is.na(ns_wave1$household_income),
    "No answer",
    ifelse(
      ns_wave1$household_income %in% 1L:2L,
      "<$20k",
      ifelse(
        ns_wave1$household_income %in% 3L:5L,
        "$20-35k",
        ifelse(
          ns_wave1$household_income %in% 6L:8L,
          "$35-50k",
          ifelse(
            ns_wave1$household_income %in% 9L:11L,
            "$50-65k",
            ifelse(
              ns_wave1$household_income %in% 12L:14L,
              "$65-80k",
              ifelse(
                ns_wave1$household_income %in% 15L:18L,
                "$80-100k",
                ifelse(
                  ns_wave1$household_income == 19L,
                  "$100-125k",
                  ifelse(
                    ns_wave1$household_income %in% 20L:22L,
                    "$125-200k",
                    ifelse(
                      ns_wave1$household_income %in% 23L:24L,
                      "≥$200k",
                      NA_character_
                    )
                  )
                )
              )
            )
          )
        )
      )
    )
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
ns_wave1$ns_vote_2016 <- factor(
  ifelse(
    ns_wave1$vote_2016 == 1L,
    "Trump",
    ifelse(
      ns_wave1$vote_2016 == 2L,
      "Clinton",
      ifelse(ns_wave1$vote_2016 %in% 3L:5L, "Other", "No vote")
    )
  ),
  levels = c("Trump", "Clinton", "Other", "No vote")
)

# Structural assertions
stopifnot(ncol(ns_wave1) == 182L)
stopifnot(nrow(ns_wave1) == 6422L)
stopifnot(is.factor(ns_wave1$gender))
stopifnot(is.factor(ns_wave1$age_group))
stopifnot(is.factor(ns_wave1$race_ethn))
stopifnot(is.factor(ns_wave1$educ))
stopifnot(all(!is.na(ns_wave1$ns_region)))
stopifnot(all(!is.na(ns_wave1$ns_hispanic)))
stopifnot(all(!is.na(ns_wave1$ns_race)))
stopifnot(all(!is.na(ns_wave1$ns_age)))
stopifnot(all(!is.na(ns_wave1$ns_language)))
stopifnot(all(!is.na(ns_wave1$ns_foreign_born)))
stopifnot(all(!is.na(ns_wave1$ns_income)))
stopifnot(all(!is.na(ns_wave1$ns_vote_2016)))
# ~419 NAs in race_ethn (race_ethnicity == 15); 0 NAs in educ

## ---- ns_wave1_svy -----------------------------------------------------------

# Raking targets: ACS 2017 proportions (Nationscape Technical Report, Table 1).
# Income NAs get target = observed NA rate; the 9 ACS proportions are scaled
# by (1 - NA rate) so all 10 income targets sum to 1.0.
.income_na_rate <- mean(is.na(ns_wave1$household_income))
.income_scale <- 1 - .income_na_rate

.ns_targets <- list(
  gender = c("Male" = 0.483, "Female" = 0.517),
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
