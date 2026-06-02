## Plan Review: replicate — Pass 1 (2026-05-04)

_No prior passes._

---

### New Issues

#### Section: PR Map

**Issue 1: PR dependency ordering not stated**
Severity: BLOCKING
Violates `github-strategy.md` branching model; creates an unworkable multi-author
merge scenario.

PRs 2–9 all modify `R/replicate-weights.R` and/or
`tests/testthat/test-replicate-weights.R`. The PR Map shows each branching from
`develop` but gives no explicit ordering. If a developer cuts PR 3 before PR 2 is
merged, `create_bootstrap_weights()` and the five shared helpers don't exist in the
branch, and `test-replicate-weights.R` will conflict on merge. The same cascade
applies to PRs 4–9.

Options:
- **[A]** Add a "Dependencies" row to the PR Map table stating that each PR must be
  merged in numeric order before the next is cut. Effort: low, Risk: low, Impact:
  prevents broken branches.
- **[B]** Restructure to use a single long-running feature branch (diverges from the
  project's one-PR-per-logical-unit policy). Effort: high, Risk: medium.
- **[C] Do nothing** — Implementer discovers ordering at the first merge conflict.

**Recommendation: A** — One sentence in the PR Map prevents confusion.

---

#### Section: PR 1 — Shared Infrastructure

**Issue 2: `devtools::document()` missing from every PR commit step**
Severity: REQUIRED
Violates `r-package-conventions.md`: "Run `devtools::document()` before committing
any file that changes roxygen2 content."

Every PR (1–9) adds or modifies files with roxygen2 annotations: new exported
functions (PRs 2–9), the `.format_history_step()` switch case addition (PR 1), and
the S7 method registration (PR 8). None of the commit steps include
`devtools::document()`. NAMESPACE and man/ will be out of sync.

Options:
- **[A]** Add `devtools::document()` as an explicit step before `git add` in each
  PR's commit sequence. Also add a check that NAMESPACE changes are staged. Effort:
  low, Risk: low, Impact: keeps NAMESPACE and man/ in sync throughout.
- **[B]** Add a single note at the top of the plan saying "run `devtools::document()`
  before every commit." Effort: low, Risk: medium (easy to miss when following the
  per-PR steps).
- **[C] Do nothing** — devtools::check() will warn, but CI could still fail or
  report stale man/ pages.

**Recommendation: A** — Add it explicitly to each PR's commit step.

**Issue 3: Changelog entries absent from every PR**
Severity: REQUIRED
Violates `github-strategy.md`: "Changelog entry format (required before every PR)
is defined in `.claude/skills/changelog-workflow.md`."

None of the nine PRs mention creating a changelog entry. The quality gate at the
bottom mentions NEWS.md but only as part of release prep, not per-PR changelogs.

Options:
- **[A]** Add a changelog step (following the `changelog-workflow` skill) to each
  PR's commit sequence. Effort: low, Risk: low.
- **[B] Do nothing** — Changelogs are added ad-hoc before the release PR.

**Recommendation: A**

**Issue 4: DESCRIPTION task doesn't explicitly state removing `svrep` from Suggests**
Severity: SUGGESTION
Risk of partial edit.

The current DESCRIPTION has `svrep (>= 0.6)` in Suggests. Task 1.2 shows the target
Imports block (which includes `svrep (>= 0.6.0)`) and the target Suggests block
(which omits it), but the prose says only "Move `svrep` and `withr` from `Suggests`
to `Imports`." An implementer editing the DESCRIPTION mechanically might add the
Imports entries without removing the Suggests entry, creating a duplicate.

Options:
- **[A]** Add an explicit step: "Remove `svrep` from Suggests and `withr` from
  Suggests before adding them to Imports." Effort: low.
- **[B] Do nothing** — `devtools::check()` will warn about a package in both
  Imports and Suggests.

**Recommendation: A**

---

#### Section: PR 2 — Bootstrap + Shared Helpers

