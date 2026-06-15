## Plan Review: propensity — Pass 1 (2026-05-19)

### New Issues

#### Section: PR 1 — `ipw()` + Infrastructure

---

**Issue 1: Return value of `.fit_participation_propensity()` is contradicted by implementation notes**
Severity: BLOCKING

The code template in Task 1.8 ends with:
```r
drop(link(X_nps %*% gamma))
```
returning a plain numeric vector. But the PR 1 implementation notes directly contradict this:
> "Simplest: return a list `list(scores, converged, final_delta)` from the helper; `ipw()` extracts `$scores`."

The `if (iter == maxit)` branch in the code has only a comment and no tracking mechanism. Task 1.9 Behavior Rule 14 requires `ipw()` to check whether NR converged and emit `surveywts_warning_propensity_nr_no_convergence` if not — which is impossible if the helper returns a plain vector with no convergence information.

An implementer following the code template will produce code where:
- `ipw()` calls `.fit_participation_propensity()` and gets back a plain vector
- `ipw()` has no way to know whether NR converged
- `surveywts_warning_propensity_nr_no_convergence` can never be emitted
- The Category 4 warning test for `maxit = 1L` will fail

Options:
- **[A]** Remove the plain-vector return from the code template; replace with the list form `list(scores = drop(link(...)), converged = converged, final_delta = max(abs(delta)))` where `converged <- FALSE` is initialized before the loop and set `TRUE` on the `break`. — Effort: low, Risk: low, Impact: fixes the contradiction and enables convergence detection
- **[B]** Keep plain-vector return but have `ipw()` track convergence by having the helper accept a mutable environment or by counting iterations via a returned attribute. — Effort: medium, Risk: medium, Impact: more complex than necessary
- **[C] Do nothing** — Implementer must resolve the contradiction on their own; risk of implementing convergence tracking incorrectly or omitting it entirely.

**Recommendation: [A]** — The list return is already the documented recommendation; the code template just needs to be updated to match it.

---

**Issue 2: 98% coverage criterion absent from both PR acceptance criteria**
Severity: REQUIRED
Violates spec §VII Quality Gate ("Test coverage ≥ 98% overall") and testing-standards.md ("98%+ line coverage is the floor").

Neither PR 1 nor PR 2 acceptance criteria mention coverage. A developer checking off the PR checklist will not verify coverage before opening the PR.

Options:
- **[A]** Add "Test coverage ≥ 98% overall (verify with `covr::package_coverage()`)" to both PR 1 and PR 2 acceptance criteria. — Effort: low, Risk: low, Impact: ensures the spec quality gate is enforced at PR time
- **[B]** Add only to the Quality Gate Checklist at the bottom of the plan (already present there implicitly via spec §VII). — Effort: low, Risk: medium, Impact: requires implementer to check two separate sections
- **[C] Do nothing** — Risk of merging a PR that drops coverage below the 95% CI block threshold.

**Recommendation: [A]** — Per-PR criteria are the checklist the implementer uses; the global Quality Gate Checklist is reviewed at phase completion, not per-PR.

---

**Issue 3: `trim = TRUE` Category 1 test does not verify actual trimming occurs**
Severity: REQUIRED

Task 1.4 Category 1 says:
> "`trim = TRUE` → history has `trim = TRUE`; `n_trimmed >= 0`; `test_invariants()` passes"

`n_trimmed >= 0` is trivially satisfied even when zero weights are trimmed. The standard NPS test data from `make_surveywts_data()` is unlikely to produce extreme IPW weights (the covariate distributions would need to be severely misaligned for any weight to exceed `median(w) + 5 * IQR(w)`). If no weights are trimmed:
- `.trim_weights_internal()` returns early without executing the redistribution path
- The `has_trimmed` vector is all-FALSE
- `n_trimmed = 0L` — which satisfies `>= 0` vacuously
- The actual trimming and redistribution code in `.trim_weights_internal()` is never exercised via this test

The test should verify `n_trimmed > 0` to confirm trimming actually fired. A purpose-built NPS dataset with extreme covariate skew (e.g., all NPS units in one covariate stratum absent from the reference) is needed.

