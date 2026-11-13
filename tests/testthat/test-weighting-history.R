# tests/testthat/test-weighting-history.R
#
# weighting_history(), and the check that surveycore's print() runs for
# survey_replicate and survey_nonprob designs.

# Builds a stratified, clustered survey_taylor over make_surveywts_data(), so
# the calibration targets (age_group, sex) exist in the data.
.make_history_taylor <- function(n = 300L, seed = 1L) {
  df <- make_surveywts_data(n = n, seed = seed)
  df$psu <- rep(seq_len(30L), length.out = n)
  df$str <- rep(seq_len(3L), each = n / 3L)
  surveycore::as_survey(
    df,
    ids = psu,
    strata = str,
    weights = base_weight,
    nest = TRUE
  )
}

.history_targets <- list(
  age_group = c("18-34" = 0.30, "35-54" = 0.40, "55+" = 0.30),
  sex = c("M" = 0.48, "F" = 0.52)
)

# Sets the weighting history of any survey_base design.
.set_history <- function(obj, history) {
  meta <- obj@metadata
  meta@weighting_history <- history
  obj@metadata <- meta
  obj
}

# ---- 1. Happy path -----------------------------------------------------------

test_that("weighting_history() returns one row per step, in order", {
  skip_if_not_installed("svrep")
  td <- .make_history_taylor()
  raked <- calibrate_rake(td, targets = .history_targets)
  result <- create_bootstrap_weights(raked, replicates = 10L, seed = 1L)
  test_invariants(result)

  wh <- weighting_history(result)

  expect_s3_class(wh, "tbl_df")
  expect_identical(names(wh), c("step", "timestamp", "operation", "description"))
  expect_identical(nrow(wh), 2L)
  expect_identical(wh$step, c(1L, 2L))
  expect_identical(wh$operation, c("calibrate_rake", "replicate_creation"))
  expect_s3_class(wh$timestamp, "POSIXct")
  expect_false(anyNA(wh$timestamp))
  expect_identical(wh$description[[1L]], "raking (targets: age_group, sex)")
})

test_that("weighting_history() returns its result visibly", {
  td <- .make_history_taylor()
  test_invariants(td)
  expect_visible(weighting_history(td))
})

test_that("weighting_history() snapshot of a two-step history", {
  skip_if_not_installed("svrep")
  td <- make_taylor_design(n = 100L, seed = 42L)
  rep <- create_bootstrap_weights(td, replicates = 20L, seed = 1L)
  test_invariants(rep)
  # A second entry from another package: an operation with no description
  # case, so the description is the operation name.
  synthetic_entry <- list(
    step = 2L,
    operation = "calibration",
    timestamp = as.POSIXct("2026-01-15 10:00:00", tz = "UTC"),
    method = "linear",
    parameters = list(variables = c("age_group", "sex"))
  )
  rep <- .pin_ts(rep)
  rep <- .set_history(
    rep,
    c(rep@metadata@weighting_history, list(synthetic_entry))
  )
  # A wide console, so the long replicate_creation description is not cut.
  expect_snapshot(
    withr::with_options(list(width = 200), print(weighting_history(rep)))
  )
})

# ---- 2. One description per operation family ---------------------------------

test_that("replicate_creation descriptions name the method, type and replicates", {
  skip_if_not_installed("svrep")
  skip_if_not_installed("survey")
  td <- make_taylor_design(n = 100L, seed = 42L)

  boot <- create_bootstrap_weights(td, replicates = 50L, seed = 1L)
  test_invariants(boot)
  expect_identical(
    weighting_history(boot)$description,
    paste0(
      "replicate_creation (method = \"bootstrap\", ",
      "type = \"Rao-Wu-Yue-Beaumont\", replicates = 50)"
    )
  )

  jkn <- create_jackknife_weights(td, type = "jkn")
  test_invariants(jkn)
  expect_identical(
    weighting_history(jkn)$description,
    "replicate_creation (method = \"jackknife\", type = \"jkn\")"
  )

  brr <- create_brr_weights(make_paired_design(seed = 42L))
  test_invariants(brr)
  expect_identical(
    weighting_history(brr)$description,
    "replicate_creation (method = \"brr\")"
  )
})

