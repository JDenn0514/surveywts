# Replicate Weight Generation Implementation Plan (v0.2.0)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement all eight deliverables from spec v1.3: six `create_*_weights()` functions, the `create_replicate_weights()` dispatcher, `as_taylor_design()`, and the `survey_replicate` print method.

**Architecture:** Six thin wrappers around `survey` and `svrep` backends, sharing a common conversion pipeline (`.convert_and_call()`). `surveycore::from_svydesign()` is **bypassed entirely** due to a bug in v0.8.2 that leaves `@variables$repweights` NULL for replicate designs — see the Critical Note below. All six wrappers extract the replicate matrix directly from the backend output and construct `survey_replicate` manually.

**Tech Stack:** R, S7, svrep (≥ 0.6.0), survey (already Imports), surveycore (≥ 0.8.0), withr (move to Imports from Suggests), rlang, cli, tidyselect

---

## CRITICAL IMPLEMENTATION NOTE: `from_svydesign()` Bug

`surveycore::from_svydesign()` in v0.8.2 **does NOT populate `@variables$repweights`** for `svyrep.design` objects — it calls `colnames(x$repweights)` which returns `NULL` for both `survey::as.svrepdesign()` and `svrep::as_bootstrap_design()` outputs. This means the returned `survey_replicate` would have empty `@variables$repweights` and no replicate columns in `@data`.

**Fix:** `.convert_and_call()` bypasses `from_svydesign()` entirely and constructs `survey_replicate` manually:

```r
rep_matrix <- as.matrix(svyrep_obj$repweights)   # works for both matrix and
n_rep      <- ncol(rep_matrix)                    # repweights_compressed classes
rep_names  <- paste0("rep_", seq_len(n_rep))
base_data  <- as.data.frame(svyrep_obj$variables)
rep_df     <- as.data.frame(rep_matrix)
names(rep_df) <- rep_names
combined   <- cbind(base_data, rep_df)
result     <- surveycore::survey_replicate(
  data = combined, variables = variables, metadata = data@metadata
)
```

The `surveycore` minimum version floor (`>= 0.8.0`) is set to the earliest version where `surveycore::as_svydesign()` and the `survey_replicate()` constructor both work. The buggy `from_svydesign()` is never called.

---

## File Structure

```
R/
├── replicate-weights.R     # All 5 shared helpers + 6 create_*_weights() functions
├── replicate-dispatch.R    # create_replicate_weights() dispatcher + as_taylor_design()
├── replicate-print.R       # S7 print method for survey_replicate
tests/testthat/
├── test-replicate-weights.R    # Tests for replicate-weights.R
├── test-replicate-print.R      # Tests for replicate-print.R
├── test-replicate-dispatch.R   # Tests for replicate-dispatch.R
plans/
├── error-messages.md       # Add 15 new error + 2 warning classes
DESCRIPTION                 # svrep + withr → Imports; surveycore floor bump
tests/testthat/helper-test-data.R  # Add make_taylor_design(), make_paired_design(),
                                    # extend test_invariants()
R/utils.R                   # Add "replicate_creation" case to .format_history_step()
```

---

## PR Map

**Dependencies:** PRs must be merged in numeric order. Each PR branches from `develop` after the previous PR is merged — do not cut PR N+1 until PR N is merged into `develop`.

- [x] PR 1: `feature/replicate-infrastructure` — DESCRIPTION, error-messages.md, test helper extensions, utils.R update
- [x] PR 2: `feature/replicate-bootstrap` — all 5 shared helpers + `create_bootstrap_weights()`
- [x] PR 3: `feature/replicate-jackknife` — `create_jackknife_weights()`
- [x] PR 4: `feature/replicate-brr` — `create_brr_weights()`
- [x] PR 5: `feature/replicate-gen-boot` — `create_gen_boot_weights()`
- [x] PR 6: `feature/replicate-gen-rep` — `create_gen_rep_weights()`
- [x] PR 7: `feature/replicate-sdr` — `create_sdr_weights()`
- [ ] PR 8: `feature/replicate-print` — S7 print method for `survey_replicate`
- [ ] PR 9: `feature/replicate-dispatch` — `create_replicate_weights()` + `as_taylor_design()`

---

## PR 1: Shared Infrastructure

**Branch:** `feature/replicate-infrastructure`
**Files:** `DESCRIPTION`, `plans/error-messages.md`, `tests/testthat/helper-test-data.R`, `R/utils.R`

### Task 1.1: Create branch

- [ ] **Step 1: Create branch**

```bash
git checkout develop
git pull origin develop
git checkout -b feature/replicate-infrastructure
```

### Task 1.2: Update DESCRIPTION

- [ ] **Step 1: Update `DESCRIPTION`**

First, remove `svrep` and `withr` from the `Suggests` field. Then add them to `Imports` and bump `surveycore` to the new floor:

```
Imports:
    anesrake (>= 0.80),
    cli (>= 3.6.0),
    dplyr (>= 1.1.0),
    rlang (>= 1.1.0),
    S7 (>= 0.2.0),
    survey (>= 4.2-1),
    surveycore (>= 0.8.0),
    svrep (>= 0.6.0),
    tibble (>= 3.2.0),
    tidyselect (>= 1.2.0),
    withr (>= 2.5.0)
Suggests:
    covr,
    knitr,
    rmarkdown,
    testthat (>= 3.2.0)
```

- [ ] **Step 2: Verify `devtools::check()` passes**

```r
devtools::check()
```

Expected: 0 errors, 0 warnings, ≤2 notes

### Task 1.3: Add error classes to `plans/error-messages.md`

- [ ] **Step 1: Add a new section under `## Errors` in `plans/error-messages.md`**

After the `### Diagnostics` section, add:

```markdown
### Replicate Weight Functions

| Class | Thrown by | Condition |
|-------|-----------|-----------|
| `surveywts_error_already_replicate` | All `create_*_weights()` | Input is already `survey_replicate` |
| `surveywts_error_not_survey_design` | All `create_*_weights()` | Input is `data.frame` or `weighted_df` |
| `surveywts_error_replicates_not_positive` | Bootstrap, jackknife (random-groups), gen-boot, SDR | `replicates` < 2 |
| `surveywts_error_replicates_not_whole_number` | All methods accepting `replicates` | `replicates` has non-zero fractional part |
| `surveywts_error_brr_requires_paired_design` | `create_brr_weights()` | Stratum has ≠ 2 PSUs, or input is `survey_nonprob` |
| `surveywts_error_brr_rho_invalid` | `create_brr_weights()` | `rho < 0` or `rho >= 1` |
| `surveywts_error_replicates_required_for_jkn` | `create_jackknife_weights()` | `type = "random-groups"` but `replicates` is `NULL` |
| `surveywts_error_jackknife_type_unsupported_for_nonprob` | `create_jackknife_weights()` | `data` is `survey_nonprob` and `type = "random-groups"` |
| `surveywts_error_nonprob_requires_probability_design` | `create_gen_boot_weights()`, `create_gen_rep_weights()`, `create_sdr_weights()` | `data` is `survey_nonprob` |
| `surveywts_error_sort_var_has_na` | `create_sdr_weights()` | `sort_var` column contains `NA` |
| `surveywts_error_variance_estimator_requires_aux` | `create_gen_boot_weights()`, `create_gen_rep_weights()` | `variance_estimator = "Deville-Tille"` but `aux_var_names = NULL` |
| `surveywts_error_no_taylor_structure` | `as_taylor_design()` | No `"replicate_creation"` entry in history |
| `surveywts_error_taylor_from_calibrated_replicate` | `as_taylor_design()` | Post-creation weight adjustment in history |
| `surveywts_error_taylor_from_nonprob_replicate` | `as_taylor_design()` | Source was `survey_nonprob` |
| `surveywts_error_unsupported_class` | All `create_*_weights()`, `as_taylor_design()` | Input class is not a supported survey design type |
```

- [ ] **Step 2: Add under `## Warnings`**

```markdown
| `surveywts_warning_already_taylor` | `as_taylor_design()` | Input is already `survey_taylor` |
| `surveywts_warning_taylor_loses_variance` | `as_taylor_design()` | Converting drops replicate weights |
```

### Task 1.4: Extend `tests/testthat/helper-test-data.R`

- [ ] **Step 1: Write failing test confirming functions don't exist yet**

In a scratch file or REPL, confirm `make_taylor_design` is not yet defined:

```r
testthat::expect_error(make_taylor_design(), "could not find function")
```

- [ ] **Step 2: Add `make_taylor_design()` and `make_paired_design()` to `helper-test-data.R`**

Append to the end of `tests/testthat/helper-test-data.R`:

```r
# Clustered, stratified design for general replicate weight testing.
# Returns a survey_taylor with PSU IDs, strata, and base weights.
make_taylor_design <- function(
  n = 500L,
  n_strata = 4L,
  psus_per_stratum = 5L,
  seed = 42L
) {
  set.seed(seed)
  total_psus <- n_strata * psus_per_stratum
  df <- data.frame(
    id          = seq_len(n),
    psu_id      = rep(seq_len(total_psus), length.out = n),
    stratum     = rep(rep(seq_len(n_strata), each = psus_per_stratum), length.out = n),
    y           = rnorm(n),
    base_weight = exp(rnorm(n, 0, 0.4))
  )
  surveycore::as_survey(df, ids = psu_id, strata = stratum, weights = base_weight)
}

# Paired-PSU design for BRR tests.
# Returns a survey_taylor with exactly 2 PSUs per stratum.
make_paired_design <- function(n_strata = 3L, obs_per_psu = 10L, seed = 42L) {
  set.seed(seed)
  n_psus <- n_strata * 2L
  n      <- n_psus * obs_per_psu
  df <- data.frame(
    id          = seq_len(n),
    psu_id      = rep(seq_len(n_psus), each = obs_per_psu),
    stratum     = rep(seq_len(n_strata), each = 2L * obs_per_psu),
    y           = rnorm(n),
    base_weight = exp(rnorm(n, 0, 0.4))
  )
  surveycore::as_survey(df, ids = psu_id, strata = stratum, weights = base_weight)
}
```

- [ ] **Step 3: Extend `test_invariants()` with the `survey_replicate` branch**

Replace the existing `test_invariants()` function with:

```r
test_invariants <- function(obj) {
  if (inherits(obj, "weighted_df")) {
    wt_col <- attr(obj, "weight_col")
    testthat::expect_true(is.character(wt_col) && length(wt_col) == 1)
    testthat::expect_true(wt_col %in% names(obj))
    testthat::expect_true(is.numeric(obj[[wt_col]]))
    testthat::expect_true(is.list(attr(obj, "weighting_history")))
  }
  if (exists("survey_nonprob") &&
        S7::S7_inherits(obj, survey_nonprob)) {
    testthat::expect_true(is.character(obj@variables$weights))
    testthat::expect_true(obj@variables$weights %in% names(obj@data))
    testthat::expect_true(is.numeric(obj@data[[obj@variables$weights]]))
    w <- obj@data[[obj@variables$weights]]
    testthat::expect_true(all(w >= 0) && any(w > 0))
  }
  if (S7::S7_inherits(obj, surveycore::survey_taylor)) {
    testthat::expect_true(is.character(obj@variables$weights))
    testthat::expect_true(obj@variables$weights %in% names(obj@data))
    testthat::expect_true(is.numeric(obj@data[[obj@variables$weights]]))
    w <- obj@data[[obj@variables$weights]]
    testthat::expect_true(all(w >= 0) && any(w > 0))
  }
  if (S7::S7_inherits(obj, surveycore::survey_replicate)) {
    testthat::expect_true(is.character(obj@variables$weights))
    testthat::expect_true(is.character(obj@variables$repweights))
    testthat::expect_true(length(obj@variables$repweights) >= 2L)
    testthat::expect_true(all(obj@variables$repweights %in% names(obj@data)))
  }
}
```

- [ ] **Step 4: Run all existing tests to confirm no regression**

```r
devtools::test()
```

Expected: all tests pass

### Task 1.5: Update `.format_history_step()` in `R/utils.R`

The `"replicate_creation"` operation type needs a `switch` case; otherwise it falls through to the default (bare operation name), which is acceptable but shows less information.

- [ ] **Step 1: Add the `"replicate_creation"` case**

In `R/utils.R`, inside the `switch(op, ...)` call in `.format_history_step()`, add before the default case:

```r
    "replicate_creation" = {
      method_str <- entry$method
      params     <- entry$parameters
      n_rep      <- params$replicates
      # Include type when present (bootstrap, jackknife); omit for methods
      # that don't have a type sub-parameter (e.g., BRR uses rho, SDR has none).
      type_str <- if (!is.null(params$type)) {
        paste0(", type = \"", params$type, "\"")
      } else {
        ""
      }
      rep_str <- if (!is.null(n_rep)) paste0(", replicates = ", n_rep) else ""
      paste0("replicate_creation (method = \"", method_str, "\"", type_str, rep_str, ")")
    },
```

- [ ] **Step 2: Run `devtools::check()`**

```r
devtools::check()
```

Expected: 0 errors, 0 warnings, ≤2 notes

- [ ] **Step 3: Commit**

```bash
Rscript -e "devtools::document()"
git add DESCRIPTION plans/error-messages.md tests/testthat/helper-test-data.R R/utils.R NAMESPACE
git commit -m "chore(replicate): add infrastructure for replicate weight generation"
```

- [ ] **Step 4: Create changelog entry**

Create `changelog/replicate/feature-replicate-infrastructure.md` following the `changelog-workflow` skill format, then commit:

```bash
git add changelog/replicate/feature-replicate-infrastructure.md
git commit -m "chore(replicate): add changelog for replicate-infrastructure"
```

- [ ] **Step 5: Open PR to `develop`**

---

## PR 2: Bootstrap + All Shared Helpers

