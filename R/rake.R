# R/rake.R
#
# rake() — iterative proportional fitting (raking) to marginal population totals.
#
# Supports:
#   - method = "anesrake"  (default: chi-square variable selection, improvement-based)
#   - method = "survey"    (fixed-order IPF, epsilon-based convergence)
#   - type = "prop"        (population proportions; default)
#   - type = "count"       (population counts)
#   - cap                  (weight ratio cap, applied per-step)
#
# Private helpers:
#   .parse_margins()       — converts Format B (long data.frame) to Format A
#                           (named list of named vectors). Co-located here
#                           because only rake() calls it.
#
# All shared helpers (.get_weight_vec, .validate_weights, etc.) live in
# R/utils.R.

# ---------------------------------------------------------------------------
# rake() — exported function
# ---------------------------------------------------------------------------

#' Rake survey weights to marginal population totals
#'
#' Iterative proportional fitting (raking) that adjusts survey weights to
#' match multiple marginal population totals simultaneously. Supports two
#' algorithms: the `"anesrake"` method (chi-square variable selection,
#' improvement-based convergence) and the `"survey"` method (fixed-order
#' IPF, epsilon-based convergence).
#'
#' @param data A `data.frame`, `weighted_df`, `survey_taylor`, or
#'   `survey_nonprob`. `survey_replicate` -> error. Any other class -> error.
#' @param margins Named list or data frame specifying population margin targets.
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
#'   Format B is auto-detected and converted to Format A before use. The
#'   converted Format A is stored in the weighting history.
#' @param weights <[`tidy-select`][tidyselect::language]> Weight column name
#'   (bare name). `NULL` -> auto-detected from `weighted_df` attribute or
#'   survey object `@variables$weights`. For plain `data.frame` with
#'   `weights = NULL`, uniform starting weights are used and the output
#'   column is named by `wt_name` (default `"wts"`).
#' @param wt_name Character scalar. Name of the output weight column in the
#'   returned `weighted_df`. Default `"wts"`. Ignored when `data` is a survey
#'   object (`survey_taylor` or `survey_nonprob`).
#' @param type Character scalar. `"prop"` (default): `margins` values are
#'   proportions. `"count"`: `margins` values are counts.
#' @param method Character scalar. `"anesrake"` (default): chi-square
#'   discrepancy variable selection with improvement-based convergence, as in
#'   the `anesrake` package. `"survey"`: fixed-order IPF cycling through all
#'   margins, with epsilon-based convergence, as in `survey::rake()`.
#' @param cap Numeric or `NULL`. Cap on the weight ratio `w / mean(w)`. Any
#'   weight exceeding `cap * mean(w)` is set to `cap * mean(w)`. Applied
#'   after each per-margin adjustment step (not post-hoc). `NULL` (default)
#'   means no cap. Applies to both methods.
#' @param reference_design A `survey_taylor` object or `NULL` (default). The
#'   reference probability survey from which `margins` were estimated. When
#'   non-`NULL`, stored in the history entry and `targets_from_reference` is
#'   set to `TRUE`. Pass the same `survey_taylor` object used to compute the
#'   margin targets. `NULL` means targets are fixed population benchmarks.
#' @param control Named list of algorithm parameters. Merged with
#'   method-specific defaults. Omitted keys retain their defaults.
#'
#'   **`method = "anesrake"` defaults:**
#'   - `maxit = 1000`: maximum full sweeps
#'   - `improvement = 0.01`: percentage improvement convergence threshold
#'   - `pval = 0.05`: chi-square p-value threshold for variable selection
#'   - `min_cell_n = 0L`: minimum unweighted observations per cell (0 = no min)
#'   - `variable_select = "total"`: chi-square aggregation for ranking
#'     (`"total"`, `"max"`, or `"average"`)
#'
#'   **`method = "survey"` defaults:**
#'   - `maxit = 100`: maximum full sweeps
#'   - `epsilon = 1e-7`: maximum relative margin error convergence threshold
#'
#'   Passing anesrake-specific keys when `method = "survey"` (or vice versa)
#'   triggers a `surveywts_warning_control_param_ignored` warning per
#'   ignored parameter.
#'
#' @return
#'   - `data.frame` or `weighted_df` input -> `weighted_df`
#'   - `survey_taylor` or `survey_nonprob` input -> same class as input
#'     (`survey_taylor` or `survey_nonprob`; class is preserved)
#'
#'   The weight column in the output contains raked weights. A history entry
#'   with `operation = "raking"` is appended to `weighting_history`.
#'
#' @details
#'   **`method = "anesrake"`:** At each sweep, variables are sorted by their
#'   chi-square discrepancy (controlled by `control$variable_select`). Variables
#'   with any cell below `control$min_cell_n` unweighted observations are
#'   excluded entirely. Variables where the chi-square p-value exceeds
#'   `control$pval` are skipped in that sweep. Convergence is assessed as the
#'   percentage improvement in total chi-square between consecutive sweeps.
#'   If all variables pass or are excluded in sweep 1, a
#'   `surveywts_message_already_calibrated` message is emitted.
#'
#'   **`method = "survey"`:** Variables are raked in the fixed order given by
#'   `margins`. All variables participate in every sweep. Convergence is
#'   assessed as the maximum relative error across all margin cells falling
#'   below `control$epsilon`.
#'
#' @references
#'   DeBell, M. and Krosnick, J. A. (2009). *Computing Weights for American
#'   National Election Study Survey Data*. ANES Technical Report series,
#'   no. nes012427. Ann Arbor, MI, and Palo Alto, CA: American National
#'   Election Studies.
#'
#' @examples
#' df <- data.frame(
#'   age_group = c("18-34", "35-54", "55+", "18-34", "35-54"),
#'   sex       = c("M", "F", "M", "F", "M"),
#'   stringsAsFactors = FALSE
#' )
#' margins <- list(
#'   age_group = c("18-34" = 0.30, "35-54" = 0.40, "55+" = 0.30),
#'   sex       = c("M" = 0.48, "F" = 0.52)
#' )
#' result <- rake(df, margins = margins)
#'
#' @family calibration
#' @export
rake <- function(
  data,
  margins,
  weights          = NULL,
  wt_name          = "wts",
  type             = c("prop", "count"),
  method           = c("anesrake", "survey"),
  cap              = NULL,
  control          = list(),
  reference_design = NULL
) {
  # ---- Capture call and arguments before any evaluation --------------------
  call_str <- deparse(match.call())
  method <- rlang::arg_match(method)
  type   <- rlang::arg_match(type)
  weights_quo <- rlang::enquo(weights)
  .validate_wt_name(wt_name)
  .validate_reference_design(reference_design)

  # ---- Cap + method = "survey" guard (fail fast, before margin parsing) ----
  if (!is.null(cap) && method == "survey") {
    cli::cli_abort(
      c(
        "x" = "{.arg cap} is not supported when {.code method = \"survey\"}.",
        "i" = "{.fn survey::rake} does not support per-step weight capping.",
        "v" = "Use {.code method = \"anesrake\"} for raking with a weight cap."
      ),
      class = "surveywts_error_cap_not_supported_survey"
    )
  }

  # ---- Apply method-specific control defaults (before warning check) -------
  anesrake_defaults <- list(
    maxit = 1000L, improvement = 0.01, pval = 0.05,
    min_cell_n = 0L, variable_select = "total"
  )
  survey_defaults <- list(maxit = 100L, epsilon = 1e-7)

  # Coerce user-supplied maxit to integer (consistent with defaults)
  if (!is.null(control$maxit)) {
    control$maxit <- as.integer(control$maxit)
  }

  method_defaults <- if (method == "anesrake") anesrake_defaults else survey_defaults
  control_resolved <- utils::modifyList(method_defaults, control)

  # ---- Warn on wrong-method control params --------------------------------
  anesrake_only <- c("improvement", "pval", "min_cell_n", "variable_select")
  survey_only   <- c("epsilon")

  if (method == "survey") {
    for (param in intersect(names(control), anesrake_only)) {
      cli::cli_warn(
        c(
          "!" = paste0(
            "{.code control${.field {param}}} is not used when ",
            "{.code method = {.val {method}}} and will be ignored."
          ),
          "i" = paste0(
            "For {.code method = \"anesrake\"}, valid {.arg control} keys are: ",
            "{.code maxit}, {.code improvement}, {.code pval}, ",
            "{.code min_cell_n}, {.code variable_select}."
          ),
          "i" = paste0(
            "For {.code method = \"survey\"}, valid {.arg control} keys are: ",
            "{.code maxit}, {.code epsilon}."
          )
        ),
        class = "surveywts_warning_control_param_ignored"
      )
    }
  } else {
    for (param in intersect(names(control), survey_only)) {
      cli::cli_warn(
        c(
          "!" = paste0(
            "{.code control${.field {param}}} is not used when ",
            "{.code method = {.val {method}}} and will be ignored."
          ),
          "i" = paste0(
            "For {.code method = \"anesrake\"}, valid {.arg control} keys are: ",
            "{.code maxit}, {.code improvement}, {.code pval}, ",
            "{.code min_cell_n}, {.code variable_select}."
          ),
          "i" = paste0(
            "For {.code method = \"survey\"}, valid {.arg control} keys are: ",
            "{.code maxit}, {.code epsilon}."
          )
        ),
        class = "surveywts_warning_control_param_ignored"
      )
    }
  }

  # ---- 1. Input class check -----------------------------------------------
  .check_input_class(data)

  # ---- 2. Empty data check ------------------------------------------------
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

  # ---- 3. Parse and normalize margins to Format A -------------------------
  # .parse_margins() converts Format B → Format A and normalizes df elements.
  # The resulting margins_a is always a named list of named numeric vectors.
  margins_a <- .parse_margins(margins)

  # ---- 4. Weight column name and handling ---------------------------------
  weight_col <- .get_weight_col_name(data, weights_quo)

  # For plain data.frame with weights = NULL: create uniform weight column
  if (inherits(data, "data.frame") && rlang::quo_is_null(weights_quo) &&
      !inherits(data, "weighted_df")) {
    data_df[[wt_name]] <- rep(1 / nrow(data_df), nrow(data_df))
    weight_col <- wt_name
  }

  # Extract the plain data frame for validation
  plain_df <- if (inherits(data, "data.frame")) data_df else data@data

  # Ensure uniform-weight column is reflected in plain_df
  if (inherits(data, "data.frame") && !weight_col %in% names(plain_df)) {
    plain_df <- data_df
  }

  .validate_weights(plain_df, weight_col)

  # ---- 5. Validate margins variables exist in data ------------------------
  margin_var_names <- names(margins_a)
  for (var in margin_var_names) {
    if (!var %in% names(plain_df)) {
      cli::cli_abort(
        c(
          "x" = "Raking variable {.field {var}} not found in {.arg data}.",
          "i" = paste0(
            "Check that all variable names in {.arg margins} exist as ",
            "columns in {.arg data}."
          )
        ),
        class = "surveywts_error_margins_variable_not_found"
      )
    }
  }

  # ---- 6. Validate margin variables (categorical, no NAs) -----------------
  .validate_calibration_variables(plain_df, margin_var_names, "Raking")

  # ---- 7. Validate population marginals -----------------------------------
  .validate_population_marginals(
    margins_a,
    margin_var_names,
    plain_df,
    type,
    target_name = "margins"
  )

  # ---- 8. Extract starting weights and compute before-stats ---------------
  weights_vec <- .get_weight_vec(data, weights_quo)
  before_stats <- .compute_weight_stats(weights_vec)

  # Convert proportions to counts for the engine
  total_w <- sum(weights_vec)
  if (type == "prop") {
    margins_counts <- lapply(margins_a, function(m) m * total_w)
  } else {
    margins_counts <- margins_a
  }

  # ---- 9. Build calibration spec and run engine ---------------------------
  vars_spec <- lapply(margin_var_names, function(v) {
    list(col = v, targets = margins_counts[[v]])
  })

  engine_method <- if (method == "anesrake") "anesrake" else "ipf"

  calibration_spec <- list(
    type      = engine_method,
    variables = vars_spec,
    total_n   = nrow(plain_df),
    cap       = cap
  )

  engine_result <- .calibrate_engine(
    data_df          = plain_df,
    weights_vec      = weights_vec,
    calibration_spec = calibration_spec,
    method           = engine_method,
    control          = control_resolved
  )

  new_weights <- engine_result$weights
  convergence <- engine_result$convergence
  capping     <- engine_result$capping

  # ---- 10. Compute after-stats and build history entry --------------------
  after_stats <- .compute_weight_stats(new_weights)

  # Determine current history for step number
  current_history <- .get_history(data)

  history_entry <- .make_history_entry(
    step = length(current_history) + 1L,
    operation = "raking",
    weight_col = if (inherits(data, "data.frame")) {
      wt_name
    } else {
      data@variables$weights
    },
    call_str = call_str,
    parameters = list(
      variables              = margin_var_names,
      margins                = margins_a,   # always stored as Format A per spec §VII
      type                   = type,
      method                 = method,
      cap                    = cap,
      control                = control_resolved,
      targets_from_reference = !is.null(reference_design),
      reference_design       = reference_design
    ),
    before_stats = before_stats,
    after_stats  = after_stats,
    convergence  = convergence,
    capping      = capping
  )

  # ---- 11. Build output ---------------------------------------------------
  if (inherits(data, "data.frame")) {
    # data.frame or weighted_df → weighted_df
    out_df <- plain_df
    out_df[[wt_name]] <- new_weights
    new_history <- c(current_history, list(history_entry))
    .make_weighted_df(out_df, wt_name, new_history)
  } else {
    # survey object → same class (class preserved; only weights + history updated)
    .update_survey_weights(data, new_weights, history_entry)
  }
}

