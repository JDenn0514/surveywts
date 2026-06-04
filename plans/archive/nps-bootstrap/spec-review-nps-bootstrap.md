# Spec Review: nps-bootstrap — Pass 1 (2026-05-22)

**Target:** `plans/spec-methodology-nps-bootstrap.md` (methodology-locked v1.1)

Note: This review is run against the methodology-locked document, which serves
as the de-facto spec for this feature. Several sections a formal spec requires —
test plan, formal function contracts, `@param` documentation — are absent.
Those gaps are flagged here.

---

### Section: `create_bootstrap_weights()` API Changes

---

**Issue 1: `replicates` conditional default is not implementable as shown in the signature**
Severity: BLOCKING
Violates engineering-preferences.md §3 — under-engineered contract

The spec states: "When `type` is `'quasi-randomization'` or `'hybrid'`, the
default is `replicates = 200L`." But the function signature shown is
`replicates = 500L`. R does not support argument default values that depend on
other arguments. If the signature stays as `replicates = 500L`, NPS types will
default to 500, not 200, directly contradicting the spec.

The standard R pattern for a conditional default is `replicates = NULL`
internally resolved to 200L or 500L based on `type`. The signature must be
updated and the internal resolution logic specified.

Options:
- **[A] Change signature to `replicates = NULL`, resolve internally:** `if (is.null(replicates)) replicates <- if (type %in% c("quasi-randomization", "hybrid")) 200L else 500L`. Document both defaults in `@param`. Effort: low, Risk: low, Impact: correct behavior for all type values, Maintenance: low.
- **[B] Keep `replicates = 500L`, document that NPS users should pass `replicates = 200L`:** Effort: low, Risk: medium (users won't read docs), Impact: routinely slow exploratory runs for NPS types.
- **[C] Do nothing** — NPS types default to 500 regardless of spec text.

**Recommendation: [A]**

---

**Issue 2: `reference_sample = survey_replicate` rejection is absent from the validation table**
Severity: REQUIRED
Violates code-style.md §3 — error table must be complete

The spec states: "`survey_replicate` is not supported as a `reference_sample`."
But the validation table contains no row for this case and no corresponding
error class is defined. The table only covers wrong `data` input class and
missing reference designs. A user passing a replicate-weighted reference survey
has no specified behavior.

Options:
- **[A] Add a validation row:** `reference_sample` is a `survey_replicate` → `surveywts_error_reference_sample_class`. The existing row "reference_sample is not a survey_taylor → surveywts_error_reference_sample_class" already covers this — the error class name implies `survey_taylor` is the only valid class, so passing `survey_replicate` should already be caught by that row. Clarify the existing row to read: "`reference_sample` is not `NULL` and is not a `survey_taylor`" → `surveywts_error_reference_sample_class`. Effort: low (editorial), Risk: low, Impact: closes the gap without a new error class.
- **[B] Do nothing** — implementer must guess whether `survey_replicate` is caught by the existing `reference_sample_class` check or silently passes through.

**Recommendation: [A]**

---

**Issue 3: Behavior when `reference_sample` is supplied with a probability-sample `type` is unspecified**
Severity: SUGGESTION
Violates engineering-preferences.md §4 — handle more edge cases, not fewer

If a user calls `create_bootstrap_weights(data, type = "Rao-Wu", reference_sample = ref)`,
the spec says nothing. Is the argument silently ignored? Does it warn? Silently
ignoring it surprises users who believe the reference sample is being used.

Options:
- **[A] Emit `surveywts_warning_reference_sample_ignored` when `reference_sample` is non-NULL and `type` is a probability-sample type.** Effort: low, Risk: low, Impact: surfaces unexpected workflow.
- **[B] Silently ignore** — document in `@param reference_sample` that the argument is only used for NPS types. Effort: low (editorial), Risk: low, Impact: relies on users reading docs.
- **[C] Do nothing** — behavior unspecified.

**Recommendation: [A]**

---

### Section: Return Type for NPS Types

---

**Issue 4: `@calibration` property is undefined; `survey_nonprob` class may not support it**
Severity: BLOCKING
Violates code-style.md §2 — S7 property contract must be complete

The spec states the function returns `survey_nonprob` with "`@calibration`
populated." The `survey_nonprob` class inherits from `survey_base`, which
defines `@data`, `@variables`, and `@metadata`. No `@calibration` top-level
property exists in the class definition. The spec does not say whether:
1. `@calibration` is a new property to be added to `survey_nonprob`, or
2. `@calibration` means `@metadata@calibration` (a metadata sub-property), or
3. The repweight columns are stored elsewhere and `@calibration` is a misnomer

If a new top-level property is required, the `survey_nonprob` class definition
must be updated — that is a class API change that needs its own spec section.

Options:
- **[A] Clarify that repweight storage uses `@data` only (no `@calibration`), remove the `@calibration` reference:** Repweight columns `repwt_1`...`repwt_R` are added to `@data`; `@variables$replicate_weights` (or similar key) records which columns are repweight columns. Effort: low (editorial + class clarification), Risk: low, Impact: no class extension required.
- **[B] Specify `@calibration` as a new top-level property on `survey_nonprob`:** Define its type, default value, and what it holds (list of B replicate estimates or a matrix). Requires a class API change section in the spec. Effort: medium, Risk: medium (class change), Impact: clean separation of replicate-weight metadata from data.
- **[C] Do nothing** — implementer must decide how to extend the class, creating divergence risk.

**Recommendation: [A]** — repweight columns embedded in `@data` with a `@variables` key is consistent with how existing weight columns work in `survey_nonprob`.

---

**Issue 5: No analysis workflow defined for the returned replicate-weighted object**
Severity: BLOCKING
Violates engineering-preferences.md §3 — under-engineered

The spec states the returned object is "immediately ready for analysis without
an additional `as_survey_nonprob()` call." But no analysis function is specified
or referenced that accepts a `survey_nonprob` with repweight columns and
computes bootstrap variance estimates. The NPS types bypass svrep, so standard
`svrep` analysis functions don't apply directly. Without an analysis path, the
returned object is inert — users cannot compute a variance estimate from it.

If analysis functions are planned for a future release, the spec must say:
"Replicate weights are stored in `@data` as `repwt_1`...`repwt_R` for use by
future analysis functions; this release does not provide analysis functions for
replicate-weighted `survey_nonprob` objects." Otherwise the claim "immediately
ready for analysis" is misleading.

Options:
- **[A] Replace the claim with an honest deferred-use statement:** "Replicate weights stored in `@data` columns `repwt_1`...`repwt_R`. Bootstrap variance is computed via [function name] (future release) or by manually averaging over replicate estimates." Effort: low (editorial), Risk: low, Impact: honest API contract.
- **[B] Define a minimal analysis function in this release:** e.g., a `summarize_bootstrap()` that accepts the returned object and computes variance for a user-supplied estimate function. Effort: medium-high, Risk: medium (scope expansion), Impact: complete feature.
- **[C] Do nothing** — "immediately ready for analysis" remains in the spec with no concrete path.

**Recommendation: [A]** — scope expansion is not warranted; honest deferred-use statement closes the gap.

---

**Issue 6: Weighting history entry for `create_bootstrap_weights()` itself is unspecified**
Severity: REQUIRED
Violates surveywts-conventions.md §5 — metadata lifecycle

Every other weighting function (`calibrate()`, `rake()`, `ipw()`) appends an
entry to `@metadata@weighting_history`. The spec is silent on whether
`create_bootstrap_weights()` appends its own entry. If it does, the entry
structure needs to be defined (at minimum: `operation`, `step`, `timestamp`,
`type`, `replicates`, `seed`). If it doesn't, the spec must say so explicitly
and explain why.

Options:
- **[A] Specify a history entry:** `operation = "bootstrap_weights"`, `type = <type>`, `replicates = B`, `seed = seed`. Effort: low, Risk: low, Impact: consistent history lifecycle; future bootstrap-aware analysis functions can inspect it.
- **[B] Specify no history entry, with rationale:** Replicate weight creation is not a weighting step — it doesn't change the weights, only adds auxiliary replicate columns. Document this explicitly. Effort: low (editorial), Risk: low, Impact: consistent if the convention is that history tracks weight modifications only.
- **[C] Do nothing** — implementer decides; history behavior diverges from convention.

**Recommendation: [A]** — consistent history makes the object self-describing; analysis functions that need to know B and the method can read it without external state.

---

### Section: Method 1 — Quasi-Randomization Bootstrap Algorithm

---

**Issue 7: Draw failure handling is unspecified**
Severity: REQUIRED
Violates engineering-preferences.md §4 — handle more edge cases, not fewer

Within each bootstrap draw, `ipw()` is re-run on a resampled NPS dataset
`S_A^(b)`. Bootstrap samples drawn with replacement can produce degenerate
inputs: all units from one group, zero variation in a covariate, or a
propensity model that fails to converge. The spec does not state what happens
when a draw fails.

Unspecified behavior includes:
- Propensity model fit failure (complete/quasi-complete separation in logit)
- `rake()` or `calibrate()` convergence failure on the resampled data
- All propensity estimates at the trim boundary in a draw (producing identical
  weights)

Options:
- **[A] Specify that failed draws are skipped (with a counter):** After the loop, if fewer than `B * 0.9` draws succeeded, emit `surveywts_warning_bootstrap_draws_failed` with a count of failures. Effort: low-medium, Risk: low, Impact: robust behavior; users see warning without silent bias.
- **[B] Error on first failed draw:** `surveywts_error_bootstrap_draw_failed` with the draw number and underlying model error. Effort: low, Risk: medium (may abort for typical survey data), Impact: forces user to debug propensity model.
- **[C] Do nothing** — propensity failure propagates as an uncontrolled error from the underlying model, crashing the entire bootstrap run.

**Recommendation: [A]**

---

**Issue 8: `seed` behavior within the bootstrap loop is unspecified**
Severity: REQUIRED
Violates engineering-preferences.md §5 — explicit over clever

The function signature includes `seed = NULL`. The spec does not state:
1. Whether `set.seed(seed)` is called once before the loop (fixing the full
   random sequence) or derived per-draw (a seed schedule), and
2. Whether the seed controls only NPS resampling, or also the reference survey
   resampling in Level B/hybrid.

Without this, two implementations using the same seed will produce different
replicate sequences if they make different assumptions about seeding strategy.

Options:
- **[A] Specify: `set.seed(seed)` is called once immediately before the loop, controlling the entire random sequence (NPS resampling, reference resampling if applicable, and any within-ipw randomness).** Effort: low (editorial), Risk: low, Impact: reproducible bootstrap runs.
- **[B] Specify per-draw seeds derived from seed:** `draw_seed <- seed + b` for each draw b. Effort: low, Risk: low, Impact: draws are individually reproducible; different from [A] in random number consumption pattern.
- **[C] Do nothing** — each implementation chooses its seeding strategy.

**Recommendation: [A]** — single pre-loop `set.seed()` is the standard R bootstrap pattern and matches user expectations.

---

### Section: Method 2 — Hybrid Bootstrap Algorithm

---

**Issue 9: Source of `N` (population size) for the population total estimator is unspecified**
Severity: REQUIRED
Violates engineering-preferences.md §5 — explicit over clever

The hybrid bootstrap total estimator formula includes `N` (population size):
`θ̂^(b) = (N/n_A) Σ ŷ_i^(b)`.
The spec does not say where `N` comes from. Plausible sources: a property on
`survey_nonprob` (e.g., from a previous `poststratify()` step), an argument
to `create_bootstrap_weights()`, extracted from the reference design's known
population size, or unspecified.

Without this, the population total path is unimplementable for hybrid.

Options:
- **[A] Add `population_size = NULL` argument to `create_bootstrap_weights()`:** Required for `type = "hybrid"` when the total estimator is used; otherwise only the mean estimator is available. Error if `NULL` and a total is requested. Effort: low-medium, Risk: low.
- **[B] Read `N` from `@metadata` if a `poststratify()` step is in the history:** Effort: medium, Risk: medium (only works if user poststratified), Impact: implicit contract.
- **[C] Remove the population total formula and support only the mean estimator in this release:** Effort: low, Risk: low, Impact: narrower feature scope; totals can be added when analysis functions are specced.
- **[D] Do nothing** — N is undefined; the total path cannot be implemented.

**Recommendation: [C]** — the analysis path for the hybrid total is not yet specified (Issue 5); supporting only the mean estimator keeps the scope tight and consistent with the deferred-analysis-API approach.

---

**Issue 10: "With auxiliary weights w_i" path in the hybrid estimator is undefined**
Severity: REQUIRED
Violates engineering-preferences.md §5 — explicit over clever

Hybrid bootstrap step 5 includes: "With auxiliary weights w_i (e.g., from a
quota allocation): multiply ŷ_i^(b) · w_i and normalize accordingly." The
spec does not say what `w_i` is, where it comes from (a column in `@data`? an
argument?), or what "normalize accordingly" means (divide by sum of weights?
divide by population size? Hájek-style ratio?).

