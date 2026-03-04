# tests/testthat/test-00-classes.R
#
# Tests for:
#   - weighted_df S3 class (print.weighted_df, dplyr_reconstruct.weighted_df)
#   - survey_calibrated S7 class (print method, validator)
#
# Per impl plan PR 3: weighted_df fixtures are constructed with structure(),
# NOT via .make_weighted_df() (defined in PR 4).

# ---------------------------------------------------------------------------
# Helpers (local to this file)
# ---------------------------------------------------------------------------

# Build a minimal weighted_df fixture with an optional history
.make_test_wdf <- function(history = list()) {
  structure(
    tibble::tibble(x = 1:5, w = c(1.0, 1.2, 0.8, 1.1, 0.9)),
    class = c("weighted_df", "tbl_df", "tbl", "data.frame"),
    weight_col = "w",
    weighting_history = history
  )
}

# Build a weighted_df with a 2-step history for print snapshot tests
.make_test_wdf_2step <- function() {
  ts <- as.POSIXct("2025-01-15 12:00:00", tz = "UTC")
  history <- list(
    list(
      step = 1L,
      operation = "nonresponse_weighting_class",
      timestamp = ts,
      call = "adjust_nonresponse(df, response_status = responded, by = c(age, sex))",
      parameters = list(by_variables = c("age", "sex")),
      weight_stats = list(
        before = list(n = 5L, n_positive = 5L, n_zero = 0L,
                      mean = 1.0, cv = 0.15, min = 0.8, p25 = 0.9,
                      p50 = 1.0, p75 = 1.1, max = 1.2, ess = 4.9),
        after = list(n = 5L, n_positive = 5L, n_zero = 0L,
                     mean = 1.0, cv = 0.18, min = 0.72, p25 = 0.85,
                     p50 = 0.95, p75 = 1.1, max = 1.28, ess = 4.8)
      ),
      convergence = NULL,
      package_version = "0.1.0"
    ),
    list(
      step = 2L,
      operation = "raking",
      timestamp = ts,
      call = "rake(df, margins = margins, weights = wt_nr)",
      parameters = list(variables = c("age", "sex", "education")),
      weight_stats = list(
        before = list(n = 5L, n_positive = 5L, n_zero = 0L,
                      mean = 1.0, cv = 0.18, min = 0.72, p25 = 0.85,
                      p50 = 0.95, p75 = 1.1, max = 1.28, ess = 4.8),
        after = list(n = 5L, n_positive = 5L, n_zero = 0L,
                     mean = 1.0, cv = 0.18, min = 0.72, p25 = 0.87,
                     p50 = 0.95, p75 = 1.14, max = 1.28, ess = 4.8)
      ),
      convergence = list(converged = TRUE, iterations = 5L,
                         max_error = 0.0003, tolerance = 1e-6),
      package_version = "0.1.0"
    )
  )
  structure(
    tibble::tibble(
      id = 1:5,
      age = c("18-34", "35-54", "55+", "18-34", "35-54"),
      sex = c("M", "F", "M", "F", "M"),
      education = c("<HS", "HS", "College", "Graduate", "College"),
      wt_final = c(0.72, 1.14, 0.95, 1.28, 0.91)
    ),
    class = c("weighted_df", "tbl_df", "tbl", "data.frame"),
    weight_col = "wt_final",
    weighting_history = history
  )
}

# Build a minimal survey_calibrated fixture
.make_test_sc <- function(history = list()) {
  df <- data.frame(
    x = 1:5,
    psu = c(1L, 1L, 2L, 2L, 3L),
    stratum = c("A", "A", "B", "B", "B"),
    w = c(1.2, 0.8, 1.1, 0.9, 1.0)
  )
  meta <- surveycore::survey_metadata(
    weighting_history = history
  )
  surveycore::survey_calibrated(
    data = df,
    variables = list(
      ids = "psu",
      strata = "stratum",
      fpc = NULL,
      weights = "w",
      nest = FALSE
    ),
    metadata = meta
  )
}

# ---------------------------------------------------------------------------
# 1. dplyr_reconstruct — select() preserving weight col → weighted_df
# ---------------------------------------------------------------------------

test_that("dplyr_reconstruct.weighted_df() preserves class when weight col is kept", {
  wdf <- .make_test_wdf()
  result <- dplyr::select(wdf, x, w)
  test_invariants(result)
  expect_true(inherits(result, "weighted_df"))
  expect_identical(attr(result, "weight_col"), "w")
  expect_identical(attr(result, "weighting_history"), list())
})