**Issue 5: `as_taylor_design()` runtime bug — character column names passed to NSE arguments**
Severity: BLOCKING
Will fail at runtime on first `as_taylor_design()` call.

The plan's `as_taylor_design()` implementation (PR 9) calls:

```r
surveycore::as_survey(
  clean_data,
  ids     = source_vars$ids,
  strata  = source_vars$strata,
  weights = source_vars$weights,
  fpc     = source_vars$fpc,
  nest    = isTRUE(source_vars$nest)
)
```

`source_vars$ids`, `source_vars$strata`, etc. are **character strings** (column
names stored in history), e.g. `"psu_id"`. But `surveycore::as_survey()` uses
tidy-select / NSE for these arguments — the test helper shows bare names:
`surveycore::as_survey(df, ids = psu_id, strata = stratum, weights = base_weight)`.
Passing a character string to a tidy-select argument does not work the same way
as a bare name; it will not resolve to a column selection.

The equivalence test (spec §XIII 15b, "original design structure preserved") will
catch this if it's written, but the bug is in the plan itself.

Options:
- **[A]** Resolve stored character names to symbols before passing: use
  `rlang::sym()` and inject with `!!` if `surveycore::as_survey()` uses
  `rlang::enquo()`. First, check `surveycore::as_survey()`'s internals to confirm
  it supports programmatic calls via `!!rlang::sym(col_name)`. Alternatively, use
  `do.call()` with a constructed argument list if the function accepts character
  strings via a non-NSE path. Effort: medium, Risk: low once verified.
