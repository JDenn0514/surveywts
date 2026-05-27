# ipw() print snapshot matches survey_nonprob format with ipw step

    Code
      print(result)
    Output
      # A calibrated survey design: 200 observations, 7 variables
      # Variance: model-assisted (SRS assumption)
      # IDs: ~1 | Strata: NULL | Weights: ipw_weight 
      # Weighting history: 1 step 
      #   Step 1: ipw [~age_group + sex, logit, n_ref=1000, N_hat=885] 

# ipw() errors when data is not a data.frame

    Code
      ipw(list(x = 1), ref, selection = ~x)
    Condition
      Error in `ipw()`:
      x `data` must be a <data.frame>.
      i Got <list>.
      v Pass a plain <data.frame> as the non-probability sample.

# ipw() errors when data has 0 rows

    Code
      ipw(empty_df, ref, selection = ~ age_group + sex)
    Condition
      Error in `ipw()`:
      x `data` has 0 rows.
      i The non-probability sample must have at least one row.
      v Check that `data` contains the intended sample.

# ipw() errors when both selection and predictors are NULL

    Code
      ipw(nps, ref)
    Condition
      Error in `ipw()`:
      x One of `selection` or `predictors` must be supplied.
      i Both were NULL.
      v Provide a formula via `selection` (e.g., `selection = ~age + sex`) or a character vector via `predictors` (e.g., `predictors = c("age", "sex")`).

# ipw() errors when both selection and predictors are non-NULL

    Code
      ipw(nps, ref, selection = ~age_group, predictors = c("age_group"))
    Condition
      Error in `ipw()`:
      x Only one of `selection` and `predictors` may be supplied.
      i Both were non-NULL.
      v Use `selection` for a formula or `predictors` for a character vector.

# ipw() errors when reference is a data.frame

    Code
      ipw(nps, ref_df, selection = ~ age_group + sex)
    Condition
      Error in `ipw()`:
      x `reference` must be a <survey_taylor> object.
      i Got <data.frame>.
      v Pass a probability-based <survey_taylor> design as the reference. Use `surveycore::as_survey()` to construct one from a data frame.

# ipw() errors when reference is survey_nonprob

    Code
      ipw(nps, np_obj, selection = ~ age_group + sex)
    Condition
      Error in `ipw()`:
      x `reference` must be a <survey_taylor> object.
      i Got <surveycore::survey_nonprob>.
      v Pass a probability-based <survey_taylor> design as the reference. Use `surveycore::as_survey()` to construct one from a data frame.

# ipw() errors when reference has a zero design weight

    Code
      ipw(nps, ref_zero, selection = ~ age_group + sex)
    Condition
      Error in `ipw()`:
      x `reference` weight column base_weight contains 1 non-positive value(s).
      i All reference design weights must be strictly positive (> 0).
      v Remove or replace non-positive weights in the reference design.

# ipw() errors when reference has a negative design weight

    Code
      ipw(nps, ref_neg, selection = ~ age_group + sex)
    Condition
      Error in `ipw()`:
      x `reference` weight column base_weight contains 1 non-positive value(s).
      i All reference design weights must be strictly positive (> 0).
      v Remove or replace non-positive weights in the reference design.

# ipw() errors when selection is a character string (not formula)

    Code
      ipw(nps, ref, selection = "~ age_group + sex")
    Condition
      Error in `.validate_formula()`:
      x `formula` must be a one-sided formula (e.g., `~ age + sex`).
      i Got <character>.

# ipw() errors when selection variable missing from data

    Code
      ipw(nps, ref, selection = ~ age_group + nonexistent_var)
    Condition
      Error in `.validate_formula_variables()`:
      x Variable nonexistent_var not found in `data`.
      i All variables in `formula` must be columns in `data`.
      v Check spelling or add nonexistent_var to the data before calling this function.

# ipw() errors when selection variable missing from reference@data

    Code
      ipw(nps, ref_no_sex, selection = ~ age_group + sex)
    Condition
      Error in `.validate_formula_variables()`:
      x Variable sex not found in `reference`.
      i All variables in `formula` must be columns in `reference`.
      v Check spelling or add sex to the data before calling this function.

# ipw() errors when factor level in data absent from reference

    Code
      ipw(nps, ref, selection = ~age_group)
    Condition
      Error in `ipw()`:
      x Level "65-74" of variable age_group is present in `data` but not in `reference`.
      i Propensity estimation requires all NPS covariate levels to appear in the reference design.
      v Remove NPS rows with age_group = "65-74", or add reference units with that level.

