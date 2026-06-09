# tests/testthat/test-calibrate-utils-nr.R
#
# Tests for the NR calibration engine infrastructure added in PR 1:
#   - .validate_bounds()
#   - .validate_unit_scale()
#   - .make_calfun_linear()
#   - .make_calfun_logit()
#   - .make_calfun_raking()
#   - .calibrate_nr_engine()
#   - .build_calibration_provenance() updated signature
#
# These helpers are internal; tested directly because they cannot be reached
# through the public API until PRs 2-4 add calibrate_linear/logit/rake(nr).

# ---------------------------------------------------------------------------
# .validate_bounds()
# ---------------------------------------------------------------------------

test_that(".validate_bounds() accepts NULL when allow_null = TRUE", {
  expect_invisible(.validate_bounds(NULL, "multiplicative", allow_null = TRUE))
})

test_that(".validate_bounds() rejects NULL when allow_null = FALSE", {
  expect_error(
    .validate_bounds(NULL, "multiplicative", allow_null = FALSE),
    class = "surveywts_error_bounds_invalid_calibration"
  )
})

test_that(".validate_bounds() rejects non-numeric bounds", {
  expect_error(
    .validate_bounds(c("0.5", "2"), "multiplicative", allow_null = FALSE),
    class = "surveywts_error_bounds_invalid_calibration"
  )
})

test_that(".validate_bounds() rejects length-1 bounds", {
  expect_error(
    .validate_bounds(0.5, "multiplicative", allow_null = FALSE),
    class = "surveywts_error_bounds_invalid_calibration"
  )
})

test_that(".validate_bounds() rejects length-3 bounds", {
  expect_error(
    .validate_bounds(c(0.5, 1.5, 3), "multiplicative", allow_null = FALSE),
    class = "surveywts_error_bounds_invalid_calibration"
  )
})

test_that(".validate_bounds() rejects NA in bounds", {
  expect_error(
    .validate_bounds(c(NA_real_, 2), "multiplicative", allow_null = FALSE),
    class = "surveywts_error_bounds_invalid_calibration"
  )
  expect_error(
    .validate_bounds(c(0.5, NA_real_), "multiplicative", allow_null = FALSE),
    class = "surveywts_error_bounds_invalid_calibration"
  )
})

test_that(".validate_bounds() rejects non-finite in bounds", {
  expect_error(
    .validate_bounds(c(0.5, Inf), "multiplicative", allow_null = FALSE),
    class = "surveywts_error_bounds_invalid_calibration"
  )
  expect_error(
    .validate_bounds(c(-Inf, 2), "multiplicative", allow_null = FALSE),
    class = "surveywts_error_bounds_invalid_calibration"
  )
})

test_that(".validate_bounds() accepts valid multiplicative bounds c(0.5, 2)", {
  expect_invisible(
    .validate_bounds(c(0.5, 2), "multiplicative", allow_null = FALSE)
  )
})

test_that(".validate_bounds() rejects multiplicative bounds L >= 1", {
  expect_error(
    .validate_bounds(c(1.0, 2.0), "multiplicative", allow_null = FALSE),
    class = "surveywts_error_bounds_invalid_calibration"
  )
  expect_error(
    .validate_bounds(c(1.5, 2.0), "multiplicative", allow_null = FALSE),
    class = "surveywts_error_bounds_invalid_calibration"
  )
})

test_that(".validate_bounds() rejects multiplicative bounds U <= 1", {
  expect_error(
    .validate_bounds(c(0.5, 0.9), "multiplicative", allow_null = FALSE),
    class = "surveywts_error_bounds_invalid_calibration"
  )
  expect_error(
    .validate_bounds(c(0.5, 1.0), "multiplicative", allow_null = FALSE),
    class = "surveywts_error_bounds_invalid_calibration"
  )
})

test_that(".validate_bounds() accepts valid absolute bounds c(100, 2000)", {
  expect_invisible(
    .validate_bounds(c(100, 2000), "absolute", allow_null = FALSE)
  )
})

test_that(".validate_bounds() rejects absolute bounds L <= 0", {
  expect_error(
    .validate_bounds(c(0, 2000), "absolute", allow_null = FALSE),
    class = "surveywts_error_bounds_invalid_calibration"
  )
  expect_error(
    .validate_bounds(c(-1, 2000), "absolute", allow_null = FALSE),
    class = "surveywts_error_bounds_invalid_calibration"
  )
})

