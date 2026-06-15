## Spec Review: sample-calibration-api — Pass 3 (2026-06-11) — PASS

### Prior Issues (Pass 2)

| # | Title | Status |
|---|---|---|
| 1 | `make_replicate_design()` not specified | ✅ Resolved |
| 2 | `survey_taylor_obj` not defined in test-spec datasets | ✅ Resolved |
| 3 | `test_invariants()` missing `survey_replicate` branch | ✅ Resolved |
| 4 | Replicate count mismatch test has non-deterministic assertion | ✅ Resolved |
| 5 | Reproducibility claim for `control_col_matches` untested | ✅ Resolved |
| 6 | Reproducibility claim for `col_selection` untested | ✅ Resolved |
| 7 | `before_stats` and `after_stats` content undefined | ✅ Resolved |
| 8 | Targets level-label mismatch has no specified error | ✅ Resolved |
| 9 | `targets = list()` (empty list) behavior not specified | ✅ Resolved |
| 10 | Spec does not say which existing `error-messages.md` entries must be updated | ✅ Resolved |
| 11 | Convergence string match case sensitivity not specified | ✅ Resolved |
| 12 | "In-place" language is misleading for R's copy-on-modify semantics | ✅ Resolved |
| 13 | Weight-sum conservation in `calibrate_to_estimate()` delegated to builder | ✅ Resolved |
| 14 | `control` defaults not confirmed to match svrep defaults | ✅ Resolved |

### New Issues

---

#### Section: spec — Function contracts (both functions) — `targets_from_reference` default

**Issue 15: `targets_from_reference` value when `reference_design = NULL` is not specified**
Severity: REQUIRED
Violates artifact-schemas.md §spec: all return fields must have their value defined for every code path.

Both function Returns sections say: "`targets_from_reference`" is part of `parameters`, and the `reference_design` argument says "When non-`NULL`, stored in the history entry `parameters$reference_design` with `parameters$targets_from_reference = TRUE`." But neither function specifies what `targets_from_reference` is when `reference_design = NULL` — the default case. The builder must guess: `FALSE`, `NULL`, or the key is absent from `parameters` entirely. Three builders produce three different implementations, all compliant with the spec as written.

Options:
- **[A]** Add to both function contracts: "`targets_from_reference = FALSE` when `reference_design` is `NULL` (the default)." One sentence per function. Effort: trivial, Risk: low, Impact: removes builder guesswork, Maintenance: none.
- **[B]** Add to the Scope §Architecture note that this mirrors `calibrate_linear()`'s behavior (if that function already stores `FALSE` for the null case). Same effect if the existing convention is clear.
- **[C] Do nothing** — builder checks existing code or guesses; implementations diverge across PRs.

**Recommendation: A** — both functions need a consistent default, and the spec should state it.

---

#### Section: test-spec — Per-function test plan (both functions) — history entry coverage

**Issue 16: `before_stats` and `after_stats` are spec-defined return fields with zero test coverage**
Severity: REQUIRED
Violates testing-standards.md §2: every spec-defined return value must have a corresponding test.

The spec defines `before_stats` and `after_stats` as named lists with 11 specific keys (`n`, `n_positive`, `n_zero`, `mean`, `cv`, `min`, `p25`, `p50`, `p75`, `max`, `ess`). These are part of the public contract — any consumer of the weighting history depends on this structure. Yet the test-spec has no test block for either function that asserts:
- `before_stats` and `after_stats` are present in the history entry
- Both are lists with the 11 defined keys
- `before_stats` reflects pre-calibration weights and `after_stats` reflects post-calibration weights (values differ after calibration)

A builder who omits either field, uses wrong key names, or stores a scalar instead of a list would pass every current test.

Options:
- **[A]** Add one history-entry test row per function to the Happy path table:
  - Scenario: "History entry `before_stats`/`after_stats` structure"
  - Dataset: standard design
  - Expected: `before_stats` and `after_stats` each are named lists; `names(before_stats)` equals `c("n", "n_positive", "n_zero", "mean", "cv", "min", "p25", "p50", "p75", "max", "ess")`; `before_stats$mean != after_stats$mean` (weights changed)
  - Tolerance: —
  Effort: low, Risk: low, Impact: closes the most significant gap in history coverage, Maintenance: none.
