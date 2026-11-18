# chore(pipeline): keep NEWS.md for the release merge; name changelog folders by feature

**Date**: 2026-11-18
**Branch**: docs/changelog-by-feature

## Changes

- `.claude/rules/core.md` §6 now says a PR records its change in
  `changelog/{feature}/{branch-name}.md` and never edits `NEWS.md`.
  `/merge-main` writes `NEWS.md` from the changelog files.
- Changelog folders are named by feature, not by phase. The skills that
  named `changelog/phase-{X}/` now name `changelog/{feature}/`, which is the
  layout the `changelog/` folder already uses.
- The changelog entry format replaces the `**Phase**` line with an optional
  `**Issue**` line.
- The pipeline docs no longer list `NEWS.md` as a file a PR writes.

## Files Modified

- `.claude/rules/core.md` — new §6 bullet on changelog files and `NEWS.md`.
- `.claude/skills/changelog-workflow.md` — feature folders, file naming, no
  `NEWS.md` edits, `**Issue**` in place of `**Phase**`.
- `.claude/skills/commit-and-pr/SKILL.md` — feature-folder path; do not edit
  `NEWS.md`.
- `.claude/skills/auto-ship/references/section-subagent.md` — feature-folder
  path; do not edit `NEWS.md`.
- `.claude/skills/implementation-workflow/references/stage-2-review.md` —
  feature-folder path.
- `.claude/skills/pipeline-implement/SKILL.md` — the file completeness lens
  checks for the changelog file, not `NEWS.md`.
- `.claude/skills/pipeline-shared/references/workspace-layout.md` — changelog
  entries in place of `NEWS.md` entries.
