# Method-choice guidance (Section C)

**Created:** 2026-08-31.
**Status:** Ready for implementation — adversarially reviewed 2026-08-31
(see the review log at the bottom).
**Source:** `plans/doc-improvements.md` Section C.
**Verified sources for claims:**
`plans/comprehension-replicate-methods.md` (CRM) and
`plans/archive/calibration-framework/comprehension-calibration-framework.md`
(CCF). Every claim this plan puts into roxygen maps to a row in the claim
ledger below.

**Audience** (from the top of `doc-improvements.md`): an R/tidyverse-fluent
analyst who is not a survey methodology expert. Write choice guidance in
that reader's words. Name the condition the reader can check ("every
stratum holds exactly two PSUs"), not the theory behind it.

**Deliverable of the implementation session:** roxygen edits in `R/`, two
`@references` additions, two `reference-map.yaml` rows, `devtools::document()`,
`devtools::check()`, PR to `develop`. No code-path changes.

---

## What changed since Section C was written

Section C (drafted 2026-06-26) predates PR #97 (merged 2026-08-31). Three
of its premises are now stale:

1. **`create_replicate_weights()` has its `@details` method overview and
   `@references`** (`R/create_replicate_weights.R:28-126`), adapted from
   CRM's draft block with verified citations. The replicate dispatcher
   needs no new content — Task 3 verifies it and stops.
2. **`calibrate()` has its method `@details`** (`R/calibrate.R:85-117`,
   Phase 1) with mechanism-to-consequence framing and verified citations.
   One gap remains: the prose never says that [poststratify()] is a
   separate function for cell targets. The documentation standard's own
   Tier 4 example calls for that note.
3. **`mse` is documented with prose on all four thin creators**
   (Section H, 2026-08-31). The "type-only roxygen" rows in CRM's
   parameter table are stale for `mse`.

What is still open, and what this plan owns: per-function "when to use
this" guidance for the calibration, replicate, and nonresponse families;
`variance_estimator` guidance on `create_gen_boot_weights()`; a
`type`-choice pointer on `create_bootstrap_weights()`.

---

## Corrections to Section C's draft tables

The implementation must not copy Section C's draft tables. Four defects:

1. **Calibration table, rake row: "slowest for many margins" — no
   source.** Neither CCF nor the mapped papers rank raking's speed.
   The sourced speed claim is linear's: one exact Newton step, no
   iteration (CCF claim ledger, Deville et al. 1993 §11). Drop the
   rake speed claim.
2. **Calibration table, logit row: "starting weights are far from
   targets" — inverted.** CCF's gotcha list says the opposite: when the
   gap between sample and targets is large relative to the bounds, no
   solution exists inside `(L, U)` and Newton-Raphson diverges (CCF,
   "Non-existence of solution for bounded methods"). Logit is for
   bounding the adjustment, not for rescuing a distant start.
