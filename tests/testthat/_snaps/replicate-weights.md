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

