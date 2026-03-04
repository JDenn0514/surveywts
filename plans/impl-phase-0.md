# Implementation Plan: Phase 0 — Weighting Core (v0.1.0)

**Version:** 1.1
**Date:** 2026-02-27
**Status:** Approved — ready for implementation
**Branch identifier:** `phase-0`
**Spec:** `plans/spec-phase-0.md` (v0.2, fully resolved)

---

## Overview

This plan delivers Phase 0 of surveyweights: the `weighted_df` S3 class,
the `survey_calibrated` S7 class, three calibration functions
(`calibrate()`, `rake()`, `poststratify()`), one nonresponse function
(`adjust_nonresponse()`), and three diagnostics (`effective_sample_size()`,
`weight_variability()`, `summarize_weights()`).

Each user-facing function lives in its own source file. Function-specific
private helpers are co-located with the function that owns them. Helpers
used by two or more source files live in `R/07-utils.R`.

> **Note:** The source file organization below supersedes spec §II, which listed
> all calibration functions in a single `02-calibrate.R`. The per-function split
> adopted here renumbers `nonresponse.R` (was 03, now 05) and `diagnostics.R`
> (was 04, now 06). The `testing-surveyweights.md` update in PR 2 will reflect
> the updated file map.

### Source File Organization

```
R/
├── 00-classes.R         # weighted_df S3 class; survey_calibrated S7 class + validator
├── 01-constructors.R    # .new_survey_calibrated() — internal constructor only
├── 02-calibrate.R       # calibrate()
├── 03-rake.R            # rake() + .parse_margins()
├── 04-poststratify.R    # poststratify() + .validate_population_cells()
├── 05-nonresponse.R     # adjust_nonresponse()
├── 06-diagnostics.R     # effective_sample_size(), weight_variability(),
│                        #   summarize_weights()
├── 07-utils.R           # Shared internal helpers (used by 2+ source files)
├── vendor/
│   ├── calibrate-greg.R # Vendored GREG/logit calibration from survey::calibrate()
│   └── calibrate-ipf.R  # Vendored IPF/raking from survey::rake()
└── surveyweights-package.R
tests/testthat/
├── helper-test-data.R
├── test-00-classes.R
├── test-02-calibrate.R
├── test-03-rake.R
├── test-04-poststratify.R
├── test-05-nonresponse.R
└── test-06-diagnostics.R
```

### Helper Placement Rules Applied

| Helper | Location | Reason |
|--------|----------|--------|
| `.get_weight_vec()` | `07-utils.R` | Used by all 5 function files |
| `.get_weight_col_name()` | `07-utils.R` | Used by all 5 function files |
| `.validate_weights()` | `07-utils.R` | Used by all 5 function files |
| `.validate_calibration_variables()` | `07-utils.R` | Used by `02-calibrate.R` and `03-rake.R` |
| `.validate_population_marginals()` | `07-utils.R` | Used by `02-calibrate.R` and `03-rake.R` |
| `.compute_weight_stats()` | `07-utils.R` | Used by `07-utils.R` itself (in `.make_history_entry()`) and `06-diagnostics.R` |
| `.make_history_entry()` | `07-utils.R` | Used by all 4 calibration/NR function files |
| `.calibrate_engine()` | `07-utils.R` | Used by `02-calibrate.R`, `03-rake.R`, `04-poststratify.R` |
| `.make_weighted_df()` | `07-utils.R` | Used by `02-calibrate.R`, `03-rake.R`, `04-poststratify.R`, `05-nonresponse.R` |
| `.update_survey_weights()` | `07-utils.R` | Used by `02-calibrate.R`, `03-rake.R`, `04-poststratify.R`, `05-nonresponse.R` |
| `.parse_margins()` | `03-rake.R` | Only used by `rake()` |
| `.validate_population_cells()` | `04-poststratify.R` | Only used by `poststratify()` |

---

## Prerequisite: Surveycore PR (not in this repo)

Before PRs 3–9 can begin, a separate PR in the `surveycore` package must be
merged. It must deliver:

1. `weighting_history` list property added to the surveycore metadata class
   (default: `list()`)
2. Updated surveycore constructors accepting `weighted_df` input and promoting
   its `weighting_history` attribute to `@metadata@weighting_history`
3. Exported accessor `survey_weighting_history(x)` → extracts
   `@metadata@weighting_history`

