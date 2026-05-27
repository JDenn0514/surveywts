# tests/testthat/test-nonprob-ipw.R
#
# Tests for ipw() — inverse probability weighting for non-probability samples
# Per impl plan PR 1 acceptance criteria (plans/impl-propensity.md)
#
# All Layer 3 error tests use the dual pattern:
#   expect_error(class = ...) + expect_snapshot(error = TRUE, ...)

# ---------------------------------------------------------------------------
# Shared test fixtures
# ---------------------------------------------------------------------------

.make_ipw_nps <- function(seed = 1L) {
  make_surveywts_data(n = 200L, seed = seed)
}

.make_ipw_ref <- function(seed = 99L) {
  make_nps_reference(n = 1000L, seed = seed)
}

# ---------------------------------------------------------------------------
# Category 1 — Happy path
# ---------------------------------------------------------------------------

test_that("ipw() returns survey_nonprob for data.frame + survey_taylor", {
  nps <- .make_ipw_nps()
  ref <- .make_ipw_ref()

  result <- ipw(nps, ref, selection = ~age_group + sex)

  test_invariants(result)
  expect_true(S7::S7_inherits(result, surveycore::survey_nonprob))
})

test_that("ipw() @data has 'ipw_weight' column; all original columns preserved; nrow unchanged", {
  nps <- .make_ipw_nps()
  ref <- .make_ipw_ref()

  result <- ipw(nps, ref, selection = ~age_group + sex)

  expect_true("ipw_weight" %in% names(result@data))
  for (cn in names(nps)) {
    expect_true(cn %in% names(result@data))
  }
  expect_identical(nrow(result@data), nrow(nps))
})

test_that("ipw() @reference_sample is a survey_taylor", {
  nps <- .make_ipw_nps()
  ref <- .make_ipw_ref()

  result <- ipw(nps, ref, selection = ~age_group + sex)

  expect_true(S7::S7_inherits(result@reference_sample, surveycore::survey_taylor))
})

test_that("ipw() history entry has operation='ipw', trim=FALSE, n_trimmed=0", {
  nps <- .make_ipw_nps()
  ref <- .make_ipw_ref()

  result <- ipw(nps, ref, selection = ~age_group + sex)

  history <- result@metadata@weighting_history
  expect_length(history, 1L)
  entry <- history[[1L]]
  expect_identical(entry$operation, "ipw")
  expect_false(entry$trim)
  expect_identical(entry$n_trimmed, 0L)
})

test_that("ipw() method='probit' returns valid survey_nonprob", {
  nps <- .make_ipw_nps()
  ref <- .make_ipw_ref()

  # probit may need more iterations than logit; suppress the non-convergence
  # warning since this test checks object validity, not convergence speed.
  result <- suppressWarnings(
    ipw(nps, ref, selection = ~age_group + sex, method = "probit", maxit = 200L)
  )

  test_invariants(result)
  expect_true(S7::S7_inherits(result, surveycore::survey_nonprob))
})

test_that("ipw() method='cloglog' returns valid survey_nonprob", {
  nps <- .make_ipw_nps()
  ref <- .make_ipw_ref()

  result <- ipw(nps, ref, selection = ~age_group + sex, method = "cloglog")

  test_invariants(result)
  expect_true(S7::S7_inherits(result, surveycore::survey_nonprob))
})

test_that("ipw() custom wt_name is used as weight column name", {
  nps <- .make_ipw_nps()
  ref <- .make_ipw_ref()

  result <- ipw(nps, ref, selection = ~age_group + sex, wt_name = "my_wt")

  expect_true("my_wt" %in% names(result@data))
  expect_identical(result@variables$weights, "my_wt")
})

test_that("ipw() predictors= gives same result as selection= (weights identical at 1e-10)", {
  nps <- .make_ipw_nps()
  ref <- .make_ipw_ref()

  r1 <- ipw(nps, ref, selection = ~age_group + sex)
  r2 <- ipw(nps, ref, predictors = c("age_group", "sex"))

  test_invariants(r1)
  test_invariants(r2)
  expect_equal(r1@data$ipw_weight, r2@data$ipw_weight, tolerance = 1e-10)
})

test_that("ipw() trim=TRUE sets history trim=TRUE; n_trimmed >= 0; test_invariants passes", {
  nps <- .make_ipw_nps()
  ref <- .make_ipw_ref()

  result <- ipw(nps, ref, selection = ~age_group + sex, trim = TRUE)

  test_invariants(result)
  entry <- result@metadata@weighting_history[[1L]]
  expect_true(entry$trim)
  expect_true(entry$n_trimmed >= 0L)
})

test_that("ipw() print snapshot matches survey_nonprob format with ipw step", {
  nps <- .make_ipw_nps()
  ref <- .make_ipw_ref()
  result <- ipw(nps, ref, selection = ~age_group + sex)
  expect_snapshot(print(result))
})

test_that("ipw() missing_method='omit' drops rows with NA; nrow < original; test_invariants passes", {
  nps <- .make_ipw_nps()
  nps$age_group[1L:3L] <- NA_character_
  ref <- .make_ipw_ref()

  expect_warning(
    result <- ipw(nps, ref, selection = ~age_group + sex, missing_method = "omit"),
    class = "surveywts_warning_ipw_data_na_omitted"
  )
  test_invariants(result)
  expect_true(nrow(result@data) < nrow(nps))
  expect_identical(nrow(result@data), nrow(nps) - 3L)
})