test_that("calibrate_linear() and calibrate_logit() descriptions list the variables", {
  df <- make_surveywts_data(n = 100, seed = 4)
  nps <- surveycore::survey_nonprob(
    data = df,
    variables = list(weights = "base_weight")
  )
  lin <- suppressWarnings(calibrate_linear(
    nps,
    targets = .history_targets,
    type = "prop"
  ))
  test_invariants(lin)
  expect_identical(
    weighting_history(lin)$description,
    "calibrate_linear (variables: age_group, sex)"
  )

  logit <- suppressWarnings(calibrate_logit(
    nps,
    targets = .history_targets,
    type = "prop"
  ))
  test_invariants(logit)
  expect_identical(
    weighting_history(logit)$description,
    "calibrate_logit (variables: age_group, sex)"
  )
})

test_that("poststratify() description lists the strata", {
  df <- make_surveywts_data(n = 200, seed = 6)
  nps <- surveycore::survey_nonprob(
    data = df,
    variables = list(weights = "base_weight")
  )
  targets <- data.frame(
    age_group = c("18-34", "35-54", "55+", "18-34", "35-54", "55+"),
    sex = c("M", "M", "M", "F", "F", "F"),
    target = c(0.144, 0.192, 0.144, 0.156, 0.208, 0.156)
  )
  ps <- suppressWarnings(poststratify(nps, targets = targets, type = "prop"))
  test_invariants(ps)
  expect_identical(
    weighting_history(ps)$description,
    "poststratify (strata: age_group, sex)"
  )
})

test_that("weighting-class nonresponse description names the by variables", {
  df <- make_surveywts_data(n = 200, seed = 7, include_nonrespondents = TRUE)
  nps <- surveycore::survey_nonprob(
    data = df,
    variables = list(weights = "base_weight")
  )

  with_by <- suppressWarnings(adjust_nonresponse(
    nps,
    response_status = "responded",
    method = "weighting-class",
    by = sex
  ))
  test_invariants(with_by)
  expect_identical(
    weighting_history(with_by)$description,
    "weighting-class nonresponse (by: sex)"
  )

  no_by <- suppressWarnings(adjust_nonresponse(
    nps,
    response_status = "responded",
    method = "weighting-class"
  ))
  test_invariants(no_by)
  expect_identical(
    weighting_history(no_by)$description,
    "weighting-class nonresponse"
  )
})

test_that("ipw() description names the formula, method and sizes", {
  lev_a <- suppressWarnings(make_nps_level_a(seed = 1))
  test_invariants(lev_a)
  wh <- weighting_history(lev_a)
  expect_identical(wh$operation[[1L]], "ipw")
  expect_match(
    wh$description[[1L]],
    "^ipw \\[~.+, logit, n_ref=[0-9]+, N_hat=[0-9]+\\]$"
  )
})

test_that("an operation with no description case is described by its name", {
  td <- .make_history_taylor()
  rescaled <- rescale_weights(td)
  test_invariants(rescaled)
  wh <- weighting_history(rescaled)
  expect_identical(wh$operation, "rescale_weights")
  expect_identical(wh$description, "rescale_weights")
})

# ---- 3. Empty history --------------------------------------------------------

test_that("an empty history gives a zero-row tibble with typed columns", {
  df <- make_surveywts_data(n = 50, seed = 1)
  nps <- surveycore::survey_nonprob(
    data = df,
    variables = list(weights = "base_weight")
  )
  test_invariants(nps)

  wh <- expect_silent(weighting_history(nps))

  expect_s3_class(wh, "tbl_df")
  expect_identical(nrow(wh), 0L)
  expect_identical(names(wh), c("step", "timestamp", "operation", "description"))
  expect_type(wh$step, "integer")
  expect_s3_class(wh$timestamp, "POSIXct")
  expect_type(wh$operation, "character")
  expect_type(wh$description, "character")
})

