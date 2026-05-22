# R/nonresponse.R
#
# adjust_nonresponse() — weighting-class, propensity-cell, and propensity
# nonresponse adjustment. Redistributes nonrespondent weights to respondents
# within cells (weighting-class / propensity-cell) or applies individual IPW
# (propensity). Returns all rows; nonrespondent weights = 0.
#
# redistribute_weights() — general-purpose weight redistribution primitive.
#
# No private helpers. Cell logic is inline. All shared helpers live in utils.R.

#' Adjust survey weights for unit nonresponse
#'
#' Redistributes the weights of nonrespondents to respondents within weighting
#' classes defined by `by`. All rows (respondents and nonrespondents) are
#' returned; nonrespondent weights are set to 0 and respondent weights are
#' adjusted upward to conserve the total weight within each cell.
#'
#' The adjustment formula within each cell `h` is:
#'
#' \deqn{w_{i,new} = w_i \times \frac{\sum w_h}{\sum w_{h,resp}}}
#'
#' where \eqn{\sum w_h} is the sum of all weights (respondents + nonrespondents)
#' in cell `h` and \eqn{\sum w_{h,resp}} is the sum of respondent weights only.
#'
#' @param data A `data.frame`, `weighted_df`, `survey_taylor`, or
#'   `survey_nonprob`. Must include BOTH respondents and nonrespondents.
#'   `survey_replicate` -> error. Any other class -> error.
#' @param response_status Bare name (NSE). Binary response indicator column.
#'   Must be `logical` or integer `0`/`1`. `1` / `TRUE` = respondent.
#' @param weights Bare name (NSE). Weight column. `NULL` -> auto-detected from
#'   `weighted_df` attribute or survey object `@variables$weights`. For plain
#'   `data.frame` with `weights = NULL`, uniform starting weights are used.
#' @param by <[`tidy-select`][tidyselect::language]> Weighting class variables.
#'   Redistribution is performed within each cell defined by the joint
#'   combination of these variables. `NULL` -> global redistribution across
#'   all rows.
#' @param wt_name Character scalar. Name of the output weight column in the
#'   returned `weighted_df`. Default `"wts"`. Ignored when `data` is a survey
#'   object (`survey_taylor` or `survey_nonprob`).
#' @param method Character scalar. Adjustment method. One of
#'   `"weighting-class"` (default), `"propensity-cell"`, or `"propensity"`.
#'   - `"weighting-class"`: cells are defined by `by` groups; adjustment
#'     factors are applied cell-by-cell.
#'   - `"propensity-cell"`: fits a logistic response propensity model via
#'     `formula`, bins scores into `control$n_cells` quantile cells, then
#'     applies cell-level adjustments.
#'   - `"propensity"`: fits a logistic response propensity model via `formula`
#'     and applies individual-level inverse-probability weights
#'     (`weight_i / propensity_i`) to each respondent. Requires `formula`.
#' @param formula A one-sided formula (e.g., `~ age_group + sex`) used for
#'   propensity score estimation when `method = "propensity-cell"` or
#'   `method = "propensity"`. Required for `"propensity"`. All variables must
#'   be present in `data` with no `NA` values.
#' @param control Named list of control parameters. Merged with defaults
#'   `list(min_cell = 20, max_adjust = 2.0, n_cells = 5)`.
#'   - `min_cell`: warn when a cell has fewer than this many respondents
#'     (default 20, per NAEP methodology). Used only for `"propensity-cell"`.
#'   - `max_adjust`: warn when the nonresponse adjustment factor exceeds
#'     this value (default 5.0). For `"propensity-cell"`, the cell-level
#'     factor; for `"propensity"`, the individual IPW ratio relative to the
#'     mean respondent weight.
#'   - `n_cells`: number of propensity score cells (default 5). Must be a whole
#'     number >= 2. Used only when `method = "propensity-cell"`.
#'   Either `min_cell` or `max_adjust` condition alone triggers the warning.
#'
#' @return
#'   All rows (respondents and nonrespondents) are returned. Nonrespondent
#'   weights are set to 0; respondent weights are adjusted upward to conserve
#'   the total weight within each cell.
#'
#'   - `data.frame` or `weighted_df` input -> `weighted_df`
#'   - `survey_nonprob` input -> `survey_nonprob` (same class)
#'   - `survey_taylor` input -> `survey_taylor` (same class; respondent
#'     rows only, because `survey_taylor` does not support zero weights)
#'
#'   A history entry with `operation = "nonresponse_weighting_class"` (for
#'   `method = "weighting-class"`), `operation = "nonresponse_propensity_cell"`
#'   (for `method = "propensity-cell"`), or `operation = "nonresponse_propensity"`
#'   (for `method = "propensity"`) is appended to `weighting_history`.
#'
#' @details
#'   Zero-weight observations are retained for design-based variance estimation.
#'   Survey estimation functions (e.g., [survey::svymean()]) handle zero
#'   weights correctly -- zero-weight units are excluded from point estimates
#'   but included in the design structure for variance estimation. For manual
#'   calculations, use `w[w > 0]` to exclude nonrespondents.
#'
#'   Diagnostic functions ([effective_sample_size()], [weight_variability()],
#'   [summarize_weights()]) automatically filter to positive weights before
#'   computing statistics.
#'
#'   Re-calibrating post-nonresponse data requires filtering to respondents
#'   first, because [calibrate()], [rake()], and [poststratify()] reject
#'   zero weights.
#'
#'   **Propensity-cell method:** A logistic regression is fitted via
#'   [stats::glm()] with `family = binomial`. GLM convergence warnings (e.g.,
#'   fitted probabilities numerically 0 or 1) pass through unchanged. Cell
#'   boundaries are defined by unweighted quantiles of the predicted propensity
#'   scores. The `by` argument is silently ignored (a warning is issued).
#'
#' @note
#'   The propensity-cell method assumes **Missing At Random (MAR)**: response
#'   propensity is fully captured by the formula variables. Violations of MAR
#'   (i.e., response depends on unobserved variables) cannot be detected or
#'   corrected by this method. Additionally, propensity scores are treated as
#'   known (estimated from the data), not as true population propensities; this
#'   understates variance and should be accounted for in downstream analysis.
#'
#' @seealso [redistribute_weights()] for the general weight redistribution
#'   primitive that underlies `method = "weighting-class"`.
#'
#' @examples
#' df <- data.frame(
#'   age_group = c("18-34", "35-54", "55+", "18-34", "35-54"),
#'   responded = c(1L, 1L, 1L, 0L, 1L),
#'   stringsAsFactors = FALSE
#' )
#' result <- adjust_nonresponse(df, response_status = responded)
#'
#' @family nonresponse
#' @export
adjust_nonresponse <- function(
  data,
  response_status,
  weights = NULL,
  by = NULL,
  wt_name = "wts",
  method = c("weighting-class", "propensity-cell", "propensity"),
  formula = NULL,
  control = list(min_cell = 20, max_adjust = 2.0, n_cells = 5)
) {
  # ---- Capture call and match arguments -------------------------------------
  call_str    <- paste0(deparse(match.call()), collapse = " ")
  method      <- rlang::arg_match(method)
  weights_quo <- rlang::enquo(weights)
  rs_quo      <- rlang::enquo(response_status)
  by_quo      <- rlang::enquo(by)
  .validate_wt_name(wt_name)

  # Merge control with defaults (n_cells added for propensity-cell)
  control <- utils::modifyList(
    list(min_cell = 20, max_adjust = 2.0, n_cells = 5), control
  )

  # ---- 1. Input class check -------------------------------------------------
  .check_input_class(data)

  # ---- 2. Extract plain data frame ------------------------------------------
  data_df <- if (inherits(data, "data.frame")) as.data.frame(data) else data@data

  # ---- 3. Empty data check --------------------------------------------------
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

  # ---- 4. Weight column name ------------------------------------------------
  weight_col <- .get_weight_col_name(data, weights_quo)

  # For plain data.frame with weights = NULL: create uniform starting weights
  if (inherits(data, "data.frame") && rlang::quo_is_null(weights_quo) &&
      !inherits(data, "weighted_df")) {
    data_df[[wt_name]] <- rep(1 / nrow(data_df), nrow(data_df))
    weight_col <- wt_name
  }

  # Sync plain_df when we added a uniform weight column
  plain_df <- if (inherits(data, "data.frame")) data_df else data@data
  if (inherits(data, "data.frame") && !weight_col %in% names(plain_df)) {
    plain_df <- data_df
  }

  # ---- 5. Validate weights --------------------------------------------------
  .validate_weights(plain_df, weight_col)

  # ---- 7. Resolve and validate response_status column -----------------------
  status_pos <- tryCatch(
    tidyselect::eval_select(rs_quo, plain_df),
    error = function(e) {
      cli::cli_abort(
        c(
          "x" = "{.arg response_status} column not found in {.arg data}.",
          "i" = "Available columns: {.and {.field {names(plain_df)}}}.",
          "v" = paste0(
            "Pass a single bare column name, ",
            "e.g., {.code response_status = responded}."
          )
        ),
        class = "surveywts_error_response_status_not_found"
      )
    }
  )
  if (length(status_pos) > 1L) {
    cli::cli_abort(
      c(
        "x" = "{.arg response_status} must select exactly one column.",
        "i" = "Got {length(status_pos)} column(s).",
        "v" = paste0(
          "Pass a single bare column name, ",
          "e.g., {.code response_status = responded}."
        )
      ),
      class = "surveywts_error_response_status_multiple_columns"
    )
  }
  status_var <- names(status_pos)

  status_col <- plain_df[[status_var]]

  # Check for NAs in response_status
  n_na_status <- sum(is.na(status_col))
  if (n_na_status > 0L) {
    cli::cli_abort(
      c(
        "x" = paste0(
          "Response status column {.field {status_var}} contains ",
          "{n_na_status} NA value(s)."
        ),
        "i" = "The response indicator must be fully observed.",
        "v" = paste0(
          "Remove rows with missing response status before calling ",
          "{.fn adjust_nonresponse}."
        )
      ),
      class = "surveywts_error_response_status_has_na"
    )
  }

  # Check binary: must be logical or integer 0/1 (not factor, not other)
  .validate_response_status_binary(plain_df, status_var)

  # Convert to logical for consistent handling
  is_respondent <- as.logical(status_col)

  # Check that at least one respondent exists
  if (!any(is_respondent)) {
    cli::cli_abort(
      c(
        "x" = "No respondents found in {.arg data}.",
        "i" = paste0(
          "All values of {.field {status_var}} are 0 or {.code FALSE}."
        ),
        "v" = paste0(
          "Ensure {.arg data} contains both respondents and ",
          "nonrespondents before adjustment."
        )
      ),
      class = "surveywts_error_response_status_all_zero"
    )
  }

  # ---- 8. Propensity-cell branch (exits with return()) ----------------------
  if (method == "propensity-cell") {
    # Warn if by is non-NULL — ignored for propensity-cell
    if (!rlang::quo_is_null(by_quo)) {
      cli::cli_warn(
        c(
          "!" = paste0(
            "The {.arg by} argument is ignored when ",
            "{.code method = \"propensity-cell\"}."
          ),
          "i" = paste0(
            "Propensity-cell uses the formula to define cells globally; ",
            "stratified adjustment is not supported."
          )
        ),
        class = "surveywts_warning_by_ignored_for_propensity_cell"
      )
    }

    # Validate formula not NULL
    if (is.null(formula)) {
      cli::cli_abort(
        c(
          "x" = paste0(
            "{.arg formula} is required when ",
            "{.code method = \"propensity-cell\"}."
          ),
          "i" = paste0(
            "Provide a one-sided formula, e.g., ",
            "{.code formula = ~ age_group + sex}."
          )
        ),
        class = "surveywts_error_formula_required_for_propensity_cell"
      )
    }

    # Validate formula structure (one-sided)
    .validate_formula(formula)

    # Validate formula variables exist in data
    .validate_formula_variables(formula, plain_df, "data")

    # Check for NA in formula variables
    for (var in all.vars(formula)) {
      if (anyNA(plain_df[[var]])) {
        n_na_var <- sum(is.na(plain_df[[var]]))
        cli::cli_abort(
          c(
            "x" = paste0(
              "Formula variable {.field {var}} contains ",
              "{n_na_var} NA value(s)."
            ),
            "i" = paste0(
              "All formula variables must be fully observed for GLM fitting."
            ),
            "v" = paste0(
              "Remove or impute NA values in {.field {var}} before calling ",
              "{.fn adjust_nonresponse}."
            )
          ),
          class = "surveywts_error_formula_variable_has_na"
        )
      }
    }

    # Validate n_cells: whole number >= 2
    n_cells_pc <- control$n_cells
    if (
      !is.numeric(n_cells_pc) ||
        length(n_cells_pc) != 1L ||
        is.na(n_cells_pc) ||
        n_cells_pc < 2 ||
        n_cells_pc %% 1 != 0
    ) {
      cli::cli_abort(
        c(
          "x" = "{.code control$n_cells} must be a whole number >= 2.",
          "i" = "Got {.val {control$n_cells}}.",
          "v" = paste0(
            "Set {.code control$n_cells} to an integer >= 2, e.g., ",
            "{.code control = list(n_cells = 5)}."
          )
        ),
        class = "surveywts_error_n_cells_invalid"
      )
    }
    n_cells_pc <- as.integer(n_cells_pc)

    # Extract weights and compute before-stats
    weights_vec_pc <- plain_df[[weight_col]]
    before_stats   <- .compute_weight_stats(weights_vec_pc)

    # Fit propensity model: build two-sided formula from response_status col
    prop_formula <- stats::as.formula(
      paste(status_var, "~", deparse(formula[[2]]))
    )
    model  <- stats::glm(prop_formula, family = stats::binomial,
                         data = plain_df, weights = weights_vec_pc)
    scores <- stats::predict(model, type = "response")

    # Assign propensity cells via quantile-based cutpoints
    cuts  <- stats::quantile(scores, probs = seq(0, 1, 1 / n_cells_pc))
    cells <- findInterval(scores, cuts, rightmost.closed = TRUE)

    # Per-cell: validate, compute adjustment factor, warn if sparse/extreme
    new_weights_pc <- weights_vec_pc
    for (k in seq_len(n_cells_pc)) {
      cell_idx <- which(cells == k)
      if (length(cell_idx) == 0L) next

      resp_in_cell <- is_respondent[cell_idx]
      n_resp_pc    <- sum(resp_in_cell)

      if (n_resp_pc == 0L) {
        score_range <- range(scores[cells == k])
        cli::cli_abort(
          c(
            "x" = "Propensity cell {k} has no respondents.",
            "i" = paste0(
              "Propensity score range for cell {k}: ",
              "[{round(score_range[1], 4)}, {round(score_range[2], 4)}]."
            ),
            "v" = paste0(
              "Reduce {.code control$n_cells} or ensure respondents ",
              "exist across all propensity score strata."
            )
          ),
          class = "surveywts_error_no_respondents_in_propensity_cell"
        )
      }

      resp_idx_pc    <- cell_idx[resp_in_cell]
      sum_all_pc     <- sum(weights_vec_pc[cell_idx])
      sum_resp_pc    <- sum(weights_vec_pc[resp_idx_pc])
      adj_factor_pc  <- sum_all_pc / sum_resp_pc

      if (n_resp_pc < control$min_cell || adj_factor_pc > control$max_adjust) {
        adj_factor_fmt <- sprintf("%.2f", adj_factor_pc)
        cli::cli_warn(
          c(
            "!" = paste0(
              "Propensity cell {k} is sparse ",
              "({n_resp_pc} respondent(s), ",
              "adjustment factor {adj_factor_fmt}\u00d7)."
            ),
            "i" = "Small or high-adjustment cells may produce extreme weights.",
            "i" = paste0(
              "Consider reducing {.code control$n_cells} or adjusting ",
              "{.code control$min_cell} / {.code control$max_adjust}."
            )
          ),
          class = "surveywts_warning_class_near_empty"
        )
      }

      new_weights_pc[resp_idx_pc] <- weights_vec_pc[resp_idx_pc] * adj_factor_pc
    }

    # Set nonrespondent weights to 0
    new_weights_pc[!is_respondent] <- 0

    out_df_pc  <- plain_df
    out_col_pc <- if (inherits(data, "data.frame")) wt_name else weight_col
    out_df_pc[[out_col_pc]] <- new_weights_pc

    # Build history entry
    after_stats_pc  <- .compute_weight_stats(new_weights_pc[is_respondent])
    current_hist_pc <- .get_history(data)

    history_entry_pc <- .make_history_entry(
      step        = length(current_hist_pc) + 1L,
      operation   = "nonresponse_propensity_cell",
      weight_col  = if (inherits(data, "data.frame")) {
        wt_name
      } else {
        data@variables$weights
      },
      call_str    = call_str,
      parameters  = list(
        formula      = deparse(formula),
        n_cells      = n_cells_pc,
        by_variables = NULL,
        method       = method
      ),
      before_stats = before_stats,
      after_stats  = after_stats_pc,
      convergence  = NULL
    )

    # Build and return output (same class as input)
    if (inherits(data, "data.frame")) {
      new_history_pc <- c(current_hist_pc, list(history_entry_pc))
      return(.make_weighted_df(out_df_pc, wt_name, new_history_pc))
    } else if (S7::S7_inherits(data, surveycore::survey_nonprob)) {
      return(.update_survey_weights(data, new_weights_pc, history_entry_pc))
    } else {
      resp_rows_pc      <- which(is_respondent)
      filtered_design   <- data
      filtered_design@data <- out_df_pc[resp_rows_pc, , drop = FALSE]
      return(
        .update_survey_weights(filtered_design, new_weights_pc[resp_rows_pc],
                               history_entry_pc)
      )
    }
  }  # end propensity-cell branch

  # ---- 9. Propensity branch (continuous individual-level IPW) ---------------
  if (method == "propensity") {
    # Require formula
    if (is.null(formula)) {
      cli::cli_abort(
        c(
          "x" = paste0(
            "{.arg formula} is required when ",
            "{.code method = \"propensity\"}."
          ),
          "i" = paste0(
            "Provide a one-sided formula, e.g., ",
            "{.code formula = ~ age_group + sex}."
          )
        ),
        class = "surveywts_error_formula_required_for_propensity"
      )
    }

    # Validate formula structure (one-sided)
    .validate_formula(formula)

    # Validate formula variables exist in data
    .validate_formula_variables(formula, plain_df, "data")

    # Check for NA in formula variables
    for (var in all.vars(formula)) {
      if (anyNA(plain_df[[var]])) {
        n_na_pvar <- sum(is.na(plain_df[[var]]))
        cli::cli_abort(
          c(
            "x" = paste0(
              "Formula variable {.field {var}} contains ",
              "{n_na_pvar} NA value(s)."
            ),
            "i" = "All formula variables must be fully observed for GLM fitting.",
            "v" = paste0(
              "Remove or impute NA values in {.field {var}} before calling ",
              "{.fn adjust_nonresponse}."
            )
          ),
          class = "surveywts_error_formula_variable_has_na"
        )
      }
    }

    # Warn if by is non-NULL — ignored for propensity
    if (!rlang::quo_is_null(by_quo)) {
      cli::cli_warn(
        c(
          "!" = paste0(
            "The {.arg by} argument is ignored when ",
            "{.code method = \"propensity\"}."
          ),
          "i" = paste0(
            "Propensity weighting applies individual-level adjustments; ",
            "stratified adjustment via {.arg by} is not supported."
          )
        ),
        class = "surveywts_warning_by_ignored_for_propensity"
      )
    }

    # Fit response propensity model with GLM
    weights_vec_p  <- plain_df[[weight_col]]
    prop_formula_p <- stats::as.formula(
      paste(status_var, "~", deparse(formula[[2]]))
    )
    before_stats_p <- .compute_weight_stats(weights_vec_p)

    # Catch GLM convergence warning and re-emit with a more informative message
    fit_p <- withCallingHandlers(
      stats::glm(
        prop_formula_p,
        data    = plain_df,
        weights = weights_vec_p,
        family  = stats::binomial(link = "logit"),
        control = stats::glm.control(maxit = 25L, epsilon = 1e-8)
      ),
      warning = function(w) {
        if (grepl("algorithm did not converge", conditionMessage(w))) {
          cli::cli_warn(
            c(
              "!" = paste0(
                "The response propensity GLM did not converge in 25 iterations."
              ),
              "i" = paste0(
                "Propensity scores from a non-converged model are unreliable. ",
                "Results should be treated with caution."
              ),
              "i" = paste0(
                "Simplify {.arg formula} or inspect covariate distributions ",
                "for near-perfect separation."
              )
            ),
            class = "surveywts_warning_propensity_glm_convergence"
          )
          invokeRestart("muffleWarning")
        }
      }
    )

    # Predict scores for all units (respondents + nonrespondents)
    scores_p <- stats::predict(fit_p, type = "response")

    # Validate scores: must be strictly in (0, 1).
    # Defensive guard: stats::glm() with maxit = 25 does not produce exactly
    # 0 or 1 in practice, but this check is retained for correctness.
    # nocov start
    if (any(scores_p <= 0 | scores_p >= 1)) {
      cli::cli_abort(
        c(
          "x" = paste0(
            "Estimated response propensity scores include values ",
            "\u22640 or \u22651."
          ),
          "i" = paste0(
            "Degenerate scores indicate near-perfect separation in the ",
            "response propensity model."
          ),
          "v" = paste0(
            "Simplify {.arg formula} or inspect covariate distributions ",
            "for near-perfect predictor-response alignment."
          )
        ),
        class = "surveywts_error_propensity_scores_degenerate"
      )
    }
    # nocov end

    # Warn on extreme scores (< 0.01)
    n_extreme_p <- sum(scores_p < 0.01)
    if (n_extreme_p > 0L) {
      min_score_p <- min(scores_p)
      cli::cli_warn(
        c(
          "!" = paste0(
            "{n_extreme_p} estimated propensity score(s) are below 0.01 ",
            "(minimum: {round(min_score_p, 4)})."
          ),
          "i" = paste0(
            "Scores near 0 produce extreme inverse-probability weights ",
            "with high variance."
          ),
          "i" = paste0(
            "Consider simplifying {.arg formula} or adding ",
            "covariate groupings to stabilize scores."
          )
        ),
        class = "surveywts_warning_extreme_propensity_scores"
      )
    }

    # Compute adjusted weights: w_i / score_i for respondents; 0 for nonrespondents
    new_weights_p <- ifelse(is_respondent,
                            weights_vec_p / scores_p,
                            0)

    # Extreme-adjustment check
    if (!is.null(control$max_adjust)) {
      resp_wts_p <- weights_vec_p[is_respondent]
      adj_ratios  <- weights_vec_p[is_respondent] / scores_p[is_respondent]
      if (length(resp_wts_p) > 0L && mean(resp_wts_p) > 0) {
        max_adj_ratio <- max(adj_ratios) / mean(resp_wts_p)
        if (max_adj_ratio > control$max_adjust) {
          cli::cli_warn(
            c(
              "!" = paste0(
                "The maximum propensity adjustment factor ",
                "({round(max_adj_ratio, 2)}\u00d7) exceeds ",
                "{.code control$max_adjust} ",
                "({control$max_adjust}\u00d7)."
              ),
              "i" = paste0(
                "Large adjustment factors indicate strong nonresponse bias; ",
                "weights may be highly variable."
              ),
              "i" = paste0(
                "Consider simplifying {.arg formula}, using ",
                "{.fn trim_weights}, or increasing ",
                "{.code control$max_adjust} to suppress this warning."
              )
            ),
            class = "surveywts_warning_extreme_propensity_adjustment"
          )
        }
      }
    }

    # Prepare output data frame (all rows; nonrespondent weights = 0)
    out_df_p  <- plain_df
    out_col_p <- if (inherits(data, "data.frame")) wt_name else weight_col
    out_df_p[[out_col_p]] <- new_weights_p

    # Build history entry
    after_stats_p  <- .compute_weight_stats(new_weights_p[is_respondent])
    current_hist_p <- .get_history(data)

    history_entry_p <- .make_history_entry(
      step        = length(current_hist_p) + 1L,
      operation   = "nonresponse_propensity",
      weight_col  = if (inherits(data, "data.frame")) {
        wt_name
      } else {
        data@variables$weights
      },
      call_str    = call_str,
      parameters  = list(
        formula = deparse(formula),
        method  = "propensity"
      ),
      before_stats = before_stats_p,
      after_stats  = after_stats_p,
      convergence  = NULL
    )

    # Return same class as input
    if (inherits(data, "data.frame")) {
      new_history_p <- c(current_hist_p, list(history_entry_p))
      return(.make_weighted_df(out_df_p, wt_name, new_history_p))
    } else if (S7::S7_inherits(data, surveycore::survey_nonprob)) {
      return(.update_survey_weights(data, new_weights_p, history_entry_p))
    } else {
      resp_rows_p      <- which(is_respondent)
      filtered_p       <- data
      filtered_p@data  <- out_df_p[resp_rows_p, , drop = FALSE]
      return(
        .update_survey_weights(filtered_p, new_weights_p[resp_rows_p],
                               history_entry_p)
      )
    }
  }  # end propensity branch

  # ---- 10. Resolve by variable names via tidy-select (weighting-class) ------
  by_names <- if (rlang::quo_is_null(by_quo)) {
    character(0)
  } else {
    tidyselect::eval_select(by_quo, plain_df) |> names()
  }

  # ---- 9b. Check for NA in by variables ------------------------------------
  for (var in by_names) {
    n_na <- sum(is.na(plain_df[[var]]))
    if (n_na > 0L) {
      cli::cli_abort(
        c(
          "x" = paste0(
            "Weighting class variable {.field {var}} contains ",
            "{n_na} NA value(s)."
          ),
          "i" = "NA values in weighting class variables are not allowed.",
          "v" = paste0(
            "Remove or impute NA values in {.field {var}} before ",
            "calling {.fn adjust_nonresponse}."
          )
        ),
        class = "surveywts_error_variable_has_na"
      )
    }
  }

  # ---- 10. Extract weights and compute before-stats ------------------------
  weights_vec  <- plain_df[[weight_col]]
  before_stats <- .compute_weight_stats(weights_vec)

  # ---- 11. Build cell keys for redistribution ------------------------------
  if (length(by_names) == 0L) {
    # Global redistribution: all rows in one cell
    cell_keys <- rep("__global__", nrow(plain_df))
  } else {
    cell_keys <- do.call(
      paste,
      c(lapply(by_names, function(v) as.character(plain_df[[v]])),
        sep = "//")
    )
  }

  # ---- 12. Check for empty respondent cells --------------------------------
  unique_cells <- unique(cell_keys)
  for (cell in unique_cells) {
    cell_idx  <- which(cell_keys == cell)
    n_resp_cell <- sum(is_respondent[cell_idx])

    if (n_resp_cell == 0L) {
      cell_label <- if (cell == "__global__") "(all rows)" else cell
      cli::cli_abort(
        c(
          "x" = "Weighting class cell {.val {cell_label}} has no respondents.",
          "i" = paste0(
            "Cannot redistribute nonrespondent weights to an empty ",
            "respondent cell."
          ),
          "v" = paste0(
            "Collapse weighting classes to ensure each cell has at ",
            "least one respondent."
          )
        ),
        class = "surveywts_error_class_cell_empty"
      )
    }
  }

  # ---- 13. Compute adjusted weights ----------------------------------------
  new_weights <- weights_vec

  for (cell in unique_cells) {
    cell_idx       <- which(cell_keys == cell)
    resp_idx       <- cell_idx[is_respondent[cell_idx]]
    sum_all        <- sum(weights_vec[cell_idx])
    sum_resp       <- sum(weights_vec[resp_idx])
    adj_factor     <- sum_all / sum_resp
    n_resp_cell    <- length(resp_idx)

    # Warn if cell is sparse or adjustment is extreme
    cell_label <- if (cell == "__global__") "(global)" else cell
    if (n_resp_cell < control$min_cell || adj_factor > control$max_adjust) {
      adj_factor_fmt <- sprintf("%.2f", adj_factor)
      cli::cli_warn(
        c(
          "!" = paste0(
            "Weighting class cell {.val {cell_label}} is sparse ",
            "({n_resp_cell} respondent(s), ",
            "adjustment factor {adj_factor_fmt}\u00d7)."
          ),
          "i" = "Small or high-adjustment cells may produce extreme weights.",
          "i" = paste0(
            "Consider collapsing weighting classes or adjusting ",
            "{.code control$min_cell} / {.code control$max_adjust}."
          )
        ),
        class = "surveywts_warning_class_near_empty"
      )
    }

    new_weights[resp_idx] <- weights_vec[resp_idx] * adj_factor
  }

  # ---- 14. Set nonrespondent weights to 0 ----------------------------------
  new_weights[!is_respondent] <- 0
  out_df <- plain_df
  # For data.frame/weighted_df: write adjusted weights into wt_name column.
  # For survey objects: write into the original weight_col (wt_name is ignored).
  out_col <- if (inherits(data, "data.frame")) wt_name else weight_col
  out_df[[out_col]] <- new_weights

  # ---- 15. Build history entry ---------------------------------------------
  after_stats     <- .compute_weight_stats(new_weights[is_respondent])
  current_history <- .get_history(data)

  history_entry <- .make_history_entry(
    step        = length(current_history) + 1L,
    operation   = "nonresponse_weighting_class",
    weight_col  = if (inherits(data, "data.frame")) {
      wt_name
    } else {
      data@variables$weights
    },
    call_str    = call_str,
    parameters  = list(
      by_variables = by_names,
      method       = method
    ),
    before_stats = before_stats,
    after_stats  = after_stats,
    convergence  = NULL  # non-iterative
  )

  # ---- 16. Build output -----------------------------------------------------
  if (inherits(data, "data.frame")) {
    new_history <- c(current_history, list(history_entry))
    .make_weighted_df(out_df, wt_name, new_history)
  } else if (S7::S7_inherits(data, surveycore::survey_nonprob)) {
    # survey_nonprob supports zero weights (validator relaxed in surveycore
    # >= 0.6.1). All rows retained; nonrespondent weights = 0.
    .update_survey_weights(data, new_weights, history_entry)
  } else {
    # survey_taylor validator requires all weights > 0 — fall back to
    # respondent-only filtering to avoid S7 validation failure.
    resp_rows <- which(is_respondent)
    filtered_design <- data
    filtered_design@data <- out_df[resp_rows, , drop = FALSE]
    .update_survey_weights(filtered_design, new_weights[resp_rows],
                           history_entry)
  }
}

