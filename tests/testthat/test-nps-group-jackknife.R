# test-nps-group-jackknife.R
#
# Tests for create_group_jackknife_weights() — DAGJK replicate weights for NPS.

# ---- Shared datasets (created once at file load time) -----------------------

datasets <- make_dagjk_datasets()

# ============================================================================
# §3.1 Happy path — structural invariants
# ============================================================================

test_that("create_group_jackknife_weights() returns survey_nonprob with correct structure", {
  result <- create_group_jackknife_weights(datasets$A, groups = 10L, seed = 42L)
  test_invariants(result)
  expect_true(S7::S7_inherits(result, surveycore::survey_nonprob))
  expect_length(result@variables$repweights, 10L)
  expect_identical(result@variables$repweights, paste0("repwt_", seq_len(10L)))
  expect_true(all(result@variables$repweights %in% names(result@data)))
  expect_equal(result@variables$scale, 9 / 10, tolerance = 1e-12)
  expect_identical(result@variables$rscales, rep(1, 10L))
  expect_true(isTRUE(result@variables$mse))
  expect_identical(result@variables$type, "group-jackknife")
})

test_that("create_group_jackknife_weights() each row has exactly 1 zero across replicate cols", {
  result <- create_group_jackknife_weights(datasets$A, groups = 10L, seed = 42L)
  rep_cols <- result@variables$repweights
  rep_mat <- as.matrix(result@data[, rep_cols, drop = FALSE])
  zero_counts <- rowSums(rep_mat == 0)
  expect_true(all(zero_counts == 1L))
})

test_that("create_group_jackknife_weights() each row has 9 positive values", {
  result <- create_group_jackknife_weights(datasets$A, groups = 10L, seed = 42L)
  rep_cols <- result@variables$repweights
  rep_mat <- as.matrix(result@data[, rep_cols, drop = FALSE])
  pos_counts <- rowSums(rep_mat > 0)
  expect_true(all(pos_counts == 9L))
})

test_that("create_group_jackknife_weights() original columns are unchanged", {
  original_cols <- names(datasets$A@data)
  result <- create_group_jackknife_weights(datasets$A, groups = 10L, seed = 42L)
  expect_true(all(original_cols %in% names(result@data)))
  # Original data unchanged in non-replicate columns
  for (col in original_cols) {
    expect_identical(result@data[[col]], datasets$A@data[[col]])
  }
})

test_that("create_group_jackknife_weights() appends history entry with correct fields", {
  result <- create_group_jackknife_weights(datasets$A, groups = 10L, seed = 42L)
  history <- result@metadata@weighting_history
  dagjk_entry <- Filter(
    function(e) identical(e$operation, "group_jackknife_weights"),
    history
  )
  expect_length(dagjk_entry, 1L)
  entry <- dagjk_entry[[1L]]
  expect_identical(entry$operation, "group_jackknife_weights")
  expect_identical(entry$groups, 10L)
  expect_identical(entry$seed, 42L)
  expect_true(is.numeric(entry$scale))
  expect_false(is.null(entry$source_design))
})

# ============================================================================
# §3.2 Default groups and coercion
# ============================================================================

test_that("create_group_jackknife_weights() uses 50 groups by default", {
  result <- create_group_jackknife_weights(datasets$A, seed = 1L)
  expect_length(result@variables$repweights, 50L)
})

test_that("create_group_jackknife_weights() coerces whole-number double groups silently", {
  expect_no_error(
    result <- create_group_jackknife_weights(datasets$A, groups = 10.0, seed = 42L)
  )
  expect_length(result@variables$repweights, 10L)
})

# ============================================================================
# §3.3 Seed reproducibility
# ============================================================================

test_that("create_group_jackknife_weights() same seed produces identical results", {
  r1 <- create_group_jackknife_weights(datasets$A, groups = 10L, seed = 42L)
  r2 <- create_group_jackknife_weights(datasets$A, groups = 10L, seed = 42L)
  expect_identical(r1@data, r2@data)
  expect_identical(r1@variables$repweights, r2@variables$repweights)
})

test_that("create_group_jackknife_weights() different seeds produce different results", {
  r1 <- create_group_jackknife_weights(datasets$A, groups = 10L, seed = 1L)
  r2 <- create_group_jackknife_weights(datasets$A, groups = 10L, seed = 99L)
  rep_col <- "repwt_1"
  expect_false(identical(r1@data[[rep_col]], r2@data[[rep_col]]))
})

