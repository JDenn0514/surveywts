# R/vendor-rake-anesrake.R
#
# VENDORED CODE — do not edit the algorithm without updating VENDORED.md
#
# Source package : anesrake
# Source version : 0.92
# Authors        : Josh Pasek, with assistance from Gene Routh and Alex Tahk
# License        : GPL-2+ (compatible with this package's GPL-3)
# Source function: anesrake::anesrake() — IPF with chi-square variable selection
# CRAN URL       : https://cran.r-project.org/package=anesrake
#
# Adaptations from source:
#   - Extracted core IPF-with-chi-square-selection algorithm into a standalone
#     function that operates on plain numeric weight vectors, character level
#     vectors, and named target vectors. Removed all data.frame, caseid, and
#     svydesign dependencies.
#   - Convergence is based on percentage improvement in total chi-square between
#     consecutive sweeps (matching anesrake's iterate convergence criterion).
#   - Cap is applied after each margin adjustment step (same as anesrake).
#   - Variable selection order is re-computed at the start of each sweep using
#     the current weights (not pre-computed once before all sweeps).
#   - Return value is a list of calibrated weights and convergence information.
#
# Algorithm is mathematically consistent with anesrake::anesrake(). Numerical
# output is verified against anesrake::anesrake() within 1e-6 in the package's
# correctness tests (test-03-rake.R).
# ---------------------------------------------------------------------------


# .anesrake_calibrate ----------------------------------------------------------
# IPF raking with chi-square-based variable selection.
# Based on: anesrake::anesrake() — Pasek et al.
#
# Arguments:
#   variable_data  - named list (one element per calibration variable).
#                    Each element is a list with:
#                      $levels  : character vector (length n) — level of this
#                                 variable for each observation (unweighted).
#                      $targets : named numeric vector — target COUNT for each
#                                 level. Names must cover all levels in $levels.
#                    Targets must be in COUNT form (not proportions) —
#                    the caller converts prop -> count.
#   ww             - numeric vector (n): starting survey weights (all > 0)
#   pval           - double: chi-square p-value threshold for variable
#                    inclusion. Variables with p-value > pval are skipped in
#                    that sweep (treated as already calibrated). Default 0.05.
#   improvement    - double: percentage improvement convergence threshold.
#                    Iterations stop when the percentage reduction in total
#                    chi-square between consecutive sweeps is below this value.
#                    Default 0.01 (i.e., < 0.01% improvement → converged).
#   min_cell_n     - integer: minimum unweighted cell count for variable
#                    inclusion. Variables where any cell has fewer than
#                    min_cell_n unweighted observations are excluded entirely
#                    from raking. 0 = no minimum. Default 0L.
#   variable_select - character(1): method to aggregate chi-square across cells
#                    for ranking: "total" (sum), "max", or "average".
#                    Default "total".
#   maxit          - integer: maximum full sweeps. Default 1000L.
#   cap            - numeric or NULL: cap on w / mean(w). Applied after each
#                    margin adjustment step. NULL = no cap.
#
# Returns: list with
#   $weights           - numeric vector (n): calibrated weights
#   $converged         - logical
#   $iterations        - integer: full sweeps completed
#   $max_error         - numeric: improvement_pct in final sweep (or 0 if
#                        already calibrated on first sweep)
#   $already_calibrated - logical: TRUE when all variables pass/excluded in
#                         sweep 1 with no weight changes