Options:
- **[A] Remove the auxiliary-weights clause from this spec:** Auxiliary-weighted mass imputation is a distinct estimand that can be specced when `mass_imputation()` is implemented. The current spec should cover the base case only. Effort: low (editorial), Risk: low, Impact: tighter scope.
- **[B] Specify `w_i` as the existing weight column in `@data` (the final calibrated IPW weight from history), define "normalize accordingly" as Hájek-style (divide by sum of w_i).** Effort: low (editorial), Risk: low, Impact: complete path, but conflates IPW weights with auxiliary quota weights.
- **[C] Do nothing** — the clause is present but unimplementable.

**Recommendation: [A]** — this path depends on `mass_imputation()` which is unimplemented; scope to the base mean/total estimator only.

---

### Section: Open Design Questions

---

**Issue 11: Q2 (in-loop rake/calibrate compatibility) is an unresolved engineering prerequisite**
Severity: REQUIRED
Violates engineering-preferences.md §3 — under-engineered

Open Design Question Q2 asks: "Confirm that `rake()` and `calibrate()` can
accept a bare `survey_nonprob` constructed in-loop without issues (particularly
around history and metadata initialization)." This is not a question that can
be deferred to implementation — it is a prerequisite that determines whether
the algorithm is implementable as described. If `rake()` and `calibrate()` fail
on a minimal in-loop `survey_nonprob`, the algorithm requires a workaround
(calling internal helpers directly, bypassing the public API).

