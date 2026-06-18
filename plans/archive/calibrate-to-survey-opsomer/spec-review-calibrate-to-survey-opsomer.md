## Spec Review: calibrate-to-survey-opsomer — Pass 1 (2026-06-17)

---

### New Issues

#### Section: Scope / Architecture

---

**Issue 1: Error class count inconsistency — Scope says 7, Architecture says 6, and all 6 are already in `error-messages.md`**
Severity: REQUIRED

The Scope section reads "Add 7 new error classes to `plans/error-messages.md`"; the Architecture section reads "6 new error classes." The actual count is 6 (confirmed by the error table in the Function contracts section, once `surveywts_error_targets_empty_list` is correctly excluded — see Issue 2). All 6 are already present in `plans/error-messages.md`. The Scope note describes work that is already done, and the count is wrong in two places.

Options:
- **[A]** Correct Scope to "6 new error classes" and reword to "have been added to `plans/error-messages.md`" to reflect current state — Effort: low, Risk: low, Impact: removes two contradictory statements, Maintenance: none
- **[B]** Delete the error-class sentence from Scope and leave Architecture as-is — Effort: low, Risk: low, Impact: acceptable but loses the cross-reference, Maintenance: none
- **[C] Do nothing** — Scope says 7, Architecture says 6, one of the two statements is always wrong; builder has no reliable count.

**Recommendation: A** — Correct both numbers and reflect that error-messages.md is already updated.

---

**Issue 2: `surveywts_error_targets_empty_list` appears in the error table but is explicitly not a separate class**
Severity: REQUIRED
Violates DRY — one concept, two contradictory representations

The error table in Function contracts lists `surveywts_error_targets_empty_list` as its own row, then immediately below states: "Note: `surveywts_error_targets_empty_list` is not a separate class. An empty list triggers `surveywts_error_targets_not_named_list` with a distinct message…" A builder implementing from the table first would create a separate condition; reading the note, they would delete it. Both the table row and the note survive in the final spec. Also, the note's "7th class" is what inflated the Scope count.

Options:
- **[A]** Remove the `surveywts_error_targets_empty_list` row from the error table entirely. Add the empty-list behavior as an additional bullet on the `surveywts_error_targets_not_named_list` row's "Trigger condition" cell — Effort: low, Risk: low, Impact: single source of truth, Maintenance: none
- **[B]** Keep the row, remove the note, and treat it as a real class — Effort: low, Risk: low, Impact: adds an unnecessary class that duplicates behavior; inconsistent with `error-messages.md`, Maintenance: ongoing
- **[C] Do nothing** — Two contradictory representations; builder must guess.

**Recommendation: A** — Remove the row; fold the empty-list trigger into the existing class description.

---

#### Section: Function contracts — Signature / Argument semantics

---

**Issue 3: `type = "prop"` default is a usability trap when Format A examples show counts** *(BLOCKING)*
Severity: BLOCKING
Violates Lens 6 — API Coherence; "technically correct but will cause user error in realistic workflows"

The `type` argument defaults to `"prop"`. The Format A example in the spec shows:
```r
list(
  age_group = c("18-34" = 12000, "35-54" = 15000, "55+" = 10000),
  region    = c("North" = 18000, "South" = 19000)
)
```
These are counts. With `type = "prop"` (default), `12000 + 15000 + 10000 = 37000 ≠ 1`, so `surveywts_error_targets_totals_invalid` fires immediately. A user who copies this example without specifying `type = "count"` hits an error with no obvious explanation. The function name `calibrate_to_survey()` and the argument name `targets` do not hint at proportion-by-default semantics.

Additionally: the existing analogous functions (`calibrate_rake()`, `calibrate_linear()`, `calibrate_logit()`) already accept `type = c("prop", "count")` with the same `"prop"` default, so there is an internal-consistency argument for the current default. But those functions take proportions *from a reference population*, while `targets` here is labeled "Fixed census margins" — which in practice are almost always counts or population totals.

Options:
- **[A]** Change default to `type = c("count", "prop")` so `"count"` is the default for `targets` — Effort: low, Risk: medium (inconsistent with sibling functions), Impact: removes the usability trap for the most common case, Maintenance: low
- **[B]** Keep `type = "prop"` as default; update Format A example to show proportions instead of counts, and add a note in `@param targets` that counts require `type = "count"` — Effort: low, Risk: low, Impact: example is now consistent with default; user still needs to read docs, Maintenance: none
- **[C]** Keep current default; no change — Effort: none, Risk: high (users will hit the error repeatedly and blame the library), Maintenance: accumulating support burden

**Recommendation: B** — Change Format A example to proportions (they are semantically cleaner as a demonstration). If the user wants counts, they need to opt in with `type = "count"`. Add a prominent note to the `@param targets` or `@param type` documentation: "The default `type = "prop"` requires values summing to 1.0 per variable. To supply population counts, use `type = "count"`."