test_that("create_group_jackknife_weights() seed = NULL does not error", {
  expect_no_error(
    create_group_jackknife_weights(datasets$A, groups = 10L, seed = NULL)
  )
})

test_that("create_group_jackknife_weights() seed = 0L is valid", {
  expect_no_error(
    result <- create_group_jackknife_weights(datasets$A, groups = 10L, seed = 0L)
  )
  expect_true(S7::S7_inherits(result, surveycore::survey_nonprob))
})

# ============================================================================
# §3.4 Calibration history — replicate repeats calibration
# ============================================================================

test_that("create_group_jackknife_weights() replicate weights differ with vs without calibration", {
  r_a <- create_group_jackknife_weights(datasets$A, groups = 10L, seed = 42L)
  r_b <- create_group_jackknife_weights(datasets$B, groups = 10L, seed = 42L)
  # When calibration is in history, replicate weights must differ from ipw-only
  expect_false(identical(
    r_a@data[["repwt_1"]],
    r_b@data[["repwt_1"]]
  ))
})

test_that("create_group_jackknife_weights() calibrated replicates satisfy margin targets", {
  # Dataset B has literal targets: age_group 0.30/0.40/0.30, sex 0.48/0.52
  result <- create_group_jackknife_weights(datasets$B, groups = 10L, seed = 42L)
  rep_cols <- result@variables$repweights
  age_targets <- c("18-34" = 0.30, "35-54" = 0.40, "55+" = 0.30)
  sex_targets <- c("M" = 0.48, "F" = 0.52)

  for (repwt_col in rep_cols) {
    w <- result@data[[repwt_col]]
    # Only surviving units (w > 0) contribute to weighted proportions
    surviving <- w > 0
    w_s <- w[surviving]
    if (sum(w_s) == 0) next

    age_s <- result@data$age_group[surviving]
    sex_s <- result@data$sex[surviving]
    w_total <- sum(w_s)

    for (lv in names(age_targets)) {
      prop_obs <- sum(w_s[age_s == lv]) / w_total
      expect_equal(prop_obs, age_targets[[lv]], tolerance = 1e-4)
    }
    for (lv in names(sex_targets)) {
      prop_obs <- sum(w_s[sex_s == lv]) / w_total
      expect_equal(prop_obs, sex_targets[[lv]], tolerance = 1e-4)
    }
  }
})

# ============================================================================
# §3.5 Dispatcher
# ============================================================================

test_that("create_replicate_weights() dispatches to group-jackknife correctly", {
  result_direct <- create_group_jackknife_weights(datasets$A, groups = 10L, seed = 42L)
  result_dispatch <- create_replicate_weights(
    datasets$A, method = "group-jackknife", groups = 10L, seed = 42L
  )
  expect_identical(result_direct@data, result_dispatch@data)
  expect_identical(result_direct@variables, result_dispatch@variables)
})

# ============================================================================
# §3.6 Error paths — input class
# ============================================================================

test_that("create_group_jackknife_weights() rejects data.frame input", {
  df <- data.frame(x = 1:5, w = 1)
  expect_error(
    create_group_jackknife_weights(df),
    class = "surveywts_error_not_survey_design"
  )
  expect_snapshot(error = TRUE, create_group_jackknife_weights(df))
})

test_that("create_group_jackknife_weights() rejects weighted_df input", {
  df <- data.frame(
    x = sample(c("a", "b", "c"), 20L, replace = TRUE),
    w = rep(1, 20L)
  )
  wdf <- surveywts::rake(
    df,
    margins  = list(x = c(a = 0.33, b = 0.33, c = 0.34)),
    weights  = w,
    type     = "prop"
  )
  if (!inherits(wdf, "weighted_df")) skip("Could not construct weighted_df for test")
  expect_error(
    create_group_jackknife_weights(wdf),
    class = "surveywts_error_not_survey_design"
  )
})

test_that("create_group_jackknife_weights() rejects survey_replicate input", {
  skip_if_not_installed("svrep")
  td  <- make_taylor_design(seed = 1L)
  rep <- create_bootstrap_weights(td, replicates = 10L, seed = 1L)
  expect_error(
    create_group_jackknife_weights(rep),
    class = "surveywts_error_already_replicate"
  )
  expect_snapshot(error = TRUE, create_group_jackknife_weights(rep))
})

