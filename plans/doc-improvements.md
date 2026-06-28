# Documentation Improvement Plan

**Created:** 2026-06-26
**Status:** Open — pre-implementation review
**Source:** Multi-agent documentation audit of all 23 exported functions, the README,
`_pkgdown.yml`, and `surveywts-package.R`, evaluated from the perspective of an
R/tidyverse-fluent analyst who is not a survey methodology expert.

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
what to do with a `weighted_df`.

---

## Issues at a Glance

| # | Initiative | Scope | Needs own plan? |
|---|-----------|-------|-----------------|
| A | Examples: show what comes next | All 23 functions | Yes |
| B | Conceptual overview / Getting Started | Package-level + pkgdown | Yes |
| C | Method-choice guidance | Calibration, replicate, nonresponse families | Yes |
| D | Jargon: define or link recurring terms | All functions | Yes |
| E | Constructor inconsistency | ~8 functions | No — fix inline |
| F | Class system: accurate `@returns` + orientation | `trim_weights`, `rescale_weights`, others | No — fix inline |
| G | Package-level docs stale | `surveywts-package.R`, `_pkgdown.yml` | No — fix inline |
| H | Quick-win fixes (errors, omissions, reproducibility) | Scattered | No — checklist below |

---

## A. Examples: Show What Comes Next

**Priority: highest.** Examples are the most-read part of any R help page.

### Problem

Every example in every function ends at the function call with no assignment and no
downstream step. Not a single example shows what the output looks like or what to
do with it next. A user copy-pasting any example ends up with a value they cannot
inspect in a workflow context.

Concrete manifestations:
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
- `ipw()`: six examples, none showing a subsequent estimation call
- `adjust_nonresponse()` and `redistribute_weights()`: `sample()` without
  `set.seed()` — results differ on every run

### Standard to apply

Every function's examples should:
1. Assign the result: `result <- fn(...)`
2. Include at least one downstream step showing what to do with the output
3. Use `set.seed()` before any random call
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
`plans/doc-examples-overhaul.md` (to be written).

---

## B. Conceptual Overview / Getting Started

**Priority: high.** A single article would lift the entire package.

### Problem

There is no explanation of the class system, the standard workflow, or the key
concepts that recur throughout the docs. A non-methodologist reading
`?calibrate_rake` encounters `weighted_df`, `survey_nonprob`, `survey_replicate`,
and `survey_taylor` as unexplained given names, with no reference point for what
they represent or how they relate to each other.

The README tells a coherent story but stops at "here is how to call these
functions." The help pages assume the reader can fill in everything else.

### What the conceptual layer needs to cover

**1. The class system**

A flowchart or table showing the object progression:

```
data.frame
    │  calibrate(), adjust_nonresponse(), ipw()
    ▼
weighted_df          ← S3 subclass of tibble; weight_col attribute
    │  create_*_weights()
    ▼
survey_replicate     ← adds replicate weight columns; enables bootstrap SEs
    │  as_taylor_design()
    ▼
survey_taylor        ← Taylor linearization design; SE via delta method

survey_nonprob       ← for non-probability samples; same family as above
```

This single diagram answers the question "what will I get back?" for every
function in the package.

**2. The standard workflow**

A plain-language description of the two primary use cases:

- **Probability sample workflow:** start with a `survey_taylor` → calibrate to
  population targets → generate replicate weights → run estimation → report
- **Non-probability sample workflow:** start with a data frame → `ipw()` to get
  a `survey_nonprob` → `calibrate()` for doubly-robust adjustment → generate
  replicate weights → run estimation → report

The README already sketches this; the conceptual article makes it canonical and
links to it from every function's `@seealso`.

**3. A working glossary of the 12 recurring terms**

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

**Yes.** Requires content decisions about scope, structure, and which concepts
to define. File: `plans/doc-getting-started.md` (to be written).

---

## C. Method-Choice Guidance

**Priority: high.**

### Problem

Every function family presents multiple methods with no documented basis for
choosing. A non-methodologist has no way to know:
- rake vs. linear vs. logit calibration
- 6 replicate weight methods
- 12 `variance_estimator` options in `create_gen_boot_weights()`
- 3 `method` options in `adjust_nonresponse()`

The `@seealso` links to siblings but none of the functions explain when to choose
one over another.

### Guidance needed per family

