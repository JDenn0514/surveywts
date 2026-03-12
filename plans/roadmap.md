# surveywts Roadmap

**Package goal:** All-in-one source for survey weighting needs, combining
functionality from `survey`, `svrep`, `anesrake`, `WeightIt`, and others
into a single tidyverse-compatible, S7-based package.

**Surveycore dependency:** Requires `surveycore >= 0.1.0` (complete).

---

## Phase Summary

| Phase | Tag | Theme | Status |
|-------|-----|-------|--------|
| Phase 0 — Calibration Core | `v0.1.0` | `survey_nonprob` class, calibration methods, basic diagnostics | ✅ Complete |
| Phase 1 — Replicate Weights | `v0.2.0` | All `create_*_weights()` functions; unlocks bootstrap variance in `survey_nonprob` | 🔜 Next |
| Phase 2 — Nonresponse & Advanced Calibration | `v0.3.0` | Sample-based calibration, weighting-class nonresponse | ⬜ Pending |
| Phase 3 — Propensity Score Weighting | `v0.4.0` | IPW for causal inference; unlocks propensity nonresponse | ⬜ Pending |
| Phase 4 — Diagnostics & Utilities | `v0.5.0` | Balance assessment, weight trimming/stabilization, visual diagnostics | ⬜ Pending |
| Phase 5 — Polish & CRAN | `v1.0.0` | Vignettes, `--as-cran` clean, pkgdown, CRAN submission | ⬜ Pending |

---

## Phase 0 — Calibration Core (`v0.1.0`)

**What users can do:** Take a `survey_taylor` or `survey_replicate` from
`surveycore`, calibrate it to known population totals, and check the result.
This is the minimum useful thing the package does.

### Deliverables

**`weighted_df` S3 class** (defined in surveywts)
- S3 subclass of tibble: `c("weighted_df", "tbl_df", "tbl", "data.frame")`
- Attributes: `weight_col` (character), `weighting_history` (list)
- dplyr integration via `dplyr_reconstruct.weighted_df()`, `select.weighted_df()`,
  `rename.weighted_df()`, `mutate.weighted_df()`
- Never constructed directly by users — produced as output from calibration
  and nonresponse functions when input is a plain `data.frame` or `weighted_df`

**`survey_nonprob` S7 class + print method**
- Class is defined in `surveycore`; surveywts provides a `print` method for it
- Inherits `@data`, `@variables`, `@metadata` from `survey_base`
- `@variables$weights`: name of the weight column in `@data`
- Weighting history stored in `@metadata@weighting_history`

**Calibration methods**
- `calibrate(data, variables, population, weights = NULL, method = c("linear", "logit"), type = c("prop", "count"), control = list(maxit = 50, epsilon = 1e-7))`
  — general calibration via GREG; note: `"raking"` is NOT a method here (lives in `rake()`)
- `rake(data, margins, weights = NULL, type = c("prop", "count"), method = c("anesrake", "survey"), cap = NULL, control = list())`
  — iterative proportional fitting; two backends: `"anesrake"` (chi-square variable selection) and `"survey"` (IPF)
- `poststratify(data, strata, population, weights = NULL, type = c("count", "prop"))`
  — cell-based exact calibration; default `type = "count"`

All three append to `weighting_history` and share `.calibrate_engine()`.

**Bonus deliverable: `adjust_nonresponse()`** (promoted from Phase 2 into Phase 0)
- `adjust_nonresponse(data, response_status, weights = NULL, by = NULL, method = c("weighting-class", "propensity-cell", "propensity"), control = list(min_cell = 20, max_adjust = 2.0))`
- `method = "weighting-class"` fully implemented
- `method = "propensity"` and `method = "propensity-cell"` are stubs (error until Phase 2/3)
- Returns respondent rows only (nonrespondents dropped)

