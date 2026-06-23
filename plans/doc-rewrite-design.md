# Design: surveywts Documentation Rewrite

**Date:** 2026-06-18
**Status:** Approved — updated after grilling sessions 2026-06-18 and 2026-06-19
**Standard:** `.claude/rules/function-documentation.md`

---

## Scope

22 exported functions across 7 families. `create_jackknife_weights` and
`create_group_jackknife_weights` are excluded from edits but remain valid
link targets in `@seealso` blocks. `calibrate_to_survey` was originally
excluded as "already cleaned up" but is now back in scope for a full audit
after grilling revealed the examples are not up to standard.

| Family | Functions |
|---|---|
| Calibration | `calibrate`, `calibrate_rake`, `calibrate_linear`, `calibrate_logit`, `poststratify` |
| Sample calibration | `calibrate_to_estimate`, `calibrate_to_survey` |
| Nonresponse | `adjust_nonresponse`, `redistribute_weights` |
| Diagnostics | `effective_sample_size`, `weight_variability`, `summarize_weights` |
| Utilities | `trim_weights`, `stabilize_weights` |
| Replicate weights | `create_bootstrap_weights`, `create_brr_weights`, `create_gen_boot_weights`, `create_gen_rep_weights`, `create_sdr_weights`, `create_replicate_weights`, `as_taylor_design` |
| Propensity | `ipw` |

**Excluded functions** (no edits, but still valid `@seealso` link targets):
`create_jackknife_weights`, `create_group_jackknife_weights`

---

## Two-Phase Structure

### Phase 1 — Structural Docs

Pure text changes to all 22 functions. Zero R CMD check risk. One PR to
`develop`.

**Changes applied to every function:**

1. `@return` → `@returns` (affects all functions not already using `@returns`)
2. `@seealso` — add to all dispatchers, sibling functions, and canonical
   companions per rule:
   - Dispatchers (`calibrate`, `create_replicate_weights`): must link every
     dispatched function
   - Siblings: all functions within the same `@family` must cross-link
   - Canonical companions: e.g., `ipw()` → `summarize_weights()`
3. **Titles** — active-verb present-tense phrase; no repeating the function
   name's verb (use a synonym); drop "survey weights" (implicit from package
   context); each sibling title must be distinct from every other sibling.
   For `create_*_weights` functions, "Generate" is the approved synonym for
   "Create".
4. **Descriptions** — must add information the title does not contain; no
   formulas; 1–3 sentences max. For `effective_sample_size` and
   `weight_variability`: one sentence on interpretation, one sentence on the
   zero-weight-row exclusion behavior (replaces the current formula-in-description
   pattern).
5. `@param data` — enforce type annotation lead; add forward reference to
   Replicate Weights section where applicable
6. `@param` defaults — state the default first and explicitly label it
   "the default"
7. **Formulas in `@description`** — move to `@section Algorithm:` with
   `\deqn{}`. Affected functions: `effective_sample_size`,
   `weight_variability`.

**Changes applied to specific functions:**

| Function | Additional structural change |
|---|---|
| `calibrate` | Add `@details` method overview (Tier 4 requirement); add `@references` (all 4 calibration papers — see reference map); `@seealso` to all three dispatched functions |
| `create_replicate_weights` | `@seealso` to all dispatched functions only. `@details` method overview and `@references` deferred — require a separate replicate-comprehension plan (comprehension-replicate-methods.md) to verify inline citations before writing. |
| `effective_sample_size` | Add `@references` (Kish 1965); add `@section Algorithm:` with `\deqn{}`; rewrite description (interpretation + zero-weight exclusion) |
| `weight_variability` | Add `@section Algorithm:` with inline code (`cv(w) = sd(w) / mean(w)`); rewrite description |
| `trim_weights` | Add `@references` (Potter & Zheng 2015 — file confirmed in knowledge base); add `@section Algorithm:` (Tier 3 requirement) |
| `calibrate_rake`, `calibrate_linear`, `calibrate_logit` | Populate empty `@references` stubs (papers verified in calibration-framework comprehension doc) |
| `poststratify` | Populate empty `@references` stub (5 papers verified in reference map) |
| `create_bootstrap_weights`, `create_brr_weights`, `create_gen_boot_weights`, `create_gen_rep_weights`, `create_sdr_weights` | Add or verify `@references` — all papers have file paths in reference map |
| `calibrate_linear`, `calibrate_logit`, `poststratify` | Verify `@references` populated (stubs exist) |
| `redistribute_weights` | Full audit of all sections — title → "Transfer weight from excluded rows to retained rows"; `@return` → `@returns`; add `@seealso` |
| `adjust_nonresponse` | Full audit; add `@seealso` sibling cross-link to `redistribute_weights` |

