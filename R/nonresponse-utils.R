# R/nonresponse-utils.R
#
# Internal helpers shared by adjust_nonresponse() and redistribute_weights().
#
# .validate_response_status_binary() — validates binary 0/1 or logical indicator columns.

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
