# R/replicate-weights.R
#
# create_bootstrap_weights(), create_jackknife_weights(),
# create_brr_weights(), create_gen_boot_weights(),
# create_gen_rep_weights(), create_sdr_weights()
# and all shared internal helpers.

# ============================================================================
# .validate_replicate_input()
# ============================================================================

.validate_replicate_input <- function(data) {
  if (inherits(data, "data.frame") || inherits(data, "weighted_df")) {
    cli::cli_abort(
      c(
        "x" = "{.arg data} is a {.cls {class(data)[[1]]}}, not a survey design.",
        "i" = "This function requires a {.cls survey_taylor} or {.cls survey_nonprob} object.",
        "v" = "Convert with {.fn surveycore::as_survey}."
      ),
      class = "surveywts_error_not_survey_design"
    )
  }
  if (S7::S7_inherits(data, surveycore::survey_replicate)) {
    cli::cli_abort(
      c(
        "x" = "{.arg data} is already a {.cls survey_replicate}.",
        "i" = "Replicate weights cannot be created from a design that already has replicates."
      ),
      class = "surveywts_error_already_replicate"
    )
  }
  if (!S7::S7_inherits(data, surveycore::survey_base)) {
    cls <- class(data)[[1L]]
    cli::cli_abort(
      c(
        "x" = "{.arg data} is {.cls {cls}}, which is not a supported input class.",
        "i" = "Supported classes: {.cls survey_taylor} and {.cls survey_nonprob}.",
        "v" = "Use {.fn surveycore::as_survey} or {.fn surveycore::survey_nonprob}."
      ),
      class = "surveywts_error_unsupported_class"
    )
  }
  invisible(TRUE)
}

# ============================================================================
# .validate_replicates_arg()
# ============================================================================

# Validates the `replicates` argument: accepts whole numbers, coerces to
# integer. Returns NULL if replicates is NULL (caller handles the NULL case).
# min_val defaults to 2; SDR passes min_val = 4.
.validate_replicates_arg <- function(replicates, min_val = 2L) {
  if (is.null(replicates)) return(NULL)
  if (!is.numeric(replicates) || length(replicates) != 1L || is.na(replicates)) {
    cli::cli_abort(
      c("x" = "{.arg replicates} must be a single number."),
      class = "surveywts_error_replicates_invalid"
    )
  }
  if (replicates %% 1 != 0) {
    cli::cli_abort(
      c(
        "x" = "{.arg replicates} must be a whole number, not {.val {replicates}}.",
        "v" = "Use an integer value, e.g. {.code replicates = {round(replicates)}}."
      ),
      class = "surveywts_error_replicates_not_whole_number"
    )
  }
  if (replicates < min_val) {
    cli::cli_abort(
      c(
        "x" = "{.arg replicates} must be at least {min_val}, got {.val {replicates}}."
      ),
      class = "surveywts_error_replicates_not_positive"
    )
  }
  as.integer(replicates)
}

# ============================================================================
# .snapshot_variables_for_history()
# ============================================================================

# Captures the full @variables list and a nonprob flag for the
# "replicate_creation" history entry. Used by as_taylor_design() to
# reconstruct the original Taylor design and detect nonprob sources.
# A boolean is used instead of a class string because attr(cls, "package")
# is unreliable for S7 classes and could produce "::survey_nonprob" if NULL.
.snapshot_variables_for_history <- function(data) {
  list(
    variables = data@variables,
    is_nonprob = S7::S7_inherits(data, surveycore::survey_nonprob)
  )
}

# ============================================================================
# .convert_and_call()
# ============================================================================

