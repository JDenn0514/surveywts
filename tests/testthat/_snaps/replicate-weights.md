# create_bootstrap_weights() rejects data.frame input

    Code
      create_bootstrap_weights(df)
    Condition
      Error in `.validate_replicate_input()`:
      x `data` is a <data.frame>, not a survey design.
      i This function requires a <survey_taylor> or <survey_nonprob> object.
      v Convert with `surveycore::as_survey()`.

# create_bootstrap_weights() rejects survey_replicate input

    Code
      create_bootstrap_weights(rep)
    Condition
      Error in `.validate_replicate_input()`:
      x `data` is already a <survey_replicate>.
      i Replicate weights cannot be created from a design that already has replicates.

# create_bootstrap_weights() rejects unsupported class

    Code
      create_bootstrap_weights(list(x = 1))
    Condition
      Error in `.validate_replicate_input()`:
      x `data` is <list>, which is not a supported input class.
      i Supported classes: <survey_taylor> and <survey_nonprob>.
      v Use `surveycore::as_survey()` or `surveycore::survey_nonprob()`.

# create_bootstrap_weights() rejects replicates = 0

    Code
      create_bootstrap_weights(td, replicates = 0L)
    Condition
      Error in `.validate_replicates_arg()`:
      x `replicates` must be at least 2, got 0.

# create_bootstrap_weights() rejects replicates = 1 (boundary: min is 2)

    Code
      create_bootstrap_weights(td, replicates = 1L)
    Condition
      Error in `.validate_replicates_arg()`:
      x `replicates` must be at least 2, got 1.

# create_bootstrap_weights() rejects fractional replicates

    Code
      create_bootstrap_weights(td, replicates = 1.5)
    Condition
      Error in `.validate_replicates_arg()`:
      x `replicates` must be a whole number, not 1.5.
      v Use an integer value, e.g. `replicates = 2`.

# create_bootstrap_weights() rejects character replicates

    Code
      create_bootstrap_weights(td, replicates = "fifty")
    Condition
      Error in `.validate_replicates_arg()`:
      x `replicates` must be a single number.

# create_bootstrap_weights() rejects NA replicates

    Code
      create_bootstrap_weights(td, replicates = NA_integer_)
    Condition
      Error in `.validate_replicates_arg()`:
      x `replicates` must be a single number.

# create_jackknife_weights() errors when random-groups needs replicates

    Code
      create_jackknife_weights(td, type = "random-groups")
    Condition
      Error in `create_jackknife_weights()`:
      x `replicates` is required when `type = "random-groups"`.
      v Supply an integer, e.g. `replicates = 20L`.

# create_jackknife_weights() rejects data.frame input

    Code
      create_jackknife_weights(df)
    Condition
      Error in `.validate_replicate_input()`:
      x `data` is a <data.frame>, not a survey design.
      i This function requires a <survey_taylor> or <survey_nonprob> object.
      v Convert with `surveycore::as_survey()`.

# create_jackknife_weights() rejects survey_replicate input

    Code
      create_jackknife_weights(rep)
    Condition
      Error in `.validate_replicate_input()`:
      x `data` is already a <survey_replicate>.
      i Replicate weights cannot be created from a design that already has replicates.

# create_jackknife_weights() rejects weighted_df input

    Code
      create_jackknife_weights(wdf)
    Condition
      Error in `.validate_replicate_input()`:
      x `data` is a <weighted_df>, not a survey design.
      i This function requires a <survey_taylor> or <survey_nonprob> object.
      v Convert with `surveycore::as_survey()`.

# create_jackknife_weights() rejects unsupported class

    Code
      create_jackknife_weights(list(x = 1))
    Condition
      Error in `.validate_replicate_input()`:
      x `data` is <list>, which is not a supported input class.
      i Supported classes: <survey_taylor> and <survey_nonprob>.
      v Use `surveycore::as_survey()` or `surveycore::survey_nonprob()`.

# create_jackknife_weights() rejects fractional replicates for random-groups

    Code
      create_jackknife_weights(td, replicates = 1.5, type = "random-groups")
    Condition
      Error in `.validate_replicates_arg()`:
      x `replicates` must be a whole number, not 1.5.
      v Use an integer value, e.g. `replicates = 2`.

# create_jackknife_weights() rejects replicates = 1 for random-groups

    Code
      create_jackknife_weights(td, replicates = 1L, type = "random-groups")
    Condition
      Error in `.validate_replicates_arg()`:
      x `replicates` must be at least 2, got 1.

