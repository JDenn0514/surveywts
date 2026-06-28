# Class System Refactor Plan

**Status:** In progress — function review partially complete
**Goal:** Remove `weighted_df` and plain `data.frame` acceptance from all
surveywts functions. Functions will accept only `survey_base` objects
(`survey_nonprob`, `survey_taylor`, `survey_replicate`) from surveycore.

---

## Key Decisions

### Drop `weighted_df` entirely
- Remove `R/weighted-df-dplyr.R`
- Remove `.make_weighted_df()` from `R/utils.R`
- Remove all `inherits(data, "weighted_df")` dispatch paths
- Remove all `attr(, "weighting_history")` manipulation
- Remove `dplyr_reconstruct.weighted_df()` and its tests

### Only accept `survey_base` objects
All functions accept `survey_nonprob`, `survey_taylor`, and `survey_replicate`
(where applicable). Passing a `data.frame` → `cli_abort()` with an `"i"`
bullet pointing to the relevant surveycore constructor.

This aligns with how `surveytidy` handles inputs — consistent ecosystem contract.

### Keep `weights` argument
Auto-detect from `@variables$weights` when `NULL`. Allow explicit override
when the user wants to calibrate from a different column than the registered
weight. Behavior unchanged from today for survey inputs.

### Repurpose `wt_name`
- `wt_name = NULL` (new default): write calibrated weights back to the same
  column as the input weight (`@variables$weights` unchanged).
- `wt_name = "new_name"`: write calibrated weights to a new `"new_name"`
  column in `@data`, update `@variables$weights = "new_name"`. Original
  column is preserved.

### `ipw()` gets a separate spec
`ipw()` is the most significant API change (currently accepts a plain
`data.frame` as its primary input). It will require a proper spec-workflow
run before implementation. Do not implement `ipw()` changes as part of this
refactor — treat it as a separate feature.

### Documentation strategy
- All examples use surveycore constructors (`as_survey_nonprob()`,
  `as_survey()`, `as_survey_replicate()`)
- Add `summarize_weights()` call after the first two examples in each
  function with comment "inspect weight distribution after [operation]"
- `@seealso` and `@param data` updated to reference surveycore constructors

---

## Implementation Tasks (after function review is complete)

1. **Remove `weighted_df`**
   - Delete `R/weighted-df-dplyr.R`
   - Remove `.make_weighted_df()` from `R/utils.R`
   - Remove `weighted_df` from `NAMESPACE` (via `devtools::document()`)
   - Delete `tests/testthat/test-00-classes.R` weighted_df sections

2. **Update each function** (see per-function notes below)
   - Remove `data.frame` and `weighted_df` dispatch branches
   - Add `cli_abort()` for non-`survey_base` input with actionable `"i"` bullet
   - Update `@param data` to list only accepted survey classes
   - Update `@returns` to remove `weighted_df` return mention
   - Remove `wt_name = "wts"` default → change to `wt_name = NULL`
   - Update examples (see agreed examples per function below)

3. **Run `devtools::document()`** after all source changes

4. **Update tests** — remove all `weighted_df` path tests; add
   `cli_abort()` tests for `data.frame` input

5. **Run `devtools::check()`** before opening PR

6. **Open PR against `develop`** — branch `refactor/drop-weighted-df`

---

## Functions Reviewed — Agreed Examples

### `calibrate()` ✅
```r
# Format A targets (list) --------------------------------------
targets_a <- list(
  sex    = c("Male" = 0.49, "Female" = 0.51),
  age_f3 = c("18-34" = 0.30, "35-54" = 0.33, "55+" = 0.37)
)

# --- survey_nonprob ---
# survey_core::as_surve_nonprob() requires weights so set them to 1 
ns_wave1$weight <- 1

ns_svy <- surveycore::as_survey_nonprob(
  ns_wave1, 
  weights = weight
)
ns_svy_rake <- calibrate(ns_svy, targets = targets_a)
# inspect weight distribution after raking
summarize_weights(ns_svy_rake)  

# --- survey_taylor ---
npors_svy_rake <- surveycore::as_survey(
  npors_2025_clean, 
  weights = weight, 
  strata = stratum
)
# create object with raking
npors_svy_rake <- calibrate(npors_svy, targets = targets_a)
# inspect weight distribution after raking
summarize_weights(npors_svy_rake)  

# create object with linear calibration
npors_svy_linear <- calibrate(
  npors_svy, 
  targets = targets_a, 
  method = "linear"
)
# inspect weight distribution
summarize_weights(npors_svy_linear, weights = "linear_wt")

# Format B targets (long data frame) ---------------------------
targets_b <- data.frame(
  variable = c("sex", "sex", "age_f3", "age_f3", "age_f3"),
  level    = c("Male", "Female", "18-34", "35-54", "55+"),
  target   = c(0.49, 0.51, 0.30, 0.33, 0.37)
)
calibrate(ns_svy, targets = targets_b)
```

