library(surveycore)

age_group_labels <- c(
  "18-24", "25-29", "30-34", "35-39", "40-44", "45-49",
  "50-54", "55-59", "60-64", "65-69", "70-74", "75-79", "80+"
)
race_ethn_labels <- c("White", "Black", "Hispanic", "Asian", "Other")
educ_labels      <- c("Less than HS", "HS/Some college", "College+")

# --- npors_2025_ipw -------------------------------------------------------
npors <- pew_npors_2025

age_group_raw <- npors$agegrp
age_group_raw[age_group_raw == 99L] <- NA_integer_
npors_age_group <- factor(age_group_raw, levels = 1:13, labels = age_group_labels)

gender_raw <- npors$gender
gender_raw[gender_raw %in% c(3L, 99L)] <- NA_integer_
npors_gender <- factor(gender_raw, levels = c(1L, 2L), labels = c("Male", "Female"))

race_ethn_raw <- npors$racethn
race_ethn_raw[race_ethn_raw == 99L] <- NA_integer_
npors_race_ethn <- factor(race_ethn_raw, levels = 1:5, labels = race_ethn_labels)

educ_raw <- npors$educcat
educ_raw[educ_raw == 99L] <- NA_integer_
npors_educ <- factor(educ_raw, levels = 1:3, labels = educ_labels)

npors_2025_ipw <- data.frame(
  age_group  = npors_age_group,
  gender     = npors_gender,
  race_ethn  = npors_race_ethn,
  educ       = npors_educ,
  stringsAsFactors = FALSE
)
# All 5022 rows retained; ~1-2% NA per predictor column from 99 recoding

# --- acs_ipw_ref ----------------------------------------------------------
acs <- acs_pums_wy[acs_pums_wy$agep >= 18L, ]  # 4736 adults

acs_age_group <- cut(
  acs$agep,
  breaks = c(18, 25, 30, 35, 40, 45, 50, 55, 60, 65, 70, 75, 80, Inf),
  labels = age_group_labels,
  right  = FALSE
)

acs_gender <- factor(acs$sex, levels = c(1L, 2L), labels = c("Male", "Female"))

acs_race_ethn <- factor(
  dplyr::case_when(
    acs$hisp > 1L      ~ 3L,
    acs$rac1p == 1L    ~ 1L,
    acs$rac1p == 2L    ~ 2L,
    acs$rac1p %in% 4:6 ~ 4L,
    TRUE               ~ 5L
  ),
  levels = 1:5,
  labels = race_ethn_labels
)

acs_educ <- factor(
  dplyr::case_when(
    acs$schl %in% 1:11  ~ 1L,
    acs$schl %in% 12:15 ~ 2L,
    acs$schl %in% 16:24 ~ 3L,
    is.na(acs$schl)     ~ NA_integer_
  ),
  levels = 1:3,
  labels = educ_labels
)

acs_df <- data.frame(
  age_group = acs_age_group,
  gender    = acs_gender,
  race_ethn = acs_race_ethn,
  educ      = acs_educ,
  pwgtp     = acs$pwgtp,
  stringsAsFactors = FALSE
)
# 4736 rows; 0 NAs in adults (verified: schl has 0 NAs for agep >= 18)

acs_ipw_ref <- surveycore::as_survey(acs_df, weights = pwgtp)

usethis::use_data(npors_2025_ipw, acs_ipw_ref, overwrite = TRUE)
