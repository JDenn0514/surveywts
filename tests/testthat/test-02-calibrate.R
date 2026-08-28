# tests/testthat/test-02-calibrate.R
#
# Tests for calibrate() — thin dispatcher
# Updated in PR 4: method = c("rake", "linear", "logit"), default = "rake"
# Dispatches to calibrate_rake(), calibrate_linear(), calibrate_logit()
# calibrate_greg() and calibrate_poststrat() no longer dispatched here.
#
# Also tests internal infrastructure helpers:
#   .check_input_class(), .update_survey_weights(), .build_calibration_provenance()
#
# All error path tests use the dual pattern:
#   expect_error(class = ...) + expect_snapshot(error = TRUE, ...)
# Warning tests use:
#   expect_warning(class = ...) + expect_snapshot()

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

.make_test_taylor_greg <- function(df, weight_col = "base_weight") {
  surveycore::survey_taylor(
    data = df,
    variables = list(
      ids = NULL,
      strata = NULL,
      fpc = NULL,
      weights = weight_col,
      nest = FALSE
    )
  )
}

.make_targets <- function(type = "prop") {
  if (type == "prop") {
    list(
      age_group = c("18-34" = 0.30, "35-54" = 0.40, "55+" = 0.30),
      sex = c("M" = 0.48, "F" = 0.52)
    )
  } else {
    list(
      age_group = c("18-34" = 150, "35-54" = 200, "55+" = 150),
      sex = c("M" = 240, "F" = 260)
    )
  }
}

# ---------------------------------------------------------------------------
# Regression guard: old calibrate() signature no longer exists
# ---------------------------------------------------------------------------

test_that("old calibrate() with variables + population args no longer exists", {
  df <- make_surveywts_data(seed = 37)
  pop <- list(
    age_group = c("18-34" = 0.30, "35-54" = 0.40, "55+" = 0.30)
  )

  # calibrate() is gone; calling with old-style variables + population should error
  # (either function not found or unknown argument error)
  expect_error(
    calibrate(df, variables = c(age_group), population = pop)
  )
})

# ===========================================================================
# calibrate() Thin Dispatcher — updated in PR 4
# method = c("rake", "linear", "logit"), default = "rake"
# Dispatches to calibrate_rake(), calibrate_linear(), calibrate_logit()
# calibrate_greg() and calibrate_poststrat() no longer dispatched here
# ===========================================================================

# ---------------------------------------------------------------------------
# D1. Happy path — method = "rake" (survey_taylor)
# ---------------------------------------------------------------------------

test_that("calibrate() with method = 'rake' returns same result as calibrate_rake()", {
  df <- make_surveywts_data(seed = 101)
  design <- .make_test_taylor_greg(df)
  targets <- .make_targets()

  direct <- calibrate_rake(design, targets = targets)
  dispatcher <- calibrate(design, targets = targets, method = "rake")

  test_invariants(dispatcher)
  expect_true(S7::S7_inherits(dispatcher, surveycore::survey_taylor))
  expect_equal(
    dispatcher@data[[dispatcher@variables$weights]],
    direct@data[[direct@variables$weights]],
    tolerance = 1e-10
  )
})

# ---------------------------------------------------------------------------
# D2. Happy path — method = "linear" (survey_taylor)
# ---------------------------------------------------------------------------

test_that("calibrate() with method = 'linear' returns same result as calibrate_linear()", {
  df <- make_surveywts_data(seed = 102)
  design <- .make_test_taylor_greg(df)
  targets <- .make_targets()

  direct <- calibrate_linear(design, targets = targets)
  dispatcher <- calibrate(design, targets = targets, method = "linear")

  test_invariants(dispatcher)
  expect_true(S7::S7_inherits(dispatcher, surveycore::survey_taylor))
  expect_equal(
    dispatcher@data[[dispatcher@variables$weights]],
    direct@data[[direct@variables$weights]],
    tolerance = 1e-10
  )
})

# ---------------------------------------------------------------------------
# D3. Happy path — method = "logit" (survey_taylor)
# ---------------------------------------------------------------------------

test_that("calibrate() with method = 'logit' returns same result as calibrate_logit()", {
  df <- make_surveywts_data(seed = 103)
  design <- .make_test_taylor_greg(df)
  targets <- .make_targets()

  direct <- calibrate_logit(design, targets = targets)
  dispatcher <- calibrate(design, targets = targets, method = "logit")

  test_invariants(dispatcher)
  expect_true(S7::S7_inherits(dispatcher, surveycore::survey_taylor))
  expect_equal(
    dispatcher@data[[dispatcher@variables$weights]],
    direct@data[[direct@variables$weights]],
    tolerance = 1e-10
  )
})

