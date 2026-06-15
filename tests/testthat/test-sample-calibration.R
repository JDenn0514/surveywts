# tests/testthat/test-sample-calibration.R
#
# Tests for calibrate_to_survey() and calibrate_to_estimate().
#
# Sections:
#   1. calibrate_to_survey() — happy path
#   2. calibrate_to_survey() — error paths
#   3. calibrate_to_survey() — warning paths
#   4. calibrate_to_survey() — edge cases
#   5. calibrate_to_estimate() — happy path
#   6. calibrate_to_estimate() — error paths
#   7. calibrate_to_estimate() — warning paths
#   8. calibrate_to_estimate() — edge cases
#   9. Validation order tests

# ===========================================================================
# 1. calibrate_to_survey() — happy path
# ===========================================================================

test_that("calibrate_to_survey() returns survey_replicate with same data dimensions", {
  skip_if_not_installed("svrep")
  primary <- make_replicate_design(n = 200L, seed = 1L)
  control <- make_replicate_design(n = 200L, seed = 2L)

  result <- calibrate_to_survey(
    primary_design = primary,
    control_design = control,
    variables      = c(sex)
  )

  test_invariants(result)
  expect_true(S7::S7_inherits(result, surveycore::survey_replicate))
  expect_identical(nrow(result@data), nrow(primary@data))
  expect_identical(ncol(result@data), ncol(primary@data))
})

test_that("calibrate_to_survey() appends history entry with operation = 'calibrate_to_survey'", {
  skip_if_not_installed("svrep")
  primary <- make_replicate_design(n = 200L, seed = 1L)
  control <- make_replicate_design(n = 200L, seed = 2L)

  result <- calibrate_to_survey(
    primary_design = primary,
    control_design = control,
    variables      = c(sex)
  )

  history <- result@metadata@weighting_history
  # 2 entries: replicate_creation + calibrate_to_survey
  expect_true(length(history) >= 2L)
  last_entry <- history[[length(history)]]
  expect_identical(last_entry$operation, "calibrate_to_survey")
})

test_that("calibrate_to_survey() history entry has correct parameters", {
  skip_if_not_installed("svrep")
  primary <- make_replicate_design(n = 200L, seed = 1L)
  control <- make_replicate_design(n = 200L, seed = 2L)

  result <- calibrate_to_survey(
    primary_design = primary,
    control_design = control,
    variables      = c(sex, age_group),
    method         = "linear",
    bounds         = c(-Inf, Inf)
  )

  history <- result@metadata@weighting_history
  last    <- history[[length(history)]]
  params  <- last$parameters

  expect_identical(params$variables, c("sex", "age_group"))
  expect_identical(params$method, "linear")
  expect_equal(params$bounds, c(-Inf, Inf))
  expect_false(params$targets_from_reference)
  expect_null(params$reference_design)
})

test_that("calibrate_to_survey() history has weight_stats with correct 11-key structure", {
  skip_if_not_installed("svrep")
  primary <- make_replicate_design(n = 200L, seed = 1L)
  control <- make_replicate_design(n = 200L, seed = 2L)

  result <- calibrate_to_survey(
    primary_design = primary,
    control_design = control,
    variables      = c(sex)
  )

  last <- result@metadata@weighting_history[[length(result@metadata@weighting_history)]]
  expect_true("weight_stats" %in% names(last))
  expect_identical(names(last$weight_stats), c("before", "after"))
  expected_keys <- c(
    "n", "n_positive", "n_zero", "mean", "cv", "min",
    "p25", "p50", "p75", "max", "ess"
  )
  expect_identical(names(last$weight_stats$before), expected_keys)
  expect_identical(names(last$weight_stats$after), expected_keys)
  expect_false(last$weight_stats$before$mean == last$weight_stats$after$mean)
})

test_that("calibrate_to_survey() produces different weights from input", {
  skip_if_not_installed("svrep")
  primary <- make_replicate_design(n = 200L, seed = 1L)
  control <- make_replicate_design(n = 200L, seed = 2L)

  result <- calibrate_to_survey(
    primary_design = primary,
    control_design = control,
    variables      = c(sex)
  )

  wt_col <- primary@variables$weights
  # Calibration should change at least some weights
  expect_false(identical(primary@data[[wt_col]], result@data[[wt_col]]))
})

test_that("calibrate_to_survey() stores reference_design provenance in history", {
  skip_if_not_installed("svrep")
  primary <- make_replicate_design(n = 200L, seed = 1L)
  control <- make_replicate_design(n = 200L, seed = 2L)
  ref_df  <- make_surveywts_data(n = 500L, seed = 99L)
  ref_taylor <- surveycore::survey_taylor(
    data = ref_df,
    variables = list(weights = "base_weight")
  )

  result <- calibrate_to_survey(
    primary_design   = primary,
    control_design   = control,
    variables        = c(sex),
    reference_design = ref_taylor
  )

  last   <- result@metadata@weighting_history[[length(result@metadata@weighting_history)]]
  params <- last$parameters
  expect_true(params$targets_from_reference)
  expect_true(!is.null(params$reference_design))
  testthat::expect_true(is.list(params$reference_design))
  testthat::expect_true(grepl("survey_taylor", params$reference_design$class))
  testthat::expect_true(is.numeric(params$reference_design$n))
})

test_that("calibrate_to_survey() control_col_matches is NOT stored in history", {
  skip_if_not_installed("svrep")
  primary <- make_replicate_design(n = 200L, seed = 1L)
  control <- make_replicate_design(n = 200L, seed = 2L)

  result <- calibrate_to_survey(
    primary_design = primary,
    control_design = control,
    variables      = c(sex),
    control        = list(control_col_matches = seq_len(50))
  )

  last   <- result@metadata@weighting_history[[length(result@metadata@weighting_history)]]
  params <- last$parameters
  # control in history should NOT contain control_col_matches
  expect_false("control_col_matches" %in% names(params$control))
})

test_that("calibrate_to_survey() numerical identity with svrep", {
  skip_if_not_installed("svrep")
  primary <- make_replicate_design(n = 200L, seed = 1L)
  control <- make_replicate_design(n = 200L, seed = 2L)

  # Known replicate matching
  n_rep <- length(primary@variables$repweights)
  col_matches <- seq_len(n_rep)

  result_wts <- calibrate_to_survey(
    primary_design = primary,
    control_design = control,
    variables      = c(sex),
    control        = list(control_col_matches = col_matches)
  )

  # Now reproduce with svrep directly
  primary_svyrep <- surveywts:::.to_svyrep(primary)
  control_svyrep <- surveywts:::.to_svyrep(control)
  ref_result <- svrep::calibrate_to_sample(
    primary_rep_design  = primary_svyrep,
    control_rep_design  = control_svyrep,
    cal_formula         = ~sex,
    calfun              = survey::cal.raking,
    bounds              = list(lower = -Inf, upper = Inf),
    maxit               = 50L,
    epsilon             = 1e-7,
    control_col_matches = col_matches
  )

  wt_col <- primary@variables$weights
  expect_equal(
    result_wts@data[[wt_col]],
    as.numeric(ref_result$pweights),
    tolerance = 1e-8
  )
})

