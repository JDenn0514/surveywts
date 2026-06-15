# Implementation Plan: group-jackknife

**Status:** DONE
**Spec:** `plans/spec-group-jackknife.md` v1.2
**Test spec:** `plans/test-spec-group-jackknife.md`
**Target branch:** `develop`

---

## Overview

This plan delivers `create_group_jackknife_weights()`, a delete-a-group
jackknife (DAGJK) variance estimator for non-probability samples. It requires
two PRs: a small prerequisite PR that modifies two existing files (adds
`maxit`/`epsilon`/`trim_threshold` to the `ipw()` history entry and extracts a
shared overwrite helper), followed by the main feature PR that implements the
new function. The `plans/error-messages.md` file is already updated (tracked
modified in git).

---

## PR Map

- [x] PR 1: `feature/dagjk-prerequisites` — Add ipw history fields and extract shared overwrite helper
- [x] PR 2: `feature/nps-group-jackknife` — Implement `create_group_jackknife_weights()` and dispatcher entry

---

### PR 1: Prerequisites — ipw history fields + shared overwrite helper

**Branch:** `feature/dagjk-prerequisites`
**Depends on:** none

This PR makes two surgical modifications to existing files that are required
before the DAGJK function can be written. It has no new exported symbols and
no user-visible behavioral change.

**Files (in TDD order — tests first):**

1. `tests/testthat/test-nonprob-ipw.R`
   — Add three tests (red first) that assert the `ipw()` history entry
   includes `maxit`, `epsilon`, and `trim_threshold` fields with correct values
   for each of the three trim cases: `trim = FALSE` (NULL threshold), `trim = TRUE`
   with a detected threshold, and the default call (maxit=25L, epsilon=1e-8).

2. `tests/testthat/test-replicate-weights.R`
   — Add one test (red first) that the internal `.handle_repweights_overwrite()`
   function exists and is callable. Also verify (green already) that the existing
   bootstrap overwrite warning message text is unchanged after the refactor —
   this is the regression guard specified in the spec.

3. `R/nonprob-ipw.R`
   — Add `maxit = as.integer(maxit)`, `epsilon = epsilon`, and
   `trim_threshold = <resolved numeric or NULL>` to the `history_entry` list
   (lines ~1170–1192). `trim_threshold` is the resolved numeric threshold used
   for trimming (the value actually applied), or `NULL` if `trim = FALSE`.
   No signature change to `ipw()` required; no roxygen changes needed.

4. `R/replicate-weights.R`
   — Extract `.handle_repweights_overwrite(data, fn_name, warning_class)` as a
   new internal helper (above `.quasi_randomization_bootstrap()`). The helper
   detects `!is.null(data@variables$repweights)`, emits the supplied
   `warning_class` with the `"i"` bullet `"A previous call to {.fn {fn_name}}
   already produced {n_old} replicate column(s). They will be replaced."`,
   drops old replicate columns from `@data`, clears `@variables$repweights`,
   and returns the modified `data`. Then **replace** (not supplement) the
   inline overwrite block in `.quasi_randomization_bootstrap()` (lines 303–324)
   with a single call to `.handle_repweights_overwrite(data, fn_name =
   "create_bootstrap_weights", warning_class =
   "surveywts_warning_repweights_overwritten")`. The bootstrap warning message
   text must not change.

**Acceptance criteria:**

- [ ] All new tests confirmed failing (red) before implementation began
- [ ] `ipw()` history entry contains `maxit` (integer), `epsilon` (double),
  `trim_threshold` (numeric or NULL) — verified by three named test blocks.
  When `trim = TRUE`, `trim_threshold` equals `median(w) + 5*IQR(w)` computed
  from the pre-trim weight vector; the test verifies this numeric value within
  `1e-10` tolerance (not just that the field is non-NULL). When `trim = FALSE`,
  `trim_threshold` is `NULL`.
- [ ] `.handle_repweights_overwrite()` is an internal helper in `replicate-weights.R`
- [ ] Bootstrap overwrite warning message text is identical before and after
  refactor (no snapshot updates needed or expected)
- [ ] `devtools::check()` 0 errors, 0 warnings, ≤2 pre-approved notes
- [ ] `devtools::document()` run; NAMESPACE and man/ in sync
- [ ] Test coverage ≥ 98% overall

**Notes:**

- `trim_threshold` is the resolved value: capture `stats::median(w) + 5 *
  stats::IQR(w)` from the pre-trim weight vector (the `upper` bound computed
  immediately before calling `.trim_weights_internal()`) as a local variable,
  then store it in the history entry. If `trim = FALSE`, store `NULL`. Do not
  store the logical `trim` flag — DAGJK needs the exact numeric threshold to
  reproduce trimming per replicate via `pmin(w, trim_threshold)`.
- The existing `trim` logical field in the history entry is kept; `trim_threshold`
  is a new additional field.
- The inline overwrite block in `.quasi_randomization_bootstrap()` is at lines
  303–324 of `R/replicate-weights.R` (as of spec authoring). Confirm line numbers
  before editing.
- After the refactor, `data` returned from `.handle_repweights_overwrite()` must
  be reassigned: `data <- .handle_repweights_overwrite(data, ...)`.

