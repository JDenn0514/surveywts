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
  df <- make_surveywts_data(seed = 1, include_nonrespondents = TRUE)

  result <- adjust_nonresponse(df, response_status = responded)

  test_invariants(result)
  expect_true(inherits(result, "weighted_df"))
  expect_identical(attr(result, "weight_col"), "wts")
  # All rows retained; nonrespondent weights = 0

  expect_equal(nrow(result), nrow(df))
  is_resp <- df$responded == 1L
  expect_true(all(result[["wts"]][!is_resp] == 0))
  expect_true(all(result[["wts"]][is_resp] > 0))
})

# ---------------------------------------------------------------------------
# 1b. Happy path — logical TRUE/FALSE response_status
# ---------------------------------------------------------------------------

test_that("adjust_nonresponse() handles logical response_status same as integer", {
  df_int <- make_surveywts_data(seed = 2, include_nonrespondents = TRUE)
  df_lgl <- df_int
  df_lgl$responded_lgl <- as.logical(df_lgl$responded)

  result_int <- adjust_nonresponse(df_int, response_status = responded)
  result_lgl <- adjust_nonresponse(df_lgl, response_status = responded_lgl)

  expect_equal(nrow(result_int), nrow(result_lgl))
  expect_equal(result_int[["wts"]], result_lgl[["wts"]], tolerance = 1e-10)
})

# ---------------------------------------------------------------------------
# 2. Happy path — survey_taylor input → survey_taylor (same class)
# ---------------------------------------------------------------------------

test_that("adjust_nonresponse() returns survey_taylor for survey_taylor input", {
  df <- make_surveywts_data(seed = 3, include_nonrespondents = TRUE)
  design <- .make_test_taylor_nr(df)

  result <- adjust_nonresponse(design, response_status = responded)

  test_invariants(result)
  expect_true(S7::S7_inherits(result, surveycore::survey_taylor))
  # Does NOT promote to survey_nonprob (same class returned)
  expect_false(S7::S7_inherits(result, surveycore::survey_nonprob))
  # survey_taylor does not support zero weights — respondent rows only
  expect_true(nrow(result@data) < nrow(df))
  expect_true(all(result@data[[result@variables$weights]] > 0))
})

# ---------------------------------------------------------------------------
# 2b. Happy path — weighted_df input → weighted_df
# ---------------------------------------------------------------------------

test_that("adjust_nonresponse() returns weighted_df for weighted_df input", {
  df <- make_surveywts_data(seed = 4, include_nonrespondents = TRUE)
  wdf <- .make_weighted_df(df, "base_weight", list())

  result <- adjust_nonresponse(wdf, response_status = responded)

  test_invariants(result)
  expect_true(inherits(result, "weighted_df"))
  expect_equal(nrow(result), nrow(df))
})

# ---------------------------------------------------------------------------
# 2c. Happy path — survey_nonprob input → survey_nonprob
# ---------------------------------------------------------------------------

test_that("adjust_nonresponse() returns survey_nonprob for survey_nonprob input", {
  df <- make_surveywts_data(seed = 5, include_nonrespondents = TRUE)

  # Construct survey_nonprob directly (not via calibrate())
  calibrated <- surveycore::survey_nonprob(
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

  result <- adjust_nonresponse(calibrated, response_status = responded)

  test_invariants(result)
  expect_true(S7::S7_inherits(result, surveycore::survey_nonprob))
  # Same class — does NOT downgrade or change class
  expect_equal(nrow(result@data), nrow(df))
  is_resp <- df$responded == 1L
  wt_col <- result@variables$weights
  expect_true(all(result@data[[wt_col]][!is_resp] == 0))
  expect_true(all(result@data[[wt_col]][is_resp] > 0))
})

# ---------------------------------------------------------------------------
# 3. Happy path — by = NULL (global redistribution)
# ---------------------------------------------------------------------------

test_that("adjust_nonresponse() performs global redistribution when by = NULL", {
  df <- make_surveywts_data(seed = 6, include_nonrespondents = TRUE)
  df$base_weight <- 1  # uniform weights for easy verification

  result <- adjust_nonresponse(df, response_status = responded, weights = base_weight)

  n_all <- nrow(df)
  n_resp <- sum(df$responded == 1)
  is_resp <- df$responded == 1L
  expected_weight <- n_all / n_resp

  # All rows returned; respondent weights adjusted, nonrespondent weights = 0
  expect_equal(nrow(result), n_all)
  expect_equal(
    result[["wts"]][is_resp],
    rep(expected_weight, n_resp),
    tolerance = 1e-10
  )
  expect_true(all(result[["wts"]][!is_resp] == 0))
})

# ---------------------------------------------------------------------------
# 4. Happy path — by = c(age_group, sex) (within-class redistribution)
# ---------------------------------------------------------------------------

test_that("adjust_nonresponse() performs within-class redistribution with by", {
  df <- make_surveywts_data(seed = 7, include_nonrespondents = TRUE)
  df$base_weight <- 1

  result <- adjust_nonresponse(
    df,
    response_status = responded,
    weights = base_weight,
    by = c(age_group, sex)
  )

  test_invariants(result)
  expect_true(inherits(result, "weighted_df"))
  # All rows retained
  expect_equal(nrow(result), nrow(df))
  expect_true(all(result[["wts"]][df$responded == 0L] == 0))
})

# ---------------------------------------------------------------------------
# 5. Weight conservation
# ---------------------------------------------------------------------------

test_that("adjust_nonresponse() conserves total weight", {
  df <- make_surveywts_data(seed = 8, include_nonrespondents = TRUE)
  df$base_weight <- 1

  sum_before <- sum(df$base_weight)

  result <- adjust_nonresponse(df, response_status = responded, weights = base_weight)
  sum_after <- sum(result[["wts"]])

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

  # Class A: 10 respondents at 1.2, 2 nonrespondents at 0
  class_a_resp <- class_a_rows[class_a_rows[["responded"]] == 1L, ]
  class_a_nonresp <- class_a_rows[class_a_rows[["responded"]] == 0L, ]
  expect_equal(class_a_resp[["wts"]], rep(1.2, 10), tolerance = 1e-10)
  expect_equal(class_a_nonresp[["wts"]], rep(0, 2), tolerance = 1e-10)
  # Class B: 8 respondents at 1.0, 0 nonrespondents
  expect_equal(class_b_rows[["wts"]], rep(1.0, 8), tolerance = 1e-10)
})

# ---------------------------------------------------------------------------
# 5c. Numerical correctness vs svrep::redistribute_weights()
# ---------------------------------------------------------------------------

test_that("adjust_nonresponse() matches svrep::redistribute_weights() within 1e-8", {
  skip_if_not_installed("svrep")

  df <- make_surveywts_data(seed = 9, include_nonrespondents = TRUE)

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

  # svrep result: extract all weights (sampling weights)
  # svrep::redistribute_weights() zeroes nonrespondents, adjusts respondents
  svrep_all_weights <- weights(svrep_result, type = "sampling")
  svrep_ids <- svrep_result$variables$id

  # Our implementation on the same data
  our_result <- adjust_nonresponse(df, response_status = responded,
                                   weights = base_weight)
  our_weights <- our_result[["wts"]]
  our_ids <- our_result[["id"]]

  # Sort both by ID for comparison (all rows — respondents and nonrespondents)
  svrep_sorted <- svrep_all_weights[order(svrep_ids)]
  our_sorted <- our_weights[order(our_ids)]

  expect_equal(unname(our_sorted), unname(svrep_sorted), tolerance = 1e-8)
})

# ---------------------------------------------------------------------------
# 5d. Weight conservation WITH by grouping
# ---------------------------------------------------------------------------

test_that("adjust_nonresponse() conserves weight within each by-cell", {
  df <- make_surveywts_data(seed = 10, include_nonrespondents = TRUE)
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
    sum_after <- sum(result[["wts"]][result[["age_group"]] == grp])
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
    class = "surveywts_error_unsupported_class"
  )
  expect_snapshot(
    error = TRUE,
    adjust_nonresponse(m, response_status = x)
  )
})

test_that("adjust_nonresponse() rejects empty data frame (SE-2)", {
  df_empty <- make_surveywts_data(seed = 1)[0, ]

  expect_error(
    adjust_nonresponse(df_empty, response_status = responded),
    class = "surveywts_error_empty_data"
  )
  expect_snapshot(
    error = TRUE,
    adjust_nonresponse(df_empty, response_status = responded)
  )
})

test_that("adjust_nonresponse() rejects survey_replicate input (SE-3)", {
  df <- make_surveywts_data(seed = 1, include_nonrespondents = TRUE)
  rep_design <- .make_test_replicate_nr(df)

  expect_error(
    adjust_nonresponse(rep_design, response_status = responded),
    class = "surveywts_error_replicate_not_supported"
  )
  expect_snapshot(
    error = TRUE,
    adjust_nonresponse(rep_design, response_status = responded)
  )
})

test_that("adjust_nonresponse() rejects missing weight column (SE-4)", {
  df <- make_surveywts_data(seed = 1, include_nonrespondents = TRUE)

  expect_error(
    adjust_nonresponse(df, response_status = responded, weights = no_such_col),
    class = "surveywts_error_weights_not_found"
  )
  expect_snapshot(
    error = TRUE,
    adjust_nonresponse(df, response_status = responded, weights = no_such_col)
  )
})

test_that("adjust_nonresponse() rejects non-numeric weight column (SE-5)", {
  df <- make_surveywts_data(seed = 1, include_nonrespondents = TRUE)
  df$char_wt <- "bad"

  expect_error(
    adjust_nonresponse(df, response_status = responded, weights = char_wt),
    class = "surveywts_error_weights_not_numeric"
  )
  expect_snapshot(
    error = TRUE,
    adjust_nonresponse(df, response_status = responded, weights = char_wt)
  )
})

