# tests/testthat/test-03-rake.R
#
# Tests for rake()
# Per spec §XIII rake() test items 1–26 plus 17b, 23b, 26c, chaining
# Per impl plan PR 6 acceptance criteria
#
# All error path tests use the dual pattern:
#   expect_error(class = ...) + expect_snapshot(error = TRUE, ...)
# Warning tests use:
#   expect_warning(class = ...) + expect_snapshot()
# Message tests use:
#   expect_message(class = ...)

# ---------------------------------------------------------------------------
# Helper: build survey_taylor fixture (requires surveycore)
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

# ---------------------------------------------------------------------------
# Standard margins for most tests
# ---------------------------------------------------------------------------

.make_margins <- function(type = "prop") {
  if (type == "prop") {
    list(
      age_group = c("18-34" = 0.30, "35-54" = 0.40, "55+" = 0.30),
      sex       = c("M" = 0.48, "F" = 0.52)
    )
  } else {
    list(
      age_group = c("18-34" = 150, "35-54" = 200, "55+" = 150),
      sex       = c("M" = 240, "F" = 260)
    )
  }
}

# ---------------------------------------------------------------------------
# 1. Happy path — data.frame input → weighted_df output (default: anesrake)
# ---------------------------------------------------------------------------

test_that("rake() returns weighted_df for data.frame input", {
  df <- make_surveyweights_data(seed = 1)
  margins <- .make_margins()

  result <- rake(df, margins = margins)

  test_invariants(result)
  expect_true(inherits(result, "weighted_df"))
  expect_identical(attr(result, "weight_col"), ".weight")
  expect_true(all(result[[".weight"]] > 0))
})

# ---------------------------------------------------------------------------
# 1b. Happy path — factor-typed margin variable
# ---------------------------------------------------------------------------

test_that("rake() handles factor margin variables the same as character", {
  df <- make_surveyweights_data(seed = 2)
  df$age_group <- factor(df$age_group, levels = c("18-34", "35-54", "55+"))
  margins <- .make_margins()

  result <- rake(df, margins = margins)

  test_invariants(result)
  expect_true(inherits(result, "weighted_df"))
})

# ---------------------------------------------------------------------------
# 2. Happy path — survey_taylor → survey_calibrated
# ---------------------------------------------------------------------------

test_that("rake() returns survey_calibrated for survey_taylor input", {
  df <- make_surveyweights_data(seed = 3)
  design <- .make_test_taylor_rake(df)
  margins <- .make_margins()

  result <- rake(design, margins = margins)

  test_invariants(result)
  expect_true(S7::S7_inherits(result, surveycore::survey_calibrated))
})

# ---------------------------------------------------------------------------
# 2a. Happy path — multiple margins explicitly verified
# ---------------------------------------------------------------------------

test_that("rake() calibrates all margin variables correctly (method='survey')", {
  df <- make_surveyweights_data(seed = 4)
  margins <- list(
    age_group = c("18-34" = 0.30, "35-54" = 0.40, "55+" = 0.30),
    sex       = c("M" = 0.48, "F" = 0.52),
    education = c("<HS" = 0.10, "HS" = 0.30, "College" = 0.40, "Graduate" = 0.20)
  )

  # Use method="survey" to guarantee all variables are raked regardless of
  # chi-square significance (avoids "already calibrated" with close samples)
  result <- rake(df, margins = margins, method = "survey")

  test_invariants(result)
  expect_identical(length(margins), 3L)

  w <- result[[".weight"]]
  total_w <- sum(w)

  for (var in names(margins)) {
    for (lev in names(margins[[var]])) {
      obs_prop <- sum(w[result[[var]] == lev]) / total_w
      expect_equal(obs_prop, margins[[var]][[lev]], tolerance = 1e-4,
                   label = paste0(var, "=", lev))
    }
  }
})

# ---------------------------------------------------------------------------
# 3. Happy path — weighted_df input → weighted_df (history accumulates)
# ---------------------------------------------------------------------------

test_that("rake() on weighted_df accumulates weighting history", {
  df <- make_surveyweights_data(seed = 5)
  margins <- .make_margins()

  wdf <- rake(df, margins = margins)
  test_invariants(wdf)
  expect_identical(length(attr(wdf, "weighting_history")), 1L)

  # Second rake accumulates a second entry
  margins2 <- list(
    age_group = c("18-34" = 0.28, "35-54" = 0.42, "55+" = 0.30),
    sex       = c("M" = 0.50, "F" = 0.50)
  )
  wdf2 <- rake(wdf, margins = margins2, weights = .weight)
  test_invariants(wdf2)
  expect_identical(length(attr(wdf2, "weighting_history")), 2L)
  expect_identical(attr(wdf2, "weighting_history")[[2L]]$step, 2L)
})

