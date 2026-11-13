# weighting_history() snapshot of a two-step history

    Code
      withr::with_options(list(width = 200), print(weighting_history(rep)))
    Output
      # A tibble: 2 x 4
         step timestamp           operation          description                                                                                   
        <int> <dttm>              <chr>              <chr>                                                                                         
      1     1 2025-01-15 10:00:00 replicate_creation "replicate_creation (method = \"bootstrap\", type = \"Rao-Wu-Yue-Beaumont\", replicates = 20)"
      2     2 2026-01-15 10:00:00 calibration        "calibration"                                                                                 

# weighting_history() rejects a plain data.frame

    Code
      weighting_history(df)
    Condition
      Error in `weighting_history()`:
      x `x` must be a <survey_nonprob>, <survey_taylor>, or <survey_replicate>.
      i Got <data.frame>.
      v Use `surveycore::as_survey_nonprob()`, `surveycore::as_survey()`, or `surveycore::as_survey_replicate()` to construct a survey object.

