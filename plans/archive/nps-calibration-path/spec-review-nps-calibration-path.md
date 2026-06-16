# Spec Review: nps-calibration-path — Pass 1 (2026-06-15)

### New Issues

---

#### Section: Lens 1 — DRY

**Issue 1: Calibration entry definition stated only in QR bootstrap section; DAGJK repeats it without cross-reference**
Severity: SUGGESTION
[Violates engineering-preferences.md §1 — flag repetition aggressively]

The definition "A 'calibration entry' is any history entry whose `$operation` field
is one of: `'raking'`, `'calibrate_rake'`" appears in the `create_bootstrap_weights`
contract. The `create_group_jackknife_weights` validation order (step 5) repeats the
same string list (`$operation %in% c("raking", "calibrate_rake")`) without referencing
the definition above. If a future maintainer adds a new operation string (e.g.,
`"calibrate_raking"`) to the supported list, they would need to update both function
contracts. The spec should either extract a shared definition block at the top or add a
cross-reference in the DAGJK section.

Options:
- **[A]** Add a shared "Calibration entry detection" definition section before the
  function contracts, and replace the inline definition in both function sections with
  a reference to it. — Effort: low, Risk: none, Impact: single point of truth for
  future maintainers, Maintenance: none
- **[B]** Add a parenthetical note in the DAGJK routing step: "same definition as in
  `create_bootstrap_weights` above." — Effort: low, Risk: none, Impact: explicit
  cross-reference, Maintenance: none
- **[C] Do nothing** — two places to update if the valid operations list ever changes.

**Recommendation: B** — minimal effort, eliminates the silent duplication risk.

---

**Issue 2: `calibrate_rake()` weight extraction note missing from DAGJK calibration-only section**
Severity: REQUIRED
[Violates testing-standards.md §1 (completeness); engineering-preferences.md §3 (under-engineered)]

The QR bootstrap contract includes this note in the "Calibration-only bootstrap
algorithm" section:

> "The output `calibrate_rake()` may be a `weighted_df` or `survey_nonprob`
> depending on the input class passed. Weight extraction must handle both classes."

The DAGJK calibration-only algorithm (step 5) also calls `calibrate_rake()` on
`S_A_minus_g`, which is a subset of `data@data` — a plain `data.frame`. Calling
`calibrate_rake()` on a `data.frame` returns a `weighted_df`, not a
`survey_nonprob`. Weight extraction then requires `attr(result, "weight_col")` /
`result[[attr(result, "weight_col")]]`, not `result@data[[result@variables$weights]]`.
The spec is silent on this for DAGJK. A builder who follows the pattern from the
existing IPW path (which always operates on `survey_nonprob` objects) will write
weight extraction that fails silently on a `weighted_df`.

Options:
- **[A]** Add the same weight extraction note to the DAGJK calibration-only algorithm
  section (after step 5): "The output of `calibrate_rake()` may be a `weighted_df`
  or `survey_nonprob` depending on the input class passed. Weight extraction must
  handle both classes — same requirement as the QR bootstrap calibration-only path."
  — Effort: low, Risk: none, Impact: prevents a runtime error in the implementation,
  Maintenance: none
- **[B]** Mandate that the builder always passes `S_A_minus_g` as a `survey_nonprob`
  to `calibrate_rake()`, so the output is always `survey_nonprob`. This eliminates the
  dual-class extraction problem at the cost of constructing a temporary `survey_nonprob`
  per replicate. — Effort: medium (builder must construct temporary object), Risk: low,
  Impact: simpler extraction logic, Maintenance: none
- **[C] Do nothing** — builder may or may not notice the issue.

**Recommendation: A** — explicit parity with the QR bootstrap section is the clearest
path and leaves the builder's implementation choice open.

---

#### Section: `create_bootstrap_weights()` — Calibration-only bootstrap algorithm

No issues beyond those flagged above.

---

#### Section: `create_group_jackknife_weights()` — Calibration-only DAGJK algorithm

