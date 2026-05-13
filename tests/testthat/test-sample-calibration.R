# tests/testthat/test-sample-calibration.R
#
# Tests for calibrate_to_survey() and calibrate_to_estimate()
# Per spec §III and §IV
# Per impl plan PR 2 acceptance criteria
#
# All error path tests use the dual pattern:
#   expect_error(class = ...) + expect_snapshot(error = TRUE, ...)
#
# estimate for calibrate_to_estimate() uses svytotal-compatible names
# (all factor levels), matching what svrep::calibrate_to_estimate() requires.

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

# Build an svyrep.design from a survey_replicate without calling the internal
# .to_svyrep_design() helper (mirrors its implementation for test use).
.make_svyrep <- function(design) {
  vars <- design@variables
  survey::svrepdesign(
    data = design@data,
    weights = design@data[[vars$weights]],
    repweights = design@data[vars$repweights],
    type = vars$type,
    scale = vars$scale,
    rscales = vars$rscales,
    combined.weights = FALSE,
    mse = if (!is.null(vars$mse)) vars$mse else TRUE
  )
}

# Compute svytotal-compatible estimate and vcov from a control design.
.control_totals <- function(formula, control_design) {
  svyrep <- .make_svyrep(control_design)
  tot <- survey::svytotal(formula, svyrep)
  list(estimate = coef(tot), vcov_estimate = vcov(tot))
}

# ---------------------------------------------------------------------------
# 1. calibrate_to_survey() — happy path
# ---------------------------------------------------------------------------

test_that("calibrate_to_survey() returns survey_replicate with updated weights", {
  primary <- make_replicate_design(n_replicates = 50L, seed = 1L)
  control <- make_replicate_design(n_replicates = 50L, seed = 2L)

  result <- calibrate_to_survey(primary, control, ~ sex)

  test_invariants(result)
  expect_true(S7::S7_inherits(result, surveycore::survey_replicate))
  expect_identical(result@variables$repweights, primary@variables$repweights)
  expect_identical(result@variables$type, primary@variables$type)
})

test_that("calibrate_to_survey() appends history entry operation = 'sample_calibration_replicate'", {
  primary <- make_replicate_design(n_replicates = 50L, seed = 1L)
  control <- make_replicate_design(n_replicates = 50L, seed = 2L)

  result <- calibrate_to_survey(primary, control, ~ sex)

  history <- result@metadata@weighting_history
  last <- history[[length(history)]]
  expect_identical(last$operation, "sample_calibration_replicate")
  expect_identical(last$step, length(history))
})

test_that("test_invariants() passes on calibrate_to_survey() result", {
  primary <- make_replicate_design(n_replicates = 50L, seed = 3L)
  control <- make_replicate_design(n_replicates = 50L, seed = 4L)

  result <- calibrate_to_survey(primary, control, ~ sex)

  test_invariants(result)
})

# ---------------------------------------------------------------------------
# 2. calibrate_to_survey() — numerical correctness
# ---------------------------------------------------------------------------

test_that("calibrate_to_survey() full-sample weights satisfy calibration constraints within 1e-6", {
  primary <- make_replicate_design(n_replicates = 50L, seed = 1L)
  control <- make_replicate_design(n_replicates = 50L, seed = 2L)
  formula <- ~sex

  result <- calibrate_to_survey(primary, control, formula)

  w_new <- result@data[[result@variables$weights]]
  w_ctrl <- control@data[[control@variables$weights]]

  # For each level of sex, calibrated total in primary ≈ weighted total in control.
  # Tolerance 1e-6: svrep's default epsilon=1e-7 convergence achieves this precision.
  for (lvl in unique(primary@data$sex)) {
    total_new <- sum(w_new[result@data$sex == lvl])
    total_ctrl <- sum(w_ctrl[control@data$sex == lvl])
    expect_equal(total_new, total_ctrl, tolerance = 1e-6,
                 label = paste0("sex == '", lvl, "' total"))
  }
})

