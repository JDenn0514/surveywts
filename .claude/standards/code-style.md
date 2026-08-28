# surveywts Code Style Guide

---

## Quick Reference

| Decision | Choice |
|----------|--------|
| Auto-formatter | `air` (Posit's R formatter) |
| Pipe operator | Native `\|>` only |
| Style guide | tidyverse style (via air) |
| Property access | Direct `@` everywhere on surveycore S7 objects — surveywts defines no accessor generics; the only wrappers are the internal `.get_*()` helpers in `utils.R` |
| Argument order | `x`/`data` first → required NSE → required scalar → optional NSE → optional scalar → `...` |
| Dispatch rule | `S7::method()` for extending existing generics; plain function + `S7::S7_inherits()` for everything else — surveywts defines no generics and no classes |
| Type check (S7 objects) | `S7::S7_inherits(x, surveycore::survey_taylor)` — fully qualified, never a string |
| Accepted input classes | `survey_base` objects only — each family has its own input gate; see §2 |
| Error structure | `"x"` + `"i"` + optional `"v"` bullets; `class=` on every `cli_abort()` |
| Message language | Declarative for `"x"`/`"i"` bullets; imperative for `"v"` bullet |

---

## 1. General R Style

### Line length
For long function signatures, break after the opening `(` and align arguments:
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

### Auto-formatter
Use **`air`** (Posit's R formatter) for all formatting. Run on save or before committing.

Do not manually adjust spacing after running `air`. If `air` output looks wrong, there's a syntax problem — don't work around it.

### Pipe operator
**Native `|>` only.** `%>%` is never used.

### Assignment operator
**`<-`** for all assignments. `=` is reserved for function arguments only.
Wrong: `weights_var = names(weights_cols)`.

---

## 2. Working with S7 Objects

### Property access

Use **`@` directly** everywhere in internal code to access properties of surveycore S7 objects.

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

Print methods for `survey_nonprob` and `survey_replicate` live in
`R/methods-print.R`. They register through `S7::methods_register()`, called
from `.onLoad()` in `R/zzz.R` — see `surveywts-conventions.md` §3 and §6 for
the file and the registration code. When you add a new print method, add it
to `methods-print.R`. Confirm `.onLoad()` still calls
`S7::methods_register()`.

### Class membership testing
Always use **`S7::S7_inherits(x, ClassName)`** with the class object — never a string.

```r
# Correct — fully qualified when the class comes from surveycore
if (!S7::S7_inherits(data, surveycore::survey_base)) {
  cli::cli_abort(
    c("x" = "{.arg data} must be a {.cls survey_base} object."),
    class = "surveywts_error_not_survey_base"
  )
}

# Also correct — bare name resolves at runtime (surveycore is imported),
# but use :: in examples and documentation for clarity
if (!S7::S7_inherits(data, surveycore::survey_taylor)) {
  cli::cli_abort(...)
}

# Wrong — string; rename silently breaks the check
if (!inherits(data, "survey_taylor")) {
  cli::cli_abort(...)
}
```

Base `inherits()` is still correct for classes that are genuinely S3 — for
example `inherits(formula, "formula")` in `.validate_formula()`. Use it only
for S3 classes, never for a surveycore class.

### Survey object input handling

Every weighting function in surveywts requires a `survey_base` object —
`survey_nonprob`, `survey_taylor`, or `survey_replicate`. Plain data frames and
tibbles are not accepted.

Each family gates its input with its own validator, called before any other
validation. Use the one that belongs to the family you are working in:

| Family | Gate | Lives in |
|--------|------|----------|
| Calibration, nonresponse | `.check_input_class()` | `utils.R` |
| Utilities (`trim_weights()`, `rescale_weights()`) | `.check_weight_utils_class()` | `weight-utils.R` |
| Replicate weights | `.validate_replicate_input()` | `replicate-utils.R` |
| Diagnostics | `.diag_validate_input()` | `diagnostics-utils.R` |

```r
# First statement in a calibration or nonresponse function
.check_input_class(data)
```

`.check_input_class()` throws `surveywts_error_not_survey_base`. The other
three gates accept narrower sets and throw their own classes — read the helper
before assuming which classes it lets through. `calibrate()` and
`as_taylor_design()` call no gate directly: `calibrate()` forwards to a
dispatched function that gates, and `as_taylor_design()` does its own class
check inline.

After that gate passes, branch only where the classes genuinely behave
differently — for example when replicate weight columns need the same
treatment as the full-sample weight:

```r
if (S7::S7_inherits(data, surveycore::survey_replicate)) {
  # Apply the method to @variables$repweights as well as the main weight
} else if (S7::S7_inherits(data, surveycore::survey_nonprob)) {
  # survey_nonprob-specific path (e.g., reading @calibration provenance)
}
```

Test for the specific class, not for `is.data.frame()`. A survey object holds
its data in `@data`; the object itself is not a data frame.

**History entry construction.** Do not assemble or append history entries by
hand. The requirement is in `core.md` §2. Here is the code shape:

```r
history_entry <- .make_history_entry(
  step         = length(.get_history(data)) + 1L,
  operation    = "raking",
  weight_col   = weight_col,
  call_str     = paste(deparse(match.call()), collapse = " "),
  parameters   = parameters,
  before_stats = .compute_weight_stats(wt_vec),
  after_stats  = .compute_weight_stats(new_wt_vec),
  convergence  = convergence
)

result <- .update_survey_weights(
  design          = data,
  new_weights_vec = new_wt_vec,
  history_entry   = history_entry,
  wt_name         = wt_name
)
```

See `core.md` §3 for how `wt_name` picks the target column.

---

## 3. Error & Warning Conventions

### `cli_abort()` structure
Standard three-bullet structure:

```r
cli::cli_abort(
  c(
    "x" = "What went wrong (declarative).",      # Always present
    "i" = "Context or diagnosis.",                # Usually present
    "v" = "How to fix it (imperative)."           # When fixable
  ),
  class = "surveywts_error_{condition}"          # ALWAYS required
)
```

- `"x"` — What is wrong. Subject is the object/argument, not the user. Active voice.
- `"i"` — Why, or what was found. Provide actual values with `{.val}` / `{.field}` / `{.cls}`.
- `"v"` — The fix. Imperative: `"Use {.fn as.numeric}..."`. Only include when actionable.

```r
# Good
cli::cli_abort(
  c(
    "x" = "Weight column {.field {weight_col}} contains {n_na} NA value(s).",
    "i" = "Weights must be fully observed.",
    "v" = "Remove rows with missing weights before proceeding."
  ),
  class = "surveywts_error_weights_na"
)

# Bad — no class, no context
cli::cli_abort("weights have NAs")
```

### `cli_warn()` structure
Same structure and same `class=` requirement:

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

### Error and warning classes

`core.md` §4 has the naming convention and the `class=` requirement.

The canonical list of all classes is in `plans/error-messages.md`. When you
add a new error or warning:
1. Add a row to `plans/error-messages.md` first
2. Use the class name from that table in the code
3. Add a matching `expect_error(class = ...)` test

```r
# Error class examples
"surveywts_error_not_survey_base"
"surveywts_error_weights_nonpositive"
"surveywts_error_calibration_not_converged"

# Warning class examples
"surveywts_warning_no_weights_trimmed"
"surveywts_warning_class_near_empty"
"surveywts_warning_negative_calibrated_weights"
```

### cli inline markup
Use the appropriate markup type consistently:

| What you're showing | Markup | Renders as |
|---------------------|--------|------------|
| Function argument | `{.arg weights}` | `weights` |
| Column / variable name | `{.field {var}}` | `var` |
| Function name | `{.fn as_survey}` | `as_survey()` |
| Code snippet | `{.code nest = TRUE}` | `nest = TRUE` |
| A value | `{.val "brr"}` | `"brr"` |
| A class name | `{.cls survey_taylor}` | `<survey_taylor>` |

### Message language register
- **`"x"` bullets** — declarative, object as subject: `"Weight column {.field wt} is not numeric."`
- **`"i"` bullets** — declarative, system as subject: `"Got class {.cls {class(wt_col)}}."`
- **`"v"` bullets** — imperative: `"Use {.fn as.numeric} to convert."` or `"Set {.arg fpc = NULL} to skip FPC."`
- Never `"You must..."` or `"You provided..."` — the user is never addressed directly

For the full inline markup reference (50+ classes, pluralization, progress bars, theming), see the `cli` skill in `.claude/skills/cli/`.

---

## 4. Function Design

### Return value visibility

`surveywts-conventions.md` §4 has the full table (`.validate_weights()`,
`.validate_wt_name()`, etc.). In code:

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
**Required before optional. Object/data always first. NSE/tidy-select before scalar. `...` last.**

Full precedence:
1. `x` / `data` — the survey object (always mandatory, always first)
2. Required NSE/tidy-select arguments (bare names the user must provide)
3. Required scalar arguments (non-NSE arguments with no default)
4. Optional NSE/tidy-select arguments (`ids = NULL`, `weights = NULL`, etc.)
5. Optional scalar control arguments (`nest = FALSE`, `mse = TRUE`, `validate = TRUE`)
6. `...`

`surveywts-conventions.md` §7 has the full argument list for every exported
function, including `ipw()` and `calibrate_rake()`.

See `core.md` §3 for the `wt_name = NULL` rule. The one exception: `ipw()`
defaults to a new column named `"ipw_weight"` instead of overwriting in
place.

### Dispatch rule

surveywts functions are plain R functions — not S7 generics, not S3 generics. Type dispatch
is always explicit via `S7::S7_inherits()` or `inherits()`.

| Situation | Use |
|-----------|-----|
| Type checking a surveycore S7 object | `S7::S7_inherits(x, surveycore::survey_nonprob)` |
| Type checking a genuinely S3 class (e.g. `formula`) | `inherits(x, "formula")` |
| Registering a print method for a surveycore class | `S7::method(print, surveycore::survey_nonprob) <- function(x, ...) { }` in `methods-print.R` |

Never use `UseMethod()` in surveywts — S3 dispatch does not work for S7 objects.

### Internal helper placement

`surveywts-conventions.md` §3 says where a helper lives: inline if used in
1 file, a shared utils file if used in 2+ files.

All internal helpers are **not exported** and prefixed with `.`.

---

## 5. Roxygen & Package Check

### `@param` verbosity
Terse (one sentence) for self-evident arguments. Fuller for arguments with
non-obvious behavior, constraints, interactions, or where `NULL` has a
non-obvious effect.

### Required tags on all exported functions

`function-documentation.md` covers the `@returns` and `@examples`
requirements. `surveywts-conventions.md` §2 covers `@family` tags.

### Internal helper documentation

`function-documentation.md` covers when an internal helper needs roxygen.

### Import style

`r-package-conventions.md` §3 has the `::`-everywhere rule and the example.

**No exception applies today.** surveywts registers no S3 methods, so
`NAMESPACE` holds no `S3method()` directives and no source file needs
`@importFrom`. If surveywts ever registers an S3 method for a generic from
another package, `@importFrom` becomes required for that one method, because
`roxygen2` cannot generate the `S3method()` directive without it. Until then,
an `@importFrom` tag anywhere in `R/` is a mistake.

### NAMESPACE hygiene

`r-package-conventions.md` §3 covers editing `NAMESPACE` and the export
policy. `surveywts-conventions.md` §5 lists the 23 exported names. `core.md`
§7 covers the `document()`/`check()` cadence.

### R CMD check targets

`r-package-conventions.md` §4 has the check targets and the two
pre-approved notes.

### Dependency pinning

`r-package-conventions.md` §4 has the version-pinning rule.

---

## 6. Tooling Configuration

### `air` — formatter (not a linter)

`air` is a **formatter**: it rewrites R files to conform to the style. It is
NOT `lintr` (which only reports violations). When `air` touches a file, the
code is correct — do not manually undo its changes.

Run `air format .` before opening a PR. Do not commit air-reformatted files
in the same commit as functional changes — reformat first, then make the
functional change.

`air.toml` and `.editorconfig`, both in the package root, are the source of
truth for width and indentation. Read them there; do not restate their
values here. Gate 8 runs `air format --check .` and fails the build when any
file drifts.
