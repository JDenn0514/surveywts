# calibrate_to_survey() errors when primary_design is not survey_replicate

    Code
      calibrate_to_survey(df, control, ~sex)
    Condition
      Error in `calibrate_to_survey()`:
      x `primary_design` must be a <survey_replicate>.
      i Got <data.frame>.

# calibrate_to_survey() errors when control_design is not survey_replicate

    Code
      calibrate_to_survey(primary, df, ~sex)
    Condition
      Error in `calibrate_to_survey()`:
      x `control_design` must be a <survey_replicate>.
      i Got <data.frame>.

# calibrate_to_survey() errors on replicate count mismatch

    Code
      calibrate_to_survey(primary, control, ~sex)
    Condition
      Error in `calibrate_to_survey()`:
      x `primary_design` and `control_design` have different numbers of replicates.
      i `primary_design` has 50 replicate(s); `control_design` has 30.

# calibrate_to_survey() errors when formula variable missing from primary_design

    Code
      calibrate_to_survey(primary, control, ~no_such_col)
    Condition
      Error in `.validate_formula_variables()`:
      x Variable no_such_col not found in `primary_design`.
      i All variables in `formula` must be columns in `primary_design`.
      v Check spelling or add no_such_col to the data before calling this function.

# calibrate_to_survey() errors when formula variable missing from control_design

    Code
      calibrate_to_survey(primary, control, ~only_in_primary)
    Condition
      Error in `.validate_formula_variables()`:
      x Variable only_in_primary not found in `control_design`.
      i All variables in `formula` must be columns in `control_design`.
      v Check spelling or add only_in_primary to the data before calling this function.

# calibrate_to_survey() errors when formula is not a formula object

    Code
      calibrate_to_survey(primary, control, "~sex")
    Condition
      Error in `.validate_formula()`:
      x `formula` must be a one-sided formula (e.g., `~ age + sex`).
      i Got <character>.

# calibrate_to_survey() errors when calibration does not converge

    Code
      calibrate_to_survey(primary, control, ~sex, control = list(maxit = 1L, epsilon = 1e-100))
    Condition
      Error in `value[[3L]]()`:
      x Calibration failed.
      i Convergence was not achieved for replicate 1. Consider increasing `maxit` or relaxing `epsilon`.
      v Try increasing `control$maxit` or relaxing `control$epsilon`.

# calibrate_to_survey() errors when svrep warns convergence but returns normally

    Code
      calibrate_to_survey(primary, control, ~sex)
    Condition
      Error in `calibrate_to_survey()`:
      x Calibration did not converge.
      i did not converge after 1 iterations
      v Try increasing `control$maxit` or relaxing `control$epsilon`.

# calibrate_to_estimate() errors when design is not survey_replicate

    Code
      calibrate_to_estimate(df, ~sex, estimate = tots$estimate, vcov_estimate = tots$
        vcov_estimate)
    Condition
      Error in `calibrate_to_estimate()`:
      x `design` must be a <survey_replicate>.
      i Got <data.frame>.

# calibrate_to_estimate() errors when formula variable missing from design

    Code
      calibrate_to_estimate(design, ~no_such_col, estimate = tots$estimate,
      vcov_estimate = tots$vcov_estimate)
    Condition
      Error in `.validate_formula_variables()`:
      x Variable no_such_col not found in `design`.
      i All variables in `formula` must be columns in `design`.
      v Check spelling or add no_such_col to the data before calling this function.

# calibrate_to_estimate() errors when formula is not a formula object

    Code
      calibrate_to_estimate(design, "~sex", estimate = tots$estimate, vcov_estimate = tots$
        vcov_estimate)
    Condition
      Error in `.validate_formula()`:
      x `formula` must be a one-sided formula (e.g., `~ age + sex`).
      i Got <character>.

