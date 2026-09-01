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
  td <- make_taylor_design(seed = 1)
  result <- create_bootstrap_weights(td, replicates = 50L, seed = 42L)
  test_invariants(result)
  expect_true(S7::S7_inherits(result, surveycore::survey_replicate))
  expect_identical(result@variables$type, "bootstrap")
  expect_identical(length(result@variables$repweights), 50L)
})

test_that("create_bootstrap_weights() accepts whole-number replicates coerced silently", {
  skip_if_not_installed("svrep")
  td <- make_taylor_design(seed = 1)
  result <- create_bootstrap_weights(td, replicates = 50, seed = 42L)
  test_invariants(result)
  expect_identical(length(result@variables$repweights), 50L)
})

test_that("create_bootstrap_weights() accepts survey_nonprob input", {
  skip_if_not_installed("svrep")
  df <- make_surveywts_data(seed = 1)
  np <- surveycore::survey_nonprob(
    data = df,
    variables = list(weights = "base_weight"),
    metadata = surveycore::survey_metadata()
  )
  result <- create_bootstrap_weights(np, replicates = 20L, seed = 1L)
  test_invariants(result)
  expect_identical(result@variables$type, "bootstrap")
})

test_that("create_bootstrap_weights() preserves metadata through conversion", {
  skip_if_not_installed("svrep")
  td <- make_taylor_design(seed = 1)
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
    type = "Rao-Wu-Yue-Beaumont",
    replicates = 50L,
    mse = TRUE
  )
  # `weights(type = "analysis")` folds the base weight into each column.
  # surveywts stores finished weights, so that is the correct comparison.
  direct_mat <- as.matrix(weights(direct_svyrep, type = "analysis"))

  # surveywts wrapper with same seed
  result <- create_bootstrap_weights(td, replicates = 50L, seed = 99L)
  test_invariants(result)
  result_mat <- as.matrix(result@data[, result@variables$repweights])

  # Strip dimnames: result_mat comes from a named data.frame; direct_mat from
  # svrep's repweights object. Values must match; dimnames are not meaningful.
  expect_equal(unname(result_mat), unname(direct_mat), tolerance = 1e-10)
})

# ---- Spec §XIII 1b: default replicates = 500 ---------------------------------

test_that("create_bootstrap_weights() default replicates = 500 produces 500 columns", {
  skip_if_not_installed("svrep")
  td <- make_taylor_design(seed = 1)
  result <- create_bootstrap_weights(td, seed = 1L)
  test_invariants(result)
  expect_identical(length(result@variables$repweights), 500L)
})

# ---- Spec §XIII 1c: different type values produce different results ----------

test_that("create_bootstrap_weights() Rao-Wu and Rao-Wu-Yue-Beaumont differ", {
  skip_if_not_installed("svrep")
  td <- make_taylor_design(seed = 1)
  r1 <- create_bootstrap_weights(
    td,
    type = "Rao-Wu",
    replicates = 50L,
    seed = 1L
  )
  r2 <- create_bootstrap_weights(
    td,
    type = "Rao-Wu-Yue-Beaumont",
    replicates = 50L,
    seed = 1L
  )
  test_invariants(r1)
  test_invariants(r2)
  mat1 <- as.matrix(r1@data[, r1@variables$repweights])
  mat2 <- as.matrix(r2@data[, r2@variables$repweights])
  expect_false(isTRUE(all.equal(mat1, mat2)))
})

# ---- Spec §XIII 1d: mse = FALSE passes through correctly ---------------------

test_that("create_bootstrap_weights() mse = uncentered is stored in history", {
  skip_if_not_installed("svrep")
  td <- make_taylor_design(seed = 1)
  result <- create_bootstrap_weights(
    td,
    replicates = 20L,
    mse = "uncentered",
    seed = 1L
  )
  test_invariants(result)
  history <- result@metadata@weighting_history
  expect_false(history[[1L]]$parameters$mse)
})

# ---- Spec §XIII 19a: edge cases ----------------------------------------------

test_that("create_bootstrap_weights() all-equal base weights succeeds", {
  skip_if_not_installed("svrep")
  df <- make_surveywts_data(n = 50L, seed = 1L)
  df$base_weight <- rep(1, nrow(df))
  td <- surveycore::as_survey(df, ids = id, weights = base_weight)
  result <- create_bootstrap_weights(td, replicates = 20L, seed = 1L)
  test_invariants(result)
  rep_mat <- as.matrix(result@data[, result@variables$repweights])
  expect_true(all(abs(colMeans(rep_mat) - 1) < 0.5)) # means near base weight
})

# ---- .validate_replicates_arg() — NULL and non-numeric paths (lines 54–59) --

test_that("create_bootstrap_weights() resolves NULL replicates to 500L for prob-sample types", {
  skip_if_not_installed("svrep")
  td <- make_taylor_design(seed = 1)
  # NULL resolves to 500L for probability-sample types (new default behavior)
  result <- create_bootstrap_weights(td, replicates = NULL, seed = 1L)
  expect_true(S7::S7_inherits(result, surveycore::survey_replicate))
  expect_identical(length(result@variables$repweights), 500L)
})

test_that("create_bootstrap_weights() rejects character replicates", {
  td <- make_taylor_design(seed = 1)
  expect_error(
    create_bootstrap_weights(td, replicates = "fifty"),
    class = "surveywts_error_replicates_invalid"
  )
  expect_snapshot(
    error = TRUE,
    create_bootstrap_weights(td, replicates = "fifty")
  )
})

test_that("create_bootstrap_weights() rejects NA replicates", {
  td <- make_taylor_design(seed = 1)
  expect_error(
    create_bootstrap_weights(td, replicates = NA_integer_),
    class = "surveywts_error_replicates_invalid"
  )
  expect_snapshot(
    error = TRUE,
    create_bootstrap_weights(td, replicates = NA_integer_)
  )
})

# ---- Jackknife happy path (4a–4d) ------------------------------------------

test_that("create_jackknife_weights() type='jk1' unstratified -> JK1", {
  skip_if_not_installed("survey")
  # SRS design (no strata)
  df <- make_surveywts_data(n = 20L, seed = 2L)
  td <- surveycore::as_survey(df, ids = id, weights = base_weight)
  result <- create_jackknife_weights(td, type = "jk1")
  test_invariants(result)
  expect_identical(result@variables$type, "JK1")
})

test_that("create_jackknife_weights() type='jkn' default stratified -> JKn", {
  skip_if_not_installed("survey")
  td <- make_taylor_design(seed = 2L)
  result <- create_jackknife_weights(td, type = "jkn")
  test_invariants(result)
  expect_identical(result@variables$type, "JKn")
})

test_that("create_jackknife_weights() type='grouped' produces correct rep count", {
  skip_if_not_installed("svrep")
  # replicates must not exceed psus_per_stratum (svrep requirement)
  td <- make_taylor_design(
    n = 200L,
    n_strata = 4L,
    psus_per_stratum = 10L,
    seed = 3L
  )
  result <- create_jackknife_weights(
    td,
    replicates = 8L,
    type = "grouped",
    seed = 5L
  )
  test_invariants(result)
  expect_identical(length(result@variables$repweights), 8L)
})

# ---- Jackknife errors (5a–5e) -----------------------------------------------

test_that("create_jackknife_weights() errors when grouped needs replicates", {
  td <- make_taylor_design(seed = 1)
  expect_error(
    create_jackknife_weights(td, type = "grouped"),
    class = "surveywts_error_jackknife_replicates_required"
  )
  expect_snapshot(error = TRUE, create_jackknife_weights(td, type = "grouped"))
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
  td <- make_taylor_design(seed = 1)
  rep <- create_jackknife_weights(td)
  expect_error(
    create_jackknife_weights(rep),
    class = "surveywts_error_already_replicate"
  )
  expect_snapshot(error = TRUE, create_jackknife_weights(rep))
})

test_that("create_jackknife_weights() rejects data.frame input", {
  df <- data.frame(x = 1:3, w = c(1, 1, 1))
  expect_error(
    create_jackknife_weights(df),
    class = "surveywts_error_not_survey_design"
  )
  expect_snapshot(error = TRUE, create_jackknife_weights(df))
})

test_that("create_jackknife_weights() rejects unsupported class", {
  expect_error(
    create_jackknife_weights(list(x = 1)),
    class = "surveywts_error_unsupported_class"
  )
  expect_snapshot(error = TRUE, create_jackknife_weights(list(x = 1)))
})

test_that("create_jackknife_weights() rejects fractional replicates for grouped", {
  td <- make_taylor_design(seed = 1)
  expect_error(
    create_jackknife_weights(td, replicates = 1.5, type = "grouped"),
    class = "surveywts_error_replicates_not_whole_number"
  )
  expect_snapshot(
    error = TRUE,
    create_jackknife_weights(td, replicates = 1.5, type = "grouped")
  )
})

test_that("create_jackknife_weights() rejects replicates = 1 for grouped", {
  td <- make_taylor_design(seed = 1)
  expect_error(
    create_jackknife_weights(td, replicates = 1L, type = "grouped"),
    class = "surveywts_error_replicates_not_positive"
  )
  expect_snapshot(
    error = TRUE,
    create_jackknife_weights(td, replicates = 1L, type = "grouped")
  )
})

test_that("create_jackknife_weights() rejects survey_nonprob + jkn", {
  df <- make_surveywts_data(n = 30L, seed = 1L)
  np <- surveycore::survey_nonprob(
    data = df,
    variables = list(weights = "base_weight"),
    metadata = surveycore::survey_metadata()
  )
  expect_error(
    create_jackknife_weights(np, type = "jkn"),
    class = "surveywts_error_jackknife_type_nonprob_only"
  )
  expect_snapshot(
    error = TRUE,
    create_jackknife_weights(np, type = "jkn")
  )
})

# ---- Jackknife equivalence (4Ea–4Ec) ----------------------------------------

test_that("create_jackknife_weights() jk1 matches survey::as.svrepdesign(JK1)", {
  skip_if_not_installed("survey")
  df <- make_surveywts_data(n = 20L, seed = 5L)
  td <- surveycore::as_survey(df, ids = id, weights = base_weight)

  direct <- survey::as.svrepdesign(
    surveycore::as_svydesign(td),
    type = "JK1",
    mse = TRUE
  )
  result <- create_jackknife_weights(td, type = "jk1")
  test_invariants(result)
  expected <- unname(as.matrix(weights(direct, type = "analysis")))
  actual <- unname(as.matrix(result@data[, result@variables$repweights]))

  expect_equal(actual, expected, tolerance = 1e-10)
})

