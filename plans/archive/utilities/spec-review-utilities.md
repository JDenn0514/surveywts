## Spec Review: utilities — Pass 1 (2026-05-18)

### New Issues

#### Section: II. Architecture / Shared Helpers

**Issue 1: `.get_weight_vec()` does not handle `survey_replicate`**
Severity: BLOCKING
Violates contract completeness (Lens 3) and engineering-preferences.md §1 (DRY).

`trim_weights()` Behavior Rule step 3 says "Extract main weight vector via
`.get_weight_vec()`." But `.get_weight_vec()` has no `survey_replicate` branch.
For a replicate design with `weights = NULL` (auto-detect case), the function
falls through to the plain-`data.frame` fallback and returns
`rep(1/nrow(data@data), nrow(data@data))` — uniform weights — instead of
`data@data[[data@variables$weights]]`. An implementer following the spec would
produce silently wrong behavior for all replicate input.

Options:
- **[A] Extend `.get_weight_vec()` to add a `survey_replicate` branch** and say so in
  the spec ("…extend `.get_weight_vec()` to handle `survey_replicate` using
  `x@variables$weights`"). Effort: low, Risk: low, Impact: correct main-weight
  extraction for all classes, Maintenance: none beyond one extra branch.
- **[B] Document an inline extraction in `trim_weights()`** for the replicate case only
  (bypass `.get_weight_vec()` in the step 3 narrative). Effort: low, Risk: low,
  Impact: narrowly correct, Maintenance: diverges from the DRY pattern.
- **[C] Do nothing** — implementer guesses; likely produces uniform weights for replicate
  designs.

**Recommendation: A** — extend `.get_weight_vec()` and document the addition in the spec.
Consistent with every other class already handled there.

---

**Issue 2: Output construction for `survey_replicate` is unspecified**
Severity: BLOCKING
Violates contract completeness (Lens 3).

Step 9 of `trim_weights()` Behavior Rules says "Construct and return the output
object via `.make_weighted_df()` or `.update_survey_weights()` (existing helpers)."
For `survey_replicate`, `.update_survey_weights()` updates `design@data[[weight_col]]`
and appends history — but it has no mechanism to write back the trimmed replicate
weight matrix `rwnew` computed in step 7. There is no helper that does both. An
implementer following step 9 literally would return a `survey_replicate` with trimmed
main weights but untouched replicate weight columns.

Options:
- **[A] Specify a third output-construction path for `survey_replicate` in step 9** —
  after calling `.update_survey_weights()` for the main weights + history, additionally
  set `design@data[design@variables$repweights] <- as.data.frame(rwnew)`. Effort: low,
  Risk: low, Impact: complete replicate output, Maintenance: none.
- **[B] Extend `.update_survey_weights()` to accept an optional `rep_weights_matrix`
  argument** and update replicate columns when present. Effort: medium, Risk: low,
  Impact: cleaner API, Maintenance: slightly broader contract on the helper.
- **[C] Do nothing** — implementer guesses; likely omits replicate weight updates.

**Recommendation: A** — inline spec guidance is the right scope for this phase.
Extending `.update_survey_weights()` can be done if a second call site arises (Propensity
phase), but that's not needed yet.

---

#### Section: III. `trim_weights()` — Behavior Rules

**Issue 3: Uniform weight default (`rep(1)` vs `rep(1/n)`) contradicts `.get_weight_vec()`**
Severity: BLOCKING
Violates contract completeness (Lens 3).

Behavior Rule step 3 says: "For plain `data.frame` with `weights = NULL`, use
`rep(1, nrow(data))` as uniform starting weights." But `.get_weight_vec()` returns
`rep(1 / nrow(data_df), nrow(data_df))` — fractional calibration-starting weights
appropriate for raking, not for trimming or stabilization. The two values produce
different numerical results. For example, with `stabilize_weights()` on a 500-row
data frame: `rep(1, 500)` → `sum = 500 = n`, already stable (no-op);
`rep(1/500, 500)` → `sum = 1`, stabilizes by factor of 500, producing weights all
equal to 1. For `trim_weights()` the default upper cutoff differs:
`median(1) + 5*IQR(1) = 1` vs `median(1/n) + 5*IQR(1/n) = 1/n`.

Options:
- **[A] Keep `rep(1, nrow(data))` as the correct default; do NOT use `.get_weight_vec()`
  for the `data.frame` + `weights = NULL` case** — inline the `rep(1, nrow(data))`
  logic in both functions and say so in the spec. Effort: low, Risk: low, Impact:
  consistent with the stated spec intent, Maintenance: none.
- **[B] Change `.get_weight_vec()` to return `rep(1, nrow(data_df))` for the
  plain-data.frame fallback** — this also affects calibration functions (breaking
  change if they rely on the existing `1/n` value). Effort: medium, Risk: medium.
- **[C] Use `.get_weight_vec()` as-is and update the spec** to say `rep(1/n, n)`.
  Effort: low, Risk: low, Impact: spec matches code, but forces stabilize to scale
  by `n^2` for uniform input (arguably surprising).

**Recommendation: A** — the uniform-weight case for trimming and stabilization is
conceptually "all weights = 1" (each observation counts once). Do not reuse the
calibration-phase convention. State explicitly in both functions' behavior rules that
for `data.frame` + `weights = NULL`, `rep(1, nrow(data))` is used inline without
calling `.get_weight_vec()`.

---

**Issue 4: Replicate weight column extraction syntax missing from step 7**
Severity: REQUIRED
Violates contract completeness (Lens 3).

Step 7 opens with "Clip the full replicate matrix: `rwnew <- pmax(lower_abs, pmin(rep_weights, upper_abs))`" but never defines `rep_weights`. Based on how `.to_svyrep_design()` accesses replicate columns, the correct extraction is:
```r
rep_weights <- as.matrix(design@data[design@variables$repweights])
```
An implementer reading only the spec has no way to reconstruct this without reading
the internals.

Options:
- **[A] Add the extraction line to step 7a** before the clip equation. Effort: low,
  Risk: low, Impact: unambiguous extraction.
- **[B] Add a cross-reference to `.to_svyrep_design()`** ("replicate columns are in
  `design@data[design@variables$repweights]`"). Effort: low, Risk: low.
- **[C] Do nothing** — implementer searches the codebase.

**Recommendation: A** — one line eliminates all ambiguity.

---

**Issue 5: `strict = TRUE` behavior on replicate columns not stated**
Severity: REQUIRED
Violates contract completeness (Lens 3).

Step 7 says replicate columns are trimmed with "a single-pass column-wise
clip-and-redistribute (no strict loop)" and "mirrors `survey::trimWeights.svyrep.design`."
But the spec never explicitly states that `strict = TRUE` is silently ignored for
replicate weight columns. A reader could wonder: "if `strict = TRUE`, does the loop
apply to replicates?" The answer is no, but it must be stated.

Options:
- **[A] Add one sentence to step 7** (before 7a): "Regardless of `strict`, replicate
  weight columns always receive a single-pass clip-and-redistribute; the strict loop is
  applied only to main weights." Effort: trivial, Risk: none.
- **[B] Do nothing** — the phrase "no strict loop" implies it, but ambiguity remains.

**Recommendation: A** — one sentence, zero implementation cost, eliminates all doubt.

---

#### Section: III. `trim_weights()` — Error Table / Input Validation

**Issue 6: `.check_input_class()` reuse eligibility unresolved for both functions**
Severity: REQUIRED
Violates contract completeness (Lens 3).

`trim_weights()` accepts `survey_replicate`; `stabilize_weights()` rejects it. The
existing `.check_input_class()` helper throws `surveywts_error_replicate_not_supported`
for replicate input (distinct from `surveywts_error_unsupported_class`). Neither
function's behavior rules say whether `.check_input_class()` is used or bypassed:

- `trim_weights()` cannot use `.check_input_class()` as-is (it would error on replicate).
- `stabilize_weights()` spec says `surveywts_error_unsupported_class` for replicate input,
  but `.check_input_class()` would throw `surveywts_error_replicate_not_supported`.
  Additionally, `error-messages.md` lists `surveywts_error_replicate_not_supported` for
  "all calibration / NR functions" — making it unclear whether utilities functions are
  "NR functions."

Without spec guidance, the implementer must guess the class validation path.

Options:
- **[A] For `trim_weights()`: write a custom class check** (inline or new helper) that
  accepts `survey_replicate`. For `stabilize_weights()`: clarify the error class for
  replicate input — either use `surveywts_error_replicate_not_supported` (consistent with
  error-messages.md and `.check_input_class()`) or `surveywts_error_unsupported_class`
  (treating replicate like any other unsupported class). State in both behavior-rules
  sections whether `.check_input_class()` is called. Effort: low, Risk: low.
- **[B] Update `.check_input_class()` to accept an optional `allow_replicate = FALSE`
  parameter** and use it for `trim_weights()`. Effort: medium, Risk: medium (touches
  existing code), Maintenance: broader helper contract.
- **[C] Do nothing** — implementer inconsistency likely.

**Recommendation: A** — the cleanest resolution is to specify the error class explicitly
for `stabilize_weights()` (recommend `surveywts_error_replicate_not_supported` to stay
consistent with the established convention and `.check_input_class()`) and to state that
`trim_weights()` uses a new custom class validator that accepts all five input types.

---

**Issue 7: `wt_name` validation timing absent from behavior rules**
Severity: REQUIRED
Violates contract completeness (Lens 3) — the ordered behavior rules are incomplete.

Both functions' behavior rules list the substantive steps (validate type, extract
weights, resolve bounds, etc.) but never mention when `wt_name` is validated. The
spec's error table lists `surveywts_error_wt_name_not_scalar` / `surveywts_error_wt_name_empty`
(reuse existing `.validate_wt_name()`), but without a placement in the ordered steps,
the implementer must guess whether validation happens before or after weight extraction.
Convention (fail fast) says it should be the first step, before any weight work.
Additionally, the behavior rules should note that `wt_name` validation is skipped
(or irrelevant) when `data` is not a plain `data.frame` with `weights = NULL`, since
the argument is ignored in all other cases.

Options:
- **[A] Add a `wt_name` validation step as step 0** in both functions' behavior rules:
  "If `data` is a plain `data.frame` and `weights` is `NULL`, call
  `.validate_wt_name(wt_name)` before any other validation." Effort: trivial, Risk: none.
- **[B] Add a note to the argument table** that `wt_name` is validated early. Less
  precise than step-level guidance.
- **[C] Do nothing** — implementer guesses; likely validates correctly but spec is incomplete.

**Recommendation: A** — placement matters for error ordering tests. Add a step.

---

#### Section: IV. `stabilize_weights()` — Behavior Rules

**Issue 8: `tidyselect::eval_select()` must target `data@data` for survey objects**
Severity: REQUIRED
Violates contract completeness (Lens 3).

Behavior Rule step 3 says: "Use `tidyselect::eval_select()` to resolve `by`." For
survey objects (`survey_taylor`, `survey_nonprob`), `data` is an S7 object, not a
data frame. Calling `tidyselect::eval_select(by_quo, data)` would not work (S7 objects
do not expose column names via `names()` in the expected way). The target must be the
extracted data frame: `tidyselect::eval_select(by_quo, data@data)`. The existing
precedent is `summarize_weights()`, which extracts `data_df` first and calls
`tidyselect::eval_select(by_quo, data_df)`. The spec should state this explicitly.

Options:
- **[A] Amend step 3** to say "…extract the data frame from survey objects via `@data`
  before calling `tidyselect::eval_select()`." Effort: trivial, Risk: none.
- **[B] Cross-reference `summarize_weights()`** as the pattern. Less prescriptive.
- **[C] Do nothing** — implementer may infer from existing code, or may call with the S7
  object and encounter a runtime error.

**Recommendation: A** — one sentence in step 3 removes all ambiguity.

---

#### Section: VI. Testing

**Issue 9: Missing test for `surveywts_warning_trimming_failed`**
Severity: REQUIRED
Violates testing-standards.md — every warning class requires a test.

Test plan §4 "Warning paths" lists one case:
- All main weights already within bounds → `surveywts_warning_no_weights_trimmed`

`surveywts_warning_trimming_failed` appears in the warning table and the
`.trim_weights_internal()` spec, but has no test case in §4. The trigger is: all units
are outside `[lower_abs, upper_abs]` so `!any(can_adjust)` is `TRUE`. This is reachable
on the first pass when every weight is outside the bounds (e.g., two weights, bounds set
between them), or during `strict = TRUE` multi-pass iteration.

Options:
- **[A] Add a test case to §4**: "All main weights are outside `[lower_abs, upper_abs]`
  on the first pass → `surveywts_warning_trimming_failed`." Describe a minimal trigger
  data set (e.g., two units with weights 1 and 10, bounds `lower = 3, upper = 7`) and
  verify the warning fires and the weight sum changes by the amount of unredistributed
  excess. Effort: low, Risk: none.
- **[B] Do nothing** — the warning goes untested; coverage below 98%.

**Recommendation: A** — one `test_that()` block; this is the most impactful uncovered
path in the spec.

---

#### Section: V. `.trim_weights_internal()` — Attribution

**Issue 10: Attribution language "Vendored from" is inaccurate**
Severity: SUGGESTION
Minor accuracy concern.

The spec's attribution comment says "Vendored from `survey::do_trimWeights`" but the
implementation in §V is materially different: it adds a `has_trimmed` tracking argument
and returns a named list instead of a plain vector. `survey::do_trimWeights` takes
`(weights, lower, upper)` and modifies in place. The vendored claim overstates
similarity — "Adapted from" or "Clip-and-redistribute logic adapted from" would be
more accurate and less likely to confuse someone who reads both sources.

Options:
- **[A] Change "Vendored from" to "Clip-and-redistribute logic adapted from"** in the
  attribution comment block. Effort: trivial, Risk: none.
- **[B] Keep "Vendored from"** — the core clip/redistribute equation is identical; the
  additions are wrappers.
- **[C] Do nothing.**

**Recommendation: A** — accurate attribution is cheap and important for GPL compliance.

---

**Issue 11: `trim_weights(upper = Inf)` triggers `surveywts_warning_no_weights_trimmed`**
Severity: SUGGESTION
Behavior rule 10 says the function is a no-op "on weight values" but "still appends a
history entry." This is correct. However, since behavior rule 6b checks `if (!any(outside_initial))` before the trimming loop, and `upper = Inf` means no weight ever exceeds `upper_abs`, the function would ALSO emit `surveywts_warning_no_weights_trimmed`. Rule 10 doesn't mention this. A user who calls `trim_weights(df, upper = Inf)` to intentionally create an audit-trail no-op would receive an unexpected warning.

Options:
- **[A] Add to rule 10**: "The `surveywts_warning_no_weights_trimmed` warning fires when
  `upper = Inf` (or when the resolved bounds are wider than the weight distribution)."
  Effort: trivial.
- **[B] Suppress the warning when `upper = Inf`** by adding a special-case check.
  Effort: low. Deviation from `survey::trimWeights` behavior.
- **[C] Do nothing** — the warning behavior is technically correct but may surprise users.

**Recommendation: A** — document rather than suppress. Users can interpret the warning
correctly if the docs are clear.

---

## Summary (Pass 1)

| Severity | Count |
|---|---|
| BLOCKING | 3 |
| REQUIRED | 6 |
| SUGGESTION | 2 |

**Total issues:** 11

**Overall assessment:** The spec is nearly implementable for `stabilize_weights()` but
has three blocking gaps in the `survey_replicate` path of `trim_weights()` — no guidance
on helper extension, output construction for replicate columns, or uniform-weight
semantics. Resolving Issues 1–3 and 6 is prerequisite for writing any replicate-path
code. The remaining required issues (4, 5, 7, 8, 9) are one-sentence spec additions.

---

## Spec Review: utilities — Pass 2 (2026-05-18)

### Prior Issues (Pass 1)

| # | Title | Status |
|---|---|---|
| 1 | `.get_weight_vec()` does not handle `survey_replicate` | ✅ Resolved |
| 2 | Output construction for `survey_replicate` is unspecified | ✅ Resolved |
| 3 | Uniform weight default (`rep(1)` vs `rep(1/n)`) contradicts `.get_weight_vec()` | ✅ Resolved |
| 4 | Replicate weight column extraction syntax missing from step 7 | ✅ Resolved |
| 5 | `strict = TRUE` behavior on replicate columns not stated | ✅ Resolved |
| 6 | `.check_input_class()` reuse eligibility unresolved for both functions | ✅ Resolved |
| 7 | `wt_name` validation timing absent from behavior rules | ✅ Resolved |
| 8 | `tidyselect::eval_select()` must target `data@data` for survey objects | ✅ Resolved |
| 9 | Missing test for `surveywts_warning_trimming_failed` | ✅ Resolved |
| 10 | Attribution language "Vendored from" is inaccurate | ✅ Resolved |
| 11 | `trim_weights(upper = Inf)` triggers `surveywts_warning_no_weights_trimmed` undocumented | ✅ Resolved |

All Pass 1 issues are resolved. The spec was substantially updated.

### New Issues

#### Section: III. `trim_weights()` — Signature

**Issue 12: `trim_weights()` argument order violates `code-style.md` convention**
Severity: REQUIRED
Violates `code-style.md` §4 argument order (Category 4 before Category 5).

The current signature is:
```r
trim_weights(data, lower = NULL, upper = NULL, k = 5,
             type = ..., strict = FALSE, weights = NULL, wt_name = "wts")
```

`weights = NULL` is an optional NSE/tidy-select argument (Category 4). `lower`,
`upper`, `k`, `type`, `strict`, and `wt_name` are optional scalar control arguments
(Category 5). `code-style.md` §4 specifies the ordering: `x`/`data` → required NSE →
required scalar → **optional NSE** → **optional scalar** → `...`. The current spec
reverses Categories 4 and 5, placing all optional scalars before the optional NSE
argument `weights`. Every other surveywts function with both `weights` and scalar options
(`calibrate()`, `rake()`, `poststratify()`, `adjust_nonresponse()`) follows the correct
ordering: `weights = NULL` precedes the option scalars.

The correct signature is:
```r
trim_weights(data, weights = NULL, lower = NULL, upper = NULL,
             k = 5, type = ..., strict = FALSE, wt_name = "wts")
```

Note: `wt_name` (scalar, Category 5) is already in the correct relative position
after the category-5 args once `weights` is moved.

Options:
- **[A] Reorder the signature** to put `weights = NULL` immediately after `data`, before
  `lower`. Update the argument table to match. Effort: trivial, Risk: none, Impact:
  consistent with every other surveywts function, Maintenance: none.
- **[B] Keep current order** and add a note to the conventions doc calling this an
  intentional exception. Effort: low, Risk: API inconsistency persists.
- **[C] Do nothing** — implementer writes the wrong signature; future maintainers have to
  explain why `trim_weights` differs from `calibrate`, `rake`, and all other functions.

**Recommendation: A** — one-line change, zero debate. Convention exists for consistency.

---

#### Section: IV. `stabilize_weights()` — Signature

**Issue 13: `stabilize_weights()` — `by` precedes `weights` within optional NSE arguments**
Severity: SUGGESTION
Minor inconsistency with established precedent in `surveywts-conventions.md`.

The current signature is:
```r
stabilize_weights(data, by = NULL, weights = NULL, wt_name = "wts")
```

Both `by` and `weights` are optional NSE/tidy-select (Category 4). `code-style.md` §4
does not specify relative ordering within Category 4. However, `summarize_weights()` —
the closest analogous function, also taking `weights` and `by` — uses:
```r
summarize_weights(x, weights = NULL, by = NULL)
```

Placing `by` before `weights` in `stabilize_weights()` creates a visible inconsistency
at the package level. A user who looks up one function's signature and then the other
will see the order swapped for no apparent reason.

Options:
- **[A] Swap to `(data, weights = NULL, by = NULL, wt_name = "wts")`** — matches
  `summarize_weights()`. Effort: trivial, Risk: none, Impact: consistent API.
- **[B] Keep current order** — `by` is arguably the more distinctive argument for this
  function. Effort: zero, Risk: visible inconsistency.
- **[C] Do nothing.**

**Recommendation: A** — consistency with `summarize_weights()` costs nothing.

---

#### Section: VI. Testing — `trim_weights()` error paths

**Issue 14: `k` error-path test missing the vector-numeric case**
Severity: SUGGESTION
Minor gap in error-path test coverage.

`surveywts_error_k_not_scalar` is defined as "k is not `numeric(1)` or is `NA`." The
test plan lists `k = "5"` (character) and `k = NA_real_` as triggers, but not
`k = c(1, 2)` (a length-2 numeric vector). A character input and an NA are sufficient
to exercise the `is.numeric(k) && length(k) == 1 && !is.na(k)` guard, but the
length-> 1 numeric branch is left uncovered by the test plan. The implementation might
test `is.numeric(k)` before `length(k) == 1` and accidentally pass `c(1, 2)` without
error if the guard is written incorrectly.

Options:
- **[A] Add `k = c(1, 2)` to the error-path test list** for `surveywts_error_k_not_scalar`.
  Effort: trivial.
- **[B] Do nothing** — `k = "5"` and `k = NA_real_` effectively exercise the guard;
  the vector case is low-risk.
- **[C] Do nothing.**

**Recommendation: A** — one line in the test plan, and it explicitly pins that length > 1
numeric is rejected (not just non-numeric and NA).

---

#### Section: VI. Testing — `stabilize_weights()` numerical correctness

**Issue 15: `survey_replicate` + `by` numerical test is underspecified**
Severity: SUGGESTION
Vague test assertion leaves implementer uncertain what to verify.

The numerical-correctness test for `stabilize_weights()` with `survey_replicate` and
`by` says only "verify group-level sums of each replicate column." It does not state the
expected formula. For the global case the spec gives a precise check:
`colSums(result_rep_weights) ≈ colSums(original_rep_weights) * (n / sum(w_main))`.
No analogous formula is provided for the `by` case.

The correct verification for each group `h` in each replicate column `j` is:
```
sum(result_rep[h, j]) ≈ sum(original_rep[h, j]) * (n_h / W_h)
```
where `W_h = sum(w_main[h])`. This is derivable from the behavior rules, but the
test plan should state it explicitly so the test can be written without reference to
the implementation.

Options:
- **[A] Replace "verify group-level sums of each replicate column"** with the explicit
  formula above. Effort: trivial.
- **[B] Keep as-is** — implementers can derive it from the behavior rules.
- **[C] Do nothing.**

**Recommendation: A** — aligns the `by` test with the specificity of the global test.

---

#### Section: VI. Testing — `trim_weights()` happy path

**Issue 16: No-op happy-path test does not explicitly verify `surveywts_warning_no_weights_trimmed`**
Severity: SUGGESTION
Minor test-assertion gap.

Test-category §1 item 8 reads: "Explicit no-op (`lower = -Inf`, `upper = Inf`,
`type = "absolute"`): no trimming; history entry still appended." Behavior Rule 10
states that `surveywts_warning_no_weights_trimmed` also fires in this case, and test
category §4 "Warning paths" covers the general no-trimming warning path. However, test
§1 item 8 does not say to verify the warning fires — a reader might write a happy-path
test for the no-op case that expects no warning and silently gets one.

The test categories are independent test blocks; §1 and §4 could be written by different
people without cross-referencing. The no-op happy-path block should note: "expect
`surveywts_warning_no_weights_trimmed` to fire."

Options:
- **[A] Add a parenthetical to §1 item 8**: "…history entry still appended (expect
  `surveywts_warning_no_weights_trimmed`)." Effort: trivial.
- **[B] Do nothing** — the warning is covered in §4; an implementer reading both
  categories will catch it.
- **[C] Do nothing.**

**Recommendation: A** — removes any chance of the no-op test failing with an unexpected
warning at CI time.

---

## Summary (Pass 2)

| Severity | Count |
|---|---|
| BLOCKING | 0 |
| REQUIRED | 1 |
| SUGGESTION | 4 |

**Total new issues:** 5

**Overall assessment:** The spec is implementable. All Pass 1 blockers and required
issues are resolved. The one remaining required issue (Issue 12: `trim_weights()`
argument order) is a one-line signature correction to match the package-wide convention.
The four suggestions are minor spec-text additions that add precision to the test plan.
This spec can proceed to Stage 4 resolution.
