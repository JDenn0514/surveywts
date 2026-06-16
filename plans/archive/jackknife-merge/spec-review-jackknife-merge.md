# Spec Review: jackknife-merge — Stage 3 (2026-06-16)

---

## Lens 1 — Contract Completeness

### 1.1 — Validation step note is incorrect (REQUIRED)

The "Input validation order" section header states:

> Steps 1–4 apply on every call. Steps 5–12 apply only on the DAGJK path
> (`type = "grouped"` + `survey_nonprob`).

But the list has **15** steps, not 12. The note should read "Steps 5–15 only
apply on the DAGJK path." This is a copy error introduced when the steps were
renumbered. A builder reading the note would think steps 13–15 apply on all
paths, which contradicts the step text itself (steps 13–15 clearly reference
`survey_nonprob`-specific behavior). The note must be corrected to match the
actual step count.

### 1.2 — `"jkn"` vs `"jk1"` dispatch within the JK path unspecified (REQUIRED)

The current `create_jackknife_weights()` implementation **auto-detects** whether
to call `survey::as.svrepdesign(type = "JKn")` or `type = "JK1"` based on
whether `data@variables$strata` is `NULL`. The new spec replaces this with
user-supplied `type = "jkn"` or `type = "jk1"` — a behavioral change that is
intentional.

The spec does not contain a note explaining this behavioral change to the
builder. Specifically, the JKn backend contract says:

> `backend_fn`: a closure calling `survey::as.svrepdesign(d, type = "JKn", mse = mse)`

But it does not state that the builder must **always** pass `type = "JKn"` when
`type = "jkn"` (and must not auto-detect). This omission risks a builder
carrying forward the old auto-detection logic. A sentence must be added to the
JKn backend contract: "Do not auto-detect JKn vs. JK1 based on strata; the
`type` argument is user-controlled."

### 1.3 — Documentation tier check: Convergence section (acceptable absence, no action needed)

The spec correctly designates `create_jackknife_weights()` as Tier 3 —
Algorithmic. Per `function-documentation.md`, Tier 3 requires `@section
Convergence:` for iterative methods. Jackknife weight construction is not
iterative (the DAGJK loop terminates in `G` steps with no convergence
criterion); `@section Convergence:` is not required. The spec's absence of a
convergence section is correct.

### 1.4 — `@seealso` missing `create_group_jackknife_weights()` (acceptable, no action needed)

The spec's `@seealso` lists all current `@family replicate-weights` members.
`create_group_jackknife_weights()` is deleted by this merge, so it correctly
does not appear.

### 1.5 — `replicates` default for `"grouped"` + `survey_nonprob` not in signature (REQUIRED)

The spec signature shows `replicates = NULL`. The `replicates` argument
description for `"grouped"` + `survey_nonprob` says G = 50 is "a practical
starting point" and recommends it, but the default in the signature is `NULL`,
which requires the user to always supply it — the function errors if
`replicates = NULL` with `type = "grouped"`.

The existing `create_group_jackknife_weights()` had `groups = 50L` as a default.
The spec removes this default (replacing with `NULL`, making it required). This
is a deliberate design decision, but the spec does not state it explicitly. This
creates ambiguity: a builder reading "a starting value of 50 is practical" might
add a default back. The spec must explicitly state: "`replicates` has no default;
the function always requires the caller to provide a value when `type =
'grouped'`." If the intent is to restore the `50L` default, a decision must be
made and recorded.

---

## Lens 2 — Internal Consistency

### 2.1 — Validation order note says "Steps 12–15" but body has 15 steps: same issue as 1.1

The note at the bottom of the "Input validation order" section says:

> Note: Steps 12–15 only apply on the DAGJK path.

This is inconsistent with the body, which labels all DAGJK-specific steps as
5–15 ("Steps 5–12 apply only on the DAGJK path" in the header). The two
sentences within the same section contradict each other:

- Header: "Steps 1–4 apply on every call. **Steps 5–12** apply only on the DAGJK path."
- Footer note: "Note: **Steps 12–15** only apply on the DAGJK path."

