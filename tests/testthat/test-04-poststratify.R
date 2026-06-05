# tests/testthat/test-04-poststratify.R
#
# Tests for calibrate_poststrat()
# Per plans/test-spec-calibration-api.md §calibrate_poststrat()
#
# All error path tests use the dual pattern:
#   expect_error(class = ...) + expect_snapshot(error = TRUE, ...)
# Every test_that block creating weighted_df or survey_nonprob calls
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
      sex       = c("M",     "F",     "M",     "F",     "M",   "F"),
      target    = c(1440L, 1560L, 1920L, 2080L, 1680L, 1320L),
      stringsAsFactors = FALSE
    )
  } else {
    data.frame(
      age_group = c("18-34", "18-34", "35-54", "35-54", "55+", "55+"),
      sex       = c("M",     "F",     "M",     "F",     "M",   "F"),
      target    = c(0.144, 0.156, 0.192, 0.208, 0.168, 0.132),
      stringsAsFactors = FALSE
    )
  }
}

.make_test_replicate_ps <- function(df) {
  meta <- surveycore::survey_metadata()
  surveycore::survey_replicate(
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
}

# ---------------------------------------------------------------------------
# 1. Happy path — data.frame, prop, single strata var
# ---------------------------------------------------------------------------

test_that("calibrate_poststrat() returns weighted_df for data.frame, prop, single strata", {
  df <- data.frame(
    age_group = c("18-34", "18-34", "35-54", "35-54", "55+", "55+"),
    stringsAsFactors = FALSE
  )
  targets <- data.frame(
    age_group = c("18-34", "35-54", "55+"),
    target    = c(0.30, 0.40, 0.30),
    stringsAsFactors = FALSE
  )

  result <- calibrate_poststrat(df, targets = targets, type = "prop")

  test_invariants(result)
  expect_true(inherits(result, "weighted_df"))
  expect_identical(attr(result, "weight_col"), "wts")
  expect_true(all(result[["wts"]] > 0))

  # Weighted proportions match targets within 1e-10
  wt <- result[["wts"]]
  for (lvl in c("18-34", "35-54", "55+")) {
    idx      <- result$age_group == lvl
    expected <- targets$target[targets$age_group == lvl]
    expect_equal(sum(wt[idx]) / sum(wt), expected, tolerance = 1e-10)
  }
})

# ---------------------------------------------------------------------------
# 2. Happy path — data.frame, prop, joint strata
# ---------------------------------------------------------------------------

test_that("calibrate_poststrat() returns weighted_df, prop, joint strata", {
  df  <- make_surveywts_data(seed = 1)
  pop <- .make_targets_ps("prop")

  result <- calibrate_poststrat(df, targets = pop, type = "prop")

  test_invariants(result)
  expect_true(inherits(result, "weighted_df"))
  expect_true(all(result[["wts"]] > 0))
})

# ---------------------------------------------------------------------------
# 3. Happy path — data.frame, type = "count"
# ---------------------------------------------------------------------------

test_that("calibrate_poststrat() returns weighted_df for data.frame input, type = 'count'", {
  df  <- make_surveywts_data(seed = 1)
  pop <- .make_targets_ps("count")

  result <- calibrate_poststrat(df, targets = pop, type = "count")

  test_invariants(result)
  expect_true(inherits(result, "weighted_df"))
  expect_identical(attr(result, "weight_col"), "wts")
  expect_true(all(result[["wts"]] > 0))
})

# ---------------------------------------------------------------------------
# 4. Happy path — weighted_df input (history accumulates)
# ---------------------------------------------------------------------------

test_that("calibrate_poststrat() returns weighted_df for weighted_df input", {
  df  <- make_surveywts_data(seed = 3)
  pop <- .make_targets_ps("count")

  wdf <- structure(
    tibble::as_tibble(df),
    class = c("weighted_df", "tbl_df", "tbl", "data.frame"),
    weight_col = "base_weight",
    weighting_history = list()
  )

  result <- calibrate_poststrat(wdf, targets = pop, weights = base_weight,
                                type = "count")

  test_invariants(result)
  expect_true(inherits(result, "weighted_df"))
  expect_length(attr(result, "weighting_history"), 1L)
})

# ---------------------------------------------------------------------------
# 5. Happy path — survey_nonprob -> survey_nonprob
# ---------------------------------------------------------------------------

test_that("calibrate_poststrat() accepts and returns survey_nonprob", {
  df  <- make_surveywts_data(seed = 5)
  pop <- .make_targets_ps("count")

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

  result <- calibrate_poststrat(sc_input, targets = pop, type = "count")

  test_invariants(result)
  expect_true(S7::S7_inherits(result, surveycore::survey_nonprob))
  expect_identical(length(result@metadata@weighting_history), 1L)
})

# ---------------------------------------------------------------------------
# 6. Happy path — survey_taylor -> survey_taylor (class preserved)
# ---------------------------------------------------------------------------

test_that("calibrate_poststrat() preserves survey_taylor class for survey_taylor input", {
  df     <- make_surveywts_data(seed = 4)
  design <- .make_test_taylor_ps(df)
  pop    <- .make_targets_ps("count")

  result <- calibrate_poststrat(design, targets = pop, type = "count")

  test_invariants(result)
  expect_true(S7::S7_inherits(result, surveycore::survey_taylor))
  expect_false(S7::S7_inherits(result, surveycore::survey_nonprob))
  expect_identical(result@variables$ids,    design@variables$ids)
  expect_identical(result@variables$strata, design@variables$strata)
  expect_identical(result@variables$fpc,    design@variables$fpc)
  expect_identical(result@variables$nest,   design@variables$nest)
  expect_false(identical(result@data[[result@variables$weights]],
                         design@data[[design@variables$weights]]))
  expect_identical(length(result@metadata@weighting_history), 1L)
})

# ---------------------------------------------------------------------------
# 7. Happy path — reference_design non-NULL -> history has targets_from_reference
# ---------------------------------------------------------------------------

test_that("calibrate_poststrat() sets targets_from_reference when reference_design given", {
  df  <- make_surveywts_data(seed = 6)
  pop <- .make_targets_ps("count")
  ref <- .make_test_taylor_ps(df)

  result  <- calibrate_poststrat(df, targets = pop, type = "count",
                                 reference_design = ref)
  history <- attr(result, "weighting_history")

  expect_true(history[[1L]]$parameters$targets_from_reference)
})

# ---------------------------------------------------------------------------
# 8. Happy path — history operation = "calibrate_poststrat"
# ---------------------------------------------------------------------------

test_that("calibrate_poststrat() history operation is 'calibrate_poststrat'", {
  df  <- make_surveywts_data(seed = 42)
  pop <- .make_targets_ps("count")

  result  <- calibrate_poststrat(df, targets = pop, type = "count")
  history <- attr(result, "weighting_history")

  expect_identical(history[[1L]]$operation, "calibrate_poststrat")
})

# ---------------------------------------------------------------------------
# 9. Happy path — strata_names derived from targets column names (not "target")
# ---------------------------------------------------------------------------

test_that("calibrate_poststrat() derives strata_names from targets columns", {
  df  <- make_surveywts_data(seed = 7)
  pop <- .make_targets_ps("count")

  result  <- calibrate_poststrat(df, targets = pop, type = "count")
  history <- attr(result, "weighting_history")

  expect_identical(sort(history[[1L]]$parameters$variables),
                   sort(c("age_group", "sex")))
})

# ---------------------------------------------------------------------------
# 10. Numerical oracle — matches survey::postStratify() within 1e-8
# ---------------------------------------------------------------------------

test_that("calibrate_poststrat() matches survey::postStratify() within 1e-8", {
  skip_if_not_installed("survey")

  df  <- make_surveywts_data(n = 300L, seed = 10)
  pop <- .make_targets_ps("count")

  result     <- calibrate_poststrat(df, targets = pop, weights = base_weight,
                                    type = "count")
  sw_weights <- result[["wts"]]

  svy_design <- survey::svydesign(ids = ~1, weights = ~base_weight, data = df)
  pop_strata <- data.frame(
    age_group = c("18-34", "18-34", "35-54", "35-54", "55+", "55+"),
    sex       = c("M",     "F",     "M",     "F",     "M",   "F"),
    Freq      = c(1440, 1560, 1920, 2080, 1680, 1320),
    stringsAsFactors = FALSE
  )
  svy_result  <- survey::postStratify(svy_design, ~age_group + sex,
                                      pop_strata, partial = FALSE)
  ref_weights <- as.numeric(weights(svy_result))

  expect_equal(sw_weights, ref_weights, tolerance = 1e-8)
})

# ---------------------------------------------------------------------------
# 11. Error — surveywts_error_unsupported_class (SE-1)
# ---------------------------------------------------------------------------

test_that("calibrate_poststrat() rejects unsupported input class (SE-1)", {
  pop <- .make_targets_ps()
  expect_error(
    calibrate_poststrat(list(x = 1), targets = pop, type = "count"),
    class = "surveywts_error_unsupported_class"
  )
  expect_snapshot(
    error = TRUE,
    calibrate_poststrat(list(x = 1), targets = pop, type = "count")
  )
})

# ---------------------------------------------------------------------------
# 12. survey_replicate no longer rejected at class-check gate
#     (PR 1: survey_replicate branch removed from .check_input_class())
#     Full survey_replicate support for calibrate_poststrat() lands in PR 2.
# ---------------------------------------------------------------------------

test_that(
  "calibrate_poststrat() no longer rejects survey_replicate at class-check gate",
  {
    df      <- make_surveywts_data(seed = 11)
    rep_obj <- .make_test_replicate_ps(df)

    # .check_input_class() no longer throws surveywts_error_replicate_not_supported
    # for survey_replicate objects (PR 1 change).
    expect_no_error(.check_input_class(rep_obj))
  }
)

# ---------------------------------------------------------------------------
# 13. Error — surveywts_error_empty_data (SE-3)
# ---------------------------------------------------------------------------

test_that("calibrate_poststrat() rejects 0-row data frame (SE-3)", {
  df0 <- make_surveywts_data(seed = 1)[0, ]
  pop <- .make_targets_ps()
  expect_error(
    calibrate_poststrat(df0, targets = pop, type = "count"),
    class = "surveywts_error_empty_data"
  )
  expect_snapshot(
    error = TRUE,
    calibrate_poststrat(df0, targets = pop, type = "count")
  )
})

# ---------------------------------------------------------------------------
# 14. Error — surveywts_error_weights_not_found (SE-4)
# ---------------------------------------------------------------------------

test_that("calibrate_poststrat() rejects missing named weight column (SE-4)", {
  df  <- make_surveywts_data(seed = 1)
  pop <- .make_targets_ps()
  expect_error(
    calibrate_poststrat(df, targets = pop, weights = no_such_col,
                        type = "count"),
    class = "surveywts_error_weights_not_found"
  )
  expect_snapshot(
    error = TRUE,
    calibrate_poststrat(df, targets = pop, weights = no_such_col,
                        type = "count")
  )
})

# ---------------------------------------------------------------------------
# 15. Error — surveywts_error_weights_not_numeric (SE-5)
# ---------------------------------------------------------------------------

test_that("calibrate_poststrat() rejects non-numeric weight column (SE-5)", {
  df        <- make_surveywts_data(seed = 1)
  df$bad_wt <- as.character(df$base_weight)
  pop       <- .make_targets_ps()
  expect_error(
    calibrate_poststrat(df, targets = pop, weights = bad_wt, type = "count"),
    class = "surveywts_error_weights_not_numeric"
  )
  expect_snapshot(
    error = TRUE,
    calibrate_poststrat(df, targets = pop, weights = bad_wt, type = "count")
  )
})

# ---------------------------------------------------------------------------
# 16. Error — surveywts_error_weights_nonpositive (SE-6)
# ---------------------------------------------------------------------------

test_that("calibrate_poststrat() rejects non-positive weight column (SE-6)", {
  df                <- make_surveywts_data(seed = 1)
  df$base_weight[1] <- 0
  pop               <- .make_targets_ps()
  expect_error(
    calibrate_poststrat(df, targets = pop, weights = base_weight,
                        type = "count"),
    class = "surveywts_error_weights_nonpositive"
  )
  expect_snapshot(
    error = TRUE,
    calibrate_poststrat(df, targets = pop, weights = base_weight,
                        type = "count")
  )
})

# ---------------------------------------------------------------------------
# 17. Error — surveywts_error_weights_na (SE-7)
# ---------------------------------------------------------------------------

test_that("calibrate_poststrat() rejects NA weight column (SE-7)", {
  df                <- make_surveywts_data(seed = 1)
  df$base_weight[1] <- NA_real_
  pop               <- .make_targets_ps()
  expect_error(
    calibrate_poststrat(df, targets = pop, weights = base_weight,
                        type = "count"),
    class = "surveywts_error_weights_na"
  )
  expect_snapshot(
    error = TRUE,
    calibrate_poststrat(df, targets = pop, weights = base_weight,
                        type = "count")
  )
})

# ---------------------------------------------------------------------------
# 18. Error — surveywts_error_wt_name_not_scalar
# ---------------------------------------------------------------------------

test_that("calibrate_poststrat() rejects non-character wt_name", {
  df  <- make_surveywts_data(seed = 1)
  pop <- .make_targets_ps()
  expect_error(
    calibrate_poststrat(df, targets = pop, type = "count", wt_name = 42),
    class = "surveywts_error_wt_name_not_scalar"
  )
  expect_snapshot(
    error = TRUE,
    calibrate_poststrat(df, targets = pop, type = "count", wt_name = 42)
  )
})

# ---------------------------------------------------------------------------
# 19. Error — surveywts_error_wt_name_empty
# ---------------------------------------------------------------------------

test_that("calibrate_poststrat() rejects empty wt_name", {
  df  <- make_surveywts_data(seed = 1)
  pop <- .make_targets_ps()
  expect_error(
    calibrate_poststrat(df, targets = pop, type = "count", wt_name = ""),
    class = "surveywts_error_wt_name_empty"
  )
  expect_snapshot(
    error = TRUE,
    calibrate_poststrat(df, targets = pop, type = "count", wt_name = "")
  )
})

# ---------------------------------------------------------------------------
# 20. Error — surveywts_error_reference_design_not_taylor
# ---------------------------------------------------------------------------

test_that("calibrate_poststrat() rejects non-taylor reference_design", {
  df  <- make_surveywts_data(seed = 1)
  pop <- .make_targets_ps()
  expect_error(
    calibrate_poststrat(df, targets = pop, type = "count",
                        reference_design = list(x = 1)),
    class = "surveywts_error_reference_design_not_taylor"
  )
  expect_snapshot(
    error = TRUE,
    calibrate_poststrat(df, targets = pop, type = "count",
                        reference_design = list(x = 1))
  )
})

# ---------------------------------------------------------------------------
# 21. Error — surveywts_error_margins_format_invalid (targets not data.frame)
# ---------------------------------------------------------------------------

test_that("calibrate_poststrat() rejects targets that is not a data.frame", {
  df <- make_surveywts_data(seed = 1)
  # Named list is not accepted; only data.frame
  bad_targets <- list(
    age_group = c("18-34" = 0.30, "35-54" = 0.40, "55+" = 0.30)
  )
  expect_error(
    calibrate_poststrat(df, targets = bad_targets, type = "prop"),
    class = "surveywts_error_margins_format_invalid"
  )
  expect_snapshot(
    error = TRUE,
    calibrate_poststrat(df, targets = bad_targets, type = "prop")
  )
})

# ---------------------------------------------------------------------------
# 22. Error — surveywts_error_no_strata_variables
# ---------------------------------------------------------------------------

test_that("calibrate_poststrat() rejects targets with zero strata columns", {
  df          <- make_surveywts_data(seed = 1)
  targets_bad <- data.frame(target = 1.0, stringsAsFactors = FALSE)
  expect_error(
    calibrate_poststrat(df, targets = targets_bad, type = "prop"),
    class = "surveywts_error_no_strata_variables"
  )
  expect_snapshot(
    error = TRUE,
    calibrate_poststrat(df, targets = targets_bad, type = "prop")
  )
})

# ---------------------------------------------------------------------------
# 23. Error — surveywts_error_targets_variable_not_found
# ---------------------------------------------------------------------------

test_that("calibrate_poststrat() rejects targets with column absent from data", {
  df <- make_surveywts_data(seed = 1)
  targets_bad <- data.frame(
    no_such_col = c("A", "B"),
    target      = c(0.5, 0.5),
    stringsAsFactors = FALSE
  )
  expect_error(
    calibrate_poststrat(df, targets = targets_bad, type = "prop"),
    class = "surveywts_error_targets_variable_not_found"
  )
  expect_snapshot(
    error = TRUE,
    calibrate_poststrat(df, targets = targets_bad, type = "prop")
  )
})

# ---------------------------------------------------------------------------
# 24. Error — surveywts_error_variable_has_na
# ---------------------------------------------------------------------------

test_that("calibrate_poststrat() rejects NA in strata variable", {
  df               <- make_surveywts_data(seed = 1)
  df$age_group[1L] <- NA_character_
  pop              <- .make_targets_ps("count")
  expect_error(
    calibrate_poststrat(df, targets = pop, type = "count"),
    class = "surveywts_error_variable_has_na"
  )
  expect_snapshot(
    error = TRUE,
    calibrate_poststrat(df, targets = pop, type = "count")
  )
})

# ---------------------------------------------------------------------------
# 25. Error — surveywts_error_population_totals_invalid (type = "prop")
# ---------------------------------------------------------------------------

test_that("calibrate_poststrat() rejects prop targets that don't sum to 1", {
  df      <- make_surveywts_data(seed = 1)
  pop_bad <- data.frame(
    age_group = c("18-34", "18-34", "35-54", "35-54", "55+", "55+"),
    sex       = c("M",     "F",     "M",     "F",     "M",   "F"),
    target    = c(0.14, 0.15, 0.19, 0.20, 0.17, 0.13),  # sums to 0.98
    stringsAsFactors = FALSE
  )
  expect_error(
    calibrate_poststrat(df, targets = pop_bad, type = "prop"),
    class = "surveywts_error_population_totals_invalid"
  )
  expect_snapshot(
    error = TRUE,
    calibrate_poststrat(df, targets = pop_bad, type = "prop")
  )
})

# ---------------------------------------------------------------------------
# 26. Error — surveywts_error_population_totals_invalid (type = "count", target <= 0)
# ---------------------------------------------------------------------------

test_that("calibrate_poststrat() rejects count targets that are non-positive", {
  df      <- make_surveywts_data(seed = 1)
  pop_bad <- data.frame(
    age_group = c("18-34", "18-34", "35-54", "35-54", "55+", "55+"),
    sex       = c("M",     "F",     "M",     "F",     "M",   "F"),
    target    = c(1440, 1560, 0, 2080, 1680, 1320),
    stringsAsFactors = FALSE
  )
  expect_error(
    calibrate_poststrat(df, targets = pop_bad, type = "count"),
    class = "surveywts_error_population_totals_invalid"
  )
  expect_snapshot(
    error = TRUE,
    calibrate_poststrat(df, targets = pop_bad, type = "count")
  )
})

# ---------------------------------------------------------------------------
# 27. Error — surveywts_error_population_cell_duplicate
# ---------------------------------------------------------------------------

test_that("calibrate_poststrat() rejects duplicate rows in targets", {
  df      <- make_surveywts_data(seed = 1)
  pop_dup <- data.frame(
    age_group = c("18-34", "18-34", "18-34", "35-54", "35-54", "55+", "55+"),
    sex       = c("M",     "F",     "M",     "F",     "M",     "M",   "F"),
    target    = c(1440, 1560, 1440, 2080, 1920, 1680, 1320),
    stringsAsFactors = FALSE
  )
  expect_error(
    calibrate_poststrat(df, targets = pop_dup, type = "count"),
    class = "surveywts_error_population_cell_duplicate"
  )
  expect_snapshot(
    error = TRUE,
    calibrate_poststrat(df, targets = pop_dup, type = "count")
  )
})

# ---------------------------------------------------------------------------
# 28. Error — surveywts_error_population_cell_missing (data cell absent from targets)
# ---------------------------------------------------------------------------

test_that("calibrate_poststrat() rejects targets missing a data cell", {
  df          <- make_surveywts_data(seed = 1)
  pop_missing <- data.frame(
    age_group = c("18-34", "18-34", "35-54", "35-54", "55+"),
    sex       = c("M",     "F",     "M",     "F",     "M"),
    target    = c(1440, 1560, 1920, 2080, 3000),
    stringsAsFactors = FALSE
  )
  expect_error(
    calibrate_poststrat(df, targets = pop_missing, type = "count"),
    class = "surveywts_error_population_cell_missing"
  )
  expect_snapshot(
    error = TRUE,
    calibrate_poststrat(df, targets = pop_missing, type = "count")
  )
})

# ---------------------------------------------------------------------------
# 29. Error — surveywts_error_population_cell_missing (targets missing "target" col)
# ---------------------------------------------------------------------------

test_that("calibrate_poststrat() rejects targets missing the 'target' column", {
  df <- make_surveywts_data(seed = 12)

  pop_no_target <- data.frame(
    age_group = c("18-34", "35-54", "55+"),
    stringsAsFactors = FALSE
  )

  expect_error(
    calibrate_poststrat(df, targets = pop_no_target, type = "count"),
    class = "surveywts_error_population_cell_missing"
  )
  expect_snapshot(
    error = TRUE,
    calibrate_poststrat(df, targets = pop_no_target, type = "count")
  )
})

# ---------------------------------------------------------------------------
# 30. Error — surveywts_error_population_cell_not_in_data
# ---------------------------------------------------------------------------

test_that("calibrate_poststrat() rejects targets cells absent from data", {
  df        <- make_surveywts_data(seed = 1)
  pop_extra <- data.frame(
    age_group = c("18-34", "18-34", "35-54", "35-54", "55+", "55+", "65+"),
    sex       = c("M",     "F",     "M",     "F",     "M",   "F",   "M"),
    target    = c(1440, 1560, 1920, 2080, 1680, 1320, 500),
    stringsAsFactors = FALSE
  )
  expect_error(
    calibrate_poststrat(df, targets = pop_extra, type = "count"),
    class = "surveywts_error_population_cell_not_in_data"
  )
  expect_snapshot(
    error = TRUE,
    calibrate_poststrat(df, targets = pop_extra, type = "count")
  )
})

# ---------------------------------------------------------------------------
# 31. Edge — 0-row data fires empty_data before weights_not_found
# ---------------------------------------------------------------------------

test_that("calibrate_poststrat() empty_data fires before weights_not_found", {
  df0 <- make_surveywts_data(seed = 1)[0, ]
  pop <- .make_targets_ps()
  expect_error(
    calibrate_poststrat(df0, targets = pop, weights = no_such_col,
                        type = "count"),
    class = "surveywts_error_empty_data"
  )
})

# ---------------------------------------------------------------------------
# 32. Edge — 1-row data, 1-cell targets
# ---------------------------------------------------------------------------

test_that("calibrate_poststrat() works with 1-row data and 1-cell targets", {
  df_1 <- data.frame(
    age_group = "18-34",
    stringsAsFactors = FALSE
  )
  targets_1 <- data.frame(
    age_group = "18-34",
    target    = 1000.0,
    stringsAsFactors = FALSE
  )

  result <- calibrate_poststrat(df_1, targets = targets_1, type = "count")

  test_invariants(result)
  expect_true(inherits(result, "weighted_df"))
})

# ---------------------------------------------------------------------------
# 33. Edge — single stratification variable
# ---------------------------------------------------------------------------

test_that("calibrate_poststrat() works with a single strata variable", {
  df         <- make_surveywts_data(seed = 7)
  pop_single <- data.frame(
    age_group = c("18-34", "35-54", "55+"),
    target    = c(3000, 4000, 3000),
    stringsAsFactors = FALSE
  )
  result <- calibrate_poststrat(df, targets = pop_single, type = "count")

  test_invariants(result)
  expect_true(inherits(result, "weighted_df"))
})

# ---------------------------------------------------------------------------
# 34. Edge — targets with only "target" column triggers no_strata_variables
# ---------------------------------------------------------------------------

test_that("calibrate_poststrat() rejects targets = data.frame(target = 1)", {
  df          <- make_surveywts_data(seed = 1)
  targets_bad <- data.frame(target = 1.0, stringsAsFactors = FALSE)
  expect_error(
    calibrate_poststrat(df, targets = targets_bad, type = "prop"),
    class = "surveywts_error_no_strata_variables"
  )
})

# ---------------------------------------------------------------------------
# 35. Edge — weights_nonpositive fires before empty_stratum
# ---------------------------------------------------------------------------

test_that("calibrate_poststrat() weights_nonpositive fires before empty_stratum", {
  df <- make_surveywts_data(n = 50L, seed = 20)
  df$base_weight[df$age_group == "55+"] <- 0
  pop <- data.frame(
    age_group = c("18-34", "35-54", "55+"),
    target    = c(3000, 4000, 3000),
    stringsAsFactors = FALSE
  )
  expect_error(
    calibrate_poststrat(df, targets = pop, weights = base_weight,
                        type = "count"),
    class = "surveywts_error_weights_nonpositive"
  )
})

# ---------------------------------------------------------------------------
# 36. History — correct structure after calibration
# ---------------------------------------------------------------------------

test_that("calibrate_poststrat() history entry has correct structure", {
  df  <- make_surveywts_data(seed = 9)
  pop <- .make_targets_ps("count")

  result  <- calibrate_poststrat(df, targets = pop, type = "count")
  history <- attr(result, "weighting_history")

  expect_length(history, 1L)
  entry <- history[[1L]]

  expect_identical(entry$step, 1L)
  expect_identical(entry$operation, "calibrate_poststrat")
  expect_true(inherits(entry$timestamp, "POSIXct"))
  expect_true(all(nchar(entry$call) > 0L))
  expect_type(entry$parameters, "list")
  expect_type(entry$weight_stats, "list")
  expect_true(!is.null(entry$weight_stats$before))
  expect_true(!is.null(entry$weight_stats$after))
  expect_null(entry$convergence)  # non-iterative
  expect_identical(
    entry$package_version,
    as.character(utils::packageVersion("surveywts"))
  )
})

# ---------------------------------------------------------------------------
# 37. History — step increments correctly in chained calls
# ---------------------------------------------------------------------------

test_that("calibrate_poststrat() step increments correctly in chained calls", {
  df  <- make_surveywts_data(seed = 11)
  pop <- .make_targets_ps("count")

  targets_greg <- list(
    age_group = c("18-34" = 0.30, "35-54" = 0.40, "55+" = 0.30),
    sex       = c("M" = 0.48, "F" = 0.52)
  )

  result1 <- calibrate_greg(df, targets = targets_greg)
  result2 <- calibrate_poststrat(
    result1,
    targets = pop,
    weights = wts,
    type = "count"
  )

  history <- attr(result2, "weighting_history")
  expect_length(history, 2L)
  expect_identical(history[[1L]]$step, 1L)
  expect_identical(history[[2L]]$step, 2L)
  expect_identical(history[[1L]]$operation, "calibrate_greg")
  expect_identical(history[[2L]]$operation, "calibrate_poststrat")
})

# ---------------------------------------------------------------------------
# 38. wt_name — default is "wts"
# ---------------------------------------------------------------------------

test_that("calibrate_poststrat() names output weight column 'wts' by default", {
  df  <- make_surveywts_data(seed = 1)
  pop <- .make_targets_ps("count")
  result <- calibrate_poststrat(df, targets = pop, type = "count")
  test_invariants(result)
  expect_identical(attr(result, "weight_col"), "wts")
  expect_true("wts" %in% names(result))
})

# ---------------------------------------------------------------------------
# 39. wt_name — custom wt_name is used
# ---------------------------------------------------------------------------

test_that("calibrate_poststrat() uses custom wt_name for output column", {
  df  <- make_surveywts_data(seed = 1)
  pop <- .make_targets_ps("count")
  result <- calibrate_poststrat(df, targets = pop, type = "count",
                                wt_name = "ps_wt")
  test_invariants(result)
  expect_identical(attr(result, "weight_col"), "ps_wt")
  expect_true("ps_wt" %in% names(result))
})

# ---------------------------------------------------------------------------
# 40. wt_name — survey object ignores wt_name
# ---------------------------------------------------------------------------

test_that("calibrate_poststrat() ignores wt_name for survey_nonprob input", {
  df <- make_surveywts_data(seed = 1)
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
  pop <- .make_targets_ps("count")
  result <- calibrate_poststrat(snp, targets = pop, type = "count",
                                wt_name = "ignored_name")
  expect_identical(result@variables$weights, snp@variables$weights)
})

# ---------------------------------------------------------------------------
# 41. wt_name — records wt_name in weighting history
# ---------------------------------------------------------------------------

test_that("calibrate_poststrat() records wt_name in weighting history", {
  df  <- make_surveywts_data(seed = 1)
  pop <- .make_targets_ps("count")
  result <- calibrate_poststrat(df, targets = pop, type = "count",
                                wt_name = "ps_wt")
  history <- attr(result, "weighting_history")
  expect_identical(history[[length(history)]]$weight_col, "ps_wt")
})

# ---------------------------------------------------------------------------
# 42. Deleted-function regression guard: old poststratify() no longer exists
# ---------------------------------------------------------------------------

test_that("old poststratify() with strata + population args no longer exists", {
  df <- make_surveywts_data(seed = 1)
  pop <- data.frame(
    age_group = c("18-34", "35-54", "55+"),
    target    = c(0.30, 0.40, 0.30),
    stringsAsFactors = FALSE
  )
  # poststratify() is gone; should produce an error
  expect_error(
    poststratify(df, strata = c(age_group), population = pop)
  )
})
