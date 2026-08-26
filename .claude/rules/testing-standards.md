# Surveyverse Testing Standards

**Version:** 1.2
**Status:** Decided — applies to all surveyverse packages

For package-specific testing conventions, see the `testing-{package}.md`
rule in each package's `.claude/rules/` directory.

## Quick Reference

| Decision | Choice |
|----------|--------|
| Test file granularity | At least 1 file per source file; large source files may split |
| `test_that()` scope | One observable behavior per block |
| Nesting | Flat — no `describe()` blocks |
| Coverage target | 98%+ line coverage; PRs blocked below 95% |
| Test categories | Happy path + error paths + edge cases |
| Private function testing | Default indirect; direct only when gap can't be closed via public API |
| Constructor error testing | Dual: `expect_error(class=)` + `expect_snapshot(error=TRUE)` |
| Structural validator errors | `class=` only — no snapshot (messages not CLI-formatted) |
| Snapshot failures | Block PRs; update via `snapshot_review()` before opening |
| Warning capture | `expect_warning()` wrapping call; result from return value |
| Structural assertions | `expect_identical()` |
| Numeric assertions | `expect_equal()` |
| Synthetic test data | Package-specific generator with `seed =`; defined in `helper-*.R` |
| Edge case data | Inline in tests; never add edge case parameters to a data generator |
| `skip_if_not_installed` | Block-level, inside affected `test_that()` blocks |

## Structure

- Naming: `R/my-thing.R` → `tests/testthat/test-my-thing.R`.
- Each `test_that()` description is a present-tense assertion naming ONE
  observable behavior ("rejects data frames with 0 rows"), never a vague
  category ("validates input").
- Flat `test_that()` only — no `describe()` nesting.

## Coverage

- 98%+ line coverage is the target; CI blocks PRs below 95%.
- `# nocov` requires an explanatory comment on the preceding line.
  Acceptable: defensive branches unreachable via the public API,
  platform-specific paths, documented non-goals. Unacceptable: covering for
  missing tests, or errors that "feel hard to trigger" — find the trigger.
- Every exported function has tests in all three categories: happy path,
  every typed error class, and edge cases (boundaries, NAs, empty inputs,
  single-row inputs).
- Test private helpers indirectly via the public API; direct tests only when
  coverage cannot be achieved indirectly AND the behavior is material.

## Assertions

- User-facing constructor errors: dual pattern —
  `expect_error(class = ...)` PLUS `expect_snapshot(error = TRUE, ...)`.
- Structural/invariant errors (S7 class validators): `class=` only, no
  snapshot.
- Snapshot failures block PRs. Update only via `testthat::snapshot_review()`
  with each diff reviewed; never blind `snapshot_accept()`. Snapshots live
  in `tests/testthat/_snaps/` and are committed.
- Warnings: `expect_warning(result <- fn(...), class = ...)`; never
  `withCallingHandlers()` or `tryCatch()` in tests.

| Use `expect_identical()` for... | Use `expect_equal()` for... |
|---------------------------------|-----------------------------|
| Character vectors, names | Floating-point output |
| `NULL` and `NA` values | Numeric computations with tolerance |
| Exact string/integer property values | Any calculated numeric result |
| List structure (keys present/absent) | Weights, proportions, estimates |

## Test data

- Each package defines a synthetic generator in `tests/testthat/helper-*.R`:
  accepts `seed =`, returns a plain data structure, produces realistic
  variation (unequal sizes, imbalanced groups). Use it for all unit tests.
- Real datasets ONLY for numerical validation against a reference
  implementation, in a dedicated test file.
- Edge cases needing specific atypical values are constructed inline in the
  test — never added as generator parameters.
- `skip_if_not_installed()` goes inside the `test_that()` block that needs
  it, never at file level.

---
Worked examples (category examples, dual pattern, warning capture, nocov,
skip placement): `.claude/references/testing-detail.md`. Read it when
writing a new test file and the pattern is not obvious from these rules.