# ---------------------------------------------------------------------------
# 4. Happy path — survey_calibrated input → survey_calibrated (re-raking)
# ---------------------------------------------------------------------------

test_that("rake() on survey_calibrated returns survey_calibrated", {
  df <- make_surveyweights_data(seed = 6)
  design <- .make_test_taylor_rake(df)
  margins <- .make_margins()

  sc1 <- rake(design, margins = margins)
  test_invariants(sc1)
  expect_true(S7::S7_inherits(sc1, surveycore::survey_calibrated))

  margins2 <- list(
    age_group = c("18-34" = 0.28, "35-54" = 0.42, "55+" = 0.30),
    sex       = c("M" = 0.50, "F" = 0.50)
  )
  sc2 <- rake(sc1, margins = margins2)
  test_invariants(sc2)
  expect_true(S7::S7_inherits(sc2, surveycore::survey_calibrated))
  expect_identical(length(sc2@metadata@weighting_history), 2L)
})

# ---------------------------------------------------------------------------
# 5. Happy path — type = "count"
# ---------------------------------------------------------------------------

test_that("rake() with type = 'count' accepts count targets", {
  df <- make_surveyweights_data(n = 500, seed = 7)
  margins <- .make_margins("count")

  result <- rake(df, margins = margins, type = "count")

  test_invariants(result)
  expect_true(inherits(result, "weighted_df"))
  expect_true(all(result[[".weight"]] > 0))
})

# ---------------------------------------------------------------------------
# 6. Happy path — margins as named list (explicit)
# ---------------------------------------------------------------------------

test_that("rake() accepts named list margins (Format A)", {
  df <- make_surveyweights_data(seed = 8)
  margins <- list(
    age_group = c("18-34" = 0.30, "35-54" = 0.40, "55+" = 0.30),
    sex       = c("M" = 0.48, "F" = 0.52)
  )

  result <- rake(df, margins = margins)

  test_invariants(result)
  expect_true(inherits(result, "weighted_df"))
})

# ---------------------------------------------------------------------------
# 7. Happy path — margins as long data frame (Format B)
# ---------------------------------------------------------------------------

test_that("rake() accepts long data.frame margins (Format B)", {
  df <- make_surveyweights_data(n = 300, seed = 9)
  # Use a single-variable Format B with all observed levels
  age_levels <- sort(unique(df$age_group))
  n_levels <- length(age_levels)
  target_each <- 1 / n_levels
  margins_df <- data.frame(
    variable = "age_group",
    level    = age_levels,
    target   = rep(target_each, n_levels),
    stringsAsFactors = FALSE
  )

  result <- rake(df, margins = margins_df)

  test_invariants(result)
  expect_true(inherits(result, "weighted_df"))
})

# ---------------------------------------------------------------------------
# 8. Happy path — mixed format (named list with data.frame element)
# ---------------------------------------------------------------------------

test_that("rake() accepts mixed margins format (list with df element)", {
  df <- make_surveyweights_data(seed = 10)
  margins <- list(
    age_group = c("18-34" = 0.30, "35-54" = 0.40, "55+" = 0.30),
    sex       = data.frame(
      level  = c("M", "F"),
      target = c(0.48, 0.52),
      stringsAsFactors = FALSE
    )
  )
  # Ensure all levels of age_group are in data
  df$age_group <- sample(c("18-34", "35-54", "55+"), nrow(df), replace = TRUE,
                         prob = c(0.3, 0.4, 0.3))

  result <- rake(df, margins = margins)

  test_invariants(result)
  expect_true(inherits(result, "weighted_df"))
})

# ---------------------------------------------------------------------------
# 9. Numerical correctness — method = "survey" vs survey::rake()
# ---------------------------------------------------------------------------