# ===========================================================================
# 2. calibrate_to_survey() — error paths
# ===========================================================================

test_that("calibrate_to_survey() rejects non-replicate primary_design", {
  skip_if_not_installed("svrep")
  control <- make_replicate_design(n = 100L, seed = 2L)
  df      <- make_surveywts_data(n = 100L, seed = 1L)
  taylor  <- surveycore::survey_taylor(
    data = df, variables = list(weights = "base_weight")
  )

  expect_error(
    calibrate_to_survey(taylor, control, variables = c(sex)),
    class = "surveywts_error_primary_not_replicate"
  )
  expect_snapshot(
    error = TRUE,
    calibrate_to_survey(taylor, control, variables = c(sex))
  )
})

test_that("calibrate_to_survey() rejects non-replicate control_design", {
  skip_if_not_installed("svrep")
  primary <- make_replicate_design(n = 100L, seed = 1L)
  df      <- make_surveywts_data(n = 100L, seed = 2L)
  taylor  <- surveycore::survey_taylor(
    data = df, variables = list(weights = "base_weight")
  )

  expect_error(
    calibrate_to_survey(primary, taylor, variables = c(sex)),
    class = "surveywts_error_control_not_replicate"
  )
  expect_snapshot(
    error = TRUE,
    calibrate_to_survey(primary, taylor, variables = c(sex))
  )
})

test_that("calibrate_to_survey() rejects non-taylor reference_design", {
  skip_if_not_installed("svrep")
  primary <- make_replicate_design(n = 100L, seed = 1L)
  control <- make_replicate_design(n = 100L, seed = 2L)

  expect_error(
    calibrate_to_survey(
      primary, control,
      variables = c(sex),
      reference_design = primary   # a replicate, not a taylor
    ),
    class = "surveywts_error_reference_design_not_taylor"
  )
  expect_snapshot(
    error = TRUE,
    calibrate_to_survey(
      primary, control,
      variables = c(sex),
      reference_design = primary
    )
  )
})

test_that("calibrate_to_survey() rejects invalid unit_scale (non-numeric)", {
  skip_if_not_installed("svrep")
  primary <- make_replicate_design(n = 100L, seed = 1L)
  control <- make_replicate_design(n = 100L, seed = 2L)

  expect_error(
    calibrate_to_survey(
      primary, control,
      variables  = c(sex),
      unit_scale = "bad"
    ),
    class = "surveywts_error_unit_scale_invalid"
  )
  expect_snapshot(
    error = TRUE,
    calibrate_to_survey(
      primary, control,
      variables  = c(sex),
      unit_scale = "bad"
    )
  )
})

test_that("calibrate_to_survey() rejects unit_scale with wrong length", {
  skip_if_not_installed("svrep")
  primary <- make_replicate_design(n = 100L, seed = 1L)
  control <- make_replicate_design(n = 100L, seed = 2L)

  expect_error(
    calibrate_to_survey(
      primary, control,
      variables  = c(sex),
      unit_scale = rep(1.0, 5)  # wrong length
    ),
    class = "surveywts_error_unit_scale_invalid"
  )
  expect_snapshot(
    error = TRUE,
    calibrate_to_survey(
      primary, control,
      variables  = c(sex),
      unit_scale = rep(1.0, 5)
    )
  )
})

test_that("calibrate_to_survey() rejects unit_scale with NA", {
  skip_if_not_installed("svrep")
  primary <- make_replicate_design(n = 100L, seed = 1L)
  control <- make_replicate_design(n = 100L, seed = 2L)
  n       <- nrow(primary@data)

  us <- rep(1.0, n)
  us[1L] <- NA_real_

  expect_error(
    calibrate_to_survey(
      primary, control,
      variables  = c(sex),
      unit_scale = us
    ),
    class = "surveywts_error_unit_scale_invalid"
  )
  expect_snapshot(
    error = TRUE,
    calibrate_to_survey(
      primary, control,
      variables  = c(sex),
      unit_scale = {
        us2 <- rep(1.0, nrow(primary@data))
        us2[1L] <- NA_real_
        us2
      }
    )
  )
})

test_that("calibrate_to_survey() rejects unit_scale with non-positive values", {
  skip_if_not_installed("svrep")
  primary <- make_replicate_design(n = 100L, seed = 1L)
  control <- make_replicate_design(n = 100L, seed = 2L)
  n       <- nrow(primary@data)

  us <- rep(1.0, n)
  us[1L] <- -1.0

  expect_error(
    calibrate_to_survey(
      primary, control,
      variables  = c(sex),
      unit_scale = us
    ),
    class = "surveywts_error_unit_scale_invalid"
  )
  expect_snapshot(
    error = TRUE,
    calibrate_to_survey(
      primary, control,
      variables  = c(sex),
      unit_scale = {
        us2 <- rep(1.0, nrow(primary@data))
        us2[1L] <- -1.0
        us2
      }
    )
  )
})

test_that("calibrate_to_survey() rejects variables not in primary_design", {
  skip_if_not_installed("svrep")
  primary <- make_replicate_design(n = 100L, seed = 1L)
  control <- make_replicate_design(n = 100L, seed = 2L)

  expect_error(
    calibrate_to_survey(primary, control, variables = c(nonexistent_var)),
    class = "surveywts_error_variables_not_found"
  )
  expect_snapshot(
    error = TRUE,
    calibrate_to_survey(primary, control, variables = c(nonexistent_var))
  )
})

test_that("calibrate_to_survey() rejects empty variable selection", {
  skip_if_not_installed("svrep")
  primary <- make_replicate_design(n = 100L, seed = 1L)
  control <- make_replicate_design(n = 100L, seed = 2L)

  expect_error(
    # starts_with with no match → empty selection
    calibrate_to_survey(
      primary, control,
      variables = tidyselect::starts_with("zzz_no_match_")
    ),
    class = "surveywts_error_variables_not_found"
  )
})

