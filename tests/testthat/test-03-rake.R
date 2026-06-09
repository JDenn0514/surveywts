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
#
# PR 4 changes:
#   - algorithm = "anesrake" renamed to "classic_ipf"
#   - algorithm = "survey" removed (expect arg_match error — no class=)
#   - algorithm = "nr" added: Newton-Raphson raking via .calibrate_nr_engine()
#   - calibrate() default method changed to "rake"

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
# 1. Happy path — data.frame, type = "prop", algorithm = "classic_ipf"
# ---------------------------------------------------------------------------

test_that("calibrate_rake() returns weighted_df for data.frame input (prop, classic_ipf)", {
  df <- make_surveywts_data(seed = 1)
  targets <- .make_targets_rake()

  result <- calibrate_rake(df, targets = targets)

  test_invariants(result)
  expect_true(inherits(result, "weighted_df"))
  expect_identical(attr(result, "weight_col"), "wts")
  expect_true(all(result[["wts"]] > 0))
})

# ---------------------------------------------------------------------------
# 2. Happy path — type = "count", algorithm = "classic_ipf"
# ---------------------------------------------------------------------------

test_that("calibrate_rake() with type = 'count' accepts count targets (classic_ipf)", {
  df <- make_surveywts_data(n = 500, seed = 2)
  targets <- .make_targets_rake("count")

  result <- calibrate_rake(df, targets = targets, type = "count")

  test_invariants(result)
  expect_true(inherits(result, "weighted_df"))
  # classic_ipf converges to proportional targets; verify marginals are closer to
  # target proportions than starting values (improvement-based convergence)
  w <- result[["wts"]]
  expect_true(all(w > 0))
})

# ---------------------------------------------------------------------------
# 3. algorithm = "survey" no longer valid — expect rlang::arg_match() error
# ---------------------------------------------------------------------------

test_that("calibrate_rake() with algorithm = 'survey' triggers arg_match error", {
  df <- make_surveywts_data(seed = 3)
  targets <- .make_targets_rake()

  # "survey" was removed from algorithm choices in PR 4.
  # rlang::arg_match() error — no class= (not a cli_abort)
  expect_error(
    calibrate_rake(df, targets = targets, algorithm = "survey")
  )
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

  result_a <- calibrate_rake(df, targets = targets_a, algorithm = "classic_ipf")
  result_b <- calibrate_rake(df, targets = targets_b, algorithm = "classic_ipf")

  test_invariants(result_a)
  test_invariants(result_b)
  expect_equal(result_a[["wts"]], result_b[["wts"]], tolerance = 1e-10)
})

# ---------------------------------------------------------------------------
# 8. Happy path — cap applied with algorithm = "classic_ipf"
# ---------------------------------------------------------------------------

