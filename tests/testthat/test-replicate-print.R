# ---- Print snapshots (18a–18d) ----------------------------------------------

test_that("print(survey_replicate) bootstrap snapshot", {
  skip_if_not_installed("svrep")
  td     <- make_taylor_design(n = 100L, seed = 42L)
  result <- create_bootstrap_weights(td, replicates = 50L, seed = 1L)
  # Pin timestamp for a stable snapshot (Sys.time() varies by run date)
  meta <- result@metadata
  meta@weighting_history[[1]]$timestamp <- as.POSIXct("2025-01-15 10:00:00", tz = "UTC")
  result@metadata <- meta
  expect_snapshot(print(result))
})

test_that("print(survey_replicate) JKn stratified delete-1 snapshot", {
  skip_if_not_installed("survey")
  td     <- make_taylor_design(n = 100L, seed = 42L)
  result <- create_jackknife_weights(td, type = "jkn")
  # Pin timestamp for a stable snapshot (Sys.time() varies by run date)
  meta <- result@metadata
  meta@weighting_history[[1]]$timestamp <- as.POSIXct("2025-01-15 10:00:00", tz = "UTC")
  result@metadata <- meta
  expect_snapshot(print(result))
})

test_that("print(survey_replicate) BRR snapshot", {
  skip_if_not_installed("survey")
  pd     <- make_paired_design(seed = 42L)
  result <- create_brr_weights(pd)
  # Pin timestamp for a stable snapshot (Sys.time() varies by run date)
  meta <- result@metadata
  meta@weighting_history[[1]]$timestamp <- as.POSIXct("2025-01-15 10:00:00", tz = "UTC")
  result@metadata <- meta
  expect_snapshot(print(result))
})

test_that("print(survey_replicate) two-entry history snapshot", {
  skip_if_not_installed("svrep")
  td  <- make_taylor_design(n = 100L, seed = 42L)
  rep <- create_bootstrap_weights(td, replicates = 20L, seed = 1L)
  # Pin timestamp for a stable snapshot (Sys.time() varies by run date)
  meta <- rep@metadata
  meta@weighting_history[[1]]$timestamp <- as.POSIXct("2025-01-15 10:00:00", tz = "UTC")
  # Append a synthetic second entry to test multi-step display
  synthetic_entry <- list(
    step      = 2L,
    operation = "calibration",
    timestamp = as.POSIXct("2026-01-15 10:00:00", tz = "UTC"),
    method    = "linear",
    parameters = list(variables = c("age_group", "sex"))
  )
  meta@weighting_history <- c(meta@weighting_history, list(synthetic_entry))
  rep@metadata <- meta
  expect_snapshot(print(rep))
})

# ---- survey_nonprob print: empty history and structural variants -------------

.pin_history_ts <- function(obj, ts = as.POSIXct("2025-01-15 10:00:00", tz = "UTC")) {
  meta <- obj@metadata
  meta@weighting_history <- lapply(meta@weighting_history, function(e) {
    e$timestamp <- ts
    e
  })
  obj@metadata <- meta
  obj
}

test_that("print(survey_nonprob) shows 'none' when weighting history is empty", {
  df <- make_surveywts_data(n = 50, seed = 1)
  nps <- surveycore::survey_nonprob(
    data      = df,
    variables = list(weights = "base_weight")
  )
  expect_snapshot(print(nps))
})

test_that("print(survey_nonprob) shows strata variable in design line", {
  df <- make_surveywts_data(n = 100, seed = 2)
  nps <- surveycore::survey_nonprob(
    data      = df,
    variables = list(weights = "base_weight", strata = "region")
  )
  expect_snapshot(print(nps))
})

test_that("print(survey_nonprob) shows ids variable in design line", {
  df <- make_surveywts_data(n = 100, seed = 3)
  nps <- surveycore::survey_nonprob(
    data      = df,
    variables = list(weights = "base_weight", ids = "id")
  )
  expect_snapshot(print(nps))
})

test_that("print(survey_nonprob) formats calibrate_linear history step", {
  df <- make_surveywts_data(n = 100, seed = 4)
  nps <- surveycore::survey_nonprob(
    data      = df,
    variables = list(weights = "base_weight")
  )
  targets <- list(
    age_group = c("18-34" = 0.30, "35-54" = 0.40, "55+" = 0.30),
    sex       = c("M" = 0.48, "F" = 0.52)
  )
  cal <- suppressWarnings(calibrate_linear(nps, targets = targets, type = "prop"))
  expect_snapshot(print(.pin_history_ts(cal)))
})

test_that("print(survey_nonprob) formats calibrate_logit history step", {
  df <- make_surveywts_data(n = 100, seed = 5)
  nps <- surveycore::survey_nonprob(
    data      = df,
    variables = list(weights = "base_weight")
  )
  targets <- list(
    age_group = c("18-34" = 0.30, "35-54" = 0.40, "55+" = 0.30),
    sex       = c("M" = 0.48, "F" = 0.52)
  )
  cal <- suppressWarnings(calibrate_logit(nps, targets = targets, type = "prop"))
  expect_snapshot(print(.pin_history_ts(cal)))
})

test_that("print(survey_nonprob) formats poststratify history step", {
  df <- make_surveywts_data(n = 200, seed = 6)
  nps <- surveycore::survey_nonprob(
    data      = df,
    variables = list(weights = "base_weight")
  )
  targets <- data.frame(
    age_group = c("18-34", "35-54", "55+", "18-34", "35-54", "55+"),
    sex       = c("M", "M", "M", "F", "F", "F"),
    target    = c(0.144, 0.192, 0.144, 0.156, 0.208, 0.156)
  )
  ps <- suppressWarnings(poststratify(nps, targets = targets, type = "prop"))
  expect_snapshot(print(.pin_history_ts(ps)))
})

test_that("print(survey_nonprob) formats nonresponse_weighting_class history step (with by)", {
  df <- make_surveywts_data(n = 200, seed = 7, include_nonrespondents = TRUE)
  nps <- surveycore::survey_nonprob(
    data      = df[df$responded == 1L, ],
    variables = list(weights = "base_weight")
  )
  adj <- suppressWarnings(adjust_nonresponse(
    nps,
    response_status = "responded",
    method          = "weighting-class",
    by              = sex
  ))
  expect_snapshot(print(.pin_history_ts(adj)))
})

test_that("print(survey_nonprob) formats nonresponse_weighting_class history step (no by)", {
  df <- make_surveywts_data(n = 200, seed = 8, include_nonrespondents = TRUE)
  nps <- surveycore::survey_nonprob(
    data      = df[df$responded == 1L, ],
    variables = list(weights = "base_weight")
  )
  adj <- suppressWarnings(adjust_nonresponse(
    nps,
    response_status = "responded",
    method          = "weighting-class"
  ))
  expect_snapshot(print(.pin_history_ts(adj)))
})

test_that("print(survey_replicate) shows 'none' when weighting history is empty", {
  skip_if_not_installed("svrep")
  td  <- make_taylor_design(n = 50L, seed = 42L)
  rep <- create_bootstrap_weights(td, replicates = 10L, seed = 1L)
  # Strip history to simulate an empty-history replicate object
  meta <- rep@metadata
  meta@weighting_history <- list()
  rep@metadata <- meta
  expect_snapshot(print(rep))
})
