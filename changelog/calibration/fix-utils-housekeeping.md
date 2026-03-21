# refactor(utils): move helpers to utils.R and inline %||%

**Date**: 2026-03-19
**Branch**: fix/utils-housekeeping
**Phase**: Phase 0

## Changes

- Moved `.check_input_class()` and `.get_history()` from `R/calibrate.R` to `R/utils.R` (used by 4 source files)
- Inlined 4 `%||%` usage sites with explicit `if (is.null(x)) y else x` checks
- Removed the `%||%` redefinition from `R/utils.R`
- Updated `R/utils.R` header comment to list new functions
- Updated header comments in `R/calibrate.R`, `R/poststratify.R`, and `R/nonresponse.R` to reflect new locations
- Documented `@importFrom` exception for S3 method registration in `.claude/rules/code-style.md`

## Files Modified

- `R/utils.R` -- received `.check_input_class()` and `.get_history()`; inlined `%||%`; removed `%||%` definition
- `R/calibrate.R` -- removed `.check_input_class()` and `.get_history()` definitions; updated header comment
- `R/poststratify.R` -- updated header comment to reference utils.R
- `R/nonresponse.R` -- updated header comment to reference utils.R
- `.claude/rules/code-style.md` -- added `@importFrom` exception for S3 method registration