3. **Replicate table: superseded.** CRM's "Method-choice table (feeds
   Section C)" replaces it, as CRM itself records. The draft's "Gen-rep:
   deterministic alternative to gen-boot" gets the lineage backwards —
   gen-boot is the randomized cousin of gen-rep (CRM, "the real
   lineage"). The shipped dispatcher `@details` already uses the correct
   "deterministic counterpart" framing.
4. **`adjust_nonresponse()` table: plausible but unsourced.** No
   comprehension doc covers the nonresponse family. Task 4 reframes the
   guidance mechanically (from code behavior) with no citations.

---

## Where each piece lives

| Piece | Surface | Owner |
|---|---|---|
| Method comparison per dispatcher | `@details` on `calibrate()`, `create_replicate_weights()` | Done (Phase 1, PR #97). Task 1 adds one paragraph to `calibrate()`. |
| Per-function "When to use" | `@details` opener on each sibling | This plan (Tasks 1–4) |
| `variance_estimator` choice | New `@section Choosing a target:` on `create_gen_boot_weights()`; cross-reference from `create_gen_rep_weights()` | This plan (Task 3) |
| Bootstrap `type` choice (5 probability schemes) | Pointer to `svrep::as_bootstrap_design()` in `@param type` | This plan (Task 3). Real guidance needs a comprehension doc — see Flagged claims. |
| Family comparison tables, glossary, workflow narrative | Getting Started article | `plans/doc-getting-started.md` (hand off; see Handoffs) |

**Placement decision — `@details`, not `@description`.** Section C said
"two-sentence note in `@description`". The documentation standard caps
`@description` at 1–3 sentences, and most touched functions already use
2–3. The note therefore goes at the top of `@details` as a paragraph that
opens with `**When to use.**` — inserted between `@returns` and the first
`@section` tag where no `@details` exists, or prepended where one does.
This overrides Section C's placement, not its content.

**Citation policy** (per `.claude/standards/function-documentation.md`):
inline citations only where a comprehension doc verifies them. CRM covers
the replicate family; CCF covers the calibration mechanisms. The
nonresponse and sample-calibration edits carry no citations. Every inline
citation must appear in that function's `@references` block; two blocks
need additions (Task 3, items 3g–3h).

---

## Claim ledger

Every claim the drafted text asserts, with its source. "Mechanical" means
the claim restates code behavior or a function signature and needs no
citation.

| # | Claim | Source |
|---|---|---|
| L1 | Raking keeps weights strictly positive; the ratio is unbounded above | CCF, multiplicative method; gotcha "Unbounded upper g-weights" |
| L2 | Linear is exact in one step with `bounds = NULL` | CCF claim ledger (Deville et al. 1993 §11) |
| L3 | Linear can produce negative weights on large discrepancies | CCF, gotcha "Negative calibrated weights (linear method)" |
| L4 | Logit bounds the ratio of calibrated to starting weight in open `(L, U)`; weights stay positive | CCF (Deville & Sarndal 1992; bounds constrain `w_k/d_k`) |
| L5 | Too-tight bounds make a solution impossible; the iteration fails | CCF, gotcha "Non-existence of solution for bounded methods" |
| L6 | A populated cell with zero sample count makes post-stratification undefined | CCF (Deville & Sarndal 1992, remark after Result 4) |
| L7 | Bootstrap works for quantiles; the jackknife's quantile SE does not improve with sample size | CRM (Elliott & Valliant 2017; VDK 2018 §15.4.1) |
| L8 | Bootstrap is the practical choice when no closed-form variance exists | CRM (Wu 2022 §6.1, §6.3) |
| L9 | `type = "quasi-randomization"` refits the weighting model in every replicate | CRM + `R/create_bootstrap_weights.R` Algorithm section |
| L10 | Jackknife suits stratified multi-stage designs with 2+ PSUs per stratum, for totals/means/ratios | CRM (VDK 2018 §15.4.1) |
| L11 | With exactly 2 PSUs per stratum, prefer BRR over the jackknife | CRM (VDK 2018: "no good reason to use JK2") |
| L12 | BRR requires exactly two PSUs per stratum; proven for quantiles and nonlinear statistics | CRM (VDK 2018 §15.4.1; Dippo, Fay & Morganstein 1984 §5.4) |
| L13 | `rho = 0` zeroes one PSU per stratum per replicate; a ratio can be undefined in a replicate; `rho > 0` avoids it | CRM (Dippo, Fay & Morganstein 1984 §4) |
| L14 | Gen-boot is the general-purpose fallback; the documented approach for Poisson sampling; 750+ replicates recommended | CRM (Beaumont & Patak 2012 §3.3, §4, Table 1) |
| L15 | Horvitz-Thompson target can imply a negative variance for some designs | CRM (Beaumont & Patak 2012 §2) |
| L16 | Yates-Grundy requires a fixed sample size; not appropriate for Poisson sampling | CRM (Beaumont & Patak 2012 §2, §4) |
| L17 | Poisson Horvitz-Thompson is the valid target under Poisson sampling | CRM (Beaumont & Patak 2012 §4, Eq. 12) |
| L18 | SD1/SD2 are the successive-difference estimators; they read row order | CRM (Ash 2014 §1.1) |
| L19 | Seven of the 12 `variance_estimator` options have no support in the mapped papers | CRM, "Code and literature gaps" item 5 plus `"Stratified Multistage SRS"` (Bellhouse 1985 never treats it as a gen-boot target) |
| L20 | Gen-rep decomposes the target matrix into fixed components; no `replicates` argument; `max_replicates` caps the count | CRM (Fay 1989 §2) + signature |
| L21 | SDR is for systematic samples from a sorted list; re-sorted rows give a wrong answer with no error | CRM (Ash 2014, Theorem 1) |
| L22 | `adjust_nonresponse()` method mechanisms (named cells / model-built quantile cells / individual IPW; `max_adjust` warning) | Mechanical — `R/adjust_nonresponse.R` |
| L23 | `calibrate_to_survey()` propagates the control survey's sampling error; `calibrate_to_estimate()` takes point estimates + vcov | Mechanical — existing `@description` blocks of both functions |
| L24 | Raking is the package default | Mechanical — `calibrate()` signature |

## Flagged claims — do not assert

These would need new comprehension work. The implementation must not
state them.

- **Any speed ranking of rake vs. logit**, or "slowest for many margins."
- **Choice guidance among the five probability bootstrap schemes**
  (`"Rao-Wu-Yue-Beaumont"`, `"Rao-Wu"`, `"Antal-Tille"`, `"Preston"`,
  `"Canty-Davison"`). No mapped source distinguishes them. The fix is a
  pointer to `svrep::as_bootstrap_design()`. Real guidance needs a
  comprehension doc (candidate: `comprehension-bootstrap-schemes.md`).
- **Cited nonresponse method-choice heuristics** ("per VDK ch. 13...").
  The mapped sources (Chang & Kott 2008; VDK 2018 ch. 13) are in the
  knowledge base but unaudited. Cited guidance needs
  `comprehension-nonresponse-methods.md` first. Task 4 ships mechanical,
  uncited wording.
- **Replicate-count economy for BRR.** CRM: none of the Fay-family
  sources state it.
- **Normative "default choice" language** beyond the mechanical fact
  that a value is the package default.

---

## Task 1 — Calibration family

**Files:** `R/calibrate.R`, `R/calibrate_rake.R`, `R/calibrate_linear.R`,
`R/calibrate_logit.R`, `R/poststratify.R`.

All inline citations below already appear in each function's
`@references` block (verified 2026-08-31 against the roxygen and
`reference-map.yaml`).

- [ ] **1a. `calibrate()`** — insert this paragraph into `@details`
  between the logit paragraph and the closing "For full algorithm..."
  paragraph (currently before `R/calibrate.R:115`):

  ```r
  #' Post-stratification does not route through `calibrate()`. When you
  #' have population values for every joint cell of the stratification
  #' variables — a full cross-tabulation, not separate margins — use
  #' [poststratify()], which matches those cells exactly in one pass.
  ```

- [ ] **1b. `calibrate_rake()`** — insert a `@details` block between
  `@returns` (ends before `R/calibrate_rake.R:107`) and
  `@section Algorithm:`:

  ```r
  #' @details
  #' **When to use.** Raking is the default calibration method. Choose it
  #' when your targets are separate margins (for example sex, age group,
  #' and region) and the weights must stay positive (Deville, Sarndal &
  #' Sautory 1993). The weight ratio has no upper bound, so a margin far
  #' from the sample can produce extreme weights; use `cap`, or
  #' [trim_weights()] afterward, to limit them.
  ```

  Claims: L1, L24.

- [ ] **1c. `calibrate_linear()`** — insert between `@returns` and
  `@section Algorithm:` (before `R/calibrate_linear.R:116`):

  ```r
  #' @details
  #' **When to use.** Choose linear calibration when speed matters: with
  #' `bounds = NULL` the solution is exact in one step, with no iteration
  #' (Deville, Sarndal & Sautory 1993). The weight adjustment is
  #' unbounded in both directions, so a large gap between the sample and
  #' the targets can produce negative weights. If negative weights are
  #' unacceptable, set `bounds`, or use [calibrate_rake()] or
  #' [calibrate_logit()].
  ```

  Claims: L2, L3.

- [ ] **1d. `calibrate_logit()`** — insert between `@returns` and
  `@section Algorithm:` (before `R/calibrate_logit.R:121`):

  ```r
  #' @details
  #' **When to use.** Choose logit calibration when you must limit how
  #' far any weight can move: the ratio of calibrated to starting weight
  #' stays inside the open interval `(L, U)`, so every weight stays
  #' positive and none grows without limit (Deville & Sarndal 1992).
  #' Bounds that are too tight for the targets make a solution
  #' impossible, and the iteration fails to converge; widen `bounds` or
  #' switch to [calibrate_rake()].
  ```

  Claims: L4, L5.

- [ ] **1e. `poststratify()`** — insert between `@returns` and
  `@section Algorithm:` (before `R/poststratify.R:81`):

  ```r
  #' @details
  #' **When to use.** Choose post-stratification when you have population
  #' values for every joint cell of the stratification variables and
  #' every cell contains sample members. A populated cell with no sample
  #' members makes the adjustment undefined (Deville & Sarndal 1992).
  #' With several variables the cells thin out quickly; when cells run
  #' empty, match margins instead via [calibrate()].
  ```

  Claims: L6. The existing `@description` already carries the
  cells-vs-margins contrast — leave it unchanged.

**Acceptance (Task 1):** the five insertions match the text above; no
other roxygen lines in these files change; every citation named inline
exists in that file's `@references`.

---

## Task 2 — Sample-calibration cross-references

**Files:** `R/calibrate_to_survey.R`, `R/calibrate_to_estimate.R`.

**Scope note:** Section C names three families; this task extends it by
one item because `doc-improvements.md`'s per-function table flags "no
comparison with `calibrate_to_survey()`" and the fix is the same
"When to use" pattern. Both texts are mechanical (L23) — no citations.

- [ ] **2a. `calibrate_to_survey()`** — insert a `@details` block before
  the first `@section` tag (prepend to `@details` if one exists):

  ```r
  #' @details
  #' **When to use.** Use [calibrate()] when your targets are fixed
  #' census values with no sampling error of their own. Use
  #' `calibrate_to_survey()` when the targets come from another survey:
  #' the control survey's sampling error then carries into the replicate
  #' variance. When you have only published estimates and their
  #' variance-covariance matrix — not the control survey's data — use
  #' [calibrate_to_estimate()].
  ```

- [ ] **2b. `calibrate_to_estimate()`** — same placement rule:

  ```r
  #' @details
  #' **When to use.** Use `calibrate_to_estimate()` when you have only
  #' point estimates and their variance-covariance matrix, for example
  #' published totals from a statistical agency. When you have the
  #' control survey itself with replicate weights, use
  #' [calibrate_to_survey()], which estimates the targets and their
  #' uncertainty directly.
  ```

**Acceptance (Task 2):** both insertions present; no citations added; no
duplication with each function's existing `@description` (if the
implementer finds overlap, trim the new text, not the description).

---

## Task 3 — Replicate family

**Files:** `R/create_bootstrap_weights.R`, `R/create_jackknife_weights.R`,
`R/create_brr_weights.R`, `R/create_gen_boot_weights.R`,
`R/create_gen_rep_weights.R`, `R/create_sdr_weights.R`,
`R/create_replicate_weights.R` (verify only), `.claude/reference-map.yaml`.

- [ ] **3a. `create_replicate_weights()` — verify, no edit.** Confirm the
  `@details` block still matches CRM's draft in substance and that all
  ten inline-cited works appear in `@references`. If both hold, this
  item closes with no diff.

- [ ] **3b. `create_bootstrap_weights()`** — two edits.

  Prepend to the existing `@details` (before the SRS-wrap paragraph at
  `R/create_bootstrap_weights.R:63`):

  ```r
  #' **When to use.** Choose the bootstrap when you estimate a median or
  #' another quantile — the jackknife standard error for a quantile does
  #' not improve as the sample grows (Elliott & Valliant 2017) — or when
  #' your estimator has no textbook variance formula (Wu 2022). For a
  #' non-probability sample with a reference probability sample, use
  #' `type = "quasi-randomization"`, which refits the weighting model
  #' inside every replicate.
  #'
  ```

  Append to `@param type` (after the existing option list): "See
  [svrep::as_bootstrap_design()] for how the five probability-sample
  variants differ."

  Claims: L7, L8, L9. Elliott & Valliant (2017) and Wu (2022) are in
  this function's `@references` (verified).

- [ ] **3c. `create_jackknife_weights()`** — insert a `@details` block
  between `@returns` and `@section Algorithm:` (before
  `R/create_jackknife_weights.R:96`):

  ```r
  #' @details
  #' **When to use.** Choose the jackknife for a stratified, possibly
  #' multi-stage probability sample where every stratum holds two or
  #' more PSUs and you estimate a total, a mean, or a ratio (Valliant,
  #' Dever & Kreuter 2018, Section 15.4). Do not use it for a median or
  #' another quantile — the jackknife standard error for a quantile does
  #' not improve as the sample grows; use [create_bootstrap_weights()]
  #' or, on a paired design, [create_brr_weights()]. When every stratum
  #' holds exactly two PSUs, prefer BRR.
  ```

  Claims: L7, L10, L11. VDK 2018 is in this function's `@references`
  (verified).

- [ ] **3d. `create_brr_weights()`** — insert a `@details` block between
  `@returns` and `@section Algorithm:` (before `R/create_brr_weights.R:26`):

  ```r
  #' @details
  #' **When to use.** Choose BRR when the design holds exactly two PSUs
  #' in every stratum, and especially when you estimate a quantile or
  #' another nonlinear statistic — BRR is proven for those, and no
  #' jackknife variant is (Valliant, Dever & Kreuter 2018, Section 15.4).
  #' Set `rho > 0` when you estimate a ratio: with the default
  #' `rho = 0`, one PSU per stratum drops to zero weight in each
  #' replicate, which can leave a ratio undefined (Dippo, Fay &
  #' Morganstein 1984).
  ```

  Claims: L12, L13. **Requires item 3h** — VDK 2018 is not yet in this
  function's `@references`.

- [ ] **3e. `create_gen_boot_weights()`** — two edits.

  Insert a `@details` block between `@returns` and `@section Algorithm:`
  (before `R/create_gen_boot_weights.R:35`):

  ```r
  #' @details
  #' **When to use.** Choose the generalized bootstrap when the design
  #' fits none of the named methods — Poisson sampling, or an unusual
  #' multi-stage structure — or when you must name the target variance
  #' estimator yourself (Beaumont & Patak 2012). The choice of
  #' `variance_estimator` is the central decision; see the **Choosing a
  #' target** section. Beaumont & Patak recommend at least 750
  #' replicates; the default is 500.
  ```

  Insert after the `@section Algorithm:` block:

  ```r
  #' @section Choosing a target:
  #' `variance_estimator` names the variance formula the replicate
  #' weights are built to reproduce. The mapped sources cover five of
  #' the options:
  #'
  #' - `"SD1"` (the default) and `"SD2"`: the successive-difference
  #'   estimators, which read the row order of the data (Ash 2014).
  #'   They suit systematic samples.
  #' - `"Horvitz-Thompson"`: valid for any design with computable
  #'   inclusion probabilities, but for some designs its form implies a
  #'   negative variance and the construction fails (Beaumont & Patak
  #'   2012).
  #' - `"Yates-Grundy"`: requires a fixed sample size; not appropriate
  #'   for Poisson sampling (Beaumont & Patak 2012).
  #' - `"Poisson Horvitz-Thompson"`: the valid choice under Poisson
  #'   sampling (Beaumont & Patak 2012).
  #'
  #' The remaining options (`"Stratified Multistage SRS"`,
  #' `"Ultimate Cluster"`, `"Deville-1"`, `"Deville-2"`,
  #' `"Deville-Tille"`, `"BOSB"`, `"Beaumont-Emond"`) come from the
  #' svrep back end; see [svrep::as_gen_boot_design()] for their
  #' definitions.
  ```

  Claims: L14–L19. **Requires item 3i** — Ash 2014 is not yet in this
  function's `@references`.

- [ ] **3f. `create_gen_rep_weights()`** — insert a `@details` block
  between `@returns` and `@section Algorithm:` (before
  `R/create_gen_rep_weights.R:38`):

  ```r
  #' @details
  #' **When to use.** Choose generalized replication when you want the
  #' deterministic counterpart of the generalized bootstrap: it is built
  #' from the same target variance estimators, but decomposes the target
  #' matrix into fixed components instead of drawing random multipliers
  #' (Fay 1989). There is no `replicates` argument — the construction
  #' sets the count, and `max_replicates` caps it. For choosing
  #' `variance_estimator`, see the **Choosing a target** section of
  #' [create_gen_boot_weights()]; note the defaults differ (`"SD2"`
  #' here, `"SD1"` there).
  ```

  Claims: L20. Fay (1989) is in this function's `@references`
  (verified).

- [ ] **3g. `create_sdr_weights()`** — insert a `@details` block between
  `@returns` and `@section Algorithm:` (before `R/create_sdr_weights.R:28`):

  ```r
  #' @details
  #' **When to use.** Choose successive difference replication only when
  #' the sample was drawn systematically from a sorted list and the rows
  #' still carry that order (Ash 2014). The row order is part of the
  #' method: re-sorted rows give a different and incorrect answer, and
  #' no error is raised. Pass `sort_var` to pin the order.
  ```

  Claims: L21. Ash (2014) is in this function's `@references`
  (verified).

- [ ] **3h. `@references` addition — `create_brr_weights()`.** Add, in
  the verified form from CRM's Citations section:

  ```
  Valliant, R., Dever, J. and Kreuter, F. (2018). *Practical Tools for
  Designing and Weighting Survey Samples*, 2nd edition. New York:
  Springer.
  ```

  Add the matching row under `create_brr_weights` in
  `.claude/reference-map.yaml`, pointing at
  `valliant_dever_kreuter_2018_ch15_variance_estimation.md` (the same
  file the `create_jackknife_weights` entry uses).

- [ ] **3i. `@references` addition — `create_gen_boot_weights()`.** Add:

  ```
  Ash, S. (2014). Using successive difference replication for estimating
  variances. *Survey Methodology*, 40(1), 47--59.
  ```

  Add the matching row under `create_gen_boot_weights` in
  `.claude/reference-map.yaml`, pointing at
  `ash_2014_successive_difference_replication.md` (the same file the
  `create_sdr_weights` entry uses).

**Acceptance (Task 3):** insertions match the text above; items 3h–3i
land before or with 3d and 3e so no inline citation is ever orphaned;
`create_replicate_weights.R` has no diff (3a is verify-only).

---

## Task 4 — Nonresponse family

**Files:** `R/adjust_nonresponse.R`, `R/redistribute_weights.R`.

No citations anywhere in this task (no comprehension doc for the family
— see Flagged claims). Every sentence below restates code behavior (L22).

- [ ] **4a. `adjust_nonresponse()` — `@param method` bullets.** Append
  one choice sentence to each bullet (`R/adjust_nonresponse.R:32-39`):

  - `"weighting-class"` bullet, append: "Choose it when you can name the
    groups whose response rates differ, and those groups are observed
    for respondents and nonrespondents alike."
  - `"propensity-cell"` bullet, append: "Choose it when no natural
    grouping exists: the model builds the cells from the data, and the
    cell-level factor smooths over individual fitted propensities."
  - `"propensity"` bullet, append: "Choose it when each unit's own
    fitted propensity should set its adjustment; individual factors can
    move further than cell-level ones, so watch the `max_adjust`
    warning."

- [ ] **4b. `adjust_nonresponse()` — `@details` opener.** Prepend to the
  existing `@details` (before `R/adjust_nonresponse.R:91`):

  ```r
  #' **When to use.** This function corrects for known nonrespondents
  #' inside your own sample; it needs a column that marks who responded.
  #' To move weight between rows defined by other conditions, use
  #' [redistribute_weights()]. To weight a sample that has no response
  #' indicator against a reference survey, use [ipw()].
  #'
  ```

  Also add `[ipw()]` to `@seealso` (currently
  `R/adjust_nonresponse.R:121` lists only `redistribute_weights()`).

- [ ] **4c. `redistribute_weights()`** — append one sentence to the
  existing `@details` (`R/redistribute_weights.R:54-58`): "Reach for
  `redistribute_weights()` when the rows losing weight are defined by a
  condition other than nonresponse — for example, removing ineligible
  cases while conserving the group totals."

**Acceptance (Task 4):** no inline citations; no `@references` changes;
`grep -c "Choose it when" R/adjust_nonresponse.R` returns 3.

---

## Task 5 — Document, check, ship

- [ ] Run `devtools::document()`. The diff under `man/` touches only the
  15 edited topics (5 calibration, 2 sample-calibration, 6 replicate
  creators, 2 nonresponse).
- [ ] Grep gates — all must return nothing:
  - `grep -rn "slowest" R/`
  - `grep -rni "fewer replicates than the jackknife" R/` (BRR economy claim)
  - `grep -rn "deterministic alternative" R/` (wrong lineage direction)
- [ ] Run `devtools::check()`: 0 errors, 0 warnings, notes unchanged
  from `develop`. No examples change in this plan, so example runtime is
  unaffected.
- [ ] Branch `docs/method-choice-guidance`, Conventional Commit
  `docs(docs): add when-to-use guidance across the three method families`,
  PR to `develop`.

---

## Handoffs to `plans/doc-getting-started.md`

This plan does not write the Getting Started article. Three inputs are
ready for it:

1. **Replicate family table:** CRM's "Method-choice table (feeds
   Section C)" — use it verbatim as the article's replicate section.
