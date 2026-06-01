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
        #   Step 1: replicate_creation (method = "bootstrap", type = "Rao-Wu-Yue-Beaumont", replicates = 50)

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
        #   Step 1: replicate_creation (method = "jackknife", type = "JKn")

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
        #   Step 1: replicate_creation (method = "brr")

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
        #   Step 1: replicate_creation (method = "bootstrap", type = "Rao-Wu-Yue-Beaumont", replicates = 20)
        #   Step 2: calibration (variables: age_group, sex)

