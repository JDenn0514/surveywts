# surveywts Package Development

**Part of the surveyverse ecosystem.**

surveywts provides tools for survey weighting and calibration.

---

## Release Status

| Release | Tag | Status | Notes |
|---------|-----|--------|-------|
| Calibration | `v0.1.0` | ✅ Complete | `survey_nonprob`, `calibrate()`, `rake()`, `poststratify()`, basic diagnostics |
| Replicate | minor bump | ✅ Complete | All `create_*_weights()` functions; `as_taylor_design()` |
| Utilities | minor bump | ✅ Complete | `trim_weights()`, `rescale_weights()` |
| Nonresponse | minor bump | ✅ Complete | `calibrate_to_survey()`, `calibrate_to_estimate()`, `adjust_nonresponse()`, `redistribute_weights()` |
| Propensity | minor bump | ✅ Complete | Non-probability sample IPW; unlocks propensity nonresponse |
| Diagnostics | minor bump | 🔜 Next | Balance assessment, `check_balance()`, `diagnose_propensity()`, `compare_weighted_estimates()` |
| Polish | minor bump | ⬜ Pending | Vignettes, `--as-cran` clean, pkgdown |

**Next action:** Begin Diagnostics.
Full roadmap at `plans/roadmap.md`.

---

## Naming Conventions

> To be filled in as the Calibration API is designed. See `plans/` for specs.

- Error classes: `surveywts_error_{snake_case_condition}`
- Warning classes: `surveywts_warning_{snake_case_condition}`
- Internal helpers: prefix with `.` (e.g., `.validate_weights()`)

## Key Implementation Rules

**Design variables are sacred** — never remove or silently rename weight
columns. Always warn when weight column is modified.

**Metadata lifecycle** — if metadata is added later, auto-delete on removal;
auto-rename on rename; track transformation history.

---

## Workflow Requirements

- Every non-trivial change lives on a feature branch — never commit implementation code to `main` or `develop`
- Branch naming: `feature/`, `fix/`, `test/`, `docs/`, `chore/`
- All commits use Conventional Commits format: `feat(scope): description`
- Valid scopes: `classes`, `constructors`, `validators`, `weights`, `calibration`, `utils`
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
- `.claude/rules/surveywts-conventions.md` — package-specific naming, families, visibility
- `.claude/rules/testing-standards.md` — test structure, coverage targets, assertion patterns
- `.claude/rules/testing-surveywts.md` — package-specific test invariants and data generators
- `.claude/rules/github-strategy.md` — branching model, commit format, versioning
- `.claude/rules/engineering-preferences.md` — DRY, edge cases, over/under-engineering
- `.claude/references/` — worked examples and rationale moved out of `.claude/rules/`; read one when a rule's use is unclear
