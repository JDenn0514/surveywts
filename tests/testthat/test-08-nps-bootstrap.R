# test-08-nps-bootstrap.R
# Full test suite for NPS bootstrap (quasi-randomization type).
# PR 2: all blocks from plans/spec-nps-bootstrap.md §X.

# ============================================================================
# Smoke test (PR 1 preserved)
# ============================================================================

test_that("NPS bootstrap helper functions return survey_nonprob with ipw history", {
  ref   <- suppressWarnings(make_nps_ref(seed = 42))
  lev_a <- suppressWarnings(make_nps_level_a(seed = 1))
  lev_b <- suppressWarnings(make_nps_level_b(seed = 2))

  expect_true(!is.null(ref))
  expect_true(!is.null(lev_a))
  expect_true(!is.null(lev_b))

  for (obj in list(lev_a, lev_b)) {
    ops <- vapply(obj@metadata@weighting_history, `[[`, character(1), "operation")
    expect_true("ipw" %in% ops)
  }
})

# ============================================================================
# Block 1: Level A happy path
# ============================================================================

test_that("create_bootstrap_weights() quasi-randomization Level A returns survey_nonprob", {
  skip_if_not_installed("svrep")
  lev_a  <- suppressWarnings(make_nps_level_a(seed = 1))
  result <- suppressWarnings(create_bootstrap_weights(
    lev_a,
    type       = "quasi-randomization",
    replicates = 50L,
    seed       = 1L
  ))

  test_invariants(result)
  expect_true(S7::S7_inherits(result, surveycore::survey_nonprob))

  # 50 repwt_* columns present, all numeric, all positive
  expect_identical(length(result@variables$repweights), 50L)
  expect_identical(result@variables$repweights, paste0("repwt_", 1:50))
  for (col in result@variables$repweights) {
    v <- result@data[[col]]
    expect_true(is.numeric(v))
    expect_true(all(v > 0))
  }

  # @variables$weights unchanged
  expect_identical(result@variables$weights, lev_a@variables$weights)

  # History has one new bootstrap_weights entry
  n_before <- length(lev_a@metadata@weighting_history)
  n_after  <- length(result@metadata@weighting_history)
  expect_identical(n_after, n_before + 1L)
  boot_entry <- result@metadata@weighting_history[[n_after]]
  expect_identical(boot_entry$operation, "bootstrap_weights")
  expect_identical(boot_entry$type, "quasi-randomization")
  expect_identical(boot_entry$replicates, 50L)
  expect_identical(boot_entry$level, "A")
})

# ============================================================================
# Block 2: Level B happy path
# ============================================================================

test_that("create_bootstrap_weights() quasi-randomization Level B records level = B", {
  skip_if_not_installed("svrep")
  lev_b  <- suppressWarnings(make_nps_level_b(seed = 2))
  result <- suppressWarnings(create_bootstrap_weights(
    lev_b,
    type       = "quasi-randomization",
    replicates = 50L,
    seed       = 2L
  ))

  test_invariants(result)
  boot_entry <- result@metadata@weighting_history[[
    length(result@metadata@weighting_history)
  ]]
  expect_identical(boot_entry$level, "B")
  # draws_used may be < replicates if some draws fail due to resampling;
  # assert the count is consistent with the history entry.
  expect_identical(
    length(result@variables$repweights),
    boot_entry$draws_used
  )
  expect_true(length(result@variables$repweights) >= 1L)
})

# ============================================================================
# Block 3: replicates = NULL default resolution
# ============================================================================

test_that("create_bootstrap_weights() NULL replicates resolves to 200L for NPS types", {
  skip_if_not_installed("svrep")
  lev_a  <- suppressWarnings(make_nps_level_a(seed = 1))
  result <- suppressWarnings(create_bootstrap_weights(
    lev_a,
    type = "quasi-randomization",
    seed = 42L
  ))

  boot_entry <- result@metadata@weighting_history[[
    length(result@metadata@weighting_history)
  ]]
  expect_identical(boot_entry$replicates, 200L)
  expect_identical(length(result@variables$repweights), boot_entry$draws_used)
})

