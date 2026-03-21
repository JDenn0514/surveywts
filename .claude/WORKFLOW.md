# surveywts Development Workflow

How the skills fit together in practice.

---

## Planning Arc
*Run once per release/feature to produce a spec and implementation plan.*

```
New session
    │
    ▼
┌──────────────┐
│/spec-reviewer│  Input:  spec file path (you provide)
│              │  Output: plans/spec-review-{name}.md
└──────┬───────┘
       │ "Start a new session with /spec-workflow"
       ▼
New session
    │
    ▼
┌──────────────────────────────────────────────────────────────────┐
│ /spec-workflow                                                    │
│                                                                  │
│  Stage 2 — Review                                                │
│    Reads plans/spec-review-{name}.md (if it exists)             │
│    Works through issues one by one; edits spec file immediately  │
│                                                                  │
│  Stage 3 — Implementation Plan                                   │
│    Produces checkbox PR map in plans/impl-{name}                │
│                                                                  │
│      - [ ] PR 1: `feature/branch-name` — one-sentence desc      │
│      - [ ] PR 2: `feature/branch-name` — one-sentence desc      │
│                                                                  │
│  Stage 4 — Decisions Log (conditional)                           │
│    Writes plans/claude-decisions-{name}.md ONLY if decisions     │
│    were made that are not already reflected in spec or plan      │
└──────────────────────────────────────────────────────────────────┘
```

---

## Implementation Loop
*Repeat until all checkboxes are `[x]`.*

```
New session
    │
    ▼
┌──────────────────────────────────────────────────────────────────┐
│ /r-implement                                                      │
│                                                                  │
│  1. Branch check                                                 │
│     ├─ on main?  → reads plan, proposes branch, confirm → create │
│     └─ on feature branch? → continue                            │
│                                                                  │
│  2. Read plan → find first - [ ] section (= session scope)       │
│     └─ all checked? → "Nothing left, nothing to do" → STOP      │
│                                                                  │
│  3. Ambiguity check                                              │
│     └─ spec unclear? → STOP and ask (never guess and implement)  │
│                                                                  │
│  4. Update plans/error-messages.md (new error classes go first)  │
│                                                                  │
│  5. Write R source  →  write tests  →  devtools::document()      │
│                                                                  │
│  6. devtools::test()  ─── fail ──→ fix → retry (max 3×)         │
│     │                              └─ still failing? STOP        │
│     ▼ pass                             (report what failed)      │
│  7. devtools::check() ─── fail ──→ fix → retry (max 3×)         │
│     │                              └─ still failing? STOP        │
│     ▼ pass                                                       │
│  8. Mark - [ ] → - [x] in implementation plan                   │
│                                                                  │
│  "Section complete. Start a new session with /commit-and-pr."    │
└──────────────────────────────────────────────────────────────────┘
       │
       ▼
New session
    │
    ▼
┌──────────────────────────────────────────────────────────────────┐
│ /commit-and-pr                                                    │
│                                                                  │
│  1. git branch / log / status                                    │
│     └─ on main? → STOP                                          │
│                                                                  │
│  2. Changelog entry                                              │
│     └─ missing? → create changelog/{name}/branch.md             │
│                                                                  │
│  3. Pre-flight: devtools::check() + devtools::test()             │
│     └─ fails? → STOP → "invoke /r-implement to fix"             │
│                                                                  │
│  4. Stage specific files + commit (Conventional Commits format)  │
│                                                                  │
│  5. Check for existing PR  →  exists? report URL + STOP         │
│                                                                  │
│  6. Show draft PR title + body → wait for approval               │
│                                                                  │
│  7. git push + gh pr create                                      │
│                                                                  │
│  8. Monitor CI (gh run watch)                                    │
│     └─ fails? → report + "invoke /r-implement to fix"           │
│                                                                  │
│  9. PR URL reported ✓                                            │
│     Reads plan → reports next unchecked section:                 │
│     "Next: PR N — description. New session → /r-implement."      │
└──────────────────────────────────────────────────────────────────┘
       │
       ▼
┌─────────────────────────┐
│ More - [ ] in plan?      ├── yes ──→ back to /r-implement (new session)
└─────────────────────────┘
       │ no
       ▼
     Done. All PRs merged. Release complete. Tag the release.
```

---

## Persistent State

The **implementation plan** is the single thread connecting every session.

```
plans/impl-{name}.md
├─ [x] PR 1: `feature/a` — merged
├─ [x] PR 2: `feature/b` — merged
├─ [ ] PR 3: `feature/c` ← r-implement picks this up next
└─ [ ] PR 4: `feature/d`
```

| File | Written by | Read by |
|------|------------|---------|
| `plans/spec-review-{name}.md` | `/spec-reviewer` | `/spec-workflow` Stage 2 |
| `plans/impl-{name}.md` | `/spec-workflow` Stage 3 | `/r-implement`, `/commit-and-pr` |
| `plans/claude-decisions-{name}.md` | `/spec-workflow` Stage 4 | future sessions |
| `plans/error-messages.md` | `/r-implement` | all sessions |
| `changelog/{name}/branch.md` | `/commit-and-pr` | `/commit-and-pr` (PR body) |
