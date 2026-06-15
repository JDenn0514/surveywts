## Plan Review: calibrate-nonprob — Pass 1 (2026-06-15)

### New Issues

#### Section: Acceptance Criteria — Missing Required Entries

---

**Issue 1: Changelog entry not listed as file or acceptance criterion**
Severity: REQUIRED
[Violates `changelog-workflow.md` — `commit-and-pr` enforces a changelog file before every PR]

`changelog-workflow.md` requires `changelog/phase-{X}/{branch-name}.md` to exist before
a PR is opened. `commit-and-pr` actively validates this with four rules (file exists,
not a stub, `## Changes` has at least one bullet, `## Files Modified` lists at least one file).
The plan's file list omits this file entirely, and none of the acceptance criteria mention it.

Options:
- **[A]** Add `changelog/phase-{X}/feature-calibrate-nonprob.md` to the file list (step 7)
  and add an acceptance criterion: "Changelog entry committed on branch at
  `changelog/phase-{X}/feature-calibrate-nonprob.md`." — Effort: low, Risk: low,
  Impact: unblocks `commit-and-pr` and prevents PR opening failure
- **[B]** Add a note clarifying that changelog is created by `commit-and-pr` automatically
  and does not need to be listed — Effort: low, Risk: low, Impact: documents the
  existing behavior without adding a step
- **[C] Do nothing** — `commit-and-pr` will block PR opening when it finds no changelog file

**Recommendation: A** — The changelog is part of the write surface for this PR. Naming
it in the file list makes the builder's responsibilities explicit and avoids surprises at PR time.

---

**Issue 2: `control_design_class` history field for mixed-class inputs absent from acceptance criteria**
Severity: REQUIRED
[Violates Spec §Quality gates: "The `control_design_class` field in `history_params` records `class(control_design)[[1L]]`"]

The spec's quality gates explicitly call out that `control_design_class` must record the
actual class of `control_design`. The test-spec adds two edge cases that directly verify
this for the new mixed-class scenarios:

- `primary_design = make_nonprob_replicate_design()`, `control_design = make_replicate_design()`
  → `history_params$control_design_class == "survey_replicate"`
- Both `make_nonprob_replicate_design()` → `history_params$control_design_class` contains
  `"survey_nonprob"`

The plan's acceptance criteria include `@metadata@weighting_history` grows by one entry but
do not require verifying the `control_design_class` field value. A builder could ship
without the `control_design_class` field being set correctly for the new nonprob paths
and the plan gate would not catch it.

Options:
- **[A]** Add acceptance criterion: "`control_design_class` in the last weighting history
  entry correctly records `class(control_design)[[1L]]` for both mixed-class and
  both-nonprob scenarios." — Effort: low, Risk: low, Impact: closes the spec quality
  gate → acceptance criteria gap
- **[B]** Leave to the tester (test-spec covers it) — Effort: none, Risk: medium,
  Impact: builder completes work without a self-check; tester catches it but feedback
  loop is longer
- **[C] Do nothing** — spec quality gate is unrepresented in the builder's acceptance gate

**Recommendation: A** — The spec explicitly lists this as a quality gate; the plan's
acceptance criteria should reflect it.

---