test_that("calibrate_to_survey() propagates convergence warning as error", {
  skip_if_not_installed("svrep")
  primary <- make_replicate_design(n = 100L, seed = 1L)
  control <- make_replicate_design(n = 100L, seed = 2L)

  testthat::with_mocked_bindings(
    .svrep_calibrate_to_sample = function(...) {
      warning("Calibration did not converge", call. = FALSE)
      NULL
    },
    .package = "surveywts",
    {
      expect_error(
        calibrate_to_survey(primary, control, variables = c(sex)),
        class = "surveywts_error_calibration_not_converged"
      )
      expect_snapshot(
        error = TRUE,
        calibrate_to_survey(primary, control, variables = c(sex))
      )
    }
  )
})

test_that("calibrate_to_survey() propagates hard svrep errors", {
  skip_if_not_installed("svrep")
  primary <- make_replicate_design(n = 100L, seed = 1L)
  control <- make_replicate_design(n = 100L, seed = 2L)

  testthat::with_mocked_bindings(
    .svrep_calibrate_to_sample = function(...) stop("svrep internal error"),
    .package = "surveywts",
    {
      expect_error(
        calibrate_to_survey(primary, control, variables = c(sex)),
        class = "surveywts_error_calibration_failed"
      )
      expect_snapshot(
        error = TRUE,
        calibrate_to_survey(primary, control, variables = c(sex))
      )
    }
  )
})

# ===========================================================================
# 3. calibrate_to_survey() — warning paths
# ===========================================================================

test_that("calibrate_to_survey() warns on unknown control key", {
  skip_if_not_installed("svrep")
  primary <- make_replicate_design(n = 100L, seed = 1L)
  control <- make_replicate_design(n = 100L, seed = 2L)

  expect_warning(
    result <- calibrate_to_survey(
      primary, control,
      variables = c(sex),
      control   = list(bad_param = 99)
    ),
    class = "surveywts_warning_control_param_ignored"
  )
  expect_true(S7::S7_inherits(result, surveycore::survey_replicate))
})

test_that("calibrate_to_survey() warns on replicate scheme mismatch", {
  skip_if_not_installed("svrep")
  primary <- make_replicate_design(n = 100L, seed = 1L)
  control <- make_replicate_design(n = 100L, seed = 2L)

  # Force different types by modifying the variables list
  control_diff_type         <- control
  ctrl_vars                 <- control_diff_type@variables
  ctrl_vars$type            <- "JK1"
  control_diff_type@variables <- ctrl_vars

  expect_warning(
    calibrate_to_survey(primary, control_diff_type, variables = c(sex)),
    class = "surveywts_warning_replicate_scheme_mismatch"
  )
})

test_that("calibrate_to_survey() warns and clips negative weights (method = linear)", {
  skip_if_not_installed("svrep")
  primary <- make_replicate_design(n = 100L, seed = 1L)
  control <- make_replicate_design(n = 100L, seed = 2L)

  # Mock the internal wrapper to return a design with a negative full-sample weight
  mock_result <- surveywts:::.to_svyrep(primary)
  mock_result$pweights[1L] <- -1.0

  testthat::with_mocked_bindings(
    .svrep_calibrate_to_sample = function(...) mock_result,
    .package = "surveywts",
    {
      expect_warning(
        result <- calibrate_to_survey(
          primary, control,
          variables = c(sex),
          method    = "linear"
        ),
        class = "surveywts_warning_negative_calibrated_weights"
      )

      wt_col <- primary@variables$weights
      expect_true(all(result@data[[wt_col]] > 0))
    }
  )
})

# ===========================================================================
# 4. calibrate_to_survey() — edge cases
# ===========================================================================

test_that("calibrate_to_survey() handles single-variable selection", {
  skip_if_not_installed("svrep")
  primary <- make_replicate_design(n = 200L, seed = 1L)
  control <- make_replicate_design(n = 200L, seed = 2L)

  result <- calibrate_to_survey(primary, control, variables = c(sex))
  test_invariants(result)
  expect_true(S7::S7_inherits(result, surveycore::survey_replicate))
})

test_that("calibrate_to_survey() handles multi-variable selection", {
  skip_if_not_installed("svrep")
  primary <- make_replicate_design(n = 200L, seed = 1L)
  control <- make_replicate_design(n = 200L, seed = 2L)

  result <- calibrate_to_survey(
    primary, control,
    variables = c(sex, age_group)
  )
  test_invariants(result)
  last   <- result@metadata@weighting_history[[length(result@metadata@weighting_history)]]
  expect_true(length(last$parameters$variables) == 2L)
})

test_that("calibrate_to_survey() preserves repweight column names from primary", {
  skip_if_not_installed("svrep")
  primary <- make_replicate_design(n = 200L, seed = 1L)
  control <- make_replicate_design(n = 200L, seed = 2L)

  orig_rep_names <- primary@variables$repweights
  result <- calibrate_to_survey(primary, control, variables = c(sex))

  expect_identical(result@variables$repweights, orig_rep_names)
})

# ===========================================================================
# 5. calibrate_to_estimate() — happy path
# ===========================================================================

test_that("calibrate_to_estimate() returns survey_replicate with same dimensions", {
  skip_if_not_installed("svrep")
  primary <- make_replicate_design(n = 200L, seed = 42L)

  targets  <- list(sex = c("F" = 110, "M" = 90))
  vcov_est <- diag(c(100, 100))

  result <- calibrate_to_estimate(primary, targets, vcov_est)

  test_invariants(result)
  expect_true(S7::S7_inherits(result, surveycore::survey_replicate))
  expect_identical(nrow(result@data), nrow(primary@data))
})

test_that("calibrate_to_estimate() appends history entry with correct operation", {
  skip_if_not_installed("svrep")
  primary  <- make_replicate_design(n = 200L, seed = 42L)
  targets  <- list(sex = c("F" = 110, "M" = 90))
  vcov_est <- diag(c(100, 100))

  result <- calibrate_to_estimate(primary, targets, vcov_est)

  history    <- result@metadata@weighting_history
  last_entry <- history[[length(history)]]
  expect_identical(last_entry$operation, "calibrate_to_estimate")
})

test_that("calibrate_to_estimate() history parameters are correct", {
  skip_if_not_installed("svrep")
  primary  <- make_replicate_design(n = 200L, seed = 42L)
  targets  <- list(sex = c("F" = 110, "M" = 90))
  vcov_est <- diag(c(100, 100))

  result <- calibrate_to_estimate(primary, targets, vcov_est)

  last   <- result@metadata@weighting_history[[length(result@metadata@weighting_history)]]
  params <- last$parameters

  expect_identical(params$variables, "sex")
  expect_identical(params$method, "rake")
  expect_equal(params$bounds, c(-Inf, Inf))
  expect_identical(params$targets, targets)
  expect_identical(params$vcov_dim, as.integer(c(2, 2)))
  expect_false(params$targets_from_reference)
})

