# tests/testthat/test-02-calibrate.R
#
# Tests for calibrate_greg()
# Per spec §III: signature, args, returns, errors, warnings, edge cases
#
# All error path tests use the dual pattern:
#   expect_error(class = ...) + expect_snapshot(error = TRUE, ...)
# Warning tests use:
#   expect_warning(class = ...) + expect_snapshot()

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

.make_test_taylor_greg <- function(df, weight_col = "base_weight") {
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

.make_targets <- function(type = "prop") {
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
# 1. Happy path — data.frame, type = "prop", model = "linear" -> weighted_df
# ---------------------------------------------------------------------------

test_that("calibrate_greg() returns weighted_df for data.frame input (prop, linear)", {
  df <- make_surveywts_data(seed = 1)
  targets <- .make_targets()

  result <- calibrate_greg(df, targets = targets)

  test_invariants(result)
  expect_true(inherits(result, "weighted_df"))
  expect_identical(attr(result, "weight_col"), "wts")

  w <- result[["wts"]]
  total_w <- sum(w)
  for (var in names(targets)) {
    for (lev in names(targets[[var]])) {
      obs_prop <- sum(w[result[[var]] == lev]) / total_w
      expect_equal(obs_prop, targets[[var]][[lev]], tolerance = 1e-10,
                   label = paste0(var, "=", lev))
    }
  }
})

# ---------------------------------------------------------------------------
# 2. Happy path — type = "count"
# ---------------------------------------------------------------------------

test_that("calibrate_greg() returns weighted_df for data.frame input (count)", {
  df <- make_surveywts_data(n = 500, seed = 2)
  targets <- .make_targets("count")

  result <- calibrate_greg(df, targets = targets, type = "count")

  test_invariants(result)
  expect_true(inherits(result, "weighted_df"))

  w <- result[["wts"]]
  for (var in names(targets)) {
    for (lev in names(targets[[var]])) {
      obs_count <- sum(w[result[[var]] == lev])
      expect_equal(obs_count, targets[[var]][[lev]], tolerance = 1e-10,
                   label = paste0(var, "=", lev))
    }
  }
})

# ---------------------------------------------------------------------------
# 3. Happy path — model = "logit" -> all weights positive
# ---------------------------------------------------------------------------

test_that("calibrate_greg() with model = 'logit' produces positive weights", {
  df <- make_surveywts_data(seed = 3)
  targets <- .make_targets()

  result <- calibrate_greg(df, targets = targets, model = "logit")

  test_invariants(result)
  expect_true(inherits(result, "weighted_df"))
  expect_true(all(result[["wts"]] > 0))
})

# ---------------------------------------------------------------------------
# 4. Happy path — weighted_df input -> weighted_df
# ---------------------------------------------------------------------------

test_that("calibrate_greg() accepts weighted_df input and returns weighted_df", {
  df <- make_surveywts_data(seed = 4)
  targets <- .make_targets()

  wdf <- calibrate_greg(df, targets = targets)
  result <- calibrate_greg(wdf, targets = targets)

  test_invariants(result)
  expect_true(inherits(result, "weighted_df"))
})

# ---------------------------------------------------------------------------
# 5. Happy path — survey_nonprob input -> survey_nonprob preserved
# ---------------------------------------------------------------------------

test_that("calibrate_greg() preserves survey_nonprob class", {
  df <- make_surveywts_data(seed = 5)
  snp <- surveycore::survey_nonprob(
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
  targets <- .make_targets()

  result <- calibrate_greg(snp, targets = targets)

  test_invariants(result)
  expect_true(S7::S7_inherits(result, surveycore::survey_nonprob))
})

# ---------------------------------------------------------------------------
# 6. Happy path — survey_taylor input -> survey_taylor preserved
# ---------------------------------------------------------------------------

test_that("calibrate_greg() preserves survey_taylor class and design vars", {
  df <- make_surveywts_data(seed = 6)
  design <- .make_test_taylor_greg(df)
  targets <- .make_targets()

  result <- calibrate_greg(design, targets = targets)

  test_invariants(result)
  expect_true(S7::S7_inherits(result, surveycore::survey_taylor))
  expect_identical(result@variables$ids, design@variables$ids)
  expect_identical(result@variables$strata, design@variables$strata)
  expect_identical(length(result@metadata@weighting_history), 1L)
})

# ---------------------------------------------------------------------------
# 7. Happy path — Format B data frame targets -> same result as Format A
# ---------------------------------------------------------------------------

test_that("calibrate_greg() Format B targets produces same result as Format A", {
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

  result_a <- calibrate_greg(df, targets = targets_a)
  result_b <- calibrate_greg(df, targets = targets_b)

  test_invariants(result_a)
  test_invariants(result_b)
  expect_equal(result_a[["wts"]], result_b[["wts"]], tolerance = 1e-10)
})

# ---------------------------------------------------------------------------
# 8. Happy path — reference_design -> history entry targets_from_reference
# ---------------------------------------------------------------------------

test_that("calibrate_greg() records targets_from_reference when reference_design given", {
  df <- make_surveywts_data(seed = 8)
  ref <- .make_test_taylor_greg(df)
  targets <- .make_targets()

  result <- calibrate_greg(df, targets = targets, reference_design = ref)

  test_invariants(result)
  history <- attr(result, "weighting_history")
  expect_true(isTRUE(history[[1L]]$parameters$targets_from_reference))
})

# ---------------------------------------------------------------------------
# 9. Happy path — weights = NULL on plain data.frame -> output col "wts",
#    uniform starting weights
# ---------------------------------------------------------------------------

test_that("calibrate_greg() with weights = NULL on data.frame uses uniform starting weights", {
  df <- make_surveywts_data(seed = 9)
  targets <- .make_targets()

  result <- calibrate_greg(df, targets = targets)

  test_invariants(result)
  expect_true("wts" %in% names(result))
  expect_identical(attr(result, "weight_col"), "wts")
})

# ---------------------------------------------------------------------------
# 10. Happy path — custom wt_name
# ---------------------------------------------------------------------------

test_that("calibrate_greg() uses custom wt_name for output column", {
  df <- make_surveywts_data(seed = 10)
  targets <- .make_targets()

  result <- calibrate_greg(df, targets = targets, wt_name = "cal_wt")

  test_invariants(result)
  expect_true("cal_wt" %in% names(result))
  expect_identical(attr(result, "weight_col"), "cal_wt")
})

# ---------------------------------------------------------------------------
# 11. Numerical oracle — model = "linear" matches survey::calibrate()
# ---------------------------------------------------------------------------

test_that("calibrate_greg() matches survey::calibrate() within 1e-8", {
  skip_if_not_installed("survey")

  df <- make_surveywts_data(n = 200, seed = 11)
  targets <- list(
    age_group = c("18-34" = 0.30, "35-54" = 0.40, "55+" = 0.30),
    sex = c("M" = 0.48, "F" = 0.52)
  )
  total_w <- sum(df$base_weight)

  sw_result <- calibrate_greg(
    df, targets = targets, weights = base_weight, model = "linear"
  )
  sw_weights <- sw_result[["wts"]]

  svy_design <- survey::svydesign(ids = ~1, weights = ~base_weight, data = df)
  mm_cols <- colnames(model.matrix(~age_group + sex, data = df))
  pop_totals_vec <- stats::setNames(numeric(length(mm_cols)), mm_cols)
  pop_totals_vec["(Intercept)"] <- total_w
  for (lev in names(targets$age_group)) {
    col_nm <- paste0("age_group", lev)
    if (col_nm %in% mm_cols) {
      pop_totals_vec[col_nm] <- targets$age_group[[lev]] * total_w
    }
  }
  for (lev in names(targets$sex)) {
    col_nm <- paste0("sex", lev)
    if (col_nm %in% mm_cols) {
      pop_totals_vec[col_nm] <- targets$sex[[lev]] * total_w
    }
  }

  svy_cal <- survey::calibrate(
    svy_design,
    formula = ~age_group + sex,
    population = pop_totals_vec,
    calfun = survey::cal.linear
  )
  svy_weights <- as.numeric(weights(svy_cal))

  expect_equal(sw_weights, svy_weights, tolerance = 1e-8)
})

# ---------------------------------------------------------------------------
# 12. Error — surveywts_error_unsupported_class
# ---------------------------------------------------------------------------

test_that("calibrate_greg() rejects unsupported class", {
  targets <- .make_targets()

  expect_error(
    calibrate_greg(list(x = 1), targets = targets),
    class = "surveywts_error_unsupported_class"
  )
  expect_snapshot(
    error = TRUE,
    calibrate_greg(list(x = 1), targets = targets)
  )
})

# ---------------------------------------------------------------------------
# 13. survey_replicate is now accepted by .check_input_class()
#     (PR 1: replicate_not_supported branch removed from .check_input_class)
#     calibrate_greg() will still error downstream with a not-yet-implemented
#     error until PR 2 adds the full replicate loop — but the class check
#     no longer rejects it at the gate.
# ---------------------------------------------------------------------------

test_that("calibrate_greg() no longer rejects survey_replicate at class-check gate", {
  df <- make_surveywts_data(seed = 12)
  targets <- .make_targets()
  meta <- surveycore::survey_metadata()
  rep_obj <- surveycore::survey_replicate(
    data = df,
    variables = list(
      ids = NULL, strata = NULL, fpc = NULL,
      weights = "base_weight", nest = FALSE,
      repweights = c("base_weight"), scale = 0.5, rscales = 1,
      type = "BRR", mse = TRUE
    ),
    metadata = meta,
    groups = character(0),
    call = NULL
  )

  # .check_input_class() no longer throws surveywts_error_replicate_not_supported
  # for survey_replicate objects (PR 1 change).
  expect_no_error(.check_input_class(rep_obj))
})

# ---------------------------------------------------------------------------
# 14. Error — surveywts_error_empty_data
# ---------------------------------------------------------------------------

test_that("calibrate_greg() rejects 0-row data", {
  df <- make_surveywts_data(seed = 13)[0, ]
  targets <- .make_targets()

  expect_error(
    calibrate_greg(df, targets = targets),
    class = "surveywts_error_empty_data"
  )
  expect_snapshot(
    error = TRUE,
    calibrate_greg(df, targets = targets)
  )
})

# ---------------------------------------------------------------------------
# 15. Error — surveywts_error_weights_not_found
# ---------------------------------------------------------------------------

test_that("calibrate_greg() rejects nonexistent weight column", {
  df <- make_surveywts_data(seed = 14)
  targets <- .make_targets()

  expect_error(
    calibrate_greg(df, targets = targets, weights = nonexistent_col),
    class = "surveywts_error_weights_not_found"
  )
  expect_snapshot(
    error = TRUE,
    calibrate_greg(df, targets = targets, weights = nonexistent_col)
  )
})

# ---------------------------------------------------------------------------
# 16. Error — surveywts_error_weights_not_numeric
# ---------------------------------------------------------------------------

test_that("calibrate_greg() rejects character weight column", {
  df <- make_surveywts_data(seed = 15)
  df$chr_wt <- as.character(df$base_weight)
  targets <- .make_targets()

  expect_error(
    calibrate_greg(df, targets = targets, weights = chr_wt),
    class = "surveywts_error_weights_not_numeric"
  )
  expect_snapshot(
    error = TRUE,
    calibrate_greg(df, targets = targets, weights = chr_wt)
  )
})

# ---------------------------------------------------------------------------
# 17. Error — surveywts_error_weights_nonpositive
# ---------------------------------------------------------------------------

test_that("calibrate_greg() rejects weight column with 0", {
  df <- make_surveywts_data(seed = 16)
  df$base_weight[1] <- 0
  targets <- .make_targets()

  expect_error(
    calibrate_greg(df, targets = targets, weights = base_weight),
    class = "surveywts_error_weights_nonpositive"
  )
  expect_snapshot(
    error = TRUE,
    calibrate_greg(df, targets = targets, weights = base_weight)
  )
})

# ---------------------------------------------------------------------------
# 18. Error — surveywts_error_weights_na
# ---------------------------------------------------------------------------

test_that("calibrate_greg() rejects weight column with NA", {
  df <- make_surveywts_data(seed = 17)
  df$base_weight[2] <- NA_real_
  targets <- .make_targets()

  expect_error(
    calibrate_greg(df, targets = targets, weights = base_weight),
    class = "surveywts_error_weights_na"
  )
  expect_snapshot(
    error = TRUE,
    calibrate_greg(df, targets = targets, weights = base_weight)
  )
})

# ---------------------------------------------------------------------------
# 19. Error — surveywts_error_wt_name_not_scalar
# ---------------------------------------------------------------------------

test_that("calibrate_greg() rejects wt_name = c('a', 'b')", {
  df <- make_surveywts_data(seed = 18)
  targets <- .make_targets()

  expect_error(
    calibrate_greg(df, targets = targets, wt_name = c("a", "b")),
    class = "surveywts_error_wt_name_not_scalar"
  )
  expect_snapshot(
    error = TRUE,
    calibrate_greg(df, targets = targets, wt_name = c("a", "b"))
  )
})

# ---------------------------------------------------------------------------
# 20. Error — surveywts_error_wt_name_empty
# ---------------------------------------------------------------------------

test_that("calibrate_greg() rejects wt_name = ''", {
  df <- make_surveywts_data(seed = 19)
  targets <- .make_targets()

  expect_error(
    calibrate_greg(df, targets = targets, wt_name = ""),
    class = "surveywts_error_wt_name_empty"
  )
  expect_snapshot(
    error = TRUE,
    calibrate_greg(df, targets = targets, wt_name = "")
  )
})

# ---------------------------------------------------------------------------
# 21. Error — surveywts_error_reference_design_not_taylor
# ---------------------------------------------------------------------------

test_that("calibrate_greg() rejects non-taylor reference_design", {
  df <- make_surveywts_data(seed = 20)
  targets <- .make_targets()

  expect_error(
    calibrate_greg(df, targets = targets, reference_design = list()),
    class = "surveywts_error_reference_design_not_taylor"
  )
  expect_snapshot(
    error = TRUE,
    calibrate_greg(df, targets = targets, reference_design = list())
  )
})

# ---------------------------------------------------------------------------
# 22. Error — surveywts_error_margins_format_invalid
# ---------------------------------------------------------------------------

test_that("calibrate_greg() rejects targets = 42 (not a list or data frame)", {
  df <- make_surveywts_data(seed = 21)

  expect_error(
    calibrate_greg(df, targets = 42),
    class = "surveywts_error_margins_format_invalid"
  )
  expect_snapshot(
    error = TRUE,
    calibrate_greg(df, targets = 42)
  )
})

# ---------------------------------------------------------------------------
# 23. Error — surveywts_error_targets_variable_not_found
# ---------------------------------------------------------------------------

test_that("calibrate_greg() rejects targets naming absent column", {
  df <- make_surveywts_data(seed = 22)
  targets <- list(
    age_group = c("18-34" = 0.30, "35-54" = 0.40, "55+" = 0.30),
    nonexistent_var = c("A" = 0.5, "B" = 0.5)
  )

  expect_error(
    calibrate_greg(df, targets = targets),
    class = "surveywts_error_targets_variable_not_found"
  )
  expect_snapshot(
    error = TRUE,
    calibrate_greg(df, targets = targets)
  )
})

# ---------------------------------------------------------------------------
# 24. Error — surveywts_error_variable_not_categorical
# ---------------------------------------------------------------------------

test_that("calibrate_greg() rejects numeric calibration variable", {
  df <- make_surveywts_data(seed = 23)
  df$num_var <- as.numeric(seq_len(nrow(df)))
  targets <- list(num_var = c("1" = 1.0))

  expect_error(
    calibrate_greg(df, targets = targets),
    class = "surveywts_error_variable_not_categorical"
  )
  expect_snapshot(
    error = TRUE,
    calibrate_greg(df, targets = targets)
  )
})

# ---------------------------------------------------------------------------
# 25. Error — surveywts_error_variable_has_na
# ---------------------------------------------------------------------------

test_that("calibrate_greg() rejects calibration variable with NA", {
  df <- make_surveywts_data(seed = 24)
  df$age_group[5] <- NA_character_
  targets <- .make_targets()

  expect_error(
    calibrate_greg(df, targets = targets),
    class = "surveywts_error_variable_has_na"
  )
  expect_snapshot(
    error = TRUE,
    calibrate_greg(df, targets = targets)
  )
})

# ---------------------------------------------------------------------------
# 26. Error — surveywts_error_population_level_missing
# ---------------------------------------------------------------------------

test_that("calibrate_greg() rejects targets missing a data level", {
  df <- make_surveywts_data(seed = 25)
  targets <- list(
    age_group = c("18-34" = 0.50, "35-54" = 0.50),  # missing "55+"
    sex = c("M" = 0.48, "F" = 0.52)
  )

  expect_error(
    calibrate_greg(df, targets = targets),
    class = "surveywts_error_population_level_missing"
  )
  expect_snapshot(
    error = TRUE,
    calibrate_greg(df, targets = targets)
  )
})

# ---------------------------------------------------------------------------
# 27. Error — surveywts_error_population_level_extra
# ---------------------------------------------------------------------------

test_that("calibrate_greg() rejects targets with extra level not in data", {
  df <- make_surveywts_data(seed = 26)
  targets <- list(
    age_group = c("18-34" = 0.20, "35-54" = 0.35, "55+" = 0.30, "65+" = 0.15),
    sex = c("M" = 0.48, "F" = 0.52)
  )

  expect_error(
    calibrate_greg(df, targets = targets),
    class = "surveywts_error_population_level_extra"
  )
  expect_snapshot(
    error = TRUE,
    calibrate_greg(df, targets = targets)
  )
})

# ---------------------------------------------------------------------------
# 28. Error — surveywts_error_population_totals_invalid (prop not sum to 1)
# ---------------------------------------------------------------------------

test_that("calibrate_greg() rejects proportions summing to 0.9", {
  df <- make_surveywts_data(seed = 27)
  targets <- list(
    age_group = c("18-34" = 0.30, "35-54" = 0.30, "55+" = 0.20),  # sums to 0.8
    sex = c("M" = 0.48, "F" = 0.52)
  )

  expect_error(
    calibrate_greg(df, targets = targets),
    class = "surveywts_error_population_totals_invalid"
  )
  expect_snapshot(
    error = TRUE,
    calibrate_greg(df, targets = targets)
  )
})

# ---------------------------------------------------------------------------
# 29. Error — surveywts_error_population_totals_invalid (count, marginal
#     sums differ > 1e-3)
# ---------------------------------------------------------------------------

test_that("calibrate_greg() rejects type='count' with inconsistent marginal sums", {
  df <- make_surveywts_data(n = 200, seed = 28)
  # age_group sums to 500, sex sums to 550 — differ by 50 > 1e-3
  targets <- list(
    age_group = c("18-34" = 150, "35-54" = 200, "55+" = 150),  # sum = 500
    sex = c("M" = 270, "F" = 280)                               # sum = 550
  )

  expect_error(
    calibrate_greg(df, targets = targets, type = "count"),
    class = "surveywts_error_population_totals_invalid"
  )
  expect_snapshot(
    error = TRUE,
    calibrate_greg(df, targets = targets, type = "count")
  )
})

# ---------------------------------------------------------------------------
# 30. Error — surveywts_error_calibration_not_converged
# ---------------------------------------------------------------------------

test_that("calibrate_greg() throws calibration_not_converged with extreme targets + logit", {
  df <- make_surveywts_data(seed = 29)
  targets <- .make_targets()

  expect_error(
    calibrate_greg(
      df, targets = targets, model = "logit",
      control = list(maxit = 1)
    ),
    class = "surveywts_error_calibration_not_converged"
  )
  # No snapshot: survey::grake() embeds platform-specific values in messages
})

# ---------------------------------------------------------------------------
# 31. Warning — surveywts_warning_negative_calibrated_weights
# ---------------------------------------------------------------------------

test_that("calibrate_greg() warns on negative calibrated weights", {
  df <- make_surveywts_data(n = 100, seed = 30)
  targets <- list(
    age_group = c("18-34" = 0.99, "35-54" = 0.005, "55+" = 0.005),
    sex = c("M" = 0.5, "F" = 0.5)
  )

  expect_warning(
    result <- calibrate_greg(
      df, targets = targets, model = "linear"
    ),
    class = "surveywts_warning_negative_calibrated_weights"
  )
  expect_snapshot(
    calibrate_greg(df, targets = targets, model = "linear")
  )
})

# ---------------------------------------------------------------------------
# 32. Warning — surveywts_warning_control_param_ignored
# ---------------------------------------------------------------------------

test_that("calibrate_greg() warns on unrecognized control key", {
  df <- make_surveywts_data(seed = 31)
  targets <- .make_targets()

  expect_warning(
    result <- calibrate_greg(
      df, targets = targets,
      control = list(maxit = 10, pval = 0.05)
    ),
    class = "surveywts_warning_control_param_ignored"
  )
  expect_snapshot(
    calibrate_greg(
      df, targets = targets,
      control = list(maxit = 10, pval = 0.05)
    )
  )
})

# ---------------------------------------------------------------------------
# 33. Edge case — 0-row data -> error
# ---------------------------------------------------------------------------

test_that("calibrate_greg() rejects 0-row data (edge case)", {
  df <- data.frame(
    age_group = character(0),
    sex = character(0),
    base_weight = numeric(0),
    stringsAsFactors = FALSE
  )
  targets <- .make_targets()

  expect_error(
    calibrate_greg(df, targets = targets),
    class = "surveywts_error_empty_data"
  )
})

# ---------------------------------------------------------------------------
# 34. Edge case — 1-row data -> completes
# ---------------------------------------------------------------------------

test_that("calibrate_greg() handles single-row data", {
  df <- data.frame(
    age_group = "18-34",
    sex = "M",
    base_weight = 1.0,
    stringsAsFactors = FALSE
  )
  targets <- list(
    age_group = c("18-34" = 1.0),
    sex = c("M" = 1.0)
  )

  result <- calibrate_greg(df, targets = targets, weights = base_weight)

  test_invariants(result)
  expect_identical(nrow(result), 1L)
})

# ---------------------------------------------------------------------------
# 35. Edge case — single-level calibration variable
# ---------------------------------------------------------------------------

test_that("calibrate_greg() handles single-level calibration variable", {
  df <- make_surveywts_data(n = 100, seed = 32)
  df$constant <- "only"
  targets <- list(
    constant = c("only" = 1.0),
    sex = c("M" = 0.5, "F" = 0.5)
  )

  result <- calibrate_greg(df, targets = targets)

  test_invariants(result)
  expect_true(inherits(result, "weighted_df"))
})

# ---------------------------------------------------------------------------
# 36. Edge case — Format B targets -> identical to Format A
# ---------------------------------------------------------------------------

test_that("calibrate_greg() Format B targets give identical result to Format A", {
  df <- make_surveywts_data(n = 200, seed = 33)

  targets_a <- list(
    sex = c("M" = 0.48, "F" = 0.52)
  )
  targets_b <- data.frame(
    variable = c("sex", "sex"),
    level = c("M", "F"),
    target = c(0.48, 0.52),
    stringsAsFactors = FALSE
  )

  result_a <- calibrate_greg(df, targets = targets_a)
  result_b <- calibrate_greg(df, targets = targets_b)

  test_invariants(result_a)
  test_invariants(result_b)
  expect_equal(result_a[["wts"]], result_b[["wts"]], tolerance = 1e-10)
})

# ---------------------------------------------------------------------------
# 37. History field — operation = "calibrate_greg"
# ---------------------------------------------------------------------------

test_that("calibrate_greg() history entry has operation = 'calibrate_greg'", {
  df <- make_surveywts_data(seed = 34)
  targets <- .make_targets()

  result <- calibrate_greg(df, targets = targets)

  history <- attr(result, "weighting_history")
  op <- history[[1L]]$operation
  expect_identical(op, "calibrate_greg")
})

# ---------------------------------------------------------------------------
# 38. History — targets stored as Format A named list
# ---------------------------------------------------------------------------

test_that("calibrate_greg() history stores targets as Format A named list", {
  df <- make_surveywts_data(seed = 35)
  targets <- .make_targets()

  result <- calibrate_greg(df, targets = targets)

  history <- attr(result, "weighting_history")
  stored_targets <- history[[1L]]$parameters$targets
  expect_true(is.list(stored_targets))
  expect_true(!is.null(names(stored_targets)))
  expect_true(is.numeric(stored_targets[[1]]))
})

# ---------------------------------------------------------------------------
# 39. History — model stored in parameters
# ---------------------------------------------------------------------------

test_that("calibrate_greg() history stores model in parameters", {
  df <- make_surveywts_data(seed = 36)
  targets <- .make_targets()

  result <- calibrate_greg(df, targets = targets, model = "logit")

  history <- attr(result, "weighting_history")
  expect_identical(history[[1L]]$parameters$model, "logit")
})

# ---------------------------------------------------------------------------
# 40. Deleted-function regression guard: old calibrate() signature no longer works
# ---------------------------------------------------------------------------

test_that("old calibrate() with variables + population args no longer exists", {
  df <- make_surveywts_data(seed = 37)
  pop <- list(
    age_group = c("18-34" = 0.30, "35-54" = 0.40, "55+" = 0.30)
  )

  # calibrate() is gone; calling with old-style variables + population should error
  # (either function not found or unknown argument error)
  expect_error(
    calibrate(df, variables = c(age_group), population = pop)
  )
})

# ===========================================================================
# calibrate() Thin Dispatcher — Section added in PR 2
# Per plans/test-spec-calibration-api.md §calibrate() — Thin Dispatcher
# ===========================================================================

# ---------------------------------------------------------------------------
# D1. Happy path — method = "greg" (explicit)
# ---------------------------------------------------------------------------

test_that("calibrate() with method = 'greg' returns same result as calibrate_greg()", {
  df      <- make_surveywts_data(seed = 101)
  targets <- .make_targets()

  direct     <- calibrate_greg(df, targets = targets)
  dispatcher <- calibrate(df, targets = targets, method = "greg")

  test_invariants(dispatcher)
  expect_true(inherits(dispatcher, "weighted_df"))
  # Weights should be identical (same computation path)
  expect_equal(dispatcher[["wts"]], direct[["wts"]], tolerance = 1e-10)
})

# ---------------------------------------------------------------------------
# D2. Happy path — method = "rake"
# ---------------------------------------------------------------------------

test_that("calibrate() with method = 'rake' returns same result as calibrate_rake()", {
  df      <- make_surveywts_data(seed = 102)
  targets <- .make_targets()

  direct     <- calibrate_rake(df, targets = targets)
  dispatcher <- calibrate(df, targets = targets, method = "rake")

  test_invariants(dispatcher)
  expect_true(inherits(dispatcher, "weighted_df"))
  expect_equal(dispatcher[["wts"]], direct[["wts"]], tolerance = 1e-10)
})

# ---------------------------------------------------------------------------
# D3. Happy path — method = "poststrat"
# ---------------------------------------------------------------------------

test_that("calibrate() with method = 'poststrat' returns same as calibrate_poststrat()", {
  df  <- make_surveywts_data(seed = 103)
  pop <- data.frame(
    age_group = c("18-34", "18-34", "35-54", "35-54", "55+", "55+"),
    sex       = c("M",     "F",     "M",     "F",     "M",   "F"),
    target    = c(1440L, 1560L, 1920L, 2080L, 1680L, 1320L),
    stringsAsFactors = FALSE
  )

  direct     <- calibrate_poststrat(df, targets = pop, type = "count")
  dispatcher <- calibrate(df, targets = pop, type = "count",
                          method = "poststrat")

  test_invariants(dispatcher)
  expect_true(inherits(dispatcher, "weighted_df"))
  expect_equal(dispatcher[["wts"]], direct[["wts"]], tolerance = 1e-10)
})

# ---------------------------------------------------------------------------
# D4. Happy path — default method = "greg"
# ---------------------------------------------------------------------------

test_that("calibrate() default method dispatches to calibrate_greg()", {
  df      <- make_surveywts_data(seed = 104)
  targets <- .make_targets()

  direct     <- calibrate_greg(df, targets = targets)
  dispatcher <- calibrate(df, targets = targets)  # no method arg

  test_invariants(dispatcher)
  expect_true(inherits(dispatcher, "weighted_df"))
  expect_equal(dispatcher[["wts"]], direct[["wts"]], tolerance = 1e-10)
})

# ---------------------------------------------------------------------------
# D5. Happy path — NSE weights forwarded correctly
# ---------------------------------------------------------------------------

test_that("calibrate() forwards NSE weights correctly to dispatched function", {
  df      <- make_surveywts_data(seed = 105)
  targets <- .make_targets()

  direct     <- calibrate_greg(df, targets = targets, weights = base_weight)
  dispatcher <- calibrate(df, targets = targets, weights = base_weight)

  test_invariants(dispatcher)
  expect_equal(dispatcher[["wts"]], direct[["wts"]], tolerance = 1e-10)
})

# ---------------------------------------------------------------------------
# D6. Error — invalid method triggers rlang::arg_match() error
# ---------------------------------------------------------------------------

test_that("calibrate() with invalid method triggers arg_match error", {
  df      <- make_surveywts_data(seed = 106)
  targets <- .make_targets()

  # rlang::arg_match() error — no class= snapshot needed (not a cli_abort())
  expect_error(
    calibrate(df, targets = targets, method = "bad_method")
  )
})

# ---------------------------------------------------------------------------
# D7. Error — unknown ... arg for method = "greg" propagates from calibrate_greg()
# ---------------------------------------------------------------------------

test_that("calibrate() propagates unknown ... arg error from calibrate_greg()", {
  df      <- make_surveywts_data(seed = 107)
  targets <- .make_targets()

  # calibrate_greg() does not accept 'unknown_arg'
  expect_error(
    calibrate(df, targets = targets, method = "greg", unknown_arg = 42)
  )
})

# ===========================================================================
# Infrastructure helpers — PR 1 tests
# ===========================================================================

# Helper: build a minimal survey_replicate for testing
.make_test_replicate <- function(seed = 200) {
  df <- make_surveywts_data(n = 100L, seed = seed)
  taylor <- surveycore::survey_taylor(
    data = df,
    variables = list(weights = "base_weight")
  )
  create_bootstrap_weights(taylor, replicates = 10L)
}

# ---------------------------------------------------------------------------
# Infra-1. .check_input_class() accepts survey_replicate without error
# ---------------------------------------------------------------------------

test_that(".check_input_class() accepts survey_replicate without throwing", {
  rep_obj <- .make_test_replicate(seed = 201)
  # After PR 1, survey_replicate is a supported class — no error thrown
  expect_no_error(.check_input_class(rep_obj))
})

# ---------------------------------------------------------------------------
# Infra-2a. .update_survey_weights() with caldata sets @calibration
# ---------------------------------------------------------------------------

test_that(
  ".update_survey_weights() with caldata = list(...) sets design@calibration",
  {
    # Use survey_nonprob which has @calibration property (survey_taylor does not)
    df <- make_surveywts_data(n = 50L, seed = 202)
    design <- surveycore::survey_nonprob(
      data = df,
      variables = list(weights = "base_weight"),
      metadata = surveycore::survey_metadata(),
      groups = character(0),
      call = NULL,
      calibration = NULL
    )
    new_wts <- design@data[["base_weight"]] * 1.05
    entry <- .make_history_entry(
      step = 1L,
      operation = "calibration",
      weight_col = "base_weight",
      call_str = "test",
      parameters = list(),
      before_stats = .compute_weight_stats(design@data[["base_weight"]]),
      after_stats = .compute_weight_stats(new_wts),
      convergence = list(
        converged = TRUE, iterations = 1L,
        max_error = 0, tolerance = 1e-6
      )
    )
    fake_caldata <- list(method = "linear", x_matrix = matrix(1, 1, 1))
    result <- .update_survey_weights(design, new_wts, entry,
                                     caldata = fake_caldata)
    expect_identical(result@calibration, fake_caldata)
  }
)

# ---------------------------------------------------------------------------
# Infra-2b. .update_survey_weights() with caldata = NULL leaves @calibration
# ---------------------------------------------------------------------------

test_that(
  ".update_survey_weights() with caldata = NULL leaves @calibration unchanged",
  {
    # Use survey_nonprob which has @calibration property (survey_taylor does not)
    df <- make_surveywts_data(n = 50L, seed = 203)
    design <- surveycore::survey_nonprob(
      data = df,
      variables = list(weights = "base_weight"),
      metadata = surveycore::survey_metadata(),
      groups = character(0),
      call = NULL,
      calibration = NULL
    )
    new_wts <- design@data[["base_weight"]] * 1.02
    entry <- .make_history_entry(
      step = 1L,
      operation = "calibration",
      weight_col = "base_weight",
      call_str = "test",
      parameters = list(),
      before_stats = .compute_weight_stats(design@data[["base_weight"]]),
      after_stats = .compute_weight_stats(new_wts),
      convergence = list(
        converged = TRUE, iterations = 1L,
        max_error = 0, tolerance = 1e-6
      )
    )
    # @calibration is NULL before (newly constructed design)
    result <- .update_survey_weights(design, new_wts, entry, caldata = NULL)
    expect_null(result@calibration)
  }
)

# ---------------------------------------------------------------------------
# Infra-3. .build_calibration_provenance() — direct tests
# ---------------------------------------------------------------------------

# Helper: build minimal engine_result and inputs for provenance tests
.make_provenance_inputs <- function(n = 50L, seed = 204) {
  set.seed(seed)
  base_weights <- exp(stats::rnorm(n, 0, 0.4))
  q_weights <- rep(1, n)
  age <- sample(c("A", "B", "C"), n, replace = TRUE, prob = c(0.3, 0.4, 0.3))
  x_matrix <- stats::model.matrix(
    ~ age,
    data = data.frame(age = factor(age, levels = c("A", "B", "C")))
  )
  J <- ncol(x_matrix)
  # Population totals: intercept = sum(base_weights), then marginals
  total_w <- sum(base_weights)
  pop_totals <- stats::setNames(numeric(J), colnames(x_matrix))
  pop_totals["(Intercept)"] <- total_w
  prop_b <- 0.40
  prop_c <- 0.30
  pop_totals["ageB"] <- prop_b * total_w
  pop_totals["ageC"] <- prop_c * total_w

  # Calibrate to get engine_result
  data_df <- data.frame(age = factor(age, levels = c("A", "B", "C")),
                        .wt_tmp = base_weights)
  svy_tmp <- survey::svydesign(ids = ~1, weights = ~.wt_tmp, data = data_df)
  fml <- stats::as.formula("~ age")
  cal <- survey::calibrate(svy_tmp, formula = fml, population = pop_totals,
                            calfun = survey::cal.linear)
  calibrated_weights <- as.numeric(stats::weights(cal))

  engine_result <- list(
    weights = calibrated_weights,
    convergence = list(converged = TRUE, iterations = 1L,
                       max_error = 0, tolerance = 1e-6)
  )

  list(
    engine_result = engine_result,
    x_matrix = x_matrix,
    base_weights = base_weights,
    q_weights = q_weights,
    population_totals = pop_totals,
    calibrated_weights = calibrated_weights
  )
}

test_that(
  ".build_calibration_provenance() returns named list with all 12 required fields",
  {
    skip_if_not_installed("survey")
    inp <- .make_provenance_inputs()
    result <- .build_calibration_provenance(
      engine_result    = inp$engine_result,
      x_matrix         = inp$x_matrix,
      base_weights     = inp$base_weights,
      q_weights        = inp$q_weights,
      population_totals = inp$population_totals,
      method           = "linear",
      cell_factors     = NULL
    )
    required_fields <- c(
      "x_matrix", "base_weights", "g_weights", "crossproduct_inv",
      "population_totals", "discrepancy", "lambda", "method",
      "cell_factors", "q_weights", "converged", "n_iterations"
    )
    expect_true(all(required_fields %in% names(result)))
    # replicate_converged is NOT in the list — callers add it
    expect_false("replicate_converged" %in% names(result))
  }
)

test_that(
  ".build_calibration_provenance() g_weights identity: g_weights * base == engine weights",
  {
    skip_if_not_installed("survey")
    inp <- .make_provenance_inputs()
    result <- .build_calibration_provenance(
      engine_result    = inp$engine_result,
      x_matrix         = inp$x_matrix,
      base_weights     = inp$base_weights,
      q_weights        = inp$q_weights,
      population_totals = inp$population_totals,
      method           = "linear"
    )
    expect_equal(
      result$g_weights * result$base_weights,
      inp$calibrated_weights,
      tolerance = 1e-10
    )
  }
)

test_that(
  ".build_calibration_provenance() discrepancy = population_totals - t(X) %*% base_weights",
  {
    skip_if_not_installed("survey")
    inp <- .make_provenance_inputs()
    result <- .build_calibration_provenance(
      engine_result    = inp$engine_result,
      x_matrix         = inp$x_matrix,
      base_weights     = inp$base_weights,
      q_weights        = inp$q_weights,
      population_totals = inp$population_totals,
      method           = "linear"
    )
    expected_discrepancy <- inp$population_totals -
      drop(t(inp$x_matrix) %*% inp$base_weights)
    expect_equal(result$discrepancy, expected_discrepancy, tolerance = 1e-10)
  }
)

test_that(
  ".build_calibration_provenance() crossproduct_inv %*% C approximates identity",
  {
    skip_if_not_installed("survey")
    inp <- .make_provenance_inputs()
    result <- .build_calibration_provenance(
      engine_result    = inp$engine_result,
      x_matrix         = inp$x_matrix,
      base_weights     = inp$base_weights,
      q_weights        = inp$q_weights,
      population_totals = inp$population_totals,
      method           = "linear"
    )
    J <- ncol(inp$x_matrix)
    C <- t(inp$x_matrix) %*%
      (inp$base_weights * inp$q_weights * inp$x_matrix)
    identity_approx <- result$crossproduct_inv %*% C
    # Strip dimnames before comparing — matrix multiplication retains names
    # from the operands, but diag() has no dimnames.
    dimnames(identity_approx) <- NULL
    expect_equal(identity_approx, diag(J), tolerance = 1e-8)
  }
)

test_that(
  ".build_calibration_provenance() lambda = crossproduct_inv %*% discrepancy for linear",
  {
    skip_if_not_installed("survey")
    inp <- .make_provenance_inputs()
    result <- .build_calibration_provenance(
      engine_result    = inp$engine_result,
      x_matrix         = inp$x_matrix,
      base_weights     = inp$base_weights,
      q_weights        = inp$q_weights,
      population_totals = inp$population_totals,
      method           = "linear"
    )
    expected_lambda <- result$crossproduct_inv %*% result$discrepancy
    expect_equal(result$lambda, expected_lambda, tolerance = 1e-10)
  }
)

test_that(
  ".build_calibration_provenance() lambda = crossproduct_inv %*% discrepancy for logit",
  {
    skip_if_not_installed("survey")
    inp <- .make_provenance_inputs()
    result <- .build_calibration_provenance(
      engine_result    = inp$engine_result,
      x_matrix         = inp$x_matrix,
      base_weights     = inp$base_weights,
      q_weights        = inp$q_weights,
      population_totals = inp$population_totals,
      method           = "logit"
    )
    expected_lambda <- result$crossproduct_inv %*% result$discrepancy
    expect_equal(result$lambda, expected_lambda, tolerance = 1e-10)
  }
)

test_that(
  ".build_calibration_provenance() lambda is NULL for method = 'raking'",
  {
    skip_if_not_installed("survey")
    inp <- .make_provenance_inputs()
    result <- .build_calibration_provenance(
      engine_result    = inp$engine_result,
      x_matrix         = inp$x_matrix,
      base_weights     = inp$base_weights,
      q_weights        = inp$q_weights,
      population_totals = inp$population_totals,
      method           = "raking"
    )
    expect_null(result$lambda)
  }
)

test_that(
  ".build_calibration_provenance() lambda is NULL for method = 'poststrat'",
  {
    skip_if_not_installed("survey")
    inp <- .make_provenance_inputs()
    result <- .build_calibration_provenance(
      engine_result    = inp$engine_result,
      x_matrix         = inp$x_matrix,
      base_weights     = inp$base_weights,
      q_weights        = inp$q_weights,
      population_totals = inp$population_totals,
      method           = "poststrat"
    )
    expect_null(result$lambda)
  }
)

test_that(
  ".build_calibration_provenance() converged = engine_result$convergence$converged",
  {
    skip_if_not_installed("survey")
    inp <- .make_provenance_inputs()
    result <- .build_calibration_provenance(
      engine_result    = inp$engine_result,
      x_matrix         = inp$x_matrix,
      base_weights     = inp$base_weights,
      q_weights        = inp$q_weights,
      population_totals = inp$population_totals,
      method           = "linear"
    )
    expect_identical(result$converged, inp$engine_result$convergence$converged)
  }
)

test_that(
  ".build_calibration_provenance() n_iterations = as.integer(engine_result$convergence$iterations)",
  {
    skip_if_not_installed("survey")
    inp <- .make_provenance_inputs()
    result <- .build_calibration_provenance(
      engine_result    = inp$engine_result,
      x_matrix         = inp$x_matrix,
      base_weights     = inp$base_weights,
      q_weights        = inp$q_weights,
      population_totals = inp$population_totals,
      method           = "linear"
    )
    expect_identical(
      result$n_iterations,
      as.integer(inp$engine_result$convergence$iterations)
    )
  }
)

test_that(
  ".build_calibration_provenance() cell_factors = NULL when not provided",
  {
    skip_if_not_installed("survey")
    inp <- .make_provenance_inputs()
    result <- .build_calibration_provenance(
      engine_result    = inp$engine_result,
      x_matrix         = inp$x_matrix,
      base_weights     = inp$base_weights,
      q_weights        = inp$q_weights,
      population_totals = inp$population_totals,
      method           = "linear",
      cell_factors     = NULL
    )
    expect_null(result$cell_factors)
  }
)

test_that(
  ".build_calibration_provenance() return value is visible (not invisible)",
  {
    skip_if_not_installed("survey")
    inp <- .make_provenance_inputs()
    # Direct assignment without print() — verifies the function is not invisible
    caldata <- .build_calibration_provenance(
      engine_result    = inp$engine_result,
      x_matrix         = inp$x_matrix,
      base_weights     = inp$base_weights,
      q_weights        = inp$q_weights,
      population_totals = inp$population_totals,
      method           = "linear"
    )
    expect_true(is.list(caldata))
    expect_true("x_matrix" %in% names(caldata))
  }
)