The spec must either confirm compatibility or specify an alternative call
mechanism for the in-loop case.

Options:
- **[A] Resolve Q2 by reading the current `rake()` / `calibrate()` implementations:** Confirm or deny that a `survey_nonprob` with minimal construction (data + weight column + empty history) is accepted. If accepted, close Q2. If not, specify the in-loop call mechanism (e.g., call `.rake_engine()` directly). Effort: low (code inspection), Risk: low, Impact: closes the last unresolved engineering question.
- **[B] Do nothing** — implementer must figure it out, potentially discovering mid-implementation that a workaround is needed.

**Recommendation: [A]** — this is a one-function inspection, not a design discussion. Resolve it during Stage 4.

---

**Issue 12: Resolved open questions Q1, Q3, Q4 remain framed as open in the document**
Severity: SUGGESTION

Q4 (B default) and Q3 (`targets_from_reference` flag) are both resolved — the
decisions are documented in `decisions-nps-bootstrap.md` and reflected in the
spec body. Q1 has a recommendation (Option A) and was applied. All three
remain in the "Open Design Questions" section without a resolved status marker,
suggesting they are still open. This creates confusion for implementers reading
the doc.

Options:
- **[A] Mark each resolved question with its decision inline:** "**Resolved:** [decision text]. See `decisions-nps-bootstrap.md`." Or remove the section entirely now that all questions are resolved. Effort: low, Risk: low.
- **[B] Do nothing** — stale open questions in the doc; may confuse the implementer.

**Recommendation: [A]**

---

### Section: Test Plan (Missing)

---

**Issue 13: No test plan exists**
Severity: BLOCKING
Violates testing-standards.md §2 — test plan required for all exported function changes

The spec contains no test plan. A formal test plan is required before
/implementation-workflow handoff. For `create_bootstrap_weights()` with two
new `type` values, the test plan must cover at minimum:

**Required test blocks (per testing-standards.md §2):**
1. **Happy path — quasi-randomization, Level A:** `survey_nonprob` with ipw history, `targets_from_reference = FALSE` → returns `survey_nonprob` with `repwt_1`...`repwt_R` columns; `test_invariants()` passes.
2. **Happy path — quasi-randomization, Level B:** Same but with `targets_from_reference = TRUE` in ipw history.
3. **Happy path — hybrid:** `survey_nonprob` with mass_imputation history → returns `survey_nonprob` with repweight columns. *(deferred until `mass_imputation()` exists)*
4. **Variance correctness — quasi-randomization:** With known DGP, bootstrap SE within `1e-1` of theoretical SE at B ≥ 200. (Numerical tolerance for bootstrapped variance is wider than for calibration — the spec must state the accepted tolerance.)
5. **Error paths:** One block per row in the validation table (8 error classes). Dual pattern (class= + snapshot) for all.
6. **Edge case — NPS with n = 10:** Very small sample; bootstrap completes without error.
7. **Edge case — `seed` reproducibility:** Same seed produces identical replicate columns on two calls.
8. **Draw failure handling:** Degenerate resampled NPS triggers draw-skip behavior and warning (if Issue 7 resolution is Option A).
9. **History entry:** Returned object has correct bootstrap history entry in `@metadata@weighting_history`.

Options:
- **[A] Add a "Test Plan" section to the spec before Stage 4 completes:** Use the structure above. Effort: low-medium, Risk: low.
- **[B] Do nothing** — implementation begins without a test plan; test coverage is discovered rather than designed.

**Recommendation: [A]**

---

### Section: Error Documentation

---

**Issue 14: New error classes are not flagged as additions to `plans/error-messages.md`**
Severity: REQUIRED
Violates code-style.md §3 — all new classes must be added to the canonical error table

The spec introduces 8 new error classes:
- `surveywts_error_qr_bootstrap_requires_nonprob`
- `surveywts_error_hybrid_bootstrap_requires_nonprob`
- `surveywts_error_qr_bootstrap_no_reference`
- `surveywts_error_hybrid_bootstrap_no_imputation_history`
- `surveywts_error_hybrid_bootstrap_no_reference`
- `surveywts_error_reference_sample_class`
- Any additional classes from Issue 7 and Issue 3 resolutions

None of them are accompanied by CLI message templates. Per `code-style.md`,
these must be added to `plans/error-messages.md` with message templates before
implementation begins. The spec does not flag this as a required pre-implementation
step.

Options:
- **[A] Add a "New Error Classes" section that lists each class with its `"x"` bullet template:** Format: `surveywts_error_qr_bootstrap_requires_nonprob` — `"x" = "{.arg data} must be a <survey_nonprob> for type {.val 'quasi-randomization'}."`. Effort: low, Risk: low, Impact: implementer can write error code directly from the spec.
- **[B] Do nothing** — implementer drafts message templates ad hoc; they may not match `code-style.md §3` format.

**Recommendation: [A]**

---

## Summary (Pass 1)

| Severity | Count |
|---|---|
| BLOCKING | 4 |
| REQUIRED | 8 |
| SUGGESTION | 2 |

**Total issues:** 14

**Overall assessment:** The statistical algorithms and Level A/B detection are
well-specified (methodology lock is solid), but four blocking gaps prevent
implementation: the conditional `replicates` default is not expressible in the
shown signature, `@calibration` is an undefined property on the return type,
no analysis path exists for the returned object, and no test plan exists. The
eight required issues are all resolvable in Stage 4 without architectural
changes. None of the issues indicate a flaw in the chosen methods.