Once merged, verify:
- `survey_base` property names (`@data`, `@variables`, `@metadata`) — Open GAP #1
- `@variables$weights` is a character scalar (column name) — Open GAP #3
- `survey_weighting_history()` exact name — Open GAP #2
- Actual minimum surveycore version (placeholder: `0.1.0`) — Open GAP #4

**PRs 1 and 2 in this package do not require surveycore. PRs 3–9 do.**

---

## PR Map

- [x] PR 1: `feature/phase-0-infra` — DESCRIPTION, vendored algorithm files,
  VENDORED.md, package docs
- [ ] PR 2: `feature/phase-0-test-helpers` — Test helper file and rule stubs
- [ ] PR 3: `feature/phase-0-classes` — `weighted_df` S3 class + `survey_calibrated`
  S7 class + internal constructor + class tests
- [ ] PR 4: `feature/phase-0-utils` — All shared internal helpers in `R/07-utils.R`
- [ ] PR 5: `feature/phase-0-calibrate` — `calibrate()` + tests
- [ ] PR 6: `feature/phase-0-rake` — `rake()` + `.parse_margins()` + tests
- [ ] PR 7: `feature/phase-0-poststratify` — `poststratify()` +
  `.validate_population_cells()` + tests
- [ ] PR 8: `feature/phase-0-nonresponse` — `adjust_nonresponse()` + tests
- [ ] PR 9: `feature/phase-0-diagnostics` — `effective_sample_size()`,
  `weight_variability()`, `summarize_weights()` + tests

PRs 5, 6, and 7 all depend on PR 4 and are independent of each other — they
can be worked in parallel. PRs 8 and 9 also depend only on PR 4.

---

## PR 1: Package Infrastructure

**Branch:** `feature/phase-0-infra`
**Depends on:** none (can start immediately)

**Files (in TDD order — no test file; infra only):**
- `DESCRIPTION` — add Imports with minimum versions per spec §II.b; add
  `Remotes:` field for surveycore (GitHub-hosted, not on CRAN)
- `R/vendor/calibrate-greg.R` — vendored GREG/logit calibration
- `R/vendor/calibrate-ipf.R` — vendored IPF/raking
- `VENDORED.md` — attribution record at repo root
- `R/surveyweights-package.R` — replace TODO stubs with proper package docs

**Acceptance criteria:**
- [x] All new tests confirmed failing (red) before implementation began
- [x] `devtools::check()` 0 errors, 0 warnings, ≤2 pre-approved notes
- [x] `devtools::document()` run; NAMESPACE and man/ in sync
- [x] `DESCRIPTION` Imports matches spec §II.b exactly: `cli (>= 3.6.0)`,
  `dplyr (>= 1.1.0)`, `rlang (>= 1.1.0)`, `S7 (>= 0.2.0)`,
  `surveycore (>= 0.1.0)`, `tibble (>= 3.2.0)`; Suggests: `survey (>= 4.2-1)`,
  `testthat (>= 3.2.0)`
- [x] `DESCRIPTION` contains a `Remotes:` field pointing to surveycore's GitHub
  location (e.g., `surveyverse/surveycore`); update with the exact repo/ref
  once the surveycore prerequisite PR is confirmed. Remove before CRAN submission.
- [x] `R/vendor/calibrate-greg.R` has attribution comment block (source package,
  version, author: Thomas Lumley, license: GPL-2+, function URL)
- [x] `R/vendor/calibrate-ipf.R` has attribution comment block (same format)
- [x] `VENDORED.md` created at repo root; attributes both vendored files with
  package, version, function name, license, and algorithm description
- [x] `R/surveyweights-package.R` updated with real description and Key Functions
  section listing all exported functions

**Notes:**
- **No changelog entry for PRs 1–4.** These are infrastructure PRs with no
  user-facing exported functions. `changelog/phase-0/` feeds NEWS.md; internal
  infrastructure does not belong there. Changelog entries begin with PR 5.
- `.onLoad()` calling `S7::methods_register()` already exists in `R/zzz.R`.
  The spec intends it in `surveyweights-package.R` but `zzz.R` is equivalent
  and correct. Do not duplicate it; update `surveyweights-package.R` with
  documentation only.
- Vendored algorithms must remain mathematically identical to their source;
  only rename internal variables and remove unused dependencies as needed.
- Open GAP #5 (`adjust_nonresponse()` reference) is unresolved. Document in
  `VENDORED.md` that this function uses hand-calculation validation; no vendored
  file is needed.

