# Replicate Open Questions: Argument Input Design

**Date created:** 2026-03-20
**Resolved:** 2026-04-18
**Status:** All resolved. Decisions folded into `plans/decisions-replicate.md` (Q11–Q22) and `plans/spec-replicate.md` (v1.1).

---

## Q11: Accepted Input Classes for `data`

**Decision:** surveycore classes only. Do not accept raw `survey::svydesign` or
`srvyr::tbl_svy`. Users holding a `svydesign` wrap once with
`surveycore::from_svydesign()`. Keeps the API boundary clean and preserves
surveycore's metadata lifecycle.

---

## Q12: Call Ergonomics — Realistic Patterns

**Decision:**

1. **Method strings** in the dispatcher use full names:
   `"generalized-bootstrap"`, `"generalized-replicate"`, `"successive-difference"`.
   Common methods keep short names: `"bootstrap"`, `"jackknife"`, `"brr"`.
2. **`replicates` default** is method-specific:
   - `500L` for `create_bootstrap_weights()`, `create_gen_boot_weights()`
   - `100L` for `create_sdr_weights()`
   - no default for `create_brr_weights()` (determined by Hadamard sizing) and
     `create_jackknife_weights()` (determined by design / required for
     random-groups)
3. **Positional arguments** limited to `data` and `replicates`. All other args
   are name-only — enforced by placing them after `...` in the signature.

---

## Q13: `...` Passthrough in `create_replicate_weights()`

**Decision:** Option A — keep `...` passthrough as-is. If a user passes an
argument the selected method doesn't accept, they get R's built-in
"unused argument" error from the target function. Not beautiful but clear
enough and zero maintenance.

---

## Q14: NSE vs. String for Column Name Arguments

**Decision:** Option B — NSE / tidy-select for all column arguments, matching
surveycore and Phase 0 conventions.

- `sort_var` in `create_sdr_weights()` — single bare name
- `aux_var_names` in gen-boot/gen-rep — tidy-select expression (supports
  `starts_with()` etc.)

Resolve to strings internally before the backend call:
`rlang::as_name(rlang::enquo(sort_var))` for the scalar,
`names(tidyselect::eval_select(rlang::enquo(aux_var_names), data@data))` for
the vector.

---

## Q15: Reproducibility / Seed Control for Stochastic Methods

**Decision:** Option B — expose a `seed = NULL` argument on stochastic methods
and set the seed internally via `withr::local_seed()`, restoring the caller's
RNG state on exit.

Applies to:
- `create_bootstrap_weights()`
- `create_gen_boot_weights()`
- `create_jackknife_weights()` (only takes effect for
  `type = "random-groups"`; ignored for delete-1)

`seed = NULL` preserves standard-R behavior (use current RNG state).

---

## Q16: Backend Error Wrapping

**Decision:** Option C — wrap known failure modes reactively; start with none.

Phase 1 ships with zero wrapped error modes. As integration tests surface a
backend error whose message we can improve, we add a named
`surveywts_error_*` class and a focused `tryCatch()`. Unknown errors propagate
with their original message.

---

## Q17: `replicates` Argument Type Coercion

**Decision:** Option A — accept numeric whole numbers and coerce silently to
integer. Fractional input errors with
`surveywts_error_replicates_not_whole_number`.

`replicates = 200` and `replicates = 200L` behave identically.
`replicates = 200.5` errors.

---

## Q18: `survey_nonprob` + Jackknife Scope

**Decision:** Option A — `survey_nonprob` supports `type = "delete-1"` only.
`type = "random-groups"` errors with
`surveywts_error_jackknife_type_unsupported_for_nonprob` and points the user
to delete-1.

Random-groups jackknife would run mechanically but its variance properties
on non-probability samples are not established in the literature. If that
changes, lifting the restriction is a non-breaking change.

---

## Q19: `survey_replicate` Class Readiness in surveycore — RESOLVED

~~Does `survey_replicate` exist in surveycore yet?~~

> **Surveycore finding (2026-03-20):** YES — `survey_replicate` exists at
> `surveycore/R/core-classes.R:354`. Its `@variables` structure matches the
> spec exactly:
> - `$weights` — character string (base weight column)
> - `$repweights` — character vector of replicate weight column names
> - `$type` — one of `"JK1"`, `"JK2"`, `"JKn"`, `"BRR"`, `"Fay"`,
>   `"bootstrap"`, `"ACS"`, `"successive-difference"`, `"other"`
> - `$scale` — numeric scaling factor
> - `$rscales` — numeric vector or `NULL`
> - `$fpc` / `$fpctype` / `$mse`
>
> Validator checks: design vars exist in `@data`, weight column is numeric and
> positive, replicate columns are numeric.
>
> Constructor `as_survey_replicate()` exists at `core-constructors.R:596` with
> full tidy-select support for `weights` and `repweights`.
>
> **NOT BLOCKING. No surveycore changes needed for Phase 1.**

---

## Q20: Replicate Weight Column Naming

**Decision:** Option A — surveywts renames replicate weight columns to
`rep_1, rep_2, …, rep_N` uniformly across all `create_*_weights()` methods.
The method is recorded in `@metadata@weighting_history`, so encoding it in
the column name (Option D) is redundant. Unifying on one convention
post-backend (rather than passing through whatever `survey`/`svrep` produces)
avoids downstream code breaking when users switch methods.

---

## Q21: Progress Messaging for Slow Operations

**Decision:** Option A — silent. Matches Phase 0 functions (`calibrate()`,
`rake()`, `poststratify()`). The backend does its work inside a single
C call, so we can't drive a real progress bar from inside anyway. If
interactive users complain later, adding an opt-in `verbose = FALSE`
default is non-breaking.

---

## Q22: `as_taylor_design()` and Calibrated Replicate Designs

**Decision:** Phase 1 errors with
`surveywts_error_taylor_from_calibrated_replicate` if a calibrated replicate
design is passed. Defer the behavioral choice (pre-calibration vs.
calibrated-Taylor vs. permanent error) to the phase that implements
replicate-design calibration.

**Structural requirement for Phase 1:** the `"replicate_creation"` history
entry stores a snapshot of the input design's `@variables` list. This keeps
options A, B, and C open for later without needing to change the history
structure.