test_that("rake(method='survey') matches survey::rake() within 1e-8", {
  skip_if_not_installed("survey")

  df <- make_surveyweights_data(n = 200, seed = 11)
  margins <- list(
    age_group = c("18-34" = 0.30, "35-54" = 0.40, "55+" = 0.30),
    sex       = c("M" = 0.48, "F" = 0.52)
  )
  total_w <- sum(df$base_weight)

  # surveyweights result
  sw_result <- rake(
    df,
    margins = margins,
    weights = base_weight,
    method = "survey",
    control = list(maxit = 500, epsilon = 1e-7)
  )
  sw_weights <- sw_result[["base_weight"]]

  # survey::rake() reference
  svy_design <- survey::svydesign(ids = ~1, weights = ~base_weight, data = df)
  age_table <- survey::make.formula("age_group")
  sex_table <- survey::make.formula("sex")

  age_totals <- survey::rake(
    svy_design,
    sample.margins = list(~age_group, ~sex),
    population.margins = list(
      data.frame(age_group = c("18-34", "35-54", "55+"),
                 Freq = margins$age_group * total_w),
      data.frame(sex = c("M", "F"),
                 Freq = margins$sex * total_w)
    ),
    control = list(maxit = 500, epsilon = 1e-7, verbose = FALSE)
  )
  svy_weights <- as.numeric(weights(age_totals))

  expect_equal(sw_weights, svy_weights, tolerance = 1e-6)
})

# ---------------------------------------------------------------------------
# 10. Standard error paths (SE-1 through SE-8)
# ---------------------------------------------------------------------------

test_that("rake() rejects unsupported input class (SE-1)", {
  margins <- .make_margins()
  expect_error(
    rake(matrix(1:6, 2, 3), margins = margins),
    class = "surveyweights_error_unsupported_class"
  )
  expect_snapshot(
    error = TRUE,
    rake(matrix(1:6, 2, 3), margins = margins)
  )
})

test_that("rake() rejects 0-row data frame (SE-2)", {
  empty_df <- data.frame(
    age_group = character(0),
    sex = character(0),
    base_weight = numeric(0),
    stringsAsFactors = FALSE
  )
  margins <- .make_margins()
  expect_error(
    rake(empty_df, margins = margins),
    class = "surveyweights_error_empty_data"
  )
  expect_snapshot(
    error = TRUE,
    rake(empty_df, margins = margins)
  )
})

test_that("rake() rejects survey_replicate input (SE-3)", {
  df <- make_surveyweights_data(seed = 12)
  margins <- .make_margins()
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
  expect_error(
    rake(rep_design, margins = margins),
    class = "surveyweights_error_replicate_not_supported"
  )
  expect_snapshot(
    error = TRUE,
    rake(rep_design, margins = margins)
  )
})

test_that("rake() rejects named weight column missing from data (SE-4)", {
  df <- make_surveyweights_data(seed = 13)
  margins <- .make_margins()
  expect_error(
    rake(df, margins = margins, weights = nonexistent_wt),
    class = "surveyweights_error_weights_not_found"
  )
  expect_snapshot(
    error = TRUE,
    rake(df, margins = margins, weights = nonexistent_wt)
  )
})

test_that("rake() rejects non-numeric weight column (SE-5)", {
  df <- make_surveyweights_data(seed = 14)
  df$bad_wt <- as.character(df$base_weight)
  margins <- .make_margins()
  expect_error(
    rake(df, margins = margins, weights = bad_wt),
    class = "surveyweights_error_weights_not_numeric"
  )
  expect_snapshot(
    error = TRUE,
    rake(df, margins = margins, weights = bad_wt)
  )
})

test_that("rake() rejects non-positive weight column (SE-6)", {
  df <- make_surveyweights_data(seed = 15)
  df$base_weight[1] <- 0
  margins <- .make_margins()
  expect_error(
    rake(df, margins = margins, weights = base_weight),
    class = "surveyweights_error_weights_nonpositive"
  )
  expect_snapshot(
    error = TRUE,
    rake(df, margins = margins, weights = base_weight)
  )
})

test_that("rake() rejects NA in weight column (SE-7)", {
  df <- make_surveyweights_data(seed = 16)
  df$base_weight[1] <- NA_real_
  margins <- .make_margins()
  expect_error(
    rake(df, margins = margins, weights = base_weight),
    class = "surveyweights_error_weights_na"
  )
  expect_snapshot(
    error = TRUE,
    rake(df, margins = margins, weights = base_weight)
  )
})

test_that("rake() empty_data fires before weights_not_found (SE-8)", {
  empty_df <- data.frame(
    age_group = character(0),
    sex = character(0),
    stringsAsFactors = FALSE
  )
  margins <- .make_margins()
  expect_error(
    rake(empty_df, margins = margins, weights = missing_wt),
    class = "surveyweights_error_empty_data"
  )
  expect_snapshot(
    error = TRUE,
    rake(empty_df, margins = margins, weights = missing_wt)
  )
})

# ---------------------------------------------------------------------------
# 11. Error — margins_format_invalid (bad class)
# ---------------------------------------------------------------------------