---

**Issue 4: `N` for `type = "prop"` → count conversion is ambiguous when `primary_design` was previously calibrated**
Severity: REQUIRED

Step 4b specifies:
> `N <- sum(primary_design@data[[primary_design@variables$weights]])`

`@variables$weights` is the name of the weight column *as it currently stands*, which is the post-calibration weight if `primary_design` was produced by a prior calibration step. `sum(calibrated weights)` is not necessarily the total population size — it is the estimated total under the calibrated design, which may differ from the true N. For proportion-to-count conversion, the intended N is the *design-weighted* total of the primary design *before* calibration, or a true external population size.

This is a statistically meaningful difference. Using post-calibration weights for N changes what the fixed margins mean.

Options:
- **[A]** Change Step 4b to use the *original* pre-calibration weight column. Define "original weight column" as the column named by `@variables$weights` at the *start* of the Opsomer procedure, before any modification — this is still `@variables$weights` since the function has not yet modified it. Note that for a design already calibrated by a prior call, this is the post-prior-calibration weight, not the raw design weight. Clarify this with a note: "N is the sum of full-sample weights of `primary_design` as supplied; this equals the estimated population size under `primary_design`'s current weighting scheme." — Effort: low, Risk: low, Impact: makes the behavior explicit, Maintenance: none
- **[B]** Add a `population_size` argument for the user to supply an explicit N, with `NULL` (use `sum(weights)`) as default — Effort: medium, Risk: medium (API bloat), Impact: full control, Maintenance: one more argument to document
- **[C] Do nothing** — The formula is as written; the ambiguity remains for users who supply a previously-calibrated design.

**Recommendation: A** — No change to the formula, but add the clarifying note to Step 4b.

---

#### Section: Function contracts — Opsomer algorithm (Steps 6–7)

---

**Issue 5: Combined target set construction is undefined when `variables` and `targets` overlap** *(BLOCKING)*
Severity: BLOCKING
Violates Lens 5 — under-engineered; "behavior is undefined for X"

The edge cases table states: "A variable can appear in both [variables and targets]. The fixed margin from targets applies for that variable; the perturbed total from the control survey for the same variable is not used in calibration."

But the Opsomer algorithm Steps 6 and 7 describe the combined target set as:
> `{ t̂_{Cx} (for variables), T_fixed (for targets variables) }`

When a variable appears in both, this set contains two constraints on the same variable — one perturbed control total and one fixed margin — which are in general inconsistent. `survey::calibrate()` cannot handle conflicting constraints; it would error or produce undefined behavior.

The spec says "fixed margin takes precedence" but does not tell the builder *how* to resolve this: should the variable be dropped from the `variables` part when building the combined target set? Should a warning be emitted? The builder must guess the implementation detail.

Options:
- **[A]** Clarify that, when building the combined target set for Steps 6 and 7, any variable that appears in `targets` is *excluded* from the `variables` part. The combined set becomes `{ t̂_{Cx} (for variables NOT in targets), T_fixed (for targets variables) }`. State this explicitly in Steps 6 and 7 — Effort: low, Risk: low, Impact: removes ambiguity; consistent with "fixed margin takes precedence", Maintenance: none
- **[B]** Disallow overlap (add `surveywts_error_targets_variable_in_variables` error class) — Effort: low, Risk: medium (restricts user), Impact: removes the conflict but loses the documented capability, Maintenance: new error class
- **[C] Do nothing** — Builder guesses; implementation may silently duplicate constraints and crash.

**Recommendation: A** — Clarify Steps 6 and 7 to exclude from the variables part any variable already named in targets.

---

**Issue 6: `a_r` formula in the Roxygen `\deqn{}` contradicts Step 3 for the K > 1 case** *(BLOCKING)*
Severity: BLOCKING

Step 3 correctly states:
```
a_r <- sqrt(A_C / A_eff)   for r = 1, …, min(R_eff, R_C)
```
where `A_eff = A / K`.

The Roxygen `@section Algorithm` specifies:
```
\deqn{a_r = \begin{cases} \sqrt{A_C / A} & r = 1, \ldots, \min(R, R_C) \\ 0 & r > \min(R, R_C) \end{cases}}
```

This formula uses `A`, not `A_eff`. For K = 1, `A_eff = A` and the formulas agree. For K > 1 (when R_C > R), `A_eff = A / K` and `sqrt(A_C / A_eff) = sqrt(A_C * K / A)` ≠ `sqrt(A_C / A)`. The documentation formula is mathematically wrong for the expansion case. The builder generating docs from the spec would produce incorrect equations.