**Issue 3: DAGJK `calibrate_rake()` call parameters incomplete — missing `type`, `algorithm`, `cap`, `control`**
Severity: REQUIRED
[Violates code-style.md §4 — contract must specify all behavioral inputs]

The QR bootstrap calibration-only algorithm explicitly specifies all parameters passed
to `calibrate_rake()`:

> "`calibrate_rake()` is called with: `data` = `S_A_b`, `targets` = resolved targets,
> `type`, `algorithm`, `cap`, `control` from `calib_entry$parameters`"

The DAGJK calibration-only algorithm (step 5) says only:

> "call `calibrate_rake()` on `S_A_minus_g` with `w_i_adj` as starting weights,
> using fixed targets from `calib_entry$parameters$targets`"

The parameters `type`, `algorithm`, `cap`, and `control` are missing. For calibration
replay to be faithful, the builder must pass all stored parameters from the calibration
history entry, not just `targets`. If the original calibration used `type = "count"` or
`algorithm = "nr"` or a non-default `cap`, and the builder uses defaults when replaying,
the DAGJK replicates will not correspond to the original weighting procedure. This will
produce numerically wrong variance estimates without any error being raised.

Options:
- **[A]** Add after DAGJK step 5: "`calibrate_rake()` is called with: `data` =
  `S_A_minus_g` (with `w_i_adj` as the weight column), `targets` = resolved targets,
  `type`, `algorithm`, `cap`, `control` from `calib_entry$parameters` (same parameter
  forwarding as the QR bootstrap calibration-only path)." — Effort: low, Risk: none,
  Impact: ensures faithful calibration replay for all parameter combinations,
  Maintenance: none
- **[B]** Add a cross-reference: "parameter forwarding follows the same contract as
  the QR bootstrap calibration-only path." — Effort: trivial, Risk: low (requires
  builder to cross-reference), Impact: slightly less explicit, Maintenance: none
- **[C] Do nothing** — builder will likely use defaults for `type`, `algorithm`, etc.,
  producing wrong DAGJK estimates for non-default calibration parameter combinations.

**Recommendation: A** — the explicit list makes the contract independently sufficient
without requiring the builder to read the QR bootstrap section.

---

#### Section: Test-spec — `create_bootstrap_weights()` — Warning paths

**Issue 4: No test specified for `surveywts_warning_bootstrap_draws_failed` on calibration-only path**
Severity: SUGGESTION
[Violates testing-standards.md §2 — three mandatory categories; conditional category for warnings]

The spec warnings table includes `surveywts_warning_bootstrap_draws_failed` (fires when
>10% of draws fail). The test-spec warning paths table for `create_bootstrap_weights()`
covers only `surveywts_warning_repweights_overwritten`. The `bootstrap_draws_failed`
warning is existing behavior for the IPW path, but verifying it fires correctly on the
new calibration-only path (where draw failure means `calibrate_rake()` non-convergence
rather than IPW non-convergence) requires a new test. Without this test, the routing
change could silently break the failed-draw counting for the calibration-only path.

Options:
- **[A]** Add a warning-path row: "Trigger: `nps_calib_a` with very small `replicates`
  and a version of `nps_calib_a` with a degenerate data configuration (e.g., an age
  group with 0 units) to force calibration failure. Pattern: `expect_warning(class =
  'surveywts_warning_bootstrap_draws_failed')`." — Effort: medium (constructing a
  reliable degenerate-calibration trigger is non-trivial), Risk: low, Impact: verified
  warning propagation on new path, Maintenance: none
- **[B]** Accept the gap; rely on the existing IPW-path test for this warning class. —
  Effort: none, Risk: low (existing test covers the warning class; new path uses the
  same code path), Impact: new routing not explicitly verified for failed-draw counting
- **[C] Do nothing** — warning not tested for new path.

**Recommendation: B** — the failed-draw counting is shared code, not new. The risk of
not testing it specifically for the calibration-only path is low.

---

#### Section: Test-spec — `create_bootstrap_weights()` — Edge cases