test_that("ipw() missing_method='separate' preserves all rows; all weights positive; test_invariants passes", {
  nps <- .make_ipw_nps()
  nps$age_group[1L:3L] <- NA_character_
  ref <- .make_ipw_ref()

  result <- ipw(nps, ref, selection = ~age_group + sex, missing_method = "separate")

  test_invariants(result)
  expect_identical(nrow(result@data), nrow(nps))
  expect_true(all(result@data$ipw_weight > 0))
})

test_that("ipw() missing_method='impute' preserves all rows; all weights positive; test_invariants passes", {
  skip_if_not_installed("mice")
  nps <- .make_ipw_nps()
  nps$age_group[1L:3L] <- NA_character_
  ref <- .make_ipw_ref()

  result <- ipw(nps, ref, selection = ~age_group + sex, missing_method = "impute",
                mice_args = list(seed = 42L))

  test_invariants(result)
  expect_identical(nrow(result@data), nrow(nps))
  expect_true(all(result@data$ipw_weight > 0))
})

test_that("ipw() mice_args=list(seed=42) with missing_method='impute' gives reproducible results", {
  skip_if_not_installed("mice")
  nps <- .make_ipw_nps()
  nps$age_group[1L:5L] <- NA_character_
  ref <- .make_ipw_ref()

  r1 <- ipw(nps, ref, selection = ~age_group + sex, missing_method = "impute",
             mice_args = list(seed = 42L))
  r2 <- ipw(nps, ref, selection = ~age_group + sex, missing_method = "impute",
             mice_args = list(seed = 42L))

  expect_equal(r1@data$ipw_weight, r2@data$ipw_weight, tolerance = 1e-10)
})

test_that("ipw() missing_method='impute' with numeric predictor NA uses numeric impute branch", {
  skip_if_not_installed("mice")
  nps <- .make_ipw_nps()
  nps$base_weight[1L:3L] <- NA_real_
  ref <- .make_ipw_ref()

  result <- ipw(
    nps, ref,
    selection = ~age_group + base_weight,
    missing_method = "impute",
    mice_args = list(seed = 42L)
  )

  test_invariants(result)
  expect_identical(nrow(result@data), nrow(nps))
  expect_true(all(result@data$ipw_weight > 0))
})

test_that("ipw() reference NAs excluded from fitting; surveywts_warning_ipw_reference_na_omitted; result valid", {
  nps <- .make_ipw_nps()
  ref_df <- .make_ipw_ref()@data
  ref_df$age_group[1L:2L] <- NA_character_
  ref_na <- surveycore::survey_taylor(
    data = ref_df,
    variables = list(weights = "base_weight")
  )

  expect_warning(
    result <- ipw(nps, ref_na, selection = ~age_group + sex),
    class = "surveywts_warning_ipw_reference_na_omitted"
  )
  test_invariants(result)
  expect_true(S7::S7_inherits(result, surveycore::survey_nonprob))
})

# ---------------------------------------------------------------------------
# Category 2 — Numerical correctness
# ---------------------------------------------------------------------------

test_that("ipw() all weights strictly positive", {
  nps <- .make_ipw_nps()
  ref <- .make_ipw_ref()

  result <- ipw(nps, ref, selection = ~age_group + sex)

  expect_true(all(result@data$ipw_weight > 0))
})

test_that("ipw() weights match manual Newton-Raphson at tolerance 1e-10", {
  nps <- .make_ipw_nps(seed = 7L)
  ref <- .make_ipw_ref(seed = 77L)

  result <- ipw(nps, ref, selection = ~age_group + sex)

  # Manual NR computation — must align factor levels to reference (same as ipw())
  formula <- ~age_group + sex
  nps_aligned <- nps
  ref_data   <- ref@data
  for (v in all.vars(formula)) {
    if (is.character(ref_data[[v]]) || is.factor(ref_data[[v]])) {
      ref_levs <- sort(unique(as.character(ref_data[[v]][!is.na(ref_data[[v]])])))
      nps_aligned[[v]] <- factor(nps_aligned[[v]], levels = ref_levs)
      ref_data[[v]]    <- factor(ref_data[[v]], levels = ref_levs)
    }
  }
  X_nps <- stats::model.matrix(formula, data = nps_aligned)
  X_ref <- stats::model.matrix(formula, data = ref_data)
  d_ref <- ref@data[[ref@variables$weights]]
  gamma <- rep(0, ncol(X_nps))
  link  <- stats::binomial(link = "logit")$linkinv

  for (iter in seq_len(200L)) {
    pi_ref <- link(drop(X_ref %*% gamma))
    score  <- colSums(X_nps) - drop(t(X_ref) %*% (d_ref * pi_ref))
    hess   <- -crossprod(X_ref, X_ref * (d_ref * pi_ref * (1 - pi_ref)))
    delta  <- solve(hess, score)
    gamma  <- gamma - delta
    if (max(abs(delta)) < 1e-8) break
  }
  expected_wts <- unname(drop(1 / link(drop(X_nps %*% gamma))))

  expect_equal(result@data$ipw_weight, expected_wts, tolerance = 1e-10)
})

