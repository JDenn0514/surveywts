# test-backend-messages.R
#
# Tests for the back-end message helpers (issue #114).
# svrep prints a plain message() on some successful calls. Those messages
# carry no class, so a caller could only quiet them with a blanket
# suppressMessages(), which also swallowed every surveywts message. These
# tests pin the collect-translate-re-emit behaviour that replaced it.

# The three texts svrep emits, verbatim. The unbalanced quoting in the first
# one is svrep's, not a typo: it opens a backtick and never closes it.
svrep_row_order <- function(estimator = "SD1") {
  paste0(
    "For `variance_estimator='",
    estimator,
    "', assumes rows of data are sorted in the same order used in sampling."
  )
}
svrep_hadamard <- paste0(
  "Using Hadamard matrix of order 128. ",
  "If `use_normal_hadamard=TRUE`, the smallest possible order is 104."
)
svrep_truncated <- paste0(
  "The number of replicates needed for fully efficient replication is 68, ",
  "but `max_replicates` is set to 20. ",
  "Only a random sample of replicates will be retained."
)

# A plain message() condition, the shape svrep raises. simpleMessage() gives
# exactly simpleMessage/message/condition, which is what was measured.
plain_message <- function(text) {
  simpleMessage(text)
}

# ============================================================================
# .new_backend_message_store()
# ============================================================================

test_that(".new_backend_message_store() starts empty", {
  expect_identical(.new_backend_message_store()$msgs, list())
})

test_that(".new_backend_message_store() returns a fresh store each call", {
  first <- .new_backend_message_store()
  first$msgs <- list(plain_message("x"))
  expect_identical(.new_backend_message_store()$msgs, list())
})

# ============================================================================
# .collect_backend_messages()
# ============================================================================

test_that(".collect_backend_messages() returns the value of expr", {
  store <- .new_backend_message_store()
  expect_identical(
    .collect_backend_messages(
      {
        message("upstream")
        42L
      },
      store
    ),
    42L
  )
})

test_that(".collect_backend_messages() collects and muffles every message", {
  store <- .new_backend_message_store()
  expect_no_message(
    .collect_backend_messages(
      {
        message("one")
        message("two")
        NULL
      },
      store
    )
  )
  expect_length(store$msgs, 2L)
  expect_identical(trimws(conditionMessage(store$msgs[[1]])), "one")
})

test_that(".collect_backend_messages() leaves a surveywts message alone", {
  store <- .new_backend_message_store()
  expect_message(
    .collect_backend_messages(
      cli::cli_inform(
        c("i" = "mine"),
        class = "surveywts_message_already_calibrated"
      ),
      store
    ),
    class = "surveywts_message_already_calibrated"
  )
  expect_identical(store$msgs, list())
})

test_that(".collect_backend_messages() writes assignments to the caller frame", {
  store <- .new_backend_message_store()
  captured <- NULL
  .collect_backend_messages(
    {
      captured <- "written"
      NULL
    },
    store
  )
  expect_identical(captured, "written")
})

# ============================================================================
# .translate_backend_message()
# ============================================================================

test_that(".translate_backend_message() classes the row-order message", {
  out <- .translate_backend_message(
    plain_message(svrep_row_order("SD1")),
    n_rep = 20L,
    params = list(variance_estimator = "SD1", replicates = 20L),
    seed = 1L
  )
  expect_identical(out$class, "surveywts_message_row_order_assumed")
  expect_identical(out$data$estimator, "SD1")
})

test_that(".translate_backend_message() reads the estimator out of the text", {
  out <- .translate_backend_message(
    plain_message(svrep_row_order("SD2")),
    n_rep = 68L,
    params = list(variance_estimator = "SD2"),
    seed = NULL
  )
  expect_identical(out$data$estimator, "SD2")
})

test_that(".translate_backend_message() classes the Hadamard message", {
  out <- .translate_backend_message(
    plain_message(svrep_hadamard),
    n_rep = 128L,
    params = list(replicates = 100L),
    seed = NULL
  )
  expect_identical(out$class, "surveywts_message_replicates_rounded_up")
  expect_identical(out$data$requested, 100L)
  expect_identical(out$data$n_rep, 128L)
})

test_that(".translate_backend_message() drops the Hadamard message when the counts match", {
  expect_null(
    .translate_backend_message(
      plain_message(svrep_hadamard),
      n_rep = 128L,
      params = list(replicates = 128L),
      seed = NULL
    )
  )
})

test_that(".translate_backend_message() classes the truncation message", {
  out <- .translate_backend_message(
    plain_message(svrep_truncated),
    n_rep = 20L,
    params = list(max_replicates = 20L),
    seed = NULL
  )
  expect_identical(out$class, "surveywts_message_replicates_subsampled")
  expect_identical(out$data$natural, 68L)
  expect_identical(out$data$requested, 20L)
})