# ---------------------------------------------------------------------------
# redistribute_weights() — exported
# ---------------------------------------------------------------------------

#' Redistribute weights from one set of rows to another
#'
#' A general-purpose weight redistribution primitive. Sets the weights of rows
#' satisfying `reduce_if` to zero and redistributes their weight to rows
#' satisfying `increase_if`, proportionally by current weight, within groups
#' defined by `by`.
#'
#' Within each group `h`:
#'
#' \deqn{w_{i,new} = w_i \times \frac{W_{reduce} + W_{increase}}{W_{increase}}}
#'
#' for each `increase_if` row `i`, where \eqn{W_{reduce}} and
#' \eqn{W_{increase}} are the summed weights of `reduce_if` and `increase_if`
#' rows in that group. Rows matching neither indicator are left unchanged.
#'
#' @param data A `data.frame`, `weighted_df`, `survey_taylor`, or
#'   `survey_nonprob`. `survey_replicate` -> error.
#' @param reduce_if Bare name (NSE). Binary indicator column (`logical` or
#'   integer `0`/`1`). Rows where this is `TRUE`/`1` have their weight set
#'   to 0 and their weight redistributed.
#' @param increase_if Bare name (NSE). Binary indicator column. Rows where
#'   this is `TRUE`/`1` receive the redistributed weight.
#' @param weights Bare name (NSE). Weight column. Auto-detected from
#'   `weighted_df` attribute or `@variables$weights`. For plain `data.frame`
#'   with `weights = NULL`, uniform starting weights are used.
#' @param by <[`tidy-select`][tidyselect::language]> Grouping variable(s).
#'   Redistribution is performed within each group. `NULL` -> global
#'   redistribution.
#' @param wt_name Character scalar. Name of the output weight column in the
#'   returned `weighted_df`. Default `"wts"`. Ignored for survey objects.
#' @param control Named list of warning thresholds. Merged with defaults
#'   `list(min_cell = 20, max_adjust = 2.0)`. `min_cell`: warn when a
#'   group has fewer than this many `increase_if` rows. `max_adjust`: warn
#'   when the adjustment factor exceeds this value.
#'
#' @return
#'   - `data.frame` or `weighted_df` input -> `weighted_df` (all rows
#'     retained; `reduce_if` rows have weight 0).
#'   - `survey_nonprob` or `survey_taylor` input -> same class as input,
#'     with `reduce_if` rows removed (zero weights violate survey validators).
#'
#'   A history entry with `operation = "redistribute_weights"` is appended.
#'
#' @details
#'   This function is the general form of
#'   [adjust_nonresponse(method = "weighting-class")][adjust_nonresponse()].
#'   When `reduce_if = nonrespondent indicator` and `increase_if = respondent
#'   indicator`, the two produce equivalent results (within `1e-10`).
#'   `adjust_nonresponse()` does not call `redistribute_weights()` internally
#'   because it is currently the only call site; refactor if a second emerges.
#'
#' @examples
#' df <- data.frame(
#'   group    = c("A", "A", "A", "B", "B"),
#'   reduce   = c(1L, 0L, 0L, 1L, 0L),
#'   increase = c(0L, 1L, 1L, 0L, 1L)
#' )
#' result <- redistribute_weights(df, reduce_if = reduce, increase_if = increase)
#'
#' @family nonresponse
#' @export
redistribute_weights <- function(
  data,
  reduce_if,
  increase_if,
  weights = NULL,
  by = NULL,
  wt_name = "wts",
  control = list()
) {
  # ---- Capture call and quosures -------------------------------------------
  call_str     <- paste0(deparse(match.call()), collapse = " ")
  weights_quo  <- rlang::enquo(weights)
  reduce_quo   <- rlang::enquo(reduce_if)
  increase_quo <- rlang::enquo(increase_if)

  # ---- 1. Input class check -------------------------------------------------
  .check_input_class(data)

  # ---- 2. Extract plain data frame ------------------------------------------
  data_df <- if (inherits(data, "data.frame")) as.data.frame(data) else data@data

  # ---- 3. Empty data check --------------------------------------------------
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

  # ---- 4. wt_name validation ------------------------------------------------
  .validate_wt_name(wt_name)

  # ---- 5. Weight column name ------------------------------------------------
  weight_col <- .get_weight_col_name(data, weights_quo)

  # ---- 6. wt_name conflict check (data.frame / weighted_df only) ------------
  # For plain data.frame + weights = NULL, weight_col is the sentinel ".weight"
  # which never appears in user data, so any existing column with wt_name
  # is treated as a conflict.
  if (inherits(data, "data.frame") &&
      wt_name %in% names(data_df) &&
      !identical(wt_name, weight_col)) {
    cli::cli_abort(
      c(
        "x" = paste0(
          "{.arg wt_name} {.val {wt_name}} conflicts with an existing ",
          "column in {.arg data}."
        ),
        "i" = paste0(
          "{.field {wt_name}} is already present and is not the weight ",
          "column."
        ),
        "v" = "Choose a different name for the output weight column."
      ),
      class = "surveywts_error_wt_name_conflict"
    )
  }

  # ---- 7. Create uniform starting weights for plain data.frame + NULL -------
  if (inherits(data, "data.frame") && rlang::quo_is_null(weights_quo) &&
      !inherits(data, "weighted_df")) {
    data_df[[wt_name]] <- rep(1 / nrow(data_df), nrow(data_df))
    weight_col <- wt_name
  }

  # Sync plain_df after potentially adding uniform weights
  plain_df <- if (inherits(data, "data.frame")) data_df else data@data

  # ---- 8. Validate weights --------------------------------------------------
  .validate_weights(plain_df, weight_col)

  # ---- 9. Merge control with defaults ---------------------------------------
  control <- utils::modifyList(list(min_cell = 20L, max_adjust = 2.0), control)

  # ---- 10. Resolve indicator column names -----------------------------------
  reduce_col   <- rlang::as_name(reduce_quo)
  increase_col <- rlang::as_name(increase_quo)

  # ---- 11. Check indicator columns exist ------------------------------------
  if (!reduce_col %in% names(plain_df)) {
    cli::cli_abort(
      c(
        "x" = paste0(
          "{.arg reduce_if} column {.field {reduce_col}} not found in ",
          "{.arg data}."
        ),
        "i" = "Available columns: {.and {.field {names(plain_df)}}}.",
        "v" = paste0(
          "Pass a bare column name, e.g., ",
          "{.code reduce_if = my_indicator}."
        )
      ),
      class = "surveywts_error_reduce_if_not_found"
    )
  }
  if (!increase_col %in% names(plain_df)) {
    cli::cli_abort(
      c(
        "x" = paste0(
          "{.arg increase_if} column {.field {increase_col}} not found in ",
          "{.arg data}."
        ),
        "i" = "Available columns: {.and {.field {names(plain_df)}}}.",
        "v" = paste0(
          "Pass a bare column name, e.g., ",
          "{.code increase_if = my_indicator}."
        )
      ),
      class = "surveywts_error_increase_if_not_found"
    )
  }

  # ---- 12. Binary validation for reduce_if ----------------------------------
  .validate_response_status_binary(
    plain_df, reduce_col,
    col_label   = "reduce_if column",
    fn_name     = "redistribute_weights",
    error_class = "surveywts_error_reduce_if_not_binary"
  )

  # ---- 13. NA check for reduce_if -------------------------------------------
  n_na_reduce <- sum(is.na(plain_df[[reduce_col]]))
  if (n_na_reduce > 0L) {
    cli::cli_abort(
      c(
        "x" = paste0(
          "{.arg reduce_if} column {.field {reduce_col}} contains ",
          "{n_na_reduce} NA value(s)."
        ),
        "i" = "The reduce indicator must be fully observed.",
        "v" = paste0(
          "Remove rows with missing values in {.field {reduce_col}} ",
          "before calling {.fn redistribute_weights}."
        )
      ),
      class = "surveywts_error_reduce_if_has_na"
    )
  }

  # ---- 14. Binary validation for increase_if --------------------------------
  .validate_response_status_binary(
    plain_df, increase_col,
    col_label   = "increase_if column",
    fn_name     = "redistribute_weights",
    error_class = "surveywts_error_increase_if_not_binary"
  )

  # ---- 15. NA check for increase_if -----------------------------------------
  n_na_increase <- sum(is.na(plain_df[[increase_col]]))
  if (n_na_increase > 0L) {
    cli::cli_abort(
      c(
        "x" = paste0(
          "{.arg increase_if} column {.field {increase_col}} contains ",
          "{n_na_increase} NA value(s)."
        ),
        "i" = "The increase indicator must be fully observed.",
        "v" = paste0(
          "Remove rows with missing values in {.field {increase_col}} ",
          "before calling {.fn redistribute_weights}."
        )
      ),
      class = "surveywts_error_increase_if_has_na"
    )
  }

  # ---- 16. Convert to logical and check overlap -----------------------------
  is_reduce  <- as.logical(plain_df[[reduce_col]])
  is_increase <- as.logical(plain_df[[increase_col]])

  n_overlap <- sum(is_reduce & is_increase, na.rm = TRUE)
  if (n_overlap > 0L) {
    cli::cli_abort(
      c(
        "x" = paste0(
          "{n_overlap} row(s) have both {.arg reduce_if} and ",
          "{.arg increase_if} set to {.code TRUE}."
        ),
        "i" = paste0(
          "{.arg reduce_if} and {.arg increase_if} must be mutually ",
          "exclusive."
        ),
        "v" = paste0(
          "Ensure no row has both indicators set to 1 or {.code TRUE}."
        )
      ),
      class = "surveywts_error_indicators_overlap"
    )
  }

  # ---- 17. Resolve by variable names ----------------------------------------
  by_quo   <- rlang::enquo(by)
  by_names <- if (rlang::quo_is_null(by_quo)) {
    character(0)
  } else {
    tidyselect::eval_select(by_quo, plain_df) |> names()
  }

  # ---- 18. Check for NA in by variables -------------------------------------
  for (var in by_names) {
    n_na <- sum(is.na(plain_df[[var]]))
    if (n_na > 0L) {
      cli::cli_abort(
        c(
          "x" = paste0(
            "By variable {.field {var}} contains {n_na} NA value(s)."
          ),
          "i" = "NA values in grouping variables are not allowed.",
          "v" = paste0(
            "Remove or impute NA values in {.field {var}} before calling ",
            "{.fn redistribute_weights}."
          )
        ),
        class = "surveywts_error_variable_has_na"
      )
    }
  }

  # ---- 19. Extract weights and compute before-stats -------------------------
  weights_vec  <- plain_df[[weight_col]]
  before_stats <- .compute_weight_stats(weights_vec)

  # ---- 20. Build cell keys --------------------------------------------------
  if (length(by_names) == 0L) {
    cell_keys <- rep("__global__", nrow(plain_df))
  } else {
    cell_keys <- do.call(
      paste,
      c(lapply(by_names, function(v) as.character(plain_df[[v]])),
        sep = "//")
    )
  }

  # ---- 21. Per-group redistribution -----------------------------------------
  new_weights  <- weights_vec
  unique_cells <- unique(cell_keys)

  for (cell in unique_cells) {
    cell_idx     <- which(cell_keys == cell)
    reduce_idx   <- cell_idx[is_reduce[cell_idx]]
    increase_idx <- cell_idx[is_increase[cell_idx]]

    # No reduce_if rows in this group: skip (nothing to redistribute)
    if (length(reduce_idx) == 0L) next

    # reduce_if rows present but no increase_if rows: error
    if (length(increase_idx) == 0L) {
      cell_label <- if (cell == "__global__") "(all rows)" else cell
      cli::cli_abort(
        c(
          "x" = paste0(
            "Group {.val {cell_label}} has {length(reduce_idx)} ",
            "reduce_if row(s) but no increase_if rows."
          ),
          "i" = "Cannot redistribute weight to an empty recipient set.",
          "v" = paste0(
            "Ensure each group has at least one row with ",
            "{.arg increase_if} = {.code TRUE}."
          )
        ),
        class = "surveywts_error_no_recipients_in_group"
      )
    }

    w_reduce   <- sum(weights_vec[reduce_idx])
    w_increase <- sum(weights_vec[increase_idx])
    adj_factor <- (w_reduce + w_increase) / w_increase
    n_increase  <- length(increase_idx)

    # Warn on sparse or extreme-adjustment groups
    cell_label <- if (cell == "__global__") "(global)" else cell
    if (n_increase < control$min_cell || adj_factor > control$max_adjust) {
      adj_factor_fmt <- sprintf("%.2f", adj_factor)
      cli::cli_warn(
        c(
          "!" = paste0(
            "Redistribution group {.val {cell_label}} has {n_increase} ",
            "recipient(s), adjustment factor {adj_factor_fmt}\u00d7."
          ),
          "i" = "Small or high-adjustment groups may produce extreme weights.",
          "i" = paste0(
            "Consider collapsing groups or adjusting ",
            "{.code control$min_cell} / {.code control$max_adjust}."
          )
        ),
        class = "surveywts_warning_class_near_empty"
      )
    }

    new_weights[increase_idx] <- weights_vec[increase_idx] * adj_factor
    new_weights[reduce_idx]   <- 0
  }

  # ---- 22. Build output data frame ------------------------------------------
  out_col <- if (inherits(data, "data.frame")) wt_name else weight_col
  out_df  <- plain_df
  out_df[[out_col]] <- new_weights

  # ---- 23. Build history entry ----------------------------------------------
  after_stats     <- .compute_weight_stats(new_weights[is_increase])
  current_history <- .get_history(data)

  history_entry <- .make_history_entry(
    step        = length(current_history) + 1L,
    operation   = "redistribute_weights",
    weight_col  = if (inherits(data, "data.frame")) {
      wt_name
    } else {
      data@variables$weights
    },
    call_str    = call_str,
    parameters  = list(
      reduce_col   = reduce_col,
      increase_col = increase_col,
      by_variables = by_names,
      method       = "general_redistribution"
    ),
    before_stats = before_stats,
    after_stats  = after_stats,
    convergence  = NULL
  )

  # ---- 24. Return output ----------------------------------------------------
  if (inherits(data, "data.frame")) {
    new_history <- c(current_history, list(history_entry))
    .make_weighted_df(out_df, wt_name, new_history)
  } else {
    # For survey objects: filter out reduce_if rows (zero weights violate
    # the strictly-positive-weights validator on survey_taylor, and for
    # consistency, survey_nonprob follows the same contract here).
    keep_rows         <- which(!is_reduce)
    filtered_design   <- data
    filtered_design@data <- out_df[keep_rows, , drop = FALSE]
    .update_survey_weights(filtered_design, new_weights[keep_rows], history_entry)
  }
}