- **[B] Do nothing** — builder gets no feedback from tests if before_stats/after_stats are missing or miskeyed; discovered only in integration.

**Recommendation: A** — the 11-key structure is a spec commitment; it needs at least one test to enforce it.

---

#### Section: test-spec — Per-function test plan (both functions) — history `parameters` coverage

**Issue 17: Several spec-defined `parameters` fields are not covered by any test**
Severity: SUGGESTION
Violates engineering-preferences.md §2 (more tests is better).

The spec defines the full list of keys stored in `parameters` for each function. The test-spec verifies some (`variables`, `method`, `targets`, `vcov_dim`, `targets_from_reference`, `reference_design`, absence of forwarding-only keys), but these spec-defined fields are not covered by any test row:

- **`calibrate_to_survey()`**: `bounds`, `unit_scale`, `n_replicates`, `control_design_class`, `n_replicates_control`
- **`calibrate_to_estimate()`**: `bounds`, `unit_scale`, `n_replicates`

A builder who misspells a key (e.g., `n_replicate` instead of `n_replicates`) or forgets to store `bounds` when non-default would pass all current tests.

Options:
- **[A]** Extend the existing "History entry parameters" test rows for both functions to also assert: `"bounds" %in% names(parameters)` (using a non-default `bounds` value so mis-storage is detectable); `"n_replicates" %in% names(parameters)`. Add one additional row for `calibrate_to_survey()` that checks `"control_design_class" %in% names(parameters)`. Effort: low, Risk: low.
- **[B] Do nothing** — `bounds` and `n_replicates` are simple pass-throughs unlikely to be misspelled; accept reduced coverage.

**Recommendation: A** — the additional assertions fit in one or two additional test rows and close a real gap in the history contract verification.

---

#### Section: spec — `control` "merged list" semantics — both functions

**Issue 18: "Merged list" for stored `control` in history is ambiguous**
Severity: SUGGESTION
Violates artifact-schemas.md §spec: all return fields must have their value fully defined.

Both functions' Returns sections say: "control (the merged list, excluding `control_col_matches` / `col_selection`)." What "merged" means is not stated. Scenario: user passes `control = list(maxit = 100)`. Is the stored control:

- **Option A**: `list(maxit = 100, epsilon = 1e-7)` — user value plus default for omitted key
- **Option B**: `list(maxit = 100)` — only what the user explicitly provided

These are different in meaning: (A) gives a complete record of effective calibration parameters; (B) only records deviations from defaults. Both are defensible design choices. The builder will choose one; if the test-spec doesn't cover this, diverging implementations could appear correct.

Options:
- **[A]** Add one sentence to both Returns sections: "The stored `control` contains values for all known keys (including defaults for keys the user omitted) — e.g., `list(maxit = 50L, epsilon = 1e-7)` when `control = list()` was passed." Effort: trivial.
- **[B]** Add one sentence: "The stored `control` contains only the user-provided keys, not injected defaults." Effort: trivial.
- **[C] Do nothing** — two builders produce (A) and (B); neither is caught by tests.

**Recommendation: A** — a complete record of effective parameters is the more useful history entry; clarify this is the intent.

---

### Summary (Pass 3)

| Severity | Count |
|---|---|
| BLOCKING | 0 |
| REQUIRED | 2 |
| SUGGESTION | 2 |

**Total new issues:** 4

**Overall assessment:** The spec is in excellent shape after two prior passes. The two REQUIRED issues are narrow gaps: one missing default value in a history field (`targets_from_reference = FALSE` when `reference_design = NULL`) and one missing test category (`before_stats`/`after_stats` structure). Both are low-effort one-sentence fixes. The suggestions improve history coverage completeness and remove a modest ambiguity in the stored `control` semantics. No blocking issues remain; the spec is implementable as-is modulo the two REQUIRED gaps.

---

## Spec Review: sample-calibration-api — Pass 2 (2026-06-11) — PASS

All 14 issues from Pass 1 resolved (all Option A). Verdict: **PASS**.

---