test_that(".validate_bounds() rejects absolute bounds L >= U", {
  expect_error(
    .validate_bounds(c(2000, 100), "absolute", allow_null = FALSE),
    class = "surveywts_error_bounds_invalid_calibration"
  )
  expect_error(
    .validate_bounds(c(500, 500), "absolute", allow_null = FALSE),
    class = "surveywts_error_bounds_invalid_calibration"
  )
})

test_that(".validate_bounds() error messages are informative [snapshot]", {
  expect_snapshot(
    error = TRUE,
    .validate_bounds(c(1.0, 2.0), "multiplicative", allow_null = FALSE)
  )
  expect_snapshot(
    error = TRUE,
    .validate_bounds(c(0.0, 2000), "absolute", allow_null = FALSE)
  )
})

# ---------------------------------------------------------------------------
# .validate_unit_scale()
# ---------------------------------------------------------------------------

test_that(".validate_unit_scale() accepts NULL", {
  expect_invisible(.validate_unit_scale(NULL, n = 100L))
})

test_that(".validate_unit_scale() accepts valid positive vector", {
  expect_invisible(.validate_unit_scale(rep(1, 10L), n = 10L))
  expect_invisible(.validate_unit_scale(c(0.5, 1, 2, 0.1), n = 4L))
})

test_that(".validate_unit_scale() rejects non-numeric input", {
  expect_error(
    .validate_unit_scale(rep("1", 5L), n = 5L),
    class = "surveywts_error_unit_scale_invalid"
  )
})

test_that(".validate_unit_scale() rejects wrong length", {
  expect_error(
    .validate_unit_scale(rep(1, 5L), n = 10L),
    class = "surveywts_error_unit_scale_invalid"
  )
})

test_that(".validate_unit_scale() rejects NA values", {
  expect_error(
    .validate_unit_scale(c(1, NA, 1), n = 3L),
    class = "surveywts_error_unit_scale_invalid"
  )
})

test_that(".validate_unit_scale() rejects non-positive values", {
  expect_error(
    .validate_unit_scale(c(1, 0, 1), n = 3L),
    class = "surveywts_error_unit_scale_invalid"
  )
  expect_error(
    .validate_unit_scale(c(1, -0.5, 1), n = 3L),
    class = "surveywts_error_unit_scale_invalid"
  )
})

test_that(".validate_unit_scale() error messages are informative [snapshot]", {
  expect_snapshot(
    error = TRUE,
    .validate_unit_scale(c(1, 0, 1), n = 3L)
  )
})

# ---------------------------------------------------------------------------
# .make_calfun_linear()
# ---------------------------------------------------------------------------

test_that(".make_calfun_linear() returns list with Fm1 and dF", {
  cf <- .make_calfun_linear()
  expect_true(is.list(cf))
  expect_true(is.function(cf$Fm1))
  expect_true(is.function(cf$dF))
})

test_that(".make_calfun_linear() Fm1: F(u) - 1 = u for plain linear", {
  cf <- .make_calfun_linear()
  u <- c(-0.5, 0, 0.5, 1)
  # Fm1(u) = F(u) - 1 = u for linear
  expect_equal(as.vector(cf$Fm1(u)), u, tolerance = 1e-12)
})

test_that(".make_calfun_linear() dF: F'(u) = 1 everywhere for plain linear", {
  cf <- .make_calfun_linear()
  u <- c(-2, -1, 0, 1, 2)
  deriv <- as.vector(cf$dF(u))
  expect_equal(deriv, rep(1, 5L), tolerance = 1e-12)
})

test_that(".make_calfun_linear() Fm1 clamps g-weights to [L, U] when bounds given", {
  # bounds = c(0.3, 3) means g-weight in [0.3, 3], so F(u) in [0.3, 3],
  # and Fm1(u) = F(u) - 1 in [0.3 - 1, 3 - 1] = [-0.7, 2]
  cf <- .make_calfun_linear(L = 0.3, U = 3)
  # u = -0.9 => F(u) = 1 + u = 0.1 < L, clamp to L=0.3 => Fm1 = -0.7
  expect_equal(as.vector(cf$Fm1(-0.9)), -0.7, tolerance = 1e-12)
  # u = 2.5 => F(u) = 3.5 > U, clamp to U=3 => Fm1 = 2
  expect_equal(as.vector(cf$Fm1(2.5)), 2.0, tolerance = 1e-12)
  # u = 0 => F(u) = 1 in [0.3, 3] => Fm1 = 0
  expect_equal(as.vector(cf$Fm1(0)), 0, tolerance = 1e-12)
})