**Issue 5: No test for "calibration entry with no `targets` and no `margins`" edge case**
Severity: REQUIRED
[Violates testing-standards.md §2 — all edge cases in the spec must have tests]

The spec edge case table includes:

> "Calibration entry with no `targets` and no `margins` → `calibrate_rake()` will
> receive `NULL` targets and error; treated as a draw failure."

This edge case has no corresponding test row in the test-spec. This edge case can occur
if a `survey_nonprob` was created with a manually constructed history entry missing the
`targets` field, or if a future calibration function fails to store targets properly.
Without a test, this behavior is unverified and any regression would be silent.

Options:
- **[A]** Add an edge case row: "Trigger: construct a `survey_nonprob` whose calibration
  history entry has `parameters$targets = NULL` and `parameters$margins = NULL`. Call
  `create_bootstrap_weights(type = 'quasi-randomization', replicates = 5L)`. Expected:
  all 5 draws fail; error `surveywts_error_bootstrap_all_draws_failed`." Pattern: dual
  `expect_error(class=...)` + `expect_snapshot(error=TRUE)`. — Effort: low, Risk: none,
  Impact: edge case explicitly verified, Maintenance: none
- **[B]** Accept the gap; the spec is clear that this is a draw-failure case and the
  all-draws-failed error path is already tested. — Effort: none, Risk: low (draw failure
  mechanism is tested; this is a specific trigger for it), Impact: trigger not explicitly
  verified
- **[C] Do nothing** — edge case described in spec, not tested.

**Recommendation: A** — constructing the trigger is low-effort (manually set
`parameters$targets = NULL` in the history entry), and the spec explicitly calls this out
as an edge case.

---

#### Section: Test-spec — `create_bootstrap_weights()` and `create_group_jackknife_weights()` — Snapshot cleanup

**Issue 6: Snapshot deletion for retired error classes not specified in test-spec**
Severity: REQUIRED
[Violates testing-standards.md §3 — snapshot failures block PRs; stale snapshots
require explicit cleanup]

The spec retires two error classes:
- `surveywts_error_qr_bootstrap_no_ipw_history` (replaced by `surveywts_error_qr_bootstrap_no_history`)
- `surveywts_error_dagjk_no_ipw_history` (replaced by `surveywts_error_dagjk_no_history`)

The existing snapshot tests for these retired classes will remain in
`tests/testthat/_snaps/test-replicate-weights.txt` and
`tests/testthat/_snaps/test-nps-group-jackknife.txt` unless explicitly deleted. After
the implementation removes the old error class from the code:
1. Any test block that used `expect_snapshot(error = TRUE, ...)` with the old trigger
   will now produce a snapshot that does not match the recorded old-class snapshot.
2. If the test block is updated to use the new class but the snapshot file retains the
   old entry, `devtools::test()` will warn about orphaned snapshots, potentially
   confusing the tester.

Neither the spec nor the test-spec mentions this cleanup.

Options:
- **[A]** Add a "Snapshot cleanup" note to the test-spec: "Before running
  `devtools::test()`, delete or update any snapshot entries for
  `surveywts_error_qr_bootstrap_no_ipw_history` and
  `surveywts_error_dagjk_no_ipw_history` in the `_snaps/` directories. Run
  `testthat::snapshot_review()` after the first test run to accept the new snapshots."
  — Effort: trivial, Risk: none, Impact: tester knows exactly what to clean up,
  Maintenance: none
- **[B]** Rely on the tester noticing the orphaned snapshots during `devtools::test()`
  and cleaning them up. — Effort: none, Risk: medium (tester may be confused by the
  warning or may clean up the wrong snapshots), Impact: implicit
- **[C] Do nothing** — snapshot cleanup left entirely implicit.

**Recommendation: A** — explicit instruction prevents tester confusion and ensures the
cleanup is not missed.

---

#### Section: Test-spec — `create_group_jackknife_weights()` — Warning paths

