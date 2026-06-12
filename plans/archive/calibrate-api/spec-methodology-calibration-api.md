## Methodology Review: calibration-api — Pass 1 (2026-06-03) — RESOLVED 2026-06-03

**Verdict: PASS** — All REQUIRED issues resolved. Issue 5 (SUGGESTION) closed as pre-existing behavior, out of scope.

| Issue | Resolution |
|-------|-----------|
| 1 — `model`/`method` naming in §III | FIXED — replaced in spec + test-spec |
| 2 — `algorithm`/`method` naming in §IV | FIXED — replaced in spec + test-spec |
| 3 — Cross-marginal N consistency for `type = "count"` | FIXED — validation added to §III, §IV errors/edge-cases + test-spec |
| 4 — `calibrate_poststrat()` missing error for non-`data.frame` targets | FIXED — `surveywts_error_margins_format_invalid` added to §V + test-spec |
| 5 — Taylor SE invalidation note | CLOSED — surveycore's standard Taylor estimator matches the `survey` package path users validated against; g-weight correction is a surveycore architecture decision for a future variance phase, not a gap introduced by this spec |

---

## Original findings (Pass 1)

### New Issues

#### Lens 1 — Method Validity

---

**Issue 1: `calibrate_greg()` warnings and edge cases reference `method` but the argument is `model`**
Severity: REQUIRED
Lens: 1 — Method Validity
Resolution type: UNAMBIGUOUS

The `calibrate_greg()` signature (§III) names the GREG model selection
argument `model = c("linear", "logit")`. Yet the "Warnings" table and the
"Edge cases" table both refer to `method = "linear"` and `method = "logit"`:

- §III Warnings: "**`method = "linear"`** produced one or more negative
  calibrated weights"
- §III Edge cases: "**`method = "logit"`** does not converge" and
  "**`method = "linear"`** produces negative weights"

An implementer reading the spec will correctly name the argument `model`, but
the warnings / edge cases text says `method`. The test-spec inherits the same
error (test-02 error path trigger says `method = "logit"`, warning path says
`method = "linear"`). Every place `method =` appears in the context of
`calibrate_greg()` must be `model =`.

Fix: globally replace `method = "linear"` and `method = "logit"` with
`model = "linear"` and `model = "logit"` everywhere in §III and in the
corresponding test-spec rows.

Options:
- **[A] Apply the replacement in spec + test-spec** — Effort: low, Risk: low,
  Impact: eliminates a documentation inconsistency that will manifest as a
  naming bug in tests, Maintenance: none
- **[B] Do nothing** — The builder names the argument `model` and the tests
  use `model`, but the spec/test-spec text says `method`. This is a silent
  divergence that will confuse anyone reading the spec against the test.

**Recommendation: A** — One-pass text substitution; no design judgment needed.

---

**Issue 2: `calibrate_rake()` errors, warnings, edge cases, and test-spec reference `method` but the argument is `algorithm`**
Severity: REQUIRED
Lens: 1 — Method Validity
Resolution type: UNAMBIGUOUS

The `calibrate_rake()` signature (§IV) names the raking algorithm selector
`algorithm = c("anesrake", "survey")`. However, the following spec locations
all say `method` instead of `algorithm`:

- §IV Errors table: "`cap` is non-`NULL` and **`method = "survey"`**" (for
  `surveywts_error_cap_not_supported_survey`)
- §IV Warnings table: "A `control` key is not applicable to the selected
  **`method`**" (for `surveywts_warning_control_param_ignored`)
- §IV Messages table: "**`method = "anesrake"`** and all variables pass
  chi-square threshold" (for `surveywts_message_already_calibrated`)
- §IV Edge cases: "`cap` non-`NULL` and **`method = "survey"`**"
- test-spec error path trigger: "`cap = 3` with **`method = "survey"`**"
- test-spec warning path triggers: **`method = "survey"`** and
  **`method = "anesrake"`**
- test-spec message path trigger: **`method = "anesrake"`**

This is the same class of error as Issue 1. The old `rake()` used a `method`
argument; the new `calibrate_rake()` renames it to `algorithm`. The rename
was applied to the signature and argument table but not propagated to
errors/warnings/messages/edge-cases sections or the test-spec.

Fix: globally replace `method = "anesrake"` → `algorithm = "anesrake"` and
`method = "survey"` → `algorithm = "survey"` in all `calibrate_rake()`
sections and corresponding test-spec rows.

Options:
- **[A] Apply the replacement in spec + test-spec** — Effort: low, Risk: low,
  Impact: eliminates propagated naming inconsistency, Maintenance: none