test_that(".make_calfun_linear() dF = 0 outside [L-1, U-1] with bounds", {
  cf <- .make_calfun_linear(L = 0.3, U = 3)
  # u = -0.9 is outside [L-1, U-1] = [-0.7, 2]: dF = 0
  expect_equal(as.vector(cf$dF(-0.9)), 0, tolerance = 1e-12)
  # u = 2.5 is outside [-0.7, 2]: dF = 0
  expect_equal(as.vector(cf$dF(2.5)), 0, tolerance = 1e-12)
  # u = 0 is inside: dF = 1
  expect_equal(as.vector(cf$dF(0)), 1, tolerance = 1e-12)
})

# ---------------------------------------------------------------------------
# .make_calfun_logit()
# ---------------------------------------------------------------------------

test_that(".make_calfun_logit() returns list with Fm1 and dF", {
  cf <- .make_calfun_logit(L = 0.3, U = 3)
  expect_true(is.list(cf))
  expect_true(is.function(cf$Fm1))
  expect_true(is.function(cf$dF))
})

test_that(".make_calfun_logit() Fm1(0) = 0 (F(0) = 1 for any L < 1 < U)", {
  # At u = 0: exp(A*0) = 1
  # F(0) = (L(U-1) + U(1-L)) / (U - 1 + (1-L))
  #       = (LU - L + U - LU) / (U - 1 + 1 - L)
  #       = (U - L) / (U - L) = 1
  # So Fm1(0) = F(0) - 1 = 0
  cf <- .make_calfun_logit(L = 0.3, U = 3)
  expect_equal(as.vector(cf$Fm1(0)), 0, tolerance = 1e-10)
})

test_that(".make_calfun_logit() F approaches L as u -> -Inf", {
  cf <- .make_calfun_logit(L = 0.3, U = 3)
  # large negative u -> exp(Au) -> 0 -> F -> L*(U-1)/(U-1) = L
  result <- as.vector(cf$Fm1(-1000))
  expect_true(result > 0.3 - 1 - 0.01)  # Fm1 ~ L - 1 = -0.7
  expect_true(result < 0.3 - 1 + 0.01)
})

test_that(".make_calfun_logit() F approaches U as u -> +Inf", {
  cf <- .make_calfun_logit(L = 0.3, U = 3)
  # large positive u -> exp(Au) -> Inf -> F -> U*(1-L)/(1-L) = U
  result <- as.vector(cf$Fm1(1000))
  expect_true(result > 3 - 1 - 0.01)  # Fm1 ~ U - 1 = 2
  expect_true(result < 3 - 1 + 0.01)
})

test_that(".make_calfun_logit() dF is positive everywhere", {
  cf <- .make_calfun_logit(L = 0.3, U = 3)
  u_vals <- seq(-5, 5, by = 0.5)
  deriv <- as.vector(cf$dF(u_vals))
  expect_true(all(deriv > 0))
})

test_that(".make_calfun_logit() default wide bounds give F ~ exp(u) near origin", {
  # With L = 1e-6, U = 1e6: A ≈ 1, logit ≈ raking for small u
  cf_logit <- .make_calfun_logit(L = 1e-6, U = 1e6)
  cf_rake <- .make_calfun_raking()
  u_small <- c(-0.1, 0, 0.1, 0.2)
  # For small u, F_logit(u) ≈ exp(u), so Fm1_logit ≈ Fm1_rake
  logit_vals <- as.vector(cf_logit$Fm1(u_small))
  rake_vals <- as.vector(cf_rake$Fm1(u_small))
  expect_equal(logit_vals, rake_vals, tolerance = 1e-4)
})

# ---------------------------------------------------------------------------
# .make_calfun_raking()
# ---------------------------------------------------------------------------

