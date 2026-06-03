# R/calibrate-utils.R
#
# Calibration-family shared helpers.
# Used by calibrate_greg() and calibrate_rake().

# ---------------------------------------------------------------------------
# .parse_margins() — converts targets/margins to Format A
# ---------------------------------------------------------------------------

# Converts targets to Format A (named list of named numeric vectors).
# Accepts:
#   - Format A: named list (pass-through, with data.frame elements normalized)
#   - Format B: data.frame with columns 'variable', 'level', 'target'
#
# Returns: named list. Each element is a named numeric vector
#   c(level1 = target1, level2 = target2, ...)
#
# Errors with surveywts_error_margins_format_invalid if targets is neither
# a named list nor a valid Format B data.frame.
.parse_margins <- function(targets) {
  # Format B: data.frame with required columns
  if (is.data.frame(targets)) {
    required_cols <- c("variable", "level", "target")
    missing_cols <- setdiff(required_cols, names(targets))
    if (length(missing_cols) > 0L) {
      cli::cli_abort(
        c(
          "x" = paste0(
            "{.arg targets} must be a named list or a data frame with ",
            "columns {.field variable}, {.field level}, and {.field target}."
          ),
          "i" = paste0(
            "Got {.cls data.frame} but missing column(s): ",
            "{.and {.field {missing_cols}}}."
          ),
          "v" = paste0(
            "See {.fn calibrate_rake} or {.fn calibrate_greg} documentation ",
            "for accepted formats."
          )
        ),
        class = "surveywts_error_margins_format_invalid"
      )
    }

    # Convert to Format A: split by variable, build named vector per variable
    var_names <- unique(as.character(targets$variable))
    result <- lapply(var_names, function(v) {
      rows <- targets[as.character(targets$variable) == v, , drop = FALSE]
      stats::setNames(
        as.double(rows$target),
        as.character(rows$level)
      )
    })
    names(result) <- var_names
    return(result)
  }

  # Format A: named list — normalize data.frame elements to named vectors
  if (is.list(targets) && !is.data.frame(targets)) {
    if (length(names(targets)) == 0L || any(names(targets) == "")) {
      cli::cli_abort(
        c(
          "x" = paste0(
            "{.arg targets} must be a named list or a data frame with ",
            "columns {.field variable}, {.field level}, and {.field target}."
          ),
          "i" = paste0(
            "Got {.cls {class(targets)[[1]]}} but list elements are not named."
          ),
          "v" = paste0(
            "See {.fn calibrate_rake} or {.fn calibrate_greg} documentation ",
            "for accepted formats."
          )
        ),
        class = "surveywts_error_margins_format_invalid"
      )
    }

    # Normalize any data.frame elements to named vectors
    result <- lapply(names(targets), function(v) {
      elem <- targets[[v]]
      if (is.data.frame(elem)) {
        if (!all(c("level", "target") %in% names(elem))) {
          cli::cli_abort(
            c(
              "x" = paste0(
                "Element {.field {v}} in {.arg targets} is a data frame but ",
                "is missing required columns {.field level} and/or {.field target}."
              ),
              "v" = paste0(
                "See {.fn calibrate_rake} or {.fn calibrate_greg} documentation ",
                "for accepted formats."
              )
            ),
            class = "surveywts_error_margins_format_invalid"
          )
        }
        stats::setNames(
          as.double(elem$target),
          as.character(elem$level)
        )
      } else {
        # Already a named vector — ensure it is double-typed
        stats::setNames(as.double(unname(elem)), names(elem))
      }
    })
    names(result) <- names(targets)
    return(result)
  }

  # Neither list nor data.frame
  cls <- class(targets)[[1L]]
  cli::cli_abort(
    c(
      "x" = paste0(
        "{.arg targets} must be a named list or a data frame with ",
        "columns {.field variable}, {.field level}, and {.field target}."
      ),
      "i" = "Got {.cls {cls}}.",
      "v" = paste0(
        "See {.fn calibrate_rake} or {.fn calibrate_greg} documentation ",
        "for accepted formats."
      )
    ),
    class = "surveywts_error_margins_format_invalid"
  )
}

# ---------------------------------------------------------------------------
# .validate_reference_design() — validates reference_design argument
# ---------------------------------------------------------------------------

# Validates the reference_design argument. Returns invisible(TRUE) if valid.
# Throws surveywts_error_reference_design_not_taylor if non-NULL and not taylor.
#
# Arguments:
#   reference_design : user-supplied reference_design argument
.validate_reference_design <- function(reference_design) {
  if (!is.null(reference_design)) {
    if (!S7::S7_inherits(reference_design, surveycore::survey_taylor)) {
      cls <- class(reference_design)[[1L]]
      cli::cli_abort(
        c(
          "x" = paste0(
            "{.arg reference_design} must be a {.cls survey_taylor} object ",
            "or {.code NULL}."
          ),
          "i" = "Got {.cls {cls}}.",
          "v" = paste0(
            "Pass a {.cls survey_taylor} design as {.arg reference_design}, ",
            "or set {.code reference_design = NULL} to omit."
          )
        ),
        class = "surveywts_error_reference_design_not_taylor"
      )
    }
  }
  invisible(TRUE)
}

# ---------------------------------------------------------------------------
# .validate_count_marginal_consistency()
# ---------------------------------------------------------------------------

# When type = "count", validates that all marginal vectors sum to the same
# population total N within 1e-3 tolerance. If any pair differs by > 1e-3,
# throws surveywts_error_population_totals_invalid.
#
# Arguments:
#   targets_a      : Format A named list (named vectors, already in count form)
#   variable_names : character vector of variable names
.validate_count_marginal_consistency <- function(targets_a, variable_names) {
  if (length(variable_names) < 2L) return(invisible(TRUE))

  sums <- vapply(variable_names, function(v) sum(targets_a[[v]]), numeric(1L))
  names(sums) <- variable_names

  ref_sum <- sums[[1L]]
  for (v in variable_names[-1L]) {
    diff <- abs(sums[[v]] - ref_sum)
    if (diff > 1e-3) {
      cli::cli_abort(
        c(
          "x" = paste0(
            "When {.code type = \"count\"}, all marginal vectors must sum ",
            "to the same population total N (within 1e-3 tolerance)."
          ),
          "i" = paste0(
            "Variable {.field {variable_names[[1L]]}} sums to ",
            "{ref_sum}; variable {.field {v}} sums to {sums[[v]]} ",
            "(difference: {round(diff, 4)})."
          ),
          "v" = paste0(
            "Ensure all entries in {.arg targets} refer to the same ",
            "population total."
          )
        ),
        class = "surveywts_error_population_totals_invalid"
      )
    }
  }
  invisible(TRUE)
}
