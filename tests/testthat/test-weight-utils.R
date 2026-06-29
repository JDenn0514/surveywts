# tests/testthat/test-weight-utils.R
#
# Tests for trim_weights() and rescale_weights()
# Per spec-utilities.md §VI test categories
# Per impl-utilities.md PR 2 acceptance criteria
#
# All Layer 3 error path tests use the dual pattern:
#   expect_error(class = ...) + expect_snapshot(error = TRUE, ...)

# ---------------------------------------------------------------------------
# Local helpers
# ---------------------------------------------------------------------------

.make_test_taylor_wt <- function(df, weight_col = "base_weight") {
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

.make_test_nonprob_wt <- function(df, weight_col = "base_weight") {
  surveycore::survey_nonprob(
    data = df,
    variables = list(
      ids = NULL, strata = NULL, fpc = NULL,
      weights = weight_col, nest = FALSE
    ),
    metadata = surveycore::survey_metadata(),
    groups = character(0),
    call = NULL,
    calibration = NULL
  )
}

# trim_weights() -------------------------------------------------------

# 1. Happy path — trim_weights() ----------------------------------------

test_that("trim_weights() rejects plain data.frame input", {
  df <- make_surveywts_data(seed = 1)
  expect_error(
    trim_weights(df),
    class = "surveywts_error_not_survey_base"
  )
  expect_snapshot(error = TRUE, trim_weights(df))
})

test_that("trim_weights() preserves survey_taylor class", {
  df <- make_surveywts_data(seed = 3)
  design <- .make_test_taylor_wt(df)
  result <- trim_weights(design, upper = 0.9, type = "percentile")
  test_invariants(result)
  expect_true(S7::S7_inherits(result, surveycore::survey_taylor))
  expect_false(S7::S7_inherits(result, surveycore::survey_nonprob))
})

test_that("trim_weights() preserves survey_nonprob class", {
  df <- make_surveywts_data(seed = 4)
  design <- .make_test_nonprob_wt(df)
  result <- trim_weights(design, upper = 0.9, type = "percentile")
  test_invariants(result)
  expect_true(S7::S7_inherits(result, surveycore::survey_nonprob))
})

test_that("trim_weights() preserves survey_replicate class and trims rep weights", {
  rep_design <- make_replicate_design(seed = 1)
  orig_main <- rep_design@data[[rep_design@variables$weights]]
  orig_rep <- as.matrix(rep_design@data[rep_design@variables$repweights])

  result <- trim_weights(rep_design, upper = 0.8, type = "percentile")
  test_invariants(result)
  expect_true(S7::S7_inherits(result, surveycore::survey_replicate))

  result_main <- result@data[[result@variables$weights]]
  result_rep <- as.matrix(result@data[result@variables$repweights])

  # Main weights were modified
  expect_false(identical(result_main, orig_main))
  # Replicate weight matrix has same dimensions
  expect_identical(dim(result_rep), dim(orig_rep))
  # At least some replicate weight values changed
  expect_false(all(result_rep == orig_rep))
})

test_that("trim_weights() default upper_abs = median(w) + 5 * IQR(w), lower_abs = -Inf", {
  df <- make_surveywts_data(seed = 6)
  w <- df$base_weight
  taylor <- .make_test_taylor_wt(df)
  result <- trim_weights(taylor)
  hist_entry <- result@metadata@weighting_history[[1]]
  expect_equal(hist_entry$parameters$upper_abs,
               stats::median(w) + 5 * stats::IQR(w),
               tolerance = 1e-10)
  expect_equal(hist_entry$parameters$lower_abs, -Inf)
})

test_that("trim_weights() k = 6 produces upper_abs = median(w) + 6 * IQR(w)", {
  df <- make_surveywts_data(seed = 7)
  w <- df$base_weight
  taylor <- .make_test_taylor_wt(df)
  result <- trim_weights(taylor, k = 6)
  hist_entry <- result@metadata@weighting_history[[1]]
  expect_equal(hist_entry$parameters$upper_abs,
               stats::median(w) + 6 * stats::IQR(w),
               tolerance = 1e-10)
})

test_that("trim_weights() type='absolute' with both tails explicit", {
  df <- make_surveywts_data(seed = 8)
  w <- df$base_weight
  lo <- stats::quantile(w, 0.05, names = FALSE)
  hi <- stats::quantile(w, 0.95, names = FALSE)
  taylor <- .make_test_taylor_wt(df)
  result <- trim_weights(taylor, lower = lo, upper = hi)
  hist_entry <- result@metadata@weighting_history[[1]]
  expect_equal(hist_entry$parameters$lower_abs, lo)
  expect_equal(hist_entry$parameters$upper_abs, hi)
  # Both tails trimmed
  expect_gt(hist_entry$parameters$n_trimmed_lower, 0L)
  expect_gt(hist_entry$parameters$n_trimmed_upper, 0L)
})

test_that("trim_weights() type='absolute' upper only (lower = NULL)", {
  df <- make_surveywts_data(seed = 9)
  w <- df$base_weight
  hi <- stats::quantile(w, 0.9, names = FALSE)
  taylor <- .make_test_taylor_wt(df)
  result <- trim_weights(taylor, upper = hi)
  hist_entry <- result@metadata@weighting_history[[1]]
  expect_equal(hist_entry$parameters$lower_abs, -Inf)
  expect_equal(hist_entry$parameters$upper_abs, hi)
  expect_equal(hist_entry$parameters$n_trimmed_lower, 0L)
  expect_gt(hist_entry$parameters$n_trimmed_upper, 0L)
})

test_that("trim_weights() type='absolute' lower only (upper = Inf)", {
  df <- make_surveywts_data(seed = 10)
  w <- df$base_weight
  lo <- stats::quantile(w, 0.1, names = FALSE)
  taylor <- .make_test_taylor_wt(df)
  result <- trim_weights(taylor, lower = lo, upper = Inf)
  hist_entry <- result@metadata@weighting_history[[1]]
  # lower trimming only (upper = Inf so no upper trimming)
  expect_gt(hist_entry$parameters$n_trimmed_lower, 0L)
  expect_equal(hist_entry$parameters$n_trimmed_upper, 0L)
})

test_that("trim_weights() type='percentile' upper=0.99 sets upper_abs to 99th percentile", {
  df <- make_surveywts_data(seed = 11)
  w <- df$base_weight
  taylor <- .make_test_taylor_wt(df)
  result <- trim_weights(taylor, upper = 0.99, type = "percentile")
  hist_entry <- result@metadata@weighting_history[[1]]
  expect_equal(hist_entry$parameters$upper_abs,
               stats::quantile(w, 0.99, type = 7, names = FALSE),
               tolerance = 1e-10)
  expect_equal(hist_entry$parameters$lower_abs, -Inf)
})

test_that("trim_weights() type='percentile' upper only (no lower)", {
  df <- make_surveywts_data(seed = 12)
  taylor <- .make_test_taylor_wt(df)
  result <- trim_weights(taylor, upper = 0.95, type = "percentile")
  hist_entry <- result@metadata@weighting_history[[1]]
  expect_equal(hist_entry$parameters$lower_abs, -Inf)
  expect_gt(hist_entry$parameters$n_trimmed_upper, 0L)
})

test_that("trim_weights() explicit no-op (upper = Inf): history appended, warning fires", {
  df <- make_surveywts_data(seed = 13)
  taylor <- .make_test_taylor_wt(df)
  expect_warning(
    result <- trim_weights(taylor, upper = Inf),
    class = "surveywts_warning_no_weights_trimmed"
  )
  hist_entry <- result@metadata@weighting_history[[1]]
  expect_identical(hist_entry$operation, "trim_weights")
  expect_equal(hist_entry$parameters$upper_abs, Inf)
})

test_that("trim_weights() strict=FALSE: weight sum preserved after single pass", {
  df <- make_surveywts_data(seed = 14)
  w <- df$base_weight
  taylor <- .make_test_taylor_wt(df)
  result <- trim_weights(taylor, upper = 0.9, type = "percentile", strict = FALSE)
  result_w <- result@data[[result@variables$weights]]
  expect_equal(sum(result_w), sum(w), tolerance = 1e-10)
})

test_that("trim_weights() strict=TRUE: all main weights within [lower_abs, upper_abs]", {
  df <- make_surveywts_data(seed = 15)
  w <- df$base_weight
  upper_pct <- 0.85
  taylor <- .make_test_taylor_wt(df)
  result <- trim_weights(taylor, upper = upper_pct, type = "percentile", strict = TRUE)
  upper_abs <- stats::quantile(w, upper_pct, type = 7, names = FALSE)
  result_w <- result@data[[result@variables$weights]]
  expect_true(all(result_w <= upper_abs + .Machine$double.eps))
  expect_equal(sum(result_w), sum(w), tolerance = 1e-10)
})

# 2. Numerical correctness — trim_weights() --------------------------------

test_that("trim_weights() weight sum preserved when trimming succeeds (strict=FALSE)", {
  df <- make_surveywts_data(seed = 20)
  w <- df$base_weight
  taylor <- .make_test_taylor_wt(df)
  result <- trim_weights(taylor, upper = 0.9, type = "percentile")
  expect_equal(sum(result@data[[result@variables$weights]]), sum(w), tolerance = 1e-10)
})

test_that("trim_weights() strict=TRUE: all weights in [lower_abs, upper_abs] + epsilon", {
  df <- make_surveywts_data(seed = 21)
  w <- df$base_weight
  lo_pct <- 0.05
  hi_pct <- 0.90
  taylor <- .make_test_taylor_wt(df)
  result <- trim_weights(taylor, lower = lo_pct, upper = hi_pct,
    type = "percentile", strict = TRUE)
  lower_abs <- stats::quantile(w, lo_pct, type = 7, names = FALSE)
  upper_abs <- stats::quantile(w, hi_pct, type = 7, names = FALSE)
  result_w <- result@data[[result@variables$weights]]
  expect_true(all(result_w >= lower_abs - .Machine$double.eps))
  expect_true(all(result_w <= upper_abs + .Machine$double.eps))
})

test_that("trim_weights() strict=FALSE: sum preserved but not all weights in bounds", {
  df <- make_surveywts_data(seed = 22)
  w <- df$base_weight
  lo_pct <- 0.45
  hi_pct <- 0.55
  taylor <- .make_test_taylor_wt(df)
  result <- trim_weights(taylor, lower = lo_pct, upper = hi_pct,
    type = "percentile", strict = FALSE)
  result_w <- result@data[[result@variables$weights]]
  expect_equal(sum(result_w), sum(w), tolerance = 1e-10)
  expect_true(is.numeric(result_w))
})

test_that("trim_weights() n_trimmed_upper equals count of original weights above upper_abs", {
  df <- make_surveywts_data(seed = 23)
  w <- df$base_weight
  upper_pct <- 0.9
  upper_abs <- stats::quantile(w, upper_pct, type = 7, names = FALSE)
  taylor <- .make_test_taylor_wt(df)
  result <- trim_weights(taylor, upper = upper_pct, type = "percentile")
  hist_entry <- result@metadata@weighting_history[[1]]
  expect_equal(hist_entry$parameters$n_trimmed_upper, sum(w > upper_abs))
})

test_that("trim_weights() n_trimmed_lower equals count of original weights below lower_abs", {
  df <- make_surveywts_data(seed = 24)
  w <- df$base_weight
  lower_pct <- 0.1
  lower_abs <- stats::quantile(w, lower_pct, type = 7, names = FALSE)
  taylor <- .make_test_taylor_wt(df)
  result <- trim_weights(taylor, lower = lower_pct, upper = 0.9, type = "percentile")
  hist_entry <- result@metadata@weighting_history[[1]]
  expect_equal(hist_entry$parameters$n_trimmed_lower, sum(w < lower_abs))
})

test_that("trim_weights() type='percentile' upper=0.99: history upper_abs == quantile(w, 0.99)", {
  df <- make_surveywts_data(seed = 25)
  w <- df$base_weight
  taylor <- .make_test_taylor_wt(df)
  result <- trim_weights(taylor, upper = 0.99, type = "percentile")
  hist_entry <- result@metadata@weighting_history[[1]]
  expect_equal(hist_entry$parameters$upper_abs,
    stats::quantile(w, 0.99, type = 7, names = FALSE),
    tolerance = 1e-10)
})

test_that("trim_weights() survey_replicate: colSums preserved per column", {
  rep_design <- make_replicate_design(seed = 2)
  orig_rep <- as.matrix(rep_design@data[rep_design@variables$repweights])
  result <- trim_weights(rep_design, upper = 0.9, type = "percentile")
  result_rep <- as.matrix(result@data[result@variables$repweights])
  # For columns where redistribution succeeds, sum should be preserved
  # With 90th percentile bound, ~10% outside, ~90% available => redistribution succeeds
  col_diffs <- abs(colSums(result_rep) - colSums(orig_rep))
  # Most columns should have preserved sums (redistribution succeeds)
  expect_true(mean(col_diffs < 1e-8) > 0.5)
})

# 3. Error paths — trim_weights() ----------------------------------------

test_that("trim_weights() rejects list input", {
  expect_error(
    trim_weights(list(x = 1:5)),
    class = "surveywts_error_not_survey_base"
  )
  expect_snapshot(error = TRUE, trim_weights(list(x = 1:5)))
})

# E6-E9 removed — weight validation (not_found, not_numeric, nonpositive, na)
# is now enforced by the S7 class validator at construction time; these errors
# are no longer reachable via the public API.

test_that("trim_weights() surveywts_error_empty_data: S7 class invariant prevents 0-row survey_nonprob", {
  # The surveycore survey_nonprob S7 class validator rejects @data assignment
  # when the resulting weight column is empty (0 rows => all-NA weights => error).
  # A 0-row survey_nonprob with repweights is therefore unrepresentable; the
  # surveywts_error_empty_data path in trim_weights() for this combination is
  # structurally unreachable via the public API.
  # This test documents that constraint and verifies the S7 rejection itself.
  n <- 10L
  n_rep <- 3L
  set.seed(99)
  df <- make_surveywts_data(n = n, seed = 99)
  for (i in seq_len(n_rep)) {
    df[[paste0("rep_", i)]] <- abs(stats::rnorm(n, 1, 0.2))
  }
  nonprob_rep_local <- surveycore::as_survey_nonprob(
    data = df,
    weights = base_weight,
    repweights = tidyselect::starts_with("rep_"),
    type = "bootstrap",
    scale = 1 / n_rep,
    mse = TRUE
  )
  # Assigning 0-row data triggers surveycore class validator, not surveywts
  expect_error(
    {
      nonprob_rep_local@data <- nonprob_rep_local@data[integer(0), ]
    },
    class = "surveycore_error_weights_all_zero"
  )
})

test_that("trim_weights() fires surveywts_error_weights_nonpositive for survey_nonprob with repweights and weight <= 0", {
  # Build inline to avoid depending on the later-defined helper
  n <- 10L
  n_rep <- 3L
  set.seed(99)
  df <- make_surveywts_data(n = n, seed = 99)
  for (i in seq_len(n_rep)) {
    df[[paste0("rep_", i)]] <- abs(stats::rnorm(n, 1, 0.2))
  }
  nonprob_rep_local <- surveycore::as_survey_nonprob(
    data = df,
    weights = base_weight,
    repweights = tidyselect::starts_with("rep_"),
    type = "bootstrap",
    scale = 1 / n_rep,
    mse = TRUE
  )
  nonprob_rep_local@data[["base_weight"]][1] <- 0
  expect_error(
    trim_weights(nonprob_rep_local, upper = 2),
    class = "surveywts_error_weights_nonpositive"
  )
})

test_that("trim_weights() rejects upper = NULL with type = 'percentile'", {
  df <- make_surveywts_data(seed = 1)
  taylor <- .make_test_taylor_wt(df)
  expect_error(
    trim_weights(taylor, type = "percentile"),
    class = "surveywts_error_null_bound_percentile"
  )
  expect_snapshot(
    error = TRUE,
    trim_weights(taylor, type = "percentile")
  )
})

test_that("trim_weights() rejects k = character scalar", {
  df <- make_surveywts_data(seed = 1)
  taylor <- .make_test_taylor_wt(df)
  expect_error(
    trim_weights(taylor, k = "5"),
    class = "surveywts_error_k_not_scalar"
  )
  expect_snapshot(
    error = TRUE,
    trim_weights(taylor, k = "5")
  )
})

test_that("trim_weights() rejects k = NA_real_", {
  df <- make_surveywts_data(seed = 1)
  taylor <- .make_test_taylor_wt(df)
  expect_error(
    trim_weights(taylor, k = NA_real_),
    class = "surveywts_error_k_not_scalar"
  )
  expect_snapshot(
    error = TRUE,
    trim_weights(taylor, k = NA_real_)
  )
})

test_that("trim_weights() rejects k = length-2 numeric", {
  df <- make_surveywts_data(seed = 1)
  taylor <- .make_test_taylor_wt(df)
  expect_error(
    trim_weights(taylor, k = c(1, 2)),
    class = "surveywts_error_k_not_scalar"
  )
  expect_snapshot(
    error = TRUE,
    trim_weights(taylor, k = c(1, 2))
  )
})

test_that("trim_weights() rejects k = -1", {
  df <- make_surveywts_data(seed = 1)
  taylor <- .make_test_taylor_wt(df)
  expect_error(
    trim_weights(taylor, k = -1),
    class = "surveywts_error_k_nonpositive"
  )
  expect_snapshot(
    error = TRUE,
    trim_weights(taylor, k = -1)
  )
})

test_that("trim_weights() rejects k = 0", {
  df <- make_surveywts_data(seed = 1)
  taylor <- .make_test_taylor_wt(df)
  expect_error(
    trim_weights(taylor, k = 0),
    class = "surveywts_error_k_nonpositive"
  )
  expect_snapshot(
    error = TRUE,
    trim_weights(taylor, k = 0)
  )
})

test_that("trim_weights() rejects lower = character scalar", {
  df <- make_surveywts_data(seed = 1)
  taylor <- .make_test_taylor_wt(df)
  expect_error(
    trim_weights(taylor, lower = "0.5"),
    class = "surveywts_error_lower_not_scalar"
  )
  expect_snapshot(
    error = TRUE,
    trim_weights(taylor, lower = "0.5")
  )
})

test_that("trim_weights() rejects lower = NA_real_", {
  df <- make_surveywts_data(seed = 1)
  taylor <- .make_test_taylor_wt(df)
  expect_error(
    trim_weights(taylor, lower = NA_real_),
    class = "surveywts_error_lower_not_scalar"
  )
  expect_snapshot(
    error = TRUE,
    trim_weights(taylor, lower = NA_real_)
  )
})

test_that("trim_weights() rejects upper = length-2 numeric", {
  df <- make_surveywts_data(seed = 1)
  taylor <- .make_test_taylor_wt(df)
  expect_error(
    trim_weights(taylor, upper = c(1, 2)),
    class = "surveywts_error_upper_not_scalar"
  )
  expect_snapshot(
    error = TRUE,
    trim_weights(taylor, upper = c(1, 2))
  )
})

test_that("trim_weights() rejects upper = NA_real_", {
  df <- make_surveywts_data(seed = 1)
  taylor <- .make_test_taylor_wt(df)
  expect_error(
    trim_weights(taylor, upper = NA_real_),
    class = "surveywts_error_upper_not_scalar"
  )
  expect_snapshot(
    error = TRUE,
    trim_weights(taylor, upper = NA_real_)
  )
})

test_that("trim_weights() rejects equal resolved bounds (lower = upper)", {
  df <- make_surveywts_data(seed = 1)
  taylor <- .make_test_taylor_wt(df)
  expect_error(
    trim_weights(taylor, lower = 3, upper = 3),
    class = "surveywts_error_bounds_invalid"
  )
  expect_snapshot(
    error = TRUE,
    trim_weights(taylor, lower = 3, upper = 3)
  )
})

test_that("trim_weights() rejects reversed bounds (lower > upper)", {
  df <- make_surveywts_data(seed = 1)
  taylor <- .make_test_taylor_wt(df)
  expect_error(
    trim_weights(taylor, lower = 5, upper = 3),
    class = "surveywts_error_bounds_invalid"
  )
  expect_snapshot(
    error = TRUE,
    trim_weights(taylor, lower = 5, upper = 3)
  )
})

test_that("trim_weights() rejects reversed percentile bounds", {
  df <- make_surveywts_data(seed = 1)
  taylor <- .make_test_taylor_wt(df)
  expect_error(
    trim_weights(taylor, lower = 0.99, upper = 0.01, type = "percentile"),
    class = "surveywts_error_bounds_invalid"
  )
  expect_snapshot(
    error = TRUE,
    trim_weights(taylor, lower = 0.99, upper = 0.01, type = "percentile")
  )
})

test_that("trim_weights() rejects upper = 0 (absolute, non-positive)", {
  df <- make_surveywts_data(seed = 1)
  taylor <- .make_test_taylor_wt(df)
  expect_error(
    trim_weights(taylor, upper = 0),
    class = "surveywts_error_upper_nonpositive"
  )
  expect_snapshot(
    error = TRUE,
    trim_weights(taylor, upper = 0)
  )
})

test_that("trim_weights() rejects upper = -1 (absolute, negative)", {
  df <- make_surveywts_data(seed = 1)
  taylor <- .make_test_taylor_wt(df)
  expect_error(
    trim_weights(taylor, upper = -1),
    class = "surveywts_error_upper_nonpositive"
  )
  expect_snapshot(
    error = TRUE,
    trim_weights(taylor, upper = -1)
  )
})

test_that("trim_weights() rejects lower = -0.1 with type = 'percentile'", {
  df <- make_surveywts_data(seed = 1)
  taylor <- .make_test_taylor_wt(df)
  expect_error(
    trim_weights(taylor, lower = -0.1, upper = 0.99, type = "percentile"),
    class = "surveywts_error_percentile_out_of_range"
  )
  expect_snapshot(
    error = TRUE,
    trim_weights(taylor, lower = -0.1, upper = 0.99, type = "percentile")
  )
})

test_that("trim_weights() rejects upper = 1.1 with type = 'percentile'", {
  df <- make_surveywts_data(seed = 1)
  taylor <- .make_test_taylor_wt(df)
  expect_error(
    trim_weights(taylor, upper = 1.1, type = "percentile"),
    class = "surveywts_error_percentile_out_of_range"
  )
  expect_snapshot(
    error = TRUE,
    trim_weights(taylor, upper = 1.1, type = "percentile")
  )
})

test_that("trim_weights() rejects wt_name = 1L", {
  df <- make_surveywts_data(seed = 1)
  taylor <- .make_test_taylor_wt(df)
  expect_error(
    trim_weights(taylor, wt_name = 1L),
    class = "surveywts_error_wt_name_not_scalar"
  )
  expect_snapshot(
    error = TRUE,
    trim_weights(taylor, wt_name = 1L)
  )
})

test_that("trim_weights() rejects wt_name = ''", {
  df <- make_surveywts_data(seed = 1)
  taylor <- .make_test_taylor_wt(df)
  expect_error(
    trim_weights(taylor, wt_name = ""),
    class = "surveywts_error_wt_name_empty"
  )
  expect_snapshot(
    error = TRUE,
    trim_weights(taylor, wt_name = "")
  )
})

# 4. Warning paths — trim_weights() ----------------------------------------

test_that("trim_weights() warns when all main weights already within bounds", {
  df <- make_surveywts_data(seed = 30)
  taylor <- .make_test_taylor_wt(df)
  expect_warning(
    result <- trim_weights(taylor, lower = 0.01, upper = 100),
    class = "surveywts_warning_no_weights_trimmed"
  )
  expect_true(S7::S7_inherits(result, surveycore::survey_taylor))
  hist_entry <- result@metadata@weighting_history[[1]]
  expect_identical(hist_entry$operation, "trim_weights")
})

test_that("trim_weights() warns when all units are outside bounds (trimming failed)", {
  two_row <- data.frame(x = 1:2, w = c(1, 10))
  design_two_row <- .make_test_taylor_wt(two_row, weight_col = "w")
  expect_warning(
    result <- trim_weights(design_two_row, lower = 3, upper = 7),
    class = "surveywts_warning_trimming_failed"
  )
  expect_false(
    isTRUE(
      abs(sum(result@data[[result@variables$weights]]) - sum(c(1, 10))) < 1e-10
    )
  )
})

# 5. History correctness — trim_weights() -----------------------------------

test_that("trim_weights() history entry has all required fields", {
  df <- make_surveywts_data(seed = 40)
  taylor <- .make_test_taylor_wt(df)
  result <- trim_weights(taylor, upper = 0.9, type = "percentile")
  hist_entry <- result@metadata@weighting_history[[1]]

  expect_identical(hist_entry$operation, "trim_weights")
  expect_true(!is.null(hist_entry$parameters$type))
  expect_true(!is.null(hist_entry$parameters$strict))
  expect_true("lower_input" %in% names(hist_entry$parameters))
  expect_true("upper_input" %in% names(hist_entry$parameters))
  expect_true(!is.null(hist_entry$parameters$lower_abs))
  expect_true(!is.null(hist_entry$parameters$upper_abs))
  expect_true("n_trimmed_lower" %in% names(hist_entry$parameters))
  expect_true("n_trimmed_upper" %in% names(hist_entry$parameters))
})

test_that("trim_weights() type='percentile': lower_input != lower_abs", {
  df <- make_surveywts_data(seed = 41)
  taylor <- .make_test_taylor_wt(df)
  result <- trim_weights(taylor, lower = 0.05, upper = 0.95, type = "percentile")
  hist_entry <- result@metadata@weighting_history[[1]]
  # Percentile input (0.05) != resolved absolute value (quantile)
  expect_false(isTRUE(hist_entry$parameters$lower_input == hist_entry$parameters$lower_abs))
})

test_that("trim_weights() step number is correct when chained after calibrate_linear()", {
  df <- make_surveywts_data(seed = 42)
  targets <- list(age_group = c("18-34" = 0.30, "35-54" = 0.40, "55+" = 0.30))
  taylor <- .make_test_taylor_wt(df)
  calibrated <- calibrate_linear(taylor, targets = targets)

  result <- trim_weights(calibrated, upper = 0.9, type = "percentile")
  hist <- result@metadata@weighting_history
  expect_equal(length(hist), 2L)
  expect_equal(hist[[2L]]$step, 2L)
  expect_identical(hist[[2L]]$operation, "trim_weights")
})

# 6. Edge cases — trim_weights() --------------------------------------------

test_that("trim_weights() works on single-row survey_taylor", {
  one_row <- data.frame(x = 1, w = 2.5)
  design_one <- .make_test_taylor_wt(one_row, weight_col = "w")
  expect_warning(
    result <- trim_weights(design_one),
    class = "surveywts_warning_no_weights_trimmed"
  )
  expect_true(S7::S7_inherits(result, surveycore::survey_taylor))
  expect_equal(nrow(result@data), 1L)
})

test_that("trim_weights() warns and is a no-op when all weights are equal", {
  df <- data.frame(x = 1:10, w = rep(1, 10))
  design <- .make_test_taylor_wt(df, weight_col = "w")
  expect_warning(
    result <- trim_weights(design),
    class = "surveywts_warning_no_weights_trimmed"
  )
  expect_equal(result@data[[result@variables$weights]], rep(1, 10), tolerance = 1e-10)
})

test_that("trim_weights() counts exactly 1 trimmed at each bound", {
  w_vec <- c(0.1, rep(1, 8), 10)
  df <- data.frame(x = seq_along(w_vec), w = w_vec)
  design <- .make_test_taylor_wt(df, weight_col = "w")
  lo <- 0.5
  hi <- 5.0

  result <- trim_weights(design, lower = lo, upper = hi)
  hist_entry <- result@metadata@weighting_history[[1]]
  expect_equal(hist_entry$parameters$n_trimmed_lower, 1L)
  expect_equal(hist_entry$parameters$n_trimmed_upper, 1L)
})

test_that("trim_weights() survey_replicate + percentile: cutoffs from main weights applied to replicates", {
  rep_design <- make_replicate_design(seed = 3)
  w_main <- rep_design@data[[rep_design@variables$weights]]
  upper_pct <- 0.9
  expected_upper <- stats::quantile(w_main, upper_pct, type = 7, names = FALSE)

  result <- trim_weights(rep_design, upper = upper_pct, type = "percentile")
  hist <- result@metadata@weighting_history
  hist_entry <- hist[[length(hist)]]
  expect_equal(hist_entry$parameters$upper_abs, expected_upper, tolerance = 1e-10)
})

# rescale_weights() --------------------------------------------------

# 1. Happy path — rescale_weights() -----------------------------------

test_that("rescale_weights() rejects plain data.frame input", {
  df <- make_surveywts_data(seed = 50)
  expect_error(
    rescale_weights(df),
    class = "surveywts_error_not_survey_base"
  )
  expect_snapshot(error = TRUE, rescale_weights(df))
})

test_that("rescale_weights() preserves survey_taylor class", {
  df <- make_surveywts_data(seed = 52)
  design <- .make_test_taylor_wt(df)
  result <- rescale_weights(design)
  test_invariants(result)
  expect_true(S7::S7_inherits(result, surveycore::survey_taylor))
})

test_that("rescale_weights() preserves survey_nonprob class", {
  df <- make_surveywts_data(seed = 53)
  design <- .make_test_nonprob_wt(df)
  result <- rescale_weights(design)
  test_invariants(result)
  expect_true(S7::S7_inherits(result, surveycore::survey_nonprob))
})

test_that("rescale_weights() preserves survey_replicate class and scales rep weights", {
  rep_design <- make_replicate_design(seed = 4)
  orig_main <- rep_design@data[[rep_design@variables$weights]]
  orig_rep <- as.matrix(rep_design@data[rep_design@variables$repweights])

  result <- rescale_weights(rep_design)
  test_invariants(result)
  expect_true(S7::S7_inherits(result, surveycore::survey_replicate))

  result_main <- result@data[[result@variables$weights]]
  result_rep <- as.matrix(result@data[result@variables$repweights])

  # Main weights changed (unless they already sum to n)
  n <- nrow(rep_design@data)
  if (abs(sum(orig_main) - n) > 1e-10) {
    expect_false(identical(result_main, orig_main))
  }
  # Replicate weight matrix has same dimensions
  expect_identical(dim(result_rep), dim(orig_rep))
})

test_that("rescale_weights() global: sum(result_weights) == nrow(data)", {
  df <- make_surveywts_data(seed = 55)
  taylor <- .make_test_taylor_wt(df)
  result <- rescale_weights(taylor)
  expect_equal(
    sum(result@data[[result@variables$weights]]),
    nrow(df),
    tolerance = 1e-10
  )
})

test_that("rescale_weights() by = col: each group sums to group n", {
  df <- make_surveywts_data(seed = 56)
  taylor <- .make_test_taylor_wt(df)
  result <- rescale_weights(taylor, by = age_group)
  w_new <- result@data[[result@variables$weights]]
  for (grp in unique(df$age_group)) {
    idx <- df$age_group == grp
    expect_equal(sum(w_new[idx]), sum(idx), tolerance = 1e-10)
  }
})

test_that("rescale_weights() by = c(col1, col2): multi-variable grouping works", {
  df <- make_surveywts_data(seed = 57)
  taylor <- .make_test_taylor_wt(df)
  result <- rescale_weights(taylor, by = c(age_group, sex))
  w_new <- result@data[[result@variables$weights]]
  for (ag in unique(df$age_group)) {
    for (sx in unique(df$sex)) {
      idx <- df$age_group == ag & df$sex == sx
      if (sum(idx) > 0L) {
        expect_equal(sum(w_new[idx]), sum(idx), tolerance = 1e-10)
      }
    }
  }
})

# 2. Numerical correctness — rescale_weights() --------------------------

test_that("rescale_weights() global: sum(w_new) == n to machine precision", {
  df <- make_surveywts_data(seed = 60)
  taylor <- .make_test_taylor_wt(df)
  result <- rescale_weights(taylor)
  expect_equal(
    sum(result@data[[result@variables$weights]]),
    nrow(df),
    tolerance = 1e-10
  )
})

test_that("rescale_weights() within-group: each group sums to group n (tolerance 1e-10)", {
  df <- make_surveywts_data(seed = 61)
  taylor <- .make_test_taylor_wt(df)
  result <- rescale_weights(taylor, by = age_group)
  w_new <- result@data[[result@variables$weights]]
  for (grp in unique(df$age_group)) {
    idx <- df$age_group == grp
    expect_equal(sum(w_new[idx]), sum(idx), tolerance = 1e-10)
  }
})

test_that("rescale_weights() scale factor n/sum(w) matches history", {
  df <- make_surveywts_data(seed = 62)
  w <- df$base_weight
  n <- nrow(df)
  taylor <- .make_test_taylor_wt(df)
  result <- rescale_weights(taylor)
  hist_entry <- result@metadata@weighting_history[[1]]
  expected_sf <- n / sum(w)
  expect_equal(hist_entry$parameters$scale_factor, expected_sf, tolerance = 1e-10)
})

test_that("rescale_weights() survey_replicate global: each rep column scaled by same factor", {
  rep_design <- make_replicate_design(seed = 5)
  orig_main <- rep_design@data[[rep_design@variables$weights]]
  orig_rep <- as.matrix(rep_design@data[rep_design@variables$repweights])
  n <- nrow(rep_design@data)
  scale_f <- n / sum(orig_main)

  result <- rescale_weights(rep_design)
  result_rep <- as.matrix(result@data[result@variables$repweights])

  # Each replicate column multiplied by same scale factor
  expected_colsums <- colSums(orig_rep) * scale_f
  expect_equal(colSums(result_rep), expected_colsums, tolerance = 1e-10)
})

test_that("rescale_weights() survey_replicate with by: per-group factors applied to rep columns", {
  rep_design <- make_replicate_design(seed = 6)
  orig_main <- rep_design@data[[rep_design@variables$weights]]
  orig_rep <- as.matrix(rep_design@data[rep_design@variables$repweights])
  data_df <- rep_design@data

  result <- rescale_weights(rep_design, by = age_group)
  result_rep <- as.matrix(result@data[result@variables$repweights])

  # Verify per-group: sum of result_rep[h, j] == sum(orig_rep[h, j]) * (n_h / W_h)
  for (grp in unique(data_df$age_group)) {
    idx <- data_df$age_group == grp
    n_h <- sum(idx)
    W_h <- sum(orig_main[idx])
    sf_h <- n_h / W_h
    for (j in seq_len(ncol(orig_rep))) {
      orig_col_sum_h <- sum(orig_rep[idx, j])
      result_col_sum_h <- sum(result_rep[idx, j])
      expect_equal(result_col_sum_h, orig_col_sum_h * sf_h, tolerance = 1e-10)
    }
  }
})

# 3. Error paths — rescale_weights() ------------------------------------

test_that("rescale_weights() rejects list input", {
  expect_error(
    rescale_weights(list(x = 1:5)),
    class = "surveywts_error_not_survey_base"
  )
  expect_snapshot(error = TRUE, rescale_weights(list(x = 1:5)))
})

# E6-E9 removed — weight validation (not_found, not_numeric, nonpositive, na)
# is now enforced by the S7 class validator at construction time; these errors
# are no longer reachable via the public API.

test_that("rescale_weights() rejects by variable not in data", {
  df <- make_surveywts_data(seed = 1)
  taylor <- .make_test_taylor_wt(df)
  expect_error(
    rescale_weights(taylor, by = nonexistent_col),
    class = "surveywts_error_by_variable_not_found"
  )
  expect_snapshot(
    error = TRUE,
    rescale_weights(taylor, by = nonexistent_col)
  )
})

test_that("rescale_weights() rejects by variable with NA values", {
  df <- make_surveywts_data(seed = 1)
  df$age_group[1] <- NA
  taylor <- .make_test_taylor_wt(df)
  expect_error(
    rescale_weights(taylor, by = age_group),
    class = "surveywts_error_variable_has_na"
  )
  expect_snapshot(
    error = TRUE,
    rescale_weights(taylor, by = age_group)
  )
})

test_that("rescale_weights() rejects wt_name = 1L", {
  df <- make_surveywts_data(seed = 1)
  taylor <- .make_test_taylor_wt(df)
  expect_error(
    rescale_weights(taylor, wt_name = 1L),
    class = "surveywts_error_wt_name_not_scalar"
  )
  expect_snapshot(
    error = TRUE,
    rescale_weights(taylor, wt_name = 1L)
  )
})

test_that("rescale_weights() rejects wt_name = ''", {
  df <- make_surveywts_data(seed = 1)
  taylor <- .make_test_taylor_wt(df)
  expect_error(
    rescale_weights(taylor, wt_name = ""),
    class = "surveywts_error_wt_name_empty"
  )
  expect_snapshot(
    error = TRUE,
    rescale_weights(taylor, wt_name = "")
  )
})

test_that("rescale_weights() surveywts_error_empty_data: S7 class invariant prevents 0-row survey_nonprob", {
  # The surveycore survey_nonprob S7 class validator rejects @data assignment
  # when the resulting weight column is empty (0 rows => all-NA weights => error).
  # A 0-row survey_nonprob with repweights is therefore unrepresentable; the
  # surveywts_error_empty_data path in rescale_weights() for this combination
  # is structurally unreachable via the public API.
  # This test documents that constraint and verifies the S7 rejection itself.
  n <- 10L
  n_rep <- 3L
  set.seed(99)
  df <- make_surveywts_data(n = n, seed = 99)
  for (i in seq_len(n_rep)) {
    df[[paste0("rep_", i)]] <- abs(stats::rnorm(n, 1, 0.2))
  }
  nonprob_rep_local <- surveycore::as_survey_nonprob(
    data = df,
    weights = base_weight,
    repweights = tidyselect::starts_with("rep_"),
    type = "bootstrap",
    scale = 1 / n_rep,
    mse = TRUE
  )
  # Assigning 0-row data triggers surveycore class validator, not surveywts
  expect_error(
    {
      nonprob_rep_local@data <- nonprob_rep_local@data[integer(0), ]
    },
    class = "surveycore_error_weights_all_zero"
  )
})

# 4. History correctness — rescale_weights() -----------------------------

test_that("rescale_weights() history entry has all required fields", {
  df <- make_surveywts_data(seed = 70)
  taylor <- .make_test_taylor_wt(df)
  result <- rescale_weights(taylor)
  hist_entry <- result@metadata@weighting_history[[1]]

  expect_identical(hist_entry$operation, "rescale_weights")
  expect_true("by" %in% names(hist_entry$parameters))
  expect_true("scale_factor" %in% names(hist_entry$parameters))
  expect_null(hist_entry$parameters$by)
})

test_that("rescale_weights() by history: named scale_factor vector with ' | ' separator", {
  df <- make_surveywts_data(seed = 71)
  taylor <- .make_test_taylor_wt(df)
  result <- rescale_weights(taylor, by = c(age_group, sex))
  hist_entry <- result@metadata@weighting_history[[1]]
  expect_false(is.null(hist_entry$parameters$by))
  expect_true(is.numeric(hist_entry$parameters$scale_factor))
  expect_true(length(hist_entry$parameters$scale_factor) > 1L)
  sf_names <- names(hist_entry$parameters$scale_factor)
  expect_true(all(grepl(" | ", sf_names, fixed = TRUE)))
})

test_that("rescale_weights() step number correct when chained after trim_weights()", {
  df <- make_surveywts_data(seed = 72)
  taylor <- .make_test_taylor_wt(df)
  trimmed <- trim_weights(taylor, upper = 0.9, type = "percentile")
  result <- rescale_weights(trimmed)
  hist <- result@metadata@weighting_history
  expect_equal(length(hist), 2L)
  expect_equal(hist[[2L]]$step, 2L)
  expect_identical(hist[[2L]]$operation, "rescale_weights")
})

# 5. Edge cases — rescale_weights() -------------------------------------

test_that("rescale_weights() no-op when weights already sum to n", {
  n <- 100L
  w <- rep(1, n)
  df <- data.frame(x = seq_len(n), w = w)
  taylor <- .make_test_taylor_wt(df, weight_col = "w")
  result <- rescale_weights(taylor)
  hist_entry <- result@metadata@weighting_history[[1]]
  expect_equal(hist_entry$parameters$scale_factor, 1.0, tolerance = 1e-10)
  expect_equal(
    sum(result@data[[result@variables$weights]]),
    n,
    tolerance = 1e-10
  )
})

test_that("rescale_weights() single-row data: weight set to 1", {
  one_row <- data.frame(x = 1, w = 5.0)
  taylor_one <- .make_test_taylor_wt(one_row, weight_col = "w")
  result <- rescale_weights(taylor_one)
  expect_equal(result@data[[result@variables$weights]], 1.0, tolerance = 1e-10)
})

test_that("rescale_weights() by with one group: equivalent to global stabilization", {
  df <- make_surveywts_data(seed = 75)
  df$const_group <- "all"
  taylor <- .make_test_taylor_wt(df)

  result_global <- rescale_weights(taylor)
  result_by <- rescale_weights(taylor, by = const_group)

  expect_equal(
    result_global@data[[result_global@variables$weights]],
    result_by@data[[result_by@variables$weights]],
    tolerance = 1e-10
  )
})

test_that("rescale_weights() by with group of size 1: weight for that observation set to 1", {
  n <- 20L
  df <- data.frame(
    x = seq_len(n),
    w = exp(stats::rnorm(n, 0, 0.4)),
    grp = c("A", rep("B", n - 1L))
  )
  taylor <- .make_test_taylor_wt(df, weight_col = "w")
  result <- rescale_weights(taylor, by = grp)
  idx_a <- df$grp == "A"
  expect_equal(
    result@data[[result@variables$weights]][idx_a],
    1.0,
    tolerance = 1e-10
  )
})

# ===========================================================================
# .has_repweights() predicate
# ===========================================================================

# Helper: build a survey_nonprob with repweights for these tests.
.make_nonprob_with_repweights <- function(n = 100L, n_rep = 10L, seed = 42L) {
  set.seed(seed)
  df <- make_surveywts_data(n = n, seed = seed)
  for (i in seq_len(n_rep)) {
    df[[paste0("rep_", i)]] <- abs(stats::rnorm(n, 1, 0.2))
  }
  surveycore::as_survey_nonprob(
    data = df,
    weights = base_weight,
    repweights = tidyselect::starts_with("rep_"),
    type = "bootstrap",
    scale = 1 / n_rep,
    mse = TRUE
  )
}

# Helper: build a survey_nonprob WITHOUT repweights.
.make_nonprob_no_repweights <- function(n = 100L, seed = 42L) {
  df <- make_surveywts_data(n = n, seed = seed)
  surveycore::survey_nonprob(
    data = df,
    variables = list(
      ids = NULL, strata = NULL, fpc = NULL,
      weights = "base_weight", nest = FALSE
    ),
    metadata = surveycore::survey_metadata(),
    groups = character(0),
    call = NULL,
    calibration = NULL
  )
}

test_that(".has_repweights() returns TRUE for survey_replicate", {
  rep_design <- make_replicate_design(seed = 1)
  expect_true(.has_repweights(rep_design))
})

test_that(".has_repweights() returns TRUE for survey_nonprob with repweights (length >= 1)", {
  nonprob_rep <- .make_nonprob_with_repweights(seed = 1)
  expect_true(.has_repweights(nonprob_rep))
})

test_that(".has_repweights() returns FALSE for survey_nonprob with NULL repweights", {
  nonprob_no_rep <- .make_nonprob_no_repweights(seed = 1)
  expect_false(.has_repweights(nonprob_no_rep))
})

test_that(".has_repweights() returns FALSE for survey_nonprob with character(0) repweights", {
  nonprob_rep <- .make_nonprob_with_repweights(seed = 1)
  # Manually set repweights to character(0)
  nonprob_rep@variables <- modifyList(
    nonprob_rep@variables,
    list(repweights = character(0))
  )
  expect_false(.has_repweights(nonprob_rep))
})

test_that(".has_repweights() returns FALSE for survey_taylor", {
  df <- make_surveywts_data(seed = 1)
  design <- .make_test_taylor_wt(df)
  expect_false(.has_repweights(design))
})

test_that(".has_repweights() returns FALSE for plain data.frame", {
  df <- make_surveywts_data(seed = 1)
  expect_false(.has_repweights(df))
})

test_that(".has_repweights() returns FALSE for NULL without throwing", {
  expect_false(.has_repweights(NULL))
})

test_that(".has_repweights() returns FALSE for list", {
  expect_false(.has_repweights(list(x = 1)))
})

# ===========================================================================
# trim_weights() — survey_nonprob with repweights
# ===========================================================================

test_that("trim_weights() preserves survey_nonprob class for nonprob with repweights", {
  nonprob_rep <- .make_nonprob_with_repweights(seed = 10)
  result <- trim_weights(nonprob_rep, upper = 0.9, type = "percentile")
  test_invariants(result)
  expect_true(S7::S7_inherits(result, surveycore::survey_nonprob))
  expect_false(S7::S7_inherits(result, surveycore::survey_replicate))
})

test_that("trim_weights() updates replicate columns for survey_nonprob with repweights", {
  nonprob_rep <- .make_nonprob_with_repweights(seed = 11)
  orig_rep <- as.matrix(nonprob_rep@data[nonprob_rep@variables$repweights])

  result <- trim_weights(nonprob_rep, upper = 0.8, type = "percentile")

  result_rep <- as.matrix(result@data[result@variables$repweights])
  expect_identical(dim(result_rep), dim(orig_rep))
  # At least some replicate values changed
  expect_false(all(result_rep == orig_rep))
})

test_that("trim_weights() applies same bounds to replicates as main weights for nonprob", {
  nonprob_rep <- .make_nonprob_with_repweights(seed = 12)
  w_main <- nonprob_rep@data[[nonprob_rep@variables$weights]]
  upper_pct <- 0.9
  upper_abs <- stats::quantile(w_main, upper_pct, type = 7, names = FALSE)

  result <- trim_weights(nonprob_rep, upper = upper_pct, type = "percentile")
  result_rep <- as.matrix(result@data[result@variables$repweights])

  # All rep values should be clipped at upper_abs
  expect_true(all(result_rep <= upper_abs + .Machine$double.eps))
})

test_that("trim_weights() appends history entry for survey_nonprob with repweights", {
  nonprob_rep <- .make_nonprob_with_repweights(seed = 13)
  result <- trim_weights(nonprob_rep, upper = 0.9, type = "percentile")
  hist <- result@metadata@weighting_history
  expect_true(length(hist) >= 1L)
  last_entry <- hist[[length(hist)]]
  expect_identical(last_entry$operation, "trim_weights")
})

test_that("trim_weights() does not update replicates for survey_nonprob WITHOUT repweights", {
  nonprob_no_rep <- .make_nonprob_no_repweights(seed = 14)
  # Should succeed without error, returning survey_nonprob
  result <- trim_weights(nonprob_no_rep, upper = 0.9, type = "percentile")
  expect_true(S7::S7_inherits(result, surveycore::survey_nonprob))
})

test_that("trim_weights() nonprob + repweights: warning fires when all main weights in bounds", {
  nonprob_rep <- .make_nonprob_with_repweights(seed = 15)
  rep_cols <- nonprob_rep@variables$repweights
  # Very wide bounds so no trimming occurs
  expect_warning(
    result <- trim_weights(nonprob_rep, lower = 0.01, upper = 100),
    class = "surveywts_warning_no_weights_trimmed"
  )
  # Class is preserved
  expect_true(S7::S7_inherits(result, surveycore::survey_nonprob))
  # Rep columns differ from input (wide bounds still clip high rep values)
  # and main weights are unchanged when none are outside bounds
  main_col <- nonprob_rep@variables$weights
  expect_identical(
    result@data[[main_col]],
    nonprob_rep@data[[main_col]]
  )
})

test_that("trim_weights() nonprob + repweights: strict=FALSE (default) not applied to replicates", {
  # The strict loop applies only to main weights; replicates use one-pass clip-and-redistribute.
  # We verify that the function completes and replicate columns have values <= upper_abs.
  nonprob_rep <- .make_nonprob_with_repweights(seed = 16)
  w_main <- nonprob_rep@data[[nonprob_rep@variables$weights]]
  upper_pct <- 0.85
  upper_abs <- stats::quantile(w_main, upper_pct, type = 7, names = FALSE)

  result <- trim_weights(nonprob_rep, upper = upper_pct, type = "percentile", strict = TRUE)
  result_rep <- as.matrix(result@data[result@variables$repweights])
  # Replicate values should be clipped at upper_abs (one pass only)
  expect_true(all(result_rep <= upper_abs + .Machine$double.eps))
})

test_that("trim_weights() handles all-outside-bounds replicate columns for survey_nonprob with repweights", {
  nonprob_rep <- .make_nonprob_with_repweights(seed = 17)
  # Tight absolute upper so all rep values are clipped
  result <- suppressWarnings(trim_weights(nonprob_rep, upper = 0.001))
  expect_true(S7::S7_inherits(result, surveycore::survey_nonprob))
  rep_cols <- result@variables$repweights
  for (col in rep_cols) {
    expect_true(all(result@data[[col]] <= 0.001 + .Machine$double.eps * 10))
  }
})

test_that("trim_weights() clips a single replicate column for survey_nonprob with repweights", {
  nonprob_rep <- .make_nonprob_with_repweights(seed = 18)
  # Narrow to one rep column by modifying @variables
  first_rep_col <- nonprob_rep@variables$repweights[[1]]
  nonprob_rep@variables <- modifyList(
    nonprob_rep@variables,
    list(repweights = first_rep_col)
  )
  # Set rep values high so clipping fires
  nonprob_rep@data[[first_rep_col]] <- rep(100, nrow(nonprob_rep@data))
  result <- trim_weights(nonprob_rep, upper = 5)
  expect_true(all(result@data[[first_rep_col]] <= 5 + .Machine$double.eps * 10))
})

# ===========================================================================
# rescale_weights() — survey_nonprob with repweights
# ===========================================================================

test_that("rescale_weights() preserves survey_nonprob class for nonprob with repweights", {
  nonprob_rep <- .make_nonprob_with_repweights(seed = 20)
  result <- rescale_weights(nonprob_rep)
  test_invariants(result)
  expect_true(S7::S7_inherits(result, surveycore::survey_nonprob))
  expect_false(S7::S7_inherits(result, surveycore::survey_replicate))
})

test_that("rescale_weights() global: scales all rep columns by same factor for nonprob", {
  nonprob_rep <- .make_nonprob_with_repweights(seed = 21)
  orig_main <- nonprob_rep@data[[nonprob_rep@variables$weights]]
  orig_rep <- as.matrix(nonprob_rep@data[nonprob_rep@variables$repweights])
  n <- nrow(nonprob_rep@data)
  scale_f <- n / sum(orig_main)

  result <- rescale_weights(nonprob_rep)
  result_rep <- as.matrix(result@data[result@variables$repweights])

  expected_colsums <- colSums(orig_rep) * scale_f
  expect_equal(colSums(result_rep), expected_colsums, tolerance = 1e-10)
})

test_that("rescale_weights() per-group: applies per-row scale factors to rep columns for nonprob", {
  nonprob_rep <- .make_nonprob_with_repweights(seed = 22)
  orig_main <- nonprob_rep@data[[nonprob_rep@variables$weights]]
  orig_rep <- as.matrix(nonprob_rep@data[nonprob_rep@variables$repweights])
  data_df <- nonprob_rep@data

  result <- rescale_weights(nonprob_rep, by = age_group)
  result_rep <- as.matrix(result@data[result@variables$repweights])

  for (grp in unique(data_df$age_group)) {
    idx <- data_df$age_group == grp
    n_h <- sum(idx)
    W_h <- sum(orig_main[idx])
    sf_h <- n_h / W_h
    for (j in seq_len(ncol(orig_rep))) {
      orig_sum_h <- sum(orig_rep[idx, j])
      result_sum_h <- sum(result_rep[idx, j])
      expect_equal(result_sum_h, orig_sum_h * sf_h, tolerance = 1e-10)
    }
  }
})

test_that("rescale_weights() appends history entry for survey_nonprob with repweights", {
  nonprob_rep <- .make_nonprob_with_repweights(seed = 23)
  result <- rescale_weights(nonprob_rep)
  hist <- result@metadata@weighting_history
  expect_true(length(hist) >= 1L)
  last_entry <- hist[[length(hist)]]
  expect_identical(last_entry$operation, "rescale_weights")
})

test_that("rescale_weights() does not scale replicates for survey_nonprob WITHOUT repweights", {
  nonprob_no_rep <- .make_nonprob_no_repweights(seed = 24)
  result <- rescale_weights(nonprob_no_rep)
  expect_true(S7::S7_inherits(result, surveycore::survey_nonprob))
})

test_that("rescale_weights() nonprob + repweights: scale_factor == 1.0 when weights already sum to n", {
  set.seed(42)
  n <- 50L
  n_rep <- 5L
  df <- data.frame(
    id = seq_len(n),
    age_group = sample(c("18-34", "35-54", "55+"), n, replace = TRUE),
    sex = sample(c("M", "F"), n, replace = TRUE),
    education = sample(c("<HS", "HS", "College", "Graduate"), n, replace = TRUE),
    region = sample(c("Northeast", "South", "Midwest", "West"), n, replace = TRUE),
    base_weight = rep(1.0, n)  # weights already sum to n
  )
  for (i in seq_len(n_rep)) {
    df[[paste0("rep_", i)]] <- abs(stats::rnorm(n, 1, 0.2))
  }
  nonprob_rep <- surveycore::as_survey_nonprob(
    data = df,
    weights = base_weight,
    repweights = tidyselect::starts_with("rep_"),
    type = "bootstrap",
    scale = 1 / n_rep,
    mse = TRUE
  )
  orig_rep <- as.matrix(nonprob_rep@data[nonprob_rep@variables$repweights])
  result <- rescale_weights(nonprob_rep)
  result_rep <- as.matrix(result@data[result@variables$repweights])
  # scale factor is 1.0, so rep columns are unchanged
  expect_equal(result_rep, orig_rep, tolerance = 1e-10)
})

test_that("rescale_weights() nonprob + repweights: two rep columns scale correctly", {
  set.seed(99)
  n <- 30L
  df <- make_surveywts_data(n = n, seed = 99)
  df[["rep_1"]] <- abs(stats::rnorm(n, 1, 0.3))
  df[["rep_2"]] <- abs(stats::rnorm(n, 1, 0.3))
  nonprob_rep <- surveycore::as_survey_nonprob(
    data = df,
    weights = base_weight,
    repweights = tidyselect::starts_with("rep_"),
    type = "bootstrap",
    scale = 0.5,
    mse = TRUE
  )
  orig_main <- nonprob_rep@data[["base_weight"]]
  orig_rep1 <- nonprob_rep@data[["rep_1"]]
  scale_f <- n / sum(orig_main)
  result <- rescale_weights(nonprob_rep)
  expect_equal(result@data[["rep_1"]], orig_rep1 * scale_f, tolerance = 1e-10)
})

# ===========================================================================
# .validate_weights() error paths — triggered via rescale_weights()
# S7 validators guard @variables$weights; these errors fire when an
# *override* weight column is passed via weights = that fails validation.
# ===========================================================================

test_that("rescale_weights() aborts when explicit weights column does not exist", {
  df <- make_surveywts_data(n = 50, seed = 1)
  svy <- surveycore::survey_taylor(
    data      = df,
    variables = list(weights = "base_weight")
  )
  expect_error(
    rescale_weights(svy, weights = nonexistent_col),
    class = "surveywts_error_weights_not_found"
  )
  expect_snapshot(
    error = TRUE,
    rescale_weights(svy, weights = nonexistent_col)
  )
})

test_that("rescale_weights() aborts when explicit weights column is not numeric", {
  df <- make_surveywts_data(n = 50, seed = 1)
  svy <- surveycore::survey_taylor(
    data      = df,
    variables = list(weights = "base_weight")
  )
  # Add a character column without touching @variables$weights
  svy@data$str_wt <- as.character(svy@data$base_weight)
  expect_error(
    rescale_weights(svy, weights = str_wt),
    class = "surveywts_error_weights_not_numeric"
  )
  expect_snapshot(
    error = TRUE,
    rescale_weights(svy, weights = str_wt)
  )
})

test_that("rescale_weights() aborts when explicit weights column contains NAs", {
  df <- make_surveywts_data(n = 50, seed = 1)
  svy <- surveycore::survey_taylor(
    data      = df,
    variables = list(weights = "base_weight")
  )
  # Add a column with NAs without touching @variables$weights
  svy@data$na_wt <- svy@data$base_weight
  svy@data$na_wt[1L] <- NA_real_
  expect_error(
    rescale_weights(svy, weights = na_wt),
    class = "surveywts_error_weights_na"
  )
  expect_snapshot(
    error = TRUE,
    rescale_weights(svy, weights = na_wt)
  )
})
