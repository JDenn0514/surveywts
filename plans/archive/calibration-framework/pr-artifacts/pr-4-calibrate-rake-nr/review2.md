# PR 4 Review — Round 2

## Verdict: BLOCK

## Summary

The three items from the Round 1 STOP are all fixed: EC8 tolerance is now
`1e-10`, `calibrate_rake()` emits `surveywts_warning_srs_no_weights`, and the
N2 oracle test is present with correct tolerance and `skip_if_not_installed`
inside the block. One new gap prevents PASS: `surveywts_error_cap_not_positive`
is required by spec §calibrate_rake §Errors and test-spec E20, but the
implementation has no validation for `cap = 0` / non-positive cap, and no test
exists for it. This was also missed by the tester in audit3.

---

## Checks

### Tolerance Integrity

All tolerance checks pass:
- EC6 (weight conservation, `type = "count"`) — now `tolerance = 1e-10` at
  `test-03-rake.R` line 1442. FIXED from Round 1 STOP.
- EC5 (weight conservation, `type = "prop"`) — `tolerance = 1e-10` at line
  1420. Correct.
- N1 oracle (NR vs `survey::calibrate(calfun = "raking")`) — `tolerance = 1e-8`.
  Matches test-spec.
- N2 oracle (`classic_ipf` vs `survey::rake()`) — `tolerance = 1e-6`. Matches
  test-spec (IPF convergence tolerance).
- CX1–CX3 dispatch identity — `tolerance = 1e-10`. Correct.

No Tolerance Integrity violations.

### SRS Warning

- `R/calibrate_rake.R` lines 293–310: `cli::cli_warn(..., class = "surveywts_warning_srs_no_weights")` emitted for plain `data.frame` + `weights = NULL`. FIXED from Round 1 STOP.
- H14 (`test-03-rake.R` line 1547): `expect_warning(class = "surveywts_warning_srs_no_weights")` present; `test_invariants(result)` called; returns `weighted_df`. FIXED.
- W1 (`test-03-rake.R` line 1564): second `expect_warning(class = "surveywts_warning_srs_no_weights")` block present. FIXED.

### N2 Oracle

- Test at `test-03-rake.R` line 1578. FIXED from Round 1 BLOCK.
- `skip_if_not_installed("survey")` at line 1579 — inside the block. Correct.
- Tolerance `1e-6` at line 1621. Correct per test-spec.
- Normalization approach: both sets of weights divided by their respective
  sums before comparison to remove the scale difference between
  `calibrate_rake()` (normalises to n) and `survey::rake()` (preserves
  sum(base_weight)). Valid — the comparison is scale-invariant.

### Spec coverage

**Gap: `surveywts_error_cap_not_positive` missing (E20).**

Spec §calibrate_rake §Errors:
> `surveywts_error_cap_not_positive` — `cap` is non-`NULL` and is
> non-positive, non-finite, or non-numeric.

Test-spec E20: `cap = 0, algorithm = "classic_ipf"` → `expect_error(class =
"surveywts_error_cap_not_positive")` + snapshot.

Impl-plan PR 4 acceptance criteria: "Error paths E1–E20 pass."

Actual state:
- `R/calibrate_rake.R` has no validation for `cap > 0`. The only cap guard is
  `cap + algorithm = "nr"` (line 183). Passing `cap = 0` or a negative value
  proceeds silently into the engine.
- No test for `surveywts_error_cap_not_positive` exists in `test-03-rake.R`.
- `plans/error-messages.md` line 50 lists the class, confirming it is
  specified. The audit3 does not mention this gap.

All other spec items checked:
- H1–H14, H9 (cap), H10 (count), H11 (Format B), H12 (reference_design),
  H13 (history op), H6–H8 (NR path): present and pass per audit3.
- N1 (NR oracle): present.
- E17 (`cap_not_supported_nr`), E18 (`calibration_not_converged`): present.
- E19 (`calibration_singular_system`): present (labeled "E19" in test file at
  line 1301 section header).
- M1 (`surveywts_message_already_calibrated`): present (line 738).
- EC1–EC9: present.
- W2–W4: present.

The only missing item is E20.

### R CMD check

`devtools::check()` run locally:
- 0 errors
- 0 warnings
- 1 NOTE: `checking for future file timestamps — unable to verify current time`
  (environment-specific; pre-approved category)

### Additional observations (non-blocking)

1. `R/utils.R` `fn_name` at line 345 still reads `"calibrate_greg"` (affects
   the `"v"` bullet in `surveywts_error_variable_has_na` for calibration
   context). Snapshots in `calibrate-linear.md` and `calibrate-logit.md`
   capture the stale text at line 118/117. This was explicitly deferred to PR 5
   per the master impl-plan File Surface Summary and the implementation.md notes.
   Tests pass because snapshot text matches production code. Not a violation.

2. `calibrate-utils.R` error messages still reference `calibrate_greg()` in
   `"v"` bullets. Also deferred to PR 5 per implementation notes. Not a violation.

---

## Issues

### BLOCK: E20 missing — `surveywts_error_cap_not_positive` not implemented or tested

**Category:** Spec coverage gap — traceable to builder (missing implementation
+ missing test).

**File/location:**
- `R/calibrate_rake.R` — no validation for `cap <= 0`, non-finite, or
  non-numeric when `algorithm = "classic_ipf"`. The cap guard block starting
  at line 183 only checks `algorithm == "nr"`.
- `tests/testthat/test-03-rake.R` — no test block for E20.

**Required fix:**

1. In `R/calibrate_rake.R`, add a validation block after the existing
   `cap + algorithm = "nr"` guard (around line 201):
   ```r
   if (!is.null(cap)) {
     if (!is.numeric(cap) || length(cap) != 1L || !is.finite(cap) || cap <= 0) {
       cli::cli_abort(
         c(
           "x" = "{.arg cap} must be a positive finite numeric scalar.",
           "i" = "Got {.val {cap}}.",
           "v" = "Use a value > 0 (e.g., {.code cap = 5}) or {.code cap = NULL} to disable capping."
         ),
         class = "surveywts_error_cap_not_positive"
       )
     }
   }
   ```

2. In `tests/testthat/test-03-rake.R`, add an E20 test block:
   - `expect_error(cap = 0, algorithm = "classic_ipf")` with
     `class = "surveywts_error_cap_not_positive"`
   - `expect_snapshot(error = TRUE, ...)` for the same call

Re-run audit after fix. All other checks are clean.

**Re-dispatch:** Builder.
