# Workspace Layout

Per-request runtime artifacts live under `.surveywts-workspace/`, a gitignored
directory at the repo root. Durable documentation artifacts (specs, archived
plans) live in `plans/` and are committed.

## Directory structure

```
<repo-root>/
├── .surveywts-workspace/            (gitignored)
│   └── runs/
│       └── {request-id}/
│           ├── status.md            state transitions (append-only)
│           ├── request.md           user intent
│           ├── impact.md            scope assessment
│           ├── comprehension.md     optional — methods-heavy only
│           ├── decisions.md         HOLD/STOP resolutions log
│           ├── methods-review.md    Stage 2 methodology verdict (if applicable)
│           ├── spec-review.md       Stage 3 spec review verdict
│           ├── plan-review.md       implementation plan review verdict
│           └── prs/
│               └── pr-{n}-{slug}/
│                   ├── implementation.md   builder output
│                   ├── audit.md            tester output
│                   ├── review.md           reviewer output
│                   └── shipper.md          ship record
└── plans/                           (committed)
    ├── spec-{id}.md                 builder's input — behavioral contract
    ├── test-spec-{id}.md            tester's input — validation scenarios
    ├── impl-{id}.md                 PR map + acceptance criteria
    ├── spec-methodology-{id}.md     methodology review (if applicable)
    ├── spec-review-{id}.md          spec review output
    ├── plan-review-{id}.md          plan review output
    └── decisions-{id}.md            decisions log (durable copy)
```

## Request ID

Format: `YYYY-MM-DD-{slug}` where slug is short kebab-case. Example:
`2026-05-22-check-balance`. Stable across the whole lifecycle.

## Gitignore

Add to `.gitignore` at repo root:

```
.surveywts-workspace/
```

## Lifecycle

- **At request start**: orchestrating skill creates `runs/{id}/`, writes
  `request.md` + `impact.md` + `status.md` (with line `NEW`)
- **During work**: agents write outputs into the run directory. Status transitions
  appended to `status.md`.
- **At DONE**: orchestrating skill copies durable artifacts (`spec-{id}.md`,
  `test-spec-{id}.md`, `impl-{id}.md`, `decisions-{id}.md`) into `plans/`.
  Workspace entry kept for forensics.
- **Archiving**: after the change is released to `main`, the run directory may be
  moved to `archive/` per project convention (see CLAUDE.md).

## Per-PR subdirectories

`prs/pr-{n}-{slug}/` groups builder + tester + reviewer outputs for a single PR.
Required when the implementation plan has multiple PRs — each PR needs its own
artifact set so parallel dispatch doesn't collide.

## What NOT to put in workspace

- Production code (lives in `R/`, `tests/testthat/`)
- Roxygen docs (inline in source)
- `NEWS.md` entries (committed)
- CRAN submission docs (`cran-comments.md`, committed)