test_that("create_bootstrap_weights() NULL replicates resolves to 500L for Rao-Wu", {
  skip_if_not_installed("svrep")
  td      <- make_taylor_design(seed = 1)
  result  <- create_bootstrap_weights(td, type = "Rao-Wu", seed = 1L)
  history <- result@metadata@weighting_history
  expect_identical(history[[length(history)]]$parameters$replicates, 500L)
})

# ============================================================================
# Block 4: seed reproducibility
# ============================================================================

test_that("create_bootstrap_weights() same seed produces identical NPS repwt columns", {
  skip_if_not_installed("svrep")
  lev_a <- suppressWarnings(make_nps_level_a(seed = 1))
  r1    <- suppressWarnings(create_bootstrap_weights(
    lev_a, type = "quasi-randomization", replicates = 20L, seed = 7L
  ))
  r2    <- suppressWarnings(create_bootstrap_weights(
    lev_a, type = "quasi-randomization", replicates = 20L, seed = 7L
  ))

  mat1 <- as.matrix(r1@data[, r1@variables$repweights])
  mat2 <- as.matrix(r2@data[, r2@variables$repweights])
  expect_equal(mat1, mat2, tolerance = 1e-10)
})

test_that("create_bootstrap_weights() different seeds produce different NPS repwt columns", {
  skip_if_not_installed("svrep")
  lev_a <- suppressWarnings(make_nps_level_a(seed = 1))
  r1    <- suppressWarnings(create_bootstrap_weights(
    lev_a, type = "quasi-randomization", replicates = 20L, seed = 7L
  ))
  r2    <- suppressWarnings(create_bootstrap_weights(
    lev_a, type = "quasi-randomization", replicates = 20L, seed = 99L
  ))

  mat1 <- as.matrix(r1@data[, r1@variables$repweights])
  mat2 <- as.matrix(r2@data[, r2@variables$repweights])
  expect_false(isTRUE(all.equal(mat1, mat2)))
})

# ============================================================================
# Block 5: reference_sample override
# ============================================================================

test_that("create_bootstrap_weights() reference_sample overrides stored reference", {
  skip_if_not_installed("svrep")
  lev_a <- suppressWarnings(make_nps_level_a(seed = 1))
  ref_a <- make_nps_ref(seed = 101)  # same ref seed used in make_nps_level_a(seed=1)
  ref_b <- make_nps_ref(seed = 999)  # very different reference

  r1 <- suppressWarnings(create_bootstrap_weights(
    lev_a,
    type             = "quasi-randomization",
    replicates       = 20L,
    seed             = 42L,
    reference_sample = ref_a
  ))
  r2 <- suppressWarnings(create_bootstrap_weights(
    lev_a,
    type             = "quasi-randomization",
    replicates       = 20L,
    seed             = 42L,
    reference_sample = ref_b
  ))

  mat1 <- as.matrix(r1@data[, r1@variables$repweights])
  mat2 <- as.matrix(r2@data[, r2@variables$repweights])
  expect_false(isTRUE(all.equal(mat1, mat2)))
})

# ============================================================================
# Block 6: probability-sample types regression guard
# ============================================================================

test_that("create_bootstrap_weights() Rao-Wu on survey_taylor still works after signature change", {
  skip_if_not_installed("svrep")
  td     <- make_taylor_design(seed = 1)
  result <- create_bootstrap_weights(
    td, type = "Rao-Wu", replicates = 20L, seed = 1L
  )
  test_invariants(result)
  expect_true(S7::S7_inherits(result, surveycore::survey_replicate))
})

# ============================================================================
# Block 7: Level A vs Level B differential
# ============================================================================

