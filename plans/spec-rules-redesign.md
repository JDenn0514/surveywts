# Spec: redesign the rules and the `.claude/` tree for token cost

**Date:** 2026-08-27
**Baseline commit:** `45e8751` (develop)
**Status:** Draft for approval. No rules file has been edited.
**Scope:** everything under `.claude/`, plus `CLAUDE.md`.
**Produces:** a smaller always-loaded set, a role-scoped standards tier, and a
conservation gate that a line count cannot pass.

### Progress against Section 10

| Step | State | Evidence |
|---|---|---|
| 0 — verify `.claude/standards/` does not auto-load | **PASS** | Two independent probes on 2026-08-27. A fresh main session and a dispatched subagent both answered NO to the canary, and both listed the same nine auto-loaded files. The structure in Section 4 holds |
| 1 — Phase A inventory | **COMPLETE** | 9 agents, each blind to this plan. **1,102 statements** in `plans/ledger/before-*.tsv`. Every row has 6 fields; 0 malformed |
| 2 — `check-literals.sh` | **PASS on the untouched tree** | 874 literals, citations resolve, no force-load links, standards reachable |
| 3 — your approvals | **COMPLETE** | All eight answered on 2026-08-27. See Section 13 |
| 4 — reformat, gate 8, drop `.lintr`, delete Group A prose | **COMPLETE** | `air format .` as one commit, 49 files, proven formatting-only three ways. Gate 8 added and tested in three directions. `.lintr` deleted; both its defects confirmed against installed lintr. A1, A2, A5, A6 deleted; `code-style.md` 618 -> 526. See "Two additions step 4 needed" below |
| 5 — core.md and trimmed CLAUDE.md | **COMPLETE** | CLAUDE.md 40 lines, core.md 94, sum 134 of 165. All 44 ledger rows mapped in `plans/ledger/mapping-claude-md.tsv`, 0 LOST. The narrowed "Design variables are sacred" banner was caught and restored |
| 6 — move and dedupe the 7 standards files | **COMPLETE** | 8 files moved with names kept; dedupes in two passes (`plans/ledger/changes-step6a.tsv`, `changes-step6b.tsv`). Every removal verified against the pinned inventory: 98 statements removed across both passes, each traced to an approved row or a quoted survivor. One narrow survivor (cluster 4) found and widened. New standing rule: a dedupe that would strip a portable file (`testing-standards.md`, `r-package-conventions.md`, `engineering-preferences.md`) in favour of a surveywts-only survivor is skipped — the portable file keeps its copy |
| 7 — agent definitions and dispatch prompts | **COMPLETE** | Step 0 read lists in all 9 definitions per the core.md role table; `Standards read:` contract on builder/tester/reviewer/shipper; reviewer checklist row added; stale auto-load claims removed from definitions and 6 skill files; builder/shipper restated rules removed with survivors quoted. Also fixed en route: shipper.md carried a malformed required-check name |
| 8 — skill decisions 13.5 to 13.8 | **COMPLETE** | Release family slash-only (4 flags); tdd, domain-modeling, codebase-design, grilling, spec-reviewer, new-package-setup.md removed with citations repointed; reference-map.yaml repaired — 66 of 66 paths resolve against `../analysis-sops/`, the two Valliant chapters corrected to `books/valliant_dever_kreuter_2018/` |
| 9 onward | not started | ready to begin |

### Two additions step 4 needed

Neither changes a decision. Both are recorded because a later reader will
otherwise find machinery the plan does not mention.

**1. `# nocov` markers move when air reformats.** covr drops a record only
when EVERY line of it is excluded. air split one statement in `R/utils.R`
across four lines, leaving the trailing `# nocov` on the closing paren alone,
and moved `# nocov start` off the `error = function(e) {` line in two places
in `R/jackknife-dagjk-utils.R`. Three expressions silently lost their
exclusion. The reformat commit holds air's output verbatim so it stays
reproducible; the next commit restores the markers. The set of expressions
covr excludes is now identical to the pre-reformat set: 0 lost, 0 added.

**2. The literal gate needed a way to record an approved removal.** Deleting
A1, A2, A5 and A6 takes 24 of the 874 literals out of the tree on purpose, so
the gate would have reported FAIL on every commit from here on.
`plans/ledger/literals.txt` stays pinned at 874 and never shrinks.
`plans/ledger/literals-retired.txt` records a removed literal against the
Section 5 row that approved it, and `check` subtracts those. It refuses a row
that names no approval, names a row that was KEPT (A3, A4, C3), or names a
literal that was never tracked; a retired literal still present in the tree
reports as a NOTE so the register cannot rot. Use this file for the Group B
and C deletions in steps 5 to 8 too.

Also fixed there: `literals.py check` died with UnicodeEncodeError while
printing a missing literal to a cp1252 console, so the gate could not report
its own failures.

---

### Start here, in a new session

Read this file, then Section 13, then start at step 4 of Section 10.

**Three things must not be redone.**

1. **Step 0 is settled.** `.claude/standards/` does not auto-load, in the main
   session or in a subagent. Two probes confirmed it. Do not re-run the canary.
2. **`plans/ledger/before-*.tsv` is a pinned contract.** 1,102 statements,
   enumerated at `45e8751` by nine agents, each blind to this plan and to every
   file but its own. It was built before any edit **on purpose**. Regenerating
   it after the restructure would produce an inventory shaped by the very thing
   it exists to audit. Never rebuild it. Read it, and append to the mapping
   columns in Phase B.
3. **`plans/ledger/literals.txt` passes today by construction.** 874 literals,
   every one confirmed present before admission. A later failure is therefore a
   real signal. Never fix a failure by deleting the literal.

---

## 0. What this plan does not touch

PR #91 already landed these. Do not re-plan them.

- Tester and shipper run on Sonnet.
- Review loops cap at 3 passes, with delta passes after the first.
- Agents no longer re-read the auto-loaded rules.
- Builder runs the full suite at most twice per PR.
- `.claude/scripts/run-gates.sh` runs all gates in one background command.
- Poll loops are banned for the tester and the shipper.

`fix/rules-factual-accuracy` also landed (commits `6c8d22a` through `45e8751`).
I spot-checked it rather than trusting it. Section 2.4 gives the results.

---

## 1. The measured baseline

### 1.1 What loads on every turn

I measured bytes with `wc -c` and converted at 4 characters per token. That
rate is conservative for Markdown with tables and code blocks. The real number
is 5 to 10 percent higher.