# create_jackknife_weights() rejects survey_nonprob + random-groups

    Code
      create_jackknife_weights(np, replicates = 10L, type = "random-groups")
    Condition
      Error in `create_jackknife_weights()`:
      x <survey_nonprob> input is not supported with `type = "random-groups"`.
      i Only `type = "delete-1"` is supported for non-probability designs.
      v Use `type = "delete-1"` or convert to <survey_taylor>.

# create_brr_weights() rejects data.frame input

    Code
      create_brr_weights(df)
    Condition
      Error in `.validate_replicate_input()`:
      x `data` is a <data.frame>, not a survey design.
      i This function requires a <survey_taylor> or <survey_nonprob> object.
      v Convert with `surveycore::as_survey()`.

# create_brr_weights() rejects survey_replicate input

    Code
      create_brr_weights(rep)
    Condition
      Error in `.validate_replicate_input()`:
      x `data` is already a <survey_replicate>.
      i Replicate weights cannot be created from a design that already has replicates.

# create_brr_weights() rejects weighted_df input

    Code
      create_brr_weights(wdf)
    Condition
      Error in `.validate_replicate_input()`:
      x `data` is a <weighted_df>, not a survey design.
      i This function requires a <survey_taylor> or <survey_nonprob> object.
      v Convert with `surveycore::as_survey()`.

# create_brr_weights() rejects unsupported class

    Code
      create_brr_weights(list(x = 1))
    Condition
      Error in `.validate_replicate_input()`:
      x `data` is <list>, which is not a supported input class.
      i Supported classes: <survey_taylor> and <survey_nonprob>.
      v Use `surveycore::as_survey()` or `surveycore::survey_nonprob()`.

# create_brr_weights() rejects non-paired design

    Code
      create_brr_weights(td)
    Condition
      Error in `create_brr_weights()`:
      x BRR requires exactly 2 PSUs per stratum.
      i Stratum/a with wrong PSU count: 1, 2, 3, 4.
      v Use `create_gen_rep_weights()` for designs with unequal PSU counts per stratum.

# create_brr_weights() rejects survey_nonprob

    Code
      create_brr_weights(np)
    Condition
      Error in `create_brr_weights()`:
      x BRR requires a paired-PSU design; <survey_nonprob> has no PSU structure.
      v Use `create_bootstrap_weights()` for non-probability designs.

# create_brr_weights() rejects survey_taylor with strata but no PSU ids

    Code
      create_brr_weights(td)
    Condition
      Error in `create_brr_weights()`:
      x BRR requires a design with both strata and PSU IDs.
      i Strata: present; PSU IDs: missing.
      v Build the design with both `ids` and `strata` in `surveycore::as_survey()`.

# create_brr_weights() rejects survey_taylor with PSU ids but no strata

    Code
      create_brr_weights(td)
    Condition
      Error in `create_brr_weights()`:
      x BRR requires a design with both strata and PSU IDs.
      i Strata: missing; PSU IDs: present.
      v Build the design with both `ids` and `strata` in `surveycore::as_survey()`.

# create_brr_weights() rejects survey_taylor with neither strata nor PSU ids

    Code
      create_brr_weights(td)
    Condition
      Error in `create_brr_weights()`:
      x BRR requires a design with both strata and PSU IDs.
      i Strata: missing; PSU IDs: missing.
      v Build the design with both `ids` and `strata` in `surveycore::as_survey()`.

# create_brr_weights() rejects rho < 0

    Code
      create_brr_weights(pd, rho = -0.1)
    Condition
      Error in `create_brr_weights()`:
      x `rho` must satisfy 0 <= rho < 1; got -0.1.
      i `rho` = 0 gives standard BRR; `rho` > 0 gives Fay's BRR variant.

# create_brr_weights() rejects rho = 1

    Code
      create_brr_weights(pd, rho = 1)
    Condition
      Error in `create_brr_weights()`:
      x `rho` must satisfy 0 <= rho < 1; got 1.
      i `rho` = 0 gives standard BRR; `rho` > 0 gives Fay's BRR variant.

# create_gen_boot_weights() rejects data.frame input

    Code
      create_gen_boot_weights(df)
    Condition
      Error in `.validate_replicate_input()`:
      x `data` is a <data.frame>, not a survey design.
      i This function requires a <survey_taylor> or <survey_nonprob> object.
      v Convert with `surveycore::as_survey()`.