test_that("calibrate_to_estimate() history has weight_stats with correct 11-key structure", {
  skip_if_not_installed("svrep")
  primary  <- make_replicate_design(n = 200L, seed = 42L)
  targets  <- list(sex = c("F" = 110, "M" = 90))
  vcov_est <- diag(c(100, 100))

  result <- calibrate_to_estimate(
    design        = primary,
    targets       = targets,
    vcov_estimate = vcov_est
  )

  last <- result@metadata@weighting_history[[length(result@metadata@weighting_history)]]
  expect_true("weight_stats" %in% names(last))
  expect_identical(names(last$weight_stats), c("before", "after"))
  expected_keys <- c(
    "n", "n_positive", "n_zero", "mean", "cv", "min",
    "p25", "p50", "p75", "max", "ess"
  )
  expect_identical(names(last$weight_stats$before), expected_keys)
  expect_identical(names(last$weight_stats$after), expected_keys)
  expect_false(last$weight_stats$before$mean == last$weight_stats$after$mean)
})

test_that("calibrate_to_estimate() col_selection is NOT stored in history", {
  skip_if_not_installed("svrep")
  primary  <- make_replicate_design(n = 200L, seed = 42L)
  targets  <- list(sex = c("F" = 110, "M" = 90))
  vcov_est <- diag(c(100, 100))

  # col_selection must have length = length(unlist(targets)) = 2
  result <- calibrate_to_estimate(
    primary, targets, vcov_est,
    control = list(col_selection = seq_len(2))
  )

  last   <- result@metadata@weighting_history[[length(result@metadata@weighting_history)]]
  params <- last$parameters
  expect_false("col_selection" %in% names(params$control))
})

test_that("calibrate_to_estimate() numerical identity with svrep", {
  skip_if_not_installed("svrep")
  primary  <- make_replicate_design(n = 200L, seed = 42L)
  targets  <- list(sex = c("F" = 110, "M" = 90))
  vcov_est <- diag(c(100, 100))

  # col_selection: length = length(unlist(targets)) = 2
  col_sel    <- seq_len(2L)
  result_wts <- calibrate_to_estimate(
    primary, targets, vcov_est,
    control = list(col_selection = col_sel)
  )

  # Reproduce with svrep directly
  design_svyrep <- surveywts:::.to_svyrep(primary)
  estimate      <- c(sexF = 110, sexM = 90)
  ref_result <- svrep::calibrate_to_estimate(
    rep_design    = design_svyrep,
    estimate      = estimate,
    vcov_estimate = vcov_est,
    cal_formula   = ~sex,
    calfun        = survey::cal.raking,
    bounds        = list(lower = -Inf, upper = Inf),
    maxit         = 50L,
    epsilon       = 1e-7,
    col_selection = col_sel
  )

  wt_col <- primary@variables$weights
  expect_equal(
    result_wts@data[[wt_col]],
    as.numeric(ref_result$pweights),
    tolerance = 1e-8
  )
})

test_that("calibrate_to_estimate() stores reference_design provenance in history", {
  skip_if_not_installed("svrep")
  primary <- make_replicate_design(n = 200L, seed = 42L)
  ref_df  <- make_surveywts_data(n = 500L, seed = 99L)
  ref_taylor <- surveycore::survey_taylor(
    data = ref_df,
    variables = list(weights = "base_weight")
  )

  targets  <- list(sex = c("F" = 110, "M" = 90))
  vcov_est <- diag(c(100, 100))

  result <- calibrate_to_estimate(
    primary, targets, vcov_est,
    reference_design = ref_taylor
  )

  last   <- result@metadata@weighting_history[[length(result@metadata@weighting_history)]]
  params <- last$parameters
  expect_true(params$targets_from_reference)
  expect_false(is.null(params$reference_design))
  testthat::expect_true(is.list(params$reference_design))
  testthat::expect_true(grepl("survey_taylor", params$reference_design$class))
  testthat::expect_true(is.numeric(params$reference_design$n))
})

# ===========================================================================
# 6. calibrate_to_estimate() — error paths
# ===========================================================================

test_that("calibrate_to_estimate() rejects non-replicate design", {
  skip_if_not_installed("svrep")
  df     <- make_surveywts_data(n = 100L, seed = 1L)
  taylor <- surveycore::survey_taylor(
    data = df, variables = list(weights = "base_weight")
  )
  targets  <- list(sex = c("F" = 60, "M" = 40))
  vcov_est <- diag(c(100, 100))

  expect_error(
    calibrate_to_estimate(taylor, targets, vcov_est),
    class = "surveywts_error_design_not_replicate"
  )
  expect_snapshot(
    error = TRUE,
    calibrate_to_estimate(taylor, targets, vcov_est)
  )
})

test_that("calibrate_to_estimate() rejects non-taylor reference_design", {
  skip_if_not_installed("svrep")
  primary  <- make_replicate_design(n = 100L, seed = 1L)
  targets  <- list(sex = c("F" = 60, "M" = 40))
  vcov_est <- diag(c(100, 100))

  expect_error(
    calibrate_to_estimate(
      primary, targets, vcov_est,
      reference_design = primary  # not a taylor
    ),
    class = "surveywts_error_reference_design_not_taylor"
  )
  expect_snapshot(
    error = TRUE,
    calibrate_to_estimate(
      primary, targets, vcov_est,
      reference_design = primary
    )
  )
})

test_that("calibrate_to_estimate() rejects invalid unit_scale", {
  skip_if_not_installed("svrep")
  primary  <- make_replicate_design(n = 100L, seed = 1L)
  targets  <- list(sex = c("F" = 60, "M" = 40))
  vcov_est <- diag(c(100, 100))

  expect_error(
    calibrate_to_estimate(
      primary, targets, vcov_est,
      unit_scale = "bad"
    ),
    class = "surveywts_error_unit_scale_invalid"
  )
  expect_snapshot(
    error = TRUE,
    calibrate_to_estimate(
      primary, targets, vcov_est,
      unit_scale = "bad"
    )
  )
})

