---
name: spec-workflow
description: >
  Use this skill for any surveyverse spec work — creating a new phase spec,
  running an adversarial review, or resolving spec issues interactively. Trigger
  whenever the user says "draft spec", "review the spec", "resolve spec issues",
  "start planning", or references a phase number (e.g. "phase 1", "phase 0.5").
  Five stages in order: Stage 1 (draft), Stage 2 (adversarial methodology review —
  survey statistics correctness), Stage 2 Resolve (lock methodology), Stage 3
  (adversarial spec review — code quality and completeness), Stage 4 (resolve +
  decisions log). After the spec is approved, move to /implementation-workflow.
---

# Surveyverse Spec Workflow

This skill governs spec work for surveywts.
Five stages, always in order:

1. **Stage 1 — Draft:** Write the spec sheet
2. **Stage 2 — Methodology Review:** Adversarial survey statistics pass; flags every
   methodological flaw before code is written *(conditional — self-assesses applicability)*
3. **Stage 2 Resolve — Lock Methodology:** Resolve all methodology issues; spec is
   methodology-locked after this
4. **Stage 3 — Spec Review:** Adversarial code-quality pass; flags gaps in contracts,
   test plans, engineering level, and API coherence (does the function behave
   as expected for every input type?)
5. **Stage 4 — Resolve:** Interactively work through all issues and log decisions

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
  - label: "Stage 2 — Methodology review"
    description: "Adversarial methodology pass: statistical correctness, algorithm validity, formula integrity. Saves all issues to a file. Self-assesses applicability — declares Stage 2 not applicable and skips to Stage 3 if the feature has no mathematical content."
  - label: "Stage 2 Resolve — Resolve methodology issues"
    description: "Work through the methodology review file issue by issue. Methodology-locks the spec after completion."
  - label: "Stage 3 — Adversarial spec review"
    description: "Full batch pass over code quality, contracts, test plans, engineering level, and API coherence. Saves all issues to a file."
  - label: "Stage 4 — Resolve issues"
    description: "Interactively work through all open issues (from Stage 2 and/or Stage 3) and log decisions."
```

Then read the corresponding reference file before doing anything else:

| Stage | Reference file |
|---|---|
| 1 | `.claude/skills/spec-workflow/references/stage-1-draft.md` |
| 2 | `.claude/skills/spec-workflow/references/stage-2-methodology.md` |
| 2 Resolve | `.claude/skills/spec-workflow/references/stage-2-resolve.md` |
| 3 | `.claude/skills/spec-workflow/references/stage-3-review.md` |
| 4 | `.claude/skills/spec-workflow/references/stage-4-resolve.md` |

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
Spec:                     plans/spec-{id}.md
Methodology review:       plans/spec-methodology-{id}.md
Spec review:              plans/spec-review-{id}.md
Decisions log:            plans/decisions-{id}.md
```
