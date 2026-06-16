# calibrate_to_survey() rejects non-replicate primary_design

    Code
      calibrate_to_survey(taylor, control, variables = c(sex))
    Condition
      Error in `calibrate_to_survey()`:
      x `primary_design` must be a <survey_replicate> or a <survey_nonprob> with replicate weights, got <surveycore::survey_taylor>.
      i Replicate weights are required to propagate control-survey uncertainty.
      v Use `create_bootstrap_weights()` or another `create_*_weights()` function to add replicate weights before calibrating.

# calibrate_to_survey() rejects non-replicate control_design

    Code
      calibrate_to_survey(primary, taylor, variables = c(sex))
    Condition
      Error in `calibrate_to_survey()`:
      x `control_design` must be a <survey_replicate> or a <survey_nonprob> with replicate weights, got <surveycore::survey_taylor>.
      i Replicate weights are required to propagate control-survey uncertainty.
      v Use `create_bootstrap_weights()` or another `create_*_weights()` function to add replicate weights.

# calibrate_to_survey() rejects non-taylor reference_design

    Code
      calibrate_to_survey(primary, control, variables = c(sex), reference_design = primary)
    Condition
      Error in `calibrate_to_survey()`:
      x `reference_design` must be a <survey_taylor> or `NULL`, got <surveycore::survey_replicate>.
      i `reference_design` is used for provenance tracking only.

# calibrate_to_survey() rejects invalid unit_scale (non-numeric)

    Code
      calibrate_to_survey(primary, control, variables = c(sex), unit_scale = "bad")
    Condition
      Error in `.validate_unit_scale()`:
      x `unit_scale` must be a positive numeric vector or `NULL`.
      i Got <character>.
      v Supply a positive numeric vector of length 100.

# calibrate_to_survey() rejects unit_scale with wrong length

    Code
      calibrate_to_survey(primary, control, variables = c(sex), unit_scale = rep(1, 5))
    Condition
      Error in `.validate_unit_scale()`:
      x `unit_scale` must have length equal to the number of rows in `data`.
      i Got length 5 but expected 100.
      v Supply a positive numeric vector of length 100.

# calibrate_to_survey() rejects unit_scale with NA

    Code
      calibrate_to_survey(primary, control, variables = c(sex), unit_scale = {
        us2 <- rep(1, nrow(primary@data))
        us2[1L] <- NA_real_
        us2
      })
    Condition
      Error in `.validate_unit_scale()`:
      x `unit_scale` must not contain `NA` values.
      i Found 1 `NA` value in `unit_scale`.
      v Remove `NA`s or set `unit_scale = NULL` to use uniform q-weights.

# calibrate_to_survey() rejects unit_scale with non-positive values

    Code
      calibrate_to_survey(primary, control, variables = c(sex), unit_scale = {
        us2 <- rep(1, nrow(primary@data))
        us2[1L] <- -1
        us2
      })
    Condition
      Error in `.validate_unit_scale()`:
      x `unit_scale` must contain only strictly positive values.
      i Found 1 non-positive value in `unit_scale`.
      v All q-weights must be > 0.

# calibrate_to_survey() rejects variables not in primary_design

    Code
      calibrate_to_survey(primary, control, variables = c(nonexistent_var))
    Condition
      Error in `value[[3L]]()`:
      x Calibration variables not found in `primary_design`.
      i Tidy-select error: Can't select columns that don't exist. x Column `nonexistent_var` doesn't exist.

# calibrate_to_survey() propagates convergence warning as error

    Code
      calibrate_to_survey(primary, control, variables = c(sex))
    Condition
      Error:
      x Sample-based calibration did not converge after 50 iterations.
      i svrep::calibrate_to_sample() reported: Calibration did not converge
      v Increase `control$maxit`, relax `control$epsilon`, or verify that the variables are present in both designs.

# calibrate_to_survey() propagates hard svrep errors

    Code
      calibrate_to_survey(primary, control, variables = c(sex))
    Condition
      Error in `value[[3L]]()`:
      x svrep::calibrate_to_sample() encountered an error.
      i svrep reported: svrep internal error

