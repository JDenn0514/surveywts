# Spec Review: wt-name

## Pass 1 (2026-03-19)

### New Issues

#### Section: III. Behavior Rules

**Issue 1: `weights = NULL` + custom `wt_name` leaks phantom uniform column**
Severity: BLOCKING
Violates engineering-preferences.md SS4 (handle more edge cases, not fewer)

The spec's behavior table (Section III, Rule 2) shows the `weights = NULL` case
only with the default `wt_name = "wts"`. In the current implementation flow:

1. `.get_weight_col_name(data, weights_quo)` returns `"wts"` (new default) when
   `weights = NULL` on a plain `data.frame`
2. Uniform weights are created: `data_df[["wts"]] <- rep(1/n, n)`
3. Section V says to change the output assignment: `out_df[[wt_name]] <- new_weights`

When `wt_name = "cal_wt"` but `weights = NULL`, step 2 creates `data_df[["wts"]]`
and step 3 writes `out_df[["cal_wt"]]`. The output `weighted_df` now contains
**both** `"wts"` (phantom uniform weights from step 2) and `"cal_wt"` (calibrated).
The user never asked for a `"wts"` column; it's an internal implementation leak.

The spec must specify how the uniform weight creation step interacts with `wt_name`
when they differ. The behavior table needs an explicit row for this case.

Options:
- **[A]** When `weights = NULL` on plain `data.frame`, create uniform weights in
  `data_df[[wt_name]]` directly (not in `data_df[[weight_col]]`). Then
  `weight_col` is reassigned to `wt_name` for the internal read/validate flow.
  No phantom column. -- Effort: low, Risk: low, Impact: fixes the leak cleanly,
  Maintenance: none
- **[B]** After calibration, remove the phantom column if it differs from
  `wt_name`. -- Effort: low, Risk: medium (fragile; what if the user's data
  happened to already have a `"wts"` column?), Impact: fixes the leak,
  Maintenance: edge case maintenance
- **[C] Do nothing** -- Phantom column leaks into output for custom `wt_name`
  with `weights = NULL`

**Recommendation: [A]** -- Simplest and most correct. The uniform weights are an
internal detail; they should be created in the column that will hold the output.

---

**Issue 2: Behavior table missing row for `weights = NULL` + custom `wt_name`**
Severity: REQUIRED
Violates engineering-preferences.md SS4 (handle more edge cases, not fewer)

The behavior table in Section III, Rule 2 has 6 rows, but none covers:

| Input type | `weights` | `wt_name` | Input col | Output cols |
|-----------|-----------|-----------|-----------|-------------|
| Plain `data.frame` | `NULL` | `"cal_wt"` (custom) | *(none)* | `"cal_wt"` (calibrated) |

This row would make the expected behavior explicit and surface Issue 1.

Options:
- **[A]** Add the row to the table. -- Effort: trivial, Risk: none, Impact:
  makes the spec unambiguous, Maintenance: none
- **[B] Do nothing** -- Implementer guesses behavior for this case

**Recommendation: [A]**

---

#### Section: VI. Weighting History

**Issue 3: Spec claims `weight_col` field "already present" in history -- it does not exist**
Severity: REQUIRED
Factual error in the spec

Section VI states: "The `weight_col` field in history entries (already present)
should use `wt_name` rather than the input weight column name when they differ."

The current `.make_history_entry()` (utils.R:476-498) has these fields:
`step`, `operation`, `timestamp`, `call`, `parameters`, `weight_stats`,
`convergence`, `package_version`. There is **no `weight_col` field**.

The spec must either:
1. Acknowledge that a new field needs to be added to `.make_history_entry()`
2. Specify the field name, type, and position in the history entry

Additionally, Section V (Implementation Changes) lists changes for utils.R but
only mentions `.validate_wt_name()` and `.get_weight_col_name()` -- it does not
mention updating `.make_history_entry()`.

Options:
- **[A]** Add a `weight_col` parameter to `.make_history_entry()` and include it
  in the returned list. Update Section V to list this change under `R/utils.R`.
  All four functions pass `wt_name` as `weight_col` for data.frame inputs, and
  the survey object path passes `design@variables$weights`. -- Effort: low,
  Risk: low, Impact: history accurately records which column holds weights,
  Maintenance: none
- **[B]** Remove Section VI entirely. History doesn't need to record the column
  name since it's always recoverable from the `weighted_df` attribute or survey
  object. -- Effort: trivial, Risk: low (less metadata), Impact: simpler,
  Maintenance: none
- **[C] Do nothing** -- Spec contains a factual error; implementer has to guess

**Recommendation: [A]** -- The metadata is valuable for multi-step workflows
where the weight column name changes between steps.

---

#### Section: VII. Testing

**Issue 4: Test plan missing `NA_character_` validation test**
Severity: REQUIRED
Violates testing-standards.md SS2 (every error class gets a test)

The validation in Section IV catches both `NA_character_` and `""` with
`surveywts_error_wt_name_empty`. Test 6 only shows `wt_name = ""`. A separate
test (or additional expectation) for `wt_name = NA_character_` is needed to
verify the `is.na()` branch of the check.

Options:
- **[A]** Add `expect_error(calibrate(df, ..., wt_name = NA_character_), class = "surveywts_error_wt_name_empty")` to the existing test block or as a separate
  block. -- Effort: trivial, Risk: none, Impact: covers both branches,
  Maintenance: none
- **[B] Do nothing** -- One branch of `surveywts_error_wt_name_empty` is untested

**Recommendation: [A]**

---