**Issue 7: No test for `surveywts_warning_dagjk_replicates_failed` or `surveywts_warning_dagjk_negative_replicate_weights`**
Severity: REQUIRED
[Violates testing-standards.md §2 — every warning class must have a test; these are
in the spec's warnings and edge cases tables]

The DAGJK warnings table includes 4 warning classes. The test-spec warning paths cover
only 2:

| Class | Tested? |
|---|---|
| `surveywts_warning_dagjk_repweights_overwritten` | ✓ |
| `surveywts_warning_dagjk_small_groups` | ✓ |
| `surveywts_warning_dagjk_replicates_failed` | ✗ |
| `surveywts_warning_dagjk_negative_replicate_weights` | ✗ |

`surveywts_warning_dagjk_negative_replicate_weights` is also listed in the spec's edge
case table ("Calibration-only: negative replicate weights produced") but has no test row
in the test-spec edge case or warning tables.

`surveywts_warning_dagjk_replicates_failed` may be tested for the existing IPW path, but
the test-spec does not verify it for the new calibration-only path.

`surveywts_warning_dagjk_negative_replicate_weights` is a scenario that is specific to
calibration (raking can produce negative intermediate weights when targets are tight),
whereas the IPW path always produces positive weights. This is a genuinely new behavior
for the calibration-only path and must be explicitly tested.

Options:
- **[A]** Add to the DAGJK warning paths table:
  - "Trigger for `replicates_failed`: `nps_calib_a` with a calibration configuration
    that causes >10% of group replicates to fail (e.g., tight targets and a small NPS).
    Pattern: `expect_warning(class = 'surveywts_warning_dagjk_replicates_failed')`."
  - "Trigger for `negative_replicate_weights`: construct a `survey_nonprob` with targets
    that force raking to produce negative weights for at least one unit in a group-deleted
    dataset. Pattern: `expect_warning(class =
    'surveywts_warning_dagjk_negative_replicate_weights')`; also assert that the result
    is returned (not errored) and that `@variables$repweights` has the expected length."
  — Effort: medium (constructing triggers requires calibration scenarios that force
  negative weights), Risk: low, Impact: both warning classes explicitly verified,
  Maintenance: none
- **[B]** Accept the `replicates_failed` gap (it's already tested for the IPW path);
  require only the `negative_replicate_weights` test since it's new to the
  calibration-only path. — Effort: low, Risk: low, Impact: partial coverage, Maintenance:
  none
- **[C] Do nothing** — two warning classes go untested.

**Recommendation: A** — both warnings are in the spec table; testing standards require
every warning class to have a test; the triggers, while non-trivial to construct, are
well-defined.

---

#### Section: Lens 6 — API Coherence

**Issue 8: Error class names `_no_history` conflate "no history" with "unsupported history method"; message text not specified in spec**
Severity: SUGGESTION
[Violates code-style.md §3 — "i" bullets must provide context; Lens 6 coherence]

`surveywts_error_qr_bootstrap_no_history` fires for two semantically different
conditions:
1. `@metadata@weighting_history` is empty (truly no history)
2. `@metadata@weighting_history` has entries, but none match the supported operations
   list (e.g., user ran `calibrate_linear()` and then called
   `create_bootstrap_weights(type = "quasi-randomization")`)

A user who calibrated with `calibrate_linear()` and then gets
`surveywts_error_qr_bootstrap_no_history` will be confused: they DID calibrate, but the
error sounds like no weighting was done. The same ambiguity applies to
`surveywts_error_dagjk_no_history`.

The spec does not specify message text for these new error classes (message text is in
`plans/error-messages.md`, which the planner updated). The `"x"` and `"i"` bullets in
`error-messages.md` should clearly say "No `ipw()` or `calibrate_rake()` step found in
the weighting history" — which covers both cases. If `error-messages.md` already has
this language, no fix is needed in the spec. If it uses language that implies "no
history at all," the spec should require a fix.

Options:
- **[A]** Verify that `plans/error-messages.md` entry for both new error classes uses
  language like "No `ipw()` or `calibrate_rake()` step found in the weighting history"
  rather than "No weighting history found." Add a note to the spec requiring this
  language. — Effort: low, Risk: none, Impact: prevents user confusion, Maintenance: none
- **[B]** Leave the spec silent on message text; rely on `error-messages.md`. — Effort:
  none, Risk: low (builder reads error-messages.md), Impact: may or may not produce
  clear messages
- **[C] Do nothing** — error class name is used only in catching code, not user-visible.

**Recommendation: A** — verify and note the required language in the spec. If
`error-messages.md` is already correct, document that verification here and close the
issue.

---

---

### Post-Pass-1 Scope Revision (2026-06-15)

During Stage 3r resolution, the user identified that the "calibration entry"
definition was too narrow. All three calibration functions (`calibrate_rake()`,
`calibrate_linear()`, `calibrate_logit()`) and `poststratify()` store
sufficient parameters in the history entry to enable faithful replay without
any user re-specification. The spec was updated to:

1. Expand the calibration entry detection to all four operations.
2. Replace the single `calibrate_rake()` replay step with a `switch()`-based
   dispatch table in both function contracts.
3. Remove the artificial "GREG-family entries not supported" footnote.
4. Update error trigger descriptions and edge case table entries accordingly.
5. Add dispatch-coverage test rows to both happy-path tables in the test-spec.

`"raking"` (legacy operation string) remains as an implementation note for
backward compatibility but is no longer listed as a distinct operation type.

Issue 8 (error class name ambiguity) is no longer a concern: the error table
now correctly states that the class fires when no supported operation is found,
making the trigger condition explicit regardless of class name.

---

## Summary (Pass 1)

| Severity | Count |
|---|---|
| BLOCKING | 0 |
| REQUIRED | 5 |
| SUGGESTION | 3 |

**Total issues:** 8

**Overall assessment:** The spec is methodologically sound and independently sufficient
for the happy path. Five REQUIRED issues must be resolved before implementation: (1) the
DAGJK section needs the same `calibrate_rake()` weight extraction note as the QR
bootstrap section; (2) the DAGJK algorithm must specify `type`, `algorithm`, `cap`, and
`control` forwarding from the calibration history entry; (3) the test-spec needs a test
for the "no targets/margins" edge case; (4) the test-spec needs snapshot cleanup
instructions for the two retired error classes; (5) the test-spec is missing tests for
`surveywts_warning_dagjk_replicates_failed` and
`surveywts_warning_dagjk_negative_replicate_weights`. All five are low-effort,
unambiguous fixes. Three suggestions address a DRY cross-reference, a warning test gap,
and an error message clarity check.

---

## Spec Review: nps-calibration-path — Pass 2 (2026-06-15)

### Prior Issues (Pass 1)

| # | Title | Status |
|---|---|---|
| 1 | Calibration entry definition stated only in QR bootstrap section; DAGJK repeats it without cross-reference | ⚠️ Still open |
| 2 | `calibrate_rake()` weight extraction note missing from DAGJK calibration-only section | ✅ Resolved |
| 3 | DAGJK `calibrate_rake()` call parameters incomplete — missing `type`, `algorithm`, `cap`, `control` | ✅ Resolved (via "Forward all stored parameters per the dispatch table" language) |
| 4 | No test specified for `surveywts_warning_bootstrap_draws_failed` on calibration-only path | ✅ Accepted (recommendation B accepted; shared code path) |
| 5 | No test for "calibration entry with no `targets` and no `margins`" edge case | ✅ Resolved |
| 6 | Snapshot deletion for retired error classes not specified in test-spec | ✅ Resolved |
| 7 | No test for `surveywts_warning_dagjk_replicates_failed` or `surveywts_warning_dagjk_negative_replicate_weights` | ✅ Resolved |
| 8 | Error class names `_no_history` conflate "no history" with "unsupported history method" | ✅ Resolved (closed by scope revision; error table trigger descriptions now explicit) |

### New Issues

---

#### Section: `create_bootstrap_weights()` — Failed draw handling

**Issue 9: "Failed draw handling" section names `calibrate_rake()` specifically; silent negative-weight failure from `calibrate_linear()` unspecified**
Severity: REQUIRED
[Under-engineered per engineering-preferences.md §3; Lens 5 failure-mode gap]

The "Failed draw handling (calibration-only path)" section reads:

> "A draw fails if `calibrate_rake()` throws an error (e.g., non-convergence)."

But the calibration-only bootstrap dispatches to all four operations (`calibrate_rake`,
`calibrate_linear`, `calibrate_logit`, `poststratify`) based on what is in the calibration
history entry. This section was apparently not updated when the scope expanded to all four
operations.

More critically: `calibrate_linear()` with `bounds = NULL` (the default) can produce
negative calibrated weights without throwing an error — it converges and returns a
`weighted_df` whose weight column contains negative values. The spec defines a draw as
failed only when the calibration function **throws an error**. So a bootstrap draw using
`calibrate_linear()` that produces a negative-weight column would be silently included in
the replicate weight matrix. Neither `test_invariants()` nor the S7 validator would catch
this: `@variables$weights` still points to the main weight column (always positive), not
the replicate columns.

The DAGJK spec explicitly handles this case via
`surveywts_warning_dagjk_negative_replicate_weights`. The bootstrap spec has no analogous
handling.

By contrast, `calibrate_logit()` has default bounds `c(1e-6, 1e6)` guaranteeing positive
output, and `poststratify()` multiplies positive weights by positive cell factors, so both
are safe. Only `calibrate_linear()` with `bounds = NULL` is at risk.

Options:
- **[A]** Update the "Failed draw handling" section to: (1) replace `calibrate_rake()` with
  "the dispatched calibration function"; (2) add: "A draw also fails if the dispatched
  calibration function produces any non-positive weights in the calibrated output. This
  case applies to `calibrate_linear()` when `bounds = NULL` — the function converges but
  may return negative weights. The draw is treated as failed and counted toward
  `surveywts_warning_bootstrap_draws_failed`." — Effort: low, Risk: none, Impact: closes
  silent correctness hole; consistent with DAGJK negative-weight handling, Maintenance: none
- **[B]** Emit a warning analogous to `surveywts_warning_dagjk_negative_replicate_weights`
  when a bootstrap replicate column contains non-positive values (retain the replicate but
  warn). This is the DAGJK policy; apply it to bootstrap too. — Effort: low, Risk: low,
  Impact: consistent policy across both functions; user learns of negatives, Maintenance: none
- **[C] Do nothing** — negative bootstrap repweights from `calibrate_linear()` silently
  enter the variance estimator, producing wrong SEs with no indication.

**Recommendation: A** — treating negative-weight draws as failed (same as non-convergence)
is methodologically clean and consistent with the spec's existing "degenerate inputs" framing.

---

**Issue 10: `surveywts_warning_bootstrap_draws_failed` text change not covered by snapshot cleanup note in test-spec**
Severity: REQUIRED
[Violates testing-standards.md §3 — snapshot failures block PRs; stale snapshots require explicit cleanup]

The spec requires the following text change to `surveywts_warning_bootstrap_draws_failed`:

> Old: "A draw fails when `ipw()` or calibration does not converge (e.g., degenerate
> propensity scores in the resampled data)."
>
> New: "A draw fails when calibration or IPW re-estimation does not converge (e.g.,
> degenerate inputs in the resampled data)."

