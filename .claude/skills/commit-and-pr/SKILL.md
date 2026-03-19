---
name: commit-and-pr
description: >
  Use when work is complete and needs to be committed and submitted as a pull
  request. Trigger when the user says "commit", "make a PR", "open PR", "submit
  this work", "PR time", or "commit and PR". CRITICAL: This skill does NOT write
  or edit R source files, test files, or any source code. If code changes are
  needed before the PR, use r-implement first.
---

# Commit and PR Skill

**Announce at start:** "Running commit-and-pr skill."

## HARD CONSTRAINT — READ THIS FIRST

**YOU ARE A COMMIT/PR AGENT.**

You CANNOT write, edit, or create:
- `.R` source files
- `.R` test files
- Any other source code

If you notice code that should change, add a `TODO:` note to the PR body
describing the issue, and report it to the user. Do NOT touch the code.

**The ONLY files you may create or edit:**
- `changelog/phase-{X}/{branch-name}.md` — the changelog entry for this branch

If you find yourself about to use the Edit or Write tool on a `.R` file,
**stop immediately and tell the user what you found**. Ask them whether to
invoke `r-implement` to address it, or note it as a TODO in the PR.

---

## Session Recovery — Check This Before Starting

Call `TaskList` first. If a "PR:" task already exists in `in_progress`:

| Task state | What to do |
|---|---|
| PR task `in_progress`, no CI task | Check if PR exists (`gh pr view`); resume from Step 5 if yes, Step 2 if no |
| PR task `in_progress`, CI task `in_progress` | Resume CI monitoring (Step 8) using `runId` from task metadata |
| PR task `in_progress`, CI task `completed` with status `failed` | Reproduce failure locally, produce handoff block (Step 9), ask user to invoke `r-implement` |
| PR task `completed` | Report PR URL and done message — nothing to do |
| No tasks | Fresh start — proceed to Step 1 |

---

## Step 1: Orientation

Run these first, before anything else:

```bash
git branch --show-current
git log develop..HEAD --oneline
git status
```

**If on `main` or `develop`: STOP.** Inform the user that implementation work
must be on a feature branch cut from `develop`. Do not proceed.

Create the main tracking task:

```
TaskCreate:
  subject:    "PR: [branch-name]"
  description: "Commit and open PR for [branch-name]."
  activeForm: "Preparing PR for [branch-name]"

TaskUpdate:
  status: in_progress
```

---

## Step 2: Changelog Entry (REQUIRED before any commit)

Read `.claude/skills/changelog-workflow.md` for the canonical format.

The changelog file lives at: `changelog/phase-{X}/{branch-name}.md`

Steps:
1. Determine the phase from the branch name (e.g., `feature/calibration-core`
   suggests Phase 0) — ask the user if unclear
2. Check if `changelog/phase-{X}/{branch-name}.md` exists
3. **If it does not exist:** create it following `changelog-workflow.md`,
   using `git log develop..HEAD --oneline` to populate the `## Changes` section
4. **If it exists:** verify it is populated — not empty, no `<!-- TODO -->`
   placeholders, `## Changes` has at least one real bullet

**If the changelog entry is missing or empty, STOP and report:**

```
No changelog entry found for this branch.

Expected: changelog/phase-{X}/{branch-name}.md

The changelog entry must be created before opening the PR.
```

Do not proceed to pre-flight or commits until the changelog entry exists and
is populated.

---

## Step 3: Pre-flight Checks

Run AFTER the changelog entry is confirmed:

```bash
Rscript -e "devtools::check()"
Rscript -e "devtools::test()"
```

**If either fails: STOP.** Inform the user of the failure. Do not proceed to
commits. Ask the user to invoke `r-implement` to fix the issue, then re-invoke
`commit-and-pr`.

Required results:
- `devtools::check()` — 0 errors, 0 warnings, ≤2 notes
- `devtools::test()` — no failures

### Conditional quality gates (run after devtools checks pass)

**Error class audit** — run if this branch adds any `cli_abort()` or `cli_warn()` calls:

```bash
git diff develop..HEAD -- R/ | grep -q "cli_abort\|cli_warn" && echo "AUDIT NEEDED" || echo "SKIP"
```

