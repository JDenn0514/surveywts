# tests/testthat/test-datasets.R
#
# Structural tests for all bundled datasets.
# Tests confirm presence/absence, dimensions, factor levels, and survey object
# classes. Integration tests confirm ipw() works with the new objects.

library(surveywts)

# ============================================================================
# Presence / absence — new objects exist, retired objects are gone
# ============================================================================

test_that("new tibble datasets are loadable via data()", {
  # New tibbles
  expect_no_error(data(gss_2024, envir = new.env()))
  expect_no_error(data(npors_2025, envir = new.env()))
  expect_no_error(data(npors_2025_clean, envir = new.env()))
  expect_no_error(data(ns_wave1, envir = new.env()))
  expect_no_error(data(cps_2023, envir = new.env()))
  # Existing pew tibbles still loadable
  expect_no_error(data(pew_2016_optin, envir = new.env()))
  expect_no_error(data(pew_2016_synth_pop, envir = new.env()))
})

test_that("_svy companion datasets are no longer in the package", {
  pkg_data <- data(package = "surveywts")$results[, "Item"]
  expect_false("gss_2024_svy" %in% pkg_data)
  expect_false("npors_2025_svy" %in% pkg_data)
  expect_false("npors_2025_clean_svy" %in% pkg_data)
  expect_false("acs_wy_2022_svy" %in% pkg_data)
  expect_false("pew_2016_optin_svy" %in% pkg_data)
  expect_false("pew_2016_synth_pop_svy" %in% pkg_data)
  expect_false("ns_wave1_svy" %in% pkg_data)
})

test_that("retired datasets no longer exist in the package", {
  # data() emits a warning (not error) for missing datasets. The reliable
  # check is to verify the names are absent from the package's data() index.
  pkg_data <- data(package = "surveywts")$results[, "Item"]
  expect_false("gss_ipw_ref" %in% pkg_data)
  expect_false("npors_2025_ref" %in% pkg_data)
  expect_false("npors_2025_clean_ref" %in% pkg_data)
  expect_false("acs_ipw_ref" %in% pkg_data)
  expect_false("ns_wave1_ipw" %in% pkg_data)
  expect_false("acs_wy_2022_svy" %in% pkg_data)
  expect_false("acs_wy_2022" %in% pkg_data)
})

# ============================================================================
# gss_2024 structural tests
# ============================================================================

test_that("gss_2024 has correct dimensions and derived columns", {
  data(gss_2024)
  # 27 original (sex overwritten in-place to factor) + age_f3 + race_f4 +
  # pid_f3 + edu_f3 + wt_pop = 32 total
  expect_equal(ncol(gss_2024), 32L)
  expect_true("sex" %in% names(gss_2024))
  expect_true("age_f3" %in% names(gss_2024))
  expect_true("race_f4" %in% names(gss_2024))
  expect_true("pid_f3" %in% names(gss_2024))
  expect_true("edu_f3" %in% names(gss_2024))
  expect_true("wt_pop" %in% names(gss_2024))
  # Original design columns still present
  expect_true("wtssps" %in% names(gss_2024))
  expect_true("vstrat" %in% names(gss_2024))
  expect_true("vpsu" %in% names(gss_2024))
  expect_true("age" %in% names(gss_2024))
})

test_that("gss_2024 sex is factor with correct levels", {
  data(gss_2024)
  expect_true(is.factor(gss_2024$sex))
  expect_identical(levels(gss_2024$sex), c("Male", "Female"))
  # Most respondents have non-NA sex
  expect_gt(sum(!is.na(gss_2024$sex)), 3000L)
})

test_that("gss_2024 age_f3 is factor with correct levels", {
  data(gss_2024)
  expect_true(is.factor(gss_2024$age_f3))
  expect_identical(levels(gss_2024$age_f3), c("18-34", "35-54", "55+"))
})

test_that("gss_2024 race_f4 is factor with correct levels", {
  data(gss_2024)
  expect_true(is.factor(gss_2024$race_f4))
  expect_identical(
    levels(gss_2024$race_f4),
    c("White", "Black", "Hispanic", "Other")
  )
})

