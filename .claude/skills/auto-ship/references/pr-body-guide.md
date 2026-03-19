# PR Body Guide

Every PR created by auto-ship uses this two-part format. The plain English
section comes first because it's what a reviewer reads to decide if this PR
is what they expected. The technical section is for audit and review.

---

## Section 1: Plain English (required, always first)

2–4 sentences explaining what this section adds in terms any developer can
understand — not just survey statistics experts. Focus on:

- What you can now do that you couldn't before
- What problem it solves for the end user
- Any meaningful limitations or caveats

**Good:**
> This PR adds iterative raking to surveywts. Before this, calibration only
> supported single-variable poststratification. Now `rake()` handles multiple
> marginal distributions simultaneously, iterating until the weights converge
> to match all target margins within a specified tolerance.

**Too vague:**
> This PR implements Phase 1 weighting functionality.

**Too technical:**
> Implements Newton-Raphson optimization of the dual calibration problem
> with Deville-Särndal distance functions under the linear bounded method.

---

## Section 2: Technical changes

Bullet list of what changed:

- **New functions:** `foo()`, `bar()` (include all exported functions added)
- **New tests:** N new test cases in `tests/testthat/test-X.R`
- **New error classes:** `surveywts_error_X`, `surveywts_warning_Y`
  (omit this line if no new error classes)
- **Modified files:** list every R and test file changed
- **Plan section:** `feature/branch-name` — section N from `plans/impl-X.md`

---

## Section 3: Spec coverage

Copy the relevant section header and bullet points from the spec. Mark each
as checked. This lets reviewers verify completeness without reading the spec.

```
**From `plans/spec-X.md §N.Title`:**
- [x] behavior 1
- [x] behavior 2
- [x] error condition A — `surveywts_error_X`
```

If the spec section is long, include only the items that have corresponding
code changes in this PR.

---

## Section 4: Test results

```
`devtools::test()`: N tests, 0 failures
`devtools::check()`: 0 errors, 0 warnings, N notes
```

---

## Full template

```markdown
## What this does

[2–4 sentence plain English description]

## Technical changes

- **New functions:** ...
- **New tests:** N new test cases
- **New error classes:** ... *(omit if none)*
- **Modified files:** ...
- **Plan section:** `feature/X` — section N from `plans/impl-X.md`

## Spec coverage

**From `plans/spec-X.md §N.Title`:**
- [x] ...
- [x] ...

## Test results

`devtools::test()`: N tests, 0 failures
`devtools::check()`: 0 errors, 0 warnings, N notes

---

🤖 Generated with [Claude Code](https://claude.ai/claude-code)
```