### `calibrate_rake()` ✅
```r

# Format A targets (list) --------------------------------------
targets_a <- list(
  sex    = c("Male" = 0.49, "Female" = 0.51),
  age_f3 = c("18-34" = 0.30, "35-54" = 0.33, "55+" = 0.37)
)

# --- survey_nonprob ---
# survey_core::as_surve_nonprob() requires weights so set them to 1 
ns_wave1$weight <- 1

ns_svy <- surveycore::as_survey_nonprob(
  ns_wave1, 
  weights = weight
)
# rake weight with defaults using classic ipf
ns_svy_ipf <- calibrate_rake(ns_svy, targets = targets_a)
# inspect weight distribution
summarize_weights(ns_svy_ipf)  

# rake weights using newton-raphson
ns_svy_nr <- calibrate_rake(
  ns_svy, 
  targets = targets_a, 
  algorithm = "nr"
)
# inspect weight distribution
summarize_weights(ns_svy_nr)  

# --- survey_taylor ---
npors_svy <- surveycore::as_survey(
  npors_2025_clean, 
  weights = weight, 
  strata = stratum
)
npors_svy_rake <- calibrate_rake(npors_svy, targets = targets_a)
# inspect weight distribution after raking
summarize_weights(npors_svy_rake)  

# Format B targets (long data frame) --------------------------
targets_b <- data.frame(
  variable = c("sex", "sex", "age_f3", "age_f3", "age_f3"),
  level    = c("Male", "Female", "18-34", "35-54", "55+"),
  target   = c(0.49, 0.51, 0.30, 0.33, 0.37)
)
calibrate_rake(ns_svy, targets = targets_b)
```

### `calibrate_linear()` ✅
```r

# Format A targets (list) --------------------------------------
targets_a <- list(
  sex    = c("Male" = 0.49, "Female" = 0.51),
  age_f3 = c("18-34" = 0.30, "35-54" = 0.33, "55+" = 0.37)
)

# --- survey_nonprob ---
# survey_core::as_surve_nonprob() requires weights so set them to 1 
ns_wave1$weight <- 1

ns_svy <- surveycore::as_survey_nonprob(
  ns_wave1, 
  weights = weight
)

ns_svy_linear <- calibrate_linear(ns_svy, targets = targets_a)
# inspect weight distribution after calibration
summarize_weights(ns_svy_linear)  

# --- survey_taylor ---
npors_svy <- surveycore::as_survey(
  npors_2025_clean, 
  weights = weight, 
  strata = stratum
)

# include bounds
npors_svy_linear <- calibrate_linear(
  npors_svy, 
  targets = targets_a, 
  bounds = c(0.3, 3)
)

# Format B targets (long data frame) --------------------------
targets_b <- data.frame(
  variable = c("sex", "sex", "age_f3", "age_f3", "age_f3"),
  level    = c("Male", "Female", "18-34", "35-54", "55+"),
  target   = c(0.49, 0.51, 0.30, 0.33, 0.37)
)
ns_svy_linear <- calibrate_linear(ns_svy, targets = targets_b)
```

### `calibrate_logit()` ✅
```r

# Format A targets (list) --------------------------------------
targets_a <- list(
  sex    = c("Male" = 0.49, "Female" = 0.51),
  age_f3 = c("18-34" = 0.30, "35-54" = 0.33, "55+" = 0.37)
)

# --- survey_nonprob ---
# survey_core::as_surve_nonprob() requires weights so set them to 1 
ns_wave1$weight <- 1

ns_svy <- surveycore::as_survey_nonprob(
  ns_wave1, 
  weights = weight
)
# logit calibration with default bounds
ns_wave_default <- calibrate_logit(ns_svy, targets = targets_a)
# inspect weight distribution after calibration
summarize_weights(ns_wave_default)  

# survey_taylor ------------------------------------------------
npors_svy <- surveycore::as_survey(
  npors_2025_clean, 
  weights = weight, 
  strata = stratum
)
# use multiplicate bounds on weight ratios
npors_svy_bounds <- calibrate_logit(
  npors_svy, 
  targets = targets_a, 
  bounds = c(0.3, 3)
)

# Format B targets (long data frame) --------------------------
targets_b <- data.frame(
  variable = c("sex", "sex", "age_f3", "age_f3", "age_f3"),
  level    = c("Male", "Female", "18-34", "35-54", "55+"),
  target   = c(0.49, 0.51, 0.30, 0.33, 0.37)
)
calibrate_logit(ns_svy, targets = targets_b)
```