test_that("create_bootstrap_weights() Level A and Level B produce different repwt columns", {
  skip_if_not_installed("svrep")
  lev_a <- suppressWarnings(make_nps_level_a(seed = 3))
  lev_b <- suppressWarnings(make_nps_level_b(seed = 3))

  r_a <- suppressWarnings(create_bootstrap_weights(
    lev_a, type = "quasi-randomization", replicates = 20L, seed = 77L
  ))
  r_b <- suppressWarnings(create_bootstrap_weights(
    lev_b, type = "quasi-randomization", replicates = 20L, seed = 77L
  ))

  boot_a <- r_a@metadata@weighting_history[[
    length(r_a@metadata@weighting_history)
  ]]
  boot_b <- r_b@metadata@weighting_history[[
    length(r_b@metadata@weighting_history)
  ]]
  expect_identical(boot_a$level, "A")
  expect_identical(boot_b$level, "B")

  # Repwt columns should differ between Level A and Level B
  n_cols <- min(
    length(r_a@variables$repweights),
    length(r_b@variables$repweights)
  )
  mat_a <- as.matrix(r_a@data[, r_a@variables$repweights[seq_len(n_cols)]])
  mat_b <- as.matrix(r_b@data[, r_b@variables$repweights[seq_len(n_cols)]])
  expect_false(isTRUE(all.equal(mat_a, mat_b)))
})

# ============================================================================
# Block 8: print snapshot with repweights
# ============================================================================

test_that("print(survey_nonprob) includes bootstrap replicates line when repweights present", {
  skip_if_not_installed("svrep")
  lev_a  <- suppressWarnings(make_nps_level_a(seed = 1))
  result <- suppressWarnings(create_bootstrap_weights(
    lev_a,
    type       = "quasi-randomization",
    replicates = 10L,
    seed       = 1L
  ))
  expect_snapshot(print(.pin_ts(result)))
})

# ============================================================================
# Block 9: print snapshot without repweights
# ============================================================================

test_that("print(survey_nonprob) unchanged when no repweights", {
  lev_a <- suppressWarnings(make_nps_level_a(seed = 1))
  expect_snapshot(print(.pin_ts(lev_a)))
})

# ============================================================================
# Block 10: second-call overwrite warning
# ============================================================================

test_that("create_bootstrap_weights() warns and overwrites on second call", {
  skip_if_not_installed("svrep")
  lev_a <- suppressWarnings(make_nps_level_a(seed = 1))
  r1    <- suppressWarnings(create_bootstrap_weights(
    lev_a, type = "quasi-randomization", replicates = 20L, seed = 1L
  ))

  # suppress all OTHER warnings (ipw convergence etc.) but let testthat
  # capture surveywts_warning_repweights_overwritten via expect_warning().
  result <- NULL
  expect_warning(
    result <- withCallingHandlers(
      create_bootstrap_weights(
        r1, type = "quasi-randomization", replicates = 10L, seed = 2L
      ),
      warning = function(w) {
        if (!inherits(w, "surveywts_warning_repweights_overwritten")) {
          invokeRestart("muffleWarning")
        }
      }
    ),
    class = "surveywts_warning_repweights_overwritten"
  )

  expect_identical(length(result@variables$repweights), 10L)
})

# ============================================================================
# Error-path tests (dual pattern)
# ============================================================================

# E1: survey_taylor + quasi-randomization
test_that("create_bootstrap_weights() rejects survey_taylor with quasi-randomization", {
  td <- make_taylor_design(seed = 1)
  expect_error(
    create_bootstrap_weights(td, type = "quasi-randomization"),
    class = "surveywts_error_qr_bootstrap_requires_nonprob"
  )
  expect_snapshot(
    error = TRUE,
    create_bootstrap_weights(td, type = "quasi-randomization")
  )
})

# E2: weighted_df + quasi-randomization
test_that("create_bootstrap_weights() rejects weighted_df with quasi-randomization", {
  df <- make_surveywts_data(seed = 1)
  wd <- calibrate_rake(df, targets = list(
    age_group = c("18-34" = 0.30, "35-54" = 0.40, "55+" = 0.30),
    sex       = c("M" = 0.48, "F" = 0.52)
  ))
  expect_error(
    create_bootstrap_weights(wd, type = "quasi-randomization"),
    class = "surveywts_error_qr_bootstrap_requires_nonprob"
  )
  expect_snapshot(
    error = TRUE,
    create_bootstrap_weights(wd, type = "quasi-randomization")
  )
})