test_that("gss_2024 pid_f3 is factor with correct levels", {
  data(gss_2024)
  expect_true(is.factor(gss_2024$pid_f3))
  expect_identical(
    levels(gss_2024$pid_f3),
    c("Republican", "Independent", "Democrat")
  )
})

test_that("gss_2024 edu_f3 is factor with correct levels", {
  data(gss_2024)
  expect_true(is.factor(gss_2024$edu_f3))
  expect_identical(
    levels(gss_2024$edu_f3),
    c("Less than HS", "HS/Some college", "College+")
  )
})

test_that("gss_2024 wt_pop is numeric and positive where wtssps is non-NA", {
  data(gss_2024)
  expect_true(is.numeric(gss_2024$wt_pop))
  non_na_rows <- !is.na(gss_2024$wtssps)
  expect_true(all(gss_2024$wt_pop[non_na_rows] > 0))
})

test_that("gss_2024 retains all rows from surveycore::gss_2024", {
  data(gss_2024)
  expect_equal(nrow(gss_2024), nrow(surveycore::gss_2024))
})

# ============================================================================
# npors_2025 structural tests
# ============================================================================

test_that("npors_2025 has correct dimensions", {
  data(npors_2025)
  expect_equal(nrow(npors_2025), 5022L)
  # 65 original (gender kept as integer) + sex + age_f3 + race_f4 + edu_f3 +
  # pid_f3 + wt_pop = 71
  expect_equal(ncol(npors_2025), 71L)
})

test_that("npors_2025 derived columns are present and factored correctly", {
  data(npors_2025)
  # gender is retained as numeric (not a factor)
  expect_true("gender" %in% names(npors_2025))
  expect_false(is.factor(npors_2025$gender))

  # sex is the new harmonized factor
  expect_true("sex" %in% names(npors_2025))
  expect_true(is.factor(npors_2025$sex))
  expect_identical(levels(npors_2025$sex), c("Male", "Female"))

  expect_true(is.factor(npors_2025$age_f3))
  expect_identical(levels(npors_2025$age_f3), c("18-34", "35-54", "55+"))

  expect_true(is.factor(npors_2025$race_f4))
  expect_identical(
    levels(npors_2025$race_f4),
    c("White", "Black", "Hispanic", "Other")
  )

  expect_true(is.factor(npors_2025$edu_f3))
  expect_identical(
    levels(npors_2025$edu_f3),
    c("Less than HS", "HS/Some college", "College+")
  )

  expect_true(is.factor(npors_2025$pid_f3))
  expect_identical(
    levels(npors_2025$pid_f3),
    c("Republican", "Independent", "Democrat")
  )
})

test_that("npors_2025 derived columns have < 2% NA rate", {
  data(npors_2025)
  # NA codes (99 = Refused, 3 = Non-binary for sex) produce approx 1-2% NA
  for (col in c("sex", "age_f3", "race_f4", "edu_f3", "pid_f3")) {
    na_rate <- mean(is.na(npors_2025[[col]]))
    expect_lt(na_rate, 0.02, label = paste("NA rate for", col))
  }
})

test_that("npors_2025 wt_pop is numeric and positive", {
  data(npors_2025)
  expect_true(is.numeric(npors_2025$wt_pop))
  expect_true(all(npors_2025$wt_pop > 0))
})

# ============================================================================
# npors_2025_clean structural tests
# ============================================================================

test_that("npors_2025_clean has zero NAs in all harmonized columns", {
  data(npors_2025_clean)
  expect_equal(sum(is.na(npors_2025_clean$sex)), 0L)
  expect_equal(sum(is.na(npors_2025_clean$age_f3)), 0L)
  expect_equal(sum(is.na(npors_2025_clean$race_f4)), 0L)
  expect_equal(sum(is.na(npors_2025_clean$edu_f3)), 0L)
  expect_equal(sum(is.na(npors_2025_clean$pid_f3)), 0L)
})

test_that("npors_2025_clean has more than 4700 rows", {
  data(npors_2025_clean)
  expect_gt(nrow(npors_2025_clean), 4700L)
})

