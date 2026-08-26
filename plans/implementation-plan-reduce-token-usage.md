# Reduce Token Usage of the Pipeline Skills — Implementation Plan

**Date:** 2026-08-26
**Repo:** `surveywts`
**Branch to create:** `chore/reduce-token-usage`
**Model that implements this:** Sonnet 5

**Goal:** Cut the token cost of one feature run through the pipeline skills by
50-70%. Do not lose output quality.

**Source of the design:** `surveycore` shipped this change in commit `0508e84`
(PR #157). Its design doc is `../surveycore/plans/spec-reduce-token-usage.md`.
Its task list is `../surveycore/plans/implementation-plan-reduce-token-usage.md`.
Read both before you start. Use the shipped `surveycore` files as the model for
every edit in this plan. Their paths are given in each task.

**Architecture:** Every change is a markdown or script edit under `.claude/`,
plus one pointer line in `CLAUDE.md`. No R source or test file changes. Verify
with `grep` and `wc -l`, not with the test suite.

---

## Why the cost is high

Four causes, ranked by measured cost in `surveycore`:

1. **The fixed entry fee per subagent.** `CLAUDE.md` plus the 8 files in
   `.claude/rules/` auto-load into every dispatch. In `surveywts` that is
   **2,482 lines**. Agent definitions then tell the agent to read
   `.claude/rules/` a second time, which doubles the cost.
2. **Unbounded review loops.** "Loop until verdict = PASS" has no cap. One
   `surveycore` feature ran 7 passes.
3. **Repeated heavy validation.** The builder runs the full test suite many
   times. The tester runs each gate as a separate command and polls for results.
4. **Top-tier model everywhere.** Mechanical agents run on the session model.

---

## Global constraints

- **Delete no rule.** Move it to a reference file, or remove a true duplicate.
- Every moved rule needs a pointer that says **when** to read the reference.
- Never use `@file` syntax in a pointer. It force-loads the file. Use a plain
  path.
- On-demand reference files go in `.claude/references/`. That directory does
  **not** auto-load. `.claude/rules/` does.
- `builder`, `planner`, and `reviewer` keep the session model. Add no `model:`
  key to them.
- Always-loaded budget (`CLAUDE.md` + `.claude/rules/*.md`): **≤ 800 lines**.
  Today it is 2,482.
- Commit after each task with the message given in the task.
- Stop after Task 9. Do not open a pull request. Report back instead.

---

## Differences from the surveycore change

Read this list before you copy anything.

| Item | surveycore | surveywts |
|---|---|---|
| `pkgcheck` gate | Removed in #157 | Already absent. No work. |
| Review lenses | Fan out to parallel `Explore` agents | Run inline in the main loop. Add the `model: sonnet` note as a conditional. |
| Pre-PR gate step | `pipeline-ship` §2e.5 | Does not exist. Apply the tree-hash skip to Step 3 instead. |
| `function-documentation.md` rule | Does not exist | Exists, 472 lines. It needs its own slim pass and its own reference file. |
| Shipper CI wait | Uses `ScheduleWakeup`, bans poll loops | Says "Poll with `gh pr checks`". Needs the fix. |
| `.claude/references/` | Exists | Must be created. |
| `.claude/scripts/` | Exists | Must be created. |

---

### Task 1: Create the branch

- [x] **Step 1**

```bash
git checkout develop && git pull origin develop
git checkout -b chore/reduce-token-usage
```

---

### Task 2: Model tiering

**Files:** `.claude/agents/tester.md`, `.claude/agents/shipper.md`,
`.claude/skills/pipeline-spec/SKILL.md`,
`.claude/skills/pipeline-implement/SKILL.md`

Reason: the tester and the shipper follow written checklists. Gate commands and
git mechanics pass or fail. They do not need the top model tier. The `model:`
frontmatter key is the supported way to set this.

- [x] **Step 1: tester frontmatter**

In `.claude/agents/tester.md`, add `model: sonnet` on its own line after the
`tools:` line, inside the frontmatter.

- [x] **Step 2: shipper frontmatter**

Do the same in `.claude/agents/shipper.md`.

- [x] **Step 3: fix the stale attribution**

`.claude/agents/shipper.md:71` reads
`Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>`. Replace it with
`Co-Authored-By: Claude <noreply@anthropic.com>`. The agent can run on any
model, so the line must not name one.

- [x] **Step 4: conditional note for lens fan-out**

`surveywts` runs the review lenses inline, so there is nothing to re-tier today.
Add this sentence once in `.claude/skills/pipeline-spec/SKILL.md` (in Stage 2,
before "Aggregate findings") and once in
`.claude/skills/pipeline-implement/SKILL.md` (in Stage 2, after the 5-lens
list):

> If you fan the lenses out to subagents instead of running them inline, pass
> `model: "sonnet"` on every lens dispatch. A lens agent scans one document
> against one named criterion. It does not need the session model.

- [x] **Step 5: verify**

```bash
grep -c "^model: sonnet" .claude/agents/tester.md .claude/agents/shipper.md   # 1 each
grep -c 'model: "sonnet"' .claude/skills/pipeline-spec/SKILL.md               # 1
grep -c 'model: "sonnet"' .claude/skills/pipeline-implement/SKILL.md          # 1
grep -c "Sonnet 4.6" .claude/agents/shipper.md                               # 0
grep -L "^model:" .claude/agents/builder.md .claude/agents/planner.md .claude/agents/reviewer.md  # all 3 listed
```

- [x] **Step 6: commit**

```bash
git add .claude/agents/tester.md .claude/agents/shipper.md \
  .claude/skills/pipeline-spec/SKILL.md .claude/skills/pipeline-implement/SKILL.md
git commit -m "chore(pipeline): run tester and shipper on sonnet"
```

---

### Task 3: Cap the review loops

**Files:** `.claude/skills/pipeline-spec/SKILL.md`,
`.claude/skills/pipeline-implement/SKILL.md`

Model: `../surveycore/.claude/skills/pipeline-spec/SKILL.md`, the section
titled "Review-loop budget".

- [x] **Step 1: add the budget block to pipeline-spec**

Insert this section immediately before `## Stage 2 — Methodology review
(conditional)`:

```markdown
## Review-loop budget (applies to Stages 2/2r and 3/3r)

Measured cost of an unbounded loop: one surveycore feature ran 7 review
passes, about $300 of API-equivalent usage. These rules cap the loop:

1. **Maximum 3 passes** per review stage. If findings are still open after
   pass 3, HOLD. Ask the user. Do not run pass 4.
2. **Pass 1 is the only full pass** — all lenses, the whole document.
3. **Pass 2 and later are delta passes.** Review only the sections the
   resolver changed, plus the specific findings you verify. The resolver
   lists the changed section headings at the top of its response. Do not
   re-read the whole document.
4. **Early exit.** A pass whose findings need no change to the artifact ends
   the loop. The verdict is PASS.
```

- [x] **Step 2: point the loop lines at the budget**

Append `Respect the Review-loop budget above.` to these two lines:
- `.claude/skills/pipeline-spec/SKILL.md:169` —
  "Loop until `spec-methodology-{id}.md` verdict = PASS."
- `.claude/skills/pipeline-spec/SKILL.md:186` —
  "... Loop until `spec-review-{id}.md` verdict = PASS."

- [x] **Step 3: add the same block to pipeline-implement**

Insert the same block in `.claude/skills/pipeline-implement/SKILL.md`, retitled
`## Review-loop budget (applies to Stages 2 and 3)`, immediately before
`## Stage 2 — Plan review (5 lenses)`. Append
`Respect the Review-loop budget above.` to the Stage 3 loop line (line 89-90).

- [x] **Step 4: verify**

```bash
grep -c "Maximum 3 passes" .claude/skills/pipeline-spec/SKILL.md \
  .claude/skills/pipeline-implement/SKILL.md            # 1 each
grep -c "Respect the Review-loop budget" .claude/skills/pipeline-spec/SKILL.md      # 2
grep -c "Respect the Review-loop budget" .claude/skills/pipeline-implement/SKILL.md # 1
```

- [x] **Step 5: commit**

```bash
git add .claude/skills/pipeline-spec/SKILL.md .claude/skills/pipeline-implement/SKILL.md
git commit -m "chore(pipeline): cap review loops at 3 passes with delta passes"
```

---

### Task 4: Slim the always-loaded rules

**This task holds most of the saving.** It cuts about 1,700 lines from every
subagent dispatch.

**Create:**
- `.claude/references/code-style-detail.md`
- `.claude/references/function-documentation-detail.md`
- `.claude/references/github-strategy-detail.md`
- `.claude/references/r-package-detail.md`
- `.claude/references/testing-detail.md`

**Modify:** all 8 files in `.claude/rules/`, and `CLAUDE.md`.

**Model to copy:** read the shipped slim files in `surveycore` first. They show
the exact voice and density to aim for:
- `../surveycore/.claude/rules/code-style.md` (130 lines, was 477)
- `../surveycore/.claude/rules/engineering-preferences.md` (25 lines, was 84)
- `../surveycore/.claude/rules/r-package-conventions.md` (65 lines, was 297)
- `../surveycore/.claude/rules/testing-standards.md` (84 lines, was 286)
- `../surveycore/.claude/references/code-style-detail.md` (the target format
  for a reference file)

**Method for every rules file:**

1. Keep the Quick Reference table as it is.
2. Keep every rule that the table does not already state, as compact prose.
3. Move to the reference file: worked examples, long code blocks, right/wrong
   pairs, and "why" prose.
4. Keep at most one short code block per rules file, and only where the shape
   of the code IS the rule (the `cli_abort()` three-bullet structure is the
   one clear case).
5. Remove content the agent can read from the repo itself — the text of
   `air.toml`, `.editorconfig`, and `.vscode/settings.json`. Point at the file
   in the package root instead.
6. Remove content duplicated across two rules files. Keep one source of truth.
   Make the other point at it.
7. End every slim rules file with a pointer in this shape:

```markdown
---
Worked examples and rationale: `.claude/references/{name}.md`. Read it when
you write new code covered by these rules and the correct use is not obvious
from the tables above.
```

**Per-file targets:**

| File | Now | Target | Reference file |
|---|---|---|---|
| `code-style.md` | 605 | ~145 | `code-style-detail.md` |
| `engineering-preferences.md` | 88 | ~25 | `code-style-detail.md` (own section) |
| `function-documentation.md` | 472 | ~85 | `function-documentation-detail.md` |
| `github-strategy.md` | 250 | ~70 | `github-strategy-detail.md` |
| `r-package-conventions.md` | 285 | ~65 | `r-package-detail.md` |
| `surveywts-conventions.md` | 239 | ~85 | `r-package-detail.md` (own section) |
| `testing-standards.md` | 288 | ~85 | `testing-detail.md` |
| `testing-surveywts.md` | 186 | ~90 | `testing-detail.md` (own section) |

- [x] **Step 1: `code-style.md` → ~145 lines**

Keep: the Quick Reference table; the `air`/pipe/assignment rules as one-liners;
the `@` property-access rule; the `weighted_df` type-check rule (base
`inherits()`, not `S7_inherits()`); the three-path input dispatch order and the
reason S7 objects are checked first; the one `cli_abort()` code block; the
class-naming lines; the cli markup table; the message-register bullets; the
return-visibility table; the argument-order list of 6; the dispatch table with
the sentence "Never use `UseMethod()` in surveywts — S3 dispatch does not work
for S7 objects."; the helper-placement table.

Move to `code-style-detail.md`: all §1 code examples (indentation, line length,
long signatures, `@examples` wrapping); the whole §6 Tooling Configuration; the
right/wrong `@` and `S7_inherits()` pairs; the history-entry code blocks; the
good/bad error examples; the `.validate_wt_name()` and `trim_weights()` example
functions; the full `ipw()` and `calibrate_rake()` signature blocks.

- [x] **Step 2: `engineering-preferences.md` → ~25 lines**

Keep the 5 principles. For each, keep the heading and its first sentence.
Move the sub-bullets and the "How to apply these during review" section into
`code-style-detail.md` under `## Engineering preferences — detail`.

- [x] **Step 3: `function-documentation.md` → ~85 lines**

This file is the largest single win after `code-style.md`. Only the builder,
the planner, and the reviewer need its detail, but today it loads into every
agent.

Keep inline: the Universal Rules as compact one-liners (title, description,
`@param` type annotation and defaults-first rule, `@returns`, `@details`, the
6 canonical named sections **in order** with a one-line trigger each,
`@references`, `@seealso`'s three required cases, `@examples` package-data
rule and the no-`\dontrun{}` rule, the errors-and-warnings placement rule, the
maths-notation rule as 3 lines, the internal-helper table); and one tier table:

```markdown
| Tier | Criteria | Required beyond the Universal Rules |
|---|---|---|
| 1 Utility | Single transformation, no iteration | Algorithm section only if it has a formula; `@references` only if the formula is published |
| 2 Standard | Multiple steps or method paths, no iteration | Algorithm section when 2-3 sentences cannot carry the mechanism; Missing Data when a `missing_method` arg exists |
| 3 Algorithmic | Statistical algorithm, formula, or optimisation | Algorithm, `@details`, `@references` always; Convergence when iterative; Missing Data when NAs are non-obvious |
| 4 Dispatcher | Routes on an argument value | Full `@param` docs; `@details` method overview with inline citations; `@references`; `@seealso` to every routed function. No Algorithm or Convergence section. |
```

Move to `function-documentation-detail.md`: every code example; the full
per-tier prose sections with their illustrative-function lists; the
`@inheritParams` example; the comment-style and section-header examples; the
Dataset Documentation section.

- [x] **Step 4: `github-strategy.md` → ~70 lines**

Keep: Quick Reference; the Workflow Tiers table; the branching diagram; the
branch-vs-direct table; the Branch Naming table; the commit type and scope
tables; the merge-strategy sentences; the versioning tables; the
`git log origin/develop..origin/main` pre-release check; the "use `/merge-main`"
line.
Move to `github-strategy-detail.md`: all worked commit and branch examples;
the PR template body; the GitHub settings checklists; the CI matrix and branch
protection sections.

- [x] **Step 5: `r-package-conventions.md` → ~65 lines**

Keep: Quick Reference; the roxygen rules as one-liners; the codoc rule stated
as prose ("one `\describe{}` block in `@format`; every column needs an
`\item{}`; `codoc` reads only the first block"); the export policy; the
`::`-everywhere rule; "NAMESPACE is never edited by hand"; the check targets;
the pre-approved NOTEs table; "accept NSE notes, do not suppress them"; the
`document()` and `check()` cadence; the minimum-version rule.
Move to `r-package-detail.md`: the right/wrong `\describe{}` blocks; the
DESCRIPTION template; the package-documentation template; the import-style
examples; the Summary section (delete it — it repeats the Quick Reference).

- [x] **Step 6: `surveywts-conventions.md` → ~85 lines**

Keep: Quick Reference; the naming-convention table; the `@family` table; the
file-organisation rules and the exempt-files table; the family-utils table; the
`survey_nonprob` validator's 5 conditions as a numbered list; the `weighted_df`
attribute table; the return-visibility table; the export and do-not-export
lists as two compact lines.
Move to `r-package-detail.md` under `## surveywts conventions — detail`: the
whole §7 Argument Order table of full signatures; the §3 File mapping table;
the §8 Documentation Checklist (it repeats `r-package-conventions.md` — keep
one copy); the `S7::new_class()` code block.

- [x] **Step 7: `testing-standards.md` → ~85 lines**

Copy `../surveycore/.claude/rules/testing-standards.md` almost as it stands.
The two files were near-identical before the slim. Check for any `surveywts`
wording and keep it.
Move the code examples to `testing-detail.md`.

- [x] **Step 8: `testing-surveywts.md` → ~90 lines**

Keep: Quick Reference; the file-mapping table; the `test_invariants()`
first-assertion rule with the 5 invariant names in prose (drop the function
body); the Layer 1 and Layer 3 rules as two lines each; the
`make_surveywts_data()` signature and its column table; the tolerance table.
Move to `testing-detail.md` under `## surveywts test templates`: the
`test_invariants()` body; both error-layer code examples; the test-file
section templates.

- [x] **Step 9: pointer line in `CLAUDE.md`**

In the Reference Documents list, add:

```markdown
- `.claude/references/` — worked examples and rationale moved out of `.claude/rules/`; read one when a rule's use is unclear
```

- [x] **Step 10: verify**

```bash
wc -l CLAUDE.md .claude/rules/*.md | tail -1     # total ≤ 800
ls .claude/references/                            # 5 files
grep -L "claude/references/" .claude/rules/*.md   # expect no output
grep -rn "@\.claude" .claude/                     # expect no output (no force-load links)
```

Content-survival spot checks. Each phrase moved out of a rules file must exist
in a reference file. Pick one distinctive phrase per moved section and confirm
it is present:

```bash
grep -rl "air.toml\|editorconfig"  .claude/references/     # tooling config moved
grep -rl "dontrun"                 .claude/references/     # examples detail moved
grep -rl "PULL_REQUEST_TEMPLATE"   .claude/references/     # PR template moved
grep -rl "ipw_weight"              .claude/references/     # signature table moved
grep -rl "make_surveywts_data"     .claude/rules/          # generator rule stayed
```

- [x] **Step 11: commit**

```bash
git add .claude/rules/ .claude/references/ CLAUDE.md
git commit -m "chore(rules): slim always-loaded rules to tables; move examples to .claude/references"
```

---

### Task 5: Stop the second read of the rules

The rules auto-load. An agent that reads `.claude/rules/` again pays twice.

**Files:** `.claude/agents/builder.md`, `tester.md`, `planner.md`,
`reviewer.md`, `snapshot-reviewer.md`,
`.claude/skills/pipeline-ship/SKILL.md`,
`.claude/skills/pipeline-simplified/SKILL.md`,
`.claude/skills/pipeline-shared/references/pipeline-isolation.md`

- [x] **Step 1: `builder.md:19`**

Replace the bullet "`.claude/rules/` — code style, testing standards, surveywts
conventions" with:

```markdown
- Project rules (`CLAUDE.md` plus `.claude/rules/`) auto-load into your
  context. Do NOT read them again. When a rule's use is unclear, read
  `.claude/references/code-style-detail.md`,
  `.claude/references/r-package-detail.md`, or
  `.claude/references/function-documentation-detail.md` for worked examples.
```

Also update `builder.md:76`: keep the pointer to
`.claude/rules/function-documentation.md` for the tier table, and add
"detail in `.claude/references/function-documentation-detail.md`".

- [x] **Step 2: `tester.md:17`**

Replace the `.claude/rules/` bullet with the same sentence, pointing at
`.claude/references/testing-detail.md`.

- [x] **Step 3: `planner.md:21` and `reviewer.md:22`**

Same treatment. For the planner, point at
`function-documentation-detail.md` and `testing-detail.md`. For the reviewer,
also replace the bullet
"`.claude/skills/pipeline-shared/references/` (all files)" with:

```markdown
- `.claude/skills/pipeline-shared/references/signals.md`,
  `artifact-schemas.md`, and `r-package-profile.md` — the only shared
  references you need (verdict schemas, tolerance defaults, gate skip rules).
```

- [x] **Step 4: `snapshot-reviewer.md:20`**

Leave the pointer to the rule file. Add the detail path only if the reviewer
needs the Warnings-section wording, which lives in the slim rule. Change
nothing else.

- [x] **Step 5: dispatch prompts**

- `pipeline-ship/SKILL.md:100` — change
  `Read: .claude/agents/builder.md, .claude/rules/, pipeline-shared/references/r-package-profile.md`
  to
  `Read: .claude/agents/builder.md, pipeline-shared/references/r-package-profile.md (rules auto-load — do not read .claude/rules/ again)`.
- `pipeline-ship/SKILL.md:157` — change `pipeline-shared/references/ (ALL)` to
  `pipeline-shared/references/signals.md, artifact-schemas.md, r-package-profile.md`.
- `pipeline-simplified/SKILL.md:92` — same change as the builder line above.

- [x] **Step 6: `pipeline-isolation.md:24-25`**

Both rows list `.claude/rules/` in the Receives column. Replace that entry with
`rules (auto-loaded)` in each row.

- [x] **Step 7: verify**

```bash
grep -c "Do NOT read them again" .claude/agents/builder.md .claude/agents/tester.md \
  .claude/agents/planner.md .claude/agents/reviewer.md       # 1 each
grep -rn "Read: .claude/agents/builder.md, .claude/rules/" .claude/skills/   # expect none
grep -rn "(ALL)" .claude/skills/pipeline-ship/SKILL.md                       # expect none
```

- [x] **Step 8: commit**

```bash
git add .claude/agents/ .claude/skills/pipeline-ship/SKILL.md \
  .claude/skills/pipeline-simplified/SKILL.md \
  .claude/skills/pipeline-shared/references/pipeline-isolation.md
git commit -m "chore(agents): stop re-reading auto-loaded rules; point at on-demand references"
```

---

### Task 6: One gate runner instead of eight commands

**Create:** `.claude/scripts/run-gates.sh`, `.claude/scripts/covr-report.R`,
`.claude/scripts/usage-profile.py`, `.gitattributes`

**Copy from:** `../surveycore/.claude/scripts/`. The three scripts port almost
as they stand.

Reason: in the `surveycore` validation run, the tester spent 683 turns polling
for gate results. That was 60% of the run's cost. One background command with
one summary table removes those turns.

- [x] **Step 1: copy and adapt `run-gates.sh`**

```bash
mkdir -p .claude/scripts
cp ../surveycore/.claude/scripts/run-gates.sh .claude/scripts/run-gates.sh
cp ../surveycore/.claude/scripts/covr-report.R .claude/scripts/covr-report.R
```

Then adapt for `surveywts`:
- The gate numbers already match — `surveywts` has no `pkgcheck` gate, and its
  gates 6 and 7 are pkgdown and covr. Confirm the script's gate numbers match
  `.claude/skills/pipeline-shared/references/r-package-profile.md`.
- Replace every `surveycore` string with `surveywts` (the comment about
  `surveycore-manual.tex` in gate 5, and the package name in any message).
- The `NOT_CRAN=true` comments in `surveycore` cite "ten test files carry a
  file-level `skip_on_cran()`". In `surveywts` only **one** test file does.
  Rewrite both comments to say: "`NOT_CRAN=true` matches CI and stops
  `skip_on_cran()` blocks from being skipped, which would understate
  coverage." Keep the variable set — do not remove it.
- Keep `--as-cran --no-manual` in gate 5. It mirrors
  `.github/workflows/R-CMD-check.yaml:41`.
- Keep `--skip-pkgdown` and `--baseline` modes as they are.
- `covr-report.R`: keep as is except the `skip_on_cran()` comment, same
  rewrite as above.

- [x] **Step 2: copy the profiler**

```bash
cp ../surveycore/.claude/scripts/usage-profile.py .claude/scripts/usage-profile.py
```

Update the example path in its header comment to
`C--Users-jdennen-surveywts`.

- [x] **Step 3: force LF line endings**

Create `.gitattributes` in the repo root:

```
*.sh text eol=lf
```

- [x] **Step 4: smoke-test the runner**

Run the baseline mode on the clean branch. It runs only the test and coverage
gates, so it is the cheap path:

```bash
bash .claude/scripts/run-gates.sh /tmp/gate-smoke --baseline
```

Expect a `## Gate summary` table, a `Tree:` line, and `ALL GATES PASS`. If a
gate fails for a reason unrelated to this plan, record it in the report and
carry on — do not fix package code in this branch.

- [x] **Step 5: commit**

```bash
git add .claude/scripts/ .gitattributes
git commit -m "chore(pipeline): add one-command gate runner and usage profiler"
```

---

### Task 7: Test-run and output discipline

**Files:** `.claude/agents/builder.md`, `.claude/agents/tester.md`,
`.claude/skills/pipeline-shared/references/r-package-profile.md`,
`.claude/skills/pipeline-ship/SKILL.md`,
`.claude/skills/pipeline-simplified/SKILL.md`

**Model:** the same four files in `surveycore`, post-#157.

- [x] **Step 1: builder full-suite budget**

In `.claude/agents/builder.md`, after the Step 2 TDD loop list, add the
`### Full-suite budget` section from
`../surveycore/.claude/agents/builder.md`. Keep its wording. It says: iterate
with `devtools::test(filter = ...)`; run the full suite at most twice per PR;
redirect full-suite output to `.test-full.log`; read only the tail; delete the
log before committing.

- [x] **Step 2: output discipline in `r-package-profile.md`**

Add two sections after the Validation commands table, copied from
`../surveycore/.claude/skills/pipeline-shared/references/r-package-profile.md`:
- `### Canonical runner` — run the whole table with one background command,
  `bash .claude/scripts/run-gates.sh <log-dir> [--skip-pkgdown]`; never run the
  gates one at a time.
- `## Output discipline (all gates)` — full output to
  `{workspace-run-dir}/logs/gate-{N}.log`; bring only `tail -25` and a
  `grep -E "FAIL|ERROR|WARNING|NOTE"` into context; record each log path in
  `audit.md`; read a full log only to diagnose that gate's failure.

- [x] **Step 3: rewrite tester Step 1**

Replace `.claude/agents/tester.md` lines 50-63 with the
`## Step 1 — Run the profile gates (ONE background command)` section from
`../surveycore/.claude/agents/tester.md`. It says:
1. Start `bash .claude/scripts/run-gates.sh {workspace-run-dir}/logs` with
   `run_in_background: true`.
2. While it runs, prepare Steps 2-3. Do not run `sleep`, `until` loops, or
   repeated status checks. The harness gives notice when the command finishes.
3. Read only the Gate summary table. On a FAIL, read the one log file the
   summary names. Never read the log of a passing gate.
4. Copy the summary table and its `Tree:` line into `audit.md`.

- [x] **Step 4: add two tester prohibitions**

In the `## Never` list of `.claude/agents/tester.md`, add:

```markdown
- Runs `sleep` or `until` polling loops (use `run_in_background` and wait for
  the notice)
- Rebuilds the pre-PR state (the Before column comes from the dispatch
  baseline)
```

- [x] **Step 5: rewrite tester Step 4**

Replace the first sentence of `## Step 4 — Before/After comparison` (which
tells the tester to use `git stash` or a second worktree) with the
`surveycore` wording: the Before column comes from the baseline passed in the
dispatch; never rebuild the pre-PR state; if no baseline arrived, write "no
baseline provided" and emit HOLD.

`pipeline-ship` Step 0 already caches a baseline and passes it in the tester
dispatch at line 131. Confirm that line names the fields the tester needs
(tests passing, coverage %). Extend it if it does not.

- [x] **Step 6: baseline capture in `pipeline-simplified`**

`pipeline-simplified` has no baseline step, so its tester has nothing for the
Before column. In Step 1, after "Append `PLANNED` to `status.md`", add:

```markdown
**In the same turn**, start the baseline capture in the background. The tree
is still clean, because the builder has not run:
`bash .claude/scripts/run-gates.sh {workspace-run-dir}/logs-baseline --baseline`
with `run_in_background: true`. Its summary is the tester's Before column. Do
not wait for it here. Collect the result before you dispatch the tester.
```

Then add `Baseline results: {summary from the background baseline capture}` to
the tester dispatch prompt in Step 3.

- [x] **Step 7: a BLOCK reuses the same builder**

In `.claude/skills/pipeline-ship/SKILL.md` §2c, replace item 2 with:

```markdown
2. If the counter is ≤ 3: send the BLOCK body — not the full `audit.md`, not
   `test-spec-{id}.md`, per `signals.md` — to the SAME builder agent with
   `SendMessage`. It keeps its context and its warm cache. The message MUST
   state: "Your worktree was merged back and removed. Work in the main
   checkout at {path}. Run `git status` there before you edit." Dispatch a
   fresh builder only when the original agent is gone, for example after a
   session restart. Pass the BLOCK body in the dispatch prompt.
```

- [x] **Step 8: verify**

```bash
grep -c "Full-suite budget" .claude/agents/builder.md                    # 1
grep -c "Output discipline" .claude/skills/pipeline-shared/references/r-package-profile.md  # >=1
grep -c "run-gates.sh" .claude/agents/tester.md                          # >=1
grep -c "SAME builder agent" .claude/skills/pipeline-ship/SKILL.md       # 1
grep -c "git stash" .claude/agents/tester.md                             # 0
grep -c "logs-baseline" .claude/skills/pipeline-simplified/SKILL.md      # 1
```

- [x] **Step 9: commit**

```bash
git add .claude/agents/builder.md .claude/agents/tester.md \
  .claude/skills/pipeline-shared/references/r-package-profile.md \
  .claude/skills/pipeline-ship/SKILL.md .claude/skills/pipeline-simplified/SKILL.md
git commit -m "chore(pipeline): cap full-suite runs, filter gate output, reuse builder on BLOCK"
```

---

### Task 8: Remove duplicate gate runs

**Files:** `.claude/agents/tester.md`,
`.claude/skills/pipeline-shared/references/artifact-schemas.md`,
`.claude/skills/pipeline-ship/SKILL.md`, `.claude/agents/shipper.md`

`surveywts` has no `pkgcheck` gate, so that half of the `surveycore` change is
already done. Two other duplicate runs remain.

- [x] **Step 1: tester records the tree hash**

In `.claude/agents/tester.md` Step 1, add: "Record
`git rev-parse 'HEAD^{tree}'` in `audit.md` §Profile gates as `Tree: {hash}`.
A later gate uses it to skip a duplicate run." The `run-gates.sh` summary
already prints this line, so the tester copies it.

- [x] **Step 2: add the field to the audit schema**

In `.claude/skills/pipeline-shared/references/artifact-schemas.md`, find the
`audit.md` schema's Profile gates block and add this line below the table:

```
Tree: {git tree hash at gate time — `git rev-parse 'HEAD^{tree}'`}
```

- [x] **Step 3: skip the post-batch rerun when the tree is unchanged**

`pipeline-ship` Step 3 runs `devtools::test()` on updated `develop` after every
batch. When a batch held one PR and `develop` did not move, the squashed
commit's tree equals the tree the tester already tested. Add before the
commands in Step 3:

```markdown
Skip check first. Compare `git rev-parse 'HEAD^{tree}'` on updated `develop`
against the `Tree:` line in this batch's `audit.md`. If every audit in the
batch matches, the tester already ran these tests on this exact tree — log
"post-batch check: SKIPPED — tree unchanged since audit" and go on. If any
hash differs, or an `audit.md` has no `Tree:` line, run the commands below.
```

- [x] **Step 4: shipper waits, it does not poll**

Replace `## Step 5 — Monitor CI` in `.claude/agents/shipper.md` with the
`surveycore` version (`../surveycore/.claude/agents/shipper.md`, Step 6). It
says: call `gh pr checks` once, then always use `ScheduleWakeup` — 600 s for
the first wakeup, 300 s after that, HOLD with classification `ci-timeout`
after 4 wakeups. Keep its **Forbidden patterns** block verbatim:

```bash
until gh pr checks ...; do sleep N; done
sleep N && gh pr checks ...
gh run list   # in any loop
```

Keep the `surveywts` required-check names. This repo runs `R-CMD-check`,
`pkgdown`, and `test-coverage`. State which of those are required.

- [x] **Step 5: verify**

```bash
grep -c "Tree:" .claude/agents/tester.md \
  .claude/skills/pipeline-shared/references/artifact-schemas.md \
  .claude/skills/pipeline-ship/SKILL.md                    # >=1 each
grep -c "ScheduleWakeup" .claude/agents/shipper.md         # >=1
grep -c "Poll with" .claude/agents/shipper.md              # 0
```

- [x] **Step 6: commit**

```bash
git add .claude/agents/tester.md .claude/agents/shipper.md \
  .claude/skills/pipeline-shared/references/artifact-schemas.md \
  .claude/skills/pipeline-ship/SKILL.md
git commit -m "chore(pipeline): skip duplicate gate runs via tree hash; stop CI polling"
```

---

### Task 9: Final sweep and report

- [x] **Step 1: line budget**

```bash
wc -l CLAUDE.md .claude/rules/*.md | tail -1     # total <= 800
wc -l .claude/references/*.md
```

- [x] **Step 2: no dangling pointers**

```bash
grep -rn "Read: .claude/rules" .claude/agents/ .claude/skills/    # expect none
grep -rn "@\.claude" .claude/                                     # expect none
grep -rn "pkgcheck" .claude/                                      # expect none
# every reference path cited anywhere must exist:
grep -rhoE "\.claude/references/[a-z-]+\.md" .claude/ CLAUDE.md | sort -u | \
  while read p; do [ -f "$p" ] || echo "MISSING: $p"; done
```

- [x] **Step 3: cross-check against the design**

Re-read `../surveycore/plans/spec-reduce-token-usage.md` §2 and §3. Confirm
every item in Groups A through E maps to a step above, or to a row in
"Differences from the surveycore change". Confirm §3 still holds: `builder`,
`planner`, and `reviewer` carry no `model:` key; the builder/tester isolation
model is untouched; tolerances, snapshot rules, and coverage floors are
untouched.

- [x] **Step 4: changelog entry**

Add a changelog entry per `.claude/skills/changelog-workflow.md`. Model:
`../surveycore/changelog/chore-reduce-pipeline-token-usage.md`.

- [x] **Step 5: commit and report**

```bash
git add -A
git commit -m "docs(changelog): add entry for pipeline token-usage reduction"
```

Report to the user:
1. A per-file table of line counts, before and after, for `CLAUDE.md` and each
   file in `.claude/rules/`, plus the total.
2. The size of each new file in `.claude/references/` and `.claude/scripts/`.
3. Anything you could not port, and why.
4. Do NOT open a pull request. Say that the branch is ready for
   `/commit-and-pr`.

---

## How to validate the saving

Do this after the branch merges, on the first real feature run.

1. Run the pipeline on one small change — a Tier 3 change per
   `github-strategy.md`.
2. Profile the session transcripts:
   `python .claude/scripts/usage-profile.py "C:/Users/jdennen/.claude/projects/C--Users-jdennen-surveywts" <session-id>`
3. Compare turns, cache reads, cache writes, and output tokens against the
   `surveycore` baseline in `../surveycore/plans/spec-reduce-token-usage.md` §1.
4. Success: 50% or more reduction in weighted usage, every gate passes, and no
   new class of finding from the reviewer or from CI.

## Risks

| Risk | Mitigation |
|---|---|
| A sonnet tester misjudges a borderline gate result | Gates pass or fail on a command. The reviewer runs on the session model and still cross-checks the audit against the implementation. |
| A delta review pass misses a regression in an unchanged section | Pass 1 is always the full pass. The reviewer reads all artifacts at ship time. |
| A moved rule stops being followed | Each pointer names the trigger to read it. Watch the first PR's diff for style violations. |
| The tree-hash skip misses a change outside the tree | A hash mismatch forces the run. GitHub CI still runs everything. |
| `run-gates.sh` behaves differently on Windows | Task 6 Step 4 smoke-tests it in `--baseline` mode before anything depends on it. |
