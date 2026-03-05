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

---

## Step 4: Stage and Commit

```bash
git status
```

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

Draft a PR title (Conventional Commit format) and body. Use this template:

```markdown
## What

<!-- One sentence: what does this PR add or fix? -->

## Checklist

- [ ] Tests written and passing (`devtools::test()`)
- [ ] R CMD check: 0 errors, 0 warnings (`devtools::check()`)
- [ ] Roxygen docs updated and `devtools::document()` run
- [ ] `plans/error-messages.md` updated (if new errors/warnings added)
- [ ] PR title is a valid Conventional Commit (`feat(scope): description`)
```

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

## Step 8: Monitor CI

Create a CI run tracking task:

```
TaskCreate:
  subject:    "CI Run #1: monitoring"
  description: "Monitoring CI for PR #[N]"
  activeForm: "Monitoring CI Run #1"

TaskUpdate:
  status: in_progress
  addBlockedBy: [pr task ID]
```

Wait for the run to appear, then watch it:

```bash
# List runs — get the run ID
gh run list --branch <branch-name> --limit 3

# Watch silently until completion — redirect output, it's very verbose
gh run watch <run-id> --exit-status > /dev/null 2>&1
echo "CI exit: $?"
```

Store the run ID:

```
TaskUpdate (CI task):
  metadata: { runId: "<run-id>" }
```

**If CI passes:** mark CI task `completed`, proceed to Step 10.

**If CI fails:** proceed to Step 9.

---

## Step 9: CI Failure — Handoff to r-implement

Analyze the failure with a targeted approach — work from the bottom of the
log upward, where the actual error almost always appears:

```bash
# Summary of which jobs and steps failed
gh run view <run-id>

# Last 40 lines of failed log (where the error usually is)
gh run view <run-id> --log-failed 2>&1 | tail -40

# If more context needed: search around the error keyword
gh run view <run-id> --log-failed 2>&1 | grep -A 5 -B 5 "Error\|FAIL\|failed"
```

Update the CI task:

```
TaskUpdate (CI task):
  subject:  "CI Run #1: failed"
  status:   completed
  metadata: { status: "failed", failureReason: "<brief reason>" }
```

Produce this structured handoff block and show it to the user:

```
## CI Failure — Handoff to r-implement

Run:    #<run-id>
PR:     #<pr-number> (<pr-url>)
Job:    <job-name> (e.g., R CMD Check / ubuntu-latest / release)
Step:   <step-name>

Error:
<last 40 lines of --log-failed output>

Local repro:
  Rscript -e "devtools::check()"
  Rscript -e "devtools::test()"
```

Then tell the user:

> "Invoke `/r-implement` and share the block above. After r-implement reports
> the fix is done, re-invoke `/commit-and-pr` — it will detect the existing PR
> and resume from CI monitoring."

**DO NOT write code to fix the failure.** This violates the hard constraint.

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