# ipw() errors when missing_method='separate' and a numeric selection variable has NA

    Code
      ipw(nps, ref, selection = ~ age_group + base_weight, missing_method = "separate")
    Condition
      Warning:
      ! NPS (200 units) is 18.4% of the estimated population (N_hat = 1085).
      i Reference weights adjusted by factor 0.8157 per Valliant (2020) eq. (1): w* = w * (N_hat - n_NPS) / N_hat.
      v Set `adjust_reference = FALSE` to skip this adjustment if the NPS is known to be disjoint from the reference frame.
      Error in `ipw()`:
      x `missing_method = "separate"` cannot handle numeric selection variables with NA values.
      i Variable base_weight is <numeric> and has 1 NA value(s).
      v Convert base_weight to a factor (e.g., with `cut()`) or use `missing_method = "impute"` instead.

# ipw() errors when missing_method='impute' and mice is not installed [mocked]

    Code
      ipw(nps, ref, selection = ~ age_group + sex, missing_method = "impute")
    Condition
      Warning:
      ! NPS (200 units) is 18.4% of the estimated population (N_hat = 1085).
      i Reference weights adjusted by factor 0.8157 per Valliant (2020) eq. (1): w* = w * (N_hat - n_NPS) / N_hat.
      v Set `adjust_reference = FALSE` to skip this adjustment if the NPS is known to be disjoint from the reference frame.
      Error in `ipw()`:
      x Package mice is required for `missing_method = "impute"`.
      i mice is not installed.
      v Install it with `install.packages("mice")` then re-run `ipw()`.

# ipw() errors when wt_name is NULL

    Code
      ipw(nps, ref, selection = ~ age_group + sex, wt_name = NULL)
    Condition
      Warning:
      ! NPS (200 units) is 18.4% of the estimated population (N_hat = 1085).
      i Reference weights adjusted by factor 0.8157 per Valliant (2020) eq. (1): w* = w * (N_hat - n_NPS) / N_hat.
      v Set `adjust_reference = FALSE` to skip this adjustment if the NPS is known to be disjoint from the reference frame.
      Error in `.validate_wt_name()`:
      x `wt_name` must be a single character string.
      i Got <NULL> of length 0.

# ipw() errors when wt_name is integer

    Code
      ipw(nps, ref, selection = ~ age_group + sex, wt_name = 1L)
    Condition
      Warning:
      ! NPS (200 units) is 18.4% of the estimated population (N_hat = 1085).
      i Reference weights adjusted by factor 0.8157 per Valliant (2020) eq. (1): w* = w * (N_hat - n_NPS) / N_hat.
      v Set `adjust_reference = FALSE` to skip this adjustment if the NPS is known to be disjoint from the reference frame.
      Error in `.validate_wt_name()`:
      x `wt_name` must be a single character string.
      i Got <integer> of length 1.

# ipw() errors when wt_name is empty string

    Code
      ipw(nps, ref, selection = ~ age_group + sex, wt_name = "")
    Condition
      Warning:
      ! NPS (200 units) is 18.4% of the estimated population (N_hat = 1085).
      i Reference weights adjusted by factor 0.8157 per Valliant (2020) eq. (1): w* = w * (N_hat - n_NPS) / N_hat.
      v Set `adjust_reference = FALSE` to skip this adjustment if the NPS is known to be disjoint from the reference frame.
      Error in `.validate_wt_name()`:
      x `wt_name` must be a non-empty, non-NA string.

# ipw() errors when wt_name is NA_character_

    Code
      ipw(nps, ref, selection = ~ age_group + sex, wt_name = NA_character_)
    Condition
      Warning:
      ! NPS (200 units) is 18.4% of the estimated population (N_hat = 1085).
      i Reference weights adjusted by factor 0.8157 per Valliant (2020) eq. (1): w* = w * (N_hat - n_NPS) / N_hat.
      v Set `adjust_reference = FALSE` to skip this adjustment if the NPS is known to be disjoint from the reference frame.
      Error in `.validate_wt_name()`:
      x `wt_name` must be a non-empty, non-NA string.

# ipw() errors when wt_name conflicts with existing data column

    Code
      ipw(nps, ref, selection = ~ age_group + sex, wt_name = "age_group")
    Condition
      Warning:
      ! NPS (200 units) is 18.4% of the estimated population (N_hat = 1085).
      i Reference weights adjusted by factor 0.8157 per Valliant (2020) eq. (1): w* = w * (N_hat - n_NPS) / N_hat.
      v Set `adjust_reference = FALSE` to skip this adjustment if the NPS is known to be disjoint from the reference frame.
      Error in `ipw()`:
      x `wt_name` "age_group" already exists as a column in `data`.
      i The output weight column must be distinct from all input columns.
      v Choose a different `wt_name`.

