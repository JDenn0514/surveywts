# R/calibrate-utils.R
#
# Calibration-family shared helpers.
# Used by calibrate_rake(), calibrate_linear(), and calibrate_logit().
#
# Contents (in addition to helpers defined below .parse_margins()):
#   .anesrake_engine()                — anesrake calibration engine
#   .throw_not_converged_zero_maxit() — error for maxit = 0 case

# ---------------------------------------------------------------------------
# .parse_margins() — converts targets/margins to Format A
# ---------------------------------------------------------------------------

# Converts targets to Format A (named list of named numeric vectors).
# Accepts:
#   - Format A: named list (pass-through, with data.frame elements normalized)
#   - Format B: data.frame with columns 'variable', 'level', 'target'
#
# Returns: named list. Each element is a named numeric vector
#   c(level1 = target1, level2 = target2, ...)
#
# Errors with surveywts_error_margins_format_invalid if targets is neither
# a named list nor a valid Format B data.frame.
.parse_margins <- function(targets) {
  # Format B: data.frame with required columns
  if (is.data.frame(targets)) {
    required_cols <- c("variable", "level", "target")
    missing_cols <- setdiff(required_cols, names(targets))
    if (length(missing_cols) > 0L) {
      cli::cli_abort(
        c(
          "x" = paste0(
            "{.arg targets} must be a named list or a data frame with ",
            "columns {.field variable}, {.field level}, and {.field target}."
          ),
          "i" = paste0(
            "Got {.cls data.frame} but missing column(s): ",
            "{.and {.field {missing_cols}}}."
          ),
          "v" = paste0(
            "See {.fn calibrate_rake}, {.fn calibrate_linear}, or {.fn calibrate_logit} documentation ",
            "for accepted formats."
          )
        ),
        class = "surveywts_error_margins_format_invalid"
      )
    }

    # Convert to Format A: split by variable, build named vector per variable
    var_names <- unique(as.character(targets$variable))
    result <- lapply(var_names, function(v) {
      rows <- targets[as.character(targets$variable) == v, , drop = FALSE]
      stats::setNames(
        as.double(rows$target),
        as.character(rows$level)
      )
    })
    names(result) <- var_names
    return(result)
  }

  # Format A: named list — normalize data.frame elements to named vectors
  if (is.list(targets) && !is.data.frame(targets)) {
    if (length(names(targets)) == 0L || any(names(targets) == "")) {
      cli::cli_abort(
        c(
          "x" = paste0(
            "{.arg targets} must be a named list or a data frame with ",
            "columns {.field variable}, {.field level}, and {.field target}."
          ),
          "i" = paste0(
            "Got {.cls {class(targets)[[1]]}} but list elements are not named."
          ),
          "v" = paste0(
            "See {.fn calibrate_rake}, {.fn calibrate_linear}, or {.fn calibrate_logit} documentation ",
            "for accepted formats."
          )
        ),
        class = "surveywts_error_margins_format_invalid"
      )
    }

    # Normalize any data.frame elements to named vectors
    result <- lapply(names(targets), function(v) {
      elem <- targets[[v]]
      if (is.data.frame(elem)) {
        if (!all(c("level", "target") %in% names(elem))) {
          cli::cli_abort(
            c(
              "x" = paste0(
                "Element {.field {v}} in {.arg targets} is a data frame but ",
                "is missing required columns {.field level} and/or {.field target}."
              ),
              "v" = paste0(
                "See {.fn calibrate_rake}, {.fn calibrate_linear}, or {.fn calibrate_logit} documentation ",
                "for accepted formats."
              )
            ),
            class = "surveywts_error_margins_format_invalid"
          )
        }
        stats::setNames(
          as.double(elem$target),
          as.character(elem$level)
        )
      } else {
        # Already a named vector — ensure it is double-typed
        stats::setNames(as.double(unname(elem)), names(elem))
      }
    })
    names(result) <- names(targets)
    return(result)
  }

  # Neither list nor data.frame
  cls <- class(targets)[[1L]]
  cli::cli_abort(
    c(
      "x" = paste0(
        "{.arg targets} must be a named list or a data frame with ",
        "columns {.field variable}, {.field level}, and {.field target}."
      ),
      "i" = "Got {.cls {cls}}.",
      "v" = paste0(
        "See {.fn calibrate_rake}, {.fn calibrate_linear}, or {.fn calibrate_logit} documentation ",
        "for accepted formats."
      )
    ),
    class = "surveywts_error_margins_format_invalid"
  )
}

# ---------------------------------------------------------------------------
# .build_calibration_provenance() — assembles @calibration list from engine
# ---------------------------------------------------------------------------