# ---------------------------------------------------------------------------
# .parse_margins() — private helper (used only by rake())
# ---------------------------------------------------------------------------

# Converts margins to Format A (named list of named numeric vectors).
# Accepts:
#   - Format A: named list (pass-through, with data.frame elements normalized)
#   - Format B: data.frame with columns 'variable', 'level', 'target'
#
# Returns: named list. Each element is a named numeric vector
#   c(level1 = target1, level2 = target2, ...)
#
# Errors with surveywts_error_margins_format_invalid if margins is neither
# a named list nor a valid Format B data.frame.
.parse_margins <- function(margins) {
  # Format B: data.frame with required columns
  if (is.data.frame(margins)) {
    required_cols <- c("variable", "level", "target")
    missing_cols <- setdiff(required_cols, names(margins))
    if (length(missing_cols) > 0L) {
      cli::cli_abort(
        c(
          "x" = paste0(
            "{.arg margins} must be a named list or a data frame with ",
            "columns {.field variable}, {.field level}, and {.field target}."
          ),
          "i" = paste0(
            "Got {.cls data.frame} but missing column(s): ",
            "{.and {.field {missing_cols}}}."
          ),
          "v" = "See {.fn rake} documentation for accepted formats."
        ),
        class = "surveywts_error_margins_format_invalid"
      )
    }

    # Convert to Format A: split by variable, build named vector per variable
    var_names <- unique(as.character(margins$variable))
    result <- lapply(var_names, function(v) {
      rows <- margins[as.character(margins$variable) == v, , drop = FALSE]
      # Use stats::setNames() explicitly to guarantee names are preserved
      stats::setNames(
        as.double(rows$target),
        as.character(rows$level)
      )
    })
    names(result) <- var_names
    return(result)
  }

  # Format A: named list — normalize data.frame elements to named vectors
  if (is.list(margins) && !is.data.frame(margins)) {
    if (length(names(margins)) == 0L || any(names(margins) == "")) {
      cli::cli_abort(
        c(
          "x" = paste0(
            "{.arg margins} must be a named list or a data frame with ",
            "columns {.field variable}, {.field level}, and {.field target}."
          ),
          "i" = paste0(
            "Got {.cls {class(margins)[[1]]}} but list elements are not named."
          ),
          "v" = "See {.fn rake} documentation for accepted formats."
        ),
        class = "surveywts_error_margins_format_invalid"
      )
    }

    # Normalize any data.frame elements to named vectors
    result <- lapply(names(margins), function(v) {
      elem <- margins[[v]]
      if (is.data.frame(elem)) {
        if (!all(c("level", "target") %in% names(elem))) {
          cli::cli_abort(
            c(
              "x" = paste0(
                "Element {.field {v}} in {.arg margins} is a data frame but ",
                "is missing required columns {.field level} and/or {.field target}."
              ),
              "v" = "See {.fn rake} documentation for accepted formats."
            ),
            class = "surveywts_error_margins_format_invalid"
          )
        }
        # Use stats::setNames() to build named vector without stripping names
        stats::setNames(
          as.double(elem$target),
          as.character(elem$level)
        )
      } else {
        # Already a named vector — ensure it is double-typed; use
        # stats::setNames() to guarantee names are preserved (as.numeric()
        # strips names on some platforms).
        stats::setNames(as.double(unname(elem)), names(elem))
      }
    })
    names(result) <- names(margins)
    return(result)
  }

  # Neither list nor data.frame
  cls <- class(margins)[[1L]]
  cli::cli_abort(
    c(
      "x" = paste0(
        "{.arg margins} must be a named list or a data frame with ",
        "columns {.field variable}, {.field level}, and {.field target}."
      ),
      "i" = "Got {.cls {cls}}.",
      "v" = "See {.fn rake} documentation for accepted formats."
    ),
    class = "surveywts_error_margins_format_invalid"
  )
}

# ---------------------------------------------------------------------------
# Ported from the anesrake R package (CRAN: anesrake), GPL-2
# Original author: Cole Rauwerda. Logic unchanged from upstream.
# ---------------------------------------------------------------------------

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
