# fix-poststratify-default-type

**Type:** fix (breaking)
**Scope:** calibration
**Phase:** 0

## Summary

Changed `poststratify()` default `type` from `"count"` to `"prop"` for
consistency with `calibrate()` and `rake()`.

## Changes

- `R/poststratify.R`: Swapped `type = c("count", "prop")` to
  `type = c("prop", "count")` in function signature. Updated `@param type`
  roxygen and `@examples` block.
- `tests/testthat/test-04-poststratify.R`: Rewrote default-type test (1c) to
  assert `"prop"` is the default. Added explicit `type = "count"` to all
  tests that use count-format population data. Fixed `nchar()` assertion for
  multi-element `deparse()` output.
- `tests/testthat/_snaps/04-poststratify.md`: Regenerated all snapshots.
- `man/poststratify.Rd`: Regenerated.
- `NEWS.md`: Added breaking change entry.

## Migration

Add `type = "count"` to any existing `poststratify()` call that passes
count-format population data without an explicit `type` argument.
