# surveywts Documentation Rewrite Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rewrite roxygen2 documentation for 22 exported surveywts functions across two phases — Phase 1 (structural: titles, descriptions, @seealso, @references, @section blocks) and Phase 2 (examples: replace inline data.frame examples with approved package-data scenarios).

**Architecture:** Phase 1 is 7 parallel-eligible family tasks that each edit only `.R` source files, followed by one `devtools::document()` + PR. Phase 2 is 7 sequential family tasks each verified with `devtools::run_examples()`, followed by a final PR. Both phases target the `develop` branch.

**Tech Stack:** R, roxygen2, devtools

## Global Constraints

- Phase 1: edit `.R` source files only — do NOT run `devtools::document()` until Task 8
- All examples must use package data (no inline `data.frame()` construction); approved datasets: `ns_wave1`, `ns_wave1_svy`, `gss_2024`, `gss_2024_svy`, `acs_wy_2022_svy`, `pew_2016_optin_svy`, `npors_2025_clean`, `npors_2025_clean_svy`
- No `\dontrun{}` in any example — all examples must run during `R CMD check`
- Phase 1 Tasks 1–7 are independent and can run in parallel git worktrees
- Phase 2 Tasks 9–15 are sequential — verify each family with `devtools::run_examples()` before proceeding
- Excluded functions (`create_jackknife_weights`, `create_group_jackknife_weights`) appear as `@seealso` link targets only — do NOT edit their source files
- Do NOT write `@details` or `@references` for `create_replicate_weights` (deferred to replicate-comprehension plan)
- `surveywts_error_*`/`surveywts_warning_*` class names must not appear in help text
- Use `@returns` (plural) everywhere — never `@return`
- `@param` defaults: state the default first and label it "the default": e.g., `"rake"` (the default), `"linear"`, or `"logit"`
- Reference map at `.claude/reference-map.yaml` is authoritative for all `@references` content — use citations verbatim from that file

---

## Phase 1 — Structural Docs (Tasks 1–7 are independent / parallelizable)

### Phase 1 branch strategy

Each family task works on its own branch:
`docs/phase-1-diagnostics`, `docs/phase-1-utilities`, `docs/phase-1-calibration`,
`docs/phase-1-sample-calibration`, `docs/phase-1-nonresponse`,
`docs/phase-1-replicate-weights`, `docs/phase-1-propensity`

After all 7 tasks complete, a parent operation merges them all onto `docs/phase-1-structural`, runs `devtools::document()`, runs `devtools::check()`, and opens a PR to `develop`.

---

### Task 1: Phase 1 — Diagnostics Family

**Files:** `R/effective_sample_size.R`, `R/weight_variability.R`, `R/summarize_weights.R`

**Branch:** `docs/phase-1-diagnostics` (cut from `develop`)

**Tier:** All three are Tier 1 — Utility. Required sections: `@section Algorithm:` (because each has a formula), `@references` (for ESS only).

- [ ] **Step 1: Create branch and read files**

```bash
git checkout develop
git checkout -b docs/phase-1-diagnostics
```

Read all three files before editing:
- `R/effective_sample_size.R`
- `R/weight_variability.R`
- `R/summarize_weights.R`

- [ ] **Step 2: Rewrite `R/effective_sample_size.R` header**

Replace the entire roxygen2 block (lines 9–24) with:

```r
#' Estimate Kish's effective sample size of weighted data
#'
#' The effective sample size (ESS) measures how much statistical precision the
#' weighted sample retains relative to an equal-sized simple random sample.
#' Higher weight variability reduces the ESS, resulting in higher variance for
#' weighted estimates. Rows with zero weights (typically produced by
#' [adjust_nonresponse()]) are excluded before computing ESS.
#'
#' @param x A `data.frame`, `weighted_df`, `survey_taylor`, or
#'   `survey_nonprob`. For `weighted_df` and survey objects, the weight
#'   column is auto-detected.
#' @param weights Bare name (NSE). Weight column. Auto-detected for
#'   `weighted_df` and survey objects. Required for plain `data.frame`.
#'
#' @returns A named numeric scalar: `c(n_eff = <value>)`. The name `"n_eff"`
#'   is part of the API contract.
#'
#' @section Algorithm:
#' \deqn{ESS = \frac{(\sum w)^2}{\sum w^2}}
#'
#' @references
#'   Kish, L. (1965). *Survey Sampling*. New York: John Wiley & Sons.
#'
#' @seealso [weight_variability()], [summarize_weights()]
#' @family diagnostics
#' @export
#'
#' @examples
```

Keep the `@examples` block untouched for now (Phase 2 handles it).

- [ ] **Step 3: Rewrite `R/weight_variability.R` header**

Replace the entire roxygen2 block (lines 9–23) with:

```r
#' Measure how unequal the survey weights are
#'
#' The coefficient of variation (CV) measures how spread out the weights are
#' relative to their mean. A CV near zero indicates near-uniform weights;
#' higher values signal greater variability and a correspondingly larger design
#' effect. Rows with zero weights (typically produced by [adjust_nonresponse()])
#' are excluded before computing CV.
#'
#' @inheritParams effective_sample_size
#'
#' @returns A named numeric scalar: `c(cv = <value>)`. The name `"cv"` is
#'   part of the API contract.
#'
#' @section Algorithm:
#' `cv(w) = sd(w) / mean(w)`
#'
#' @seealso [effective_sample_size()], [summarize_weights()]
#' @family diagnostics
#' @export
#'
#' @examples
```

Keep the `@examples` block untouched.

- [ ] **Step 4: Rewrite `R/summarize_weights.R` header**

Replace the entire roxygen2 block (lines 9–32) with:

```r
#' Report summary statistics for the weight distribution
#'
#' Returns a tibble with n, mean, CV, percentiles (p25, p50, p75), and ESS
#' for the weight column. Pass `by` to compute statistics separately within
#' each subgroup defined by one or more grouping variables.
#'
#' @inheritParams effective_sample_size
#' @param by <[`tidy-select`][tidyselect::language]> Optional grouping
#'   variables. When `NULL` (the default), a single-row summary over all
#'   observations is returned. When specified, one row is returned per
#'   unique group combination.
#'
#' @returns A tibble with columns `n`, `n_positive`, `n_zero`, `mean`, `cv`,
#'   `min`, `p25`, `p50`, `p75`, `max`, `ess`. When `by` is non-`NULL`,
#'   the group columns precede the summary columns.
#'
#' @seealso [effective_sample_size()], [weight_variability()]
#' @family diagnostics
#' @export
#'
#' @examples
```

Keep the `@examples` block untouched.

- [ ] **Step 5: Commit**

```bash
git add R/effective_sample_size.R R/weight_variability.R R/summarize_weights.R
git commit -m "docs(diagnostics): rewrite structural docs for Phase 1"
```

---

### Task 2: Phase 1 — Utilities Family

**Files:** `R/trim_weights.R`, `R/stabilize_weights.R`

**Branch:** `docs/phase-1-utilities` (cut from `develop`)

**Tier:** `trim_weights` is Tier 3 (requires `@section Algorithm:`, `@references`). `stabilize_weights` is Tier 1.

- [ ] **Step 1: Create branch and read files**

```bash
git checkout develop
git checkout -b docs/phase-1-utilities
```

Read both files before editing.

- [ ] **Step 2: Edit `R/trim_weights.R` title and add @seealso + @references**

The current title is "Trim survey weights to a specified interval". Change it to:

```r
#' Clip weights to a bounded interval
```