Options:
- **[A]** Update the Roxygen `\deqn{}` to use `A_{\text{eff}}` and add the case structure showing K > 1 expansion, or reference Step 3 directly — Effort: low, Risk: low, Impact: documentation matches implementation, Maintenance: none
- **[B]** Simplify the Roxygen docs to describe only the K = 1 case, noting "when R_C > R, see the expansion algorithm" — Effort: low, Risk: low, Impact: loses full documentation of the expansion case, Maintenance: low
- **[C] Do nothing** — Roxygen docs for the K > 1 path would be wrong.

**Recommendation: A** — Update the `\deqn{}` to use `A_{\text{eff}}` with the expansion definition: `A_{\text{eff}} = A / K` when `R_C > R`, else `A_{\text{eff}} = A`.

---

**Issue 7: `c_s` for virtual replicates `s > R_C` when K > 1 is not defined**
Severity: REQUIRED

When K > 1, virtual replicates are indexed `s = 1, …, R_eff`. Step 3 defines `a_s = 0` for `s > R_C`. Step 7's perturbed-total formula is:
```
t̂*_{Cx}(s) <- t̂_{Cx} + a_s * (t̂_{Cx}^(c_s) - t̂_{Cx})
```
For `s > R_C`, `a_s = 0` so the term vanishes, but the formula still references `c_s` — the mapped control replicate index. The spec does not say what `c_s` is for `s > R_C`, and does not say that the builder should skip the `c_s` lookup.

A builder implementing Step 7 literally would try to look up `c_s` for these indices and fail (since `control_col_matches` has only `min(R_eff, R_C)` entries).

Options:
- **[A]** Add a sentence to Step 7: "For virtual replicates `s > R_C`, `a_s = 0`; no control replicate lookup is needed — the perturbed total equals the full-sample total regardless of `c_s`." — Effort: low, Risk: low, Impact: builder cannot make an indexing mistake, Maintenance: none
- **[B]** Rewrite the formula branch to make the zero case explicit: separate the `s <= R_C` and `s > R_C` sub-steps — Effort: medium, Risk: low, Impact: clearer but verbose, Maintenance: low
- **[C] Do nothing** — Builder tries to access `control_col_matches[s]` for `s > R_C`; runtime indexing error or undefined behavior.

**Recommendation: A** — A single clarifying sentence in Step 7 is sufficient.

---

#### Section: Function contracts — Error table

---

**Issue 8: Scope says svrep-delegation errors no longer fire for `targets = NULL` — but this is not stated in the error table**
Severity: REQUIRED

The Scope says "Remove `svrep::calibrate_to_sample()` delegation; the function is now self-contained." The existing errors `surveywts_error_calibration_not_converged` and `surveywts_error_calibration_failed` previously referred to "svrep" as the trigger source. The error table now says "svrep (when `targets = NULL`) or `.calibrate_engine()` (when `targets` is non-NULL)". But if svrep delegation is removed entirely (even for `targets = NULL`), the "svrep (when `targets = NULL`)" clause is wrong — `.calibrate_engine()` should be the trigger on all paths.

Options:
- **[A]** Update both error rows to read "`.calibrate_engine()` on any call path" — the svrep trigger is retired along with the delegation — Effort: low, Risk: low, Impact: consistent with scope, Maintenance: none
- **[B]** Keep both mentions but rewrite to "`.calibrate_engine()` on all calls (svrep delegation removed)" — Effort: low, Impact: same, Maintenance: none
- **[C] Do nothing** — Error table describes a trigger that no longer exists.

**Recommendation: A**

---

#### Section: Function contracts — Roxygen2 documentation

---

**Issue 9: `@examples` do not specify which package data to use — current example requires `svrep` which moves to Suggests**
Severity: REQUIRED
Violates `.claude/rules/function-documentation.md` — `@examples` must use package data

The current `calibrate_to_survey.R` examples use `data(api, package = "survey")` and `svrep::as_bootstrap_design()` — an Imports function that moves to Suggests in this spec. The spec says svrep moves to Suggests, so any example using `svrep::` would require `\dontrun{}` or `skip_if_not_installed`, which violates the "all examples must run during R CMD check" rule.

The spec's Roxygen section does not address what package data to use or how to construct the example designs without svrep. If no existing surveywts bundled datasets include designs with `@variables$scale` populated and replicate weights, the spec must flag the relevant dataset for remediation.

Options:
- **[A]** Add a note to the Roxygen documentation section specifying: (1) which bundled surveywts datasets carry `@variables$scale`, (2) if none exist, flag the dataset that needs to be extended or created. Wrap the `svrep`-dependent example in `if (requireNamespace("svrep", quietly = TRUE)) { ... }` — Effort: medium, Risk: low, Impact: R CMD check stays clean, Maintenance: low
- **[B]** Define the example entirely using surveywts's own `create_*_weights()` functions (no svrep dependency in examples) — Effort: high, Risk: low, Impact: fully self-contained, Maintenance: none
- **[C] Do nothing** — The existing example calls a Suggests package without a guard; R CMD check will warn or error.

