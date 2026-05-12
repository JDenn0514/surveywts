## Plan Review: rake-anesrake-port — Pass 1 (2026-05-11)

### New Issues

#### Section: PR 1 — Acceptance Criteria

**Issue 1: Parity tests are missing `skip_if_not_installed("anesrake")` — plan falsely claims guards exist**
Severity: BLOCKING
Violates: testing-standards.md §4 (`skip_if_not_installed` must be block-level, not assumed)

The plan's Implementation Notes state: "The existing parity test already contains
`skip_if_not_installed('anesrake')` inside the block per project testing standards."

This is factually incorrect. Inspecting `tests/testthat/test-03-rake.R` (lines 1453–1539),
none of the five parity tests have a `skip_if_not_installed("anesrake")` guard:

```
line 1453: test_that("rake(method='anesrake') weights match direct anesrake::anesrake() call (type='prop')"
line 1471: test_that("rake(method='anesrake', type='count') correctly converts counts to proportions"
line 1490: test_that("rake(method='anesrake', cap=NULL) substitutes anesrake's default cap of 5"
line 1506: test_that("rake(method='anesrake') passes explicit cap to anesrake::anesrake()"
line 1521: test_that("rake(method='anesrake') passes custom control params to anesrake::anesrake()"
```

Each calls `anesrake::anesrake()` via `.call_anesrake_direct()` or directly. After Step 11
moves `anesrake` from `Imports` to `Suggests`, CI environments that do not install `Suggests`
packages will throw `Error: there is no package called 'anesrake'` on these tests rather than
skipping them cleanly.

The plan has no step to add `skip_if_not_installed("anesrake")` to these tests.

Options:
- **[A]** Add Step 2b: before touching any implementation, add `skip_if_not_installed("anesrake")` inside all five parity tests at lines 1453, 1471, 1490, 1506, 1521. This is a test-only change on top of the already-required cap=NULL update (Step 2). Effort: low, Risk: low, Impact: prevents CI breakage after Suggests move.
- **[B]** Combine into Step 2: expand Step 2 scope to also add `skip_if_not_installed` guards to all five parity tests (not just rename/flip the cap=NULL test). Effort: low, Risk: low, Impact: same.
- **[C] Do nothing** — CI will fail with an error (not a skip) on systems that don't install Suggests. The plan's false claim would mislead the implementer.

**Recommendation: [B]** — Fold the guard additions into Step 2 since both are test-only changes that happen before any implementation. Cleaner than a separate step.

---

**Issue 2: `.call_anesrake_direct()` default cap and stale comment not addressed after cap fix**
Severity: REQUIRED
Violates: engineering-preferences.md §5 (explicit over clever — tests should document what they are actually testing)

After the cap=NULL bug fix (Step 9: `%||% 5` → `%||% Inf`), three parity tests at lines
1453, 1471, and 1521 become semantically inconsistent:

