# Spec Review: ipw-replicate-ref — Pass 1 (2026-06-24)

## New Issues

### Lens 1 — DRY

No issues found. Single function modified, single error table, no duplicated
validation patterns.

---

### Lens 2 — Test Completeness

**Issue 1: `test-datasets.R:317–324` test inverts the new happy path — not in write surface**
Severity: REQUIRED

`tests/testthat/test-datasets.R` contains the test block:

```r
test_that("acs_wy_2022_svy cannot be passed to ipw() — throws correct error", {
  data(ns_wave1)
  data(acs_wy_2022_svy)
  expect_error(
    ipw(ns_wave1, acs_wy_2022_svy, selection = ~sex + age_f3),
    class = "surveywts_error_svydesign_not_taylor"
  )
})
```

After this PR:
1. The test *description* is wrong — `acs_wy_2022_svy` CAN be passed to `ipw()`.
2. The `expect_error(class = "surveywts_error_svydesign_not_taylor")` will fail —
   the call succeeds instead of erroring.
3. The retired class name appears as a dead assertion.

The spec write surface lists `tests/testthat/test-nonprob-ipw.R` but not
`tests/testthat/test-datasets.R`. This test will break after the PR.

Fix: Add `tests/testthat/test-datasets.R` to the write surface. The builder
replaces the block with a happy-path assertion:

```r
test_that("acs_wy_2022_svy can be passed directly to ipw()", {
  data(ns_wave1)
  data(acs_wy_2022_svy)
  result <- ipw(ns_wave1, acs_wy_2022_svy, selection = ~sex + age_f3)
  test_invariants(result)
  expect_true(S7::S7_inherits(result, surveycore::survey_nonprob))
})
```

Options:
- **[A]** Add `test-datasets.R` to write surface and replace the block — Effort: low, Risk: low
- **[B]** Leave it out of scope and let CI catch it — Effort: zero now, Risk: high (certain CI failure)
- **[C]** Do nothing — CI fails.

**Recommendation: A**

---

### Lens 3 — Contract Completeness

No issues. Tier 3 stated. All parameter docs, error table, examples, and
`@references` changes specified. `data.R` added to write surface in Stage 2.
`surveywts_error_reference_not_survey_design` flagged for addition to
`plans/error-messages.md`. ✓

---

### Lens 4 — Edge Cases

No issues. All edge case scenarios covered: BRR zeros in replicate columns (EC-1),
zero main weight (E-5), NA in reference selection variables (W-1), absent variable
(EC-3), absent factor level (EC-4), wt_name conflict (EC-2), NULL/list/survey_nonprob
reference inputs (E-2–E-4). ✓

---

### Lens 5 — Engineering Level

No under- or over-engineering. Minimal change: one `||` added to the type check
guard. The retired error class is used only in `ipw()`, `test-nonprob-ipw.R`,
`test-datasets.R`, and archived plan files — confirmed by grep. No other active
code paths throw it. ✓

---

### Lens 6 — API Coherence & User Expectations

No issues. The return class (`survey_nonprob`) is unchanged regardless of reference
class. The `reference_design` history field correctly preserves the full
`survey_replicate` object with its replicate columns. The documentation accurately
describes V_p availability without promising tooling that does not yet exist. ✓

---

## Summary (Pass 1)

| Severity | Count |
|---|---|
| BLOCKING | 0 |
| REQUIRED | 1 |
| SUGGESTION | 0 |

**Total issues:** 1

**Overall assessment (Pass 1):** One REQUIRED finding; applied as Stage 3r fix.

---

## Stage 3r Resolution

**Issue 1 — resolved.** Applied Option A:
- `plans/spec-ipw-replicate-ref.md` "Out" section: removed stale note claiming
  `data.R` was out of scope (already corrected in Stage 2); replaced
  with accurate statement of scope boundary.
- `plans/spec-ipw-replicate-ref.md` "Files touched": added
  `tests/testthat/test-datasets.R` entry specifying that the error test at
  lines 317–324 must be replaced with a happy-path assertion.

**Mini-pass (Lens 2 only):** Write surface now covers all three test-file
locations that reference `surveywts_error_svydesign_not_taylor` or the
`survey_replicate` reference path:
- `test-nonprob-ipw.R` (lines 369, 384) — in write surface ✓
- `test-datasets.R` (line 322) — now in write surface ✓

No other files reference the retired class (confirmed by prior grep). ✓

**Verdict after Stage 3r:** PASS — 0 BLOCKING, 0 unresolved REQUIRED findings.

---

## Spec Review: ipw-replicate-ref — Pass 2 (2026-06-24)

### Prior Issues (Pass 1)

| # | Title | Status |
|---|---|---|
| 1 | `test-datasets.R:317–324` test inverts the new happy path — not in write surface | ✅ Resolved |

