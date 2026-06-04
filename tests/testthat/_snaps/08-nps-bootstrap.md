# print(survey_nonprob) includes bootstrap replicates line when repweights present

    Code
      print(result)
    Output
      # A calibrated survey design: 500 observations, 17 variables
      # Variance: model-assisted (SRS assumption)
      # IDs: ~1 | Strata: NULL | Weights: ipw_weight 
      # Weighting history: 3 steps 
      #   Step 1 [2026-06-03]: ipw [~age_group + sex, logit, n_ref=1000, N_hat=612] 
      #   Step 2 [2026-06-03]: raking (targets: age_group, sex) 
      #   Step 3 [2026-06-03]: bootstrap_weights 
      # Bootstrap replicates: 10 (quasi-randomization, level A)

# print(survey_nonprob) unchanged when no repweights

    Code
      print(lev_a)
    Output
      # A calibrated survey design: 500 observations, 7 variables
      # Variance: model-assisted (SRS assumption)
      # IDs: ~1 | Strata: NULL | Weights: ipw_weight 
      # Weighting history: 2 steps 
      #   Step 1 [2026-06-03]: ipw [~age_group + sex, logit, n_ref=1000, N_hat=612] 
      #   Step 2 [2026-06-03]: raking (targets: age_group, sex) 

# create_bootstrap_weights() rejects survey_taylor with quasi-randomization

    Code
      create_bootstrap_weights(td, type = "quasi-randomization")
    Condition
      Error in `create_bootstrap_weights()`:
      x `type = 'quasi-randomization'` requires a <survey_nonprob>; got <surveycore::survey_taylor>.
      i The quasi-randomization bootstrap is designed for non-probability samples with IPW history.
      v Use `ipw()` to create a <survey_nonprob>, then call `create_bootstrap_weights()`.

# create_bootstrap_weights() rejects weighted_df with quasi-randomization

    Code
      create_bootstrap_weights(wd, type = "quasi-randomization")
    Condition
      Error in `create_bootstrap_weights()`:
      x `type = 'quasi-randomization'` requires a <survey_nonprob>; got <weighted_df>.
      i The quasi-randomization bootstrap is designed for non-probability samples with IPW history.
      v Use `ipw()` to create a <survey_nonprob>, then call `create_bootstrap_weights()`.

# create_bootstrap_weights() rejects survey_taylor with hybrid

    Code
      create_bootstrap_weights(td, type = "hybrid")
    Condition
      Error in `create_bootstrap_weights()`:
      x `type = 'hybrid'` requires a <survey_nonprob>; got <surveycore::survey_taylor>.
      i The hybrid bootstrap is designed for non-probability samples.
      v Use `ipw()` to create a <survey_nonprob>, then call `create_bootstrap_weights()`.

# create_bootstrap_weights() errors when no ipw history present

    Code
      create_bootstrap_weights(np_no_ipw, type = "quasi-randomization")
    Condition
      Error in `.quasi_randomization_bootstrap()`:
      x No `ipw()` step found in the weighting history of `data`.
      i The quasi-randomization bootstrap requires an `ipw()` step in the weighting history.
      v Call `ipw()` on the non-probability sample before calling `create_bootstrap_weights()`.

# create_bootstrap_weights() errors when no reference available

    Code
      create_bootstrap_weights(ipw_result, type = "quasi-randomization")
    Condition
      Error in `.quasi_randomization_bootstrap()`:
      x A reference probability sample is required for `type = 'quasi-randomization'`.
      i No reference design found in the `ipw()` history entry and `reference_sample` was not supplied.
      v Supply the reference design via `reference_sample`, or re-run `ipw()` with a <survey_taylor> reference.

# create_bootstrap_weights() errors with hybrid type (not yet implemented)

    Code
      create_bootstrap_weights(np, type = "hybrid")
    Condition
      Error in `create_bootstrap_weights()`:
      x `type = "hybrid"` is not yet available.
      i The hybrid bootstrap requires `mass_imputation()`, which is not yet implemented.
      v Use `type = "quasi-randomization"` for IPW-weighted non-probability samples.

# create_bootstrap_weights() rejects survey_replicate as reference_sample

    Code
      create_bootstrap_weights(lev_a, type = "quasi-randomization", reference_sample = rep_ref)
    Condition
      Error in `.validate_reference_sample()`:
      x `reference_sample` must be a <survey_taylor>, not <surveycore::survey_replicate>.
      i A replicate-weighted reference survey is not supported here. Only <survey_taylor> (Taylor-series linearization design) is accepted.
      v Use `calibrate_to_survey()` for the Opsomer-Erciulescu approach with a replicate-weighted reference.

# create_bootstrap_weights() rejects list as reference_sample

    Code
      create_bootstrap_weights(lev_a, type = "quasi-randomization", reference_sample = list())
    Condition
      Error in `.validate_reference_sample()`:
      x `reference_sample` must be a <survey_taylor>, not <list>.
      i Only <survey_taylor> (Taylor-series linearization design) is accepted.
      v Pass a <survey_taylor> created with `surveycore::as_survey()`.

# create_bootstrap_weights() rejects mse = chrostowski for prob-sample type

    Code
      create_bootstrap_weights(td, type = "Rao-Wu", mse = "chrostowski")
    Condition
      Error in `create_bootstrap_weights()`:
      x `mse = "chrostowski"` is only available for NPS types (`type = "quasi-randomization"`).
      i `mse = "chrostowski"` is the Chrostowski et al. (2025) formula for NPS variance. It cannot be applied to probability-sample designs.
      v Use `mse = "mse"` or `mse = "uncentered"` for probability-sample types.

# create_bootstrap_weights() rejects mse = TRUE (logical not character)

    Code
      create_bootstrap_weights(td, mse = TRUE)
    Condition
      Error in `create_bootstrap_weights()`:
      x `mse` must be a character string, not <logical>.
      i `mse = TRUE` and `mse = FALSE` are no longer accepted.
      v Use `mse = "mse"` (replaces `TRUE`) or `mse = "uncentered"` (replaces `FALSE`).

# create_bootstrap_weights() rejects mse = FALSE (logical not character)

    Code
      create_bootstrap_weights(td, mse = FALSE)
    Condition
      Error in `create_bootstrap_weights()`:
      x `mse` must be a character string, not <logical>.
      i `mse = TRUE` and `mse = FALSE` are no longer accepted.
      v Use `mse = "mse"` (replaces `TRUE`) or `mse = "uncentered"` (replaces `FALSE`).

# create_bootstrap_weights() errors when all draws fail

    Code
      suppressWarnings(create_bootstrap_weights(nps_raked, type = "quasi-randomization",
        replicates = 10L, seed = 8L))
    Condition
      Error in `.quasi_randomization_bootstrap()`:
      x All 10 bootstrap draws failed; no replicate weights could be produced.
      i Every resampled draw produced degenerate propensity scores or calibration divergence.
      v Check the `data` for single-level covariates or extreme covariate imbalance with the reference.

