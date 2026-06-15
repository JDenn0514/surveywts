# Decisions Log — surveywts propensity

This file records planning decisions made during the Propensity phase.
Each entry corresponds to one planning session.

---

## 2026-05-19 — Methodology lock: ipw() and adjust_nonresponse(method = "propensity")

### Context

Five methodology issues were resolved from the Stage 2 review. Two were unambiguous
(applied without discussion). Three were judgment calls covering the propensity
estimation method, GLM convergence handling, and warning class semantics.

### Questions & Decisions

**Q: Should ipw() use the weighted GLM (Valliant & Dever 2011) or pseudo-likelihood
(Chen 2021) approach for propensity estimation?**
- Options considered:
  - **Weighted GLM:** Plain `stats::glm()` on pooled data. Simple, widely used, but
    the `nonprobsvy` cross-validation test would fail at any tight tolerance because
    the two packages use different estimating equations.
  - **Pseudo-likelihood (Chen 2021):** Maximizes the pseudo-log-likelihood via
    Newton-Raphson. This is the method used by `nonprobsvy`, making the 1e-6
    cross-validation test valid. Requires ~15-line custom NR loop.
- **Decision:** Pseudo-likelihood via Newton-Raphson.
- **Rationale:** The cross-validation test against `nonprobsvy` is a meaningful
  correctness check. Using the same method makes it valid. The NR implementation is
  compact and the convergence arguments (`maxit`, `epsilon`) map directly.

**Q: Should ipw() expose a control list or top-level arguments for maxit, epsilon, trim?**
- Options considered:
  - **control list:** Matches adjust_nonresponse() pattern; grouped under one argument.
  - **Top-level arguments:** Explicit; each argument is documented and visible in
    the function signature.
- **Decision:** Top-level arguments (`maxit`, `epsilon`, `trim`).
- **Rationale:** User preference for explicitness.

**Q: Should the svydesign argument be renamed to survey_taylor?**
- **Decision:** Yes — argument renamed `survey_taylor` to match the class name.
- **Rationale:** User preference; consistent with the class the argument accepts.

**Q: Should ipw() include multiple PSA weight formulas (PSA2–4 from Rueda 2020) now?**
- Options considered:
  - **Add all PSA variants now:** PSA1 (1/π̂), PSA2 ((1−π̂)/π̂), PSA3/PSA4 (stratified).
  - **Defer:** Keep only the standard 1/π̂ formula; add variants in a future phase.
- **Decision:** Defer. Keep 1/π̂ only for this phase.
- **Rationale:** User walked back the scope expansion after initially exploring it.
  Simpler scope; match nonprobsvy's default output.

**Q: How should adjust_nonresponse(method = "propensity") handle GLM non-convergence?**
- Options considered:
  - **Option A:** Add @details text only; pass native GLM warning through unchanged.
  - **Option B:** Re-wrap the convergence warning as
    `surveywts_warning_propensity_glm_convergence` with explicit message about
    unreliable scores.
- **Decision:** Option B — re-wrap with explicit surveywts warning.
- **Rationale:** Clearer user-facing message; makes the reliability implication
  explicit rather than relying on users knowing what "algorithm did not converge" means
  in the context of propensity weights.

**Q: Should surveywts_warning_class_near_empty be reused for the propensity extreme-
adjustment check in adjust_nonresponse(method = "propensity")?**
- Options considered:
  - **Reuse:** Same check logic; no new class needed.
  - **New class:** `surveywts_warning_extreme_propensity_adjustment` — no "class"
    semantics in the name; message text refers to adjustment factors, not cells.
- **Decision:** New class `surveywts_warning_extreme_propensity_adjustment`.
- **Rationale:** The existing class name contains "class" (discrete cells), which is
  semantically wrong for continuous propensity scores. The warning is part of the
  public API; fixing the name now costs little.

### Outcome