If `AUDIT NEEDED`: invoke the `error-class-auditor` subagent. If it flags any
calls missing `class=`, using wrong prefixes, or referencing undocumented classes,
**STOP** and report the findings. Ask the user to fix in `r-implement`, then
re-invoke `commit-and-pr`.

**Coverage check** — run if this branch adds any new exported functions:

```bash
git diff develop..HEAD -- R/ | grep -q "^+#' @export" && echo "COVERAGE NEEDED" || echo "SKIP"
```

If `COVERAGE NEEDED`: invoke the `coverage-gap-finder` subagent. If it finds
uncovered lines in the new code that are not marked `# nocov`, **STOP** and
report the gaps. Ask the user to add tests in `r-implement`, then re-invoke
`commit-and-pr`.

---

## Step 4: Stage and Commit

```bash
git status
```

Review the changed files list. If any `.R` source or test files appear that were
not part of this implementation task, stop and report to the user before staging.
This skill does not write code — unexpected `.R` changes need investigation.

Stage SPECIFIC files by name — never `git add -A` or `git add .`.

Always include the changelog file in the staged set.

Commit format, valid types, and valid scopes: see `github-strategy.md §5`.

Pass the commit message via HEREDOC:
```bash
git commit -m "$(cat <<'EOF'
feat(calibration): implement rake() with iterative proportional fitting

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

**Rules:**
- Never amend; always create new commits for fixes
- Never skip pre-commit hooks (`--no-verify`)
- If a pre-commit hook fails: fix the issue, re-stage, create a NEW commit
  (do not amend)

---

## Step 5: Check for Existing PR

Before creating a PR, verify one doesn't already exist:

```bash
gh pr view 2>/dev/null && echo "PR EXISTS" || echo "NO PR"
```

If a PR already exists: report its URL, update the task with its URL, and
skip to Step 8 (Monitor CI).

---

## Step 6: Draft and Approve PR

Draft a PR title (Conventional Commit format) and body. PR template: see
`refs/feature-pr-template.md`.

**Show the draft to the user before creating.** Ask for approval. Revise if
requested. Do NOT create the PR until the user approves.

---

## Step 7: Push and Create PR

```bash
git push -u origin <branch-name>

gh pr create \
  --base develop \
  --title "<approved-title>" \
  --body "$(cat <<'EOF'
<approved-body>
EOF
)"
```

Capture the PR URL and store it:

```
TaskUpdate:
  metadata: { prUrl: "<url>", prNumber: <N> }
```

Report the PR URL to the user.

---

## Steps 8–9: Monitor CI and Handle Failures

Read `refs/ci-monitoring.md` for the complete monitoring and failure-handoff
procedure. Return here for Step 10 when CI passes.

---

## Step 10: Done

When CI passes:

```
TaskUpdate (CI task):
  subject: "CI Run #N: passed"
  status:  completed
  metadata: { status: "passed" }

TaskUpdate (PR task):
  status: completed
```

1. Report the PR URL
2. Read the implementation plan and find the first remaining `- [ ]` section
3. Report:

   > "Next section: `branch-name` — [description]. Start a new session with
   > `/r-implement` to continue."

**Do NOT merge the PR.** Merging is the user's decision.

The terminal state of this skill is a passing CI run with an open PR. Do not
write code, fix anything, or continue work in this session after reporting.
The only next step is `/r-implement` for the next plan section.

---

## Quick Reference: What This Skill CAN and CANNOT Do

| Action | Allowed? |
|---|---|
| Read `.R` files to understand what was implemented | Yes |
| Create `changelog/phase-{X}/{branch-name}.md` | Yes |
| Run `devtools::check()` and `devtools::test()` | Yes |
| Stage and commit files | Yes |
| Push the branch | Yes |
| Create the PR | Yes |
| Monitor CI | Yes |
| Produce CI failure handoff block for r-implement | Yes |
| Write or edit `.R` source files | **NO** |
| Write or edit `.R` test files | **NO** |
| Fix failing tests | **NO** |
| Fix R CMD check errors | **NO** |
| Amend commits | **NO** |
| Merge the PR | **NO** |
