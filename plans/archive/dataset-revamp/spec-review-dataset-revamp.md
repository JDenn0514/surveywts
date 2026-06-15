## Spec Review: dataset-revamp — Pass 1 (2026-06-14)

### New Issues

---

#### Section: III.4 — acs_wy_2022_svy construction

**Issue 1: Replicate weight selector is ambiguous and will include the main weight column**
Severity: REQUIRED

The spec proposes using `dplyr::starts_with("pwgtp")` as the `repweights`
selector in `as_survey_replicate()`. This selector will match BOTH `pwgtp`
(the main person weight) AND `pwgtp1`–`pwgtp80` (the replicate weights),
because `"pwgtp"` is a prefix of `"pwgtp"` itself. Including the main weight
as a replicate will produce incorrect variance estimates silently.

The spec flags this as a risk but leaves it unresolved. The spec must specify
the exact selector.

Options:
- **[A]** Use `grep("^pwgtp[0-9]", names(acs_wy_2022), value = TRUE)` to produce
  a character vector of replicate column names; pass as `repweights = dplyr::all_of(rep_cols)`.
  Effort: low, Risk: low, Impact: correct variance, Maintenance: none.
- **[B]** Use `matches("^pwgtp[0-9]+")` as a tidy-select selector in the
  `repweights` argument.
  Effort: low, Risk: low, Impact: same correctness, Maintenance: none.
- **[C] Do nothing** — leaves an implementation-time ambiguity that will
  silently produce wrong variance if the wrong selector is used.

**Recommendation: [A]** — using a pre-computed character vector is explicit
and verifiable; less reliance on tidy-select behavior inside `as_survey_replicate`.

---

#### Section: III.7 — ns_wave1 column count

**Issue 2: ncol ambiguity — gender overwritten vs. new column**
Severity: REQUIRED

The spec says `ns_wave1` carries "all 171 original columns" plus "4 derived
columns," which implies 175 total. But the spec also says `gender` is
"overwritten in-place" (the existing integer column is replaced with a factor).
If `gender` is overwritten (not added), the total is 174 (171 + 3 new cols:
`age_group`, `race_ethn`, `educ`).

The test-spec asserts `ncol(ns_wave1) == 171 + 4`, which contradicts the
in-place overwrite description. One of the two must be wrong.

Options:
- **[A]** Overwrite `gender` in-place (integer → factor). Total cols = 174.
  The spec's "4 derived columns" language is misleading — correct to
  "3 new columns + 1 overwritten column." Fix test-spec to `171 + 3`.
  Effort: low, Risk: low, Impact: accurate test.
- **[B]** Add a NEW `gender` factor column alongside the original integer
  column. Requires renaming one of them (e.g., `gender_raw` for the integer,
  `gender` for the factor). Total = 175. More columns, but retains the raw
  integer for reference.
  Effort: low, Risk: low, Impact: slightly larger tibble.
- **[C] Do nothing** — the test-spec will fail on column count.

**Recommendation: [A]** — consistent with the old `ns_wave1_ipw` script which
overwritten `gender` in-place; minimizes columns; the raw integer is implicit
from the factor levels.

---

#### Section: V.2 — acs_wy_2022 codoc requirement

**Issue 3: 80 replicate weight columns require individual \\item{} entries**
Severity: REQUIRED

The spec flags as a GAP that `codoc` may require 80 individual `\item{pwgtpN}`
entries in the `@format \describe{}` block, but leaves the resolution open.
Without a concrete direction, the builder may write only a grouped entry and
the build will fail with a `codoc` warning.

Options:
- **[A]** Write 80 individual terse `\item{}` entries:
  `\item{pwgtp1}{ACS PUMS successive-difference replicate weight 1.}` through
  `\item{pwgtp80}{... weight 80.}`. Mechanical but `codoc`-compliant.
  Effort: low (can be done with text substitution), Risk: low.
- **[B]** Use a group notation in roxygen2 markdown:
  `\item{pwgtp1, pwgtp2, ..., pwgtp80}{ACS PUMS successive-difference replicate
  weights for variance estimation.}` — but `codoc` reads the item names
  literally and may not match multi-name items. Risky.
- **[C] Do nothing** — `codoc` warning blocks CI.