test_that("calibrate_to_survey() weight total aligns with control survey total, not primary total", {
  primary <- make_replicate_design(n_replicates = 50L, seed = 1L)
  control <- make_replicate_design(n_replicates = 50L, seed = 2L)

  result <- calibrate_to_survey(primary, control, ~sex)

  w_new <- result@data[[result@variables$weights]]
  w_ctrl <- control@data[[control@variables$weights]]

  expect_equal(sum(w_new), sum(w_ctrl), tolerance = 1e-6)
})

# ---------------------------------------------------------------------------
# 3. calibrate_to_survey() — error paths
# ---------------------------------------------------------------------------

test_that("calibrate_to_survey() errors when primary_design is not survey_replicate", {
  control <- make_replicate_design(n_replicates = 50L, seed = 1L)
  df <- make_surveywts_data(seed = 1L)

  expect_error(
    calibrate_to_survey(df, control, ~sex),
    class = "surveywts_error_primary_not_replicate"
  )
  expect_snapshot(error = TRUE,
    calibrate_to_survey(df, control, ~sex)
  )
})

test_that("calibrate_to_survey() errors when control_design is not survey_replicate", {
  primary <- make_replicate_design(n_replicates = 50L, seed = 1L)
  df <- make_surveywts_data(seed = 2L)

  expect_error(
    calibrate_to_survey(primary, df, ~sex),
    class = "surveywts_error_control_not_replicate"
  )
  expect_snapshot(error = TRUE,
    calibrate_to_survey(primary, df, ~sex)
  )
})

test_that("calibrate_to_survey() errors on replicate count mismatch", {
  primary <- make_replicate_design(n_replicates = 50L, seed = 1L)
  control <- make_replicate_design(n_replicates = 30L, seed = 2L)

  expect_error(
    calibrate_to_survey(primary, control, ~sex),
    class = "surveywts_error_replicate_count_mismatch"
  )
  expect_snapshot(error = TRUE,
    calibrate_to_survey(primary, control, ~sex)
  )
})

test_that("calibrate_to_survey() errors when formula variable missing from primary_design", {
  primary <- make_replicate_design(n_replicates = 50L, seed = 1L)
  control <- make_replicate_design(n_replicates = 50L, seed = 2L)

  expect_error(
    calibrate_to_survey(primary, control, ~no_such_col),
    class = "surveywts_error_formula_variable_not_found"
  )
  expect_snapshot(error = TRUE,
    calibrate_to_survey(primary, control, ~no_such_col)
  )
})

test_that("calibrate_to_survey() errors when formula variable missing from control_design", {
  primary <- make_replicate_design(n_replicates = 50L, seed = 1L)
  control <- make_replicate_design(n_replicates = 50L, seed = 2L)

  # Add column only to primary so control is missing it
  primary@data$only_in_primary <- seq_len(nrow(primary@data))

  expect_error(
    calibrate_to_survey(primary, control, ~only_in_primary),
    class = "surveywts_error_formula_variable_not_found"
  )
  expect_snapshot(error = TRUE,
    calibrate_to_survey(primary, control, ~only_in_primary)
  )
})

test_that("calibrate_to_survey() errors when formula is not a formula object", {
  primary <- make_replicate_design(n_replicates = 50L, seed = 1L)
  control <- make_replicate_design(n_replicates = 50L, seed = 2L)

  expect_error(
    calibrate_to_survey(primary, control, "~sex"),
    class = "surveywts_error_formula_invalid"
  )
  expect_snapshot(error = TRUE,
    calibrate_to_survey(primary, control, "~sex")
  )
})

test_that("calibrate_to_survey() errors when calibration does not converge", {
  primary <- make_replicate_design(n_replicates = 50L, seed = 1L)
  control <- make_replicate_design(n_replicates = 50L, seed = 2L)

  # epsilon = 1e-100 is impossible to achieve; maxit = 1 ensures failure
  expect_error(
    calibrate_to_survey(
      primary, control, ~sex,
      control = list(maxit = 1L, epsilon = 1e-100)
    ),
    class = "surveywts_error_calibration_not_converged"
  )
  expect_snapshot(error = TRUE,
    calibrate_to_survey(
      primary, control, ~sex,
      control = list(maxit = 1L, epsilon = 1e-100)
    )
  )
})