test_that("adjust_nonresponse() rejects non-positive weights (SE-6)", {
  df <- make_surveywts_data(seed = 1, include_nonrespondents = TRUE)
  df$base_weight[1] <- 0

  expect_error(
    adjust_nonresponse(df, response_status = responded, weights = base_weight),
    class = "surveywts_error_weights_nonpositive"
  )
  expect_snapshot(
    error = TRUE,
    adjust_nonresponse(df, response_status = responded, weights = base_weight)
  )
})

test_that("adjust_nonresponse() rejects NA in weight column (SE-7)", {
  df <- make_surveywts_data(seed = 1, include_nonrespondents = TRUE)
  df$base_weight[1] <- NA_real_

  expect_error(
    adjust_nonresponse(df, response_status = responded, weights = base_weight),
    class = "surveywts_error_weights_na"
  )
  expect_snapshot(
    error = TRUE,
    adjust_nonresponse(df, response_status = responded, weights = base_weight)
  )
})

test_that("adjust_nonresponse() empty_data fires before weights_not_found (SE-8)", {
  df_empty <- make_surveywts_data(seed = 1)[0, ]

  expect_error(
    adjust_nonresponse(df_empty, response_status = responded, weights = no_such_col),
    class = "surveywts_error_empty_data"
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
  df <- make_surveywts_data(seed = 11, include_nonrespondents = TRUE)
  df$age_group[1] <- NA_character_

  expect_error(
    adjust_nonresponse(df, response_status = responded, by = age_group),
    class = "surveywts_error_variable_has_na"
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
  df <- make_surveywts_data(seed = 12, include_nonrespondents = TRUE)
  df$responded[1] <- NA_integer_

  expect_error(
    adjust_nonresponse(df, response_status = responded),
    class = "surveywts_error_response_status_has_na"
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
  df <- make_surveywts_data(seed = 13)  # no responded column

  expect_error(
    adjust_nonresponse(df, response_status = responded),
    class = "surveywts_error_response_status_not_found"
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
  df <- make_surveywts_data(seed = 14)
  df$resp_bad <- c(0L, 1L, 2L, rep(0L, nrow(df) - 3))

  expect_error(
    adjust_nonresponse(df, response_status = resp_bad),
    class = "surveywts_error_response_status_not_binary"
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
  df <- make_surveywts_data(seed = 15)
  df$resp_factor <- factor(c("R", "NR", "R", rep("R", nrow(df) - 3)))

  expect_error(
    adjust_nonresponse(df, response_status = resp_factor),
    class = "surveywts_error_response_status_not_binary"
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
  df <- make_surveywts_data(seed = 16)
  df$responded <- 0L

  expect_error(
    adjust_nonresponse(df, response_status = responded),
    class = "surveywts_error_response_status_all_zero"
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
    class = "surveywts_error_class_cell_empty"
  )
  expect_snapshot(
    error = TRUE,
    adjust_nonresponse(df, response_status = responded, weights = w, by = class)
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
    class = "surveywts_warning_class_near_empty"
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
    class = "surveywts_warning_class_near_empty"
  )
  test_invariants(result)
})

# ---------------------------------------------------------------------------
# 15. Edge — all respondents (no nonrespondents to redistribute)
# ---------------------------------------------------------------------------

test_that("adjust_nonresponse() returns unchanged weights when all are respondents", {
  df <- make_surveywts_data(seed = 19)
  df$responded <- 1L

  result <- adjust_nonresponse(df, response_status = responded)

  test_invariants(result)
  expect_equal(nrow(result), nrow(df))
  # Weights unchanged (adj factor = 1.0 with zero nonrespondents)
  expect_equal(result[["wts"]], rep(1 / nrow(df), nrow(df)), tolerance = 1e-10)
})

# ---------------------------------------------------------------------------
# 16. Edge — single weighting class (equivalent to global)
# ---------------------------------------------------------------------------

test_that("adjust_nonresponse() single by-cell gives same result as global", {
  df <- make_surveywts_data(seed = 20, include_nonrespondents = TRUE)
  df$const_class <- "all"

  result_global <- adjust_nonresponse(df, response_status = responded)
  result_single <- adjust_nonresponse(
    df, response_status = responded, by = const_class
  )

  expect_equal(
    result_global[["wts"]],
    result_single[["wts"]],
    tolerance = 1e-10
  )
})

# ---------------------------------------------------------------------------
# 17. History entry has correct structure
# ---------------------------------------------------------------------------

test_that("adjust_nonresponse() history entry has correct structure", {
  df <- make_surveywts_data(seed = 21, include_nonrespondents = TRUE)

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
    as.character(utils::packageVersion("surveywts"))
  )
})

# ---------------------------------------------------------------------------
# 10c. Error — response_status_not_binary (character column)
# ---------------------------------------------------------------------------

test_that("adjust_nonresponse() rejects character response_status (not binary)", {
  # Covers R/nonresponse.R lines 411-428: "all other types" branch in
  # .validate_response_status_binary() for character input
  df <- make_surveywts_data(seed = 19)
  df$resp_char <- rep(c("yes", "no"), length.out = nrow(df))

  expect_error(
    adjust_nonresponse(df, response_status = resp_char),
    class = "surveywts_error_response_status_not_binary"
  )
  expect_snapshot(
    error = TRUE,
    adjust_nonresponse(df, response_status = resp_char)
  )
})

# ---------------------------------------------------------------------------
# 18. Error — response_status selects multiple columns (eval_select)
# ---------------------------------------------------------------------------

test_that("adjust_nonresponse() rejects response_status selecting multiple columns", {
  df <- make_surveywts_data(seed = 22, include_nonrespondents = TRUE)
  df$responded2 <- df$responded

  expect_error(
    adjust_nonresponse(df, response_status = c(responded, responded2)),
    class = "surveywts_error_response_status_multiple_columns"
  )
  expect_snapshot(
    error = TRUE,
    adjust_nonresponse(df, response_status = c(responded, responded2))
  )
})

# ---------------------------------------------------------------------------
# 19. Zero weights — data.frame happy path (respondent formula unchanged)
# ---------------------------------------------------------------------------

test_that("adjust_nonresponse() sets nonrespondent weights to 0 (data.frame)", {
  df <- data.frame(
    id = 1:10,
    group = c(rep("A", 5), rep("B", 5)),
    responded = c(1L, 1L, 1L, 0L, 0L, 1L, 1L, 0L, 1L, 1L),
    w = rep(2.0, 10),
    stringsAsFactors = FALSE
  )

  result <- adjust_nonresponse(
    df,
    response_status = responded,
    weights = w,
    by = group,
    control = list(min_cell = 0, max_adjust = Inf)
  )

  test_invariants(result)

  # All 10 rows retained

  expect_equal(nrow(result), 10L)

  # Nonrespondent weights are exactly 0
  nr_mask <- df$responded == 0L
  expect_identical(result[["wts"]][nr_mask], c(0, 0, 0))

  # Respondent weights match the adjustment formula:
  #   Group A: sum_all = 5*2=10, sum_resp = 3*2=6, adj = 10/6
  #   Group B: sum_all = 5*2=10, sum_resp = 4*2=8, adj = 10/8
  resp_a <- result[result[["group"]] == "A" & result[["responded"]] == 1L, ]
  resp_b <- result[result[["group"]] == "B" & result[["responded"]] == 1L, ]
  expect_equal(resp_a[["wts"]], rep(2.0 * 10 / 6, 3), tolerance = 1e-10)
  expect_equal(resp_b[["wts"]], rep(2.0 * 10 / 8, 4), tolerance = 1e-10)
})

# ---------------------------------------------------------------------------
# 20. Zero weights — survey_nonprob happy path (metadata preserved)
# ---------------------------------------------------------------------------

test_that("adjust_nonresponse() preserves survey_nonprob metadata with zero weights", {
  df <- make_surveywts_data(seed = 30, include_nonrespondents = TRUE)

  meta <- surveycore::survey_metadata()
  snp <- surveycore::survey_nonprob(
    data = df,
    variables = list(
      ids = NULL, strata = NULL, fpc = NULL,
      weights = "base_weight", nest = FALSE
    ),
    metadata = meta,
    groups = character(0),
    call = NULL,
    calibration = NULL
  )

  result <- adjust_nonresponse(snp, response_status = responded)

  test_invariants(result)
  expect_true(S7::S7_inherits(result, surveycore::survey_nonprob))

  # All rows retained
  expect_equal(nrow(result@data), nrow(df))

  # Nonrespondent weights = 0, respondent weights > 0
  wt_col <- result@variables$weights
  is_resp <- df$responded == 1L
  expect_true(all(result@data[[wt_col]][!is_resp] == 0))
  expect_true(all(result@data[[wt_col]][is_resp] > 0))

  # @variables preserved (except the weight values in @data)
  expect_identical(result@variables$weights, snp@variables$weights)
  expect_identical(result@variables$ids, snp@variables$ids)
  expect_identical(result@variables$strata, snp@variables$strata)

  # Weighting history appended
  expect_true(length(result@metadata@weighting_history) >= 1L)
  last_entry <- result@metadata@weighting_history[[
    length(result@metadata@weighting_history)
  ]]
  expect_identical(last_entry$operation, "nonresponse_weighting_class")
})

# ---------------------------------------------------------------------------
# 21. Re-calibration of post-nonresponse data correctly errors
# ---------------------------------------------------------------------------

test_that("calibrate() rejects post-nonresponse data with zero weights", {
  df <- data.frame(
    id = 1:10,
    group = c(rep("A", 5), rep("B", 5)),
    responded = c(1L, 1L, 1L, 0L, 0L, 1L, 1L, 0L, 1L, 1L),
    w = rep(2.0, 10),
    stringsAsFactors = FALSE
  )

  nr_result <- adjust_nonresponse(
    df,
    response_status = responded,
    weights = w,
    control = list(min_cell = 0, max_adjust = Inf)
  )

  # Attempting to calibrate with zero-weight rows should fail
  pop <- list(group = c("A" = 0.5, "B" = 0.5))

  expect_error(
    calibrate_greg(nr_result, targets = pop),
    class = "surveywts_error_weights_nonpositive"
  )
})

# ---------------------------------------------------------------------------
# wt_name — validation error tests
# ---------------------------------------------------------------------------

test_that("adjust_nonresponse() rejects non-character wt_name", {
  df <- make_surveywts_data(seed = 1, include_nonrespondents = TRUE)
  expect_error(
    adjust_nonresponse(df, response_status = responded, wt_name = 42),
    class = "surveywts_error_wt_name_not_scalar"
  )
  expect_snapshot(
    error = TRUE,
    adjust_nonresponse(df, response_status = responded, wt_name = 42)
  )
})

test_that("adjust_nonresponse() rejects empty wt_name", {
  df <- make_surveywts_data(seed = 1, include_nonrespondents = TRUE)
  expect_error(
    adjust_nonresponse(df, response_status = responded, wt_name = ""),
    class = "surveywts_error_wt_name_empty"
  )
  expect_snapshot(
    error = TRUE,
    adjust_nonresponse(df, response_status = responded, wt_name = "")
  )
})

test_that("adjust_nonresponse() rejects NA wt_name", {
  df <- make_surveywts_data(seed = 1, include_nonrespondents = TRUE)
  expect_error(
    adjust_nonresponse(
      df, response_status = responded, wt_name = NA_character_
    ),
    class = "surveywts_error_wt_name_empty"
  )
  expect_snapshot(
    error = TRUE,
    adjust_nonresponse(
      df, response_status = responded, wt_name = NA_character_
    )
  )
})

# ---------------------------------------------------------------------------
# wt_name — happy path tests
# ---------------------------------------------------------------------------

test_that("adjust_nonresponse() names output weight column 'wts' by default", {
  df <- make_surveywts_data(seed = 1, include_nonrespondents = TRUE)
  result <- adjust_nonresponse(df, response_status = responded)
  test_invariants(result)
  expect_identical(attr(result, "weight_col"), "wts")
  expect_true("wts" %in% names(result))
})

test_that("adjust_nonresponse() uses custom wt_name for output column", {
  df <- make_surveywts_data(seed = 1, include_nonrespondents = TRUE)
  result <- adjust_nonresponse(
    df, response_status = responded, wt_name = "nr_wt"
  )
  test_invariants(result)
  expect_identical(attr(result, "weight_col"), "nr_wt")
  expect_true("nr_wt" %in% names(result))
})

# ---------------------------------------------------------------------------
# wt_name — input preservation and overwrite tests
# ---------------------------------------------------------------------------

test_that("adjust_nonresponse() preserves input weight column when wt_name differs", {
  df <- make_surveywts_data(seed = 1, include_nonrespondents = TRUE)
  result <- adjust_nonresponse(
    df, response_status = responded,
    weights = base_weight, wt_name = "nr_wt"
  )
  test_invariants(result)
  expect_true("base_weight" %in% names(result))
  expect_true("nr_wt" %in% names(result))
  expect_identical(attr(result, "weight_col"), "nr_wt")
})

test_that("adjust_nonresponse() overwrites input column when wt_name matches", {
  df <- make_surveywts_data(seed = 1, include_nonrespondents = TRUE)
  result <- adjust_nonresponse(
    df, response_status = responded,
    weights = base_weight, wt_name = "base_weight"
  )
  test_invariants(result)
  expect_identical(attr(result, "weight_col"), "base_weight")
  expect_false(identical(result[["base_weight"]], df[["base_weight"]]))
})

# ---------------------------------------------------------------------------
# wt_name — no phantom column test (Rule 1b)
# ---------------------------------------------------------------------------

test_that("adjust_nonresponse() has no phantom column when weights = NULL + custom wt_name", {
  df <- make_surveywts_data(seed = 1, include_nonrespondents = TRUE)
  result <- adjust_nonresponse(
    df, response_status = responded, wt_name = "nr_wt"
  )
  test_invariants(result)
  expect_true("nr_wt" %in% names(result))
  expect_false(".weight" %in% names(result))
  expected_cols <- c(names(df), "nr_wt")
  expect_true(all(names(result) %in% expected_cols))
})

# ---------------------------------------------------------------------------
# wt_name — survey object ignore test
# ---------------------------------------------------------------------------

test_that("adjust_nonresponse() ignores wt_name for survey_nonprob input", {
  df <- make_surveywts_data(seed = 1, include_nonrespondents = TRUE)
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
  result <- adjust_nonresponse(
    snp, response_status = responded, wt_name = "ignored_name"
  )
  expect_identical(result@variables$weights, snp@variables$weights)
})

# ---------------------------------------------------------------------------
# wt_name — weighted_df input tests
# ---------------------------------------------------------------------------

test_that("adjust_nonresponse() preserves old weight col and creates 'wts' for weighted_df input", {
  df <- make_surveywts_data(seed = 1, include_nonrespondents = TRUE)
  wdf <- .make_weighted_df(df, "base_weight", list())
  result <- adjust_nonresponse(wdf, response_status = responded)
  test_invariants(result)
  expect_true("base_weight" %in% names(result))
  expect_true("wts" %in% names(result))
  expect_identical(attr(result, "weight_col"), "wts")
})

test_that("adjust_nonresponse() overwrites weight col when wt_name matches weighted_df attr", {
  df <- make_surveywts_data(seed = 1, include_nonrespondents = TRUE)
  wdf <- .make_weighted_df(df, "base_weight", list())
  result <- adjust_nonresponse(
    wdf, response_status = responded, wt_name = "base_weight"
  )
  test_invariants(result)
  expect_identical(attr(result, "weight_col"), "base_weight")
})

# ---------------------------------------------------------------------------
# wt_name — nonrespondent weights correctly in wt_name column
# ---------------------------------------------------------------------------

test_that("adjust_nonresponse() sets nonrespondent weights to 0 in wt_name column", {
  df <- make_surveywts_data(seed = 1, include_nonrespondents = TRUE)
  result <- adjust_nonresponse(
    df, response_status = responded, wt_name = "nr_wt"
  )
  is_resp <- df$responded == 1L
  expect_true(all(result[["nr_wt"]][!is_resp] == 0))
  expect_true(all(result[["nr_wt"]][is_resp] > 0))
})

# ---------------------------------------------------------------------------
# wt_name — history test
# ---------------------------------------------------------------------------

test_that("adjust_nonresponse() records wt_name in weighting history", {
  df <- make_surveywts_data(seed = 1, include_nonrespondents = TRUE)
  result <- adjust_nonresponse(
    df, response_status = responded, wt_name = "nr_wt"
  )
  history <- attr(result, "weighting_history")
  expect_identical(history[[length(history)]]$weight_col, "nr_wt")
})

# ===========================================================================
# redistribute_weights() tests
# ===========================================================================

# ---------------------------------------------------------------------------
# RW-1. Happy path — data.frame input → weighted_df (all rows retained)
# ---------------------------------------------------------------------------

test_that("redistribute_weights() with data.frame input returns weighted_df", {
  df <- make_surveywts_data(seed = 20, include_nonrespondents = TRUE)
  df$reduce_col   <- 1L - df$responded
  df$increase_col <- df$responded

  result <- redistribute_weights(df, reduce_if = reduce_col, increase_if = increase_col)

  test_invariants(result)
  expect_true(inherits(result, "weighted_df"))
  expect_equal(nrow(result), nrow(df))
  expect_true(all(result[["wts"]][df$reduce_col == 1L] == 0))
  expect_true(all(result[["wts"]][df$increase_col == 1L] > 0))
})

# ---------------------------------------------------------------------------
# RW-2. Happy path — weighted_df input → weighted_df
# ---------------------------------------------------------------------------

test_that("redistribute_weights() with weighted_df input returns weighted_df", {
  df <- make_surveywts_data(seed = 21, include_nonrespondents = TRUE)
  df$reduce_col   <- 1L - df$responded
  df$increase_col <- df$responded
  wdf <- .make_weighted_df(df, "base_weight", list())

  result <- redistribute_weights(wdf, reduce_if = reduce_col, increase_if = increase_col)

  test_invariants(result)
  expect_true(inherits(result, "weighted_df"))
  expect_equal(nrow(result), nrow(wdf))
})

# ---------------------------------------------------------------------------
# RW-3. Happy path — survey_nonprob input → survey_nonprob (reduce_if rows filtered)
# ---------------------------------------------------------------------------

test_that("redistribute_weights() with survey_nonprob input returns survey_nonprob", {
  df <- make_surveywts_data(seed = 22, include_nonrespondents = TRUE)
  df$reduce_col   <- 1L - df$responded
  df$increase_col <- df$responded

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

  result <- redistribute_weights(snp, reduce_if = reduce_col, increase_if = increase_col)

  test_invariants(result)
  expect_true(S7::S7_inherits(result, surveycore::survey_nonprob))
  n_reduce <- sum(df$reduce_col == 1L)
  expect_equal(nrow(result@data), nrow(df) - n_reduce)
  expect_true(all(result@data[[result@variables$weights]] > 0))
})

# ---------------------------------------------------------------------------
# RW-4. Happy path — survey_taylor input → survey_taylor (reduce_if rows filtered)
# ---------------------------------------------------------------------------

test_that("redistribute_weights() with survey_taylor input returns survey_taylor, respondents only", {
  df <- make_surveywts_data(seed = 23, include_nonrespondents = TRUE)
  df$reduce_col   <- 1L - df$responded
  df$increase_col <- df$responded
  design <- .make_test_taylor_nr(df)

  result <- redistribute_weights(design, reduce_if = reduce_col, increase_if = increase_col)

  test_invariants(result)
  expect_true(S7::S7_inherits(result, surveycore::survey_taylor))
  expect_false(S7::S7_inherits(result, surveycore::survey_nonprob))
  n_reduce <- sum(df$reduce_col == 1L)
  expect_equal(nrow(result@data), nrow(df) - n_reduce)
  expect_true(all(result@data[[result@variables$weights]] > 0))
})

# ---------------------------------------------------------------------------
# RW-5. Happy path — by = NULL performs global redistribution
# ---------------------------------------------------------------------------

test_that("redistribute_weights() with by = NULL performs global redistribution", {
  n <- 100L
  df <- data.frame(
    wt         = rep(1, n),
    reduce_col  = c(rep(1L, 20L), rep(0L, 80L)),
    increase_col = c(rep(0L, 20L), rep(1L, 80L))
  )

  result <- redistribute_weights(
    df,
    reduce_if  = reduce_col,
    increase_if = increase_col,
    weights    = wt
  )

  w_new <- result[["wts"]]
  # W_total = 100, W_increase = 80; factor = 100/80 = 1.25
  expected_wt <- n / 80L
  expect_equal(unique(w_new[df$increase_col == 1L]), expected_wt, tolerance = 1e-10)
  expect_true(all(w_new[df$reduce_col == 1L] == 0))
})

# ---------------------------------------------------------------------------
# RW-6. Happy path — by groups processed independently
# ---------------------------------------------------------------------------

test_that("redistribute_weights() with by groups processes each group independently", {
  df <- data.frame(
    grp        = c(rep("A", 10L), rep("B", 10L)),
    wt         = rep(1, 20L),
    reduce_col  = c(rep(1L, 3L), rep(0L, 7L), rep(1L, 4L), rep(0L, 6L)),
    increase_col = c(rep(0L, 3L), rep(1L, 7L), rep(0L, 4L), rep(1L, 6L))
  )

  result <- redistribute_weights(
    df,
    reduce_if  = reduce_col,
    increase_if = increase_col,
    weights    = wt,
    by         = grp,
    control    = list(min_cell = 1L)  # suppress sparse-cell warning; not testing that here
  )

  w_new <- result[["wts"]]
  for (g in c("A", "B")) {
    idx_all  <- df$grp == g
    idx_resp <- idx_all & df$increase_col == 1L
    expect_equal(sum(w_new[idx_resp]), sum(df$wt[idx_all]), tolerance = 1e-10)
  }
})

# ---------------------------------------------------------------------------
# RW-7. Happy path — rows matching neither indicator have unchanged weights
# ---------------------------------------------------------------------------

test_that("redistribute_weights() rows matching neither indicator have unchanged weights", {
  df <- data.frame(
    wt         = c(1, 2, 3, 4, 5),
    reduce_col  = c(1L, 0L, 0L, 0L, 0L),
    increase_col = c(0L, 1L, 0L, 0L, 0L)
  )

  result <- redistribute_weights(
    df,
    reduce_if  = reduce_col,
    increase_if = increase_col,
    weights    = wt,
    control    = list(min_cell = 1L)  # suppress sparse-cell warning; not testing that here
  )

  neither_idx <- df$reduce_col == 0L & df$increase_col == 0L
  expect_equal(result[["wts"]][neither_idx], df$wt[neither_idx], tolerance = 1e-10)
})

# ---------------------------------------------------------------------------
# RW-8. Numerical correctness — matches adjust_nonresponse() for equivalent inputs
# ---------------------------------------------------------------------------

test_that("redistribute_weights() result matches adjust_nonresponse() weighting-class for equivalent inputs", {
  df <- make_surveywts_data(seed = 27, include_nonrespondents = TRUE)
  df$reduce_col   <- 1L - df$responded
  df$increase_col <- df$responded

  result_rw <- redistribute_weights(
    df,
    reduce_if  = reduce_col,
    increase_if = increase_col,
    weights    = base_weight,
    wt_name    = "wts"
  )
  result_adj <- adjust_nonresponse(df, response_status = responded, weights = base_weight)

  resp_idx    <- df$responded == 1L
  nonresp_idx <- df$responded == 0L
  expect_equal(result_rw[["wts"]][resp_idx], result_adj[["wts"]][resp_idx], tolerance = 1e-10)
  expect_true(all(result_rw[["wts"]][nonresp_idx] == 0))
  expect_true(all(result_adj[["wts"]][nonresp_idx] == 0))
})

# ---------------------------------------------------------------------------
# RW-9. Error — survey_replicate input
# ---------------------------------------------------------------------------

test_that("redistribute_weights() errors for survey_replicate input", {
  rsd <- make_replicate_design(seed = 30)

  expect_error(
    redistribute_weights(rsd, reduce_if = x, increase_if = y),
    class = "surveywts_error_replicate_not_supported"
  )
  expect_snapshot(
    error = TRUE,
    redistribute_weights(rsd, reduce_if = x, increase_if = y)
  )
})

# ---------------------------------------------------------------------------
# RW-10. Error — 0-row data frame
# ---------------------------------------------------------------------------

test_that("redistribute_weights() errors for 0-row data frame", {
  empty_df <- data.frame(
    wt = numeric(0), reduce_col = integer(0), increase_col = integer(0)
  )

  expect_error(
    redistribute_weights(empty_df, reduce_if = reduce_col, increase_if = increase_col, weights = wt),
    class = "surveywts_error_empty_data"
  )
  expect_snapshot(
    error = TRUE,
    redistribute_weights(empty_df, reduce_if = reduce_col, increase_if = increase_col, weights = wt)
  )
})

# ---------------------------------------------------------------------------
# RW-11. Error — named weight column is missing
# ---------------------------------------------------------------------------

test_that("redistribute_weights() errors when named weight column is missing", {
  df <- data.frame(
    reduce_col = 0L, increase_col = 1L
  )

  expect_error(
    redistribute_weights(df, reduce_if = reduce_col, increase_if = increase_col, weights = no_such_col),
    class = "surveywts_error_weights_not_found"
  )
  expect_snapshot(
    error = TRUE,
    redistribute_weights(df, reduce_if = reduce_col, increase_if = increase_col, weights = no_such_col)
  )
})

# ---------------------------------------------------------------------------
# RW-12. Error — weight column is not numeric
# ---------------------------------------------------------------------------

test_that("redistribute_weights() errors when weight column is not numeric", {
  df <- data.frame(
    wt = c("a", "b", "c"),
    reduce_col  = c(1L, 0L, 0L),
    increase_col = c(0L, 1L, 0L)
  )

  expect_error(
    redistribute_weights(df, reduce_if = reduce_col, increase_if = increase_col, weights = wt),
    class = "surveywts_error_weights_not_numeric"
  )
  expect_snapshot(
    error = TRUE,
    redistribute_weights(df, reduce_if = reduce_col, increase_if = increase_col, weights = wt)
  )
})

# ---------------------------------------------------------------------------
# RW-13. Error — weight column has non-positive values
# ---------------------------------------------------------------------------

test_that("redistribute_weights() errors when weight column has non-positive values", {
  df <- data.frame(
    wt = c(-1, 1, 1),
    reduce_col  = c(1L, 0L, 0L),
    increase_col = c(0L, 1L, 1L)
  )

  expect_error(
    redistribute_weights(df, reduce_if = reduce_col, increase_if = increase_col, weights = wt),
    class = "surveywts_error_weights_nonpositive"
  )
  expect_snapshot(
    error = TRUE,
    redistribute_weights(df, reduce_if = reduce_col, increase_if = increase_col, weights = wt)
  )
})

# ---------------------------------------------------------------------------
# RW-14. Error — weight column has NA
# ---------------------------------------------------------------------------

test_that("redistribute_weights() errors when weight column has NA", {
  df <- data.frame(
    wt = c(NA_real_, 1, 1),
    reduce_col  = c(1L, 0L, 0L),
    increase_col = c(0L, 1L, 1L)
  )

  expect_error(
    redistribute_weights(df, reduce_if = reduce_col, increase_if = increase_col, weights = wt),
    class = "surveywts_error_weights_na"
  )
  expect_snapshot(
    error = TRUE,
    redistribute_weights(df, reduce_if = reduce_col, increase_if = increase_col, weights = wt)
  )
})

# ---------------------------------------------------------------------------
# RW-15. Error — wt_name is not character(1)
# ---------------------------------------------------------------------------

test_that("redistribute_weights() errors when wt_name is not character(1)", {
  df <- data.frame(
    wt = 1, reduce_col = 1L, increase_col = 0L
  )

  expect_error(
    redistribute_weights(df, reduce_if = reduce_col, increase_if = increase_col, weights = wt, wt_name = 42),
    class = "surveywts_error_wt_name_not_scalar"
  )
  expect_snapshot(
    error = TRUE,
    redistribute_weights(df, reduce_if = reduce_col, increase_if = increase_col, weights = wt, wt_name = 42)
  )
})

# ---------------------------------------------------------------------------
# RW-16. Error — wt_name is NA or empty string
# ---------------------------------------------------------------------------

test_that("redistribute_weights() errors when wt_name is NA or empty string", {
  df <- data.frame(
    wt = 1, reduce_col = 1L, increase_col = 0L
  )

  expect_error(
    redistribute_weights(df, reduce_if = reduce_col, increase_if = increase_col, weights = wt, wt_name = ""),
    class = "surveywts_error_wt_name_empty"
  )
  expect_snapshot(
    error = TRUE,
    redistribute_weights(df, reduce_if = reduce_col, increase_if = increase_col, weights = wt, wt_name = "")
  )
  expect_error(
    redistribute_weights(df, reduce_if = reduce_col, increase_if = increase_col, weights = wt, wt_name = NA_character_),
    class = "surveywts_error_wt_name_empty"
  )
})

# ---------------------------------------------------------------------------
# RW-17. Error — wt_name conflicts with existing non-weight column
# ---------------------------------------------------------------------------

test_that("redistribute_weights() errors when wt_name conflicts with an existing non-weight column", {
  df <- make_surveywts_data(seed = 31, include_nonrespondents = TRUE)
  df$reduce_col   <- 1L - df$responded
  df$increase_col <- df$responded

  # "age_group" is an existing non-weight column; using it as wt_name should error
  expect_error(
    redistribute_weights(
      df,
      reduce_if  = reduce_col,
      increase_if = increase_col,
      wt_name    = "age_group"
    ),
    class = "surveywts_error_wt_name_conflict"
  )
  expect_snapshot(
    error = TRUE,
    redistribute_weights(
      df,
      reduce_if  = reduce_col,
      increase_if = increase_col,
      wt_name    = "age_group"
    )
  )
})

# ---------------------------------------------------------------------------
# RW-18. Error — reduce_if column not found
# ---------------------------------------------------------------------------

test_that("redistribute_weights() errors when reduce_if column is not found", {
  df <- make_surveywts_data(seed = 32, include_nonrespondents = TRUE)
  df$increase_col <- df$responded

  expect_error(
    redistribute_weights(df, reduce_if = no_such_col, increase_if = increase_col),
    class = "surveywts_error_reduce_if_not_found"
  )
  expect_snapshot(
    error = TRUE,
    redistribute_weights(df, reduce_if = no_such_col, increase_if = increase_col)
  )
})

# ---------------------------------------------------------------------------
# RW-19. Error — increase_if column not found
# ---------------------------------------------------------------------------

test_that("redistribute_weights() errors when increase_if column is not found", {
  df <- make_surveywts_data(seed = 33, include_nonrespondents = TRUE)
  df$reduce_col <- 1L - df$responded

  expect_error(
    redistribute_weights(df, reduce_if = reduce_col, increase_if = no_such_col),
    class = "surveywts_error_increase_if_not_found"
  )
  expect_snapshot(
    error = TRUE,
    redistribute_weights(df, reduce_if = reduce_col, increase_if = no_such_col)
  )
})

# ---------------------------------------------------------------------------
# RW-20. Error — reduce_if is not binary (factor input)
# ---------------------------------------------------------------------------

test_that("redistribute_weights() errors when reduce_if is not binary (factor input)", {
  df <- make_surveywts_data(seed = 34, include_nonrespondents = TRUE)
  df$reduce_col   <- factor(1L - df$responded)
  df$increase_col <- df$responded

  expect_error(
    redistribute_weights(df, reduce_if = reduce_col, increase_if = increase_col),
    class = "surveywts_error_reduce_if_not_binary"
  )
  expect_snapshot(
    error = TRUE,
    redistribute_weights(df, reduce_if = reduce_col, increase_if = increase_col)
  )
})

# ---------------------------------------------------------------------------
# RW-21. Error — increase_if is not binary (character input)
# ---------------------------------------------------------------------------

test_that("redistribute_weights() errors when increase_if is not binary (character input)", {
  df <- make_surveywts_data(seed = 35, include_nonrespondents = TRUE)
  df$reduce_col   <- 1L - df$responded
  df$increase_col <- as.character(df$responded)

  expect_error(
    redistribute_weights(df, reduce_if = reduce_col, increase_if = increase_col),
    class = "surveywts_error_increase_if_not_binary"
  )
  expect_snapshot(
    error = TRUE,
    redistribute_weights(df, reduce_if = reduce_col, increase_if = increase_col)
  )
})

# ---------------------------------------------------------------------------
# RW-22. Error — reduce_if has NA values
# ---------------------------------------------------------------------------

test_that("redistribute_weights() errors when reduce_if has NA values", {
  df <- make_surveywts_data(seed = 36, include_nonrespondents = TRUE)
  df$reduce_col   <- 1L - df$responded
  df$reduce_col[1L] <- NA_integer_
  df$increase_col <- df$responded

  expect_error(
    redistribute_weights(df, reduce_if = reduce_col, increase_if = increase_col),
    class = "surveywts_error_reduce_if_has_na"
  )
  expect_snapshot(
    error = TRUE,
    redistribute_weights(df, reduce_if = reduce_col, increase_if = increase_col)
  )
})

# ---------------------------------------------------------------------------
# RW-23. Error — increase_if has NA values
# ---------------------------------------------------------------------------

test_that("redistribute_weights() errors when increase_if has NA values", {
  df <- make_surveywts_data(seed = 37, include_nonrespondents = TRUE)
  df$reduce_col   <- 1L - df$responded
  df$increase_col <- df$responded
  df$increase_col[1L] <- NA_integer_

  expect_error(
    redistribute_weights(df, reduce_if = reduce_col, increase_if = increase_col),
    class = "surveywts_error_increase_if_has_na"
  )
  expect_snapshot(
    error = TRUE,
    redistribute_weights(df, reduce_if = reduce_col, increase_if = increase_col)
  )
})

# ---------------------------------------------------------------------------
# RW-24. Error — reduce_if and increase_if overlap
# ---------------------------------------------------------------------------

test_that("redistribute_weights() errors when reduce_if and increase_if overlap", {
  df <- data.frame(
    wt          = c(1, 1, 1, 1, 1),
    reduce_col  = c(1L, 1L, 0L, 0L, 0L),
    increase_col = c(1L, 0L, 1L, 1L, 1L)  # row 1: both 1 → overlap
  )

  expect_error(
    redistribute_weights(df, reduce_if = reduce_col, increase_if = increase_col, weights = wt),
    class = "surveywts_error_indicators_overlap"
  )
  expect_snapshot(
    error = TRUE,
    redistribute_weights(df, reduce_if = reduce_col, increase_if = increase_col, weights = wt)
  )
})

# ---------------------------------------------------------------------------
# RW-25. Error — group has no increase_if rows
# ---------------------------------------------------------------------------

test_that("redistribute_weights() errors when a group has no increase_if rows", {
  df <- data.frame(
    wt          = rep(1, 5L),
    reduce_col  = rep(1L, 5L),   # everyone is reduce_if
    increase_col = rep(0L, 5L)   # nobody is increase_if
  )

  expect_error(
    redistribute_weights(df, reduce_if = reduce_col, increase_if = increase_col, weights = wt),
    class = "surveywts_error_no_recipients_in_group"
  )
  expect_snapshot(
    error = TRUE,
    redistribute_weights(df, reduce_if = reduce_col, increase_if = increase_col, weights = wt)
  )
})

# ---------------------------------------------------------------------------
# RW-26. Error — by variable has NA values
# ---------------------------------------------------------------------------

test_that("redistribute_weights() errors when a by variable has NA values", {
  df <- make_surveywts_data(seed = 38, include_nonrespondents = TRUE)
  df$reduce_col   <- 1L - df$responded
  df$increase_col <- df$responded
  df$age_group[1L] <- NA_character_

  expect_error(
    redistribute_weights(df, reduce_if = reduce_col, increase_if = increase_col, by = age_group),
    class = "surveywts_error_variable_has_na"
  )
  expect_snapshot(
    error = TRUE,
    redistribute_weights(df, reduce_if = reduce_col, increase_if = increase_col, by = age_group)
  )
})

# ---------------------------------------------------------------------------
# RW-27. Warning — group has fewer than min_cell increase_if respondents
# ---------------------------------------------------------------------------

test_that("redistribute_weights() warns when a group has fewer than min_cell recipients", {
  df <- data.frame(
    wt          = rep(1, 25L),
    reduce_col  = c(rep(1L, 22L), rep(0L, 3L)),
    increase_col = c(rep(0L, 22L), rep(1L, 3L))  # 3 recipients < min_cell default of 20
  )

  expect_warning(
    result <- redistribute_weights(
      df,
      reduce_if  = reduce_col,
      increase_if = increase_col,
      weights    = wt
    ),
    class = "surveywts_warning_class_near_empty"
  )
  test_invariants(result)
})

# ---------------------------------------------------------------------------
# RW-28. Warning — adjustment factor exceeds max_adjust
# ---------------------------------------------------------------------------

test_that("redistribute_weights() warns when adjustment factor exceeds max_adjust", {
  # 30 reduce rows (wt=10 each) and 30 increase rows (wt=1 each)
  # W_total = 330, W_increase = 30; factor = 330/30 = 11 > 2.0
  df <- data.frame(
    wt          = c(rep(10, 30L), rep(1, 30L)),
    reduce_col  = c(rep(1L, 30L), rep(0L, 30L)),
    increase_col = c(rep(0L, 30L), rep(1L, 30L))
  )

  expect_warning(
    result <- redistribute_weights(
      df,
      reduce_if  = reduce_col,
      increase_if = increase_col,
      weights    = wt,
      control    = list(min_cell = 1L)  # suppress sparse warning; only want factor warning
    ),
    class = "surveywts_warning_class_near_empty"
  )
  test_invariants(result)
})

# ---------------------------------------------------------------------------
# RW-29. Edge case — no reduce_if rows: weights unchanged, no error
# ---------------------------------------------------------------------------

test_that("redistribute_weights() with no reduce_if rows leaves weights unchanged", {
  df <- make_surveywts_data(seed = 39, include_nonrespondents = TRUE)
  df$reduce_col   <- 0L  # nobody is reduced
  df$increase_col <- df$responded

  result <- redistribute_weights(df, reduce_if = reduce_col, increase_if = increase_col)

  # No redistribution needed — all weights should be unchanged in output
  # (uniform weights since weights = NULL for plain df)
  expect_true(inherits(result, "weighted_df"))
  test_invariants(result)
  # All rows retained
  expect_equal(nrow(result), nrow(df))
})

# ---------------------------------------------------------------------------
# RW-30. Edge case — zero-weight rows in increase_if caught by weight validator
# ---------------------------------------------------------------------------

test_that("redistribute_weights() handles zero-weight rows in increase_if", {
  df <- data.frame(
    wt          = c(1, 0, 1, 1, 1),  # row 2 has zero weight → error
    reduce_col  = c(1L, 0L, 0L, 0L, 0L),
    increase_col = c(0L, 1L, 1L, 1L, 1L)
  )

  # Zero weights caught by weight validator before redistribution logic
  expect_error(
    redistribute_weights(df, reduce_if = reduce_col, increase_if = increase_col, weights = wt),
    class = "surveywts_error_weights_nonpositive"
  )
})

# ---------------------------------------------------------------------------
# RW-31. Edge case — with by: one group all-reduce triggers error
# ---------------------------------------------------------------------------

test_that("redistribute_weights() with by: one group all-reduce triggers error, other groups succeed", {
  df <- data.frame(
    grp         = c("A", "A", "A", "B", "B"),
    wt          = rep(1, 5L),
    reduce_col  = c(0L, 0L, 0L, 1L, 1L),  # group B: all reduce, no increase
    increase_col = c(1L, 1L, 1L, 0L, 0L)
  )

  expect_error(
    redistribute_weights(
      df,
      reduce_if  = reduce_col,
      increase_if = increase_col,
      weights    = wt,
      by         = grp
    ),
    class = "surveywts_error_no_recipients_in_group"
  )
  expect_snapshot(
    error = TRUE,
    redistribute_weights(
      df,
      reduce_if  = reduce_col,
      increase_if = increase_col,
      weights    = wt,
      by         = grp
    )
  )
})

# ---------------------------------------------------------------------------
# RW-32. Edge case — history step correct when chained after prior operation
# ---------------------------------------------------------------------------

test_that("redistribute_weights() history step number is correct when chained after calibration", {
  df <- make_surveywts_data(seed = 40, include_nonrespondents = TRUE)
  df$reduce_col   <- 1L - df$responded
  df$increase_col <- df$responded

  # Simulate a weighted_df with one prior history step (e.g., from calibrate())
  prior_entry <- list(step = 1L, operation = "calibration")
  wdf <- .make_weighted_df(df, "base_weight", list(prior_entry))

  result <- redistribute_weights(wdf, reduce_if = reduce_col, increase_if = increase_col)

  history <- attr(result, "weighting_history")
  expect_equal(length(history), 2L)
  expect_equal(history[[2L]]$step, 2L)
  expect_identical(history[[2L]]$operation, "redistribute_weights")
})

# ===========================================================================
# adjust_nonresponse() — propensity-cell method
# ===========================================================================

# ---------------------------------------------------------------------------
# PC-1. Happy path — data.frame input → weighted_df
# ---------------------------------------------------------------------------

test_that("adjust_nonresponse(method='propensity-cell') returns weighted_df for data.frame input", {
  df <- make_surveywts_data(seed = 50, include_nonrespondents = TRUE)

  result <- adjust_nonresponse(
    df,
    response_status = responded,
    formula = ~age_group,
    method = "propensity-cell"
  )

  expect_true(inherits(result, "weighted_df"))
  test_invariants(result)
  expect_equal(nrow(result), nrow(df))
})

# ---------------------------------------------------------------------------
# PC-2. Happy path — nonrespondent weights are 0
# ---------------------------------------------------------------------------

test_that("adjust_nonresponse(method='propensity-cell') sets nonrespondent weights to 0", {
  df <- make_surveywts_data(seed = 51, include_nonrespondents = TRUE)
  is_resp <- df$responded == 1L

  result <- adjust_nonresponse(
    df,
    response_status = responded,
    formula = ~age_group,
    method = "propensity-cell"
  )

  wt_col <- attr(result, "weight_col")
  expect_true(all(result[[wt_col]][!is_resp] == 0))
  expect_true(all(result[[wt_col]][is_resp] > 0))
})

# ---------------------------------------------------------------------------
# PC-3. Happy path — history entry operation is 'nonresponse_propensity_cell'
# ---------------------------------------------------------------------------

test_that("adjust_nonresponse(method='propensity-cell') history entry has operation = 'nonresponse_propensity_cell'", {
  df <- make_surveywts_data(seed = 52, include_nonrespondents = TRUE)

  result <- adjust_nonresponse(
    df,
    response_status = responded,
    formula = ~age_group,
    method = "propensity-cell"
  )

  history <- attr(result, "weighting_history")
  expect_equal(length(history), 1L)
  expect_identical(history[[1L]]$operation, "nonresponse_propensity_cell")
})

# ---------------------------------------------------------------------------
# PC-4. Happy path — survey_taylor input → survey_taylor (respondent rows only)
# ---------------------------------------------------------------------------

test_that("adjust_nonresponse(method='propensity-cell') returns survey_taylor for survey_taylor input", {
  df <- make_surveywts_data(seed = 53, include_nonrespondents = TRUE)
  design <- .make_test_taylor_nr(df)

  result <- adjust_nonresponse(
    design,
    response_status = responded,
    formula = ~age_group,
    method = "propensity-cell"
  )

  expect_true(S7::S7_inherits(result, surveycore::survey_taylor))
  test_invariants(result)
  # survey_taylor does not support zero weights — respondent rows only returned
  expect_true(nrow(result@data) < nrow(df))
  expect_true(all(result@data[[result@variables$weights]] > 0))
})

# ---------------------------------------------------------------------------
# PC-5. Numerical correctness — within-cell weight sums are conserved
# ---------------------------------------------------------------------------

test_that("propensity-cell respondent weights within each cell scale correctly", {
  df <- make_surveywts_data(seed = 54, include_nonrespondents = TRUE)
  # Uniform weights: what adjust_nonresponse() uses internally for a plain
  # data.frame with no explicit weights argument
  old_wts <- rep(1 / nrow(df), nrow(df))
  is_resp <- df$responded == 1L

  result <- adjust_nonresponse(
    df,
    response_status = responded,
    formula = ~age_group,
    method = "propensity-cell"
  )
  new_wts <- result[[attr(result, "weight_col")]]

  # Replicate propensity scores and cell assignment to verify per-cell scaling
  model  <- stats::glm(responded ~ age_group, family = stats::binomial,
                       data = df, weights = old_wts)
  scores <- stats::predict(model, type = "response")
  n_cells <- 5L  # default
  cuts    <- stats::quantile(scores, probs = seq(0, 1, 1 / n_cells))
  cells   <- findInterval(scores, cuts, rightmost.closed = TRUE)

  for (k in seq_len(n_cells)) {
    in_cell <- cells == k
    if (!any(in_cell & is_resp)) next
    expect_equal(
      sum(new_wts[in_cell & is_resp]),
      sum(old_wts[in_cell]),
      tolerance = 1e-10
    )
  }
})

# ---------------------------------------------------------------------------
# PC-6. Error — formula = NULL with method = 'propensity-cell'
# ---------------------------------------------------------------------------

test_that("adjust_nonresponse() errors when method='propensity-cell' and formula is NULL", {
  df <- make_surveywts_data(seed = 50, include_nonrespondents = TRUE)

  expect_error(
    adjust_nonresponse(df, response_status = responded, method = "propensity-cell"),
    class = "surveywts_error_formula_required_for_propensity_cell"
  )
  expect_snapshot(
    error = TRUE,
    adjust_nonresponse(df, response_status = responded, method = "propensity-cell")
  )
})

# ---------------------------------------------------------------------------
# PC-7. Error — formula is not a formula object
# ---------------------------------------------------------------------------

test_that("adjust_nonresponse() errors when formula is not a formula object (propensity-cell)", {
  df <- make_surveywts_data(seed = 50, include_nonrespondents = TRUE)

  expect_error(
    adjust_nonresponse(df, response_status = responded,
                       formula = "age_group", method = "propensity-cell"),
    class = "surveywts_error_formula_invalid"
  )
  expect_snapshot(
    error = TRUE,
    adjust_nonresponse(df, response_status = responded,
                       formula = "age_group", method = "propensity-cell")
  )
})

# ---------------------------------------------------------------------------
# PC-8. Error — formula variable not found in data
# ---------------------------------------------------------------------------

test_that("adjust_nonresponse() errors when a formula variable is missing (propensity-cell)", {
  df <- make_surveywts_data(seed = 50, include_nonrespondents = TRUE)

  expect_error(
    adjust_nonresponse(df, response_status = responded,
                       formula = ~nonexistent_var, method = "propensity-cell"),
    class = "surveywts_error_formula_variable_not_found"
  )
  expect_snapshot(
    error = TRUE,
    adjust_nonresponse(df, response_status = responded,
                       formula = ~nonexistent_var, method = "propensity-cell")
  )
})

# ---------------------------------------------------------------------------
# PC-9. Error — formula variable has NA values
# ---------------------------------------------------------------------------

test_that("adjust_nonresponse() errors when a formula variable has NA values", {
  df <- make_surveywts_data(seed = 50, include_nonrespondents = TRUE)
  df$age_group[1L] <- NA

  expect_error(
    adjust_nonresponse(df, response_status = responded,
                       formula = ~age_group, method = "propensity-cell"),
    class = "surveywts_error_formula_variable_has_na"
  )
  expect_snapshot(
    error = TRUE,
    adjust_nonresponse(df, response_status = responded,
                       formula = ~age_group, method = "propensity-cell")
  )
})

# ---------------------------------------------------------------------------
# PC-10. Error — control$n_cells < 2
# ---------------------------------------------------------------------------

test_that("adjust_nonresponse() errors when control$n_cells = 1", {
  df <- make_surveywts_data(seed = 50, include_nonrespondents = TRUE)

  expect_error(
    adjust_nonresponse(df, response_status = responded,
                       formula = ~age_group, method = "propensity-cell",
                       control = list(n_cells = 1)),
    class = "surveywts_error_n_cells_invalid"
  )
  expect_snapshot(
    error = TRUE,
    adjust_nonresponse(df, response_status = responded,
                       formula = ~age_group, method = "propensity-cell",
                       control = list(n_cells = 1))
  )
})

# ---------------------------------------------------------------------------
# PC-12. Error — a propensity cell contains no respondents
# ---------------------------------------------------------------------------

test_that("adjust_nonresponse() errors when a propensity cell contains no respondents", {
  set.seed(60)
  x_pred     <- runif(30)
  responded  <- sample(c(rep(1L, 2L), rep(0L, 28L)))
  df_no_resp <- data.frame(x_pred = x_pred, responded = responded,
                            wt = rep(1, 30))

  expect_error(
    adjust_nonresponse(df_no_resp, response_status = responded, weights = wt,
                       formula = ~x_pred, method = "propensity-cell",
                       control = list(n_cells = 10)),
    class = "surveywts_error_no_respondents_in_propensity_cell"
  )
  expect_snapshot(
    error = TRUE,
    adjust_nonresponse(df_no_resp, response_status = responded, weights = wt,
                       formula = ~x_pred, method = "propensity-cell",
                       control = list(n_cells = 10))
  )
})

# ---------------------------------------------------------------------------
# PC-13. Warning — by is non-NULL with method = 'propensity-cell'
# ---------------------------------------------------------------------------

test_that("adjust_nonresponse() warns when by is non-NULL with method='propensity-cell'", {
  df <- make_surveywts_data(seed = 55, include_nonrespondents = TRUE)

  expect_warning(
    result <- adjust_nonresponse(
      df,
      response_status = responded,
      by = age_group,
      formula = ~sex,
      method = "propensity-cell"
    ),
    class = "surveywts_warning_by_ignored_for_propensity_cell"
  )

  # by is ignored — result is still valid
  test_invariants(result)
})

# ---------------------------------------------------------------------------
# PC-14. Warning — cell has fewer than min_cell respondents
# ---------------------------------------------------------------------------

test_that("adjust_nonresponse() warns when a cell has fewer than min_cell respondents", {
  df <- make_surveywts_data(n = 200, seed = 55, include_nonrespondents = TRUE)

  # min_cell = 9999 guarantees all cells trigger (each has far fewer respondents);
  # max_adjust = Inf disables the max_adjust condition so only min_cell triggers
  expect_warning(
    adjust_nonresponse(
      df,
      response_status = responded,
      formula = ~age_group,
      method = "propensity-cell",
      control = list(n_cells = 5, max_adjust = Inf, min_cell = 9999)
    ),
    class = "surveywts_warning_class_near_empty"
  )
})

# ---------------------------------------------------------------------------
# PC-15. Warning — adjustment factor exceeds max_adjust in a cell
# ---------------------------------------------------------------------------

test_that("adjust_nonresponse() warns when adjustment factor exceeds max_adjust in a cell", {
  df <- make_surveywts_data(n = 500, seed = 65, include_nonrespondents = TRUE)

  # max_adjust = 1.1 is below the actual adj_factor (~1.25 with ~20% nonresponse)
  expect_warning(
    adjust_nonresponse(
      df,
      response_status = responded,
      formula = ~age_group,
      method = "propensity-cell",
      control = list(n_cells = 5, max_adjust = 1.1, min_cell = 0L)
    ),
    class = "surveywts_warning_class_near_empty"
  )
})

# ---------------------------------------------------------------------------
# PC-16. Edge case — control$n_cells = 2
# ---------------------------------------------------------------------------

test_that("propensity-cell works with control$n_cells = 2", {
  df <- make_surveywts_data(seed = 56, include_nonrespondents = TRUE)

  result <- adjust_nonresponse(
    df,
    response_status = responded,
    formula = ~age_group,
    method = "propensity-cell",
    control = list(n_cells = 2)
  )

  test_invariants(result)
  is_resp <- df$responded == 1L
  wt_col  <- attr(result, "weight_col")
  expect_true(all(result[[wt_col]][!is_resp] == 0))
})

# ---------------------------------------------------------------------------
# PC-17. Edge case — high propensity concentration (bimodal scores)
# ---------------------------------------------------------------------------

test_that("propensity-cell handles high propensity concentration (all scores near 0 or 1)", {
  # Binary predictor creates bimodal scores; suppressWarnings since small cells
  # trigger class_near_empty warnings (expected in this edge case)
  set.seed(57)
  df_bimodal <- data.frame(
    x_pred    = rep(c(0L, 1L), each = 50L),
    responded = c(
      sample(c(rep(1L, 5L), rep(0L, 45L))),   # 10% response when x=0
      sample(c(rep(1L, 45L), rep(0L, 5L)))    # 90% response when x=1
    ),
    wt = rep(1, 100)
  )

  result <- suppressWarnings(
    adjust_nonresponse(
      df_bimodal,
      response_status = responded,
      weights = wt,
      formula = ~x_pred,
      method = "propensity-cell",
      control = list(n_cells = 2, min_cell = 0L, max_adjust = Inf)
    )
  )

  test_invariants(result)
  is_resp <- df_bimodal$responded == 1L
  wt_col  <- attr(result, "weight_col")
  expect_true(all(result[[wt_col]][!is_resp] == 0))
  # Total weight conserved (respondent weights absorb nonrespondent weights)
  expect_equal(sum(result[[wt_col]]), sum(df_bimodal$wt), tolerance = 1e-10)
})

# ===========================================================================
# adjust_nonresponse(method = "propensity") — full implementation
# ===========================================================================

# ---------------------------------------------------------------------------
# P-1. Happy path — data.frame input returns weighted_df
# ---------------------------------------------------------------------------

test_that("adjust_nonresponse(propensity) accepts data.frame and returns weighted_df", {
  df <- make_surveywts_data(n = 200L, seed = 70L, include_nonrespondents = TRUE)
  df$base_weight <- rep(1L, nrow(df))

  result <- adjust_nonresponse(
    df,
    response_status = responded,
    weights         = base_weight,
    formula         = ~age_group + sex,
    method          = "propensity"
  )

  test_invariants(result)
  expect_true(inherits(result, "weighted_df"))
  expect_equal(nrow(result), nrow(df))
  is_resp <- df$responded == 1L
  wt_col  <- attr(result, "weight_col")
  expect_true(all(result[[wt_col]][is_resp] > 0))
  expect_true(all(result[[wt_col]][!is_resp] == 0))
})

# ---------------------------------------------------------------------------
# P-2. Happy path — weighted_df input returns weighted_df
# ---------------------------------------------------------------------------

test_that("adjust_nonresponse(propensity) accepts weighted_df and returns weighted_df", {
  df  <- make_surveywts_data(n = 200L, seed = 71L, include_nonrespondents = TRUE)
  df$base_weight <- rep(1L, nrow(df))
  wdf <- .make_weighted_df(df, "base_weight", list())

  result <- adjust_nonresponse(
    wdf,
    response_status = responded,
    formula         = ~age_group + sex,
    method          = "propensity"
  )

  test_invariants(result)
  expect_true(inherits(result, "weighted_df"))
  expect_equal(nrow(result), nrow(wdf))
})

# ---------------------------------------------------------------------------
# P-3. Happy path — survey_taylor input returns respondent rows only
# ---------------------------------------------------------------------------

test_that("adjust_nonresponse(propensity) accepts survey_taylor and returns respondent rows only", {
  df     <- make_surveywts_data(n = 200L, seed = 72L, include_nonrespondents = TRUE)
  df$base_weight <- rep(1L, nrow(df))
  design <- .make_test_taylor_nr(df)

  result <- adjust_nonresponse(
    design,
    response_status = responded,
    formula         = ~age_group + sex,
    method          = "propensity"
  )

  test_invariants(result)
  expect_true(S7::S7_inherits(result, surveycore::survey_taylor))
  n_resp <- sum(df$responded == 1L)
  expect_equal(nrow(result@data), n_resp)
  expect_true(all(result@data[[result@variables$weights]] > 0))
})

# ---------------------------------------------------------------------------
# P-4. Happy path — survey_nonprob input returns survey_nonprob
# ---------------------------------------------------------------------------

test_that("adjust_nonresponse(propensity) accepts survey_nonprob and returns survey_nonprob", {
  df <- make_surveywts_data(n = 200L, seed = 73L, include_nonrespondents = TRUE)
  df$base_weight <- rep(1L, nrow(df))
  nonprob_obj <- surveycore::survey_nonprob(
    data      = df,
    variables = list(
      ids = NULL, strata = NULL, fpc = NULL,
      weights = "base_weight", nest = FALSE
    ),
    metadata    = surveycore::survey_metadata(),
    groups      = character(0L),
    call        = NULL,
    calibration = NULL
  )

  result <- adjust_nonresponse(
    nonprob_obj,
    response_status = responded,
    formula         = ~age_group + sex,
    method          = "propensity"
  )

  test_invariants(result)
  expect_true(S7::S7_inherits(result, surveycore::survey_nonprob))
  wt_col <- result@variables$weights
  expect_true(all(result@data[[wt_col]] >= 0))
  expect_true(any(result@data[[wt_col]] > 0))
})

# ---------------------------------------------------------------------------
# P-5. Happy path — respondent count and history operation
# ---------------------------------------------------------------------------

test_that("adjust_nonresponse(propensity) records correct history operation", {
  df     <- make_surveywts_data(n = 200L, seed = 74L, include_nonrespondents = TRUE)
  df$base_weight <- rep(1L, nrow(df))
  n_resp <- sum(df$responded == 1L)

  result <- adjust_nonresponse(
    df,
    response_status = responded,
    weights         = base_weight,
    formula         = ~age_group + sex,
    method          = "propensity"
  )

  wt_col <- attr(result, "weight_col")
  expect_equal(sum(result[[wt_col]] > 0), n_resp)

  hist  <- attr(result, "weighting_history")
  entry <- hist[[length(hist)]]
  expect_identical(entry$operation, "nonresponse_propensity")
  expect_identical(entry$parameters$method, "propensity")
})

# ---------------------------------------------------------------------------
# P-Num. Numerical correctness — new_weight_i = orig_weight_i / score_i
# ---------------------------------------------------------------------------

test_that("adjust_nonresponse(propensity) produces weights equal to w / predicted score", {
  df <- make_surveywts_data(n = 200L, seed = 75L, include_nonrespondents = TRUE)
  df$base_weight <- 1  # uniform for easy verification

  is_resp <- df$responded == 1L

  # Reproduce the exact GLM the implementation uses (formula built from col name)
  prop_form <- stats::as.formula(paste("responded", "~", "age_group + sex"))
  fit_ref   <- stats::glm(
    prop_form,
    data    = df,
    weights = base_weight,
    family  = stats::binomial(link = "logit"),
    control = stats::glm.control(maxit = 25L, epsilon = 1e-8)
  )
  scores_ref   <- stats::predict(fit_ref, type = "response")
  expected_wts <- ifelse(is_resp, df$base_weight / scores_ref, 0)

  result <- suppressWarnings(adjust_nonresponse(
    df,
    response_status = responded,
    weights         = base_weight,
    formula         = ~age_group + sex,
    method          = "propensity"
  ))

  wt_col <- attr(result, "weight_col")
  expect_equal(result[[wt_col]], expected_wts, tolerance = 1e-10)
})

# ---------------------------------------------------------------------------
# P-6. Error — formula = NULL with method = "propensity"
# ---------------------------------------------------------------------------

test_that("adjust_nonresponse(propensity) errors when formula = NULL", {
  df <- make_surveywts_data(n = 200L, seed = 76L, include_nonrespondents = TRUE)

  expect_error(
    adjust_nonresponse(df, response_status = responded, method = "propensity"),
    class = "surveywts_error_formula_required_for_propensity"
  )
  expect_snapshot(
    error = TRUE,
    adjust_nonresponse(df, response_status = responded, method = "propensity")
  )
})

# ---------------------------------------------------------------------------
# P-7. Error — formula is not a formula object
# ---------------------------------------------------------------------------

test_that("adjust_nonresponse(propensity) errors when formula is not a formula", {
  df <- make_surveywts_data(n = 200L, seed = 76L, include_nonrespondents = TRUE)

  expect_error(
    adjust_nonresponse(df, response_status = responded,
                       formula = "age_group + sex", method = "propensity"),
    class = "surveywts_error_formula_invalid"
  )
  expect_snapshot(
    error = TRUE,
    adjust_nonresponse(df, response_status = responded,
                       formula = "age_group + sex", method = "propensity")
  )
})

# ---------------------------------------------------------------------------
# P-8. Error — formula variable not found in data
# ---------------------------------------------------------------------------

test_that("adjust_nonresponse(propensity) errors when formula variable is missing", {
  df <- make_surveywts_data(n = 200L, seed = 76L, include_nonrespondents = TRUE)

  expect_error(
    adjust_nonresponse(df, response_status = responded,
                       formula = ~nonexistent_var, method = "propensity"),
    class = "surveywts_error_formula_variable_not_found"
  )
  expect_snapshot(
    error = TRUE,
    adjust_nonresponse(df, response_status = responded,
                       formula = ~nonexistent_var, method = "propensity")
  )
})

# ---------------------------------------------------------------------------
# P-9. Error — formula variable has NA values
# ---------------------------------------------------------------------------

test_that("adjust_nonresponse(propensity) errors when formula variable has NA", {
  df <- make_surveywts_data(n = 200L, seed = 76L, include_nonrespondents = TRUE)
  df$age_group[1L] <- NA_character_

  expect_error(
    adjust_nonresponse(df, response_status = responded,
                       formula = ~age_group, method = "propensity"),
    class = "surveywts_error_formula_variable_has_na"
  )
  expect_snapshot(
    error = TRUE,
    adjust_nonresponse(df, response_status = responded,
                       formula = ~age_group, method = "propensity")
  )
})

# ---------------------------------------------------------------------------
# P-W1. Warning — by is non-NULL with method = "propensity"
# ---------------------------------------------------------------------------

test_that("adjust_nonresponse(propensity) warns when by is non-NULL", {
  df <- make_surveywts_data(n = 200L, seed = 77L, include_nonrespondents = TRUE)
  df$base_weight <- rep(1L, nrow(df))

  expect_warning(
    result <- adjust_nonresponse(
      df,
      response_status = responded,
      weights         = base_weight,
      by              = age_group,
      formula         = ~sex,
      method          = "propensity"
    ),
    class = "surveywts_warning_by_ignored_for_propensity"
  )

  # by is ignored — result is still valid
  test_invariants(result)
})

# ---------------------------------------------------------------------------
# P-W2. Warning — extreme propensity scores (< 0.01)
# ---------------------------------------------------------------------------

test_that("adjust_nonresponse(propensity) warns on extreme scores < 0.01", {
  # 1 respondent at low x vs 200 nonrespondents at low x → propensity << 0.01
  set.seed(77)
  df_extreme <- data.frame(
    x_pred    = c(
      runif(99L, 0.8, 1.0),   # respondents clustered at high x
      0.0,                      # 1 respondent at x = 0 (very low propensity)
      runif(200L, 0.0, 0.1)   # 200 nonrespondents at low x
    ),
    responded = c(rep(1L, 100L), rep(0L, 200L)),
    wt        = rep(1, 300L)
  )

  expect_warning(
    result <- adjust_nonresponse(
      df_extreme,
      response_status = responded,
      weights         = wt,
      formula         = ~x_pred,
      method          = "propensity"
    ),
    class = "surveywts_warning_extreme_propensity_scores"
  )

  test_invariants(result)
})

# ---------------------------------------------------------------------------
# P-W3. Warning — extreme adjustment factor exceeds control$max_adjust
# ---------------------------------------------------------------------------

test_that("adjust_nonresponse(propensity) warns when adjustment exceeds max_adjust", {
  df <- make_surveywts_data(n = 200L, seed = 78L, include_nonrespondents = TRUE)

  # max_adjust = 1.01 — extremely tight; any real adjustment triggers warning
  expect_warning(
    result <- adjust_nonresponse(
      df,
      response_status = responded,
      weights         = base_weight,
      formula         = ~age_group + sex,
      method          = "propensity",
      control         = list(max_adjust = 1.01)
    ),
    class = "surveywts_warning_extreme_propensity_adjustment"
  )

  test_invariants(result)
})

# ---------------------------------------------------------------------------
# P-W4. Warning — GLM does not converge in 25 iterations
# ---------------------------------------------------------------------------

test_that("adjust_nonresponse(propensity) warns when GLM does not converge", {
  # Perfect binary separation with n >= 51 per group: IRLS does not converge in
  # 25 iterations because the deviance keeps decreasing as the coefficient
  # diverges. The convergence warning fires; scores remain strictly in (0, 1).
  df_conv <- data.frame(
    x_pred    = c(rep(0L, 100L), rep(1L, 100L)),
    responded = c(rep(1L, 100L), rep(0L, 100L)),
    wt        = rep(1, 200L)
  )

  expect_warning(
    result <- adjust_nonresponse(
      df_conv,
      response_status = responded,
      weights         = wt,
      formula         = ~x_pred,
      method          = "propensity"
    ),
    class = "surveywts_warning_propensity_glm_convergence"
  )

  test_invariants(result)
})

# ---------------------------------------------------------------------------
# P-E1. Edge case — very high response rate (95%)
# ---------------------------------------------------------------------------

test_that("adjust_nonresponse(propensity) works with 95% response rate (no warning)", {
  set.seed(79)
  n <- 200L
  responded <- as.integer(stats::rbinom(n, 1L, 0.95))
  # Ensure at least some nonrespondents
  if (sum(responded == 0L) == 0L) responded[1L] <- 0L
  df_high <- data.frame(
    age_group = sample(c("18-34", "35-54", "55+"), n, replace = TRUE),
    sex       = sample(c("M", "F"), n, replace = TRUE),
    responded = responded,
    wt        = rep(1, n)
  )

  result <- adjust_nonresponse(
    df_high,
    response_status = responded,
    weights         = wt,
    formula         = ~age_group + sex,
    method          = "propensity"
  )

  test_invariants(result)
  n_resp <- sum(responded == 1L)
  wt_col <- attr(result, "weight_col")
  expect_equal(sum(result[[wt_col]] > 0), n_resp)
})

# ---------------------------------------------------------------------------
# P-E2. Edge case — very low response rate (20%)
# ---------------------------------------------------------------------------

test_that("adjust_nonresponse(propensity) warns on high adjustment with 20% response rate", {
  set.seed(80)
  n <- 300L
  responded <- as.integer(stats::rbinom(n, 1L, 0.20))
  if (sum(responded) < 5L) responded[seq_len(5L)] <- 1L
  df_low <- data.frame(
    age_group = sample(c("18-34", "35-54", "55+"), n, replace = TRUE),
    sex       = sample(c("M", "F"), n, replace = TRUE),
    responded = responded,
    wt        = rep(1, n)
  )

  # High nonresponse → large adjustments → expect extreme_propensity_adjustment warning
  expect_warning(
    result <- adjust_nonresponse(
      df_low,
      response_status = responded,
      weights         = wt,
      formula         = ~age_group + sex,
      method          = "propensity"
    ),
    class = "surveywts_warning_extreme_propensity_adjustment"
  )

  test_invariants(result)
})

# ---------------------------------------------------------------------------
# P-E3. Edge case — control$n_cells is silently ignored
# ---------------------------------------------------------------------------

test_that("adjust_nonresponse(propensity) ignores control$n_cells without warning", {
  df <- make_surveywts_data(n = 200L, seed = 81L, include_nonrespondents = TRUE)
  # Use integer weights to avoid "non-integer #successes in a binomial glm!"
  # warning from stats::glm() — the point of this test is only that n_cells
  # is silently ignored, not to exercise non-integer weight paths.
  df$base_weight <- rep(1L, nrow(df))

  # max_adjust = Inf to suppress any adjustment warning; we only want to
  # verify n_cells is silently ignored
  expect_no_warning(
    result <- adjust_nonresponse(
      df,
      response_status = responded,
      weights         = base_weight,
      formula         = ~age_group + sex,
      method          = "propensity",
      control         = list(n_cells = 10L, max_adjust = Inf)
    )
  )

  test_invariants(result)
})
