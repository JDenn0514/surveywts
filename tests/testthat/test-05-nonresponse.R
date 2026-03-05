# tests/testthat/test-05-nonresponse.R
#
# Tests for adjust_nonresponse()
# Per spec §XIII adjust_nonresponse() test items 1–17
# Per impl plan PR 8 acceptance criteria
#
# All error path tests use the dual pattern:
#   expect_error(class = ...) + expect_snapshot(error = TRUE, ...)

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

.make_test_taylor_nr <- function(df, weight_col = "base_weight") {
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

.make_test_replicate_nr <- function(df) {
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
# 1. Happy path — data.frame → weighted_df (respondents only returned)
# ---------------------------------------------------------------------------

test_that("adjust_nonresponse() returns weighted_df for data.frame input", {
  df <- make_surveyweights_data(seed = 1, include_nonrespondents = TRUE)

  result <- adjust_nonresponse(df, response_status = responded)

  test_invariants(result)
  expect_true(inherits(result, "weighted_df"))
  expect_identical(attr(result, "weight_col"), ".weight")
  # Only respondent rows returned
  expect_true(nrow(result) < nrow(df))
  expect_true(all(result[[".weight"]] > 0))
})

# ---------------------------------------------------------------------------
# 1b. Happy path — logical TRUE/FALSE response_status
# ---------------------------------------------------------------------------

test_that("adjust_nonresponse() handles logical response_status same as integer", {
  df_int <- make_surveyweights_data(seed = 2, include_nonrespondents = TRUE)
  df_lgl <- df_int
  df_lgl$responded_lgl <- as.logical(df_lgl$responded)

  result_int <- adjust_nonresponse(df_int, response_status = responded)
  result_lgl <- adjust_nonresponse(df_lgl, response_status = responded_lgl)

  expect_equal(nrow(result_int), nrow(result_lgl))
  expect_equal(result_int[[".weight"]], result_lgl[[".weight"]], tolerance = 1e-10)
})

# ---------------------------------------------------------------------------
# 2. Happy path — survey_taylor input → survey_taylor (same class)
# ---------------------------------------------------------------------------

test_that("adjust_nonresponse() returns survey_taylor for survey_taylor input", {
  df <- make_surveyweights_data(seed = 3, include_nonrespondents = TRUE)
  design <- .make_test_taylor_nr(df)

  result <- adjust_nonresponse(design, response_status = responded)

  test_invariants(result)
  expect_true(S7::S7_inherits(result, surveycore::survey_taylor))
  # Does NOT promote to survey_calibrated (same class returned)
  expect_false(S7::S7_inherits(result, surveycore::survey_calibrated))
  # Only respondent rows
  expect_true(nrow(result@data) < nrow(df))
})

# ---------------------------------------------------------------------------
# 2b. Happy path — weighted_df input → weighted_df
# ---------------------------------------------------------------------------

test_that("adjust_nonresponse() returns weighted_df for weighted_df input", {
  df <- make_surveyweights_data(seed = 4, include_nonrespondents = TRUE)
  wdf <- .make_weighted_df(df, "base_weight", list())

  result <- adjust_nonresponse(wdf, response_status = responded)

  test_invariants(result)
  expect_true(inherits(result, "weighted_df"))
  expect_true(nrow(result) < nrow(df))
})

# ---------------------------------------------------------------------------
# 2c. Happy path — survey_calibrated input → survey_calibrated
# ---------------------------------------------------------------------------

test_that("adjust_nonresponse() returns survey_calibrated for survey_calibrated input", {
  df <- make_surveyweights_data(seed = 5, include_nonrespondents = TRUE)
  design <- .make_test_taylor_nr(df)

  # Calibrate first to get a survey_calibrated object
  pop <- list(
    age_group = c("18-34" = 0.30, "35-54" = 0.40, "55+" = 0.30),
    sex = c("M" = 0.48, "F" = 0.52)
  )
  calibrated <- calibrate(design, variables = c(age_group, sex), population = pop)

  result <- adjust_nonresponse(calibrated, response_status = responded)

  test_invariants(result)
  expect_true(S7::S7_inherits(result, surveycore::survey_calibrated))
  # Same class — does NOT downgrade or change class
  expect_true(nrow(result@data) < nrow(df))
})

# ---------------------------------------------------------------------------
# 3. Happy path — by = NULL (global redistribution)
# ---------------------------------------------------------------------------

test_that("adjust_nonresponse() performs global redistribution when by = NULL", {
  df <- make_surveyweights_data(seed = 6, include_nonrespondents = TRUE)
  df$base_weight <- 1  # uniform weights for easy verification

  result <- adjust_nonresponse(df, response_status = responded, weights = base_weight)

  n_all <- nrow(df)
  n_resp <- sum(df$responded == 1)
  expected_weight <- n_all / n_resp

  expect_equal(
    result[["base_weight"]],
    rep(expected_weight, n_resp),
    tolerance = 1e-10
  )
})

# ---------------------------------------------------------------------------
# 4. Happy path — by = c(age_group, sex) (within-class redistribution)
# ---------------------------------------------------------------------------

test_that("adjust_nonresponse() performs within-class redistribution with by", {
  df <- make_surveyweights_data(seed = 7, include_nonrespondents = TRUE)
  df$base_weight <- 1

  result <- adjust_nonresponse(
    df,
    response_status = responded,
    weights = base_weight,
    by = c(age_group, sex)
  )

  test_invariants(result)
  expect_true(inherits(result, "weighted_df"))
  expect_true(nrow(result) == sum(df$responded == 1))
})

# ---------------------------------------------------------------------------
# 5. Weight conservation
# ---------------------------------------------------------------------------

test_that("adjust_nonresponse() conserves total weight", {
  df <- make_surveyweights_data(seed = 8, include_nonrespondents = TRUE)
  df$base_weight <- 1

  sum_before <- sum(df$base_weight)

  result <- adjust_nonresponse(df, response_status = responded, weights = base_weight)
  sum_after <- sum(result[["base_weight"]])

  expect_equal(sum_before, sum_after, tolerance = 1e-10)
})

# ---------------------------------------------------------------------------
# 5b. Numerical correctness — hand-calculation verification
# ---------------------------------------------------------------------------

test_that("adjust_nonresponse() matches hand calculation for 2-class example", {
  # Class A: 10 respondents w=1, 2 nonrespondents w=1
  # Class B: 8 respondents w=1, 0 nonrespondents w=1
  # Expected:
  #   Class A: w_new = 1 * (12/10) = 1.2
  #   Class B: w_new = 1 * (8/8) = 1.0
  df <- data.frame(
    class = c(rep("A", 12), rep("B", 8)),
    responded = c(rep(1L, 10), rep(0L, 2), rep(1L, 8)),
    w = 1,
    stringsAsFactors = FALSE
  )

  # Suppress warnings for small cells (class A: 10, class B: 8 < default 20)
  result <- adjust_nonresponse(
    df,
    response_status = responded,
    weights = w,
    by = class,
    control = list(min_cell = 0, max_adjust = Inf)
  )

  class_a_rows <- result[result[["class"]] == "A", ]
  class_b_rows <- result[result[["class"]] == "B", ]

  expect_equal(class_a_rows[["w"]], rep(1.2, 10), tolerance = 1e-10)
  expect_equal(class_b_rows[["w"]], rep(1.0, 8), tolerance = 1e-10)
})

# ---------------------------------------------------------------------------
# 5c. Numerical correctness vs svrep::redistribute_weights()
# ---------------------------------------------------------------------------

test_that("adjust_nonresponse() matches svrep::redistribute_weights() within 1e-8", {
  skip_if_not_installed("svrep")
  skip_if_not_installed("survey")

  df <- make_surveyweights_data(seed = 9, include_nonrespondents = TRUE)

  # Create a replicate design (svrep requires svyrep.design)
  base_design <- survey::svydesign(
    ids = ~1,
    data = df,
    weights = ~base_weight
  )
  rep_design <- survey::as.svrepdesign(base_design, type = "JK1")

  # svrep oracle: redistributes weights from nonrespondents to respondents
  svrep_result <- svrep::redistribute_weights(
    design = rep_design,
    reduce_if = responded == 0,
    increase_if = responded == 1
  )

  # svrep result: extract main weights for respondents (sampling weights)
  svrep_all_weights <- weights(svrep_result, type = "sampling")
  resp_mask <- svrep_result$variables$responded == 1
  svrep_resp_weights <- svrep_all_weights[resp_mask]
  svrep_resp_ids <- svrep_result$variables$id[resp_mask]

  # Our implementation on the same data
  our_result <- adjust_nonresponse(df, response_status = responded,
                                   weights = base_weight)
  our_weights <- our_result[["base_weight"]]
  our_ids <- our_result[["id"]]

  # Sort both by ID for comparison
  svrep_sorted <- svrep_resp_weights[order(svrep_resp_ids)]
  our_sorted <- our_weights[order(our_ids)]

  expect_equal(unname(our_sorted), unname(svrep_sorted), tolerance = 1e-8)
})

# ---------------------------------------------------------------------------
# 5d. Weight conservation WITH by grouping
# ---------------------------------------------------------------------------

test_that("adjust_nonresponse() conserves weight within each by-cell", {
  df <- make_surveyweights_data(seed = 10, include_nonrespondents = TRUE)
  df$base_weight <- 1

  result <- adjust_nonresponse(
    df,
    response_status = responded,
    weights = base_weight,
    by = age_group
  )

  # For each age group: sum of all before == sum of respondents after
  for (grp in unique(df$age_group)) {
    sum_before <- sum(df$base_weight[df$age_group == grp])
    sum_after <- sum(result[["base_weight"]][result[["age_group"]] == grp])
    expect_equal(sum_before, sum_after, tolerance = 1e-10,
                 label = paste("weight conservation in age_group =", grp))
  }
})

# ---------------------------------------------------------------------------
# 6. Standard error paths (SE-1 through SE-8)
# ---------------------------------------------------------------------------

test_that("adjust_nonresponse() rejects unsupported class (SE-1)", {
  m <- matrix(1:9, nrow = 3)

  expect_error(
    adjust_nonresponse(m, response_status = x),
    class = "surveyweights_error_unsupported_class"
  )
  expect_snapshot(
    error = TRUE,
    adjust_nonresponse(m, response_status = x)
  )
})

test_that("adjust_nonresponse() rejects empty data frame (SE-2)", {
  df_empty <- make_surveyweights_data(seed = 1)[0, ]

  expect_error(
    adjust_nonresponse(df_empty, response_status = responded),
    class = "surveyweights_error_empty_data"
  )
  expect_snapshot(
    error = TRUE,
    adjust_nonresponse(df_empty, response_status = responded)
  )
})

test_that("adjust_nonresponse() rejects survey_replicate input (SE-3)", {
  df <- make_surveyweights_data(seed = 1, include_nonrespondents = TRUE)
  rep_design <- .make_test_replicate_nr(df)

  expect_error(
    adjust_nonresponse(rep_design, response_status = responded),
    class = "surveyweights_error_replicate_not_supported"
  )
  expect_snapshot(
    error = TRUE,
    adjust_nonresponse(rep_design, response_status = responded)
  )
})

test_that("adjust_nonresponse() rejects missing weight column (SE-4)", {
  df <- make_surveyweights_data(seed = 1, include_nonrespondents = TRUE)

  expect_error(
    adjust_nonresponse(df, response_status = responded, weights = no_such_col),
    class = "surveyweights_error_weights_not_found"
  )
  expect_snapshot(
    error = TRUE,
    adjust_nonresponse(df, response_status = responded, weights = no_such_col)
  )
})

test_that("adjust_nonresponse() rejects non-numeric weight column (SE-5)", {
  df <- make_surveyweights_data(seed = 1, include_nonrespondents = TRUE)
  df$char_wt <- "bad"

  expect_error(
    adjust_nonresponse(df, response_status = responded, weights = char_wt),
    class = "surveyweights_error_weights_not_numeric"
  )
  expect_snapshot(
    error = TRUE,
    adjust_nonresponse(df, response_status = responded, weights = char_wt)
  )
})

test_that("adjust_nonresponse() rejects non-positive weights (SE-6)", {
  df <- make_surveyweights_data(seed = 1, include_nonrespondents = TRUE)
  df$base_weight[1] <- 0

  expect_error(
    adjust_nonresponse(df, response_status = responded, weights = base_weight),
    class = "surveyweights_error_weights_nonpositive"
  )
  expect_snapshot(
    error = TRUE,
    adjust_nonresponse(df, response_status = responded, weights = base_weight)
  )
})

test_that("adjust_nonresponse() rejects NA in weight column (SE-7)", {
  df <- make_surveyweights_data(seed = 1, include_nonrespondents = TRUE)
  df$base_weight[1] <- NA_real_

  expect_error(
    adjust_nonresponse(df, response_status = responded, weights = base_weight),
    class = "surveyweights_error_weights_na"
  )
  expect_snapshot(
    error = TRUE,
    adjust_nonresponse(df, response_status = responded, weights = base_weight)
  )
})

test_that("adjust_nonresponse() empty_data fires before weights_not_found (SE-8)", {
  df_empty <- make_surveyweights_data(seed = 1)[0, ]

  expect_error(
    adjust_nonresponse(df_empty, response_status = responded, weights = no_such_col),
    class = "surveyweights_error_empty_data"
  )
  expect_snapshot(
    error = TRUE,
    adjust_nonresponse(df_empty, response_status = responded, weights = no_such_col)
  )
})

# ---------------------------------------------------------------------------
# 7. Error — variable_has_na (NA in a by variable)
# ---------------------------------------------------------------------------

test_that("adjust_nonresponse() rejects by variable with NA values", {
  df <- make_surveyweights_data(seed = 11, include_nonrespondents = TRUE)
  df$age_group[1] <- NA_character_

  expect_error(
    adjust_nonresponse(df, response_status = responded, by = age_group),
    class = "surveyweights_error_variable_has_na"
  )
  expect_snapshot(
    error = TRUE,
    adjust_nonresponse(df, response_status = responded, by = age_group)
  )
})

# ---------------------------------------------------------------------------
# 8. Error — response_status_has_na
# ---------------------------------------------------------------------------

test_that("adjust_nonresponse() rejects response_status with NA values", {
  df <- make_surveyweights_data(seed = 12, include_nonrespondents = TRUE)
  df$responded[1] <- NA_integer_

  expect_error(
    adjust_nonresponse(df, response_status = responded),
    class = "surveyweights_error_response_status_has_na"
  )
  expect_snapshot(
    error = TRUE,
    adjust_nonresponse(df, response_status = responded)
  )
})

# ---------------------------------------------------------------------------
# 9. Error — response_status_not_found
# ---------------------------------------------------------------------------

test_that("adjust_nonresponse() rejects missing response_status column", {
  df <- make_surveyweights_data(seed = 13)  # no responded column

  expect_error(
    adjust_nonresponse(df, response_status = responded),
    class = "surveyweights_error_response_status_not_found"
  )
  expect_snapshot(
    error = TRUE,
    adjust_nonresponse(df, response_status = responded)
  )
})

# ---------------------------------------------------------------------------
# 10. Error — response_status_not_binary (integer/character with wrong values)
# ---------------------------------------------------------------------------

test_that("adjust_nonresponse() rejects response_status with non-binary integer values", {
  df <- make_surveyweights_data(seed = 14)
  df$resp_bad <- c(0L, 1L, 2L, rep(0L, nrow(df) - 3))

  expect_error(
    adjust_nonresponse(df, response_status = resp_bad),
    class = "surveyweights_error_response_status_not_binary"
  )
  expect_snapshot(
    error = TRUE,
    adjust_nonresponse(df, response_status = resp_bad)
  )
})

# ---------------------------------------------------------------------------
# 10b. Error — response_status_not_binary (factor column)
# ---------------------------------------------------------------------------

test_that("adjust_nonresponse() rejects factor response_status (not binary)", {
  df <- make_surveyweights_data(seed = 15)
  df$resp_factor <- factor(c("R", "NR", "R", rep("R", nrow(df) - 3)))

  expect_error(
    adjust_nonresponse(df, response_status = resp_factor),
    class = "surveyweights_error_response_status_not_binary"
  )
  expect_snapshot(
    error = TRUE,
    adjust_nonresponse(df, response_status = resp_factor)
  )
})

# ---------------------------------------------------------------------------
# 11. Error — response_status_all_zero
# ---------------------------------------------------------------------------

test_that("adjust_nonresponse() rejects data with all nonrespondents", {
  df <- make_surveyweights_data(seed = 16)
  df$responded <- 0L

  expect_error(
    adjust_nonresponse(df, response_status = responded),
    class = "surveyweights_error_response_status_all_zero"
  )
  expect_snapshot(
    error = TRUE,
    adjust_nonresponse(df, response_status = responded)
  )
})

# ---------------------------------------------------------------------------
# 12. Error — class_cell_empty (by variable creates empty respondent cell)
# ---------------------------------------------------------------------------

test_that("adjust_nonresponse() rejects by-cell with no respondents", {
  # Class A: 5 respondents, 2 nonrespondents — OK
  # Class B: 0 respondents, 3 nonrespondents — class_cell_empty error
  df <- data.frame(
    class = c(rep("A", 7), rep("B", 3)),
    responded = c(rep(1L, 5), rep(0L, 2), rep(0L, 3)),
    w = 1,
    stringsAsFactors = FALSE
  )

  expect_error(
    adjust_nonresponse(df, response_status = responded, weights = w, by = class),
    class = "surveyweights_error_class_cell_empty"
  )
  expect_snapshot(
    error = TRUE,
    adjust_nonresponse(df, response_status = responded, weights = w, by = class)
  )
})

# ---------------------------------------------------------------------------
# 13. Error — propensity_requires_phase2
# ---------------------------------------------------------------------------

test_that("adjust_nonresponse() rejects method = 'propensity' (Phase 2 stub)", {
  df <- make_surveyweights_data(seed = 17, include_nonrespondents = TRUE)

  expect_error(
    adjust_nonresponse(df, response_status = responded, method = "propensity"),
    class = "surveyweights_error_propensity_requires_phase2"
  )
  expect_snapshot(
    error = TRUE,
    adjust_nonresponse(df, response_status = responded, method = "propensity")
  )
})

test_that("adjust_nonresponse() rejects method = 'propensity-cell' (Phase 2 stub)", {
  df <- make_surveyweights_data(seed = 18, include_nonrespondents = TRUE)

  expect_error(
    adjust_nonresponse(df, response_status = responded, method = "propensity-cell"),
    class = "surveyweights_error_propensity_requires_phase2"
  )
  expect_snapshot(
    error = TRUE,
    adjust_nonresponse(df, response_status = responded, method = "propensity-cell")
  )
})

# ---------------------------------------------------------------------------
# 14. Warning — class_near_empty triggered by low count (< 20 respondents)
# ---------------------------------------------------------------------------

test_that("adjust_nonresponse() warns when a cell has fewer than 20 respondents", {
  # Construct a cell with only 5 respondents + 2 nonrespondents
  df_small <- data.frame(
    class = c(rep("small", 7), rep("big", 100)),
    responded = c(rep(1L, 5), rep(0L, 2), rep(1L, 80), rep(0L, 20)),
    w = 1,
    stringsAsFactors = FALSE
  )

  expect_warning(
    result <- adjust_nonresponse(
      df_small,
      response_status = responded,
      weights = w,
      by = class
    ),
    class = "surveyweights_warning_class_near_empty"
  )
  expect_snapshot(
    adjust_nonresponse(
      df_small,
      response_status = responded,
      weights = w,
      by = class
    )
  )
  test_invariants(result)
})

# ---------------------------------------------------------------------------
# 14b. Warning — class_near_empty triggered by high adjustment factor (> 2.0)
# ---------------------------------------------------------------------------

test_that("adjust_nonresponse() warns when adjustment factor exceeds 2.0", {
  # Class A: 30 respondents (w=1), 35 nonrespondents (w=1)
  # adj_factor = 65/30 = 2.167 > 2.0
  df_high_adj <- data.frame(
    class = rep("A", 65),
    responded = c(rep(1L, 30), rep(0L, 35)),
    w = 1,
    stringsAsFactors = FALSE
  )

  expect_warning(
    result <- adjust_nonresponse(
      df_high_adj,
      response_status = responded,
      weights = w,
      by = class
    ),
    class = "surveyweights_warning_class_near_empty"
  )
  test_invariants(result)
})

# ---------------------------------------------------------------------------
# 15. Edge — all respondents (no nonrespondents to redistribute)
# ---------------------------------------------------------------------------

test_that("adjust_nonresponse() returns unchanged weights when all are respondents", {
  df <- make_surveyweights_data(seed = 19)
  df$responded <- 1L

  result <- adjust_nonresponse(df, response_status = responded)

  test_invariants(result)
  expect_equal(nrow(result), nrow(df))
  # Weights unchanged (adj factor = 1.0 with zero nonrespondents)
  expect_equal(result[[".weight"]], rep(1 / nrow(df), nrow(df)), tolerance = 1e-10)
})

# ---------------------------------------------------------------------------
# 16. Edge — single weighting class (equivalent to global)
# ---------------------------------------------------------------------------

test_that("adjust_nonresponse() single by-cell gives same result as global", {
  df <- make_surveyweights_data(seed = 20, include_nonrespondents = TRUE)
  df$const_class <- "all"

  result_global <- adjust_nonresponse(df, response_status = responded)
  result_single <- adjust_nonresponse(
    df, response_status = responded, by = const_class
  )

  expect_equal(
    result_global[[".weight"]],
    result_single[[".weight"]],
    tolerance = 1e-10
  )
})

# ---------------------------------------------------------------------------
# 17. History entry has correct structure
# ---------------------------------------------------------------------------

test_that("adjust_nonresponse() history entry has correct structure", {
  df <- make_surveyweights_data(seed = 21, include_nonrespondents = TRUE)

  result <- adjust_nonresponse(
    df,
    response_status = responded,
    by = c(age_group, sex)
  )

  history <- attr(result, "weighting_history")
  expect_true(is.list(history))
  expect_equal(length(history), 1L)

  entry <- history[[1L]]

  # step
  expect_true(is.integer(entry$step))
  expect_equal(entry$step, 1L)

  # operation
  expect_identical(entry$operation, "nonresponse_weighting_class")

  # timestamp
  expect_true(inherits(entry$timestamp, "POSIXct"))

  # call
  expect_true(is.character(entry$call) && all(nchar(entry$call) > 0))

  # parameters
  expect_true(is.list(entry$parameters))
  expect_true("by_variables" %in% names(entry$parameters))
  expect_true("method" %in% names(entry$parameters))
  expect_equal(entry$parameters$by_variables, c("age_group", "sex"))
  expect_identical(entry$parameters$method, "weighting-class")

  # weight_stats
  expect_true(is.list(entry$weight_stats))
  expect_true("before" %in% names(entry$weight_stats))
  expect_true("after" %in% names(entry$weight_stats))

  # convergence — NULL for non-iterative
  expect_null(entry$convergence)

  # package_version
  expect_identical(
    entry$package_version,
    as.character(utils::packageVersion("surveyweights"))
  )
})

# ---------------------------------------------------------------------------
# 10c. Error — response_status_not_binary (character column)
# ---------------------------------------------------------------------------

test_that("adjust_nonresponse() rejects character response_status (not binary)", {
  # Covers R/nonresponse.R lines 411-428: "all other types" branch in
  # .validate_response_status_binary() for character input
  df <- make_surveyweights_data(seed = 19)
  df$resp_char <- rep(c("yes", "no"), length.out = nrow(df))

  expect_error(
    adjust_nonresponse(df, response_status = resp_char),
    class = "surveyweights_error_response_status_not_binary"
  )
  expect_snapshot(
    error = TRUE,
    adjust_nonresponse(df, response_status = resp_char)
  )
})
