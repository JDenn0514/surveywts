# CI Monitoring (Steps 8–9)

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

**If CI passes:** mark CI task `completed`, return to SKILL.md Step 10.

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

Classify the failure before writing the handoff block. This helps r-implement
diagnose faster:
- **Test failure** (`devtools::test()` failing): logic issue in R source or test
- **R CMD check error**: documentation, NAMESPACE, or syntax issue
- **Platform-specific failure** (Windows or macOS only, not ubuntu-latest):
  environment issue; confirm it does not reproduce locally before handing off

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
Type:   <test failure | R CMD check error | platform-specific>

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

**DO NOT write code to fix the failure.** This violates the hard constraint
at the top of SKILL.md.