Spec is at version 0.2. `ipw()` uses pseudo-likelihood NR (not weighted GLM), exposes
`maxit`/`epsilon`/`trim` as top-level arguments, and accepts `survey_taylor` by name.
Five new warning/error classes added. `adjust_nonresponse(method = "propensity")`
re-wraps GLM convergence warnings and uses a dedicated extreme-adjustment warning class.

---

## 2026-05-19 — Stage 4 Pass 1: Issues 1–18 (Spec Quality + API Audit)

### Context

Working through the 18 issues from `plans/spec-review-propensity.md` Pass 1. Most were
clear-cut; the items below required a genuine choice between meaningfully different approaches.

### Questions & Decisions

**Q: How should `ipw()` handle factor level mismatches between `data` and `reference@data`? (Issue 1)**
- Options considered:
  - **Align levels silently:** Drop orphaned NPS levels and emit a warning
  - **Error on NPS orphaned levels; ignore reference-only levels:** Error if `data` has a level absent from `reference@data` (a support violation); silently ignore levels present only in `reference@data` (harmless)
- **Decision:** Error for NPS orphaned levels (`surveywts_error_propensity_level_not_in_reference`); silently ignore reference-only levels.
- **Rationale:** NPS orphaned levels indicate a support violation — the NPS has covariate combinations not observed in the reference sample, making propensity estimation impossible for those units. Reference-only levels are harmless: the model matrix will have valid entries for all NPS units even if the reference has additional levels.

**Q: Should the argument colliding with the class name (`survey_taylor`) be renamed? (Issue 15)**
- Options considered:
  - **Keep `survey_taylor`:** Class name as argument aids discoverability
  - **Rename to `reference`:** Shorter, matches NPS literature, avoids name collision
- **Decision:** Rename to `reference` throughout.
- **Rationale:** The class-name collision created inconsistency in the behavior rules (some used `svydesign`, others `survey_taylor`). `reference` is unambiguous, commonly used in NPS methodology literature, and is shorter to type. Applied throughout: signature, argument table, all behavior rules, output contract, example, and §VIII conventions table.

**Q: Can `adjust_nonresponse(method = "propensity")` delegate to a shared helper? (Issue 3 architecture)**
- Options considered:
  - **Delegate to `surveywts::redistribute_weights()`:** Wrong math — proportional redistribution, not unit-specific `w_i / p̂_i`
  - **Share `.fit_participation_propensity()`:** Would require branching on problem type; structural difference, not surface repetition
  - **Inline `stats::glm()` independently**
- **Decision:** Inline `stats::glm()` independently. No shared helper.
- **Rationale:** Response propensity (P(respond | sampled)) and participation propensity (P(in NPS | X)) differ in data structure, weight construction, and reference data requirements. A shared helper would require conditional logic on the problem type, producing a harder-to-test abstraction. Per engineering-preferences.md §1.

**Q: What formula is used for the extreme-adjustment check? (Issue 3 formula)**
- Options considered:
  - **§V formula:** `max(weight_i / score_i) / mean(weight_i)` — ratio of max adjusted weight to mean original weight
  - **§VI formula:** `max(1 / score) / mean(1 / score)` — score-quality check ignoring original weights
- **Decision:** §V formula: `max(weight_i / score_i) / mean(weight_i)`.
- **Rationale:** More methodologically meaningful — detects when propensity adjustment inflates any individual weight far above the sample average. The §VI test was the derivative artifact and was updated to match.

**Q: How should all-respondents / all-nonrespondents edge cases be handled for `method = "propensity"`? (Issue 10)**
- Options considered:
  - **Specify new propensity-specific error classes**
  - **Cross-reference Nonresponse spec:** Cases already specified there; handled by shared validation layer before the propensity branch
- **Decision:** Cross-reference Nonresponse spec; no new error classes.
- **Rationale:** These edge cases are caught by shared input-validation in `adjust_nonresponse()` before any method-specific code runs. Adding new classes would be redundant.

