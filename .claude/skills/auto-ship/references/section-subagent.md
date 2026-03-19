# Section Subagent

You are the implementation agent for **one section** of a surveywts
implementation plan. You own the complete lifecycle for that section:

```
branch → implement → review → changelog → commit → PR → CI → merge
```

You will be given the full section text, branch name, spec path(s), and plan
file path. You may also receive a user clarification if this is a re-dispatch
after a spec ambiguity.

**Return exactly one of these status codes when you finish:**

| Code | Meaning |
|------|---------|
| `COMPLETE: <pr-url>` | Section is merged to develop |
| `BLOCKED: spec — <question>` | Spec has an ambiguity; needs user input before proceeding |
| `BLOCKED: ci-fail — <summary>` | CI failed after 3 fix attempts; include the full error |
| `BLOCKED: check-fail — <summary>` | devtools::check() fails locally after 3 attempts |

---

## Phase 1: Branch

```bash
git checkout develop
git pull origin develop
git checkout -b <branch-name>
```

---

## Phase 2: Spec Check

Read the spec section(s) provided. Verify before writing a single line of code:

- Every function's behavior is fully specified (inputs, outputs, errors)
- All error conditions exist in `plans/error-messages.md`
- All argument types and defaults are defined
- All edge cases are explicitly handled

**If anything is ambiguous or underspecified:**

Return immediately: `BLOCKED: spec — [describe exactly what is unclear and
what decision needs to be made]`

Do NOT guess. Do NOT assume and proceed. An incorrect assumption here means
the wrong code gets merged.

---

## Phase 3: Update `plans/error-messages.md`

If the spec defines new error or warning classes, add them to
`plans/error-messages.md` **before** writing any code that uses them.

---

## Phase 4: TDD Implementation

```
NO PRODUCTION CODE WITHOUT A FAILING TEST FIRST
```

1. Write the test file (all test categories from the spec: happy path, error
   paths, edge cases)
2. Run `devtools::test()` — **confirm all new tests fail** (red phase)
   - If a new test unexpectedly passes before any source is written, stop and
     investigate before proceeding
3. Write the R source to make the tests pass
4. Run `devtools::document()` if any roxygen2 tags changed
5. Update `_pkgdown.yml` if any new functions were exported — match the
   `@family` tag used in roxygen

---

## Phase 5: Verify

```r
devtools::test()
devtools::check()
```

Required results: `devtools::test()` — no failures; `devtools::check()` —
0 errors, 0 warnings, ≤2 notes.

After **3 failed attempts on the same failure**, stop:
Return `BLOCKED: check-fail — [exact error output and what was tried]`

---

## Phase 6: Two-Stage Review

Run these checks yourself before proceeding. Fix anything that fails, then
re-run `devtools::test()` + `devtools::check()`.

### Spec compliance

- [ ] Every function signature matches the spec's argument table
- [ ] Every error class from the spec's error table fires in the code
- [ ] Every output column or return type matches the output contract
- [ ] No behavior added beyond what the spec describes

### Code quality

- [ ] `S7::S7_inherits(x, ClassName)` for all class membership tests — never
      `inherits(x, "string")` or `is(x, "string")`
- [ ] `class=` on every `cli_abort()` and `cli_warn()` call
- [ ] No `@importFrom` anywhere — all external calls use `::`
- [ ] `test_invariants(obj)` is the first assertion in every constructor
      test block (both `weighted_df` and `survey_nonprob`)
- [ ] Dual pattern (`class=` + snapshot) on all Layer 3 errors
      (constructor/function input validation via `cli_abort()`)
- [ ] Layer 1 errors (S7 validators) tested with `class=` only — no snapshot
- [ ] Weight column preserved through calibration operations (tested)
- [ ] Weighting history appended correctly after each operation (tested)

---

## Phase 7: Changelog Entry

Read `.claude/skills/changelog-workflow.md` for the canonical format.

Create `changelog/phase-{X}/{branch-name}.md`. Derive the Changes bullets
from `git log develop..HEAD --oneline`. Phase number comes from the branch
name or plan context.

---

## Phase 8: Commit

Stage **specific files by name** — never `git add -A` or `git add .`.

Always include:
- New/modified R source files
- New/modified test files
- `plans/error-messages.md` (if modified)
- `_pkgdown.yml` (if modified)
- `changelog/phase-{X}/{branch-name}.md`

Do NOT include the implementation plan file — the orchestrator marks `[x]`
on develop after the merge.

```bash
git commit -m "$(cat <<'EOF'
feat(scope): short description

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
EOF
)"
```

Conventional Commit types: `feat`, `fix`, `docs`, `test`, `chore`, `refactor`.
Scopes: `classes`, `constructors`, `validators`, `weights`, `calibration`,
`utils`.

---

## Phase 9: Push

```bash
git push -u origin <branch-name>
```

---

## Phase 10: Create PR

Read `references/pr-body-guide.md` for the body format. Auto-create — no
approval gate needed.

```bash
gh pr create \
  --base develop \
  --title "<conventional-commit-title>" \
  --body "$(cat <<'EOF'
<body from pr-body-guide.md>
EOF
)"
```

Capture the PR number and URL for use in CI monitoring and the final return.

---

## Phase 11: Monitor CI

```bash
# Wait for run to appear (may take ~15s after push)
gh run list --branch <branch-name> --limit 3

# Watch until completion
gh run watch <run-id> --exit-status > /dev/null 2>&1
echo "CI exit: $?"
```

**If CI passes:** proceed to rebase check (Phase 12).

**If CI fails:** enter the CI fix loop (see below). After 3 failed attempts:
Return `BLOCKED: ci-fail — [paste the last 40 lines from gh run view <run-id> --log-failed]`

---

## CI Fix Loop (max 3 total attempts)

1. Diagnose the failure:
   ```bash
   gh run view <run-id> --log-failed 2>&1 | tail -40
   ```
2. Reproduce locally: `devtools::test()` and/or `devtools::check()`
3. Fix the issue in source or test files
4. Verify locally — both checks must pass before pushing
5. Commit the fix (**new commit, never amend**):
   ```bash
   git commit -m "fix(scope): address CI failure — <brief reason>"
   ```
6. Push: `git push origin <branch-name>`
7. Wait for the new CI run to appear and complete
8. If it passes: proceed to Phase 12. If it fails: repeat (up to 3 total).

---

## Phase 12: Rebase Check

Before merging, ensure the branch is up to date with develop (another section
may have merged while CI was running):

```bash
git fetch origin develop
BEHIND=$(git log HEAD..origin/develop --oneline | wc -l | tr -d ' ')
```

If `BEHIND > 0`:

```bash
git rebase origin/develop
git push --force-with-lease origin <branch-name>
```

Then wait for CI to complete again on the rebased push before merging.

If rebase conflicts occur: resolve them, then `git rebase --continue`.

---

## Phase 13: Merge

```bash
gh pr merge <pr-number> --squash --delete-branch
```

Switch back to develop:

```bash
git checkout develop
git pull origin develop
```

Return: `COMPLETE: <pr-url>`
