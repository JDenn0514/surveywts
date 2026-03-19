---
name: r-implement
description: >
  Use when it's time to write R implementation code for surveywts. Trigger
  when the user says "implement", "code this up", "start coding", "write the
  code", "start the PR", or "let's build this". Also use when commit-and-pr
  produces a CI Failure handoff block and the user needs the failure fixed
  (Mode B), or when the user says "subagent mode", "drive it yourself", or
  "auto-implement the plan" (Mode C: subagent-driven per-section dispatch).
---

# R Implementation Skill

You are implementing R package code for surveywts.

---

## Entry Mode — Determine This First

**Mode A: Normal** — starting a new implementation section from the plan.
Signs: user says "implement", "start coding", "let's build this", or similar.
→ Go to **Pre-flight**.

**Mode B: CI-fix** — fixing a failure surfaced by commit-and-pr after push.
Signs: user provides a "CI Failure — Handoff to r-implement" block, or says
"CI is failing", "fix the CI failure", "commit-and-pr handed off to you", etc.
→ Read `references/ci-fix.md`. Skip Pre-flight entirely.

**Mode C: Subagent-Driven** — dispatching fresh subagents per plan section.
Signs: "subagent mode", "drive it yourself", "auto-implement the plan".
→ Read `references/mode-c-subagent.md`. Skip Pre-flight.

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

### Step 2: Check surveycore version

`surveycore` is a co-developed ecosystem dependency installed from GitHub. Working
against a stale version risks implementing against the wrong class definitions or API.

Run both of these:

```bash
gh release view --repo JDenn0514/surveycore --json tagName,publishedAt,body \
  --template '{{.tagName}} ({{.publishedAt}})\n{{.body}}'
Rscript -e "cat(as.character(packageVersion('surveycore')), '\n')"
```

Compare the installed version against the latest release tag.

**If installed version is behind the latest release:**

Stop and tell the user:

> "surveycore `<installed>` is installed but `<latest>` is available.
> Update before implementing to avoid working against a stale API:
> ```r
> pak::pak('JDenn0514/surveycore')
> ```
> Re-invoke `/r-implement` after updating."

Do not proceed until the user confirms they have updated or explicitly chooses
to continue with the current version.

**If installed version matches the latest release:** note it briefly and continue.

**If the `gh` call fails** (no network, no auth): warn that the check could not
be completed and ask the user whether to proceed.

### Step 3: Read the implementation plan

Ask the user for the path if not provided (e.g., `plans/impl-phase-0.md`).

Find the **first unchecked `- [ ]` section**. That section defines the scope for this
entire session. Do not implement anything outside that scope.

If all sections are checked: report "All sections complete — nothing left to implement."
and stop.

### Step 4: Read the spec section

Read the spec file for the section you are about to implement. Before writing any code,
verify:

- Every function's behavior is fully specified (inputs, outputs, errors)
- All error conditions exist in `plans/error-messages.md`
- All argument types and defaults are defined
- All edge cases are explicitly handled

**If anything is ambiguous or underspecified: STOP. Ask the user to clarify before
writing a single line of code.** Do not make architectural guesses — surface the question.

### Step 5: Update `plans/error-messages.md`

Add any new error/warning classes you will need **before** writing code that uses them.

---

## TDD Iron Law

NO PRODUCTION CODE WITHOUT A FAILING TEST FIRST

Write code before the test? Delete it. Start over. No exceptions.

Do not keep it "as reference" — delete means delete. Implement fresh from tests.

| Rationalization | Reality |
|---|---|
| "Too simple to need a test" | Simple code breaks. The test takes 2 minutes. |
| "I'll add tests after" | Tests written after pass immediately, proving nothing. |
| "I already know it works" | Tests-first force edge case discovery. Tests-after verify memory. |
| "Just this once" | That's how untested code accumulates. |
| "I manually tested it" | Manual testing is ad-hoc, unrepeatable, and undocumented. |