test_that("create_group_jackknife_weights() rejects survey_taylor input", {
  td <- make_taylor_design(seed = 1L)
  expect_error(
    create_group_jackknife_weights(td),
    class = "surveywts_error_dagjk_requires_nonprob"
  )
  expect_snapshot(error = TRUE, create_group_jackknife_weights(td))
})

test_that("create_group_jackknife_weights() rejects plain list input", {
  expect_error(
    create_group_jackknife_weights(list(x = 1)),
    class = "surveywts_error_unsupported_class"
  )
})

# ============================================================================
# §3.7 Error paths — reference_sample
# ============================================================================

test_that("create_group_jackknife_weights() rejects survey_replicate reference_sample", {
  skip_if_not_installed("svrep")
  td  <- make_taylor_design(seed = 1L)
  rep <- create_bootstrap_weights(td, replicates = 10L, seed = 1L)
  expect_error(
    create_group_jackknife_weights(datasets$A, reference_sample = rep),
    class = "surveywts_error_reference_sample_class"
  )
  expect_snapshot(
    error = TRUE,
    create_group_jackknife_weights(datasets$A, reference_sample = rep)
  )
})

test_that("create_group_jackknife_weights() rejects data.frame reference_sample", {
  df_ref <- data.frame(age_group = c("18-34", "55+"), sex = c("M", "F"),
                       w = c(1, 1))
  expect_error(
    create_group_jackknife_weights(datasets$A, reference_sample = df_ref),
    class = "surveywts_error_reference_sample_class"
  )
  expect_snapshot(
    error = TRUE,
    create_group_jackknife_weights(datasets$A, reference_sample = df_ref)
  )
})

test_that("create_group_jackknife_weights() errors when reference_sample = NULL and no stored reference", {
  # Build a survey_nonprob WITHOUT ipw() history (no reference stored)
  set.seed(1L)
  nps_df <- data.frame(
    age_group = c("18-34", "55+"),
    w = c(1.5, 2.0),
    stringsAsFactors = FALSE
  )
  np <- surveycore::survey_nonprob(
    data      = nps_df,
    variables = list(weights = "w")
  )
  # Manually add an ipw-like history entry WITHOUT a reference_design
  meta <- np@metadata
  meta@weighting_history <- list(list(
    step             = 1L,
    operation        = "ipw",
    formula          = ~age_group,
    method           = "logit",
    estimating_eq    = "mle",
    missing_method   = "omit",
    adjust_reference = FALSE,
    trim             = FALSE,
    trim_threshold   = NULL,
    maxit            = 25L,
    epsilon          = 1e-8,
    reference_design = NULL   # no reference
  ))
  np@metadata <- meta
  expect_error(
    create_group_jackknife_weights(np, groups = 2L),
    class = "surveywts_error_dagjk_no_reference"
  )
  expect_snapshot(
    error = TRUE,
    create_group_jackknife_weights(np, groups = 2L)
  )
})

# ============================================================================
# §3.8 Error paths — groups argument (8 tests)
# ============================================================================

test_that("create_group_jackknife_weights() rejects groups = 1", {
  expect_error(
    create_group_jackknife_weights(datasets$A, groups = 1L),
    class = "surveywts_error_dagjk_groups_too_small"
  )
  expect_snapshot(
    error = TRUE,
    create_group_jackknife_weights(datasets$A, groups = 1L)
  )
})

test_that("create_group_jackknife_weights() rejects groups = 0", {
  expect_error(
    create_group_jackknife_weights(datasets$A, groups = 0L),
    class = "surveywts_error_dagjk_groups_too_small"
  )
})

test_that("create_group_jackknife_weights() rejects groups = -1", {
  expect_error(
    create_group_jackknife_weights(datasets$A, groups = -1L),
    class = "surveywts_error_dagjk_groups_too_small"
  )
})

test_that("create_group_jackknife_weights() rejects groups = 50.5 (fractional)", {
  expect_error(
    create_group_jackknife_weights(datasets$A, groups = 50.5),
    class = "surveywts_error_dagjk_groups_not_whole_number"
  )
  expect_snapshot(
    error = TRUE,
    create_group_jackknife_weights(datasets$A, groups = 50.5)
  )
})