Options:
- **[A]** Add a dedicated `trim = TRUE` edge case in Category 5 using a small synthetic dataset where at least one weight is guaranteed to exceed the IQR bound (e.g., NPS with 5 units all in one demographic cell while the reference has 1000 units uniformly distributed). Assert `n_trimmed > 0` and `sum(result@data$ipw_weight) < estimated_population_size_from_history`. — Effort: low, Risk: low, Impact: exercises the trim path with a real assertion
- **[B]** Change the Category 1 `trim = TRUE` test to manufacture extreme IPW scores explicitly by constructing near-degenerate covariate distributions. — Effort: medium, Risk: medium, Impact: makes the happy-path test more brittle
- **[C] Do nothing** — The `.trim_weights_internal()` redistribution path is untested; a regression in it would not be caught.

**Recommendation: [A]** — Keep Category 1 simple; add a single targeted edge case in Category 5. Edge cases with specific value requirements belong inline in tests, per testing-standards.md.

---

#### Section: PR 2 — `adjust_nonresponse(method = "propensity")`

---

**Issue 4: Extreme-adjustment check respondent-only scope is ambiguous in Task 2.5 Step 11**
Severity: REQUIRED
Violates the implementation note's own specification: "evaluated only for respondents (where `status == 1`)".

Task 2.5 Step 11 says:
> `if (max(weight_vec / scores) / mean(weight_vec) > control$max_adjust)`

`weight_vec` in the existing `adjust_nonresponse()` code is extracted before the method branch and includes all units — both respondents and nonrespondents. Using the full `weight_vec` in `mean(weight_vec)` inflates the denominator compared to the respondent-only computation. This would make the check less sensitive (harder to trigger the warning), and the acceptance criterion — "`max(weight_i / score_i) / mean(weight_i)` (not `max(1/score) / mean(1/score)`)" — does not clarify which units `weight_i` ranges over.

Specifically: if there are 500 respondents and 200 nonrespondents, using `mean(weight_vec)` over all 700 gives a smaller denominator than using `mean(weight_vec[respondents])` over 500. The "Very low response rate (20%)" edge case in Category 5 expects `surveywts_warning_extreme_propensity_adjustment` to fire — if the wrong scope is used, the threshold may not be crossed and the test will fail.

Options:
- **[A]** Change Step 11 to use respondent-only weights explicitly: `resp_idx <- plain_df[[response_status_col]] == 1; resp_weights <- weight_vec[resp_idx]; resp_scores <- scores[resp_idx]; if (max(resp_weights / resp_scores) / mean(resp_weights) > control$max_adjust)`. Update acceptance criterion to state "respondents only". — Effort: low, Risk: low, Impact: matches implementation note intent and makes the acceptance criterion testable
- **[B]** Clarify in Step 11 that `weight_vec` in this context means "after subsetting to respondents" and add a local alias. — Effort: low, Risk: low, Impact: same result, less code change
- **[C] Do nothing** — Risk of wrong behavior at low response rates; the Category 5 "Very low response rate (20%)" test may fail.

**Recommendation: [A]** — Be explicit about the subset; this is a numerical check where scoping matters.

---

#### Section: PR 1 Suggestions

---

**Issue 5: `match.arg(method)` step absent from Behavior Rules; invalid method produces non-surveywts error**
Severity: SUGGESTION
Applies code-style.md ("class= on every cli_abort()") — invalid `method` values fall through to `stats::binomial(link = method)$linkinv` which throws a base R error without a `surveywts_error_*` class.

The 20 Behavior Rules in Task 1.9 do not include `method <- match.arg(method)`. An implementer who follows the rules literally will produce a function where `ipw(data, ~ x, ref, method = "logistic")` throws:
```
Error in stats::binomial("logistic") : 'link' argument 'logistic' not ...
```
rather than a classed surveywts error.

Options:
- **[A]** Add Behavior Rule 0 (before Rule 1): "Coerce `method` via `match.arg(method)` → produces standard R error on invalid values." Accept that this produces a base R error, not a `surveywts_error_*` class, since this is standard R practice. — Effort: low, Risk: low
- **[B]** Add explicit validation: `if (!method %in% c("logit", "probit", "cloglog")) cli::cli_abort(..., class = "surveywts_error_propensity_invalid_method")`. Add to error-messages.md and test categories. — Effort: low, Risk: low, Impact: full surveywts-class coverage for this path
- **[C] Do nothing** — Standard R `match.arg()` handles it via a base R error; this is acceptable practice in many packages.

**Recommendation: [A]** — Use `match.arg()`; the base R error is informative enough. Full classing (option B) is proportionate only if this pattern is consistently applied to other functions with enumerated arguments in this package. Check existing functions for precedent before choosing B.

