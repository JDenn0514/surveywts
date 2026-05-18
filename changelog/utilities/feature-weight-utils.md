---
pr: feature/weight-utils
type: feat
scope: weights
---

## feat(weights): add trim_weights() and stabilize_weights()

### New functions

- `trim_weights()` — clip-and-redistribute weight trimming with IQR-based
  (default), absolute, and percentile cutpoint modes. Supports `strict = TRUE`
  for iterative trimming until all weights fall within bounds. Handles all
  five input classes: `data.frame`, `weighted_df`, `survey_taylor`,
  `survey_nonprob`, and `survey_replicate` (replicate columns trimmed
  independently per column). Emits `surveywts_warning_no_weights_trimmed`
  when all weights already fall within bounds, and
  `surveywts_warning_trimming_failed` when redistribution fails due to
  exhausted untrimmed units.

- `stabilize_weights()` — rescale weights so they sum to sample size, either
  globally or within groups defined by `by`. Supports the same five input
  classes; replicate columns are rescaled with the same per-group factors
  applied to main weights.

Both functions append a typed history entry via `.make_history_entry()` and
return the same class as their input.

### Bug fix

- `.get_weight_col_name()` in `R/utils.R` now uses
  `S7::S7_inherits(x, surveycore::survey_base)` instead of enumerating
  `survey_taylor` and `survey_nonprob` explicitly, which means
  `survey_replicate` (and any future `survey_base` subclass) is handled
  correctly without a separate branch.