test_that("calibrate_to_survey() errors when svrep warns convergence but returns normally", {
  primary <- make_replicate_design(n_replicates = 10L, seed = 1L)
  control <- make_replicate_design(n_replicates = 10L, seed = 2L)

  # Mock svrep to emit a "converge" warning and return normally (Path B).
  # calibrated is not read before the if (!converged) check, so NULL is safe.
  testthat::local_mocked_bindings(
    calibrate_to_sample = function(...) {
      warning("did not converge after 1 iterations")
      NULL
    },
    .package = "svrep"
  )

  expect_error(
    calibrate_to_survey(primary, control, ~sex),
    class = "surveywts_error_calibration_not_converged"
  )
  expect_snapshot(
    error = TRUE,
    calibrate_to_survey(primary, control, ~sex)
  )
})

# ---------------------------------------------------------------------------
# 4. calibrate_to_survey() — warning paths
# ---------------------------------------------------------------------------

test_that("calibrate_to_survey() warns on replicate scheme mismatch and still calibrates", {
  # Build primary (bootstrap) and control (JK random-groups with 50 replicates)
  primary <- make_replicate_design(n_replicates = 50L, seed = 1L)

  df2 <- make_surveywts_data(n = 200L, seed = 2L)
  taylor2 <- surveycore::survey_taylor(
    data = df2,
    variables = list(weights = "base_weight")
  )
  control <- create_jackknife_weights(taylor2, type = "random-groups",
                                      replicates = 50L)

  expect_warning(
    result <- calibrate_to_survey(primary, control, ~sex),
    class = "surveywts_warning_replicate_scheme_mismatch"
  )

  test_invariants(result)
  expect_true(S7::S7_inherits(result, surveycore::survey_replicate))
})

test_that("calibrate_to_survey() warns on negative full-sample weights from linear calibration", {
  # Control has conflicting age + sex skew: young F = weight 100, old M = weight 0.001.
  # With additive ~age_group + sex formula, linear calibration must simultaneously
  # boost young and female weights while slashing old and male weights.
  # This over-adjustment forces 55+/M primary units into negative territory.
  df_p <- make_surveywts_data(n = 200L, seed = 1L)
  df_p$base_weight <- 1
  df_c <- df_p
  df_c$base_weight <- ifelse(
    df_c$age_group == "18-34" & df_c$sex == "F", 100,
    ifelse(df_c$age_group == "55+" & df_c$sex == "M", 0.001, 1)
  )

  taylor_p <- surveycore::survey_taylor(data = df_p,
                                        variables = list(weights = "base_weight"))
  taylor_c <- surveycore::survey_taylor(data = df_c,
                                        variables = list(weights = "base_weight"))

  primary <- create_bootstrap_weights(taylor_p, replicates = 50L)
  control <- create_bootstrap_weights(taylor_c, replicates = 50L)

  expect_warning(
    calibrate_to_survey(primary, control, ~age_group + sex, method = "linear"),
    class = "surveywts_warning_negative_calibrated_weights"
  )
})

# ---------------------------------------------------------------------------
# 5. calibrate_to_survey() — edge cases
# ---------------------------------------------------------------------------

test_that("calibrate_to_survey() works with a single formula variable", {
  primary <- make_replicate_design(n_replicates = 50L, seed = 1L)
  control <- make_replicate_design(n_replicates = 50L, seed = 2L)

  result <- calibrate_to_survey(primary, control, ~sex)

  test_invariants(result)
  expect_true(S7::S7_inherits(result, surveycore::survey_replicate))
})

test_that("calibrate_to_survey() works with formula interaction terms (age_group * sex)", {
  primary <- make_replicate_design(n_replicates = 50L, seed = 1L)
  control <- make_replicate_design(n_replicates = 50L, seed = 2L)

  result <- calibrate_to_survey(primary, control, ~age_group * sex)

  test_invariants(result)
  expect_true(S7::S7_inherits(result, surveycore::survey_replicate))
})