**Reference map authority:** `.claude/reference-map.yaml` is the authoritative
source for `@references` content. As of this session:
- `calibrate`: populated with 4 papers (same as rake/linear/logit)
- `trim_weights`: populated with Potter & Zheng (2015)
- `create_replicate_weights`: populated with 14 papers aggregated from
  dispatched functions

**End of phase:** run `devtools::document()`, confirm 0 errors/warnings in
check, open PR.

---

### Phase 2 — Examples

Family-by-family. Each family block is verified with `devtools::run_examples()`
before moving to the next. One combined PR after all families are verified.

**Key rules enforced:**
- All examples use package data (no inline `data.frame`, no `data(x, package = "other")`)
- Every function that accepts survey objects gets at least one survey-object
  example demonstrating unique behavior
- `\dontrun{}` only for genuine external resource requirements — none expected here
- Comments explain WHY, not what; section headers label the scenario being
  demonstrated
- Section header format: `# Brief scenario label ---------------------------`

**`surveytidy` added to `Suggests`:** Examples for nonresponse functions use
`surveytidy::mutate()` to add columns to `survey_taylor` objects — the
idiomatic approach that preserves S7 class and validator contracts without
direct `@data` slot assignment. Add `surveytidy` to `Suggests` in DESCRIPTION.
Each such example includes a brief comment explaining why `surveytidy::mutate()`
is used instead of direct slot access.

---

## Seealso Map

Pre-enumerated for parallel subagent dispatch. Every in-scope function gets
exactly this `@seealso` block — no derivation needed at implementation time.
"Already present" entries must be verified to match; update if incomplete.

Excluded functions (`create_jackknife_weights`, `create_group_jackknife_weights`)
appear as link targets only — no edits to those files.

