# test(utils): check `survey_nonprob` objects in `test_invariants()`

**Date**: 2026-09-03
**Branch**: JDenn0514/test_invariants-never-checks-survey_nonprob-obje
**Issue**: #117

## Changes

- Change the `survey_nonprob` branch of `test_invariants()` to test
  `surveycore::survey_nonprob`, the form the other two branches use. The
  branch tested a bare class name behind `exists("survey_nonprob")`, which
  is always `FALSE`, so 77 of the 282 calls asserted nothing
- Correct the standards file, which recorded the guard as deliberate. All
  three branches now test the qualified class name, and the file says so
- Add the NEWS entry under `## Internal`

## Verification

- Full suite before the change: 3837 passed, 0 failed, 0 errors, 6 skipped
- Full suite after: 4145 passed, 0 failed, 0 errors, 6 skipped
- The 308 new expectations are the 77 dead calls times the 4 weight
  invariants each call asserts. Nothing failed, so no `survey_nonprob`
  object in the suite was breaking an invariant and no fixture needed a fix
- `devtools::check()`: 0 errors, 0 warnings, 1 note (the pre-existing `.git`
  hidden-directory note from running in a worktree)

## Files Modified

- `tests/testthat/helper-test-data.R` — the one-line branch condition
- `.claude/standards/testing-surveywts.md` — replace the guard rationale
  with the rule that all three branches test the qualified class name
- `NEWS.md` — entry under `## Internal`