test_that("calibrate_to_survey() works with method = 'linear'", {
  primary <- make_replicate_design(n_replicates = 50L, seed = 5L)
  control <- make_replicate_design(n_replicates = 50L, seed = 6L)

  # Suppress expected negative weight warning for similar-ish data
  suppressWarnings(
    result <- calibrate_to_survey(primary, control, ~sex, method = "linear")
  )

  test_invariants(result)
  expect_true(S7::S7_inherits(result, surveycore::survey_replicate))
})

test_that("calibrate_to_survey() works with method = 'logit' and finite bounds", {
  primary <- make_replicate_design(n_replicates = 50L, seed = 1L)
  control <- make_replicate_design(n_replicates = 50L, seed = 2L)

  result <- calibrate_to_survey(
    primary, control, ~sex,
    method = "logit",
    bounds = list(lower = 0.1, upper = 10)
  )

  test_invariants(result)
  w_new <- result@data[[result@variables$weights]]
  expect_true(all(w_new >= 0.1))
  expect_true(all(w_new <= 10))
})

test_that("calibrate_to_survey() works with n_rep = 1", {
  # Bootstrap requires >= 2 replicates, so build 1-replicate designs directly.
  meta <- surveycore::survey_metadata()
  df_p <- make_surveywts_data(n = 100L, seed = 1L)
  df_p$rep_1 <- df_p$base_weight
  df_c <- make_surveywts_data(n = 100L, seed = 2L)
  df_c$rep_1 <- df_c$base_weight

  primary <- surveycore::survey_replicate(
    data = df_p,
    variables = list(
      weights = "base_weight", repweights = "rep_1",
      scale = 1, rscales = 1, type = "bootstrap", mse = TRUE
    ),
    metadata = meta, groups = character(0L), call = NULL
  )
  control <- surveycore::survey_replicate(
    data = df_c,
    variables = list(
      weights = "base_weight", repweights = "rep_1",
      scale = 1, rscales = 1, type = "bootstrap", mse = TRUE
    ),
    metadata = meta, groups = character(0L), call = NULL
  )

  result <- calibrate_to_survey(primary, control, ~sex)

  test_invariants(result)
  expect_true(S7::S7_inherits(result, surveycore::survey_replicate))
})

# ---------------------------------------------------------------------------
# 6. calibrate_to_estimate() — happy path
# ---------------------------------------------------------------------------

test_that("calibrate_to_estimate() returns survey_replicate with updated weights", {
  design <- make_replicate_design(n_replicates = 50L, seed = 1L)
  control <- make_replicate_design(n_replicates = 50L, seed = 2L)
  tots <- .control_totals(~sex, control)

  result <- calibrate_to_estimate(design, ~sex,
                                   estimate = tots$estimate,
                                   vcov_estimate = tots$vcov_estimate)

  test_invariants(result)
  expect_true(S7::S7_inherits(result, surveycore::survey_replicate))
  expect_identical(result@variables$repweights, design@variables$repweights)
})

test_that("calibrate_to_estimate() appends history entry operation = 'sample_calibration_estimate'", {
  design <- make_replicate_design(n_replicates = 50L, seed = 1L)
  control <- make_replicate_design(n_replicates = 50L, seed = 2L)
  tots <- .control_totals(~sex, control)

  result <- calibrate_to_estimate(design, ~sex,
                                   estimate = tots$estimate,
                                   vcov_estimate = tots$vcov_estimate)

  history <- result@metadata@weighting_history
  last <- history[[length(history)]]
  expect_identical(last$operation, "sample_calibration_estimate")
})

test_that("test_invariants() passes on calibrate_to_estimate() result", {
  design <- make_replicate_design(n_replicates = 50L, seed = 3L)
  control <- make_replicate_design(n_replicates = 50L, seed = 4L)
  tots <- .control_totals(~sex, control)

  result <- calibrate_to_estimate(design, ~sex,
                                   estimate = tots$estimate,
                                   vcov_estimate = tots$vcov_estimate)

  test_invariants(result)
})