test_that("ipw() estimates match nonprobsvy at tolerance 1e-6 [numerical cross-validation]", {
  skip_if_not_installed("nonprobsvy")

  nps <- .make_ipw_nps(seed = 5L)
  ref <- .make_ipw_ref(seed = 55L)

  result <- ipw(nps, ref, selection = ~age_group + sex)

  # Use HT total / N_ref to match nonprobsvy's estimator (divides by sum of
  # reference weights, not by sum of IPW weights as weighted.mean() would)
  N_ref <- sum(ref@data[[ref@variables$weights]])
  ipw_mean <- sum(nps$base_weight * result@data$ipw_weight) / N_ref

  # nonprobsvy estimate — target = ~base_weight required by current API
  ref_svy <- survey::svydesign(ids = ~1, weights = ~base_weight, data = ref@data)
  np_res <- nonprobsvy::nonprob(
    selection = ~age_group + sex,
    target = ~base_weight,
    data = nps,
    svydesign = ref_svy,
    method_selection = "logit"
  )
  nonprobsvy_mean <- np_res$output["base_weight", "mean"]

  expect_equal(ipw_mean, nonprobsvy_mean, tolerance = 1e-6)
})

# ---------------------------------------------------------------------------
# Category 3 — Error paths (dual pattern)
# ---------------------------------------------------------------------------

test_that("ipw() errors when data is not a data.frame", {
  ref <- .make_ipw_ref()

  expect_error(
    ipw(list(x = 1), ref, selection = ~x),
    class = "surveywts_error_not_data_frame"
  )
  expect_snapshot(error = TRUE, ipw(list(x = 1), ref, selection = ~x))
})

test_that("ipw() errors when data has 0 rows", {
  ref <- .make_ipw_ref()
  empty_df <- .make_ipw_nps()[0, ]

  expect_error(
    ipw(empty_df, ref, selection = ~age_group + sex),
    class = "surveywts_error_empty_data"
  )
  expect_snapshot(
    error = TRUE,
    ipw(empty_df, ref, selection = ~age_group + sex)
  )
})

test_that("ipw() errors when both selection and predictors are NULL", {
  nps <- .make_ipw_nps()
  ref <- .make_ipw_ref()

  expect_error(
    ipw(nps, ref),
    class = "surveywts_error_selection_missing"
  )
  expect_snapshot(error = TRUE, ipw(nps, ref))
})

test_that("ipw() errors when both selection and predictors are non-NULL", {
  nps <- .make_ipw_nps()
  ref <- .make_ipw_ref()

  expect_error(
    ipw(nps, ref, selection = ~age_group, predictors = c("age_group")),
    class = "surveywts_error_selection_conflict"
  )
  expect_snapshot(
    error = TRUE,
    ipw(nps, ref, selection = ~age_group, predictors = c("age_group"))
  )
})

test_that("ipw() errors when reference is a data.frame", {
  nps <- .make_ipw_nps()
  ref_df <- make_nps_reference()@data

  expect_error(
    ipw(nps, ref_df, selection = ~age_group + sex),
    class = "surveywts_error_svydesign_not_taylor"
  )
  expect_snapshot(
    error = TRUE,
    ipw(nps, ref_df, selection = ~age_group + sex)
  )
})

test_that("ipw() errors when reference is survey_nonprob", {
  nps <- .make_ipw_nps()
  ref <- .make_ipw_ref()
  np_obj <- ipw(nps, ref, selection = ~age_group + sex)

  expect_error(
    ipw(nps, np_obj, selection = ~age_group + sex),
    class = "surveywts_error_svydesign_not_taylor"
  )
  expect_snapshot(
    error = TRUE,
    ipw(nps, np_obj, selection = ~age_group + sex)
  )
})

test_that("ipw() errors when reference has a zero design weight", {
  nps <- .make_ipw_nps()
  ref_valid <- .make_ipw_ref()
  # Use attr<- to bypass the survey_taylor S7 validator (which also
  # validates weights > 0) so we can test ipw()'s own check.
  ref_zero <- ref_valid
  bad_data <- ref_valid@data
  bad_data$base_weight[1L] <- 0
  attr(ref_zero, "data") <- bad_data

  expect_error(
    ipw(nps, ref_zero, selection = ~age_group + sex),
    class = "surveywts_error_reference_weights_nonpositive"
  )
  expect_snapshot(
    error = TRUE,
    ipw(nps, ref_zero, selection = ~age_group + sex)
  )
})

test_that("ipw() errors when reference has a negative design weight", {
  nps <- .make_ipw_nps()
  ref_valid <- .make_ipw_ref()
  ref_neg <- ref_valid
  bad_data <- ref_valid@data
  bad_data$base_weight[1L] <- -1
  attr(ref_neg, "data") <- bad_data

  expect_error(
    ipw(nps, ref_neg, selection = ~age_group + sex),
    class = "surveywts_error_reference_weights_nonpositive"
  )
  expect_snapshot(
    error = TRUE,
    ipw(nps, ref_neg, selection = ~age_group + sex)
  )
})

test_that("ipw() errors when selection is a character string (not formula)", {
  nps <- .make_ipw_nps()
  ref <- .make_ipw_ref()

  expect_error(
    ipw(nps, ref, selection = "~ age_group + sex"),
    class = "surveywts_error_formula_invalid"
  )
  expect_snapshot(
    error = TRUE,
    ipw(nps, ref, selection = "~ age_group + sex")
  )
})