**Q: Should the console output GAP be resolved immediately or deferred? (Issue 13)**
- **Decision:** Defer until bootstrap issues (Pass 2) are resolved.
- **Rationale:** The history entry structure depends on bootstrap compatibility (operation name, formula storage, reference_design). Specifying the print format before the structure is finalized would require revision.

### Outcome

All 18 Pass 1 issues resolved in `plans/spec-propensity.md`. Three new error classes added:
`surveywts_error_reference_weights_nonpositive`, `surveywts_error_propensity_level_not_in_reference`,
`surveywts_error_propensity_hessian_singular`. `survey_taylor` argument renamed to `reference` throughout.

---

## 2026-05-19 — Stage 4 Pass 2: Issues 19–25 (Bootstrap Compatibility Audit)

### Context

Cross-checking the `ipw()` history entry against `plans/spec-methodology-nps-bootstrap.md`
"Required `ipw()` history entry structure". The bootstrap reads this entry to re-run propensity
estimation in Level A and B draws. Six incompatibilities found; all resolved before the
history entry structure could be finalized and the Console Output GAP could be resolved.

### Questions & Decisions

**Q: Should `operation` be `"propensity_ipw"` or `"ipw"`? (Issue 19)**
- Options considered:
  - **`"ipw"`:** Matches the function name; shorter; what the bootstrap doc expects
  - **`"propensity_ipw"`:** More descriptive; disambiguates from future IPW variants
- **Decision:** `"ipw"`.
- **Rationale:** `"ipw"` is what the quasi-randomization bootstrap searches for in `@metadata@weighting_history`. Changing the bootstrap doc to match `"propensity_ipw"` would introduce drift in the authoritative contract. `ipw()` is the only function that produces this entry; the prefix is redundant.

**Q: Should the formula be stored as a deparsed string or as a formula object? (Issue 20)**
- Options considered:
  - **Formula object (`formula = selection`):** Bootstrap passes directly; display string derived at print time via `deparse()`
  - **Both (`formula` + `selection_formula`):** Redundant; string always derivable from object
  - **Deparsed string only:** Fragile for bootstrap use; requires `as.formula()` with environment management
- **Decision:** Store the formula object under field name `formula`; derive display string at print time.
- **Rationale:** Bootstrap re-use requires the object. Redundant string field adds API surface with no benefit.

**Q: Should `reference_design` be stored in the history entry? (Issue 21)**
- Options considered:
  - **Store `reference_design = reference`:** Level B bootstrap automatic; history self-contained; slight memory cost
  - **Require user to re-pass `reference_sample` each time:** Degrades UX; user must remember
- **Decision:** Store `reference_design = reference`.
- **Rationale:** The bootstrap doc explicitly requires this field for Level B. Without it, Level B is permanently unavailable regardless of user intent.

**Q: Should `estimator` be recorded? (Issue 22)**
- Options considered:
  - **Add `estimator = "ht"` (hard-coded for now)**
  - **Leave absent; bootstrap assumes `"ht"`**
- **Decision:** Add `estimator = "ht"`.
- **Rationale:** One trivial field prevents the bootstrap from hard-coding an assumption. Future Hájek support sets this to `"hajek"`.

**Q: Should `trim` store the logical flag, the count, or both? (Issue 23)**
- Options considered:
  - **`trim = <logical>` + `n_trimmed = <integer>`:** Bootstrap uses `trim` to decide whether to re-trim; `n_trimmed` retained as diagnostic
  - **`trim = <logical>` only:** Loses the count diagnostic
- **Decision:** Add `trim = <logical>` alongside the existing `n_trimmed`.
- **Rationale:** IQR-based trim bound is recomputed from each draw's weights, so storing the count is insufficient for bootstrap replay. Retaining `n_trimmed` preserves a useful diagnostic.

**Q: Should `method` be `"logit"` or `"logistic"` — and which document is authoritative? (Issue 24)**
- **Decision:** Update bootstrap doc example to `"logit"`.
- **Rationale:** The propensity spec is the source of truth. The bootstrap doc's example was written before the spec settled the method value names.

