# tests/testthat/helper-test-data.R
#
# Shared test infrastructure loaded automatically by testthat.
# Provides:
#   - make_surveywts_data()   — synthetic data generator
#   - test_invariants()           — invariant checker

make_surveywts_data <- function(
  n = 500L,
  seed = 42L,
  include_nonrespondents = FALSE
) {
  set.seed(seed)

  age_group <- sample(
    c("18-34", "35-54", "55+"),
    size = n,
    replace = TRUE,
    prob = c(0.30, 0.40, 0.30)
  )
  sex <- sample(
    c("M", "F"),
    size = n,
    replace = TRUE,
    prob = c(0.48, 0.52)
  )
  education <- sample(
    c("<HS", "HS", "College", "Graduate"),
    size = n,
    replace = TRUE,
    prob = c(0.10, 0.30, 0.40, 0.20)
  )
  region <- sample(
    c("Northeast", "South", "Midwest", "West"),
    size = n,
    replace = TRUE,
    prob = c(0.20, 0.35, 0.25, 0.20)
  )
  base_weight <- exp(rnorm(n, mean = 0, sd = 0.4))

  df <- data.frame(
    id = seq_len(n),
    age_group = age_group,
    sex = sex,
    education = education,
    region = region,
    base_weight = base_weight,
    stringsAsFactors = FALSE
  )

  if (include_nonrespondents) {
    # Response probability varies by education — graduate / college respond more
    resp_prob <- ifelse(
      education == "Graduate", 0.90,
      ifelse(education == "College", 0.85,
        ifelse(education == "HS", 0.75, 0.65)
      )
    )
    df$responded <- as.integer(stats::rbinom(n, size = 1L, prob = resp_prob))
  }

  df
}

test_invariants <- function(obj) {
  if (inherits(obj, "weighted_df")) {
    wt_col <- attr(obj, "weight_col")
    testthat::expect_true(is.character(wt_col) && length(wt_col) == 1)
    testthat::expect_true(wt_col %in% names(obj))
    testthat::expect_true(is.numeric(obj[[wt_col]]))
    testthat::expect_true(is.list(attr(obj, "weighting_history")))
  }
  if (exists("survey_nonprob") &&
        S7::S7_inherits(obj, survey_nonprob)) {
    testthat::expect_true(is.character(obj@variables$weights))
    testthat::expect_true(obj@variables$weights %in% names(obj@data))
    testthat::expect_true(is.numeric(obj@data[[obj@variables$weights]]))
    w <- obj@data[[obj@variables$weights]]
    testthat::expect_true(all(w >= 0) && any(w > 0))
  }
  if (S7::S7_inherits(obj, surveycore::survey_taylor)) {
    testthat::expect_true(is.character(obj@variables$weights))
    testthat::expect_true(obj@variables$weights %in% names(obj@data))
    testthat::expect_true(is.numeric(obj@data[[obj@variables$weights]]))
    w <- obj@data[[obj@variables$weights]]
    testthat::expect_true(all(w >= 0) && any(w > 0))
  }
  if (S7::S7_inherits(obj, surveycore::survey_replicate)) {
    testthat::expect_true(is.character(obj@variables$weights))
    testthat::expect_true(is.character(obj@variables$repweights))
    testthat::expect_true(length(obj@variables$repweights) >= 1L)
    testthat::expect_true(all(obj@variables$repweights %in% names(obj@data)))
  }
}

# Clustered, stratified design for general replicate weight testing.
# Returns a survey_taylor with PSU IDs, strata, and base weights.
make_taylor_design <- function(
  n = 500L,
  n_strata = 4L,
  psus_per_stratum = 5L,
  seed = 42L
) {
  set.seed(seed)
  total_psus <- n_strata * psus_per_stratum
  df <- data.frame(
    id          = seq_len(n),
    psu_id      = rep(seq_len(total_psus), length.out = n),
    stratum     = rep(rep(seq_len(n_strata), each = psus_per_stratum), length.out = n),
    y           = rnorm(n),
    base_weight = exp(rnorm(n, 0, 0.4))
  )
  surveycore::as_survey(df, ids = psu_id, strata = stratum, weights = base_weight)
}

# Replicate design for nonresponse phase tests.
# Returns a survey_replicate built from make_surveywts_data().
make_replicate_design <- function(n_replicates = 50L, seed = 42L) {
  df <- make_surveywts_data(n = 200L, seed = seed)
  taylor <- surveycore::survey_taylor(
    data = df,
    variables = list(weights = "base_weight")
  )
  create_bootstrap_weights(taylor, replicates = n_replicates)
}

# Paired-PSU design for BRR tests.
# Returns a survey_taylor with exactly 2 PSUs per stratum.
make_paired_design <- function(n_strata = 3L, obs_per_psu = 10L, seed = 42L) {
  set.seed(seed)
  n_psus <- n_strata * 2L
  n      <- n_psus * obs_per_psu
  df <- data.frame(
    id          = seq_len(n),
    psu_id      = rep(seq_len(n_psus), each = obs_per_psu),
    stratum     = rep(seq_len(n_strata), each = 2L * obs_per_psu),
    y           = rnorm(n),
    base_weight = exp(rnorm(n, 0, 0.4))
  )
  surveycore::as_survey(df, ids = psu_id, strata = stratum, weights = base_weight)
}
