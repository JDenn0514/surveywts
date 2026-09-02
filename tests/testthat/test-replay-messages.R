# test-replay-messages.R
#
# Tests for the calibration replay message helpers (issue #111).
# The grouped jackknife and the quasi-randomization bootstrap re-run the
# stored calibration once per replicate. Each replay used to announce its own
# convergence. These tests pin the muffle-and-count behaviour that replaced it.

emit_already_calibrated <- function() {
  cli::cli_inform(
    c("i" = "all variables already met their margins"),
    class = "surveywts_message_already_calibrated"
  )
  invisible(TRUE)
}

# ============================================================================
# .new_replay_counter()
# ============================================================================

test_that(".new_replay_counter() starts at zero", {
  expect_identical(.new_replay_counter()$n, 0L)
})

test_that(".new_replay_counter() returns an independent counter each call", {
  a <- .new_replay_counter()
  b <- .new_replay_counter()
  a$n <- 5L
  expect_identical(b$n, 0L)
})

# ============================================================================
# .muffle_replay_messages()
# ============================================================================

test_that(".muffle_replay_messages() muffles the per-replicate message", {
  counter <- .new_replay_counter()
  expect_no_message(
    .muffle_replay_messages(
      for (i in 1:3) emit_already_calibrated(),
      counter = counter
    )
  )
})

test_that(".muffle_replay_messages() counts every muffled message", {
  counter <- .new_replay_counter()
  .muffle_replay_messages(
    for (i in 1:7) emit_already_calibrated(),
    counter = counter
  )
  expect_identical(counter$n, 7L)
})

test_that(".muffle_replay_messages() keeps loop side effects in the caller frame", {
  counter <- .new_replay_counter()
  acc <- integer(0)
  .muffle_replay_messages(
    for (i in 1:4) {
      emit_already_calibrated()
      acc <- c(acc, i)
    },
    counter = counter
  )
  expect_identical(acc, 1:4)
})

test_that(".muffle_replay_messages() returns the value of expr", {
  counter <- .new_replay_counter()
  out <- .muffle_replay_messages(
    {
      emit_already_calibrated()
      42L
    },
    counter = counter
  )
  expect_identical(out, 42L)
})

test_that(".muffle_replay_messages() leaves an unrelated message alone", {
  counter <- .new_replay_counter()
  expect_message(
    .muffle_replay_messages(
      cli::cli_inform(
        c("i" = "unrelated"),
        class = "surveywts_message_unrelated_for_test"
      ),
      counter = counter
    ),
    class = "surveywts_message_unrelated_for_test"
  )
  expect_identical(counter$n, 0L)
})

# ============================================================================
# .report_replay_messages()
# ============================================================================

test_that(".report_replay_messages() prints nothing when the count is zero", {
  counter <- .new_replay_counter()
  expect_no_message(.report_replay_messages(counter, replicates = 25L))
})

test_that(".report_replay_messages() emits the summary class above zero", {
  counter <- .new_replay_counter()
  counter$n <- 22L
  expect_message(
    .report_replay_messages(counter, replicates = 25L),
    class = "surveywts_message_replay_already_calibrated"
  )
})

test_that(".report_replay_messages() names the count and the replicate total", {
  counter <- .new_replay_counter()
  counter$n <- 22L
  msg <- NULL
  withCallingHandlers(
    .report_replay_messages(counter, replicates = 25L),
    surveywts_message_replay_already_calibrated = function(m) {
      msg <<- conditionMessage(m)
      invokeRestart("muffleMessage")
    }
  )
  expect_match(msg, "22 of 25 replicates", fixed = TRUE)
})

test_that(".report_replay_messages() returns invisible NULL", {
  counter <- .new_replay_counter()
  expect_null(.report_replay_messages(counter, replicates = 25L))
})

# ============================================================================
# Integration — the three replicate loops
# ============================================================================

replay <- make_replay_message_datasets()

# Count the per-replicate messages that escape a call. After the fix this is
# always 0; before the fix it was one per replicate.
count_escaped <- function(expr) {
  n <- 0L
  withCallingHandlers(
    force(expr),
    surveywts_message_already_calibrated = function(m) {
      n <<- n + 1L
      invokeRestart("muffleMessage")
    }
  )
  n
}

