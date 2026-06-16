# tests/testthat/test-replicate-dispatch.R

# ---- create_replicate_weights() dispatch (14a–14h) -------------------------

test_that("create_replicate_weights() bootstrap dispatches correctly", {
  skip_if_not_installed("svrep")
  td     <- make_taylor_design(seed = 1L)
  result <- create_replicate_weights(td, method = "bootstrap",
                                      replicates = 20L, seed = 1L)
  expect_true(S7::S7_inherits(result, surveycore::survey_replicate))
  expect_identical(result@variables$type, "bootstrap")
})

test_that("create_replicate_weights() jackknife dispatches correctly", {
  skip_if_not_installed("survey")
  td     <- make_taylor_design(seed = 1L)
  result <- create_replicate_weights(td, method = "jackknife")
  expect_true(S7::S7_inherits(result, surveycore::survey_replicate))
})

test_that("create_replicate_weights() brr dispatches correctly", {
  skip_if_not_installed("survey")
  pd     <- make_paired_design(seed = 1L)
  result <- create_replicate_weights(pd, method = "brr")
  expect_true(S7::S7_inherits(result, surveycore::survey_replicate))
})

test_that("create_replicate_weights() generalized-bootstrap dispatches correctly", {
  skip_if_not_installed("svrep")
  td     <- make_taylor_design(seed = 1L)
  result <- create_replicate_weights(td, method = "generalized-bootstrap",
                                      replicates = 10L, seed = 1L)
  expect_true(S7::S7_inherits(result, surveycore::survey_replicate))
})

test_that("create_replicate_weights() generalized-replicate dispatches correctly", {
  skip_if_not_installed("svrep")
  td     <- make_taylor_design(seed = 1L)
  result <- create_replicate_weights(td, method = "generalized-replicate")
  expect_true(S7::S7_inherits(result, surveycore::survey_replicate))
})

test_that("create_replicate_weights() successive-difference dispatches correctly", {
  skip_if_not_installed("svrep")
  td     <- make_taylor_design(seed = 1L)
  result <- create_replicate_weights(td, method = "successive-difference",
                                      replicates = 20L)
  expect_true(S7::S7_inherits(result, surveycore::survey_replicate))
})

test_that("create_replicate_weights() passes ... to underlying function", {
  skip_if_not_installed("svrep")
  td     <- make_taylor_design(seed = 1L)
  result <- create_replicate_weights(td, method = "bootstrap",
                                      replicates = 10L,
                                      mse = "uncentered", seed = 1L)
  test_invariants(result)
  expect_false(result@variables$mse)
})

test_that("create_replicate_weights() jackknife+grouped dispatches to DAGJK for survey_nonprob", {
  ds <- make_dagjk_datasets()
  result_direct   <- create_jackknife_weights(
    ds$A, replicates = 10L, type = "grouped", seed = 42L
  )
  result_dispatch <- create_replicate_weights(
    ds$A, method = "jackknife", type = "grouped", replicates = 10L, seed = 42L
  )
  expect_true(S7::S7_inherits(result_dispatch, surveycore::survey_nonprob))
  expect_identical(result_direct@data, result_dispatch@data)
  expect_identical(result_direct@variables, result_dispatch@variables)
})

test_that("create_replicate_weights() method='group-jackknife' errors (removed method)", {
  td <- make_taylor_design(seed = 1L)
  # 'group-jackknife' was removed from the method choices; arg_match() errors.
  expect_error(create_replicate_weights(td, method = "group-jackknife"))
})

test_that("create_replicate_weights() invalid method errors via arg_match", {
  td <- make_taylor_design(seed = 1L)
  expect_error(create_replicate_weights(td, method = "not-a-method"))
})

# ---- as_taylor_design() happy path (15a–15c) --------------------------------

test_that("as_taylor_design() converts survey_replicate -> survey_taylor", {
  skip_if_not_installed("svrep")
  td  <- make_taylor_design(seed = 1L)
  rep <- create_bootstrap_weights(td, replicates = 20L, seed = 1L)

  expect_warning(
    result <- as_taylor_design(rep),
    class = "surveywts_warning_taylor_loses_variance"
  )
  expect_true(S7::S7_inherits(result, surveycore::survey_taylor))
})

test_that("as_taylor_design() drops replicate columns from @data", {
  skip_if_not_installed("svrep")
  td  <- make_taylor_design(seed = 1L)
  rep <- create_bootstrap_weights(td, replicates = 20L, seed = 1L)

  expect_warning(
    result <- as_taylor_design(rep),
    class = "surveywts_warning_taylor_loses_variance"
  )
  rep_col_names <- paste0("rep_", seq_len(20L))
  expect_false(any(rep_col_names %in% names(result@data)))
})