## Spec Review: sample-calibration-api — Pass 1 (2026-06-11)

### New Issues

---

#### Section: test-spec — Datasets / Helper Infrastructure

**Issue 1: `make_replicate_design()` not specified**
Severity: BLOCKING
Violates artifact-schemas.md: test-spec must be independently sufficient for the tester.

The entire `calibrate_to_survey()` and `calibrate_to_estimate()` test suite
depends on `make_replicate_design(n, seed)` (referenced as
`.make_replicate_design(df, seed = N)` in the Datasets table), but this helper
is defined nowhere — not in `helper-test-data.R`, not in `testing-surveywts.md`,
not in the test-spec itself. The tester would need to invent its contract from
scratch: replicate type (bootstrap? jackknife?), number of replicates, seed
behavior, weight structure, PSU/strata columns.

Options:
- **[A]** Add a `make_replicate_design()` section to the test-spec specifying:
  signature, return class (`survey_replicate`), replicate type, number of
  replicates, and that it wraps `make_surveywts_data()` → one of the
  `create_*_weights()` functions. Effort: low, Risk: low, Impact: unblocks all
  happy-path and edge-case tests, Maintenance: none.
- **[B]** Add to `helper-test-data.R` spec and reference from test-spec. Same
  effect, slightly more formal.
- **[C] Do nothing** — tester guesses; two testers produce different designs;
  tests are non-reproducible across reviewers.

**Recommendation: A** — the test-spec is the tester's sole input; define it there.

---

**Issue 2: `survey_taylor_obj` not defined in test-spec datasets**
Severity: REQUIRED
Violates testing-standards.md §4: tester must be able to construct every test
input from the test-spec alone.

