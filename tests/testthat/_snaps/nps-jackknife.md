# create_jackknife_weights() type='grouped' rejects data.frame input

    Code
      create_jackknife_weights(df, replicates = 10L, type = "grouped")
    Condition
      Error in `.validate_replicate_input()`:
      x `data` is a <data.frame>, not a survey design.
      i This function requires a <survey_taylor> or <survey_nonprob> object.
      v Convert with `surveycore::as_survey()`.

# create_jackknife_weights() type='grouped' rejects survey_replicate input

    Code
      create_jackknife_weights(rep, replicates = 10L, type = "grouped")
    Condition
      Error in `.validate_replicate_input()`:
      x `data` is already a <survey_replicate>.
      i Replicate weights cannot be created from a design that already has replicates.

# create_jackknife_weights() type='grouped' rejects survey_replicate reference_sample

    Code
      create_jackknife_weights(datasets$A, replicates = 10L, type = "grouped",
      reference_sample = rep)
    Condition
      Error in `.validate_reference_sample()`:
      x `reference_sample` must be a <survey_taylor>, not <surveycore::survey_replicate>.
      i A replicate-weighted reference survey is not supported here. Only <survey_taylor> (Taylor-series linearization design) is accepted.
      v Use `calibrate_to_survey()` for the Opsomer-Erciulescu approach with a replicate-weighted reference.

# create_jackknife_weights() type='grouped' rejects data.frame reference_sample

    Code
      create_jackknife_weights(datasets$A, replicates = 10L, type = "grouped",
      reference_sample = df_ref)
    Condition
      Error in `.validate_reference_sample()`:
      x `reference_sample` must be a <survey_taylor>, not <data.frame>.
      i Use `survey::svydesign()` to convert an SRS data frame to a <survey_taylor> object.
      v Pass a <survey_taylor> created with `surveycore::as_survey()`.

# create_jackknife_weights() errors when reference_sample = NULL and no stored reference

    Code
      create_jackknife_weights(np, replicates = 2L, type = "grouped")
    Condition
      Error in `create_jackknife_weights()`:
      x A reference probability sample is required for `create_jackknife_weights()` with a non-probability sample.
      i No reference design found in the `ipw()` history entry and `reference_sample` was not supplied.
      v Supply the reference design via `reference_sample`, or re-run `ipw()` with a <survey_taylor> reference.

# create_jackknife_weights() type='grouped' rejects replicates = NULL

    Code
      create_jackknife_weights(datasets$A, type = "grouped")
    Condition
      Error in `create_jackknife_weights()`:
      x `replicates` is required when `type = "grouped"`.
      v Supply an integer, e.g. `replicates = 50L`.

# create_jackknife_weights() type='grouped' rejects replicates = 1

    Code
      create_jackknife_weights(datasets$A, replicates = 1L, type = "grouped")
    Condition
      Error in `.validate_replicates_dagjk_arg()`:
      x `replicates` must be >= 2; got 1.
      i The DAGJK formula is degenerate at G = 1 (variance estimate is 0).
      v Use at least 2 groups. Valliant (2020) recommends `replicates = 50`.

# create_jackknife_weights() type='grouped' rejects fractional replicates

    Code
      create_jackknife_weights(datasets$A, replicates = 50.5, type = "grouped")
    Condition
      Error in `.validate_replicates_dagjk_arg()`:
      x `replicates` must be a whole number, not 50.5.
      v Use an integer value, e.g. `replicates = 50`.

# create_jackknife_weights() type='grouped' rejects replicates = NA

    Code
      create_jackknife_weights(datasets$A, replicates = NA, type = "grouped")
    Condition
      Error in `.validate_replicates_dagjk_arg()`:
      x `replicates` must be a single, non-NA number.
      i Got <logical> of length 1.
      v Supply a whole number >= 2, e.g. `replicates = 50L`.