test_that("create_jackknife_weights() jkn matches survey::as.svrepdesign(JKn)", {
  skip_if_not_installed("survey")
  df <- make_surveywts_data(n = 40L, seed = 5L)
  td <- surveycore::as_survey(
    df,
    ids = id,
    strata = age_group,
    weights = base_weight
  )

  direct <- survey::as.svrepdesign(
    surveycore::as_svydesign(td),
    type = "JKn",
    mse = TRUE
  )
  result <- create_jackknife_weights(td, type = "jkn")
  test_invariants(result)
  expected <- unname(as.matrix(weights(direct, type = "analysis")))
  actual <- unname(as.matrix(result@data[, result@variables$repweights]))

  expect_equal(actual, expected, tolerance = 1e-10)
})

test_that("create_jackknife_weights() grouped matches svrep::as_random_group_jackknife_design()", {
  skip_if_not_installed("svrep")
  df <- make_surveywts_data(n = 60L, seed = 3L)
  td <- surveycore::as_survey(df, ids = id, weights = base_weight)

  set.seed(77L)
  direct <- svrep::as_random_group_jackknife_design(
    surveycore::as_svydesign(td),
    replicates = 20L,
    mse = TRUE
  )
  result <- create_jackknife_weights(
    td,
    type = "grouped",
    replicates = 20L,
    seed = 77L
  )
  test_invariants(result)

  expected <- unname(as.matrix(weights(direct, type = "analysis")))
  actual <- unname(as.matrix(result@data[, result@variables$repweights]))
  expect_equal(actual, expected, tolerance = 1e-10)
})

# ---- Spec §XIII 19b: edge cases ----------------------------------------------

test_that("create_jackknife_weights() jk1 single-PSU propagates backend error", {
  # 2 rows with the same PSU id = 1 unique PSU; surveycore requires >= 2 rows
  # but survey::as.svrepdesign() errors when it cannot compute leave-one-out
  df <- data.frame(
    id = c(1L, 1L),
    base_weight = c(1, 1),
    age_group = c("18-34", "18-34")
  )
  td <- surveycore::as_survey(df, ids = id, weights = base_weight)
  expect_error(create_jackknife_weights(td, type = "jk1"))
})

test_that("create_jackknife_weights() grouped replicates > PSU count propagates backend error", {
  skip_if_not_installed("svrep")
  df <- make_surveywts_data(n = 5L, seed = 1L)
  td <- surveycore::as_survey(df, ids = id, weights = base_weight)
  expect_error(
    create_jackknife_weights(td, type = "grouped", replicates = 100L, seed = 1L)
  )
})

test_that("create_jackknife_weights() all-equal base weights succeeds", {
  skip_if_not_installed("survey")
  df <- make_surveywts_data(n = 20L, seed = 1L)
  df$base_weight <- rep(1, nrow(df))
  # SRS design (no strata) — use jk1
  td <- surveycore::as_survey(df, ids = id, weights = base_weight)
  result <- create_jackknife_weights(td, type = "jk1")
  test_invariants(result)
})

# ---- BRR happy path (6a–6b) -------------------------------------------------

test_that("create_brr_weights() paired design rho=0 -> BRR type", {
  skip_if_not_installed("survey")
  pd <- make_paired_design(seed = 1L)
  result <- create_brr_weights(pd)
  test_invariants(result)
  expect_identical(result@variables$type, "BRR")
})

test_that("create_brr_weights() paired design rho=0.5 -> Fay type", {
  skip_if_not_installed("survey")
  pd <- make_paired_design(seed = 1L)
  result <- create_brr_weights(pd, rho = 0.5)
  test_invariants(result)
  expect_identical(result@variables$type, "Fay")
})

# ---- Shared input-class errors (13a–13d) ------------------------------------

test_that("create_brr_weights() rejects data.frame input", {
  df <- make_surveywts_data(seed = 1)
  expect_error(
    create_brr_weights(df),
    class = "surveywts_error_not_survey_design"
  )
  expect_snapshot(error = TRUE, create_brr_weights(df))
})

test_that("create_brr_weights() rejects survey_replicate input", {
  skip_if_not_installed("survey")
  pd <- make_paired_design(seed = 1)
  rep <- create_brr_weights(pd)
  expect_error(
    create_brr_weights(rep),
    class = "surveywts_error_already_replicate"
  )
  expect_snapshot(error = TRUE, create_brr_weights(rep))
})

test_that("create_brr_weights() rejects data.frame input", {
  df <- data.frame(x = 1:3, w = c(1, 1, 1))
  expect_error(
    create_brr_weights(df),
    class = "surveywts_error_not_survey_design"
  )
  expect_snapshot(error = TRUE, create_brr_weights(df))
})

test_that("create_brr_weights() rejects unsupported class", {
  expect_error(
    create_brr_weights(list(x = 1)),
    class = "surveywts_error_unsupported_class"
  )
  expect_snapshot(error = TRUE, create_brr_weights(list(x = 1)))
})

# ---- BRR errors (8a–8d) ----------------------------------------------------

test_that("create_brr_weights() rejects non-paired design", {
  td <- make_taylor_design(
    n = 200L,
    n_strata = 4L,
    psus_per_stratum = 5L,
    seed = 1L
  )
  expect_error(
    create_brr_weights(td),
    class = "surveywts_error_brr_requires_paired_design"
  )
  expect_snapshot(error = TRUE, create_brr_weights(td))
})

test_that("create_brr_weights() rejects survey_nonprob", {
  df <- make_surveywts_data(n = 30L, seed = 1L)
  np <- surveycore::survey_nonprob(
    data = df,
    variables = list(weights = "base_weight"),
    metadata = surveycore::survey_metadata()
  )
  expect_error(
    create_brr_weights(np),
    class = "surveywts_error_brr_requires_paired_design"
  )
  expect_snapshot(error = TRUE, create_brr_weights(np))
})

test_that("create_brr_weights() rejects survey_taylor with strata but no PSU ids", {
  df <- data.frame(id = 1:20, stratum = rep(1:2, 10), y = rnorm(20), w = 1)
  td <- surveycore::as_survey(df, strata = stratum, weights = w)
  expect_error(
    create_brr_weights(td),
    class = "surveywts_error_brr_requires_paired_design"
  )
  expect_snapshot(error = TRUE, create_brr_weights(td))
})

test_that("create_brr_weights() rejects survey_taylor with PSU ids but no strata", {
  df <- data.frame(id = 1:20, psu = rep(1:10, 2), y = rnorm(20), w = 1)
  td <- surveycore::as_survey(df, ids = psu, weights = w)
  expect_error(
    create_brr_weights(td),
    class = "surveywts_error_brr_requires_paired_design"
  )
  expect_snapshot(error = TRUE, create_brr_weights(td))
})

test_that("create_brr_weights() rejects survey_taylor with neither strata nor PSU ids", {
  df <- data.frame(id = 1:20, y = rnorm(20), w = 1)
  td <- surveycore::as_survey(df, weights = w)
  expect_error(
    create_brr_weights(td),
    class = "surveywts_error_brr_requires_paired_design"
  )
  expect_snapshot(error = TRUE, create_brr_weights(td))
})

test_that("create_brr_weights() rejects rho < 0", {
  pd <- make_paired_design(seed = 1L)
  expect_error(
    create_brr_weights(pd, rho = -0.1),
    class = "surveywts_error_brr_rho_invalid"
  )
  expect_snapshot(error = TRUE, create_brr_weights(pd, rho = -0.1))
})

test_that("create_brr_weights() rejects rho = 1", {
  pd <- make_paired_design(seed = 1L)
  expect_error(
    create_brr_weights(pd, rho = 1.0),
    class = "surveywts_error_brr_rho_invalid"
  )
  expect_snapshot(error = TRUE, create_brr_weights(pd, rho = 1.0))
})

# ---- BRR equivalence (7a) ---------------------------------------------------

test_that("create_brr_weights() matches survey::as.svrepdesign(BRR) directly", {
  skip_if_not_installed("survey")
  pd <- make_paired_design(seed = 1L)
  direct <- survey::as.svrepdesign(
    surveycore::as_svydesign(pd),
    type = "BRR",
    mse = TRUE
  )
  result <- create_brr_weights(pd)
  test_invariants(result)
  expected <- unname(as.matrix(weights(direct, type = "analysis")))
  actual <- unname(as.matrix(result@data[, result@variables$repweights]))
  expect_equal(actual, expected, tolerance = 1e-10)
})

# ---- Spec §XIII 19c: edge cases ----------------------------------------------