---

## Spec Review: nps-bootstrap — Pass 2 (2026-05-26)

**Target:** `plans/spec-nps-bootstrap.md` v1.0 (updated post-Pass 1 resolution)

### Prior Issues (Pass 1)

| # | Title | Status |
|---|---|---|
| 1 | `replicates` conditional default not implementable as shown | ✅ Resolved — signature now `replicates = NULL`; §III.A specifies internal resolution |
| 2 | `reference_sample = survey_replicate` rejection absent | ✅ Resolved — §VIII validation table clarified: "not NULL and not survey_taylor" catches all invalid classes including `survey_replicate` |
| 3 | Behavior when `reference_sample` supplied with prob-sample type | ✅ Resolved — `surveywts_warning_reference_sample_ignored` defined in §VIII and §IX |
| 4 | `@calibration` property undefined | ✅ Resolved — repweights stored in `@data`; `@variables$repweights` key defined in §III.D |
| 5 | No analysis workflow defined for returned object | ✅ Resolved — §III.D honest deferred-use statement added |
| 6 | Weighting history entry for `create_bootstrap_weights()` unspecified | ✅ Resolved — §VI fully specifies the entry structure |
| 7 | Draw failure handling unspecified | ✅ Resolved — §IV specifies catch-skip-count; 10% threshold; `surveywts_error_bootstrap_all_draws_failed` |
| 8 | `seed` behavior within bootstrap loop unspecified | ✅ Resolved — `set.seed(seed)` once before loop; §III.C documents RNG restoration difference |
| 9 | Source of `N` for hybrid population total estimator | ✅ Resolved — total path deferred; mean estimator only for hybrid stub |
| 10 | Auxiliary-weights clause in hybrid estimator undefined | ✅ Resolved — removed from scope |
| 11 | Q2 (in-loop rake/calibrate compatibility) unresolved | ✅ Resolved — §II confirms rake/calibrate accept `survey_nonprob`; no workaround needed |
| 12 | Resolved open questions framed as open | ✅ Resolved — §XIII shows all four questions resolved with decisions |
| 13 | No test plan | ✅ Resolved — §X comprehensive test plan added |
| 14 | New error classes not flagged for `plans/error-messages.md` | ✅ Resolved — §IX lists all new classes with `"x"` templates |

All 14 Pass 1 issues resolved. The updated spec is substantially more complete.

---

### New Issues

#### Section: §III — `create_bootstrap_weights()` Modified API

---

**Issue 15: `mse` boolean-to-logical conversion before `.convert_and_call()` is not specified**
Severity: REQUIRED
Violates engineering-preferences.md §5 — explicit over clever

The spec changes `mse` from `logical(1)` to `character(1)` with three valid
values. But `.convert_and_call()` (the existing probability-sample dispatch
path) passes `mse` to `svrep::as_bootstrap_design()` as a logical — confirmed
by `replicate-weights.R:149` which stores `mse = isTRUE(svyrep_obj$mse)`.

The spec at §III.B shows:
```r
} else {
  # Probability-sample path — existing behavior
  .convert_and_call(...)
}
```
without specifying that `mse` must be converted before the call. An implementer
reading this will either pass the character string to `.convert_and_call()` (which
then passes it to `svrep`, causing an error) or infer the conversion — neither
is acceptable; the conversion must be explicit in the spec.

The correct mapping (per §III argument table) is:
`"mse"` → `TRUE`, `"uncentered"` → `FALSE` for `.convert_and_call()`.
`"chrostowski"` must be rejected before reaching this path (already handled
by `surveywts_error_chrostowski_prob_sample`).

Options:
- **[A] Add a conversion step to §III.B type dispatch:** Before calling `.convert_and_call()`, show `mse_logical <- mse == "mse"` and pass `mse = mse_logical` to `.convert_and_call()`. Effort: low (editorial), Risk: low, Impact: implementer can write the conversion directly from the spec.
- **[B] Update `.convert_and_call()` to accept character `mse`:** Add mapping logic inside `.convert_and_call()`. Effort: low, Risk: medium (changes shared utility that other functions depend on), Impact: forces all callers to update.
- **[C] Do nothing** — implementer must infer the conversion from reading the existing code.

**Recommendation: [A]** — the conversion belongs in `create_bootstrap_weights()` body, not in the shared utility.

---

**Issue 16: Invalid `mse` value (including old boolean) produces an unclassed R error**
Severity: REQUIRED
Violates code-style.md §3 — every user-facing error must have a typed class

When `mse = TRUE` or `mse = FALSE` (the old API) is passed to the new function,
`rlang::arg_match()` or `match.arg()` will throw an unclassed R error with a
generic message, not a typed `surveywts_error_*` with a migration suggestion.
The spec does not define what happens for invalid `mse` values.

The failure mode is especially harmful because users upgrading from the old API
(`mse = TRUE`) will see a confusing base-R error with no guidance to update their
call to `mse = "mse"`.

Options:
- **[A] Add a pre-validation step before `rlang::arg_match()`:** Detect if `mse` is a logical scalar and emit `surveywts_error_mse_not_character` with a migration message: `"v" = "Replace {.code mse = TRUE} with {.code mse = \"mse\"}, and {.code mse = FALSE} with {.code mse = \"uncentered\"}."` Effort: low, Risk: low, Impact: clear migration path for existing callers.
- **[B] Accept the default `match.arg()` error** and document in the `@param` that boolean inputs are no longer accepted. Effort: low, Risk: medium (bad user experience for upgraders), Impact: confusing failure mode.
- **[C] Do nothing** — old callers get an untyped R error.

**Recommendation: [A]** — add the boolean-detection check and the new class to §IX.

---

**Issue 17: `weighted_df` + probability-sample type missing from input/output matrix**
Severity: SUGGESTION
Violates code-style.md §3 — contract completeness

The input/output matrix in §I covers `weighted_df` only for NPS types:
`weighted_df + quasi-randomization or hybrid → Error: NPS types require survey_nonprob`.
It does not show what happens with `weighted_df + Rao-Wu` (or any probability-sample
type). The existing `.validate_replicate_input()` presumably rejects `weighted_df`
(since only `survey_taylor` and `survey_nonprob` are listed as accepted), but the spec
doesn't confirm this, leaving the matrix incomplete for probability-sample paths.

Options:
- **[A] Add rows for `weighted_df + prob-sample types` and `data.frame + prob-sample types`:** Both should show "Error: caught by `.validate_replicate_input()`". This closes the matrix without new error classes. Effort: low (editorial).
- **[B] Do nothing** — the matrix only documents changes; existing behavior is implied.

**Recommendation: [A]** — a complete matrix is the spec standard and avoids "what about weighted_df + Rao-Wu?" confusion during implementation.

