# create_group_jackknife_weights() rejects data.frame input

    Code
      create_group_jackknife_weights(df)
    Condition
      Error in `.validate_replicate_input()`:
      x `data` is a <data.frame>, not a survey design.
      i This function requires a <survey_taylor> or <survey_nonprob> object.
      v Convert with `surveycore::as_survey()`.

# create_group_jackknife_weights() rejects survey_replicate input

    Code
      create_group_jackknife_weights(rep)
    Condition
      Error in `.validate_replicate_input()`:
      x `data` is already a <survey_replicate>.
      i Replicate weights cannot be created from a design that already has replicates.

# create_group_jackknife_weights() rejects survey_taylor input

    Code
      create_group_jackknife_weights(td)
    Condition
      Error in `create_group_jackknife_weights()`:
      x `create_group_jackknife_weights()` requires a <survey_nonprob>; got <surveycore::survey_taylor>.
      i The DAGJK for NPS requires an IPW weighting history attached to a <survey_nonprob> object.
      v Use `ipw()` to create a <survey_nonprob>, then call `create_group_jackknife_weights()`.

# create_group_jackknife_weights() rejects survey_replicate reference_sample

    Code
      create_group_jackknife_weights(datasets$A, reference_sample = rep)
    Condition
      Error in `.validate_reference_sample()`:
      x `reference_sample` must be a <survey_taylor>, not <surveycore::survey_replicate>.
      i A replicate-weighted reference survey is not supported here. Only <survey_taylor> (Taylor-series linearization design) is accepted.
      v Use `calibrate_to_survey()` for the Opsomer-Erciulescu approach with a replicate-weighted reference.

# create_group_jackknife_weights() rejects data.frame reference_sample

    Code
      create_group_jackknife_weights(datasets$A, reference_sample = df_ref)
    Condition
      Error in `.validate_reference_sample()`:
      x `reference_sample` must be a <survey_taylor>, not <data.frame>.
      i Use `survey::svydesign()` to convert an SRS data frame to a <survey_taylor> object.
      v Pass a <survey_taylor> created with `surveycore::as_survey()`.

# create_group_jackknife_weights() errors when reference_sample = NULL and no stored reference

    Code
      create_group_jackknife_weights(np, groups = 2L)
    Condition
      Error in `create_group_jackknife_weights()`:
      x A reference probability sample is required for `create_group_jackknife_weights()`.
      i No reference design found in the `ipw()` history entry and `reference_sample` was not supplied.
      v Supply the reference design via `reference_sample`, or re-run `ipw()` with a <survey_taylor> reference.

# create_group_jackknife_weights() rejects groups = 1

    Code
      create_group_jackknife_weights(datasets$A, groups = 1L)
    Condition
      Error in `.validate_groups_arg()`:
      x `groups` must be >= 2; got 1.
      i The DAGJK formula is degenerate at G = 1 (variance estimate is 0).
      v Use at least 2 groups. Valliant (2020) recommends `groups = 50`.

# create_group_jackknife_weights() rejects groups = 50.5 (fractional)

    Code
      create_group_jackknife_weights(datasets$A, groups = 50.5)
    Condition
      Error in `.validate_groups_arg()`:
      x `groups` must be a whole number, not 50.5.
      v Use an integer value, e.g. `groups = 50`.

# create_group_jackknife_weights() rejects groups = NA

    Code
      create_group_jackknife_weights(datasets$A, groups = NA)
    Condition
      Error in `.validate_groups_arg()`:
      x `groups` must be a single, non-NA number.
      i Got <logical> of length 1.
      v Supply a whole number >= 2, e.g. `groups = 50L`.

# create_group_jackknife_weights() rejects groups exceeding combined N

    Code
      create_group_jackknife_weights(datasets$A, groups = 581L)
    Condition
      Error in `.validate_groups_arg()`:
      x `groups` (581) exceeds the combined NPS + reference row count (580).
      i Each group must contain at least 1 unit; groups cannot exceed the total number of combined rows.
      v Reduce `groups` to at most 580 (combined NPS + reference rows).

# create_group_jackknife_weights() rejects data with no ipw history

    Code
      create_group_jackknife_weights(np_no_ipw, groups = 5L)
    Condition
      Error in `create_group_jackknife_weights()`:
      x No `ipw()` step found in the weighting history of `data`.
      i `create_group_jackknife_weights()` requires an `ipw()` step in the weighting history to refit the propensity model per replicate.
      v Call `ipw()` on the non-probability sample before calling `create_group_jackknife_weights()`.

# create_group_jackknife_weights() warns when repweights already populated

    Code
      create_group_jackknife_weights(r1, groups = 10L, seed = 2L)
    Condition
      Warning:
      ! Overwriting 10 existing replicate weight column(s) in `data`.
      i A previous call to `create_group_jackknife_weights()` already produced 10 replicate column(s). They will be replaced.
      v Inspect the previous replicates before overwriting if needed.
    Output
      # A calibrated survey design: 80 observations, 13 variables
      # Variance: model-assisted (SRS assumption)
      # IDs: ~1 | Strata: NULL | Weights: ipw_weight 
      # Weighting history: 3 steps 
      #   Step 1: ipw [~age_group + sex, logit, n_ref=500, N_hat=501] 
      #   Step 2: group_jackknife_weights 
      #   Step 3: group_jackknife_weights 