| Function | `@seealso` links |
|---|---|
| `effective_sample_size` | `[weight_variability()]`, `[summarize_weights()]` |
| `weight_variability` | `[effective_sample_size()]`, `[summarize_weights()]` |
| `summarize_weights` | `[effective_sample_size()]`, `[weight_variability()]` |
| `trim_weights` | `[stabilize_weights()]` |
| `stabilize_weights` | `[trim_weights()]` |
| `calibrate` | `[calibrate_rake()]`, `[calibrate_linear()]`, `[calibrate_logit()]`, `[poststratify()]` |
| `calibrate_rake` | `[calibrate()]`, `[calibrate_linear()]`, `[calibrate_logit()]`, `[poststratify()]` |
| `calibrate_linear` | `[calibrate()]`, `[calibrate_rake()]`, `[calibrate_logit()]`, `[poststratify()]` |
| `calibrate_logit` | `[calibrate()]`, `[calibrate_rake()]`, `[calibrate_linear()]`, `[poststratify()]` |
| `poststratify` | `[calibrate()]`, `[calibrate_rake()]`, `[calibrate_linear()]`, `[calibrate_logit()]` |
| `calibrate_to_estimate` | `[calibrate_to_survey()]` |
| `calibrate_to_survey` | `[calibrate_to_estimate()]` ← already present; verify |
| `adjust_nonresponse` | `[redistribute_weights()]` ← already present; verify |
| `redistribute_weights` | `[adjust_nonresponse()]` |
| `create_bootstrap_weights` | `[create_jackknife_weights()]`, `[create_group_jackknife_weights()]`, `[create_brr_weights()]`, `[create_gen_boot_weights()]`, `[create_gen_rep_weights()]`, `[create_sdr_weights()]`, `[create_replicate_weights()]`, `[as_taylor_design()]` |
| `create_brr_weights` | `[create_bootstrap_weights()]`, `[create_jackknife_weights()]`, `[create_group_jackknife_weights()]`, `[create_gen_boot_weights()]`, `[create_gen_rep_weights()]`, `[create_sdr_weights()]`, `[create_replicate_weights()]`, `[as_taylor_design()]` |
| `create_gen_boot_weights` | `[create_bootstrap_weights()]`, `[create_jackknife_weights()]`, `[create_group_jackknife_weights()]`, `[create_brr_weights()]`, `[create_gen_rep_weights()]`, `[create_sdr_weights()]`, `[create_replicate_weights()]`, `[as_taylor_design()]` |
| `create_gen_rep_weights` | `[create_bootstrap_weights()]`, `[create_jackknife_weights()]`, `[create_group_jackknife_weights()]`, `[create_brr_weights()]`, `[create_gen_boot_weights()]`, `[create_sdr_weights()]`, `[create_replicate_weights()]`, `[as_taylor_design()]` |
| `create_sdr_weights` | `[create_bootstrap_weights()]`, `[create_jackknife_weights()]`, `[create_group_jackknife_weights()]`, `[create_brr_weights()]`, `[create_gen_boot_weights()]`, `[create_gen_rep_weights()]`, `[create_replicate_weights()]`, `[as_taylor_design()]` |
| `create_replicate_weights` | `[create_bootstrap_weights()]`, `[create_jackknife_weights()]`, `[create_group_jackknife_weights()]`, `[create_brr_weights()]`, `[create_gen_boot_weights()]`, `[create_gen_rep_weights()]`, `[create_sdr_weights()]`, `[as_taylor_design()]` ← add `[create_group_jackknife_weights()]` and `[as_taylor_design()]` to existing |
| `as_taylor_design` | `[create_bootstrap_weights()]`, `[create_jackknife_weights()]`, `[create_group_jackknife_weights()]`, `[create_brr_weights()]`, `[create_gen_boot_weights()]`, `[create_gen_rep_weights()]`, `[create_sdr_weights()]`, `[create_replicate_weights()]` |
| `ipw` | `[adjust_nonresponse()]`, `[calibrate_to_survey()]`, `[summarize_weights()]` ← add `[summarize_weights()]` to existing |

---

## Dataset Mapping

| Function(s) | Dataset(s) | Notes |
|---|---|---|
| `effective_sample_size`, `weight_variability`, `summarize_weights` | `ns_wave1`, `ns_wave1_svy` | `summarize_weights` shows `by = sex` |
| `trim_weights`, `stabilize_weights` | `ns_wave1`, `ns_wave1_svy`, `acs_wy_2022_svy` | `acs_wy_2022_svy` demonstrates replicate weight path |
| `calibrate`, `calibrate_rake`, `calibrate_linear`, `calibrate_logit`, `poststratify` | `ns_wave1`, `ns_wave1_svy` | hardcoded US population margins for `gender`, `age_group` |
| `adjust_nonresponse`, `redistribute_weights` | `gss_2024` + synthetic `response_status` via `sample()` (no `set.seed()`) for data.frame path; `gss_2024_svy` + `surveytidy::mutate()` for survey_taylor path | Following svrep convention: no `set.seed()` |
| `calibrate_to_estimate` | `gss_2024` (primary via `wt_pop` + `create_jackknife_weights(type = "jkn")`) + `npors_2025_clean` (control via `survey::svydesign` + `survey::as.svrepdesign(type = "JKn")`) | Single scenario: calibrate `gss_2024` pid_f3 to NPORS estimates. Both datasets use `wt_pop` (~260M US adults). Targets via `survey::svytotal(~pid_f3, npors_pop)`; names via `setNames(coef(), levels())`. No `\donttest{}` needed. |
| `calibrate_to_survey` | `pew_2016_optin_svy` (NPS primary; 2,000 rows, 200 reps, scale = 0.005) + `create_bootstrap_weights(npors_2025_clean_svy, replicates = 50L)` as control | Single NPS scenario only — prob-to-prob path dropped. Variables: `c(age_f3, pid_f3)`. Runs in ~2s. No `\donttest{}` needed. |
| `ipw` | `ns_wave1` (NPS) + `gss_2024` with `wt_pop` (probability reference) | Keep current `gss_2024 + wt_pop` approach — `gss_2024_svy` uses `wtssps` (normalized, not population-scale) and is wrong for IPW. Cosmetic changes only: drop `data()` calls, fix comment style, standardize section headers. |
| `create_bootstrap_weights` | `gss_2024_svy` (probability), `ns_wave1_svy` (non-probability) | Two scenarios: (1) default SRSWR on `gss_2024_svy`; (2) `type = "quasi-randomization"` on `ns_wave1_svy`. NPS type must be explicit — SRSWR is wrong for NPS. |
| `create_brr_weights` | `gss_2024_svy` | Two scenarios: (1) default BRR; (2) Fay's method with explicit `fay` value (e.g., `fay = 0.5`). ✅ confirmed: 67 strata × 2 PSUs. |
| `create_gen_boot_weights` | `gss_2024_svy` | One scenario with `seed` for reproducibility. Prob-only. |
| `create_gen_rep_weights` | `gss_2024_svy` | One scenario with `seed` for reproducibility. Prob-only. |
| `create_sdr_weights` | `as_taylor_design(acs_wy_2022_svy)` | One scenario: convert ACS replicate to Taylor, then apply SDR. Shows natural sequence. |
| `create_replicate_weights` | `gss_2024_svy` (scenarios 1–2), `ns_wave1_svy` (scenario 3) | Three scenarios: (1) `method = "bootstrap"`; (2) `method = "jackknife"`; (3) `method = "jackknife"` with `type = "grouped"` via `...` (NPS path). |
| `as_taylor_design` | `acs_wy_2022_svy` | One scenario: survey_replicate → survey_taylor. |