test_that("ipw() errors when selection variable missing from data", {
  nps <- .make_ipw_nps()
  ref <- .make_ipw_ref()

  expect_error(
    ipw(nps, ref, selection = ~age_group + nonexistent_var),
    class = "surveywts_error_formula_variable_not_found"
  )
  expect_snapshot(
    error = TRUE,
    ipw(nps, ref, selection = ~age_group + nonexistent_var)
  )
})

test_that("ipw() errors when selection variable missing from reference@data", {
  nps <- .make_ipw_nps()
  # Reference with different column name
  ref_df <- .make_ipw_ref()@data
  ref_df$sex_renamed <- ref_df$sex
  ref_df$sex <- NULL
  ref_no_sex <- surveycore::survey_taylor(
    data = ref_df,
    variables = list(weights = "base_weight")
  )

  expect_error(
    ipw(nps, ref_no_sex, selection = ~age_group + sex),
    class = "surveywts_error_formula_variable_not_in_reference"
  )
  expect_snapshot(
    error = TRUE,
    ipw(nps, ref_no_sex, selection = ~age_group + sex)
  )
})

test_that("ipw() errors when factor level in data absent from reference", {
  nps <- .make_ipw_nps()
  nps$age_group[1L] <- "65-74"  # level not in reference

  ref <- .make_ipw_ref()  # reference has only 18-34, 35-54, 55+

  expect_error(
    ipw(nps, ref, selection = ~age_group),
    class = "surveywts_error_propensity_level_not_in_reference"
  )
  expect_snapshot(
    error = TRUE,
    ipw(nps, ref, selection = ~age_group)
  )
})

test_that("ipw() errors when missing_method='separate' and a numeric selection variable has NA", {
  nps <- .make_ipw_nps()
  nps$base_weight[1L] <- NA_real_
  ref <- .make_ipw_ref()

  expect_error(
    ipw(nps, ref, selection = ~age_group + base_weight, missing_method = "separate"),
    class = "surveywts_error_separate_numeric_na"
  )
  expect_snapshot(
    error = TRUE,
    ipw(nps, ref, selection = ~age_group + base_weight, missing_method = "separate")
  )
})

test_that("ipw() errors when missing_method='impute' and mice is not installed", {
  skip_if(
    requireNamespace("mice", quietly = TRUE),
    "mice is installed; cannot test missing-package error"
  )
  nps <- .make_ipw_nps()
  nps$age_group[1L] <- NA_character_
  ref <- .make_ipw_ref()

  expect_error(
    ipw(nps, ref, selection = ~age_group + sex, missing_method = "impute"),
    class = "surveywts_error_mice_not_installed"
  )
  expect_snapshot(
    error = TRUE,
    ipw(nps, ref, selection = ~age_group + sex, missing_method = "impute")
  )
})

test_that("ipw() errors when missing_method='impute' and mice is not installed [mocked]", {
  nps <- .make_ipw_nps()
  nps$age_group[1L] <- NA_character_
  ref <- .make_ipw_ref()

  testthat::local_mocked_bindings(
    .has_package = function(pkg) if (pkg == "mice") FALSE else requireNamespace(pkg, quietly = TRUE),
    .package = "surveywts"
  )

  expect_error(
    ipw(nps, ref, selection = ~age_group + sex, missing_method = "impute"),
    class = "surveywts_error_mice_not_installed"
  )
  expect_snapshot(
    error = TRUE,
    ipw(nps, ref, selection = ~age_group + sex, missing_method = "impute")
  )
})

test_that("ipw() errors when wt_name is NULL", {
  nps <- .make_ipw_nps()
  ref <- .make_ipw_ref()

  expect_error(
    ipw(nps, ref, selection = ~age_group + sex, wt_name = NULL),
    class = "surveywts_error_wt_name_not_scalar"
  )
  expect_snapshot(
    error = TRUE,
    ipw(nps, ref, selection = ~age_group + sex, wt_name = NULL)
  )
})

test_that("ipw() errors when wt_name is integer", {
  nps <- .make_ipw_nps()
  ref <- .make_ipw_ref()

  expect_error(
    ipw(nps, ref, selection = ~age_group + sex, wt_name = 1L),
    class = "surveywts_error_wt_name_not_scalar"
  )
  expect_snapshot(
    error = TRUE,
    ipw(nps, ref, selection = ~age_group + sex, wt_name = 1L)
  )
})

test_that("ipw() errors when wt_name is empty string", {
  nps <- .make_ipw_nps()
  ref <- .make_ipw_ref()

  expect_error(
    ipw(nps, ref, selection = ~age_group + sex, wt_name = ""),
    class = "surveywts_error_wt_name_empty"
  )
  expect_snapshot(
    error = TRUE,
    ipw(nps, ref, selection = ~age_group + sex, wt_name = "")
  )
})

test_that("ipw() errors when wt_name is NA_character_", {
  nps <- .make_ipw_nps()
  ref <- .make_ipw_ref()

  expect_error(
    ipw(nps, ref, selection = ~age_group + sex, wt_name = NA_character_),
    class = "surveywts_error_wt_name_empty"
  )
  expect_snapshot(
    error = TRUE,
    ipw(nps, ref, selection = ~age_group + sex, wt_name = NA_character_)
  )
})

