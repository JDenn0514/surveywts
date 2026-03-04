# Implementation Plan: Phase 0 — Weighting Core (v0.1.0)

**Version:** 1.3
**Date:** 2026-03-04
**Status:** Approved — ready for implementation
**Branch identifier:** `phase-0`
**Spec:** `plans/spec-phase-0.md` (v0.3, fully resolved)

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
├── 00-classes.R         # weighted_df S3 class (print.weighted_df, dplyr_reconstruct.weighted_df)
├── 01-constructors.R    # .new_survey_calibrated() — internal constructor only
├── 02-calibrate.R       # calibrate()
├── 03-rake.R            # rake() + .parse_margins()
├── 04-poststratify.R    # poststratify() + .validate_population_cells()
├── 05-nonresponse.R     # adjust_nonresponse()
├── 06-diagnostics.R     # effective_sample_size(), weight_variability(),
│                        #   summarize_weights()
├── 07-utils.R           # Shared internal helpers (used by 2+ source files)
├── methods-print.R      # S7::method(print, surveycore::survey_calibrated)
│                        #   per code-style.md §2 (S7 methods in dedicated file)
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
- [x] PR 2: `feature/phase-0-test-helpers` — Test helper file and rule stubs
- [x] PR 3: `feature/phase-0-classes` — `weighted_df` S3 class + `survey_calibrated`
  S7 class + internal constructor + class tests
- [x] PR 4: `feature/phase-0-utils` — All shared internal helpers in `R/07-utils.R`
- [x] PR 5: `feature/phase-0-calibrate` — `calibrate()` + tests
- [x] PR 6: `feature/phase-0-rake` — `rake()` + `.parse_margins()` + tests
- [ ] PR 7: `feature/phase-0-poststratify` — `poststratify()` +
  `.validate_population_cells()` + tests
- [ ] PR 8: `feature/phase-0-nonresponse` — `adjust_nonresponse()` + tests
- [ ] PR 9: `feature/phase-0-diagnostics` — `effective_sample_size()`,
  `weight_variability()`, `summarize_weights()` + tests

PR 5 and PR 7 can be worked in parallel (both depend only on PR 4). PR 6
depends on both PR 4 and PR 5 — its integration test requires `calibrate()`
to exist. PRs 8 and 9 also depend only on PR 4.

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
  `svrep (>= 0.6)`, `testthat (>= 3.2.0)` — `svrep` is the numerical oracle
  for `adjust_nonresponse()` tests
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
- GAP #5 (`adjust_nonresponse()` reference) is resolved: `svrep::redistribute_weights()`
  serves as the numerical oracle in tests. No vendored file is needed; document in
  `VENDORED.md` that this function uses a native implementation validated against svrep.

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
- [x] All new tests confirmed failing (red) before implementation began
- [x] `devtools::check()` 0 errors, 0 warnings, ≤2 pre-approved notes
- [x] `devtools::document()` run; NAMESPACE and man/ in sync
- [x] `make_surveyweights_data(n = 500, seed = 42)` produces a data.frame with
  columns: `id` (integer), `age_group` (character), `sex` (character),
  `education` (character), `region` (character), `base_weight` (positive numeric)
- [x] `make_surveyweights_data(include_nonrespondents = TRUE)` adds `responded`
  column (integer 0/1) with realistic split (≥ 20% nonrespondents)
- [x] `test_invariants()` defined exactly as in spec §XIII (checks `weighted_df`
  and `survey_calibrated` invariants; uses `S7::S7_inherits()`, not `inherits()`)
- [x] `.claude/rules/surveyweights-conventions.md` and
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
- `R/00-classes.R` — `weighted_df` S3 class + `print.weighted_df()` +
  `dplyr_reconstruct.weighted_df()`
- `R/methods-print.R` — `S7::method(print, surveycore::survey_calibrated)`;
  per code-style.md §2, S7 print methods live in a dedicated file separate
  from class definitions