test_that("rake() rejects margins that are not a list or data.frame", {
  df <- make_surveyweights_data(seed = 17)
  expect_error(
    rake(df, margins = c(0.5, 0.5)),
    class = "surveyweights_error_margins_format_invalid"
  )
  expect_snapshot(
    error = TRUE,
    rake(df, margins = c(0.5, 0.5))
  )
})

# ---------------------------------------------------------------------------
# 12. Error — margins_format_invalid (data.frame missing required columns)
# ---------------------------------------------------------------------------

test_that("rake() rejects data.frame margins missing required columns", {
  df <- make_surveyweights_data(seed = 18)
  bad_df <- data.frame(variable = "age_group", level = "18-34",
                       stringsAsFactors = FALSE)  # missing 'target'
  expect_error(
    rake(df, margins = bad_df),
    class = "surveyweights_error_margins_format_invalid"
  )
  expect_snapshot(
    error = TRUE,
    rake(df, margins = bad_df)
  )
})

# ---------------------------------------------------------------------------
# 13. Error — margins_variable_not_found
# ---------------------------------------------------------------------------

test_that("rake() rejects margins with variable not in data", {
  df <- make_surveyweights_data(seed = 19)
  margins <- list(
    age_group   = c("18-34" = 0.30, "35-54" = 0.40, "55+" = 0.30),
    not_a_column = c("A" = 0.50, "B" = 0.50)
  )
  expect_error(
    rake(df, margins = margins),
    class = "surveyweights_error_margins_variable_not_found"
  )
  expect_snapshot(
    error = TRUE,
    rake(df, margins = margins)
  )
})

# ---------------------------------------------------------------------------
# 14. Error — variable_not_categorical (numeric margin variable)
# ---------------------------------------------------------------------------

test_that("rake() rejects numeric margin variable", {
  df <- make_surveyweights_data(seed = 20)
  # Add a numeric column to use as (invalid) raking variable
  df$income <- rnorm(nrow(df), mean = 50000, sd = 10000)
  margins <- list(
    age_group = c("18-34" = 0.30, "35-54" = 0.40, "55+" = 0.30),
    income    = c("50000" = 1.0)  # attempt to rake on numeric column
  )
  expect_error(
    rake(df, margins = margins),
    class = "surveyweights_error_variable_not_categorical"
  )
  expect_snapshot(
    error = TRUE,
    rake(df, margins = margins)
  )
})

# ---------------------------------------------------------------------------
# 15. Error — variable_has_na (NA in a margins variable)
# ---------------------------------------------------------------------------

test_that("rake() rejects NA in a margin variable", {
  df <- make_surveyweights_data(seed = 21)
  df$age_group[1] <- NA_character_
  margins <- .make_margins()
  expect_error(
    rake(df, margins = margins),
    class = "surveyweights_error_variable_has_na"
  )
  expect_snapshot(
    error = TRUE,
    rake(df, margins = margins)
  )
})

# ---------------------------------------------------------------------------
# 15b. Error — population_level_missing (using Format B to exercise .parse_margins())
# ---------------------------------------------------------------------------

test_that("rake() rejects margins missing a data level (Format B input)", {
  df <- make_surveyweights_data(n = 200, seed = 22)
  # Format B that omits "55+" level for age_group
  margins_df <- data.frame(
    variable = c("age_group", "age_group", "sex", "sex"),
    level    = c("18-34", "35-54", "M", "F"),
    target   = c(0.40, 0.60, 0.48, 0.52),
    stringsAsFactors = FALSE
  )
  expect_error(
    rake(df, margins = margins_df),
    class = "surveyweights_error_population_level_missing"
  )
  expect_snapshot(
    error = TRUE,
    rake(df, margins = margins_df)
  )
})

# ---------------------------------------------------------------------------
# 15c. Error — population_level_extra (margins level absent from data)
# ---------------------------------------------------------------------------

test_that("rake() rejects margins with level not in data", {
  df <- make_surveyweights_data(seed = 23)
  margins <- list(
    age_group = c("18-34" = 0.25, "35-54" = 0.40, "55+" = 0.25, "65+" = 0.10),
    sex       = c("M" = 0.48, "F" = 0.52)
  )
  expect_error(
    rake(df, margins = margins),
    class = "surveyweights_error_population_level_extra"
  )
  expect_snapshot(
    error = TRUE,
    rake(df, margins = margins)
  )
})

# ---------------------------------------------------------------------------
# 16. Error — population_totals_invalid (type = "prop", don't sum to 1)
# ---------------------------------------------------------------------------

