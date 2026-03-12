# surveywts Package Development

**Part of the surveyverse ecosystem.**

surveywts provides tools for survey weighting and calibration.

---

## Current Phase Status

| Phase | Tag | Status | Notes |
|-------|-----|--------|-------|
| Phase 0 — Calibration Core | `v0.1.0` | ✅ Complete | `survey_nonprob`, `calibrate()`, `rake()`, `poststratify()`, basic diagnostics |
| Phase 1 — Replicate Weights | `v0.2.0` | 🔜 Next | All `create_*_weights()` functions; unlocks bootstrap variance in `survey_nonprob` |
| Phase 2 — Nonresponse & Advanced Calibration | `v0.3.0` | ⬜ Pending | `calibrate_to_sample()`, weighting-class nonresponse |
| Phase 3 — Propensity Score Weighting | `v0.4.0` | ⬜ Pending | IPW for causal inference; unlocks propensity nonresponse |
| Phase 4 — Diagnostics & Utilities | `v0.5.0` | ⬜ Pending | Balance assessment, `trim_weights()`, `stabilize_weights()` |
| Phase 5 — Polish & CRAN | `v1.0.0` | ⬜ Pending | Vignettes, `--as-cran` clean, pkgdown |

**Next action:** Begin Phase 1. Start with `/spec-workflow` to draft the spec.
Full roadmap at `plans/roadmap.md`.

---

## Naming Conventions

> To be filled in as Phase 0 API is designed. See `plans/` for specs.

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
