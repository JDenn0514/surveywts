---
pr: feature/weighting-history
type: feat
scope: weights
---

## feat(weights): add weighting_history(); stop overriding surveycore print()

Issue: JDenn0514/surveywts#131.

### Behavior change

surveywts no longer registers `print()` methods on `survey_replicate` and
`survey_nonprob`. Those classes belong to surveycore, and S7 keeps one method
per generic and class, so the surveywts methods replaced surveycore's for
every design once surveywts was loaded. They ignored `design_info` and the
other arguments, and they dropped the FPC line, `rho`, the data preview and
the real variance method. `R/methods-print.R` is deleted.

### New export

`weighting_history(x)` returns `x@metadata@weighting_history` as a tibble
with the columns `step`, `timestamp`, `operation` and `description`. An empty
history gives a zero-row tibble. An entry with missing fields uses the
documented fallbacks and never raises an error. A non-`survey_base` input
raises `surveywts_error_not_survey_base`.

### Internal

`.format_history_step()` in `R/utils.R` is replaced by
`.history_step_label()`, which returns only the description, and
`.history_operation()`. The history entries themselves are unchanged.

### Tests

- `test-replicate-print.R` is renamed to `test-weighting-history.R`. Its
  description checks now run against `weighting_history()`.
- The print snapshots in `test-08-nps-bootstrap.R`, `test-nonprob-ipw.R` and
  `test-nps-jackknife.R` are now `weighting_history()` snapshots. The
  overwrite-warning snapshot in `test-replicate-weights.R` no longer prints
  the returned design.