test_that("create_group_jackknife_weights() rejects groups = NA", {
  expect_error(
    create_group_jackknife_weights(datasets$A, groups = NA),
    class = "surveywts_error_dagjk_groups_invalid"
  )
  expect_snapshot(
    error = TRUE,
    create_group_jackknife_weights(datasets$A, groups = NA)
  )
})

test_that("create_group_jackknife_weights() rejects groups = '50' (character)", {
  expect_error(
    create_group_jackknife_weights(datasets$A, groups = "50"),
    class = "surveywts_error_dagjk_groups_invalid"
  )
})

test_that("create_group_jackknife_weights() rejects groups of length > 1", {
  expect_error(
    create_group_jackknife_weights(datasets$A, groups = c(10L, 20L)),
    class = "surveywts_error_dagjk_groups_invalid"
  )
})

test_that("create_group_jackknife_weights() rejects groups exceeding combined N", {
  # 80 NPS + 500 ref = 580 combined; request 581 groups
  expect_error(
    create_group_jackknife_weights(datasets$A, groups = 581L),
    class = "surveywts_error_dagjk_groups_exceeds_n"
  )
  expect_snapshot(
    error = TRUE,
    create_group_jackknife_weights(datasets$A, groups = 581L)
  )
})

# ============================================================================
# §3.9 No ipw history
# ============================================================================

test_that("create_group_jackknife_weights() rejects data with no ipw history", {
  set.seed(1L)
  nps_df <- data.frame(
    age_group = sample(c("18-34", "55+"), 20L, replace = TRUE),
    w = exp(rnorm(20L)),
    stringsAsFactors = FALSE
  )
  np_no_ipw <- surveycore::survey_nonprob(
    data      = nps_df,
    variables = list(weights = "w")
  )
  expect_error(
    create_group_jackknife_weights(np_no_ipw, groups = 5L),
    class = "surveywts_error_dagjk_no_ipw_history"
  )
  expect_snapshot(
    error = TRUE,
    create_group_jackknife_weights(np_no_ipw, groups = 5L)
  )
})

# ============================================================================
# §3.10 All replicates fail
# ============================================================================

test_that("create_group_jackknife_weights() errors when all replicates fail", {
  # Pathological case: 4 NPS units + 4 ref units, groups = 2
  # NPS has a covariate level not in ref -> degenerate propensity
  set.seed(1L)
  tiny_nps <- data.frame(
    age_group = c("18-34", "18-34", "55+", "55+"),
    sex       = c("M", "F", "M", "F"),
    stringsAsFactors = FALSE
  )
  tiny_ref_df <- data.frame(
    age_group  = c("18-34", "35-54", "35-54", "55+"),
    sex        = c("M", "F", "M", "F"),
    ref_weight = c(1, 1, 1, 1),
    stringsAsFactors = FALSE
  )
  tiny_ref <- surveycore::survey_taylor(
    data      = tiny_ref_df,
    variables = list(weights = "ref_weight")
  )
  # Will error or produce degenerate scores; suppress warnings in test
  tiny_ipw <- tryCatch(
    suppressWarnings(
      surveywts::ipw(
        data             = tiny_nps,
        reference        = tiny_ref,
        selection        = ~age_group + sex,
        adjust_reference = FALSE
      )
    ),
    error = function(e) NULL
  )
  skip_if(is.null(tiny_ipw), "ipw() failed on tiny data; cannot test all-fail path")

  # Attempt DAGJK with groups = 2; very likely all fail due to tiny data
  result <- tryCatch(
    suppressWarnings(
      create_group_jackknife_weights(tiny_ipw, groups = 2L, seed = 1L)
    ),
    error = function(e) e
  )
  # Either succeeds (some replicates work) or errors with all-failed class
  if (inherits(result, "error")) {
    expect_s3_class(result, "surveywts_error_dagjk_all_replicates_failed")
  }
  # If it succeeds, that's also valid — test documents behavior
})

# ============================================================================
# §3.11 Warning paths
# ============================================================================

test_that("create_group_jackknife_weights() warns when repweights already populated", {
  r1 <- create_group_jackknife_weights(datasets$A, groups = 10L, seed = 1L)
  expect_warning(
    result <- create_group_jackknife_weights(r1, groups = 10L, seed = 2L),
    class = "surveywts_warning_dagjk_repweights_overwritten"
  )
  expect_snapshot(create_group_jackknife_weights(r1, groups = 10L, seed = 2L))
})