test_that(".translate_backend_message() names seed only when seed is NULL", {
  with_seed <- .translate_backend_message(
    plain_message(svrep_truncated),
    n_rep = 20L,
    params = list(max_replicates = 20L),
    seed = 1L
  )
  without_seed <- .translate_backend_message(
    plain_message(svrep_truncated),
    n_rep = 20L,
    params = list(max_replicates = 20L),
    seed = NULL
  )
  expect_false(any(grepl("seed", with_seed$bullets, fixed = TRUE)))
  expect_true(any(grepl("seed", without_seed$bullets, fixed = TRUE)))
})

test_that(".translate_backend_message() falls back to the generic class", {
  out <- .translate_backend_message(
    plain_message("Something svrep has not said before."),
    n_rep = 20L,
    params = list(),
    seed = NULL
  )
  expect_identical(out$class, "surveywts_message_backend_note")
  expect_identical(out$data$txt, "Something svrep has not said before.")
})

test_that(".translate_backend_message() falls back when the Hadamard params are absent", {
  out <- .translate_backend_message(
    plain_message(svrep_hadamard),
    n_rep = 128L,
    params = list(),
    seed = NULL
  )
  expect_identical(out$class, "surveywts_message_backend_note")
})

test_that(".translate_backend_message() sends the sort_variable note to the generic class", {
  sort_note <- paste0(
    "Since `sort_variable = NULL`, assuming rows of data are sorted in the ",
    "same order used in sampling."
  )
  out <- .translate_backend_message(
    plain_message(sort_note),
    n_rep = 32L,
    params = list(replicates = 20L),
    seed = NULL
  )
  expect_identical(out$class, "surveywts_message_backend_note")
})

# ============================================================================
# .report_backend_messages()
# ============================================================================

test_that(".report_backend_messages() prints nothing for an empty store", {
  expect_no_message(
    .report_backend_messages(
      .new_backend_message_store(),
      n_rep = 20L,
      params = list(),
      seed = NULL
    )
  )
})

test_that(".report_backend_messages() emits one classed message per collected message", {
  store <- .new_backend_message_store()
  store$msgs <- list(
    plain_message(svrep_row_order("SD2")),
    plain_message(svrep_truncated)
  )
  seen <- character()
  withCallingHandlers(
    .report_backend_messages(
      store,
      n_rep = 20L,
      params = list(max_replicates = 20L),
      seed = NULL
    ),
    message = function(m) {
      seen <<- c(seen, class(m)[[1]])
      invokeRestart("muffleMessage")
    }
  )
  expect_identical(
    seen,
    c(
      "surveywts_message_row_order_assumed",
      "surveywts_message_replicates_subsampled"
    )
  )
})

test_that(".report_backend_messages() re-emits an unrecognised text verbatim", {
  store <- .new_backend_message_store()
  store$msgs <- list(plain_message(svrep_hadamard))
  expect_message(
    .report_backend_messages(
      store,
      n_rep = 128L,
      params = list(),
      seed = NULL
    ),
    "use_normal_hadamard",
    class = "surveywts_message_backend_note"
  )
})

test_that(".report_backend_messages() returns invisible NULL", {
  expect_null(
    suppressMessages(
      .report_backend_messages(
        .new_backend_message_store(),
        n_rep = 20L,
        params = list(),
        seed = NULL
      )
    )
  )
})

# ============================================================================
# Integration: the six creators that call .convert_and_call()
# ============================================================================

make_gss_taylor <- function() {
  surveycore::as_survey(
    gss_2024,
    weights = wtssps,
    strata = vstrat,
    ids = vpsu,
    nest = TRUE
  )
}

make_cps_taylor <- function() {
  surveycore::as_survey(cps_2023, weights = wtfinl)
}

test_that("create_gen_boot_weights() classes the row-order message", {
  expect_message(
    create_gen_boot_weights(make_gss_taylor(), replicates = 20L, seed = 1L),
    class = "surveywts_message_row_order_assumed"
  )
})

test_that("create_gen_boot_weights() emits nothing unclassed", {
  seen <- character()
  withCallingHandlers(
    create_gen_boot_weights(make_gss_taylor(), replicates = 20L, seed = 1L),
    message = function(m) {
      seen <<- c(seen, class(m)[[1]])
      invokeRestart("muffleMessage")
    }
  )
  expect_true(all(grepl("^surveywts_message_", seen)))
})

test_that("create_gen_boot_weights() names the estimator it was given", {
  expect_message(
    create_gen_boot_weights(make_gss_taylor(), replicates = 20L, seed = 1L),
    "SD1",
    class = "surveywts_message_row_order_assumed"
  )
})