# calibrate_to_estimate() rejects non-replicate design

    Code
      calibrate_to_estimate(taylor, targets, vcov_est)
    Condition
      Error in `calibrate_to_estimate()`:
      x `design` must be a <survey_replicate> or a <survey_nonprob> with replicate weights, got <surveycore::survey_taylor>.
      i Replicate weights are required to propagate the uncertainty of the external estimates.
      v Use `create_bootstrap_weights()` or another `create_*_weights()` function to add replicate weights.

# calibrate_to_estimate() rejects non-taylor reference_design

    Code
      calibrate_to_estimate(primary, targets, vcov_est, reference_design = primary)
    Condition
      Error in `calibrate_to_estimate()`:
      x `reference_design` must be a <survey_taylor> or `NULL`, got <surveycore::survey_replicate>.
      i `reference_design` is used for provenance tracking only.

# calibrate_to_estimate() rejects invalid unit_scale

    Code
      calibrate_to_estimate(primary, targets, vcov_est, unit_scale = "bad")
    Condition
      Error in `.validate_unit_scale()`:
      x `unit_scale` must be a positive numeric vector or `NULL`.
      i Got <character>.
      v Supply a positive numeric vector of length 100.

# calibrate_to_estimate() rejects unit_scale with wrong length

    Code
      calibrate_to_estimate(primary, targets, vcov_est, unit_scale = rep(1, 5))
    Condition
      Error in `.validate_unit_scale()`:
      x `unit_scale` must have length equal to the number of rows in `data`.
      i Got length 5 but expected 100.
      v Supply a positive numeric vector of length 100.

# calibrate_to_estimate() rejects unit_scale with NA

    Code
      calibrate_to_estimate(primary, targets, vcov_est, unit_scale = {
        us2 <- rep(1, nrow(primary@data))
        us2[1L] <- NA_real_
        us2
      })
    Condition
      Error in `.validate_unit_scale()`:
      x `unit_scale` must not contain `NA` values.
      i Found 1 `NA` value in `unit_scale`.
      v Remove `NA`s or set `unit_scale = NULL` to use uniform q-weights.

# calibrate_to_estimate() rejects unit_scale with non-positive values

    Code
      calibrate_to_estimate(primary, targets, vcov_est, unit_scale = {
        us2 <- rep(1, nrow(primary@data))
        us2[1L] <- -1
        us2
      })
    Condition
      Error in `.validate_unit_scale()`:
      x `unit_scale` must contain only strictly positive values.
      i Found 1 non-positive value in `unit_scale`.
      v All q-weights must be > 0.

# calibrate_to_estimate() rejects non-named-list targets

    Code
      calibrate_to_estimate(primary, list(c(60, 40)), vcov_est)
    Condition
      Error in `calibrate_to_estimate()`:
      x `targets` must be a non-empty named list with all elements named.
      i Each name gives the variable in `design@data`, and each element is a named numeric vector of population count totals.

# calibrate_to_estimate() rejects targets element with no names

    Code
      calibrate_to_estimate(primary, list(sex = c(60, 40)), vcov_est)
    Condition
      Error in `calibrate_to_estimate()`:
      x `targets$sex` must be a named numeric vector.
      i Got <numeric> with no names.
      v Supply count totals as e.g. `c(level1 = 1000, level2 = 500)`.

# calibrate_to_estimate() rejects targets element with non-positive values

    Code
      calibrate_to_estimate(primary, list(sex = c(F = 60, M = -1)), vcov_est)
    Condition
      Error in `calibrate_to_estimate()`:
      x `targets$sex` contains 1 value(s) that are NA or not strictly positive.
      i All population count totals must be > 0.

# calibrate_to_estimate() rejects targets variable not in design

    Code
      calibrate_to_estimate(primary, list(nonexistent_var = c(a = 60, b = 40)),
      vcov_est)
    Condition
      Error in `calibrate_to_estimate()`:
      x Calibration variable(s) not found in `design`: nonexistent_var.
      i Available columns: id, age_group, sex, education, region, base_weight, rep_1, rep_2, rep_3, rep_4, rep_5, rep_6, rep_7, rep_8, rep_9, rep_10, rep_11, rep_12, ..., rep_49, and rep_50.

