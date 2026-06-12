## Spec Review: calibrate-unit-scale — Pass 1 (2026-06-09)

### New Issues

#### Section: Scope / Architecture (general)

No new issues found.

---

#### Section: `.calibrate_nr_engine()` contract

No new issues found. Pseudocode is complete; all three fix locations (D1, D2,
D3) are unambiguous; `q_weights` resolution at entry is correctly specified;
return shape and error table unchanged.

---

#### Section: `.make_calfun_logit()` body fix

No new issues found. The scalar-compat guard `if (length(L) > 1L) L[idx] else L`
is correct in both branches. The `dF` function is element-wise for vector
L/U/A. The final `pmax(L, pmin(U, f))` is correct. The builder has enough
information to implement this exactly.

---

#### Section: `calibrate_linear()` call site wiring

No new issues found. The five call sites are individually described; the D6
"before" and "after" are shown side-by-side; the prohibition on
`scaled_weights`/`scaled_population` variables is explicit.

---

#### Section: `calibrate_logit()` call site wiring

No new issues found. The four call sites follow the same structure as the
linear section. The precondition check placement (before building the calfun,
in both full-sample and replicate branches) is unambiguous.

---

#### Section: Error and warning classes (spec)

**Issue 1: `plans/error-messages.md` not updated for new logit bounds trigger**

Severity: REQUIRED
Violates workflow requirement in CLAUDE.md: "When adding a new error or
warning: 1. Add a row to `plans/error-messages.md` first."

The spec adds a new trigger condition for `surveywts_error_bounds_invalid_calibration`
in `calibrate_logit()`:

> "thrown when any base weight `d_k` is not strictly within `(L_abs, U_abs)`,
> making the per-unit logit calfun ill-defined"

The current `plans/error-messages.md` row for `surveywts_error_bounds_invalid_calibration`
describes only the `.validate_bounds()` triggers (non-numeric, wrong length,
NA, multiplicative out-of-range, absolute non-positive, L >= U). The new
per-unit base-weight trigger is absent.

The spec text is clear about the new condition. The issue is that neither
the spec Architecture section nor the write-surface list mentions updating
`plans/error-messages.md`. The error-class-auditor agent checks that all
`cli_abort()` calls use a class present in that table with an accurate
condition description.

Options:
- **[A]** Add a sentence in the spec Architecture section: "Update
  `plans/error-messages.md`: extend the `surveywts_error_bounds_invalid_calibration`
  row's Condition column to include the new `calibrate_logit()` per-unit
  absolute-bounds trigger." — Effort: low, Risk: low, Impact: builder
  remembers to update the canonical table, auditor passes CI.
- **[B]** Add `plans/error-messages.md` to the write surface list explicitly.
  — Effort: low, Risk: low, Impact: same as A but more explicit.
- **[C] Do nothing** — The builder may or may not update `error-messages.md`;
  if they don't, the error-class-auditor CI step will flag it.

**Recommendation: A** — One-sentence addition to the Architecture section;
prevents CI failure and keeps the canonical table accurate.

---

#### Section: Error message template (spec)

**Issue 2: No message template for new logit precondition check**

Severity: SUGGESTION
Violates code-style.md §3 spirit: error messages should follow `"x"` + `"i"` +
optional `"v"` structure with specific bullet content.

The spec says to throw `surveywts_error_bounds_invalid_calibration` when
`any(weights_vec <= abs_L | weights_vec >= abs_U)`, but does not provide
message text. The builder will invent a message. The test-spec (HGE-4 and
HGE-5) uses `expect_snapshot(error = TRUE)`, so whatever the builder writes
becomes the canonical snapshot.

This is fine mechanically — the snapshot captures the first run. But without
a template, the message might not distinguish which direction the bound is
violated (L-side vs U-side), making it less actionable for users.

Options:
- **[A]** Add an `"x"`, `"i"`, `"v"` template to the Architecture section,
  distinguishing the L_abs-violation case and the U_abs-violation case.
  — Effort: low, Risk: low, Impact: consistent message quality.
- **[B]** Keep spec as-is; the builder follows `code-style.md` conventions
  and the snapshot locks in whatever they write. — Effort: none.
- **[C] Do nothing** — Same as B.

