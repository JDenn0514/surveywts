## Plan Review: ipw-gee-fix — Pass 1 (2026-06-24)

### New Issues

#### Section: PR Map

No issues found.

#### Section: PR 1 — GEE nleqslv rewrite

---

**Issue 1: Changelog entry file missing from Files list and acceptance criteria**
Severity: REQUIRED
[Violates github-strategy.md "Changelog entry format (required before every PR)" and
stage-2-review standard criteria: "Changelog entry written and committed on this branch."]

The plan's Files section lists `DESCRIPTION`, `tests/testthat/test-nonprob-ipw.R`,
`R/ipw.R`, and `man/ipw.Rd`. No changelog entry is listed. The project actively uses
`changelog/propensity/` (e.g., `fix-gss-ipw-ref-nest.md` for the prior propensity
fix). The acceptance criteria have no corresponding check.

Without this in the plan, the builder may ship the PR without a changelog entry, and
the tester's profile gate check won't catch it.

Options:
- **[A]** Add `changelog/propensity/fix-ipw-gee-nleqslv.md` to the Files section and
  add "changelog entry committed on this branch" to the acceptance criteria.
  Effort: low, Risk: low, Impact: keeps the propensity changelog consistent.
- **[B]** Delegate to commit-and-pr skill (which may handle changelog automatically).
  Effort: low, Risk: medium — if the skill doesn't produce the entry, it silently
  goes missing.
- **[C] Do nothing** — Changelog entry gets skipped; propensity phase history has a gap.

**Recommendation: A** — One line addition to Files, one line to acceptance criteria; no
ambiguity about responsibility.

---

**Issue 2: No prohibition on `skip_if_not_installed("nleqslv")` in implementation notes**
Severity: SUGGESTION
[Aligns with test-spec-ipw-gee-fix.md §nleqslv dependency: "Do not add
`skip_if_not_installed("nleqslv")` to any block."]

`nleqslv` is moved to `Imports` (not `Suggests`), making it always present when the
package is installed. The test-spec explicitly calls out that no skip guard should be
added. The plan's implementation notes do not repeat this constraint; a builder's
natural instinct when encountering a new dependency in tests is to add a skip guard.

Options:
- **[A]** Add a one-line note to the implementation notes: "Do not add
  `skip_if_not_installed('nleqslv')` to any test block — nleqslv is in Imports."
  Effort: trivial, Risk: none, Impact: prevents a subtle test-suite inconsistency.
- **[B] Do nothing** — Test-spec is the authoritative source; builder should read it.
  Risk: builder may not re-read the test-spec assumption section when writing tests.

**Recommendation: A** — Trivial addition; prevents a head-scratcher skip guard from
appearing in code review.

---

**Issue 3: Three of four roxygen2 updates have no verifiable acceptance criterion**
Severity: SUGGESTION
[Violates spec coverage — spec §ipw() documentation updates lists four distinct changes;
only one has a testable criterion in the plan.]

The spec requires four roxygen2 updates:
1. `@section Algorithm` GEE subsection — describes nleqslv, termcd convergence
2. `@section Convergence` — remove the note that GEE may fail with population-scale weights
3. `@details` non-convergence paragraph — distinguish MLE vs GEE paths
4. `@examples` GEE block comment — remove size-balance implication

The plan's acceptance criteria cover item 3 implicitly (AC-4 snapshot verifies the
"convergence diagnostic" label in the *warning message*; the `@details` paragraph update
uses the same label, so if the warning fires with the right text the paragraph was likely
updated). Items 1, 2, and 4 have no criterion beyond "devtools::document() passes" —
which only verifies the docs compile, not that the correct content was written.

The risk is partial implementation: a builder could correctly update the nleqslv code
and the warning message label but leave the `@section Convergence` note intact or leave
the `@examples` comment unchanged.

Options:
- **[A]** Add three observable criteria to the acceptance checklist:
  - `@section Algorithm` GEE subsection references `nleqslv::nleqslv()` and
    `termcd %in% c(1L, 2L)` — verifiable by reading the generated `.Rd`
  - `@section Convergence` no longer contains "GEE may fail with population-scale"
    (or equivalent text) — verifiable by reading the generated `.Rd`
  - `@examples` GEE comment no longer implies a size-balance convergence limitation —
    verifiable by reading the source
  Effort: low, Risk: low, Impact: closes the coverage gap.
- **[B]** Leave as-is and rely on code review to catch missing doc updates.
  Risk: a PR that passes CI and all automated checks could still ship with stale docs;
  code review is the only backstop.
