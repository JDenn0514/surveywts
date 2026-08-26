# chore(pipeline): reduce token usage of the pipeline skill family

**Date**: 2026-08-26
**Branch**: chore/reduce-token-usage
**Phase**: Tooling (no package code)

## Changes

- Run the tester and shipper agents on Sonnet; builder, planner, and reviewer
  keep the session model. Add a conditional note for review-lens fan-out
  (surveywts runs lenses inline today).
- Cap review loops at 3 passes: pass 1 is the only full-panel pass, later
  passes are delta passes reviewing only changed sections, with an early exit
- Slim the always-loaded rules from 2,482 to 800 lines (`CLAUDE.md` +
  `.claude/rules/*.md`); move worked examples to five on-demand files in
  `.claude/references/`
- Stop agents and dispatch prompts from re-reading auto-loaded rules
- Cap builder full-suite runs at 2 per PR; route all gate output through log
  files with filtered summaries
- Continue the SAME builder agent on tester BLOCK instead of dispatching a
  fresh one
- Skip the duplicate post-batch test rerun in `pipeline-ship` when the audit's
  tree hash matches (surveywts had no `pkgcheck` gate to remove)
- Add `.claude/scripts/run-gates.sh` — all validation gates in one background
  command with per-gate logs and one summary table
- Ban tester sleep-poll loops and pre-PR-state reconstruction; add baseline
  capture to `pipeline-simplified` so the tester's Before column never
  requires reconstructing the pre-PR tree
- Add `.claude/scripts/usage-profile.py` for before/after session measurement
- Add `.gitattributes` to force LF line endings on shell scripts

## Files Modified

- `.claude/agents/{builder,tester,reviewer,shipper,planner}.md` — model
  tiering, gate batching, discipline rules
- `.claude/skills/pipeline-{spec,implement,ship,simplified}/SKILL.md` —
  review caps, dispatch slimming, tree-hash skip, baseline capture
- `.claude/skills/pipeline-shared/references/{r-package-profile,artifact-schemas,pipeline-isolation}.md` —
  gate table, canonical runner, audit schema, isolation table wording
- `.claude/rules/*.md` (all 8) — slimmed to decision tables with pointers
- `.claude/references/{code-style,function-documentation,github-strategy,r-package,testing}-detail.md` —
  new on-demand example files
- `.claude/scripts/{run-gates.sh,covr-report.R,usage-profile.py}` — new
  tooling, adapted from surveycore
- `CLAUDE.md`, `.gitattributes` — pointer line; LF for shell scripts
- `plans/implementation-plan-reduce-token-usage.md` — task checklist, marked
  complete