### `poststratify()` ✅
```r
# joint cell proportions (sex x age_f3, 6 cells) ---------------
ps_cells <- data.frame(
  sex    = rep(c("Male", "Female"), each = 3),
  age_f3 = rep(c("18-34", "35-54", "55+"), times = 2),
  target = c(0.1470, 0.1617, 0.1813, 0.1530, 0.1683, 0.1887)
)

# survey_nonprob -----------------------------------------------
# survey_core::as_surve_nonprob() requires weights so set them to 1 
ns_wave1$weight <- 1

ns_svy <- surveycore::as_survey_nonprob(
  ns_wave1, 
  weights = weight
)
cal <- poststratify(ns_svy, targets = ps_cells)
summarize_weights(cal)  # inspect weight distribution after post-stratification

# survey_taylor ------------------------------------------------
npors_svy <- surveycore::as_survey(
  npors_2025_clean, weights = weight, strata = stratum
)
cal_prob <- poststratify(npors_svy, targets = ps_cells)
summarize_weights(cal_prob)  # inspect weight distribution after post-stratification

# type = "count": population counts instead of proportions -----
ps_counts <- data.frame(
  sex    = rep(c("Male", "Female"), each = 3),
  age_f3 = rep(c("18-34", "35-54", "55+"), times = 2),
  target = c(0.1470, 0.1617, 0.1813, 0.1530, 0.1683, 0.1887) * 260000000
)
poststratify(ns_svy, targets = ps_counts, type = "count")
```

### `calibrate_to_survey()` ✅ (already survey-only — add `summarize_weights()` only)
```r
# calibrate ns_wave1 NPS to NPORS probability survey on age_f3 and sex ----
# use existing calibrated weights for ns_wave1
primary <- surveycore::as_survey_nonprob(ns_wave1, weights = weight) |>
  # need it to have replicate weights
  create_bootstrap_weights(replicates = 50)

# create survey object
control <- surveycore::as_survey(
  npors_2025_clean, 
  weights = weight, 
  strata = stratum
) |>
  # add replicate weights
  create_bootstrap_weights(npors_design, replicates = 50L)

result <- calibrate_to_survey(
  primary, 
  control, 
  variables = c(age_f3, sex)
)
# inspect weight distribution after calibration
summarize_weights(result)  
```

### `calibrate_to_estimate()` ✅ (already survey-only — add `summarize_weights()` only)
```r
# calibrate GSS 2024 pid_f3 to NPORS population estimates ---------------

# build primary replicate design from GSS (JKn on complete pid_f3 rows)

gss_pop <- surveycore::as_survey(
  gss_2024[!is.na(gss_2024$pid_f3), ],
  weights = wt_pop, 
  strata = vstrat, 
  ids = vpsu, 
  nest = TRUE
) |>
  create_jackknife_weights(type = "jkn")

# build NPORS control design (must use survey pkg for svytotal/coef/vcov)
npors_pop <- survey::svydesign(
  ids = ~1, 
  strata = ~stratum, 
  weights = ~wt_pop, 
  data = npors_2025_clean
) |>
  survey::as.svrepdesign(type = "JKn")

# derive targets from control survey
pid_f3_est    <- survey::svytotal(~pid_f3, npors_pop)
pid_f3_totals <- setNames(coef(pid_f3_est), levels(npors_2025_clean$pid_f3))
vcov_pid_f3   <- vcov(pid_f3_est)

result <- calibrate_to_estimate(
  gss_pop,
  targets       = list(pid_f3 = pid_f3_totals),
  vcov_estimate = vcov_pid_f3
)
# inspect weight distribution after calibration
summarize_weights(result)  
```