The existing test suite for the IPW path presumably has a snapshot that records the OLD text.
When the builder changes the warning message, the existing snapshot in
`tests/testthat/_snaps/replicate-weights.md` (or `nps-group-jackknife.md`) will no longer
match, blocking `devtools::test()`. The test-spec snapshot cleanup notes cover only the
retired error classes (`surveywts_error_qr_bootstrap_no_ipw_history` and
`surveywts_error_dagjk_no_ipw_history`). They do not mention this warning-text snapshot.

The tester would encounter a confusing snapshot failure on an existing test that "should"
pass and might incorrectly revert the message text change.

Options:
- **[A]** Add to the test-spec "Snapshot cleanup" section for `create_bootstrap_weights()`:
  "Additionally, the `'i'` bullet text of `surveywts_warning_bootstrap_draws_failed` is
  changed in this PR. Any existing snapshot entries for this warning class in
  `tests/testthat/_snaps/replicate-weights.md` must be updated via
  `testthat::snapshot_review()` to reflect the new text. Do NOT revert the text change to
  make the snapshot pass." — Effort: trivial, Risk: none, Impact: tester knows exactly
  what to do, Maintenance: none
- **[B]** Rely on the tester noticing the broken snapshot and investigating its source. —
  Effort: none, Risk: medium (tester may revert the message change to fix the snapshot),
  Impact: implicit
