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

# ---- .validate_replicates_arg() — NULL and non-numeric paths (lines 54–59) --

test_that("create_bootstrap_weights() passes NULL replicates to svrep (which errors)", {
  skip_if_not_installed("svrep")
  td <- make_taylor_design(seed = 1)
  # NULL passes .validate_replicates_arg() (line 54) but svrep rejects it
  expect_error(create_bootstrap_weights(td, replicates = NULL))
})

test_that("create_bootstrap_weights() rejects character replicates", {
  td <- make_taylor_design(seed = 1)
  expect_error(
    create_bootstrap_weights(td, replicates = "fifty"),
    class = "surveywts_error_replicates_invalid"
  )
  expect_snapshot(error = TRUE, create_bootstrap_weights(td, replicates = "fifty"))
})

test_that("create_bootstrap_weights() rejects NA replicates", {
  td <- make_taylor_design(seed = 1)
  expect_error(
    create_bootstrap_weights(td, replicates = NA_integer_),
    class = "surveywts_error_replicates_invalid"
  )
  expect_snapshot(error = TRUE, create_bootstrap_weights(td, replicates = NA_integer_))
})

# ---- Jackknife happy path (4a–4d) ------------------------------------------

test_that("create_jackknife_weights() delete-1 unstratified -> JK1", {
  skip_if_not_installed("survey")
  # SRS design (no strata)
  df <- make_surveywts_data(n = 20L, seed = 2L)
  td <- surveycore::as_survey(df, ids = id, weights = base_weight)
  result <- create_jackknife_weights(td)
  test_invariants(result)
  expect_identical(result@variables$type, "JK1")
})

test_that("create_jackknife_weights() delete-1 stratified -> JKn", {
  skip_if_not_installed("survey")
  td     <- make_taylor_design(seed = 2L)
  result <- create_jackknife_weights(td)
  test_invariants(result)
  expect_identical(result@variables$type, "JKn")
})

test_that("create_jackknife_weights() random-groups produces JKn with correct rep count", {
  skip_if_not_installed("svrep")
  # replicates must not exceed psus_per_stratum (svrep requirement)
  td     <- make_taylor_design(n = 200L, n_strata = 4L, psus_per_stratum = 10L, seed = 3L)
  result <- create_jackknife_weights(td, replicates = 8L, type = "random-groups", seed = 5L)
  test_invariants(result)
  expect_identical(result@variables$type, "Random-groups jackknife")
  expect_identical(length(result@variables$repweights), 8L)
})

test_that("create_jackknife_weights() accepts survey_nonprob with delete-1", {
  skip_if_not_installed("survey")
  df <- make_surveywts_data(n = 30L, seed = 4L)
  np <- surveycore::survey_nonprob(
    data      = df,
    variables = list(weights = "base_weight"),
    metadata  = surveycore::survey_metadata()
  )
  result <- create_jackknife_weights(np)
  test_invariants(result)
})

# ---- Jackknife errors (5a–5e) -----------------------------------------------

test_that("create_jackknife_weights() errors when random-groups needs replicates", {
  td <- make_taylor_design(seed = 1)
  expect_error(
    create_jackknife_weights(td, type = "random-groups"),
    class = "surveywts_error_replicates_required_for_jkn"
  )
  expect_snapshot(error = TRUE, create_jackknife_weights(td, type = "random-groups"))
})

# ---- Shared input-class errors (13a–13d) ------------------------------------

test_that("create_jackknife_weights() rejects data.frame input", {
  df <- make_surveywts_data(seed = 1)
  expect_error(
    create_jackknife_weights(df),
    class = "surveywts_error_not_survey_design"
  )
  expect_snapshot(error = TRUE, create_jackknife_weights(df))
})

test_that("create_jackknife_weights() rejects survey_replicate input", {
  skip_if_not_installed("survey")
  td  <- make_taylor_design(seed = 1)
  rep <- create_jackknife_weights(td)
  expect_error(
    create_jackknife_weights(rep),
    class = "surveywts_error_already_replicate"
  )
  expect_snapshot(error = TRUE, create_jackknife_weights(rep))
})

test_that("create_jackknife_weights() rejects weighted_df input", {
  df <- make_surveywts_data(seed = 1)
  wdf <- structure(df, class = c("weighted_df", "tbl_df", "tbl", "data.frame"),
                   weight_col = "base_weight", weighting_history = list())
  expect_error(
    create_jackknife_weights(wdf),
    class = "surveywts_error_not_survey_design"
  )
  expect_snapshot(error = TRUE, create_jackknife_weights(wdf))
})

test_that("create_jackknife_weights() rejects unsupported class", {
  expect_error(
    create_jackknife_weights(list(x = 1)),
    class = "surveywts_error_unsupported_class"
  )
  expect_snapshot(error = TRUE, create_jackknife_weights(list(x = 1)))
})

test_that("create_jackknife_weights() rejects fractional replicates for random-groups", {
  td <- make_taylor_design(seed = 1)
  expect_error(
    create_jackknife_weights(td, replicates = 1.5, type = "random-groups"),
    class = "surveywts_error_replicates_not_whole_number"
  )
  expect_snapshot(
    error = TRUE,
    create_jackknife_weights(td, replicates = 1.5, type = "random-groups")
  )
})

