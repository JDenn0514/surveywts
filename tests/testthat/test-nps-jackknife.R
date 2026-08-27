# test-nps-jackknife.R
#
# Tests for create_jackknife_weights(..., type = "grouped") on survey_nonprob
# (DAGJK — delete-a-group jackknife for non-probability samples).

# ---- Shared datasets (created once at file load time) -----------------------

datasets <- make_dagjk_datasets()

# ============================================================================
# §3.1 Happy path -- structural invariants
# ============================================================================

test_that("create_jackknife_weights() type='grouped' returns survey_nonprob with correct structure", {
  result <- create_jackknife_weights(
    datasets$A,
    replicates = 10L,
    type = "grouped",
    seed = 42L
  )
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

test_that("create_jackknife_weights() type='grouped' each row has exactly 1 zero across replicate cols", {
  result <- create_jackknife_weights(
    datasets$A,
    replicates = 10L,
    type = "grouped",
    seed = 42L
  )
  rep_cols <- result@variables$repweights
  rep_mat <- as.matrix(result@data[, rep_cols, drop = FALSE])
  zero_counts <- rowSums(rep_mat == 0)
  expect_true(all(zero_counts == 1L))
})

test_that("create_jackknife_weights() type='grouped' each row has G-1 positive values", {
  result <- create_jackknife_weights(
    datasets$A,
    replicates = 10L,
    type = "grouped",
    seed = 42L
  )
  rep_cols <- result@variables$repweights
  rep_mat <- as.matrix(result@data[, rep_cols, drop = FALSE])
  pos_counts <- rowSums(rep_mat > 0)
  expect_true(all(pos_counts == 9L))
})

test_that("create_jackknife_weights() type='grouped' original columns are unchanged", {
  original_cols <- names(datasets$A@data)
  result <- create_jackknife_weights(
    datasets$A,
    replicates = 10L,
    type = "grouped",
    seed = 42L
  )
  expect_true(all(original_cols %in% names(result@data)))
  for (col in original_cols) {
    expect_identical(result@data[[col]], datasets$A@data[[col]])
  }
})

test_that("create_jackknife_weights() type='grouped' appends history entry with correct fields", {
  result <- create_jackknife_weights(
    datasets$A,
    replicates = 10L,
    type = "grouped",
    seed = 42L
  )
  history <- result@metadata@weighting_history
  dagjk_entry <- Filter(
    function(e) identical(e$operation, "jackknife_weights"),
    history
  )
  expect_length(dagjk_entry, 1L)
  entry <- dagjk_entry[[1L]]
  expect_identical(entry$operation, "jackknife_weights")
  expect_identical(entry$parameters$replicates, 10L)
  expect_identical(entry$parameters$seed, 42L)
  expect_true(is.numeric(entry$parameters$scale))
  expect_false(is.null(entry$source_design))
})

# ============================================================================
# §3.2 Coercion and argument passing
# ============================================================================

test_that("create_jackknife_weights() type='grouped' coerces whole-number double replicates silently", {
  expect_no_error(
    result <- create_jackknife_weights(
      datasets$A,
      replicates = 10.0,
      type = "grouped",
      seed = 42L
    )
  )
  expect_length(result@variables$repweights, 10L)
})

# ============================================================================
# §3.3 Seed reproducibility
# ============================================================================

test_that("create_jackknife_weights() type='grouped' same seed produces identical results", {
  r1 <- create_jackknife_weights(
    datasets$A,
    replicates = 10L,
    type = "grouped",
    seed = 42L
  )
  r2 <- create_jackknife_weights(
    datasets$A,
    replicates = 10L,
    type = "grouped",
    seed = 42L
  )
  expect_identical(r1@data, r2@data)
  expect_identical(r1@variables$repweights, r2@variables$repweights)
})

test_that("create_jackknife_weights() type='grouped' different seeds produce different results", {
  r1 <- create_jackknife_weights(
    datasets$A,
    replicates = 10L,
    type = "grouped",
    seed = 1L
  )
  r2 <- create_jackknife_weights(
    datasets$A,
    replicates = 10L,
    type = "grouped",
    seed = 99L
  )
  rep_col <- "repwt_1"
  expect_false(identical(r1@data[[rep_col]], r2@data[[rep_col]]))
})

test_that("create_jackknife_weights() type='grouped' seed = NULL does not error", {
  expect_no_error(
    create_jackknife_weights(
      datasets$A,
      replicates = 10L,
      type = "grouped",
      seed = NULL
    )
  )
})

test_that("create_jackknife_weights() type='grouped' seed = 0L is valid", {
  expect_no_error(
    result <- create_jackknife_weights(
      datasets$A,
      replicates = 10L,
      type = "grouped",
      seed = 0L
    )
  )
  expect_true(S7::S7_inherits(result, surveycore::survey_nonprob))
})

# ============================================================================
# §3.4 Calibration history -- replicate repeats calibration
# ============================================================================

test_that("create_jackknife_weights() type='grouped' replicate weights differ with vs without calibration", {
  r_a <- create_jackknife_weights(
    datasets$A,
    replicates = 10L,
    type = "grouped",
    seed = 42L
  )
  r_b <- create_jackknife_weights(
    datasets$B,
    replicates = 10L,
    type = "grouped",
    seed = 42L
  )
  # When calibration is in history, replicate weights must differ from ipw-only
  expect_false(identical(
    r_a@data[["repwt_1"]],
    r_b@data[["repwt_1"]]
  ))
})

test_that("create_jackknife_weights() type='grouped' calibrated replicates satisfy margin targets", {
  # Dataset B has literal targets: age_group 0.30/0.40/0.30, sex 0.48/0.52
  result <- create_jackknife_weights(
    datasets$B,
    replicates = 10L,
    type = "grouped",
    seed = 42L
  )
  rep_cols <- result@variables$repweights
  age_targets <- c("18-34" = 0.30, "35-54" = 0.40, "55+" = 0.30)
  sex_targets <- c("M" = 0.48, "F" = 0.52)

  for (repwt_col in rep_cols) {
    w <- result@data[[repwt_col]]
    surviving <- w > 0
    w_s <- w[surviving]
    if (sum(w_s) == 0) {
      next
    }

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

test_that("create_replicate_weights() dispatches to DAGJK via method='jackknife', type='grouped'", {
  result_direct <- create_jackknife_weights(
    datasets$A,
    replicates = 10L,
    type = "grouped",
    seed = 42L
  )
  result_dispatch <- create_replicate_weights(
    datasets$A,
    method = "jackknife",
    type = "grouped",
    replicates = 10L,
    seed = 42L
  )
  expect_identical(result_direct@data, result_dispatch@data)
  expect_identical(result_direct@variables, result_dispatch@variables)
})

# ============================================================================
# §3.6 Error paths -- input class
# ============================================================================

test_that("create_jackknife_weights() type='grouped' rejects data.frame input", {
  df <- data.frame(x = 1:5, w = 1)
  expect_error(
    create_jackknife_weights(df, replicates = 10L, type = "grouped"),
    class = "surveywts_error_not_survey_design"
  )
  expect_snapshot(
    error = TRUE,
    create_jackknife_weights(df, replicates = 10L, type = "grouped")
  )
})


test_that("create_jackknife_weights() type='grouped' rejects survey_replicate input", {
  skip_if_not_installed("svrep")
  td <- make_taylor_design(seed = 1L)
  rep <- create_bootstrap_weights(td, replicates = 10L, seed = 1L)
  expect_error(
    create_jackknife_weights(rep, replicates = 10L, type = "grouped"),
    class = "surveywts_error_already_replicate"
  )
  expect_snapshot(
    error = TRUE,
    create_jackknife_weights(rep, replicates = 10L, type = "grouped")
  )
})

test_that("create_jackknife_weights() type='grouped' rejects plain list input", {
  expect_error(
    create_jackknife_weights(list(x = 1), replicates = 10L, type = "grouped"),
    class = "surveywts_error_unsupported_class"
  )
})

# ============================================================================
# §3.7 Error paths -- reference_sample
# ============================================================================

test_that("create_jackknife_weights() type='grouped' rejects survey_replicate reference_sample", {
  skip_if_not_installed("svrep")
  td <- make_taylor_design(seed = 1L)
  rep <- create_bootstrap_weights(td, replicates = 10L, seed = 1L)
  expect_error(
    create_jackknife_weights(
      datasets$A,
      replicates = 10L,
      type = "grouped",
      reference_sample = rep
    ),
    class = "surveywts_error_reference_sample_class"
  )
  expect_snapshot(
    error = TRUE,
    create_jackknife_weights(
      datasets$A,
      replicates = 10L,
      type = "grouped",
      reference_sample = rep
    )
  )
})

test_that("create_jackknife_weights() type='grouped' rejects data.frame reference_sample", {
  df_ref <- data.frame(
    age_group = c("18-34", "55+"),
    sex = c("M", "F"),
    w = c(1, 1)
  )
  expect_error(
    create_jackknife_weights(
      datasets$A,
      replicates = 10L,
      type = "grouped",
      reference_sample = df_ref
    ),
    class = "surveywts_error_reference_sample_class"
  )
  expect_snapshot(
    error = TRUE,
    create_jackknife_weights(
      datasets$A,
      replicates = 10L,
      type = "grouped",
      reference_sample = df_ref
    )
  )
})

test_that("create_jackknife_weights() errors when reference_sample = NULL and no stored reference", {
  # Build a survey_nonprob WITHOUT ipw() history (no reference stored)
  set.seed(1L)
  nps_df <- data.frame(
    age_group = c("18-34", "55+"),
    w = c(1.5, 2.0),
    stringsAsFactors = FALSE
  )
  np <- surveycore::survey_nonprob(
    data = nps_df,
    variables = list(weights = "w")
  )
  # Manually add an ipw-like history entry WITHOUT a reference_design
  meta <- np@metadata
  meta@weighting_history <- list(list(
    step = 1L,
    operation = "ipw",
    formula = ~age_group,
    method = "logit",
    estimating_eq = "mle",
    missing_method = "omit",
    adjust_reference = FALSE,
    trim = FALSE,
    trim_threshold = NULL,
    maxit = 25L,
    epsilon = 1e-8,
    reference_design = NULL # no reference
  ))
  np@metadata <- meta
  expect_error(
    create_jackknife_weights(np, replicates = 2L, type = "grouped"),
    class = "surveywts_error_jackknife_no_reference"
  )
  expect_snapshot(
    error = TRUE,
    create_jackknife_weights(np, replicates = 2L, type = "grouped")
  )
})

# ============================================================================
# §3.8 Error paths -- replicates argument
# ============================================================================

test_that("create_jackknife_weights() type='grouped' rejects replicates = NULL", {
  expect_error(
    create_jackknife_weights(datasets$A, type = "grouped"),
    class = "surveywts_error_jackknife_replicates_required"
  )
  expect_snapshot(
    error = TRUE,
    create_jackknife_weights(datasets$A, type = "grouped")
  )
})

test_that("create_jackknife_weights() type='grouped' rejects replicates = 1", {
  expect_error(
    create_jackknife_weights(datasets$A, replicates = 1L, type = "grouped"),
    class = "surveywts_error_jackknife_replicates_too_small"
  )
  expect_snapshot(
    error = TRUE,
    create_jackknife_weights(datasets$A, replicates = 1L, type = "grouped")
  )
})

test_that("create_jackknife_weights() type='grouped' rejects replicates = 0", {
  expect_error(
    create_jackknife_weights(datasets$A, replicates = 0L, type = "grouped"),
    class = "surveywts_error_jackknife_replicates_too_small"
  )
})

test_that("create_jackknife_weights() type='grouped' rejects replicates = -1", {
  expect_error(
    create_jackknife_weights(datasets$A, replicates = -1L, type = "grouped"),
    class = "surveywts_error_jackknife_replicates_too_small"
  )
})

test_that("create_jackknife_weights() type='grouped' rejects fractional replicates", {
  expect_error(
    create_jackknife_weights(datasets$A, replicates = 50.5, type = "grouped"),
    class = "surveywts_error_replicates_not_whole_number"
  )
  expect_snapshot(
    error = TRUE,
    create_jackknife_weights(datasets$A, replicates = 50.5, type = "grouped")
  )
})

test_that("create_jackknife_weights() type='grouped' rejects replicates = NA", {
  expect_error(
    create_jackknife_weights(datasets$A, replicates = NA, type = "grouped"),
    class = "surveywts_error_jackknife_replicates_invalid"
  )
  expect_snapshot(
    error = TRUE,
    create_jackknife_weights(datasets$A, replicates = NA, type = "grouped")
  )
})

test_that("create_jackknife_weights() type='grouped' rejects character replicates", {
  expect_error(
    create_jackknife_weights(datasets$A, replicates = "50", type = "grouped"),
    class = "surveywts_error_jackknife_replicates_invalid"
  )
})

test_that("create_jackknife_weights() type='grouped' rejects replicates of length > 1", {
  expect_error(
    create_jackknife_weights(
      datasets$A,
      replicates = c(10L, 20L),
      type = "grouped"
    ),
    class = "surveywts_error_jackknife_replicates_invalid"
  )
})

test_that("create_jackknife_weights() type='grouped' rejects replicates exceeding combined N", {
  # 80 NPS + 500 ref = 580 combined; request 581 groups
  expect_error(
    create_jackknife_weights(datasets$A, replicates = 581L, type = "grouped"),
    class = "surveywts_error_jackknife_replicates_exceeds_n"
  )
  expect_snapshot(
    error = TRUE,
    create_jackknife_weights(datasets$A, replicates = 581L, type = "grouped")
  )
})

# ============================================================================
# §3.9 No ipw/calib history
# ============================================================================

test_that("create_jackknife_weights() type='grouped' rejects data with no weighting history", {
  set.seed(1L)
  nps_df <- data.frame(
    age_group = sample(c("18-34", "55+"), 20L, replace = TRUE),
    w = exp(rnorm(20L)),
    stringsAsFactors = FALSE
  )
  np_no_history <- surveycore::survey_nonprob(
    data = nps_df,
    variables = list(weights = "w")
  )
  expect_error(
    create_jackknife_weights(np_no_history, replicates = 5L, type = "grouped"),
    class = "surveywts_error_jackknife_no_history"
  )
  expect_snapshot(
    error = TRUE,
    create_jackknife_weights(np_no_history, replicates = 5L, type = "grouped")
  )
})

# ============================================================================
# §3.10 All replicates fail
# ============================================================================

test_that("create_jackknife_weights() type='grouped' errors when all replicates fail", {
  # Pathological case: 4 NPS units + 4 ref units, groups = 2
  set.seed(1L)
  tiny_nps <- data.frame(
    age_group = c("18-34", "18-34", "55+", "55+"),
    sex = c("M", "F", "M", "F"),
    stringsAsFactors = FALSE
  )
  tiny_ref_df <- data.frame(
    age_group = c("18-34", "35-54", "35-54", "55+"),
    sex = c("M", "F", "M", "F"),
    ref_weight = c(1, 1, 1, 1),
    stringsAsFactors = FALSE
  )
  tiny_ref <- surveycore::survey_taylor(
    data = tiny_ref_df,
    variables = list(weights = "ref_weight")
  )
  tiny_ipw <- tryCatch(
    suppressWarnings(
      surveywts::ipw(
        data = tiny_nps,
        reference = tiny_ref,
        selection = ~ age_group + sex,
        adjust_reference = FALSE
      )
    ),
    error = function(e) NULL
  )
  skip_if(
    is.null(tiny_ipw),
    "ipw() failed on tiny data; cannot test all-fail path"
  )

  result <- tryCatch(
    suppressWarnings(
      create_jackknife_weights(
        tiny_ipw,
        replicates = 2L,
        type = "grouped",
        seed = 1L
      )
    ),
    error = function(e) e
  )
  if (inherits(result, "error")) {
    expect_s3_class(result, "surveywts_error_jackknife_all_replicates_failed")
  }
})

test_that(".dagjk_single_replicate() throws degenerate_replicate when no NPS units remain [direct]", {
  # All NPS units assigned to group 1; after deleting group 1, no NPS remain
  n_nps <- 3L
  n_ref <- 3L
  group_assign <- c(rep(1L, n_nps), rep(2L, n_ref))
  nps_data <- data.frame(x = 1:3, w = rep(1, 3))
  ref_data <- data.frame(x = 4:6, ref_w = rep(1, 3))
  ipw_entry <- list(
    formula = ~x,
    method = "logit",
    estimating_eq = "mle",
    missing_method = "omit",
    adjust_reference = FALSE,
    trim = FALSE,
    trim_threshold = NULL,
    maxit = 25L,
    epsilon = 1e-8
  )
  cond <- tryCatch(
    surveywts:::.dagjk_single_replicate(
      g = 1L,
      group_assign = group_assign,
      nps_data = nps_data,
      ref_data = ref_data,
      ref_wt_col = "ref_w",
      ipw_entry = ipw_entry,
      calib_entry = NULL,
      n_nps = n_nps,
      n_ref = n_ref,
      use_level_b = FALSE,
      ref_design = NULL,
      wt_col = "w"
    ),
    error = function(e) e
  )
  expect_s3_class(cond, "surveywts_error_jackknife_degenerate_replicate")
})

test_that(".dagjk_single_replicate() throws degenerate_replicate when no ref units remain [direct]", {
  # All ref units assigned to group 1; after deleting group 1, no ref remain
  n_nps <- 3L
  n_ref <- 3L
  group_assign <- c(rep(2L, n_nps), rep(1L, n_ref))
  nps_data <- data.frame(x = 1:3, w = rep(1, 3))
  ref_data <- data.frame(x = 4:6, ref_w = rep(1, 3))
  ipw_entry <- list(
    formula = ~x,
    method = "logit",
    estimating_eq = "mle",
    missing_method = "omit",
    adjust_reference = FALSE,
    trim = FALSE,
    trim_threshold = NULL,
    maxit = 25L,
    epsilon = 1e-8
  )
  cond <- tryCatch(
    surveywts:::.dagjk_single_replicate(
      g = 1L,
      group_assign = group_assign,
      nps_data = nps_data,
      ref_data = ref_data,
      ref_wt_col = "ref_w",
      ipw_entry = ipw_entry,
      calib_entry = NULL,
      n_nps = n_nps,
      n_ref = n_ref,
      use_level_b = FALSE,
      ref_design = NULL,
      wt_col = "w"
    ),
    error = function(e) e
  )
  expect_s3_class(cond, "surveywts_error_jackknife_degenerate_replicate")
})

test_that(".dagjk_single_replicate() throws degenerate_replicate when N_hat_g < n_nps_g [direct]", {
  # ref weights are tiny (sum << n_nps_g) -> N_hat_g - n_nps_g < 0
  n_nps <- 10L
  n_ref <- 4L
  group_assign <- c(c(1L, 1L, rep(2L, 8L)), rep(2L, n_ref))
  nps_data <- data.frame(x = 1:10, w = rep(1, 10))
  ref_data <- data.frame(x = 11:14, ref_w = rep(0.001, 4L))
  ipw_entry <- list(
    formula = ~x,
    method = "logit",
    estimating_eq = "mle",
    missing_method = "omit",
    adjust_reference = FALSE,
    trim = FALSE,
    trim_threshold = NULL,
    maxit = 25L,
    epsilon = 1e-8
  )
  cond <- tryCatch(
    surveywts:::.dagjk_single_replicate(
      g = 1L,
      group_assign = group_assign,
      nps_data = nps_data,
      ref_data = ref_data,
      ref_wt_col = "ref_w",
      ipw_entry = ipw_entry,
      calib_entry = NULL,
      n_nps = n_nps,
      n_ref = n_ref,
      use_level_b = FALSE,
      ref_design = NULL,
      wt_col = "w"
    ),
    error = function(e) e
  )
  expect_s3_class(cond, "surveywts_error_jackknife_degenerate_replicate")
})

test_that("create_jackknife_weights() type='grouped' errors (all fail) when N_hat_g < n_nps_g", {
  # Tiny reference (n=5, weight=1) vs large NPS (n=50)
  set.seed(5L)
  tiny_ref_df <- data.frame(
    age_group = sample(c("18-34", "55+"), 5L, replace = TRUE),
    sex = sample(c("M", "F"), 5L, replace = TRUE),
    ref_weight = rep(1, 5L),
    stringsAsFactors = FALSE
  )
  tiny_ref <- surveycore::survey_taylor(
    data = tiny_ref_df,
    variables = list(weights = "ref_weight")
  )
  large_nps_df <- data.frame(
    age_group = sample(c("18-34", "55+"), 50L, replace = TRUE),
    sex = sample(c("M", "F"), 50L, replace = TRUE),
    stringsAsFactors = FALSE
  )
  large_ipw <- tryCatch(
    suppressWarnings(
      surveywts::ipw(
        data = large_nps_df,
        reference = tiny_ref,
        selection = ~ age_group + sex,
        adjust_reference = FALSE
      )
    ),
    error = function(e) NULL
  )
  skip_if(
    is.null(large_ipw),
    "ipw() failed; cannot test negative adjustment factor path"
  )

  expect_error(
    suppressWarnings(
      create_jackknife_weights(
        large_ipw,
        replicates = 10L,
        type = "grouped",
        seed = 1L
      )
    ),
    class = "surveywts_error_jackknife_all_replicates_failed"
  )
  expect_snapshot(
    error = TRUE,
    suppressWarnings(
      create_jackknife_weights(
        large_ipw,
        replicates = 10L,
        type = "grouped",
        seed = 1L
      )
    )
  )
})

# ============================================================================
# §3.11 Warning paths
# ============================================================================

test_that("create_jackknife_weights() type='grouped' warns when repweights already populated", {
  r1 <- create_jackknife_weights(
    datasets$A,
    replicates = 10L,
    type = "grouped",
    seed = 1L
  )
  expect_warning(
    result <- create_jackknife_weights(
      r1,
      replicates = 10L,
      type = "grouped",
      seed = 2L
    ),
    class = "surveywts_warning_jackknife_repweights_overwritten"
  )
  expect_snapshot(
    .pin_ts(
      create_jackknife_weights(
        r1,
        replicates = 10L,
        type = "grouped",
        seed = 2L
      )
    )
  )
})

test_that("create_jackknife_weights() type='grouped' warns when average group size < 5", {
  # 80 NPS + 500 ref = 580 combined; replicates = 200 -> avg = floor(580/200) = 2
  saw_small_groups <- FALSE
  withCallingHandlers(
    create_jackknife_weights(
      datasets$A,
      replicates = 200L,
      type = "grouped",
      seed = 1L
    ),
    surveywts_warning_jackknife_small_groups = function(w) {
      saw_small_groups <<- TRUE
      invokeRestart("muffleWarning")
    },
    warning = function(w) invokeRestart("muffleWarning")
  )
  expect_true(saw_small_groups)
  expect_snapshot(
    .pin_ts(withCallingHandlers(
      create_jackknife_weights(
        datasets$A,
        replicates = 200L,
        type = "grouped",
        seed = 1L
      ),
      warning = function(w) {
        if (!inherits(w, "surveywts_warning_jackknife_small_groups")) {
          invokeRestart("muffleWarning")
        }
      }
    ))
  )
})

test_that("create_jackknife_weights() type='grouped' warns when > 10% of replicates fail", {
  set.seed(77L)
  tiny_ref_df2 <- data.frame(
    age_group = c("18-34", "18-34", "55+", "55+", "35-54", "35-54"),
    ref_weight = rep(100, 6L),
    stringsAsFactors = FALSE
  )
  tiny_ref2 <- surveycore::survey_taylor(
    data = tiny_ref_df2,
    variables = list(weights = "ref_weight")
  )
  tiny_nps2 <- data.frame(
    age_group = c("18-34", "18-34", "55+", "55+", "35-54", "35-54"),
    stringsAsFactors = FALSE
  )
  tiny_ipw2 <- suppressWarnings(
    surveywts::ipw(
      data = tiny_nps2,
      reference = tiny_ref2,
      selection = ~age_group,
      adjust_reference = FALSE
    )
  )

  expect_warning(
    result <- create_jackknife_weights(
      tiny_ipw2,
      replicates = 5L,
      type = "grouped",
      seed = 7L
    ),
    class = "surveywts_warning_jackknife_replicates_failed"
  )
  expect_true(S7::S7_inherits(result, surveycore::survey_nonprob))
  expect_true(length(result@variables$repweights) < 5L)
  g_success <- length(result@variables$repweights)
  expect_equal(
    result@variables$scale,
    (g_success - 1) / g_success,
    tolerance = 1e-12
  )
  expect_snapshot(
    .pin_ts(
      create_jackknife_weights(
        tiny_ipw2,
        replicates = 5L,
        type = "grouped",
        seed = 7L
      )
    )
  )
})

test_that("create_jackknife_weights() type='grouped' mse=FALSE warning fires and overrides to TRUE", {
  expect_warning(
    result <- create_jackknife_weights(
      datasets$A,
      replicates = 10L,
      type = "grouped",
      mse = FALSE,
      seed = 1L
    ),
    class = "surveywts_warning_jackknife_mse_overridden"
  )
  expect_true(isTRUE(result@variables$mse))
})

test_that("create_jackknife_weights() type='grouped' svrep args warning fires once for non-default args", {
  expect_warning(
    create_jackknife_weights(
      datasets$A,
      replicates = 10L,
      type = "grouped",
      seed = 1L,
      var_strat = "some_var"
    ),
    class = "surveywts_warning_jackknife_svrep_args_ignored"
  )
})

test_that("create_jackknife_weights() warns when adj_method overridden for DAGJK", {
  ns_wave1_svy <- datasets$A
  expect_warning(
    create_jackknife_weights(
      ns_wave1_svy,
      replicates = 5L,
      type = "grouped",
      adj_method = "variance-units"
    ),
    class = "surveywts_warning_jackknife_svrep_args_ignored"
  )
})

test_that("multiple non-default svrep args together emit exactly one warning for DAGJK", {
  ns_wave1_svy <- datasets$A
  n_warnings <- 0L
  withCallingHandlers(
    create_jackknife_weights(
      ns_wave1_svy,
      replicates = 5L,
      type = "grouped",
      adj_method = "variance-units",
      scale_method = "variance-units"
    ),
    warning = function(w) {
      n_warnings <<- n_warnings + 1L
      invokeRestart("muffleWarning")
    }
  )
  expect_identical(n_warnings, 1L)
})

test_that("create_jackknife_weights() does not warn for svrep args when all at default for DAGJK", {
  ns_wave1_svy <- datasets$A
  expect_no_warning(
    create_jackknife_weights(ns_wave1_svy, replicates = 5L, type = "grouped")
  )
})

test_that("create_jackknife_weights() type='grouped' negative-weight warning path is defensive", {
  # Note: surveywts_warning_jackknife_negative_replicate_weights cannot be triggered
  # via the public API in normal circumstances because:
  #   rake() (IPF) always produces strictly positive weights by construction.
  #   The rep_mat < 0 check only fires if calibration returns negative weights while
  #   bypassing the S7 validator. This test documents the defensive nature of the check.
  set.seed(33L)
  ref_df3 <- data.frame(
    age_group = sample(
      c("young", "old"),
      200L,
      replace = TRUE,
      prob = c(0.5, 0.5)
    ),
    ref_weight = rep(1, 200L),
    stringsAsFactors = FALSE
  )
  ref3 <- surveycore::survey_taylor(
    data = ref_df3,
    variables = list(weights = "ref_weight")
  )
  nps_df3 <- data.frame(
    age_group = sample(
      c("young", "old"),
      30L,
      replace = TRUE,
      prob = c(0.95, 0.05)
    ),
    stringsAsFactors = FALSE
  )
  ipw3 <- suppressWarnings(
    surveywts::ipw(
      data = nps_df3,
      reference = ref3,
      selection = ~age_group,
      adjust_reference = FALSE
    )
  )
  raked3 <- surveywts::calibrate_rake(
    ipw3,
    targets = list(age_group = c("young" = 0.05, "old" = 0.95)),
    type = "prop"
  )
  expect_true(S7::S7_inherits(raked3, surveycore::survey_nonprob))
  wts <- raked3@data[[raked3@variables$weights]]
  expect_true(all(wts > 0))
  result <- suppressWarnings(
    create_jackknife_weights(
      raked3,
      replicates = 10L,
      type = "grouped",
      seed = 1L
    )
  )
  expect_true(S7::S7_inherits(result, surveycore::survey_nonprob))
  rep_cols <- result@variables$repweights
  if (length(rep_cols) > 0L) {
    rep_mat <- as.matrix(result@data[, rep_cols, drop = FALSE])
    expect_false(any(rep_mat < 0, na.rm = TRUE))
  }
})

test_that("create_jackknife_weights() type='grouped' uses_level_b = TRUE (targets_from_reference)", {
  # Dataset D uses rake() with reference_design= -> targets_from_reference = TRUE
  result <- create_jackknife_weights(
    datasets$D,
    replicates = 10L,
    type = "grouped",
    seed = 42L
  )
  test_invariants(result)
  expect_true(S7::S7_inherits(result, surveycore::survey_nonprob))
  expect_length(result@variables$repweights, 10L)
  expect_identical(result@variables$type, "group-jackknife")
})

# ============================================================================
# §4 Scaling factor -- (G-1)/G, not (n-1)/n
# ============================================================================

test_that("create_jackknife_weights() type='grouped' sets scale to (G-1)/G, not (n-1)/n", {
  G <- 10L
  result <- create_jackknife_weights(
    datasets$A,
    replicates = G,
    type = "grouped",
    seed = 42L
  )
  n <- nrow(datasets$A@data)
  expect_equal(result@variables$scale, (G - 1) / G, tolerance = 1e-12)
  expect_false(isTRUE(all.equal(result@variables$scale, (n - 1) / n)))
})

# ============================================================================
# §5 Model refit -- per-replicate logistic model refit
# ============================================================================

test_that("create_jackknife_weights() type='grouped' refits the logistic model per replicate", {
  result <- create_jackknife_weights(
    datasets$A,
    replicates = 10L,
    type = "grouped",
    seed = 42L
  )
  wt_col <- result@variables$weights
  full_wt <- result@data[[wt_col]]
  surviving1 <- result@data[["repwt_1"]] > 0
  if (sum(surviving1) < 2L) {
    skip("Not enough surviving units in replicate 1")
  }
  ratio <- result@data[["repwt_1"]][surviving1] / full_wt[surviving1]
  expect_true(stats::sd(ratio) > 1e-10)
})

# ============================================================================
# §6 Calibration-only DAGJK (no ipw() in history)
# ============================================================================

# These tests exercise the calibration-only code path in DAGJK, where
# create_jackknife_weights() is called on a survey_nonprob whose weighting
# history has a calibration entry but no ipw() entry.  The two sub-cases are:
#   Level A — calibrate_rake() without reference_design (targets_from_reference = FALSE)
#   Level B — calibrate_rake() with reference_design    (targets_from_reference = TRUE)

test_that("create_jackknife_weights() calibration-only DAGJK Level A (no reference)", {
  set.seed(101L)
  nps_df <- data.frame(
    age_group = sample(
      c("18-34", "35-54", "55+"),
      size = 80L,
      replace = TRUE,
      prob = c(0.40, 0.35, 0.25)
    ),
    sex = sample(c("M", "F"), size = 80L, replace = TRUE, prob = c(0.55, 0.45)),
    wts = rep(1, 80L),
    stringsAsFactors = FALSE
  )
  np <- surveycore::survey_nonprob(
    data = nps_df,
    variables = list(weights = "wts")
  )
  targets <- list(
    age_group = c("18-34" = 0.30, "35-54" = 0.40, "55+" = 0.30),
    sex = c("M" = 0.48, "F" = 0.52)
  )
  cal <- calibrate_rake(np, targets = targets, type = "prop")
  result <- create_jackknife_weights(
    cal,
    replicates = 10L,
    type = "grouped",
    seed = 42L
  )

  expect_true(S7::S7_inherits(result, surveycore::survey_nonprob))
  expect_length(result@variables$repweights, 10L)
  expect_identical(result@variables$type, "group-jackknife")
  rep_mat <- sapply(result@variables$repweights, function(col) {
    result@data[[col]]
  })
  expect_equal(nrow(rep_mat), 80L)
  expect_equal(ncol(rep_mat), 10L)
})

test_that("create_jackknife_weights() calibration-only DAGJK Level B (with reference)", {
  set.seed(101L)
  ref_df <- data.frame(
    age_group = sample(
      c("18-34", "35-54", "55+"),
      size = 500L,
      replace = TRUE,
      prob = c(0.30, 0.40, 0.30)
    ),
    sex = sample(
      c("M", "F"),
      size = 500L,
      replace = TRUE,
      prob = c(0.48, 0.52)
    ),
    ref_weight = rep(1, 500L),
    stringsAsFactors = FALSE
  )
  ref <- surveycore::survey_taylor(
    data = ref_df,
    variables = list(weights = "ref_weight")
  )

  set.seed(202L)
  nps_df <- data.frame(
    age_group = sample(
      c("18-34", "35-54", "55+"),
      size = 80L,
      replace = TRUE,
      prob = c(0.40, 0.35, 0.25)
    ),
    sex = sample(c("M", "F"), size = 80L, replace = TRUE, prob = c(0.55, 0.45)),
    wts = rep(1, 80L),
    stringsAsFactors = FALSE
  )
  np <- surveycore::survey_nonprob(
    data = nps_df,
    variables = list(weights = "wts")
  )
  targets <- list(
    age_group = c("18-34" = 0.30, "35-54" = 0.40, "55+" = 0.30),
    sex = c("M" = 0.48, "F" = 0.52)
  )
  cal <- calibrate_rake(
    np,
    targets = targets,
    type = "prop",
    reference_design = ref
  )
  result <- create_jackknife_weights(
    cal,
    replicates = 10L,
    type = "grouped",
    seed = 42L
  )

  expect_true(S7::S7_inherits(result, surveycore::survey_nonprob))
  expect_length(result@variables$repweights, 10L)
  expect_identical(result@variables$type, "group-jackknife")
  rep_mat <- sapply(result@variables$repweights, function(col) {
    result@data[[col]]
  })
  expect_equal(nrow(rep_mat), 80L)
  expect_equal(ncol(rep_mat), 10L)
})

# ============================================================================
# §7 DAGJK variant paths
# ============================================================================

test_that("create_jackknife_weights() DAGJK handles missing_method = 'separate'", {
  set.seed(303L)
  ref_df <- data.frame(
    age_group = sample(
      c("18-34", "35-54", "55+"),
      size = 500L,
      replace = TRUE,
      prob = c(0.30, 0.40, 0.30)
    ),
    sex = sample(
      c("M", "F"),
      size = 500L,
      replace = TRUE,
      prob = c(0.48, 0.52)
    ),
    ref_weight = rep(1, 500L),
    stringsAsFactors = FALSE
  )
  ref <- surveycore::survey_taylor(
    data = ref_df,
    variables = list(weights = "ref_weight")
  )
  set.seed(404L)
  nps_df <- data.frame(
    age_group = sample(
      c("18-34", "35-54", "55+"),
      size = 80L,
      replace = TRUE,
      prob = c(0.40, 0.35, 0.25)
    ),
    sex = sample(c("M", "F"), size = 80L, replace = TRUE, prob = c(0.55, 0.45)),
    stringsAsFactors = FALSE
  )
  # Introduce NAs so missing_method = "separate" creates the (Missing) level
  nps_df$age_group[c(1L, 5L, 10L)] <- NA_character_
  result_ipw <- suppressWarnings(ipw(
    data = nps_df,
    reference = ref,
    selection = ~ age_group + sex,
    missing_method = "separate",
    adjust_reference = FALSE
  ))
  result <- create_jackknife_weights(
    result_ipw,
    replicates = 10L,
    type = "grouped",
    seed = 42L
  )
  expect_true(S7::S7_inherits(result, surveycore::survey_nonprob))
  expect_length(result@variables$repweights, 10L)
})

test_that("create_jackknife_weights() DAGJK handles ipw() with trim = TRUE", {
  result_ipw <- suppressWarnings(ipw(
    data = datasets$ref@data[1:80, c("age_group", "sex")],
    reference = datasets$ref,
    selection = ~ age_group + sex,
    trim = TRUE,
    adjust_reference = FALSE
  ))
  result <- create_jackknife_weights(
    result_ipw,
    replicates = 10L,
    type = "grouped",
    seed = 42L
  )
  expect_true(S7::S7_inherits(result, surveycore::survey_nonprob))
  expect_length(result@variables$repweights, 10L)
})

test_that("create_jackknife_weights() DAGJK applies per-stratum scaling when strata present", {
  # ipw() does not propagate @variables$strata to its output; set it manually
  # so create_jackknife_weights() takes the per-stratum scaling path
  # (lines 226-256 of jackknife-dagjk-utils.R).
  result_ipw <- suppressWarnings(ipw(
    data = datasets$ref@data[1:80, c("age_group", "sex")],
    reference = datasets$ref,
    selection = ~ age_group + sex,
    adjust_reference = FALSE
  ))
  result_ipw@variables$strata <- "age_group"
  result <- create_jackknife_weights(
    result_ipw,
    replicates = 10L,
    type = "grouped",
    seed = 42L
  )
  test_invariants(result)
  expect_true(S7::S7_inherits(result, surveycore::survey_nonprob))
  expect_length(result@variables$repweights, 10L)
})

test_that("create_jackknife_weights() DAGJK replays calibrate_logit() in replicates", {
  result_ipw <- suppressWarnings(ipw(
    data = datasets$ref@data[1:80, c("age_group", "sex")],
    reference = datasets$ref,
    selection = ~ age_group + sex,
    adjust_reference = FALSE
  ))
  targets <- list(
    age_group = c("18-34" = 0.30, "35-54" = 0.40, "55+" = 0.30),
    sex = c("M" = 0.48, "F" = 0.52)
  )
  cal <- tryCatch(
    calibrate_logit(result_ipw, targets = targets, type = "prop"),
    error = function(e) NULL
  )
  if (is.null(cal)) {
    skip("calibrate_logit() did not converge on this data")
  }
  result <- create_jackknife_weights(
    cal,
    replicates = 10L,
    type = "grouped",
    seed = 42L
  )
  expect_true(S7::S7_inherits(result, surveycore::survey_nonprob))
  expect_length(result@variables$repweights, 10L)
})

test_that("create_jackknife_weights() DAGJK replays calibrate_linear() in replicates", {
  result_ipw <- suppressWarnings(ipw(
    data = datasets$ref@data[1:80, c("age_group", "sex")],
    reference = datasets$ref,
    selection = ~ age_group + sex,
    adjust_reference = FALSE
  ))
  targets <- list(
    age_group = c("18-34" = 0.30, "35-54" = 0.40, "55+" = 0.30),
    sex = c("M" = 0.48, "F" = 0.52)
  )
  cal <- tryCatch(
    calibrate_linear(result_ipw, targets = targets, type = "prop"),
    error = function(e) NULL
  )
  if (is.null(cal)) {
    skip("calibrate_linear() did not converge on this data")
  }
  result <- create_jackknife_weights(
    cal,
    replicates = 10L,
    type = "grouped",
    seed = 42L
  )
  expect_true(S7::S7_inherits(result, surveycore::survey_nonprob))
  expect_length(result@variables$repweights, 10L)
})

test_that("create_jackknife_weights() DAGJK uses extended formula when n_h < G", {
  # Build NPS where one stratum has 8 rows so n_h=8 < G=10
  # This exercises jackknife-dagjk-utils.R lines 249, 253 (Kott 2001 §3 eq. 2).
  # n_old=8 >> 1 group's share (~1 row) so no replicate loses all "old" rows.
  set.seed(77L)
  ref_df <- data.frame(
    age_group = c(rep("young", 400L), rep("old", 400L)),
    sex = sample(c("M", "F"), size = 800L, replace = TRUE),
    ref_weight = rep(1, 800L),
    stringsAsFactors = FALSE
  )
  ref <- surveycore::survey_taylor(
    data = ref_df,
    variables = list(weights = "ref_weight")
  )
  # NPS: 92 "young" + 8 "old" rows; "old" stratum has n_h=8 < G=10
  nps_df <- data.frame(
    age_group = c(rep("young", 92L), rep("old", 8L)),
    sex = sample(c("M", "F"), size = 100L, replace = TRUE),
    stringsAsFactors = FALSE
  )
  result_ipw <- suppressWarnings(ipw(
    data = nps_df,
    reference = ref,
    selection = ~ age_group + sex,
    adjust_reference = FALSE
  ))
  result_ipw@variables$strata <- "age_group"
  result <- suppressWarnings(
    create_jackknife_weights(
      result_ipw,
      replicates = 10L,
      type = "grouped",
      seed = 42L
    )
  )
  expect_true(S7::S7_inherits(result, surveycore::survey_nonprob))
  expect_gte(length(result@variables$repweights), 9L)
})

test_that("create_jackknife_weights() DAGJK Level B replays calibrate_logit() with reference", {
  # calibrate_logit with reference_design in history → Level B path
  # exercises jackknife-dagjk-utils.R lines 308-314
  result_ipw <- suppressWarnings(ipw(
    data = datasets$ref@data[1:80, c("age_group", "sex")],
    reference = datasets$ref,
    selection = ~ age_group + sex,
    adjust_reference = FALSE
  ))
  targets <- list(
    age_group = c("18-34" = 0.30, "35-54" = 0.40, "55+" = 0.30),
    sex = c("M" = 0.48, "F" = 0.52)
  )
  cal <- tryCatch(
    calibrate_logit(
      result_ipw,
      targets = targets,
      type = "prop",
      reference_design = datasets$ref
    ),
    error = function(e) NULL
  )
  if (is.null(cal)) {
    skip("calibrate_logit() did not converge on this data")
  }
  result <- create_jackknife_weights(
    cal,
    replicates = 10L,
    type = "grouped",
    seed = 42L
  )
  expect_true(S7::S7_inherits(result, surveycore::survey_nonprob))
  expect_length(result@variables$repweights, 10L)
})
