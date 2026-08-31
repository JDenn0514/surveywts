# docs(docs): add when-to-use guidance across the three method families

**Date**: 2026-08-31
**Branch**: docs/method-choice-guidance
**Phase**: Documentation improvements (plans/doc-method-choice-guidance.md,
from doc-improvements Section C)

## Changes

- Add a "When to use" `@details` paragraph to each calibration sibling
  (`calibrate_rake()`, `calibrate_linear()`, `calibrate_logit()`,
  `poststratify()`) and a poststratify-vs-calibrate routing paragraph to
  `calibrate()`, with citations backed by the calibration comprehension doc
- Add "When to use" cross-references between `calibrate_to_survey()`,
  `calibrate_to_estimate()`, and `calibrate()` (mechanical, no citations)
- Add "When to use" guidance to the six replicate creators
  (`create_bootstrap_weights()`, `create_jackknife_weights()`,
  `create_brr_weights()`, `create_gen_boot_weights()`,
  `create_gen_rep_weights()`, `create_sdr_weights()`), a
  `Choosing a target` section on `create_gen_boot_weights()` for
  `variance_estimator`, and a `svrep::as_bootstrap_design()` pointer on the
  bootstrap `type` parameter
- Add two missing references: Valliant, Dever & Kreuter (2018) to
  `create_brr_weights()` and Ash (2014) to `create_gen_boot_weights()`,
  with matching `.claude/reference-map.yaml` rows
- Add mechanical "Choose it when" guidance to the three
  `adjust_nonresponse()` method bullets, a "When to use" opener on its
  `@details` with an `ipw()` cross-reference, and a routing sentence on
  `redistribute_weights()` (no citations — no comprehension doc covers the
  nonresponse family)

## Files Modified

- `R/calibrate.R` — poststratify routing paragraph in `@details`
- `R/calibrate_rake.R` — "When to use" `@details` block
- `R/calibrate_linear.R` — "When to use" `@details` block
- `R/calibrate_logit.R` — "When to use" `@details` block
- `R/poststratify.R` — "When to use" `@details` block
- `R/calibrate_to_survey.R` — "When to use" cross-reference paragraph
- `R/calibrate_to_estimate.R` — "When to use" cross-reference paragraph
- `R/create_bootstrap_weights.R` — "When to use" paragraph; `@param type`
  svrep pointer
- `R/create_jackknife_weights.R` — "When to use" `@details` block
- `R/create_brr_weights.R` — "When to use" `@details` block; VDK 2018
  reference
- `R/create_gen_boot_weights.R` — "When to use" `@details` block;
  `Choosing a target` section; Ash 2014 reference
- `R/create_gen_rep_weights.R` — "When to use" `@details` block
- `R/create_sdr_weights.R` — "When to use" `@details` block
- `R/adjust_nonresponse.R` — method-bullet choice sentences; `@details`
  opener; `ipw()` in `@seealso`
- `R/redistribute_weights.R` — routing sentence in `@details`
- `.claude/reference-map.yaml` — VDK 2018 row for `create_brr_weights`;
  Ash 2014 row for `create_gen_boot_weights`
- `man/` — the 15 matching `.Rd` topics regenerated