# create_gen_boot_weights() rejects survey_replicate input

    Code
      create_gen_boot_weights(rep)
    Condition
      Error in `.validate_replicate_input()`:
      x `data` is already a <survey_replicate>.
      i Replicate weights cannot be created from a design that already has replicates.

# create_gen_boot_weights() rejects weighted_df input

    Code
      create_gen_boot_weights(wdf)
    Condition
      Error in `.validate_replicate_input()`:
      x `data` is a <weighted_df>, not a survey design.
      i This function requires a <survey_taylor> or <survey_nonprob> object.
      v Convert with `surveycore::as_survey()`.

# create_gen_boot_weights() rejects unsupported class

    Code
      create_gen_boot_weights(list(x = 1))
    Condition
      Error in `.validate_replicate_input()`:
      x `data` is <list>, which is not a supported input class.
      i Supported classes: <survey_taylor> and <survey_nonprob>.
      v Use `surveycore::as_survey()` or `surveycore::survey_nonprob()`.

# create_gen_boot_weights() rejects replicates = 0

    Code
      create_gen_boot_weights(td, replicates = 0L)
    Condition
      Error in `.validate_replicates_arg()`:
      x `replicates` must be at least 2, got 0.

# create_gen_boot_weights() rejects replicates = 1 (boundary: min is 2)

    Code
      create_gen_boot_weights(td, replicates = 1L)
    Condition
      Error in `.validate_replicates_arg()`:
      x `replicates` must be at least 2, got 1.

# create_gen_boot_weights() rejects fractional replicates

    Code
      create_gen_boot_weights(td, replicates = 2.5)
    Condition
      Error in `.validate_replicates_arg()`:
      x `replicates` must be a whole number, not 2.5.
      v Use an integer value, e.g. `replicates = 2`.

# create_gen_boot_weights() rejects Deville-Tille without aux_var_names

    Code
      create_gen_boot_weights(td, variance_estimator = "Deville-Tille")
    Condition
      Error in `create_gen_boot_weights()`:
      x `variance_estimator = "Deville-Tille"` requires `aux_var_names`.
      v Pass column names, e.g. `aux_var_names = c(x1, x2)`.

# create_gen_boot_weights() rejects survey_nonprob

    Code
      create_gen_boot_weights(np)
    Condition
      Error in `create_gen_boot_weights()`:
      x `create_gen_boot_weights()` requires a probability-design structure.
      i <survey_nonprob> has no PSU or stratum structure required by this method.
      v Use `create_bootstrap_weights()` for non-probability designs.

# create_gen_rep_weights() rejects data.frame input

    Code
      create_gen_rep_weights(df)
    Condition
      Error in `.validate_replicate_input()`:
      x `data` is a <data.frame>, not a survey design.
      i This function requires a <survey_taylor> or <survey_nonprob> object.
      v Convert with `surveycore::as_survey()`.

# create_gen_rep_weights() rejects survey_replicate input

    Code
      create_gen_rep_weights(rep)
    Condition
      Error in `.validate_replicate_input()`:
      x `data` is already a <survey_replicate>.
      i Replicate weights cannot be created from a design that already has replicates.

# create_gen_rep_weights() rejects weighted_df input

    Code
      create_gen_rep_weights(wdf)
    Condition
      Error in `.validate_replicate_input()`:
      x `data` is a <weighted_df>, not a survey design.
      i This function requires a <survey_taylor> or <survey_nonprob> object.
      v Convert with `surveycore::as_survey()`.

# create_gen_rep_weights() rejects unsupported class

    Code
      create_gen_rep_weights(list(x = 1))
    Condition
      Error in `.validate_replicate_input()`:
      x `data` is <list>, which is not a supported input class.
      i Supported classes: <survey_taylor> and <survey_nonprob>.
      v Use `surveycore::as_survey()` or `surveycore::survey_nonprob()`.

# create_gen_rep_weights() rejects Deville-Tille without aux_var_names

    Code
      create_gen_rep_weights(td, variance_estimator = "Deville-Tille")
    Condition
      Error in `create_gen_rep_weights()`:
      x `variance_estimator = "Deville-Tille"` requires `aux_var_names`.
      v Pass column names, e.g. `aux_var_names = c(x1, x2)`.

# create_gen_rep_weights() rejects survey_nonprob

    Code
      create_gen_rep_weights(np)
    Condition
      Error in `create_gen_rep_weights()`:
      x `create_gen_rep_weights()` requires a probability-design structure.
      i <survey_nonprob> has no PSU or stratum structure required by this method.
      v Use `create_bootstrap_weights()` for non-probability designs.

