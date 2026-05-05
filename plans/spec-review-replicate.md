# Spec Review: replicate — Pass 1 (2026-04-18)

### New Issues

#### Section: II — Architecture

**Issue 1: §II.a pseudocode drops the `"replicate_creation"` history entry**
Severity: REQUIRED
Violates spec internal consistency (§II.e, §IX via Q9, §X via Q22).

The pseudocode in §II.a reads:

```r
result@metadata <- data@metadata
result
```

This overwrites the result's metadata with the input's metadata but never
appends the `"replicate_creation"` entry that §II.e and Q9 require.
`as_taylor_design()` and `.snapshot_variables_for_history()` both depend on
that entry existing. An implementer who follows the pseudocode verbatim will
produce a `survey_replicate` with no creation history, silently breaking
round-trip recovery.

Options:
- **[A]** Rewrite the pseudocode to show: copy metadata, append
  `"replicate_creation"` entry with `source_design = .snapshot_variables_for_history(data)`,
  then return. Effort: trivial, Risk: none.
- **[B]** Delete the pseudocode and rely on the §II.e prose.
- **[C] Do nothing** — pseudocode contradicts §II.e and Q9 resolution.

**Recommendation: A** — The pseudocode is load-bearing for implementers;
it must reflect the resolved design.

---

**Issue 2: `surveycore::from_svydesign()` version requirement unstated**
Severity: SUGGESTION
Violates `r-package-conventions.md` §3 minimum version pinning.

§II.a depends on `surveycore::from_svydesign(<svrepdesign>)` producing a
`survey_replicate` with all eight `@variables` keys populated. Confirmed
working on the current installed surveycore. The spec does not name the
minimum `surveycore` version required. §II.c lists only a new `svrep` import;
any existing `surveycore` floor that lacked replicate support would silently
break Phase 1.

Options:
- **[A]** Add a `surveycore (>= X.Y.Z)` bound to §II.c, pinned to the earliest
  version where `from_svydesign()` handles `svrepdesign` input.
- **[B] Do nothing** — rely on downstream breakage to flag a mismatch.

**Recommendation: A** — Pin the floor when the implementer adds svrep.

---

#### Section: III — `create_bootstrap_weights()`

**Issue 3: Error table omits `surveywts_error_replicates_not_whole_number`**
Severity: REQUIRED
Violates §XII (canonical class list) and Q17 resolution.

The argument table for `replicates` says "Numeric whole numbers accepted and
coerced silently; fractional errors (Q17)." §XII lists
`surveywts_error_replicates_not_whole_number` as thrown by "all methods that
accept `replicates`." But §III's error table lists only
`surveywts_error_replicates_not_positive`. Same omission in §VI
(`create_gen_boot_weights()`) and §VIII (`create_sdr_weights()`). Only §IV
(jackknife) lists both.

Options:
- **[A]** Add `surveywts_error_replicates_not_whole_number` row to error tables
  in §III, §VI, §VIII. Effort: trivial.
- **[B] Do nothing** — error tables are incomplete; readers miss a real
  runtime error class.

**Recommendation: A**

---

**Issue 4: Output `@variables` contract covers only a subset of the class's keys**
Severity: REQUIRED
Violates `code-style.md §2` (S7 keys always present, value `NULL` when unspecified).

Per Q19, `surveycore::survey_replicate@variables` has eight keys:
`weights`, `repweights`, `type`, `scale`, `rscales`, `fpc`, `fpctype`, `mse`.
§III's output contract specifies `weights`, `repweights`, `type`, `mse` — it
is silent on `scale`, `rscales`, `fpc`, `fpctype`. Same silence in §IV (JK),
§VI (gen-boot), §VII (gen-rep), §VIII (SDR; mentions `scale` but not the
rest). Users cannot answer "does calling `create_bootstrap_weights()` on a
design with `fpc` set preserve that FPC in the output?" from the spec.

Options:
- **[A]** For each `create_*_weights()` section, state what all eight keys
  contain after conversion. Where the backend writes a value
  (e.g., `scale`, `rscales`), say so and cite it. Where the surveywts
  wrapper is responsible (e.g., carrying FPC forward through the round-trip),
  state the rule.
