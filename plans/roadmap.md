# surveyweights Roadmap

**Package goal:** All-in-one source for survey weighting needs, combining
functionality from `survey`, `svrep`, `anesrake`, `WeightIt`, and others
into a single tidyverse-compatible, S7-based package.

**Surveycore dependency:** Requires `surveycore >= 0.1.0` (complete).

---

## Phase Summary

| Phase | Tag | Theme | Status |
|-------|-----|-------|--------|
| Phase 0 — Calibration Core | `v0.1.0` | `survey_calibrated` class, calibration methods, basic diagnostics | 🔜 Next |
| Phase 1 — Replicate Weights | `v0.2.0` | All `create_*_weights()` functions; unlocks bootstrap variance in `survey_calibrated` | ⬜ Pending |
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

**`survey_calibrated` S7 class + constructor**
- Completes the skeleton from `surveycore` Phase 0
- `@calibration` property: provenance record from calibration functions
- `as_survey_calibrated(design, calibration, variance = c("srs", "bootstrap"))`
  - `variance = "bootstrap"` deferred to Phase 1; raises
    `surveyweights_error_bootstrap_requires_replicates` until then
- Estimation functions (`get_means()` etc.) dispatch on `survey_calibrated`
  using SRS variance initially

**Calibration methods**
- `calibrate(svy, formula, population, method = c("raking", "linear", "logit"))`
  — general calibration to known totals
- `rake(svy, formulas, population_margins)` — iterative proportional fitting
  (separate user-facing function with multiple-margin argument structure)
- `poststratify(svy, strata, population)` — cell-based exact calibration

All three:
- Write provenance to `@calibration` (structured list: method, formula,
  population, timestamp, call)
- Append to `@metadata@weighting_history`
- Preserve all other metadata from the input design
- Share an internal `.calibrate_engine()` helper (avoids DRY violation)

**Basic weight diagnostics** (small functions, high immediate value)
- `effective_sample_size(svy)` — Kish's formula: `(sum(w))^2 / sum(w^2)`
- `weight_variability(svy)` — coefficient of variation of weights
- `summarize_weights(svy, by = NULL)` — distribution summary (mean, CV, min,
  max, percentiles); `by` allows within-group summaries

### Source File Map

| File | Contents |
|------|----------|
| `R/00-classes.R` | `survey_calibrated` S7 class + validator |
| `R/01-constructors.R` | `as_survey_calibrated()` |
| `R/02-calibrate.R` | `calibrate()`, `rake()`, `poststratify()` |
| `R/03-diagnostics.R` | `effective_sample_size()`, `weight_variability()`, `summarize_weights()` |
| `R/07-utils.R` | `.calibrate_engine()`, `.write_provenance()`, `.validate_population_totals()` |

### Test References

- `survey::calibrate()`, `survey::rake()` — numerical gold standard
- Tolerances: point estimates `1e-10`, weights `1e-8`

### Notes

- First task in Phase 0: add `surveycore (>= 0.1.0)` to `DESCRIPTION Imports`
- Define `make_surveyweights_data()` and `test_invariants()` in
  `tests/testthat/helper-test-data.R` before writing any source
- Fill in stubs in `surveyweights-conventions.md` and
  `testing-surveyweights.md` before implementation begins

---

## Phase 1 — Replicate Weight Generation (`v0.2.0`)

**What users can do:** Convert any Taylor linearization design to a replicate
design using six schemes. Also unlocks full bootstrap variance in
`survey_calibrated` (re-calibrates on each replicate using stored provenance).

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

**Unlock `variance = "bootstrap"` in `survey_calibrated`**
- Remove the Phase 0 stub error
- `as_survey_calibrated(..., variance = "bootstrap")` now re-calibrates
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

**Nonresponse adjustment**
- `adjust_nonresponse(svy, response_status, method = c("weighting-class", "propensity-cell", "propensity"))`
  - `method = "weighting-class"`: redistributes nonrespondent weights to
    respondents within each response class proportionally (implemented Phase 0)
  - `method = "propensity-cell"`: estimate response propensity via logistic
    regression → sort into quintile cells → redistribute within cells
  - `method = "propensity"`: full IPW via logistic regression
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
- `surveyweights-conventions.md` fully filled in
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