test_that("as_taylor_design() preserves original design structure (ids, strata)", {
  skip_if_not_installed("svrep")
  td  <- make_taylor_design(seed = 1L)
  rep <- create_bootstrap_weights(td, replicates = 20L, seed = 1L)

  expect_warning(
    result <- as_taylor_design(rep),
    class = "surveywts_warning_taylor_loses_variance"
  )
  expect_identical(result@variables$ids,    td@variables$ids)
  expect_identical(result@variables$strata, td@variables$strata)
})

test_that("as_taylor_design() round-trips SRS design with ids = NULL", {
  skip_if_not_installed("svrep")
  df  <- make_surveywts_data(n = 40L, seed = 3L)
  srs <- surveycore::as_survey(df, weights = base_weight)  # ids = NULL

  rep <- create_bootstrap_weights(srs, replicates = 10L, seed = 1L)

  expect_warning(
    result <- as_taylor_design(rep),
    class = "surveywts_warning_taylor_loses_variance"
  )
  expect_true(S7::S7_inherits(result, surveycore::survey_taylor))
  expect_null(result@variables$ids)
})

# ---- as_taylor_design() warnings (16a–16b) ----------------------------------

test_that("as_taylor_design() warns and returns unchanged for survey_taylor input", {
  td <- make_taylor_design(seed = 1L)
  expect_warning(
    result <- as_taylor_design(td),
    class = "surveywts_warning_already_taylor"
  )
  expect_identical(result, td)
})

test_that("as_taylor_design() emits taylor_loses_variance warning", {
  skip_if_not_installed("svrep")
  td  <- make_taylor_design(seed = 1L)
  rep <- create_bootstrap_weights(td, replicates = 20L, seed = 1L)
  expect_warning(as_taylor_design(rep), class = "surveywts_warning_taylor_loses_variance")
})

# Snapshot the warnings
test_that("as_taylor_design() already_taylor warning snapshot", {
  td <- make_taylor_design(seed = 1L)
  expect_snapshot(
    expect_warning(
      as_taylor_design(td),
      class = "surveywts_warning_already_taylor"
    )
  )
})

# ---- as_taylor_design() errors (17a–17e) ------------------------------------

test_that("as_taylor_design() rejects unsupported class", {
  expect_error(as_taylor_design(list(x = 1)), class = "surveywts_error_unsupported_class")
  expect_snapshot(error = TRUE, as_taylor_design(list(x = 1)))
})

test_that("as_taylor_design() errors when no replicate_creation history entry", {
  skip_if_not_installed("svrep")
  td  <- make_taylor_design(seed = 1L)
  rep <- create_bootstrap_weights(td, replicates = 10L, seed = 1L)
  # Strip all history to simulate missing creation entry
  rep@metadata@weighting_history <- list()
  expect_error(as_taylor_design(rep), class = "surveywts_error_no_taylor_structure")
  expect_snapshot(error = TRUE, as_taylor_design(rep))
})

test_that("as_taylor_design() errors when post-creation calibration is present", {
  skip_if_not_installed("svrep")
  td  <- make_taylor_design(seed = 1L)
  rep <- create_bootstrap_weights(td, replicates = 10L, seed = 1L)
  # Append a synthetic post-creation calibration entry
  fake_entry <- list(
    step      = 2L,
    operation = "calibration",
    timestamp = Sys.time(),
    method    = "linear",
    parameters = list(variables = "age_group")
  )
  meta <- rep@metadata
  meta@weighting_history <- c(meta@weighting_history, list(fake_entry))
  rep@metadata <- meta
  expect_error(
    as_taylor_design(rep),
    class = "surveywts_error_taylor_from_calibrated_replicate"
  )
  expect_snapshot(error = TRUE, as_taylor_design(rep))
})

test_that("as_taylor_design() errors when source was survey_nonprob", {
  skip_if_not_installed("svrep")
  df <- make_surveywts_data(n = 50L, seed = 1L)
  np <- surveycore::survey_nonprob(
    data      = df,
    variables = list(weights = "base_weight"),
    metadata  = surveycore::survey_metadata()
  )
  rep <- create_bootstrap_weights(np, replicates = 10L, seed = 1L)
  expect_error(
    as_taylor_design(rep),
    class = "surveywts_error_taylor_from_nonprob_replicate"
  )
  expect_snapshot(error = TRUE, as_taylor_design(rep))
})

test_that("as_taylor_design() SRS survey_taylor round-trip succeeds (class-tag detector)", {
  # SRS design has ids = NULL, strata = NULL — same shape as nonprob.
  # Detector uses the is_nonprob boolean flag in history, not design shape.
  skip_if_not_installed("svrep")
  df  <- make_surveywts_data(n = 50L, seed = 1L)
  srs <- surveycore::as_survey(df, ids = id, weights = base_weight)
  rep <- create_bootstrap_weights(srs, replicates = 10L, seed = 1L)
  expect_warning(
    result <- as_taylor_design(rep),
    class = "surveywts_warning_taylor_loses_variance"
  )
  expect_true(S7::S7_inherits(result, surveycore::survey_taylor))
})
