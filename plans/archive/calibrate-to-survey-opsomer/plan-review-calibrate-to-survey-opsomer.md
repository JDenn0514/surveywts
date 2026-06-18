## Plan Review: calibrate-to-survey-opsomer — Pass 1 (2026-06-17)

---

### New Issues

#### Section: PR Map

No issues found.

---

#### Section: PR 1 — New signature + validation + test helpers

---

**Issue 1: Changelog entry absent from PR 1 file list and acceptance criteria**
Severity: REQUIRED
Violates stage-1-draft.md file-list template (`changelog/{phase-name}/feature-[name].md` — created last, before opening PR)

Neither PR 1 nor PR 2 lists a changelog entry in the file list or acceptance
criteria. The `changelog/` directory exists with existing subdirectories
(`calibration`, `calibration-framework`, `replicate`, etc.). A new subdirectory
`changelog/calibrate-unit-scale/` exists from a prior feature — there is no
`calibration-opsomer/` or similar. The implementor has no guidance on which
subdirectory to use or what filename to create.

Options:
- **[A]** Add `changelog/calibration/feature-cts-opsomer.md` to both PR 1 and
  PR 2 file lists and acceptance criteria — Effort: low, Risk: low, Impact:
  satisfies workflow requirement, Maintenance: none
- **[B] Do nothing** — PR will be missing the changelog artifact; shipper will
  catch it but implementor has to guess.

**Recommendation: A** — Add the changelog file to both PR file lists.

---

**Issue 2: PR 2 svrep-to-Suggests is BLOCKING due to `calibrate_to_estimate.R`** *(BLOCKING)*
Severity: BLOCKING
Violates spec scope and R package conventions

The plan's PR 2 includes "DESCRIPTION — move svrep from `Imports` to `Suggests`"
and an acceptance criterion: "svrep in Suggests."

However, `calibrate_to_estimate.R:414` calls `.to_svyrep(design)` and line 426
calls `.method_to_calfun(method)` — both defined in `calibrate_to_survey.R` —
and line 450 calls `.svrep_calibrate_to_estimate()` which directly invokes
`svrep::calibrate_to_estimate()`. These are unconditional svrep calls. Moving
svrep to Suggests without wrapping these in `requireNamespace()` guards would
produce a hard R CMD check ERROR on any machine where svrep is not installed.

The spec's "Out" section explicitly excludes "Changes to `calibrate_to_estimate()`",
so adding namespace guards there is out of scope for this PR range.

Options:
- **[A]** Keep svrep in `Imports` for this PR range. Remove the DESCRIPTION
  change and the "svrep in Suggests" acceptance criterion from PR 2. Document in
  NEWS.md that `calibrate_to_survey()` no longer uses svrep but the package
  still imports it for `calibrate_to_estimate()` — Effort: low, Risk: low,
  Impact: spec goal deferred; no user-visible breakage, Maintenance: a future
  PR can complete the demotion once `calibrate_to_estimate()` is also updated
- **[B]** Include wrapping `calibrate_to_estimate()`'s svrep calls in namespace
  guards in PR 2 — expands scope beyond the spec's "Out" exclusion — Effort:
  medium, Risk: medium (changes calibrate_to_estimate behavior), Impact: achieves
  spec goal immediately
- **[C] Do nothing** — PR 2 fails R CMD check; implementor hits a hard blocker.

**Recommendation: A** — Keep svrep in Imports for this PR range. The spec's
"Out" exclusion makes Option B out of scope. Update PR 2 to remove the DESCRIPTION
change and the related criterion; add a note that the svrep demotion is deferred.

---

**Issue 3: `.to_svyrep()` and `.method_to_calfun()` must be moved, not deleted**
Severity: REQUIRED
Violates spec architecture and R package dependency correctness

The PR 2 notes say: "Remove `.to_svyrep()`, `.svrep_calibrate_to_sample()`,
`.method_to_calfun()` if they are not shared with `calibrate_to_estimate.R`.
(Check first — `calibrate_to_estimate.R` uses its own path.)"