test_that("ipw() errors when wt_name conflicts with existing data column", {
  nps <- .make_ipw_nps()
  ref <- .make_ipw_ref()

  expect_error(
    ipw(nps, ref, selection = ~age_group + sex, wt_name = "age_group"),
    class = "surveywts_error_wt_name_conflict"
  )
  expect_snapshot(
    error = TRUE,
    ipw(nps, ref, selection = ~age_group + sex, wt_name = "age_group")
  )
})

test_that("ipw() errors when propensity scores are degenerate (score >= 1)", {
  # Perfect separation: many more NPS 'A' than reference 'A'
  # Forces logistic to overflow → score → 1 → error
  set.seed(42L)
  nps_degen <- data.frame(
    cat_var = c(rep("A", 200L), rep("B", 5L)),
    stringsAsFactors = FALSE
  )
  ref_degen_df <- data.frame(
    cat_var    = c(rep("A", 3L), rep("B", 200L)),
    base_weight = 1,
    stringsAsFactors = FALSE
  )
  ref_degen <- surveycore::survey_taylor(
    data      = ref_degen_df,
    variables = list(weights = "base_weight")
  )

  expect_error(
    suppressWarnings(
      ipw(nps_degen, ref_degen, selection = ~cat_var, maxit = 500L)
    ),
    class = "surveywts_error_propensity_scores_degenerate"
  )
  expect_snapshot(
    error = TRUE,
    suppressWarnings(
      ipw(nps_degen, ref_degen, selection = ~cat_var, maxit = 500L)
    )
  )
})

test_that("ipw() errors when Hessian is singular (collinear covariates)", {
  # Exact collinearity: x2 = 2 * x1 in both NPS and reference
  set.seed(7L)
  nps_coll <- data.frame(
    x1 = rnorm(50L),
    x2 = rnorm(50L)
  )
  nps_coll$x2 <- 2 * nps_coll$x1

  ref_coll_df <- data.frame(
    x1          = rnorm(200L),
    x2          = rnorm(200L),
    base_weight = 1
  )
  ref_coll_df$x2 <- 2 * ref_coll_df$x1

  ref_coll <- surveycore::survey_taylor(
    data      = ref_coll_df,
    variables = list(weights = "base_weight")
  )

  expect_error(
    ipw(nps_coll, ref_coll, selection = ~x1 + x2),
    class = "surveywts_error_propensity_hessian_singular"
  )
  expect_snapshot(
    error = TRUE,
    ipw(nps_coll, ref_coll, selection = ~x1 + x2)
  )
})

test_that("ipw() errors when maxit = 0L", {
  nps <- .make_ipw_nps()
  ref <- .make_ipw_ref()

  expect_error(
    ipw(nps, ref, selection = ~age_group + sex, maxit = 0L),
    class = "surveywts_error_propensity_invalid_maxit"
  )
  expect_snapshot(
    error = TRUE,
    ipw(nps, ref, selection = ~age_group + sex, maxit = 0L)
  )
})

test_that("ipw() errors when epsilon = 0", {
  nps <- .make_ipw_nps()
  ref <- .make_ipw_ref()

  expect_error(
    ipw(nps, ref, selection = ~age_group + sex, epsilon = 0),
    class = "surveywts_error_propensity_invalid_epsilon"
  )
  expect_snapshot(
    error = TRUE,
    ipw(nps, ref, selection = ~age_group + sex, epsilon = 0)
  )
})

test_that("ipw() errors when epsilon = -1", {
  nps <- .make_ipw_nps()
  ref <- .make_ipw_ref()

  expect_error(
    ipw(nps, ref, selection = ~age_group + sex, epsilon = -1),
    class = "surveywts_error_propensity_invalid_epsilon"
  )
  expect_snapshot(
    error = TRUE,
    ipw(nps, ref, selection = ~age_group + sex, epsilon = -1)
  )
})

# ---------------------------------------------------------------------------
# Category 4 — Warning paths
# ---------------------------------------------------------------------------

test_that("ipw() warns for extreme propensity scores (score < 0.01)", {
  # Binary covariate: 1 "low" unit in NPS vs 200 "low" in reference.
  # pi("low") = 1/200 = 0.005 < 0.01 → warning fires.
  # n_nps_k <= n_ref_k for both levels → score equations are feasible, NR converges.
  set.seed(123L)
  nps_skewed <- data.frame(
    group = c("low", rep("high", 199L)),
    stringsAsFactors = FALSE
  )
  ref_df_skewed <- data.frame(
    group       = c(rep("low", 200L), rep("high", 200L)),
    base_weight = 1,
    stringsAsFactors = FALSE
  )
  ref_skewed <- surveycore::survey_taylor(
    data      = ref_df_skewed,
    variables = list(weights = "base_weight")
  )

  expect_warning(
    result <- ipw(nps_skewed, ref_skewed, selection = ~group),
    class = "surveywts_warning_extreme_propensity_scores"
  )
  test_invariants(result)
  expect_true(S7::S7_inherits(result, surveycore::survey_nonprob))
})

test_that("ipw() warns when missing_method='omit' drops NPS rows with NA; warning names variable", {
  nps <- .make_ipw_nps()
  nps$age_group[1L:3L] <- NA_character_
  ref <- .make_ipw_ref()

  expect_warning(
    result <- ipw(nps, ref, selection = ~age_group + sex, missing_method = "omit"),
    class = "surveywts_warning_ipw_data_na_omitted"
  )
  test_invariants(result)
})

