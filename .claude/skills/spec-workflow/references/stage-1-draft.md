# Stage 1: Drafting a Spec Sheet

## Before Writing Anything

Use the `AskUserQuestion` tool to gather context before reading or writing
anything:

```
questions:
  - question: "Which feature or phase is this spec for?"
    header: "Phase"
    multiSelect: false
    options:
      - label: "Phase 0 — Initial implementation"
        description: "The first phase of surveyweights. See CLAUDE.md for current phase status."
      - label: "Later phase"
        description: "A subsequent phase building on Phase 0."
      - label: "Feature / bug fix"
        description: "A targeted feature or fix outside the main phase structure."

  - question: "Is there an existing roadmap or upstream spec to reference?"
    header: "Context docs"
    multiSelect: false
    options:
      - label: "Yes — I'll share the path or paste the content"
        description: "Provide the document before the draft begins."
      - label: "No roadmap exists yet"
        description: "Draft from scratch based on this conversation."

  - question: "Are there upstream phase specs that constrain this one?"
    header: "Upstream specs"
    multiSelect: false
    options:
      - label: "Yes — I'll share them"
        description: "Share before drafting so constraints are captured."
      - label: "No upstream constraints"
        description: "This phase is self-contained."
```

Wait for the user to provide any referenced documents. Read all provided
context before writing a single line of the spec.

---

## Spec Structure

Model every spec on the Phase 1 structure. Required sections:

| Section | Content |
|---|---|
| Header block | Version, date, status |
| Document Purpose | One paragraph: this is the source of truth |
| I. Scope | What this phase delivers (table), what it does NOT deliver, class/design support matrix |
| II. Architecture | File organization tree, shared helpers with signatures |
| III–N. Function specs | One section per function or component: signature, argument table, output contract, behavior rules, error table |
| Testing section | Per-function test categories, edge cases, invariant helpers |
| Quality Gates | Checklist of what "done" means — must be objectively verifiable |
| Integration section | Contracts with other packages (e.g. surveytidy) |

---

## Spec Writing Rules

- Every public function gets a full argument table: name, type, default,
  one-sentence description. Argument order must follow `code-style.md`:
  `x`/`data` first → required NSE → required scalar → optional NSE →
  optional scalar → `...`.
- Every function gets an explicit output contract: column names, types, and the
  S3 class hierarchy.
- Every result class or S3 class with a `print()` or `format()` method must
  include a verbatim console example showing exactly what the user sees —
  including any header line (e.g., `# A <survey_means> [5 × 4]`). "Prints as
  an ordinary tibble" or similar vague description is not sufficient; if that
  is the intentional design, state it explicitly and show the exact output.
- Every error condition is listed in a table with: error class, trigger
  condition, and the message template. Class names follow:
  `"surveyweights_error_{snake_case}"` or `"surveyweights_warning_{snake_case}"`.
- "TBD" and "to be determined" are not allowed — flag as **GAP** with
  `> ⚠️ GAP: [description]` so they're easy to find.
- Domain estimation and grouping behavior must be specified for every analysis
  function.
- Do NOT restate rules already defined in `code-style.md`,
  `r-package-conventions.md`, or `surveyweights-conventions.md`. Reference them.

---

## After the Draft

Tell the user:

> "This is a first draft. I expect there are gaps — run Stage 2 in a new
> session to get an adversarial review before we resolve anything."