- `R/01-constructors.R` — `.new_survey_calibrated()` internal constructor
  (no exports)

**Acceptance criteria:**
- [ ] All new tests confirmed failing (red) before implementation began
- [ ] `devtools::check()` 0 errors, 0 warnings, ≤2 pre-approved notes
- [ ] `devtools::document()` run; NAMESPACE and man/ in sync
- [ ] All 16 test items from spec §XIII classes section pass (items 1–9, 2b–2g, 4b):
  1. `dplyr_reconstruct` preserving weight col → `weighted_df` returned
  2. `dplyr_reconstruct` dropping weight col → plain tibble + warning
  2b. `dplyr_reconstruct` after rename → plain tibble + warning (§IV rule 3)
  2c. `dplyr_reconstruct` via `filter()` preserving weight col → `weighted_df`
  2d. `dplyr_reconstruct` via `filter()` to 0 rows → `weighted_df`
  2e. `dplyr_reconstruct` via `mutate()` not touching weight col → `weighted_df`
  2f. `dplyr_reconstruct` via `mutate()` modifying weight values → `weighted_df`
  2g. `dplyr_reconstruct` via `mutate(.keep = "unused")` dropping weight col → warning + plain tibble
  3. Warning class is `surveyweights_warning_weight_col_dropped`
  4. `print.weighted_df` snapshot with 2-step history (matches verbatim in spec §IV)
  4b. `print.weighted_df` snapshot with empty history → `# Weighting history: none`
  5. History is empty list on initial creation
  6. Class vector is `c("weighted_df", "tbl_df", "tbl", "data.frame")`
  7. `survey_calibrated` print snapshot (matches verbatim in spec §V)
  8. `survey_calibrated` validator rejects non-positive weights (`class=` only;
     class = `"surveycore_error_weights_nonpositive"`)
  9. `survey_calibrated` validator rejects NA weights (`class=` only;
     class = `"surveycore_error_weights_na"`; trigger requires ALL values to be NA —
     surveycore permits individual NAs)
- [ ] `test_invariants()` called in every test block that constructs a
  `weighted_df` or `survey_calibrated`
- [ ] `S7::S7_inherits()` used everywhere — no `inherits()` with string class names
- [ ] `survey_calibrated` uses `S7::new_class("survey_calibrated", parent =
  surveycore::survey_base, ...)` per spec §V
- [ ] Validator checks exactly the 5 conditions in spec §V using S7's native
  mechanism (not `cli_abort()`)
- [ ] `print.weighted_df()` delegates body to `NextMethod()` for tibble formatting
- [ ] `S7::method(print, survey_calibrated)` lives in `R/methods-print.R`
  and hardcodes `"Taylor linearization"` per spec §V (Issue 2, resolved Option A)
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
- `.update_survey_weights(design, new_weights_vec, history_entry)` — updates
  survey object weights and appends history entry; only used by
  `adjust_nonresponse()` (which never promotes class); calibration functions
  call `.new_survey_calibrated()` directly for class promotion

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
- [ ] `.update_survey_weights()` takes exactly 3 arguments (`design`,
  `new_weights_vec`, `history_entry`) — no `output_class` parameter; only
  `adjust_nonresponse()` calls it; calibration functions use
  `.new_survey_calibrated()` directly for class promotion
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
- [ ] All `calibrate()` test items from spec §XIII pass (items 1–19 plus 13c,
  13d, 14b; item 19b is relocated to `test-03-rake.R` in PR 6):
  - Happy paths: data.frame→weighted_df (assert `attr(result,"weight_col")==".weight"`),
    survey_taylor→survey_calibrated, weighted_df→weighted_df (history),
    survey_calibrated→survey_calibrated, 1b. factor-typed `variables` column,
    method="logit", type="count", multi-variable population verified
  - Numerical correctness vs `survey::calibrate()` within 1e-8 tolerance
    (inside `skip_if_not_installed("survey")` block)
  - SE-1 through SE-8 standard error paths (SE-8: 0-row + missing weight → empty_data)
  - Function-specific error paths: variable_not_categorical, variable_has_na,
    population_variable_not_found, population_level_missing,
    population_level_extra, population_totals_invalid (item 13: type="prop"),
    population_totals_invalid (item 13b: type="count" target ≤ 0),
    population_totals_invalid tolerance boundary (13c: passes at 1.0+9e-7;
    13d: fails at 1.0+2e-6), calibration_not_converged (hits maxit),
    calibration_not_converged (item 14b: control$maxit = 0 distinct note)
  - Warning: negative_calibrated_weights
  - Edge cases: single-row data frame, single variable in population
  - History: full §IV.5 structure (step, operation, timestamp POSIXct, call,
    parameters, weight_stats before/after, convergence list, package_version)