test_that(".make_calfun_raking() returns list with Fm1 and dF", {
  cf <- .make_calfun_raking()
  expect_true(is.list(cf))
  expect_true(is.function(cf$Fm1))
  expect_true(is.function(cf$dF))
})

test_that(".make_calfun_raking() Fm1: F(u) - 1 = exp(u) - 1", {
  cf <- .make_calfun_raking()
  u <- c(-1, 0, 1, 2)
  expected <- exp(u) - 1
  expect_equal(as.vector(cf$Fm1(u)), expected, tolerance = 1e-12)
})

test_that(".make_calfun_raking() dF: F'(u) = exp(u)", {
  cf <- .make_calfun_raking()
  u <- c(-1, 0, 1, 2)
  expected <- exp(u)
  expect_equal(as.vector(cf$dF(u)), expected, tolerance = 1e-12)
})

test_that(".make_calfun_raking() Fm1(0) = 0", {
  cf <- .make_calfun_raking()
  expect_equal(as.vector(cf$Fm1(0)), 0, tolerance = 1e-12)
})

test_that(".make_calfun_raking() produces strictly positive g-weights", {
  # g_k = F(u) = 1 + Fm1(u) = exp(u) > 0 for any finite u
  cf <- .make_calfun_raking()
  u <- c(-10, -1, 0, 1, 10)
  g_weights <- 1 + as.vector(cf$Fm1(u))
  expect_true(all(g_weights > 0))
})

# ---------------------------------------------------------------------------
# .calibrate_nr_engine()
# ---------------------------------------------------------------------------

# Helper: create a simple 1-variable calibration problem for testing
.make_simple_calib <- function(n = 100, seed = 42) {
  set.seed(seed)
  df <- data.frame(
    g = sample(c("A", "B"), n, replace = TRUE),
    w = exp(rnorm(n, 0, 0.3))
  )
  # x_matrix: intercept + dummy for B
  df$gA <- as.integer(df$g == "A")
  df$gB <- as.integer(df$g == "B")
  # Use treatment contrast: intercept + one dummy
  df_factor <- df
  df_factor$g <- factor(df$g, levels = c("A", "B"))
  x_mat <- stats::model.matrix(~g, data = df_factor)
  # Population: 40% A, 60% B (count scale matching sum of weights)
  N <- sum(df$w)
  pop <- c("(Intercept)" = N, "gB" = 0.60 * N)
  list(
    x_matrix = x_mat,
    weights_vec = df$w,
    population = pop,
    df = df
  )
}

test_that(".calibrate_nr_engine() converges for linear calfun in 1 iteration", {
  prob <- .make_simple_calib(seed = 1)
  cf <- .make_calfun_linear()
  result <- .calibrate_nr_engine(
    x_matrix    = prob$x_matrix,
    weights_vec = prob$weights_vec,
    calfun      = cf,
    population  = prob$population,
    epsilon     = 1e-7,
    maxit       = 50L
  )
  expect_equal(result$n_iterations, 1L)
  expect_true(result$converged)
  expect_true(is.numeric(result$weights))
  expect_equal(length(result$weights), length(prob$weights_vec))
  # Verify calibration constraint: weighted sum of x should match population
  calibrated_totals <- drop(t(prob$x_matrix) %*% result$weights)
  expect_equal(
    calibrated_totals,
    prob$population,
    tolerance = 1e-6
  )
})

test_that(".calibrate_nr_engine() returns lambda vector", {
  prob <- .make_simple_calib(seed = 2)
  cf <- .make_calfun_linear()
  result <- .calibrate_nr_engine(
    x_matrix    = prob$x_matrix,
    weights_vec = prob$weights_vec,
    calfun      = cf,
    population  = prob$population,
    epsilon     = 1e-7,
    maxit       = 50L
  )
  expect_true(is.numeric(result$lambda))
  expect_equal(length(result$lambda), ncol(prob$x_matrix))
})

test_that(".calibrate_nr_engine() converges for raking calfun", {
  prob <- .make_simple_calib(seed = 3)
  cf <- .make_calfun_raking()
  result <- .calibrate_nr_engine(
    x_matrix    = prob$x_matrix,
    weights_vec = prob$weights_vec,
    calfun      = cf,
    population  = prob$population,
    epsilon     = 1e-7,
    maxit       = 50L
  )
  expect_true(result$converged)
  # All weights must be strictly positive for raking
  expect_true(all(result$weights > 0))
  calibrated_totals <- drop(t(prob$x_matrix) %*% result$weights)
  expect_equal(calibrated_totals, prob$population, tolerance = 1e-6)
})

