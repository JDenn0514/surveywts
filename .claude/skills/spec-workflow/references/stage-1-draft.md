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
      - label: "Current phase"
        description: "The next phase in the roadmap. See CLAUDE.md for current phase status."
      - label: "Later phase"
        description: "A subsequent phase beyond the current one."
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

Wait for the user to provide any referenced documents. If a `comprehension.md`
exists from Stage 0, read it before drafting. Read all provided context before
writing a single line of the spec.

Confirm the `{id}` with the user if not obvious from context. Default patterns:
"phase 1" → `phase-1`, "diagnostics" → `diagnostics`. Stage 1 produces TWO
output files:
- `plans/spec-{id}.md` — behavioral contract (what builder reads)
- `plans/test-spec-{id}.md` — validation scenarios (what tester reads)

Establish both file paths before writing anything.

---

## Two-artifact rule

Stage 1 always produces BOTH artifacts. They must be independently sufficient:
- `spec-{id}.md` contains NO test cases, NO tolerances, NO test datasets
- `test-spec-{id}.md` contains NO file paths from `R/`, NO internal helper names
- Neither file says "see the other document"

Think of them as two separate briefs for two different readers who will never
talk to each other: the builder implements from the spec; the tester validates
from the test-spec. They should arrive at the same behavior independently.

---

## `spec-{id}.md` structure

Model every spec on this structure. Required sections:

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

## `spec-{id}.md` writing rules

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
  `"surveywts_error_{snake_case}"` or `"surveywts_warning_{snake_case}"`.
- "TBD" and "to be determined" are not allowed — flag as **GAP** with
  `> ⚠️ GAP: [description]` so they're easy to find.
- Domain estimation and grouping behavior must be specified for every analysis
  function.
- Do NOT restate rules already defined in `code-style.md`,
  `r-package-conventions.md`, or `surveywts-conventions.md`. Reference them.

---

## `test-spec-{id}.md` structure

Required sections per `artifact-schemas.md §test-spec-{id}.md`:

| Section | Content |
|---------|---------|
| Reference oracle | Which package/function provides the ground truth (e.g., `survey::svymean`) |
| Datasets | Which datasets to use for each test scenario |
| Per-function test plan | Happy path, error paths, warning paths, edge cases, invariants |
| Tolerances | Default: point 1e-10, SE 1e-8, CI 1e-6. Deviations require justification. |
| Profile gates | Full list per `r-package-profile.md §Validation commands` |

### `test-spec-{id}.md` writing rules

- Every error class in the spec gets: `expect_error(class = ...)` AND
  `expect_snapshot(error = TRUE)` (dual pattern from `testing-standards.md §3`)
- Every edge case in the spec gets a test row
- `test_invariants(obj)` is the first assertion for every test that constructs
  a `weighted_df` or `survey_nonprob`
- If `comprehension.md` exists: every gotcha listed there gets a test row or
  an explicit "out of scope" note with justification
- No file paths from `R/`. No internal function names.

---

## After the Draft

Tell the user:

> "spec-{id}.md and test-spec-{id}.md are drafted. I expect there are gaps.
> Next steps:
> - Run Stage 2 (methodology review) in a new session — it will self-assess
>   whether the feature needs a statistical pass and will apply the Literature
>   Lens if a paper was attached.
> - Do not resolve anything until both reviews are complete."