Three test rows reference `survey_taylor_obj` (the `reference_design` tests in
both functions' happy paths) but there is no dataset entry or construction recipe
for it. The tester does not know which `survey_taylor` to build, from what data,
or with what design structure.

Options:
- **[A]** Add to the Datasets table: e.g.,
  `survey::svydesign(id=~1, data=survey::apisrs, weights=~pw)` cast to
  `survey_taylor` via `as_survey()` (or however surveycore constructs one).
  Specify the exact construction. Effort: low, Risk: low, Impact: unblocks two
  test blocks, Maintenance: none.
- **[B] Do nothing** — tester improvises; correctness of the provenance test is
  implementation-dependent.

**Recommendation: A** — one sentence in the Datasets table fixes this.

---

#### Section: test-spec — `calibrate_to_survey()` — test invariants / helper extension

**Issue 3: `test_invariants()` missing `survey_replicate` branch**
Severity: REQUIRED
Violates testing-surveywts.md: `test_invariants()` must be the first assertion
in every block that constructs a result; the function currently has no branch for
`survey_replicate`.

The test-spec's Invariants section says `test_invariants(obj)` is the first
assertion in every test block and validates `obj` is `survey_replicate`, weight
column exists, is numeric, all values strictly positive. But the definition in
`helper-test-data.R` (from `testing-surveywts.md`) handles only `weighted_df`
and `survey_nonprob`. Calling `test_invariants(result)` on a `survey_replicate`
result would silently pass every time — including for a broken implementation.

Options:
- **[A]** Add to the test-spec: "The tester must extend `test_invariants()` in
  `helper-test-data.R` to add a `survey_replicate` branch that asserts:
  `S7::S7_inherits(obj, surveycore::survey_replicate)` is `TRUE`; the full-sample
  weight column exists and is numeric; all full-sample weights are strictly
  positive." Effort: low, Risk: low, Impact: turns silent pass into real
  assertion, Maintenance: none.
- **[B] Do nothing** — invariant tests are vacuously true; a broken
  implementation still passes them.

**Recommendation: A** — without this, the test-spec's core invariant is
unenforceable.

---

#### Section: test-spec — `calibrate_to_survey()` happy path

**Issue 4: Replicate count mismatch test has non-deterministic assertion**
Severity: REQUIRED
Violates testing-standards.md §3: assertions must be deterministic.

The happy path rows for "Replicate count mismatch (more in primary)" and "fewer
in primary" say Expected = "Returns `survey_replicate` without error; warning may
or may not be emitted (svrep behavior)". But `spec-sample-calibration-api.md`
§`calibrate_to_survey()` Edge cases is unambiguous: "`surveywts_warning_replicate_scheme_mismatch`
is NOT emitted for count mismatches (only type mismatches)." A test must be
deterministic. The "may or may not" conflates surveywts warnings with svrep's
internal warnings.

Options:
- **[A]** Rewrite both rows: Expected = "Returns `survey_replicate` without error;
  no `surveywts_warning_replicate_scheme_mismatch` emitted. Svrep's own warnings
  (if any) are suppressed with `suppressWarnings()` before asserting on the
  result class." Effort: low, Risk: low, Impact: makes test deterministic,
  Maintenance: none.
- **[B] Do nothing** — tester writes a non-deterministic test or skips it;
  coverage gap goes undetected.

**Recommendation: A** — the spec already defines the behavior; the test-spec just
needs to reflect it.

---

**Issue 5: Reproducibility claim for `control_col_matches` untested**
Severity: REQUIRED
Violates engineering-preferences.md §2: spec-stated behavior must be testable.

The spec says: "When absent (or `NULL`), svrep uses random matching — results
are non-deterministic; two calls with identical inputs can produce different
calibrated weights. Set `control_col_matches` to a fixed integer vector to ensure
reproducibility." But the test-spec only verifies that `control_col_matches` is
NOT stored in history (forwarding-only key test). No test verifies that two calls
with the same `control_col_matches` produce identical weights, or that two calls
without it can produce different weights.

Options:
- **[A]** Add a reproducibility test: two calls with `control = list(control_col_matches = 1:50)` and the same designs produce identical full-sample weights
  (`expect_identical(w1, w2)`). Optionally: two calls without `control_col_matches`
  MAY differ (test via `set.seed(NULL)` before each call). Effort: low, Risk:
  low, Impact: validates the non-trivial spec claim, Maintenance: none.
- **[B] Do nothing** — reproducibility claim is unverifiable from the test-spec.

**Recommendation: A** — the reproducibility behavior is a meaningful spec
commitment; it needs a test.

---

#### Section: test-spec — `calibrate_to_estimate()` happy path

**Issue 6: Reproducibility claim for `col_selection` untested**
Severity: REQUIRED
Same issue as Issue 5, for `calibrate_to_estimate()`. The spec says `col_selection`
enables reproducible replicate-level perturbations, but no test verifies this.

Options:
- **[A]** Add the same pattern: two calls with `control = list(col_selection = 1:50)`
  produce identical full-sample weights. Effort: low, Risk: low.
- **[B] Do nothing** — claim is untested.

**Recommendation: A** — mirrors Issue 5.

---

#### Section: spec — Function contracts (`before_stats` / `after_stats`)

**Issue 7: `before_stats` and `after_stats` content undefined**
Severity: REQUIRED
Violates artifact-schemas.md §spec: all return fields must have type, shape, and
content defined.

Both function Returns sections list `before_stats`, `after_stats` as part of the
history entry ("weight summary statistics") but neither the spec nor any linked
document defines what they contain. The builder cannot implement this without
inspecting the existing code or guessing. Possible contents: mean, min, max, CV,
N, ESS — none are specified.

Options:
- **[A]** Define the fields in the spec: e.g., "each is a named numeric vector
  with elements `n`, `mean`, `min`, `max`, `cv` computed on the full-sample
  weights before/after calibration." Align with whatever `.make_history_entry()`
  already produces for other functions. Effort: low, Risk: low, Impact: builder
  implements consistently, Maintenance: none.
- **[B]** Reference the existing helper: "Same structure as in `calibrate_linear()`
  history entries — see `.make_history_entry()` in `calibrate-utils.R`." Slightly
  DRYer if builder reads existing code anyway.
- **[C] Do nothing** — builder infers from existing code; spec is incomplete.

**Recommendation: A** — specs should not require the builder to reverse-engineer
behavior from the existing implementation.

---

#### Section: spec — `calibrate_to_estimate()` — targets level-label mismatch

**Issue 8: Targets level-label mismatch has no specified error**
Severity: REQUIRED
Violates engineering-preferences.md §4 (handle edge cases explicitly).

The spec says: "Inner names are the level labels; they must exactly match the
levels present in the corresponding column (no missing levels, no extra levels)."
But no error class is specified for when they don't match. A user supplying
`targets = list(sex = c("Male" = 300, "Female" = 200))` when the data column has
`c("M", "F")` would receive a confusing svrep-internal error surfaced as
`surveywts_error_calibration_failed`. There is no early validation or specific
error class.

Options:
- **[A]** Add a new error class `surveywts_error_targets_levels_mismatch` (or
  two: `_missing` / `_extra`), validate before calling svrep, and add to
  `error-messages.md`. Effort: medium, Risk: low, Impact: helpful error message
  for a very common user mistake, Maintenance: none.
- **[B]** Explicitly state in the spec: "Level-label mismatches are not validated
  by surveywts; svrep rejects them and the error is surfaced as
  `surveywts_error_calibration_failed`. The error message will contain svrep's
  raw text." Mark it as a known limitation. Effort: low, Risk: low, Impact: spec
  is explicit, Maintenance: none.
- **[C] Do nothing** — builder has to guess which approach is intended; currently
  the spec implies validation is required but provides no mechanism.

**Recommendation: A** — level mismatches are a common mistake that deserves a
clear error; if that's too heavy for this PR, choose B and document the
limitation explicitly.

---

#### Section: spec — `calibrate_to_estimate()` — empty `targets`

**Issue 9: `targets = list()` (empty list) behavior not specified**
Severity: REQUIRED
Violates engineering-preferences.md §4: edge cases must be explicitly specified.

The spec defines `targets` as a "named list" and validates it's not empty-named,
each element is named numeric, etc. But `targets = list()` (a valid named list
with zero elements) is not covered. It would either trigger no error in surveywts
and then fail in svrep (surfaced as `surveywts_error_calibration_failed`), or it
should be caught as `surveywts_error_targets_not_named_list` (if the spec treats
"no elements" as equivalent to "no names"). Currently unspecified.

This is analogous to `calibrate_to_survey()` explicitly covering "empty selection
triggers `surveywts_error_variables_not_found`" — `calibrate_to_estimate()` has
no equivalent.

Options:
- **[A]** Add to the `targets` argument spec and Edge cases: "`targets = list()`
  triggers `surveywts_error_targets_not_named_list`" (zero-element list is
  vacuously unnamed). Add corresponding test row. Effort: low, Risk: low.
