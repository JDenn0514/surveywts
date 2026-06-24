# Decisions Log — surveywts ipw-gee-fix

This file records planning decisions made during ipw-gee-fix.

---

## 2026-06-24 — Implementation plan Stage 3 resolve

### Context

Resolving three issues from the Pass 1 adversarial review of `impl-ipw-gee-fix.md`.
Issue 3 (unverifiable roxygen2 acceptance criteria) opened a broader question about
documentation structure, and the user raised an additional default-change request.

### Questions & Decisions

**Q: Should the PR include a full Tier 3 documentation reorganization (creating
`@section Algorithm`, `@section Convergence`, `@section Missing Data`, `@section
Limitations`) or only the four minimal doc changes from the spec?**

- Options considered:
  - **Option A — Full reorganization in this PR:** The spec already touches
    `R/ipw.R`. Creating the required Tier 3 sections while the file is open
    avoids a separate PR and closes long-standing `function-documentation.md`
    violations (missing @section Algorithm and Convergence blocks).
  - **Option B — Minimal doc changes:** Strictly follow the spec scope; file a
    separate `docs/ipw-doc-reorganize` PR for the structural work.
- **Decision:** Option A — full reorganization in this PR.
- **Rationale:** The structural violations preexist the GEE fix but `R/ipw.R`
  is already being touched; one PR with one code review is lower friction and
  leaves the file in a state that meets documented standards.

**Q: Should the `estimating_eq` argument default be changed from `"mle"` to `"gee"`?**

- Options considered:
  - **Yes — change default to `"gee"`:** Beresewicz et al. (2025) show GEE
    outperforms MLE; `@param estimating_eq` already says "for most applications
    `'gee'` is preferred." Making GEE the default is consistent with the
    recommendation and is now safe since the nleqslv rewrite fixes population-scale
    convergence.
  - **No — leave default as `"mle"`:** More conservative; avoids any behavioral
    change for users who call `ipw()` without specifying `estimating_eq`.
- **Decision:** Change default to `"gee"`.
- **Rationale:** The GEE fix is the whole motivation for this PR; making the
  preferred estimating equation the default is the logical conclusion. Any existing
  user code that relied on the MLE default and cares about the distinction should
  have been specifying `estimating_eq = "mle"` explicitly anyway.

### Outcome

`impl-ipw-gee-fix.md` is updated to include: (1) `estimating_eq` default change
with acceptance criteria requiring explicit `estimating_eq = "mle"` in existing
MLE-specific tests; (2) full Tier 3 roxygen2 reorganization with 13 new acceptance
criteria covering all @section creations and @param trims.

---

## 2026-06-24 — Implementation plan Stage 3 resolve (Pass 2 — documentation focus)

### Context

Resolving five issues from the Pass 2 adversarial review of `impl-ipw-gee-fix.md`.
The review focused on the documentation reorganization section of the plan and
found three required gaps and two suggestions.

### Questions & Decisions

**Q: Where should the three orphaned `@note` items go after the `@note` block is removed?**

The plan specified destinations for 4 of 7 `@note` items. Three were unassigned:
"Variance under-estimation", "Weight interpretation", "Pre-trim population size".

- Options considered:
  - **Option A — Explicit per-item dispositions:** Delete the variance note
    (duplicate of `@details`); move the weight formula to `@section Algorithm`
    MLE subsection; move pre-trim guarantee to `@returns`.
  - **Option B — Move all three to `@section Limitations`:** Simpler to specify
    but editorially incorrect (weight interpretation and pre-trim guarantees are
    not limitations).
- **Decision:** Option A.
- **Rationale:** Each item belongs where its content type is documented — formulas
  in Algorithm, output guarantees in `@returns`. Lumping non-limitation content
  into Limitations violates `function-documentation.md` section semantics.

**Q: Should `@param missing_method` be explicitly listed in the param-trims list?**

The plan body stated the param would be trimmed but did not include it in the
formal trims list and had no AC to verify the trim.

- **Decision:** Add to trims list + add AC.
- **Rationale:** The builder needs explicit guidance (trims list) and the tester
  needs something verifiable (AC). Without both, duplicate content could ship.

**Q: Do `@examples` calls that omit `estimating_eq` need explicit guidance after the default flip?**

Seven `@examples` calls will silently switch from MLE to GEE. The plan scanned
test files but not examples.

- **Decision:** Add an implementation-notes sentence directing the builder to
  confirm GEE validity per example or add explicit `estimating_eq = "mle"`.
- **Rationale:** The builder should make a deliberate choice per example rather
  than discovering the behavior change during `devtools::run_examples()`.

### Outcome

`impl-ipw-gee-fix.md` updated with: (1) `@param maxit` added to trims list + AC;
(2) explicit `@note` item dispositions in the Limitations section description;
(3) `@param missing_method` added to trims list + AC; (4) `@examples` scanning
note in implementation notes + AC; (5) Tier 3 formula typesetting AC for
`@section Algorithm`.

---
