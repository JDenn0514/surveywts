# Prompt: redesign the rules against skill-authoring practice

**Created:** 2026-08-27
**Run in:** a fresh session, after `prompt-rules-factual-accuracy.md` lands
**Produces:** `plans/spec-rules-redesign.md` — a plan, not an implementation

## Why this exists

`CLAUDE.md` plus the 8 files in `.claude/rules/` total 2,482 lines that
auto-load into every subagent dispatch. That is the largest remaining token
cost after PR #91.

PR #90 attempted this and cut the total to 800 lines. A later per-rule audit
found 19 dropped rules and 1 silently widened prohibition out of 533 normative
statements. The verification it passed — `wc -l`, spot-check greps, and a full
`devtools::check()` — cannot detect a dropped rule. This prompt builds that
gate in.

If you want the redesign implemented straight through rather than planned,
remove the "Produce the plan only" line. Keep the conservation gate either way.

## The prompt

Copy everything below into a new session.

---

I want to reduce how many tokens my skills and rules consume. My pipeline
skills currently use most of my allotted usage.

Use these skills to identify skill and rule best practices and areas for
improvement: `skill-creator`, `writing-for-agents`, and `writing-skills`. Also
research online for current strategies on reducing agent token usage —
progressive disclosure, context loading, instruction density, when to split a
document versus condense it.

Then produce a plan for updating my skills and rules to match those practices.
Produce the plan only. Do not implement it.

Context you need before you start:

WHAT IS ALREADY DONE — do not re-plan these. See PR #91.
- Tester and shipper agents run on Sonnet.
- Review loops are capped at 3 passes with delta passes after the first.
- Agents no longer re-read the auto-loaded rules.
- Builder full-suite test runs are capped at 2 per PR.
- All validation gates run in one background command
  (.claude/scripts/run-gates.sh) instead of eight; poll loops are banned for
  the tester and shipper.
- .claude/scripts/usage-profile.py measures per-session token usage by model
  and by subagent. Use it to establish the baseline before you plan, and name
  it as the measurement step in the plan.

THE REMAINING TARGET
CLAUDE.md plus the 8 files in .claude/rules/ total 2,482 lines. They auto-load
into every subagent dispatch. That is the largest remaining cost and the thing
the plan should address.

A PREVIOUS ATTEMPT FAILED — learn from it, do not repeat it.
An earlier pass cut those 2,482 lines to 800 by moving worked examples into
five on-demand files. It verified the result with `wc -l`, a `grep -L` for
missing pointers, five spot-check greps, and a full `devtools::check()`. All
passed. A later per-rule audit found 19 dropped rules and 1 silently widened
prohibition out of 533 normative statements, two live skills left citing a
deleted rule by path, and a self-contradiction inside one file. The work is on
branch chore/reduce-token-usage if you want to read it — treat it as a draft
with known defects, not a model.

The lesson is that line-count and lint-style checks cannot detect a dropped
rule. So:

- Your plan must end with a rule-conservation audit as a merge gate: enumerate
  every normative statement in the originals, then show where each one lives
  afterward, classified as preserved, moved, deduplicated, or deleted with a
  reason. Include statements that appear only inside a code comment or an
  example, and every specific value — tolerances, version bounds, line widths,
  file paths, naming patterns, error class names. That is where the losses were.
- Anything you propose deleting must be listed explicitly for my approval, not
  folded into a restructuring.
- Before proposing that any rule be condensed, verify it is still true against
  the source. Grep R/, NAMESPACE, and tests/ for every class, function, and
  file path a rule names. A separate pass on branch fix/rules-factual-accuracy
  has already corrected known-false statements; assume it landed, but spot-check
  rather than trusting it.

PRIOR ART
The sibling repo at ../surveycore ran a similar reduction — see
plans/spec-reduce-token-usage.md and plans/implementation-plan-reduce-token-usage.md
there, and commit 0508e84. Its measured cost analysis is useful. Its
verification method is the one that failed above, and its rules have never been
audited for losses, so do not treat its result as validated. surveycore also
has no equivalent of my function-documentation.md, which is where 10 of the 19
losses occurred — that file is the hardest part of this job and has no prior art.

DELIVERABLE
A plan at plans/spec-rules-redesign.md covering: the measured baseline, what
best practices you found and which apply here, the proposed structure, what
moves where, the conservation audit as a gate, and how success is measured with
usage-profile.py. Ask me about anything ambiguous before you write it rather
than assuming.
