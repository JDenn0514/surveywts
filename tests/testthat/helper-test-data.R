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

# NPS reference design for ipw() tests.
# Returns a survey_taylor from a probability sample with the same covariate
# columns as make_surveywts_data(). The reference represents the population
# against which NPS participation propensity is estimated.
make_nps_reference <- function(n = 1000L, seed = 42L) {
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
  ref_df <- data.frame(
    age_group  = age_group,
    sex        = sex,
    education  = education,
    region     = region,
    base_weight = base_weight,
    stringsAsFactors = FALSE
  )
  surveycore::survey_taylor(
    data      = ref_df,
    variables = list(weights = "base_weight")
  )
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

# NPS bootstrap helpers -------------------------------------------------------

make_nps_ref <- function(seed = 42) {
  ref_df <- make_surveywts_data(n = 1000, seed = seed)
  surveycore::as_survey(ref_df, weights = base_weight)
}

# Level A: margins are fixed population targets, NOT derived from ref design.
# targets_from_reference = FALSE in the rake history entry.
make_nps_level_a <- function(seed = 1, n = 500) {
  nps_df <- make_surveywts_data(n = n, seed = seed)
  ref    <- make_nps_ref(seed = seed + 100)
  ipw_result <- surveywts::ipw(
    data      = nps_df,
    reference = ref,
    selection = ~age_group + sex
  )
  surveywts::calibrate_rake(
    ipw_result,
    targets = list(
      age_group = c("18-34" = 0.35, "35-54" = 0.40, "55+" = 0.25),
      sex       = c("M" = 0.49, "F" = 0.51)
    ),
    type = "prop"
    # No reference_design= argument → targets_from_reference = FALSE
  )
}

# Level B: calibration margins derived from the reference design.
# targets_from_reference = TRUE in the rake history entry.
make_nps_level_b <- function(seed = 2, n = 500) {
  ref <- make_nps_ref(seed = seed + 100)
  nps_df <- make_surveywts_data(n = n, seed = seed)
  ipw_result <- surveywts::ipw(
    data      = nps_df,
    reference = ref,
    selection = ~age_group + sex
  )
  surveywts::calibrate_rake(
    ipw_result,
    targets = list(
      age_group = c("18-34" = 0.35, "35-54" = 0.40, "55+" = 0.25),
      sex       = c("M" = 0.49, "F" = 0.51)
    ),
    type             = "prop",
    reference_design = ref  # -> targets_from_reference = TRUE
  )
}

# DAGJK datasets for create_group_jackknife_weights() tests.
# Returns a named list:
#   A: survey_nonprob after ipw() only (reference stored in history)
#   B: survey_nonprob after ipw() + rake() with literal targets
#   C: survey_nonprob after ipw() — same as A (reference in ipw history)
#   ref: the survey_taylor reference used for all datasets
#
# NPS: 80 units. Reference: 500 units (large enough to avoid degenerate scores).
# Two categorical covariates: age_group (3 levels), sex (2 levels).
# Using well-matched distributions to ensure ipw() converges cleanly.
make_dagjk_datasets <- function() {
  set.seed(101L)

  # Reference probability sample (500 units — must be >> NPS for propensity stability)
  ref_df <- data.frame(
    age_group   = sample(
      c("18-34", "35-54", "55+"),
      size = 500L,
      replace = TRUE,
      prob = c(0.30, 0.40, 0.30)
    ),
    sex         = sample(
      c("M", "F"),
      size = 500L,
      replace = TRUE,
      prob = c(0.48, 0.52)
    ),
    ref_weight  = rep(1, 500L),
    stringsAsFactors = FALSE
  )
  ref <- surveycore::survey_taylor(
    data      = ref_df,
    variables = list(weights = "ref_weight")
  )

  # NPS (80 units, slightly different distribution to induce propensity variation)
  set.seed(202L)
  nps_df <- data.frame(
    age_group = sample(
      c("18-34", "35-54", "55+"),
      size = 80L,
      replace = TRUE,
      prob = c(0.40, 0.35, 0.25)
    ),
    sex = sample(
      c("M", "F"),
      size = 80L,
      replace = TRUE,
      prob = c(0.55, 0.45)
    ),
    stringsAsFactors = FALSE
  )

  # Dataset A: ipw() only, no post-ipw calibration
  # reference is stored in ipw history entry
  A <- suppressWarnings(surveywts::ipw(
    data             = nps_df,
    reference        = ref,
    selection        = ~age_group + sex,
    adjust_reference = FALSE
  ))

  # Dataset B: ipw() + calibrate_rake() with literal fixed targets
  ipw_b <- suppressWarnings(surveywts::ipw(
    data             = nps_df,
    reference        = ref,
    selection        = ~age_group + sex,
    adjust_reference = FALSE
  ))
  B <- surveywts::calibrate_rake(
    ipw_b,
    targets = list(
      age_group = c("18-34" = 0.30, "35-54" = 0.40, "55+" = 0.30),
      sex       = c("M" = 0.48, "F" = 0.52)
    ),
    type = "prop"
    # No reference_design= → targets_from_reference = FALSE
  )

  # Dataset C: same as A (reference in ipw history entry)
  C <- suppressWarnings(surveywts::ipw(
    data             = nps_df,
    reference        = ref,
    selection        = ~age_group + sex,
    adjust_reference = FALSE
  ))

  # Dataset D: ipw() + calibrate_rake() with reference_design= (targets_from_reference = TRUE)
  # Exercises use_level_b = TRUE path (raking branch) in .dagjk_single_replicate()
  ipw_d <- suppressWarnings(surveywts::ipw(
    data             = nps_df,
    reference        = ref,
    selection        = ~age_group + sex,
    adjust_reference = FALSE
  ))
  D <- surveywts::calibrate_rake(
    ipw_d,
    targets = list(
      age_group = c("18-34" = 0.30, "35-54" = 0.40, "55+" = 0.30),
      sex       = c("M" = 0.48, "F" = 0.52)
    ),
    type             = "prop",
    reference_design = ref  # -> targets_from_reference = TRUE
  )

  # Dataset E: ipw() + calibrate_greg() with reference_design= (targets_from_reference = TRUE)
  # Exercises use_level_b = TRUE calibration (not raking) branch
  ipw_e <- suppressWarnings(surveywts::ipw(
    data             = nps_df,
    reference        = ref,
    selection        = ~age_group + sex,
    adjust_reference = FALSE
  ))
  targets_e <- list(
    age_group = c("18-34" = 0.30, "35-54" = 0.40, "55+" = 0.30),
    sex       = c("M" = 0.48, "F" = 0.52)
  )
  E <- tryCatch(
    surveywts::calibrate_greg(
      data             = ipw_e,
      targets          = targets_e,
      type             = "prop",
      reference_design = ref   # -> targets_from_reference = TRUE
    ),
    error = function(e) NULL
  )

  # Dataset F: ipw() + calibrate_greg() WITHOUT reference_design (targets_from_reference = FALSE)
  # Exercises use_level_b = FALSE calibration branch in .dagjk_single_replicate()
  ipw_f <- suppressWarnings(surveywts::ipw(
    data             = nps_df,
    reference        = ref,
    selection        = ~age_group + sex,
    adjust_reference = FALSE
  ))
  targets_f <- list(
    age_group = c("18-34" = 0.30, "35-54" = 0.40, "55+" = 0.30),
    sex       = c("M" = 0.48, "F" = 0.52)
  )
  F_data <- tryCatch(
    surveywts::calibrate_greg(
      data    = ipw_f,
      targets = targets_f,
      type    = "prop"
      # no reference_design -> targets_from_reference = FALSE
    ),
    error = function(e) NULL
  )

  list(A = A, B = B, C = C, D = D, E = E, F = F_data, ref = ref)
}

# Pin all weighting history timestamps to a fixed date for stable snapshots.
# Works for survey_nonprob and survey_replicate (both have @metadata@weighting_history).
# Usage: result <- .pin_ts(result)
.pin_ts <- function(obj, ts = as.POSIXct("2025-01-15 10:00:00", tz = "UTC")) {
  if (S7::S7_inherits(obj, surveycore::survey_nonprob) ||
        S7::S7_inherits(obj, surveycore::survey_replicate)) {
    meta <- obj@metadata
    for (i in seq_along(meta@weighting_history)) {
      meta@weighting_history[[i]]$timestamp <- ts
    }
    obj@metadata <- meta
  }
  obj
}