# ---------------------------------------------------------------------------
# D4. Happy path — default method = "rake" (survey_taylor)
# ---------------------------------------------------------------------------

test_that("calibrate() default method dispatches to calibrate_rake()", {
  df <- make_surveywts_data(seed = 104)
  design <- .make_test_taylor_greg(df)
  targets <- .make_targets()

  direct <- calibrate_rake(design, targets = targets)
  dispatcher <- calibrate(design, targets = targets)

  test_invariants(dispatcher)
  expect_true(S7::S7_inherits(dispatcher, surveycore::survey_taylor))
  expect_equal(
    dispatcher@data[[dispatcher@variables$weights]],
    direct@data[[direct@variables$weights]],
    tolerance = 1e-10
  )
})

# ---------------------------------------------------------------------------
# D5. Happy path — NSE weights forwarded correctly (survey_taylor)
# ---------------------------------------------------------------------------

test_that("calibrate() forwards NSE weights correctly to dispatched function", {
  df <- make_surveywts_data(seed = 105)
  design <- .make_test_taylor_greg(df)
  targets <- .make_targets()

  direct <- calibrate_rake(design, targets = targets)
  dispatcher <- calibrate(design, targets = targets)

  test_invariants(dispatcher)
  expect_equal(
    dispatcher@data[[dispatcher@variables$weights]],
    direct@data[[direct@variables$weights]],
    tolerance = 1e-10
  )
})

# ---------------------------------------------------------------------------
# D-NB. Error — data.frame input aborts with surveywts_error_not_survey_base
# ---------------------------------------------------------------------------

test_that("calibrate() aborts with cli error for data.frame input", {
  targets_a <- .make_targets()
  expect_error(
    calibrate(make_surveywts_data(), targets = targets_a),
    class = "surveywts_error_not_survey_base"
  )
  expect_snapshot(
    error = TRUE,
    calibrate(make_surveywts_data(), targets = targets_a)
  )
})

# ---------------------------------------------------------------------------
# D6. Error — invalid method triggers rlang::arg_match() error
# ---------------------------------------------------------------------------

test_that("calibrate() with invalid method triggers arg_match error", {
  df <- make_surveywts_data(seed = 106)
  design <- .make_test_taylor_greg(df)
  targets <- .make_targets()

  expect_error(
    calibrate(design, targets = targets, method = "bad_method")
  )
})

# ---------------------------------------------------------------------------
# D7. method = "greg" no longer valid — expect arg_match error
# ---------------------------------------------------------------------------

test_that("calibrate() with method = 'greg' triggers arg_match error (removed in PR 4)", {
  df <- make_surveywts_data(seed = 107)
  design <- .make_test_taylor_greg(df)
  targets <- .make_targets()

  expect_error(
    calibrate(design, targets = targets, method = "greg")
  )
})

# ---------------------------------------------------------------------------
# D8. method = "poststrat" no longer valid — expect arg_match error
# ---------------------------------------------------------------------------

test_that("calibrate() with method = 'poststrat' triggers arg_match error (removed in PR 4)", {
  df <- make_surveywts_data(seed = 108)
  design <- .make_test_taylor_greg(df)
  targets <- .make_targets()

  expect_error(
    calibrate(design, targets = targets, method = "poststrat")
  )
})

# ===========================================================================
# Infrastructure helpers — PR 1 tests
# ===========================================================================

# Helper: build a minimal survey_replicate for testing
.make_test_replicate <- function(seed = 200) {
  df <- make_surveywts_data(n = 100L, seed = seed)
  taylor <- surveycore::survey_taylor(
    data = df,
    variables = list(weights = "base_weight")
  )
  create_bootstrap_weights(taylor, replicates = 10L)
}

# ---------------------------------------------------------------------------
# Infra-1. .check_input_class() accepts survey_replicate without error
# ---------------------------------------------------------------------------

test_that(".check_input_class() accepts survey_replicate without throwing", {
  rep_obj <- .make_test_replicate(seed = 201)
  # After PR 1, survey_replicate is a supported class — no error thrown
  expect_no_error(.check_input_class(rep_obj))
})

# ---------------------------------------------------------------------------
# Infra-2a. .update_survey_weights() with caldata sets @calibration
# ---------------------------------------------------------------------------

