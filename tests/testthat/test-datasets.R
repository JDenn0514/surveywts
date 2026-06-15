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
  expect_no_error(data(acs_wy_2022, envir = new.env()))
  expect_no_error(data(ns_wave1, envir = new.env()))
  # Existing pew tibbles still loadable
  expect_no_error(data(pew_2016_optin, envir = new.env()))
  expect_no_error(data(pew_2016_synth_pop, envir = new.env()))
})

test_that("new survey companion datasets are loadable via data()", {
  expect_no_error(data(gss_2024_svy, envir = new.env()))
  expect_no_error(data(npors_2025_svy, envir = new.env()))
  expect_no_error(data(npors_2025_clean_svy, envir = new.env()))
  expect_no_error(data(acs_wy_2022_svy, envir = new.env()))
  expect_no_error(data(pew_2016_optin_svy, envir = new.env()))
  expect_no_error(data(pew_2016_synth_pop_svy, envir = new.env()))
  expect_no_error(data(ns_wave1_svy, envir = new.env()))
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
})

# ============================================================================
# gss_2024 structural tests
# ============================================================================

test_that("gss_2024 has correct dimensions and derived columns", {
  data(gss_2024)
  # 27 original + 3 derived (gender, age_group, wt_pop) = 30 total
  expect_equal(ncol(gss_2024), 30L)
  expect_true("gender" %in% names(gss_2024))
  expect_true("age_group" %in% names(gss_2024))
  expect_true("wt_pop" %in% names(gss_2024))
  # Original design columns still present
  expect_true("wtssps" %in% names(gss_2024))
  expect_true("vstrat" %in% names(gss_2024))
  expect_true("vpsu" %in% names(gss_2024))
  expect_true("sex" %in% names(gss_2024))
  expect_true("age" %in% names(gss_2024))
})

test_that("gss_2024 gender is factor with correct levels", {
  data(gss_2024)
  expect_true(is.factor(gss_2024$gender))
  expect_identical(levels(gss_2024$gender), c("Male", "Female"))
  # sex == 1 maps to Male
  sex1_rows <- !is.na(gss_2024$sex) & gss_2024$sex == 1L
  expect_true(all(as.character(gss_2024$gender[sex1_rows]) == "Male"))
  # sex == 2 maps to Female
  sex2_rows <- !is.na(gss_2024$sex) & gss_2024$sex == 2L
  expect_true(all(as.character(gss_2024$gender[sex2_rows]) == "Female"))
})

