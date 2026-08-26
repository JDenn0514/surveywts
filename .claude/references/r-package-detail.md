# R Package Conventions — Worked Examples and Templates

Detail moved out of `.claude/rules/r-package-conventions.md` and
`.claude/rules/surveywts-conventions.md`. The rules live there; this file
shows how to apply them. Read this when writing roxygen docs, DESCRIPTION
fields, or package-level documentation.

---

## `@param` verbosity examples

**Terse** (one sentence) for simple, self-evident arguments:

```r
#' @param data A data.frame.
#' @param label A character string.
#' @param ... Additional arguments (currently unused).
```

**Fuller** for arguments with non-obvious behavior, constraints, or
interactions:

```r
#' @param weights <[`tidy-select`][tidyselect::language]> Column(s) for
#'   survey weights. If multiple columns, they are combined. Cannot contain
#'   `NA`. Default `NULL` (uniform weights).
```

## `@returns` examples

```r
#' @returns The updated object, same class as the input.
#' @returns A named numeric vector, or a tibble when `by` is supplied.
#' @returns A `survey_nonprob` with updated weights. If the input contains
#'   replicate weight columns, all replicate weight columns are updated by
#'   the same method.
```

## `@examples` — runnable, small

If an example is slow, use a smaller inline dataset instead of `\dontrun{}`:

```r
#' @examples
#' # Small inline example (preferred)
#' df <- data.frame(id = 1:10, y = rnorm(10))
#' result <- my_function(df)
```

## Internal function documentation

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

## Import style examples

```r
# Correct
result <- rlang::enquo(x)
cli::cli_abort("message", class = "error_class")

# Wrong
result <- enquo(x)           # requires @importFrom rlang enquo
cli_abort("message")         # requires @importFrom cli cli_abort

# Wrong — no re-exports; don't do this
#' @importFrom magrittr %>%
#' @export
`%>%` <- magrittr::`%>%`
```

## Version pinning example

```r
Imports:
    cli (>= 3.6.0),        # cli_abort() with class= argument
    rlang (>= 1.1.0),      # rlang::check_required()
    S7 (>= 0.1.0)          # S7 class system
Suggests:
    testthat (>= 3.0.0)
```

Set the bound to the oldest version where the required feature exists. Do
NOT use exact version pins (`==`) — rejected by CRAN and too fragile.

## `devtools::document()` cadence example

```r
# Before committing changes to R/03-functions.R
devtools::document()
git add NAMESPACE man/my_function.Rd
git commit -m "docs(functions): update roxygen"
```

## Dataset codoc: right vs. wrong `\describe{}`

```r
# Correct — single \describe{} block, all columns covered
#' @format A data frame with 500 rows and 6 columns:
#' \describe{
#'   \item{id}{Integer. Row identifier.}
#'   \item{gender}{Numeric. 1 = Male, 2 = Female.}
#'   \item{age}{Numeric. Age in years.}
#'   \item{registered}{Integer. Registered to vote: 1 = Yes, 0 = No.}
#'   \item{vote14}{Integer. Voted in 2014: 1 = Yes, 0 = No.}
#'   \item{weight}{Numeric. Survey weight.}
#' }

# Wrong — second \describe{} block is invisible to codoc
#' @format A data frame with 500 rows and 6 columns. Key columns:
#' \describe{
#'   \item{id}{Integer. Row identifier.}
#' }
#'
#' Benchmark variables:
#' \describe{
#'   \item{weight}{Numeric. Survey weight.}
#' }
```

Before writing roxygen2 for a new dataset, run `names(my_dataset)` to get
the full column list, then write one `\item{}` per column. Use
`attr(my_dataset[[col]], "label")` to recover the original SPSS/Stata label.

---

## DESCRIPTION template (all surveyverse packages)

```
Package: surveyXXX
Title: [Descriptive title matching the package role]
Version: 0.0.0.9000
Authors@R: person("Jacob", "Dennen", role = c("aut", "cre"), email = "...")
Description: [1-2 sentence description of what the package does]
License: GPL-3
Encoding: UTF-8
Roxygen: list(markdown = TRUE)
RoxygenNote: 7.x.x
```

## Package documentation template (surveypkg-package.R)

```r
#' surveytidy: dplyr/tidyr verbs for survey objects
#'
#' @description
#' surveytidy provides dplyr and tidyr verbs that work with survey design objects
#' from surveycore, allowing...
#'
#' @section Key Functions:
#' - [filter()] — domain-aware filtering
#' - [select()] — column selection
#' - [mutate()] — add/modify variables
#'
#' @section Documentation:
#' For ecosystem architecture, see [the ecosystem guide](../survey-standards/ECOSYSTEM.md).
#'
#' @keywords internal
#' "_PACKAGE"
```

---

## surveywts conventions — detail

### Argument order (full signatures)

