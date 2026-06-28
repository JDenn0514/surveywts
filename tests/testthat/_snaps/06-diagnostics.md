# effective_sample_size() throws not_survey_base for plain data.frame input

    Code
      effective_sample_size(df)
    Condition
      Error in `.diag_validate_input()`:
      x `x` must be a <survey_nonprob>, <survey_taylor>, or <survey_replicate>.
      i Got <data.frame>.
      v Use `surveycore::as_survey_nonprob()`, `surveycore::as_survey()`, or `surveycore::as_survey_replicate()` to construct a survey object.

# weight_variability() throws not_survey_base for plain data.frame input

    Code
      weight_variability(df)
    Condition
      Error in `.diag_validate_input()`:
      x `x` must be a <survey_nonprob>, <survey_taylor>, or <survey_replicate>.
      i Got <data.frame>.
      v Use `surveycore::as_survey_nonprob()`, `surveycore::as_survey()`, or `surveycore::as_survey_replicate()` to construct a survey object.

# summarize_weights() throws not_survey_base for plain data.frame input

    Code
      summarize_weights(df)
    Condition
      Error in `.diag_validate_input()`:
      x `x` must be a <survey_nonprob>, <survey_taylor>, or <survey_replicate>.
      i Got <data.frame>.
      v Use `surveycore::as_survey_nonprob()`, `surveycore::as_survey()`, or `surveycore::as_survey_replicate()` to construct a survey object.

# effective_sample_size() throws not_survey_base for matrix input

    Code
      effective_sample_size(m)
    Condition
      Error in `.diag_validate_input()`:
      x `x` must be a <survey_nonprob>, <survey_taylor>, or <survey_replicate>.
      i Got <matrix>.
      v Use `surveycore::as_survey_nonprob()`, `surveycore::as_survey()`, or `surveycore::as_survey_replicate()` to construct a survey object.

# weight_variability() throws not_survey_base for list input

    Code
      weight_variability(x)
    Condition
      Error in `.diag_validate_input()`:
      x `x` must be a <survey_nonprob>, <survey_taylor>, or <survey_replicate>.
      i Got <list>.
      v Use `surveycore::as_survey_nonprob()`, `surveycore::as_survey()`, or `surveycore::as_survey_replicate()` to construct a survey object.

