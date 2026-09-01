# R/adjust_nonresponse.R
#
# adjust_nonresponse() — weighting-class, propensity-cell, and propensity
# nonresponse adjustment. Redistributes nonrespondent weights to respondents
# within cells. survey_nonprob keeps all rows (nonrespondent weights = 0);
# survey_taylor keeps respondent rows only (its validator rejects zero weights).

#' Correct weights for unit nonresponse
#'
#' Redistributes the weights of nonrespondents to respondents within
#' weighting classes (groups assumed to share one response rate) defined by
#' `by`. Respondent weights increase proportionally to preserve the total
#' weight within each class. What happens to the nonrespondent rows depends
#' on the input class — see the **Input class behavior** section.
#'
#' @param data A `survey_taylor` or `survey_nonprob`. Must include BOTH
#'   respondents and nonrespondents. `survey_replicate` -> error. Any other
#'   class -> error.
#' @param response_status Bare name (NSE). Binary response indicator column.
#'   Must be `logical` or integer `0`/`1`. `1` / `TRUE` = respondent.
#' @param weights Bare name (NSE). Weight column. `NULL` -> auto-detected from
#'   survey object `@variables$weights`.
#' @param by <[`tidy-select`][tidyselect::language]> Weighting class variables.
#'   Redistribution is performed within each cell defined by the joint
#'   combination of these variables. `NULL` -> global redistribution across
#'   all rows.
#' @param wt_name `NULL` (default) or a character scalar. When `NULL`,
#'   adjusted weights overwrite the existing weight column in place. When a
#'   character string, a new column is added and `@variables$weights` updated.
#' @param method Character scalar. Adjustment method. One of
#'   `"weighting-class"` (default), `"propensity-cell"`, or `"propensity"`.
#'   - `"weighting-class"`: cells are defined by `by` groups; adjustment
#'     factors are applied cell-by-cell. Choose it when you can name the
#'     groups whose response rates differ, and those groups are observed
#'     for respondents and nonrespondents alike.
#'   - `"propensity-cell"`: fits a logistic response propensity model via
#'     `formula`, bins scores into `control$n_cells` quantile cells, then
#'     applies cell-level adjustments. Choose it when no natural grouping
#'     exists: the model builds the cells from the data, and the cell-level
#'     factor smooths over individual fitted propensities.
#'   - `"propensity"`: fits a logistic response propensity model via `formula`
#'     and applies individual-level inverse-probability weights
#'     (`weight_i / propensity_i`) to each respondent. Requires `formula`.
#'     Choose it when each unit's own fitted propensity should set its
#'     adjustment; individual factors can move further than cell-level ones,
#'     so watch the `max_adjust` warning.
#' @param formula A one-sided formula (e.g., `~ age_group + sex`) used for
#'   propensity score estimation when `method = "propensity-cell"` or
#'   `method = "propensity"`. Required for `"propensity"`. All variables must
#'   be present in `data` with no `NA` values.
#' @param control Named list of control parameters. Merged with defaults
#'   `list(min_cell = 20, max_adjust = 2.0, n_cells = 5)`.
#'   - `min_cell`: warn when a cell has fewer than this many respondents
#'     (default 20, per NAEP methodology). Used only for `"propensity-cell"`.
#'   - `max_adjust`: warn when the nonresponse adjustment factor exceeds
#'     this value (default 2.0). For `"propensity-cell"`, the cell-level
#'     factor; for `"propensity"`, the individual IPW ratio relative to the
#'     mean respondent weight.
#'   - `n_cells`: number of propensity score cells (default 5). Must be a whole
#'     number >= 2. Used only when `method = "propensity-cell"`.
#'   Either `min_cell` or `max_adjust` condition alone triggers the warning.
#'
#' @section Input class behavior:
#' The rows in the returned object depend on the class of `data`:
#'
#' - `survey_nonprob`: all rows are returned. Nonrespondent rows are kept
#'   with a weight of zero.
#' - `survey_taylor`: respondent rows only are returned. The
#'   `survey_taylor` validator requires strictly positive weights, so the
#'   zero-weight nonrespondent rows are dropped.
#'
#' In both cases respondent weights are adjusted upward to conserve the
#' total weight within each cell.
#'
#' @section Algorithm:
#' Within each cell \eqn{h} defined by `by`, the adjustment factor is
#' \deqn{f_h = \frac{\sum_{i \in h} w_i}{\sum_{i \in h, \text{resp}} w_i}}
#' where the numerator sums all weights in the cell and the denominator
#' sums respondent weights only. Each respondent weight becomes
#' \eqn{w_{i,new} = w_i \times f_h}. Nonrespondent weights are set to 0.
#'
#' @returns
#'   An object of the same class as `data` with adjusted weights. The rows
#'   it contains depend on the input class (see the **Input class
#'   behavior** section):
#'
#'   - `survey_nonprob` input -> `survey_nonprob` with all rows;
#'     nonrespondent weights are set to 0
#'   - `survey_taylor` input -> `survey_taylor` with respondent rows only,
#'     because `survey_taylor` does not support zero weights
#'
#'   A history entry with `operation = "nonresponse_weighting_class"` (for
#'   `method = "weighting-class"`), `operation = "nonresponse_propensity_cell"`
#'   (for `method = "propensity-cell"`), or `operation = "nonresponse_propensity"`
#'   (for `method = "propensity"`) is appended to `weighting_history`.
#'
#' @details
#'   **When to use.** This function corrects for known nonrespondents
#'   inside your own sample; it needs a column that marks who responded.
#'   To move weight between rows defined by other conditions, use
#'   [redistribute_weights()]. To weight a sample that has no response
#'   indicator against a reference survey, use [ipw()].
#'
#'   For `survey_nonprob` input, zero-weight observations are retained for
#'   design-based variance estimation. Survey estimation functions (e.g.,
#'   [survey::svymean()]) handle zero weights correctly -- zero-weight units
#'   are excluded from point estimates but included in the design structure
#'   for variance estimation. For manual calculations, use `w[w > 0]` to
#'   exclude nonrespondents. For `survey_taylor` input, the returned object
#'   carries no zero-weight rows -- the nonrespondent rows are dropped.
#'
#'   Diagnostic functions ([effective_sample_size()], [weight_variability()],
#'   [summarize_weights()]) automatically filter to positive weights before
#'   computing statistics.
#'
#'   Re-calibrating post-nonresponse data requires filtering to respondents
#'   first, because [calibrate()], [calibrate_rake()], and
#'   [poststratify()] reject zero weights.
#'
#'   **Propensity-cell method:** A logistic regression is fitted via
#'   [stats::glm()] with `family = binomial`. GLM convergence warnings (e.g.,
#'   fitted probabilities numerically 0 or 1) pass through unchanged. Cell
#'   boundaries are defined by unweighted quantiles of the predicted
#'   propensity scores (the modeled probability of responding or of
#'   appearing in the sample). This method assumes missing at random
#'   (response depends only on observed variables). The `by` argument is
#'   silently ignored (a warning is issued).
#'
#' @note
#'   The propensity-cell method assumes **Missing At Random (MAR)**: response
#'   propensity is fully captured by the formula variables. Violations of MAR
#'   (i.e., response depends on unobserved variables) cannot be detected or
#'   corrected by this method. Additionally, propensity scores are treated as
#'   known (estimated from the data), not as true population propensities; this
#'   understates variance and should be accounted for in downstream analysis.
#'
#' @seealso [redistribute_weights()], [ipw()]. For the class system, the
#'   standard workflows, and a glossary of terms, see the [Getting started
#'   article](https://jdenn0514.github.io/surveywts/articles/getting-started.html).
#'
#' @examples
#' # survey_taylor: mutate the tibble first, then construct the design -------
#' # `formula` below needs no NA in sex or age_f3, so filter both here.
#' gss_with_resp <- gss_2024[!is.na(gss_2024$sex) & !is.na(gss_2024$age_f3), ]
#' gss_with_resp$responded <- sample(
#'   c(0L, 1L), nrow(gss_with_resp), replace = TRUE, prob = c(0.2, 0.8)
#' )
#' gss_svy <- surveycore::as_survey(
#'   gss_with_resp, weights = wtssps, strata = vstrat, ids = vpsu, nest = TRUE
#' )
#'
#' # method = "weighting-class" (the default) ---------------------------------
#' result <- adjust_nonresponse(gss_svy, response_status = responded, by = sex)
#' summarize_weights(result)
#'
#' # survey_taylor requires strictly positive weights, so the zero-weight
#' # nonrespondent rows are dropped. The exact drop count moves with the
#' # unseeded draw above; the two counts below still differ every run.
#' nrow(surveycore::survey_data(gss_svy))
#' nrow(surveycore::survey_data(result))
#'
#' # method = "propensity-cell": one factor per propensity cell ---------------
#' # Both propensity methods fit a weighted logistic regression, so base R
#' # warns "non-integer #successes in a binomial glm!". The fit is unaffected.
#' result_pc <- adjust_nonresponse(
#'   gss_svy,
#'   response_status = responded,
#'   method = "propensity-cell",
#'   formula = ~ sex + age_f3
#' )
#' summarize_weights(result_pc)
#'
#' # method = "propensity": one factor per unit ------------------------------
#' # Individual factors move further than cell-level ones, so this trips the
#' # `max_adjust` warning. The factor itself moves with the unseeded draw.
#' result_p <- adjust_nonresponse(
#'   gss_svy,
#'   response_status = responded,
#'   method = "propensity",
#'   formula = ~ sex + age_f3
#' )
#' summarize_weights(result_p)
#'
#' @family nonresponse
#' @export
adjust_nonresponse <- function(
  data,
  response_status,
  weights = NULL,
  by = NULL,
  wt_name = NULL,
  method = c("weighting-class", "propensity-cell", "propensity"),
  formula = NULL,
  control = list(min_cell = 20, max_adjust = 2.0, n_cells = 5)
) {
  # ---- Capture call and match arguments -------------------------------------
  call_str <- paste0(deparse(match.call()), collapse = " ")
  method <- rlang::arg_match(method)
  weights_quo <- rlang::enquo(weights)
  rs_quo <- rlang::enquo(response_status)
  by_quo <- rlang::enquo(by)
  .validate_wt_name(wt_name)

  # Merge control with defaults (n_cells added for propensity-cell)
  control <- utils::modifyList(
    list(min_cell = 20, max_adjust = 2.0, n_cells = 5),
    control
  )

  # ---- 1. Input class check -------------------------------------------------
  .check_input_class(data)

  # survey_replicate is not yet supported for nonresponse adjustment.
  # (calibrate_greg/rake/poststrat accept survey_replicate; nonresponse does not.)
  if (S7::S7_inherits(data, surveycore::survey_replicate)) {
    cli::cli_abort(
      c(
        "x" = "{.cls survey_replicate} objects are not supported by {.fn adjust_nonresponse}.",
        "i" = "Replicate-weight support for nonresponse adjustment is not yet available.",
        "v" = "Use a {.cls survey_taylor} or {.cls survey_nonprob} design."
      ),
      class = "surveywts_error_replicate_not_supported"
    )
  }

  # ---- 2. Extract plain data frame ------------------------------------------
  data_df <- data@data

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

  plain_df <- data_df

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
    before_stats <- .compute_weight_stats(weights_vec_pc)

    # Fit propensity model: build two-sided formula from response_status col
    prop_formula <- stats::as.formula(
      paste(status_var, "~", deparse(formula[[2]]))
    )
    model <- stats::glm(
      prop_formula,
      family = stats::binomial,
      data = plain_df,
      weights = weights_vec_pc
    )
    scores <- stats::predict(model, type = "response")

    # Assign propensity cells via quantile-based cutpoints
    cuts <- stats::quantile(scores, probs = seq(0, 1, 1 / n_cells_pc))
    cells <- findInterval(scores, cuts, rightmost.closed = TRUE)

    # Per-cell: validate, compute adjustment factor, warn if sparse/extreme
    new_weights_pc <- weights_vec_pc
    for (k in seq_len(n_cells_pc)) {
      cell_idx <- which(cells == k)
      if (length(cell_idx) == 0L) {
        next
      }

      resp_in_cell <- is_respondent[cell_idx]
      n_resp_pc <- sum(resp_in_cell)

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

      resp_idx_pc <- cell_idx[resp_in_cell]
      sum_all_pc <- sum(weights_vec_pc[cell_idx])
      sum_resp_pc <- sum(weights_vec_pc[resp_idx_pc])
      adj_factor_pc <- sum_all_pc / sum_resp_pc

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

    # Build history entry
    after_stats_pc <- .compute_weight_stats(new_weights_pc[is_respondent])
    current_hist_pc <- .get_history(data)

    history_entry_pc <- .make_history_entry(
      step = length(current_hist_pc) + 1L,
      operation = "nonresponse_propensity_cell",
      weight_col = if (is.null(wt_name)) data@variables$weights else wt_name,
      call_str = call_str,
      parameters = list(
        formula = deparse(formula),
        n_cells = n_cells_pc,
        by_variables = NULL,
        method = method
      ),
      before_stats = before_stats,
      after_stats = after_stats_pc,
      convergence = NULL
    )

    # Return same class as input
    if (S7::S7_inherits(data, surveycore::survey_nonprob)) {
      return(.update_survey_weights(
        data,
        new_weights_pc,
        history_entry_pc,
        wt_name = wt_name
      ))
    } else {
      resp_rows_pc <- which(is_respondent)
      filtered_design <- data
      filtered_design@data <- plain_df[resp_rows_pc, , drop = FALSE]
      return(
        .update_survey_weights(
          filtered_design,
          new_weights_pc[resp_rows_pc],
          history_entry_pc,
          wt_name = wt_name
        )
      )
    }
  } # end propensity-cell branch

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
    weights_vec_p <- plain_df[[weight_col]]
    prop_formula_p <- stats::as.formula(
      paste(status_var, "~", deparse(formula[[2]]))
    )
    before_stats_p <- .compute_weight_stats(weights_vec_p)

    # Catch GLM convergence warning and re-emit with a more informative message
    fit_p <- withCallingHandlers(
      stats::glm(
        prop_formula_p,
        data = plain_df,
        weights = weights_vec_p,
        family = stats::binomial(link = "logit"),
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
    new_weights_p <- ifelse(is_respondent, weights_vec_p / scores_p, 0)

    # Extreme-adjustment check
    if (!is.null(control$max_adjust)) {
      resp_wts_p <- weights_vec_p[is_respondent]
      adj_ratios <- weights_vec_p[is_respondent] / scores_p[is_respondent]
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

    # Build history entry
    after_stats_p <- .compute_weight_stats(new_weights_p[is_respondent])
    current_hist_p <- .get_history(data)

    history_entry_p <- .make_history_entry(
      step = length(current_hist_p) + 1L,
      operation = "nonresponse_propensity",
      weight_col = if (is.null(wt_name)) data@variables$weights else wt_name,
      call_str = call_str,
      parameters = list(
        formula = deparse(formula),
        method = "propensity"
      ),
      before_stats = before_stats_p,
      after_stats = after_stats_p,
      convergence = NULL
    )

    # Return same class as input
    if (S7::S7_inherits(data, surveycore::survey_nonprob)) {
      return(.update_survey_weights(
        data,
        new_weights_p,
        history_entry_p,
        wt_name = wt_name
      ))
    } else {
      resp_rows_p <- which(is_respondent)
      filtered_p <- data
      filtered_p@data <- plain_df[resp_rows_p, , drop = FALSE]
      return(
        .update_survey_weights(
          filtered_p,
          new_weights_p[resp_rows_p],
          history_entry_p,
          wt_name = wt_name
        )
      )
    }
  } # end propensity branch

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
  weights_vec <- plain_df[[weight_col]]
  before_stats <- .compute_weight_stats(weights_vec)

  # ---- 11. Build cell keys for redistribution ------------------------------
  if (length(by_names) == 0L) {
    # Global redistribution: all rows in one cell
    cell_keys <- rep("__global__", nrow(plain_df))
  } else {
    cell_keys <- do.call(
      paste,
      c(lapply(by_names, function(v) as.character(plain_df[[v]])), sep = "//")
    )
  }

  # ---- 12. Check for empty respondent cells --------------------------------
  unique_cells <- unique(cell_keys)
  for (cell in unique_cells) {
    cell_idx <- which(cell_keys == cell)
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
    cell_idx <- which(cell_keys == cell)
    resp_idx <- cell_idx[is_respondent[cell_idx]]
    sum_all <- sum(weights_vec[cell_idx])
    sum_resp <- sum(weights_vec[resp_idx])
    adj_factor <- sum_all / sum_resp
    n_resp_cell <- length(resp_idx)

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

  # ---- 15. Build history entry ---------------------------------------------
  after_stats <- .compute_weight_stats(new_weights[is_respondent])
  current_history <- .get_history(data)

  history_entry <- .make_history_entry(
    step = length(current_history) + 1L,
    operation = "nonresponse_weighting_class",
    weight_col = if (is.null(wt_name)) data@variables$weights else wt_name,
    call_str = call_str,
    parameters = list(
      by_variables = by_names,
      method = method
    ),
    before_stats = before_stats,
    after_stats = after_stats,
    convergence = NULL # non-iterative
  )

  # ---- 16. Build output -----------------------------------------------------
  if (S7::S7_inherits(data, surveycore::survey_nonprob)) {
    # survey_nonprob supports zero weights (validator relaxed in surveycore
    # >= 0.6.1). All rows retained; nonrespondent weights = 0.
    .update_survey_weights(data, new_weights, history_entry, wt_name = wt_name)
  } else {
    # survey_taylor validator requires all weights > 0 — fall back to
    # respondent-only filtering to avoid S7 validation failure.
    resp_rows <- which(is_respondent)
    filtered_design <- data
    filtered_design@data <- plain_df[resp_rows, , drop = FALSE]
    .update_survey_weights(
      filtered_design,
      new_weights[resp_rows],
      history_entry,
      wt_name = wt_name
    )
  }
}