**Q: Should `ipw()` record `targets_from_reference = FALSE`? (Issue 25)**
- **Decision:** Yes — record `targets_from_reference = FALSE` as the default; note that downstream `rake()`/`calibrate()` are responsible for setting it to `TRUE`.
- **Rationale:** Documents the default and responsibility boundary before the bootstrap spec is written. Prevents the bootstrap implementer from finding a missing field.

**Q: What is the Console Output format for `ipw()` history entries? (Issue 13, now unblocked)**
- **Decision:** `ipw  [~ <formula>, <method>, n_ref=<n_reference>, N_hat=<estimated_population_size>]`. Fields `trim`, `n_trimmed`, `estimator`, `reference_design`, and `targets_from_reference` not shown in the one-line summary (accessible via `@metadata@weighting_history`).
- **Rationale:** Concise one-line format consistent with existing history entry rendering. Formula is the most diagnostic field for identifying the history step; N_hat allows quick weight-scale sanity check.

### Outcome

All 7 Pass 2 issues resolved. `ipw()` Output Contract now has a fully specified,
bootstrap-compatible history entry structure. Console Output GAP resolved. Spec bumped to
v0.3 — Approved for implementation.

Fields added to history entry: `formula` (renamed from `selection_formula`; now a formula object),
`estimator = "ht"`, `trim = <logical>`, `reference_design`, `targets_from_reference = FALSE`.
Bootstrap doc updated: `method = "logistic"` → `method = "logit"`.

---

## 2026-05-19 — Stage 4 Pass 3: Issues 26–32 (API/Implementation Audit)

### Context

Pass 3 found 7 issues — 3 blocking and 4 required/suggestion — stemming from mismatches
between the spec's description of internal APIs and their actual implementation in `R/utils.R`.

### Questions & Decisions

**Q: How should `ipw()` emit `surveywts_error_formula_variable_not_in_reference` when `.validate_formula_variables()` hard-codes a different class? (Issue 26)**
- Options considered:
  - **Add `error_class = NULL` parameter to helper:** Backward-compatible; Rule 7 passes the new class explicitly.
  - **Inline validation in `ipw()`:** Minor DRY violation; avoids modifying shared helper.
- **Decision:** Add `error_class = NULL` to `.validate_formula_variables()`.
- **Rationale:** Maintains DRY; existing callers are unaffected by the default. §VIII notes the parameter addition.

**Q: `.trim_weights_internal()` returns `$has_trimmed`, not `$n_trimmed` — spec was wrong. Fix spec or fix helper? (Issue 27)**
- Options considered:
  - **Fix spec text:** Trivial; the helper is already correct per the Utilities spec.
  - **Add `$n_trimmed` to helper:** Modifies a shipped helper to fix a spec error; over-engineering.
- **Decision:** Fix spec: Rule 16 now reads `$has_trimmed`; sets `n_trimmed = sum(result$has_trimmed)`.

**Q: Console Output section had three stale/inconsistent elements — how to fix? (Issue 28)**
- **Decision:** Fixed all three: (a) stale `"propensity_ipw"` replaced with `"ipw"`; (b) formula added to first code block; (c) print header updated to match actual `methods-print.R` output (`# A calibrated survey design: N observations, M variables`, etc.).

**Q: Spec says `.format_history_step()` needs no changes, but it has no `"ipw"` branch. How to handle? (Issue 29)**
- **Decision:** Add explicit note in Console Output section that `.format_history_step()` in `R/utils.R` must be extended with an `"ipw"` case.
- **Rationale:** The spec said "No new print method required" — true, but the helper still needed extension. Made the requirement explicit.

**Q: Should `maxit = 0L` produce an error or a warning? (Issue 30)**
- Options considered:
  - **Error `surveywts_error_propensity_invalid_maxit`:** Clean; stops the user before dubious output is produced.
  - **Warning with `iterations = 0`:** Still returns uniform weights of 2; less clean.
- **Decision:** Error. Rule 12 validates `maxit >= 1L`.