**Recommendation: A** — Audit which bundled datasets work; guard any svrep example call with `if (requireNamespace(...))`.

---

#### Section: Test-spec — Datasets / helper functions

---

**Issue 10: `make_replicate_design()` and `make_nonprob_replicate_design()` are referenced but not defined**
Severity: REQUIRED

The test-spec lists these as defined in `tests/testthat/helper-test-data.R`. The current helper file defines only `make_surveywts_data()`. These two functions are prerequisites for every test in the test plan. Without knowing whether they already exist (and what their contracts are) or need to be created (and what their signatures should be), the builder cannot write the tests.

Options:
- **[A]** Add a "Helper function specifications" section to the test-spec defining the signatures and minimum output contracts for both functions. If they don't exist yet, specify their required columns and that `@variables$scale` must be non-NULL — Effort: medium, Risk: low, Impact: builder can implement the helpers, Maintenance: none
- **[B]** Replace the helpers with inline construction using `create_bootstrap_weights()` in each test block — Effort: high, Risk: low, Impact: no new helpers needed; verbose tests, Maintenance: higher per-test overhead
- **[C] Do nothing** — Builder must reverse-engineer required contract from how the functions are called in tests.

**Recommendation: A** — Add helper contracts to the test-spec.

---

**Issue 11: Test-spec references `params$targets_from_reference` — a non-existent history field**
Severity: REQUIRED

The test-spec happy-path table for `targets` non-NULL includes:

| `reference_design stored in history` | Supply valid `survey_taylor` | `params$targets_from_reference == TRUE` | `expect_true` |

The spec's history entry schema does not define a field named `targets_from_reference`. Per the spec: "`reference_design` — Stored in history for provenance only." If stored, the assertion should check that the history entry contains `reference_design` (or a named pointer to it), not a field that doesn't exist.

Options:
- **[A]** Remove this test row, or replace it with `!is.null(params$reference_design)` — checking that the object (or its identifying metadata) is present in history — Effort: low, Risk: low, Impact: test correctly reflects the spec contract, Maintenance: none
- **[B]** Add `targets_from_reference` as a new boolean history field in the spec — Effort: low, Risk: low, Impact: documents intent, Maintenance: adds a new history field not described in the function contract
- **[C] Do nothing** — The test references a non-existent field and would fail immediately on implementation.

**Recommendation: A** — Fix the test row to match the actual history schema.

---

**Issue 12: Missing happy-path tests for Format B (tibble) targets and mixed-format lists**
Severity: REQUIRED

The spec explicitly supports three `targets` formats:
- Format A: named numeric vector
- Format B: tibble with variable column + `n` or `prop` column
- Mixed: both formats within the same list

All test-spec happy-path rows for the `targets` non-NULL path use Format A only. There is no test that Format B is accepted and produces a valid result, and no test that mixed format works. If the normalization logic for Format B has a bug, no test would catch it.

Options:
- **[A]** Add one happy-path test row for Format B (tibble element, type = "count") and one for a mixed-format list — Effort: low, Risk: low, Impact: covers the normalization code path, Maintenance: none
- **[B]** Move Format B testing to an error-path test only (invalid tibble → error) — Effort: low, Risk: medium, Impact: happy path for tibble remains uncovered, Maintenance: none
- **[C] Do nothing** — Format B normalization untested; silent bug possible.

**Recommendation: A**

---

**Issue 13: Missing test that `algorithm` is silently ignored when `method != "rake"`**
Severity: REQUIRED

The spec states: "`algorithm` is `rlang::arg_match()` matched regardless; its value is not passed to `.calibrate_engine()` when `method` is `"linear"` or `"logit"`." There is no test verifying this. A builder who accidentally passes `algorithm` to `.calibrate_engine()` for all methods would have no failing test.

Options:
- **[A]** Add an edge-case test: supply `method = "linear"`, `algorithm = "nr"`, `targets` non-NULL; expect no error and a valid result; assert the result is identical to the same call without `algorithm` — Effort: low, Risk: low, Impact: verifies the silent-ignore behavior, Maintenance: none
- **[B]** Do nothing — no coverage for silent ignore path.

**Recommendation: A**

---

#### Section: Test-spec — History tests

---

**Issue 14: History tests do not verify `targets` and `type` are absent when `targets = NULL`**
Severity: SUGGESTION

The test-spec verifies `is.null(params$fixed_variables)` when `targets = NULL`. The spec also states: "When `targets = NULL`, the history entry … omits `targets`, `type`, and `fixed_variables` (which are undefined when there are no fixed margins)." The test-spec does not check that `targets` and `type` are also absent from `params` for the `targets = NULL` path.

