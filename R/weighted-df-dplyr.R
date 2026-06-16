# R/weighted-df-dplyr.R
#
# weighted_df S3 class definition.
#
# Includes:
#   - dplyr_reconstruct.weighted_df() — dplyr compat (filter, mutate, direct calls)
#   - select.weighted_df()            — dplyr 1.2.0 col-select path
#   - rename.weighted_df()            — detect weight col rename
#   - mutate.weighted_df()            — detect post-.keep weight col removal
#   - .reconstruct_weighted_df()      — internal helper shared by all dplyr methods
#
# print.weighted_df() lives in R/methods-print.R.
# .format_history_step() lives in R/utils.R (moved in PR 4).
# survey_nonprob is defined in surveycore, not here.

# ---------------------------------------------------------------------------
# dplyr_reconstruct.weighted_df()
# Called by filter() (via dplyr_row_slice), mutate() (via dplyr_col_modify),
# and direct dplyr_reconstruct() calls.  In dplyr >= 1.2.0, select() uses
# dplyr_col_select which does NOT call dplyr_reconstruct for tibble subclasses;
# that case is handled by select.weighted_df() below.
# ---------------------------------------------------------------------------

#' @importFrom dplyr dplyr_reconstruct
#' @export
dplyr_reconstruct.weighted_df <- function(data, template) {
  .reconstruct_weighted_df(data, template)
}

# ---------------------------------------------------------------------------
# select.weighted_df()
# In dplyr >= 1.2.0, select() uses dplyr_col_select() which bypasses
# dplyr_reconstruct for tibble subclasses (uses C-level vectbl_restore instead).
# This method restores correct behavior.
# Registered via @rawNamespace to avoid documentation requirement on the method.
# ---------------------------------------------------------------------------

#' @importFrom dplyr select
#' @export
select.weighted_df <- function(.data, ...) {
  result <- NextMethod()
  .reconstruct_weighted_df(result, .data)
}

# ---------------------------------------------------------------------------
# rename.weighted_df()
# rename.data.frame uses set_names() which preserves all attributes but makes
# the weight_col attribute stale when the weight column is renamed.
# ---------------------------------------------------------------------------

#' @importFrom dplyr rename
#' @export
rename.weighted_df <- function(.data, ...) {
  result <- NextMethod()
  .reconstruct_weighted_df(result, .data)
}

# ---------------------------------------------------------------------------
# mutate.weighted_df()
# dplyr_col_modify (used by mutate) calls dplyr_reconstruct BEFORE the .keep
# filter is applied.  When .keep = "unused" drops the weight column,
# dplyr_reconstruct sees all columns (passes), but the final result is missing
# the weight column.  This wrapper runs a second check after .keep has run.
# ---------------------------------------------------------------------------

#' @importFrom dplyr mutate
#' @export
mutate.weighted_df <- function(.data, ...) {
  result <- NextMethod()
  .reconstruct_weighted_df(result, .data)
}

# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

# Core reconstruction logic shared by all dplyr integration points.
# If weight_col is present in `data`, restores weighted_df class and attributes.
# If weight_col is missing, warns (surveywts_warning_weight_col_dropped)
# and returns a plain tibble.
.reconstruct_weighted_df <- function(data, template) {
  weight_col <- attr(template, "weight_col")

  if (weight_col %in% names(data)) {
    structure(
      data,
      class = c("weighted_df", "tbl_df", "tbl", "data.frame"),
      weight_col = weight_col,
      weighting_history = attr(template, "weighting_history")
    )
  } else {
    cli::cli_warn(
      c(
        "!" = "Weight column {.field {weight_col}} was removed from the {.cls weighted_df}.",
        "i" = "The result has been downgraded to a plain tibble.",
        "i" = "Load {.pkg surveytidy} for rename-aware handling."
      ),
      class = "surveywts_warning_weight_col_dropped"
    )
    # Strip custom weighted_df attributes before returning as plain tibble
    attr(data, "weight_col") <- NULL
    attr(data, "weighting_history") <- NULL
    tibble::as_tibble(data)
  }
}
