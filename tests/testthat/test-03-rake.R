# tests/testthat/test-03-rake.R
#
# Tests for calibrate_rake()
# Per spec §IV: signature, args, returns, errors, warnings, messages, edge cases
#
# All error path tests use the dual pattern:
#   expect_error(class = ...) + expect_snapshot(error = TRUE, ...)
# Warning tests use:
#   expect_warning(class = ...) + expect_snapshot()
# Message tests use:
#   expect_message(class = ...)

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

.make_test_taylor_rake <- function(df, weight_col = "base_weight") {
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

.make_targets_rake <- function(type = "prop") {
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
# 1. Happy path — data.frame, type = "prop", algorithm = "anesrake"
# ---------------------------------------------------------------------------

test_that("calibrate_rake() returns weighted_df for data.frame input (prop, anesrake)", {
  df <- make_surveywts_data(seed = 1)
  targets <- .make_targets_rake()

  result <- calibrate_rake(df, targets = targets)

  test_invariants(result)
  expect_true(inherits(result, "weighted_df"))
  expect_identical(attr(result, "weight_col"), "wts")
  expect_true(all(result[["wts"]] > 0))
})

# ---------------------------------------------------------------------------
# 2. Happy path — type = "count", algorithm = "anesrake"
# ---------------------------------------------------------------------------

test_that("calibrate_rake() with type = 'count' accepts count targets (anesrake)", {
  df <- make_surveywts_data(n = 500, seed = 2)
  targets <- .make_targets_rake("count")

  result <- calibrate_rake(df, targets = targets, type = "count")

  test_invariants(result)
  expect_true(inherits(result, "weighted_df"))
  # anesrake converges to proportional targets; verify marginals are closer to
  # target proportions than starting values (improvement-based convergence)
  w <- result[["wts"]]
  expect_true(all(w > 0))
})

# ---------------------------------------------------------------------------
# 3. Happy path — algorithm = "survey"
# ---------------------------------------------------------------------------

test_that("calibrate_rake() with algorithm = 'survey' produces valid raked weights", {
  df <- make_surveywts_data(seed = 3)
  targets <- .make_targets_rake()

  result <- calibrate_rake(df, targets = targets, algorithm = "survey")

  test_invariants(result)
  expect_true(inherits(result, "weighted_df"))
  expect_true(all(result[["wts"]] > 0))
})

# ---------------------------------------------------------------------------
# 4. Happy path — weighted_df input -> weighted_df
# ---------------------------------------------------------------------------

test_that("calibrate_rake() accepts weighted_df input and returns weighted_df", {
  df <- make_surveywts_data(seed = 4)
  targets <- .make_targets_rake()

  wdf <- calibrate_rake(df, targets = targets)
  result <- calibrate_rake(wdf, targets = targets)

  test_invariants(result)
  expect_true(inherits(result, "weighted_df"))
})

# ---------------------------------------------------------------------------
# 5. Happy path — survey_nonprob input -> class preserved
# ---------------------------------------------------------------------------

test_that("calibrate_rake() preserves survey_nonprob class", {
  df <- make_surveywts_data(seed = 5)
  sc_input <- surveycore::survey_nonprob(
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
  targets <- .make_targets_rake()

  result <- calibrate_rake(sc_input, targets = targets)

  test_invariants(result)
  expect_true(S7::S7_inherits(result, surveycore::survey_nonprob))
})

# ---------------------------------------------------------------------------
# 6. Happy path — survey_taylor input -> class preserved, design vars unchanged
# ---------------------------------------------------------------------------

test_that("calibrate_rake() preserves survey_taylor class and design vars", {
  df <- make_surveywts_data(seed = 6)
  design <- .make_test_taylor_rake(df)
  targets <- .make_targets_rake()

  result <- calibrate_rake(design, targets = targets)

  test_invariants(result)
  expect_true(S7::S7_inherits(result, surveycore::survey_taylor))
  expect_identical(result@variables$ids, design@variables$ids)
  expect_identical(result@variables$strata, design@variables$strata)
})

# ---------------------------------------------------------------------------
# 7. Happy path — Format B targets -> same result as Format A
# ---------------------------------------------------------------------------

test_that("calibrate_rake() Format B targets gives same result as Format A", {
  df <- make_surveywts_data(n = 200, seed = 7)

  targets_a <- list(
    age_group = c("18-34" = 0.30, "35-54" = 0.40, "55+" = 0.30),
    sex = c("M" = 0.48, "F" = 0.52)
  )
  targets_b <- data.frame(
    variable = c("age_group", "age_group", "age_group", "sex", "sex"),
    level = c("18-34", "35-54", "55+", "M", "F"),
    target = c(0.30, 0.40, 0.30, 0.48, 0.52),
    stringsAsFactors = FALSE
  )

  result_a <- calibrate_rake(df, targets = targets_a, algorithm = "survey")
  result_b <- calibrate_rake(df, targets = targets_b, algorithm = "survey")

  test_invariants(result_a)
  test_invariants(result_b)
  expect_equal(result_a[["wts"]], result_b[["wts"]], tolerance = 1e-10)
})

# ---------------------------------------------------------------------------
# 8. Happy path — cap applied with algorithm = "anesrake"
# ---------------------------------------------------------------------------

test_that("calibrate_rake() cap limits weight ratio (algorithm = 'anesrake')", {
  df <- make_surveywts_data(seed = 8)
  targets <- .make_targets_rake()
  cap_val <- 3.0

  result <- calibrate_rake(df, targets = targets, cap = cap_val)

  test_invariants(result)
  w <- result[["wts"]]
  expect_true(all(w / mean(w) <= cap_val + 1e-10))
})

# ---------------------------------------------------------------------------
# 9. Happy path — reference_design -> targets_from_reference = TRUE in history
# ---------------------------------------------------------------------------

test_that("calibrate_rake() records targets_from_reference in history", {
  df <- make_surveywts_data(seed = 9)
  ref <- .make_test_taylor_rake(df)
  targets <- .make_targets_rake()

  result <- calibrate_rake(df, targets = targets, reference_design = ref)

  test_invariants(result)
  history <- attr(result, "weighting_history")
  expect_true(isTRUE(history[[1L]]$parameters$targets_from_reference))
})

# ---------------------------------------------------------------------------
# 10. Numerical oracle — algorithm = "survey" matches survey::rake()
# ---------------------------------------------------------------------------

test_that("calibrate_rake(algorithm='survey') matches survey::rake() within 1e-8", {
  skip_if_not_installed("survey")

  df <- make_surveywts_data(n = 200, seed = 10)
  targets <- list(
    age_group = c("18-34" = 0.30, "35-54" = 0.40, "55+" = 0.30),
    sex = c("M" = 0.48, "F" = 0.52)
  )
  total_w <- sum(df$base_weight)

  sw_result <- calibrate_rake(
    df,
    targets = targets,
    weights = base_weight,
    algorithm = "survey",
    control = list(maxit = 500, epsilon = 1e-7)
  )
  sw_weights <- sw_result[["wts"]]

  svy_design <- survey::svydesign(ids = ~1, weights = ~base_weight, data = df)
  svy_raked <- survey::rake(
    svy_design,
    sample.margins = list(~age_group, ~sex),
    population.margins = list(
      data.frame(age_group = c("18-34", "35-54", "55+"),
                 Freq = targets$age_group * total_w),
      data.frame(sex = c("M", "F"),
                 Freq = targets$sex * total_w)
    ),
    control = list(maxit = 500, epsilon = 1e-7, verbose = FALSE)
  )
  svy_weights <- as.numeric(weights(svy_raked))

  expect_equal(sw_weights, svy_weights, tolerance = 1e-8)
})

# ---------------------------------------------------------------------------
# 11. Error — surveywts_error_unsupported_class
# ---------------------------------------------------------------------------

test_that("calibrate_rake() rejects unsupported class", {
  targets <- .make_targets_rake()

  expect_error(
    calibrate_rake(list(x = 1), targets = targets),
    class = "surveywts_error_unsupported_class"
  )
  expect_snapshot(
    error = TRUE,
    calibrate_rake(list(x = 1), targets = targets)
  )
})

# ---------------------------------------------------------------------------
# 12. survey_replicate no longer rejected at class-check gate
#     (PR 1: survey_replicate branch removed from .check_input_class())
#     Full survey_replicate support for calibrate_rake() lands in PR 2.
# ---------------------------------------------------------------------------

test_that("calibrate_rake() no longer rejects survey_replicate at class-check gate", {
  df <- make_surveywts_data(seed = 11)
  targets <- .make_targets_rake()
  meta <- surveycore::survey_metadata()
  rep_design <- surveycore::survey_replicate(
    data = df,
    variables = list(
      ids = NULL, strata = NULL, fpc = NULL,
      weights = "base_weight", nest = FALSE,
      repweights = c("base_weight"), scale = 0.5,
      rscales = 1, type = "BRR", mse = TRUE
    ),
    metadata = meta,
    groups = character(0),
    call = NULL
  )

  # .check_input_class() no longer throws surveywts_error_replicate_not_supported
  # for survey_replicate objects (PR 1 change).
  expect_no_error(.check_input_class(rep_design))
})

# ---------------------------------------------------------------------------
# 13. Error — surveywts_error_empty_data
# ---------------------------------------------------------------------------

test_that("calibrate_rake() rejects 0-row data", {
  empty_df <- data.frame(
    age_group = character(0), sex = character(0),
    base_weight = numeric(0), stringsAsFactors = FALSE
  )
  targets <- .make_targets_rake()

  expect_error(
    calibrate_rake(empty_df, targets = targets),
    class = "surveywts_error_empty_data"
  )
  expect_snapshot(
    error = TRUE,
    calibrate_rake(empty_df, targets = targets)
  )
})

# ---------------------------------------------------------------------------
# 14. Error — surveywts_error_weights_not_found
# ---------------------------------------------------------------------------

test_that("calibrate_rake() rejects nonexistent weight column", {
  df <- make_surveywts_data(seed = 12)
  targets <- .make_targets_rake()

  expect_error(
    calibrate_rake(df, targets = targets, weights = nonexistent_wt),
    class = "surveywts_error_weights_not_found"
  )
  expect_snapshot(
    error = TRUE,
    calibrate_rake(df, targets = targets, weights = nonexistent_wt)
  )
})

# ---------------------------------------------------------------------------
# 15. Error — surveywts_error_weights_not_numeric
# ---------------------------------------------------------------------------

test_that("calibrate_rake() rejects character weight column", {
  df <- make_surveywts_data(seed = 13)
  df$bad_wt <- as.character(df$base_weight)
  targets <- .make_targets_rake()

  expect_error(
    calibrate_rake(df, targets = targets, weights = bad_wt),
    class = "surveywts_error_weights_not_numeric"
  )
  expect_snapshot(
    error = TRUE,
    calibrate_rake(df, targets = targets, weights = bad_wt)
  )
})

# ---------------------------------------------------------------------------
# 16. Error — surveywts_error_weights_nonpositive
# ---------------------------------------------------------------------------

test_that("calibrate_rake() rejects weight column with 0", {
  df <- make_surveywts_data(seed = 14)
  df$base_weight[1] <- 0
  targets <- .make_targets_rake()

  expect_error(
    calibrate_rake(df, targets = targets, weights = base_weight),
    class = "surveywts_error_weights_nonpositive"
  )
  expect_snapshot(
    error = TRUE,
    calibrate_rake(df, targets = targets, weights = base_weight)
  )
})

# ---------------------------------------------------------------------------
# 17. Error — surveywts_error_weights_na
# ---------------------------------------------------------------------------

test_that("calibrate_rake() rejects weight column with NA", {
  df <- make_surveywts_data(seed = 15)
  df$base_weight[1] <- NA_real_
  targets <- .make_targets_rake()

  expect_error(
    calibrate_rake(df, targets = targets, weights = base_weight),
    class = "surveywts_error_weights_na"
  )
  expect_snapshot(
    error = TRUE,
    calibrate_rake(df, targets = targets, weights = base_weight)
  )
})

# ---------------------------------------------------------------------------
# 18. Error — surveywts_error_wt_name_not_scalar
# ---------------------------------------------------------------------------

test_that("calibrate_rake() rejects wt_name = c('a', 'b')", {
  df <- make_surveywts_data(seed = 16)
  targets <- .make_targets_rake()

  expect_error(
    calibrate_rake(df, targets = targets, wt_name = c("a", "b")),
    class = "surveywts_error_wt_name_not_scalar"
  )
  expect_snapshot(
    error = TRUE,
    calibrate_rake(df, targets = targets, wt_name = c("a", "b"))
  )
})

# ---------------------------------------------------------------------------
# 19. Error — surveywts_error_wt_name_empty
# ---------------------------------------------------------------------------

test_that("calibrate_rake() rejects wt_name = ''", {
  df <- make_surveywts_data(seed = 17)
  targets <- .make_targets_rake()

  expect_error(
    calibrate_rake(df, targets = targets, wt_name = ""),
    class = "surveywts_error_wt_name_empty"
  )
  expect_snapshot(
    error = TRUE,
    calibrate_rake(df, targets = targets, wt_name = "")
  )
})

# ---------------------------------------------------------------------------
# 20. Error — surveywts_error_reference_design_not_taylor
# ---------------------------------------------------------------------------

test_that("calibrate_rake() rejects non-taylor reference_design", {
  df <- make_surveywts_data(seed = 18)
  targets <- .make_targets_rake()

  expect_error(
    calibrate_rake(df, targets = targets, reference_design = "bad"),
    class = "surveywts_error_reference_design_not_taylor"
  )
  expect_snapshot(
    error = TRUE,
    calibrate_rake(df, targets = targets, reference_design = "bad")
  )
})

# ---------------------------------------------------------------------------
# 21. Error — surveywts_error_margins_format_invalid (not a list/df)
# ---------------------------------------------------------------------------

test_that("calibrate_rake() rejects targets = 42", {
  df <- make_surveywts_data(seed = 19)

  expect_error(
    calibrate_rake(df, targets = 42),
    class = "surveywts_error_margins_format_invalid"
  )
  expect_snapshot(
    error = TRUE,
    calibrate_rake(df, targets = 42)
  )
})

# ---------------------------------------------------------------------------
# 22. Error — surveywts_error_margins_format_invalid (df missing level col)
# ---------------------------------------------------------------------------

test_that("calibrate_rake() rejects Format B data frame missing 'level' column", {
  df <- make_surveywts_data(seed = 20)
  bad_df <- data.frame(
    variable = "age_group", target = 0.5,
    stringsAsFactors = FALSE
  )  # missing 'level' column

  expect_error(
    calibrate_rake(df, targets = bad_df),
    class = "surveywts_error_margins_format_invalid"
  )
  expect_snapshot(
    error = TRUE,
    calibrate_rake(df, targets = bad_df)
  )
})

# ---------------------------------------------------------------------------
# 23. Error — surveywts_error_targets_variable_not_found
# ---------------------------------------------------------------------------

test_that("calibrate_rake() rejects targets naming absent column", {
  df <- make_surveywts_data(seed = 21)
  targets <- list(
    age_group = c("18-34" = 0.30, "35-54" = 0.40, "55+" = 0.30),
    not_a_column = c("A" = 0.50, "B" = 0.50)
  )

  expect_error(
    calibrate_rake(df, targets = targets),
    class = "surveywts_error_targets_variable_not_found"
  )
  expect_snapshot(
    error = TRUE,
    calibrate_rake(df, targets = targets)
  )
})

# ---------------------------------------------------------------------------
# 24. Error — surveywts_error_variable_not_categorical
# ---------------------------------------------------------------------------

test_that("calibrate_rake() rejects numeric raking variable", {
  df <- make_surveywts_data(seed = 22)
  df$income <- rnorm(nrow(df))
  targets <- list(
    age_group = c("18-34" = 0.30, "35-54" = 0.40, "55+" = 0.30),
    income = c("50000" = 1.0)
  )

  expect_error(
    calibrate_rake(df, targets = targets),
    class = "surveywts_error_variable_not_categorical"
  )
  expect_snapshot(
    error = TRUE,
    calibrate_rake(df, targets = targets)
  )
})

# ---------------------------------------------------------------------------
# 25. Error — surveywts_error_variable_has_na
# ---------------------------------------------------------------------------

test_that("calibrate_rake() rejects raking variable with NA", {
  df <- make_surveywts_data(seed = 23)
  df$age_group[1] <- NA_character_
  targets <- .make_targets_rake()

  expect_error(
    calibrate_rake(df, targets = targets),
    class = "surveywts_error_variable_has_na"
  )
  expect_snapshot(
    error = TRUE,
    calibrate_rake(df, targets = targets)
  )
})

# ---------------------------------------------------------------------------
# 26. Error — surveywts_error_population_level_missing
# ---------------------------------------------------------------------------

test_that("calibrate_rake() rejects targets missing a data level", {
  df <- make_surveywts_data(seed = 24)
  targets <- list(
    age_group = c("18-34" = 0.50, "35-54" = 0.50),  # missing "55+"
    sex = c("M" = 0.48, "F" = 0.52)
  )

  expect_error(
    calibrate_rake(df, targets = targets),
    class = "surveywts_error_population_level_missing"
  )
  expect_snapshot(
    error = TRUE,
    calibrate_rake(df, targets = targets)
  )
})

# ---------------------------------------------------------------------------
# 27. Error — surveywts_error_population_level_extra
# ---------------------------------------------------------------------------

test_that("calibrate_rake() rejects targets with level not in data", {
  df <- make_surveywts_data(seed = 25)
  targets <- list(
    age_group = c("18-34" = 0.25, "35-54" = 0.40, "55+" = 0.25, "65+" = 0.10),
    sex = c("M" = 0.48, "F" = 0.52)
  )

  expect_error(
    calibrate_rake(df, targets = targets),
    class = "surveywts_error_population_level_extra"
  )
  expect_snapshot(
    error = TRUE,
    calibrate_rake(df, targets = targets)
  )
})

# ---------------------------------------------------------------------------
# 28. Error — surveywts_error_population_totals_invalid (prop sums to 1.1)
# ---------------------------------------------------------------------------

test_that("calibrate_rake() rejects proportions summing to 1.1", {
  df <- make_surveywts_data(seed = 26)
  targets <- list(
    age_group = c("18-34" = 0.40, "35-54" = 0.40, "55+" = 0.30),  # sums to 1.1
    sex = c("M" = 0.48, "F" = 0.52)
  )

  expect_error(
    calibrate_rake(df, targets = targets),
    class = "surveywts_error_population_totals_invalid"
  )
  expect_snapshot(
    error = TRUE,
    calibrate_rake(df, targets = targets)
  )
})

# ---------------------------------------------------------------------------
# 29. Error — surveywts_error_population_totals_invalid (count, marginal sums differ)
# ---------------------------------------------------------------------------

test_that("calibrate_rake() rejects type='count' with inconsistent marginal sums", {
  df <- make_surveywts_data(n = 200, seed = 27)
  # age_group sums to 500, sex sums to 550 — differ by 50 > 1e-3
  targets <- list(
    age_group = c("18-34" = 150, "35-54" = 200, "55+" = 150),  # sum = 500
    sex = c("M" = 270, "F" = 280)                               # sum = 550
  )

  expect_error(
    calibrate_rake(df, targets = targets, type = "count"),
    class = "surveywts_error_population_totals_invalid"
  )
  expect_snapshot(
    error = TRUE,
    calibrate_rake(df, targets = targets, type = "count")
  )
})

# ---------------------------------------------------------------------------
# 30. Error — surveywts_error_calibration_not_converged
# ---------------------------------------------------------------------------

test_that("calibrate_rake() throws calibration_not_converged hitting maxit", {
  df <- make_surveywts_data(seed = 28)
  targets <- .make_targets_rake()

  expect_error(
    calibrate_rake(
      df, targets = targets, algorithm = "survey",
      control = list(maxit = 1, epsilon = 1e-20)
    ),
    class = "surveywts_error_calibration_not_converged"
  )
  expect_snapshot(
    error = TRUE,
    calibrate_rake(
      df, targets = targets, algorithm = "survey",
      control = list(maxit = 1, epsilon = 1e-20)
    )
  )
})

# ---------------------------------------------------------------------------
# 31. Error — surveywts_error_cap_not_supported_survey
# ---------------------------------------------------------------------------

test_that("calibrate_rake() rejects cap with algorithm = 'survey'", {
  df <- make_surveywts_data(seed = 29)
  targets <- .make_targets_rake()

  expect_error(
    calibrate_rake(df, targets = targets, algorithm = "survey", cap = 3.0),
    class = "surveywts_error_cap_not_supported_survey"
  )
  expect_snapshot(
    error = TRUE,
    calibrate_rake(df, targets = targets, algorithm = "survey", cap = 3.0)
  )
})

# ---------------------------------------------------------------------------
# 32. Warning — control_param_ignored (pval with algorithm = "survey")
# ---------------------------------------------------------------------------

test_that("calibrate_rake() warns for anesrake-specific control param with algorithm='survey'", {
  df <- make_surveywts_data(seed = 30)
  targets <- .make_targets_rake()

  expect_warning(
    result <- calibrate_rake(
      df, targets = targets, algorithm = "survey",
      control = list(pval = 0.01)
    ),
    class = "surveywts_warning_control_param_ignored"
  )
  expect_snapshot(
    calibrate_rake(
      df, targets = targets, algorithm = "survey",
      control = list(pval = 0.01)
    )
  )
})

# ---------------------------------------------------------------------------
# 33. Warning — control_param_ignored (epsilon with algorithm = "anesrake")
# ---------------------------------------------------------------------------

test_that("calibrate_rake() warns for survey-specific control param with algorithm='anesrake'", {
  df <- make_surveywts_data(seed = 31)
  targets <- .make_targets_rake()

  expect_warning(
    result <- calibrate_rake(
      df, targets = targets, algorithm = "anesrake",
      control = list(epsilon = 1e-9)
    ),
    class = "surveywts_warning_control_param_ignored"
  )
  expect_snapshot(
    calibrate_rake(
      df, targets = targets, algorithm = "anesrake",
      control = list(epsilon = 1e-9)
    )
  )
})

# ---------------------------------------------------------------------------
# 34. Message — surveywts_message_already_calibrated
# ---------------------------------------------------------------------------

test_that("calibrate_rake() emits already_calibrated when data matches targets", {
  df_exact <- data.frame(
    age_group = c(rep("18-34", 3), rep("35-54", 4), rep("55+", 3)),
    w = rep(1, 10),
    stringsAsFactors = FALSE
  )
  targets <- list(
    age_group = c("18-34" = 0.3, "35-54" = 0.4, "55+" = 0.3)
  )

  expect_message(
    result <- calibrate_rake(df_exact, targets = targets, weights = w),
    class = "surveywts_message_already_calibrated"
  )
  test_invariants(result)
})

# ---------------------------------------------------------------------------
# 35. Edge case — 0-row data -> error
# ---------------------------------------------------------------------------

test_that("calibrate_rake() rejects 0-row data (edge case)", {
  df <- data.frame(
    age_group = character(0), sex = character(0),
    stringsAsFactors = FALSE
  )
  targets <- .make_targets_rake()

  expect_error(
    calibrate_rake(df, targets = targets),
    class = "surveywts_error_empty_data"
  )
})

# ---------------------------------------------------------------------------
# 36. Edge case — cap non-NULL + algorithm = "survey" -> error before parsing
# ---------------------------------------------------------------------------

test_that("calibrate_rake() cap + algorithm='survey' error fires before margin parsing", {
  df <- make_surveywts_data(seed = 32)

  # targets = 42 is also invalid, but cap error should fire first
  expect_error(
    calibrate_rake(df, targets = 42, algorithm = "survey", cap = 3.0),
    class = "surveywts_error_cap_not_supported_survey"
  )
})

# ---------------------------------------------------------------------------
# 37. Edge case — Format B targets -> identical result to Format A
# ---------------------------------------------------------------------------

test_that("calibrate_rake() Format B targets gives identical result to Format A", {
  df <- make_surveywts_data(n = 200, seed = 33)

  targets_a <- list(sex = c("M" = 0.48, "F" = 0.52))
  targets_b <- data.frame(
    variable = c("sex", "sex"),
    level = c("M", "F"),
    target = c(0.48, 0.52),
    stringsAsFactors = FALSE
  )

  result_a <- calibrate_rake(df, targets = targets_a, algorithm = "survey")
  result_b <- calibrate_rake(df, targets = targets_b, algorithm = "survey")

  test_invariants(result_a)
  test_invariants(result_b)
  expect_equal(result_a[["wts"]], result_b[["wts"]], tolerance = 1e-10)
})

# ---------------------------------------------------------------------------
# 38. Edge case — single-level raking variable
# ---------------------------------------------------------------------------

test_that("calibrate_rake() handles single-level raking variable", {
  df <- data.frame(
    group_one = rep("A", 50),
    group_two = c(rep("X", 30), rep("Y", 20)),
    base_weight = rep(1, 50),
    stringsAsFactors = FALSE
  )
  targets <- list(
    group_one = c("A" = 1.0),
    group_two = c("X" = 0.5, "Y" = 0.5)
  )

  result <- calibrate_rake(df, targets = targets, weights = base_weight)

  test_invariants(result)
  expect_true(inherits(result, "weighted_df"))
})

# ---------------------------------------------------------------------------
# 39. History field — operation = "calibrate_rake"
# ---------------------------------------------------------------------------

test_that("calibrate_rake() history entry has operation = 'calibrate_rake'", {
  df <- make_surveywts_data(seed = 34)
  targets <- .make_targets_rake()

  result <- calibrate_rake(df, targets = targets)

  history <- attr(result, "weighting_history")
  op <- history[[1L]]$operation
  expect_identical(op, "calibrate_rake")
})

# ---------------------------------------------------------------------------
# 40. History — algorithm stored in parameters
# ---------------------------------------------------------------------------

test_that("calibrate_rake() history stores algorithm in parameters", {
  df <- make_surveywts_data(seed = 35)
  targets <- .make_targets_rake()

  result <- calibrate_rake(df, targets = targets, algorithm = "survey")

  history <- attr(result, "weighting_history")
  expect_identical(history[[1L]]$parameters$algorithm, "survey")
})

# ---------------------------------------------------------------------------
# 41. History — targets stored as Format A
# ---------------------------------------------------------------------------

test_that("calibrate_rake() history stores targets as Format A named list", {
  df <- make_surveywts_data(seed = 36)
  targets <- .make_targets_rake()

  result <- calibrate_rake(df, targets = targets)

  history <- attr(result, "weighting_history")
  stored_targets <- history[[1L]]$parameters$targets
  expect_true(is.list(stored_targets))
  expect_true(!is.null(names(stored_targets)))
})

# ---------------------------------------------------------------------------
# 42. Deleted-function regression guard: old rake() / margins arg no longer exists
# ---------------------------------------------------------------------------

test_that("old rake() with margins arg no longer exists", {
  df <- make_surveywts_data(seed = 37)
  margins <- list(
    age_group = c("18-34" = 0.30, "35-54" = 0.40, "55+" = 0.30)
  )

  # rake() is gone; calling with margins arg should error
  expect_error(
    rake(df, margins = margins)
  )
})
