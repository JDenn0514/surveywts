# calibrate() aborts with cli error for data.frame input

    Code
      calibrate(make_surveywts_data(), targets = targets_a)
    Condition
      Error in `.check_input_class()`:
      x `data` must be a <survey_nonprob>, <survey_taylor>, or <survey_replicate>.
      i Got <data.frame>.
      v Use `surveycore::as_survey_nonprob()`, `surveycore::as_survey()`, or `surveycore::as_survey_replicate()` to construct a survey object.

