# R/calibrate_linear.R
#
# calibrate_linear() — Linear (GREG) and truncated-linear calibration.
#
# Implements the Deville-Sarndal (1992) linear GREG calibration method.
# For bounded calibration (bounds != NULL), uses truncated-linear F-function
# with Newton-Raphson iteration via .calibrate_nr_engine().
#
# Uses shared helpers from:
#   R/utils.R          — .validate_wt_name(), .validate_reference_design(),
#                        .validate_weights(), .get_weight_vec(),
#                        .validate_calibration_variables(),
#                        .validate_population_marginals(),
#                        .compute_weight_stats(), .make_history_entry(),
#                        .make_weighted_df(), .update_survey_weights(),
#                        .check_input_class(), .get_history()
#   R/calibrate-utils.R — .parse_margins(), .validate_bounds(),
#                         .validate_unit_scale(), .make_calfun_linear(),
#                         .calibrate_nr_engine(),
#                         .build_calibration_provenance(),
#                         .validate_count_marginal_consistency()

#' Calibrate survey weights using linear (GREG) or truncated-linear method
#'
#' Adjusts survey weights so that the weighted marginal totals of calibration
#' variables match known population values using linear (GREG) estimation. Uses
#' `F(u) = 1 + u` which is exact in a single Newton step when `bounds = NULL`.
#' When `bounds = c(L, U)` is specified, switches to truncated-linear
#' calibration where g-weights are constrained to `[L, U]` using
#' Newton-Raphson iteration.
#'
#' @param data A `data.frame`, `weighted_df`, `survey_taylor`,
#'   `survey_nonprob`, or `survey_replicate`. Any other class -> error.
#'   When `data` is a `survey_replicate`, calibration is applied independently
#'   to every replicate weight column using the same population `targets`.
#'   Replicate columns that fail calibration are kept at their original values
#'   and reported via `surveywts_warning_replicate_calibration_failed`; the
#'   full-sample calibration still completes normally.
#' @param targets Named list of population marginal targets (Format A) or a
#'   long data frame with columns `variable`, `level`, `target` (Format B).
#'
#'   **Format A -- named list:**
#'   ```r
#'   list(
#'     age_group = c("18-34" = 0.30, "35-54" = 0.40, "55+" = 0.30),
#'     sex       = c("M" = 0.48, "F" = 0.52)
#'   )
#'   ```
#'
#'   **Format B -- long data frame:**
#'   ```r
#'   data.frame(
#'     variable = c("age_group", "age_group", "sex", "sex"),
#'     level    = c("18-34", "35-54", "M", "F"),
#'     target   = c(0.40, 0.60, 0.49, 0.51)
#'   )
#'   ```
#'
#'   Names must match column names in `data`. For `type = "prop"`: each
#'   element must sum to 1.0 within 1e-6. For `type = "count"`: all values
#'   must be strictly positive and all marginal sums must agree within 1e-3.
#' @param weights <[`tidy-select`][tidyselect::language]> Weight column name
#'   (bare name). `NULL` -> auto-detected from `weighted_df` attribute or
#'   survey object `@variables$weights`. For plain `data.frame` with
#'   `weights = NULL`, uniform starting weights (all 1) are used and
#'   `surveywts_warning_srs_no_weights` is emitted.
#' @param wt_name Character scalar. Name of the output weight column in the
#'   returned `weighted_df`. Default `"wts"`. Ignored when `data` is a survey
#'   object.
#' @param bounds `NULL` (default) or a length-2 numeric vector `c(L, U)`.
#'   `NULL`: plain unbounded linear calibration. G-weights are unconstrained
#'   and negative calibrated weights are possible. `c(L, U)`: truncated-linear
#'   calibration with g-weights constrained to the closed interval `[L, U]`.
#'   Interpretation depends on `bounds_scale`. Triggers
#'   `surveywts_error_bounds_invalid_calibration` on invalid values.
#' @param bounds_scale Character scalar. `"multiplicative"` (default): `bounds`
#'   constrain the g-weight ratio `g_k = w_k / d_k`. `"absolute"`: `bounds`
#'   constrain the final calibrated weight `w_k` directly. Matched with
#'   `rlang::arg_match()`. Ignored when `bounds = NULL`. For
#'   `"multiplicative"`: requires `L < 1 < U`. For `"absolute"`: requires
#'   `0 < L < U`.
#' @param unit_scale `NULL` (default) or a positive numeric vector of length
#'   `nrow(data)`. Per-unit scaling factors `q_k` for the calibration distance
#'   function (Deville & Sarndal 1992 eq. 2.2). `NULL` is equivalent to
#'   `rep(1, nrow(data))`. Triggers `surveywts_error_unit_scale_invalid` if
#'   not `NULL` and: not numeric, wrong length, contains `NA`, or contains
#'   non-positive values.
#' @param type Character scalar. `"prop"` (default): `targets` values are
#'   proportions summing to 1.0 per variable (within 1e-6 tolerance).
#'   `"count"`: `targets` values are population counts (all strictly positive).
#'   Matched with `rlang::arg_match()`.
#' @param control Named list of convergence parameters. Merged with defaults
#'   `list(maxit = 50, epsilon = 1e-7)`. Unrecognized keys trigger
#'   `surveywts_warning_control_param_ignored` per key. Valid keys: `maxit`,
#'   `epsilon`. For plain linear (`bounds = NULL`), `maxit` and `epsilon` are
#'   stored in the history entry but do not affect computation.
#' @param reference_design A `survey_taylor` object or `NULL`. When non-`NULL`,
#'   stored in the history entry with `targets_from_reference = TRUE`. Any
#'   non-`NULL` non-`survey_taylor` value triggers
#'   `surveywts_error_reference_design_not_taylor`.
#'
#' @return
#'   - `data.frame` or `weighted_df` input -> `weighted_df` with the calibrated
#'     weight column named by `wt_name` and a history entry appended.
#'   - `survey_taylor` input -> `survey_taylor` (class preserved); only
#'     `@variables$weights` (the weight column) and `@calibration` are
#'     modified. `@variables$ids`, `@variables$strata`, `@variables$fpc`,
#'     and the Taylor design structure are unchanged.
#'   - `survey_nonprob` input -> `survey_nonprob` (class preserved); weight
#'     column updated; history entry appended; `@calibration` slot populated.
#'   - `survey_replicate` input -> `survey_replicate` (class preserved);
#'     full-sample weight column updated; each replicate weight column
#'     calibrated independently. For `type = "count"` targets, each
#'     replicate's population totals are scaled: `rep_targets * (sum(rep_wt) /
#'     sum(base_wt))`. Failed replicates are kept at original values and
#'     reported via `surveywts_warning_replicate_calibration_failed`.
#'     `@calibration` slot populated including `replicate_converged`.
#'
#'   History entry `operation` field: `"calibrate_linear"`.
#'
#' @references
#'   Deville, J.-C. and Sarndal, C.-E. (1992). Calibration estimators in
#'   survey sampling. *Journal of the American Statistical Association*,
#'   87(418), 376--382.
#'   <http://links.jstor.org/sici?sici=0162-1459%28199206%2987%3A418%3C376%3ACEISS%3E2.0.CO%3B2-3>
#'
#'   Deville, J.-C., Sarndal, C.-E. and Sautory, O. (1993). Generalized
#'   raking procedures in survey sampling. *Journal of the American Statistical
#'   Association*, 88(423), 1013--1020. <https://www.jstor.org/stable/2290793>
#'
#' @examples
#' df <- data.frame(
#'   age_group = c("18-34", "35-54", "55+", "18-34", "35-54"),
#'   sex = c("M", "F", "M", "F", "M"),
#'   wt = c(1.2, 0.8, 1.1, 0.9, 1.0),
#'   stringsAsFactors = FALSE
#' )
#' targets <- list(
#'   age_group = c("18-34" = 0.40, "35-54" = 0.40, "55+" = 0.20),
#'   sex = c("M" = 0.50, "F" = 0.50)
#' )
#' result <- calibrate_linear(df, targets = targets, weights = wt)
#'
#' @family calibration
#' @export
calibrate_linear <- function(
  data,
  targets,
  weights = NULL,
  wt_name = "wts",
  bounds = NULL,
  bounds_scale = c("multiplicative", "absolute"),
  unit_scale = NULL,
  type = c("prop", "count"),
  control = list(),
  reference_design = NULL
) {
  # ---- Capture call before evaluation --------------------------------------
  call_str <- deparse(match.call())

  # ---- Argument matching ---------------------------------------------------
  bounds_scale <- rlang::arg_match(bounds_scale)
  type <- rlang::arg_match(type)
  weights_quo <- rlang::enquo(weights)

  # ---- Basic argument validation -------------------------------------------
  .validate_wt_name(wt_name)
  .validate_reference_design(reference_design)
  targets_from_reference <- !is.null(reference_design)

  # ---- Control key validation and merge with defaults ----------------------
  valid_keys <- c("maxit", "epsilon")
  unknown_keys <- setdiff(names(control), valid_keys)
  for (key in unknown_keys) {
    cli::cli_warn(
      c(
        "!" = paste0(
          "{.code control${.field {key}}} is not a recognized ",
          "{.fn calibrate_linear} control parameter and will be ignored."
        ),
        "i" = "Valid {.arg control} keys are: {.code maxit}, {.code epsilon}."
      ),
      class = "surveywts_warning_control_param_ignored"
    )
  }
  control <- control[intersect(names(control), valid_keys)]
  control <- utils::modifyList(list(maxit = 50L, epsilon = 1e-7), control)

  # ---- Validate bounds -----------------------------------------------------
  .validate_bounds(bounds, bounds_scale, allow_null = TRUE)

  # ---- 1. Input class check ------------------------------------------------
  .check_input_class(data)

  # ---- 2. Empty data check -------------------------------------------------
  data_df <- if (inherits(data, "data.frame")) as.data.frame(data) else data@data
  if (nrow(data_df) == 0L) {
    cli::cli_abort(
      c(
        "x" = "{.arg data} has 0 rows.",
        "i" = "This operation is undefined on empty data.",
        "v" = "Ensure {.arg data} has at least one row."
      ),
      class = "surveywts_error_empty_data"
    )
  }

  # ---- 3. Parse targets to Format A ----------------------------------------
  targets_a <- .parse_margins(targets)
  variable_names <- names(targets_a)

  # ---- 4. Determine weight column and handle SRS case ----------------------
  weight_col <- .get_weight_col_name(data, weights_quo)

  # For plain data.frame with weights = NULL: uniform weights (all 1) + warning
  is_plain_df <- inherits(data, "data.frame") && !inherits(data, "weighted_df")
  srs_assumption <- is_plain_df && rlang::quo_is_null(weights_quo)

  if (srs_assumption) {
    cli::cli_warn(
      c(
        "!" = paste0(
          "No {.arg weights} supplied for a plain {.cls data.frame}. ",
          "Using uniform starting weights (all 1)."
        ),
        "i" = paste0(
          "This assumes a simple random sample (SRS). Supply design ",
          "weights for unequal-probability designs."
        )
      ),
      class = "surveywts_warning_srs_no_weights"
    )
    data_df[[wt_name]] <- rep(1, nrow(data_df))
    weight_col <- wt_name
  }

  # Extract the plain data frame for all downstream operations
  plain_df <- if (inherits(data, "data.frame")) data_df else data@data

  # For data.frame inputs: sync plain_df with the (possibly newly added) weight col
  if (inherits(data, "data.frame") && !weight_col %in% names(plain_df)) {
    plain_df <- data_df
  }

  # ---- 5. Validate weights -------------------------------------------------
  .validate_weights(plain_df, weight_col)

  # ---- 6. Validate unit_scale ----------------------------------------------
  .validate_unit_scale(unit_scale, nrow(plain_df))

  # ---- 7. Check targets variable names are in data -------------------------
  missing_target_vars <- setdiff(variable_names, names(plain_df))
  if (length(missing_target_vars) > 0L) {
    var <- missing_target_vars[[1L]]
    cli::cli_abort(
      c(
        "x" = "Target variable {.field {var}} not found in {.arg data}.",
        "i" = "Names in {.arg targets} must match column names in {.arg data}.",
        "v" = paste0(
          "Check spelling: available columns are ",
          "{.and {.field {names(plain_df)}}}."
        )
      ),
      class = "surveywts_error_targets_variable_not_found"
    )
  }

  # ---- 8. Validate calibration variables (categorical, no NAs) -------------
  .validate_calibration_variables(plain_df, variable_names, "Calibration")

  # ---- 9. Validate population marginals ------------------------------------
  .validate_population_marginals(
    targets_a, variable_names, plain_df, type,
    target_name = "targets"
  )

  # ---- 9b. Validate count marginal consistency (cross-marginal sums) -------
  if (type == "count") {
    .validate_count_marginal_consistency(targets_a, variable_names)
  }

  # ---- 10. Extract starting weights ----------------------------------------
  weights_vec <- .get_weight_vec(data, weights_quo)

  # If SRS assumption was applied, override with the 1s vector
  if (srs_assumption) {
    weights_vec <- rep(1, nrow(plain_df))
  }

  before_stats <- .compute_weight_stats(weights_vec)

  # ---- 11. Convert proportions to counts for the engine --------------------
  total_w <- sum(weights_vec)
  if (type == "prop") {
    population_counts <- lapply(targets_a, function(p) p * total_w)
  } else {
    population_counts <- targets_a
  }

  # ---- 12. Build model matrix and population vector ------------------------
  # Build factor-encoded data frame for model.matrix
  # Use full dummy coding (-1 to drop intercept for individual variables,
  # but we need the intercept overall for the total constraint).
  # Each variable contributes k-1 dummy columns (reference level dropped).
  x_df <- plain_df
  for (v in variable_names) {
    lvls <- names(population_counts[[v]])
    x_df[[v]] <- factor(x_df[[v]], levels = lvls)
  }

  # Build the model formula: intercept + all variables with >=2 levels
  multi_level_vars <- variable_names[vapply(
    variable_names,
    function(v) length(population_counts[[v]]) >= 2L,
    logical(1L)
  )]

  if (length(multi_level_vars) == 0L) {
    # All variables have a single level: model matrix is intercept-only
    x_matrix <- matrix(
      1,
      nrow = nrow(plain_df),
      ncol = 1L,
      dimnames = list(NULL, "(Intercept)")
    )
  } else {
    fml <- stats::as.formula(
      paste("~", paste(multi_level_vars, collapse = " + "))
    )
    x_matrix <- stats::model.matrix(fml, data = x_df)
  }

  # Population totals vector: one entry per column in x_matrix.
  # The intercept total = N = sum of the first variable's count targets.
  # For type = "prop": population_counts[[v]] was scaled by total_w, so
  # sum(population_counts[[v]]) = total_w (unchanged).
  # For type = "count": N is the common marginal sum validated to be
  # consistent across all variables.
  N_pop <- sum(population_counts[[variable_names[[1L]]]])
  n_cols <- ncol(x_matrix)
  population_totals_vec <- stats::setNames(numeric(n_cols), colnames(x_matrix))
  population_totals_vec["(Intercept)"] <- N_pop
  for (v in multi_level_vars) {
    lvls <- names(population_counts[[v]])
    for (lev in lvls[-1L]) {
      col_nm <- paste0(v, lev)
      if (col_nm %in% names(population_totals_vec)) {
        population_totals_vec[col_nm] <- population_counts[[v]][[lev]]
      }
    }
  }

  # ---- 13. Resolve q_weights (unit_scale) ----------------------------------
  q_weights_vec <- if (!is.null(unit_scale)) {
    unit_scale
  } else {
    NULL
  }
  # q-weights used in T_x computation: default to 1 for all units
  q_for_engine <- if (!is.null(q_weights_vec)) q_weights_vec else rep(1, nrow(plain_df))

  # ---- 14. Build calibration function and run engine -----------------------
  # For absolute bounds: transform to multiplicative g-weight space
  # w_k = d_k * g_k, so absolute bounds [L_abs, U_abs] on w_k become
  # per-unit multiplicative bounds [L_abs / d_k, U_abs / d_k] on g_k.
  # This is equivalent to re-scaling the problem internally.
  #
  # Implementation approach: work in g-weight space by dividing base weights
  # by themselves (unit weights = 1), then converting back.
  # For absolute bounds we pass per-unit effective L/U to the calfun.
  #
  # Simpler for truncated-linear: the calfun clamps Fm1(u) to [L-1, U-1]
  # where L, U are in g-weight space. For absolute, we convert the input
  # weights to 1s, run the engine, then the resulting g-weights * original
  # weights give the final weights.

  if (!is.null(bounds) && identical(bounds_scale, "absolute")) {
    # D6: Absolute bounds -- per-unit g-weight bounds
    # Absolute bounds [L_abs, U_abs] constrain the final weight w_k directly.
    # The g-weight g_k = w_k / d_k, so the per-unit multiplicative bounds are:
    #   L_vec[k] = L_abs / d_k,  U_vec[k] = U_abs / d_k
    # These are passed as length-n vectors to .make_calfun_linear(), which
    # clamps Fm1(u_k) to [L_vec[k] - 1, U_vec[k] - 1] independently per unit.
    # The base weights (d_k) are passed unchanged; the calibration constraint
    # sum(d_k * F(u_k) * x_k) = pop is satisfied with the per-unit L/U.
    abs_L <- bounds[[1L]]
    abs_U <- bounds[[2L]]
    L_vec <- abs_L / weights_vec
    U_vec <- abs_U / weights_vec

    calfun <- .make_calfun_linear(L = L_vec, U = U_vec)

    engine_result_raw <- .calibrate_nr_engine(
      x_matrix    = x_matrix,
      weights_vec = weights_vec,
      calfun      = calfun,
      population  = population_totals_vec,
      epsilon     = control$epsilon,
      maxit       = as.integer(control$maxit),
      q_weights   = q_for_engine
    )

    new_weights <- engine_result_raw$weights

    engine_result <- list(
      weights    = new_weights,
      lambda     = engine_result_raw$lambda,
      n_iterations = engine_result_raw$n_iterations,
      converged  = engine_result_raw$converged,
      convergence = list(
        converged  = engine_result_raw$converged,
        iterations = engine_result_raw$n_iterations
      )
    )

  } else if (!is.null(bounds)) {
    # Multiplicative bounds: g-weights in [L, U]
    L <- bounds[[1L]]
    U <- bounds[[2L]]
    calfun <- .make_calfun_linear(L = L, U = U)

    engine_result_raw <- .calibrate_nr_engine(
      x_matrix    = x_matrix,
      weights_vec = weights_vec,
      calfun      = calfun,
      population  = population_totals_vec,
      epsilon     = control$epsilon,
      maxit       = as.integer(control$maxit),
      q_weights   = q_for_engine
    )

    new_weights <- engine_result_raw$weights

    engine_result <- list(
      weights    = new_weights,
      lambda     = engine_result_raw$lambda,
      n_iterations = engine_result_raw$n_iterations,
      converged  = engine_result_raw$converged,
      convergence = list(
        converged  = engine_result_raw$converged,
        iterations = engine_result_raw$n_iterations
      )
    )

  } else {
    # Plain unbounded linear: F(u) = 1 + u, exact in one step
    calfun <- .make_calfun_linear()

    engine_result_raw <- .calibrate_nr_engine(
      x_matrix    = x_matrix,
      weights_vec = weights_vec,
      calfun      = calfun,
      population  = population_totals_vec,
      epsilon     = control$epsilon,
      maxit       = as.integer(control$maxit),
      q_weights   = q_for_engine
    )

    new_weights <- engine_result_raw$weights

    engine_result <- list(
      weights    = new_weights,
      lambda     = engine_result_raw$lambda,
      n_iterations = engine_result_raw$n_iterations,
      converged  = engine_result_raw$converged,
      convergence = list(
        converged  = engine_result_raw$converged,
        iterations = engine_result_raw$n_iterations
      )
    )
  }

  # ---- 15. Warn on negative calibrated weights (plain linear only) ---------
  if (is.null(bounds)) {
    n_neg <- sum(new_weights < 0, na.rm = TRUE)
    if (n_neg > 0L) {
      cli::cli_warn(
        c(
          "!" = paste0(
            "Linear calibration produced {n_neg} ",
            "negative calibrated weight{?s}."
          ),
          "i" = "Negative weights can cause invalid variance estimates.",
          "i" = paste0(
            "Consider {.fn calibrate_logit} or {.fn calibrate_rake} ",
            "for bounded positive weights, or review population targets."
          )
        ),
        class = "surveywts_warning_negative_calibrated_weights"
      )
    }
  }

  # ---- 16. Build @calibration provenance (survey objects only) -------------
  is_survey_obj <- S7::S7_inherits(data, surveycore::survey_base)
  caldata <- NULL

  if (is_survey_obj) {
    method_str <- if (!is.null(bounds)) "truncated" else "linear"

    # For absolute bounds: base_weights for provenance are the original d_k
    provenance_base_weights <- weights_vec

    # .build_calibration_provenance() computes T_x = t(X) %*% (d * q * X).
    # q_weights_vec is NULL when unit_scale = NULL; pass q_for_engine (all-ones
    # vector) so the matrix multiply is well-defined. The @calibration$q_weights
    # slot is then overridden to store the user's unit_scale (NULL or a vector).
    caldata <- .build_calibration_provenance(
      engine_result     = engine_result,
      x_matrix          = x_matrix,
      base_weights      = provenance_base_weights,
      q_weights         = q_for_engine,
      population_totals = population_totals_vec,
      method            = method_str,
      lambda            = engine_result$lambda,
      cell_factors      = NULL,
      bounds_scale      = if (!is.null(bounds)) bounds_scale else NULL
    )
    # Override q_weights slot to store the user-supplied unit_scale (may be NULL)
    caldata$q_weights <- q_weights_vec

    # ---- Replicate loop (survey_replicate only) ----------------------------
    if (S7::S7_inherits(data, surveycore::survey_replicate)) {
      repwt_cols <- data@variables$repweights
      replicate_converged <- stats::setNames(
        rep(TRUE, length(repwt_cols)),
        repwt_cols
      )

      for (repwt_col in repwt_cols) {
        rep_wt <- data@data[[repwt_col]]

        # Scale population totals for this replicate
        rep_total_w <- sum(rep_wt)
        if (type == "prop") {
          rep_pop_counts <- lapply(targets_a, function(p) p * rep_total_w)
        } else {
          # type = "count": scale by sum(rep_wt) / sum(base_wt)
          scale_ratio <- rep_total_w / total_w
          rep_pop_counts <- lapply(population_counts, function(p) p * scale_ratio)
        }

        # Build rep population totals vector
        rep_pop_vec <- stats::setNames(numeric(n_cols), colnames(x_matrix))
        rep_pop_vec["(Intercept)"] <- rep_total_w
        for (v in multi_level_vars) {
          lvls <- names(rep_pop_counts[[v]])
          for (lev in lvls[-1L]) {
            col_nm <- paste0(v, lev)
            if (col_nm %in% names(rep_pop_vec)) {
              rep_pop_vec[col_nm] <- rep_pop_counts[[v]][[lev]]
            }
          }
        }

        failed <- tryCatch(
          {
            if (!is.null(bounds) && identical(bounds_scale, "absolute")) {
              # D6 replicate: per-unit bounds for this replicate's base weights.
              # Units with rep_wt = 0 (excluded from this bootstrap sample) get
              # unclamped bounds (L_k = -Inf, U_k = Inf) since they contribute
              # zero to all weighted totals and cannot be bounded meaningfully.
              nonzero <- rep_wt > 0
              rep_L_vec <- rep(-Inf, length(rep_wt))
              rep_U_vec <- rep(Inf, length(rep_wt))
              rep_L_vec[nonzero] <- abs_L / rep_wt[nonzero]
              rep_U_vec[nonzero] <- abs_U / rep_wt[nonzero]
              rep_calfun <- .make_calfun_linear(L = rep_L_vec, U = rep_U_vec)
              rep_engine <- .calibrate_nr_engine(
                x_matrix    = x_matrix,
                weights_vec = rep_wt,
                calfun      = rep_calfun,
                population  = rep_pop_vec,
                epsilon     = control$epsilon,
                maxit       = as.integer(control$maxit),
                q_weights   = q_for_engine
              )
              data@data[[repwt_col]] <- rep_engine$weights
            } else {
              rep_engine <- .calibrate_nr_engine(
                x_matrix    = x_matrix,
                weights_vec = rep_wt,
                calfun      = calfun,
                population  = rep_pop_vec,
                epsilon     = control$epsilon,
                maxit       = as.integer(control$maxit),
                q_weights   = q_for_engine
              )
              data@data[[repwt_col]] <- rep_engine$weights
            }
            FALSE
          },
          error = function(e) {
            col_nm <- repwt_col
            cli::cli_warn(
              c(
                "!" = paste0(
                  "Calibration failed for replicate weight column ",
                  "{.field {col_nm}}."
                ),
                "i" = "Reason: {conditionMessage(e)}",
                "i" = paste0(
                  "This replicate's weights are kept at their ",
                  "pre-calibration values. Variance estimates may be ",
                  "affected. Inspect {.code output@calibration$replicate_converged}."
                )
              ),
              class = "surveywts_warning_replicate_calibration_failed"
            )
            TRUE
          }
        )

        if (failed) {
          replicate_converged[[repwt_col]] <- FALSE
        }
      }

      caldata$replicate_converged <- replicate_converged
    }
  }

  # ---- 17. Compute after-stats and build history entry --------------------
  after_stats <- .compute_weight_stats(new_weights)
  current_history <- .get_history(data)

  history_entry <- .make_history_entry(
    step = length(current_history) + 1L,
    operation = "calibrate_linear",
    weight_col = if (inherits(data, "data.frame")) {
      wt_name
    } else {
      data@variables$weights
    },
    call_str = call_str,
    parameters = list(
      variables = variable_names,
      targets = targets_a,
      bounds = bounds,
      bounds_scale = if (!is.null(bounds)) bounds_scale else NULL,
      unit_scale = unit_scale,
      type = type,
      control = control,
      targets_from_reference = targets_from_reference,
      reference_design = reference_design
    ),
    before_stats = before_stats,
    after_stats  = after_stats,
    convergence  = engine_result$convergence
  )

  # ---- 18. Build output ----------------------------------------------------
  if (inherits(data, "data.frame")) {
    out_df <- plain_df
    out_df[[wt_name]] <- new_weights
    new_history <- c(current_history, list(history_entry))
    .make_weighted_df(out_df, wt_name, new_history)
  } else {
    .update_survey_weights(data, new_weights, history_entry, caldata = caldata)
  }
}
