## Spec Review: calibration-api — Pass 1 (2026-06-03)

### New Issues

---

#### Section: II. Architecture — Private helpers

**Issue 1: `.parse_margins()` location contradicted by its usage in §III**
Severity: BLOCKING
Violates: Internal consistency; builder would need to make an architectural guess.

§II Private helpers table states:

> | `.parse_margins()` | `R/calibrate_rake.R` | `calibrate_rake()` only |

But §III (calibrate_greg() Arguments) states for the `targets` argument:

> "Format B is auto-converted to Format A via `.parse_margins()` before use."

And the edge cases table in §III repeats:

> "`targets` is a Format B long data frame | Auto-converted to Format A via `.parse_margins()` before all downstream processing"

These cannot both be true. If `.parse_margins()` is in `calibrate_rake.R` and used by `calibrate_rake()` only, then `calibrate_greg()` cannot call it without a cross-file dependency that violates the file-organization convention. If `calibrate_greg()` genuinely calls `.parse_margins()`, the helper must move to `R/utils.R` (shared) or a new `R/calibration-utils.R`.

Options:
- **[A]** Move `.parse_margins()` to `R/utils.R` and update §II to show "Used by: `calibrate_greg()`, `calibrate_rake()`" — Effort: low, Risk: low, Impact: both functions share Format B parsing; DRY-correct, Maintenance: low
- **[B]** Duplicate `.parse_margins()` logic in `calibrate_greg.R` as a new private function with a different name (e.g., `.parse_targets_to_format_a()`) — Effort: low, Risk: medium, Impact: divergence risk as formats evolve, Maintenance: high (two copies to keep in sync)
- **[C] Do nothing** — Builder makes an arbitrary architectural choice; the inconsistency ships.

**Recommendation: [A]** — Moving to `utils.R` is the only DRY-consistent solution and requires only updating one line in §II.

---

#### Section: III. `calibrate_greg()` — Arguments

**Issue 2: Unknown `control` keys — behavior not specified**
Severity: REQUIRED
Violates: engineering-preferences.md §4 ("Handle more edge cases, not fewer")

`calibrate_rake()` explicitly specifies that control keys for the wrong algorithm trigger `surveywts_warning_control_param_ignored` (one per parameter). `calibrate_greg()` accepts `control = list(maxit = 50, epsilon = 1e-7)`. The spec says keys are "merged with defaults; omitted keys retain defaults," but is silent on what happens when the user passes a key that is neither `maxit` nor `epsilon` (e.g., `control = list(maxit = 10, pval = 0.05)`).

Options:
- **[A]** Warn on unrecognized keys using `surveywts_warning_control_param_ignored` (same class as rake) — Effort: low, Risk: low, Impact: consistent behavior; builder can reuse warning class, Maintenance: low
- **[B]** Error on unrecognized keys — Effort: low, Risk: low but stricter than rake, Impact: asymmetric with rake's warn behavior, Maintenance: low
- **[C]** Silently ignore (document as such) — Effort: low, Risk: medium (user mistakes go undetected), Impact: inconsistent with rake, Maintenance: none

**Recommendation: [A]** — Same warning class as rake makes the warning reusable and the API consistent. Add one row to the Warnings table and one edge case row.

---

#### Section: III. `calibrate_greg()` — Errors / §IV. `calibrate_rake()` — Errors

**Issue 3: Same condition, different error class names in greg vs. rake**
Severity: REQUIRED
Violates: API coherence; a user writing error handling across functions would need two different `class =` checks for the same semantic failure.

`calibrate_greg()` uses `surveywts_error_population_variable_not_found` for "A `targets` name not found in `data`."
`calibrate_rake()` uses `surveywts_error_margins_variable_not_found` for "A `targets` variable name not found in `data`."

These are identical in semantics. The divergence stems from inheriting the old `calibrate()`/`rake()` namespaces ("population" vs "margins"). The new API harmonizes the argument name to `targets`, but the error classes remain split. A user catching errors from `calibrate()` dispatcher calls would need to handle both classes for the same conceptual failure.

Options:
- **[A]** Standardize on `surveywts_error_targets_variable_not_found` for both functions — Effort: medium (update error-messages.md, both function specs, test-specs, snapshot files), Risk: low (new name, no backward compat concern), Impact: consistent API, Maintenance: low
- **[B]** Keep `surveywts_error_population_variable_not_found` for greg and rename rake to the same — Effort: medium, Risk: low, Impact: reuses existing class, Maintenance: low
- **[C] Do nothing** — Document the divergence explicitly as intentional (carry-over from old classes). Adds a note to §VIII.