**Basic weight diagnostics**
- `effective_sample_size(x, weights = NULL)` — Kish's formula: `(sum(w))^2 / sum(w^2)`
- `weight_variability(x, weights = NULL)` — coefficient of variation of weights
- `summarize_weights(x, weights = NULL, by = NULL)` — distribution summary (mean, CV, min,
  max, percentiles); `by` allows within-group summaries

**Vendored algorithms** (avoids heavy dependencies)
- `survey` package: GREG linear/logit calibration, IPF raking
- `anesrake` package: chi-square variable selection raking

### Source File Map

| File | Contents |
|------|----------|
| `R/classes.R` | `weighted_df` S3 class + dplyr methods (`dplyr_reconstruct`, `select`, `rename`, `mutate`, `print`) |
| `R/calibrate.R` | `calibrate()` |
| `R/rake.R` | `rake()` |
| `R/poststratify.R` | `poststratify()` |
| `R/nonresponse.R` | `adjust_nonresponse()` (weighting-class implemented; propensity stubs) |
| `R/diagnostics.R` | `effective_sample_size()`, `weight_variability()`, `summarize_weights()` |
| `R/methods-print.R` | `print` method for `survey_nonprob` (S7 method, class from surveycore) |
| `R/utils.R` | All shared internal helpers: `.get_weight_col_name()`, `.get_weight_vec()`, `.validate_weights()`, `.validate_calibration_variables()`, `.validate_population_marginals()`, `.compute_weight_stats()`, `.make_history_entry()`, `.make_weighted_df()`, `.update_survey_weights()`, `.calibrate_engine()`, `.build_model_matrix()`, `.format_history_step()`, `%\|\|%` |
| `R/vendor-calibrate-greg.R` | Vendored: GREG linear & logit calibration (from `survey` pkg) |
| `R/vendor-calibrate-ipf.R` | Vendored: IPF iterative proportional fitting (from `survey` pkg) |
| `R/vendor-rake-anesrake.R` | Vendored: anesrake chi-square variable selection (from `anesrake` pkg) |
| `R/surveywts-package.R` | Package documentation entry point |

### Test References

- `survey::calibrate()`, `survey::rake()` — numerical gold standard
- Tolerances: point estimates `1e-10`, weights `1e-8`

### Notes

- `survey_nonprob` class is defined in `surveycore`; surveywts extends it
  with a print method and uses it as the output type for calibration functions
  when input is a `survey_taylor` or `survey_nonprob`
- `adjust_nonresponse()` was promoted from Phase 2 into Phase 0; the
  weighting-class method is fully implemented; propensity methods remain stubs

---

## Phase 1 — Replicate Weight Generation (`v0.2.0`)

**What users can do:** Convert any Taylor linearization design to a replicate
design using six schemes. Also unlocks full bootstrap variance in
`survey_nonprob` (re-calibrates on each replicate using stored provenance).

### Deliverables

**Replicate weight creation functions** (all return `survey_replicate`)
- `create_bootstrap_weights(svy, replicates = 500, type = c("Rao-Wu-Yue-Beaumont", "standard"))`
- `create_jackknife_weights(svy, replicates, type = c("delete-1", "random-groups"))`
- `create_brr_weights(svy, fay_rho = 0)`
- `create_fay_weights(svy, replicates = 100, rho = 0.5)`
- `create_gen_boot_weights(svy, replicates = 500, variance_estimator = c("SD1", "SD2"))`
- `create_sdr_weights(svy, replicates = 100)`

**Conversion functions**
- `as_replicate_design(svy, method, replicates)` — dispatches to the
  appropriate `create_*` function based on `method`
- `as_taylor_design(svy)` — collapses a replicate design to Taylor

**Unlock `variance = "bootstrap"` in `survey_nonprob`**
- Remove the Phase 0 stub error
- `as_survey_nonprob(..., variance = "bootstrap")` now re-calibrates
  on each replicate using the provenance in `@calibration`

### Source File Map

| File | Contents |
|------|----------|
| `R/04-replicate-weights.R` | All six `create_*_weights()` functions |
| `R/05-conversion.R` | `as_replicate_design()`, `as_taylor_design()` |

