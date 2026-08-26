# Engineering Preferences

**Version:** 1.1
**Status:** Decided — applies to all surveyverse packages

Meta-principles that govern every implementation decision, in priority
order. Use as the tiebreaker when in doubt about an approach.

1. **DRY — flag repetition aggressively.** Duplicated logic is a bug waiting
   to happen. Extract shared helpers; consolidate repeated validation; do
   not defer DRY violations to "later".
2. **Well-tested — more tests is better.** Missing coverage is always a
   problem; over-tested code is not. 98%+ line coverage is the floor.
3. **Engineered enough — not under, not over.** Flag missing edge-case
   handling AND premature abstraction. The current spec determines the right
   level, not hypothetical future needs.
4. **Handle more edge cases, not fewer.** All-NA inputs, zero-weight rows,
   single-level groups, and empty domains appear in real survey data.
5. **Explicit over clever.** Prefer the longer explicit way: class objects
   in `S7_inherits()`, named error classes, documented assumptions.

---
Sub-points and the review checklist:
`.claude/references/code-style-detail.md` §Engineering preferences — read it
when reviewing a spec, plan, or PR against these principles.