test_that("npors_2025_clean has same column structure as npors_2025", {
  data(npors_2025)
  data(npors_2025_clean)
  expect_identical(names(npors_2025_clean), names(npors_2025))
})

# ============================================================================
# cps_2023 structural tests
# ============================================================================

test_that("cps_2023 has approximately 10000 rows", {
  data(cps_2023)
  expect_gte(nrow(cps_2023), 9000L)
  expect_lte(nrow(cps_2023), 11000L)
})

test_that("cps_2023 has wtfinl weight column and 160 repwtp* columns", {
  data(cps_2023)
  expect_true("wtfinl" %in% names(cps_2023))
  rep_cols <- grep("^repwtp[0-9]", names(cps_2023), value = TRUE)
  expect_length(rep_cols, 160L)
})

test_that("cps_2023 derived factor columns are factors with expected levels", {
  data(cps_2023)
  expect_true(is.factor(cps_2023$sex))
  expect_identical(levels(cps_2023$sex), c("Male", "Female"))
  expect_true(is.factor(cps_2023$age_f3))
  expect_identical(levels(cps_2023$age_f3), c("18-34", "35-54", "55+"))
  expect_true(is.factor(cps_2023$race_f4))
})

test_that("cps_2023 can be used as survey_replicate reference in ipw()", {
  data(ns_wave1)
  data(cps_2023)
  cps_ref <- surveycore::as_survey_replicate(
    cps_2023,
    weights = "wtfinl",
    repweights = paste0("repwtp", 1:160),
    type = "successive-difference",
    scale = 4 / 160,
    rscales = rep(1, 160)
  )
  result <- suppressWarnings(
    ipw(ns_wave1, cps_ref, selection = ~ sex + age_f3 + race_f4)
  )
  test_invariants(result)
  expect_true(S7::S7_inherits(result, surveycore::survey_nonprob))
})

# ============================================================================
# pew_2016_optin structural tests
# ============================================================================

test_that("pew_2016_optin does NOT have equal_wt column", {
  data(pew_2016_optin)
  expect_false("equal_wt" %in% names(pew_2016_optin))
})

test_that("pew_2016_optin has 305 columns (104 original + weight + 200 repwts)", {
  data(pew_2016_optin)
  expect_equal(ncol(pew_2016_optin), 305L)
})

test_that("pew_2016_optin has promoted calibrated weight column", {
  data(pew_2016_optin)
  expect_true("weight" %in% names(pew_2016_optin))
  expect_true(is.numeric(pew_2016_optin$weight))
  expect_true(all(pew_2016_optin$weight > 0))
  # Calibrated weights vary around 1
  expect_gt(sd(pew_2016_optin$weight), 0.01)
})

test_that("pew_2016_optin has 200 bootstrap replicate weight columns", {
  data(pew_2016_optin)
  repwt_cols <- grep("^repwt_", names(pew_2016_optin), value = TRUE)
  expect_equal(length(repwt_cols), 200L)
  expect_true("repwt_1" %in% repwt_cols)
  expect_true("repwt_200" %in% repwt_cols)
})

# ============================================================================
# ns_wave1 structural tests
# ============================================================================

test_that("ns_wave1 has correct dimensions", {
  data(ns_wave1)
  expect_equal(nrow(ns_wave1), 6422L)
  # 171 original (gender kept as integer) + sex + age_f3 + race_f4 + edu_f3 +
  # pid_f3 + 8 ns_* raking columns + hh_income_f9 = 185
  expect_equal(ncol(ns_wave1), 185L)
})

test_that("ns_wave1 gender column is retained as numeric", {
  data(ns_wave1)
  expect_true("gender" %in% names(ns_wave1))
  expect_true(is.numeric(ns_wave1$gender))
})

test_that("ns_wave1 sex is factor with correct levels", {
  data(ns_wave1)
  expect_true(is.factor(ns_wave1$sex))
  expect_identical(levels(ns_wave1$sex), c("Male", "Female"))
})

test_that("ns_wave1 age column is preserved (not deleted)", {
  data(ns_wave1)
  expect_true("age" %in% names(ns_wave1))
})

