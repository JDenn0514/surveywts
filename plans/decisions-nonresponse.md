# Decisions Log — surveywts nonresponse

This file records planning decisions made during the Nonresponse phase.
Each entry corresponds to one planning session.

---

## 2026-05-12 — Methodology lock: Nonresponse phase

### Context

Nine open methodology issues (across two review passes) were resolved in this session. Five were unambiguous fixes applied in batch; four were judgment calls resolved individually.

### Questions & Decisions

**Q: Issue 9 — How should `redistribute_weights()` handle `survey_taylor`/`survey_nonprob` inputs when `reduce_if` rows would get weight 0 (violating the S7 strictly-positive-weights validator)?**
- Options considered:
  - **Option A:** Filter `reduce_if` rows from the output for survey objects (mirrors `adjust_nonresponse()` weighting-class behavior).
  - **Option B:** Disallow `survey_taylor` and `survey_nonprob` as inputs entirely; callers must convert to `weighted_df` first.
- **Decision:** Option A — filter `reduce_if` rows from output for survey objects.
- **Rationale:** Consistent with the existing `adjust_nonresponse()` contract. Users expect the same behavior from a general-purpose primitive. Explicitly documented in §V Output Contract.

**Q: Issue 3 — Should `calibrate_to_survey()` validate that primary and control designs use matching replicate schemes?**
- Options considered:
  - **Option A:** Error on scheme mismatch (`surveywts_error_replicate_scheme_mismatch`).
  - **Option B:** Warn on scheme mismatch (`surveywts_warning_replicate_scheme_mismatch`) and proceed.
  - **Option C:** No check; delegate to svrep.
- **Decision:** Option B — warn, then proceed.
- **Rationale:** Users may have legitimate reasons for scheme names that differ by convention (e.g., `"boot"` vs. `"bootstrap"`). A warning gives actionable information without being falsely restrictive.

**Q: Issue 6 — Should `glm()` convergence warnings in propensity-cell be caught and re-wrapped as a surveywts-classed warning?**
- Options considered:
  - **Option A:** Catch with `withCallingHandlers` and re-issue as `surveywts_warning_propensity_model_not_converged`.
  - **Option B:** Let glm warnings pass through; document the pass-through behavior in `@details`.
- **Decision:** Option B — document pass-through, no re-wrapping.
- **Rationale:** The glm warning message is informative enough; re-wrapping adds `withCallingHandlers` complexity without materially improving user experience.

**Q: Issue 8 — Should propensity-cell use unweighted or weighted quantiles to define cell boundaries?**
- Options considered:
  - **Option A:** Keep unweighted quantiles (as currently specified); add `@details` note.
  - **Option B:** Switch to weighted quantiles (equal weighted population per cell).
- **Decision:** Option A — unweighted quantiles, documented.
- **Rationale:** svrep's nonresponse vignette uses `ntile()` (unweighted equal-size bins), matching our `quantile()` + `findInterval()` approach. This is also the conventional textbook implementation (Rosenbaum & Rubin 1984; Little 1986). The note prevents future implementers from switching to weighted quantiles.

### Unambiguous fixes applied (no judgment required)

- **Issue 1:** Weight conservation test for `calibrate_to_survey()` corrected — asserts `sum(w_new) ≈ sum(control weights)`, not `sum(w_original)`.
- **Issue 2:** `surveywts_error_vcov_cholesky_failed` added to §IV Error Table, §X integration list; `vcov_estimate` description updated to "positive definite"; Behavior Rule 3 updated to catch/re-throw instead of propagate-as-is.
- **Issue 4:** Multivariate normality assumption for `calibrate_to_estimate()` perturbation added to §IV as a "Statistical Assumptions" block.
- **Issue 5:** Propensity-as-known limitation added to §VI Statistical Assumptions with `@note` directive.
- **Issue 7:** MAR assumption for propensity-cell method added to §VI Statistical Assumptions with `@note` directive.

### Outcome

The spec is methodology-locked at version 0.2. All statistical assumptions are documented (MAR, multivariate normality, propensity-as-known, unweighted quantiles). All error/warning inconsistencies are resolved. Start Stage 3 in a new session to run the code/architecture review.

---

## 2026-05-12 — Stage 4 Code Review: Nonresponse phase

### Context