---

## PR 2: Test Infrastructure and Stubs

**Branch:** `feature/phase-0-test-helpers`
**Depends on:** PR 1

**Files (in TDD order — no test file; helpers are tested indirectly):**
- `tests/testthat/helper-test-data.R` — `make_surveyweights_data()` and
  `test_invariants()`

**Before opening PR 2** (direct commits to `develop`, no branch needed):
- `.claude/rules/surveyweights-conventions.md` — fill in stubs with Phase 0
  naming patterns
- `.claude/rules/testing-surveyweights.md` — fill in stubs with
  `test_invariants()` definition, `make_surveyweights_data()` spec, file map,
  and numerical tolerance table

**Acceptance criteria:**
- [ ] All new tests confirmed failing (red) before implementation began
- [ ] `devtools::check()` 0 errors, 0 warnings, ≤2 pre-approved notes
- [ ] `devtools::document()` run; NAMESPACE and man/ in sync
- [ ] `make_surveyweights_data(n = 500, seed = 42)` produces a data.frame with
  columns: `id` (integer), `age_group` (character), `sex` (character),
  `education` (character), `region` (character), `base_weight` (positive numeric)
- [ ] `make_surveyweights_data(include_nonrespondents = TRUE)` adds `responded`
  column (integer 0/1) with realistic split (≥ 20% nonrespondents)
- [ ] `test_invariants()` defined exactly as in spec §XIII (checks `weighted_df`
  and `survey_calibrated` invariants; uses `S7::S7_inherits()`, not `inherits()`)
- [ ] `.claude/rules/surveyweights-conventions.md` and
  `.claude/rules/testing-surveyweights.md` committed directly to `develop`
  before opening this PR (not part of the feature branch diff)

**Notes:**
- `make_surveyweights_data()` must produce realistic imbalance — not equal-sized
  groups. Use `set.seed(seed)` at the top; use `sample(...)` with unequal
  `prob =` arguments for demographic groups.
- `test_invariants()` must reference the exported `survey_calibrated` class
  object by name. It will not yet be available at testthat load time; use
  `if (exists("survey_calibrated"))` guard for the S7 branch until PR 3 lands.
- The file map in `testing-surveyweights.md` must reflect the split file
  structure from this plan, not the single-file structure in spec §II.

---

## PR 3: Core Classes and Internal Constructor

**Branch:** `feature/phase-0-classes`
**Depends on:** Surveycore prerequisite PR; PR 2

**Files (in TDD order — tests first):**
- `tests/testthat/test-00-classes.R` — tests for `weighted_df` and
  `survey_calibrated` (spec §XIII classes test items 1–9)
- `R/00-classes.R` — `weighted_df` S3 class + `survey_calibrated` S7 class
  definition + validator
- `R/01-constructors.R` — `.new_survey_calibrated()` internal constructor
  (no exports)

**Acceptance criteria:**
- [ ] All new tests confirmed failing (red) before implementation began
- [ ] `devtools::check()` 0 errors, 0 warnings, ≤2 pre-approved notes
- [ ] `devtools::document()` run; NAMESPACE and man/ in sync
- [ ] All 9 test items from spec §XIII classes section pass:
  1. `dplyr_reconstruct` preserving weight col → `weighted_df` returned
  2. `dplyr_reconstruct` dropping weight col → plain tibble + warning
  3. Warning class is `surveyweights_warning_weight_col_dropped`
  4. `print.weighted_df` snapshot (matches verbatim in spec §IV)
  5. History is empty list on initial creation
  6. Class vector is `c("weighted_df", "tbl_df", "tbl", "data.frame")`
  7. `survey_calibrated` print snapshot (matches verbatim in spec §V)
  8. `survey_calibrated` validator rejects non-positive weights (`class=` only)
  9. `survey_calibrated` validator rejects NA weights (`class=` only)
- [ ] `test_invariants()` called in every test block that constructs a
  `weighted_df` or `survey_calibrated`
- [ ] `S7::S7_inherits()` used everywhere — no `inherits()` with string class names
- [ ] `survey_calibrated` uses `S7::new_class("survey_calibrated", parent =
  surveycore::survey_base, ...)` per spec §V
- [ ] Validator checks exactly the 5 conditions in spec §V using S7's native
  mechanism (not `cli_abort()`)
