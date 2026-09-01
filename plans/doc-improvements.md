# Documentation Improvement Plan

**Created:** 2026-06-26
**Revised:** 2026-08-26 — reconciled against `doc-rewrite` (Phase 1/2, PRs #79–#80)
and re-verified against current source. Resolved items removed; open items
confirmed live.
**Revised:** 2026-08-31 — second verification pass and decision round.
Narrowed the Section A claim, redrew the Section B class diagram, closed the
row-retention re-verify items, reconciled Section G with its Outcome block,
and added two quick wins: the nonresponse `@details` contradiction and the
`create_bootstrap_weights()` nonprob pass-through.
**Revised:** 2026-08-31 — third pass: claim-by-claim verification of the
whole file. Corrected the Section F premise (`redistribute_weights()` has no
class branch), fixed wrong citations, reopened part of resolved item E, and
added newly found defects to Section H.
**Revised:** 2026-08-31 — Section C planning pass. The Section C plan is
drafted (`plans/doc-method-choice-guidance.md`); its adversarial review
found defects in this file's Section C draft tables (fixed in place),
confirmed a calibration comprehension doc exists in the archive, and added
one new Section H quick win (`max_adjust` default contradiction).
**Revised:** 2026-08-31 — Section B+D planning pass. The combined plan is
drafted and adversarially reviewed (`plans/doc-getting-started.md`). Its
review added two Section H quick wins (the README static function table
and the missing `strata` in the README reference construction) and found
two defects in this file that the plan's Task 5d corrects on
implementation: Section B's "the other five creators reject a
`survey_nonprob`" claim (four do; the jackknife accepts
`type = "grouped"`), and the probability workflow sketch's step order
(replicate weights come before calibration).
**Status:** Open — pre-implementation review
**Source:** Multi-agent documentation audit of all 23 exported functions, the README,
`_pkgdown.yml`, and `surveywts-package.R`, evaluated from the perspective of an
R/tidyverse-fluent analyst who is not a survey methodology expert.

Background on the prior rewrites is in **History**, and closed items are in
the **Resolved log** — both at the bottom of this file.

---

## Executive Summary

The package's documentation is structurally complete — every function has a title,
description, params, returns, and examples — but has a systemic gap: **it answers
"what" and "how" but not "why" or "what next."** Descriptions explain mechanisms,
not motivations. Examples demonstrate calling syntax but stop before showing the
user anything useful. Jargon accumulates without definition. No function explains
when to prefer it over its siblings.

The README is the strongest documentation surface by a wide margin — it tells a
coherent story, shows realistic workflow examples with console output, and
contextualizes the package. The function-level help pages do not sustain that
quality.

**The single biggest gap:** there is no conceptual layer between the README's
workflow narrative and the function-level reference pages. A user who graduates
from the README to `?calibrate_rake` hits a help page written for someone who
already knows what raking is, why they'd choose it over linear calibration, and
what the class system returns.

---

## Issues at a Glance