# calibrate_to_estimate() rejects targets levels mismatch

    Code
      calibrate_to_estimate(primary, list(sex = c(Female = 110, Male = 90)), vcov_est)
    Condition
      Error in `calibrate_to_estimate()`:
      x Level labels in `targets$sex` do not exactly match the levels in `design@data$sex`.
      i Levels in data but not in targets: F, M; Levels in targets but not in data: Female, Male

# calibrate_to_estimate() rejects vcov with NA

    Code
      calibrate_to_estimate(primary, targets, vcov_bad)
    Condition
      Error in `calibrate_to_estimate()`:
      x `vcov_estimate` contains 1 NA value(s).
      i The variance-covariance matrix must be fully observed.

# calibrate_to_estimate() rejects vcov with wrong dimensions

    Code
      calibrate_to_estimate(primary, targets, vcov_bad)
    Condition
      Error in `calibrate_to_estimate()`:
      x `vcov_estimate` must be 2 x 2 (one row/column per element of `unlist(targets)`).
      i Got 3 x 3.

# calibrate_to_estimate() rejects non-symmetric vcov

    Code
      calibrate_to_estimate(primary, targets, vcov_bad)
    Condition
      Error in `calibrate_to_estimate()`:
      x `vcov_estimate` is not symmetric: max(|V - V^T|) = 49.
      i Symmetry tolerance is 1e-8.
      v Symmetrize with `(vcov + t(vcov)) / 2`.

# calibrate_to_estimate() rejects non-positive-definite vcov

    Code
      calibrate_to_estimate(primary, targets, vcov_bad)
    Condition
      Error in `calibrate_to_estimate()`:
      x `vcov_estimate` is not positive definite.
      i Cholesky decomposition failed: the leading minor of order 2 is not positive
      v Use a valid variance-covariance matrix (all eigenvalues > 0).

# calibrate_to_estimate() propagates convergence warning as error

    Code
      calibrate_to_estimate(primary, targets, vcov_est)
    Condition
      Error:
      x Calibration to estimate did not converge after 50 iterations.
      i svrep::calibrate_to_estimate() reported: Calibration did not converge
      v Increase `control$maxit`, relax `control$epsilon`, or verify the target counts are consistent with the design.

# calibrate_to_estimate() propagates hard svrep errors

    Code
      calibrate_to_estimate(primary, targets, vcov_est)
    Condition
      Error in `value[[3L]]()`:
      x svrep::calibrate_to_estimate() encountered an error.
      i svrep reported: svrep internal error

# calibrate_to_survey() fires surveywts_error_primary_no_repweights

    Code
      calibrate_to_survey(primary_design = primary_no_rep, control_design = control,
        variables = c(sex))
    Condition
      Error in `calibrate_to_survey()`:
      x `primary_design` is a <survey_nonprob> but has no replicate weights.
      i Replicate weights are required to propagate control-survey uncertainty.
      v Use `create_bootstrap_weights()` or another `create_*_weights()` function to add replicate weights before calibrating.

# calibrate_to_survey() fires surveywts_error_control_no_repweights

    Code
      calibrate_to_survey(primary_design = primary, control_design = control_no_rep,
        variables = c(sex))
    Condition
      Error in `calibrate_to_survey()`:
      x `control_design` is a <survey_nonprob> but has no replicate weights.
      i Replicate weights are required to propagate control-survey uncertainty.
      v Use `create_bootstrap_weights()` or another `create_*_weights()` function to add replicate weights.

# calibrate_to_estimate() fires surveywts_error_design_no_repweights

    Code
      calibrate_to_estimate(design_no_rep, targets, vcov_est)
    Condition
      Error in `calibrate_to_estimate()`:
      x `design` is a <survey_nonprob> but has no replicate weights.
      i Replicate weights are required to propagate the uncertainty of the external estimates.
      v Use `create_bootstrap_weights()` or another `create_*_weights()` function to add replicate weights before calibrating.