- [ ] `print.weighted_df()` delegates body to `NextMethod()` for tibble formatting
- [ ] `S7::method(print, survey_calibrated)` hardcodes `"Taylor linearization"`
  per spec §V (Issue 2, resolved Option A)
- [ ] Both print methods return `invisible(x)`

**Notes:**
- Verify Open GAP #1 against surveycore source: does `survey_base`'s validator
  already enforce `@variables` key presence (`ids`, `strata`, `fpc`, `nest`)?
  If not, add those checks to the `survey_calibrated` validator per spec §V.
- `dplyr_reconstruct.weighted_df()` must be registered with `@export` so dplyr
  can dispatch it. S3 method registration happens via roxygen2 `@export` — never
  via manual `NAMESPACE` edit.
- The `print.weighted_df()` header block must match the verbatim example in
  spec §IV exactly. Pay attention to number formatting (`1,500`) and ESS
  (`1,189`).
- **PR 3 tests cannot call `.make_weighted_df()`** (not yet defined — lives in
  PR 4). Construct `weighted_df` test fixtures using `structure()` with explicit
  class, `weight_col`, and `weighting_history` attributes:
  ```r
  wdf <- structure(
    tibble::tibble(x = 1:5, w = rep(1, 5)),
    class = c("weighted_df", "tbl_df", "tbl", "data.frame"),
    weight_col = "w",
    weighting_history = list()
  )
  ```
- **PR 3 must implement `print.weighted_df()` stats inline** — do NOT call
  `.compute_weight_stats()` (defined in PR 4, not yet available). Implement
  ~4 lines inline: `mean(w)`, `sd(w)/mean(w)` for CV, and the Kish ESS formula
  `sum(w)^2 / sum(w^2)`. PR 4 refactors `print.weighted_df()` to call
  `.compute_weight_stats()` and may require snapshot regeneration (see PR 4).

---

## PR 4: Shared Internal Utilities

**Branch:** `feature/phase-0-utils`
**Depends on:** Surveycore prerequisite PR; PR 3

**Files (in TDD order — no separate test file; all tested indirectly via PRs 5–9):**
- `R/07-utils.R` — all shared internal helpers
- `R/00-classes.R` — refactor `print.weighted_df()` to call `.compute_weight_stats()`
  (replacing the inline stats from PR 3); regenerate snapshot if output differs

**Shared helpers (used by 2+ source files):**
- `.get_weight_vec(x, weights_quo)` — extracts weight vector from any input class
- `.get_weight_col_name(x, weights_quo)` — returns weight column name as character;
  returns `".weight"` for plain `data.frame` with `weights_quo = NULL`
- `.validate_weights(data, weight_col)` — validates existence, type, positivity, no NA
- `.validate_calibration_variables(data, variable_names, context)` — checks
  that each column in `variable_names` is character or factor (throws
  `surveyweights_error_variable_not_categorical`) and contains no NAs (throws
  `surveyweights_error_variable_has_na`); `context` is `"Calibration"` or
  `"Raking"` and appears in the error message; used by `calibrate()` and `rake()`
- `.validate_population_marginals(population, variable_names, data, type)` —
  validates named-list population targets; used by `calibrate()` and `rake()`
  (rake converts Format B to Format A before calling this)
- `.compute_weight_stats(weights_vec)` — returns 11-key named list
- `.make_history_entry(operation, call_str, parameters, before_stats, after_stats,
  convergence = NULL)` — constructs one history entry per spec §IV.5
- `.calibrate_engine(data_df, weights_vec, calibration_spec, method, control)` —
  dispatches to vendored GREG, logit, or IPF algorithms
- `.make_weighted_df(data, weight_col, history = list())` — internal `weighted_df`
  constructor
- `.update_survey_weights(design, new_weights_vec, history_entry,
  output_class = c("same", "survey_calibrated"))` — updates survey object weights
  and appends history entry

**Acceptance criteria:**
- [ ] All new tests confirmed failing (red) before implementation began
- [ ] `devtools::check()` 0 errors, 0 warnings, ≤2 pre-approved notes
- [ ] `devtools::document()` run; NAMESPACE and man/ in sync
- [ ] All 9 shared helpers implemented with signatures matching spec §XI
- [ ] `.validate_calibration_variables(data, variable_names, context)` implemented with
  signature matching spec §XI; throws `surveyweights_error_variable_not_categorical`
  for non-character/non-factor columns and `surveyweights_error_variable_has_na`
  for columns with NAs; `context` parameter (`"Calibration"` / `"Raking"`) appears
  in the error message text
