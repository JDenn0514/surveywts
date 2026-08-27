---
name: pipeline-spec
description: >
  Orchestrates the full spec workflow for surveywts — from NEW request through
  SPEC_READY. Adds a state machine, Deep Comprehension Stage 0 (literature
  ingestion from attached papers/PDFs), and tracks state transitions. Wraps the
  existing spec-workflow stages. Use when a user says "start planning", "pipeline
  it", "new feature", "new spec", or mentions a new exported function, a
  statistical method, or attaches a journal article. The result is two
  independently-sufficient artifacts: spec-{id}.md (for builder) and
  test-spec-{id}.md (for tester).
---

# Skill: pipeline-spec

Drive a request from NEW → SPEC_READY. Produce `spec-{id}.md` (for builder)
and `test-spec-{id}.md` (for tester) that are independently sufficient.

## When to use

- Any new exported function
- Any change to numerical behavior (new estimator, modified formula)
- Any methodology-referencing change (attached papers, new variance approach)
- Any public API change

For small changes (≤3 files, no algorithmic change, no new export), offer
`pipeline-simplified` instead.

## Preconditions

- Current state = NEW (or first run — workspace not yet created)
- User has described what they want
- Any attached papers or PDFs are available

## Stage routing

| Stage | Purpose | Output | Next state |
|-------|---------|--------|------------|
| 0 | Deep Comprehension (if methods-heavy or paper attached) | `comprehension.md` | COMPREHENDED |
| 1 | Planner drafts `spec-{id}.md` + `test-spec-{id}.md` | two artifacts | DRAFT |
| 2 | Methodology review (5 lenses + literature lens) | `spec-methodology-{id}.md` | METHODS_REVIEWED |
| 2r | Resolve methods findings | updated spec + test-spec | DRAFT (loop) |
| 3 | Spec review (6 lenses) | `spec-review-{id}.md` | SPEC_REVIEWED |
| 3r | Resolve spec findings | updated spec + test-spec | DRAFT (loop) |
| 4 | Freeze & advance | status → SPEC_READY | SPEC_READY |

Stages 2 and 3 may loop with their resolve counterparts until verdict PASS.

## Setup (before Stage 0)

1. Determine `{id}` — infer from user's description (e.g., "diagnostics" →
   `diagnostics`, "check-balance" → `check-balance`). Ask if ambiguous.
2. Create workspace directory: `.surveywts-workspace/runs/{YYYY-MM-DD-id}/`
3. Write `request.md` from the user's description (per `artifact-schemas.md`).
4. Write `impact.md` — assess scope. Set smallness test result.
5. Append `NEW` to `status.md`.

## Stage 0 — Deep Comprehension

Determine if methods-heavy per `planner.md §Step 0 criteria`. Also check:
- Did the user attach papers, PDFs, or markdown files of journal articles?
- If yes, how many?

**If NOT methods-heavy AND no papers attached:** auto-transition to COMPREHENDED
with status line `(no methods — auto)`.

### Single paper (exactly 1 attached) or methods-heavy with no paper

1. Dispatch `planner` agent with prompt:
   > Run Step 0 (Deep Comprehension Protocol) only. Write `comprehension.md`
   > per `artifact-schemas.md`. If a paper was attached, read it in full before
   > writing. Do not draft spec-{id}.md or test-spec-{id}.md yet.
   > Paper/attachment: {path or content}

2. On return, verify `comprehension.md` is coherent: problem restated, formulas
   present with symbol bindings, ≥1 gotcha, ≥1 reference mapping, assumptions
   listed. If not coherent, re-dispatch with specific feedback.

3. Append `COMPREHENDED` to `status.md`.

### Multiple papers (2+ attached)

Reading multiple full papers inside one agent context crowds out the reasoning
needed for synthesis. Use parallel extraction first:

1. **Dispatch one `extractor` agent per paper in the same turn** (parallel).
   Each extractor reads one paper in full and writes
   `extraction-{slug}.md` to the workspace run directory. Derive the slug from
   the sanitized filename or a short paper title.

2. **Verify all extractions** before continuing. Each `extraction-{slug}.md`
   must contain: ≥1 formula with symbol bindings, ≥1 gotcha, ≥1 reference
   claim. Re-dispatch any extractor that produced a thin or incomplete result.

3. **Dispatch `planner` agent for synthesis**:
   > Run Step 0 (Deep Comprehension Protocol) — synthesis pass only. All papers
   > have been pre-read by extraction agents. Their outputs are at:
   > {list all extraction-{slug}.md paths}
   >
   > Read all extractions. Synthesize into `comprehension.md` per
   > `artifact-schemas.md`. Pay particular attention to:
   > - Conflicts between sources (different formulas for the same quantity)
   > - Assumptions that only one paper makes explicit
   > - Gotchas that appear in multiple sources (these are especially important)
   > - Citations: aggregate all Citation sections from the extractions into a
   >   single Citations section in `comprehension.md`. Preserve any [NOT FOUND]
   >   flags exactly — do not fill them in by inference.
   >
   > Do not re-read the original papers — work only from the extractions.

4. On return, verify `comprehension.md` using the same coherence checks as the
   single-paper path. Any cross-paper conflicts the planner could not resolve
   should be written to `decisions-{id}.md` as HOLDs for the user to resolve
   before Stage 1.

5. Append `COMPREHENDED` to `status.md`.