**Q: How to test `surveywts_warning_propensity_glm_convergence`? `control = list(maxit = 1)` was suggested but doesn't work. (Issue 31)**
- **Decision:** Remove the invalid approach; use perfect-separation dataset (binary covariate where all nonrespondents = 1, all respondents = 0). Added concrete data-construction hint.
- **Rationale:** The GLM's `maxit` is hard-coded internally; `adjust_nonresponse(control = ...)` has no path to override it.

**Q: Should `epsilon <= 0` be an error or just a `@param` note? (Issue 32)**
- Options considered:
  - **Error `surveywts_error_propensity_invalid_epsilon`:** Consistent with Issue 30; catches a confusing user error.
  - **`@param` note only:** Proportionate; the case is narrow.
- **Decision:** Error. Consistent with `maxit` validation (Issue 30); both NR control arguments validated together.

### Outcome

All 7 Pass 3 issues resolved. Two new error classes added:
`surveywts_error_propensity_invalid_maxit`, `surveywts_error_propensity_invalid_epsilon`.
`.validate_formula_variables()` gains `error_class = NULL` parameter.
`.format_history_step()` extension for `"ipw"` explicitly required in spec.
Behavior Rules renumbered: old 12–18 → new 14–20; new Rules 12–13 added for maxit/epsilon.
Spec bumped to v0.3 — approved for implementation (all passes complete).

---

## 2026-05-20 — Inline Spec Amendment: `ipw()` signature — `predictors` arg + arg reorder

### Context

After reviewing `surveycore::survey_glm()`'s dual formula/programmatic interface, the question
arose whether `ipw()` should support a `predictors = c("gender", "age")` alternative to
`selection = ~gender + age` for `lapply()` use cases.

### Questions & Decisions

**Q: Should `ipw()` add a `predictors` argument (programmatic alternative to `selection`)?**
- Options considered:
  - **Add `predictors`:** Consistent with `survey_glm()`; enables `lapply()` iteration over
    covariate sets without string-formula manipulation.
  - **Formula only:** Simpler signature; programmatic users can build formulas via
    `stats::reformulate()` themselves.
- **Decision:** Add `predictors = NULL` as a programmatic alternative to `selection = NULL`.
  Mutually exclusive; error if both or neither provided.
- **Rationale:** Consistency with surveyverse API pattern established in `survey_glm()`;
  genuine `lapply()` use case for iterating over covariate sets.

**Q: What argument order should `ipw()` use with the new `predictors` arg?**
- Options considered:
  - **`data, selection, reference, predictors`:** Original order with `predictors` appended.
  - **`data, reference, selection, predictors`:** Groups the two survey objects together
    (`data`, `reference`) and the two formula alternatives together (`selection`, `predictors`).
- **Decision:** `data, reference, selection = NULL, predictors = NULL, method, ...`
- **Rationale:** Semantic grouping: `data` + `reference` are both survey-related inputs;
  `selection` + `predictors` are adjacent formula alternatives. Cleaner than splitting
  formula args around `reference`.

### Outcome

`ipw()` signature amended to:
`ipw(data, reference, selection = NULL, predictors = NULL, method, maxit, epsilon, trim, wt_name)`
Two new error classes added: `surveywts_error_selection_missing`,
`surveywts_error_selection_conflict`. Spec §III behavior rules renumbered; `0a/0b/0c` added.
Plan updated: Task 1.1 (13 classes, up from 11), Task 1.2 (arg order), Task 1.4 (new happy
path + 2 error paths), Task 1.9 (23 rules, up from 20; `@param` count; `@examples`).

---

## 2026-05-20 — Stage 3 Resolve: Implementation Plan Issues 8–12 (Pass 2)

### Context

Working through 6 issues from `plans/plan-review-propensity.md` Pass 2. One blocking issue
(unspecified `survey_nonprob` construction pattern), five required issues (missing history
fields, missing `@reference_sample` test, wrong constructor API in two locations, missing
changelog files).

### Questions & Decisions

