## Spec Review: calibration-framework — Pass 1 (2026-06-08)

_Pass 1: No prior review file exists._

---

### New Issues

#### Section: calibrate() — Function Contract

**Issue 1: `calibrate()` method argument description misattributes `algorithm` and `cap` to the wrong dispatched functions**
Severity: BLOCKING
Violates `engineering-preferences.md §5` — explicit over clever; spec must be factually correct.

The `method` argument description states:
> "e.g., `algorithm`, `cap`, `bounds` for `calibrate_linear()`/`calibrate_logit()`"

`algorithm` and `cap` are arguments of `calibrate_rake()`, not `calibrate_linear()` or `calibrate_logit()`. `bounds` is the correct method-specific arg for linear and logit. A builder reading this will pass `algorithm` and `cap` through `...` when dispatching to linear/logit and may add corresponding handling there, producing wrong architecture.

The correct statement: "e.g., `algorithm`, `cap` for `calibrate_rake()`; `bounds` for `calibrate_linear()` and `calibrate_logit()`."

Options:
- **[A] Correct the parenthetical** in the `method` argument description to accurately attribute `algorithm`/`cap` to `calibrate_rake()` and `bounds` to `calibrate_linear()`/`calibrate_logit()`. Effort: minimal, Risk: none, Impact: builder cannot be misled about which function receives which argument.
- **[B] Do nothing** — Builder might deduce from the function signatures. But this is a factual error in a spec that is supposed to be independently sufficient.

**Recommendation: [A]** — One-word fix; the error is unambiguous.

---

#### Section: calibrate_rake() — Function Contract

**Issue 2: `cap` argument lacks a validation contract for non-positive values**
Severity: REQUIRED
Violates `engineering-preferences.md §4` — handle more edge cases, not fewer.

The spec describes `cap` as "Numeric or `NULL` (default)." It defines `surveywts_error_cap_not_supported_nr` for `cap` non-NULL with `algorithm = "nr"`, but says nothing about what happens when `cap ≤ 0` (e.g., `cap = 0` or `cap = -2`) with `algorithm = "classic_ipf"`.

With `cap = 0`, the per-step constraint is `cap * mean(w) = 0`, capping all weights to 0. This produces zero weights that then violate `surveywts_error_weights_nonpositive` mid-computation — but the user sees a weights error, not a cap error, with no indication the source was invalid `cap`. With `cap = -1`, behavior is undefined.

The spec must state: "`cap` must be a positive finite numeric scalar or `NULL`. Non-positive, non-finite, or non-numeric values trigger `surveywts_error_cap_not_positive`" (or similar), and add this class to `plans/error-messages.md`.

Options:
- **[A] Add input validation for `cap`** — must be `NULL` or a positive finite scalar. New error class `surveywts_error_cap_not_positive`. Effort: low, Risk: none, Impact: user gets actionable error at the argument, not a confusing weights error mid-computation.
- **[B] Add a note that `cap > 0` is assumed** without formal error handling. Users who pass `cap = 0` get undefined behavior.
- **[C] Do nothing** — `cap ≤ 0` is an implausible input; no real user would pass it.

**Recommendation: [A]** — Defensive validation is cheap; confusing downstream errors are expensive to debug.

---

**Issue 3: `variable_select` control parameter options are undocumented**
Severity: REQUIRED
Violates `engineering-preferences.md §5` — explicit over clever; the spec must define behavior, not just enumerate option names.

The `algorithm = "classic_ipf"` control parameters list:
```
variable_select = "total": chi-square aggregation method ("total", "max", or "average")
```

The spec names three options but does not define what any of them does. A builder who has not read the `anesrake` source cannot implement this parameter. Specifically: when comparing variables to select their calibration order, does `"total"` aggregate chi-square across all cells of a variable by summing, `"max"` by taking the worst cell, and `"average"` by averaging? The spec must define the aggregation rule for each option.

Options:
- **[A] Add a one-sentence definition of each option** to the `control` argument description: `"total"` — sum of chi-square contributions across all cells for that variable; `"max"` — max cell chi-square; `"average"` — mean cell chi-square. Effort: minimal, Impact: builder can implement without reading anesrake source.
- **[B] Add a cross-reference to the `anesrake` package documentation.** Effort: minimal but violates the independently-sufficient spec requirement.
- **[C] Do nothing** — The builder will read anesrake source.