# Assembles the @calibration list from ingredients available after
# .anesrake_engine() or .calibrate_nr_engine() returns. Called once per
# full-sample calibration by calibrate_rake(), calibrate_linear(), and
# calibrate_logit().
#
# The @calibration list is the cross-package contract between surveywts
# (writer) and surveycore (reader). Surveycore reads this list at variance
# estimation time.
#
# Arguments:
#   engine_result     : named list from .anesrake_engine() or .calibrate_nr_engine(); must contain
#                       $weights (calibrated weight vector) and $convergence
#                       (list with $converged and $iterations fields)
#   x_matrix          : n x J numeric matrix — calibration model matrix built
#                       by the calling function
#   base_weights      : numeric length-n — pre-calibration design weights (d_k)
#   q_weights         : numeric length-n — per-unit tuning constants (default
#                       all ones)
#   population_totals : numeric length-J — known population totals in count
#                       scale
#   method            : character(1) — one of "linear", "logit", "raking",
#                       "poststrat"
#   cell_factors      : named numeric or NULL — post-stratification cell
#                       ratios N_c / N_hat_c. NULL for non-poststrat methods.
#
# Returns: named list with 12 fields conforming to the @calibration contract.
#   replicate_converged is NOT included — callers add it for survey_replicate
#   inputs. Returned visibly (not invisible()) so callers can assign directly:
#   caldata <- .build_calibration_provenance(...)
#
# No errors thrown: all validation is the caller's or the engine's
# responsibility. Singularity in solve() propagates naturally.
#
# @keywords internal
# @noRd
.build_calibration_provenance <- function(
  engine_result,
  x_matrix,
  base_weights,
  q_weights,
  population_totals,
  method,
  lambda = NULL,
  cell_factors = NULL,
  bounds_scale = NULL
) {
  # g_weights: a_k = calibrated_weight_k / base_weight_k.
  # NaN when base_weights[k] == 0 (cannot occur under .validate_weights()
  # but do not error defensively).
  g_weights <- engine_result$weights / base_weights

  # discrepancy: HT deficit at base weights (pre-calibration shortfall).
  # Not the post-calibration residual.
  discrepancy <- population_totals -
    drop(t(x_matrix) %*% base_weights)

  # crossproduct_inv: inverse of the weighted cross-product matrix.
  # If singular, solve() propagates the error naturally (engine would
  # have already failed in practice).
  C <- t(x_matrix) %*% (base_weights * q_weights * x_matrix)
  crossproduct_inv <- solve(C)

  # lambda: use the explicit argument if supplied; otherwise compute from
  # the closed-form linear approximation for backward-compatibility with
  # callers that don't supply it. For raking and poststrat methods without
  # explicit lambda: NULL.
  if (is.null(lambda)) {
    lambda <- if (method %in% c("linear", "logit")) {
      crossproduct_inv %*% discrepancy
    } else {
      NULL
    }
  }

  converged <- engine_result$convergence$converged

  # n_iterations: as.integer() preserves NA_integer_ for logit (survey::calibrate()
  # does not expose an iteration count for Newton-Raphson internally).
  n_iterations <- as.integer(engine_result$convergence$iterations)

  list(
    x_matrix          = x_matrix,
    base_weights      = base_weights,
    g_weights         = g_weights,
    crossproduct_inv  = crossproduct_inv,
    population_totals = population_totals,
    discrepancy       = discrepancy,
    lambda            = lambda,
    method            = method,
    cell_factors      = cell_factors,
    q_weights         = q_weights,
    converged         = converged,
    n_iterations      = n_iterations,
    bounds_scale      = bounds_scale
  )
}

# ---------------------------------------------------------------------------
# .validate_bounds() — validates the bounds argument for NR calibration
# ---------------------------------------------------------------------------