# E3: survey_taylor + hybrid
test_that("create_bootstrap_weights() rejects survey_taylor with hybrid", {
  td <- make_taylor_design(seed = 1)
  expect_error(
    create_bootstrap_weights(td, type = "hybrid"),
    class = "surveywts_error_hybrid_bootstrap_requires_nonprob"
  )
  expect_snapshot(
    error = TRUE,
    create_bootstrap_weights(td, type = "hybrid")
  )
})

# E4: survey_nonprob with no ipw history
test_that("create_bootstrap_weights() errors when no ipw history present", {
  df <- make_surveywts_data(seed = 1)
  np_no_ipw <- surveycore::survey_nonprob(
    data      = df,
    variables = list(weights = "base_weight"),
    metadata  = surveycore::survey_metadata()
  )
  expect_error(
    create_bootstrap_weights(np_no_ipw, type = "quasi-randomization"),
    class = "surveywts_error_qr_bootstrap_no_ipw_history"
  )
  expect_snapshot(
    error = TRUE,
    create_bootstrap_weights(np_no_ipw, type = "quasi-randomization")
  )
})

# E5: survey_nonprob with ipw but reference_design = NULL and no reference_sample
test_that("create_bootstrap_weights() errors when no reference available", {
  df  <- make_surveywts_data(seed = 1)
  ref <- make_nps_ref(seed = 42)
  ipw_result <- suppressWarnings(ipw(
    data      = df,
    reference = ref,
    selection = ~age_group + sex
  ))
  # Force reference_design to NULL in the history entry
  meta <- ipw_result@metadata
  meta@weighting_history[[1L]]$reference_design <- NULL
  ipw_result@metadata <- meta

  expect_error(
    create_bootstrap_weights(ipw_result, type = "quasi-randomization"),
    class = "surveywts_error_qr_bootstrap_no_reference"
  )
  expect_snapshot(
    error = TRUE,
    create_bootstrap_weights(ipw_result, type = "quasi-randomization")
  )
})

# E6: survey_nonprob + hybrid
test_that("create_bootstrap_weights() errors with hybrid type (not yet implemented)", {
  df <- make_surveywts_data(seed = 1)
  np <- surveycore::survey_nonprob(
    data      = df,
    variables = list(weights = "base_weight"),
    metadata  = surveycore::survey_metadata()
  )
  expect_error(
    create_bootstrap_weights(np, type = "hybrid"),
    class = "surveywts_error_hybrid_bootstrap_not_implemented"
  )
  expect_snapshot(
    error = TRUE,
    create_bootstrap_weights(np, type = "hybrid")
  )
})

# E7: reference_sample is survey_replicate
test_that("create_bootstrap_weights() rejects survey_replicate as reference_sample", {
  skip_if_not_installed("svrep")
  lev_a   <- suppressWarnings(make_nps_level_a(seed = 1))
  td      <- make_taylor_design(seed = 1)
  rep_ref <- create_bootstrap_weights(td, replicates = 10L, seed = 1L)

  expect_error(
    create_bootstrap_weights(
      lev_a,
      type             = "quasi-randomization",
      reference_sample = rep_ref
    ),
    class = "surveywts_error_reference_sample_class"
  )
  expect_snapshot(
    error = TRUE,
    create_bootstrap_weights(
      lev_a,
      type             = "quasi-randomization",
      reference_sample = rep_ref
    )
  )
})

# E8: reference_sample is list()
test_that("create_bootstrap_weights() rejects list as reference_sample", {
  lev_a <- suppressWarnings(make_nps_level_a(seed = 1))
  expect_error(
    create_bootstrap_weights(
      lev_a,
      type             = "quasi-randomization",
      reference_sample = list()
    ),
    class = "surveywts_error_reference_sample_class"
  )
  expect_snapshot(
    error = TRUE,
    create_bootstrap_weights(
      lev_a,
      type             = "quasi-randomization",
      reference_sample = list()
    )
  )
})