**Branch:** `feature/replicate-bootstrap`
**Files:** `R/replicate-weights.R` (new), `tests/testthat/test-replicate-weights.R` (new), `.claude/rules/surveywts-conventions.md` (modify)

### Task 2.1: Create branch and write failing tests

- [ ] **Step 1: Create branch**

```bash
git checkout develop && git pull origin develop
git checkout -b feature/replicate-bootstrap
```

- [ ] **Step 2: Write failing tests in `tests/testthat/test-replicate-weights.R`**

```r
# tests/testthat/test-replicate-weights.R

# ---- Shared input-class errors (13a–13d) ------------------------------------

test_that("create_bootstrap_weights() rejects data.frame input", {
  df <- make_surveywts_data(seed = 1)
  expect_error(
    create_bootstrap_weights(df),
    class = "surveywts_error_not_survey_design"
  )
  expect_snapshot(error = TRUE, create_bootstrap_weights(df))
})

test_that("create_bootstrap_weights() rejects survey_replicate input", {
  skip_if_not_installed("svrep")
  td <- make_taylor_design(seed = 1)
  rep <- create_bootstrap_weights(td, replicates = 10L, seed = 1L)
  expect_error(
    create_bootstrap_weights(rep),
    class = "surveywts_error_already_replicate"
  )
  expect_snapshot(error = TRUE, create_bootstrap_weights(rep))
})

test_that("create_bootstrap_weights() rejects unsupported class", {
  expect_error(
    create_bootstrap_weights(list(x = 1)),
    class = "surveywts_error_unsupported_class"
  )
  expect_snapshot(error = TRUE, create_bootstrap_weights(list(x = 1)))
})

# ---- Bootstrap-specific errors (3c–3d) -------------------------------------

test_that("create_bootstrap_weights() rejects replicates = 0", {
  td <- make_taylor_design(seed = 1)
  expect_error(
    create_bootstrap_weights(td, replicates = 0L),
    class = "surveywts_error_replicates_not_positive"
  )
  expect_snapshot(error = TRUE, create_bootstrap_weights(td, replicates = 0L))
})

test_that("create_bootstrap_weights() rejects replicates = 1 (boundary: min is 2)", {
  td <- make_taylor_design(seed = 1)
  expect_error(
    create_bootstrap_weights(td, replicates = 1L),
    class = "surveywts_error_replicates_not_positive"
  )
  expect_snapshot(error = TRUE, create_bootstrap_weights(td, replicates = 1L))
})

test_that("create_bootstrap_weights() rejects fractional replicates", {
  td <- make_taylor_design(seed = 1)
  expect_error(
    create_bootstrap_weights(td, replicates = 1.5),
    class = "surveywts_error_replicates_not_whole_number"
  )
  expect_snapshot(error = TRUE, create_bootstrap_weights(td, replicates = 1.5))
})

# ---- Happy path (1a–1f) -----------------------------------------------------

test_that("create_bootstrap_weights() returns survey_replicate from survey_taylor", {
  skip_if_not_installed("svrep")
  td     <- make_taylor_design(seed = 1)
  result <- create_bootstrap_weights(td, replicates = 50L, seed = 42L)
  test_invariants(result)
  expect_true(S7::S7_inherits(result, surveycore::survey_replicate))
  expect_identical(result@variables$type, "bootstrap")
  expect_identical(length(result@variables$repweights), 50L)
})

test_that("create_bootstrap_weights() accepts whole-number replicates coerced silently", {
  skip_if_not_installed("svrep")
  td     <- make_taylor_design(seed = 1)
  result <- create_bootstrap_weights(td, replicates = 50, seed = 42L)
  test_invariants(result)
  expect_identical(length(result@variables$repweights), 50L)
})

test_that("create_bootstrap_weights() accepts survey_nonprob input", {
  skip_if_not_installed("svrep")
  df  <- make_surveywts_data(seed = 1)
  np  <- surveycore::survey_nonprob(
    data      = df,
    variables = list(weights = "base_weight"),
    metadata  = surveycore::survey_metadata()
  )
  result <- create_bootstrap_weights(np, replicates = 20L, seed = 1L)
  test_invariants(result)
  expect_identical(result@variables$type, "bootstrap")
})

test_that("create_bootstrap_weights() preserves metadata through conversion", {
  skip_if_not_installed("svrep")
  td     <- make_taylor_design(seed = 1)
  result <- create_bootstrap_weights(td, replicates = 10L, seed = 1L)
  test_invariants(result)
  # weighting history has exactly one entry of operation = "replicate_creation"
  history <- result@metadata@weighting_history
  expect_length(history, 1L)
  expect_identical(history[[1L]]$operation, "replicate_creation")
  expect_identical(history[[1L]]$method, "bootstrap")
})

# ---- Equivalence with svrep (2a) -------------------------------------------

test_that("create_bootstrap_weights() matches svrep::as_bootstrap_design() directly", {
  skip_if_not_installed("svrep")
  td <- make_taylor_design(n = 100L, seed = 7L)

  # Direct svrep call with same seed
  set.seed(99L)
  direct_svyrep <- svrep::as_bootstrap_design(
    surveycore::as_svydesign(td),
    type       = "Rao-Wu-Yue-Beaumont",
    replicates = 50L,
    mse        = TRUE
  )
  direct_mat <- as.matrix(direct_svyrep$repweights)

  # surveywts wrapper with same seed
  result     <- create_bootstrap_weights(td, replicates = 50L, seed = 99L)
  test_invariants(result)
  result_mat <- as.matrix(result@data[, result@variables$repweights])

  expect_equal(result_mat, direct_mat, tolerance = 1e-10)
})

# ---- Spec §XIII 1b: default replicates = 500 ---------------------------------

test_that("create_bootstrap_weights() default replicates = 500 produces 500 columns", {
  skip_if_not_installed("svrep")
  td     <- make_taylor_design(seed = 1)
  result <- create_bootstrap_weights(td, seed = 1L)
  test_invariants(result)
  expect_identical(length(result@variables$repweights), 500L)
})

# ---- Spec §XIII 1c: different type values produce different results ----------

test_that("create_bootstrap_weights() Rao-Wu and Rao-Wu-Yue-Beaumont differ", {
  skip_if_not_installed("svrep")
  td  <- make_taylor_design(seed = 1)
  r1  <- create_bootstrap_weights(td, type = "Rao-Wu", replicates = 50L, seed = 1L)
  r2  <- create_bootstrap_weights(td, type = "Rao-Wu-Yue-Beaumont", replicates = 50L, seed = 1L)
  test_invariants(r1)
  test_invariants(r2)
  mat1 <- as.matrix(r1@data[, r1@variables$repweights])
  mat2 <- as.matrix(r2@data[, r2@variables$repweights])
  expect_false(isTRUE(all.equal(mat1, mat2)))
})

# ---- Spec §XIII 1d: mse = FALSE passes through correctly ---------------------

test_that("create_bootstrap_weights() mse = FALSE is stored in history", {
  skip_if_not_installed("svrep")
  td     <- make_taylor_design(seed = 1)
  result <- create_bootstrap_weights(td, replicates = 20L, mse = FALSE, seed = 1L)
  test_invariants(result)
  history <- result@metadata@weighting_history
  expect_false(history[[1L]]$parameters$mse)
})

# ---- Spec §XIII 19a: edge cases ----------------------------------------------

test_that("create_bootstrap_weights() single-PSU-per-stratum propagates backend error", {
  skip_if_not_installed("svrep")
  # single PSU per stratum — RWYB bootstrap requires >= 2 PSUs per stratum
  df        <- make_surveywts_data(n = 10L, seed = 1L)
  df$strat1 <- seq_len(nrow(df))  # each row is its own stratum
  td <- surveycore::as_survey(df, ids = id, strata = strat1, weights = base_weight)
  expect_error(create_bootstrap_weights(td, replicates = 10L, seed = 1L))
})

test_that("create_bootstrap_weights() all-equal base weights succeeds", {
  skip_if_not_installed("svrep")
  df             <- make_surveywts_data(n = 50L, seed = 1L)
  df$base_weight <- rep(1, nrow(df))
  td     <- surveycore::as_survey(df, ids = id, weights = base_weight)
  result <- create_bootstrap_weights(td, replicates = 20L, seed = 1L)
  test_invariants(result)
  rep_mat <- as.matrix(result@data[, result@variables$repweights])
  expect_true(all(abs(colMeans(rep_mat) - 1) < 0.5))  # means near base weight
})
```