---

## Tier Classifications

Per `function-documentation.md`, each function's tier determines which sections
are required.

| Tier | Functions |
|---|---|
| Tier 1 — Utility | `effective_sample_size`, `weight_variability`, `summarize_weights`, `stabilize_weights`, `as_taylor_design` |
| Tier 2 — Standard | `adjust_nonresponse`, `redistribute_weights`, `calibrate_to_estimate`, `calibrate_to_survey` |
| Tier 3 — Algorithmic | `trim_weights`, `calibrate_rake`, `calibrate_linear`, `calibrate_logit`, `poststratify`, `create_bootstrap_weights`, `create_brr_weights`, `create_gen_boot_weights`, `create_gen_rep_weights`, `create_sdr_weights`, `ipw` |
| Tier 4 — Dispatcher | `calibrate`, `create_replicate_weights` |

---

## Implementation Order

### Phase 1 order (structural)

**Dispatch strategy:** 7 parallel subagents, one per family, each in its own
git worktree on its own branch. All `@seealso` links are pre-enumerated in the
Seealso Map above — subagents do not need to read sibling family files.

**Critical constraint for all subagents:** edit `.R` source files only.
Do NOT run `devtools::document()`. The parent agent runs it once after all
worktrees are merged.

**Universal rewrite baseline (applies to every function in every brief):**
Rewrite all documentation sections from scratch per the function's tier
classification and `function-documentation.md`. The pre-approved content in
the Title Map, Seealso Map, and approved description blocks below are
**locked-in** — use them verbatim and do not re-derive. Where no approved
text is provided, derive from the function's source code and the tier rules.
The per-function notes below are exceptions, constraints, and pre-approved
content only — not a complete list of changes.

**Subagent briefs (one per family):**

1. **Diagnostics** — `effective_sample_size`, `weight_variability`, `summarize_weights`
   - `@return` → `@returns` on all three
   - Titles per Title Map
   - `@seealso` per Seealso Map
   - `effective_sample_size`: use approved description below; move formula to
     `@section Algorithm:` with `\deqn{}`; add `@references` (Kish 1965)
     > The effective sample size (ESS) measures how much statistical precision the weighted sample retains relative to an equal-sized simple random sample. Higher weight variability reduces the ESS, resulting in higher variance for weighted estimates. Rows with zero weights (typically produced by [adjust_nonresponse()]) are excluded before computing ESS.
   - `weight_variability`: use approved description below; move formula to
     `@section Algorithm:` as inline code (`cv(w) = sd(w) / mean(w)`)
     > The coefficient of variation (CV) measures how spread out the weights are relative to their mean. A CV near zero indicates near-uniform weights; higher values signal greater variability and a correspondingly larger design effect. Rows with zero weights (typically produced by [adjust_nonresponse()]) are excluded before computing CV.
   - `summarize_weights`: use approved description below
     > Returns a tibble with n, mean, CV, percentiles (p25, p50, p75), and ESS for the weight column. Pass `by` to compute statistics separately within each subgroup defined by one or more grouping variables.

