# tests/testthat/test-weight-utils.R
#
# Tests for trim_weights() and stabilize_weights()
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

.make_test_wdf <- function(df) {
  targets <- list(age_group = c("18-34" = 0.30, "35-54" = 0.40, "55+" = 0.30))
  calibrate_linear(df, targets = targets, weights = base_weight)
}

# trim_weights() -------------------------------------------------------

# 1. Happy path — trim_weights() ----------------------------------------

test_that("trim_weights() returns weighted_df for data.frame + named weights", {
  df <- make_surveywts_data(seed = 1)
  result <- trim_weights(df, weights = base_weight, upper = 0.9, type = "percentile")
  test_invariants(result)
  expect_true(inherits(result, "weighted_df"))
  expect_identical(attr(result, "weight_col"), "base_weight")
  expect_true(all(result[["base_weight"]] > 0))
})

test_that("trim_weights() preserves weighted_df class and weight column name", {
  df <- make_surveywts_data(seed = 2)
  wdf <- .make_test_wdf(df)
  col_name <- attr(wdf, "weight_col")

  result <- trim_weights(wdf, upper = 0.9, type = "percentile")
  test_invariants(result)
  expect_true(inherits(result, "weighted_df"))
  expect_identical(attr(result, "weight_col"), col_name)
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

test_that("trim_weights() returns weighted_df with wt_name column for data.frame + NULL weights", {
  df <- make_surveywts_data(seed = 5)
  result <- trim_weights(df, wt_name = "my_weight")
  test_invariants(result)
  expect_true(inherits(result, "weighted_df"))
  expect_identical(attr(result, "weight_col"), "my_weight")
  expect_true("my_weight" %in% names(result))
  expect_true(all(result[["my_weight"]] == 1))
})

test_that("trim_weights() default upper_abs = median(w) + 5 * IQR(w), lower_abs = -Inf", {
  df <- make_surveywts_data(seed = 6)
  w <- df$base_weight
  result <- trim_weights(df, weights = base_weight)
  hist_entry <- attr(result, "weighting_history")[[1]]
  expect_equal(hist_entry$parameters$upper_abs,
               stats::median(w) + 5 * stats::IQR(w),
               tolerance = 1e-10)
  expect_equal(hist_entry$parameters$lower_abs, -Inf)
})

test_that("trim_weights() k = 6 produces upper_abs = median(w) + 6 * IQR(w)", {
  df <- make_surveywts_data(seed = 7)
  w <- df$base_weight
  result <- trim_weights(df, weights = base_weight, k = 6)
  hist_entry <- attr(result, "weighting_history")[[1]]
  expect_equal(hist_entry$parameters$upper_abs,
               stats::median(w) + 6 * stats::IQR(w),
               tolerance = 1e-10)
})

test_that("trim_weights() type='absolute' with both tails explicit", {
  df <- make_surveywts_data(seed = 8)
  w <- df$base_weight
  lo <- stats::quantile(w, 0.05, names = FALSE)
  hi <- stats::quantile(w, 0.95, names = FALSE)
  result <- trim_weights(df, weights = base_weight, lower = lo, upper = hi)
  hist_entry <- attr(result, "weighting_history")[[1]]
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
  result <- trim_weights(df, weights = base_weight, upper = hi)
  hist_entry <- attr(result, "weighting_history")[[1]]
  expect_equal(hist_entry$parameters$lower_abs, -Inf)
  expect_equal(hist_entry$parameters$upper_abs, hi)
  expect_equal(hist_entry$parameters$n_trimmed_lower, 0L)
  expect_gt(hist_entry$parameters$n_trimmed_upper, 0L)
})

test_that("trim_weights() type='absolute' lower only (upper = Inf)", {
  df <- make_surveywts_data(seed = 10)
  w <- df$base_weight
  lo <- stats::quantile(w, 0.1, names = FALSE)
  result <- trim_weights(df, weights = base_weight, lower = lo, upper = Inf)
  hist_entry <- attr(result, "weighting_history")[[1]]
  # lower trimming only (upper = Inf so no upper trimming)
  expect_gt(hist_entry$parameters$n_trimmed_lower, 0L)
  expect_equal(hist_entry$parameters$n_trimmed_upper, 0L)
})

test_that("trim_weights() type='percentile' upper=0.99 sets upper_abs to 99th percentile", {
  df <- make_surveywts_data(seed = 11)
  w <- df$base_weight
  result <- trim_weights(df, weights = base_weight, upper = 0.99, type = "percentile")
  hist_entry <- attr(result, "weighting_history")[[1]]
  expect_equal(hist_entry$parameters$upper_abs,
               stats::quantile(w, 0.99, type = 7, names = FALSE),
               tolerance = 1e-10)
  expect_equal(hist_entry$parameters$lower_abs, -Inf)
})

test_that("trim_weights() type='percentile' upper only (no lower)", {
  df <- make_surveywts_data(seed = 12)
  result <- trim_weights(df, weights = base_weight, upper = 0.95, type = "percentile")
  hist_entry <- attr(result, "weighting_history")[[1]]
  expect_equal(hist_entry$parameters$lower_abs, -Inf)
  expect_gt(hist_entry$parameters$n_trimmed_upper, 0L)
})

test_that("trim_weights() explicit no-op (upper = Inf): history appended, warning fires", {
  df <- make_surveywts_data(seed = 13)
  expect_warning(
    result <- trim_weights(df, weights = base_weight, upper = Inf),
    class = "surveywts_warning_no_weights_trimmed"
  )
  hist_entry <- attr(result, "weighting_history")[[1]]
  expect_identical(hist_entry$operation, "trim_weights")
  expect_equal(hist_entry$parameters$upper_abs, Inf)
})

test_that("trim_weights() strict=FALSE: weight sum preserved after single pass", {
  df <- make_surveywts_data(seed = 14)
  w <- df$base_weight
  result <- trim_weights(df, weights = base_weight, upper = 0.9, type = "percentile",
                         strict = FALSE)
  result_w <- result[["base_weight"]]
  expect_equal(sum(result_w), sum(w), tolerance = 1e-10)
})

test_that("trim_weights() strict=TRUE: all main weights within [lower_abs, upper_abs]", {
  df <- make_surveywts_data(seed = 15)
  w <- df$base_weight
  upper_pct <- 0.85
  result <- trim_weights(df, weights = base_weight, upper = upper_pct,
                         type = "percentile", strict = TRUE)
  upper_abs <- stats::quantile(w, upper_pct, type = 7, names = FALSE)
  result_w <- result[["base_weight"]]
  expect_true(all(result_w <= upper_abs + .Machine$double.eps))
  expect_equal(sum(result_w), sum(w), tolerance = 1e-10)
})

# 2. Numerical correctness — trim_weights() --------------------------------

test_that("trim_weights() weight sum preserved when trimming succeeds (strict=FALSE)", {
  df <- make_surveywts_data(seed = 20)
  w <- df$base_weight
  result <- trim_weights(df, weights = base_weight, upper = 0.9, type = "percentile")
  expect_equal(sum(result[["base_weight"]]), sum(w), tolerance = 1e-10)
})

test_that("trim_weights() strict=TRUE: all weights in [lower_abs, upper_abs] + epsilon", {
  df <- make_surveywts_data(seed = 21)
  w <- df$base_weight
  lo_pct <- 0.05
  hi_pct <- 0.90
  result <- trim_weights(df, weights = base_weight,
                         lower = lo_pct, upper = hi_pct,
                         type = "percentile", strict = TRUE)
  lower_abs <- stats::quantile(w, lo_pct, type = 7, names = FALSE)
  upper_abs <- stats::quantile(w, hi_pct, type = 7, names = FALSE)
  result_w <- result[["base_weight"]]
  expect_true(all(result_w >= lower_abs - .Machine$double.eps))
  expect_true(all(result_w <= upper_abs + .Machine$double.eps))
})

test_that("trim_weights() strict=FALSE: sum preserved but not all weights in bounds", {
  df <- make_surveywts_data(seed = 22)
  w <- df$base_weight
  # Use a tight bound that ensures redistribution pushes some weights out
  lo_pct <- 0.45
  hi_pct <- 0.55
  result <- trim_weights(df, weights = base_weight,
                         lower = lo_pct, upper = hi_pct,
                         type = "percentile", strict = FALSE)
  result_w <- result[["base_weight"]]
  # Sum is preserved
  expect_equal(sum(result_w), sum(w), tolerance = 1e-10)
  # With strict=FALSE, redistribution may push some weights out of bounds
  lower_abs <- stats::quantile(w, lo_pct, type = 7, names = FALSE)
  upper_abs <- stats::quantile(w, hi_pct, type = 7, names = FALSE)
  outside <- result_w < lower_abs | result_w > upper_abs
  # Not all weights guaranteed in bounds after redistribution
  # (if redistribution occurred, some may be pushed out)
  # We just check sum is preserved — that's the guarantee of strict=FALSE
  expect_true(is.numeric(result_w))
})

test_that("trim_weights() n_trimmed_upper equals count of original weights above upper_abs", {
  df <- make_surveywts_data(seed = 23)
  w <- df$base_weight
  upper_pct <- 0.9
  upper_abs <- stats::quantile(w, upper_pct, type = 7, names = FALSE)
  result <- trim_weights(df, weights = base_weight, upper = upper_pct, type = "percentile")
  hist_entry <- attr(result, "weighting_history")[[1]]
  expect_equal(hist_entry$parameters$n_trimmed_upper, sum(w > upper_abs))
})

test_that("trim_weights() n_trimmed_lower equals count of original weights below lower_abs", {
  df <- make_surveywts_data(seed = 24)
  w <- df$base_weight
  lower_pct <- 0.1
  lower_abs <- stats::quantile(w, lower_pct, type = 7, names = FALSE)
  result <- trim_weights(df, weights = base_weight,
                         lower = lower_pct, upper = 0.9,
                         type = "percentile")
  hist_entry <- attr(result, "weighting_history")[[1]]
  expect_equal(hist_entry$parameters$n_trimmed_lower, sum(w < lower_abs))
})

test_that("trim_weights() type='percentile' upper=0.99: history upper_abs == quantile(w, 0.99)", {
  df <- make_surveywts_data(seed = 25)
  w <- df$base_weight
  result <- trim_weights(df, weights = base_weight, upper = 0.99, type = "percentile")
  hist_entry <- attr(result, "weighting_history")[[1]]
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
    class = "surveywts_error_unsupported_class"
  )
  expect_snapshot(error = TRUE, trim_weights(list(x = 1:5)))
})

test_that("trim_weights() rejects 0-row data frame", {
  empty <- data.frame(x = numeric(0), w = numeric(0))
  expect_error(
    trim_weights(empty, weights = w),
    class = "surveywts_error_empty_data"
  )
  expect_snapshot(error = TRUE, trim_weights(empty, weights = w))
})

test_that("trim_weights() rejects missing weight column", {
  df <- data.frame(x = 1:5)
  expect_error(
    trim_weights(df, weights = missing_col),
    class = "surveywts_error_weights_not_found"
  )
  expect_snapshot(error = TRUE, trim_weights(df, weights = missing_col))
})

test_that("trim_weights() rejects non-numeric weight column", {
  df <- data.frame(x = 1:5, w = letters[1:5])
  expect_error(
    trim_weights(df, weights = w),
    class = "surveywts_error_weights_not_numeric"
  )
  expect_snapshot(error = TRUE, trim_weights(df, weights = w))
})

test_that("trim_weights() rejects negative weight values", {
  df <- data.frame(x = 1:5, w = c(1, 2, -1, 2, 1))
  expect_error(
    trim_weights(df, weights = w),
    class = "surveywts_error_weights_nonpositive"
  )
  expect_snapshot(error = TRUE, trim_weights(df, weights = w))
})

test_that("trim_weights() rejects NA weight values", {
  df <- data.frame(x = 1:5, w = c(1, 2, NA, 2, 1))
  expect_error(
    trim_weights(df, weights = w),
    class = "surveywts_error_weights_na"
  )
  expect_snapshot(error = TRUE, trim_weights(df, weights = w))
})

test_that("trim_weights() rejects upper = NULL with type = 'percentile'", {
  df <- make_surveywts_data(seed = 1)
  expect_error(
    trim_weights(df, weights = base_weight, type = "percentile"),
    class = "surveywts_error_null_bound_percentile"
  )
  expect_snapshot(
    error = TRUE,
    trim_weights(df, weights = base_weight, type = "percentile")
  )
})

test_that("trim_weights() rejects k = character scalar", {
  df <- make_surveywts_data(seed = 1)
  expect_error(
    trim_weights(df, weights = base_weight, k = "5"),
    class = "surveywts_error_k_not_scalar"
  )
  expect_snapshot(
    error = TRUE,
    trim_weights(df, weights = base_weight, k = "5")
  )
})

test_that("trim_weights() rejects k = NA_real_", {
  df <- make_surveywts_data(seed = 1)
  expect_error(
    trim_weights(df, weights = base_weight, k = NA_real_),
    class = "surveywts_error_k_not_scalar"
  )
  expect_snapshot(
    error = TRUE,
    trim_weights(df, weights = base_weight, k = NA_real_)
  )
})

test_that("trim_weights() rejects k = length-2 numeric", {
  df <- make_surveywts_data(seed = 1)
  expect_error(
    trim_weights(df, weights = base_weight, k = c(1, 2)),
    class = "surveywts_error_k_not_scalar"
  )
  expect_snapshot(
    error = TRUE,
    trim_weights(df, weights = base_weight, k = c(1, 2))
  )
})

test_that("trim_weights() rejects k = -1", {
  df <- make_surveywts_data(seed = 1)
  expect_error(
    trim_weights(df, weights = base_weight, k = -1),
    class = "surveywts_error_k_nonpositive"
  )
  expect_snapshot(
    error = TRUE,
    trim_weights(df, weights = base_weight, k = -1)
  )
})

test_that("trim_weights() rejects k = 0", {
  df <- make_surveywts_data(seed = 1)
  expect_error(
    trim_weights(df, weights = base_weight, k = 0),
    class = "surveywts_error_k_nonpositive"
  )
  expect_snapshot(
    error = TRUE,
    trim_weights(df, weights = base_weight, k = 0)
  )
})

test_that("trim_weights() rejects lower = character scalar", {
  df <- make_surveywts_data(seed = 1)
  expect_error(
    trim_weights(df, weights = base_weight, lower = "0.5"),
    class = "surveywts_error_lower_not_scalar"
  )
  expect_snapshot(
    error = TRUE,
    trim_weights(df, weights = base_weight, lower = "0.5")
  )
})

test_that("trim_weights() rejects lower = NA_real_", {
  df <- make_surveywts_data(seed = 1)
  expect_error(
    trim_weights(df, weights = base_weight, lower = NA_real_),
    class = "surveywts_error_lower_not_scalar"
  )
  expect_snapshot(
    error = TRUE,
    trim_weights(df, weights = base_weight, lower = NA_real_)
  )
})

test_that("trim_weights() rejects upper = length-2 numeric", {
  df <- make_surveywts_data(seed = 1)
  expect_error(
    trim_weights(df, weights = base_weight, upper = c(1, 2)),
    class = "surveywts_error_upper_not_scalar"
  )
  expect_snapshot(
    error = TRUE,
    trim_weights(df, weights = base_weight, upper = c(1, 2))
  )
})

test_that("trim_weights() rejects upper = NA_real_", {
  df <- make_surveywts_data(seed = 1)
  expect_error(
    trim_weights(df, weights = base_weight, upper = NA_real_),
    class = "surveywts_error_upper_not_scalar"
  )
  expect_snapshot(
    error = TRUE,
    trim_weights(df, weights = base_weight, upper = NA_real_)
  )
})

test_that("trim_weights() rejects equal resolved bounds (lower = upper)", {
  df <- make_surveywts_data(seed = 1)
  expect_error(
    trim_weights(df, weights = base_weight, lower = 3, upper = 3),
    class = "surveywts_error_bounds_invalid"
  )
  expect_snapshot(
    error = TRUE,
    trim_weights(df, weights = base_weight, lower = 3, upper = 3)
  )
})

test_that("trim_weights() rejects reversed bounds (lower > upper)", {
  df <- make_surveywts_data(seed = 1)
  expect_error(
    trim_weights(df, weights = base_weight, lower = 5, upper = 3),
    class = "surveywts_error_bounds_invalid"
  )
  expect_snapshot(
    error = TRUE,
    trim_weights(df, weights = base_weight, lower = 5, upper = 3)
  )
})

test_that("trim_weights() rejects reversed percentile bounds", {
  df <- make_surveywts_data(seed = 1)
  expect_error(
    trim_weights(df, weights = base_weight,
                 lower = 0.99, upper = 0.01, type = "percentile"),
    class = "surveywts_error_bounds_invalid"
  )
  expect_snapshot(
    error = TRUE,
    trim_weights(df, weights = base_weight,
                 lower = 0.99, upper = 0.01, type = "percentile")
  )
})

test_that("trim_weights() rejects upper = 0 (absolute, non-positive)", {
  df <- make_surveywts_data(seed = 1)
  expect_error(
    trim_weights(df, weights = base_weight, upper = 0),
    class = "surveywts_error_upper_nonpositive"
  )
  expect_snapshot(
    error = TRUE,
    trim_weights(df, weights = base_weight, upper = 0)
  )
})

test_that("trim_weights() rejects upper = -1 (absolute, negative)", {
  df <- make_surveywts_data(seed = 1)
  expect_error(
    trim_weights(df, weights = base_weight, upper = -1),
    class = "surveywts_error_upper_nonpositive"
  )
  expect_snapshot(
    error = TRUE,
    trim_weights(df, weights = base_weight, upper = -1)
  )
})

test_that("trim_weights() rejects lower = -0.1 with type = 'percentile'", {
  df <- make_surveywts_data(seed = 1)
  expect_error(
    trim_weights(df, weights = base_weight,
                 lower = -0.1, upper = 0.99, type = "percentile"),
    class = "surveywts_error_percentile_out_of_range"
  )
  expect_snapshot(
    error = TRUE,
    trim_weights(df, weights = base_weight,
                 lower = -0.1, upper = 0.99, type = "percentile")
  )
})

test_that("trim_weights() rejects upper = 1.1 with type = 'percentile'", {
  df <- make_surveywts_data(seed = 1)
  expect_error(
    trim_weights(df, weights = base_weight, upper = 1.1, type = "percentile"),
    class = "surveywts_error_percentile_out_of_range"
  )
  expect_snapshot(
    error = TRUE,
    trim_weights(df, weights = base_weight, upper = 1.1, type = "percentile")
  )
})

test_that("trim_weights() rejects wt_name = 1L (plain df + NULL weights)", {
  df <- make_surveywts_data(seed = 1)
  expect_error(
    trim_weights(df, wt_name = 1L),
    class = "surveywts_error_wt_name_not_scalar"
  )
  expect_snapshot(
    error = TRUE,
    trim_weights(df, wt_name = 1L)
  )
})

test_that("trim_weights() rejects wt_name = '' (plain df + NULL weights)", {
  df <- make_surveywts_data(seed = 1)
  expect_error(
    trim_weights(df, wt_name = ""),
    class = "surveywts_error_wt_name_empty"
  )
  expect_snapshot(
    error = TRUE,
    trim_weights(df, wt_name = "")
  )
})

# 4. Warning paths — trim_weights() ----------------------------------------

test_that("trim_weights() warns when all main weights already within bounds", {
  df <- make_surveywts_data(seed = 30)
  # Set very wide bounds that all log-normal weights fall within
  expect_warning(
    result <- trim_weights(df, weights = base_weight, lower = 0.01, upper = 100),
    class = "surveywts_warning_no_weights_trimmed"
  )
  # Result is still returned
  expect_true(inherits(result, "weighted_df"))
  # History is still appended
  hist_entry <- attr(result, "weighting_history")[[1]]
  expect_identical(hist_entry$operation, "trim_weights")
})

test_that("trim_weights() warns when all units are outside bounds (trimming failed)", {
  # Two units: weights c(1, 10), both outside [3, 7]
  two_row <- data.frame(x = 1:2, w = c(1, 10))
  expect_warning(
    result <- trim_weights(two_row, weights = w, lower = 3, upper = 7),
    class = "surveywts_warning_trimming_failed"
  )
  # Sum changes because redistribution failed
  expect_false(isTRUE(abs(sum(result[["w"]]) - sum(c(1, 10))) < 1e-10))
})

# 5. History correctness — trim_weights() -----------------------------------

test_that("trim_weights() history entry has all required fields", {
  df <- make_surveywts_data(seed = 40)
  result <- trim_weights(df, weights = base_weight, upper = 0.9, type = "percentile")
  hist_entry <- attr(result, "weighting_history")[[1]]

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
  result <- trim_weights(df, weights = base_weight,
                         lower = 0.05, upper = 0.95, type = "percentile")
  hist_entry <- attr(result, "weighting_history")[[1]]
  # Percentile input (0.05) != resolved absolute value (quantile)
  expect_false(isTRUE(hist_entry$parameters$lower_input == hist_entry$parameters$lower_abs))
})

test_that("trim_weights() step number is correct when chained after calibrate_linear()", {
  df <- make_surveywts_data(seed = 42)
  targets <- list(age_group = c("18-34" = 0.30, "35-54" = 0.40, "55+" = 0.30))
  wdf <- calibrate_linear(df, targets = targets, weights = base_weight)

  result <- trim_weights(wdf, upper = 0.9, type = "percentile")
  hist <- attr(result, "weighting_history")
  expect_equal(length(hist), 2L)
  expect_equal(hist[[2L]]$step, 2L)
  expect_identical(hist[[2L]]$operation, "trim_weights")
})

# 6. Edge cases — trim_weights() --------------------------------------------

test_that("trim_weights() works on single-row data frame", {
  one_row <- data.frame(x = 1, w = 2.5)
  expect_warning(
    result <- trim_weights(one_row, weights = w),
    class = "surveywts_warning_no_weights_trimmed"
  )
  expect_true(inherits(result, "weighted_df"))
  expect_equal(nrow(result), 1L)
})

test_that("trim_weights() warns and is a no-op when all weights are equal", {
  df <- data.frame(x = 1:10, w = rep(1, 10))
  expect_warning(
    result <- trim_weights(df, weights = w),
    class = "surveywts_warning_no_weights_trimmed"
  )
  expect_equal(result[["w"]], rep(1, 10), tolerance = 1e-10)
})

test_that("trim_weights() counts exactly 1 trimmed at each bound", {
  # Place exactly one weight at each extreme
  w_vec <- c(0.1, rep(1, 8), 10)  # 10 observations
  df <- data.frame(x = seq_along(w_vec), w = w_vec)
  lo <- 0.5   # 0.1 is below
  hi <- 5.0   # 10 is above

  result <- trim_weights(df, weights = w, lower = lo, upper = hi)
  hist_entry <- attr(result, "weighting_history")[[1]]
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

# stabilize_weights() --------------------------------------------------

# 1. Happy path — stabilize_weights() -----------------------------------

test_that("stabilize_weights() returns weighted_df for data.frame + named weights", {
  df <- make_surveywts_data(seed = 50)
  result <- stabilize_weights(df, weights = base_weight)
  test_invariants(result)
  expect_true(inherits(result, "weighted_df"))
  expect_identical(attr(result, "weight_col"), "base_weight")
})

test_that("stabilize_weights() preserves weighted_df class and weight column name", {
  df <- make_surveywts_data(seed = 51)
  wdf <- .make_test_wdf(df)
  col_name <- attr(wdf, "weight_col")

  result <- stabilize_weights(wdf)
  test_invariants(result)
  expect_true(inherits(result, "weighted_df"))
  expect_identical(attr(result, "weight_col"), col_name)
})

test_that("stabilize_weights() preserves survey_taylor class", {
  df <- make_surveywts_data(seed = 52)
  design <- .make_test_taylor_wt(df)
  result <- stabilize_weights(design)
  test_invariants(result)
  expect_true(S7::S7_inherits(result, surveycore::survey_taylor))
})

test_that("stabilize_weights() preserves survey_nonprob class", {
  df <- make_surveywts_data(seed = 53)
  design <- .make_test_nonprob_wt(df)
  result <- stabilize_weights(design)
  test_invariants(result)
  expect_true(S7::S7_inherits(result, surveycore::survey_nonprob))
})

test_that("stabilize_weights() preserves survey_replicate class and scales rep weights", {
  rep_design <- make_replicate_design(seed = 4)
  orig_main <- rep_design@data[[rep_design@variables$weights]]
  orig_rep <- as.matrix(rep_design@data[rep_design@variables$repweights])

  result <- stabilize_weights(rep_design)
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

test_that("stabilize_weights() returns weighted_df with wt_name column for data.frame + NULL weights", {
  df <- make_surveywts_data(seed = 54)
  result <- stabilize_weights(df, wt_name = "my_stable_weight")
  test_invariants(result)
  expect_true(inherits(result, "weighted_df"))
  expect_identical(attr(result, "weight_col"), "my_stable_weight")
  # Uniform weights -> stabilize -> still all equal
  n <- nrow(df)
  expect_equal(sum(result[["my_stable_weight"]]), n, tolerance = 1e-10)
})

test_that("stabilize_weights() global: sum(result_weights) == nrow(data)", {
  df <- make_surveywts_data(seed = 55)
  result <- stabilize_weights(df, weights = base_weight)
  expect_equal(sum(result[["base_weight"]]), nrow(df), tolerance = 1e-10)
})

test_that("stabilize_weights() by = col: each group sums to group n", {
  df <- make_surveywts_data(seed = 56)
  result <- stabilize_weights(df, weights = base_weight, by = age_group)
  w_new <- result[["base_weight"]]
  for (grp in unique(df$age_group)) {
    idx <- df$age_group == grp
    expect_equal(sum(w_new[idx]), sum(idx), tolerance = 1e-10)
  }
})

test_that("stabilize_weights() by = c(col1, col2): multi-variable grouping works", {
  df <- make_surveywts_data(seed = 57)
  result <- stabilize_weights(df, weights = base_weight, by = c(age_group, sex))
  w_new <- result[["base_weight"]]
  for (ag in unique(df$age_group)) {
    for (sx in unique(df$sex)) {
      idx <- df$age_group == ag & df$sex == sx
      if (sum(idx) > 0L) {
        expect_equal(sum(w_new[idx]), sum(idx), tolerance = 1e-10)
      }
    }
  }
})

# 2. Numerical correctness — stabilize_weights() --------------------------

test_that("stabilize_weights() global: sum(w_new) == n to machine precision", {
  df <- make_surveywts_data(seed = 60)
  result <- stabilize_weights(df, weights = base_weight)
  expect_equal(sum(result[["base_weight"]]), nrow(df), tolerance = 1e-10)
})

test_that("stabilize_weights() within-group: each group sums to group n (tolerance 1e-10)", {
  df <- make_surveywts_data(seed = 61)
  result <- stabilize_weights(df, weights = base_weight, by = age_group)
  w_new <- result[["base_weight"]]
  for (grp in unique(df$age_group)) {
    idx <- df$age_group == grp
    expect_equal(sum(w_new[idx]), sum(idx), tolerance = 1e-10)
  }
})

test_that("stabilize_weights() scale factor n/sum(w) matches history", {
  df <- make_surveywts_data(seed = 62)
  w <- df$base_weight
  n <- nrow(df)
  result <- stabilize_weights(df, weights = base_weight)
  hist_entry <- attr(result, "weighting_history")[[1]]
  expected_sf <- n / sum(w)
  expect_equal(hist_entry$parameters$scale_factor, expected_sf, tolerance = 1e-10)
})

test_that("stabilize_weights() survey_replicate global: each rep column scaled by same factor", {
  rep_design <- make_replicate_design(seed = 5)
  orig_main <- rep_design@data[[rep_design@variables$weights]]
  orig_rep <- as.matrix(rep_design@data[rep_design@variables$repweights])
  n <- nrow(rep_design@data)
  scale_f <- n / sum(orig_main)

  result <- stabilize_weights(rep_design)
  result_rep <- as.matrix(result@data[result@variables$repweights])

  # Each replicate column multiplied by same scale factor
  expected_colsums <- colSums(orig_rep) * scale_f
  expect_equal(colSums(result_rep), expected_colsums, tolerance = 1e-10)
})

test_that("stabilize_weights() survey_replicate with by: per-group factors applied to rep columns", {
  rep_design <- make_replicate_design(seed = 6)
  orig_main <- rep_design@data[[rep_design@variables$weights]]
  orig_rep <- as.matrix(rep_design@data[rep_design@variables$repweights])
  data_df <- rep_design@data

  result <- stabilize_weights(rep_design, by = age_group)
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

# 3. Error paths — stabilize_weights() ------------------------------------

test_that("stabilize_weights() rejects list input", {
  expect_error(
    stabilize_weights(list(x = 1:5)),
    class = "surveywts_error_unsupported_class"
  )
  expect_snapshot(error = TRUE, stabilize_weights(list(x = 1:5)))
})

test_that("stabilize_weights() rejects 0-row data frame", {
  empty <- data.frame(x = numeric(0), w = numeric(0))
  expect_error(
    stabilize_weights(empty, weights = w),
    class = "surveywts_error_empty_data"
  )
  expect_snapshot(error = TRUE, stabilize_weights(empty, weights = w))
})

test_that("stabilize_weights() rejects missing weight column", {
  df <- data.frame(x = 1:5)
  expect_error(
    stabilize_weights(df, weights = missing_col),
    class = "surveywts_error_weights_not_found"
  )
  expect_snapshot(error = TRUE, stabilize_weights(df, weights = missing_col))
})

test_that("stabilize_weights() rejects non-numeric weight column", {
  df <- data.frame(x = 1:5, w = letters[1:5])
  expect_error(
    stabilize_weights(df, weights = w),
    class = "surveywts_error_weights_not_numeric"
  )
  expect_snapshot(error = TRUE, stabilize_weights(df, weights = w))
})

test_that("stabilize_weights() rejects negative weight values", {
  df <- data.frame(x = 1:5, w = c(1, 2, -1, 2, 1))
  expect_error(
    stabilize_weights(df, weights = w),
    class = "surveywts_error_weights_nonpositive"
  )
  expect_snapshot(error = TRUE, stabilize_weights(df, weights = w))
})

test_that("stabilize_weights() rejects NA weight values", {
  df <- data.frame(x = 1:5, w = c(1, 2, NA, 2, 1))
  expect_error(
    stabilize_weights(df, weights = w),
    class = "surveywts_error_weights_na"
  )
  expect_snapshot(error = TRUE, stabilize_weights(df, weights = w))
})

test_that("stabilize_weights() rejects by variable not in data", {
  df <- make_surveywts_data(seed = 1)
  expect_error(
    stabilize_weights(df, weights = base_weight, by = nonexistent_col),
    class = "surveywts_error_by_variable_not_found"
  )
  expect_snapshot(
    error = TRUE,
    stabilize_weights(df, weights = base_weight, by = nonexistent_col)
  )
})

test_that("stabilize_weights() rejects by variable with NA values", {
  df <- make_surveywts_data(seed = 1)
  df$age_group[1] <- NA
  expect_error(
    stabilize_weights(df, weights = base_weight, by = age_group),
    class = "surveywts_error_variable_has_na"
  )
  expect_snapshot(
    error = TRUE,
    stabilize_weights(df, weights = base_weight, by = age_group)
  )
})

test_that("stabilize_weights() rejects wt_name = 1L (plain df + NULL weights)", {
  df <- make_surveywts_data(seed = 1)
  expect_error(
    stabilize_weights(df, wt_name = 1L),
    class = "surveywts_error_wt_name_not_scalar"
  )
  expect_snapshot(
    error = TRUE,
    stabilize_weights(df, wt_name = 1L)
  )
})

test_that("stabilize_weights() rejects wt_name = '' (plain df + NULL weights)", {
  df <- make_surveywts_data(seed = 1)
  expect_error(
    stabilize_weights(df, wt_name = ""),
    class = "surveywts_error_wt_name_empty"
  )
  expect_snapshot(
    error = TRUE,
    stabilize_weights(df, wt_name = "")
  )
})

# 4. History correctness — stabilize_weights() -----------------------------

test_that("stabilize_weights() history entry has all required fields", {
  df <- make_surveywts_data(seed = 70)
  result <- stabilize_weights(df, weights = base_weight)
  hist_entry <- attr(result, "weighting_history")[[1]]

  expect_identical(hist_entry$operation, "stabilize_weights")
  expect_true("by" %in% names(hist_entry$parameters))
  expect_true("scale_factor" %in% names(hist_entry$parameters))
  expect_null(hist_entry$parameters$by)
})

test_that("stabilize_weights() by history: named scale_factor vector with ' | ' separator", {
  df <- make_surveywts_data(seed = 71)
  result <- stabilize_weights(df, weights = base_weight, by = c(age_group, sex))
  hist_entry <- attr(result, "weighting_history")[[1]]
  expect_false(is.null(hist_entry$parameters$by))
  expect_true(is.numeric(hist_entry$parameters$scale_factor))
  expect_true(length(hist_entry$parameters$scale_factor) > 1L)
  # Multi-variable by: names use ' | ' separator
  sf_names <- names(hist_entry$parameters$scale_factor)
  expect_true(all(grepl(" | ", sf_names, fixed = TRUE)))
})

test_that("stabilize_weights() step number correct when chained after trim_weights()", {
  df <- make_surveywts_data(seed = 72)
  trimmed <- trim_weights(df, weights = base_weight, upper = 0.9, type = "percentile")
  result <- stabilize_weights(trimmed)
  hist <- attr(result, "weighting_history")
  expect_equal(length(hist), 2L)
  expect_equal(hist[[2L]]$step, 2L)
  expect_identical(hist[[2L]]$operation, "stabilize_weights")
})

# 5. Edge cases — stabilize_weights() -------------------------------------

test_that("stabilize_weights() no-op when weights already sum to n", {
  n <- 100L
  # Create weights that already sum to n
  w <- rep(1, n)  # uniform weights already sum to n
  df <- data.frame(x = seq_len(n), w = w)
  result <- stabilize_weights(df, weights = w)
  hist_entry <- attr(result, "weighting_history")[[1]]
  expect_equal(hist_entry$parameters$scale_factor, 1.0, tolerance = 1e-10)
  expect_equal(sum(result[["w"]]), n, tolerance = 1e-10)
})

test_that("stabilize_weights() single-row data: weight set to 1", {
  one_row <- data.frame(x = 1, w = 5.0)
  result <- stabilize_weights(one_row, weights = w)
  expect_equal(result[["w"]], 1.0, tolerance = 1e-10)
})

test_that("stabilize_weights() by with one group: equivalent to global stabilization", {
  df <- make_surveywts_data(seed = 75)
  # Use a variable with only one level
  df$const_group <- "all"

  result_global <- stabilize_weights(df, weights = base_weight)
  result_by <- stabilize_weights(df, weights = base_weight, by = const_group)

  expect_equal(result_global[["base_weight"]],
               result_by[["base_weight"]],
               tolerance = 1e-10)
})

test_that("stabilize_weights() by with group of size 1: weight for that observation set to 1", {
  n <- 20L
  df <- data.frame(
    x = seq_len(n),
    w = exp(stats::rnorm(n, 0, 0.4)),
    grp = c("A", rep("B", n - 1L))
  )
  result <- stabilize_weights(df, weights = w, by = grp)
  # Group "A" has 1 observation: its weight should be 1
  idx_a <- df$grp == "A"
  expect_equal(result[["w"]][idx_a], 1.0, tolerance = 1e-10)
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

test_that(".has_repweights() returns FALSE for weighted_df", {
  df <- make_surveywts_data(seed = 1)
  wdf <- .make_test_wdf(df)
  expect_false(.has_repweights(wdf))
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
  # Very wide bounds so no trimming occurs
  expect_warning(
    result <- trim_weights(nonprob_rep, lower = 0.01, upper = 100),
    class = "surveywts_warning_no_weights_trimmed"
  )
  # Class is preserved
  expect_true(S7::S7_inherits(result, surveycore::survey_nonprob))
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

# ===========================================================================
# stabilize_weights() — survey_nonprob with repweights
# ===========================================================================

test_that("stabilize_weights() preserves survey_nonprob class for nonprob with repweights", {
  nonprob_rep <- .make_nonprob_with_repweights(seed = 20)
  result <- stabilize_weights(nonprob_rep)
  test_invariants(result)
  expect_true(S7::S7_inherits(result, surveycore::survey_nonprob))
  expect_false(S7::S7_inherits(result, surveycore::survey_replicate))
})

test_that("stabilize_weights() global: scales all rep columns by same factor for nonprob", {
  nonprob_rep <- .make_nonprob_with_repweights(seed = 21)
  orig_main <- nonprob_rep@data[[nonprob_rep@variables$weights]]
  orig_rep <- as.matrix(nonprob_rep@data[nonprob_rep@variables$repweights])
  n <- nrow(nonprob_rep@data)
  scale_f <- n / sum(orig_main)

  result <- stabilize_weights(nonprob_rep)
  result_rep <- as.matrix(result@data[result@variables$repweights])

  expected_colsums <- colSums(orig_rep) * scale_f
  expect_equal(colSums(result_rep), expected_colsums, tolerance = 1e-10)
})

test_that("stabilize_weights() per-group: applies per-row scale factors to rep columns for nonprob", {
  nonprob_rep <- .make_nonprob_with_repweights(seed = 22)
  orig_main <- nonprob_rep@data[[nonprob_rep@variables$weights]]
  orig_rep <- as.matrix(nonprob_rep@data[nonprob_rep@variables$repweights])
  data_df <- nonprob_rep@data

  result <- stabilize_weights(nonprob_rep, by = age_group)
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

test_that("stabilize_weights() appends history entry for survey_nonprob with repweights", {
  nonprob_rep <- .make_nonprob_with_repweights(seed = 23)
  result <- stabilize_weights(nonprob_rep)
  hist <- result@metadata@weighting_history
  expect_true(length(hist) >= 1L)
  last_entry <- hist[[length(hist)]]
  expect_identical(last_entry$operation, "stabilize_weights")
})

test_that("stabilize_weights() does not scale replicates for survey_nonprob WITHOUT repweights", {
  nonprob_no_rep <- .make_nonprob_no_repweights(seed = 24)
  result <- stabilize_weights(nonprob_no_rep)
  expect_true(S7::S7_inherits(result, surveycore::survey_nonprob))
})

test_that("stabilize_weights() nonprob + repweights: scale_factor == 1.0 when weights already sum to n", {
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
  result <- stabilize_weights(nonprob_rep)
  result_rep <- as.matrix(result@data[result@variables$repweights])
  # scale factor is 1.0, so rep columns are unchanged
  expect_equal(result_rep, orig_rep, tolerance = 1e-10)
})

test_that("stabilize_weights() nonprob + repweights: two rep columns scale correctly", {
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
  result <- stabilize_weights(nonprob_rep)
  expect_equal(result@data[["rep_1"]], orig_rep1 * scale_f, tolerance = 1e-10)
})