| File | Lines | Chars | ~Tokens |
|---|---:|---:|---:|
| `CLAUDE.md` | 84 | 4,182 | 1,045 |
| `.claude/rules/code-style.md` | 618 | 20,297 | 5,074 |
| `.claude/rules/function-documentation.md` | 490 | 20,555 | 5,138 |
| `.claude/rules/surveywts-conventions.md` | 235 | 12,591 | 3,147 |
| `.claude/rules/testing-surveywts.md` | 235 | 9,751 | 2,437 |
| `.claude/rules/testing-standards.md` | 288 | 9,623 | 2,405 |
| `.claude/rules/r-package-conventions.md` | 290 | 9,242 | 2,310 |
| `.claude/rules/github-strategy.md` | 268 | 9,155 | 2,288 |
| `.claude/rules/engineering-preferences.md` | 88 | 3,508 | 877 |
| **Total** | **2,596** | **102,096** | **~24,700** |

Two files hold 41 percent of the total: `code-style.md` and
`function-documentation.md`.

The tree also loads two smaller always-present blocks.

| Block | ~Tokens |
|---|---:|
| 29 project skill descriptions (25 register; 4 do not) | 2,733 |
| 9 agent descriptions | 591 |
| The user's global `~/.claude/CLAUDE.md` | 676 |

The global file loads into every subagent as well, which the step 0 probes
confirmed. At 39 lines it is immaterial against 24,700, and it lives outside
this repository, so this plan measures it and leaves it alone.

### 1.2 What a subagent pays before it does any work

This is the number that matters. I read the first turn of each subagent in
session `d5420ad5`. The first turn writes the whole frozen prefix to cache.

| Subagent | First-turn `cache_creation` | Turns | Cache read over its life |
|---|---:|---:|---:|
| `agent-a914bcb40bc4dcf4f` (Opus) | **68,471** | 66 | 7,385,014 |
| `agent-aadf61cc62df7f5c7` (Sonnet) | **73,246** | 394 | 90,488,954 |

`CLAUDE.md` plus the rules is about 24,700 of that prefix. So the rules are
**34 to 36 percent of every subagent's entry fee**, and the agent pays that
share again as a cache read on every turn it takes.

### 1.3 Where the money actually goes

The entry fee hurts short agents most. A lens agent that runs 15 turns pays
24,700 tokens of rules 15 times to apply one review criterion. A builder that
runs 394 turns pays the same rate but does real work with some of it.

One feature with 3 PRs dispatches roughly this many agents.

| Role | Dispatches | Rules it gets today | Rules it needs |
|---|---:|---|---|
| Review-lens `Explore` (spec and plan loops) | up to 30 | all 8 | none |
| `builder` | 3 | all 8 | 6 of 7 |
| `tester` | 3 | all 8 | 2 of 7 |
| `reviewer` | 3 | all 8 | 7 of 7 |
| `shipper` | 3 | all 8 | 1 of 7 |
| `planner` | 2 | all 8 | 4 of 7 |
| `extractor` | 0 to 3 | all 8 | none |

The 30 lens agents are the prize. They spend about 741,000 tokens of entry fee
per feature on material none of them reads.

### 1.4 The measurement command

```bash
python .claude/scripts/usage-profile.py \
  "C:/Users/jdennen/.claude/projects/C--Users-jdennen-surveywts" \
  <session-id>
```

The script prints per-model turns, cache create, cache read, and output. It
does not yet print the entry fee. Section 9 adds that.

---

## 2. What the research says, and what applies here

### 2.1 Sources

- Anthropic, *Effective context engineering for AI agents*.
- Anthropic Agent Skills documentation, the progressive disclosure model.
- The `superpowers:writing-skills` skill.
- The `mattpocock-skills:writing-for-agents` skill.
- The `example-skills:skill-creator` skill.
- Community write-ups on `CLAUDE.md` bloat (alexop.dev, Developers Digest,
  the dev.to 2026 guide).

### 2.2 The five ideas that apply

**1. Find the smallest set of high-signal tokens.** Anthropic states the goal
directly. Every token spends a finite attention budget, and long context also
degrades recall. A 24,700-token instruction block that a tester does not read
costs attention as well as money.

**2. Progressive disclosure is a hierarchy, not a token trick.** The
`writing-for-agents` skill ranks material three ways: an in-file step, in-file
reference, and disclosed reference behind a pointer. It gives one clean test
for which tier a piece belongs to. **Inline what every branch needs. Push
behind a pointer what only some branches reach.** Here the branch is the agent
role. That is why role-scoping is the right cut, and why a per-file detail tier
is the weaker one.

**3. A pointer is a variance bug when the target is a must-have.** The same
skill warns: "A must-have target behind a weakly worded pointer is a variance
bug: sharpen the wording first, and inline the material only if sharpening
fails." The prior audit found exactly this risk and could not test it. Section
8.7 tests it.

**4. Automate a mechanical rule instead of documenting it.** The
`writing-skills` skill says that if a rule is enforceable with a regex or a
validator, you automate it and save the document for judgment calls. About 220
lines of `code-style.md` describe indentation, line width, the pipe, and the
assignment operator. All four are already declared in `air.toml`, in
`.editorconfig`, and in `.lintr`. None of them run in a gate today.

**5. The environment is a source of truth. A document that copies it is a
cache.** A cache earns its cost only when the lookup is expensive. Copying
`.github/workflows/R-CMD-check.yaml` into `github-strategy.md` caches a cheap
lookup at a high price, and the copy goes stale.

### 2.3 What does not apply

- **Skill-body size limits.** The 500-line SKILL.md guidance targets skill
  bodies, which load on demand. The rules load unconditionally. They need a
  harder limit, not the same one.
- **The description-writing rules for triggering.** Those apply to the 29 skill
  descriptions in Section 7.2, not to the rules files.

### 2.4 Factual spot-check of the current rules

I did not trust `fix/rules-factual-accuracy`. I checked the source.

| Claim in the rules | Source check | Result |
|---|---|---|
| `NAMESPACE` holds 23 `export()` and nothing else | `grep -c '^export('` is 23; `^S3method(` is 0 | true |
| surveywts defines no classes | `grep -rn new_class R/` is empty | true |
| No `@importFrom` anywhere in `R/` | `grep -rn '@importFrom' R/` is empty | true |
| `air.toml` and `.editorconfig` are in the package root | both present | true |
| The `R/` file list in `surveywts-conventions.md` §3 | `ls R/` is 34 files, all named | true |
| The test file mapping in `testing-surveywts.md` | `ls tests/testthat/` is 19 files, all named | true |
| `weighted_df` is gone from the rules | no occurrence under `.claude/rules/` | true |

Two gaps the accuracy pass missed.

- **`.lintr` exists and no rules file names it.** It enforces
  `line_length_linter(80)`, `pipe_consistency_linter("native")`,
  `object_name_linter("snake_case")`, and `assignment_linter()`.
  `code-style.md:546` says air "is NOT `lintr`". That is true about air, but it
  reads as though lintr is not in the project. It is.
- **Six of the eight files still carry a `Version` / `Created` / `Status`
  header.** Commit `45e8751` removed two of eight. Sixteen lines remain and
  they track nothing.

---

## 3. Why the previous attempt failed

