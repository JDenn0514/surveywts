# Documentation Improvement Plan

**Created:** 2026-06-26
**Revised:** 2026-08-26 — reconciled against `doc-rewrite` (Phase 1/2, PRs #79–#80)
and re-verified against current source. Resolved items removed; open items
confirmed live.
**Status:** Open — pre-implementation review
**Source:** Multi-agent documentation audit of all 23 exported functions, the README,
`_pkgdown.yml`, and `surveywts-package.R`, evaluated from the perspective of an
R/tidyverse-fluent analyst who is not a survey methodology expert.

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
A–D below), and it made two **deliberate, documented decisions** that this
audit's recommendations conflict with:

1. No `set.seed()` in `adjust_nonresponse()` / `redistribute_weights()`
   examples — "following svrep convention."
2. `create_replicate_weights()` `@details` and `@references` deliberately
   deferred, pending a `comprehension-replicate-methods.md` plan. That plan
   is now written (2026-08-28), so this deferral is cleared — see Section H.

Where this revision below marks something as still open, it distinguishes
**oversights** (nobody decided this — just do it) from these **deliberate
calls** (decide whether you still agree before touching them).

The class-system-refactor (PRs #85–#89, merged through 2026-06-29) also
removed `weighted_df` and all `data.frame` input entirely, which retired a
handful of the original findings below outright (noted where relevant).

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
| B | Conceptual overview / Getting Started | Package-level + pkgdown | Open | Yes |
| C | Method-choice guidance | Calibration, replicate, nonresponse families | Open | Yes |
| D | Jargon: define or link recurring terms | All functions | Open | Yes |
| E | Constructor inconsistency | — | **Resolved** | — |
| F | Class system: accurate `@returns` + orientation | `adjust_nonresponse`, `redistribute_weights`, `summarize_weights` | Partially open | No — fix inline |
| G | Package-level docs stale | `surveywts-package.R`, `_pkgdown.yml`, README | Open (confirmed) | No — fix inline |
| H | Quick-win fixes (errors, omissions, reproducibility) | Scattered | Mostly open (confirmed item-by-item) | No — checklist below |

---

## A. Examples: Show What Comes Next

**Priority: highest.** Examples are the most-read part of any R help page.
**Status: fully open** — not touched by Phase 2 (which addressed *what data*
examples use, not *what comes next*).

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
`plans/doc-examples-overhaul.md` (to be written).

---

## B. Conceptual Overview / Getting Started

**Priority: high.** A single article would lift the entire package.
**Status: fully open** — no work has touched this.

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
survey_taylor / survey_nonprob
    │  create_*_weights()
    ▼
survey_replicate     ← adds replicate weight columns; enables bootstrap SEs
    │  as_taylor_design()
    ▼
survey_taylor        ← Taylor linearization design; SE via delta method
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

**Yes.** Requires content decisions about scope, structure, and which concepts
to define. File: `plans/doc-getting-started.md` (to be written).

---

## C. Method-Choice Guidance

**Priority: high.** **Status: fully open.**

### Problem

Every function family presents multiple methods with no documented basis for
choosing. A non-methodologist has no way to know:
- rake vs. linear vs. logit calibration
- 6 replicate weight methods
- 12 `variance_estimator` options in `create_gen_boot_weights()`
- 3 `method` options in `adjust_nonresponse()`

The `@seealso` links to siblings (added in Phase 1) but none of the functions
explain when to choose one over another.

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
  required `@details` section comparing methods. `calibrate()` already has a
  method-overview `@details` block (Phase 1); `create_replicate_weights()`
  still has none — this was deliberately deferred pending a comprehension
  plan for the replicate methods (see History), not an oversight. Decided
  2026-08-28: write that plan (see Plans to Write)
- **Individual functions**: two-sentence "When to use this" note in `@description`
- **Getting Started article** (Section B): comparative table for each family

### Needs own plan?

**Yes.** The method-choice content requires methodological decisions about how to
frame each comparison for a non-expert audience. File:
`plans/doc-method-choice-guidance.md` (to be written).

---

## D. Jargon: Define or Link Recurring Terms

**Priority: high.** **Status: fully open.**

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

**Yes** — the glossary content decisions and which terms warrant full definitions
vs. one-line anchors are non-trivial. Fold into `plans/doc-getting-started.md`.

---

## E. Constructor Inconsistency — RESOLVED

Originally flagged: examples used `surveycore::as_survey_nonprob(ns_wave1,
weights = weight)` while the `ns_wave1` dataset doc used
`surveycore::survey_nonprob(ns_wave1, variables = list(weights = "weight"))` —
apparently contradictory constructors.

**Re-verified 2026-08-26:** `R/data.R` now constructs `ns_wave1` examples via
`surveycore::as_survey_nonprob()` consistently (fixed in or before PR #85,
2026-06-25). `survey_nonprob()` is the low-level S7 constructor;
`as_survey_nonprob()` is the intended friendly wrapper — these were never
actually contradictory, and current usage is consistent throughout. No action
needed.

---

## F. Class System: Accurate `@returns` and Orientation

**Priority: medium.** **Status: partially resolved.**

### Resolved by the class-system-refactor

The original finding — `trim_weights()` and `rescale_weights()` `@returns`
saying "same class as `data`," which was false for plain `data.frame` input
(returned `weighted_df`) — is now moot. `data.frame`/`weighted_df` input is
rejected outright (`surveywts_error_not_survey_base`), so "same class as
`data`" is now accurate. **Re-verified 2026-08-26** against current
`R/trim_weights.R` and `R/rescale_weights.R` — no fix needed.

### Still open

**Undisclosed behavioral trap in nonresponse functions:**
- `adjust_nonresponse()` and `redistribute_weights()` return different numbers of
  rows depending on input class: `survey_taylor`/`survey_nonprob` inputs drop
  excluded rows entirely (confirm current row-retention behavior still varies
  by class post-refactor before writing the fix — the refactor changed input
  handling broadly enough that this needs a fresh check, not just a doc edit)
- This behavioral difference, if still present, is documented only as the last
  bullet in `@returns` — it should appear in `@description` or a named
  `@section` ("Input class behavior")

**`n_positive` and `n_zero` in `summarize_weights()` are still undefined:**
- Confirmed in current source (`R/summarize_weights.R` line 21) — both columns
  appear in `@returns` with no explanation
- A user seeing `n_zero = 3` in the output has no docs explaining what a
  zero-weight row means or what to do about it

### Fix

1. Confirm the row-retention behavior against current source, then promote it
   to `@description` or a named section in `adjust_nonresponse()` and
   `redistribute_weights()`
2. Define `n_positive` and `n_zero` in `summarize_weights()` docs

No separate plan needed. Add to quick-wins checklist in Section H.

---

## G. Package-Level Docs: Stale and Incomplete

**Priority: medium.** **Status: confirmed still open** (re-verified
2026-08-26).

### Problems

**`surveywts-package.R`** (the `?surveywts` help page) — confirmed current:
- Still references `rake()` (line 13) — a function that does not exist (it's
  `calibrate_rake()`)
- Key Functions section covers only 9 of 23 exported functions (Calibration,
  Nonresponse, Diagnostics only — no replicate weights, IPW, or utilities)

**`_pkgdown.yml`** — confirmed current:
- `create_group_jackknife_weights()` is still absent; it will not appear in
  the pkgdown reference index

**README** — confirmed current:
- Line 190: `help('calibrate_to_sample')` — wrong function name; should be
  `calibrate_to_survey`

### Fix

Update `surveywts-package.R` to reflect the current function set. Add
`create_group_jackknife_weights()` to `_pkgdown.yml`. Fix the README typo.

No separate plan needed. Add to quick-wins checklist.

### Outcome (2026-08-28, branch `docs/package-level-docs`)

Item 1 shipped. Items 2 and 3 did not survive verification against current
source.

**Item 1 — `surveywts-package.R`: DONE.** `rake()` is gone. `@section Key
Functions:` now names all 23 exports across 7 families, and `@description`
covers the current function set.

**Item 2 — `_pkgdown.yml`: DROPPED, not needed.**
`create_group_jackknife_weights()` no longer exists. Commit `986b8bc` merged
it into `create_jackknife_weights(type = "grouped")`. It is absent from
`NAMESPACE`, `R/`, and `man/`. A `contents:` entry with no matching `.Rd`
breaks the pkgdown reference build, so the entry must not be added.
`_pkgdown.yml` was audited against `NAMESPACE` instead: all 23 exports
appear exactly once. The file is already correct.

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
tagged **[open]** (confirmed still present, no known reason not to fix),
**[decide]** (a past deliberate call — confirm you still want it before
changing), or removed if resolved.

### Reproducibility

- [x] **[decided 2026-08-28]** Keep the no-seed svrep convention in the
      `adjust_nonresponse()` / `redistribute_weights()` examples. Make no
      change to those examples. Section A's `set.seed()` standard now carries
      an exception for these two functions.

### Factual errors

- [x] ~~`trim_weights()`/`rescale_weights()` `@returns`: "same class as
      `data`"~~ — **resolved**, moot after class-system-refactor (Section F)
- [ ] **[open]** `trim_weights()` `@description` says excess is redistributed
      "equally" (line 13); `@section Algorithm` says "proportionally" (line
      71) — reconcile these
- [ ] **[open]** `summarize_weights()` `@returns` lists 11 columns
      (`n`, `n_positive`, `n_zero`, `mean`, `cv`, `min`, `p25`, `p50`, `p75`,
      `max`, `ess`) — confirm `@description` covers the same set or references
      `@returns` instead of restating a shorter list
- [ ] **[open]** `rescale_weights()` first example: verify the "Rescale
      weights to unit mean" comment lines up with the `rescale_weights()` call
      and not a trailing `summarize_weights()` call

### Missing documentation

- [ ] **[open]** `weight_variability()`: still no `@references` — confirmed
      absent in current source; sibling `effective_sample_size()` has one
- [ ] **[open]** `as_taylor_design()`: still no `@section Warnings` —
      confirmed absent; the function always emits
      `surveywts_warning_taylor_loses_variance` but the help page doesn't say so
- [ ] **[open]** `mse` parameter in `create_gen_boot_weights()`,
      `create_gen_rep_weights()`, `create_sdr_weights()`, `create_brr_weights()`:
      confirmed still just a bare type annotation ("`logical(1)`, default
      `TRUE`") with no behavioral description, unlike `create_jackknife_weights()`
      and `create_bootstrap_weights()` which explain it fully
- [ ] **[unblocked 2026-08-28]** `create_replicate_weights()`: still no
      `@details` section (Tier 4 dispatcher requirement). The prerequisite
      comprehension plan is **complete** —
      `plans/comprehension-replicate-methods.md` verifies all 14 sources and
      carries a draft `@details` block ready to adapt. This item stays open
      only for the roxygen edit itself. Three findings from that doc change
      what to write:
      - The dispatcher accepts **six** `method` strings, not seven.
        `create_group_jackknife_weights()` does not exist; delete-a-group
        jackknife is `create_jackknife_weights(type = "grouped")`.
      - **Four citations need correction before `@references` is written.**
        Read that doc's "Citation verification" section first. The
        Chrostowski entry names two co-authors who did not write the paper.
      - `tau` belongs to `create_gen_boot_weights()` only. BRR uses `rho`,
        a different quantity, and its default `rho = 0` deserves a warning.
- [x] ~~`ipw()` `estimating_eq` param: never states default~~ — **resolved**,
      already documents "`"gee"` (the default) or `"mle"`"
- [ ] **[open]** `adjust_nonresponse()` / `redistribute_weights()` `@returns`:
      promote the class-specific row-retention behavior difference to
      `@description` or a named `@section` — **re-verify the behavior itself
      first**, since the class-system-refactor changed input handling broadly

### Inadvertent content

- [ ] **[open]** `redistribute_weights.R` line 57 still contains an internal
      developer note ("...because it is currently the only call site; refactor
      if a second emerges") — remove from user docs

### Incorrect or misleading content

- [ ] **[open]** `calibrate_to_survey()` `@param algorithm` (line 151) still
      contains a migration note ("differs from the prior svrep-based
      behavior") that belongs in NEWS.md, not user-facing parameter docs
- [ ] **[open]** `calibrate_to_survey()` `@param control` (lines 60, 126) still
      documents `control_col_matches` as a user-facing sub-key — implementation
      detail; move to an internal comment or remove

### `@returns` consistency

- [ ] `create_gen_rep_weights()` `@returns`: verify whether it names
      `@variables$type`, unlike `create_gen_boot_weights()` which names
      `"bootstrap"` — make consistent if still inconsistent

### Package-level

- [x] **[done 2026-08-28]** `surveywts-package.R`: replaced `rake()` with
      `calibrate_rake()`; Key Functions now covers all 23 exports across 7
      families. See Section G "Outcome".
- [x] ~~`_pkgdown.yml`: add `create_group_jackknife_weights` to the
      Replicate Weights section~~ — **dropped 2026-08-28**, the function no
      longer exists (merged into `create_jackknife_weights(type =
      "grouped")` in `986b8bc`). Adding the entry would break the pkgdown
      reference build. `_pkgdown.yml` audited against `NAMESPACE`: all 23
      exports already present, no change needed.
- [ ] **[open, blocked]** README: the stale `help('calibrate_to_sample')`
      line is generated chunk output of an upstream
      `svrep::calibrate_to_sample()` message, not a typo — do NOT rename it.
      surveywts no longer calls that path, so the fix is to re-render
      `README.md` from `README.Rmd`. Blocked on the "Broken README.Rmd
      chunks" items below.

### Broken README.Rmd chunks

Found 2026-08-28, extended 2026-08-31, while working Section G item 3.
`devtools::build_readme()` fails, so `README.md` cannot be re-rendered at
all. Two chunks are broken. Every item below is verified against the
bundled data. All must land before the Section G README item can close.

`README.md` is therefore stale by an unknown margin. Its current output
blocks were produced by an older render, against an older data schema.

**The `ipw` chunk (line 120 onward):**

- [ ] **[open]** `README.Rmd:126` — the chunk passes
      `predictors = c("gender", "age_group", "race_ethn", "educ")`, but only
      `gender` is a column of `ns_wave1`. `age_group`, `race_ethn`, and
      `educ` do not exist in that dataset, so the chunk errors.
- [ ] **[open]** `README.Rmd:113` — the paragraph above the chunk names
      `acs_wy_2022` as a bundled reference survey. No such dataset is in
      `data/`. The bundled sets are `cps_2023`, `gss_2024`, `npors_2025`,
      `npors_2025_clean`, `ns_wave1`, `pew_2016_optin`, and
      `pew_2016_synth_pop`. The same line states that each tibble is "paired
      with a survey design companion (e.g., `gss_2024_svy`)". No
      `gss_2024_svy` object exists. Nothing named `*_svy` is exported, and
      `data/` holds none; the only `*_svy` name in the repo is
      `ns_wave1_svy`, a local variable in `data-raw/ns-wave1.R` that line
      339 of that script discards.

**The `calibrate-to-survey` chunk (line 160 onward):**

- [ ] **[open]** `README.Rmd:161` — passes `npors_2025_clean_svy` to
      `create_bootstrap_weights()`. No such object exists. `data/` holds the
      `npors_2025_clean` tibble only.
- [ ] **[open]** `README.Rmd:165` — filters on `gss_2024$gender` and
      `gss_2024$age_group`. Neither column is in `gss_2024`. That dataset
      carries `sex`, `age`, and `age_f3`.
- [ ] **[open]** `README.Rmd:178` — passes `variables = c(gender,
      age_group)` to `calibrate_to_survey()`. Same two missing columns as
      line 165.
- [ ] **[open]** `README.Rmd:163` — the comment states that `gss_2024_svy`
      "retains all rows including those with NA sex (19 rows)". The object
      does not exist, and the claim is unverified.

### Dataset docs / examples

- [ ] `ipw()` GEE example: verify whether it still uses inline synthetic data
      (`nps_gee`, `ref_gee_df`) instead of package data — replace with a
      package dataset if so, per the documentation standards

### Constructor pattern (see Section E)

- [x] ~~Grep for `as_survey_nonprob` usage and reconcile~~ — **resolved**,
      usage is consistent throughout (Section E)

---

## Per-Function Issue Reference

Quick lookup for which functions have known gaps, re-verified 2026-08-26.
Constructor-inconsistency and `weighted_df`-return mentions from the original
audit are removed as resolved/moot. This is not exhaustive — see the full
subagent reports for detailed findings.

| Function | Key gaps |
|----------|----------|
| `calibrate()` | `reference_design` has no use-case framing; `wt_name` behavior unexplained; no downstream step in examples |
| `calibrate_rake()` | `cap` param ratio vs. absolute framing is confusing; `weighting_history` referenced but not explained |
| `calibrate_linear()` | `bounds` (the distinctive feature) absent from all examples; `unit_scale` → `d_k` notation undefined; `bounds_scale` constraint `L < 1 < U` unexplained |
| `calibrate_logit()` | `g-weight` undefined; `bounds` never shown in examples; no "when to use vs. rake" guidance |
| `poststratify()` | `260000000` in `type = "count"` example unexplained; `setdiff()` prose in params; cell-size edge case absent |
| `calibrate_to_survey()` | Migration note and `control_col_matches` leaked into user docs (Section H); Algorithm section is methodology-specialist writing |
| `calibrate_to_estimate()` | No simple example (only the complex vcov path); `unit_scale` → svrep internal arg name leaked; no comparison with `calibrate_to_survey()` |
| `adjust_nonresponse()` | propensity methods (`"propensity-cell"`, `"propensity"`) have no examples; `sample()` without `set.seed()` (deliberate — see H); row-retention trap in `@returns` needs re-verification |
| `redistribute_weights()` | Developer note in user docs (Section H); `sample()` without `set.seed()` (deliberate — see H) |
| `effective_sample_size()` | "Kish's" in title; no interpretation guidance ("is n_eff = 1456 good?") |
| `weight_variability()` | "Design effect" undefined; no interpretation guidance; missing `@references` |
| `summarize_weights()` | `n_positive`/`n_zero` undefined |
| `trim_weights()` | "equally" vs. "proportionally" contradiction (confirmed); `survey_replicate` example is 10-line setup for a one-line call |
| `rescale_weights()` | `n_h / W_h` notation undefined; example comment placement needs verification |
| `ipw()` | Mechanism-before-motivation description; GEE example may use inline data (verify); variance details section is long before plain-language summary |
| `create_bootstrap_weights()` | `type` options (5 methods) with no selection guidance; purpose of output never stated |
| `create_brr_weights()` | Substantially thinner than siblings; `mse` undocumented; no Warnings section |
| `create_jackknife_weights()` | Best-documented of the replicate family; verify example `replicates` value meets recommended minimum |
| `create_gen_boot_weights()` | 12 `variance_estimator` options with no selection guidance; `mse` undocumented; `tau` guidance absent |
| `create_gen_rep_weights()` | "Deterministic" claim contradicted by `seed` param (unexplained); `@returns` `@variables$type` consistency to verify |
| `create_sdr_weights()` | Ordering sensitivity not in description; `sort_var` version note in `@param` |
| `create_replicate_weights()` | `@details` absent — deliberately deferred pending comprehension plan (Section H); DAGJK undefined |
| `as_taylor_design()` | "Taylor design" / "replicate design" undefined in title; no use-case motivation; warning always fires but no Warnings section (confirmed) |

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
2. Section F (row-retention re-verification, `n_positive`/`n_zero`) — bounded,
   standalone
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
| `plans/comprehension-replicate-methods.md` | Prerequisite for `create_replicate_weights()` `@details`/`@references` (Section C/H) | **Complete 2026-08-28.** All 14 sources verified; 4 citations need correction; carries a draft `@details` block and the Section C method-choice table |