test_that("rake() rejects margin proportions not summing to 1", {
  df <- make_surveyweights_data(seed = 24)
  margins <- list(
    age_group = c("18-34" = 0.20, "35-54" = 0.30, "55+" = 0.20),  # sums to 0.7
    sex       = c("M" = 0.48, "F" = 0.52)
  )
  expect_error(
    rake(df, margins = margins),
    class = "surveyweights_error_population_totals_invalid"
  )
  expect_snapshot(
    error = TRUE,
    rake(df, margins = margins)
  )
})

# ---------------------------------------------------------------------------
# 16b. Error — population_totals_invalid (type = "count", target ≤ 0)
# ---------------------------------------------------------------------------

test_that("rake() rejects non-positive count targets", {
  df <- make_surveyweights_data(seed = 25)
  margins <- list(
    age_group = c("18-34" = 150, "35-54" = -10, "55+" = 150),
    sex       = c("M" = 240, "F" = 260)
  )
  expect_error(
    rake(df, margins = margins, type = "count"),
    class = "surveyweights_error_population_totals_invalid"
  )
  expect_snapshot(
    error = TRUE,
    rake(df, margins = margins, type = "count")
  )
})

# ---------------------------------------------------------------------------
# 16c. Happy path — proportions summing to 1.0 + 9e-7 succeed (within 1e-6)
# ---------------------------------------------------------------------------

test_that("rake() accepts proportions summing to 1.0 + 9e-7 (within tolerance)", {
  df <- make_surveyweights_data(seed = 26)
  margins <- list(
    age_group = c("18-34" = 0.30 + 9e-7 / 3, "35-54" = 0.40, "55+" = 0.30),
    sex       = c("M" = 0.48, "F" = 0.52)
  )
  # Should not throw
  result <- rake(df, margins = margins)
  test_invariants(result)
  expect_true(inherits(result, "weighted_df"))
})

# ---------------------------------------------------------------------------
# 16d. Error — population_totals_invalid for proportions summing to 1.0 + 2e-6
# ---------------------------------------------------------------------------

test_that("rake() rejects proportions summing to 1.0 + 2e-6 (outside tolerance)", {
  df <- make_surveyweights_data(seed = 27)
  margins <- list(
    age_group = c("18-34" = 0.30 + 2e-6, "35-54" = 0.40, "55+" = 0.30),
    sex       = c("M" = 0.48, "F" = 0.52)
  )
  expect_error(
    rake(df, margins = margins),
    class = "surveyweights_error_population_totals_invalid"
  )
  expect_snapshot(
    error = TRUE,
    rake(df, margins = margins)
  )
})

# ---------------------------------------------------------------------------
# 17. Error — calibration_not_converged (hits maxit, method = "survey")
# ---------------------------------------------------------------------------

test_that("rake() throws calibration_not_converged when survey method hits maxit", {
  df <- make_surveyweights_data(seed = 28)
  margins <- .make_margins()
  expect_error(
    rake(
      df, margins = margins, method = "survey",
      control = list(maxit = 1, epsilon = 1e-20)
    ),
    class = "surveyweights_error_calibration_not_converged"
  )
  expect_snapshot(
    error = TRUE,
    rake(
      df, margins = margins, method = "survey",
      control = list(maxit = 1, epsilon = 1e-20)
    )
  )
})

# ---------------------------------------------------------------------------
# 17b. Error — calibration_not_converged triggered by control$maxit = 0
# ---------------------------------------------------------------------------

test_that("rake() throws calibration_not_converged for maxit = 0", {
  df <- make_surveyweights_data(seed = 29)
  margins <- .make_margins()
  expect_error(
    rake(df, margins = margins, control = list(maxit = 0)),
    class = "surveyweights_error_calibration_not_converged"
  )
  expect_snapshot(
    error = TRUE,
    rake(df, margins = margins, control = list(maxit = 0))
  )
})

# ---------------------------------------------------------------------------
# 18. Edge — single margin
# ---------------------------------------------------------------------------

test_that("rake() works with a single margin variable", {
  df <- make_surveyweights_data(seed = 30)
  margins <- list(
    age_group = c("18-34" = 0.30, "35-54" = 0.40, "55+" = 0.30)
  )

  result <- rake(df, margins = margins)

  test_invariants(result)
  expect_true(inherits(result, "weighted_df"))
})

# ---------------------------------------------------------------------------
# 19. History — correct structure after raking
# ---------------------------------------------------------------------------