Two separate failures. Keep them separate. This plan must answer both.

**Failure 1 — conservation.** Nineteen rules were dropped and one prohibition
was silently widened, out of 533 normative statements. `wc -l`, a `grep -L` for
pointers, five spot greps, and `devtools::check()` all passed. None of those
can see a missing rule. Ten of the 19 losses were in
`function-documentation.md`, which has no prior art in surveycore. The losses
clustered in three shapes:

- A specific value inside an example — `Posit.air-vscode`, "~76 characters",
  `set.seed(seed)`.
- A tiebreaker sentence that resolved a conflict between two other rules — "do
  not substitute inline data as a workaround".
- A negative clause attached to a positive rule — "not just that it compiles".

**Failure 2 — reachability, untested.** 217 statements moved behind a pointer.
The audit verified that every pointer existed and carried a trigger. It could
not verify that any agent follows one, and it named this as the structural risk
the line counts hide. This plan treats a moved rule as unproven until an agent
is observed reaching it.

Two live skills were also left citing a deleted rule by path. Eight files cite
`function-documentation.md` by path today. A rename breaks all eight.

---

## 4. The proposed structure

### 4.1 Two always-loaded files

| File | Holds | Target |
|---|---|---:|
| `CLAUDE.md` | Orientation. What the package is. The release table. Where things live. The standards pointer table. | 55 lines or fewer |
| `.claude/rules/core.md` | The cross-role normative rules. Every rule that any role can violate. | 110 lines or fewer |

`.claude/rules/` keeps exactly one file. Everything a Claude Code session
auto-loads lives in these two files and nothing else.

`core.md` holds only rules that pass the every-branch test:

- The weight-column invariant. Never remove a weight column. Overwrite in place
  or write a new column and repoint `@variables$weights`.
- Every adjustment appends a history entry through `.make_history_entry()` and
  `.update_survey_weights()`.
- `wt_name = NULL` overwrites in place. A non-NULL name that collides throws
  `surveywts_error_wt_name_conflict`.
- Error and warning class naming, and the requirement of a `class=` on every
  `cli_abort()` and `cli_warn()`.
- Internal helpers carry a `.` prefix and are not exported.
- Every non-trivial change lives on a feature branch. Commits use Conventional
  Commits. The valid scope list.
- Run `devtools::document()` before committing a roxygen change. Run
  `devtools::check()` before opening a PR.
- The standards pointer table from Section 4.2.

### 4.2 Seven role-scoped standards files

These move to `.claude/standards/`, which does not auto-load.

| File | Read by |
|---|---|
| `code-style.md` | builder, reviewer, error-class-auditor |
| `function-documentation.md` | builder, planner, reviewer, snapshot-reviewer |
| `r-package-conventions.md` | builder, reviewer, tester |
| `surveywts-conventions.md` | builder, planner, reviewer, error-class-auditor |
| `testing-standards.md` | builder, planner, tester, reviewer, coverage-gap-finder |
| `testing-surveywts.md` | builder, planner, tester, reviewer, coverage-gap-finder |
| `github-strategy.md` | shipper, reviewer |
| `engineering-preferences.md` | planner, reviewer |

Keep every file name. Only the directory changes. That limits the citation
breakage to one path segment, and it makes the fix a single search and replace
across the eight citing files.

**Why the two testing files stay split.** They duplicate each other today, and
one role reads both, so merging would cut more. But `testing-standards.md`,
`r-package-conventions.md`, and `engineering-preferences.md` are written to be
copied into sibling surveyverse repos. That portability is real, and you
maintain sibling repos. So keep the split and add a hard rule instead: **the
package-specific file states nothing the generic file already states. It only
extends or overrides.** The conservation ledger checks this. Question 8 in
Section 12 asks whether you agree.

### 4.3 What moves where

| Content | Today | Proposed |
|---|---|---|
| Weight-column invariant, history entries, `wt_name` | `CLAUDE.md`, `code-style.md` §2 | `core.md`, one copy |
| Error class naming and the `class=` requirement | `CLAUDE.md`, `code-style.md` §3, `surveywts-conventions.md` | `core.md` for naming and the requirement; `standards/code-style.md` for the three-bullet structure and the markup table |
| Branch and commit rules | `CLAUDE.md`, `github-strategy.md` | `core.md` for naming and scopes; `standards/github-strategy.md` for tiers, merge strategy, versioning, release |
| `document()` and `check()` cadence | 4 places | `core.md`, one copy |
| Return-value visibility table | `code-style.md` §4, `surveywts-conventions.md` §4 and quick ref | `standards/surveywts-conventions.md`, one copy |
| Internal helper placement | `code-style.md` §4 and quick ref, `surveywts-conventions.md` §3 | `standards/surveywts-conventions.md`, one copy |
| Internal helper doc tiers | `code-style.md` §5, `function-documentation.md` | `standards/function-documentation.md`, one copy |
| Export policy, NAMESPACE hygiene, `::` style, version pinning, check targets | `code-style.md` §5, `r-package-conventions.md` §3 and §4, `surveywts-conventions.md` §5 and §8 | `standards/r-package-conventions.md`, one copy; the surveywts extensions stay in `standards/surveywts-conventions.md` |
| Dataset codoc rule | `r-package-conventions.md` §2 in full, `function-documentation.md` as a pointer | unchanged; already correct |
| S7 patterns, input gates, dispatch rule, argument-order precedence | `code-style.md` §2 and §4 | `standards/code-style.md` |
| Per-function argument-order table | `surveywts-conventions.md` §7 | `standards/surveywts-conventions.md` |
| Documentation tiers 1 to 4 | `function-documentation.md` | `standards/function-documentation.md`, shape unchanged |
| Mechanical formatting rules | `code-style.md` §1 and §6 | see Section 5.1 |

### 4.4 Making the read reliable

A pointer in a rules file is the weak form. Use the strong form instead.

**Step 0 in each agent definition.** Each definition already has a "Receives"
section that says the rules auto-load. Replace that line with a numbered first
step.

```
## Step 0 — Read your standards

Before anything else, read these files in full:

1. `.claude/standards/code-style.md`
2. `.claude/standards/surveywts-conventions.md`
3. ...

Then record the list under `Standards read:` in your output artifact.
```

This puts the material at the top of the information hierarchy, as a step,
rather than as reference behind a pointer.

**A completion criterion the reviewer can check.** Each artifact —
`implementation.md`, `audit.md`, `review.md`, `shipper.md` — gains a required
`Standards read:` line. The reviewer's checklist gains one row: the line is
present, and it lists the files that role's definition names. That turns "did
it read?" into something observable, which is what makes Section 8.7 possible.

**For dispatch prompts, not agent definitions.** A lens agent or an `Explore`
agent has no definition to edit. The dispatching skill names the one standards
file that lens needs inside the dispatch prompt, or it names none.