**Q: Should `ipw()` accept `survey_nonprob` as input (like `rake()`/`calibrate()`) to avoid the novel `data.frame` → `survey_nonprob` construction? (Issue 8 discussion)**
- Options considered:
  - **`survey_nonprob`-only input:** Matches existing pattern; construction is trivial via `.update_survey_weights()`. But NPS data starts as a raw `data.frame` with no weights; user would need placeholder weights just to call the function.
  - **`data.frame` input (current spec):** Primary NPS use case; `ipw()` is the entry point for weight creation. Requires specifying the `as_survey_nonprob()` construction pattern explicitly in the plan.
- **Decision:** Keep `data.frame` input (current spec). Fix Issue 8 by specifying the explicit two-step pattern in the plan.
- **Rationale:** Requiring a pre-weighted `survey_nonprob` adds friction to the primary workflow. The construction novelty is a plan gap, not a design problem.

**Q: Which surveycore datasets should be used for `ipw()` `@examples`? (Issue 12)**
- Options considered:
  - **`pew_npors_2025` (NPS) + `acs_pums_wy` (reference):** ACS is the best probability reference but variable names differ substantially from NPORS.
  - **`ns_wave1` (NPS) + `gss_2024` (reference):** `ns_wave1` is an online panel (non-probability); GSS is a probability sample. `gender` coding is 1/2 in both (just different column names: `gender` vs `sex`); `age` is directly shared. One rename line needed.
- **Decision:** `ns_wave1` (NPS) + `gss_2024` (reference). Rename `gss_2024$sex → gender`. Selection: `~gender + age`.
- **Rationale:** `ns_wave1` is confirmed as a non-probability sample. GSS is a well-known probability sample with design variables (`vpsu`, `vstrat`, `wtssps`). The online-panel-vs-GSS pairing is a canonical IPW example in the survey methods literature. Minimal harmonization (one rename, no value recoding).

### Outcome

All 6 Pass 2 issues resolved. Plan updated with: explicit `as_survey_nonprob()` + history-append
pattern for Rule 20; `step` and `timestamp` fields in the bespoke history entry; `@reference_sample`
assertion in Category 1; corrected `survey_taylor(variables = list(...))` API in Task 1.3b;
`ns_wave1` + `gss_2024` `@examples`; changelog file entries in both PR file lists.

---

## 2026-05-19 — Stage 3 Resolve: Implementation Plan Issues 1–7

### Context

Working through 7 issues from `plans/plan-review-propensity.md` Pass 1.
One blocking issue (contradicted return contract), three required issues
(missing coverage criterion, weak trim test, ambiguous adjustment scope),
and three suggestions (match.arg, NPS reference helper, NULL wt_name).

### Questions & Decisions

**Q: Should `.fit_participation_propensity()` return a plain vector or a named list? (Issue 1)**
- Options considered:
  - **Plain vector:** Code template showed `drop(link(X_nps %*% gamma))` — simple but makes convergence detection impossible in `ipw()`
  - **Named list `list(scores, converged, final_delta)`:** Matches implementation notes; `ipw()` checks `result$converged` to emit the NR non-convergence warning
- **Decision:** Named list. Code template updated to initialize `converged <- FALSE`, set `converged <- TRUE` on `break`, and return `list(scores, converged, final_delta)`.
- **Rationale:** The Category 4 warning test (`maxit = 1L`) is untestable with a plain-vector return. The list form was already the documented recommendation in the implementation notes.

**Q: Should the extreme-adjustment check in Task 2.5 Step 11 use all-unit or respondent-only weights? (Issue 4)**
- Options considered:
  - **All-unit `weight_vec`:** Inflates denominator; makes warning harder to trigger; incorrect per implementation notes
  - **Respondent-only subset:** Matches "evaluated only for respondents" note; makes Category 5 low-response-rate test reliable
- **Decision:** Respondent-only. Step 11 rewritten to extract `resp_idx`, `resp_wts`, `resp_scores` explicitly.