- [ ] `.validate_weights()` throws all 4 typed errors from spec §XII.A:
  `weights_not_found`, `weights_not_numeric`, `weights_nonpositive`, `weights_na`
- [ ] `.get_weight_col_name()` returns `".weight"` for `data.frame` input with
  `weights_quo = NULL` — authoritative default per spec §II.d
- [ ] `.compute_weight_stats()` returns a named list with all 11 keys: `n`,
  `n_positive`, `n_zero`, `mean`, `cv`, `min`, `p25`, `p50`, `p75`, `max`, `ess`
- [ ] `.calibrate_engine()` accepts `method = c("linear", "logit", "ipf",
  "poststratify")` and delegates to the appropriate vendored algorithm
- [ ] `.make_history_entry()` produces a list matching spec §IV.5 including
  `package_version = as.character(packageVersion("surveyweights"))`
- [ ] `.update_survey_weights()` calls `.new_survey_calibrated()` for
  `output_class = "survey_calibrated"`
- [ ] No helpers are exported; all are `.`-prefixed
- [ ] `.validate_population_cells()` is NOT in this file — it lives in
  `04-poststratify.R`
- [ ] **Coverage note:** Coverage will be ~0% when this PR merges in isolation;
  this is expected. All helpers are covered indirectly by PRs 5–9. Do not add
  direct tests to meet coverage here.
- [ ] `print.weighted_df()` in `R/00-classes.R` refactored to call
  `.compute_weight_stats()` instead of the inline implementation from PR 3;
  `print.weighted_df()` snapshot reviewed and regenerated if needed

**Notes:**
- `.validate_population_marginals()` handles the `population_level_extra` error
  (Issue 21): levels in `population` absent from `data` → error. This validation
  is shared by both `calibrate()` (direct) and `rake()` (after Format A
  conversion by `.parse_margins()`).
- Open GAP #6: `.calibrate_engine()` `calibration_spec` format may need
  refinement during implementation. Document any departures from spec §XI in a
  comment in the function body.
- For `.update_survey_weights()`: the `@metadata@weighting_history` append
  requires the surveycore prerequisite PR to be complete.

---

## PR 5: `calibrate()`

**Branch:** `feature/phase-0-calibrate`
**Depends on:** PR 4

**Files (in TDD order — tests first):**
- `tests/testthat/test-02-calibrate.R` — full test suite for `calibrate()`
- `R/02-calibrate.R` — `calibrate()` (no private helpers; all used by rake too,
  so all helpers are in `07-utils.R`)
- `changelog/phase-0/calibrate.md` — created last, before opening PR

**Acceptance criteria:**
- [ ] All new tests confirmed failing (red) before implementation began
- [ ] `devtools::check()` 0 errors, 0 warnings, ≤2 pre-approved notes
- [ ] `devtools::document()` run; NAMESPACE and man/ in sync
- [ ] All `calibrate()` test items from spec §XIII pass (items 1–19; item 19b
  is relocated to `test-03-rake.R` in PR 6 — do not write it here):
  - Happy paths: data.frame→weighted_df, survey_taylor→survey_calibrated,
    weighted_df→weighted_df (history), survey_calibrated→survey_calibrated,
    method="logit", type="count", multi-variable population verified
  - Numerical correctness vs `survey::calibrate()` within 1e-8 tolerance
    (inside `skip_if_not_installed("survey")` block)
  - SE-1 through SE-7 standard error paths
  - Function-specific error paths: variable_not_categorical, variable_has_na,
    population_variable_not_found, population_level_missing,
    population_level_extra, population_totals_invalid,
    calibration_not_converged
  - Warning: negative_calibrated_weights
  - Edge cases: single-row data frame, single variable in population
  - History: structure after calibration, step increment
- [ ] All error tests use dual pattern (`expect_error(class=)` +
  `expect_snapshot(error=TRUE)`)
- [ ] `test_invariants()` called in every happy path test block
- [ ] `make_surveyweights_data()` used in all non-edge-case test blocks
- [ ] Argument order: `data, variables, population, weights, method, type, control`
- [ ] `method = "logit"` delegates to vendored logit calibration
- [ ] History operation label is exactly `"calibration"`
- [ ] Changelog entry written and committed on this branch

