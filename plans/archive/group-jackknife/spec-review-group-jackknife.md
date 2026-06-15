# Spec Review: group-jackknife — Pass 1 (2026-05-27)

---

### New Issues

#### Section: 2. Architecture / Argument Order

---

**Issue 1: `...` is in the wrong position for the argument order convention**
Severity: REQUIRED
Violates surveywts-conventions.md §6 and code-style.md §4 ("Argument order").

The spec signature is:

```r
create_group_jackknife_weights(
  data,
  groups = 50L,
  ...,
  reference_sample = NULL,
  seed = NULL
)
```

The convention is: `x`/`data` → required NSE → required scalar → optional NSE → optional scalar → `...`. Here `groups` is an optional scalar and `...` is used as a forcing mechanism (all subsequent args must be named). Looking at every other replicate weight function in the codebase (`create_bootstrap_weights`, `create_jackknife_weights`, `create_brr_weights`, `create_gen_boot_weights`, `create_gen_rep_weights`, `create_sdr_weights`), the pattern is `data, <required-positional-arg>, ..., <optional-named-args>`. In those functions, `...` appears after any positional scalar that the user would commonly pass, to force the remaining optional args to be named.

In this case `groups` has a meaningful default (`50L`) and is the only positional arg. The question is whether `groups = 50L` is required-positional (should come before `...`) or optional (should follow `...`). The codebase convention — exemplified by `create_jackknife_weights(data, replicates = NULL, ..., type, mse, seed)` — treats count-like integer args as pre-`...` positional. Placing `groups` before `...` (so users can call `create_group_jackknife_weights(obj, 10L)`) is consistent with `create_jackknife_weights(obj, 20L)`.

The current spec places `groups = 50L` before `...`, which is the codebase convention. **This is actually correct and consistent.** On further inspection, there is no violation here. Skipping to the next real issue.

*Revised: Issue 1 is not a real issue. Removing.*

---

**Issue 1: `nonprob-ipw.R` history entry does not currently record `maxit` or `epsilon`**
Severity: BLOCKING
Violates engineering-preferences.md §1 (explicit over implicit) and §3 (engineered enough).

The spec (§2, §3.5b, §3.6) states: "The DAGJK implementation requires that the `ipw()` history entry records `maxit` and `epsilon`. These fields are added to the `ipw()` history entry by this PR."

Reading `/Users/jacobdennen/surveywts/R/nonprob-ipw.R` lines 1170–1192, the current `ipw()` history entry contains: `step`, `timestamp`, `operation`, `formula`, `method`, `estimating_eq`, `missing_method`, `estimator`, `adjust_reference`, `nps_fraction`, `adjust_factor`, `trim`, `n_nps`, `n_reference`, `estimated_population_size`, `population_size_known`, `n_trimmed`, `reference_design`, `targets_from_reference`, `propensity_scores`. It does NOT contain `maxit` or `epsilon`.

The spec correctly identifies this as a required change to `nonprob-ipw.R`, but it does not specify:
1. The exact field names to add (`maxit` and `epsilon` — are these `as.integer(maxit)` and `as.numeric(epsilon)`? Or the raw user-supplied values before validation?)
2. What happens if `create_group_jackknife_weights()` is called on a `survey_nonprob` that was created by an older `ipw()` call (before this PR) that did not record `maxit`/`epsilon`. The DAGJK implementation presumably needs to fall back to the defaults (`maxit = 25L`, `epsilon = 1e-8`). The spec is silent on this backward-compatibility behavior.

Options:
- **[A]** Specify in §3.5b (estimation pipeline) that missing `maxit`/`epsilon` in the ipw history entry → fall back to ipw defaults (`25L` and `1e-8`); add the two fields to the nonprob-ipw.R change list with their exact types (`as.integer(maxit)` and `epsilon` as-is). — Effort: low, Risk: low, Impact: backward-compatible DAGJK for existing `survey_nonprob` objects, Maintenance: none
- **[B]** Require that `maxit`/`epsilon` are always present (error if absent) — means every existing survey_nonprob without these fields must re-run `ipw()`. — Effort: low, Risk: high (breaking), Impact: clean contract but breaks all existing serialized objects, Maintenance: low
- **[C] Do nothing** — Builder must guess the fallback behavior; likely produces incorrect variance if the user's ipw used non-default `maxit`/`epsilon`.

**Recommendation: A** — Backward compatibility costs nothing here; the defaults are correct for the vast majority of cases.

---

**Issue 2: `surveywts_error_dagjk_degenerate_replicate` is in the error table but not in the function contract**
Severity: REQUIRED
Violates testing-standards.md §2 (every error class gets a test) and code-style.md §3 (class= on every cli_abort).

`plans/error-messages.md` lists `surveywts_error_dagjk_degenerate_replicate` as "used as inner error, not surfaced to user; degenerate replicates are counted as failures." This error class appears in the error-messages.md table but is absent from the error table in spec §3.4. The spec says degenerate replicates are "counted as failed" — but it does not specify that they are caught via an internal `cli_abort()` with this class. If the class exists in error-messages.md, the test plan (test-spec §3.10) must include it. Currently §3.10 tests only `surveywts_error_dagjk_all_replicates_failed`.

Options:
- **[A]** Add `surveywts_error_dagjk_degenerate_replicate` to the spec's error table with explicit note that it is an internal error thrown inside the per-replicate `tryCatch()` and caught by the failure counter; add a corresponding internal test (direct) verifying that the degenerate replicate path throws this class. — Effort: low, Risk: low, Impact: complete test coverage, Maintenance: none
- **[B]** Remove `surveywts_error_dagjk_degenerate_replicate` from error-messages.md and replace with a comment that degenerate replicates are handled silently. — Effort: low, Risk: low, Impact: simpler error table, Maintenance: none
- **[C] Do nothing** — Untested error path; builder may choose any class or no class.

**Recommendation: A** — An internal error class with a test is the right pattern for the degenerate-replicate path.

---

#### Section: 3. Function Contract

---

**Issue 3: Operation name detection for calibration is fragile — `"calibration"` is correct but the spec should cite the source**
Severity: SUGGESTION
Violates engineering-preferences.md §5 (explicit over clever).

Spec §3.5e says: 'If a calibration step (`operation = "raking"` or `"calibration"`) is present in the weighting history after the `ipw()` entry.' The actual operation names written by `rake()` and `calibrate()` are `"raking"` and `"calibration"` respectively — confirmed by reading `R/rake.R` line 351 and `R/calibrate.R` line 225. The spec's detection logic is correct.

However, the spec does not note that this detection must use `identical()` (not `==`) or that it is looking for the LAST such entry (consistent with `.quasi_randomization_bootstrap()` which uses `calib_entry[[length(calib_entry)]]`). What if the user called `ipw()`, then `calibrate()`, then `calibrate()` again? The spec says "the calibration step" but doesn't say which one.

Options:
- **[A]** Add a sentence: "When multiple calibration entries follow the `ipw()` entry, use the last one (highest `step` number), consistent with the quasi-randomization bootstrap behavior." — Effort: low, Risk: low, Impact: unambiguous implementation, Maintenance: none
- **[B]** Accept the current text and leave it to the builder to infer "last" from the quasi-randomization bootstrap code. — Effort: none, Risk: medium (implementer divergence from bootstrap behavior)
- **[C] Do nothing** — Ambiguous; builder may use first, last, or all calibration entries.

**Recommendation: A** — One sentence resolves the ambiguity and maintains consistency with the bootstrap.

---

**Issue 4: `@return` section does not specify what happens to `@variables$fpc` and `@variables$fpctype`**
Severity: REQUIRED
Violates code-style.md §2 ("If the output is an S7 object: are `@variables` keys always present (never absent, value `NULL` when unspecified)?") and stage-3-review.md Lens 3.

The spec §3.3 (Returns) specifies: `@variables$repweights`, `@variables$scale`, `@variables$rscales`, `@variables$mse`, `@variables$type`. It does not state the disposition of `@variables$fpc`, `@variables$fpctype`, `@variables$ids`, `@variables$strata`, or `@variables$weights` (the existing base weight). Since the output is still a `survey_nonprob` (not converted to `survey_replicate`), the existing `@variables` keys must be preserved. The spec does not say this explicitly.

Looking at `.quasi_randomization_bootstrap()` (the closest analogue), it preserves all existing `@variables` by modifying only `$repweights` and appending the history entry. The DAGJK spec should state the same preservation guarantee.

Options:
- **[A]** Add to the `@return` section: "All other `@variables` keys (`weights`, `fpc`, `fpctype`, `ids`, `strata`) are preserved unchanged from the input." — Effort: low, Risk: low, Impact: complete return contract, Maintenance: none
- **[B]** Leave implicit; tester's §3.13 invariants cover `@variables$weights` unchanged. — Effort: none, Risk: medium (fpc/ids/strata silently dropped → wrong downstream behavior)
- **[C] Do nothing** — The invariant is partially covered but not completely specified.