The correct statement is that steps 5–15 are all DAGJK-only. This internal
contradiction would leave the builder uncertain about whether steps 5–11 apply
universally or only on the DAGJK path.

### 2.2 — History `operation` field is consistent (no issue)

Verification:
- JKn / JK1 / grouped + `survey_taylor` → `operation = "replicate_creation"`, `method = "jackknife"`, `parameters$type = "jkn"` / `"jk1"` / `"grouped"` — consistent across: @returns, Output contracts, History entry schema, and Quality gates.
- DAGJK → `operation = "jackknife_weights"` (no `method` field) — consistent across: @returns, Output contracts, History entry schema, DAGJK backend contracts, and Quality gates.
- Quality gate explicitly states: "No path may write `'group_jackknife_weights'`." Correct.

### 2.3 — Degenerate replicate trigger: inconsistency between Error catalogue and DAGJK internals section (BLOCKING)

The **Error catalogue** (Errors section of the spec) states the trigger for
`surveywts_error_jackknife_degenerate_replicate` as:

> A DAGJK group replicate produced **non-positive or NA** weights, or reduced
> dataset has no NPS or reference units; caught inside the replicate loop and
> counted as a failure

The **DAGJK internals section** (`.dagjk_single_replicate()` description) states
the updated trigger as:

> **"non-positive, non-finite, or NA weights"** (expanded from "non-positive or
> NA weights"). Inf weights (arising from `n_h / (n_h - n_hg)` when
> `n_hg = n_h`) are counted as failures.

These two descriptions of the same error class disagree. The Error catalogue was
not updated when the Stage 2 review expanded the degenerate check. The
`error-messages.md` registry entry for
`surveywts_error_jackknife_degenerate_replicate` also reads "non-positive or NA"
(not "non-positive, non-finite, or NA"). All three locations must agree. The
spec's Error catalogue must be updated to read "non-positive, non-finite, or NA
weights." The `error-messages.md` entry must be updated to match.

### 2.4 — Error class name mismatch: `surveywts_error_jackknife_replicates_invalid` vs `surveywts_error_replicates_invalid` (BLOCKING)

In the spec's **Errors table** (the short table under "#### Errors"):

```
| `surveywts_error_replicates_invalid` | `replicates` is not a single non-NA numeric value (DAGJK path; uses existing class) |
```

In the spec's **Error catalogue** (longer section below):

```
| `surveywts_error_jackknife_replicates_invalid` | "`replicates` must be a single, non-NA number." | Non-numeric, length ≠ 1, or `NA` (DAGJK path) |
```

These are **two different class names for the same error**. The "Existing classes
reused" sub-table directly below the catalogue confirms the intended design: the
DAGJK path uses `surveywts_error_replicates_invalid` (the existing class, not a
new jackknife-prefixed one):

```
| `surveywts_error_replicates_invalid` | Wrong type/length/NA in `replicates` (DAGJK path, via `.validate_replicates_dagjk_arg()`) |
```

And `error-messages.md` registers **both**:
- `surveywts_error_replicates_invalid` (existing, in "Replicate Weight Functions" section)
- `surveywts_error_jackknife_replicates_invalid` (new, registered for this merge)

The DAGJK internals section says the renamed helper `.validate_replicates_dagjk_arg()` maps from the old `surveywts_error_dagjk_groups_invalid` to `surveywts_error_jackknife_replicates_invalid`. But the "Existing classes reused" table says the DAGJK path uses the existing `surveywts_error_replicates_invalid`.

The spec is internally contradictory about which class is thrown for invalid
`replicates` on the DAGJK path. The builder will implement one and the tester
will test the other.

**The resolution must be explicit:** either:
(a) The DAGJK path uses the existing `surveywts_error_replicates_invalid` (consistent with the "Existing classes reused" table), in which case `surveywts_error_jackknife_replicates_invalid` should be removed from the Error catalogue and from `error-messages.md`; or
(b) The DAGJK path uses the new `surveywts_error_jackknife_replicates_invalid`, in which case it must be removed from the "Existing classes reused" table and the Errors table must be corrected.