**Recommendation: [A]** — The spec must be independently sufficient.

---

#### Section: poststratify() — Function Contract

**Issue 4: `surveywts_error_empty_stratum` trigger condition is imprecise**
Severity: REQUIRED
Violates `engineering-preferences.md §4` — "The implementation should handle edge cases gracefully" is not a spec.

The spec error table says:
> `surveywts_error_empty_stratum` | "A stratum cell has zero weighted count (defensive; primarily for replicates)"

"Zero weighted count" is ambiguous — it could mean (a) `sum(weights) == 0` for all units in a cell, or (b) `n_units == 0` for a cell (but that's `surveywts_error_population_cell_missing`). The "(defensive; primarily for replicates)" note implies this fires only for replicate paths. But the full-sample path cannot produce zero weighted count because `surveywts_error_weights_nonpositive` prevents zero design weights.

The spec must state explicitly: "Fires when `sum(replicate_weight_column[cell])` equals 0 for any cell in a replicate weight column. The full-sample path cannot trigger this error because design weights are validated to be strictly positive before reaching the cell computation."

Options:
- **[A] Replace the imprecise trigger with the explicit formulation** above. Effort: one sentence, Risk: none, Impact: builder knows exactly when to throw this error, and tester can write a reproducible trigger.
- **[B] Do nothing** — The builder will deduce the intent from "defensive."

**Recommendation: [A]** — An imprecise trigger means the builder guesses; a wrong guess produces either silent failures or spurious errors.

---

#### Section: test-spec — calibrate_logit()

**Issue 5: Missing test for `bounds = c(NA, 2)` triggering `surveywts_error_bounds_invalid_calibration`**
Severity: REQUIRED
Violates `testing-standards.md §3` — every row in the error table covered by a test.

The `calibrate_logit()` spec error table states `surveywts_error_bounds_invalid_calibration` fires when "either value is `NA` or non-finite." The `calibrate_linear()` test-spec covers this via E20 (`bounds = c(NA, 2)`). The `calibrate_logit()` test-spec only covers L≥1 (E17), U≤1 (E18), and length≠2 (E19). The NA/non-finite trigger is untested for `calibrate_logit()`, creating asymmetric coverage for a shared validation helper (`.validate_bounds()`).

Options:
- **[A] Add E20 to `calibrate_logit()` test-spec**: `bounds = c(NA, 2)` → `surveywts_error_bounds_invalid_calibration`. Pattern: `expect_error(class=...)` + snapshot. Effort: trivial.
- **[B] Do nothing** — Shared helper; covered indirectly by calibrate_linear E20.

**Recommendation: [A]** — Each function needs independent error path coverage; shared helper doesn't mean shared tests.

---

#### Section: test-spec — poststratify()

**Issue 6: Missing error path test for `surveywts_error_weights_not_numeric`**
Severity: REQUIRED
Violates `testing-standards.md §3` — every row in the error table covered.

The `poststratify()` spec error table includes `surveywts_error_weights_not_numeric` ("Weight column is not numeric"). The test-spec error paths include E9 (not found), E10 (nonpositive), E11 (NA), but do not include a test for `surveywts_error_weights_not_numeric`. This error class is tested for `calibrate_linear()` (E7) but is absent from the `poststratify()` test plan.

Options:
- **[A] Add an error path test for `surveywts_error_weights_not_numeric`** in the `poststratify()` error paths section. Trigger: weight column is `character`. Pattern: `expect_error(class=...)` + snapshot. Effort: trivial.
- **[B] Do nothing** — Shared validation; covered by calibrate_linear E7.

**Recommendation: [A]** — Independent test coverage per function is the standard.

---

**Issue 7: Missing error path test for `surveywts_error_empty_stratum`**
Severity: REQUIRED
Violates `testing-standards.md §3` — every row in the error table covered.

The `poststratify()` spec error table includes `surveywts_error_empty_stratum` but the test-spec has no error path for it. The trigger (once Issue 4 is resolved to mean "replicate column with zero-sum cell") requires a `survey_replicate` input where one replicate weight column has all-zero weights for one stratum cell.

Options:
- **[A] Add an error path test for `surveywts_error_empty_stratum`** in the `poststratify()` test plan. Use a `survey_replicate` input with a manually zeroed replicate column for one cell. Pattern: `expect_warning(class = "surveywts_warning_replicate_calibration_failed")` (if defensive, the error is caught per-replicate and converted to a warning) — or `expect_error(class=...)` if it bubbles up. _Note: the spec needs to first resolve whether this fires as an error or is caught as a replicate failure warning (Issue 4's resolution will clarify)._
- **[B] Do nothing** — Defensive path; unlikely in practice.

**Recommendation: [A]** — Error table row without a test is a coverage gap.

---

#### Section: test-spec — calibrate_linear()

**Issue 8: No test verifies `@calibration$method` field value for truncated-linear vs plain linear**
Severity: REQUIRED
Violates `testing-standards.md §2` — core behavioral distinction not covered.

The spec returns section states: "`@calibration` slot fields: `method = "linear"` or `"truncated"`" depending on whether `bounds` is `NULL` or not. This is a testable behavioral property distinguishing the two code paths. No test in the `calibrate_linear()` test plan asserts:
- Plain linear → `obj@calibration$method == "linear"`
- Truncated linear → `obj@calibration$method == "truncated"`

H6 (truncated linear happy path) only checks that g-weights are in `[0.3, 3]` and match the oracle. It does not verify the method field.

Options:
- **[A] Add assertions for `@calibration$method`** to H1 (plain → `"linear"`) and H6 (truncated → `"truncated"`). Effort: two lines added to existing test blocks.
- **[B] Do nothing** — The method field distinction is derived from the bounds path; testing bounds behavior implicitly tests it.

**Recommendation: [A]** — The spec defines this as a distinct field value; it should be asserted explicitly.

---

#### Section: test-spec — Cross-function

**Issue 9: CX4 "Difference" metric is undefined**
Severity: REQUIRED
Violates `testing-standards.md §1` — one observable behavior per block; the block must be implementable.

The cross-function test plan has:
> **CX4** | `calibrate_linear()` and `calibrate_logit()` converge to similar weights for well-conditioned data | Difference < `1e-3` (not a strict tolerance; asymptotic equivalence test)

"Difference" is undefined. Is it:
- Max absolute difference across all weights: `max(abs(w_linear - w_logit))`?
- Max relative difference: `max(abs(w_linear - w_logit) / w_linear)`?
- Sum of absolute differences?
- Something on the proportion scale?

Without a defined metric, a tester cannot write this test. A `1e-3` absolute difference is trivially achievable on small weights and trivially unachievable on large weights, making the test dataset-dependent without a relative scale.

Options:
- **[A] Define the metric precisely**: "Max absolute relative difference `max(abs(w_linear - w_logit) / w_linear) < 0.001` on standard test data." Effort: one sentence. Impact: testable.
- **[B] Remove CX4 entirely** as an untestable theoretical property (asymptotic equivalence holds in the limit, not at finite sample sizes). Effort: minimal. This is acceptable since N1/N2 oracle tests for each function independently establish numerical correctness.
- **[C] Do nothing** — The tester will pick a reasonable metric.

**Recommendation: [B]** — Asymptotic equivalence at a specific sample size is not a reliable regression test. The oracle comparisons (N1/N2 for each function) already establish that each matches `survey::calibrate()`, which implicitly covers asymptotic equivalence. CX4 adds noise without a precise specification.

---

#### Section: test-spec — calibrate_linear()

**Issue 10: No test verifies `n_iterations > 1` for truncated-linear to confirm the engine is actually iterating**
Severity: SUGGESTION
Testing asymmetry: quality gate 7 asserts `n_iterations == 1L` for plain linear (EC10) but the test-spec has no complementary test asserting `n_iterations > 1` for truncated-linear.

Without this test, a builder who accidentally uses the plain-linear closed-form for the truncated path would pass all existing tests (H6 matches oracle, g-weights are in bounds) but would violate the internal contract that truncated-linear requires NR iteration. The failure mode is subtle: the oracle comparison might still pass if bounds aren't binding.

Options:
- **[A] Add EC11 to `calibrate_linear()` edge cases**: For `bounds = c(0.3, 3)` with non-trivial targets on a `survey_taylor` input, assert `obj@calibration$n_iterations > 1L`. Effort: trivial.
- **[B] Do nothing** — The oracle comparison (H6 vs survey::calibrate truncated) is sufficient evidence the engine is correct.

**Recommendation: [A]** — Quality gate 7 is now half-tested. One assertion completes the symmetric test.

---

### Summary (Pass 1)

| Severity | Count |
|---|---|
| BLOCKING | 1 |
| REQUIRED | 8 |
| SUGGESTION | 1 |

**Total issues:** 10

**Overall assessment:** The spec is nearly implementation-ready. All three blocking issues from the methodology review were resolved, the formulas are correct, and the function contracts are substantially complete. This pass found one blocking issue (a factual error in `calibrate()` that misattributes method-specific arguments to the wrong functions) and eight required gaps concentrated in two areas: (1) the test-spec has missing error path coverage in `calibrate_logit()` and `poststratify()`, and (2) two spec underspecifications (`cap` validation and `variable_select` options) that prevent a builder from writing correct validation logic without reading external source code. None of the required issues represent wrong formulas or wrong architectural decisions — they are gaps and omissions. Resolving Issue 1 (BLOCKING) and Issues 2–9 (REQUIRED) is recommended before implementation begins.

---

## Spec Review: calibration-framework — Pass 3 (2026-06-08)

### Prior Issues (Pass 2)

All 10 Pass 1 issues were resolved. Pass 2 found 0 new issues and advanced status to SPEC_READY.

### New Issues

#### Section: test-spec — calibrate_linear() and calibrate_logit()

**Issue 11: `surveywts_error_unit_scale_invalid` missing from both functions' error path tests**
Severity: REQUIRED
Violates `testing-standards.md §2` — every row in the error table covered by a test.

The spec error tables for both `calibrate_linear()` and `calibrate_logit()` list:
> `surveywts_error_unit_scale_invalid` | `unit_scale` is not `NULL` and is: not numeric, length ≠ `nrow(data)`, contains `NA`, or contains non-positive values

Neither function's test plan contains a test for this class. For `calibrate_linear()`, none of E1–E22 cover it. For `calibrate_logit()`, the test plan references "Same error classes as `calibrate_linear()` E1–E16" plus logit-specific E17–E22; since `unit_scale_invalid` is not in E1–E22 of linear, it also doesn't appear in logit's plan.

A builder who implements `unit_scale` validation has no regression protection for it.

Options:
- **[A] Add E23 to `calibrate_linear()` error paths**: `unit_scale = c(-1, rep(1, nrow(data) - 1))` → `surveywts_error_unit_scale_invalid`. Pattern: `expect_error(class=...)` + snapshot. Add the equivalent test to `calibrate_logit()` independently (do not rely on the cross-reference to linear E1–E16, which will not pick it up). Effort: two test blocks.
- **[B] Do nothing** — The shared `.validate_unit_scale()` helper is implicitly tested when either function validates input.

**Recommendation: [A]** — The cross-reference pattern for E1–E16 silently excludes any error not already in that numbered list; explicit test entries are required for both functions.

---

**Issue 12: `surveywts_error_unit_scale_invalid` not yet added to `plans/error-messages.md`**
Severity: REQUIRED
Violates code-style.md §3 — `class=` on every `cli_abort()` must correspond to a row in `plans/error-messages.md`.

The spec Scope section states:
> "Modify `plans/error-messages.md` — add `surveywts_error_cap_not_supported_nr`, `surveywts_error_bounds_invalid_calibration`, and `surveywts_error_unit_scale_invalid` (first two already done)."

The first two are present in `plans/error-messages.md`. `surveywts_error_unit_scale_invalid` is absent. The error-class-auditor agent will flag any `cli_abort(class = "surveywts_error_unit_scale_invalid")` call in the source as undocumented. This must be added before the builder begins.

Options:
- **[A] Add a row to the `calibrate_linear()` / `calibrate_logit()` section of `plans/error-messages.md`**: `surveywts_error_unit_scale_invalid | calibrate_linear(), calibrate_logit() | unit_scale is not NULL and is: not numeric, length ≠ nrow(data), contains NA, or contains non-positive values`. Effort: one table row.
- **[B] Do nothing** — The spec already acknowledges it as outstanding.

**Recommendation: [A]** — The spec acknowledges this is undone; do it now before implementation begins.

---

#### Section: test-spec — calibrate_rake()

**Issue 13: `surveywts_error_cap_not_positive` missing from `calibrate_rake()` error path tests**
Severity: REQUIRED
Violates `testing-standards.md §2` — every row in the error table covered by a test.

The spec adds `surveywts_error_cap_not_positive` to `calibrate_rake()`'s error table (Issue 2 resolution). `plans/error-messages.md` line 49 confirms it is registered. However, the `calibrate_rake()` test plan has E17 (`cap_not_supported_nr`), E18 (`calibration_not_converged`), E19 (`calibration_singular_system`), and no test for `cap_not_positive`.

Trigger: `cap = 0` or `cap = -1` with `algorithm = "classic_ipf"`.

Options:
- **[A] Add E20 to `calibrate_rake()` error paths**: `cap = 0, algorithm = "classic_ipf"` → `surveywts_error_cap_not_positive`. Pattern: `expect_error(class=...)` + snapshot. Effort: one test block.
- **[B] Do nothing** — Non-positive cap is an implausible input.

**Recommendation: [A]** — Error table row without a test is a coverage gap regardless of plausibility.

---

#### Section: spec — calibrate_rake() Returns / @calibration slot

**Issue 14: `calibrate_rake()` `@calibration` slot specification is incomplete**
Severity: REQUIRED
Violates `engineering-preferences.md §5` — explicit over clever; a builder cannot infer which fields to populate.

The spec Returns section for `calibrate_rake()` lists only two `@calibration` fields:
> "`lambda` field: `NULL` for `algorithm = "classic_ipf"`; converged λ vector for `algorithm = "nr"`."
> "`method` field: `"raking"`."

By contrast, `calibrate_linear()` Returns lists thirteen named fields: `x_matrix`, `base_weights`, `g_weights`, `crossproduct_inv`, `population_totals`, `discrepancy`, `lambda`, `method`, `cell_factors`, `q_weights`, `bounds_scale`, `converged`, `n_iterations`.

A builder implementing `calibrate_rake()` must decide:
- Is `x_matrix` stored? (Likely yes.)
- Is `g_weights` stored? (Required by quality gate 5.)
- Is `crossproduct_inv` stored? For `"nr"`, the NR Jacobian inverse at convergence; for `"classic_ipf"`, there is no such quantity. What is stored?
- Are `q_weights` and `bounds_scale` `NULL` (since rake has no `unit_scale` or `bounds` args)?
- Is `cell_factors` `NULL`?
- Are `converged` and `n_iterations` present?

The spec must either: (a) list all applicable fields explicitly as it does for `calibrate_linear()`, or (b) add a single sentence: "All `calibrate_linear()` `@calibration` fields apply; `q_weights = NULL`, `bounds_scale = NULL`, `cell_factors = NULL`. For `algorithm = "classic_ipf"`, `crossproduct_inv = NULL`; for `algorithm = "nr"`, `crossproduct_inv` is the NR Jacobian inverse at convergence (or `NULL` if not stored)."

Options:
- **[A] Add explicit field list for `calibrate_rake()` `@calibration`** using the approach in (b) above: reference `calibrate_linear()` fields and state which are `NULL` for rake. Effort: 2–3 sentences.
- **[B] Do nothing** — Quality gate 5 references `.build_calibration_provenance()`, which may define a canonical field list the builder can look up.

**Recommendation: [A]** — Quality gate 5 references an unspecified helper function; the builder cannot look up its contract without reading existing source code, violating the independently-sufficient requirement.

---

#### Section: spec — plans/error-messages.md stale entries

**Issue 15: Three `plans/error-messages.md` "Thrown by" entries reference functions being deleted**
Severity: REQUIRED
Violates `engineering-preferences.md §5` — stale entries cause incorrect error-class-auditor output after implementation.

The spec deletes `calibrate_greg()` and `calibrate_poststrat()` and adds `calibrate_linear()`, `calibrate_logit()`, and `poststratify()`. Three entries in `plans/error-messages.md` reference the deleted functions and will be stale after implementation:

1. `surveywts_warning_negative_calibrated_weights`: "Thrown by: `calibrate_greg()`" → should be `calibrate_linear()`.
2. `surveywts_warning_replicate_calibration_failed`: "Thrown by: `calibrate_greg()`, `calibrate_rake()`, `calibrate_poststrat()`" → should be `calibrate_linear()`, `calibrate_logit()`, `calibrate_rake()`, `poststratify()`.
3. `surveywts_warning_control_param_ignored`: "Thrown by: `calibrate_greg()`, `calibrate_rake()`" → should be `calibrate_linear()`, `calibrate_logit()`, `calibrate_rake()`.

Additionally:
4. `surveywts_message_already_calibrated`: "algorithm = `"anesrake"`" → should be `"classic_ipf"` (Issue 2 renamed this algorithm value).

The spec Scope section does not list updating these entries, so an implementer following the spec would leave them stale.

Options:
- **[A] Add these four `plans/error-messages.md` updates to the spec Scope section**, and update the entries now. Effort: four table-row edits.
- **[B] Do nothing** — The error-class-auditor runs after implementation, not before, and the inconsistency would be caught then.

**Recommendation: [A]** — The auditor depends on error-messages.md being correct; stale entries produce false negatives. Better to update the spec Scope and fix the entries now.

---

#### Section: spec — calibrate_rake() classic_ipf edge case

**Issue 16: Behavior when `min_cell_n` excludes all raking variables is unspecified**
Severity: SUGGESTION
Violates `engineering-preferences.md §4` — handle more edge cases, not fewer.

The spec documents `control$min_cell_n = 0L` for classic_ipf: "Variables with any cell below `control$min_cell_n` unweighted observations are excluded." If `min_cell_n` is set high enough that every variable is excluded at every sweep, the algorithm has no variables to calibrate. The spec does not state what happens: does it return weights unchanged, emit a message, or raise an error?

A consistent choice would be to treat this identically to the already-specified "all variables already at target" path: emit `surveywts_message_already_calibrated` and return weights unchanged (since "nothing to do" is the same outcome regardless of cause).

Options:
- **[A] Add a sentence to the `classic_ipf` details**: "If all variables are excluded by `min_cell_n` in sweep 1, behavior is identical to the already-calibrated path: `surveywts_message_already_calibrated` is emitted and weights are returned unchanged." Effort: one sentence.
- **[B] Do nothing** — High `min_cell_n` is user misconfiguration; documenting it is optional.

**Recommendation: [A]** — One sentence closes the gap and enables a targeted test.

---

### Summary (Pass 3)

| Severity | Count |
|---|---|
| BLOCKING | 0 |
| REQUIRED | 5 |
| SUGGESTION | 1 |

**Total new issues:** 6

**Overall assessment:** The spec remains nearly implementation-ready with no blocking issues. Pass 3 found five required gaps: two test-spec coverage holes (`unit_scale_invalid` missing from both calibrate_linear and calibrate_logit test plans, and `cap_not_positive` missing from calibrate_rake), one incomplete `@calibration` slot spec for calibrate_rake, one outstanding error-messages.md entry (`unit_scale_invalid`), and three stale "Thrown by" entries in error-messages.md that were not included in the spec's scope of changes. All five are low-effort fixes. Resolving them before implementation begins is recommended.

---

## Spec Review: calibration-framework — Pass 2 (2026-06-08) — Stage 3r Resolution

### Prior Issues (Pass 1)

| # | Title | Status |
|---|---|---|
| 1 | `calibrate()` method arg misattributes algorithm/cap | ✅ Resolved |
| 2 | `cap` lacks validation contract for non-positive values | ✅ Resolved |
| 3 | `variable_select` options undocumented | ✅ Resolved |
| 4 | `surveywts_error_empty_stratum` trigger imprecise | ✅ Resolved |
| 5 | Missing `calibrate_logit()` test for `bounds = c(NA, 2)` | ✅ Resolved |
| 6 | Missing `poststratify()` test for `weights_not_numeric` | ✅ Resolved |
| 7 | Missing `poststratify()` test for `empty_stratum` | ✅ Resolved |
| 8 | No test for `@calibration$method` truncated vs plain linear | ✅ Resolved |
| 9 | CX4 "Difference" metric undefined | ✅ Resolved |
| 10 | No test for `n_iterations > 1` for truncated-linear | ✅ Resolved |

### Resolution Notes

- **Issue 1**: Fixed parenthetical in `calibrate()` method arg to correctly attribute `algorithm`/`cap` to `calibrate_rake()` and `bounds` to `calibrate_linear()`/`calibrate_logit()`.
- **Issue 2**: Added validation contract to `cap` arg: must be positive finite numeric or `NULL`. New error class `surveywts_error_cap_not_positive` added to spec error table and `plans/error-messages.md`.
- **Issue 3**: Expanded `variable_select` description with one-sentence definition for each option (`"total"` = sum of cell chi-squares, `"max"` = max cell chi-square, `"average"` = mean cell chi-square).
- **Issue 4**: Replaced vague "zero weighted count" trigger with exact formulation: fires when `sum(replicate_weight_column[cell]) == 0` in any replicate column; full-sample path cannot trigger it. Updated spec error table and `plans/error-messages.md`.
- **Issue 5**: Added E20 (`bounds = c(NA, 2)`) to `calibrate_logit()` error paths in test-spec; renumbered former E20/E21 to E21/E22.
- **Issue 6**: Added E18 (`surveywts_error_weights_not_numeric`, trigger: character weight column) to `poststratify()` error paths in test-spec.
- **Issue 7**: Updated W2 in `poststratify()` warning paths to explicitly state it exercises the `surveywts_error_empty_stratum` internal path with a precise trigger (manually zero one replicate column's weights for one cell).
- **Issue 8**: Added `@calibration$method == "linear"` assertion to H3 (`survey_taylor` plain linear). Updated H6 to note that a `survey_taylor` variant should assert `@calibration$method == "truncated"`.
- **Issue 9**: Removed CX4 (asymptotic equivalence test with undefined metric). Former CX5 renumbered to CX4.
- **Issue 10**: Added EC11 to `calibrate_linear()` edge cases: `bounds = c(0.3, 3)` with non-trivial targets on `survey_taylor` input must have `@calibration$n_iterations > 1L`.

### Summary (Pass 2)

**All 10 Pass 1 issues resolved. 0 new issues found.**

Spec status advanced to SPEC_READY.

---

## Spec Review: calibration-framework — Pass 3 Stage 3r Resolution (2026-06-08)

### Prior Issues (Pass 3)

| # | Title | Status |
|---|---|---|
| 11 | `unit_scale_invalid` missing from calibrate_linear + calibrate_logit test-spec error paths | ✅ Resolved |
| 12 | `unit_scale_invalid` not in error-messages.md | ✅ Resolved |
| 13 | `cap_not_positive` missing from calibrate_rake test-spec error paths | ✅ Resolved |
| 14 | calibrate_rake `@calibration` slot specification incomplete | ✅ Resolved |
| 15 | Three error-messages.md "Thrown by" entries reference deleted functions | ✅ Resolved |
| 16 | `min_cell_n` all-excluded edge case unspecified | ✅ Resolved |

### Resolution Notes

- **Issue 11**: Added E23 (`surveywts_error_unit_scale_invalid`, trigger: `unit_scale = c(-1, rep(1, nrow(data) - 1))`) independently to `calibrate_linear()` and `calibrate_logit()` error paths in test-spec. Not relying on cross-reference to E1–E16 since that would silently exclude new entries.
- **Issue 12**: Added `surveywts_error_unit_scale_invalid` row to `plans/error-messages.md` under `calibrate_rake()` section (adjacent to `surveywts_error_bounds_invalid_calibration`), attributed to `calibrate_linear()`, `calibrate_logit()`.
- **Issue 13**: Added E20 (`surveywts_error_cap_not_positive`, trigger: `cap = 0, algorithm = "classic_ipf"`) to `calibrate_rake()` error paths in test-spec.
- **Issue 14**: Replaced minimal 2-bullet `@calibration` slot spec for `calibrate_rake()` with full field list referencing `calibrate_linear()` fields and explicitly stating which are `NULL` for rake (`q_weights`, `bounds_scale`, `cell_factors`, and for `"classic_ipf"`: `lambda`, `crossproduct_inv`). For `"nr"`: `lambda` and `crossproduct_inv` are populated.
- **Issue 15**: Updated four stale entries in `plans/error-messages.md`: `negative_calibrated_weights` (`calibrate_greg` → `calibrate_linear`), `replicate_calibration_failed` (three old names → four new names), `control_param_ignored` (`calibrate_greg` → `calibrate_linear`, `calibrate_logit`), `message_already_calibrated` (`"anesrake"` → `"classic_ipf"`). Updated spec Scope section to document these four updates explicitly.
- **Issue 16**: Added one sentence to `classic_ipf` details block in spec: "If all variables are excluded by `min_cell_n` in sweep 1, behavior is identical to the already-calibrated path: `surveywts_message_already_calibrated` is emitted and weights are returned unchanged."

### Summary (Pass 3 Stage 3r)

**All 6 Pass 3 issues resolved. Spec status confirmed SPEC_READY.**