**Q: How to handle invalid `method` argument in `ipw()`? (Issue 5)**
- Options considered:
  - **`match.arg(method)`:** Standard R idiom; produces informative base R error
  - **Explicit `cli_abort()` with new error class:** Full classed coverage
- **Decision:** `match.arg(method)` as Behavior Rule 0. Consistent with R idiom; no precedent for classing this error in existing surveywts functions.

**Q: Should `test-nonprob-ipw.R` use an inline or helper-based `survey_taylor` reference? (Issue 6)**
- **Decision:** Add `make_nps_reference(n = 1000, seed)` to `helper-test-data.R` as Task 1.3b. Consistent with the `make_survey_replicate()` pattern.

### Outcome

All 7 issues resolved. Plan is approved for implementation. Start with PR 1 (`feature/ipw`).

---

## 2026-05-21 — Spec Amendment v0.5: `missing_method` + `mice_args` (NA handling)

### Context

After PR 1 (`feature/ipw`) was implemented, it became clear the original hard-error on NAs
(Rule 9, `surveywts_error_formula_variable_has_na`) was undocumented assumption rather than
a deliberate design choice — no decision log entry existed for it. Review of Lenau et al.
(2021) §3.4.6.2 identified two methodologically supported approaches for handling missing
covariate values in non-probability sample propensity models: treating missing values as a
separate category so all units receive weights, and imputing before weighting. `nonprobsvy`
was also reviewed; it hard-codes `na_action = na.omit` on the full dataset and emits no
warning, which is too blunt for `ipw()`'s weight-production context. The argument name
`na_action` was also rejected as it implies an R `na_action` function, which `"separate"`
and `"impute"` are not.

### Questions & Decisions

**Q: Should `na_action` be renamed, and to what?**
- **Decision:** Rename to `missing_method`.
- **Rationale:** `na_action` implies an R function (like `na.omit`, `na.fail`). The new
  values `"separate"` and `"impute"` are methodological strategies, not functions.
  `missing_method` is descriptive and unambiguous.

**Q: What values should `missing_method` support?**
- **Decision:** `c("omit", "separate", "impute")` with `"omit"` as default.
- **Rationale:** `"omit"` (listwise deletion) preserves backward-compatible behavior.
  `"separate"` follows Lenau's WeightImp approach. `"impute"` follows Lenau's ImpWeight
  approach. Three methods cover the full spectrum of principled choices.

**Q: Should `"omit"` warn when rows are dropped?**
- **Decision:** Yes — emit `surveywts_warning_ipw_data_na_omitted` with count and variable
  names.
- **Rationale:** Dropped NPS rows receive no IPW weight and disappear from downstream
  estimates. This is more consequential than in a standard regression; users should be
  aware even when they chose `"omit"`.

**Q: What imputation package and method for `missing_method = "impute"`?**
- **Decision:** `mice::mice()` with default `method = "pmm"` (predictive mean matching),
  `m = 1` (single imputation, fixed).
- **Rationale:** PMM is the method used in Lenau et al. (2021) §3.4.6.2 for the ImpWeight
  approach and is robust to non-normality. `m = 1` matches Lenau's "single iteration"
  approach; multiple imputation with Rubin's rules pooling for propensity scores is deferred
  to a future phase. `mice` is in CRAN and widely used for survey imputation.

**Q: Should `mice` impute all columns or only selection variables with NAs?**
- **Decision:** Only selection variables with NAs are passed to `mice`.
- **Rationale:** Imputing unrelated columns wastes computation and introduces noise into
  the propensity model.

**Q: Should `missing_method` apply to `reference@data` NAs?**
- **Decision:** No — reference NAs are always listwise-deleted regardless of
  `missing_method`, with `surveywts_warning_ipw_reference_na_omitted`.
- **Rationale:** Lenau et al. (2021) explicitly applies listwise deletion to the EU-SILC
  probability reference before weight adjustment. Imputing within a survey design object
  requires accounting for the design structure, which is out of scope. Reference samples
  (probability surveys) typically have low missingness; listwise deletion is appropriate.

