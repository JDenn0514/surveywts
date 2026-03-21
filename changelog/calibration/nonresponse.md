# Changelog: adjust_nonresponse()

## PR 8 — feat(calibration): implement adjust_nonresponse()

### New function: `adjust_nonresponse()`

Weighting-class nonresponse adjustment. Redistributes nonrespondent weights to
respondents within weighting classes defined by `by`. Returns only respondent
rows with adjusted weights.

**Signature:**

```r
adjust_nonresponse(
  data,
  response_status,
  weights = NULL,
  by = NULL,
  method = c("weighting-class", "propensity-cell", "propensity"),
  control = list(min_cell = 20, max_adjust = 2.0)
)
```

**Key behaviours:**

- Accepts `data.frame`, `weighted_df`, `survey_taylor`, and `survey_nonprob`.
- Returns `weighted_df` for data frame inputs; same class for survey objects
  (does not promote to `survey_nonprob`).
- Returns only respondent rows (`response_status == 1` or `TRUE`).
- Weight update formula within each cell `h`:
  `w_new = w * (sum(w_h) / sum(w_h_respondents))`.
- `by = NULL` performs global redistribution across all rows.
- Appends a history entry with `operation = "nonresponse_weighting_class"` and
  `convergence = NULL` (non-iterative).
- `method = "propensity"` and `method = "propensity-cell"` are API-stable Phase 2
  stubs that error immediately.

**Warnings:**

- `surveywts_warning_class_near_empty` -- a weighting class cell has fewer
  than `control$min_cell` respondents (default 20) OR the adjustment factor
  exceeds `control$max_adjust` (default 2.0). Either condition alone triggers
  the warning.

**Errors thrown:**

- `surveywts_error_response_status_not_found` -- `response_status` column
  missing from data.
- `surveywts_error_response_status_not_binary` -- column is not 0/1 or
  logical (factor columns are rejected regardless of their levels).
- `surveywts_error_response_status_has_na` -- `response_status` column
  has NA values.
- `surveywts_error_response_status_all_zero` -- no respondents in data.
- `surveywts_error_class_cell_empty` -- a weighting class cell has no
  respondents.
- `surveywts_error_variable_has_na` -- NA in a `by` variable.
- `surveywts_error_propensity_requires_phase2` -- `method` is `"propensity"`
  or `"propensity-cell"` (Phase 2 stubs).
- All standard SE-1 through SE-8 input validation errors.

### New private helper: `.validate_response_status_binary()`

Validates that the `response_status` column is binary (integer 0/1 or logical).
Explicitly rejects factor columns even if they have exactly 2 levels. Co-located
in `R/05-nonresponse.R`.