**Recommendation: [A]** — The new API is a deliberate redesign; this is the right moment to align the error namespace with the new `targets` argument name. Cost is low; asymmetry at runtime is a real user cost.

---

#### Section: V. `calibrate_poststrat()` — Errors / Edge cases

**Issue 4: Missing error for stratification column name not found in `data`**
Severity: REQUIRED
Violates: engineering-preferences.md §4; this is a predictable user error with no explicit handler.

`calibrate_poststrat()` derives stratification variable names from `names(targets)` (excluding `"target"`). If a column named in `targets` does not exist as a column in `data`, the spec has no explicit error for this case. The closest candidates in the error table are:

- `surveywts_error_population_cell_missing` — trigger says "A cell in `data` has no row in `targets`, or `targets` is missing a required column." This does not cleanly cover "a `targets` column name is absent from `data`."
- `surveywts_error_population_cell_not_in_data` — trigger is the reverse (a `targets` cell has no observations in `data`), which is semantically wrong for this case.

In practice a missing column would cause a join failure and could surface as a cryptic R error rather than a `cli_abort()` with a `class =` argument.

Compare: `calibrate_greg()` has `surveywts_error_population_variable_not_found` for exactly this condition.

Options:
- **[A]** Add a pre-join check: for each non-`"target"` column name in `targets`, verify it exists in `data`. Use a new error class `surveywts_error_population_variable_not_found` (same class as greg, since the condition is the same) or add the case to the trigger text of that class. Also add a corresponding test row to the test-spec error paths table — Effort: low, Risk: low, Impact: consistent with greg behavior, Maintenance: low
- **[B]** Add the case to `surveywts_error_population_cell_missing` trigger description — Effort: low, Risk: low, Impact: overloaded class name, Maintenance: medium
- **[C] Do nothing** — User gets a cryptic join error.

**Recommendation: [A]** — Reuse `surveywts_error_population_variable_not_found` across all three functions (pending resolution of Issue 3); add explicit validation before the join.

---

#### Section: VI. `calibrate()` — Thin Dispatcher

**Issue 5: NSE `weights` forwarding from dispatcher to dispatched function not specified**
Severity: REQUIRED
Violates: Contract completeness; builder implementing this naively produces broken NSE forwarding.

The `weights` argument in the dispatcher is a tidy-select bare name (NSE). When a user calls `calibrate(df, targets = pop, weights = my_col)`, the dispatcher receives `my_col` as an unevaluated expression. The dispatcher must forward this expression to `calibrate_greg()` (or whichever function is dispatched) in a way that preserves the unevaluated symbol, not just the string `"my_col"`.

The spec says the dispatcher "passes `data` and all `...` arguments through" and that all explicit params are "Passed as-is to the dispatched function." But "as-is" for an NSE argument is non-trivial: if the builder writes `calibrate_greg(data, targets = targets, weights = weights, ...)`, the inner `calibrate_greg()` receives the symbol `weights` (a variable name) rather than the user's original bare column reference. Whether this works depends on how the dispatched functions implement tidy-select capture.

The `create_replicate_weights()` pattern cited in the spec does not take an NSE `weights` argument, so it does not illustrate this forwarding.

Options:
- **[A]** Specify the forwarding mechanism explicitly in §VI: quote `weights` in the dispatcher via `rlang::enquo()` and inject into the dispatched call with `!!`. Add a note: "The `weights` argument must be forwarded with `!!rlang::enquo(weights)` to preserve the tidy-select expression." — Effort: low, Risk: low, Impact: builder has unambiguous instruction, Maintenance: none
- **[B]** Move `weights` into `...` in the dispatcher signature (remove it as an explicit param) so it flows through naturally — Effort: low, Risk: low (slightly less explicit signature), Impact: user must always name `weights = ` explicitly since positional matching is trickier with `...`, Maintenance: none
- **[C] Do nothing** — Builder discovers the forwarding pattern from existing code or documentation; risk of silent breakage if done incorrectly.

**Recommendation: [A]** — One sentence in §VI eliminates an implementation trap. The spec is the builder's only input.

---

#### Section: Test-spec — `calibrate_greg()`, `calibrate_rake()`, `calibrate_poststrat()`

**Issue 6: Test-spec missing `survey_taylor` happy-path tests for all three substantive functions**
Severity: REQUIRED
Violates: testing-standards.md §2 (conditional category 5 — input class dispatch tested per class)

The class support matrix in §I explicitly accepts `survey_taylor` input, preserving the class and updating only the weight column and history. But the happy-path test tables in the test-spec cover only `data.frame`, `weighted_df`, and `survey_nonprob`. No `survey_taylor` test block exists for any of the three substantive functions.