2. **Calibration family table:** build from Task 1's four "When to use"
   paragraphs plus the `calibrate()` `@details`; the CCF backs the
   claims. Do not resurrect Section C's draft rows dropped above.
3. **Nonresponse:** mechanical framing only until
   `comprehension-nonresponse-methods.md` exists.

---

## Found while planning (not this plan's scope)

- **`adjust_nonresponse()` `@param control` contradicts itself on
  `max_adjust`:** the defaults list says `max_adjust = 2.0`
  (`R/adjust_nonresponse.R:45`, matching the signature at line 144), but
  the bullet below says "(default 5.0)" (line 49). The bullet is wrong.
  Belongs on the Section H quick-win list in `plans/doc-improvements.md`.

---

## Adversarial review log (2026-08-31)

The draft was checked claim-by-claim against source before this file was
marked ready. Findings, all fixed inline:

1. **The brief's premise "the calibration-family claims have no
   comprehension doc yet" is wrong.** The archive holds
   `comprehension-calibration-framework.md` with a claim ledger citing
   Deville & Sarndal (1992) and Deville et al. (1993) section-by-section.
   The plan's calibration citations rest on it (L1–L6), so the
   calibration `@details` paragraphs may carry inline citations after
   all. Only the speed-ranking and normative-default claims stay
   flagged.