- **[C] Do nothing** — snapshot failure without instruction; implementation risk.

**Recommendation: A** — one sentence in the cleanup note prevents a silent regression of the
text change.

---

#### Section: Test-spec — `create_group_jackknife_weights()` — Error paths

**Issue 11: `surveywts_error_dagjk_all_replicates_failed` has no test in the test-spec**
Severity: REQUIRED
[Violates testing-standards.md §2 — every error class in the error table must have a test]

The DAGJK error table includes `surveywts_error_dagjk_all_replicates_failed` (fires when
all G group replicates fail). The spec edge cases also describe this condition: "All group
replicates fail → Error `surveywts_error_dagjk_all_replicates_failed`." But neither the
error paths section nor the edge cases section of the DAGJK test-spec includes a test
row for this error class. The spec's edge case table has "All group replicates fail" under
the `create_group_jackknife_weights()` section but with no corresponding test row.

By contrast, `surveywts_error_bootstrap_all_draws_failed` IS tested for the bootstrap
(via the null-targets edge case). The analogous DAGJK error is untested.

`surveywts_error_dagjk_degenerate_replicate` is thrown inside `tryCatch()` and is therefore
not directly user-visible; it is implicitly exercised via the `dagjk_replicates_failed`
warning test. But `dagjk_all_replicates_failed` IS user-visible and needs an explicit test.