- **[B]** Store column names as symbols or quosures in the history entry at creation
  time (brittle; quosures don't serialize cleanly). Effort: high, Risk: high.
- **[C] Do nothing** — Discovered at runtime during PR 9 testing.

**Recommendation: A** — Verify `surveycore::as_survey()` internals and document
the correct programmatic call pattern before implementation begins.

**Issue 6: `source_class` construction in `.snapshot_variables_for_history()` is fragile**
Severity: REQUIRED
Silent failure mode in `as_taylor_design()`.

The plan constructs:
```r
source_class = paste0(attr(cls, "package"), "::", cls@name)
```

where `cls = S7::S7_class(data)`. If `attr(cls, "package")` returns `NULL` for
S7 classes from `surveycore` (which it may, depending on how S7 sets this attribute
at install time), the result is `"::survey_nonprob"` instead of
`"surveycore::survey_nonprob"`. The check in `as_taylor_design()` uses
`identical(source_class, "surveycore::survey_nonprob")`, which would then silently
fail — permitting nonprob-sourced replicates to be converted to Taylor designs
(exactly the scenario the spec blocks in §X).

Options:
- **[A]** Store a boolean instead of a string:
  `is_nonprob = S7::S7_inherits(data, surveycore::survey_nonprob)`. The
  `as_taylor_design()` check becomes `isTRUE(last_creation$source_design$is_nonprob)`.
  This is guaranteed to work, is consistent with how every other class check in
  the package is written, and doesn't depend on `attr()` behavior. Effort: low,
  Risk: low.
- **[B]** Verify that `attr(S7::S7_class(surveycore::survey_nonprob()), "package")`
  reliably returns `"surveycore"` via a REPL check, and document the finding.
  Keep the string approach if verified. Effort: low, Risk: medium (still fragile
  across surveycore releases).
- **[C] Do nothing** — Relies on undocumented S7 attribute behavior.

**Recommendation: A** — Boolean is simpler, safer, and consistent with the rest of
the codebase.

**Issue 7: Multiple required spec test blocks absent from the plan**
Severity: REQUIRED
Violates spec §XIII; the plan will not satisfy the Quality Gate (§XV).

The following test blocks are in the spec's test plan but have no corresponding
test in any PR:

| Missing block | Spec ref | Where it belongs |
|---|---|---|
| Bootstrap default `replicates = 500` produces correct column count | 1b | PR 2 |
| Different `type` values produce different results | 1c | PR 2 |
| `mse = FALSE` passes through correctly | 1d | PR 2 |
| JKn delete-1 equivalence with `survey::as.svrepdesign(type="JKn")` | 4Eb | PR 3 |
| Random-groups equivalence with `svrep::as_random_group_jackknife_design()` | 4Ec | PR 3 |
| `tau = "auto"` produces non-negative replicate weights | 9c | PR 5 |
| `balanced = FALSE` may produce fewer replicates than `balanced = TRUE` | 10c | PR 6 |
| Gen-rep equivalence with `svrep::as_fays_gen_rep_design()` | 10Xa | PR 6 |
| SDR equivalence with `svrep::as_sdr_design()` | 11Ea | PR 7 |

Nine of the spec's required test blocks — including two equivalence tests that pin
the numerical backends — are absent.

Options:
- **[A]** Add each missing test block to its corresponding PR's "write failing tests"
  step. Effort: medium (writing the tests is straightforward; they mirror the
  existing equivalence pattern from PR 2). Risk: low.
- **[B] Do nothing** — Tests are added during post-PR coverage review.

**Recommendation: A** — These are spec requirements, not optional coverage fill-ins.

**Issue 8: Shared error paths 13a, 13c, 13d missing for 5 of 6 functions**
Severity: REQUIRED
Spec §XIII block 13 says "Each `create_*_weights()` …" — meaning all six.

The plan tests all four shared error paths (13a–13d) for bootstrap only. For
jackknife, only the `survey_replicate` rejection (13b) is present. For BRR,
gen-boot, gen-rep, and SDR: zero shared error tests.

Missing tests:
- `data.frame` input (13a) for jackknife, BRR, gen-boot, gen-rep, SDR
- `weighted_df` input (13c) for all five
- Unsupported class input (13d) for all five

Options:
- **[A]** Add the missing shared error tests to each function's PR. Each is a
  2-line test block (one `expect_error`, one `expect_snapshot`). Effort: low.
- **[B] Do nothing** — Shared helpers cover these paths; coverage may still reach
  98% via bootstrap's tests.

**Recommendation: A** — The spec is explicit: "each `create_*_weights()`" means
all six. Coverage via one function is insufficient — the tests also verify that
each function calls `.validate_replicate_input()`.

**Issue 9: `test_invariants()` missing from the whole-number coercion test**
Severity: REQUIRED
Violates `testing-surveywts.md`: "every `test_that()` block that creates a survey
object must call `test_invariants(obj)` as its first assertion."

The test `"create_bootstrap_weights() accepts whole-number replicates coerced
silently"` creates a `survey_replicate` but calls no invariants. All other happy
path tests in the plan correctly call `test_invariants()`.

Options:
- **[A]** Add `test_invariants(result)` as the first assertion in that test block.
  Effort: trivial.
- **[B] Do nothing** — The object will be structurally valid if it was created;
  the test only checks replicate count.

**Recommendation: A**

**Issue 10: `.format_history_step()` format string missing `type` parameter**
Severity: REQUIRED
Will produce incorrect snapshot output and fail the spec's print example.

The spec §X.5 example shows:
```
1. replicate_creation (method = "bootstrap", type = "Rao-Wu-Yue-Beaumont", replicates = 500)
```

The plan's `"replicate_creation"` switch case only produces:
```
replicate_creation (method = "bootstrap", replicates = 50)
```

`entry$parameters$type` (which stores `"Rao-Wu-Yue-Beaumont"` for bootstrap,
`"JK1"` / `"JKn"` for jackknife, etc.) is never used. The snapshot tests in PR 8
will record — and lock in — the incorrect abbreviated format.

Note: not every method has a `type` sub-parameter (BRR uses `rho`, SDR has none).
The format string needs method-aware conditionals.

Options:
- **[A]** Extend the format case to include `params$type` when present:
  ```r
  type_str <- if (!is.null(params$type)) paste0(", type = \"", params$type, "\"") else ""
  paste0("replicate_creation (method = \"", method_str, "\"", type_str,
         if (!is.null(n_rep)) paste0(", replicates = ", n_rep), ")")
  ```
  Effort: low.
- **[B]** Update the spec §X.5 example to remove `type` from the format. Effort:
  low, but loses useful information for users inspecting history.
- **[C] Do nothing** — Snapshot tests will record whatever format the code produces;
  it will diverge from the spec example.

**Recommendation: A**

---

#### Section: PR 3 — Jackknife

_No additional issues beyond those in Issue 7 (missing 4Eb, 4Ec) and Issue 8
(missing 13a, 13c, 13d)._

---

#### Section: PR 4 — BRR

_No additional issues beyond Issue 8 (missing 13a, 13c, 13d for BRR)._

---

#### Section: PR 5 — Generalized Bootstrap

_No additional issues beyond Issue 7 (missing 9c) and Issue 8 (missing 13a, 13c,
13d)._

---

#### Section: PR 6 — Generalized Replication

_No additional issues beyond Issue 7 (missing 10c, 10Xa) and Issue 8 (missing 13a,
13c, 13d)._

---

#### Section: PR 7 — SDR

_No additional issues beyond Issue 7 (missing 11Ea) and Issue 8 (missing 13a, 13c,
13d)._

---

#### Section: PR 8 — Print Method

_No additional issues._

---

#### Section: PR 9 — Dispatcher + `as_taylor_design()`

**Issue 11: `withCallingHandlers()` used directly in warning snapshot test**
Severity: REQUIRED
Violates `testing-standards.md`: "Do NOT use `withCallingHandlers()` or
`tryCatch()` in tests."

The `"as_taylor_design() already_taylor warning snapshot"` test wraps the call in
`withCallingHandlers(...)` with `invokeRestart("muffleWarning")`. The correct
pattern for testing a warning is `expect_warning(result <- ..., class = "...")`.
For snapshot testing a warning message, the standard approach is
`expect_snapshot(expect_warning(result <- ..., class = "..."))` or
`expect_snapshot(suppressWarnings(as_taylor_design(td)))` depending on intent.

Options:
- **[A]** Replace with `expect_snapshot(expect_warning(as_taylor_design(td), class = "surveywts_warning_already_taylor"))`. Effort: trivial.
- **[B] Do nothing** — The test will pass but teaches the wrong pattern.

**Recommendation: A**

---

#### Section: Post-PR — Coverage and Release Prep

**Issue 12: Spec §XIII edge cases (19a–19f) treated as optional; they are required**
Severity: BLOCKING
Contradicts spec §XIII and §XV Quality Gate.

The plan places test blocks 19a–19f under "Post-PR: Coverage and Release Prep" with
the condition "add edge-case tests if coverage is below 98%." This makes them
optional coverage fill-ins. But the spec §XIII lists them as required test blocks
with the same standing as any other numbered block, and §XV Quality Gate item 4
says "All §XIII test blocks (1–19) are implemented and passing" — not "1–18 plus
maybe 19."

The edge cases in 19a–19f test backend-error propagation (Q16), which is a spec
guarantee. Without them, the package ships with untested boundary behavior.

Options:
- **[A]** Allocate the 19a–19f blocks to specific PRs: 19a with PR 2 (bootstrap),
  19b with PR 3 (jackknife), 19c with PR 4 (BRR), 19d with PR 5 (gen-boot), 19e
  with PR 6 (gen-rep), 19f with PR 7 (SDR). Remove them from the post-PR section
  entirely. Effort: medium.
- **[B]** Create a PR 10 specifically for edge cases before the release PR. Remove
  the "if coverage is below 98%" conditionality. Effort: medium.
- **[C] Do nothing** — Tests are added if CI drops below 95%.

**Recommendation: A** — Edge cases belong in the same PR as the function they test.
This is consistent with how PR 2 already tests bootstrap-specific error paths.

---

#### Section: General (Cross-Cutting)

**Issue 13: Spec §II.a pseudocode contradicts the Critical Implementation Note**
Severity: REQUIRED
Will confuse future contributors reading the spec.

Spec §II.a step 4 says: "Converts the result back to surveycore via
`surveycore::from_svydesign()`." The plan's Critical Note documents that
`from_svydesign()` has a verified bug in v0.8.2 that leaves `@variables$repweights`
NULL, and bypasses it entirely with a manual construction. The plan is correct; the
spec is not.

The spec should be updated to:
1. Note the `from_svydesign()` bug
2. Document the manual construction approach as the authoritative implementation
   (not just a plan-level note)

Options:
- **[A]** Update `plans/spec-replicate.md` §II.a to replace the `from_svydesign()`
  pseudocode with the manual construction, and add a note explaining the bypass.
  Effort: low.
- **[B] Do nothing** — The plan's Critical Note is clear enough; the spec stays
  inconsistent.

**Recommendation: A**

---

#### Section: Suggestions (no spec violations; worth fixing before coding)

**Issue 14: Missing boundary test for bootstrap `replicates = 1`**
Severity: SUGGESTION
`engineering-preferences.md`: "handle more edge cases, not fewer."

The spec says ≥ 2. The plan tests `replicates = 0` but not `replicates = 1`. Both
should error with `surveywts_error_replicates_not_positive`. The boundary value 1
is a natural test case.

Options:
- **[A]** Add `create_bootstrap_weights(td, replicates = 1L)` test alongside the
  existing `replicates = 0` test. Effort: trivial.
- **[B] Do nothing** — min_val = 2 logic covers it; the 0 test proves the path.

**Recommendation: A**

**Issue 15: Missing boundary test for SDR `replicates = 3`**
Severity: SUGGESTION
Same rationale as Issue 14. SDR uses `min_val = 4L`. Testing `replicates = 0` is
not the boundary — `replicates = 3` is.

Options:
- **[A]** Add `create_sdr_weights(td, replicates = 3L)` test. Effort: trivial.
- **[B] Do nothing**

**Recommendation: A**

---

## Summary (Pass 1)

| Severity | Count |
|---|---|
| BLOCKING | 3 |
| REQUIRED | 9 |
| SUGGESTION | 3 |

**Total issues:** 15

**Overall assessment:** The plan's architecture and code are generally sound — the
shared helpers are well-designed, the PR sequencing is logical, and the Critical
Implementation Note correctly identifies and bypasses a real bug. However, the plan
cannot be handed to an implementer as-is: the `as_taylor_design()` NSE bug (Issue 5)
and the `source_class` fragility (Issue 6) will produce silent failures, the edge
case tests are misclassified as optional (Issue 12), and nine required test blocks
from the spec are simply missing (Issues 7, 8, 9, 10, 11). Resolve the three
BLOCKING issues and the nine REQUIRED issues before implementation begins.

---

## Plan Review: replicate — Pass 2 (2026-05-04)

### Prior Issues (Pass 1)

| # | Title | Status |
|---|---|---|
| 1 | PR dependency ordering not stated | ✅ Resolved |
| 2 | `devtools::document()` missing from every PR commit step | ✅ Resolved |
| 3 | Changelog entries absent from every PR | ✅ Resolved |
| 4 | DESCRIPTION task doesn't explicitly state removing `svrep` from Suggests | ✅ Resolved |
| 5 | `as_taylor_design()` runtime bug — character column names passed to NSE arguments | ✅ Resolved |
| 6 | `source_class` construction in `.snapshot_variables_for_history()` is fragile | ✅ Resolved |
| 7 | Multiple required spec test blocks absent from the plan | ✅ Resolved |
| 8 | Shared error paths 13a, 13c, 13d missing for 5 of 6 functions | ✅ Resolved |
| 9 | `test_invariants()` missing from the whole-number coercion test | ✅ Resolved |
| 10 | `.format_history_step()` format string missing `type` parameter | ✅ Resolved |
| 11 | `withCallingHandlers()` used directly in warning snapshot test | ✅ Resolved |
| 12 | Spec §XIII edge cases (19a–19f) treated as optional; they are required | ✅ Resolved |
| 13 | Spec §II.a pseudocode contradicts the Critical Implementation Note | ✅ Resolved |
| 14 | Missing boundary test for bootstrap `replicates = 1` | ✅ Resolved |
| 15 | Missing boundary test for SDR `replicates = 3` | ✅ Resolved |

All 15 Pass 1 issues are resolved. The spec pseudocode (§II.a step 4) now reads "Manually constructs `survey_replicate` from the backend output" and the plan uses `rlang::inject()` / `rlang::sym()` for `as_taylor_design()` NSE, boolean `is_nonprob` flag, and explicit `devtools::document()` in every commit step.

---

### New Issues

#### Section: PR 1 — Shared Infrastructure

**Issue 16: `surveywts_error_unsupported_class` missing from `plans/error-messages.md`**
Severity: REQUIRED
Violates `code-style.md`: "The canonical list of all classes is in `plans/error-messages.md`. When adding a new error or warning: 1. Add a row to `plans/error-messages.md` first."

Task 1.3 adds 14 error classes and 2 warning classes to `plans/error-messages.md`. But the implementation uses a fifteenth class — `surveywts_error_unsupported_class` — in two places:
1. `.validate_replicate_input()` (the third branch, for objects that are not `survey_base` subclasses)
2. `as_taylor_design()` (for non-replicate, non-taylor input)

Tests in PRs 2–9 reference this class (e.g., `"create_bootstrap_weights() rejects unsupported class"`). Since the class is neither in the Task 1.3 table nor the existing error-messages.md, `devtools::check()` will not fail, but the error-class-auditor CI check — if configured — will flag it. More practically, there is no canonical `plans/error-messages.md` entry, violating the project's error-class workflow.

Options:
- **[A]** Add `surveywts_error_unsupported_class` to the Task 1.3 table in `plans/error-messages.md`. One row: `| \`surveywts_error_unsupported_class\` | All \`create_*_weights()\`, \`as_taylor_design()\` | Input class is not a supported survey design type |`. Effort: trivial.
- **[B] Do nothing** — The class works; the docs are just inconsistent.

**Recommendation: A**

---

#### Section: PR 8 — Print Method

**Issue 17: Print method tests placed in `test-replicate-weights.R` instead of `test-replicate-print.R`**
Severity: REQUIRED
Violates `testing-standards.md`: "Every source file in `R/` has a corresponding test file in `tests/testthat/`. One-to-one is the floor."

PR 8 creates `R/replicate-print.R` (a new source file) but places its four snapshot tests by appending to `tests/testthat/test-replicate-weights.R`. There is no `tests/testthat/test-replicate-print.R`. The one-to-one rule is explicit and has no exception for simple files (only `R/utils.R` is excepted via a documented justification in the file mapping table).

Placing print tests in `test-replicate-weights.R` creates a test file whose name misleads readers: `test-replicate-weights.R` sounds like it tests `replicate-weights.R`, but after PR 8 it also tests `replicate-print.R`.

Options:
- **[A]** Change PR 8's file list to create `tests/testthat/test-replicate-print.R` (new) instead of modifying `test-replicate-weights.R`. Move the four snapshot tests there. Effort: low.
- **[B]** Keep the current placement and add a comment at the top of `test-replicate-weights.R` explaining that print tests live there. Update the file mapping in `testing-surveywts.md`. Effort: low, Risk: medium (breaks the one-to-one invariant permanently).
- **[C] Do nothing** — Tests still run; the file naming is just wrong.

**Recommendation: A**

---

#### Section: PRs 2–9 (Cross-Cutting)

**Issue 18: Widespread `test_invariants()` missing from equivalence tests and secondary happy-path tests**
Severity: REQUIRED
Violates `testing-surveywts.md`: "Every `test_that()` block that creates a `weighted_df` or `survey_nonprob` object must call `test_invariants(obj)` as its first assertion." The updated `test_invariants()` in the plan extends this to `survey_replicate` objects (Step 3, Task 1.4).

The following test blocks create `survey_replicate` objects but do not call `test_invariants()`:

| PR | Test name | Objects missing check |
|---|---|---|
| 2 | `"preserves metadata through conversion"` | `result` |
| 2 | `"matches svrep::as_bootstrap_design() directly"` | `result` |
| 2 | `"default replicates = 500 produces 500 columns"` | `result` |
| 2 | `"Rao-Wu and Rao-Wu-Yue-Beaumont differ"` | `r1`, `r2` |
| 2 | `"mse = FALSE is stored in history"` | `result` |
| 3 | `"delete-1 matches survey::as.svrepdesign(JK1)"` | `result` |
| 3 | `"JKn delete-1 matches survey::as.svrepdesign(JKn)"` | `result` |
| 3 | `"random-groups matches svrep::as_random_group_jackknife_design()"` | `result` |
| 4 | `"matches survey::as.svrepdesign(BRR) directly"` | `result` |
| 5 | `"variance_estimator SD2 differs from SD1"` | `r1`, `r2` |
| 5 | `"tau = 'auto' produces non-negative weights"` | `result` |
| 5 | `"matches svrep::as_gen_boot_design() directly"` | `result` |
| 6 | `"max_replicates limits count"` | `result` |
| 6 | `"balanced = FALSE may produce fewer replicates"` | `balanced`, `unbalanced` |
| 6 | `"matches svrep::as_fays_gen_rep_design() directly"` | `result` |
| 7 | `"sort_var changes result"` | `r1`, `r2` |
| 7 | `"matches svrep::as_sdr_design() directly"` | `result` |
| 9 | `"passes ... to underlying function"` | `result` |

18 test blocks affected across 8 PRs. The pattern is consistent: happy-path primary tests and edge-case `all-equal` tests correctly call `test_invariants()`, but equivalence tests and parameter-variation tests do not. Calling `test_invariants()` first in equivalence tests is especially important — it ensures the conversion pipeline produced a valid object before comparing numerical values.

Options:
- **[A]** Add `test_invariants(result)` (or `test_invariants(r1)` / `test_invariants(r2)`) as the first assertion in each of the 18 affected test blocks. Effort: low (one-line addition per block).
- **[B] Do nothing** — Object validity is implicitly checked when the numerical extraction `result@data[, result@variables$repweights]` does not error.

**Recommendation: A** — Structural validity should be explicit; "doesn't crash" is not the same as "valid."

---

**Issue 19: `as_taylor_design()` fails when source design has no explicit cluster IDs**
Severity: REQUIRED
Silent failure mode for legitimate survey designs.

The `as_taylor_design()` implementation does:
```r
ids_sym     <- rlang::sym(source_vars$ids)
weights_sym <- rlang::sym(source_vars$weights)
```

`rlang::sym()` requires a non-NULL character string. If the source `survey_taylor` was created with `ids = NULL` (a simple random sample with no cluster structure), `source_vars$ids` is `NULL`, and `rlang::sym(NULL)` throws:
```
Error in rlang::sym(NULL) : argument must be a character string, not NULL
```

This is an uninformative error that points to internals, not the user's input. The optional arguments (`strata`, `fpc`) already have NULL guards:
```r
if (!is.null(source_vars$strata)) optional$strata <- rlang::sym(source_vars$strata)
```
But `ids` does not. Every test in PR 9 uses a design with `ids = psu_id` or `ids = id`, so this is not caught by the test suite.

Options:
- **[A]** Add a NULL guard for `ids`, matching the pattern used for `strata`/`fpc`. When `source_vars$ids` is NULL, omit `ids` from the `rlang::inject()` call (or pass `ids = rlang::sym("1")` to produce a `~1` formula equivalent). Add a test: `create_bootstrap_weights(srs_no_ids_design, ...)` followed by `as_taylor_design(rep)` where `srs_no_ids_design` uses `ids = NULL`. Effort: low.
- **[B]** Document that `as_taylor_design()` requires the source design to have explicit cluster IDs. Add an upfront validation error if `source_vars$ids` is NULL. Effort: low, Risk: low — but may surprise users who created plain SRS designs.
- **[C] Do nothing** — Users hit an unhelpful `rlang::sym(NULL)` error.

**Recommendation: A** — The NULL guard is a two-line fix; the SRS test adds a useful round-trip validation.

---

**Issue 20: `surveywts-conventions.md` not updated with new `@family` groups**
Severity: REQUIRED
Violates the conventions document's own scope and the general rule of keeping reference docs in sync with implementation.

The plan introduces two new `@family` tags used across PRs 2–9:
- `@family replicate-weights` — used by all six `create_*_weights()` functions
- `@family conversion` — used by `create_replicate_weights()` and `as_taylor_design()`

Neither family appears in `.claude/rules/surveywts-conventions.md` Section 2 (Function Families). The document's header says `**Version:** 1.0 — Calibration API complete`, confirming it covers only Calibration. The Replicate phase adds new exported functions with new `@family` groupings, but no PR lists `.claude/rules/surveywts-conventions.md` as a file to update.

Additionally, the `@family conversion` grouping for `create_replicate_weights()` is debatable — since it is a dispatcher that creates replicate weights, it could plausibly belong to `@family replicate-weights` instead. This choice should be explicit in the conventions document, not left implicit.

Options:
- **[A]** Add a step to PR 1 (or PR 2, when the first `@family replicate-weights` function is introduced) to update `.claude/rules/surveywts-conventions.md` Section 2 with the two new family rows: `replicate-weights` (all six `create_*_weights()` + `create_replicate_weights()`) and document the decision on whether `as_taylor_design()` belongs to `conversion` or `replicate-weights`. Effort: low.
- **[B] Do nothing** — roxygen2 generates the see-also links regardless; the conventions doc is stale but code works.

**Recommendation: A** — The conventions file is a decision log, not auto-generated. Leaving it stale defeats its purpose.

---

#### Section: PR 5 — Generalized Bootstrap

**Issue 21: `create_gen_boot_weights()` missing boundary test for `replicates = 1`**
Severity: SUGGESTION
`engineering-preferences.md`: "handle more edge cases, not fewer."

The fix for bootstrap Issue 14 added a `replicates = 1L` test (boundary of the ≥ 2 requirement). Gen-boot uses the same `.validate_replicates_arg(min_val = 2L)` logic. PR 5 tests `replicates = 0L` but not `replicates = 1L`. The tightest failing value is 1, not 0.

Options:
- **[A]** Add `create_gen_boot_weights(td, replicates = 1L)` test alongside the existing `replicates = 0L` test. Effort: trivial.
- **[B] Do nothing** — The `replicates = 0` test covers the validation path.

**Recommendation: A**

---

## Summary (Pass 2)

| Severity | Count |
|---|---|
| BLOCKING | 0 |
| REQUIRED | 5 |
| SUGGESTION | 1 |

**Total new issues:** 6

**Overall assessment:** Pass 1 resolved every issue — the plan is substantially better. The remaining required issues are all mechanical: one missing error class in the docs table, one wrong test file location, one widespread pattern of missing `test_invariants()` calls (18 test blocks, one-line fix each), one NULL guard in `as_taylor_design()`, and one stale conventions document. None of these require architectural rethinking. Resolve Issues 16–20 (all REQUIRED) and the plan is ready for `/r-implement`.
