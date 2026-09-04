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
      education == "Graduate",
      0.90,
      ifelse(
        education == "College",
        0.85,
        ifelse(education == "HS", 0.75, 0.65)
      )
    )
    df$responded <- as.integer(stats::rbinom(n, size = 1L, prob = resp_prob))
  }

  df
}

test_invariants <- function(obj) {
  if (S7::S7_inherits(obj, surveycore::survey_nonprob)) {
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
    testthat::expect_true(S7::S7_inherits(obj, surveycore::survey_replicate))
    wt_col <- obj@variables$weights
    testthat::expect_true(is.character(wt_col) && length(wt_col) == 1)
    testthat::expect_true(wt_col %in% names(obj@data))
    testthat::expect_true(is.numeric(obj@data[[wt_col]]))
    testthat::expect_true(all(obj@data[[wt_col]] > 0))
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
    age_group = age_group,
    sex = sex,
    education = education,
    region = region,
    base_weight = base_weight,
    stringsAsFactors = FALSE
  )
  surveycore::survey_taylor(
    data = ref_df,
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
    id = seq_len(n),
    psu_id = rep(seq_len(total_psus), length.out = n),
    stratum = rep(
      rep(seq_len(n_strata), each = psus_per_stratum),
      length.out = n
    ),
    y = rnorm(n),
    base_weight = exp(rnorm(n, 0, 0.4))
  )
  surveycore::as_survey(
    df,
    ids = psu_id,
    strata = stratum,
    weights = base_weight
  )
}

# Simple bootstrap replicate design for sample-calibration tests.
# Returns a survey_replicate with R bootstrap replicates (default 50).
make_replicate_design <- function(n = 200L, R = 50L, seed = 42L) {
  df <- make_surveywts_data(n = n, seed = seed)
  taylor <- surveycore::survey_taylor(
    data = df,
    variables = list(weights = "base_weight")
  )
  create_bootstrap_weights(taylor, replicates = R)
}

# Paired-PSU design for BRR tests.
# Returns a survey_taylor with exactly 2 PSUs per stratum.
make_paired_design <- function(n_strata = 3L, obs_per_psu = 10L, seed = 42L) {
  set.seed(seed)
  n_psus <- n_strata * 2L
  n <- n_psus * obs_per_psu
  df <- data.frame(
    id = seq_len(n),
    psu_id = rep(seq_len(n_psus), each = obs_per_psu),
    stratum = rep(seq_len(n_strata), each = 2L * obs_per_psu),
    y = rnorm(n),
    base_weight = exp(rnorm(n, 0, 0.4))
  )
  surveycore::as_survey(
    df,
    ids = psu_id,
    strata = stratum,
    weights = base_weight
  )
}

# NPS bootstrap helpers -------------------------------------------------------

make_nps_ref <- function(seed = 42) {
  ref_df <- make_surveywts_data(n = 1000, seed = seed)
  surveycore::as_survey(ref_df, weights = base_weight)
}

# Level A: margins are fixed population targets, NOT derived from ref design.
make_nps_level_a <- function(seed = 1, n = 500) {
  nps_df <- make_surveywts_data(n = n, seed = seed)
  ref <- make_nps_ref(seed = seed + 100)
  ipw_result <- surveywts::ipw(
    data = nps_df,
    reference = ref,
    selection = ~ age_group + sex
  )
  surveywts::calibrate_rake(
    ipw_result,
    targets = list(
      age_group = c("18-34" = 0.35, "35-54" = 0.40, "55+" = 0.25),
      sex = c("M" = 0.49, "F" = 0.51)
    ),
    type = "prop"
  )
}

# Level B: calibration margins derived from the reference design.
make_nps_level_b <- function(seed = 2, n = 500) {
  ref <- make_nps_ref(seed = seed + 100)
  nps_df <- make_surveywts_data(n = n, seed = seed)
  ipw_result <- surveywts::ipw(
    data = nps_df,
    reference = ref,
    selection = ~ age_group + sex
  )
  surveywts::calibrate_rake(
    ipw_result,
    targets = list(
      age_group = c("18-34" = 0.35, "35-54" = 0.40, "55+" = 0.25),
      sex = c("M" = 0.49, "F" = 0.51)
    ),
    type = "prop",
    reference_design = ref
  )
}