**Recommendation: [A]** — required for R CMD check compliance. The spec must
specify "80 individual `\item{}` entries" and builder generates them with
a simple text pattern.

---

#### Section: VII — ipw.R examples, acs_wy_2022 replacement

**Issue 4: ipw() example with ACS reference needs explicit construction**
Severity: REQUIRED

The spec says to replace the old `acs_ipw_ref` (survey_taylor) with
`acs_wy_2022_svy` (survey_replicate), but then notes that `acs_wy_2022_svy`
can't be passed to `ipw()`. The spec recommends constructing a simple Taylor
design inline but doesn't specify the exact code for the example.

The builder needs a concrete example block to insert. Without it, the example
section is under-specified.

Options:
- **[A]** Show inline construction in `@examples`:
  ```r
  data(acs_wy_2022)
  acs_ref <- surveycore::as_survey(acs_wy_2022, weights = pwgtp)
  result_acs <- ipw(
    ns_wave1,
    acs_ref,
    selection = ~gender + age_group + race_ethn + educ,
    missing_method = "omit"
  )
  ```
  Effort: low, Risk: low, Impact: clear and runnable.
- **[B]** Remove the ACS example entirely.
  Effort: low, Risk: low, Impact: fewer examples.
- **[C] Do nothing** — builder has to guess.

**Recommendation: [A]** — demonstrating inline construction teaches users
how to use `acs_wy_2022` tibble with `ipw()`, which is an important workflow.

---

#### Section: Test-spec — ns_wave1 ncol

**Issue 5: test-spec ncol assertion contradicts spec intent**
Severity: REQUIRED

The test-spec asserts `ncol(ns_wave1) == 171 + 4` but (per Issue 2 resolution)
the correct total is `171 + 3` if `gender` is overwritten in-place.

Options:
- **[A]** Fix to `ncol(ns_wave1) == 174` after resolving Issue 2 with Option A.
- **[C] Do nothing** — test fails on column count.

**Recommendation: [A]** — resolves with Issue 2.

---

#### Section: Test-spec — acs_wy_2022_svy incompatibility with ipw()

**Issue 6: no test for ipw() rejecting survey_replicate input**
Severity: SUGGESTION

The spec documents that `acs_wy_2022_svy` (survey_replicate) cannot be passed
to `ipw()`. There is no test asserting this. A test would lock in the
expected error class.

Options:
- **[A]** Add test: `expect_error(ipw(ns_wave1, acs_wy_2022_svy, selection = ~gender), class = "surveywts_error_svydesign_not_taylor")`
  Effort: minimal, Risk: none, Impact: prevents regression if ipw() input
  validation is ever relaxed without updating docs.
- **[C] Do nothing** — existing ipw() input validation tests cover this.

**Recommendation: [A]** — lightweight and directly validates the documented
API constraint.

---

### Summary (Pass 1)

| Severity | Count |
|---|---|
| BLOCKING | 0 |
| REQUIRED | 5 |
| SUGGESTION | 1 |

**Total issues:** 6

**Overall assessment:** The spec is nearly complete. Five REQUIRED issues cover
implementation ambiguities that would cause build failures (codoc), silent bugs
(repweight selector), or test failures (ncol assertion). None are blocking
architectural decisions — all can be resolved with small, unambiguous fixes.
One HOLD (#1, weight column choice) is deferred to the user.

---

## Stage 3r Resolution Log (2026-06-14)

| Issue | Disposition | Action taken |
|---|---|---|
| 1 — repweights selector | ✅ Resolved (A) | Spec §III.4 updated with `grep` approach |
| 2 — ns_wave1 ncol | ✅ Resolved (A) | Spec §III.7 clarified; in-place overwrite → 174 cols |
| 3 — acs codoc 80 items | ✅ Resolved (A) | Spec §V.2 updated: 80 individual items required |
| 4 — ipw ACS example | ✅ Resolved (A) | Spec §VII: inline `as_survey(acs_wy_2022, weights = pwgtp)` pattern |
| 5 — test-spec ncol | ✅ Resolved (A) | test-spec fixed to `== 174` |
| 6 — ipw() rejects survey_replicate | ✅ Resolved (A) | test-spec: `expect_error(..., class = "surveywts_error_svydesign_not_taylor")` |

HOLD #1 (weight column for gss/npors svy objects): OPEN — see `decisions-dataset-revamp.md`.
