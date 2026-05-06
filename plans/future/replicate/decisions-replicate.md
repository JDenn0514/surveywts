# Decisions Log — surveywts replicate

This file records planning decisions made during replicate spec development.
Each entry corresponds to one planning session.

---

## 2026-03-11 — Methodology lock: replicate weight algorithms + scope

### Context

Stage 2 methodology review (Pass 1 + code verification addendum, 2026-03-10)
produced 13 issues — 7 BLOCKING, 6 REQUIRED. This session resolved 7 of them:
3 unambiguous fixes (Issues 1, 3, 8), 3 judgment calls (Issues 4, 5, 6), and
1 scope correction (Issue 7 — dropped from Phase 1 entirely). Issues 2 and
9–13 remain open and will be resolved in the next session.

A code audit conducted mid-session (three parallel subagents reading surveycore
and surveywts source) revealed a fundamental misunderstanding in the Phase 1
spec: `survey_nonprob` is a non-probability sample class (Phase 2.5
skeleton), not a probability design with calibrated weights. This changed the
resolution of Issue 7 from a judgment call to a scope removal.

### Unambiguous Fixes Applied

**Issue 1 — RWYB draw count (BLOCKING)**
- Fix: §III.b "Draw m_h = n_h PSUs" → "Draw m_h = n_h − 1 PSUs with replacement"
- Confirmed against svrep source (`make_rwyb_bootstrap_weights.R`)

**Issue 3 — Fay scale factor (BLOCKING)**
- Fix: §II.d and §VI Fay scale `1 / n_rep` → `1 / (n_rep * (1 - rho)^2)`
- Confirmed against survey package source (`as.svrepdesign.default`)

**Issue 8 — `mse = FALSE` undocumented (REQUIRED)**
- Fix: added documentation to all `mse` argument entries explaining both forms:
  - `TRUE`: deviation from full-sample estimate
  - `FALSE`: deviation from replicate mean (can underestimate for biased estimators)

### Questions & Decisions

**Q: Issue 4 — `create_gen_boot_weights()` SD1/SD2 formulas: fully specify both,
or drop SD2 from Phase 1?**

The addendum corrected the description: SD1/SD2 are Ash (2014) successive-
difference variance estimators used as quadratic form targets for the generalized
bootstrap (not Beaumont & Patak 2012 random-weight variants).

- Options considered:
  - **Option A:** Fully spec both SD1 and SD2 in §VII (state Ash 2014 quadratic
    forms, reference svrep `make_gen_boot_factors()`)
  - **Option B:** SD1 only in Phase 1; defer SD2
  - **Option C:** Do nothing (spec remains incomplete)
- **Decision:** Option A — fully spec both
- **Rationale:** Both are listed deliverables; both reference the same svrep
  oracle function; specifying both adds minimal incremental effort once SD1 is
  written

**Q: Issue 5 — SDR: include in Phase 1 with corrected algorithm, or defer?**

The addendum made three corrections to the spec's SDR description:
- Formula corrected: Hadamard-based `f_{i,r} = 1 + (H[row1,r] − H[row2,r]) × 2^(−3/2)`, not alternating signs
- Scale corrected: `4/R` (not `2/R`)
- Replicate constraint corrected: must be a multiple of 4 (not just even)
- New: `sort_var` argument required (systematic selection order)
- Error class renamed: `surveywts_error_sdr_replicates_not_multiple_of_4`

- Options considered:
  - **Option A:** Keep SDR in Phase 1 with fully corrected algorithm
  - **Option B:** Defer SDR to Phase 2
- **Decision:** Option A — keep in Phase 1, spec corrected
- **Rationale:** SDR is in the v0.2.0 deliverables table; corrections are now
  documented precisely; svrep `make_sdr_replicate_factors()` serves as oracle

**Q: Issue 6 — `as_taylor_design()` round-trip: how to preserve Taylor design
structure in `survey_replicate` for recovery?**