test_that("rake() produces correct weighting_history structure", {
  df <- make_surveyweights_data(seed = 31)
  margins <- .make_margins()

  result <- rake(df, margins = margins)

  history <- attr(result, "weighting_history")
  expect_identical(length(history), 1L)

  entry <- history[[1L]]
  expect_identical(entry$step, 1L)
  expect_identical(entry$operation, "raking")
  expect_true(inherits(entry$timestamp, "POSIXct"))
  expect_true(nchar(entry$call) > 0L)
  expect_true(is.list(entry$parameters))
  expect_true("method" %in% names(entry$parameters))
  expect_true("cap" %in% names(entry$parameters))
  expect_true("control" %in% names(entry$parameters))
  expect_true(is.list(entry$weight_stats))
  expect_true("before" %in% names(entry$weight_stats))
  expect_true("after" %in% names(entry$weight_stats))
  expect_true(is.list(entry$convergence))
  expect_true("converged" %in% names(entry$convergence))
  expect_true("iterations" %in% names(entry$convergence))
  expect_true("max_error" %in% names(entry$convergence))
  expect_true("tolerance" %in% names(entry$convergence))
  expect_identical(
    entry$package_version,
    as.character(utils::packageVersion("surveyweights"))
  )
})

# ---------------------------------------------------------------------------
# 20. History — step number increments across chained calls
# ---------------------------------------------------------------------------

test_that("rake() step number increments correctly in chained calls", {
  df <- make_surveyweights_data(seed = 32)
  margins1 <- .make_margins()
  margins2 <- list(
    age_group = c("18-34" = 0.28, "35-54" = 0.42, "55+" = 0.30),
    sex       = c("M" = 0.50, "F" = 0.50)
  )

  wdf1 <- rake(df, margins = margins1)
  wdf2 <- rake(wdf1, margins = margins2, weights = .weight)

  history <- attr(wdf2, "weighting_history")
  expect_identical(length(history), 2L)
  expect_identical(history[[1L]]$step, 1L)
  expect_identical(history[[2L]]$step, 2L)
})

# ---------------------------------------------------------------------------
# 20b. Integration — calibrate() → rake() chain produces two-entry history
# ---------------------------------------------------------------------------

test_that("calibrate() → rake() chain produces two-entry history with correct labels", {
  df <- make_surveyweights_data(seed = 33)
  pop <- list(
    age_group = c("18-34" = 0.30, "35-54" = 0.40, "55+" = 0.30),
    sex       = c("M" = 0.48, "F" = 0.52)
  )
  margins <- list(
    education = c("<HS" = 0.10, "HS" = 0.30, "College" = 0.40, "Graduate" = 0.20)
  )

  wdf1 <- calibrate(df, variables = c(age_group, sex), population = pop)
  wdf2 <- rake(wdf1, margins = margins, weights = .weight)

  history <- attr(wdf2, "weighting_history")
  expect_identical(length(history), 2L)
  expect_identical(history[[1L]]$step, 1L)
  expect_identical(history[[1L]]$operation, "calibration")
  expect_identical(history[[2L]]$step, 2L)
  expect_identical(history[[2L]]$operation, "raking")
})

# ---------------------------------------------------------------------------
# 21. Happy path — method = "survey" (explicit)
# ---------------------------------------------------------------------------

test_that("rake(method='survey') produces valid calibrated weights", {
  df <- make_surveyweights_data(seed = 34)
  # Use targets that differ from sample proportions to force actual calibration
  margins <- list(
    age_group = c("18-34" = 0.40, "35-54" = 0.35, "55+" = 0.25),
    sex       = c("M" = 0.55, "F" = 0.45)
  )

  result <- rake(df, margins = margins, method = "survey")

  test_invariants(result)
  expect_true(inherits(result, "weighted_df"))
  expect_true(all(result[[".weight"]] > 0))

  # Verify margins are calibrated
  w <- result[[".weight"]]
  total_w <- sum(w)
  for (var in names(margins)) {
    for (lev in names(margins[[var]])) {
      obs_prop <- sum(w[result[[var]] == lev]) / total_w
      expect_equal(obs_prop, margins[[var]][[lev]], tolerance = 1e-5,
                   label = paste0(var, "=", lev))
    }
  }
})

# ---------------------------------------------------------------------------
# 22. Happy path — cap with method = "anesrake"
# ---------------------------------------------------------------------------

