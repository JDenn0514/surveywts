# Decisions Log — surveywts jackknife-merge

This file records planning decisions made during jackknife-merge.
Each entry corresponds to one planning session.

---

## 2026-06-16 — Pipeline-ship PR 2 reviewer BLOCK — pkgdown gate

### Context

The reviewer flagged that `r-package-profile.md` requires pkgdown to run when
NAMESPACE changes (PR 2 removes `create_group_jackknife_weights` from exports).
The profile does include a `SKIPPED — pre-pkgdown` exception: "during pre-Polish
phases, pkgdown may be SKIPPED — Polish if pkgdown CI is not yet wired up."

### Decision

**pkgdown gate: SKIPPED — pre-pkgdown.**

Rationale: We are in the Diagnostics phase, two phases before Polish.
`pkgdown.yaml` is wired but runs only on push to `main`. The current PR targets
`develop`. The export removal (`create_group_jackknife_weights`) is the only
NAMESPACE change, and the deleted function no longer exists in source, so there
is no risk of a stale reference page shipping to users via the live site.
pkgdown will run in full on the Polish release PR as required.

This deferral is authorized by the pipeline owner per profile §pkgdown skip condition.

---

## 2026-06-16 — Stage 3 issue resolution (Plan Review Pass 1 + 2)

### Context

Twelve open issues from two plan review passes. All five REQUIRED issues
(Issues 1–5) addressed test coverage gaps or a false-positive verification
step. Issues 6–12 were SUGGESTION-severity fixes to acceptance criteria
completeness, file cleanup, documentation, and test deduplication.

### Questions & Decisions

**Q: Issue 9 — fix spec §Returns typo by correcting the spec directly, or
add a warning note to the impl plan?**
- Options considered:
  - **Note in plan:** low-effort; leaves the spec wrong; future readers of
    the spec see incorrect information.
  - **Fix the spec directly:** one-line edit to `spec-jackknife-merge.md`;
    removes the source of confusion permanently.
- **Decision:** Fix the spec at the source.
- **Rationale:** A spec with a known wrong value is worse than the cost of
  a one-line correction. The spec is the authoritative contract; the plan
  should not need to override it with a note.

### Outcome

`impl-jackknife-merge.md` updated with 11 fixes; `spec-jackknife-merge.md`
corrected at §Returns (probability paths now correctly state
`operation = "replicate_creation"` with `method = "jackknife"`). Plan is
ready for `/r-implement`.

---
