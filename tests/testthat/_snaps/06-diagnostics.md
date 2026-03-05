# effective_sample_size() throws unsupported_class for matrix input

    Code
      effective_sample_size(m)
    Condition
      Error in `.diag_validate_input()`:
      x `x` must be a data frame, <weighted_df>, <survey_taylor>, or <survey_calibrated>.
      i Got <matrix>.

# weight_variability() throws unsupported_class for list input

    Code
      weight_variability(x)
    Condition
      Error in `.diag_validate_input()`:
      x `x` must be a data frame, <weighted_df>, <survey_taylor>, or <survey_calibrated>.
      i Got <list>.

# effective_sample_size() throws weights_required for plain df with no weights

    Code
      effective_sample_size(df)
    Condition
      Error in `.diag_validate_input()`:
      x `weights` is required when `x` is a plain data frame.
      i For <weighted_df> and survey objects, the weight column is detected automatically.
      v Pass the column name as a bare name, e.g., `weights = wt_col`.

# summarize_weights() throws weights_required for plain df with no weights

    Code
      summarize_weights(df)
    Condition
      Error in `.diag_validate_input()`:
      x `weights` is required when `x` is a plain data frame.
      i For <weighted_df> and survey objects, the weight column is detected automatically.
      v Pass the column name as a bare name, e.g., `weights = wt_col`.

# effective_sample_size() throws weights_not_found for missing column

    Code
      effective_sample_size(df, weights = nonexistent_col)
    Condition
      Error in `.validate_weights()`:
      x Weight column nonexistent_col not found in `data`.
      i Available columns: x.
      v Pass the column name as a bare name, e.g., `weights = wt_col`.

# effective_sample_size() throws weights_not_numeric for character weight column

    Code
      effective_sample_size(df, weights = w)
    Condition
      Error in `.validate_weights()`:
      x Weight column w must be numeric.
      i Got <character>.
      v Use `as.numeric(w)` to convert.

# effective_sample_size() throws weights_nonpositive for zero weight value

    Code
      effective_sample_size(df, weights = w)
    Condition
      Error in `.validate_weights()`:
      x Weight column w contains 1 non-positive value(s).
      i All starting weights must be strictly positive (> 0).
      v Remove or replace non-positive weights before proceeding.

# effective_sample_size() throws weights_na for NA in weight column

    Code
      effective_sample_size(df, weights = w)
    Condition
      Error in `.validate_weights()`:
      x Weight column w contains 1 NA value(s).
      i Weights must be fully observed.
      v Remove rows with missing weights before proceeding.

