# chore(pipeline): redesign the rules tree behind a conservation ledger

**Date**: 2026-08-28
**Branch**: chore/rules-conservation-ledger
**Phase**: Tooling (rules redesign, plans/spec-rules-redesign.md)

## Changes

- Reformatted the whole package with `air format .` as one standalone commit,
  proven formatting-only three ways (token stream, comment tokens, interleaved
  order); restored three `# nocov` markers the reformat moved.
- Added gate 8, `air format --check .`, to `run-gates.sh` and the profile;
  deleted the never-parsed `.lintr`.
- Cut the always-loaded tier from ~24,700 tokens (CLAUDE.md + 8 rules files)
  to ~1,470 (`CLAUDE.md` 40 lines + `.claude/rules/core.md` 94). The 8 files
  moved to `.claude/standards/`, read per role.
- Deleted the approved Section 5 rows (A1, A2, A5, A6, B1–B7, C1, C2) and
  deduped 26 register clusters, every removal traced to an approval or a
  quoted survivor. Portable files keep their copies when the survivor does
  not travel.
- Built the conservation machinery: pinned 1,102-row inventory, a literal
  gate with an approved-retirement register (`check-literals.sh` runs after
  every commit), a Phase B blind audit of all 1,102 rows, and a Phase C
  reconciliation — PASS, 0 LOST, 2 waived instructed ALTERED rows. The audit
  caught and restored 2 real losses and a narrowed prohibition.
- Rewrote the 9 agent definitions with first-tool-call Step 0 read lists and
  a `Standards read:` output contract; reachability-tested 7 roles × 3
  trials. The tester never reads, so pipeline-ship and pipeline-simplified
  now inject its standards into the dispatch prompt (verified 3/3).
- Applied the skill decisions: release family slash-only, four duplicate
  skills and two orphans removed, `reference-map.yaml` repaired to 66/66
  resolving paths.
- Added `--entry-fee` to `usage-profile.py`; pipeline-role entry fee dropped
  from 68,471/73,246 to 47,881–51,559.

## Files Modified

- `R/` (24 files), `tests/` (18), `data-raw/` (7) — air reformat only; token
  stream byte-identical
- `R/utils.R`, `R/jackknife-dagjk-utils.R` — `# nocov` markers restored
- `CLAUDE.md`, `.claude/rules/core.md` — the new always-loaded tier
- `.claude/standards/*.md` (8 files) — moved from `.claude/rules/`, deduped
- `.claude/agents/*.md` (9 files) — Step 0 read lists, output contracts
- `.claude/skills/` — dispatch-prompt fixes, tester standards injection,
  release family flags, removals per decisions 13.5–13.7
- `.claude/reference-map.yaml` — sibling-relative paths, 66/66 resolve
- `.claude/scripts/run-gates.sh`, `literals.py`, `check-literals.sh`,
  `usage-profile.py` — gate 8, retirement register, entry-fee mode
- `plans/ledger/` — before-inventory (pinned), literals, retirements,
  Phase B mapping, waivers, change records
- `plans/spec-rules-redesign.md` — progress table through step 10
- `.lintr` — deleted
