# Plan Review: ipw-replicate-ref — Pass 1 (2026-06-24)

### New Issues

#### Section: PR Map

No issues found. Single-PR directive matches the spec's stated `PR range: PR 1
(single PR)` and the "optional" pipeline-split annotation.

---

#### Section: PR 1 — ipw() type widening + cps_2023 conversion + ACS removal

---

**Issue 1: Changelog entry missing from file list**
Severity: REQUIRED
[Violates stage-1-draft.md template: "changelog/{phase-name}/feature-[name].md
— created last, before opening PR"]

The file list for PR 1 does not include a changelog entry. The
`changelog/propensity/` directory already exists (contains `feature-ipw.md`,
`fix-ipw-gee-nleqslv.md`, etc.). An entry for this PR must be listed and
created before opening the PR.

Options:
- **[A]** Add `changelog/propensity/feature-ipw-replicate-ref.md` to the file
  list in PR 1, with the note "created last, before opening PR" — Effort: low,
  Risk: low, Impact: plan is complete per template
- **[B]** Do nothing — changelog entry gets forgotten; CI doesn't check for it
  but the PR review process will catch the omission

**Recommendation: A** — One line to add; no ambiguity.

---

**Issue 2: `survey_replicate` fixture construction recipe is underspecified**
Severity: REQUIRED
[Acceptance criterion H-R1 through H-R5 and EC-1 all require an inline
`survey_replicate` fixture; the plan says "inline `survey_replicate` constructed
from `make_nps_reference()@data`" but does not specify how replicate weight
columns are added]

`make_nps_reference()@data` contains columns `age_group`, `sex`, `education`,
`region`, `base_weight` — no replicate weight columns. `as_survey_replicate()`
requires existing replicate weight columns to be named in `repweights`. Without
a concrete recipe, the implementor must guess:

- How many replicate columns to generate (arbitrary)
- How to generate them (arbitrary — BRR zeros? scaled copies? random?)
- Which `surveycore` constructor call to use

The H-R5 test (Taylor vs replicate weight equality) is sensitive to this: both
designs must have identical main weights, but the replicate columns are
irrelevant to the point estimate. Any construction that produces a valid
`survey_replicate` with the same `base_weight` will satisfy H-R5.

Options:
- **[A]** Add a concrete fixture recipe to the PR 1 Notes section:
  ```r
  # Get the underlying data frame from the Taylor fixture
  ref_df <- make_nps_reference(n = 1000L, seed = 99L)@data
  # Add 10 synthetic BRR-style replicate columns (0 or 2*w per half-sample)
  n <- nrow(ref_df)
  set.seed(42)
  repmat <- matrix(
    sample(c(0, 2), n * 10L, replace = TRUE) * ref_df$base_weight,
    nrow = n, ncol = 10L
  )
  colnames(repmat) <- paste0("repwt", 1:10)
  ref_data_with_reps <- cbind(ref_df, repmat)
  # survey_replicate fixture
  ref_replicate <- surveycore::as_survey_replicate(
    data       = ref_data_with_reps,
    weights    = "base_weight",
    repweights = paste0("repwt", 1:10),
    type       = "bootstrap",
    scale      = 1 / 10,
    rscales    = rep(1, 10)
  )
  # survey_taylor fixture (same data, same main weight — for H-R5 oracle)
  ref_taylor <- surveycore::survey_taylor(
    data      = ref_df,
    variables = list(weights = "base_weight")
  )
  ```
  For EC-1 (BRR zeros), zero out some replicate columns in `repmat`:
  ```r
  repmat[1:100, c(1, 3, 5)] <- 0  # partial zeros, all main weights still positive
  ```
  Effort: low, Risk: low, Impact: implementor has unambiguous fixture code

- **[B]** Leave construction implicit — implementor figures it out
  Effort: zero, Risk: medium (implementation inconsistency between tests), Impact: none

**Recommendation: A** — Concrete recipe prevents guessing and ensures H-R5
oracle comparison is set up correctly.

---

**Issue 3: Coverage criterion ambiguity between 95% and 98%**
Severity: SUGGESTION
[testing-standards.md target is 98%; CI block is 95%; both values appear in
the plan without clarification]

The acceptance criteria states `covr::package_coverage() ≥ 95%` and the test-spec
profile gate says the same (`>= 95%`). However, `testing-standards.md` defines
98%+ as the project coverage target. Both numbers are correct in their context
(95% = CI block, 98% = internal target) but having only 95% in the acceptance
criteria implies 95% is sufficient.

Options:
- **[A]** Expand the criterion to:
  `covr::package_coverage() ≥ 95% (CI block; internal target 98%); confirm Behavior Rule 2 branch for survey_replicate is covered`
  Effort: low, Risk: low, Impact: implementor knows both thresholds
- **[B]** Leave at 95% — matches the CI block; 98% is a project-level aspiration
  not enforced per-PR

**Recommendation: A** — Makes the two thresholds explicit rather than relying on
the implementor to know the project target from a separate document.

---

**Issue 4: E-2 error path fixture underspecified**
Severity: SUGGESTION
[Acceptance criteria E-2 requires a `survey_nonprob` object as `reference`;
no fixture recipe given]

The helper file `tests/testthat/helper-test-data.R` already has
`make_nonprob_no_repweights()` which returns a `survey_nonprob` with no
replicate weights. This is exactly the fixture needed for E-2. The plan should
reference it explicitly so the implementor doesn't write a redundant fixture or
use `make_nonprob_replicate_design()` (wrong — that has repweights).

Options:
- **[A]** Add to PR 1 Notes: "E-2 fixture: use `make_nonprob_no_repweights()`
  from `helper-test-data.R`. This returns a `survey_nonprob` from `ipw()` only,
  with no replicate weights — the simplest `survey_nonprob` to pass as
  `reference`."
  Effort: trivial, Risk: none, Impact: saves 5 minutes of implementor confusion
- **[B]** Leave implicit — implementor will find it via grep

**Recommendation: A** — The helper is obscure enough to warrant a pointer.

---

## Summary (Pass 1)

| Severity | Count |
|---|---|
| BLOCKING | 0 |
| REQUIRED | 2 |
| SUGGESTION | 2 |

**Total issues:** 4

**Overall assessment:** The plan is structurally sound — correct file order,
single PR matches the spec directive, all spec sections are covered, and the
major acceptance criteria are verifiable. Two REQUIRED items need resolution
before handing off: the changelog entry must be added to the file list, and
the `survey_replicate` fixture construction needs a concrete recipe so H-R1
through H-R5 and EC-1 tests are unambiguous to implement.

---

## Plan Review: ipw-replicate-ref — Pass 2 (2026-06-24)

### Prior Issues (Pass 1)

| # | Title | Status |
|---|---|---|
| 1 | Changelog entry missing from file list | ✅ Resolved |
| 2 | `survey_replicate` fixture construction recipe is underspecified | ✅ Resolved |
| 3 | Coverage criterion ambiguity between 95% and 98% | ✅ Resolved |
| 4 | E-2 error path fixture underspecified | ✅ Resolved |

### New Issues

No new issues found.

---

## Summary (Pass 2)

| Severity | Count |
|---|---|
| BLOCKING | 0 |
| REQUIRED | 0 |
| SUGGESTION | 0 |

**Total issues:** 0

**Verdict: PASS** — All prior issues resolved. Plan is complete and ready to
hand off to `/r-implement`.