test_that("create_jackknife_weights() rejects replicates = 1 for random-groups", {
  td <- make_taylor_design(seed = 1)
  expect_error(
    create_jackknife_weights(td, replicates = 1L, type = "random-groups"),
    class = "surveywts_error_replicates_not_positive"
  )
  expect_snapshot(
    error = TRUE,
    create_jackknife_weights(td, replicates = 1L, type = "random-groups")
  )
})

test_that("create_jackknife_weights() rejects survey_nonprob + random-groups", {
  df <- make_surveywts_data(n = 30L, seed = 1L)
  np <- surveycore::survey_nonprob(
    data      = df,
    variables = list(weights = "base_weight"),
    metadata  = surveycore::survey_metadata()
  )
  expect_error(
    create_jackknife_weights(np, replicates = 10L, type = "random-groups"),
    class = "surveywts_error_jackknife_type_unsupported_for_nonprob"
  )
  expect_snapshot(
    error = TRUE,
    create_jackknife_weights(np, replicates = 10L, type = "random-groups")
  )
})

# ---- Jackknife equivalence (4Ea–4Ec) ----------------------------------------

test_that("create_jackknife_weights() delete-1 matches survey::as.svrepdesign(JK1)", {
  skip_if_not_installed("survey")
  df <- make_surveywts_data(n = 20L, seed = 5L)
  td <- surveycore::as_survey(df, ids = id, weights = base_weight)

  direct   <- survey::as.svrepdesign(surveycore::as_svydesign(td), type = "JK1", mse = TRUE)
  result   <- create_jackknife_weights(td, type = "delete-1")
  test_invariants(result)
  expected <- unname(as.matrix(direct$repweights))
  actual   <- unname(as.matrix(result@data[, result@variables$repweights]))

  expect_equal(actual, expected, tolerance = 1e-10)
})

test_that("create_jackknife_weights() JKn delete-1 matches survey::as.svrepdesign(JKn)", {
  skip_if_not_installed("survey")
  df <- make_surveywts_data(n = 40L, seed = 5L)
  td <- surveycore::as_survey(df, ids = id, strata = age_group, weights = base_weight)

  direct   <- survey::as.svrepdesign(surveycore::as_svydesign(td), type = "JKn", mse = TRUE)
  result   <- create_jackknife_weights(td, type = "delete-1")
  test_invariants(result)
  expected <- unname(as.matrix(direct$repweights))
  actual   <- unname(as.matrix(result@data[, result@variables$repweights]))

  expect_equal(actual, expected, tolerance = 1e-10)
})

test_that("create_jackknife_weights() random-groups matches svrep::as_random_group_jackknife_design()", {
  skip_if_not_installed("svrep")
  df <- make_surveywts_data(n = 60L, seed = 3L)
  td <- surveycore::as_survey(df, ids = id, weights = base_weight)

  set.seed(77L)
  direct <- svrep::as_random_group_jackknife_design(
    surveycore::as_svydesign(td),
    replicates = 20L,
    mse        = TRUE
  )
  result <- create_jackknife_weights(td, type = "random-groups", replicates = 20L, seed = 77L)
  test_invariants(result)

  expected <- unname(as.matrix(direct$repweights))
  actual   <- unname(as.matrix(result@data[, result@variables$repweights]))
  expect_equal(actual, expected, tolerance = 1e-10)
})

# ---- Spec §XIII 19b: edge cases ----------------------------------------------

test_that("create_jackknife_weights() delete-1 single-PSU propagates backend error", {
  # 2 rows with the same PSU id = 1 unique PSU; surveycore requires >= 2 rows
  # but survey::as.svrepdesign() errors when it cannot compute leave-one-out
  df <- data.frame(id = c(1L, 1L), base_weight = c(1, 1), age_group = c("18-34", "18-34"))
  td <- surveycore::as_survey(df, ids = id, weights = base_weight)
  expect_error(create_jackknife_weights(td, type = "delete-1"))
})

test_that("create_jackknife_weights() random-groups replicates > PSU count propagates backend error", {
  skip_if_not_installed("svrep")
  df <- make_surveywts_data(n = 5L, seed = 1L)
  td <- surveycore::as_survey(df, ids = id, weights = base_weight)
  expect_error(
    create_jackknife_weights(td, type = "random-groups", replicates = 100L, seed = 1L)
  )
})

test_that("create_jackknife_weights() all-equal base weights succeeds", {
  skip_if_not_installed("survey")
  df             <- make_surveywts_data(n = 20L, seed = 1L)
  df$base_weight <- rep(1, nrow(df))
  td     <- surveycore::as_survey(df, ids = id, weights = base_weight)
  result <- create_jackknife_weights(td, type = "delete-1")
  test_invariants(result)
})

# ---- BRR happy path (6a–6b) -------------------------------------------------

