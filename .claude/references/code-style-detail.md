# Code Style — Worked Examples and Rationale

Detail moved out of `.claude/rules/code-style.md` and
`.claude/rules/engineering-preferences.md`. The rules themselves live there;
this file shows how to apply them. Read this when writing new code and the
correct application is not obvious from the rule tables.

---

## General R style examples

### Indentation (2 spaces)

Matches rlang, tidyselect, cli, and S7 source.

```r
# Correct
survey_taylor <- S7::new_class(
  "survey_taylor",
  parent = survey_base,
  validator = function(self) {
    if (is.null(self@variables$weights)) {
      cli::cli_abort("...")
    }
  }
)

# Wrong
survey_taylor <- S7::new_class(
    "survey_taylor",           # 4-space indent
    parent = survey_base,
```

### Line length (80 characters)

For long function signatures, break after the opening `(` and align
arguments:

```r
# Good — break after (
as_survey <- function(
  data,
  ids = NULL,
  probs = NULL,
  weights = NULL,
  strata = NULL,
  fpc = NULL,
  nest = FALSE
) {

# Also good for short signatures — keep on one line if under 80 chars
set_var_label <- function(x, var, label) {
```

**`@examples` blocks:** `air` does not format roxygen2 comments. Wrap
function calls manually when the `#' result <- fn(...)` line exceeds 80
characters — break after the opening `(`, one argument per line, closing `)`
on its own line:

```r
# Good — call fits on one line
#' result <- ipw(nps, ref, selection = ~age + sex)

# Good — call is too long; break after (
#' result <- ipw(
#'   npors_2025_ipw,
#'   acs_ipw_ref,
#'   selection = ~gender + age_group + race_ethn + educ,
#'   missing_method = "omit"
#' )
```

For long `cli_abort()` calls, break the named vector across lines:

```r
cli::cli_abort(
  c(
    "x" = "Weight column {.field {weights_var}} must be numeric.",
    "i" = "Got class {.cls {class(wt_col)}}.",
    "v" = "Use {.code as.numeric({.field {weights_var}})} to convert."
  ),
  class = "surveywts_error_weights_not_numeric"
)
```

### Pipe and assignment

```r
# Correct
survey_obj |>
  set_var_label(age, "Age in years") |>
  set_var_label(income, "Annual income")
weights_var <- names(weights_cols)

# Wrong
survey_obj %>%
  set_var_label(age, "Age in years")
weights_var = names(weights_cols)
```

---

## S7 pattern examples

### Property access

```r
# Reading properties of a surveycore object in surveywts internal code
wt_vec  <- data@data[[data@variables$weights]]
meta    <- data@metadata
history <- meta@weighting_history

# Writing back (surveywts pattern for updating weighting history):
meta@weighting_history <- c(history, list(new_entry))
data@metadata <- meta
```

### Print method registration

surveywts defines print methods for the surveycore classes `survey_nonprob`
and `survey_replicate`, both registered in `R/methods-print.R`. Registration
happens via `S7::methods_register()` called from `.onLoad()` in `R/zzz.R`.
If adding a new print method, add it to `methods-print.R` and ensure
`.onLoad()` still calls `S7::methods_register()`.

### Class membership testing

```r
# Correct — fully qualified when the class comes from surveycore
if (!S7::S7_inherits(data, surveycore::survey_nonprob)) {
  cli::cli_abort(
    c("x" = "{.arg data} must be a {.cls survey_nonprob}."),
    class = "surveywts_error_not_nonprob"
  )
}

# Wrong — string; rename silently breaks the check
if (!inherits(data, "survey_taylor")) {
  cli::cli_abort(...)
}

# weighted_df uses base inherits() — it is an S3 class, not S7
if (inherits(data, "weighted_df")) {
  # weighted_df path
} else if (S7::S7_inherits(data, surveycore::survey_nonprob)) {
  # survey_nonprob path
} else if (is.data.frame(data)) {
  # plain data.frame path
}
```

### `weighted_df` attributes and construction

```r
# weighted_df full class vector:
# c("weighted_df", "tbl_df", "tbl", "data.frame")
inherits(x, "weighted_df")       # correct — matches position 1
S7::S7_inherits(x, weighted_df)  # wrong — weighted_df is not an S7 class

attr(x, "weight_col")         # character(1) — name of the weight column
attr(x, "weighting_history")  # list — ordered history entries
```

Users receive `weighted_df` as output; they never build one themselves.
Internally, use `.make_weighted_df()` from `utils.R`.

### Three-path input handling