The red phase isn't ceremony — it's proof. A test written after implementation almost
always passes immediately, which tells you nothing about whether it's testing real
behavior. Watching it fail proves the test is exercising what you think it is.

## Implementation

Follow this order for each sub-task:

1. Write the test file (from the spec's test categories for this section)
2. Run `devtools::test()` — **confirm all new tests fail (red phase)**
   Expected output: failures like `── Failure: my_fn() rejects X ──` with
   "did not throw" or "object not found." If tests pass before any source code
   exists, the tests are not testing anything — stop and investigate before proceeding.
3. Write the R source file to make the tests pass
4. Run `devtools::document()` if any roxygen2 tags changed
5. Update `_pkgdown.yml` if any new functions were exported — add them to the
   correct `reference:` section (match the `@family` tag used in roxygen). If
   any new vignettes were added to `vignettes/`, add them under `articles:`.

**Red flags — stop immediately if:**
- All new tests pass before any source code is written
- You are writing source before running `devtools::test()` to confirm failures
- A spec error condition has no corresponding failing test in the test file

---

## Verification

Run these checks after implementation:

```r
devtools::test()
devtools::check()
pkgdown::check_pkgdown()
```

**If either fails:** attempt to diagnose and fix, then re-run. After **3 failed attempts
on the same failure**, stop and report:

- The exact error output
- What was tried
- Why it is still failing

Do not mark the section complete until both pass.

---

## Sub-task Self-Check

After each sub-task (one `- [ ]` item) passes `devtools::test()`, run these two
checks before marking it `[x]`. This is the spec compliance + conventions gate —
the equivalent of a two-stage review after each unit of work.

**Spec compliance** — does the implementation match the spec's exact contracts?
- Every error condition in the spec fires correctly and has a corresponding test?
- Every explicitly listed edge case has a test?
- Return type visibility matches the spec (`invisible()` vs. visible)?

**Conventions** — does it follow the package rules?
- No `UseMethod()` on S7 objects? No S7 class string comparisons?
- `class=` on every `cli_abort()` and `cli_warn()`?
- No `@importFrom` anywhere; all external calls use `::`?
- `test_invariants()` first assertion in every constructor test?
- Dual pattern (snapshot + `class=`) on all Layer 3 errors?

If either check reveals a gap, fix it before moving to the next sub-task.

---

## Completion

When `devtools::test()` and `devtools::check()` both pass:

1. Mark the section complete in the implementation plan: `- [ ]` → `- [x]`
2. Report:

> "Section complete. Start a new session with `/commit-and-pr` to create the PR."

---

## Conventions (always in context — no need to re-read)

All surveywts coding conventions are in the rule files loaded at session start.
Quick index:

| What you need | Where it is |
|---|---|
| S7 class patterns, cli errors, arg order, helper placement | `code-style.md §2–4` |
| `cli_abort()` / `cli_warn()` structure and `class=` | `code-style.md §3` |
| `::` everywhere, no `@importFrom`, roxygen2 | `r-package-conventions.md §2` |
| Naming, families, visibility, export policy | `surveywts-conventions.md` |
| Test structure, constructor invariants, error testing | `testing-standards.md` + `testing-surveywts.md` |
| Error class names | `plans/error-messages.md` — update this file BEFORE using any new class |

---

## Done Criteria

Do not mark the section complete until ALL are true:

- [ ] `devtools::test()` — no failures
- [ ] `devtools::check()` — 0 errors, 0 warnings, ≤2 notes
- [ ] `devtools::document()` run (if roxygen2 changed); `_pkgdown.yml` updated (if new exports or vignettes); `pkgdown::check_pkgdown()` passes
- [ ] `plans/error-messages.md` updated (if new error classes added)
- [ ] No `UseMethod()` on S7 objects; no missing `class=`; no `@importFrom`
- [ ] `test_invariants()` first in every constructor test (see `testing-surveywts.md`); dual pattern on Layer 3 errors
- [ ] Sub-task self-check passed (spec compliance + conventions) for each `- [x]` item
- [ ] Implementation plan section marked `[x]`
