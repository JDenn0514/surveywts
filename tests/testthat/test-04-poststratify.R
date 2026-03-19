# tests/testthat/test-04-poststratify.R
#
# Tests for poststratify()
# Per spec §XIII poststratify() test items 1–15
# Per impl plan PR 7 acceptance criteria
#
# All error path tests use the dual pattern:
#   expect_error(class = ...) + expect_snapshot(error = TRUE, ...)

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

# Joint population for age_group x sex (6 cells, type = "count")
.make_pop_ps <- function(type = "count") {
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
# 1. Happy path — data.frame → weighted_df
# ---------------------------------------------------------------------------

test_that("poststratify() returns weighted_df for data.frame input", {
  df  <- make_surveywts_data(seed = 1)
  pop <- .make_pop_ps()

  result <- poststratify(df, strata = c(age_group, sex), population = pop,
                         type = "count")

  test_invariants(result)
  expect_true(inherits(result, "weighted_df"))
  expect_identical(attr(result, "weight_col"), ".weight")
  expect_true(all(result[[".weight"]] > 0))
})

# ---------------------------------------------------------------------------
# 1c. Happy path — type = "prop" is the default (consistent with calibrate/rake)
# ---------------------------------------------------------------------------

test_that("poststratify() default type is 'prop', consistent with calibrate/rake", {
  df  <- make_surveywts_data(seed = 2)
  pop_count <- .make_pop_ps("count")
  pop_prop  <- .make_pop_ps("prop")

  # Succeeds with prop-format population and no type argument (default = "prop")
  result_prop <- poststratify(df, strata = c(age_group, sex),
                              population = pop_prop)
  test_invariants(result_prop)
  expect_true(inherits(result_prop, "weighted_df"))

  # Succeeds with count-format population when type = "count" is explicit
  result_count <- poststratify(df, strata = c(age_group, sex),
                               population = pop_count, type = "count")
  test_invariants(result_count)
  expect_true(inherits(result_count, "weighted_df"))

  # Using count-format population (targets summing to 10000) without type =
  # "count" fails because the default "prop" requires targets summing to 1.0
  expect_error(
    poststratify(df, strata = c(age_group, sex),
                 population = pop_count),
    class = "surveywts_error_population_totals_invalid"
  )
})

# ---------------------------------------------------------------------------
# 2. Happy path — weighted_df → weighted_df (history accumulates)
# ---------------------------------------------------------------------------

test_that("poststratify() returns weighted_df for weighted_df input", {
  df  <- make_surveywts_data(seed = 3)
  pop <- .make_pop_ps()

  wdf <- structure(
    tibble::as_tibble(df),
    class = c("weighted_df", "tbl_df", "tbl", "data.frame"),
    weight_col = "base_weight",
    weighting_history = list()
  )

  result <- poststratify(wdf, strata = c(age_group, sex), population = pop,
                         weights = base_weight, type = "count")

  test_invariants(result)
  expect_true(inherits(result, "weighted_df"))
  expect_length(attr(result, "weighting_history"), 1L)
})

# ---------------------------------------------------------------------------
# 3. Happy path — survey_taylor → survey_taylor (class preserved)
# ---------------------------------------------------------------------------

test_that("poststratify() preserves survey_taylor class for survey_taylor input", {
  df     <- make_surveywts_data(seed = 4)
  design <- .make_test_taylor_ps(df)
  pop    <- .make_pop_ps()

  result <- poststratify(design, strata = c(age_group, sex), population = pop,
                         type = "count")

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
# 4. Happy path — survey_nonprob → survey_nonprob
# ---------------------------------------------------------------------------

test_that("poststratify() accepts and returns survey_nonprob", {
  df  <- make_surveywts_data(seed = 5)
  pop <- .make_pop_ps()

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

  result <- poststratify(sc_input, strata = c(age_group, sex), population = pop,
                         type = "count")

  test_invariants(result)
  expect_true(S7::S7_inherits(result, surveycore::survey_nonprob))
  expect_identical(length(result@metadata@weighting_history), 1L)
})

# ---------------------------------------------------------------------------
# 5. Happy path — numeric/integer strata column (no categorical restriction)
# ---------------------------------------------------------------------------

test_that("poststratify() accepts integer strata columns", {
  df <- make_surveywts_data(seed = 6)
  df$age_int <- ifelse(df$age_group == "18-34", 1L,
                  ifelse(df$age_group == "35-54", 2L, 3L))

  pop <- data.frame(
    age_int = c(1L, 2L, 3L),
    target  = c(3000, 4000, 3000),
    stringsAsFactors = FALSE
  )

  result <- poststratify(df, strata = c(age_int), population = pop,
                         type = "count")

  test_invariants(result)
  expect_true(inherits(result, "weighted_df"))
})

# ---------------------------------------------------------------------------
# 6. Numerical correctness — matches survey::postStratify() within 1e-8
# ---------------------------------------------------------------------------

test_that("poststratify() matches survey::postStratify() within 1e-8", {
  skip_if_not_installed("survey")

  df  <- make_surveywts_data(n = 300L, seed = 10)
  pop <- .make_pop_ps()

  result <- poststratify(df, strata = c(age_group, sex), population = pop,
                         weights = base_weight, type = "count")
  sw_weights <- result[["base_weight"]]

  svy_design <- survey::svydesign(ids = ~1, weights = ~base_weight, data = df)
  pop_strata <- data.frame(
    age_group = c("18-34", "18-34", "35-54", "35-54", "55+", "55+"),
    sex       = c("M",     "F",     "M",     "F",     "M",   "F"),
    Freq      = c(1440, 1560, 1920, 2080, 1680, 1320),
    stringsAsFactors = FALSE
  )
  svy_result <- survey::postStratify(svy_design, ~age_group + sex,
                                     pop_strata, partial = FALSE)
  ref_weights <- as.numeric(weights(svy_result))

  expect_equal(sw_weights, ref_weights, tolerance = 1e-8)
})

# ---------------------------------------------------------------------------
# 7. Standard error paths SE-1 through SE-8
# ---------------------------------------------------------------------------

test_that("poststratify() rejects unsupported input class (SE-1)", {
  pop <- .make_pop_ps()
  expect_error(
    poststratify(matrix(1:4, 2, 2), strata = c(V1), population = pop,
                 type = "count"),
    class = "surveywts_error_unsupported_class"
  )
  expect_snapshot(
    error = TRUE,
    poststratify(matrix(1:4, 2, 2), strata = c(V1), population = pop,
                 type = "count")
  )
})

test_that("poststratify() rejects 0-row data frame (SE-2)", {
  df0 <- make_surveywts_data(seed = 1)[0, ]
  pop <- .make_pop_ps()
  expect_error(
    poststratify(df0, strata = c(age_group, sex), population = pop,
                 type = "count"),
    class = "surveywts_error_empty_data"
  )
  expect_snapshot(
    error = TRUE,
    poststratify(df0, strata = c(age_group, sex), population = pop,
                 type = "count")
  )
})

test_that("poststratify() rejects survey_replicate input (SE-3)", {
  df  <- make_surveywts_data(seed = 11)
  pop <- .make_pop_ps()
  rep_obj <- .make_test_replicate_ps(df)
  expect_error(
    poststratify(rep_obj, strata = c(age_group, sex), population = pop,
                 type = "count"),
    class = "surveywts_error_replicate_not_supported"
  )
  expect_snapshot(
    error = TRUE,
    poststratify(rep_obj, strata = c(age_group, sex), population = pop,
                 type = "count")
  )
})

test_that("poststratify() rejects missing named weight column (SE-4)", {
  df  <- make_surveywts_data(seed = 1)
  pop <- .make_pop_ps()
  expect_error(
    poststratify(df, strata = c(age_group, sex), population = pop,
                 weights = no_such_col, type = "count"),
    class = "surveywts_error_weights_not_found"
  )
  expect_snapshot(
    error = TRUE,
    poststratify(df, strata = c(age_group, sex), population = pop,
                 weights = no_such_col, type = "count")
  )
})

test_that("poststratify() rejects non-numeric weight column (SE-5)", {
  df        <- make_surveywts_data(seed = 1)
  df$bad_wt <- as.character(df$base_weight)
  pop       <- .make_pop_ps()
  expect_error(
    poststratify(df, strata = c(age_group, sex), population = pop,
                 weights = bad_wt, type = "count"),
    class = "surveywts_error_weights_not_numeric"
  )
  expect_snapshot(
    error = TRUE,
    poststratify(df, strata = c(age_group, sex), population = pop,
                 weights = bad_wt, type = "count")
  )
})

test_that("poststratify() rejects non-positive weight column (SE-6)", {
  df                <- make_surveywts_data(seed = 1)
  df$base_weight[1] <- 0
  pop               <- .make_pop_ps()
  expect_error(
    poststratify(df, strata = c(age_group, sex), population = pop,
                 weights = base_weight, type = "count"),
    class = "surveywts_error_weights_nonpositive"
  )
  expect_snapshot(
    error = TRUE,
    poststratify(df, strata = c(age_group, sex), population = pop,
                 weights = base_weight, type = "count")
  )
})

test_that("poststratify() rejects NA weight column (SE-7)", {
  df                    <- make_surveywts_data(seed = 1)
  df$base_weight[1]     <- NA_real_
  pop                   <- .make_pop_ps()
  expect_error(
    poststratify(df, strata = c(age_group, sex), population = pop,
                 weights = base_weight, type = "count"),
    class = "surveywts_error_weights_na"
  )
  expect_snapshot(
    error = TRUE,
    poststratify(df, strata = c(age_group, sex), population = pop,
                 weights = base_weight, type = "count")
  )
})

test_that("poststratify() empty_data fires before weights_not_found (SE-8)", {
  df0 <- make_surveywts_data(seed = 1)[0, ]
  pop <- .make_pop_ps()
  expect_error(
    poststratify(df0, strata = c(age_group, sex), population = pop,
                 weights = no_such_col, type = "count"),
    class = "surveywts_error_empty_data"
  )
  expect_snapshot(
    error = TRUE,
    poststratify(df0, strata = c(age_group, sex), population = pop,
                 weights = no_such_col, type = "count")
  )
})

# ---------------------------------------------------------------------------
# 8. Error — variable_has_na
# ---------------------------------------------------------------------------

test_that("poststratify() rejects NA in strata variable", {
  df               <- make_surveywts_data(seed = 1)
  df$age_group[1L] <- NA_character_
  pop              <- .make_pop_ps()
  expect_error(
    poststratify(df, strata = c(age_group, sex), population = pop,
                 type = "count"),
    class = "surveywts_error_variable_has_na"
  )
  expect_snapshot(
    error = TRUE,
    poststratify(df, strata = c(age_group, sex), population = pop,
                 type = "count")
  )
})

# ---------------------------------------------------------------------------
# 8b. Error — population_totals_invalid (type = "prop")
# ---------------------------------------------------------------------------

test_that("poststratify() rejects prop targets that don't sum to 1", {
  df      <- make_surveywts_data(seed = 1)
  pop_bad <- data.frame(
    age_group = c("18-34", "18-34", "35-54", "35-54", "55+", "55+"),
    sex       = c("M",     "F",     "M",     "F",     "M",   "F"),
    target    = c(0.14, 0.15, 0.19, 0.20, 0.17, 0.13),  # sums to 0.98
    stringsAsFactors = FALSE
  )
  expect_error(
    poststratify(df, strata = c(age_group, sex), population = pop_bad,
                 type = "prop"),
    class = "surveywts_error_population_totals_invalid"
  )
  expect_snapshot(
    error = TRUE,
    poststratify(df, strata = c(age_group, sex), population = pop_bad,
                 type = "prop")
  )
})

# ---------------------------------------------------------------------------
# 8c. Error — population_totals_invalid (type = "count", target ≤ 0)
# ---------------------------------------------------------------------------

test_that("poststratify() rejects count targets that are non-positive", {
  df      <- make_surveywts_data(seed = 1)
  pop_bad <- data.frame(
    age_group = c("18-34", "18-34", "35-54", "35-54", "55+", "55+"),
    sex       = c("M",     "F",     "M",     "F",     "M",   "F"),
    target    = c(1440, 1560, 0, 2080, 1680, 1320),  # 0 is non-positive
    stringsAsFactors = FALSE
  )
  expect_error(
    poststratify(df, strata = c(age_group, sex), population = pop_bad,
                 type = "count"),
    class = "surveywts_error_population_totals_invalid"
  )
  expect_snapshot(
    error = TRUE,
    poststratify(df, strata = c(age_group, sex), population = pop_bad,
                 type = "count")
  )
})

# ---------------------------------------------------------------------------
# 8d. Error — population_cell_duplicate
# ---------------------------------------------------------------------------

test_that("poststratify() rejects duplicate rows in population", {
  df      <- make_surveywts_data(seed = 1)
  pop_dup <- data.frame(
    age_group = c("18-34", "18-34", "18-34", "35-54", "35-54", "55+", "55+"),
    sex       = c("M",     "F",     "M",     "F",     "M",     "M",   "F"),
    target    = c(1440, 1560, 1440, 2080, 1920, 1680, 1320),
    stringsAsFactors = FALSE
  )
  expect_error(
    poststratify(df, strata = c(age_group, sex), population = pop_dup,
                 type = "count"),
    class = "surveywts_error_population_cell_duplicate"
  )
  expect_snapshot(
    error = TRUE,
    poststratify(df, strata = c(age_group, sex), population = pop_dup,
                 type = "count")
  )
})

# ---------------------------------------------------------------------------
# 9. Error — population_cell_missing
# ---------------------------------------------------------------------------

test_that("poststratify() rejects population missing a data cell", {
  df          <- make_surveywts_data(seed = 1)
  pop_missing <- data.frame(
    age_group = c("18-34", "18-34", "35-54", "35-54", "55+"),
    sex       = c("M",     "F",     "M",     "F",     "M"),
    target    = c(1440, 1560, 1920, 2080, 3000),
    stringsAsFactors = FALSE
  )
  expect_error(
    poststratify(df, strata = c(age_group, sex), population = pop_missing,
                 type = "count"),
    class = "surveywts_error_population_cell_missing"
  )
  expect_snapshot(
    error = TRUE,
    poststratify(df, strata = c(age_group, sex), population = pop_missing,
                 type = "count")
  )
})

# ---------------------------------------------------------------------------
# 10. Error — population_cell_not_in_data
# ---------------------------------------------------------------------------

test_that("poststratify() rejects population cells absent from data", {
  df        <- make_surveywts_data(seed = 1)
  pop_extra <- data.frame(
    age_group = c("18-34", "18-34", "35-54", "35-54", "55+", "55+", "65+"),
    sex       = c("M",     "F",     "M",     "F",     "M",   "F",   "M"),
    target    = c(1440, 1560, 1920, 2080, 1680, 1320, 500),
    stringsAsFactors = FALSE
  )
  expect_error(
    poststratify(df, strata = c(age_group, sex), population = pop_extra,
                 type = "count"),
    class = "surveywts_error_population_cell_not_in_data"
  )
  expect_snapshot(
    error = TRUE,
    poststratify(df, strata = c(age_group, sex), population = pop_extra,
                 type = "count")
  )
})

# ---------------------------------------------------------------------------
# 11. Error — empty_stratum
#
# Phase 0 note: empty_stratum (N_hat_h = 0) is architecturally unreachable
# via the public API because .validate_weights() blocks zero weights before
# .calibrate_engine() is called. The defensive check is present for Phase 1+
# scenarios (e.g., replicate weights, trimmed weights). Here we document the
# ordering: weights_nonpositive fires first when a cell's weights are zero.
# ---------------------------------------------------------------------------

test_that("poststratify() weights_nonpositive fires before empty_stratum", {
  df <- make_surveywts_data(n = 50L, seed = 20)
  # Force all "55+" rows to have zero weight (non-positive)
  df$base_weight[df$age_group == "55+"] <- 0
  pop <- data.frame(
    age_group = c("18-34", "35-54", "55+"),
    target    = c(3000, 4000, 3000),
    stringsAsFactors = FALSE
  )
  # validate_weights fires first (weights_nonpositive), not empty_stratum
  expect_error(
    poststratify(df, strata = c(age_group), population = pop,
                 weights = base_weight, type = "count"),
    class = "surveywts_error_weights_nonpositive"
  )
})

# ---------------------------------------------------------------------------
# 12. Edge — single stratum variable
# ---------------------------------------------------------------------------

test_that("poststratify() works with a single strata variable", {
  df         <- make_surveywts_data(seed = 7)
  pop_single <- data.frame(
    age_group = c("18-34", "35-54", "55+"),
    target    = c(3000, 4000, 3000),
    stringsAsFactors = FALSE
  )
  result <- poststratify(df, strata = c(age_group), population = pop_single,
                         type = "count")

  test_invariants(result)
  expect_true(inherits(result, "weighted_df"))
})

# ---------------------------------------------------------------------------
# 13. Edge — type = "prop"
# ---------------------------------------------------------------------------

test_that("poststratify() produces positive weights with type = 'prop'", {
  df  <- make_surveywts_data(seed = 8)
  pop <- .make_pop_ps("prop")

  result <- poststratify(df, strata = c(age_group, sex), population = pop,
                         type = "prop")

  test_invariants(result)
  expect_true(inherits(result, "weighted_df"))
  expect_true(all(result[[".weight"]] > 0))
})

# ---------------------------------------------------------------------------
# 14. History — correct structure after post-stratification
# ---------------------------------------------------------------------------

test_that("poststratify() history entry has correct structure", {
  df  <- make_surveywts_data(seed = 9)
  pop <- .make_pop_ps()

  result  <- poststratify(df, strata = c(age_group, sex), population = pop,
                          type = "count")
  history <- attr(result, "weighting_history")

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
  expect_null(entry$convergence)  # non-iterative
  expect_identical(
    entry$package_version,
    as.character(utils::packageVersion("surveywts"))
  )
})

# ---------------------------------------------------------------------------
# 15. History — step number increments correctly across chained calls
# ---------------------------------------------------------------------------

test_that("poststratify() step increments correctly in chained calls", {
  df  <- make_surveywts_data(seed = 11)
  pop <- .make_pop_ps()

  result1 <- calibrate(
    df,
    variables = c(age_group, sex),
    population = list(
      age_group = c("18-34" = 0.30, "35-54" = 0.40, "55+" = 0.30),
      sex       = c("M" = 0.48, "F" = 0.52)
    )
  )
  result2 <- poststratify(
    result1,
    strata = c(age_group, sex),
    population = pop,
    weights = .weight,
    type = "count"
  )

  history <- attr(result2, "weighting_history")
  expect_length(history, 2L)
  expect_identical(history[[1L]]$step, 1L)
  expect_identical(history[[2L]]$step, 2L)
  expect_identical(history[[1L]]$operation, "calibration")
  expect_identical(history[[2L]]$operation, "poststratify")
})

# ---------------------------------------------------------------------------
# 9b. Error — population_cell_missing (missing required column in population)
# ---------------------------------------------------------------------------

test_that("poststratify() rejects population missing the 'target' column", {
  # Covers R/poststratify.R lines 272-287 and
  # .validate_population_cells() required column check
  df <- make_surveywts_data(seed = 12)

  # Population data frame is missing the required 'target' column
  pop_no_target <- data.frame(
    age_group = c("18-34", "35-54", "55+"),
    stringsAsFactors = FALSE
  )

  expect_error(
    poststratify(df, strata = c(age_group), population = pop_no_target,
                 type = "count"),
    class = "surveywts_error_population_cell_missing"
  )
  expect_snapshot(
    error = TRUE,
    poststratify(df, strata = c(age_group), population = pop_no_target,
                 type = "count")
  )
})