- [ ] All error tests use dual pattern (`expect_error(class=)` +
  `expect_snapshot(error=TRUE)`); warning tests (item 15) use
  `expect_warning(class =)` + `expect_snapshot()`
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
- `R/vendor/rake-anesrake.R` — vendored anesrake IPF algorithm from the `anesrake`
  package (Pasek & Tahk, GPL-2+); must carry full attribution comment block
- `VENDORED.md` — updated to add attribution entry for `rake-anesrake.R`
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
- [ ] All `rake()` test items from spec §XIII pass (items 1–26 plus 17b, 23b, 26c, chaining):
  - Happy paths: data.frame (assert `attr(result,"weight_col")==".weight"`),
    survey_taylor, weighted_df (history), survey_calibrated,
    1b. factor-typed margin variable, type="count", margins as named list,
    margins as long data frame, mixed format, method = "survey" explicit,
    cap with both methods, cap = NULL
  - Numerical correctness vs `survey::rake()` within 1e-8 (`method = "survey"`,
    inside `skip_if_not_installed("survey")` block)
  - Numerical correctness vs `anesrake::anesrake()` within 1e-8 (`method = "anesrake"`,
    inside `skip_if_not_installed("anesrake")` block)
  - SE-1 through SE-8 standard error paths (SE-8: 0-row + missing weight → empty_data)
  - Function-specific errors: margins_format_invalid (bad class),
    margins_format_invalid (df missing columns), margins_variable_not_found,
    variable_not_categorical, variable_has_na,
    population_level_missing (item 15b: use Format B input to test .parse_margins() path),
    population_level_extra, population_totals_invalid (item 16: type="prop"),
    population_totals_invalid (item 16b: type="count" target ≤ 0),
    population_totals_invalid tolerance boundary (16c: passes at 1.0+9e-7;
    16d: fails at 1.0+2e-6),
    calibration_not_converged (hits maxit),
    calibration_not_converged (item 17b: control$maxit = 0 distinct note)
  - Warnings: control_param_ignored (pval with survey; epsilon with anesrake)
  - Item 23: `control$variable_select = "max"` vs `"total"`
  - Item 23b: `control$variable_select = "average"` produces valid calibrated weights
  - Item 26b: `surveyweights_message_already_calibrated` via chi-square threshold
  - Item 26c: `surveyweights_message_already_calibrated` via min_cell_n exclusion
  - Edge: single margin
  - History: full §IV.5 structure (step, operation, timestamp POSIXct, call,
    parameters including method/cap/resolved control, weight_stats before/after,
    convergence list, package_version); step increment
  - Control defaults: anesrake resolves maxit = 1000; survey resolves maxit = 100;
    user override works
  - **Integration: `calibrate()` → `rake()` chain produces two-entry history**
    with step numbers 1 and 2 and correct `operation` labels
- [ ] All error tests use dual pattern; warning tests use `expect_warning(class =)` +
  `expect_snapshot()`