**Q: How should `missing_method = "separate"` handle numeric selection variables with NAs?**
- **Decision:** Error with `surveywts_error_separate_numeric_na`, naming the variable and
  advising `cut()` or `missing_method = "impute"`.
- **Rationale:** There is no natural "missing category" for a continuous predictor in
  `model.matrix()`. The mixed fallback (separate for factors, omit for numerics) is
  surprising and hard to document. An explicit error forces the user to make a deliberate
  choice. The `@param` documents this constraint.

**Q: Should `mice_args` allow overriding `m`?**
- **Decision:** No — `m` is fixed at `1L`. If the user passes `m` in `mice_args`, emit
  `surveywts_warning_ipw_mice_m_ignored` and use `m = 1L` anyway.
- **Rationale:** Multiple imputation with propensity score pooling is not specified in this
  phase. Allowing `m > 1` without implementing Rubin's rules pooling would silently use
  only the first imputed dataset, which is misleading.

### Outcome

Spec bumped to v0.5. `na_action` removed; `missing_method` and `mice_args` added to
signature and argument table. Rule 9 replaced with Rules 9–9d. Two new error classes:
`surveywts_error_separate_numeric_na`, `surveywts_error_mice_not_installed`. Three new
warning classes: `surveywts_warning_ipw_data_na_omitted`,
`surveywts_warning_ipw_reference_na_omitted`, `surveywts_warning_ipw_mice_m_ignored`.
`mice` added to `Suggests`. Lenau et al. (2021) added to `@references`. Test categories
updated with new happy-path, warning-path, and error-path cases.

---

## 2026-05-20 — Stage 3 Resolve: Implementation Plan Issues 14–19 (Pass 3)

### Context

Working through 6 issues from `plans/plan-review-propensity.md` Pass 3. No blocking issues;
four required (spec divergence from plan after `predictors` amendment, three stale counts in
acceptance criteria) and two suggestions (N_hat formatting, GLM non-convergence test robustness).

### Questions & Decisions

**Q: Should spec-propensity.md be updated to reflect the 2026-05-20 `predictors` amendment? (Issue 14)**
- **Decision:** Yes — update spec §III signature, argument table, behavior rules (add 0/0a/0b/0c),
  error table (add `surveywts_error_selection_missing`, `surveywts_error_selection_conflict`),
  §VIII conventions table, and example. Bump to v0.4.
- **Rationale:** Spec is the source of truth; plan and spec must agree on the API before implementation.

**Q: How should `estimated_population_size` be formatted in the `N_hat=` field? (Issue 18)**
- Options considered:
  - **`round()`:** Produces integer-looking output consistent with spec example (`N_hat=148392`).
  - **Raw numeric:** Full floating-point representation (e.g., `N_hat=148392.37`).
- **Decision:** `round(entry$estimated_population_size)` — integer, no decimal.
- **Rationale:** Matches spec example intent; prevents verbose snapshot output.

**Q: Should the GLM non-convergence test use 100% or partial separation? (Issue 19)**
- Options considered:
  - **100% separation:** Maximally triggers convergence warning but may push fitted values to
    exactly 0/1 on small datasets, accidentally triggering the degenerate-scores error instead.
  - **80/20 split with strong imbalance:** Still triggers non-convergence; scores stay in (0, 1).
- **Decision:** Allow implementer to use 80/20 if needed to keep scores strictly in (0, 1);
  note added to Task 2.2.
- **Rationale:** Small safety margin prevents a brittle test that fails on specific R versions
  or seeds.

### Outcome

All 6 Pass 3 issues resolved. `spec-propensity.md` bumped to v0.4 and is now in sync with
the plan. Three acceptance criteria counts corrected (error paths: 20→24, error classes: 11→13,
`@param` count: 8→9). N_hat formatted as `round()` in Task 1.7. GLM non-convergence test
construction clarified in Task 2.2.

---
