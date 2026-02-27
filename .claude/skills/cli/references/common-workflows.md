# Common Workflows

## Base R to CLI Migration

```r
# Before: Base R error handling
validate_input <- function(x, y) {
  if (!is.numeric(x)) {
    stop("x must be numeric")
  }
  if (length(y) == 0) {
    stop("y cannot be empty")
  }
  if (length(x) != length(y)) {
    stop("x and y must have the same length")
  }
}

# After: CLI error handling
validate_input <- function(x, y) {
  if (!is.numeric(x)) {
    cli_abort(c(
      "{.arg x} must be numeric",
      "x" = "You supplied a {.cls {class(x)}} vector",
      "i" = "Use {.fn as.numeric} to convert"
    ))
  }

  if (length(y) == 0) {
    cli_abort(c(
      "{.arg y} cannot be empty",
      "i" = "Provide at least one element"
    ))
  }

  if (length(x) != length(y)) {
    cli_abort(c(
      "{.arg x} and {.arg y} must have the same length",
      "x" = "{.arg x} has length {length(x)}",
      "x" = "{.arg y} has length {length(y)}"
    ))
  }
}
```

## Error Message with Rich Context

```r
check_required_columns <- function(data, required_cols) {
  actual_cols <- names(data)
  missing_cols <- setdiff(required_cols, actual_cols)

  if (length(missing_cols) > 0) {
    cli_abort(c(
      "Required column{?s} missing from data",
      "x" = "Missing {length(missing_cols)} column{?s}: {.field {missing_cols}}",
      "i" = "Data has {length(actual_cols)} column{?s}: {.field {actual_cols}}",
      "i" = "Add the missing column{?s} or check for typos"
    ))
  }

  invisible(data)
}
```

## Function with Progress Bar

```r
process_files <- function(files, verbose = TRUE) {
  n <- length(files)

  if (verbose) {
    cli_progress_bar(
      format = "Processing {cli::pb_bar} {cli::pb_current}/{cli::pb_total} [{cli::pb_eta}]",
      total = n
    )
  }

  results <- vector("list", n)

  for (i in seq_along(files)) {
    results[[i]] <- process_file(files[[i]])

    if (verbose) {
      cli_progress_update()
    }
  }

  results
}
```