# calibrate_to_estimate() errors when estimate is not named

    Code
      calibrate_to_estimate(design, ~sex, estimate = bad_estimate, vcov_estimate = tots$
        vcov_estimate)
    Condition
      Error in `calibrate_to_estimate()`:
      x `estimate` must be a named numeric vector.
      i Provide names matching `survey::svytotal()` output for `~sex`: "sexF" and "sexM".

# calibrate_to_estimate() errors when estimate has NA values

    Code
      calibrate_to_estimate(design, ~sex, estimate = bad_estimate, vcov_estimate = tots$
        vcov_estimate)
    Condition
      Error in `calibrate_to_estimate()`:
      x `estimate` contains 1 NA value(s).
      i All control total estimates must be non-missing.

# calibrate_to_estimate() errors when estimate length does not match model matrix

    Code
      calibrate_to_estimate(design, ~sex, estimate = bad_estimate, vcov_estimate = tots$
        vcov_estimate)
    Condition
      Error in `calibrate_to_estimate()`:
      x `estimate` has 3 element(s); expected 2.
      i Expected names: "sexF" and "sexM".

# calibrate_to_estimate() errors when estimate names do not match model matrix

    Code
      calibrate_to_estimate(design, ~sex, estimate = bad_estimate, vcov_estimate = tots$
        vcov_estimate)
    Condition
      Error in `calibrate_to_estimate()`:
      x Names of `estimate` do not match expected calibration variable names.
      i Got: "wrong1" and "wrong2".
      i Expected: "sexF" and "sexM".

# calibrate_to_estimate() errors when vcov_estimate has wrong dimensions

    Code
      calibrate_to_estimate(design, ~sex, estimate = tots$estimate, vcov_estimate = bad_vcov)
    Condition
      Error in `calibrate_to_estimate()`:
      x `vcov_estimate` must be a 2 x 2 matrix.
      i Got dimensions 3 x 3.

# calibrate_to_estimate() errors when vcov_estimate has NA values

    Code
      calibrate_to_estimate(design, ~sex, estimate = tots$estimate, vcov_estimate = bad_vcov)
    Condition
      Error in `calibrate_to_estimate()`:
      x `vcov_estimate` contains 1 NA value(s).
      i The variance-covariance matrix must be fully observed.

# calibrate_to_estimate() errors when vcov_estimate is not symmetric

    Code
      calibrate_to_estimate(design, ~sex, estimate = tots$estimate, vcov_estimate = bad_vcov)
    Condition
      Error in `calibrate_to_estimate()`:
      x `vcov_estimate` is not symmetric (max asymmetry = 1e-05).
      i The symmetry tolerance is 1e-8.
      v Use `(vcov_estimate + t(vcov_estimate)) / 2` to symmetrize.

# calibrate_to_estimate() errors when vcov_estimate is not positive definite

    Code
      calibrate_to_estimate(design, ~sex, estimate = tots$estimate, vcov_estimate = bad_vcov)
    Condition
      Error in `value[[3L]]()`:
      x `vcov_estimate` is not positive definite (Cholesky factorization failed).
      i Singular or indefinite matrices are not valid variance-covariance matrices.
      v Ensure all eigenvalues are strictly positive.

# calibrate_to_estimate() errors when calibration does not converge

    Code
      calibrate_to_estimate(design, ~sex, estimate = tots$estimate, vcov_estimate = tots$
        vcov_estimate, control = list(maxit = 1L, epsilon = 1e-100))
    Condition
      Error in `value[[3L]]()`:
      x Calibration failed.
      i Convergence was not achieved for replicate 1. Consider increasing `maxit` or relaxing `epsilon`.
      v Try increasing `control$maxit` or relaxing `control$epsilon`.

# calibrate_to_estimate() errors when svrep warns convergence but returns normally

    Code
      surveywts::calibrate_to_estimate(design, ~sex, estimate = tots$estimate,
      vcov_estimate = tots$vcov_estimate)
    Condition
      Error in `surveywts::calibrate_to_estimate()`:
      x Calibration did not converge.
      i did not converge after 1 iterations
      v Try increasing `control$maxit` or relaxing `control$epsilon`.