### Test References

- `svrep` — primary reference for all six creation methods
- `survey::as.svrepdesign()` — for BRR cross-validation
- Tolerances: point estimates `1e-10`, variance `1e-8`

---

## Phase 2 — Nonresponse & Advanced Calibration (`v0.3.0`)

**What users can do:** Calibrate to control totals that are themselves
estimated (not fixed). Adjust for unit nonresponse using weighting classes.

### Deliverables

**Sample-based calibration**
- `calibrate_to_survey(primary_design, control_design, formula, method)` —
  adjusts replicate weights to account for variance in estimated control totals
  when benchmarks come from another survey design; requires `primary_design` to
  be a `survey_replicate`
- `calibrate_to_estimate(design, estimate, vcov_estimate, formula)` —
  when only a point estimate + covariance of the control total is available

**Nonresponse adjustment** (extends Phase 0 stubs)
- `adjust_nonresponse()` was introduced in Phase 0 with `method = "weighting-class"`
  fully implemented; Phase 2 unlocks the two propensity stubs:
  - `method = "propensity-cell"`: estimate response propensity via logistic
    regression → sort into quintile cells → redistribute within cells
  - `method = "propensity"`: full IPW via logistic regression (delegates to Phase 3
    `estimate_propensity()` + `create_propensity_weights()`)
- `redistribute_weights(svy, reduce_if, increase_if, by = NULL)` — general
  weight redistribution primitive (exported standalone)

All functions append to `@metadata@weighting_history`.

### Source File Map

| File | Contents |
|------|----------|
| `R/06-sample-calibration.R` | `calibrate_to_survey()`, `calibrate_to_estimate()` |
| `R/07-nonresponse.R` | `adjust_nonresponse()`, `redistribute_weights()` |

### Test References

- `svrep::calibrate_to_sample()`, `svrep::calibrate_to_estimate()`
- `survey` — weighting-class nonresponse comparison

---

## Phase 3 — Propensity Score Weighting (`v0.4.0`)

**What users can do:** Construct inverse probability weights for causal
inference. Choose estimand (ATE, ATT, ATC, overlap, matching). Unlocks
`adjust_nonresponse(method = "propensity")` from Phase 2.

### Deliverables

**Propensity estimation**
- `estimate_propensity(data, formula, method = c("logistic", "probit", "rf", "gbm"))`
  - `logistic`/`probit` via `stats::glm()` (no new Imports)
  - `rf` requires `ranger` in `Suggests`; `gbm` requires `gbm` in `Suggests`
  - Returns a structured list: fitted probabilities, model object, method metadata

**Weight creation**
- `create_propensity_weights(svy, propensity, estimand = c("ATE", "ATT", "ATC", "overlap", "matching"), stabilize = TRUE, trim_at = NULL)`
  - Uses internal `.trim_weights_internal()` for `trim_at` (unexported helper;
    the exported `trim_weights()` wraps this in Phase 4)
- `add_propensity_weights(svy, formula, estimand, method)` — combined
  one-step wrapper (calls `estimate_propensity()` + `create_propensity_weights()`)

**Nonresponse-via-calibration**
- `calibrate_nonresponse(data, response_status, variables, weights = NULL, method = c("linear", "logit"), control = list())` —
  calibrates respondent weights to match full-sample (respondents + nonrespondents)
  weighted totals on `variables`; mirrors `calibrate()` signature but computes
  targets internally from the data rather than requiring an external `population` argument

**Unlock `adjust_nonresponse(method = "propensity")` and `adjust_nonresponse(method = "propensity-cell")`**
- Remove the Phase 2 stub errors; both delegate to `estimate_propensity()` +
  `create_propensity_weights()` internally

### Source File Map

| File | Contents |
|------|----------|
| `R/08-propensity.R` | `estimate_propensity()`, `create_propensity_weights()`, `add_propensity_weights()` |
| `R/09-calibrate-nonresponse.R` | `calibrate_nonresponse()` |

