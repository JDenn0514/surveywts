---
name: spec-reviewer
description: >
  This skill has been absorbed into spec-workflow Stage 3. Use
  `/spec-workflow stage 3` instead. Kept here to avoid broken references.
---

# Spec Reviewer (Redirected)

This skill has been absorbed into `spec-workflow`. The spec review workflow now
has four stages:

- Stage 2 — Adversarial **methodology** review (survey statistics correctness)
- Stage 3 — Adversarial **spec** review (contracts, test plans, engineering level)

Run Stage 3 for the code-quality review:

```
/spec-workflow stage 3
```

All adversarial spec review content is in:

```
.claude/skills/spec-workflow/references/stage-2-review.md
```

The output file location is unchanged: `plans/spec-review-{id}.md`.
After the review, resolve issues with `/spec-workflow stage 4`.