- **[C] Do nothing** — These are documentation-only changes and documentation
  correctness is a judgment call. AC-4 snapshot partially covers item 3.

**Recommendation: A** — The spec is explicit about what each section should and should not
say. Adding three short criteria costs nothing and closes the gap without extending
implementation scope.

---

### Summary (Pass 1)

| Severity | Count |
|---|---|
| BLOCKING | 0 |
| REQUIRED | 1 |
| SUGGESTION | 2 |

**Total issues:** 3

**Overall assessment:** The plan is well-aligned with the spec and test-spec — all 10
test blocks map correctly to test-spec scenarios, the TDD ordering is correct, nleqslv
call form and result-extraction rules are faithfully reproduced, and the guard-removal
criteria are precise. The only required fix is adding the missing changelog entry to the
Files list and acceptance criteria; the two suggestions improve robustness but are not
blockers.

---

## Resolution Log: Pass 1 Issues (2026-06-24)

| # | Title | Resolution |
|---|---|---|
| 1 | Changelog entry missing | ✅ Resolved — `changelog/propensity/fix-ipw-gee-nleqslv.md` added to Files list and acceptance criteria |
| 2 | No `skip_if_not_installed` prohibition | ✅ Resolved — note added to implementation notes for test file |
| 3 | Three roxygen2 updates unverifiable | ✅ Resolved — scope expanded to full Tier 3 doc reorganization (Option A); 13 new acceptance criteria added covering all @section and @param changes |

Additional scope added at user direction (2026-06-24):
- `estimating_eq` default changed from `"mle"` to `"gee"` — 3 new acceptance criteria added
- Full roxygen2 reorganization: `@section Algorithm`, `@section Convergence`, `@section Missing Data`, `@section Limitations` created; `@note` block eliminated; `@param` mechanism content trimmed

**Verdict: PASS** — All Pass 1 issues resolved. Plan is ready for implementation.

---

## Plan Review: ipw-gee-fix — Pass 2 (2026-06-24) — Documentation Focus

### Prior Issues (Pass 1)

| # | Title | Status |
|---|---|---|
| 1 | Changelog entry missing | ✅ Resolved |
| 2 | No `skip_if_not_installed` prohibition | ✅ Resolved |
| 3 | Three roxygen2 updates unverifiable | ✅ Resolved (scope expanded to full Tier 3 reorganization) |

### New Issues

#### Section: PR 1 — Roxygen2 documentation reorganization

---

**Issue 4: `@param maxit` description is stale for the GEE path**
Severity: REQUIRED
[Violates spec Rule GEE-3: nleqslv replaces the NR loop on the GEE path; `maxit` is now passed as `control$maxit` to `nleqslv::nleqslv()`, not as Newton-Raphson iterations. Violates `function-documentation.md` §@param: "describes the effect of the argument on behavior or output."]

Current text: `"Maximum number of Newton-Raphson iterations. Must be >= 1. Default 25L."`

After the change, this description is accurate only for the MLE path. On the GEE path, `maxit` is passed as `control$maxit` to `nleqslv::nleqslv()` — it controls nleqslv's internal iteration budget, not an explicit NR step. The plan's `@param` trims section lists `epsilon`, `reference`, `method`, `estimating_eq`, and `population_size` — `maxit` is absent. No acceptance criterion checks it.

A builder following the plan's `@param` trims section exactly will leave `maxit` with the NR-only description, which is incorrect for the GEE path.

Options:
- **[A]** Add `@param maxit` to the `@param trims` list: "update to cover both paths — for MLE, maximum Newton-Raphson iterations; for GEE, passed as `control$maxit` to `nleqslv::nleqslv()`." Add an AC: "`@param maxit` describes both MLE (NR iterations) and GEE (nleqslv `control$maxit`) paths." Effort: low, Risk: low.
- **[B]** Leave as-is and note that "Newton-Raphson" is a close-enough approximation since nleqslv uses Newton-like steps. Risk: technically incorrect; creates confusion when users see a non-convergence warning labelled "convergence diagnostic" while the param docs still say "Newton-Raphson iterations."
- **[C] Do nothing** — stale description ships; user reads "Newton-Raphson iterations" for a GEE call that uses nleqslv.

**Recommendation: A** — Trivial addition to the @param trims list; prevents a concrete doc/code mismatch that will confuse any user who reads the help page while debugging GEE convergence.

---