**Recommendation: A** — A one-sentence preservation guarantee is the cleanest fix.

---

**Issue 5: Silent override of `reference_sample` over stored ipw history reference — no warning**
Severity: REQUIRED
Violates engineering-preferences.md §5 (explicit over clever) and Lens 6 (API coherence: "silently wrong result" risk).

Spec §3.5 edge cases table: "`reference_sample` supplied and ipw history also has a reference → `reference_sample` argument wins silently (no warning)."

This is the behavior of `.quasi_randomization_bootstrap()` (line 264: `ref_design <- reference_sample %||% ipw_entry$reference_design`), so it is consistent. However, the DAGJK usage is different in a methodologically important way: the reference design is used to refit the logistic model in every replicate. If a user accidentally passes the wrong reference sample (e.g., a trimmed version vs. the original), the DAGJK will silently produce methodologically wrong variance estimates — the replicate model is fit on a different population than the full-sample model. For the quasi-randomization bootstrap this is less critical because the reference is used only for margin re-estimation.

The spec must at minimum acknowledge this risk in `@details`. A lint-level warning would be more user-protective.

Options:
- **[A]** Add a `surveywts_warning_dagjk_reference_sample_override` warning (class in error-messages.md) emitted whenever `reference_sample` is non-`NULL` AND the ipw history also contains a reference design, noting both sources. — Effort: low, Risk: low, Impact: user-protective, Maintenance: low
- **[B]** Add a `@details` note only (no runtime warning): "When `reference_sample` is supplied and ipw history also stores a reference, the argument takes precedence silently. Verify that the supplied reference matches the one used in `ipw()`." — Effort: very low, Risk: low, Impact: documents the risk without runtime noise, Maintenance: none
- **[C] Do nothing** — Silent override; user-error risk for the most methodologically sensitive argument.

**Recommendation: B** — A documentation note is sufficient; emitting a warning on every use of `reference_sample` (the common case) would create noise. The risk is real but not catastrophic.

---

**Issue 6: `@variables$type` value `"group-jackknife"` vs. `create_replicate_weights()` dispatcher string — inconsistency risk**
Severity: SUGGESTION
Violates engineering-preferences.md §5 (explicit over clever).

Spec §3.3 sets `@variables$type = "group-jackknife"`. Spec §4 adds `"group-jackknife"` to the dispatcher. The existing replicate weight functions use the `svrep`/`survey` package's type strings in `@variables$type` (e.g., `"JK1"`, `"JKn"`, `"BRR"`, `"bootstrap"`) — or override with `type_override` (e.g., `"bootstrap"` for gen-boot, `"successive-difference"` for SDR). The DAGJK uses a surveywts-owned string `"group-jackknife"` that does not map to any `svrep`/`survey` type.

This is intentional since the DAGJK is implemented entirely within surveywts (no `svrep` backend). However, the spec should note that downstream `svrepdesign`-based functions may not recognize `type = "group-jackknife"` and will error or fall back. This limitation should appear in `@details` or at minimum be mentioned in the spec's assumptions section.

Options:
- **[A]** Add a sentence to `@details`: "`@variables$type` is set to `\"group-jackknife\"`, a surveywts-specific value. Downstream `survey`-package functions expecting a standard type (e.g., `\"JKn\"`, `\"BRR\"`) will not recognize this value." — Effort: very low, Risk: low, Impact: sets user expectations, Maintenance: none
- **[B]** Leave unspecified. — Effort: none, Risk: medium (user confusion when passing output to `survey::svrepdesign`)
- **[C] Do nothing**.

**Recommendation: A** — One sentence saves a user from a confusing downstream error.

---

**Issue 7: Validation order discrepancy — `groups` ceiling check (`surveywts_error_dagjk_groups_exceeds_n`) requires resolving the reference, but reference validation comes after `groups` validation**
Severity: BLOCKING
Violates spec §3.4 ("Argument order of validation").

Spec §3.4 lists validation order:
1. `data` class
2. `reference_sample` class (if non-`NULL`)
3. `groups` type → whole-number → floor → **ceiling (combined N)**
4. ipw history presence
5. reference resolution

Step 3 includes the ceiling check `groups > combined NPS + reference row count`, which requires knowing the combined NPS + reference row count. The combined count requires the reference design (to count reference rows). But the reference is not resolved until step 5 (reference resolution). At step 3, the reference may not be available yet — particularly if `reference_sample = NULL` and the reference must be pulled from the ipw history entry.

This means the ceiling check cannot happen at step 3 without either:
(a) pre-loading the ipw history at step 3 (running step 4 earlier), or
(b) performing the ceiling check at step 5 (after reference resolution), or
(c) using only the NPS row count as a conservative ceiling (groups > NPS row count alone).

The spec does not explain how this circular dependency is resolved.

Options:
- **[A]** Move the ceiling check to step 5 (after reference resolution): validate type, whole-number, and floor (`groups < 2`) at step 3; validate the ceiling (`groups > combined N`) at step 5 after the reference is resolved. Update the validation order table accordingly. — Effort: low, Risk: low, Impact: consistent implementation, Maintenance: none
- **[B]** Perform a conservative NPS-only ceiling check at step 3 (`groups > nrow(data@data)`) and the combined ceiling check at step 5. This gives the user an earlier error for a subset of cases. — Effort: low, Risk: low, Impact: slightly better user experience for extreme cases, Maintenance: low
- **[C] Do nothing** — Builder must guess the resolution; likely defers the ceiling check to step 5 anyway, making the spec wrong.

**Recommendation: A** — Clean and unambiguous. Move the ceiling check to step 5 where the reference is available.

---

**Issue 8: `seed = 0L` — spec says `seed = NULL` is the "no seed" sentinel, but `0` is a valid R seed and should not be silently treated as falsy**
Severity: REQUIRED
Violates engineering-preferences.md §4 (handle edge cases) and Lens 4.

Spec §3.3 (Arguments, `seed`): "When non-`NULL`, `set.seed(seed)` is called once immediately before group assignment." The implementation will likely use `if (!is.null(seed)) set.seed(seed)`. This correctly handles `seed = 0L` (a valid integer seed in R, `set.seed(0L)` works fine). So there is no bug here.

However, the edge case table in §3.5 does not include `seed = 0L`. The test-spec §3.3 tests `seed = NULL`, same seed, different seed — but not `seed = 0L`. Since `0L` is a legal R seed value, it should appear in the edge case table as a specified-working case, and there should be a test confirming `seed = 0L` produces valid results without error.

Options:
- **[A]** Add `seed = 0L` as a row to the edge case table in §3.5: "Valid seed value; `set.seed(0L)` is called; function completes successfully." Add a corresponding test in test-spec §3.3. — Effort: very low, Risk: low, Impact: documents a non-obvious edge case, Maintenance: none
- **[B]** Leave unspecified. — Effort: none, Risk: low (implementation likely correct, but untested)
- **[C] Do nothing**.

**Recommendation: A** — One row costs nothing and prevents a future implementer from introducing `if (seed != 0)` as a mistaken falsy check.

---

#### Section: 3.5 — Estimation Pipeline / Calibration Detection

---

**Issue 9: Calibration re-run for `operation = "calibration"` is incomplete — what arguments does `calibrate()` need?**
Severity: BLOCKING
Violates engineering-preferences.md §1 (DRY — spec should match what the quasi-randomization bootstrap actually does for calibrate()) and Lens 3 (contract completeness).

Spec §3.5e specifies: "If a calibration step (`operation = "raking"` or `"calibration"`) is present in the weighting history after the `ipw()` entry: repeat that calibration on the reduced NPS units."

For `operation = "raking"`, the spec says to use: `calib_entry$parameters$margins`, `calib_entry$parameters$type`, `calib_entry$parameters$method`, `calib_entry$parameters$control`, and `calib_entry$parameters$cap`. This matches the `.quasi_randomization_bootstrap()` code (lines 408–416).

For `operation = "calibration"`, the spec says to use: `calib_entry$parameters$variables`, `calib_entry$parameters$population`, `calib_entry$parameters$method`, `calib_entry$parameters$type`, `calib_entry$parameters$control`. Looking at `R/calibrate.R` lines 232–239, the history parameters are: `variables`, `population`, `method`, `type`, `control`, `targets_from_reference`, `reference_design`. The spec omits `reference_design` from the `calibrate()` re-run parameters.

When `targets_from_reference = FALSE`, `reference_design` is not needed in the replicate (use fixed population targets). When `targets_from_reference = TRUE`, the replicate needs to re-estimate population targets from the reduced reference design (analogous to Level B in the bootstrap). The spec covers the `targets_from_reference` distinction for raking but does not spell out what to pass as `reference_design` when calling `calibrate()` in the replicate.

