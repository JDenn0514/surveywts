# Prompt: correct the rules against the source

**Created:** 2026-08-27
**Run in:** a fresh session, before `prompt-rules-redesign.md`
**Produces:** branch `fix/rules-factual-accuracy`, no PR

## Why this exists

An audit of PR #90 found that `.claude/rules/` describes package
infrastructure that no longer exists. The `weighted_df` class was removed by
commits `9c8246f` and `73de0f9`, but the rules still present it as live. Any
redesign of the rules must start from true source, or it will compress false
statements into a better-looking structure. That is what PR #90 did.

Run this prompt first. Run `prompt-rules-redesign.md` after it lands.

## The prompt

Copy everything below into a new session.

---

The rules in .claude/rules/ describe package infrastructure that no longer
exists. I need them corrected against the current source. This is a truth
pass, not a size pass — do not shorten, restructure, or condense anything.

An audit found these false statements. Confirm each against the source before
you act on it, then fix it:

1. `weighted_df` no longer exists. Commits 9c8246f and 73de0f9 removed it and
   moved all weighting functions to survey_base objects. `grep -rl weighted_df
   R/ tests/ man/ NAMESPACE` returns nothing. The rules still present it as a
   live S3 class with a three-path input dispatch contract, attributes, and a
   dplyr compatibility story. It appears in five rules files, by mention count:
   code-style.md (21), surveywts-conventions.md (11), testing-surveywts.md (7),
   function-documentation.md (2), github-strategy.md (2). Grep for it yourself
   and work from your own result, not from these counts.
2. `.make_weighted_df()` does not exist. The rules say it lives in utils.R.
3. `print.weighted_df()` and `dplyr_reconstruct.weighted_df()` are documented
   as exported via @export. NAMESPACE has zero S3method() entries.
4. The rules say surveywts exports the `survey_nonprob` S7 class object. There
   is no S7::new_class() call anywhere in R/ and no export(survey_nonprob) in
   NAMESPACE — the class belongs to surveycore.
5. `R/weighted-df-dplyr.R` does not exist (cited in the file mapping tables).
6. `R/rake.R` does not exist. The file is `R/calibrate_rake.R`.
7. `tests/testthat/test-00-classes.R` does not exist.

Do not stop at that list. Verify every factual claim the rules make about this
package: every file path, every function name, every class name, every error
class, every exported symbol. Check each against R/, tests/, man/, NAMESPACE,
and DESCRIPTION. Report anything else you find false.

Two judgment calls I need you to raise rather than decide:

- Where a rule documented weighted_df behavior that has a survey_base
  equivalent, propose the replacement text and ask me before writing it. Where
  it has no equivalent, propose deleting the rule and ask.
- code-style.md and surveywts-conventions.md disagree about whether surveywts
  defines S7 classes. The source says it does not. Confirm that, then tell me
  which file should carry the statement.

Also fix one contradiction that is not about dead code: the r-package-
conventions.md quick-reference row states "@examples | All runnable — no
\dontrun{}" as absolute, while its own prose and function-documentation.md
both permit \dontrun{} for genuine external resources. Make the row match.

Scope: .claude/rules/ and CLAUDE.md only. Do not touch R/, tests/, man/, or
NAMESPACE — read them, never write them. Work on a branch named
fix/rules-factual-accuracy, commit per file with Conventional Commits, and do
not open a PR. When you are done, give me a table of every statement you
changed or deleted, with the source evidence for each.