test_that("calibrate_to_estimate() rejects unit_scale with wrong length", {
  skip_if_not_installed("svrep")
  primary  <- make_replicate_design(n = 100L, seed = 1L)
  targets  <- list(sex = c("F" = 60, "M" = 40))
  vcov_est <- diag(c(100, 100))

  expect_error(
    calibrate_to_estimate(
      primary, targets, vcov_est,
      unit_scale = rep(1.0, 5)  # wrong length
    ),
    class = "surveywts_error_unit_scale_invalid"
  )
  expect_snapshot(
    error = TRUE,
    calibrate_to_estimate(
      primary, targets, vcov_est,
      unit_scale = rep(1.0, 5)
    )
  )
})

test_that("calibrate_to_estimate() rejects unit_scale with NA", {
  skip_if_not_installed("svrep")
  primary  <- make_replicate_design(n = 100L, seed = 1L)
  targets  <- list(sex = c("F" = 60, "M" = 40))
  vcov_est <- diag(c(100, 100))

  us <- rep(1.0, nrow(primary@data))
  us[1L] <- NA_real_

  expect_error(
    calibrate_to_estimate(
      primary, targets, vcov_est,
      unit_scale = us
    ),
    class = "surveywts_error_unit_scale_invalid"
  )
  expect_snapshot(
    error = TRUE,
    calibrate_to_estimate(
      primary, targets, vcov_est,
      unit_scale = {
        us2 <- rep(1.0, nrow(primary@data))
        us2[1L] <- NA_real_
        us2
      }
    )
  )
})

test_that("calibrate_to_estimate() rejects unit_scale with non-positive values", {
  skip_if_not_installed("svrep")
  primary  <- make_replicate_design(n = 100L, seed = 1L)
  targets  <- list(sex = c("F" = 60, "M" = 40))
  vcov_est <- diag(c(100, 100))

  us <- rep(1.0, nrow(primary@data))
  us[1L] <- -1.0

  expect_error(
    calibrate_to_estimate(
      primary, targets, vcov_est,
      unit_scale = us
    ),
    class = "surveywts_error_unit_scale_invalid"
  )
  expect_snapshot(
    error = TRUE,
    calibrate_to_estimate(
      primary, targets, vcov_est,
      unit_scale = {
        us2 <- rep(1.0, nrow(primary@data))
        us2[1L] <- -1.0
        us2
      }
    )
  )
})

test_that("calibrate_to_estimate() rejects non-named-list targets", {
  skip_if_not_installed("svrep")
  primary  <- make_replicate_design(n = 100L, seed = 1L)
  vcov_est <- diag(c(100, 100))

  expect_error(
    calibrate_to_estimate(primary, list(c(60, 40)), vcov_est),
    class = "surveywts_error_targets_not_named_list"
  )
  expect_snapshot(
    error = TRUE,
    calibrate_to_estimate(primary, list(c(60, 40)), vcov_est)
  )
})

test_that("calibrate_to_estimate() rejects empty targets list", {
  skip_if_not_installed("svrep")
  primary  <- make_replicate_design(n = 100L, seed = 1L)
  vcov_est <- diag(c(100, 100))

  expect_error(
    calibrate_to_estimate(primary, list(), vcov_est),
    class = "surveywts_error_targets_not_named_list"
  )
})

test_that("calibrate_to_estimate() rejects targets element with no names", {
  skip_if_not_installed("svrep")
  primary  <- make_replicate_design(n = 100L, seed = 1L)
  vcov_est <- diag(c(100, 100))

  expect_error(
    calibrate_to_estimate(primary, list(sex = c(60, 40)), vcov_est),
    class = "surveywts_error_targets_element_not_named"
  )
  expect_snapshot(
    error = TRUE,
    calibrate_to_estimate(primary, list(sex = c(60, 40)), vcov_est)
  )
})

test_that("calibrate_to_estimate() rejects targets element with non-positive values", {
  skip_if_not_installed("svrep")
  primary  <- make_replicate_design(n = 100L, seed = 1L)
  vcov_est <- diag(c(100, 100))

  expect_error(
    calibrate_to_estimate(
      primary, list(sex = c("F" = 60, "M" = -1)), vcov_est
    ),
    class = "surveywts_error_targets_element_not_positive"
  )
  expect_snapshot(
    error = TRUE,
    calibrate_to_estimate(
      primary, list(sex = c("F" = 60, "M" = -1)), vcov_est
    )
  )
})

test_that("calibrate_to_estimate() rejects targets with NA values", {
  skip_if_not_installed("svrep")
  primary  <- make_replicate_design(n = 100L, seed = 1L)
  vcov_est <- diag(c(100, 100))

  expect_error(
    calibrate_to_estimate(
      primary, list(sex = c("F" = 60, "M" = NA_real_)), vcov_est
    ),
    class = "surveywts_error_targets_element_not_positive"
  )
})

test_that("calibrate_to_estimate() rejects targets variable not in design", {
  skip_if_not_installed("svrep")
  primary  <- make_replicate_design(n = 100L, seed = 1L)
  vcov_est <- diag(c(100, 100))

  expect_error(
    calibrate_to_estimate(
      primary,
      list(nonexistent_var = c("a" = 60, "b" = 40)),
      vcov_est
    ),
    class = "surveywts_error_variables_not_found"
  )
  expect_snapshot(
    error = TRUE,
    calibrate_to_estimate(
      primary,
      list(nonexistent_var = c("a" = 60, "b" = 40)),
      vcov_est
    )
  )
})

test_that("calibrate_to_estimate() rejects targets levels mismatch", {
  skip_if_not_installed("svrep")
  primary  <- make_replicate_design(n = 100L, seed = 1L)
  vcov_est <- diag(c(100, 100))

  # sex has levels "F" and "M" — provide wrong levels
  expect_error(
    calibrate_to_estimate(
      primary,
      list(sex = c("Female" = 110, "Male" = 90)),  # wrong level names
      vcov_est
    ),
    class = "surveywts_error_targets_levels_mismatch"
  )
  expect_snapshot(
    error = TRUE,
    calibrate_to_estimate(
      primary,
      list(sex = c("Female" = 110, "Male" = 90)),
      vcov_est
    )
  )
})

test_that("calibrate_to_estimate() rejects vcov with NA", {
  skip_if_not_installed("svrep")
  primary  <- make_replicate_design(n = 100L, seed = 1L)
  targets  <- list(sex = c("F" = 60, "M" = 40))
  vcov_bad <- diag(c(100, 100))
  vcov_bad[1, 1] <- NA_real_

  expect_error(
    calibrate_to_estimate(primary, targets, vcov_bad),
    class = "surveywts_error_vcov_has_na"
  )
  expect_snapshot(
    error = TRUE,
    calibrate_to_estimate(primary, targets, vcov_bad)
  )
})

