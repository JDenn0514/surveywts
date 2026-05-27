# Plan Review: nps-bootstrap — Pass 1 (2026-05-27)

---

## New Issues

### Section: PR 1 — Error classes and test helpers

---

**Issue 1: BLOCKING — Level A/B detection references the wrong access path for `calib_entry$targets_from_reference`**

Severity: BLOCKING
Violates: spec §IV detection rule vs. actual `rake()` / `calibrate()` history structure

The plan's detection rule is:
```r
use_level_b <-
  isTRUE(calib_entry$targets_from_reference) ||
  !is.null(ipw_entry$reference_design)
```

But `rake()` and `calibrate()` build their history entries via `.make_history_entry()`, which wraps all operational parameters inside a nested `parameters` key:
```r
# From R/rake.R line 349–366
history_entry <- .make_history_entry(
  parameters = list(
    targets_from_reference = !is.null(reference_design),
    ...
  ),
  ...
)
```

So `calib_entry$targets_from_reference` is always `NULL`. `isTRUE(NULL)` = `FALSE`. The calibration branch of the Level B detection will **never fire** in any test or production call. Only the second branch (`!is.null(ipw_entry$reference_design)`) is reachable.

The correct access path is `calib_entry$parameters$targets_from_reference`.

(Note: `ipw()` does NOT use `.make_history_entry()` — its history entry is a flat list, so `ipw_entry$reference_design`, `ipw_entry$formula`, etc. are correct as written.)

Options:
- **[A]** Fix access path to `calib_entry$parameters$targets_from_reference` in the detection rule and everywhere `calib_entry$*` is referenced (see also Issue 3). — Effort: low, Risk: low, Impact: detection rule now correctly fires Level B via calibration branch.
- **[B]** Do nothing — Level B via calibration path silently never fires; only `ipw_entry$reference_design` triggers Level B (which then conflicts with Issue 2). — Effort: none, Risk: high, Impact: incorrect variance estimation for calibration-based Level B workflows.

**Recommendation: A** — Fix the access path. This affects the detection rule line, the in-loop calibration replay (Issue 3), and any other place `calib_entry$*` is used without the `$parameters` sub-path.

---

**Issue 2: BLOCKING — `!is.null(ipw_entry$reference_design)` overfires; `make_nps_level_a()` produces Level B, contradicting Block 1 and EC5**

Severity: BLOCKING
Violates: Test spec Block 1 (expects `level = "A"` for `make_nps_level_a()` output), EC5 (expects `level = "A"` for ipw-only with reference)

The `ipw()` implementation always stores `reference_design = reference` in its history entry (R/nonprob-ipw.R line 1189). Therefore `ipw_entry$reference_design` is non-NULL whenever `ipw()` is called with a reference sample — which is the case for every `make_nps_level_a()` and `make_nps_level_b()` call.

Under the current detection rule, **all objects produced by `make_nps_level_a()` would be classified as Level B** because `!is.null(ipw_entry$reference_design) = TRUE`. This directly contradicts:
- Test spec Block 1: expects `level = "A"` for `make_nps_level_a(seed=1)` output.
- Test spec EC5: expects `level = "A"` for `ipw(reference=ref, ...)` with no downstream calibration.
- Test spec Block 7: asserts that passing `reference_sample = ref_fixed` "forces Level A behavior" — but the detection rule ignores `reference_sample`.

