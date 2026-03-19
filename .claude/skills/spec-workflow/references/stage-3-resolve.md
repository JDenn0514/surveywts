# Stage 3: Resolve Issues + Log Decisions

## Before Starting

Check for a spec-review file at `plans/spec-review-{id}.md`.

**If the file exists:** Work through those issues in order. Do not do a fresh
review pass — the adversarial review is already done. Skip to the review mode
question below.

**If no file exists:** Tell the user:

> "No spec-review file found at `plans/spec-review-{id}.md`.
> Run Stage 2 first to get a saved issue list, then come back here to
> resolve them. Alternatively, confirm you want an informal review pass
> without a saved issue list."

---

## Choose a Batch Size

Use the `AskUserQuestion` tool:

```
question: "How many issues do you want to see at a time?"
header: "Batch size"
multiSelect: false
options:
  - label: "BIG — 4 issues at a time"
    description: "Present up to 4 issues, resolve all of them, then move to the next batch. Faster overall."
  - label: "SMALL — 1 issue at a time"
    description: "Present one issue, resolve it, then the next. Easier to stay focused."
```

Wait for the answer before presenting any issues.

---

## Working Through the Issues

Work through the issues **in the order they appear in the review file** —
do not re-group or re-sequence them.

Present a batch (4 or 1 depending on the chosen mode). For each issue in the
batch, show the issue text and options, then wait for the user's direction.
After the user has resolved all issues in the batch, ask:

> "Ready for the next batch?"

Then present the next batch. Do not apply fixes speculatively — wait for
explicit direction on each issue.

---

## Issue Format

For each issue (whether from the review file or found during this session):

```
**Issue [N]: [Short title]**

[Concrete description, with section/spec reference. Cite rule file if applicable,
e.g. "Violates code-style.md §3."]

Options:
- **[A]** [Description] — Effort: [low/medium/high], Risk: [low/medium/high],
  Impact: [what this affects], Maintenance: [ongoing burden]
- **[B]** [Description]
- **[C] Do nothing** — [consequences of not addressing this]

**Recommendation: [A/B/C]** — [Why, mapped to engineering-preferences.md.]

> Do you agree with option [letter], or would you prefer a different direction?
```

---

## Applying Fixes

When the user approves a direction, **edit the spec file immediately** — before
presenting the next issue. Do not batch fixes. After each edit, summarize what
changed in one sentence.

---

## Decisions Log

After all issues are resolved, write a decisions log entry if ANY of these
are true:

- You asked the user a question during this session
- You chose between meaningfully different approaches
- You made a scope or behavior assumption not obvious from the spec
- You deferred something to a later phase

**If every decision is already fully captured in the updated spec, skip the
log entry.**

The log lives at `plans/decisions-{id}.md`. This file is **append-only** —
never overwrite or delete existing entries. If the file exists, add the new
entry below all previous entries. Create the file with this header only if
it doesn't exist yet:

```markdown
# Decisions Log — [package] [id]

This file records planning decisions made during [id].
Each entry corresponds to one planning session.

---
```

Entry format:

```markdown
## [YYYY-MM-DD] — [Component or feature planned]

### Context

[1–2 sentences: what were we trying to figure out in this session?]

### Questions & Decisions

**Q: [The question that came up]**
- Options considered:
  - **[Option A]:** [description and trade-offs]
  - **[Option B]:** [description and trade-offs]
- **Decision:** [what was decided]
- **Rationale:** [why — mapped to project constraints and engineering preferences]

### Outcome

[1 sentence: what will be built as a result of this session]

---
```

Only log decisions — not implementation details already determined by the spec
or a rule file. If the answer was predetermined, there is no decision to log.
