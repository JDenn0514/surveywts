# dplyr_reconstruct.weighted_df() drops class and warns when weight col is removed

    Code
      dplyr::select(.make_test_wdf(), x)
    Condition
      Warning:
      ! Weight column w was removed from the <weighted_df>.
      i The result has been downgraded to a plain tibble.
      i Load surveytidy for rename-aware handling.
    Output
      # A tibble: 5 x 1
            x
        <int>
      1     1
      2     2
      3     3
      4     4
      5     5

# dplyr_reconstruct.weighted_df() drops class and warns when weight col is renamed

    Code
      dplyr::rename(.make_test_wdf(), weight_renamed = w)
    Condition
      Warning:
      ! Weight column w was removed from the <weighted_df>.
      i The result has been downgraded to a plain tibble.
      i Load surveytidy for rename-aware handling.
    Output
      # A tibble: 5 x 2
            x weight_renamed
        <int>          <dbl>
      1     1            1  
      2     2            1.2
      3     3            0.8
      4     4            1.1
      5     5            0.9

# dplyr_reconstruct.weighted_df() drops class and warns when mutate(.keep='unused') removes weight col

    Code
      dplyr::mutate(.make_test_wdf(), y = w * 2, .keep = "unused")
    Condition
      Warning:
      ! Weight column w was removed from the <weighted_df>.
      i The result has been downgraded to a plain tibble.
      i Load surveytidy for rename-aware handling.
    Output
      # A tibble: 5 x 2
            x     y
        <int> <dbl>
      1     1   2  
      2     2   2.4
      3     3   1.6
      4     4   2.2
      5     5   1.8

# print.weighted_df() output matches snapshot with 2-step history

    Code
      print(wdf)
    Output
      # A weighted data frame: 5 × 5 
      # Weight: wt_final (n = 5, mean = 1.00, CV = 0.22, ESS = 5) 
      # Weighting history: 2 steps 
      #   Step 1 [2025-01-15]: weighting-class nonresponse (by: age, sex) 
      #   Step 2 [2025-01-15]: raking (margins: age, sex, education) 
      # ── Data ────────────────────────────────────────────────────────────────────────
      # A tibble: 5 x 5
           id age   sex   education wt_final
      * <int> <chr> <chr> <chr>        <dbl>
      1     1 18-34 M     <HS           0.72
      2     2 35-54 F     HS            1.14
      3     3 55+   M     College       0.95
      4     4 18-34 F     Graduate      1.28
      5     5 35-54 M     College       0.91

# print.weighted_df() shows 'Weighting history: none' when history is empty

    Code
      print(wdf)
    Output
      # A weighted data frame: 5 × 2 
      # Weight: w (n = 5, mean = 1.00, CV = 0.16, ESS = 5) 
      # Weighting history: none
      # ── Data ────────────────────────────────────────────────────────────────────────
      # A tibble: 5 x 2
            x     w
      * <int> <dbl>
      1     1   1  
      2     2   1.2
      3     3   0.8
      4     4   1.1
      5     5   0.9

# print method for survey_calibrated produces expected output

    Code
      print(sc)
    Output
      # A calibrated survey design: 5 observations, 4 variables
      # Variance method: Taylor linearization
      # IDs: ~psu | Strata: ~stratum | Weights: w 
      # Weighting history: 2 steps 
      #   Step 1 [2025-01-15]: weighting-class nonresponse (by: age, sex) 
      #   Step 2 [2025-01-15]: raking (margins: age, sex, education) 

# print method for survey_calibrated handles NULL ids, NULL strata, empty history

    Code
      print(sc)
    Output
      # A calibrated survey design: 5 observations, 2 variables
      # Variance method: Taylor linearization
      # IDs: ~1 | Strata: NULL | Weights: w 
      # Weighting history: none

# print.weighted_df() formats calibration, poststratify, and null-by nonresponse entries

    Code
      print(wdf)
    Output
      # A weighted data frame: 5 × 2 
      # Weight: w (n = 5, mean = 1.00, CV = 0.16, ESS = 5) 
      # Weighting history: 3 steps 
      #   Step 1 [2025-01-15]: calibration (variables: age_group) 
      #   Step 2 [2025-01-15]: poststratify (strata: age_group) 
      #   Step 3 [2025-01-15]: weighting-class nonresponse 
      # ── Data ────────────────────────────────────────────────────────────────────────
      # A tibble: 5 x 2
            x     w
      * <int> <dbl>
      1     1   1  
      2     2   1.2
      3     3   0.8
      4     4   1.1
      5     5   0.9