**Notes:**
- `calibrate()` has no private helpers. All its internal logic that is also
  needed by `rake()` (weight extraction, weight validation, population validation,
  history entry creation, output construction) lives in `07-utils.R`. The
  function body is primarily orchestration: validate → compute before-stats →
  call `.calibrate_engine()` → compute after-stats → build history entry →
  return output.
- `surveyweights_error_calibration_not_converged` is thrown by
  `.calibrate_engine()`, not by `calibrate()` directly.
- `surveyweights_error_population_level_extra` is thrown by
  `.validate_population_marginals()` in `07-utils.R`.

---

## PR 6: `rake()`

**Branch:** `feature/phase-0-rake`
**Depends on:** PR 4; PR 5

**Files (in TDD order — tests first):**
- `tests/testthat/test-03-rake.R` — full test suite for `rake()`
- `R/03-rake.R` — `rake()` + `.parse_margins()`
- `changelog/phase-0/rake.md` — created last, before opening PR

**Private helper in this file:**

`.parse_margins(margins)` — converts Format B (long data.frame with `variable`,
`level`, `target` columns) to Format A (named list). Called at the top of
`rake()` after format validation. Returns a named list; errors with
`surveyweights_error_margins_format_invalid` if `margins` is neither valid format.

**Acceptance criteria:**
- [ ] All new tests confirmed failing (red) before implementation began
- [ ] `devtools::check()` 0 errors, 0 warnings, ≤2 pre-approved notes
- [ ] `devtools::document()` run; NAMESPACE and man/ in sync
- [ ] All `rake()` test items from spec §XIII pass (items 1–20 plus chaining):
  - Happy paths: data.frame, survey_taylor, weighted_df (history), survey_calibrated,
    type="count", margins as named list, margins as long data frame, mixed format
  - Numerical correctness vs `survey::rake()` within 1e-8 tolerance
    (inside `skip_if_not_installed("survey")` block)
  - SE-1 through SE-7 standard error paths
  - Function-specific errors: margins_format_invalid (bad class),
    margins_format_invalid (df missing columns), margins_variable_not_found,
    variable_not_categorical, variable_has_na, population_level_extra,
    population_totals_invalid, calibration_not_converged
  - Edge: single margin
  - History: structure after raking, step increment
  - **Integration: `calibrate()` → `rake()` chain produces two-entry history**
    with step numbers 1 and 2 and correct `operation` labels (test item 19b
    from spec §XIII, placed here since `rake()` is the chaining consumer)
- [ ] All error tests use dual pattern
- [ ] `test_invariants()` called in every happy path test block
- [ ] `make_surveyweights_data()` used in all non-edge-case test blocks
- [ ] Argument order: `data, margins, weights, type, control`
- [ ] Format B auto-detected, converted to Format A via `.parse_margins()` before
  history entry storage (spec §VII: "converted to Format A before storing")
- [ ] History operation label is exactly `"raking"`
- [ ] Changelog entry written and committed on this branch

**Notes:**
- `.parse_margins()` is co-located in `03-rake.R` because only `rake()` calls
  it. It validates margins structure AND normalizes Format B → Format A.
- The integration test (`calibrate() → rake()`) requires PR 5 to be merged
  first. If working in parallel, write the test as a stub and fill it in once
  PR 5 lands.
- `rake()` must call `.validate_population_marginals()` from `07-utils.R`
  after converting margins to Format A — this ensures level-checking and
  `population_level_extra` detection are shared with `calibrate()`.

---

## PR 7: `poststratify()`

**Branch:** `feature/phase-0-poststratify`
**Depends on:** PR 4

**Files (in TDD order — tests first):**
- `tests/testthat/test-04-poststratify.R` — full test suite for `poststratify()`
- `R/04-poststratify.R` — `poststratify()` + `.validate_population_cells()`
- `changelog/phase-0/poststratify.md` — created last, before opening PR

**Private helper in this file:**

`.validate_population_cells(population, strata_names, data, type)` — validates
the `population` data frame format for `poststratify()`. Checks: required columns
present (`strata_names` + `"target"`), every data cell has a matching population
row, no extra population cells, target values valid for the given `type`. Returns
`invisible(TRUE)` on success. This helper is NOT in `07-utils.R` because only
`poststratify()` uses it.

