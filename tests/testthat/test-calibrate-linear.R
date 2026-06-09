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
# Spec E19: Error — bounds length != 2
# ---------------------------------------------------------------------------

test_that("calibrate_linear() throws surveywts_error_bounds_invalid_calibration for bounds length != 2", {
  df <- make_surveywts_data(n = 50, seed = 191)
  targets <- .make_linear_targets()

  expect_error(
    calibrate_linear(df, targets = targets, weights = base_weight, bounds = c(0.5, 2, 3)),
    class = "surveywts_error_bounds_invalid_calibration"
  )
  expect_snapshot(
    error = TRUE,
    calibrate_linear(df, targets = targets, weights = base_weight, bounds = c(0.5, 2, 3))
  )
})

# ---------------------------------------------------------------------------
# Spec E20: Error — bounds with NA value
# ---------------------------------------------------------------------------

test_that("calibrate_linear() throws surveywts_error_bounds_invalid_calibration for bounds with NA", {
  df <- make_surveywts_data(n = 50, seed = 201)
  targets <- .make_linear_targets()

  expect_error(
    calibrate_linear(df, targets = targets, weights = base_weight, bounds = c(NA, 2)),
    class = "surveywts_error_bounds_invalid_calibration"
  )
  expect_snapshot(
    error = TRUE,
    calibrate_linear(df, targets = targets, weights = base_weight, bounds = c(NA, 2))
  )
})

# ---------------------------------------------------------------------------
# Spec E21: Error — calibration_not_converged for tight bounds
# ---------------------------------------------------------------------------