The check has been done: `calibrate_to_estimate.R:414` calls `.to_svyrep()` and
`:426` calls `.method_to_calfun()`. These are currently defined in
`calibrate_to_survey.R`. In PR 2, when `calibrate_to_survey.R` removes its svrep
delegation, `.to_svyrep()` and `.method_to_calfun()` MUST be relocated (not
deleted) — either kept in `calibrate_to_survey.R` or moved to `calibrate-utils.R`.

The plan leaves this as an open question ("check first") which would force the
builder to investigate at implementation time. The answer is now known: move them
to `calibrate-utils.R`.

Options:
- **[A]** Update PR 2 notes to explicitly state: "Move `.to_svyrep()` and
  `.method_to_calfun()` to `calibrate-utils.R` (they are still needed by
  `calibrate_to_estimate.R`). Add `calibrate-utils.R` to the PR 2 file list.
  `.svrep_calibrate_to_sample()` is specific to `calibrate_to_survey.R` and
  can be deleted once the delegation is removed" — Effort: low, Risk: low,
  Impact: prevents a hard R CMD check failure in PR 2, Maintenance: none
- **[B] Do nothing** — Builder discovers the constraint at implementation time;
  may incorrectly delete the functions or leave them duplicated.

**Recommendation: A** — Add explicit relocation instruction and add
`calibrate-utils.R` to the PR 2 file list.

---

**Issue 4: Mock mechanism for "svrep not called" test is unspecified**
Severity: REQUIRED
Violates testing-standards.md (test assertions must be objectively verifiable)

The plan requires a gotcha test: "Mock `.calibrate_engine()` to throw; confirm
no error is raised from any valid call" and "Mock `svrep::calibrate_to_sample`
to throw an error; confirm no error is raised from any valid call." The plan does
not specify the mocking mechanism. In testthat 3, the idiomatic approach is
`testthat::local_mocked_bindings()`. Without specifying this, the builder may
use `mockery::mock` (a separate package not in DESCRIPTION) or an incorrect
pattern.

Options:
- **[A]** Add a note to PR 2: "Use `testthat::local_mocked_bindings()` to mock
  `.svrep_calibrate_to_sample` (or its replacement after deletion). After PR 2,
  the function no longer exists, so the test should instead mock
  `svrep::calibrate_to_sample` directly and confirm the result is returned
  without calling it. Alternatively, confirm no call is made by checking that
  the result equals the expected output computed without svrep." — Effort: low,
  Risk: low, Impact: removes ambiguity, Maintenance: none
- **[B] Do nothing** — Builder guesses the mechanism; may introduce a new
  package dependency or use a pattern incompatible with testthat 3.

**Recommendation: A** — Add explicit mocking mechanism to PR 2 notes.

---

#### Section: PR 2 — Opsomer algorithm + svrep removal + tests + documentation

---

**Issue 5: `.calibrate_replicate_opsomer()` from the spec is not named in the plan**
Severity: REQUIRED
Violates spec Architecture §Functions added (internal)

The spec's Architecture section lists three new internal functions:
- `.validate_targets_for_opsomer()` — listed in PR 1 ✅
- `.compute_control_totals()` — listed in PR 2 ✅
- `.calibrate_replicate_opsomer()` — **not mentioned by name in the plan**

The plan describes the per-replicate calibration logic (step 7) inline in the
PR 2 notes, but does not instruct the builder to create `.calibrate_replicate_opsomer()`
as a named internal function. The spec requires it to exist as a separately
named helper (it calibrates a single primary replicate to combined perturbed +
fixed targets using `.calibrate_engine()`).

Options:
- **[A]** Add `.calibrate_replicate_opsomer()` to PR 2's "functions added
  (internal)" section and implementation notes, with its contract: takes a
  single primary replicate weight vector, perturbed control totals, and fixed
  targets; calls `.calibrate_engine()`; returns the calibrated weight vector —
  Effort: low, Risk: low, Impact: satisfies spec, Maintenance: none
- **[B]** Leave the per-replicate logic inline in the main function body —
  violates the spec but works — Effort: none, Risk: low, Impact: spec divergence
  that will be flagged in tester audit
- **[C] Do nothing** — Builder may not create the function; tester's audit will
  BLOCK.

**Recommendation: A** — Name the function explicitly in the plan.

---