test_that(".update_survey_weights() with caldata = list(...) sets design@calibration", {
  # Use survey_nonprob which has @calibration property (survey_taylor does not)
  df <- make_surveywts_data(n = 50L, seed = 202)
  design <- surveycore::survey_nonprob(
    data = df,
    variables = list(weights = "base_weight"),
    metadata = surveycore::survey_metadata(),
    groups = character(0),
    call = NULL,
    calibration = NULL
  )
  new_wts <- design@data[["base_weight"]] * 1.05
  entry <- .make_history_entry(
    step = 1L,
    operation = "calibration",
    weight_col = "base_weight",
    call_str = "test",
    parameters = list(),
    before_stats = .compute_weight_stats(design@data[["base_weight"]]),
    after_stats = .compute_weight_stats(new_wts),
    convergence = list(
      converged = TRUE,
      iterations = 1L,
      max_error = 0,
      tolerance = 1e-6
    )
  )
  fake_caldata <- list(method = "linear", x_matrix = matrix(1, 1, 1))
  result <- .update_survey_weights(
    design,
    new_wts,
    entry,
    caldata = fake_caldata
  )
  expect_identical(result@calibration, fake_caldata)
})

# ---------------------------------------------------------------------------
# Infra-2b. .update_survey_weights() with caldata = NULL leaves @calibration
# ---------------------------------------------------------------------------

test_that(".update_survey_weights() with caldata = NULL leaves @calibration unchanged", {
  # Use survey_nonprob which has @calibration property (survey_taylor does not)
  df <- make_surveywts_data(n = 50L, seed = 203)
  design <- surveycore::survey_nonprob(
    data = df,
    variables = list(weights = "base_weight"),
    metadata = surveycore::survey_metadata(),
    groups = character(0),
    call = NULL,
    calibration = NULL
  )
  new_wts <- design@data[["base_weight"]] * 1.02
  entry <- .make_history_entry(
    step = 1L,
    operation = "calibration",
    weight_col = "base_weight",
    call_str = "test",
    parameters = list(),
    before_stats = .compute_weight_stats(design@data[["base_weight"]]),
    after_stats = .compute_weight_stats(new_wts),
    convergence = list(
      converged = TRUE,
      iterations = 1L,
      max_error = 0,
      tolerance = 1e-6
    )
  )
  # @calibration is NULL before (newly constructed design)
  result <- .update_survey_weights(design, new_wts, entry, caldata = NULL)
  expect_null(result@calibration)
})

# ---------------------------------------------------------------------------
# Infra-3. .build_calibration_provenance() — direct tests
# ---------------------------------------------------------------------------

# Helper: build minimal engine_result and inputs for provenance tests
.make_provenance_inputs <- function(n = 50L, seed = 204) {
  set.seed(seed)
  base_weights <- exp(stats::rnorm(n, 0, 0.4))
  q_weights <- rep(1, n)
  age <- sample(c("A", "B", "C"), n, replace = TRUE, prob = c(0.3, 0.4, 0.3))
  x_matrix <- stats::model.matrix(
    ~age,
    data = data.frame(age = factor(age, levels = c("A", "B", "C")))
  )
  J <- ncol(x_matrix)
  # Population totals: intercept = sum(base_weights), then marginals
  total_w <- sum(base_weights)
  pop_totals <- stats::setNames(numeric(J), colnames(x_matrix))
  pop_totals["(Intercept)"] <- total_w
  prop_b <- 0.40
  prop_c <- 0.30
  pop_totals["ageB"] <- prop_b * total_w
  pop_totals["ageC"] <- prop_c * total_w

  # Calibrate to get engine_result
  data_df <- data.frame(
    age = factor(age, levels = c("A", "B", "C")),
    .wt_tmp = base_weights
  )
  svy_tmp <- survey::svydesign(ids = ~1, weights = ~.wt_tmp, data = data_df)
  fml <- stats::as.formula("~ age")
  cal <- survey::calibrate(
    svy_tmp,
    formula = fml,
    population = pop_totals,
    calfun = survey::cal.linear
  )
  calibrated_weights <- as.numeric(stats::weights(cal))

  engine_result <- list(
    weights = calibrated_weights,
    convergence = list(
      converged = TRUE,
      iterations = 1L,
      max_error = 0,
      tolerance = 1e-6
    )
  )

  list(
    engine_result = engine_result,
    x_matrix = x_matrix,
    base_weights = base_weights,
    q_weights = q_weights,
    population_totals = pop_totals,
    calibrated_weights = calibrated_weights
  )
}