### `adjust_nonresponse()` ✅
```r
# survey_taylor --------------------------------------------------------
library(surveytidy)

set.seed(42)
# create the survey object 
gss_svy <- surveycore::as_survey(
  gss_2024,
  weights = wtssnrps,
  strata = vstrat,
  ids = vpsu,
  nest = TRUE
) |> 
  # remove NAs
  subset(!is.na(sex) & !is.na(age_f3)) |>
  # add a column indicating if they responded or not
  mutate(
    responded = sample(
      c(0L, 1L), 
      size = 3197, 
      replace = TRUE, 
      prob = c(0.2, 0.8) 
    )
  )

# redistribute nonrespondent weights to respondents within sex groups
result <- adjust_nonresponse(gss_svy, response_status = responded, by = sex)
# inspect respondent weight distribution after adjustment
summarize_weights(result)  

# survey_nonprob -------------------------------------------------------

# set seed for reproducibility
set.seed(42)

ns_svy <- surveycore::as_survey_nonprob(ns_wave1, weights = weight) |> 
  # add column indicating if they responded
  mutate(
    responded = sample(
      c(0L, 1L), 
      nrow(ns_wave1), 
      replace = TRUE, 
      prob = c(0.2, 0.8)
    )
  )

# redistribute nonrespondent weights to respondents within sex groups
result_np <- adjust_nonresponse(ns_svy, response_status = responded, by = sex)
# inspect respondent weight distribution after adjustment
summarize_weights(result_np)  

# propensity-cell method: fit propensity model, bin into cells ---------
gss_cell <- adjust_nonresponse(
  gss_svy,
  response_status = responded,
  method          = "propensity-cell",
  formula         = ~sex + age_f3
) 
# inspect respondent weight distribution after adjustment
summarize_weights(gss_cell)

# propensity method: apply individual-level IPW to each respondent -----
gss_prop <- adjust_nonresponse(
  gss_svy,
  response_status = responded,
  method          = "propensity",
  formula         = ~sex + age_f3
) 
# inspect respondent weight distribution after adjustment
summarize_weights(gss_prop)


```

### `redistribute_weights()` ✅
```r
# survey_taylor --------------------------------------------------------

# create indicators for which rows lose weight and which receive it
set.seed(42)
gss_svy <- surveycore::as_survey(
  gss_2024,
  weights = wtssnrps,
  strata = vstrat,
  ids = vpsu,
  nest = TRUE
) |> 
  # remove NAs
  subset(!is.na(sex)) |>
  # add a column indicating if they responded or not
  mutate(
    excluded = sample(
      c(0L, 1L), 
      size = 3290, 
      replace = TRUE, 
      prob = c(0.8, 0.2) 
    ),
    retained = as.integer(!excluded)
  )

# transfer weight from excluded rows to retained rows within sex groups
result <- redistribute_weights(
  gss_svy, 
  reduce_if = excluded, 
  increase_if = retained, 
  by = sex
)
# inspect weight distribution after redistribution
summarize_weights(result)  

# survey_nonprob -------------------------------------------------------

# create indicators for which rows lose weight and which receive it
set.seed(42)
ns_svy <- ns_wave1 |> 
  surveycore::as_survey_nonprob(weights = weight) |> 
  mutate(
    excluded = sample(
      c(0L, 1L), 
      nrow(ns_wave1), 
      replace = TRUE, 
      prob = c(0.8, 0.2)
    ),
    retained = as.integer(!excluded)
  )

# transfer weight from excluded rows to retained rows within sex groups
ns_svy_red <- redistribute_weights(
  ns_svy, 
  reduce_if = excluded, 
  increase_if = retained, 
  by = sex
)
summarize_weights(ns_svy_red)
```

---

### `trim_weights()` ✅
```r
# survey_nonprob — all three bound methods -----------------------------
ns_svy <- surveycore::as_survey_nonprob(ns_wave1, weights = weight)

# IQR default (k = 5)
ns_trimmed_iqr <- trim_weights(ns_svy)
# inspect weight distribution after trimming
summarize_weights(ns_trimmed_iqr)

# percentile bounds
ns_trimmed_pct <- trim_weights(
  ns_svy,
  lower = 0.05,
  upper = 0.95,
  type  = "percentile"
)
# inspect weight distribution after trimming
summarize_weights(ns_trimmed_pct)

# absolute bounds
ns_trimmed_abs <- trim_weights(ns_svy, lower = 0.3, upper = 3.0)
# inspect weight distribution after trimming
summarize_weights(ns_trimmed_abs)

# survey_taylor --------------------------------------------------------
npors_svy <- surveycore::as_survey(
  npors_2025_clean,
  weights = weight,
  strata  = stratum
)
npors_trimmed <- trim_weights(npors_svy)
# inspect weight distribution after trimming
summarize_weights(npors_trimmed)

# survey_replicate — bounds auto-applied to all replicate columns ------
cps_svy <- surveycore::as_survey_replicate(
  cps_2023,
  weights    = "wtfinl",
  repweights = paste0("repwtp", 1:160),
  type       = "successive-difference",
  scale      = 4 / 160,
  rscales    = rep(1, 160)
)
trim_weights(cps_svy)
```

