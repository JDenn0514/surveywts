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
  taylor <- .make_test_taylor_diag(df, weight_col = "w")

  expected_ess <- sum(w)^2 / sum(w^2)
  result <- effective_sample_size(taylor)

  expect_equal(result[["n_eff"]], expected_ess, tolerance = 1e-10)
  expect_identical(names(result), "n_eff")
})

test_that("weight_variability() computes correct CV vs hand calculation", {
  w <- c(1.2, 0.8, 1.5, 0.9, 1.1)
  df <- data.frame(y = 1:5, w = w, stringsAsFactors = FALSE)
  taylor <- .make_test_taylor_diag(df, weight_col = "w")

  expected_cv <- stats::sd(w) / mean(w)
  result <- weight_variability(taylor)

  expect_equal(result[["cv"]], expected_cv, tolerance = 1e-10)
  expect_identical(names(result), "cv")
})

# ---------------------------------------------------------------------------
# 1b. All-equal weights — ESS = n exactly, CV = 0 exactly
# ---------------------------------------------------------------------------

test_that("effective_sample_size() returns ESS = n exactly for equal weights", {
  n <- 100L
  df <- data.frame(y = seq_len(n), w = rep(1, n), stringsAsFactors = FALSE)
  taylor <- .make_test_taylor_diag(df, weight_col = "w")

  result <- effective_sample_size(taylor)
  expect_equal(result[["n_eff"]], n, tolerance = 1e-10)
})

test_that("weight_variability() returns CV = 0 exactly for equal weights", {
  n <- 100L
  df <- data.frame(y = seq_len(n), w = rep(1, n), stringsAsFactors = FALSE)
  taylor <- .make_test_taylor_diag(df, weight_col = "w")

  result <- weight_variability(taylor)
  expect_equal(result[["cv"]], 0, tolerance = 1e-10)
})

# ---------------------------------------------------------------------------
# 2. Error — not_survey_base (plain data.frame input)
# ---------------------------------------------------------------------------

test_that("effective_sample_size() throws not_survey_base for plain data.frame input", {
  df <- data.frame(x = 1:5, w = c(1.2, 0.8, 1.5, 0.9, 1.1))

  expect_error(
    effective_sample_size(df),
    class = "surveywts_error_not_survey_base"
  )
  expect_snapshot(error = TRUE, effective_sample_size(df))
})

test_that("weight_variability() throws not_survey_base for plain data.frame input", {
  df <- data.frame(x = 1:5, w = c(1.2, 0.8, 1.5, 0.9, 1.1))

  expect_error(
    weight_variability(df),
    class = "surveywts_error_not_survey_base"
  )
  expect_snapshot(error = TRUE, weight_variability(df))
})

test_that("summarize_weights() throws not_survey_base for plain data.frame input", {
  df <- data.frame(x = 1:5, w = c(1.2, 0.8, 1.5, 0.9, 1.1))

  expect_error(
    summarize_weights(df),
    class = "surveywts_error_not_survey_base"
  )
  expect_snapshot(error = TRUE, summarize_weights(df))
})

# ---------------------------------------------------------------------------
# 3. Auto-detected weights for survey_nonprob input
# ---------------------------------------------------------------------------

test_that("effective_sample_size() auto-detects weights from survey_nonprob", {
  df <- make_surveywts_data(seed = 3)
  svy <- .make_test_taylor_diag(df)
  pop_age <- c("18-34" = 1 / 3, "35-54" = 1 / 3, "55+" = 1 / 3)
  svc <- calibrate_linear(svy, targets = list(age_group = pop_age))

  result_auto <- effective_sample_size(svc)
  result_explicit <- effective_sample_size(svc, weights = base_weight)

  # Auto-detection reads @variables$weights
  expect_equal(
    result_auto[["n_eff"]],
    result_explicit[["n_eff"]],
    tolerance = 1e-10
  )
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
  taylor <- .make_test_taylor_diag(df)

  result <- summarize_weights(taylor)

  expect_true(tibble::is_tibble(result))
  expect_equal(nrow(result), 1L)
})

# ---------------------------------------------------------------------------
# 5. summarize_weights — by grouping returns correct number of rows
# ---------------------------------------------------------------------------

test_that("summarize_weights() returns one row per group with by grouping", {
  df <- make_surveywts_data(seed = 6)
  taylor <- .make_test_taylor_diag(df)

  result <- summarize_weights(taylor, by = c(age_group))

  n_age_groups <- length(unique(df$age_group))
  expect_equal(nrow(result), n_age_groups)
  expect_true(tibble::is_tibble(result))
  expect_true("age_group" %in% names(result))
})

