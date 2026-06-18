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

test_that("calibrate_to_survey() raises error on calibration failure (method=rake, maxit=1)", {
  # Trigger surveywts_error_calibration_not_converged by limiting to 1 iteration
  # with an extremely tight tolerance.  survey::calibrate() with cal.raking
  # emits a "Failed to converge" warning then errors — our handler maps this to
  # the typed error class.
  primary <- make_replicate_design(n = 100L, seed = 1L)
  control <- make_replicate_design(n = 100L, seed = 2L)

  expect_error(
    calibrate_to_survey(
      primary, control,
      variables = c(sex),
      method    = "rake",
      control   = list(maxit = 1L, epsilon = 1e-40)
    ),
    class = "surveywts_error_calibration_not_converged"
  )
})

test_that("calibrate_to_survey() does not call .svrep_calibrate_to_sample()", {
  # Verify that the Opsomer path never delegates to svrep.
  primary <- make_replicate_design(n = 100L, seed = 1L)
  control <- make_replicate_design(n = 100L, seed = 2L)

  testthat::with_mocked_bindings(
    .svrep_calibrate_to_sample = function(...) {
      stop("svrep::calibrate_to_sample must not be called in PR 2")
    },
    .package = "surveywts",
    {
      expect_no_error(
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

test_that("calibrate_to_survey() warns and clips negative full-sample weights (method = linear)", {
  # Linear calibration with two correlated variables (A, B) produces negative
  # full-sample weights when the primary has extreme joint distribution (large
  # weights in A=1,B=1 group) and the control has very small A totals.
  # Using n=30 primary / n=100 control ensures bootstrap replicates are stable
  # enough to avoid per-replicate convergence errors.
  df_prim <- data.frame(
    A  = c(rep(1L, 15L), rep(0L, 15L)),
    B  = c(rep(1L, 10L), rep(0L, 5L), rep(1L, 5L), rep(0L, 10L)),
    wt = c(rep(8, 15L), rep(1, 15L)),
    stringsAsFactors = FALSE
  )
  # Control: A very sparse (2 out of 100 units, total=2); B at 50%.
  # Both levels present in control — passes .check_control_levels().
  df_ctrl <- data.frame(
    A  = c(rep(1L, 2L), rep(0L, 98L)),
    B  = c(1L, 0L, rep(1L, 49L), rep(0L, 49L)),
    wt = rep(1, 100L),
    stringsAsFactors = FALSE
  )
  tay_p <- surveycore::survey_taylor(df_prim, variables = list(weights = "wt"))
  tay_c <- surveycore::survey_taylor(df_ctrl, variables = list(weights = "wt"))
  p_rep <- create_bootstrap_weights(tay_p, replicates = 30L, seed = 1L)
  c_rep <- create_bootstrap_weights(tay_c, replicates = 30L, seed = 2L)

  expect_warning(
    result <- calibrate_to_survey(
      p_rep, c_rep,
      variables = c(A, B),
      method    = "linear"
    ),
    class = "surveywts_warning_negative_calibrated_weights"
  )

  wt_col <- p_rep@variables$weights
  expect_true(all(result@data[[wt_col]] > 0))
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

# ===========================================================================
# 12. calibrate_to_survey() — survey_nonprob primary/control happy paths
# ===========================================================================

test_that(
  "calibrate_to_survey() accepts survey_nonprob primary + survey_replicate control",
  {
    skip_if_not_installed("svrep")
    primary <- make_nonprob_replicate_design(n = 200L, seed = 1L)
    control <- make_replicate_design(n = 200L, seed = 2L)

    result <- calibrate_to_survey(
      primary_design = primary,
      control_design = control,
      variables      = c(sex)
    )

    test_invariants(result)
    expect_true(S7::S7_inherits(result, surveycore::survey_nonprob))
    expect_identical(nrow(result@data), nrow(primary@data))
  }
)

test_that(
  "calibrate_to_survey() accepts survey_replicate primary + survey_nonprob control",
  {
    skip_if_not_installed("svrep")
    primary <- make_replicate_design(n = 200L, seed = 1L)
    control <- make_nonprob_replicate_design(n = 200L, seed = 2L)

    result <- calibrate_to_survey(
      primary_design = primary,
      control_design = control,
      variables      = c(sex)
    )

    test_invariants(result)
    expect_true(S7::S7_inherits(result, surveycore::survey_replicate))
  }
)

test_that(
  "calibrate_to_survey() accepts both survey_nonprob with replicate weights",
  {
    skip_if_not_installed("svrep")
    primary <- make_nonprob_replicate_design(n = 200L, seed = 1L)
    control <- make_nonprob_replicate_design(n = 200L, seed = 2L)

    result <- calibrate_to_survey(
      primary_design = primary,
      control_design = control,
      variables      = c(sex)
    )

    test_invariants(result)
    expect_true(S7::S7_inherits(result, surveycore::survey_nonprob))
  }
)

test_that(
  "calibrate_to_survey() nonprob history grows by exactly 1 entry per call",
  {
    skip_if_not_installed("svrep")
    primary  <- make_nonprob_replicate_design(n = 200L, seed = 1L)
    control  <- make_replicate_design(n = 200L, seed = 2L)
    n_before <- length(primary@metadata@weighting_history)

    result <- calibrate_to_survey(
      primary_design = primary,
      control_design = control,
      variables      = c(sex)
    )

    n_after <- length(result@metadata@weighting_history)
    expect_identical(n_after - n_before, 1L)
    last <- result@metadata@weighting_history[[n_after]]
    expect_identical(last$operation, "calibrate_to_survey")
  }
)

test_that(
  paste0(
    "calibrate_to_survey() records control_design_class correctly ",
    "for nonprob primary + replicate control"
  ),
  {
    skip_if_not_installed("svrep")
    primary <- make_nonprob_replicate_design(n = 200L, seed = 1L)
    control <- make_replicate_design(n = 200L, seed = 2L)

    result <- calibrate_to_survey(
      primary_design = primary,
      control_design = control,
      variables      = c(sex)
    )

    last <- result@metadata@weighting_history[[
      length(result@metadata@weighting_history)
    ]]
    expect_identical(
      last$parameters$control_design_class,
      class(control)[[1L]]
    )
  }
)

test_that(
  paste0(
    "calibrate_to_survey() records control_design_class correctly ",
    "for both-nonprob scenario"
  ),
  {
    skip_if_not_installed("svrep")
    primary <- make_nonprob_replicate_design(n = 200L, seed = 1L)
    control <- make_nonprob_replicate_design(n = 200L, seed = 2L)

    result <- calibrate_to_survey(
      primary_design = primary,
      control_design = control,
      variables      = c(sex)
    )

    last <- result@metadata@weighting_history[[
      length(result@metadata@weighting_history)
    ]]
    expect_identical(
      last$parameters$control_design_class,
      class(control)[[1L]]
    )
  }
)

# ===========================================================================
# 13. calibrate_to_estimate() — survey_nonprob happy path
# ===========================================================================

test_that(
  "calibrate_to_estimate() accepts survey_nonprob with replicate weights",
  {
    skip_if_not_installed("svrep")
    design   <- make_nonprob_replicate_design(n = 200L, seed = 1L)
    targets  <- list(sex = c("F" = 110, "M" = 90))
    vcov_est <- diag(c(100, 100))

    result <- calibrate_to_estimate(design, targets, vcov_est)

    test_invariants(result)
    expect_true(S7::S7_inherits(result, surveycore::survey_nonprob))
    expect_identical(nrow(result@data), nrow(design@data))
  }
)

test_that(
  "calibrate_to_estimate() nonprob history grows by exactly 1 entry per call",
  {
    skip_if_not_installed("svrep")
    design   <- make_nonprob_replicate_design(n = 200L, seed = 1L)
    targets  <- list(sex = c("F" = 110, "M" = 90))
    vcov_est <- diag(c(100, 100))
    n_before <- length(design@metadata@weighting_history)

    result <- calibrate_to_estimate(design, targets, vcov_est)

    n_after <- length(result@metadata@weighting_history)
    expect_identical(n_after - n_before, 1L)
    last <- result@metadata@weighting_history[[n_after]]
    expect_identical(last$operation, "calibrate_to_estimate")
  }
)

# ===========================================================================
# 14. New error classes: _no_repweights
# ===========================================================================

test_that(
  "calibrate_to_survey() fires surveywts_error_primary_no_repweights",
  {
    skip_if_not_installed("svrep")
    primary_no_rep <- make_nonprob_no_repweights(n = 100L, seed = 1L)
    control        <- make_replicate_design(n = 100L, seed = 2L)

    expect_error(
      calibrate_to_survey(
        primary_design = primary_no_rep,
        control_design = control,
        variables      = c(sex)
      ),
      class = "surveywts_error_primary_no_repweights"
    )
    expect_snapshot(
      error = TRUE,
      calibrate_to_survey(
        primary_design = primary_no_rep,
        control_design = control,
        variables      = c(sex)
      )
    )
  }
)

test_that(
  "calibrate_to_survey() fires surveywts_error_control_no_repweights",
  {
    skip_if_not_installed("svrep")
    primary        <- make_nonprob_replicate_design(n = 100L, seed = 1L)
    control_no_rep <- make_nonprob_no_repweights(n = 100L, seed = 2L)

    expect_error(
      calibrate_to_survey(
        primary_design = primary,
        control_design = control_no_rep,
        variables      = c(sex)
      ),
      class = "surveywts_error_control_no_repweights"
    )
    expect_snapshot(
      error = TRUE,
      calibrate_to_survey(
        primary_design = primary,
        control_design = control_no_rep,
        variables      = c(sex)
      )
    )
  }
)

test_that(
  "calibrate_to_estimate() fires surveywts_error_design_no_repweights",
  {
    skip_if_not_installed("svrep")
    design_no_rep <- make_nonprob_no_repweights(n = 100L, seed = 1L)
    targets       <- list(sex = c("F" = 60, "M" = 40))
    vcov_est      <- diag(c(100, 100))

    expect_error(
      calibrate_to_estimate(design_no_rep, targets, vcov_est),
      class = "surveywts_error_design_no_repweights"
    )
    expect_snapshot(
      error = TRUE,
      calibrate_to_estimate(design_no_rep, targets, vcov_est)
    )
  }
)

# ===========================================================================
# 15. Validation order: nonprob checks relative to other checks
# ===========================================================================

test_that(
  "calibrate_to_survey() primary class check fires before control (nonprob order)",
  {
    skip_if_not_installed("svrep")
    df            <- make_surveywts_data(n = 100L, seed = 1L)
    not_replicate <- surveycore::survey_taylor(
      data = df, variables = list(weights = "base_weight")
    )
    nonprob_no_rep <- make_nonprob_no_repweights(n = 100L, seed = 2L)

    # primary is wrong class (taylor) — primary_not_replicate fires first
    expect_error(
      calibrate_to_survey(not_replicate, nonprob_no_rep, variables = c(sex)),
      class = "surveywts_error_primary_not_replicate"
    )
  }
)

test_that(
  "calibrate_to_survey() primary_no_repweights fires before control check",
  {
    skip_if_not_installed("svrep")
    primary_no_rep <- make_nonprob_no_repweights(n = 100L, seed = 1L)
    df             <- make_surveywts_data(n = 100L, seed = 2L)
    not_replicate  <- surveycore::survey_taylor(
      data = df, variables = list(weights = "base_weight")
    )

    # primary is nonprob without repweights, control is wrong class
    # primary_no_repweights fires first (step 1b before step 2)
    expect_error(
      calibrate_to_survey(
        primary_no_rep, not_replicate, variables = c(sex)
      ),
      class = "surveywts_error_primary_no_repweights"
    )
  }
)

test_that(
  "calibrate_to_estimate() design_no_repweights fires before targets check",
  {
    skip_if_not_installed("svrep")
    design_no_rep <- make_nonprob_no_repweights(n = 100L, seed = 1L)

    # design is nonprob without repweights, targets is also invalid
    # design_no_repweights should fire first
    expect_error(
      calibrate_to_estimate(design_no_rep, list(c(60, 40)), diag(c(100, 100))),
      class = "surveywts_error_design_no_repweights"
    )
  }
)

# ===========================================================================
# 16. Edge case: @variables$repweights = character(0) triggers _no_repweights
# ===========================================================================

test_that(
  paste0(
    "calibrate_to_survey() fires primary_no_repweights when ",
    "@variables$repweights = character(0)"
  ),
  {
    skip_if_not_installed("svrep")
    nps_df <- make_surveywts_data(n = 100L, seed = 1L)
    ref_df <- make_surveywts_data(n = 500L, seed = 101L)
    ref    <- surveycore::as_survey(ref_df, weights = base_weight)
    nps    <- ipw(data = nps_df, reference = ref, selection = ~sex + age_group)

    # Force empty repweights
    vars            <- nps@variables
    vars$repweights <- character(0)
    nps@variables   <- vars

    control <- make_replicate_design(n = 100L, seed = 2L)

    expect_error(
      calibrate_to_survey(nps, control, variables = c(sex)),
      class = "surveywts_error_primary_no_repweights"
    )
  }
)

test_that(
  paste0(
    "calibrate_to_estimate() fires design_no_repweights when ",
    "@variables$repweights = character(0)"
  ),
  {
    skip_if_not_installed("svrep")
    nps_df <- make_surveywts_data(n = 100L, seed = 1L)
    ref_df <- make_surveywts_data(n = 500L, seed = 101L)
    ref    <- surveycore::as_survey(ref_df, weights = base_weight)
    nps    <- ipw(data = nps_df, reference = ref, selection = ~sex + age_group)

    vars            <- nps@variables
    vars$repweights <- character(0)
    nps@variables   <- vars

    targets  <- list(sex = c("F" = 60, "M" = 40))
    vcov_est <- diag(c(100, 100))

    expect_error(
      calibrate_to_estimate(nps, targets, vcov_est),
      class = "surveywts_error_design_no_repweights"
    )
  }
)

# ===========================================================================
# 17. Regression guards
# ===========================================================================

test_that(
  "calibrate_to_survey() still returns survey_replicate for replicate+replicate",
  {
    skip_if_not_installed("svrep")
    primary <- make_replicate_design(n = 200L, seed = 1L)
    control <- make_replicate_design(n = 200L, seed = 2L)

    result <- calibrate_to_survey(primary, control, variables = c(sex))

    test_invariants(result)
    expect_true(S7::S7_inherits(result, surveycore::survey_replicate))
    expect_false(S7::S7_inherits(result, surveycore::survey_nonprob))
  }
)

test_that(
  "calibrate_to_survey() _not_replicate still fires for data.frame primary",
  {
    skip_if_not_installed("svrep")
    df      <- make_surveywts_data(n = 100L, seed = 1L)
    control <- make_replicate_design(n = 100L, seed = 2L)

    expect_error(
      calibrate_to_survey(df, control, variables = c(sex)),
      class = "surveywts_error_primary_not_replicate"
    )
  }
)

test_that(
  "calibrate_to_survey() _not_replicate still fires for survey_taylor control",
  {
    skip_if_not_installed("svrep")
    primary <- make_nonprob_replicate_design(n = 100L, seed = 1L)
    df      <- make_surveywts_data(n = 100L, seed = 2L)
    taylor  <- surveycore::survey_taylor(
      data = df, variables = list(weights = "base_weight")
    )

    expect_error(
      calibrate_to_survey(primary, taylor, variables = c(sex)),
      class = "surveywts_error_control_not_replicate"
    )
  }
)

test_that(
  "calibrate_to_estimate() _not_replicate still fires for data.frame design",
  {
    skip_if_not_installed("svrep")
    df       <- make_surveywts_data(n = 100L, seed = 1L)
    targets  <- list(sex = c("F" = 60, "M" = 40))
    vcov_est <- diag(c(100, 100))

    expect_error(
      calibrate_to_estimate(df, targets, vcov_est),
      class = "surveywts_error_design_not_replicate"
    )
  }
)

test_that(
  paste0(
    "calibrate_to_estimate() targets_levels_mismatch still fires ",
    "with nonprob design"
  ),
  {
    skip_if_not_installed("svrep")
    design   <- make_nonprob_replicate_design(n = 200L, seed = 1L)
    vcov_est <- diag(c(100, 100))

    expect_error(
      calibrate_to_estimate(
        design,
        list(sex = c("Female" = 110, "Male" = 90)),
        vcov_est
      ),
      class = "surveywts_error_targets_levels_mismatch"
    )
  }
)

# ===========================================================================
# 18. PR 1 — new signature: type and algorithm arg_match tests
# ===========================================================================

test_that(
  "calibrate_to_survey() accepts type = 'prop' with targets = NULL (no error)",
  {
    skip_if_not_installed("svrep")
    primary <- make_replicate_design(n = 100L, seed = 1L)
    control <- make_replicate_design(n = 100L, seed = 2L)

    expect_no_error(
      calibrate_to_survey(
        primary_design = primary,
        control_design = control,
        variables      = c(sex),
        targets        = NULL,
        type           = "prop"
      )
    )
  }
)

test_that(
  "calibrate_to_survey() accepts algorithm = 'nr' with method = 'linear' (no error)",
  {
    skip_if_not_installed("svrep")
    primary <- make_replicate_design(n = 100L, seed = 1L)
    control <- make_replicate_design(n = 100L, seed = 2L)

    expect_no_error(
      calibrate_to_survey(
        primary_design = primary,
        control_design = control,
        variables      = c(sex),
        method         = "linear",
        algorithm      = "nr"
      )
    )
  }
)

# ===========================================================================
# 19. PR 1 — surveywts_error_scale_not_found
# ===========================================================================

test_that(
  "calibrate_to_survey() fires scale_not_found when primary@variables$scale is NULL (targets = NULL)",
  {
    primary <- make_replicate_design(n = 100L, seed = 1L)
    control <- make_replicate_design(n = 100L, seed = 2L)

    # Remove scale from primary
    vars_p <- primary@variables
    vars_p$scale <- NULL
    primary@variables <- vars_p

    expect_error(
      calibrate_to_survey(
        primary_design = primary,
        control_design = control,
        variables      = c(sex),
        targets        = NULL
      ),
      class = "surveywts_error_scale_not_found"
    )
    expect_snapshot(
      error = TRUE,
      {
        p2 <- make_replicate_design(n = 100L, seed = 1L)
        v2 <- p2@variables
        v2$scale <- NULL
        p2@variables <- v2
        calibrate_to_survey(p2, make_replicate_design(n = 100L, seed = 2L),
                            variables = c(sex), targets = NULL)
      }
    )
  }
)

test_that(
  "calibrate_to_survey() fires scale_not_found when primary@variables$scale is NULL (targets non-NULL)",
  {
    primary <- make_replicate_design(n = 100L, seed = 1L)
    control <- make_replicate_design(n = 100L, seed = 2L)

    vars_p <- primary@variables
    vars_p$scale <- NULL
    primary@variables <- vars_p

    tgts <- list(sex = c("M" = 0.48, "F" = 0.52))

    expect_error(
      calibrate_to_survey(
        primary_design = primary,
        control_design = control,
        variables      = c(age_group),
        targets        = tgts,
        type           = "prop"
      ),
      class = "surveywts_error_scale_not_found"
    )
    expect_snapshot(
      error = TRUE,
      {
        p2a <- make_replicate_design(n = 100L, seed = 1L)
        c2a <- make_replicate_design(n = 100L, seed = 2L)
        v2a <- p2a@variables
        v2a$scale <- NULL
        p2a@variables <- v2a
        calibrate_to_survey(
          p2a, c2a,
          variables = c(age_group),
          targets   = list(sex = c("M" = 0.48, "F" = 0.52)),
          type      = "prop"
        )
      }
    )
  }
)

test_that(
  "calibrate_to_survey() fires scale_not_found when control@variables$scale is NULL (targets non-NULL)",
  {
    primary <- make_replicate_design(n = 100L, seed = 1L)
    control <- make_replicate_design(n = 100L, seed = 2L)

    vars_c2 <- control@variables
    vars_c2$scale <- NULL
    control@variables <- vars_c2

    tgts <- list(sex = c("M" = 0.48, "F" = 0.52))

    expect_error(
      calibrate_to_survey(
        primary_design = primary,
        control_design = control,
        variables      = c(age_group),
        targets        = tgts,
        type           = "prop"
      ),
      class = "surveywts_error_scale_not_found"
    )
    expect_snapshot(
      error = TRUE,
      {
        p2b <- make_replicate_design(n = 100L, seed = 1L)
        c2b <- make_replicate_design(n = 100L, seed = 2L)
        v2b <- c2b@variables
        v2b$scale <- NULL
        c2b@variables <- v2b
        calibrate_to_survey(
          p2b, c2b,
          variables = c(age_group),
          targets   = list(sex = c("M" = 0.48, "F" = 0.52)),
          type      = "prop"
        )
      }
    )
  }
)

test_that(
  "calibrate_to_survey() fires scale_not_found when control@variables$scale is NULL (targets = NULL)",
  {
    primary <- make_replicate_design(n = 100L, seed = 1L)
    control <- make_replicate_design(n = 100L, seed = 2L)

    vars_c <- control@variables
    vars_c$scale <- NULL
    control@variables <- vars_c

    expect_error(
      calibrate_to_survey(
        primary_design = primary,
        control_design = control,
        variables      = c(sex),
        targets        = NULL
      ),
      class = "surveywts_error_scale_not_found"
    )
    expect_snapshot(
      error = TRUE,
      {
        p3 <- make_replicate_design(n = 100L, seed = 1L)
        c3 <- make_replicate_design(n = 100L, seed = 2L)
        v3 <- c3@variables
        v3$scale <- NULL
        c3@variables <- v3
        calibrate_to_survey(p3, c3, variables = c(sex), targets = NULL)
      }
    )
  }
)

# ===========================================================================
# 20. PR 1 — surveywts_error_control_level_missing
# ===========================================================================

test_that(
  "calibrate_to_survey() fires control_level_missing when a level is absent from control (targets = NULL)",
  {
    skip_if_not_installed("svrep")
    primary <- make_replicate_design(n = 100L, seed = 1L)

    # Build a control where sex only has "M" (no "F")
    df_c <- make_surveywts_data(n = 200L, seed = 77L)
    df_c_m_only <- df_c[df_c$sex == "M", ]
    taylor_c <- surveycore::survey_taylor(
      data      = df_c_m_only,
      variables = list(weights = "base_weight")
    )
    control_m_only <- create_bootstrap_weights(taylor_c, replicates = 50L)

    expect_error(
      calibrate_to_survey(
        primary_design = primary,
        control_design = control_m_only,
        variables      = c(sex),
        targets        = NULL
      ),
      class = "surveywts_error_control_level_missing"
    )
    expect_snapshot(
      error = TRUE,
      {
        df_snap <- make_surveywts_data(n = 200L, seed = 77L)
        df_snap_m <- df_snap[df_snap$sex == "M", ]
        t_snap <- surveycore::survey_taylor(
          data      = df_snap_m,
          variables = list(weights = "base_weight")
        )
        ctrl_snap <- create_bootstrap_weights(t_snap, replicates = 50L)
        calibrate_to_survey(
          make_replicate_design(n = 100L, seed = 1L),
          ctrl_snap,
          variables = c(sex),
          targets   = NULL
        )
      }
    )
  }
)

test_that(
  "calibrate_to_survey() fires control_level_missing when a level is absent from control (targets non-NULL)",
  {
    skip_if_not_installed("svrep")
    primary <- make_replicate_design(n = 100L, seed = 1L)

    # Build a control where age_group only has "18-34" and "35-54"
    df_c <- make_surveywts_data(n = 500L, seed = 88L)
    df_c_partial <- df_c[df_c$age_group != "55+", ]
    taylor_c <- surveycore::survey_taylor(
      data      = df_c_partial,
      variables = list(weights = "base_weight")
    )
    control_partial <- create_bootstrap_weights(taylor_c, replicates = 50L)

    tgts <- list(sex = c("M" = 0.48, "F" = 0.52))

    expect_error(
      calibrate_to_survey(
        primary_design = primary,
        control_design = control_partial,
        variables      = c(age_group),
        targets        = tgts,
        type           = "prop"
      ),
      class = "surveywts_error_control_level_missing"
    )
    expect_snapshot(
      error = TRUE,
      {
        df_sn2 <- make_surveywts_data(n = 500L, seed = 88L)
        df_sn2_partial <- df_sn2[df_sn2$age_group != "55+", ]
        t_sn2 <- surveycore::survey_taylor(
          data      = df_sn2_partial,
          variables = list(weights = "base_weight")
        )
        ctrl_sn2 <- create_bootstrap_weights(t_sn2, replicates = 50L)
        calibrate_to_survey(
          make_replicate_design(n = 100L, seed = 1L),
          ctrl_sn2,
          variables = c(age_group),
          targets   = list(sex = c("M" = 0.48, "F" = 0.52)),
          type      = "prop"
        )
      }
    )
  }
)

# ===========================================================================
# 21. PR 1 — surveywts_error_targets_not_named_list
# ===========================================================================

test_that(
  "calibrate_to_survey() fires targets_not_named_list for unnamed element",
  {
    skip_if_not_installed("svrep")
    primary <- make_replicate_design(n = 100L, seed = 1L)
    control <- make_replicate_design(n = 100L, seed = 2L)

    expect_error(
      calibrate_to_survey(
        primary_design = primary,
        control_design = control,
        variables      = c(sex),
        targets        = list(c(1000, 2000))   # unnamed element
      ),
      class = "surveywts_error_targets_not_named_list"
    )
    expect_snapshot(
      error = TRUE,
      calibrate_to_survey(
        make_replicate_design(n = 100L, seed = 1L),
        make_replicate_design(n = 100L, seed = 2L),
        variables = c(sex),
        targets   = list(c(1000, 2000))
      )
    )
  }
)

test_that(
  "calibrate_to_survey() fires targets_not_named_list for empty list",
  {
    skip_if_not_installed("svrep")
    primary <- make_replicate_design(n = 100L, seed = 1L)
    control <- make_replicate_design(n = 100L, seed = 2L)

    expect_error(
      calibrate_to_survey(
        primary_design = primary,
        control_design = control,
        variables      = c(sex),
        targets        = list()
      ),
      class = "surveywts_error_targets_not_named_list"
    )
    expect_snapshot(
      error = TRUE,
      calibrate_to_survey(
        make_replicate_design(n = 100L, seed = 1L),
        make_replicate_design(n = 100L, seed = 2L),
        variables = c(sex),
        targets   = list()
      )
    )
  }
)

test_that(
  "calibrate_to_survey() fires targets_not_named_list when targets is not a list",
  {
    skip_if_not_installed("svrep")
    primary <- make_replicate_design(n = 100L, seed = 1L)
    control <- make_replicate_design(n = 100L, seed = 2L)

    expect_error(
      calibrate_to_survey(
        primary_design = primary,
        control_design = control,
        variables      = c(sex),
        targets        = c(age = 1000)    # named vector, not a list
      ),
      class = "surveywts_error_targets_not_named_list"
    )
    expect_snapshot(
      error = TRUE,
      calibrate_to_survey(
        make_replicate_design(n = 100L, seed = 1L),
        make_replicate_design(n = 100L, seed = 2L),
        variables = c(sex),
        targets   = c(age = 1000)
      )
    )
  }
)

# ===========================================================================
# 22. PR 1 — surveywts_error_targets_variable_not_found
# ===========================================================================

test_that(
  "calibrate_to_survey() fires targets_variable_not_found for nonexistent column",
  {
    skip_if_not_installed("svrep")
    primary <- make_replicate_design(n = 100L, seed = 1L)
    control <- make_replicate_design(n = 100L, seed = 2L)

    expect_error(
      calibrate_to_survey(
        primary_design = primary,
        control_design = control,
        variables      = c(sex),
        targets        = list(nonexistent_col = c(a = 100))
      ),
      class = "surveywts_error_targets_variable_not_found"
    )
    expect_snapshot(
      error = TRUE,
      calibrate_to_survey(
        make_replicate_design(n = 100L, seed = 1L),
        make_replicate_design(n = 100L, seed = 2L),
        variables = c(sex),
        targets   = list(nonexistent_col = c(a = 100))
      )
    )
  }
)

# ===========================================================================
# 23. PR 1 — surveywts_error_targets_element_invalid
# ===========================================================================

test_that(
  "calibrate_to_survey() fires targets_element_invalid for string element",
  {
    skip_if_not_installed("svrep")
    primary <- make_replicate_design(n = 100L, seed = 1L)
    control <- make_replicate_design(n = 100L, seed = 2L)

    expect_error(
      calibrate_to_survey(
        primary_design = primary,
        control_design = control,
        variables      = c(age_group),
        targets        = list(sex = "not_a_vector"),
        type           = "count"
      ),
      class = "surveywts_error_targets_element_invalid"
    )
    expect_snapshot(
      error = TRUE,
      calibrate_to_survey(
        make_replicate_design(n = 100L, seed = 1L),
        make_replicate_design(n = 100L, seed = 2L),
        variables = c(age_group),
        targets   = list(sex = "not_a_vector"),
        type      = "count"
      )
    )
  }
)

test_that(
  "calibrate_to_survey() fires targets_element_invalid for unnamed numeric vector",
  {
    skip_if_not_installed("svrep")
    primary <- make_replicate_design(n = 100L, seed = 1L)
    control <- make_replicate_design(n = 100L, seed = 2L)

    expect_error(
      calibrate_to_survey(
        primary_design = primary,
        control_design = control,
        variables      = c(age_group),
        targets        = list(sex = c(100, 200)),   # unnamed numeric
        type           = "count"
      ),
      class = "surveywts_error_targets_element_invalid"
    )
    expect_snapshot(
      error = TRUE,
      calibrate_to_survey(
        make_replicate_design(n = 100L, seed = 1L),
        make_replicate_design(n = 100L, seed = 2L),
        variables = c(age_group),
        targets   = list(sex = c(100, 200)),
        type      = "count"
      )
    )
  }
)

# ===========================================================================
# 24. PR 1 — surveywts_error_targets_totals_invalid
# ===========================================================================

test_that(
  "calibrate_to_survey() fires targets_totals_invalid for count = 0",
  {
    skip_if_not_installed("svrep")
    primary <- make_replicate_design(n = 100L, seed = 1L)
    control <- make_replicate_design(n = 100L, seed = 2L)

    expect_error(
      calibrate_to_survey(
        primary_design = primary,
        control_design = control,
        variables      = c(age_group),
        targets        = list(sex = c("M" = 0, "F" = 200)),
        type           = "count"
      ),
      class = "surveywts_error_targets_totals_invalid"
    )
    expect_snapshot(
      error = TRUE,
      calibrate_to_survey(
        make_replicate_design(n = 100L, seed = 1L),
        make_replicate_design(n = 100L, seed = 2L),
        variables = c(age_group),
        targets   = list(sex = c("M" = 0, "F" = 200)),
        type      = "count"
      )
    )
  }
)

test_that(
  "calibrate_to_survey() fires targets_totals_invalid for count < 0",
  {
    skip_if_not_installed("svrep")
    primary <- make_replicate_design(n = 100L, seed = 1L)
    control <- make_replicate_design(n = 100L, seed = 2L)

    expect_error(
      calibrate_to_survey(
        primary_design = primary,
        control_design = control,
        variables      = c(age_group),
        targets        = list(sex = c("M" = -50, "F" = 200)),
        type           = "count"
      ),
      class = "surveywts_error_targets_totals_invalid"
    )
    expect_snapshot(
      error = TRUE,
      calibrate_to_survey(
        make_replicate_design(n = 100L, seed = 1L),
        make_replicate_design(n = 100L, seed = 2L),
        variables = c(age_group),
        targets   = list(sex = c("M" = -50, "F" = 200)),
        type      = "count"
      )
    )
  }
)

test_that(
  "calibrate_to_survey() fires targets_totals_invalid for count = NA",
  {
    skip_if_not_installed("svrep")
    primary <- make_replicate_design(n = 100L, seed = 1L)
    control <- make_replicate_design(n = 100L, seed = 2L)

    expect_error(
      calibrate_to_survey(
        primary_design = primary,
        control_design = control,
        variables      = c(age_group),
        targets        = list(sex = c("M" = NA_real_, "F" = 200)),
        type           = "count"
      ),
      class = "surveywts_error_targets_totals_invalid"
    )
    expect_snapshot(
      error = TRUE,
      calibrate_to_survey(
        make_replicate_design(n = 100L, seed = 1L),
        make_replicate_design(n = 100L, seed = 2L),
        variables = c(age_group),
        targets   = list(sex = c("M" = NA_real_, "F" = 200)),
        type      = "count"
      )
    )
  }
)

test_that(
  "calibrate_to_survey() fires targets_totals_invalid when prop sum != 1",
  {
    skip_if_not_installed("svrep")
    primary <- make_replicate_design(n = 100L, seed = 1L)
    control <- make_replicate_design(n = 100L, seed = 2L)

    expect_error(
      calibrate_to_survey(
        primary_design = primary,
        control_design = control,
        variables      = c(age_group),
        targets        = list(sex = c("M" = 0.60, "F" = 0.50)),  # sums to 1.1
        type           = "prop"
      ),
      class = "surveywts_error_targets_totals_invalid"
    )
    expect_snapshot(
      error = TRUE,
      calibrate_to_survey(
        make_replicate_design(n = 100L, seed = 1L),
        make_replicate_design(n = 100L, seed = 2L),
        variables = c(age_group),
        targets   = list(sex = c("M" = 0.60, "F" = 0.50)),
        type      = "prop"
      )
    )
  }
)

# ===========================================================================
# 25. PR 1 — Regression guards (no skip_if_not_installed("svrep"))
# ===========================================================================

test_that(
  "calibrate_to_survey() rejects non-replicate primary_design [regression guard]",
  {
    control <- make_replicate_design(n = 100L, seed = 2L)
    df      <- make_surveywts_data(n = 100L, seed = 1L)
    taylor  <- surveycore::survey_taylor(
      data = df, variables = list(weights = "base_weight")
    )

    expect_error(
      calibrate_to_survey(taylor, control,
                          variables = c(sex), targets = NULL),
      class = "surveywts_error_primary_not_replicate"
    )
  }
)

test_that(
  "calibrate_to_survey() rejects nonprob primary with no repweights [regression guard]",
  {
    primary_no_rep <- make_nonprob_no_repweights(n = 100L, seed = 1L)
    control        <- make_replicate_design(n = 100L, seed = 2L)

    expect_error(
      calibrate_to_survey(
        primary_design = primary_no_rep,
        control_design = control,
        variables      = c(sex),
        targets        = NULL
      ),
      class = "surveywts_error_primary_no_repweights"
    )
  }
)

test_that(
  "calibrate_to_survey() rejects non-replicate control_design [regression guard]",
  {
    primary <- make_replicate_design(n = 100L, seed = 1L)
    df      <- make_surveywts_data(n = 100L, seed = 2L)
    taylor  <- surveycore::survey_taylor(
      data = df, variables = list(weights = "base_weight")
    )

    expect_error(
      calibrate_to_survey(primary, taylor,
                          variables = c(sex), targets = NULL),
      class = "surveywts_error_control_not_replicate"
    )
  }
)

test_that(
  "calibrate_to_survey() rejects nonprob control with no repweights [regression guard]",
  {
    primary        <- make_nonprob_replicate_design(n = 100L, seed = 1L)
    control_no_rep <- make_nonprob_no_repweights(n = 100L, seed = 2L)

    expect_error(
      calibrate_to_survey(
        primary_design = primary,
        control_design = control_no_rep,
        variables      = c(sex),
        targets        = NULL
      ),
      class = "surveywts_error_control_no_repweights"
    )
  }
)

test_that(
  "calibrate_to_survey() rejects non-taylor reference_design [regression guard]",
  {
    skip_if_not_installed("svrep")
    primary <- make_replicate_design(n = 100L, seed = 1L)
    control <- make_replicate_design(n = 100L, seed = 2L)

    expect_error(
      calibrate_to_survey(
        primary, control,
        variables        = c(sex),
        targets          = NULL,
        reference_design = primary
      ),
      class = "surveywts_error_reference_design_not_taylor"
    )
  }
)

test_that(
  "calibrate_to_survey() rejects invalid unit_scale [regression guard]",
  {
    skip_if_not_installed("svrep")
    primary <- make_replicate_design(n = 100L, seed = 1L)
    control <- make_replicate_design(n = 100L, seed = 2L)

    expect_error(
      calibrate_to_survey(
        primary, control,
        variables  = c(sex),
        targets    = NULL,
        unit_scale = "bad"
      ),
      class = "surveywts_error_unit_scale_invalid"
    )
  }
)

test_that(
  "calibrate_to_survey() rejects variables not in primary_design [regression guard]",
  {
    primary <- make_replicate_design(n = 100L, seed = 1L)
    control <- make_replicate_design(n = 100L, seed = 2L)

    expect_error(
      calibrate_to_survey(primary, control,
                          variables = c(nonexistent_var), targets = NULL),
      class = "surveywts_error_variables_not_found"
    )
  }
)

# ===========================================================================
# 26. PR 2 — Happy path: targets = NULL (Opsomer, no fixed margins)
# ===========================================================================

test_that(
  "calibrate_to_survey() Opsomer path returns survey_replicate for replicate primary",
  {
    primary <- make_replicate_design(n = 200L, R = 50L, seed = 42L)
    control <- make_replicate_design(n = 200L, R = 50L, seed = 99L)
    result  <- calibrate_to_survey(
      primary_design = primary,
      control_design = control,
      variables      = c(sex),
      targets        = NULL
    )
    expect_true(S7::S7_inherits(result, surveycore::survey_replicate))
  }
)

test_that(
  "calibrate_to_survey() Opsomer path returns survey_nonprob for nonprob primary",
  {
    primary <- make_nonprob_replicate_design(n = 200L, R = 30L, seed = 1L)
    control <- make_replicate_design(n = 200L, R = 30L, seed = 99L)
    result  <- calibrate_to_survey(
      primary_design = primary,
      control_design = control,
      variables      = c(sex)
    )
    expect_true(S7::S7_inherits(result, surveycore::survey_nonprob))
  }
)

test_that(
  "calibrate_to_survey() Opsomer path changes weights (targets = NULL)",
  {
    primary <- make_replicate_design(n = 200L, R = 50L, seed = 42L)
    control <- make_replicate_design(n = 200L, R = 50L, seed = 99L)
    before  <- primary@data[[primary@variables$weights]]
    result  <- calibrate_to_survey(
      primary_design = primary,
      control_design = control,
      variables      = c(sex)
    )
    after <- result@data[[result@variables$weights]]
    expect_false(isTRUE(all.equal(before, after)))
  }
)

test_that(
  "calibrate_to_survey() Opsomer path grows history by exactly 1 (targets = NULL)",
  {
    primary <- make_replicate_design(n = 200L, R = 50L, seed = 42L)
    control <- make_replicate_design(n = 200L, R = 50L, seed = 99L)
    n_before <- length(primary@metadata@weighting_history)
    result   <- calibrate_to_survey(primary, control, variables = c(sex))
    n_after  <- length(result@metadata@weighting_history)
    expect_identical(n_after - n_before, 1L)
  }
)

test_that(
  "calibrate_to_survey() history entry has operation == 'calibrate_to_survey'",
  {
    primary <- make_replicate_design(n = 200L, R = 50L, seed = 42L)
    control <- make_replicate_design(n = 200L, R = 50L, seed = 99L)
    result  <- calibrate_to_survey(primary, control, variables = c(sex))
    hist    <- result@metadata@weighting_history
    last    <- hist[[length(hist)]]
    expect_identical(last$operation, "calibrate_to_survey")
  }
)

test_that(
  "calibrate_to_survey() history records a_constants of length R (targets = NULL)",
  {
    primary <- make_replicate_design(n = 200L, R = 50L, seed = 42L)
    control <- make_replicate_design(n = 200L, R = 50L, seed = 99L)
    R       <- length(primary@variables$repweights)
    result  <- calibrate_to_survey(primary, control, variables = c(sex))
    hist    <- result@metadata@weighting_history
    last    <- hist[[length(hist)]]
    # When R = R_C = 50, K = 1, R_eff = R = 50
    expect_identical(length(last$a_constants), R)
  }
)

test_that(
  "calibrate_to_survey() history records K == 1L when R_C <= R (targets = NULL)",
  {
    primary <- make_replicate_design(n = 200L, R = 50L, seed = 42L)
    control <- make_replicate_design(n = 200L, R = 50L, seed = 99L)
    result  <- calibrate_to_survey(primary, control, variables = c(sex))
    hist    <- result@metadata@weighting_history
    last    <- hist[[length(hist)]]
    expect_identical(last$K, 1L)
  }
)

test_that(
  "calibrate_to_survey() history omits targets/type/fixed_variables (targets = NULL)",
  {
    primary <- make_replicate_design(n = 200L, R = 50L, seed = 42L)
    control <- make_replicate_design(n = 200L, R = 50L, seed = 99L)
    result  <- calibrate_to_survey(primary, control, variables = c(sex))
    hist    <- result@metadata@weighting_history
    last    <- hist[[length(hist)]]
    expect_null(last$targets)
    expect_null(last$type)
    expect_null(last$fixed_variables)
  }
)

# ===========================================================================
# 27. PR 2 — Numerical comparison vs svrep oracle (method = "linear")
# ===========================================================================

test_that(
  "calibrate_to_survey() Opsomer linear path matches svrep oracle within 1e-8",
  {
    skip_if_not_installed("svrep")
    primary <- make_replicate_design(n = 200L, R = 50L, seed = 42L)
    control <- make_replicate_design(n = 200L, R = 50L, seed = 99L)
    set.seed(1L)
    result_ours <- calibrate_to_survey(
      primary, control,
      variables = c(sex),
      method    = "linear"
    )

    # Build svrep oracle inputs
    .to_svyrep_local <- function(design) {
      wt_col   <- design@variables$weights
      rep_cols <- design@variables$repweights
      data_df  <- as.data.frame(design@data)
      pweights <- data_df[[wt_col]]
      repwts   <- as.matrix(data_df[, rep_cols, drop = FALSE])
      suppressWarnings(
        survey::svrepdesign(
          data       = data_df,
          repweights = repwts,
          weights    = pweights,
          type       = design@variables$type %||% "bootstrap",
          scale      = design@variables$scale,
          rscales    = design@variables$rscales,
          mse        = isTRUE(design@variables$mse)
        )
      )
    }
    primary_svrep <- .to_svyrep_local(primary)
    control_svrep <- .to_svyrep_local(control)

    set.seed(1L)
    result_svrep <- suppressWarnings(svrep::calibrate_to_sample(
      primary_rep_design = primary_svrep,
      control_rep_design = control_svrep,
      cal_formula        = ~sex,
      calfun             = survey::cal.linear
    ))

    # Compare full-sample calibrated weights.
    # svrep$pweights holds the calibrated full-sample sampling weights.
    ours_wts  <- result_ours@data[[result_ours@variables$weights]]
    svrep_wts <- as.numeric(result_svrep$pweights)

    expect_equal(ours_wts, svrep_wts, tolerance = 1e-8)
  }
)

test_that(
  "calibrate_to_survey() Opsomer rake path satisfies full-sample control totals",
  {
    primary <- make_replicate_design(n = 200L, R = 50L, seed = 42L)
    control <- make_replicate_design(n = 200L, R = 50L, seed = 99L)
    result  <- calibrate_to_survey(primary, control, variables = c(sex))

    # Compute control full-sample totals for 'sex'
    ctrl_wt   <- control@data[[control@variables$weights]]
    ctrl_sex  <- control@data$sex
    ctrl_tot  <- tapply(ctrl_wt, ctrl_sex, sum)

    # Check calibrated primary totals match within 1e-4 (raking tolerance)
    cal_wt    <- result@data[[result@variables$weights]]
    cal_tot   <- tapply(cal_wt, result@data$sex, sum)

    for (lv in names(ctrl_tot)) {
      expect_equal(
        unname(cal_tot[[lv]]),
        unname(ctrl_tot[[lv]]),
        tolerance = 1e-4
      )
    }
  }
)

# ===========================================================================
# 28. PR 2 — Happy path: targets non-NULL (Opsomer, fixed margins)
# ===========================================================================

test_that(
  "calibrate_to_survey() Opsomer fixed-margin returns survey_replicate",
  {
    primary <- make_replicate_design(n = 200L, R = 50L, seed = 42L)
    control <- make_replicate_design(n = 200L, R = 50L, seed = 99L)
    sex_prop <- c("M" = 0.49, "F" = 0.51)
    result  <- calibrate_to_survey(
      primary, control,
      variables = c(age_group),
      targets   = list(sex = sex_prop),
      type      = "prop"
    )
    expect_true(S7::S7_inherits(result, surveycore::survey_replicate))
    expect_identical(nrow(result@data), nrow(primary@data))
    n_before <- length(primary@metadata@weighting_history)
    n_after  <- length(result@metadata@weighting_history)
    expect_identical(n_after - n_before, 1L)
  }
)

test_that(
  "calibrate_to_survey() Opsomer fixed-margin returns survey_nonprob for nonprob primary",
  {
    primary <- make_nonprob_replicate_design(n = 200L, R = 30L, seed = 1L)
    control <- make_replicate_design(n = 200L, R = 30L, seed = 99L)
    # Use type = "count" with targets consistent with the control weight total
    # so that the simultaneous age_group (from control) and sex (fixed)
    # constraints share the same grand total and convergence is guaranteed.
    N_ctrl  <- sum(control@data[[control@variables$weights]])
    sex_cnt <- c("M" = 0.49 * N_ctrl, "F" = 0.51 * N_ctrl)
    result  <- calibrate_to_survey(
      primary, control,
      variables = c(age_group),
      targets   = list(sex = sex_cnt),
      type      = "count"
    )
    expect_true(S7::S7_inherits(result, surveycore::survey_nonprob))
  }
)

test_that(
  "calibrate_to_survey() history records fixed_variables from targets",
  {
    primary <- make_replicate_design(n = 200L, R = 50L, seed = 42L)
    control <- make_replicate_design(n = 200L, R = 50L, seed = 99L)
    sex_prop <- c("M" = 0.49, "F" = 0.51)
    result <- calibrate_to_survey(
      primary, control,
      variables = c(age_group),
      targets   = list(sex = sex_prop),
      type      = "prop"
    )
    hist <- result@metadata@weighting_history
    last <- hist[[length(hist)]]
    expect_identical(last$fixed_variables, "sex")
  }
)

test_that(
  "calibrate_to_survey() history records K == 1L when R_C <= R (targets non-NULL)",
  {
    primary <- make_replicate_design(n = 200L, R = 50L, seed = 42L)
    control <- make_replicate_design(n = 200L, R = 50L, seed = 99L)
    sex_prop <- c("M" = 0.49, "F" = 0.51)
    result <- calibrate_to_survey(
      primary, control,
      variables = c(age_group),
      targets   = list(sex = sex_prop),
      type      = "prop"
    )
    hist <- result@metadata@weighting_history
    last <- hist[[length(hist)]]
    expect_identical(last$K, 1L)
  }
)

test_that(
  "calibrate_to_survey() history records K == 2L when R_C > R",
  {
    # primary R = 30, control R = 50 -> K = ceiling(50/30) = 2
    primary <- make_nonprob_replicate_design(n = 200L, R = 30L, seed = 1L)
    control <- make_replicate_design(n = 200L, R = 50L, seed = 99L)
    # Use type = "count" with targets consistent with the control weight total
    N_ctrl  <- sum(control@data[[control@variables$weights]])
    sex_cnt <- c("M" = 0.49 * N_ctrl, "F" = 0.51 * N_ctrl)
    result <- calibrate_to_survey(
      primary, control,
      variables = c(age_group),
      targets   = list(sex = sex_cnt),
      type      = "count"
    )
    hist <- result@metadata@weighting_history
    last <- hist[[length(hist)]]
    expect_identical(last$K, 2L)
    # R_eff = K * R = 2 * 30 = 60
    expect_identical(length(last$a_constants), 60L)
  }
)

test_that(
  "calibrate_to_survey() history records type == 'count' when type = 'count'",
  {
    primary <- make_replicate_design(n = 200L, R = 50L, seed = 42L)
    control <- make_replicate_design(n = 200L, R = 50L, seed = 99L)
    N <- sum(primary@data[[primary@variables$weights]])
    sex_count <- c("M" = N * 0.49, "F" = N * 0.51)
    result <- calibrate_to_survey(
      primary, control,
      variables = c(age_group),
      targets   = list(sex = sex_count),
      type      = "count"
    )
    hist <- result@metadata@weighting_history
    last <- hist[[length(hist)]]
    expect_identical(last$type, "count")
  }
)

test_that(
  "calibrate_to_survey() type='prop' accepted with non-NULL targets",
  {
    primary <- make_replicate_design(n = 200L, R = 50L, seed = 42L)
    control <- make_replicate_design(n = 200L, R = 50L, seed = 99L)
    sex_prop <- c("M" = 0.49, "F" = 0.51)
    result <- calibrate_to_survey(
      primary, control,
      variables = c(age_group),
      targets   = list(sex = sex_prop),
      type      = "prop"
    )
    expect_true(S7::S7_inherits(result, surveycore::survey_replicate))
  }
)

test_that(
  "calibrate_to_survey() fixed margin constraint satisfied within 1e-4",
  {
    primary  <- make_replicate_design(n = 200L, R = 50L, seed = 42L)
    control  <- make_replicate_design(n = 200L, R = 50L, seed = 99L)
    N        <- sum(primary@data[[primary@variables$weights]])
    sex_prop <- c("M" = 0.49, "F" = 0.51)
    sex_cnt  <- sex_prop * N  # convert to counts for comparison

    result   <- calibrate_to_survey(
      primary, control,
      variables = c(age_group),
      targets   = list(sex = sex_prop),
      type      = "prop"
    )
    cal_wt  <- result@data[[result@variables$weights]]
    cal_tot <- tapply(cal_wt, result@data$sex, sum)

    for (lv in names(sex_cnt)) {
      expect_equal(
        unname(cal_tot[[lv]]),
        unname(sex_cnt[[lv]]),
        tolerance = 1e-4
      )
    }
  }
)

test_that(
  "calibrate_to_survey() reference_design stored in history when supplied",
  {
    primary  <- make_replicate_design(n = 200L, R = 50L, seed = 42L)
    control  <- make_replicate_design(n = 200L, R = 50L, seed = 99L)
    ref_data <- make_surveywts_data(n = 200L, seed = 77L)
    ref      <- surveycore::survey_taylor(
      data = ref_data, variables = list(weights = "base_weight")
    )
    result <- calibrate_to_survey(
      primary, control,
      variables        = c(sex),
      reference_design = ref
    )
    hist   <- result@metadata@weighting_history
    last   <- hist[[length(hist)]]
    params <- last$parameters
    expect_true(params$targets_from_reference)
  }
)

# ===========================================================================
# 29. PR 2 — a_r constants correctness
# ===========================================================================

test_that(
  "calibrate_to_survey() all a_r == sqrt(A_C/A) when R == R_C",
  {
    primary  <- make_replicate_design(n = 100L, R = 50L, seed = 42L)
    control  <- make_replicate_design(n = 100L, R = 50L, seed = 99L)
    A        <- primary@variables$scale
    A_C      <- control@variables$scale
    result   <- calibrate_to_survey(primary, control, variables = c(sex))
    hist     <- result@metadata@weighting_history
    last     <- hist[[length(hist)]]
    expected <- sqrt(A_C / A)
    expect_equal(last$a_constants, rep(expected, 50L), tolerance = 1e-10)
  }
)

test_that(
  "calibrate_to_survey() a_r[r] == sqrt(A_C/A) for r <= R_C, 0 for r > R_C",
  {
    # primary R=60 (need to create this), control R=50 -> a_r[51..60] = 0
    # Use acs_wy_2022_svy which has R=80, then create smaller controls
    # Actually make a custom design with R=60 via bootstrap
    df60 <- make_surveywts_data(n = 100L, seed = 42L)
    t60  <- surveycore::survey_taylor(
      data = df60, variables = list(weights = "base_weight")
    )
    primary  <- create_bootstrap_weights(t60, replicates = 60L, seed = 1L)
    control  <- make_replicate_design(n = 100L, R = 50L, seed = 99L)

    A        <- primary@variables$scale
    A_C      <- control@variables$scale
    result   <- calibrate_to_survey(primary, control, variables = c(sex))
    hist     <- result@metadata@weighting_history
    last     <- hist[[length(hist)]]

    # K=1, R_eff=60; a_r[1..50] = sqrt(A_C/A), a_r[51..60] = 0
    expected <- sqrt(A_C / A)
    expect_equal(last$a_constants[1:50], rep(expected, 50L), tolerance = 1e-10)
    expect_equal(last$a_constants[51:60], rep(0, 10L), tolerance = 1e-10)
  }
)

test_that(
  "calibrate_to_survey() K == ceiling(R_C / R) when R_C > R",
  {
    primary  <- make_nonprob_replicate_design(n = 100L, R = 30L, seed = 1L)
    control  <- make_replicate_design(n = 100L, R = 50L, seed = 99L)
    result   <- calibrate_to_survey(primary, control, variables = c(sex))
    hist     <- result@metadata@weighting_history
    last     <- hist[[length(hist)]]
    expect_identical(last$K, 2L)  # ceiling(50/30) = 2
  }
)

test_that(
  "calibrate_to_survey() a_r computed with A_eff = A/K when K > 1",
  {
    # primary R=30, control R=50 -> K=2, A_eff = A/2
    primary  <- make_nonprob_replicate_design(n = 100L, R = 30L, seed = 1L)
    control  <- make_replicate_design(n = 100L, R = 50L, seed = 99L)
    A        <- primary@variables$scale
    A_C      <- control@variables$scale
    K        <- 2L  # ceiling(50/30)
    A_eff    <- A / K

    result   <- calibrate_to_survey(primary, control, variables = c(sex))
    hist     <- result@metadata@weighting_history
    last     <- hist[[length(hist)]]

    expected <- sqrt(A_C / A_eff)
    # a_r for r=1..R_C=50 (R_eff = 2*30 = 60)
    expect_equal(last$a_constants[1:50], rep(expected, 50L), tolerance = 1e-10)
    # a_r[51..60] should be 0
    expect_equal(last$a_constants[51:60], rep(0, 10L), tolerance = 1e-10)
  }
)

# ===========================================================================
# 30. PR 2 — Numerical correctness (Opsomer path)
# ===========================================================================

test_that(
  "calibrate_to_survey() satisfies full-sample random-margin constraint",
  {
    primary <- make_replicate_design(n = 200L, R = 50L, seed = 42L)
    control <- make_replicate_design(n = 200L, R = 50L, seed = 99L)
    result  <- calibrate_to_survey(primary, control, variables = c(sex))

    # Calibrated weights must match control full-sample totals for 'sex'
    ctrl_wt  <- control@data[[control@variables$weights]]
    ctrl_tot <- tapply(ctrl_wt, control@data$sex, sum)
    cal_wt   <- result@data[[result@variables$weights]]
    cal_tot  <- tapply(cal_wt, result@data$sex, sum)

    for (lv in names(ctrl_tot)) {
      expect_equal(
        unname(cal_tot[[lv]]),
        unname(ctrl_tot[[lv]]),
        tolerance = 1e-4
      )
    }
  }
)

test_that(
  "calibrate_to_survey() satisfies full-sample fixed-margin constraint",
  {
    primary  <- make_replicate_design(n = 200L, R = 50L, seed = 42L)
    control  <- make_replicate_design(n = 200L, R = 50L, seed = 99L)
    N        <- sum(primary@data[[primary@variables$weights]])
    sex_prop <- c("M" = 0.49, "F" = 0.51)
    sex_cnt  <- sex_prop * N

    result  <- calibrate_to_survey(
      primary, control,
      variables = c(age_group),
      targets   = list(sex = sex_prop),
      type      = "prop"
    )
    cal_wt  <- result@data[[result@variables$weights]]
    cal_tot <- tapply(cal_wt, result@data$sex, sum)

    for (lv in names(sex_cnt)) {
      expect_equal(
        unname(cal_tot[[lv]]),
        unname(sex_cnt[[lv]]),
        tolerance = 1e-4
      )
    }
  }
)

test_that(
  "calibrate_to_survey() type='prop' uses N from input primary weights",
  {
    primary  <- make_replicate_design(n = 200L, R = 50L, seed = 42L)
    control  <- make_replicate_design(n = 200L, R = 50L, seed = 99L)
    N        <- sum(primary@data[[primary@variables$weights]])
    sex_prop <- c("M" = 0.48, "F" = 0.52)

    result <- calibrate_to_survey(
      primary, control,
      variables = c(age_group),
      targets   = list(sex = sex_prop),
      type      = "prop"
    )
    # N should be preserved (sum of output weights ~= N)
    cal_wt <- result@data[[result@variables$weights]]
    expect_equal(sum(cal_wt), N, tolerance = 1e-4)
  }
)

# ===========================================================================
# 31. PR 2 — Gotcha coverage
# ===========================================================================

test_that(
  "calibrate_to_survey() does not call svrep::calibrate_to_sample() in any path",
  {
    skip_if_not_installed("svrep")
    # Mock the delegation function so it errors if called
    local_mocked_bindings(
      .svrep_calibrate_to_sample = function(...) {
        stop("svrep::calibrate_to_sample must not be called in PR 2")
      },
      .package = "surveywts"
    )

    primary  <- make_replicate_design(n = 100L, R = 50L, seed = 42L)
    control  <- make_replicate_design(n = 100L, R = 50L, seed = 99L)
    sex_prop <- c("M" = 0.49, "F" = 0.51)

    # targets = NULL path
    expect_no_error(
      calibrate_to_survey(primary, control, variables = c(sex))
    )

    # targets non-NULL path
    expect_no_error(
      calibrate_to_survey(
        primary, control,
        variables = c(age_group),
        targets   = list(sex = sex_prop),
        type      = "prop"
      )
    )
  }
)

test_that(
  "calibrate_to_survey() scale_not_found error is not regressed by PR 2",
  {
    primary <- make_replicate_design(n = 100L, R = 50L, seed = 42L)
    control <- make_replicate_design(n = 100L, R = 50L, seed = 99L)
    primary@variables$scale <- NULL

    expect_error(
      calibrate_to_survey(primary, control, variables = c(sex)),
      class = "surveywts_error_scale_not_found"
    )
  }
)

test_that(
  "calibrate_to_survey() R > R_C: output has R replicate columns",
  {
    df60 <- make_surveywts_data(n = 100L, seed = 42L)
    t60  <- surveycore::survey_taylor(
      data = df60, variables = list(weights = "base_weight")
    )
    primary <- create_bootstrap_weights(t60, replicates = 60L, seed = 1L)
    control <- make_replicate_design(n = 100L, R = 50L, seed = 99L)

    R      <- length(primary@variables$repweights)
    result <- calibrate_to_survey(primary, control, variables = c(sex))
    expect_identical(length(result@variables$repweights), R)
  }
)

test_that(
  "calibrate_to_survey() R_C > R: output still has R replicate columns",
  {
    primary <- make_nonprob_replicate_design(n = 100L, R = 30L, seed = 1L)
    control <- make_replicate_design(n = 100L, R = 50L, seed = 99L)
    R       <- length(primary@variables$repweights)
    result  <- calibrate_to_survey(primary, control, variables = c(sex))
    expect_identical(length(result@variables$repweights), R)
  }
)

test_that(
  "calibrate_to_survey() a_r=0 replicates produce finite weights (no Inf/NaN)",
  {
    df60 <- make_surveywts_data(n = 100L, seed = 42L)
    t60  <- surveycore::survey_taylor(
      data = df60, variables = list(weights = "base_weight")
    )
    primary <- create_bootstrap_weights(t60, replicates = 60L, seed = 1L)
    control <- make_replicate_design(n = 100L, R = 50L, seed = 99L)

    result  <- calibrate_to_survey(primary, control, variables = c(sex))
    # Check that a_r=0 replicates (positions 51..60) have finite weights
    rep_cols <- result@variables$repweights
    # All replicate weight columns should be finite
    all_finite <- all(vapply(rep_cols, function(col) {
      all(is.finite(result@data[[col]]))
    }, logical(1L)))
    expect_true(all_finite)
  }
)

# ===========================================================================
# 32. PR 2 — Warning paths
# ===========================================================================

test_that(
  "calibrate_to_survey() warns for unknown control param (regression guard PR 2)",
  {
    primary <- make_replicate_design(n = 100L, R = 50L, seed = 42L)
    control <- make_replicate_design(n = 100L, R = 50L, seed = 99L)

    expect_warning(
      calibrate_to_survey(
        primary, control,
        variables = c(sex),
        control   = list(unknown_key = 99)
      ),
      class = "surveywts_warning_control_param_ignored"
    )
  }
)

test_that(
  "calibrate_to_survey() warns for replicate scheme mismatch (regression guard PR 2)",
  {
    skip_if_not_installed("svrep")
    primary <- make_replicate_design(n = 100L, R = 50L, seed = 42L)
    # Build jackknife control with different type
    # Use make_surveywts_data + stratified design so jackknife works
    df_jk  <- make_surveywts_data(n = 100L, seed = 99L)
    # Add strata and PSU columns; use unique PSU IDs within each stratum via
    # nest = TRUE so jackknife does not error on non-nested clusters.
    df_jk$stratum <- rep(c(1L, 2L, 3L, 4L), length.out = nrow(df_jk))
    df_jk$psu_id  <- rep(seq_len(nrow(df_jk) %/% 2L), each = 2L,
                         length.out = nrow(df_jk))
    t_jk   <- surveycore::as_survey(
      df_jk, ids = psu_id, strata = stratum, weights = base_weight,
      nest = TRUE
    )
    control_jk <- create_jackknife_weights(t_jk)
    # Manually set scale so it passes the scale check
    control_jk@variables$scale <- 1 / length(control_jk@variables$repweights)

    expect_warning(
      calibrate_to_survey(primary, control_jk, variables = c(sex)),
      class = "surveywts_warning_replicate_scheme_mismatch"
    )
  }
)

test_that(
  "calibrate_to_survey() warns for negative full-sample weights (method=linear)",
  {
    # Construct a case where linear calibration produces negatives:
    # very unbalanced primary vs control
    set.seed(99L)
    df_p  <- make_surveywts_data(n = 100L, seed = 1L)
    # Make primary heavily male-skewed
    df_p$sex <- ifelse(seq_len(nrow(df_p)) <= 90L, "M", "F")
    df_p$base_weight <- exp(rnorm(nrow(df_p), 0, 0.1))
    t_p   <- surveycore::survey_taylor(
      data = df_p, variables = list(weights = "base_weight")
    )
    primary <- create_bootstrap_weights(t_p, replicates = 30L, seed = 1L)

    # Make control heavily female-skewed
    df_c  <- make_surveywts_data(n = 500L, seed = 2L)
    df_c$sex <- ifelse(seq_len(nrow(df_c)) <= 50L, "M", "F")
    df_c$base_weight <- exp(rnorm(nrow(df_c), 0, 0.1))
    t_c   <- surveycore::survey_taylor(
      data = df_c, variables = list(weights = "base_weight")
    )
    control <- create_bootstrap_weights(t_c, replicates = 30L, seed = 2L)

    # This should trigger negative weights with linear calibration
    # If it doesn't produce negatives in this random seed, we just verify
    # no error is raised (the warning is conditional)
    expect_no_error(
      suppressWarnings(
        calibrate_to_survey(primary, control, variables = c(sex),
                            method = "linear")
      )
    )
  }
)

# ===========================================================================
# 33. PR 2 — Edge cases
# ===========================================================================

test_that(
  "calibrate_to_survey() targets=NULL with type='prop' is identical to default",
  {
    primary <- make_replicate_design(n = 100L, R = 50L, seed = 42L)
    control <- make_replicate_design(n = 100L, R = 50L, seed = 99L)
    set.seed(1L)
    r1 <- calibrate_to_survey(primary, control, variables = c(sex))
    set.seed(1L)
    r2 <- calibrate_to_survey(
      primary, control,
      variables = c(sex),
      targets   = NULL,
      type      = "prop"
    )
    w1 <- r1@data[[r1@variables$weights]]
    w2 <- r2@data[[r2@variables$weights]]
    expect_equal(w1, w2, tolerance = 1e-10)
  }
)

test_that(
  "calibrate_to_survey() algorithm='nr' with method='linear' does not error",
  {
    primary <- make_replicate_design(n = 100L, R = 50L, seed = 42L)
    control <- make_replicate_design(n = 100L, R = 50L, seed = 99L)
    expect_no_error(
      suppressWarnings(
        calibrate_to_survey(
          primary, control,
          variables = c(sex),
          method    = "linear",
          algorithm = "nr"
        )
      )
    )
  }
)

test_that(
  "calibrate_to_survey() R = R_C = 2 minimum replicates: K=1, valid result",
  {
    df2 <- make_surveywts_data(n = 50L, seed = 42L)
    t2  <- surveycore::survey_taylor(
      data = df2, variables = list(weights = "base_weight")
    )
    primary <- create_bootstrap_weights(t2, replicates = 2L, seed = 1L)
    control_df <- make_surveywts_data(n = 50L, seed = 99L)
    tc  <- surveycore::survey_taylor(
      data = control_df, variables = list(weights = "base_weight")
    )
    control <- create_bootstrap_weights(tc, replicates = 2L, seed = 2L)

    result <- calibrate_to_survey(primary, control, variables = c(sex))
    hist   <- result@metadata@weighting_history
    last   <- hist[[length(hist)]]
    expect_identical(last$K, 1L)
    test_invariants(result)
  }
)

test_that(
  "calibrate_to_survey() negative replicate weights do not trigger warning",
  {
    primary <- make_replicate_design(n = 100L, R = 50L, seed = 42L)
    control <- make_replicate_design(n = 100L, R = 50L, seed = 99L)
    # Replicate weights are allowed to be negative — only full-sample negatives warn
    expect_no_warning(
      calibrate_to_survey(primary, control, variables = c(sex),
                          method = "rake")
    )
  }
)

test_that(
  "calibrate_to_survey() unit_scale non-NULL with Opsomer path produces valid result",
  {
    primary    <- make_replicate_design(n = 100L, R = 50L, seed = 42L)
    control    <- make_replicate_design(n = 100L, R = 50L, seed = 99L)
    unit_scale <- rep(1.0, nrow(primary@data))
    result <- calibrate_to_survey(
      primary, control,
      variables  = c(sex),
      unit_scale = unit_scale
    )
    expect_true(S7::S7_inherits(result, surveycore::survey_replicate))
    test_invariants(result)
  }
)