**Recommendation: B** — The builder follows existing convention; the snapshot
test provides quality control. Only worth specifying if message specificity
matters for user experience.

---

#### Section: Behavioral change table (D6)

No new issues found. The before/after table is clear. The "breaking change"
designation is correctly applied.

**Issue 3: No user-facing signal for breaking change in absolute-bounds output**

Severity: SUGGESTION
Potentially violates api-coherence expectations (Lens 6): a silent behavioral
change for existing callers.

Users with code that calls `calibrate_linear(bounds_scale = "absolute")` or
`calibrate_logit(bounds_scale = "absolute")` with unequal base weights will get
different results after this fix. The spec documents this as a bug fix, not a
new feature. Since the package is `0.1.0.9000` (pre-1.0) and the old behavior
was incorrect, no warning is required.

The spec is correct to proceed without a warning. Flagging only as SUGGESTION
since a `cli_message()` or NEWS.md entry at release time would help users
diagnose unexpected result changes.

Options:
- **[A]** Add a `cli_inform()` in the absolute-bounds path (or a NEWS.md
  note) indicating the D6 fix was applied. — Effort: low.
- **[B]** Note in NEWS.md (already the release workflow's responsibility).
  — Effort: zero in this PR.
- **[C] Do nothing** — Pre-1.0 breaking change; no warning required.

**Recommendation: C** — Pre-1.0 package; the correct behavior is unambiguously
better; NEWS.md covers it at release time.

---

#### Section: Quality gates (spec) — DRY (Lens 1)

**Issue 4: D6 per-unit bounds computation will appear in 4 call sites without a shared helper**

Severity: SUGGESTION
Violates engineering-preferences.md §1: "Repeated patterns in 2+ functions →
extract a shared internal helper."

The computation `L_vec = abs_L / weights_vec; U_vec = abs_U / weights_vec` will
appear in:
1. `calibrate_linear()` full-sample absolute-bounds path
2. `calibrate_linear()` replicate-loop absolute-bounds path
3. `calibrate_logit()` full-sample absolute-bounds path
4. `calibrate_logit()` replicate-loop absolute-bounds path

This is 4 repetitions of a 2-line pattern. The spec says "No new exported
functions" but doesn't prohibit new private helpers. However, a helper for
2 lines would be over-engineered (violates engineering-preferences.md §3).

Options:
- **[A]** Add a 2-line private helper `.make_per_unit_bounds(abs_L, abs_U, wt)` 
  in `calibrate-utils.R`. — Effort: very low, but debatable value for 2 lines.
- **[B]** Leave inline in all 4 call sites as specified. — Effort: none.
- **[C] Do nothing** — Same as B; 2 lines does not justify abstraction.

**Recommendation: B/C** — Two lines doesn't warrant a helper. Leave inline.

---

#### Section: Test-spec — Happy paths (Lens 2)

**Issue 5: `test_invariants()` not mandated as first assertion in most happy-path blocks**

Severity: REQUIRED
Violates testing-surveywts.md rule: "Every `test_that()` block that creates a
`weighted_df` or `survey_nonprob` object must call `test_invariants(obj)` as its
**first** assertion."

The test-spec explicitly specifies `test_invariants(result)` only in HL-7 ("HL-7
| `weighted_df` output has correct structure") and HG-7 (analogously), and the
replicate-loop RL-1/RL-3 tests ("test_invariants(result) is the first assertion
in every replicate-loop test"). But HL-1 through HL-6, HL-8 through HL-11, HG-1
through HG-6, HG-8 through HG-10 all produce `weighted_df` objects and do not
mention `test_invariants()` as first assertion.

The test-spec is meant to be "independently sufficient" for the tester (who does
not see spec-calibrate-unit-scale.md). Without explicit guidance in the test-spec
for each block, the tester may write numeric-comparison-only tests.

Options:
- **[A]** Add a general rule at the top of the Per-function test plan section:
  "Every `test_that()` block that produces a `weighted_df` must call
  `test_invariants(result)` as its first assertion before any numeric
  comparisons." Then remove HL-7 and HG-7 as separate rows (they are covered
  by this rule). — Effort: low, Impact: tester writes structurally correct tests.
- **[B]** Add `test_invariants(result)` as a column to the happy-path tables,
  with `✓` in every row. — Effort: low.
- **[C] Do nothing** — The tester has access to testing-surveywts.md and should
  apply the rule independently. Risk: some blocks may miss the structural check.

**Recommendation: A** — One-sentence rule at the top of the test plan,
replacing the individual HL-7/HG-7 rows. Unambiguous for the tester.

---

#### Section: Test-spec — Error paths (Lens 2)

**Issue 6: HLE-5 dual pattern not explicitly specified**

Severity: REQUIRED
Violates testing-surveywts.md: all Layer 3 (constructor/function) errors use
the dual pattern: `expect_error(class = ...)` + `expect_snapshot(error = TRUE)`.

The test-spec for HLE-5 says:
> "verify error class still correct"

It does not specify whether this is class-only (Layer 1 pattern) or the dual
pattern (Layer 3 pattern). `surveywts_error_calibration_not_converged` is
thrown by `.calibrate_nr_engine()` — which is internal — but the triggering
call is through the public `calibrate_linear()` API, making it a Layer 3 error.

The dual pattern is also missing from:
- HGE-1 through HGE-3: these share the same "pre-existing; verify still correct"
  framing but don't say dual. (Though the calibrate_logit() section says "All
  use the dual pattern: `expect_error(class = ...)` + `expect_snapshot(error = TRUE)`"
  only for HGE-4 and HGE-5.)

Actually HLE-1 through HLE-4 do say "dual pattern" via the section header:
"All use the dual pattern: `expect_error(class = ...)` + `expect_snapshot(error = TRUE)`."
But HLE-5 appears outside this scope, with a different description.

Options:
- **[A]** Explicitly add "dual pattern: `expect_error(class = "surveywts_error_calibration_not_converged")` +
  `expect_snapshot(error = TRUE)`" to HLE-5. Same for HGE-1, HGE-2, HGE-3.
  — Effort: low, Impact: tester writes correct dual pattern.
- **[B]** Add a general statement: "All error paths use the dual pattern unless
  noted otherwise." — Effort: minimal.
- **[C] Do nothing** — Testing-surveywts.md requires dual pattern for Layer 3;
  tester should apply it. Risk: HLE-5 snapshot may be omitted.

**Recommendation: A** — Explicitly call out dual pattern per error row;
avoids ambiguity since HLE-5's description differs from HLE-1 through HLE-4.

---

#### Section: Test-spec — Edge cases (Lens 4)

**Issue 7: EC-2 behavioral description is factually incorrect and produces an untestable dual-outcome expectation**

Severity: REQUIRED
Violates testing-standards.md: "Do not use... `tryCatch()` in tests." The
"either converges or throws error" framing requires `tryCatch()` to implement.

EC-2 states:
> "Calibration may diverge (heavily penalizes deviations) or produce
> `surveywts_error_calibration_not_converged`; test that either converges
> or throws the expected error class — no crash"

This is incorrect in two ways:

1. **Wrong behavioral intuition**: `unit_scale = rep(1e-6, n)` sets q_k = 1e-6.
   In Deville-Sarndal (1992) eq. 2.2, `G_k = (1/q_k) * g(w/d)`. With
   q_k = 1e-6, the penalty coefficient is 1/q_k = 1e6 (very strict, not loose).
   The description "heavily penalizes deviations" is actually correct
   directionally, but the expected outcome (divergence / non-convergence) is
   wrong. For the NR iteration: `delta_lambda = solve(X'diag(d*q)X, misfit)`,
   the Jacobian scales by q_k but so does `u_vec = q_k * X * lambda`, so the
   net effect cancels — the iteration converges to the same weights as q_k = 1
   for any uniform q_k. Non-convergence is not expected.

2. **Untestable**: "test that either converges or throws the expected error
   class" cannot be written without prohibited `tryCatch()`. A test must have a
   single deterministic expectation.

The correct expected behavior for EC-2 (`unit_scale = rep(1e-6, n)`, uniform):
calibration converges; the calibration constraint holds; final weights are
numerically close to those from `unit_scale = NULL` (for the unbounded linear
case, they are identical due to cancellation in the one-step solution).

Options:
- **[A]** Replace EC-2 with a deterministic test: `unit_scale = rep(1e-6, n)`
  converges; `test_invariants(result)` passes; calibration constraint holds
  within tolerance. Document why (uniform q_k cancels in NR update). Also
  add a note: "for uniform q_k, result is numerically identical to q_k = 1."
  — Effort: low, Impact: tester writes a correct, runnable test.
- **[B]** Replace with a test for a non-uniform extreme: one unit with q_k = 1e-8
  and all others q_k = 1, with a near-singular small dataset, to make the
  Jacobian ill-conditioned. This tests the edge case more meaningfully.
  — Effort: medium.
- **[C] Do nothing** — Tester will write a fragile test using `tryCatch()`;
  test may pass vacuously on convergence.

**Recommendation: A** — Fix the behavioral description and make the expectation
deterministic. The uniform-q_k case is now a clean regression test.

---

#### Section: Test-spec — Oracle construction (Lens 2)

**Issue 8: HL-4 oracle construction references `survey::make.calfun()` — uncertain API**

Severity: SUGGESTION
Robustness concern: the test-spec note says "If `survey::make.calfun("truncated", ...)`
is not available in the installed version, skip HL-4" but the note in the
oracle setup table already uses
`survey::make.calfun(survey::make.calfun("truncated", list(bounds=c(0.3,3))))` (HL-4 note)
which is likely a copy-paste error (double-wrapping). The canonical form of the
oracle call in HL-4 is:
```r
calfun = survey::make.calfun("truncated", list(bounds = c(0.3, 3)))
```
The note should be:
```r
survey::calibrate(..., calfun = survey::make.calfun("truncated", list(bounds = c(0.3, 3))), variance = 1/q_unequal)
```
The double-wrapped form in the note is confusing but doesn't affect the test if
the tester reads both the table and the note.

Also: `survey::make.calfun("truncated")` takes a list as second argument but the
parameter name and structure may differ across versions of the `survey` package
(4.1 vs 4.2). A version check using `packageVersion("survey") >= "4.1"` (already
suggested in the test-spec for `bounds.const = TRUE`) should be noted here too.

Options:
- **[A]** Fix the double-wrapped note; add `packageVersion("survey") >= "4.1"`
  skip condition to HL-4 note. — Effort: low, Impact: oracle is more robust.
- **[B]** Remove HL-4 oracle note's parenthetical double-wrap; keep the rest.
  — Effort: minimal.
- **[C] Do nothing** — Tester will work it out from context.

**Recommendation: A** — Fix the copy-paste error and add a version guard note.
The double-wrapped form will confuse any reader.

---

### Summary (Pass 1)

| Severity | Count |
|---|---|
| BLOCKING | 0 |
| REQUIRED | 4 |
| SUGGESTION | 4 |

**Total issues:** 8

**Overall assessment:** The spec is well-specified and nearly implementation-ready.
All four REQUIRED issues are in the test-spec, not the implementation spec — the
behavioral contracts, algorithm pseudocode, and architecture are complete and
unambiguous. The blocking concern would be EC-2's untestable dual-outcome
expectation (tester would have to use prohibited `tryCatch()`); issues 5 and 6
are structural gaps that make the test-spec insufficiently independent. Issue 1
(`error-messages.md`) is a workflow step the builder must not miss. After
addressing the four REQUIRED issues (all small edits to the test-spec), the
spec can proceed directly to implementation.

---

## Spec Review: calibrate-unit-scale — Pass 2 (2026-06-09)

### Prior Issues (Pass 1)

| # | Title | Status |
|---|---|---|
| 1 | `plans/error-messages.md` not updated for new logit bounds trigger | ✅ Resolved |
| 2 | No message template for new logit precondition check | ⚠️ Still open (SUGGESTION; recommendation was B — do nothing) |
| 3 | No user-facing signal for breaking change in absolute-bounds output | ⚠️ Still open (SUGGESTION; recommendation was C — do nothing) |
| 4 | D6 per-unit bounds computation in 4 call sites without a shared helper | ⚠️ Still open (SUGGESTION; recommendation was B/C — leave inline) |
| 5 | `test_invariants()` not mandated as first assertion in most happy-path blocks | ✅ Resolved |
| 6 | HLE-5 dual pattern not explicitly specified | ✅ Resolved |
| 7 | EC-2 behavioral description factually incorrect and produces untestable dual-outcome expectation | ✅ Resolved |
| 8 | HL-4 oracle construction double-wrapped and missing version guard | ✅ Resolved |

### New Issues

#### Section: Test-spec — Edge cases (Lens 4 / Lens 2)

**Issue 9: EC-4 is still a dual-outcome test — same defect as the original EC-2**

Severity: REQUIRED
Violates testing-standards.md §4: "Do not use `withCallingHandlers()` or
`tryCatch()` in tests." and "A test must have a single deterministic expectation."

EC-4 states:
> "Does not produce silent wrong result; either converges correctly or throws
> `surveywts_error_calibration_singular_system`"

This is structurally identical to the original EC-2 before it was fixed in Pass
1r. The "either A or B" framing requires `tryCatch()` to implement, which is
prohibited. Issue 7 was fixed for EC-2 but the same problem remains in EC-4.

Analysis of what actually happens: for a 20-row inline data frame with one unit
at `q_k = 1e8` and the rest at `q_k = 1`, the Jacobian column for that unit is
heavily weighted — but whether this causes `solve()` to fail depends on whether
the calibration variables are effectively rank-deficient once that unit dominates.
For a typical 2-variable calibration problem with 20 rows, the Jacobian remains
full rank (one heavily-weighted unit cannot make a full-rank matrix singular in
the mathematical sense, though it may affect numerical stability). In practice,
`solve()` will almost certainly succeed, and the test would exercise "converges
correctly." The "or throws error" branch is never reached reliably.

Fix: determine the deterministic expected outcome for the specific inline dataset
(it converges), then write a deterministic test. If the goal is to test
near-singular behavior, construct a dataset where singular behavior is guaranteed
(e.g., two identical calibration variable columns).

Options:
- **[A]** Replace EC-4 with a deterministic convergence test: 20-row inline df
  with one extreme `q_k = 1e8`, verify it converges and `test_invariants(result)`
  passes; separately note the singular-system error class is tested indirectly
  via the existing engine. — Effort: low, Impact: tester writes a runnable test.
- **[B]** Construct a guaranteed-singular dataset: `q_weights` that make the
  Jacobian rank-deficient (e.g., `q_k = c(1e8, rep(0, n-1))` — but wait,
  q_weights must be positive per spec, so 0 isn't valid). Alternative: use
  perfectly collinear calibration variables with this dataset. — Effort: medium.
- **[C] Do nothing** — Tester writes a fragile test using `tryCatch()`, which
  either violates the standard or passes vacuously.

**Recommendation: A** — Deterministic convergence test. The singular-system
error class (`surveywts_error_calibration_singular_system`) is already exercised
by the engine's own behavior; no additional edge-case test for it is required
here unless singular behavior is reliably constructible.

---

#### Section: Test-spec — HL-12 (Lens 3 / Contract Completeness)

**Issue 10: HL-12 references non-existent history field path `$parameters$n_iterations`**

Severity: REQUIRED
The test-spec note for HL-12 says:
> "Access via: `attr(result, "weighting_history")[[1]]$parameters$n_iterations`"

Confirmed via `R/utils.R:565–591` — `.make_history_entry()` builds the
following structure:

```r
list(
  step        = ...,
  operation   = ...,
  weight_col  = ...,
  timestamp   = ...,
  call        = ...,
  parameters  = parameters,   # ← the list passed by the caller
  weight_stats = ...,
  convergence = convergence,  # ← separate field; list(converged, iterations)
  capping     = ...,
  package_version = ...
)
```

In `calibrate_linear.R`, `parameters` is:
```r
parameters = list(
  variables, targets, bounds, bounds_scale, unit_scale,
  type, control, targets_from_reference, reference_design
)
```

`n_iterations` is NOT in `parameters`. It lives at `$convergence$iterations`
(passed as `convergence = engine_result$convergence = list(converged, iterations)`).

The path `$parameters$n_iterations` returns `NULL`. A test written as
`expect_equal(attr(result, "weighting_history")[[1]]$parameters$n_iterations, 1L)`
will call `expect_equal(NULL, 1L)` — this fails with a `waldo` comparison error,
not a silent pass. The tester will be blocked and have to debug the path rather
than run the intended correctness test.

Options:
- **[A]** Fix the note to use the correct path:
  `attr(result, "weighting_history")[[1]]$convergence$iterations` — Effort: trivial.
- **[B]** If the intent was to access iterations from `parameters$control$maxit`
  (i.e., checking the maximum was 50, not the actual count), rewrite HL-12 to
  access the correct field and clarify the test intent. — Effort: low.
- **[C] Do nothing** — Tester debugs the path; HL-12 is eventually rewritten to
  the correct path. Risk: tester time wasted.

**Recommendation: A** — One-word fix: replace `$parameters$n_iterations` with
`$convergence$iterations`.

---

#### Section: Test-spec — Logit replicate precondition coverage (Lens 2)

**Issue 11: No test for `surveywts_error_bounds_invalid_calibration` firing inside the logit replicate loop**

Severity: SUGGESTION
Coverage gap: the spec adds a precondition check in "both full-sample and
replicate-loop branches" of `calibrate_logit()` when `bounds_scale = "absolute"`.

The full-sample path is tested by HGE-4 and HGE-5. The replicate-loop path is
not tested. When the precondition check fires inside the replicate `tryCatch`,
it is caught and re-emitted as `surveywts_warning_replicate_calibration_failed`
(with the original error message in the `$i` context bullet). This is a
distinct code path from the full-sample error.

Options:
- **[A]** Add an edge-case test: construct a `survey_replicate` input where one
  replicate weight column contains a value below `L_abs`; call
  `calibrate_logit(bounds_scale = "absolute")`; verify
  `surveywts_warning_replicate_calibration_failed` is emitted and that
  replicate column is unchanged. — Effort: medium.
- **[B]** Leave the replicate-loop path untested; it is covered by the generic
  replicate-failure machinery (already tested by other replicate tests).
  — Effort: none.
- **[C] Do nothing** — Same as B.

**Recommendation: B** — The replicate error-to-warning conversion path is
already exercised by general replicate calibration failure tests; the new
precondition check fires inside the same `tryCatch` structure. The marginal
coverage value is low relative to test setup cost for a `survey_replicate` edge
case.

---

### Summary (Pass 2)

| Severity | Count |
|---|---|
| BLOCKING | 0 |
| REQUIRED | 2 |
| SUGGESTION | 1 |

**Total new issues:** 3

**Overall assessment:** Pass 1 resolved 4 of 8 issues (the 4 REQUIRED ones). The
3 still-open items from Pass 1 are all SUGGESTIONs with "do nothing"
recommendations, correctly left unresolved. Pass 2 finds 2 new REQUIRED issues,
both in the test-spec: EC-4 repeats the dual-outcome pattern that was fixed for
EC-2 in Pass 1r, and HL-12 references a wrong field path (`$parameters$n_iterations`
instead of `$convergence$iterations`). Both are small, targeted fixes. After
resolving these 2 REQUIRED issues, the spec and test-spec are SPEC_READY.

---

## Spec Review: calibrate-unit-scale — Pass 2r (2026-06-09)

### Resolutions

| # | Issue | Resolution |
|---|-------|------------|
| 9 | EC-4 dual-outcome "either converges or throws" (untestable) | ✅ Resolved — EC-4 replaced with deterministic convergence test: converges, `test_invariants` passes, constraint holds within `1e-8`; note explains why single dominant q_k does not cause singularity |
| 10 | HL-12 wrong history path `$parameters$n_iterations` | ✅ Resolved — both occurrences (table row and note) corrected to `$convergence$iterations` |

### Open items (SUGGESTIONs, "do nothing" recommended)

| # | Issue | Status |
|---|-------|--------|
| 2 | No message template for new logit precondition check | Left open; builder follows code-style.md; snapshot locks in message |
| 3 | No user-facing signal for breaking change in absolute-bounds output | Left open; pre-1.0; NEWS.md covers at release |
| 4 | D6 per-unit bounds in 4 call sites without shared helper | Left open; 2 lines does not warrant abstraction |
| 11 | No test for `bounds_invalid_calibration` firing inside logit replicate loop | Left open; covered by generic replicate-failure machinery |

### Verdict: **PASS**

All REQUIRED issues resolved. Spec and test-spec are SPEC_READY.