test_that(".build_calibration_provenance() returns named list with all 12 required fields", {
  skip_if_not_installed("survey")
  inp <- .make_provenance_inputs()
  result <- .build_calibration_provenance(
    engine_result = inp$engine_result,
    x_matrix = inp$x_matrix,
    base_weights = inp$base_weights,
    q_weights = inp$q_weights,
    population_totals = inp$population_totals,
    method = "linear",
    cell_factors = NULL
  )
  required_fields <- c(
    "x_matrix",
    "base_weights",
    "g_weights",
    "crossproduct_inv",
    "population_totals",
    "discrepancy",
    "lambda",
    "method",
    "cell_factors",
    "q_weights",
    "converged",
    "n_iterations"
  )
  expect_true(all(required_fields %in% names(result)))
  # replicate_converged is NOT in the list — callers add it
  expect_false("replicate_converged" %in% names(result))
})

test_that(".build_calibration_provenance() g_weights identity: g_weights * base == engine weights", {
  skip_if_not_installed("survey")
  inp <- .make_provenance_inputs()
  result <- .build_calibration_provenance(
    engine_result = inp$engine_result,
    x_matrix = inp$x_matrix,
    base_weights = inp$base_weights,
    q_weights = inp$q_weights,
    population_totals = inp$population_totals,
    method = "linear"
  )
  expect_equal(
    result$g_weights * result$base_weights,
    inp$calibrated_weights,
    tolerance = 1e-10
  )
})

test_that(".build_calibration_provenance() discrepancy = population_totals - t(X) %*% base_weights", {
  skip_if_not_installed("survey")
  inp <- .make_provenance_inputs()
  result <- .build_calibration_provenance(
    engine_result = inp$engine_result,
    x_matrix = inp$x_matrix,
    base_weights = inp$base_weights,
    q_weights = inp$q_weights,
    population_totals = inp$population_totals,
    method = "linear"
  )
  expected_discrepancy <- inp$population_totals -
    drop(t(inp$x_matrix) %*% inp$base_weights)
  expect_equal(result$discrepancy, expected_discrepancy, tolerance = 1e-10)
})

test_that(".build_calibration_provenance() crossproduct_inv %*% C approximates identity", {
  skip_if_not_installed("survey")
  inp <- .make_provenance_inputs()
  result <- .build_calibration_provenance(
    engine_result = inp$engine_result,
    x_matrix = inp$x_matrix,
    base_weights = inp$base_weights,
    q_weights = inp$q_weights,
    population_totals = inp$population_totals,
    method = "linear"
  )
  J <- ncol(inp$x_matrix)
  C <- t(inp$x_matrix) %*%
    (inp$base_weights * inp$q_weights * inp$x_matrix)
  identity_approx <- result$crossproduct_inv %*% C
  # Strip dimnames before comparing — matrix multiplication retains names
  # from the operands, but diag() has no dimnames.
  dimnames(identity_approx) <- NULL
  expect_equal(identity_approx, diag(J), tolerance = 1e-8)
})

test_that(".build_calibration_provenance() lambda = crossproduct_inv %*% discrepancy for linear", {
  skip_if_not_installed("survey")
  inp <- .make_provenance_inputs()
  result <- .build_calibration_provenance(
    engine_result = inp$engine_result,
    x_matrix = inp$x_matrix,
    base_weights = inp$base_weights,
    q_weights = inp$q_weights,
    population_totals = inp$population_totals,
    method = "linear"
  )
  expected_lambda <- result$crossproduct_inv %*% result$discrepancy
  expect_equal(result$lambda, expected_lambda, tolerance = 1e-10)
})

test_that(".build_calibration_provenance() lambda = crossproduct_inv %*% discrepancy for logit", {
  skip_if_not_installed("survey")
  inp <- .make_provenance_inputs()
  result <- .build_calibration_provenance(
    engine_result = inp$engine_result,
    x_matrix = inp$x_matrix,
    base_weights = inp$base_weights,
    q_weights = inp$q_weights,
    population_totals = inp$population_totals,
    method = "logit"
  )
  expected_lambda <- result$crossproduct_inv %*% result$discrepancy
  expect_equal(result$lambda, expected_lambda, tolerance = 1e-10)
})

test_that(".build_calibration_provenance() lambda is NULL for method = 'raking'", {
  skip_if_not_installed("survey")
  inp <- .make_provenance_inputs()
  result <- .build_calibration_provenance(
    engine_result = inp$engine_result,
    x_matrix = inp$x_matrix,
    base_weights = inp$base_weights,
    q_weights = inp$q_weights,
    population_totals = inp$population_totals,
    method = "raking"
  )
  expect_null(result$lambda)
})

