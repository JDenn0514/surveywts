# chore(pipeline): cut pipeline token usage outside the rules files

**Date**: 2026-08-27
**Branch**: chore/pipeline-efficiency
**Phase**: Tooling (no package code)

## Changes

- Run the tester and shipper agents on Sonnet; builder, planner, and reviewer
  keep the session model
- Cap review loops at 3 passes: pass 1 is the only full-panel pass, later
  passes review only changed sections, with an early exit
- Stop agents and dispatch prompts from re-reading the auto-loaded rules
- Narrow the reviewer's shared-reference list from all files to the three it
  needs
- Cap builder full-suite runs at 2 per PR; route gate output through log files
  and read only filtered summaries
- Continue the SAME builder agent on a tester BLOCK instead of dispatching a
  fresh one
- Skip the duplicate post-batch test rerun when the audit's tree hash matches
- Add `.claude/scripts/run-gates.sh` — all validation gates in one background
  command with per-gate logs and one summary table
- Ban tester sleep-poll loops and pre-PR-state reconstruction; add baseline
  capture to `pipeline-simplified`
- Replace the shipper's CI poll loop with `ScheduleWakeup`
- Add `.claude/scripts/usage-profile.py` for before/after session measurement
- Add `.gitattributes` (LF for shell scripts) and `air.toml` (the formatter
  config the code style rule already referenced)

## Not included

Slimming the always-loaded rules files is deliberately excluded. An audit of
that work found 19 dropped rules and 1 widened prohibition, and the rules
also describe a `weighted_df` class that commits 9c8246f and 73de0f9 removed
from the package. Both are handled separately: first correct the rules against
the current source, then redesign them against skill-authoring practice.

## Files Modified

- `.claude/agents/{builder,tester,reviewer,shipper,planner}.md` — model
  tiering, gate batching, no rule re-reads, CI wakeups
- `.claude/skills/pipeline-{spec,implement,ship,simplified}/SKILL.md` —
  review caps, dispatch slimming, tree-hash skip, baseline capture
- `.claude/skills/pipeline-shared/references/{r-package-profile,artifact-schemas,pipeline-isolation}.md` —
  canonical runner, output discipline, audit tree hash, isolation wording
- `.claude/scripts/{run-gates.sh,covr-report.R,usage-profile.py}` — new
- `.gitattributes`, `air.toml` — new
