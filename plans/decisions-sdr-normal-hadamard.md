# Decisions — sdr-normal-hadamard

Decisions taken during the implementation-plan phase, 2026-09-04. The spec
phase's own decisions live in
`.surveywts-workspace/runs/2026-09-03-sdr-normal-hadamard/decisions-sdr-normal-hadamard.md`
and are not repeated here.

## Binding decisions carried in from the spec

| ID | Decision | Set by |
|---|---|---|
| D1 | Add `use_normal_hadamard` as a named argument, default `FALSE`. Existing behaviour does not change. | user, 2026-09-03 |
| D2 | Name the argument exactly `use_normal_hadamard`, matching svrep. | user, 2026-09-03 |

## Plan-phase decisions

| ID | Decision | Reason |
|---|---|---|
| P1 | One PR, matching the spec's `PR range: PR 1–1`. | The spec sets the range. Quality gate 16 is non-separable: the `NEWS.md` bullet, the retired test block and the forwarded argument are one claim. |
| P2 | Branch `fix/sdr-forward-use-normal-hadamard`, renamed from the local issue branch. | `core.md` §6 requires a type prefix. The branch has no upstream, so the rename costs nothing. Both `NEWS.md` bullets and the issue file the change under bug fixes, so `fix/` matches the record over `feat/`. |
| P3 | `plans/impl-backend-message-classes.md` and `plans/archive/doc-rewrite/2026-06-22-doc-rewrite-impl.md` stay unedited, though both carry text quality gates 10 and 16 forbid. | Each is the task log of a merged PR, and each quotes the text as it shipped then. A log is not a live claim. Rewriting one would falsify the record. |
| P4 | The changelog entry stays in the plan, though the spec's Architecture table does not list it. | `github-strategy.md:150` requires an entry before every PR. It is a repo process artifact, not functional scope. |
| P5 | The mechanical grep block skips when the source tree is absent, rather than reading the installed package. | Under `R CMD check` the tests run from the check directory and `R/`, `man/` and `NEWS.md` are two levels up and not present. `devtools::test()` is a profile gate the tester runs, so the check still executes on every gate run. |

## Plan-review findings, Pass 1 — all ten resolved

Every finding was a correction to the plan document. None changed the
approach, and none needed a decision from the user: each had one factually
correct answer, verified against the file it cites.

| # | Finding | Severity | Option taken |
|---|---|---|---|
| 1 | Task 27 claimed seven man pages change before Stage F edits the file that drives six of them | REQUIRED | A — task 27 confirms one page; task 30 keeps the seven-page check |
| 2 | Quality gates 12 and 18 had no verification task | REQUIRED | A — task 45 grew from three greps to five, one per gate |
| 3 | No task for the general no-warning assertion the test-spec requires | REQUIRED | A — task 43a added, plus a Track 2 bullet |
| 4 | Task 29 said four lines; the spec block is five, and the task did not say "verbatim" | REQUIRED | A — five lines, verbatim |
| 5 | Task 37 pinned three mean variances with no tolerance | REQUIRED | A — 1e-8 stated in the task and the Track 2 bullet |
| 6 | The documentation-check row count read eleven; the table has ten | REQUIRED | A — ten rows plus the inheriting-page prose check |
| 7 | No criterion held the seven existing error snapshots still | REQUIRED | A — named in task 12 and in a new Track 2 bullet |
| 8 | "Why one PR" claimed the formula fix cannot ship separately | SUGGESTION | B — fact 3 now states the spec's own reason, and keeps one PR |
| 9 | Tasks 20, 25 and 26 pointed at spec text without saying "verbatim" | SUGGESTION | A — added, with a note on the `\deqn` LaTeX |
| 10 | A citation read line 329; the definition is at 328 | SUGGESTION | A — corrected |

Finding 7 was raised by the orchestrator while verifying the lens reports,
not by a lens.

## Counter-findings — recorded so a later pass does not re-open them

1. Stage H failing until Stage I lands is a deliberate red test, on the same
   shape as Stage B into Stage C. Not a defect.
2. Quality gate 16 names two sites and there are three;
   `plans/spec-backend-message-classes.md` is the third. Task 50 rewrites it
   anyway, so the plan is right and the gate text is one short. No plan change
   follows.
3. `fix/` against `feat/` is defensible either way. See P2.

## Ship-phase decisions

| ID | Decision | Reason |
|---|---|---|
| S1 | The builder runs in the main checkout, not in an Agent-tool worktree. | The Agent tool cuts a worktree from `develop`, not from the current branch. Every pipeline artifact this PR needs — `plans/spec-sdr-normal-hadamard.md` among them — is uncommitted on `fix/sdr-forward-use-normal-hadamard`, so a worktree would not carry it. Worktree isolation guards against two builders writing the same file at once; this plan has one PR, so it guards nothing here. |
| S2 | The orchestrator renamed the branch (plan task 1) before dispatch. | The rename is a controller-level git operation. The shipper needs the final branch name, and the builder's task list starts at task 2. |
| S3 | The shipper commits on the existing `fix/sdr-forward-use-normal-hadamard` branch rather than cutting a fresh one from `develop`. | The work already sits on that branch. `shipper.md` Step 2 assumes the work is on local `develop`; that assumption does not hold here. |
| S4 | The builder may rewrite `plans/spec-backend-message-classes.md`, `plans/archive/replicate/decisions-replicate.md` and `plans/archive/replicate/spec-replicate.md`, though `builder.md` forbids writes to `plans/spec-*.md`. | The prohibition guards the builder's own contract. These three are records of earlier phases, and the plan's write surface names each one. The builder still may not touch `plans/spec-sdr-normal-hadamard.md`, `plans/test-spec-sdr-normal-hadamard.md`, `plans/impl-sdr-normal-hadamard.md`, `plans/decisions-sdr-normal-hadamard.md` or `status.md`. |
