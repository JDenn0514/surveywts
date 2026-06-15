---
pr: feature/nonprob-repweights-diagnostics
type: feat
scope: diagnostics
---

## feat(diagnostics): accept survey_replicate input in all three diagnostic functions

### Behavior change

`effective_sample_size()`, `weight_variability()`, and `summarize_weights()`
now accept `survey_replicate` objects as input. Previously, passing a
`survey_replicate` threw `surveywts_error_replicate_not_supported`.

The change removes the blocking guard from `.diag_validate_input()` in
`R/diagnostics-utils.R`. After removal, `survey_replicate` objects fall
through to the existing `survey_base` path and are processed exactly like
`survey_taylor` or `survey_nonprob` inputs — diagnostics are computed from
the main weight column (`@variables$weights` in `@data`).

Replicate variance of the diagnostics is not computed (out of scope).

### Retired error class

`surveywts_error_replicate_not_supported` is retired. The class remains in
`plans/error-messages.md` marked **RETIRED** but is no longer thrown anywhere
in the package.
