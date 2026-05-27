# R/rake-anesrake-engine.R
#
# Internal raking engine for method = "anesrake".
#
# Algorithm and logic ported from the anesrake R package:
#   Pasek, Josh (with help from Jon Krosnick and some code from
#   Alex Tahk and others). anesrake: ANES Raking Implementation.
#   https://CRAN.R-project.org/package=anesrake
#
# Weighting methodology from:
#   DeBell, Matthew, and Jon A. Krosnick. 2009. "Computing Weights for
#   American National Election Study Survey Data." ANES Technical Report
#   nes012427. https://electionstudies.org/
#
# Changes from the original (beyond style/formatting):
#   - Only code paths reachable via rake() are retained
#   - .rake_list() captures pre-cap weight vector before each capping step
#     and returns it in the result (the original destroys this state)

# ============================================================================
# .rake_discrep() — factor-only discrepancy (ported from discrep.factor.R)
# ============================================================================

# rake() always converts variables to factor before calling the engine,
# so only the factor method is needed.
.rake_discrep <- function(datavec, targetvec, weightvec) {
  dat <- sapply(names(targetvec), function(x) {
    sum(weightvec[datavec == x & !is.na(datavec)]) /
      sum(weightvec[!is.na(datavec)])
  })
  targetvec - dat
}

# ============================================================================
# .rake_on_var() — rake weights on a single variable (ported from rakeonvar.R)
# ============================================================================

# rake() always converts variables to factor with explicit levels before calling
# the engine, so weighton is always a clean integer sequence with no NAs and
# no extra levels. The NA-remapping and missing-category paths are not needed.
.rake_on_var <- function(weighton, weightto, weightvec) {
  weighton <- as.numeric(weighton)
  lwo <- length(table(weighton))
  if (sum(weightto) < 1.5) {
    weightto <- weightto * sum(weightvec)
  }
  for (i in seq_len(lwo)) {
    weightvec[weighton == i] <- weightvec[weighton == i] *
      (weightto[i] / sum(weightvec[weighton == i]))
  }
  weightvec
}

# ============================================================================
# .rake_find_discrepancies() — (ported from anesrakefinder.R)
#
# Supports the three choosemethod values exposed by rake() via
# control$variable_select: "total", "max", "average".
# ============================================================================

.rake_find_discrepancies <- function(
  inputter,
  dataframe,
  weightvec,
  choosemethod = "total"
) {
  findoff <- lapply(names(inputter), function(x) {
    .rake_discrep(dataframe[, x], inputter[x][[1]], weightvec)
  })
  names(findoff) <- names(inputter)
  if (choosemethod == "total") {
    out <- sapply(findoff, function(x) sum(abs(x), na.rm = TRUE))
  }
  if (choosemethod == "max") {
    out <- sapply(findoff, function(x) range(abs(x), na.rm = TRUE)[2])
  }
  if (choosemethod == "average") {
    out <- sapply(findoff, function(x) mean(abs(x), na.rm = TRUE))
  }
  out
}

# ============================================================================
# .rake_select_by_pct() — (ported from selecthighestpcts.R)
#
# tostop = 1: error if no variable exceeds threshold (used for initial
#   variable selection; triggers the "already calibrated" path upstream).
# tostop = 0: silent empty result (used in the pctlim iterate loop to
#   discover newly off-target variables after raking).
# ============================================================================

.rake_select_by_pct <- function(dif, inputter, pctlim, tostop = 1) {
  found <- inputter[dif >= pctlim]
  if (length(found) == 0 && tostop == 1) {
    stop(paste(
      "No variables are off by more than",
      pctlim * 100,
      "percent using the method you have chosen, either weighting is unnecessary or a smaller pre-raking limit should be chosen."
    ))
  }
  found
}

# ============================================================================
# .rake_list() — inner convergence loop (ported from rakelist.R)
#
# Only algorithmic change: captures precap_weightvec before each capping block.
# ============================================================================

