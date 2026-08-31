# R/calibrate_rake.R
#
# calibrate_rake() — iterative proportional fitting to marginal targets.
#
# PR 4 changes vs PR 2:
#   - algorithm = "anesrake" renamed to "classic_ipf"
#   - algorithm = "survey" removed
#   - algorithm = "nr" added: Newton-Raphson via .calibrate_nr_engine()
#   - cap guard updated: surveywts_error_cap_not_supported_nr for "nr"
#   - control key sets updated for both algorithms
#
# All shared helpers live in R/utils.R.
# Calibration-family helpers live in R/calibrate-utils.R.

#' Fit weights using raking
#'
#' Iterative proportional fitting (raking) that adjusts survey weights to
#' match multiple marginal population totals simultaneously. Supports two
#' algorithms: the `"classic_ipf"` method (chi-square variable selection,
#' improvement-based convergence, ported from the anesrake package) and the
#' `"nr"` method (Newton-Raphson solver from Deville, Sarndal & Sautory 1993,
#' using the multiplicative `F(u) = exp(u)` function).
#'
#' @param data A `survey_taylor`, `survey_nonprob`, or `survey_replicate`. Any
#'   other class -> error. When `data` is a `survey_replicate`, raking is
#'   applied independently to every replicate weight column using the same
#'   population `targets`. Replicate columns that fail raking are kept at their
#'   original values and reported via a
#'   `surveywts_warning_replicate_calibration_failed` warning; the full-sample
#'   raking still completes normally.
#' @param targets Named list or data frame specifying population margin targets.
#'
#'   **Format A -- named list:**
#'   ```r
#'   list(
#'     age_group = c("18-34" = 0.28, "35-54" = 0.37, "55+" = 0.35),
#'     sex       = c("M" = 0.49, "F" = 0.51)
#'   )
#'   ```
#'   Each element can be a named numeric vector or a data frame with columns
#'   `level` and `target` (formats can be mixed within the list).
#'
#'   **Format B -- long data frame** with columns `variable`, `level`, `target`:
#'   ```r
#'   data.frame(
#'     variable = c("age_group", "age_group", "sex", "sex"),
#'     level    = c("18-34", "35-54", "M", "F"),
#'     target   = c(0.40, 0.60, 0.49, 0.51)
#'   )
#'   ```
#'   Format B is auto-detected and converted to Format A before use.
#' @param weights <[`tidy-select`][tidyselect::language]> Weight column name
#'   (bare name). Auto-detected from survey object `@variables$weights`.
#' @param wt_name `NULL` (default) or a `character(1)`. When `NULL`, raked
#'   weights overwrite the existing weight column in place. When a character
#'   string, a new column is added and `@variables$weights` updated.
#' @param type Character scalar. `"prop"` (default): `targets` values are
#'   proportions. `"count"`: `targets` values are counts.
#' @param algorithm Character scalar. `"classic_ipf"` (default): chi-square
#'   discrepancy variable selection with improvement-based convergence, as in
#'   the `anesrake` package. `"nr"`: Newton-Raphson solver using the
#'   multiplicative F-function `F(u) = exp(u)`, corresponding to
#'   Deville, Sarndal & Sautory (1993) generalized raking.
#' @param cap Numeric or `NULL`. Cap on the weight ratio `w / mean(w)`. Any
#'   weight exceeding `cap * mean(w)` is set to `cap * mean(w)`. Applied
#'   after each per-margin adjustment step (not post-hoc). `NULL` (default)
#'   means no cap. Not compatible with `algorithm = "nr"` (-> error).
#' @param control Named list of algorithm parameters. Merged with
#'   algorithm-specific defaults. Omitted keys retain their defaults.
#'
#'   **`algorithm = "classic_ipf"` defaults:**
#'   - `maxit = 1000`: maximum full sweeps
#'   - `improvement = 0.01`: percentage improvement convergence threshold
#'   - `pval = 0.05`: chi-square p-value threshold for variable selection
#'   - `min_cell_n = 0L`: minimum unweighted observations per cell (0 = no min)
#'   - `variable_select = "total"`: chi-square aggregation for ranking
#'     (`"total"`, `"max"`, or `"average"`)
#'
#'   **`algorithm = "nr"` defaults:**
#'   - `maxit = 50L`: maximum Newton-Raphson iterations
#'   - `epsilon = 1e-7`: maximum relative margin error convergence threshold
#'
#'   Passing `"classic_ipf"`-specific keys when `algorithm = "nr"` (or vice
#'   versa) triggers `surveywts_warning_control_param_ignored` per ignored key.
#'
#' @param reference_design A `survey_taylor` object or `NULL`. The probability
#'   survey from which `targets` were estimated. When non-`NULL`, stored in
#'   the history entry with `targets_from_reference = TRUE`. Any non-`NULL`
#'   non-`survey_taylor` value triggers an error.
#'
#' @returns
#'   - `survey_taylor` or `survey_nonprob` input -> same class as input
#'     (class is preserved); `@calibration` slot is populated
#'   - `survey_replicate` input -> `survey_replicate` (class preserved);
#'     `@calibration` slot is populated, including `replicate_converged`
#'
#'   The weight column in the output contains raked weights. A history entry
#'   with `operation = "calibrate_rake"` is appended to `weighting_history`.
#'   For `survey_replicate` inputs, each replicate weight column is also
#'   raked. Failed replicates retain their original weights and are recorded
#'   in `output@calibration$replicate_converged` as `FALSE`.
#'
#'   For `algorithm = "nr"`, `@calibration$lambda` contains the converged
#'   Lagrange multiplier vector. For `algorithm = "classic_ipf"`,
#'   `@calibration$lambda` is `NULL`.
#'
#' @details
#' **When to use.** Raking is the default calibration method. Choose it
#' when your targets are separate margins (for example sex, age group,
#' and region) and the weights must stay positive (Deville, Sarndal &
#' Sautory 1993). The weight ratio has no upper bound, so a margin far
#' from the sample can produce extreme weights; use `cap`, or
#' [trim_weights()] afterward, to limit them.
#'
#' @section Algorithm:
#' Both algorithms implement the raking calibration function
#' \eqn{F(u) = \exp(u)}, which keeps all calibrated weights strictly positive.
#'
#' **Classic IPF (`algorithm = "classic_ipf"`, the default)**
#'
#' At each sweep, variables are ranked by chi-square discrepancy between
#' weighted and target margins (controlled by `control$variable_select`,
#' default `"chi_square"`). Variables with any cell below
#' `control$min_cell_n` (default `5L`) unweighted observations are excluded
#' entirely; variables whose chi-square p-value exceeds `control$pval`
#' (default `0.01`) are skipped for that sweep. Within each selected
#' variable, weights are scaled by `target_k / weighted_k` for each level
#' `k`. If all variables pass or are excluded in sweep 1, a message is
#' emitted indicating the data is already calibrated.
#'
#' **Newton-Raphson (`algorithm = "nr"`)**
#'
#' Solves the calibration score equations via Newton-Raphson iteration.
#' Calibrated weights satisfy
#' \deqn{w_k = d_k \exp(x_k^T \hat{\lambda})}
#' where \eqn{\hat{\lambda}} is found by iterating on
#' \deqn{\sum_{k \in s} d_k \exp(x_k^T \lambda) x_k = X_U.}
#' Step-halving guards against non-finite g-weights at each iteration.
#'
#' @section Convergence:
#' **Classic IPF:** Terminates when the percentage improvement in total
#' chi-square discrepancy between successive sweeps falls below
#' `control$improvement` (default `0.01`%), or when `control$maxit`
#' (default `1000L`) full sweeps are completed.
#'
#' **Newton-Raphson:** Terminates when
#' \eqn{\max(|\text{misfit}| / (1 + |\text{population}|)) < \epsilon},
#' where \eqn{\epsilon} is `control$epsilon` (default `1e-7`), or when
#' `control$maxit` (default `50L`) iterations are completed.
#'
#' Calibration non-convergence raises an error.
#'
#' @references
#'   DeBell, M. and Krosnick, J.A. (2009). Computing Weights for American
#'   National Election Study Survey Data. ANES Technical Report series,
#'   no. nes012427. Ann Arbor, MI, and Palo Alto, CA: American National
#'   Election Studies.
#'
#'   Deville, J.-C. and Sarndal, C.-E. (1992). Calibration estimators in
#'   survey sampling. *Journal of the American Statistical Association*,
#'   87(418), 376--382.
#'
#'   Deville, J.-C., Sarndal, C.-E. and Sautory, O. (1993). Generalized
#'   raking procedures in survey sampling. *Journal of the American
#'   Statistical Association*, 88(423), 1013--1020.
#'
#'   Kott, P.S. (2003). An overview of calibration weighting. 2003 Joint
#'   Statistical Meetings — Section on Survey Research Methods.
#'
#' @seealso [calibrate()], [calibrate_linear()], [calibrate_logit()],
#'   [poststratify()]
#' @family calibration
#' @export
#'
#' @examples
#' ns_wave1_svy <- surveycore::as_survey_nonprob(ns_wave1, weights = weight)
#'
#' targets_a <- list(
#'   sex   = c("Male" = 0.49, "Female" = 0.51),
#'   age_f3 = c("18-34" = 0.30, "35-54" = 0.33, "55+" = 0.37)
#' )
#'
#' # Format A + classic_ipf (default) ------------------------------------
#' calibrate_rake(ns_wave1_svy, targets = targets_a)
#'
#' # Format A + Newton-Raphson algorithm ---------------------------------
#' calibrate_rake(ns_wave1_svy, targets = targets_a, algorithm = "nr")
#'
#' # Format B ------------------------------------------------------------
#' targets_b <- data.frame(
#'   variable = c("sex", "sex", "age_f3", "age_f3", "age_f3"),
#'   level    = c("Male", "Female", "18-34", "35-54", "55+"),
#'   target   = c(0.49, 0.51, 0.30, 0.33, 0.37)
#' )
#' calibrate_rake(ns_wave1_svy, targets = targets_b)
calibrate_rake <- function(
  data,
  targets,
  weights = NULL,
  wt_name = NULL,
  type = c("prop", "count"),
  algorithm = c("classic_ipf", "nr"),
  cap = NULL,
  control = list(),
  reference_design = NULL
) {
  # ---- Capture call and arguments before any evaluation --------------------
  call_str <- deparse(match.call())
  algorithm <- rlang::arg_match(algorithm)
  type <- rlang::arg_match(type)
  weights_quo <- rlang::enquo(weights)
  .validate_wt_name(wt_name)

  # ---- Validate reference_design -------------------------------------------
  .validate_reference_design(reference_design)
  targets_from_reference <- !is.null(reference_design)

  # ---- Cap + algorithm = "nr" guard (fail fast, before margin parsing) ----
  if (!is.null(cap) && algorithm == "nr") {
    cli::cli_abort(
      c(
        "x" = paste0(
          "{.arg cap} is not supported when ",
          "{.code algorithm = \"nr\"}."
        ),
        "i" = paste0(
          "The Newton-Raphson raking engine does not support ",
          "per-step weight capping."
        ),
        "v" = paste0(
          "Use {.code algorithm = \"classic_ipf\"} for raking with ",
          "a weight cap."
        )
      ),
      class = "surveywts_error_cap_not_supported_nr"
    )
  }

  # ---- Cap value validation --------------------------------------------------
  if (!is.null(cap)) {
    if (!is.numeric(cap) || length(cap) != 1L || !is.finite(cap) || cap <= 0) {
      cli::cli_abort(
        c(
          "x" = "{.arg cap} must be a positive finite numeric scalar.",
          "i" = "Got {.val {cap}}.",
          "v" = paste0(
            "Use a value > 0 (e.g., {.code cap = 5}) or ",
            "{.code cap = NULL} to disable capping."
          )
        ),
        class = "surveywts_error_cap_not_positive"
      )
    }
  }

  # ---- Apply algorithm-specific control defaults (before warning check) ----
  classic_ipf_defaults <- list(
    maxit = 1000L,
    improvement = 0.01,
    pval = 0.05,
    min_cell_n = 0L,
    variable_select = "total"
  )
  nr_defaults <- list(maxit = 50L, epsilon = 1e-7)

  # Coerce user-supplied maxit to integer (consistent with defaults)
  if (!is.null(control$maxit)) {
    control$maxit <- as.integer(control$maxit)
  }

  algorithm_defaults <- if (algorithm == "classic_ipf") {
    classic_ipf_defaults
  } else {
    nr_defaults
  }
  control_resolved <- utils::modifyList(algorithm_defaults, control)

  # ---- Warn on wrong-algorithm control params ------------------------------
  classic_ipf_only <- c("improvement", "pval", "min_cell_n", "variable_select")
  nr_only <- c("epsilon")

  if (algorithm == "nr") {
    for (param in intersect(names(control), classic_ipf_only)) {
      cli::cli_warn(
        c(
          "!" = paste0(
            "{.code control${.field {param}}} is not used when ",
            "{.code algorithm = {.val {algorithm}}} and will be ignored."
          ),
          "i" = paste0(
            "For {.code algorithm = \"classic_ipf\"}, valid {.arg control} ",
            "keys are: {.code maxit}, {.code improvement}, {.code pval}, ",
            "{.code min_cell_n}, {.code variable_select}."
          ),
          "i" = paste0(
            "For {.code algorithm = \"nr\"}, valid {.arg control} ",
            "keys are: {.code maxit}, {.code epsilon}."
          )
        ),
        class = "surveywts_warning_control_param_ignored"
      )
    }
  } else {
    for (param in intersect(names(control), nr_only)) {
      cli::cli_warn(
        c(
          "!" = paste0(
            "{.code control${.field {param}}} is not used when ",
            "{.code algorithm = {.val {algorithm}}} and will be ignored."
          ),
          "i" = paste0(
            "For {.code algorithm = \"classic_ipf\"}, valid {.arg control} ",
            "keys are: {.code maxit}, {.code improvement}, {.code pval}, ",
            "{.code min_cell_n}, {.code variable_select}."
          ),
          "i" = paste0(
            "For {.code algorithm = \"nr\"}, valid {.arg control} ",
            "keys are: {.code maxit}, {.code epsilon}."
          )
        ),
        class = "surveywts_warning_control_param_ignored"
      )
    }
  }

  # ---- 1. Input class check -----------------------------------------------
  .check_input_class(data)

  # ---- 2. Empty data check ------------------------------------------------
  data_df <- data@data
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

  # ---- 3. Parse and normalize targets to Format A -------------------------
  targets_a <- .parse_margins(targets)

  # ---- 4. Weight column name and handling ---------------------------------
  weight_col <- .get_weight_col_name(data, weights_quo)
  plain_df <- data_df

  .validate_weights(plain_df, weight_col)

  # ---- 5. Validate targets variables exist in data ------------------------
  target_var_names <- names(targets_a)
  for (var in target_var_names) {
    if (!var %in% names(plain_df)) {
      cli::cli_abort(
        c(
          "x" = "Raking variable {.field {var}} not found in {.arg data}.",
          "i" = paste0(
            "Check that all variable names in {.arg targets} exist as ",
            "columns in {.arg data}."
          )
        ),
        class = "surveywts_error_targets_variable_not_found"
      )
    }
  }

  # ---- 6. Validate margin variables (categorical, no NAs) -----------------
  .validate_calibration_variables(plain_df, target_var_names, "Raking")

  # ---- 7. Validate population marginals -----------------------------------
  .validate_population_marginals(
    targets_a,
    target_var_names,
    plain_df,
    type,
    target_name = "targets"
  )

  # ---- 7b. Validate count marginal consistency ----------------------------
  if (type == "count") {
    .validate_count_marginal_consistency(targets_a, target_var_names)
  }

  # ---- 8. Extract starting weights and compute before-stats ---------------
  weights_vec <- .get_weight_vec(data, weights_quo)
  before_stats <- .compute_weight_stats(weights_vec)

  # Convert proportions to counts for the engine
  total_w <- sum(weights_vec)
  if (type == "prop") {
    targets_counts <- lapply(targets_a, function(m) m * total_w)
  } else {
    targets_counts <- targets_a
  }

  # ---- 9. Build calibration spec and run engine ---------------------------
  vars_spec <- lapply(target_var_names, function(v) {
    list(col = v, targets = targets_counts[[v]])
  })

  if (algorithm == "classic_ipf") {
    # --- classic_ipf path: anesrake engine via .anesrake_engine() ----------
    engine_method <- "anesrake"

    calibration_spec <- list(
      type = engine_method,
      variables = vars_spec,
      total_n = nrow(plain_df),
      cap = cap
    )

    engine_result <- .anesrake_engine(
      data_df = plain_df,
      weights_vec = weights_vec,
      calibration_spec = calibration_spec,
      control = control_resolved
    )

    new_weights <- engine_result$weights
    convergence <- engine_result$convergence
    nr_lambda <- NULL
  } else {
    # --- nr path: Newton-Raphson engine via .calibrate_nr_engine() ----------
    # Build treatment-contrast model matrix (same as calibrate_linear)
    x_df_nr <- plain_df
    for (v in vars_spec) {
      col_name <- v$col
      lvls <- names(v$targets)
      x_df_nr[[col_name]] <- factor(x_df_nr[[col_name]], levels = lvls)
    }
    fml_vars_nr <- target_var_names[vapply(
      vars_spec,
      function(v) length(v$targets) >= 2L,
      logical(1L)
    )]
    if (length(fml_vars_nr) == 0L) {
      x_matrix_nr <- matrix(
        1,
        nrow = nrow(plain_df),
        ncol = 1L,
        dimnames = list(NULL, "(Intercept)")
      )
    } else {
      fml_nr <- stats::as.formula(
        paste("~", paste(fml_vars_nr, collapse = " + "))
      )
      x_matrix_nr <- stats::model.matrix(fml_nr, data = x_df_nr)
    }

    # Population totals in count scale (J-vector matching x_matrix columns).
    # Intercept constraint = target total N.
    # For type = "prop": targets_counts sum to total_w, so N = total_w.
    # For type = "count": N = sum of any one margin's targets (all equal after
    #   .validate_count_marginal_consistency()). Use the first variable's sum.
    n_cols_nr <- ncol(x_matrix_nr)
    pop_totals_nr <- stats::setNames(
      numeric(n_cols_nr),
      colnames(x_matrix_nr)
    )
    intercept_total_nr <- sum(targets_counts[[target_var_names[[1L]]]])
    pop_totals_nr["(Intercept)"] <- intercept_total_nr
    for (v in vars_spec) {
      if (length(v$targets) < 2L) {
        next
      }
      col_name <- v$col
      lvls <- names(v$targets)
      for (lev in lvls[-1L]) {
        col_nm <- paste0(col_name, lev)
        if (col_nm %in% names(pop_totals_nr)) {
          pop_totals_nr[col_nm] <- v$targets[[lev]]
        }
      }
    }

    calfun_nr <- .make_calfun_raking()
    nr_result <- .calibrate_nr_engine(
      x_matrix = x_matrix_nr,
      weights_vec = weights_vec,
      calfun = calfun_nr,
      population = pop_totals_nr,
      epsilon = control_resolved$epsilon,
      maxit = control_resolved$maxit
    )

    new_weights <- unname(nr_result$weights)
    nr_lambda <- nr_result$lambda
    convergence <- list(
      converged = nr_result$converged,
      iterations = nr_result$n_iterations,
      max_error = NA_real_,
      tolerance = control_resolved$epsilon
    )

    # Post-hoc renormalize to enforce exact weight sum conservation against
    # floating-point residuals from the NR loop (spec §6).
    # For type = "prop": sum(w_cal) should equal total_w (sum of design wts).
    # For type = "count": sum(w_cal) should equal target N.
    nr_target_total <- intercept_total_nr
    new_weights <- new_weights * (nr_target_total / sum(new_weights))
  }

  # ---- 10. Build x_matrix and calibration provenance (survey objects only) -
  # x_matrix: treatment-contrast model matrix (intercept + k-1 dummies per
  # factor), same parameterization as calibrate_linear(). method = "raking".
  is_survey_obj <- S7::S7_inherits(data, surveycore::survey_base)
  caldata <- NULL

  if (is_survey_obj) {
    x_df <- plain_df
    for (v in vars_spec) {
      col_name <- v$col
      lvls <- names(v$targets)
      x_df[[col_name]] <- factor(x_df[[col_name]], levels = lvls)
    }
    fml_vars_rake <- target_var_names[vapply(
      vars_spec,
      function(v) length(v$targets) >= 2L,
      logical(1L)
    )]
    if (length(fml_vars_rake) == 0L) {
      x_matrix <- matrix(
        1,
        nrow = nrow(plain_df),
        ncol = 1L,
        dimnames = list(NULL, "(Intercept)")
      )
    } else {
      fml_rake <- stats::as.formula(
        paste("~", paste(fml_vars_rake, collapse = " + "))
      )
      x_matrix <- stats::model.matrix(fml_rake, data = x_df)
    }

    # Population totals in count scale (J-vector matching x_matrix columns).
    # Intercept = target total N (same as intercept_total_nr for "nr" path;
    # for "classic_ipf", total_w is correct since all targets_counts sum to it).
    n_cols <- ncol(x_matrix)
    pop_totals_rake <- stats::setNames(numeric(n_cols), colnames(x_matrix))
    intercept_total_rake <- sum(targets_counts[[target_var_names[[1L]]]])
    pop_totals_rake["(Intercept)"] <- intercept_total_rake
    for (v in vars_spec) {
      if (length(v$targets) < 2L) {
        next
      }
      col_name <- v$col
      lvls <- names(v$targets)
      for (lev in lvls[-1L]) {
        col_nm <- paste0(col_name, lev)
        if (col_nm %in% names(pop_totals_rake)) {
          pop_totals_rake[col_nm] <- v$targets[[lev]]
        }
      }
    }

    q_weights <- rep(1, nrow(plain_df))

    # For "nr": pass the converged lambda explicitly; crossproduct_inv computed
    # in .build_calibration_provenance() but spec says NULL for NR — override.
    # For "classic_ipf": lambda = NULL (not analytically solved).
    caldata <- .build_calibration_provenance(
      engine_result = .engine_result_for_caldata(
        new_weights,
        convergence
      ),
      x_matrix = x_matrix,
      base_weights = weights_vec,
      q_weights = q_weights,
      population_totals = pop_totals_rake,
      method = "raking",
      lambda = nr_lambda,
      cell_factors = NULL
    )

    # NR: crossproduct_inv is NULL per spec (not stored for raking NR)
    if (algorithm == "nr") {
      caldata$crossproduct_inv <- NULL
    }

    # ---- Replicate loop (survey_replicate only) ----------------------------
    if (S7::S7_inherits(data, surveycore::survey_replicate)) {
      repwt_cols <- data@variables$repweights
      replicate_converged <- stats::setNames(
        rep(TRUE, length(repwt_cols)),
        repwt_cols
      )

      for (repwt_col in repwt_cols) {
        rep_wt <- data@data[[repwt_col]]

        # Scale population counts to this replicate's own weight total
        rep_total_w <- sum(rep_wt)
        if (type == "prop") {
          rep_targets_counts <- lapply(targets_a, function(m) m * rep_total_w)
        } else {
          # For type = "count": scale target totals by replicate weight ratio
          rep_scale <- rep_total_w / total_w
          rep_targets_counts <- lapply(targets_counts, function(m) {
            m * rep_scale
          })
        }
        rep_vars_spec <- lapply(target_var_names, function(v) {
          list(col = v, targets = rep_targets_counts[[v]])
        })

        failed <- tryCatch(
          {
            if (algorithm == "classic_ipf") {
              rep_cal_spec <- list(
                type = "anesrake",
                variables = rep_vars_spec,
                total_n = nrow(plain_df),
                cap = cap
              )
              rep_engine <- .anesrake_engine(
                data_df = plain_df,
                weights_vec = rep_wt,
                calibration_spec = rep_cal_spec,
                control = control_resolved
              )
              data@data[[repwt_col]] <- rep_engine$weights
            } else {
              # "nr": build rep pop_totals then call .calibrate_nr_engine()
              # Intercept = target total for this replicate = sum of any margin.
              n_cols_rep <- ncol(x_matrix)
              pop_totals_rep <- stats::setNames(
                numeric(n_cols_rep),
                colnames(x_matrix)
              )
              rep_intercept <- sum(
                rep_targets_counts[[target_var_names[[1L]]]]
              )
              pop_totals_rep["(Intercept)"] <- rep_intercept
              for (v in rep_vars_spec) {
                if (length(v$targets) < 2L) {
                  next
                }
                col_name <- v$col
                lvls <- names(v$targets)
                for (lev in lvls[-1L]) {
                  col_nm <- paste0(col_name, lev)
                  if (col_nm %in% names(pop_totals_rep)) {
                    pop_totals_rep[col_nm] <- v$targets[[lev]]
                  }
                }
              }
              rep_nr <- .calibrate_nr_engine(
                x_matrix = x_matrix,
                weights_vec = rep_wt,
                calfun = .make_calfun_raking(),
                population = pop_totals_rep,
                epsilon = control_resolved$epsilon,
                maxit = control_resolved$maxit
              )
              data@data[[repwt_col]] <- rep_nr$weights
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
                  "affected. Inspect ",
                  "{.code output@calibration$replicate_converged}."
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

  # ---- 11. Compute after-stats and build history entry --------------------
  after_stats <- .compute_weight_stats(new_weights)
  current_history <- .get_history(data)

  history_entry <- .make_history_entry(
    step = length(current_history) + 1L,
    operation = "calibrate_rake",
    weight_col = if (is.null(wt_name)) data@variables$weights else wt_name,
    call_str = call_str,
    parameters = list(
      variables = target_var_names,
      targets = targets_a, # always stored as Format A per spec §VII
      type = type,
      algorithm = algorithm,
      cap = cap,
      control = control_resolved,
      targets_from_reference = targets_from_reference,
      reference_design = reference_design
    ),
    before_stats = before_stats,
    after_stats = after_stats,
    convergence = convergence
  )

  # ---- 12. Build output ---------------------------------------------------
  .update_survey_weights(
    data,
    new_weights,
    history_entry,
    wt_name = wt_name,
    caldata = caldata
  )
}

# ---------------------------------------------------------------------------
# Internal helper: build a minimal engine_result for .build_calibration_provenance
# ---------------------------------------------------------------------------
# Wraps calibrated weights + convergence list into the format expected by
# .build_calibration_provenance(). Used for both classic_ipf and nr paths.
#
# @keywords internal
# @noRd
.engine_result_for_caldata <- function(new_weights, convergence) {
  list(
    weights = new_weights,
    convergence = convergence
  )
}

# ============================================================================
# Anesrake engine — internal helpers ported from the anesrake R package
#
# Algorithm and logic ported from:
#   Pasek, Josh (with help from Jon Krosnick and some code from Alex Tahk
#   and others). anesrake: ANES Raking Implementation.
#   https://CRAN.R-project.org/package=anesrake
#
# Methodology:
#   DeBell, Matthew, and Jon A. Krosnick. 2009. "Computing Weights for
#   American National Election Study Survey Data." ANES Technical Report
#   nes012427. https://electionstudies.org/
#
# Changes from original: only code paths reachable via calibrate_rake() are
# retained; .rake_list() captures precap_weightvec before each capping step.
# ============================================================================

.rake_discrep <- function(datavec, targetvec, weightvec) {
  dat <- sapply(names(targetvec), function(x) {
    sum(weightvec[datavec == x & !is.na(datavec)]) /
      sum(weightvec[!is.na(datavec)])
  })
  targetvec - dat
}

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
      warning(
        "Raking Algorithm Did Not Converge, Results May Be Highly Inconsistent"
      )
      diferrold <- 0
      pop <- 2
      converge <- paste("No convergence in", maxit, "iterations")
    }
  }
  # nocov start
  # Partial convergence: loop exited because improvement stalled, not because
  # full convergence was reached. Reachable in principle but not triggered by
  # current tests; the non-convergence path (g > maxit) is tested instead.
  if (diferr > 0.001) {
    warning(paste(
      "Raking algorithm achieved only partial convergence, please check the results to ensure that sufficient convergence was achieved.  Average change in weight per case is",
      diferr / sum(weightvec)
    ))
    warning(
      "Results are stable, but do not perfectly match population marginals"
    )
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
    weightvec = weightvec,
    caseid = caseid,
    iterations = g,
    nonconvergence = diferr,
    converge = converge,
    varsused = names(inputter),
    targets = inputter,
    dataframe = dataframe,
    prevec = prevec,
    precap_weightvec = precap_weightvec
  )
}

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
  weightvec <- weightvec / mean(weightvec, na.rm = TRUE)
  prevec <- weightvec

  discrep1 <- .rake_find_discrepancies(
    inputter,
    dataframe,
    weightvec,
    choosemethod
  )
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
        inputter,
        pctlim,
        tostop = 0
      )
      adders <- addtotowers[!(names(addtotowers) %in% names(towers))]
      tow2 <- c(towers, adders)
      towersx <- towers
      towers <- tow2
      if (
        sum(as.numeric(names(towersx) %in% names(towers))) == length(towers)
      ) {
        ww <- 1
      }
      # nocov start
      # Re-raking triggered when a previously on-target variable falls off
      # after raking others in. Reachable but not triggered by current tests.
      if (
        sum(as.numeric(names(towersx) %in% names(towers))) != length(towers)
      ) {
        ranweight <- .rake_list(
          towers,
          mat,
          caseid,
          weightvec,
          cap,
          maxit,
          convcrit
        )
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
    weightvec = weightout,
    caseid = caseid,
    varsused = names(towers),
    choosemethod = choosemethod,
    converge = ranweight$converge,
    nonconvergence = ranweight$nonconvergence,
    targets = inputter,
    dataframe = dataframe,
    iterations = iterations,
    prevec = prevec,
    precap_weightvec = ranweight$precap_weightvec
  )
}