2. **Utilities** — `trim_weights`, `stabilize_weights`
   - `@return` → `@returns` if not already `@returns`
   - Titles per Title Map
   - `@seealso` per Seealso Map
   - `trim_weights`: `@references` already in reference map (Potter & Zheng 2015);
     `@section Algorithm:` required (Tier 3) — add if missing
   - `stabilize_weights`: Tier 1 — `@details` not required unless formula present

3. **Calibration** — `calibrate_rake`, `calibrate_linear`, `calibrate_logit`, `poststratify`, `calibrate`
   - `@return` → `@returns` on all
   - Titles per Title Map
   - `@seealso` per Seealso Map
   - `calibrate_rake`, `calibrate_linear`, `calibrate_logit`: populate
     `@references` from reference map; `@section Algorithm:` and
     `@section Convergence:` required (Tier 3) — add if missing
   - `poststratify`: populate `@references` from reference map (5 papers)
   - `calibrate` (Tier 4): use pre-drafted `@details` from Pre-drafted Content
     section below; add `@references` (4 papers from reference map)

4. **Sample calibration** — `calibrate_to_estimate`, `calibrate_to_survey`
   - `@return` → `@returns` if not already
   - Titles per Title Map
   - `@seealso` per Seealso Map

5. **Nonresponse** — `adjust_nonresponse`, `redistribute_weights`
   - `@return` → `@returns` on both
   - Titles per Title Map
   - `@seealso` per Seealso Map

6. **Replicate weights** — `create_bootstrap_weights`, `create_brr_weights`, `create_gen_boot_weights`, `create_gen_rep_weights`, `create_sdr_weights`, `as_taylor_design`, `create_replicate_weights`
   - `@return` → `@returns` on all
   - Titles per Title Map
   - `@seealso` per Seealso Map (includes excluded functions as link targets)
   - `create_bootstrap_weights` through `create_sdr_weights`: populate
     `@references` from reference map
   - `create_replicate_weights`: `@seealso` only — do NOT write `@details` or
     `@references` (deferred to replicate-comprehension plan)

7. **Propensity** — `ipw`
   - `@return` → `@returns`
   - Titles per Title Map
   - `@seealso` per Seealso Map (add `[summarize_weights()]` to existing)

**After all 7 worktrees complete:**
- Parent agent merges all branches onto `docs/phase-1-structural`
- Run `devtools::document()` once
- Run `devtools::check()` — must pass 0 errors, 0 warnings
- Open PR to `develop`

### Phase 2 order (examples)

**Approved example scenarios:**

*Diagnostics* — `effective_sample_size`, `weight_variability`: 2 scenarios each (data.frame with `weights = weight`; survey_nonprob auto-detected). `summarize_weights`: 3 scenarios (overall; `by = sex`; survey_nonprob auto-detected). All well under 25 lines; no `\donttest{}` needed.

*Utilities* — `trim_weights`: 4 scenarios: IQR default (`k = 5`); explicit percentile bounds (`lower = 0.05, upper = 0.95, type = "percentile"`, broken across lines per 80-char rule); absolute bounds (`lower = 0.3, upper = 3.0, type = "absolute"`, broken across lines); survey_replicate auto-detected (`acs_wy_2022_svy`). ~22 lines total, under limit. `stabilize_weights`: 3 scenarios: data.frame with `weights = weight`; `by = sex` grouping; survey_nonprob auto-detected (`ns_wave1_svy`). All calls fit on one line.