# Validates the bounds argument. Returns invisible(TRUE) on success.
#
# Arguments:
#   bounds      : user-supplied bounds — numeric length-2 c(L, U), or NULL
#   bounds_scale: character(1) — "multiplicative" or "absolute"
#   allow_null  : logical(1) — TRUE if NULL is an acceptable value
#
# Errors:
#   surveywts_error_bounds_invalid_calibration if:
#     - allow_null = FALSE and bounds is NULL
#     - bounds is non-NULL but not numeric length-2
#     - bounds contains NA or non-finite values
#     - bounds_scale = "multiplicative" and L >= 1 or U <= 1
#     - bounds_scale = "absolute" and L <= 0 or L >= U
#
# @keywords internal
# @noRd
.validate_bounds <- function(bounds, bounds_scale, allow_null) {
  if (is.null(bounds)) {
    if (!allow_null) {
      cli::cli_abort(
        c(
          "x" = "{.arg bounds} must be a numeric vector of length 2.",
          "i" = "Got {.code NULL}.",
          "v" = "Supply {.code bounds = c(L, U)} where {.code L < 1 < U}."
        ),
        class = "surveywts_error_bounds_invalid_calibration"
      )
    }
    return(invisible(TRUE))
  }

  if (!is.numeric(bounds)) {
    cls <- class(bounds)[[1L]]
    cli::cli_abort(
      c(
        "x" = "{.arg bounds} must be a numeric vector of length 2.",
        "i" = "Got {.cls {cls}}.",
        "v" = "Supply {.code bounds = c(L, U)} where {.code L < 1 < U}."
      ),
      class = "surveywts_error_bounds_invalid_calibration"
    )
  }

  if (length(bounds) != 2L) {
    cli::cli_abort(
      c(
        "x" = "{.arg bounds} must be a numeric vector of length 2.",
        "i" = "Got length {length(bounds)}.",
        "v" = "Supply {.code bounds = c(L, U)} where {.code L < 1 < U}."
      ),
      class = "surveywts_error_bounds_invalid_calibration"
    )
  }

  if (anyNA(bounds)) {
    cli::cli_abort(
      c(
        "x" = "{.arg bounds} must not contain {.code NA} values.",
        "i" = "Found {.code NA} in {.arg bounds}.",
        "v" = "Supply finite numeric values for {.code L} and {.code U}."
      ),
      class = "surveywts_error_bounds_invalid_calibration"
    )
  }

  if (!all(is.finite(bounds))) {
    cli::cli_abort(
      c(
        "x" = "{.arg bounds} must contain finite values.",
        "i" = "Got {.code c({bounds[[1L]]}, {bounds[[2L]]})}.",
        "v" = "Supply finite numeric values for {.code L} and {.code U}."
      ),
      class = "surveywts_error_bounds_invalid_calibration"
    )
  }

  L <- bounds[[1L]]
  U <- bounds[[2L]]

  if (identical(bounds_scale, "multiplicative")) {
    if (L >= 1) {
      cli::cli_abort(
        c(
          "x" = paste0(
            "For {.code bounds_scale = \"multiplicative\"}, the lower bound ",
            "{.code L} must be strictly less than 1."
          ),
          "i" = "Got {.code L = {L}}.",
          "v" = paste0(
            "Supply {.code bounds = c(L, U)} where {.code L < 1 < U}, ",
            "e.g. {.code c(0.5, 2)}."
          )
        ),
        class = "surveywts_error_bounds_invalid_calibration"
      )
    }
    if (U <= 1) {
      cli::cli_abort(
        c(
          "x" = paste0(
            "For {.code bounds_scale = \"multiplicative\"}, the upper bound ",
            "{.code U} must be strictly greater than 1."
          ),
          "i" = "Got {.code U = {U}}.",
          "v" = paste0(
            "Supply {.code bounds = c(L, U)} where {.code L < 1 < U}, ",
            "e.g. {.code c(0.5, 2)}."
          )
        ),
        class = "surveywts_error_bounds_invalid_calibration"
      )
    }
  } else if (identical(bounds_scale, "absolute")) {
    if (L <= 0) {
      cli::cli_abort(
        c(
          "x" = paste0(
            "For {.code bounds_scale = \"absolute\"}, the lower bound ",
            "{.code L} must be strictly positive."
          ),
          "i" = "Got {.code L = {L}}.",
          "v" = "Supply {.code bounds = c(L, U)} where {.code 0 < L < U}."
        ),
        class = "surveywts_error_bounds_invalid_calibration"
      )
    }
    if (L >= U) {
      cli::cli_abort(
        c(
          "x" = paste0(
            "For {.code bounds_scale = \"absolute\"}, the lower bound ",
            "{.code L} must be strictly less than the upper bound {.code U}."
          ),
          "i" = "Got {.code L = {L}}, {.code U = {U}}.",
          "v" = "Supply {.code bounds = c(L, U)} where {.code 0 < L < U}."
        ),
        class = "surveywts_error_bounds_invalid_calibration"
      )
    }
  }

  invisible(TRUE)
}

# ---------------------------------------------------------------------------
# .validate_unit_scale() — validates q-weights (unit_scale) argument
# ---------------------------------------------------------------------------