This is a BLOCKING contradiction.

### 2.5 — `replicates` default removal is implied but not stated as a deliberate break (REQUIRED)

Related to finding 1.5 above: the existing function has `groups = 50L`;
the merged spec has `replicates = NULL`. The spec does not say this is
intentional. This could be read as an omission rather than a decision.

---

## Lens 3 — Test Completeness

### 3.1 — Error class mismatch in test-spec for `surveywts_error_jackknife_replicates_invalid` (BLOCKING)

The test-spec error paths table contains:

```
| `surveywts_error_jackknife_replicates_invalid` | `replicates = "fifty"` with DAGJK path | Inline `survey_nonprob` |
```

This is the new class registered in `error-messages.md`. But as established in
finding 2.4, the spec's "Existing classes reused" table says the DAGJK path uses
`surveywts_error_replicates_invalid` (the old class). The test-spec will test the
wrong class unless the underlying contradiction in the spec is resolved first.
This is a consequence of Lens 2 finding 2.4 and blocks until that is resolved.

### 3.2 — No dual-pattern snapshot test for `surveywts_error_jackknife_replicates_required` (REQUIRED)

The test-spec specifies the dual pattern for all error paths in the preamble:
"Every error path test uses the dual pattern: one `expect_error(class = ...)` and
one `expect_snapshot(error = TRUE, ...)`."

The error paths table includes `surveywts_error_jackknife_replicates_required`
with two rows (one for `survey_taylor`, one for `survey_nonprob`). Both rows
are present. No issue with coverage.

On further review, the dual pattern coverage appears complete for all listed
errors. No issue here. Retracting.

### 3.3 — Missing test for `surveywts_error_jackknife_type_nonprob_only` with `type = "jk1"` snapshot (no issue)

The test-spec has two separate rows for this error class: one for
`type = "jkn"` and one for `type = "jk1"`. Both use the dual pattern. Complete.

### 3.4 — `test_invariants()` coverage for warning paths (REQUIRED)

The warning paths table specifies `test_invariants(result)` for
`surveywts_warning_jackknife_svrep_args_ignored` but **not** for the other five
warning paths where a `survey_nonprob` is returned:
- `surveywts_warning_jackknife_mse_overridden`
- `surveywts_warning_jackknife_repweights_overwritten`
- `surveywts_warning_jackknife_small_groups`
- `surveywts_warning_jackknife_replicates_failed`
- `surveywts_warning_jackknife_negative_replicate_weights`

Per `testing-surveywts.md`: "`test_invariants(obj)` is the first assertion for
every test that constructs a `weighted_df` or `survey_nonprob`." All five of the
above warning paths return a `survey_nonprob`; all five must call
`test_invariants(result)`. The test-spec omits this requirement for those five.

### 3.5 — `test_invariants()` not called for JK1 and grouped + `survey_taylor` happy paths (acceptable)

The happy path table note states: "For every block that constructs a returned
object, call `test_invariants(obj)` as the first assertion (applies to the
`survey_nonprob` DAGJK output; does not apply to `survey_replicate` output)."
This parenthetical carve-out is correct — `test_invariants()` is not defined for
`survey_replicate`. No issue.

### 3.6 — History entry validation table: DAGJK `method` field (no issue)

The history entry validation table correctly specifies DAGJK as having no
`method` field (marked as "*(not present)*"), consistent with the DAGJK path
writing the entry directly (not via `.convert_and_call()`). This matches the
spec's History entry schema. No issue.

### 3.7 — No test for `create_replicate_weights()` documentation update (acceptable gap)

The test-spec covers the behavioral changes to `create_replicate_weights()`
(pass-through and removal of `"group-jackknife"`), but does not cover the
roxygen documentation update (removal of `"group-jackknife"` from `@param
method`). This is correctly out of scope for an automated test; it is a
quality gate item (`devtools::run_examples()`). No issue.

### 3.8 — Edge case: `replicates = 2L` (minimum) test is present but invariant call missing (REQUIRED)

Edge case table row: "`replicates = 2L` (minimum) on DAGJK path | Inline
`survey_nonprob` | Succeeds; `length(result@variables$repweights) == 2`"