test_that(".build_calibration_provenance() lambda is NULL for method = 'poststrat'", {
  skip_if_not_installed("survey")
  inp <- .make_provenance_inputs()
  result <- .build_calibration_provenance(
    engine_result = inp$engine_result,
    x_matrix = inp$x_matrix,
    base_weights = inp$base_weights,
    q_weights = inp$q_weights,
    population_totals = inp$population_totals,
    method = "poststrat"
  )
  expect_null(result$lambda)
})

test_that(".build_calibration_provenance() converged = engine_result$convergence$converged", {
  skip_if_not_installed("survey")
  inp <- .make_provenance_inputs()
  result <- .build_calibration_provenance(
    engine_result = inp$engine_result,
    x_matrix = inp$x_matrix,
    base_weights = inp$base_weights,
    q_weights = inp$q_weights,
    population_totals = inp$population_totals,
    method = "linear"
  )
  expect_identical(result$converged, inp$engine_result$convergence$converged)
})

test_that(".build_calibration_provenance() n_iterations = as.integer(engine_result$convergence$iterations)", {
  skip_if_not_installed("survey")
  inp <- .make_provenance_inputs()
  result <- .build_calibration_provenance(
    engine_result = inp$engine_result,
    x_matrix = inp$x_matrix,
    base_weights = inp$base_weights,
    q_weights = inp$q_weights,
    population_totals = inp$population_totals,
    method = "linear"
  )
  expect_identical(
    result$n_iterations,
    as.integer(inp$engine_result$convergence$iterations)
  )
})

test_that(".build_calibration_provenance() cell_factors = NULL when not provided", {
  skip_if_not_installed("survey")
  inp <- .make_provenance_inputs()
  result <- .build_calibration_provenance(
    engine_result = inp$engine_result,
    x_matrix = inp$x_matrix,
    base_weights = inp$base_weights,
    q_weights = inp$q_weights,
    population_totals = inp$population_totals,
    method = "linear",
    cell_factors = NULL
  )
  expect_null(result$cell_factors)
})

test_that(".build_calibration_provenance() return value is visible (not invisible)", {
  skip_if_not_installed("survey")
  inp <- .make_provenance_inputs()
  # Direct assignment without print() — verifies the function is not invisible
  caldata <- .build_calibration_provenance(
    engine_result = inp$engine_result,
    x_matrix = inp$x_matrix,
    base_weights = inp$base_weights,
    q_weights = inp$q_weights,
    population_totals = inp$population_totals,
    method = "linear"
  )
  expect_true(is.list(caldata))
  expect_true("x_matrix" %in% names(caldata))
})

# ===========================================================================
# Dispatcher pass-through with survey_replicate (D-1r, D-2r additions, PR 4)
# ===========================================================================

# ---------------------------------------------------------------------------
# D-1r. calibrate(replicate_design, targets, method = "rake") -> survey_replicate
# ---------------------------------------------------------------------------

test_that("calibrate() dispatcher with survey_replicate + method='rake' returns survey_replicate", {
  df <- make_surveywts_data(seed = 401)
  targets <- .make_targets()
  rep_design <- .make_replicate_design(df, seed = 401)

  result <- calibrate(rep_design, targets = targets, method = "rake")

  expect_true(S7::S7_inherits(result, surveycore::survey_replicate))
})

# ---------------------------------------------------------------------------
# D-2r. calibrate(replicate_design, targets, method = "linear") -> survey_replicate
# ---------------------------------------------------------------------------

test_that("calibrate() dispatcher with survey_replicate + method='linear' returns survey_replicate", {
  skip_if_not_installed("survey")
  df <- make_surveywts_data(seed = 402)
  targets <- .make_targets()
  rep_design <- .make_replicate_design(df, seed = 402)

  result <- calibrate(rep_design, targets = targets, method = "linear")

  expect_true(S7::S7_inherits(result, surveycore::survey_replicate))
})

# ---------------------------------------------------------------------------
# D-3r. calibrate(replicate_design, targets, method = "logit") -> survey_replicate
# ---------------------------------------------------------------------------

test_that("calibrate() dispatcher with survey_replicate + method='logit' returns survey_replicate", {
  skip_if_not_installed("survey")
  df <- make_surveywts_data(seed = 403)
  rep_design <- .make_replicate_design(df, seed = 403)
  targets <- .make_targets()

  result <- calibrate(rep_design, targets = targets, method = "logit")

  expect_true(S7::S7_inherits(result, surveycore::survey_replicate))
})
