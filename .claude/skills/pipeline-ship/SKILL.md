---
name: pipeline-ship
description: >
  Drives an implementation plan end-to-end through pipelined agents with hard
  information barriers. For each PR: dispatch builder (reads spec-{id}.md only)
  in a worktree, dispatch tester (reads test-spec-{id}.md only) after merge-back,
  dispatch reviewer (all artifacts) for convergence verdict, dispatch shipper for
  branch/commit/PR/CI/merge. The builder and tester never see each other's inputs
  — independent convergence. Use when the user says "ship it", "run pipeline-ship",
  "execute the plan", or after pipeline-implement has reached PLAN_READY.
---

# Skill: pipeline-ship

Drive a request from PLAN_READY → DONE by executing each PR in `impl-{id}.md`
through the pipelined agent sequence: builder → tester → reviewer → shipper.

## Preconditions

- Current state = PLAN_READY
- `impl-{id}.md` exists with a PR map
- `plans/spec-{id}.md` exists (builder's input)
- `plans/test-spec-{id}.md` exists (tester's input)
- Working tree is clean
- `develop` branch is up-to-date with origin

## High-level flow

```
PLAN_READY
   │
   ▼
baseline check (tests + R CMD check on current develop)
   │
   ▼
for each PR (sequential or parallel per topology):
   │
   ├─ builder (worktree, reads spec-{id}.md only) → implementation.md
   │     │
   │     ▼
   │   merge-back to main checkout
   │     │
   │     ▼
   ├─ tester (merged checkout, reads test-spec-{id}.md only) → audit.md
   │     │
   │     ├─ verdict=BLOCK → re-dispatch builder (max 3 cycles) → HOLD on 4th
   │     └─ verdict=PASS → continue
   │
   ├─ reviewer (all artifacts) → review.md
   │     │
   │     ├─ verdict=BLOCK → re-dispatch builder or pipeline-spec
   │     ├─ verdict=STOP → HOLD pipeline; user override required
   │     └─ verdict=PASS → continue
   │
   └─ shipper → PR, CI, merge → plan[x]

all PRs DONE → status → DONE
```

## Step 0 — Baseline check

Before any PR starts:

```bash
Rscript -e 'devtools::test()'
Rscript -e 'devtools::check()'
```

If either fails, HOLD classification `dirty-baseline`. Do not begin.

Cache baseline results (tests passing count, coverage %) for Before/After
comparisons in each audit.

## Step 1 — Topology analysis

Parse `impl-{id}.md` PR map. For each PR, extract the Files touched write
surface.

Build a dependency graph:
- PR A blocks PR B if A's write surface overlaps B's
- Otherwise, A and B can dispatch in parallel

Output: a sequence of "batches". Each batch contains PRs that can dispatch
in parallel.

## Step 2 — Dispatch loop

For each batch in order:

### 2a. Dispatch builders (parallel, with worktree isolation)

For each PR in the batch, dispatch `builder` agent with `isolation: "worktree"`:

```
PR: {number} — {slug}
Spec: plans/spec-{id}.md
Write surface: {exact files from impl-{id}.md}
Tasks: {tasks from impl-{id}.md for this PR}
Acceptance criteria: {from impl-{id}.md}
Read: .claude/agents/builder.md, pipeline-shared/references/r-package-profile.md
(builder.md Step 0 lists the standards files to read — do not re-list them here)
Key documentation rule: `.claude/standards/function-documentation.md` — tier system, `@returns` (not `@return`), named `@section` requirements, `@examples` package-data rule for all exported functions
Comprehension (if exists): plans/comprehension-{id}.md

DO NOT read test-spec-{id}.md. DO NOT read any other PR's implementation.md.
```

Each builder returns `implementation.md` with write surface changes.

### 2b. Merge-back, cleanup, and dispatch testers (parallel)

After all builders in the batch return:

1. Verify each worktree merged back cleanly (no conflicts)
2. Verify each `implementation.md` write surface matches the plan
3. Remove each builder's worktree — it has served its purpose and keeping it
   causes confusion about what is and isn't merged:
   ```bash
   git worktree unlock <path>   # unlock if locked (agent may have locked it)
   git worktree remove <path>   # fails if uncommitted changes remain
   # If remove fails due to uncommitted changes, all listed files should
   # already be on develop via the PR — force-remove is safe:
   git worktree remove --force <path>
   git worktree prune           # clean up stale refs
   ```

Then dispatch `tester` for each PR (NOT in a worktree — tester reads merged checkout).

**Inject the tester's standards into the dispatch prompt.** The reachability
test showed the tester does not perform its Step 0 reads, so YOU perform them
at dispatch: read `.claude/standards/r-package-conventions.md`,
`.claude/standards/testing-standards.md`, and
`.claude/standards/testing-surveywts.md`, and paste their FULL contents into
the dispatch prompt under the heading shown below. Do not summarize them and
do not substitute a pointer — the paste is what puts the rules in the
tester's context.

```
PR: {number} — {slug}
Test-spec: plans/test-spec-{id}.md
Baseline results: {from step 0}
Read: pipeline-shared/references/r-package-profile.md

DO NOT read spec-{id}.md. DO NOT read implementation.md.

## Your standards (full text — these are in your context; no Step 0 Reads needed)

{full contents of the three standards files}
```

Each tester returns `audit.md` with verdict PASS or BLOCK.

### 2c. BLOCK handling

If an audit returns BLOCK:

1. Increment BLOCK counter for that PR
2. If the counter is ≤ 3: send the BLOCK body — not the full `audit.md`, not
   `test-spec-{id}.md`, per `signals.md` — to the SAME builder agent with
   `SendMessage`. It keeps its context and its warm cache. The message MUST
   state: "Your worktree was merged back and removed. Work in the main
   checkout at {path}. Run `git status` there before you edit." Dispatch a
   fresh builder only when the original agent is gone, for example after a
   session restart. Pass the BLOCK body in the dispatch prompt.
3. If counter = 4: emit HOLD classification `repeated-block`; pause for user

### 2d. Dispatch reviewer (sequential per PR, after its audit passes)

For each PR with audit verdict=PASS:

```
PR: {number} — {slug}
All artifacts: plans/spec-{id}.md, plans/test-spec-{id}.md,
               plans/comprehension-{id}.md (if present),
               impl-{id}.md, implementation.md, audit.md
Read: .claude/agents/reviewer.md, pipeline-shared/references/signals.md, artifact-schemas.md, r-package-profile.md
```

Reviewer returns `review.md` with verdict PASS / BLOCK / STOP.

### 2e. Review verdict handling

- **PASS** → proceed to shipper
- **BLOCK** → re-dispatch the agent reviewer identified (builder or planner).
  Increment BLOCK counter. Max 3 cycles per PR.
- **STOP** → pipeline halts. Write HOLD to `decisions-{id}.md`. User must
  resolve before resume.

### 2f. Dispatch shipper

For each PR with review verdict=PASS:

```
PR: {number} — {slug}
Review: {path to review.md}
Plan: impl-{id}.md
Read: .claude/agents/shipper.md
```

Shipper opens the PR, monitors CI, merges, marks `[x]` in the plan.

## Step 3 — Post-batch verification

After every shipper in a batch returns:

Skip check first. Compare `git rev-parse 'HEAD^{tree}'` on updated `develop`
against the `Tree:` line in this batch's `audit.md`. If every audit in the
batch matches, the tester already ran these tests on this exact tree — log
"post-batch check: SKIPPED — tree unchanged since audit" and go on. If any
hash differs, or an `audit.md` has no `Tree:` line, run the commands below.

1. `git checkout develop && git pull`
2. `Rscript -e 'devtools::test()'` on updated develop
3. If any test fails that was passing in the baseline → HOLD classification
   `post-merge-regression`

Only then proceed to the next batch.

## Step 4 — Advance to DONE

After all batches complete and all plan checkboxes are `[x]`:

1. Prune any remaining worktree artifacts (belt-and-suspenders in case a batch's
   cleanup was skipped due to an error path):
   ```bash
   git worktree list   # identify any non-main worktrees still present
   # for each stale worktree:
   git worktree unlock <path> 2>/dev/null || true
   git worktree remove --force <path>
   git worktree prune
   ```
2. Append `PIPELINES_COMPLETE` to `status.md`
3. Append `REVIEW_PASSED` to `status.md`
4. Append `DONE` to `status.md`
5. Archive plan artifacts — move all files specific to this pipeline ID into
   a dedicated archive folder:
   ```bash
   mkdir -p plans/archive/{id}
   mv plans/*-{id}.md plans/archive/{id}/
   mv plans/status.md plans/archive/{id}/ 2>/dev/null || true
   mv plans/impact.md plans/archive/{id}/ 2>/dev/null || true
   ```
   This moves `spec-{id}.md`, `test-spec-{id}.md`, `impl-{id}.md`,
   `decisions-{id}.md`, `comprehension-{id}.md` (if present), `status.md`,
   and `impact.md` (if present) out of `plans/` into `plans/archive/{id}/`.
6. Return to user with summary: PRs merged, coverage delta, any STOPs encountered

## Signal handling

- **HOLD** — any stage. Pause, write to `decisions-{id}.md`, ask user.
- **BLOCK** (from tester) — route back to builder. Max 3 per PR.
- **BLOCK** (from reviewer) — route back to builder OR `pipeline-spec` depending
  on classification. Max 3 per PR.
- **STOP** (from reviewer) — halt pipeline. HOLD with full STOP body. User must
  override in `decisions-{id}.md` to resume.

## Must not

- Dispatch a tester before the corresponding builder's worktree has merged back
- Dispatch a reviewer before the corresponding tester's `audit.md` is written
- Dispatch a shipper without `review.md` verdict=PASS
- Dispatch two builders in parallel on overlapping write surfaces
- Advance to DONE while any PR checkbox is `[ ]`

## References

- `.claude/skills/pipeline-shared/references/state-model.md`
- `.claude/skills/pipeline-shared/references/signals.md`
- `.claude/skills/pipeline-shared/references/pipeline-isolation.md`
- `.claude/skills/pipeline-shared/references/artifact-schemas.md`
- `.claude/skills/pipeline-shared/references/r-package-profile.md`
- `.claude/skills/pipeline-shared/references/workspace-layout.md`
- `.claude/agents/builder.md`, `tester.md`, `reviewer.md`, `shipper.md`