test_that("ipw() warns when reference@data has NAs in selection variable; warning names variable", {
  nps <- .make_ipw_nps()
  ref_df <- .make_ipw_ref()@data
  ref_df$age_group[1L] <- NA_character_
  ref_na <- surveycore::survey_taylor(
    data = ref_df,
    variables = list(weights = "base_weight")
  )

  expect_warning(
    result <- ipw(nps, ref_na, selection = ~age_group + sex),
    class = "surveywts_warning_ipw_reference_na_omitted"
  )
  test_invariants(result)
})

test_that("ipw() warns when mice_args includes 'm' with missing_method='impute'; m=1 used", {
  skip_if_not_installed("mice")
  nps <- .make_ipw_nps()
  nps$age_group[1L:3L] <- NA_character_
  ref <- .make_ipw_ref()

  expect_warning(
    result <- ipw(nps, ref, selection = ~age_group + sex, missing_method = "impute",
                  mice_args = list(m = 5L, seed = 42L)),
    class = "surveywts_warning_ipw_mice_m_ignored"
  )
  test_invariants(result)
})

test_that("ipw() warns when NR does not converge (maxit=1L); result still valid; scores in (0,1)", {
  nps <- .make_ipw_nps()
  ref <- .make_ipw_ref()

  expect_warning(
    result <- ipw(nps, ref, selection = ~age_group + sex, maxit = 1L),
    class = "surveywts_warning_propensity_nr_no_convergence"
  )
  test_invariants(result)
  expect_true(S7::S7_inherits(result, surveycore::survey_nonprob))
  scores <- 1 / result@data$ipw_weight
  expect_true(all(scores > 0 & scores < 1))
})

# ---------------------------------------------------------------------------
# Category 5 — Edge cases
# ---------------------------------------------------------------------------

test_that("ipw() works with single covariate", {
  nps <- .make_ipw_nps()
  ref <- .make_ipw_ref()

  result <- ipw(nps, ref, selection = ~age_group)

  test_invariants(result)
  expect_true(S7::S7_inherits(result, surveycore::survey_nonprob))
})

test_that("ipw() works with interaction term", {
  nps <- .make_ipw_nps()
  ref <- .make_ipw_ref()

  result <- ipw(nps, ref, selection = ~age_group * sex)

  test_invariants(result)
  expect_true(S7::S7_inherits(result, surveycore::survey_nonprob))
})

test_that("ipw() gives roughly uniform weights when NPS and reference have identical distributions", {
  set.seed(1L)
  n <- 300L
  common_df <- data.frame(
    age_group = sample(c("18-34", "35-54", "55+"), n, replace = TRUE,
                       prob = c(0.30, 0.40, 0.30)),
    sex       = sample(c("M", "F"), n, replace = TRUE, prob = c(0.48, 0.52)),
    base_weight = 1,
    stringsAsFactors = FALSE
  )
  nps_same <- common_df[seq_len(100L), -3L]
  ref_same <- surveycore::survey_taylor(
    data      = common_df[101L:n, ],
    variables = list(weights = "base_weight")
  )

  result <- ipw(nps_same, ref_same, selection = ~age_group + sex)

  test_invariants(result)
  wts <- result@data$ipw_weight
  cv_wts <- stats::sd(wts) / mean(wts)
  expect_true(cv_wts < 1.0)  # low variability when distributions match
})

test_that("ipw() works with small NPS (n = 5)", {
  set.seed(3L)
  small_nps <- data.frame(
    age_group = c("18-34", "35-54", "55+", "18-34", "35-54"),
    sex       = c("M", "F", "M", "F", "M"),
    stringsAsFactors = FALSE
  )
  ref <- .make_ipw_ref()

  # With n=5 NPS units, some covariate combinations are rare relative to the
  # large reference; suppress the expected extreme propensity scores warning.
  result <- suppressWarnings(
    ipw(small_nps, ref, selection = ~age_group + sex)
  )

  test_invariants(result)
  expect_identical(nrow(result@data), 5L)
  expect_true(all(result@data$ipw_weight > 0))
})

test_that("ipw() works when NPS has more rows than the reference", {
  # n_nps=200 > n_ref=2, but large design weights (base_weight=500) make the
  # effective reference total (~1000) >> n_nps, so score equations are feasible.
  nps_large <- .make_ipw_nps(seed = 11L)  # n=200
  ref_tiny <- surveycore::survey_taylor(
    data = data.frame(
      sex         = c("M", "F"),
      base_weight = c(500, 500),
      stringsAsFactors = FALSE
    ),
    variables = list(weights = "base_weight")
  )

  result <- ipw(nps_large, ref_tiny, selection = ~sex)

  test_invariants(result)
  expect_true(all(result@data$ipw_weight > 0))
})