# Validates the unit_scale argument. Returns invisible(TRUE) on success.
#
# Arguments:
#   unit_scale : user-supplied unit_scale — numeric length-n, or NULL
#   n          : integer — expected length (nrow of data)
#
# Errors:
#   surveywts_error_unit_scale_invalid if:
#     - unit_scale is non-NULL but not numeric
#     - length(unit_scale) != n
#     - unit_scale contains NA
#     - unit_scale contains values <= 0
#
# @keywords internal
# @noRd
.validate_unit_scale <- function(unit_scale, n) {
  if (is.null(unit_scale)) {
    return(invisible(TRUE))
  }

  if (!is.numeric(unit_scale)) {
    cls <- class(unit_scale)[[1L]]
    cli::cli_abort(
      c(
        "x" = paste0(
          "{.arg unit_scale} must be a positive numeric vector or {.code NULL}."
        ),
        "i" = "Got {.cls {cls}}.",
        "v" = "Supply a positive numeric vector of length {n}."
      ),
      class = "surveywts_error_unit_scale_invalid"
    )
  }

  if (length(unit_scale) != n) {
    cli::cli_abort(
      c(
        "x" = paste0(
          "{.arg unit_scale} must have length equal to the number of ",
          "rows in {.arg data}."
        ),
        "i" = "Got length {length(unit_scale)} but expected {n}.",
        "v" = "Supply a positive numeric vector of length {n}."
      ),
      class = "surveywts_error_unit_scale_invalid"
    )
  }

  if (anyNA(unit_scale)) {
    n_na <- sum(is.na(unit_scale))
    cli::cli_abort(
      c(
        "x" = "{.arg unit_scale} must not contain {.code NA} values.",
        "i" = "Found {n_na} {.code NA} value{?s} in {.arg unit_scale}.",
        "v" = paste0(
          "Remove {.code NA}s or set {.arg unit_scale = NULL} to use ",
          "uniform q-weights."
        )
      ),
      class = "surveywts_error_unit_scale_invalid"
    )
  }

  if (any(unit_scale <= 0)) {
    n_nonpos <- sum(unit_scale <= 0)
    cli::cli_abort(
      c(
        "x" = "{.arg unit_scale} must contain only strictly positive values.",
        "i" = "Found {n_nonpos} non-positive value{?s} in {.arg unit_scale}.",
        "v" = "All q-weights must be > 0."
      ),
      class = "surveywts_error_unit_scale_invalid"
    )
  }

  invisible(TRUE)
}

# ---------------------------------------------------------------------------
# .make_calfun_linear() — linear / truncated-linear F-function
# ---------------------------------------------------------------------------

# Returns a calibration function object for the linear method.
# When L and U are NULL (default), produces unclamped linear: F(u) = 1 + u.
# When L and U are provided, produces truncated-linear (clamped at bounds).
#
# The returned list has two elements:
#   Fm1 : function(u) — F(u) - 1 (i.e., the calibration factor minus 1)
#   dF  : function(u) — F'(u) (derivative for Jacobian)
#
# For unclamped linear: Fm1(u) = u, dF(u) = 1 everywhere.
# For truncated linear with bounds c(L, U):
#   F(u) in [L, U]; Fm1(u) = F(u) - 1 clamped to [L-1, U-1]
#   dF(u) = 1 if u in [L-1, U-1], else 0
#
# Arguments:
#   L : numeric(1) or NULL — lower g-weight bound (e.g., 0.3 means g >= 0.3)
#   U : numeric(1) or NULL — upper g-weight bound (e.g., 3 means g <= 3)
#
# @keywords internal
# @noRd
.make_calfun_linear <- function(L = NULL, U = NULL) {
  if (is.null(L) || is.null(U)) {
    # Unclamped linear: F(u) = 1 + u, Fm1(u) = u, dF(u) = 1
    list(
      Fm1 = function(u) u,
      dF = function(u) rep(1, length(u))
    )
  } else {
    # Truncated linear: F(u) clamped to [L, U].
    # dF = 1 everywhere (matches survey::calfun.truncated) — the NR Jacobian
    # uses the unclamped derivative so the step direction is always defined.
    # Clamping in Fm1 creates residuals that drive subsequent iterations.
    lo <- L - 1
    hi <- U - 1
    list(
      Fm1 = function(u) pmax(lo, pmin(hi, u)),
      dF = function(u) rep(1, length(u))
    )
  }
}

# ---------------------------------------------------------------------------
# .make_calfun_logit() — logit F-function (Deville et al. 1993)
# ---------------------------------------------------------------------------