**Issue 5: Test plan missing `weighted_df` input scenarios**
Severity: REQUIRED
Violates testing-standards.md SS2 (one block per supported input class)

The behavior table (Section III) has two rows for `weighted_df` input (rows 4-5),
but the test plan in Section VII has no explicit `weighted_df` input tests.
Tests 1-4 all use plain `data.frame` (`df`). The testing standards require
"one block per supported input class when the function accepts multiple."

Missing test scenarios:
- `weighted_df` input + default `wt_name` (verifies old weight column preserved
  and `"wts"` column created)
- `weighted_df` input + `wt_name` matching existing `weight_col` (verifies
  overwrite)

Options:
- **[A]** Add two `weighted_df` input test blocks per function. -- Effort: low,
  Risk: none, Impact: covers the full input class matrix, Maintenance: none
- **[B] Do nothing** -- `weighted_df` input path untested for `wt_name` behavior

**Recommendation: [A]**

---

**Issue 6: No test for weighting history recording `wt_name`**
Severity: REQUIRED
Violates testing-standards.md SS2 (weighting history correctly appended)

Section VI specifies that history entries should record the output weight column
name. The test plan (Section VII) has no test that verifies the `weight_col`
field in history entries equals `wt_name`. This is a testable behavioral contract
with no coverage.

Options:
- **[A]** Add a test block per function that checks
  `attr(result, "weighting_history")[[1]]$weight_col == wt_name`. -- Effort:
  low, Risk: none, Impact: verifies Section VI contract, Maintenance: none
- **[B] Do nothing** -- Section VI contract untested

**Recommendation: [A]**

---

#### Section: II. Argument Specification

**Issue 7: `adjust_nonresponse()` `wt_name` position violates argument order convention**
Severity: REQUIRED
Violates code-style.md SS4 (argument order: optional NSE before optional scalar)

The spec proposes:
```r
adjust_nonresponse(data, response_status, weights = NULL, wt_name = "wts",
                   by = NULL, method = ..., control = ...)
```

`by = NULL` is optional NSE (tidy-select for grouping columns). `wt_name = "wts"`
is optional scalar. Per code-style.md, optional NSE arguments (category 4) must
precede optional scalar arguments (category 5). The proposed signature puts
`wt_name` (scalar) before `by` (NSE).

The current code correctly orders `by` before `method`:
```r
adjust_nonresponse(data, response_status, weights = NULL, by = NULL,
                   method = ..., control = ...)
```

The correct position for `wt_name` in `adjust_nonresponse()` is after `by`:
```r
adjust_nonresponse(data, response_status, weights = NULL, by = NULL,
                   wt_name = "wts", method = ..., control = ...)
```

The other three functions have no optional NSE after `weights`, so their
proposed order is correct.

Options:
- **[A]** Move `wt_name` after `by` in `adjust_nonresponse()`. Update the
  Section II position rule to: "After the last optional NSE argument, before
  method/control arguments." -- Effort: trivial, Risk: none, Impact: maintains
  convention consistency, Maintenance: none
- **[B]** Keep `wt_name` after `weights` in all four functions for API
  consistency across the family, and document this as an intentional exception
  to argument order for `adjust_nonresponse()`. -- Effort: trivial, Risk: low,
  Impact: uniform position at the cost of a documented exception, Maintenance:
  must remember the exception
- **[C] Do nothing** -- Convention violation ships to users

**Recommendation: [A]** -- Convention exists for a reason; `adjust_nonresponse()`
is the only function affected and the position shift is minor.

---

#### Section: V. Implementation Changes

**Issue 8: `.get_weight_col_name()` default change may be unnecessary**
Severity: SUGGESTION

Section V item 2 says to update `.get_weight_col_name()` default from
`".weight"` to `"wts"`. Section III Rule 5 acknowledges this path "is now only
used for the internal weight extraction logic, not for naming the output."

If Issue 1 is resolved via Option A (uniform weights created in
`data_df[[wt_name]]` directly), the `.get_weight_col_name()` fallback for
plain `data.frame` + `weights = NULL` becomes unreachable for the output
naming path. The only reason to change it is cosmetic consistency.

This isn't wrong -- it's just unnecessary coupling. If a future change
modifies `wt_name`'s default, `.get_weight_col_name()` would also need
updating to stay "consistent," creating a maintenance trap.

Options:
- **[A]** Keep the default change for consistency. -- Effort: trivial, Risk: low,
  Impact: aesthetically consistent, Maintenance: coupled defaults
- **[B]** Don't change `.get_weight_col_name()`. Document that its fallback is
  only used for the internal weight extraction path and doesn't affect output
  naming. -- Effort: trivial, Risk: none, Impact: decoupled, Maintenance: none
- **[C]** Decide after resolving Issue 1. -- The right answer depends on how
  Issue 1 is resolved.

**Recommendation: [C]** -- Resolve Issue 1 first; the answer falls out naturally.

---

## Summary (Pass 1)

| Severity | Count |
|----------|-------|
| BLOCKING | 1 |
| REQUIRED | 5 |
| SUGGESTION | 1 |

**Total issues:** 7

**Overall assessment:** The spec is well-structured and covers the core behavior
correctly for the default case. The blocking issue is a real implementation gap:
when `weights = NULL` and `wt_name` differs from the internal default, a phantom
column leaks into the output. The required issues are mostly test plan gaps --
the testing section covers the happy path well but misses `weighted_df` input
scenarios, `NA_character_` validation, and history verification. The argument
order violation in `adjust_nonresponse()` is a straightforward fix. Once these
are resolved, the spec is ready for implementation.
