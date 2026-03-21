# Rake survey weights to marginal population totals

Iterative proportional fitting (raking) that adjusts survey weights to
match multiple marginal population totals simultaneously. Supports two
algorithms: the `"anesrake"` method (chi-square variable selection,
improvement-based convergence) and the `"survey"` method (fixed-order
IPF, epsilon-based convergence).

## Usage

``` r
rake(
  data,
  margins,
  weights = NULL,
  wt_name = "wts",
  type = c("prop", "count"),
  method = c("anesrake", "survey"),
  cap = NULL,
  control = list()
)
```

## Arguments

- data:

  A `data.frame`, `weighted_df`, `survey_taylor`, or `survey_nonprob`.
  `survey_replicate` → error. Any other class → error.

- margins:

  Named list or data frame specifying population margin targets.

  **Format A — named list:**

      list(
        age_group = c("18-34" = 0.28, "35-54" = 0.37, "55+" = 0.35),
        sex       = c("M" = 0.49, "F" = 0.51)
      )

  Each element can be a named numeric vector or a data frame with
  columns `level` and `target` (formats can be mixed within the list).

  **Format B — long data frame** with columns `variable`, `level`,
  `target`:

      data.frame(
        variable = c("age_group", "age_group", "sex", "sex"),
        level    = c("18-34", "35-54", "M", "F"),
        target   = c(0.40, 0.60, 0.49, 0.51)
      )

  Format B is auto-detected and converted to Format A before use. The
  converted Format A is stored in the weighting history.

- weights:

  \<[`tidy-select`](https://tidyselect.r-lib.org/reference/language.html)\>
  Weight column name (bare name). `NULL` → auto-detected from
  `weighted_df` attribute or survey object `@variables$weights`. For
  plain `data.frame` with `weights = NULL`, uniform starting weights are
  used and the output column is named by `wt_name` (default `"wts"`).

- wt_name:

  Character scalar. Name of the output weight column in the returned
  `weighted_df`. Default `"wts"`. Ignored when `data` is a survey object
  (`survey_taylor` or `survey_nonprob`).

- type:

  Character scalar. `"prop"` (default): `margins` values are
  proportions. `"count"`: `margins` values are counts.

- method:

  Character scalar. `"anesrake"` (default): chi-square discrepancy
  variable selection with improvement-based convergence, as in the
  `anesrake` package. `"survey"`: fixed-order IPF cycling through all
  margins, with epsilon-based convergence, as in
  [`survey::rake()`](https://rdrr.io/pkg/survey/man/rake.html).

- cap:

  Numeric or `NULL`. Cap on the weight ratio `w / mean(w)`. Any weight
  exceeding `cap × mean(w)` is set to `cap × mean(w)`. Applied after
  each per-margin adjustment step (not post-hoc). `NULL` (default) means
  no cap. Applies to both methods.

- control:

  Named list of algorithm parameters. Merged with method-specific
  defaults — omitted keys retain their defaults.

  **`method = "anesrake"` defaults:**

  - `maxit = 1000`: maximum full sweeps

  - `improvement = 0.01`: percentage improvement convergence threshold

  - `pval = 0.05`: chi-square p-value threshold for variable selection

  - `min_cell_n = 0L`: minimum unweighted observations per cell (0 = no
    min)

  - `variable_select = "total"`: chi-square aggregation for ranking
    (`"total"`, `"max"`, or `"average"`)

  **`method = "survey"` defaults:**

  - `maxit = 100`: maximum full sweeps

  - `epsilon = 1e-7`: maximum relative margin error convergence
    threshold

  Passing anesrake-specific keys when `method = "survey"` (or vice
  versa) triggers a `surveywts_warning_control_param_ignored` warning
  per ignored parameter.

## Value

- `data.frame` or `weighted_df` input → `weighted_df`

- `survey_taylor` or `survey_nonprob` input → same class as input
  (`survey_taylor` or `survey_nonprob`; class is preserved)

The weight column in the output contains raked weights. A history entry
with `operation = "raking"` is appended to `weighting_history`.

## Details

**`method = "anesrake"`:** At each sweep, variables are sorted by their
chi-square discrepancy (controlled by `control$variable_select`).
Variables with any cell below `control$min_cell_n` unweighted
observations are excluded entirely. Variables where the chi-square
p-value exceeds `control$pval` are skipped in that sweep. Convergence is
assessed as the percentage improvement in total chi-square between
consecutive sweeps. If all variables pass or are excluded in sweep 1, a
`surveywts_message_already_calibrated` message is emitted.

**`method = "survey"`:** Variables are raked in the fixed order given by
`margins`. All variables participate in every sweep. Convergence is
assessed as the maximum relative error across all margin cells falling
below `control$epsilon`.

## See also

Other calibration:
[`calibrate()`](https://jdenn0514.github.io/surveywts/reference/calibrate.md),
[`poststratify()`](https://jdenn0514.github.io/surveywts/reference/poststratify.md)

## Examples

``` r
df <- data.frame(
  age_group = c("18-34", "35-54", "55+", "18-34", "35-54"),
  sex       = c("M", "F", "M", "F", "M"),
  stringsAsFactors = FALSE
)
margins <- list(
  age_group = c("18-34" = 0.30, "35-54" = 0.40, "55+" = 0.30),
  sex       = c("M" = 0.48, "F" = 0.52)
)
result <- rake(df, margins = margins)
```