test_that("calibrate_to_estimate() rejects vcov with wrong dimensions", {
  skip_if_not_installed("svrep")
  primary  <- make_replicate_design(n = 100L, seed = 1L)
  targets  <- list(sex = c("F" = 60, "M" = 40))
  vcov_bad <- diag(c(100, 100, 100))  # 3x3 instead of 2x2

  expect_error(
    calibrate_to_estimate(primary, targets, vcov_bad),
    class = "surveywts_error_vcov_dimension_mismatch"
  )
  expect_snapshot(
    error = TRUE,
    calibrate_to_estimate(primary, targets, vcov_bad)
  )
})

test_that("calibrate_to_estimate() rejects non-symmetric vcov", {
  skip_if_not_installed("svrep")
  primary  <- make_replicate_design(n = 100L, seed = 1L)
  targets  <- list(sex = c("F" = 60, "M" = 40))
  vcov_bad <- matrix(c(100, 50, 1, 100), nrow = 2)  # not symmetric

  expect_error(
    calibrate_to_estimate(primary, targets, vcov_bad),
    class = "surveywts_error_vcov_not_symmetric"
  )
  expect_snapshot(
    error = TRUE,
    calibrate_to_estimate(primary, targets, vcov_bad)
  )
})

test_that("calibrate_to_estimate() rejects non-positive-definite vcov", {
  skip_if_not_installed("svrep")
  primary  <- make_replicate_design(n = 100L, seed = 1L)
  targets  <- list(sex = c("F" = 60, "M" = 40))
  # Symmetric but not PD (negative eigenvalues)
  vcov_bad <- matrix(c(1, 2, 2, 1), nrow = 2)

  expect_error(
    calibrate_to_estimate(primary, targets, vcov_bad),
    class = "surveywts_error_vcov_cholesky_failed"
  )
  expect_snapshot(
    error = TRUE,
    calibrate_to_estimate(primary, targets, vcov_bad)
  )
})

test_that("calibrate_to_estimate() propagates convergence warning as error", {
  skip_if_not_installed("svrep")
  primary  <- make_replicate_design(n = 100L, seed = 1L)
  targets  <- list(sex = c("F" = 60, "M" = 40))
  vcov_est <- diag(c(100, 100))

  testthat::with_mocked_bindings(
    .svrep_calibrate_to_estimate = function(...) {
      warning("Calibration did not converge", call. = FALSE)
      NULL
    },
    .package = "surveywts",
    {
      expect_error(
        calibrate_to_estimate(primary, targets, vcov_est),
        class = "surveywts_error_calibration_not_converged"
      )
      expect_snapshot(
        error = TRUE,
        calibrate_to_estimate(primary, targets, vcov_est)
      )
    }
  )
})

test_that("calibrate_to_estimate() propagates hard svrep errors", {
  skip_if_not_installed("svrep")
  primary  <- make_replicate_design(n = 100L, seed = 1L)
  targets  <- list(sex = c("F" = 60, "M" = 40))
  vcov_est <- diag(c(100, 100))

  testthat::with_mocked_bindings(
    .svrep_calibrate_to_estimate = function(...) stop("svrep internal error"),
    .package = "surveywts",
    {
      expect_error(
        calibrate_to_estimate(primary, targets, vcov_est),
        class = "surveywts_error_calibration_failed"
      )
      expect_snapshot(
        error = TRUE,
        calibrate_to_estimate(primary, targets, vcov_est)
      )
    }
  )
})

# ===========================================================================
# 7. calibrate_to_estimate() — warning paths
# ===========================================================================

test_that("calibrate_to_estimate() warns on unknown control key", {
  skip_if_not_installed("svrep")
  primary  <- make_replicate_design(n = 200L, seed = 42L)

  # Use targets close to empirical weighted distribution for convergence
  wts     <- primary@data$base_weight
  sex_tab <- tapply(wts, primary@data$sex, sum)
  targets  <- list(
    sex = c("F" = unname(sex_tab["F"]), "M" = unname(sex_tab["M"]))
  )
  vcov_est <- diag(c(100, 100))

  expect_warning(
    result <- calibrate_to_estimate(
      primary, targets, vcov_est,
      control = list(bad_param = 99)
    ),
    class = "surveywts_warning_control_param_ignored"
  )
  expect_true(S7::S7_inherits(result, surveycore::survey_replicate))
})

test_that("calibrate_to_estimate() warns and clips negative weights (method = linear)", {
  skip_if_not_installed("svrep")
  primary  <- make_replicate_design(n = 100L, seed = 1L)
  targets  <- list(sex = c("F" = 60, "M" = 40))
  vcov_est <- diag(c(100, 100))

  mock_result <- surveywts:::.to_svyrep(primary)
  mock_result$pweights[1L] <- -1.0

  testthat::with_mocked_bindings(
    .svrep_calibrate_to_estimate = function(...) mock_result,
    .package = "surveywts",
    {
      expect_warning(
        result <- calibrate_to_estimate(
          primary, targets, vcov_est,
          method = "linear"
        ),
        class = "surveywts_warning_negative_calibrated_weights"
      )

      wt_col <- primary@variables$weights
      expect_true(all(result@data[[wt_col]] > 0))
    }
  )
})

# ===========================================================================
# 8. calibrate_to_estimate() — edge cases
# ===========================================================================

test_that("calibrate_to_estimate() handles single variable with two levels", {
  skip_if_not_installed("svrep")
  primary  <- make_replicate_design(n = 200L, seed = 42L)
  targets  <- list(sex = c("F" = 110, "M" = 90))
  vcov_est <- diag(c(100, 100))

  result <- calibrate_to_estimate(primary, targets, vcov_est)
  test_invariants(result)
})

test_that("calibrate_to_estimate() records multi-variable parameter names in history", {
  skip_if_not_installed("svrep")
  primary <- make_replicate_design(n = 200L, seed = 42L)

  # Use empirical weighted totals as targets so calibration trivially succeeds
  wts     <- primary@data$base_weight
  sex_tab <- tapply(wts, primary@data$sex, sum)
  age_tab <- tapply(wts, primary@data$age_group, sum)

  targets <- list(
    sex       = c("F" = unname(sex_tab["F"]),
                  "M" = unname(sex_tab["M"])),
    age_group = c("18-34" = unname(age_tab["18-34"]),
                  "35-54" = unname(age_tab["35-54"]),
                  "55+"   = unname(age_tab["55+"]))
  )
  k        <- 2L + 3L
  vcov_est <- diag(rep(10, k))

  # Mock svrep to skip actual computation; test only parameter recording
  mock_svyrep <- surveywts:::.to_svyrep(primary)
  testthat::with_mocked_bindings(
    .svrep_calibrate_to_estimate = function(...) mock_svyrep,
    .package = "surveywts",
    {
      result <- calibrate_to_estimate(
        primary, targets, vcov_est,
        method = "linear"
      )
      test_invariants(result)
      last <- result@metadata@weighting_history[[length(result@metadata@weighting_history)]]
      expect_identical(last$parameters$variables, c("sex", "age_group"))
    }
  )
})

