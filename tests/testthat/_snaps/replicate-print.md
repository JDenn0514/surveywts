# print(survey_replicate) bootstrap snapshot

    Code
      print(result)
    Output
      <survey_replicate: bootstrap>
      N = 100 observations
      50 replicate weights (rep_1 ... rep_50)
      Scale: 0.02
      Replicate scales: vector of length 50, range [1, 1]
      mse = TRUE
      
      Weights:
        min:    0.44
        median: 0.97
        mean:   1.03
        max:    2.95
        CV:     0.40
      
      Weighting history:
        #   Step 1 [2025-01-15]: replicate_creation (method = "bootstrap", type = "Rao-Wu-Yue-Beaumont", replicates = 50)

# print(survey_replicate) JKn stratified delete-1 snapshot

    Code
      print(result)
    Output
      <survey_replicate: JKn>
      N = 100 observations
      20 replicate weights (rep_1 ... rep_20)
      Scale: 1
      Replicate scales: vector of length 20, range [0.8, 0.8]
      mse = TRUE
      
      Weights:
        min:    0.44
        median: 0.97
        mean:   1.03
        max:    2.95
        CV:     0.40
      
      Weighting history:
        #   Step 1 [2025-01-15]: replicate_creation (method = "jackknife", type = "jkn")

# print(survey_replicate) BRR snapshot

    Code
      print(result)
    Output
      <survey_replicate: BRR>
      N = 60 observations
      4 replicate weights (rep_1 ... rep_4)
      Scale: 0.25
      Replicate scales: vector of length 4, range [1, 1]
      mse = TRUE
      
      Weights:
        min:    0.51
        median: 1.04
        mean:   1.11
        max:    2.95
        CV:     0.40
      
      Weighting history:
        #   Step 1 [2025-01-15]: replicate_creation (method = "brr")

# print(survey_replicate) two-entry history snapshot

    Code
      print(rep)
    Output
      <survey_replicate: bootstrap>
      N = 100 observations
      20 replicate weights (rep_1 ... rep_20)
      Scale: 0.05
      Replicate scales: vector of length 20, range [1, 1]
      mse = TRUE
      
      Weights:
        min:    0.44
        median: 0.97
        mean:   1.03
        max:    2.95
        CV:     0.40
      
      Weighting history:
        #   Step 1 [2025-01-15]: replicate_creation (method = "bootstrap", type = "Rao-Wu-Yue-Beaumont", replicates = 20)
        #   Step 2 [2026-01-15]: calibration

# print(survey_nonprob) shows 'none' when weighting history is empty

    Code
      print(nps)
    Output
      # A calibrated survey design: 50 observations, 6 variables
      # Variance: model-assisted (SRS assumption)
      # IDs: ~1 | Strata: NULL | Weights: base_weight 
      # Weighting history: none

# print(survey_nonprob) shows strata variable in design line

    Code
      print(nps)
    Output
      # A calibrated survey design: 100 observations, 6 variables
      # Variance: model-assisted (SRS assumption)
      # IDs: ~1 | Strata: ~region | Weights: base_weight 
      # Weighting history: none

# print(survey_nonprob) shows ids variable in design line

    Code
      print(nps)
    Output
      # A calibrated survey design: 100 observations, 6 variables
      # Variance: model-assisted (SRS assumption)
      # IDs: ~id | Strata: NULL | Weights: base_weight 
      # Weighting history: none

# print(survey_nonprob) formats calibrate_linear history step

    Code
      print(.pin_history_ts(cal))
    Output
      # A calibrated survey design: 100 observations, 6 variables
      # Variance: model-assisted (SRS assumption)
      # IDs: ~1 | Strata: NULL | Weights: base_weight 
      # Weighting history: 1 step 
      #   Step 1 [2025-01-15]: calibrate_linear (variables: age_group, sex) 

# print(survey_nonprob) formats calibrate_logit history step

    Code
      print(.pin_history_ts(cal))
    Output
      # A calibrated survey design: 100 observations, 6 variables
      # Variance: model-assisted (SRS assumption)
      # IDs: ~1 | Strata: NULL | Weights: base_weight 
      # Weighting history: 1 step 
      #   Step 1 [2025-01-15]: calibrate_logit (variables: age_group, sex) 

# print(survey_nonprob) formats poststratify history step

    Code
      print(.pin_history_ts(ps))
    Output
      # A calibrated survey design: 200 observations, 6 variables
      # Variance: model-assisted (SRS assumption)
      # IDs: ~1 | Strata: NULL | Weights: base_weight 
      # Weighting history: 1 step 
      #   Step 1 [2025-01-15]: poststratify (strata: age_group, sex) 

# print(survey_nonprob) formats nonresponse_weighting_class history step (with by)

    Code
      print(.pin_history_ts(adj))
    Output
      # A calibrated survey design: 165 observations, 7 variables
      # Variance: model-assisted (SRS assumption)
      # IDs: ~1 | Strata: NULL | Weights: base_weight 
      # Weighting history: 1 step 
      #   Step 1 [2025-01-15]: weighting-class nonresponse (by: sex) 

# print(survey_nonprob) formats nonresponse_weighting_class history step (no by)

    Code
      print(.pin_history_ts(adj))
    Output
      # A calibrated survey design: 159 observations, 7 variables
      # Variance: model-assisted (SRS assumption)
      # IDs: ~1 | Strata: NULL | Weights: base_weight 
      # Weighting history: 1 step 
      #   Step 1 [2025-01-15]: weighting-class nonresponse 

# print(survey_replicate) shows 'none' when weighting history is empty

    Code
      print(rep)
    Output
      <survey_replicate: bootstrap>
      N = 50 observations
      10 replicate weights (rep_1 ... rep_10)
      Scale: 0.1
      Replicate scales: vector of length 10, range [1, 1]
      mse = TRUE
      
      Weights:
        min:    0.30
        median: 1.11
        mean:   1.11
        max:    1.88
        CV:     0.33
      
      Weighting history:
        (none)