*Calibration* — All five functions use `ns_wave1` (data.frame path, `weights = weight`) and `ns_wave1_svy` (survey_nonprob auto-detected). Population margins: `sex = c("Male" = 0.49, "Female" = 0.51)`, `age_f3 = c("18-34" = 0.30, "35-54" = 0.33, "55+" = 0.37)`. `calibrate`: 4 scenarios — Format A + rake (default), Format A + linear, Format A + logit, Format B + rake (~32 lines). `calibrate_rake`: 4 scenarios — Format A + classic_ipf (default), Format A + nr algorithm, survey_nonprob, Format B (~25 lines). `calibrate_linear`, `calibrate_logit`: 3 scenarios each — Format A + data.frame, survey_nonprob, Format B (~18 lines). `poststratify`: 3 scenarios — joint cell proportions (sex × age_f3, 6 cells, sum = 1.000), survey_nonprob, `type = "count"` with population counts summing to 260,000,000 (~33 lines). `poststratify` only accepts data frame targets (named lists rejected), so `type = "count"` serves as the second format demonstration.

*Nonresponse* — `adjust_nonresponse` and `redistribute_weights` both synthesize `response_status` via inline `sample()` with no `set.seed()` (following svrep convention). data.frame path: add column directly to `gss_2024` tibble (`gss$responded <- sample(...)`), call function with `weights = wtssps, by = sex`. survey_taylor path: add column via `surveytidy::mutate(gss_2024_svy, responded = sample(...))`, then call function with `response_status = responded`. `redistribute_weights` uses same structure with `reduce_if` / `increase_if` columns instead of `response_status`.

*Sample calibration — `calibrate_to_estimate`* — Single scenario. Approved code (runs clean):
```r
# create GSS replicate survey
gss_pop <- surveycore::as_survey(
  gss_2024[!is.na(gss_2024$pid_f3), ],
  weights = wt_pop,
  strata  = vstrat,
  ids     = vpsu,
  nest    = TRUE
) |>
  create_jackknife_weights(type = "jkn")

# create NPORS control design (must use survey pkg for svytotal/coef/vcov)
npors_pop <- survey::svydesign(
  ids     = ~1,
  strata  = ~stratum,
  weights = ~wt_pop,
  data    = npors_2025_clean
) |>
  survey::as.svrepdesign(type = "JKn")

# derive targets from control survey
pid_f3_est    <- survey::svytotal(~pid_f3, npors_pop)
pid_f3_totals <- setNames(coef(pid_f3_est), levels(npors_2025_clean$pid_f3))
vcov_pid_f3   <- vcov(pid_f3_est)

result <- calibrate_to_estimate(
  gss_pop,
  targets       = list(pid_f3 = pid_f3_totals),
  vcov_estimate = vcov_pid_f3
)
```
~18 lines. No `\donttest{}` needed (JKn on 3,309-row GSS is fast).

Same family order. After each family:
- Run `devtools::run_examples(package = "surveywts")` scoped to the family's functions
- Fix any warnings/errors before moving to next family
- If a dataset produces spurious warnings, use the nearest clean alternative and note the deviation

---

## Title Map

Pre-specified replacement titles for all 22 in-scope functions. Subagents must
use these exactly — no derivation. Functions not listed have compliant titles
and need no change.

| Function | Title |
|---|---|
| `effective_sample_size` | "Estimate Kish's effective sample size of weighted data" |
| `weight_variability` | "Measure how unequal the survey weights are" |
| `summarize_weights` | "Report summary statistics for the weight distribution" |
| `trim_weights` | "Clip weights to a bounded interval" |
| `stabilize_weights` | "Rescale weights to sum to the sample size" |
| `calibrate` | "Adjust weights to match population totals" |
| `calibrate_rake` | "Fit weights using raking" |
| `calibrate_linear` | "Fit weights using linear (GREG) calibration" |
| `calibrate_logit` | "Fit weights using logit-bounded calibration" |
| `poststratify` | "Fit weights using post-stratification" |
| `calibrate_to_estimate` | "Reweight to externally estimated population totals" |
| `calibrate_to_survey` | "Reweight to population totals estimated from a control survey" |
| `adjust_nonresponse` | "Correct weights for unit nonresponse" |
| `redistribute_weights` | "Transfer weight from excluded rows to retained rows" |
| `create_bootstrap_weights` | "Generate bootstrap replicate weights" |
| `create_brr_weights` | "Generate BRR (Fay) replicate weights" |
| `create_gen_boot_weights` | "Generate generalized bootstrap replicate weights" |
| `create_gen_rep_weights` | "Generate generalized replication replicate weights" |
| `create_sdr_weights` | "Generate successive difference replication weights" |
| `create_replicate_weights` | "Generate replicate weights for a survey design" |
| `as_taylor_design` | ✅ no change — "Convert a replicate design back to a Taylor design" |
| `ipw` | "Estimate inverse probability weights for a non-probability sample" |