# E9: mse = "chrostowski" with probability-sample type
test_that("create_bootstrap_weights() rejects mse = chrostowski for prob-sample type", {
  skip_if_not_installed("svrep")
  td <- make_taylor_design(seed = 1)
  expect_error(
    create_bootstrap_weights(
      td,
      type = "Rao-Wu",
      mse  = "chrostowski"
    ),
    class = "surveywts_error_chrostowski_prob_sample"
  )
  expect_snapshot(
    error = TRUE,
    create_bootstrap_weights(
      td,
      type = "Rao-Wu",
      mse  = "chrostowski"
    )
  )
})

# E10: mse = TRUE (legacy logical TRUE)
test_that("create_bootstrap_weights() rejects mse = TRUE (logical not character)", {
  td <- make_taylor_design(seed = 1)
  expect_error(
    create_bootstrap_weights(td, mse = TRUE),
    class = "surveywts_error_mse_not_character"
  )
  expect_snapshot(
    error = TRUE,
    create_bootstrap_weights(td, mse = TRUE)
  )
})

# E11: mse = FALSE (legacy logical FALSE)
test_that("create_bootstrap_weights() rejects mse = FALSE (logical not character)", {
  td <- make_taylor_design(seed = 1)
  expect_error(
    create_bootstrap_weights(td, mse = FALSE),
    class = "surveywts_error_mse_not_character"
  )
  expect_snapshot(
    error = TRUE,
    create_bootstrap_weights(td, mse = FALSE)
  )
})

# ============================================================================
# Warning-path tests
# ============================================================================

# W1: reference_sample supplied with prob-sample type
test_that("create_bootstrap_weights() warns reference_sample ignored for prob-sample type", {
  skip_if_not_installed("svrep")
  td  <- make_taylor_design(seed = 1)
  ref <- make_nps_ref(seed = 42)

  expect_warning(
    result <- create_bootstrap_weights(
      td,
      type             = "Rao-Wu",
      replicates       = 10L,
      seed             = 1L,
      reference_sample = ref
    ),
    class = "surveywts_warning_reference_sample_ignored"
  )
  test_invariants(result)
})

# W2: >10% draws fail
test_that("create_bootstrap_weights() warns when >10% draws fail", {
  skip_if_not_installed("svrep")
  # 5-row raked NPS: 4 rows without "55+", 1 with "55+".
  # P(missing "55+" in SRSWR of 5) = (4/5)^5 ≈ 33%.
  # With B=20 and fixed margins requiring "55+", rake() fails in those draws.
  # seed=42 gives ~9/20 failures (>10%), triggering the warning.
  ref_df <- make_surveywts_data(n = 200L, seed = 42L)
  ref    <- surveycore::as_survey(ref_df, weights = base_weight)

  nps_df <- data.frame(
    age_group = c("18-34", "18-34", "35-54", "35-54", "55+"),
    sex       = c("M", "F", "M", "F", "M"),
    stringsAsFactors = FALSE
  )
  nps_ipw <- suppressWarnings(ipw(
    data      = nps_df,
    reference = ref,
    selection = ~age_group
  ))
  nps_raked <- suppressWarnings(calibrate_rake(
    nps_ipw,
    targets = list(
      age_group = c("18-34" = 0.35, "35-54" = 0.40, "55+" = 0.25)
    ),
    type = "prop"
  ))

  result <- NULL
  expect_warning(
    result <- withCallingHandlers(
      create_bootstrap_weights(
        nps_raked,
        type       = "quasi-randomization",
        replicates = 20L,
        seed       = 42L
      ),
      warning = function(w) {
        if (!inherits(w, "surveywts_warning_bootstrap_draws_failed")) {
          invokeRestart("muffleWarning")
        }
      }
    ),
    class = "surveywts_warning_bootstrap_draws_failed"
  )
  expect_true(length(result@variables$repweights) > 0L)
})

# ============================================================================
# Edge-case tests
# ============================================================================

# EC1: Very small NPS (n = 10)
test_that("create_bootstrap_weights() completes on very small NPS (n = 10)", {
  skip_if_not_installed("svrep")
  lev_a_small <- suppressWarnings(make_nps_level_a(seed = 99, n = 10))
  result <- suppressWarnings(create_bootstrap_weights(
    lev_a_small,
    type       = "quasi-randomization",
    replicates = 20L,
    seed       = 1L
  ))
  expect_true(S7::S7_inherits(result, surveycore::survey_nonprob))
  expect_true(length(result@variables$repweights) > 0L)
})