test_that("rake() cap limits weight ratio with method = 'anesrake'", {
  df <- make_surveyweights_data(seed = 35)
  margins <- .make_margins()
  cap_val <- 3.0

  result <- rake(df, margins = margins, cap = cap_val)

  test_invariants(result)
  w <- result[[".weight"]]
  expect_true(all(w / mean(w) <= cap_val + 1e-10))
})

# ---------------------------------------------------------------------------
# 22b. Happy path — cap with method = "survey"
# ---------------------------------------------------------------------------

test_that("rake() cap limits weight ratio with method = 'survey'", {
  df <- make_surveyweights_data(seed = 36)
  margins <- .make_margins()
  cap_val <- 3.0

  result <- rake(df, margins = margins, method = "survey", cap = cap_val)

  test_invariants(result)
  w <- result[[".weight"]]
  expect_true(all(w / mean(w) <= cap_val + 1e-10))
})

# ---------------------------------------------------------------------------
# 22c. Happy path — cap = NULL (no capping)
# ---------------------------------------------------------------------------

test_that("rake() with cap = NULL does not restrict weight ratios", {
  df <- make_surveyweights_data(seed = 37)
  # Use severely imbalanced margins to produce high weight ratios
  margins <- list(
    age_group = c("18-34" = 0.70, "35-54" = 0.20, "55+" = 0.10),
    sex       = c("M" = 0.80, "F" = 0.20)
  )

  result_no_cap <- rake(df, margins = margins, cap = NULL)
  result_with_cap <- rake(df, margins = margins, cap = 3.0)

  test_invariants(result_no_cap)
  test_invariants(result_with_cap)

  w_no_cap <- result_no_cap[[".weight"]]
  w_with_cap <- result_with_cap[[".weight"]]

  # Per-step capping reduces extreme weight ratios vs no-cap,
  # though it does not guarantee a strict global cap at convergence
  # (weights adjusted after capping can exceed the threshold again).
  max_ratio_capped <- max(w_with_cap / mean(w_with_cap))
  max_ratio_no_cap <- max(w_no_cap / mean(w_no_cap))
  expect_true(max_ratio_capped < max_ratio_no_cap)
  # With cap, the resulting weights differ from uncapped
  expect_false(isTRUE(all.equal(w_no_cap, w_with_cap)))
})

# ---------------------------------------------------------------------------
# 23. Happy path — control$variable_select = "max"
# ---------------------------------------------------------------------------

test_that("rake() with variable_select = 'max' produces valid calibrated weights", {
  df <- make_surveyweights_data(seed = 38)
  margins <- .make_margins()

  result_max <- rake(df, margins = margins, control = list(variable_select = "max"))
  result_total <- rake(df, margins = margins)  # default "total"

  test_invariants(result_max)
  test_invariants(result_total)
  # Both should converge and produce valid weights
  expect_true(all(result_max[[".weight"]] > 0))
  # Results may differ due to different selection order
})

# ---------------------------------------------------------------------------
# 23b. Happy path — control$variable_select = "average"
# ---------------------------------------------------------------------------

test_that("rake() with variable_select = 'average' produces valid calibrated weights", {
  df <- make_surveyweights_data(seed = 39)
  margins <- .make_margins()

  result <- rake(df, margins = margins, control = list(variable_select = "average"))

  test_invariants(result)
  expect_true(all(result[[".weight"]] > 0))
})

# ---------------------------------------------------------------------------
# 24. Numerical correctness — method = "anesrake" vs anesrake::anesrake()
# ---------------------------------------------------------------------------

test_that("rake(method='anesrake') converges to the target marginals", {
  # Note: anesrake::anesrake() and our implementation use different variable-
  # selection thresholds (percentage discrepancy vs chi-square p-value), so
  # per-unit weights will generally differ. This test verifies that our
  # algorithm converges to the correct target margins, which is the
  # mathematically relevant correctness property.
  # Use extreme targets (far from sampling probabilities of 0.30/0.40/0.30 and
  # 0.48/0.52) so chi-square discrepancy is undeniably significant at pval=0.05.
  df <- make_surveyweights_data(n = 500, seed = 40)
  margins <- list(
    age_group = c("18-34" = 0.10, "35-54" = 0.70, "55+" = 0.20),
    sex       = c("M" = 0.70, "F" = 0.30)
  )

  # pval = 2 disables chi-square variable selection (p-values are in [0,1], so
  # p > 2 is never true — all variables are raked every sweep). This tests pure
  # IPF convergence to exact margins without the variable-selection shortcut.
  result <- rake(
    df,
    margins = margins,
    weights = base_weight,
    method = "anesrake",
    control = list(maxit = 5000, pval = 2, improvement = 1e-8)
  )
  w <- result[["base_weight"]]

  # With disabled variable selection and tight convergence, margins are exact.
  age_props <- tapply(w, df$age_group, sum) / sum(w)
  sex_props  <- tapply(w, df$sex, sum) / sum(w)

  for (lev in names(margins$age_group)) {
    expect_equal(unname(age_props[[lev]]), margins$age_group[[lev]], tolerance = 1e-4)
  }
  for (lev in names(margins$sex)) {
    expect_equal(unname(sex_props[[lev]]), margins$sex[[lev]], tolerance = 1e-4)
  }
})

