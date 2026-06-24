# Spec — ipw-replicate-ref

**Status**: SPEC_READY
**Target version**: 0.6.0.9000
**PR range**: PR 1 (single PR)

---

## Scope

### In

**Part A — `ipw()` type widening:**

- Widen Behavior Rule 2 in `ipw()` to accept `survey_replicate` as a valid
  class for the `reference` argument, in addition to `survey_taylor`.
- Replace the error class `surveywts_error_svydesign_not_taylor` with
  `surveywts_error_reference_not_survey_design`. The old class is retired in
  `plans/error-messages.md` with a strikethrough entry pointing to the new class.
- Update `@param reference` to document both accepted classes.
- Add a new paragraph to `@details` (existing "Variance estimation — refit
  required" subsection) noting that when `reference` is `survey_replicate`, its
  replicate weight columns provide the reference-design variance component V_p
  per Wu (2022) §6.2. This is a documentation addition only.
- Add Wu (2022) to `@references`.
- Update `plans/error-messages.md`: retire `surveywts_error_svydesign_not_taylor`
  and add `surveywts_error_reference_not_survey_design`.

**Part B — `cps_2023` conversion to `survey_replicate`:**

- Convert `cps_2023` from a plain `data.frame` to a `survey_replicate` object.
  Update `data-raw/cps-2023.R`: replace the final `usethis::use_data()` call
  (and the `message()` call) with:
  ```r
  cps_2023 <- surveycore::as_survey_replicate(
    data       = cps_2023,
    weights    = "wtfinl",
    repweights = paste0("repwtp", 1:160),
    type       = "successive-difference",
    scale      = 4 / 160,
    rscales    = rep(1, 160)
  )
  ## structural assertions for the survey_replicate
  stopifnot(S7::S7_inherits(cps_2023, surveycore::survey_replicate))
  stopifnot(cps_2023@variables$weights == "wtfinl")
  stopifnot(length(cps_2023@variables$repweights) == 160L)
  usethis::use_data(cps_2023, overwrite = TRUE)
  message("Saved cps_2023 as survey_replicate (",
          nrow(cps_2023@data), " rows, 160 SDR replicates)")
  ```
  The replicate columns remain in `@data` (187 cols total) but are also
  registered in `@variables$repweights`.

- Update `R/data.R` `cps_2023` docstring:
  - Change `@description` to describe the object as a `survey_replicate` that
    can be passed directly to `ipw()` and all replicate-weight-aware functions.
    Remove the "construct via `as_survey_replicate()` when needed" workaround
    paragraph.
  - Replace the current `@format` (plain data frame, 187 columns enumerated
    individually) with a `survey_replicate` description. Because `cps_2023` is
    an S7 object — not a plain `data.frame` — the codoc check does not apply,
    so the 160 `repwtp*` columns can be described as a group:

    ```r
    #' @format A \code{survey_replicate} object with a successive-difference
    #'   replicate design. Key slots:
    #' \describe{
    #'   \item{@@data}{A data frame with approximately 10,000 rows and 187
    #'     columns. The 27 analytic columns are: unit identifiers
    #'     (\code{cpsidp}, \code{serial}); main weight (\code{wtfinl});
    #'     raw CPS variables (\code{statefip}, \code{region}, \code{metro},
    #'     \code{age}, \code{sex}, \code{race}, \code{hispan}, \code{educ},
    #'     \code{marst}, \code{empstat}, \code{classwkr}, \code{wkswork2},
    #'     \code{uhrsworkly}, \code{inctot}, \code{hhincome}, \code{health},
    #'     \code{nchild}, \code{famsize}); and derived factor columns
    #'     (\code{age_f3}, \code{race_f4}, \code{edu_f3}, \code{empstat_f},
    #'     \code{inc_hh_cat}, \code{hh_income_f9}). The remaining 160 columns
    #'     are the successive-difference replicate weights (\code{repwtp1}
    #'     through \code{repwtp160}), also listed in
    #'     \code{@@variables$repweights}.}
    #'   \item{@@variables$weights}{\code{"wtfinl"} — the main person weight.}
    #'   \item{@@variables$repweights}{Character vector of length 160:
    #'     \code{c("repwtp1", ..., "repwtp160")}.}
    #'   \item{@@variables$type}{\code{"successive-difference"}.}
    #'   \item{@@variables$scale}{\code{0.025} (= 4/160) — the Census Bureau
    #'     SDR variance scale factor.}
    #' }
    ```

  - Update `@examples` to call `ipw()` directly with `cps_2023`:
    ```r
    data(cps_2023)
    ipw(
      ns_wave1, cps_2023,
      selection = ~sex + age_f3 + race_f4 + edu_f3 + hh_income_f9,
      missing_method = "omit"
    )
    ```

**Part C — remove `acs_wy_2022` and `acs_wy_2022_svy`:**

- Delete `data/acs_wy_2022.rda` and `data/acs_wy_2022_svy.rda`.
- Remove the `acs_wy_2022` / `acs_wy_2022_svy` documentation block from
  `R/data.R` (lines 371–536).
- Update `R/data.R` `ns_wave1` `@seealso` to remove the `[acs_wy_2022]` link.
- Update `R/ipw.R` `@examples`: replace the ACS PUMS block with a `cps_2023`
  block (uses `cps_2023` directly as a `survey_replicate` reference — no
  workaround comment needed).
- Update `R/trim_weights.R` `@examples`: replace `trim_weights(acs_wy_2022_svy)`
  with `trim_weights(cps_2023)` (`survey_replicate` is a supported input class).

### Out

- No changes to the propensity estimation algorithm (MLE or GEE paths).
- No changes to how reference weights are extracted or used in any computation.
- No new variance estimation code; the V_p note is documentation only.
- No changes to `survey_taylor` behavior.
- No changes to any weighting or calibration function other than `ipw()`.
- `data-raw/acs-wy-2022.R` is not deleted — left as a historical data prep
  script. Only the built `.rda` files are removed from the package.

---

## Architecture

### Files touched

**Part A — `ipw()` type widening:**
- `R/ipw.R` — Behavior Rule 2 type check and error class; `@param reference`;
  `@details` variance note; `@examples` CPS block (see Part C); `@references`
  (Wu 2022 added)
- `plans/error-messages.md` — retire `surveywts_error_svydesign_not_taylor`,
  add `surveywts_error_reference_not_survey_design`
- `tests/testthat/test-nonprob-ipw.R` — add happy-path tests for
  `survey_replicate` reference; update/add error-path test for the new class name

**Part B — `cps_2023` conversion:**
- `data-raw/cps-2023.R` — add `survey_replicate` construction + re-save at end
- `data/cps_2023.rda` — regenerated (now a `survey_replicate`)
- `R/data.R` — update `cps_2023` docstring (new class, updated description,
  `@format` for `survey_replicate`, updated examples)

**Part C — `acs_wy_2022` / `acs_wy_2022_svy` removal:**
- `data/acs_wy_2022.rda` — deleted
- `data/acs_wy_2022_svy.rda` — deleted
- `R/data.R` — remove `acs_wy_2022` + `acs_wy_2022_svy` documentation block
  (lines 371–536 in current file); update `ns_wave1` `@seealso` to remove
  `[acs_wy_2022]` link
- `R/trim_weights.R` — `@examples`: replace `trim_weights(acs_wy_2022_svy)`
  with `trim_weights(cps_2023)`
- `tests/testthat/test-datasets.R` — remove all `acs_wy_2022` and
  `acs_wy_2022_svy` test blocks (lines 244–324); add `cps_2023` structural
  tests as `survey_replicate` (see test-spec); update dataset load tests
  (lines 18 and 29) to remove `acs_wy_2022*` entries
- `tests/testthat/test-sample-calibration.R` — update stale comment at line
  3074 that references `acs_wy_2022_svy` (comment only, no logic change)

### Functions added

None.

### Functions modified

- `ipw()` — contract widened: `reference` now accepts `survey_taylor` OR
  `survey_replicate`

### Data objects changed

- `cps_2023` — class changes from `data.frame` to `survey_replicate`
- `acs_wy_2022` — removed from package
- `acs_wy_2022_svy` — removed from package

### Class changes

None.

---

## Function contracts

### `ipw(data, reference, selection, predictors, missing_method, mice_args, method, estimating_eq, maxit, epsilon, adjust_reference, trim, population_size, wt_name)`

**Documentation tier:** Tier 3 — Algorithmic

**Signature (unchanged):**
```
ipw(
  data,
  reference,
  selection = NULL,
  predictors = NULL,
  missing_method = c("omit", "separate", "impute"),
  mice_args = list(),
  method = "logit",
  estimating_eq = c("gee", "mle"),
  maxit = 25L,
  epsilon = 1e-8,
  adjust_reference = TRUE,
  trim = FALSE,
  population_size = NULL,
  wt_name = "ipw_weight"
)
```

**Arguments — changes from current spec:**

- `reference`: A `survey_taylor` or `survey_replicate` object representing the
  probability-based reference sample. Must have strictly positive main design
  weights accessible via `reference@variables$weights`. For either class, the
  main weight column and unit-level covariate data are extracted identically.
  The replicate weight columns of a `survey_replicate` reference are not used
  during propensity estimation; they are available for downstream V_p variance
  estimation (see **Variance estimation** section in `@details`). When `reference`
  is `survey_replicate`, it is preferred over an equivalent plain Taylor design
  when variance estimation quality matters, because its pre-computed replicate
  weights directly provide the reference-design variance component without
  requiring second-order inclusion probabilities (Wu, 2022, §6.2).

All other arguments are unchanged.

**Returns (unchanged):**

A `survey_nonprob` object. The `@reference_sample` slot holds the supplied
`reference` design — which may be a `survey_taylor` or a `survey_replicate`.
The `reference_design` field in the weighting history entry holds the same
supplied object. A new entry with `operation = "ipw"` is appended to the
weighting history.

**Errors:**

| Class | Trigger condition |
|-------|-------------------|
| `surveywts_error_reference_not_survey_design` | `reference` is neither `survey_taylor` nor `survey_replicate` |
| `surveywts_error_reference_weights_nonpositive` | Main weight column of `reference` contains values <= 0 |
| `surveywts_error_not_data_frame` | `data` is not a `data.frame` |
| `surveywts_error_empty_data` | `nrow(data) == 0` |
| `surveywts_error_selection_conflict` | Both `selection` and `predictors` are non-NULL |
| `surveywts_error_selection_missing` | Both `selection` and `predictors` are NULL |
| `surveywts_error_formula_variable_not_in_reference` | A selection variable is absent from `reference@data` |
| `surveywts_error_propensity_level_not_in_reference` | A factor level in `data` is absent from `reference@data` |
| `surveywts_error_separate_numeric_na` | `missing_method = "separate"` and a numeric selection variable has NA |
| `surveywts_error_mice_not_installed` | `missing_method = "impute"` but `mice` is not installed |
| `surveywts_error_wt_name_not_scalar` | `wt_name` is not `character(1)` |
| `surveywts_error_wt_name_empty` | `wt_name` is `NA` or `""` |
| `surveywts_error_wt_name_conflict` | `wt_name` already exists as a column in `data` |
| `surveywts_error_propensity_invalid_maxit` | `maxit < 1` or non-integer |
| `surveywts_error_propensity_invalid_epsilon` | `epsilon <= 0` |
| `surveywts_error_propensity_hessian_singular` | MLE Hessian is singular (collinear covariates) |
| `surveywts_error_propensity_scores_degenerate` | Any propensity score at float boundary of (0, 1) |
| `surveywts_error_adjust_reference_invalid` | `adjust_reference` is not a length-1 logical |
| `surveywts_error_population_size_invalid` | `population_size` is not NULL and not a positive finite scalar |

**Warnings (unchanged):**

| Class | Condition |
|-------|-----------|
| `surveywts_warning_ipw_reference_na_omitted` | `reference@data` has NA in selection variables |
| `surveywts_warning_ipw_reference_weight_adjusted` | NPS fraction > 5% and `adjust_reference = TRUE` |
| `surveywts_warning_ipw_reference_unadjusted_large_nps` | NPS fraction > 5% and `adjust_reference = FALSE` |
| `surveywts_warning_ipw_covariate_range_extrapolation` | NPS numeric covariate range exceeds reference range |
| `surveywts_warning_ipw_reference_levels_absent_from_nps` | Reference factor level absent from NPS |
| `surveywts_warning_ipw_data_na_omitted` | `missing_method = "omit"` and NPS has NA in selection variables |
| `surveywts_warning_ipw_mice_m_ignored` | `mice_args` contains `m` |
| `surveywts_warning_propensity_nr_no_convergence` | Solver did not converge within `maxit` iterations |

**Behavior Rule 2 — revised:**

```
if (!S7::S7_inherits(reference, surveycore::survey_taylor) &&
    !S7::S7_inherits(reference, surveycore::survey_replicate)) {
  cli::cli_abort(
    c(
      "x" = "{.arg reference} must be a {.cls survey_taylor} or
             {.cls survey_replicate} object.",
      "i" = "Got {.cls {class(reference)[[1L]]}}.",
      "v" = paste0(
        "Pass a probability-based survey design as the reference. ",
        "Use {.fn surveycore::as_survey} to construct one from a data frame."
      )
    ),
    class = "surveywts_error_reference_not_survey_design"
  )
}
```

**Behavior Rule 3 — weight extraction (unchanged logic, applies to both types):**

```
ref_wt_col  <- reference@variables$weights
ref_weights <- reference@data[[ref_wt_col]]
```

This works identically for `survey_taylor` and `survey_replicate`: both expose
`@variables$weights` (the main weight column name) and `@data` (the unit-level
data frame). The replicate weight columns in a `survey_replicate` object are
stored separately and are not touched by `ipw()`.

**All other behavior rules are unchanged.**

**Edge cases:**

| Input | Expected behavior |
|-------|-------------------|
| `reference` is `survey_taylor` | Unchanged from current behavior |
| `reference` is `survey_replicate` | Accepted; main weight extracted via `@variables$weights`; algorithm runs identically |
| `reference` is a `data.frame` | Errors with `surveywts_error_reference_not_survey_design` |
| `reference` is a `survey_nonprob` | Errors with `surveywts_error_reference_not_survey_design` |
| `reference` is `NULL` | Errors with `surveywts_error_reference_not_survey_design` |
| `reference` is a list | Errors with `surveywts_error_reference_not_survey_design` |
| `survey_replicate` reference with some zero-valued replicate columns (normal for BRR) | Main weight is positive; passes Behavior Rule 3; replicate columns are ignored |
| `survey_replicate` and `survey_taylor` references with identical main weights and covariates | Produce numerically identical IPW weights (to within floating-point arithmetic) |

**Documentation changes — `@param reference`:**

Update to list both accepted types and include the variance note about
`survey_replicate` being preferred when downstream variance estimation matters.
Cite Wu (2022) for the V_p pathway.

**Documentation changes — `@details` variance section:**

Add a new paragraph after the existing "Variance estimation — refit required"
guidance. The paragraph explains that when `reference` is a `survey_replicate`,
its pre-computed replicate weight columns provide a direct estimator for the
reference-design variance component V_p (Wu, 2022, §6.2) without requiring
second-order inclusion probabilities. This is distinct from — and complementary
to — the propensity model refitting requirement: the two variance components
(V_q from propensity model uncertainty, V_p from reference design uncertainty)
are both needed for a complete variance estimate, and they are estimated by
separate procedures.

**Documentation changes — `@examples`:**

The current ACS PUMS block reads:
```r
# --- ACS PUMS Wyoming as probability reference ------------------------
# acs_wy_2022_svy is survey_replicate; ipw() needs survey_taylor.
# Construct a plain Taylor design from the tibble.
data(acs_wy_2022)
acs_ref <- surveycore::as_survey(acs_wy_2022, weights = pwgtp)
result_acs <- ipw(
  ns_wave1,
  acs_ref,
  selection = ~sex + age_f3 + race_f4 + edu_f3,
  missing_method = "omit"
)
```

Replace with:
```r
# --- CPS ASEC 2023 as probability reference (survey_replicate) --------
# cps_2023 is a survey_replicate with 160 SDR replicate weights.
# ipw() accepts survey_replicate directly; its replicate weights are
# available for reference-design variance estimation after weighting.
data(cps_2023)
result_cps <- ipw(
  ns_wave1,
  cps_2023,
  selection = ~sex + age_f3 + race_f4 + edu_f3 + hh_income_f9,
  missing_method = "omit"
)
```

Note: `cps_2023` (after Part B conversion) is a `survey_replicate` (SDR,
`wtfinl` as main weight, `repwtp1`–`repwtp160` as 160 replicates). It shares
the factor columns `sex`, `age_f3`, `race_f4`, `edu_f3`, `hh_income_f9`
with `ns_wave1`.

**Documentation changes — `@references`:**

Add Wu (2022) to the existing reference list:

```
Wu, C. (2022). Statistical inference with non-probability survey samples.
*Survey Methodology* **48**(2), 283--311.
```

**Documentation changes — `@details` "Estimating equation" paragraph:**

No change needed. The current paragraph already correctly describes the
unconditional pseudo-likelihood approach.

---

## Error class changes

### Retire

`surveywts_error_svydesign_not_taylor` — fired when `reference` was not a
`survey_taylor`. Retired because the new contract accepts two design classes.
Add strikethrough in `plans/error-messages.md` with note pointing to
`surveywts_error_reference_not_survey_design`.

### Add

`surveywts_error_reference_not_survey_design` — fired when `reference` is
neither `survey_taylor` nor `survey_replicate`. Thrown by `ipw()`, Behavior
Rule 2.

---

## Quality gates

- For any input where `S7::S7_inherits(reference, surveycore::survey_replicate)`
  is TRUE, the returned `survey_nonprob` passes `test_invariants()`.
- For any input where `S7::S7_inherits(reference, surveycore::survey_taylor)`
  is TRUE, behavior is identical to the pre-PR state.
- The `reference_design` field in the history entry holds the original supplied
  `reference` object (preserving the `survey_replicate` object with its replicate
  columns).
- `ipw()` errors with `surveywts_error_reference_not_survey_design` for all
  non-survey-design inputs (including `data.frame`, `survey_nonprob`, `NULL`,
  `list`).
- `surveywts_error_svydesign_not_taylor` is never thrown by any code path after
  this PR.

---

## Pipeline split

optional — No new exported function, no algorithmic change, ≤3 files touched,
type-widening only.

---

## @references (for the spec record)

- Chen, Y., Li, P. and Wu, C. (2020). Doubly robust inference with
  nonprobability survey samples. *Journal of the American Statistical
  Association* **115**(532), 2011--2021.

- Elliott, M.R. and Valliant, R. (2017). Inference for nonprobability samples.
  *Statistical Science* **32**(2), 249--264.

- Lenau, S., Marchetti, S., Munnich, R., Pratesi, M., Salvati, N., Shlomo,
  N., Schirripa Spagnolo, F. and Zhang, L.-C. (2021). Methods for sampling
  and inference with non-probability samples. Deliverable D11.8,
  InGRID-2 project 730998 -- H2020.

- Valliant, R. (2020). Comparing alternatives for estimation from
  nonprobability samples. *Journal of Survey Statistics and Methodology*
  **8**, 231--263. doi: 10.1093/jssam/smz003.

- Wu, C. (2022). Statistical inference with non-probability survey samples.
  *Survey Methodology* **48**(2), 283--311.

- Yang, S., Kim, J.K. and Song, R. (2020). Doubly robust inference when
  combining probability and non-probability samples with high dimensional
  data. *Journal of the Royal Statistical Society: Series B* **82**(2),
  445--465.
