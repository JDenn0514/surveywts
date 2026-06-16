## Plan Review: calibrate-unit-scale — Pass 1 (2026-06-09)

---

### New Issues

#### Section: PR 1 — File Completeness

**Issue 1: Shared test dataset placement unspecified**
Severity: REQUIRED

The test spec defines three shared datasets with fixed seeds used across 10+
test blocks in each test file:

- `df_500 = make_surveywts_data(n = 500, seed = 42)`
- `df_200 = make_surveywts_data(n = 200, seed = 7)`
- `q_unequal = exp(rnorm(500, 0, 0.3))` with `set.seed(99)`

The plan does not specify where these are defined. If each `test_that()` block
constructs them independently, the result is 20+ instances of
`set.seed(99); q_unequal <- exp(rnorm(500, 0, 0.3))` and 20+ calls to
`make_surveywts_data(n = 500, seed = 42)` — a DRY violation that inflates the
test files and makes oracle comparisons fragile. Seed interactions between
blocks are a real concern if any block modifies global state. This also
contradicts `engineering-preferences.md §1 (DRY)`.

The helper file `tests/testthat/helper-test-data.R` already holds shared test
infrastructure and is the right home. Alternatively, a `local()` block at the
top of each test file works. The plan must specify which.

Options:
- **[A]** Add `df_500`, `df_200`, `q_unequal`, `q_all_twos` as named objects in
  `helper-test-data.R` and list `helper-test-data.R` in the write surface —
  Effort: low, Risk: low, Impact: DRY, reproducible oracle comparisons
- **[B]** Specify that each test file defines them once at the top of the file
  in a shared `local()` scope, referenced inside `test_that()` blocks —
  Effort: low, Risk: low, Impact: same benefits without changing the helper
- **[C] Do nothing** — Builder must guess; likely creates 20+ duplicated seed
  calls; oracle mismatches become very hard to debug

**Recommendation: [A]** — Extends the established helper pattern; no ambiguity
for the builder; keeps test files free of setup boilerplate.

---

#### Section: PR 1 — Acceptance Criteria (replicate absolute-bounds coverage)

**Issue 2: No explicit test for replicate absolute-bounds success path**
Severity: REQUIRED

The two new code paths that replace the old `scale_factor` approach in the
replicate loops have no dedicated failing test in the plan:

- `calibrate_linear()` call site 4 (replicate loop, bounded-absolute branch):
  computes `rep_L_vec = abs_L / rep_wt`, `rep_U_vec = abs_U / rep_wt`, runs
  engine with `rep_wt` directly
- `calibrate_logit()` call site 3 (replicate loop, absolute branch):
  same per-unit vector approach plus precondition check

RL-1 and RL-2 use unspecified bounds (effectively multiplicative/unbounded) —
they verify `unit_scale` propagation, not the D6 fix in the replicate path.
EC-9 and EC-10 are full-sample only. No listed test would fail if the replicate
absolute-bounds path retained the old `scale_factor` implementation.

The acceptance criterion "absolute-bounds per-unit path in both functions
(full-sample and replicate) must be covered" is necessary but not sufficient:
coverage via a passing test is not the same as a *failing* test that drives
correct implementation. A builder who correctly fixes full-sample but forgets
the replicate path would pass all acceptance criteria except coverage — and
even that gap might be masked by incidental hits.

The plan's Notes section also flags the `abs_L`/`abs_U` scope concern ("verify
these variables are declared before the replicate loop, not inside the
full-sample `if` branch"). Without a replicate absolute-bounds test, this
concern has no safety net: the code would crash at runtime rather than fail a
test.

Required additions (two new test blocks, one per function):

- **RL-5 (linear):** `calibrate_linear()` with `survey_replicate` input,
  `bounds = c(L_abs, U_abs)`, `bounds_scale = "absolute"` — assert all final
  weights in every replicate column satisfy `w_k >= L_abs` and `w_k <= U_abs`;
  `test_invariants(result)` first