**Issue 5: Three `@note` items have no documented destination**
Severity: REQUIRED
[Violates plan internal consistency: the plan states "Remove the entire `@note` block after migration" but specifies destinations for only 4 of 7 items. The 3 unassigned items would be silently deleted.]

The current `@note` block (lines 377–416 of `R/ipw.R`) contains 7 items:

| Item | Plan disposition |
|---|---|
| MAR assumption | → `@section Limitations` ✅ |
| Common support | → `@section Limitations` ✅ |
| **Variance under-estimation** | **Not specified** ❌ |
| **Weight interpretation** (`w_i = 1 / P(in NPS | x_i)`) | **Not specified** ❌ |
| **Pre-trim population size** (`estimated_population_size = sum(w)` before trim) | **Not specified** ❌ |
| Independence of participation | → `@section Limitations` ✅ |
| Non-overlapping samples | → `@section Limitations` ✅ |

"Variance under-estimation" is a condensed version of the `@details` variance-refit procedure — it is partially redundant but not fully covered. "Weight interpretation" is a formula note (`w_i = 1/pi_i`) that belongs in `@section Algorithm`. "Pre-trim population size" is an `@returns`-style guarantee about the history entry.

Without explicit destinations, a builder following the plan will either (a) silently delete the 3 items, losing useful content, or (b) leave them in `@note`, which the plan says to remove. The acceptance criterion "`@note` block absent from `man/ipw.Rd`" only verifies removal, not content preservation.

