# calibration-nps-compat — NPS Bootstrap Compatibility

## Changes

- `rake()`: Added `reference_design = NULL` argument. When a `survey_taylor`
  object is supplied, it is stored in the weighting history entry under
  `parameters$reference_design` and `parameters$targets_from_reference` is set
  to `TRUE`. When `NULL` (default), `targets_from_reference = FALSE` is recorded
  and no reference design is stored. Invalid non-`NULL` non-`survey_taylor` values
  throw `surveywts_error_reference_design_not_taylor`.

- `rake()`: Added `type` to the history `parameters` list. Previously `type` was
  not recorded in the raking history entry; this was a silent bootstrap-replay
  correctness gap. Now `parameters$type` is always present.

- `calibrate()`: Added `reference_design = NULL` argument with the same semantics
  as `rake()`. History entry gains `targets_from_reference` and `reference_design`
  fields.

- `R/utils.R`: Added `.validate_reference_design()` shared helper used by both
  `rake()` and `calibrate()`.

## Error classes added

- `surveywts_error_reference_design_not_taylor`: thrown by both `rake()` and
  `calibrate()` when `reference_design` is non-`NULL` but not a `survey_taylor`.

## Bootstrap replay contract

These additions enable the quasi-randomization bootstrap
(`create_bootstrap_weights(type = "quasi-randomization")`) to replay calibration
steps accurately inside each draw:
- `targets_from_reference = FALSE`: replay with stored fixed targets.
- `targets_from_reference = TRUE`: re-estimate targets from the stored
  `reference_design` before replaying.