# Returns a calibration function object for the logit method.
# F(u) is the logit function bounded between L and U (open interval).
#
# Formula (Deville, Sarndal & Sautory 1993, §3):
#   A = (U - L) / ((1 - L) * (U - 1))
#   F(u) = (L(U-1) + U(1-L)exp(Au)) / (U - 1 + (1-L)exp(Au))
#
# At u = 0: F(0) = 1, so Fm1(0) = 0 (required for NR at lambda = 0).
# As u -> -Inf: F -> L. As u -> +Inf: F -> U.
#
# Derivative:
#   F'(u) = A * (F(u) - L) * (U - F(u)) / (U - L)
#
# Arguments:
#   L : numeric(1) — lower g-weight bound; must be < 1
#   U : numeric(1) — upper g-weight bound; must be > 1
#
# @keywords internal
# @noRd
.make_calfun_logit <- function(L, U) {
  A <- (U - L) / ((1 - L) * (U - 1))

  # Numerically stable evaluation.
  # F(u) = (L(U-1) + U(1-L)exp(Au)) / (U - 1 + (1-L)exp(Au))
  #
  # For large |Au|, exp(Au) overflows/underflows. Divide num & denom by
  # the dominant exponential term to keep ratios finite:
  #
  # When Au is large positive: divide by exp(Au)
  #   F = (L(U-1)exp(-Au) + U(1-L)) / ((U-1)exp(-Au) + (1-L)) -> U
  # When Au is large negative: exp(Au) -> 0, so
  #   F -> L(U-1)/(U-1) = L
  #   (standard formula works numerically for negative Au of moderate magnitude)
  #
  # Clamp to (L, U) as final guard.
  #
  # When L or U are length-n vectors (absolute-bounds path with per-unit
  # scaling), we subset them by the same logical index to avoid dimension
  # mismatch inside the large_pos and normal branches.
  .eval_f <- function(u) {
    au <- A * u
    f <- numeric(length(u))

    # Large positive au: use the exp(-au)-scaled form to avoid exp(au)=Inf
    large_pos <- au > 500
    if (any(large_pos)) {
      L_sub <- if (length(L) > 1L) L[large_pos] else L
      U_sub <- if (length(U) > 1L) U[large_pos] else U
      ena <- exp(-au[large_pos])  # exp(-au) underflows to 0 safely
      f[large_pos] <- (L_sub * (U_sub - 1) * ena + U_sub * (1 - L_sub)) /
        ((U_sub - 1) * ena + (1 - L_sub))
    }

    # Normal range (including large negative au where exp(au) underflows to 0)
    normal <- !large_pos
    if (any(normal)) {
      L_sub <- if (length(L) > 1L) L[normal] else L
      U_sub <- if (length(U) > 1L) U[normal] else U
      ea <- exp(au[normal])   # exp of negative / small number: finite
      f[normal] <- (L_sub * (U_sub - 1) + U_sub * (1 - L_sub) * ea) /
        (U_sub - 1 + (1 - L_sub) * ea)
    }

    # Clamp to (L, U) as a final numerical guard
    pmax(L, pmin(U, f))
  }

  Fm1 <- function(u) .eval_f(u) - 1

  dF <- function(u) {
    f <- .eval_f(u)
    A * (f - L) * (U - f) / (U - L)
  }

  list(Fm1 = Fm1, dF = dF)
}

# ---------------------------------------------------------------------------
# .make_calfun_raking() — multiplicative / raking F-function
# ---------------------------------------------------------------------------

# Returns a calibration function object for the raking (multiplicative) method.
# F(u) = exp(u), F'(u) = exp(u). Fm1(u) = exp(u) - 1.
#
# g-weights are strictly positive and unbounded above.
# For a two-way table, this reduces to classical IPF (Deville et al. 1993 §3).
#
# @keywords internal
# @noRd
.make_calfun_raking <- function() {
  list(
    Fm1 = function(u) exp(u) - 1,
    dF = function(u) exp(u)
  )
}

# ---------------------------------------------------------------------------
# .calibrate_nr_engine() — Newton-Raphson calibration solver
# ---------------------------------------------------------------------------

