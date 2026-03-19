# tests/testthat/test-02-calibrate.R
#
# Tests for calibrate()
# Per spec §XIII calibrate() test items 1–19, 13c, 13d, 14b
# Per impl plan PR 5 acceptance criteria
#
# All error path tests use the dual pattern:
#   expect_error(class = ...) + expect_snapshot(error = TRUE, ...)
# Warning tests use:
#   expect_warning(class = ...) + expect_snapshot()

# ---------------------------------------------------------------------------
# Helper: build survey_taylor fixture (requires surveycore)
# ---------------------------------------------------------------------------

.make_test_taylor <- function(df, weight_col = "base_weight") {
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
# Population targets for standard tests
# ---------------------------------------------------------------------------

.make_pop <- function(type = "prop") {
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
# 1. Happy path — data.frame → weighted_df
# ---------------------------------------------------------------------------

test_that("calibrate() returns weighted_df for data.frame input", {
  df <- make_surveywts_data(seed = 1)
  pop <- .make_pop()

  result <- calibrate(df, variables = c(age_group, sex), population = pop)

  test_invariants(result)
  expect_true(inherits(result, "weighted_df"))
  expect_identical(attr(result, "weight_col"), ".weight")
  expect_true(all(result[[".weight"]] > 0))
})

# ---------------------------------------------------------------------------
# 1b. Happy path — factor-typed variable column
# ---------------------------------------------------------------------------

test_that("calibrate() handles factor variables the same as character", {
  df <- make_surveywts_data(seed = 2)
  df$age_group <- factor(df$age_group, levels = c("18-34", "35-54", "55+"))
  pop <- .make_pop()

  result <- calibrate(df, variables = c(age_group, sex), population = pop)

  test_invariants(result)
  expect_true(inherits(result, "weighted_df"))
})

# ---------------------------------------------------------------------------
# 2. Happy path — survey_taylor → survey_taylor (class preserved)
# ---------------------------------------------------------------------------

test_that("calibrate() preserves survey_taylor class for survey_taylor input", {
  df <- make_surveywts_data(seed = 3)
  design <- .make_test_taylor(df)
  pop <- .make_pop()

  result <- calibrate(design, variables = c(age_group, sex), population = pop)

  test_invariants(result)
  expect_true(S7::S7_inherits(result, surveycore::survey_taylor))
  expect_false(S7::S7_inherits(result, surveycore::survey_nonprob))
  # Design vars are unchanged
  expect_identical(result@variables$ids,    design@variables$ids)
  expect_identical(result@variables$strata, design@variables$strata)
  expect_identical(result@variables$fpc,    design@variables$fpc)
  expect_identical(result@variables$nest,   design@variables$nest)
  # Weights changed
  expect_false(identical(result@data[[result@variables$weights]],
                         design@data[[design@variables$weights]]))
  expect_identical(length(result@metadata@weighting_history), 1L)
})

# ---------------------------------------------------------------------------
# 2a. Happy path — multiple variables explicitly verified
# ---------------------------------------------------------------------------

test_that("calibrate() calibrates all variables in population correctly", {
  df <- make_surveywts_data(seed = 4)
  pop <- list(
    age_group = c("18-34" = 0.30, "35-54" = 0.40, "55+" = 0.30),
    sex = c("M" = 0.48, "F" = 0.52),
    education = c("<HS" = 0.10, "HS" = 0.30, "College" = 0.40, "Graduate" = 0.20)
  )

  result <- calibrate(
    df,
    variables = c(age_group, sex, education),
    population = pop
  )

  test_invariants(result)
  expect_identical(length(pop), 3L)

  # After calibration, weighted proportions should match targets
  w <- result[[".weight"]]
  total_w <- sum(w)

  for (var in names(pop)) {
    for (lev in names(pop[[var]])) {
      obs_prop <- sum(w[result[[var]] == lev]) / total_w
      expect_equal(obs_prop, pop[[var]][[lev]], tolerance = 1e-6,
                   label = paste0(var, "=", lev))
    }
  }
})

# ---------------------------------------------------------------------------
# 3. Happy path — weighted_df → weighted_df (history accumulates)
# ---------------------------------------------------------------------------

test_that("calibrate() on weighted_df accumulates weighting history", {
  df <- make_surveywts_data(seed = 5)
  pop <- .make_pop()

  wdf <- calibrate(df, variables = c(age_group, sex), population = pop)
  test_invariants(wdf)
  expect_identical(length(attr(wdf, "weighting_history")), 1L)

  # Second calibration accumulates a second entry
  pop2 <- list(
    age_group = c("18-34" = 0.28, "35-54" = 0.42, "55+" = 0.30),
    sex = c("M" = 0.50, "F" = 0.50)
  )
  wdf2 <- calibrate(wdf, variables = c(age_group, sex), population = pop2,
                    weights = .weight)
  test_invariants(wdf2)
  expect_identical(length(attr(wdf2, "weighting_history")), 2L)
  expect_identical(attr(wdf2, "weighting_history")[[2L]]$step, 2L)
})

# ---------------------------------------------------------------------------
# 4. Happy path — survey_nonprob input → survey_nonprob (re-calibration)
# ---------------------------------------------------------------------------

test_that("calibrate() on survey_nonprob returns survey_nonprob", {
  df <- make_surveywts_data(seed = 6)

  # Construct survey_nonprob directly (not via calibrate())
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

  pop2 <- list(
    age_group = c("18-34" = 0.28, "35-54" = 0.42, "55+" = 0.30),
    sex = c("M" = 0.50, "F" = 0.50)
  )
  sc2 <- calibrate(sc_input, variables = c(age_group, sex), population = pop2)
  test_invariants(sc2)
  expect_true(S7::S7_inherits(sc2, surveycore::survey_nonprob))
  # History should have 1 entry (sc_input had no prior history)
  expect_identical(length(sc2@metadata@weighting_history), 1L)
})

# ---------------------------------------------------------------------------
# 5. Happy path — method = "logit"
# ---------------------------------------------------------------------------

test_that("calibrate() with method = 'logit' produces valid calibrated weights", {
  df <- make_surveywts_data(seed = 7)
  pop <- .make_pop()

  result <- calibrate(df, variables = c(age_group, sex), population = pop,
                      method = "logit")

  test_invariants(result)
  expect_true(inherits(result, "weighted_df"))
  # Logit calibration always produces positive weights
  expect_true(all(result[[".weight"]] > 0))
})

# ---------------------------------------------------------------------------
# 6. Happy path — type = "count"
# ---------------------------------------------------------------------------

test_that("calibrate() with type = 'count' accepts count targets", {
  df <- make_surveywts_data(n = 500, seed = 8)
  pop <- .make_pop("count")

  result <- calibrate(df, variables = c(age_group, sex), population = pop,
                      type = "count")

  test_invariants(result)
  expect_true(inherits(result, "weighted_df"))

  w <- result[[".weight"]]
  total_w <- sum(w)
  for (var in names(pop)) {
    for (lev in names(pop[[var]])) {
      obs_count <- sum(w[result[[var]] == lev])
      expect_equal(obs_count, pop[[var]][[lev]], tolerance = 1e-6,
                   label = paste0(var, "=", lev))
    }
  }
})

# ---------------------------------------------------------------------------
# 7. Numerical correctness vs survey::calibrate()
# ---------------------------------------------------------------------------

test_that("calibrate() matches survey::calibrate() within 1e-8 tolerance", {
  skip_if_not_installed("MASS")

  df <- make_surveywts_data(n = 200, seed = 9)
  pop_prop <- list(
    age_group = c("18-34" = 0.30, "35-54" = 0.40, "55+" = 0.30),
    sex = c("M" = 0.48, "F" = 0.52)
  )
  total_w <- sum(df$base_weight)

  # surveywts calibration
  sw_result <- calibrate(
    df,
    variables = c(age_group, sex),
    population = pop_prop,
    weights = base_weight
  )
  sw_weights <- sw_result[["base_weight"]]

  # survey calibration (reference):
  # Use formula ~age_group + sex (with intercept + k-1 dummies) and construct
  # population targets matching the model.matrix columns.
  # survey::calibrate() uses the formula model matrix internally; we build
  # the matching target vector from the full-indicator parameterisation.
  svy_design <- survey::svydesign(ids = ~1, weights = ~base_weight, data = df)

  # Discover the model matrix columns so our target names match exactly
  mm_cols <- colnames(model.matrix(~age_group + sex, data = df))

  # Build population target vector to match those column names
  pop_totals_vec <- stats::setNames(
    numeric(length(mm_cols)),
    mm_cols
  )
  pop_totals_vec["(Intercept)"] <- total_w
  for (lev in names(pop_prop$age_group)) {
    col_nm <- paste0("age_group", lev)
    if (col_nm %in% mm_cols) {
      pop_totals_vec[col_nm] <- pop_prop$age_group[[lev]] * total_w
    }
  }
  for (lev in names(pop_prop$sex)) {
    col_nm <- paste0("sex", lev)
    if (col_nm %in% mm_cols) {
      pop_totals_vec[col_nm] <- pop_prop$sex[[lev]] * total_w
    }
  }
  # Intercept target = total weight; reference-level targets implied by the
  # intercept constraint (not needed as explicit columns in the k-1 formula).

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
# 8. Standard error paths (SE-1 through SE-8)
# ---------------------------------------------------------------------------

test_that("calibrate() rejects unsupported input class (SE-1)", {
  pop <- .make_pop()
  expect_error(
    calibrate(matrix(1:6, 2, 3), variables = c(age_group), population = pop),
    class = "surveywts_error_unsupported_class"
  )
  expect_snapshot(
    error = TRUE,
    calibrate(matrix(1:6, 2, 3), variables = c(age_group), population = pop)
  )
})

test_that("calibrate() rejects 0-row data frame (SE-2)", {
  df <- make_surveywts_data(seed = 10)[0, ]
  pop <- .make_pop()
  expect_error(
    calibrate(df, variables = c(age_group, sex), population = pop),
    class = "surveywts_error_empty_data"
  )
  expect_snapshot(
    error = TRUE,
    calibrate(df, variables = c(age_group, sex), population = pop)
  )
})

test_that("calibrate() rejects survey_replicate input (SE-3)", {
  pop <- .make_pop()
  df <- make_surveywts_data(seed = 11)
  meta <- surveycore::survey_metadata()
  rep_obj <- surveycore::survey_replicate(
    data = df,
    variables = list(
      ids = NULL, strata = NULL, fpc = NULL,
      weights = "base_weight", nest = FALSE,
      repweights = c("base_weight"), scale = 0.5, rscales = 1, type = "BRR", mse = TRUE
    ),
    metadata = meta,
    groups = character(0),
    call = NULL
  )
  expect_error(
    calibrate(rep_obj, variables = c(age_group, sex), population = pop),
    class = "surveywts_error_replicate_not_supported"
  )
  expect_snapshot(
    error = TRUE,
    calibrate(rep_obj, variables = c(age_group, sex), population = pop)
  )
})

test_that("calibrate() rejects named weight column not in data (SE-4)", {
  df <- make_surveywts_data(seed = 12)
  pop <- .make_pop()
  expect_error(
    calibrate(df, variables = c(age_group, sex), population = pop,
              weights = nonexistent_col),
    class = "surveywts_error_weights_not_found"
  )
  expect_snapshot(
    error = TRUE,
    calibrate(df, variables = c(age_group, sex), population = pop,
              weights = nonexistent_col)
  )
})

test_that("calibrate() rejects non-numeric weight column (SE-5)", {
  df <- make_surveywts_data(seed = 13)
  df$chr_weight <- as.character(df$base_weight)
  pop <- .make_pop()
  expect_error(
    calibrate(df, variables = c(age_group, sex), population = pop,
              weights = chr_weight),
    class = "surveywts_error_weights_not_numeric"
  )
  expect_snapshot(
    error = TRUE,
    calibrate(df, variables = c(age_group, sex), population = pop,
              weights = chr_weight)
  )
})

test_that("calibrate() rejects weight column with non-positive values (SE-6)", {
  df <- make_surveywts_data(seed = 14)
  df$base_weight[1] <- 0
  pop <- .make_pop()
  expect_error(
    calibrate(df, variables = c(age_group, sex), population = pop,
              weights = base_weight),
    class = "surveywts_error_weights_nonpositive"
  )
  expect_snapshot(
    error = TRUE,
    calibrate(df, variables = c(age_group, sex), population = pop,
              weights = base_weight)
  )
})

test_that("calibrate() rejects weight column with NA values (SE-7)", {
  df <- make_surveywts_data(seed = 15)
  df$base_weight[2] <- NA_real_
  pop <- .make_pop()
  expect_error(
    calibrate(df, variables = c(age_group, sex), population = pop,
              weights = base_weight),
    class = "surveywts_error_weights_na"
  )
  expect_snapshot(
    error = TRUE,
    calibrate(df, variables = c(age_group, sex), population = pop,
              weights = base_weight)
  )
})

test_that("calibrate() validation order: empty_data fires before weights_not_found (SE-8)", {
  df <- make_surveywts_data(seed = 16)[0, ]
  pop <- .make_pop()
  # 0-row data WITH a named but missing weight column: empty_data fires first
  expect_error(
    calibrate(df, variables = c(age_group, sex), population = pop,
              weights = nonexistent_col),
    class = "surveywts_error_empty_data"
  )
  expect_snapshot(
    error = TRUE,
    calibrate(df, variables = c(age_group, sex), population = pop,
              weights = nonexistent_col)
  )
})

# ---------------------------------------------------------------------------
# 9. Error — variable_not_categorical
# ---------------------------------------------------------------------------

test_that("calibrate() rejects numeric calibration variable", {
  df <- make_surveywts_data(seed = 17)
  df$num_var <- as.numeric(seq_len(nrow(df)))
  pop <- list(num_var = c("1" = 0.5, "2" = 0.5))

  expect_error(
    calibrate(df, variables = c(num_var), population = pop),
    class = "surveywts_error_variable_not_categorical"
  )
  expect_snapshot(
    error = TRUE,
    calibrate(df, variables = c(num_var), population = pop)
  )
})

# ---------------------------------------------------------------------------
# 10. Error — variable_has_na
# ---------------------------------------------------------------------------

test_that("calibrate() rejects calibration variable with NA values", {
  df <- make_surveywts_data(seed = 18)
  df$age_group[5] <- NA_character_
  pop <- .make_pop()

  expect_error(
    calibrate(df, variables = c(age_group, sex), population = pop),
    class = "surveywts_error_variable_has_na"
  )
  expect_snapshot(
    error = TRUE,
    calibrate(df, variables = c(age_group, sex), population = pop)
  )
})

# ---------------------------------------------------------------------------
# 11. Error — population_variable_not_found
# ---------------------------------------------------------------------------

test_that("calibrate() rejects population name not found in data", {
  df <- make_surveywts_data(seed = 19)
  # population has "nonexistent_var" which is not a column in data
  # variables only selects age_group (which exists)
  pop <- list(
    age_group = c("18-34" = 0.30, "35-54" = 0.40, "55+" = 0.30),
    nonexistent_var = c("A" = 0.5, "B" = 0.5)
  )

  expect_error(
    calibrate(df, variables = c(age_group), population = pop),
    class = "surveywts_error_population_variable_not_found"
  )
  expect_snapshot(
    error = TRUE,
    calibrate(df, variables = c(age_group), population = pop)
  )
})

# ---------------------------------------------------------------------------
# 12. Error — population_level_missing
# ---------------------------------------------------------------------------

test_that("calibrate() rejects population missing a data level", {
  df <- make_surveywts_data(seed = 20)
  # population for age_group is missing "55+"
  pop <- list(
    age_group = c("18-34" = 0.50, "35-54" = 0.50),
    sex = c("M" = 0.48, "F" = 0.52)
  )

  expect_error(
    calibrate(df, variables = c(age_group, sex), population = pop),
    class = "surveywts_error_population_level_missing"
  )
  expect_snapshot(
    error = TRUE,
    calibrate(df, variables = c(age_group, sex), population = pop)
  )
})

# ---------------------------------------------------------------------------
# 12b. Error — population_level_extra
# ---------------------------------------------------------------------------

test_that("calibrate() rejects population with extra level absent from data", {
  df <- make_surveywts_data(seed = 21)
  # population for age_group has extra level "65+" not in data
  pop <- list(
    age_group = c("18-34" = 0.20, "35-54" = 0.35, "55+" = 0.30, "65+" = 0.15),
    sex = c("M" = 0.48, "F" = 0.52)
  )

  expect_error(
    calibrate(df, variables = c(age_group, sex), population = pop),
    class = "surveywts_error_population_level_extra"
  )
  expect_snapshot(
    error = TRUE,
    calibrate(df, variables = c(age_group, sex), population = pop)
  )
})

# ---------------------------------------------------------------------------
# 13. Error — population_totals_invalid (type = "prop", does not sum to 1)
# ---------------------------------------------------------------------------

test_that("calibrate() rejects proportions that do not sum to 1", {
  df <- make_surveywts_data(seed = 22)
  # age_group sums to 0.80 (not 1.0)
  pop <- list(
    age_group = c("18-34" = 0.30, "35-54" = 0.30, "55+" = 0.20),
    sex = c("M" = 0.48, "F" = 0.52)
  )

  expect_error(
    calibrate(df, variables = c(age_group, sex), population = pop),
    class = "surveywts_error_population_totals_invalid"
  )
  expect_snapshot(
    error = TRUE,
    calibrate(df, variables = c(age_group, sex), population = pop)
  )
})

# ---------------------------------------------------------------------------
# 13b. Error — population_totals_invalid (type = "count", target ≤ 0)
# ---------------------------------------------------------------------------

test_that("calibrate() rejects count targets that are non-positive", {
  df <- make_surveywts_data(seed = 23)
  pop <- list(
    age_group = c("18-34" = 150, "35-54" = -1, "55+" = 150),
    sex = c("M" = 240, "F" = 260)
  )

  expect_error(
    calibrate(df, variables = c(age_group, sex), population = pop,
              type = "count"),
    class = "surveywts_error_population_totals_invalid"
  )
  expect_snapshot(
    error = TRUE,
    calibrate(df, variables = c(age_group, sex), population = pop,
              type = "count")
  )
})

# ---------------------------------------------------------------------------
# 13c. Happy path — proportions summing to exactly 1.0 + 9e-7 succeed
# ---------------------------------------------------------------------------

test_that("calibrate() accepts proportions summing to 1.0 + 9e-7 (within 1e-6 tolerance)", {
  df <- make_surveywts_data(seed = 24)
  # sex sums to exactly 1.0 + 9e-7 (within 1e-6 tolerance)
  pop <- list(
    age_group = c("18-34" = 0.30, "35-54" = 0.40, "55+" = 0.30),
    sex = c("M" = 0.48, "F" = 0.52 + 9e-7)
  )

  expect_no_error(
    calibrate(df, variables = c(age_group, sex), population = pop)
  )
})

# ---------------------------------------------------------------------------
# 13d. Error — population_totals_invalid for proportions summing to 1.0 + 2e-6
# ---------------------------------------------------------------------------

test_that("calibrate() rejects proportions summing to 1.0 + 2e-6 (outside 1e-6 tolerance)", {
  df <- make_surveywts_data(seed = 25)
  pop <- list(
    age_group = c("18-34" = 0.30, "35-54" = 0.40, "55+" = 0.30),
    sex = c("M" = 0.48, "F" = 0.52 + 2e-6)
  )

  expect_error(
    calibrate(df, variables = c(age_group, sex), population = pop),
    class = "surveywts_error_population_totals_invalid"
  )
})

# ---------------------------------------------------------------------------
# 14. Error — calibration_not_converged (inconsistent population; hits maxit)
# ---------------------------------------------------------------------------

test_that("calibrate() throws calibration_not_converged when maxit is reached", {
  df <- make_surveywts_data(seed = 26)
  pop <- .make_pop()

  expect_error(
    calibrate(df, variables = c(age_group, sex), population = pop,
              method = "logit", control = list(maxit = 1, epsilon = 1e-20)),
    class = "surveywts_error_calibration_not_converged"
  )
  # No snapshot: survey::grake() embeds platform-specific floating-point

  # values in its convergence message, causing cross-platform snapshot
  # failures. The class= check above is sufficient.
})

# ---------------------------------------------------------------------------
# 14b. Error — calibration_not_converged triggered by control$maxit = 0
# ---------------------------------------------------------------------------

test_that("calibrate() with control$maxit = 0 throws not_converged with distinct note", {
  df <- make_surveywts_data(seed = 27)
  pop <- .make_pop()

  expect_error(
    calibrate(df, variables = c(age_group, sex), population = pop,
              control = list(maxit = 0)),
    class = "surveywts_error_calibration_not_converged"
  )
  expect_snapshot(
    error = TRUE,
    calibrate(df, variables = c(age_group, sex), population = pop,
              control = list(maxit = 0))
  )
})

# ---------------------------------------------------------------------------
# 15. Warning — negative_calibrated_weights
# ---------------------------------------------------------------------------

test_that("calibrate() warns when linear calibration produces negative weights", {
  # Use extreme targets to force negative weights with linear method
  df <- make_surveywts_data(n = 100, seed = 28)
  # All weight to "18-34" so other groups get negative weights
  pop <- list(
    age_group = c("18-34" = 0.99, "35-54" = 0.005, "55+" = 0.005),
    sex = c("M" = 0.5, "F" = 0.5)
  )

  expect_warning(
    result <- calibrate(df, variables = c(age_group, sex), population = pop,
                        method = "linear"),
    class = "surveywts_warning_negative_calibrated_weights"
  )
  expect_snapshot(
    calibrate(df, variables = c(age_group, sex), population = pop,
              method = "linear")
  )
})

# ---------------------------------------------------------------------------
# 16. Edge — single-row data frame
# ---------------------------------------------------------------------------

test_that("calibrate() handles single-row data frame", {
  df <- data.frame(
    age_group = "18-34",
    sex = "M",
    base_weight = 1.0,
    stringsAsFactors = FALSE
  )
  pop <- list(
    age_group = c("18-34" = 1.0),
    sex = c("M" = 1.0)
  )

  result <- calibrate(df, variables = c(age_group, sex), population = pop,
                      weights = base_weight)
  test_invariants(result)
  expect_identical(nrow(result), 1L)
})

# ---------------------------------------------------------------------------
# 17. Edge — single variable in population
# ---------------------------------------------------------------------------

test_that("calibrate() handles single variable in population", {
  df <- make_surveywts_data(seed = 29)
  pop <- list(
    sex = c("M" = 0.48, "F" = 0.52)
  )

  result <- calibrate(df, variables = c(sex), population = pop)
  test_invariants(result)
  expect_true(inherits(result, "weighted_df"))
})

# ---------------------------------------------------------------------------
# 18. History — full structure after calibration
# ---------------------------------------------------------------------------

test_that("calibrate() produces a correctly structured weighting history entry", {
  df <- make_surveywts_data(seed = 30)
  pop <- .make_pop()

  result <- calibrate(df, variables = c(age_group, sex), population = pop)

  history <- attr(result, "weighting_history")
  expect_identical(length(history), 1L)

  entry <- history[[1L]]
  expect_true(is.integer(entry$step))
  expect_identical(entry$operation, "calibration")
  expect_true(inherits(entry$timestamp, "POSIXct"))
  expect_true(nchar(entry$call) > 0)
  expect_true(is.list(entry$parameters))
  expect_true(is.list(entry$weight_stats))
  expect_true(is.list(entry$weight_stats$before))
  expect_true(is.list(entry$weight_stats$after))
  expect_true(is.list(entry$convergence))
  expect_true(is.logical(entry$convergence$converged))
  expect_true(is.integer(entry$convergence$iterations))
  expect_true(is.numeric(entry$convergence$max_error))
  expect_true(is.numeric(entry$convergence$tolerance))
  expect_identical(
    entry$package_version,
    as.character(utils::packageVersion("surveywts"))
  )
})

# ---------------------------------------------------------------------------
# 19. History — step number increments correctly across chained calls
# ---------------------------------------------------------------------------

test_that("calibrate() step numbers increment correctly across chained calls", {
  df <- make_surveywts_data(seed = 31)
  pop1 <- list(
    age_group = c("18-34" = 0.30, "35-54" = 0.40, "55+" = 0.30)
  )
  pop2 <- list(
    sex = c("M" = 0.48, "F" = 0.52)
  )

  wdf1 <- calibrate(df, variables = c(age_group), population = pop1)
  expect_identical(attr(wdf1, "weighting_history")[[1L]]$step, 1L)

  wdf2 <- calibrate(wdf1, variables = c(sex), population = pop2,
                    weights = .weight)
  expect_identical(attr(wdf2, "weighting_history")[[2L]]$step, 2L)
})

# ---------------------------------------------------------------------------
# 20. weighted_df auto-detects weights when weights = NULL
# ---------------------------------------------------------------------------

test_that("calibrate() auto-detects weights from weighted_df when weights is NULL", {
  # Covers .get_weight_vec() line 127: data_df[[attr(x, "weight_col")]]
  df <- make_surveywts_data(seed = 32)
  pop <- .make_pop()

  # First calibration produces a weighted_df
  wdf <- calibrate(df, variables = c(age_group, sex), population = pop)
  test_invariants(wdf)

  # Second calibration with NO explicit weights arg — auto-detects weight_col
  pop2 <- list(
    age_group = c("18-34" = 0.28, "35-54" = 0.42, "55+" = 0.30),
    sex = c("M" = 0.50, "F" = 0.50)
  )
  result <- calibrate(wdf, variables = c(age_group, sex), population = pop2)

  test_invariants(result)
  expect_true(inherits(result, "weighted_df"))
  expect_identical(length(attr(result, "weighting_history")), 2L)
})

# ---------------------------------------------------------------------------
# 21. Large count targets trigger scale normalization in GREG solver
# ---------------------------------------------------------------------------

test_that("calibrate() with method='logit', type='count', large counts triggers GREG scale normalization", {
  # Covers survey::grake() internal rescaling path:
  #   when min(scales) > 20 (scales = population / sample_total).
  # The scale normalization is internal to survey::calibrate() logit path.
  # With n=500, base_weight~1, sample_total~150 per group.
  # scales = 300000/150 = 2000 >> 20 → triggers scale normalization.
  df <- make_surveywts_data(seed = 34)

  pop_large <- list(
    age_group = c("18-34" = 300000L, "35-54" = 400000L, "55+" = 300000L)
  )

  result <- calibrate(
    df,
    variables = c(age_group),
    population = pop_large,
    type = "count",
    method = "logit"
  )

  test_invariants(result)
  expect_true(inherits(result, "weighted_df"))
})
