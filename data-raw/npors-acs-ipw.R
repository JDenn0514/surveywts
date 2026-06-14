library(surveycore)

age_bins <- c(18, 35, 55, Inf)
age_labs <- c("18-34", "35-54", "55+")

race_ethn_levels <- c("White", "Black", "Hispanic", "Asian", "Other")
educ_levels      <- c("Less than HS", "HS/Some college", "College+")

# US non-institutionalised adult population (18+), Census 2024 estimate.
# Both NPORS and GSS use normalized weights (mean ≈ 1).  This constant
# converts them to person-level population weights so that
# sum(d_ref) ≈ N_pop >> n_NPS, satisfying the pseudo-likelihood IPW
# score equations.
US_ADULT_POP <- 260000000L

# --- npors_2025_ref (probability reference) --------------------------------
npors <- pew_npors_2025

# gender: 1=Male, 2=Female; 3=Non-binary / 99=Refused → NA
gender_raw <- npors$gender
gender_raw[gender_raw %in% c(3L, 99L)] <- NA_integer_
npors_gender <- factor(gender_raw, levels = c(1L, 2L), labels = c("Male", "Female"))

# age_group: agegrp 1-3 → "18-34", 4-7 → "35-54", 8-13 → "55+"
agegrp_raw <- npors$agegrp
agegrp_raw[agegrp_raw == 99L] <- NA_integer_
npors_age_group <- factor(
  dplyr::case_when(
    agegrp_raw %in% 1L:3L  ~ "18-34",
    agegrp_raw %in% 4L:7L  ~ "35-54",
    agegrp_raw %in% 8L:13L ~ "55+"
  ),
  levels = age_labs
)

# race_ethn: 1=White, 2=Black, 3=Hispanic, 5=Asian, 4=Other; 99=Refused → NA
racethn_raw <- npors$racethn
racethn_raw[racethn_raw == 99L] <- NA_integer_
npors_race_ethn <- factor(
  dplyr::case_when(
    racethn_raw == 1L ~ "White",
    racethn_raw == 2L ~ "Black",
    racethn_raw == 3L ~ "Hispanic",
    racethn_raw == 5L ~ "Asian",
    racethn_raw == 4L ~ "Other"
  ),
  levels = race_ethn_levels
)

# educ: 1=College+, 2=Some college, 3=HS or less; 99=Refused → NA
educcat_raw <- npors$educcat
educcat_raw[educcat_raw == 99L] <- NA_integer_
npors_educ <- factor(
  dplyr::case_when(
    educcat_raw == 3L ~ "Less than HS",
    educcat_raw == 2L ~ "HS/Some college",
    educcat_raw == 1L ~ "College+"
  ),
  levels = educ_levels
)

# Scale normalized weight (sum = sample size) to population weight
npors_df <- data.frame(
  gender    = npors_gender,
  age_group = npors_age_group,
  race_ethn = npors_race_ethn,
  educ      = npors_educ,
  wt_pop    = npors$weight * (US_ADULT_POP / nrow(npors)),
  stringsAsFactors = FALSE
)
# All 5022 rows retained; ~0.5% NA per predictor column from 99-code recoding

npors_2025_ref <- surveycore::as_survey(npors_df, weights = wt_pop)

# --- npors_2025_clean_ref (NAs removed from all predictor columns) -----------
# Drops rows where gender, age_group, race_ethn, or educ is NA so the object
# can be passed to ipw() without triggering the reference-NA listwise-deletion
# warning.  Use npors_2025_ref when downstream code handles missingness itself.
npors_clean_df <- npors_df[
  !is.na(npors_df$gender) &
    !is.na(npors_df$age_group) &
    !is.na(npors_df$race_ethn) &
    !is.na(npors_df$educ),
]

npors_2025_clean_ref <- surveycore::as_survey(npors_clean_df, weights = wt_pop)

# --- acs_ipw_ref (probability reference) -----------------------------------
acs <- acs_pums_wy[acs_pums_wy$agep >= 18L, ]  # 4736 adults

acs_age_group <- cut(
  acs$agep,
  breaks = age_bins,
  labels = age_labs,
  right  = FALSE
)

acs_gender <- factor(acs$sex, levels = c(1L, 2L), labels = c("Male", "Female"))

acs_race_ethn <- factor(
  dplyr::case_when(
    acs$hisp > 1L      ~ "Hispanic",
    acs$rac1p == 1L    ~ "White",
    acs$rac1p == 2L    ~ "Black",
    acs$rac1p %in% 4:6 ~ "Asian",
    TRUE               ~ "Other"
  ),
  levels = race_ethn_levels
)

acs_educ <- factor(
  dplyr::case_when(
    acs$schl %in% 1:11  ~ "Less than HS",
    acs$schl %in% 12:15 ~ "HS/Some college",
    acs$schl %in% 16:24 ~ "College+",
    is.na(acs$schl)     ~ NA_character_
  ),
  levels = educ_levels
)

acs_df <- data.frame(
  gender    = acs_gender,
  age_group = acs_age_group,
  race_ethn = acs_race_ethn,
  educ      = acs_educ,
  pwgtp     = acs$pwgtp,
  stringsAsFactors = FALSE
)
# 4736 rows; 0 NAs in adults (verified: schl has 0 NAs for agep >= 18)

acs_ipw_ref <- surveycore::as_survey(acs_df, weights = pwgtp)

usethis::use_data(npors_2025_ref, npors_2025_clean_ref, acs_ipw_ref, overwrite = TRUE)