This is the only accepted input class with an active design structure (PSU, strata, FPC). If class preservation silently fails for `survey_taylor`, or if the weight update incorrectly modifies design structure, no test would catch it.

Options:
- **[A]** Add one happy-path row per function for `survey_taylor` input: construct a minimal `survey_taylor` from `make_surveywts_data()`, call the function, assert (a) returned class is `survey_taylor`, (b) `test_invariants()` passes, (c) weight column values changed, (d) `@variables$ids`/`@variables$strata` are unchanged — Effort: low, Risk: low, Impact: full class coverage, Maintenance: low
- **[B] Do nothing** — `survey_taylor` behavior goes untested.

**Recommendation: [A]** — Three rows added to the three happy-path tables; this is required to verify the class support contract.

---

#### Section: Test-spec — `calibrate_poststrat()`

**Issue 7: Test-spec missing `surveywts_error_reference_design_not_taylor` error path**
Severity: REQUIRED
Violates: testing-standards.md §2 (every row in the error table covered by a test)

`calibrate_poststrat()` includes `surveywts_error_reference_design_not_taylor` in its spec error table (trigger: `reference_design` is non-`NULL` and not `survey_taylor`). This error class does not appear in the test-spec error paths table for `calibrate_poststrat()`. The dual pattern (`expect_error(class =)` + `expect_snapshot(error = TRUE)`) is not specified for this trigger.

Options:
- **[A]** Add a row to the `calibrate_poststrat()` error paths table: "Trigger: `reference_design = list()`" with dual-pattern notation — Effort: negligible, Risk: none, Impact: complete error coverage, Maintenance: none
- **[B] Do nothing** — One error class ships untested.

**Recommendation: [A]**

---

**Issue 8: Test-spec missing `reference_design = non-NULL` happy-path for `calibrate_poststrat()`**
Severity: REQUIRED
Violates: testing-standards.md §2 (the `reference_design` parameter is covered in greg and rake happy paths but absent from poststrat)

The happy-path tables for `calibrate_greg()` and `calibrate_rake()` both include a scenario for `reference_design` non-`NULL` (asserting `targets_from_reference = TRUE` in history). `calibrate_poststrat()` has the same parameter and the same behavior but its happy-path table omits this scenario.

Options:
- **[A]** Add one row to the `calibrate_poststrat()` happy-path table mirroring the pattern from greg/rake — Effort: negligible, Risk: none, Impact: complete parameter coverage, Maintenance: none
- **[B] Do nothing** — Behavioral parity between functions goes untested for this parameter.

**Recommendation: [A]**

---

#### Section: V. `calibrate_poststrat()` — Edge cases

**Issue 9: Zero-strata-variables edge case uses semantically wrong error class**
Severity: SUGGESTION
Violates: API coherence (error class name should reflect the actual problem)

The edge case table specifies:

> "if `targets` has exactly one column named `"target"` and no strata columns, error with `surveywts_error_population_cell_missing`"

The class `surveywts_error_population_cell_missing` implies a cell in the data has no matching row in `targets`. The actual problem here is that no stratification variables were declared — a fundamentally different condition. A user seeing this error for a `targets = data.frame(target = 1.0)` call would be confused about which "cell" is "missing."

Options:
- **[A]** Define a new error class `surveywts_error_no_strata_variables` for this specific condition and add it to `plans/error-messages.md` — Effort: low, Risk: low, Impact: more informative error message, Maintenance: low
- **[B]** Use `surveywts_error_margins_format_invalid` (targets is structurally invalid because it has no stratification columns) — Effort: negligible (reuse existing class), Risk: low, Impact: semantically plausible, Maintenance: none
- **[C] Do nothing** — Keep `surveywts_error_population_cell_missing`; the edge case is rare and the error still stops the user.

**Recommendation: [B]** — `surveywts_error_margins_format_invalid` ("targets is not a valid data frame") is a better fit than "population cell missing." This is a SUGGESTION; [C] is acceptable if the effort of a new class seems excessive.

---

#### Section: VII. History Entry / III–V Returns

**Issue 10: `targets` format in history entry inconsistency not explicitly documented**
Severity: SUGGESTION
Violates: Implicit contract; a reader of history entries expects uniform structure.

The Returns sections specify:
- `calibrate_greg()` — `targets` stored as Format A named list
- `calibrate_rake()` — `targets` stored as Format A named list
- `calibrate_poststrat()` — `targets` stored as the input data frame

This is intentional (the formats are structurally different — marginals vs joint cells), but nothing in the spec states "this inconsistency is intentional." A future reader or implementer of a history-reading utility would be surprised to find that the `targets` field in the history entry has a different structure depending on the operation value.

