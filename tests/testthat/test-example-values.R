# tests/testthat/test-example-values.R
#
# Guards the `#>` expected-output comments pasted into the roxygen
# @examples blocks of effective_sample_size(), weight_variability(), and
# summarize_weights(). Not a coverage test: if one of these fails, the
# named .R file's roxygen comment is stale, not the underlying function.

test_that("R/effective_sample_size.R's #> comment matches effective_sample_size()", {
  ns_wave1_svy <- surveycore::as_survey_nonprob(ns_wave1, weights = weight)
  n_eff <- unname(effective_sample_size(ns_wave1_svy))

  expect_equal(
    round(n_eff, 3),
    2254.539,
    info = paste0(
      "R/effective_sample_size.R's `#> n_eff` comment is stale for ",
      "effective_sample_size()."
    )
  )
})

test_that("R/weight_variability.R's #> comment matches weight_variability()", {
  ns_wave1_svy <- surveycore::as_survey_nonprob(ns_wave1, weights = weight)
  cv <- unname(weight_variability(ns_wave1_svy))

  expect_equal(
    round(cv, 6),
    1.359692,
    info = paste0(
      "R/weight_variability.R's `#> cv` comment is stale for ",
      "weight_variability()."
    )
  )
})

test_that("R/summarize_weights.R's ungrouped #> comment matches summarize_weights()", {
  ns_wave1_svy <- surveycore::as_survey_nonprob(ns_wave1, weights = weight)
  out <- summarize_weights(ns_wave1_svy)

  info <- "R/summarize_weights.R's ungrouped #> comment is stale for summarize_weights()."

  expect_identical(out$n, 6422L, info = info)
  expect_identical(out$n_positive, 6422L, info = info)
  expect_identical(out$n_zero, 0L, info = info)
  expect_equal(round(out$mean, 2), 1.00, info = info)
  expect_equal(round(out$cv, 2), 1.36, info = info)
  expect_equal(round(out$min, 5), 0.00382, info = info)
  expect_equal(round(out$p25, 3), 0.153, info = info)
  expect_equal(round(out$p50, 3), 0.400, info = info)
  expect_equal(round(out$p75, 2), 1.13, info = info)
  expect_equal(round(out$max, 2), 4.78, info = info)
  expect_equal(round(out$ess, 0), 2255, info = info)
})

test_that("R/summarize_weights.R's by = sex #> comment matches summarize_weights()", {
  ns_wave1_svy <- surveycore::as_survey_nonprob(ns_wave1, weights = weight)
  out <- summarize_weights(ns_wave1_svy, by = sex)

  info <- "R/summarize_weights.R's `by = sex` #> comment is stale for summarize_weights()."

  expect_identical(nrow(out), 2L, info = info)
  expect_identical(ncol(out), 12L, info = info)

  male <- out[out$sex == "Male", ]
  female <- out[out$sex == "Female", ]

  expect_identical(male$n, 3632L, info = info)
  expect_equal(round(male$mean, 3), 0.877, info = info)
  expect_equal(round(male$cv, 2), 1.44, info = info)
  expect_equal(round(male$min, 5), 0.00382, info = info)
  expect_equal(round(male$p25, 3), 0.138, info = info)
  expect_equal(round(male$p50, 3), 0.353, info = info)
  expect_equal(round(male$p75, 3), 0.893, info = info)
  expect_equal(round(male$max, 2), 4.78, info = info)

  expect_identical(female$n, 2790L, info = info)
  expect_equal(round(female$mean, 2), 1.16, info = info)
  expect_equal(round(female$cv, 2), 1.26, info = info)
  expect_equal(round(female$min, 5), 0.00382, info = info)
  expect_equal(round(female$p25, 3), 0.173, info = info)
  expect_equal(round(female$p50, 3), 0.494, info = info)
  expect_equal(round(female$p75, 2), 1.47, info = info)
  expect_equal(round(female$max, 2), 4.77, info = info)
})
