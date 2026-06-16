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
