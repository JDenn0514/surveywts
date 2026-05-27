# test-08-nps-bootstrap.R
# PR 1 stub: smoke tests for NPS bootstrap helper functions.
# Full test suite is added in PR 2.

test_that("NPS bootstrap helper functions return survey_nonprob with ipw history", {
  ref   <- make_nps_ref(seed = 42)
  lev_a <- make_nps_level_a(seed = 1)
  lev_b <- make_nps_level_b(seed = 2)

  expect_true(!is.null(ref))
  expect_true(!is.null(lev_a))
  expect_true(!is.null(lev_b))

  for (obj in list(lev_a, lev_b)) {
    ops <- vapply(obj@metadata@weighting_history, `[[`, character(1), "operation")
    expect_true("ipw" %in% ops)
  }
})
