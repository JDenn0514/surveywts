# tests/testthat/test-06-diagnostics.R
#
# Tests for effective_sample_size(), weight_variability(), summarize_weights()
# Per spec §XIII diagnostics items 1, 1b, 2, 3, 3b, 4, 5, 5b, 6, 7, 7b, 7c, 7d, 8
# Per impl plan PR 9 acceptance criteria
#
# All error path tests use the dual pattern:
#   expect_error(class = ...) + expect_snapshot(error = TRUE, ...)

# ---------------------------------------------------------------------------
# Local helpers
# ---------------------------------------------------------------------------

.make_test_taylor_diag <- function(df, weight_col = "base_weight") {
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

# ---------------------------------------------------------------------------
# 1. Correct value vs hand calculation
# ---------------------------------------------------------------------------

test_that("effective_sample_size() computes correct ESS vs hand calculation", {
  w <- c(1.2, 0.8, 1.5, 0.9, 1.1)
  df <- data.frame(y = 1:5, w = w, stringsAsFactors = FALSE)

  expected_ess <- sum(w)^2 / sum(w^2)
  result <- effective_sample_size(df, weights = w)

  expect_equal(result[["n_eff"]], expected_ess, tolerance = 1e-10)
  expect_identical(names(result), "n_eff")
})

test_that("weight_variability() computes correct CV vs hand calculation", {
  w <- c(1.2, 0.8, 1.5, 0.9, 1.1)
  df <- data.frame(y = 1:5, w = w, stringsAsFactors = FALSE)

  expected_cv <- stats::sd(w) / mean(w)
  result <- weight_variability(df, weights = w)

  expect_equal(result[["cv"]], expected_cv, tolerance = 1e-10)
  expect_identical(names(result), "cv")
})

# ---------------------------------------------------------------------------
# 1b. All-equal weights — ESS = n exactly, CV = 0 exactly
# ---------------------------------------------------------------------------

test_that("effective_sample_size() returns ESS = n exactly for equal weights", {
  n <- 100L
  df <- data.frame(y = seq_len(n), w = rep(1, n), stringsAsFactors = FALSE)

  result <- effective_sample_size(df, weights = w)
  expect_equal(result[["n_eff"]], n, tolerance = 1e-10)
})

test_that("weight_variability() returns CV = 0 exactly for equal weights", {
  n <- 100L
  df <- data.frame(y = seq_len(n), w = rep(1, n), stringsAsFactors = FALSE)

  result <- weight_variability(df, weights = w)
  expect_equal(result[["cv"]], 0, tolerance = 1e-10)
})

# ---------------------------------------------------------------------------
# 2. Auto-detected weights for weighted_df input
# ---------------------------------------------------------------------------

test_that("effective_sample_size() auto-detects weights from weighted_df", {
  df <- make_surveywts_data(seed = 1)
  pop_age <- c("18-34" = 1 / 3, "35-54" = 1 / 3, "55+" = 1 / 3)
  wdf <- calibrate(df, variables = c(age_group), population = list(age_group = pop_age))

  # Auto-detection (no weights arg)
  result_auto <- effective_sample_size(wdf)
  # Explicit weight column
  result_explicit <- effective_sample_size(wdf, weights = .weight)

  expect_equal(result_auto, result_explicit, tolerance = 1e-10)
  expect_true(result_auto[["n_eff"]] > 0)
})

test_that("weight_variability() auto-detects weights from weighted_df", {
  df <- make_surveywts_data(seed = 2)
  pop_age <- c("18-34" = 1 / 3, "35-54" = 1 / 3, "55+" = 1 / 3)
  wdf <- calibrate(df, variables = c(age_group), population = list(age_group = pop_age))

  result_auto <- weight_variability(wdf)
  result_explicit <- weight_variability(wdf, weights = .weight)

  expect_equal(result_auto, result_explicit, tolerance = 1e-10)
})

# ---------------------------------------------------------------------------
# 3. Auto-detected weights for survey_calibrated input
# ---------------------------------------------------------------------------

test_that("effective_sample_size() auto-detects weights from survey_calibrated", {
  df <- make_surveywts_data(seed = 3)
  svy <- .make_test_taylor_diag(df)
  pop_age <- c("18-34" = 1 / 3, "35-54" = 1 / 3, "55+" = 1 / 3)
  svc <- calibrate(svy, variables = c(age_group), population = list(age_group = pop_age))

  result_auto <- effective_sample_size(svc)
  result_explicit <- effective_sample_size(svc, weights = base_weight)

  # Auto-detection reads @variables$weights
  expect_equal(result_auto[["n_eff"]], result_explicit[["n_eff"]], tolerance = 1e-10)
  expect_true(result_auto[["n_eff"]] > 0)
})

# ---------------------------------------------------------------------------
# 3b. Auto-detected weights for survey_taylor input
# ---------------------------------------------------------------------------

test_that("effective_sample_size() auto-detects weights from survey_taylor", {
  df <- make_surveywts_data(seed = 4)
  svy <- .make_test_taylor_diag(df, weight_col = "base_weight")

  # Auto-detection reads @variables$weights = "base_weight"
  result_auto <- effective_sample_size(svy)
  result_explicit <- effective_sample_size(svy, weights = base_weight)

  expect_equal(result_auto, result_explicit, tolerance = 1e-10)
  expect_true(result_auto[["n_eff"]] > 0)
})

# ---------------------------------------------------------------------------
# 4. summarize_weights — by = NULL returns single-row tibble
# ---------------------------------------------------------------------------

test_that("summarize_weights() returns single-row tibble when by = NULL", {
  df <- make_surveywts_data(seed = 5)

  result <- summarize_weights(df, weights = base_weight)

  expect_true(tibble::is_tibble(result))
  expect_equal(nrow(result), 1L)
})

# ---------------------------------------------------------------------------
# 5. summarize_weights — by grouping returns correct number of rows
# ---------------------------------------------------------------------------

test_that("summarize_weights() returns one row per group with by grouping", {
  df <- make_surveywts_data(seed = 6)

  result <- summarize_weights(df, weights = base_weight, by = c(age_group))

  n_age_groups <- length(unique(df$age_group))
  expect_equal(nrow(result), n_age_groups)
  expect_true(tibble::is_tibble(result))
  expect_true("age_group" %in% names(result))
})

# ---------------------------------------------------------------------------
# 5b. Error — unsupported_class (matrix or list input)
# ---------------------------------------------------------------------------

test_that("effective_sample_size() throws unsupported_class for matrix input", {
  m <- matrix(1:6, nrow = 3)

  expect_error(
    effective_sample_size(m),
    class = "surveywts_error_unsupported_class"
  )
  expect_snapshot(error = TRUE, effective_sample_size(m))
})

test_that("weight_variability() throws unsupported_class for list input", {
  x <- list(w = c(1, 2, 3))

  expect_error(
    weight_variability(x),
    class = "surveywts_error_unsupported_class"
  )
  expect_snapshot(error = TRUE, weight_variability(x))
})

# ---------------------------------------------------------------------------
# 6. Error — weights_required (plain df, no weights arg)
# ---------------------------------------------------------------------------

test_that("effective_sample_size() throws weights_required for plain df with no weights", {
  df <- data.frame(x = 1:5, w = c(1.2, 0.8, 1.5, 0.9, 1.1))

  expect_error(
    effective_sample_size(df),
    class = "surveywts_error_weights_required"
  )
  expect_snapshot(error = TRUE, effective_sample_size(df))
})

test_that("summarize_weights() throws weights_required for plain df with no weights", {
  df <- data.frame(x = 1:5, w = c(1.2, 0.8, 1.5, 0.9, 1.1))

  expect_error(
    summarize_weights(df),
    class = "surveywts_error_weights_required"
  )
  expect_snapshot(error = TRUE, summarize_weights(df))
})

# ---------------------------------------------------------------------------
# 7. Error — weights_not_found (named column missing from data)
# ---------------------------------------------------------------------------

test_that("effective_sample_size() throws weights_not_found for missing column", {
  df <- data.frame(x = 1:5)

  expect_error(
    effective_sample_size(df, weights = nonexistent_col),
    class = "surveywts_error_weights_not_found"
  )
  expect_snapshot(error = TRUE, effective_sample_size(df, weights = nonexistent_col))
})

# ---------------------------------------------------------------------------
# 7b. Error — weights_not_numeric
# ---------------------------------------------------------------------------

test_that("effective_sample_size() throws weights_not_numeric for character weight column", {
  df <- data.frame(
    x = 1:5,
    w = c("1.2", "0.8", "1.5", "0.9", "1.1"),
    stringsAsFactors = FALSE
  )

  expect_error(
    effective_sample_size(df, weights = w),
    class = "surveywts_error_weights_not_numeric"
  )
  expect_snapshot(error = TRUE, effective_sample_size(df, weights = w))
})

# ---------------------------------------------------------------------------
# 7c. Error — weights_nonpositive
# ---------------------------------------------------------------------------

test_that("effective_sample_size() throws weights_nonpositive for zero weight value", {
  df <- data.frame(x = 1:5, w = c(1.0, 0.0, 1.5, 0.9, 1.1))

  expect_error(
    effective_sample_size(df, weights = w),
    class = "surveywts_error_weights_nonpositive"
  )
  expect_snapshot(error = TRUE, effective_sample_size(df, weights = w))
})

# ---------------------------------------------------------------------------
# 7d. Error — weights_na
# ---------------------------------------------------------------------------

test_that("effective_sample_size() throws weights_na for NA in weight column", {
  df <- data.frame(x = 1:5, w = c(1.0, NA, 1.5, 0.9, 1.1))

  expect_error(
    effective_sample_size(df, weights = w),
    class = "surveywts_error_weights_na"
  )
  expect_snapshot(error = TRUE, effective_sample_size(df, weights = w))
})

# ---------------------------------------------------------------------------
# 8. summarize_weights() output has correct columns in specified order
# ---------------------------------------------------------------------------

test_that("summarize_weights() returns columns in correct order (no by)", {
  df <- make_surveywts_data(seed = 7)

  result <- summarize_weights(df, weights = base_weight)

  expect_identical(
    names(result),
    c("n", "n_positive", "n_zero", "mean", "cv", "min", "p25", "p50", "p75", "max", "ess")
  )
})

test_that("summarize_weights() returns group columns first with by grouping", {
  df <- make_surveywts_data(seed = 8)

  result <- summarize_weights(df, weights = base_weight, by = c(age_group))

  expect_identical(
    names(result),
    c("age_group", "n", "n_positive", "n_zero", "mean", "cv",
      "min", "p25", "p50", "p75", "max", "ess")
  )
})