---

### `rescale_weights()` ✅
```r
# survey_nonprob — global rescaling ------------------------------------
ns_svy <- surveycore::as_survey_nonprob(ns_wave1, weights = weight)
ns_rescaled <- rescale_weights(ns_svy)
# inspect weight distribution after rescaling
summarize_weights(ns_rescaled)

# rescale within groups using by = -------------------------------------
ns_rescaled_by <- rescale_weights(ns_svy, by = sex)
# inspect weight distribution after rescaling
summarize_weights(ns_rescaled_by, by = sex)

# survey_taylor --------------------------------------------------------
npors_svy <- surveycore::as_survey(
  npors_2025_clean,
  weights = weight,
  strata  = stratum
)
npors_rescaled <- rescale_weights(npors_svy)
# inspect weight distribution after rescaling
summarize_weights(npors_rescaled)
```

---

## Functions Still to Review

Continue the one-by-one review in a new session. Pick up here:

### `effective_sample_size()` ✅
```r
# survey_nonprob -------------------------------------------------------
ns_svy <- surveycore::as_survey_nonprob(ns_wave1, weights = weight)
effective_sample_size(ns_svy)

# survey_taylor --------------------------------------------------------
npors_svy <- surveycore::as_survey(
  npors_2025_clean,
  weights = weight,
  strata  = stratum
)
effective_sample_size(npors_svy)
```

### `weight_variability()` ✅
```r
# survey_nonprob -------------------------------------------------------
ns_svy <- surveycore::as_survey_nonprob(ns_wave1, weights = weight)
weight_variability(ns_svy)

# survey_taylor --------------------------------------------------------
npors_svy <- surveycore::as_survey(
  npors_2025_clean,
  weights = weight,
  strata  = stratum
)
weight_variability(npors_svy)
```

### `summarize_weights()` ✅
```r
# survey_nonprob -------------------------------------------------------
ns_svy <- surveycore::as_survey_nonprob(ns_wave1, weights = weight)
summarize_weights(ns_svy)

# grouped by sex
summarize_weights(ns_svy, by = sex)

# survey_taylor --------------------------------------------------------
npors_svy <- surveycore::as_survey(
  npors_2025_clean,
  weights = weight,
  strata  = stratum
)
summarize_weights(npors_svy)
```

### Replicate weights family ✅ (no changes needed)
All functions in this family call `.validate_replicate_input()` from
`R/replicate-utils.R`, which already errors for `data.frame` and `weighted_df`.
All examples already use `surveycore::as_survey()` or
`surveycore::as_survey_nonprob()`. No example or dispatch changes required.

- `create_bootstrap_weights()` ✅
- `create_jackknife_weights()` ✅
- `create_brr_weights()` ✅
- `create_gen_boot_weights()` ✅
- `create_gen_rep_weights()` ✅
- `create_sdr_weights()` ✅
- `create_replicate_weights()` ✅
- `as_taylor_design()` ✅

### Finally: `ipw()` — SEPARATE SPEC REQUIRED
`ipw()` is the most significant change. Currently accepts a plain `data.frame`
as its primary `data` argument. The new design requires `survey_nonprob` input.

Key questions to resolve in the spec:
- The entry-point pattern: users who have a raw data.frame need to construct
  `as_survey_nonprob(data, weights = rep(1, nrow(data)))` first. Document this
  in a vignette and in the `@param data` description.
- Does the `reference` argument change? Currently accepts `survey_taylor` or
  `survey_replicate`. This seems correct already.
- Does `ipw()` still always return `survey_nonprob` regardless of input class?
  Yes — this is correct and unchanged.

Do NOT implement `ipw()` changes until the spec is written and approved.

---

## After All Functions Are Reviewed

Once the review is complete, implement as a single PR on branch
`refactor/drop-weighted-df` targeting `develop`. The PR covers all functions
except `ipw()` (separate PR after its spec). Tier 2 workflow: plan already
exists (this file) → `/r-implement` → `/commit-and-pr`.