### Test References

- `WeightIt` — cross-validation for ATE/ATT/ATC IPW weights
- `cobalt` — balance diagnostic cross-check

---

## Phase 4 — Diagnostics & Utilities (`v0.5.0`)

**What users can do:** Fully audit weight construction. Assess covariate
balance. Compare estimates across weighting strategies. Trim and stabilize
weights.

### Deliverables

**Comprehensive diagnostics**
- `check_balance(svy_weighted, covariates, unweighted)` — standardized mean
  differences, variance ratios; returns tidy data frame suitable for plotting
- `diagnose_propensity(svy, formula, show_plots = FALSE)` — overlap
  assessment; `show_plots = TRUE` requires `ggplot2` in `Suggests`
- `compare_weighted_estimates(list_of_designs, formula)` — side-by-side
  estimates across a named list of designs

**Weight utilities** (exported wrappers for internal helpers from earlier phases)
- `trim_weights(svy, lower, upper)` — exported wrapper around
  `.trim_weights_internal()` (available since Phase 3); appends to
  `@metadata@weighting_history`
- `stabilize_weights(svy, by = NULL)` — rescale weights to sum to n (or
  group n); appends to `@metadata@weighting_history`

### Source File Map

| File | Contents |
|------|----------|
| `R/09-balance.R` | `check_balance()`, `diagnose_propensity()`, `compare_weighted_estimates()` |
| `R/10-weight-utils.R` | `trim_weights()`, `stabilize_weights()` |

### Test References

- `cobalt::bal.tab()` — SMD cross-validation
- `WeightIt::ESS()` — ESS cross-validation
- `survey::svymean()` — estimate comparison

---

## Phase 5 — Polish & CRAN (`v1.0.0`)

**No new function deliverables.** This phase is explicitly listed because
this work is substantial and should not be appended to Phase 4.

### Deliverables

- `DESCRIPTION` finalized: complete `Description:`, all `Suggests` with
  minimum versions (`ranger`, `gbm`, `ggplot2`, `cobalt`, `WeightIt`)
- Full vignette suite:
  - `vignette("calibration")` — end-to-end: `survey_taylor` → raking → estimates
  - `vignette("replicate-weights")` — scheme selection guide; `svrep` comparison
  - `vignette("propensity-weighting")` — causal estimands; ATE vs ATT workflow
  - `vignette("nonresponse")` — weighting-class vs propensity comparison
- `plans/error-messages.md` complete with every class from all phases
- `surveywts-conventions.md` fully filled in
- `R CMD check --as-cran` clean: 0 errors, 0 warnings, ≤2 notes
- `pkgdown` site build verified
- NEWS.md entries for all phases reviewed

---

## Cross-Cutting Design Decisions

### `@calibration` provenance record structure
Must be specified in the Phase 0 spec **before** implementation. Proposed:
```r
list(
  method      = "raking",          # or "linear", "logit", "poststratify"
  formula     = ~age + sex,         # or a list of formulas for rake()
  population  = list(...),          # the population margins/totals
  timestamp   = Sys.time(),
  call        = sys.call()
)
```
`@metadata@weighting_history` is a list of such records, growing with each step.

### `calibrate()` vs `rake()` distinction
`rake()` gets its own user-facing function (multiple-margin argument structure)
rather than being a `method = "raking"` shortcut. The shared engine is
`.calibrate_engine()` in `R/07-utils.R` — the DRY rule requires this.

### `trim_weights()` internals across phases
Phase 3 needs trimming internally (the `trim_at` argument in
`create_propensity_weights()`). Export the function in Phase 4. Use an
unexported `.trim_weights_internal()` helper from Phase 3 onward;
`trim_weights()` (exported) is just a wrapper around it.

### `surveycore` dependency
Add `surveycore (>= 0.1.0)` to `DESCRIPTION Imports` as the very first change
in Phase 0 before any source file references `surveycore` class objects.