# Solves the calibration constraints using Newton-Raphson iteration.
# Calibrated weights satisfy: sum_k d_k * F(q_k * x_k' * lambda) * x_k = t_x
#
# Algorithm (Deville & Sarndal 1992, Deville et al. 1993 §11):
#   Initialize lambda = 0 (phi(0) = 0 since Fm1(0) = 0 for all calfun types)
#   Iterate:
#     u_k = q_k * x_k' * lambda                    [D1: q_weights scaling]
#     phi(lambda) = X' * (d * Fm1(u))
#     Jacobian = X' * diag(d * F'(u) * q) * X      [D2: q_weights in Jacobian]
#     misfit = discrepancy - phi(lambda)
#     lambda_new = lambda + solve(Jacobian, misfit)
#   Convergence: max(|misfit| / (1 + |population|)) < epsilon
#
# For the linear method (F(u) = 1+u), one step is exact.
# Step-halving guard: up to 20 halvings when non-finite g-weights appear.
# Step-halving also uses q_k scaling:
#   g_candidate = 1 + Fm1(q_k * x_k' * lambda_new) [D3: q_weights in halvings]
#
# Arguments:
#   x_matrix    : n x J numeric matrix — calibration model matrix
#   weights_vec : numeric length-n — base design weights (d_k > 0)
#   calfun      : list(Fm1, dF) — calibration function from .make_calfun_*()
#   population  : named numeric length-J — population totals in count scale
#   epsilon     : numeric(1) — convergence tolerance
#   maxit       : integer(1) — maximum iterations
#   q_weights   : numeric length-n or NULL — per-unit scale factors q_k > 0
#                 (Deville & Sarndal 1992 notation). NULL is equivalent to
#                 rep(1, n). Corresponds to variance = sigma2_k = 1/q_k in
#                 survey::calibrate().
#
# Returns: named list:
#   weights      : numeric length-n — calibrated weights
#   lambda       : numeric length-J — converged Lagrange multipliers
#   n_iterations : integer — number of iterations performed
#   converged    : logical — TRUE if converged within maxit
#
# Errors:
#   surveywts_error_calibration_singular_system — solve() fails
#   surveywts_error_calibration_not_converged — maxit reached
#
# @keywords internal
# @noRd
.calibrate_nr_engine <- function(
  x_matrix,
  weights_vec,
  calfun,
  population,
  epsilon = 1e-7,
  maxit = 50L,
  q_weights = NULL
) {
  J <- ncol(x_matrix)
  lambda <- rep(0, J)

  # Resolve q_weights: NULL => rep(1, n) so all downstream code is uniform
  if (is.null(q_weights)) {
    q_weights <- rep(1, nrow(x_matrix))
  }

  # Pre-compute HT totals: t_hat = X' * d
  t_hat <- drop(t(x_matrix) %*% weights_vec)
  discrepancy <- population - t_hat

  # Convergence check: max(|misfit| / (1 + |population|)) < epsilon
  is_converged <- function(misfit) {
    max(abs(misfit) / (1 + abs(population))) < epsilon
  }

  for (iter in seq_len(maxit)) {
    # D1: u_k = q_k * x_k' * lambda  (scaled linear predictor)
    u_vec <- q_weights * drop(x_matrix %*% lambda)

    # phi(lambda) = X' * (d * Fm1(u))
    fm1_vals <- calfun$Fm1(u_vec)
    phi <- drop(t(x_matrix) %*% (weights_vec * fm1_vals))

    # Residual: discrepancy - phi(lambda)
    misfit <- discrepancy - phi

    # D2: Jacobian = X' * diag(d * F'(u) * q) * X  (q_weights in Jacobian)
    df_vals <- calfun$dF(u_vec)
    jacobian <- t(x_matrix) %*% ((weights_vec * df_vals * q_weights) * x_matrix)

    # Newton step
    delta_lambda <- tryCatch(
      drop(solve(jacobian, misfit)),
      error = function(e) {
        cli::cli_abort(
          c(
            "x" = paste0(
              "The calibration Jacobian matrix is singular and cannot ",
              "be solved."
            ),
            "i" = paste0(
              "This typically indicates collinear calibration variables ",
              "or a rank-deficient model matrix."
            ),
            "v" = paste0(
              "Check that no two calibration variables are perfectly ",
              "correlated in the sample, and that all levels appear ",
              "in the data."
            )
          ),
          class = "surveywts_error_calibration_singular_system"
        )
      }
    )

    # D3: Step-halving uses q_weights in the g_candidate check
    step_size <- 1
    lambda_new <- lambda + step_size * delta_lambda
    g_candidate <- 1 + calfun$Fm1(q_weights * drop(x_matrix %*% lambda_new))
    n_halvings <- 0L
    while (any(!is.finite(g_candidate)) && n_halvings < 20L) {
      step_size <- step_size / 2
      lambda_new <- lambda + step_size * delta_lambda
      g_candidate <- 1 + calfun$Fm1(
        q_weights * drop(x_matrix %*% lambda_new)
      )
      n_halvings <- n_halvings + 1L
    }

    lambda <- lambda_new

    # Check convergence after updating lambda
    u_new <- q_weights * drop(x_matrix %*% lambda)
    fm1_new <- calfun$Fm1(u_new)
    phi_new <- drop(t(x_matrix) %*% (weights_vec * fm1_new))
    misfit_new <- discrepancy - phi_new

    if (is_converged(misfit_new)) {
      g_weights <- 1 + fm1_new
      return(list(
        weights = weights_vec * g_weights,
        lambda = lambda,
        n_iterations = as.integer(iter),
        converged = TRUE
      ))
    }
  }

  # Reached maxit without converging
  u_final <- q_weights * drop(x_matrix %*% lambda)
  fm1_final <- calfun$Fm1(u_final)
  phi_final <- drop(t(x_matrix) %*% (weights_vec * fm1_final))
  misfit_final <- discrepancy - phi_final
  max_rel_misfit <- round(
    max(abs(misfit_final) / (1 + abs(population))),
    6
  )
  cli::cli_abort(
    c(
      "x" = "Calibration did not converge after {maxit} iteration{?s}.",
      "i" = paste0(
        "The maximum relative misfit at termination was ",
        "{max_rel_misfit}."
      ),
      "v" = paste0(
        "Try increasing {.arg maxit}, relaxing {.arg epsilon}, ",
        "or widening the {.arg bounds}."
      )
    ),
    class = "surveywts_error_calibration_not_converged"
  )
}