test_that("create_brr_weights() paired design rho=0 -> BRR type", {
  skip_if_not_installed("survey")
  pd     <- make_paired_design(seed = 1L)
  result <- create_brr_weights(pd)
  test_invariants(result)
  expect_identical(result@variables$type, "BRR")
})

test_that("create_brr_weights() paired design rho=0.5 -> Fay type", {
  skip_if_not_installed("survey")
  pd     <- make_paired_design(seed = 1L)
  result <- create_brr_weights(pd, rho = 0.5)
  test_invariants(result)
  expect_identical(result@variables$type, "Fay")
})

# ---- Shared input-class errors (13a–13d) ------------------------------------

test_that("create_brr_weights() rejects data.frame input", {
  df <- make_surveywts_data(seed = 1)
  expect_error(create_brr_weights(df), class = "surveywts_error_not_survey_design")
  expect_snapshot(error = TRUE, create_brr_weights(df))
})

test_that("create_brr_weights() rejects survey_replicate input", {
  skip_if_not_installed("survey")
  pd  <- make_paired_design(seed = 1)
  rep <- create_brr_weights(pd)
  expect_error(create_brr_weights(rep), class = "surveywts_error_already_replicate")
  expect_snapshot(error = TRUE, create_brr_weights(rep))
})

test_that("create_brr_weights() rejects weighted_df input", {
  df <- make_surveywts_data(seed = 1)
  wdf <- structure(df, class = c("weighted_df", "tbl_df", "tbl", "data.frame"),
                   weight_col = "base_weight", weighting_history = list())
  expect_error(create_brr_weights(wdf), class = "surveywts_error_not_survey_design")
  expect_snapshot(error = TRUE, create_brr_weights(wdf))
})

test_that("create_brr_weights() rejects unsupported class", {
  expect_error(create_brr_weights(list(x = 1)), class = "surveywts_error_unsupported_class")
  expect_snapshot(error = TRUE, create_brr_weights(list(x = 1)))
})

# ---- BRR errors (8a–8d) ----------------------------------------------------

test_that("create_brr_weights() rejects non-paired design", {
  td <- make_taylor_design(n = 200L, n_strata = 4L, psus_per_stratum = 5L, seed = 1L)
  expect_error(
    create_brr_weights(td),
    class = "surveywts_error_brr_requires_paired_design"
  )
  expect_snapshot(error = TRUE, create_brr_weights(td))
})

test_that("create_brr_weights() rejects survey_nonprob", {
  df <- make_surveywts_data(n = 30L, seed = 1L)
  np <- surveycore::survey_nonprob(
    data      = df,
    variables = list(weights = "base_weight"),
    metadata  = surveycore::survey_metadata()
  )
  expect_error(create_brr_weights(np), class = "surveywts_error_brr_requires_paired_design")
  expect_snapshot(error = TRUE, create_brr_weights(np))
})

test_that("create_brr_weights() rejects rho < 0", {
  pd <- make_paired_design(seed = 1L)
  expect_error(create_brr_weights(pd, rho = -0.1), class = "surveywts_error_brr_rho_invalid")
  expect_snapshot(error = TRUE, create_brr_weights(pd, rho = -0.1))
})

test_that("create_brr_weights() rejects rho = 1", {
  pd <- make_paired_design(seed = 1L)
  expect_error(create_brr_weights(pd, rho = 1.0), class = "surveywts_error_brr_rho_invalid")
  expect_snapshot(error = TRUE, create_brr_weights(pd, rho = 1.0))
})

# ---- BRR equivalence (7a) ---------------------------------------------------

test_that("create_brr_weights() matches survey::as.svrepdesign(BRR) directly", {
  skip_if_not_installed("survey")
  pd       <- make_paired_design(seed = 1L)
  direct   <- survey::as.svrepdesign(surveycore::as_svydesign(pd), type = "BRR", mse = TRUE)
  result   <- create_brr_weights(pd)
  test_invariants(result)
  expected <- unname(as.matrix(direct$repweights))
  actual   <- unname(as.matrix(result@data[, result@variables$repweights]))
  expect_equal(actual, expected, tolerance = 1e-10)
})

# ---- Spec §XIII 19c: edge cases ----------------------------------------------

test_that("create_brr_weights() single-stratum paired design succeeds with 4 replicates", {
  skip_if_not_installed("survey")
  # 1 stratum, 2 PSUs — smallest valid BRR design; survey uses Hadamard order 4
  df <- data.frame(
    id          = 1:2, stratum = c(1L, 1L),
    base_weight = c(1, 1), age_group = c("18-34", "35-54")
  )
  pd     <- suppressWarnings(
    surveycore::as_survey(df, ids = id, strata = stratum, weights = base_weight)
  )
  result <- create_brr_weights(pd)
  test_invariants(result)
  expect_identical(length(result@variables$repweights), 4L)
})

test_that("create_brr_weights() all-equal base weights succeeds", {
  skip_if_not_installed("survey")
  pd <- make_paired_design(seed = 1L)
  pd@data$base_weight <- rep(1, nrow(pd@data))
  result <- create_brr_weights(pd)
  test_invariants(result)
})