# DAGJK datasets for create_jackknife_weights(type = "grouped") tests.
make_dagjk_datasets <- function() {
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
    sex = sample(
      c("M", "F"),
      size = 80L,
      replace = TRUE,
      prob = c(0.55, 0.45)
    ),
    stringsAsFactors = FALSE
  )

  A <- suppressWarnings(surveywts::ipw(
    data = nps_df,
    reference = ref,
    selection = ~ age_group + sex,
    estimating_eq = "mle",
    adjust_reference = FALSE
  ))

  ipw_b <- suppressWarnings(surveywts::ipw(
    data = nps_df,
    reference = ref,
    selection = ~ age_group + sex,
    estimating_eq = "mle",
    adjust_reference = FALSE
  ))
  B <- surveywts::calibrate_rake(
    ipw_b,
    targets = list(
      age_group = c("18-34" = 0.30, "35-54" = 0.40, "55+" = 0.30),
      sex = c("M" = 0.48, "F" = 0.52)
    ),
    type = "prop"
  )

  C <- suppressWarnings(surveywts::ipw(
    data = nps_df,
    reference = ref,
    selection = ~ age_group + sex,
    estimating_eq = "mle",
    adjust_reference = FALSE
  ))

  ipw_d <- suppressWarnings(surveywts::ipw(
    data = nps_df,
    reference = ref,
    selection = ~ age_group + sex,
    estimating_eq = "mle",
    adjust_reference = FALSE
  ))
  D <- surveywts::calibrate_rake(
    ipw_d,
    targets = list(
      age_group = c("18-34" = 0.30, "35-54" = 0.40, "55+" = 0.30),
      sex = c("M" = 0.48, "F" = 0.52)
    ),
    type = "prop",
    reference_design = ref
  )

  ipw_e <- suppressWarnings(surveywts::ipw(
    data = nps_df,
    reference = ref,
    selection = ~ age_group + sex,
    estimating_eq = "mle",
    adjust_reference = FALSE
  ))
  targets_e <- list(
    age_group = c("18-34" = 0.30, "35-54" = 0.40, "55+" = 0.30),
    sex = c("M" = 0.48, "F" = 0.52)
  )
  E <- tryCatch(
    surveywts::calibrate_linear(
      data = ipw_e,
      targets = targets_e,
      type = "prop",
      reference_design = ref
    ),
    error = function(e) NULL
  )

  ipw_f <- suppressWarnings(surveywts::ipw(
    data = nps_df,
    reference = ref,
    selection = ~ age_group + sex,
    estimating_eq = "mle",
    adjust_reference = FALSE
  ))
  targets_f <- list(
    age_group = c("18-34" = 0.30, "35-54" = 0.40, "55+" = 0.30),
    sex = c("M" = 0.48, "F" = 0.52)
  )
  F_data <- tryCatch(
    surveywts::calibrate_linear(
      data = ipw_f,
      targets = targets_f,
      type = "prop"
    ),
    error = function(e) NULL
  )

  list(A = A, B = B, C = C, D = D, E = E, F = F_data, ref = ref)
}

# ============================================================================
# Replicate design helpers for calibrate-surveycore PR 2 tests
# ============================================================================

# .make_replicate_design() — wraps df in survey_taylor then bootstrap replicates.
.make_replicate_design <- function(df, weight_col = "base_weight", seed = 42) {
  set.seed(seed)
  taylor <- surveycore::survey_taylor(
    data = df,
    variables = list(weights = weight_col)
  )
  create_bootstrap_weights(taylor, replicates = 10L)
}

# .make_brr_design() — bootstrap replicates with first column negated.
.make_brr_design <- function(df, weight_col = "base_weight") {
  base_rep <- .make_replicate_design(df, weight_col = weight_col)
  repwt_cols <- base_rep@variables$repweights
  updated_data <- base_rep@data
  updated_data[[repwt_cols[[1L]]]] <- updated_data[[repwt_cols[[1L]]]] * (-0.1)
  base_rep@data <- updated_data
  base_rep
}

# .make_empty_cell_replicate_design() — survey_replicate where one replicate
# column has zero weight for all units in the first level of calibration_var.
.make_empty_cell_replicate_design <- function(
  df,
  calibration_var,
  weight_col = "base_weight"
) {
  base_rep <- .make_replicate_design(df, weight_col = weight_col)
  repwt_cols <- base_rep@variables$repweights
  first_level <- unique(df[[calibration_var]])[[1L]]
  idx <- which(base_rep@data[[calibration_var]] == first_level)
  updated_data <- base_rep@data
  last_col <- repwt_cols[[length(repwt_cols)]]
  updated_data[[last_col]][idx] <- 0
  base_rep@data <- updated_data
  base_rep
}

# ============================================================================
# Shared fixtures for calibrate-unit-scale tests
# ============================================================================

df_500 <- make_surveywts_data(n = 500, seed = 42)
df_200 <- make_surveywts_data(n = 200, seed = 7)
q_unequal <- {
  set.seed(99)
  exp(rnorm(500, 0, 0.3))
}
q_all_twos <- rep(2, 500)
q_all_ones <- rep(1, 500)

taylor_500 <- surveycore::survey_taylor(
  data = df_500,
  variables = list(
    ids = NULL,
    strata = NULL,
    fpc = NULL,
    weights = "base_weight",
    nest = FALSE
  )
)
taylor_200 <- surveycore::survey_taylor(
  data = df_200,
  variables = list(
    ids = NULL,
    strata = NULL,
    fpc = NULL,
    weights = "base_weight",
    nest = FALSE
  )
)

# Pin all weighting history timestamps to a fixed date for stable snapshots.
.pin_ts <- function(obj, ts = as.POSIXct("2025-01-15 10:00:00", tz = "UTC")) {
  if (
    S7::S7_inherits(obj, surveycore::survey_nonprob) ||
      S7::S7_inherits(obj, surveycore::survey_replicate)
  ) {
    meta <- obj@metadata
    for (i in seq_along(meta@weighting_history)) {
      meta@weighting_history[[i]]$timestamp <- ts
    }
    obj@metadata <- meta
  }
  obj
}

