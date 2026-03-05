---
name: spec-workflow
description: >
  Use this skill for any surveyverse spec work — creating a new phase spec,
  running an adversarial review, or resolving spec issues interactively. Trigger
  whenever the user says "draft spec", "review the spec", "resolve spec issues",
  "start planning", or references a phase number (e.g. "phase 1", "phase 0.5").
  Has three stages: Stage 1 (draft), Stage 2 (adversarial review), Stage 3
  (resolve + decisions log). After the spec is approved, move to
  /implementation-workflow.
---

# Surveyverse Spec Workflow

This skill governs spec work for surveywts.
Three stages, always in order:

1. **Stage 1 — Draft:** Write the spec sheet
2. **Stage 2 — Review:** Adversarial batch pass; saves all issues to a file
3. **Stage 3 — Resolve:** Interactively work through issues and log decisions

After the spec is approved, move to `/implementation-workflow`.

---

## Stage Routing

Determine which stage the user wants from context. If unclear, use the
`AskUserQuestion` tool:

```
question: "Which stage of the spec workflow do you want to run?"
header: "Stage"
multiSelect: false
options:
  - label: "Stage 1 — Draft the spec"
    description: "Write a new spec sheet from scratch."
  - label: "Stage 2 — Adversarial review"
    description: "Full batch pass over the spec; saves all issues to a file."
  - label: "Stage 3 — Resolve issues"
    description: "Interactively work through the review file issue by issue."
```

Then read the corresponding reference file before doing anything else:

| Stage | Reference file |
|---|---|
| 1 | `.claude/skills/spec-workflow/references/stage-1-draft.md` |
| 2 | `.claude/skills/spec-workflow/references/stage-2-review.md` |
| 3 | `.claude/skills/spec-workflow/references/stage-3-resolve.md` |

---

## Rules in Context

Every stage works alongside — never instead of — these rule files:

| Rule file | What it governs |
|---|---|
| `code-style.md` | Indentation, pipe, air formatter, S7 patterns, cli error structure, argument order, helper placement |
| `r-package-conventions.md` | `::` usage, NAMESPACE, roxygen2, `@return`, `@examples`, export policy |
| `surveywts-conventions.md` | Package-specific naming patterns, `@family` groups, return visibility, export policy |
| `testing-standards.md` | `test_that()` scope, 98% coverage, assertion patterns, data generators |
| `testing-surveywts.md` | `test_invariants()`, layer 1 vs layer 3 error testing, data generators, numerical tolerances |

When a spec decision touches one of these rules, cite the rule file. When the
spec is silent on something these rules already define, note that the rule is
authoritative — the spec doesn't need to repeat it.

---

## File Locations

The `{id}` matches the feature branch identifier (e.g., `phase-2`, `survey-srs`).

```
Spec:              plans/spec-{id}.md
Spec review:       plans/spec-review-{id}.md
Decisions log:     plans/decisions-{id}.md
```
