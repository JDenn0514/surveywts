# Changelog Workflow

This is a reference document, not an invocable skill. It defines the canonical
changelog format enforced by `commit-and-pr`.

---

## Location and Timing

```
Location:  changelog/phase-{X}/{branch-name}.md
Timing:    Created LAST on the branch, BEFORE opening the PR
Populated: From git log develop..HEAD --oneline
```

Where `{X}` is the current phase number (e.g., `1` for Phase 1). If unsure,
check the branch name or ask the user.

---

## Entry Format

```markdown
# [type]([scope]): [description]

**Date**: YYYY-MM-DD
**Branch**: feature/[name]
**Phase**: Phase X

## Changes

- [Bullet derived from commit messages describing what changed]
- [One bullet per logical change, not one per commit]

## Files Modified

- `R/[file].R` — [one sentence describing what changed in this file]
- `tests/testthat/test-[file].R` — [one sentence]
- `plans/error-messages.md` — [if new error classes were added]
```

---

## Deriving Content from Commits

Run `git log develop..HEAD --oneline` to get the commit list. Use those messages
to populate the `## Changes` section. Group related commits into single bullets
where appropriate (e.g., a sequence of "fix: " commits that address the same
issue can be one bullet).

---

## Validation Rules

These are enforced by `commit-and-pr` before a PR is opened:

1. File must exist at `changelog/phase-{X}/{branch-name}.md`
2. File must not be empty or a stub (no `<!-- TODO -->` placeholders)
3. `## Changes` section must have at least one bullet
4. `## Files Modified` section must list at least one file
5. `**Date**` must be a real date (not a placeholder)

---

## Example

For a branch `feature/variance-twophase` in Phase 0.75:

```markdown
# feat(variance): implement two-phase Taylor variance estimation

**Date**: 2026-02-23
**Branch**: feature/variance-twophase
**Phase**: Phase 0.75

## Changes

- Vendor two-phase variance code from the survey package (GPL-3 compatible)
- Implement `survey_twophase` variance estimation via Taylor linearization
- Add numerical oracle tests comparing against `survey::svymean()` for two-phase designs
- Update `plans/error-messages.md` with new twophase-specific error classes

## Files Modified

- `R/06-variance-estimation.R` — add `twophase_variance()` and helpers
- `R/vendor/twophase-variance.R` — vendored code from survey package
- `tests/testthat/test-variance-estimation.R` — two-phase oracle tests
- `plans/error-messages.md` — new twophase error class rows
- `VENDORED.md` — updated with new vendored code attribution
```
