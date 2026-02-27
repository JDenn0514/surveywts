# surveyweights Package Development

**Part of the surveyverse ecosystem.**

surveyweights provides tools for survey weighting and calibration.

---

## Current Phase Status

| Phase | Status | Notes |
|-------|--------|-------|
| Phase 0 — Initial implementation | 🔜 Next | See `plans/` |

**Next action:** Begin Phase 0.

---

## Key Implementation Rules

- Every non-trivial change lives on a feature branch — never commit to `main` or
  `develop` directly
- Branch naming: `feature/`, `fix/`, `test/`, `docs/`, `chore/`
- All commits use Conventional Commits format: `feat(scope): description`
- Run `devtools::document()` before committing any file with roxygen2 changes
- Run `devtools::check()` before opening a PR
- Use native pipe `|>` only — never `%>%`
- Use `::` everywhere — no `@importFrom`
- 2-space indentation throughout
- This package uses S7 classes — always call `S7::methods_register()` in `.onLoad()`

## Reference Documents

- `plans/error-messages.md` — canonical error/warning class names
- `.claude/rules/` — code style, testing standards, R package conventions