Options:
- **[A]** Add an error path row to the DAGJK test-spec:
  "Trigger: Construct a `survey_nonprob` calibrated to targets that guarantee calibration
  failure for every group (e.g., tight count targets and `nps_calib_a` with `groups = 2L`
  plus a calibration step whose stored targets include a level that disappears when half
  the data is removed). Expected: error `surveywts_error_dagjk_all_replicates_failed`.
  Pattern: dual `expect_error(class = ...)` + `expect_snapshot(error = TRUE, ...)`."
  — Effort: low-medium (constructing a trigger requires a degenerate-target scenario),
  Risk: none, Impact: error class explicitly verified, Maintenance: none
- **[B]** Add to the edge cases table only (not the error paths table), with the same
  trigger and pattern. — Effort: same, Risk: none, Impact: same, Maintenance: none
- **[C] Do nothing** — error class goes untested; a regression in the all-replicates-failed
  path would be silent.

**Recommendation: A** — use the error paths table for consistency with how
`surveywts_error_bootstrap_all_draws_failed` is handled in the bootstrap test-spec.

---

#### Section: Architecture — Calibration dispatch table

**Issue 12: Spec assumes calibration history entries store all required forwarded parameters; assumption unverified**
Severity: SUGGESTION
[Violates engineering-preferences.md §5 — explicit over implicit; implicit assumption on existing implementation]

The calibration dispatch table specifies parameters to forward from `calib_entry$parameters`,
for example:

> `"calibrate_linear"` → parameters forwarded: `targets`, `type`, `bounds`, `bounds_scale`,
> `unit_scale`, `control`

