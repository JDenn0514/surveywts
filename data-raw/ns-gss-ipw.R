library(surveycore)

# --- ns_wave1_ipw ---------------------------------------------------------
ns_wave1_ipw <- ns_wave1[, c("gender", "age")]
ns_wave1_ipw$gender <- factor(
  ns_wave1_ipw$gender,
  levels = c(1L, 2L),
  labels = c("Male", "Female")
)
# 0 NAs in gender or age; all 6422 rows retained

# --- gss_ipw_ref ----------------------------------------------------------
gss_sub <- gss_2024[!is.na(gss_2024$sex), c("sex", "age", "vpsu", "vstrat", "wtssps")]
names(gss_sub)[names(gss_sub) == "sex"] <- "gender"
gss_sub$gender <- factor(
  gss_sub$gender,
  levels = c(1L, 2L),
  labels = c("Male", "Female")
)
# 19 rows with NA sex dropped; 3290 rows retained
gss_ipw_ref <- surveycore::as_survey(
  gss_sub,
  weights = wtssps,
  strata  = vstrat,
  ids     = vpsu
)

usethis::use_data(ns_wave1_ipw, gss_ipw_ref, overwrite = TRUE)