**For an interactive session.** The main session loses the rules from context.
`CLAUDE.md` gains one line: before you write or review R code, read the
standards file for what you are writing. The pointer table in `core.md` says
which one.

### 4.5 Estimated result

| Tier | Today | Target | Change |
|---|---:|---:|---:|
| Always loaded (`CLAUDE.md` plus rules) | 2,596 lines, ~24,700 tok | ~165 lines, ~1,700 tok | **−93%** |
| Standards tier, read by role | — | ~1,785 lines, ~17,600 tok | — |
| Sum of both | 2,596 lines | ~1,950 lines | −25% |

The standards tier only shrinks about 29 percent. That is honest. The
deduplication clusters are real but each one is small, and
`function-documentation.md` is genuine reference with little duplication in it.

The win is that no role reads the whole tier.

| Role | Rules cost today | Rules cost after | Change |
|---|---:|---:|---:|
| Review-lens `Explore`, `extractor` | 24,700 | 1,700 | **−93%** |
| `shipper` | 24,700 | 3,600 | **−85%** |
| `tester` | 24,700 | 6,000 | **−76%** |
| `planner` | 24,700 | 10,100 | **−59%** |
| `builder` | 24,700 | 16,300 | **−34%** |
| `reviewer` | 24,700 | 19,300 | **−22%** |

Read this table honestly. Builder and reviewer barely gain from scoping. Their
gain comes only from deduplication and deletion. The scoping gain concentrates
in the narrow, short-lived agents, and those are the majority of dispatches.

Predicted subagent entry fee, against the measured 68,471 baseline:

| Role | Entry fee today | Entry fee after |
|---|---:|---:|
| Review-lens `Explore` | 68,471 | ~45,500 |
| `tester` | ~73,200 | ~54,500 |
| `builder` | 68,471 | ~60,100 |

One caveat. A file the agent reads with the `Read` tool arrives with line
number prefixes. That adds roughly 10 percent to the standards tier's real cost
compared with auto-loading the same bytes. The tables above do not include it.
Add about 1,700 tokens to a builder's figure.

---

## 5. Deletions proposed, for your approval

Nothing here is deleted without a line-by-line yes from you. Each row names
what would enforce the rule afterward.

### 5.1 Group A — mechanical style rules

**These are conditional on approving a new gate 8.** Today `air.toml`,
`.editorconfig`, and `.lintr` all exist and **nothing runs them**. There is no
git hook, no pre-commit config, no lint or format step in any of the three CI
workflows, and no lint gate in `run-gates.sh`. So these rules are declared but
not enforced. Deleting the prose today would drop them entirely.

The proposal is a trade: add gate 8, then delete the prose.

```
Gate 8: air format --check . && Rscript -e 'lintr::lint_package()'
```

| # | Statement | Source | Enforcer after the trade |
|---|---|---|---|
| A1 | "2 spaces per indent level. No tabs." | `code-style.md` §1 | `air.toml indent-width = 2`, `.editorconfig`, gate 8 |
| A2 | "80 characters maximum." | `code-style.md` §1 and quick ref | `air.toml line-width = 80`, `.lintr line_length_linter(80)`, gate 8 |
| A3 | "Native pipe only. `%>%` is never used." | `code-style.md` §1 and quick ref | `.lintr pipe_consistency_linter("native")`, gate 8 |
| A4 | "`<-` for all assignments. `=` is reserved for function arguments only." | `code-style.md` §1 | `.lintr assignment_linter()`, gate 8 |
| A5 | The `air` install command, the format-on-save setup for Positron, VS Code, and RStudio, and the manual format commands | `code-style.md` §6 | `air --help`; this is a cache of the tool's own docs |
| A6 | The inlined contents of `air.toml` and `.editorconfig` | `code-style.md` §6 | the two files, in the package root |

**Not proposed for deletion, even under the trade:** "Do not manually adjust
spacing after running `air`. If `air` output looks wrong, there is a syntax
problem." That is a judgment call, not a mechanical constraint, and the prior
pass lost it. It moves to `standards/code-style.md`.

**If you decline gate 8,** A1 through A4 stay as one-line rows in
`standards/code-style.md`, and only A5 and A6 are deleted.

### 5.2 Group B — caches of the environment

| # | Statement | Source | The real source of truth |
|---|---|---|---|
| B1 | The R-CMD-check matrix YAML block | `github-strategy.md` | `.github/workflows/R-CMD-check.yaml` |
| B2 | The PR template body, reproduced inline | `github-strategy.md` | `.github/PULL_REQUEST_TEMPLATE.md` |
| B3 | The GitHub merge-settings checkbox list | `github-strategy.md` | a one-time repo setting, not an agent instruction |
| B4 | The branch-protection settings list | `github-strategy.md` | same |
| B5 | The `test_invariants()` function body, 26 lines | `testing-surveywts.md` | `tests/testthat/helper-test-data.R` |
| B6 | The `DESCRIPTION` field template | `r-package-conventions.md` §5 | `DESCRIPTION` |
| B7 | The `surveypkg-package.R` template, written as a surveytidy example | `r-package-conventions.md` §5 | `R/surveywts-package.R` |

For B1 through B4, the rule that *uses* the value stays. The required status
check is `R-CMD-check / ubuntu-latest (release)`, and an agent cannot derive
that, so it stays. The YAML that produces it goes.

For B5, the *requirement* stays. Every constructor test calls
`test_invariants(obj)` as its first assertion, and two sentences describe the
three branches. The 26-line body goes.

### 5.3 Group C — self-restatement

| # | Statement | Source | Why |
|---|---|---|---|
| C1 | "Summary for All Packages", 11 lines | `r-package-conventions.md` | restates §1 through §5 of the same file |
| C2 | Six `Version` / `Created` / `Status` headers, 16 lines | six rules files | they track nothing; `45e8751` removed two of eight |
| C3 | "How to apply these during review", 8 lines | `engineering-preferences.md` | restates the five numbered principles above it as five questions |

C3 is the only debatable one. It reframes the principles as review questions,
which is a different use. I am flagging it rather than assuming.

### 5.4 What is explicitly not deleted

- Every specific value. The tolerances `1e-10` and `1e-8`. The version bounds
  `cli (>= 3.6.0)`, `rlang (>= 1.1.0)`, `S7 (>= 0.1.0)`, `testthat (>= 3.0.0)`.
  The coverage floors 98 and 95. `min_cell = 20`, `max_adjust = 2.0`,
  `n_cells = 5`. The bounds `c(1e-6, 1e6)`. `maxit = 25L` and `epsilon = 1e-8`.
  The "~76 characters" dash width. The 23 export names. Every error and warning
  class name.
- Every tiebreaker sentence. These resolve a conflict between two other rules,
  and the prior pass lost three of them.
- Every negative clause attached to a positive rule: "not just that it
  compiles", "do not substitute inline data as a workaround", "never a string".

---

## 6. The deduplication register