15 issues from the Stage 3 adversarial code review were resolved in this session. Two issues (1, 2) were already resolved in the spec before the session began. The remaining 13 were resolved with four judgment calls (Issues 4, 7, 8, 13) and nine unambiguous fixes.

### Questions & Decisions

**Q: Issue 4 — Where does the `bounds` parameter for logit calibration belong?**
- Options considered:
  - **Option A:** Inside the `control` list alongside `maxit`/`epsilon`.
  - **Option B:** As a top-level argument at the same level as `method`.
- **Decision:** Option B — top-level argument `bounds = list(lower = -Inf, upper = Inf)`.
- **Rationale:** svrep exposes `bounds` as a top-level parameter in both `calibrate_to_sample()` and `calibrate_to_estimate()`. It is a calibration parameter (what the weights may be), not a convergence parameter (how the algorithm runs). Grouping it with `control` would conflate two distinct concerns.

**Q: Issue 7 — Should `calibrate_to_estimate()` have `formula` before or after `estimate`/`vcov_estimate`?**
- Options considered:
  - **Option A:** `(design, formula, estimate, vcov_estimate, ...)` — formula first.
  - **Option B:** `(design, estimate, vcov_estimate, formula, ...)` — original order.
- **Decision:** Option A — `formula` before `estimate` and `vcov_estimate`.
- **Rationale:** `formula` defines the model matrix that determines what `estimate` names must match. Users need to know the formula before they know how to construct `estimate`. Consistent with `calibrate_to_survey()` where `formula` follows the design objects.

**Q: Issue 8 — Should `wt_name` collision with an existing non-weight column be an error or silent overwrite?**
- Options considered:
  - **Option A:** Error (`surveywts_error_wt_name_conflict`) — strict validation.
  - **Option B:** Silent overwrite — consistent with R's default column replacement.
- **Decision:** Option A — error on collision.
- **Rationale:** Silent overwrite would violate CLAUDE.md's "design variables are sacred" principle. The package's strict validation stance is consistent with erroring here.

**Q: Issue 13 — Should the no-respondents-in-propensity-cell error be a new class or reuse `surveywts_error_no_recipients_in_group`?**
- Options considered:
  - **Option A:** New class `surveywts_error_no_respondents_in_propensity_cell` with cell index + propensity range in the message.
  - **Option B:** Reuse `surveywts_error_no_recipients_in_group`.
- **Decision:** Option A — new class with diagnostic information.
- **Rationale:** The propensity-cell scenario (near-perfect separation → empty cell) is common in practice and benefits from a specific, actionable message. Cell index and propensity range let the user diagnose which covariate is causing the problem.

### Unambiguous fixes applied (no judgment required)

- **Issue 3:** Warning test added to §VIII for `surveywts_warning_replicate_scheme_mismatch`.
- **Issue 5:** `surveywts_error_estimate_has_na` added — behavior rule 2a, error table, §VIII test entry, §X.
- **Issue 6:** Formula error tests for `calibrate_to_estimate()` added to §VIII.
- **Issue 9:** NA error test entries for `redistribute_weights()` added to §VIII.
- **Issue 10:** Weight validation error test entries for `redistribute_weights()` added to §VIII.
- **Issue 11:** §VI Behavior Notes updated to explicitly call `.validate_formula_variables()` (shared helper from §VII).
- **Issue 12:** `.validate_formula()` call added to §VI Behavior Notes; `surveywts_error_formula_invalid` added as reuse entry to §VI error table and §VIII test plan.
- **Issue 14:** Test file name corrected to `test-05-nonresponse.R`.
- **Issue 15:** Dual test pattern note added to §VIII preamble.

### Outcome

The spec is approved at version 0.3. Start `/implementation-workflow` in a new session to build the implementation plan.

---

## 2026-05-12 — Stage 4 Code Review Pass 2: Nonresponse phase

### Context

6 issues from the Stage 3 Pass 2 adversarial review were resolved in this session. All 4 REQUIRED issues were unambiguous fixes. Issue 1 (SUGGESTION, carried from Pass 1) was already resolved in the spec.

### Questions & Decisions

No judgment calls were required. All resolutions were unambiguous targeted additions.

### Unambiguous fixes applied (no judgment required)