**Acceptance criteria:**
- [ ] All new tests confirmed failing (red) before implementation began
- [ ] `devtools::check()` 0 errors, 0 warnings, ≤2 pre-approved notes
- [ ] `devtools::document()` run; NAMESPACE and man/ in sync
- [ ] All `poststratify()` test items from spec §XIII pass (items 1–15):
  - Happy paths: data.frame, weighted_df, survey_taylor, survey_calibrated
  - Happy path: numeric strata column (integer age; verifies no categorical
    restriction applies to poststratify)
  - Numerical correctness vs `survey::postStratify()` within 1e-8 tolerance
    (inside `skip_if_not_installed("survey")` block)
  - SE-1 through SE-7 standard error paths
  - Function-specific errors: variable_has_na, population_totals_invalid,
    population_cell_missing, population_cell_not_in_data, empty_stratum
  - Edge: single stratum variable, type = "prop"
  - History: structure after post-stratification, step increment
- [ ] All error tests use dual pattern
- [ ] `test_invariants()` called in every happy path test block
- [ ] `make_surveyweights_data()` used in all non-edge-case test blocks
- [ ] Argument order: `data, strata, population, weights, type`
- [ ] No categorical restriction on strata variables (Issue 7 resolution);
  numeric/integer strata are valid cell keys
- [ ] Post-stratification formula is exact:
  `w_new = w * (N_h / N_hat_h)` per spec §VIII
- [ ] `.validate_population_cells()` checks for duplicate rows in `population` and
  throws `surveyweights_error_population_cell_duplicate`; test item 8d passes
- [ ] History operation label is exactly `"poststratify"`
- [ ] Changelog entry written and committed on this branch

**Notes:**
- `.validate_population_cells()` is co-located in `04-poststratify.R` because
  only `poststratify()` calls it. Unlike `.validate_population_marginals()`
  (which is shared with `calibrate()`), cell validation is join-based and
  not applicable to the other calibration functions.
- `surveyweights_error_population_cell_not_in_data` (extra cells in population)
  is thrown by `.validate_population_cells()` — this was resolved as an error,
  not a warning (Issue 4, Option A).
- The `empty_stratum` error condition (zero weighted count in a cell) is
  checked after weight application, not during validation.

---

## PR 8: `adjust_nonresponse()`

**Branch:** `feature/phase-0-nonresponse`
**Depends on:** PR 4

**Files (in TDD order — tests first):**
- `tests/testthat/test-05-nonresponse.R` — full test suite for
  `adjust_nonresponse()`
- `R/05-nonresponse.R` — `adjust_nonresponse()` (no private helpers; all
  helpers shared via `07-utils.R`)
- `changelog/phase-0/nonresponse.md` — created last, before opening PR

**Acceptance criteria:**
- [ ] All new tests confirmed failing (red) before implementation began
- [ ] `devtools::check()` 0 errors, 0 warnings, ≤2 pre-approved notes
- [ ] `devtools::document()` run; NAMESPACE and man/ in sync
- [ ] All 17 test items from spec §XIII pass (items 1–17 for `adjust_nonresponse()`)
- [ ] Dual pattern on all Layer 3 errors; all 8 error classes and 1 warning
  class in spec §XII.E tested
- [ ] `test_invariants()` called in every happy path test block
- [ ] `make_surveyweights_data(include_nonrespondents = TRUE)` used for main
  happy path tests
- [ ] Weight conservation (item 5): `sum(weights_before) ==
  sum(respondent_weights_after)` within 1e-10 tolerance
- [ ] Hand-calculation (item 5b): 2-class example from spec §XIII verified
  within 1e-10 tolerance; note in comment that no reference R package exists
- [ ] Output contains only respondent rows (`response_status == 1`)
- [ ] Argument order: `data, response_status, weights, by, method, control`
- [ ] Does NOT change the variance class for survey objects (spec §I)
- [ ] `method = "propensity"` → `surveyweights_error_propensity_requires_phase2`
  (API-stable Phase 2 stub)
- [ ] Warning thresholds: `control$min_cell = 20`, `control$max_adjust = 2.0`;
  either condition alone triggers `surveyweights_warning_class_near_empty`
- [ ] Separate test blocks for count-trigger (item 14) and factor-trigger (14b)
- [ ] History operation label is exactly `"nonresponse_weighting_class"`
- [ ] Changelog entry written and committed on this branch

**Notes:**
- `adjust_nonresponse()` has no private helpers. Cell-grouping logic (split
  data by `by` variables, compute group sums) is simple enough to do inline;
  do not create a helper for it unless it exceeds ~20 lines.