The current description already explains the mechanism — keep it as-is (it is compliant with tier rules since it adds information the title doesn't contain).

Verify the `@returns` tag is already present (it is). No change needed.

Verify `@section Algorithm:` exists and documents the IQR/percentile/absolute bound logic. If absent, add after the `@returns` block:

```r
#' @section Algorithm:
#' Bounds are computed from the main weights:
#' - `type = "absolute"` with `upper = NULL`: `upper_abs = median(w) + k * IQR(w)`;
#'   `lower_abs = lower` (or `0` if `NULL`).
#' - `type = "absolute"` with `upper` specified: `upper_abs = upper`,
#'   `lower_abs = lower` (or `0` if `NULL`).
#' - `type = "percentile"`: `lower_abs = quantile(w, lower)`,
#'   `upper_abs = quantile(w, upper)`.
#'
#' Within each clip-and-redistribute pass, weights above `upper_abs` are
#' clipped to `upper_abs`; weights below `lower_abs` are clipped to
#' `lower_abs`. The clipped mass is redistributed proportionally to
#' untrimmed observations so that the total weight sum is preserved. When
#' `strict = TRUE`, the pass repeats until all weights satisfy
#' `[lower_abs, upper_abs]`.
```

Add `@references` before `@seealso` (which is currently absent — add it too):

```r
#' @references
#'   Potter, F. and Zheng, Y. (2015). Methods and issues in trimming extreme
#'   weights in sample surveys. *Proceedings of the Joint Statistical
#'   Meetings, Section on Survey Research Methods*, 2707--2719.
#'
#' @seealso [stabilize_weights()]
```

Keep all existing `@param` docs, `@section Replicate Weights:`, and `@family utilities` tags.

- [ ] **Step 3: Edit `R/stabilize_weights.R` title and add @seealso**

The current title is "Stabilize survey weights to sum to sample size". Change it to:

```r
#' Rescale weights to sum to the sample size
```

The description ("Rescales weights so they sum to the sample size `n` (globally)...") is compliant — keep it.

Verify `@returns` is already present (it is). No change needed.

Add `@seealso` before `@family utilities`:

```r
#' @seealso [trim_weights()]
```

Keep all existing `@param` and `@section Replicate Weights:` content.

- [ ] **Step 4: Commit**

```bash
git add R/trim_weights.R R/stabilize_weights.R
git commit -m "docs(utilities): rewrite structural docs for Phase 1"
```

---

### Task 3: Phase 1 — Calibration Family

**Files:** `R/calibrate.R`, `R/calibrate_rake.R`, `R/calibrate_linear.R`, `R/calibrate_logit.R`, `R/poststratify.R`

**Branch:** `docs/phase-1-calibration` (cut from `develop`)

**Tiers:** `calibrate` is Tier 4 (dispatcher); `calibrate_rake`, `calibrate_linear`, `calibrate_logit`, `poststratify` are Tier 3 (algorithmic).

- [ ] **Step 1: Create branch and read all 5 files**

```bash
git checkout develop
git checkout -b docs/phase-1-calibration
```

- [ ] **Step 2: Rewrite `R/calibrate.R` header**

The current title is "Calibrate survey weights". Replace the entire roxygen2 header block with:

```r
#' Adjust weights to match population totals
#'
#' A thin dispatcher that routes to [calibrate_rake()], [calibrate_linear()],
#' or [calibrate_logit()] based on `method`. All arguments are forwarded
#' unchanged; all validation and error handling occur in the dispatched
#' function.
#'
#' @param data A `data.frame`, `weighted_df`, `survey_taylor`, `survey_nonprob`,
#'   or `survey_replicate`. Forwarded unchanged to the dispatched function. For
#'   `survey_replicate` inputs, calibration is applied to every replicate weight
#'   column using the same `targets`; see the dispatched function for replicate
#'   weight handling details.
#' @param targets Target specification. Forwarded to the dispatched function.
#'   Two formats are accepted:
#'
#'   **Format A — named list** (one element per calibration variable):
#'   ```r
#'   list(
#'     sex   = c("Male" = 0.49, "Female" = 0.51),
#'     age_f3 = c("18-34" = 0.30, "35-54" = 0.33, "55+" = 0.37)
#'   )
#'   ```
#'
#'   **Format B — long data frame** with columns `variable`, `level`, `target`:
#'   ```r
#'   data.frame(
#'     variable = c("sex", "sex", "age_f3", "age_f3", "age_f3"),
#'     level    = c("Male", "Female", "18-34", "35-54", "55+"),
#'     target   = c(0.49, 0.51, 0.30, 0.33, 0.37)
#'   )
#'   ```
#'
#'   Format B is auto-detected and converted to Format A before dispatch.
#'   See [calibrate_rake()], [calibrate_linear()], or [calibrate_logit()]
#'   for per-method target validation rules.
#' @param weights <[`tidy-select`][tidyselect::language]> Weight column
#'   (bare name). Forwarded to the dispatched function. `NULL` (the default)
#'   auto-detects the weight column from `weighted_df` attributes or survey
#'   object `@variables$weights`.
#' @param wt_name `character(1)`. Name of the output weight column in the
#'   returned `weighted_df`. `"wts"` (the default). Ignored when `data` is a
#'   survey object.
#' @param type `character(1)`. `"prop"` (the default): `targets` values are
#'   proportions. `"count"`: `targets` values are population counts. Forwarded
#'   to the dispatched function.
#' @param reference_design A `survey_taylor` or `NULL` (the default). Stored
#'   in the weighting history for provenance. Forwarded to the dispatched
#'   function.
#' @param ... Additional arguments forwarded as-is to the dispatched function.
#'   See [calibrate_rake()], [calibrate_linear()], or [calibrate_logit()]
#'   for available arguments (e.g., `algorithm`, `bounds`, `cap`, `control`).
#' @param method `character(1)`. Calibration method: `"rake"` (the default),
#'   `"linear"`, or `"logit"`. Matched with [rlang::arg_match()].
#'   - `"rake"`: multiplicative raking via [calibrate_rake()]. Weights remain
#'     strictly positive. Two algorithms available via `algorithm` in `...`.
#'   - `"linear"`: GREG estimator via [calibrate_linear()]. Exact in one step;
#'     may produce negative weights for large discrepancies.
#'   - `"logit"`: logit-bounded calibration via [calibrate_logit()]. G-weight
#'     ratios constrained to an open interval `(L, U)` via `bounds` in `...`.
#'
#' @returns An object of the same class as `data`, as returned by the
#'   dispatched function. See [calibrate_rake()], [calibrate_linear()], or
#'   [calibrate_logit()] for class-specific return value details and
#'   weighting history guarantees.
#'
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
#'
#' @references
#'   DeBell, M. and Krosnick, J.A. (2009). Computing Weights for American
#'   National Election Study Survey Data. ANES Technical Report series,
#'   no. nes012427. Ann Arbor, MI, and Palo Alto, CA: American National
#'   Election Studies.
#'
#'   Deville, J.-C. and Sarndal, C.-E. (1992). Calibration estimators in
#'   survey sampling. *Journal of the American Statistical Association*,
#'   87(418), 376--382.
#'
#'   Deville, J.-C., Sarndal, C.-E. and Sautory, O. (1993). Generalized
#'   raking procedures in survey sampling. *Journal of the American
#'   Statistical Association*, 88(423), 1013--1020.
#'
#'   Kott, P.S. (2003). An overview of calibration weighting. 2003 Joint
#'   Statistical Meetings — Section on Survey Research Methods.
#'
#' @seealso [calibrate_rake()], [calibrate_linear()], [calibrate_logit()],
#'   [poststratify()]
#' @family calibration
#' @export
#'
#' @examples
```

Keep the existing `@examples` block untouched.

- [ ] **Step 3: Edit `R/calibrate_rake.R` — title, @return→@returns, fix @references, add @section blocks, add @seealso**

**3a. Title change:** "Rake survey weights to marginal population totals" → "Fit weights using raking"

**3b. `@return` → `@returns`:** The `@return` tag at line 94 must become `@returns`.

**3c. Fix `@references`:** The current block has 4 references including "Chang, T. and Kott, P. S. (2008)..." which is wrong per the reference map. Replace the entire `@references` block with:

```r
#' @references
#'   DeBell, M. and Krosnick, J.A. (2009). Computing Weights for American
#'   National Election Study Survey Data. ANES Technical Report series,
#'   no. nes012427. Ann Arbor, MI, and Palo Alto, CA: American National
#'   Election Studies.
#'
#'   Deville, J.-C. and Sarndal, C.-E. (1992). Calibration estimators in
#'   survey sampling. *Journal of the American Statistical Association*,
#'   87(418), 376--382.
#'
#'   Deville, J.-C., Sarndal, C.-E. and Sautory, O. (1993). Generalized
#'   raking procedures in survey sampling. *Journal of the American
#'   Statistical Association*, 88(423), 1013--1020.
#'
#'   Kott, P.S. (2003). An overview of calibration weighting. 2003 Joint
#'   Statistical Meetings — Section on Survey Research Methods.
```

**3d. Remove the existing `@details` block and replace with `@section Algorithm:` and `@section Convergence:`** immediately before `@references`. The existing `@details` (lines 111–127) overlaps with these sections — delete it entirely:

```r
#' @section Algorithm:
#' Both algorithms implement the raking calibration function
#' \eqn{F(u) = \exp(u)}, which keeps all calibrated weights strictly positive.
#'
#' **Classic IPF (`algorithm = "classic_ipf"`, the default)**
#'
#' At each sweep, variables are ranked by chi-square discrepancy between
#' weighted and target margins (controlled by `control$variable_select`,
#' default `"chi_square"`). Variables with any cell below
#' `control$min_cell_n` (default `5L`) unweighted observations are excluded
#' entirely; variables whose chi-square p-value exceeds `control$pval`
#' (default `0.01`) are skipped for that sweep. Within each selected
#' variable, weights are scaled by `target_k / weighted_k` for each level
#' `k`. If all variables pass or are excluded in sweep 1, a message is
#' emitted indicating the data is already calibrated.
#'
#' **Newton-Raphson (`algorithm = "nr"`)**
#'
#' Solves the calibration score equations via Newton-Raphson iteration.
#' Calibrated weights satisfy
#' \deqn{w_k = d_k \exp(x_k^T \hat{\lambda})}
#' where \eqn{\hat{\lambda}} is found by iterating on
#' \deqn{\sum_{k \in s} d_k \exp(x_k^T \lambda) x_k = X_U.}
#' Step-halving guards against non-finite g-weights at each iteration.
#'
#' @section Convergence:
#' **Classic IPF:** Terminates when the percentage improvement in total
#' chi-square discrepancy between successive sweeps falls below
#' `control$improvement` (default `0.01`%), or when `control$maxit`
#' (default `1000L`) full sweeps are completed.
#'
#' **Newton-Raphson:** Terminates when
#' \eqn{\max(|\text{misfit}| / (1 + |\text{population}|)) < \epsilon},
#' where \eqn{\epsilon} is `control$epsilon` (default `1e-7`), or when
#' `control$maxit` (default `50L`) iterations are completed.
#'
#' Calibration non-convergence raises an error.
```

**3e. Add `@seealso`** immediately before `@family calibration`:

```r
#' @seealso [calibrate()], [calibrate_linear()], [calibrate_logit()],
#'   [poststratify()]
```

- [ ] **Step 4: Edit `R/calibrate_linear.R` — title, @return→@returns, add @section blocks, add @seealso**

**4a. Title change:** "Calibrate survey weights using linear (GREG) or truncated-linear method" → "Fit weights using linear (GREG) calibration"

**4b. `@return` → `@returns`** (at line 102).

**4c. Add `@section Algorithm:` and `@section Convergence:`** before the existing `@references` block:

```r
#' @section Algorithm:
#' Linear calibration uses \eqn{F(u) = 1 + u} (the GREG estimator). The
#' calibrated weights are
#' \deqn{w_k = d_k (1 + x_k^T \hat{\lambda})}
#' where the Lagrange multipliers satisfy
#' \deqn{\hat{\lambda} = \left(\sum_{k \in s} d_k x_k x_k^T\right)^{-1}
#'   \left(X_U - \sum_{k \in s} d_k x_k\right).}
#' The solution is obtained in a single Newton step (no iteration required)
#' when `bounds = NULL`.
#'
#' When `bounds = c(L, U)` is specified, g-weights are constrained to
#' `[L, U]` (truncated-linear calibration) via Newton-Raphson iteration.
#'
#' @section Convergence:
#' For unbounded calibration (`bounds = NULL`), the solution is exact in
#' one step — no convergence check is performed.
#'
#' For bounded calibration, Newton-Raphson terminates when the maximum
#' absolute change in \eqn{\lambda} falls below `control$epsilon` (default
#' `1e-7`), or when `control$maxit` (default `50`) iterations are reached.
#' Calibration non-convergence raises an error.
```

**4d. Add `@seealso`** before `@family calibration`:

```r
#' @seealso [calibrate()], [calibrate_rake()], [calibrate_logit()],
#'   [poststratify()]
```

**4e. Strip URLs from the existing `@references` block** — the current entries include inline JSTOR URLs; remove them to match the reference map format:

```r
#' @references
#'   Deville, J.-C. and Sarndal, C.-E. (1992). Calibration estimators in
#'   survey sampling. *Journal of the American Statistical Association*,
#'   87(418), 376--382.
#'
#'   Deville, J.-C., Sarndal, C.-E. and Sautory, O. (1993). Generalized
#'   raking procedures in survey sampling. *Journal of the American
#'   Statistical Association*, 88(423), 1013--1020.
```

- [ ] **Step 5: Edit `R/calibrate_logit.R` — title, @return→@returns, add @section blocks, add @seealso**

**5a. Title change:** "Calibrate survey weights using logit-bounded method" → "Fit weights using logit-bounded calibration"

**5b. `@return` → `@returns`** (at line 101).

**5c. Add `@section Algorithm:` and `@section Convergence:`** before the existing `@references` block:

```r
#' @section Algorithm:
#' Logit calibration constrains the g-weight ratio \eqn{w_k / d_k} to the
#' open interval \eqn{(L, U)} via the bounded function
#' \deqn{F(u) = \frac{L + U e^u}{1 + e^u}.}
#' The calibrated weights are \eqn{w_k = d_k F(x_k^T \hat{\lambda})},
#' guaranteeing \eqn{L < w_k / d_k < U}. The Lagrange multipliers
#' \eqn{\hat{\lambda}} are found by Newton-Raphson iteration.
#'
#' @section Convergence:
#' Newton-Raphson terminates when the maximum absolute change in
#' \eqn{\lambda} falls below `control$epsilon` (default `1e-7`), or when
#' `control$maxit` (default `50`) iterations are reached. Calibration
#' non-convergence raises an error.
```

**5d. Add `@seealso`** before `@family calibration`:

```r
#' @seealso [calibrate()], [calibrate_rake()], [calibrate_linear()],
#'   [poststratify()]
```

**5e. Strip URLs from the existing `@references` block** — same as `calibrate_linear.R`; remove inline JSTOR URLs:

```r
#' @references
#'   Deville, J.-C. and Sarndal, C.-E. (1992). Calibration estimators in
#'   survey sampling. *Journal of the American Statistical Association*,
#'   87(418), 376--382.
#'
#'   Deville, J.-C., Sarndal, C.-E. and Sautory, O. (1993). Generalized
#'   raking procedures in survey sampling. *Journal of the American
#'   Statistical Association*, 88(423), 1013--1020.
```

- [ ] **Step 6: Edit `R/poststratify.R` — title, @return→@returns, add @section Algorithm, add @seealso**

**6a. Title change:** "Post-stratify survey weights to known joint population cell totals" → "Fit weights using post-stratification"

**6b. `@return` → `@returns`** (at line 69).

**6c. Add `@section Algorithm:`** before the existing `@references` block. (No `@section Convergence:` — the solution is direct, not iterative.)

```r
#' @section Algorithm:
#' Within each cell \eqn{h} defined by the joint combination of
#' stratification variables, the calibration factor is
#' \deqn{c_h = \frac{T_h}{W_h}}
#' where \eqn{T_h} is the target cell total (population count or proportion
#' scaled to population size) and \eqn{W_h = \sum_{k \in h} w_k} is the
#' sum of current weights in cell \eqn{h}. The calibrated weight for each
#' unit in cell \eqn{h} is \eqn{w_k^* = c_h \cdot w_k}. The solution is
#' exact in one pass — no iteration is required.
```

**6d. Add `@seealso`** before `@family calibration`:

```r
#' @seealso [calibrate()], [calibrate_rake()], [calibrate_linear()],
#'   [calibrate_logit()]
```

**6e. Strip DOI URLs from the existing `@references` block** — three of the five entries have inline DOIs; remove them to match the reference map format:

```r
#' @references
#'   Valliant, R. (1993). Poststratification and conditional variance
#'   estimation. *Journal of the American Statistical Association*,
#'   88(421), 89--96.
#'
#'   Deville, J.-C. and Sarndal, C.-E. (1992). Calibration estimators in
#'   survey sampling. *Journal of the American Statistical Association*,
#'   87(418), 376--382.
#'
#'   Rao, J. N. K., Yung, W. and Hidiroglou, M. A. (2002). Estimating
#'   equations for the analysis of survey data using poststratification
#'   information. *Sankhya*, 64(2), 364--378.
#'
#'   Deville, J.-C., Sarndal, C.-E. and Sautory, O. (1993). Generalized
#'   raking procedures in survey sampling. *Journal of the American
#'   Statistical Association*, 88(423), 1013--1020.
#'
#'   Rao, J. N. K., Wu, C. F. J. and Yue, K. (1992). Some recent work on
#'   resampling methods for complex surveys. *Survey Methodology*,
#'   18(2), 209--217.
```

- [ ] **Step 7: Commit**

```bash
git add R/calibrate.R R/calibrate_rake.R R/calibrate_linear.R \
        R/calibrate_logit.R R/poststratify.R
git commit -m "docs(calibration): rewrite structural docs for Phase 1"
```

---

### Task 4: Phase 1 — Sample Calibration Family

**Files:** `R/calibrate_to_estimate.R`, `R/calibrate_to_survey.R`

**Branch:** `docs/phase-1-sample-calibration` (cut from `develop`)

**Tier:** Both are Tier 2 — Standard. Both already have `@returns` and `@references`.

- [ ] **Step 1: Create branch and read files**

```bash
git checkout develop
git checkout -b docs/phase-1-sample-calibration
```

- [ ] **Step 2: Edit `R/calibrate_to_estimate.R` — title and @seealso**

**2a. Title change:** "Calibrate replicate weights to externally supplied population estimates" → "Reweight to externally estimated population totals"

**2b. Add `@seealso`** before `@family sample-calibration`:

```r
#' @seealso [calibrate_to_survey()]
```

The existing `@returns` (already plural) and `@references` are compliant — keep them.

- [ ] **Step 3: Edit `R/calibrate_to_survey.R` — title and verify @seealso**

**3a. Title change:** "Calibrate replicate weights to a control survey" → "Reweight to population totals estimated from a control survey"

**3b. Verify `@seealso`:** The file currently ends with:
```r
#' @seealso [calibrate_to_estimate()] for calibration to externally supplied
#'   estimates with a known variance-covariance matrix.
```

Replace with the canonical form (no trailing description):

```r
#' @seealso [calibrate_to_estimate()]
```

The existing `@returns` and `@references` are compliant — keep them.

- [ ] **Step 4: Commit**

```bash
git add R/calibrate_to_estimate.R R/calibrate_to_survey.R
git commit -m "docs(sample-calibration): rewrite structural docs for Phase 1"
```

---

### Task 5: Phase 1 — Nonresponse Family

**Files:** `R/adjust_nonresponse.R`, `R/redistribute_weights.R`

**Branch:** `docs/phase-1-nonresponse` (cut from `develop`)

**Tier:** Both are Tier 2 — Standard.

- [ ] **Step 1: Create branch and read files**

```bash
git checkout develop
git checkout -b docs/phase-1-nonresponse
```

- [ ] **Step 2: Edit `R/adjust_nonresponse.R`**

**2a. Title change:** "Adjust survey weights for unit nonresponse" → "Correct weights for unit nonresponse"

**2b. Description:** The current description has a formula inline:

> "All rows (respondents and nonrespondents) are returned; nonrespondent weights are set to 0 and respondent weights are adjusted upward to conserve the total weight within each cell. The adjustment formula within each cell `h` is: \deqn{w_{i,new} = ...}"

Move the formula out of `@description` into a `@section Algorithm:` block. Rewrite `@description` to:

> "Redistributes the weights of nonrespondents to respondents within weighting classes defined by `by`. All rows are returned; nonrespondent weights are set to zero and respondent weights increase proportionally to preserve the total weight within each class."

Add after the `@param` block and before `@return`:

```r
#' @section Algorithm:
#' Within each cell \eqn{h} defined by `by`, the adjustment factor is
#' \deqn{f_h = \frac{\sum_{i \in h} w_i}{\sum_{i \in h, \text{resp}} w_i}}
#' where the numerator sums all weights in the cell and the denominator
#' sums respondent weights only. Each respondent weight becomes
#' \eqn{w_{i,new} = w_i \times f_h}. Nonrespondent weights are set to 0.
```

**2c. `@return` → `@returns`** (at line 62).

**2d. Verify `@seealso`:** Check whether `@seealso [redistribute_weights()]` is already present. If absent, add before `@family nonresponse`:

```r
#' @seealso [redistribute_weights()]
```

- [ ] **Step 3: Edit `R/redistribute_weights.R`**

**3a. Title change:** "Redistribute weights from one set of rows to another" → "Transfer weight from excluded rows to retained rows"

**3b. Description:** The current description has a formula inline similar to adjust_nonresponse. Move the formula to a `@section Algorithm:` block. Rewrite `@description` to:

> "Sets the weights of rows satisfying `reduce_if` to zero and proportionally redistributes their weight to rows satisfying `increase_if` within groups defined by `by`. Rows matching neither condition are unchanged."

Add `@section Algorithm:` after the `@param` block:

```r
#' @section Algorithm:
#' Within each group \eqn{h} defined by `by`, let \eqn{W_{R}} be the sum
#' of `reduce_if` weights and \eqn{W_{I}} be the sum of `increase_if`
#' weights. The adjusted weight for each `increase_if` row is
#' \deqn{w_{i,new} = w_i \times \frac{W_{R} + W_{I}}{W_{I}}.}
#' `reduce_if` rows have their weight set to 0. Rows matching neither
#' indicator are left unchanged.
```

**3c. `@return` → `@returns`** (at line 45).

**3d. Add `@seealso`** before `@family nonresponse`:

```r
#' @seealso [adjust_nonresponse()]
```

- [ ] **Step 4: Commit**

```bash
git add R/adjust_nonresponse.R R/redistribute_weights.R
git commit -m "docs(nonresponse): rewrite structural docs for Phase 1"
```

---

### Task 6: Phase 1 — Replicate Weights Family

**Files:** `R/create_bootstrap_weights.R`, `R/create_brr_weights.R`,
`R/create_gen_boot_weights.R`, `R/create_gen_rep_weights.R`,
`R/create_sdr_weights.R`, `R/as_taylor_design.R`, `R/create_replicate_weights.R`

**Branch:** `docs/phase-1-replicate-weights` (cut from `develop`)

**Tiers:** `create_bootstrap_weights`, `create_brr_weights`, `create_gen_boot_weights`,
`create_gen_rep_weights`, `create_sdr_weights` are Tier 3. `as_taylor_design` is Tier 1.
`create_replicate_weights` is Tier 4 (dispatcher) — but `@details` and `@references` are
DEFERRED; add `@seealso` only.

The full `@seealso` block for every replicate-weights function:

```r
#' @seealso [create_bootstrap_weights()], [create_jackknife_weights()],
#'   [create_group_jackknife_weights()], [create_brr_weights()],
#'   [create_gen_boot_weights()], [create_gen_rep_weights()],
#'   [create_sdr_weights()], [create_replicate_weights()], [as_taylor_design()]
```

(Every function gets this full block minus itself. See specific edits below.)

- [ ] **Step 1: Create branch and read all 7 files**

```bash
git checkout develop
git checkout -b docs/phase-1-replicate-weights
```

- [ ] **Step 2: Edit `R/create_bootstrap_weights.R`**

**2a. Title change:** "Create bootstrap replicate weights" → "Generate bootstrap replicate weights"

**2b. `@return` → `@returns`** (the `@return` block starting around line 51).

**2c. Replace the existing `@details` block with `@section Algorithm:` followed by `@section Limitations:`.** The existing `@details` (SRSWR understatement note) belongs in `@section Limitations:` per the canonical section list in `function-documentation.md`. Delete `@details` and write both named sections in its place:

```r
#' @section Algorithm:
#' For probability-sample designs (`survey_taylor`), delegates to
#' [svrep::as_bootstrap_design()] with the specified `type`. The variance
#' estimator for resampling type `"Rao-Wu-Yue-Beaumont"` is:
#' \deqn{\hat{V}_{boot} = \frac{1}{B} \sum_{b=1}^{B}
#'   (\hat{\theta}^{(b)} - \hat{\theta})^2}
#' when `mse = "mse"`, with `B = replicates`.
#'
#' For non-probability samples (`type = "quasi-randomization"`), each
#' bootstrap replicate resamples respondents with replacement (SRSWR),
#' then re-runs the original IPW fitting on the resampled data, producing
#' replicate weights that reflect the variability of the propensity
#' estimation step.
#'
#' @section Limitations:
#' Bootstrap standard errors from `type = "quasi-randomization"` likely
#' understate true sampling variability because SRSWR resampling cannot
#' replicate the original NPS recruitment mechanism (AAPOR 2022, §4). This
#' understatement is not reduced by increasing `replicates`.
```

**2d. Add `@seealso`** before `@family replicate-weights`:

```r
#' @seealso [create_jackknife_weights()], [create_group_jackknife_weights()],
#'   [create_brr_weights()], [create_gen_boot_weights()],
#'   [create_gen_rep_weights()], [create_sdr_weights()],
#'   [create_replicate_weights()], [as_taylor_design()]
```

Keep existing `@references` (4 papers — already match reference map).

- [ ] **Step 3: Edit `R/create_brr_weights.R`**

**3a. Title change:** "Create BRR (Fay) replicate weights" → "Generate BRR (Fay) replicate weights"

**3b. `@return` → `@returns`**.

**3c. Expand `@param rho`** to include the full Fay description — the current doc is brief ("Fay damping coefficient. `rho = 0` gives standard BRR..."). Keep it, but verify it explains `0 <= rho < 1`.

**3d. Add `@section Algorithm:`** before `@family replicate-weights`:

```r
#' @section Algorithm:
#' BRR creates \eqn{R} half-sample replicates from a paired-PSU design
#' (exactly 2 PSUs per stratum). A Hadamard matrix of order \eqn{R}
#' determines which PSU in each stratum belongs to each half-sample.
#' Within replicate \eqn{r}, PSU 1 receives weight \eqn{2(1-\rho)} and
#' PSU 2 receives weight \eqn{2\rho} (or vice versa). The BRR variance
#' estimator is:
#' \deqn{\hat{V}_{BRR} = \frac{1}{R(1-\rho)^2}
#'   \sum_{r=1}^{R} (\hat{\theta}^{(r)} - \hat{\theta})^2.}
#' When `rho = 0`, this simplifies to standard BRR. The Fay variant
#' (`rho > 0`) reduces variance instability from extreme replicate
#' estimates.
```

**3e. Add `@references`** before `@family replicate-weights`:

```r
#' @references
#'   Fay, R.E. (1984). Some properties of estimates of variance based on
#'   replication methods. *Proceedings of the American Statistical
#'   Association*, 495--500.
#'
#'   Fay, R.E. (1989). Theory and application of replicate weighting for
#'   variance calculations. *Proceedings of the American Statistical
#'   Association*, 495--500.
#'
#'   Dippo, C., Fay, R.E. and Morganstein, D. (1984). Computing variances
#'   from complex samples with replicate weights. *Proceedings of the
#'   American Statistical Association*, 489--494.
```

**3f. Add `@seealso`**:

```r
#' @seealso [create_bootstrap_weights()], [create_jackknife_weights()],
#'   [create_group_jackknife_weights()], [create_gen_boot_weights()],
#'   [create_gen_rep_weights()], [create_sdr_weights()],
#'   [create_replicate_weights()], [as_taylor_design()]
```

- [ ] **Step 4: Edit `R/create_gen_boot_weights.R`**

Read the file first, then:

**4a. Title change:** current title → "Generate generalized bootstrap replicate weights"

**4b. `@return` → `@returns`**.

**4c. Add `@section Algorithm:`** before `@family replicate-weights`:

```r
#' @section Algorithm:
#' The generalized bootstrap (Beaumont & Patak, 2012) generates replicate
#' weights using unit-level random multipliers:
#' \deqn{w_k^{(r)} = w_k \cdot u_k^{(r)}}
#' where \eqn{u_k^{(r)}} are drawn from a distribution calibrated to the
#' design's first-order inclusion probabilities. Unlike SRSWR bootstrap,
#' the multipliers are chosen to satisfy \eqn{E[u_k] = 1} and
#' \eqn{Var(u_k) = (1 - \pi_k) / \pi_k}. Delegates to
#' [svrep::as_gen_boot_design()].
```

**4d. Verify or add `@references`** (should have 4 papers: Beaumont & Patak 2012, Fay 1984, Dippo et al. 1984, Bellhouse 1985). If the block is missing or incomplete, use:

```r
#' @references
#'   Beaumont, J.-F. and Patak, Z. (2012). On the generalized bootstrap for
#'   sample surveys with special attention to Poisson sampling.
#'   *International Statistical Review*, 80(1), 127--148.
#'
#'   Fay, R.E. (1984). Some properties of estimates of variance based on
#'   replication methods. *Proceedings of the American Statistical
#'   Association*, 495--500.
#'
#'   Dippo, C., Fay, R.E. and Morganstein, D. (1984). Computing variances
#'   from complex samples with replicate weights. *Proceedings of the
#'   American Statistical Association*, 489--494.
#'
#'   Bellhouse, D.R. (1985). Computing methods for variance estimation in
#'   complex surveys. *Journal of Official Statistics*, 1(3).
```

**4e. Add `@seealso`**:

```r
#' @seealso [create_bootstrap_weights()], [create_jackknife_weights()],
#'   [create_group_jackknife_weights()], [create_brr_weights()],
#'   [create_gen_rep_weights()], [create_sdr_weights()],
#'   [create_replicate_weights()], [as_taylor_design()]
```

- [ ] **Step 5: Edit `R/create_gen_rep_weights.R`**

Read the file first, then:

**5a. Title change:** current title → "Generate generalized replication replicate weights"

**5b. `@return` → `@returns`**.

**5c. Add `@section Algorithm:`** before `@family`:

```r
#' @section Algorithm:
#' Generalized replication (GR) is a BRR extension that removes the
#' requirement for exactly 2 PSUs per stratum. It constructs
#' \eqn{R \geq H} replicates (where \eqn{H} is the number of strata)
#' using a generalized Hadamard matrix, assigning each stratum-PSU unit a
#' weight that satisfies the BRR variance formula
#' \deqn{\hat{V}_{GR} = \frac{1}{R} \sum_{r=1}^{R}
#'   (\hat{\theta}^{(r)} - \hat{\theta})^2.}
#' Delegates to [svrep::as_gen_rep_design()].
```

**5d. Verify or add `@references`** (3 papers: Fay 1984, Fay 1989, Dippo et al. 1984):

```r
#' @references
#'   Fay, R.E. (1984). Some properties of estimates of variance based on
#'   replication methods. *Proceedings of the American Statistical
#'   Association*, 495--500.
#'
#'   Fay, R.E. (1989). Theory and application of replicate weighting for
#'   variance calculations. *Proceedings of the American Statistical
#'   Association*, 495--500.
#'
#'   Dippo, C., Fay, R.E. and Morganstein, D. (1984). Computing variances
#'   from complex samples with replicate weights. *Proceedings of the
#'   American Statistical Association*, 489--494.
```

**5e. Add `@seealso`**:

```r
#' @seealso [create_bootstrap_weights()], [create_jackknife_weights()],
#'   [create_group_jackknife_weights()], [create_brr_weights()],
#'   [create_gen_boot_weights()], [create_sdr_weights()],
#'   [create_replicate_weights()], [as_taylor_design()]
```

- [ ] **Step 6: Edit `R/create_sdr_weights.R`**

**6a. Title change:** "Create successive difference replication (SDR) weights" → "Generate successive difference replication weights"

**6b. `@return` → `@returns`**.

**6c. Add `@section Algorithm:`** before `@family`:

```r
#' @section Algorithm:
#' Successive difference replication (SDR) pairs adjacent PSUs in
#' systematic selection order. A Hadamard matrix of order \eqn{R} assigns
#' each pair to a half-sample. The SDR variance estimator is:
#' \deqn{\hat{V}_{SDR} = \frac{1}{2R} \sum_{r=1}^{R}
#'   (\hat{\theta}^{(r)} - \hat{\theta}_{\text{full}})^2.}
#' This estimator matches the variance of a systematic random sample when
#' PSUs are in selection order (Ash, 2014; Fay & Train, 1995). Delegates
#' to [svrep::as_sdr_design()].
```

**6d. Add `@references`** before `@family`:

```r
#' @references
#'   Ash, S. (2014). Using successive difference replication for
#'   estimating variances. *Survey Methodology, Statistics Canada*,
#'   40(1), 47--59.
#'
#'   Fay, R.E. and Train, G.F. (1995). Aspects of survey and model-based
#'   postcensal estimation of income and poverty characteristics for
#'   states and counties. *Joint Statistical Meetings, Proceedings of
#'   the Section on Government Statistics*, 154--159.
```

**6e. Add `@seealso`**:

```r
#' @seealso [create_bootstrap_weights()], [create_jackknife_weights()],
#'   [create_group_jackknife_weights()], [create_brr_weights()],
#'   [create_gen_boot_weights()], [create_gen_rep_weights()],
#'   [create_replicate_weights()], [as_taylor_design()]
```

- [ ] **Step 7: Edit `R/as_taylor_design.R`**

**7a. Title:** "Convert a replicate design back to a Taylor design" — already correct per the design doc. No change.

**7b. `@return` → `@returns`** (at line 24).

**7c. Add `@seealso`** before `@family replicate-weights`:

```r
#' @seealso [create_bootstrap_weights()], [create_jackknife_weights()],
#'   [create_group_jackknife_weights()], [create_brr_weights()],
#'   [create_gen_boot_weights()], [create_gen_rep_weights()],
#'   [create_sdr_weights()], [create_replicate_weights()]
```

- [ ] **Step 8: Edit `R/create_replicate_weights.R`**

**8a. Title change:** "Create replicate weights (dispatcher)" → "Generate replicate weights for a survey design"

**8b. `@returns`:** Already has `@returns` ✅. No change.

**8c. Update `@seealso`:** The current block links `create_bootstrap_weights`, `create_jackknife_weights`, `create_brr_weights`, `create_gen_boot_weights`, `create_gen_rep_weights`, `create_sdr_weights`. Add `create_group_jackknife_weights` and `as_taylor_design`:

```r
#' @seealso [create_bootstrap_weights()], [create_jackknife_weights()],
#'   [create_group_jackknife_weights()], [create_brr_weights()],
#'   [create_gen_boot_weights()], [create_gen_rep_weights()],
#'   [create_sdr_weights()], [as_taylor_design()]
```

Do NOT add `@details` or `@references` — those are deferred.

- [ ] **Step 9: Commit**

```bash
git add R/create_bootstrap_weights.R R/create_brr_weights.R \
        R/create_gen_boot_weights.R R/create_gen_rep_weights.R \
        R/create_sdr_weights.R R/as_taylor_design.R \
        R/create_replicate_weights.R
git commit -m "docs(replicate-weights): rewrite structural docs for Phase 1"
```

---

### Task 7: Phase 1 — Propensity Family

**Files:** `R/ipw.R`

**Branch:** `docs/phase-1-propensity` (cut from `develop`)

**Tier:** Tier 3 — Algorithmic. Already has `@section Algorithm:`, `@details`, `@references`, and `@seealso`. Changes: title consolidation, `@return` → `@returns`, add `[summarize_weights()]` to `@seealso`.

- [ ] **Step 1: Create branch and read file**

```bash
git checkout develop
git checkout -b docs/phase-1-propensity
```

- [ ] **Step 2: Consolidate title and remove redundant tags**

The current file has a non-standard double-title structure:

```r
#' Inverse probability weighting for non-probability samples
#'
#' @title Inverse Probability Weighting (IPW) for Non-Probability Samples
#'
#' @description
#' Constructs inverse probability weights...
```

Replace with the standard implicit form:

```r
#' Estimate inverse probability weights for a non-probability sample
#'
#' Constructs inverse probability weights for a non-probability sample (NPS)
#' by estimating participation propensity via pseudo-likelihood logistic
#' regression. The weights adjust for selection bias by upweighting NPS units
#' that are underrepresented relative to a probability-based reference sample.
#'
```

(Remove the `@title` and `@description` tags; keep the description text as the second paragraph.)

- [ ] **Step 3: Change `@return` → `@returns`**

Find the `@return A \`survey_nonprob\` object...` line and change `@return` to `@returns`.

- [ ] **Step 4: Insert `[summarize_weights()]` into the existing `@seealso` block**

Do NOT replace the full block — only insert. Add the `[summarize_weights()]` entry between the
`[calibrate_to_survey()]` entry and the `diagnose_propensity()` entry, preserving the existing
`diagnose_propensity()` sentence about `propensity_scores`:

```r
#'   [summarize_weights()] for diagnosing the distribution of the IPW weights
#'   produced by this function.
#'
```

Insert this immediately before the line:

```r
#'   `diagnose_propensity()` (planned) for propensity score diagnostics
```

The result should be:

```r
#' @seealso
#'   [adjust_nonresponse()] for unit nonresponse adjustment via weighting
#'   class methods, which can serve as the IPW step in a doubly robust pipeline
#'   when the nonresponse mechanism is modeled.
#'
#'   [calibrate_to_survey()] for post-stratification and raking calibration
#'   that can be applied after `ipw()` as the regression correction step of a
#'   doubly robust estimator.
#'
#'   [summarize_weights()] for diagnosing the distribution of the IPW weights
#'   produced by this function.
#'
#'   `diagnose_propensity()` (planned) for propensity score diagnostics
#'   including AUC, covariate balance plots, and standardized mean differences.
#'   Uses the `propensity_scores` stored in the history entry returned by
#'   `ipw()` without refitting the model.
```

- [ ] **Step 5: Commit**

```bash
git add R/ipw.R
git commit -m "docs(propensity): rewrite structural docs for Phase 1"
```

---

### Task 8: Phase 1 Verification and PR

**Prerequisite:** Tasks 1–7 are complete and committed on their respective branches.

- [ ] **Step 1: Create merge target branch**

```bash
git checkout develop
git checkout -b docs/phase-1-structural
```

- [ ] **Step 2: Merge all 7 family branches**

```bash
git merge --no-ff docs/phase-1-diagnostics
git merge --no-ff docs/phase-1-utilities
git merge --no-ff docs/phase-1-calibration
git merge --no-ff docs/phase-1-sample-calibration
git merge --no-ff docs/phase-1-nonresponse
git merge --no-ff docs/phase-1-replicate-weights
git merge --no-ff docs/phase-1-propensity
```

Resolve any merge conflicts (unlikely since each task touches different files).

- [ ] **Step 3: Run `devtools::document()`**

In R:
```r
devtools::document()
```

Expected: 0 errors, 0 warnings. The `NAMESPACE` file and `man/` `.Rd` files are updated.

- [ ] **Step 4: Run `devtools::check()`**

```r
devtools::check()
```

Expected: 0 errors, 0 warnings, ≤2 pre-approved notes (NSE binding, CRAN feasibility).

If errors occur, diagnose and fix in the `docs/phase-1-structural` branch, then re-run.

- [ ] **Step 5: Commit documentation artifacts**

```bash
git add NAMESPACE man/
git commit -m "docs(phase-1): run devtools::document() after structural rewrites"
```

- [ ] **Step 6: Open PR to `develop`**

```bash
gh pr create \
  --base develop \
  --head docs/phase-1-structural \
  --title "docs: Phase 1 structural documentation rewrite (22 functions)" \
  --body "$(cat <<'EOF'
## Summary

- Rewrites titles, descriptions, @returns, @seealso, @references, and @section blocks for all 22 in-scope exported functions across 7 families
- Adds pre-approved @details to calibrate() (Tier 4 requirement)
- Adds @section Algorithm: and @section Convergence: to all Tier 3 functions missing them
- Fixes calibrate_rake() @references (replaces Chang & Kott 2008 with Kott 2003 per reference map)
- Consolidates ipw() non-standard @title/@description tags into standard form
- Zero behavioral changes — documentation only

## Test plan

- [ ] devtools::check() passes with 0 errors, 0 warnings
- [ ] All 22 function help pages render correctly via ?fn_name
EOF
)"
```

---

## Phase 2 — Examples (Tasks 9–15 are sequential)

### Phase 2 branch strategy

All Phase 2 work lives on `docs/phase-2-examples` (cut from `develop` after Phase 1 PR merges).

```bash
git checkout develop  # after Phase 1 PR is merged
git checkout -b docs/phase-2-examples
```

No DESCRIPTION changes are needed before Task 9. `surveytidy` is NOT added to Suggests — the nonresponse examples use `surveycore::as_survey()` to construct survey objects from a pre-mutated data frame instead.

---

### Task 9: Phase 2 — Diagnostics Examples

**Functions:** `effective_sample_size`, `weight_variability`, `summarize_weights`

**Datasets:** `ns_wave1` (data.frame; weight column = `weight`, sex column = `sex`), `ns_wave1_svy` (survey_nonprob)

**Section header format:** `# Brief scenario label ---------------------------`

- [ ] **Step 1: Read current @examples in all three files**

- [ ] **Step 2: Replace `@examples` in `R/effective_sample_size.R`**

```r
#' @examples
#' # data.frame with explicit weight column ---------------------------------
#' effective_sample_size(ns_wave1, weights = weight)
#'
#' # survey_nonprob — weight column auto-detected ---------------------------
#' effective_sample_size(ns_wave1_svy)
```

- [ ] **Step 3: Replace `@examples` in `R/weight_variability.R`**

```r
#' @examples
#' # data.frame with explicit weight column ---------------------------------
#' weight_variability(ns_wave1, weights = weight)
#'
#' # survey_nonprob — weight column auto-detected ---------------------------
#' weight_variability(ns_wave1_svy)
```

- [ ] **Step 4: Replace `@examples` in `R/summarize_weights.R`**

```r
#' @examples
#' # overall summary --------------------------------------------------------
#' summarize_weights(ns_wave1, weights = weight)
#'
#' # grouped by sex ---------------------------------------------------------
#' summarize_weights(ns_wave1, weights = weight, by = sex)
#'
#' # survey_nonprob — weight column auto-detected ---------------------------
#' summarize_weights(ns_wave1_svy)
```

- [ ] **Step 5: Verify examples run**

```r
devtools::run_examples(package = "surveywts", filter = "^(effective_sample_size|weight_variability|summarize_weights)$")
```

Expected: 0 errors, 0 warnings. If any example fails, fix the data column references before proceeding.

- [ ] **Step 6: Commit**

```bash
git add R/effective_sample_size.R R/weight_variability.R R/summarize_weights.R
git commit -m "docs(diagnostics): replace examples with package-data scenarios"
```

---

### Task 10: Phase 2 — Utilities Examples

**Functions:** `trim_weights`, `stabilize_weights`

**Datasets:** `ns_wave1` (weight = `weight`, sex = `sex`), `ns_wave1_svy`, `acs_wy_2022_svy` (survey_replicate)

- [ ] **Step 1: Read current @examples in both files**

- [ ] **Step 2: Replace `@examples` in `R/trim_weights.R`**

```r
#' @examples
#' # IQR default (k = 5) ---------------------------------------------------
#' trim_weights(ns_wave1, weights = weight)
#'
#' # explicit percentile bounds --------------------------------------------
#' trim_weights(
#'   ns_wave1,
#'   weights = weight,
#'   lower = 0.05,
#'   upper = 0.95,
#'   type = "percentile"
#' )
#'
#' # absolute bounds -------------------------------------------------------
#' trim_weights(
#'   ns_wave1,
#'   weights = weight,
#'   lower = 0.3,
#'   upper = 3.0,
#'   type = "absolute"
#' )
#'
#' # survey_replicate — bounds auto-applied to all replicate columns -------
#' trim_weights(acs_wy_2022_svy)
```

- [ ] **Step 3: Replace `@examples` in `R/stabilize_weights.R`**

```r
#' @examples
#' # data.frame with explicit weight column ---------------------------------
#' stabilize_weights(ns_wave1, weights = weight)
#'
#' # grouped by sex — each group sums to its own n_h -----------------------
#' stabilize_weights(ns_wave1, weights = weight, by = sex)
#'
#' # survey_nonprob — weight column auto-detected ---------------------------
#' stabilize_weights(ns_wave1_svy)
```

- [ ] **Step 4: Verify examples run**

```r
devtools::run_examples(package = "surveywts", filter = "^(trim_weights|stabilize_weights)$")
```

Expected: 0 errors, 0 warnings.

- [ ] **Step 5: Commit**

```bash
git add R/trim_weights.R R/stabilize_weights.R
git commit -m "docs(utilities): replace examples with package-data scenarios"
```

---

### Task 11: Phase 2 — Calibration Examples

**Functions:** `calibrate`, `calibrate_rake`, `calibrate_linear`, `calibrate_logit`, `poststratify`

**Datasets:** `ns_wave1` (weight = `weight`, sex = `sex` [Factor: "Male"/"Female"], age = `age_f3` [Factor: "18-34"/"35-54"/"55+"]); `ns_wave1_svy` (survey_nonprob)

**Approved population margins:**
```r
targets_a <- list(
  sex   = c("Male" = 0.49, "Female" = 0.51),
  age_f3 = c("18-34" = 0.30, "35-54" = 0.33, "55+" = 0.37)
)
targets_b <- data.frame(
  variable = c("sex", "sex", "age_f3", "age_f3", "age_f3"),
  level    = c("Male", "Female", "18-34", "35-54", "55+"),
  target   = c(0.49, 0.51, 0.30, 0.33, 0.37)
)
```

- [ ] **Step 1: Read current @examples in all 5 files**

- [ ] **Step 2: Replace `@examples` in `R/calibrate.R`**

```r
#' @examples
#' targets_a <- list(
#'   sex   = c("Male" = 0.49, "Female" = 0.51),
#'   age_f3 = c("18-34" = 0.30, "35-54" = 0.33, "55+" = 0.37)
#' )
#'
#' # Format A + rake (default) ---------------------------------------------
#' calibrate(ns_wave1, targets = targets_a, weights = weight)
#'
#' # Format A + linear -----------------------------------------------------
#' calibrate(ns_wave1, targets = targets_a, weights = weight, method = "linear")
#'
#' # Format A + logit ------------------------------------------------------
#' calibrate(ns_wave1, targets = targets_a, weights = weight, method = "logit")
#'
#' # Format B + rake -------------------------------------------------------
#' targets_b <- data.frame(
#'   variable = c("sex", "sex", "age_f3", "age_f3", "age_f3"),
#'   level    = c("Male", "Female", "18-34", "35-54", "55+"),
#'   target   = c(0.49, 0.51, 0.30, 0.33, 0.37)
#' )
#' calibrate(ns_wave1, targets = targets_b, weights = weight)
```

- [ ] **Step 3: Replace `@examples` in `R/calibrate_rake.R`**

```r
#' @examples
#' targets_a <- list(
#'   sex   = c("Male" = 0.49, "Female" = 0.51),
#'   age_f3 = c("18-34" = 0.30, "35-54" = 0.33, "55+" = 0.37)
#' )
#'
#' # Format A + classic_ipf (default) --------------------------------------
#' calibrate_rake(ns_wave1, targets = targets_a, weights = weight)
#'
#' # Format A + Newton-Raphson algorithm -----------------------------------
#' calibrate_rake(
#'   ns_wave1, targets = targets_a, weights = weight, algorithm = "nr"
#' )
#'
#' # survey_nonprob — weight column auto-detected ---------------------------
#' calibrate_rake(ns_wave1_svy, targets = targets_a)
#'
#' # Format B --------------------------------------------------------------
#' targets_b <- data.frame(
#'   variable = c("sex", "sex", "age_f3", "age_f3", "age_f3"),
#'   level    = c("Male", "Female", "18-34", "35-54", "55+"),
#'   target   = c(0.49, 0.51, 0.30, 0.33, 0.37)
#' )
#' calibrate_rake(ns_wave1, targets = targets_b, weights = weight)
```

- [ ] **Step 4: Replace `@examples` in `R/calibrate_linear.R`**

```r
#' @examples
#' targets_a <- list(
#'   sex   = c("Male" = 0.49, "Female" = 0.51),
#'   age_f3 = c("18-34" = 0.30, "35-54" = 0.33, "55+" = 0.37)
#' )
#'
#' # Format A + data.frame -------------------------------------------------
#' calibrate_linear(ns_wave1, targets = targets_a, weights = weight)
#'
#' # survey_nonprob — weight column auto-detected ---------------------------
#' calibrate_linear(ns_wave1_svy, targets = targets_a)
#'
#' # Format B --------------------------------------------------------------
#' targets_b <- data.frame(
#'   variable = c("sex", "sex", "age_f3", "age_f3", "age_f3"),
#'   level    = c("Male", "Female", "18-34", "35-54", "55+"),
#'   target   = c(0.49, 0.51, 0.30, 0.33, 0.37)
#' )
#' calibrate_linear(ns_wave1, targets = targets_b, weights = weight)
```

- [ ] **Step 5: Replace `@examples` in `R/calibrate_logit.R`**

```r
#' @examples
#' targets_a <- list(
#'   sex   = c("Male" = 0.49, "Female" = 0.51),
#'   age_f3 = c("18-34" = 0.30, "35-54" = 0.33, "55+" = 0.37)
#' )
#'
#' # Format A + data.frame -------------------------------------------------
#' calibrate_logit(ns_wave1, targets = targets_a, weights = weight)
#'
#' # survey_nonprob — weight column auto-detected ---------------------------
#' calibrate_logit(ns_wave1_svy, targets = targets_a)
#'
#' # Format B --------------------------------------------------------------
#' targets_b <- data.frame(
#'   variable = c("sex", "sex", "age_f3", "age_f3", "age_f3"),
#'   level    = c("Male", "Female", "18-34", "35-54", "55+"),
#'   target   = c(0.49, 0.51, 0.30, 0.33, 0.37)
#' )
#' calibrate_logit(ns_wave1, targets = targets_b, weights = weight)
```

- [ ] **Step 6: Replace `@examples` in `R/poststratify.R`**

Post-stratify requires a data frame `targets`. The 6 sex × age_f3 cells use cross-products of the approved margins (sex × age_f3, each cell = sex_prop × age_prop, sum = 1.000):

```r
#' @examples
#' # joint cell proportions (sex x age_f3, 6 cells, sum = 1.000) ----------
#' ps_cells <- data.frame(
#'   sex    = rep(c("Male", "Female"), each = 3),
#'   age_f3 = rep(c("18-34", "35-54", "55+"), times = 2),
#'   target = c(0.1470, 0.1617, 0.1813, 0.1530, 0.1683, 0.1887)
#' )
#' poststratify(ns_wave1, targets = ps_cells, weights = weight)
#'
#' # survey_nonprob — weight column auto-detected ---------------------------
#' poststratify(ns_wave1_svy, targets = ps_cells)
#'
#' # type = "count" with US adult population counts (260 million) ----------
#' ps_counts <- data.frame(
#'   sex    = rep(c("Male", "Female"), each = 3),
#'   age_f3 = rep(c("18-34", "35-54", "55+"), times = 2),
#'   target = c(0.1470, 0.1617, 0.1813, 0.1530, 0.1683, 0.1887) * 260000000
#' )
#' poststratify(
#'   ns_wave1, targets = ps_counts, weights = weight, type = "count"
#' )
```

- [ ] **Step 7: Verify all 5 calibration functions run**

```r
devtools::run_examples(
  package = "surveywts",
  filter = "^(calibrate|calibrate_rake|calibrate_linear|calibrate_logit|poststratify)$"
)
```

Expected: 0 errors, 0 warnings.

- [ ] **Step 8: Commit**

```bash
git add R/calibrate.R R/calibrate_rake.R R/calibrate_linear.R \
        R/calibrate_logit.R R/poststratify.R
git commit -m "docs(calibration): replace examples with package-data scenarios"
```

---

### Task 12: Phase 2 — Sample Calibration Examples

**Functions:** `calibrate_to_estimate`, `calibrate_to_survey`

**Datasets:** `gss_2024` (tibble; weight = `wt_pop`, strata = `vstrat`, ids = `vpsu`),
`npors_2025_clean` (tibble; weight = `wt_pop`, strata = `stratum`),
`pew_2016_optin_svy` (survey_nonprob with 200 replicate columns),
`npors_2025_clean_svy` (survey_taylor)

- [ ] **Step 1: Read current @examples in both files**

- [ ] **Step 2: Replace `@examples` in `R/calibrate_to_estimate.R`**

The current example uses `data(api, package = "survey")` which violates the package-data rule. Replace with the approved code (this has been verified to run clean):

```r
#' @examples
#' # calibrate GSS 2024 pid_f3 to NPORS population estimates ---------------
#'
#' # build primary replicate design from GSS (JKn on complete pid_f3 rows)
#' gss_pop <- surveycore::as_survey(
#'   gss_2024[!is.na(gss_2024$pid_f3), ],
#'   weights = wt_pop,
#'   strata  = vstrat,
#'   ids     = vpsu,
#'   nest    = TRUE
#' ) |>
#'   create_jackknife_weights(type = "jkn")
#'
#' # build NPORS control design (must use survey pkg for svytotal/coef/vcov)
#' npors_pop <- survey::svydesign(
#'   ids     = ~1,
#'   strata  = ~stratum,
#'   weights = ~wt_pop,
#'   data    = npors_2025_clean
#' ) |>
#'   survey::as.svrepdesign(type = "JKn")
#'
#' # derive targets from control survey
#' pid_f3_est    <- survey::svytotal(~pid_f3, npors_pop)
#' pid_f3_totals <- setNames(coef(pid_f3_est), levels(npors_2025_clean$pid_f3))
#' vcov_pid_f3   <- vcov(pid_f3_est)
#'
#' result <- calibrate_to_estimate(
#'   gss_pop,
#'   targets       = list(pid_f3 = pid_f3_totals),
#'   vcov_estimate = vcov_pid_f3
#' )
```

Note: `library(survey)` is not needed because `survey::` calls are used. R CMD check runs examples with only `library(surveywts)` loaded; `survey` is in `Imports` so it is available via `::`.

- [ ] **Step 3: Replace `@examples` in `R/calibrate_to_survey.R`**

The current example constructs a synthetic control from `acs_wy_2022`. Replace with the approved NPS scenario (runs in ~2 seconds):

```r
#' @examples
#' # calibrate pew NPS to NPORS control survey on age_f3 and pid_f3 -------
#' control <- create_bootstrap_weights(
#'   npors_2025_clean_svy,
#'   replicates = 50L
#' )
#' result <- calibrate_to_survey(
#'   pew_2016_optin_svy,
#'   control,
#'   variables = c(age_f3, pid_f3)
#' )
```

- [ ] **Step 4: Verify examples run**

```r
devtools::run_examples(
  package = "surveywts",
  filter = "^(calibrate_to_estimate|calibrate_to_survey)$"
)
```

Expected: 0 errors, 0 warnings. `calibrate_to_estimate` uses JKn on a 3,309-row GSS subset and is fast. `calibrate_to_survey` runs in ~2 seconds.

- [ ] **Step 5: Commit**

```bash
git add R/calibrate_to_estimate.R R/calibrate_to_survey.R
git commit -m "docs(sample-calibration): replace examples with package-data scenarios"
```

---

### Task 13: Phase 2 — Nonresponse Examples

**Functions:** `adjust_nonresponse`, `redistribute_weights`

**Datasets:** `gss_2024` (tibble; weight = `wtssps`, sex = `sex`); `gss_2024_svy` (survey_taylor using `wtssps`)

**Key rule:** No `set.seed()` in examples (following `svrep` convention).

**Key rule:** For the survey_taylor path, add the response status column to the underlying tibble first, then construct the survey object with `surveycore::as_survey()`. Do NOT use direct `@data` slot assignment or `surveytidy::mutate()` — this avoids a Suggests dependency while preserving the S7 class invariants.

- [ ] **Step 1: Read current @examples in both files**

- [ ] **Step 2: Replace `@examples` in `R/adjust_nonresponse.R`**

```r
#' @examples
#' # data.frame path: add response_status column ---------------------------
#' gss <- gss_2024
#' gss$responded <- sample(
#'   c(0L, 1L), nrow(gss), replace = TRUE, prob = c(0.2, 0.8)
#' )
#' result <- adjust_nonresponse(
#'   gss, response_status = responded, weights = wtssps, by = sex
#' )
#'
#' # survey_taylor path: mutate the tibble first, then construct the design --
#' gss_with_resp <- gss_2024
#' gss_with_resp$responded <- sample(
#'   c(0L, 1L), nrow(gss_with_resp), replace = TRUE, prob = c(0.2, 0.8)
#' )
#' gss_svy <- surveycore::as_survey(
#'   gss_with_resp, weights = wtssps, strata = vstrat, ids = vpsu, nest = TRUE
#' )
#' result <- adjust_nonresponse(gss_svy, response_status = responded, by = sex)
```

- [ ] **Step 3: Replace `@examples` in `R/redistribute_weights.R`**

```r
#' @examples
#' # data.frame path: add reduce_if and increase_if columns ----------------
#' gss <- gss_2024
#' gss$excluded <- sample(
#'   c(0L, 1L), nrow(gss), replace = TRUE, prob = c(0.8, 0.2)
#' )
#' gss$retained <- as.integer(!gss$excluded)
#' result <- redistribute_weights(
#'   gss,
#'   reduce_if   = excluded,
#'   increase_if = retained,
#'   weights     = wtssps,
#'   by          = sex
#' )
#'
#' # survey_taylor path: mutate the tibble first, then construct the design --
#' gss_excl <- gss_2024
#' gss_excl$excluded <- sample(
#'   c(0L, 1L), nrow(gss_excl), replace = TRUE, prob = c(0.8, 0.2)
#' )
#' gss_excl$retained <- as.integer(!gss_excl$excluded)
#' gss_svy <- surveycore::as_survey(
#'   gss_excl, weights = wtssps, strata = vstrat, ids = vpsu, nest = TRUE
#' )
#' result <- redistribute_weights(
#'   gss_svy, reduce_if = excluded, increase_if = retained, by = sex
#' )
```

- [ ] **Step 4: Verify examples run**

```r
devtools::run_examples(
  package = "surveywts",
  filter = "^(adjust_nonresponse|redistribute_weights)$"
)
```

Expected: 0 errors, 0 warnings. The `sample()` calls will produce different random values on each run — that is correct and expected (no `set.seed()`).

- [ ] **Step 5: Commit**

```bash
git add R/adjust_nonresponse.R R/redistribute_weights.R
git commit -m "docs(nonresponse): replace examples with package-data scenarios"
```

---

### Task 14: Phase 2 — Replicate Weights Examples

**Functions:** `create_bootstrap_weights`, `create_brr_weights`, `create_gen_boot_weights`, `create_gen_rep_weights`, `create_sdr_weights`, `create_replicate_weights`, `as_taylor_design`

**Datasets:** `gss_2024_svy` (survey_taylor; 67 strata × 2 PSUs — required for BRR), `ns_wave1_svy` (survey_nonprob), `acs_wy_2022_svy` (survey_replicate with SDR weights)

- [ ] **Step 1: Read current @examples in all 7 files**

- [ ] **Step 2: Replace `@examples` in `R/create_bootstrap_weights.R`**

```r
#' @examples
#' # default SRSWR bootstrap on a probability survey -----------------------
#' create_bootstrap_weights(gss_2024_svy)
#'
#' # quasi-randomization bootstrap for a non-probability sample -----------
#' create_bootstrap_weights(
#'   ns_wave1_svy,
#'   type       = "quasi-randomization",
#'   replicates = 200L
#' )
```

- [ ] **Step 3: Replace `@examples` in `R/create_brr_weights.R`**

```r
#' @examples
#' # standard BRR (gss_2024_svy has 67 strata x 2 PSUs) ------------------
#' create_brr_weights(gss_2024_svy)
#'
#' # Fay's BRR with damping coefficient -----------------------------------
#' create_brr_weights(gss_2024_svy, rho = 0.5)
```

- [ ] **Step 4: Replace `@examples` in `R/create_gen_boot_weights.R`**

```r
#' @examples
#' # generalized bootstrap with reproducible seed -------------------------
#' create_gen_boot_weights(gss_2024_svy, seed = 42L)
```

- [ ] **Step 5: Replace `@examples` in `R/create_gen_rep_weights.R`**

```r
#' @examples
#' # generalized replication with reproducible seed -----------------------
#' create_gen_rep_weights(gss_2024_svy, seed = 42L)
```

- [ ] **Step 6: Replace `@examples` in `R/create_sdr_weights.R`**

SDR requires a `survey_taylor` design; `acs_wy_2022_svy` is a `survey_replicate`, so convert it first with `as_taylor_design()`:

```r
#' @examples
#' # convert replicate ACS design to Taylor, then apply SDR ---------------
#' acs_taylor <- as_taylor_design(acs_wy_2022_svy)
#' create_sdr_weights(acs_taylor)
```

- [ ] **Step 7: Replace `@examples` in `R/create_replicate_weights.R`**

```r
#' @examples
#' # bootstrap (default: Rao-Wu-Yue-Beaumont) ------------------------------
#' create_replicate_weights(gss_2024_svy, method = "bootstrap")
#'
#' # jackknife ----------------------------------------------------------------
#' create_replicate_weights(gss_2024_svy, method = "jackknife")
#'
#' # delete-a-group jackknife for a non-probability sample ------------------
#' create_replicate_weights(ns_wave1_svy, method = "jackknife", type = "grouped")
```

- [ ] **Step 8: Replace `@examples` in `R/as_taylor_design.R`**

```r
#' @examples
#' # convert SDR replicate design back to Taylor ---------------------------
#' as_taylor_design(acs_wy_2022_svy)
```

- [ ] **Step 9: Verify all 7 replicate-weights functions run**

```r
devtools::run_examples(
  package = "surveywts",
  filter = paste0(
    "^(create_bootstrap_weights|create_brr_weights|create_gen_boot_weights",
    "|create_gen_rep_weights|create_sdr_weights|create_replicate_weights",
    "|as_taylor_design)$"
  )
)
```

Expected: 0 errors, 0 warnings. If `create_sdr_weights` warnings about sort order appear, check the `sort_var` argument; `acs_wy_2022_svy` PSU order may need an explicit `sort_var`.

- [ ] **Step 10: Commit**

```bash
git add R/create_bootstrap_weights.R R/create_brr_weights.R \
        R/create_gen_boot_weights.R R/create_gen_rep_weights.R \
        R/create_sdr_weights.R R/create_replicate_weights.R \
        R/as_taylor_design.R
git commit -m "docs(replicate-weights): replace examples with package-data scenarios"
```

---

### Task 15: Phase 2 — Propensity Examples

**Function:** `ipw`

**Changes:** Substantive rewrite — drop `data()` calls, drop ACS scenario (not in approved
dataset list), drop MLE/synthetic-data GEE examples, use `estimating_eq = "gee"` throughout,
use `npors_2025_clean_svy` directly as reference (it is a `survey_taylor`).

**Key constraints:**
- Primary reference: `gss_2024 + wt_pop` (population-scaled). Do NOT use `gss_2024_svy`
  (uses `wtssps`, a normalized weight not suitable for IPW).
- `estimating_eq = "gee"` is the featured approach — do not show MLE.
- All examples use package data — no inline `data.frame()` construction.

- [ ] **Step 1: Read the current `@examples` section in `R/ipw.R`**

The current block has scenarios to drop:
- ACS scenario (`acs_wy_2022` bare data frame — not in approved dataset list) → remove
- GEE example using inline synthetic `data.frame()` → remove
- known population size example → remove
- `data()` calls throughout → remove
- `npors_2025_clean` bare data frame → replace with `npors_2025_clean_svy` directly

- [ ] **Step 2: Replace `@examples` in `R/ipw.R`**

```r
#' @examples
#' # GSS 2024 as probability reference (wt_pop is population-scaled) -------
#' gss_ref <- surveycore::as_survey(
#'   gss_2024, weights = wt_pop, strata = vstrat, ids = vpsu, nest = TRUE
#' )
#'
#' # GEE: formula interface ------------------------------------------------
#' result <- ipw(
#'   ns_wave1, gss_ref,
#'   selection     = ~sex + age_f3,
#'   estimating_eq = "gee"
#' )
#' effective_sample_size(result)
#' weight_variability(result)
#'
#' # NPORS as reference: broader covariates and missing_method --------------
#' # ns_wave1 has ~120 NAs in race_f4; missing_method controls handling
#'
#' # "omit" (default): rows with NA in race_f4 dropped before fitting ------
#' result_omit <- ipw(
#'   ns_wave1,
#'   npors_2025_clean_svy,
#'   selection      = ~sex + age_f3 + race_f4 + edu_f3,
#'   estimating_eq  = "gee",
#'   missing_method = "omit"
#' )
#'
#' # "separate": NA recoded to "(Missing)" level; all rows kept ------------
#' result_sep <- ipw(
#'   ns_wave1,
#'   npors_2025_clean_svy,
#'   selection      = ~sex + age_f3 + race_f4 + edu_f3,
#'   estimating_eq  = "gee",
#'   missing_method = "separate"
#' )
#'
#' # "impute": NA imputed via mice::mice() (requires mice package) ---------
#' if (requireNamespace("mice", quietly = TRUE)) {
#'   result_imp <- ipw(
#'     ns_wave1,
#'     npors_2025_clean_svy,
#'     selection      = ~sex + age_f3 + race_f4 + edu_f3,
#'     estimating_eq  = "gee",
#'     missing_method = "impute"
#'   )
#' }
```

- [ ] **Step 3: Verify examples run**

```r

```

Expected: 0 errors, 0 warnings. The `mice` block is guarded by `requireNamespace()` so it skips if mice is not installed.

- [ ] **Step 4: Commit**

```bash
git add R/ipw.R
git commit -m "docs(propensity): replace examples with package-data scenarios"
```

---

### Task 16: Phase 2 Final Verification and PR

- [ ] **Step 1: Run `devtools::document()`**

```r
devtools::document()
```

Expected: 0 errors, 0 warnings.

- [ ] **Step 2: Run `devtools::check()`**

```r
devtools::check()
```

Expected: 0 errors, 0 warnings, ≤2 notes.

- [ ] **Step 3: Commit updated man/ files**

```bash
git add NAMESPACE man/
git commit -m "docs(phase-2): run devtools::document() after examples rewrites"
```

- [ ] **Step 4: Open PR to `develop`**

```bash
gh pr create \
  --base develop \
  --head docs/phase-2-examples \
  --title "docs: Phase 2 examples rewrite (22 functions, package data)" \
  --body "$(cat <<'EOF'
## Summary

- Replaces all inline data.frame examples with approved package-data scenarios
- All 22 in-scope functions now use: ns_wave1, ns_wave1_svy, gss_2024, gss_2024_svy, acs_wy_2022_svy, pew_2016_optin_svy, npors_2025_clean, npors_2025_clean_svy
- Nonresponse examples construct survey objects from pre-mutated tibbles (no new Suggests dependency)
- calibrate_to_estimate example uses the approved JKn + NPORS scenario
- calibrate_to_survey example uses the approved pew_2016_optin_svy NPS scenario
- ipw examples: substantive rewrite — drop ACS and MLE scenarios, GEE-focused package-data examples with npors_2025_clean_svy
- Zero behavioral changes — documentation only

## Test plan

- [ ] devtools::run_examples() passes with 0 errors, 0 warnings for all 22 functions
- [ ] devtools::check() passes with 0 errors, 0 warnings
EOF
)"
```

---

## Self-Review

### Spec coverage check

| Requirement from design doc | Covered by task |
|---|---|
| `@return` → `@returns` on all 22 functions | Tasks 1–7 |
| Titles per Title Map (all 22) | Tasks 1–7 |
| `@seealso` per Seealso Map (all 22) | Tasks 1–7 |
| `effective_sample_size` formula → `@section Algorithm:` | Task 1 |
| `weight_variability` formula → `@section Algorithm:` | Task 1 |
| `effective_sample_size` `@references` (Kish 1965) | Task 1 |
| `calibrate` `@details` (pre-drafted) | Task 3 |
| `calibrate` `@references` (4 papers) | Task 3 |
| `calibrate_rake` fix `@references` (Kott 2003, not Chang & Kott 2008) | Task 3 |
| `calibrate_rake/linear/logit` `@section Algorithm:` + `@section Convergence:` | Task 3 |
| `poststratify` `@section Algorithm:` | Task 3 |
| `create_brr_weights` `@references` (3 papers) | Task 6 |
| `create_gen_boot_weights` `@references` (4 papers) | Task 6 |
| `create_gen_rep_weights` `@references` (3 papers) | Task 6 |
| `create_sdr_weights` `@references` (2 papers) | Task 6 |
| `create_bootstrap_weights` `@section Algorithm:` | Task 6 |
| `create_replicate_weights` `@seealso` update (add group_jackknife + as_taylor) | Task 6 |
| `create_replicate_weights` NO `@details` or `@references` (deferred) | Task 6 ✓ |
| `ipw` title consolidation (remove `@title` + `@description` tags) | Task 7 |
| `ipw` add `[summarize_weights()]` to `@seealso` | Task 7 |
| `adjust_nonresponse` formula → `@section Algorithm:` | Task 5 |
| `redistribute_weights` formula → `@section Algorithm:` | Task 5 |
| Phase 2: all examples use package data | Tasks 9–15 |
| Phase 2: `calibrate_to_estimate` approved example | Task 12 |
| Phase 2: `calibrate_to_survey` NPS scenario | Task 12 |
| Phase 2: nonresponse survey_taylor path via pre-mutated tibble + `surveycore::as_survey()` | Task 13 |
| `devtools::document()` + `devtools::check()` after Phase 1 | Task 8 |
| `devtools::run_examples()` after each Phase 2 family | Tasks 9–15 |
| Phase 1 PR to `develop` | Task 8 |
| Phase 2 PR to `develop` | Task 16 |

### Placeholder scan

No TBD, TODO, or "similar to Task N" placeholders present. Every step contains the exact content to write.

### Type consistency

- All `@seealso` links use `[fn_name()]` bracket format — consistent throughout
- All `@references` citations match `.claude/reference-map.yaml` verbatim
- `@returns` (plural) used consistently — `@return` never appears in new content
- Section header format `# Brief label ----` used consistently in all Phase 2 examples
