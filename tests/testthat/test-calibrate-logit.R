# tests/testthat/test-calibrate-logit.R
#
# Full test suite for calibrate_logit()
# Tests are written BEFORE implementation (TDD red phase).
#
# Test sections:
#   H1-H10  — Happy paths
#   N1      — Oracle / numerical correctness vs survey::calibrate(calfun="logit")
#   E1-E23  — Error paths (dual: expect_error + expect_snapshot)
#   W1-W3   — Warning paths
#   EC1-EC4 — Edge cases
#   H_abs   — Absolute bounds happy path
#   E_abs   — Absolute bounds error path

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

.make_logit_targets <- function(type = "prop") {
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

.make_test_taylor_logit <- function(df, weight_col = "base_weight") {
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

.make_test_nonprob_logit <- function(df, weight_col = "base_weight") {
  surveycore::survey_nonprob(
    data = df,
    variables = list(weights = weight_col)
  )
}

# ---------------------------------------------------------------------------
# H1: Happy path — plain data.frame, type = "prop", default bounds
# ---------------------------------------------------------------------------

test_that("H1: calibrate_logit() returns weighted_df for data.frame (prop, default bounds)", {
  df <- make_surveywts_data(seed = 1)
  targets <- .make_logit_targets()

  result <- calibrate_logit(df, targets = targets, weights = base_weight)

  test_invariants(result)
  expect_true(inherits(result, "weighted_df"))
  expect_identical(attr(result, "weight_col"), "wts")

  # Calibration constraint check
  w <- result[["wts"]]
  total_w <- sum(w)
  for (var in names(targets)) {
    for (lev in names(targets[[var]])) {
      obs_prop <- sum(w[result[[var]] == lev]) / total_w
      expect_equal(obs_prop, targets[[var]][[lev]], tolerance = 1e-6,
                   label = paste0(var, "=", lev))
    }
  }

  # History entry check
  h <- attr(result, "weighting_history")
  expect_equal(length(h), 1L)
  expect_identical(h[[1L]]$operation, "calibrate_logit")
})

# ---------------------------------------------------------------------------
# H2: Happy path — type = "count"
# ---------------------------------------------------------------------------

test_that("H2: calibrate_logit() returns weighted_df for data.frame (count)", {
  df <- make_surveywts_data(n = 500, seed = 2)
  targets <- .make_logit_targets("count")

  result <- calibrate_logit(
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

test_that("H3: calibrate_logit() preserves survey_taylor class and populates @calibration", {
  df <- make_surveywts_data(seed = 3)
  taylor <- .make_test_taylor_logit(df)
  targets <- .make_logit_targets()

  result <- calibrate_logit(taylor, targets = targets)

  test_invariants(result)
  expect_true(S7::S7_inherits(result, surveycore::survey_taylor))

  # @calibration populated
  cal <- result@calibration
  expect_false(is.null(cal))
  expect_true(is.list(cal))
  expect_true("method" %in% names(cal))
  expect_identical(cal$method, "logit")
  expect_true("lambda" %in% names(cal))
  expect_true(is.numeric(cal$lambda))
})

# ---------------------------------------------------------------------------
# H4: Happy path — survey_nonprob input: class preserved
# ---------------------------------------------------------------------------

test_that("H4: calibrate_logit() preserves survey_nonprob class", {
  df <- make_surveywts_data(seed = 4)
  nonprob <- .make_test_nonprob_logit(df)
  targets <- .make_logit_targets()

  result <- calibrate_logit(nonprob, targets = targets)

  test_invariants(result)
  expect_true(S7::S7_inherits(result, surveycore::survey_nonprob))

  cal <- result@calibration
  expect_false(is.null(cal))
  expect_identical(cal$method, "logit")
})

# ---------------------------------------------------------------------------
# H5: Happy path — weighted_df input: history entry appended
# ---------------------------------------------------------------------------

test_that("H5: calibrate_logit() accepts weighted_df and appends history entry", {
  df <- make_surveywts_data(seed = 5)
  targets <- .make_logit_targets()

  # First pass: make a weighted_df via calibrate_logit itself
  wdf <- calibrate_logit(df, targets = targets, weights = base_weight)

  # Second pass: calibrate the weighted_df
  result <- calibrate_logit(wdf, targets = targets)

  test_invariants(result)
  expect_true(inherits(result, "weighted_df"))

  h <- attr(result, "weighting_history")
  expect_equal(length(h), 2L)
  expect_identical(h[[2L]]$operation, "calibrate_logit")
})

# ---------------------------------------------------------------------------
# H6: Happy path — @calibration$method = "logit"; @calibration$bounds_scale = "multiplicative"
# ---------------------------------------------------------------------------

test_that("H6: calibrate_logit() method='logit'; bounds_scale='multiplicative' by default", {
  df <- make_surveywts_data(seed = 6)
  taylor <- .make_test_taylor_logit(df)
  targets <- .make_logit_targets()

  result <- calibrate_logit(taylor, targets = targets)

  test_invariants(result)
  expect_identical(result@calibration$method, "logit")
  expect_identical(result@calibration$bounds_scale, "multiplicative")
})

test_that("H6b: data.frame with default bounds produces valid weighted_df", {
  df <- make_surveywts_data(seed = 6)
  targets <- .make_logit_targets()

  result <- calibrate_logit(
    df,
    targets = targets,
    weights = base_weight
  )

  test_invariants(result)
  expect_true(inherits(result, "weighted_df"))
  w <- result[["wts"]]
  expect_true(all(is.finite(w)))
  expect_true(all(w > 0))
})

# ---------------------------------------------------------------------------
# H7: Happy path — unit_scale provided; @calibration$q_weights matches
# ---------------------------------------------------------------------------

test_that("H7: unit_scale arg populates @calibration$q_weights", {
  df <- make_surveywts_data(n = 100, seed = 7)
  taylor <- .make_test_taylor_logit(df)
  targets <- .make_logit_targets()

  q <- rep(1.5, nrow(df))
  result <- calibrate_logit(taylor, targets = targets, unit_scale = q)

  test_invariants(result)
  expect_equal(result@calibration$q_weights, q, tolerance = 1e-12)
})

# ---------------------------------------------------------------------------
# H8: Happy path — unit_scale = NULL gives @calibration$q_weights = NULL
# ---------------------------------------------------------------------------

test_that("H8: unit_scale = NULL gives is.null(@calibration$q_weights) = TRUE", {
  df <- make_surveywts_data(n = 100, seed = 8)
  taylor <- .make_test_taylor_logit(df)
  targets <- .make_logit_targets()

  result <- calibrate_logit(taylor, targets = targets, unit_scale = NULL)

  test_invariants(result)
  expect_null(result@calibration$q_weights)
})

# ---------------------------------------------------------------------------
# H7b: Happy path — reference_design sets targets_from_reference = TRUE in history
# ---------------------------------------------------------------------------

test_that("H7b: reference_design sets targets_from_reference = TRUE in weighting history", {
  df <- make_surveywts_data(n = 100, seed = 71)
  taylor <- .make_test_taylor_logit(df)
  ref <- surveycore::survey_taylor(
    data = df,
    variables = list(weights = "base_weight")
  )
  targets <- .make_logit_targets()

  result <- calibrate_logit(taylor, targets = targets,
                            reference_design = ref)

  test_invariants(result)
  hist <- result@metadata@weighting_history
  entry <- hist[[length(hist)]]
  expect_true(entry$parameters$targets_from_reference)
})

# ---------------------------------------------------------------------------
# H9: Happy path — Format B (long data frame) targets accepted
# ---------------------------------------------------------------------------

test_that("H9: calibrate_logit() accepts Format B (long data frame) targets", {
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

  result <- calibrate_logit(df, targets = targets_b, weights = base_weight)

  test_invariants(result)
  expect_true(inherits(result, "weighted_df"))
})

# ---------------------------------------------------------------------------
# H10: Happy path — custom (narrower) bounds
# ---------------------------------------------------------------------------

test_that("H10: calibrate_logit() works with narrower bounds = c(0.5, 2)", {
  df <- make_surveywts_data(seed = 10)
  taylor <- .make_test_taylor_logit(df)
  targets <- .make_logit_targets()

  result <- calibrate_logit(
    taylor, targets = targets,
    bounds = c(0.5, 2)
  )

  test_invariants(result)
  expect_identical(result@calibration$method, "logit")

  # g-weights in open interval (L, U) = (0.5, 2)
  L <- 0.5
  U <- 2
  base_wts <- df$base_weight
  cal_wts <- result@data[[result@variables$weights]]
  g <- cal_wts / base_wts
  expect_true(all(g > L))
  expect_true(all(g < U))
})

# ---------------------------------------------------------------------------
# N1: Oracle — compare against survey::calibrate(calfun="logit")
# ---------------------------------------------------------------------------

test_that("N1: calibrate_logit() matches survey::calibrate(calfun='logit') within 1e-8", {
  skip_if_not_installed("survey")

  df <- make_surveywts_data(n = 200, seed = 101)

  # Single variable for clean comparison
  targets_a <- list(
    age_group = c("18-34" = 0.30, "35-54" = 0.40, "55+" = 0.30)
  )

  result <- calibrate_logit(df, targets = targets_a, weights = base_weight)
  wts_ours <- result[["wts"]]

  # survey::calibrate() with calfun = "logit" uses default bounds c(1e-6, 1e6)
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
    calfun = "logit",
    bounds = c(1e-6, 1e6)
  ))
  wts_survey <- as.numeric(weights(calib_design))

  expect_equal(wts_ours, wts_survey, tolerance = 1e-8)
})

# ---------------------------------------------------------------------------
# E1: Error — unsupported input class
# ---------------------------------------------------------------------------

test_that("E1: calibrate_logit() throws surveywts_error_unsupported_class for bad input", {
  expect_error(
    calibrate_logit(list(x = 1:3), targets = list()),
    class = "surveywts_error_unsupported_class"
  )
  expect_snapshot(
    error = TRUE,
    calibrate_logit(list(x = 1:3), targets = list())
  )
})

# ---------------------------------------------------------------------------
# E2: Error — empty data
# ---------------------------------------------------------------------------

test_that("E2: calibrate_logit() throws surveywts_error_empty_data for 0-row input", {
  empty_df <- data.frame(
    age_group = character(0),
    base_weight = numeric(0),
    stringsAsFactors = FALSE
  )
  targets <- list(age_group = c("18-34" = 1.0))

  expect_error(
    calibrate_logit(empty_df, targets = targets, weights = base_weight),
    class = "surveywts_error_empty_data"
  )
  expect_snapshot(
    error = TRUE,
    calibrate_logit(empty_df, targets = targets, weights = base_weight)
  )
})

# ---------------------------------------------------------------------------
# E3: Error — wt_name not scalar
# ---------------------------------------------------------------------------

test_that("E3: calibrate_logit() throws surveywts_error_wt_name_not_scalar", {
  df <- make_surveywts_data(n = 50, seed = 3)
  targets <- .make_logit_targets()

  expect_error(
    calibrate_logit(
      df, targets = targets, weights = base_weight,
      wt_name = c("a", "b")
    ),
    class = "surveywts_error_wt_name_not_scalar"
  )
  expect_snapshot(
    error = TRUE,
    calibrate_logit(
      df, targets = targets, weights = base_weight,
      wt_name = c("a", "b")
    )
  )
})

# ---------------------------------------------------------------------------
# E4: Error — wt_name empty
# ---------------------------------------------------------------------------

test_that("E4: calibrate_logit() throws surveywts_error_wt_name_empty for NA wt_name", {
  df <- make_surveywts_data(n = 50, seed = 4)
  targets <- .make_logit_targets()

  expect_error(
    calibrate_logit(
      df, targets = targets, weights = base_weight,
      wt_name = NA_character_
    ),
    class = "surveywts_error_wt_name_empty"
  )
  expect_snapshot(
    error = TRUE,
    calibrate_logit(
      df, targets = targets, weights = base_weight,
      wt_name = NA_character_
    )
  )
})

test_that("E4b: calibrate_logit() throws surveywts_error_wt_name_empty for empty string", {
  df <- make_surveywts_data(n = 50, seed = 4)
  targets <- .make_logit_targets()

  expect_error(
    calibrate_logit(
      df, targets = targets, weights = base_weight,
      wt_name = ""
    ),
    class = "surveywts_error_wt_name_empty"
  )
})

# ---------------------------------------------------------------------------
# E5: Error — reference_design not taylor
# ---------------------------------------------------------------------------

test_that("E5: calibrate_logit() throws surveywts_error_reference_design_not_taylor", {
  df <- make_surveywts_data(n = 50, seed = 5)
  targets <- .make_logit_targets()

  expect_error(
    calibrate_logit(
      df, targets = targets, weights = base_weight,
      reference_design = "not_a_design"
    ),
    class = "surveywts_error_reference_design_not_taylor"
  )
  expect_snapshot(
    error = TRUE,
    calibrate_logit(
      df, targets = targets, weights = base_weight,
      reference_design = "not_a_design"
    )
  )
})

# ---------------------------------------------------------------------------
# E6: Error — weight column not found
# ---------------------------------------------------------------------------

test_that("E6: calibrate_logit() throws surveywts_error_weights_not_found", {
  df <- make_surveywts_data(n = 50, seed = 6)
  targets <- .make_logit_targets()

  expect_error(
    calibrate_logit(df, targets = targets, weights = nonexistent_col),
    class = "surveywts_error_weights_not_found"
  )
  expect_snapshot(
    error = TRUE,
    calibrate_logit(df, targets = targets, weights = nonexistent_col)
  )
})

# ---------------------------------------------------------------------------
# E7: Error — weight column not numeric
# ---------------------------------------------------------------------------

test_that("E7: calibrate_logit() throws surveywts_error_weights_not_numeric", {
  df <- make_surveywts_data(n = 50, seed = 7)
  df$bad_wt <- as.character(df$base_weight)
  targets <- .make_logit_targets()

  expect_error(
    calibrate_logit(df, targets = targets, weights = bad_wt),
    class = "surveywts_error_weights_not_numeric"
  )
  expect_snapshot(
    error = TRUE,
    calibrate_logit(df, targets = targets, weights = bad_wt)
  )
})

# ---------------------------------------------------------------------------
# E8: Error — weight column has non-positive values
# ---------------------------------------------------------------------------

test_that("E8: calibrate_logit() throws surveywts_error_weights_nonpositive", {
  df <- make_surveywts_data(n = 50, seed = 8)
  df$base_weight[1] <- 0
  targets <- .make_logit_targets()

  expect_error(
    calibrate_logit(df, targets = targets, weights = base_weight),
    class = "surveywts_error_weights_nonpositive"
  )
  expect_snapshot(
    error = TRUE,
    calibrate_logit(df, targets = targets, weights = base_weight)
  )
})

# ---------------------------------------------------------------------------
# E9: Error — weight column has NA
# ---------------------------------------------------------------------------

test_that("E9: calibrate_logit() throws surveywts_error_weights_na", {
  df <- make_surveywts_data(n = 50, seed = 9)
  df$base_weight[3] <- NA_real_
  targets <- .make_logit_targets()

  expect_error(
    calibrate_logit(df, targets = targets, weights = base_weight),
    class = "surveywts_error_weights_na"
  )
  expect_snapshot(
    error = TRUE,
    calibrate_logit(df, targets = targets, weights = base_weight)
  )
})

# ---------------------------------------------------------------------------
# E10: Error — targets variable not found in data
# ---------------------------------------------------------------------------

test_that("E10: calibrate_logit() throws surveywts_error_targets_variable_not_found", {
  df <- make_surveywts_data(n = 50, seed = 10)
  targets <- list(
    nonexistent_var = c("A" = 0.5, "B" = 0.5)
  )

  expect_error(
    calibrate_logit(df, targets = targets, weights = base_weight),
    class = "surveywts_error_targets_variable_not_found"
  )
  expect_snapshot(
    error = TRUE,
    calibrate_logit(df, targets = targets, weights = base_weight)
  )
})

# ---------------------------------------------------------------------------
# E11: Error — calibration variable is not categorical
# ---------------------------------------------------------------------------

test_that("E11: calibrate_logit() throws surveywts_error_variable_not_categorical", {
  df <- make_surveywts_data(n = 50, seed = 11)
  targets <- list(id = c(`1` = 0.5, `2` = 0.5))

  expect_error(
    calibrate_logit(df, targets = targets, weights = base_weight),
    class = "surveywts_error_variable_not_categorical"
  )
  expect_snapshot(
    error = TRUE,
    calibrate_logit(df, targets = targets, weights = base_weight)
  )
})

# ---------------------------------------------------------------------------
# E12: Error — calibration variable has NA
# ---------------------------------------------------------------------------

test_that("E12: calibrate_logit() throws surveywts_error_variable_has_na", {
  df <- make_surveywts_data(n = 50, seed = 12)
  df$age_group[1] <- NA_character_
  targets <- .make_logit_targets()

  expect_error(
    calibrate_logit(df, targets = targets, weights = base_weight),
    class = "surveywts_error_variable_has_na"
  )
  expect_snapshot(
    error = TRUE,
    calibrate_logit(df, targets = targets, weights = base_weight)
  )
})

# ---------------------------------------------------------------------------
# E13: Error — population level missing (data level absent from targets)
# ---------------------------------------------------------------------------

test_that("E13: calibrate_logit() throws surveywts_error_population_level_missing", {
  df <- make_surveywts_data(n = 50, seed = 13)
  # Missing "55+" level in targets
  targets <- list(
    age_group = c("18-34" = 0.50, "35-54" = 0.50)
  )

  expect_error(
    calibrate_logit(df, targets = targets, weights = base_weight),
    class = "surveywts_error_population_level_missing"
  )
  expect_snapshot(
    error = TRUE,
    calibrate_logit(df, targets = targets, weights = base_weight)
  )
})

# ---------------------------------------------------------------------------
# E14: Error — population level extra (targets level absent from data)
# ---------------------------------------------------------------------------

test_that("E14: calibrate_logit() throws surveywts_error_population_level_extra", {
  df <- make_surveywts_data(n = 50, seed = 14)
  targets <- list(
    age_group = c("18-34" = 0.25, "35-54" = 0.40, "55+" = 0.25, "65+" = 0.10)
  )

  expect_error(
    calibrate_logit(df, targets = targets, weights = base_weight),
    class = "surveywts_error_population_level_extra"
  )
  expect_snapshot(
    error = TRUE,
    calibrate_logit(df, targets = targets, weights = base_weight)
  )
})

# ---------------------------------------------------------------------------
# E15: Error — population totals invalid (prop doesn't sum to 1)
# ---------------------------------------------------------------------------

test_that("E15: calibrate_logit() throws surveywts_error_population_totals_invalid (prop != 1)", {
  df <- make_surveywts_data(n = 50, seed = 15)
  targets <- list(
    age_group = c("18-34" = 0.40, "35-54" = 0.40, "55+" = 0.40) # sums to 1.2
  )

  expect_error(
    calibrate_logit(df, targets = targets, weights = base_weight),
    class = "surveywts_error_population_totals_invalid"
  )
  expect_snapshot(
    error = TRUE,
    calibrate_logit(df, targets = targets, weights = base_weight)
  )
})

# ---------------------------------------------------------------------------
# E16: Error — population totals invalid (count <= 0)
# ---------------------------------------------------------------------------

test_that("E16: calibrate_logit() throws surveywts_error_population_totals_invalid (count <= 0)", {
  df <- make_surveywts_data(n = 50, seed = 16)
  targets <- list(
    age_group = c("18-34" = -10, "35-54" = 200, "55+" = 150)
  )

  expect_error(
    calibrate_logit(
      df, targets = targets, weights = base_weight,
      type = "count"
    ),
    class = "surveywts_error_population_totals_invalid"
  )
  expect_snapshot(
    error = TRUE,
    calibrate_logit(
      df, targets = targets, weights = base_weight,
      type = "count"
    )
  )
})

# ---------------------------------------------------------------------------
# E17: Error — margins format invalid
# ---------------------------------------------------------------------------

test_that("E17: calibrate_logit() throws surveywts_error_margins_format_invalid for bad targets", {
  df <- make_surveywts_data(n = 50, seed = 17)

  expect_error(
    calibrate_logit(df, targets = 42, weights = base_weight),
    class = "surveywts_error_margins_format_invalid"
  )
  expect_snapshot(
    error = TRUE,
    calibrate_logit(df, targets = 42, weights = base_weight)
  )
})

# ---------------------------------------------------------------------------
# E18: Error — bounds invalid for multiplicative (L >= 1)
# ---------------------------------------------------------------------------

test_that("E18: calibrate_logit() throws surveywts_error_bounds_invalid_calibration (L >= 1)", {
  df <- make_surveywts_data(n = 50, seed = 18)
  targets <- .make_logit_targets()

  expect_error(
    calibrate_logit(
      df, targets = targets, weights = base_weight,
      bounds = c(1.0, 3.0)
    ),
    class = "surveywts_error_bounds_invalid_calibration"
  )
  expect_snapshot(
    error = TRUE,
    calibrate_logit(
      df, targets = targets, weights = base_weight,
      bounds = c(1.0, 3.0)
    )
  )
})

# ---------------------------------------------------------------------------
# E19: Error — bounds invalid for multiplicative (U <= 1)
# ---------------------------------------------------------------------------

test_that("E19: calibrate_logit() throws surveywts_error_bounds_invalid_calibration (U <= 1)", {
  df <- make_surveywts_data(n = 50, seed = 19)
  targets <- .make_logit_targets()

  expect_error(
    calibrate_logit(
      df, targets = targets, weights = base_weight,
      bounds = c(0.3, 0.9)
    ),
    class = "surveywts_error_bounds_invalid_calibration"
  )
  expect_snapshot(
    error = TRUE,
    calibrate_logit(
      df, targets = targets, weights = base_weight,
      bounds = c(0.3, 0.9)
    )
  )
})

# ---------------------------------------------------------------------------
# E20: Error — unit_scale invalid (not numeric)
# ---------------------------------------------------------------------------

test_that("E20: calibrate_logit() throws surveywts_error_unit_scale_invalid (not numeric)", {
  df <- make_surveywts_data(n = 50, seed = 20)
  targets <- .make_logit_targets()

  expect_error(
    calibrate_logit(
      df, targets = targets, weights = base_weight,
      unit_scale = rep("1", nrow(df))
    ),
    class = "surveywts_error_unit_scale_invalid"
  )
  expect_snapshot(
    error = TRUE,
    calibrate_logit(
      df, targets = targets, weights = base_weight,
      unit_scale = rep("1", nrow(df))
    )
  )
})

# ---------------------------------------------------------------------------
# E21: Error — unit_scale invalid (wrong length)
# ---------------------------------------------------------------------------

test_that("E21: calibrate_logit() throws surveywts_error_unit_scale_invalid (wrong length)", {
  df <- make_surveywts_data(n = 50, seed = 21)
  targets <- .make_logit_targets()

  expect_error(
    calibrate_logit(
      df, targets = targets, weights = base_weight,
      unit_scale = rep(1, nrow(df) - 1)
    ),
    class = "surveywts_error_unit_scale_invalid"
  )
})

# ---------------------------------------------------------------------------
# E22: Error — calibration singular system
# ---------------------------------------------------------------------------

test_that("E22: calibrate_logit() throws surveywts_error_calibration_singular_system for degenerate model", {
  set.seed(22)
  n <- 50
  df <- data.frame(
    sex = sample(c("M", "F"), n, replace = TRUE),
    base_weight = rep(1, n),
    stringsAsFactors = FALSE
  )
  df$sex2 <- df$sex
  targets <- list(
    sex = c("M" = 0.50, "F" = 0.50),
    sex2 = c("M" = 0.50, "F" = 0.50)
  )

  expect_error(
    calibrate_logit(df, targets = targets, weights = base_weight),
    class = "surveywts_error_calibration_singular_system"
  )
})

# ---------------------------------------------------------------------------
# E23: Error — count marginal inconsistency across multiple variables
# ---------------------------------------------------------------------------

test_that("E23: calibrate_logit() throws surveywts_error_population_totals_invalid for inconsistent count marginals", {
  df <- make_surveywts_data(n = 100, seed = 23)
  targets <- list(
    age_group = c("18-34" = 150, "35-54" = 200, "55+" = 150), # N = 500
    sex       = c("M" = 300, "F" = 350)  # N = 650 -- inconsistent
  )

  expect_error(
    calibrate_logit(
      df, targets = targets, weights = base_weight,
      type = "count"
    ),
    class = "surveywts_error_population_totals_invalid"
  )
})

# ---------------------------------------------------------------------------
# E22b: Error — calibration not converged (maxit = 1 with non-trivial targets)
# ---------------------------------------------------------------------------

test_that("E22b: calibrate_logit() throws surveywts_error_calibration_not_converged for maxit = 1", {
  df <- make_surveywts_data(n = 200, seed = 221)
  targets <- list(
    age_group = c("18-34" = 0.10, "35-54" = 0.80, "55+" = 0.10),
    sex       = c("M" = 0.30, "F" = 0.70)
  )

  expect_error(
    calibrate_logit(
      df, targets = targets, weights = base_weight,
      control = list(maxit = 1L)
    ),
    class = "surveywts_error_calibration_not_converged"
  )
  expect_snapshot(
    error = TRUE,
    calibrate_logit(
      df, targets = targets, weights = base_weight,
      control = list(maxit = 1L)
    )
  )
})

# ---------------------------------------------------------------------------
# E23b: Error — unit_scale non-positive values
# ---------------------------------------------------------------------------

test_that("E23b: calibrate_logit() throws surveywts_error_unit_scale_invalid for non-positive unit_scale", {
  df <- make_surveywts_data(n = 50, seed = 231)
  targets <- .make_logit_targets()
  q <- rep(1, nrow(df))
  q[1] <- -1

  expect_error(
    calibrate_logit(
      df, targets = targets, weights = base_weight,
      unit_scale = q
    ),
    class = "surveywts_error_unit_scale_invalid"
  )
  expect_snapshot(
    error = TRUE,
    calibrate_logit(
      df, targets = targets, weights = base_weight,
      unit_scale = q
    )
  )
})

# ---------------------------------------------------------------------------
# Additional bounds error tests
# ---------------------------------------------------------------------------

test_that("calibrate_logit() throws surveywts_error_bounds_invalid_calibration for bounds length != 2", {
  df <- make_surveywts_data(n = 50, seed = 191)
  targets <- .make_logit_targets()

  expect_error(
    calibrate_logit(
      df, targets = targets, weights = base_weight,
      bounds = c(0.5, 2, 3)
    ),
    class = "surveywts_error_bounds_invalid_calibration"
  )
  expect_snapshot(
    error = TRUE,
    calibrate_logit(
      df, targets = targets, weights = base_weight,
      bounds = c(0.5, 2, 3)
    )
  )
})

test_that("calibrate_logit() throws surveywts_error_bounds_invalid_calibration for bounds with NA", {
  df <- make_surveywts_data(n = 50, seed = 192)
  targets <- .make_logit_targets()

  expect_error(
    calibrate_logit(
      df, targets = targets, weights = base_weight,
      bounds = c(0.5, NA_real_)
    ),
    class = "surveywts_error_bounds_invalid_calibration"
  )
})

test_that("calibrate_logit() throws surveywts_error_bounds_invalid_calibration for non-numeric bounds", {
  df <- make_surveywts_data(n = 50, seed = 193)
  targets <- .make_logit_targets()

  expect_error(
    calibrate_logit(
      df, targets = targets, weights = base_weight,
      bounds = c("0.5", "2")
    ),
    class = "surveywts_error_bounds_invalid_calibration"
  )
})

# ---------------------------------------------------------------------------
# W1: Warning — SRS assumption for plain data.frame + weights = NULL
# ---------------------------------------------------------------------------

test_that("W1: calibrate_logit() warns surveywts_warning_srs_no_weights for plain df + NULL weights", {
  df <- make_surveywts_data(n = 50, seed = 31)
  targets <- .make_logit_targets()

  expect_warning(
    result <- calibrate_logit(df, targets = targets),
    class = "surveywts_warning_srs_no_weights"
  )

  test_invariants(result)
  expect_true(inherits(result, "weighted_df"))
  # SRS assumption: sum of starting weights = n
  expect_equal(sum(result[["wts"]]), nrow(df), tolerance = 1e-6)
})

# ---------------------------------------------------------------------------
# W2: Warning — replicate calibration failed (replicate weight column error)
# ---------------------------------------------------------------------------

test_that("W2: calibrate_logit() warns surveywts_warning_replicate_calibration_failed for failing replicate", {
  df <- make_surveywts_data(n = 100, seed = 32)
  rep_design <- .make_empty_cell_replicate_design(df, "age_group")
  targets <- .make_logit_targets()

  expect_warning(
    result <- calibrate_logit(rep_design, targets = targets),
    class = "surveywts_warning_replicate_calibration_failed"
  )

  test_invariants(result)
  expect_true(S7::S7_inherits(result, surveycore::survey_replicate))
})

# ---------------------------------------------------------------------------
# W3: Warning — unrecognized control parameter
# ---------------------------------------------------------------------------

test_that("W3: calibrate_logit() warns surveywts_warning_control_param_ignored for unknown control key", {
  df <- make_surveywts_data(n = 50, seed = 33)
  targets <- .make_logit_targets()

  expect_warning(
    result <- calibrate_logit(
      df, targets = targets, weights = base_weight,
      control = list(epsilon = 1e-7, unknown_param = 42)
    ),
    class = "surveywts_warning_control_param_ignored"
  )

  test_invariants(result)
  expect_true(inherits(result, "weighted_df"))
})

# ---------------------------------------------------------------------------
# EC1: Edge case — all weights already satisfy targets (trivial calibration)
# ---------------------------------------------------------------------------

test_that("EC1: calibrate_logit() converges trivially when weights already satisfy targets", {
  # Create data where weighted proportions exactly match targets
  set.seed(41)
  n <- 300
  # Equal proportions: 100 per age group, 150 per sex
  df <- data.frame(
    age_group = rep(c("18-34", "35-54", "55+"), each = 100),
    sex = rep(c("M", "F"), times = 150),
    base_weight = rep(1, n),
    stringsAsFactors = FALSE
  )

  targets <- list(
    age_group = c("18-34" = 1/3, "35-54" = 1/3, "55+" = 1/3),
    sex = c("M" = 0.50, "F" = 0.50)
  )

  result <- calibrate_logit(df, targets = targets, weights = base_weight)

  test_invariants(result)
  w <- result[["wts"]]
  expect_true(all(w > 0))
  expect_true(all(is.finite(w)))
})

# ---------------------------------------------------------------------------
# EC2: Edge case — all output weights strictly positive
# ---------------------------------------------------------------------------

test_that("EC2: calibrate_logit() always produces strictly positive weights", {
  df <- make_surveywts_data(seed = 42)
  targets <- .make_logit_targets()

  result <- calibrate_logit(df, targets = targets, weights = base_weight)

  w <- result[["wts"]]
  expect_true(all(w > 0), label = "all output weights strictly positive")
})

# ---------------------------------------------------------------------------
# EC3: Edge case — g-weights in open interval (L, U) for multiplicative scale
# ---------------------------------------------------------------------------

test_that("EC3: calibrate_logit() g-weights strictly in (L, U) for multiplicative bounds", {
  df <- make_surveywts_data(seed = 43)
  taylor <- .make_test_taylor_logit(df)
  targets <- .make_logit_targets()

  L <- 1e-6
  U <- 1e6
  result <- calibrate_logit(
    taylor, targets = targets,
    bounds = c(L, U),
    bounds_scale = "multiplicative"
  )

  base_wts <- df$base_weight
  cal_wts <- result@data[[result@variables$weights]]
  g <- cal_wts / base_wts

  expect_true(all(g > L), label = "all g-weights strictly > L")
  expect_true(all(g < U), label = "all g-weights strictly < U")
})

# ---------------------------------------------------------------------------
# EC4: Edge case — @calibration$lambda is the NR converged solution
# ---------------------------------------------------------------------------

test_that("EC4: calibrate_logit() @calibration$lambda is converged NR solution (not linear approx)", {
  df <- make_surveywts_data(n = 200, seed = 44)
  taylor <- .make_test_taylor_logit(df)
  targets <- list(
    age_group = c("18-34" = 0.30, "35-54" = 0.40, "55+" = 0.30)
  )

  result <- calibrate_logit(taylor, targets = targets)

  cal <- result@calibration
  lambda_nr <- cal$lambda

  # Compute the linear one-step approximation for comparison
  x_mat <- cal$x_matrix
  base_wts <- cal$base_weights
  pop_totals <- cal$population_totals
  t_hat <- drop(t(x_mat) %*% base_wts)
  discrepancy <- pop_totals - t_hat
  T_x <- t(x_mat) %*% (base_wts * x_mat)
  lambda_linear <- drop(solve(T_x, discrepancy))

  # The NR lambda for logit is NOT equal to the linear one-step solution
  # (since logit requires actual NR iteration). They will differ.
  # Both are numeric vectors of the same length, but the values differ.
  expect_true(is.numeric(lambda_nr))
  expect_equal(length(lambda_nr), length(lambda_linear))
  # Verify the NR lambda actually satisfies calibration within tolerance:
  # sum(d_k * F(x_k' lambda_nr) * x_k) = pop_totals
  L <- 1e-6
  U <- 1e6
  A <- (U - L) / ((1 - L) * (U - 1))
  u_nr <- drop(x_mat %*% lambda_nr)
  exp_au <- exp(A * u_nr)
  f_nr <- (L * (U - 1) + U * (1 - L) * exp_au) / (U - 1 + (1 - L) * exp_au)
  cal_totals <- drop(t(x_mat) %*% (base_wts * f_nr))
  expect_equal(cal_totals, pop_totals, tolerance = 1e-5,
               label = "NR lambda satisfies calibration constraints")
})

# ---------------------------------------------------------------------------
# H_abs: Happy path — absolute bounds
# ---------------------------------------------------------------------------

test_that("H_abs: calibrate_logit() with absolute bounds produces weights in open interval (L, U)", {
  # Scale base_weight by 1000 so weights are in ~[400, 3100].
  # Use bounds (200, 3500) so all d_k strictly inside (L_abs, U_abs) —
  # a requirement of logit absolute bounds with per-unit g-weight bounds.
  df <- make_surveywts_data(n = 200, seed = 51)
  df$base_weight <- df$base_weight * 1000
  targets <- list(
    age_group = c("18-34" = 0.30, "35-54" = 0.40, "55+" = 0.30)
  )

  # Absolute bounds: output weights (not g-weights) in open interval (200, 3500)
  result <- calibrate_logit(
    df,
    targets = targets,
    weights = base_weight,
    bounds = c(200, 3500),
    bounds_scale = "absolute"
  )

  test_invariants(result)
  w <- result[["wts"]]
  expect_true(all(w > 200), label = "all weights > 200 (absolute lower bound)")
  expect_true(all(w < 3500), label = "all weights < 3500 (absolute upper bound)")
  expect_true(all(w > 0))
})

test_that("H_abs: calibrate_logit() absolute bounds stored in @calibration$bounds_scale", {
  # seed=52 has weights in [0.36, 2.46]; bounds (0.3, 3) contain all d_k strictly.
  df <- make_surveywts_data(n = 100, seed = 52)
  taylor <- .make_test_taylor_logit(df)
  targets <- list(
    age_group = c("18-34" = 0.30, "35-54" = 0.40, "55+" = 0.30)
  )

  result <- calibrate_logit(
    taylor,
    targets = targets,
    bounds = c(0.3, 3),
    bounds_scale = "absolute"
  )

  test_invariants(result)
  expect_identical(result@calibration$bounds_scale, "absolute")
})

# ---------------------------------------------------------------------------
# E_abs: Error — absolute bounds with L <= 0
# ---------------------------------------------------------------------------

test_that("E_abs: calibrate_logit() throws surveywts_error_bounds_invalid_calibration for L <= 0 (absolute)", {
  df <- make_surveywts_data(n = 50, seed = 53)
  targets <- .make_logit_targets()

  expect_error(
    calibrate_logit(
      df, targets = targets, weights = base_weight,
      bounds = c(-1, 2),
      bounds_scale = "absolute"
    ),
    class = "surveywts_error_bounds_invalid_calibration"
  )
  expect_snapshot(
    error = TRUE,
    calibrate_logit(
      df, targets = targets, weights = base_weight,
      bounds = c(-1, 2),
      bounds_scale = "absolute"
    )
  )
})

test_that("E_abs: calibrate_logit() throws surveywts_error_bounds_invalid_calibration for L >= U (absolute)", {
  df <- make_surveywts_data(n = 50, seed = 54)
  targets <- .make_logit_targets()

  expect_error(
    calibrate_logit(
      df, targets = targets, weights = base_weight,
      bounds = c(2, 1),
      bounds_scale = "absolute"
    ),
    class = "surveywts_error_bounds_invalid_calibration"
  )
})

# ===========================================================================
# unit_scale (q_weights) tests — calibrate-unit-scale PR 1
# ===========================================================================

# ---------------------------------------------------------------------------
# HG-1: Regression guard — unit_scale = rep(1, n) identical to unit_scale = NULL
# ---------------------------------------------------------------------------

test_that("HG-1: unit_scale = rep(1, n) produces weights identical to unit_scale = NULL within 1e-14", {
  targets <- .make_logit_targets()

  result_null <- calibrate_logit(
    df_500, targets = targets, weights = base_weight
  )
  result_ones <- calibrate_logit(
    df_500, targets = targets, weights = base_weight,
    unit_scale = q_all_ones
  )

  test_invariants(result_null)
  test_invariants(result_ones)

  expect_equal(
    result_ones[["wts"]],
    result_null[["wts"]],
    tolerance = 1e-14,
    label = "HG-1: unit_scale = rep(1, n) identical to unit_scale = NULL"
  )
})

# ---------------------------------------------------------------------------
# HG-2: Oracle — default bounds, unit_scale = q_unequal vs survey::calibrate(calfun="logit")
# ---------------------------------------------------------------------------

test_that("HG-2: logit with q_unequal matches survey::calibrate(calfun='logit', variance=1/q) within 1e-8", {
  skip_if_not_installed("survey")

  targets <- .make_logit_targets()
  total_w <- sum(df_500$base_weight)

  result <- calibrate_logit(
    df_500, targets = targets,
    weights = base_weight,
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
    calfun = "logit",
    bounds = c(1e-6, 1e6),
    variance = 1 / q_unequal
  )
  survey_weights <- as.numeric(stats::weights(svy_cal))

  test_invariants(result)
  expect_equal(
    result[["wts"]],
    survey_weights,
    tolerance = 1e-8,
    label = "HG-2: logit with q_unequal matches survey::calibrate"
  )
})

# ---------------------------------------------------------------------------
# HG-3: Oracle — default bounds, constant unit_scale = q_all_twos
# ---------------------------------------------------------------------------

test_that("HG-3: logit with q_all_twos matches survey::calibrate(variance=0.5) within 1e-8", {
  skip_if_not_installed("survey")

  targets <- .make_logit_targets()
  total_w <- sum(df_500$base_weight)

  result <- calibrate_logit(
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
    calfun = "logit",
    bounds = c(1e-6, 1e6),
    variance = rep(0.5, nrow(df_500))
  )
  survey_weights <- as.numeric(stats::weights(svy_cal))

  test_invariants(result)
  expect_equal(
    result[["wts"]],
    survey_weights,
    tolerance = 1e-8,
    label = "HG-3: logit with q_all_twos matches survey::calibrate"
  )
})

# ---------------------------------------------------------------------------
# HG-4: Oracle — multiplicative bounds with unit_scale = q_unequal
# ---------------------------------------------------------------------------

test_that("HG-4: multiplicative-bounded logit with q_unequal matches survey::calibrate within 1e-8", {
  skip_if_not_installed("survey")

  targets <- list(
    age_group = c("18-34" = 0.30, "35-54" = 0.40, "55+" = 0.30)
  )
  total_w <- sum(df_500$base_weight)
  L <- 0.3
  U <- 3.0

  result <- calibrate_logit(
    df_500, targets = targets,
    weights = base_weight,
    bounds = c(L, U),
    unit_scale = q_unequal
  )

  svy_design <- survey::svydesign(
    ids = ~1, data = df_500, weights = ~base_weight
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
    calfun = "logit",
    bounds = c(L, U),
    variance = 1 / q_unequal
  )
  survey_weights <- as.numeric(stats::weights(svy_cal))

  test_invariants(result)
  expect_equal(
    result[["wts"]],
    survey_weights,
    tolerance = 1e-8,
    label = "HG-4: multiplicative-bounded logit with q_unequal oracle"
  )
})

# ---------------------------------------------------------------------------
# HG-5: Calibration constraint holds with unit_scale != NULL
# ---------------------------------------------------------------------------

test_that("HG-5: calibration constraint satisfied within 1e-6 when unit_scale != NULL", {
  targets <- .make_logit_targets()

  result <- calibrate_logit(
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
        tolerance = 1e-6,
        label = paste0("HG-5: constraint: ", var, "=", lev)
      )
    }
  }
})

# ---------------------------------------------------------------------------
# HG-6: weighting_history records unit_scale vector
# ---------------------------------------------------------------------------

test_that("HG-6: weighting_history entry records unit_scale vector", {
  targets <- .make_logit_targets()

  result <- calibrate_logit(
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
    label = "HG-6: unit_scale stored in history"
  )
})

# ---------------------------------------------------------------------------
# HG-7: Absolute-bounds oracle — bounds.const = TRUE in survey::calibrate
# ---------------------------------------------------------------------------

test_that("HG-7: absolute-bounds logit matches survey::calibrate(calfun='logit', bounds.const=TRUE) within 1e-6", {
  skip_if_not_installed("survey")
  skip_if(
    utils::packageVersion("survey") < "4.1",
    "survey >= 4.1 required for bounds.const"
  )

  targets <- list(
    age_group = c("18-34" = 0.30, "35-54" = 0.40, "55+" = 0.30)
  )
  # df_200 (seed=7) has weights in [0.406, 2.716].
  # Use abs_L = 0.3 so all d_k strictly in (0.3, 3.0).
  abs_L <- 0.3
  abs_U <- 3.0
  total_w <- sum(df_200$base_weight)

  result <- calibrate_logit(
    df_200, targets = targets,
    weights = base_weight,
    bounds = c(abs_L, abs_U),
    bounds_scale = "absolute"
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
    calfun = "logit",
    bounds = c(abs_L, abs_U),
    bounds.const = TRUE
  )
  survey_weights <- as.numeric(stats::weights(svy_cal))

  test_invariants(result)
  # Tolerance is 1e-6: per-unit-bounds and survey's bounds.const use slightly
  # different NR paths at epsilon=1e-7, so exact agreement to 1e-8 is not expected.
  expect_equal(
    result[["wts"]],
    survey_weights,
    tolerance = 1e-6,
    label = "HG-7: absolute-bounds logit oracle"
  )
})

# ---------------------------------------------------------------------------
# HG-8: Bounded vs unbounded outputs differ with same q
# ---------------------------------------------------------------------------

test_that("HG-8: bounded and unbounded logit produce different weights with same q", {
  targets <- .make_logit_targets()

  result_wide <- calibrate_logit(
    df_500, targets = targets,
    weights = base_weight,
    bounds = c(1e-6, 1e6),
    unit_scale = q_unequal
  )
  result_tight <- calibrate_logit(
    df_500, targets = targets,
    weights = base_weight,
    bounds = c(0.5, 2),
    unit_scale = q_unequal
  )

  test_invariants(result_wide)
  test_invariants(result_tight)

  diff_max <- max(abs(result_tight[["wts"]] - result_wide[["wts"]]))
  expect_true(
    diff_max > 1e-6,
    label = "HG-8: bounds=(0.5,2) vs wide bounds produce different weights"
  )
})

# ---------------------------------------------------------------------------
# HG-9: Unequal-weights absolute-bounds differs from old mean-based approach
# ---------------------------------------------------------------------------

test_that("HG-9: absolute-bounds logit with unequal d_k differs from old mean-based approach", {
  targets <- list(
    age_group = c("18-34" = 0.30, "35-54" = 0.40, "55+" = 0.30)
  )
  # df_200 (seed=7) has weights in [0.406, 2.716]; use abs_L=0.3 so all d_k in (0.3, 3.0).
  abs_L <- 0.3
  abs_U <- 3.0
  total_w <- sum(df_200$base_weight)

  # New per-unit approach
  result_new <- calibrate_logit(
    df_200, targets = targets,
    weights = base_weight,
    bounds = c(abs_L, abs_U),
    bounds_scale = "absolute"
  )

  # Old mean-based approach: run engine with unit weights, scaled pop, scale back
  weights_vec <- df_200$base_weight
  n <- nrow(df_200)
  mean_d <- mean(weights_vec)
  L_g <- abs_L / mean_d
  U_g <- abs_U / mean_d
  x_df <- df_200
  lvls <- c("18-34", "35-54", "55+")
  x_df$age_group <- factor(x_df$age_group, levels = lvls)
  x_mat <- stats::model.matrix(~age_group, data = x_df)
  pop_totals_vec <- c(
    `(Intercept)` = total_w,
    age_group3554 = targets$age_group[["35-54"]] * total_w,
    `age_group55+` = targets$age_group[["55+"]] * total_w
  )
  calfun_old <- surveywts:::.make_calfun_logit(L = L_g, U = U_g)
  old_engine <- surveywts:::.calibrate_nr_engine(
    x_matrix    = x_mat,
    weights_vec = rep(1, n),
    calfun      = calfun_old,
    population  = pop_totals_vec / mean_d
  )
  old_weights <- old_engine$weights * mean_d

  test_invariants(result_new)
  max_diff <- max(abs(result_new[["wts"]] - old_weights))
  expect_true(
    max_diff > 0,
    label = "HG-9: per-unit and mean-based logit approaches differ for unequal d_k"
  )
})

# ---------------------------------------------------------------------------
# HG-10: Combined oracle — absolute-bounds + unit_scale = q_unequal
# ---------------------------------------------------------------------------

test_that("HG-10: absolute-bounds logit + unit_scale=q_unequal[1:200] matches survey::calibrate within 1e-6", {
  skip_if_not_installed("survey")
  skip_if(
    utils::packageVersion("survey") < "4.1",
    "survey >= 4.1 required for bounds.const"
  )

  targets <- list(
    age_group = c("18-34" = 0.30, "35-54" = 0.40, "55+" = 0.30)
  )
  # df_200 (seed=7) has weights in [0.406, 2.716]; use abs_L=0.3 so all d_k in (0.3, 3.0).
  abs_L <- 0.3
  abs_U <- 3.0
  total_w <- sum(df_200$base_weight)
  q_200 <- q_unequal[seq_len(nrow(df_200))]

  result <- calibrate_logit(
    df_200, targets = targets,
    weights = base_weight,
    bounds = c(abs_L, abs_U),
    bounds_scale = "absolute",
    unit_scale = q_200
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
    calfun = "logit",
    bounds = c(abs_L, abs_U),
    bounds.const = TRUE,
    variance = 1 / q_200
  )
  survey_weights <- as.numeric(stats::weights(svy_cal))

  test_invariants(result)
  # Tolerance is 1e-6: per-unit-bounds + q_weights and survey's bounds.const + variance
  # converge to the same solution from slightly different NR paths at epsilon=1e-7.
  expect_equal(
    result[["wts"]],
    survey_weights,
    tolerance = 1e-6,
    label = "HG-10: absolute-bounds logit + unit_scale oracle"
  )
})

# ---------------------------------------------------------------------------
# HGE-1 through HGE-5: Error paths
# ---------------------------------------------------------------------------

test_that("HGE-1: calibrate_logit() rejects unit_scale with non-numeric type", {
  targets <- .make_logit_targets()

  expect_error(
    calibrate_logit(
      df_500, targets = targets, weights = base_weight,
      unit_scale = as.character(q_unequal)
    ),
    class = "surveywts_error_unit_scale_invalid"
  )
  expect_snapshot(
    error = TRUE,
    calibrate_logit(
      df_500, targets = targets, weights = base_weight,
      unit_scale = as.character(q_unequal)
    )
  )
})

test_that("HGE-2: calibrate_logit() rejects unit_scale with wrong length", {
  targets <- .make_logit_targets()

  expect_error(
    calibrate_logit(
      df_500, targets = targets, weights = base_weight,
      unit_scale = q_unequal[-1L]
    ),
    class = "surveywts_error_unit_scale_invalid"
  )
  expect_snapshot(
    error = TRUE,
    calibrate_logit(
      df_500, targets = targets, weights = base_weight,
      unit_scale = q_unequal[-1L]
    )
  )
})

test_that("HGE-3: calibrate_logit() rejects unit_scale with NA values", {
  targets <- .make_logit_targets()
  q_na <- q_unequal
  q_na[5L] <- NA_real_

  expect_error(
    calibrate_logit(
      df_500, targets = targets, weights = base_weight,
      unit_scale = q_na
    ),
    class = "surveywts_error_unit_scale_invalid"
  )
  expect_snapshot(
    error = TRUE,
    calibrate_logit(
      df_500, targets = targets, weights = base_weight,
      unit_scale = q_na
    )
  )
})

test_that("HGE-4: calibrate_logit() throws bounds_invalid when d_k <= L_abs (absolute bounds)", {
  # Base weight = 0.3, abs_L = 0.5 => L_vec[k] = 0.5/0.3 = 1.67 >= 1: ill-defined
  n <- 50L
  set.seed(401)
  df_small <- data.frame(
    age_group = sample(c("18-34", "35-54", "55+"), n, replace = TRUE),
    base_weight = c(0.3, rep(1.5, n - 1L)),
    stringsAsFactors = FALSE
  )
  targets_s <- list(
    age_group = c("18-34" = 0.30, "35-54" = 0.40, "55+" = 0.30)
  )
  abs_L <- 0.5
  abs_U <- 5.0

  expect_error(
    calibrate_logit(
      df_small, targets = targets_s, weights = base_weight,
      bounds = c(abs_L, abs_U), bounds_scale = "absolute"
    ),
    class = "surveywts_error_bounds_invalid_calibration"
  )
  expect_snapshot(
    error = TRUE,
    calibrate_logit(
      df_small, targets = targets_s, weights = base_weight,
      bounds = c(abs_L, abs_U), bounds_scale = "absolute"
    )
  )
})

test_that("HGE-5: calibrate_logit() throws bounds_invalid when d_k >= U_abs (absolute bounds)", {
  # Base weight = 6, abs_U = 5 => U_vec[k] = 5/6 <= 1: ill-defined
  n <- 50L
  set.seed(402)
  df_small <- data.frame(
    age_group = sample(c("18-34", "35-54", "55+"), n, replace = TRUE),
    base_weight = c(6.0, rep(1.5, n - 1L)),
    stringsAsFactors = FALSE
  )
  targets_s <- list(
    age_group = c("18-34" = 0.30, "35-54" = 0.40, "55+" = 0.30)
  )
  abs_L <- 0.5
  abs_U <- 5.0

  expect_error(
    calibrate_logit(
      df_small, targets = targets_s, weights = base_weight,
      bounds = c(abs_L, abs_U), bounds_scale = "absolute"
    ),
    class = "surveywts_error_bounds_invalid_calibration"
  )
  expect_snapshot(
    error = TRUE,
    calibrate_logit(
      df_small, targets = targets_s, weights = base_weight,
      bounds = c(abs_L, abs_U), bounds_scale = "absolute"
    )
  )
})

# ---------------------------------------------------------------------------
# RL-3: Replicate — full-sample logit oracle with unit_scale
# ---------------------------------------------------------------------------

test_that("RL-3: replicate logit calibration full-sample weights match oracle with unit_scale", {
  targets <- list(
    age_group = c("18-34" = 0.30, "35-54" = 0.40, "55+" = 0.30)
  )
  q_200 <- q_unequal[seq_len(nrow(df_200))]

  taylor <- .make_test_taylor_logit(df_200)
  rep_design <- create_bootstrap_weights(taylor, replicates = 10L)

  result <- calibrate_logit(
    rep_design, targets = targets,
    unit_scale = q_200
  )

  test_invariants(result)

  result_full <- calibrate_logit(
    df_200, targets = targets,
    weights = base_weight,
    unit_scale = q_200
  )

  expect_equal(
    result@data[[result@variables$weights]],
    result_full[["wts"]],
    tolerance = 1e-8,
    label = "RL-3: replicate full-sample matches non-replicate oracle"
  )
})

# ---------------------------------------------------------------------------
# RL-4: Replicate — unit_scale = NULL vs rep(1, n) identical
# ---------------------------------------------------------------------------

test_that("RL-4: replicate logit with unit_scale = NULL and rep(1,n) produce identical full-sample weights", {
  targets <- list(
    age_group = c("18-34" = 0.30, "35-54" = 0.40, "55+" = 0.30)
  )

  taylor <- .make_test_taylor_logit(df_200)
  rep_design <- create_bootstrap_weights(taylor, replicates = 10L)

  result_null <- calibrate_logit(rep_design, targets = targets)
  result_ones <- calibrate_logit(
    rep_design, targets = targets,
    unit_scale = rep(1.0, nrow(df_200))
  )

  test_invariants(result_null)
  test_invariants(result_ones)

  expect_equal(
    result_ones@data[[result_ones@variables$weights]],
    result_null@data[[result_null@variables$weights]],
    tolerance = 1e-14,
    label = "RL-4: unit_scale = NULL vs rep(1,n) identical in replicate logit"
  )
})

# ---------------------------------------------------------------------------
# RL-6: Replicate — absolute-bounds logit constraint + all base weights in (L, U)
# ---------------------------------------------------------------------------

test_that("RL-6: absolute-bounds replicate logit: constraint holds and base weights strictly in (L_abs, U_abs)", {
  # df_200 (seed=7) has weights in [0.406, 2.716]; use abs_L=0.3 so all d_k in (0.3, 3.0).
  abs_L <- 0.3
  abs_U <- 3.0
  targets <- list(
    age_group = c("18-34" = 0.30, "35-54" = 0.40, "55+" = 0.30)
  )

  taylor <- .make_test_taylor_logit(df_200)
  rep_design <- create_bootstrap_weights(taylor, replicates = 10L)

  # Ensure all base weights are strictly within (L_abs, U_abs)
  stopifnot(all(df_200$base_weight > abs_L & df_200$base_weight < abs_U))

  result <- calibrate_logit(
    rep_design, targets = targets,
    bounds = c(abs_L, abs_U),
    bounds_scale = "absolute"
  )

  test_invariants(result)

  # Calibration constraint on full-sample weights
  fs_wts <- result@data[[result@variables$weights]]
  total_fs <- sum(fs_wts)
  x_full <- rep_design@data$age_group
  for (lev in names(targets$age_group)) {
    obs <- sum(fs_wts[x_full == lev]) / total_fs
    expect_equal(obs, targets$age_group[[lev]], tolerance = 1e-8,
                 label = paste0("RL-6: constraint age_group=", lev))
  }
  expect_true(
    all(df_200$base_weight > abs_L & df_200$base_weight < abs_U),
    label = "RL-6: all base weights strictly in (0.3, 3.0)"
  )
})

# ---------------------------------------------------------------------------
# EC-7: Edge case — logit g-weights in open interval (L, U)
# ---------------------------------------------------------------------------

test_that("EC-7: logit g-weights are strictly in open interval (L, U) with q_unequal", {
  L <- 0.3
  U <- 3.0
  targets <- list(
    age_group = c("18-34" = 0.30, "35-54" = 0.40, "55+" = 0.30)
  )
  q_200 <- q_unequal[seq_len(nrow(df_200))]

  result <- calibrate_logit(
    df_200, targets = targets,
    weights = base_weight,
    bounds = c(L, U),
    unit_scale = q_200
  )

  test_invariants(result)
  g <- result[["wts"]] / df_200$base_weight
  expect_true(all(g > L), label = "EC-7: all g-weights > L")
  expect_true(all(g < U), label = "EC-7: all g-weights < U")
})

# ---------------------------------------------------------------------------
# EC-10: Edge case — absolute-bounds logit final weights strictly in (L_abs, U_abs)
# ---------------------------------------------------------------------------

test_that("EC-10: absolute-bounds logit: all final weights strictly within (L_abs, U_abs)", {
  # df_200 (seed=7) has weights in [0.406, 2.716]; use abs_L=0.3 so all d_k in (0.3, 3.0).
  abs_L <- 0.3
  abs_U <- 3.0
  targets <- list(
    age_group = c("18-34" = 0.30, "35-54" = 0.40, "55+" = 0.30)
  )

  # Verify precondition: all base weights strictly within (L_abs, U_abs)
  stopifnot(all(df_200$base_weight > abs_L & df_200$base_weight < abs_U))

  result <- calibrate_logit(
    df_200, targets = targets, weights = base_weight,
    bounds = c(abs_L, abs_U), bounds_scale = "absolute"
  )

  test_invariants(result)
  w <- result[["wts"]]
  expect_true(
    all(w > abs_L),
    label = "EC-10: all weights strictly > L_abs"
  )
  expect_true(
    all(w < abs_U),
    label = "EC-10: all weights strictly < U_abs"
  )
})