test_that("create_gen_boot_weights() stays quiet for an estimator that ignores row order", {
  expect_no_message(
    create_gen_boot_weights(
      make_gss_taylor(),
      replicates = 20L,
      variance_estimator = "Horvitz-Thompson",
      seed = 1L
    )
  )
})

test_that("create_gen_rep_weights() classes the row-order message", {
  expect_message(
    create_gen_rep_weights(make_gss_taylor(), seed = 1L),
    class = "surveywts_message_row_order_assumed"
  )
})

test_that("create_gen_rep_weights() classes both messages when max_replicates truncates", {
  seen <- character()
  withCallingHandlers(
    create_gen_rep_weights(make_gss_taylor(), max_replicates = 20L),
    message = function(m) {
      seen <<- c(seen, class(m)[[1]])
      invokeRestart("muffleMessage")
    }
  )
  expect_identical(
    seen,
    c(
      "surveywts_message_row_order_assumed",
      "surveywts_message_replicates_subsampled"
    )
  )
})

test_that("create_gen_rep_weights() names the fully efficient count", {
  # Read the subsample message on its own, with the row-order one muffled.
  txt <- NULL
  withCallingHandlers(
    create_gen_rep_weights(make_gss_taylor(), max_replicates = 20L),
    surveywts_message_replicates_subsampled = function(m) {
      txt <<- conditionMessage(m)
      invokeRestart("muffleMessage")
    },
    surveywts_message_row_order_assumed = function(m) {
      invokeRestart("muffleMessage")
    }
  )
  expect_match(txt, "68")
  expect_match(txt, "seed")
})

test_that("create_gen_rep_weights() drops the seed advice when seed is given", {
  txt <- NULL
  withCallingHandlers(
    create_gen_rep_weights(make_gss_taylor(), max_replicates = 20L, seed = 1L),
    surveywts_message_replicates_subsampled = function(m) {
      txt <<- conditionMessage(m)
      invokeRestart("muffleMessage")
    },
    surveywts_message_row_order_assumed = function(m) {
      invokeRestart("muffleMessage")
    }
  )
  expect_no_match(txt, "seed")
})

test_that("create_gen_rep_weights() stays quiet at the default max_replicates for a non-SD estimator", {
  expect_no_message(
    create_gen_rep_weights(
      make_gss_taylor(),
      variance_estimator = "Horvitz-Thompson",
      seed = 1L
    )
  )
})

test_that("create_sdr_weights() classes the rounding message and names both counts", {
  txt <- NULL
  design <- withCallingHandlers(
    create_sdr_weights(make_cps_taylor(), replicates = 100L),
    surveywts_message_replicates_rounded_up = function(m) {
      txt <<- conditionMessage(m)
      invokeRestart("muffleMessage")
    }
  )
  expect_match(txt, "100")
  expect_match(txt, "128")
  expect_length(design@variables$repweights, 128L)
})

test_that("create_sdr_weights() stays quiet when the count matches the request", {
  expect_no_message(create_sdr_weights(make_cps_taylor(), replicates = 128L))
})

test_that("create_sdr_weights() never mentions an argument it does not forward", {
  txt <- NULL
  withCallingHandlers(
    create_sdr_weights(make_cps_taylor(), replicates = 100L),
    surveywts_message_replicates_rounded_up = function(m) {
      txt <<- conditionMessage(m)
      invokeRestart("muffleMessage")
    }
  )
  expect_no_match(txt, "use_normal_hadamard")
})

test_that("the three silent creators stay silent", {
  gss <- make_gss_taylor()
  expect_no_message(create_brr_weights(gss))
  expect_no_message(create_jackknife_weights(gss, type = "jkn"))
  expect_no_message(
    create_bootstrap_weights(gss, replicates = 20L, seed = 1L)
  )
})

test_that(".convert_and_call() classes a message no pattern matches", {
  # The backend_fn mirrors create_sdr_weights(): it adds a .row_order column
  # so svrep does not emit its own `sort_variable = NULL` note on top of the
  # one this test raises. params carries `replicates = 32L`, the count svrep
  # returns for 20, so the Hadamard message translates to NULL and only the
  # unrecognised text reaches the caller.
  expect_message(
    .convert_and_call(
      data = make_cps_taylor(),
      backend_fn = function(d) {
        message("A back end said something new.")
        d$variables[[".row_order"]] <- seq_len(nrow(d$variables))
        out <- svrep::as_sdr_design(
          d,
          replicates = 20L,
          sort_variable = ".row_order",
          mse = TRUE
        )
        out$variables[[".row_order"]] <- NULL
        out
      },
      method = "successive-difference",
      params = list(replicates = 32L, sort_var = NULL, mse = TRUE)
    ),
    "A back end said something new",
    class = "surveywts_message_backend_note"
  )
})