# ---------------------------------------------------------------------------
# 2. dplyr_reconstruct — select(-weight_col) → plain tibble + warning
# ---------------------------------------------------------------------------

test_that("dplyr_reconstruct.weighted_df() drops class and warns when weight col is removed", {
  wdf <- .make_test_wdf()

  expect_warning(
    result <- dplyr::select(wdf, x),
    class = "surveyweights_warning_weight_col_dropped"
  )
  expect_false(inherits(result, "weighted_df"))
  expect_true(tibble::is_tibble(result))
  expect_null(attr(result, "weight_col"))
})

expect_snapshot(dplyr::select(.make_test_wdf(), x))

# ---------------------------------------------------------------------------
# 2b. dplyr_reconstruct — rename(weight_col → new_name) → plain tibble + warning
# ---------------------------------------------------------------------------

test_that("dplyr_reconstruct.weighted_df() drops class and warns when weight col is renamed", {
  wdf <- .make_test_wdf()

  expect_warning(
    result <- dplyr::rename(wdf, weight_renamed = w),
    class = "surveyweights_warning_weight_col_dropped"
  )
  expect_false(inherits(result, "weighted_df"))
})

expect_snapshot(dplyr::rename(.make_test_wdf(), weight_renamed = w))

# ---------------------------------------------------------------------------
# 2c. dplyr_reconstruct — filter() preserving weight col → weighted_df
# ---------------------------------------------------------------------------

test_that("dplyr_reconstruct.weighted_df() preserves class after filter() with rows remaining", {
  wdf <- .make_test_wdf()
  result <- dplyr::filter(wdf, x > 2)
  test_invariants(result)
  expect_true(inherits(result, "weighted_df"))
  expect_identical(attr(result, "weight_col"), "w")
})

# ---------------------------------------------------------------------------
# 2d. dplyr_reconstruct — filter() to 0 rows → weighted_df (empty preserves class)
# ---------------------------------------------------------------------------

test_that("dplyr_reconstruct.weighted_df() preserves class when filter() results in 0 rows", {
  wdf <- .make_test_wdf()
  result <- dplyr::filter(wdf, x > 100)
  test_invariants(result)
  expect_true(inherits(result, "weighted_df"))
  expect_identical(nrow(result), 0L)
  expect_identical(attr(result, "weight_col"), "w")
})

# ---------------------------------------------------------------------------
# 2e. dplyr_reconstruct — mutate() adding a new column → weighted_df
# ---------------------------------------------------------------------------

test_that("dplyr_reconstruct.weighted_df() preserves class after mutate() adds a column", {
  wdf <- .make_test_wdf()
  result <- dplyr::mutate(wdf, y = x * 2)
  test_invariants(result)
  expect_true(inherits(result, "weighted_df"))
  expect_true("y" %in% names(result))
})

# ---------------------------------------------------------------------------
# 2f. dplyr_reconstruct — mutate() modifying weight VALUES → weighted_df
# ---------------------------------------------------------------------------

test_that("dplyr_reconstruct.weighted_df() preserves class when weight values are modified", {
  wdf <- .make_test_wdf()
  result <- dplyr::mutate(wdf, w = w * 2)
  test_invariants(result)
  expect_true(inherits(result, "weighted_df"))
  expect_identical(attr(result, "weight_col"), "w")
  # Values changed but column still exists
  expect_true(all(result$w > 0))
})

# ---------------------------------------------------------------------------
# 2g. dplyr_reconstruct — mutate(.keep = "unused") dropping weight col → warning + tibble
# ---------------------------------------------------------------------------

test_that("dplyr_reconstruct.weighted_df() drops class and warns when mutate(.keep='unused') removes weight col", {
  wdf <- .make_test_wdf()

  # .keep = "unused": keep only columns NOT used in any expression.
  # When w is USED in the expression, w is treated as "used" and gets dropped.
  expect_warning(
    result <- dplyr::mutate(wdf, y = w * 2, .keep = "unused"),
    class = "surveyweights_warning_weight_col_dropped"
  )
  expect_false(inherits(result, "weighted_df"))
  expect_false("w" %in% names(result))
})

expect_snapshot(dplyr::mutate(.make_test_wdf(), y = w * 2, .keep = "unused"))