- [ ] `test_invariants()` called in every happy path test block
- [ ] `make_surveyweights_data()` used in all non-edge-case test blocks
- [ ] Argument order: `data, margins, weights, type, method, cap, control`
- [ ] Default `method = "anesrake"` (first element of character vector)
- [ ] `control = list()` in signature; method-appropriate defaults applied internally
  via `modifyList(method_defaults, control)` before any use of control values
- [ ] Format B auto-detected, converted to Format A via `.parse_margins()` before
  history entry storage (spec §VII: "converted to Format A before storing")
- [ ] When `cap` is non-`NULL`, cap applied at each IPF step (`w / mean(w) > cap`
  → `w = cap × mean(w)`); documented in function `@details`
- [ ] Method-specific control params passed to wrong method trigger
  `surveyweights_warning_control_param_ignored` (one warning per ignored param)
- [ ] `R/vendor/rake-anesrake.R` carries full attribution comment block:
  source package (`anesrake`), version, authors (Pasek & Tahk), license (GPL-2+),
  function name, and algorithm description
- [ ] `VENDORED.md` updated with entry for anesrake IPF algorithm
- [ ] History operation label is exactly `"raking"`
- [ ] History `parameters` includes `method`, `cap`, and fully resolved `control` list
- [ ] Changelog entry written and committed on this branch

**Notes:**
- `.parse_margins()` is co-located in `03-rake.R` because only `rake()` calls
  it. It validates margins structure AND normalizes Format B → Format A.
- The integration test (`calibrate() → rake()`) requires PR 5 to be merged
  first. PR 6 requires PR 5 to be merged first; the integration test is not
  a stub.
- `rake()` must call `.validate_population_marginals()` from `07-utils.R`
  after converting margins to Format A — this ensures level-checking and
  `population_level_extra` detection are shared with `calibrate()`.
- The vendored anesrake algorithm (`R/vendor/rake-anesrake.R`) must remain
  mathematically identical to the `anesrake` package source. Only rename
  internal variables and remove unused dependencies. Do not vendor the full
  package — extract only the core IPF-with-selection function.
- The `anesrake` package is GPL-2+ (Pasek & Tahk). GPL-2+ is compatible with
  this package's GPL-3 license. Verify the license before vendoring.
- For the control defaults implementation: validate the `method` argument first
  (so `method = "bad"` errors before control parsing), then apply
  `modifyList(method_defaults, control)`, then check for wrong-method keys
  and warn. This ensures the warning fires even when other errors would follow.

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
  - Happy paths: data.frame (assert `attr(result,"weight_col")==".weight"`),
    weighted_df, survey_taylor, survey_calibrated
  - Item 1c: verify `type = "count"` is the default
  - Happy path: numeric strata column (integer age; verifies no categorical restriction)
  - Numerical correctness vs `survey::postStratify()` within 1e-8 tolerance
    (inside `skip_if_not_installed("survey")` block)
  - SE-1 through SE-8 standard error paths (SE-8: 0-row + missing weight → empty_data)
  - Function-specific errors: variable_has_na, population_totals_invalid
    (item 8b: type="prop"), population_totals_invalid (item 8c: type="count"),
    population_cell_duplicate, population_cell_missing,
    population_cell_not_in_data, empty_stratum
  - Edge: single stratum variable, type = "prop"
  - History: full §IV.5 structure (step, operation == "poststratify",
    timestamp POSIXct, call, parameters, weight_stats before/after,
    convergence == NULL, package_version); step increment
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
- [ ] All 27 test blocks pass (items 1, 1b, 2, 2b, 2c, 3, 4, 5, 5b, 5c, 5d,
  6 SE-1–SE-8, 7, 8, 9, 10, 10b, 11, 12, 13, 14, 14b, 15, 16, 17)
- [ ] Dual pattern on all Layer 3 errors; all 7 function-specific error classes
  and 1 warning class in spec §XII.E tested