- When `by = NULL`, treat all rows as a single cell — equivalent to global
  redistribution.
- Cells with zero nonrespondents pass through unchanged without a warning.

---

## PR 9: Diagnostics

**Branch:** `feature/phase-0-diagnostics`
**Depends on:** PR 4

**Files (in TDD order — tests first):**
- `tests/testthat/test-06-diagnostics.R` — full test suite for
  `effective_sample_size()`, `weight_variability()`, `summarize_weights()`
- `R/06-diagnostics.R` — all three diagnostic functions (no private helpers;
  `.compute_weight_stats()` is in `07-utils.R`)
- `changelog/phase-0/diagnostics.md` — created last, before opening PR

**Acceptance criteria:**
- [ ] All new tests confirmed failing (red) before implementation began
- [ ] `devtools::check()` 0 errors, 0 warnings, ≤2 pre-approved notes
- [ ] `devtools::document()` run; NAMESPACE and man/ in sync
- [ ] All 8 test items from spec §XIII pass (items 1–8 for diagnostics)
- [ ] Dual pattern on all Layer 3 errors; 4 error classes tested for
  `effective_sample_size()` / `weight_variability()`
- [ ] `unsupported_class` tested (item 5b): throw
  `surveyweights_error_unsupported_class` for matrix/list input (Issue 28)
- [ ] `effective_sample_size()` returns named scalar `c(n_eff = <value>)`;
  name `"n_eff"` is part of the API contract
- [ ] `weight_variability()` returns named scalar `c(cv = <value>)`;
  name `"cv"` is part of the API contract
- [ ] `summarize_weights()` returns a tibble with columns in the order from
  spec §X: group columns, `n`, `n_positive`, `n_zero`, `mean`, `cv`, `min`,
  `p25`, `p50`, `p75`, `max`, `ess`; single-row tibble when `by = NULL`
- [ ] `summarize_weights()` with `by` grouping returns one row per group
- [ ] Hand-calculation test (item 1): construct weights manually, verify ESS
  and CV within 1e-10 tolerance
- [ ] Argument order: `effective_sample_size(x, weights = NULL)`,
  `weight_variability(x, weights = NULL)`,
  `summarize_weights(x, weights = NULL, by = NULL)`
- [ ] All three functions use `::` for every external call; no `@importFrom`
- [ ] Changelog entry written and committed on this branch

**Notes:**
- `summarize_weights()` delegates per-group computation to
  `.compute_weight_stats()` from `07-utils.R` — do not duplicate the
  computation logic.
- Auto-detection: `weighted_df` → `attr(x, "weight_col")`;
  survey objects → `x@variables$weights`.

---

## Final Quality Gate Checklist

Before opening the release PR (`develop` → `main`), all of the following must pass:

- [ ] `devtools::check()` passes: 0 errors, 0 warnings, ≤2 notes
- [ ] `covr::package_coverage()` ≥ 98% line coverage
- [ ] Every exported function has `@return`, runnable `@examples`, `@family`
- [ ] Every `cli_abort()` and `cli_warn()` has a `class =` argument
- [ ] All error classes in spec §XII are in `plans/error-messages.md`
- [ ] All error classes have a `test_that()` block with the dual pattern
- [ ] All snapshot tests pass (`testthat::snapshot_review()` clean)
- [ ] `air::format_package()` produces no diffs
- [ ] `test_invariants()` is called in every constructor test block
- [ ] `make_surveyweights_data()` is used in all non-edge-case test blocks
- [ ] `calibrate()`, `rake()`, `poststratify()` have numerical correctness tests
  against `survey` package (each with `skip_if_not_installed("survey")` inside
  the relevant `test_that()` block)
- [ ] `R/vendor/calibrate-greg.R` and `R/vendor/calibrate-ipf.R` exist and carry
  attribution comment blocks (source package, version, author, license, URL)
- [ ] `VENDORED.md` is created and attributes all vendored code
- [ ] Reference for `adjust_nonresponse()` is documented in `VENDORED.md`
  (hand-calculation validation methodology)
- [ ] `surveyweights-conventions.md` stub is filled in with Phase 0 conventions
- [ ] `testing-surveyweights.md` stub is filled in with `test_invariants()`
  definition, `make_surveyweights_data()` spec, and updated file map
- [ ] Surveycore prerequisite PR is merged before any PR that uses survey objects
