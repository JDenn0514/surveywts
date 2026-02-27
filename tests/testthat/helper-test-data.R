# tests/testthat/helper-test-data.R
#
# Shared test infrastructure loaded automatically by testthat.
# Provides:
#   - make_surveyweights_data()   — synthetic data generator
#   - test_invariants()           — invariant checker

#' @keywords internal
make_surveyweights_data <- function(n = 100L, seed = 42L) {
  set.seed(seed)
  data.frame(
    x = rnorm(n),
    y = rnorm(n),
    g = sample(c("A", "B"), n, replace = TRUE)
  )
}

#' @keywords internal
test_invariants <- function(obj) {
  # Add package-specific invariants here as defined in the spec.
  expect_true(!is.null(obj))
}