Options:
- **[A]** Add test rows: `is.null(params$targets)` and `is.null(params$type)` for the `targets = NULL` happy path — Effort: low, Risk: low, Impact: complete history schema coverage
- **[B]** Do nothing — The three-field absence is partially tested (only `fixed_variables` checked)

**Recommendation: A**

---

#### Section: API coherence — behavioral change disclosure

---

**Issue 15: Behavioral change for existing callers (svrep linear GREG → rake/classic_ipf) has no migration signal**
Severity: SUGGESTION
Violates Lens 6 — silent behavioral surprise in realistic upgrade workflows

The Scope explicitly marks "Preserving bit-exact output for existing `targets = NULL` callers" as **Out**. This is the correct decision, but the change is silent: users who upgrade and don't read release notes will get different point estimates from the same code. The only signal is the result itself.

Existing behavior: svrep linear GREG (equivalent to `method = "linear"`).
New behavior: rake with `algorithm = "classic_ipf"` by default.

Options:
- **[A]** Add a one-time `surveywts_warning_calibration_method_changed` warning (lifecycle-style) for one version cycle, emitted when `targets = NULL` and `method` is not explicitly supplied — Effort: medium, Risk: low, Impact: users get a signal; they can silence it by explicitly passing `method = "linear"`, Maintenance: remove after one release
- **[B]** Add a conspicuous NEWS.md entry only (no runtime signal) — Effort: low, Risk: medium, Impact: users who don't read NEWS still get silent behavioral changes, Maintenance: none
- **[C] Do nothing** — Silent breaking change. CRAN packages are typically allowed to change defaults, but survey practitioners reproducing published analyses are specifically harmed.

**Recommendation: B** — At minimum, a prominent NEWS entry. Whether a runtime warning is appropriate is a judgment call for the user (ask via HOLD if needed).

---

**Issue 16: History schema change for `targets = NULL` callers not flagged as potentially breaking**
Severity: SUGGESTION

When `targets = NULL`, the history entry now includes two new fields: `a_constants` and `K`. This is additive (not removing fields), but any caller who inspects `@metadata@weighting_history` by index or field name may be affected. The spec should note this as a non-breaking additive schema change so the builder includes it in the changelog.

Options:
- **[A]** Add a note to the Scope section: "The history entry for `targets = NULL` calls gains two new fields (`a_constants`, `K`) — additive change, existing key-name lookups are unaffected" — Effort: low, Risk: low, Impact: builder knows to note this in NEWS, Maintenance: none
- **[B]** Do nothing.

**Recommendation: A**

---

**Issue 17: `control_col_matches` random permutation test should specify a mocking approach**
Severity: SUGGESTION

The test-spec's gotcha coverage includes:
> "Call without `control_col_matches`; run twice with different `set.seed()` values; confirm full-sample calibrated weights are identical (calibration is deterministic) but replicate calibrated weights differ across calls."

Wait — this is actually wrong per the spec: `control_col_matches` affects replicate calibration (which replicate is mapped to which control replicate), so replicate weights would differ across calls without a seed. But full-sample calibration (Step 6) does NOT use `control_col_matches`; it uses the full-sample control totals `t̂_{Cx}` directly. So full-sample calibrated weights should be identical across calls regardless of `control_col_matches`. The test assertion is correct, but the description should clarify: "full-sample calibrated weights are identical (Step 6 does not depend on control_col_matches; it uses full-sample control totals); replicate calibrated weights differ because the control replicate assignment changes." Add this clarification to the gotcha row.

Options:
- **[A]** Add the clarifying parenthetical to the gotcha row description — Effort: low, Risk: low, Impact: builder understands why full-sample weights are deterministic, Maintenance: none
- **[B]** Do nothing.

**Recommendation: A**

---

## Summary (Pass 1)

| Severity | Count |
|---|---|
| BLOCKING | 3 |
| REQUIRED | 9 |
| SUGGESTION | 5 |

**Total issues:** 17

**Overall assessment:** The spec is well-structured and statistically detailed, but has three blocking gaps that would force the builder to make architectural guesses: the combined-target-set construction when variables and targets overlap (Issue 5), the a_r formula discrepancy between the implementation steps and the Roxygen documentation (Issue 6), and the type = "prop" default that makes the spec's own Format A examples non-functional (Issue 3). The test-spec also has two test rows referencing fields or assertions that don't match the function contract (Issues 11 and 7). Resolving the three BLOCKING issues and the two critical test-spec mismatches (Issues 10, 11) is enough to unblock implementation; the REQUIRED issues can be addressed in the same pass.

---

## Spec Review: calibrate-to-survey-opsomer — Pass 2 (2026-06-17)

