# fix(data): add nest = TRUE to gss_ipw_ref survey design

**Date**: 2026-06-14
**Branch**: fix/gss-ipw-ref-nest
**Phase**: Propensity

## Changes

- Added `nest = TRUE` to `gss_ipw_ref` survey design construction so GSS PSU
  IDs (non-globally-unique across strata) are correctly paired; fixes
  `create_bootstrap_weights()` failure via `survey::as.svrepdesign()`
- Updated `README.Rmd` to use `npors_2025_clean_ref` (NA-free) in the
  calibrate-to-survey example, replacing `eval=FALSE` with a live chunk
- Added `npors_2025_clean_ref`, `pew_2016_optin`, and `pew_2016_synth_pop` to
  `_pkgdown.yml` reference index; split Example Datasets into IPW and
  Calibration subsections to accommodate all seven dataset entries

## Files Modified

- `data-raw/ns-gss-ipw.R` — add `nest = TRUE` to `as_survey()` call for `gss_ipw_ref`
- `data/gss_ipw_ref.rda` — regenerated with corrected survey design
- `README.Rmd` — switch calibrate-to-survey example to `npors_2025_clean_ref`; remove `eval=FALSE`
- `README.md` — re-rendered from updated `README.Rmd`
- `_pkgdown.yml` — add missing datasets to reference index; restructure Example Datasets section