# ---------------------------------------------------------------------------
# .validate_response_status_binary() — private helper
# ---------------------------------------------------------------------------

# Validates that a binary indicator column is integer 0/1 or logical.
# Factors are explicitly rejected even if they have 2 levels.
#
# Arguments:
#   data        : plain data.frame
#   status_var  : character(1) — name of the indicator column
#   col_label   : character(1) — label used in the error message x-bullet
#   fn_name     : character(1) — function name used in the v-bullet
#   error_class : character(1) — error class to throw
#
# Returns invisible(TRUE) on success. Throws on failure.
#
# Called by adjust_nonresponse() (response_status) and redistribute_weights()
# (reduce_if, increase_if). Use col_label/fn_name/error_class to tailor the
# message for each context without duplicating the validation logic.
.validate_response_status_binary <- function(
  data,
  status_var,
  col_label   = "Response status column",
  fn_name     = "adjust_nonresponse",
  error_class = "surveywts_error_response_status_not_binary"
) {
  col <- data[[status_var]]

  # Factors are not binary regardless of their levels
  if (is.factor(col)) {
    cli::cli_abort(
      c(
        "x" = paste0(
          "{col_label} {.field {status_var}} must be binary ",
          "(0/1 or logical)."
        ),
        "i" = paste0(
          "Got {.cls {class(col)[[1]]}} with values: ",
          "{.val {unique(col)}}."
        ),
        "i" = "Factor columns are not binary regardless of their levels.",
        "v" = paste0(
          "Convert to logical ({.code TRUE}/{.code FALSE}) or integer ",
          "({.code 0}/{.code 1}) before calling {.fn {fn_name}}."
        )
      ),
      class = error_class
    )
  }

  if (is.logical(col)) {
    return(invisible(TRUE))
  }

  if (is.integer(col) || is.numeric(col)) {
    unique_vals <- sort(unique(col[!is.na(col)]))
    if (!all(unique_vals %in% c(0L, 1L))) {
      cli::cli_abort(
        c(
          "x" = paste0(
            "{col_label} {.field {status_var}} must be binary ",
            "(0/1 or logical)."
          ),
          "i" = paste0(
            "Got {.cls {class(col)[[1]]}} with values: ",
            "{.val {unique(col)}}."
          ),
          "i" = "Factor columns are not binary regardless of their levels.",
          "v" = paste0(
            "Convert to logical ({.code TRUE}/{.code FALSE}) or integer ",
            "({.code 0}/{.code 1}) before calling {.fn {fn_name}}."
          )
        ),
        class = error_class
      )
    }
    return(invisible(TRUE))
  }

  # All other types (character, etc.) are not binary
  cli::cli_abort(
    c(
      "x" = paste0(
        "{col_label} {.field {status_var}} must be binary ",
        "(0/1 or logical)."
      ),
      "i" = paste0(
        "Got {.cls {class(col)[[1]]}} with values: ",
        "{.val {unique(col)}}."
      ),
      "i" = "Factor columns are not binary regardless of their levels.",
      "v" = paste0(
        "Convert to logical ({.code TRUE}/{.code FALSE}) or integer ",
        "({.code 0}/{.code 1}) before calling {.fn {fn_name}}."
      )
    ),
    class = error_class
  )
}