| Function | Argument order |
|----------|----------------|
| `calibrate()` | `data, targets, weights = NULL, wt_name = "wts", type = c("prop", "count"), reference_design = NULL, ..., method = c("rake", "linear", "logit")` |
| `calibrate_linear()` | `data, targets, weights = NULL, wt_name = "wts", bounds = NULL, bounds_scale = c("multiplicative", "absolute"), unit_scale = NULL, type = c("prop", "count"), control = list(), reference_design = NULL` |
| `calibrate_logit()` | `data, targets, weights = NULL, wt_name = "wts", bounds = c(1e-6, 1e6), bounds_scale = c("multiplicative", "absolute"), unit_scale = NULL, type = c("prop", "count"), control = list(), reference_design = NULL` |
| `calibrate_rake()` | `data, targets, weights = NULL, wt_name = "wts", type = c("prop", "count"), algorithm = c("classic_ipf", "nr"), cap = NULL, control = list(), reference_design = NULL` |
| `poststratify()` | `data, targets, weights = NULL, wt_name = "wts", type = c("prop", "count"), reference_design = NULL` |
| `adjust_nonresponse()` | `data, response_status, weights = NULL, by = NULL, wt_name = "wts", method = c("weighting-class", "propensity-cell", "propensity"), formula = NULL, control = list(min_cell = 20, max_adjust = 2.0, n_cells = 5)` |
| `redistribute_weights()` | `data, reduce_if, increase_if, weights = NULL, by = NULL, wt_name = "wts", control = list()` |
| `trim_weights()` | `data, weights = NULL, lower = NULL, upper = NULL, k = 5, type = c("absolute", "percentile"), strict = FALSE, wt_name = "wts"` |
| `rescale_weights()` | `data, weights = NULL, by = NULL, wt_name = "wts"` |
| `calibrate_to_survey()` | `primary_design, control_design, variables, method = c("rake", "linear", "logit"), bounds = c(-Inf, Inf), unit_scale = NULL, reference_design = NULL, control = list()` |
| `calibrate_to_estimate()` | `design, targets, vcov_estimate, method = c("rake", "linear", "logit"), bounds = c(-Inf, Inf), unit_scale = NULL, reference_design = NULL, control = list()` |
| `effective_sample_size()` | `x, weights = NULL` |
| `weight_variability()` | `x, weights = NULL` |
| `summarize_weights()` | `x, weights = NULL, by = NULL` |
| `as_taylor_design()` | `data` |
| `ipw()` | `data, reference, selection = NULL, predictors = NULL, missing_method = c("omit", "separate", "impute"), mice_args = list(), method = "logit", estimating_eq = c("mle", "gee"), maxit = 25L, epsilon = 1e-8, adjust_reference = TRUE, trim = FALSE, population_size = NULL, wt_name = "ipw_weight"` |

### File mapping (R/ → export)

| File | Export |
|------|--------|
| `adjust_nonresponse.R` | `adjust_nonresponse()` |
| `as_taylor_design.R` | `as_taylor_design()` |
| `calibrate.R` | `calibrate()` — thin dispatcher |
| `calibrate-utils.R` | (internal helpers — not exported) |
| `calibrate_linear.R` | `calibrate_linear()` |
| `calibrate_logit.R` | `calibrate_logit()` |
| `calibrate_rake.R` | `calibrate_rake()` |
| `poststratify.R` | `poststratify()` |
| `calibrate_to_estimate.R` | `calibrate_to_estimate()` |
| `calibrate_to_survey.R` | `calibrate_to_survey()` |
| `create_bootstrap_weights.R` | `create_bootstrap_weights()` |
| `create_brr_weights.R` | `create_brr_weights()` |
| `create_gen_boot_weights.R` | `create_gen_boot_weights()` |
| `create_gen_rep_weights.R` | `create_gen_rep_weights()` |
| `create_jackknife_weights.R` | `create_jackknife_weights()` |
| `jackknife-dagjk-utils.R` | DAGJK engine internals (internal helpers only) |
| `create_replicate_weights.R` | `create_replicate_weights()` |
| `create_sdr_weights.R` | `create_sdr_weights()` |
| `effective_sample_size.R` | `effective_sample_size()` |
| `ipw.R` | `ipw()` |
| `redistribute_weights.R` | `redistribute_weights()` |
| `rescale_weights.R` | `rescale_weights()` |
| `summarize_weights.R` | `summarize_weights()` |
| `trim_weights.R` | `trim_weights()` |
| `weight_variability.R` | `weight_variability()` |
| `weighted-df-dplyr.R` | dplyr methods for `weighted_df` |

### `S7::new_class()` — `survey_nonprob`

```r
survey_nonprob <- S7::new_class(
  "survey_nonprob",
  parent = surveycore::survey_base,
  ...
)
```

### Documentation checklist (before committing roxygen changes)

- [ ] `devtools::document()` has been run
- [ ] `NAMESPACE` file has been updated
- [ ] All exported functions have `@returns`
- [ ] All `@examples` are runnable
- [ ] Internal helpers have `@keywords internal` + `@noRd` if needed
- [ ] `@family` tags are correct
- [ ] No `@importFrom` tags anywhere
- [ ] All external calls use `::`
- [ ] `R CMD check` passes with 0 errors, 0 warnings, ≤2 notes
