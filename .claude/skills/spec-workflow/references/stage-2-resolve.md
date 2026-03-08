# Stage 2 Resolve: Lock Methodology

## Contents
- Before Starting
- Two Categories of Issues
- Working Through the Issues
- Methodology Lock Rule
- Decisions Log
- After Resolution

---

## Before Starting

Check for `plans/spec-methodology-{id}.md`.

**If the file exists:** Work through those issues. Do not do a fresh review —
the methodology pass is already done.

**If no file exists:** Tell the user:

> "No methodology review file found at `plans/spec-methodology-{id}.md`.
> Run Stage 2 first to get the issue list, then come back here."

---

## Two Categories of Issues

Every issue in the methodology review file is marked with a resolution type.
Handle them differently:

**UNAMBIGUOUS** — There is one mathematically correct answer. Batch these
together: show all unambiguous fixes at once, explain each briefly, then ask
once for confirmation before editing the spec.

**JUDGMENT CALL** — Multiple statistically valid approaches exist. Present
these one at a time using `AskUserQuestion`. Show the options with their
statistical trade-offs before asking.

Work through BLOCKING issues first, then REQUIRED, then SUGGESTION.

---

## Working Through the Issues

### Unambiguous batch

Collect all UNAMBIGUOUS issues. Show them together:

```
The following issues have one correct fix. I'll apply them all if you confirm:

Issue [N]: [title] — [one-sentence fix]
Issue [N]: [title] — [one-sentence fix]
...
```

Then use `AskUserQuestion`:

```
question: "Apply all unambiguous fixes?"
header: "Unambiguous fixes"
multiSelect: false
options:
  - label: "Yes — apply all"
    description: "Edit the spec for each fix listed above."
  - label: "No — walk through them one at a time"
    description: "Treat each as a judgment call."
```

After confirmation, edit the spec for each fix immediately. Summarize changes
in one sentence per issue.

### Judgment calls

Present each JUDGMENT CALL issue individually. Show the issue text, then use
`AskUserQuestion`:

```
question: "Issue [N] — [title]: which approach?"
header: "Issue [N]"
multiSelect: false
options:
  - label: "Issue [N] — Option [A]: [short label] (Recommended)"
    description: "[statistical trade-offs]"
  - label: "Issue [N] — Option [B]: [short label]"
    description: "[trade-offs]"
  - label: "Issue [N] — Do nothing"
    description: "[consequences]"
```

Edit the spec immediately after each decision. Do not batch judgment call fixes.

---

## Methodology Lock Rule

After all issues are resolved, the spec is **methodology-locked**:

- Stage 2 does not reopen unless new statistical components are added to the
  spec (e.g., a new variance method, a new estimator, a new algorithmic step)
- Fixing a wrong formula discovered in Stage 3 or during implementation IS
  worth reopening Stage 2 for — treat it as a new mini-pass on the specific
  section
- Cosmetic changes, API design changes, and test plan additions do not reopen
  Stage 2

---

## Decisions Log

After all issues are resolved, append a decisions log entry to
`plans/decisions-{id}.md` if ANY judgment call was resolved. If every fix
was unambiguous, skip the log entry.

The log lives at `plans/decisions-{id}.md` and is **append-only**. Create it
with this header only if it does not exist yet:

```markdown
# Decisions Log — surveywts [id]

This file records planning decisions made during [id].
Each entry corresponds to one planning session.

---
```

Entry format:

```markdown
## [YYYY-MM-DD] — Methodology lock: [component]

### Context

[1–2 sentences: what methodology questions were resolved in this session.]

### Questions & Decisions

**Q: [The question that came up]**
- Options considered:
  - **[Option A]:** [description and trade-offs]
  - **[Option B]:** [description and trade-offs]
- **Decision:** [what was decided]
- **Rationale:** [why]

### Outcome

[1 sentence: what the spec now says as a result of this session]

---
```

---

## After Resolution

1. Update the spec version in the header block (bump the minor version, e.g.
   `1.0` → `1.1`).
2. End the session with:

   > "Methodology locked. {N} issues resolved ({X} unambiguous fixes, {Y}
   > judgment calls). Spec is at version [X.Y]. Start Stage 3 in a new session
   > to run the code/architecture review."
