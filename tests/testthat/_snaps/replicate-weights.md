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