Options:
- **[A]** Add explicit dispositions to the plan:
  - "Variance under-estimation" → delete (content already covered more thoroughly in `@details` variance-refit section)
  - "Weight interpretation" → move to `@section Algorithm` MLE subsection (formula belongs with the weight formula `w = 1/pi`)
  - "Pre-trim population size" → move to `@returns` (it's a guarantee about the output object)
  Effort: low, Risk: low, Impact: no content is silently lost.
- **[B]** Add all 3 unassigned items to `@section Limitations` for simplicity. Effort: low, Risk: low, but "Weight interpretation" and "Pre-trim population size" are not limitations.
- **[C] Do nothing** — builder guesses; 3 content items may be silently deleted.

**Recommendation: A** — Three short disposition lines in the plan; content is clearly categorized. Option B lumps non-limitation content into Limitations, which would be editorially incorrect.

---

**Issue 6: `@param missing_method` trimming not in acceptance criteria**
Severity: REQUIRED
[Violates spec coverage: the plan states "`@param missing_method` stays concise on options only and links here" when describing `@section Missing Data`, but no acceptance criterion verifies the trim was done.]

The current `@param missing_method` block (lines 179–201 of `R/ipw.R`) is 23 lines long and contains the full mechanism description for each option including the "separate" complete-case caveat. The plan says this content becomes `@section Missing Data` and the param is trimmed to "options only + link." If the builder creates the section but omits the param trim, the help page will have duplicated content — the same "separate" caveat explained twice. The existing acceptance criterion checks only that the section exists, not that the param was trimmed.

Options:
- **[A]** Add one acceptance criterion: "`@param missing_method` is trimmed to a short options list with a link to `@section Missing Data`; the mechanism description of each option is not duplicated in `@param`." Effort: trivial, Risk: none.
- **[B]** Add `@param missing_method` to the explicit `@param trims` list in the plan body alongside reference, method, estimating_eq, epsilon, population_size. Effort: low, Risk: none.
- **[C] Do nothing** — duplicate content may ship; the man page would be correct but redundant.

**Recommendation: A+B** — Add `@param missing_method` to the trims list (so the builder has explicit guidance) and add the AC (so the tester can verify it). Both changes are trivial.

---

**Issue 7: `@examples` silent default flip not addressed**
Severity: SUGGESTION
[Consistency gap: the plan scans test files for implicit `"mle"` default usage but does not address `@examples` blocks, which have the same exposure.]

After changing `estimating_eq = c("mle", "gee")` to `c("gee", "mle")`, seven `@examples` calls that omit `estimating_eq` will silently use GEE:
`result1`, `result2`, `result_acs`, `result_omit`, `result_sep`, `result_imp`, and `result_known_n`. Only `result_gee` explicitly sets `estimating_eq = "gee"`.

The plan scans `tests/testthat/test-nonprob-ipw.R` for implicit default usage and adds `estimating_eq = "mle"` where MLE-specific behavior is being tested. The same scanning logic applies to `@examples`. If using real package data (ns_wave1, gss_ref) with GEE is acceptable and correct, the examples can rely on the new default — but this should be stated explicitly so the builder doesn't have to guess.

Options:
- **[A]** Add to the implementation notes: "Scan `@examples` for calls to `ipw()` without `estimating_eq`. These will use GEE by default after the change. For each such call, confirm GEE produces a valid result with the package datasets used in the example. If a specific example is intended to demonstrate MLE, add `estimating_eq = 'mle'` explicitly." Effort: low, Risk: low.
- **[B]** Add an explicit acceptance criterion: "All `@examples` calls either specify `estimating_eq` explicitly or are verified to produce correct output with the new GEE default." Effort: low.
- **[C] Do nothing** — builder may not notice the 7 silent flips; examples may run correctly but demonstrate behavior different from the author's intent without any explicit decision.

**Recommendation: A** — One implementation-notes sentence clarifies intent without prescribing the outcome. The builder needs guidance, not a hard rule about which direction to go.

---

**Issue 8: Tier 3 formula typesetting not in acceptance criteria**
Severity: SUGGESTION
[Violates `function-documentation.md` Tier 3 requirement: "@section Algorithm — Include formulas using `\eqn{}` / `\deqn{}` wherever notation requires subscripts, superscripts, Greek letters, or summation." No acceptance criterion checks this.]

The new `@section Algorithm` will contain:
- **MLE subsection**: the pseudo-likelihood score equation (involves `\sum`, subscripts for NPS/reference units, `X^T`, `\pi`)
- **GEE subsection**: calibration score `\sum_k (x_k / \pi_k) = \sum_k d_k x_k` and Jacobian `−X^T \text{diag}((1-\pi)/\pi) X`
- The weight formula `w = 1/\pi` (subscripts)

All of these require `\eqn{}` or `\deqn{}` per Tier 3 rules. The plan describes the content but the acceptance criteria check only "exists with `**MLE**` and `**GEE**` subsections" — not that formulas are typeset with `\eqn{}`/`\deqn{}`. A builder could write the section in plain prose ("sum of x over pi minus reference totals") and pass all criteria while producing a substandard help page.

Options:
- **[A]** Add one acceptance criterion: "Formulas in `@section Algorithm` (score equation, weight formula, calibration constraint) use `\eqn{}` or `\deqn{}` for notation involving subscripts, Greek letters, or summation." Effort: trivial.
- **[B]** Leave as-is; rely on code review to enforce Tier 3 formula typesetting. Risk: subtle formatting deficiency that CI won't catch.
- **[C] Do nothing** — typesetting is a polish detail; functional content is more important.

**Recommendation: A** — One AC line; enforces an existing project rule that's already been decided. Not adding it creates a blind spot that only code review can catch.

---

### Summary (Pass 2)

| Severity | Count |
|---|---|
| BLOCKING | 0 |
| REQUIRED | 3 |
| SUGGESTION | 2 |

**Total issues:** 5

**Overall assessment:** The documentation reorganization section of the plan is thorough but has three concrete required gaps: `@param maxit` was overlooked in the param-trims list, three `@note` items lack documented destinations (risking silent deletion of useful content), and `@param missing_method` trimming has no AC to verify it. All three are low-effort fixes. The two suggestions improve robustness on the `@examples` default flip and formula typesetting.

---

## Resolution Log: Pass 2 Issues (2026-06-24)

| # | Title | Resolution |
|---|---|---|
| 4 | `@param maxit` stale description | ✅ Resolved — added to `@param` trims list + AC: covers both MLE (NR iterations) and GEE (`control$maxit` to nleqslv) |
| 5 | `@note` orphaned items | ✅ Resolved — explicit dispositions added: "Variance under-estimation" → delete (duplicate of @details); "Weight interpretation" → `@section Algorithm` MLE subsection; "Pre-trim population size" → `@returns` |
| 6 | `@param missing_method` trim not in AC | ✅ Resolved — added to `@param` trims list + AC verifying trim and no duplicate content |
| 7 | `@examples` silent default flip | ✅ Resolved — scanning note added to implementation notes; builder confirms GEE validity per example or adds explicit `estimating_eq = "mle"` |
| 8 | Tier 3 formula typesetting | ✅ Resolved — AC added: `\eqn{}`/`\deqn{}` required for subscripts, Greek letters, summation in `@section Algorithm` |

**Verdict: PASS** — All Pass 2 issues resolved. Plan is ready for implementation.