# EC2: All draws fail
test_that("create_bootstrap_weights() errors when all draws fail", {
  skip_if_not_installed("svrep")
  # 3-row raked NPS: exactly 1 of each age group.
  # SRSWR of n=3 covers all 3 groups with probability 6/27 ≈ 22% per draw.
  # seed=8 gives 10/10 resamples that drop at least 1 group, so rake() fails
  # in every draw → surveywts_error_bootstrap_all_draws_failed.
  ref_df <- make_surveywts_data(n = 200L, seed = 42L)
  ref    <- surveycore::as_survey(ref_df, weights = base_weight)

  nps_df <- data.frame(
    age_group = c("18-34", "35-54", "55+"),
    sex       = c("M", "F", "M"),
    stringsAsFactors = FALSE
  )
  nps_ipw <- suppressWarnings(ipw(
    data      = nps_df,
    reference = ref,
    selection = ~age_group
  ))
  nps_raked <- suppressWarnings(calibrate_rake(
    nps_ipw,
    targets = list(
      age_group = c("18-34" = 0.35, "35-54" = 0.40, "55+" = 0.25)
    ),
    type = "prop"
  ))

  expect_error(
    suppressWarnings(create_bootstrap_weights(
      nps_raked,
      type       = "quasi-randomization",
      replicates = 10L,
      seed       = 8L
    )),
    class = "surveywts_error_bootstrap_all_draws_failed"
  )
  expect_snapshot(
    error = TRUE,
    suppressWarnings(create_bootstrap_weights(
      nps_raked,
      type       = "quasi-randomization",
      replicates = 10L,
      seed       = 8L
    ))
  )
})

# EC3: mse variants stored correctly in history
test_that("create_bootstrap_weights() stores mse string correctly in history", {
  skip_if_not_installed("svrep")
  lev_a <- suppressWarnings(make_nps_level_a(seed = 1))

  for (mse_val in c("mse", "chrostowski", "uncentered")) {
    result <- suppressWarnings(create_bootstrap_weights(
      lev_a,
      type       = "quasi-randomization",
      replicates = 10L,
      seed       = 1L,
      mse        = mse_val
    ))
    boot_entry <- result@metadata@weighting_history[[
      length(result@metadata@weighting_history)
    ]]
    expect_identical(boot_entry$mse, mse_val)
  }
})

# EC4: seed = NULL completes without error
test_that("create_bootstrap_weights() completes with seed = NULL", {
  skip_if_not_installed("svrep")
  lev_a  <- suppressWarnings(make_nps_level_a(seed = 1))
  result <- suppressWarnings(create_bootstrap_weights(
    lev_a,
    type       = "quasi-randomization",
    replicates = 10L,
    seed       = NULL
  ))
  expect_true(S7::S7_inherits(result, surveycore::survey_nonprob))
  expect_identical(length(result@variables$repweights), 10L)
})

# EC5: ipw-only (no calibration in history) — Level A
test_that("create_bootstrap_weights() works on ipw-only NPS (no calibration step)", {
  skip_if_not_installed("svrep")
  df      <- make_surveywts_data(seed = 1)
  ref     <- make_nps_ref(seed = 101)
  nps_ipw <- suppressWarnings(ipw(
    data      = df,
    reference = ref,
    selection = ~age_group + sex
  ))

  result <- suppressWarnings(create_bootstrap_weights(
    nps_ipw,
    type       = "quasi-randomization",
    replicates = 10L,
    seed       = 1L
  ))

  test_invariants(result)
  boot_entry <- result@metadata@weighting_history[[
    length(result@metadata@weighting_history)
  ]]
  expect_identical(boot_entry$level, "A")
})

# ============================================================================
# History entry structure test
# ============================================================================

