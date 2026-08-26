# surveywts R Package Conventions

**Version:** 1.1 — Calibration API complete
**Status:** Stable for Calibration — extends `r-package-conventions.md`. Read
that file first, then this one.

## Quick Reference (surveywts-specific)

| Decision | Choice | Example |
|----------|--------|---------|
| Error prefix | `surveywts_error_*` | `surveywts_error_weights_nonpositive` |
| Warning prefix | `surveywts_warning_*` | `surveywts_warning_weight_col_dropped` |
| Calibration / nonresponse function return | Visible (new object) | `calibrate_rake()` |
| Internal constructor return | Visible (the new object) | `.new_survey_nonprob()` |
| Internal validator return | `invisible(TRUE)` on success | `.validate_weights()` |
| Print method return | `invisible(x)` | `print.weighted_df()`, S7 print |
| Diagnostic function return | Visible named scalar or tibble | `effective_sample_size()` |

## Naming conventions

| Category | Pattern | Example |
|----------|---------|---------|
| User-facing calibration functions | verb | `calibrate()`, `calibrate_rake()`, `poststratify()` |
| User-facing nonresponse function | verb + noun | `adjust_nonresponse()` |
| User-facing diagnostic functions | noun phrase | `effective_sample_size()`, `weight_variability()`, `summarize_weights()` |
| Internal constructor | `.new_` prefix | `.new_survey_nonprob()` |
| Internal validators | `.validate_` prefix | `.validate_weights()`, `.validate_calibration_variables()` |
| Internal shared helpers | `.` prefix + descriptive name | `.get_weight_vec()`, `.compute_weight_stats()`, `.make_history_entry()` |
| Internal dispatch/engine functions | `.` prefix + `_engine` suffix | `.calibrate_engine()` |
| Internal output constructors | `.make_` prefix | `.make_weighted_df()` |

## Function families (`@family` groups)

| Family tag | Functions |
|------------|-----------|
| `calibration` | `calibrate()`, `calibrate_linear()`, `calibrate_logit()`, `calibrate_rake()`, `poststratify()` |
| `sample-calibration` | `calibrate_to_survey()`, `calibrate_to_estimate()` |
| `nonresponse` | `adjust_nonresponse()`, `redistribute_weights()` |
| `diagnostics` | `effective_sample_size()`, `weight_variability()`, `summarize_weights()` |
| `replicate-weights` | `create_bootstrap_weights()`, `create_jackknife_weights()`, `create_brr_weights()`, `create_gen_boot_weights()`, `create_gen_rep_weights()`, `create_sdr_weights()`, `create_replicate_weights()`, `as_taylor_design()` |
| `utilities` | `trim_weights()`, `rescale_weights()` |
| `propensity` | `ipw()` |

## File organization

1. Every exported function lives in a `.R` file named identically to it
   (matching its `.Rd` filename without the extension), with the exported
   function at the **top** and its single-use helpers **below** it.
2. Helpers shared by 2+ functions in the same family go to
   `{family}-utils.R`; helpers used across families stay in `utils.R`.
3. Structural/role-based files are exempt from rule 1.

| Exempt file | Purpose |
|------|---------|
| `utils.R` | Cross-family internal helpers |
| `methods-print.R` | All S7 and S3 print methods |
| `zzz.R` | `.onLoad()` / `.onAttach()` hooks |
| `data.R` | `@docType data` documentation stubs |
| `surveywts-package.R` | Package-level documentation |

| Family utils file (shared helpers) | Functions covered |
|------|--------------------|
| `diagnostics-utils.R` | `effective_sample_size()`, `weight_variability()`, `summarize_weights()` |
| `nonresponse-utils.R` | `adjust_nonresponse()`, `redistribute_weights()` |
| `replicate-utils.R` | All `create_*_weights()` functions + `as_taylor_design()` |
| `jackknife-dagjk-utils.R` | DAGJK engine internals for `create_jackknife_weights()` |
| `weight-utils.R` | `trim_weights()`, `rescale_weights()` |

## Export policy

Export: all user-facing functions (`calibrate()`, `calibrate_rake()`,
`poststratify()`, `adjust_nonresponse()`, `effective_sample_size()`,
`weight_variability()`, `summarize_weights()`, ...); the `survey_nonprob` S7
class object; `print.weighted_df()` and `dplyr_reconstruct.weighted_df()`
via `@export` (S3 method registration).
Do NOT export: any `.`-prefixed internal helper or constructor
(`.validate_weights()`, `.make_weighted_df()`, `.new_survey_nonprob()`);
`weighted_df` is never exported as an object — it is produced as output,
never constructed by users.

## S7 classes

`survey_nonprob` inherits all properties from `survey_base` (`@data`,
`@variables`, `@metadata`); `@variables$weights` names the weight column;
weighting history lives in `@metadata@weighting_history`. It extends
`survey_base` directly, not `survey_taylor`, to avoid inheriting
Taylor-specific dispatch that would be incorrect post-calibration.

The validator enforces 5 conditions (S7 native mechanism, not
`cli_abort()` — test with `class=` only, no snapshot):

1. `@variables$weights` is a character scalar
2. The named column exists in `@data`
3. That column is numeric
4. All values are strictly positive (> 0)
5. No NAs in the weight column

`weighted_df` is an S3 subclass of tibble, never constructed by users, with
class vector `c("weighted_df", "tbl_df", "tbl", "data.frame")` and two
attributes: `weight_col` (`character(1)`, the weight column's name) and
`weighting_history` (`list`, ordered history entries).

`dplyr_reconstruct.weighted_df()` preserves the `weighted_df` class when the
weight column is retained; emits `surveywts_warning_weight_col_dropped` and
returns a plain tibble when the weight column is removed.

---
Full argument-order signatures, the R/ → export file map, the S7
`new_class()` block, and the pre-commit documentation checklist:
`.claude/references/r-package-detail.md` §surveywts conventions — detail.
Read it when adding a new exported function or auditing file placement.