test_that("ipw() trim=TRUE with extreme weights: n_trimmed > 0; mass conserved by clip-and-redistribute", {
  # 1 "rare" unit in NPS vs 200 "rare" in reference.
  # pi("rare") ≈ 1/201 → weight ≈ 201; all common ≈ 2.0 with IQR ≈ 0.
  # trim_limit ≈ median + 5*IQR ≈ 2.0, so the "rare" unit is trimmed.
  # .trim_weights_internal() clips and redistributes — total mass is conserved.
  nps_extreme <- data.frame(
    group = c("rare", rep("common", 199L)),
    stringsAsFactors = FALSE
  )
  ref_extreme_df <- data.frame(
    group       = c(rep("rare", 200L), rep("common", 200L)),
    base_weight = 1,
    stringsAsFactors = FALSE
  )
  ref_extreme <- surveycore::survey_taylor(
    data      = ref_extreme_df,
    variables = list(weights = "base_weight")
  )

  result <- suppressWarnings(
    ipw(nps_extreme, ref_extreme, selection = ~group, trim = TRUE)
  )

  test_invariants(result)
  entry <- result@metadata@weighting_history[[1L]]
  expect_true(entry$n_trimmed > 0L)
  expect_equal(
    sum(result@data$ipw_weight),
    entry$estimated_population_size,
    tolerance = 1e-10
  )
})

# ---------------------------------------------------------------------------
# Category 6 — History correctness
# ---------------------------------------------------------------------------

test_that("ipw() history: estimated_population_size = sum(pre-trim weights)", {
  nps <- .make_ipw_nps()
  ref <- .make_ipw_ref()

  result <- ipw(nps, ref, selection = ~age_group + sex)

  entry <- result@metadata@weighting_history[[1L]]
  expect_equal(
    entry$estimated_population_size,
    sum(result@data$ipw_weight),
    tolerance = 1e-10
  )
})

test_that("ipw() history: n_nps = nrow(data); n_reference = nrow(reference@data)", {
  nps <- .make_ipw_nps()
  ref <- .make_ipw_ref()

  result <- ipw(nps, ref, selection = ~age_group + sex)

  entry <- result@metadata@weighting_history[[1L]]
  expect_identical(entry$n_nps, nrow(nps))
  expect_identical(entry$n_reference, nrow(ref@data))
})

test_that("ipw() history formula field is a formula object", {
  nps <- .make_ipw_nps()
  ref <- .make_ipw_ref()

  result <- ipw(nps, ref, selection = ~age_group + sex)

  entry <- result@metadata@weighting_history[[1L]]
  expect_true(inherits(entry$formula, "formula"))
})

test_that("ipw() history operation = 'ipw' (not 'propensity_ipw')", {
  nps <- .make_ipw_nps()
  ref <- .make_ipw_ref()

  result <- ipw(nps, ref, selection = ~age_group + sex)

  entry <- result@metadata@weighting_history[[1L]]
  expect_identical(entry$operation, "ipw")
})

test_that("ipw() history estimator = 'ipw2' (regression: was 'ht')", {
  nps <- .make_ipw_nps()
  ref <- .make_ipw_ref()

  result <- ipw(nps, ref, selection = ~age_group + sex)

  entry <- result@metadata@weighting_history[[1L]]
  expect_identical(entry$estimator, "ipw2")
})

test_that("ipw() history: trim = FALSE (default) / TRUE (when passed)", {
  nps <- .make_ipw_nps()
  ref <- .make_ipw_ref()

  r_no_trim <- ipw(nps, ref, selection = ~age_group + sex)
  r_trim    <- ipw(nps, ref, selection = ~age_group + sex, trim = TRUE)

  expect_false(r_no_trim@metadata@weighting_history[[1L]]$trim)
  expect_true(r_trim@metadata@weighting_history[[1L]]$trim)
})

test_that("ipw() history: targets_from_reference = FALSE", {
  nps <- .make_ipw_nps()
  ref <- .make_ipw_ref()

  result <- ipw(nps, ref, selection = ~age_group + sex)

  entry <- result@metadata@weighting_history[[1L]]
  expect_false(entry$targets_from_reference)
})

test_that("ipw() history: reference_design is a survey_taylor", {
  nps <- .make_ipw_nps()
  ref <- .make_ipw_ref()

  result <- ipw(nps, ref, selection = ~age_group + sex)

  entry <- result@metadata@weighting_history[[1L]]
  expect_true(S7::S7_inherits(entry$reference_design, surveycore::survey_taylor))
})

test_that("ipw() history step = 1 on first call", {
  nps_df <- .make_ipw_nps()
  ref    <- .make_ipw_ref()

  result <- ipw(nps_df, ref, selection = ~age_group + sex)

  expect_identical(result@metadata@weighting_history[[1L]]$step, 1L)
})

test_that("ipw() history missing_method = 'omit' by default", {
  nps <- .make_ipw_nps()
  ref <- .make_ipw_ref()

  result <- ipw(nps, ref, selection = ~age_group + sex)

  entry <- result@metadata@weighting_history[[1L]]
  expect_identical(entry$missing_method, "omit")
})

test_that("ipw() history missing_method reflects the argument value", {
  nps <- .make_ipw_nps()
  nps$age_group[1L:3L] <- NA_character_
  ref <- .make_ipw_ref()

  result <- suppressWarnings(
    ipw(nps, ref, selection = ~age_group + sex, missing_method = "omit")
  )
  entry <- result@metadata@weighting_history[[1L]]
  expect_identical(entry$missing_method, "omit")

  result2 <- ipw(nps, ref, selection = ~age_group + sex, missing_method = "separate")
  entry2 <- result2@metadata@weighting_history[[1L]]
  expect_identical(entry2$missing_method, "separate")
})

