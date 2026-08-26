---
name: pipeline-implement
description: >
  Orchestrates implementation plan drafting for surveywts after SPEC_READY.
  Dispatches planner to draft a PR map with per-PR acceptance criteria, runs a
  5-lens plan review, resolves findings, and advances to PLAN_READY. Produces
  impl-{id}.md that pipeline-ship executes PR-by-PR. Use when the user says
  "draft the plan", "implementation plan", "build the plan", or after
  pipeline-spec has reached SPEC_READY.
---

# Skill: pipeline-implement

Drive a request from SPEC_READY → PLAN_READY. Produce `impl-{id}.md` with a
PR map that `pipeline-ship` can execute PR-by-PR.

## Preconditions

- Current state = SPEC_READY
- `plans/spec-{id}.md` and `plans/test-spec-{id}.md` exist
- Any HOLDs from spec phase are resolved

## Stage routing

| Stage | Purpose | Output | Next state |
|-------|---------|--------|------------|
| 1 | Draft PR map | `impl-{id}.md` | DRAFT |
| 2 | Plan review (5 lenses) | `plan-review-{id}.md` | REVIEWED |
| 3 | Resolve findings | updated plan | DRAFT (loop) |
| 4 | Freeze & advance | status → PLAN_READY | PLAN_READY |

## Stage Routing (user prompt)

Determine which stage the user wants from context. If unclear:

```
question: "Which stage of the implementation workflow?"
header: "Stage"
options:
  - label: "Stage 1 — Draft the plan"
    description: "Write the PR map from the finalized spec."
  - label: "Stage 2 — Adversarial review"
    description: "Full batch pass over the plan; saves issues to a file."
  - label: "Stage 3 — Resolve issues"
    description: "Work through issues and log decisions."
```

Then read the relevant reference file from
`.claude/skills/implementation-workflow/references/`.

## Stage 1 — Draft

Invoke `.claude/skills/implementation-workflow/references/stage-1-draft.md`.

Key constraints for the PR map:
- Each PR lists both `spec-{id}.md` contract items AND `test-spec-{id}.md`
  test scenarios in its acceptance criteria — these are the two independent
  verification tracks that builder and tester will execute.
- Write surfaces of concurrent PRs must NOT overlap.
- Tasks are 2–5 minutes each with explicit TDD sub-steps.

Verify `impl-{id}.md` exists and contains all required sections. Append
`DRAFT` to `status.md`.

## Stage 2 — Plan review (5 lenses)

Run an adversarial pass per
`.claude/skills/implementation-workflow/references/stage-2-review.md`.

Run these 5 lenses:

1. **PR Granularity lens** — is each PR a single logical unit? Too large
   (>10 tasks, >5 files) or too small (1 task, 1 line)?
2. **Dependency Ordering lens** — does the PR order respect dependencies?
   Later PRs must not require changes to earlier PRs' tested behavior.
3. **Acceptance Criteria lens** — is every acceptance criterion observable?
   Does each criterion map to a row in `test-spec-{id}.md`?
4. **Spec Coverage lens** — does the union of all PR acceptance criteria
   cover every item in `spec-{id}.md §Function contracts`?
5. **File Completeness lens** — does the union of all write surfaces include
   every file implied by the spec (source, tests, NAMESPACE, man/, NEWS.md)?

If you fan the lenses out to subagents instead of running them inline, pass
`model: "sonnet"` on every lens dispatch. A lens agent scans one document
against one named criterion. It does not need the session model.

Aggregate into `plans/plan-review-{id}.md` with verdict PASS / BLOCK / HOLD.

## Stage 3 — Resolve

Invoke `.claude/skills/implementation-workflow/references/stage-3-resolve.md`.

Use BIG mode (>8 findings) or SMALL mode (≤8 findings). Loop until
`plan-review-{id}.md` verdict = PASS.

## Stage 4 — Freeze & advance

On PASS:

1. Verify `impl-{id}.md` is complete with a PR map.
2. Append `PLAN_READY` to `status.md`.
3. Return to user with summary:
   > "impl-{id}.md is PLAN_READY. Next step: run `/pipeline-ship` to execute
   > the PR sequence with builder + tester isolation."

## Common Shortcuts to Resist

| Rationalization | Why it fails |
|-----------------|-------------|
| "The plan is clear, Stage 2 would just nitpick" | Stage 2 catches missing error paths, wrong task order, and DRY violations. |
| "We can figure out edge cases during implementation" | Edge cases discovered in implementation are plan bugs. Resolve here. |
| "Some issues are minor, I'll resolve them later" | `decisions-{id}.md` must be populated before handing off. |

## References

- `.claude/skills/pipeline-shared/references/state-model.md`
- `.claude/skills/pipeline-shared/references/artifact-schemas.md`
- `.claude/skills/pipeline-shared/references/signals.md`
- `.claude/skills/implementation-workflow/references/stage-1-draft.md`
- `.claude/skills/implementation-workflow/references/stage-2-review.md`
- `.claude/skills/implementation-workflow/references/stage-3-resolve.md`