- **RL-6 (logit):** `calibrate_logit()` with `survey_replicate` input,
  `bounds = c(L_abs, U_abs)`, `bounds_scale = "absolute"`, all base weights
  strictly inside `(L_abs, U_abs)` — assert result is `survey_replicate`,
  `test_invariants(result)` first, calibration constraint holds on full-sample
  weights

These should be listed under the replicate loop section of each test file, and
as explicit acceptance criteria.

Options:
- **[A]** Add RL-5 and RL-6 to the plan (test blocks + acceptance criteria);
  add RL-5/RL-6 to the write surface for each test file —
  Effort: low, Risk: low, Impact: closes the largest coverage gap in the plan
- **[B]** Accept that the 98% coverage criterion will force the builder to add
  the tests during implementation — Effort: zero, Risk: high (builder may not
  realize the gap; replicate absolute-bounds path is easy to miss)
- **[C] Do nothing** — Call sites 4 (linear) and 3 (logit) have no test
  contract; the D6 fix may be silently absent from the replicate path

**Recommendation: [A]** — Two small test blocks eliminate the most significant
behavioral gap in the plan; also resolves the Notes section's abs_L/abs_U scope
concern by ensuring the test would fail at runtime if scoping is wrong.

---

#### Section: PR 1 — Acceptance Criteria (minor omissions)

**Issue 3: HL-1 and HL-RG describe the same assertion**
Severity: SUGGESTION

Both entries test that `unit_scale = NULL` produces weights identical to
`unit_scale = rep(1, n)` within `1e-14`:

- HL-RG (Regression guard section): "`unit_scale = rep(1, n)` weights identical
  to `unit_scale = NULL` within `1e-14`"