**Calibration:**
| Method | Use when |
|--------|----------|
| `calibrate_rake()` | Default choice. Weights stay positive; matches demographic marginals; slowest for many margins |
| `calibrate_linear()` | Speed matters; small discrepancies from targets; negative weights acceptable |
| `calibrate_logit()` | Need bounded weight ratios; starting weights are far from targets |
| `poststratify()` | Cross-classified cell targets available; exact match required |

**Replicate weights:**
| Method | Use when |
|--------|----------|
| Bootstrap | Default for probability samples; flexible design requirements |
| Jackknife | Standard complex designs; JK1 for SRS, JKn for stratified multi-stage |
| BRR | Exactly 2 PSUs per stratum (NHANES-style designs) |
| Gen-boot | Generalized complex designs; `svrep` back-end |
| Gen-rep | Deterministic alternative to gen-boot |
| SDR | Systematic random samples; row order matters |

**`adjust_nonresponse()` methods:**
| Method | Use when |
|--------|----------|
| `"weighting-class"` | Default; response rates differ across known groups |
| `"propensity-cell"` | No pre-defined groups; want data-driven cells |
| `"propensity"` | Continuous propensity adjustment; richer auxiliary variables |

### Where this guidance should live

- **Dispatcher functions** (`calibrate()`, `create_replicate_weights()`): in a
  required `@details` section comparing methods (these functions are already
  Tier 4 dispatchers; `@details` is required by the documentation standards and
  currently absent from `create_replicate_weights()`)
- **Individual functions**: two-sentence "When to use this" note in `@description`
- **Getting Started article** (Section B): comparative table for each family

### Needs own plan?

**Yes.** The method-choice content requires methodological decisions about how to
frame each comparison for a non-expert audience. File:
`plans/doc-method-choice-guidance.md` (to be written).

---

## D. Jargon: Define or Link Recurring Terms

**Priority: high.**

### Problem

The same 14 terms appear throughout the docs and are never defined. A non-
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

**Yes** — the glossary content decisions and which terms warrant full definitions
vs. one-line anchors are non-trivial. Fold into `plans/doc-getting-started.md`.

---

## E. Constructor Inconsistency

**Priority: medium.** Independently flagged by 3 of 8 subagents.

### Problem

Multiple functions' examples construct `ns_wave1` survey objects using:
```r
surveycore::as_survey_nonprob(ns_wave1, weights = weight)
```

The `ns_wave1` dataset documentation instructs:
```r
surveycore::survey_nonprob(ns_wave1, variables = list(weights = "weight"))
```

These are different functions with different argument interfaces. A user cross-
referencing both will see contradictory patterns; one of them will produce an
error or a wrong object.

**Affected functions** (examples use `as_survey_nonprob`):
- `calibrate_rake()`
- `effective_sample_size()`
- `weight_variability()`
- `summarize_weights()`
- (likely others — requires a full grep)

### Fix

1. Determine which construction pattern is correct for `ns_wave1` by checking
   the `surveycore` API
2. Update all affected examples to use the single correct pattern
3. Verify all examples pass `R CMD check`

This can be done without a separate plan — it's a search-and-replace with
verification. Track via the quick-wins checklist in Section H.

---

## F. Class System: Accurate `@returns` and Orientation

**Priority: medium.**

### Problem

**Factual errors in `@returns`:**
- `trim_weights()`: "An object of the same class as `data`" — false for plain
  `data.frame` inputs, which return a `weighted_df`
- `rescale_weights()`: same error

The correct statement: "A `weighted_df` when `data` is a plain `data.frame`;
otherwise an object of the same class as `data`."

**Undisclosed behavioral trap in nonresponse functions:**
- `adjust_nonresponse()` and `redistribute_weights()` return different numbers of
  rows depending on input class: `data.frame`/`weighted_df` keep all rows (with
  zero weights for excluded observations); `survey_taylor` and survey objects drop
  excluded rows entirely
- This behavioral difference is documented only as the last bullet in `@returns`,
  but it will silently break downstream code when a user switches input class
- It should appear in `@description` or a named `@section` ("Input class behavior")

**`n_positive` and `n_zero` in `summarize_weights()` are undefined:**
- Both columns appear in `@returns` without explanation
- A user seeing `n_zero = 3` in the output has no docs explaining what a
  zero-weight row means or what to do about it

### Fix

1. Correct `@returns` in `trim_weights()` and `rescale_weights()`
2. Promote the row-retention behavioral difference in `adjust_nonresponse()` and
   `redistribute_weights()` to `@description` or a named section
3. Define `n_positive` and `n_zero` in `summarize_weights()` docs

