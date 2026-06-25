## data-raw/acs-wy-2022.R
##
## Produces:
##   acs_wy_2022 — surveycore::acs_pums_wy adults with derived cols (tibble)
##
## Run from the package root: source("data-raw/acs-wy-2022.R")

library(surveycore)
library(dplyr)

age_f3_bins    <- c(18, 35, 55, Inf)
age_f3_labs    <- c("18-34", "35-54", "55+")
race_f4_levels <- c("White", "Black", "Hispanic", "Other")
edu_f3_levels  <- c("Less than HS", "HS/Some college", "College+")

## ---- acs_wy_2022 ------------------------------------------------------------
## surveycore::acs_pums_wy filtered to adults (agep >= 18).
## Result: 4,736 rows.
## All 96 original columns retained; raw sex overwritten + 3 derived columns added:
##   sex:      factor from sex (1=M, 2=F; overwrites raw integer; no NAs for adults)
##   age_f3:   factor from agep (18-34, 35-54, 55+; no NAs for adults)
##   race_f4:  factor from rac1p + hisp (White, Black, Hispanic, Other; 4 levels)
##   edu_f3:   factor from schl (Less HS, HS/Some, College+; no NAs for adults)
## Total columns: 96 - 1 (sex overwrite) + 1 (sex) + 3 new = 99
##
## NOTE: pwgtp is the ACS person weight (population-scaled by design).
## Use pwgtp directly with ipw() — no wt_pop column needed.
##
## For ipw() use, construct a simple Taylor design from the tibble:
##   ref <- surveycore::as_survey(acs_wy_2022, weights = pwgtp)
##   ipw(ns_wave1, ref, selection = ~sex + age_f3 + race_f4 + edu_f3)

acs_wy_2022 <- as.data.frame(
  surveycore::acs_pums_wy[surveycore::acs_pums_wy$agep >= 18L, ],
  stringsAsFactors = FALSE
)

# sex: overwrite raw sex column (integer 1=Male, 2=Female) with labeled factor
acs_wy_2022$sex <- factor(
  acs_wy_2022$sex,
  levels = c(1L, 2L),
  labels = c("Male", "Female")
)

# age_f3: cut on agep; all adults (agep >= 18), so no NAs expected
acs_wy_2022$age_f3 <- cut(
  acs_wy_2022$agep,
  breaks = age_f3_bins,
  labels = age_f3_labs,
  right = FALSE
)

# race_f4: Hispanic origin takes precedence; Asian (rac1p 4-6) collapsed into Other
acs_wy_2022$race_f4 <- factor(
  dplyr::case_when(
    acs_wy_2022$hisp > 1L           ~ "Hispanic",
    acs_wy_2022$rac1p == 1L         ~ "White",
    acs_wy_2022$rac1p == 2L         ~ "Black",
    .default                         = "Other"
  ),
  levels = race_f4_levels
)

# edu_f3: schl 1-11 = Less than HS, 12-15 = HS/Some college, 16-24 = College+
# schl has no NAs for agep >= 18 (verified)
acs_wy_2022$edu_f3 <- factor(
  dplyr::recode_values(
    acs_wy_2022$schl,
    c(1:11)  ~ "Less than HS",
    c(12:15) ~ "HS/Some college",
    c(16:24) ~ "College+",
    default  = NA_character_
  ),
  levels = edu_f3_levels
)

# Structural assertions
stopifnot(nrow(acs_wy_2022) == 4736L)
stopifnot(all(acs_wy_2022$agep >= 18L))
stopifnot(is.factor(acs_wy_2022$sex))
stopifnot(is.factor(acs_wy_2022$age_f3))
stopifnot(is.factor(acs_wy_2022$race_f4))
stopifnot(is.factor(acs_wy_2022$edu_f3))
stopifnot(sum(is.na(acs_wy_2022$sex)) == 0L)
stopifnot(sum(is.na(acs_wy_2022$age_f3)) == 0L)
stopifnot(sum(is.na(acs_wy_2022$race_f4)) == 0L)
stopifnot(sum(is.na(acs_wy_2022$edu_f3)) == 0L)

# Add "label" attributes to derived columns (ACS source columns already labeled by surveycore)
attr(acs_wy_2022$sex, "label")    <- "Sex (factor, derived from raw sex: 1=Male, 2=Female)"
attr(acs_wy_2022$age_f3, "label") <- "Age group (3 levels: 18-34, 35-54, 55+)"
attr(acs_wy_2022$race_f4, "label") <- "Race/ethnicity (4 levels: White, Black, Hispanic, Other)"
attr(acs_wy_2022$edu_f3, "label") <- "Educational attainment (3 levels)"

acs_wy_2022 <- tibble::as_tibble(acs_wy_2022)

usethis::use_data(acs_wy_2022, overwrite = TRUE)
message(
  "Saved acs_wy_2022 (",
  nrow(acs_wy_2022),
  " rows x ",
  ncol(acs_wy_2022),
  " cols)"
)
