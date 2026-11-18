# Changelog Workflow

This is a reference document, not an invocable skill. It defines the canonical
changelog format enforced by `commit-and-pr`.

---

## Location and Timing

```
Location:  changelog/{feature}/{branch-name}.md
Timing:    Created LAST on the branch, BEFORE opening the PR
Populated: From git log develop..HEAD --oneline
```

- `{feature}` is a short kebab-case name for the feature or fix, for example
  `fpc-applied` or `replicate-count-totals`. PRs for the same feature share
  one folder. Do not use phase folders (`phase-{X}`).
- `{branch-name}` is the branch name with `/` replaced by `-`. The branch
  `fix/replicate-count-totals` gives `fix-replicate-count-totals.md`.

The changelog file is the only record of the change in the PR. Do not edit
`NEWS.md` in a PR. `/merge-main` reads every changelog file added since the
last release tag and writes the `NEWS.md` section from them.

---

## Entry Format

```markdown
# [type]([scope]): [description]

**Date**: YYYY-MM-DD
**Branch**: feature/[name]
**Issue**: JDenn0514/surveywts#[number] (if there is one)

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

1. File must exist at `changelog/{feature}/{branch-name}.md`
2. File must not be empty or a stub (no `<!-- TODO -->` placeholders)
3. `## Changes` section must have at least one bullet
4. `## Files Modified` section must list at least one file
5. `**Date**` must be a real date (not a placeholder)

---

## Example

For a branch `feature/variance-twophase`, the file is
`changelog/variance-twophase/feature-variance-twophase.md`:

```markdown
# feat(variance): implement two-phase Taylor variance estimation

**Date**: 2026-02-23
**Branch**: feature/variance-twophase

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