# ---------------------------------------------------------------------------
# 7. calibrate_to_estimate() — numerical correctness
# ---------------------------------------------------------------------------

test_that("calibrate_to_estimate() full-sample weights satisfy calibration constraints within 1e-6", {
  design <- make_replicate_design(n_replicates = 50L, seed = 1L)
  control <- make_replicate_design(n_replicates = 50L, seed = 2L)
  formula <- ~sex
  tots <- .control_totals(formula, control)

  result <- calibrate_to_estimate(design, formula,
                                   estimate = tots$estimate,
                                   vcov_estimate = tots$vcov_estimate)

  w_new <- result@data[[result@variables$weights]]
  # For each level, calibrated total ≈ estimate value.
  # Tolerance 1e-6: svrep's default epsilon=1e-7 convergence achieves this precision.
  for (nm in names(tots$estimate)) {
    # name format: "sexF" or "sexM" — extract level from column name
    lvl_var <- sub("^(sex|age_group|education|region)(.*)", "\\1", nm)
    lvl_val <- sub("^(sex|age_group|education|region)(.*)", "\\2", nm)
    col <- result@data[[lvl_var]]
    indicator <- as.integer(col == lvl_val)
    expect_equal(sum(w_new * indicator), tots$estimate[[nm]], tolerance = 1e-6,
                 label = paste0("total for ", nm))
  }
})

# ---------------------------------------------------------------------------
# 8. calibrate_to_estimate() — error paths
# ---------------------------------------------------------------------------

test_that("calibrate_to_estimate() errors when design is not survey_replicate", {
  df <- make_surveywts_data(seed = 1L)
  control <- make_replicate_design(n_replicates = 50L, seed = 2L)
  tots <- .control_totals(~sex, control)

  expect_error(
    calibrate_to_estimate(df, ~sex,
                           estimate = tots$estimate,
                           vcov_estimate = tots$vcov_estimate),
    class = "surveywts_error_primary_not_replicate"
  )
  expect_snapshot(error = TRUE,
    calibrate_to_estimate(df, ~sex,
                           estimate = tots$estimate,
                           vcov_estimate = tots$vcov_estimate)
  )
})

test_that("calibrate_to_estimate() errors when formula variable missing from design", {
  design <- make_replicate_design(n_replicates = 50L, seed = 1L)
  control <- make_replicate_design(n_replicates = 50L, seed = 2L)
  tots <- .control_totals(~sex, control)

  expect_error(
    calibrate_to_estimate(design, ~no_such_col,
                           estimate = tots$estimate,
                           vcov_estimate = tots$vcov_estimate),
    class = "surveywts_error_formula_variable_not_found"
  )
  expect_snapshot(error = TRUE,
    calibrate_to_estimate(design, ~no_such_col,
                           estimate = tots$estimate,
                           vcov_estimate = tots$vcov_estimate)
  )
})

test_that("calibrate_to_estimate() errors when formula is not a formula object", {
  design <- make_replicate_design(n_replicates = 50L, seed = 1L)
  control <- make_replicate_design(n_replicates = 50L, seed = 2L)
  tots <- .control_totals(~sex, control)

  expect_error(
    calibrate_to_estimate(design, "~sex",
                           estimate = tots$estimate,
                           vcov_estimate = tots$vcov_estimate),
    class = "surveywts_error_formula_invalid"
  )
  expect_snapshot(error = TRUE,
    calibrate_to_estimate(design, "~sex",
                           estimate = tots$estimate,
                           vcov_estimate = tots$vcov_estimate)
  )
})