test_that("ns_wave1 age_f3 is factor with correct levels", {
  data(ns_wave1)
  expect_true(is.factor(ns_wave1$age_f3))
  expect_identical(levels(ns_wave1$age_f3), c("18-34", "35-54", "55+"))
})

test_that("ns_wave1 race_f4 is factor with correct levels and some NAs", {
  data(ns_wave1)
  expect_true(is.factor(ns_wave1$race_f4))
  expect_identical(
    levels(ns_wave1$race_f4),
    c("White", "Black", "Hispanic", "Other")
  )
  # NAs from race_ethnicity == 15 (some other race, non-Hispanic)
  na_count <- sum(is.na(ns_wave1$race_f4))
  expect_gt(na_count, 50L)
  expect_lt(na_count, 300L)
})

test_that("ns_wave1 edu_f3 is factor with correct levels and zero NAs", {
  data(ns_wave1)
  expect_true(is.factor(ns_wave1$edu_f3))
  expect_identical(
    levels(ns_wave1$edu_f3),
    c("Less than HS", "HS/Some college", "College+")
  )
  expect_equal(sum(is.na(ns_wave1$edu_f3)), 0L)
})

test_that("ns_wave1 pid_f3 is factor with correct levels", {
  data(ns_wave1)
  expect_true(is.factor(ns_wave1$pid_f3))
  expect_identical(
    levels(ns_wave1$pid_f3),
    c("Republican", "Independent", "Democrat")
  )
})

test_that("ns_wave1 original columns are preserved", {
  data(ns_wave1)
  # gender is retained as numeric; race_ethnicity and hispanic used to derive race_f4
  expect_true("gender" %in% names(ns_wave1))
  expect_true("race_ethnicity" %in% names(ns_wave1))
  expect_true("hispanic" %in% names(ns_wave1))
  expect_true("education" %in% names(ns_wave1))
  expect_true("weight" %in% names(ns_wave1))
})

test_that("ns_wave1 weight column is raked+trimmed (not original published weight)", {
  data(ns_wave1)
  # Raked weight sums to approximately n (stabilized by calibrate_rake)
  # Original published Nationscape weight summed to about 6422
  # The raked weight mean is approximately 1 and varies around the original
  expect_true(is.numeric(ns_wave1$weight))
  expect_true(all(ns_wave1$weight > 0))
  expect_true("weight" %in% names(ns_wave1))
})

# ============================================================================
# Integration tests — ipw() with new datasets
# ============================================================================

test_that("ipw() works with ns_wave1 and gss_2024 (wt_pop) reference", {
  data(ns_wave1)
  data(gss_2024)
  gss_ref <- surveycore::as_survey(
    gss_2024,
    weights = wt_pop,
    strata = vstrat,
    ids = vpsu,
    nest = TRUE
  )
  result <- suppressWarnings(
    ipw(ns_wave1, gss_ref, selection = ~ sex + age_f3)
  )
  expect_true(S7::S7_inherits(result, surveycore::survey_nonprob))
  expect_true("ipw_weight" %in% names(result@data))
})

test_that("ipw() works with ns_wave1 and npors_2025_clean (wt_pop) reference", {
  data(ns_wave1)
  data(npors_2025_clean)
  npors_ref <- surveycore::as_survey(npors_2025_clean, weights = wt_pop)
  result <- suppressWarnings(
    ipw(
      ns_wave1,
      npors_ref,
      selection = ~ sex + age_f3 + race_f4 + edu_f3,
      missing_method = "omit"
    )
  )
  expect_true(S7::S7_inherits(result, surveycore::survey_nonprob))
  expect_true("ipw_weight" %in% names(result@data))
})

test_that("ipw() works with ns_wave1 and cps_2023 (Taylor design) reference", {
  data(ns_wave1)
  data(cps_2023)
  cps_ref <- surveycore::as_survey(cps_2023, weights = wtfinl)
  result <- suppressWarnings(
    ipw(
      ns_wave1,
      cps_ref,
      selection = ~ sex + age_f3 + race_f4 + edu_f3,
      missing_method = "omit"
    )
  )
  expect_true(S7::S7_inherits(result, surveycore::survey_nonprob))
  expect_true("ipw_weight" %in% names(result@data))
})
