# feat(nonresponse): implement adjust_nonresponse(method = "propensity")

**Date**: 2026-05-22
**Branch**: feature/nonresponse-propensity
**Phase**: Propensity

## Changes

- Implement `adjust_nonresponse(method = "propensity")` — individual-level
  IPW nonresponse adjustment via logistic response propensity model. Removes
  the `surveywts_error_propensity_not_available` stub; method is now fully
  supported across `data.frame`, `weighted_df`, `survey_taylor`, and
  `survey_nonprob` inputs.
- Add 2 new error classes and 3 new warning classes in
  `plans/error-messages.md` for the propensity method:
  `surveywts_error_formula_required_for_propensity`,
  `surveywts_warning_by_ignored_for_propensity`,
  `surveywts_warning_extreme_propensity_adjustment`,
  `surveywts_warning_propensity_glm_convergence`.
- Redesign bundled IPW datasets for a consistent 3-level age/race/educ
  schema aligned across all NPS/reference pairs:
  - `ns_wave1_ipw`: expanded from 2 columns (`gender`, `age`) to 4 columns
    (`gender`, `age_group`, `race_ethn`, `educ`); `age` column removed.
  - `gss_ipw_ref`: weight column renamed from `wtssps` to `wt_pop` (scaled
    to 2024 US adult population); `age` column collapsed to `age_group`.
  - `npors_2025_ipw` renamed to `npors_2025_ref` and converted from a plain
    data frame to a `survey_taylor` reference design with population-scaled
    `wt_pop`.
  - `acs_ipw_ref`: `age_group` collapsed from 13 levels to 3 (`"18-34"`,
    `"35-54"`, `"55+"`).
- Update `ipw()` roxygen2 `@examples` to use the redesigned datasets
  (`npors_2025_ref` instead of `npors_2025_ipw`; `age_group` instead of
  `age`); add third example pair (NS Wave 1 × ACS PUMS WY).
- Update `_pkgdown.yml` to reference `npors_2025_ref` in place of
  `npors_2025_ipw`.
- Remove stub tests for `surveywts_error_propensity_not_available`; add 439
  lines of new tests for the full propensity method (happy paths, error
  paths, edge cases, history correctness).

## Implementation Notes

- **Formula required**: `method = "propensity"` requires `formula`; if
  `formula = NULL`, the function errors with
  `surveywts_error_formula_required_for_propensity`.
- **`by` ignored**: when `method = "propensity"` and `by` is non-`NULL`, a
  `surveywts_warning_by_ignored_for_propensity` warning is issued and `by`
  is silently dropped — individual-level scores make cell grouping redundant.
- **`max_adjust` semantics**: for `"propensity"`, the adjustment ratio is
  `max(w_i / score_i) / mean(w)` across respondents (not cell-level as in
  `"propensity-cell"`). Default threshold raised from 2.0 to 5.0 to match
  typical IPW variability.
- **`survey_taylor` path**: nonrespondent rows are dropped (same behavior as
  the existing `"propensity-cell"` path) since `survey_taylor` does not
  support zero weights.
- **Dataset redesign rationale**: all four datasets now share identical
  factor level sets so that any NPS/reference pair can be used together
  without per-example recoding. The `wt_pop` population-scaled weight
  convention (used by `ipw()`) is now applied uniformly.

## Files Modified

- `R/nonresponse.R` — propensity method implementation; remove stub
- `R/nonprob-ipw.R` — updated `@examples` for redesigned datasets
- `R/data.R` — updated roxygen2 docs for all four IPW datasets
- `data/ns_wave1_ipw.rda` — 4-column redesign
- `data/gss_ipw_ref.rda` — `wt_pop` weight, `age_group` collapse
- `data/npors_2025_ipw.rda` — deleted
- `data/npors_2025_ref.rda` *(new)* — `survey_taylor` reference design
- `data/acs_ipw_ref.rda` — `age_group` collapsed to 3 levels
- `data-raw/ns-gss-ipw.R` — updated harmonization script
- `data-raw/npors-acs-ipw.R` — updated harmonization script
- `man/ipw.Rd`, `man/adjust_nonresponse.Rd`, `man/acs_ipw_ref.Rd`,
  `man/gss_ipw_ref.Rd`, `man/ns_wave1_ipw.Rd` — regenerated
- `man/npors_2025_ipw.Rd` — deleted
- `man/npors_2025_ref.Rd` *(new)* — regenerated
- `_pkgdown.yml` — `npors_2025_ref` reference added
- `plans/error-messages.md` — new error/warning classes; stub retired
- `plans/impl-propensity.md` — updated implementation plan
- `tests/testthat/test-05-nonresponse.R` — remove stub tests; add propensity method tests
- `tests/testthat/_snaps/05-nonresponse.md` — updated snapshots
- `changelog/propensity/feature-nonresponse-propensity.md` — this file