---

## Pre-drafted Content

### `calibrate` — `@details` method overview

Verified against `comprehension-calibration-framework.md`. Copy verbatim into
`R/calibrate.R`.

```r
#' @details
#' All three methods implement the Deville-Sarndal calibration framework:
#' each adjusts survey weights so that weighted auxiliary totals match
#' known population totals. The methods share a variance estimator and
#' differ in the weight-ratio function \eqn{F} applied during calibration
#' (Deville & Sarndal 1992; Deville, Sarndal & Sautory 1993).
#'
#' **Raking** (`method = "rake"`, the default) uses the multiplicative
#' function \eqn{F(u) = \exp(u)}, which keeps all calibrated weights
#' strictly positive. For marginal targets, raking reduces to classical
#' iterative proportional fitting (Deville, Sarndal & Sautory 1993). Two
#' algorithms are available via `algorithm` (passed through `...`):
#' `"classic_ipf"` (the default; chi-square variable selection ported
#' from the ANES raking procedure, DeBell & Krosnick 2009) and `"nr"`
#' (Newton-Raphson). The weight ratio \eqn{w_k / d_k} is unbounded above.
#'
#' **Linear** (`method = "linear"`) uses \eqn{F(u) = 1 + u}, equivalent
#' to the generalized regression (GREG) estimator. The solution is exact
#' in a single step — no iteration required — making it the fastest method
#' (Deville & Sarndal 1992). The weight ratio is unbounded in both
#' directions; large sample-to-population discrepancies can produce
#' negative calibrated weights.
#'
#' **Logit** (`method = "logit"`) constrains the weight ratio
#' \eqn{w_k / d_k} to the open interval \eqn{(L, U)} via a logit-bounded
#' \eqn{F} function (Deville & Sarndal 1992; Deville, Sarndal & Sautory
#' 1993). Pass `bounds` via `...` to control the interval (default
#' `c(1e-6, 1e6)`). Note that bounds apply to the ratio of calibrated to
#' design weight, not to calibrated weights directly.
#'
#' For full algorithm documentation, convergence criteria, and
#' replicate-weight handling, see [calibrate_rake()],
#' [calibrate_linear()], and [calibrate_logit()].
```

---

## Known Risks

| Risk | Mitigation | Status |
|---|---|---|
| `create_brr_weights` example requires 2-PSU/stratum structure | ✅ Resolved: `gss_2024_svy` has 67 strata × 2 PSUs — standard package data works | Closed |
| `calibrate_to_survey` NPS example requires `create_bootstrap_weights()` to set `@variables$scale` | ✅ Resolved: confirmed via `.convert_and_call()` in `replicate-utils.R`; value is `1/replicates` from `svrep` | Closed |
| Examples on large datasets (`pew_2016_optin_svy`, 200 replicate weights) may be slow | ✅ Resolved: `calibrate_to_estimate` uses `gss_2024` + `npors_2025_clean` (JKn, fast). `calibrate_to_survey` NPS path TBD in grilling. | Closed |
| `create_replicate_weights` @details + @references blocked by missing comprehension doc | Separate plan: `comprehension-replicate-methods.md` — pipeline-spec task to ingest 6 replication method papers before @details can be written | Open |
| `adjust_nonresponse` / `redistribute_weights`: synthesized `response_status` via `sample()` may produce edge-case cells | ✅ Resolved: following svrep convention — no `set.seed()`; approved example scenarios use `sample()` directly. | Closed |