test_that(".calibrate_nr_engine() converges for logit calfun", {
  prob <- .make_simple_calib(seed = 4)
  cf <- .make_calfun_logit(L = 0.3, U = 3)
  result <- .calibrate_nr_engine(
    x_matrix    = prob$x_matrix,
    weights_vec = prob$weights_vec,
    calfun      = cf,
    population  = prob$population,
    epsilon     = 1e-7,
    maxit       = 50L
  )
  expect_true(result$converged)
  expect_true(all(result$weights > 0))
  # g-weights should be in (L, U) = (0.3, 3)
  g_weights <- result$weights / prob$weights_vec
  expect_true(all(g_weights > 0.3))
  expect_true(all(g_weights < 3))
})

test_that(".calibrate_nr_engine() throws surveywts_error_calibration_not_converged on maxit = 1 for raking", {
  # Raking with maxit=1 and tight epsilon should fail to converge
  # (unless data is trivially calibrated, which it won't be with mismatched targets)
  set.seed(10)
  n <- 200
  df <- data.frame(g = sample(c("A", "B"), n, replace = TRUE))
  df$g <- factor(df$g, levels = c("A", "B"))
  x_mat <- stats::model.matrix(~g, data = df)
  w <- rep(1, n)
  # Force imbalance: sample is 50/50 but targets want 20/80
  N <- sum(w)
  pop <- c("(Intercept)" = N, "gB" = 0.80 * N)
  cf <- .make_calfun_raking()
  expect_error(
    .calibrate_nr_engine(
      x_matrix    = x_mat,
      weights_vec = w,
      calfun      = cf,
      population  = pop,
      epsilon     = 1e-20,  # impossibly tight
      maxit       = 1L
    ),
    class = "surveywts_error_calibration_not_converged"
  )
})

test_that(".calibrate_nr_engine() throws singular system error for rank-deficient x_matrix", {
  # Create a rank-deficient x_matrix: two identical columns
  n <- 50
  x_mat <- matrix(
    c(rep(1, n), rep(1, n), rep(1, n)),
    nrow = n, ncol = 3,
    dimnames = list(NULL, c("(Intercept)", "col2", "col3"))
  )
  w <- rep(1, n)
  pop <- c("(Intercept)" = n, "col2" = n, "col3" = n)
  cf <- .make_calfun_linear()
  expect_error(
    .calibrate_nr_engine(
      x_matrix    = x_mat,
      weights_vec = w,
      calfun      = cf,
      population  = pop,
      epsilon     = 1e-7,
      maxit       = 50L
    ),
    class = "surveywts_error_calibration_singular_system"
  )
})

test_that(".calibrate_nr_engine() linear result matches manual GREG formula", {
  # For linear: lambda = T_x^{-1} * discrepancy
  # where T_x = X'WX and discrepancy = pop - X'w
  prob <- .make_simple_calib(seed = 5)
  cf <- .make_calfun_linear()
  result <- .calibrate_nr_engine(
    x_matrix    = prob$x_matrix,
    weights_vec = prob$weights_vec,
    calfun      = cf,
    population  = prob$population,
    epsilon     = 1e-7,
    maxit       = 50L
  )

  # Manual GREG
  X <- prob$x_matrix
  w <- prob$weights_vec
  pop <- prob$population
  T_x <- t(X) %*% (w * X)
  discrepancy <- pop - drop(t(X) %*% w)
  lambda_manual <- drop(solve(T_x, discrepancy))
  g_manual <- drop(1 + X %*% lambda_manual)
  w_manual <- w * g_manual

  expect_equal(result$weights, w_manual, tolerance = 1e-10)
})

# ---------------------------------------------------------------------------
# .build_calibration_provenance() — updated signature with bounds_scale + lambda
# ---------------------------------------------------------------------------