| # | Initiative | Scope | Status | Needs own plan? |
|---|-----------|-------|--------|-----------------|
| A | Examples: show what comes next | All 23 functions | Open | Yes |
| B | Conceptual overview / Getting Started | Package-level + pkgdown | Plan drafted 2026-08-31 | Yes — written (with D) |
| C | Method-choice guidance | Calibration, replicate, nonresponse families | Plan drafted 2026-08-31; dispatcher `@details` done (Phase 1, PR #97) | Yes — written |
| D | Jargon: define or link recurring terms | All functions | Plan drafted 2026-08-31 | Yes — written (with B) |
| E | Constructor inconsistency | — | **Resolved** — see Resolved log | — |
| F | Class system: accurate `@returns` + orientation | `adjust_nonresponse`, `summarize_weights` | Fixed 2026-08-31 on `docs/section-h-quick-wins`, pending merge | No — fix inline |
| G | Package-level docs stale | `surveywts-package.R`, `_pkgdown.yml`, README | Fixed — README re-rendered 2026-08-31, pending merge | No — fix inline |
| H | Quick-win fixes (errors, omissions, reproducibility) | Scattered | Done 2026-08-31 except the `ipw()` GEE example (deferred to Section A) and the `max_adjust` default contradiction (added 2026-08-31) | No — checklist below |

---

## A. Examples: Show What Comes Next

**Priority: highest.** Examples are the most-read part of any R help page.
**Status: open — narrowed 2026-08-31.**

### Problem

**Corrected 2026-08-31:** the original claim covered all 23 functions. The
re-verification narrowed it. The gap still holds for the calibration
functions and the replicate creators. Six of the seven creators end at the
bare call with no assignment; `create_jackknife_weights()` assigns all three
of its results (`R/create_jackknife_weights.R:258`, `:261`, `:275`), but the
assignments are dead ends — the names are never used again (verified
2026-08-31). "No downstream step" holds for all seven. Other families have
moved:

- `rescale_weights()` already meets the full standard: it assigns the result
  and shows `summarize_weights()` before and after.
- `ipw()` assigns eight results, and one example inspects
  `weighting_history`. Two downstream diagnostic calls appear:
  `effective_sample_size(result1)` and `weight_variability(result1)`
  (`R/ipw.R:549-550`). No example shows a subsequent estimation call.
- `adjust_nonresponse()`, `calibrate_to_survey()`, and
  `calibrate_to_estimate()` assign their results.

Concrete manifestations (still current):
- Every calibration function: no `result$wts`, no `summarize_weights(result)`, no
  pipe to a subsequent step
- Every diagnostic function: no commented expected output showing what `n_eff = X`
  looks like
- Every replicate weight function: no indication that the result is passed to a
  variance-estimation function — the whole point of the operation
- `create_replicate_weights()` DAGJK example: the most complex and niche use case
  is the longest, requiring three setup steps with no payoff explanation
- `as_taylor_design()`: example shows the call but not that the function always
  emits a warning, which will surprise every user
- `adjust_nonresponse()` and `redistribute_weights()`: `sample()` without
  `set.seed()` — results differ on every run (**decided 2026-08-28: keep the
  no-seed svrep convention**; these two functions are exempt from standard
  item 3 below)

### Standard to apply

Every function's examples should:
1. Assign the result: `result <- fn(...)`
2. Include at least one downstream step showing what to do with the output
3. Use `set.seed()` before any random call. Exception (decided 2026-08-28):
   `adjust_nonresponse()` and `redistribute_weights()` keep the no-seed svrep
   convention.
4. For diagnostic functions: include a commented expected value, e.g.,
   `#> n_eff: 1456`
5. For functions with notable warnings: show the warning in a comment so users
   are not surprised

### Workflow hints by family

| Family | Downstream step to show |
|--------|------------------------|
| Calibration | `summarize_weights(result)` or `result$wts` |
| Diagnostics | Print result with comment; show `by =` effect on output tibble shape |
| Replicate weights | Comment: "# pass to surveycore::get_means() for bootstrap SEs"; or show `as_taylor_design()` |
| Nonresponse | `summarize_weights(result)` before and after; show row count change for survey inputs |
| Utilities | `summarize_weights()` before and after trim/rescale |
| `ipw()` | `summarize_weights(result)`, then `calibrate(result, ...)` |

### Needs own plan?

**Yes.** Touching 23 functions systematically requires a checklist-driven spec that
tracks which functions have been updated, what downstream step each now shows, and
verifies `R CMD check` still passes after all example changes. File:
`plans/doc-examples-overhaul.md` (to be written). That plan starts with a full
per-function example audit: the 2026-08-31 narrowing above came from spot
checks of five families, not a sweep of all 23 functions.

---

## B. Conceptual Overview / Getting Started

**Priority: high.** A single article would lift the entire package.
**Status: plan drafted 2026-08-31** (`plans/doc-getting-started.md`,
adversarially reviewed, ready for implementation). No article content is
written yet.

### Problem

There is no explanation of the class system, the standard workflow, or the key
concepts that recur throughout the docs. A non-methodologist reading
`?calibrate_rake` encounters `survey_nonprob`, `survey_replicate`, and
`survey_taylor` as unexplained given names, with no reference point for what
they represent or how they relate to each other.

The README tells a coherent story but stops at "here is how to call these
functions." The help pages assume the reader can fill in everything else.

### What the conceptual layer needs to cover

**1. The class system**

A flowchart or table showing the object progression. Note: this needs a
rewrite from the original draft below — `weighted_df` no longer exists;
every path now starts from a `surveycore` survey object.

```
probability sample              non-probability sample

survey_taylor                   survey_nonprob
    │  create_*_weights()           │  create_*_weights()
    ▼                               │  (quasi-randomization bootstrap,
survey_replicate                    │   grouped jackknife / DAGJK)
    │  as_taylor_design()           ▼
    ▼                           survey_nonprob + repwt_* columns
survey_taylor                       (class unchanged; variance-ready)
```

This diagram answers the question "what will I get back?" for every function
in the package. The nonprob path never changes class: the NPS methods add
`repwt_*` columns and populate `@variables$repweights` in place
(`R/replicate-utils.R:639-667`, `R/create_jackknife_weights.R:745-774`).

One crossover exists (verified 2026-08-31): `create_bootstrap_weights()` also
accepts a `survey_nonprob` on its probability-style types, the default
included. It silently wraps the data as an SRS design and returns a
`survey_replicate` (`R/replicate-utils.R:139–149`); `as_taylor_design()`
later refuses that object with
`surveywts_error_taylor_from_nonprob_replicate`
(`R/as_taylor_design.R:102–115`). The other five creators reject a
`survey_nonprob` at the door. The article must show the two paths above and
flag the crossover as a footnote, not draw it as a normal route.

**2. The standard workflow**

A plain-language description of the two primary use cases:

- **Probability sample workflow:** start with a `survey_taylor` → calibrate to
  population targets → generate replicate weights → run estimation → report
- **Non-probability sample workflow:** start with a data frame → `ipw()` to get
  a `survey_nonprob` → `calibrate()` for doubly-robust adjustment → generate
  replicate weights → run estimation → report

The README already sketches this; the conceptual article makes it canonical and
links to it from every function's `@seealso`.

**3. A working glossary of the recurring terms**

See Section D below for the full list. These definitions live here and are linked
from individual function docs.

**4. When to use which calibration method**

One paragraph or table: rake (always-positive weights, margin matching),
linear/GREG (fast, may produce negative weights at large discrepancies), logit
(bounded ratios, slower). See Section C below.

### Implementation options

Option A: pkgdown article (`vignettes/articles/getting-started.Rmd`). This is
the cleanest surface — appears in the pkgdown "Articles" menu and can be linked
from `@seealso` in every function.

Option B: Expanded `surveywts-package.R`. Lower friction to maintain but limited
formatting and no standalone URL to link to.

**Recommendation:** Option A. The vignettes release phase is already planned;
this article is a natural precursor and could be written without needing the
full vignette suite.

### Needs own plan?

**Yes — written.** `plans/doc-getting-started.md` (drafted 2026-08-31,
adversarially reviewed): article structure, the two workflow skeletons,
the method-choice tables' sources, linking, and infrastructure, with
per-task acceptance criteria.

---

## C. Method-Choice Guidance

**Priority: high.** **Status: plan drafted 2026-08-31**
(`plans/doc-method-choice-guidance.md`, adversarially reviewed, ready for
implementation). The dispatcher halves are done: `calibrate()` got its
method `@details` in Phase 1, and `create_replicate_weights()` got its
`@details` and `@references` in PR #97 (merged 2026-08-31). What remains
open is the sibling-level guidance, which the plan carries as drafted
roxygen text.

### Problem

Every function family presents multiple methods with no documented basis for
choosing. A non-methodologist has no way to know:
- rake vs. linear vs. logit calibration
- 6 replicate weight methods
- 12 `variance_estimator` options in `create_gen_boot_weights()` — of
  which 7 (not 6; verified 2026-08-31) have no support in the mapped
  papers and can only be pointed at the svrep back end
- 3 `method` options in `adjust_nonresponse()`

The two dispatchers now explain the choice in `@details`; the individual
functions still do not.

### Guidance per family — superseded by the plan

The draft tables that stood here until 2026-08-31 are superseded. The
plan's adversarial review found three defects in them, so do not copy the
old cells from git history:

- **Rake, "slowest for many margins":** no source ranks raking's speed.
  The only sourced speed claim is linear's one-step exact solution
  (Deville et al. 1993 §11, per the calibration comprehension doc).
- **Logit, "starting weights are far from targets":** inverted. When the
  gap between sample and targets is large relative to the bounds, no
  solution exists inside `(L, U)` and the iteration diverges. Logit is
  for bounding the adjustment, not for rescuing a distant start.
- **Gen-rep, "deterministic alternative to gen-boot":** the lineage runs
  the other way — gen-boot is the randomized cousin of gen-rep
  (Beaumont & Patak 2012 §1; `plans/comprehension-replicate-methods.md`,
  "the real lineage").

The `adjust_nonresponse()` rows were plausible but unsourced — no
comprehension doc covers the nonresponse family, so the plan reframes
that guidance mechanically (from code behavior) with no citations.

Corrected, sourced content now lives in:
- **Replicate family:** the method-choice table in
  `plans/comprehension-replicate-methods.md` (which replaces the draft
  table that stood here).
- **All families:** the drafted per-function roxygen text and 24-row
  claim ledger in `plans/doc-method-choice-guidance.md`.

**Sourcing note (found 2026-08-31):** the calibration mechanism claims
are verified —
`plans/archive/calibration-framework/comprehension-calibration-framework.md`
carries a claim ledger citing Deville & Sarndal (1992) and Deville et al.
(1993) section-by-section. Calibration guidance may carry inline
citations. Still unsourced, and flagged in the plan as must-not-assert:
any rake/logit speed ranking, choice guidance among the five probability
bootstrap schemes in `create_bootstrap_weights()`, cited nonresponse
heuristics, and replicate-count economy for BRR.

### Where this guidance lives

- **Dispatcher functions** (`calibrate()`, `create_replicate_weights()`):
  `@details` comparing methods — **done** (Phase 1 and PR #97). The plan
  adds one paragraph to `calibrate()` naming [poststratify()] as the
  separate function for cell targets.
- **Individual functions**: a "When to use" paragraph at the top of
  `@details`. The plan overrides this section's earlier
  two-sentences-in-`@description` placement: the documentation standard
  caps `@description` at 1–3 sentences, and most touched functions
  already use them.
- **Getting Started article** (Section B): comparative table for each
  family. The plan's Handoffs section lists the three ready inputs.

### Needs own plan?

**Yes — written.** `plans/doc-method-choice-guidance.md`
(drafted 2026-08-31): five tasks, per-function checklist items with the
roxygen text drafted verbatim, a claim ledger, and grep gates.

---

## D. Jargon: Define or Link Recurring Terms

**Priority: high.** **Status: plan drafted 2026-08-31** — folded into
`plans/doc-getting-started.md` (glossary term list, entry depths, anchor
texts, and placement rules).

### Problem

The same terms appear throughout the docs and are never defined. A non-
methodologist either already knows them (in which case the docs are fine) or does
not (in which case they are blocked). At the target user level — R-fluent, not a
survey specialist — many of these will be unknown:

| Term | First appears | Defined? |
|------|---------------|----------|
| PSU (primary sampling unit) | `create_brr_weights()` | No |
| FPC (finite population correction) | `as_taylor_design()` | No |
| Taylor linearization | `as_taylor_design()` | No |
| Replicate weights | All 8 replicate functions | No |
| Design effect / DEFF | `weight_variability()` | No |
| G-weight | `calibrate_logit()`, `calibrate_linear()` | No |
| Propensity score | `adjust_nonresponse()`, `ipw()` | No |
| Weighting class | `adjust_nonresponse()` | No |
| GREG | `calibrate_linear()` title | No |
| BRR | `create_brr_weights()` title | No |
| DAGJK | `create_jackknife_weights()`, `create_replicate_weights()` | No |
| MAR (Missing At Random) | `adjust_nonresponse()`, `ipw()` | No |
| Quasi-randomization bootstrap | `create_bootstrap_weights()` | No |
| Doubly robust | `ipw()` | No |

Most critically: **"replicate weights"** appears in the title or description of 8
functions and is the purpose of an entire function family, but not one help page
states in plain language that replicate weights are used to compute standard errors.

### Implementation options

Option A: Define inline at first use in each function. Self-contained; no
cross-references needed. Verbose and duplicative across 23 files.

Option B: Write a pkgdown glossary article; link from each function's `@seealso`
or `@description`. Maintainable; single source of truth. Requires the getting-
started article infrastructure (Section B).

**Recommendation:** Option B. Write the glossary as part of Section B's
getting-started article. In individual function docs, add a one-line plain-
language anchor at the first use of each term, e.g., "replicate weights (sets of
perturbed weights used to estimate variance)."

### Needs own plan?

**Yes — written.** Folded into `plans/doc-getting-started.md` (drafted
2026-08-31): 12 concept entries plus 3 acronym entries (Hadamard matrix
added as a 15th term), drafted anchor texts, and placement rules.

---

## F. Class System: Accurate `@returns` and Orientation

**Priority: medium.** **Status: fixed 2026-08-31** on
`docs/section-h-quick-wins` (pending merge) — the earlier closed half is in
the Resolved log. The `n_zero` design question (document the always-0
behavior vs. stop dropping zero rows) is documented, not decided.

### Fixed 2026-08-31 (kept for reference)

**Undisclosed behavioral trap in `adjust_nonresponse()` — behavior
re-verified 2026-08-31:**
- The behavior is class-dependent in all three method paths
  (`R/adjust_nonresponse.R:821-837` weighting-class, `:446-465`
  propensity-cell, `:674-693` propensity). A `survey_taylor` input keeps
  respondent rows only — the validator requires strictly positive weights.
  A `survey_nonprob` input keeps all rows with zero weights.
- The difference appears in the `@returns` bullets only
  (`R/adjust_nonresponse.R:66-68`). The `@details` block never mentions it.
  It should also appear in `@description` or a named `@section` ("Input
  class behavior").
- Two sentences state unconditional retention, which is wrong for the
  `survey_taylor` path: the `@details` sentence "Zero-weight observations
  are retained for design-based variance estimation."
  (`R/adjust_nonresponse.R:76`) and the `@description` sentence "All rows
  are returned; nonrespondent weights are set to zero" (line 10). See the
  quick win in Section H.
- `redistribute_weights()` has no class branch. Both input classes drop the
  `reduce_if` rows (`R/redistribute_weights.R:379-389`). Its `@returns`
  (lines 46-47) documents this correctly ("same class as input, with
  `reduce_if` rows removed"), and tests lock the behavior in for both
  classes (`tests/testthat/test-05-nonresponse.R:1084` and `:1108`). No
  row-retention doc fix is needed there.

**`n_positive` and `n_zero` in `summarize_weights()` are still undefined:**
- Confirmed in current source (`R/summarize_weights.R` line 21) — both columns
  appear in `@returns` with no explanation
- The function drops zero-weight rows before it computes the statistics
  (`R/summarize_weights.R:48` filters `w_all != 0`). In the output, `n_zero`
  is always 0 and `n_positive` always equals `n`. The columns are
  vestigial, which makes the missing definitions actively misleading.
- `@returns` (lines 21-23) lists the full 11 columns. `@description` (lines
  11-13) restates a shorter 7-column list — it omits `n_positive`,
  `n_zero`, `min`, and `max` — and does not reference `@returns`.

### Fix

1. Promote the row-retention difference to `@description` or a named section
   in `adjust_nonresponse()`. Fix both unconditional sentences: the
   `@details` sentence at `R/adjust_nonresponse.R:76` and the `@description`
   sentence at line 10
2. Define `n_positive` and `n_zero` in `summarize_weights()` docs. The
   columns are currently always 0 and `n`. Either the docs explain that, or
   the function stops dropping zero-weight rows — a design question to
   flag, not decide here

No separate plan needed. Add to quick-wins checklist in Section H.

---

## G. Package-Level Docs: Stale and Incomplete

**Priority: medium.** **Status: resolved 2026-08-31** — the README chunks
were fixed and `README.md` re-rendered on `docs/section-h-quick-wins`
(pending merge; see Section H).

### Problems (original audit, since resolved or superseded)

The audit found three problems. The Outcome below records what happened to
each; the summaries here are historical.

- **`surveywts-package.R`** referenced `rake()`, which does not exist, and
  its Key Functions section covered only a subset of the 23 exports.
  **Fixed in PR #93.**
- **`_pkgdown.yml`** appeared to be missing a replicate function. The
  finding was wrong — the function it named does not exist. **Dropped;** the
  file is correct as is.
- **README line 190** appeared to name a wrong function. The line is
  generated svrep chunk output, not a typo. The real fix is a README
  re-render, which is **blocked** — see the Outcome and Section H.

### Outcome (2026-08-28, branch `docs/package-level-docs`)

Item 1 shipped and item 2 was dropped — details in the Resolved log. Item 3
is the only live piece of this section:

**Item 3 — README: DEFERRED, blocked.** The fix as written is wrong, and the
correct fix is blocked by an unrelated defect.

`README.md:190` is not authored prose. It is captured chunk output. The
message comes from `svrep::calibrate_to_sample()`, and inside that message
`help('calibrate_to_sample')` correctly names svrep's own function.
Renaming it to `calibrate_to_survey` would point the reader at a help page
that exists in neither package.

The real defect is that `README.md` is stale. surveywts no longer reaches
that svrep path: `.svrep_calibrate_to_sample()` is defined at
`R/calibrate_to_survey.R:1249` and nothing calls it, and
`tests/testthat/test-sample-calibration.R:3264` asserts no path calls it.
So the correct fix is to re-render `README.md` from `README.Rmd`.

That render currently fails. Two chunks in `README.Rmd` reference columns
and objects that do not exist. See Section H ("Broken README.Rmd chunks").
Item 3 stays open until those land.

---

## H. Quick-Win Fixes

Re-verified item-by-item against current source on 2026-08-26. Each item is
tagged **[open]** (confirmed still present, no known reason not to fix) or
**[decide]** (a past deliberate call — confirm you still want it before
changing). Closed items are in the Resolved log at the bottom of this file.

### Factual errors

- [ ] **[open, found 2026-08-31 during the Section C planning pass]**
      `adjust_nonresponse()` `@param control` contradicts itself on the
      `max_adjust` default. The defaults list says `max_adjust = 2.0`
      (`R/adjust_nonresponse.R:45`, matching the signature at line 144),
      but the bullet below says "(default 5.0)" (line 49). The bullet is
      wrong; fix it to 2.0.
- [x] **[done 2026-08-31, branch `docs/section-h-quick-wins`]**
      `trim_weights()` `@description` says excess is redistributed
      "equally" (line 13); `@section Algorithm` says "proportionally" (line
      71). The code settles it: the redistribution adds a constant amount
      per eligible unit (`R/utils.R:804-805`; replicate path
      `R/trim_weights.R:303-304`), so "equally" is correct and
      "proportionally" is the defective word (verified 2026-08-31). Fix
      line 71
- [x] **[done 2026-08-31]** `summarize_weights()` `@returns`
      lists 11 columns (`n`, `n_positive`, `n_zero`, `mean`, `cv`, `min`,
      `p25`, `p50`, `p75`, `max`, `ess`). `@description`
      (`R/summarize_weights.R:11-13`) restates a shorter 7-column list —
      it omits `n_positive`, `n_zero`, `min`, and `max` — and does not
      reference `@returns`. Make `@description` cover the full set or
      reference `@returns`

### Missing documentation

- [x] **[done 2026-08-31]** `weight_variability()`: Kish (1965) `@references`
      added; `weight_variability` entry added to `.claude/reference-map.yaml`
- [x] **[done 2026-08-31]** `as_taylor_design()`: still no `@section Warnings` —
      confirmed absent; the function always emits
      `surveywts_warning_taylor_loses_variance` but the help page doesn't
      say so. The roxygen prose (`:17-18`) mentions only the already-Taylor
      warning; the variance-loss warning fires on every successful
      conversion (`:118-123`, unguarded after the early exits)
- [x] **[done 2026-08-31]** `mse` parameter in `create_gen_boot_weights()`,
      `create_gen_rep_weights()`, `create_sdr_weights()`, `create_brr_weights()`:
      confirmed still just a bare type annotation ("`logical(1)`, default
      `TRUE`") with no behavioral description, unlike `create_jackknife_weights()`
      and `create_bootstrap_weights()` which explain it fully
- [x] **[done 2026-08-31]** `create_replicate_weights()`: still no
      `@details` section (Tier 4 dispatcher requirement). The prerequisite
      comprehension plan is **complete** —
      `plans/comprehension-replicate-methods.md` audits all 14 sources
      (4 citations corrected in `.claude/reference-map.yaml`; two residual
      open items: the Fay 1989 page range and the Chrostowski year/venue
      need a printed copy) and carries a draft `@details` block ready to
      adapt. This item stays open
      only for the roxygen edit itself. Three findings from that doc change
      what to write:
      - The dispatcher accepts **six** `method` strings, not seven.
        `create_group_jackknife_weights()` does not exist; delete-a-group
        jackknife is `create_jackknife_weights(type = "grouped")`.
      - **Four citations were corrected in `.claude/reference-map.yaml` —
        use the corrected forms when `@references` is written.**
        Read that doc's "Citation verification" section first. The
        Chrostowski entry names two co-authors who did not write the paper.
      - `tau` belongs to `create_gen_boot_weights()` only. BRR uses `rho`,
        a different quantity, and its default `rho = 0` deserves a warning.
- [x] **[done 2026-08-31]** `adjust_nonresponse()`:
      promote the class-specific row-retention difference to `@description`
      or a named `@section`. The behavior is confirmed in all three method
      paths: `survey_taylor` keeps respondent rows only; `survey_nonprob`
      keeps all rows with zero weights. The difference currently appears in
      the `@returns` bullets only (`R/adjust_nonresponse.R:66-68`); the
      `@details` block never mentions it.
- [x] **[done 2026-08-31]** `adjust_nonresponse()`: two sentences
      state unconditional row retention, which contradicts the
      `survey_taylor` path. The `@details` sentence "Zero-weight
      observations are retained for design-based variance estimation." is at
      `R/adjust_nonresponse.R:76`. The `@description` sentence "All rows are
      returned; nonrespondent weights are set to zero" is at line 10. Make
      both conditional on input class.
- [x] **[done 2026-08-31]** `create_bootstrap_weights()`: the
      probability-style types (the default included) silently accept a
      `survey_nonprob`. The data is wrapped as an SRS design
      (`R/replicate-utils.R:139–149`), so the replicates ignore the
      propensity-estimation step that `type = "quasi-randomization"` exists
      to capture. The behavior is intended —
      `tests/testthat/test-replicate-weights.R:82–93` locks in acceptance
      without error — but no doc surface states it. `@param data`
      (`R/create_bootstrap_weights.R:17-18`) only lists accepted classes and
      says nothing about SRS wrapping or the returned class, and the test
      does not pin the returned class (verified 2026-08-31). Add a
      `@details` paragraph that names the SRS wrapping, points NPS users to
      `type = "quasi-randomization"`, and notes that `as_taylor_design()`
      refuses the resulting object. Also state in `@param data` and
      `@returns` that a `survey_nonprob` on a probability type returns a
      `survey_replicate`.

### Inadvertent content

- [x] **[done 2026-08-31]** `redistribute_weights.R` internal developer note
      ("...because it is currently the only call site; refactor if a second
      emerges") moved from the roxygen `@details` to a source comment
- [x] **[done 2026-08-31]** Stale comments name the removed
      `create_group_jackknife_weights()`: `R/jackknife-dagjk-utils.R:3-4`,
      `R/replicate-utils.R:5`, `tests/testthat/helper-test-data.R:247` —
      update to `create_jackknife_weights(type = "grouped")`

### Incorrect or misleading content

- [x] **[done 2026-08-31 — moved to NEWS.md]** `calibrate_to_survey()`: a
      migration note ("differs from
      the prior svrep-based behavior") sits at
      `R/calibrate_to_survey.R:149-153`, inside `@section Algorithm:` under
      the "Calibration method and algorithm" sub-heading (verified
      2026-08-31). The note concerns `method`, not `algorithm` —
      `@param algorithm` (`:43-48`) is clean. The note belongs in NEWS.md,
      not user-facing docs
- [x] **[done 2026-08-31 — internalized]** `calibrate_to_survey()` documented
      `control_col_matches` as a user-facing sub-key at three sites:
      `@param control` (`:60-64`), `@section Algorithm` Step 5 (`:125-126`),
      and `@section Warnings` (`:164-166`) — implementation detail; move to
      an internal comment or remove at all three sites
- [x] **[done 2026-08-31]** `redistribute_weights()` `@description`
      (lines 12-13) says "Sets the weights of rows satisfying `reduce_if` to
      zero". The rows are then removed (`R/redistribute_weights.R:379-389`),
      not kept at zero weight. Reword to say the rows are removed.
- [ ] **[open, found 2026-08-31 during the Section B+D planning pass]**
      The README function table names a function that does not exist.
      `README.Rmd:88` (and the rendered `README.md`) lists
      `create_group_jackknife_weights()` in the Replicate weights table;
      the function was merged into
      `create_jackknife_weights(type = "grouped")` in `986b8bc`. Delete
      the row or fold it into the `create_jackknife_weights()` row. The
      jackknife row at `README.Rmd:83` also says "(JK1, JKn, random
      groups)"; the accepted `type` values are `"jk1"`, `"jkn"`,
      `"grouped"`. The 2026-08-31 re-render fixed the chunks, not this
      static table. Fix `README.Rmd`, then re-render with
      `devtools::build_readme()`.
- [ ] **[open, found 2026-08-31 during the Section B+D planning pass]**
      The README reference construction omits `strata`. `README.Rmd:121`
      builds the NPORS reference with
      `surveycore::as_survey(npors_2025_clean, weights = wt_pop)`, but
      the dataset docs say "Always include `strata = stratum`"
      (`R/data.R:110-111`, `:251-253`). Add the argument and re-render.
      The Getting Started article already uses the documented form
      (`plans/doc-getting-started.md`, Task 2c).
- [x] **[done 2026-08-31 — switched to `as_survey_nonprob()` with
      `repweights = paste0("repwt_", 1:200)`, run-verified]**
      `R/data.R:396-400` demonstrated the
      low-level `surveycore::survey_nonprob()` constructor in a user-facing
      block for `pew_2016_optin`, and that block uses `repwts =` while
      lines 591 and 1211 of the same file use `repweights =`. Switch to
      `as_survey_nonprob()` or at least reconcile the argument name.

### `@returns` consistency

- [x] **[done 2026-08-31]** `create_gen_rep_weights()` `@returns`: now states
      `@variables$type = "other"` (run-verified — gen-rep passes no
      `type_override`, so the svrep default is stored); gen-boot's entry
      gained a clarifier that `"bootstrap"` is the stored type, not the
      method name

### Package-level

The `surveywts-package.R` and `_pkgdown.yml` items are closed — see the
Resolved log.

- [x] **[done 2026-08-31 — comments fixed, NEWS.md Datasets section rewritten
      against verified shapes, orphaned `data-raw/acs-wy-2022.R` deleted]**
      Stale references to the deleted `*_svy` datasets: section comments at `R/data.R:7` and `:240`; `NEWS.md:76-79`
      still documents the `*_svy` objects as shipped;
      `data-raw/acs-wy-2022.R` is an orphaned builder for a deleted dataset
- [x] **[done 2026-08-31 — README.md re-rendered after the chunk fixes
      below]** README: the stale `help('calibrate_to_sample')`
      line is generated chunk output of an upstream
      `svrep::calibrate_to_sample()` message, not a typo — do NOT rename it.
      surveywts no longer calls that path, so the fix is to re-render
      `README.md` from `README.Rmd`. Blocked on the "Broken README.Rmd
      chunks" items below.

### Broken README.Rmd chunks

Found 2026-08-28, extended 2026-08-31, while working Section G item 3.
All items closed 2026-08-31: the chunks were fixed on
`docs/section-h-quick-wins` and `devtools::build_readme()` now renders
`README.md` cleanly.

**The `ipw` chunk (line 120 onward):**

- [ ] **[open]** `README.Rmd:126` — the chunk passes
      `predictors = c("gender", "age_group", "race_ethn", "educ")`, but only
      `gender` is a column of `ns_wave1`. `age_group`, `race_ethn`, and
      `educ` do not exist in that dataset, so the chunk errors. Fixed with
      `predictors = c("sex", "age_f3", "race_f4", "edu_f3")` (all verified
      present in both `ns_wave1` and `npors_2025_clean`, harmonized levels).
- [x] **[done 2026-08-31]** `README.Rmd:113` — the paragraph above the chunk names
      `acs_wy_2022` as a bundled reference survey. No such dataset is in
      `data/`. The bundled sets are `cps_2023`, `gss_2024`, `npors_2025`,
      `npors_2025_clean`, `ns_wave1`, `pew_2016_optin`, and
      `pew_2016_synth_pop`. The same line states that each tibble is "paired
      with a survey design companion (e.g., `gss_2024_svy`)". No
      `gss_2024_svy` object exists. No `*_svy` object is bundled, exported,
      or documented — `tests/testthat/test-datasets.R:25-34` asserts their
      absence from the data index. `*_svy` names appear widely as locally
      constructed variables in roxygen examples, which is legitimate. The
      `ns_wave1_svy` in `data-raw/ns-wave1.R` is discarded
      (`rm(ns_wave1_svy)` at line 342).

**The `calibrate-to-survey` chunk (line 160 onward):**

All four items below closed together on 2026-08-31: the chunk was redesigned
(decision with the user) rather than patched. The old chunk calibrated two
probability samples (NPORS primary, GSS control). The new chunk continues the
README's non-probability pipeline: the IPW-weighted `ns_wave1` panel (with
quasi-randomization bootstrap replicates, `estimating_eq = "mle"` for stable
per-replicate refits) is benchmarked to the NPORS estimate of partisanship
(`variables = c(pid_f3)`). The full pipeline was run-verified end-to-end
(~65 s) before the re-render. The GSS objects left the chunk entirely.

- [x] **[done 2026-08-31]** `README.Rmd:161` — passes `npors_2025_clean_svy` to
      `create_bootstrap_weights()`. No such object exists. `data/` holds the
      `npors_2025_clean` tibble only.
- [x] **[done 2026-08-31]** `README.Rmd:165` — filters on `gss_2024$gender` and
      `gss_2024$age_group`. Neither column is in `gss_2024`. That dataset
      carries `sex`, `age`, and `age_f3`. Because `gss_2024$gender` is
      `NULL`, `!is.na(NULL)` yields `logical(0)` and the subset silently
      returns a zero-row frame — the chunk fails quietly, not with an
      error.
- [x] **[done 2026-08-31]** `README.Rmd:178` — passes `variables = c(gender,
      age_group)` to `calibrate_to_survey()`. Same two missing columns as
      line 165.
- [x] **[done 2026-08-31]** `README.Rmd:163` — the comment states that `gss_2024_svy`
      "retains all rows including those with NA sex (19 rows)". The figure
      is accurate — `sum(is.na(gss_2024$sex))` is 19 of 3309 rows (verified
      2026-08-31) — but the comment names a nonexistent object, and the
      code below it filters on the wrong columns.

### Also fixed while in the files (2026-08-31, not on the checklist)

- `create_bootstrap_weights()` `@references` carried the fabricated
  Chrostowski citation and the wrong Kolenikov citation (the comprehension
  doc's Corrections 1-2 were applied to `reference-map.yaml` but never to
  the roxygen). Chrostowski is now the corrected form (real authors and
  title; no year/venue — unverifiable); Kolenikov is dropped (weak support,
  per the comprehension doc).
- `create_brr_weights()`, `create_gen_boot_weights()`,
  `create_gen_rep_weights()` `@references`: venue completed to
  "Proceedings of the Section on Survey Research Methods, American
  Statistical Association" for Fay (1984), Fay (1989), and Dippo et al.
  (1984); the duplicated 495-500 page range removed from Fay (1989);
  Bellhouse (1985) pages 323-329 added.
- `create_gen_rep_weights()` `@param seed` now explains the
  deterministic-method-with-a-seed puzzle (run-verified: svrep retains a
  random sample of replicates when `max_replicates` truncates).
- `README.Rmd` `{r replicate}` chunk called `create_bootstrap_weights()` on
  a `survey_nonprob` without `type = "quasi-randomization"` — the silent
  SRS-wrap crossover path, contradicting its own prose. Now passes the type.
- `NEWS.md` `ipw()` snippet used `selection = ~gender + age_group`
  (nonexistent columns); now `~sex + age_f3`.

### Dataset docs / examples

- [ ] **[open, deferred 2026-08-31]** `ipw()` GEE example: still uses inline
      synthetic data (`nps_gee`, `ref_gee_df`). Deliberately left open during
      the quick-wins pass: the documentation standards say to flag a dataset
      gap rather than force a substitution, and a replacement must be chosen
      for GEE convergence (population-scale reference weights) and run-tested
      for `R CMD check` example time. Belongs with the Section A examples
      overhaul (`plans/doc-examples-overhaul.md`).

---

## Per-Function Issue Reference

Quick lookup for which functions have known gaps, re-verified 2026-08-26.
Constructor-inconsistency and `weighted_df`-return mentions from the original
audit are removed as resolved/moot. This is not exhaustive — see the full
subagent reports for detailed findings.

Rows that point at Section H items closed on 2026-08-31 (branch
`docs/section-h-quick-wins`) are stale for those items — the H checklist is
authoritative. Refresh this table at the next audit pass.

| Function | Key gaps |
|----------|----------|
| `calibrate()` | `reference_design` has no use-case framing; `wt_name` behavior unexplained; no downstream step in examples |
| `calibrate_rake()` | `cap` param ratio vs. absolute framing is confusing; `weighting_history` referenced but not explained |
| `calibrate_linear()` | `bounds` (the distinctive feature) absent from all examples; `unit_scale` → `d_k` notation undefined; `bounds_scale` constraint `L < 1 < U` unexplained |
| `calibrate_logit()` | `g-weight` undefined; `bounds` never shown in examples; no "when to use vs. rake" guidance |
| `poststratify()` | `260000000` in `type = "count"` example unexplained; `setdiff()` prose in params; cell-size edge case absent |
| `calibrate_to_survey()` | Migration note and `control_col_matches` leaked into user docs (Section H); Algorithm section is methodology-specialist writing |
| `calibrate_to_estimate()` | No simple example (only the complex vcov path); `unit_scale` → svrep internal arg name leaked; no comparison with `calibrate_to_survey()` |
| `adjust_nonresponse()` | propensity methods (`"propensity-cell"`, `"propensity"`) have no examples; `sample()` without `set.seed()` (deliberate — see H); row-retention trap verified 2026-08-31 — the class difference appears in `@returns` only, and both `@description` and `@details` state unconditional retention, which is wrong for `survey_taylor` (see F/H); `@param control` states two different `max_adjust` defaults — 2.0 (correct) and 5.0 (see H) |
| `redistribute_weights()` | Developer note in user docs (Section H); `sample()` without `set.seed()` (deliberate — see H); `@description` says the `reduce_if` rows are set to zero, but the function removes them (see H) |
| `effective_sample_size()` | "Kish's" in title; no interpretation guidance ("is n_eff = 1456 good?") |
| `weight_variability()` | "Design effect" undefined; no interpretation guidance; missing `@references` |
| `summarize_weights()` | `n_positive`/`n_zero` undefined; `n_zero` is always 0 because zero-weight rows are dropped before the stats (`R/summarize_weights.R:48`); the `@description` column list omits 4 of the 11 `@returns` columns |
| `trim_weights()` | "equally" vs. "proportionally" contradiction — the code adds a constant amount per eligible unit, so "equally" is correct and Algorithm line 71 is the defective word (see H); `survey_replicate` example is 10-line setup for a one-line call |
| `rescale_weights()` | `n_h / W_h` notation undefined; example comment placement resolved 2026-08-31 (fine) |
| `ipw()` | Mechanism-before-motivation description; GEE example uses inline data (confirmed 2026-08-31); variance details section is long before plain-language summary |
| `create_bootstrap_weights()` | `type` options (5 methods) with no selection guidance; purpose of output never stated; silent nonprob pass-through on probability types needs `@details` (see H) |
| `create_brr_weights()` | BRR, gen-boot, gen-rep, and SDR are uniformly thin — BRR's 56 roxygen lines match `create_gen_rep_weights()` (56) and exceed `create_sdr_weights()` (47), vs. ~273 for jackknife and ~106 for bootstrap; any thickening fix should treat the four together; `mse` undocumented; no Warnings section (shared by all creators except jackknife) |
| `create_jackknife_weights()` | Best-documented of the replicate family; verify example `replicates` value meets recommended minimum |
| `create_gen_boot_weights()` | 12 `variance_estimator` options with no selection guidance; `mse` undocumented; `tau` guidance absent |
| `create_gen_rep_weights()` | "Deterministic" claim contradicted by `seed` param (unexplained) — verified 2026-08-31: the `seed` is never passed to `svrep::as_fays_gen_rep_design()` (`:130-137`); it goes only to the surveywts backend wrapper (`:146`); the docs never say so; `@returns` `@variables$type` inconsistency confirmed 2026-08-31 |
| `create_sdr_weights()` | Ordering sensitivity not in description; `sort_var` version note in `@param` |
| `create_replicate_weights()` | `@details` and `@references` landed in PR #97 (2026-08-31); remaining gap is Section A's example standard (no downstream step) |
| `as_taylor_design()` | "Taylor design" / "replicate design" undefined in title; no use-case motivation; warning always fires but no Warnings section (confirmed) — the roxygen prose (`:17-18`) mentions only the already-Taylor warning, while the variance-loss warning fires on every successful conversion (`:118-123`, unguarded after the early exits) |

---

## Relationship to Roadmap

The **Polish release** (`plans/roadmap.md`) includes "pkgdown site build verified"
and "vignettes." The documentation improvements here are prerequisites and
complements to that release, not replacements for it:

- Sections A–D (examples, getting started, method-choice, jargon) should be
  addressed before or during Polish, not after
- Section H quick wins can be worked incrementally as part of any PR that touches
  a given function
- The Getting Started article (Section B) is the natural predecessor to the full
  vignette suite planned for Polish

**Suggested sequencing:**
1. Section H (quick wins) — no design needed; knock these out opportunistically.
   The two **[decide]** items were resolved on 2026-08-28: keep the no-seed
   convention; write the comprehension plan. They no longer block the rest.
2. Section F (row-retention doc fix, `n_positive`/`n_zero`) — bounded,
   standalone; the behavior itself is verified as of 2026-08-31
3. Section G (package-level docs) — standalone, fast
4. Section C (method-choice) — feed into Section B design
5. Section B + D (getting started + glossary) — the flagship deliverable
6. Section A (examples overhaul) — last, because downstream workflow steps become
   clearer once the getting-started article exists to reference

---

## Plans to Write

| Plan file | Initiative | Status |
|-----------|-----------|--------|
| `plans/doc-examples-overhaul.md` | Section A: per-function examples checklist | Not started |
| `plans/doc-getting-started.md` | Section B + D: conceptual article + glossary | **Drafted 2026-08-31**, adversarially reviewed; ready for implementation |
| `plans/doc-method-choice-guidance.md` | Section C: when-to-use content per family | **Drafted 2026-08-31**, adversarially reviewed; ready for implementation |
| `plans/comprehension-replicate-methods.md` | Prerequisite for `create_replicate_weights()` `@details`/`@references` (Section C/H) | **Complete 2026-08-28.** All 14 sources audited (4 citations corrected; two residual open items); carries a draft `@details` block and the Section C method-choice table |

---

## History

A structural documentation rewrite (`plans/archive/doc-rewrite/`) landed in
PRs #79 and #80 (merged 2026-06-23), three days before this audit was written:

- **Phase 1 (#79):** `@return` → `@returns`, titles rewritten per a pre-approved
  title map, `@seealso` cross-links added per family, `@references` populated
  where verified, `@section Algorithm`/`Convergence` added for Tier 3
  functions, `@details` added for `calibrate()`.
- **Phase 2 (#80):** inline `data.frame()` calls in examples replaced with
  package datasets across all families.

That rewrite was explicitly structural — tags and sections, not narrative. It
did not touch the conceptual/narrative gaps this audit identifies (Sections
A–D), and it made two **deliberate, documented decisions** that this
audit's recommendations conflict with:

1. No `set.seed()` in `adjust_nonresponse()` / `redistribute_weights()`
   examples — "following svrep convention." (Kept, decided 2026-08-28.)
2. `create_replicate_weights()` `@details` and `@references` deliberately
   deferred, pending a `comprehension-replicate-methods.md` plan. That plan
   is now written (2026-08-28), so this deferral is cleared — see Section H.

Where a section marks something as still open, it distinguishes
**oversights** (nobody decided this — just do it) from these **deliberate
calls** (decide whether you still agree before touching them).

The class-system-refactor (PRs #85–#89, merged through 2026-06-29) also
removed `weighted_df` and all `data.frame` input entirely, which retired a
handful of the original findings outright (noted where relevant).

---

## Resolved log

Closed, dropped, and superseded items, moved here so the body carries only
open work.

- **E. Constructor inconsistency (resolved for `ns_wave1` 2026-08-26;
  scoped 2026-08-31).** `R/data.R` constructs `ns_wave1` examples via
  `surveycore::as_survey_nonprob()` consistently (fixed in or before
  PR #85). `survey_nonprob()` is the low-level S7 constructor;
  `as_survey_nonprob()` is the friendly wrapper — the two were never
  actually contradictory. The related grep task closed with it. The
  `pew_2016_optin` block at `R/data.R:396-400` still uses the low-level
  constructor; that block was out of the original item's scope and is
  tracked as a new Section H item.
- **F (closed half) — `trim_weights()`/`rescale_weights()` `@returns` "same
  class as `data`" (moot, 2026-08-26).** `data.frame`/`weighted_df` input is
  now rejected outright (`surveywts_error_not_survey_base`), so the
  statement is accurate as written.
- **G item 1 — `surveywts-package.R` (done 2026-08-28, PR #93).** `rake()`
  is gone. `@section Key Functions:` names all 23 exports across the 7
  families used by `_pkgdown.yml`.
- **G item 2 — `_pkgdown.yml` (dropped 2026-08-28).**
  `create_group_jackknife_weights()` no longer exists (merged into
  `create_jackknife_weights(type = "grouped")` in `986b8bc`). A `contents:`
  entry with no matching `.Rd` breaks the pkgdown reference build, so the
  entry must not be added. Audited against `NAMESPACE`: all 23 exports
  appear exactly once.
- **H reproducibility (decided 2026-08-28).** Keep the no-seed svrep
  convention in the `adjust_nonresponse()` / `redistribute_weights()`
  examples. Standing decision — Section A's standard item 3 carries the
  exception.
- **H `rescale_weights()` first-example comment (resolved 2026-08-31).**
  The comment is a section header over a before/after pair; the placement
  is fine.
- **H `ipw()` `estimating_eq` default (resolved).** Already documents
  `"gee"` (the default) or `"mle"`.