# H1: All history fields correct
test_that("create_bootstrap_weights() history entry has all required fields", {
  skip_if_not_installed("svrep")
  lev_a  <- suppressWarnings(make_nps_level_a(seed = 1))
  result <- suppressWarnings(create_bootstrap_weights(
    lev_a,
    type       = "quasi-randomization",
    replicates = 30L,
    seed       = 42L,
    mse        = "chrostowski"
  ))

  n     <- length(result@metadata@weighting_history)
  entry <- result@metadata@weighting_history[[n]]

  expect_identical(entry$operation, "bootstrap_weights")
  expect_identical(entry$type, "quasi-randomization")
  expect_identical(entry$replicates, 30L)
  expect_true(is.integer(entry$draws_used))
  expect_true(entry$draws_used <= 30L)
  expect_identical(entry$level, "A")
  expect_identical(entry$mse, "chrostowski")
  expect_identical(entry$seed, 42L)
  expect_true(inherits(entry$timestamp, "POSIXct"))
  expect_identical(entry$step, n)
})

# ============================================================================
# Numerical correctness test
# ============================================================================

# N1: Bootstrap SE within expected range
test_that("create_bootstrap_weights() quasi-randomization SE is within reasonable range", {
  skip_if_not_installed("svrep")
  skip_on_cran()

  set.seed(100L)
  n_pop <- 2000L
  pop   <- data.frame(
    x = as.character(rbinom(n_pop, 1L, prob = 0.5)),
    y = rnorm(n_pop, mean = 5, sd = 1),
    stringsAsFactors = FALSE
  )

  # Reference (random sample of 500)
  ref_idx <- sample(n_pop, 500L)
  ref_df  <- pop[ref_idx, ]
  ref_df$w <- 1
  ref <- surveycore::as_survey(ref_df, weights = w)

  # NPS: biased sample of 200 (oversamples x="1")
  nps_idx <- c(
    sample(which(pop$x == "1"), 120L, replace = FALSE),
    sample(which(pop$x == "0"), 80L,  replace = FALSE)
  )
  nps_df <- pop[nps_idx, ]

  nps_ipw <- suppressWarnings(ipw(
    data      = nps_df,
    reference = ref,
    selection = ~x
  ))

  B      <- 200L
  result <- suppressWarnings(create_bootstrap_weights(
    nps_ipw,
    type       = "quasi-randomization",
    replicates = B,
    seed       = 7L
  ))

  # Full-sample IPW estimate
  wts     <- result@data[[result@variables$weights]]
  est_hat <- sum(wts * result@data$y) / sum(wts)

  # Bootstrap SEs per replicate
  repwt_cols <- result@variables$repweights
  theta_b <- vapply(repwt_cols, function(col) {
    w_b <- result@data[[col]]
    sum(w_b * result@data$y) / sum(w_b)
  }, numeric(1L))

  boot_se <- sqrt(mean((theta_b - est_hat)^2))

  # Naive SE based on sample SD
  n_nps   <- nrow(result@data)
  theo_se <- sd(result@data$y) / sqrt(n_nps)

  # IPW compression means boot_se is often < naive theo_se. Check it is
  # non-trivial (> 0) and not wildly inflated (< 5 * theo_se).
  expect_true(boot_se > 0)
  expect_true(boot_se < 5 * theo_se)
})

# ============================================================================
# Coverage gap tests (BLOCK-3)
# ============================================================================

# CG1: .validate_replicates_arg(NULL) early return (line 54)
test_that(".validate_replicates_arg(NULL) returns NULL", {
  result <- surveywts:::.validate_replicates_arg(NULL)
  expect_null(result)
})

# CG2: missing_method = "separate" reversion in draw loop (lines 350-360)
test_that("create_bootstrap_weights() handles NPS built with missing_method = 'separate'", {
  skip_if_not_installed("svrep")
  df  <- make_surveywts_data(seed = 1)
  # Introduce NAs in age_group for some rows so missing_method = "separate" matters
  df$age_group[sample(nrow(df), 20)] <- NA
  ref <- make_nps_ref(seed = 101)

  nps_sep <- suppressWarnings(ipw(
    data           = df,
    reference      = ref,
    selection      = ~age_group + sex,
    missing_method = "separate"
  ))

  result <- suppressWarnings(create_bootstrap_weights(
    nps_sep,
    type       = "quasi-randomization",
    replicates = 20L,
    seed       = 1L
  ))

  test_invariants(result)
  expect_true(S7::S7_inherits(result, surveycore::survey_nonprob))
  expect_true(length(result@variables$repweights) >= 1L)
  boot_entry <- result@metadata@weighting_history[[
    length(result@metadata@weighting_history)
  ]]
  expect_identical(boot_entry$operation, "bootstrap_weights")
})

