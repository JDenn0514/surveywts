## `ipw()` accepts `survey_replicate` as reference design

`ipw()` now accepts a `survey_replicate` object as the `reference` argument in
addition to `survey_taylor`. The main design weights are used for propensity
estimation; the replicate weight columns are not used by `ipw()`.

### Changes

- **`R/ipw.R`**: Behavior Rule 2 replaced single `survey_taylor` check with
  two-class check (`survey_taylor || survey_replicate`). New error class
  `surveywts_error_reference_not_survey_design` replaces retired
  `surveywts_error_svydesign_not_taylor`. Coercion of `survey_replicate` →
  `survey_taylor` added before `as_survey_nonprob()` call (surveycore
  constraint). `@param reference`, `@details`, `@examples`, and `@references`
  (Wu 2022) updated.

- **`R/data.R`**: Removed `acs_wy_2022` and `acs_wy_2022_svy` documentation.
  `cps_2023` description updated with inline `as_survey_replicate()` pattern.
  `ns_wave1` `@seealso` updated.

- **`R/trim_weights.R`**: `@examples` updated to use inline `cps_2023`
  construction.

- **`data/`**: `acs_wy_2022.rda` and `acs_wy_2022_svy.rda` deleted.

- **`tests/`**: `test-nonprob-ipw.R` — new happy-path (H-R1–H-R5), error-path
  (E-3, E-4, E-5), and edge-case (EC-1–EC-6) tests for `survey_replicate`
  reference. `test-datasets.R` — removed ACS structural tests; added `cps_2023`
  structural tests.

- **`plans/error-messages.md`**: Retired
  `surveywts_error_svydesign_not_taylor`; added
  `surveywts_error_reference_not_survey_design`.
