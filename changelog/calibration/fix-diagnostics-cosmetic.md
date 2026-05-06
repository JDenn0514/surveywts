## fix/diagnostics-cosmetic

**Date:** 2026-03-19
**Spec changes:** 6, 9
**PR:** fix/diagnostics-cosmetic

### Changes

- **`summarize_weights()` grouped path rewrite (Change 6):** Replaced
  `interaction()` with `paste(sep = "//")` + `split()` + `lapply()` pattern
  in the grouped summarization path. `interaction()` uses `.` as its default
  separator, which collides with `.` in factor levels (e.g., `"Dr."`,
  `"H.R."`). The new approach uses `"//"` as separator and preserves
  first-occurrence row ordering instead of alphabetical ordering from
  `split()`.

- **`survey_nonprob` print label fix (Change 9):** Changed the variance
  method label from `"Variance method: Taylor linearization"` to
  `"Variance: model-assisted (SRS assumption)"`. `survey_nonprob` does not
  use Taylor linearization.

### Tests added

- `summarize_weights()` handles grouping variable with dot in levels
- `summarize_weights()` preserves first-occurrence order in grouped output
- `summarize_weights()` handles multi-column by with dots in levels

### Files modified

- `R/diagnostics.R`
- `R/methods-print.R`
- `tests/testthat/_snaps/00-classes.md`
- `tests/testthat/test-06-diagnostics.R`