test_that("gss_2024 age_group is factor with correct levels", {
  data(gss_2024)
  expect_true(is.factor(gss_2024$age_group))
  expect_identical(levels(gss_2024$age_group), c("18-34", "35-54", "55+"))
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
# gss_2024_svy structural tests
# ============================================================================

test_that("gss_2024_svy is survey_taylor with correct row count", {
  data(gss_2024)
  data(gss_2024_svy)
  expect_true(S7::S7_inherits(gss_2024_svy, surveycore::survey_taylor))
  expect_equal(nrow(gss_2024_svy@data), nrow(gss_2024))
})

test_that("gss_2024_svy uses wtssps as weight column", {
  data(gss_2024_svy)
  expect_identical(gss_2024_svy@variables$weights, "wtssps")
})

# ============================================================================
# npors_2025 structural tests
# ============================================================================

test_that("npors_2025 has correct dimensions", {
  data(npors_2025)
  expect_equal(nrow(npors_2025), 5022L)
  # 65 source cols; gender already exists (overwritten in-place);
  # 4 new: age_group, race_ethn, educ, wt_pop => 65 + 4 = 69
  expect_equal(ncol(npors_2025), 69L)
})

test_that("npors_2025 derived columns are present and factored correctly", {
  data(npors_2025)
  expect_true("gender" %in% names(npors_2025))
  expect_true("age_group" %in% names(npors_2025))
  expect_true("race_ethn" %in% names(npors_2025))
  expect_true("educ" %in% names(npors_2025))
  expect_true("wt_pop" %in% names(npors_2025))

  expect_true(is.factor(npors_2025$gender))
  expect_identical(levels(npors_2025$gender), c("Male", "Female"))

  expect_true(is.factor(npors_2025$age_group))
  expect_identical(levels(npors_2025$age_group), c("18-34", "35-54", "55+"))

  expect_true(is.factor(npors_2025$race_ethn))
  expect_identical(
    levels(npors_2025$race_ethn),
    c("White", "Black", "Hispanic", "Asian", "Other")
  )

  expect_true(is.factor(npors_2025$educ))
  expect_identical(
    levels(npors_2025$educ),
    c("Less than HS", "HS/Some college", "College+")
  )
})

test_that("npors_2025 derived columns have < 2% NA rate", {
  data(npors_2025)
  # NA codes (99 = Refused, 3 = Non-binary for gender) produce approx 1-2% NA
  for (col in c("gender", "age_group", "race_ethn", "educ")) {
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
# npors_2025_svy structural tests
# ============================================================================

test_that("npors_2025_svy is survey_taylor with 5022 rows", {
  data(npors_2025_svy)
  expect_true(S7::S7_inherits(npors_2025_svy, surveycore::survey_taylor))
  expect_equal(nrow(npors_2025_svy@data), 5022L)
})

test_that("npors_2025_svy uses weight as weight column", {
  data(npors_2025_svy)
  expect_identical(npors_2025_svy@variables$weights, "weight")
})

# ============================================================================
# npors_2025_clean structural tests
# ============================================================================

test_that("npors_2025_clean has zero NAs in all derived columns", {
  data(npors_2025_clean)
  expect_equal(sum(is.na(npors_2025_clean$gender)), 0L)
  expect_equal(sum(is.na(npors_2025_clean$age_group)), 0L)
  expect_equal(sum(is.na(npors_2025_clean$race_ethn)), 0L)
  expect_equal(sum(is.na(npors_2025_clean$educ)), 0L)
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
# npors_2025_clean_svy structural tests
# ============================================================================

test_that("npors_2025_clean_svy is survey_taylor with matching row count", {
  data(npors_2025_clean)
  data(npors_2025_clean_svy)
  expect_true(
    S7::S7_inherits(npors_2025_clean_svy, surveycore::survey_taylor)
  )
  expect_equal(nrow(npors_2025_clean_svy@data), nrow(npors_2025_clean))
})

# ============================================================================
# acs_wy_2022 structural tests
# ============================================================================

test_that("acs_wy_2022 has correct row count (adults only)", {
  data(acs_wy_2022)
  expect_equal(nrow(acs_wy_2022), 4736L)
})

test_that("acs_wy_2022 all rows are adults (agep >= 18)", {
  data(acs_wy_2022)
  expect_true(all(acs_wy_2022$agep >= 18L))
})

test_that("acs_wy_2022 has pwgtp and 80 individual replicate weight columns", {
  data(acs_wy_2022)
  expect_true("pwgtp" %in% names(acs_wy_2022))
  rep_cols <- grep("^pwgtp[0-9]", names(acs_wy_2022), value = TRUE)
  expect_equal(length(rep_cols), 80L)
  expect_true("pwgtp1" %in% rep_cols)
  expect_true("pwgtp80" %in% rep_cols)
  # Main pwgtp should NOT be in rep_cols
  expect_false("pwgtp" %in% rep_cols)
})

test_that("acs_wy_2022 derived columns are factors with zero NAs", {
  data(acs_wy_2022)
  expect_true(is.factor(acs_wy_2022$gender))
  expect_identical(levels(acs_wy_2022$gender), c("Male", "Female"))
  expect_equal(sum(is.na(acs_wy_2022$gender)), 0L)

  expect_true(is.factor(acs_wy_2022$age_group))
  expect_identical(levels(acs_wy_2022$age_group), c("18-34", "35-54", "55+"))
  expect_equal(sum(is.na(acs_wy_2022$age_group)), 0L)

  expect_true(is.factor(acs_wy_2022$race_ethn))
  expect_identical(
    levels(acs_wy_2022$race_ethn),
    c("White", "Black", "Hispanic", "Asian", "Other")
  )
  expect_equal(sum(is.na(acs_wy_2022$race_ethn)), 0L)

  expect_true(is.factor(acs_wy_2022$educ))
  expect_identical(
    levels(acs_wy_2022$educ),
    c("Less than HS", "HS/Some college", "College+")
  )
  expect_equal(sum(is.na(acs_wy_2022$educ)), 0L)
})

# ============================================================================
# acs_wy_2022_svy structural tests
# ============================================================================

test_that("acs_wy_2022_svy is survey_replicate with 4736 rows", {
  data(acs_wy_2022_svy)
  expect_true(
    S7::S7_inherits(acs_wy_2022_svy, surveycore::survey_replicate)
  )
  expect_equal(nrow(acs_wy_2022_svy@data), 4736L)
})

test_that("acs_wy_2022_svy uses pwgtp as weight column", {
  data(acs_wy_2022_svy)
  expect_identical(acs_wy_2022_svy@variables$weights, "pwgtp")
})

test_that("acs_wy_2022_svy has 80 replicate weight columns", {
  data(acs_wy_2022_svy)
  rep_wts <- acs_wy_2022_svy@variables$repweights
  expect_equal(length(rep_wts), 80L)
})

test_that("acs_wy_2022_svy cannot be passed to ipw() — throws correct error", {
  data(ns_wave1)
  data(acs_wy_2022_svy)
  expect_error(
    ipw(ns_wave1, acs_wy_2022_svy, selection = ~gender + age_group),
    class = "surveywts_error_svydesign_not_taylor"
  )
})

# ============================================================================
# pew_2016_optin_svy structural tests
# ============================================================================

test_that("pew_2016_optin_svy is survey_nonprob with 31863 rows", {
  data(pew_2016_optin_svy)
  expect_true(
    S7::S7_inherits(pew_2016_optin_svy, surveycore::survey_nonprob)
  )
  expect_equal(nrow(pew_2016_optin_svy@data), 31863L)
})

test_that("pew_2016_optin does NOT have equal_wt column", {
  data(pew_2016_optin)
  expect_false("equal_wt" %in% names(pew_2016_optin))
})

test_that("pew_2016_optin_svy weights are all 1", {
  data(pew_2016_optin_svy)
  wt_col <- pew_2016_optin_svy@variables$weights
  expect_true(all(pew_2016_optin_svy@data[[wt_col]] == 1L))
})

# ============================================================================
# pew_2016_synth_pop_svy structural tests
# ============================================================================

test_that("pew_2016_synth_pop_svy is survey_taylor with 20000 rows", {
  data(pew_2016_synth_pop_svy)
  expect_true(
    S7::S7_inherits(pew_2016_synth_pop_svy, surveycore::survey_taylor)
  )
  expect_equal(nrow(pew_2016_synth_pop_svy@data), 20000L)
})

test_that("pew_2016_synth_pop_svy weights are all 1", {
  data(pew_2016_synth_pop_svy)
  wt_col <- pew_2016_synth_pop_svy@variables$weights
  expect_true(all(pew_2016_synth_pop_svy@data[[wt_col]] == 1L))
})

# ============================================================================
# ns_wave1 structural tests
# ============================================================================

test_that("ns_wave1 has correct dimensions", {
  data(ns_wave1)
  expect_equal(nrow(ns_wave1), 6422L)
  # 171 original; gender overwritten in-place; 3 new: age_group, race_ethn, educ
  expect_equal(ncol(ns_wave1), 174L)
})

test_that("ns_wave1 gender is factor with correct levels", {
  data(ns_wave1)
  expect_true(is.factor(ns_wave1$gender))
  expect_identical(levels(ns_wave1$gender), c("Male", "Female"))
})

test_that("ns_wave1 age column is preserved (not deleted)", {
  data(ns_wave1)
  expect_true("age" %in% names(ns_wave1))
})

test_that("ns_wave1 age_group is factor with correct levels", {
  data(ns_wave1)
  expect_true(is.factor(ns_wave1$age_group))
  expect_identical(levels(ns_wave1$age_group), c("18-34", "35-54", "55+"))
})

test_that("ns_wave1 race_ethn is factor with correct levels and ~419 NAs", {
  data(ns_wave1)
  expect_true(is.factor(ns_wave1$race_ethn))
  expect_identical(
    levels(ns_wave1$race_ethn),
    c("White", "Black", "Hispanic", "Asian", "Other")
  )
  # NAs from race_ethnicity == 15 (some other race, non-Hispanic)
  na_count <- sum(is.na(ns_wave1$race_ethn))
  expect_gt(na_count, 50L)
  expect_lt(na_count, 600L)
})

test_that("ns_wave1 educ is factor with correct levels and zero NAs", {
  data(ns_wave1)
  expect_true(is.factor(ns_wave1$educ))
  expect_identical(
    levels(ns_wave1$educ),
    c("Less than HS", "HS/Some college", "College+")
  )
  expect_equal(sum(is.na(ns_wave1$educ)), 0L)
})

test_that("ns_wave1 original columns are preserved", {
  data(ns_wave1)
  # gender was overwritten in-place (integer -> factor), but these remain
  expect_true("race_ethnicity" %in% names(ns_wave1))
  expect_true("hispanic" %in% names(ns_wave1))
  expect_true("education" %in% names(ns_wave1))
  expect_true("weight" %in% names(ns_wave1))
})

# ============================================================================
# ns_wave1_svy structural tests
# ============================================================================

test_that("ns_wave1_svy is survey_nonprob with 6422 rows", {
  data(ns_wave1_svy)
  expect_true(S7::S7_inherits(ns_wave1_svy, surveycore::survey_nonprob))
  expect_equal(nrow(ns_wave1_svy@data), 6422L)
})

test_that("ns_wave1_svy uses weight as weight column", {
  data(ns_wave1_svy)
  expect_identical(ns_wave1_svy@variables$weights, "weight")
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
    ipw(ns_wave1, gss_ref, selection = ~gender + age_group)
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
      selection = ~gender + age_group + race_ethn + educ,
      missing_method = "omit"
    )
  )
  expect_true(S7::S7_inherits(result, surveycore::survey_nonprob))
  expect_true("ipw_weight" %in% names(result@data))
})

test_that("ipw() works with ns_wave1 and acs_wy_2022 (Taylor design) reference", {
  data(ns_wave1)
  data(acs_wy_2022)
  acs_ref <- surveycore::as_survey(acs_wy_2022, weights = pwgtp)
  result <- suppressWarnings(
    ipw(
      ns_wave1,
      acs_ref,
      selection = ~gender + age_group + race_ethn + educ,
      missing_method = "omit"
    )
  )
  expect_true(S7::S7_inherits(result, surveycore::survey_nonprob))
  expect_true("ipw_weight" %in% names(result@data))
})