- [ ] `test_invariants()` called in every happy path test block
- [ ] `make_surveyweights_data(include_nonrespondents = TRUE)` used for main
  happy path tests
- [ ] Item 1: assert `attr(result, "weight_col") == ".weight"` when `weights = NULL`
- [ ] Item 1b: logical TRUE/FALSE `response_status` produces same output as integer
- [ ] Weight conservation (item 5): `sum(weights_before) ==
  sum(respondent_weights_after)` within 1e-10 tolerance
- [ ] Weight conservation WITH by grouping (item 5d): sum within each by-cell
  conserved within 1e-10 tolerance
- [ ] Hand-calculation (item 5b): 2-class example from spec §XIII verified
  within 1e-10 tolerance
- [ ] Numerical correctness vs `svrep::redistribute_weights()` within 1e-8
  tolerance (item 5c; inside `skip_if_not_installed("svrep")` block)
- [ ] History: full §IV.5 structure (step, operation == "nonresponse_weighting_class",
  timestamp POSIXct, call, parameters, weight_stats before/after,
  convergence == NULL, package_version)
- [ ] Separate test blocks for item 10 (integer/character `response_status`
  with wrong values) and item 10b (factor `response_status` — not binary
  regardless of its levels)
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
- [ ] All 10 test items from spec §XIII pass (items 1, 1b, 2, 3, 3b, 4, 5, 5b, 6, 7, 7b, 7c, 7d, 8)
- [ ] Item 1b: all-equal weights (`rep(1, n)`) → ESS = n exactly, CV = 0 exactly
  for both `effective_sample_size()` and `weight_variability()`
- [ ] Dual pattern on all Layer 3 errors; 6 error classes tested for
  `effective_sample_size()` / `weight_variability()`: `unsupported_class`,
  `weights_required`, `weights_not_found`, `weights_not_numeric` (item 7b),
  `weights_nonpositive` (item 7c), `weights_na` (item 7d) — items 7b/7c/7d
  each require a separate `test_that()` block
- [ ] Item 3b: auto-detected weights for `survey_taylor` input tested separately
  from item 3 (`survey_calibrated`) — `survey_taylor` uses `@variables$weights`
  and is a distinct code path
- [ ] `unsupported_class` tested (item 5b): throw
  `surveyweights_error_unsupported_class` for matrix/list input
- [ ] `effective_sample_size()` returns named scalar `c(n_eff = <value>)`;
  name `"n_eff"` is part of the API contract
- [ ] `weight_variability()` returns named scalar `c(cv = <value>)`;
  name `"cv"` is part of the API contract
- [ ] Item 8: `summarize_weights()` output has correct columns in specified order:
  `expect_identical(names(result), c("n", "n_positive", "n_zero", "mean", "cv",
  "min", "p25", "p50", "p75", "max", "ess"))` (group columns precede when `by` non-NULL)
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
- [ ] `calibrate()`, `rake()` (`method = "survey"`), `poststratify()` have numerical
  correctness tests against `survey` package (`skip_if_not_installed("survey")` inside
  each relevant `test_that()` block)
- [ ] `rake()` (`method = "anesrake"`) has numerical correctness test against
  `anesrake` package (`skip_if_not_installed("anesrake")` inside the block)
- [ ] `R/vendor/calibrate-greg.R`, `R/vendor/calibrate-ipf.R`, and
  `R/vendor/rake-anesrake.R` exist and carry attribution comment blocks
  (source package, version, author, license, URL)
- [ ] `VENDORED.md` is created and attributes all vendored code
- [ ] Reference for `adjust_nonresponse()` is documented in `VENDORED.md`
  (hand-calculation validation methodology)
- [ ] `surveyweights-conventions.md` stub is filled in with Phase 0 conventions
- [ ] `testing-surveyweights.md` stub is filled in with `test_invariants()`
  definition, `make_surveyweights_data()` spec, and updated file map
- [ ] Surveycore prerequisite PR is merged before any PR that uses survey objects
