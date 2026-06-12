## Plan Review: sample-calibration-api — Pass 1 (2026-06-11) — RESOLVED 2026-06-11

---

### New Issues

#### Section: PR 1 — Acceptance Criteria

**Issue 1: Test-spec `make_replicate_design()` pseudocode is incorrect — tester will implement a broken helper**
Severity: BLOCKING
Violates artifact isolation principle: tester artifact contains an incorrect code snippet that produces `surveywts_error_not_survey_design`.

The test-spec's helper pseudocode (§Helper: `make_replicate_design(n, seed)`) passes a plain data.frame directly to `create_bootstrap_weights()`:

```r
make_replicate_design <- function(n = 200L, seed = 42L) {
  df <- make_surveywts_data(n = n, seed = seed)
  create_bootstrap_weights(df, weights = base_weight, replicates = 50L)  # WRONG
}
```

`create_bootstrap_weights()` rejects data frames with `surveywts_error_not_survey_design` (confirmed in `error-messages.md` §Replicate Weight Functions). The correct implementation (in the impl plan's notes) wraps `df` in `survey_taylor` first — consistent with what the current `helper-test-data.R:165` already does:

```r
make_replicate_design <- function(n = 200L, seed = 42L) {
  df <- make_surveywts_data(n = n, seed = seed)
  taylor <- surveycore::survey_taylor(
    data = df,
    variables = list(weights = "base_weight")
  )
  create_bootstrap_weights(taylor, replicates = 50L)  # CORRECT
}
```

The tester receives only the test-spec (never the impl plan). If the tester implements the pseudocode as written, every test block that calls `make_replicate_design()` will error with the wrong class, making the audit useless. Additionally, even if the builder writes the correct helper, the tester will flag it as inconsistent with the test-spec pseudocode.

Options:
- **[A]** Update the test-spec's `make_replicate_design()` pseudocode to include the `survey_taylor` wrapping step — Effort: low, Risk: low, Impact: tester gets an implementable, correct helper
- **[B]** Add a note to the impl plan instructing the human to hand the corrected helper to the tester out-of-band — Effort: low, Risk: medium, Impact: breaks artifact isolation; fragile
- **[C] Do nothing** — Tester implements a broken helper; all `calibrate_to_survey()` / `calibrate_to_estimate()` test blocks fail with `surveywts_error_not_survey_design`; audit is invalid

**Recommendation: A** — The test-spec is the single source of truth for the tester; fix the pseudocode there.

---

**Issue 2: Mocking strategy for svrep convergence / hard-error tests not specified**
Severity: REQUIRED
Violates Lens 3 (Acceptance Criteria) — the test scenarios are not "objectively implementable" without a named mechanism.

The test-spec lists two error-path rows for both functions:
- `surveywts_error_calibration_not_converged` — "Mock svrep to emit 'converge' warning and return normally"
- `surveywts_error_calibration_failed` — "Mock svrep to throw a hard error"

Neither the test-spec nor the impl plan specifies the mocking mechanism. The surveywts codebase calls svrep via `svrep::calibrate_to_sample()` and `svrep::calibrate_to_estimate()` using `::` (per code-style.md import rules). Standard R mocking tools (`testthat::with_mocked_bindings()`, `mockery::stub()`) work differently for `::` calls vs. attached-function calls. The builder needs explicit guidance on which mechanism to use and how to target `svrep::calibrate_to_sample` via `::` namespacing.

Options:
- **[A]** Add a "Mocking strategy" note to the impl plan specifying the mechanism (e.g., `testthat::with_mocked_bindings()` or `mockery` with `where = asNamespace("svrep")`) and confirming `mockery` is a Suggests dependency — Effort: low, Risk: low, Impact: builder implements testable convergence paths
- **[B]** Update the test-spec to include a mocking code snippet for at least one of the two scenarios — Effort: low, Risk: low, Impact: tester can validate independently
- **[C] Do nothing** — Builder may skip or incorrectly implement these two tests; convergence / hard-error distinction (a key behavioral change in the API) goes untested

**Recommendation: A** — the impl plan is the right place for implementation-detail notes; add a "Mocking svrep" note section.

---

**Issue 3: Changelog entry missing from write surface and acceptance criteria**
Severity: REQUIRED
Violates `github-strategy.md`: "Changelog entry format (required before every PR)."

The `changelog/` directory is active (contains entries for every prior phase: calibration, nonresponse, propensity, replicate, utilities, etc.). There is already a `changelog/nonresponse/feature-sample-calibration.md` covering the original implementation. This PR is a material API rewrite and must produce a new entry (e.g., `changelog/nonresponse/feature-sample-calibration-api.md`) documenting the argument renames, retired error classes, new arguments, and behavior changes.

Neither the write surface (§Files) nor the acceptance criteria mentions a changelog file.

Options:
- **[A]** Add `changelog/nonresponse/feature-sample-calibration-api.md` to the §Files list and add "Changelog entry written and committed" to the acceptance criteria — Effort: low, Risk: low, Impact: consistent with all prior PRs
- **[B]** Do nothing — Effort: zero, Risk: medium, Impact: PR history loses traceability; inconsistent with package conventions

**Recommendation: A** — one-line addition to files list and one bullet in acceptance criteria.

---

**Issue 4: Retired error (`surveywts_error_replicate_count_mismatch`) removal not an explicit acceptance criterion**
Severity: REQUIRED
Violates Lens 3 (Acceptance Criteria) — behavioral regression (leaving old error in) would pass all other listed criteria.

The spec explicitly removes `surveywts_error_replicate_count_mismatch` ("svrep handles count mismatches natively; error removed"). The test-spec has two dedicated rows:
- "Replicate count mismatch (more in primary): no error"
- "Replicate count mismatch (fewer in primary): no error"

These appear only in the §Edge cases table, not in the acceptance criteria. A builder could leave the old count-mismatch guard in place, and no listed acceptance criterion would catch it — the guard would simply prevent otherwise-valid calls from succeeding.

Options:
- **[A]** Add an explicit acceptance criterion: "Replicate count mismatches (both directions) do not throw any error; `surveywts_error_replicate_count_mismatch` is absent from the codebase" — Effort: low, Risk: low, Impact: removes silent regression path
- **[B]** Do nothing — Effort: zero, Risk: medium, Impact: old error guard may survive the rewrite; calls with mismatched replicate counts would fail unexpectedly in production

**Recommendation: A** — one bullet in acceptance criteria, one `grep` check in the build.

---

#### Section: PR 1 — PR Granularity / Spec Alignment

**Issue 5: Spec recommends pipeline split; plan bundles both functions without explicit justification comparison**
Severity: SUGGESTION
`spec-sample-calibration-api.md §Pipeline split` states: "recommended — two exported function contracts both change, the argument list changes materially."

The plan's justification ("share helper changes, a single test file, and tightly coupled error-class additions") is reasonable. The functions share `test-sample-calibration.R`, `helper-test-data.R`, and the `error-messages.md` update. Bundling is acceptable when the shared infrastructure makes splitting impractical.

However, the justification appears only in the plan's §Overview and is not cross-referenced against the spec's explicit recommendation. A reviewer handed only the plan cannot tell whether the spec's "recommended" split was intentionally overridden.

Options:
- **[A]** Add one sentence to the plan's §Notes acknowledging the spec's split recommendation and stating the override rationale (shared test file makes split impractical; both functions must pass `test_invariants()` with the same extended helper) — Effort: minimal, Risk: none, Impact: explicit decision trail
- **[B]** Do nothing — Effort: zero, Risk: low, Impact: minor documentation gap; justification is implicit

**Recommendation: A** — explicit deviation acknowledgment takes one sentence.

---

**Issue 6: Roxygen acceptance criteria are too coarse to catch missing required tags**
Severity: SUGGESTION
The spec mandates specific roxygen content that `devtools::check()` will not verify.

The spec's §Roxygen documentation requirements lists:
- `@family sample-calibration`
- `@details` explaining why `survey_replicate` is required (not just that it is)
- `@details` or inline `@param bounds` note that `bounds_scale` is not supported
- `@references` with two specific citations (Fuller 1998; Opsomer & Erciulescu 2021)
- `@examples` using `survey::apiclus1` / `survey::apisrs`

The plan's acceptance criteria only check that `devtools::check()` passes and `devtools::document()` generates files in sync. A function could export without `@family`, `@references`, or the required `@details` content and still pass `R CMD check`.

Options:
- **[A]** Add acceptance criteria bullets checking: `@family sample-calibration` present in both files; `@references` block present with both citations; `@examples` block uses `survey::apiclus1` / `survey::apisrs`; `@details` explains `survey_replicate` requirement — Effort: low, Risk: none, Impact: verifiable per-tag compliance
- **[B]** Do nothing — Effort: zero, Risk: low, Impact: roxygen content may be incomplete; caught in code review but not by test gate

**Recommendation: A** — four verifiable bullets; each is a grep or visual check.

---

**Issue 7: Snapshot review process not explicitly required in acceptance criteria**
Severity: SUGGESTION
`testing-standards.md`: "Never run `testthat::snapshot_accept()` blindly. Each snapshot change must be reviewed."

The impl plan notes say "Delete the existing snapshot file before running tests so testthat generates fresh snapshots. Then review and approve each snapshot individually via `testthat::snapshot_review()`." This critical process instruction is in §Notes but is not in the acceptance criteria. The acceptance criterion reads "All spec §Error paths throw the correct class with snapshot match" — which is the outcome, not the process. A builder could bulk-accept snapshots with `testthat::snapshot_accept()` without individual review.

Options:
- **[A]** Add acceptance criterion: "All snapshots reviewed individually via `testthat::snapshot_review()` before committing (not bulk-accepted via `snapshot_accept()`)" — Effort: minimal, Risk: none, Impact: enforces the testing-standards.md requirement
- **[B]** Do nothing — Effort: zero, Risk: low, Impact: snapshot content may be accepted without review; message regressions could slip through

**Recommendation: A** — one bullet in acceptance criteria mirrors the existing testing-standards.md rule.

---

## Summary (Pass 1)

| Severity | Count |
|---|---|
| BLOCKING | 1 |
| REQUIRED | 3 |
| SUGGESTION | 3 |

**Total issues:** 7

**Overall assessment:** The plan is structurally sound — TDD order is correct, the single-PR bundling is justified, and the acceptance criteria are unusually thorough for an API rewrite. One blocking defect (wrong helper pseudocode in the test-spec) would cause every tester test block to fail with the wrong error class. Three required items (mocking strategy, changelog entry, and explicit criterion for retired error removal) close regression paths that the current catch-all criteria would miss. Resolve issue 1 before handing to pipeline-ship.
