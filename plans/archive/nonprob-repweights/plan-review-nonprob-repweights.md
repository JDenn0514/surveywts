## Plan Review: nonprob-repweights — Pass 1 (2026-06-15)

### New Issues

#### Section: PR 1 — Weight utilities (nonprob-repweights routing)

---

**Issue 1: Documentation content changes not in acceptance criteria**
Severity: REQUIRED
Rule: Stage 2 Lens 3 (Acceptance Criteria must be objectively verifiable); spec §trim_weights() and §stabilize_weights() documentation requirements

The spec explicitly requires three documentation changes in both `trim_weights.R` and `stabilize_weights.R`:
1. Update `@description` sentence to include `survey_nonprob` with repweights
2. Update `@param data` to add a forward reference to the Replicate Weights section
3. Add `@section Replicate Weights:` block

These are currently in the Notes section of the plan only. No acceptance criterion covers them. `devtools::check()` and `devtools::document()` will not verify prose content — a builder could deliver all behavioral changes while omitting all three documentation updates and every AC item would still pass.

Options:
- **[A]** Add an AC item: "Documentation: `@description` updated in both `trim_weights.R` and `stabilize_weights.R` to include `survey_nonprob` with repweights; `@param data` updated with forward reference; `@section Replicate Weights:` block present in both files." — Effort: low, Risk: low, Impact: catches documentation regressions during review
- **[B]** Keep documentation requirements in Notes only and trust the builder to read them — Effort: none, Risk: medium, Impact: no reviewer checkpoint for spec compliance
- **[C] Do nothing** — documentation updates may be silently omitted; spec requirement §trim_weights() @description update and §stabilize_weights() @description update is unchecked

**Recommendation: A** — Documentation changes are explicitly contractual in the spec. They must appear in the AC so the reviewer can verify compliance.

---

**Issue 2: Per-group `stabilize_weights()` replicate column criterion has no assertion formula or tolerance**
Severity: REQUIRED
Rule: Stage 2 Lens 3 (acceptance criteria must be objectively verifiable)

The current AC item:
> `stabilize_weights()` per-group scaling: per-group main sum `== n_h` at `1e-10`; per-row factor applied to all replicate columns (test-spec §Numerical correctness — per-group)

The phrase "per-row factor applied to all replicate columns" is not a verifiable assertion. The test-spec provides the exact formula:
> `sum(result_rep[h, j]) == sum(orig_rep[h, j]) * (n_h / W_h)` at `1e-10`

A builder who applies the per-row factor correctly to main weights but multiplies replicate columns by the global factor (a plausible off-by-one mistake) would pass the current AC item. The quantitative assertion is what makes the criterion verifiable.

Options:
- **[A]** Replace "per-row factor applied to all replicate columns" with: "for each group `h` and each replicate column `j`: `sum(result_rep[h, j]) == sum(orig_rep[h, j]) * (n_h / W_h)` at `1e-10`" — Effort: low, Risk: low, Impact: closes the gap between AC and test-spec
- **[B]** Leave as-is and rely on the tester reading test-spec §Numerical correctness — Effort: none, Risk: medium, Impact: implementation error won't be caught by reviewer
- **[C] Do nothing** — a subtly wrong per-group replicate scaling could pass code review

**Recommendation: A** — The test-spec already has the exact formula; copy it into the AC.

---

**Issue 3: Changelog entry absent from acceptance criteria (PR 1)**
Severity: REQUIRED
Rule: Stage 2 Lens 3 standard criteria checklist; `github-strategy.md` PR template

The Stage 2 review lens states: "Are the standard criteria present? [...] Changelog entry written and committed on this branch." PR 1's acceptance criteria does not include a changelog item. The plan's Notes section says "Create `changelog/utilities/feature-nonprob-repweights-utils.md` before opening the PR" — but this is a note, not a verifiable acceptance criterion. A builder who ships code and opens the PR without the changelog file has no AC gate to stop them.