- **[B]** Add to Edge cases: "`targets = list()` is passed to svrep; svrep rejects
  it; surfaced as `surveywts_error_calibration_failed`." Explicit but delegates to
  svrep.
- **[C] Do nothing** — unspecified; builder guesses.

**Recommendation: A** — consistent with how `calibrate_to_survey()` handles empty
selection; gives a helpful early error.

---

#### Section: plans/error-messages.md update scope

**Issue 10: Spec does not say which existing `error-messages.md` entries must be updated**
Severity: REQUIRED
Violates artifact-schemas.md: spec §Scope/In must list all artifact changes.

The spec says "Update `plans/error-messages.md` with all new, renamed, and
retired classes." But `error-messages.md` currently lists two error classes as
thrown by `calibrate_to_survey()` that are NOT in the new spec's error table:

- `surveywts_error_formula_variable_not_found` (listed as thrown by
  `calibrate_to_survey()` (internal, forwarded from svrep for control_design
  check))
- `surveywts_error_formula_invalid` (listed as thrown by `calibrate_to_survey()`
  (internal))

After the rewrite, `calibrate_to_survey()` uses `variables` (tidy-select), not a
`formula`. These classes remain valid for `adjust_nonresponse(method =
"propensity-cell")` but `calibrate_to_survey()` should no longer appear in their
"Thrown by" columns. If the builder misses this, `error-messages.md` will be
inconsistent with the implementation.

Options:
- **[A]** Add to the spec's Architecture §Files touched or In scope: "In
  `plans/error-messages.md`, remove `calibrate_to_survey()` from the 'Thrown by'
  column of `surveywts_error_formula_variable_not_found` and
  `surveywts_error_formula_invalid`. These classes are not retired (still used by
  `adjust_nonresponse`), only updated." Effort: low, Risk: low.