# CG3: calibrate() else branch in draw loop (lines 418-425)
# NPS weighting history has calibrate() (operation = "calibration") not rake()
test_that("create_bootstrap_weights() handles NPS built with calibrate() instead of rake()", {
  skip_if_not_installed("svrep")
  df  <- make_surveywts_data(seed = 3)
  ref <- make_nps_ref(seed = 103)

  nps_ipw <- suppressWarnings(ipw(
    data      = df,
    reference = ref,
    selection = ~age_group + sex
  ))

  # Use calibrate_greg() so the history entry has operation = "calibrate_greg",
  # exercising the else branch in the draw loop
  pop_targets <- list(
    age_group = c("18-34" = 0.35, "35-54" = 0.40, "55+" = 0.25),
    sex       = c("M" = 0.49, "F" = 0.51)
  )
  nps_calibrated <- suppressWarnings(calibrate_greg(
    nps_ipw,
    targets = pop_targets,
    type    = "prop"
  ))

  result <- suppressWarnings(create_bootstrap_weights(
    nps_calibrated,
    type       = "quasi-randomization",
    replicates = 20L,
    seed       = 3L
  ))

  test_invariants(result)
  expect_true(S7::S7_inherits(result, surveycore::survey_nonprob))
  expect_true(length(result@variables$repweights) >= 1L)
  boot_entry <- result@metadata@weighting_history[[
    length(result@metadata@weighting_history)
  ]]
  expect_identical(boot_entry$operation, "bootstrap_weights")
  expect_identical(boot_entry$level, "A")
})

# CG4: type = "count" branch in .reestimate_margins_from_reference() (lines 549-552)
# Level B bootstrap with rake(..., type = "count", reference_design = ref)
test_that("create_bootstrap_weights() Level B with type = 'count' margins re-estimates correctly", {
  skip_if_not_installed("svrep")
  df  <- make_surveywts_data(seed = 5)
  ref <- make_nps_ref(seed = 105)

  nps_ipw <- suppressWarnings(ipw(
    data      = df,
    reference = ref,
    selection = ~age_group + sex
  ))

  # rake with type = "count" and reference_design → Level B, count margins
  # Population counts from reference design
  ref_wts <- ref@data[[ref@variables$weights]]
  ref_age <- as.character(ref@data$age_group)
  ref_sex <- as.character(ref@data$sex)
  count_margins <- list(
    age_group = c(
      "18-34" = sum(ref_wts[ref_age == "18-34"]),
      "35-54" = sum(ref_wts[ref_age == "35-54"]),
      "55+"   = sum(ref_wts[ref_age == "55+"])
    ),
    sex = c(
      "M" = sum(ref_wts[ref_sex == "M"]),
      "F" = sum(ref_wts[ref_sex == "F"])
    )
  )

  nps_raked_count <- suppressWarnings(calibrate_rake(
    nps_ipw,
    targets          = count_margins,
    type             = "count",
    reference_design = ref
  ))

  result <- suppressWarnings(create_bootstrap_weights(
    nps_raked_count,
    type       = "quasi-randomization",
    replicates = 20L,
    seed       = 5L
  ))

  test_invariants(result)
  expect_true(S7::S7_inherits(result, surveycore::survey_nonprob))
  expect_true(length(result@variables$repweights) >= 1L)
  # Verify Level B is detected (targets_from_reference = TRUE)
  boot_entry <- result@metadata@weighting_history[[
    length(result@metadata@weighting_history)
  ]]
  expect_identical(boot_entry$level, "B")
  # Repwt columns are present and numeric
  for (col in result@variables$repweights) {
    expect_true(is.numeric(result@data[[col]]))
  }
})
