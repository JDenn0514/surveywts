# surveywts Spec: Calibration NPS Bootstrap Compatibility

**Version:** 0.2 — Stage 4 resolve complete
**Date:** 2026-05-19
**Status:** Draft
**ID:** `calibration-nps-compat`

---

## Document Purpose

This spec is the source of truth for small, targeted additions to `rake()` and
`calibrate()` that make them NPS bootstrap-compatible. The changes are:

1. A new `reference_design` argument on both functions
2. A `targets_from_reference` field in each function's history entry

These additions are required by the quasi-randomization bootstrap
(`create_bootstrap_weights(type = "quasi-randomization")`) specified in
`plans/spec-methodology-nps-bootstrap.md`. That bootstrap replays the full
weighting history inside each draw and needs to know (a) whether calibration
targets were estimated from the reference probability survey and (b) which
reference design to resample when re-estimating targets.

The changes to `rake()` and `calibrate()` are backward-compatible: all
existing arguments retain their behavior; the new argument defaults to `NULL`,
which produces a `targets_from_reference = FALSE` history field — identical
in effect to the current state of the history entry.

---

## I. Scope

### Deliverables

| Deliverable | Function | File |
|---|---|---|
| `reference_design` argument | `rake()` | `R/rake.R` |
| `targets_from_reference` in history | `rake()` | `R/rake.R` |
| `reference_design` argument | `calibrate()` | `R/calibrate.R` |
| `targets_from_reference` in history | `calibrate()` | `R/calibrate.R` |

### What This Spec Does NOT Deliver

- Changes to `poststratify()` — `poststratify()` is rarely used in NPS
  calibration pipelines; defer to a future spec if the quasi-randomization
  bootstrap needs to replay post-stratification steps.
- Changes to `create_bootstrap_weights()` — the quasi-randomization and hybrid
  bootstrap types are specified in `spec-methodology-nps-bootstrap.md`; they
  are a separate deliverable.
- `weighted_df` → `create_bootstrap_weights()` pipe — `create_bootstrap_weights()`
  currently rejects `weighted_df` input with a message to use `as_survey()`.
  This is correct behavior. The NPS pipeline flows through `survey_nonprob`
  objects (produced by `ipw()`), so `weighted_df` support is not needed here.
- Changes to `adjust_nonresponse()` — nonresponse history entries are not
  replayed by the quasi-randomization bootstrap.
- Any change to `ipw()` — `ipw()` already specifies `targets_from_reference`
  and `reference_design` fields in its history entry per `spec-propensity.md §III`.

### Input Class Support

These changes affect `rake()` and `calibrate()` for all input classes they
already accept. The `reference_design` argument is valid with any input class;
no restriction to `survey_nonprob`.

### Why the Pipe Already Works (Design Clarification)

`create_bootstrap_weights()` accepts `survey_taylor` and `survey_nonprob`.
When `rake()` or `calibrate()` receive a `survey_nonprob` (e.g., the output
of `ipw()`), they return a `survey_nonprob`. The pipe

```r
ipw(data, selection, reference) |>
  rake(margins = pop_margins) |>
  create_bootstrap_weights()
```

already works at the class level today. What the quasi-randomization bootstrap
adds is the ability to **replay** `rake()` and `calibrate()` inside each draw.
That requires reading the history entries — hence the history additions in this
spec, not class-level changes.

---

## II. Architecture

No new files beyond the addition to `R/utils.R` described below. The only
change in each function is:
1. Add `reference_design = NULL` to the function signature
2. Call `.validate_reference_design(reference_design)` immediately after
   argument capture
3. Add `targets_from_reference` and (when non-NULL) `reference_design` to
   the `parameters` list passed to `.make_history_entry()`

### Shared helper: `.validate_reference_design()`

Because the same validation logic is needed in both `rake.R` and `calibrate.R`,
it is extracted to `R/utils.R` per `code-style.md §4`:

```r
.validate_reference_design <- function(reference_design) {
  if (!is.null(reference_design) &&
        !S7::S7_inherits(reference_design, surveycore::survey_taylor)) {
    cli::cli_abort(
      c(
        "x" = "{.arg reference_design} must be a {.cls survey_taylor}.",
        "i" = "Got class {.cls {class(reference_design)[[1L]]}}.",
        "v" = "Pass the {.cls survey_taylor} object used to compute the targets."
      ),
      class = "surveywts_error_reference_design_not_taylor"
    )
  }
  invisible(NULL)
}
```