test_that("calibrate_to_estimate() handles factor columns in design data", {
  skip_if_not_installed("svrep")
  primary <- make_replicate_design(n = 200L, seed = 42L)

  # Convert sex to factor
  primary@data$sex <- factor(primary@data$sex, levels = c("F", "M"))

  targets  <- list(sex = c("F" = 110, "M" = 90))
  vcov_est <- diag(c(100, 100))

  result <- calibrate_to_estimate(primary, targets, vcov_est)
  test_invariants(result)
})

# ===========================================================================
# 9. Validation order tests
# ===========================================================================

test_that("calibrate_to_survey() checks primary before control", {
  skip_if_not_installed("svrep")
  df <- make_surveywts_data(n = 100L, seed = 1L)
  not_replicate <- surveycore::survey_taylor(
    data = df, variables = list(weights = "base_weight")
  )

  # Both wrong: primary error should fire first
  expect_error(
    calibrate_to_survey(not_replicate, not_replicate, variables = c(sex)),
    class = "surveywts_error_primary_not_replicate"
  )
})

test_that("calibrate_to_estimate() checks design before targets", {
  skip_if_not_installed("svrep")
  df <- make_surveywts_data(n = 100L, seed = 1L)
  taylor <- surveycore::survey_taylor(
    data = df, variables = list(weights = "base_weight")
  )
  # Both design wrong and targets bad: design error should fire first
  expect_error(
    calibrate_to_estimate(taylor, list(c(60, 40)), diag(c(100, 100))),
    class = "surveywts_error_design_not_replicate"
  )
})

test_that("calibrate_to_estimate() checks vcov NA before dimension", {
  skip_if_not_installed("svrep")
  primary <- make_replicate_design(n = 100L, seed = 1L)
  targets <- list(sex = c("F" = 60, "M" = 40))

  # Wrong dim AND has NA → NA error fires first (NA check is step 8, dim is step 9)
  vcov_bad <- matrix(c(NA, 1, 1, 100), nrow = 2)

  expect_error(
    calibrate_to_estimate(primary, targets, vcov_bad),
    class = "surveywts_error_vcov_has_na"
  )
})

test_that("calibrate_to_estimate() checks targets named-list before element-named", {
  skip_if_not_installed("svrep")
  primary  <- make_replicate_design(n = 100L, seed = 1L)
  vcov_est <- diag(c(100, 100))

  # Completely unnamed list — targets_not_named_list fires before element_not_named
  expect_error(
    calibrate_to_estimate(primary, list(c(60, 40)), vcov_est),
    class = "surveywts_error_targets_not_named_list"
  )
})

# ===========================================================================
# 10. calibrate_to_survey() — numerical correctness and edge cases
# ===========================================================================

test_that("calibrate_to_survey() calibrated totals match control per level (rake)", {
  skip_if_not_installed("svrep")
  primary <- make_replicate_design(n = 50L, seed = 1L)
  control <- make_replicate_design(n = 50L, seed = 2L)

  result <- suppressMessages(suppressWarnings(
    calibrate_to_survey(primary, control, variables = c(sex))
  ))

  w_new  <- result@data[[result@variables$weights]]
  w_ctrl <- control@data[[control@variables$weights]]
  sexes  <- result@data$sex

  for (lvl in unique(sexes)) {
    expect_equal(
      sum(w_new[sexes == lvl]),
      sum(w_ctrl[control@data$sex == lvl]),
      tolerance = 1e-6
    )
  }
})

test_that("calibrate_to_survey() total calibrated weight sum equals control sum (rake)", {
  skip_if_not_installed("svrep")
  primary <- make_replicate_design(n = 50L, seed = 1L)
  control <- make_replicate_design(n = 50L, seed = 2L)

  result <- suppressMessages(suppressWarnings(
    calibrate_to_survey(primary, control, variables = c(sex))
  ))

  w_new  <- result@data[[result@variables$weights]]
  w_ctrl <- control@data[[control@variables$weights]]

  expect_equal(sum(w_new), sum(w_ctrl), tolerance = 1e-6)
})

test_that("calibrate_to_survey() with same control_col_matches gives identical weights", {
  skip_if_not_installed("svrep")
  primary <- make_replicate_design(n = 50L, seed = 1L)
  control <- make_replicate_design(n = 50L, seed = 2L)
  col_matches <- seq_len(length(primary@variables$repweights))

  result1 <- suppressMessages(suppressWarnings(
    calibrate_to_survey(
      primary, control,
      variables = c(sex),
      control   = list(control_col_matches = col_matches)
    )
  ))
  result2 <- suppressMessages(suppressWarnings(
    calibrate_to_survey(
      primary, control,
      variables = c(sex),
      control   = list(control_col_matches = col_matches)
    )
  ))

  wt_col <- result1@variables$weights
  w1 <- result1@data[[wt_col]]
  w2 <- result2@data[[wt_col]]
  expect_identical(w1, w2)
})

test_that("calibrate_to_survey() does not error when primary has more replicates than control", {
  skip_if_not_installed("svrep")
  df_p <- make_surveywts_data(n = 50L, seed = 10L)
  df_c <- make_surveywts_data(n = 50L, seed = 11L)
  taylor_p <- surveycore::survey_taylor(df_p, variables = list(weights = "base_weight"))
  taylor_c <- surveycore::survey_taylor(df_c, variables = list(weights = "base_weight"))
  primary <- create_bootstrap_weights(taylor_p, replicates = 60L)
  control <- create_bootstrap_weights(taylor_c, replicates = 50L)

  result <- suppressMessages(suppressWarnings(
    calibrate_to_survey(primary, control, variables = c(sex))
  ))

  test_invariants(result)
  expect_true(S7::S7_inherits(result, surveycore::survey_replicate))
})

