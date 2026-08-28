# tests/testthat/test-04-poststratify.R
#
# Tests for poststratify()
# Per plans/test-spec-calibration-api.md §poststratify()
#
# All error path tests use the dual pattern:
#   expect_error(class = ...) + expect_snapshot(error = TRUE, ...)
# Every test_that block creating a survey_nonprob calls
# test_invariants(obj) first.

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

.make_test_taylor_ps <- function(df, weight_col = "base_weight") {
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

# Joint population for age_group x sex (6 cells)
# strata_names = c("age_group", "sex"); "target" column excluded
.make_targets_ps <- function(type = "count") {
  if (type == "count") {
    data.frame(
      age_group = c("18-34", "18-34", "35-54", "35-54", "55+", "55+"),
      sex = c("M", "F", "M", "F", "M", "F"),
      target = c(1440L, 1560L, 1920L, 2080L, 1680L, 1320L),
      stringsAsFactors = FALSE
    )
  } else {
    data.frame(
      age_group = c("18-34", "18-34", "35-54", "35-54", "55+", "55+"),
      sex = c("M", "F", "M", "F", "M", "F"),
      target = c(0.144, 0.156, 0.192, 0.208, 0.168, 0.132),
      stringsAsFactors = FALSE
    )
  }
}

.make_test_replicate_ps <- function(df) {
  meta <- surveycore::survey_metadata()
  surveycore::survey_replicate(
    data = df,
    variables = list(
      ids = NULL,
      strata = NULL,
      fpc = NULL,
      weights = "base_weight",
      nest = FALSE,
      repweights = c("base_weight"),
      scale = 0.5,
      rscales = 1,
      type = "BRR",
      mse = TRUE
    ),
    metadata = meta,
    groups = character(0),
    call = NULL
  )
}

# ---------------------------------------------------------------------------
# 1. Error — surveywts_error_not_survey_base (data.frame input)
# ---------------------------------------------------------------------------

test_that("poststratify() aborts with cli error for data.frame input", {
  pop <- .make_targets_ps("count")
  expect_error(
    poststratify(make_surveywts_data(), targets = pop, type = "count"),
    class = "surveywts_error_not_survey_base"
  )
  expect_snapshot(
    error = TRUE,
    poststratify(make_surveywts_data(), targets = pop, type = "count")
  )
})

# ---------------------------------------------------------------------------
# 5. Happy path — survey_nonprob -> survey_nonprob
# ---------------------------------------------------------------------------

test_that("poststratify() accepts and returns survey_nonprob", {
  df <- make_surveywts_data(seed = 5)
  pop <- .make_targets_ps("count")

  sc_input <- surveycore::survey_nonprob(
    data = df,
    variables = list(
      ids = NULL,
      strata = NULL,
      fpc = NULL,
      weights = "base_weight",
      nest = FALSE
    ),
    metadata = surveycore::survey_metadata(),
    groups = character(0),
    call = NULL,
    calibration = NULL
  )

  result <- poststratify(sc_input, targets = pop, type = "count")

  test_invariants(result)
  expect_true(S7::S7_inherits(result, surveycore::survey_nonprob))
  expect_identical(length(result@metadata@weighting_history), 1L)
})

# ---------------------------------------------------------------------------
# 6. Happy path — survey_taylor -> survey_taylor (class preserved)
# ---------------------------------------------------------------------------

test_that("poststratify() preserves survey_taylor class for survey_taylor input", {
  df <- make_surveywts_data(seed = 4)
  design <- .make_test_taylor_ps(df)
  pop <- .make_targets_ps("count")

  result <- poststratify(design, targets = pop, type = "count")

  test_invariants(result)
  expect_true(S7::S7_inherits(result, surveycore::survey_taylor))
  expect_false(S7::S7_inherits(result, surveycore::survey_nonprob))
  expect_identical(result@variables$ids, design@variables$ids)
  expect_identical(result@variables$strata, design@variables$strata)
  expect_identical(result@variables$fpc, design@variables$fpc)
  expect_identical(result@variables$nest, design@variables$nest)
  expect_false(identical(
    result@data[[result@variables$weights]],
    design@data[[design@variables$weights]]
  ))
  expect_identical(length(result@metadata@weighting_history), 1L)
})

# ---------------------------------------------------------------------------
# 7. Happy path — reference_design non-NULL -> history has targets_from_reference
# ---------------------------------------------------------------------------

test_that("poststratify() sets targets_from_reference when reference_design given", {
  df <- make_surveywts_data(seed = 6)
  design <- .make_test_taylor_ps(df)
  pop <- .make_targets_ps("count")
  ref <- .make_test_taylor_ps(df)

  result <- poststratify(
    design,
    targets = pop,
    type = "count",
    reference_design = ref
  )
  history <- result@metadata@weighting_history

  expect_true(history[[1L]]$parameters$targets_from_reference)
})

# ---------------------------------------------------------------------------
# 8. Happy path — history operation = "poststratify"
# ---------------------------------------------------------------------------

test_that("poststratify() history operation is 'poststratify'", {
  df <- make_surveywts_data(seed = 42)
  design <- .make_test_taylor_ps(df)
  pop <- .make_targets_ps("count")

  result <- poststratify(design, targets = pop, type = "count")
  history <- result@metadata@weighting_history

  expect_identical(history[[1L]]$operation, "poststratify")
})

# ---------------------------------------------------------------------------
# 9. Happy path — strata_names derived from targets column names (not "target")
# ---------------------------------------------------------------------------

test_that("poststratify() derives strata_names from targets columns", {
  df <- make_surveywts_data(seed = 7)
  design <- .make_test_taylor_ps(df)
  pop <- .make_targets_ps("count")

  result <- poststratify(design, targets = pop, type = "count")
  history <- result@metadata@weighting_history

  expect_identical(
    sort(history[[1L]]$parameters$variables),
    sort(c("age_group", "sex"))
  )
})

# ---------------------------------------------------------------------------
# 10. Numerical oracle — matches survey::postStratify() within 1e-8
# ---------------------------------------------------------------------------

test_that("poststratify() matches survey::postStratify() within 1e-8", {
  skip_if_not_installed("survey")

  df <- make_surveywts_data(n = 300L, seed = 10)
  design <- .make_test_taylor_ps(df)
  pop <- .make_targets_ps("count")

  result <- poststratify(design, targets = pop, type = "count")
  sw_weights <- result@data[[result@variables$weights]]

  svy_design <- survey::svydesign(ids = ~1, weights = ~base_weight, data = df)
  pop_strata <- data.frame(
    age_group = c("18-34", "18-34", "35-54", "35-54", "55+", "55+"),
    sex = c("M", "F", "M", "F", "M", "F"),
    Freq = c(1440, 1560, 1920, 2080, 1680, 1320),
    stringsAsFactors = FALSE
  )
  svy_result <- survey::postStratify(
    svy_design,
    ~ age_group + sex,
    pop_strata,
    partial = FALSE
  )
  ref_weights <- as.numeric(weights(svy_result))

  expect_equal(sw_weights, ref_weights, tolerance = 1e-8)
})

# ---------------------------------------------------------------------------
# 11. Error — surveywts_error_unsupported_class (SE-1)
# ---------------------------------------------------------------------------

test_that("poststratify() rejects unsupported input class (SE-1)", {
  pop <- .make_targets_ps()
  expect_error(
    poststratify(list(x = 1), targets = pop, type = "count"),
    class = "surveywts_error_not_survey_base"
  )
  expect_snapshot(
    error = TRUE,
    poststratify(list(x = 1), targets = pop, type = "count")
  )
})

# ---------------------------------------------------------------------------
# 12. survey_replicate no longer rejected at class-check gate
#     (PR 1: survey_replicate branch removed from .check_input_class())
#     Full survey_replicate support for poststratify() lands in PR 2.
# ---------------------------------------------------------------------------

test_that("poststratify() no longer rejects survey_replicate at class-check gate", {
  df <- make_surveywts_data(seed = 11)
  rep_obj <- .make_test_replicate_ps(df)

  # .check_input_class() no longer throws surveywts_error_replicate_not_supported
  # for survey_replicate objects (PR 1 change).
  expect_no_error(.check_input_class(rep_obj))
})

# ---------------------------------------------------------------------------
# 13. Error — surveywts_error_empty_data (SE-3)
# ---------------------------------------------------------------------------

test_that("poststratify() rejects 0-row survey_taylor (SE-3)", {
  df0 <- make_surveywts_data(seed = 1)[0, ]
  design0 <- .make_test_taylor_ps(df0)
  pop <- .make_targets_ps()
  expect_error(
    poststratify(design0, targets = pop, type = "count"),
    class = "surveywts_error_empty_data"
  )
  expect_snapshot(
    error = TRUE,
    poststratify(design0, targets = pop, type = "count")
  )
})

# ---------------------------------------------------------------------------
# SE-4 through SE-7 removed — weights_not_found, weights_not_numeric,
# weights_nonpositive, weights_na are not reachable after the refactor:
# - S7 enforces positive, non-NA, numeric weights at construction time (SE-6, SE-7)
# - the weights= arg is removed from calibration functions (SE-4, SE-5)

# ---------------------------------------------------------------------------
# 18. Error — surveywts_error_wt_name_not_scalar
# ---------------------------------------------------------------------------

test_that("poststratify() rejects non-character wt_name", {
  df <- make_surveywts_data(seed = 1)
  design <- .make_test_taylor_ps(df)
  pop <- .make_targets_ps()
  expect_error(
    poststratify(design, targets = pop, type = "count", wt_name = 42),
    class = "surveywts_error_wt_name_not_scalar"
  )
  expect_snapshot(
    error = TRUE,
    poststratify(design, targets = pop, type = "count", wt_name = 42)
  )
})

# ---------------------------------------------------------------------------
# 19. Error — surveywts_error_wt_name_empty
# ---------------------------------------------------------------------------

test_that("poststratify() rejects empty wt_name", {
  df <- make_surveywts_data(seed = 1)
  design <- .make_test_taylor_ps(df)
  pop <- .make_targets_ps()
  expect_error(
    poststratify(design, targets = pop, type = "count", wt_name = ""),
    class = "surveywts_error_wt_name_empty"
  )
  expect_snapshot(
    error = TRUE,
    poststratify(design, targets = pop, type = "count", wt_name = "")
  )
})

# ---------------------------------------------------------------------------
# 20. Error — surveywts_error_reference_design_not_taylor
# ---------------------------------------------------------------------------

test_that("poststratify() rejects non-taylor reference_design", {
  df <- make_surveywts_data(seed = 1)
  design <- .make_test_taylor_ps(df)
  pop <- .make_targets_ps()
  expect_error(
    poststratify(
      design,
      targets = pop,
      type = "count",
      reference_design = list(x = 1)
    ),
    class = "surveywts_error_reference_design_not_taylor"
  )
  expect_snapshot(
    error = TRUE,
    poststratify(
      design,
      targets = pop,
      type = "count",
      reference_design = list(x = 1)
    )
  )
})

# ---------------------------------------------------------------------------
# 21. Error — surveywts_error_margins_format_invalid (targets not data.frame)
# ---------------------------------------------------------------------------

test_that("poststratify() rejects targets that is not a data.frame", {
  df <- make_surveywts_data(seed = 1)
  design <- .make_test_taylor_ps(df)
  # Named list is not accepted; only data.frame
  bad_targets <- list(
    age_group = c("18-34" = 0.30, "35-54" = 0.40, "55+" = 0.30)
  )
  expect_error(
    poststratify(design, targets = bad_targets, type = "prop"),
    class = "surveywts_error_margins_format_invalid"
  )
  expect_snapshot(
    error = TRUE,
    poststratify(design, targets = bad_targets, type = "prop")
  )
})

# ---------------------------------------------------------------------------
# 22. Error — surveywts_error_no_strata_variables
# ---------------------------------------------------------------------------

test_that("poststratify() rejects targets with zero strata columns", {
  df <- make_surveywts_data(seed = 1)
  design <- .make_test_taylor_ps(df)
  targets_bad <- data.frame(target = 1.0, stringsAsFactors = FALSE)
  expect_error(
    poststratify(design, targets = targets_bad, type = "prop"),
    class = "surveywts_error_no_strata_variables"
  )
  expect_snapshot(
    error = TRUE,
    poststratify(design, targets = targets_bad, type = "prop")
  )
})

# ---------------------------------------------------------------------------
# 23. Error — surveywts_error_targets_variable_not_found
# ---------------------------------------------------------------------------

test_that("poststratify() rejects targets with column absent from data", {
  df <- make_surveywts_data(seed = 1)
  design <- .make_test_taylor_ps(df)
  targets_bad <- data.frame(
    no_such_col = c("A", "B"),
    target = c(0.5, 0.5),
    stringsAsFactors = FALSE
  )
  expect_error(
    poststratify(design, targets = targets_bad, type = "prop"),
    class = "surveywts_error_targets_variable_not_found"
  )
  expect_snapshot(
    error = TRUE,
    poststratify(design, targets = targets_bad, type = "prop")
  )
})

# ---------------------------------------------------------------------------
# 24. Error — surveywts_error_variable_has_na
# ---------------------------------------------------------------------------

test_that("poststratify() rejects NA in strata variable", {
  df <- make_surveywts_data(seed = 1)
  df$age_group[1L] <- NA_character_
  design <- .make_test_taylor_ps(df)
  pop <- .make_targets_ps("count")
  expect_error(
    poststratify(design, targets = pop, type = "count"),
    class = "surveywts_error_variable_has_na"
  )
  expect_snapshot(
    error = TRUE,
    poststratify(design, targets = pop, type = "count")
  )
})

# ---------------------------------------------------------------------------
# 25. Error — surveywts_error_population_totals_invalid (type = "prop")
# ---------------------------------------------------------------------------

test_that("poststratify() rejects prop targets that don't sum to 1", {
  df <- make_surveywts_data(seed = 1)
  design <- .make_test_taylor_ps(df)
  pop_bad <- data.frame(
    age_group = c("18-34", "18-34", "35-54", "35-54", "55+", "55+"),
    sex = c("M", "F", "M", "F", "M", "F"),
    target = c(0.14, 0.15, 0.19, 0.20, 0.17, 0.13), # sums to 0.98
    stringsAsFactors = FALSE
  )
  expect_error(
    poststratify(design, targets = pop_bad, type = "prop"),
    class = "surveywts_error_population_totals_invalid"
  )
  expect_snapshot(
    error = TRUE,
    poststratify(design, targets = pop_bad, type = "prop")
  )
})

# ---------------------------------------------------------------------------
# 26. Error — surveywts_error_population_totals_invalid (type = "count", target <= 0)
# ---------------------------------------------------------------------------

test_that("poststratify() rejects count targets that are non-positive", {
  df <- make_surveywts_data(seed = 1)
  design <- .make_test_taylor_ps(df)
  pop_bad <- data.frame(
    age_group = c("18-34", "18-34", "35-54", "35-54", "55+", "55+"),
    sex = c("M", "F", "M", "F", "M", "F"),
    target = c(1440, 1560, 0, 2080, 1680, 1320),
    stringsAsFactors = FALSE
  )
  expect_error(
    poststratify(design, targets = pop_bad, type = "count"),
    class = "surveywts_error_population_totals_invalid"
  )
  expect_snapshot(
    error = TRUE,
    poststratify(design, targets = pop_bad, type = "count")
  )
})

# ---------------------------------------------------------------------------
# 27. Error — surveywts_error_population_cell_duplicate
# ---------------------------------------------------------------------------

test_that("poststratify() rejects duplicate rows in targets", {
  df <- make_surveywts_data(seed = 1)
  design <- .make_test_taylor_ps(df)
  pop_dup <- data.frame(
    age_group = c("18-34", "18-34", "18-34", "35-54", "35-54", "55+", "55+"),
    sex = c("M", "F", "M", "F", "M", "M", "F"),
    target = c(1440, 1560, 1440, 2080, 1920, 1680, 1320),
    stringsAsFactors = FALSE
  )
  expect_error(
    poststratify(design, targets = pop_dup, type = "count"),
    class = "surveywts_error_population_cell_duplicate"
  )
  expect_snapshot(
    error = TRUE,
    poststratify(design, targets = pop_dup, type = "count")
  )
})

# ---------------------------------------------------------------------------
# 28. Error — surveywts_error_population_cell_missing (data cell absent from targets)
# ---------------------------------------------------------------------------

test_that("poststratify() rejects targets missing a data cell", {
  df <- make_surveywts_data(seed = 1)
  design <- .make_test_taylor_ps(df)
  pop_missing <- data.frame(
    age_group = c("18-34", "18-34", "35-54", "35-54", "55+"),
    sex = c("M", "F", "M", "F", "M"),
    target = c(1440, 1560, 1920, 2080, 3000),
    stringsAsFactors = FALSE
  )
  expect_error(
    poststratify(design, targets = pop_missing, type = "count"),
    class = "surveywts_error_population_cell_missing"
  )
  expect_snapshot(
    error = TRUE,
    poststratify(design, targets = pop_missing, type = "count")
  )
})

# ---------------------------------------------------------------------------
# 29. Error — surveywts_error_population_cell_missing (targets missing "target" col)
# ---------------------------------------------------------------------------

test_that("poststratify() rejects targets missing the 'target' column", {
  df <- make_surveywts_data(seed = 12)
  design <- .make_test_taylor_ps(df)

  pop_no_target <- data.frame(
    age_group = c("18-34", "35-54", "55+"),
    stringsAsFactors = FALSE
  )

  expect_error(
    poststratify(design, targets = pop_no_target, type = "count"),
    class = "surveywts_error_population_cell_missing"
  )
  expect_snapshot(
    error = TRUE,
    poststratify(design, targets = pop_no_target, type = "count")
  )
})

# ---------------------------------------------------------------------------
# 30. Error — surveywts_error_population_cell_not_in_data
# ---------------------------------------------------------------------------

test_that("poststratify() rejects targets cells absent from data", {
  df <- make_surveywts_data(seed = 1)
  design <- .make_test_taylor_ps(df)
  pop_extra <- data.frame(
    age_group = c("18-34", "18-34", "35-54", "35-54", "55+", "55+", "65+"),
    sex = c("M", "F", "M", "F", "M", "F", "M"),
    target = c(1440, 1560, 1920, 2080, 1680, 1320, 500),
    stringsAsFactors = FALSE
  )
  expect_error(
    poststratify(design, targets = pop_extra, type = "count"),
    class = "surveywts_error_population_cell_not_in_data"
  )
  expect_snapshot(
    error = TRUE,
    poststratify(design, targets = pop_extra, type = "count")
  )
})

# ---------------------------------------------------------------------------
# 31. Edge — 0-row data fires empty_data before weights_not_found
# ---------------------------------------------------------------------------

test_that("poststratify() empty_data fires before weights_not_found", {
  df0 <- make_surveywts_data(seed = 1)[0, ]
  design0 <- .make_test_taylor_ps(df0)
  pop <- .make_targets_ps()
  expect_error(
    poststratify(design0, targets = pop, weights = no_such_col, type = "count"),
    class = "surveywts_error_empty_data"
  )
})

# ---------------------------------------------------------------------------
# 32. Edge — 1-row data, 1-cell targets
# ---------------------------------------------------------------------------

test_that("poststratify() works with 1-row data and 1-cell targets", {
  df_1 <- data.frame(
    age_group = "18-34",
    base_weight = 1.0,
    stringsAsFactors = FALSE
  )
  design_1 <- .make_test_taylor_ps(df_1)
  targets_1 <- data.frame(
    age_group = "18-34",
    target = 1000.0,
    stringsAsFactors = FALSE
  )

  result <- poststratify(design_1, targets = targets_1, type = "count")

  test_invariants(result)
  expect_true(S7::S7_inherits(result, surveycore::survey_taylor))
})

# ---------------------------------------------------------------------------
# 33. Edge — single stratification variable
# ---------------------------------------------------------------------------

test_that("poststratify() works with a single strata variable", {
  df <- make_surveywts_data(seed = 7)
  design <- .make_test_taylor_ps(df)
  pop_single <- data.frame(
    age_group = c("18-34", "35-54", "55+"),
    target = c(3000, 4000, 3000),
    stringsAsFactors = FALSE
  )
  result <- poststratify(design, targets = pop_single, type = "count")

  test_invariants(result)
  expect_true(S7::S7_inherits(result, surveycore::survey_taylor))
})

# ---------------------------------------------------------------------------
# 34. Edge — targets with only "target" column triggers no_strata_variables
# ---------------------------------------------------------------------------

test_that("poststratify() rejects targets = data.frame(target = 1)", {
  df <- make_surveywts_data(seed = 1)
  design <- .make_test_taylor_ps(df)
  targets_bad <- data.frame(target = 1.0, stringsAsFactors = FALSE)
  expect_error(
    poststratify(design, targets = targets_bad, type = "prop"),
    class = "surveywts_error_no_strata_variables"
  )
})

# §35 removed — zero-weight rows cannot be constructed in an S7 survey_taylor
# (S7 validator enforces all weights > 0 at construction time).

# ---------------------------------------------------------------------------
# SX-2 removed — zero-weight rows cannot be constructed in an S7 survey_taylor
# (S7 validator enforces all weights > 0 at construction time).

# ---------------------------------------------------------------------------
# 36. History — correct structure after calibration
# ---------------------------------------------------------------------------

test_that("poststratify() history entry has correct structure", {
  df <- make_surveywts_data(seed = 9)
  design <- .make_test_taylor_ps(df)
  pop <- .make_targets_ps("count")

  result <- poststratify(design, targets = pop, type = "count")
  history <- result@metadata@weighting_history

  expect_length(history, 1L)
  entry <- history[[1L]]

  expect_identical(entry$step, 1L)
  expect_identical(entry$operation, "poststratify")
  expect_true(inherits(entry$timestamp, "POSIXct"))
  expect_true(all(nchar(entry$call) > 0L))
  expect_type(entry$parameters, "list")
  expect_type(entry$weight_stats, "list")
  expect_true(!is.null(entry$weight_stats$before))
  expect_true(!is.null(entry$weight_stats$after))
  expect_null(entry$convergence) # non-iterative
  expect_identical(
    entry$package_version,
    as.character(utils::packageVersion("surveywts"))
  )
})

# ---------------------------------------------------------------------------
# 37. History — step increments correctly in chained calls
# ---------------------------------------------------------------------------

test_that("poststratify() step increments correctly in chained calls", {
  df <- make_surveywts_data(seed = 11)
  design <- .make_test_taylor_ps(df)
  pop <- .make_targets_ps("count")

  targets_greg <- list(
    age_group = c("18-34" = 0.30, "35-54" = 0.40, "55+" = 0.30),
    sex = c("M" = 0.48, "F" = 0.52)
  )

  result1 <- calibrate_linear(design, targets = targets_greg)
  result2 <- poststratify(result1, targets = pop, type = "count")

  history <- result2@metadata@weighting_history
  expect_length(history, 2L)
  expect_identical(history[[1L]]$step, 1L)
  expect_identical(history[[2L]]$step, 2L)
  expect_identical(history[[1L]]$operation, "calibrate_linear")
  expect_identical(history[[2L]]$operation, "poststratify")
})

# ---------------------------------------------------------------------------
# 38. wt_name — default is "wts"
# ---------------------------------------------------------------------------

test_that("poststratify() with wt_name = NULL overwrites weight column in-place", {
  df <- make_surveywts_data(seed = 1)
  design <- .make_test_taylor_ps(df)
  pop <- .make_targets_ps("count")
  result <- poststratify(design, targets = pop, type = "count")
  test_invariants(result)
  expect_identical(result@variables$weights, design@variables$weights)
})

# ---------------------------------------------------------------------------
# 39. wt_name — custom wt_name is used
# ---------------------------------------------------------------------------

test_that("poststratify() uses custom wt_name for output column", {
  df <- make_surveywts_data(seed = 1)
  design <- .make_test_taylor_ps(df)
  pop <- .make_targets_ps("count")
  result <- poststratify(
    design,
    targets = pop,
    type = "count",
    wt_name = "ps_wt"
  )
  test_invariants(result)
  expect_identical(result@variables$weights, "ps_wt")
  expect_true("ps_wt" %in% names(result@data))
})

# §40 removed — old test documented that S7 objects ignored wt_name;
# after the refactor wt_name applies to all inputs including S7 objects.

# ---------------------------------------------------------------------------
# 41. wt_name — records wt_name in weighting history
# ---------------------------------------------------------------------------

test_that("poststratify() records wt_name in weighting history", {
  df <- make_surveywts_data(seed = 1)
  design <- .make_test_taylor_ps(df)
  pop <- .make_targets_ps("count")
  result <- poststratify(
    design,
    targets = pop,
    type = "count",
    wt_name = "ps_wt"
  )
  history <- result@metadata@weighting_history
  expect_identical(history[[length(history)]]$weight_col, "ps_wt")
})

# ===========================================================================
# survey_taylor input — @calibration slot (PT tests, PR 2)
# ===========================================================================

# ---------------------------------------------------------------------------
# PT-1. survey_taylor input -> survey_taylor output
# ---------------------------------------------------------------------------

test_that("poststratify() with survey_taylor returns survey_taylor", {
  df <- make_surveywts_data(seed = 601)
  design <- .make_test_taylor_ps(df)
  targets <- .make_targets_ps()

  result <- poststratify(design, targets = targets, type = "count")

  expect_true(S7::S7_inherits(result, surveycore::survey_taylor))
})

# ---------------------------------------------------------------------------
# PT-2. @calibration populated for survey_taylor
# ---------------------------------------------------------------------------

test_that("poststratify() with survey_taylor populates @calibration", {
  df <- make_surveywts_data(seed = 602)
  design <- .make_test_taylor_ps(df)
  targets <- .make_targets_ps()

  result <- poststratify(design, targets = targets, type = "count")

  expect_false(is.null(result@calibration))
  expect_true(is.list(result@calibration))
})

# ---------------------------------------------------------------------------
# PT-3. All 12 @calibration fields present
# ---------------------------------------------------------------------------

test_that("poststratify() @calibration has all 12 required fields", {
  df <- make_surveywts_data(seed = 603)
  design <- .make_test_taylor_ps(df)
  targets <- .make_targets_ps()

  result <- poststratify(design, targets = targets, type = "count")

  required_fields <- c(
    "x_matrix",
    "base_weights",
    "g_weights",
    "crossproduct_inv",
    "population_totals",
    "discrepancy",
    "lambda",
    "method",
    "cell_factors",
    "q_weights",
    "converged",
    "n_iterations"
  )
  expect_true(all(required_fields %in% names(result@calibration)))
})

# ---------------------------------------------------------------------------
# PT-4. method == "poststrat"
# ---------------------------------------------------------------------------

test_that("poststratify() @calibration$method == 'poststrat'", {
  df <- make_surveywts_data(seed = 604)
  design <- .make_test_taylor_ps(df)
  targets <- .make_targets_ps()

  result <- poststratify(design, targets = targets, type = "count")

  expect_identical(result@calibration$method, "poststrat")
})

# ---------------------------------------------------------------------------
# PT-5. lambda is NULL for poststrat
# ---------------------------------------------------------------------------

test_that("poststratify() @calibration$lambda is NULL", {
  df <- make_surveywts_data(seed = 605)
  design <- .make_test_taylor_ps(df)
  targets <- .make_targets_ps()

  result <- poststratify(design, targets = targets, type = "count")

  expect_null(result@calibration$lambda)
})

# ---------------------------------------------------------------------------
# PT-6. cell_factors is non-NULL named numeric vector
# ---------------------------------------------------------------------------

test_that("poststratify() @calibration$cell_factors is non-NULL named numeric", {
  df <- make_surveywts_data(seed = 606)
  design <- .make_test_taylor_ps(df)
  targets <- .make_targets_ps()

  result <- poststratify(design, targets = targets, type = "count")

  cf <- result@calibration$cell_factors
  expect_false(is.null(cf))
  expect_true(is.numeric(cf))
  expect_false(is.null(names(cf)))
  # Number of factors == number of cells in targets
  expect_identical(length(cf), nrow(targets))
})

# ---------------------------------------------------------------------------
# PT-7. x_matrix has C columns (one per cell)
# ---------------------------------------------------------------------------

test_that("poststratify() @calibration$x_matrix has C columns", {
  df <- make_surveywts_data(seed = 607)
  design <- .make_test_taylor_ps(df)
  targets <- .make_targets_ps()
  C <- nrow(targets) # 6 cells

  result <- poststratify(design, targets = targets, type = "count")

  expect_identical(ncol(result@calibration$x_matrix), C)
  expect_identical(nrow(result@calibration$x_matrix), nrow(df))
})

# ---------------------------------------------------------------------------
# PT-8. x_matrix is binary (0/1) indicator matrix
# ---------------------------------------------------------------------------

test_that("poststratify() @calibration$x_matrix is binary indicator", {
  df <- make_surveywts_data(seed = 608)
  design <- .make_test_taylor_ps(df)
  targets <- .make_targets_ps()

  result <- poststratify(design, targets = targets, type = "count")

  xm <- result@calibration$x_matrix
  expect_true(all(xm %in% c(0, 1)))
  # Each row sums to 1 (each unit belongs to exactly one cell)
  expect_equal(rowSums(xm), rep(1, nrow(df)), tolerance = 1e-10)
})

# ---------------------------------------------------------------------------
# PT-9. base_weights matches pre-calibration weights (1e-10)
# ---------------------------------------------------------------------------

test_that("poststratify() @calibration$base_weights matches pre-calibration (1e-10)", {
  df <- make_surveywts_data(seed = 609)
  design <- .make_test_taylor_ps(df)
  targets <- .make_targets_ps()
  pre_weights <- design@data[[design@variables$weights]]

  result <- poststratify(design, targets = targets, type = "count")

  expect_equal(result@calibration$base_weights, pre_weights, tolerance = 1e-10)
})

# ---------------------------------------------------------------------------
# PT-10. g_weights * base_weights == output_weights (1e-10)
# ---------------------------------------------------------------------------

test_that("poststratify() g_weights * base_weights == calibrated weights (1e-10)", {
  df <- make_surveywts_data(seed = 610)
  design <- .make_test_taylor_ps(df)
  targets <- .make_targets_ps()

  result <- poststratify(design, targets = targets, type = "count")
  cal <- result@calibration
  out_weights <- result@data[[result@variables$weights]]

  expect_equal(cal$g_weights * cal$base_weights, out_weights, tolerance = 1e-10)
})

# ---------------------------------------------------------------------------
# PT-11. converged == TRUE (post-stratification is exact)
# ---------------------------------------------------------------------------

test_that("poststratify() @calibration$converged is TRUE", {
  df <- make_surveywts_data(seed = 611)
  design <- .make_test_taylor_ps(df)
  targets <- .make_targets_ps()

  result <- poststratify(design, targets = targets, type = "count")

  expect_identical(result@calibration$converged, TRUE)
})

# ---------------------------------------------------------------------------
# PT-12. n_iterations == 1L (post-stratification is one-step)
# ---------------------------------------------------------------------------

test_that("poststratify() @calibration$n_iterations == 1L", {
  df <- make_surveywts_data(seed = 612)
  design <- .make_test_taylor_ps(df)
  targets <- .make_targets_ps()

  result <- poststratify(design, targets = targets, type = "count")

  expect_identical(result@calibration$n_iterations, 1L)
})

# ---------------------------------------------------------------------------
# PT-13. replicate_converged is NULL for survey_taylor
# ---------------------------------------------------------------------------

test_that("poststratify() @calibration$replicate_converged is NULL for survey_taylor", {
  df <- make_surveywts_data(seed = 613)
  design <- .make_test_taylor_ps(df)
  targets <- .make_targets_ps()

  result <- poststratify(design, targets = targets, type = "count")

  expect_null(result@calibration$replicate_converged)
})

# ---------------------------------------------------------------------------
# PT-14. History entry appended
# ---------------------------------------------------------------------------

test_that("poststratify() appends history entry to survey_taylor", {
  df <- make_surveywts_data(seed = 614)
  design <- .make_test_taylor_ps(df)
  targets <- .make_targets_ps()

  result <- poststratify(design, targets = targets, type = "count")

  expect_identical(length(result@metadata@weighting_history), 1L)
  expect_identical(
    result@metadata@weighting_history[[1L]]$operation,
    "poststratify"
  )
})

# ===========================================================================
# survey_replicate input — @calibration + replicate_converged (PR tests, PR 2)
# ===========================================================================

# ---------------------------------------------------------------------------
# PR-1. survey_replicate output class
# ---------------------------------------------------------------------------

test_that("poststratify() with survey_replicate returns survey_replicate", {
  df <- make_surveywts_data(seed = 621)
  targets <- .make_targets_ps()
  rep_design <- .make_replicate_design(df, seed = 621)

  result <- poststratify(rep_design, targets = targets, type = "count")

  expect_true(S7::S7_inherits(result, surveycore::survey_replicate))
})

# ---------------------------------------------------------------------------
# PR-2. @calibration populated for survey_replicate
# ---------------------------------------------------------------------------

test_that("poststratify() survey_replicate @calibration is non-NULL", {
  df <- make_surveywts_data(seed = 622)
  targets <- .make_targets_ps()
  rep_design <- .make_replicate_design(df, seed = 622)

  result <- poststratify(rep_design, targets = targets, type = "count")

  expect_false(is.null(result@calibration))
})

# ---------------------------------------------------------------------------
# PR-3. replicate_converged is named logical of length R
# ---------------------------------------------------------------------------

test_that("poststratify() replicate_converged is named logical length R", {
  df <- make_surveywts_data(seed = 623)
  targets <- .make_targets_ps()
  rep_design <- .make_replicate_design(df, seed = 623)
  R <- length(rep_design@variables$repweights)

  result <- poststratify(rep_design, targets = targets, type = "count")

  rc <- result@calibration$replicate_converged
  expect_true(is.logical(rc))
  expect_identical(length(rc), R)
  expect_identical(names(rc), rep_design@variables$repweights)
})

# ---------------------------------------------------------------------------
# PR-4. All entries TRUE when all replicates converge
# ---------------------------------------------------------------------------

test_that("poststratify() replicate_converged all TRUE when all converge", {
  df <- make_surveywts_data(seed = 624)
  targets <- .make_targets_ps()
  rep_design <- .make_replicate_design(df, seed = 624)

  result <- poststratify(rep_design, targets = targets, type = "count")

  expect_true(all(result@calibration$replicate_converged))
})

# ---------------------------------------------------------------------------
# PR-5. Full-sample weights calibrated
# ---------------------------------------------------------------------------

test_that("poststratify() full-sample weights calibrated in survey_replicate", {
  df <- make_surveywts_data(seed = 625)
  targets <- .make_targets_ps()
  rep_design <- .make_replicate_design(df, seed = 625)
  pre_weights <- rep_design@data[[rep_design@variables$weights]]

  result <- poststratify(rep_design, targets = targets, type = "count")

  out_weights <- result@data[[result@variables$weights]]
  expect_false(identical(out_weights, pre_weights))
})

# ---------------------------------------------------------------------------
# PR-6. method == "poststrat" for survey_replicate
# ---------------------------------------------------------------------------

test_that("poststratify() @calibration$method == 'poststrat' for replicate", {
  df <- make_surveywts_data(seed = 626)
  targets <- .make_targets_ps()
  rep_design <- .make_replicate_design(df, seed = 626)

  result <- poststratify(rep_design, targets = targets, type = "count")

  expect_identical(result@calibration$method, "poststrat")
})

# ---------------------------------------------------------------------------
# PR-7. 0 replicate columns -> replicate_converged length 0
# ---------------------------------------------------------------------------

test_that("poststratify() with 0 repweights gives replicate_converged length 0", {
  df <- make_surveywts_data(n = 50, seed = 627)
  targets <- .make_targets_ps()
  meta <- surveycore::survey_metadata()
  rep_empty <- surveycore::survey_replicate(
    data = df,
    variables = list(
      ids = NULL,
      strata = NULL,
      fpc = NULL,
      weights = "base_weight",
      nest = FALSE,
      repweights = character(0),
      scale = 1,
      rscales = numeric(0),
      type = "bootstrap",
      mse = TRUE
    ),
    metadata = meta,
    groups = character(0),
    call = NULL
  )

  result <- poststratify(rep_empty, targets = targets, type = "count")

  rc <- result@calibration$replicate_converged
  expect_true(is.logical(rc))
  expect_identical(length(rc), 0L)
})

# ---------------------------------------------------------------------------
# PR-8. cell_factors non-NULL for survey_replicate
# ---------------------------------------------------------------------------

test_that("poststratify() @calibration$cell_factors non-NULL for survey_replicate", {
  df <- make_surveywts_data(seed = 628)
  targets <- .make_targets_ps()
  rep_design <- .make_replicate_design(df, seed = 628)

  result <- poststratify(rep_design, targets = targets, type = "count")

  expect_false(is.null(result@calibration$cell_factors))
  expect_true(is.numeric(result@calibration$cell_factors))
})

# ---------------------------------------------------------------------------
# PR-9. REG: survey_replicate does NOT throw replicate_not_supported
# ---------------------------------------------------------------------------

test_that("poststratify() with survey_replicate does NOT throw replicate_not_supported", {
  df <- make_surveywts_data(seed = 629)
  targets <- .make_targets_ps()
  rep_design <- .make_replicate_design(df, seed = 629)

  expect_no_error(
    poststratify(rep_design, targets = targets, type = "count")
  )
})

# ---------------------------------------------------------------------------
# EC6. cell_factors == target_count / ht_estimate per cell (value assertion)
# ---------------------------------------------------------------------------

test_that("poststratify() @calibration$cell_factors equal target/ht_estimate per cell (1e-10)", {
  df <- make_surveywts_data(seed = 700)
  design <- .make_test_taylor_ps(df)
  targets <- .make_targets_ps("count") # count type for unambiguous ht estimate

  result <- poststratify(design, targets = targets, type = "count")

  cf <- result@calibration$cell_factors
  pre_wts <- design@data[[design@variables$weights]]

  for (i in seq_along(cf)) {
    cell_name <- names(cf)[[i]]
    # Reconstruct cell key: paste all non-target column values
    var_cols <- setdiff(names(targets), "target")
    cell_row <- targets[i, var_cols, drop = FALSE]
    cell_mask <- rep(TRUE, nrow(df))
    for (v in var_cols) {
      cell_mask <- cell_mask & (df[[v]] == cell_row[[v]])
    }
    ht_est <- sum(pre_wts[cell_mask])
    expected_cf <- targets$target[[i]] / ht_est
    expect_equal(cf[[i]], expected_cf, tolerance = 1e-10)
  }
})

# ---------------------------------------------------------------------------
# CX4. Four distinct operation strings across all calibration functions
# ---------------------------------------------------------------------------

test_that("CX4: calibrate_linear/logit/rake/poststratify produce four distinct operations", {
  df <- make_surveywts_data(seed = 710)
  design <- .make_test_taylor_ps(df)
  targets_marg <- list(
    age_group = c("18-34" = 0.30, "35-54" = 0.40, "55+" = 0.30),
    sex = c("M" = 0.48, "F" = 0.52)
  )
  pop <- .make_targets_ps("count")

  suppressWarnings({
    r1 <- calibrate_linear(design, targets = targets_marg)
    r2 <- calibrate_logit(design, targets = targets_marg)
    r3 <- calibrate_rake(design, targets = targets_marg)
    r4 <- poststratify(design, targets = pop, type = "count")
  })

  ops <- c(
    r1@metadata@weighting_history[[length(
      r1@metadata@weighting_history
    )]]$operation,
    r2@metadata@weighting_history[[length(
      r2@metadata@weighting_history
    )]]$operation,
    r3@metadata@weighting_history[[length(
      r3@metadata@weighting_history
    )]]$operation,
    r4@metadata@weighting_history[[length(
      r4@metadata@weighting_history
    )]]$operation
  )
  expect_length(unique(ops), 4L)
  expect_true(all(
    c(
      "calibrate_linear",
      "calibrate_logit",
      "calibrate_rake",
      "poststratify"
    ) %in%
      ops
  ))
})

# ---------------------------------------------------------------------------
# W2. Replicate calibration failure — surveywts_warning_replicate_calibration_failed
# ---------------------------------------------------------------------------

test_that("W2: poststratify() warns replicate_calibration_failed when replicate cell has zero weights", {
  df <- make_surveywts_data(seed = 730)
  targets <- .make_targets_ps("count")
  rep_design <- .make_replicate_design(df, seed = 730)

  # Zero out all "55+" weights in the first replicate column
  first_rep_col <- rep_design@variables$repweights[[1L]]
  rep_design@data[[first_rep_col]][df$age_group == "55+"] <- 0

  expect_warning(
    result <- poststratify(rep_design, targets = targets, type = "count"),
    class = "surveywts_warning_replicate_calibration_failed"
  )

  # Full-sample weights still positive
  out_wts <- result@data[[result@variables$weights]]
  expect_true(all(out_wts > 0))

  # First replicate marked as not converged
  expect_false(result@calibration$replicate_converged[[first_rep_col]])
})

# ---------------------------------------------------------------------------
# PR-type = "prop" in replicate loop (coverage for line 418)
# ---------------------------------------------------------------------------

test_that("poststratify() type='prop' works for survey_replicate", {
  df <- make_surveywts_data(seed = 740)
  pop_prop <- .make_targets_ps("prop")
  rep_design <- .make_replicate_design(df, seed = 740)

  result <- poststratify(rep_design, targets = pop_prop, type = "prop")

  test_invariants(result)
  expect_true(S7::S7_inherits(result, surveycore::survey_replicate))
  # Full-sample weights hit the proportional targets
  out_wts <- result@data[[result@variables$weights]]
  expect_true(all(out_wts > 0))
})