- **[B] Revert `algorithm` back to `method`** — Restores old naming; avoids
  the rename entirely. The old `rake()` argument was `method`; if the rename
  is not intentional, this is the fix.
- **[C] Do nothing** — Builder uses `algorithm`; tests use `method`; tests fail.

**Recommendation: A** — The rename to `algorithm` is clearly intentional
(the spec says so in §IV Arguments); propagate it consistently.

---

**Issue 3: Multi-variable `type = "count"` targets — cross-marginal consistency of N not validated**
Severity: REQUIRED
Lens: 1 — Method Validity
Resolution type: JUDGMENT CALL

For both `calibrate_greg()` and `calibrate_rake()` with `type = "count"` and
multiple variables in `targets`, the spec requires only that each individual
target value is > 0 (`surveywts_error_population_totals_invalid`). It does not
require that the sum of each marginal vector equals the same population total N.

This creates two silent failure modes:

**For `calibrate_rake()`**: If variable A's targets sum to N_A and variable B's
sum to N_B with N_A ≠ N_B, the IPF algorithm cannot converge — it will
oscillate between satisfying A and satisfying B. The function eventually throws
`surveywts_error_calibration_not_converged`, but the error message says "max
iterations reached without convergence" rather than identifying the root cause.
The user has no diagnostic path.

**For `calibrate_greg()`**: If marginals imply different totals, the calibration
constraint vector T is internally inconsistent. Linear GREG finds the
minimum-norm solution to X'w = T, which will not satisfy all constraints
exactly. Logit GREG will fail to converge. In the linear case, no error is
thrown — the function succeeds and returns weights that satisfy no population
jointly.

The spec should add upfront validation: for `type = "count"`, all marginal
vectors in `targets` must sum to the same value (within a tolerance). Violations
should throw `surveywts_error_population_totals_invalid` with a message
identifying which marginals are inconsistent and what their sums are.

Options:
- **[A] Add cross-marginal consistency validation for `type = "count"`** —
  Validate that `sum(targets[[v]])` is the same for all variables `v` within a
  tolerance (1e-3 is conventional). Throw `surveywts_error_population_totals_invalid`
  if inconsistent. Effort: low, Risk: low, Impact: catches a common user error
  before the algorithm runs, Maintenance: none
- **[B] Document as user responsibility (no validation)** — Add a note in
  `@param targets` that count totals must be consistent across variables. Rely
  on convergence failure as the error signal for raking. For GREG, silent wrong
  results are possible. Effort: trivial, Risk: high (silent wrong results in GREG
  case), Impact: poor UX
- **[C] Do nothing** — Leave the gap as-is; inherits behavior from old API.
  Silent wrong results for GREG with inconsistent count targets.

**Recommendation: A** — The silent-wrong-result case for GREG is a
methodological trap. Upfront validation is a small addition that prevents a
statistically incorrect result from passing all tests and reaching production.

---

**Issue 4: `calibrate_poststrat()` has no error class for non-`data.frame` `targets` input**
Severity: REQUIRED
Lens: 1 — Method Validity
Resolution type: UNAMBIGUOUS

The spec states that `calibrate_poststrat()` `targets` must be a `data.frame`.
However, the function's error table (§V) contains no error class for the case
where `targets` is not a `data.frame` (e.g., a named list — which is the valid
format for the other two calibration functions).

If a user calls `calibrate(data, targets = list(age = c(...)), method = "poststrat")`
or directly calls `calibrate_poststrat(data, targets = list(...))`, the current
spec provides no specified error — the function will fail with a cryptic internal
R error when it attempts to call `names(targets)` or use it as a data frame.

Contrast with `calibrate_greg()` and `calibrate_rake()`, which correctly have
`surveywts_error_margins_format_invalid` for non-list/non-data-frame `targets`.

The test-spec for `calibrate_poststrat()` error paths does not include a test
for this condition.

Fix: Add an error class (suggest reusing `surveywts_error_margins_format_invalid`
or introduce `surveywts_error_targets_not_data_frame`) to the §V error table,
and add the corresponding test row to the test-spec.

Options:
- **[A] Add explicit error: reuse `surveywts_error_margins_format_invalid`** —
  Consistent with the class used in greg/rake for structurally invalid `targets`.
  Add the error class and test row. Effort: low, Risk: low, Maintenance: none
- **[B] Add explicit error: new class `surveywts_error_targets_not_data_frame`** —
  More precise naming; makes it immediately clear that a data frame is required.
  Effort: low (add one row to error-messages.md), Risk: low, Maintenance: none
