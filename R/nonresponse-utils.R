# R/nonresponse-utils.R
#
# Internal helpers shared by adjust_nonresponse() and redistribute_weights().
#
# .validate_response_status_binary() — validates binary 0/1 or logical indicator columns.
# .warn_near_empty_cell() — emits surveywts_warning_class_near_empty.

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
  col_label = "Response status column",
  fn_name = "adjust_nonresponse",
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

# ---------------------------------------------------------------------------
# .warn_near_empty_cell() — private helper
# ---------------------------------------------------------------------------

# Emits the surveywts_warning_class_near_empty warning.
#
# Three call sites share this one condition class: the "propensity-cell"
# method of adjust_nonresponse(), the "weighting-class" method of
# adjust_nonresponse(), and redistribute_weights(). They differ only in the
# nouns for the grouping unit and its members, and in the first suggested
# remedy. Those four differences are arguments. The message shape, the
# adjustment-factor format, and the class stay here, so all three sites
# produce the same message shape.
#
# Arguments:
#   label      : the grouping unit's label (character or integer)
#   n          : integer(1) — number of members in the unit
#   adj_factor : numeric(1) — the adjustment factor, formatted to 2 decimals
#   unit_label : character(1) — noun phrase that opens the `!` bullet
#   unit       : character(1) — bare noun, pluralized in the first `i` bullet
#   member     : character(1) — noun for what `n` counts
#   remedy     : character(1) — first suggested remedy
#
# unit_label, unit, member, and remedy can carry cli markup. Each one is
# pasted into the format string, not interpolated into it, so cli parses the
# markup.
#
# Returns invisible(NULL). The caller keeps the guard
# `n < control$min_cell || adj_factor > control$max_adjust`, because the
# caller is where the counts are computed.
.warn_near_empty_cell <- function(
  label,
  n,
  adj_factor,
  unit_label = "Weighting class cell",
  unit = "cell",
  member = "respondent",
  remedy = "collapsing weighting classes"
) {
  adj_factor_fmt <- sprintf("%.2f", adj_factor)

  cli::cli_warn(
    c(
      "!" = paste0(
        unit_label,
        " {.val {label}} is sparse ",
        "({n} ",
        member,
        "(s), adjustment factor {adj_factor_fmt}\u00d7)."
      ),
      "i" = paste0(
        "Small or high-adjustment ",
        unit,
        "s may produce extreme weights."
      ),
      "i" = paste0(
        "Consider ",
        remedy,
        " or adjusting {.code control$min_cell} / {.code control$max_adjust}."
      )
    ),
    class = "surveywts_warning_class_near_empty"
  )

  invisible(NULL)
}