Twenty-six clusters state one meaning in two or more places. Each becomes one
source of truth. The ledger records the surviving location for every dropped
copy.

| # | Meaning | Stated in | Survivor |
|---|---|---|---|
| 1 | `::` everywhere, no `@importFrom` | `code-style` §5, `r-package-conventions` §3, `surveywts-conventions` §8, `builder.md:94` | `standards/r-package-conventions.md` |
| 2 | `NAMESPACE` is generated, never hand-edited | 3 places | `standards/r-package-conventions.md` |
| 3 | Check targets 0/0/2 and the two pre-approved notes | 3 places | `standards/r-package-conventions.md` |
| 4 | Return-value visibility | `code-style` §4, `surveywts-conventions` §4 and quick ref | `standards/surveywts-conventions.md` |
| 5 | Internal helper placement | `code-style` §4 and quick ref, `surveywts-conventions` §3 | `standards/surveywts-conventions.md` |
| 6 | Internal helper doc tiers | `code-style` §5, `function-documentation` | `standards/function-documentation.md` |
| 7 | Error and warning class naming | `CLAUDE.md`, `code-style` §3, `surveywts-conventions` quick ref and §1 | `core.md` |
| 8 | `class=` required on every abort and warn | `code-style` §3, twice | `core.md` |
| 9 | Export policy and no re-exports | `code-style` §5, `r-package-conventions` §3 and quick ref, `surveywts-conventions` §5 | `standards/r-package-conventions.md` for the generic rule; `standards/surveywts-conventions.md` for the 23 names |
| 10 | Minimum version pinning, no `==` | `code-style` §5, `r-package-conventions` §4 | `standards/r-package-conventions.md` |
| 11 | `document()` before commit, `check()` before PR | `CLAUDE.md`, `code-style` §5, `r-package-conventions` §4, `surveywts-conventions` §8 | `core.md` |
| 12 | Print methods live in `methods-print.R`, registered in `.onLoad()` | `code-style` §2 and quick ref, `surveywts-conventions` §3 and §6 | `standards/surveywts-conventions.md` |
| 13 | `S7_inherits()` with the class object, never a string | `code-style` §2, §4 and quick ref, `engineering-preferences` §5 | `standards/code-style.md` |
| 14 | `@family` tags | `surveywts-conventions` §2, `code-style` §5, `function-documentation` | `standards/surveywts-conventions.md` §2 |
| 15 | `@returns` required, plural spelling | `code-style` §5, `function-documentation`, `surveywts-conventions` §8 | `standards/function-documentation.md` |
| 16 | `@examples` must run; `\dontrun{}` only for external resources | `code-style` §5, `function-documentation`, `r-package-conventions` | `standards/function-documentation.md` |
| 17 | Dataset codoc `\describe{}` rule | `r-package-conventions` §2 in full, `function-documentation` as a pointer | already correct; no change |
| 18 | `skip_if_not_installed()` is block-level | `testing-standards` §4, `testing-surveywts` | `standards/testing-standards.md` |
| 19 | Dual error-test pattern, and `class=` only for structural validators | `testing-standards` quick ref and §3, `testing-surveywts` quick ref and layers | `standards/testing-standards.md` for the pattern; `standards/testing-surveywts.md` for which layer carries which class prefix |
| 20 | Coverage 98 floor, 95 blocks | `testing-standards` quick ref and §2, `engineering-preferences` §2 | `standards/testing-standards.md` |
| 21 | Argument-order precedence and the per-function table | `code-style` §4, `surveywts-conventions` §7 | precedence in `standards/code-style.md`; the table in `standards/surveywts-conventions.md`; the duplicated `ipw()` and `calibrate_rake()` examples drop |
| 22 | `wt_name = NULL` overwrites in place | `CLAUDE.md`, `code-style` §2, `code-style` §4 | `core.md` |
| 23 | History entries via the two helpers | `CLAUDE.md`, `code-style` §2 | `core.md` for the requirement; `standards/code-style.md` for the code shape |
| 24 | Branch naming prefixes | `CLAUDE.md`, `github-strategy` quick ref and table | `core.md` for the prefix list; `standards/github-strategy.md` for the target branch per prefix |
| 25 | Conventional Commits and the valid scopes | `CLAUDE.md`, `github-strategy` | `core.md` |
| 26 | Naming for helpers, validators, engines, constructors | `CLAUDE.md`, `surveywts-conventions` §1 | `core.md` for the `.` prefix rule; `standards/surveywts-conventions.md` for the full table |

A dedupe is not a deletion. Even so, every one of these 26 gets a ledger row
that names the surviving file and line, and the auditing agent reads it there
before marking the row deduped. That is the discipline the prior pass skipped.

---

## 7. The rest of the `.claude/` tree

### 7.1 Agent definitions — 997 lines

| Change | Detail |
|---|---|
| Step 0 read list | Replace the "rules auto-load, do not read them again" line with a numbered read list per Section 4.4 |
| `Standards read:` output line | Add to the "Produces" contract of builder, tester, reviewer, and shipper |
| Remove rules restated in agent bodies | `builder.md:94` restates the `@importFrom` rule. Three rules files state it and `r-package-profile.md` grep-enforces it. Sweep all nine definitions for this pattern |
| Fix the shipper inconsistency | `shipper.md` is the only definition whose "Receives" section never mentions the rules, though they load for it too |
| Update the 8 path citations | Five agent definitions and three skills cite `.claude/rules/function-documentation.md`. All move to `.claude/standards/` |

### 7.2 Skills — 17,528 lines, about 2,733 always-loaded tokens

Only the descriptions load. The bodies are already on demand. Four findings.

**F1 — four skills exist but do not register.** `improve-codebase-architecture`
(189 lines), `teach` (284), `grill-me` (7), and `grill-with-docs` (7) have
frontmatter but do not appear in the available-skills list. That is 487 lines
that nothing can reach. Diagnose the frontmatter, then either fix or remove.
This needs your decision.

**F2 — four skills duplicate a plugin skill.** The project ships `tdd`,
`domain-modeling`, `codebase-design`, and `grilling`. The `mattpocock-skills`
plugin ships all four under the same names. Both sets appear in the
available-skills list, so the agent must choose between two skills with the same
name and similar descriptions. The token cost is small, about 195. The ambiguity
cost is real. I recommend removing the project copies unless they diverge from
upstream. This needs your decision.

**F3 — one skill is a tombstone.** The `spec-reviewer` description reads: "This
skill has been absorbed into spec-workflow Stage 3. Use `/spec-workflow stage 3`
instead. Kept here to avoid broken references." That is 81 lines plus 34
always-loaded tokens. Find what references it, repoint, then remove.

