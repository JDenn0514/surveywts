# Prompt: implement the rules redesign

**Created:** 2026-08-27
**Run in:** a fresh session, on branch `chore/rules-conservation-ledger`
**Follows:** `prompt-rules-redesign.md`, which produced `spec-rules-redesign.md`
**Produces:** the implementation — steps 4 through 11 of the plan

## Why this exists

The planning session measured the baseline, built the conservation ledger, and
got all eight design decisions approved. That session is large and its context
is spent on exploration the implementation does not need. Everything the
implementation needs is committed.

## The prompt

Copy everything below into a new session.

---

Continue the surveywts rules redesign. Planning is done, the conservation
baseline is built, and every design decision is approved. You are starting at
step 4 of the plan. Do not re-plan.

## Read these first, in this order

1. `plans/spec-rules-redesign.md` — the whole plan. Begin with the progress
   table and the "Start here, in a new session" block at the top.
2. **Section 13** of that file — the eight approved decisions, with the
   measurements behind them. Section 13 supersedes Section 12. Do not re-ask
   any of those questions.
3. **Section 10** — the order of work. You are at step 4.
4. **Section 8** — the conservation gate you must pass before any of this
   merges.

## Current state

Branch `chore/rules-conservation-ledger`, two commits on top of `45e8751`.
Not pushed. Working tree clean. Steps 0 through 3 are complete:

- `.claude/standards/` does not auto-load, in a main session or a subagent.
  Confirmed by two independent probes.
- `plans/ledger/before-*.tsv` holds **1,102 normative statements** enumerated
  from `45e8751` by nine agents, each blind to the plan and to every file but
  its own.
- `plans/ledger/literals.txt` holds **874 literals**.
  `bash .claude/scripts/check-literals.sh` passes on the untouched tree.
- All eight decisions are approved and recorded in Section 13.

## Three things you must not do

1. **Never regenerate `plans/ledger/before-*.tsv`.** It was built before any
   edit on purpose. Rebuilding it after the restructure would produce an
   inventory shaped by the very thing it exists to audit, which is how the
   previous attempt passed every check while dropping 19 rules. Read it and
   extend it; never recreate it.
2. **Never delete a literal to make `check-literals.sh` pass.** Every one of
   the 874 was confirmed present before admission, so the list passes today by
   construction. A failure later is real signal about a dropped value. Fix the
   restructure, not the list.
3. **Never re-run the auto-load canary.** Step 0 is settled.

## The order, and why it is the order

Step 4 has a hard sequence. Do not compress it.

1. Run `air format .` as **one standalone commit** that changes no logic. It
   touches 49 files: 24 of 34 in `R/`, 18 in `tests/`, 7 in `data-raw/`. This
   is the largest diff in the project and it will rewrite blame across most of
   the package. `code-style.md` already requires a reformat to be committed
   separately from a functional change.
2. Add gate 8 as `air format --check .` to `.claude/scripts/run-gates.sh` and
   to `r-package-profile.md`. Confirm it runs **green on `develop`** before
   going further.
3. Delete `.lintr`. It carries two bugs and has never run; see Section 13.2.
4. Only now delete the Group A prose (A1, A2, A5, A6). A3 and A4 stay as
   one-line rows — with `.lintr` gone, prose is their only enforcement, and
   that is deliberate.

Then steps 5 through 8: write `core.md` and the trimmed `CLAUDE.md`, move and
dedupe the seven standards files one commit per file, update the eight path
citations and the nine agent definitions, and apply the Section 7 and 13.5
through 13.8 skill and orphan decisions.

Run `bash .claude/scripts/check-literals.sh` after every commit. It is fast,
and it tells you which commit dropped something rather than leaving you to
bisect at the end.

## How to break this into PRs

This is too large for one PR. Suggested split, but use your judgment and tell
me if you disagree:

| PR | Contents |
|---|---|
| A | The current branch — the plan and the ledger |
| B | `air format .`, formatting only |
| C | Gate 8, and `.lintr` deleted |
| D | `core.md`, the trimmed `CLAUDE.md`, and the seven standards files |
| E | Agent definitions, path citations, skills, and orphans |
| F | Phase B and Phase C of the ledger, plus the reachability test |

Every PR targets `develop` per `github-strategy.md`.

## The gate before any of this merges

Section 8 is the merge gate, and it is not optional:

- **Phase B** — one agent per ledger fragment, different agents from the ones
  that built them, each mapping every row to PRESERVED, MOVED, DEDUPED,
  DELETED, ALTERED, or LOST with evidence. A matching heading is not evidence;
  quote the normative content.
- **Phase C** — any LOST row blocks. Any ALTERED row blocks. Any DELETED row
  without a matching approval in Section 13 blocks. Any DEDUPED row whose
  survivor the agent did not quote blocks.
- **Section 8.7** — the reachability test. Seven cases, three trials, two arms.
  If any role skips its Step 0 read on any trial, that role's material goes
  back into `core.md` rather than staying behind a read.

## Measurement

Section 9. Add an `--entry-fee` mode to `.claude/scripts/usage-profile.py` that
prints first-turn `cache_creation_input_tokens` per subagent. The baseline is
68,471 and 73,246, measured. `wc -l` is explicitly not a success metric — it is
the measure that passed while 19 rules went missing.

## Ask me rather than assuming

- If `air format .` changes anything that looks like more than formatting.
- If gate 8 does not go green on `develop` after the reformat.
- If a Section 13 decision turns out to conflict with something in the source.
- If Phase B returns any LOST or ALTERED row — bring it to me with the evidence
  rather than deciding whether it matters.
- Before you delete anything not already approved in Section 13.