Options:
- **[A]** Add one sentence to §VII noting: "The `targets` field in history parameters stores Format A named list for `calibrate_greg()` and `calibrate_rake()`, and a data frame for `calibrate_poststrat()`, because the formats are structurally incompatible" — Effort: negligible, Risk: none, Impact: prevents future confusion, Maintenance: none
- **[B] Do nothing** — The difference is inferrable from reading the Returns sections of each function.

**Recommendation: [A]** — One sentence; costs nothing.

---

#### Section: VI. `calibrate()` — Thin Dispatcher

**Issue 11: Default `method = "greg"` has no stated rationale**
Severity: SUGGESTION
Violates: Clarity (why is GREG the default rather than rake, which is more common in applied survey work?)

The spec defines `method = c("greg", "rake", "poststrat")` which makes `"greg"` the default via `rlang::arg_match()`. In applied survey practice, raking is more common than GREG for most weighting workflows. The choice of GREG as the default is defensible (it is the most general estimator; rake and poststrat are special cases) but the spec gives no rationale. A developer maintaining this API in the future cannot distinguish "intentional methodological choice" from "arbitrary first-in-list."

Options:
- **[A]** Add one sentence to §VI Design section: "GREG is the default because it is the most general linear calibration estimator; rake and poststrat are restricted special cases." — Effort: negligible, Risk: none
- **[B] Change default to `"rake"`** — Effort: negligible, Impact: matches applied survey practice, Risk: medium (a different choice could change what users get if they forget to specify)
- **[C] Do nothing** — The rationale stays implicit.

**Recommendation: [A]** — Document the intent; the current default is defensible.

---

## Summary (Pass 1)

| Severity | Count |
|---|---|
| BLOCKING | 1 |
| REQUIRED | 7 |
| SUGGESTION | 3 |

**Total issues:** 11

**Overall assessment:** The spec has one blocking architectural contradiction (`.parse_margins()` is claimed to live in `calibrate_rake.R` and be used by `calibrate_rake()` only, while §III requires `calibrate_greg()` to call it) that must be resolved before the builder can determine the correct file layout. Seven required issues address missing test coverage for `survey_taylor` input class (across all three functions), two gaps in the `calibrate_poststrat()` test-spec, an unhandled edge case, an API inconsistency in error class naming, an unspecified behavior for unknown control keys, and an NSE forwarding ambiguity in the dispatcher. The three suggestions are low-stakes improvements. Resolve Issue 1 and the seven REQUIRED issues before opening to the builder.

---

## Pass 2 — Verification (2026-06-03)

All 11 findings from Pass 1 verified as resolved in `plans/spec-calibration-api.md` and `plans/test-spec-calibration-api.md`:

| Issue | Finding | Resolution |
|-------|---------|------------|
| 1 (BLOCKING) | `.parse_margins()` location contradicted | Moved to `R/calibrate-utils.R`; §II table updated to show "Used by: `calibrate_greg()`, `calibrate_rake()`" |
| 2 (REQUIRED) | `calibrate_greg()` unknown `control` keys unspecified | Warn per unrecognized key with `surveywts_warning_control_param_ignored`; added to §III Warnings table and edge cases |
| 3 (REQUIRED) | Error class name divergence (greg vs rake) | Standardized to `surveywts_error_targets_variable_not_found` across all three functions |
| 4 (REQUIRED) | Missing `calibrate_poststrat()` error for column not found in `data` | Pre-join check added; uses `surveywts_error_targets_variable_not_found` (same class as greg/rake) |
| 5 (REQUIRED) | NSE `weights` forwarding unspecified in dispatcher | `rlang::enquo()` / `!!` pattern explicitly specified in §VI |
| 6 (REQUIRED) | No `survey_taylor` happy-path tests for any function | Added to all three function happy-path tables in test-spec |
| 7 (REQUIRED) | Missing `surveywts_error_reference_design_not_taylor` test for `calibrate_poststrat()` | Added to poststrat error paths table |
| 8 (REQUIRED) | Missing `reference_design` non-`NULL` happy-path for `calibrate_poststrat()` | Added to poststrat happy-path table |
| 9 (SUGGESTION) | Zero-strata edge case uses semantically wrong error class | New class `surveywts_error_no_strata_variables` defined; added to spec and test-spec |
| 10 (SUGGESTION) | History `targets` format inconsistency undocumented | One-sentence note added to §VII explaining structural incompatibility |
| 11 (SUGGESTION) | `method = "greg"` default has no rationale | Rationale documented in §VI Design section |

**Verdict: PASS** — No open findings. Spec is ready for implementation.