```r
if (S7::S7_inherits(data, surveycore::survey_nonprob)) {
  # S7 path: extract @data, operate, write back, update @metadata@weighting_history
} else if (inherits(data, "weighted_df")) {
  # weighted_df path: update weight column, append to attr(, "weighting_history")
} else {
  # plain data.frame path: create a new weighted_df via .make_weighted_df()
}
```

Check S7 objects before `weighted_df` because `survey_nonprob` inherits from
`data.frame` and would pass an `is.data.frame()` check if tested last.

History-entry construction (append pattern for each path):

```r
new_entry <- list(
  step      = length(attr(result, "weighting_history")) + 1L,  # or result@metadata@weighting_history for S7
  timestamp = Sys.time(),
  operation = "fn_name"
  # additional function-specific fields follow
)

# weighted_df path:
attr(result, "weighting_history") <- c(
  attr(result, "weighting_history"),
  list(new_entry)
)

# survey_nonprob path:
meta <- result@metadata
meta@weighting_history <- c(meta@weighting_history, list(new_entry))
result@metadata <- meta
```

---

## Error and warning examples

### `cli_abort()` good vs bad

```r
# Good
cli::cli_abort(
  c(
    "x" = "{.arg fpc} column {.field {fpc_var}} contains {sum(is.na(fpc_col))} NA value(s).",
    "i" = "FPC must be fully observed for finite population correction.",
    "v" = "Remove rows with missing FPC or set {.arg fpc = NULL} to omit the correction."
  ),
  class = "surveywts_error_fpc_na"
)

# Bad — no class, no context
cli::cli_abort("FPC has NAs")
```

### `cli_warn()` structure

Same structure and same `class=` requirement as `cli_abort()`:

```r
cli::cli_warn(
  c(
    "!" = "What triggered the warning.",
    "i" = "Why this matters.",
    "i" = "What to do if this is unexpected."
  ),
  class = "surveywts_warning_{condition}"    # ALWAYS required
)
```

### Class name examples

```r
# Error class examples
"surveywts_error_not_data_frame"
"surveywts_error_weights_nonpositive"
"surveywts_error_subset_degenerate"

# Warning class examples
"surveywts_warning_srs_no_weights"
"surveywts_warning_single_stratum"
"surveywts_warning_psu_multi_strata"
```

For the full inline markup reference (50+ classes, pluralization, progress
bars, theming), see the `cli` skill in `.claude/skills/cli/`.

---

## Function design examples

### Return visibility

```r
# Weighting function — always returns visible, same class as input
trim_weights <- function(data, weights = NULL, lower = NULL, upper = NULL, ...) {
  # ... implementation ...
  result  # visible — no invisible()
}

# Diagnostic function — visible scalar or tibble
effective_sample_size <- function(x, weights = NULL) {
  # ...
  ess  # visible
}

# Internal validator — invisible(TRUE) on success, cli_abort() on failure
.validate_wt_name <- function(wt_name) {
  if (!is.character(wt_name) || length(wt_name) != 1L) {
    cli::cli_abort(
      c("x" = "{.arg wt_name} must be a single character string."),
      class = "surveywts_error_wt_name_invalid"
    )
  }
  invisible(TRUE)
}
```

### Argument order

```r
# ipw: data (1), reference (2, required), then optional args
ipw <- function(
  data,
  reference,
  selection = NULL,
  predictors = NULL,
  missing_method = c("omit", "separate", "impute"),
  method = "logit",
  estimating_eq = c("mle", "gee"),
  maxit = 25L,
  epsilon = 1e-8,
  trim = FALSE,
  population_size = NULL,
  wt_name = "ipw_weight"
)

# calibrate_rake: data (1), targets (2, required), weights (3, optional NSE),
#                 then optional scalars
calibrate_rake <- function(
  data,
  targets,
  weights = NULL,
  wt_name = "wts",
  type = c("prop", "count"),
  algorithm = c("classic_ipf", "nr"),
  cap = NULL,
  control = list(),
  reference_design = NULL
)
```

### Dispatch rule

```r
# CORRECT — extending an existing generic
S7::method(print, surveycore::survey_nonprob) <- function(x, ...) { ... }

# CORRECT — new surveywts-owned generic
ipw <- function(data, reference, ...) {
  if (!S7::S7_inherits(data, surveycore::survey_nonprob) &&
        !inherits(data, "weighted_df") && !is.data.frame(data)) {
    cli::cli_abort(
      c("x" = "{.arg data} must be a data.frame, weighted_df, or survey_nonprob."),
      class = "surveywts_error_data_invalid"
    )
  }
  # implementation
}

# WRONG — S3 dispatch does not work for S7 objects
ipw <- function(data, ...) UseMethod("ipw")
ipw.survey_nonprob <- function(data, ...) { ... }  # never dispatched
```

