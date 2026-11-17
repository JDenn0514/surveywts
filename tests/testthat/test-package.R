test_that("package loads", {
  expect_true(is.character(utils::packageDescription("surveywts")$Version))
})

test_that("surveycore rejects 0-row survey designs", {
  # surveywts has no 0-row checks for survey objects. It relies on
  # surveycore (>= 1.2.0) to reject empty data at construction and on
  # @data assignment. If this test fails, surveywts needs those checks back.
  df <- make_surveywts_data(seed = 1)
  expect_error(
    surveycore::as_survey(df[0, ], weights = base_weight),
    class = "surveycore_error_empty_data"
  )
  design <- surveycore::as_survey(df, weights = base_weight)
  expect_error(
    {
      design@data <- design@data[integer(0), ]
    },
    class = "surveycore_error_empty_data"
  )
})