1. **Stale comment at line 1465** (inside test #1): `# cap = NULL in rake() → engine substitutes cap = 5 for anesrake (NULL not accepted)`. This comment will be wrong after the fix.

2. **`.call_anesrake_direct()` default `cap = 5`**: Tests #1, #2, and #5 call this helper without specifying `cap`, so the reference uses `cap = 5`. After the fix, our engine uses `cap = Inf` for `cap = NULL`. The tests will likely still pass numerically (because for seeds 50, 51, and 54, raked weights do not reach 5), but they pass by coincidence rather than by correctly specifying the reference behavior.

If anyone later adds a test with a different seed where weights do reach 5, these three parity tests would suddenly fail for the wrong reason.

The plan updates test #3 at line 1490 (Step 2) but does not address updating `.call_anesrake_direct()` or the stale comment in test #1.

Options:
- **[A]** In Step 2, also: (i) update `.call_anesrake_direct()` default from `cap = 5` to `cap = Inf`; (ii) update test #1's stale comment at line 1465 to `# cap = NULL → Inf (no cap)`. The explicit `cap = 3.0` test at line 1506 passes its own cap so is unaffected. Effort: low, Risk: low, Impact: tests correctly document post-fix semantics.
- **[B]** Add a code comment to tests #1, #2, and #5 explaining why cap=5 and cap=Inf produce the same result for these seeds. Leave `.call_anesrake_direct()` unchanged. Effort: low, Risk: low, Impact: preserves the test as a regression guard while explaining why it passes.
- **[C] Do nothing** — Tests pass by coincidence; stale comment misleads future readers.

**Recommendation: [A]** — Updating `.call_anesrake_direct()`'s default to `cap = Inf` is the cleanest fix. It correctly reflects post-fix behavior without relying on implicit dataset properties.

---

**Issue 3: 98% line coverage not listed as acceptance criterion**
Severity: REQUIRED
Violates: testing-standards.md §2 ("PRs that drop coverage below 95% are blocked by CI")

The acceptance criteria for PR 1 do not mention coverage. The new file
`R/rake-anesrake-engine.R` contains multiple ported code paths (S3 dispatch
branches, variable-selection branches, convergence paths) that need coverage.
Per testing-standards.md, the project target is 98%+ and PRs below 95% are
blocked by CI.

Options:
- **[A]** Add criterion: "`devtools::test()` produces ≥ 98% line coverage; no new uncovered lines in `R/rake-anesrake-engine.R`." Effort: minimal, Risk: none, Impact: matches project standard.
- **[B]** Do nothing — CI will catch it, but the implementer won't know to check proactively.

**Recommendation: [A]**

---

**Issue 4: Changelog entry not listed as acceptance criteria or files**
Severity: REQUIRED
Violates: Stage 2 Lens 5 (file completeness — changelog entry required)

The project has a `changelog/` directory with per-feature entries (e.g.,
`changelog/calibration/feature-calibration-rake.md`). The acceptance criteria
and files list do not mention creating a changelog entry for this PR.

Options:
- **[A]** Add to the Files list: `changelog/calibration/feature-calibration-rake-precap.md` (or similar under the current phase). Add a criterion: "Changelog entry written and committed on this branch." Effort: minimal, Risk: none, Impact: completes the required deliverables.
- **[B]** Do nothing — changelog entry would be missed.

**Recommendation: [A]**

---

#### Section: Step 6 — Port `.rake_list()` with pre-cap snapshot

**Issue 5: Pre-loop initialization of `precap_weightvec` is not in the spec**
Severity: SUGGESTION
Violates: spec alignment (Section 1 of spec shows snapshot only inside the convergence loop)

The plan says: "`precap_weightvec` is initialized to `weightvec` before the convergence
loop so it is always defined." The spec's code snippet places `precap_weightvec <- weightvec`
only inside the convergence loop (after the variable sweep, before the capping block) with
no pre-loop initialization.

Since the anesrake convergence loop always executes at least once (it's a `repeat` loop
with an exit condition check at the bottom), the pre-loop initialization is not required
for correctness. Adding it is harmless but is an undocumented deviation from the spec.

Options:
- **[A]** Remove the pre-loop initialization from the implementation notes and confirm the spec's placement (inside the loop) is sufficient. Effort: minimal, Risk: none, Impact: keeps plan aligned with spec.
- **[B]** Retain the pre-loop initialization but add a comment in Step 6 explaining it as defensive (handles hypothetical zero-iteration loop). Effort: minimal, Risk: none, Impact: explicitly justified deviation.
- **[C] Do nothing** — harmless, but leaves an unexplained deviation.

**Recommendation: [B]** — A one-line justification comment in Step 6 prevents future confusion.

---

#### Section: Step 1 — Write failing pre-cap history tests (third test)

**Issue 6: Dataset choice for the "cap fires" test is unverified**
Severity: SUGGESTION

Step 1's third test uses `make_surveywts_data(n = 200, seed = 1)` with `cap = 1.5`.
`make_surveywts_data` generates log-normal base weights with `exp(rnorm(n, 0, 0.4))`,
producing values roughly in [0.5, 2.5]. After raking, whether any normalized weight
exceeds 1.5 depends on the specific targets and seed used. The plan does not verify
that this combination guarantees capping fires.

If `cap = 1.5` does not trigger capping for this dataset, the test's `expect_true(n_capped > 0)`
assertion will fail — but not as a "red TDD test" (it would fail for the wrong reason before
any implementation, since it's testing the data properties, not the code).

Options:
- **[A]** Before finalizing Step 1, run `make_surveywts_data(n = 200, seed = 1)` through the existing raking and verify at least one weight ratio exceeds 1.5. Note in Step 1: "Verified: seed=1 + standard margins produces max weight ratio > 1.5." Effort: low (one R command), Risk: none, Impact: confidence in test validity.
- **[B]** Use an explicit dataset constructed to guarantee capping fires (e.g., severely imbalanced margins) instead of relying on `make_surveywts_data`. Effort: low, Risk: low, Impact: self-documenting test.
- **[C] Do nothing** — discover the problem during Step 1 TDD run.

**Recommendation: [A]** — Verify the choice before writing the test; note it in the plan for reviewers.

---

## Summary (Pass 1)

| Severity | Count |
|---|---|
| BLOCKING | 1 |
| REQUIRED | 3 |
| SUGGESTION | 2 |

**Total issues:** 6

**Overall assessment:** The plan is structurally sound — single PR is well-scoped, TDD order is correct, and the porting approach is faithful to the spec. One blocking issue (missing `skip_if_not_installed` guards that the plan incorrectly claims exist) and one required semantic-correctness issue (stale parity test reference after the cap fix) must be resolved before coding starts. Coverage and changelog criteria are missing but easy to add.