- [ ] **Step 3: Run tests to confirm they all fail (functions don't exist yet)**

```r
devtools::test(filter = "replicate-weights")
```

Expected: all tests fail with "could not find function"

### Task 2.2: Implement shared helpers and `create_bootstrap_weights()`

- [ ] **Step 1: Create `R/replicate-weights.R`** with the five shared helpers:

```r
# R/replicate-weights.R
#
# create_bootstrap_weights(), create_jackknife_weights(),
# create_brr_weights(), create_gen_boot_weights(),
# create_gen_rep_weights(), create_sdr_weights()
# and all shared internal helpers.

# ============================================================================
# .validate_replicate_input()
# ============================================================================

.validate_replicate_input <- function(data) {
  if (inherits(data, "data.frame") || inherits(data, "weighted_df")) {
    cli::cli_abort(
      c(
        "x" = "{.arg data} is a {.cls {class(data)[[1]]}}, not a survey design.",
        "i" = "This function requires a {.cls survey_taylor} or {.cls survey_nonprob} object.",
        "v" = "Convert with {.fn surveycore::as_survey}."
      ),
      class = "surveywts_error_not_survey_design"
    )
  }
  if (S7::S7_inherits(data, surveycore::survey_replicate)) {
    cli::cli_abort(
      c(
        "x" = "{.arg data} is already a {.cls survey_replicate}.",
        "i" = "Replicate weights cannot be created from a design that already has replicates."
      ),
      class = "surveywts_error_already_replicate"
    )
  }
  if (!S7::S7_inherits(data, surveycore::survey_base)) {
    cls <- class(data)[[1L]]
    cli::cli_abort(
      c(
        "x" = "{.arg data} is {.cls {cls}}, which is not a supported input class.",
        "i" = "Supported classes: {.cls survey_taylor} and {.cls survey_nonprob}.",
        "v" = "Use {.fn surveycore::as_survey} or {.fn surveycore::survey_nonprob}."
      ),
      class = "surveywts_error_unsupported_class"
    )
  }
  invisible(TRUE)
}

# ============================================================================
# .validate_replicates_arg()
# ============================================================================

# Validates the `replicates` argument: accepts whole numbers, coerces to
# integer. Returns NULL if replicates is NULL (caller handles the NULL case).
# min_val defaults to 2; SDR passes min_val = 4.
.validate_replicates_arg <- function(replicates, min_val = 2L) {
  if (is.null(replicates)) return(NULL)
  if (!is.numeric(replicates) || length(replicates) != 1L || is.na(replicates)) {
    cli::cli_abort(
      c("x" = "{.arg replicates} must be a single number."),
      class = "surveywts_error_replicates_not_positive"
    )
  }
  if (replicates %% 1 != 0) {
    cli::cli_abort(
      c(
        "x" = "{.arg replicates} must be a whole number, not {.val {replicates}}.",
        "v" = "Use an integer value, e.g. {.code replicates = {round(replicates)}}."
      ),
      class = "surveywts_error_replicates_not_whole_number"
    )
  }
  if (replicates < min_val) {
    cli::cli_abort(
      c(
        "x" = "{.arg replicates} must be at least {min_val}, got {.val {replicates}}."
      ),
      class = "surveywts_error_replicates_not_positive"
    )
  }
  as.integer(replicates)
}

# ============================================================================
# .snapshot_variables_for_history()
# ============================================================================

# Captures the full @variables list and a nonprob flag for the
# "replicate_creation" history entry. Used by as_taylor_design() to
# reconstruct the original Taylor design and detect nonprob sources.
# A boolean is used instead of a class string because attr(cls, "package")
# is unreliable for S7 classes and could produce "::survey_nonprob" if NULL.
.snapshot_variables_for_history <- function(data) {
  list(
    variables = data@variables,
    is_nonprob = S7::S7_inherits(data, surveycore::survey_nonprob)
  )
}

# ============================================================================
# .convert_and_call()
# ============================================================================

# Core conversion pipeline. Converts S7 design to svydesign, calls backend_fn,
# then manually constructs survey_replicate (bypassing from_svydesign() which
# has a bug in surveycore <= 0.8.2 where @variables$repweights is not populated).
#
# Arguments:
#   data       : survey_taylor or survey_nonprob
#   backend_fn : function(svydesign) -> svyrep.design
#   method     : character(1) — e.g. "bootstrap", "jackknife"
#   params     : named list of method-specific parameters for the history entry
#   seed       : integer(1) or NULL — if non-NULL, withr::local_seed() is used
.convert_and_call <- function(data, backend_fn, method, params, seed = NULL) {
  if (!is.null(seed)) withr::local_seed(seed)
  svydesign_obj <- surveycore::as_svydesign(data)
  svyrep_obj    <- backend_fn(svydesign_obj)

  # Extract replicate weight matrix. Both `matrix` (svrep bootstrap, gen-boot,
  # gen-rep) and `repweights_compressed` (survey JKn/BRR, svrep random-group JK)
  # support as.matrix().
  rep_matrix  <- as.matrix(svyrep_obj$repweights)
  n_rep       <- ncol(rep_matrix)
  rep_names   <- paste0("rep_", seq_len(n_rep))

  base_data   <- as.data.frame(svyrep_obj$variables)
  rep_df      <- as.data.frame(rep_matrix)
  names(rep_df) <- rep_names
  combined    <- cbind(base_data, rep_df)

  variables   <- list(
    weights    = data@variables$weights,
    repweights = rep_names,
    type       = svyrep_obj$type,
    scale      = svyrep_obj$scale,
    rscales    = svyrep_obj$rscales,
    fpc        = data@variables$fpc,
    fpctype    = if (!is.null(svyrep_obj$fpctype)) svyrep_obj$fpctype else "fraction",
    mse        = isTRUE(svyrep_obj$mse)
  )

  result    <- surveycore::survey_replicate(
    data      = combined,
    variables = variables,
    metadata  = data@metadata
  )

  # Append replicate_creation history entry. Snapshot the full @variables so
  # as_taylor_design() can reconstruct the original Taylor design.
  snapshot  <- .snapshot_variables_for_history(data)
  new_entry <- list(
    step          = length(data@metadata@weighting_history) + 1L,
    operation     = "replicate_creation",
    timestamp     = Sys.time(),
    method        = method,
    parameters    = params,
    source_design = snapshot
  )
  meta                      <- result@metadata
  meta@weighting_history    <- c(meta@weighting_history, list(new_entry))
  result@metadata           <- meta

  result
}

# ============================================================================
# create_bootstrap_weights()
# ============================================================================

#' Create bootstrap replicate weights
#'
#' Generates bootstrap replicate weights via [svrep::as_bootstrap_design()].
#' Both `survey_taylor` and `survey_nonprob` inputs are supported.
#'
#' @param data A `survey_taylor` or `survey_nonprob` design object.
#' @param replicates `integer(1)`, default `500L`. Number of bootstrap
#'   replicates. Must be ≥ 2. Whole-number doubles are coerced silently.
#' @param ... Must be empty. Forces all subsequent arguments to be named.
#' @param type `character(1)`. Bootstrap variant passed to
#'   [svrep::as_bootstrap_design()]. One of `"Rao-Wu-Yue-Beaumont"` (default),
#'   `"Rao-Wu"`, `"Antal-Tille"`, `"Preston"`, or `"Canty-Davison"`.
#' @param mse `logical(1)`, default `TRUE`. If `TRUE`, variance is estimated
#'   as the deviation from the full-sample estimate.
#' @param seed `integer(1)` or `NULL`. If non-`NULL`, sets the RNG seed via
#'   [withr::local_seed()] for the duration of the call; caller's RNG state is
#'   restored on exit.
#'
#' @return A `survey_replicate` with `replicates` new `rep_1…rep_N` columns,
#'   `@variables$type = "bootstrap"`, and a `"replicate_creation"` entry in the
#'   weighting history.
#'
#' @family replicate-weights
#' @export
create_bootstrap_weights <- function(
  data,
  replicates = 500L,
  ...,
  type = c(
    "Rao-Wu-Yue-Beaumont", "Rao-Wu", "Antal-Tille",
    "Preston", "Canty-Davison"
  ),
  mse = TRUE,
  seed = NULL
) {
  .validate_replicate_input(data)
  replicates <- .validate_replicates_arg(replicates)
  type       <- rlang::arg_match(type)

  .convert_and_call(
    data       = data,
    backend_fn = function(d) {
      svrep::as_bootstrap_design(d, type = type, replicates = replicates, mse = mse)
    },
    method     = "bootstrap",
    params     = list(type = type, replicates = replicates, mse = mse),
    seed       = seed
  )
}
```

- [ ] **Step 2: Run tests — all should now pass**

```r
devtools::test(filter = "replicate-weights")
```

Expected: all tests pass

- [ ] **Step 3: Run `devtools::check()`**

```r
devtools::check()
```

Expected: 0 errors, 0 warnings, ≤2 notes

- [ ] **Step 4: Update `.claude/rules/surveywts-conventions.md` Section 2 (Function Families)**

Add the new `replicate-weights` family row to the table:

```markdown
| `replicate-weights` | `create_bootstrap_weights()`, `create_jackknife_weights()`, `create_brr_weights()`, `create_gen_boot_weights()`, `create_gen_rep_weights()`, `create_sdr_weights()`, `create_replicate_weights()`, `as_taylor_design()` |
```

Note: `as_taylor_design()` belongs in `@family replicate-weights` (not `@family conversion`) because it operates on `survey_replicate` objects and is part of the replicate weights workflow, not a general-purpose conversion utility.

- [ ] **Step 5: Commit**

```bash
Rscript -e "devtools::document()"
git add R/replicate-weights.R tests/testthat/test-replicate-weights.R \
    .claude/rules/surveywts-conventions.md NAMESPACE man/
git commit -m "feat(replicate): add create_bootstrap_weights() and shared helpers"
```

- [ ] **Step 6: Create changelog entry**

Create `changelog/replicate/feature-replicate-bootstrap.md` following the `changelog-workflow` skill format, then commit:

```bash
git add changelog/replicate/feature-replicate-bootstrap.md
git commit -m "chore(replicate): add changelog for replicate-bootstrap"
```

- [ ] **Step 7: Open PR to `develop`**

---

## PR 3: Jackknife

**Branch:** `feature/replicate-jackknife`
**Files:** `R/replicate-weights.R` (modify), `tests/testthat/test-replicate-weights.R` (modify)

### Task 3.1: Create branch and write failing tests

- [ ] **Step 1: Create branch**

```bash
git checkout develop && git pull origin develop
git checkout -b feature/replicate-jackknife
```

- [ ] **Step 2: Add jackknife tests to `tests/testthat/test-replicate-weights.R`**

```r
# ---- Jackknife happy path (4a–4d) ------------------------------------------

test_that("create_jackknife_weights() delete-1 unstratified -> JK1", {
  skip_if_not_installed("survey")
  # SRS design (no strata)
  df <- make_surveywts_data(n = 20L, seed = 2L)
  td <- surveycore::as_survey(df, ids = id, weights = base_weight)
  result <- create_jackknife_weights(td)
  test_invariants(result)
  expect_identical(result@variables$type, "JK1")
})

test_that("create_jackknife_weights() delete-1 stratified -> JKn", {
  skip_if_not_installed("survey")
  td     <- make_taylor_design(seed = 2L)
  result <- create_jackknife_weights(td)
  test_invariants(result)
  expect_identical(result@variables$type, "JKn")
})

test_that("create_jackknife_weights() random-groups produces JKn with correct rep count", {
  skip_if_not_installed("svrep")
  td     <- make_taylor_design(n = 200L, n_strata = 4L, psus_per_stratum = 10L, seed = 3L)
  result <- create_jackknife_weights(td, replicates = 20L, type = "random-groups", seed = 5L)
  test_invariants(result)
  expect_identical(result@variables$type, "JKn")
  expect_identical(length(result@variables$repweights), 20L)
})

test_that("create_jackknife_weights() accepts survey_nonprob with delete-1", {
  skip_if_not_installed("survey")
  df <- make_surveywts_data(n = 30L, seed = 4L)
  np <- surveycore::survey_nonprob(
    data      = df,
    variables = list(weights = "base_weight"),
    metadata  = surveycore::survey_metadata()
  )
  result <- create_jackknife_weights(np)
  test_invariants(result)
})

# ---- Jackknife errors (5a–5e) -----------------------------------------------

test_that("create_jackknife_weights() errors when random-groups needs replicates", {
  td <- make_taylor_design(seed = 1)
  expect_error(
    create_jackknife_weights(td, type = "random-groups"),
    class = "surveywts_error_replicates_required_for_jkn"
  )
  expect_snapshot(error = TRUE, create_jackknife_weights(td, type = "random-groups"))
})

# ---- Shared input-class errors (13a–13d) ------------------------------------

test_that("create_jackknife_weights() rejects data.frame input", {
  df <- make_surveywts_data(seed = 1)
  expect_error(
    create_jackknife_weights(df),
    class = "surveywts_error_not_survey_design"
  )
  expect_snapshot(error = TRUE, create_jackknife_weights(df))
})

test_that("create_jackknife_weights() rejects survey_replicate input", {
  skip_if_not_installed("survey")
  td  <- make_taylor_design(seed = 1)
  rep <- create_jackknife_weights(td)
  expect_error(
    create_jackknife_weights(rep),
    class = "surveywts_error_already_replicate"
  )
  expect_snapshot(error = TRUE, create_jackknife_weights(rep))
})

test_that("create_jackknife_weights() rejects weighted_df input", {
  df <- make_surveywts_data(seed = 1)
  wdf <- structure(df, class = c("weighted_df", "tbl_df", "tbl", "data.frame"),
                   weight_col = "base_weight", weighting_history = list())
  expect_error(
    create_jackknife_weights(wdf),
    class = "surveywts_error_not_survey_design"
  )
  expect_snapshot(error = TRUE, create_jackknife_weights(wdf))
})

test_that("create_jackknife_weights() rejects unsupported class", {
  expect_error(
    create_jackknife_weights(list(x = 1)),
    class = "surveywts_error_unsupported_class"
  )
  expect_snapshot(error = TRUE, create_jackknife_weights(list(x = 1)))
})

test_that("create_jackknife_weights() rejects fractional replicates for random-groups", {
  td <- make_taylor_design(seed = 1)
  expect_error(
    create_jackknife_weights(td, replicates = 1.5, type = "random-groups"),
    class = "surveywts_error_replicates_not_whole_number"
  )
  expect_snapshot(
    error = TRUE,
    create_jackknife_weights(td, replicates = 1.5, type = "random-groups")
  )
})

test_that("create_jackknife_weights() rejects replicates = 1 for random-groups", {
  td <- make_taylor_design(seed = 1)
  expect_error(
    create_jackknife_weights(td, replicates = 1L, type = "random-groups"),
    class = "surveywts_error_replicates_not_positive"
  )
  expect_snapshot(
    error = TRUE,
    create_jackknife_weights(td, replicates = 1L, type = "random-groups")
  )
})

test_that("create_jackknife_weights() rejects survey_nonprob + random-groups", {
  df <- make_surveywts_data(n = 30L, seed = 1L)
  np <- surveycore::survey_nonprob(
    data      = df,
    variables = list(weights = "base_weight"),
    metadata  = surveycore::survey_metadata()
  )
  expect_error(
    create_jackknife_weights(np, replicates = 10L, type = "random-groups"),
    class = "surveywts_error_jackknife_type_unsupported_for_nonprob"
  )
  expect_snapshot(
    error = TRUE,
    create_jackknife_weights(np, replicates = 10L, type = "random-groups")
  )
})

# ---- Jackknife equivalence (4Ea–4Ec) ----------------------------------------

test_that("create_jackknife_weights() delete-1 matches survey::as.svrepdesign(JK1)", {
  skip_if_not_installed("survey")
  df <- make_surveywts_data(n = 20L, seed = 5L)
  td <- surveycore::as_survey(df, ids = id, weights = base_weight)

  direct   <- survey::as.svrepdesign(surveycore::as_svydesign(td), type = "JK1", mse = TRUE)
  result   <- create_jackknife_weights(td, type = "delete-1")
  test_invariants(result)
  expected <- as.matrix(direct$repweights)
  actual   <- as.matrix(result@data[, result@variables$repweights])

  expect_equal(actual, expected, tolerance = 1e-10)
})

# ---- Spec §XIII 4Eb: JKn delete-1 equivalence --------------------------------

test_that("create_jackknife_weights() JKn delete-1 matches survey::as.svrepdesign(JKn)", {
  skip_if_not_installed("survey")
  df <- make_surveywts_data(n = 40L, seed = 5L)
  td <- surveycore::as_survey(df, ids = id, strata = age_group, weights = base_weight)

  direct   <- survey::as.svrepdesign(surveycore::as_svydesign(td), type = "JKn", mse = TRUE)
  result   <- create_jackknife_weights(td, type = "delete-1")
  test_invariants(result)
  expected <- as.matrix(direct$repweights)
  actual   <- as.matrix(result@data[, result@variables$repweights])

  expect_equal(actual, expected, tolerance = 1e-10)
})

# ---- Spec §XIII 4Ec: random-groups equivalence with svrep --------------------

test_that("create_jackknife_weights() random-groups matches svrep::as_random_group_jackknife_design()", {
  skip_if_not_installed("svrep")
  df <- make_surveywts_data(n = 60L, seed = 3L)
  td <- surveycore::as_survey(df, ids = id, weights = base_weight)

  set.seed(77L)
  direct <- svrep::as_random_group_jackknife_design(
    surveycore::as_svydesign(td),
    replicates = 20L,
    mse        = TRUE
  )
  result <- create_jackknife_weights(td, type = "random-groups", replicates = 20L, seed = 77L)
  test_invariants(result)

  expected <- as.matrix(direct$repweights)
  actual   <- as.matrix(result@data[, result@variables$repweights])
  expect_equal(actual, expected, tolerance = 1e-10)
})

# ---- Spec §XIII 19b: edge cases ----------------------------------------------

test_that("create_jackknife_weights() delete-1 single-PSU propagates backend error", {
  # single PSU, single stratum — cannot leave one out of one
  df <- data.frame(id = 1L, base_weight = 1, age_group = "18-34")
  td <- surveycore::as_survey(df, ids = id, weights = base_weight)
  expect_error(create_jackknife_weights(td, type = "delete-1"))
})

test_that("create_jackknife_weights() random-groups replicates > PSU count propagates backend error", {
  skip_if_not_installed("svrep")
  df <- make_surveywts_data(n = 5L, seed = 1L)
  td <- surveycore::as_survey(df, ids = id, weights = base_weight)
  expect_error(
    create_jackknife_weights(td, type = "random-groups", replicates = 100L, seed = 1L)
  )
})

test_that("create_jackknife_weights() all-equal base weights succeeds", {
  skip_if_not_installed("survey")
  df             <- make_surveywts_data(n = 20L, seed = 1L)
  df$base_weight <- rep(1, nrow(df))
  td     <- surveycore::as_survey(df, ids = id, weights = base_weight)
  result <- create_jackknife_weights(td, type = "delete-1")
  test_invariants(result)
})
```

- [ ] **Step 3: Run tests to confirm they fail**

```r
devtools::test(filter = "replicate-weights")
```

Expected: jackknife tests fail with "could not find function"

### Task 3.2: Implement `create_jackknife_weights()`

- [ ] **Step 1: Append to `R/replicate-weights.R`**

```r
# ============================================================================
# create_jackknife_weights()
# ============================================================================

#' Create jackknife replicate weights
#'
#' Generates jackknife replicate weights via [survey::as.svrepdesign()] (for
#' delete-1) or [svrep::as_random_group_jackknife_design()] (for random-groups).
#'
#' @param data A `survey_taylor` or `survey_nonprob` design. `survey_nonprob`
#'   supports `type = "delete-1"` only.
#' @param replicates `integer(1)` or `NULL`. Number of random groups when
#'   `type = "random-groups"`. Required for random-groups; ignored for
#'   delete-1.
#' @param ... Must be empty.
#' @param type `character(1)`. `"delete-1"` (default): one replicate per PSU,
#'   auto-selecting JK1 (unstratified) or JKn (stratified). `"random-groups"`:
#'   PSUs randomly divided into `replicates` groups.
#' @param mse `logical(1)`, default `TRUE`.
#' @param seed `integer(1)` or `NULL`. RNG seed for random-group assignment
#'   (ignored for delete-1).
#'
#' @return A `survey_replicate` with `@variables$type` of `"JK1"` or `"JKn"`.
#'
#' @family replicate-weights
#' @export
create_jackknife_weights <- function(
  data,
  replicates = NULL,
  ...,
  type = c("delete-1", "random-groups"),
  mse = TRUE,
  seed = NULL
) {
  .validate_replicate_input(data)
  type <- rlang::arg_match(type)

  # nonprob + random-groups: error first (before replicates validation)
  if (S7::S7_inherits(data, surveycore::survey_nonprob) &&
        type == "random-groups") {
    cli::cli_abort(
      c(
        "x" = paste0(
          "{.cls survey_nonprob} input is not supported with ",
          "{.code type = \"random-groups\"}."
        ),
        "i" = "Only {.code type = \"delete-1\"} is supported for non-probability designs.",
        "v" = "Use {.code type = \"delete-1\"} or convert to {.cls survey_taylor}."
      ),
      class = "surveywts_error_jackknife_type_unsupported_for_nonprob"
    )
  }

  if (type == "random-groups") {
    if (is.null(replicates)) {
      cli::cli_abort(
        c(
          "x" = "{.arg replicates} is required when {.code type = \"random-groups\"}.",
          "v" = "Supply an integer, e.g. {.code replicates = 20L}."
        ),
        class = "surveywts_error_replicates_required_for_jkn"
      )
    }
    replicates <- .validate_replicates_arg(replicates)
    .convert_and_call(
      data       = data,
      backend_fn = function(d) {
        svrep::as_random_group_jackknife_design(d, replicates = replicates, mse = mse)
      },
      method     = "jackknife",
      params     = list(type = "random-groups", replicates = replicates, mse = mse),
      seed       = seed
    )
  } else {
    # delete-1: auto-detect JK1 (no strata) vs JKn (has strata)
    jk_type <- if (is.null(data@variables$strata)) "JK1" else "JKn"
    .convert_and_call(
      data       = data,
      backend_fn = function(d) {
        survey::as.svrepdesign(d, type = jk_type, mse = mse)
      },
      method     = "jackknife",
      params     = list(type = jk_type, mse = mse)
    )
  }
}
```

- [ ] **Step 2: Run tests**

```r
devtools::test(filter = "replicate-weights")
```

Expected: all tests pass

- [ ] **Step 3: `devtools::check()`, commit, open PR**

```bash
Rscript -e "devtools::document()"
git add R/replicate-weights.R tests/testthat/test-replicate-weights.R NAMESPACE man/
git commit -m "feat(replicate): add create_jackknife_weights()"
```

- [ ] **Create changelog entry:** Create `changelog/replicate/feature-replicate-jackknife.md` following the `changelog-workflow` skill format, then `git add changelog/replicate/feature-replicate-jackknife.md && git commit -m "chore(replicate): add changelog for replicate-jackknife"`. Then open PR to `develop`.

---

## PR 4: BRR

**Branch:** `feature/replicate-brr`
**Files:** `R/replicate-weights.R` (modify), `tests/testthat/test-replicate-weights.R` (modify)

### Task 4.1: Write failing tests then implement

- [x] **Step 1: Create branch**

```bash
git checkout develop && git pull origin develop
git checkout -b feature/replicate-brr
```

- [x] **Step 2: Add BRR tests to `test-replicate-weights.R`**

```r
# ---- BRR happy path (6a–6b) -------------------------------------------------

test_that("create_brr_weights() paired design rho=0 -> BRR type", {
  skip_if_not_installed("survey")
  pd     <- make_paired_design(seed = 1L)
  result <- create_brr_weights(pd)
  test_invariants(result)
  expect_identical(result@variables$type, "BRR")
})

test_that("create_brr_weights() paired design rho=0.5 -> Fay type", {
  skip_if_not_installed("survey")
  pd     <- make_paired_design(seed = 1L)
  result <- create_brr_weights(pd, rho = 0.5)
  test_invariants(result)
  expect_identical(result@variables$type, "Fay")
})

# ---- Shared input-class errors (13a–13d) ------------------------------------

test_that("create_brr_weights() rejects data.frame input", {
  df <- make_surveywts_data(seed = 1)
  expect_error(create_brr_weights(df), class = "surveywts_error_not_survey_design")
  expect_snapshot(error = TRUE, create_brr_weights(df))
})

test_that("create_brr_weights() rejects survey_replicate input", {
  skip_if_not_installed("survey")
  pd  <- make_paired_design(seed = 1)
  rep <- create_brr_weights(pd)
  expect_error(create_brr_weights(rep), class = "surveywts_error_already_replicate")
  expect_snapshot(error = TRUE, create_brr_weights(rep))
})

test_that("create_brr_weights() rejects weighted_df input", {
  df <- make_surveywts_data(seed = 1)
  wdf <- structure(df, class = c("weighted_df", "tbl_df", "tbl", "data.frame"),
                   weight_col = "base_weight", weighting_history = list())
  expect_error(create_brr_weights(wdf), class = "surveywts_error_not_survey_design")
  expect_snapshot(error = TRUE, create_brr_weights(wdf))
})

test_that("create_brr_weights() rejects unsupported class", {
  expect_error(create_brr_weights(list(x = 1)), class = "surveywts_error_unsupported_class")
  expect_snapshot(error = TRUE, create_brr_weights(list(x = 1)))
})

# ---- BRR errors (8a–8d) ----------------------------------------------------

test_that("create_brr_weights() rejects non-paired design", {
  td <- make_taylor_design(n = 200L, n_strata = 4L, psus_per_stratum = 5L, seed = 1L)
  expect_error(
    create_brr_weights(td),
    class = "surveywts_error_brr_requires_paired_design"
  )
  expect_snapshot(error = TRUE, create_brr_weights(td))
})

test_that("create_brr_weights() rejects survey_nonprob", {
  df <- make_surveywts_data(n = 30L, seed = 1L)
  np <- surveycore::survey_nonprob(
    data      = df,
    variables = list(weights = "base_weight"),
    metadata  = surveycore::survey_metadata()
  )
  expect_error(create_brr_weights(np), class = "surveywts_error_brr_requires_paired_design")
  expect_snapshot(error = TRUE, create_brr_weights(np))
})

test_that("create_brr_weights() rejects rho < 0", {
  pd <- make_paired_design(seed = 1L)
  expect_error(create_brr_weights(pd, rho = -0.1), class = "surveywts_error_brr_rho_invalid")
  expect_snapshot(error = TRUE, create_brr_weights(pd, rho = -0.1))
})

test_that("create_brr_weights() rejects rho = 1", {
  pd <- make_paired_design(seed = 1L)
  expect_error(create_brr_weights(pd, rho = 1.0), class = "surveywts_error_brr_rho_invalid")
  expect_snapshot(error = TRUE, create_brr_weights(pd, rho = 1.0))
})

# ---- BRR equivalence (7a) ---------------------------------------------------

test_that("create_brr_weights() matches survey::as.svrepdesign(BRR) directly", {
  skip_if_not_installed("survey")
  pd       <- make_paired_design(seed = 1L)
  direct   <- survey::as.svrepdesign(surveycore::as_svydesign(pd), type = "BRR", mse = TRUE)
  result   <- create_brr_weights(pd)
  test_invariants(result)
  expected <- as.matrix(direct$repweights)
  actual   <- as.matrix(result@data[, result@variables$repweights])
  expect_equal(actual, expected, tolerance = 1e-10)
})

# ---- Spec §XIII 19c: edge cases ----------------------------------------------

test_that("create_brr_weights() single-stratum paired design succeeds with 2 replicates", {
  skip_if_not_installed("survey")
  # 1 stratum, 2 PSUs — smallest valid BRR design; Hadamard order 2
  df <- data.frame(
    id          = 1:2, stratum = c(1L, 1L),
    base_weight = c(1, 1), age_group = c("18-34", "35-54")
  )
  pd     <- surveycore::as_survey(df, ids = id, strata = stratum, weights = base_weight)
  result <- create_brr_weights(pd)
  test_invariants(result)
  expect_identical(length(result@variables$repweights), 2L)
})

test_that("create_brr_weights() all-equal base weights succeeds", {
  skip_if_not_installed("survey")
  pd <- make_paired_design(seed = 1L)
  pd@data$base_weight <- rep(1, nrow(pd@data))
  result <- create_brr_weights(pd)
  test_invariants(result)
})
```

- [x] **Step 3: Confirm tests fail, then implement `create_brr_weights()`**

Append to `R/replicate-weights.R`:

```r
# ============================================================================
# create_brr_weights()
# ============================================================================

#' Create BRR (Fay) replicate weights
#'
#' Generates balanced repeated replication (BRR) or Fay's BRR replicate weights
#' via [survey::as.svrepdesign()]. Requires a paired-PSU design (exactly 2 PSUs
#' per stratum).
#'
#' @param data A `survey_taylor` with exactly 2 PSUs per stratum.
#' @param ... Must be empty.
#' @param rho `numeric(1)`, default `0`. Fay damping coefficient. `rho = 0`
#'   gives standard BRR; `rho > 0` gives Fay's BRR variant with factors `rho`
#'   and `2 - rho`. Must satisfy `0 <= rho < 1`.
#' @param mse `logical(1)`, default `TRUE`.
#'
#' @return A `survey_replicate` with `@variables$type` of `"BRR"` or `"Fay"`.
#'
#' @family replicate-weights
#' @export
create_brr_weights <- function(data, ..., rho = 0, mse = TRUE) {
  .validate_replicate_input(data)

  # Step 1: nonprob rejection
  if (S7::S7_inherits(data, surveycore::survey_nonprob)) {
    cli::cli_abort(
      c(
        "x" = "BRR requires a paired-PSU design; {.cls survey_nonprob} has no PSU structure.",
        "v" = "Use {.fn create_bootstrap_weights} for non-probability designs."
      ),
      class = "surveywts_error_brr_requires_paired_design"
    )
  }

  # Step 2: missing strata or ids
  if (is.null(data@variables$strata) || is.null(data@variables$ids)) {
    cli::cli_abort(
      c(
        "x" = "BRR requires a design with both strata and PSU IDs.",
        "i" = paste0(
          "Strata: ",
          if (is.null(data@variables$strata)) "missing" else "present",
          "; PSU IDs: ",
          if (is.null(data@variables$ids)) "missing" else "present",
          "."
        ),
        "v" = "Build the design with both {.arg ids} and {.arg strata} in {.fn surveycore::as_survey}."
      ),
      class = "surveywts_error_brr_requires_paired_design"
    )
  }

  # Step 3: PSU count per stratum must be exactly 2
  psu_col    <- data@variables$ids
  strata_col <- data@variables$strata
  df         <- data@data
  counts     <- tapply(
    df[[psu_col]], df[[strata_col]], function(x) length(unique(x))
  )
  bad <- names(counts)[counts != 2L]
  if (length(bad) > 0L) {
    show <- utils::head(bad, 5L)
    suffix <- if (length(bad) > 5L) paste0(" … (", length(bad) - 5L, " more)") else ""
    cli::cli_abort(
      c(
        "x" = "BRR requires exactly 2 PSUs per stratum.",
        "i" = paste0(
          "Stratum/a with wrong PSU count: ",
          paste(show, collapse = ", "), suffix, "."
        ),
        "v" = "Use {.fn create_gen_rep_weights} for designs with unequal PSU counts per stratum."
      ),
      class = "surveywts_error_brr_requires_paired_design"
    )
  }

  # Step 4: rho range
  if (rho < 0 || rho >= 1) {
    cli::cli_abort(
      c(
        "x" = "{.arg rho} must satisfy 0 ≤ rho < 1; got {.val {rho}}.",
        "i" = "{.arg rho} = 0 gives standard BRR; {.arg rho} > 0 gives Fay's BRR variant."
      ),
      class = "surveywts_error_brr_rho_invalid"
    )
  }

  if (rho == 0) {
    .convert_and_call(
      data       = data,
      backend_fn = function(d) survey::as.svrepdesign(d, type = "BRR", mse = mse),
      method     = "brr",
      params     = list(rho = 0, mse = mse)
    )
  } else {
    .convert_and_call(
      data       = data,
      backend_fn = function(d) survey::as.svrepdesign(d, type = "Fay", fay.rho = rho, mse = mse),
      method     = "brr",
      params     = list(rho = rho, mse = mse)
    )
  }
}
```

- [x] **Step 4: Run tests, `devtools::check()`, commit, open PR**

```bash
Rscript -e "devtools::document()"
git add R/replicate-weights.R tests/testthat/test-replicate-weights.R NAMESPACE man/
git commit -m "feat(replicate): add create_brr_weights()"
```

- [x] **Create changelog entry:** Create `changelog/replicate/feature-replicate-brr.md` following the `changelog-workflow` skill format, then `git add changelog/replicate/feature-replicate-brr.md && git commit -m "chore(replicate): add changelog for replicate-brr"`. Then open PR to `develop`.

---

## PR 5: Generalized Bootstrap

**Branch:** `feature/replicate-gen-boot`
**Files:** `R/replicate-weights.R`, `tests/testthat/test-replicate-weights.R`

### Task 5.1: Write failing tests

- [ ] **Step 1: Create branch**

```bash
git checkout develop && git pull origin develop
git checkout -b feature/replicate-gen-boot
```

- [ ] **Step 2: Add gen-boot tests**

```r
# ---- Gen-boot happy path (9a–9c) -------------------------------------------

test_that("create_gen_boot_weights() returns survey_replicate with type bootstrap", {
  skip_if_not_installed("svrep")
  td     <- make_taylor_design(seed = 1L)
  result <- create_gen_boot_weights(td, replicates = 20L, seed = 1L)
  test_invariants(result)
  expect_identical(result@variables$type, "bootstrap")
})

test_that("create_gen_boot_weights() variance_estimator SD2 differs from SD1", {
  skip_if_not_installed("svrep")
  td  <- make_taylor_design(seed = 1L)
  r1  <- create_gen_boot_weights(td, replicates = 20L,
                                  variance_estimator = "SD1", seed = 1L)
  r2  <- create_gen_boot_weights(td, replicates = 20L,
                                  variance_estimator = "SD2", seed = 1L)
  test_invariants(r1)
  test_invariants(r2)
  expect_false(identical(
    as.matrix(r1@data[, r1@variables$repweights]),
    as.matrix(r2@data[, r2@variables$repweights])
  ))
})

# ---- Shared input-class errors (13a–13d) ------------------------------------

test_that("create_gen_boot_weights() rejects data.frame input", {
  df <- make_surveywts_data(seed = 1)
  expect_error(create_gen_boot_weights(df), class = "surveywts_error_not_survey_design")
  expect_snapshot(error = TRUE, create_gen_boot_weights(df))
})

test_that("create_gen_boot_weights() rejects survey_replicate input", {
  skip_if_not_installed("svrep")
  td  <- make_taylor_design(seed = 1)
  rep <- create_bootstrap_weights(td, replicates = 10L, seed = 1L)
  expect_error(create_gen_boot_weights(rep), class = "surveywts_error_already_replicate")
  expect_snapshot(error = TRUE, create_gen_boot_weights(rep))
})

test_that("create_gen_boot_weights() rejects weighted_df input", {
  df <- make_surveywts_data(seed = 1)
  wdf <- structure(df, class = c("weighted_df", "tbl_df", "tbl", "data.frame"),
                   weight_col = "base_weight", weighting_history = list())
  expect_error(create_gen_boot_weights(wdf), class = "surveywts_error_not_survey_design")
  expect_snapshot(error = TRUE, create_gen_boot_weights(wdf))
})

test_that("create_gen_boot_weights() rejects unsupported class", {
  expect_error(create_gen_boot_weights(list(x = 1)), class = "surveywts_error_unsupported_class")
  expect_snapshot(error = TRUE, create_gen_boot_weights(list(x = 1)))
})

# ---- Gen-boot errors (9Ea–9Ed) -----------------------------------------------

test_that("create_gen_boot_weights() rejects replicates = 0", {
  td <- make_taylor_design(seed = 1)
  expect_error(
    create_gen_boot_weights(td, replicates = 0L),
    class = "surveywts_error_replicates_not_positive"
  )
  expect_snapshot(error = TRUE, create_gen_boot_weights(td, replicates = 0L))
})

test_that("create_gen_boot_weights() rejects replicates = 1 (boundary: min is 2)", {
  td <- make_taylor_design(seed = 1)
  expect_error(
    create_gen_boot_weights(td, replicates = 1L),
    class = "surveywts_error_replicates_not_positive"
  )
  expect_snapshot(error = TRUE, create_gen_boot_weights(td, replicates = 1L))
})

test_that("create_gen_boot_weights() rejects fractional replicates", {
  td <- make_taylor_design(seed = 1)
  expect_error(
    create_gen_boot_weights(td, replicates = 2.5),
    class = "surveywts_error_replicates_not_whole_number"
  )
  expect_snapshot(error = TRUE, create_gen_boot_weights(td, replicates = 2.5))
})

test_that("create_gen_boot_weights() rejects Deville-Tille without aux_var_names", {
  td <- make_taylor_design(seed = 1)
  expect_error(
    create_gen_boot_weights(td, variance_estimator = "Deville-Tille"),
    class = "surveywts_error_variance_estimator_requires_aux"
  )
  expect_snapshot(
    error = TRUE,
    create_gen_boot_weights(td, variance_estimator = "Deville-Tille")
  )
})

test_that("create_gen_boot_weights() rejects survey_nonprob", {
  df <- make_surveywts_data(n = 30L, seed = 1L)
  np <- surveycore::survey_nonprob(
    data      = df,
    variables = list(weights = "base_weight"),
    metadata  = surveycore::survey_metadata()
  )
  expect_error(
    create_gen_boot_weights(np),
    class = "surveywts_error_nonprob_requires_probability_design"
  )
  expect_snapshot(error = TRUE, create_gen_boot_weights(np))
})

# ---- Gen-boot equivalence (9Xa) --------------------------------------------

test_that("create_gen_boot_weights() matches svrep::as_gen_boot_design() directly", {
  skip_if_not_installed("svrep")
  td <- make_taylor_design(n = 100L, seed = 7L)

  set.seed(77L)
  direct   <- svrep::as_gen_boot_design(
    surveycore::as_svydesign(td),
    variance_estimator = "SD1",
    replicates         = 30L,
    mse                = TRUE
  )
  result   <- create_gen_boot_weights(td, replicates = 30L,
                                       variance_estimator = "SD1", seed = 77L)
  test_invariants(result)
  expected <- as.matrix(direct$repweights)
  actual   <- as.matrix(result@data[, result@variables$repweights])
  expect_equal(actual, expected, tolerance = 1e-10)
})

# ---- Spec §XIII 9c: tau = "auto" produces non-negative replicate weights -----

test_that("create_gen_boot_weights() tau = 'auto' produces non-negative weights", {
  skip_if_not_installed("svrep")
  td     <- make_taylor_design(seed = 1)
  result <- create_gen_boot_weights(td, replicates = 30L, tau = "auto", seed = 1L)
  test_invariants(result)
  rep_mat <- as.matrix(result@data[, result@variables$repweights])
  expect_true(all(rep_mat >= 0))
})

# ---- Spec §XIII 19d: edge cases ----------------------------------------------

test_that("create_gen_boot_weights() 0-row input propagates backend error", {
  skip_if_not_installed("svrep")
  df <- make_surveywts_data(n = 10L, seed = 1L)[0L, ]
  td <- surveycore::as_survey(df, ids = id, weights = base_weight)
  expect_error(create_gen_boot_weights(td, replicates = 10L, seed = 1L))
})

test_that("create_gen_boot_weights() all-equal base weights succeeds", {
  skip_if_not_installed("svrep")
  df             <- make_surveywts_data(n = 50L, seed = 1L)
  df$base_weight <- rep(1, nrow(df))
  td     <- surveycore::as_survey(df, ids = id, weights = base_weight)
  result <- create_gen_boot_weights(td, replicates = 20L, seed = 1L)
  test_invariants(result)
})
```

### Task 5.2: Implement `create_gen_boot_weights()`

- [ ] **Step 1: Append to `R/replicate-weights.R`**

```r
# ============================================================================
# create_gen_boot_weights()
# ============================================================================

#' Create generalized bootstrap replicate weights
#'
#' Generates generalized bootstrap replicate weights via
#' [svrep::as_gen_boot_design()]. Requires a `survey_taylor` design.
#'
#' @param data A `survey_taylor` design.
#' @param replicates `integer(1)`, default `500L`. Number of bootstrap replicates.
#' @param ... Must be empty.
#' @param variance_estimator `character(1)`. Target variance estimator. One of
#'   `"SD1"` (default), `"SD2"`, `"Horvitz-Thompson"`, `"Yates-Grundy"`,
#'   `"Poisson Horvitz-Thompson"`, `"Stratified Multistage SRS"`,
#'   `"Ultimate Cluster"`, `"Deville-1"`, `"Deville-2"`, `"Deville-Tille"`,
#'   `"BOSB"`, or `"Beaumont-Emond"`.
#' @param tau `numeric(1)` or `"auto"`, default `1`. Rescaling constant to
#'   prevent negative replicate weights.
#' @param aux_var_names `<tidy-select>` or `NULL`. Auxiliary variable columns.
#'   Required when `variance_estimator = "Deville-Tille"`.
#' @param mse `logical(1)`, default `TRUE`.
#' @param seed `integer(1)` or `NULL`. RNG seed.
#'
#' @return A `survey_replicate` with `@variables$type = "bootstrap"`.
#'
#' @family replicate-weights
#' @export
create_gen_boot_weights <- function(
  data,
  replicates = 500L,
  ...,
  variance_estimator = "SD1",
  tau = 1,
  aux_var_names = NULL,
  mse = TRUE,
  seed = NULL
) {
  .validate_replicate_input(data)

  if (S7::S7_inherits(data, surveycore::survey_nonprob)) {
    cli::cli_abort(
      c(
        "x" = "{.fn create_gen_boot_weights} requires a probability-design structure.",
        "i" = "{.cls survey_nonprob} has no PSU or stratum structure required by this method.",
        "v" = "Use {.fn create_bootstrap_weights} for non-probability designs."
      ),
      class = "surveywts_error_nonprob_requires_probability_design"
    )
  }

  replicates         <- .validate_replicates_arg(replicates)
  variance_estimator <- rlang::arg_match(variance_estimator, c(
    "SD1", "SD2", "Horvitz-Thompson", "Yates-Grundy",
    "Poisson Horvitz-Thompson", "Stratified Multistage SRS",
    "Ultimate Cluster", "Deville-1", "Deville-2", "Deville-Tille",
    "BOSB", "Beaumont-Emond"
  ))

  if (identical(variance_estimator, "Deville-Tille") && is.null(aux_var_names)) {
    cli::cli_abort(
      c(
        "x" = "{.code variance_estimator = \"Deville-Tille\"} requires {.arg aux_var_names}.",
        "v" = "Pass column names, e.g. {.code aux_var_names = c(x1, x2)}."
      ),
      class = "surveywts_error_variance_estimator_requires_aux"
    )
  }

  aux_quo      <- rlang::enquo(aux_var_names)
  resolved_aux <- if (rlang::quo_is_null(aux_quo)) {
    NULL
  } else {
    names(tidyselect::eval_select(aux_quo, data = data@data))
  }

  .convert_and_call(
    data       = data,
    backend_fn = function(d) {
      svrep::as_gen_boot_design(
        d,
        variance_estimator = variance_estimator,
        replicates         = replicates,
        tau                = tau,
        aux_var_names      = resolved_aux,
        mse                = mse
      )
    },
    method     = "generalized-bootstrap",
    params     = list(
      variance_estimator = variance_estimator,
      replicates         = replicates,
      tau                = tau,
      mse                = mse
    ),
    seed       = seed
  )
}
```

- [ ] **Step 2: Run tests, `devtools::check()`, commit, open PR**

```bash
Rscript -e "devtools::document()"
git add R/replicate-weights.R tests/testthat/test-replicate-weights.R NAMESPACE man/
git commit -m "feat(replicate): add create_gen_boot_weights()"
```

- [ ] **Create changelog entry:** Create `changelog/replicate/feature-replicate-gen-boot.md` following the `changelog-workflow` skill format, then `git add changelog/replicate/feature-replicate-gen-boot.md && git commit -m "chore(replicate): add changelog for replicate-gen-boot"`. Then open PR to `develop`.

---

## PR 6: Generalized Replication

**Branch:** `feature/replicate-gen-rep`
**Files:** `R/replicate-weights.R`, `tests/testthat/test-replicate-weights.R`

### Task 6.1: Write failing tests then implement

- [ ] **Step 1: Create branch**

```bash
git checkout develop && git pull origin develop
git checkout -b feature/replicate-gen-rep
```

- [ ] **Step 2: Add gen-rep tests**

```r
# ---- Gen-rep happy path (10a–10c) ------------------------------------------

test_that("create_gen_rep_weights() returns deterministic survey_replicate", {
  skip_if_not_installed("svrep")
  td  <- make_taylor_design(seed = 1L)
  r1  <- create_gen_rep_weights(td)
  r2  <- create_gen_rep_weights(td)
  test_invariants(r1)
  expect_equal(
    as.matrix(r1@data[, r1@variables$repweights]),
    as.matrix(r2@data[, r2@variables$repweights]),
    tolerance = 1e-10
  )
})

test_that("create_gen_rep_weights() max_replicates limits count", {
  skip_if_not_installed("svrep")
  td     <- make_taylor_design(seed = 1L)
  result <- create_gen_rep_weights(td, max_replicates = 10L)
  test_invariants(result)
  expect_true(length(result@variables$repweights) <= 10L)
})

# ---- Shared input-class errors (13a–13d) ------------------------------------

test_that("create_gen_rep_weights() rejects data.frame input", {
  df <- make_surveywts_data(seed = 1)
  expect_error(create_gen_rep_weights(df), class = "surveywts_error_not_survey_design")
  expect_snapshot(error = TRUE, create_gen_rep_weights(df))
})

test_that("create_gen_rep_weights() rejects survey_replicate input", {
  skip_if_not_installed("svrep")
  td  <- make_taylor_design(seed = 1)
  rep <- create_bootstrap_weights(td, replicates = 10L, seed = 1L)
  expect_error(create_gen_rep_weights(rep), class = "surveywts_error_already_replicate")
  expect_snapshot(error = TRUE, create_gen_rep_weights(rep))
})

test_that("create_gen_rep_weights() rejects weighted_df input", {
  df <- make_surveywts_data(seed = 1)
  wdf <- structure(df, class = c("weighted_df", "tbl_df", "tbl", "data.frame"),
                   weight_col = "base_weight", weighting_history = list())
  expect_error(create_gen_rep_weights(wdf), class = "surveywts_error_not_survey_design")
  expect_snapshot(error = TRUE, create_gen_rep_weights(wdf))
})

test_that("create_gen_rep_weights() rejects unsupported class", {
  expect_error(create_gen_rep_weights(list(x = 1)), class = "surveywts_error_unsupported_class")
  expect_snapshot(error = TRUE, create_gen_rep_weights(list(x = 1)))
})

# ---- Gen-rep errors (10Ea–10Eb) ---------------------------------------------

test_that("create_gen_rep_weights() rejects Deville-Tille without aux_var_names", {
  td <- make_taylor_design(seed = 1)
  expect_error(
    create_gen_rep_weights(td, variance_estimator = "Deville-Tille"),
    class = "surveywts_error_variance_estimator_requires_aux"
  )
  expect_snapshot(
    error = TRUE,
    create_gen_rep_weights(td, variance_estimator = "Deville-Tille")
  )
})

test_that("create_gen_rep_weights() rejects survey_nonprob", {
  df <- make_surveywts_data(n = 30L, seed = 1L)
  np <- surveycore::survey_nonprob(
    data      = df,
    variables = list(weights = "base_weight"),
    metadata  = surveycore::survey_metadata()
  )
  expect_error(
    create_gen_rep_weights(np),
    class = "surveywts_error_nonprob_requires_probability_design"
  )
  expect_snapshot(error = TRUE, create_gen_rep_weights(np))
})

# ---- Spec §XIII 10c: balanced = FALSE may produce fewer replicates -----------

test_that("create_gen_rep_weights() balanced = FALSE may produce fewer replicates", {
  skip_if_not_installed("svrep")
  td       <- make_taylor_design(seed = 1L)
  balanced <- create_gen_rep_weights(td, balanced = TRUE)
  unbalanced <- create_gen_rep_weights(td, balanced = FALSE)
  test_invariants(balanced)
  test_invariants(unbalanced)
  expect_true(
    length(unbalanced@variables$repweights) <= length(balanced@variables$repweights)
  )
})

# ---- Spec §XIII 10Xa: gen-rep equivalence with svrep -------------------------

test_that("create_gen_rep_weights() matches svrep::as_fays_gen_rep_design() directly", {
  skip_if_not_installed("svrep")
  td <- make_taylor_design(n = 60L, seed = 7L)

  direct <- svrep::as_fays_gen_rep_design(
    surveycore::as_svydesign(td),
    variance_estimator = "SD1",
    max_replicates     = 50L,
    balanced           = TRUE,
    mse                = TRUE
  )
  result <- create_gen_rep_weights(
    td,
    variance_estimator = "SD1",
    max_replicates     = 50L,
    balanced           = TRUE
  )
  test_invariants(result)

  expected <- as.matrix(direct$repweights)
  actual   <- as.matrix(result@data[, result@variables$repweights])
  expect_equal(actual, expected, tolerance = 1e-10)
})

# ---- Spec §XIII 19e: edge cases ----------------------------------------------

test_that("create_gen_rep_weights() 0-row input propagates backend error", {
  skip_if_not_installed("svrep")
  df <- make_surveywts_data(n = 10L, seed = 1L)[0L, ]
  td <- surveycore::as_survey(df, ids = id, weights = base_weight)
  expect_error(create_gen_rep_weights(td))
})

test_that("create_gen_rep_weights() all-equal base weights produces deterministic output", {
  skip_if_not_installed("svrep")
  df             <- make_surveywts_data(n = 50L, seed = 1L)
  df$base_weight <- rep(1, nrow(df))
  td <- surveycore::as_survey(df, ids = id, weights = base_weight)
  r1 <- create_gen_rep_weights(td)
  r2 <- create_gen_rep_weights(td)
  test_invariants(r1)
  expect_equal(
    as.matrix(r1@data[, r1@variables$repweights]),
    as.matrix(r2@data[, r2@variables$repweights]),
    tolerance = 1e-10
  )
})
```

- [ ] **Step 3: Implement `create_gen_rep_weights()`**

Append to `R/replicate-weights.R`:

```r
# ============================================================================
# create_gen_rep_weights()
# ============================================================================

#' Create generalized replication replicate weights
#'
#' Generates Fay's generalized replication weights via
#' [svrep::as_fays_gen_rep_design()]. Produces deterministic replicate weights
#' (no randomness). Requires a `survey_taylor` design.
#'
#' @param data A `survey_taylor` design.
#' @param ... Must be empty.
#' @param variance_estimator `character(1)`. Target variance estimator. Same
#'   options as [create_gen_boot_weights()]. Default `"SD2"`.
#' @param max_replicates `numeric(1)`, default `Inf`. Maximum number of
#'   replicates; `Inf` uses the natural count.
#' @param balanced `logical(1)`, default `TRUE`. Equal contribution of
#'   replicates to variance estimates.
#' @param aux_var_names `<tidy-select>` or `NULL`. Required for
#'   `"Deville-Tille"`.
#' @param mse `logical(1)`, default `TRUE`.
#'
#' @return A `survey_replicate` with deterministic replicate weights.
#'
#' @family replicate-weights
#' @export
create_gen_rep_weights <- function(
  data,
  ...,
  variance_estimator = "SD2",
  max_replicates = Inf,
  balanced = TRUE,
  aux_var_names = NULL,
  mse = TRUE
) {
  .validate_replicate_input(data)

  if (S7::S7_inherits(data, surveycore::survey_nonprob)) {
    cli::cli_abort(
      c(
        "x" = "{.fn create_gen_rep_weights} requires a probability-design structure.",
        "i" = "{.cls survey_nonprob} has no PSU or stratum structure required by this method.",
        "v" = "Use {.fn create_bootstrap_weights} for non-probability designs."
      ),
      class = "surveywts_error_nonprob_requires_probability_design"
    )
  }

  variance_estimator <- rlang::arg_match(variance_estimator, c(
    "SD1", "SD2", "Horvitz-Thompson", "Yates-Grundy",
    "Poisson Horvitz-Thompson", "Stratified Multistage SRS",
    "Ultimate Cluster", "Deville-1", "Deville-2", "Deville-Tille",
    "BOSB", "Beaumont-Emond"
  ))

  if (identical(variance_estimator, "Deville-Tille") && is.null(aux_var_names)) {
    cli::cli_abort(
      c(
        "x" = "{.code variance_estimator = \"Deville-Tille\"} requires {.arg aux_var_names}.",
        "v" = "Pass column names, e.g. {.code aux_var_names = c(x1, x2)}."
      ),
      class = "surveywts_error_variance_estimator_requires_aux"
    )
  }

  aux_quo      <- rlang::enquo(aux_var_names)
  resolved_aux <- if (rlang::quo_is_null(aux_quo)) {
    NULL
  } else {
    names(tidyselect::eval_select(aux_quo, data = data@data))
  }

  .convert_and_call(
    data       = data,
    backend_fn = function(d) {
      svrep::as_fays_gen_rep_design(
        d,
        variance_estimator = variance_estimator,
        max_replicates     = max_replicates,
        balanced           = balanced,
        aux_var_names      = resolved_aux,
        mse                = mse
      )
    },
    method     = "generalized-replicate",
    params     = list(
      variance_estimator = variance_estimator,
      max_replicates     = max_replicates,
      balanced           = balanced,
      mse                = mse
    )
  )
}
```

- [ ] **Step 4: Run tests, `devtools::check()`, commit, open PR**

```bash
Rscript -e "devtools::document()"
git add R/replicate-weights.R tests/testthat/test-replicate-weights.R NAMESPACE man/
git commit -m "feat(replicate): add create_gen_rep_weights()"
```

- [ ] **Create changelog entry:** Create `changelog/replicate/feature-replicate-gen-rep.md` following the `changelog-workflow` skill format, then `git add changelog/replicate/feature-replicate-gen-rep.md && git commit -m "chore(replicate): add changelog for replicate-gen-rep"`. Then open PR to `develop`.

---

## PR 7: Successive Difference Replication

**Branch:** `feature/replicate-sdr`
**Files:** `R/replicate-weights.R`, `tests/testthat/test-replicate-weights.R`

### Task 7.1: Write failing tests then implement

- [ ] **Step 1: Create branch**

```bash
git checkout develop && git pull origin develop
git checkout -b feature/replicate-sdr
```

- [ ] **Step 2: Add SDR tests**

```r
# ---- SDR happy path (11a–11b) -----------------------------------------------

test_that("create_sdr_weights() returns successive-difference type", {
  skip_if_not_installed("svrep")
  td     <- make_taylor_design(seed = 1L)
  result <- create_sdr_weights(td, replicates = 40L)
  test_invariants(result)
  expect_identical(result@variables$type, "successive-difference")
})

test_that("create_sdr_weights() sort_var changes result", {
  skip_if_not_installed("svrep")
  td <- make_taylor_design(seed = 1L)
  r1 <- create_sdr_weights(td, replicates = 40L)
  r2 <- create_sdr_weights(td, replicates = 40L, sort_var = id)
  test_invariants(r1)
  test_invariants(r2)
  # sort_var = id is a different order than default row order; results differ
  expect_false(identical(
    as.matrix(r1@data[, r1@variables$repweights]),
    as.matrix(r2@data[, r2@variables$repweights])
  ))
})

# ---- Shared input-class errors (13a–13d) ------------------------------------

test_that("create_sdr_weights() rejects data.frame input", {
  df <- make_surveywts_data(seed = 1)
  expect_error(create_sdr_weights(df), class = "surveywts_error_not_survey_design")
  expect_snapshot(error = TRUE, create_sdr_weights(df))
})

test_that("create_sdr_weights() rejects survey_replicate input", {
  skip_if_not_installed("svrep")
  td  <- make_taylor_design(seed = 1)
  rep <- create_bootstrap_weights(td, replicates = 10L, seed = 1L)
  expect_error(create_sdr_weights(rep), class = "surveywts_error_already_replicate")
  expect_snapshot(error = TRUE, create_sdr_weights(rep))
})

test_that("create_sdr_weights() rejects weighted_df input", {
  df <- make_surveywts_data(seed = 1)
  wdf <- structure(df, class = c("weighted_df", "tbl_df", "tbl", "data.frame"),
                   weight_col = "base_weight", weighting_history = list())
  expect_error(create_sdr_weights(wdf), class = "surveywts_error_not_survey_design")
  expect_snapshot(error = TRUE, create_sdr_weights(wdf))
})

test_that("create_sdr_weights() rejects unsupported class", {
  expect_error(create_sdr_weights(list(x = 1)), class = "surveywts_error_unsupported_class")
  expect_snapshot(error = TRUE, create_sdr_weights(list(x = 1)))
})

# ---- SDR errors (12a–12d) ---------------------------------------------------

test_that("create_sdr_weights() rejects sort_var with NA", {
  td              <- make_taylor_design(n = 50L, seed = 1L)
  td@data$sort_na <- c(NA, seq_len(nrow(td@data) - 1L))
  expect_error(
    create_sdr_weights(td, sort_var = sort_na),
    class = "surveywts_error_sort_var_has_na"
  )
  expect_snapshot(error = TRUE, create_sdr_weights(td, sort_var = sort_na))
})

test_that("create_sdr_weights() rejects replicates = 0", {
  td <- make_taylor_design(seed = 1)
  expect_error(
    create_sdr_weights(td, replicates = 0L),
    class = "surveywts_error_replicates_not_positive"
  )
  expect_snapshot(error = TRUE, create_sdr_weights(td, replicates = 0L))
})

test_that("create_sdr_weights() rejects replicates = 3 (boundary: min is 4)", {
  td <- make_taylor_design(seed = 1)
  expect_error(
    create_sdr_weights(td, replicates = 3L),
    class = "surveywts_error_replicates_not_positive"
  )
  expect_snapshot(error = TRUE, create_sdr_weights(td, replicates = 3L))
})

test_that("create_sdr_weights() rejects fractional replicates", {
  td <- make_taylor_design(seed = 1)
  expect_error(
    create_sdr_weights(td, replicates = 2.5),
    class = "surveywts_error_replicates_not_whole_number"
  )
  expect_snapshot(error = TRUE, create_sdr_weights(td, replicates = 2.5))
})

test_that("create_sdr_weights() rejects survey_nonprob", {
  df <- make_surveywts_data(n = 30L, seed = 1L)
  np <- surveycore::survey_nonprob(
    data      = df,
    variables = list(weights = "base_weight"),
    metadata  = surveycore::survey_metadata()
  )
  expect_error(create_sdr_weights(np), class = "surveywts_error_nonprob_requires_probability_design")
  expect_snapshot(error = TRUE, create_sdr_weights(np))
})

# ---- Spec §XIII 11Ea: SDR equivalence with svrep ----------------------------

test_that("create_sdr_weights() matches svrep::as_sdr_design() directly", {
  skip_if_not_installed("svrep")
  td <- make_taylor_design(n = 80L, seed = 7L)

  direct <- svrep::as_sdr_design(
    surveycore::as_svydesign(td),
    replicates = 40L,
    mse        = TRUE
  )
  result <- create_sdr_weights(td, replicates = 40L)
  test_invariants(result)

  expected <- as.matrix(direct$repweights)
  actual   <- as.matrix(result@data[, result@variables$repweights])
  expect_equal(actual, expected, tolerance = 1e-10)
})

# ---- Spec §XIII 19f: edge cases ----------------------------------------------

test_that("create_sdr_weights() 0-row input propagates backend error", {
  skip_if_not_installed("svrep")
  df <- make_surveywts_data(n = 10L, seed = 1L)[0L, ]
  td <- surveycore::as_survey(df, ids = id, weights = base_weight)
  expect_error(create_sdr_weights(td, replicates = 10L))
})

test_that("create_sdr_weights() all-equal base weights succeeds", {
  skip_if_not_installed("svrep")
  df             <- make_surveywts_data(n = 50L, seed = 1L)
  df$base_weight <- rep(1, nrow(df))
  td     <- surveycore::as_survey(df, ids = id, weights = base_weight)
  result <- create_sdr_weights(td, replicates = 20L)
  test_invariants(result)
})
```

- [ ] **Step 3: Implement `create_sdr_weights()`**

Append to `R/replicate-weights.R`:

```r
# ============================================================================
# create_sdr_weights()
# ============================================================================

#' Create successive difference replication (SDR) weights
#'
#' Generates successive difference replication weights via
#' [svrep::as_sdr_design()]. Requires a `survey_taylor` design.
#'
#' @param data A `survey_taylor` design. PSUs should be in systematic
#'   selection order, or use `sort_var`.
#' @param replicates `integer(1)`, default `100L`. Target replicate count
#'   (≥ 4). Actual count may be slightly larger due to Hadamard matrix sizing.
#' @param ... Must be empty.
#' @param sort_var Bare column name or `NULL`. Column giving systematic
#'   selection order. `NULL` assumes row order reflects selection order.
#' @param mse `logical(1)`, default `TRUE`.
#'
#' @return A `survey_replicate` with `@variables$type = "successive-difference"`.
#'
#' @family replicate-weights
#' @export
create_sdr_weights <- function(
  data,
  replicates = 100L,
  ...,
  sort_var = NULL,
  mse = TRUE
) {
  .validate_replicate_input(data)

  if (S7::S7_inherits(data, surveycore::survey_nonprob)) {
    cli::cli_abort(
      c(
        "x" = "{.fn create_sdr_weights} requires a probability-design structure.",
        "i" = "{.cls survey_nonprob} has no PSU or stratum structure required by SDR.",
        "v" = "Use {.fn create_bootstrap_weights} for non-probability designs."
      ),
      class = "surveywts_error_nonprob_requires_probability_design"
    )
  }

  replicates <- .validate_replicates_arg(replicates, min_val = 4L)

  sort_quo <- rlang::enquo(sort_var)
  sort_col <- if (rlang::quo_is_null(sort_quo)) NULL else rlang::as_name(sort_quo)

  if (!is.null(sort_col)) {
    n_na <- sum(is.na(data@data[[sort_col]]))
    if (n_na > 0L) {
      cli::cli_abort(
        c(
          "x" = "{.arg sort_var} column {.field {sort_col}} contains {n_na} NA value(s).",
          "v" = "Remove rows with missing sort values before calling {.fn create_sdr_weights}."
        ),
        class = "surveywts_error_sort_var_has_na"
      )
    }
  }

  .convert_and_call(
    data       = data,
    backend_fn = function(d) {
      svrep::as_sdr_design(d, replicates = replicates, sort_variable = sort_col, mse = mse)
    },
    method     = "successive-difference",
    params     = list(replicates = replicates, sort_var = sort_col, mse = mse)
  )
}
```

- [ ] **Step 4: Run tests, `devtools::check()`, commit, open PR**

```bash
Rscript -e "devtools::document()"
git add R/replicate-weights.R tests/testthat/test-replicate-weights.R NAMESPACE man/
git commit -m "feat(replicate): add create_sdr_weights()"
```

- [ ] **Create changelog entry:** Create `changelog/replicate/feature-replicate-sdr.md` following the `changelog-workflow` skill format, then `git add changelog/replicate/feature-replicate-sdr.md && git commit -m "chore(replicate): add changelog for replicate-sdr"`. Then open PR to `develop`.

---

## PR 8: Print Method for `survey_replicate`

**Branch:** `feature/replicate-print`
**Files:** `R/replicate-print.R` (new), `tests/testthat/test-replicate-print.R` (new)

### Task 8.1: Write failing snapshot tests

- [ ] **Step 1: Create branch**

```bash
git checkout develop && git pull origin develop
git checkout -b feature/replicate-print
```

- [ ] **Step 2: Create `tests/testthat/test-replicate-print.R` with snapshot tests**

```r
# ---- Print snapshots (18a–18d) ----------------------------------------------

test_that("print(survey_replicate) bootstrap snapshot", {
  skip_if_not_installed("svrep")
  td     <- make_taylor_design(n = 100L, seed = 42L)
  result <- create_bootstrap_weights(td, replicates = 50L, seed = 1L)
  expect_snapshot(print(result))
})

test_that("print(survey_replicate) JKn stratified delete-1 snapshot", {
  skip_if_not_installed("survey")
  td     <- make_taylor_design(n = 100L, seed = 42L)
  result <- create_jackknife_weights(td, type = "delete-1")
  expect_snapshot(print(result))
})

test_that("print(survey_replicate) BRR snapshot", {
  skip_if_not_installed("survey")
  pd     <- make_paired_design(seed = 42L)
  result <- create_brr_weights(pd)
  expect_snapshot(print(result))
})

test_that("print(survey_replicate) two-entry history snapshot", {
  skip_if_not_installed("svrep")
  td  <- make_taylor_design(n = 100L, seed = 42L)
  rep <- create_bootstrap_weights(td, replicates = 20L, seed = 1L)
  # Append a synthetic second entry to test multi-step display
  synthetic_entry <- list(
    step      = 2L,
    operation = "calibration",
    timestamp = as.POSIXct("2026-01-15 10:00:00", tz = "UTC"),
    method    = "linear",
    parameters = list(variables = c("age_group", "sex"))
  )
  meta <- rep@metadata
  meta@weighting_history <- c(meta@weighting_history, list(synthetic_entry))
  rep@metadata <- meta
  expect_snapshot(print(rep))
})
```

- [ ] **Step 3: Confirm snapshot tests fail (method not yet defined)**

### Task 8.2: Implement the print method

- [ ] **Step 1: Create `R/replicate-print.R`**

```r
# R/replicate-print.R
#
# S7 print method for surveycore::survey_replicate.
# Class defined in surveycore (not in this package).

# Class defined in surveycore (surveycore::survey_replicate)
S7::method(print, surveycore::survey_replicate) <- function(x, ...) {
  vars    <- x@variables
  history <- x@metadata@weighting_history
  n_rep   <- length(vars$repweights)

  cat(sprintf("<survey_replicate: %s>\n", vars$type))
  cat(sprintf(
    "N = %s observations\n",
    formatC(nrow(x@data), format = "d", big.mark = ",")
  ))

  if (n_rep > 0L) {
    first_rep <- vars$repweights[[1L]]
    last_rep  <- vars$repweights[[n_rep]]
    cat(sprintf(
      "%d replicate weights (%s … %s)\n",
      n_rep, first_rep, last_rep
    ))
  }

  cat(sprintf("Scale: %s\n", format(vars$scale, digits = 4)))

  if (!is.null(vars$rscales) && length(vars$rscales) > 1L) {
    cat(sprintf(
      "Replicate scales: vector of length %d, range [%s, %s]\n",
      length(vars$rscales),
      format(min(vars$rscales), digits = 4),
      format(max(vars$rscales), digits = 4)
    ))
  }

  cat(sprintf("mse = %s\n", vars$mse))

  wt_vec <- x@data[[vars$weights]]
  cat("\nWeights:\n")
  cat(sprintf("  min:    %.2f\n", min(wt_vec)))
  cat(sprintf("  median: %.2f\n", stats::median(wt_vec)))
  cat(sprintf("  mean:   %.2f\n", mean(wt_vec)))
  cat(sprintf("  max:    %.2f\n", max(wt_vec)))
  cv_val <- stats::sd(wt_vec) / mean(wt_vec)
  cat(sprintf("  CV:     %.2f\n", cv_val))

  cat("\nWeighting history:\n")
  n_steps <- length(history)
  if (n_steps == 0L) {
    cat("  (none)\n")
  } else {
    for (entry in history) {
      cat("  ", .format_history_step(entry), "\n", sep = "")
    }
  }

  invisible(x)
}
```

- [ ] **Step 2: Run snapshot tests — they will record new snapshots on first run**

```r
devtools::test(filter = "replicate-print")
```

Expected: snapshot tests "pass" by recording new snapshots in `tests/testthat/_snaps/`

- [ ] **Step 3: Review snapshots**

```r
testthat::snapshot_review()
```

Review and accept each snapshot.

- [ ] **Step 4: Re-run to confirm snapshots are stable**

```r
devtools::test(filter = "replicate-print")
```

Expected: all tests pass (snapshots match)

- [ ] **Step 5: `devtools::check()`, commit, open PR**

```bash
Rscript -e "devtools::document()"
git add R/replicate-print.R tests/testthat/test-replicate-print.R \
    tests/testthat/_snaps/replicate-print.md NAMESPACE man/
git commit -m "feat(replicate): add print method for survey_replicate"
```

- [ ] **Create changelog entry:** Create `changelog/replicate/feature-replicate-print.md` following the `changelog-workflow` skill format, then `git add changelog/replicate/feature-replicate-print.md && git commit -m "chore(replicate): add changelog for replicate-print"`. Then open PR to `develop`.

---

## PR 9: Dispatcher + `as_taylor_design()`

**Branch:** `feature/replicate-dispatch`
**Files:** `R/replicate-dispatch.R` (new), `tests/testthat/test-replicate-dispatch.R` (new)

### Task 9.1: Write failing tests

- [ ] **Step 1: Create branch**

```bash
git checkout develop && git pull origin develop
git checkout -b feature/replicate-dispatch
```

- [ ] **Step 2: Create `tests/testthat/test-replicate-dispatch.R`**

```r
# tests/testthat/test-replicate-dispatch.R

# ---- create_replicate_weights() dispatch (14a–14h) -------------------------

test_that("create_replicate_weights() bootstrap dispatches correctly", {
  skip_if_not_installed("svrep")
  td     <- make_taylor_design(seed = 1L)
  result <- create_replicate_weights(td, method = "bootstrap",
                                      replicates = 20L, seed = 1L)
  expect_true(S7::S7_inherits(result, surveycore::survey_replicate))
  expect_identical(result@variables$type, "bootstrap")
})

test_that("create_replicate_weights() jackknife dispatches correctly", {
  skip_if_not_installed("survey")
  td     <- make_taylor_design(seed = 1L)
  result <- create_replicate_weights(td, method = "jackknife")
  expect_true(S7::S7_inherits(result, surveycore::survey_replicate))
})

test_that("create_replicate_weights() brr dispatches correctly", {
  skip_if_not_installed("survey")
  pd     <- make_paired_design(seed = 1L)
  result <- create_replicate_weights(pd, method = "brr")
  expect_true(S7::S7_inherits(result, surveycore::survey_replicate))
})

test_that("create_replicate_weights() generalized-bootstrap dispatches correctly", {
  skip_if_not_installed("svrep")
  td     <- make_taylor_design(seed = 1L)
  result <- create_replicate_weights(td, method = "generalized-bootstrap",
                                      replicates = 10L, seed = 1L)
  expect_true(S7::S7_inherits(result, surveycore::survey_replicate))
})

test_that("create_replicate_weights() generalized-replicate dispatches correctly", {
  skip_if_not_installed("svrep")
  td     <- make_taylor_design(seed = 1L)
  result <- create_replicate_weights(td, method = "generalized-replicate")
  expect_true(S7::S7_inherits(result, surveycore::survey_replicate))
})

test_that("create_replicate_weights() successive-difference dispatches correctly", {
  skip_if_not_installed("svrep")
  td     <- make_taylor_design(seed = 1L)
  result <- create_replicate_weights(td, method = "successive-difference",
                                      replicates = 20L)
  expect_true(S7::S7_inherits(result, surveycore::survey_replicate))
})

test_that("create_replicate_weights() passes ... to underlying function", {
  skip_if_not_installed("svrep")
  td     <- make_taylor_design(seed = 1L)
  result <- create_replicate_weights(td, method = "bootstrap",
                                      replicates = 10L, mse = FALSE, seed = 1L)
  test_invariants(result)
  expect_false(result@variables$mse)
})

test_that("create_replicate_weights() invalid method errors via arg_match", {
  td <- make_taylor_design(seed = 1L)
  expect_error(create_replicate_weights(td, method = "not-a-method"))
})

# ---- as_taylor_design() happy path (15a–15c) --------------------------------

test_that("as_taylor_design() converts survey_replicate -> survey_taylor", {
  skip_if_not_installed("svrep")
  td  <- make_taylor_design(seed = 1L)
  rep <- create_bootstrap_weights(td, replicates = 20L, seed = 1L)

  expect_warning(
    result <- as_taylor_design(rep),
    class = "surveywts_warning_taylor_loses_variance"
  )
  expect_true(S7::S7_inherits(result, surveycore::survey_taylor))
})

test_that("as_taylor_design() drops replicate columns from @data", {
  skip_if_not_installed("svrep")
  td  <- make_taylor_design(seed = 1L)
  rep <- create_bootstrap_weights(td, replicates = 20L, seed = 1L)

  expect_warning(
    result <- as_taylor_design(rep),
    class = "surveywts_warning_taylor_loses_variance"
  )
  rep_col_names <- paste0("rep_", seq_len(20L))
  expect_false(any(rep_col_names %in% names(result@data)))
})

test_that("as_taylor_design() preserves original design structure (ids, strata)", {
  skip_if_not_installed("svrep")
  td  <- make_taylor_design(seed = 1L)
  rep <- create_bootstrap_weights(td, replicates = 20L, seed = 1L)

  expect_warning(
    result <- as_taylor_design(rep),
    class = "surveywts_warning_taylor_loses_variance"
  )
  expect_identical(result@variables$ids,    td@variables$ids)
  expect_identical(result@variables$strata, td@variables$strata)
})

test_that("as_taylor_design() round-trips SRS design with ids = NULL", {
  skip_if_not_installed("svrep")
  df  <- make_surveywts_data(n = 40L, seed = 3L)
  srs <- surveycore::as_survey(df, weights = base_weight)  # ids = NULL
  rep <- create_bootstrap_weights(srs, replicates = 10L, seed = 1L)

  expect_warning(
    result <- as_taylor_design(rep),
    class = "surveywts_warning_taylor_loses_variance"
  )
  expect_true(S7::S7_inherits(result, surveycore::survey_taylor))
  expect_null(result@variables$ids)
})

# ---- as_taylor_design() warnings (16a–16b) ----------------------------------

test_that("as_taylor_design() warns and returns unchanged for survey_taylor input", {
  td <- make_taylor_design(seed = 1L)
  expect_warning(
    result <- as_taylor_design(td),
    class = "surveywts_warning_already_taylor"
  )
  expect_identical(result, td)
})

test_that("as_taylor_design() emits taylor_loses_variance warning", {
  skip_if_not_installed("svrep")
  td  <- make_taylor_design(seed = 1L)
  rep <- create_bootstrap_weights(td, replicates = 20L, seed = 1L)
  expect_warning(as_taylor_design(rep), class = "surveywts_warning_taylor_loses_variance")
})

# Snapshot the warnings
test_that("as_taylor_design() already_taylor warning snapshot", {
  td <- make_taylor_design(seed = 1L)
  expect_snapshot(
    expect_warning(
      as_taylor_design(td),
      class = "surveywts_warning_already_taylor"
    )
  )
})

# ---- as_taylor_design() errors (17a–17e) ------------------------------------

test_that("as_taylor_design() rejects unsupported class", {
  expect_error(as_taylor_design(list(x = 1)), class = "surveywts_error_unsupported_class")
  expect_snapshot(error = TRUE, as_taylor_design(list(x = 1)))
})

test_that("as_taylor_design() errors when no replicate_creation history entry", {
  skip_if_not_installed("svrep")
  td  <- make_taylor_design(seed = 1L)
  rep <- create_bootstrap_weights(td, replicates = 10L, seed = 1L)
  # Strip all history to simulate missing creation entry
  rep@metadata@weighting_history <- list()
  expect_error(as_taylor_design(rep), class = "surveywts_error_no_taylor_structure")
  expect_snapshot(error = TRUE, as_taylor_design(rep))
})

test_that("as_taylor_design() errors when post-creation calibration is present", {
  skip_if_not_installed("svrep")
  td  <- make_taylor_design(seed = 1L)
  rep <- create_bootstrap_weights(td, replicates = 10L, seed = 1L)
  # Append a synthetic post-creation calibration entry
  fake_entry <- list(
    step      = 2L,
    operation = "calibration",
    timestamp = Sys.time(),
    method    = "linear",
    parameters = list(variables = "age_group")
  )
  meta <- rep@metadata
  meta@weighting_history <- c(meta@weighting_history, list(fake_entry))
  rep@metadata <- meta
  expect_error(
    as_taylor_design(rep),
    class = "surveywts_error_taylor_from_calibrated_replicate"
  )
  expect_snapshot(error = TRUE, as_taylor_design(rep))
})

test_that("as_taylor_design() errors when source was survey_nonprob", {
  skip_if_not_installed("svrep")
  df <- make_surveywts_data(n = 50L, seed = 1L)
  np <- surveycore::survey_nonprob(
    data      = df,
    variables = list(weights = "base_weight"),
    metadata  = surveycore::survey_metadata()
  )
  rep <- create_bootstrap_weights(np, replicates = 10L, seed = 1L)
  expect_error(
    as_taylor_design(rep),
    class = "surveywts_error_taylor_from_nonprob_replicate"
  )
  expect_snapshot(error = TRUE, as_taylor_design(rep))
})

test_that("as_taylor_design() SRS survey_taylor round-trip succeeds (class-tag detector)", {
  # SRS design has ids = NULL, strata = NULL — same shape as nonprob.
  # Detector uses the is_nonprob boolean flag in history, not design shape.
  skip_if_not_installed("svrep")
  df  <- make_surveywts_data(n = 50L, seed = 1L)
  srs <- surveycore::as_survey(df, ids = id, weights = base_weight)
  rep <- create_bootstrap_weights(srs, replicates = 10L, seed = 1L)
  expect_warning(
    result <- as_taylor_design(rep),
    class = "surveywts_warning_taylor_loses_variance"
  )
  expect_true(S7::S7_inherits(result, surveycore::survey_taylor))
})
```

- [ ] **Step 3: Confirm tests fail**

```r
devtools::test(filter = "replicate-dispatch")
```

Expected: all fail with "could not find function"

### Task 9.2: Implement `create_replicate_weights()` and `as_taylor_design()`

- [ ] **Step 1: Create `R/replicate-dispatch.R`**

```r
# R/replicate-dispatch.R
#
# create_replicate_weights() — dispatcher
# as_taylor_design()         — inverse conversion

# ============================================================================
# create_replicate_weights()
# ============================================================================

#' Create replicate weights (dispatcher)
#'
#' Dispatches to the appropriate `create_*_weights()` function based on
#' `method`. All validation, defaults, and error messages are handled by the
#' dispatched function; this function only resolves the method name.
#'
#' @param data A `survey_taylor` or `survey_nonprob` design.
#' @param method `character(1)`. One of `"bootstrap"`, `"jackknife"`, `"brr"`,
#'   `"generalized-bootstrap"`, `"generalized-replicate"`,
#'   `"successive-difference"`.
#' @param ... Passed as-is to the dispatched function. Invalid arguments for
#'   the selected method produce R's native "unused argument" error.
#'
#' @return A `survey_replicate`.
#'
#' @family replicate-weights
#' @export
create_replicate_weights <- function(
  data,
  method = c(
    "bootstrap", "jackknife", "brr",
    "generalized-bootstrap", "generalized-replicate",
    "successive-difference"
  ),
  ...
) {
  method <- rlang::arg_match(method)
  switch(
    method,
    bootstrap                = create_bootstrap_weights(data, ...),
    jackknife                = create_jackknife_weights(data, ...),
    brr                      = create_brr_weights(data, ...),
    "generalized-bootstrap"  = create_gen_boot_weights(data, ...),
    "generalized-replicate"  = create_gen_rep_weights(data, ...),
    "successive-difference"  = create_sdr_weights(data, ...)
  )
}

# ============================================================================
# as_taylor_design()
# ============================================================================

#' Convert a replicate design back to a Taylor design
#'
#' Reconstructs a `survey_taylor` from a `survey_replicate` created by
#' `create_*_weights()`. The original Taylor structure (PSU IDs, strata, FPC,
#' nest flag) is read from the `"replicate_creation"` entry in the weighting
#' history. Replicate weight columns are dropped from `@data`.
#'
#' Returns `data` unchanged (with a warning) if `data` is already a
#' `survey_taylor`.
#'
#' @param data A `survey_replicate` created by `create_*_weights()`, or a
#'   `survey_taylor` (returns unchanged with a warning).
#'
#' @return A `survey_taylor`.
#'
#' @family replicate-weights
#' @export
as_taylor_design <- function(data) {
  if (S7::S7_inherits(data, surveycore::survey_taylor)) {
    cli::cli_warn(
      c("!" = "{.arg data} is already a {.cls survey_taylor}; returning unchanged."),
      class = "surveywts_warning_already_taylor"
    )
    return(data)
  }

  if (!S7::S7_inherits(data, surveycore::survey_replicate)) {
    cls <- class(data)[[1L]]
    cli::cli_abort(
      c(
        "x" = "{.arg data} must be a {.cls survey_replicate} or {.cls survey_taylor}.",
        "i" = "Got {.cls {cls}}."
      ),
      class = "surveywts_error_unsupported_class"
    )
  }

  history      <- data@metadata@weighting_history
  creation_idx <- which(
    vapply(
      history,
      function(e) identical(e$operation, "replicate_creation"),
      logical(1)
    )
  )

  if (length(creation_idx) == 0L) {
    cli::cli_abort(
      c(
        "x" = "No {.val replicate_creation} entry found in the weighting history.",
        "i" = "Cannot reconstruct the original Taylor design without the stored structure.",
        "v" = "Only designs created with {.fn create_*_weights} functions can be converted back."
      ),
      class = "surveywts_error_no_taylor_structure"
    )
  }

  last_idx     <- max(creation_idx)
  last_creation <- history[[last_idx]]

  # Check for post-creation weight adjustments
  if (last_idx < length(history)) {
    post_ops <- vapply(
      history[(last_idx + 1L):length(history)],
      function(e) e$operation,
      character(1)
    )
    cli::cli_abort(
      c(
        "x" = "Cannot reconstruct Taylor design: replicate weights were adjusted after creation.",
        "i" = "Post-creation operation(s): {.and {.val {post_ops}}}.",
        "v" = "Conversion back to Taylor is only supported for unadjusted replicate designs."
      ),
      class = "surveywts_error_taylor_from_calibrated_replicate"
    )
  }

  # Check source class — must not be survey_nonprob
  if (isTRUE(last_creation$source_design$is_nonprob)) {
    cli::cli_abort(
      c(
        "x" = paste0(
          "Source design was a {.cls survey_nonprob}; ",
          "cannot reconstruct a {.cls survey_taylor}."
        ),
        "i" = paste0(
          "Non-probability samples lack the probability-design structure ",
          "required for Taylor linearization."
        )
      ),
      class = "surveywts_error_taylor_from_nonprob_replicate"
    )
  }

  cli::cli_warn(
    c("!" = "Converting to {.cls survey_taylor} discards replicate weights and variance capability."),
    class = "surveywts_warning_taylor_loses_variance"
  )

  source_vars <- last_creation$source_design$variables
  rep_cols    <- data@variables$repweights
  clean_data  <- data@data[, !names(data@data) %in% rep_cols, drop = FALSE]

  # source_vars$ids/strata/weights/fpc are stored character column names.
  # as_survey() uses tidy-eval (enquo), so character strings must be converted
  # to symbols with rlang::sym() and unquoted with !! inside rlang::inject().
  # ids may be NULL for SRS designs (no cluster structure); guard all optional args.
  weights_sym <- rlang::sym(source_vars$weights)
  optional    <- list()
  if (!is.null(source_vars$ids))    optional$ids    <- rlang::sym(source_vars$ids)
  if (!is.null(source_vars$strata)) optional$strata <- rlang::sym(source_vars$strata)
  if (!is.null(source_vars$fpc))    optional$fpc    <- rlang::sym(source_vars$fpc)

  rlang::inject(surveycore::as_survey(
    clean_data,
    weights = !!weights_sym,
    nest    = isTRUE(source_vars$nest),
    !!!optional
  ))
}
```

- [ ] **Step 2: Run tests**

```r
devtools::test(filter = "replicate-dispatch")
```

Expected: all tests pass (snapshots record on first run — accept them)

- [ ] **Step 3: Review new snapshots**

```r
testthat::snapshot_review()
```

- [ ] **Step 4: Re-run to confirm all pass**

- [ ] **Step 5: Run full test suite**

```r
devtools::test()
```

Expected: all existing tests still pass

- [ ] **Step 6: `devtools::check()`, commit, open PR**

```bash
Rscript -e "devtools::document()"
git add R/replicate-dispatch.R tests/testthat/test-replicate-dispatch.R \
    tests/testthat/_snaps/replicate-dispatch.md NAMESPACE man/
git commit -m "feat(replicate): add create_replicate_weights() dispatcher and as_taylor_design()"
```

- [ ] **Create changelog entry:** Create `changelog/replicate/feature-replicate-dispatch.md` following the `changelog-workflow` skill format, then `git add changelog/replicate/feature-replicate-dispatch.md && git commit -m "chore(replicate): add changelog for replicate-dispatch"`. Then open PR to `develop`.

---

## Post-PR: Coverage and Release Prep

After all 9 PRs are merged to `develop`:

- [ ] **Step 1: Check coverage**

```r
covr::package_coverage()
```

Target: ≥ 98% for `R/replicate-weights.R`, `R/replicate-dispatch.R`, `R/replicate-print.R`

- [ ] **Step 2: Verify all §XIII test blocks pass**

Spec §XIII blocks 19a–19f are implemented in their respective PRs (19a in PR 2, 19b in PR 3, 19c in PR 4, 19d in PR 5, 19e in PR 6, 19f in PR 7). Confirm all blocks (1–19) pass before proceeding.

- [ ] **Step 3: Run release prep via `/merge-main`**

The `/merge-main` skill handles NEWS.md update, version bump to `0.2.0`, final `devtools::check()`, PR `develop → main`, tag, and post-release `.9000` bump.

---

## Quality Gates (spec §XV)

Before opening the release PR:

- [ ] All six `create_*_weights()` + `create_replicate_weights()` + `as_taylor_design()` pass `devtools::check()` with 0 errors, 0 warnings, ≤2 notes
- [ ] Test coverage ≥ 98% for all three new source files
- [ ] All error classes from spec §XII are in `plans/error-messages.md`
- [ ] All §XIII test blocks (1–19) are implemented and passing
- [ ] Equivalence tests against svrep/survey pass for all six backends (tolerance `1e-10`)
- [ ] Metadata preservation verified (variable labels, history survive conversion pipeline)
- [ ] `svrep (>= 0.6.0)` and `withr (>= 2.5.0)` in DESCRIPTION Imports
- [ ] `surveycore (>= 0.8.0)` floor in DESCRIPTION
