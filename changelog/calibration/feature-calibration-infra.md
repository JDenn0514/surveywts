# chore(infra): set up Phase 0 planning infrastructure and vendor calibration code

**Date**: 2026-03-03
**Branch**: feature/phase-0-infra
**Phase**: Phase 0

## Changes

- Expand `.claude/rules/` with detailed guidance: code-style (S7 dispatch rule, error structure, cli markup, air formatter), github-strategy (workflow tiers, branching model, CI matrix), testing-standards (snapshot rules, warning capture, coverage targets), engineering-preferences (DRY, over/under-engineering heuristics)
- Update `.claude/skills/` for commit-and-pr, merge-main, r-implement, and spec-reviewer with improved workflows and templates
- Add Phase 0 planning documents: spec (`plans/spec-phase-0.md`), adversarial spec review (`plans/spec-review-phase-0.md`), implementation plan (`plans/impl-phase-0.md`), adversarial plan review (`plans/plan-review-phase-0.md`), design decisions log (`plans/decisions-phase-0.md`), and surveycore prerequisite analysis (`plans/surveycore-prerequisites-phase-0.md`)
- Populate `plans/error-messages.md` with Phase 0 error and warning class table
- Vendor GPL-3-compatible calibration code from the survey package: GREG (`R/vendor/calibrate-greg.R`) and IPF (`R/vendor/calibrate-ipf.R`); add `VENDORED.md` attribution file
- Update `DESCRIPTION` (dependencies, author, description text) and `R/surveywts-package.R` with Phase 0 package documentation

## Files Modified

- `.claude/rules/code-style.md` — expanded S7 dispatch rule, error/warning structure, cli inline markup table, air formatter docs, import style
- `.claude/rules/engineering-preferences.md` — added "how to apply during review" section
- `.claude/rules/github-strategy.md` — added workflow tier table, branching model diagram, CI matrix, branch protection settings
- `.claude/rules/testing-standards.md` — added snapshot blocking rules, `skip_if_not_installed` block-level guidance
- `.claude/skills/commit-and-pr/SKILL.md` — rewritten with session recovery, changelog validation, CI monitoring steps
- `.claude/skills/merge-main/SKILL.md` — updated release workflow steps
- `.claude/skills/r-implement/SKILL.md` — updated with CI handoff handling
- `.claude/skills/spec-reviewer/SKILL.md` — streamlined (absorbed into spec-workflow)
- `DESCRIPTION` — updated dependencies, description, and author fields
- `R/surveywts-package.R` — updated package-level documentation for Phase 0
- `man/surveywts-package.Rd` — regenerated from roxygen2
- `plans/error-messages.md` — populated with Phase 0 error/warning class table
- `plans/spec-phase-0.md` — Phase 0 spec (new)
- `plans/spec-review-phase-0.md` — adversarial spec review (new)
- `plans/impl-phase-0.md` — Phase 0 implementation plan (new)
- `plans/plan-review-phase-0.md` — adversarial plan review (new)
- `plans/decisions-phase-0.md` — design decisions log (new)
- `plans/surveycore-prerequisites-phase-0.md` — surveycore prerequisite analysis (new)
- `R/vendor/calibrate-greg.R` — vendored GREG calibration code from survey package
- `R/vendor/calibrate-ipf.R` — vendored IPF/raking code from survey package
- `VENDORED.md` — attribution and licensing for vendored code