**F4 — the ten longest descriptions read as workflow summaries, not
triggers.** `spec-workflow` spends 191 tokens, `cli` spends 178, and `auto-ship`
spends 167. The `writing-skills` skill documents a specific failure this causes:
when a description summarizes the workflow, the agent follows the description
and skips the body. Rewriting the top ten to triggers only, at about 60 tokens
each, saves roughly 800 always-loaded tokens **and** improves compliance with
the skill bodies. This is the one place in this plan where cutting tokens and
improving behavior point the same way.

**Not proposed:** touching the vendored skill bodies. `cli` is 4,922 lines and
`testing-r-packages` is 2,062, but both load only on demand and both are pinned
to an upstream commit. Editing them breaks the pin.

### 7.3 Orphans

| File | Lines | Finding |
|---|---:|---|
| `.claude/reference-map.yaml` | 187 | Nothing in the repo reads it. Every `file:` path points at `/Users/jacobdennen/analysis-sops/...`, a macOS path that does not exist on this machine. The citations in it are still useful. I recommend keeping the citations, fixing or dropping the dead paths, and adding one pointer from `core.md` so it becomes reachable. Needs your decision |
| `.claude/WORKFLOW.md` | 140 | Cited once, from `CLAUDE.md:76`. Reachable. Keep |
| `.claude/skills/changelog-workflow.md` | 90 | Cited from `github-strategy.md`. It is a loose `.md` at the skills root, not a skill directory, so it never registers. That is correct for a reference. Keep |
| `.claude/skills/new-package-setup.md` | 10 | Cited by nothing. Needs your decision |

---

## 8. The conservation gate

This is the merge gate. Line counts and lint checks do not pass it.

### 8.1 The counting rule, fixed before anything starts

Reuse the prior audit's rule word for word, so the counts stay comparable.

> One statement per table row, per prose rule, and per distinct constraint
> stated inside a code comment or example.

A **normative statement** is anything that tells a developer what to do, what
not to do, or what a value must be. It includes table rows, prose rules,
constraints stated only inside a code comment or an example, and every specific
value: a tolerance, a line width, a version bound, a file path, a naming
pattern, an error class name.

The prior audit counted 533 statements at commit `31fe7ec`. The accuracy pass
changed the files, so 533 is not the target. Re-enumerate from `45e8751`.

**Do not use 533 as a target, and do not treat a higher count as an error.**
The first six inventory agents returned 553 rows between them, with the three
largest files still running. The projected total is near 1,000, roughly double
the prior audit.

The extra rows are granularity, not invention. This inventory splits a compound
sentence into its separately checkable parts, gives a negative clause its own
row where the clause is independently losable, and records a restatement as its
own row rather than silently folding it into the original. Every one of the
three loss shapes in Section 3 is a fragment of a larger sentence, so a coarser
count is exactly what let them through last time.

Finer rows cost more in Phase B, because there are more of them to locate. That
is the trade, and it is the right way round: a row that is too small is
cheap to verify, and a row that is too large hides a loss inside itself.

### 8.2 Phase A — the inventory, built before any edit

Run this first, on the untouched tree. The inventory must not be shaped by the
restructure.

- One agent per source file. Nine agents: `CLAUDE.md` plus the eight rules.
- Each agent sees **only** its BEFORE file, pinned as
  `git show 45e8751:.claude/rules/<name>.md`. It gets no access to any plan, any
  proposed structure, or any other file.
- Output is a TSV fragment, one row per statement.

```
id  source_file  source_line  verbatim  category
```

- Commit all nine fragments as `plans/ledger/before-<name>.tsv`. This is the
  contract. Nobody edits it after the restructure begins.

### 8.3 Phase B — the mapping, after the edits

- One agent per fragment, and a different agent from the one that built it.
- Each receives its fragment plus read access to the whole AFTER tree.
- For every row it must return one classification.

| Class | Meaning | Evidence required |
|---|---|---|
| PRESERVED | still in an always-loaded file | file and line |
| MOVED | now in a standards file | file and line |
| DEDUPED | dropped here because another file states it | the surviving file and line, read and quoted |
| DELETED | removed on purpose | the approval row from Section 5 |
| ALTERED | present but the meaning changed | both texts, side by side |
| LOST | cannot be found anywhere under `.claude/` | none |

- A matching heading is not evidence. Quote the normative content.
- Instruct the agent adversarially. It must report an uncertain row as a
  finding, not as fine. The prior audit's phrasing worked, so reuse it.

### 8.4 Phase C — reconciliation, the actual gate

| Condition | Verdict |
|---|---|
| Any LOST row | BLOCK |
| Any ALTERED row | BLOCK |
| Any DELETED row without a matching approved row from Section 5 | BLOCK |
| Any DEDUPED row whose survivor the agent did not quote | BLOCK |
| Otherwise | PASS |

### 8.5 The literal check — a script, not an agent

Three of the prior 19 losses were a specific value inside an example. A script
catches those every time, and it keeps working after this project ends.

Two files, both written and both green on the untouched tree:

- `.claude/scripts/literals.py` — `extract`, `merge`, `check`.
- `.claude/scripts/check-literals.sh` — the gate. Calls `literals.py check`,
  then runs the citation, force-load, and reachability checks in Section 8.6.

**The list has two independent sources, on purpose.** `extract` runs a regex
pass over the BEFORE files at the pinned ref and found 283. `merge` folds in
the `literals` column the nine inventory agents recorded and admitted 596 more,
for **874**. A literal that only one source saw still lands in the list. That
redundancy is the reason for doing it twice.

**Whitespace is normalised on both sides before comparison.** This is not a
detail; without it the check is worse than useless. Markdown prose wraps, and a
restructure re-wraps it on nearly every edit. The source holds

```
present tense: "Clip weights to a
range", not "Clipping of weights"
```

while the literal recorded for it is `Clip weights to a range`. A raw byte
comparison reports a loss that never happened, and a gate that cries wolf gets
switched off. Collapsing every run of whitespace to one space on both sides
makes the check immune to re-wrapping. Three of the four rejects in the first
merge run were this and nothing else. Because both `merge` and `check` must
apply the identical rule, the comparison lives in one Python module rather than
being written twice, once there and once in bash.

**A literal is admitted only if it is present in the tree today.** A candidate
that cannot be found on the untouched tree is a transcription artifact — a
normalised call such as `.get_history()` where the source writes
`.get_history(data)` — not evidence of a loss. Admitting one would poison the
baseline, because every later run would report a failure that was never real.
Rejects go to `plans/ledger/literals-rejected.txt` for review rather than
disappearing. One candidate was rejected: `{.code}`, where the source only ever
writes `{.code nest = TRUE}`.

This check would have caught the `Posit.air-vscode` loss, the "~76 characters"
loss, and the `set.seed(seed)` loss on its own.

### 8.6 The path and citation check — also a script

Extend the same script with three assertions.

1. Every `.claude/...` path cited anywhere in the repo resolves to a file that
   exists. This catches the two skills that were left citing a deleted rule.