- **Issue 16:** `bounds` added to Behavior Rule 5 in both §III and §IV, so implementers know to pass `bounds` to `svrep::calibrate_to_sample()` and `svrep::calibrate_to_estimate()`.
- **Issue 17:** Warning path test block added to §VIII for `calibrate_to_survey()`: `method = "linear"` producing negative full-sample weights → `surveywts_warning_negative_calibrated_weights`.
- **Issue 18:** Warning paths section added to §VIII for `calibrate_to_estimate()`: same warning for linear calibration producing negative weights.
- **Issue 19:** Two missing error tests added to §VIII error paths for `redistribute_weights()`: `surveywts_error_weights_na` and `surveywts_error_wt_name_empty`.
- **Issue 20:** `control` argument description for `redistribute_weights()` updated to state "Merged with defaults `list(min_cell = 20, max_adjust = 2.0)`."
- **Issue 1:** Already present in §II table — no change needed.

### Outcome

The spec is approved at version 0.4. All Pass 2 issues resolved. Start `/implementation-workflow` in a new session to build the implementation plan.

---

## 2026-05-13 — Stage 4 Code Review Pass 3: Nonresponse phase

### Context

4 issues from the Stage 3 Pass 3 adversarial review were resolved in this session. 1 REQUIRED issue and 3 SUGGESTIONS — all trivial fixes with no judgment calls.

### Questions & Decisions

No meaningful judgment calls were required. All four resolutions followed straightforwardly from the existing spec principles.

### Unambiguous fixes applied (no judgment required)

- **Issue 21:** Removed `.compute_model_matrix_totals()` from the §II file map — it was a leftover from an earlier draft; `svrep` handles model matrix totals internally. The §II file map now accurately lists `.to_svyrep_design()`, `.validate_formula_variables()`, and `.validate_formula()`.
- **Issue 22:** Clarified the "Zero-weight rows in `increase_if`" edge case in §VIII: it is caught by `surveywts_error_weights_nonpositive` before redistribution logic runs (tests the weight validator, not redistribution).
- **Issue 23:** Added a missing sparse-cell warning test to §VIII propensity-cell edge cases: one propensity cell with fewer than `control$min_cell` respondents → `surveywts_warning_class_near_empty`.
- **Issue 24:** Removed `by_variables` from the propensity-cell history entry parameters in §VI — `by` is not used in propensity-cell and recording an ignored argument in the weighting history is misleading.

### Outcome

The spec is approved at version 0.5. All Pass 3 issues resolved. Start `/implementation-workflow` in a new session to build the implementation plan.

---

## 2026-05-13 — Stage 3 Plan Review Resolution: Nonresponse phase

### Context

5 open issues from the plan-review Pass 1 and Pass 2 were resolved in this session (Issues 6–10). Issues 1–5 were already resolved in prior sessions.

### Questions & Decisions

**Q: Issue 6 — Does `.compute_model_matrix_totals()` appearing in spec §II but not in the plan represent a missing helper or a stale artifact?**
- **Decision:** Stale artifact — the function was already removed from spec §II in Pass 3 (Issue 21 in the decisions log above). The discrepancy no longer exists.
- **Rationale:** User confirmed the spec §II update. No plan change required.

### Unambiguous fixes applied (no judgment required)

- **Issue 9 (BLOCKING):** Added `combined.weights = FALSE` to the `survey::svrepdesign()` call in PR 1 step 5, with an explanatory comment that surveywts stores replicate weights as scale factors matching the `combined.weights = FALSE` convention of `svrep::as_bootstrap_design()` and `survey::as.svrepdesign()`.
- **Issue 10:** Added `tests/testthat/_snaps/05-nonresponse.md` to the PR 4 file list with a note that the stub snapshot is deleted and new propensity-cell error snapshots are added.
- **Issue 7:** Added "Test coverage ≥ 95% (checked via `covr::package_coverage()` before opening PR)" to the acceptance criteria of all four PRs.
- **Issue 8:** Added `.claude/rules/surveywts-conventions.md` to the PR 2 and PR 3 file lists, and added corresponding task steps (step 17 in PR 2, step 12 in PR 3) to update the `@family` table with `sample-calibration` and `redistribute_weights()` respectively.

### Outcome

The implementation plan is fully approved. All open issues resolved. Hand off to `/r-implement`, starting with PR 1 (`feature/nonresponse-infrastructure`).

---
