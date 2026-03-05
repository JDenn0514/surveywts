test_that("package loads", {
  expect_true(is.character(utils::packageDescription("surveywts")$Version))
})
