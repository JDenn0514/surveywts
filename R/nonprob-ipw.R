# R/nonprob-ipw.R
#
# Inverse probability weighting for non-probability samples.
#
# Contents:
#   .fit_participation_propensity() - internal Newton-Raphson engine
#   ipw()                           - user-facing IPW constructor

# ============================================================================
# .fit_participation_propensity()
# ============================================================================

#' @keywords internal
#' @noRd
.fit_participation_propensity <- function(
  selection, nps_data, ref_data, ref_weights, method, maxit, epsilon
) {
  sel_vars <- all.vars(selection)

  # Detect "(Missing)" rows in NPS data (produced by missing_method = "separate").
  # When present, the pseudo-likelihood Hessian is singular if "(Missing)" is
  # treated as either a regular dummy (X_ref column all-zeros) or as the reference
  # level (X_ref intercept = sum of other dummies, so X_ref is collinear). The
  # fix: fit the NR score equations on complete-case NPS rows only; predict for
  # ALL NPS rows by substituting "(Missing)" with the reference baseline level.
  sep_mask <- rep(FALSE, nrow(nps_data))
  for (var in sel_vars) {
    if (is.factor(nps_data[[var]]) || is.character(nps_data[[var]])) {
      sep_mask <- sep_mask | (as.character(nps_data[[var]]) == "(Missing)")
    }
  }
  has_sep <- any(sep_mask)

  nps_fit  <- if (has_sep) nps_data[!sep_mask, , drop = FALSE] else nps_data
  nps_pred <- nps_data

  # Align factor levels: reference is authoritative.
  for (var in sel_vars) {
    if (is.character(ref_data[[var]]) || is.factor(ref_data[[var]])) {
      ref_levs <- sort(unique(as.character(ref_data[[var]][!is.na(ref_data[[var]])])))
      if (has_sep) {
        # Replace "(Missing)" in prediction dataset with the baseline ref level
        pred_col <- as.character(nps_pred[[var]])
        pred_col[pred_col == "(Missing)"] <- ref_levs[1L]
        nps_pred[[var]] <- factor(pred_col, levels = ref_levs)
        nps_fit[[var]]  <- factor(as.character(nps_fit[[var]]), levels = ref_levs)
      } else {
        nps_fit[[var]]  <- factor(nps_data[[var]], levels = ref_levs)
        nps_pred[[var]] <- nps_fit[[var]]
      }
      ref_data[[var]] <- factor(ref_data[[var]], levels = ref_levs)
    }
  }

  X_nps_fit  <- stats::model.matrix(selection, data = nps_fit)
  X_nps_pred <- if (has_sep) stats::model.matrix(selection, data = nps_pred) else X_nps_fit
  X_ref  <- stats::model.matrix(selection, data = ref_data)
  d_ref  <- ref_weights
  gamma  <- rep(0, ncol(X_nps_fit))
  link   <- stats::binomial(link = method)$linkinv
  converged <- FALSE
  delta     <- rep(Inf, ncol(X_nps_fit))

  for (iter in seq_len(maxit)) {
    # Guard: detect NPS score saturation on the PREDICTION matrix (all NPS rows).
    # R's link functions cap at 1 - .Machine$double.eps rather than 1.0 exactly.
    # When NPS is heavily overrepresented, gamma diverges and scores hit this float
    # boundary. Returning early here lets ipw() throw
    # surveywts_error_propensity_scores_degenerate with the correct class.
    eps        <- .Machine$double.eps
    cur_scores <- link(drop(X_nps_pred %*% gamma))
    if (any(cur_scores <= eps | cur_scores >= 1 - eps)) {
      return(list(
        scores      = cur_scores,
        converged   = FALSE,
        final_delta = max(abs(delta))
      ))
    }

    pi_ref <- link(drop(X_ref %*% gamma))
    score  <- colSums(X_nps_fit) - drop(t(X_ref) %*% (d_ref * pi_ref))
    hess   <- -crossprod(X_ref, X_ref * (d_ref * pi_ref * (1 - pi_ref)))
    delta  <- tryCatch(
      solve(hess, score),
      error = function(e) cli::cli_abort(
        c(
          "x" = "Propensity Hessian is singular: {e$message}",
          "i" = "Collinear or degenerate covariates in {.arg selection}.",
          "v" = "Simplify {.arg selection} or check for constant covariate columns."
        ),
        class = "surveywts_error_propensity_hessian_singular"
      )
    )
    gamma <- gamma - delta
    if (max(abs(delta)) < epsilon) {
      converged <- TRUE
      break
    }
  }
  list(
    scores      = link(drop(X_nps_pred %*% gamma)),
    converged   = converged,
    final_delta = max(abs(delta))
  )
}

