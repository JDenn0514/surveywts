# Mode C: Subagent-Driven Development

Use this mode to implement all remaining plan sections autonomously, dispatching
a fresh subagent per section with two-stage review after each.

**Core principle:** Fresh subagent per section (no context pollution) + two-stage
review (spec compliance, then code quality) = high confidence, continuous progress.

**Never dispatch multiple implementation subagents in parallel — context conflicts.**

---

## Step 1: Pre-flight

```bash
git branch --show-current
```

Must be on `develop` or a feature branch. If on `main`: stop and tell the user.

Read the implementation plan. Extract all unchecked `- [ ]` sections with full
text and dependencies. Create a TodoWrite task list.

Run the baseline:

```r
devtools::test()
devtools::check()
```

Both must pass before starting. If either fails, report and stop — do not
proceed into section dispatch.

---

## Step 2: Per-Section Loop

For each unchecked section in plan order:

### 2a. Dispatch implementer subagent

Provide the subagent with:
- The full section text from the plan (copy it; do not make the subagent read the file)
- The corresponding spec section (file path or content)
- Paths to: `code-style.md`, `testing-surveywts.md`, `plans/error-messages.md`
- Current branch name

The subagent follows Mode A pre-flight (skip branch creation — branch already
exists), TDD Iron Law, and verification. It reports back when
`devtools::test()` and `devtools::check()` both pass.

**If the subagent asks questions before implementing:** answer clearly and
completely before letting it proceed. Do not rush it.

**If the subagent fails after 3 attempts:** do not dispatch another implementer.
Surface the failure to the user with the exact error output.

### 2b. Spec compliance review

After the implementer reports success, dispatch a spec compliance reviewer:

> "Review the code changes against the spec section provided. Confirm:
> (1) every function signature matches the argument table,
> (2) every error class from the spec's error table is present in the code,
> (3) every output column matches the output contract,
> (4) no behavior was added beyond spec scope.
> Report PASS or list specific deviations."

If reviewer finds deviations: dispatch the same implementer subagent with
specific fix instructions. Re-review. Repeat until PASS.

**Do not advance to code quality review until spec compliance is PASS.**

### 2c. Code quality review

After spec compliance is PASS, dispatch a code quality reviewer:

> "Review the code changes against surveywts conventions:
> (1) no `UseMethod()` on S7 objects — uses `S7::S7_inherits()` instead,
> (2) `class=` on every `cli_abort()` and `cli_warn()` call,
> (3) no `@importFrom` — all external calls use `::`,
> (4) `test_invariants(obj)` is first assertion in every constructor test block,
> (5) dual pattern (class= + snapshot) on all Layer 3 errors.
> Report PASS or list violations."

If reviewer finds violations: dispatch the implementer to fix. Re-review.
Repeat until PASS.

### 2d. Mark complete

Mark the section `[x]` in the plan. Update the TodoWrite task. Continue to
the next section.

---

## Step 3: All Sections Complete

When all `- [ ]` sections are marked `[x]`:

> "All plan sections implemented and reviewed. Start a new session with
> `/commit-and-pr` to create the PR."