test_that("calibrate_to_estimate() errors when estimate is not named", {
  design <- make_replicate_design(n_replicates = 50L, seed = 1L)
  control <- make_replicate_design(n_replicates = 50L, seed = 2L)
  tots <- .control_totals(~sex, control)
  bad_estimate <- unname(tots$estimate)

  expect_error(
    calibrate_to_estimate(design, ~sex,
                           estimate = bad_estimate,
                           vcov_estimate = tots$vcov_estimate),
    class = "surveywts_error_estimate_not_named"
  )
  expect_snapshot(error = TRUE,
    calibrate_to_estimate(design, ~sex,
                           estimate = bad_estimate,
                           vcov_estimate = tots$vcov_estimate)
  )
})

test_that("calibrate_to_estimate() errors when estimate has NA values", {
  design <- make_replicate_design(n_replicates = 50L, seed = 1L)
  control <- make_replicate_design(n_replicates = 50L, seed = 2L)
  tots <- .control_totals(~sex, control)
  bad_estimate <- tots$estimate
  bad_estimate[[1L]] <- NA_real_

  expect_error(
    calibrate_to_estimate(design, ~sex,
                           estimate = bad_estimate,
                           vcov_estimate = tots$vcov_estimate),
    class = "surveywts_error_estimate_has_na"
  )
  expect_snapshot(error = TRUE,
    calibrate_to_estimate(design, ~sex,
                           estimate = bad_estimate,
                           vcov_estimate = tots$vcov_estimate)
  )
})

test_that("calibrate_to_estimate() errors when estimate length does not match model matrix", {
  design <- make_replicate_design(n_replicates = 50L, seed = 1L)
  control <- make_replicate_design(n_replicates = 50L, seed = 2L)
  tots <- .control_totals(~sex, control)

  # ~ sex expects 2-element estimate; provide 3
  bad_estimate <- c(a = 100, b = 200, c = 300)

  expect_error(
    calibrate_to_estimate(design, ~sex,
                           estimate = bad_estimate,
                           vcov_estimate = tots$vcov_estimate),
    class = "surveywts_error_estimate_length_mismatch"
  )
  expect_snapshot(error = TRUE,
    calibrate_to_estimate(design, ~sex,
                           estimate = bad_estimate,
                           vcov_estimate = tots$vcov_estimate)
  )
})

test_that("calibrate_to_estimate() errors when estimate names do not match model matrix", {
  design <- make_replicate_design(n_replicates = 50L, seed = 1L)
  control <- make_replicate_design(n_replicates = 50L, seed = 2L)
  tots <- .control_totals(~sex, control)

  # Correct length but wrong names
  bad_estimate <- setNames(tots$estimate, c("wrong1", "wrong2"))

  expect_error(
    calibrate_to_estimate(design, ~sex,
                           estimate = bad_estimate,
                           vcov_estimate = tots$vcov_estimate),
    class = "surveywts_error_estimate_names_mismatch"
  )
  expect_snapshot(error = TRUE,
    calibrate_to_estimate(design, ~sex,
                           estimate = bad_estimate,
                           vcov_estimate = tots$vcov_estimate)
  )
})

test_that("calibrate_to_estimate() errors when vcov_estimate has wrong dimensions", {
  design <- make_replicate_design(n_replicates = 50L, seed = 1L)
  control <- make_replicate_design(n_replicates = 50L, seed = 2L)
  tots <- .control_totals(~sex, control)

  # estimate length = 2; provide 3x3 vcov
  bad_vcov <- diag(3)

  expect_error(
    calibrate_to_estimate(design, ~sex,
                           estimate = tots$estimate,
                           vcov_estimate = bad_vcov),
    class = "surveywts_error_vcov_dimension_mismatch"
  )
  expect_snapshot(error = TRUE,
    calibrate_to_estimate(design, ~sex,
                           estimate = tots$estimate,
                           vcov_estimate = bad_vcov)
  )
})

test_that("calibrate_to_estimate() errors when vcov_estimate has NA values", {
  design <- make_replicate_design(n_replicates = 50L, seed = 1L)
  control <- make_replicate_design(n_replicates = 50L, seed = 2L)
  tots <- .control_totals(~sex, control)
  bad_vcov <- tots$vcov_estimate
  bad_vcov[1L, 1L] <- NA_real_

  expect_error(
    calibrate_to_estimate(design, ~sex,
                           estimate = tots$estimate,
                           vcov_estimate = bad_vcov),
    class = "surveywts_error_vcov_has_na"
  )
  expect_snapshot(error = TRUE,
    calibrate_to_estimate(design, ~sex,
                           estimate = tots$estimate,
                           vcov_estimate = bad_vcov)
  )
})