# survey_nonprob with bootstrap replicate weights — for calibrate-nonprob tests.
# Returns a survey_nonprob that has been through ipw() and then
# create_bootstrap_weights(), so @variables$repweights is populated.
# R controls the number of bootstrap replicates (default 30L).
make_nonprob_replicate_design <- function(n = 200L, R = 30L, seed = 1L) {
  set.seed(seed)
  nps_df <- make_surveywts_data(n = n, seed = seed)
  ref_df <- make_surveywts_data(n = n * 5L, seed = seed + 100L)
  ref <- surveycore::as_survey(ref_df, weights = base_weight)
  nps <- ipw(data = nps_df, reference = ref, selection = ~ sex + age_group)
  result <- create_bootstrap_weights(
    nps,
    replicates = R,
    type = "quasi-randomization",
    seed = seed
  )
  # The quasi-randomization bootstrap path does not populate @variables$scale.
  # Set it to 1/R (the bootstrap scale constant) so Opsomer-based callers
  # that require @variables$scale (e.g. calibrate_to_survey()) receive a
  # valid design. This mirrors the value svrep sets for probability-sample
  # bootstrap designs.
  result@variables$scale <- 1 / R
  result
}

# survey_nonprob WITHOUT replicate weights — for error path tests.
# Returns a survey_nonprob from ipw() only; @variables$repweights is NULL.
make_nonprob_no_repweights <- function(n = 200L, seed = 1L) {
  set.seed(seed)
  nps_df <- make_surveywts_data(n = n, seed = seed)
  ref_df <- make_surveywts_data(n = n * 5L, seed = seed + 100L)
  ref <- surveycore::as_survey(ref_df, weights = base_weight)
  ipw(data = nps_df, reference = ref, selection = ~ sex + age_group)
}

# ---- Survey object helpers (replace _svy lazy-loaded package data) ----------

make_gss_taylor <- function() {
  data(gss_2024, package = "surveywts", envir = environment())
  surveycore::as_survey(
    gss_2024,
    weights = wtssps,
    strata = vstrat,
    ids = vpsu,
    nest = TRUE
  )
}

make_cps_taylor <- function() {
  data(cps_2023, package = "surveywts", envir = environment())
  surveycore::as_survey(cps_2023, weights = wtfinl)
}

make_ns_nonprob <- function() {
  data(ns_wave1, package = "surveywts", envir = environment())
  surveycore::survey_nonprob(
    ns_wave1,
    variables = list(weights = "weight")
  )
}

make_npors_taylor <- function() {
  data(npors_2025_clean, package = "surveywts", envir = environment())
  surveycore::as_survey(
    npors_2025_clean,
    weights = weight,
    strata = stratum
  )
}

# Designs that fire the calibration replay message (issue #111).
#
# control = list(improvement = 5) makes every replicate pass the raking
# improvement threshold, so every replicate emits
# surveywts_message_already_calibrated. That saturates the count and keeps the
# assertions clear of borderline chi-square comparisons.
#
# Returns a list:
#   ipw_cal  : ipw() then calibrate_rake(); fires on the IPW replay paths
#   cal_only : calibrate_rake() only; fires on the calibration-only paths
#   quiet    : same data, default threshold; fires on no bootstrap replicate
#   ref      : the reference survey_taylor
make_replay_message_datasets <- function() {
  d <- make_dagjk_datasets()

  targets <- list(
    age_group = c("18-34" = 0.30, "35-54" = 0.40, "55+" = 0.30),
    sex = c("M" = 0.48, "F" = 0.52)
  )

  ipw_fit <- suppressWarnings(surveywts::ipw(
    data = d$A@data[, c("age_group", "sex")],
    reference = d$ref,
    selection = ~ age_group + sex,
    estimating_eq = "mle",
    adjust_reference = FALSE
  ))
  ipw_cal <- suppressMessages(suppressWarnings(surveywts::calibrate_rake(
    ipw_fit,
    targets = targets,
    type = "prop",
    control = list(improvement = 5)
  )))

  # A design sitting exactly on its margins, calibration only.
  age <- rep(c("18-34", "35-54", "55+"), times = c(3L, 4L, 3L) * 100L)
  set.seed(7L)
  sex <- sample(rep(c("M", "F"), times = c(480L, 520L)))
  df <- data.frame(
    age_group = age,
    sex = sex,
    w = rep(1, 1000L),
    stringsAsFactors = FALSE
  )
  svy <- surveycore::as_survey_nonprob(df, weights = w)

  cal_only <- suppressMessages(suppressWarnings(surveywts::calibrate_rake(
    svy,
    targets = targets,
    type = "prop",
    control = list(improvement = 5)
  )))
  quiet <- suppressMessages(suppressWarnings(surveywts::calibrate_rake(
    svy,
    targets = targets,
    type = "prop"
  )))

  list(ipw_cal = ipw_cal, cal_only = cal_only, quiet = quiet, ref = d$ref)
}