test_that(".build_calibration_provenance() accepts explicit lambda argument", {
  n <- 20L
  p <- 3L
  set.seed(7)
  x_mat <- cbind(1, matrix(rnorm(n * (p - 1L)), nrow = n))
  colnames(x_mat) <- c("(Intercept)", "v1", "v2")
  w <- rep(1, n)
  cal_w <- w * 1.1  # dummy calibrated weights

  engine_result <- list(
    weights = cal_w,
    convergence = list(converged = TRUE, iterations = 1L)
  )
  pop_totals <- c("(Intercept)" = n, "v1" = 0.5, "v2" = 0.3)
  lambda_explicit <- c(0.1, 0.2, 0.3)

  result <- .build_calibration_provenance(
    engine_result     = engine_result,
    x_matrix          = x_mat,
    base_weights      = w,
    q_weights         = rep(1, n),
    population_totals = pop_totals,
    method            = "linear",
    lambda            = lambda_explicit,
    cell_factors      = NULL,
    bounds_scale      = "multiplicative"
  )

  expect_identical(result$lambda, lambda_explicit)
  expect_identical(result$bounds_scale, "multiplicative")
  expect_true(is.list(result))
})

test_that(".build_calibration_provenance() stores bounds_scale = NULL for logit with bounds_scale unset", {
  n <- 10L
  set.seed(8)
  x_mat <- cbind(1, rnorm(n))
  colnames(x_mat) <- c("(Intercept)", "v1")
  w <- rep(1, n)
  cal_w <- w * 1.05

  engine_result <- list(
    weights = cal_w,
    convergence = list(converged = TRUE, iterations = 3L)
  )
  pop_totals <- c("(Intercept)" = n, "v1" = 2.0)

  result <- .build_calibration_provenance(
    engine_result     = engine_result,
    x_matrix          = x_mat,
    base_weights      = w,
    q_weights         = rep(1, n),
    population_totals = pop_totals,
    method            = "logit",
    lambda            = c(0.05, 0.02),
    cell_factors      = NULL,
    bounds_scale      = NULL
  )

  expect_null(result$bounds_scale)
  expect_equal(result$n_iterations, 3L)
})

test_that(".build_calibration_provenance() computes g_weights correctly", {
  n <- 5L
  x_mat <- matrix(c(1, 1, 1, 1, 1), nrow = n, ncol = 1L,
                  dimnames = list(NULL, "(Intercept)"))
  w <- c(1, 2, 3, 2, 1)
  cal_w <- w * 1.2  # g = 1.2 for all

  engine_result <- list(
    weights = cal_w,
    convergence = list(converged = TRUE, iterations = 1L)
  )
  pop_totals <- c("(Intercept)" = sum(w) * 1.2)

  result <- .build_calibration_provenance(
    engine_result     = engine_result,
    x_matrix          = x_mat,
    base_weights      = w,
    q_weights         = rep(1, n),
    population_totals = pop_totals,
    method            = "linear",
    lambda            = 0.2,
    cell_factors      = NULL,
    bounds_scale      = NULL
  )

  expect_equal(result$g_weights, rep(1.2, n), tolerance = 1e-12)
})

# ---------------------------------------------------------------------------
# Existing calibrate_rake() tests pass after .calibrate_engine() migration
# (Smoke test: calibrate_rake() still works with the "anesrake" algorithm)
# ---------------------------------------------------------------------------

test_that("calibrate_rake() with algorithm = 'anesrake' still works after PR 1", {
  df <- make_surveywts_data(n = 100L, seed = 99L)
  targets <- list(
    age_group = c("18-34" = 0.33, "35-54" = 0.34, "55+" = 0.33),
    sex       = c("M" = 0.50, "F" = 0.50)
  )
  result <- calibrate_rake(
    df,
    targets  = targets,
    weights  = base_weight,
    wt_name  = "wts",
    type     = "prop",
    algorithm = "anesrake"
  )
  test_invariants(result)
  expect_true(inherits(result, "weighted_df"))
  # Check calibration constraint: weighted proportions match targets
  total_w <- sum(result$wts)
  age_props_arr <- tapply(result$wts, df$age_group, sum) / total_w
  age_props <- as.numeric(age_props_arr[c("18-34", "35-54", "55+")])
  expect_equal(
    age_props,
    c(0.33, 0.34, 0.33),
    tolerance = 0.01
  )
})