No content validation of `reference_design` is performed beyond the class
check. Mis-specified `reference_design` objects (e.g., missing the variables
used in `margins`) are detected at bootstrap-replay time, not at recording
time. Do not add variable-overlap or row-count checks here.

No changes to `.make_history_entry()` or any other shared helper.

---

## III. Changes to `rake()`

### Updated Signature

```r
rake <- function(
  data,
  margins,
  weights          = NULL,
  wt_name          = "wts",
  type             = c("prop", "count"),
  method           = c("anesrake", "survey"),
  cap              = NULL,
  control          = list(),
  reference_design = NULL         # NEW
)
```

### New Argument

| Argument | Type | Default | Description |
|---|---|---|---|
| `reference_design` | `survey_taylor` or `NULL` | `NULL` | The reference probability survey from which `margins` were estimated. When non-`NULL`, stored in the history entry and `targets_from_reference` is set to `TRUE`. Pass the same `survey_taylor` object used to compute the margin targets. `NULL` (default) means targets are fixed population benchmarks. |

### Validation Rule

`reference_design` must satisfy `S7::S7_inherits(reference_design, surveycore::survey_taylor)` when non-`NULL`. Any other non-`NULL` class → `surveywts_error_reference_design_not_taylor`. Validated immediately after argument capture, before any data processing.

### Updated History Entry `parameters`

The `parameters` list passed to `.make_history_entry()` gains two new fields:

```r
parameters = list(
  variables            = margin_var_names,
  margins              = margins_a,          # Format A (existing)
  type                 = type,               # existing (added here for bootstrap replay)
  method               = method,             # existing
  cap                  = cap,                # existing
  control              = control_resolved,   # existing
  targets_from_reference = !is.null(reference_design),   # NEW
  reference_design     = reference_design    # NEW; NULL when not provided
)
```

`targets_from_reference` is derived automatically from whether `reference_design`
is `NULL` — no user-facing boolean argument needed.

### No Behavioral Change

All existing behavior is unchanged. `reference_design` participates in no
computation; it is recorded only.

---

## IV. Changes to `calibrate()`

### Updated Signature

```r
calibrate <- function(
  data,
  variables,
  population,
  weights          = NULL,
  wt_name          = "wts",
  method           = c("linear", "logit"),
  type             = c("prop", "count"),
  control          = list(maxit = 50, epsilon = 1e-7),
  reference_design = NULL         # NEW
)
```

### New Argument

| Argument | Type | Default | Description |
|---|---|---|---|
| `reference_design` | `survey_taylor` or `NULL` | `NULL` | The reference probability survey from which `population` targets were estimated. When non-`NULL`, stored in the history entry and `targets_from_reference` is set to `TRUE`. `NULL` (default) means targets are fixed population benchmarks. |

### Validation Rule

Same as `rake()`: `S7::S7_inherits(reference_design, surveycore::survey_taylor)` when non-`NULL`. Error class: `surveywts_error_reference_design_not_taylor`. Validated immediately after argument capture.

### Updated History Entry `parameters`

```r
parameters = list(
  variables            = variable_names,
  population           = population,         # existing
  method               = method,             # existing
  type                 = type,               # existing
  control              = control,            # existing
  targets_from_reference = !is.null(reference_design),   # NEW
  reference_design     = reference_design    # NEW; NULL when not provided
)
```

### No Behavioral Change

All existing behavior is unchanged.

---

## V. Error Table

| Error class | Trigger | Message template |
|---|---|---|
| `surveywts_error_reference_design_not_taylor` | `reference_design` is non-`NULL` and is not `survey_taylor` | `"x"` = `"{.arg reference_design} must be a {.cls survey_taylor}."`; `"i"` = `"Got class {.cls {class(reference_design)[[1L]]}}."` ; `"v"` = `"Pass the {.cls survey_taylor} object used to compute the targets."` |

No new warning classes.

---

## VI. Testing

### `rake()` tests (add to `tests/testthat/test-03-rake.R`)

**Happy path — `reference_design` recorded in history:**
```r
test_that("rake() records reference_design and targets_from_reference = TRUE in history", {
  # ... setup ...
  result <- rake(data, margins = margins, reference_design = ref_taylor)
  test_invariants(result)
  entry <- attr(result, "weighting_history")[[1L]]
  expect_true(entry$parameters$targets_from_reference)
  expect_identical(entry$parameters$reference_design, ref_taylor)
})
```