test_that("calibrate_to_estimate() errors when vcov_estimate is not symmetric", {
  design <- make_replicate_design(n_replicates = 50L, seed = 1L)
  control <- make_replicate_design(n_replicates = 50L, seed = 2L)
  tots <- .control_totals(~sex, control)

  # Build a 2x2 non-symmetric matrix
  bad_vcov <- tots$vcov_estimate
  bad_vcov[1L, 2L] <- bad_vcov[1L, 2L] + 1e-5  # break symmetry

  expect_error(
    calibrate_to_estimate(design, ~sex,
                           estimate = tots$estimate,
                           vcov_estimate = bad_vcov),
    class = "surveywts_error_vcov_not_symmetric"
  )
  expect_snapshot(error = TRUE,
    calibrate_to_estimate(design, ~sex,
                           estimate = tots$estimate,
                           vcov_estimate = bad_vcov)
  )
})

test_that("calibrate_to_estimate() errors when vcov_estimate is not positive definite", {
  design <- make_replicate_design(n_replicates = 50L, seed = 1L)
  control <- make_replicate_design(n_replicates = 50L, seed = 2L)
  tots <- .control_totals(~sex, control)

  # Singular 2x2 matrix: rank-1, not PD
  bad_vcov <- matrix(c(1, 1, 1, 1), 2L, 2L)

  expect_error(
    calibrate_to_estimate(design, ~sex,
                           estimate = tots$estimate,
                           vcov_estimate = bad_vcov),
    class = "surveywts_error_vcov_cholesky_failed"
  )
  expect_snapshot(error = TRUE,
    calibrate_to_estimate(design, ~sex,
                           estimate = tots$estimate,
                           vcov_estimate = bad_vcov)
  )
})

test_that("calibrate_to_estimate() errors when calibration does not converge", {
  design <- make_replicate_design(n_replicates = 50L, seed = 1L)
  control <- make_replicate_design(n_replicates = 50L, seed = 2L)
  tots <- .control_totals(~sex, control)

  expect_error(
    calibrate_to_estimate(
      design, ~sex,
      estimate = tots$estimate,
      vcov_estimate = tots$vcov_estimate,
      control = list(maxit = 1L, epsilon = 1e-100)
    ),
    class = "surveywts_error_calibration_not_converged"
  )
  expect_snapshot(error = TRUE,
    calibrate_to_estimate(
      design, ~sex,
      estimate = tots$estimate,
      vcov_estimate = tots$vcov_estimate,
      control = list(maxit = 1L, epsilon = 1e-100)
    )
  )
})

test_that("calibrate_to_estimate() errors when svrep warns convergence but returns normally", {
  design <- make_replicate_design(n_replicates = 10L, seed = 1L)
  control <- make_replicate_design(n_replicates = 10L, seed = 2L)
  tots <- .control_totals(~sex, control)

  # Mock svrep to emit a "converge" warning and return normally (Path B).
  # Qualifying as surveywts:: ensures the local mock doesn't intercept the
  # test call (both packages export calibrate_to_estimate).
  testthat::local_mocked_bindings(
    calibrate_to_estimate = function(...) {
      warning("did not converge after 1 iterations")
      NULL
    },
    .package = "svrep"
  )

  expect_error(
    surveywts::calibrate_to_estimate(
      design, ~sex,
      estimate = tots$estimate,
      vcov_estimate = tots$vcov_estimate
    ),
    class = "surveywts_error_calibration_not_converged"
  )
  expect_snapshot(
    error = TRUE,
    surveywts::calibrate_to_estimate(
      design, ~sex,
      estimate = tots$estimate,
      vcov_estimate = tots$vcov_estimate
    )
  )
})

