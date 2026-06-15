## Spec Review: calibrate-nonprob — Pass 1 (2026-06-15)

### New Issues

#### Section: test-spec — Datasets / Helper definitions

**Issue 1: `make_nonprob_replicate_design()` helper sketch omits `type = "quasi-randomization"`**
Severity: REQUIRED

The sketch in `test-spec-calibrate-nonprob.md §Datasets` shows:

> 4. Call `create_bootstrap_weights(ipw_result, replicates = 50L)` to populate replicate weights.

`create_bootstrap_weights()` defaults to `type = "Rao-Wu-Yue-Beaumont"` (a probability-sample type). When called on a `survey_nonprob`, the prob-sample path goes through `.convert_and_call()`, which returns a `survey_replicate` — NOT a `survey_nonprob`. The helper would produce the wrong class.

The quasi-randomization bootstrap (`type = "quasi-randomization"`) is the only path that returns a `survey_nonprob` with `@variables$repweights` populated.

**Fix:** Add `type = "quasi-randomization"` to step 4 of the helper sketch.

Options:
- **[A]** Fix the sketch: `create_bootstrap_weights(ipw_result, replicates = 50L, type = "quasi-randomization", seed = seed)` — Effort: low, Risk: low, Impact: helper now produces correct class
- **[C] Do nothing** — helper produces a `survey_replicate`; all new happy-path tests fail silently with the wrong input type

**Recommendation: A** — One-word fix; no other approach works.

---

#### Section: spec — Error messages / snapshot impact

**Issue 2: Snapshot update instruction is in test-spec but not flagged in spec**
Severity: SUGGESTION

The test-spec notes that three existing `_not_replicate` error snapshot files will break (because the message text changes). The spec's Out of Scope section says "Snapshot updates for existing tests are NOT in scope" — but that's referring to tests NOT touching these classes. The three `_not_replicate` class messages ARE changing in this PR (the spec updates their message text). The Out of Scope wording is misleading.

Options:
- **[A]** Clarify the spec Out of Scope sentence: "Snapshot updates for error classes whose message text is unchanged are not in scope. The three `_not_replicate` snapshots will need updating because their message text changes."
- **[C] Do nothing** — the test-spec already covers this; a builder might be confused but a tester will see the failures and use `snapshot_review()`.

**Recommendation: A** — Low-effort clarity fix; removes ambiguity for the builder.

---

#### Section: test-spec — Happy path / `calibrate_to_survey()`

**Issue 3: Replicate scheme mismatch warning behavior with NULL type not documented**
Severity: SUGGESTION

When `primary_design` is a quasi-randomization `survey_nonprob` (whose `@variables$type` is NULL) and `control_design` is a `survey_replicate` with a named type (e.g., `"Rao-Wu-Yue-Beaumont"`), the mismatch warning does NOT fire because the existing code guards with `!is.null(primary_type)`. The test-spec does not include a scenario verifying this expected-no-warning behavior.

Options:
- **[A]** Add an explicit "no mismatch warning fires when primary type is NULL" test case to the edge cases table
- **[C] Do nothing** — the existing guard logic is tested by the existing mismatch-warning test; this is a secondary consequence, not a new behavior

**Recommendation: C** — The guard is already tested elsewhere; documenting it here adds low value.

---

## Summary (Pass 1)

| Severity | Count |
|---|---|
| BLOCKING | 0 |
| REQUIRED | 1 |
| SUGGESTION | 2 |

**Total issues:** 3

**Overall assessment:** The spec and test-spec are well-structured and near-implementable. One REQUIRED fix in the test-spec helper sketch (missing `type = "quasi-randomization"`) would cause all new happy-path tests to produce the wrong input class; everything else is suggestions.

---

### Resolutions (Pass 1)

| # | Issue | Resolution |
|---|---|---|
| 1 | `make_nonprob_replicate_design()` missing `type = "quasi-randomization"` | FIXED — added to step 4 of helper sketch in test-spec |
| 2 | Snapshot impact wording in spec Out of Scope | FIXED — clarified to distinguish changed vs unchanged snapshots |
| 3 | Mismatch warning with NULL type | ACCEPTED as-is — existing guard behavior, not a new behavioral change |

**Verdict: PASS** — all REQUIRED issues resolved; suggestions accepted or deferred.