2. Every file in `.claude/standards/` is named by at least one agent definition,
   dispatch prompt, or `core.md` pointer. An unreachable standards file is a
   silent loss.
3. No `@`-prefixed force-load link appears anywhere under `.claude/`.

### 8.7 The reachability test

This answers the second failure in Section 3. A moved rule is unproven until an
agent is seen reaching it.

**Design.** Seven cases, one per standards file. Each case is a small, real task
that an agent can only do correctly by using a rule that lives **only** in that
standards file, never in `core.md`.

| Role | Task shape | The rule it must reach |
|---|---|---|
| builder | Add one argument to an existing exported function | The argument-order precedence in `code-style.md` |
| builder | Write roxygen for one new Tier 3 function | The required `@section Convergence` in `function-documentation.md` |
| tester | Write a test for one new error class | The dual pattern in `testing-standards.md` |
| tester | Write a constructor test | `test_invariants()` first, from `testing-surveywts.md` |
| planner | Draft one test-spec section | The tolerance table in `testing-surveywts.md` |
| shipper | Prepare a release PR | The `origin/develop..origin/main` check in `github-strategy.md` |
| reviewer | Review a diff that adds an export | The export policy in `r-package-conventions.md` |

**Measurement, per case.**

1. Did the transcript show a `Read` of the standards file? Observable.
2. Did the output honor the rule? Observable.
3. Did the artifact carry the `Standards read:` line? Observable.

**Baseline arm.** Run the same seven cases against the current always-loaded
tree first. That gives a compliance delta, not an absolute. A rule the agent
also fails today is not a regression this change caused.

**Threshold.** Three trials per case. If any role skips its read on any trial,
that role's material does not stay behind a read. It goes back into `core.md`.
This makes the "sharpen the wording first, inline only if sharpening fails"
discipline into a gate.

---

## 9. How success is measured

### 9.1 Primary metric — the subagent entry fee

Deterministic, cheap, and directly attributable to this change.

Add an `--entry-fee` mode to `.claude/scripts/usage-profile.py`. It prints the
first-turn `cache_creation_input_tokens` for the main session and for each
subagent. That is about 15 lines of Python on top of the existing `scan()`.

| Measurement | Value |
|---|---|
| Baseline, measured today | 68,471 for the Opus subagent, 73,246 for the Sonnet subagent |
| Target, review-lens agent | 47,000 or lower |
| Target, builder | 62,000 or lower |
| Target, tester | 56,000 or lower |

### 9.2 Secondary metric — cost per feature

Run one Tier-3-sized change end to end through the pipeline after the work
lands. Profile it with `usage-profile.py`. Report:

- Total cache-read tokens, by model.
- The number of subagent dispatches.
- The mean entry fee per dispatch.

No recorded full pipeline run exists on the current tree, so this figure is a
forward baseline, not a before-and-after. Say that in the report rather than
implying a comparison that nobody made.

### 9.3 Quality metric — no regression

- The reachability test in Section 8.7 passes for all seven roles.
- The confirmatory pipeline run produces the usual verdict kinds. No new BLOCK
  is caused by a missing standard.
- `run-gates.sh` passes on the confirmatory run.

### 9.4 What is not a success metric

`wc -l`. That is the measure that passed while 19 rules went missing.

---

## 10. Order of work

| # | Step | Gate before moving on |
|---|---|---|
| 0 | Verify `.claude/standards/` does not auto-load. Create the directory with one throwaway file, start a fresh session, and check whether it appears in the system prompt | If it does auto-load, the whole structure changes. Stop and re-plan |
| 1 | Build the Phase A inventory from Section 8.2. Commit the nine TSV fragments | Nine fragments exist and total 520 to 560 rows |
| 2 | Build `check-literals.sh` from the BEFORE tree. Confirm it passes on the untouched tree | Exit 0 today |
| 3 | Get your approval on the Section 5 deletions and the Section 7 decisions | A written yes, row by row |
| 4 | If gate 8 is approved, add it to `run-gates.sh` and `r-package-profile.md`. Confirm it passes on `develop` today | Gate 8 green before any prose is deleted |
| 5 | Write `core.md` and the trimmed `CLAUDE.md` | 165 lines or fewer, combined |
| 6 | Move and dedupe the seven standards files, one file per commit | Each commit passes `check-literals.sh` |
| 7 | Update the eight path citations, the nine agent definitions, and the dispatch prompts | The path check passes |
| 8 | Apply the Section 7 skill decisions | none |
| 9 | Run Phase B and Phase C from Sections 8.3 and 8.4 | PASS, with no LOST and no ALTERED rows |
| 10 | Run the reachability test from Section 8.7, both the baseline arm and the treatment arm | All seven roles read their files on 3 of 3 trials |
| 11 | Run the confirmatory pipeline change and profile it per Section 9.2 | The report is written |

Steps 1 and 2 come before any edit. That is the whole lesson of the prior
attempt.

---

## 11. Risks

| Risk | Mitigation |
|---|---|
| An agent skips its Step 0 read | Section 8.7 tests this per role. A role that fails gets its material inlined back into `core.md` |
| `.claude/standards/` turns out to auto-load | Step 0 of Section 10 checks this before anything else. surveycore's `.claude/references/` does not auto-load, so this is likely fine, but I did not verify it on this machine |
| The Phase A inventory misses a statement | The inventory is per-file and adversarial, and the literal script catches the value class on its own. A statement that escapes both was also invisible to the prior audit. Accepted risk, stated |
| The interactive main session loses the rules | `CLAUDE.md` gains a one-line instruction and `core.md` carries the pointer table. This is a real, accepted loss of convenience for interactive work |
| The mechanical style prose is deleted while gate 8 is flaky | Gate 8 must run green on an untouched `develop` before any prose is deleted, per step 4 |
| A dedupe silently widens or narrows a prohibition | The ALTERED class exists for exactly this, and it BLOCKs. It caught the one instance last time |
| The reachability test is expensive | Seven cases, three trials, two arms is 42 short dispatches. At about 47,000 entry fee each that is roughly 2M tokens. That is about one fifth of what the 30 lens agents waste on one feature today |

---

## 12. Open questions for you

1. **Gate 8.** Add `air format --check` and `lintr::lint_package()` as a gate,
   then delete the Group A prose? Or keep the prose and skip the gate?
2. **Section 5 deletions.** Approve, reject, or amend each of A1 to A6, B1 to
   B7, and C1 to C3.
3. **F1, the four unregistered skills.** Fix the frontmatter, or remove them?
4. **F2, the four skills that duplicate the mattpocock plugin.** Remove the
   project copies, or keep them and rename?
5. **F3, `spec-reviewer`.** Remove it after repointing, or keep the tombstone?
6. **`reference-map.yaml`.** Fix the dead macOS paths, or drop the paths and
   keep only the citations?