.anesrake_calibrate <- function(
  variable_data,
  ww,
  pval = 0.05,
  improvement = 0.01,
  min_cell_n = 0L,
  variable_select = "total",
  maxit = 1000L,
  cap = NULL
) {
  var_names <- names(variable_data)
  n <- length(ww)

  # ---- Determine which variables to exclude entirely (min_cell_n filter) ----
  # Exclusion is based on UNWEIGHTED cell counts — checked once before raking.
  excluded_vars <- character(0)
  if (min_cell_n > 0L) {
    for (var in var_names) {
      levels_vec <- variable_data[[var]]$levels
      targets <- variable_data[[var]]$targets
      for (lev in names(targets)) {
        if (sum(levels_vec == lev) < min_cell_n) {
          excluded_vars <- c(excluded_vars, var)
          break
        }
      }
    }
  }
  active_vars <- setdiff(var_names, excluded_vars)

  # All variables excluded → already calibrated, weights unchanged
  if (length(active_vars) == 0L) {
    return(list(
      weights = ww,
      converged = TRUE,
      iterations = 1L,
      max_error = 0,
      already_calibrated = TRUE
    ))
  }

  # ---- Chi-square computation helper ----------------------------------------
  # Computes the per-cell chi-square values for one variable.
  # Returns a numeric vector of length = number of levels.
  # Chi-square cell: n_unweighted_total * (obs_prop - target_prop)^2 / target_prop
  # where obs_prop = weighted proportion, target_prop = target / total_target.
  .chi_sq_cells <- function(ww, vdata) {
    levels_vec <- vdata$levels
    targets <- vdata$targets
    total_target <- sum(targets)
    total_ww <- sum(ww)

    cells <- numeric(length(targets))
    n_total <- length(levels_vec)  # unweighted total N

    for (i in seq_along(targets)) {
      lev <- names(targets)[i]
      idx <- levels_vec == lev
      obs_ww <- sum(ww[idx])
      obs_prop <- if (total_ww > 0) obs_ww / total_ww else 0
      target_prop <- targets[[i]] / total_target
      n_cell <- sum(idx)
      cells[i] <- if (target_prop > 0) {
        n_cell * (obs_prop - target_prop)^2 / target_prop
      } else {
        0 # nocov
      }
    }
    cells
  }

  .chi_sq_score <- function(cells, variable_select) {
    switch(
      variable_select,
      "total"   = sum(cells),
      "max"     = max(cells),
      "average" = mean(cells)
    )
  }

  # ---- Compute initial total chi-square -------------------------------------
  prev_total_chi_sq <- sum(unlist(lapply(
    active_vars,
    function(v) .chi_sq_cells(ww, variable_data[[v]])
  )))

  converged <- FALSE
  iter <- 0L

  repeat {
    iter <- iter + 1L

    # Compute chi-square for each active variable at the start of this sweep
    var_chi_sq_cells <- lapply(active_vars, function(v) {
      .chi_sq_cells(ww, variable_data[[v]])
    })
    names(var_chi_sq_cells) <- active_vars

    # Score and rank variables (descending — most discrepant first)
    var_scores <- vapply(
      active_vars,
      function(v) .chi_sq_score(var_chi_sq_cells[[v]], variable_select),
      numeric(1)
    )
    sorted_vars <- active_vars[order(var_scores, decreasing = TRUE)]

    any_raked <- FALSE

    for (var in sorted_vars) {
      # Chi-square p-value test for this variable
      cells <- var_chi_sq_cells[[var]]
      chi_sq_total_var <- sum(cells)
      df <- length(cells) - 1L
      p_val <- if (df > 0L && chi_sq_total_var > 0) {
        stats::pchisq(chi_sq_total_var, df = df, lower.tail = FALSE)
      } else {
        1.0  # degenerate case: treat as already calibrated
      }

      if (p_val > pval) next  # skip: already calibrated

      # Rake this variable (multiplicative adjustment per level)
      vdata <- variable_data[[var]]
      levels_vec <- vdata$levels
      targets <- vdata$targets

      for (lev in names(targets)) {
        idx <- levels_vec == lev
        current_total <- sum(ww[idx])
        if (current_total > 0) {
          ratio <- targets[[lev]] / current_total
          ww[idx] <- ww[idx] * ratio
        }
      }

      # Apply cap after this variable's adjustment
      if (!is.null(cap)) {
        mean_w <- mean(ww)
        if (mean_w > 0) {
          too_large <- (ww / mean_w) > cap
          ww[too_large] <- cap * mean_w
        }
      }

      any_raked <- TRUE

      # Recompute chi-square for this variable (for reference; sorting uses
      # the values from the start of the sweep per spec rule 4)
      var_chi_sq_cells[[var]] <- .chi_sq_cells(ww, vdata)
    }

    # Compute total chi-square after the sweep
    curr_total_chi_sq <- sum(unlist(lapply(
      active_vars,
      function(v) .chi_sq_cells(ww, variable_data[[v]])
    )))

    # Percentage improvement
    improvement_pct <- if (prev_total_chi_sq > 0) {
      (prev_total_chi_sq - curr_total_chi_sq) / prev_total_chi_sq * 100
    } else {
      0
    }

    # Already calibrated: first sweep with no raking and no improvement
    if (iter == 1L && !any_raked) {
      return(list(
        weights = ww,
        converged = TRUE,
        iterations = 1L,
        max_error = 0,
        already_calibrated = TRUE
      ))
    }

    if (improvement_pct < improvement) {
      converged <- TRUE
      break
    }

    prev_total_chi_sq <- curr_total_chi_sq

    if (iter >= maxit) break
  }

  list(
    weights = ww,
    converged = converged,
    iterations = iter,
    max_error = if (converged) 0 else {
      # For non-convergence: report improvement_pct of last sweep
      prev_total_chi_sq <- sum(unlist(lapply(
        active_vars,
        function(v) .chi_sq_cells(ww, variable_data[[v]])
      )))
      if (prev_total_chi_sq > 0 && curr_total_chi_sq >= 0) {
        max(0, (prev_total_chi_sq - curr_total_chi_sq) / prev_total_chi_sq * 100)
      } else {
        0
      }
    },
    already_calibrated = FALSE
  )
}