The dispatch relies on `calib_entry$parameters$bounds_scale` being present in the history
entry. But whether `calibrate_linear()` actually stores `bounds_scale` (as opposed to only
storing the resolved `bounds`) in its history entry is not verified in the spec. If
`bounds_scale` is not stored, then `calib_entry$parameters$bounds_scale` will be `NULL`,
and the dispatch call will use the default `"multiplicative"` — silently wrong if the
original calibration used `bounds_scale = "absolute"`.

The same concern applies to `unit_scale` for both `calibrate_linear()` and
`calibrate_logit()`.

For `calibrate_rake()`, the spec handles the legacy case (`"raking"` / `margins`) but
assumes `type`, `algorithm`, `cap`, and `control` are stored. These are almost certainly
stored (the history entry pattern for `rake()` is well-established), but this isn't
stated.

Options:
- **[A]** Add a verification note to the spec Architecture section: "Assumption: existing
  calibration functions (`calibrate_linear()`, `calibrate_logit()`, `calibrate_rake()`,
  `poststratify()`) store all parameters listed in the dispatch table under
  `calib_entry$parameters`. Verify by reading the history entry of a `survey_nonprob` after
  calling each function. If a parameter is not stored, forward `NULL` (using the function's
  default), and document the limitation." — Effort: low, Risk: none, Impact: builder
  explicitly validates before implementing, Maintenance: none
- **[B]** Add the verification to the spec review only (this issue), not the spec itself.
  The builder should verify during implementation. — Effort: trivial, Risk: low (builder
  may or may not notice), Impact: implicit dependency surfaced here only
- **[C] Do nothing** — builder discovers at implementation time whether parameters are stored.

**Recommendation: B** — the risk is low because `NULL` for a missing parameter uses the
function's default, which is typically the same as the original call. But the builder should
be aware of this assumption and verify during implementation.

---

### Summary (Pass 2)

| Severity | Count |
|---|---|
| BLOCKING | 0 |
| REQUIRED | 3 |
| SUGGESTION | 2 |

**Total new issues:** 5 (Issues 9–12, plus carryforward of Issue 1)

**Overall assessment:** The spec is close to implementation-ready — all five REQUIRED issues
from Pass 1 were resolved and the scope expansion to all four calibration operations is
well-specified. Three REQUIRED gaps remain: (1) the "Failed draw handling" section still
references `calibrate_rake()` specifically and does not specify behavior when
`calibrate_linear()` produces negative weights without erroring; (2) the snapshot cleanup
notes must mention the `surveywts_warning_bootstrap_draws_failed` text change; (3) the
test-spec has no test for `surveywts_error_dagjk_all_replicates_failed`. All three are low
effort. The two SUGGESTION-level items (DRY cross-reference from Pass 1, and the unverified
parameter-storage assumption) can be resolved at the builder's discretion without blocking
implementation.

---

## Resolution — Pass 2 (2026-06-15)

| # | Title | Decision | Outcome |
|---|---|---|---|
| 1 | Calibration entry definition cross-reference in DAGJK | Option B | Parenthetical "(same definition as in `create_bootstrap_weights` above)" added to DAGJK routing step 5 |
| 9 | Failed draw handling names `calibrate_rake()` specifically; silent negative-weight case unspecified | Option A | "Failed draw handling" section updated: names "the dispatched calibration function"; adds explicit negative-weight draw-failure rule for `calibrate_linear()` |
| 10 | Snapshot cleanup missing for `surveywts_warning_bootstrap_draws_failed` text change | Option A | Snapshot cleanup note in test-spec updated to include warning text change instruction |
| 11 | `surveywts_error_dagjk_all_replicates_failed` untested | Option A | Error path row added to DAGJK error paths table with dual `expect_error` + `expect_snapshot` pattern |
| 12 | Parameter storage assumption unverified for `calibrate_linear()`/`calibrate_logit()` | Option A | Verification note added to spec Architecture section; builder must inspect history entry before implementing dispatch |

**Verdict: PASS** — all REQUIRED and BLOCKING issues resolved. Spec is approved for implementation.
