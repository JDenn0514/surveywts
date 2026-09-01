# Getting Started article + glossary (Sections B + D)

**Created:** 2026-08-31.
**Status:** Ready for implementation — adversarially reviewed 2026-08-31
(see the review log at the bottom).
**Source:** `plans/doc-improvements.md` Sections B and D. The Plans to Write
table folds Section D into this file.
**Verified sources for claims:** `plans/comprehension-replicate-methods.md`
(CRM), `plans/archive/calibration-framework/comprehension-calibration-framework.md`
(CCF), and current package source. Every line anchor below was re-verified
against source on 2026-08-31.

**Audience** (from the top of `doc-improvements.md`): an R/tidyverse-fluent
analyst who is not a survey methodology expert. The article names the
condition the reader can check, not the theory behind it.

**Deliverable of the implementation sessions:** a pkgdown article at
`vignettes/articles/getting-started.Rmd`, one `.Rbuildignore` line, jargon
anchors and `@seealso` links in `R/`, `devtools::document()`,
`devtools::check()`, a verified pkgdown build, and two PRs to `develop`.
No code-path changes.

---

## Inputs consumed from the Section C plan

`plans/doc-method-choice-guidance.md` (merged as PR #98) handed three
inputs to this plan. This plan takes them as settled and does not re-derive
them:

1. **Replicate family table:** CRM's "Method-choice table (feeds Section C)"
   — the article uses it verbatim (Task 2, block 4b).
2. **Calibration family table:** built from the five "When to use"
   paragraphs now shipped in `R/calibrate*.R` and `R/poststratify.R`
   (PR #98), plus the `calibrate()` `@details`. CCF backs the claims. Do
   not resurrect the draft rows that Section C's review dropped.
3. **Nonresponse:** mechanical framing only, no citations, until
   `comprehension-nonresponse-methods.md` exists.

The Section C plan also fixed the placement question (`@details`, not
`@description`) and shipped the sibling-level "When to use" paragraphs.
The article links to those paragraphs; it does not duplicate them.

---

## Decisions

### D1. Surface: Option A, a pkgdown article

`vignettes/articles/getting-started.Rmd`, per Section B's standing
recommendation. A pkgdown article is not an installed vignette: it is
ignored by `R CMD check` and built only for the site. Consequences:

- `vignette("getting-started")` does not work at runtime. Every link to
  the article must be the absolute site URL:
  `https://jdenn0514.github.io/surveywts/articles/getting-started.html`.
  The URL is deterministic (site URL from `_pkgdown.yml:1` + `articles/` +
  file name), so the roxygen edits do not have to wait for a site deploy.
- The article's chunks do not count against `R CMD check` example time.
  They run on every pkgdown build, so total render time still matters —
  keep it under ~2 minutes (the QR bootstrap at 100 replicates ran ~65 s
  in the 2026-08-31 README verification).

### D2. Article structure and order

Five sections, in this order:

1. **Orientation** — three sentences: who the article is for, what it
   covers, where the README stops and this article starts.
2. **The class system** — the diagram, the "what will I get back" table,
   the crossover footnote. Placed first because every later section uses
   the class names.
3. **The two standard workflows** — probability, then non-probability.
   Runnable code with output.
4. **Choosing a method** — four short subsections with tables:
   calibration, replicate, nonresponse, sample-based calibration.
5. **Glossary** — the terms, each under its own sub-heading so the
   section is skimmable.

### D3. Workflow step order differs by path — the article must say so

No prior doc surface states this contrast, and one states the probability
half wrong: Section B's workflow sketch (`doc-improvements.md:199-200`)
puts calibration before replicate creation. Task 5d corrects that line
when it updates the parent doc. Both halves below are verified:

- **Probability path: create replicate weights first, calibrate second.**
  `calibrate()` on a `survey_replicate` applies the calibration to every
  replicate weight column (`R/calibrate.R:27-31`), which is the required
  per-replicate replay — "It is not enough to simply create replicate
  weights by adjusting the final full-sample weight alone" (CRM, jackknife
  gotcha 3, citing VDK 2018 §15.4.1). Calibrating first and creating
  replicates second perturbs the calibrated weights but drops the variance
  the calibration step contributes.
- **Non-probability path: replicate weights come last.** The
  quasi-randomization bootstrap and the grouped jackknife replay the whole
  weighting pipeline — the IPW fit and any calibration — inside every
  replicate (`R/replicate-utils.R:670-676` dispatch table for calibration
  replay; README `calibrate-to-survey` chunk comment, run-verified
  2026-08-31). So the analyst calibrates the full-sample weights first and
  creates replicates as the final weighting step.

### D4. Glossary: two entry depths, plus one-line anchors in function docs

Per Section D's recommendation (Option B): the glossary in the article is
the single source of truth; individual function docs get a one-line
plain-language anchor at first use.

- **Concept entries** (2–4 sentences each, 12 terms): replicate weights,
  PSU, Taylor linearization, FPC, design effect, g-weight, propensity
  score, weighting class, MAR, quasi-randomization bootstrap, doubly
  robust, Hadamard matrix. Hadamard matrix is added to Section D's 14: it
  appears undefined in the shipped `create_replicate_weights()` `@details`
  (`R/create_replicate_weights.R:54`) and in several Algorithm sections,
  and CRM defines it.
- **Acronym entries** (one line each — expansion plus a pointer to the
  home function, 3 terms): GREG, BRR, DAGJK. These are method names, not
  concepts; their real documentation is the home function's "When to use"
  paragraph.
- **No per-term deep links from roxygen.** The `@seealso` line (Task 4)
  points at the article once per help page. Per-term URL fragments in 23
  files would be noisy and fragile.

### D5. Scope boundary with Section A (`plans/doc-examples-overhaul.md`)

- **This plan owns:** the article, the `.Rbuildignore` line, the jargon
  anchor sentences (Task 3), and the `@seealso` article links (Task 4).
  These are prose edits to roxygen.
- **Section A owns:** every `@examples` block. This plan does not touch
  an `@examples` block, even where an example would illustrate a glossary
  term. Section A's plan should link workflow steps to this article
  instead of re-explaining them.

### D6. Citations in the article

The article carries parenthetical author-year citations only in the
"Choosing a method" section, and only where CRM or CCF verifies the claim
— the same texts already shipped in roxygen with those citations. A short
"Further reading" list at the end of the article gives the full forms,
copied from CRM's "Citations" section (the verified forms). The glossary
and workflow sections carry no citations; their content is mechanical or
definitional.

### D7. Two PRs

- **PR 1** (branch `docs/getting-started-article`): Tasks 1–2.
  `docs(docs): add the getting-started pkgdown article`.
- **PR 2** (branch `docs/getting-started-links`): Tasks 3–4, then Task 5's
  document/check. `docs(docs): link function docs to the getting-started
  article`.

PR 1 lands first. PR 2's URL is deterministic either way (D1), but
separating them keeps the 23-file roxygen diff reviewable on its own.

---

## Verified claim ledger

Claims the article asserts, with the source verified 2026-08-31. "Mechanical"
means the claim restates code behavior and needs no citation.

| # | Claim | Source |
|---|---|---|
| G1 | 23 exported functions; every one has `@seealso` | `NAMESPACE:3-25`; grep of `R/` |
| G2 | Probability creators return a `survey_replicate` with `rep_*` columns | Mechanical — `R/replicate-utils.R:156-163` |
| G3 | The nonprob bootstrap adds `repwt_*` columns and repoints `@variables$repweights` in place; the class stays `survey_nonprob` | Mechanical — `R/replicate-utils.R:639-646` |
| G4 | The grouped jackknife does the same in place | Mechanical — `R/create_jackknife_weights.R:755-759` |
| G5 | Crossover: `create_bootstrap_weights()` on a probability `type` silently wraps a `survey_nonprob` as an SRS design and returns a `survey_replicate` | Mechanical — `R/replicate-utils.R:137-149` |
| G6 | `as_taylor_design()` refuses that crossover object | Mechanical — `R/as_taylor_design.R:108-123` |
| G7 | Four creators reject a `survey_nonprob` outright: brr (`R/create_brr_weights.R:85-93`), gen-boot (`R/create_gen_boot_weights.R:121`), gen-rep (`R/create_gen_rep_weights.R:97`), sdr (`R/create_sdr_weights.R:74`). The jackknife rejects it for `"jk1"`/`"jkn"` (`R/create_jackknife_weights.R:323-345`) and accepts it only on the `type = "grouped"` (DAGJK) path | Mechanical — corrected 2026-08-31 in adversarial review; `doc-improvements.md:191-192` says "five" and is wrong |
| G8 | `calibrate()` on a `survey_replicate` recalibrates every replicate column | Mechanical — `R/calibrate.R:27-31` |
| G9 | Replaying adjustments per replicate is required, not optional | CRM jackknife gotcha 3 (VDK 2018 §15.4.1) |
| G10 | QR bootstrap and DAGJK replay IPW and calibration inside every replicate | Mechanical — `R/replicate-utils.R:463-487` (per-replicate IPW refit and calibration replay) and `:670-676` (replay dispatch table); `R/create_bootstrap_weights.R:90-94` (IPW refit); `R/create_jackknife_weights.R:151` (DAGJK) |
| G11 | `ipw()` takes a plain `data.frame` plus a reference design and returns a `survey_nonprob` | Mechanical — `R/ipw.R:171-175, 242-246` |
| G12 | `as_taylor_design()` warns on every successful conversion (variance loss) | Mechanical — Section H item, done 2026-08-31 |
| G13 | Replicate weights exist to compute standard errors | CRM, Purpose and Method 1 mechanism |
| G14 | PSU: the first thing the design selects — a county, a school, a block | CRM, Problem section |
| G15 | Hadamard matrix: ±1 grid; any two rows agree in exactly half their positions | CRM, Problem section |
| G16 | g-weight: the ratio of calibrated to starting weight, `g_k = w_k / d_k` | Mechanical — `R/calibrate_logit.R:76`; CCF |
| G17 | Design effect: variance inflation vs. an SRS of the same size | `weight_variability()` `@references` (Kish 1965, added 2026-08-31) |
| G18 | `surveycore::get_means()` exists and is the estimation step | `getNamespaceExports("surveycore")`, checked 2026-08-31; exact call signature must be run-verified in Task 2 |
| G19 | Method-choice table content, replicate family | CRM, "Method-choice table (feeds Section C)" — verbatim |
| G20 | Method-choice content, calibration + sample-calibration + nonresponse | Shipped roxygen from PR #98 (`R/calibrate*.R`, `R/poststratify.R`, `R/create_*_weights.R`, `R/adjust_nonresponse.R`, `R/redistribute_weights.R`) |

## Must-not-assert list

Copied forward from the Section C plan; still binding. The article must not
state:

- Any speed ranking of rake vs. logit, or "slowest for many margins."
- Choice guidance among the five probability bootstrap schemes in
  `create_bootstrap_weights()` — point at `svrep::as_bootstrap_design()`.
- Cited nonresponse method-choice heuristics. Mechanical wording only.
- Replicate-count economy for BRR.
- Normative "default choice" language beyond the mechanical fact that a
  value is the package default.
- Ash (2014) §4's "SD1 usually has larger biases" sentence — a wording
  error in the source (CRM, Cross-paper conflicts). Do not propagate it.

---

## Task 1 — Infrastructure

**Files:** `vignettes/articles/` (new), `.Rbuildignore`.

Current state, verified 2026-08-31: no `vignettes/` directory exists.
`DESCRIPTION` already has `knitr` and `rmarkdown` in Suggests and
`VignetteBuilder: knitr` — no DESCRIPTION change is needed. `_pkgdown.yml`
has no `articles:` or `navbar:` block; pkgdown adds the Articles menu on
its own when an article exists, so no `_pkgdown.yml` change is needed
either. A pkgdown CI workflow exists (`.github/workflows/pkgdown.yaml`).

- [ ] **1a.** Create `vignettes/articles/getting-started.Rmd` (Task 2
  writes the content). Do not create any file directly under `vignettes/`
  — the vignette suite belongs to the Polish release, and this plan sets
  up only what the article needs.
- [ ] **1b.** Add one line to `.Rbuildignore`:

  ```
  ^vignettes/articles$
  ```

  This keeps the article out of the built package, so `R CMD check` never
  sees it. Do not ignore `^vignettes$` — future vignettes must stay in
  the build.
- [ ] **1c.** After Task 2, run `pkgdown::build_site()` locally (or at
  minimum `pkgdown::build_articles()`). The article must render with no
  errors, and the Articles menu must appear in the navbar.

**Acceptance (Task 1):** `R CMD build` output contains no `vignettes/`
entry; the local pkgdown build renders the article; `devtools::check()`
results are unchanged from `develop`.

---

## Task 2 — The article

**File:** `vignettes/articles/getting-started.Rmd`.

Front matter: `title: "Getting started with surveywts"`, standard pkgdown
article header, a setup chunk with `library(surveywts)` and a fixed seed.
All chunks run on package data (same rule as `@examples`). Every chunk
must be run-verified before the PR opens.

The blocks below give the load-bearing content verbatim (diagram, tables,
glossary, anchor facts). Connecting prose is written at implementation,
inside the constraints of the claim ledger and the must-not-assert list.

### Block 2a — Orientation

Three sentences, no more: the article is for an R-fluent analyst who is
not a survey methodologist; it explains the objects, the two standard
workflows, how to choose among sibling methods, and the recurring terms;
the README shows the calls, this article explains what comes back and
why.

### Block 2b — The class system

Show (do not merely link):

1. The verified diagram, as a fenced text block:

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

2. A three-row table naming the classes in plain language:
   - `survey_taylor` — a probability design that computes variance by
     Taylor linearization (see the glossary).
   - `survey_replicate` — a probability design that carries replicate
     weight columns (`rep_1`, `rep_2`, ...) and computes variance from
     their spread (G2).
   - `survey_nonprob` — a non-probability sample with estimated weights.
     Replicate methods add `repwt_*` columns in place; the class never
     changes (G3, G4).

3. One paragraph on what each function family returns, pointing at the
   diagram: weighting functions preserve the input class; only the
   probability-path replicate creators change it (`survey_taylor` →
   `survey_replicate`); `as_taylor_design()` converts back and always
   warns that the replicate-specific variance detail is lost (G12).

4. **The crossover, as a footnote — not drawn in the diagram.**
   `create_bootstrap_weights()` with a probability-style `type` (the
   default included) accepts a `survey_nonprob`, silently wraps it as a
   simple-random-sample design, and returns a `survey_replicate` whose
   replicates ignore the propensity-estimation step (G5). The result
   cannot be converted by `as_taylor_design()` (G6). The footnote sends
   non-probability users to `type = "quasi-randomization"`. Of the other
   creators, brr, gen-boot, gen-rep, and sdr reject a `survey_nonprob`
   outright; the jackknife rejects it for `"jk1"`/`"jkn"` and accepts it
   only on the explicit `type = "grouped"` (DAGJK) path the diagram
   already shows (G7). This matches
   the `@details` paragraph shipped on `create_bootstrap_weights()`
   (Section H, 2026-08-31) — link to it rather than restating the full
   mechanics.

### Block 2c — The two standard workflows

Each workflow is a runnable chunk with output shown, plus one short
paragraph per step saying why the step exists. Both end with an
estimation call and a diagnostic, because "run estimation" is the payoff
the function docs never show (Section A's finding).

**Workflow 1 — probability sample.** Skeleton (column names and
constructor verified against `R/data.R:23-26`; the exact
`surveycore::get_means()` signature must be verified against surveycore's
docs when the chunk is run — G18):

```r
# 1. Construct the design from the raw tibble
gss <- surveycore::as_survey(
  gss_2024, weights = wtssps, strata = vstrat, ids = vpsu, nest = TRUE
)

# 2. Create replicate weights BEFORE calibrating (see prose on order).
#    Real analyses use more replicates; 100 keeps the article fast.
gss_rep <- create_replicate_weights(
  gss, method = "bootstrap", replicates = 100L, seed = 1
)

# 3. Calibrate to population margins — every replicate column is
#    recalibrated to the same targets
targets <- list(
  sex = c("Male" = 0.49, "Female" = 0.51),
  age_f3 = c("18-34" = 0.28, "35-54" = 0.37, "55+" = 0.35)
)
gss_cal <- calibrate(gss_rep, targets = targets)

# 4. Inspect the weights
summarize_weights(gss_cal)

# 5. Estimate
surveycore::get_means(gss_cal, pid_f3)
```

Contingency: `gss_2024` carries `NA` in `sex` and `age`
(`R/data.R:13-14`). If `calibrate()` errors on the `NA` rows, filter them
first with a one-line comment, or switch the chunk to `npors_2025_clean`.
Decide by running the chunk, not by guessing.

The step-order prose states D3's probability half: replicate weights
first, calibration second, with the plain-language reason (each replicate
column gets its own calibration, so the calibration step's variance
survives — G8, G9). Cite VDK 2018 per D6.

**Workflow 2 — non-probability sample.** Mirrors the run-verified README
pipeline (README.Rmd:117-199), with one deliberate departure: the
reference construction adds `strata = stratum`, which the `npors_2025_clean`
dataset docs require ("Always include `strata = stratum`",
`R/data.R:110-111`) and the README omits (see Found while planning):

```r
# 1. Start from a plain tibble; drop rows with NA in the benchmark variable
ns_complete <- ns_wave1[!is.na(ns_wave1$pid_f3), ]

# 2. Estimate inverse probability weights against a probability reference
npors_ref <- surveycore::as_survey(
  npors_2025_clean, weights = wt_pop, strata = stratum
)
nps_wts <- ipw(
  ns_complete,
  npors_ref,
  predictors = c("sex", "age_f3", "race_f4", "edu_f3"),
  missing_method = "omit",
  estimating_eq = "mle"
)

# 3. Calibrate the IPW weights to census margins (doubly robust)
nps_cal <- calibrate(nps_wts, targets = targets)

# 4. Create replicate weights LAST — each replicate refits the IPW model
#    and replays the calibration
nps_rep <- create_bootstrap_weights(
  nps_cal,
  type = "quasi-randomization",
  replicates = 100L,
  seed = 1
)

# 5. Inspect and estimate
summarize_weights(nps_rep)
surveycore::get_means(nps_rep, pid_f3)
```

The step-order prose states D3's non-probability half: replicates come
last because the quasi-randomization bootstrap replays the whole pipeline
inside every replicate (G10). One sentence contrasts the two workflows'
orders explicitly — this is the article's central practical lesson.

Chunk time budget: the QR bootstrap at 100 replicates ran ~65 s on
2026-08-31. If the rendered article exceeds ~2 minutes total, cut
`replicates` in the chunk (not below 50) and say in a comment that real
analyses use more.

### Block 2d — Choosing a method

Four subsections. Each shows a table and links to the per-function
"When to use" paragraphs shipped in PR #98 for depth. No new claims —
every cell traces to G19 or G20.

1. **Calibration** (`calibrate()`, `calibrate_rake()`,
   `calibrate_linear()`, `calibrate_logit()`, `poststratify()`). Build a
   four-row table from the shipped "When to use" texts: rake — separate
   margins, weights stay positive, unbounded above, use `cap` or
   `trim_weights()`; linear — one exact step with `bounds = NULL`, can go
   negative on large gaps; logit — bounds the g-weight ratio in `(L, U)`,
   too-tight bounds fail to converge; poststratify — full joint cells,
   every cell must contain sample members. Cite Deville & Sarndal (1992)
   and Deville, Sarndal & Sautory (1993) as the shipped texts do.
2. **Replicate weights.** CRM's method-choice table, verbatim (G19). It
   is written for exactly this audience. Keep its "Choose it when / Do
   not choose it when" columns unchanged.
3. **Nonresponse** (`adjust_nonresponse()`, `redistribute_weights()`).
   Mechanical framing only, from the shipped `@param method` bullets and
   `@details` openers: weighting-class when you can name the groups;
   propensity-cell when no natural grouping exists; propensity when each
   unit's own fitted propensity should set its adjustment;
   `redistribute_weights()` when the rows losing weight are defined by a
   condition other than nonresponse. No citations.
4. **Calibrating to a survey vs. to estimates** (`calibrate()`,
   `calibrate_to_survey()`, `calibrate_to_estimate()`). Three rows from
   the shipped Task 2 texts: fixed census targets → `calibrate()`;
   targets from another survey with its data in hand →
   `calibrate_to_survey()`; published estimates plus a variance-covariance
   matrix → `calibrate_to_estimate()`. No citations (mechanical).

### Block 2e — Glossary

Every entry gets its own `### Term` sub-heading. Concept entries first,
alphabetical; the three acronym entries last under a "Method names" note.
Drafted verbatim — the implementation may smooth transitions but must not
change a definition's substance without re-verifying it:

- **Design effect (DEFF).** How much the sampling design and the weights
  inflate the variance of an estimate, compared with a simple random
  sample of the same size. A design effect of 2 means the sample carries
  the information of an unweighted sample half its size.
  `weight_variability()` reports the weight CV, the quantity that drives
  the weighting component of the design effect (Kish 1965).
- **Doubly robust.** An estimation strategy that combines two models — a
  selection model (such as the IPW propensity model) and an outcome model
  (such as calibration to population margins). The estimate stays
  consistent when either model is right, so a mistake in one of the two
  is survivable. In this package: `ipw()` followed by `calibrate()`.
- **FPC (finite population correction).** A factor that shrinks a
  variance estimate when the sample is a large share of the population.
  With a 5% sampling fraction it barely matters; with 50% it halves the
  variance. Carried in the design object; not something the weighting
  functions change.
- **G-weight.** The ratio of the calibrated weight to the starting
  weight, `g = w_calibrated / w_start`. On the default multiplicative
  scale, calibration `bounds` constrain this ratio rather than the weight
  itself: `bounds = c(0.5, 2)` means no weight moves to less than half or
  more than double its starting value. (`bounds_scale = "absolute"`
  switches to bounding the weight directly.)
- **Hadamard matrix.** A square grid of +1 and -1 values arranged so that
  any two rows agree in exactly half their positions. BRR, generalized
  replication, and successive difference replication use one to keep the
  replicates balanced — so that every unit is up-weighted and
  down-weighted in a controlled pattern across replicates.
- **MAR (missing at random).** The assumption that whether a unit
  responds depends only on things you observed (age, region, mode), not
  on the unobserved answer itself. Every nonresponse adjustment in this
  package leans on it, and no function can test it for you.
- **Propensity score.** The modeled probability that a unit responds (in
  nonresponse adjustment) or appears in the sample (in non-probability
  weighting). Weighting by its inverse gives units from underrepresented
  groups more weight.
- **PSU (primary sampling unit).** The first thing the design selects —
  often a county, a school, or a city block, not a person. Replicate
  methods drop or reweight whole PSUs, not individual respondents,
  because the PSU is the unit the randomness lives in.
- **Quasi-randomization bootstrap.** The bootstrap for a non-probability
  sample with a probability reference sample. Each replicate resamples
  the non-probability sample and refits the weighting model, so the
  model's own estimation error enters the variance; the reference sample
  is also resampled when the calibration targets were estimated from it.
  See `create_bootstrap_weights(type = "quasi-randomization")`.
  (Evidence for the conditional resampling: `R/replicate-utils.R:377-378,
  449-460` — the reference is redrawn under Level B only. Not article
  text.)
- **Replicate weights.** Sets of perturbed copies of the main weight,
  stored as extra columns. You compute your estimate once per column;
  the spread of those estimates gives the standard error. They exist so
  that variance estimation survives complex designs and multi-step
  weighting.
- **Taylor linearization.** The closed-form alternative to replication:
  approximate a nonlinear statistic by a linear one, then apply the
  design's exact variance formula. Fast and standard for totals, means,
  and ratios; it is what a `survey_taylor` object uses.
- **Weighting class.** A group of units assumed to share the same
  response rate. `adjust_nonresponse(method = "weighting-class")` moves
  the weight of nonrespondents to respondents inside each class.

Method names:

- **BRR** — balanced repeated replication; needs exactly two PSUs per
  stratum. See `create_brr_weights()`.
- **DAGJK** — delete-a-group jackknife; the grouped jackknife for
  non-probability samples. See `create_jackknife_weights(type = "grouped")`.
- **GREG** — generalized regression estimator; the survey name for
  linear calibration. See `calibrate_linear()`.

- [ ] **2f. Term-list sweep.** Before finalizing the glossary, grep the
  current roxygen for each of the 15 terms above plus any recurring
  undefined term the sweep surfaces. Section D's "Defined? No" column is
  from the 2026-06 audit and is already partially stale: `ipw()` now
  defines doubly robust in its `@details` (`R/ipw.R:308-311`), and PR #98
  added plain-language method framing across three families. The sweep
  confirms each glossary entry still earns its place; drop an entry only
  if the term no longer appears in any user-facing doc.

### Block 2g — Further reading

A short list of the works the method-choice section cites, in the
verified forms from CRM's "Citations" section and the calibration
references already shipped in `R/calibrate.R`. Do not cite Chrostowski
(year and venue still unconfirmed — CRM) or Wolter (not in the knowledge
base).

**Acceptance (Task 2):**

- The article renders with `pkgdown::build_articles()` with no errors or
  warnings.
- Both workflow chunks run and show output; total render stays under
  ~2 minutes.
- The diagram block matches Block 2b character for character.
- The replicate method-choice table matches CRM's table cell for cell.
- Grep gates on the article source — all must return nothing:
  - `grep -in "slowest" vignettes/articles/getting-started.Rmd`
  - `grep -in "fewer replicates than the jackknife" vignettes/articles/getting-started.Rmd`
  - `grep -in "deterministic alternative" vignettes/articles/getting-started.Rmd`
  - `grep -in "SD1 usually has larger" vignettes/articles/getting-started.Rmd`
- Every glossary definition matches Block 2e in substance.
- No error or warning class names appear in the article.

---

## Task 3 — Jargon anchors in function docs

**Files:** the `R/` files listed in the placement table below.

The anchor is a one-line parenthetical gloss at the term's first use in a
help page's `@title`, `@description`, or the top of `@details` — the
reader's first contact. Rules:

- One anchor per term per help page, at the first user-facing use.
- Do not anchor inside `@examples` (Section A's territory) or inside
  `@section Algorithm:` blocks (a reader there has already met the term).
- Do not anchor a term inside the same sentence that PR #98's "When to
  use" text already explains it.
- The anchor text is fixed per term (verbatim below). Grammar may flex
  (singular/plural), the gloss may not.

Anchor texts:

| Term | Anchor (verbatim gloss) |
|---|---|
| replicate weights | `replicate weights (sets of perturbed weight columns used to compute standard errors)` |
| PSU | `PSUs (primary sampling units: the first units the design selects, such as counties or schools)` |
| FPC | `finite population correction (a factor that shrinks the variance when the sample is a large share of the population)` |
| Taylor linearization | `Taylor linearization (closed-form variance from a linear approximation, the alternative to replication)` |
| design effect | `design effect (variance inflation relative to a simple random sample of the same size)` |
| g-weight | `g-weights (the ratio of calibrated to starting weight)` |
| propensity score | `propensity score (the modeled probability of responding or of appearing in the sample)` |
| weighting class | `weighting classes (groups assumed to share one response rate)` |
| GREG | `GREG (generalized regression, the survey name for linear calibration)` |
| BRR | `BRR (balanced repeated replication)` |
| DAGJK | `DAGJK (delete-a-group jackknife)` |
| MAR | `missing at random (response depends only on observed variables)` |
| quasi-randomization bootstrap | `quasi-randomization bootstrap (each replicate refits the weighting model)` |
| doubly robust | `doubly robust (consistent when either the selection model or the outcome model is right)` |
| Hadamard matrix | `Hadamard matrix (a +1/-1 grid that keeps replicates balanced)` |

Placement, starting from Section D's first-appears column — the
implementation session finalizes it by grepping each term across `R/`
(the 2026-06 audit predates PR #97/#98, which moved first-use points):

- [ ] **3a.** replicate weights → the 8 replicate-family pages, plus
  `calibrate_to_survey()` and `calibrate_to_estimate()` (both require
  replicate designs).
- [ ] **3b.** PSU → `create_brr_weights()`, `create_jackknife_weights()`,
  `create_replicate_weights()`.
- [ ] **3c.** FPC and Taylor linearization → `as_taylor_design()`.
  Exception to the first-use rule: "Taylor linearization" appears in that
  file only inside an error message (`R/as_taylor_design.R:118`), never in
  the roxygen prose — the title says "Taylor design." Here the anchor is a
  new sentence at the top of `@details` that introduces the term with its
  gloss; it does not rename the title (title changes are out of scope).
- [ ] **3d.** design effect → `weight_variability()`.
- [ ] **3e.** g-weight → `calibrate_linear()`, `calibrate_logit()`,
  `calibrate()`.
- [ ] **3f.** propensity score and MAR → `adjust_nonresponse()`, `ipw()`.
- [ ] **3g.** weighting class → `adjust_nonresponse()`.
- [ ] **3h.** GREG → `calibrate_linear()`. BRR → `create_brr_weights()`,
  `create_replicate_weights()`. DAGJK → `create_jackknife_weights()`,
  `create_replicate_weights()`.
- [ ] **3i.** quasi-randomization bootstrap →
  `create_bootstrap_weights()`. doubly robust → `ipw()` (skip if the
  existing `R/ipw.R:308-311` definition already covers first use).
  Hadamard matrix → `create_replicate_weights()` only
  (`R/create_replicate_weights.R:54`, inside `@details`). On
  `create_brr_weights()`, `create_gen_rep_weights()`, and
  `create_sdr_weights()` the term lives only in `@section Algorithm:` or
  `@param` blocks, which the anchor rules leave untouched — the glossary
  covers those readers.

**Acceptance (Task 3):** each checklist item names the pages it touched
and the tag the anchor landed in; no `@examples` or
`@section Algorithm:` block changed; every anchor gloss matches the table
verbatim; a term is glossed at most once per help page.

---

## Task 4 — `@seealso` links to the article

**Files:** all 23 exported functions' `R/` files (G1 — every one already
has a `@seealso` tag; verified 2026-08-31). Dataset docs are excluded.

- [ ] **4a.** Append this text to each function's existing `@seealso`
  block, as its final sentence (verbatim; wrap to the file's line width):

  ```r
  #'   For the class system, the standard workflows, and a glossary of
  #'   terms, see the [Getting started
  #'   article](https://jdenn0514.github.io/surveywts/articles/getting-started.html).
  ```

- [ ] **4b.** Where a `@seealso` is a bare comma-separated link list (most
  files), end the list with a period before the new sentence, or place
  the sentence on its own lines after the list — match each file's
  existing layout. Where `@seealso` already carries prose
  (`R/ipw.R:475-482`, `R/create_jackknife_weights.R:253-257`), append
  after the existing prose.

**Acceptance (Task 4):**
`grep -rc "articles/getting-started.html" R/ --include="*.R"` totals 23
matches across the function files (not `data.R`); every match sits inside
a `@seealso` block; `devtools::document()` regenerates 23 `.Rd` files and
nothing else.

---

## Task 5 — Document, check, ship

- [ ] **5a.** PR 1 (Tasks 1–2): branch `docs/getting-started-article`,
  commit `docs(docs): add the getting-started pkgdown article`, PR to
  `develop`. `devtools::check()` must be clean and unchanged from
  `develop` — the article is build-ignored, so any check diff means
  Task 1b failed.
- [ ] **5b.** After PR 1 merges and the pkgdown deploy runs, confirm the
  article URL resolves:
  `https://jdenn0514.github.io/surveywts/articles/getting-started.html`.
- [ ] **5c.** PR 2 (Tasks 3–4): branch `docs/getting-started-links`.
  Run `devtools::document()`; the `man/` diff covers exactly the touched
  topics. Run `devtools::check()`: 0 errors, 0 warnings, notes unchanged
  from `develop`. No `@examples` block changes in the diff. Commit
  `docs(docs): link function docs to the getting-started article`, PR to
  `develop`.
- [ ] **5d.** Update `plans/doc-improvements.md`: mark Sections B and D
  as plan-written (this file), and after the PRs merge, mark them done.
  Update the Plans to Write table row for this file. Also correct two
  errors in that file, inline (per the plan-files rule: rewrite in
  place): the Section B claim that "the other five creators reject a
  `survey_nonprob` at the door" (lines 191-192 — four do; the jackknife
  accepts `type = "grouped"`), and the probability workflow sketch
  (lines 199-200 — replicate weights come before calibration, per D3).

---

## Found while planning (not this plan's scope)

- **README function table names a function that does not exist.**
  `README.Rmd:88` (and the rendered `README.md`) lists
  `create_group_jackknife_weights()` in the Replicate weights table. The
  function was merged into `create_jackknife_weights(type = "grouped")`
  in `986b8bc`. The row must be deleted or folded into the
  `create_jackknife_weights()` row. The `README.Rmd:83` jackknife row's
  "(JK1, JKn, random groups)" should also read "(JK1, JKn, grouped)" —
  the accepted `type` values are `"jk1"`, `"jkn"`, `"grouped"`. The
  2026-08-31 README re-render fixed the chunks, not this static table.
  Belongs on the Section H quick-win list in `plans/doc-improvements.md`.
- **README reference construction omits `strata`.** `README.Rmd:121`
  builds the NPORS reference with
  `surveycore::as_survey(npors_2025_clean, weights = wt_pop)`, while the
  dataset docs say "Always include `strata = stratum`"
  (`R/data.R:110-111`, `:251-253`). The article uses the documented form
  (Task 2c); the README fix belongs on the Section H quick-win list.

---

## Adversarial review log (2026-08-31)

A fresh-context reviewer checked the draft claim-by-claim against source.
Findings, all fixed inline:

1. **G7 was false as written — the blocking find.** The draft said "the
   other five creators reject a `survey_nonprob` at the door," inherited
   from `doc-improvements.md:191-192`. Four do (brr, gen-boot, gen-rep,
   sdr); the jackknife rejects only `"jk1"`/`"jkn"` and accepts
   `type = "grouped"` — the DAGJK path the diagram itself draws. The
   ledger row, the Block 2b footnote, and Task 5d (which now corrects the
   parent doc) were all fixed.
2. **D3 claimed no prior doc states a step order.** One does, wrongly:
   `doc-improvements.md:199-200` puts calibration before replicate
   creation on the probability path. D3 now names the contradiction, and
   Task 5d corrects it. D3's advice itself was verified clean —
   `R/calibrate.R:27-31`, CRM gotcha 3, `R/replicate-utils.R:463-487`,
   `R/create_jackknife_weights.R:151`.
3. **The design-effect glossary entry overstated `weight_variability()`**,
   which returns only the weight CV (`R/weight_variability.R:47`), not a
   design-effect component. Reworded.
4. **The quasi-randomization glossary entry said both samples are
   resampled every replicate.** The reference is resampled only under
   Level B — when the calibration targets were estimated from it
   (`R/replicate-utils.R:377-378, 449-460`). Reworded conditionally.
5. **Task 3i's Hadamard anchors named three pages where the term lives
   only in `@section Algorithm:` or `@param` blocks**, which the anchor
   rules forbid touching. Narrowed to `create_replicate_weights()`.
6. **The g-weight entry's blanket "bounds constrain the ratio" is wrong
   for `bounds_scale = "absolute"`** (`R/calibrate_logit.R:75-78`).
   Scoped to the default multiplicative scale.
7. **G10's anchors half-covered the claim** — the bootstrap Algorithm
   section describes the IPW refit only, and the DAGJK half cited
   nothing. Anchors extended.
8. **"Taylor linearization" has no roxygen first use in
   `as_taylor_design()`** (only an error message at `:118`). Task 3c now
   carries an explicit introduce-the-term exception.
9. **Workflow 1 left `replicates` at the 500 default**, unexamined
   against the render budget. Now explicit at 100L with a comment.
10. **Workflow 2's reference construction omitted `strata = stratum`**,
    against the dataset docs. Fixed in the skeleton; the same omission in
    `README.Rmd:121` moved to Found while planning.
11. **Wording:** the Task 2 grep gates said "rendered `.Rmd`"; the `.Rmd`
    is the source. Fixed.

Verified clean by the same review: ledger anchors G1–G6, G8, G9, G11–G16,
G18, G19; both workflow skeletons' signatures, argument names, and dataset
columns; Section B/D fidelity (all four content blocks, all 14 original
terms plus Hadamard, crossover kept as a footnote, diagram
character-for-character); every Task 1 infrastructure claim, including
that `^vignettes/articles$` is the exact pattern `usethis::use_article()`
writes and that pkgdown adds the Articles menu without config; Task 4's
23-function count and grep coherence; the must-not-assert gates (no false
positives against CRM's verbatim table); and the Found-while-planning
README items.