`survey_replicate@variables` does not define `ids`, `strata`, `fpc`, `nest` keys
by default. Without storing them at creation time, `as_taylor_design()` cannot
reconstruct the original `survey_taylor`.

- Options considered:
  - **Option A:** Store `$ids`, `$strata`, `$fpc`, `$nest` in
    `survey_replicate@variables` during `create_*_weights()`
  - **Option B:** Store in `@metadata@weighting_history` provenance entry
  - **Option C:** Require user to supply them as arguments to `as_taylor_design()`
- **Decision:** Option A — store in `@variables`
- **Rationale:** Clean, explicit, readable via normal property access. Falls back
  to Option B if surveycore rejects extra `@variables` keys (must be verified
  at implementation start)

**Q: Issue 7 — Bootstrap variance for `survey_nonprob`: how should Phase 1
handle re-calibration per replicate?**

This question was resolved by a code audit that revealed `survey_nonprob` is
NOT a probability sample with design structure. From surveycore source
(`core-classes.R` line 698):

> "Calibrated / Non-Probability Survey Design — A survey design object for
> non-probability samples and post-hoc calibrated designs (e.g., raked online
> panels, post-stratified samples)."

`survey_nonprob@variables` has only `weights` and `probs_provided` — no
`ids`, `strata`, or `fpc`. There is no design structure from which bootstrap
PSU replicates can be drawn. The class is explicitly marked "Phase 2.5
skeleton" in surveycore, with full bootstrap variance reserved for Phase 2.5.

- **Decision:** Remove "Bootstrap variance in `survey_nonprob`" from Phase 1
  deliverables. Phase 1 `create_*_weights()` functions reject `survey_nonprob`
  input with `surveywts_error_not_survey_design` (same as `data.frame`/
  `weighted_df`) and an `"i"` bullet pointing to Phase 2.5.
- **Rationale:** The Phase 1 spec was based on a category error. `survey_nonprob`
  is not a probability design — RWYB bootstrap (and all other Phase 1 methods)
  require PSUs and strata. Phase 2.5 is the planned home for non-probability
  bootstrap variance.

### Pending Decisions (carry to next session)

The following issues from the Stage 2 methodology review were NOT resolved in
this session. Resolve these in Stage 2 Resolve Part 2 before methodology lock:

| # | Title | Severity | Type |
|---|-------|----------|------|
| 2 | JK1 for stratified designs: error or support with per-stratum rscales? | BLOCKING | JUDGMENT CALL |
| 9 | Re-calibration convergence failure handling (now N/A — Issue 7 dropped) | REQUIRED | JUDGMENT CALL |
| 10 | JKn stratified grouping: within-stratum or across all strata? | REQUIRED | JUDGMENT CALL |
| 11 | Bootstrap single-PSU stratum handling | REQUIRED | JUDGMENT CALL |
| 12 | Bootstrap unclustered design support | REQUIRED | JUDGMENT CALL |
| 13 | BRR vs Fay API distinction | REQUIRED | JUDGMENT CALL |

Note: Issue 9 (re-calibration convergence) may now be N/A since Issue 7
(bootstrap for `survey_nonprob`) was dropped. Verify at start of next session.

### Pending Actions (separate tasks)

- **`survey_nonprob` rename:** The name `survey_nonprob` is confusing
  (implies post-calibration of a probability sample; actually means
  non-probability design). Decision to rename to `survey_nonprob` in surveycore
  was flagged. To be executed in a dedicated session — affects surveycore source,
  surveywts source, tests, and snapshots throughout both packages.

### Outcome

Phase 1 methodology pass is partially locked: RWYB formula, Fay scale, SDR
algorithm, gen-boot quadratic forms, and as_taylor_design() round-trip are
resolved. Bootstrap for `survey_nonprob` is removed from Phase 1 scope.
Six issues remain open (Issues 2, 10–13, and verification of Issue 9 N/A status).

---
