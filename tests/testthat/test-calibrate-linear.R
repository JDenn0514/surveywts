# tests/testthat/test-calibrate-linear.R
#
# Full test suite for calibrate_linear()
# Tests are written BEFORE implementation (TDD red phase).
#
# Test sections:
#   H1-H10  — Happy paths
#   N1-N2   — Oracle / numerical correctness vs survey::calibrate()
#   E1-E23  — Error paths (dual: expect_error + expect_snapshot)
#   W1-W4   — Warning paths
#   EC1-EC11 — Edge cases
#   H_abs   — Absolute bounds happy path
#   E_abs   — Absolute bounds error path

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

.make_linear_targets <- function(type = "prop") {
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

.make_test_taylor_linear <- function(df, weight_col = "base_weight") {
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

.make_test_nonprob_linear <- function(df, weight_col = "base_weight") {
  surveycore::survey_nonprob(
    data = df,
    variables = list(weights = weight_col)
  )
}

# ---------------------------------------------------------------------------
# H1: Happy path — plain data.frame, type = "prop", bounds = NULL
# ---------------------------------------------------------------------------

test_that("H1: calibrate_linear() returns weighted_df for data.frame (prop, no bounds)", {
  df <- make_surveywts_data(seed = 1)
  targets <- .make_linear_targets()

  result <- calibrate_linear(df, targets = targets, weights = base_weight)

  test_invariants(result)
  expect_true(inherits(result, "weighted_df"))
  expect_identical(attr(result, "weight_col"), "wts")

  # Calibration constraint check
  w <- result[["wts"]]
  total_w <- sum(w)
  for (var in names(targets)) {
    for (lev in names(targets[[var]])) {
      obs_prop <- sum(w[result[[var]] == lev]) / total_w
      expect_equal(obs_prop, targets[[var]][[lev]], tolerance = 1e-8,
                   label = paste0(var, "=", lev))
    }
  }

  # History entry check
  h <- attr(result, "weighting_history")
  expect_equal(length(h), 1L)
  expect_identical(h[[1L]]$operation, "calibrate_linear")
})

# ---------------------------------------------------------------------------
# H2: Happy path — type = "count"
# ---------------------------------------------------------------------------

test_that("H2: calibrate_linear() returns weighted_df for data.frame (count)", {
  df <- make_surveywts_data(n = 500, seed = 2)
  targets <- .make_linear_targets("count")

  result <- calibrate_linear(
    df, targets = targets, weights = base_weight, type = "count"
  )

  test_invariants(result)
  expect_true(inherits(result, "weighted_df"))

  w <- result[["wts"]]
  for (var in names(targets)) {
    for (lev in names(targets[[var]])) {
      obs_count <- sum(w[result[[var]] == lev])
      expect_equal(obs_count, targets[[var]][[lev]], tolerance = 1e-6,
                   label = paste0(var, "=", lev))
    }
  }
})

# ---------------------------------------------------------------------------
# H3: Happy path — survey_taylor input: class preserved, @calibration populated
# ---------------------------------------------------------------------------

test_that("H3: calibrate_linear() preserves survey_taylor class and populates @calibration", {
  df <- make_surveywts_data(seed = 3)
  taylor <- .make_test_taylor_linear(df)
  targets <- .make_linear_targets()

  result <- calibrate_linear(taylor, targets = targets)

  test_invariants(result)
  expect_true(S7::S7_inherits(result, surveycore::survey_taylor))

  # @calibration populated
  cal <- result@calibration
  expect_false(is.null(cal))
  expect_true(is.list(cal))
  expect_true("method" %in% names(cal))
  expect_identical(cal$method, "linear")
  expect_true("lambda" %in% names(cal))
  expect_true(is.numeric(cal$lambda))
})

# ---------------------------------------------------------------------------
# H4: Happy path — survey_nonprob input: class preserved
# ---------------------------------------------------------------------------

test_that("H4: calibrate_linear() preserves survey_nonprob class", {
  df <- make_surveywts_data(seed = 4)
  nonprob <- .make_test_nonprob_linear(df)
  targets <- .make_linear_targets()

  result <- calibrate_linear(nonprob, targets = targets)

  test_invariants(result)
  expect_true(S7::S7_inherits(result, surveycore::survey_nonprob))

  cal <- result@calibration
  expect_false(is.null(cal))
  expect_identical(cal$method, "linear")
})

# ---------------------------------------------------------------------------
# H5: Happy path — weighted_df input: history entry appended
# ---------------------------------------------------------------------------

test_that("H5: calibrate_linear() accepts weighted_df and appends history entry", {
  df <- make_surveywts_data(seed = 5)
  targets <- .make_linear_targets()

  # First pass: make a weighted_df via calibrate_linear itself
  wdf <- calibrate_linear(df, targets = targets, weights = base_weight)

  # Second pass: calibrate the weighted_df
  result <- calibrate_linear(wdf, targets = targets)

  test_invariants(result)
  expect_true(inherits(result, "weighted_df"))

  h <- attr(result, "weighting_history")
  expect_equal(length(h), 2L)
  expect_identical(h[[2L]]$operation, "calibrate_linear")
})

# ---------------------------------------------------------------------------
# H6: Happy path — bounds != NULL (truncated linear); @calibration$method = "truncated"
# ---------------------------------------------------------------------------

test_that("H6: bounds = c(0.3, 3) gives method='truncated'; @calibration$bounds_scale='multiplicative'", {
  df <- make_surveywts_data(seed = 6)
  taylor <- .make_test_taylor_linear(df)
  targets <- .make_linear_targets()

  result <- calibrate_linear(
    taylor,
    targets = targets,
    bounds = c(0.3, 3)
  )

  test_invariants(result)
  expect_identical(result@calibration$method, "truncated")
  expect_identical(result@calibration$bounds_scale, "multiplicative")
})

test_that("H6b: data.frame with bounds produces valid weighted_df", {
  df <- make_surveywts_data(seed = 6)
  targets <- .make_linear_targets()

  result <- calibrate_linear(
    df,
    targets = targets,
    weights = base_weight,
    bounds = c(0.3, 3)
  )

  test_invariants(result)
  expect_true(inherits(result, "weighted_df"))
  w <- result[["wts"]]
  expect_true(all(is.finite(w)))
})

# ---------------------------------------------------------------------------
# H7: Happy path — unit_scale provided; @calibration$q_weights matches
# ---------------------------------------------------------------------------

test_that("H7: unit_scale arg populates @calibration$q_weights", {
  df <- make_surveywts_data(n = 100, seed = 7)
  taylor <- .make_test_taylor_linear(df)
  targets <- .make_linear_targets()

  q <- rep(1.5, nrow(df))
  result <- calibrate_linear(taylor, targets = targets, unit_scale = q)

  test_invariants(result)
  expect_equal(result@calibration$q_weights, q, tolerance = 1e-12)
})

# ---------------------------------------------------------------------------
# H8: Happy path — unit_scale = NULL gives @calibration$q_weights = NULL
# ---------------------------------------------------------------------------

test_that("H8: unit_scale = NULL gives is.null(@calibration$q_weights) = TRUE", {
  df <- make_surveywts_data(n = 100, seed = 8)
  taylor <- .make_test_taylor_linear(df)
  targets <- .make_linear_targets()

  result <- calibrate_linear(taylor, targets = targets, unit_scale = NULL)

  test_invariants(result)
  expect_null(result@calibration$q_weights)
})

# ---------------------------------------------------------------------------
# H9: Happy path — Format B (long data frame) targets accepted
# ---------------------------------------------------------------------------

test_that("H9: calibrate_linear() accepts Format B (long data frame) targets", {
  df <- make_surveywts_data(seed = 9)
  targets_b <- data.frame(
    variable = c(
      "age_group", "age_group", "age_group",
      "sex", "sex"
    ),
    level = c("18-34", "35-54", "55+", "M", "F"),
    target = c(0.30, 0.40, 0.30, 0.48, 0.52),
    stringsAsFactors = FALSE
  )

  result <- calibrate_linear(df, targets = targets_b, weights = base_weight)

  test_invariants(result)
  expect_true(inherits(result, "weighted_df"))
})

# ---------------------------------------------------------------------------
# H10: Happy path — plain linear may produce negative weights -> warning emitted
# ---------------------------------------------------------------------------

test_that("H10: extreme targets produce negative weights warning for plain linear", {
  # Two independent variables with extreme targets force negative g-weights
  # Sample: 90% young/M; targets: 5% young, 5% M — GREG extrapolates outside [0,1]
  set.seed(123)
  n <- 200
  age <- sample(c("young", "old"), n, replace = TRUE, prob = c(0.90, 0.10))
  sex <- sample(c("M", "F"), n, replace = TRUE, prob = c(0.90, 0.10))
  df <- data.frame(age = age, sex = sex, wt = rep(1, n), stringsAsFactors = FALSE)

  targets <- list(
    age = c("young" = 0.05, "old" = 0.95),
    sex = c("M" = 0.05, "F" = 0.95)
  )

  expect_warning(
    result <- calibrate_linear(df, targets = targets, weights = wt),
    class = "surveywts_warning_negative_calibrated_weights"
  )
  test_invariants(result)
  expect_true(inherits(result, "weighted_df"))
})

# ---------------------------------------------------------------------------
# N1: Oracle — compare against survey::calibrate() (linear / GREG)
# ---------------------------------------------------------------------------

test_that("N1: calibrate_linear() matches survey::calibrate(calfun='linear') within 1e-8", {
  skip_if_not_installed("survey")

  df <- make_surveywts_data(n = 200, seed = 101)

  # Single variable to keep matrix construction simple and comparable
  targets_a <- list(
    age_group = c("18-34" = 0.30, "35-54" = 0.40, "55+" = 0.30)
  )

  result <- calibrate_linear(df, targets = targets_a, weights = base_weight)
  wts_ours <- result[["wts"]]

  # Build survey::calibrate equivalent.
  # Note: survey::svydesign() converts '-' to '.' in column names in some
  # pop totals vectors; use the factor + model.matrix approach to get matching
  # names, then strip names from survey weights for comparison.
  total_w <- sum(df$base_weight)
  pop_totals_survey <- c(
    `(Intercept)` = total_w,
    `age_group35-54` = total_w * 0.40,
    `age_group55+` = total_w * 0.30
  )

  df_factor <- df
  df_factor$age_group <- factor(df$age_group, levels = c("18-34", "35-54", "55+"))
  svy_design <- survey::svydesign(
    ids = ~1,
    weights = ~base_weight,
    data = df_factor
  )
  # survey::calibrate() may warn about name mismatches for hyphenated levels;
  # suppress that warning — it's a survey package formatting artefact
  calib_design <- suppressWarnings(survey::calibrate(
    svy_design,
    formula = ~age_group,
    population = pop_totals_survey,
    calfun = "linear"
  ))
  # as.numeric(): strips names and any auxiliary attributes (e.g., "eta")
  # that survey::calibrate() attaches to the weight vector
  wts_survey <- as.numeric(weights(calib_design))

  expect_equal(wts_ours, wts_survey, tolerance = 1e-8)
})

# ---------------------------------------------------------------------------
# N2: Oracle — truncated linear with bounds vs survey::calibrate(calfun='truncated')
# ---------------------------------------------------------------------------

test_that("N2: calibrate_linear(bounds=c(0.3,3)) matches survey::calibrate(calfun='linear', bounds) within 1e-8", {
  skip_if_not_installed("survey")

  df <- make_surveywts_data(n = 200, seed = 102)

  targets_a <- list(
    age_group = c("18-34" = 0.30, "35-54" = 0.40, "55+" = 0.30)
  )

  result <- calibrate_linear(
    df, targets = targets_a, weights = base_weight,
    bounds = c(0.3, 3)
  )
  wts_ours <- result[["wts"]]

  # survey::calibrate() implements truncated-linear via calfun = "linear" + bounds.
  # The survey package uses "." for "-" in factor level names in some contexts;
  # suppress name-mismatch warnings and strip names for comparison.
  total_w <- sum(df$base_weight)
  pop_totals_survey <- c(
    `(Intercept)` = total_w,
    `age_group35-54` = total_w * 0.40,
    `age_group55+` = total_w * 0.30
  )

  df_factor <- df
  df_factor$age_group <- factor(df$age_group, levels = c("18-34", "35-54", "55+"))
  svy_design <- survey::svydesign(
    ids = ~1,
    weights = ~base_weight,
    data = df_factor
  )
  calib_design <- suppressWarnings(survey::calibrate(
    svy_design,
    formula = ~age_group,
    population = pop_totals_survey,
    calfun = "linear",
    bounds = c(0.3, 3)
  ))
  wts_survey <- as.numeric(weights(calib_design))

  expect_equal(wts_ours, wts_survey, tolerance = 1e-8)
})

# ---------------------------------------------------------------------------
# E1: Error — unsupported input class
# ---------------------------------------------------------------------------

test_that("E1: calibrate_linear() throws surveywts_error_unsupported_class for bad input", {
  expect_error(
    calibrate_linear(list(x = 1:3), targets = list()),
    class = "surveywts_error_unsupported_class"
  )
  expect_snapshot(
    error = TRUE,
    calibrate_linear(list(x = 1:3), targets = list())
  )
})

# ---------------------------------------------------------------------------
# E2: Error — empty data
# ---------------------------------------------------------------------------

test_that("E2: calibrate_linear() throws surveywts_error_empty_data for 0-row input", {
  empty_df <- data.frame(
    age_group = character(0),
    base_weight = numeric(0),
    stringsAsFactors = FALSE
  )
  targets <- list(age_group = c("18-34" = 1.0))

  expect_error(
    calibrate_linear(empty_df, targets = targets, weights = base_weight),
    class = "surveywts_error_empty_data"
  )
  expect_snapshot(
    error = TRUE,
    calibrate_linear(empty_df, targets = targets, weights = base_weight)
  )
})

# ---------------------------------------------------------------------------
# E3: Error — wt_name not scalar
# ---------------------------------------------------------------------------

test_that("E3: calibrate_linear() throws surveywts_error_wt_name_not_scalar", {
  df <- make_surveywts_data(n = 50, seed = 3)
  targets <- .make_linear_targets()

  expect_error(
    calibrate_linear(
      df, targets = targets, weights = base_weight,
      wt_name = c("a", "b")
    ),
    class = "surveywts_error_wt_name_not_scalar"
  )
  expect_snapshot(
    error = TRUE,
    calibrate_linear(
      df, targets = targets, weights = base_weight,
      wt_name = c("a", "b")
    )
  )
})

# ---------------------------------------------------------------------------
# E4: Error — wt_name empty
# ---------------------------------------------------------------------------

test_that("E4: calibrate_linear() throws surveywts_error_wt_name_empty for NA wt_name", {
  df <- make_surveywts_data(n = 50, seed = 4)
  targets <- .make_linear_targets()

  expect_error(
    calibrate_linear(
      df, targets = targets, weights = base_weight,
      wt_name = NA_character_
    ),
    class = "surveywts_error_wt_name_empty"
  )
  expect_snapshot(
    error = TRUE,
    calibrate_linear(
      df, targets = targets, weights = base_weight,
      wt_name = NA_character_
    )
  )
})

test_that("E4b: calibrate_linear() throws surveywts_error_wt_name_empty for empty string", {
  df <- make_surveywts_data(n = 50, seed = 4)
  targets <- .make_linear_targets()

  expect_error(
    calibrate_linear(
      df, targets = targets, weights = base_weight,
      wt_name = ""
    ),
    class = "surveywts_error_wt_name_empty"
  )
})

# ---------------------------------------------------------------------------
# E5: Error — reference_design not taylor
# ---------------------------------------------------------------------------

test_that("E5: calibrate_linear() throws surveywts_error_reference_design_not_taylor", {
  df <- make_surveywts_data(n = 50, seed = 5)
  targets <- .make_linear_targets()

  expect_error(
    calibrate_linear(
      df, targets = targets, weights = base_weight,
      reference_design = "not_a_design"
    ),
    class = "surveywts_error_reference_design_not_taylor"
  )
  expect_snapshot(
    error = TRUE,
    calibrate_linear(
      df, targets = targets, weights = base_weight,
      reference_design = "not_a_design"
    )
  )
})

# ---------------------------------------------------------------------------
# E6: Error — weight column not found
# ---------------------------------------------------------------------------

test_that("E6: calibrate_linear() throws surveywts_error_weights_not_found", {
  df <- make_surveywts_data(n = 50, seed = 6)
  targets <- .make_linear_targets()

  expect_error(
    calibrate_linear(df, targets = targets, weights = nonexistent_col),
    class = "surveywts_error_weights_not_found"
  )
  expect_snapshot(
    error = TRUE,
    calibrate_linear(df, targets = targets, weights = nonexistent_col)
  )
})

# ---------------------------------------------------------------------------
# E7: Error — weight column not numeric
# ---------------------------------------------------------------------------

test_that("E7: calibrate_linear() throws surveywts_error_weights_not_numeric", {
  df <- make_surveywts_data(n = 50, seed = 7)
  df$bad_wt <- as.character(df$base_weight)
  targets <- .make_linear_targets()

  expect_error(
    calibrate_linear(df, targets = targets, weights = bad_wt),
    class = "surveywts_error_weights_not_numeric"
  )
  expect_snapshot(
    error = TRUE,
    calibrate_linear(df, targets = targets, weights = bad_wt)
  )
})

# ---------------------------------------------------------------------------
# E8: Error — weight column has non-positive values
# ---------------------------------------------------------------------------

test_that("E8: calibrate_linear() throws surveywts_error_weights_nonpositive", {
  df <- make_surveywts_data(n = 50, seed = 8)
  df$base_weight[1] <- 0
  targets <- .make_linear_targets()

  expect_error(
    calibrate_linear(df, targets = targets, weights = base_weight),
    class = "surveywts_error_weights_nonpositive"
  )
  expect_snapshot(
    error = TRUE,
    calibrate_linear(df, targets = targets, weights = base_weight)
  )
})

# ---------------------------------------------------------------------------
# E9: Error — weight column has NA
# ---------------------------------------------------------------------------

test_that("E9: calibrate_linear() throws surveywts_error_weights_na", {
  df <- make_surveywts_data(n = 50, seed = 9)
  df$base_weight[3] <- NA_real_
  targets <- .make_linear_targets()

  expect_error(
    calibrate_linear(df, targets = targets, weights = base_weight),
    class = "surveywts_error_weights_na"
  )
  expect_snapshot(
    error = TRUE,
    calibrate_linear(df, targets = targets, weights = base_weight)
  )
})

# ---------------------------------------------------------------------------
# E10: Error — targets variable not found in data
# ---------------------------------------------------------------------------

test_that("E10: calibrate_linear() throws surveywts_error_targets_variable_not_found", {
  df <- make_surveywts_data(n = 50, seed = 10)
  targets <- list(
    nonexistent_var = c("A" = 0.5, "B" = 0.5)
  )

  expect_error(
    calibrate_linear(df, targets = targets, weights = base_weight),
    class = "surveywts_error_targets_variable_not_found"
  )
  expect_snapshot(
    error = TRUE,
    calibrate_linear(df, targets = targets, weights = base_weight)
  )
})

# ---------------------------------------------------------------------------
# E11: Error — calibration variable is not categorical
# ---------------------------------------------------------------------------

test_that("E11: calibrate_linear() throws surveywts_error_variable_not_categorical", {
  df <- make_surveywts_data(n = 50, seed = 11)
  # Use id (integer) as a calibration variable
  targets <- list(id = c(`1` = 0.5, `2` = 0.5))

  expect_error(
    calibrate_linear(df, targets = targets, weights = base_weight),
    class = "surveywts_error_variable_not_categorical"
  )
  expect_snapshot(
    error = TRUE,
    calibrate_linear(df, targets = targets, weights = base_weight)
  )
})

# ---------------------------------------------------------------------------
# E12: Error — calibration variable has NA
# ---------------------------------------------------------------------------

test_that("E12: calibrate_linear() throws surveywts_error_variable_has_na", {
  df <- make_surveywts_data(n = 50, seed = 12)
  df$age_group[1] <- NA_character_
  targets <- .make_linear_targets()

  expect_error(
    calibrate_linear(df, targets = targets, weights = base_weight),
    class = "surveywts_error_variable_has_na"
  )
  expect_snapshot(
    error = TRUE,
    calibrate_linear(df, targets = targets, weights = base_weight)
  )
})

# ---------------------------------------------------------------------------
# E13: Error — population level missing (data level absent from targets)
# ---------------------------------------------------------------------------

test_that("E13: calibrate_linear() throws surveywts_error_population_level_missing", {
  df <- make_surveywts_data(n = 50, seed = 13)
  # Missing "55+" level in targets
  targets <- list(
    age_group = c("18-34" = 0.50, "35-54" = 0.50)
  )

  expect_error(
    calibrate_linear(df, targets = targets, weights = base_weight),
    class = "surveywts_error_population_level_missing"
  )
  expect_snapshot(
    error = TRUE,
    calibrate_linear(df, targets = targets, weights = base_weight)
  )
})

# ---------------------------------------------------------------------------
# E14: Error — population level extra (targets level absent from data)
# ---------------------------------------------------------------------------

test_that("E14: calibrate_linear() throws surveywts_error_population_level_extra", {
  df <- make_surveywts_data(n = 50, seed = 14)
  # Extra level "65+" not in data
  targets <- list(
    age_group = c("18-34" = 0.25, "35-54" = 0.40, "55+" = 0.25, "65+" = 0.10)
  )

  expect_error(
    calibrate_linear(df, targets = targets, weights = base_weight),
    class = "surveywts_error_population_level_extra"
  )
  expect_snapshot(
    error = TRUE,
    calibrate_linear(df, targets = targets, weights = base_weight)
  )
})

# ---------------------------------------------------------------------------
# E15: Error — population totals invalid (prop doesn't sum to 1)
# ---------------------------------------------------------------------------

test_that("E15: calibrate_linear() throws surveywts_error_population_totals_invalid (prop != 1)", {
  df <- make_surveywts_data(n = 50, seed = 15)
  targets <- list(
    age_group = c("18-34" = 0.40, "35-54" = 0.40, "55+" = 0.40) # sums to 1.2
  )

  expect_error(
    calibrate_linear(df, targets = targets, weights = base_weight),
    class = "surveywts_error_population_totals_invalid"
  )
  expect_snapshot(
    error = TRUE,
    calibrate_linear(df, targets = targets, weights = base_weight)
  )
})

# ---------------------------------------------------------------------------
# E16: Error — population totals invalid (count <= 0)
# ---------------------------------------------------------------------------

test_that("E16: calibrate_linear() throws surveywts_error_population_totals_invalid (count <= 0)", {
  df <- make_surveywts_data(n = 50, seed = 16)
  targets <- list(
    age_group = c("18-34" = -10, "35-54" = 200, "55+" = 150)
  )

  expect_error(
    calibrate_linear(
      df, targets = targets, weights = base_weight,
      type = "count"
    ),
    class = "surveywts_error_population_totals_invalid"
  )
  expect_snapshot(
    error = TRUE,
    calibrate_linear(
      df, targets = targets, weights = base_weight,
      type = "count"
    )
  )
})

# ---------------------------------------------------------------------------
# E17: Error — margins format invalid (unsupported targets type)
# ---------------------------------------------------------------------------

test_that("E17: calibrate_linear() throws surveywts_error_margins_format_invalid for bad targets", {
  df <- make_surveywts_data(n = 50, seed = 17)

  expect_error(
    calibrate_linear(df, targets = 42, weights = base_weight),
    class = "surveywts_error_margins_format_invalid"
  )
  expect_snapshot(
    error = TRUE,
    calibrate_linear(df, targets = 42, weights = base_weight)
  )
})

# ---------------------------------------------------------------------------
# E18: Error — bounds invalid for multiplicative (L >= 1)
# ---------------------------------------------------------------------------

test_that("E18: calibrate_linear() throws surveywts_error_bounds_invalid_calibration (L >= 1)", {
  df <- make_surveywts_data(n = 50, seed = 18)
  targets <- .make_linear_targets()

  expect_error(
    calibrate_linear(
      df, targets = targets, weights = base_weight,
      bounds = c(1.0, 3.0)
    ),
    class = "surveywts_error_bounds_invalid_calibration"
  )
  expect_snapshot(
    error = TRUE,
    calibrate_linear(
      df, targets = targets, weights = base_weight,
      bounds = c(1.0, 3.0)
    )
  )
})

# ---------------------------------------------------------------------------
# E19: Error — bounds invalid for multiplicative (U <= 1)
# ---------------------------------------------------------------------------

test_that("E19: calibrate_linear() throws surveywts_error_bounds_invalid_calibration (U <= 1)", {
  df <- make_surveywts_data(n = 50, seed = 19)
  targets <- .make_linear_targets()

  expect_error(
    calibrate_linear(
      df, targets = targets, weights = base_weight,
      bounds = c(0.3, 0.9)
    ),
    class = "surveywts_error_bounds_invalid_calibration"
  )
  expect_snapshot(
    error = TRUE,
    calibrate_linear(
      df, targets = targets, weights = base_weight,
      bounds = c(0.3, 0.9)
    )
  )
})

# ---------------------------------------------------------------------------
# E20: Error — unit_scale invalid (not numeric)
# ---------------------------------------------------------------------------

test_that("E20: calibrate_linear() throws surveywts_error_unit_scale_invalid (not numeric)", {
  df <- make_surveywts_data(n = 50, seed = 20)
  targets <- .make_linear_targets()

  expect_error(
    calibrate_linear(
      df, targets = targets, weights = base_weight,
      unit_scale = rep("1", nrow(df))
    ),
    class = "surveywts_error_unit_scale_invalid"
  )
  expect_snapshot(
    error = TRUE,
    calibrate_linear(
      df, targets = targets, weights = base_weight,
      unit_scale = rep("1", nrow(df))
    )
  )
})

# ---------------------------------------------------------------------------
# E21: Error — unit_scale invalid (wrong length)
# ---------------------------------------------------------------------------

test_that("E21: calibrate_linear() throws surveywts_error_unit_scale_invalid (wrong length)", {
  df <- make_surveywts_data(n = 50, seed = 21)
  targets <- .make_linear_targets()

  expect_error(
    calibrate_linear(
      df, targets = targets, weights = base_weight,
      unit_scale = rep(1, nrow(df) - 1)
    ),
    class = "surveywts_error_unit_scale_invalid"
  )
})

# ---------------------------------------------------------------------------
# E22: Error — calibration singular system
# ---------------------------------------------------------------------------

test_that("E22: calibrate_linear() throws surveywts_error_calibration_singular_system for degenerate model", {
  # Create perfectly collinear variables: sex2 is a copy of sex
  set.seed(22)
  n <- 50
  df <- data.frame(
    sex = sample(c("M", "F"), n, replace = TRUE),
    base_weight = rep(1, n),
    stringsAsFactors = FALSE
  )
  df$sex2 <- df$sex
  # Both sex and sex2 are identical — model matrix is rank-deficient
  targets <- list(
    sex = c("M" = 0.50, "F" = 0.50),
    sex2 = c("M" = 0.50, "F" = 0.50)
  )

  expect_error(
    calibrate_linear(df, targets = targets, weights = base_weight),
    class = "surveywts_error_calibration_singular_system"
  )
})

# ---------------------------------------------------------------------------
# E23: Error — count marginal inconsistency across multiple variables
# ---------------------------------------------------------------------------

test_that("E23: calibrate_linear() throws surveywts_error_population_totals_invalid for inconsistent count marginals", {
  df <- make_surveywts_data(n = 100, seed = 23)
  # Two variables with inconsistent total N
  targets <- list(
    age_group = c("18-34" = 150, "35-54" = 200, "55+" = 150), # N = 500
    sex       = c("M" = 300, "F" = 350)  # N = 650 -- inconsistent
  )

  expect_error(
    calibrate_linear(
      df, targets = targets, weights = base_weight,
      type = "count"
    ),
    class = "surveywts_error_population_totals_invalid"
  )
})

# ---------------------------------------------------------------------------
# W1: Warning — SRS assumption for plain data.frame + weights = NULL
# ---------------------------------------------------------------------------

test_that("W1: calibrate_linear() emits surveywts_warning_srs_no_weights for data.frame + weights=NULL", {
  df <- make_surveywts_data(n = 100, seed = 31)
  targets <- list(
    age_group = c("18-34" = 0.30, "35-54" = 0.40, "55+" = 0.30)
  )

  expect_warning(
    result <- calibrate_linear(df, targets = targets),
    class = "surveywts_warning_srs_no_weights"
  )
  test_invariants(result)
  expect_true(inherits(result, "weighted_df"))
})

# ---------------------------------------------------------------------------
# W2: Warning — negative calibrated weights for plain linear
# ---------------------------------------------------------------------------

test_that("W2: calibrate_linear() emits surveywts_warning_negative_calibrated_weights", {
  set.seed(123)
  n <- 200
  age <- sample(c("young", "old"), n, replace = TRUE, prob = c(0.90, 0.10))
  sex <- sample(c("M", "F"), n, replace = TRUE, prob = c(0.90, 0.10))
  df <- data.frame(age = age, sex = sex, wt = rep(1, n), stringsAsFactors = FALSE)

  targets <- list(
    age = c("young" = 0.05, "old" = 0.95),
    sex = c("M" = 0.05, "F" = 0.95)
  )

  expect_warning(
    result <- calibrate_linear(df, targets = targets, weights = wt),
    class = "surveywts_warning_negative_calibrated_weights"
  )
  test_invariants(result)
})

# ---------------------------------------------------------------------------
# W3: Warning — unrecognized control key
# ---------------------------------------------------------------------------

test_that("W3: calibrate_linear() emits surveywts_warning_control_param_ignored for unknown key", {
  df <- make_surveywts_data(n = 100, seed = 32)
  targets <- .make_linear_targets()

  expect_warning(
    result <- calibrate_linear(
      df, targets = targets, weights = base_weight,
      control = list(epsilon = 1e-7, unknown_key = 42)
    ),
    class = "surveywts_warning_control_param_ignored"
  )
  test_invariants(result)
})

# ---------------------------------------------------------------------------
# W4: Warning — replicate calibration failed (survey_replicate input)
# ---------------------------------------------------------------------------

test_that("W4: calibrate_linear() emits surveywts_warning_replicate_calibration_failed for failing replicate", {
  df <- make_surveywts_data(n = 100, seed = 33)
  rep_design <- .make_empty_cell_replicate_design(df, "age_group")
  targets <- .make_linear_targets()

  # The empty cell replicate should trigger a warning for that replicate
  expect_warning(
    result <- calibrate_linear(rep_design, targets = targets),
    class = "surveywts_warning_replicate_calibration_failed"
  )
  test_invariants(result)
  expect_true(S7::S7_inherits(result, surveycore::survey_replicate))
})

# ---------------------------------------------------------------------------
# EC1: Edge case — nrow(data) == 0 throws error before computation
# ---------------------------------------------------------------------------

test_that("EC1: empty data.frame triggers surveywts_error_empty_data", {
  empty_df <- data.frame(
    age_group = character(0),
    base_weight = numeric(0),
    stringsAsFactors = FALSE
  )
  targets <- list(age_group = c("18-34" = 1.0))

  expect_error(
    calibrate_linear(empty_df, targets = targets, weights = base_weight),
    class = "surveywts_error_empty_data"
  )
})

# ---------------------------------------------------------------------------
# EC2: Edge case — single-row data
# ---------------------------------------------------------------------------

test_that("EC2: single-row data.frame with single-level variable proceeds without error", {
  df <- data.frame(
    grp = "A",
    wt = 1,
    stringsAsFactors = FALSE
  )
  targets <- list(grp = c("A" = 1.0))

  # Single-row with single level: model matrix is intercept-only (trivially calibrated)
  result <- calibrate_linear(df, targets = targets, weights = wt)
  expect_true(inherits(result, "weighted_df"))
})

# ---------------------------------------------------------------------------
# EC3: Edge case — all weights already at calibrated values (no-op)
# ---------------------------------------------------------------------------

test_that("EC3: already-calibrated data returns weights unchanged (within tolerance)", {
  df <- make_surveywts_data(n = 100, seed = 35)
  targets <- .make_linear_targets()

  # First calibration
  result1 <- calibrate_linear(df, targets = targets, weights = base_weight)

  # Second calibration on the already-calibrated result — weights should not change
  result2 <- calibrate_linear(result1, targets = targets)

  w1 <- result1[["wts"]]
  w2 <- result2[["wts"]]
  expect_equal(w1, w2, tolerance = 1e-8)
})

# ---------------------------------------------------------------------------
# EC4: Edge case — bounds_scale = "absolute" is valid arg
# ---------------------------------------------------------------------------

test_that("EC4: bounds_scale = 'absolute' is accepted with valid absolute bounds", {
  # Use bounds that straddle 1 so NR converges. For make_surveywts_data
  # base_weight is log-normal with mean ~1, so [0.3, 3] is a sensible
  # absolute constraint on the output weights.
  df <- make_surveywts_data(n = 100, seed = 36)
  targets <- .make_linear_targets()

  result <- calibrate_linear(
    df, targets = targets, weights = base_weight,
    bounds = c(0.3, 3),
    bounds_scale = "absolute"
  )
  expect_true(inherits(result, "weighted_df"))
})

# ---------------------------------------------------------------------------
# EC5: Edge case — survey_replicate: output class preserved
# ---------------------------------------------------------------------------

test_that("EC5: survey_replicate output has same class as input", {
  df <- make_surveywts_data(n = 100, seed = 37)
  rep_design <- .make_replicate_design(df)
  targets <- .make_linear_targets()

  result <- calibrate_linear(rep_design, targets = targets)

  test_invariants(result)
  expect_true(S7::S7_inherits(result, surveycore::survey_replicate))
})

# ---------------------------------------------------------------------------
# EC6: Edge case — reference_design stored in history
# ---------------------------------------------------------------------------

test_that("EC6: reference_design stored in history entry parameters", {
  df <- make_surveywts_data(n = 100, seed = 38)
  ref <- .make_test_taylor_linear(df)
  targets <- .make_linear_targets()

  result <- calibrate_linear(
    df, targets = targets, weights = base_weight,
    reference_design = ref
  )
  test_invariants(result)
  h <- attr(result, "weighting_history")
  expect_true(h[[1L]]$parameters$targets_from_reference)
})

# ---------------------------------------------------------------------------
# EC7: Edge case — g-weights constrained to [L, U] for multiplicative bounds
# ---------------------------------------------------------------------------

test_that("EC7: g-weights (wt / base_wt) are in [L, U] for multiplicative bounds", {
  df <- make_surveywts_data(n = 200, seed = 39)
  taylor <- .make_test_taylor_linear(df)
  targets <- .make_linear_targets()
  L <- 0.3
  U <- 3.0

  result <- calibrate_linear(taylor, targets = targets, bounds = c(L, U))

  test_invariants(result)
  new_wts <- result@data[[result@variables$weights]]
  base_wts <- df$base_weight
  g_weights <- new_wts / base_wts

  # g-weights (not raw weights) must be in [L, U]
  expect_true(all(g_weights >= L - 1e-9))
  expect_true(all(g_weights <= U + 1e-9))
})

# ---------------------------------------------------------------------------
# EC8: Edge case — weight conservation for type = "count"
# ---------------------------------------------------------------------------

test_that("EC8: weight conservation for type='count' within 1e-10", {
  df <- make_surveywts_data(n = 200, seed = 40)
  targets <- .make_linear_targets("count")

  result <- calibrate_linear(
    df, targets = targets, weights = base_weight, type = "count"
  )
  test_invariants(result)

  w_new <- result[["wts"]]
  # The sum of calibrated weights should equal the common population total N
  N_expected <- sum(targets$age_group) # 500
  expect_equal(sum(w_new), N_expected, tolerance = 1e-10)
})

# ---------------------------------------------------------------------------
# EC9: Edge case — weight conservation for type = "prop"
# ---------------------------------------------------------------------------

test_that("EC9: weight conservation for type='prop' within 1e-10", {
  df <- make_surveywts_data(n = 200, seed = 41)
  targets <- .make_linear_targets()

  result <- calibrate_linear(
    df, targets = targets, weights = base_weight, type = "prop"
  )
  test_invariants(result)

  w_new <- result[["wts"]]
  w_orig <- df$base_weight
  # For prop targets, sum of calibrated weights = sum of design weights
  expect_equal(sum(w_new), sum(w_orig), tolerance = 1e-10)
})

# ---------------------------------------------------------------------------
# EC10: Edge case — n_iterations == 1L for plain linear (bounds = NULL)
# ---------------------------------------------------------------------------

test_that("EC10: @calibration$n_iterations == 1L for plain linear (bounds = NULL)", {
  df <- make_surveywts_data(n = 200, seed = 42)
  taylor <- .make_test_taylor_linear(df)
  targets <- .make_linear_targets()

  result <- calibrate_linear(taylor, targets = targets)

  test_invariants(result)
  expect_equal(result@calibration$n_iterations, 1L)
})

# ---------------------------------------------------------------------------
# EC11: Edge case — n_iterations >= 1L for truncated linear (bounds != NULL)
# ---------------------------------------------------------------------------

test_that("EC11: @calibration$n_iterations >= 1L for truncated linear (bounds != NULL)", {
  df <- make_surveywts_data(n = 200, seed = 43)
  taylor <- .make_test_taylor_linear(df)
  targets <- .make_linear_targets()

  result <- calibrate_linear(taylor, targets = targets, bounds = c(0.3, 3))

  test_invariants(result)
  # Truncated linear requires NR iteration
  expect_true(result@calibration$n_iterations >= 1L)
  # With non-trivial targets, convergence should happen
  expect_true(result@calibration$converged)
})

# ---------------------------------------------------------------------------
# H_abs: Happy path — absolute bounds constrain output weights (not g-weights)
# ---------------------------------------------------------------------------

test_that("H_abs: bounds = c(0.3, 3) with bounds_scale='absolute' keeps output weights in [0.3, 3]", {
  # make_surveywts_data has log-normal weights with mean ~1.
  # Absolute bounds [0.3, 3] straddle 1 so the NR engine converges.
  # In the absolute-bounds implementation (unit-weight trick):
  # base weights normalized to 1, pop totals scaled by n/total_w,
  # bounds [0.3, 3] apply directly to the output weights.
  df <- make_surveywts_data(n = 200, seed = 44)
  targets <- .make_linear_targets()

  result <- calibrate_linear(
    df,
    targets = targets,
    weights = base_weight,
    bounds = c(0.3, 3),
    bounds_scale = "absolute"
  )
  test_invariants(result)
  expect_true(inherits(result, "weighted_df"))

  wts <- result[["wts"]]
  expect_true(all(wts >= 0.3 - 1e-6))
  expect_true(all(wts <= 3 + 1e-6))
})

# ---------------------------------------------------------------------------
# E_abs: Error — absolute bounds with L <= 0
# ---------------------------------------------------------------------------

test_that("E_abs: bounds = c(-1, 2) with bounds_scale='absolute' throws surveywts_error_bounds_invalid_calibration", {
  df <- make_surveywts_data(n = 50, seed = 45)
  targets <- .make_linear_targets()

  expect_error(
    calibrate_linear(
      df, targets = targets, weights = base_weight,
      bounds = c(-1, 2),
      bounds_scale = "absolute"
    ),
    class = "surveywts_error_bounds_invalid_calibration"
  )
  expect_snapshot(
    error = TRUE,
    calibrate_linear(
      df, targets = targets, weights = base_weight,
      bounds = c(-1, 2),
      bounds_scale = "absolute"
    )
  )
})

# ---------------------------------------------------------------------------
# @calibration$bounds_scale metadata tests
# ---------------------------------------------------------------------------

test_that("bounds_scale = NULL when bounds = NULL in @calibration", {
  df <- make_surveywts_data(n = 100, seed = 46)
  taylor <- .make_test_taylor_linear(df)
  targets <- .make_linear_targets()

  result <- calibrate_linear(taylor, targets = targets)
  test_invariants(result)
  expect_null(result@calibration$bounds_scale)
})

test_that("bounds_scale = 'multiplicative' when bounds = c(0.3, 3) in @calibration", {
  df <- make_surveywts_data(n = 100, seed = 47)
  taylor <- .make_test_taylor_linear(df)
  targets <- .make_linear_targets()

  result <- calibrate_linear(
    taylor, targets = targets,
    bounds = c(0.3, 3)
  )
  test_invariants(result)
  expect_identical(result@calibration$bounds_scale, "multiplicative")
})
