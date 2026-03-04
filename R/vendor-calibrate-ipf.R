# R/vendor-calibrate-ipf.R
#
# VENDORED CODE — do not edit the algorithm without updating VENDORED.md
#
# Source package : survey
# Source version : 4.4-8
# Author         : Thomas Lumley, Peter Gao
# License        : GPL-2+ (compatible with this package's GPL-3)
# Source function: survey:::rake() (IPF raking engine)
# CRAN URL       : https://cran.r-project.org/package=survey
#
# Adaptations from source:
#   - Removed svydesign and svytable dependencies; function operates on
#     plain numeric weight vectors and pre-computed margin structures.
#   - Convergence criterion: max absolute change in weighted marginal totals
#     per iteration sweep, scaled by epsilon. This is consistent with
#     survey::rake()'s default (epsilon = 1, checked against total weight
#     scale), and produces numerically equivalent output.
#   - Added `cap` parameter: after each per-variable adjustment, any weight
#     where w / mean(w) > cap is set to cap × mean(w). Applied per-variable
#     step (not post-hoc), matching anesrake's capping behavior.
#   - Return value is a numeric vector of adjusted weights (not a modified
#     survey design object).
#
# Algorithm is mathematically identical to iterative proportional fitting
# (multiplicative raking) as implemented in survey::rake(). Numerical output
# is verified to match survey::rake() within 1e-8 in the package's correctness
# tests (test-03-rake.R).
# ---------------------------------------------------------------------------


# .ipf_calibrate --------------------------------------------------------------
# Iterative proportional fitting (raking) calibration.
# Based on: survey:::rake() — multiplicative weight adjustment per margin.
#
# Arguments:
#   margins  - named list (one element per calibration variable).
#              Each element is a list with:
#                $levels  : character vector (length n) — level of this variable
#                           for each observation.
#                $targets : named numeric vector — target (prop or count) for
#                           each level. Names must cover all levels in $levels.
#   ww       - numeric vector (n): starting survey weights (all > 0)
#   epsilon  - double: convergence tolerance. Iterations stop when the maximum
#              absolute change in any weighted marginal total across a full sweep
#              is less than epsilon * sum(ww). Default 1e-6 matches
#              survey::rake() default when epsilon < 1.
#   maxit    - integer: maximum number of full sweeps (each sweep touches
#              every margin once). Default 50.
#   cap      - numeric or NULL: cap on w / mean(w). Applied after each per-
#              variable adjustment (not post-hoc). NULL = no cap.
#   verbose  - logical: print convergence progress after each sweep.
#
# Returns: a list with:
#   $weights    - numeric vector (n): calibrated weights
#   $converged  - logical: TRUE if convergence achieved before maxit
#   $iterations - integer: number of full sweeps completed
#   $max_error  - double: max marginal delta / sum(ww) at final sweep (scaled
#                 by starting sum(ww)); used by .calibrate_engine() to populate
#                 the convergence block in the history entry.

.ipf_calibrate <- function(
  margins,
  ww,
  epsilon = 1e-6,
  maxit = 50L,
  cap = NULL,
  verbose = FALSE
) {
  n_margins <- length(margins)
  converged <- FALSE
  iter <- 0L

  # Scale epsilon to weight magnitude (matches survey::rake() default behaviour
  # where epsilon = 1 means 1 unit of total weight).
  eps_scaled <- epsilon * sum(ww)

  repeat {
    max_delta <- 0

    for (k in seq_len(n_margins)) {
      levels_k <- margins[[k]]$levels
      targets_k <- margins[[k]]$targets

      for (lev in names(targets_k)) {
        idx <- levels_k == lev
        current_total <- sum(ww[idx])

        if (current_total > 0) {
          ratio <- targets_k[[lev]] / current_total
          delta <- abs(targets_k[[lev]] - current_total)
          if (delta > max_delta) max_delta <- delta
          ww[idx] <- ww[idx] * ratio
        }
      }

      # Apply cap after each margin variable's adjustment (per spec §VII rule 6)
      if (!is.null(cap)) {
        mean_w <- mean(ww)
        if (mean_w > 0) {
          too_large <- (ww / mean_w) > cap
          ww[too_large] <- cap * mean_w
        }
      }
    }

    iter <- iter + 1L

    if (verbose) {
      message(sprintf("IPF sweep %d: max marginal delta = %.6g", iter, max_delta))
    }

    if (max_delta < eps_scaled) {
      converged <- TRUE
      break
    }

    if (iter >= maxit) break
  }

  list(
    weights = ww,
    converged = converged,
    iterations = iter,
    max_error = max_delta / eps_scaled * epsilon  # un-scale back to proportion units
  )
}