---

**Issue 6: No `survey_taylor` reference design helper for NPS tests**
Severity: SUGGESTION

Every `ipw()` test block must construct a `survey_taylor` reference design. The existing `helper-test-data.R` has `make_taylor_design()` (line ~97) but it is built from `make_surveywts_data()` data — producing a complex stratified design with PSUs. For NPS propensity tests, a simple flat `survey_taylor(data = ref_df, weights = wt)` is more appropriate, and every test block will repeat this construction inline.

Options:
- **[A]** Add a `make_nps_reference(n = 1000, seed = seed)` helper to `helper-test-data.R` that generates a plain reference data frame (matching the covariate structure of `make_surveywts_data()`) and wraps it in `surveycore::survey_taylor(data = ref_df, weights = wt)`. — Effort: low, Risk: low, Impact: eliminates 4-6 lines of setup repetition across the ~12 happy-path test blocks
- **[B]** Construct the reference design inline in each test block. — Effort: zero now, Risk: low, Impact: more verbose tests but no helper maintenance burden
- **[C] Do nothing** — Each test constructs its own reference design.

**Recommendation: [A]** — The helper-test-data.R file already has this pattern (see line 117's `make_survey_replicate()`); adding an NPS reference helper is consistent and will reduce test repetition materially.

---

**Issue 7: `wt_name = NULL` edge case not tested**
Severity: SUGGESTION

The error paths test `wt_name = 1L` (not scalar), `wt_name = ""` (empty), and `wt_name = NA_character_` (empty). They do not test `wt_name = NULL`. Depending on `.validate_wt_name()` internals, `NULL` might throw `surveywts_error_wt_name_not_scalar` (correct) or might produce a different error. Since `NULL` is a distinct R value from `NA_character_`, it deserves explicit coverage.

Options:
- **[A]** Add `wt_name = NULL` to Category 3 error paths: assert `surveywts_error_wt_name_not_scalar`. — Effort: trivial, Risk: low
- **[B]** Skip — rely on `.validate_wt_name()` tests (if any exist) to cover the NULL case. — Effort: zero, Risk: low if the validator is independently tested

**Recommendation: [A]** — trivial to add; ensures the wt_name validation is complete from the caller's perspective.

---

## Summary (Pass 1)

| Severity | Count |
|---|---|
| BLOCKING | 1 |
| REQUIRED | 3 |
| SUGGESTION | 3 |

**Total issues:** 7

**Overall assessment:** The plan is structurally sound — PR sequencing is correct, TDD order is correct, all spec behaviors are covered. One blocking issue must be resolved before implementation: the `.fit_participation_propensity()` return contract contradicts itself between the code template and the implementation notes, making NR convergence detection unimplementable as written. Three required issues address missing acceptance criteria and two test gaps that would allow failures through undetected. Ready to implement after Stage 3 resolves the blocking and required issues.

---

## Plan Review: propensity — Pass 2 (2026-05-20)

### Prior Issues (Pass 1)

| # | Title | Status |
|---|---|---|
| 1 | Return value of `.fit_participation_propensity()` is contradicted by implementation notes | ✅ Resolved |
| 2 | 98% coverage criterion absent from both PR acceptance criteria | ✅ Resolved |
| 3 | `trim = TRUE` Category 1 test does not verify actual trimming occurs | ✅ Resolved |
| 4 | Extreme-adjustment check respondent-only scope is ambiguous in Task 2.5 Step 11 | ✅ Resolved |
| 5 | `match.arg(method)` step absent from Behavior Rules | ✅ Resolved |
| 6 | No `survey_taylor` reference design helper for NPS tests | ✅ Resolved |
| 7 | `wt_name = NULL` edge case not tested | ✅ Resolved |

### New Issues

#### Section: PR 1 — `ipw()` + Infrastructure

---

**Issue 8: `ipw()` `survey_nonprob` construction is unspecified — no analogous pattern exists in this codebase**
Severity: BLOCKING
Violates the plan's own implementation note: "Use the surveycore internal constructor pattern consistent with other functions in this package that return `survey_nonprob`."

Every other surveywts function that returns a `survey_nonprob` receives one as *input* and updates it in place via `.update_survey_weights()`. None of them construct a new `survey_nonprob` from a raw `data.frame`. `ipw()` is unique: its input is always a `data.frame`, so it must call the surveycore constructor directly — but the plan doesn't say which one, how to pass `reference_sample`, or how to attach the history entry.

The relevant surveycore constructor is `as_survey_nonprob(data, weights, reference_sample = NULL)`, where `weights` is NSE. Passing `wt_name` (a character scalar) directly will not work — `rlang::enquo(wt_name)` captures the symbol `wt_name`, not its value, so `as_name()` would return `"wt_name"` instead of `"ipw_weight"`. The correct call is:

```r
result <- surveycore::as_survey_nonprob(
  data             = out_df,
  weights          = !!rlang::sym(wt_name),
  reference_sample = reference
)
```

After construction, the history entry must be appended manually:

```r
meta <- result@metadata
meta@weighting_history <- c(meta@weighting_history, list(history_entry))
result@metadata <- meta
```

An implementer following the plan as written will spend significant time debugging an approach that works for none of the existing functions.

Options:
- **[A]** Replace the implementation note for Rule 20 with the explicit two-step pattern above: `as_survey_nonprob(data = out_df, weights = !!rlang::sym(wt_name), reference_sample = reference)` followed by manual history entry append. — Effort: low, Risk: low, Impact: eliminates guesswork; enables `r-implement` to execute mechanically
- **[B]** Use the raw S7 constructor: `surveycore::survey_nonprob(data = out_df, variables = list(weights = wt_name), reference_sample = reference)` followed by history append. — Effort: low, Risk: low, Impact: bypasses `as_survey_nonprob()` validation (already done by `ipw()`), but loses haven metadata extraction
- **[C] Do nothing** — Implementer must reverse-engineer the surveycore API; risk of incorrect NSE usage or missing `reference_sample` assignment.

**Recommendation: [A]** — `as_survey_nonprob()` is the documented user-facing constructor; NSE injection with `!!rlang::sym()` is standard in this codebase.

---

**Issue 9: Bespoke `ipw()` history entry must include `step` and `timestamp` — plan and spec both omit them**
Severity: REQUIRED

The `.format_history_step()` common footer (after the switch case) always reads `entry$step` and `entry$timestamp`:

```r
date_str <- format(ts, "%Y-%m-%d")
paste0("#   Step ", entry$step, " [", date_str, "]: ", label)
```

When `ipw()` constructs a bespoke history entry (not via `.make_history_entry()`), it must include these two fields. Neither the spec §III history entry field list nor the plan's Task 1.7 or Task 1.9 mention them. An implementer who follows the spec's field list literally will produce a history entry missing `step` and `timestamp`, causing `format(NULL, "%Y-%m-%d")` to return `character(0)` and `entry$step` to return `NULL` — both silently corrupting the print output rather than throwing an error.

The bespoke entry should include:

```r
history_entry <- list(
  step                      = length(.get_history(result)) + 1L,
  timestamp                 = Sys.time(),
  operation                 = "ipw",
  formula                   = selection,
  method                    = method,
  estimator                 = "ht",
  trim                      = trim,
  n_nps                     = nrow(data),
  n_reference               = nrow(reference@data),
  estimated_population_size = estimated_population_size,
  n_trimmed                 = n_trimmed,
  reference_design          = reference,
  targets_from_reference    = FALSE
)
```

Options:
- **[A]** Add `step` and `timestamp` to the history entry field list in Task 1.9 Rule 20's implementation note. Show the full bespoke entry construction as an explicit code block. — Effort: low, Risk: low, Impact: prevents silent print corruption
- **[B]** Add a comment in Task 1.7 that the `"ipw"` case entry must include `step` and `timestamp` at minimum. — Effort: trivial, Risk: low, Impact: less complete than A
- **[C] Do nothing** — Risk of corrupted print output that passes tests (since the snapshot test only runs after implementation generates a valid snapshot).

**Recommendation: [A]** — The full entry construction should be shown in one place alongside Rule 20, where the implementer is building the return value.

---

**Issue 10: `@reference_sample` property not verified in PR 1 acceptance criteria**
Severity: REQUIRED
Violates spec §III Output Contract, which lists `@reference_sample: reference` as a property of the returned `survey_nonprob`.

`survey_nonprob` has an S7 `reference_sample` property (confirmed in `surveycore/R/core-classes.R`, line 965: `reference_sample = S7::new_property(default = NULL)`). The spec §III Output Contract includes `@reference_sample: reference`. But no test in Category 1, 5, or 6 asserts `S7::S7_inherits(result@reference_sample, surveycore::survey_taylor)`. If the constructor call omits `reference_sample = reference`, the property silently defaults to `NULL` and no test catches it.

Options:
- **[A]** Add to Category 1 (happy path): `expect_true(S7::S7_inherits(result@reference_sample, surveycore::survey_taylor))`. — Effort: trivial, Risk: low, Impact: enforces the output contract; catches accidental omission of `reference_sample =` in the constructor call
- **[B]** Add to Category 6 (history correctness) as a structural check alongside the `reference_design` history entry check. — Effort: trivial, Risk: low, Impact: correct placement conceptually but grouped with history, not the object property
- **[C] Do nothing** — `@reference_sample` silently stays `NULL`; the Level B bootstrap would fail at runtime rather than at PR time.

**Recommendation: [A]** — Place in Category 1 where other output contract assertions live; keeps the object property check separate from the history entry check.

---

**Issue 11: Task 1.3b uses the wrong `survey_taylor()` constructor API**
Severity: REQUIRED
Violates the existing internal convention established by `make_replicate_design()` in `helper-test-data.R`.

Task 1.3b specifies:

```r
surveycore::survey_taylor(data = ref_df, weights = "base_weight")
```

The `survey_taylor()` S7 constructor does NOT accept a `weights` argument — its properties are `data`, `metadata`, `variables`, `groups`, and `call`. Passing `weights = "base_weight"` will either be silently ignored (if S7 ignores extra args) or throw `Error: unused argument (weights = "base_weight")`. The existing `make_replicate_design()` helper in `helper-test-data.R` uses the correct pattern:

```r
surveycore::survey_taylor(
  data      = df,
  variables = list(weights = "base_weight")
)
```

An implementer following Task 1.3b will produce a broken helper. When `test-nonprob-ipw.R` calls `make_nps_reference()`, the file will fail to load, causing all tests to error — not just fail — which makes the "confirm RED phase" step of Task 1.5 uninterpretable.

Options:
- **[A]** Fix Task 1.3b: change `weights = "base_weight"` to `variables = list(weights = "base_weight")`, consistent with `make_replicate_design()`. — Effort: trivial, Risk: low, Impact: prevents test file load failure
- **[B]** Use `surveycore::as_survey(ref_df, weights = base_weight)` (NSE) as the reference design constructor — matches the user-facing API shown in spec examples. — Effort: trivial, Risk: low, Impact: same outcome; slightly different constructor path
- **[C] Do nothing** — ALL ipw() tests fail to load; RED phase is uninterpretable.

**Recommendation: [A]** — `survey_taylor(variables = list(weights = ...))` is the exact pattern already used in this file; the fix is one word.

---

**Issue 12: `ipw()` roxygen `@examples` will fail `R CMD check` due to wrong `survey_taylor()` API**
Severity: REQUIRED
Violates acceptance criterion: "All exported function examples runnable."

Task 1.9 says `@examples` comes "from spec §III." The spec §III example includes:

```r
ref_design <- surveycore::survey_taylor(data = ref_df, weights = wt)
```

This is the same wrong API as Issue 11. When `devtools::check()` runs examples, this line will throw `Error: unused argument (weights = wt)` (or similar). The `R CMD check` criterion ("0 errors, 0 warnings") in the PR 1 acceptance criteria would be violated.

Options:
- **[A]** Fix the `@examples` specification in Task 1.9 to use `variables = list(weights = "wt")` for `survey_taylor()`. Or replace with `surveycore::as_survey(ref_df, weights = wt)` which accepts bare names via NSE and is the documented user-facing API. — Effort: trivial, Risk: low, Impact: `R CMD check` passes on examples
- **[B]** Add a note to Task 1.9 that the spec example must be adapted to use the correct constructor before inclusion in `@examples`. — Effort: trivial, Risk: low, Impact: delegates the fix to the implementer with explicit awareness
- **[C] Do nothing** — R CMD check fails on examples; PR 1 cannot pass its acceptance criteria.

**Recommendation: [A]** — Specify `surveycore::as_survey(ref_df, weights = wt)` as the correct pattern; it's the documented constructor and matches how `make_taylor_design()` works in this repo.

---

**Issue 13: Missing changelog entries in both PR file lists**
Severity: REQUIRED
Violates `github-strategy.md`: "Changelog entry format (required before every PR)."

The `changelog/` directory exists with entries for every prior phase (`calibration/`, `nonresponse/`, `replicate/`, `utilities/`). Neither PR 1 nor PR 2 file list includes a `changelog/propensity/` entry. An implementer following the plan will not create changelog entries before opening PRs.

Options:
- **[A]** Add `changelog/propensity/feature-ipw.md` to PR 1's file list and `changelog/propensity/feature-nonresponse-propensity.md` to PR 2's file list; add "Changelog entry committed" to each PR's acceptance criteria. — Effort: low, Risk: low, Impact: enforces the required workflow
- **[B]** Add a single `changelog/propensity/` section note at the top of the PR Map section as a reminder, without listing specific files. — Effort: trivial, Risk: medium, Impact: easy to miss
- **[C] Do nothing** — PRs open without changelog entries; `/merge-main` will catch the gap but forces a last-minute amendment.

**Recommendation: [A]** — Per the existing pattern in prior phase implementations; changelog entries belong in the file list.

---

## Summary (Pass 2)

| Severity | Count |
|---|---|
| BLOCKING | 1 |
| REQUIRED | 5 |
| SUGGESTION | 0 |

**Total issues:** 6

**Overall assessment:** All 7 Pass 1 issues are resolved in the current plan. Pass 2 found one new blocking issue (the `survey_nonprob` construction pattern is unspecified and actively misleading) and five required issues (two missing `step`/`timestamp` fields in the bespoke history entry, a missing `@reference_sample` property test, two instances of the wrong `survey_taylor()` API, and missing changelog files). The plan cannot be handed to `r-implement` without resolving the blocking issue — the implementer will produce broken code or spend unplanned time reverse-engineering the surveycore API. Resolve in Stage 3 then proceed to implementation.

---

## Plan Review: propensity — Pass 3 (2026-05-20)

### Prior Issues (Pass 2)

| # | Title | Status |
|---|---|---|
| 8 | `ipw()` `survey_nonprob` construction is unspecified | ✅ Resolved |
| 9 | Bespoke history entry missing `step` and `timestamp` fields | ✅ Resolved |
| 10 | `@reference_sample` property not verified in acceptance criteria | ✅ Resolved |
| 11 | Task 1.3b uses wrong `survey_taylor()` constructor API | ✅ Resolved |
| 12 | `ipw()` `@examples` will fail R CMD check due to wrong API | ✅ Resolved |
| 13 | Missing changelog entries in both PR file lists | ✅ Resolved |

### New Issues (all resolved in Stage 3)

#### Section: Plan Header / Spec Alignment

---

**Issue 14: `spec-propensity.md` not updated after 2026-05-20 `predictors` amendment**
Severity: REQUIRED
Violates spec-propensity.md's own preamble: "This spec is the source of truth for the Propensity phase."

The 2026-05-20 decisions log entry ("Inline Spec Amendment: `ipw()` signature — `predictors` arg + arg reorder") documents an approved amendment to the `ipw()` API. The outcome states: "Plan updated: Task 1.1 (13 classes, up from 11), Task 1.2 (arg order), Task 1.4 (new happy path + 2 error paths), Task 1.9 (23 rules, up from 20...)." The plan was updated correctly. However, **`plans/spec-propensity.md` was not updated**:

- §III Signature still shows `selection` as position-2 required argument; no `predictors`
- §III Argument Table has no `predictors` row
- §VIII conventions table still shows: `data, selection, reference, method = "logit", ...`
- §III Error Table omits `surveywts_error_selection_missing` and `surveywts_error_selection_conflict`

As a result, the spec directly contradicts the plan. An implementer reading both documents would see two different APIs: the spec says `ipw(data, selection_required, reference, ...)` while the plan says `ipw(data, reference, selection = NULL, predictors = NULL, ...)`.

Options:
- **[A]** Update `spec-propensity.md` to reflect the amendment: revise §III Signature, Argument Table, Error Table, and §VIII conventions table; bump spec version to 0.4. — Effort: low, Risk: low, Impact: source-of-truth and plan are in sync before implementation
- **[B]** Add a header note to `spec-propensity.md`: "See `decisions-propensity.md` (2026-05-20) for post-approval amendment: `predictors` arg + arg reorder." — Effort: trivial, Risk: low, Impact: documents the divergence without full sync
- **[C] Do nothing** — Source-of-truth contradicts the plan; any future reader relying on the spec implements the wrong API.

**Recommendation: [A]** — The spec is authoritative and should be updated; decisions log documents the rationale. A partial fix (option B) still leaves the spec in a state where the stated signature and the plan's implementation contract differ.

---

#### Section: PR 1 — Acceptance Criteria

---

**Issue 15: Acceptance criterion "All 20 error paths" doesn't match 24 test scenarios in Category 3**
Severity: REQUIRED

The PR 1 acceptance criterion reads: `"All 20 error paths: dual expect_error(class=) + expect_snapshot(error=TRUE)"`. Category 3 in Task 1.4 lists 24 distinct test scenarios:

| Scenarios | Count |
|---|---|
| `data` validation (items 1–2) | 2 |
| `selection`/`predictors` mutual exclusion (items 3–4, added by amendment) | 2 |
| `reference` validation (items 5–8: 2 for wrong type + 2 for zero/negative weight) | 4 |
| formula validation (items 9–14: character, missing-from-data, missing-from-reference, level-not-in-reference, NA-in-data, NA-in-reference) | 6 |
| `wt_name` validation (items 15–19: NULL, 1L, "", NA_character_, conflict) | 5 |
| NR-specific validation (items 20–24: perfect-separation, singular-hessian, maxit=0L, epsilon=0, epsilon=-1) | 5 |

The count "20" was not updated when the `predictors` amendment added items 3–4, and was already off by 2 before that (the original spec had ~16 scenarios; the plan had already expanded to ~22 before the amendment). The acceptance criterion count does not match the test list the implementer will write.

Options:
- **[A]** Update the acceptance criterion to say "All 24 error paths". — Effort: trivial, Risk: low, Impact: acceptance criterion matches the actual test requirement
- **[B]** Recount by going through Category 3 line-by-line and updating to the correct total. — Same as A; just more careful.
- **[C] Do nothing** — Acceptance criterion is technically unverifiable (which 20 of 24?); a PR reviewer might miss 4 paths.

**Recommendation: [A]** — Trivial fix; the criterion must match the list.

---

**Issue 16: Acceptance criterion "error-messages.md has all 11 new classes" conflicts with Task 1.1's 13 classes**
Severity: REQUIRED

The PR 1 acceptance criterion reads: `"error-messages.md has all 11 new classes"`. But Task 1.1 specifies 13 new classes, including `surveywts_error_selection_missing` and `surveywts_error_selection_conflict` added by the 2026-05-20 `predictors` amendment. The count "11" was not updated in the acceptance criterion when Task 1.1 was updated.

An implementer checking off the acceptance criterion after writing 11 classes would mark the box as done — missing the 2 extra classes required by the `predictors` interface validation.

Options:
- **[A]** Update the acceptance criterion to say "error-messages.md has all 13 new classes". — Effort: trivial, Risk: low, Impact: acceptance criterion matches Task 1.1
- **[B]** Enumerate the 13 class names in the acceptance criterion. — Effort: low, Risk: low, Impact: more explicit but verbose
- **[C] Do nothing** — Implementer may omit `surveywts_error_selection_missing` or `surveywts_error_selection_conflict` from error-messages.md.

**Recommendation: [A]** — Match the count to Task 1.1; names are already enumerated there.

---

**Issue 17: Task 1.9 says `@param` for "all 8 args" but `ipw()` now has 9 parameters**
Severity: REQUIRED

Task 1.9 reads: `"Add full roxygen2 block: @title, @description, @param for all 8 args, @return, ..."`. After the 2026-05-20 `predictors` amendment, `ipw()` has 9 parameters:

`data, reference, selection, predictors, method, maxit, epsilon, trim, wt_name`

The decisions log outcome for the amendment says "@param count" was updated — but the plan text still says "8 args". An implementer following this literally would write `@param` blocks for 8 arguments and omit one (most likely `predictors`, since it was the last addition).

Options:
- **[A]** Update "all 8 args" to "all 9 args" in Task 1.9. — Effort: trivial, Risk: low, Impact: implementer writes the correct number of `@param` blocks
- **[B]** List the 9 argument names explicitly in Task 1.9 so there is no ambiguity. — Effort: trivial, Risk: low
- **[C] Do nothing** — One `@param` block will be missing; `devtools::check()` will warn about undocumented parameters, violating the "0 warnings" acceptance criterion.

**Recommendation: [A]** — One-word fix; prevents a warning that would block the PR's acceptance criterion.

---

#### Section: PR 1 — Suggestions

---

**Issue 18: Task 1.7 doesn't specify how to format `estimated_population_size` in the N_hat field**
Severity: SUGGESTION

Task 1.7 says the `"ipw"` case produces:
```
ipw [~ <formula>, <method>, n_ref=<n_reference>, N_hat=<estimated_population_size>]
```
No formatting guidance is given for `estimated_population_size`. In R, pasting a numeric vector element produces its full floating-point representation (e.g., `"148392.371839456"`). The spec example shows `N_hat=148392` (integer-looking). The accepted print snapshot (Task 1.12) will capture whatever the implementation produces, but without guidance the implementer may produce verbose output like `N_hat=148392.4` or `N_hat=148392.37183946` — inconsistent with the spec's implied intent.

Options:
- **[A]** Add to Task 1.7: "Format `estimated_population_size` as `round(entry$estimated_population_size)` (integer, no decimal)." — Effort: trivial, Risk: low, Impact: clean N_hat display consistent with spec example
- **[B]** Let the snapshot capture whatever the implementation produces. — Effort: zero, Risk: low, Impact: may produce verbose N_hat; technically passes since snapshot tests capture actual output
- **[C] Do nothing** — Implementer guesses; output may be inconsistent with spec example.

**Recommendation: [A]** — One additional word in the format spec prevents ugly floating-point output. `round()` matches the spec example without introducing formatting overhead.

---

**Issue 19: GLM non-convergence test may inadvertently trigger `surveywts_error_propensity_scores_degenerate`**
Severity: SUGGESTION

Task 2.2 Category 4 specifies: "GLM non-convergence test: binary covariate where all nonrespondents = 1 and all respondents = 0 (perfect separation) → `surveywts_warning_propensity_glm_convergence`; result still returned."

The test sequence in PR 2's implementation is:
1. `withCallingHandlers` wraps `stats::glm()` — "algorithm did not converge" → re-emits `surveywts_warning_propensity_glm_convergence`
2. `predict(fit, type = "response")` extracts scores
3. `any(scores <= 0 | scores >= 1)` → `surveywts_error_propensity_scores_degenerate`

With **complete** perfect separation (all nonrespondents = 1, all respondents = 0), `stats::glm()` IRLS pushes coefficients toward ±∞. In practice, R's floating-point arithmetic returns scores very close to 0 and 1 but not exactly — so the degenerate check typically passes. However, if the dataset is small (e.g., n = 10 with 2 nonrespondents and 8 respondents all perfectly separated), R's `glm()` may return `predict()` values of exactly `1` or `0` due to numerical overflow before convergence, triggering the degenerate error instead of the warning path. The test would then fail with an unexpected error rather than the expected warning + result.

Options:
- **[A]** Add a note to Task 2.2: "After constructing the perfect-separation dataset, verify with `all(fitted(fit) > 0 & fitted(fit) < 1)` that scores remain strictly in (0, 1); if needed, use an 80/20 responder split rather than 100% separation to ensure non-degenerate fitted values." — Effort: trivial, Risk: low, Impact: test construction is robust; no guesswork
- **[B]** Accept the risk — in practice, R's `glm()` doesn't return exactly 0 or 1 with double-precision arithmetic. — Effort: zero, Risk: low (but non-zero)
- **[C] Do nothing** — Risk: test may intermittently fail on specific R versions or data seeds.

**Recommendation: [A]** — A one-line note removes ambiguity about test construction; the alternative (option B) is likely fine in practice but slightly brittle.

---

## Summary (Pass 3)

| Severity | Count |
|---|---|
| BLOCKING | 0 |
| REQUIRED | 4 |
| SUGGESTION | 2 |

**Total issues:** 6

**Overall assessment:** All 6 Pass 2 issues are resolved. Pass 3 found no blocking issues but four required ones: the spec was not updated after the 2026-05-20 `predictors` amendment, leaving `spec-propensity.md` in conflict with the plan (different signature, missing error classes, wrong arg order table); and three stale counts in PR 1's acceptance criteria (error paths: 20 → 24, error class count: 11 → 13, @param count: 8 → 9). These are all mechanical fixes that should take under 10 minutes collectively. Two suggestions address output formatting and a subtle test construction risk. The plan is ready to hand to `/r-implement` once Stage 3 resolves the four required issues.