**Issue 3: `surveywts_error_targets_levels_mismatch` regression guard missing for `survey_nonprob` input**
Severity: REQUIRED
[Violates Lens 4 — Spec Coverage: test-spec §calibrate_to_estimate() edge cases has this scenario; plan's regression guards do not]

The test-spec includes this edge case for `calibrate_to_estimate()`:

> `design` is `survey_nonprob` with repweights; `targets` are mismatched levels
> → Errors: `surveywts_error_targets_levels_mismatch` (existing class, existing behavior)

The plan's regression guards cover:
- `survey_replicate` + `survey_replicate` → still returns `survey_replicate` ✅
- `_not_replicate` errors still fire for wrong types (data.frame, survey_taylor) ✅

But they do NOT cover: downstream existing error classes (like `_targets_levels_mismatch`)
still fire when `design` is `survey_nonprob`. The refactoring of the validation logic
in `calibrate_to_estimate.R` could accidentally change ordering or miss a check; this
regression guard would catch that.

Options:
- **[A]** Add acceptance criterion: "Regression guard: `surveywts_error_targets_levels_mismatch`
  still fires when `design = make_nonprob_replicate_design()` and target level names
  are intentionally wrong." — Effort: low, Risk: low, Impact: guards against
  validation-order breakage in the refactored `calibrate_to_estimate()` code path
- **[B]** Accept that tester catches it via test-spec — Effort: none, Risk: medium,
  Impact: longer feedback loop if builder breaks existing validation order
- **[C] Do nothing** — regression gap for existing error class with new input type

**Recommendation: A** — This is the one existing downstream error class the test-spec
explicitly adds for the new input type, and it guards the correctness of the refactored
validation chain.

---

#### Section: PR 1 — Acceptance Criteria (minor gaps)

---

**Issue 4: `nrow(result@data)` preservation check absent from happy-path acceptance criteria**
Severity: SUGGESTION
[Test-spec specifies this for all three `calibrate_to_survey()` happy-path scenarios and the `calibrate_to_estimate()` scenario]

The test-spec for every happy-path block says: "Verify `nrow(result@data)` equals
`nrow(primary_design@data)`." This is omitted from the plan's acceptance criteria.

Options:
- **[A]** Add a single criterion covering all happy paths: "Result row count equals
  `primary_design@data` / `design@data` row count." — Effort: low, Risk: low
- **[B]** Leave to tester — Effort: none, Risk: low (easily caught)
- **[C] Do nothing** — minor gap; structural invariant

**Recommendation: B** — The tester will catch this via test-spec; adding it to the
plan would marginally help but is not critical given test_invariants() would also
surface most structural problems.

---

**Issue 5: Three snapshot filenames not named in regression guard criterion**
Severity: SUGGESTION
[Lens 3 — Acceptance Criteria: verifiability]

The criterion "Regression guard `_not_replicate` snapshots updated and accepted via
`snapshot_review()`" does not name which three snapshot files change. The test-spec
explicitly names them: `surveywts_error_primary_not_replicate`,
`surveywts_error_control_not_replicate`, and `surveywts_error_design_not_replicate`.

Without naming them, a builder working quickly could miss updating the `_design_not_replicate`
snapshot (in `calibrate_to_estimate()`) which lives in a different part of the test file
from the primary/control snapshots.

Options:
- **[A]** Revise the criterion to: "Updated snapshots accepted via `snapshot_review()` for
  all three affected classes: `_primary_not_replicate`, `_control_not_replicate`, and
  `_design_not_replicate`." — Effort: low, Risk: low
- **[B]** Leave as-is — implementation notes describe the change and the tester catches it
- **[C] Do nothing** — minor ambiguity

**Recommendation: A** — One line change that eliminates ambiguity about scope; worth doing.

---

**Issue 6: Negative class assertion (`expect_false`) absent from happy-path acceptance criteria**
Severity: SUGGESTION
[Test-spec specifies "Verify the result class does NOT equal the alternate class" for each happy-path scenario]

The plan lists positive class assertions (e.g., "returns `survey_nonprob`") but not the
negative (e.g., "result is NOT `survey_replicate`"). The test-spec adds
`expect_false(S7::S7_inherits(result, surveycore::survey_replicate))` for each nonprob
happy path. Without the negative assertion, a buggy constructor call that returns an
object inheriting both classes would still pass the plan's gate.

Options:
- **[A]** Revise each happy-path criterion to include the negative: "returns `survey_nonprob`
  (not `survey_replicate`)." — Effort: low, Risk: low
- **[B]** Leave to tester — Effort: none, Risk: very low (S7 inheritance hierarchy
  makes this essentially impossible in practice)
- **[C] Do nothing** — the spec's output construction section makes clear only one
  constructor is called

**Recommendation: B** — S7 makes dual-class inheritance structurally impossible here.
The negative assertion adds safety but the risk of missing it is minimal.

---

### Summary (Pass 1)

| Severity | Count |
|---|---|
| BLOCKING | 0 |
| REQUIRED | 3 |
| SUGGESTION | 3 |

**Total issues:** 6

**Overall assessment:** The plan is structurally sound — single coherent PR, correct TDD
ordering, thorough implementation notes, and implementation code blocks that match the
spec exactly. The three required issues are all acceptance-criteria gaps (missing
changelog file, missing history-field quality gate, missing downstream regression guard)
that should be filled before coding starts; none require changes to the implementation
approach or file scope.