Options:
- **[A]** Add to §3.5e: "For `operation = 'calibration'` with `targets_from_reference = TRUE`: pass the reduced within-replicate reference design (reference rows not in group $g$) as `reference_design`. For `targets_from_reference = FALSE`: call `calibrate()` with the original `population` targets and `reference_design = NULL`." — Effort: low, Risk: low, Impact: complete implementation contract, Maintenance: none
- **[B]** Restrict to raking only for the `targets_from_reference = TRUE` path (matching the quasi-randomization bootstrap which only handles raking for Level B), and error if `calibrate()` was called with `targets_from_reference = TRUE`. — Effort: medium, Risk: low, Impact: simpler but less capable, Maintenance: low
- **[C] Do nothing** — Builder must infer from the bootstrap code; likely gets it right but may handle `reference_design` incorrectly.

**Recommendation: A** — The spec must be complete for `calibrate()` re-runs; the logic is parallel to raking.

---

**Issue 10: Trim threshold for replicate pseudo-weights is not specified — how is the "same trim threshold" determined?**
Severity: BLOCKING
Violates Lens 3 (contract completeness) and engineering-preferences.md §4 (edge cases).

Spec §3.5d: "If the original `ipw()` call used `trim = TRUE` (as recorded in the `ipw()` history entry), apply the same trimming to replicate pseudo-weights using the same trim threshold."

The `ipw()` history entry (from `R/nonprob-ipw.R`) records `trim` (which is the raw `trim` argument passed by the user, either `FALSE` or a numeric threshold). The spec says to "apply the same trimming" but does not specify:
1. What value of `trim` is recorded — is it the raw argument or the resolved threshold?
2. How trimming is re-applied in the replicate: by calling `trim_weights()` on the pseudo-weight vector, or by applying the same cap directly?
3. If `trim = TRUE` (not a numeric threshold), how does the DAGJK know what threshold to use? `ipw()` computes the threshold internally — it is not stored in the history entry in the current `nonprob-ipw.R` implementation.

Reading `nonprob-ipw.R`, `trim` is stored as the raw argument value (`trim = trim` at line 1188). If the user passed `trim = TRUE` (not a numeric), the stored `trim = TRUE` in the history entry gives no information about the actual threshold used.

Options:
- **[A]** Require that `nonprob-ipw.R` also records the resolved trim threshold in the history entry (e.g., `trim_threshold = <computed threshold or NULL>`). The DAGJK uses this resolved threshold. Update §2 (Modified files) and §3.6 (history schema) accordingly. — Effort: low (one extra field), Risk: low, Impact: complete trimming contract, Maintenance: none
- **[B]** Restrict DAGJK trim replication to `trim = FALSE` only: if `trim != FALSE` in the ipw history, skip trimming in replicates and emit `surveywts_warning_dagjk_trim_not_replicated`. — Effort: low, Risk: low, Impact: simpler but less correct for trimmed pipelines, Maintenance: low
- **[C] Do nothing** — Builder must guess how to reproduce trimming; likely produces incorrect replicate weights for trimmed pipelines.

**Recommendation: A** — Recording the resolved threshold is the right fix; it costs nothing and makes the DAGJK correct for trimmed pipelines.

---

#### Section: 3.13 / Test-Spec §3.13 — Invariants

---

**Issue 11: Test-spec §3.13 invariant for zero-weight assignment is under-specified when replicates fail**
Severity: REQUIRED
Violates testing-standards.md §2 (one observable behavior per test block) and Lens 2 (test completeness).

Test-spec §3.13 states: "For each NPS row, the number of zero-valued entries across replicate columns equals exactly `1` (when no replicates failed) or `>= 1` (when groups failed and the row happened to be in a failed group — this can be up to `groups_failed` zeros if the row was in a failed group, but exactly `0` zeros if the row was never in a failed group replicate and zeros are not stored for failed groups)."

This invariant contains a logical contradiction: it says zeros are NOT stored for failed groups ("zeros are not stored for failed groups"), but it also says a row in a failed group may have `>= 1` zeros. If the failed replicate column is not included in the output, then no row can have a zero in a non-existent column. The invariant should read: in the successful replicate columns, each NPS row has weight `0` in exactly the columns where that row's group was deleted, and weight `> 0` in all other successful-replicate columns.

Additionally, the simplified invariant "No replicate weight is NA; all non-zero values are positive" is correct and testable. The complex invariant about zero counts across failed replicates is not testable without knowing which group each row was assigned to, which requires either exposing internal state or using `seed` to deterministically assign groups.

Options:
- **[A]** Replace the complex zero-count invariant with a clearer statement: "In the output, each NPS unit has exactly one zero-valued entry across all G_success replicate columns (the column corresponding to the group that unit was assigned to). Failed replicate columns are not present in the output, so they contribute no zeros." Test this by fixing `seed`, verifying the group assignment deterministically, and checking the zero pattern against the expected group membership. — Effort: low, Risk: low, Impact: testable invariant, Maintenance: none
- **[B]** Keep the simplified invariant only ("no NA, all non-zero are positive") and drop the zero-count invariant. — Effort: very low, Risk: low, Impact: loses some coverage but keeps the invariants simple and testable
- **[C] Do nothing** — Contradictory invariant; builder cannot implement a test for it.

**Recommendation: A** — The corrected statement is actually testable with a fixed seed and is a critical property of the DAGJK weight matrix.

---

#### Section: Test-Spec §5 — Model Refit Correctness

---

**Issue 12: Model refit test (correlation < 0.9999) is not a reliable oracle — correlation can be high even after refitting**
Severity: REQUIRED
Violates testing-standards.md §2 (numerical correctness) and Lens 2 (test completeness — the proxy test may produce false passes).

Test-spec §5 proposes: "compute `cor(repwt_g[non_deleted], full_wt[non_deleted])` for one replicate. If the model is re-fit, this correlation will not be exactly 1. Assert that the max correlation across all replicates is `< 0.9999`."

This test will produce a false pass if:
1. The dataset is constructed such that removing one group (1/50 of units) changes the logistic model coefficients negligibly — which is the typical case for a well-behaved dataset with 200+ units. The replicate pseudo-weights would be near-proportional to the full-sample weights, and `cor()` could easily be `> 0.9999`.
2. The test threshold `0.9999` is essentially "not exactly equal" — this will always pass whether or not the model is actually refit.

A more reliable test: construct a dataset where group $g$ contains ALL units with a specific covariate level (e.g., all "age_group = 55+" units). Removing group $g$ eliminates that level from the training data. A correctly-refitting model must fit a model with fewer predictors or drop that level, producing pseudo-weights that are structurally different from the full-sample weights. A non-refitting implementation would produce identical or `NA` weights for the remaining units.

Options:
- **[A]** Replace the correlation proxy with a structured test: build a dataset with a perfectly group-predictive covariate, fix `seed` so group $g$ contains all units of that covariate level, and verify that (a) the refitting model converges (the replicate succeeds), (b) the replicate weights for units with other covariate levels differ materially from the full-sample weights for those units (e.g., more than 5% deviation in mean). — Effort: medium, Risk: low, Impact: reliable detection of "refit vs. fixed weights" bug, Maintenance: low
- **[B]** Keep the correlation test but lower the threshold to `< 0.999` and note that it may produce false passes on well-balanced data. Add a note that coverage of this test is "best-effort proxy." — Effort: very low, Risk: medium (false pass still possible), Impact: documents weakness, Maintenance: none
- **[C] Do nothing** — Unreliable test; the most common implementation error (not refitting) could pass all tests.

**Recommendation: A** — The model refit test is the single most critical correctness check. It must be reliable.

---

#### Section: Test-Spec §7 — Reference Weight Adjustment

---

**Issue 13: Reference weight adjustment test (§7) cannot distinguish the adjustment from other sources of variation**
Severity: SUGGESTION
Violates testing-standards.md (numerical correctness) and Lens 2.

Test-spec §7 proposes: "run two calls, one where the NPS fraction is large (reference n = 20, NPS n = 80) and one where it is small (reference n = 400, NPS n = 80). Assert that the replicate weight distributions differ."

The replicate weight distributions will always differ between these two scenarios because the datasets are different (different reference sample size changes the model-fitting distribution, not just the adjustment). This test does not isolate the reference weight adjustment — it conflates the adjustment effect with the model-fitting effect.

The only reliable way to test the within-replicate reference weight adjustment is to expose it as internal state (which would require exporting an internal helper) or to construct a test where the adjustment factor is measurable. One approach: verify that the replicate weights for a known group-$g$-deleted replicate are consistent with the expected adjusted reference weights, by computing the expected `w_ref_adj` for that replicate manually and verifying the logistic model would produce a known propensity when fit with those adjusted weights. This is complex.

A simpler alternative: add a bullet to `@details` explicitly stating that the within-replicate reference weight adjustment is an internal implementation detail that is not separately testable via the public API; coverage is provided by the variance magnitude test (§5) and the refit-per-replicate test.