2. **Two inline citations would have been orphans.** VDK 2018 is absent
   from `create_brr_weights()` `@references`, and Ash 2014 from
   `create_gen_boot_weights()`. Items 3h–3i add them, with
   `reference-map.yaml` rows, before the citing text lands.
3. **CRM's "six of 12 options unsourced" undercounts for the roxygen's
   purpose.** `"Stratified Multistage SRS"` appears only in Bellhouse
   (1985) as an exact computation, never as a generalized-bootstrap
   target (CRM, "The `variance_estimator` choice"). The drafted section
   therefore lists seven options under the svrep pointer, not six (L19).
4. **Line anchors verified against current source:** `calibrate()`
   `@details` at `R/calibrate.R:85-117`; first `@section` tags at
   `calibrate_rake.R:107`, `calibrate_linear.R:116`,
   `calibrate_logit.R:121`, `poststratify.R:81`,
   `create_jackknife_weights.R:96`, `create_brr_weights.R:26`,
   `create_gen_boot_weights.R:35`, `create_gen_rep_weights.R:38`,
   `create_sdr_weights.R:28`; bootstrap `@details` at
   `create_bootstrap_weights.R:62-70`; `adjust_nonresponse` `@details`
   at `R/adjust_nonresponse.R:90-111` and `@seealso` at line 121;
   `redistribute_weights` `@details` at `R/redistribute_weights.R:54-58`.
5. **`redistribute_weights()` already documents its relationship to
   `adjust_nonresponse()`** (`@details`, lines 55-58), so Task 4c adds
   one sentence instead of a full "When to use" paragraph.
6. **Checked that `mse` prose now exists on all four thin creators**
   (e.g., `create_gen_boot_weights.R:27-29`), so this plan adds no `mse`
   content — CRM's warning 4 in "Parameter reference across the family"
   is stale on that point.
7. **Dispatcher default vs. sibling default:** the drafted gen-rep text
   says "the defaults differ (`"SD2"` here, `"SD1"` there)" — verified
   against `create_gen_rep_weights.R:77` and
   `create_gen_boot_weights.R:78`.
