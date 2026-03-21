# Replicate Open Questions: Argument Input Design

**Date created:** 2026-03-20
**Updated:** 2026-03-20
**Context:** §XI API design questions are resolved (`plans/decisions-replicate.md`).
These are follow-up questions about argument ergonomics that surfaced during
review, to be discussed before or during implementation.

**Findings from surveycore review** (2026-03-20): Read `surveycore/R/core-classes.R`
and `surveycore/R/core-constructors.R`. Key findings noted inline on Q14, Q19, Q20.

---

## Q11: Accepted Input Classes for `data`

The spec says `survey_taylor` and (for bootstrap/jackknife) `survey_nonprob`.
Should we also accept:

- A raw `survey::svydesign` object directly? (skip the surveycore conversion
  on the user's side)
- A `srvyr::tbl_svy` object?

Trade-off: convenience vs. keeping the API boundary clean. If we accept
`svydesign`, we bypass surveycore's metadata system entirely. If we don't,
users who already have a `svydesign` must wrap it in `surveycore::from_svydesign()`
first.

---

## Q12: Call Ergonomics — Realistic Patterns

Walk through realistic call patterns to check whether argument names, defaults,
and ordering feel right in practice. Examples to evaluate:

```r
# Simple bootstrap — does this feel natural?
create_bootstrap_weights(my_design, replicates = 200L)

# BRR with Fay damping — is rho = 0.5 discoverable?
create_brr_weights(my_design, rho = 0.5)

# Generalized bootstrap with a specific estimator — too many positional args?
create_gen_boot_weights(my_design, replicates = 500L,
                        variance_estimator = "SD1", tau = "auto")

# Dispatcher — is method = "gen-boot" obvious, or would users expect "generalized_bootstrap"?
create_replicate_weights(my_design, method = "gen-boot", replicates = 200L)
```

Key sub-questions:
- Are the `method` strings in the dispatcher (`"gen-boot"`, `"gen-rep"`, `"sdr"`)
  discoverable enough, or do they need longer/shorter aliases?
- Should `replicates` default to `500L` everywhere, or should different methods
  have different defaults (e.g., SDR defaults to `100L` which is already in the spec)?

---

## Q13: `...` Passthrough in `create_replicate_weights()`

The dispatcher forwards `...` to the individual function. This means:

- `create_replicate_weights(d, method = "brr", rho = 0.5)` works
- `create_replicate_weights(d, method = "brr", replicates = 500)` silently
  passes `replicates` to `create_brr_weights()` which doesn't use it

Should the dispatcher:
- **A:** Keep `...` passthrough as-is (simple; user gets an "unused argument"
  error from the target function if they pass something invalid)
- **B:** Validate that `...` args are valid for the selected method (more
  helpful errors, but adds maintenance burden)
- **C:** Drop the dispatcher entirely and only offer the individual functions
  (users pick the right function; no ambiguity)

---

## Q14: NSE vs. String for Column Name Arguments

Currently in the spec:
- `sort_var` in `create_sdr_weights()` is a **string** (`character(1)`)
- `aux_var_names` in gen-boot/gen-rep is a **character vector**

The rest of surveywts (Phase 0) uses **NSE** (tidy-select / bare names) for
column references in user-facing functions (e.g., `calibrate(data, variables = c(age_group))`).

Options:
- **A:** Strings — consistent with svrep's interface; these are passthrough
  args to the backend anyway
- **B:** NSE (bare names) — consistent with surveywts Phase 0 conventions;
  evaluate with `rlang::as_name(rlang::enquo(...))` before passing to backend
- **C:** Accept both — use `tidyselect` for column selection, fall back to
  string if character is passed

Trade-off: internal consistency (NSE) vs. backend consistency (strings) vs.
flexibility (both).

> **Surveycore finding (2026-03-20):** surveycore uses tidy-select for ALL
> user-facing column arguments: `as_survey(data, weights = wt)`,
> `as_survey_replicate(data, repweights = starts_with("rep"))`. This strongly
> favors **Option B** for ecosystem consistency. The conversion from bare name
> to string is trivial (`rlang::as_name(rlang::enquo(sort_var))`) and happens
> before the backend call.

---

## Q15: Reproducibility / Seed Control for Stochastic Methods

Bootstrap and random-group jackknife involve randomness. Should
`create_bootstrap_weights()`, `create_gen_boot_weights()`, and
`create_jackknife_weights(type = "random-groups")` accept a `seed` argument?

Options:
- **A:** No `seed` argument — users call `set.seed()` before the function
  (standard R convention; svrep and survey work this way)
- **B:** Expose a `seed` argument that calls `set.seed()` internally and
  restores the previous RNG state on exit (via `withr::local_seed()`) —
  self-contained reproducibility without side effects
- **C:** Expose `seed` but only as documentation guidance (i.e., mention
  `set.seed()` in the roxygen `@details`)

Trade-off: Option A is standard but easy to forget. Option B is friendlier
but adds an argument to stochastic functions that deterministic ones don't
have, creating asymmetry across the family.

---

## Q16: Backend Error Wrapping

When the backend (`survey` or `svrep`) throws an error that surveycore's
pre-validation didn't catch, what should happen?

Examples of backend errors that could leak through:
- `survey::as.svrepdesign()` fails due to singular design matrix
- `svrep::as_bootstrap_design()` errors on a design structure it doesn't support
- Memory errors from very large replicate matrices

Options:
- **A:** Let backend errors propagate as-is — the user sees the survey/svrep
  error message directly
- **B:** Wrap in a `tryCatch()` and re-throw with a surveywts error class
  (e.g., `surveywts_error_backend_failure`) that includes the original message
  as context
- **C:** Wrap only known failure modes; let unknown errors propagate

Trade-off: Option A is simplest but users get confusing error messages from
packages they didn't call directly. Option B gives consistent error classes
but obscures the original error. Option C is a middle ground but requires
cataloging known failure modes.

---

## Q17: `replicates` Argument Type Coercion

The spec says `replicates` is `integer(1)`. In practice, R users write
`replicates = 200` (numeric) not `replicates = 200L` (integer). Should we:

- **A:** Accept numeric and silently coerce to integer (with a check that
  it's a whole number) — e.g., `200` works, `200.5` errors
- **B:** Require strict integer input — `200` errors with a message suggesting
  `200L`
- **C:** Accept numeric, coerce, and warn if the input had a fractional part

Option A is almost certainly correct here (it's what every R package does),
but worth noting explicitly so the validator handles `200` and `200L`
identically.

---

## Q18: `survey_nonprob` + Jackknife Scope

Q4 decided that `survey_nonprob` is accepted by bootstrap and jackknife.
For jackknife specifically:

- **Delete-1** makes sense: each observation is its own PSU, so delete-1
  jackknife leaves one out at a time
- **Random-groups** is ambiguous: there are no PSUs to assign to groups —
  should it randomly assign observations to groups?

Options:
- **A:** `survey_nonprob` supports delete-1 only; `type = "random-groups"`
  errors with `survey_nonprob`
- **B:** Both work — random-groups randomly assigns individual observations
  to groups (treating each as its own PSU)

Trade-off: Option A is conservative and clear. Option B is technically valid
(svrep would handle it) but the statistical properties of random-group
jackknife on non-probability samples are not well-established.

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

When `create_*_weights()` generates replicate weight columns in `@data`,
what should they be named?

Options:
- **A:** `rep_1`, `rep_2`, ..., `rep_500` — short and generic
- **B:** `repwt_1`, `repwt_2`, ... — matches survey package convention
  (`repweights` slot)
- **C:** Use whatever the backend produces — e.g., svrep may name them
  differently than survey
- **D:** `{method}_rep_1`, ... — e.g., `boot_rep_1`, `jk_rep_1` — encodes
  the method in the column name

Trade-off: Option C is zero maintenance but column names may differ between
backends. Option A/B gives a consistent naming convention. Option D is
self-documenting but verbose.

> **Surveycore finding (2026-03-20):** `as_survey_replicate()` uses
> tidy-select for `repweights` — it stores whatever column names already
> exist in the data. surveycore imposes no naming convention. This means
> the naming is determined by whatever `from_svydesign()` produces from the
> backend's `svyrep.design` object. Worth checking what survey/svrep
> actually name the columns in practice to decide if we need to rename them
> for consistency.

---

## Q21: Progress Messaging for Slow Operations

Generating 500 bootstrap replicates on a large dataset can take seconds to
minutes. Should `create_*_weights()` emit progress messages?

Options:
- **A:** Silent — no messages; consistent with Phase 0 functions
- **B:** Use `cli::cli_progress_bar()` for methods where `replicates > 100`
- **C:** Use `cli::cli_alert_info()` with a one-line message like
  `"Creating 500 bootstrap replicates..."` before the backend call

Trade-off: A is cleanest for non-interactive use. B/C are helpful for
interactive sessions but add noise in scripts and tests.

---

## Q22: `as_taylor_design()` and Calibrated Replicate Designs

If a user creates replicate weights and then calibrates the replicate design
(future phase), calling `as_taylor_design()` on the calibrated replicate
design raises questions:

- Should it return the pre-calibration Taylor design (from stored history)?
- Should it return a Taylor design with the calibrated weights?
- Should it error because the round-trip is lossy?

This may be a future-phase problem, but the history storage design (Q7/Q9)
should not paint us into a corner. Worth considering now so the
`"replicate_creation"` history entry structure doesn't need to change later.