Options:
- **[A]** Add AC item: "`changelog/utilities/feature-nonprob-repweights-utils.md` created and committed on this branch before opening the PR." — Effort: low, Risk: low, Impact: enforces the project's PR template requirement
- **[B]** Leave in Notes and rely on the builder reading it — Effort: none, Risk: low (it's clearly stated in Notes), Impact: no reviewer checkpoint
- **[C] Do nothing** — same as B

**Recommendation: A** — Standard criteria should be in AC, not just Notes. Low effort, closes a process gap.

---

#### Section: PR 2 — Diagnostics (accept survey_replicate input)

---

**Issue 4: Changelog entry absent from acceptance criteria (PR 2)**
Severity: REQUIRED
Rule: Stage 2 Lens 3 standard criteria checklist; `github-strategy.md` PR template

Same issue as Issue 3 for PR 2. The Notes say "Create `changelog/utilities/feature-nonprob-repweights-diagnostics.md` before opening the PR" but this is not an AC item.

Options:
- **[A]** Add AC item: "`changelog/utilities/feature-nonprob-repweights-diagnostics.md` created and committed on this branch before opening the PR." — Effort: low, Risk: low
- **[B] Do nothing** — note exists in Notes; minor risk

**Recommendation: A** — Consistent with the resolution of Issue 3.

---

#### Section: PR 1 — Suggestions

---

**Issue 5: `NULL` "must not throw" constraint for `.has_repweights()` not explicit in AC**
Severity: SUGGESTION
Rule: Spec §.has_repweights() contract ("Errors: None. This is a pure Boolean predicate; it must not throw.")

The AC bundles `NULL` into the FALSE-returning group: "returns `FALSE` for `data.frame`, `survey_taylor`, `weighted_df`, `NULL`." The "must not throw" constraint is qualitatively different from "returns FALSE" — it tests exception safety of the predicate under a degenerate input. A builder who guards `NULL` with `stopifnot(...)` would return FALSE, but throw first.

Options:
- **[A]** Separate `NULL` into its own AC bullet: "returns `FALSE` for `NULL` input and does not throw (spec §.has_repweights() Errors contract)" — Effort: minimal, Risk: low
- **[B]** Keep as bundled; trust that "returns FALSE" implies "must not throw" — Effort: none, Risk: low
- **[C] Do nothing** — test-spec edge case table already says "must not throw"

**Recommendation: A** — The spec's "must not throw" language is load-bearing for a predicate. A single extra AC bullet costs nothing.

---

**Issue 6: Single-replicate-column edge case not explicit in AC**
Severity: SUGGESTION
Rule: Stage 2 Lens 4 (spec edge cases must appear in AC)

The test-spec has an explicit edge case row: "`survey_nonprob` with a single replicate column | `n_rep = 1L` fixture | `TRUE`". The plan's AC covers this only implicitly via "returns `TRUE` for `survey_nonprob` with `@variables$repweights` length ≥ 1". For trim_weights and stabilize_weights, the single-column edge case is also in the test-spec ("Single replicate column scaled correctly", "one column in `@data` scaled correctly").

The test-spec is the tester's authority, so the tester will write the test. But adding an explicit AC bullet makes the reviewer's job cleaner.

Options:
- **[A]** Add a bullet to each relevant AC block: "single replicate column (`n_rep = 1L`) — trimmed/scaled correctly; result has exactly 1 replicate column" — Effort: minimal
- **[B] Do nothing** — test-spec covers it; implicit coverage in existing AC is adequate

**Recommendation: B** — The tester reads the test-spec, which is authoritative. The implicit coverage via "length >= 1" is sufficient. Don't add noise to the AC for this.

---

## Summary (Pass 1)

| Severity | Count |
|---|---|
| BLOCKING | 0 |
| REQUIRED | 4 |
| SUGGESTION | 2 |

**Total issues:** 6

**Overall assessment:** The plan is structurally sound — PRs are correctly sized, genuinely independent, and cover all spec behaviors. Four required issues need resolution before coding starts: documentation changes must be in the AC (not just Notes), the per-group replicate column criterion needs a quantitative formula, and both PRs are missing the standard changelog AC item.