---

### New Issues

#### Section: test-spec — Profile Gates

**Issue 2: Stale profile gate references deleted dataset**
Severity: REQUIRED

The `devtools::run_examples()` gate in `plans/test-spec-ipw-replicate-ref.md`
(lines 175–176) reads:

```
- [ ] `devtools::run_examples()` — all `@examples` run clean, including the
      updated ACS PUMS example using `acs_wy_2022_svy` directly
```

Part C deletes `acs_wy_2022_svy` from the package entirely. After this PR, no
such example exists anywhere in `R/`. The description would direct the tester
to look for an ACS PUMS example that has been intentionally removed, causing
confusion about whether the profile gate actually passed.

The correct description should reference the CPS 2023 example that replaces it.

Options:
- **[A]** Update the gate description to: `devtools::run_examples()` — all `@examples` run clean, including the updated `ipw()` example using `cps_2023` directly as a `survey_replicate` — Effort: low, Risk: low, Impact: tester clarity
- **[B]** Do nothing — Effort: zero now, Risk: medium (tester confusion on a passing gate)

**Recommendation: A**

---

#### Section: test-spec — Per-function test plan → H-R5 fixture construction

**Issue 3: H-R5 inline `survey_replicate` fixture construction not specified**
Severity: SUGGESTION

H-R5 in the test-spec specifies:

> Inline `survey_replicate` constructed from `make_nps_reference()@data` | Replicate reference fixture — wraps the same data as the Taylor fixture so weights are oracle-comparable

The `Datasets` section labels this "inline" but does not show the construction
code or specify which `type`, `scale`, or `rscales` to pass to
`as_survey_replicate()`. For H-R5 only the main weight matters (replicate
weights are not used by `ipw()`), so any valid replicate configuration is
acceptable — but the tester/builder has to infer this.

Options:
- **[A]** Add a one-block example of the fixture construction to the `Datasets` section — Effort: low, Risk: low
- **[B]** Leave implicit — "inline" signals builder discretion — Effort: zero, Risk: low (likely inferrable)

**Recommendation: B** — The note "wraps the same data as the Taylor fixture so weights are oracle-comparable" conveys the intent. H-R5's only invariant is that main weights are identical; the builder can choose any valid `type`/`rscales`. This is builder-level detail rather than spec-level.

---

#### Section: Part B — `cps_2023` `@format` / codoc exemption claim

**Issue 4: codoc exemption claim for S7 objects should be verified**
Severity: SUGGESTION

The spec states: "Because `cps_2023` is an S7 object — not a plain `data.frame`
— the codoc check does not apply, so the 160 `repwtp*` columns can be described
as a group."

This claim is correct for R CMD check's standard codoc path (which calls
`colnames()` on the data object). For an S7 object, `colnames()` returns `NULL`
unless explicitly defined. However, R CMD check's behavior with S7-classed `.rda`
files is not definitively documented, and if codoc traverses `@data` to extract
column names, the 160 undocumented `repwtp*` columns would produce a WARNING.

The profile gate (`R CMD check --as-cran`) catches this if it fires. The risk is
that a builder who does not run `--as-cran` locally before opening the PR misses
it.

Options:
- **[A]** Builder verifies codoc behavior by running `R CMD check --as-cran`
  before merging — Effort: already required by profile gate, Risk: none
- **[B]** Add an explicit note in the spec: "verify codoc does not check S7 object
  slots during `R CMD check --as-cran`" — Effort: low, Risk: none
- **[C]** Do nothing — the profile gate catches it — Effort: zero

**Recommendation: C** — The profile gate already requires `R CMD check --as-cran`.
No additional spec language needed.

---

### Summary (Pass 2)

| Severity | Count |
|---|---|
| BLOCKING | 0 |
| REQUIRED | 1 |
| SUGGESTION | 2 |

**Total new issues:** 3

**Overall assessment (Pass 2):** One REQUIRED finding (stale profile gate description referencing a deleted dataset); two suggestions that are builder-discretion level. The spec is implementable as written — the REQUIRED issue is a test-spec cosmetic fix.

**Verdict:** PASS after resolving Issue 2.

---

## Stage 3r Resolution (Pass 2)

**Issue 2 — resolved.** Applied Option A:
- `plans/test-spec-ipw-replicate-ref.md` profile gate updated: replaced
  "the updated ACS PUMS example using `acs_wy_2022_svy` directly" with
  "the updated `ipw()` example using `cps_2023` directly as a `survey_replicate`".

Issues 3 and 4 — accepted as-is (Recommendation: B and C respectively).

**Verdict after Stage 3r (Pass 2):** PASS — 0 BLOCKING, 0 unresolved REQUIRED findings.