# ---------------------------------------------------------------------------
# 9. calibrate_to_estimate() — warning paths
# ---------------------------------------------------------------------------

test_that("calibrate_to_estimate() warns on negative full-sample weights from linear calibration", {
  # Additive ~age_group + sex with conflicting targets: most weight pushed to 18-34
  # AND most weight pushed to F. The 55+/M combination receives conflicting negative
  # adjustments from both additive terms, driving those units below zero.
  # Relaxed control (maxit=500, epsilon=1e-4) keeps replicates from convergence errors.
  df <- make_surveywts_data(n = 200L, seed = 1L)
  df$base_weight <- 1
  taylor <- surveycore::survey_taylor(data = df, variables = list(weights = "base_weight"))
  design <- create_bootstrap_weights(taylor, replicates = 50L)

  tot_sum <- nrow(df)
  estimate <- c(
    "age_group18-34" = tot_sum * 0.75,
    "age_group35-54" = tot_sum * 0.125,
    "age_group55+"   = tot_sum * 0.125,
    sexF             = tot_sum * 0.75,
    sexM             = tot_sum * 0.25
  )
  vcov_est <- diag(1e-8, 5L)

  expect_warning(
    calibrate_to_estimate(design, ~age_group + sex,
                           estimate = estimate,
                           vcov_estimate = vcov_est,
                           method = "linear",
                           control = list(maxit = 500L, epsilon = 1e-4)),
    class = "surveywts_warning_negative_calibrated_weights"
  )
})

# ---------------------------------------------------------------------------
# 10. calibrate_to_estimate() — edge cases
# ---------------------------------------------------------------------------

test_that("calibrate_to_estimate() works with identity covariance (zero uncertainty)", {
  design <- make_replicate_design(n_replicates = 50L, seed = 1L)
  control <- make_replicate_design(n_replicates = 50L, seed = 2L)
  tots <- .control_totals(~sex, control)
  identity_vcov <- diag(1, nrow(tots$vcov_estimate))

  result <- calibrate_to_estimate(design, ~sex,
                                   estimate = tots$estimate,
                                   vcov_estimate = identity_vcov)

  test_invariants(result)
  expect_true(S7::S7_inherits(result, surveycore::survey_replicate))
})

test_that("calibrate_to_estimate() works with a single calibration variable", {
  design <- make_replicate_design(n_replicates = 50L, seed = 1L)
  control <- make_replicate_design(n_replicates = 50L, seed = 2L)
  tots <- .control_totals(~sex, control)

  result <- calibrate_to_estimate(design, ~sex,
                                   estimate = tots$estimate,
                                   vcov_estimate = tots$vcov_estimate)

  test_invariants(result)
  expect_true(S7::S7_inherits(result, surveycore::survey_replicate))
})

test_that("calibrate_to_estimate() works with method = 'linear'", {
  design <- make_replicate_design(n_replicates = 50L, seed = 5L)
  control <- make_replicate_design(n_replicates = 50L, seed = 6L)
  tots <- .control_totals(~sex, control)

  suppressWarnings(
    result <- calibrate_to_estimate(design, ~sex,
                                     estimate = tots$estimate,
                                     vcov_estimate = tots$vcov_estimate,
                                     method = "linear")
  )

  test_invariants(result)
  expect_true(S7::S7_inherits(result, surveycore::survey_replicate))
})

test_that("calibrate_to_estimate() works with method = 'logit' and finite bounds", {
  design <- make_replicate_design(n_replicates = 50L, seed = 1L)
  control <- make_replicate_design(n_replicates = 50L, seed = 2L)
  tots <- .control_totals(~sex, control)

  result <- calibrate_to_estimate(
    design, ~sex,
    estimate = tots$estimate,
    vcov_estimate = tots$vcov_estimate,
    method = "logit",
    bounds = list(lower = 0.1, upper = 10)
  )

  test_invariants(result)
  w_new <- result@data[[result@variables$weights]]
  expect_true(all(w_new >= 0.1))
  expect_true(all(w_new <= 10))
})