---

### PR 2: `create_group_jackknife_weights()` + dispatcher

**Branch:** `feature/nps-group-jackknife`
**Depends on:** PR 1

The main feature PR. Creates `R/nps-group-jackknife.R` with the full DAGJK
pipeline and updates the dispatcher.

**Files (in TDD order — tests first):**

1. `tests/testthat/helper-test-data.R`
   — Add `make_dagjk_datasets()` helper that constructs Datasets A, B, C
   from `test-spec-group-jackknife.md §2`. Returns a named list. Dataset A:
   100-unit NPS + 100-unit reference `survey_taylor`, IPW only, seed-stable.
   Dataset B: same + `rake()` with literal margin targets. Dataset C: same as
   A but reference stored in ipw history. All use `set.seed()` internally.
   Do NOT add edge-case parameters; construct pathological inputs inline in
   tests. Dataset D (minimal 4 NPS + 4 ref) is a boundary edge case — per
   `testing-standards.md §4`, construct it inline in each test that needs it
   rather than in the helper.

2. `tests/testthat/test-nps-group-jackknife.R`
   — Full test file (red phase). Cover all scenarios from `test-spec-group-jackknife.md`:
   - §3.1 happy path structural invariants (use `test_invariants()`)
   - §3.2 default groups and whole-number coercion
   - §3.3 seed reproducibility (same seed → identical, different seed → non-identical)
   - §3.4 calibration history (Dataset B) — within-replicate calibration fires; the assertion must re-state raking target values as named numeric literals in the test file, independent of `make_dagjk_datasets()` and independent of the history entry (reading from either would be circular)
   - §3.5 dispatcher integration
   - §3.6–3.10 all error paths: use the dual pattern on each row in the tables from `test-spec-group-jackknife.md` §3.6–3.10 (`expect_error(class=)` + `expect_snapshot(error=TRUE)`)
   - §3.11 all warning paths (`expect_warning(class=)` + `expect_snapshot(warning=TRUE)`)
   - §3.12 edge cases (inline data for each)
   - §4 scaling factor named test: `"create_group_jackknife_weights() sets scale to (G-1)/G, not (n-1)/n"`
   - §5 model refit correctness named test: `"create_group_jackknife_weights() refits the logistic model per replicate"`
   - §6 zero-weight assignment named test
   - §3.13 invariant block (wrap in helper or inline at end of each happy-path test)
   - Direct test for `.dagjk_single_replicate()` degenerate error class (§3.10)

3. `tests/testthat/test-replicate-dispatch.R`
   — Add one test block: `create_replicate_weights(data, method = "group-jackknife", groups = 10L, seed = 42L)` returns identical result to `create_group_jackknife_weights(data, groups = 10L, seed = 42L)`.

4. `R/nps-group-jackknife.R`
   — New file. Contains `create_group_jackknife_weights()` (exported) and all
   private helpers for the DAGJK pipeline. Structure:
   - `.validate_groups_arg(groups, combined_n)` — validates `groups` in the
     order specified by spec §3.4 (invalid → not whole → too small → exceeds N)
   - `.dagjk_single_replicate(g, group_assignments, nps_data, ref_data, ref_weights, ipw_entry, calib_entry, use_level_b, ref_design)` — per-replicate engine. Throws `surveywts_error_dagjk_degenerate_replicate` on any failure condition (NA propensities, out-of-range propensities, negative adjustment factor, calibration error, no surviving NPS units). Called inside `tryCatch()` in the main loop.
   - `create_group_jackknife_weights()` — public function. Full roxygen2 with
     all 13 `@details` points, `@references`, `@family replicate-weights`, `@export`.
   Validation order: `data` class → `reference_sample` class → `groups` → ipw
   history → reference resolution → ceiling check (groups > combined N).
   Overwrite check via `.handle_repweights_overwrite()` from `R/replicate-weights.R`.
   Small-groups warning before the loop. Main loop with `tryCatch()` per replicate.
   Post-loop: >10% failure warning, negative weight warning, final assembly.

5. `R/replicate-weights.R`
   — Add a `data.frame` branch to `.validate_reference_sample()` per spec §3.4.
   When `reference_sample` is a `data.frame`, the error must include an `'i'`
   bullet: `"Use {.fn survey::svydesign} to convert an SRS data frame to a
   {.cls survey_taylor} object."` This is a shared helper also called by the
   bootstrap and nonresponse pipelines — after modifying it, run the existing
   bootstrap and nonresponse test files to confirm no regressions (no snapshot
   diffs expected).

6. `R/replicate-dispatch.R`
   — Add `"group-jackknife"` to the `method` argument vector and the `switch()`
   body. Update `@return` documentation to note that `method = "group-jackknife"`
   returns `survey_nonprob` rather than `survey_replicate`.

7. `changelog/replicate/feature-nps-group-jackknife.md`
   — New changelog entry for `create_group_jackknife_weights()` following the
   project convention (`changelog/replicate/feature-*.md`).

8. Run `devtools::document()` — regenerates NAMESPACE and `man/` Rd files.

**Acceptance criteria:**

