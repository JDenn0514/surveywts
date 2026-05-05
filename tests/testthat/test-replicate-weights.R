# tests/testthat/test-replicate-weights.R

# ---- Shared input-class errors (13a–13d) ------------------------------------

test_that("create_bootstrap_weights() rejects data.frame input", {
  df <- make_surveywts_data(seed = 1)
  expect_error(
    create_bootstrap_weights(df),
    class = "surveywts_error_not_survey_design"
  )
  expect_snapshot(error = TRUE, create_bootstrap_weights(df))
})

test_that("create_bootstrap_weights() rejects survey_replicate input", {
  skip_if_not_installed("svrep")
  td <- make_taylor_design(seed = 1)
  rep <- create_bootstrap_weights(td, replicates = 10L, seed = 1L)
  expect_error(
    create_bootstrap_weights(rep),
    class = "surveywts_error_already_replicate"
  )
  expect_snapshot(error = TRUE, create_bootstrap_weights(rep))
})

test_that("create_bootstrap_weights() rejects unsupported class", {
  expect_error(
    create_bootstrap_weights(list(x = 1)),
    class = "surveywts_error_unsupported_class"
  )
  expect_snapshot(error = TRUE, create_bootstrap_weights(list(x = 1)))
})

# ---- Bootstrap-specific errors (3c–3d) -------------------------------------

test_that("create_bootstrap_weights() rejects replicates = 0", {
  td <- make_taylor_design(seed = 1)
  expect_error(
    create_bootstrap_weights(td, replicates = 0L),
    class = "surveywts_error_replicates_not_positive"
  )
  expect_snapshot(error = TRUE, create_bootstrap_weights(td, replicates = 0L))
})

test_that("create_bootstrap_weights() rejects replicates = 1 (boundary: min is 2)", {
  td <- make_taylor_design(seed = 1)
  expect_error(
    create_bootstrap_weights(td, replicates = 1L),
    class = "surveywts_error_replicates_not_positive"
  )
  expect_snapshot(error = TRUE, create_bootstrap_weights(td, replicates = 1L))
})

test_that("create_bootstrap_weights() rejects fractional replicates", {
  td <- make_taylor_design(seed = 1)
  expect_error(
    create_bootstrap_weights(td, replicates = 1.5),
    class = "surveywts_error_replicates_not_whole_number"
  )
  expect_snapshot(error = TRUE, create_bootstrap_weights(td, replicates = 1.5))
})

# ---- Happy path (1a–1f) -----------------------------------------------------

test_that("create_bootstrap_weights() returns survey_replicate from survey_taylor", {
  skip_if_not_installed("svrep")
  td     <- make_taylor_design(seed = 1)
  result <- create_bootstrap_weights(td, replicates = 50L, seed = 42L)
  test_invariants(result)
  expect_true(S7::S7_inherits(result, surveycore::survey_replicate))
  expect_identical(result@variables$type, "bootstrap")
  expect_identical(length(result@variables$repweights), 50L)
})

test_that("create_bootstrap_weights() accepts whole-number replicates coerced silently", {
  skip_if_not_installed("svrep")
  td     <- make_taylor_design(seed = 1)
  result <- create_bootstrap_weights(td, replicates = 50, seed = 42L)
  test_invariants(result)
  expect_identical(length(result@variables$repweights), 50L)
})

test_that("create_bootstrap_weights() accepts survey_nonprob input", {
  skip_if_not_installed("svrep")
  df  <- make_surveywts_data(seed = 1)
  np  <- surveycore::survey_nonprob(
    data      = df,
    variables = list(weights = "base_weight"),
    metadata  = surveycore::survey_metadata()
  )
  result <- create_bootstrap_weights(np, replicates = 20L, seed = 1L)
  test_invariants(result)
  expect_identical(result@variables$type, "bootstrap")
})