No separate plan needed. Add to quick-wins checklist in Section H.

---

## G. Package-Level Docs: Stale and Incomplete

**Priority: medium.**

### Problems

**`surveywts-package.R`** (the `?surveywts` help page):
- References `rake()` — a function that does not exist (it's `calibrate_rake()`)
- Key Functions section covers only 5 of 23 exported functions
- No mention of replicate weights, IPW, nonresponse adjustment, or utilities
- Will be the first help page many users read; currently misleads them

**`_pkgdown.yml`**:
- `create_group_jackknife_weights()` appears in the README function table but is
  absent from `_pkgdown.yml`; it will not appear in the pkgdown reference index

**README**:
- `help('calibrate_to_sample')` in the `calibrate_to_survey()` example output
  — wrong function name; should be `calibrate_to_survey`

### Fix

Update `surveywts-package.R` to reflect the current function set. Add
`create_group_jackknife_weights()` to `_pkgdown.yml`. Fix the README typo.

No separate plan needed. Add to quick-wins checklist.

---

## H. Quick-Win Fixes

These are concrete, bounded, independently fixable. No separate plan needed.
Work through this list before or alongside the larger initiatives.

### Reproducibility

- [ ] `adjust_nonresponse()` examples: add `set.seed()` before `sample()` calls
- [ ] `redistribute_weights()` examples: add `set.seed()` before `sample()` calls

### Factual errors

- [ ] `trim_weights()` `@description`: says excess is redistributed "equally";
      `@section Algorithm` says "proportionally" — reconcile these
- [ ] `trim_weights()` and `rescale_weights()` `@returns`: fix "same class as
      `data`" — false for plain `data.frame` inputs (returns `weighted_df`)
- [ ] `summarize_weights()` `@description`: lists 6 output columns; `@returns`
      lists 11 — add `min`, `max`, `n_positive`, `n_zero` to the description
- [ ] `rescale_weights()` first example: "Rescale weights to unit mean" comment
      precedes the `summarize_weights()` call, not the `rescale_weights()` call —
      move or relabel the comment

### Missing documentation

- [ ] `weight_variability()`: add `@references` — sibling `effective_sample_size()`
      has one; `weight_variability()` is equally citable (Kish 1965, design-effect
      literature)
- [ ] `as_taylor_design()`: add `@section Warnings` documenting
      `surveywts_warning_taylor_loses_variance` — the function always emits this
      warning but the help page has no Warnings section
- [ ] `mse` parameter in `create_gen_boot_weights()`, `create_gen_rep_weights()`,
      `create_sdr_weights()`, `create_brr_weights()`: currently documented as
      only a type annotation with no behavioral description — copy the pattern
      from `create_jackknife_weights()` which documents both options
- [ ] `create_replicate_weights()`: add required `@details` section — this is a
      Tier 4 dispatcher; the documentation standards require a high-level overview
      of each method; it is currently absent
- [ ] `ipw()` `estimating_eq` param: never states which value is the default;
      add "GEE is the default" (matching `method` param's "logit is the default"
      phrasing)
- [ ] `adjust_nonresponse()` `@returns`: promote the class-specific row-retention
      behavior difference to `@description` or a named `@section`
- [ ] `redistribute_weights()` `@returns`: same promotion as above

### Inadvertent content

- [ ] `redistribute_weights()` `@details`: contains an internal developer note
      ("does not call `redistribute_weights()` internally because it is currently
      the only call site; refactor if a second emerges") — remove from user docs

### Incorrect or misleading content

- [ ] `calibrate_to_survey()` `@param algorithm`: contains a migration note
      ("differs from the prior svrep-based behavior") that belongs in NEWS.md,
      not in user-facing parameter docs
- [ ] `calibrate_to_survey()` `@param control` `control_col_matches` sub-key:
      implementation detail that has no place in user-facing docs for a parameter
      almost no user will touch — move to an internal comment or remove

### `@returns` consistency

- [ ] `create_gen_rep_weights()` `@returns`: does not name `@variables$type`,
      unlike `create_gen_boot_weights()` which names `"bootstrap"` — make
      consistent

### Package-level

- [ ] `surveywts-package.R`: replace `rake()` with `calibrate_rake()`; expand
      Key Functions to cover at least one function per family (calibration,
      nonresponse, propensity, replicate, utilities, diagnostics)
- [ ] `_pkgdown.yml`: add `create_group_jackknife_weights` to the Replicate
      Weights section
- [ ] README: fix `help('calibrate_to_sample')` → `help('calibrate_to_survey')`

### Dataset docs / examples

- [ ] `ipw()` GEE example: uses inline synthetic data (`nps_gee`, `ref_gee_df`)
      instead of package data — replace with a package dataset per the
      documentation standards (all examples must use package data)

### Constructor pattern (see Section E)

- [ ] Grep for all uses of `as_survey_nonprob` in examples; replace with the
      correct construction pattern once it is confirmed

---

## Per-Function Issue Reference

Quick lookup for which functions have known gaps. This is not exhaustive — see the
full subagent reports for detailed findings.

| Function | Key gaps |
|----------|----------|
| `calibrate()` | `reference_design` has no use-case framing; `wt_name` "ignored" behavior unexplained; no downstream step in examples |
| `calibrate_rake()` | Constructor pattern inconsistency in examples; `cap` param ratio vs. absolute framing is confusing; `weighting_history` referenced but not explained |
| `calibrate_linear()` | `bounds` (the distinctive feature) absent from all examples; `unit_scale` → `d_k` notation undefined; `bounds_scale` constraint `L < 1 < U` unexplained |
| `calibrate_logit()` | `g-weight` undefined; `bounds` never shown in examples; no "when to use vs. rake" guidance |
| `poststratify()` | `260000000` in `type = "count"` example unexplained; `setdiff()` prose in params; cell-size edge case absent |
| `calibrate_to_survey()` | `reference_design` still plumbing-only; Algorithm section is methodology-specialist writing; `variables` param uses "random" as jargon |
| `calibrate_to_estimate()` | No simple example (only the complex vcov path); `unit_scale` → svrep internal arg name leaked; no comparison with `calibrate_to_survey()` |
| `adjust_nonresponse()` | propensity methods (`"propensity-cell"`, `"propensity"`) have no examples; `sample()` without `set.seed()`; `@note` MAR assumption unexplained; row-retention trap in `@returns` |
| `redistribute_weights()` | Developer note in user docs; `sample()` without `set.seed()`; `survey_replicate -> error` notation in params is informal |
| `effective_sample_size()` | "Kish's" in title; no interpretation guidance ("is n_eff = 1456 good?"); constructor inconsistency in examples |
| `weight_variability()` | "Design effect" undefined; no interpretation guidance; missing `@references` |
| `summarize_weights()` | Description lists 6 columns, `@returns` lists 11; `n_positive`/`n_zero` undefined |
| `trim_weights()` | "equally" vs. "proportionally" contradiction; `@returns` class error; `survey_replicate` example is 10-line setup for a one-line call |
| `rescale_weights()` | Title implies a choice ("mean or sum") that doesn't exist; `n_h / W_h` notation undefined; `@returns` class error; example comment on wrong line |
| `ipw()` | Mechanism-before-motivation description; GEE example uses inline data; `estimating_eq` default unstated; variance details section is long before plain-language summary |
| `create_bootstrap_weights()` | `type` options (5 methods) with no selection guidance; NPS example is incomplete (missing `ipw()` step); purpose of output never stated |
| `create_brr_weights()` | Substantially thinner than siblings; `mse` undocumented; `@returns` one sentence vs. multi-paragraph in jackknife; no Warnings section |
| `create_jackknife_weights()` | Best-documented of the replicate family; `replicates = 2L` in example below recommended minimum of 50 |
| `create_gen_boot_weights()` | 12 `variance_estimator` options with no selection guidance; `mse` undocumented; `tau` guidance absent |
| `create_gen_rep_weights()` | "Deterministic" claim contradicted by `seed` param (unexplained); `max_replicates = Inf` natural count unexplained; `@returns` inconsistency |
| `create_sdr_weights()` | Ordering sensitivity not in description; `sort_var` version note in `@param`; example bypasses `sort_var` for stratified design |
| `create_replicate_weights()` | Description reads as code maintainer note; `@details` absent (required for Tier 4 dispatchers); DAGJK undefined; return-type ambiguity |
| `as_taylor_design()` | "Taylor design" / "replicate design" undefined in title; no use-case motivation; warning always fires but no Warnings section |

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
1. Section H (quick wins) — no design needed; knock these out opportunistically
2. Section E + F (constructor fix, `@returns` accuracy) — bounded, standalone
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
| `plans/doc-getting-started.md` | Section B + D: conceptual article + glossary | Not started |
| `plans/doc-method-choice-guidance.md` | Section C: when-to-use content per family | Not started |
