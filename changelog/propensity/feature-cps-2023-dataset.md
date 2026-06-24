# feat(data): add cps_2023 national probability reference dataset

**Date**: 2026-06-24
**Branch**: feature/cps-2023-dataset
**Phase**: Propensity

## Changes

- Add `cps_2023` — ~10,000-row person-level CPS ASEC 2023 adult sample from
  IPUMS-CPS, designed as the `reference` argument for `ipw()` examples. Includes
  160 SDR replicate weight columns (`repwtp1`–`repwtp160`) for variance estimation.
- Add `data-raw/cps-2023.R` — processing script that reads the raw IPUMS
  fixed-width extract via `ipumsr`, strips `haven_labelled` attributes with
  `haven::zap_labels()`, recodes Census division codes to 4-category Census
  regions, draws a stratified random sample (~10k rows, seed 42), and saves
  the result with `usethis::use_data()`.
- Add `hh_income_f9` — 9-bracket household income factor (harmonized levels)
  to both `cps_2023` and `ns_wave1`, enabling income to be included in the
  `ipw()` selection formula. "No answer" in `ns_wave1$ns_income` and the
  99999999 NIU code in `cps_2023$hhincome` both map to `NA`.
- Fix broken `@seealso` link in `as_taylor_design.R` (`create_group_jackknife_weights`
  does not exist); add Claude Code artifacts to `.Rbuildignore` (eliminating
  two pre-existing R CMD check notes).

## Files Modified

- `data-raw/cps-2023.R` *(new)* — IPUMS CPS 2023 processing script
- `data-raw/ns-wave1.R` — add `hh_income_f9` derived from `ns_income`
- `data/cps_2023.rda` *(new)* — bundled dataset (9,999 rows × 187 cols)
- `data/ns_wave1.rda` — regenerated with `hh_income_f9` (185 cols)
- `data/ns_wave1_svy.rda` — regenerated (inherits `hh_income_f9` from `ns_wave1`)
- `R/data.R` — roxygen2 block for `cps_2023` (187 `\item{}` entries); `hh_income_f9` items in both `cps_2023` and `ns_wave1` blocks; IPW example updated to include `hh_income_f9`
- `R/as_taylor_design.R` — remove broken `create_group_jackknife_weights` `@seealso` link
- `man/cps_2023.Rd` *(new)* — generated help file
- `man/ns_wave1.Rd` — regenerated
- `man/as_taylor_design.Rd` — regenerated
- `.gitignore` — add `data-raw/cps_2023/` entry
- `.Rbuildignore` — add `.agents`, `.superpowers`, `skills-lock.json`, `air.toml`
- `changelog/propensity/feature-cps-2023-dataset.md` — this file