## Stage 1 — Draft

Invoke `spec-workflow` Stage 1 (see
`.claude/skills/spec-workflow/references/stage-1-draft.md`).

The key constraint: Stage 1 must now produce TWO artifacts:
- `plans/spec-{id}.md` — behavioral contract (builder's input)
- `plans/test-spec-{id}.md` — validation scenarios (tester's input)

Pass `comprehension.md` path to the planner if it exists.

Verify both artifacts exist and contain all required sections on return.

When verifying `spec-{id}.md` function contracts, apply 
`.claude/rules/function-documentation.md`: check that the tier (Utility / 
Standard / Algorithmic / Dispatcher) is identifiable and that the required 
`@param`, `@returns`, `@details`, `@section`, and `@examples` rules for 
that tier are reflected in the contract.

Append `DRAFT` to `status.md`.

## Review-loop budget (applies to Stages 2/2r and 3/3r)

Measured cost of an unbounded loop: one surveycore feature ran 7 review
passes, about $300 of API-equivalent usage. These rules cap the loop:

1. **Maximum 3 passes** per review stage. If findings are still open after
   pass 3, HOLD. Ask the user. Do not run pass 4.
2. **Pass 1 is the only full pass** — all lenses, the whole document.
3. **Pass 2 and later are delta passes.** Review only the sections the
   resolver changed, plus the specific findings you verify. The resolver
   lists the changed section headings at the top of its response. Do not
   re-read the whole document.
4. **Early exit.** A pass whose findings need no change to the artifact ends
   the loop. The verdict is PASS.

## Stage 2 — Methodology review (conditional)

Self-assess applicability using the trigger criteria in
`.claude/skills/spec-workflow/references/stage-2-methodology.md §Trigger
Condition`. Also check: is a paper/comprehension.md available?

If applicable:

Run the full methodology review per
`.claude/skills/spec-workflow/references/stage-2-methodology.md` — including
Lens 6 (Literature Lens) if a paper was attached. Save to
`plans/spec-methodology-{id}.md`.

If you fan the lenses out to subagents instead of running them inline, pass
`model: "sonnet"` on every lens dispatch. A lens agent scans one document
against one named criterion. It does not need the session model.

Aggregate findings with verdict:
- **PASS** — no BLOCKING, no REQUIRED-UNAMBIGUOUS findings
- **BLOCK** — any BLOCKING finding
- **HOLD** — any JUDGMENT_CALL finding (user decides)

If not applicable: append `(Stage 2 N/A — {reason})` to status.md.

## Stage 2r — Resolve methods findings

Two modes:
- **UNAMBIGUOUS batch**: Apply all unambiguous fixes to `spec-{id}.md`,
  `test-spec-{id}.md`, and `comprehension.md` in one pass. Re-run affected
  lenses only (mini-pass) to confirm.
- **JUDGMENT_CALL per-issue**: Ask user via `AskUserQuestion`, one at a time.
  Record resolution in `decisions-{id}.md`. Apply fix. Mini-pass the affected
  lens.

Loop until `spec-methodology-{id}.md` verdict = PASS.
Respect the Review-loop budget above.

## Stage 3 — Spec review

Invoke `.claude/skills/spec-workflow/references/stage-3-review.md`.

When applying Lens 3 (Contract Completeness), consult 
`.claude/rules/function-documentation.md` to determine which `@details`, 
`@section`, and `@examples` content is required for each function's tier.

Save to `plans/spec-review-{id}.md`. Aggregate verdict (PASS / BLOCK / HOLD).

## Stage 3r — Resolve spec findings

Invoke `.claude/skills/spec-workflow/references/stage-4-resolve.md`.

Use BIG mode (>8 findings) or SMALL mode (≤8 findings). Loop until
`spec-review-{id}.md` verdict = PASS. Respect the Review-loop budget above.

## Stage 4 — Freeze & advance

On PASS from both Stage 2 (if applicable) and Stage 3:

1. Verify `plans/spec-{id}.md` and `plans/test-spec-{id}.md` both exist and
   are finalized.
2. Copy `comprehension.md` to `plans/comprehension-{id}.md` if present.
3. Append `SPEC_READY` to `status.md`.
4. Return to user with summary:
   > "spec-{id}.md and test-spec-{id}.md are SPEC_READY. Next step:
   > run `/pipeline-implement` to draft the PR map."

## Signal handling

- **HOLD** from any stage → pause, write to `decisions-{id}.md`, ask user
  via `AskUserQuestion`, resume
- **BLOCK** from methodology review → route to Stage 2r

## References

- `.claude/skills/pipeline-shared/references/state-model.md`
- `.claude/skills/pipeline-shared/references/artifact-schemas.md`
- `.claude/skills/pipeline-shared/references/workspace-layout.md`
- `.claude/skills/pipeline-shared/references/signals.md`
- `.claude/skills/spec-workflow/references/stage-1-draft.md`
- `.claude/skills/spec-workflow/references/stage-2-methodology.md`
- `.claude/skills/spec-workflow/references/stage-3-review.md`
- `.claude/skills/spec-workflow/references/stage-4-resolve.md`
- `.claude/agents/planner.md`
- `.claude/agents/extractor.md`
- `.claude/rules/function-documentation.md` — documentation tier system and section rules used during Stage 1 verification and Stage 3 Lens 3