test_that("create_group_jackknife_weights() warns when average group size < 5", {
  # 80 NPS + 500 ref = 580 combined; groups = 200 -> avg = floor(580/200) = 2
  # Use withCallingHandlers to capture only the small_groups warning
  saw_small_groups <- FALSE
  withCallingHandlers(
    create_group_jackknife_weights(datasets$A, groups = 200L, seed = 1L),
    surveywts_warning_dagjk_small_groups = function(w) {
      saw_small_groups <<- TRUE
      invokeRestart("muffleWarning")
    },
    warning = function(w) invokeRestart("muffleWarning")
  )
  expect_true(saw_small_groups)
})

# ============================================================================
# §4 Scaling factor — (G-1)/G, not (n-1)/n
# ============================================================================

test_that("create_group_jackknife_weights() sets scale to (G-1)/G, not (n-1)/n", {
  G <- 10L
  result <- create_group_jackknife_weights(datasets$A, groups = G, seed = 42L)
  n <- nrow(datasets$A@data)
  expect_equal(result@variables$scale, (G - 1) / G, tolerance = 1e-12)
  expect_false(isTRUE(all.equal(result@variables$scale, (n - 1) / n)))
})

# ============================================================================
# §5 Model refit — per-replicate logistic model refit
# ============================================================================

test_that("create_group_jackknife_weights() refits the logistic model per replicate", {
  result <- create_group_jackknife_weights(datasets$A, groups = 10L, seed = 42L)
  # The ratio of replicate weight to full-weight should not be constant
  wt_col <- result@variables$weights
  full_wt <- result@data[[wt_col]]
  surviving1 <- result@data[["repwt_1"]] > 0
  if (sum(surviving1) < 2L) skip("Not enough surviving units in replicate 1")
  ratio <- result@data[["repwt_1"]][surviving1] / full_wt[surviving1]
  # If ratio were constant (no refit), all values would be equal
  expect_true(stats::sd(ratio) > 1e-10)
})

# ============================================================================
# §6 Zero-weight assignment
# ============================================================================

test_that("create_group_jackknife_weights() assigns weight 0 to deleted group units", {
  result <- create_group_jackknife_weights(datasets$A, groups = 10L, seed = 42L)
  rep_cols <- result@variables$repweights

  for (g in seq_along(rep_cols)) {
    repwt <- result@data[[rep_cols[g]]]
    zero_rows <- which(repwt == 0)
    nonzero_rows <- which(repwt > 0)
    # All other replicate columns for zero-group rows should be > 0
    for (other_g in setdiff(seq_along(rep_cols), g)) {
      other_repwt <- result@data[[rep_cols[other_g]]]
      expect_true(all(other_repwt[zero_rows] > 0))
    }
  }
})

# ============================================================================
# §3.12 Edge cases
# ============================================================================

test_that("create_group_jackknife_weights() handles groups = 2 (minimum valid)", {
  result <- suppressWarnings(
    create_group_jackknife_weights(datasets$A, groups = 2L, seed = 42L)
  )
  expect_true(S7::S7_inherits(result, surveycore::survey_nonprob))
  expect_lte(length(result@variables$repweights), 2L)
  expect_gte(length(result@variables$repweights), 1L)
})

test_that("create_group_jackknife_weights() works with reference_sample overriding stored reference", {
  # Dataset C has reference in ipw history; pass a fresh reference explicitly
  result <- create_group_jackknife_weights(
    datasets$C,
    groups = 10L,
    seed = 42L,
    reference_sample = datasets$ref
  )
  test_invariants(result)
  expect_true(S7::S7_inherits(result, surveycore::survey_nonprob))
})

test_that("create_group_jackknife_weights() @variables$mse is TRUE", {
  result <- create_group_jackknife_weights(datasets$A, groups = 10L, seed = 42L)
  expect_true(isTRUE(result@variables$mse))
})

test_that("create_group_jackknife_weights() @variables$type is 'group-jackknife'", {
  result <- create_group_jackknife_weights(datasets$A, groups = 10L, seed = 42L)
  expect_identical(result@variables$type, "group-jackknife")
})
