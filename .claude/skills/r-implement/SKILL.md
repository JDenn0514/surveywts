---
name: r-implement
description: >
  Use when it's time to write R implementation code for surveyweights. Trigger
  when the user says "implement", "code this up", "start coding", "write the
  code", "start the PR", or "let's build this". Also use when commit-and-pr
  produces a CI Failure handoff block and the user needs the failure fixed.
---

# R Implementation Skill

You are implementing R package code for surveyweights.

---

## Entry Mode — Determine This First

**Mode A: Normal** — starting a new implementation section from the plan.
Signs: user says "implement", "start coding", "let's build this", or similar.
→ Go to **Pre-flight**.

**Mode B: CI-fix** — fixing a failure surfaced by commit-and-pr after push.
Signs: user provides a "CI Failure — Handoff to r-implement" block, or says
"CI is failing", "fix the CI failure", "commit-and-pr handed off to you", etc.
→ Go to **CI-Fix Mode** below. Skip Pre-flight entirely.

---

## CI-Fix Mode

Use this mode when commit-and-pr has already created a PR and CI has failed.

### Step 1: Read the handoff block

The user will provide a CI failure handoff block (fields: Run, PR, Job, Step, Error,
Local repro). Read it carefully. Identify: which check failed (check vs test), which
job (OS + R version), and the exact error message.

### Step 2: Reproduce locally

```bash
Rscript -e "devtools::check()"
Rscript -e "devtools::test()"
```

Match the failure to what CI reported. If the failure doesn't reproduce
locally, report that and describe what you see instead — do not guess.

### Step 3: Diagnose and fix

Attempt to diagnose and fix. After **3 failed attempts on the same failure**,
stop and report:

- The exact error output
- What was tried
- Why it is still failing

### Step 4: Verify

Run both checks after the fix:

```bash
Rscript -e "devtools::test()"
Rscript -e "devtools::check()"
```

Run `devtools::document()` if any roxygen2 tags changed.

### Step 5: Report

When both pass, report:

> "Fixed. Re-invoke `/commit-and-pr` — it will push the fix and resume
> monitoring CI."

**Do NOT mark the implementation plan section complete again.** It was already
marked `[x]` before commit-and-pr was invoked.

---

## Pre-flight (Normal Mode — do these FIRST, before writing any code)

### Step 1: Check the branch

```bash
git branch --show-current
```

**If on `main`:**

Stop. Feature branches must be cut from `develop`, not `main`. Tell the user:

> "Feature branches should start from `develop`. Please run `git checkout develop`
> and re-invoke `/r-implement`."

Do not proceed until the user is on `develop` or a feature branch.

**If on `develop`:**

1. Ask the user for the implementation plan path if not already provided
2. Read the plan and find the first unchecked `- [ ]` section
3. Determine the branch name from that section's entry
4. Show: "I'll create branch `feature/X` from `develop` — is that right?"
5. On confirmation: `git checkout -b feature/X`
6. Continue to Step 2

**If already on a feature branch:** continue to Step 2.

### Step 2: Read the implementation plan

Ask the user for the path if not provided (e.g., `plans/phase-1-implementation-plan.md`).

Find the **first unchecked `- [ ]` section**. That section defines the scope for this
entire session. Do not implement anything outside that scope.

If all sections are checked: report "All sections complete — nothing left to implement."
and stop.

### Step 3: Read the spec section

Read the spec file for the section you are about to implement. Before writing any code,
verify:

- Every function's behavior is fully specified (inputs, outputs, errors)
- All error conditions exist in `plans/error-messages.md`
- All argument types and defaults are defined
- All edge cases are explicitly handled

**If anything is ambiguous or underspecified: STOP. Ask the user to clarify before
writing a single line of code.** Do not make architectural guesses — surface the question.

### Step 4: Update `plans/error-messages.md`

Add any new error/warning classes you will need **before** writing code that uses them.

---

## Implementation

Follow TDD order — tests before source, always.

1. Write the test file (from the spec's test categories for this section)
2. Run `devtools::test()` — **confirm all new tests fail (red phase)**
   - If a new test unexpectedly passes, stop and investigate before proceeding
3. Write the R source file to make the tests pass
4. Run `devtools::document()` if any roxygen2 tags changed
5. Update `_pkgdown.yml` if any new functions were exported — add them to the
   correct `reference:` section (match the `@family` tag used in roxygen)

---

## Verification

Run both checks after implementation:

```r
devtools::test()
devtools::check()
```

**If either fails:** attempt to diagnose and fix, then re-run. After **3 failed attempts
on the same failure**, stop and report:

- The exact error output
- What was tried
- Why it is still failing

Do not mark the section complete until both pass.

---

## Completion

When `devtools::test()` and `devtools::check()` both pass:

1. Mark the section complete in the implementation plan: `- [ ]` → `- [x]`
2. Report:

> "Section complete. Start a new session with `/commit-and-pr` to create the PR."

---

## Conventions (always in context — no need to re-read)

All coding conventions are in the rule files loaded at session start.
Key rules: `code-style.md` (S7 patterns, cli errors, arg order), `r-package-conventions.md`
(imports, roxygen2), `surveyweights-conventions.md` (naming, families, visibility),
`testing-standards.md` + `testing-surveyweights.md` (test patterns).
Error class names: `plans/error-messages.md` — update BEFORE using any new class.

---

## Done Criteria

Do not mark the section complete until ALL are true:

- [ ] `devtools::test()` — no failures
- [ ] `devtools::check()` — 0 errors, 0 warnings, ≤2 notes
- [ ] `devtools::document()` run (if roxygen2 changed); `_pkgdown.yml` updated (if new exports)
- [ ] `plans/error-messages.md` updated (if new error classes added)
- [ ] No `UseMethod()` on S7 objects; no missing `class=`; no `@importFrom`
- [ ] `test_invariants()` first in every constructor test (see `testing-surveyweights.md`); dual pattern on Layer 3 errors
- [ ] Implementation plan section marked `[x]`