**Happy path — default NULL produces `targets_from_reference = FALSE`:**
```r
test_that("rake() records targets_from_reference = FALSE when reference_design = NULL", {
  result <- rake(data, margins = margins)
  test_invariants(result)
  entry <- attr(result, "weighting_history")[[1L]]
  expect_false(entry$parameters$targets_from_reference)
  expect_null(entry$parameters$reference_design)
})
```

**Error path — wrong class for `reference_design`:**
```r
test_that("rake() rejects non-taylor reference_design", {
  expect_error(
    rake(data, margins = margins, reference_design = list()),
    class = "surveywts_error_reference_design_not_taylor"
  )
  expect_snapshot(
    error = TRUE,
    rake(data, margins = margins, reference_design = list())
  )
})
```

### `calibrate()` tests (add to `tests/testthat/test-02-calibrate.R`)

Same three blocks as the `rake()` tests above, substituting `calibrate()` and
`population`. The happy-path blocks must include `test_invariants(result)` as
the first assertion, identical to the `rake()` pattern:

```r
test_that("calibrate() records reference_design and targets_from_reference = TRUE in history", {
  # ... setup ...
  result <- calibrate(data, variables = c(age_group), population = pop,
                      reference_design = ref_taylor)
  test_invariants(result)
  entry <- attr(result, "weighting_history")[[1L]]
  expect_true(entry$parameters$targets_from_reference)
  expect_identical(entry$parameters$reference_design, ref_taylor)
})

test_that("calibrate() records targets_from_reference = FALSE when reference_design = NULL", {
  result <- calibrate(data, variables = c(age_group), population = pop)
  test_invariants(result)
  entry <- attr(result, "weighting_history")[[1L]]
  expect_false(entry$parameters$targets_from_reference)
  expect_null(entry$parameters$reference_design)
})
```

### Coverage

Both functions already have comprehensive tests. These additions require:
- 2 new happy-path blocks per function (4 total)
- 1 new error-path block per function (2 total)

---

## VII. Quality Gates

- [ ] `devtools::document()` run after roxygen2 changes
- [ ] `plans/error-messages.md` updated with `surveywts_error_reference_design_not_taylor`
- [ ] `surveywts-conventions.md` updated if `reference_design` arg pattern is added to the
      argument-order table (it follows `control` in both functions — after all other optional
      scalars, consistent with the rule that `control` is last before the new extension args)
- [ ] `R CMD check` passes: 0 errors, 0 warnings, ≤2 notes
- [ ] `devtools::test()` passes
- [ ] New snapshot tests reviewed and committed
- [ ] Coverage remains ≥ 98%

---

## VIII. Integration Notes

### Dependency: `ipw()` history entry

`spec-propensity.md §III` specifies that the `ipw()` history entry has
`targets_from_reference = FALSE` as a default field. The note in that spec
reads: "a subsequent rake()/calibrate() sets TRUE if its targets are derived
from reference_design." This spec implements that intent: `rake()` and
`calibrate()` set their own `targets_from_reference` field; they do NOT
modify the `ipw()` entry retroactively. The quasi-randomization bootstrap
reads all entries in sequence.

### Bootstrap Replay Contract

When the quasi-randomization bootstrap (future) replays `rake()` in draw `b`:

- If `parameters$targets_from_reference = FALSE`: call
  `rake(resampled_nonprob, margins = entry$parameters$margins, type = entry$parameters$type, method = entry$parameters$method, ...)`
  with the stored fixed margins.
- If `parameters$targets_from_reference = TRUE`: re-estimate margins from the
  resampled reference design `entry$parameters$reference_design` (or the one
  stored in the `ipw` entry), then call `rake()` with the re-estimated margins
  and `type = entry$parameters$type`.

The `calibrate()` replay is symmetric: fixed `population` when
`targets_from_reference = FALSE`; re-estimated `population` when `TRUE`.

### Argument Position

`reference_design` is placed last in both signatures, after `control`. This
follows the argument order rule in `code-style.md` (optional scalars before
`...`; NPS-bootstrap-specific extension args go last). It is never NSE and
takes a default of `NULL`.
