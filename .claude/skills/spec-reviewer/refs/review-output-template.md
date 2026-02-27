# Review Output Template

Use this structure for all spec review output.

```markdown
## Spec Review: [Document name or Phase]

### Section: [First major section name]

**Issue 1: [title]**
Severity: BLOCKING
[Rule or principle violated]

[Concrete description. Quote the problematic spec text, or name what is absent.]

Options:
- **[A]** [Description] — Effort: [low/medium/high], Risk: [low/medium/high], Impact: [what]
- **[B]** [Alternative]
- **[C] Do nothing** — [what stays ambiguous]

**Recommendation: [A/B/C]** — [One sentence rationale]

---

### Section: [Next section name]

No issues found.

---

## Summary

| Severity | Count |
|---|---|
| BLOCKING | N |
| REQUIRED | N |
| SUGGESTION | N |

**Total issues:** N

**Overall assessment:** [One sentence — e.g., "The spec is nearly
implementable but has two blocking ambiguities in the error contract
that must be resolved before coding begins."]
```

## Severity tiers

- **BLOCKING** — The spec cannot be implemented correctly without resolving this.
  Ambiguity that would require the implementer to make an architectural guess.
- **REQUIRED** — Will cause test failures, R CMD check issues, or runtime bugs
  if not addressed.
- **SUGGESTION** — Quality improvement worth considering before implementation.