# ipw() errors when propensity scores are degenerate (score >= 1)

    Code
      suppressWarnings(ipw(nps_degen, ref_degen, selection = ~cat_var, maxit = 500L))
    Condition
      Error in `ipw()`:
      x 200 propensity score(s) saturate at the floating-point boundary of (0, 1).
      i Scores at or beyond the float boundary indicate that the Newton-Raphson has diverged due to extreme NPS/reference imbalance: the NPS is so overrepresented in some covariate cells that no valid participation propensity exists.
      v Review covariate distributions in `data` and `reference`. Consider trimming extreme NPS units or using a simpler `selection`.

# ipw() errors when Hessian is singular (collinear covariates)

    Code
      ipw(nps_coll, ref_coll, selection = ~ x1 + x2, adjust_reference = FALSE)
    Condition
      Error in `value[[3L]]()`:
      x Propensity Hessian is singular: Lapack routine dgesv: system is exactly singular: U[3,3] = 0
      i Collinear or degenerate covariates in `selection`.
      v Simplify `selection` or check for constant covariate columns.

# ipw() errors when maxit = 0L

    Code
      ipw(nps, ref, selection = ~ age_group + sex, maxit = 0L)
    Condition
      Warning:
      ! NPS (200 units) is 18.4% of the estimated population (N_hat = 1085).
      i Reference weights adjusted by factor 0.8157 per Valliant (2020) eq. (1): w* = w * (N_hat - n_NPS) / N_hat.
      v Set `adjust_reference = FALSE` to skip this adjustment if the NPS is known to be disjoint from the reference frame.
      Error in `ipw()`:
      x `maxit` must be a whole number >= 1.
      i Got 0.
      v Set `maxit` to a positive integer (e.g., `maxit = 25L`).

# ipw() errors when epsilon = 0

    Code
      ipw(nps, ref, selection = ~ age_group + sex, epsilon = 0)
    Condition
      Warning:
      ! NPS (200 units) is 18.4% of the estimated population (N_hat = 1085).
      i Reference weights adjusted by factor 0.8157 per Valliant (2020) eq. (1): w* = w * (N_hat - n_NPS) / N_hat.
      v Set `adjust_reference = FALSE` to skip this adjustment if the NPS is known to be disjoint from the reference frame.
      Error in `ipw()`:
      x `epsilon` must be a positive number.
      i Got 0.
      v Set `epsilon` to a small positive value (e.g., `epsilon = 1e-8`).

# ipw() errors when epsilon = -1

    Code
      ipw(nps, ref, selection = ~ age_group + sex, epsilon = -1)
    Condition
      Warning:
      ! NPS (200 units) is 18.4% of the estimated population (N_hat = 1085).
      i Reference weights adjusted by factor 0.8157 per Valliant (2020) eq. (1): w* = w * (N_hat - n_NPS) / N_hat.
      v Set `adjust_reference = FALSE` to skip this adjustment if the NPS is known to be disjoint from the reference frame.
      Error in `ipw()`:
      x `epsilon` must be a positive number.
      i Got -1.
      v Set `epsilon` to a small positive value (e.g., `epsilon = 1e-8`).

# population_size = 0 or negative → error

    Code
      ipw(nps, ref, selection = ~ age_group + sex, population_size = 0)
    Condition
      Error in `ipw()`:
      x `population_size` must be a positive finite number.
      i Got 0.
      v Supply a known census population count or leave `population_size = NULL` to use the self-normalizing estimate.

# population_size = non-numeric → error

    Code
      ipw(nps, ref, selection = ~ age_group + sex, population_size = "50000")
    Condition
      Error in `ipw()`:
      x `population_size` must be a positive finite number.
      i Got "50000".
      v Supply a known census population count or leave `population_size = NULL` to use the self-normalizing estimate.

# adjust_reference = TRUE warns and adjusts when nps_fraction > 0.05

    Code
      expect_warning(ipw(nps, ref, selection = ~ age_group + sex, adjust_reference = TRUE),
      class = "surveywts_warning_ipw_reference_weight_adjusted")

# adjust_reference = FALSE warns but does not adjust when nps_fraction > 0.05

    Code
      expect_warning(ipw(nps, ref, selection = ~ age_group + sex, adjust_reference = FALSE),
      class = "surveywts_warning_ipw_reference_unadjusted_large_nps")

# adjust_reference validation — non-logical rejected (dual pattern)

    Code
      ipw(nps, ref, selection = ~ age_group + sex, adjust_reference = "yes")
    Condition
      Error in `ipw()`:
      x `adjust_reference` must be TRUE or FALSE.
      i Got <character> of length 1.
      v Set `adjust_reference = TRUE` (default) or `adjust_reference = FALSE`.

