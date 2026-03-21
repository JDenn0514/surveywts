# Replicate API Design Decisions

**Date resolved:** 2026-03-20
**Spec:** `plans/spec-replicate.md` §XI

---

## Q1: Bootstrap Type Roster

**Decision:** Option A — All 5 svrep types, no subbootstrap.

Types: `"Rao-Wu-Yue-Beaumont"` (default), `"Rao-Wu"`, `"Antal-Tille"`,
`"Preston"`, `"Canty-Davison"`.

---

## Q2: Type and Estimator Naming

**Decision:** Option A — Use svrep's exact string names.

No aliases. `"Rao-Wu-Yue-Beaumont"`, `"Stratified Multistage SRS"`, etc.

---

## Q3: Variance Estimator Roster

**Decision:** Option A — All 12 svrep estimators.

Document the 4-5 most common with examples in roxygen; list the rest with
one-line descriptions. Zero implementation cost since they are passthrough
strings to svrep.

---

## Q4: `survey_nonprob` Input Policy

**Decision:** Option A — Bootstrap + jackknife only.

`create_bootstrap_weights()` and `create_jackknife_weights()` accept
`survey_nonprob`. All other `create_*_weights()` functions reject it.
Simple resampling only; re-calibrated bootstrap is Phase 2.5.

---

## Q5: BRR Non-Paired Strata Handling

**Decision:** Option A — Error on non-paired designs.

`create_brr_weights()` errors with `surveywts_error_brr_requires_paired_design`
and a helpful message suggesting `create_gen_rep_weights()` or
`create_gen_boot_weights()` as alternatives. Does not expose `small`/`large`
arguments.

---

## Q6: Jackknife Configuration

**Decision:** Option A — Hide all advanced configuration.

Delete-1 uses survey's `survey.lonely.psu` option. Random-groups uses svrep's
defaults. No `adj_method`, `scale_method`, or variance strata arguments
exposed in Phase 1.

---

## Q7: Taylor Round-Trip Storage

**Decision:** Option B — Store in `@metadata@weighting_history`.

`create_*_weights()` adds a history entry with
`source_design = list(ids = ..., strata = ..., fpc = ..., nest = ...)`.
`as_taylor_design()` reads from the most recent `"replicate_creation"` entry.

---

## Q8: Advanced Argument Exposure

**Decision:** As proposed in spec §XI table.

| Argument | Decision |
|----------|----------|
| `compress` | **Hide** — always `TRUE` |
| `tau` | **Expose** on `create_gen_boot_weights()` |
| `psd_option` | **Hide** — always `"warn"` |
| `balanced` | **Expose** on `create_gen_rep_weights()` |
| `samp_method_by_stage` | **Hide** |
| `aux_var_names` | **Expose** on gen-boot and gen-rep (required for Deville-Tille) |
| `exact_vcov` | **Hide** |
| `sort_var` (jackknife) | **Hide** |
| `var_strat` / `var_strat_frac` | **Hide** |
| `use_normal_hadamard` | **Hide** |

---

## Q9: Weighting History Entries

**Decision:** Option C — Yes, with distinct `"replicate_creation"` operation type.

Distinguishes design conversion from weight adjustment operations (`"calibration"`,
`"raking"`, etc.). Entry includes `source_design` metadata per Q7.

---

## Q10: Print Method for `survey_replicate`

**Decision:** Option A — Full print method.

Shows weight stats, replicate type, number of replicates, scale factor, and
weighting history. Consistent with `survey_nonprob` print method from Phase 0.
