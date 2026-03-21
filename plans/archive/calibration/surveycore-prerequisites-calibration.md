# Surveycore Prerequisites — Phase 0

**Created:** 2026-02-28
**Status:** Ready to implement in surveycore
**Blocking:** surveywts Phase 0, PRs 3–9

This document is a complete specification of every change required in the
`surveycore` package before surveywts Phase 0 implementation can begin.
It is extracted from `plans/spec-phase-0.md` and `plans/impl-phase-0.md`.

---

## Open Gaps (resolve before implementing)

These must be confirmed against surveycore source before writing any code:

| # | Question | Impact |
|---|----------|--------|
| **GAP 1** | Exact `survey_base` property names and inheritance path — are `@data`, `@variables`, `@metadata` the actual property names? | BLOCKING: surveywts' `survey_nonprob` inherits from `survey_base` |
| **GAP 2** | Exact name and signature for the `weighting_history` accessor | BLOCKING: surveywts calls it as `survey_weighting_history(x)` |
| **GAP 3** | Is `@variables$weights` a `character(1)` column name (not the vector itself)? | CRITICAL: all weight extraction logic depends on this |
| **GAP 4** | Minimum surveycore version once this PR merges — surveywts will pin to it | BLOCKING: locks the `surveycore (>= X.Y.Z)` DESCRIPTION entry |

---

## 1. New metadata property: `weighting_history`

Add a `weighting_history` list property to the surveycore metadata class.

**Specification:**
- **Property name:** `weighting_history`
- **Type:** `list`
- **Default:** `list()` (empty list)
- **Access pattern used by surveywts:** `obj@metadata@weighting_history`

Each element of the list is a history entry appended by surveywts after
each calibration or nonresponse adjustment operation. The entry structure
is fully specified in `plans/spec-phase-0.md §IV.5` and is reproduced below
for reference:

```r
list(
  step            = 1L,
  operation       = "raking",  # "raking" | "calibration" | "poststratify" |
                               # "nonresponse_weighting_class" | "trim" |
                               # "stabilize" | "construction"
  timestamp       = Sys.time(),
  call            = "rake(df, ...)",   # deparsed character string
  parameters      = list(             # operation-specific; resolved column names
    variables     = c("age", "sex"),
    population    = list(...),
    control       = list(maxit = 50, epsilon = 1e-7)
  ),
  weight_stats    = list(
    before = list(n=1500, n_positive=1500, n_zero=0, mean=1.0, cv=0.18,
                  min=0.3, p25=0.7, p50=0.95, p75=1.2, max=3.1, ess=1189),
    after  = list(...)
  ),
  convergence     = list(converged=TRUE, iterations=12, max_error=0.0003,
                         tolerance=1e-6),  # NULL for non-iterative operations
  package_version = "0.1.0"
)
```

Surveycore does not need to validate or inspect this structure — it only
stores and exposes it.

---

## 2. Update constructors to accept `weighted_df` input

Update surveycore constructors (e.g., `as_survey_taylor()`) to accept a
`weighted_df` as the `data` argument and promote its weighting history.

**Specification:**
- **Trigger:** Input to constructor is a `weighted_df` (S3 class, has
  `attr(x, "weighting_history")`)
- **Action:** Extract `attr(data, "weighting_history")` and assign it to
  `@metadata@weighting_history` on the resulting survey object
- **Fallback:** If input is a plain `data.frame` (no `weighting_history`
  attribute), `@metadata@weighting_history` defaults to `list()`

**Why this is needed:**
A user may build a `weighted_df` through surveywts calibration functions,
then pass it to a surveycore constructor to attach design metadata (strata,
PSUs, etc.). The weighting history accumulated before the constructor call
must be preserved on the resulting survey object.

---

## 3. New exported accessor: `survey_weighting_history()`

Add and export a function that extracts the weighting history list from any
survey object.

**Specification:**
```r
#' Extract the weighting history from a survey object
#'
#' @param x A survey object (any class inheriting from `survey_base`).
#' @return A list of history entries, or `list()` if no history is present.
#' @export
survey_weighting_history <- function(x) {
  x@metadata@weighting_history
}
```

- **Name:** `survey_weighting_history` (subject to GAP 2 confirmation)
- **Input:** Any `survey_base` subclass
- **Return:** `list` (never `NULL`; return `list()` if property is empty)
- **Export:** Yes — called by surveywts and user code

---

## 4. Assumed existing surveycore API

Surveyweights Phase 0 assumes the following already exists in surveycore.
Verify each against source before writing the prerequisite PR:

### Class hierarchy

```
survey_base    (abstract S7 class)
  ├── survey_taylor
  └── survey_replicate
```

`survey_nonprob` will be defined in **surveywts**, inheriting from
`surveycore::survey_base`.

### `survey_base` properties assumed

| Property | Type | Access pattern |
|----------|------|----------------|
| `@data` | `data.frame` | `obj@data` |
| `@variables` | named `list` | `obj@variables$weights`, `obj@variables$ids`, etc. |
| `@metadata` | metadata S7 class | `obj@metadata@weighting_history` |

### `@variables` structure assumed

| Key | Type | Description |
|-----|------|-------------|
| `$weights` | `character(1)` | Column name of the weight variable (not the vector) |
| `$ids` | `character` | One or more PSU column names |
| `$strata` | `character` or `NULL` | Stratum column name(s) |
| `$fpc` | `character` or `NULL` | FPC column name(s) |
| `$nest` | `logical(1)` | Whether PSUs are nested within strata |

**GAP 3:** Confirm `$weights` is a column name scalar, not the weight vector.

### `survey_base` validator assumed

Surveyweights spec §V assumes the `survey_base` parent validator already
enforces the presence of the required `@variables` keys (`ids`, `weights`,
`strata`, `fpc`, `nest`). **GAP 1:** Verify this. If it does NOT enforce these,
surveywts will add corresponding checks to the `survey_nonprob`
validator.

---

## 5. Export requirements

The following must be exported from surveycore for use in surveywts:

| Name | Type | Status |
|------|------|--------|
| `survey_base` | S7 class object | Already exported (assumed) |
| `survey_taylor` | S7 class object | Already exported (assumed) |
| `survey_replicate` | S7 class object | Already exported (assumed) |
| `survey_weighting_history()` | Function | **NEW — add in this PR** |

---

## 6. DESCRIPTION impact on surveywts

Once this PR is merged, update the following in surveywts `DESCRIPTION`:

```
Imports:
    surveycore (>= X.Y.Z),   # replace X.Y.Z with the version that ships this PR

Remotes:
    surveyverse/surveycore   # remove once surveycore is on CRAN
```

---

## Summary

| Change | File(s) | Required before |
|--------|---------|-----------------|
| Add `weighting_history` list property to metadata class | metadata class definition | surveywts PR 3 |
| Update constructors to promote `weighted_df` history | constructor files | surveywts PR 3 |
| Add + export `survey_weighting_history()` | new file or existing utils | surveywts PR 3 |
| Resolve GAPs 1–4 | — | surveywts PR 3 |