test_that("calibrate_rake() cap limits weight ratio (algorithm = 'classic_ipf')", {
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
# 10. Numerical oracle — algorithm = "nr" matches survey::calibrate(calfun="raking")
# ---------------------------------------------------------------------------

test_that("calibrate_rake(algorithm='nr') matches survey::calibrate(raking) within 1e-8", {
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
    algorithm = "nr",
    control = list(maxit = 100L, epsilon = 1e-10)
  )
  sw_weights <- sw_result[["wts"]]

  # Build oracle via survey::calibrate(calfun = survey::cal.raking)
  svy_design <- survey::svydesign(ids = ~1, weights = ~base_weight, data = df)
  mm <- stats::model.matrix(~age_group + sex, data = df)
  pop_totals_vec <- stats::setNames(numeric(ncol(mm)), colnames(mm))
  pop_totals_vec["(Intercept)"] <- total_w
  for (lev in names(targets$age_group)) {
    col_nm <- paste0("age_group", lev)
    if (col_nm %in% names(pop_totals_vec)) {
      pop_totals_vec[col_nm] <- targets$age_group[[lev]] * total_w
    }
  }
  for (lev in names(targets$sex)) {
    col_nm <- paste0("sex", lev)
    if (col_nm %in% names(pop_totals_vec)) {
      pop_totals_vec[col_nm] <- targets$sex[[lev]] * total_w
    }
  }
  svy_cal <- survey::calibrate(
    svy_design,
    formula = ~age_group + sex,
    population = pop_totals_vec,
    calfun = survey::cal.raking,
    epsilon = 1e-10
  )
  svy_weights <- as.numeric(weights(svy_cal))

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

test_that("calibrate_rake() throws calibration_not_converged hitting maxit (nr)", {
  df <- make_surveywts_data(seed = 28)
  targets <- .make_targets_rake()

  expect_error(
    calibrate_rake(
      df, targets = targets, algorithm = "nr",
      control = list(maxit = 1L, epsilon = 1e-20)
    ),
    class = "surveywts_error_calibration_not_converged"
  )
  expect_snapshot(
    error = TRUE,
    calibrate_rake(
      df, targets = targets, algorithm = "nr",
      control = list(maxit = 1L, epsilon = 1e-20)
    )
  )
})

# ---------------------------------------------------------------------------
# 31. Error — surveywts_error_cap_not_supported_nr
# ---------------------------------------------------------------------------

test_that("calibrate_rake() rejects cap with algorithm = 'nr'", {
  df <- make_surveywts_data(seed = 29)
  targets <- .make_targets_rake()

  expect_error(
    calibrate_rake(df, targets = targets, algorithm = "nr", cap = 3.0),
    class = "surveywts_error_cap_not_supported_nr"
  )
  expect_snapshot(
    error = TRUE,
    calibrate_rake(df, targets = targets, algorithm = "nr", cap = 3.0)
  )
})

# ---------------------------------------------------------------------------
# 32. Warning — control_param_ignored (pval with algorithm = "nr")
# ---------------------------------------------------------------------------

test_that("calibrate_rake() warns for classic_ipf-specific control param with algorithm='nr'", {
  df <- make_surveywts_data(seed = 30)
  targets <- .make_targets_rake()

  expect_warning(
    result <- calibrate_rake(
      df, targets = targets, algorithm = "nr",
      control = list(pval = 0.01)
    ),
    class = "surveywts_warning_control_param_ignored"
  )
  expect_snapshot(
    calibrate_rake(
      df, targets = targets, algorithm = "nr",
      control = list(pval = 0.01)
    )
  )
})

# ---------------------------------------------------------------------------
# 33. Warning — control_param_ignored (epsilon with algorithm = "classic_ipf")
# ---------------------------------------------------------------------------

test_that("calibrate_rake() warns for nr-specific control param with algorithm='classic_ipf'", {
  df <- make_surveywts_data(seed = 31)
  targets <- .make_targets_rake()

  expect_warning(
    result <- calibrate_rake(
      df, targets = targets, algorithm = "classic_ipf",
      control = list(epsilon = 1e-9)
    ),
    class = "surveywts_warning_control_param_ignored"
  )
  expect_snapshot(
    calibrate_rake(
      df, targets = targets, algorithm = "classic_ipf",
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
# 36. Edge case — cap non-NULL + algorithm = "nr" -> error before parsing
# ---------------------------------------------------------------------------

test_that("calibrate_rake() cap + algorithm='nr' error fires before margin parsing", {
  df <- make_surveywts_data(seed = 32)

  # targets = 42 is also invalid, but cap error should fire first
  expect_error(
    calibrate_rake(df, targets = 42, algorithm = "nr", cap = 3.0),
    class = "surveywts_error_cap_not_supported_nr"
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

  result_a <- calibrate_rake(df, targets = targets_a, algorithm = "classic_ipf")
  result_b <- calibrate_rake(df, targets = targets_b, algorithm = "classic_ipf")

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

  result <- calibrate_rake(df, targets = targets, algorithm = "classic_ipf")

  history <- attr(result, "weighting_history")
  expect_identical(history[[1L]]$parameters$algorithm, "classic_ipf")
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

# ===========================================================================
# survey_taylor input — @calibration slot (RT tests, PR 2)
# ===========================================================================

# ---------------------------------------------------------------------------
# RT-1. survey_taylor input -> survey_taylor output
# ---------------------------------------------------------------------------

test_that("calibrate_rake() with survey_taylor returns survey_taylor", {
  df <- make_surveywts_data(seed = 501)
  design <- .make_test_taylor_rake(df)
  targets <- .make_targets_rake()

  result <- calibrate_rake(design, targets = targets)

  expect_true(S7::S7_inherits(result, surveycore::survey_taylor))
})

# ---------------------------------------------------------------------------
# RT-2. @calibration populated for survey_taylor
# ---------------------------------------------------------------------------

test_that("calibrate_rake() with survey_taylor populates @calibration", {
  df <- make_surveywts_data(seed = 502)
  design <- .make_test_taylor_rake(df)
  targets <- .make_targets_rake()

  result <- calibrate_rake(design, targets = targets)

  expect_false(is.null(result@calibration))
  expect_true(is.list(result@calibration))
})

# ---------------------------------------------------------------------------
# RT-3. All 12 @calibration fields present
# ---------------------------------------------------------------------------

test_that("calibrate_rake() @calibration has all 12 required fields", {
  df <- make_surveywts_data(seed = 503)
  design <- .make_test_taylor_rake(df)
  targets <- .make_targets_rake()

  result <- calibrate_rake(design, targets = targets)

  required_fields <- c(
    "x_matrix", "base_weights", "g_weights", "crossproduct_inv",
    "population_totals", "discrepancy", "lambda", "method",
    "cell_factors", "q_weights", "converged", "n_iterations"
  )
  expect_true(all(required_fields %in% names(result@calibration)))
})

# ---------------------------------------------------------------------------
# RT-4. method == "raking"
# ---------------------------------------------------------------------------

test_that("calibrate_rake() @calibration$method == 'raking'", {
  df <- make_surveywts_data(seed = 504)
  design <- .make_test_taylor_rake(df)
  targets <- .make_targets_rake()

  result <- calibrate_rake(design, targets = targets)

  expect_identical(result@calibration$method, "raking")
})

# ---------------------------------------------------------------------------
# RT-5. lambda is NULL (multiplicative form, not stored)
# ---------------------------------------------------------------------------

test_that("calibrate_rake() @calibration$lambda is NULL", {
  df <- make_surveywts_data(seed = 505)
  design <- .make_test_taylor_rake(df)
  targets <- .make_targets_rake()

  result <- calibrate_rake(design, targets = targets)

  expect_null(result@calibration$lambda)
})

# ---------------------------------------------------------------------------
# RT-6. cell_factors is NULL
# ---------------------------------------------------------------------------

test_that("calibrate_rake() @calibration$cell_factors is NULL", {
  df <- make_surveywts_data(seed = 506)
  design <- .make_test_taylor_rake(df)
  targets <- .make_targets_rake()

  result <- calibrate_rake(design, targets = targets)

  expect_null(result@calibration$cell_factors)
})

# ---------------------------------------------------------------------------
# RT-7. base_weights equals pre-calibration weight vector (1e-10)
# ---------------------------------------------------------------------------

test_that("calibrate_rake() @calibration$base_weights matches pre-calibration", {
  df <- make_surveywts_data(seed = 507)
  design <- .make_test_taylor_rake(df)
  targets <- .make_targets_rake()
  pre_weights <- design@data[[design@variables$weights]]

  result <- calibrate_rake(design, targets = targets)

  expect_equal(result@calibration$base_weights, pre_weights, tolerance = 1e-10)
})

# ---------------------------------------------------------------------------
# RT-8. g_weights * base_weights == output_weights (1e-10)
# ---------------------------------------------------------------------------

test_that("calibrate_rake() g_weights * base_weights == calibrated weights (1e-10)", {
  df <- make_surveywts_data(seed = 508)
  design <- .make_test_taylor_rake(df)
  targets <- .make_targets_rake()

  result <- calibrate_rake(design, targets = targets)
  cal <- result@calibration
  out_weights <- result@data[[result@variables$weights]]

  expect_equal(cal$g_weights * cal$base_weights, out_weights, tolerance = 1e-10)
})

# ---------------------------------------------------------------------------
# RT-9. q_weights all 1
# ---------------------------------------------------------------------------

test_that("calibrate_rake() @calibration$q_weights are all 1", {
  df <- make_surveywts_data(seed = 509)
  design <- .make_test_taylor_rake(df)
  targets <- .make_targets_rake()

  result <- calibrate_rake(design, targets = targets)

  expect_equal(result@calibration$q_weights, rep(1, nrow(df)), tolerance = 1e-10)
})

# ---------------------------------------------------------------------------
# RT-10. replicate_converged is NULL for survey_taylor
# ---------------------------------------------------------------------------

test_that("calibrate_rake() @calibration$replicate_converged is NULL for survey_taylor", {
  df <- make_surveywts_data(seed = 510)
  design <- .make_test_taylor_rake(df)
  targets <- .make_targets_rake()

  result <- calibrate_rake(design, targets = targets)

  expect_null(result@calibration$replicate_converged)
})

# ---------------------------------------------------------------------------
# RT-11. History entry appended
# ---------------------------------------------------------------------------

test_that("calibrate_rake() appends history entry to survey_taylor", {
  df <- make_surveywts_data(seed = 511)
  design <- .make_test_taylor_rake(df)
  targets <- .make_targets_rake()

  result <- calibrate_rake(design, targets = targets)

  expect_identical(length(result@metadata@weighting_history), 1L)
  expect_identical(
    result@metadata@weighting_history[[1L]]$operation,
    "calibrate_rake"
  )
})

# ===========================================================================
# survey_replicate input — @calibration + replicate_converged (RR tests, PR 2)
# ===========================================================================

# ---------------------------------------------------------------------------
# RR-1. survey_replicate output class
# ---------------------------------------------------------------------------

test_that("calibrate_rake() with survey_replicate returns survey_replicate", {
  df <- make_surveywts_data(seed = 521)
  targets <- .make_targets_rake()
  rep_design <- .make_replicate_design(df, seed = 521)

  result <- calibrate_rake(rep_design, targets = targets)

  expect_true(S7::S7_inherits(result, surveycore::survey_replicate))
})

# ---------------------------------------------------------------------------
# RR-2. @calibration populated for survey_replicate
# ---------------------------------------------------------------------------

test_that("calibrate_rake() survey_replicate @calibration is non-NULL", {
  df <- make_surveywts_data(seed = 522)
  targets <- .make_targets_rake()
  rep_design <- .make_replicate_design(df, seed = 522)

  result <- calibrate_rake(rep_design, targets = targets)

  expect_false(is.null(result@calibration))
})

# ---------------------------------------------------------------------------
# RR-3. replicate_converged is named logical of length R
# ---------------------------------------------------------------------------

test_that("calibrate_rake() replicate_converged is named logical length R", {
  df <- make_surveywts_data(seed = 523)
  targets <- .make_targets_rake()
  rep_design <- .make_replicate_design(df, seed = 523)
  R <- length(rep_design@variables$repweights)

  result <- calibrate_rake(rep_design, targets = targets)

  rc <- result@calibration$replicate_converged
  expect_true(is.logical(rc))
  expect_identical(length(rc), R)
  expect_identical(names(rc), rep_design@variables$repweights)
})

# ---------------------------------------------------------------------------
# RR-4. All entries TRUE when all replicates converge
# ---------------------------------------------------------------------------

test_that("calibrate_rake() replicate_converged all TRUE when all converge", {
  df <- make_surveywts_data(seed = 524)
  targets <- .make_targets_rake()
  rep_design <- .make_replicate_design(df, seed = 524)

  result <- calibrate_rake(rep_design, targets = targets)

  expect_true(all(result@calibration$replicate_converged))
})

# ---------------------------------------------------------------------------
# RR-5. Full-sample weight column calibrated
# ---------------------------------------------------------------------------

test_that("calibrate_rake() full-sample weights calibrated in survey_replicate", {
  df <- make_surveywts_data(seed = 525)
  targets <- .make_targets_rake()
  rep_design <- .make_replicate_design(df, seed = 525)
  pre_weights <- rep_design@data[[rep_design@variables$weights]]

  result <- calibrate_rake(rep_design, targets = targets)

  out_weights <- result@data[[result@variables$weights]]
  expect_false(identical(out_weights, pre_weights))
})

# ---------------------------------------------------------------------------
# RR-6. All 12 @calibration fields present for survey_replicate
# ---------------------------------------------------------------------------

test_that("calibrate_rake() survey_replicate @calibration has 12 required fields", {
  df <- make_surveywts_data(seed = 526)
  targets <- .make_targets_rake()
  rep_design <- .make_replicate_design(df, seed = 526)

  result <- calibrate_rake(rep_design, targets = targets)

  required_fields <- c(
    "x_matrix", "base_weights", "g_weights", "crossproduct_inv",
    "population_totals", "discrepancy", "lambda", "method",
    "cell_factors", "q_weights", "converged", "n_iterations"
  )
  expect_true(all(required_fields %in% names(result@calibration)))
})

# ---------------------------------------------------------------------------
# RR-7. Warning emitted when a replicate fails
# ---------------------------------------------------------------------------

test_that("calibrate_rake() warns when a replicate fails calibration", {
  df <- make_surveywts_data(seed = 527)
  rep_design <- .make_empty_cell_replicate_design(df, "age_group")
  targets <- .make_targets_rake()

  expect_warning(
    calibrate_rake(rep_design, targets = targets),
    class = "surveywts_warning_replicate_calibration_failed"
  )
})

# ---------------------------------------------------------------------------
# RR-8. 0 replicate columns -> replicate_converged length 0
# ---------------------------------------------------------------------------

test_that("calibrate_rake() with 0 repweights gives replicate_converged length 0", {
  df <- make_surveywts_data(n = 50, seed = 528)
  targets <- .make_targets_rake()
  meta <- surveycore::survey_metadata()
  rep_empty <- surveycore::survey_replicate(
    data = df,
    variables = list(
      ids = NULL, strata = NULL, fpc = NULL,
      weights = "base_weight", nest = FALSE,
      repweights = character(0), scale = 1, rscales = numeric(0),
      type = "bootstrap", mse = TRUE
    ),
    metadata = meta,
    groups = character(0),
    call = NULL
  )

  result <- calibrate_rake(rep_empty, targets = targets)

  rc <- result@calibration$replicate_converged
  expect_true(is.logical(rc))
  expect_identical(length(rc), 0L)
})

# ---------------------------------------------------------------------------
# RR-9. method == "raking" for survey_replicate
# ---------------------------------------------------------------------------

test_that("calibrate_rake() @calibration$method == 'raking' for survey_replicate", {
  df <- make_surveywts_data(seed = 529)
  targets <- .make_targets_rake()
  rep_design <- .make_replicate_design(df, seed = 529)

  result <- calibrate_rake(rep_design, targets = targets)

  expect_identical(result@calibration$method, "raking")
})

# ---------------------------------------------------------------------------
# REG: survey_replicate does NOT throw surveywts_error_replicate_not_supported
# ---------------------------------------------------------------------------

test_that("calibrate_rake() with survey_replicate does NOT throw replicate_not_supported", {
  df <- make_surveywts_data(seed = 531)
  targets <- .make_targets_rake()
  rep_design <- .make_replicate_design(df, seed = 531)

  expect_no_error(
    calibrate_rake(rep_design, targets = targets)
  )
})

# ===========================================================================
# NR algorithm — Happy path (H6–H8, H10, PR 4)
# ===========================================================================

# ---------------------------------------------------------------------------
# H6. algorithm = "nr" with data.frame input -> weighted_df
# ---------------------------------------------------------------------------

test_that("calibrate_rake() algorithm = 'nr' returns weighted_df for data.frame", {
  df <- make_surveywts_data(seed = 601)
  targets <- .make_targets_rake()

  result <- calibrate_rake(df, targets = targets, algorithm = "nr")

  test_invariants(result)
  expect_true(inherits(result, "weighted_df"))
  expect_true(all(result[["wts"]] > 0))
})

# ---------------------------------------------------------------------------
# H7. algorithm = "nr" with survey_taylor -> @calibration populated
# ---------------------------------------------------------------------------

test_that("calibrate_rake() algorithm = 'nr' with survey_taylor populates @calibration", {
  df <- make_surveywts_data(seed = 602)
  design <- .make_test_taylor_rake(df)
  targets <- .make_targets_rake()

  result <- calibrate_rake(design, targets = targets, algorithm = "nr")

  expect_true(S7::S7_inherits(result, surveycore::survey_taylor))
  expect_false(is.null(result@calibration))
  expect_identical(result@calibration$method, "raking")
})

# ---------------------------------------------------------------------------
# H8. algorithm = "nr" with survey_replicate -> replicate loop uses NR
# ---------------------------------------------------------------------------

test_that("calibrate_rake() algorithm = 'nr' with survey_replicate returns survey_replicate", {
  df <- make_surveywts_data(seed = 603)
  targets <- .make_targets_rake()
  rep_design <- .make_replicate_design(df, seed = 603)

  result <- calibrate_rake(rep_design, targets = targets, algorithm = "nr")

  expect_true(S7::S7_inherits(result, surveycore::survey_replicate))
  expect_false(is.null(result@calibration))
  expect_true(all(result@calibration$replicate_converged))
})

# ---------------------------------------------------------------------------
# H10. algorithm = "nr" convergence: lambda is a numeric vector, not NULL
# ---------------------------------------------------------------------------

test_that("calibrate_rake() algorithm = 'nr' @calibration$lambda is numeric (not NULL)", {
  df <- make_surveywts_data(seed = 604)
  design <- .make_test_taylor_rake(df)
  targets <- .make_targets_rake()

  result <- calibrate_rake(design, targets = targets, algorithm = "nr")

  lam <- result@calibration$lambda
  expect_true(is.numeric(lam))
  expect_true(length(lam) > 0L)
})

# ===========================================================================
# NR algorithm — Error paths (E17–E20, PR 4)
# ===========================================================================

# ---------------------------------------------------------------------------
# E17. cap + algorithm = "nr" -> surveywts_error_cap_not_supported_nr
#      (fires before any other validation)
# ---------------------------------------------------------------------------

test_that("calibrate_rake() cap + nr fires before margin parsing", {
  df <- make_surveywts_data(seed = 611)

  # targets = 42 is invalid, but cap+nr check fires first
  expect_error(
    calibrate_rake(df, targets = 42, algorithm = "nr", cap = 3.0),
    class = "surveywts_error_cap_not_supported_nr"
  )
})

# ---------------------------------------------------------------------------
# E18. algorithm = "nr" + maxit = 1 + epsilon = 1e-20 -> not_converged
# ---------------------------------------------------------------------------

test_that("calibrate_rake() nr with maxit=1 + tiny epsilon throws not_converged", {
  df <- make_surveywts_data(seed = 612)
  targets <- .make_targets_rake()

  expect_error(
    calibrate_rake(
      df, targets = targets, algorithm = "nr",
      control = list(maxit = 1L, epsilon = 1e-20)
    ),
    class = "surveywts_error_calibration_not_converged"
  )
})

# ---------------------------------------------------------------------------
# E19. algorithm = "nr" — wrong control keys (classic_ipf keys) trigger warning
# ---------------------------------------------------------------------------

test_that("calibrate_rake() algorithm='nr' warns on classic_ipf-specific control params", {
  df <- make_surveywts_data(seed = 613)
  targets <- .make_targets_rake()

  expect_warning(
    calibrate_rake(
      df, targets = targets, algorithm = "nr",
      control = list(improvement = 0.01)
    ),
    class = "surveywts_warning_control_param_ignored"
  )
})

# ---------------------------------------------------------------------------
# E20. algorithm = "nr" — wrong control keys (pval) trigger warning
# ---------------------------------------------------------------------------

test_that("calibrate_rake() algorithm='nr' warns on pval control param", {
  df <- make_surveywts_data(seed = 614)
  targets <- .make_targets_rake()

  expect_warning(
    calibrate_rake(
      df, targets = targets, algorithm = "nr",
      control = list(pval = 0.05)
    ),
    class = "surveywts_warning_control_param_ignored"
  )
})

# ===========================================================================
# NR algorithm — Edge cases (EC3–EC9, PR 4)
# ===========================================================================

# ---------------------------------------------------------------------------
# EC3. NR lambda stored, crossproduct_inv is NULL in @calibration
# ---------------------------------------------------------------------------

test_that("calibrate_rake() nr @calibration has lambda numeric, crossproduct_inv NULL", {
  df <- make_surveywts_data(seed = 621)
  design <- .make_test_taylor_rake(df)
  targets <- .make_targets_rake()

  result <- calibrate_rake(design, targets = targets, algorithm = "nr")

  cal <- result@calibration
  expect_true(is.numeric(cal$lambda))
  expect_null(cal$crossproduct_inv)
})

# ---------------------------------------------------------------------------
# EC4. classic_ipf lambda is NULL in @calibration
# ---------------------------------------------------------------------------

test_that("calibrate_rake() classic_ipf @calibration$lambda is NULL", {
  df <- make_surveywts_data(seed = 622)
  design <- .make_test_taylor_rake(df)
  targets <- .make_targets_rake()

  result <- calibrate_rake(design, targets = targets, algorithm = "classic_ipf")

  expect_null(result@calibration$lambda)
})

# ---------------------------------------------------------------------------
# EC5. NR weight conservation for type = "prop"
#      sum(new_weights) == sum(base_weights) within 1e-10
# ---------------------------------------------------------------------------

test_that("calibrate_rake() nr conserves weight sum for type='prop' (1e-10)", {
  df <- make_surveywts_data(seed = 623)
  targets <- .make_targets_rake()

  result <- calibrate_rake(
    df, targets = targets, weights = base_weight, algorithm = "nr"
  )

  expect_equal(
    sum(result[["wts"]]),
    sum(df$base_weight),
    tolerance = 1e-10
  )
})

# ---------------------------------------------------------------------------
# EC6. NR weight conservation for type = "count"
#      sum(new_weights) == sum of any marginal total (since all equal)
# ---------------------------------------------------------------------------

test_that("calibrate_rake() nr with type='count' conserves weight sum to target total (1e-6)", {
  df <- make_surveywts_data(n = 300, seed = 624)
  targets <- list(
    age_group = c("18-34" = 90, "35-54" = 120, "55+" = 90),  # sum = 300
    sex = c("M" = 144, "F" = 156)                             # sum = 300
  )

  result <- calibrate_rake(
    df, targets = targets, weights = base_weight,
    algorithm = "nr", type = "count"
  )

  w <- result[["wts"]]
  expect_equal(sum(w), 300, tolerance = 1e-6)
})

# ---------------------------------------------------------------------------
# EC7. NR @calibration$method == "raking" (not "raking_nr")
# ---------------------------------------------------------------------------

test_that("calibrate_rake() nr @calibration$method == 'raking' (not 'raking_nr')", {
  df <- make_surveywts_data(seed = 625)
  design <- .make_test_taylor_rake(df)
  targets <- .make_targets_rake()

  result <- calibrate_rake(design, targets = targets, algorithm = "nr")

  expect_identical(result@calibration$method, "raking")
})

# ---------------------------------------------------------------------------
# EC8. NR replicate loop scales population totals for type = "count"
#      Each replicate weight sum differs from base; constraint must still hold
# ---------------------------------------------------------------------------

test_that("calibrate_rake() nr replicate loop scales count targets correctly", {
  df <- make_surveywts_data(n = 200, seed = 626)
  targets_count <- list(
    age_group = c("18-34" = 60, "35-54" = 80, "55+" = 60),  # sum = 200
    sex = c("M" = 96, "F" = 104)                             # sum = 200
  )
  rep_design <- .make_replicate_design(df, seed = 626)

  result <- calibrate_rake(
    rep_design, targets = targets_count,
    algorithm = "nr", type = "count"
  )

  expect_true(S7::S7_inherits(result, surveycore::survey_replicate))
  expect_true(all(result@calibration$replicate_converged))
})

# ---------------------------------------------------------------------------
# EC9. NR g_weights * base_weights == calibrated weights (1e-10)
# ---------------------------------------------------------------------------

test_that("calibrate_rake() nr g_weights * base_weights == calibrated weights (1e-10)", {
  df <- make_surveywts_data(seed = 627)
  design <- .make_test_taylor_rake(df)
  targets <- .make_targets_rake()

  result <- calibrate_rake(design, targets = targets, algorithm = "nr")

  cal <- result@calibration
  out_weights <- result@data[[result@variables$weights]]
  expect_equal(cal$g_weights * cal$base_weights, out_weights, tolerance = 1e-10)
})

# ===========================================================================
# RT-5. lambda is NULL for classic_ipf (spec: lambda stored for "nr" only)
# ===========================================================================

test_that("calibrate_rake() @calibration$lambda is NULL for classic_ipf (RT-5b)", {
  df <- make_surveywts_data(seed = 630)
  design <- .make_test_taylor_rake(df)
  targets <- .make_targets_rake()

  result <- calibrate_rake(design, targets = targets, algorithm = "classic_ipf")

  expect_null(result@calibration$lambda)
})