test_that("a replicate design with its history removed gives zero rows", {
  skip_if_not_installed("svrep")
  td <- make_taylor_design(n = 50L, seed = 42L)
  rep <- create_bootstrap_weights(td, replicates = 10L, seed = 1L)
  test_invariants(rep)
  rep <- .set_history(rep, list())
  expect_identical(nrow(weighting_history(rep)), 0L)
})

# ---- 4. Incomplete and unknown entries ---------------------------------------

test_that("an entry with no step, timestamp or operation uses the fallbacks", {
  td <- .make_history_taylor()
  test_invariants(td)
  td <- .set_history(td, list(list(parameters = list(variables = "sex"))))

  wh <- expect_silent(weighting_history(td))

  expect_identical(nrow(wh), 1L)
  expect_identical(wh$step, 1L)
  expect_true(is.na(wh$timestamp))
  expect_identical(wh$operation, NA_character_)
  expect_identical(wh$description, NA_character_)
})

test_that("a missing step reads as the row position", {
  td <- .make_history_taylor()
  test_invariants(td)
  ts <- as.POSIXct("2025-01-15 10:00:00", tz = "UTC")
  td <- .set_history(
    td,
    list(
      list(step = 1L, operation = "trim_weights", timestamp = ts),
      list(operation = "rescale_weights", timestamp = ts)
    )
  )
  wh <- weighting_history(td)
  expect_identical(wh$step, c(1L, 2L))
  expect_identical(wh$timestamp, rep(ts, 2L))
})

test_that("an entry whose description fails falls back to its operation", {
  td <- .make_history_taylor()
  test_invariants(td)
  # An ipw entry without estimated_population_size cannot be described.
  td <- .set_history(td, list(list(step = 1L, operation = "ipw")))
  wh <- expect_silent(weighting_history(td))
  expect_identical(wh$description, "ipw")
})

test_that("an entry that is not a list reads as an empty entry", {
  td <- .make_history_taylor()
  test_invariants(td)
  td <- .set_history(td, list("not an entry"))
  wh <- expect_silent(weighting_history(td))
  expect_identical(nrow(wh), 1L)
  expect_identical(wh$step, 1L)
  expect_identical(wh$operation, NA_character_)
})

# ---- 5. Error paths ----------------------------------------------------------

test_that("weighting_history() rejects a plain data.frame", {
  df <- make_surveywts_data(n = 20, seed = 1)
  expect_error(
    weighting_history(df),
    class = "surveywts_error_not_survey_base"
  )
  expect_snapshot(error = TRUE, weighting_history(df))
})

# ---- 6. surveycore's print() runs for surveycore classes ----------------------

test_that("print() on survey_replicate and survey_nonprob is surveycore's method", {
  expect_identical(
    environment(getS3method("print", "surveycore::survey_replicate")),
    asNamespace("surveycore")
  )
  expect_identical(
    environment(getS3method("print", "surveycore::survey_nonprob")),
    asNamespace("surveycore")
  )
})

test_that("print(design_info = TRUE) on a JKn design shows surveycore's FPC line", {
  skip_if_not_installed("survey")
  df <- make_surveywts_data(n = 300, seed = 1)
  df$psu <- rep(seq_len(30L), length.out = 300L)
  df$str <- rep(seq_len(3L), each = 100L)
  df$fpc <- 1000
  td <- surveycore::as_survey(
    df,
    ids = psu,
    strata = str,
    weights = base_weight,
    fpc = fpc,
    nest = TRUE
  )
  jk <- create_jackknife_weights(td, type = "jkn")
  test_invariants(jk)
  # Before surveywts records fpc_applied (issue #130) the line reads
  # "application not recorded"; after, "applied in replicate scales".
  # surveycore writes the design section through cli (as messages) and the
  # data preview to stdout; keep the cli lines and drop the preview.
  utils::capture.output(
    cli_lines <- cli::cli_fmt(print(jk, design_info = TRUE))
  )
  expect_true(any(grepl("FPC: fpc", cli_lines, fixed = TRUE)))
})
