# Mode B: CI-Fix

Use this mode when commit-and-pr has pushed a branch and CI has failed.

## Step 1: Read the handoff block

The user provides a "CI Failure — Handoff to r-implement" block like:

```
## CI Failure — Handoff to r-implement

Run:    #12345
PR:     #7 (https://github.com/...)
Job:    R CMD Check / ubuntu-latest / release
Step:   Running R CMD check

Error:
  <log output>

Local repro:
  Rscript -e "devtools::check()"
  Rscript -e "devtools::test()"
```

Identify: which check failed (check vs test), which job (OS + R version), and
the exact error message.

---

## Step 2: Reproduce locally

```bash
Rscript -e "devtools::check()"
Rscript -e "devtools::test()"
```

Match the failure to what CI reported. If the failure does not reproduce
locally, report that and describe what you see instead — do not guess.

---

## Step 3: Diagnose and fix

Attempt to diagnose and fix. After **3 failed attempts on the same failure**,
stop and report:

- The exact error output
- What was tried
- Why it is still failing

Do not continue attempting after 3 failures.

---

## Step 4: Verify

```bash
Rscript -e "devtools::test()"
Rscript -e "devtools::check()"
```

Run `devtools::document()` if any roxygen2 tags changed.

---

## Step 5: Report

When both pass:

> "Fixed. Re-invoke `/commit-and-pr` — it will push the fix and resume
> monitoring CI."

**Do NOT mark the implementation plan section complete again.** It was already
marked `[x]` before commit-and-pr was invoked.
