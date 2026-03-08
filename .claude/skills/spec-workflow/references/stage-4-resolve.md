# Stage 4: Resolve Issues + Log Decisions

## Contents
- Before Starting
- Choose a Batch Size
- Working Through the Issues
- Issue Format
- Applying Fixes
- Decisions Log
- After Resolution

---

## Before Starting

Check for a spec-review file at `plans/spec-review-{id}.md`.

**If the file exists:** Work through those issues in order. Do not do a fresh
review pass — the adversarial review is already done.

Note: methodology issues (from `plans/spec-methodology-{id}.md`) should
already be resolved by Stage 2 Resolve and are not re-raised here. If a
code-level decision has introduced a new statistical error, flag it and
suggest running a targeted Stage 2 mini-pass on that section only.

**If no file exists:** Tell the user:

> "No spec-review file found at `plans/spec-review-{id}.md`.
> Run Stage 3 first to get a saved issue list, then come back here to
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

**In BIG mode (4 at a time):** Show all issues in the batch as markdown text
first, then use `AskUserQuestion` for each issue in the batch sequentially.
Apply fixes after all decisions in the batch are collected. After applying
each fix, check whether it materially changes the framing of any remaining
issues in the batch — if so, re-present the affected issue with updated
context before applying its fix. Then ask:
> "Ready for the next batch?"

**In SMALL mode (1 at a time):** Show the issue text, use `AskUserQuestion`,
apply the fix immediately, then move to the next issue.

Do not apply fixes speculatively — wait for the `AskUserQuestion` response
on each issue before editing the spec.

---

## Issue Format

Show each issue as markdown, then immediately use `AskUserQuestion`. The
**recommended option must be first**. Every option **must be labeled** with
the issue number and letter so the user always knows what they're selecting.

Present the issue text:

```
**Issue [N]: [Short title]**
Severity: BLOCKING | REQUIRED | SUGGESTION
[Rule violated, e.g. "Violates code-style.md §3."]

[Concrete description, with section/spec reference.]

Options:
- **[A]** [Description] — Effort: [low/medium/high], Risk: [low/medium/high],
  Impact: [what this affects], Maintenance: [ongoing burden]
- **[B]** [Description]
- **[C] Do nothing** — [consequences of not addressing this]

**Recommendation: Option [A/B/C]** — [Why, mapped to engineering-preferences.md.]
```

Then call AskUserQuestion:

```
question: "Issue [N] — [Short title]: which option?"
header: "Issue [N]"
multiSelect: false
options:
  - label: "Issue [N] — Option [Rec]: [short label] (Recommended)"
    description: "[effort/risk/impact/maintenance summary]"
  - label: "Issue [N] — Option [Alt]: [short label]"
    description: "[trade-offs]"
  - label: "Issue [N] — Option C: Do nothing"
    description: "[consequences]"
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
# Decisions Log — surveywts [id]

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

---

## After Resolution

1. Update the spec version in the header block.
2. End the session with:

   > "Code review resolved. {N} issues resolved ({X} blocking, {Y} required,
   > {Z} suggestions). Spec at version [X.Y] is approved. Start
   > `/implementation-workflow` in a new session to build the implementation plan."
