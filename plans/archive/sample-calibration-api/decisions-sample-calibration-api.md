# Decisions Log — surveywts sample-calibration-api

This file records planning decisions made during sample-calibration-api.
Each entry corresponds to one planning session.

---

## 2026-06-11 — Stage 2r Methodology Resolve

### Context

Resolving 8 issues from the Pass 1 methodology review of
`spec-sample-calibration-api.md`. Six were UNAMBIGUOUS (applied in batch);
two required a design decision.

### Questions & Decisions

**Q: Issue 5 — How should convergence detection be implemented when svrep does
not expose typed warning classes?**
- Options considered:
  - **Option A:** Keep string matching on "converge"; add a code comment
    noting fragility; add a `@details` note that partial convergence results
    are discarded.
  - **Option B:** Use `withCallingHandlers()` + rlang warning class inspection,
    fall back to string matching.
  - **Option C:** Do nothing.
- **Decision:** Option A — string match + document.
- **Rationale:** svrep does not expose a typed convergence warning class, so
  the string matching approach is the pragmatic baseline. The key risk (svrep
  changing message text) is low in practice and is now documented in the spec.
  A snapshot test will catch any future text change at CI time.

**Q: Issue 6 — What should happen to negative weights produced by linear
calibration (GREG)?**
- Options considered:
  - **Option A:** Clip to `.Machine$double.eps` and document in `@details` and
    the warning message that this breaks the calibration constraint.
  - **Option B:** Clip + renormalize to restore the calibrated weight sum.
  - **Option C:** Warn but do not clip; return negative weights as-is.
- **Decision:** Option A — clip + document.
- **Rationale:** Preserves the existing behavior (users relying on clipping
  are not broken). The important gap was that the spec was silent about the
  calibration constraint violation — this is now explicitly documented. Option
  B would impose an ad hoc renormalization that changes all other units' weights
  without statistical justification. Option C introduces negative weights that
  break downstream packages.

### Outcome

All 8 methodology issues resolved. Spec updated with per-method unit_scale
documentation, non-determinism warnings for both functions, explicit vcov
delegation note, replicate duplication limitation, convergence string-matching
note, negative weight clipping constraint violation documentation, and
weight-sum conservation statement for calibrate_to_estimate().

---

## 2026-06-11 — Stage 3r Spec Review Resolve

### Context

Resolving 14 issues (1 BLOCKING, 9 REQUIRED, 4 SUGGESTIONS) from the Pass 1
spec review of `spec-sample-calibration-api.md` and `test-spec-sample-calibration-api.md`.
All 14 issues were resolved with Option A (recommended option).

### Questions & Decisions

**Q: Issue 8 — Should level-label mismatch in `targets` trigger a surveywts
error or be delegated to svrep?**
- Options considered:
  - **Option A:** New error class `surveywts_error_targets_levels_mismatch`,
    validate before calling svrep.
  - **Option B:** Explicit known limitation; surface as
    `surveywts_error_calibration_failed`.
  - **Option C:** Do nothing.
- **Decision:** Option A — pre-validate levels with a new error class.
- **Rationale:** Level mismatches are among the most common user mistakes when
  specifying `targets` (e.g., `"Male"/"Female"` vs `"M"/"F"`); a clear early
  error with the mismatch identified prevents confusing svrep-internal failures.
  The validation cost is low (set comparison before svrep call).

**Q: Issue 13 — Should weight-sum conservation behavior be delegated to the
builder or specified explicitly?**
- Options considered:
  - **Option A:** Specify explicitly: internally consistent targets → weight
    sum equals N; inconsistent targets → svrep-implementation-defined.
  - **Option B:** Mark as HOLD.
  - **Option C:** Do nothing.
- **Decision:** Option A — verified via svrep intercept semantics.
- **Rationale:** The behavior is deterministic and knowable; delegating spec
  responsibility to the builder violates artifact-schemas.md.

### Outcome

All 14 spec review issues resolved. Key additions: `make_replicate_design()`
helper spec; `survey_taylor_obj` construction recipe; `test_invariants()` survey_replicate
branch; deterministic count-mismatch assertions; reproducibility tests for
`control_col_matches` and `col_selection`; `before_stats`/`after_stats` field
definitions (11-key lists from `.compute_weight_stats()`);
`surveywts_error_targets_levels_mismatch` new class; empty-targets edge case;
`error-messages.md` formula-class clean-up; `ignore.case = TRUE` for convergence
detection; "in-place" language fixed; weight-sum conservation specified; control
defaults confirmed to match svrep.

---

## 2026-06-11 — Stage 3r Spec Review Resolve (Pass 3)

### Context

Resolving 4 issues (2 REQUIRED, 2 SUGGESTIONS) from the Pass 3 spec review.
All four issues were resolved with Option A (recommended option).

### Questions & Decisions

**Q: Issue 15 — What should `targets_from_reference` store when `reference_design = NULL`?**
- Options considered:
  - **Option A:** Specify `FALSE` for the null case in both function contracts.
  - **Option B:** Reference the existing `calibrate_linear()` convention.
  - **Option C:** Do nothing.
- **Decision:** Option A — explicit `FALSE` in both contracts.
- **Rationale:** Removes builder guesswork; consistent with the general pattern
  of boolean provenance flags defaulting to `FALSE`.

**Q: Issue 18 — Does the stored `control` in history contain all known keys
(with defaults filled in) or only user-provided keys?**
- Options considered:
  - **Option A:** Full record — all known keys with defaults for omitted ones.
  - **Option B:** Sparse record — only user-provided keys.
  - **Option C:** Do nothing.
- **Decision:** Option A — complete record including defaults.
- **Rationale:** A complete record of effective calibration parameters (not just
  deviations from defaults) is more useful for provenance tracking and
  post-hoc debugging.

### Outcome

All 4 Pass 3 issues resolved. Spec updated with `targets_from_reference = FALSE`
default for both functions, explicit merged-list semantics for stored `control`,
`before_stats`/`after_stats` test rows added to both Happy path tables, and
"History entry parameters" test rows extended to cover `bounds`, `n_replicates`,
and `control_design_class`/`n_replicates_control` for `calibrate_to_survey()`.

---