# Core conversion pipeline. Converts S7 design to svydesign, calls backend_fn,
# then manually constructs survey_replicate (bypassing from_svydesign() which
# has a bug in surveycore <= 0.8.2 where @variables$repweights is not populated).
#
# Arguments:
#   data       : survey_taylor or survey_nonprob
#   backend_fn : function(svydesign) -> svyrep.design
#   method     : character(1) — e.g. "bootstrap", "jackknife"
#   params     : named list of method-specific parameters for the history entry
#   seed       : integer(1) or NULL — if non-NULL, withr::local_seed() is used
.convert_and_call <- function(data, backend_fn, method, params, seed = NULL) {
  if (!is.null(seed)) withr::local_seed(seed)

  # survey_nonprob doesn't support as_svydesign(); build a simple SRS-weighted
  # design from the raw data and base weights so svrep can consume it.
  if (S7::S7_inherits(data, surveycore::survey_nonprob)) {
    wt_col        <- data@variables$weights
    wt_formula    <- stats::as.formula(paste0("~", wt_col))
    svydesign_obj <- survey::svydesign(ids = ~1, weights = wt_formula, data = data@data)
  } else {
    svydesign_obj <- surveycore::as_svydesign(data)
  }

  svyrep_obj    <- backend_fn(svydesign_obj)

  # Extract replicate weight matrix. Both `matrix` (svrep bootstrap, gen-boot,
  # gen-rep) and `repweights_compressed` (survey JKn/BRR, svrep random-group JK)
  # support as.matrix().
  rep_matrix  <- as.matrix(svyrep_obj$repweights)
  n_rep       <- ncol(rep_matrix)
  rep_names   <- paste0("rep_", seq_len(n_rep))

  base_data   <- as.data.frame(svyrep_obj$variables)
  rep_df      <- as.data.frame(rep_matrix)
  names(rep_df) <- rep_names
  combined    <- cbind(base_data, rep_df)

  variables   <- list(
    weights    = data@variables$weights,
    repweights = rep_names,
    type       = svyrep_obj$type,
    scale      = svyrep_obj$scale,
    rscales    = svyrep_obj$rscales,
    fpc        = data@variables$fpc,
    fpctype    = if (!is.null(svyrep_obj$fpctype)) svyrep_obj$fpctype else "fraction",
    mse        = isTRUE(svyrep_obj$mse)
  )

  result    <- surveycore::survey_replicate(
    data      = combined,
    variables = variables,
    metadata  = data@metadata
  )

  # Append replicate_creation history entry. Snapshot the full @variables so
  # as_taylor_design() can reconstruct the original Taylor design.
  snapshot  <- .snapshot_variables_for_history(data)
  new_entry <- list(
    step          = length(data@metadata@weighting_history) + 1L,
    operation     = "replicate_creation",
    timestamp     = Sys.time(),
    method        = method,
    parameters    = params,
    source_design = snapshot
  )
  meta                      <- result@metadata
  meta@weighting_history    <- c(meta@weighting_history, list(new_entry))
  result@metadata           <- meta

  result
}

# ============================================================================
# create_bootstrap_weights()
# ============================================================================

#' Create bootstrap replicate weights
#'
#' Generates bootstrap replicate weights via [svrep::as_bootstrap_design()].
#' Both `survey_taylor` and `survey_nonprob` inputs are supported.
#'
#' @param data A `survey_taylor` or `survey_nonprob` design object.
#' @param replicates `integer(1)`, default `500L`. Number of bootstrap
#'   replicates. Must be >= 2. Whole-number doubles are coerced silently.
#' @param ... Must be empty. Forces all subsequent arguments to be named.
#' @param type `character(1)`. Bootstrap variant passed to
#'   [svrep::as_bootstrap_design()]. One of `"Rao-Wu-Yue-Beaumont"` (default),
#'   `"Rao-Wu"`, `"Antal-Tille"`, `"Preston"`, or `"Canty-Davison"`.
#' @param mse `logical(1)`, default `TRUE`. If `TRUE`, variance is estimated
#'   as the deviation from the full-sample estimate.
#' @param seed `integer(1)` or `NULL`. If non-`NULL`, sets the RNG seed via
#'   [withr::local_seed()] for the duration of the call; caller's RNG state is
#'   restored on exit.
#'
#' @return A `survey_replicate` with `replicates` new `rep_1...rep_N` columns,
#'   `@variables$type = "bootstrap"`, and a `"replicate_creation"` entry in the
#'   weighting history.
#'
#' @family replicate-weights
#' @export
create_bootstrap_weights <- function(
  data,
  replicates = 500L,
  ...,
  type = c(
    "Rao-Wu-Yue-Beaumont", "Rao-Wu", "Antal-Tille",
    "Preston", "Canty-Davison"
  ),
  mse = TRUE,
  seed = NULL
) {
  .validate_replicate_input(data)
  replicates <- .validate_replicates_arg(replicates)
  type       <- rlang::arg_match(type)

  .convert_and_call(
    data       = data,
    backend_fn = function(d) {
      svrep::as_bootstrap_design(d, type = type, replicates = replicates, mse = mse)
    },
    method     = "bootstrap",
    params     = list(type = type, replicates = replicates, mse = mse),
    seed       = seed
  )
}