**Issue 6: PR 1 coverage requirement absent**
Severity: SUGGESTION
Violates testing-standards.md (coverage ≥ 95% required)

PR 2 has `covr::package_coverage() ≥ 95%` in acceptance criteria. PR 1 does not.
PR 1 adds new validation helpers (`.check_control_levels()`,
`.validate_targets_for_opsomer()`) and new argument handling — code that must be
covered by the error-path tests in PR 1. A coverage drop in PR 1 might mask a
gap that isn't caught until PR 2.

Options:
- **[A]** Add `covr::package_coverage() ≥ 95%` to PR 1 acceptance criteria —
  Effort: low, Risk: low, Impact: catches coverage regressions early
- **[B] Do nothing** — Coverage checked only in PR 2; brief gap acceptable.

**Recommendation: A** — Add the criterion; the error-path tests should cover the
new validation code fully.

---

**Issue 7: `@param bounds` svrep-specific note should be removed in PR 2**
Severity: SUGGESTION
Violates function-documentation.md (docs should reflect current behavior)

The current `@param bounds` docs include: "Note: per-unit `bounds_scale` is not
supported; use scalar bounds only." This note was svrep-specific — it referred to
svrep's `calibrate_to_sample()` API. After PR 2 removes svrep delegation, this
note is wrong (`.calibrate_engine()` doesn't have a `bounds_scale` concept at
all). The plan does not mention updating this note.

Options:
- **[A]** Add to PR 2 notes: "Update `@param bounds` to remove the svrep-specific
  `bounds_scale` note. Replace with a description matching `.calibrate_engine()`'s
  bounds behavior." — Effort: low, Risk: low, Impact: accurate docs
- **[B] Do nothing** — The stale note persists in the docs post-PR-2.

**Recommendation: A** — Include in the PR 2 documentation update.

---

## Summary (Pass 1)

| Severity | Count |
|---|---|
| BLOCKING | 1 |
| REQUIRED | 4 |
| SUGGESTION | 2 |

**Total issues:** 7

**Overall assessment:** One blocker (svrep-to-Suggests is unachievable without
modifying `calibrate_to_estimate()` which is out of scope) must be resolved before
handing off; four required fixes are low-effort clarifications (changelog files,
function relocation, mock mechanism, named function). The plan is structurally
sound and can be fixed in a single resolve pass.

---

## Plan Review: calibrate-to-survey-opsomer — Pass 2 (2026-06-17)

### Prior Issues (Pass 1)

| # | Title | Status |
|---|---|---|
| 1 | Changelog entry absent from both PRs | ✅ Resolved — `changelog/calibration/feature-cts-opsomer-{pr}.md` added to both PRs' file lists and acceptance criteria |
| 2 | svrep-to-Suggests BLOCKING due to `calibrate_to_estimate.R` | ✅ Resolved — svrep stays in Imports; DESCRIPTION change removed from PR 2; decision documented in plan header |
| 3 | `.to_svyrep()` and `.method_to_calfun()` must be moved, not deleted | ✅ Resolved — PR 2 notes now explicitly state: move to `calibrate-utils.R`; `calibrate-utils.R` added to PR 2 file list |
| 4 | Mock mechanism unspecified | ✅ Resolved — `testthat::local_mocked_bindings()` specified in PR 2 notes with fallback `withr::defer` pattern |
| 5 | `.calibrate_replicate_opsomer()` not named in PR 2 | ✅ Resolved — function named explicitly in PR 2 implementation notes with its contract |
| 6 | PR 1 coverage requirement absent | ✅ Resolved — `covr::package_coverage() ≥ 95%` added to PR 1 acceptance criteria |
| 7 | `@param bounds` stale note not flagged for removal | ✅ Resolved — PR 2 documentation notes now include explicit instruction to remove the svrep-specific bounds note |

### New Issues

No new issues found. The plan is ready to hand off to `/pipeline-ship`.

---

## Summary (Pass 2)

| Severity | Count |
|---|---|
| BLOCKING | 0 |
| REQUIRED | 0 |
| SUGGESTION | 0 |

**Total issues:** 0

**Overall assessment:** All 7 issues from Pass 1 are resolved. The plan is
PLAN_READY.