test_that("create_bootstrap_weights() preserves metadata through conversion", {
  skip_if_not_installed("svrep")
  td     <- make_taylor_design(seed = 1)
  result <- create_bootstrap_weights(td, replicates = 10L, seed = 1L)
  test_invariants(result)
  # weighting history has exactly one entry of operation = "replicate_creation"
  history <- result@metadata@weighting_history
  expect_length(history, 1L)
  expect_identical(history[[1L]]$operation, "replicate_creation")
  expect_identical(history[[1L]]$method, "bootstrap")
})

# ---- Equivalence with svrep (2a) -------------------------------------------

test_that("create_bootstrap_weights() matches svrep::as_bootstrap_design() directly", {
  skip_if_not_installed("svrep")
  td <- make_taylor_design(n = 100L, seed = 7L)

  # Direct svrep call with same seed
  set.seed(99L)
  direct_svyrep <- svrep::as_bootstrap_design(
    surveycore::as_svydesign(td),
    type       = "Rao-Wu-Yue-Beaumont",
    replicates = 50L,
    mse        = TRUE
  )
  direct_mat <- as.matrix(direct_svyrep$repweights)

  # surveywts wrapper with same seed
  result     <- create_bootstrap_weights(td, replicates = 50L, seed = 99L)
  test_invariants(result)
  result_mat <- as.matrix(result@data[, result@variables$repweights])

  # Strip dimnames: result_mat comes from a named data.frame; direct_mat from
  # svrep's repweights object. Values must match; dimnames are not meaningful.
  expect_equal(unname(result_mat), unname(direct_mat), tolerance = 1e-10)
})

# ---- Spec §XIII 1b: default replicates = 500 ---------------------------------

test_that("create_bootstrap_weights() default replicates = 500 produces 500 columns", {
  skip_if_not_installed("svrep")
  td     <- make_taylor_design(seed = 1)
  result <- create_bootstrap_weights(td, seed = 1L)
  test_invariants(result)
  expect_identical(length(result@variables$repweights), 500L)
})

# ---- Spec §XIII 1c: different type values produce different results ----------

test_that("create_bootstrap_weights() Rao-Wu and Rao-Wu-Yue-Beaumont differ", {
  skip_if_not_installed("svrep")
  td  <- make_taylor_design(seed = 1)
  r1  <- create_bootstrap_weights(td, type = "Rao-Wu", replicates = 50L, seed = 1L)
  r2  <- create_bootstrap_weights(td, type = "Rao-Wu-Yue-Beaumont", replicates = 50L, seed = 1L)
  test_invariants(r1)
  test_invariants(r2)
  mat1 <- as.matrix(r1@data[, r1@variables$repweights])
  mat2 <- as.matrix(r2@data[, r2@variables$repweights])
  expect_false(isTRUE(all.equal(mat1, mat2)))
})

# ---- Spec §XIII 1d: mse = FALSE passes through correctly ---------------------

test_that("create_bootstrap_weights() mse = FALSE is stored in history", {
  skip_if_not_installed("svrep")
  td     <- make_taylor_design(seed = 1)
  result <- create_bootstrap_weights(td, replicates = 20L, mse = FALSE, seed = 1L)
  test_invariants(result)
  history <- result@metadata@weighting_history
  expect_false(history[[1L]]$parameters$mse)
})

# ---- Spec §XIII 19a: edge cases ----------------------------------------------

test_that("create_bootstrap_weights() all-equal base weights succeeds", {
  skip_if_not_installed("svrep")
  df             <- make_surveywts_data(n = 50L, seed = 1L)
  df$base_weight <- rep(1, nrow(df))
  td     <- surveycore::as_survey(df, ids = id, weights = base_weight)
  result <- create_bootstrap_weights(td, replicates = 20L, seed = 1L)
  test_invariants(result)
  rep_mat <- as.matrix(result@data[, result@variables$repweights])
  expect_true(all(abs(colMeans(rep_mat) - 1) < 0.5))  # means near base weight
})