# ---------------------------------------------------------------------------
# 3. Warning class is surveyweights_warning_weight_col_dropped
# (covered by tests 2, 2b, 2g above — explicit class checks included there)
# ---------------------------------------------------------------------------

test_that("warning class is surveyweights_warning_weight_col_dropped", {
  wdf <- .make_test_wdf()
  w <- tryCatch(
    withCallingHandlers(
      dplyr::select(wdf, x),
      warning = function(cnd) {
        expect_true(inherits(cnd, "surveyweights_warning_weight_col_dropped"))
        invokeRestart("muffleWarning")
      }
    )
  )
})

# ---------------------------------------------------------------------------
# 4. print.weighted_df — snapshot test (2-step history)
# ---------------------------------------------------------------------------

test_that("print.weighted_df() output matches snapshot with 2-step history", {
  wdf <- .make_test_wdf_2step()
  expect_snapshot(print(wdf))
})

# ---------------------------------------------------------------------------
# 4b. print.weighted_df — empty weighting_history → "# Weighting history: none"
# ---------------------------------------------------------------------------

test_that("print.weighted_df() shows 'Weighting history: none' when history is empty", {
  wdf <- .make_test_wdf()
  expect_snapshot(print(wdf))
})

# ---------------------------------------------------------------------------
# 5. History is empty list on initial creation
# ---------------------------------------------------------------------------

test_that("weighted_df has empty list weighting_history when constructed with no history", {
  wdf <- .make_test_wdf()
  expect_identical(attr(wdf, "weighting_history"), list())
})

# ---------------------------------------------------------------------------
# 6. Class vector is correct
# ---------------------------------------------------------------------------

test_that("weighted_df has correct class vector", {
  wdf <- .make_test_wdf()
  expect_identical(
    class(wdf),
    c("weighted_df", "tbl_df", "tbl", "data.frame")
  )
})

# ---------------------------------------------------------------------------
# 7. survey_calibrated print — snapshot test
# ---------------------------------------------------------------------------

test_that("print method for survey_calibrated produces expected output", {
  ts <- as.POSIXct("2025-01-15 12:00:00", tz = "UTC")
  history <- list(
    list(
      step = 1L,
      operation = "nonresponse_weighting_class",
      timestamp = ts,
      call = "adjust_nonresponse(df, ...)",
      parameters = list(by_variables = c("age", "sex")),
      weight_stats = list(before = list(), after = list()),
      convergence = NULL,
      package_version = "0.1.0"
    ),
    list(
      step = 2L,
      operation = "raking",
      timestamp = ts,
      call = "rake(df, ...)",
      parameters = list(variables = c("age", "sex", "education")),
      weight_stats = list(before = list(), after = list()),
      convergence = list(converged = TRUE, iterations = 5L,
                         max_error = 0.0003, tolerance = 1e-6),
      package_version = "0.1.0"
    )
  )
  sc <- .make_test_sc(history = history)
  expect_snapshot(print(sc))
})

# ---------------------------------------------------------------------------
# 8. survey_calibrated S7 validator — rejects non-positive weights
# ---------------------------------------------------------------------------

test_that("survey_calibrated validator rejects non-positive weights", {
  # class= only, no snapshot (validator messages are not CLI-formatted)
  expect_error(
    surveycore::survey_calibrated(
      data = data.frame(x = 1:5, w = c(1.0, 0.0, 1.0, 1.0, 1.0)),
      variables = list(
        ids = NULL, strata = NULL, fpc = NULL, weights = "w", nest = FALSE
      )
    ),
    class = "surveycore_error_weights_nonpositive"
  )
})

# ---------------------------------------------------------------------------
# 9. survey_calibrated S7 validator — rejects all-NA weight column
# ---------------------------------------------------------------------------

test_that("survey_calibrated validator rejects weight column where all values are NA", {
  # surveycore's validator permits individual NAs; errors only when ALL are NA
  # Actual surveycore class: surveycore_error_weights_all_zero
  # (spec listed surveycore_error_weights_na; actual class differs)
  expect_error(
    surveycore::survey_calibrated(
      data = data.frame(x = 1:5, w = rep(NA_real_, 5)),
      variables = list(
        ids = NULL, strata = NULL, fpc = NULL, weights = "w", nest = FALSE
      )
    ),
    class = "surveycore_error_weights_all_zero"
  )
})