- [ ] All new tests confirmed failing (red) before implementation began
- [ ] `devtools::check()` 0 errors, 0 warnings, ≤2 pre-approved notes
- [ ] `devtools::document()` run; NAMESPACE and man/ in sync
- [ ] §3.1 happy path: all structural invariants listed in test-spec §3.1 pass
- [ ] §3.2 default groups = 50 and whole-number coercion pass
- [ ] §3.3 seed reproducibility: identical outputs with same seed
- [ ] §3.4 calibration refit: replicate weights differ between Dataset A and B; within-replicate margins match literal targets within `1e-6`
- [ ] History entry `groups_failed` equals `G - groups_used` on a run where at least one replicate fails
- [ ] History entry `seed` matches the `seed` argument (verified for both a non-NULL seed and `seed = NULL`)
- [ ] §3.5 dispatcher: `create_replicate_weights(..., method = "group-jackknife")` is identical to direct call
- [ ] §3.6–3.10 all error paths: dual pattern (`class=` + snapshot) for all test scenarios from `test-spec-group-jackknife.md` §3.6–3.10, using the dual pattern on each row in the tables (including a direct internal call for `surveywts_error_dagjk_degenerate_replicate`)
- [ ] §3.11 all warning paths: warning + snapshot for all 4 warning classes
- [ ] §4 scaling factor test: scale = 0.9 for G=10, not 0.995
- [ ] §5 model refit: ratio of replicate weights to full-sample weights is non-constant
- [ ] §6 zero-weight assignment: group-1 units have repwt_1 = 0 and repwt_g > 0 for g ≠ 1
- [ ] §3.13 invariants pass on every happy-path result
- [ ] Snapshot for `reference_sample = data.frame(...)` confirms `'i'` bullet about `survey::svydesign()` is present
- [ ] Existing bootstrap and nonresponse test snapshots pass without updates after `.validate_reference_sample()` modification (no snapshot diffs expected on any bootstrap or nonresponse test)
- [ ] Line coverage on `R/nps-group-jackknife.R` ≥ 98%
- [ ] All `@details` points 1–13 present in roxygen2; all three `@references` citations present

**Notes:**

- **Validation order is strict** (spec §3.4): `data` class first (via
  `.validate_replicate_input()` then DAGJK-specific `survey_taylor` check),
  then `reference_sample` class, then `groups` (invalid → not-whole → too-small),
  then ipw history, then reference resolution, then ceiling check.
- **`data.frame` branch in `.validate_reference_sample()`**: The spec requires
  modifying this shared helper to add the `"Use survey::svydesign() to convert
  an SRS data frame to a survey_taylor object."` `'i'` bullet when the input is
  a `data.frame`. After modifying the helper, run existing bootstrap and
  nonresponse tests to confirm no regressions. The snapshot for `reference_sample
  = data.frame(...)` in the DAGJK test file must be reviewed manually to confirm
  this bullet appears.
- **Overwrite helper call**: The DAGJK function calls `.handle_repweights_overwrite(data,
  fn_name = "create_group_jackknife_weights", warning_class =
  "surveywts_warning_dagjk_repweights_overwritten")`. This is a different `fn_name`
  and `warning_class` from the bootstrap call.
- **Per-replicate trim**: If `entry$trim_threshold` is non-NULL, apply `pmin(w, trim_threshold)` (or the equivalent trimming operation) to replicate pseudo-weights inside `.dagjk_single_replicate()`. If NULL, skip trimming. No `is.element()` check needed — `NULL` covers both the absent-field and explicit-FALSE cases.
- **`N_hat_g` scaling**: After computing replicate pseudo-weights `1/pi_hat`, scale them to sum to `N_hat_g` (the sum of adjusted reference weights in that replicate). This keeps `theta_g` on the same scale as `theta` for DAGJK centering. The full-sample `ipw()` weights already sum to `N_hat` (estimated population size); replicate weights must mirror this convention.
- **Failed replicates**: When replicates fail, the surviving replicate columns are renumbered sequentially from `repwt_1` to `repwt_{G_success}`. `@variables$scale` is updated to `(G_success - 1) / G_success`. The history entry records both `groups` (original G) and `groups_used` (G_success).
- **`.dagjk_single_replicate()` is a private helper** (`.`-prefixed) but must be
  accessible for direct testing via `surveywts:::.dagjk_single_replicate()`. Since it is
  not exported, no `@export` tag.
- **`@variables$type` = `"group-jackknife"`**: This is a surveywts-specific value;
  downstream `survey`-package functions expecting `"JKn"` will not recognize it.
  Document this in `@details` point 13.
- **Dispatcher `@return` update**: The existing `@return` says `"A survey_replicate"`.
  Update to note that `method = "group-jackknife"` returns `survey_nonprob`.
  Run `devtools::document()` after this change.
- **`maxit`/`epsilon` fallback**: When these fields are absent from the ipw history
  entry (weights created before this PR), fall back to `25L` and `1e-8` respectively
  using `entry$maxit %||% 25L` (or `if (is.null(entry$maxit)) 25L else entry$maxit`).
  Use rlang's `%||%` via `rlang::`%||%``.