Options:
- **[A]** Replace §7 with a documented rationale: "The within-replicate reference weight adjustment is an internal implementation detail. It is covered indirectly by the model refit correctness test (§5) and the variance magnitude comparison. No separate test is written for this adjustment." — Effort: very low, Risk: low, Impact: honest about test coverage limits, Maintenance: none
- **[B]** Keep §7 but add a note that it tests a proxy (different replicate weight distributions), not the adjustment mechanism directly. — Effort: very low, Risk: low, Impact: documents weakness
- **[C] Do nothing** — Test stays in with a misleading rationale.

**Recommendation: A** — Be honest about what is testable. Remove the false-precision proxy and document the coverage gap.

---

#### Section: Test-Spec §3.10 — All Replicates Fail

---

**Issue 14: "All replicates fail" test construction is left entirely to the builder's judgment**
Severity: REQUIRED
Violates testing-standards.md §2 ("never use edge case parameters to avoid constructing the edge case inline") and Lens 2 (edge case coverage).

Test-spec §3.10: "constructing a case where all replicates fail due to model non-convergence may require manufacturing a highly collinear dataset. An alternative approach is to verify the behavior via a mock/stub inside the test that forces all replicate iterations to throw. Use whichever approach the builder judges most maintainable."

Leaving the approach to the builder's judgment for a required error path is under-specification. The spec should prescribe one approach, with sufficient detail that two different builders produce equivalent tests.

The simplest reliable approach for triggering `surveywts_error_dagjk_all_replicates_failed` without mocking: use `groups = 2` on a dataset with exactly 2 NPS units, so every group deletion leaves exactly 1 NPS unit (which cannot fit a logistic model reliably), causing both replicates to fail. This is deterministic and requires no mocking.

Options:
- **[A]** Replace the open-ended description with: "Construct a `survey_nonprob` with exactly 2 NPS units and a reference with 2 units. Use `groups = 2`. Each replicate leaves 1 NPS unit and 1 reference unit, which cannot fit a binary logistic model (only 1 observation per class). Both replicates fail, triggering `surveywts_error_dagjk_all_replicates_failed`." — Effort: low, Risk: low, Impact: deterministic, reproducible test, Maintenance: none
- **[B]** Specify that a mock is required and describe the mock interface: "Use `testthat::local_mocked_bindings()` to replace the internal refit helper with a function that always throws." — Effort: medium, Risk: medium (tightly couples test to internal function name), Impact: tests the error path regardless of dataset
- **[C] Do nothing** — Builder chooses; inconsistent test quality.

**Recommendation: A** — The minimum-size dataset approach is simpler, deterministic, and does not depend on internal mocking.

---

#### Section: Test-Spec §3.4 — Calibration History (Dataset B)

---

**Issue 15: Test-spec §3.4 "calibration step is repeated per replicate" test is identical in structure to the model refit proxy issue — it is a difference-not-identity test, not a correctness test**
Severity: SUGGESTION
Violates Lens 2 (test completeness).