### Prior Issues (Pass 1)

| # | Title | Status |
|---|---|---|
| 1 | Error class count inconsistency — Scope says 7, Architecture says 6 | ✅ Resolved |
| 2 | `surveywts_error_targets_empty_list` row contradicts its own note | ✅ Resolved |
| 3 | `type = "prop"` default is a usability trap when Format A examples show counts | ✅ Resolved |
| 4 | `N` for `type = "prop"` → count conversion is ambiguous when primary was previously calibrated | ✅ Resolved |
| 5 | Combined target set construction is undefined when `variables` and `targets` overlap | ✅ Resolved |
| 6 | `a_r` formula in Roxygen `\deqn{}` contradicts Step 3 for the K > 1 case | ✅ Resolved |
| 7 | `c_s` for virtual replicates `s > R_C` when K > 1 is not defined | ✅ Resolved |
| 8 | Error table references svrep as trigger source after delegation removed | ✅ Resolved |
| 9 | `@examples` svrep dependency without requireNamespace guard | ✅ Resolved |
| 10 | `make_replicate_design()` and `make_nonprob_replicate_design()` undefined | ✅ Resolved |
| 11 | Test-spec references `params$targets_from_reference` — non-existent history field | ✅ Resolved |
| 12 | Missing happy-path tests for Format B (tibble) targets and mixed-format lists | ✅ Resolved |
| 13 | Missing test that `algorithm` is silently ignored when `method != "rake"` | ✅ Resolved |
| 14 | History tests do not verify `targets` and `type` absent when `targets = NULL` | ✅ Resolved |
| 15 | Behavioral change for existing callers has no migration signal | ✅ Resolved |
| 16 | History schema change for `targets = NULL` callers not flagged as additive | ✅ Resolved |
| 17 | `control_col_matches` random permutation test description lacked Step 6 clarification | ✅ Resolved |

### New Issues

#### Section: Function contracts — History entry

---

**Issue 18: `a_constants` length is ambiguous when K > 1 (R_C > R expansion)**
Severity: REQUIRED

The history parameter section states: "`a_constants` — numeric vector of **length `R`**, the `a_r` values used." However, the algorithm operates with `R_eff = K * R` virtual replicates, each with its own `a_s` value (Step 3). When K = 1, R_eff = R and there is no ambiguity. When K > 1 (R_C > R), there are `K * R` a_s values internally, but the spec says length R is stored.

The spec does not define how to collapse K * R values to R. A builder might store:
- `a_s` for the first virtual replicate of each primary replicate (a_s[(r-1)*K + 1] for r = 1..R)
- All R_eff values (length K*R, not R)
- The average a_s across the K virtual replicates for each primary replicate

These produce numerically different stored values for any case where K > 1 and some virtual replicates have `a_s = 0`. The test-spec only tests length for the R = R_C = 50 case (K = 1), so no test would catch an incorrect K > 1 implementation.

Options:
- **[A]** Specify that `a_constants` stores all `R_eff = K * R` values (not R), renaming the length guarantee to "length `R_eff`" — Effort: low, Risk: low, Impact: unambiguous; test-spec gains a length assertion for K > 1 case, Maintenance: none
- **[B]** Specify that `a_constants` stores the `a_s` values for the first virtual replicate of each primary replicate, i.e., `a_s[(r-1)*K + 1]` for r = 1..R — Effort: low, Risk: low, Impact: length R preserved; builder has a clear rule, Maintenance: none
- **[C]** State "when K = 1, length R; when K > 1, length R_eff = K * R" explicitly — Effort: low, Risk: low, Impact: covers both cases; test-spec should test both, Maintenance: none
- **[D] Do nothing** — Builder picks arbitrarily; tester's length assertion passes only for K = 1; silent mismatch for K > 1.

**Recommendation: A** — Storing all R_eff values is most informative and matches the algorithm's natural indexing. Update the history param description to "numeric vector of length `R_eff` (= K * R), the `a_s` values for all virtual replicates." Add a test-spec row for length when K > 1.

---

**Issue 19: `targets` history field — proportions or converted counts? Step 4b and history param conflict**
Severity: REQUIRED

Two spec passages describe what is stored in the `targets` history field:

- **History parameters section:** "`targets` — the fixed margins as supplied (after format normalization)"
- **Step 4b:** "The converted count values are stored in the history entry."

If `type = "prop"`, the user supplies proportions. "As supplied" (history section) → store proportions. "Converted count values" (Step 4b) → store counts. These are different. A builder implementing from the history section stores proportions; from Step 4b stores counts. There is no way to reconcile these two statements as written.