# ---------------------------------------------------------------------------
# 5b. Error — unsupported_class (matrix or list input)
# ---------------------------------------------------------------------------

test_that("effective_sample_size() throws not_survey_base for matrix input", {
  m <- matrix(1:6, nrow = 3)

  expect_error(
    effective_sample_size(m),
    class = "surveywts_error_not_survey_base"
  )
  expect_snapshot(error = TRUE, effective_sample_size(m))
})

test_that("weight_variability() throws not_survey_base for list input", {
  x <- list(w = c(1, 2, 3))

  expect_error(
    weight_variability(x),
    class = "surveywts_error_not_survey_base"
  )
  expect_snapshot(error = TRUE, weight_variability(x))
})

# E6-E9 removed — weights_required, weights_not_found, weights_not_numeric,
# weights_nonpositive, weights_na are no longer reachable via public API.
# The weights= arg is removed from plain data.frame inputs; S7 enforces
# weight validity at construction time. not_survey_base tests cover §2 above.

# ---------------------------------------------------------------------------
# 8. summarize_weights() output has correct columns in specified order
# ---------------------------------------------------------------------------

test_that("summarize_weights() returns columns in correct order (no by)", {
  df <- make_surveywts_data(seed = 7)
  taylor <- .make_test_taylor_diag(df)

  result <- summarize_weights(taylor)

  expect_identical(
    names(result),
    c(
      "n",
      "n_positive",
      "n_zero",
      "mean",
      "cv",
      "min",
      "p25",
      "p50",
      "p75",
      "max",
      "ess"
    )
  )
})

test_that("summarize_weights() returns group columns first with by grouping", {
  df <- make_surveywts_data(seed = 8)
  taylor <- .make_test_taylor_diag(df)

  result <- summarize_weights(taylor, by = c(age_group))

  expect_identical(
    names(result),
    c(
      "age_group",
      "n",
      "n_positive",
      "n_zero",
      "mean",
      "cv",
      "min",
      "p25",
      "p50",
      "p75",
      "max",
      "ess"
    )
  )
})

# ---------------------------------------------------------------------------
# 9. summarize_weights() — grouping variable with dot in levels
# ---------------------------------------------------------------------------

test_that("summarize_weights() handles grouping variable with dot in levels", {
  # Regression test: interaction() uses "." as separator, which collides
  # with "." in factor levels like "Dr." or "U.S."
  df <- data.frame(
    title = c("Dr.", "Dr.", "Mr.", "Mr.", "Ms."),
    w = c(1.2, 0.8, 1.5, 0.9, 1.1),
    stringsAsFactors = FALSE
  )
  taylor <- .make_test_taylor_diag(df, weight_col = "w")

  result <- summarize_weights(taylor, by = c(title))

  # Should have 3 rows — one per unique title
  expect_equal(nrow(result), 3L)
  expect_true("title" %in% names(result))
  # Level values must not be mangled
  expect_identical(sort(result$title), c("Dr.", "Mr.", "Ms."))
})

test_that("summarize_weights() preserves first-occurrence order in grouped output", {
  df <- data.frame(
    group = c("B", "A", "B", "A", "C"),
    w = c(1.2, 0.8, 1.5, 0.9, 1.1),
    stringsAsFactors = FALSE
  )
  taylor <- .make_test_taylor_diag(df, weight_col = "w")

  result <- summarize_weights(taylor, by = c(group))

  # First-occurrence order: B, A, C (not alphabetical A, B, C)
  expect_identical(result$group, c("B", "A", "C"))
})

test_that("summarize_weights() handles multi-column by with dots in levels", {
  df <- data.frame(
    title = c("Dr.", "Dr.", "Mr.", "Mr."),
    dept = c("R&D", "R&D", "H.R.", "H.R."),
    w = c(1.2, 0.8, 1.5, 0.9),
    stringsAsFactors = FALSE
  )
  taylor <- .make_test_taylor_diag(df, weight_col = "w")

  result <- summarize_weights(taylor, by = c(title, dept))

  # 2 unique combinations: Dr./R&D and Mr./H.R.
  expect_equal(nrow(result), 2L)
  expect_identical(result$title, c("Dr.", "Mr."))
  expect_identical(result$dept, c("R&D", "H.R."))
})