test_that("create_brr_weights() single-stratum paired design succeeds with 4 replicates", {
  skip_if_not_installed("survey")
  # 1 stratum, 2 PSUs — smallest valid BRR design; survey uses Hadamard order 4
  df <- data.frame(
    id = 1:2,
    stratum = c(1L, 1L),
    base_weight = c(1, 1),
    age_group = c("18-34", "35-54")
  )
  pd <- suppressWarnings(
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

# ---- Gen-boot happy path (9a–9c) -------------------------------------------

test_that("create_gen_boot_weights() returns survey_replicate with type bootstrap", {
  skip_if_not_installed("svrep")
  td <- make_taylor_design(seed = 1L)
  result <- create_gen_boot_weights(td, replicates = 20L, seed = 1L)
  test_invariants(result)
  expect_identical(result@variables$type, "bootstrap")
})

test_that("create_gen_boot_weights() variance_estimator SD2 differs from SD1", {
  skip_if_not_installed("svrep")
  td <- make_taylor_design(seed = 1L)
  r1 <- create_gen_boot_weights(
    td,
    replicates = 20L,
    variance_estimator = "SD1",
    seed = 1L
  )
  r2 <- create_gen_boot_weights(
    td,
    replicates = 20L,
    variance_estimator = "SD2",
    seed = 1L
  )
  test_invariants(r1)
  test_invariants(r2)
  expect_false(identical(
    as.matrix(r1@data[, r1@variables$repweights]),
    as.matrix(r2@data[, r2@variables$repweights])
  ))
})

# ---- Shared input-class errors (13a–13d) ------------------------------------

test_that("create_gen_boot_weights() rejects data.frame input", {
  df <- make_surveywts_data(seed = 1)
  expect_error(
    create_gen_boot_weights(df),
    class = "surveywts_error_not_survey_design"
  )
  expect_snapshot(error = TRUE, create_gen_boot_weights(df))
})

test_that("create_gen_boot_weights() rejects survey_replicate input", {
  skip_if_not_installed("svrep")
  td <- make_taylor_design(seed = 1)
  rep <- create_bootstrap_weights(td, replicates = 10L, seed = 1L)
  expect_error(
    create_gen_boot_weights(rep),
    class = "surveywts_error_already_replicate"
  )
  expect_snapshot(error = TRUE, create_gen_boot_weights(rep))
})

test_that("create_gen_boot_weights() rejects data.frame input", {
  df <- data.frame(x = 1:3, w = c(1, 1, 1))
  expect_error(
    create_gen_boot_weights(df),
    class = "surveywts_error_not_survey_design"
  )
  expect_snapshot(error = TRUE, create_gen_boot_weights(df))
})

test_that("create_gen_boot_weights() rejects unsupported class", {
  expect_error(
    create_gen_boot_weights(list(x = 1)),
    class = "surveywts_error_unsupported_class"
  )
  expect_snapshot(error = TRUE, create_gen_boot_weights(list(x = 1)))
})

# ---- Gen-boot errors (9Ea–9Ed) -----------------------------------------------

test_that("create_gen_boot_weights() rejects replicates = 0", {
  td <- make_taylor_design(seed = 1)
  expect_error(
    create_gen_boot_weights(td, replicates = 0L),
    class = "surveywts_error_replicates_not_positive"
  )
  expect_snapshot(error = TRUE, create_gen_boot_weights(td, replicates = 0L))
})

test_that("create_gen_boot_weights() rejects replicates = 1 (boundary: min is 2)", {
  td <- make_taylor_design(seed = 1)
  expect_error(
    create_gen_boot_weights(td, replicates = 1L),
    class = "surveywts_error_replicates_not_positive"
  )
  expect_snapshot(error = TRUE, create_gen_boot_weights(td, replicates = 1L))
})

test_that("create_gen_boot_weights() rejects fractional replicates", {
  td <- make_taylor_design(seed = 1)
  expect_error(
    create_gen_boot_weights(td, replicates = 2.5),
    class = "surveywts_error_replicates_not_whole_number"
  )
  expect_snapshot(error = TRUE, create_gen_boot_weights(td, replicates = 2.5))
})

test_that("create_gen_boot_weights() rejects Deville-Tille without aux_var_names", {
  td <- make_taylor_design(seed = 1)
  expect_error(
    create_gen_boot_weights(td, variance_estimator = "Deville-Tille"),
    class = "surveywts_error_variance_estimator_requires_aux"
  )
  expect_snapshot(
    error = TRUE,
    create_gen_boot_weights(td, variance_estimator = "Deville-Tille")
  )
})

test_that("create_gen_boot_weights() Deville-Tille with aux_var_names succeeds", {
  skip_if_not_installed("svrep")
  # Deville-Tille requires SRS or single-stage design; complex multistage
  # designs cause numerical instability in the hat-matrix computation.
  set.seed(1)
  n <- 60L
  N <- 600L
  df <- data.frame(id = seq_len(n), y = rnorm(n), base_weight = N / n)
  td <- surveycore::as_survey(df, ids = id, weights = base_weight)

  result <- create_gen_boot_weights(
    td,
    replicates = 20L,
    variance_estimator = "Deville-Tille",
    aux_var_names = y,
    seed = 1L
  )
  expect_true(S7::S7_inherits(result, surveycore::survey_replicate))
  expect_identical(result@variables$type, "bootstrap")
})

test_that("create_gen_boot_weights() rejects survey_nonprob", {
  df <- make_surveywts_data(n = 30L, seed = 1L)
  np <- surveycore::survey_nonprob(
    data = df,
    variables = list(weights = "base_weight"),
    metadata = surveycore::survey_metadata()
  )
  expect_error(
    create_gen_boot_weights(np),
    class = "surveywts_error_nonprob_requires_probability_design"
  )
  expect_snapshot(error = TRUE, create_gen_boot_weights(np))
})

# ---- Gen-boot equivalence (9Xa) --------------------------------------------

test_that("create_gen_boot_weights() matches svrep::as_gen_boot_design() directly", {
  skip_if_not_installed("svrep")
  td <- make_taylor_design(n = 100L, seed = 7L)

  set.seed(77L)
  direct <- svrep::as_gen_boot_design(
    surveycore::as_svydesign(td),
    variance_estimator = "SD1",
    replicates = 30L,
    mse = TRUE
  )
  result <- create_gen_boot_weights(
    td,
    replicates = 30L,
    variance_estimator = "SD1",
    seed = 77L
  )
  test_invariants(result)
  # svrep attaches rscales/scale/tau attrs to repweights; drop them so expect_equal
  # compares only numeric values (our impl stores a plain data frame).
  expected_mat <- as.matrix(weights(direct, type = "analysis"))
  for (a in c("rscales", "scale", "tau")) {
    attr(expected_mat, a) <- NULL
  }
  expected <- unname(expected_mat)
  actual <- unname(as.matrix(result@data[, result@variables$repweights]))
  expect_equal(actual, expected, tolerance = 1e-10)
})

# ---- Spec §XIII 9c: tau = "auto" produces non-negative replicate weights -----

test_that("create_gen_boot_weights() tau = 'auto' produces non-negative weights", {
  skip_if_not_installed("svrep")
  td <- make_taylor_design(seed = 1)
  result <- create_gen_boot_weights(
    td,
    replicates = 30L,
    tau = "auto",
    seed = 1L
  )
  test_invariants(result)
  rep_mat <- as.matrix(result@data[, result@variables$repweights])
  expect_true(all(rep_mat >= 0))
})

# ---- Spec §XIII 19d: edge cases ----------------------------------------------

test_that("create_gen_boot_weights() 0-row input propagates error", {
  # surveycore::as_survey() itself rejects 0-row data, so the error fires at
  # design construction. The test verifies the pipeline fails loudly.
  df <- make_surveywts_data(n = 10L, seed = 1L)[0L, ]
  expect_error(surveycore::as_survey(df, ids = id, weights = base_weight))
})

test_that("create_gen_boot_weights() all-equal base weights succeeds", {
  skip_if_not_installed("svrep")
  df <- make_surveywts_data(n = 50L, seed = 1L)
  df$base_weight <- rep(1, nrow(df))
  td <- surveycore::as_survey(df, ids = id, weights = base_weight)
  result <- create_gen_boot_weights(td, replicates = 20L, seed = 1L)
  test_invariants(result)
})

# ---- Gen-rep happy path (10a–10c) ------------------------------------------

test_that("create_gen_rep_weights() returns reproducible survey_replicate with seed", {
  skip_if_not_installed("svrep")
  td <- make_taylor_design(seed = 1L)
  r1 <- create_gen_rep_weights(td, seed = 1L)
  r2 <- create_gen_rep_weights(td, seed = 1L)
  test_invariants(r1)
  expect_equal(
    as.matrix(r1@data[, r1@variables$repweights]),
    as.matrix(r2@data[, r2@variables$repweights]),
    tolerance = 1e-10
  )
})

test_that("create_gen_rep_weights() max_replicates limits count", {
  skip_if_not_installed("svrep")
  td <- make_taylor_design(seed = 1L)
  result <- create_gen_rep_weights(td, max_replicates = 10L)
  test_invariants(result)
  expect_true(length(result@variables$repweights) <= 10L)
})

# ---- Shared input-class errors (13a–13d) ------------------------------------

test_that("create_gen_rep_weights() rejects data.frame input", {
  df <- make_surveywts_data(seed = 1)
  expect_error(
    create_gen_rep_weights(df),
    class = "surveywts_error_not_survey_design"
  )
  expect_snapshot(error = TRUE, create_gen_rep_weights(df))
})

test_that("create_gen_rep_weights() rejects survey_replicate input", {
  skip_if_not_installed("svrep")
  td <- make_taylor_design(seed = 1)
  rep <- create_bootstrap_weights(td, replicates = 10L, seed = 1L)
  expect_error(
    create_gen_rep_weights(rep),
    class = "surveywts_error_already_replicate"
  )
  expect_snapshot(error = TRUE, create_gen_rep_weights(rep))
})

test_that("create_gen_rep_weights() rejects data.frame input", {
  df <- data.frame(x = 1:3, w = c(1, 1, 1))
  expect_error(
    create_gen_rep_weights(df),
    class = "surveywts_error_not_survey_design"
  )
  expect_snapshot(error = TRUE, create_gen_rep_weights(df))
})

test_that("create_gen_rep_weights() rejects unsupported class", {
  expect_error(
    create_gen_rep_weights(list(x = 1)),
    class = "surveywts_error_unsupported_class"
  )
  expect_snapshot(error = TRUE, create_gen_rep_weights(list(x = 1)))
})

# ---- Gen-rep errors (10Ea–10Eb) ---------------------------------------------

test_that("create_gen_rep_weights() rejects Deville-Tille without aux_var_names", {
  td <- make_taylor_design(seed = 1)
  expect_error(
    create_gen_rep_weights(td, variance_estimator = "Deville-Tille"),
    class = "surveywts_error_variance_estimator_requires_aux"
  )
  expect_snapshot(
    error = TRUE,
    create_gen_rep_weights(td, variance_estimator = "Deville-Tille")
  )
})

test_that("create_gen_rep_weights() Deville-Tille with aux_var_names succeeds", {
  skip_if_not_installed("svrep")
  # Deville-Tille requires SRS or single-stage design; complex multistage
  # designs cause numerical instability in the hat-matrix computation.
  set.seed(1)
  n <- 60L
  N <- 600L
  df <- data.frame(id = seq_len(n), y = rnorm(n), base_weight = N / n)
  td <- surveycore::as_survey(df, ids = id, weights = base_weight)

  result <- create_gen_rep_weights(
    td,
    variance_estimator = "Deville-Tille",
    aux_var_names = y,
    seed = 1L
  )
  test_invariants(result)
  expect_true(S7::S7_inherits(result, surveycore::survey_replicate))
})

test_that("create_gen_rep_weights() rejects survey_nonprob", {
  df <- make_surveywts_data(n = 30L, seed = 1L)
  np <- surveycore::survey_nonprob(
    data = df,
    variables = list(weights = "base_weight"),
    metadata = surveycore::survey_metadata()
  )
  expect_error(
    create_gen_rep_weights(np),
    class = "surveywts_error_nonprob_requires_probability_design"
  )
  expect_snapshot(error = TRUE, create_gen_rep_weights(np))
})

# ---- Spec §XIII 10c: balanced = FALSE may produce fewer replicates -----------

test_that("create_gen_rep_weights() balanced = FALSE may produce fewer replicates", {
  skip_if_not_installed("svrep")
  td <- make_taylor_design(seed = 1L)
  balanced <- create_gen_rep_weights(td, balanced = TRUE)
  unbalanced <- create_gen_rep_weights(td, balanced = FALSE)
  test_invariants(balanced)
  test_invariants(unbalanced)
  expect_true(
    length(unbalanced@variables$repweights) <=
      length(balanced@variables$repweights)
  )
})

# ---- Spec §XIII 10Xa: gen-rep equivalence with svrep -------------------------

test_that("create_gen_rep_weights() matches svrep::as_fays_gen_rep_design() directly", {
  skip_if_not_installed("svrep")
  td <- make_taylor_design(n = 60L, seed = 7L)

  set.seed(99L)
  direct <- svrep::as_fays_gen_rep_design(
    surveycore::as_svydesign(td),
    variance_estimator = "SD1",
    max_replicates = 50L,
    balanced = TRUE,
    mse = TRUE
  )
  result <- create_gen_rep_weights(
    td,
    variance_estimator = "SD1",
    max_replicates = 50L,
    balanced = TRUE,
    seed = 99L
  )
  test_invariants(result)

  # svrep attaches rscales/scale attrs to repweights; drop them so expect_equal
  # compares only numeric values (our impl stores a plain data frame).
  expected_mat <- as.matrix(weights(direct, type = "analysis"))
  for (a in c("rscales", "scale")) {
    attr(expected_mat, a) <- NULL
  }
  expected <- unname(expected_mat)
  actual <- unname(as.matrix(result@data[, result@variables$repweights]))
  expect_equal(actual, expected, tolerance = 1e-10)
})

# ---- Spec §XIII 19e: edge cases ----------------------------------------------

test_that("create_gen_rep_weights() 0-row input propagates backend error", {
  skip_if_not_installed("svrep")
  # surveycore::as_survey() itself rejects 0-row data, so the error fires at
  # design construction. The test verifies the pipeline fails loudly.
  df <- make_surveywts_data(n = 10L, seed = 1L)[0L, ]
  expect_error(surveycore::as_survey(df, ids = id, weights = base_weight))
})

test_that("create_gen_rep_weights() all-equal base weights produces reproducible output with seed", {
  skip_if_not_installed("svrep")
  df <- make_surveywts_data(n = 50L, seed = 1L)
  df$base_weight <- rep(1, nrow(df))
  td <- surveycore::as_survey(df, ids = id, weights = base_weight)
  r1 <- create_gen_rep_weights(td, seed = 1L)
  r2 <- create_gen_rep_weights(td, seed = 1L)
  test_invariants(r1)
  expect_equal(
    as.matrix(r1@data[, r1@variables$repweights]),
    as.matrix(r2@data[, r2@variables$repweights]),
    tolerance = 1e-10
  )
})

# ============================================================================
# create_sdr_weights() tests
# ============================================================================

# ---- SDR happy path (11a–11b) -----------------------------------------------

test_that("create_sdr_weights() returns successive-difference type", {
  skip_if_not_installed("svrep")
  td <- make_taylor_design(seed = 1L)
  result <- create_sdr_weights(td, replicates = 40L, sort_var = id)
  test_invariants(result)
  expect_identical(result@variables$type, "successive-difference")
})

test_that("create_sdr_weights() sort_var changes result", {
  skip_if_not_installed("svrep")
  td <- make_taylor_design(seed = 1L)
  r1 <- create_sdr_weights(td, replicates = 40L, sort_var = id)
  r2 <- create_sdr_weights(td, replicates = 40L, sort_var = y)
  test_invariants(r1)
  test_invariants(r2)
  expect_false(identical(
    as.matrix(r1@data[, r1@variables$repweights]),
    as.matrix(r2@data[, r2@variables$repweights])
  ))
})

# ---- Shared input-class errors (13a–13d) ------------------------------------

test_that("create_sdr_weights() rejects data.frame input", {
  df <- make_surveywts_data(seed = 1)
  expect_error(
    create_sdr_weights(df),
    class = "surveywts_error_not_survey_design"
  )
  expect_snapshot(error = TRUE, create_sdr_weights(df))
})

test_that("create_sdr_weights() rejects survey_replicate input", {
  skip_if_not_installed("svrep")
  td <- make_taylor_design(seed = 1)
  rep <- create_bootstrap_weights(td, replicates = 10L, seed = 1L)
  expect_error(
    create_sdr_weights(rep),
    class = "surveywts_error_already_replicate"
  )
  expect_snapshot(error = TRUE, create_sdr_weights(rep))
})

test_that("create_sdr_weights() rejects data.frame input", {
  df <- data.frame(x = 1:3, w = c(1, 1, 1))
  expect_error(
    create_sdr_weights(df),
    class = "surveywts_error_not_survey_design"
  )
  expect_snapshot(error = TRUE, create_sdr_weights(df))
})

test_that("create_sdr_weights() rejects unsupported class", {
  expect_error(
    create_sdr_weights(list(x = 1)),
    class = "surveywts_error_unsupported_class"
  )
  expect_snapshot(error = TRUE, create_sdr_weights(list(x = 1)))
})

# ---- SDR errors (12a–12d) ---------------------------------------------------

test_that("create_sdr_weights() rejects sort_var with NA", {
  td <- make_taylor_design(n = 50L, seed = 1L)
  td@data$sort_na <- c(NA, seq_len(nrow(td@data) - 1L))
  expect_error(
    create_sdr_weights(td, sort_var = sort_na),
    class = "surveywts_error_sort_var_has_na"
  )
  expect_snapshot(error = TRUE, create_sdr_weights(td, sort_var = sort_na))
})

test_that("create_sdr_weights() rejects replicates = 0", {
  td <- make_taylor_design(seed = 1)
  expect_error(
    create_sdr_weights(td, replicates = 0L),
    class = "surveywts_error_replicates_not_positive"
  )
  expect_snapshot(error = TRUE, create_sdr_weights(td, replicates = 0L))
})

test_that("create_sdr_weights() rejects replicates = 3 (boundary: min is 4)", {
  td <- make_taylor_design(seed = 1)
  expect_error(
    create_sdr_weights(td, replicates = 3L),
    class = "surveywts_error_replicates_not_positive"
  )
  expect_snapshot(error = TRUE, create_sdr_weights(td, replicates = 3L))
})

test_that("create_sdr_weights() rejects fractional replicates", {
  td <- make_taylor_design(seed = 1)
  expect_error(
    create_sdr_weights(td, replicates = 2.5),
    class = "surveywts_error_replicates_not_whole_number"
  )
  expect_snapshot(error = TRUE, create_sdr_weights(td, replicates = 2.5))
})

test_that("create_sdr_weights() rejects survey_nonprob", {
  df <- make_surveywts_data(n = 30L, seed = 1L)
  np <- surveycore::survey_nonprob(
    data = df,
    variables = list(weights = "base_weight"),
    metadata = surveycore::survey_metadata()
  )
  expect_error(
    create_sdr_weights(np),
    class = "surveywts_error_nonprob_requires_probability_design"
  )
  expect_snapshot(error = TRUE, create_sdr_weights(np))
})

# ---- Spec §XIII 11Ea: SDR equivalence with svrep ----------------------------

test_that("create_sdr_weights() matches svrep::as_sdr_design() directly", {
  skip_if_not_installed("svrep")
  td <- make_taylor_design(n = 80L, seed = 7L)

  # svrep >= 0.9.1 requires sort_variable; use "id" (present in make_taylor_design)
  direct <- svrep::as_sdr_design(
    surveycore::as_svydesign(td),
    replicates = 40L,
    sort_variable = "id",
    mse = TRUE
  )
  result <- create_sdr_weights(td, replicates = 40L, sort_var = id)
  test_invariants(result)

  expected <- unname(as.matrix(weights(direct, type = "analysis")))
  actual <- unname(as.matrix(result@data[, result@variables$repweights]))
  expect_equal(actual, expected, tolerance = 1e-10)
})

# ---- Spec §XIII 19f: edge cases ----------------------------------------------

test_that("create_sdr_weights() 0-row input propagates backend error", {
  skip_if_not_installed("svrep")
  # surveycore::as_survey() itself rejects 0-row data, so the error fires at
  # design construction. The test verifies the pipeline fails loudly.
  df <- make_surveywts_data(n = 10L, seed = 1L)[0L, ]
  expect_error(surveycore::as_survey(df, ids = id, weights = base_weight))
})

test_that("create_sdr_weights() all-equal base weights succeeds", {
  skip_if_not_installed("svrep")
  df <- make_surveywts_data(n = 50L, seed = 1L)
  df$base_weight <- rep(1, nrow(df))
  td <- surveycore::as_survey(df, ids = id, weights = base_weight)
  result <- create_sdr_weights(td, replicates = 20L, sort_var = id)
  test_invariants(result)
})

# ============================================================================
# DAGJK-PR1: .handle_repweights_overwrite() internal helper
# ============================================================================

test_that(".handle_repweights_overwrite() is an internal helper that handles overwrite logic", {
  skip_if_not_installed("svrep")

  # Build a survey_nonprob with existing repweights (via create_bootstrap_weights)
  df <- make_surveywts_data(seed = 1L)
  np <- surveycore::survey_nonprob(
    data = df,
    variables = list(weights = "base_weight"),
    metadata = surveycore::survey_metadata()
  )
  rep <- create_bootstrap_weights(np, replicates = 10L, seed = 1L)

  # Function must exist and be callable via :::
  expect_true(
    existsFunction(
      ".handle_repweights_overwrite",
      where = asNamespace("surveywts")
    )
  )

  # Call the helper directly and check it returns a modified survey_nonprob
  result <- surveywts:::.handle_repweights_overwrite(
    rep,
    fn_name = "create_bootstrap_weights",
    warning_class = "surveywts_warning_repweights_overwritten"
  )

  # The returned object must have cleared repweights
  expect_null(result@variables$repweights)

  # Old replicate columns must be gone from @data
  expect_false(any(grepl("^repwt_", names(result@data))))
})

test_that("bootstrap overwrite warning message text is unchanged after refactor", {
  skip_if_not_installed("svrep")

  df <- make_surveywts_data(seed = 1L)
  np <- surveycore::survey_nonprob(
    data = df,
    variables = list(weights = "base_weight"),
    metadata = surveycore::survey_metadata()
  )
  rep <- .pin_ts(create_bootstrap_weights(np, replicates = 5L, seed = 1L))

  # Snapshot the warning message text to detect accidental changes after refactor.
  expect_warning(
    surveywts:::.handle_repweights_overwrite(
      rep,
      fn_name = "create_bootstrap_weights",
      warning_class = "surveywts_warning_repweights_overwritten"
    ),
    class = "surveywts_warning_repweights_overwritten"
  )
  expect_snapshot(
    withCallingHandlers(
      surveywts:::.handle_repweights_overwrite(
        rep,
        fn_name = "create_bootstrap_weights",
        warning_class = "surveywts_warning_repweights_overwritten"
      ),
      warning = function(w) {
        message(conditionMessage(w))
        invokeRestart("muffleWarning")
      }
    )
  )
})

# calibration-only QR bootstrap — error paths --------------------------------

# Fixtures used in this section (constructed inline per test when needed;
# shared fixtures defined here are referenced by multiple blocks):
#   nps_calib_a  — survey_nonprob calibrated via calibrate_rake(), no IPW
#   nps_calib_b  — survey_nonprob calibrated via calibrate_rake() with
#                  reference_design, no IPW (Level B)
#   nps_no_history — survey_nonprob with empty weighting history (no IPW,
#                    no calibration)
#   ref_data     — survey_taylor reference design

test_that("create_bootstrap_weights() errors on survey_nonprob with no history", {
  skip_if_not_installed("svrep")

  df <- make_surveywts_data(n = 200L, seed = 7L)
  nps_no_history <- surveycore::survey_nonprob(
    data = df,
    variables = list(weights = "base_weight"),
    metadata = surveycore::survey_metadata()
  )

  expect_error(
    create_bootstrap_weights(nps_no_history, type = "quasi-randomization"),
    class = "surveywts_error_qr_bootstrap_no_history"
  )
  expect_snapshot(
    error = TRUE,
    create_bootstrap_weights(nps_no_history, type = "quasi-randomization")
  )
})

test_that("create_bootstrap_weights() error for bad reference_sample class with calib-only NPS", {
  skip_if_not_installed("svrep")

  df <- make_surveywts_data(n = 200L, seed = 7L)
  nps_base <- surveycore::survey_nonprob(
    data = df,
    variables = list(weights = "base_weight"),
    metadata = surveycore::survey_metadata()
  )
  nps_calib_a <- calibrate_rake(
    nps_base,
    targets = list(
      age_group = c("18-34" = 0.35, "35-54" = 0.40, "55+" = 0.25),
      sex = c("M" = 0.49, "F" = 0.51)
    ),
    type = "prop"
  )

  expect_error(
    create_bootstrap_weights(
      nps_calib_a,
      type = "quasi-randomization",
      reference_sample = data.frame(x = 1)
    ),
    class = "surveywts_error_reference_sample_class"
  )
  expect_snapshot(
    error = TRUE,
    create_bootstrap_weights(
      nps_calib_a,
      type = "quasi-randomization",
      reference_sample = data.frame(x = 1)
    )
  )
})

test_that("surveywts_error_qr_bootstrap_requires_nonprob message does not say 'IPW history'", {
  skip_if_not_installed("svrep")

  td <- make_nps_ref(seed = 42L)

  # Snapshot verifies "with IPW history" is NOT present in the error message.
  expect_snapshot(
    error = TRUE,
    create_bootstrap_weights(td, type = "quasi-randomization")
  )
})

test_that("create_bootstrap_weights() errors on calibration-only Level B with no reference", {
  skip_if_not_installed("svrep")

  df <- make_surveywts_data(n = 200L, seed = 7L)
  ref_data <- make_nps_ref(seed = 99L)
  nps_base <- surveycore::survey_nonprob(
    data = df,
    variables = list(weights = "base_weight"),
    metadata = surveycore::survey_metadata()
  )
  nps_calib_b <- calibrate_rake(
    nps_base,
    targets = list(
      age_group = c("18-34" = 0.35, "35-54" = 0.40, "55+" = 0.25),
      sex = c("M" = 0.49, "F" = 0.51)
    ),
    type = "prop",
    reference_design = ref_data
  )

  # Clear reference_design from the history entry to force the error
  meta <- nps_calib_b@metadata
  last_idx <- length(meta@weighting_history)
  meta@weighting_history[[last_idx]]$parameters$reference_design <- NULL
  nps_calib_b@metadata <- meta

  expect_error(
    create_bootstrap_weights(nps_calib_b, type = "quasi-randomization"),
    class = "surveywts_error_qr_bootstrap_no_reference"
  )
  expect_snapshot(
    error = TRUE,
    create_bootstrap_weights(nps_calib_b, type = "quasi-randomization")
  )
})

# calibration-only QR bootstrap — Level A happy path -------------------------

test_that("calibration-only QR bootstrap (Level A) returns survey_nonprob with correct repweights", {
  skip_if_not_installed("svrep")

  df <- make_surveywts_data(n = 200L, seed = 7L)
  nps_base <- surveycore::survey_nonprob(
    data = df,
    variables = list(weights = "base_weight"),
    metadata = surveycore::survey_metadata()
  )
  nps_calib_a <- calibrate_rake(
    nps_base,
    targets = list(
      age_group = c("18-34" = 0.35, "35-54" = 0.40, "55+" = 0.25),
      sex = c("M" = 0.49, "F" = 0.51)
    ),
    type = "prop"
  )

  result <- create_bootstrap_weights(
    nps_calib_a,
    replicates = 20L,
    type = "quasi-randomization",
    seed = 1L
  )

  test_invariants(result)
  expect_true(S7::S7_inherits(result, surveycore::survey_nonprob))
  expect_length(result@variables$repweights, 20L)
})

test_that("calibration-only QR bootstrap (Level A) history entry has operation and level A", {
  skip_if_not_installed("svrep")

  df <- make_surveywts_data(n = 200L, seed = 7L)
  nps_base <- surveycore::survey_nonprob(
    data = df,
    variables = list(weights = "base_weight"),
    metadata = surveycore::survey_metadata()
  )
  nps_calib_a <- calibrate_rake(
    nps_base,
    targets = list(
      age_group = c("18-34" = 0.35, "35-54" = 0.40, "55+" = 0.25),
      sex = c("M" = 0.49, "F" = 0.51)
    ),
    type = "prop"
  )

  result <- create_bootstrap_weights(
    nps_calib_a,
    replicates = 20L,
    type = "quasi-randomization",
    seed = 1L
  )

  history <- result@metadata@weighting_history
  last_entry <- history[[length(history)]]
  expect_identical(last_entry$operation, "bootstrap_weights")
  expect_identical(last_entry$level, "A")
})

test_that("calibration-only QR bootstrap (Level A) repwt columns are named repwt_1 to repwt_20", {
  skip_if_not_installed("svrep")

  df <- make_surveywts_data(n = 200L, seed = 7L)
  nps_base <- surveycore::survey_nonprob(
    data = df,
    variables = list(weights = "base_weight"),
    metadata = surveycore::survey_metadata()
  )
  nps_calib_a <- calibrate_rake(
    nps_base,
    targets = list(
      age_group = c("18-34" = 0.35, "35-54" = 0.40, "55+" = 0.25),
      sex = c("M" = 0.49, "F" = 0.51)
    ),
    type = "prop"
  )

  result <- create_bootstrap_weights(
    nps_calib_a,
    replicates = 20L,
    type = "quasi-randomization",
    seed = 1L
  )

  expect_identical(
    result@variables$repweights,
    paste0("repwt_", seq_len(20L))
  )
})

# calibration-only QR bootstrap — @variables scale/rscales/type/mse ----------

test_that("calibration-only QR bootstrap (Level A) sets @variables$scale to 1/draws_used", {
  skip_if_not_installed("svrep")

  df <- make_surveywts_data(n = 200L, seed = 7L)
  nps_base <- surveycore::survey_nonprob(
    data = df,
    variables = list(weights = "base_weight"),
    metadata = surveycore::survey_metadata()
  )
  nps_calib_a <- calibrate_rake(
    nps_base,
    targets = list(
      age_group = c("18-34" = 0.35, "35-54" = 0.40, "55+" = 0.25),
      sex = c("M" = 0.49, "F" = 0.51)
    ),
    type = "prop"
  )

  result <- create_bootstrap_weights(
    nps_calib_a,
    replicates = 20L,
    type = "quasi-randomization",
    seed = 1L
  )

  draws_used <- length(result@variables$repweights)
  expect_equal(result@variables$scale, 1 / draws_used, tolerance = 1e-10)
})

test_that("calibration-only QR bootstrap (Level A) sets @variables$rscales to rep(1, draws_used)", {
  skip_if_not_installed("svrep")

  df <- make_surveywts_data(n = 200L, seed = 7L)
  nps_base <- surveycore::survey_nonprob(
    data = df,
    variables = list(weights = "base_weight"),
    metadata = surveycore::survey_metadata()
  )
  nps_calib_a <- calibrate_rake(
    nps_base,
    targets = list(
      age_group = c("18-34" = 0.35, "35-54" = 0.40, "55+" = 0.25),
      sex = c("M" = 0.49, "F" = 0.51)
    ),
    type = "prop"
  )

  result <- create_bootstrap_weights(
    nps_calib_a,
    replicates = 20L,
    type = "quasi-randomization",
    seed = 1L
  )

  draws_used <- length(result@variables$repweights)
  expect_identical(result@variables$rscales, rep(1, draws_used))
})

test_that("calibration-only QR bootstrap (Level A) sets @variables$type to 'bootstrap'", {
  skip_if_not_installed("svrep")

  df <- make_surveywts_data(n = 200L, seed = 7L)
  nps_base <- surveycore::survey_nonprob(
    data = df,
    variables = list(weights = "base_weight"),
    metadata = surveycore::survey_metadata()
  )
  nps_calib_a <- calibrate_rake(
    nps_base,
    targets = list(
      age_group = c("18-34" = 0.35, "35-54" = 0.40, "55+" = 0.25),
      sex = c("M" = 0.49, "F" = 0.51)
    ),
    type = "prop"
  )

  result <- create_bootstrap_weights(
    nps_calib_a,
    replicates = 20L,
    type = "quasi-randomization",
    seed = 1L
  )

  expect_identical(result@variables$type, "bootstrap")
})

test_that("calibration-only QR bootstrap (Level A) sets @variables$mse = TRUE when mse = 'mse'", {
  skip_if_not_installed("svrep")

  df <- make_surveywts_data(n = 200L, seed = 7L)
  nps_base <- surveycore::survey_nonprob(
    data = df,
    variables = list(weights = "base_weight"),
    metadata = surveycore::survey_metadata()
  )
  nps_calib_a <- calibrate_rake(
    nps_base,
    targets = list(
      age_group = c("18-34" = 0.35, "35-54" = 0.40, "55+" = 0.25),
      sex = c("M" = 0.49, "F" = 0.51)
    ),
    type = "prop"
  )

  result <- create_bootstrap_weights(
    nps_calib_a,
    replicates = 20L,
    type = "quasi-randomization",
    mse = "mse",
    seed = 1L
  )

  expect_true(result@variables$mse)
})

test_that("calibration-only QR bootstrap (Level A) sets @variables$mse = FALSE when mse = 'uncentered'", {
  skip_if_not_installed("svrep")

  df <- make_surveywts_data(n = 200L, seed = 7L)
  nps_base <- surveycore::survey_nonprob(
    data = df,
    variables = list(weights = "base_weight"),
    metadata = surveycore::survey_metadata()
  )
  nps_calib_a <- calibrate_rake(
    nps_base,
    targets = list(
      age_group = c("18-34" = 0.35, "35-54" = 0.40, "55+" = 0.25),
      sex = c("M" = 0.49, "F" = 0.51)
    ),
    type = "prop"
  )

  result <- create_bootstrap_weights(
    nps_calib_a,
    replicates = 20L,
    type = "quasi-randomization",
    mse = "uncentered",
    seed = 1L
  )

  expect_false(result@variables$mse)
})

test_that("IPW-path QR bootstrap sets @variables$scale to 1/draws_used", {
  skip_if_not_installed("svrep")

  nps <- suppressWarnings(make_nps_level_a(seed = 1L, n = 200L))

  result <- create_bootstrap_weights(
    nps,
    replicates = 20L,
    type = "quasi-randomization",
    seed = 1L
  )

  draws_used <- length(result@variables$repweights)
  expect_equal(result@variables$scale, 1 / draws_used, tolerance = 1e-10)
  expect_identical(result@variables$type, "bootstrap")
})

test_that("calibration-only QR bootstrap (Level A) original columns are unchanged", {
  skip_if_not_installed("svrep")

  df <- make_surveywts_data(n = 200L, seed = 7L)
  nps_base <- surveycore::survey_nonprob(
    data = df,
    variables = list(weights = "base_weight"),
    metadata = surveycore::survey_metadata()
  )
  nps_calib_a <- calibrate_rake(
    nps_base,
    targets = list(
      age_group = c("18-34" = 0.35, "35-54" = 0.40, "55+" = 0.25),
      sex = c("M" = 0.49, "F" = 0.51)
    ),
    type = "prop"
  )

  original_cols <- names(nps_calib_a@data)

  result <- create_bootstrap_weights(
    nps_calib_a,
    replicates = 20L,
    type = "quasi-randomization",
    seed = 1L
  )

  # Original columns are all still present in result
  expect_true(all(original_cols %in% names(result@data)))
})

test_that("calibration-only QR bootstrap (Level A) is reproducible with same seed", {
  skip_if_not_installed("svrep")

  df <- make_surveywts_data(n = 200L, seed = 7L)
  nps_base <- surveycore::survey_nonprob(
    data = df,
    variables = list(weights = "base_weight"),
    metadata = surveycore::survey_metadata()
  )
  nps_calib_a <- calibrate_rake(
    nps_base,
    targets = list(
      age_group = c("18-34" = 0.35, "35-54" = 0.40, "55+" = 0.25),
      sex = c("M" = 0.49, "F" = 0.51)
    ),
    type = "prop"
  )

  r1 <- create_bootstrap_weights(
    nps_calib_a,
    replicates = 10L,
    type = "quasi-randomization",
    seed = 42L
  )
  r2 <- create_bootstrap_weights(
    nps_calib_a,
    replicates = 10L,
    type = "quasi-randomization",
    seed = 42L
  )

  expect_equal(r1@data$repwt_1, r2@data$repwt_1, tolerance = 1e-10)
})

test_that("calibration-only QR bootstrap (Level A) weight conservation: repwt_1 sums to main weight sum", {
  skip_if_not_installed("svrep")

  df <- make_surveywts_data(n = 200L, seed = 7L)
  nps_base <- surveycore::survey_nonprob(
    data = df,
    variables = list(weights = "base_weight"),
    metadata = surveycore::survey_metadata()
  )
  nps_calib_a <- calibrate_rake(
    nps_base,
    targets = list(
      age_group = c("18-34" = 0.35, "35-54" = 0.40, "55+" = 0.25),
      sex = c("M" = 0.49, "F" = 0.51)
    ),
    type = "prop"
  )

  result <- create_bootstrap_weights(
    nps_calib_a,
    replicates = 20L,
    type = "quasi-randomization",
    seed = 1L
  )

  wt_col <- nps_calib_a@variables$weights
  main_sum <- sum(nps_calib_a@data[[wt_col]])
  repwt1_sum <- sum(result@data[["repwt_1"]])

  expect_equal(repwt1_sum, main_sum, tolerance = 1e-6)
})

test_that("calibration-only QR bootstrap (Level A): replicates = 2L (minimum) returns 2 repweights", {
  skip_if_not_installed("svrep")

  df <- make_surveywts_data(n = 200L, seed = 7L)
  nps_base <- surveycore::survey_nonprob(
    data = df,
    variables = list(weights = "base_weight"),
    metadata = surveycore::survey_metadata()
  )
  nps_calib_a <- calibrate_rake(
    nps_base,
    targets = list(
      age_group = c("18-34" = 0.35, "35-54" = 0.40, "55+" = 0.25),
      sex = c("M" = 0.49, "F" = 0.51)
    ),
    type = "prop"
  )

  result <- create_bootstrap_weights(
    nps_calib_a,
    replicates = 2L,
    type = "quasi-randomization",
    seed = 1L
  )

  test_invariants(result)
  expect_length(result@variables$repweights, 2L)
})

test_that("calibration-only QR bootstrap (Level A): reference_sample accepted but unused", {
  skip_if_not_installed("svrep")

  df <- make_surveywts_data(n = 200L, seed = 7L)
  nps_base <- surveycore::survey_nonprob(
    data = df,
    variables = list(weights = "base_weight"),
    metadata = surveycore::survey_metadata()
  )
  nps_calib_a <- calibrate_rake(
    nps_base,
    targets = list(
      age_group = c("18-34" = 0.35, "35-54" = 0.40, "55+" = 0.25),
      sex = c("M" = 0.49, "F" = 0.51)
    ),
    type = "prop"
  )
  ref_data <- make_nps_ref(seed = 99L)

  # Should not error — Level A does not require or use the reference
  expect_no_error(
    create_bootstrap_weights(
      nps_calib_a,
      replicates = 10L,
      type = "quasi-randomization",
      seed = 1L,
      reference_sample = ref_data
    )
  )
})

# calibration-only QR bootstrap — dispatch coverage (Level A) ----------------

test_that("calibration-only QR bootstrap dispatches to calibrate_linear", {
  skip_if_not_installed("svrep")

  df <- make_surveywts_data(n = 200L, seed = 7L)
  nps_base <- surveycore::survey_nonprob(
    data = df,
    variables = list(weights = "base_weight"),
    metadata = surveycore::survey_metadata()
  )
  nps_linear <- calibrate_linear(
    nps_base,
    targets = list(
      age_group = c("18-34" = 0.35, "35-54" = 0.40, "55+" = 0.25),
      sex = c("M" = 0.49, "F" = 0.51)
    ),
    type = "prop"
  )

  result <- create_bootstrap_weights(
    nps_linear,
    replicates = 10L,
    type = "quasi-randomization",
    seed = 1L
  )

  expect_true(S7::S7_inherits(result, surveycore::survey_nonprob))
  expect_length(result@variables$repweights, 10L)
})

test_that("calibration-only QR bootstrap dispatches to calibrate_logit", {
  skip_if_not_installed("svrep")

  df <- make_surveywts_data(n = 200L, seed = 7L)
  nps_base <- surveycore::survey_nonprob(
    data = df,
    variables = list(weights = "base_weight"),
    metadata = surveycore::survey_metadata()
  )
  nps_logit <- calibrate_logit(
    nps_base,
    targets = list(
      age_group = c("18-34" = 0.35, "35-54" = 0.40, "55+" = 0.25),
      sex = c("M" = 0.49, "F" = 0.51)
    ),
    type = "prop"
  )

  result <- create_bootstrap_weights(
    nps_logit,
    replicates = 10L,
    type = "quasi-randomization",
    seed = 1L
  )

  expect_true(S7::S7_inherits(result, surveycore::survey_nonprob))
  expect_length(result@variables$repweights, 10L)
})

test_that("calibration-only QR bootstrap dispatches to poststratify", {
  skip_if_not_installed("svrep")

  df <- make_surveywts_data(n = 200L, seed = 7L)
  nps_base <- surveycore::survey_nonprob(
    data = df,
    variables = list(weights = "base_weight"),
    metadata = surveycore::survey_metadata()
  )

  # poststratify requires a data.frame with strata columns + "target" column
  pop_cells <- data.frame(
    age_group = c("18-34", "35-54", "55+", "18-34", "35-54", "55+"),
    sex = c("M", "M", "M", "F", "F", "F"),
    target = c(
      0.35 * 0.49,
      0.40 * 0.49,
      0.25 * 0.49,
      0.35 * 0.51,
      0.40 * 0.51,
      0.25 * 0.51
    ),
    stringsAsFactors = FALSE
  )

  nps_ps <- poststratify(
    nps_base,
    targets = pop_cells,
    type = "prop"
  )

  result <- create_bootstrap_weights(
    nps_ps,
    replicates = 10L,
    type = "quasi-randomization",
    seed = 1L
  )

  expect_true(S7::S7_inherits(result, surveycore::survey_nonprob))
  expect_length(result@variables$repweights, 10L)
})

# calibration-only QR bootstrap — Level B ------------------------------------

test_that("calibration-only QR bootstrap (Level B) returns survey_nonprob with repweights", {
  skip_if_not_installed("svrep")

  df <- make_surveywts_data(n = 200L, seed = 7L)
  ref_data <- make_nps_ref(seed = 99L)
  nps_base <- surveycore::survey_nonprob(
    data = df,
    variables = list(weights = "base_weight"),
    metadata = surveycore::survey_metadata()
  )
  nps_calib_b <- calibrate_rake(
    nps_base,
    targets = list(
      age_group = c("18-34" = 0.35, "35-54" = 0.40, "55+" = 0.25),
      sex = c("M" = 0.49, "F" = 0.51)
    ),
    type = "prop",
    reference_design = ref_data
  )

  result <- create_bootstrap_weights(
    nps_calib_b,
    replicates = 20L,
    type = "quasi-randomization",
    seed = 2L,
    reference_sample = ref_data
  )

  test_invariants(result)
  expect_true(S7::S7_inherits(result, surveycore::survey_nonprob))
  expect_length(result@variables$repweights, 20L)

  history <- result@metadata@weighting_history
  last_entry <- history[[length(history)]]
  expect_identical(last_entry$operation, "bootstrap_weights")
  expect_identical(last_entry$level, "B")
})

# calibration-only QR bootstrap — warning paths ------------------------------

test_that("calibration-only QR bootstrap warns on repweights overwrite", {
  skip_if_not_installed("svrep")

  df <- make_surveywts_data(n = 200L, seed = 7L)
  nps_base <- surveycore::survey_nonprob(
    data = df,
    variables = list(weights = "base_weight"),
    metadata = surveycore::survey_metadata()
  )
  nps_calib_a <- calibrate_rake(
    nps_base,
    targets = list(
      age_group = c("18-34" = 0.35, "35-54" = 0.40, "55+" = 0.25),
      sex = c("M" = 0.49, "F" = 0.51)
    ),
    type = "prop"
  )

  # First call: no warning
  r1 <- create_bootstrap_weights(
    nps_calib_a,
    replicates = 10L,
    type = "quasi-randomization",
    seed = 1L
  )

  # Second call: overwrite warning
  expect_warning(
    create_bootstrap_weights(
      r1,
      replicates = 10L,
      type = "quasi-randomization",
      seed = 2L
    ),
    class = "surveywts_warning_repweights_overwritten"
  )
})

test_that("calibration-only QR bootstrap errors when all draws fail", {
  skip_if_not_installed("svrep")

  df <- make_surveywts_data(n = 200L, seed = 7L)
  nps_base <- surveycore::survey_nonprob(
    data = df,
    variables = list(weights = "base_weight"),
    metadata = surveycore::survey_metadata()
  )
  nps_calib_a <- calibrate_rake(
    nps_base,
    targets = list(
      age_group = c("18-34" = 0.35, "35-54" = 0.40, "55+" = 0.25),
      sex = c("M" = 0.49, "F" = 0.51)
    ),
    type = "prop"
  )

  # Force both targets and margins to NULL so every draw fails
  meta <- nps_calib_a@metadata
  last_idx <- length(meta@weighting_history)
  meta@weighting_history[[last_idx]]$parameters$targets <- NULL
  meta@weighting_history[[last_idx]]$parameters$margins <- NULL
  nps_calib_a@metadata <- meta

  expect_error(
    suppressWarnings(
      create_bootstrap_weights(
        nps_calib_a,
        replicates = 5L,
        type = "quasi-randomization",
        seed = 1L
      )
    ),
    class = "surveywts_error_bootstrap_all_draws_failed"
  )
})

# calibration-only QR bootstrap — regression tests (existing paths) ----------

test_that("IPW-only path still works after routing refactor", {
  skip_if_not_installed("svrep")

  nps <- suppressWarnings(make_nonprob_no_repweights(n = 200L, seed = 1L))
  ref <- make_nps_ref(seed = 42L)

  result <- create_bootstrap_weights(
    nps,
    replicates = 10L,
    type = "quasi-randomization",
    seed = 1L,
    reference_sample = ref
  )

  expect_true(S7::S7_inherits(result, surveycore::survey_nonprob))
  expect_true(length(result@variables$repweights) > 0L)
})

test_that("doubly-robust Level A path still works after routing refactor", {
  skip_if_not_installed("svrep")

  nps <- suppressWarnings(make_nps_level_a(seed = 1L, n = 200L))

  result <- create_bootstrap_weights(
    nps,
    replicates = 10L,
    type = "quasi-randomization",
    seed = 1L
  )

  expect_true(S7::S7_inherits(result, surveycore::survey_nonprob))
  expect_true(length(result@variables$repweights) > 0L)
})

test_that("doubly-robust Level B path still works after routing refactor", {
  skip_if_not_installed("svrep")

  nps <- suppressWarnings(make_nps_level_b(seed = 2L, n = 200L))
  ref <- make_nps_ref(seed = 102L)

  result <- create_bootstrap_weights(
    nps,
    replicates = 10L,
    type = "quasi-randomization",
    seed = 2L,
    reference_sample = ref
  )

  expect_true(S7::S7_inherits(result, surveycore::survey_nonprob))
  expect_true(length(result@variables$repweights) > 0L)
})

# ============================================================================
# New unified jackknife API (PR 2 — type = "jkn" | "jk1" | "grouped")
# ============================================================================

# ---- Happy paths -----------------------------------------------------------

test_that("create_jackknife_weights() type = 'jkn' returns survey_replicate with @variables$type == 'JKn'", {
  skip_if_not_installed("survey")
  gss_2024_svy <- make_gss_taylor()
  result <- create_jackknife_weights(gss_2024_svy, type = "jkn")
  test_invariants(result)
  expect_true(S7::S7_inherits(result, surveycore::survey_replicate))
  expect_identical(result@variables$type, "JKn")
})

test_that("create_jackknife_weights() type = 'jk1' returns survey_replicate with @variables$type == 'JK1'", {
  skip_if_not_installed("survey")
  # JK1 requires an unstratified design; use a simple SRS
  df_srs <- make_surveywts_data(n = 40L, seed = 10L)
  td_srs <- surveycore::as_survey(df_srs, ids = id, weights = base_weight)
  result <- create_jackknife_weights(td_srs, type = "jk1")
  test_invariants(result)
  expect_true(S7::S7_inherits(result, surveycore::survey_replicate))
  expect_identical(result@variables$type, "JK1")
})

test_that("create_jackknife_weights() type = 'grouped' returns survey_replicate with correct type string", {
  skip_if_not_installed("svrep")
  # Use a design with more PSUs per stratum so svrep can form 4 groups
  td_grp <- make_taylor_design(
    n = 200L,
    n_strata = 4L,
    psus_per_stratum = 10L,
    seed = 1L
  )
  result <- create_jackknife_weights(
    td_grp,
    type = "grouped",
    replicates = 4L,
    seed = 1L
  )
  test_invariants(result)
  expect_true(S7::S7_inherits(result, surveycore::survey_replicate))
  # svrep sets type to "Random-groups jackknife" (the raw svrep type string)
  expect_true(grepl(
    "jackknife|random",
    result@variables$type,
    ignore.case = TRUE
  ))
  expect_identical(length(result@variables$repweights), 4L)
})

# ---- Numerical oracles -----------------------------------------------------

test_that("create_jackknife_weights() jkn replicate count matches survey::as.svrepdesign oracle", {
  skip_if_not_installed("survey")
  gss_2024_svy <- make_gss_taylor()
  direct <- survey::as.svrepdesign(
    surveycore::as_svydesign(gss_2024_svy),
    type = "JKn",
    mse = TRUE
  )
  result <- create_jackknife_weights(gss_2024_svy, type = "jkn")
  expect_identical(
    length(result@variables$repweights),
    ncol(as.matrix(direct$repweights))
  )
})

test_that("create_jackknife_weights() jk1 replicate count matches survey::as.svrepdesign oracle", {
  skip_if_not_installed("survey")
  # JK1 requires an unstratified design
  df_srs <- make_surveywts_data(n = 30L, seed = 20L)
  td_srs <- surveycore::as_survey(df_srs, ids = id, weights = base_weight)
  direct <- survey::as.svrepdesign(
    surveycore::as_svydesign(td_srs),
    type = "JK1",
    mse = TRUE
  )
  result <- create_jackknife_weights(td_srs, type = "jk1")
  expect_identical(
    length(result@variables$repweights),
    ncol(as.matrix(direct$repweights))
  )
})

test_that("create_jackknife_weights() jkn scale factor matches survey::as.svrepdesign oracle", {
  skip_if_not_installed("survey")
  gss_2024_svy <- make_gss_taylor()
  direct <- survey::as.svrepdesign(
    surveycore::as_svydesign(gss_2024_svy),
    type = "JKn",
    mse = TRUE
  )
  result <- create_jackknife_weights(gss_2024_svy, type = "jkn")
  expect_equal(result@variables$scale, direct$scale, tolerance = 1e-10)
})

# ---- History entry structure -----------------------------------------------

test_that("create_jackknife_weights() jkn history entry has operation='replicate_creation', method='jackknife', parameters$type='jkn'", {
  skip_if_not_installed("survey")
  gss_2024_svy <- make_gss_taylor()
  result <- create_jackknife_weights(gss_2024_svy, type = "jkn")
  history <- result@metadata@weighting_history
  entry <- history[[length(history)]]
  expect_identical(entry$operation, "replicate_creation")
  expect_identical(entry$method, "jackknife")
  expect_identical(entry$parameters$type, "jkn")
  expect_true(isTRUE(entry$parameters$mse))
})

test_that("create_jackknife_weights() jk1 history entry has parameters$type='jk1', parameters$mse", {
  skip_if_not_installed("survey")
  # JK1 requires an unstratified design
  df_srs <- make_surveywts_data(n = 30L, seed = 30L)
  td_srs <- surveycore::as_survey(df_srs, ids = id, weights = base_weight)
  result <- create_jackknife_weights(td_srs, type = "jk1")
  history <- result@metadata@weighting_history
  entry <- history[[length(history)]]
  expect_identical(entry$operation, "replicate_creation")
  expect_identical(entry$method, "jackknife")
  expect_identical(entry$parameters$type, "jk1")
  expect_true(isTRUE(entry$parameters$mse))
})

test_that("create_jackknife_weights() grouped+taylor history entry has parameters$type='grouped', parameters$replicates==4L, parameters$mse", {
  skip_if_not_installed("svrep")
  td_grp <- make_taylor_design(
    n = 200L,
    n_strata = 4L,
    psus_per_stratum = 10L,
    seed = 1L
  )
  result <- create_jackknife_weights(
    td_grp,
    type = "grouped",
    replicates = 4L,
    seed = 1L
  )
  history <- result@metadata@weighting_history
  entry <- history[[length(history)]]
  expect_identical(entry$operation, "replicate_creation")
  expect_identical(entry$method, "jackknife")
  expect_identical(entry$parameters$type, "grouped")
  expect_identical(entry$parameters$replicates, 4L)
  expect_true(isTRUE(entry$parameters$mse))
})

# ---- Edge cases (probability paths) ----------------------------------------

test_that("create_jackknife_weights() type = 'jkn' fails on unstratified survey_taylor (backend error)", {
  skip_if_not_installed("survey")
  # survey::as.svrepdesign() requires strata for JKn
  df <- make_surveywts_data(n = 20L, seed = 2L)
  td <- surveycore::as_survey(df, ids = id, weights = base_weight)
  expect_error(create_jackknife_weights(td, type = "jkn"))
})

# ---- Argument behavior (ignored args) --------------------------------------

test_that("replicates is silently ignored for type = 'jkn'", {
  skip_if_not_installed("survey")
  gss_2024_svy <- make_gss_taylor()
  result <- create_jackknife_weights(
    gss_2024_svy,
    type = "jkn",
    replicates = 99L
  )
  expect_true(S7::S7_inherits(result, surveycore::survey_replicate))
  expect_true(length(result@variables$repweights) != 99L)
})

test_that("replicates is silently ignored for type = 'jk1'", {
  skip_if_not_installed("survey")
  # JK1 requires unstratified design; gss_2024_svy is stratified
  df_srs <- make_surveywts_data(n = 30L, seed = 11L)
  td_srs <- surveycore::as_survey(df_srs, ids = id, weights = base_weight)
  result <- create_jackknife_weights(td_srs, type = "jk1", replicates = 99L)
  expect_true(S7::S7_inherits(result, surveycore::survey_replicate))
  expect_true(length(result@variables$repweights) != 99L)
})

test_that("seed is silently ignored for type = 'jkn'", {
  skip_if_not_installed("survey")
  gss_2024_svy <- make_gss_taylor()
  expect_no_error(
    create_jackknife_weights(gss_2024_svy, type = "jkn", seed = 42L)
  )
})

test_that("reference_sample is silently ignored for type = 'jkn'", {
  skip_if_not_installed("survey")
  gss_2024_svy <- make_gss_taylor()
  ref <- make_nps_reference(n = 100L, seed = 1L)
  expect_no_error(
    create_jackknife_weights(gss_2024_svy, type = "jkn", reference_sample = ref)
  )
})

# ---- Error paths (new API) -------------------------------------------------

test_that("create_jackknife_weights() rejects data.frame input (new API)", {
  df <- data.frame(x = 1:5, w = 1)
  expect_error(
    create_jackknife_weights(df, type = "jkn"),
    class = "surveywts_error_not_survey_design"
  )
  expect_snapshot(error = TRUE, create_jackknife_weights(df, type = "jkn"))
})

test_that("create_jackknife_weights() rejects list input (new API)", {
  expect_error(
    create_jackknife_weights(list(x = 1:5, w = 1), type = "jkn"),
    class = "surveywts_error_unsupported_class"
  )
  expect_snapshot(
    error = TRUE,
    create_jackknife_weights(list(x = 1:5, w = 1), type = "jkn")
  )
})

test_that("create_jackknife_weights() rejects survey_nonprob with type = 'jkn'", {
  df <- make_surveywts_data(n = 30L, seed = 1L)
  np <- surveycore::survey_nonprob(
    data = df,
    variables = list(weights = "base_weight"),
    metadata = surveycore::survey_metadata()
  )
  expect_error(
    create_jackknife_weights(np, type = "jkn"),
    class = "surveywts_error_jackknife_type_nonprob_only"
  )
  expect_snapshot(error = TRUE, create_jackknife_weights(np, type = "jkn"))
})

test_that("create_jackknife_weights() rejects survey_nonprob with type = 'jk1'", {
  df <- make_surveywts_data(n = 30L, seed = 1L)
  np <- surveycore::survey_nonprob(
    data = df,
    variables = list(weights = "base_weight"),
    metadata = surveycore::survey_metadata()
  )
  expect_error(
    create_jackknife_weights(np, type = "jk1"),
    class = "surveywts_error_jackknife_type_nonprob_only"
  )
  expect_snapshot(error = TRUE, create_jackknife_weights(np, type = "jk1"))
})

test_that("create_jackknife_weights() errors when type = 'grouped' and replicates = NULL, survey_taylor input", {
  gss_2024_svy <- make_gss_taylor()
  expect_error(
    create_jackknife_weights(gss_2024_svy, type = "grouped"),
    class = "surveywts_error_jackknife_replicates_required"
  )
  expect_snapshot(
    error = TRUE,
    create_jackknife_weights(gss_2024_svy, type = "grouped")
  )
})

test_that("create_jackknife_weights() errors when type = 'grouped' and replicates = NULL, survey_nonprob input", {
  nps <- make_dagjk_datasets()$A
  expect_error(
    create_jackknife_weights(nps, type = "grouped"),
    class = "surveywts_error_jackknife_replicates_required"
  )
  expect_snapshot(error = TRUE, create_jackknife_weights(nps, type = "grouped"))
})

test_that("create_jackknife_weights() errors when ... is non-empty", {
  gss_2024_svy <- make_gss_taylor()
  expect_error(
    create_jackknife_weights(gss_2024_svy, type = "jkn", extra = 1)
  )
})

# ---- Issue #101: creators store finished replicate weights -------------------
# survey and svrep return replication factors (combined.weights = FALSE).
# surveycore reads @variables$repweights as finished weights. Each block below
# checks that the base weight is folded in, so the replicate columns sit on the
# same scale as the base weight column.

test_that("create_bootstrap_weights() stores finished replicate weights", {
  skip_if_not_installed("svrep")
  td <- make_taylor_design(n = 100L, seed = 7L)
  result <- create_bootstrap_weights(td, replicates = 50L, seed = 99L)
  test_invariants(result)

  base_wt <- result@data[[result@variables$weights]]
  rep_mat <- as.matrix(result@data[, result@variables$repweights])

  # Each replicate column totals near the base weight total, not the row count.
  expect_equal(mean(colSums(rep_mat)), sum(base_wt), tolerance = 0.05)
  expect_false(isTRUE(all.equal(mean(colSums(rep_mat)), nrow(rep_mat))))
})

test_that("create_jackknife_weights() type = 'jkn' stores finished replicate weights", {
  skip_if_not_installed("survey")
  td <- make_taylor_design(n = 100L, seed = 7L)
  result <- create_jackknife_weights(td, type = "jkn")
  test_invariants(result)

  base_wt <- result@data[[result@variables$weights]]
  rep_mat <- as.matrix(result@data[, result@variables$repweights])

  # A JKn replicate drops one PSU and inflates the rest, so each column totals
  # close to the base weight total.
  expect_equal(mean(colSums(rep_mat)), sum(base_wt), tolerance = 0.05)
})

test_that("create_brr_weights() stores finished replicate weights", {
  skip_if_not_installed("survey")
  pd <- make_paired_design(seed = 1L)
  result <- create_brr_weights(pd)
  test_invariants(result)

  base_wt <- result@data[[result@variables$weights]]
  rep_mat <- as.matrix(result@data[, result@variables$repweights])

  expect_equal(mean(colSums(rep_mat)), sum(base_wt), tolerance = 0.05)
})

test_that("replicate means track the weighted mean, not the unweighted mean", {
  skip_if_not_installed("survey")
  td <- make_taylor_design(n = 200L, seed = 11L)
  base_wt <- td@data[[td@variables$weights]]
  # make_taylor_design() draws y independent of the base weight, so the
  # weighted and unweighted means agree. Tie y to the base weight to separate
  # them; the wrong convention lands on the unweighted mean.
  td@data$y <- 10 * base_wt
  y <- td@data$y

  weighted_mean <- sum(base_wt * y) / sum(base_wt)
  unweighted_mean <- mean(y)
  expect_gt(abs(weighted_mean - unweighted_mean), 0.5)

  result <- create_bootstrap_weights(td, replicates = 100L, seed = 5L)
  rep_mat <- as.matrix(result@data[, result@variables$repweights])
  rep_means <- colSums(rep_mat * y) / colSums(rep_mat)

  expect_equal(mean(rep_means), weighted_mean, tolerance = 0.02)
  expect_gt(
    abs(mean(rep_means) - unweighted_mean),
    abs(mean(rep_means) - weighted_mean)
  )
})

test_that("bootstrap standard errors match survey's Taylor design", {
  skip_if_not_installed("survey")
  skip_if_not_installed("svrep")
  td <- make_taylor_design(n = 400L, seed = 3L)

  taylor_se <- survey::SE(
    survey::svymean(~y, surveycore::as_svydesign(td))
  )
  result <- create_bootstrap_weights(td, replicates = 500L, seed = 2L)
  rep_se <- survey::SE(
    survey::svymean(~y, surveycore::as_svydesign(result))
  )

  # Bootstrap and Taylor are different estimators; 25% is a loose band that
  # still fails by orders of magnitude when the convention is wrong.
  expect_equal(as.numeric(rep_se), as.numeric(taylor_se), tolerance = 0.25)
})

test_that("as_svydesign() on a creator result does not warn about combined weights", {
  skip_if_not_installed("svrep")
  td <- make_taylor_design(n = 100L, seed = 7L)
  result <- create_bootstrap_weights(td, replicates = 50L, seed = 99L)

  expect_no_warning(surveycore::as_svydesign(result))
})