---

#### Section: §IV — Algorithm: Quasi-Randomization Bootstrap

---

**Issue 18: Level B — `svrep::as_bootstrap_design()` receives a `survey_taylor` S7 class, not a `survey.design`**
Severity: BLOCKING
Violates engineering-preferences.md §3 — under-engineered contract

§IV Level B specifies:
```r
svrep::as_bootstrap_design(ref_design, replicates = B)
```
where `ref_design` is a `survey_taylor` (surveycore's S7 class). `svrep` does
not know about surveycore's S7 classes — it expects a `survey.design` object
from the `survey` package.

The existing probability-sample path handles this conversion inside
`.convert_and_call()` at `replicate-weights.R:124`:
```r
svydesign_obj <- surveycore::as_svydesign(data)
```
Level B must do the same conversion before calling `svrep`. The spec as written
will produce `Error in svrep::as_bootstrap_design(ref_design, ...)` at runtime —
`svrep` has no method for surveycore's S7 class.

Options:
- **[A] Add a conversion step to §IV Level B, Step 2:** Before the `svrep::as_bootstrap_design()` call, specify `ref_svydesign <- surveycore::as_svydesign(ref_design)`, then call `svrep::as_bootstrap_design(ref_svydesign, replicates = B)`. Effort: low (editorial), Risk: low, Impact: implementable algorithm.
- **[B] Wrap in a helper function that accepts `survey_taylor`:** Define `.resample_reference(ref_design, B)` that handles the conversion internally. Effort: low-medium, Risk: low, Impact: hides the conversion; cleaner algorithm description.
- **[C] Do nothing** — implementer must infer the conversion from reading `.convert_and_call()`.

**Recommendation: [A]** — explicit conversion step in the spec; it's one line and removes a guaranteed runtime error.

---

**Issue 19: Level B — failure of `svrep::as_bootstrap_design()` (pre-loop) is unhandled**
Severity: REQUIRED
Violates engineering-preferences.md §4 — handle more edge cases, not fewer

The draw failure handling in §IV covers errors thrown *within* the bootstrap loop
(per-draw failures). Level B calls `svrep::as_bootstrap_design(ref_svydesign, replicates = B)`
*before* the main loop as a pre-computation step. If this call fails (e.g., the
reference design is too small, or the design structure is incompatible with SRSWR
resampling), the error propagates as an uncontrolled error from `svrep`, not as a
typed `surveywts_error_*`.

Options:
- **[A] Wrap the pre-loop `svrep` call in `tryCatch()`:** On failure, emit `surveywts_error_reference_bootstrap_failed` with the underlying `svrep` message in the `"i"` bullet. Add class to §IX. Effort: low-medium, Risk: low.
- **[B] Note in the spec that pre-loop failures are uncontrolled errors from `svrep`:** Document this explicitly so the implementer doesn't add catch logic. Effort: low (editorial), Risk: low (but users get unhelpful errors).
- **[C] Do nothing** — uncontrolled error from `svrep` propagates.

**Recommendation: [A]** — a reference design that is too small is a plausible user error that deserves a typed message.

---

**Issue 20: `trim` type in §VII example is inconsistent with `ipw()` signature**
Severity: REQUIRED
Violates engineering-preferences.md §5 — explicit over clever

§VII Required `ipw()` History Entry Fields shows:
```r
trim = c(0.05, 0.95),     # or NULL
```
But `ipw()` takes `trim = FALSE` — a `logical(1)`, not a numeric vector. The
actual history entry (confirmed at `R/nonprob-ipw.R:743`) stores:
```r
trim = trim,   # trim is logical(1): TRUE or FALSE
```
The spec example `c(0.05, 0.95)` is incorrect. An implementer reading §VII will
write in-loop bootstrap code expecting a numeric vector for the trim field and
may add unnecessary coercion logic or fail when they get a logical.

The in-loop `ipw()` call at §IV correctly passes `trim = ipw_entry$trim` (a
logical), so the algorithm is functionally correct. The §VII example is the
only error.

Options:
- **[A] Correct §VII example to `trim = TRUE` (or `FALSE`):** Remove the `c(0.05, 0.95)` example value; show both possible values. Add a note: "Logical scalar; the trim threshold is re-estimated within each draw per the 'Trim note' in §IV." Effort: low (editorial).
- **[B] Do nothing** — implementer may add unnecessary coercion code that silently no-ops.

**Recommendation: [A]** — one-line fix that prevents a guaranteed confusion during implementation.

---

#### Section: §III.D — Output Contract / §X — Test Plan

---

**Issue 21: Calling `create_bootstrap_weights()` twice on same object — column collision not specified**
Severity: REQUIRED
Violates engineering-preferences.md §4 — handle more edge cases, not fewer

The output contract (§III.D) specifies that `@data` gains columns `repwt_1`...`repwt_B`.
If a user calls `create_bootstrap_weights()` on the same `survey_nonprob` a second
time (perhaps to generate more replicates or with a different seed), the new call
will attempt to add `repwt_1`...`repwt_B` to `@data`, but those column names already
exist. The spec is silent on this scenario.

Unspecified behavior: overwrite silently? Error? Auto-rename to `repwt2_1`...?

Options:
- **[A] Specify that a second call overwrites existing `repwt_*` columns:** The new columns replace the old ones; the history entry from the previous call remains. Emit `surveywts_warning_repweights_overwritten` if any `repwt_*` column already exists. Add the warning class to §IX. Effort: low, Risk: low, Impact: predictable behavior with user notification.
- **[B] Error if `@variables$repweights` is already populated:** `surveywts_error_repweights_already_present`. User must start from the original (pre-bootstrap) `survey_nonprob`. Effort: low, Risk: low, Impact: strict but clear.
- **[C] Do nothing** — column collision causes an uncontrolled error or silent overwrite depending on R's `cbind` behavior.

**Recommendation: [A]** — warning-and-overwrite is the least surprising behavior for an iterative workflow.

---

**Issue 22: Print behavior for `survey_nonprob` with repweight columns is not specified**
Severity: REQUIRED
Violates testing-standards.md §2 — print snapshot required for every result class with a print method

§III.D specifies that the returned object is a `survey_nonprob` (same class as
input, same `print()` method). But the returned object has a new `@variables$repweights`
key that did not exist before. If the existing `print()` method for `survey_nonprob`
iterates over `@variables`, the output will include the new repweights key — changing
the print format compared to a plain `survey_nonprob` without repweights.

The spec does not:
1. Say whether the print output changes for a repweight-augmented `survey_nonprob`
2. Show a verbatim example of what the new print output looks like
3. Include a print snapshot test block in §X

Options:
- **[A] Specify print behavior explicitly:** State whether the existing print method shows `@variables$repweights` and what it looks like, or whether the `print()` method should be extended to summarize repweight information (e.g., "Bootstrap replicates: 200"). Add a print snapshot test block to §X. Effort: low-medium (requires deciding on the print format).
- **[B] State that print output is unchanged (print method not extended):** "`survey_nonprob` with repweights prints identically to one without; `@variables$repweights` is not displayed in the standard print format." Add a confirmation test that print output does not change. Effort: low (editorial + one test block).
- **[C] Do nothing** — print behavior undefined; print snapshot test absent from test plan.

**Recommendation: [A]** — explicitly choosing to show "Bootstrap replicates: B" in the print output makes the object self-describing and is consistent with the intent to use this object in analysis. The print format must be shown as a verbatim example.

---

**Issue 23: `test-spec-nps-bootstrap.md` does not exist as a standalone artifact**
Severity: REQUIRED
Violates pipeline-spec skill — two independent artifacts required

The pipeline-spec skill requires two independent artifacts: `plans/spec-{id}.md`
(builder's input) and `plans/test-spec-{id}.md` (tester's input). The test plan
is embedded in §X of `spec-nps-bootstrap.md` but no standalone
`plans/test-spec-nps-bootstrap.md` exists.

This matters for the implementation workflow: the builder agent reads the spec;
the tester agent reads the test-spec. If the test plan is only in the spec, the
tester must read the entire spec to find their input, and the builder receives
unnecessary testing detail that may distract from the implementation contract.

Options:
- **[A] Extract §X into a standalone `plans/test-spec-nps-bootstrap.md`:** Copy the test plan section verbatim, add the standard header (target file, function under test, source spec), and link back to `spec-nps-bootstrap.md §X`. Keep §X in the spec as a summary reference. Effort: low (copy-extract).
- **[B] Leave test plan embedded in the spec:** Document that for this feature the test plan is in §X of the spec; tester reads the full spec. Effort: none, Risk: process deviation from the pipeline standard.
- **[C] Do nothing** — tester has no standalone input file.

**Recommendation: [A]** — extract now before the implementation workflow begins; it takes minutes and keeps the pipeline standard intact.

---

**Issue 24: Level B test block (Block 2) verifies history label but not reference resampling**
Severity: SUGGESTION
Violates testing-standards.md §2 — test must cover the specific behavior, not just a label

§X Block 2 checks that the history entry has `level = "B"` and repwt columns are
present — but it does not verify that the reference was actually resampled in Level B
vs. Level A. A broken implementation that always uses the fixed reference (Level A
path) but writes `level = "B"` to the history entry would pass Block 2.

Options:
- **[A] Add a differential test:** Run both Level A and Level B on the same data with the same seed. Verify that repwt columns differ between the two outputs. If Level B is working correctly (reference resampled), its repwt columns will differ from Level A's (reference fixed) at the same seed. Effort: low (one additional assertion in Block 2).
- **[B] Do nothing** — Level B is tested only by presence of the history label.

**Recommendation: [A]** — the differential assertion is the only way to confirm Level B is actually doing something different from Level A.

---

#### Section: §IV — `targets_from_reference` source (DRY)

---

**Issue 25: `targets_from_reference` is described in two places with subtly different fallback logic**
Severity: SUGGESTION
Violates engineering-preferences.md §1 — DRY

§IV (History replay structure) defines:
```r
targets_from_ref <- if (!is.null(calib_entry)) isTRUE(calib_entry$targets_from_reference) else FALSE
```
§VII (Required ipw() History Entry Fields) says: "If the ipw entry carries the
field, it is read from there as a fallback; but the calibration entry is
authoritative."

These are not equivalent. §IV ignores the ipw entry entirely (only reads from
`calib_entry` or defaults to `FALSE`). §VII implies a three-way fallback:
(1) calibration entry → (2) ipw entry → (3) FALSE. §IV is the implementation
spec; §VII is the field description. The inconsistency means an implementer
reading §VII will add an extra fallback that §IV does not specify.

Options:
- **[A] Remove the fallback clause from §VII:** Delete "If the ipw entry carries
  the field, it is read from there as a fallback." Keep §IV as the single
  authoritative source for the fallback logic. Effort: low (editorial).
- **[B] Add the three-way fallback to §IV explicitly:** Update the `targets_from_ref`
  assignment to check `calib_entry$targets_from_reference` first, then
  `ipw_entry$targets_from_reference`, then `FALSE`. Effort: low (editorial + one line).
- **[C] Do nothing** — both descriptions remain; implementer picks one.

**Recommendation: [A]** — §IV is the implementation spec; §VII is a field reference.
The fallback policy belongs in §IV. Remove the conflicting note from §VII.

---

### Summary (Pass 2)

| Severity | Count |
|---|---|
| BLOCKING | 1 |
| REQUIRED | 7 |
| SUGGESTION | 3 |

**Total new issues:** 11

**Overall assessment:** All 14 Pass 1 issues are resolved — the spec is substantially
more complete. One new blocking issue (Issue 18: Level B passes a `survey_taylor` S7
object directly to `svrep::as_bootstrap_design()` without converting to `survey.design`
first, causing a guaranteed runtime error) must be resolved before implementation.
Seven required issues are straightforward editorial or structural fixes. The spec
is close to implementation-ready but needs the blocking conversion step and the
missing `test-spec-nps-bootstrap.md` artifact before the implementation workflow begins.

---

## Literature Gaps — For Pass 3 Resolution

**Source:** `plans/gaps-nps-bootstrap.md` (2026-05-26)
**Papers:** Elliott & Valliant (2017); Chrostowski et al. (2025); Kolenikov (2014); AAPOR (2022)
**Status:** Unresolved — to be addressed in Pass 3

These issues were identified by cross-referencing the spec against the source
literature and the current `R/nonprob-ipw.R` implementation. They are appended
here for consolidated Pass 3 review. Issues are numbered continuing from Pass 2.

---

### Section: §IV — Within-Draw Algorithm

---

**Issue 26: `missing_method` not replayed in within-draw `ipw()` call**
Severity: BLOCKING
Violates engineering-preferences.md §4 — handle more edge cases, not fewer

`R/nonprob-ipw.R:742` writes `missing_method = missing_method` into the
weighting history entry. The within-draw `ipw()` call shown in spec §IV
(`plans/spec-nps-bootstrap.md:269–278`) does not replay it — `missing_method`
defaults to `"omit"` in each draw.

What breaks: If the original `ipw()` used `missing_method = "separate"`, NA
rows were recoded to `"(Missing)"` and kept in `@data`. The within-draw call
silently drops those rows via `"omit"`, producing replicate weights on a
structurally smaller sample than the full-sample estimate. Bootstrap SE is
computed from mismatched numerator and denominator.

`missing_method` is also absent from the required history fields table in
spec §VII (`plans/spec-nps-bootstrap.md:428–439`), even though the
implementation stores it and the bootstrap must replay it.

Options:
- **[A] Add `missing_method = ipw_entry$missing_method` to the within-draw `ipw()` call in §IV; add `missing_method` to the required fields table in §VII.** Effort: low (editorial), Risk: low, Impact: correctness for any user who called `ipw()` with `missing_method = "separate"` or `"impute"`.
- **[B] Do nothing** — bootstrap SEs are silently wrong for non-`"omit"` missing methods.

**Recommendation: [A]**

---

**Issue 27: SRS variance understatement not documented in man page contract**
Severity: REQUIRED
Violates engineering-preferences.md §5 — explicit over clever

AAPOR (2022) §4 and Chrostowski et al. (2025) §2.2 state that SRSWR bootstrap
for NPS "likely understates sampling variability" because the actual NPS
recruitment mechanism cannot be replicated. This understatement is structural
and not fixable by increasing `replicates`. The spec's §III deferred-use
statement mentions only the missing analysis function; systematic variance
understatement is not documented anywhere.

The analogous `ipw()` man page at `R/nonprob-ipw.R:188–190` already warns
that naive SEs understate variance; `create_bootstrap_weights()` needs a
different but analogous caveat.

Options:
- **[A] Add a `@details` bullet to the `create_bootstrap_weights()` man page contract in spec §III:** "SRSWR resampling cannot replicate the original NPS recruitment mechanism. Bootstrap standard errors from `'quasi-randomization'` likely understate true sampling variability (AAPOR 2022, §4). Variance understatement is not reduced by increasing `replicates`. Additional understatement occurs when NPS units share cluster structure (e.g., panel recruitment), because SRSWR ignores within-cluster correlation." Effort: low (editorial).
- **[B] Do nothing** — users assume bootstrap SEs are well-calibrated.

**Recommendation: [A]**

---

**Issue 28: `estimator` field in spec §VII shows `"hajek"` but implementation stores `"ht"` (will be `"ipw2"` after ipw-extensions)**
Severity: REQUIRED
Violates engineering-preferences.md §5 — explicit over clever

`R/nonprob-ipw.R:745` currently stores `estimator = "ht"` (changing to
`"ipw2"` after the ipw-extensions PR merges). Spec §VII
(`plans/spec-nps-bootstrap.md:435`) shows `estimator = "hajek"`. The
weights are `w = 1 / p_hat` with no renormalization — HT style. The
spec example value is wrong; a builder reading §VII verbatim would store
the wrong field value in bootstrap history replay.

Options:
- **[A] Correct §VII example to match the actual stored value:** Use `estimator = "ipw2"` (anticipating the ipw-extensions merge) or `estimator = "ht"` (current). Add a note: "This value is read from the `ipw()` history entry; the bootstrap does not change it." Effort: low (one-line editorial).
- **[B] Do nothing** — builder stores wrong field; creates audit confusion.

**Recommendation: [A]** — coordinate with ipw-extensions merge timing; use `"ipw2"`.

---

**Issue 29: Per-draw trim bounds vary; spec does not state this**
Severity: REQUIRED
Violates engineering-preferences.md §5 — explicit over clever

`R/nonprob-ipw.R:715–718` computes the trim threshold from within-draw
weights (`median(w) + 5 * IQR(w)`) — not from a fixed full-sample threshold.
Each draw produces a different effective trim bound. Spec §IV
(`plans/spec-nps-bootstrap.md:271`) says `trim = ipw_entry$trim` (replay
the flag) but does not acknowledge that this means per-draw bounds.

An implementer might reasonably try to carry over the full-sample bound as
a fixed constant — a different statistical procedure. Per-draw bounds
propagate trim-threshold uncertainty through the bootstrap (methodologically
correct); fixed bounds do not.

Options:
- **[A] Add one sentence to §IV near the `trim` replay line:** "When `trim = TRUE`, the trimming threshold is re-estimated from within-draw weights (`median(w) + 5 * IQR(w)`) — not carried over from the full-sample call. This propagates trim-threshold uncertainty through the bootstrap." Effort: low (editorial).
- **[B] Do nothing** — implementer may use fixed bounds, producing a different procedure without realizing it.

**Recommendation: [A]**

---

**Issue 30: `S_A^(b)` paragraph misleads about weight normalization and "base weights"**
Severity: REQUIRED
Violates engineering-preferences.md §5 — explicit over clever

`R/nonprob-ipw.R:704` computes `w <- 1 / scores` with no renormalization.
Within-draw `ipw()` on `S_A_b` starts fresh from propensity estimation —
it ignores all existing weight columns. There is no "base weight" in this path.

Spec §IV (`plans/spec-nps-bootstrap.md:365–373`) says:
> "Each row carries the original base weight from the ipw history entry's input
> (or `data@data[[data@variables$weights]]` if no pre-ipw weight exists)."

This is misleading: `data@data[[data@variables$weights]]` IS the IPW weight
after the original `ipw()` call, not a base weight. Within-draw `ipw()` ignores
it entirely.

Options:
- **[A] Replace the `S_A^(b)` paragraph in §IV** with: "Within-draw `ipw()` receives `S_A_b` as a plain data frame. It does not read or use any weight column present in those rows; it fits the propensity model on the resampled units and computes fresh weights as `1 / p_hat`. The IPW weights from the full-sample call are irrelevant here." Also add to §III or §IV: "IPW weights are raw `1 / p_hat` values with no renormalization. The sum of weights estimates the population size." Effort: low (editorial).
- **[B] Do nothing** — implementer may add unnecessary weight-carrying logic or misunderstand the algorithm.

**Recommendation: [A]**

---

**Issue 31: Variance formula departure from Chrostowski et al. not justified**
Severity: SUGGESTION

Chrostowski et al. (2025) Eq. 5 uses `1/(B-1)` centered on the original
estimate. The spec uses `1/B` for the MSE form. Spec §IV
(`plans/spec-nps-bootstrap.md:351–358`) states the formula but gives no
rationale for the departure.

Options:
- **[A] Add one sentence after the variance formula in §IV:** "The `1/B` divisor (rather than `1/(B-1)` as in Chrostowski et al. 2025 Eq. 5) is consistent with standard replicate-weight variance practice (cf. Kolenikov 2014 §4.6)." Effort: low (editorial).
- **[B] Do nothing** — methodology reviewer will flag.

**Recommendation: [A]**

---

**Issue 32: Level B RNG independence mechanism underspecified**
Severity: REQUIRED
Violates engineering-preferences.md §5 — explicit over clever

Spec §IV says NPS and reference resamples use "separate independent random
sequences" (`plans/spec-nps-bootstrap.md:319–322`), but also specifies a
single `set.seed(seed)` before the loop (`plans/spec-nps-bootstrap.md:256–257`).

For Level B, `svrep::as_bootstrap_design()` is called *before* the main loop.
If `set.seed(seed)` precedes this pre-computation, both it and the main NPS
loop draw from the same initialized RNG stream — deterministically derived
from one seed, not statistically independent. The spec does not state: (a)
whether "independent" means statistically independent (requires two seeds) or
reproducibly deterministic (one seed); (b) the exact call ordering for Level B.

Options:
- **[A] Clarify §IV Level B setup:** "`set.seed(seed)` is called once, immediately before `svrep::as_bootstrap_design()`. Both the reference pre-computation and the main NPS resample loop draw from this initialized stream sequentially. 'Independent' means each draw's NPS resample and reference replicate use separate positions in the stream — not separate seeds. Results are exactly reproducible given the same `seed`." Effort: low (editorial).
- **[B] Do nothing** — implementer must choose seeding strategy; reproducibility semantics are ambiguous.

**Recommendation: [A]**

---

### Section: §III — Man Page Contract / Edge Cases

---

**Issue 33: `S_A^(b)` within-draw raking wording (covered by Issue 30)**
Severity: SUGGESTION

The within-draw raking base weight concern from Kolenikov §4.6 is satisfied
because within-draw `ipw()` starts fresh from propensity estimation (not from
calibrated weights). The Kolenikov caution does not apply here. This concern
is fully subsumed by the Issue 30 wording fix.

**Recommendation:** Close as covered by Issue 30. No independent action needed.

---

**Issue 34: No pre-loop calibration target consistency check**
Severity: SUGGESTION

If `calib_entry$margins` are inconsistent (margins for different variables
sum to different population totals), every draw will fail. The spec fires
`surveywts_error_bootstrap_all_draws_failed` post-loop with no diagnostic
about root cause.

Options:
- **[A] Add a pre-loop check in §IV prerequisites:** verify all calibration margins sum to a consistent population total; emit `surveywts_error_calibration_targets_inconsistent`. Add to `plans/error-messages.md`. Effort: low-medium.
- **[B] Do nothing** — fails loudly via the all-draws-failed error, but user sees no diagnostic.

**Recommendation: [A]** — low effort, high diagnostic value.

---

**Issue 35: NPS/reference overlap not validated or documented**
Severity: SUGGESTION

Chrostowski et al. (2025) states estimators assume no unit appears in both
samples. Overlap biases propensity estimates toward 0.5 for overlapping units.
The spec §VIII validation table has no overlap check.

Options:
- **[A] Add a `@details` note to the `create_bootstrap_weights()` man page contract in spec §III:** "The NPS and reference sample are assumed to be disjoint. If any unit appears in both, propensity estimates will be biased. No deduplication is performed; verify this precondition before calling." Effort: low (editorial).
- **[B] Do nothing** — silent bias in rare cases.

**Recommendation: [A]** — editorial only; no code change required.

---

**Issue 36: NPS clustering understatement not documented (covered by Issue 27)**
Severity: SUGGESTION

The NPS clustering caveat (SRSWR ignores within-cluster correlation) is
already part of the Issue 27 `@details` text. Resolving Issue 27 closes this.

**Recommendation:** Close as covered by Issue 27. No independent action needed.

---

**Issue 37: Small sampling fraction assumption not documented**
Severity: SUGGESTION

Elliott & Valliant (2017) §3: the Bayes-rule derivation of pseudo-weights
requires both NPS and reference to constitute small fractions of the population.
Not mentioned anywhere in the spec.

Options:
- **[A] Add one sentence to `@details` of `create_bootstrap_weights()` contract in spec §III:** "IPW pseudo-weights are theoretically justified when both the NPS and the reference sample are small fractions of the target population (Elliott & Valliant 2017). The approximation degrades as either sample approaches the population in size." Effort: low (editorial).
- **[B] Do nothing** — theoretical caveat undocumented.

**Recommendation: [A]**

---

**Issue 38: `@references` not required by spec for `create_bootstrap_weights()`**
Severity: SUGGESTION

Spec §III function contract has no `@references` requirement. Spec §XI
quality gates do not include a roxygen completeness check. The analogous
`ipw()` at `R/nonprob-ipw.R:202–214` provides the template.

Options:
- **[A] Add to §III or §XI:** "`create_bootstrap_weights()` must include a `@references` roxygen tag citing Elliott & Valliant (2017), Chrostowski et al. (2025), and Kolenikov (2014). Full citation details are in `plans/comprehension-nps-bootstrap.md`." Effort: low (editorial).
- **[B] Do nothing** — implementer omits citations.

**Recommendation: [A]**

---

**Issue 39: EC2 test case construction underspecified**
Severity: SUGGESTION

Spec §X Block EC2 says "Construct NPS such that every resample produces
degenerate propensity scores (e.g., single-level covariates after resampling)."
For a small NPS with a binary covariate where one level appears once, SRSWR
draws will frequently but not always exclude that level — degeneracy is not
guaranteed.

Options:
- **[A] Replace EC2 with a concrete construction:** "Construct an NPS of 3 rows where `selection = ~x` and `x` is a factor with two levels, but only one level appears (all rows have `x = 'A'`). The propensity model will have a collinear design matrix in every draw; each draw catches `surveywts_error_propensity_hessian_singular` (`R/nonprob-ipw.R:85–93`), increments `failed_draws`, and the post-loop check fires `surveywts_error_bootstrap_all_draws_failed`." Effort: low (editorial).
- **[B] Do nothing** — tester must discover a reliable degeneracy construction.

**Recommendation: [A]**

---

### Summary (Literature Gaps — Pass 3 Input)

| Severity | Count |
|---|---|
| BLOCKING | 1 |
| REQUIRED | 5 |
| SUGGESTION | 8 |

**Total new issues:** 14 (Issues 26–39)

**Issues subsumed by others:** Issue 33 (covered by Issue 30), Issue 36 (covered
by Issue 27) — these may be closed without independent action during resolution.

**Overall:** One blocking gap (Issue 26: `missing_method` not replayed in
within-draw `ipw()` call — correctness bug for any user who called `ipw()` with
`missing_method = "separate"` or `"impute"`) must be resolved in the spec before
implementation begins. The five required issues are all editorial fixes to §IV or
§VII. The eight suggestion-level issues are documentation additions to `@details`,
the test plan, and the quality gates checklist.