# Capture the text of the one summary message.
capture_summary <- function(expr) {
  msg <- NULL
  withCallingHandlers(
    force(expr),
    surveywts_message_replay_already_calibrated = function(m) {
      msg <<- conditionMessage(m)
      invokeRestart("muffleMessage")
    }
  )
  msg
}

# Assert the shape of a survey object a replicate-loop call produces: a
# single numeric, non-negative weight column, present in the data, and
# (when `replicates` is given) that many repwt_* columns, all present in
# the data.
expect_replicate_result <- function(result, replicates = NULL) {
  wt_col <- result@variables$weights
  expect_true(is.character(wt_col) && length(wt_col) == 1L)
  expect_true(wt_col %in% names(result@data))

  w <- result@data[[wt_col]]
  expect_true(is.numeric(w))
  expect_true(all(w >= 0))
  expect_true(any(w > 0))

  if (!is.null(replicates)) {
    rep_cols <- result@variables$repweights
    expect_identical(length(rep_cols), as.integer(replicates))
    expect_true(all(rep_cols %in% names(result@data)))
  }
}

test_that("DAGJK IPW path emits the summary, not one message per replicate", {
  expect_message(
    result <- suppressWarnings(create_jackknife_weights(
      replay$ipw_cal,
      replicates = 25L,
      type = "grouped",
      seed = 42L
    )),
    class = "surveywts_message_replay_already_calibrated"
  )
  expect_replicate_result(result, replicates = 25L)
})

test_that("DAGJK IPW path lets no per-replicate message escape", {
  suppressMessages(
    n <- count_escaped(suppressWarnings(
      result <- create_jackknife_weights(
        replay$ipw_cal,
        replicates = 25L,
        type = "grouped",
        seed = 42L
      )
    )),
    classes = "surveywts_message_replay_already_calibrated"
  )
  expect_identical(n, 0L)
  expect_replicate_result(result, replicates = 25L)
})

test_that("DAGJK calibration-only path lets no per-replicate message escape", {
  suppressMessages(
    n <- count_escaped(suppressWarnings(
      result <- create_jackknife_weights(
        replay$cal_only,
        replicates = 25L,
        type = "grouped",
        seed = 42L
      )
    )),
    classes = "surveywts_message_replay_already_calibrated"
  )
  expect_identical(n, 0L)
  expect_replicate_result(result, replicates = 25L)
})

test_that("bootstrap IPW path emits the summary, not one per replicate", {
  expect_message(
    result <- suppressWarnings(create_bootstrap_weights(
      replay$ipw_cal,
      replicates = 25L,
      type = "quasi-randomization",
      seed = 42L,
      reference_sample = replay$ref
    )),
    class = "surveywts_message_replay_already_calibrated"
  )
  expect_replicate_result(result, replicates = 25L)
})

test_that("bootstrap calibration-only path emits the summary", {
  expect_message(
    result <- suppressWarnings(create_bootstrap_weights(
      replay$cal_only,
      replicates = 25L,
      type = "quasi-randomization",
      seed = 42L
    )),
    class = "surveywts_message_replay_already_calibrated"
  )
  expect_replicate_result(result, replicates = 25L)
})

test_that("the summary names the count when every replicate met its margins", {
  msg <- capture_summary(suppressWarnings(
    result <- create_bootstrap_weights(
      replay$cal_only,
      replicates = 25L,
      type = "quasi-randomization",
      seed = 42L
    )
  ))
  expect_match(msg, "25 of 25 replicates", fixed = TRUE)
  expect_replicate_result(result, replicates = 25L)
})

test_that("no summary fires when no replicate meets its margins", {
  expect_no_message(
    result <- suppressWarnings(create_bootstrap_weights(
      replay$quiet,
      replicates = 25L,
      type = "quasi-randomization",
      seed = 42L
    )),
    class = "surveywts_message_replay_already_calibrated"
  )
  expect_replicate_result(result, replicates = 25L)
})

test_that("a direct calibrate_rake() call still emits the per-replicate message", {
  df <- data.frame(
    g = rep(c("a", "b"), each = 50L),
    w = rep(1, 100L),
    stringsAsFactors = FALSE
  )
  svy <- surveycore::as_survey_nonprob(df, weights = w)
  expect_message(
    result <- suppressWarnings(calibrate_rake(
      svy,
      targets = list(g = c("a" = 0.5, "b" = 0.5)),
      type = "prop"
    )),
    class = "surveywts_message_already_calibrated"
  )
  expect_replicate_result(result)
})