# ---------------------------------------------------------------------------
# .validate_count_marginal_consistency()
# ---------------------------------------------------------------------------

# When type = "count", validates that all marginal vectors sum to the same
# population total N within 1e-3 tolerance. If any pair differs by > 1e-3,
# throws surveywts_error_population_totals_invalid.
#
# Arguments:
#   targets_a      : Format A named list (named vectors, already in count form)
#   variable_names : character vector of variable names
.validate_count_marginal_consistency <- function(targets_a, variable_names) {
  if (length(variable_names) < 2L) return(invisible(TRUE))

  sums <- vapply(variable_names, function(v) sum(targets_a[[v]]), numeric(1L))
  names(sums) <- variable_names

  ref_sum <- sums[[1L]]
  for (v in variable_names[-1L]) {
    diff <- abs(sums[[v]] - ref_sum)
    if (diff > 1e-3) {
      cli::cli_abort(
        c(
          "x" = paste0(
            "When {.code type = \"count\"}, all marginal vectors must sum ",
            "to the same population total N (within 1e-3 tolerance)."
          ),
          "i" = paste0(
            "Variable {.field {variable_names[[1L]]}} sums to ",
            "{ref_sum}; variable {.field {v}} sums to {sums[[v]]} ",
            "(difference: {round(diff, 4)})."
          ),
          "v" = paste0(
            "Ensure all entries in {.arg targets} refer to the same ",
            "population total."
          )
        ),
        class = "surveywts_error_population_totals_invalid"
      )
    }
  }
  invisible(TRUE)
}

# ---------------------------------------------------------------------------
# .to_svyrep() — convert survey_replicate / survey_nonprob to svyrep.design
# ---------------------------------------------------------------------------

# Convert a survey_replicate or survey_nonprob S7 object to a survey package
# svyrep.design object that svrep can consume.
# Shared by calibrate_to_survey() and calibrate_to_estimate().
#
# @keywords internal
# @noRd
.to_svyrep <- function(design) {
  wt_col   <- design@variables$weights
  rep_cols <- design@variables$repweights
  data_df  <- as.data.frame(design@data)

  pweights <- data_df[[wt_col]]
  repwts   <- as.matrix(data_df[, rep_cols, drop = FALSE])

  # Build a svyrep.design object. Suppress the "combined weights" warning
  # that fires when mean(repweights) << mean(sampling weights).
  suppressWarnings(
    survey::svrepdesign(
      data       = data_df,
      repweights = repwts,
      weights    = pweights,
      type       = design@variables$type %||% "bootstrap",
      scale      = design@variables$scale,
      rscales    = design@variables$rscales,
      mse        = isTRUE(design@variables$mse)
    )
  )
}

# ---------------------------------------------------------------------------
# .method_to_calfun() — map method string to survey calfun object
# ---------------------------------------------------------------------------

# Map method string to survey calfun object.
# Shared by calibrate_to_survey() and calibrate_to_estimate().
#
# @keywords internal
# @noRd
.method_to_calfun <- function(method) {
  switch(
    method,
    "rake"   = survey::cal.raking,
    "linear" = survey::cal.linear,
    "logit"  = survey::cal.logit,
    survey::cal.raking  # default
  )
}

# ---------------------------------------------------------------------------
# .throw_not_converged_zero_maxit() — error helper for maxit = 0 case
# ---------------------------------------------------------------------------

# Throws surveywts_error_calibration_not_converged when control$maxit == 0.
# Only caller: .anesrake_engine().
.throw_not_converged_zero_maxit <- function(control) {
  cli::cli_abort(
    c(
      "x" = "Raking did not converge after 0 iterations.",
      "i" = "Setting {.code control$maxit = 0} means no raking is attempted.",
      "v" = paste0(
        "Set {.code control$maxit} to a positive integer."
      )
    ),
    class = "surveywts_error_calibration_not_converged"
  )
}

# ---------------------------------------------------------------------------
# .anesrake_engine() — anesrake calibration engine
# ---------------------------------------------------------------------------

