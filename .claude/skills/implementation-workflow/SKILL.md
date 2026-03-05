---
name: implementation-workflow
description: >
  Use this skill for implementation plan work — drafting a plan from a finalized
  spec, running an adversarial review of the plan, or resolving plan issues
  interactively. Trigger when the user says "build the implementation plan",
  "draft the plan", "review the plan", "resolve plan issues", or "implementation
  plan". Always runs after spec-workflow is complete. Has three stages: Stage 1
  (draft plan), Stage 2 (adversarial review), Stage 3 (resolve + decisions log).
  After the plan is approved, hand off to /r-implement.
---

# Surveyverse Implementation Workflow

This skill governs implementation plan work for surveywts
packages). Three stages, always in order:

1. **Stage 1 — Draft:** Write the implementation plan from the finalized spec
2. **Stage 2 — Review:** Adversarial batch pass; saves all issues to a file
3. **Stage 3 — Resolve:** Interactively work through issues and log decisions

After the plan is approved, hand off to `/r-implement`.

---

## Stage Routing

Determine which stage the user wants from context. If unclear, use the
`AskUserQuestion` tool:

```
question: "Which stage of the implementation workflow do you want to run?"
header: "Stage"
multiSelect: false
options:
  - label: "Stage 1 — Draft the plan"
    description: "Write the implementation plan from the finalized spec."
  - label: "Stage 2 — Adversarial review"
    description: "Full batch pass over the plan; saves all issues to a file."
  - label: "Stage 3 — Resolve issues"
    description: "Interactively work through the review file issue by issue."
```

Then read the corresponding reference file before doing anything else:

| Stage | Reference file |
|---|---|
| 1 | `.claude/skills/implementation-workflow/references/stage-1-draft.md` |
| 2 | `.claude/skills/implementation-workflow/references/stage-2-review.md` |
| 3 | `.claude/skills/implementation-workflow/references/stage-3-resolve.md` |

---

## Rules in Context

Every stage works alongside — never instead of — these rule files:

| Rule file | What it governs |
|---|---|
| `code-style.md` | Indentation, pipe, air formatter, S7 patterns, cli error structure, argument order, helper placement |
| `r-package-conventions.md` | `::` usage, NAMESPACE, roxygen2, `@return`, `@examples`, export policy |
| `surveywts-conventions.md` | Naming patterns (`get_*`, `extract_*`, `set_*`), `@family`, return visibility, haven handling |
| `testing-standards.md` | `test_that()` scope, 98% coverage, assertion patterns, data generators |
| `testing-surveywts.md` | `test_invariants()`, layer 1 vs layer 3 error testing, `make_survey_data()`, numerical tolerances |
| `github-strategy.md` | Branch naming, PR granularity, commit format, merge strategy |

---

## File Locations

The `{id}` matches the feature branch identifier (e.g., `phase-2`, `survey-srs`).

```
Implementation plan:  plans/impl-{id}.md
Plan review:          plans/plan-review-{id}.md
Decisions log:        plans/decisions-{id}.md
```