- **[B] Do nothing** — builder discovers this inconsistency (or doesn't).

**Recommendation: A** — a one-sentence addition prevents a stale error registry.

---

#### Section: spec — Suggestions

**Issue 11: Convergence string match case sensitivity not specified**
Severity: SUGGESTION
The spec says convergence detection "matches 'converge'" (string matching on
svrep's warning text). It doesn't specify case sensitivity. If svrep ever
capitalizes the word (`"Convergence failed"` vs `"convergence failed"`), the
detection breaks silently. Recommend: specify `grepl("converge", msg, ignore.case = TRUE)`.

Options:
- **[A]** Add `ignore.case = TRUE` to the detection spec. Effort: trivial.
- **[B] Do nothing** — case-sensitive match works until svrep changes its messages.

**Recommendation: A**.

---

**Issue 12: "In-place" language is misleading for R's copy-on-modify semantics**
Severity: SUGGESTION
The Returns section for `calibrate_to_survey()` says: "The full-sample weight
column ... and all replicate weight columns ... are updated in-place on the
returned object." "In-place" implies mutation; in R, objects are copy-on-modify.
Should say "are updated in the returned object" or "the returned object carries
updated weights."

Options:
- **[A]** Replace "updated in-place on the returned object" with "updated in the
  returned object". Effort: trivial.
- **[B] Do nothing** — minor, meaning is inferrable from context.

**Recommendation: A** — prevents a builder with a non-R background from thinking
`primary_design` is mutated.

---

**Issue 13: Weight-sum conservation in `calibrate_to_estimate()` delegated to builder**
Severity: SUGGESTION
The Returns section says: "The builder must verify and document the exact
weight-sum conservation behavior of the underlying svrep call in a code comment."
This delegates spec responsibility to the builder. The spec should state what the
behavior IS, not ask the builder to discover it. At a minimum: "When targets are
internally consistent (all variables' level totals sum to the same N), the
calibrated weight sum equals N." If this isn't known yet, mark it as a HOLD.

Options:
- **[A]** Research svrep's intercept handling and state the behavior explicitly.
  Effort: low (check svrep docs/source).
- **[B]** Mark as HOLD with "Tester must verify weight-sum conservation against a
  known svrep call in the happy path; expected value TBD."
- **[C] Do nothing** — builder infers it.

**Recommendation: A** — a spec that requires the builder to figure out behavior is incomplete.

---

**Issue 14: `control` defaults not confirmed to match svrep defaults**
Severity: SUGGESTION
The spec states `maxit = 50L` and `epsilon = 1e-7` as defaults for both
functions. It's not stated whether these match svrep's own defaults for its
`calibrate_to_sample()` / `calibrate_to_estimate()` functions. If svrep uses
different defaults, surveywts would silently override them — which may or may not
be intentional. The spec should either: confirm these ARE svrep's defaults (so
passing `NULL` would be equivalent), or state they are surveywts overrides and
explain why.

Options:
- **[A]** Add one sentence: "These match svrep's defaults" or "These intentionally
  differ from svrep's defaults: [reason]." Effort: trivial.
- **[B] Do nothing** — builder looks up svrep docs.

**Recommendation: A** — removes an ambiguity the builder will have to resolve.

---

## Summary (Pass 1)

| Severity | Count |
|---|---|
| BLOCKING | 1 |
| REQUIRED | 9 |
| SUGGESTION | 4 |

**Total issues:** 14

**Overall assessment:** The spec is structurally complete and methodologically
sound — all error classes are in `error-messages.md`, validation order is
specified, the `vcov_estimate` ordering contract is clear, and the two functions'
APIs are coherent. The blocking issue (undefined `make_replicate_design()` helper)
and several required issues (undefined `before_stats`/`after_stats`, missing
`survey_taylor_obj` recipe, untested reproducibility claims, non-deterministic
count-mismatch assertion, empty-targets gap, level-mismatch gap,
`test_invariants()` extension, and `error-messages.md` update scope) must be
resolved before the tester can run an independent, deterministic test suite from
the test-spec alone.