### Internal helper placement

```r
# Used only by trim_weights() — inline, below the exported function
.redistribute_trimmed <- function(w, lower, upper) { ... }

# Used by trim_weights() AND rescale_weights() — weight-utils.R
.get_weight_vec <- function(data, weights) { ... }

# Used across families (diagnostics, nonresponse, utilities) — utils.R
.make_weighted_df <- function(data, weight_col, wt_name) { ... }
```

---

## Roxygen and package check examples

```r
# Correct
result <- rlang::enquo(x)

# Wrong
result <- enquo(x)  # requires @importFrom rlang enquo
```

**Exception: S3 method registration.** `@importFrom` is required when
registering an S3 method for a generic from another package (e.g.,
`dplyr::dplyr_reconstruct`, `dplyr::select`). Without it, roxygen2 cannot
generate the `S3method()` directive in `NAMESPACE`. This is the only
approved use of `@importFrom`.

```r
# One-liner — no roxygen needed
.get_col <- function(x, col) x[[col]]

# Complex helper — document but suppress .Rd
#' Validate survey design structure
#'
#' @param x A survey design object.
#' @returns Invisibly, `TRUE` on success (errors otherwise).
#' @keywords internal
#' @noRd
.validate_design <- function(x) { ... }
```

---

## Tooling configuration

`air` is a **formatter**, not a linter: it rewrites R files to conform to
the style. When `air` touches a file, the code is correct — do not manually
undo its changes.

```r
# Install
pak::pak("posit-dev/air")
```

```bash
# Format the entire package
air format .

# Format a single file
air format R/calibrate.R
```

Format-on-save (Positron / VS Code): install the air extension, then set
`editor.formatOnSave` and `editor.defaultFormatter` for `[r]` in
`.vscode/settings.json` in the repo root (create it if missing).

RStudio has no native format-on-save — use the air addin (Addins → Format
with air), or run `air format .` from the terminal before committing.

Run `air format .` before opening a PR. Do not commit air-reformatted files
in the same commit as functional changes — reformat first, then make the
functional change.

The formatter config (`air.toml`) and editor config (`.editorconfig`) live
in the package root — read them there, not here.

---

## Engineering preferences — detail

The five principles live in `.claude/rules/engineering-preferences.md`.
Their sub-points:

### 1. DRY — flag repetition aggressively

- Repeated patterns in 2+ functions → extract a shared internal helper
- Repeated validation logic → consolidate into a single validator
- Repeated test setup → move to `helper-*.R`
- Do not defer DRY violations as "we can clean this up later." Surface them
  during spec review, not after the code is written.

### 2. Well-tested — more tests is better

- When unsure whether an edge case needs a test, write the test
- Never suggest removing coverage to hit a deadline
- 98%+ line coverage is the floor, not the target
- Every error class gets a test; every edge case in the spec gets a test

### 3. Engineered enough — not under, not over

**Under-engineered** (fragile, hacky): missing edge case handling; contracts
that don't specify behavior at the boundaries; validation that only checks
the happy path.

**Over-engineered** (premature abstraction, unnecessary complexity):
abstraction layers that don't yet have two real call sites; generalization
for hypothetical future requirements not in the roadmap; clever solutions
when a straightforward one works fine.

The right amount of engineering is determined by what's in the current spec,
not by what might be needed in a later phase.

### 4. Handle more edge cases, not fewer

- All-NA inputs, zero-weight rows, single-level groups, empty domains — these
  are not hypothetical; they appear in real survey data
- "That probably won't happen" is not a reason to skip an edge case
- Thoughtfulness > speed: a slower implementation that handles edge cases
  correctly is always preferred

### 5. Explicit over clever

- `S7::S7_inherits(x, ClassName)` not `inherits(x, "survey_taylor")`
- Named error classes on every `cli_abort()`, not bare messages
- Spell out behavior in the spec rather than relying on "the reader will infer"
- Document assumptions rather than leaving them implicit

### How to apply these during review

1. Read through with DRY as the first lens — find repetition before
   anything else
2. Check every error condition and edge case in the spec against the test
   plan
3. For each design decision, ask: is this the right level of abstraction
   for what's actually needed now?
4. For each boundary condition mentioned in the spec, ask: is the behavior
   fully specified, or is it left implicit?
5. For any "shortcut" in the implementation plan, ask: does this skip
   something that will need to be added back later anyway?