# ---------------------------------------------------------------------------
# 11. survey_replicate input — accepted (Replicate release complete)
# ---------------------------------------------------------------------------

test_that("effective_sample_size() accepts survey_replicate input", {
  skip_if_not_installed("svrep")
  sr <- make_replicate_design(seed = 1)

  expect_no_error(effective_sample_size(sr))
})

test_that("weight_variability() accepts survey_replicate input", {
  skip_if_not_installed("svrep")
  sr <- make_replicate_design(seed = 1)

  expect_no_error(weight_variability(sr))
})

test_that("summarize_weights() accepts survey_replicate input", {
  skip_if_not_installed("svrep")
  sr <- make_replicate_design(seed = 1)

  expect_no_error(summarize_weights(sr))
})

# ---------------------------------------------------------------------------
# 11a. Numerical correctness — survey_replicate uses main weight column only
# ---------------------------------------------------------------------------

test_that("effective_sample_size() computes correct ESS from survey_replicate main weights", {
  skip_if_not_installed("svrep")
  sr <- make_replicate_design(seed = 1)
  w <- sr@data[[sr@variables$weights]]

  result <- effective_sample_size(sr)

  expected_ess <- sum(w)^2 / sum(w^2)
  expect_equal(result[["n_eff"]], expected_ess, tolerance = 1e-10)
})

test_that("weight_variability() computes correct CV from survey_replicate main weights", {
  skip_if_not_installed("svrep")
  sr <- make_replicate_design(seed = 1)
  w <- sr@data[[sr@variables$weights]]

  result <- weight_variability(sr)

  expected_cv <- stats::sd(w) / mean(w)
  expect_equal(result[["cv"]], expected_cv, tolerance = 1e-10)
})

test_that("effective_sample_size() on survey_replicate matches survey_taylor with same main weights", {
  skip_if_not_installed("svrep")
  sr <- make_replicate_design(seed = 1)
  # Build a survey_taylor with the same main weight column
  taylor <- surveycore::survey_taylor(
    data = sr@data,
    variables = list(weights = sr@variables$weights)
  )

  result_sr <- effective_sample_size(sr)
  result_taylor <- effective_sample_size(taylor)

  expect_equal(
    result_sr[["n_eff"]],
    result_taylor[["n_eff"]],
    tolerance = 1e-10
  )
})

# ---------------------------------------------------------------------------
# 11b. Regression — not_survey_base fires for all non-S7 input types
# ---------------------------------------------------------------------------

test_that("surveywts_error_not_survey_base fires for plain data.frame input", {
  df <- data.frame(x = 1:5, w = c(1.2, 0.8, 1.5, 0.9, 1.1))

  expect_error(
    effective_sample_size(df),
    class = "surveywts_error_not_survey_base"
  )
})

test_that("surveywts_error_not_survey_base fires for list input", {
  x <- list(w = c(1, 2, 3))

  expect_error(
    effective_sample_size(x),
    class = "surveywts_error_not_survey_base"
  )
})

# ---------------------------------------------------------------------------
# 11c. Edge cases — survey_replicate
# ---------------------------------------------------------------------------

test_that("summarize_weights() with survey_replicate and by = age_group returns grouped tibble", {
  skip_if_not_installed("svrep")
  sr <- make_replicate_design(seed = 1)

  result <- summarize_weights(sr, by = age_group)

  expect_true(tibble::is_tibble(result))
  expect_true("age_group" %in% names(result))
  n_age_groups <- length(unique(sr@data[["age_group"]]))
  expect_equal(nrow(result), n_age_groups)
})

test_that("survey_replicate with equal main weights gives n_eff == n and cv == 0", {
  skip_if_not_installed("svrep")
  n <- 50L
  df_eq <- data.frame(
    id = seq_len(n),
    age_group = rep(c("18-34", "35-54", "55+"), length.out = n),
    base_weight = rep(1.0, n),
    stringsAsFactors = FALSE
  )
  taylor_eq <- surveycore::survey_taylor(
    data = df_eq,
    variables = list(weights = "base_weight")
  )
  sr_eq <- create_bootstrap_weights(taylor_eq, replicates = 10L)

  result_ess <- effective_sample_size(sr_eq)
  result_cv <- weight_variability(sr_eq)

  expect_equal(result_ess[["n_eff"]], n, tolerance = 1e-10)
  expect_equal(result_cv[["cv"]], 0, tolerance = 1e-10)
})
