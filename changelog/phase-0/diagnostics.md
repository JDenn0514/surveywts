# Changelog: Diagnostic Functions

## PR 9 — feat(calibration): implement effective_sample_size(), weight_variability(), summarize_weights()

### New function: `effective_sample_size()`

Computes Kish's effective sample size for a survey weight vector.

**Signature:**

```r
effective_sample_size(x, weights = NULL)
```

**Key behaviours:**

- Accepts `data.frame`, `weighted_df`, `survey_taylor`, and `survey_nonprob`.
- Returns a named numeric scalar `c(n_eff = <value>)`.
- Auto-detects the weight column for `weighted_df` and survey objects;
  `weights` is required for plain `data.frame`.
- Formula: `ESS = (sum(w))^2 / sum(w^2)`.

### New function: `weight_variability()`

Computes the coefficient of variation of survey weights.

**Signature:**

```r
weight_variability(x, weights = NULL)
```

**Key behaviours:**

- Same inputs and validation as `effective_sample_size()`.
- Returns a named numeric scalar `c(cv = <value>)`.
- Formula: `CV = sd(w) / mean(w)`.

### New function: `summarize_weights()`

Returns a full distributional summary of the weight column, optionally
within groups.

**Signature:**

```r
summarize_weights(x, weights = NULL, by = NULL)
```

**Key behaviours:**

- Same inputs and validation as `effective_sample_size()`.
- `by = NULL` returns a single-row tibble (overall summary).
- `by = c(var1, var2)` (tidy-select) returns one row per unique group
  combination. Group columns precede the summary statistics columns.
- Output columns (in order): `n`, `n_positive`, `n_zero`, `mean`, `cv`,
  `min`, `p25`, `p50`, `p75`, `max`, `ess`.

**Errors thrown (all three functions):**

- `surveywts_error_unsupported_class` — `x` is not a supported class.
- `surveywts_error_weights_required` — `x` is a plain `data.frame` and
  `weights = NULL`.
- `surveywts_error_weights_not_found` — named weight column missing.
- `surveywts_error_weights_not_numeric` — weight column is not numeric.
- `surveywts_error_weights_nonpositive` — weight column has values ≤ 0.
- `surveywts_error_weights_na` — weight column has `NA` values.

### New private helper: `.diag_validate_input()`

Validates the `x` argument and resolves `(data_df, weight_col)` for use
by the three diagnostic functions. Co-located in `R/06-diagnostics.R`.
