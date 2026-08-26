---
name: pipeline-simplified
description: >
  Fast-path workflow for small routine surveywts changes (≤3 files, no new export,
  no algorithmic change). Runs a lightweight planner-lite → builder → tester → shipper
  sequence without comprehension, without spec/test-spec split, without a separate
  reviewer. Tester is the quality gate. Escalates to full pipeline on repeated BLOCK
  or scope creep. Offer this when the user's request clearly meets the smallness
  criteria — a docstring fix, a parameter default, a test addition.
---

# Skill: pipeline-simplified

Drive a small change from NEW → DONE with minimal overhead. Sequence:
planner-lite → builder → tester → shipper. No separate reviewer. No pipeline
isolation between spec and test-spec (there is no split). Escalates to the full
pipeline if scope grows.

## When to offer

This skill is not invoked silently. Check smallness criteria before offering.

### Smallness criteria (ALL must hold)

| Criterion | Test |
|-----------|------|
| Few files | Change touches ≤3 files |
| No algorithmic change | No variance, estimator, or numerical method changed |
| No new exported function | The exported API surface does not grow |
| No public contract change | No existing function's arguments, return shape, or error classes change |
| No attached material | User did not upload papers, PDFs, or reference implementations |
| Routine pattern | Pattern is in the allowed list below |

### Routine patterns

- Fix a typo in a docstring or error message
- Bump version in DESCRIPTION
- Add `@export` tag
- Fix a broken `@examples`
- Add a parameter with a safe default to an existing function
- Fix an `@importFrom` by switching to `::`
- Add `.Rbuildignore` entry
- Add edge case test for already-implemented behavior

### NOT simplified

- New exported function
- Any variance or estimator change
- Any change referencing a paper or formula
- Any change expected to alter numerical output
- Changes spanning multiple domain areas

## Offer protocol

Use `AskUserQuestion`:

> This looks like a small change (≤3 files, no algorithmic change). Use simplified
> workflow?
>
> - **Simplified (faster)**: no spec/test-spec split, tester gates quality
> - **Full workflow**: pipeline-spec → pipeline-implement → pipeline-ship with
>   full builder/tester isolation

Default to Full when the smallness test is ambiguous.

## State chain

```
NEW → PLANNED → PIPELINES_COMPLETE → REVIEW_PASSED → DONE
```

## Step 1 — Planned (planner-lite)

Create workspace per `workspace-layout.md`. Write `request.md` with:
- Description of the change
- Acceptance criteria (observable outcomes)
- Affected files (write surface, ≤3)
- Expected validation outcome

Append `PLANNED` to `status.md`. Do NOT write `spec-{id}.md` or
`test-spec-{id}.md`.

## Step 2 — Builder

Dispatch `builder` WITHOUT worktree isolation (small change; overhead not justified):

```
Simplified workflow.
Request: {path to request.md}
Write surface: {files from request.md}
Acceptance criteria: {from request.md}
Read: .claude/agents/builder.md, r-package-profile.md (§Builder compliance rules) (rules auto-load — do not read .claude/rules/ again)
Exception: you MAY read test code in tests/testthat/ to update tests alongside code.
```

Builder implements, updates docs if needed, writes `implementation.md`.

## Step 3 — Tester

Dispatch `tester`:

```
Simplified workflow.
Request: {path to request.md with acceptance criteria}
Read: .claude/agents/tester.md, r-package-profile.md
Validate:
  1. Each acceptance criterion from request.md holds
  2. All profile gates pass (devtools::test, run_examples, R CMD check --as-cran, pkgdown if in scope, covr)
  3. CRAN cookbook scan clean on modified files
  4. No regression in tests that were passing before
Write audit.md with verdict PASS or BLOCK.
Exception: pipeline isolation relaxed — you may infer acceptance criteria from context.
```

BLOCK routing: re-dispatch builder with the BLOCK body. Max 3 cycles. On 4th,
escalate (see below).

With audit verdict=PASS:
- Append `PIPELINES_COMPLETE` to `status.md`
- Append `REVIEW_PASSED` to `status.md`

## Step 4 — Ship

Dispatch `shipper` (same as pipeline-ship §2f). Shipper still requires a PASS
quality gate — in simplified mode, this is the `audit.md` verdict=PASS.

Append `DONE` to `status.md`.

## Escalation to full workflow

If AT ANY POINT:
- Builder emits HOLD more than once
- Tester emits BLOCK more than twice on the same issue
- The change touches more than 3 files
- A CRAN cookbook violation requires a design-level fix
- Acceptance criteria depend on methodology the user didn't describe

Leader MUST escalate:

1. Preserve current work
2. Run `pipeline-spec` from Stage 0 (comprehension if now applicable)
3. Append to `status.md`: `ESCALATED — {reason}`

## Signal handling

- **HOLD** — any agent. Pause, ask user, resume OR escalate.
- **BLOCK** — tester only. Max 3 cycles; on 4th, escalate.
- **STOP** — not valid in simplified mode. If tester finds something STOP-worthy
  (e.g., coverage dropped below 95% on new code), that is an ESCALATION trigger.

## References

- `.claude/skills/pipeline-shared/references/state-model.md` §Simplified workflow
- `.claude/skills/pipeline-shared/references/signals.md`
- `.claude/skills/pipeline-shared/references/r-package-profile.md`
- `.claude/agents/planner.md`, `builder.md`, `tester.md`, `shipper.md`