A builder following the plan would write a detection rule that classifies `make_nps_level_a()` as Level B, causing Block 1, EC5, and the Level A side of Block 7 to fail at the RED step (they'd pass without implementation, invalidating TDD).

**Root cause:** The intended distinction between Level A and Level B is "did calibration consume the reference sample?" (`targets_from_reference = TRUE`). The `!is.null(ipw_entry$reference_design)` clause widens the net to include IPW-only workflows where the reference is present, which fires on every call that includes an `ipw()` step with a reference — i.e., every valid NPS bootstrap call.

Options:
- **[A]** Narrow the detection rule to calibration only:
  ```r
  use_level_b <- isTRUE(calib_entry$parameters$targets_from_reference)
  ```
  This produces Level A for `make_nps_level_a()` (rake without `reference_design`) and Level B for `make_nps_level_b()` (rake with `reference_design`). EC5 (ipw-only) gets Level A. Statistical note: IPW-only workflows with a probability-sample reference technically should propagate reference variance, but the spec doesn't have a Level B path for calibration-free inputs, so Level A is the practical default. Update EC5 expected level to document this limitation.
  
  Block 7 needs redesign: since passing `reference_sample` no longer affects detection, "forced Level A" via `reference_sample` doesn't work. Instead, compare Level A data (`make_nps_level_a()`) against Level B data (`make_nps_level_b()`) at the same seed to confirm the code paths produce different outputs.
  
  Effort: medium (test helper names already match this rule; Block 7 redesign is small); Risk: low; Impact: all detection tests pass as written.

- **[B]** Add a `reference_sample`-override flag to the detection rule:
  ```r
  use_level_b <- is.null(reference_sample) &&
    (isTRUE(calib_entry$parameters$targets_from_reference) ||
     !is.null(ipw_entry$reference_design))
  ```
  Passing `reference_sample` explicitly → Level A (user-declared fixed reference). Not passing it with a stored reference → Level B. This makes `make_nps_level_a()` Level B (no explicit `reference_sample`) and breaks Block 1. Test helpers would need redesign.
  
  Effort: high (helpers + Block 1 + EC5 all need to be rethought); Risk: medium.

- **[C] Do nothing** — Block 1, EC5, and Block 7 all fail at the GREEN step. TDD is invalidated because tests may pass by accident at RED.

**Recommendation: A** — Narrow the detection rule to `calib_entry$parameters$targets_from_reference` only. This aligns with the naming and structure of the test helpers (`make_nps_level_a`: no `reference_design` in rake; `make_nps_level_b`: `reference_design` in rake). Redesign Block 7 to compare `make_nps_level_a()` vs. `make_nps_level_b()` outputs directly rather than trying to "force Level A" via `reference_sample`.

---

**Issue 3: BLOCKING — In-loop calibration replay uses wrong access paths throughout**

Severity: BLOCKING
Violates: spec §IV algorithm; actual `rake()` / `calibrate()` history structure (same root cause as Issue 1)

Every place the plan accesses calibration parameters from the history entry uses the flat path. The correct nested paths are:

| Plan uses | Actual path | Where used |
|-----------|-------------|-----------|
| `calib_entry$margins` | `calib_entry$parameters$margins` | In-loop rake()/calibrate() call; Level B target re-estimation |
| `calib_entry$targets_from_reference` | `calib_entry$parameters$targets_from_reference` | Level A/B detection rule (Issue 1) |
| `calib_entry$type` (implied by `...`) | `calib_entry$parameters$type` | In-loop rake()/calibrate() call |
| `calib_entry$method` (implied by `...`) | `calib_entry$parameters$method` | In-loop rake()/calibrate() call |
| `calib_entry$cap` (implied by `...`) | `calib_entry$parameters$cap` | In-loop rake()/calibrate() call |
| `calib_entry$control` (implied by `...`) | `calib_entry$parameters$control` | In-loop rake()/calibrate() call |
| `calib_entry$reference_design` | `calib_entry$parameters$reference_design` | Level B: reference_design for in-loop rake() |

The in-loop rake() call with `margins = calib_entry$margins` (which is NULL) would error with `surveywts_error_margins_format_invalid` in every draw, causing all draws to fail and `surveywts_error_bootstrap_all_draws_failed` to fire. None of the calibration-dependent happy-path tests (Blocks 1, 2, 3, EC3, H1) would pass.

Additionally, the `...` in the implementation notes ("same params as stored in calib_entry") is ambiguous about which fields to replay. The builder needs the complete list: `type`, `method`, `cap`, `control`, `wt_name`.

Options:
- **[A]** Fix all access paths to use `calib_entry$parameters$*` throughout, and enumerate the complete replay field list explicitly in the implementation notes:
  ```r
  calib_result_b <- rake(  # or calibrate() per calib_entry$operation
    data    = ipw_result_b,
    margins = calib_entry$parameters$margins,
    type    = calib_entry$parameters$type,
    method  = calib_entry$parameters$method,
    cap     = calib_entry$parameters$cap,
    control = calib_entry$parameters$control
  )
  ```
  For Level B, `margins` is replaced with the perturbed per-draw targets (re-estimated from `S_B_b`). — Effort: low, Risk: low, Impact: in-loop calibration works correctly.

- **[B] Do nothing** — every draw errors with NULL margins; all draw-failure tests (EC2, W2) pass accidentally for the wrong reason; all happy-path tests fail.

**Recommendation: A**

---

### Section: PR 2 — NPS bootstrap implementation

---

**Issue 4: REQUIRED — Acceptance criteria omit `@param seed` documentation update**

Severity: REQUIRED
Violates: spec §III.C explicit requirement

Spec §III.C states: "This difference should be noted in the `@param seed` documentation: 'For NPS types, `set.seed()` is called once and the caller's RNG state is not restored; for probability-sample types, the seed is applied via `withr::local_seed()` and the caller's state is restored.'"

Neither the TDD sub-steps nor the PR 2 acceptance criteria list updating `@param seed` documentation. A builder following the checklist will write the functional code correctly but miss the `@param` update. This is a user-facing contract difference (one path is RNG-safe, the other is not) that belongs in the exported documentation.

Options:
- **[A]** Add criterion: `@param seed` documentation includes the NPS / prob-sample RNG restoration difference per spec §III.C. — Effort: trivial, Risk: none.
- **[B] Do nothing** — users discover the RNG side-effect through debugging.

**Recommendation: A**

---

**Issue 5: REQUIRED — Coverage criterion omits `R/methods-print.R`**

Severity: REQUIRED
Violates: testing-standards.md 98%+ line coverage target

PR 2 acceptance criterion states: "Test coverage ≥ 98% on new code in `R/replicate-weights.R`". The print extension in `R/methods-print.R` adds ~15–20 lines of new code (the repweights conditional block). This code is exercised by Blocks 8 and 9 (snapshot tests), but the coverage criterion doesn't name it. If the print extension has an untested branch (e.g., the `!is.null(repwts) && length(repwts) > 0L` guard), it could slip through.

Options:
- **[A]** Add: "Test coverage ≥ 98% on new code in `R/methods-print.R`" to acceptance criteria. — Effort: trivial, Risk: none.
- **[B] Do nothing** — print extension branches may go uncovered; CI coverage check may flag the gap after merge.

**Recommendation: A**

---

**Issue 6: REQUIRED — In-loop calibration replay does not enumerate all fields to replay from `calib_entry$parameters`**

Severity: REQUIRED
Violates: spec §IV algorithm correctness

The implementation notes say "same params as stored in `calib_entry`" with `...` ellipsis, which is ambiguous. The actual `rake()` history entry stores: `variables`, `margins`, `type`, `method`, `cap`, `control`, `targets_from_reference`, `reference_design` inside `calib_entry$parameters`. The `calibrate()` history entry stores: `variables`, `population`, `method`, `type`, `control`, `targets_from_reference`, `reference_design`.

Without an explicit list, a builder could omit `type` (defaulting to `"prop"` when the original call used `"count"`), `method` (defaulting to `"anesrake"` when the original used `"survey"`), `cap`, or `control`. Each omission would silently produce inconsistent replicate weights.

Options:
- **[A]** Add the complete replay field list to the implementation notes for both `rake()` and `calibrate()` paths (see Issue 3 recommendation for the rake() version). — Effort: low, Risk: none.
- **[B] Do nothing** — builder guesses which fields to replay; likely to miss at least one under time pressure.

**Recommendation: A** — This also requires distinguishing rake vs. calibrate paths: `rake()` entry uses `margins`; `calibrate()` entry uses `population`.

---

**Issue 7: REQUIRED — `tests/testthat/_snaps/` not in PR 2 write surface list**

Severity: REQUIRED
Violates: github-strategy.md (snapshot files committed in same PR)

The implementation notes say "Commit the `_snaps/` file in the same PR" (TDD step 5), but `tests/testthat/_snaps/` is absent from the PR 2 file list. A shipper running the PR sequence could open the PR without the snapshot files, causing CI to fail with "snapshots need to be reviewed."

Options:
- **[A]** Add `tests/testthat/_snaps/08-nps-bootstrap.md` (or the directory) to the PR 2 write surface list. — Effort: trivial.
- **[B] Do nothing** — the acceptance criterion ("Print snapshots approved and committed") covers this, but the file list discrepancy will confuse automated tooling.

**Recommendation: A**

---

**Issue 8: SUGGESTION — PR 1 helper correctness has no automated gate**

Severity: SUGGESTION
Principle: engineering-preferences.md — "well-tested is always better"

PR 1 acceptance criterion includes: "test_invariants() passes on objects returned by each helper." But there is no test file in PR 1 — the plan says to "verify manually." If any of the three helpers (`make_nps_ref`, `make_nps_level_a`, `make_nps_level_b`) are broken (wrong argument name, function doesn't exist yet, wrong API for `ipw()` or `rake()`), the error surfaces only when PR 2 test blocks fail with misleading messages (e.g., "object of type 'NULL' is not subsettable" instead of "expected level A, got NULL").

A minimal smoke-test block in PR 1 (no new test file needed — add a single `test_that()` to an existing helper test file) would catch broken helpers before the full PR 2 test suite runs.

Options:
- **[A]** Add a `test_that("helper functions return survey_nonprob with ipw history", { ... })` block in PR 1, calling `make_nps_ref()`, `make_nps_level_a()`, `make_nps_level_b()` and asserting: not NULL, correct class, history has "ipw" entry. — Effort: low, Risk: none.
- **[B]** Keep "verify manually" — acceptable if the team runs the smoke test before declaring PR 1 done. — Risk: low but non-zero.
- **[C] Do nothing** — helper bugs surface as confusing failures in PR 2.

**Recommendation: A** — A two-minute test block eliminates a whole class of misleading failures.

---

**Issue 9: SUGGESTION — Changelog path deviates from existing phase convention**

Severity: SUGGESTION
Principle: github-strategy.md branch naming / consistency

Existing changelog directories: `calibration/`, `nonresponse/`, `propensity/`, `replicate/`, `utilities/`, `wt-name/`. The plan creates `changelog/nps-bootstrap/feature-nps-bootstrap.md` — a new feature-level directory. The NPS bootstrap is part of the Replicate phase per CLAUDE.md roadmap. Using `changelog/replicate/feature-nps-bootstrap.md` would follow the existing phase convention.

Options:
- **[A]** Use `changelog/replicate/feature-nps-bootstrap.md` — consistent with existing structure. — Effort: trivial.
- **[B]** Keep `changelog/nps-bootstrap/` — creates a one-off directory; precedent may be intentional if nps-bootstrap is a named sub-phase. — Risk: low.

**Recommendation: A** — unless the team has decided NPS bootstrap is its own named sub-phase, in which case document the convention change.

---

## Summary (Pass 1)

| Severity | Count |
|---|---|
| BLOCKING | 3 |
| REQUIRED | 4 |
| SUGGESTION | 2 |

**Total issues:** 9

**Overall assessment:** The plan has three blocking issues that would cause all calibration-path tests to fail: the wrong access paths for `calib_entry$*` (should be `calib_entry$parameters$*`), and a Level A/B detection rule that overfires on every IPW-with-reference call, making the `make_nps_level_a()` helper produce Level B. These need to be resolved before implementation begins — a builder following the plan as written would produce code where every Level A happy-path test fails, draw failures accumulate for the wrong reason, and the TDD RED step cannot be validated correctly. The four REQUIRED issues are straightforward fixes (documentation, coverage criterion, file list) that take minutes to address. Recommend Stage 3 to close Issues 1–3 first, then Issues 4–7 as a batch.

---

## Plan Review: nps-bootstrap — Pass 2 (2026-05-27)

### Prior Issues (Pass 1)

| # | Title | Status |
|---|---|---|
| 1 | Level A/B detection uses `calib_entry$targets_from_reference` (wrong path) | ✅ Resolved |
| 2 | `!is.null(ipw_entry$reference_design)` overfires on all IPW calls | ✅ Resolved |
| 3 | In-loop calibration replay uses flat `calib_entry$*` paths throughout | ✅ Resolved |
| 4 | Acceptance criteria omit `@param seed` documentation update | ✅ Resolved |
| 5 | Coverage criterion omits `R/methods-print.R` | ✅ Resolved |
| 6 | In-loop calibration replay doesn't enumerate all fields to replay | ✅ Resolved |
| 7 | `tests/testthat/_snaps/` not in PR 2 write surface list | ✅ Resolved |
| 8 | PR 1 helper correctness has no automated gate | ✅ Resolved |
| 9 | Changelog path deviates from existing phase convention | ✅ Resolved |

All 9 issues from Pass 1 are resolved. The plan has been substantially improved: the Level A/B detection rule now correctly uses `calib_entry$parameters$targets_from_reference` only, the in-loop calibration replay explicitly enumerates all fields, and the PR 1 smoke test has been added.

---

### New Issues

#### Section: PR 2 — NPS bootstrap implementation

---

**Issue 10: REQUIRED — Test spec Block 7 contradicts the plan's Level A/B detection correction; TDD step 1 conflicts with TDD step 4**

Severity: REQUIRED
Violates: Internal plan consistency; testing-standards.md §2 (tests must verify what they claim to verify)

The test spec (`test-spec-nps-bootstrap.md`) Block 7, which the plan's TDD step 1 instructs to write verbatim, reads:

```r
level_a_result <- create_bootstrap_weights(data, type="quasi-randomization",
  replicates=30L, seed=77L,
  reference_sample = ref_fixed)  # fixed reference; forces Level A behavior
```

The comment `# fixed reference; forces Level A behavior` is incorrect per Issue 2's resolution. Level A/B detection depends solely on `calib_entry$parameters$targets_from_reference`. Passing `reference_sample` does NOT change the detection outcome — `make_nps_level_b()` data has `targets_from_reference = TRUE` in its rake history regardless of what `reference_sample` is passed. Both "Level A" and "Level B" calls would run Level B.

The plan's TDD step 4 explicitly contradicts step 1 on this point:
> "Do NOT use `reference_sample` to "force Level A" — `reference_sample` does not affect Level A/B detection."

A builder who follows step 1 literally will write a test that claims to compare Level A vs. Level B but actually compares two Level B runs with different reference samples. The test might pass for the wrong reason (different references produce different results), meaning the Level B implementation could be broken and the test would not catch it.

The plan's step 4 is correct: Block 7 should compare `make_nps_level_a()` output (rake without `reference_design`) vs. `make_nps_level_b()` output (rake with `reference_design`) at the same seed. The test spec has not been updated to match.

Options:
- **[A]** Update `test-spec-nps-bootstrap.md` Block 7 to use `make_nps_level_a()` vs. `make_nps_level_b()` at the same seed (no `reference_sample` override). Add a note in TDD step 1: "Write all blocks from `test-spec-nps-bootstrap.md` verbatim **except Block 7**, which is superseded by the corrected design in TDD step 4." — Effort: low, Risk: none, Impact: test correctly distinguishes Level A from Level B.
- **[B]** Add a note in TDD step 1 only (don't update the test spec). — Effort: trivial, Risk: low (builder must read both step 1 and step 4); Impact: same correctness, slightly less clear.
- **[C] Do nothing** — builder writes a Block 7 test that doesn't test Level B correctness; Level B could be silently broken and the test passes anyway.

**Recommendation: A** — The test spec is the tester's standalone input. If it contains an incorrect test, update it; don't rely on cross-references to the plan to override it.

---

**Issue 11: REQUIRED — `test-replicate-weights.R` has a breaking `mse = FALSE` test that the plan doesn't address**

Severity: REQUIRED
Violates: Plan acceptance criterion "devtools::check() 0 errors, 0 warnings" and the plan statement "do not touch that file; just confirm it still passes"

`tests/testthat/test-replicate-weights.R` line 159–165 contains:

```r
test_that("create_bootstrap_weights() mse = FALSE is stored in history", {
  skip_if_not_installed("svrep")
  td     <- make_taylor_design(seed = 1)
  result <- create_bootstrap_weights(td, replicates = 20L, mse = FALSE, seed = 1L)
  ...
  expect_false(history[[1L]]$parameters$mse)
})
```

After the `mse` API change (`logical(1)` → `character(1)`), `mse = FALSE` is a logical scalar, which triggers `surveywts_error_mse_not_character` before any work is done. This test will error at the `create_bootstrap_weights()` call. The plan says "do not touch that file; just confirm it still passes" — but this test cannot pass after the change.

Additionally, the assertion `expect_false(history[[1L]]$parameters$mse)` is testing the old API semantics (logical FALSE stored in history). After the change, prob-sample types store `mse_logical = FALSE` (derived from `mse_logical <- mse == "mse"` when `mse = "uncentered"`), so the assertion value is still correct — but the call needs to change from `mse = FALSE` to `mse = "uncentered"`.

No other `create_bootstrap_weights()` calls in `test-replicate-weights.R` use explicit `mse = TRUE/FALSE`. The `mse = TRUE` references at lines 119, 382, 536, 710, 879, 1045 are for direct `svrep` / `survey` backend calls, not `create_bootstrap_weights()` calls.

Options:
- **[A]** Add `tests/testthat/test-replicate-weights.R` to the PR 2 write surface. Update line 162 from `mse = FALSE` to `mse = "uncentered"`. The assertion `expect_false(history[[1L]]$parameters$mse)` remains correct because `mse_logical <- ("uncentered" == "mse") = FALSE`. — Effort: trivial (one line change), Risk: none, Impact: existing tests pass after mse API change.
- **[B] Do nothing** — `devtools::check()` fails due to this test; PR 2 cannot pass CI.

**Recommendation: A**

---

**Issue 12: SUGGESTION — Column naming convention for partially-failed bootstrap runs is implicit**

Severity: SUGGESTION
Principle: engineering-preferences.md — explicit over clever

The plan's `.quasi_randomization_bootstrap()` structure says "Add repwt_1...repwt_B columns to data@data." When `failed_draws > 0`, fewer than `B` columns are stored. The naming convention — sequential from `repwt_1` to `repwt_{draws_used}`, not sparse by original draw index — can be inferred from Block 10 (`@variables$repweights == c("repwt_1", ..., "repwt_10")` for a call with `replicates=10L`) but is not explicitly stated in the plan body.

A builder who stores sparse columns (e.g., `repwt_1`, `repwt_3`, `repwt_5` when draws 2 and 4 failed) would pass the happy-path tests but fail the `EC1` test description ("20 repwt columns present (up to draw failures)") and produce confusing gaps in column names.

Options:
- **[A]** Add one sentence to the "Assemble output" step: "Columns are named sequentially from `repwt_1` to `repwt_{draws_used}` — not indexed by original draw number (failed draws leave no gap)." — Effort: trivial.
- **[B]** Leave implicit — inferrable from Block 10 if builder reads the test spec carefully. — Risk: low.

**Recommendation: A** — One sentence eliminates any ambiguity about sparse vs. dense naming.

---

## Summary (Pass 2)

| Severity | Count |
|---|---|
| BLOCKING | 0 |
| REQUIRED | 2 |
| SUGGESTION | 1 |

**Total new issues:** 3

**Overall assessment:** All blocking issues from Pass 1 are resolved. The plan is substantially improved and the core algorithm is now correctly specified. Two required issues remain: Block 7 in the test spec still uses the incorrect `reference_sample` override approach that was fixed in the plan (needs test spec update), and one existing test will break when `mse = FALSE` hits the new error check (needs one-line fix in `test-replicate-weights.R`). Both are low-effort. After resolving Issues 10–11, the plan is ready to implement.