- HL-1 (Happy path section): "`unit_scale = NULL` matches `unit_scale =
  rep(1, n)` exactly"

As written, the builder would create two separate `test_that()` blocks making
the same assertion. The plan should specify which of the two is the canonical
block for the acceptance criterion, and drop or merge the other. The same
applies to HG-RG and HG-1.

Options:
- **[A]** Remove HL-RG from the plan (it duplicates HL-1); relabel HL-1 as the
  regression guard; update acceptance criteria to reference HL-1 —
  Effort: negligible, Risk: none, Impact: one fewer redundant test block
- **[B]** Keep both but add a plan note: "HL-RG is a separate focused block
  with no oracle setup; HL-1 shares the oracle setup context" — Effort:
  negligible, Risk: none
- **[C] Do nothing** — Builder writes two tests; redundant but not incorrect

**Recommendation: [A]** — Merge the two; the regression guard doesn't need its
own block when HL-1 already makes the same assertion.

---

**Issue 4: EC-4 expected outcome is "either/or" and lacks a test pattern**
Severity: SUGGESTION

EC-4: "Does not produce silent wrong result; either converges correctly or
throws `surveywts_error_calibration_singular_system`."

An "either/or" expectation is not directly expressible as a standard
`expect_error()` or `expect_equal()` assertion. The builder must invent a
`tryCatch()` structure that validates whichever outcome occurs. Without a
prescribed test pattern, two builders would write incompatible tests; one might
write a test that always passes regardless of whether the wrong outcome occurs.

The plan should specify the expected outcome for the specific test data (one
unit with `q_k = 1e8`, rest `q_k = 1`) and supply the test pattern:

```r
result <- tryCatch(
  calibrate_linear(df_20, targets, weights = base_weight,
                   unit_scale = q_extreme),
  error = function(e) e
)
if (inherits(result, "error")) {
  expect_s3_class(result, "surveywts_error_calibration_singular_system")
} else {
  test_invariants(result)
  # calibration constraint holds for the non-extreme units
}
```

Options:
- **[A]** Update EC-4 in the plan to prescribe the test pattern above and state
  which outcome is expected for the specific test data — Effort: low, Risk: none
- **[B]** Leave as-is and note that the builder must handle both outcomes —
  Effort: zero, Risk: inconsistent tests across reviewers
- **[C] Do nothing** — Ambiguous test; likely passes regardless of wrong output

**Recommendation: [A]** — A concrete test pattern eliminates ambiguity at zero cost.

---

**Issue 5: HL-6/HG-6 (history records unit_scale) and HL-7 not in acceptance criteria**
Severity: SUGGESTION

HL-6, HL-7, HG-6 appear in the "test blocks to add" list but do not appear as
named acceptance criteria. If these test blocks fail, the current acceptance
criteria checklist would not catch it — only the "all new tests pass" gate would.
This weakens the PR review: a reviewer checking off named criteria could mark
the PR complete with HL-6/HG-6 still failing.

The history invariant (HL-6/HG-6) is particularly important because the
`weighting_history` is used downstream by diagnostics functions.

Options:
- **[A]** Add two acceptance criteria: "HL-6 and HG-6: `unit_scale` recorded in
  `weighting_history` entry" and "HL-7: bounded vs unbounded outputs differ
  with same q" — Effort: negligible
- **[B]** Rely on "all new tests pass" as the catch-all — Effort: zero, Risk:
  PR can technically be marked done with these tests still failing if the
  reviewer only checks named criteria
- **[C] Do nothing**

**Recommendation: [A]** — Named criteria make review faster and prevent the
"all new tests pass" catch-all from being the only safety net.

---

### Summary (Pass 1)

| Severity | Count |
|---|---|
| BLOCKING | 0 |
| REQUIRED | 2 |
| SUGGESTION | 3 |

**Total issues:** 5

**Overall assessment:** The plan is nearly implementable as-is — the mechanics
are correct, the spec coverage is solid, and the TDD ordering is right. Two
gaps need resolution before coding: the shared test dataset placement (Issue 1)
and the missing replicate absolute-bounds tests (Issue 2). Issue 2 is the more
consequential gap: it means two new code paths (call sites 4 and 3 in the
replicate loops) have no failing test contract, and the `abs_L`/`abs_U` scope
concern noted in the plan's own Notes section would have no safety net.
Resolving Issues 1 and 2 brings the plan to PLAN_READY.

---

## Plan Review: calibrate-unit-scale — Pass 2 (2026-06-09)

### Prior Issues (Pass 1)

| # | Title | Status |
|---|---|---|
| 1 | Shared test dataset placement unspecified | ✅ Resolved — helper-test-data.R now listed in write surface with `df_500`, `df_200`, `q_unequal`, `q_all_twos` defined at file top level |
| 2 | No explicit test for replicate absolute-bounds success path | ✅ Partially resolved in plan — RL-5 and RL-6 added to the plan with detailed descriptions and acceptance criteria. **However, the test-spec was not updated** (see Issue 1 below). |
| 3 | HL-1 and HL-RG describe the same assertion | ✅ Resolved — HL-1 is now the regression guard; HL-RG not listed as a separate test block; acceptance criteria reference HL-1/HG-1 only |
| 4 | EC-4 "either/or" expected outcome lacks test pattern | ✅ Resolved — impl plan now specifies the `tryCatch()` pattern and the expected non-error outcome explicitly |
| 5 | HL-6/HG-6 and HL-7 not in acceptance criteria | ✅ Resolved — all three now appear as named acceptance criteria |

---

### New Issues

#### Section: PR 1 — calibrate-utils.R Task 7 (n_iterations tracking)

**Issue 1: Task 7 is redundant and proposes the wrong storage path**
Severity: REQUIRED
Violates spec fidelity and will cause HL-12 assertion to access a non-existent field.

The impl plan task 7 in `R/calibrate-utils.R` reads:

> _"Track iteration count: initialize `n_iterations <- 0L` before the NR loop; increment at the top of each loop body; attach as an attribute before returning: `attr(result, "n_iterations") <- n_iterations` so callers extract it with `attr(engine_result, "n_iterations")` and store it in `weighting_history[[entry]]$parameters$n_iterations`"_

Verification against current code shows this is describing something that already exists under a different mechanism:

- `.calibrate_nr_engine()` already returns `n_iterations = as.integer(iter)` as a named list element (not via `attr()`).
- Every call site in `calibrate_linear.R` (verified at lines 448–521) already extracts `engine_result_raw$n_iterations` and wraps it into `engine_result$convergence = list(converged = ..., iterations = engine_result_raw$n_iterations)`.
- `.make_history_entry()` receives `convergence = engine_result$convergence`, so the history entry already stores `$convergence$iterations`.

The acceptance criterion in the plan says:

> _"`weighting_history[[1]]$parameters$n_iterations == 1L`"_

But the test-spec HL-12 says to access via:

> _"`weighting_history[[1]]$convergence$iterations`"_

These are two different field paths. The tester reads only the test-spec and will check `$convergence$iterations`. If a builder follows the impl plan's task 7 and acceptance criterion, they will:
1. Add redundant `attr()`-based tracking alongside the existing `$n_iterations` list element
2. Add new code in callers to store in `$parameters$n_iterations` (a new field that doesn't yet exist)
3. Write the HL-12 assertion as `$parameters$n_iterations == 1L`

The tester will then check `$convergence$iterations` and may or may not find the right value depending on whether callers also still populate `$convergence`. This is a guaranteed divergence between builder output and tester expectation.

Options:
- **[A]** Delete task 7 entirely from the impl plan (iteration count tracking already exists via the `$n_iterations` list return); update the HL-12 acceptance criterion to read `weighting_history[[1]]$convergence$iterations == 1L` to match the test-spec — Effort: negligible, Risk: none, Impact: removes a task that would introduce bugs
- **[B]** Rewrite task 7 to say "no change needed — n_iterations already tracked; verify existing `$convergence$iterations` path is preserved" — Effort: negligible, Risk: none
- **[C] Do nothing** — Builder adds redundant attr-based tracking; HL-12 checks `$parameters$n_iterations`; tester checks `$convergence$iterations`; one will fail or they'll be semantically duplicated

**Recommendation: [A]** — Task 7 is describing pre-existing infrastructure. Removing it eliminates a source of unnecessary changes and the acceptance criterion discrepancy.

---

#### Section: PR 1 — Test-spec coverage (RL-5, RL-6)

**Issue 2: RL-5 and RL-6 are in the impl plan but absent from the test-spec**
Severity: REQUIRED
Violates the pipeline isolation contract: tester reads only test-spec.

Pass 1 Issue 2 was resolved by adding RL-5 and RL-6 to the impl plan. The plan now lists them as test blocks and acceptance criteria. However, the test-spec (`plans/test-spec-calibrate-unit-scale.md`) still has only RL-1 through RL-4 in the replicate loop section.

The `tester` agent receives only the test-spec. In the current pipeline:

- Builder reads spec + impl plan → writes tests RL-5 and RL-6
- Tester reads test-spec → validates all test-spec scenarios → writes audit.md
- **RL-5 and RL-6 are not in the test-spec** → tester cannot verify them → the D6 replicate-loop fix goes unaudited

This defeats the entire purpose of adding RL-5 and RL-6: to ensure the replicate absolute-bounds code paths (call site 4 in linear, call site 3 in logit) have a failing-test contract. If the tester cannot verify them, a builder who forgets to implement the replicate fix passes audit.

Required: add RL-5 and RL-6 to `plans/test-spec-calibrate-unit-scale.md` under the replicate loop section, matching the descriptions in the impl plan:

- **RL-5 (linear):** `calibrate_linear()` with `survey_replicate` input, `bounds = c(L_abs, U_abs)`, `bounds_scale = "absolute"` — all final weights in every replicate column satisfy `w_k >= L_abs` and `w_k <= U_abs`; `test_invariants(result)` first; `skip_if_not_installed("survey")` inside block.
- **RL-6 (logit):** `calibrate_logit()` with `survey_replicate` input, `bounds = c(L_abs, U_abs)`, `bounds_scale = "absolute"`, all base weights strictly inside `(L_abs, U_abs)` — result is `survey_replicate`; calibration constraint holds on full-sample weights within `1e-6`; `test_invariants(result)` first.

Options:
- **[A]** Update `test-spec-calibrate-unit-scale.md` to add RL-5 and RL-6 to the replicate loop table — Effort: low, Risk: none, Impact: closes the tester audit gap for the D6 replicate fix
- **[B]** Accept that RL-5 and RL-6 are builder-only tests that tester does not audit — Effort: zero, Risk: high (replicate absolute-bounds fix may be silently absent; main purpose of adding these tests is unmet)
- **[C] Do nothing** — D6 replicate loop paths unaudited; same failure mode as Pass 1 Issue 2 described, now hidden inside the pipeline

**Recommendation: [A]** — The test-spec update is a one-paragraph addition. Without it, resolving Pass 1 Issue 2 in the plan achieves nothing for the pipeline.

---

#### Section: PR 1 — Acceptance Criteria (minor tolerance mismatch)

**Issue 3: HG-5 calibration constraint tolerance differs between test-spec and acceptance criteria**
Severity: SUGGESTION

The test-spec specifies HG-5 (logit calibration constraint) at tolerance `1e-6`:

> _"All target proportions matched" … tolerance: `1e-6`_

The impl plan acceptance criterion bundles HL-5 and HG-5 together at `1e-8`:

> _"Calibration constraint: HL-5 and HG-5 pass within `1e-8` for any `unit_scale != NULL`"_

The tester reads the test-spec and validates HG-5 at `1e-6`. The acceptance reviewer reads the impl plan and expects `1e-8`. If the logit constraint lands at `1e-7` (satisfies the test-spec but not the acceptance criterion), the tester passes and the acceptance review flags a failure — an inconsistent outcome.

Options:
- **[A]** Update the impl plan acceptance criterion to split HL-5 and HG-5: HL-5 at `1e-8`, HG-5 at `1e-6` — Effort: negligible, Risk: none
- **[B]** Leave as-is; since logit typically achieves `1e-8` or better in practice, the discrepancy is unlikely to surface — Effort: zero, Risk: low but non-zero
- **[C] Do nothing**

**Recommendation: [A]** — One-word change; eliminates the ambiguity for acceptance review.

---

**Issue 4: `q_all_ones` absent from helper-test-data.R write surface**
Severity: SUGGESTION

The test-spec lists `q_all_ones = rep(1, 500)` as a named dataset in its datasets table. The impl plan's `helper-test-data.R` task adds `df_500`, `df_200`, `q_unequal`, and `q_all_twos`, but omits `q_all_ones`.

Since `q_all_ones` is a trivial one-liner, the builder will likely construct it inline in HL-1/HG-1 without noticing the omission. But this creates an inconsistency: the test-spec describes a named shared object that doesn't exist in the helper, meaning the builder must interpret whether it should be in the helper or constructed inline.

Options:
- **[A]** Add `q_all_ones = rep(1, 500)` to the helper-test-data.R task description — Effort: negligible, Risk: none
- **[B]** Add a note in the impl plan: "`q_all_ones` is trivial; construct inline in each test block" — Effort: negligible, Risk: none
- **[C] Do nothing** — Builder will construct it inline; no test breaks; minor inconsistency with test-spec dataset table

**Recommendation: [A]** — Consistency with the test-spec dataset table costs nothing; avoids builder ambiguity.

---

### Summary (Pass 2)

| Severity | Count |
|---|---|
| BLOCKING | 0 |
| REQUIRED | 2 |
| SUGGESTION | 2 |

**Total new issues:** 4

**Overall assessment:** Pass 1 issues are fully resolved in the impl plan (Issue 2 required one more step). Two REQUIRED gaps remain: task 7 is a stale description of already-existing infrastructure that will produce wrong acceptance criterion field paths, and the test-spec needs RL-5/RL-6 added so the tester can audit the D6 replicate-loop fix. Resolving those two issues brings the plan to PLAN_READY.