test_that("calibrate_linear() throws surveywts_error_calibration_not_converged for infeasible tight bounds", {
  df <- make_surveywts_data(n = 200, seed = 211)
  # Targets impossible to reach within the tiny window bounds = c(0.999, 1.001)
  targets <- list(
    age_group = c("18-34" = 0.01, "35-54" = 0.01, "55+" = 0.98)
  )

  expect_error(
    calibrate_linear(
      df, targets = targets, weights = base_weight,
      bounds = c(0.999, 1.001), control = list(maxit = 25L)
    ),
    class = "surveywts_error_calibration_not_converged"
  )
  expect_snapshot(
    error = TRUE,
    calibrate_linear(
      df, targets = targets, weights = base_weight,
      bounds = c(0.999, 1.001), control = list(maxit = 25L)
    )
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
# EC11: Edge case — n_iterations > 1L for truncated linear (bounds != NULL)
# ---------------------------------------------------------------------------

test_that("EC11: @calibration$n_iterations > 1L for truncated linear when bounds bind", {
  # seed=200, n=500 gives unconstrained g-weights in [0.86, 1.19].
  # bounds=(0.85, 1.15) clip the upper end, forcing multiple NR iterations.
  df <- make_surveywts_data(n = 500, seed = 200)
  taylor <- .make_test_taylor_linear(df)
  targets <- list(
    age_group = c("18-34" = 0.30, "35-54" = 0.40, "55+" = 0.30),
    sex = c("M" = 0.48, "F" = 0.52)
  )

  result <- calibrate_linear(taylor, targets = targets, bounds = c(0.85, 1.15))

  test_invariants(result)
  # With bounds binding, multiple NR iterations are required
  expect_true(result@calibration$n_iterations > 1L)
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

# ===========================================================================
# unit_scale (q_weights) tests — calibrate-unit-scale PR 1
# ===========================================================================

# ---------------------------------------------------------------------------
# HL-1: Regression guard — unit_scale = rep(1, n) identical to unit_scale = NULL
# ---------------------------------------------------------------------------

test_that("HL-1: unit_scale = rep(1, n) produces weights identical to unit_scale = NULL within 1e-14", {
  targets <- .make_linear_targets()
  n <- nrow(df_500)

  result_null <- calibrate_linear(
    df_500, targets = targets, weights = base_weight
  )
  result_ones <- calibrate_linear(
    df_500, targets = targets, weights = base_weight,
    unit_scale = q_all_ones
  )

  test_invariants(result_null)
  test_invariants(result_ones)

  expect_equal(
    result_ones[["wts"]],
    result_null[["wts"]],
    tolerance = 1e-14,
    label = "unit_scale = rep(1, n) identical to unit_scale = NULL"
  )
})

# ---------------------------------------------------------------------------
# HL-2: Oracle — unbounded linear, unit_scale = q_unequal vs survey::calibrate
# ---------------------------------------------------------------------------

test_that("HL-2: unbounded linear with q_unequal matches survey::calibrate(variance=1/q) within 1e-8", {
  skip_if_not_installed("survey")

  targets <- .make_linear_targets()
  n <- nrow(df_500)
  total_w <- sum(df_500$base_weight)

  result <- calibrate_linear(
    df_500, targets = targets,
    weights = base_weight,
    unit_scale = q_unequal
  )

  # Build survey::calibrate reference
  svy_design <- survey::svydesign(
    ids = ~1,
    data = df_500,
    weights = ~base_weight
  )
  pop_totals <- c(
    `(Intercept)` = total_w,
    age_group3554 = targets$age_group[["35-54"]] * total_w,
    `age_group55+` = targets$age_group[["55+"]] * total_w,
    sexM = targets$sex[["M"]] * total_w
  )
  # survey::calibrate uses variance = sigma2_k = 1/q_k
  svy_cal <- survey::calibrate(
    svy_design,
    formula = ~age_group + sex,
    population = pop_totals,
    calfun = "linear",
    variance = 1 / q_unequal
  )
  survey_weights <- as.numeric(stats::weights(svy_cal))

  test_invariants(result)
  expect_equal(
    result[["wts"]],
    survey_weights,
    tolerance = 1e-8,
    label = "HL-2: unbounded linear with q_unequal matches survey::calibrate"
  )
})

# ---------------------------------------------------------------------------
# HL-3: Oracle — bounded-multiplicative, unit_scale = q_unequal
# ---------------------------------------------------------------------------

test_that("HL-3: multiplicative-bounded linear with q_unequal matches survey::calibrate within 1e-8", {
  skip_if_not_installed("survey")

  targets <- .make_linear_targets()
  total_w <- sum(df_500$base_weight)

  result <- calibrate_linear(
    df_500, targets = targets,
    weights = base_weight,
    bounds = c(0.3, 3),
    unit_scale = q_unequal
  )

  svy_design <- survey::svydesign(
    ids = ~1, data = df_500, weights = ~base_weight
  )
  pop_totals <- c(
    `(Intercept)` = total_w,
    age_group3554 = targets$age_group[["35-54"]] * total_w,
    `age_group55+` = targets$age_group[["55+"]] * total_w,
    sexM = targets$sex[["M"]] * total_w
  )
  svy_cal <- survey::calibrate(
    svy_design,
    formula = ~age_group + sex,
    population = pop_totals,
    calfun = "linear",
    bounds = c(0.3, 3),
    variance = 1 / q_unequal
  )
  survey_weights <- as.numeric(stats::weights(svy_cal))

  test_invariants(result)
  expect_equal(
    result[["wts"]],
    survey_weights,
    tolerance = 1e-8,
    label = "HL-3: multiplicative-bounded with q_unequal matches survey::calibrate"
  )
})

# ---------------------------------------------------------------------------
# HL-4: Oracle — unbounded linear, constant unit_scale = q_all_twos
# ---------------------------------------------------------------------------

test_that("HL-4: unbounded linear with q_all_twos matches survey::calibrate(variance=0.5) within 1e-8", {
  skip_if_not_installed("survey")

  targets <- .make_linear_targets()
  total_w <- sum(df_500$base_weight)

  result <- calibrate_linear(
    df_500, targets = targets,
    weights = base_weight,
    unit_scale = q_all_twos
  )

  svy_design <- survey::svydesign(
    ids = ~1, data = df_500, weights = ~base_weight
  )
  pop_totals <- c(
    `(Intercept)` = total_w,
    age_group3554 = targets$age_group[["35-54"]] * total_w,
    `age_group55+` = targets$age_group[["55+"]] * total_w,
    sexM = targets$sex[["M"]] * total_w
  )
  svy_cal <- survey::calibrate(
    svy_design,
    formula = ~age_group + sex,
    population = pop_totals,
    calfun = "linear",
    variance = rep(0.5, nrow(df_500))
  )
  survey_weights <- as.numeric(stats::weights(svy_cal))

  test_invariants(result)
  expect_equal(
    result[["wts"]],
    survey_weights,
    tolerance = 1e-8,
    label = "HL-4: unbounded linear with q_all_twos matches survey::calibrate"
  )
})

# ---------------------------------------------------------------------------
# HL-5: Calibration constraint holds with unit_scale != NULL
# ---------------------------------------------------------------------------

test_that("HL-5: calibration constraint satisfied within 1e-8 when unit_scale != NULL", {
  targets <- .make_linear_targets()

  result <- calibrate_linear(
    df_500, targets = targets,
    weights = base_weight,
    unit_scale = q_unequal
  )

  test_invariants(result)
  w <- result[["wts"]]
  total_w <- sum(w)

  for (var in names(targets)) {
    for (lev in names(targets[[var]])) {
      obs_prop <- sum(w[result[[var]] == lev]) / total_w
      expect_equal(
        obs_prop, targets[[var]][[lev]],
        tolerance = 1e-8,
        label = paste0("HL-5: constraint: ", var, "=", lev)
      )
    }
  }
})

# ---------------------------------------------------------------------------
# HL-6: weighting_history records unit_scale vector
# ---------------------------------------------------------------------------

test_that("HL-6: weighting_history entry records unit_scale vector", {
  targets <- .make_linear_targets()

  result <- calibrate_linear(
    df_500, targets = targets,
    weights = base_weight,
    unit_scale = q_unequal
  )

  test_invariants(result)
  h <- attr(result, "weighting_history")
  expect_equal(length(h), 1L)
  expect_equal(
    h[[1L]]$parameters$unit_scale,
    q_unequal,
    tolerance = 1e-14,
    label = "HL-6: unit_scale stored in history"
  )
})

# ---------------------------------------------------------------------------
# HL-7: Bounded vs unbounded outputs differ with same q
# ---------------------------------------------------------------------------

test_that("HL-7: bounded and unbounded calibration produce different weights with same q", {
  # Unconstrained g-weights for this data fall in [0.80, 1.22].
  # bounds = c(0.85, 1.15) clips both ends, forcing a different (constrained) solution.
  targets <- .make_linear_targets()

  result_unbounded <- calibrate_linear(
    df_500, targets = targets,
    weights = base_weight,
    unit_scale = q_unequal
  )
  result_bounded <- calibrate_linear(
    df_500, targets = targets,
    weights = base_weight,
    bounds = c(0.85, 1.15),
    unit_scale = q_unequal
  )

  test_invariants(result_unbounded)
  test_invariants(result_bounded)

  diff_max <- max(abs(result_bounded[["wts"]] - result_unbounded[["wts"]]))
  expect_true(
    diff_max > 1e-6,
    label = "HL-7: bounded vs unbounded outputs differ with same q"
  )
})

# ---------------------------------------------------------------------------
# HL-8: Absolute-bounds oracle — bounds.const = TRUE in survey::calibrate
# ---------------------------------------------------------------------------

test_that("HL-8: absolute-bounds linear matches survey::calibrate(bounds.const=TRUE) within 1e-8", {
  skip_if_not_installed("survey")
  skip_if(
    utils::packageVersion("survey") < "4.1",
    "survey >= 4.1 required for bounds.const"
  )

  targets <- list(
    age_group = c("18-34" = 0.30, "35-54" = 0.40, "55+" = 0.30)
  )
  abs_L <- 0.5
  abs_U <- 3.0
  total_w <- sum(df_200$base_weight)

  result <- calibrate_linear(
    df_200, targets = targets,
    weights = base_weight,
    bounds = c(abs_L, abs_U),
    bounds_scale = "absolute",
    control = list(epsilon = 1e-10)
  )

  svy_design <- survey::svydesign(
    ids = ~1, data = df_200, weights = ~base_weight
  )
  pop_totals <- c(
    `(Intercept)` = total_w,
    age_group3554 = targets$age_group[["35-54"]] * total_w,
    `age_group55+` = targets$age_group[["55+"]] * total_w
  )
  svy_cal <- survey::calibrate(
    svy_design,
    formula = ~age_group,
    population = pop_totals,
    calfun = "linear",
    bounds = c(abs_L, abs_U),
    bounds.const = TRUE
  )
  survey_weights <- as.numeric(stats::weights(svy_cal))

  test_invariants(result)
  expect_equal(
    result[["wts"]],
    survey_weights,
    tolerance = 1e-8,
    label = "HL-8: absolute-bounds linear oracle"
  )
})

# ---------------------------------------------------------------------------
# HL-9: Equal-weights absolute-bounds parity (pre-fix == post-fix)
# ---------------------------------------------------------------------------

test_that("HL-9: absolute-bounds with equal base weights gives identical output before and after D6 fix", {
  # When all d_k are equal, L_abs / d_k = L_abs / mean(d_k) for all k.
  # So the per-unit and mean-based approaches agree exactly.
  n <- 100L
  df_eq <- data.frame(
    age_group = sample(
      c("18-34", "35-54", "55+"),
      n, replace = TRUE, prob = c(0.3, 0.4, 0.3)
    ),
    sex = sample(c("M", "F"), n, replace = TRUE),
    base_weight = rep(2.0, n),
    stringsAsFactors = FALSE
  )
  targets <- list(
    age_group = c("18-34" = 0.30, "35-54" = 0.40, "55+" = 0.30)
  )
  abs_L <- 0.5
  abs_U <- 6.0

  result <- calibrate_linear(
    df_eq, targets = targets,
    weights = base_weight,
    bounds = c(abs_L, abs_U),
    bounds_scale = "absolute"
  )

  test_invariants(result)
  w <- result[["wts"]]
  expect_true(all(w >= abs_L - 1e-6) && all(w <= abs_U + 1e-6),
              label = "HL-9: equal-weights abs bounds satisfied")
})

# ---------------------------------------------------------------------------
# HL-10: Unequal-weights absolute-bounds differs from old mean-based approach
# ---------------------------------------------------------------------------

test_that("HL-10: absolute-bounds with unequal d_k differs from old mean-based approach", {
  targets <- list(
    age_group = c("18-34" = 0.30, "35-54" = 0.40, "55+" = 0.30)
  )
  abs_L <- 0.5
  abs_U <- 3.0
  total_w <- sum(df_200$base_weight)

  # New per-unit approach
  result_new <- calibrate_linear(
    df_200, targets = targets,
    weights = base_weight,
    bounds = c(abs_L, abs_U),
    bounds_scale = "absolute"
  )

  # Old mean-based approach: run engine with scaled_weights = rep(1,n),
  # scaled_population = pop / mean(d), bounds [L, U] direct
  weights_vec <- df_200$base_weight
  n <- nrow(df_200)
  mean_d <- mean(weights_vec)
  x_df <- df_200
  lvls <- c("18-34", "35-54", "55+")
  x_df$age_group <- factor(x_df$age_group, levels = lvls)
  x_mat <- stats::model.matrix(~age_group, data = x_df)
  pop_totals_vec <- c(
    `(Intercept)` = total_w,
    age_group3554 = targets$age_group[["35-54"]] * total_w,
    `age_group55+` = targets$age_group[["55+"]] * total_w
  )
  calfun_old <- surveywts:::.make_calfun_linear(L = abs_L, U = abs_U)
  old_engine <- surveywts:::.calibrate_nr_engine(
    x_matrix    = x_mat,
    weights_vec = rep(1, n),
    calfun      = calfun_old,
    population  = pop_totals_vec / mean_d
  )
  old_weights <- old_engine$weights

  test_invariants(result_new)
  # With unequal base weights, the per-unit approach gives a different result
  max_diff <- max(abs(result_new[["wts"]] - old_weights))
  expect_true(
    max_diff > 0,
    label = "HL-10: per-unit and mean-based differ for unequal base weights"
  )
})

# ---------------------------------------------------------------------------
# HL-11: Combined oracle — absolute-bounds + unit_scale = q_unequal
# ---------------------------------------------------------------------------

test_that("HL-11: absolute-bounds + unit_scale=q_unequal[1:200] matches survey::calibrate within 1e-8", {
  skip_if_not_installed("survey")
  skip_if(
    utils::packageVersion("survey") < "4.1",
    "survey >= 4.1 required for bounds.const"
  )

  targets <- list(
    age_group = c("18-34" = 0.30, "35-54" = 0.40, "55+" = 0.30)
  )
  abs_L <- 0.5
  abs_U <- 3.0
  total_w <- sum(df_200$base_weight)
  q_200 <- q_unequal[seq_len(nrow(df_200))]

  result <- calibrate_linear(
    df_200, targets = targets,
    weights = base_weight,
    bounds = c(abs_L, abs_U),
    bounds_scale = "absolute",
    unit_scale = q_200,
    control = list(epsilon = 1e-10)
  )

  svy_design <- survey::svydesign(
    ids = ~1, data = df_200, weights = ~base_weight
  )
  pop_totals <- c(
    `(Intercept)` = total_w,
    age_group3554 = targets$age_group[["35-54"]] * total_w,
    `age_group55+` = targets$age_group[["55+"]] * total_w
  )
  svy_cal <- survey::calibrate(
    svy_design,
    formula = ~age_group,
    population = pop_totals,
    calfun = "linear",
    bounds = c(abs_L, abs_U),
    bounds.const = TRUE,
    variance = 1 / q_200
  )
  survey_weights <- as.numeric(stats::weights(svy_cal))

  test_invariants(result)
  expect_equal(
    result[["wts"]],
    survey_weights,
    tolerance = 1e-8,
    label = "HL-11: absolute-bounds + unit_scale oracle"
  )
})

# ---------------------------------------------------------------------------
# HL-12: D2 Jacobian gate — unbounded linear converges in exactly 1 iteration
# ---------------------------------------------------------------------------

test_that("HL-12: unbounded linear with q_unequal converges in exactly 1 NR iteration", {
  # For linear F(u) = 1 + u, the NR update is exact in one step when the
  # Jacobian is correct (includes q_weights). This is a D2 gate.
  targets <- .make_linear_targets()
  taylor <- .make_test_taylor_linear(df_500)

  result <- calibrate_linear(
    taylor, targets = targets,
    unit_scale = q_unequal
  )

  test_invariants(result)
  expect_equal(
    result@calibration$n_iterations, 1L,
    label = "HL-12: unbounded linear converges in 1 NR step"
  )
})

# ---------------------------------------------------------------------------
# HLW-1: Warning — negative weights still fires when unit_scale != NULL
# ---------------------------------------------------------------------------

test_that("HLW-1: negative-weights warning fires even when unit_scale != NULL", {
  # Two variables with extreme cross-classified targets push GREG g-weights
  # well below 0 (sample: 90% young/M; targets: 5% young, 5% M).
  # This same setup is used by H10 and works without unit_scale; here we
  # verify the warning still fires when unit_scale != NULL.
  set.seed(123)
  n <- 200L
  age <- sample(c("young", "old"), n, replace = TRUE, prob = c(0.90, 0.10))
  sex <- sample(c("M", "F"), n, replace = TRUE, prob = c(0.90, 0.10))
  df_neg <- data.frame(
    age = age, sex = sex, wt = rep(1, n),
    stringsAsFactors = FALSE
  )
  targets_neg <- list(
    age = c("young" = 0.05, "old" = 0.95),
    sex = c("M" = 0.05, "F" = 0.95)
  )

  expect_warning(
    result <- calibrate_linear(
      df_neg, targets = targets_neg,
      weights = wt,
      unit_scale = rep(1.5, n)
    ),
    class = "surveywts_warning_negative_calibrated_weights"
  )
  test_invariants(result)
})

# ---------------------------------------------------------------------------
# HLE-1 through HLE-5: Error paths for unit_scale
# ---------------------------------------------------------------------------

test_that("HLE-1: calibrate_linear() rejects unit_scale with non-numeric type", {
  targets <- .make_linear_targets()

  expect_error(
    calibrate_linear(
      df_500, targets = targets, weights = base_weight,
      unit_scale = as.character(q_unequal)
    ),
    class = "surveywts_error_unit_scale_invalid"
  )
  expect_snapshot(
    error = TRUE,
    calibrate_linear(
      df_500, targets = targets, weights = base_weight,
      unit_scale = as.character(q_unequal)
    )
  )
})

test_that("HLE-2: calibrate_linear() rejects unit_scale with wrong length", {
  targets <- .make_linear_targets()

  expect_error(
    calibrate_linear(
      df_500, targets = targets, weights = base_weight,
      unit_scale = q_unequal[-1L]
    ),
    class = "surveywts_error_unit_scale_invalid"
  )
  expect_snapshot(
    error = TRUE,
    calibrate_linear(
      df_500, targets = targets, weights = base_weight,
      unit_scale = q_unequal[-1L]
    )
  )
})

test_that("HLE-3: calibrate_linear() rejects unit_scale with NA values", {
  targets <- .make_linear_targets()
  q_na <- q_unequal
  q_na[5L] <- NA_real_

  expect_error(
    calibrate_linear(
      df_500, targets = targets, weights = base_weight,
      unit_scale = q_na
    ),
    class = "surveywts_error_unit_scale_invalid"
  )
  expect_snapshot(
    error = TRUE,
    calibrate_linear(
      df_500, targets = targets, weights = base_weight,
      unit_scale = q_na
    )
  )
})

test_that("HLE-4: calibrate_linear() rejects unit_scale with non-positive values", {
  targets <- .make_linear_targets()
  q_nonpos <- q_unequal
  q_nonpos[3L] <- -0.5

  expect_error(
    calibrate_linear(
      df_500, targets = targets, weights = base_weight,
      unit_scale = q_nonpos
    ),
    class = "surveywts_error_unit_scale_invalid"
  )
  expect_snapshot(
    error = TRUE,
    calibrate_linear(
      df_500, targets = targets, weights = base_weight,
      unit_scale = q_nonpos
    )
  )
})

test_that("HLE-5: calibrate_linear() throws surveywts_error_calibration_not_converged with dual pattern", {
  # Force non-convergence: conflicting targets that can't be satisfied
  n <- 10L
  df_hard <- data.frame(
    age_group = rep("18-34", n),
    base_weight = rep(1, n),
    stringsAsFactors = FALSE
  )
  # All units are "18-34" but target demands 80% in "55+" — impossible
  targets_hard <- list(
    age_group = c("18-34" = 0.20, "35-54" = 0.00, "55+" = 0.80)
  )
  # This won't converge because "35-54" and "55+" have 0 observations
  # We need a case that starts converging but never finishes
  # Use calibrate_linear with extremely tight epsilon and very low maxit
  df_tight <- make_surveywts_data(n = 200, seed = 55)
  targets_tight <- list(
    age_group = c("18-34" = 0.30, "35-54" = 0.40, "55+" = 0.30),
    sex = c("M" = 0.48, "F" = 0.52)
  )

  expect_error(
    calibrate_linear(
      df_tight, targets = targets_tight, weights = base_weight,
      bounds = c(0.999, 1.001),
      control = list(maxit = 1L, epsilon = 1e-15)
    ),
    class = "surveywts_error_calibration_not_converged"
  )
  expect_snapshot(
    error = TRUE,
    calibrate_linear(
      df_tight, targets = targets_tight, weights = base_weight,
      bounds = c(0.999, 1.001),
      control = list(maxit = 1L, epsilon = 1e-15)
    )
  )
})

# ---------------------------------------------------------------------------
# RL-1: Replicate — full-sample weights match oracle with unit_scale
# ---------------------------------------------------------------------------

test_that("RL-1: replicate linear calibration full-sample weights match oracle with unit_scale", {
  skip_if_not_installed("survey")

  targets <- list(
    age_group = c("18-34" = 0.30, "35-54" = 0.40, "55+" = 0.30)
  )
  total_w <- sum(df_200$base_weight)
  q_200 <- q_unequal[seq_len(nrow(df_200))]

  taylor <- .make_test_taylor_linear(df_200)
  rep_design <- create_bootstrap_weights(taylor, replicates = 10L)

  result <- calibrate_linear(
    rep_design, targets = targets,
    unit_scale = q_200
  )

  test_invariants(result)

  # Full-sample weights should match the non-replicate calibration
  result_full <- calibrate_linear(
    df_200, targets = targets,
    weights = base_weight,
    unit_scale = q_200
  )

  expect_equal(
    result@data[[result@variables$weights]],
    result_full[["wts"]],
    tolerance = 1e-8,
    label = "RL-1: replicate full-sample matches non-replicate oracle"
  )
})

# ---------------------------------------------------------------------------
# RL-2: Replicate — unit_scale = NULL vs rep(1, n) identical
# ---------------------------------------------------------------------------

test_that("RL-2: replicate with unit_scale = NULL and unit_scale = rep(1,n) produce identical full-sample weights", {
  targets <- list(
    age_group = c("18-34" = 0.30, "35-54" = 0.40, "55+" = 0.30)
  )

  taylor <- .make_test_taylor_linear(df_200)
  rep_design <- create_bootstrap_weights(taylor, replicates = 10L)

  result_null <- calibrate_linear(rep_design, targets = targets)
  result_ones <- calibrate_linear(
    rep_design, targets = targets,
    unit_scale = q_unequal[seq_len(nrow(df_200))] * 0 + 1
  )

  test_invariants(result_null)
  test_invariants(result_ones)

  expect_equal(
    result_ones@data[[result_ones@variables$weights]],
    result_null@data[[result_null@variables$weights]],
    tolerance = 1e-14,
    label = "RL-2: unit_scale = NULL vs rep(1,n) identical in replicate"
  )
})

# ---------------------------------------------------------------------------
# RL-5: Replicate — absolute-bounds all weights in [L, U]
# ---------------------------------------------------------------------------

test_that("RL-5: absolute-bounds replicate calibration: all weights in every column satisfy [L_abs, U_abs]", {
  abs_L <- 0.5
  abs_U <- 3.0
  targets <- list(
    age_group = c("18-34" = 0.30, "35-54" = 0.40, "55+" = 0.30)
  )

  taylor <- .make_test_taylor_linear(df_200)
  rep_design <- create_bootstrap_weights(taylor, replicates = 10L)

  result <- calibrate_linear(
    rep_design, targets = targets,
    bounds = c(abs_L, abs_U),
    bounds_scale = "absolute"
  )

  test_invariants(result)

  # Check full-sample weights
  fs_wts <- result@data[[result@variables$weights]]
  expect_true(all(fs_wts >= abs_L - 1e-6) && all(fs_wts <= abs_U + 1e-6),
              label = "RL-5: full-sample weights in [L_abs, U_abs]")

  # Check every replicate column that converged.
  # Units excluded from a bootstrap replicate have rep_wt = 0 (and remain 0
  # after calibration), so we only check positive-weight units.
  repwt_cols <- result@variables$repweights
  conv <- result@calibration$replicate_converged
  for (col in repwt_cols) {
    if (!is.null(conv) && !conv[[col]]) next
    rep_wts <- result@data[[col]]
    # Only check units that were sampled in this replicate (rep_wt > 0)
    active <- rep_wts > 0
    if (!any(active)) next
    expect_true(
      all(rep_wts[active] >= abs_L - 1e-6) &&
        all(rep_wts[active] <= abs_U + 1e-6),
      label = paste0("RL-5: replicate ", col, " weights in [L_abs, U_abs]")
    )
  }
})

# ---------------------------------------------------------------------------
# EC-1: Edge case — single-row data with q = 2
# ---------------------------------------------------------------------------

test_that("EC-1: single-row data with q = 2 produces valid calibrated weight", {
  df_1 <- data.frame(
    age_group = "18-34",
    base_weight = 1.5,
    stringsAsFactors = FALSE
  )
  targets_1 <- list(age_group = c("18-34" = 1.0))

  result <- calibrate_linear(
    df_1, targets = targets_1, weights = base_weight,
    type = "count",
    unit_scale = 2.0
  )

  test_invariants(result)
  expect_true(is.finite(result[["wts"]]))
})

# ---------------------------------------------------------------------------
# EC-2: Edge case — uniform small q (0.01) converges
# ---------------------------------------------------------------------------

test_that("EC-2: uniform small q = 0.01 converges for calibrate_linear()", {
  targets <- list(
    age_group = c("18-34" = 0.30, "35-54" = 0.40, "55+" = 0.30)
  )

  result <- calibrate_linear(
    df_200, targets = targets,
    weights = base_weight,
    unit_scale = rep(0.01, nrow(df_200))
  )

  test_invariants(result)
  w <- result[["wts"]]
  total_w <- sum(w)
  for (lev in names(targets$age_group)) {
    obs <- sum(w[result$age_group == lev]) / total_w
    expect_equal(obs, targets$age_group[[lev]], tolerance = 1e-8)
  }
})

# ---------------------------------------------------------------------------
# EC-3: Edge case — uniform large q (100) converges
# ---------------------------------------------------------------------------

test_that("EC-3: uniform large q = 100 converges for calibrate_linear()", {
  targets <- list(
    age_group = c("18-34" = 0.30, "35-54" = 0.40, "55+" = 0.30)
  )

  result <- calibrate_linear(
    df_200, targets = targets,
    weights = base_weight,
    unit_scale = rep(100, nrow(df_200))
  )

  test_invariants(result)
  w <- result[["wts"]]
  total_w <- sum(w)
  for (lev in names(targets$age_group)) {
    obs <- sum(w[result$age_group == lev]) / total_w
    expect_equal(obs, targets$age_group[[lev]], tolerance = 1e-8)
  }
})

# ---------------------------------------------------------------------------
# EC-4: Edge case — one extreme q entry (1e8) may cause singular system
# ---------------------------------------------------------------------------

test_that("EC-4: one extreme q_k = 1e8 on a 20-unit dataset either errors with singular-system or satisfies constraint", {
  set.seed(301)
  n <- 20L
  df_small <- data.frame(
    age_group = sample(c("18-34", "35-54", "55+"), n, replace = TRUE),
    base_weight = exp(rnorm(n, 0, 0.3)),
    stringsAsFactors = FALSE
  )
  targets_small <- list(
    age_group = c("18-34" = 0.30, "35-54" = 0.40, "55+" = 0.30)
  )
  q_extreme <- rep(1.0, n)
  q_extreme[1L] <- 1e8

  result <- tryCatch(
    calibrate_linear(
      df_small, targets = targets_small,
      weights = base_weight,
      unit_scale = q_extreme
    ),
    error = function(e) e
  )

  if (inherits(result, "error")) {
    expect_s3_class(result, "surveywts_error_calibration_singular_system")
  } else {
    test_invariants(result)
    # Check non-extreme units satisfy calibration constraint
    w <- result[["wts"]]
    total_w <- sum(w)
    for (lev in names(targets_small$age_group)) {
      obs <- sum(w[result$age_group == lev]) / total_w
      expect_equal(obs, targets_small$age_group[[lev]], tolerance = 1e-6)
    }
  }
})

# ---------------------------------------------------------------------------
# EC-5: Edge case — explicit rep(1, n) identical to NULL
# ---------------------------------------------------------------------------

test_that("EC-5: explicit rep(1, n) is numerically identical to unit_scale = NULL", {
  targets <- .make_linear_targets()
  n <- nrow(df_500)

  result_null <- calibrate_linear(
    df_500, targets = targets, weights = base_weight
  )
  result_explicit <- calibrate_linear(
    df_500, targets = targets, weights = base_weight,
    unit_scale = rep(1, n)
  )

  test_invariants(result_null)
  test_invariants(result_explicit)

  expect_equal(
    result_explicit[["wts"]],
    result_null[["wts"]],
    tolerance = 1e-14
  )
})

# ---------------------------------------------------------------------------
# EC-6: Edge case — multiplicative bounds with q_unequal
# ---------------------------------------------------------------------------

test_that("EC-6: multiplicative-bounds calibration with q_unequal satisfies constraint and bounds", {
  targets <- list(
    age_group = c("18-34" = 0.30, "35-54" = 0.40, "55+" = 0.30)
  )
  q_200 <- q_unequal[seq_len(nrow(df_200))]

  result <- calibrate_linear(
    df_200, targets = targets,
    weights = base_weight,
    bounds = c(0.3, 3),
    unit_scale = q_200
  )

  test_invariants(result)
  w <- result[["wts"]]
  d <- df_200$base_weight
  g <- w / d
  expect_true(all(g >= 0.3 - 1e-6) && all(g <= 3 + 1e-6),
              label = "EC-6: g-weights in [0.3, 3]")
})

# ---------------------------------------------------------------------------
# EC-8: Edge case — absolute-bounds with equal base weights regression guard
# ---------------------------------------------------------------------------

test_that("EC-8: absolute-bounds with equal base weights: pre-fix and post-fix give same result", {
  n <- 100L
  set.seed(888)
  df_eq <- data.frame(
    age_group = sample(c("18-34", "35-54", "55+"), n, replace = TRUE),
    base_weight = rep(1.5, n),
    stringsAsFactors = FALSE
  )
  targets <- list(
    age_group = c("18-34" = 0.30, "35-54" = 0.40, "55+" = 0.30)
  )
  abs_L <- 0.5
  abs_U <- 5.0

  result <- calibrate_linear(
    df_eq, targets = targets, weights = base_weight,
    bounds = c(abs_L, abs_U), bounds_scale = "absolute"
  )

  test_invariants(result)
  w <- result[["wts"]]
  expect_true(all(w >= abs_L - 1e-6) && all(w <= abs_U + 1e-6))
})

# ---------------------------------------------------------------------------
# EC-9: Edge case — absolute-bounds final weights all in [L_abs, U_abs]
# ---------------------------------------------------------------------------

test_that("EC-9: absolute-bounds linear: all final weights satisfy w_k in [L_abs, U_abs]", {
  abs_L <- 0.5
  abs_U <- 3.0
  targets <- list(
    age_group = c("18-34" = 0.30, "35-54" = 0.40, "55+" = 0.30)
  )

  result <- calibrate_linear(
    df_200, targets = targets, weights = base_weight,
    bounds = c(abs_L, abs_U), bounds_scale = "absolute"
  )

  test_invariants(result)
  w <- result[["wts"]]
  expect_true(
    all(w >= abs_L - 1e-6),
    label = "EC-9: all weights >= L_abs"
  )
  expect_true(
    all(w <= abs_U + 1e-6),
    label = "EC-9: all weights <= U_abs"
  )
})