# ============================================================================
# ipw()
# ============================================================================

#' Inverse probability weighting for non-probability samples
#'
#' @title Inverse Probability Weighting (IPW) for Non-Probability Samples
#'
#' @description
#' Constructs inverse probability weights for a non-probability sample (NPS)
#' by estimating participation propensity via pseudo-likelihood logistic
#' regression. The weights adjust for selection bias by upweighting NPS units
#' that are underrepresented relative to a probability-based reference sample.
#'
#' @param data A `data.frame` containing the non-probability sample.
#' @param reference A `survey_taylor` object representing the probability-based
#'   reference sample. Must have strictly positive design weights.
#' @param selection A one-sided formula (e.g., `~ age + sex`) specifying
#'   the covariates used to model participation propensity. Exactly one of
#'   `selection` and `predictors` must be supplied.
#' @param predictors A character vector of covariate names (e.g.,
#'   `c("age", "sex")`), used as an alternative to `selection`. Exactly one
#'   of `selection` and `predictors` must be supplied. Suitable for
#'   programmatic use (e.g., `lapply()`).
#' @param missing_method How to handle `NA` values in `selection` variables in
#'   `data`. One of:
#'   \describe{
#'     \item{`"omit"` (default)}{Rows with any NA in a selection variable are
#'       dropped before fitting and excluded from `@data`; a warning reports
#'       the count and which variables.}
#'     \item{`"separate"`}{NA values in **factor and character** selection
#'       variables are recoded to an explicit `"(Missing)"` baseline category
#'       so those units still enter the propensity model and receive weights.
#'       **Numeric selection variables with NA values are not supported** —
#'       `ipw()` errors with `surveywts_error_separate_numeric_na`. Convert
#'       the variable to a factor (e.g. with `cut()`) or use
#'       `missing_method = "impute"` instead.}
#'     \item{`"impute"`}{Missing values are imputed via a single iteration of
#'       predictive mean matching using `mice::mice()` (requires the `mice`
#'       package). All NPS units receive weights.}
#'   }
#'   Regardless of `missing_method`, NA values in `reference@data` selection
#'   variables are always handled by listwise deletion with a warning.
#' @param mice_args Named list of additional arguments forwarded to
#'   `mice::mice()` when `missing_method = "impute"`. The argument `m` is
#'   fixed at `1` and cannot be overridden — attempting to do so triggers
#'   `surveywts_warning_ipw_mice_m_ignored`. Ignored when `missing_method` is
#'   not `"impute"`.
#' @param method Link function for the propensity model. One of `"logit"`
#'   (default), `"probit"`, or `"cloglog"`. Partial matching is supported.
#' @param maxit Maximum number of Newton-Raphson iterations. Must be >= 1.
#'   Default `25L`.
#' @param epsilon Convergence threshold on the maximum absolute step size.
#'   Must be > 0. Default `1e-8`.
#' @param trim Logical. If `TRUE`, IPW weights are trimmed at
#'   `median(w) + 5 * IQR(w)` after estimation. Default `FALSE`.
#' @param wt_name Name for the output weight column in `@data`. Must be a
#'   non-empty character scalar that does not already exist in `data`.
#'   Default `"ipw_weight"`.
#'
#' @return A `survey_nonprob` object. The `@data` slot contains all original
#'   columns from `data` plus a new column named `wt_name` holding the
#'   (possibly trimmed) IPW weights. When `missing_method = "omit"`, rows with
#'   NA in any selection variable are excluded from `@data`. The
#'   `@reference_sample` slot holds the supplied `reference` design. A history
#'   entry is appended to `@metadata@weighting_history`.
#'
#' @details
#' **Newton-Raphson non-convergence:** If the algorithm does not converge
#' within `maxit` iterations, a `surveywts_warning_propensity_nr_no_convergence`
#' warning is issued and the result from the last iteration is returned.
#' Inspect the data for extreme covariate imbalance or increase `maxit`.
#'
#' @note
#' **Selection on observables:** IPW adjusts only for observable covariates.
#' If important predictors of NPS participation are unmeasured, the resulting
#' weights may be biased.
#'
#' **Common support:** IPW requires that every covariate combination observed
#' in the NPS is also present in the reference. If not, scores approach 1 and
#' weights become uninformative.
#'
#' **Variance under-estimation:** Naive variance estimates from the resulting
#' `survey_nonprob` object do not account for the uncertainty in the estimated
#' propensity scores. Bootstrap variance estimation is recommended.
#'
#' **Weight interpretation:** The IPW weight for unit `i` is
#' `w_i = 1 / P(in NPS | x_i)`. The sum of weights estimates the population
#' size (`N_hat` in the history entry reflects the pre-trim total).
#'
#' **Pre-trim population size:** `estimated_population_size` in the history
#' entry always equals `sum(w)` before trimming, regardless of `trim`.
#'
#' @family propensity
#' @export
#'
#' @references
#' Elliott, M.R. and Valliant, R. (2017). Inference for nonprobability samples.
#' *Statistical Science* **32**(2), 249--264.
#'
#' Chen, Y., Li, P. and Wu, C. (2020). Doubly robust inference with
#' nonprobability survey samples. *Journal of the American Statistical
#' Association* **115**(532), 2011--2021.
#'
#' Lenau, S., Marchetti, S., Munnich, R., Pratesi, M., Salvati, N., Shlomo,
#' N., Schirripa Spagnolo, F. and Zhang, L.-C. (2021). Methods for sampling
#' and inference with non-probability samples. Deliverable D11.8,
#' InGRID-2 project 730998 -- H2020.
#'
#' @examples
#' data(ns_wave1_ipw)
#'
#' # --- GSS 2024 as probability reference ---
#' data(gss_ipw_ref)
#'
#' # Formula interface
#' result1 <- ipw(ns_wave1_ipw, gss_ipw_ref, selection = ~gender + age_group)
#'
#' # Programmatic interface — suitable for lapply()
#' result2 <- ipw(
#'   ns_wave1_ipw,
#'   gss_ipw_ref,
#'   predictors = c("gender", "age_group")
#' )
#'
#' # Inspect weight quality before analysis
#' effective_sample_size(result1)
#' weight_variability(result1)
#'
#' # --- ACS PUMS Wyoming as probability reference ---
#' data(acs_ipw_ref)
#' result_acs <- ipw(
#'   ns_wave1_ipw,
#'   acs_ipw_ref,
#'   selection = ~gender + age_group + race_ethn + educ,
#'   missing_method = "omit"
#' )
#'
#' # --- Pew NPORS 2025 as probability reference ---
#' # ns_wave1_ipw has ~120 NA values in race_ethn; missing_method controls
#' # how these are handled.
#' data(npors_2025_ref)
#'
#' # missing_method = "omit" (default): rows with NA in race_ethn are dropped
#' result_omit <- ipw(
#'   ns_wave1_ipw,
#'   npors_2025_ref,
#'   selection = ~gender + age_group + race_ethn + educ,
#'   missing_method = "omit"
#' )
#'
#' # missing_method = "separate": NA recoded to "(Missing)" level; all rows kept
#' result_sep <- ipw(
#'   ns_wave1_ipw,
#'   npors_2025_ref,
#'   selection = ~gender + age_group + race_ethn + educ,
#'   missing_method = "separate"
#' )
#'
#' # missing_method = "impute": NA imputed via mice::mice() (requires mice)
#' if (requireNamespace("mice", quietly = TRUE)) {
#'   result_imp <- ipw(
#'     ns_wave1_ipw,
#'     npors_2025_ref,
#'     selection = ~gender + age_group + race_ethn + educ,
#'     missing_method = "impute"
#'   )
#' }
ipw <- function(
  data,
  reference,
  selection      = NULL,
  predictors     = NULL,
  missing_method = c("omit", "separate", "impute"),
  mice_args      = list(),
  method         = "logit",
  maxit          = 25L,
  epsilon        = 1e-8,
  trim           = FALSE,
  wt_name        = "ipw_weight"
) {
  # Behavior Rule 0: partial-match method
  method <- match.arg(method, c("logit", "probit", "cloglog"))

  # Behavior Rule 0a: conflict check
  if (!is.null(selection) && !is.null(predictors)) {
    cli::cli_abort(
      c(
        "x" = "Only one of {.arg selection} and {.arg predictors} may be supplied.",
        "i" = "Both were non-NULL.",
        "v" = "Use {.arg selection} for a formula or {.arg predictors} for a character vector."
      ),
      class = "surveywts_error_selection_conflict"
    )
  }

  # Behavior Rule 0b: missing check
  if (is.null(selection) && is.null(predictors)) {
    cli::cli_abort(
      c(
        "x" = "One of {.arg selection} or {.arg predictors} must be supplied.",
        "i" = "Both were NULL.",
        "v" = paste0(
          "Provide a formula via {.arg selection} ",
          "(e.g., {.code selection = ~age + sex}) or a character vector via ",
          "{.arg predictors} (e.g., {.code predictors = c(\"age\", \"sex\")})."
        )
      ),
      class = "surveywts_error_selection_missing"
    )
  }

  # Behavior Rule 0c: build selection from predictors
  if (!is.null(predictors)) {
    selection <- stats::reformulate(predictors)
    environment(selection) <- baseenv()
  }

  # Behavior Rule 1: validate data is data.frame
  if (!is.data.frame(data)) {
    cli::cli_abort(
      c(
        "x" = "{.arg data} must be a {.cls data.frame}.",
        "i" = "Got {.cls {class(data)[[1L]]}}.",
        "v" = "Pass a plain {.cls data.frame} as the non-probability sample."
      ),
      class = "surveywts_error_not_data_frame"
    )
  }

  # Behavior Rule 2: validate reference is survey_taylor
  if (!S7::S7_inherits(reference, surveycore::survey_taylor)) {
    cli::cli_abort(
      c(
        "x" = "{.arg reference} must be a {.cls survey_taylor} object.",
        "i" = "Got {.cls {class(reference)[[1L]]}}.",
        "v" = paste0(
          "Pass a probability-based {.cls survey_taylor} design as the reference. ",
          "Use {.fn surveycore::as_survey} to construct one from a data frame."
        )
      ),
      class = "surveywts_error_svydesign_not_taylor"
    )
  }

  # Behavior Rule 3: extract reference weights and validate > 0
  ref_wt_col <- reference@variables$weights
  ref_weights <- reference@data[[ref_wt_col]]
  n_nonpos <- sum(ref_weights <= 0, na.rm = TRUE)
  if (n_nonpos > 0L) {
    cli::cli_abort(
      c(
        "x" = paste0(
          "{.arg reference} weight column {.field {ref_wt_col}} contains ",
          "{n_nonpos} non-positive value(s)."
        ),
        "i" = "All reference design weights must be strictly positive (> 0).",
        "v" = "Remove or replace non-positive weights in the reference design."
      ),
      class = "surveywts_error_reference_weights_nonpositive"
    )
  }

  # Behavior Rule 4: validate nrow(data) > 0
  if (nrow(data) == 0L) {
    cli::cli_abort(
      c(
        "x" = "{.arg data} has 0 rows.",
        "i" = "The non-probability sample must have at least one row.",
        "v" = "Check that {.arg data} contains the intended sample."
      ),
      class = "surveywts_error_empty_data"
    )
  }

  # Behavior Rule 5: validate selection formula
  .validate_formula(selection)

  # Behavior Rule 6: validate selection variables exist in data
  .validate_formula_variables(selection, data, "data")

  # Behavior Rule 7: validate selection variables exist in reference@data
  .validate_formula_variables(
    selection, reference@data, "reference",
    error_class = "surveywts_error_formula_variable_not_in_reference"
  )

  # Behavior Rule 8: factor/character level alignment
  sel_vars <- all.vars(selection)
  for (var in sel_vars) {
    nps_col <- data[[var]]
    ref_col <- reference@data[[var]]
    if (is.character(nps_col) || is.factor(nps_col)) {
      nps_levels <- unique(as.character(nps_col[!is.na(nps_col)]))
      ref_levels <- unique(as.character(ref_col[!is.na(ref_col)]))
      orphaned   <- setdiff(nps_levels, ref_levels)
      if (length(orphaned) > 0L) {
        lev <- orphaned[[1L]]
        cli::cli_abort(
          c(
            "x" = paste0(
              "Level {.val {lev}} of variable {.field {var}} is present in ",
              "{.arg data} but not in {.arg reference}."
            ),
            "i" = paste0(
              "Propensity estimation requires all NPS covariate levels ",
              "to appear in the reference design."
            ),
            "v" = paste0(
              "Remove NPS rows with {.field {var}} = {.val {lev}}, or add ",
              "reference units with that level."
            )
          ),
          class = "surveywts_error_propensity_level_not_in_reference"
        )
      }
    }
  }

  # Behavior Rule 9: coerce missing_method
  missing_method <- match.arg(missing_method)

  # Behavior Rule 9a: Reference NA handling (always listwise regardless of missing_method)
  ref_data_for_fit <- reference@data
  ref_weights_for_fit <- ref_weights
  ref_na_mask <- Reduce("|", lapply(sel_vars, function(v) is.na(ref_data_for_fit[[v]])))
  if (any(ref_na_mask)) {
    n_na_ref <- sum(ref_na_mask)
    na_vars_ref <- sel_vars[
      vapply(sel_vars, function(v) any(is.na(ref_data_for_fit[[v]])), logical(1L))
    ]
    cli::cli_warn(
      c(
        "!" = paste0(
          "{n_na_ref} reference row(s) excluded from model fitting: NA in ",
          "{.and {.field {na_vars_ref}}}."
        ),
        "i" = "Reference NAs are always removed by listwise deletion regardless of {.arg missing_method}.",
        "v" = paste0(
          "Remove or impute NA values in {.arg reference} before calling ",
          "{.fn ipw} to avoid this warning."
        )
      ),
      class = "surveywts_warning_ipw_reference_na_omitted"
    )
    ref_data_for_fit <- ref_data_for_fit[!ref_na_mask, , drop = FALSE]
    ref_weights_for_fit <- ref_weights_for_fit[!ref_na_mask]
  }

  # Behavior Rules 9b / 9c / 9d: NPS NA handling
  if (missing_method == "omit") {
    # Rule 9b: drop rows with any NA in any selection variable
    nps_na_mask <- Reduce("|", lapply(sel_vars, function(v) is.na(data[[v]])))
    if (any(nps_na_mask)) {
      n_na_nps <- sum(nps_na_mask)
      na_vars_nps <- sel_vars[
        vapply(sel_vars, function(v) any(is.na(data[[v]])), logical(1L))
      ]
      cli::cli_warn(
        c(
          "!" = paste0(
            "{n_na_nps} row(s) in {.arg data} dropped: NA in ",
            "{.and {.field {na_vars_nps}}}."
          ),
          "i" = paste0(
            "Rows with any NA in a {.arg selection} variable are excluded when ",
            "{.code missing_method = \"omit\"}."
          ),
          "v" = paste0(
            "Use {.code missing_method = \"separate\"} or ",
            "{.code missing_method = \"impute\"} to retain rows with NA."
          )
        ),
        class = "surveywts_warning_ipw_data_na_omitted"
      )
      data <- data[!nps_na_mask, , drop = FALSE]
    }
  } else if (missing_method == "separate") {
    # Rule 9c: recode factor/character NA → "(Missing)" baseline; error on numeric NA
    for (var in sel_vars) {
      col <- data[[var]]
      if (any(is.na(col))) {
        if (is.numeric(col)) {
          n_na <- sum(is.na(col))
          cli::cli_abort(
            c(
              "x" = paste0(
                "{.code missing_method = \"separate\"} cannot handle numeric ",
                "selection variables with NA values."
              ),
              "i" = paste0(
                "Variable {.field {var}} is {.cls numeric} and has ",
                "{n_na} NA value(s)."
              ),
              "v" = paste0(
                "Convert {.field {var}} to a factor (e.g., with {.fn cut}) or ",
                "use {.code missing_method = \"impute\"} instead."
              )
            ),
            class = "surveywts_error_separate_numeric_na"
          )
        }
        # Factor or character: recode NA → "(Missing)" so the caller can track
        # which rows had missing data. The helper handles these rows separately
        # (fitting on complete-case NPS rows only, predicting for all).
        char_col <- as.character(col)
        char_col[is.na(char_col)] <- "(Missing)"
        existing_levels <- sort(unique(char_col[char_col != "(Missing)"]))
        data[[var]] <- factor(char_col, levels = c("(Missing)", existing_levels))
      }
    }
  } else {
    # Rule 9d: missing_method == "impute" — single-iteration PMM via mice
    if (!.has_package("mice")) {
      cli::cli_abort(
        c(
          "x" = paste0(
            "Package {.pkg mice} is required for ",
            "{.code missing_method = \"impute\"}."
          ),
          "i" = "{.pkg mice} is not installed.",
          "v" = paste0(
            "Install it with {.code install.packages(\"mice\")} then re-run ",
            "{.fn ipw}."
          )
        ),
        class = "surveywts_error_mice_not_installed"
      )
    }
    na_vars_nps <- sel_vars[
      vapply(sel_vars, function(v) any(is.na(data[[v]])), logical(1L))
    ]
    if (length(na_vars_nps) > 0L) {
      if ("m" %in% names(mice_args)) {
        cli::cli_warn(
          c(
            "!" = paste0(
              "{.arg m} in {.arg mice_args} is ignored: ",
              "{.fn mice::mice} is always called with {.code m = 1L}."
            ),
            "i" = "Single imputation ({.code m = 1}) is used for propensity model fitting.",
            "v" = "Remove {.arg m} from {.arg mice_args} to suppress this warning."
          ),
          class = "surveywts_warning_ipw_mice_m_ignored"
        )
        mice_args[["m"]] <- NULL
      }
      impute_df <- data[, sel_vars, drop = FALSE]
      # mice requires factor type for categorical variables. Convert character
      # columns to factor so mice can properly impute NA values; convert back
      # after completing the imputed dataset.
      original_char_vars <- sel_vars[
        vapply(sel_vars, function(v) is.character(impute_df[[v]]), logical(1L))
      ]
      for (v in original_char_vars) {
        impute_df[[v]] <- factor(impute_df[[v]])
      }
      imp <- do.call(
        mice::mice,
        c(list(data = impute_df, m = 1L, method = "pmm", printFlag = FALSE), mice_args)
      )
      completed <- mice::complete(imp, 1L)
      for (v in na_vars_nps) {
        if (v %in% original_char_vars) {
          data[[v]] <- as.character(completed[[v]])
        } else {
          data[[v]] <- completed[[v]]
        }
      }
    }
  }

  # Behavior Rule 10: validate wt_name
  .validate_wt_name(wt_name)

  # Behavior Rule 11: check wt_name conflict with existing columns
  if (wt_name %in% names(data)) {
    cli::cli_abort(
      c(
        "x" = paste0(
          "{.arg wt_name} {.val {wt_name}} already exists as a column in ",
          "{.arg data}."
        ),
        "i" = "The output weight column must be distinct from all input columns.",
        "v" = "Choose a different {.arg wt_name}."
      ),
      class = "surveywts_error_wt_name_conflict"
    )
  }

  # Behavior Rule 12: validate maxit >= 1L
  if (!is.numeric(maxit) || length(maxit) != 1L || is.na(maxit) ||
      as.integer(maxit) < 1L) {
    cli::cli_abort(
      c(
        "x" = "{.arg maxit} must be a whole number >= 1.",
        "i" = "Got {.val {maxit}}.",
        "v" = "Set {.arg maxit} to a positive integer (e.g., {.code maxit = 25L})."
      ),
      class = "surveywts_error_propensity_invalid_maxit"
    )
  }

  # Behavior Rule 13: validate epsilon > 0
  if (!is.numeric(epsilon) || length(epsilon) != 1L || is.na(epsilon) ||
      epsilon <= 0) {
    cli::cli_abort(
      c(
        "x" = "{.arg epsilon} must be a positive number.",
        "i" = "Got {.val {epsilon}}.",
        "v" = "Set {.arg epsilon} to a small positive value (e.g., {.code epsilon = 1e-8})."
      ),
      class = "surveywts_error_propensity_invalid_epsilon"
    )
  }

  # Behavior Rule 14: fit propensity model; check convergence
  fit <- .fit_participation_propensity(
    selection   = selection,
    nps_data    = data,
    ref_data    = ref_data_for_fit,
    ref_weights = ref_weights_for_fit,
    method      = method,
    maxit       = as.integer(maxit),
    epsilon     = epsilon
  )
  if (!fit$converged) {
    cli::cli_warn(
      c(
        "!" = paste0(
          "Newton-Raphson did not converge after {maxit} iterations ",
          "(max |delta| = {round(fit$final_delta, 6)})."
        ),
        "i" = "Propensity scores from the last iteration are returned.",
        "v" = paste0(
          "Increase {.arg maxit}, relax {.arg epsilon}, or check for ",
          "extreme covariate imbalance between {.arg data} and {.arg reference}."
        )
      ),
      class = "surveywts_warning_propensity_nr_no_convergence"
    )
  }

  # Behavior Rule 15: validate scores - none at the float boundary of (0, 1).
  # R link functions (logit, probit, cloglog) cap at 1 - .Machine$double.eps
  # rather than returning exactly 1. A score at that boundary indicates the
  # linear predictor overflowed, which happens when the NR has diverged due to
  # extreme NPS/reference imbalance.
  scores <- fit$scores
  .eps   <- .Machine$double.eps
  if (any(scores <= .eps | scores >= 1 - .eps)) {
    n_degen <- sum(scores <= .eps | scores >= 1 - .eps)
    cli::cli_abort(
      c(
        "x" = paste0(
          "{n_degen} propensity score(s) saturate at the floating-point ",
          "boundary of (0, 1)."
        ),
        "i" = paste0(
          "Scores at or beyond the float boundary indicate that the ",
          "Newton-Raphson has diverged due to extreme NPS/reference imbalance: ",
          "the NPS is so overrepresented in some covariate cells that no ",
          "valid participation propensity exists."
        ),
        "v" = paste0(
          "Review covariate distributions in {.arg data} and {.arg reference}. ",
          "Consider trimming extreme NPS units or using a simpler {.arg selection}."
        )
      ),
      class = "surveywts_error_propensity_scores_degenerate"
    )
  }

  # Behavior Rule 16: warn if any score < 0.01
  if (any(scores < 0.01)) {
    n_extreme <- sum(scores < 0.01)
    cli::cli_warn(
      c(
        "!" = paste0(
          "{n_extreme} propensity score(s) are below 0.01, ",
          "producing extreme IPW weights (> 100)."
        ),
        "i" = paste0(
          "Very low participation propensity scores indicate NPS units ",
          "with covariate combinations that are rare in the NPS but ",
          "common in the reference."
        ),
        "v" = paste0(
          "Consider trimming ({.code trim = TRUE}) or reviewing covariate ",
          "balance between {.arg data} and {.arg reference}."
        )
      ),
      class = "surveywts_warning_extreme_propensity_scores"
    )
  }

  # Behavior Rule 17: compute weights
  w <- 1 / scores

  # Behavior Rule 18: optionally trim; record n_trimmed
  w_before_trim <- w
  n_trimmed <- 0L
  if (trim) {
    trim_result <- .trim_weights_internal(
      weights     = w,
      lower       = -Inf,
      upper       = stats::median(w) + 5 * stats::IQR(w),
      has_trimmed = rep(FALSE, length(w))
    )
    w         <- trim_result$weights
    n_trimmed <- sum(trim_result$has_trimmed)
  }

  # Behavior Rule 19: record estimated population size (pre-trim)
  estimated_population_size <- sum(w_before_trim)

  # Behavior Rule 20: construct survey_nonprob and append history

  # Step 1 - construct the object (NSE injection for wt_name)
  out_df            <- data
  out_df[[wt_name]] <- w
  result <- surveycore::as_survey_nonprob(
    data             = out_df,
    weights          = !!rlang::sym(wt_name),
    reference_sample = reference
  )

  # Step 2 - build history entry and append
  history_entry <- list(
    step                      = length(.get_history(result)) + 1L,
    timestamp                 = Sys.time(),
    operation                 = "ipw",
    formula                   = selection,
    method                    = method,
    missing_method            = missing_method,
    estimator                 = "ht",
    trim                      = trim,
    n_nps                     = nrow(data),
    n_reference               = nrow(ref_data_for_fit),
    estimated_population_size = estimated_population_size,
    n_trimmed                 = as.integer(n_trimmed),
    reference_design          = reference,
    targets_from_reference    = FALSE
  )
  meta <- result@metadata
  meta@weighting_history <- c(meta@weighting_history, list(history_entry))
  result@metadata <- meta

  result
}
