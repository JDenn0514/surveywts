# Engineering Preferences

**Version:** 1.0
**Created:** February 2026
**Status:** Decided — applies to all surveyverse packages

**Scope:** These preferences are owned by this repo but intended as guidance
for the full surveyverse ecosystem. If another package adopts them, they should
copy this file to their own `.claude/rules/`.

These are meta-principles that govern every implementation decision across
all phases. When in doubt about an approach, use this list as the tiebreaker.
They are listed in priority order.

---

## 1. DRY — flag repetition aggressively

Duplicated logic is a bug waiting to happen. If two functions do the same
thing, they should share a helper. If two spec sections describe the same
behavior, one should reference the other.

- Repeated patterns in 2+ functions → extract a shared internal helper
- Repeated validation logic → consolidate into a single validator
- Repeated test setup → move to `helper-*.R`

Do not defer DRY violations as "we can clean this up later." Surface them
during spec review, not after the code is written.

## 2. Well-tested — more tests is better

Missing test coverage is always a problem. Over-tested code is not.

- When unsure whether an edge case needs a test, write the test
- Never suggest removing coverage to hit a deadline
- 98%+ line coverage is the floor, not the target
- Every error class gets a test; every edge case in the spec gets a test

## 3. Engineered enough — not under, not over

Flag both failure modes:

**Under-engineered** (fragile, hacky):
- Missing edge case handling
- Contracts that don't specify behavior at the boundaries
- Validation that only checks the happy path

**Over-engineered** (premature abstraction, unnecessary complexity):
- Abstraction layers that don't yet have two real call sites
- Generalization for hypothetical future requirements not in the roadmap
- Clever solutions when a straightforward one works fine

The right amount of engineering is determined by what's in the current spec,
not by what might be needed in a later phase.

## 4. Handle more edge cases, not fewer

When deciding whether to handle an edge case, err on the side of handling it.

- All-NA inputs, zero-weight rows, single-level groups, empty domains — these
  are not hypothetical; they appear in real survey data
- "That probably won't happen" is not a reason to skip an edge case
- Thoughtfulness > speed: a slower implementation that handles edge cases
  correctly is always preferred

## 5. Explicit over clever

When there are two ways to do something — a clever short way and a longer
explicit way — choose explicit.

- `S7::inherits(x, ClassName)` not `inherits(x, "survey_taylor")`
- Named error classes on every `cli_abort()`, not bare messages
- Spell out behavior in the spec rather than relying on "the reader will infer"
- Document assumptions rather than leaving them implicit

---

## How to apply these during review

When evaluating a spec, implementation, or PR:

1. Read through with DRY as the first lens — find repetition before anything else
2. Check every error condition and edge case in the spec against the test plan
3. For each design decision, ask: is this the right level of abstraction for
   what's actually needed now?
4. For each boundary condition mentioned in the spec, ask: is the behavior
   fully specified, or is it left implicit?
5. For any "shortcut" in the implementation plan, ask: does this skip something
   that will need to be added back later anyway?