This also affects the test-spec's numerical correctness test: "`type = "prop"` conversion uses original primary weights as N; manually compute N = sum(original primary weights) and verify that N × proportion[lev] equals the calibrated full-sample total." That test verifies the conversion math but does not pin what is stored in history.

Options:
- **[A]** Clarify that `targets` in the history stores the **converted counts** (the T_fixed values as counts, after proportion-to-count conversion when `type = "prop"`). Amend Step 4b to say "The converted count values are stored in the history entry's `targets` field, replacing the original proportions." Remove the "as supplied" phrase — Effort: low, Risk: low, Impact: single source of truth; builder stores counts, Maintenance: none
- **[B]** Clarify that `targets` in the history stores the **original user-supplied values** (proportions if `type = "prop"`, counts if `type = "count"`), after format normalization to named numeric vectors. Remove the "converted count values" sentence from Step 4b — Effort: low, Risk: low, Impact: round-trips the user's input; consistent with "as supplied", Maintenance: none
- **[C] Do nothing** — Two contradictory statements; one of them will be wrong in the implementation.

**Recommendation: B** — Store what the user supplied (after format normalization); the `type` field already records how to interpret those values. The conversion to counts is an internal implementation detail, not part of the audit trail. Amend Step 4b to remove "converted count values are stored in the history entry" and replace with "the conversion is used internally for Steps 5–7; the history entry's `targets` field stores the original normalized user-supplied values."

---

#### Section: Roxygen2 documentation requirements

---

**Issue 20: `@section Warnings` not specified — three warning conditions exist**
Severity: REQUIRED
Violates `.claude/rules/function-documentation.md` — Warnings is a canonical section; required "when applicable"

The spec's Roxygen documentation requirements list `@section Algorithm`, `@section Convergence`, and `@section Limitations` but do not specify `@section Warnings`. The function has three warning conditions:
- `surveywts_warning_control_param_ignored` — unknown key in `control`
- `surveywts_warning_replicate_scheme_mismatch` — type mismatch between designs
- `surveywts_warning_negative_calibrated_weights` — negative full-sample weights under `method = "linear"`

Per `function-documentation.md`: "Warnings — when warnings may occur and how to resolve them. Plain language only — no warning class names." The function-documentation.md rule lists Warnings as the 6th canonical section to use when applicable, and three active warning conditions clearly qualify.

Options:
- **[A]** Add `@section Warnings` to the Roxygen documentation requirements, with plain-language descriptions of each condition and how to resolve it — Effort: low, Risk: low, Impact: builder has the documentation contract, Maintenance: none
- **[B]** Note that Warnings section is intentionally omitted (e.g., because warnings are self-explanatory from `@param control`) — Effort: low, Risk: low, Impact: documents the decision, Maintenance: none
- **[C] Do nothing** — Builder produces Tier 3 docs without a Warnings section; documentation is incomplete per the rules.

**Recommendation: A** — Add the Warnings section spec. Three non-trivial warning conditions warrant documentation.

---

#### Section: Test-spec — skip_if_not_installed placement

---

**Issue 21: `skip_if_not_installed("svrep")` applied section-wide instead of block-level**
Severity: REQUIRED
Violates `.claude/rules/testing-standards.md §4` — "block-level, not file-level"

The test-spec states: "Run all tests with `skip_if_not_installed("svrep")`" for the entire `targets = NULL` section. But many tests in that section do not call any svrep function — they call `calibrate_to_survey()` (which no longer delegates to svrep) and inspect the result or history. Only the numerical comparison tests (the svrep oracle rows) require svrep to be installed.

Applying a section-wide skip would cause the entire `targets = NULL` test section to be skipped in environments where svrep is not available, including CRAN check environments where svrep is in Suggests. All the class, history, and `a_constants` tests would be silently skipped.

Per testing-standards.md: "Place `skip_if_not_installed()` inside the `test_that()` block that actually requires the external package. Do not put a file-level skip at the top of a test file — other blocks in the same file may not need it."

Options:
- **[A]** Move `skip_if_not_installed("svrep")` to block-level: place it inside only the numerical comparison test blocks that actually call `svrep::calibrate_to_sample()`. All other happy-path and history tests run unconditionally — Effort: low, Risk: low, Impact: all non-svrep tests run on CRAN; svrep tests skip gracefully when svrep unavailable, Maintenance: none
- **[B]** Keep section-wide skip; note it as an intentional decision — Effort: none, Risk: high (many tests silently skipped in CRAN environments), Maintenance: ongoing
- **[C] Do nothing** — Effective coverage drops significantly on any system where svrep is not installed.

**Recommendation: A** — Move skip to the two or three numerical comparison test blocks that compare against svrep. All remaining tests (class assertions, history assertions, `a_r` constants, edge cases) run without the skip.

---

#### Section: Test-spec — Edge cases / helper

---