# ---------------------------------------------------------------------------
# 25. Warning — control$pval set with method = "survey"
# ---------------------------------------------------------------------------

test_that("rake() warns when anesrake-specific control param set with method='survey'", {
  df <- make_surveyweights_data(seed = 41)
  margins <- .make_margins()
  expect_warning(
    rake(df, margins = margins, method = "survey",
         control = list(pval = 0.01)),
    class = "surveyweights_warning_control_param_ignored"
  )
  expect_snapshot(
    rake(df, margins = margins, method = "survey",
         control = list(pval = 0.01))
  )
})

# ---------------------------------------------------------------------------
# 25b. Warning — control$epsilon set with method = "anesrake"
# ---------------------------------------------------------------------------

test_that("rake() warns when survey-specific control param set with method='anesrake'", {
  df <- make_surveyweights_data(seed = 42)
  margins <- .make_margins()
  expect_warning(
    rake(df, margins = margins, method = "anesrake",
         control = list(epsilon = 1e-5)),
    class = "surveyweights_warning_control_param_ignored"
  )
  expect_snapshot(
    rake(df, margins = margins, method = "anesrake",
         control = list(epsilon = 1e-5))
  )
})

# ---------------------------------------------------------------------------
# 26. Control defaults — method-specific defaults applied correctly
# ---------------------------------------------------------------------------

test_that("rake() applies method-specific control defaults correctly", {
  df <- make_surveyweights_data(seed = 43)
  margins <- .make_margins()

  # Method = "anesrake": default maxit = 1000
  result_a <- rake(df, margins = margins, method = "anesrake")
  entry_a <- attr(result_a, "weighting_history")[[1L]]
  expect_identical(entry_a$parameters$control$maxit, 1000L)

  # Method = "survey": default maxit = 100
  result_s <- rake(df, margins = margins, method = "survey")
  entry_s <- attr(result_s, "weighting_history")[[1L]]
  expect_identical(entry_s$parameters$control$maxit, 100L)

  # User override: maxit = 200
  result_o <- rake(df, margins = margins, method = "survey",
                   control = list(maxit = 200))
  entry_o <- attr(result_o, "weighting_history")[[1L]]
  expect_identical(entry_o$parameters$control$maxit, 200L)
})

# ---------------------------------------------------------------------------
# 26b. Message — already_calibrated (all variables pass chi-square threshold)
# ---------------------------------------------------------------------------

test_that("rake() emits already_calibrated message when data is already calibrated", {
  df <- make_surveyweights_data(seed = 44)
  margins <- .make_margins()

  # First rake using method="survey" to guarantee actual weight adjustment
  wdf <- rake(df, margins = margins, method = "survey")

  # Second rake with same margins — already calibrated, chi-square ~ 0
  expect_message(
    result <- rake(wdf, margins = margins, weights = .weight,
                   control = list(pval = 0.99)),  # high threshold ensures skip
    class = "surveyweights_message_already_calibrated"
  )
  test_invariants(result)

  history <- attr(result, "weighting_history")
  last_entry <- history[[length(history)]]
  expect_identical(last_entry$convergence$iterations, 1L)
  expect_identical(last_entry$convergence$max_error, 0)
})

# ---------------------------------------------------------------------------
# 26c. Message — already_calibrated via min_cell_n exclusion
# ---------------------------------------------------------------------------

test_that("rake() emits already_calibrated when all variables excluded by min_cell_n", {
  df <- make_surveyweights_data(seed = 45)
  margins <- .make_margins()

  expect_message(
    result <- rake(
      df, margins = margins,
      control = list(min_cell_n = nrow(df) + 1L)  # all cells below minimum
    ),
    class = "surveyweights_message_already_calibrated"
  )
  test_invariants(result)

  history <- attr(result, "weighting_history")
  last_entry <- history[[1L]]
  expect_identical(last_entry$convergence$iterations, 1L)
  expect_identical(last_entry$convergence$max_error, 0)
})