- **[C] Do nothing** — The user gets an internal R error; no user-friendly
  diagnostic.

**Recommendation: A** — Reusing `surveywts_error_margins_format_invalid` keeps
the error class namespace lean. The error message text can still say "targets
must be a data.frame for calibrate_poststrat()".

---

#### Lens 2 — Variance Estimation Validity

**Issue 5: `survey_taylor` output: Taylor-linearized SE invalidation after calibration not documented**
Severity: SUGGESTION
Lens: 2 — Variance Estimation Validity
Resolution type: JUDGMENT CALL

When `survey_taylor` is passed as `data`, the spec states the output class is
preserved. This means the output object carries calibrated weights inside a
`survey_taylor` that still holds the original PSU/strata/FPC structure. A user
who then computes Taylor-linearized standard errors on this object (e.g., via
`survey::svymean()`) will get SEs that use the calibrated weights but do not
account for the calibration constraints — the g-weight linearization term is
absent. This produces SEs that are typically too conservative (calibration
tends to reduce variance), so the error is in the safe direction but can be
substantial for well-calibrated surveys.

This is an API-only release; the algorithmic fix (g-weight linearization) is
explicitly out of scope. But the spec provides no documentation of this
limitation. A user relying on this package to produce calibration-corrected
SEs will not be warned.

Options:
- **[A] Add a note to the `@description` or `@details` of each calibration
  function** — One sentence: "Note: Taylor-linearized standard errors computed
  on the output `survey_taylor` object do not account for calibration
  constraints; correct variance estimation requires replicate weights that have
  been independently re-calibrated." Effort: trivial, Risk: none, Impact:
  prevents silent misuse, Maintenance: remove when g-weight support is added
- **[B] Add the note only to the `calibrate()` dispatcher** — Centralized
  documentation; users reading the dispatcher learn about the limitation.
  Less surface area than [A].
- **[C] Do nothing** — Defer documentation to a later phase. The spec already
  excludes variance estimation from scope.

**Recommendation: A** — One sentence per function costs nothing and prevents
a statistically consequential misuse. The note is temporary and will be removed
when g-weight support lands.

---

#### Lens 3 — Algorithmic Correctness

Lens 3 is partially applicable: the spec references iterative algorithms
(`calibrate_rake()` IPF, `calibrate_greg()` with `model = "logit"`) with
convergence requirements. However, §I explicitly states "Changes to calibration
engine internals: No behavioral change; only public API changes." The existing
algorithms carry their own convergence specifications from the old `rake()` and
`calibrate()` implementations.

No new issues found under Lens 3. The convergence criteria, max-iteration
behavior, and non-convergence error classes are carried forward from the
prior API.

---

#### Lens 4 — Statistical Assumptions

Issue 3 (marginal consistency) covers the most significant statistical
assumption gap. One additional observation:

The spec (§III, §IV) says for `type = "prop"`: targets must sum to 1.0 within
1e-6. For `type = "count"`: all values must be strictly positive. This correctly
treats the two type modes differently. The 1e-6 tolerance for proportion sums
is standard. No issues found beyond those already captured in Issues 1–4.

---

#### Lens 5 — Formula Integrity

The spec explicitly excludes engine internals from scope. No formula definitions
are added or changed in this spec. The only formula-adjacent content is the
specification of convergence tolerances (inherited from old functions) and the
`type = "prop"` sum-to-1 check. Both are correct as stated. No issues found
under Lens 5.

---

#### Lens 6 — Literature Cross-Check

Lens 6 not applicable: no paper was attached and no `comprehension.md` exists
for this run. The spec's §IX references section lists appropriate citations
for each function. No cross-check possible without attached literature.

---

## Summary (Pass 1)

| Severity | Count |
|---|---|
| BLOCKING | 0 |
| REQUIRED | 4 |
| SUGGESTION | 1 |

**Total issues:** 5

**Overall assessment:** The calibration API redesign is methodologically sound
in structure. Three of the four REQUIRED issues are propagated naming
inconsistencies (the `model`/`method` and `algorithm`/`method` confusion) that
will cause test failures at implementation time if not resolved — they're
specification typos, not design flaws. The fourth (cross-marginal count
consistency) is a genuine statistical gap that the API redesign is the right
moment to close; the GREG silent-wrong-result case in particular is a trap
that no test will catch without explicit validation. The SUGGESTION (SE
invalidation note) is optional but costs nothing and prevents a consequential
misuse of the `survey_taylor` output path.
