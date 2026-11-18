# Issue 148: for type = "count" on a survey_replicate, each replicate is
# calibrated to the population counts scaled by sum(rep_wt) / sum(base_wt).
# The scaled totals must keep the same level mix as the population targets,
# also when sum(base weights) != N.

.rep_count_setup <- function() {
  design <- make_replicate_design(n = 200L, R = 20L, seed = 7L)
  base_wt <- design@data[[design@variables$weights]]
  props <- c("18-34" = 0.25, "35-54" = 0.45, "55+" = 0.30)
  N_pop <- round(1.5 * sum(base_wt))
  list(
    design = design,
    base_wt = base_wt,
    props = props,
    counts = props * N_pop,
    N_pop = N_pop
  )
}

# Check every replicate column: calibrated level totals equal the population
# counts times sum(input rep_wt) / sum(base_wt).
.expect_rep_count_mix <- function(result, s, label) {
  for (col in s$design@variables$repweights) {
    rep_in <- s$design@data[[col]]
    rep_out <- result@data[[col]]
    ratio <- sum(rep_in) / sum(s$base_wt)
    got <- tapply(rep_out, result@data$age_group, sum)[names(s$counts)]
    expect_equal(
      as.numeric(got),
      unname(s$counts * ratio),
      tolerance = 1e-6,
      label = paste0(label, ": ", col)
    )
  }
}

test_that("calibrate_linear() count replicate totals keep the population mix", {
  s <- .rep_count_setup()
  expect_false(isTRUE(all.equal(sum(s$base_wt), s$N_pop)))

  result <- calibrate_linear(
    s$design,
    targets = list(age_group = s$counts),
    type = "count"
  )
  test_invariants(result)
  expect_true(all(result@calibration$replicate_converged))
  .expect_rep_count_mix(result, s, "calibrate_linear")
})

test_that("calibrate_logit() count replicate totals keep the population mix", {
  s <- .rep_count_setup()

  result <- calibrate_logit(
    s$design,
    targets = list(age_group = s$counts),
    type = "count"
  )
  test_invariants(result)
  expect_true(all(result@calibration$replicate_converged))
  .expect_rep_count_mix(result, s, "calibrate_logit")
})

test_that("calibrate_rake() count replicate totals keep the population mix", {
  s <- .rep_count_setup()

  result <- calibrate_rake(
    s$design,
    targets = list(age_group = s$counts),
    type = "count",
    algorithm = "nr"
  )
  test_invariants(result)
  .expect_rep_count_mix(result, s, "calibrate_rake")
})

test_that("poststratify() count replicate totals use the same scaling", {
  s <- .rep_count_setup()
  pop <- data.frame(
    age_group = names(s$counts),
    target = unname(s$counts),
    stringsAsFactors = FALSE
  )

  result <- poststratify(s$design, targets = pop, type = "count")
  test_invariants(result)
  .expect_rep_count_mix(result, s, "poststratify")
})