# ============================================================================
# create_jackknife_weights()
# ============================================================================

#' Create jackknife replicate weights
#'
#' Generates jackknife replicate weights via [survey::as.svrepdesign()] (for
#' delete-1) or [svrep::as_random_group_jackknife_design()] (for random-groups).
#'
#' @param data A `survey_taylor` or `survey_nonprob` design. `survey_nonprob`
#'   supports `type = "delete-1"` only.
#' @param replicates `integer(1)` or `NULL`. Number of random groups when
#'   `type = "random-groups"`. Required for random-groups; ignored for
#'   delete-1.
#' @param ... Must be empty.
#' @param type `character(1)`. `"delete-1"` (default): one replicate per PSU,
#'   auto-selecting JK1 (unstratified) or JKn (stratified). `"random-groups"`:
#'   PSUs randomly divided into `replicates` groups.
#' @param mse `logical(1)`, default `TRUE`.
#' @param seed `integer(1)` or `NULL`. RNG seed for random-group assignment
#'   (ignored for delete-1).
#'
#' @return A `survey_replicate` with `@variables$type` of `"JK1"` or `"JKn"`.
#'
#' @family replicate-weights
#' @export
create_jackknife_weights <- function(
  data,
  replicates = NULL,
  ...,
  type = c("delete-1", "random-groups"),
  mse = TRUE,
  seed = NULL
) {
  .validate_replicate_input(data)
  type <- rlang::arg_match(type)

  # nonprob + random-groups: error first (before replicates validation)
  if (S7::S7_inherits(data, surveycore::survey_nonprob) &&
        type == "random-groups") {
    cli::cli_abort(
      c(
        "x" = paste0(
          "{.cls survey_nonprob} input is not supported with ",
          "{.code type = \"random-groups\"}."
        ),
        "i" = "Only {.code type = \"delete-1\"} is supported for non-probability designs.",
        "v" = "Use {.code type = \"delete-1\"} or convert to {.cls survey_taylor}."
      ),
      class = "surveywts_error_jackknife_type_unsupported_for_nonprob"
    )
  }

  if (type == "random-groups") {
    if (is.null(replicates)) {
      cli::cli_abort(
        c(
          "x" = "{.arg replicates} is required when {.code type = \"random-groups\"}.",
          "v" = "Supply an integer, e.g. {.code replicates = 20L}."
        ),
        class = "surveywts_error_replicates_required_for_jkn"
      )
    }
    replicates <- .validate_replicates_arg(replicates)
    .convert_and_call(
      data       = data,
      backend_fn = function(d) {
        svrep::as_random_group_jackknife_design(d, replicates = replicates, mse = mse)
      },
      method     = "jackknife",
      params     = list(type = "random-groups", replicates = replicates, mse = mse),
      seed       = seed
    )
  } else {
    # delete-1: auto-detect JK1 (no strata) vs JKn (has strata)
    jk_type <- if (is.null(data@variables$strata)) "JK1" else "JKn"
    .convert_and_call(
      data       = data,
      backend_fn = function(d) {
        survey::as.svrepdesign(d, type = jk_type, mse = mse)
      },
      method     = "jackknife",
      params     = list(type = jk_type, mse = mse)
    )
  }
}
