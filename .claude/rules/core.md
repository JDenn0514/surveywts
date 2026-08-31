# surveywts Core Rules

Cross-role rules: every rule below is one any role can violate. Full
conventions — including naming beyond the two classes below — are in
`.claude/standards/surveywts-conventions.md` §1.

## 1. Design variables are sacred

Never remove a weight column. Every weighting function either overwrites the
existing weight column in place (`wt_name = NULL`, the default) or writes a
new column and repoints `@variables$weights` at it. It never drops the old
column, and it refuses to write over a non-weight column: that throws
`surveywts_error_wt_name_conflict`.

In-place overwrite of the main weight column is silent — no warning. Only
replicate weight columns warn when overwritten, via
`surveywts_warning_repweights_overwritten` and
`surveywts_warning_jackknife_repweights_overwritten`.

Column removal and rename hooks are surveycore and surveytidy concerns.
surveywts has no code path that removes or renames a column.

## 2. Weighting history

Every adjustment appends an entry to `@metadata@weighting_history`, built by
`.make_history_entry()` and written by `.update_survey_weights()`.

## 3. `wt_name`

`wt_name = NULL` overwrites the existing weight column in place. A non-NULL
`wt_name` writes a new column and updates `@variables$weights`; if that name
collides with an existing non-weight column, it throws
`surveywts_error_wt_name_conflict`.

## 4. Error and warning class naming

- Error classes: `surveywts_error_{snake_case_condition}`
- Warning classes: `surveywts_warning_{snake_case_condition}`
- `class=` is required on every `cli_abort()` and every `cli_warn()` call —
  no exceptions.

## 5. Internal helpers

Internal helpers carry a `.` prefix (e.g., `.validate_weights()`) and are
never exported.

## 6. Branching and commits

- Every non-trivial change lives on a feature branch — never commit
  implementation code to `main` or `develop`.
- Exception (decided 2026-08-31): edits to files under `plans/` may be
  committed directly to `develop` with a `docs(plans):` message. The
  exception covers `plans/` only — README, `.claude/`, and all other
  documentation still use a branch and a PR.
- Branch naming: `feature/`, `fix/`, `hotfix/`, `test/`, `docs/`, `chore/`,
  `refactor/`.
- All commits use Conventional Commits format: `feat(scope): description`.
- Valid scopes: `calibration`, `weights`, `utils`, `validators`, `replicate`,
  `propensity`, `diagnostics`, `data`, `docs`, `plans`, `pipeline`, `ci`,
  `description`.

## 7. Document and check cadence

- Run `devtools::document()` before committing any file with roxygen2
  changes.
- Run `devtools::check()` before opening a PR.

## 8. Standards pointer table

Read the file for the role and concern you have. None of these auto-load.

| File | Read by |
|---|---|
| `.claude/standards/code-style.md` | builder, reviewer, error-class-auditor |
| `.claude/standards/function-documentation.md` | builder, planner, reviewer, snapshot-reviewer |
| `.claude/standards/r-package-conventions.md` | builder, reviewer, tester |
| `.claude/standards/surveywts-conventions.md` | builder, planner, reviewer, error-class-auditor |
| `.claude/standards/testing-standards.md` | builder, planner, tester, reviewer, coverage-gap-finder |
| `.claude/standards/testing-surveywts.md` | builder, planner, tester, reviewer, coverage-gap-finder |
| `.claude/standards/github-strategy.md` | shipper, reviewer |
| `.claude/standards/engineering-preferences.md` | planner, reviewer |

`code-style.md` covers S7 patterns, cli errors, argument order, the air
formatter. `r-package-conventions.md` covers imports, NAMESPACE, roxygen2,
export policy. `surveywts-conventions.md` covers package-specific naming,
families, visibility, class ownership. `function-documentation.md` covers
roxygen2 tiers, required sections, the `@examples` policy. `testing-standards.md`
covers test structure, coverage targets, assertion patterns.
`testing-surveywts.md` covers package-specific test invariants and data
generators. `github-strategy.md` covers branching model, commit format,
versioning. `engineering-preferences.md` covers DRY, edge cases,
over/under-engineering.

## 9. Reference map

`.claude/reference-map.yaml` maps each exported function to the source
papers behind it. Nothing else in the repo reads it — read it directly when
you need a citation.