- **[B]** Add a single cross-cutting §II.h table that lists post-conversion
  values for all eight keys across all six methods. Reduces duplication.
- **[C] Do nothing** — leaves implementation choices implicit.

**Recommendation: B** — One table is DRY and easier to audit during review
(Lens 1).

---

#### Section: IV — `create_jackknife_weights()`

**Issue 5: Output contract does not specify `rscales` for stratified delete-1**
Severity: REQUIRED
Methodology review Issue 2 (per-stratum rscales) resolved by delegating to
`survey::as.svrepdesign()`. Phase 1 spec never surfaces the result.

Stratified delete-1 (JKn) writes per-replicate `rscales = (n_h - 1) / n_h`
and `scale = 1`. Unstratified delete-1 (JK1) writes a single scale. This is
a user-visible property of the output; the spec does not state it.

Options:
- **[A]** Add to §IV output contract: "For JKn, `@variables$scale = 1` and
  `@variables$rscales` is a numeric vector of length `n_rep` with
  `(n_h - 1) / n_h` for each replicate's source stratum. For JK1,
  `@variables$scale = (n_rep - 1) / n_rep` and `@variables$rscales = NULL`."
- **[B]** Covered implicitly by Issue 4 resolution (if §II.h table is
  added).
- **[C] Do nothing.**

**Recommendation: B** if Issue 4 is resolved via Option B; otherwise A.

---

#### Section: V — `create_brr_weights()`

