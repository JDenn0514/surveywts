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