.rake_list <- function(
  inputter,
  dataframe,
  caseid,
  weightvec,
  cap = 999999,
  maxit = 1000,
  convcrit = 0.01
) {
  mat <- dataframe
  prevec <- weightvec
  diferr <- 9999999
  diferrold <- 99999999999
  g <- 0
  pctstill <- 1 - convcrit
  pop <- 0
  # Defensive init so R static analysis is satisfied; overwritten each iteration.
  precap_weightvec <- weightvec
  while (diferr < pctstill * diferrold) {
    g <- g + 1
    wvold <- weightvec
    for (i in names(inputter)) {
      weightvec <- .rake_on_var(mat[, i], inputter[[i]], weightvec)
    }
    precap_weightvec <- weightvec
    while (max(weightvec) > cap + 1e-04) {
      weightvec <- pmin(weightvec, cap)
      weightvec <- weightvec / mean(weightvec)
    }
    diferrold <- diferr
    diferr <- sum(abs(weightvec - wvold))
    if (g > maxit) {
      warning("Raking Algorithm Did Not Converge, Results May Be Highly Inconsistent")
      diferrold <- 0
      pop <- 2
      converge <- paste("No convergence in", maxit, "iterations")
    }
  }
  # nocov start
  # Partial convergence: loop exited because improvement stalled, not because
  # full convergence was reached. Reachable in principle (unusual datasets) but
  # not triggered by current tests; the non-convergence path (g > maxit) is
  # tested instead.
  if (diferr > 0.001) {
    warning(paste(
      "Raking algorithm achieved only partial convergence, please check the results to ensure that sufficient convergence was achieved.  Average change in weight per case is",
      diferr / sum(weightvec)
    ))
    warning("Results are stable, but do not perfectly match population marginals")
    diferrx <- diferr
    pop <- 1
    converge <- "Results are stable, but do not perfectly match population marginals"
  }
  # nocov end
  if (pop == 0) {
    diferrx <- diferr
    converge <- "Complete convergence was achieved"
  }
  names(weightvec) <- caseid
  list(
    weightvec        = weightvec,
    caseid           = caseid,
    iterations       = g,
    nonconvergence   = diferr,
    converge         = converge,
    varsused         = names(inputter),
    targets          = inputter,
    dataframe        = dataframe,
    prevec           = prevec,
    precap_weightvec = precap_weightvec
  )
}

# ============================================================================
# .rake_anesrake() — top-level dispatcher (ported from anesrake.R)
#
# Only the type = "pctlim" path is retained; rake() always passes that type.
# ============================================================================

.rake_anesrake <- function(
  inputter,
  dataframe,
  caseid,
  weightvec,
  cap = 5,
  maxit = 1000,
  pctlim = 5,
  choosemethod = "total",
  iterate = TRUE,
  convcrit = 0.01
) {
  mat <- as.data.frame(dataframe)
  # Normalize starting weights so they average to 1.
  weightvec <- weightvec / mean(weightvec, na.rm = TRUE)
  prevec <- weightvec

  discrep1 <- .rake_find_discrepancies(inputter, dataframe, weightvec, choosemethod)
  towers <- .rake_select_by_pct(discrep1, inputter, pctlim)

  ranweight <- .rake_list(towers, mat, caseid, weightvec, cap, maxit, convcrit)
  iterations <- ranweight$iterations
  weightout <- ranweight$weightvec

  if (iterate) {
    ww <- 0
    it <- 0
    while (ww < 1) {
      it <- it + 1
      addtotowers <- .rake_select_by_pct(
        .rake_find_discrepancies(inputter, dataframe, weightout),
        inputter, pctlim, tostop = 0
      )
      adders <- addtotowers[!(names(addtotowers) %in% names(towers))]
      tow2 <- c(towers, adders)
      towersx <- towers
      towers <- tow2
      if (sum(as.numeric(names(towersx) %in% names(towers))) == length(towers)) {
        ww <- 1
      }
      # nocov start
      # Re-raking triggered when a previously on-target variable falls off
      # after raking others in. Reachable but not triggered by current tests.
      if (sum(as.numeric(names(towersx) %in% names(towers))) != length(towers)) {
        ranweight <- .rake_list(towers, mat, caseid, weightvec, cap, maxit, convcrit)
        weightout <- ranweight$weightvec
      }
      if (it > 10) {
        ww <- 1
      }
      # nocov end
      iterations <- ranweight$iterations
    }
  }

  names(weightout) <- caseid
  list(
    weightvec        = weightout,
    caseid           = caseid,
    varsused         = names(towers),
    choosemethod     = choosemethod,
    converge         = ranweight$converge,
    nonconvergence   = ranweight$nonconvergence,
    targets          = inputter,
    dataframe        = dataframe,
    iterations       = iterations,
    prevec           = prevec,
    precap_weightvec = ranweight$precap_weightvec
  )
}