**Issue 6: Signature omits `...`, violating Q12 name-only policy**
Severity: BLOCKING
Violates Q12 decision ("Only `data` and `replicates` are positional. All
other arguments are name-only, enforced by placing them after `...`").

```r
create_brr_weights(data, rho = 0, mse = TRUE)    # spec §V
```

BRR has no `replicates` argument (Hadamard sizing is automatic), so per Q12
all args after `data` must be name-only. The current signature allows
`create_brr_weights(design, 0.5, TRUE)` with positional `rho` and `mse` —
contradicting Q12 and inconsistent with §III, §VI, §VIII. Same defect in §VII
(`create_gen_rep_weights()`) — no `...` in its signature either, so
`variance_estimator`, `max_replicates`, `balanced`, `aux_var_names`, `mse`
are all positional-capable.

Options:
- **[A]** Insert `...` after `data` in both signatures:
  `create_brr_weights(data, ..., rho = 0, mse = TRUE)` and
  `create_gen_rep_weights(data, ..., variance_estimator = "SD2", ...)`.
  Effort: trivial. Risk: none (there are no named args before `...` to
  collide with).
- **[B]** Declare BRR and gen-rep exceptions to Q12 (no `replicates`, so
  positional-after-`data` is fine). Must update Q12 decision.
- **[C] Do nothing** — Q12 is silently violated for two of six functions.

**Recommendation: A**

---

**Issue 7: PSU-count-per-stratum validation path not specified**
Severity: REQUIRED
Violates Lens 3 (contract completeness for error triggers).

`surveywts_error_brr_requires_paired_design` fires when "Any stratum has ≠ 2
PSUs, or input is `survey_nonprob`." The spec does not state *where* this
check runs in surveywts (before or after `as_svydesign()`) or how the PSU
count per stratum is computed from a `survey_taylor`. Implementer has to
guess. Path matters because `data@variables$strata`/`$ids` can be NULL
(unclustered), and PSU count computation needs a defined procedure.

Options:
- **[A]** Add to §V a short "Validation" block: "Before `as_svydesign()`,
  compute PSU counts via `data@data` grouped by `data@variables$strata` and
  `data@variables$ids`. If any group has ≠ 2 rows of unique PSU IDs, or if
  either `strata` or `ids` is NULL, throw
  `surveywts_error_brr_requires_paired_design`."
- **[B]** Delegate the PSU check to the survey backend; map the survey
  error to the surveywts class via a `tryCatch`. (Contradicts §II.f which
  says validation happens in surveywts before the backend.)
- **[C] Do nothing.**

**Recommendation: A** — §II.f already commits to pre-backend validation;
spell out how.

---

#### Section: VIII — `create_sdr_weights()`

**Issue 8: NSE resolution of `sort_var = NULL` is under-specified**
Severity: REQUIRED
Violates Lens 3 (contract completeness at boundary values).

§VIII argument description: "Bare name; resolved via
`rlang::as_name(rlang::enquo(sort_var))`. If `NULL`, row order is assumed to
reflect selection order." `rlang::as_name(rlang::enquo(NULL))` returns the
string `"NULL"` (literally), which is not a column name. Implementer needs
the explicit branching rule for `rlang::quo_is_null(rlang::enquo(sort_var))`.

Options:
- **[A]** Rewrite the `sort_var` entry: "Resolved with
  `quo <- rlang::enquo(sort_var); if (rlang::quo_is_null(quo)) NULL else
  rlang::as_name(quo)`. A `NULL` result is passed through to svrep's
  `sort_variable = NULL`."
- **[B] Do nothing** — implementer writes `NULL` literal into svrep and
  surfaces an obscure downstream error.

**Recommendation: A**

---

#### Section: IX — `create_replicate_weights()` (Dispatcher)

**Issue 9: Test plan uses stale method strings for three of six branches**
Severity: REQUIRED
Violates Q12 resolution and §IX signature.

Test block 14 (§XIII):

```
14d. `method = "gen-boot"` dispatches correctly → `survey_replicate`
14e. `method = "gen-rep"` dispatches correctly → `survey_replicate`
14f. `method = "sdr"` dispatches correctly → `survey_replicate`
```

But the dispatcher's `method` argument (§IX + Q12) accepts
`"generalized-bootstrap"`, `"generalized-replicate"`,
`"successive-difference"`. The abbreviations `"gen-boot"`, `"gen-rep"`,
`"sdr"` are invalid; these tests would error via `rlang::arg_match()`.

Options:
- **[A]** Update test plan strings in §XIII to the Q12 canonical names.
- **[B]** Add aliases to the dispatcher (contradicts Q2 — "no aliases").
- **[C] Do nothing** — test plan asserts wrong behavior.

**Recommendation: A**

---

#### Section: X — `as_taylor_design()`

**Issue 10: Behavior on `survey_replicate` whose source was `survey_nonprob` is undefined**
Severity: BLOCKING
Violates Lens 6 (API coherence across accepted input types).

Q4 allows `create_bootstrap_weights(survey_nonprob)` and
`create_jackknife_weights(survey_nonprob, type = "delete-1")` to produce a
`survey_replicate`. Q22 stores the input's `@variables` snapshot in the
history entry. §X says `as_taylor_design()` reads the snapshot and
reconstructs via `surveycore::as_survey()`. `as_survey()` produces a
`survey_taylor`. There is no path in the spec that describes what happens
when the snapshot came from a `survey_nonprob` (no `ids`, no `strata`).

Realistic chained workflow:

```r
np  <- surveycore::as_survey_nonprob(df, weights = w)
rep <- create_bootstrap_weights(np)
tay <- as_taylor_design(rep)   # what does this produce?
```

Four possibilities, none stated:
1. Returns `survey_nonprob` (violates §X return type contract).
2. Returns a `survey_taylor` with no strata/ids (methodologically suspect —
   user gets an SRS Taylor design from a non-probability sample).
3. Errors with `surveywts_error_no_taylor_structure` (spec lists this class,
   but only for "No stored Taylor structure found"; unclear if nonprob
   source qualifies).
4. Errors with a new class.

Options:
- **[A]** Error with `surveywts_error_no_taylor_structure` (or a new class
  like `surveywts_error_taylor_from_nonprob_replicate`). Document in §X and
  add to §XII + test §17. Matches the Q22 principle: when round-trip is
  unsafe, refuse rather than guess. Effort: low.
- **[B]** Return the original `survey_nonprob` (dropping replicate columns).
  Document clearly. Breaks the return-type contract but matches "undo the
  conversion." Would require renaming the function or relaxing §X output
  type from "`survey_taylor`" to "original design class."
- **[C] Do nothing** — implementer improvises.

**Recommendation: A** — Consistent with Q22 conservatism. A non-probability
bootstrap replicate cannot yield a valid Taylor design; refuse explicitly.

---

#### Section: XIII — Testing

**Issue 11: Error-path coverage is incomplete across five of seven functions**
Severity: REQUIRED
Violates `testing-standards.md` §2 ("every typed error class from the
package's error table" has a test) and spec §XV (all error classes in §XII
covered).

Per-function tally of error-class tests in §XIII:

| Function | Error classes in table | Tests in §XIII |
|---|---|---|
| `create_bootstrap_weights()` | 4 | 2 (block 3) + shared block 13 |
| `create_jackknife_weights()` | 7 | 2 (block 5) + shared block 13 |
| `create_brr_weights()` | 5 | 4 (block 8) + shared block 13 |
| `create_gen_boot_weights()` | 5 | 0 explicit + shared block 13 |
| `create_gen_rep_weights()` | 4 | 0 explicit + shared block 13 |
| `create_sdr_weights()` | 5 | 1 (block 12) + shared block 13 |
| `as_taylor_design()` | 5 | 2 (block 17) |

Shared block 13 covers only `surveywts_error_not_survey_design` and
`surveywts_error_already_replicate`. That leaves these classes with no test:

- `surveywts_error_unsupported_class` (all seven functions)
- `surveywts_error_replicates_not_positive` (gen-boot, SDR)
- `surveywts_error_replicates_not_whole_number` (bootstrap, gen-boot, SDR —
  only listed for jackknife; see Issue 3)
- `surveywts_error_variance_estimator_requires_aux` (gen-boot, gen-rep)
- `surveywts_error_replicates_required_for_jkn` test exists but
  `surveywts_error_jackknife_type_unsupported_for_nonprob` does not
- `surveywts_error_brr_requires_paired_design` (only non-paired tested;
  `survey_nonprob` branch also listed but not tested)
- `surveywts_error_taylor_from_calibrated_replicate`

Options:
- **[A]** Expand §XIII so every row in every §III–§X error table has a
  `class=` + snapshot test. Extend shared block 13 to also cover
  `unsupported_class`, `replicates_not_whole_number`, and `replicates_not_positive`
  across all applicable functions. Effort: medium (pure test additions).
- **[B]** Raise the per-function blocks rather than a shared block
  (duplicative; fails Lens 1 DRY).
- **[C] Do nothing** — §XV quality gate is unreachable.

**Recommendation: A**

---

**Issue 12: No numerical-equivalence tests for jackknife, gen-boot, gen-rep, or SDR**
Severity: REQUIRED
Violates §XV ("Equivalence tests against svrep/survey pass (tolerance
`1e-10`)").

§XIII specifies equivalence blocks only for bootstrap (block 2) and BRR
(block 7). Quality gate is stated for all backends. Without equivalence
tests for jackknife / gen-boot / gen-rep / SDR, surveywts's thin-wrapper
contract (§II.a) is unverifiable: a refactor that introduces a subtle
per-replicate arithmetic change would pass all structural tests silently.

Options:
- **[A]** Add one equivalence block per function (fixed seed where
  applicable; tolerance `1e-10`; `skip_if_not_installed("svrep")`). Six
  additional `test_that()` blocks. Effort: low.
- **[B]** Add only for methods with stochastic output (bootstrap, gen-boot,
  SDR, random-groups JK) and rely on structural tests for deterministic
  ones (gen-rep, delete-1 JK, BRR). Still leaves gen-rep equivalence
  unverified.
- **[C] Do nothing** — §XV gate cannot be met.

**Recommendation: A**

---

**Issue 13: No test for `surveywts_error_taylor_from_calibrated_replicate`**
Severity: REQUIRED
Violates §XII + Q22.

§X states `as_taylor_design()` errors with
`surveywts_error_taylor_from_calibrated_replicate` when the replicate's
history records a post-creation weight adjustment. Block 17 covers
`unsupported_class` and `no_taylor_structure`, not this class. Coverage of
Q22's central runtime guard is zero.

Options:
- **[A]** Add block 17c: construct a `survey_replicate`, append a synthetic
  `"calibration"` history entry, assert `as_taylor_design()` fails with
  class + snapshot. Effort: low.
- **[B] Do nothing.**

**Recommendation: A**

---

#### Section: XI/XII/testing — Print method for `survey_replicate`

**Issue 14: Q10 approved a print method but the spec has no section for it**
Severity: REQUIRED
Violates Lens 3 (every class with a `print()` method requires a verbatim
example block).

Q10 decision: "Full print method … shows weight stats, replicate type,
number of replicates, scale factor, and weighting history." Nothing else in
the spec:

- No dedicated section describing the format (no verbatim example output).
- No entry in §II.d source file organization — which file contains the
  `S7::method(print, survey_replicate)` registration?
- No snapshot test in §XIII.
- No `@family` group entry in §XIV for the print method.

Options:
- **[A]** Add a new §X.5 "Print method for `survey_replicate`" with: file
  location (new `R/replicate-print.R` or folded into `replicate-weights.R`),
  verbatim example output, and test block specification. Add a
  corresponding block to §XIII (likely §XIII.18) calling `expect_snapshot(print(obj))`.
  Update §II.d.
- **[B]** Narrow Q10 to "no print method for Phase 1; use surveycore's
  default." Amend the decision. Re-defer to a later phase.
- **[C] Do nothing** — Q10 says yes, spec says nothing, implementer picks.

**Recommendation: A** — Q10 already committed. The spec must close the loop.

---

#### Section: XII — Error and Warning Classes

**Issue 15: `surveywts_warning_delete1_many_replicates` has no trigger spec**
Severity: SUGGESTION
Violates `r-package-conventions.md` (warnings need a defined trigger and test).

§XII lists `surveywts_warning_delete1_many_replicates` with "Delete-1
produces > 500 replicates (proposed threshold)." The word "proposed" is a
tell: the threshold is not decided, and §IV
(`create_jackknife_weights()`) never mentions this warning. No test for it
in §XIII. No roxygen note in the argument tables.

Options:
- **[A]** Decide the threshold, add the trigger to §IV ("If `type =
  "delete-1"` and total PSU count > N, emit
  `surveywts_warning_delete1_many_replicates` before calling the backend"),
  add a test block. Effort: low.
- **[B]** Drop the warning class from §XII — it isn't implemented anywhere.
  Phase 1 ships without it. Effort: trivial.
- **[C] Do nothing** — orphan class sits in §XII.

**Recommendation: B** — Orphan warnings add noise. Lift it later if a user
asks for it.

---

#### Section: XII + I — DRY shared-error documentation

**Issue 16: Three errors are duplicated across six function tables**
Severity: SUGGESTION
Violates `engineering-preferences.md` §1 (DRY — Lens 1).

`surveywts_error_not_survey_design`, `surveywts_error_unsupported_class`,
and `surveywts_error_already_replicate` appear in the error tables for
§III, §IV, §V, §VI, §VII, §VIII — six restatements of the same three rows.
The §I input/output class matrix already names them; §II.f names validation
order. Per-function error tables would be shorter and DRYer if the shared
rows lived in one place (e.g., a §II.h "Shared input-class errors" table)
and per-function tables only listed method-specific errors.

Options:
- **[A]** Extract shared rows into §II.h; each function's error table cites
  "…plus shared input-class errors from §II.h."
- **[B] Do nothing** — readability of per-function tables outweighs the
  duplication.

**Recommendation: A** if Issue 4 is resolved via its Option B (one §II.h
table already being added anyway); otherwise B is acceptable.

---

## Summary (Pass 1)

| Severity | Count |
|---|---|
| BLOCKING | 2 |
| REQUIRED | 11 |
| SUGGESTION | 3 |

**Total issues:** 16

| # | Title | Severity |
|---|---|---|
| 1 | §II.a pseudocode drops `"replicate_creation"` history entry | REQUIRED |
| 2 | `surveycore` minimum version unstated | SUGGESTION |
| 3 | `replicates_not_whole_number` missing from §III/§VI/§VIII error tables | REQUIRED |
| 4 | Output `@variables` contracts cover only a subset of class keys | REQUIRED |
| 5 | JKn `rscales`/`scale` not specified in output contract | REQUIRED |
| 6 | BRR and gen-rep signatures lack `...`, violating Q12 | BLOCKING |
| 7 | BRR PSU-count validation path not specified | REQUIRED |
| 8 | SDR `sort_var = NULL` NSE resolution under-specified | REQUIRED |
| 9 | Dispatcher test plan uses stale method strings | REQUIRED |
| 10 | `as_taylor_design()` on nonprob-sourced replicate undefined | BLOCKING |
| 11 | Error-class test coverage incomplete across five functions | REQUIRED |
| 12 | No numerical-equivalence tests for JK, gen-boot, gen-rep, SDR | REQUIRED |
| 13 | No test for `surveywts_error_taylor_from_calibrated_replicate` | REQUIRED |
| 14 | Print method approved by Q10 but unspecified | REQUIRED |
| 15 | `surveywts_warning_delete1_many_replicates` is orphaned | SUGGESTION |
| 16 | Three shared errors duplicated across six tables | SUGGESTION |

**Overall assessment:** The spec is methodology-locked and the delegation
architecture is sound, but it carries two blocking API-policy gaps
(BRR/gen-rep signatures violate Q12; `as_taylor_design()` on nonprob-sourced
replicates is undefined) and a cluster of REQUIRED contract/test omissions
— most notably output `@variables` coverage, missing error-class tests, and
the entirely absent print-method section. All sixteen issues are local
fixes; none call the architecture into question.

---

## Spec Review: replicate — Pass 2 (2026-04-18)

### Prior Issues (Pass 1)

| # | Title | Status |
|---|---|---|
| 1 | §II.a pseudocode drops `"replicate_creation"` history entry | ✅ Resolved |
| 2 | `surveycore` minimum version unstated | ✅ Resolved |
| 3 | `replicates_not_whole_number` missing from §III/§VI/§VIII error tables | ✅ Resolved |
| 4 | Output `@variables` contracts cover only a subset of class keys | ✅ Resolved (§II.h added) |
| 5 | JKn `rscales`/`scale` not specified in output contract | ✅ Resolved (via §II.h) |
| 6 | BRR and gen-rep signatures lack `...`, violating Q12 | ✅ Resolved |
| 7 | BRR PSU-count validation path not specified | ✅ Resolved (§V Validation block) |
| 8 | SDR `sort_var = NULL` NSE resolution under-specified | ✅ Resolved |
| 9 | Dispatcher test plan uses stale method strings | ✅ Resolved |
| 10 | `as_taylor_design()` on nonprob-sourced replicate undefined | ✅ Resolved (new error class; see Issue 17 below for detection mechanism) |
| 11 | Error-class test coverage incomplete | ✅ Resolved |
| 12 | No numerical-equivalence tests for JK/gen-boot/gen-rep/SDR | ✅ Resolved |
| 13 | No test for `surveywts_error_taylor_from_calibrated_replicate` | ✅ Resolved |
| 14 | Print method approved by Q10 but unspecified | ✅ Resolved (§X.5 added) |
| 15 | `surveywts_warning_delete1_many_replicates` is orphaned | ✅ Resolved (dropped) |
| 16 | Three shared errors duplicated across six tables | ✅ Resolved (§II.i added) |

### New Issues

#### Section: X — `as_taylor_design()`

**Issue 17: Nonprob detection via `ids == NULL && strata == NULL` will false-positive on SRS `survey_taylor`**
Severity: BLOCKING
Violates Lens 6 (API coherence: legitimate workflow silently errors) and
`engineering-preferences.md §5` (explicit over clever).

§X fourth bullet (line 701–708) detects a nonprob-sourced replicate by
inspecting the `source_design` snapshot:

> "most recent `"replicate_creation"` history entry has a `source_design`
> snapshot with `ids = NULL` and `strata = NULL` (i.e., the source was
> `survey_nonprob`)"

The parenthetical equates shape with identity, but a simple-random-sample
`survey_taylor` (unclustered, unstratified) has the same
`@variables$ids == NULL` and `@variables$strata == NULL` shape. That
design is a legitimate input to `create_bootstrap_weights()` /
`create_jackknife_weights()`, and the round-trip

```r
taylor_srs <- surveycore::as_survey(df, weights = w)   # no ids, no strata
rep        <- create_bootstrap_weights(taylor_srs)
back       <- as_taylor_design(rep)   # should succeed, returns srs taylor
```

would instead error with `surveywts_error_taylor_from_nonprob_replicate`.
The detection is shape-based, not identity-based. §XIII block 17d tests
the shape-based condition, cementing the bug into the test plan.

Options:
- **[A]** Replace the shape heuristic with an explicit class tag. Have
  `.snapshot_variables_for_history()` record the source class name (e.g.,
  `source_class = "survey_nonprob"` or the result of
  `S7::S7_class(data)@name`) alongside the `@variables` snapshot. §X
  checks the stored class name rather than the shape. Update §XIII
  block 17d to construct a snapshot with the recorded nonprob class tag.
  Effort: low. Risk: none.
- **[B]** Scope the detection to "source had only `@variables$weights` and
  no other keys" (i.e., a `survey_nonprob`'s @variables schema, not
  survey_taylor's). Effort: low but fragile — depends on surveycore's
  internal schema for `survey_nonprob@variables`.
- **[C] Do nothing** — SRS Taylor round-trip fails with a wrong error class.

**Recommendation: A** — Identity should be stored, not inferred. Also
simplifies §X prose ("snapshot's stored class is `survey_nonprob`") and
makes test setup obvious.

---

#### Section: II.g / VI / VII / VIII — `survey_nonprob` rejection path

**Issue 18: No typed error class specified for `survey_nonprob` passed to gen-boot / gen-rep / SDR**
Severity: REQUIRED
Violates Lens 3 (contract completeness for error triggers) and §II.f
(validation in surveywts before backend).

§II.g states the accepted-input-class policy: bootstrap and delete-1
jackknife accept `survey_nonprob`; all other methods reject it. BRR has
an explicit path (`surveywts_error_brr_requires_paired_design`, §V step 1).
Gen-boot, gen-rep, and SDR have no analogous path.

Gap consequences:
- §II.i's `surveywts_error_unsupported_class` is defined as "not a
  recognized survey class," so it does not apply (`survey_nonprob` is
  recognized).
- Per-function error tables (§VI, §VII, §VIII) do not list any class for
  this condition.
- No test block in §XIII covers it.

An implementer has to choose a class on the fly, violating
`r-package-conventions.md` (every `cli_abort()` has a named class defined
in the spec).

Options:
- **[A]** Add a shared `surveywts_error_nonprob_requires_probability_design`
  (or three method-specific classes) with condition "`data` is
  `survey_nonprob` and method requires probability-design structure."
  Route gen-boot / gen-rep / SDR validation through it as step 1 before
  other method-specific checks. Add row to §XII and tests to §XIII
  blocks 9.E, 10.E, 12. Effort: low.
- **[B]** Extend §II.i `surveywts_error_unsupported_class` to include
  "recognized class not supported by this method." Widens one class to
  cover multiple semantic conditions; weaker user messages.
- **[C] Do nothing** — implementer improvises a class name.

**Recommendation: A** — Matches BRR's pattern (method-specific class
with a message pointing at the right alternative) and closes a real
validation gap.

---

#### Section: XIII — Testing

**Issue 19: Block 17b under-specified — how to construct a replicate without a `"replicate_creation"` history entry**
Severity: SUGGESTION
Violates Lens 3 (contract completeness for test preconditions).

Block 17b asserts that `as_taylor_design()` on "a replicate with no stored
`"replicate_creation"` history entry" fires
`surveywts_error_no_taylor_structure`. But `create_*_weights()` always
appends the entry (§II.a pseudocode, §II.e). The only way to create this
test input is to manually construct a `survey_replicate` with an empty
`@metadata@weighting_history`, bypassing the public API. The spec does
not say which.

This matters because the test is the only defense against a future
refactor that relies on the history entry always being present.

Options:
- **[A]** Add a note: "Construct the test input directly via
  `S7::new_object(surveycore::survey_replicate, …)` with empty
  `weighting_history`, or equivalently strip the entry after creation:
  `rep@metadata@weighting_history <- list()`."
- **[B] Do nothing** — implementer figures it out.

**Recommendation: A** — One sentence eliminates guesswork.

---

**Issue 20: No explicit edge-case tests (0-row input, single-stratum, all-equal weights)**
Severity: SUGGESTION
Violates `testing-standards.md` §2 ("Every exported function must have
tests in... edge cases: boundary conditions, NAs, empty inputs, single-row
inputs") and Lens 4.

§XIII has happy path, equivalence, and error-class coverage. Explicit
edge-case blocks are missing for all six `create_*_weights()` functions:

- 0-row `@data` (`survey_taylor` with empty data frame)
- Single-row / single-PSU / single-stratum inputs
- All-equal base weights (degenerate variance inputs)
- NAs in strata / PSU / fpc columns

Some of these will be caught by the backend and surface as wrapped errors
(Q16); others may silently succeed with methodologically dubious outputs
(e.g., BRR on a single-stratum paired design reduces to trivial).

Options:
- **[A]** Add an "Edge cases" block per function (one `test_that` each)
  covering: 0-row input, single-stratum (where applicable), all-equal
  weights. Document expected behavior: which succeed, which error, which
  warn. Effort: medium (decisions needed per method).
- **[B]** Add a single shared edge-case block in §XIII.13 covering the
  common cases across all methods. Effort: low.
- **[C] Do nothing** — edge cases surface only if a user trips them.

**Recommendation: B** for Phase 1 — the delegation architecture (§II.a)
means backend packages already handle these; Phase 1 mostly needs to
verify surveywts does not mangle them. A single shared block is
sufficient, with per-function edge cases deferred to a later bug-surface
phase if needed.

---

#### Section: XV — Quality Gates

**Issue 21: Coverage gate omits `R/replicate-print.R`**
Severity: SUGGESTION
Violates Lens 1 (consistency between §II.d and §XV).

§II.d now lists three source files (`replicate-weights.R`,
`replicate-dispatch.R`, `replicate-print.R`). §XV says:

> "Test coverage ≥ 98% for `R/replicate-weights.R` and
> `R/replicate-dispatch.R`"

`replicate-print.R` (the S7 `print` method registration) is not included.
Block 18 in §XIII covers it via snapshot tests, so coverage should be
easy to meet — but the gate text does not require it.

Options:
- **[A]** Add `replicate-print.R` to the coverage gate line.
- **[B] Do nothing** — print method coverage is implicitly covered by
  the "all tests passing" gate.

**Recommendation: A** — One-word fix; keeps §XV in sync with §II.d.

---

**Issue 22: Print example renders "N = 1 observations" for single-row input**
Severity: SUGGESTION
Minor cosmetic issue in §X.5 output contract.

Line 757: `"N = {nrow(@data)} observations"`. For the degenerate `nrow = 1`
case, this prints "N = 1 observations" (ungrammatical). Low user
impact — replicate designs with 1 row are nonsensical — but the spec's
verbatim example is an implicit contract that future contributors may
copy.

Options:
- **[A]** Use `cli::pluralize()` / `{cli}` inline markup to handle
  pluralization: `"N = {cli::no({nrow(@data)})} observation{?s}"`.
- **[B] Do nothing** — the case is vanishingly rare.

**Recommendation: B** — not worth the code complexity. Noting for
completeness.

---

## Summary (Pass 2)

| Severity | Count |
|---|---|
| BLOCKING | 1 |
| REQUIRED | 1 |
| SUGGESTION | 4 |

**Total new issues:** 6

| # | Title | Severity |
|---|---|---|
| 17 | Nonprob detection false-positives on SRS `survey_taylor` | BLOCKING |
| 18 | No typed error class for `survey_nonprob` → gen-boot/gen-rep/SDR | REQUIRED |
| 19 | Block 17b test precondition ("no history entry") unspecified | SUGGESTION |
| 20 | No explicit edge-case test blocks (0-row, single-stratum, all-equal) | SUGGESTION |
| 21 | §XV coverage gate omits `R/replicate-print.R` | SUGGESTION |
| 22 | Print example ungrammatical for `N = 1` | SUGGESTION |

**Overall assessment:** Pass 1's sixteen issues all landed cleanly; the
spec is materially stronger at v1.2 (§II.h, §II.i, §X.5, expanded §XIII
error coverage). Pass 2 surfaces one genuine blocker — the nonprob
detection in `as_taylor_design()` will break SRS Taylor round-trip — and
one REQUIRED contract gap (nonprob rejection path for three methods).
The four suggestions are polish. After Issues 17 and 18 are resolved,
the spec is ready for implementation.