**Issue 22: `make_replicate_design_no_scale` listed in dataset table as a defined helper, but immediately described as constructed inline**
Severity: SUGGESTION

The Datasets table in the test-spec lists `make_replicate_design_no_scale(n, seed)` as if it is a distinct helper function. The description column says: "Constructed inline by setting `@variables$scale <- NULL` after creation." This is contradictory — a function with a signature `(n, seed)` that is actually described as "constructed inline" is confusing.

If it is a helper function, it needs a contract in the Helper function specifications section. If it is constructed inline, it should not appear in the Datasets table with a function signature.

Options:
- **[A]** Remove `make_replicate_design_no_scale` from the Datasets table; instead add a note in the `surveywts_error_scale_not_found` error path row saying "constructed inline: `d <- make_replicate_design(); d$primary@variables$scale <- NULL`" — Effort: low, Risk: low, Impact: no ambiguity, Maintenance: none
- **[B]** Keep it in the table but remove the function signature; change to "Inline: `primary@variables$scale <- NULL` applied after construction" — Effort: low, Risk: low, Impact: clears the confusion, Maintenance: none
- **[C] Do nothing** — A builder reading the table thinks they need to write a helper function; a builder reading the description thinks they construct inline; both are right but neither is clear.

**Recommendation: A** — Remove from Datasets table; document the inline construction pattern in the relevant test rows.

---

**Issue 23: No test that negative replicate weights do NOT trigger the clipping warning**
Severity: SUGGESTION

The spec states: "All replicate weights written to the output design must be numeric; negative replicate weights are expected and must NOT be clipped. Only full-sample negative weights trigger `surveywts_warning_negative_calibrated_weights` (existing behavior for `method = "linear"`)."

The test-spec's warning path tests the case where full-sample weights are negative (expected to warn). But there is no test confirming that when only replicate weights are negative (full-sample positive), no warning fires. Without this test, a builder who accidentally clips replicate weights would not have a failing test.

Options:
- **[A]** Add an edge-case test: supply `method = "linear"`, `targets` non-NULL; confirm the call succeeds and `expect_no_warning()` even when some calibrated replicate weights are negative (verify by inspecting `result@variables$repweights`) — Effort: low, Risk: low, Impact: pins the "don't clip replicates" contract, Maintenance: none
- **[B]** Do nothing — the no-clipping behavior is tested implicitly by any test where negative replicate weights appear without a warning being raised.

**Recommendation: A** — Explicit is better than implicit for a behavioral contract this specific.

---

## Summary (Pass 2)

| Severity | Count |
|---|---|
| BLOCKING | 0 |
| REQUIRED | 4 |
| SUGGESTION | 2 |

**Total new issues:** 6

**Overall assessment:** All 17 Pass 1 issues are resolved; the spec is substantially improved. The remaining issues are concentrated in two areas: a statistical precision gap (a_constants length when K > 1, Issue 18) and a documentation contradiction (targets field stores proportions vs. counts, Issue 19). Both are straightforward to resolve with a one-line clarification. The test-spec skip_if_not_installed placement (Issue 21) is a standards violation that would silently suppress most of the targets = NULL test coverage on CRAN — this should be fixed before implementation begins. Once Issues 18–21 are resolved, the spec is implementable with no remaining ambiguities.

---

## Spec Review: calibrate-to-survey-opsomer — Pass 3 (2026-06-17)

### Prior Issues (Pass 2)

| # | Title | Status |
|---|---|---|
| 18 | `a_constants` length ambiguous when K > 1 | ✅ Resolved — history now specifies length `R_eff` (= `K * R`); test-spec adds K > 1 length assertion |
| 19 | `targets` history field — proportions or converted counts? | ✅ Resolved — Step 4b clarified: conversion is internal; history stores original normalized user-supplied values |
| 20 | Missing `@section Warnings` in Roxygen2 docs | ✅ Resolved — `@section Warnings` added with three plain-language conditions |
| 21 | `skip_if_not_installed("svrep")` applied section-wide | ✅ Resolved — block-level placement specified for svrep oracle test blocks only |
| 22 | `make_replicate_design_no_scale` listed as helper but is actually inline | ✅ Resolved — removed from Datasets table; inline pattern documented at point of use |
| 23 | No test that negative replicate weights don't trigger clipping warning | ✅ Resolved — edge-case test row added |

### New Issues

None.

## Summary (Pass 3)

| Severity | Count |
|---|---|
| BLOCKING | 0 |
| REQUIRED | 0 |
| SUGGESTION | 0 |

**Verdict: PASS**

All 23 issues across Passes 1 and 2 are resolved. The spec is complete, internally consistent, and implementable without ambiguity. `spec-calibrate-to-survey-opsomer.md` and `test-spec-calibrate-to-survey-opsomer.md` are SPEC_READY.