# Wraps the internal anesrake engine (.rake_anesrake()). Only caller:
# calibrate_rake(algorithm = "classic_ipf").
#
# Arguments:
#   data_df          : plain data.frame
#   weights_vec      : numeric vector (length = nrow(data_df)),
#                      all positive, no NAs
#   calibration_spec : list with $type = "anesrake", $variables, $total_n,
#                      $cap
#   control          : list with at least $maxit; anesrake defaults already
#                      applied by calibrate_rake()
#
# Returns: list(
#   weights     = <numeric vector of calibrated weights>,
#   convergence = list(converged, iterations, max_error, tolerance),
#   capping     = <list or NULL>
# )
# Throws surveywts_error_calibration_not_converged on failure.
.anesrake_engine <- function(data_df, weights_vec, calibration_spec, control) {
  # Handle maxit = 0: algorithm never runs
  if (isTRUE(control$maxit == 0L) || isTRUE(control$maxit == 0)) {
    .throw_not_converged_zero_maxit(control)
  }

  type <- calibration_spec$type
  vars_spec <- calibration_spec$variables

  # ---- Anesrake (via internal .rake_anesrake()) ----------------------------
  if (type == "anesrake") {
    var_names <- vapply(vars_spec, function(v) v$col, character(1))

    # Build named list of target vectors (proportions for anesrake)
    targets_list <- lapply(vars_spec, function(v) {
      tgt <- v$targets
      tgt / sum(tgt)  # anesrake expects proportions
    })
    names(targets_list) <- var_names

    # Ensure data columns are factors with correct levels
    for (v in vars_spec) {
      lvls <- names(v$targets)
      data_df[[v$col]] <- factor(data_df[[v$col]], levels = lvls)
    }

    # Create synthetic caseid
    data_df$.anesrake_id <- seq_len(nrow(data_df))

    # cap = NULL means no cap; use Inf so .rake_list()'s while loop never fires
    anesrake_cap <- calibration_spec$cap %||% Inf

    # When data is already calibrated, .rake_select_by_pct() throws
    # an error "No variables are off by more than ...". Catch that and treat
    # as already-calibrated.
    anesrake_error <- NULL
    result <- tryCatch(
      suppressWarnings(
        .rake_anesrake(
          inputter     = targets_list,
          dataframe    = data_df,
          caseid       = data_df$.anesrake_id,
          weightvec    = weights_vec,
          choosemethod = control$variable_select,
          cap          = anesrake_cap,
          pctlim       = control$improvement,
          iterate      = TRUE,
          maxit        = as.integer(control$maxit)
        )
      ),
        error = function(e) {
          if (grepl("No variables are off", conditionMessage(e),
                    ignore.case = TRUE)) {
            anesrake_error <<- "already_calibrated"
            NULL
          } else {
            stop(e) # nocov
          }
        }
      )

    # Already-calibrated: engine threw an error because no variables
    # exceeded the improvement threshold
    if (identical(anesrake_error, "already_calibrated")) {
      cli::cli_inform(
        c("i" = paste0(
          "Raking converged in 1 sweep: all variables already met their ",
          "margins. Weights were not adjusted."
        )),
        class = "surveywts_message_already_calibrated"
      )
      return(list(
        weights = weights_vec,
        convergence = list(
          converged  = TRUE,
          iterations = 1L,
          max_error  = 0,
          tolerance  = control$improvement
        ),
        capping = NULL
      ))
    }

    # .rake_anesrake()$converge is a character string:
    #   "Complete convergence was achieved" — fully converged
    #   "Results are stable, but do not perfectly match..." — partial,
    #     treated as converged (matches old vendored behaviour)
    #   Other strings (e.g. containing "Did Not Converge") — failure
    converged <- grepl(
      "Complete convergence|Results are stable",
      result$converge, ignore.case = TRUE
    )

    if (!converged) {
      cli::cli_abort(
        c(
          "x" = paste0(
            "Raking did not converge after ",
            "{control$maxit} full sweeps."
          ),
          "i" = paste0(
            "Internal raking engine reported: {result$converge}"
          ),
          "v" = paste0(
            "Increase {.code control$maxit} or relax ",
            "{.code control$improvement} in the {.arg control} list."
          )
        ),
        class = "surveywts_error_calibration_not_converged"
      )
    }

    # nocov start
    # Defensive: engine returns iterations = 0 only when it throws "No
    # variables are off", which is caught above and returns early. This branch
    # cannot be reached via the public API.
    if (result$iterations == 0L) {
      cli::cli_inform(
        c("i" = paste0(
          "Raking converged in 1 sweep: all variables already met their ",
          "margins. Weights were not adjusted."
        )),
        class = "surveywts_message_already_calibrated"
      )
    }
    # nocov end

    new_weights <- as.numeric(result$weightvec)
    precap <- as.numeric(result$precap_weightvec)
    internal_cap <- calibration_spec$cap

    capping_result <- if (is.null(internal_cap)) {
      NULL
    } else {
      list(
        applied        = any(precap > internal_cap),
        cap_threshold  = internal_cap,
        n_capped       = sum(precap > internal_cap),
        max_precap     = max(precap),
        mean_excess    = if (any(precap > internal_cap)) {
          mean(precap[precap > internal_cap] - internal_cap)
        } else {
          NA_real_
        },
        precap_weights = precap
      )
    }

    return(list(
      weights = new_weights,
      convergence = list(
        converged  = converged,
        iterations = as.integer(result$iterations),
        max_error  = 0,
        tolerance  = control$improvement
      ),
      capping = capping_result
    ))
  }
}