# create_jackknife_weights() type='grouped' rejects replicates exceeding combined N

    Code
      create_jackknife_weights(datasets$A, replicates = 581L, type = "grouped")
    Condition
      Error in `.validate_replicates_dagjk_arg()`:
      x `replicates` (581) exceeds the combined NPS + reference row count (580).
      i Each group must contain at least 1 unit; groups cannot exceed the total number of combined rows.
      v Reduce `replicates` to at most 580 (combined NPS + reference rows).

# create_jackknife_weights() type='grouped' rejects data with no weighting history

    Code
      create_jackknife_weights(np_no_history, replicates = 5L, type = "grouped")
    Condition
      Error in `create_jackknife_weights()`:
      x No IPW or calibration step found in the weighting history of `data`.
      i `create_jackknife_weights()` requires an `ipw()` or calibration step in the weighting history.
      v Call `ipw()` or a calibration function on the non-probability sample before calling `create_jackknife_weights()`.

# create_jackknife_weights() type='grouped' warns when repweights already populated

    Code
      .pin_ts(create_jackknife_weights(r1, replicates = 10L, type = "grouped", seed = 2L))
    Condition
      Warning:
      ! Overwriting 10 existing replicate weight column(s) in `data`.
      i A previous call to `create_jackknife_weights()` already produced 10 replicate column(s). They will be replaced.
      v Inspect the previous replicates before overwriting if needed.
    Output
      # A calibrated survey design: 80 observations, 13 variables
      # Variance: model-assisted (SRS assumption)
      # IDs: ~1 | Strata: NULL | Weights: ipw_weight 
      # Weighting history: 3 steps 
      #   Step 1 [2025-01-15]: ipw [~age_group + sex, logit, n_ref=500, N_hat=501] 
      #   Step 2 [2025-01-15]: jackknife_weights 
      #   Step 3 [2025-01-15]: jackknife_weights 

# create_jackknife_weights() type='grouped' warns when average group size < 5

    Code
      .pin_ts(withCallingHandlers(create_jackknife_weights(datasets$A, replicates = 200L,
      type = "grouped", seed = 1L), warning = function(w) {
        if (!inherits(w, "surveywts_warning_jackknife_small_groups")) {
          invokeRestart("muffleWarning")
        }
      }))
    Condition
      Warning:
      ! Average group size is 2 unit(s) (580 combined / 200 groups).
      i Groups with fewer than 5 units may cause the logistic model to fail to converge in some replicates.
      v Reduce `replicates` or ensure the combined NPS + reference dataset is large enough relative to the number of groups.
    Output
      # A calibrated survey design: 80 observations, 203 variables
      # Variance: model-assisted (SRS assumption)
      # IDs: ~1 | Strata: NULL | Weights: ipw_weight 
      # Weighting history: 2 steps 
      #   Step 1 [2025-01-15]: ipw [~age_group + sex, logit, n_ref=500, N_hat=501] 
      #   Step 2 [2025-01-15]: jackknife_weights 

# create_jackknife_weights() type='grouped' warns when > 10% of replicates fail

    Code
      .pin_ts(create_jackknife_weights(tiny_ipw2, replicates = 5L, type = "grouped",
        seed = 7L))
    Condition
      Warning:
      ! Average group size is 2 unit(s) (12 combined / 5 groups).
      i Groups with fewer than 5 units may cause the logistic model to fail to converge in some replicates.
      v Reduce `replicates` or ensure the combined NPS + reference dataset is large enough relative to the number of groups.
      Warning:
      ! 1 of 5 group replicates failed and were skipped.
      i A replicate fails when the logistic model does not converge or produces degenerate propensity scores in the reduced dataset.
      v Reduce `replicates` or inspect the data for extreme covariate imbalance.
    Output
      # A calibrated survey design: 6 observations, 6 variables
      # Variance: model-assisted (SRS assumption)
      # IDs: ~1 | Strata: NULL | Weights: ipw_weight 
      # Weighting history: 2 steps 
      #   Step 1 [2025-01-15]: ipw [~age_group, logit, n_ref=6, N_hat=600] 
      #   Step 2 [2025-01-15]: jackknife_weights 