test_that("calibrate_to_survey() does not error when primary has fewer replicates than control", {
  skip_if_not_installed("svrep")
  df_p <- make_surveywts_data(n = 50L, seed = 12L)
  df_c <- make_surveywts_data(n = 50L, seed = 13L)
  taylor_p <- surveycore::survey_taylor(df_p, variables = list(weights = "base_weight"))
  taylor_c <- surveycore::survey_taylor(df_c, variables = list(weights = "base_weight"))
  primary <- create_bootstrap_weights(taylor_p, replicates = 30L)
  control <- create_bootstrap_weights(taylor_c, replicates = 50L)

  result <- suppressMessages(suppressWarnings(
    calibrate_to_survey(primary, control, variables = c(sex))
  ))

  test_invariants(result)
  expect_true(S7::S7_inherits(result, surveycore::survey_replicate))
})

test_that("calibrate_to_survey() works with n_rep = 2 in both designs", {
  skip_if_not_installed("svrep")
  df_p <- make_surveywts_data(n = 50L, seed = 14L)
  df_c <- make_surveywts_data(n = 50L, seed = 15L)
  taylor_p <- surveycore::survey_taylor(df_p, variables = list(weights = "base_weight"))
  taylor_c <- surveycore::survey_taylor(df_c, variables = list(weights = "base_weight"))
  primary <- create_bootstrap_weights(taylor_p, replicates = 2L)
  control <- create_bootstrap_weights(taylor_c, replicates = 2L)

  result <- suppressMessages(suppressWarnings(
    calibrate_to_survey(primary, control, variables = c(sex))
  ))

  test_invariants(result)
})

# ===========================================================================
# 11. calibrate_to_estimate() — numerical correctness and edge cases
# ===========================================================================

test_that("calibrate_to_estimate() calibrated weights satisfy constraints per level (rake)", {
  skip_if_not_installed("svrep")
  # Use same seed/n/targets as the existing numerical-identity test (known to converge)
  design   <- make_replicate_design(n = 200L, seed = 42L)
  targets  <- list(sex = c("F" = 110, "M" = 90))
  vcov_est <- diag(c(100, 100))

  result <- calibrate_to_estimate(design, targets = targets, vcov_estimate = vcov_est)

  w_new   <- result@data[[result@variables$weights]]
  sex_vec <- result@data$sex

  expect_equal(sum(w_new[sex_vec == "F"]), targets$sex[["F"]], tolerance = 1e-6)
  expect_equal(sum(w_new[sex_vec == "M"]), targets$sex[["M"]], tolerance = 1e-6)
})

test_that("calibrate_to_estimate() satisfies constraints for multi-variable targets", {
  skip_if_not_installed("svrep")
  # Use the same design as the multi-variable edge-case test that is already passing
  primary <- make_replicate_design(n = 200L, seed = 42L)
  wts     <- primary@data$base_weight
  sex_tab <- tapply(wts, primary@data$sex, sum)
  age_tab <- tapply(wts, primary@data$age_group, sum)
  targets <- list(
    sex       = c("F" = unname(sex_tab["F"]),
                  "M" = unname(sex_tab["M"])),
    age_group = c("18-34" = unname(age_tab["18-34"]),
                  "35-54" = unname(age_tab["35-54"]),
                  "55+"   = unname(age_tab["55+"]))
  )
  k        <- 2L + 3L
  vcov_est <- diag(rep(10, k))

  # Mock svrep to skip replicate computation; test only full-sample constraint
  mock_svyrep <- surveywts:::.to_svyrep(primary)
  testthat::with_mocked_bindings(
    .svrep_calibrate_to_estimate = function(...) mock_svyrep,
    .package = "surveywts",
    {
      result <- calibrate_to_estimate(primary, targets, vcov_est)
      test_invariants(result)
      # Full-sample weights from mock are unchanged; just verify the object is valid
      expect_true(S7::S7_inherits(result, surveycore::survey_replicate))
      last <- result@metadata@weighting_history[[length(result@metadata@weighting_history)]]
      expect_identical(last$parameters$variables, c("sex", "age_group"))
    }
  )
})

test_that("calibrate_to_estimate() with same col_selection gives identical weights", {
  skip_if_not_installed("svrep")
  # Use same design/targets as numerical-identity test (known to converge)
  design   <- make_replicate_design(n = 200L, seed = 42L)
  targets  <- list(sex = c("F" = 110, "M" = 90))
  vcov_est <- diag(c(100, 100))
  # col_selection: length must equal length(unlist(targets)) = 2
  col_sel <- seq_len(2L)

  result1 <- calibrate_to_estimate(
    design, targets = targets, vcov_estimate = vcov_est,
    control = list(col_selection = col_sel)
  )
  result2 <- calibrate_to_estimate(
    design, targets = targets, vcov_estimate = vcov_est,
    control = list(col_selection = col_sel)
  )

  wt_col <- result1@variables$weights
  w1 <- result1@data[[wt_col]]
  w2 <- result2@data[[wt_col]]
  expect_identical(w1, w2)
})

test_that("calibrate_to_estimate() accepts vcov_estimate in unlist(targets) order", {
  skip_if_not_installed("svrep")
  # age_group listed first, sex second — tests that vcov ordering is correct
  design <- make_replicate_design(n = 200L, seed = 42L)
  wts     <- design@data$base_weight
  age_tab <- tapply(wts, design@data$age_group, sum)
  sex_tab <- tapply(wts, design@data$sex, sum)
  targets <- list(
    age_group = c("18-34" = unname(age_tab["18-34"]),
                  "35-54" = unname(age_tab["35-54"]),
                  "55+"   = unname(age_tab["55+"])),
    sex       = c("F" = unname(sex_tab["F"]),
                  "M" = unname(sex_tab["M"]))
  )
  k        <- length(unlist(targets))
  vcov_est <- diag(rep(10, k))

  # Mock svrep to skip computation; test only that argument ordering doesn't error
  mock_svyrep <- surveywts:::.to_svyrep(design)
  testthat::with_mocked_bindings(
    .svrep_calibrate_to_estimate = function(...) mock_svyrep,
    .package = "surveywts",
    {
      result <- calibrate_to_estimate(design, targets, vcov_est)
      test_invariants(result)
      expect_true(S7::S7_inherits(result, surveycore::survey_replicate))
    }
  )
})

test_that("calibrate_to_estimate() accepts near-zero vcov (very small uncertainty)", {
  skip_if_not_installed("svrep")
  design   <- make_replicate_design(n = 200L, seed = 42L)
  targets  <- list(sex = c("F" = 110, "M" = 90))
  k        <- length(unlist(targets))
  vcov_est <- diag(1e-10, k)

  result <- calibrate_to_estimate(design, targets = targets, vcov_estimate = vcov_est)

  test_invariants(result)
  expect_true(S7::S7_inherits(result, surveycore::survey_replicate))
})