7. **`new-package-setup.md`.** Keep or remove?
8. **The testing split.** Keep `testing-standards.md` and `testing-surveywts.md`
   separate for portability to sibling repos, as proposed? Or merge them and
   accept the loss of the clean copy boundary?

---

## 13. Decisions (approved 2026-08-27)

All eight questions in Section 12 are answered. These supersede Section 12.

### 13.1 Gate 8 and Group A — air only, after a reformat commit

**Approved:** add gate 8 as `air format --check .` only. Delete A1, A2, A5, A6.
Keep A3 and A4 as one-line rows in `standards/code-style.md`.

Three measurements drove this, all taken on 2026-08-27 against `45e8751`:

| Check | Result |
|---|---|
| `air format --check .` | 49 files fail: 24 of 34 in `R/`, 18 in `tests/`, 7 in `data-raw/` |
| `.lintr` parse | fails; see 13.2 |
| `lintr::lint_package()` with `.lintr` repaired | 2,045 lints — 1,360 line-length, 302 object-usage, 184 commented-code, 162 object-name |

`code-style.md` describes a formatting regime that has never existed. air is
reachable in one mechanical step; lintr is not, because roughly 650 lints
survive whatever air fixes and each needs a real code change.

**Order matters.** Run `air format .` as its own commit, touching no logic,
before gate 8 is added and before any Group A prose is deleted.
`code-style.md` already requires a reformat to be committed separately from a
functional change. Gate 8 must run green on `develop` before a single line of
A1, A2, A5, or A6 comes out.

A3 (native pipe) and A4 (`<-` for assignment) stay as prose because, with
`.lintr` gone, prose is their only enforcement. That is an honest state and it
is better than a config that claims to check them and never runs.

### 13.2 `.lintr` — delete

**Approved:** remove `.lintr`.

It carries two independent bugs and has therefore never run:

1. The closing `)` sits at column 0. DCF format requires a continuation line to
   be indented, so the file cannot be parsed at all.
2. `pipe_consistency_linter("native")` — the accepted values are `"|>"`,
   `"%>%"`, and `"auto"`. `"native"` is not one of them.

A config that does nothing is a claim the project does not honor. Deleting it
makes the standards documentation true again. Note that no rules file has ever
named `.lintr`, so nothing points at it.

### 13.3 Group B — delete all seven

**Approved:** B1 through B7.

In every case the rule that *uses* the value stays. The required status check
name `R-CMD-check / ubuntu-latest (release)` stays; the CI matrix YAML that
produces it goes. The requirement that every constructor test calls
`test_invariants(obj)` first stays; the 26-line copy of its body goes.

### 13.4 Group C — delete C1 and C2, keep C3

**Approved:** delete the "Summary for All Packages" block and the sixteen lines
of `Version` / `Created` / `Status` headers across six files. Keep "How to
apply these during review": it reframes the five principles as review
questions, which is a different use rather than a restatement.

### 13.5 Skills — slash-only for the release family

**Correction to F1.** The finding was wrong. `improve-codebase-architecture`,
`teach`, `grill-me`, and `grill-with-docs` are not broken. All four carry
`disable-model-invocation: true`, which is why they are absent from the
available-skills list. They are deliberately slash-command-only.

That turns the defect into a lever: such a skill costs **zero** always-loaded
description tokens and stays fully available on demand.

**Approved:** apply `disable-model-invocation: true` to the release family —
`merge-main` (132 tok), `cran` (128), `release-post` (140), and
`create-release-checklist` (40). About 440 tokens off every dispatch at no
behavioral risk, because a model should never start a CRAN submission or a
release to `main` because a conversation drifted near the subject.

Not applied to the pipeline orchestrators. Keeping those model-invocable means
the model can still reach for `pipeline-ship` when work is ready, rather than
waiting for an explicit command.

### 13.6 F2 — remove the four duplicated project skills

**Approved:** delete the project copies of `tdd`, `domain-modeling`,
`codebase-design`, and `grilling` unconditionally, without diffing against the
`mattpocock-skills` plugin. The plugin is the maintained upstream.

Saves about 195 always-loaded tokens, and removes a same-name collision the
model has to resolve on every relevant task.

### 13.7 Orphans

| Item | Decision |
|---|---|
| `spec-reviewer` | **Remove**, after repointing whatever still cites it to `/spec-workflow stage 3`. Its own description says it was absorbed and is "kept here to avoid broken references". The citation check confirms nothing dangles |
| `new-package-setup.md` | **Remove.** Ten lines, cited by nothing, and a loose `.md` at the skills root never registers as a skill either |
| `.claude/reference-map.yaml` | **Keep and repair.** See 13.8 |

### 13.8 `reference-map.yaml` — repair the paths, keep the file

The knowledge base does exist, at `C:\Users\jdennen\analysis-sops`. Only the
path prefix was wrong.

**Approved:** rewrite paths as sibling-relative.

1. Replace the prefix `/Users/jacobdennen/analysis-sops/` with
   `../analysis-sops/` — 62 of 66 paths then resolve.
2. Correct the two Valliant chapters. They are recorded under `papers/` but the
   book lives in `books/valliant_dever_kreuter_2018/`. That is a wrong
   subdirectory, not a missing file. Fixing it brings the total to **66 of 66**.
3. Leave the four `file: ~` entries. They correctly mean the paper is not in
   the knowledge base.
4. Add one pointer from `core.md` so the file is reachable at all. Today
   nothing in the repo reads it.

Sibling-relative rather than an environment variable, because `analysis-sops`
already sits beside `surveywts` in the same parent, the repo already uses
`../surveycore` the same way, and no per-machine configuration is then needed.
If the repos ever stop being siblings, the fallback is an env var
`$SURVEY_KNOWLEDGE` defaulting to `../analysis-sops`.

### 13.9 The testing split — keep it, add a no-restatement rule

**Approved:** `testing-standards.md` (generic, portable) and
`testing-surveywts.md` (package-specific) stay separate, preserving the copy
boundary to surveycore and future siblings.

New rule, checked by the conservation ledger: **the package-specific file
states nothing the generic file already states. It may only extend or
override.** The same rule applies to the other two portable pairs —
`r-package-conventions.md` and `engineering-preferences.md` against their
surveywts counterparts.

### 13.10 What these decisions change in the earlier sections

| Section | Change |
|---|---|
| 5.1 | Group A resolves to: delete A1, A2, A5, A6; keep A3, A4. Gate 8 is air-only |
| 5.2 | Group B all approved |
| 5.3 | C1 and C2 approved; C3 withdrawn |
| 7.2 F1 | Withdrawn — the four skills are correctly configured. Replaced by the slash-only lever in 13.5 |
| 7.2 F2 | Approved, unconditional |
| 7.2 F3 | Approved |
| 7.3 | `reference-map.yaml` repaired rather than left; `new-package-setup.md` removed |
| 10 step 4 | Now: run `air format .`, then add gate 8, then delete `.lintr` |