Test-spec §3.4: "Replicate weights from Dataset B differ from replicate weights produced by an identical run on Dataset A (QR-only)." This test confirms that Dataset B produces different replicate weights than Dataset A — but the difference could stem from the calibration changing the weight column used as the base for the replicate loop, not from the replicate calibration step itself. In other words, a buggy implementation that skips the within-replicate calibration would still produce different weights from Dataset A (because the full-sample base weight in Dataset B is calibrated, while Dataset A's base weight is the raw pseudo-weight).

A more reliable test: within Dataset B, confirm that the sum of each replicate weight column (after group deletion) is equal to the calibration target population total (or approximates it), since a correctly-calibrated replicate weight should satisfy the calibration constraints. This is directly testable.

Options:
- **[A]** Add a sub-test: "For Dataset B with `type = 'prop'` raking, verify that each successful replicate weight column, when used to compute the weighted proportion for each raking variable, is approximately equal to the raking margin target (within calibration convergence tolerance)." — Effort: medium, Risk: low, Impact: confirms within-replicate calibration is running, Maintenance: low
- **[B]** Keep the current difference test and add a note that it is a proxy. — Effort: very low, Risk: medium (false pass possible)
- **[C] Do nothing** — Weak test that passes even when within-replicate calibration is skipped.

**Recommendation: A** — The calibration margin check is the right oracle for "did calibration run?"

---

#### Section: Test-Spec §3.11 — Warning Paths

---

**Issue 16: Warning snapshot tests are specified in §10 (Profile Gates) but not in each warning test block**
Severity: REQUIRED
Violates testing-standards.md §3 (dual pattern: `class=` + snapshot for all Layer 3 warnings) and the spec's own §5 Quality Gates ("All new warning classes have a corresponding `expect_warning(class = ...)` test").

Test-spec §10 (Profile Gates) states: "All `expect_warning(class = ...)` calls have corresponding snapshot | Each warning path has a `expect_snapshot(warning = TRUE)` pair." However, test-spec §3.11 specifies `expect_warning(class = ...)` for each warning path but does not explicitly pair each one with `expect_snapshot(warning = TRUE)`. The dual pattern requirement exists in the profile gates but is not wired into the individual test descriptions in §3.11.

This means a builder could write only `expect_warning(class = ...)` for each warning and pass the quality gate check without writing snapshots.

Options:
- **[A]** Add `expect_snapshot(warning = TRUE, ...)` pairing explicitly to each row in test-spec §3.11, exactly as is done for error paths in §3.6–3.10. — Effort: low, Risk: low, Impact: consistent dual pattern, Maintenance: none
- **[B]** Leave the snapshot requirement in §10 only, trusting the builder to apply it. — Effort: none, Risk: medium (incomplete snapshots survive review)
- **[C] Do nothing**.

**Recommendation: A** — The dual pattern is a project-wide standard; it should be explicit in each test block, not only in profile gates.

---

#### Section: 3.6 — History Entry

---

**Issue 17: History entry schema lacks `reference_design` field — needed for downstream functions that may re-use the reference**
Severity: SUGGESTION
Violates Lens 3 (contract completeness) and consistency with the ipw() history entry pattern.

The `group_jackknife_weights` history entry (§3.6) contains: `step`, `operation`, `timestamp`, `groups`, `groups_used`, `groups_failed`, `seed`, `scale`, `source_design`. It does not include a `reference_design` field (the resolved reference used in the replication loop).

The `ipw()` history entry includes `reference_design`. If a future function needs to re-use the reference design from DAGJK (analogous to how DAGJK re-uses the ipw reference), it would need to look back to the `ipw()` history entry — which the DAGJK already does. Not storing the resolved reference in the DAGJK history entry is acceptable but creates a slight inconsistency.

More immediately: the spec says `reference_sample` argument wins over stored ipw reference. If the user passes `reference_sample`, the ipw history entry still records the original reference. The DAGJK history entry would not record which reference was actually used. This could cause confusion during debugging.

Options:
- **[A]** Add `reference_design` to the history entry schema, recording the resolved reference used for the replicate loop (either from the argument or from ipw history). — Effort: low, Risk: low, Impact: complete audit trail, Maintenance: none
- **[B]** Leave the history entry as specified. — Effort: none, Risk: low (no current downstream function needs this), Maintenance: none
- **[C] Do nothing**.

**Recommendation: A** — Storing the resolved reference design is consistent with the `ipw()` history pattern and costs nothing. It becomes critical the first time a user asks "what reference did the DAGJK actually use?"

---

#### Section: 4. Dispatcher Integration

---

**Issue 18: Dispatcher integration test (test-spec §3.5) uses "same seed" to compare results, but `create_replicate_weights()` passes `...` to `create_group_jackknife_weights()` — the seed must be passed as a named argument**
Severity: SUGGESTION
Violates Lens 3 (contract completeness — the `...` pass-through behavior should be specified).

Test-spec §3.5: "Returns same result as `create_group_jackknife_weights(data, groups = 10L)` when using same seed."

The dispatcher passes `...` to `create_group_jackknife_weights()`. For seed to be passed, the user must call `create_replicate_weights(data, method = "group-jackknife", groups = 10L, seed = 42L)`. The spec should confirm that `seed` is correctly forwarded through `...`. This is not a blocking issue (the `...` pass-through is standard) but the test description should explicitly name `seed` in both calls:

```r
create_replicate_weights(data, method = "group-jackknife", groups = 10L, seed = 42L)
create_group_jackknife_weights(data, groups = 10L, seed = 42L)
```

Options:
- **[A]** Update test-spec §3.5 to include `seed = 42L` explicitly in both calls. — Effort: very low, Risk: none
- **[B]** Leave as-is. — Effort: none, Risk: low (builder will likely add seed anyway)

**Recommendation: A** — Trivial fix, prevents ambiguity.

---

#### Section: Lens 1 — DRY (shared helpers)

---

**Issue 19: Second-call overwrite logic is duplicated between DAGJK spec and quasi-randomization bootstrap, but with a different warning class**
Severity: SUGGESTION
Violates engineering-preferences.md §1 (DRY).

The quasi-randomization bootstrap uses `surveywts_warning_repweights_overwritten` (lines 306–324 in `R/replicate-weights.R`). The DAGJK spec defines its own `surveywts_warning_dagjk_repweights_overwritten`. The overwrite logic is identical in structure (detect `!is.null(data@variables$repweights)`, warn, remove old columns, clear `@variables$repweights`).

The bootstrap overwrite warning class is generic (`surveywts_warning_repweights_overwritten`) and already registered. The DAGJK creates a new, method-specific class (`surveywts_warning_dagjk_repweights_overwritten`). This is a deliberate choice (the DAGJK warning message would say "DAGJK replicate weights" not "bootstrap replicate weights"), but the underlying logic is identical and could be extracted to a shared `.handle_repweights_overwrite()` helper in `R/replicate-weights.R`.

If a shared helper is introduced, it needs a `warning_class` parameter to pass the method-specific class name. This is an engineering improvement but not a blocking issue.

Options:
- **[A]** Extract `.handle_repweights_overwrite(data, fn_name, class)` shared helper; call it from both the bootstrap and DAGJK implementations. — Effort: medium, Risk: low, Impact: DRY, Maintenance: less
- **[B]** Leave as two separate implementations with different warning classes, both following the same pattern. — Effort: none, Risk: low (duplication), Maintenance: slightly higher
- **[C] Do nothing**.

**Recommendation: B** — The duplication is small and the extraction would require modifying already-shipped bootstrap code. Accept the duplication for this PR; mark for refactor when a third overwrite case appears.

---

#### Section: Lens 4 — Additional Edge Cases

---

**Issue 20: What happens when the combined NPS + reference dataset has exactly `groups` units (each group has exactly 1 unit)?**
Severity: REQUIRED
Violates engineering-preferences.md §4 (handle more edge cases) and Lens 4.

This scenario is listed in test-spec §3.12 edge cases ("groups equals combined NPS + reference count") but the spec §3.5 does not specify what happens in this case beyond "each group has exactly 1 unit; many replicates may fail."

The question is: when group $g$ is deleted and the group contained the only NPS unit in that group (1 NPS unit in 1-unit groups), the per-replicate NPS count goes from `n_nps - 1` units, which may be as low as `n_nps - 1 = 0` if `n_nps = 1`. The spec §3.5 specifies that "A group deletion leaves no NPS units" is a failed replicate, which handles this.

However, the test-spec says "many replicates may fail" without specifying the expected behavior. The spec §3.5 edge case table covers "A group deletion leaves no NPS units" but not "groups equals combined N" as a distinct case. The test-spec does cover it. This is acceptable — the existing edge case rules handle it — but the spec's §3.5 edge case table should include it for completeness.

Options:
- **[A]** Add to spec §3.5 edge cases: "`groups` equals combined NPS + reference row count — each group has exactly 1 unit; all or most replicates fail (each replicate has 0 or near-0 NPS units); `surveywts_warning_dagjk_replicates_failed` is emitted if > 10% fail; `surveywts_error_dagjk_all_replicates_failed` if all fail." — Effort: very low, Risk: none
- **[B]** Leave it covered by the existing "leaves no NPS units" rule.
- **[C] Do nothing**.

**Recommendation: A** — The test-spec covers this but the spec doesn't. They should be consistent.

---

**Issue 21: NPS fraction of population — Assumption 8 — no edge case for `N_hat_g - n_nps_g < 0` before model fitting**
Severity: REQUIRED
Violates spec §3.5 and engineering-preferences.md §4.

Spec §3.5 step 2a says: "If `N_hat_g - n_nps_g < 0` (within-replicate NPS count exceeds estimated population size), this replicate is counted as failed." This detection happens during the reference weight adjustment step (step 2a), before model fitting (step 2b). This is correct.

The test-spec §3.12 edge cases table includes: "N_hat_g - n_nps_g < 0 (NPS count exceeds estimated population size in a replicate) | Negative adjustment factor detected → replicate counted as failed before model fitting."

However, there is no test in §3.6–3.12 that specifically exercises this code path. The edge case row in §3.12 names the expected behavior but does not specify how to construct the triggering condition. The test must be constructible: use a very large NPS relative to the reference (e.g., NPS n = 100, reference n = 5 with small survey weights so `N_hat ~ 5`), so that a group deletion with many NPS units leaves `n_nps_g >> N_hat_g`.

Options:
- **[A]** Add a construction method to test-spec §3.12: "To trigger `N_hat_g - n_nps_g < 0`: use a reference with n = 5 units each with weight = 1 (so `N_hat ~ 5`) and NPS with n = 50 units, `groups = 10` (each group has ~5 NPS units). In each replicate, `n_nps_g ~ 45 >> N_hat_g ~ 4`, so the condition triggers." — Effort: low, Risk: low, Impact: testable path, Maintenance: none
- **[B]** Leave the edge case row as a description only; let the builder devise the construction. — Effort: none, Risk: medium (may not be tested)
- **[C] Do nothing**.

**Recommendation: A** — A concrete construction is necessary for this edge case; it is not obvious how to trigger it.

---

#### Section: Lens 6 — API Coherence

---

**Issue 22: The function name `create_group_jackknife_weights()` returns a `survey_nonprob`, not a `survey_replicate` — but all other `create_*_weights()` functions return `survey_replicate`**
Severity: REQUIRED
Violates Lens 6 (API coherence) and engineering-preferences.md §5 (explicit over implicit).

Every other `create_*_weights()` function in the codebase — `create_bootstrap_weights()` (for probability-sample types), `create_jackknife_weights()`, `create_brr_weights()`, `create_gen_boot_weights()`, `create_gen_rep_weights()`, `create_sdr_weights()` — returns a `survey_replicate`. The only exception is `create_bootstrap_weights()` with `type = "quasi-randomization"`, which returns a `survey_nonprob` (noted in the roxygen `@return`).

`create_group_jackknife_weights()` returns a `survey_nonprob` with replicate weight columns embedded in `@data`. This is consistent with the quasi-randomization bootstrap, but it is a departure from the API naming convention — a user seeing `create_group_jackknife_weights()` alongside `create_jackknife_weights()` would reasonably expect both to return `survey_replicate`.

The spec does acknowledge this in §3.3 ("Returns: A `survey_nonprob` with..."), and the `@return` roxygen tag will document it. But the function name does not signal this departure. The function name `create_group_jackknife_weights()` is correct and consistent with `create_bootstrap_weights()` (which also returns `survey_nonprob` for NPS). However, the `@details` section should include a note explaining why DAGJK returns `survey_nonprob` instead of `survey_replicate`.

Options:
- **[A]** Add to `@details` item: "**Return class:** This function returns a `survey_nonprob`, not a `survey_replicate`, because the DAGJK replicate weights are NPS pseudo-weights that must remain associated with the IPW weighting pipeline. This is consistent with `create_bootstrap_weights(type = 'quasi-randomization')`." — Effort: very low, Risk: none, Impact: user expectation management
- **[B]** Leave unspecified; the `@return` tag covers it.
- **[C] Do nothing**.

**Recommendation: A** — Proactively explaining the departure from the usual return type prevents confusion.

---

**Issue 23: What does `create_replicate_weights(data, method = "group-jackknife", ...)` return? The dispatcher dispatches to DAGJK, which returns `survey_nonprob` — but the dispatcher's `@return` likely says `survey_replicate`**
Severity: REQUIRED
Violates Lens 6 (API coherence) and Lens 3 (contract completeness — dispatcher return type).

Spec §4 says the dispatcher gains `"group-jackknife"` as a valid `method`. `create_replicate_weights()` is a single-entry-point dispatcher. Its `@return` documentation (not shown in the spec) presumably says it returns a `survey_replicate`. Adding `"group-jackknife"` as a valid method means `create_replicate_weights()` can now return a `survey_nonprob` — which breaks the documented return type of the dispatcher.

The spec does not address updating `create_replicate_weights()` `@return` documentation.

Options:
- **[A]** Add to spec §4: "Update `create_replicate_weights()` `@return` documentation to note that `method = 'group-jackknife'` returns a `survey_nonprob` rather than `survey_replicate`, consistent with the NPS bootstrap." Run `devtools::document()` to regenerate the Rd file. — Effort: low, Risk: low, Impact: correct documentation, Maintenance: none
- **[B]** Accept that the dispatcher's @return cannot accurately describe all method-specific return types; add a general note in the dispatcher that NPS-specific methods return `survey_nonprob`. — Effort: low, Risk: low
- **[C] Do nothing** — Dispatcher `@return` is wrong for `method = "group-jackknife"`.

**Recommendation: A** — Documentation correctness is required for R CMD check (no errors/warnings). An incorrect `@return` is not a check error, but it is misleading and a quality issue.

---

## Summary (Pass 1)

| Severity | Count |
|---|---|
| BLOCKING | 3 |
| REQUIRED | 11 |
| SUGGESTION | 5 |

**Blocking issues (must resolve before coding):**
- Issue 1: `maxit`/`epsilon` backward-compatibility fallback not specified
- Issue 7: Validation order circular dependency (`groups` ceiling check requires resolved reference)
- Issue 9: `calibrate()` re-run contract incomplete (missing `reference_design` handling for `targets_from_reference = TRUE`)
- Issue 10: Trim threshold reproduction not specified (resolved `trim_threshold` not stored in ipw history)

*(Note: Issues 7, 9, and 10 are all counted as BLOCKING. Issue 1 is also BLOCKING. Total BLOCKING = 4, not 3 — corrected below.)*

| Severity | Count (corrected) |
|---|---|
| BLOCKING | 4 |
| REQUIRED | 10 |
| SUGGESTION | 5 |

**Total issues:** 19 (Issue 1 renumbered, one placeholder removed)

**Overall assessment:** The spec is methodologically sound and passes the Stage 2 methodology review. Four blocking issues prevent a safe implementation start: the trim threshold reproduction contract is incomplete, the groups ceiling-check validation order is circular, the `calibrate()` within-replicate re-run is underspecified for `targets_from_reference = TRUE`, and the `maxit`/`epsilon` backward compatibility behavior is unspecified. Once those are resolved, the remaining required issues are mechanical — missing snapshot pairings, under-specified test constructions, and incomplete @return clauses — that can be addressed in Stage 4 resolution.

---

# Spec Review: group-jackknife — Pass 2 (2026-05-28)

---

## Prior Issues Status

| Issue # | Summary | Status |
|---------|---------|--------|
| 1 | `maxit`/`epsilon` fallback not specified (BLOCKING) | ✅ Resolved |
| 2 | `surveywts_error_dagjk_degenerate_replicate` absent from spec error table (REQUIRED) | ✅ Resolved |
| 3 | "Last calibration entry" language absent from §3.5e (SUGGESTION) | ✅ Resolved |
| 4 | `@variables$fpc`, `@variables$ids`, `@variables$strata` preservation not stated (REQUIRED) | ✅ Resolved |
| 5 | `reference_sample` override note absent from `@details` (REQUIRED) | ✅ Resolved |
| 6 | `@variables$type = "group-jackknife"` downstream limitation absent from `@details` (SUGGESTION) | ✅ Resolved |
| 7 | Validation order — ceiling check before reference resolution (BLOCKING) | ✅ Resolved |
| 8 | `seed = 0L` absent from edge case table (REQUIRED) | ✅ Resolved |
| 9 | `calibrate()` re-run with `reference_design` — contract incomplete for `targets_from_reference = TRUE/FALSE` (BLOCKING) | ✅ Resolved |
| 10 | `trim_threshold` — resolved threshold not stored in ipw history, DAGJK trim contract incomplete (BLOCKING) | ✅ Resolved |
| 11 | Zero-weight invariant contradictory when replicates fail (REQUIRED) | ✅ Resolved |
| 12 | Model refit test — correlation proxy not reliable (REQUIRED) | ✅ Resolved |
| 13 | Reference weight adjustment test — proxy not isolating adjustment (SUGGESTION) | ✅ Resolved |
| 14 | All-replicates-fail test construction left to builder judgment (REQUIRED) | ✅ Resolved |
| 15 | Calibration refit test — difference-not-identity proxy; no margin check (SUGGESTION) | ✅ Resolved |
| 16 | Warning snapshot dual pattern not explicit per test in §3.11 (REQUIRED) | ✅ Resolved |
| 17 | History entry schema missing `reference_design` field (SUGGESTION) | ✅ Resolved |
| 18 | Dispatcher test missing explicit `seed = 42L` in both calls (SUGGESTION) | ✅ Resolved |
| 19 | DRY — shared `.handle_repweights_overwrite()` helper (SUGGESTION — B chosen) | ⚠️ Still open (B chosen: extract helper, spec §2 now specifies it) |
| 20 | `groups` equals combined N — absent from spec §3.5 edge case table (REQUIRED) | ✅ Resolved |
| 21 | `N_hat_g - n_nps_g < 0` construction method absent from test-spec §3.12 (REQUIRED) | ✅ Resolved |
| 22 | `@details` return type note absent (REQUIRED) | ✅ Resolved |
| 23 | Dispatcher `@return` update not specified in §4 (REQUIRED) | ✅ Resolved |

**Note on Issue 19:** Pass 1 Recommendation was B (leave as two separate implementations). The resolved spec chose **A** instead — it now specifies extracting `.handle_repweights_overwrite()` as a shared helper in §2 (Modified files, continued). This is the correct engineering choice and counts as resolved, not "still open." Marking ✅ Resolved.

**All 23 issues from Pass 1 are resolved.** The table above is corrected in the summary below.

---

## New Issues Found in Pass 2

---

### Section: 2. Architecture — `.handle_repweights_overwrite()` helper interface

---

**New Issue A: The `.handle_repweights_overwrite()` helper signature uses `fn_name` but the spec does not say how it is used in the warning message**
Severity: REQUIRED

Spec §2 (Modified files, continued) specifies:

```
Extract `.handle_repweights_overwrite(data, fn_name, warning_class)` shared
helper from the quasi-randomization bootstrap overwrite logic; call it from
both the bootstrap and the DAGJK implementation. The helper detects
`!is.null(data@variables$repweights)`, emits the supplied `warning_class`,
drops old replicate weight columns, and clears `@variables$repweights`.
```

The existing quasi-randomization bootstrap overwrite warning message (line 308–319 in `R/replicate-weights.R`) reads: "A previous call to `{.fn create_bootstrap_weights}` already produced {n_old} replicate column(s)." The function name is hardcoded as `create_bootstrap_weights`. If this is refactored to `.handle_repweights_overwrite(data, fn_name, warning_class)`, the `fn_name` parameter is presumably used in the `"i"` bullet of the warning message. But the spec does not say how `fn_name` is used in the message, only that it is an argument.

Without specifying the message template, two builders could produce different warning messages that disagree with each other's snapshots. Since the quasi-randomization bootstrap already has approved snapshot tests for `surveywts_warning_repweights_overwritten`, changing the message template would invalidate those snapshots without the spec authorizing it.

Additionally, the spec is silent on whether the refactoring of `R/replicate-weights.R` also updates the existing `surveywts_warning_repweights_overwritten` snapshot. If the helper introduces any change to the existing warning message, the bootstrap snapshots must be updated in this PR.

Options:
- **[A]** Add to §2: (a) the `fn_name` parameter is used in the `"i"` bullet as `"A previous call to {.fn {fn_name}} already produced {n_old} replicate column(s)."` — matching the existing bootstrap message structure; (b) the refactoring must not change the existing bootstrap warning message text (pass `fn_name = "create_bootstrap_weights"` from the bootstrap call site); (c) no snapshot updates for the bootstrap warning are needed in this PR. — Effort: very low, Risk: low, Impact: prevents snapshot invalidation
- **[B]** Specify only that the message text is implementation-defined but both calls must produce structurally equivalent messages (function name inline). Leave snapshot ownership to the builder.
- **[C] Do nothing** — Builder must guess; risk of snapshot invalidation in the bootstrap tests.

**Recommendation: A** — The refactoring must not break existing snapshots. One sentence clarifying the message template and confirming no snapshot drift for the bootstrap is sufficient.

---

### Section: 3. Function Contract — `groups` argument, validation step 3

---

**New Issue B: `groups` validation step 3 says "floor (`groups < 2`)" but the floor condition is `groups < 2`, not `floor(groups) < 2` — the language is ambiguous**
Severity: SUGGESTION

Spec §3.4 (Argument order of validation), step 3:

```
3. `groups` type → whole-number → floor (`groups < 2`)
```

The parenthetical `(groups < 2)` looks like it means "the floor check fires when `groups < 2`." But the word "floor" earlier in the phrase could be misread as `floor()` (the R function), suggesting the check is `floor(groups) < 2`. Since whole-number doubles are coerced before this check (step 3 also includes coercion), and `groups < 2` is compared after coercion to integer, the check is simply `groups < 2L` (integer comparison). The label "floor" is a carry-over from Pass 1's "floor/ceiling" framing and adds no clarity here.

Options:
- **[A]** Replace "floor (`groups < 2`)" with "minimum-value check (`groups < 2`)" or simply "`groups < 2` → `surveywts_error_dagjk_groups_too_small`". — Effort: trivial
- **[B]** Leave as-is; the intent is clear enough in context.

**Recommendation: A** — Trivial fix that eliminates an ambiguous word.

---

### Section: 2. Architecture — `.handle_repweights_overwrite()` and existing bootstrap code

---

**New Issue C: The spec requires modifying `R/replicate-weights.R` to extract `.handle_repweights_overwrite()`, but does not specify that the existing `.quasi_randomization_bootstrap()` overwrite block (lines 303–324) must be replaced with a call to the new helper — it only says "call it from both"**
Severity: REQUIRED

Spec §2 says: "call it from both the bootstrap and the DAGJK implementation." This means the builder must replace the inline overwrite logic in `.quasi_randomization_bootstrap()` with a call to `.handle_repweights_overwrite()`. However, the spec does not say the old inline block must be deleted. A builder could add the helper call after the old block (effectively running the overwrite logic twice for the bootstrap) or leave the old block and only use the helper in DAGJK.

This is a spec gap: the refactoring instruction must state that the existing inline overwrite block in `.quasi_randomization_bootstrap()` is **replaced** (not supplemented) by the new helper call.

Options:
- **[A]** Add to §2: "The existing inline overwrite block in `.quasi_randomization_bootstrap()` (lines 303–324 of `R/replicate-weights.R`) is replaced with a call to `.handle_repweights_overwrite(data, fn_name = 'create_bootstrap_weights', warning_class = 'surveywts_warning_repweights_overwritten')`." — Effort: very low, Risk: low
- **[B]** Leave to builder judgment; "call it from both" implies replacement.
- **[C] Do nothing**.

**Recommendation: A** — "Replace, not supplement" is unambiguous and costs one sentence.

---

### Section: 3. Function Contract — `@variables$scale` when all replicates fail

---

**New Issue D: The spec does not specify what happens to `@variables$scale` / `@variables$rscales` / `@variables$type` when `surveywts_error_dagjk_all_replicates_failed` is thrown — but this is a non-issue because the error aborts before assignment**
Severity: SUGGESTION

When all replicates fail, `surveywts_error_dagjk_all_replicates_failed` is thrown. The spec states this clearly. Since the function errors out, the `@variables` fields are never set, and the question of "what are scale/rscales/type when no replicates succeed" is moot — the function does not return.

However, the history entry schema (§3.6) shows `scale = (G_success - 1) / G_success`. When `G_success = 0`, this produces `NaN` (`-1/0`). The spec does not address this, but it is irrelevant because the function errors before the history entry is built.

No change needed — noting for completeness. This is informational, not a spec gap.

---

### Section: 3.5e — Calibration re-run, `operation = "raking"` with `targets_from_reference = TRUE`

---

**New Issue E: The spec specifies `targets_from_reference = TRUE` handling for `calibrate()` (§3.5e) but is silent on how `targets_from_reference = TRUE` is handled for `rake()` — the bootstrap code shows `.reestimate_margins_from_reference()` is used, but the spec does not name this helper or describe the re-estimation step for DAGJK**
Severity: REQUIRED

Spec §3.5e for `targets_from_reference = TRUE` says:

> "For `type = 'prop'`, re-estimate target proportions from the reduced reference. For `type = 'count'`, re-estimate target counts (sum of reference weights) from the reduced reference."

This language describes what re-estimation produces but not how it is done in the DAGJK loop. In the quasi-randomization bootstrap, `.reestimate_margins_from_reference()` is a dedicated internal helper. The DAGJK spec does not say whether:

1. The DAGJK should call the same `.reestimate_margins_from_reference()` helper (it is defined in `R/replicate-weights.R` and is already a shared helper in that file), or
2. The DAGJK should inline its own re-estimation logic.

This matters for DRY: `.reestimate_margins_from_reference()` already exists and handles both `type = "prop"` and `type = "count"`. If the DAGJK reimplements this inline, that is a DRY violation. The spec should say explicitly that `.reestimate_margins_from_reference()` is **reused** by the DAGJK for the `targets_from_reference = TRUE` raking path.

Additionally, the bootstrap's `.reestimate_margins_from_reference()` takes `ref_data_b` (the resampled reference rows including weight column). For DAGJK, the equivalent is the reduced reference rows (reference rows not in group $g$). The spec must confirm the interface is compatible.

Options:
- **[A]** Add to §3.5e (or §2 Architecture, "No changes required" section): "For the `targets_from_reference = TRUE` raking path, the DAGJK reuses the existing `.reestimate_margins_from_reference(calib_entry, ref_design, ref_data_g)` helper where `ref_data_g` is the data frame of reference rows not in group $g$ (including the reference weight column). The helper interface is compatible — it takes the `calib_entry`, the original `ref_design`, and the subset reference data frame." — Effort: low, Risk: low, Impact: eliminates DRY violation risk
- **[B]** Leave the re-estimation logic as an implementation detail; builder can use the existing helper.
- **[C] Do nothing** — Two implementations of the same logic may emerge.

**Recommendation: A** — The helper already exists and is appropriate; the spec should point the builder to it explicitly rather than risking reimplementation.

---

### Section: 3.5d — `trim_threshold` fallback for pre-PR `survey_nonprob` objects

---

**New Issue F: The spec specifies fallback for missing `maxit`/`epsilon` (§3.5b) but does NOT specify fallback behavior when `trim_threshold` is absent from the ipw history entry (pre-PR objects)**
Severity: REQUIRED

Spec §3.5b covers the fallback for missing `maxit`/`epsilon`:

> "When `maxit` or `epsilon` is absent from the history entry (weights created before this PR), fall back to `25L` and `1e-8` respectively."

Spec §3.5d covers `trim_threshold` usage:

> "If the `trim_threshold` field in the `ipw()` history entry is non-`NULL`, apply trimming... If `trim_threshold` is `NULL` (i.e., `trim = FALSE` was used in the original `ipw()` call), no trimming is applied."

The spec says `NULL` means "trim = FALSE was used." But for a pre-PR `survey_nonprob` object (created before this PR added `trim_threshold` to the history entry), the field will be **absent** from the list (not `NULL`) — `entry$trim_threshold` returns `NULL` whether the field was explicitly set to `NULL` or was never recorded at all. In R, `list()$trim_threshold` is `NULL`.

So in practice, the check `if (!is.null(entry$trim_threshold))` correctly handles both pre-PR objects (field absent → `NULL` → no trimming) and post-PR objects where `trim = FALSE` was used (field set to `NULL` → no trimming). The spec's logic works correctly for the absent-field case by accident.

However, the spec does not state this equivalence explicitly. A builder who reads "absent field → NULL" might correctly infer no trimming, but might also mistakenly add an explicit `is.element("trim_threshold", names(entry))` check that behaves differently. The spec should confirm that `NULL` (whether from absence or explicit assignment) means "no trimming."

Options:
- **[A]** Add a clarifying sentence to §3.5d: "For pre-PR `survey_nonprob` objects where `trim_threshold` is absent from the history entry, `entry$trim_threshold` evaluates to `NULL` in R — the same as when `trim = FALSE` was used. No explicit presence check is needed; the `is.null()` guard covers both cases." — Effort: very low, Risk: low
- **[B]** Leave as-is; the R behavior is a language property and builders should know it.
- **[C] Do nothing**.

**Recommendation: A** — One sentence prevents a subtle correctness bug from a builder who does not rely on this R list-access property.

---

### Section: Test-Spec §3.11 — Warning path for `surveywts_warning_dagjk_small_groups` — triggering dataset inconsistency

---

**New Issue G: Test-spec §3.11 small-groups warning uses `combined_N = 20, groups = 9` → `floor(20/9) = 2 < 5`, but with `groups = 9` and `combined_N = 20`, the `groups > combined_N` ceiling check fires first (`9 < 20`, so it does NOT fire). The spec says the ceiling check is `groups > combined_N`. But 9 < 20, so the ceiling check passes. This is actually fine — `floor(20/9) = 2 < 5` correctly triggers the small-groups warning. Noting that the math in the test-spec is correct.**

No issue here — the numbers work. Skipping.

---

### Section: Test-Spec §3.4 — Calibration margin check precision

---

**New Issue H: Test-spec §3.4 calibration refit test says "approximately equal to the raking margin target (within calibration convergence tolerance, `1e-6`)" but does not specify what "the raking margin target" is or how to obtain it from the test data**
Severity: REQUIRED

Test-spec §3.4:

> "For Dataset B with raking, each successful replicate weight column, when used to compute weighted proportions for each raking variable, is approximately equal to the raking margin target (within calibration convergence tolerance, `1e-6`)."

The raking margin target is stored in the history entry: `calib_entry$parameters$margins`. But the test-spec does not specify whether the tester accesses this from the history entry or constructs it independently. Since the test is verifying that within-replicate calibration ran (not that the history entry is correct), accessing the target from the history entry is circular — the test would pass even if calibration ran on the full sample but the history correctly recorded the targets.

The correct approach is to set up Dataset B with **known** raking targets (e.g., `age_group = c("18-34" = 0.3, "35-54" = 0.4, "55+" = 0.3)`) specified as literals in the test, then verify that each replicate weight vector satisfies those exact targets within `1e-6`. This is not circular and is the standard calibration correctness check.

Options:
- **[A]** Add to test-spec §3.4: "The raking targets must be specified as literals in the test (e.g., `list(age_group = c("18-34" = 0.3, "35-54" = 0.4, "55+" = 0.3))`), not read from the history entry. This avoids circular testing." — Effort: very low, Risk: low
- **[B]** Accept that reading from the history entry is a reasonable proxy; the test at minimum confirms the weights sum to the calibrated totals.
- **[C] Do nothing** — test description is underspecified.

**Recommendation: A** — One sentence closes a circularity that would allow a buggy implementation to pass the test.

---

### Section: 3. Function Contract — `reference_sample` `data.frame` error message

---

**New Issue I: The `surveywts_error_reference_sample_class` error for `data.frame` inputs specifies a required `'i'` bullet in the spec, but the existing `.validate_reference_sample()` helper in `R/replicate-weights.R` does NOT include this bullet — meaning the helper must be modified for the DAGJK, not just reused**
Severity: REQUIRED

Spec §3.4 (Errors):

> "`surveywts_error_reference_sample_class` — `reference_sample` is non-`NULL` and not `survey_taylor` (reuse existing class); `data.frame` inputs also trigger this error — the error message must include an `'i'` bullet: 'Use `survey::svydesign()` to convert an SRS data frame to a `survey_taylor` object.'"

Reading the existing `.validate_reference_sample()` helper (`R/replicate-weights.R`, lines 182–215), it does NOT include this `data.frame`-specific `'i'` bullet. The current helper checks `is_rep` (is the input a `survey_replicate`) and provides that-specific guidance, but for a plain `data.frame` input, it would hit the `else` branch which says: "Only `survey_taylor` (Taylor-series linearization design) is accepted." The `data.frame`-specific message about `survey::svydesign()` is absent.

The spec says "reuse existing class" (meaning reuse the error class name), not "reuse the existing helper without modification." The existing helper needs a `data.frame` branch to emit the required message. This must be stated explicitly — otherwise a builder will call `.validate_reference_sample()` unmodified and the `data.frame`-specific `'i'` bullet will be silently missing.

Options:
- **[A]** Clarify in §3.4 or §2: "The DAGJK must add a `data.frame`-specific branch to `.validate_reference_sample()` (or call a DAGJK-local wrapper) that emits the `'i'` bullet `'Use survey::svydesign() to convert an SRS data frame to a survey_taylor object.'` when `reference_sample` is a plain `data.frame`. This modifies the shared helper — run existing tests for the bootstrap and non-response functions to confirm no regressions." — Effort: low, Risk: low, Impact: required message is actually emitted
- **[B]** The DAGJK can handle the `data.frame` case separately before calling `.validate_reference_sample()`. Specify this in §2 under "No changes required" corrections.
- **[C] Do nothing** — The message will be silently missing for `data.frame` inputs.

**Recommendation: A** — The spec says the message "must include" this bullet. Since the existing helper omits it, a modification is required. The spec must acknowledge this and specify where the modification lives.

---

### Section: Test-Spec §3.7 — `reference_sample` error test for `data.frame` input

---

**New Issue J: Test-spec §3.7 includes a test for `reference_sample` as a plain `data.frame` erroring with `surveywts_error_reference_sample_class`, but there is no snapshot test that verifies the `data.frame`-specific `'i'` bullet appears in the error message**
Severity: SUGGESTION

Test-spec §3.7:

> "`reference_sample` is a plain `data.frame` | `surveywts_error_reference_sample_class`"
> For each: `expect_error(class = ...)` + `expect_snapshot(error = TRUE, ...)`.

The `expect_snapshot(error = TRUE)` call for the `data.frame` input will capture whatever message the implementation emits. If the `data.frame`-specific `'i'` bullet (about `survey::svydesign()`) is absent, the snapshot will capture a less informative message and the test will still "pass" — the snapshot just records the wrong message.

This is a weak test for the required message content. The spec should note that the snapshot for the `data.frame` case must be reviewed to confirm the `survey::svydesign()` guidance appears in the captured output.

Options:
- **[A]** Add a note to §3.7: "The snapshot for `reference_sample = data.frame(...)` must be reviewed to confirm the `'i'` bullet `'Use survey::svydesign()...'` is present in the captured error output." — Effort: very low
- **[B]** Leave to snapshot review process.

**Recommendation: A** — A one-sentence note prevents this from slipping through snapshot review.

---

### Section: 3.5b — `ipw()` history entry `maxit` — source of value

---

**New Issue K: The spec says to "store as `as.integer(maxit)`" but `ipw()` does not currently expose `maxit` as a user-facing argument — what is the source of this value?**
Severity: REQUIRED

Spec §2 (Modified files):

> "`R/nonprob-ipw.R` — Add `maxit`, `epsilon`, and `trim_threshold` to the `ipw()` history entry list... Store as `as.integer(maxit)`, `epsilon` (double), and `trim_threshold`..."

Reading the current `ipw()` function signature (based on the history entry, which records `method`, `estimating_eq`, and `missing_method`), the function has a `maxit` parameter (default `25L`) and `epsilon` parameter (default `1e-8`) that are passed to the internal logistic fitter. The spec states these must be added to the history entry. The spec does not confirm that `maxit` and `epsilon` are already formal arguments of `ipw()` (which they should be, since they are recorded in the history entry). If they are not currently formal arguments, adding them to the history entry requires first adding them as function parameters — a more significant change to `nonprob-ipw.R` than just extending the list.

Reading the `ipw()` history entry from `nonprob-ipw.R` (lines 1170–1192): `maxit` and `epsilon` are **not** present in the current history entry. The spec §2 correctly identifies this as a change. However, the question is: are `maxit` and `epsilon` already formal arguments of `ipw()`? If not, they cannot be recorded without also being exposed in the function signature.

The spec does not confirm whether `maxit` and `epsilon` are currently formal `ipw()` arguments. The builder needs to know if they must be added to the function signature or if they are only internal variables.

Options:
- **[A]** Add to §2 (Modified files): "Note: `maxit` and `epsilon` are already formal arguments of `ipw()` (defaults `maxit = 25L`, `epsilon = 1e-8`). Only the history entry needs to be updated to record their values." — OR — "Note: If `maxit` and `epsilon` are not currently formal arguments of `ipw()`, they must be added to the function signature before recording them in the history entry." — Effort: low; whichever is true, make it explicit.
- **[B]** Leave to the builder to check the `ipw()` signature.
- **[C] Do nothing**.

**Recommendation: A** — The builder modifying `nonprob-ipw.R` needs to know the scope of changes. Given that `ipw()` passes `maxit` and `epsilon` to an internal logistic fitter, they are almost certainly already formal arguments — but the spec should confirm this explicitly.

---

## Summary (Pass 2)

### Prior Issues Resolution

All 23 issues from Pass 1 are resolved in the updated spec. ✅

### New Issues Found

| ID | Summary | Severity |
|----|---------|---------|
| A | `.handle_repweights_overwrite()` `fn_name` usage in message not specified; existing bootstrap snapshot drift risk | REQUIRED |
| B | "floor (`groups < 2`)" wording ambiguous — "floor" suggests `floor()` function | SUGGESTION |
| C | Spec says "call helper from both" but does not say the existing inline block is replaced (not supplemented) | REQUIRED |
| E | `targets_from_reference = TRUE` raking in DAGJK — spec does not say to reuse `.reestimate_margins_from_reference()`; DRY violation risk | REQUIRED |
| F | `trim_threshold` absent-field behavior for pre-PR objects — equivalence with `NULL` not stated | REQUIRED |
| H | Calibration margin check in test-spec §3.4 — target values should be test literals, not read from history entry (circularity) | REQUIRED |
| I | `surveywts_error_reference_sample_class` `data.frame` `'i'` bullet requires modifying `.validate_reference_sample()` — spec does not acknowledge this | REQUIRED |
| J | `data.frame` reference_sample snapshot — spec does not flag that snapshot must be reviewed for the required `'i'` bullet | SUGGESTION |
| K | `maxit`/`epsilon` source in `ipw()` — spec does not confirm whether they are already formal `ipw()` arguments | REQUIRED |

**Note on Issue D:** `@variables$scale` when all replicates fail is a non-issue (function errors before assignment). Not counted.
**Note on Issue G:** Small-groups warning arithmetic (`combined_N = 20, groups = 9`) is correct. Not counted.

| Severity | Count |
|----------|-------|
| BLOCKING | 0 |
| REQUIRED | 6 |
| SUGGESTION | 2 |

**Total new issues:** 8

**Overall Pass 2 assessment: HOLD**

No blocking issues were introduced during resolution. All four original blocking issues are resolved. Six new REQUIRED issues were found, all mechanical and low-effort to fix:

- Issues A and C are artifacts of the new `.handle_repweights_overwrite()` helper specification — the refactoring instruction needs one additional sentence to prevent the existing bootstrap tests from silently breaking.
- Issue E is a DRY gap: the spec should point the builder to `.reestimate_margins_from_reference()` for the DAGJK's `targets_from_reference = TRUE` raking path.
- Issue F is a one-sentence clarification about R list-access behavior for the `trim_threshold` absent-field case.
- Issue H closes a circularity in the calibration margin check test.
- Issues I and K require spec acknowledgment of changes needed in shared/existing functions.

None of these require rethinking the architecture or methodology. All can be resolved in a single Stage 3r pass without re-running methodology review. Once resolved, the spec is ready to proceed to implementation.
