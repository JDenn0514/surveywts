# Changelog: poststratify()

## PR 7 — feat(calibration): implement poststratify()

### New function: `poststratify()`

Exact post-stratification to known joint population cell counts or proportions.
Unlike `calibrate()` and `rake()`, which match marginal totals, `poststratify()`
matches cross-tabulation cells in a single pass with no iteration.

**Signature:**

```r
poststratify(data, strata, population, weights = NULL, type = c("count", "prop"))
```

**Key behaviours:**

- Accepts `data.frame`, `weighted_df`, `survey_taylor`, and `survey_calibrated`.
- Returns `weighted_df` for data frame inputs; `survey_calibrated` for survey objects.
- Default `type = "count"` (differs from `calibrate()` and `rake()`).
- Strata variables may be any type (character, factor, integer, numeric) -- no
  categorical restriction.
- Post-stratification formula: `w_new = w * (N_h / N_hat_h)`.
- Appends a history entry with `operation = "poststratify"` and `convergence = NULL`
  (non-iterative).

**Errors thrown:**

- `surveywts_error_variable_has_na` -- NA in a strata variable.
- `surveywts_error_population_totals_invalid` -- prop targets don't sum to 1,
  or count target <= 0.
- `surveywts_error_population_cell_duplicate` -- duplicate cell in population.
- `surveywts_error_population_cell_missing` -- data cell absent from population.
- `surveywts_error_population_cell_not_in_data` -- population cell absent from data.
- `surveywts_error_empty_stratum` -- cell has zero weighted count (defensive guard).
- All standard SE-1 through SE-8 input validation errors.

### New private helper: `.validate_population_cells()`

Validates the `population` data frame structure for `poststratify()`. Checks
required columns, duplicate rows, data-population cell alignment, and target
validity. Co-located in `R/04-poststratify.R` (not in `07-utils.R`) because
only `poststratify()` calls it.