This path returns a `survey_nonprob`; per `testing-surveywts.md`, `test_invariants(result)` is required as the first assertion. The expected behavior column does not include it.

This is the same pattern as finding 3.4 — `test_invariants()` is systematically
omitted from DAGJK paths that return `survey_nonprob` in the edge cases table.

### 3.9 — `replicates = 50.0` (double) edge case test: invariant call missing (REQUIRED)

Same issue as 3.8. Edge case row: "`replicates = 50.0` (double) on DAGJK path"
returns `survey_nonprob`; `test_invariants(result)` must be added.

---

## Lens 4 — Scope Discipline

### 4.1 — File surfaces are disjoint and complete (no issue)

Files touched (from the spec's "Files touched" section) are:

| File | Action |
|------|--------|
| `R/create_jackknife_weights.R` | Replaced |
| `R/create_group_jackknife_weights.R` | Deleted |
| `R/jackknife-dagjk-utils.R` | Created |
| `R/create_replicate_weights.R` | Modified |
| `R/replicate-utils.R` | Unchanged |
| `plans/error-messages.md` | Updated |
| `tests/testthat/test-replicate-weights.R` | Modified |
| `tests/testthat/test-nps-jackknife.R` | Renamed and updated |
| `tests/testthat/test-replicate-dispatch.R` | Modified |
| `man/create_jackknife_weights.Rd` | Regenerated |
| `man/create_group_jackknife_weights.Rd` | Deleted |
| `NAMESPACE` | Regenerated |

No two PR surfaces overlap (PR 1 and PR 2 are not explicitly delineated in the
spec, but the impl plan governs that split). The scope section correctly lists
all `replicate-utils.R` helpers as unchanged. No new exports are added. No
scope creep detected.

### 4.2 — DAGJK helpers placement: `jackknife-dagjk-utils.R` vs `create_jackknife_weights.R` (no issue)

The File layout section is explicit: `create_jackknife_weights.R` contains the
public function only, with no internal helpers. DAGJK engine internals go to
`jackknife-dagjk-utils.R`. This is consistent with `surveywts-conventions.md`
rule 2 ("The exported function appears at the top of its file; helpers used only
by that function appear below it"), with the caveat that the DAGJK helpers will
be needed in a separate file because they are substantial. The spec treats them
as a family-utils file, which is acceptable.

### 4.3 — No behavior changes to `replicate-utils.R` (confirmed no issue)

The "Out" scope section and the "Unchanged helpers" table both confirm
`replicate-utils.R` is not modified. The spec does not list any behavior
changes to `.handle_repweights_overwrite()`, `.dispatch_calibration_replay()`,
etc. The only change is that `.handle_repweights_overwrite()` is now called with
`warning_class = "surveywts_warning_jackknife_repweights_overwritten"` instead of
the old `dagjk_*` class — but this is a call-site change, not a change to the
helper itself. Scope is clean.

---

## Lens 5 — Error/Warning Class Registry

### 5.1 — `surveywts_error_jackknife_replicates_invalid` inconsistency with registry (BLOCKING)

`error-messages.md` registers **both** `surveywts_error_replicates_invalid` (in
the "Replicate Weight Functions" section) and `surveywts_error_jackknife_replicates_invalid`
(registered for this merge). Both appear as active (non-retired) classes. The
DAGJK internals section says the renamed helper uses
`surveywts_error_jackknife_replicates_invalid`; the "Existing classes reused"
table says DAGJK uses `surveywts_error_replicates_invalid`.

The registry has registered a class (`surveywts_error_jackknife_replicates_invalid`)
that is ambiguously positioned relative to an existing class
(`surveywts_error_replicates_invalid`). The test-spec uses the new class. The
"Existing classes reused" table says the old class. This needs a single
authoritative answer:

- If the DAGJK path uses `surveywts_error_jackknife_replicates_invalid`: remove `surveywts_error_replicates_invalid` from the "Existing classes reused" table and from the Errors table.
- If the DAGJK path uses `surveywts_error_replicates_invalid`: remove `surveywts_error_jackknife_replicates_invalid` from the Error catalogue and from `error-messages.md`.

This is the same as Lens 2 finding 2.4.

### 5.2 — `surveywts_error_jackknife_degenerate_replicate` description in registry (REQUIRED)

`error-messages.md` registry entry reads:

> A DAGJK group replicate produced non-positive or NA weights, or the reduced
> dataset contains no NPS or reference units

The spec's DAGJK internals section updated this to "non-positive, non-finite, or NA."
The registry entry must be updated to match, or the registry entry governs and
the spec's internals section must be updated back. The correct technical answer
is "non-positive, non-finite, or NA" (Inf weights from `n_h / 0` should be
caught). Update the registry.

### 5.3 — All other error and warning classes present and correctly named (no issue)

Verified:
- `surveywts_error_not_survey_design` ✓
- `surveywts_error_already_replicate` ✓
- `surveywts_error_unsupported_class` ✓
- `surveywts_error_jackknife_type_nonprob_only` ✓
- `surveywts_error_jackknife_replicates_required` ✓
- `surveywts_error_replicates_not_whole_number` ✓
- `surveywts_error_jackknife_replicates_too_small` ✓
- `surveywts_error_jackknife_replicates_exceeds_n` ✓
- `surveywts_error_reference_sample_class` ✓
- `surveywts_error_jackknife_no_history` ✓
- `surveywts_error_jackknife_no_reference` ✓
- `surveywts_error_jackknife_degenerate_replicate` ✓ (description needs update — 5.2)
- `surveywts_error_jackknife_all_replicates_failed` ✓
- `surveywts_warning_jackknife_mse_overridden` ✓
- `surveywts_warning_jackknife_svrep_args_ignored` ✓
- `surveywts_warning_jackknife_repweights_overwritten` ✓
- `surveywts_warning_jackknife_small_groups` ✓
- `surveywts_warning_jackknife_replicates_failed` ✓
- `surveywts_warning_jackknife_negative_replicate_weights` ✓

All retired `dagjk_*` classes correctly appear as strikethrough in the registry.
The `surveywts_error_replicates_not_positive` class exists in `error-messages.md`
(for bootstrap, jackknife random-groups, etc.) but the spec correctly uses
`surveywts_error_jackknife_replicates_too_small` for the DAGJK minimum-value
check — these are intentionally distinct. No additional issue.

### 5.4 — `surveywts_error_replicates_not_positive` not used anywhere in spec (SUGGESTION)

The existing class `surveywts_error_replicates_not_positive` remains in the
registry ("Bootstrap, jackknife (random-groups), gen-boot, SDR | `replicates`
< 2"). After the merge, the `"random-groups"` type string is removed; the only
jackknife path that validates `replicates` minimum is now the DAGJK path, which
uses `surveywts_error_jackknife_replicates_too_small`. The `survey_taylor` grouped
path delegates `replicates` validation to `.validate_replicates_arg()`, which
throws `surveywts_error_replicates_not_positive`.

No action needed for this spec; the class is still valid for the
`survey_taylor` grouped path and for other methods. Note for future audit.

---

## Lens 6 — File Layout and Naming

### 6.1 — `jackknife-dagjk-utils.R` naming pattern (no issue)

`surveywts-conventions.md` §3 specifies family utils files as `{family}-utils.R`
(e.g., `replicate-utils.R`, `weight-utils.R`). The new file
`jackknife-dagjk-utils.R` uses a descriptive name that is not strictly a
`{family}-utils.R` name (the replicate family already has `replicate-utils.R`).
The spec acknowledges this — it describes the file as containing "DAGJK engine
internals only," not a general-purpose family utils file. The naming is
acceptable as a sub-family utils file scoped to DAGJK internals. The
conventions document does not prohibit more specific names.

### 6.2 — One exported function per file: `create_jackknife_weights.R` (no issue)

Post-merge, `create_jackknife_weights.R` exports only `create_jackknife_weights()`.
The DAGJK engine internals move to `jackknife-dagjk-utils.R`. This satisfies
conventions §3 rule 2.

### 6.3 — Test file rename: `test-nps-jackknife.R` (no issue)

The rename from `test-nps-group-jackknife.R` to `test-nps-jackknife.R` is
consistent with the function being merged. The file covers all DAGJK scenarios.
The `testing-surveywts.md` file mapping does not yet reflect this rename
(it still lists `tests/testthat/test-nps-group-jackknife.R`), but updating
that rules file is outside the scope of the spec — it is a documentation update
that should accompany the merge. No blocking issue, but it is worth flagging.

### 6.4 — `create_group_jackknife_weights.R` listed correctly as a deletion (no issue)

The spec explicitly lists the file under "Deletions" with a note: "No
deprecation wrapper." The `surveywts-conventions.md` file mapping will need to
be updated (currently lists `R/create_group_jackknife_weights.R` and
`create_group_jackknife_weights()` as active). Not a blocking concern for the
spec itself, but flagged as a follow-up item.

### 6.5 — `man/create_group_jackknife_weights.Rd` deletion (no issue)

Correctly handled via `devtools::document()` regeneration. No manual deletion
needed; `devtools::document()` removes stale `.Rd` files when an export is
removed from `NAMESPACE`.

---

## Summary

| Severity | Count |
|---|---|
| BLOCKING | 2 |
| REQUIRED | 7 |
| SUGGESTION | 1 |

### BLOCKING findings (must be resolved before Stage 4)

**B-1** (Lens 2, finding 2.4 / Lens 5, finding 5.1) — The spec contains an
irreconcilable contradiction about which error class is thrown for invalid
`replicates` on the DAGJK path. The Error catalogue says
`surveywts_error_jackknife_replicates_invalid`; the "Existing classes reused"
table says `surveywts_error_replicates_invalid`; and `error-messages.md`
registers both as active. The DAGJK internals section says the renamed helper
uses `surveywts_error_jackknife_replicates_invalid`. The test-spec tests for
`surveywts_error_jackknife_replicates_invalid`. A single authoritative choice
must be made and propagated to the Errors table, the Error catalogue, the
"Existing classes reused" table, `error-messages.md`, and the test-spec error
paths table.

**B-2** (Lens 2, finding 2.3) — The trigger description for
`surveywts_error_jackknife_degenerate_replicate` is "non-positive or NA" in the
Error catalogue and in `error-messages.md`, but "non-positive, non-finite, or
NA" in the DAGJK internals section. All three locations must agree. The correct
technical answer is "non-positive, non-finite, or NA."

### REQUIRED findings (quality problems that will cause failures)

**R-1** (Lens 1, finding 1.1 / Lens 2, finding 2.1) — The "Input validation
order" section header says "Steps 1–4 apply on every call. Steps 5–12 apply only
on the DAGJK path" but the footer note says "Steps 12–15 only apply on the DAGJK
path." Both are wrong. The correct statement is: "Steps 1–4 apply on every call.
Steps 5–15 apply only on the DAGJK path." Fix both sentences.

**R-2** (Lens 1, finding 1.2) — The JKn/JK1 backend contracts do not state that
the builder must not auto-detect `type` based on `data@variables$strata`. This is
a behavioral change from the current implementation that the builder could miss.
Add an explicit note.

**R-3** (Lens 1, finding 1.5 / Lens 2, finding 2.5) — The `replicates`
default is `NULL` in the merged signature, making it always-required for
`type = "grouped"`. The existing `create_group_jackknife_weights()` had
`groups = 50L`. The spec does not state this default removal is intentional.
A decision must be recorded: restore `replicates = 50L` as the default for
`survey_nonprob` paths, or confirm `NULL` is intentional and document it
explicitly.

**R-4** (Lens 3, finding 3.4) — `test_invariants(result)` is omitted from five
warning path tests that return `survey_nonprob`:
`surveywts_warning_jackknife_mse_overridden`,
`surveywts_warning_jackknife_repweights_overwritten`,
`surveywts_warning_jackknife_small_groups`,
`surveywts_warning_jackknife_replicates_failed`,
`surveywts_warning_jackknife_negative_replicate_weights`. Per
`testing-surveywts.md`, `test_invariants()` is required as the first assertion
whenever a `survey_nonprob` is constructed.

**R-5** (Lens 3, findings 3.8 / 3.9) — `test_invariants(result)` is omitted
from two DAGJK edge case tests that return `survey_nonprob`: `replicates = 2L`
(minimum) and `replicates = 50.0` (double coercion). Same rule as R-4.

**R-6** (Lens 5, finding 5.2) — `error-messages.md` registry entry for
`surveywts_error_jackknife_degenerate_replicate` still reads "non-positive or NA."
This must be updated to "non-positive, non-finite, or NA" to match the DAGJK
internals section. (Consequence of B-2; update the registry as part of resolving
B-2.)

**R-7** (Lens 3, finding 3.1) — The test-spec error paths table tests for
`surveywts_error_jackknife_replicates_invalid`. Until B-1 is resolved with a
definitive class name, the test-spec cannot be finalized. This is a consequence
of B-1.

### SUGGESTION

**S-1** (Lens 6, finding 6.3) — The `testing-surveywts.md` file mapping still
lists `tests/testthat/test-nps-group-jackknife.R`. Update the file mapping in
that rules document to `tests/testthat/test-nps-jackknife.R` as part of the
merge work.

---

**Verdict**: BLOCK

Two blocking contradictions (the replicates-invalid class name ambiguity and the
degenerate replicate trigger description mismatch) must be resolved in the spec
and in `error-messages.md` before implementation can proceed. Seven required
findings must also be addressed. None of the findings represent genuine
methodology disagreements — they are editorial and naming issues introduced
during the multi-stage revision process.

---

## Resolutions (Pass 1) — Stage 3r (2026-06-16)

Re-checked lenses: 1, 2, 3, 5. Files read: `spec-jackknife-merge.md`,
`test-spec-jackknife-merge.md`, `plans/error-messages.md`,
`.claude/rules/testing-surveywts.md`.

### B-1 — Error class name ambiguity (DAGJK path `replicates_invalid`)

**Fix applied:** The spec's Errors table now has two distinct rows: one for
`surveywts_error_jackknife_replicates_invalid` (DAGJK path, annotated as new
class renamed from `surveywts_error_dagjk_groups_invalid`) and one for
`surveywts_error_replicates_invalid` (`survey_taylor` grouped path, reusing the
existing class via `.validate_replicates_arg()`). The Error catalogue lists
`surveywts_error_jackknife_replicates_invalid` under new classes only. The
"Existing classes reused" table lists `surveywts_error_replicates_invalid` for
the `survey_taylor` grouped path only. The DAGJK internals section maps the old
`surveywts_error_dagjk_groups_invalid` to `surveywts_error_jackknife_replicates_invalid`
consistently. `error-messages.md` registers `surveywts_error_jackknife_replicates_invalid`
as a new active class and the test-spec tests for it on the DAGJK path. All
locations are now mutually consistent.

**Status: RESOLVED.**

### B-2 — Degenerate replicate trigger mismatch ("non-positive or NA" vs. "non-positive, non-finite, or NA")

**Fix applied:** The spec's Errors table trigger description for
`surveywts_error_jackknife_degenerate_replicate` now reads "non-positive,
non-finite, or NA weights". The Error catalogue entry reads the same.
`error-messages.md` line 151 now reads "non-positive, non-finite, or NA
weights". All three locations agree with the DAGJK internals section, which
was already correct.

**Status: RESOLVED.**

### R-1 — Validation step count note incorrect

**Fix applied:** The Input validation order section header now reads "Steps
1–4 apply on every call. Steps 5–15 apply only on the DAGJK path." The
former footer note "Steps 12–15 only apply on the DAGJK path" has been
removed and replaced with an ordering rationale note: "Note: Steps 12–13 are
ordered after reference resolution (step 10) to avoid spurious svrep-args
warnings on error paths." The contradiction between header and footer is gone.

**Status: RESOLVED.**

### R-2 — Auto-detection note absent from JKn/JK1 backend contracts

**Fix applied:** The JKn/JK1 backend contracts section now opens with an
explicit paragraph: "The builder must always use the user-supplied `type`
argument to select `'JKn'` or `'JK1'`. Do not auto-detect the jackknife
variant based on `data@variables$strata`. The current
`create_jackknife_weights()` auto-detects by checking whether `strata` is
`NULL`; that behavior is explicitly replaced by user-controlled `type`
dispatch in this merge."

**Status: RESOLVED.**

### R-3 — `replicates` default removal not stated as intentional

**Fix applied:** The `replicates` argument description now contains an explicit
"Intentional design:" paragraph: "unlike `create_group_jackknife_weights()`
which had `groups = 50L` as a default, `replicates` has no built-in default.
Callers must always supply a value when `type = 'grouped'`. This is documented
in `plans/jackknife-merge-decisions.md §Argument Decisions § replicates` and
is a deliberate breaking change." The referenced decisions file exists on disk.

**Status: RESOLVED.**

### R-4 — `test_invariants()` missing from five warning path tests

**Fix applied:** All six warning path rows in the test-spec now include
`test_invariants(result)` as the first named additional assertion. The five
that were missing it (`surveywts_warning_jackknife_mse_overridden`,
`surveywts_warning_jackknife_repweights_overwritten`,
`surveywts_warning_jackknife_small_groups`,
`surveywts_warning_jackknife_replicates_failed`,
`surveywts_warning_jackknife_negative_replicate_weights`) now explicitly state
`test_invariants(result)` in the Additional assertion column.

**Status: RESOLVED.**

### R-5 — `test_invariants()` missing from two DAGJK edge case rows

**Fix applied:** Both edge case rows that return `survey_nonprob` now include
`test_invariants(result)` as the first expected behavior: `replicates = 50.0`
reads "test_invariants(result); no error; result@variables$scale == 49/50"
and `replicates = 2L` reads "test_invariants(result); succeeds;
length(result@variables$repweights) == 2".

**Status: RESOLVED.**

### R-6 — `error-messages.md` degenerate replicate entry reads "non-positive or NA"

**Fix applied:** Consequence of B-2. `error-messages.md` line 151 now reads
"non-positive, non-finite, or NA weights" for
`surveywts_error_jackknife_degenerate_replicate`.

**Status: RESOLVED.**

### R-7 — Test-spec error class `surveywts_error_jackknife_replicates_invalid` was contingent on B-1

**Fix applied:** Consequence of B-1. The test-spec error paths table tests
`surveywts_error_jackknife_replicates_invalid` for the DAGJK path; this is now
the correct and unambiguous class for that path per the updated spec.

**Status: RESOLVED.**

### S-1 — `testing-surveywts.md` file mapping not updated

**Fix applied:** `.claude/rules/testing-surveywts.md` file mapping now lists
`R/jackknife-dagjk-utils.R → tests/testthat/test-nps-jackknife.R` (replacing
the old `test-nps-group-jackknife.R` entry). Verified by grep.

**Status: RESOLVED.**

---

### New issues introduced by fixes

None detected. The fixes are editorial (replacing class names, adding explicit
notes, adding `test_invariants()` calls). No new ambiguity, no new cross-reference
between spec and test-spec, no new error classes, no file surface changes.

One minor observation, not blocking: the R-3 fix cites
`plans/jackknife-merge-decisions.md §Argument Decisions § replicates` as the
authoritative decision record. That file exists on disk. The decisions file's
internal section structure was not read during this review pass and cannot be
verified; builder should confirm the cited section heading exists.

---

### Updated summary

| Severity | Original count | Resolved | Remaining |
|----------|---------------|----------|-----------|
| BLOCKING | 2 | 2 | 0 |
| REQUIRED | 7 | 7 | 0 |
| SUGGESTION | 1 | 1 | 0 |

---

**Updated verdict: PASS**

All 2 blocking and 7 required findings are resolved. The spec, test-spec, and
`error-messages.md` are internally consistent across all re-checked lenses.
Implementation may proceed.
