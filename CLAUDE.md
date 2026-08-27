# surveywts Package Development

**Part of the surveyverse ecosystem.**

surveywts provides tools for survey weighting and calibration.

---

## Release Status

| Release | Tag | Status | Notes |
|---------|-----|--------|-------|
| Calibration | `v0.1.0` | ✅ Complete | `calibrate()`, `calibrate_rake()`, `calibrate_linear()`, `calibrate_logit()`, `poststratify()`, basic diagnostics |
| Replicate | minor bump | ✅ Complete | All `create_*_weights()` functions; `as_taylor_design()` |
| Utilities | minor bump | ✅ Complete | `trim_weights()`, `rescale_weights()` |
| Nonresponse | minor bump | ✅ Complete | `calibrate_to_survey()`, `calibrate_to_estimate()`, `adjust_nonresponse()`, `redistribute_weights()` |
| Propensity | minor bump | ✅ Complete | Non-probability sample IPW; unlocks propensity nonresponse |
| Diagnostics | minor bump | 🔜 Next | Balance assessment, `check_balance()`, `diagnose_propensity()`, `compare_weighted_estimates()` |
| Polish | minor bump | ⬜ Pending | Vignettes, `--as-cran` clean, pkgdown |

Full roadmap at `plans/roadmap.md`.

---

## Naming Conventions

> Full conventions are in `.claude/rules/surveywts-conventions.md` §1. The
> three below are the ones that come up most often.

- Error classes: `surveywts_error_{snake_case_condition}`
- Warning classes: `surveywts_warning_{snake_case_condition}`
- Internal helpers: prefix with `.` (e.g., `.validate_weights()`)

## Key Implementation Rules

**Design variables are sacred** — never remove a weight column. Every
weighting function either overwrites the existing weight column in place
(`wt_name = NULL`, the default) or writes a new column and repoints
`@variables$weights` at it. It never drops the old column, and it refuses to
write over a non-weight column: that throws
`surveywts_error_wt_name_conflict`.

In-place overwrite of the main weight column is silent — no warning. Only
replicate weight columns warn when overwritten, via
`surveywts_warning_repweights_overwritten` and
`surveywts_warning_jackknife_repweights_overwritten`.

**Weighting history** — every adjustment appends an entry to
`@metadata@weighting_history`, built by `.make_history_entry()` and written by
`.update_survey_weights()`. Column removal and rename hooks are surveycore and
surveytidy concerns; surveywts has no code path that removes or renames a
column.

---

## Workflow Requirements

- Every non-trivial change lives on a feature branch — never commit implementation code to `main` or `develop`
- Branch naming: `feature/`, `fix/`, `hotfix/`, `test/`, `docs/`, `chore/`, `refactor/`
- All commits use Conventional Commits format: `feat(scope): description`
- Valid scopes: `calibration`, `weights`, `utils`, `validators`, `replicate`,
  `propensity`, `diagnostics`, `data`, `docs`, `plans`, `pipeline`, `ci`,
  `description` — see `.claude/rules/github-strategy.md`
- Run `devtools::document()` before committing any file with roxygen2 changes
- Run `devtools::check()` before opening a PR

## R CMD Check Gotchas

**Examples must load Imports packages explicitly.** R CMD check runs examples in a fresh session
with only `library(surveywts)` loaded. If an example calls a bare function from an Imports
package, add `library(pkg)` at the top of the block.

## Reference Documents

- `plans/error-messages.md` — canonical error/warning class names and CLI message templates
- `.claude/WORKFLOW.md` — how the skills fit together (planning arc → implementation loop)
- `.claude/rules/code-style.md` — S7 patterns, cli errors, arg order, air formatter
- `.claude/rules/r-package-conventions.md` — imports, NAMESPACE, roxygen2, export policy
- `.claude/rules/surveywts-conventions.md` — package-specific naming, families, visibility, class ownership
- `.claude/rules/function-documentation.md` — roxygen2 tiers, required sections, `@examples` policy
- `.claude/rules/testing-standards.md` — test structure, coverage targets, assertion patterns
- `.claude/rules/testing-surveywts.md` — package-specific test invariants and data generators
- `.claude/rules/github-strategy.md` — branching model, commit format, versioning
- `.claude/rules/engineering-preferences.md` — DRY, edge cases, over/under-engineering