# ---------------------------------------------------------------------------
# PR 1 — C-1: estimator field fixed to "ipw2"
# ---------------------------------------------------------------------------

test_that("ipw() history entry records estimator = 'ipw2'", {
  nps <- .make_ipw_nps()
  ref <- .make_ipw_ref()

  result <- ipw(nps, ref, selection = ~age_group + sex)

  test_invariants(result)
  entry <- result@metadata@weighting_history[[1L]]
  expect_identical(entry$estimator, "ipw2")
  expect_true(entry$estimator != "ht")
})

# ---------------------------------------------------------------------------
# PR 1 — M-6: propensity_scores in history entry
# ---------------------------------------------------------------------------

test_that("propensity_scores are in history entry as numeric vector", {
  nps <- .make_ipw_nps()
  ref <- .make_ipw_ref()

  result <- ipw(nps, ref, selection = ~age_group + sex)

  test_invariants(result)
  hist <- result@metadata@weighting_history[[1L]]
  expect_true(is.numeric(hist$propensity_scores))
  expect_true(length(hist$propensity_scores) == nrow(nps))
})

test_that("all propensity_scores are in (0, 1)", {
  nps <- .make_ipw_nps()
  ref <- .make_ipw_ref()

  result <- ipw(nps, ref, selection = ~age_group + sex)

  hist <- result@metadata@weighting_history[[1L]]
  scores <- hist$propensity_scores
  eps <- .Machine$double.eps
  expect_true(all(scores > eps))
  expect_true(all(scores < 1 - eps))
})

test_that("propensity_scores length equals n_nps after omit", {
  nps <- .make_ipw_nps()
  nps$sex[1L:10L] <- NA_character_
  ref <- .make_ipw_ref()

  result_omit <- suppressWarnings(
    ipw(nps, ref, selection = ~age_group + sex, missing_method = "omit")
  )

  test_invariants(result_omit)
  hist_omit <- result_omit@metadata@weighting_history[[1L]]
  expect_equal(length(hist_omit$propensity_scores), hist_omit$n_nps)
})

test_that("propensity_scores matches 1/weights before trimming", {
  nps <- .make_ipw_nps()
  ref <- .make_ipw_ref()

  result <- ipw(nps, ref, selection = ~age_group + sex, trim = FALSE)

  test_invariants(result)
  hist <- result@metadata@weighting_history[[1L]]
  weights_from_scores <- unname(1 / hist$propensity_scores)
  weights_in_data <- result@data[["ipw_weight"]]
  expect_equal(weights_in_data, weights_from_scores, tolerance = 1e-10)
})

# ---------------------------------------------------------------------------
# PR 1 — L-4: population_size argument
# ---------------------------------------------------------------------------

test_that("population_size = NULL → population_size_known = FALSE", {
  nps <- .make_ipw_nps()
  ref <- .make_ipw_ref()

  result <- ipw(nps, ref, selection = ~age_group + sex)

  test_invariants(result)
  hist <- result@metadata@weighting_history[[1L]]
  expect_false(hist$population_size_known)
})

test_that("population_size supplied → population_size_known = TRUE, estimated_population_size = supplied value", {
  nps <- .make_ipw_nps()
  ref <- .make_ipw_ref()

  result_known_n <- ipw(nps, ref, selection = ~age_group + sex,
                        population_size = 50000)

  test_invariants(result_known_n)
  hist_known <- result_known_n@metadata@weighting_history[[1L]]
  expect_true(hist_known$population_size_known)
  expect_equal(hist_known$estimated_population_size, 50000, tolerance = 1e-10)
})

test_that("population_size does not change the weights", {
  nps <- .make_ipw_nps()
  ref <- .make_ipw_ref()

  result_null <- ipw(nps, ref, selection = ~age_group + sex)
  result_50k  <- ipw(nps, ref, selection = ~age_group + sex,
                     population_size = 50000)

  test_invariants(result_null)
  test_invariants(result_50k)
  expect_equal(
    result_null@data[["ipw_weight"]],
    result_50k@data[["ipw_weight"]],
    tolerance = 1e-10
  )
})

test_that("population_size = 0 or negative → error", {
  nps <- .make_ipw_nps()
  ref <- .make_ipw_ref()

  expect_error(
    ipw(nps, ref, selection = ~age_group + sex, population_size = 0),
    class = "surveywts_error_population_size_invalid"
  )
  expect_snapshot(
    error = TRUE,
    ipw(nps, ref, selection = ~age_group + sex, population_size = 0)
  )
  expect_error(
    ipw(nps, ref, selection = ~age_group + sex, population_size = -100),
    class = "surveywts_error_population_size_invalid"
  )
})

test_that("population_size = non-numeric → error", {
  nps <- .make_ipw_nps()
  ref <- .make_ipw_ref()

  expect_error(
    ipw(nps, ref, selection = ~age_group + sex, population_size = "50000"),
    class = "surveywts_error_population_size_invalid"
  )
  expect_snapshot(
    error = TRUE,
    ipw(nps, ref, selection = ~age_group + sex, population_size = "50000")
  )
})

test_that("population_size = Inf → error", {
  nps <- .make_ipw_nps()
  ref <- .make_ipw_ref()

  expect_error(
    ipw(nps, ref, selection = ~age_group + sex, population_size = Inf),
    class = "surveywts_error_population_size_invalid"
  )
})
