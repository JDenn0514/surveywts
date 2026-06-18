# Design: surveywts Documentation Rewrite

**Date:** 2026-06-18
**Status:** Approved
**Standard:** `.claude/rules/function-documentation.md`

---

## Scope

21 exported functions across 7 families. Functions already cleaned up and excluded:
`create_jackknife_weights`, `create_group_jackknife_weights`, `calibrate_to_survey`.

| Family | Functions |
|---|---|
| Calibration | `calibrate`, `calibrate_rake`, `calibrate_linear`, `calibrate_logit`, `poststratify` |
| Sample calibration | `calibrate_to_estimate` |
| Nonresponse | `adjust_nonresponse`, `redistribute_weights` |
| Diagnostics | `effective_sample_size`, `weight_variability`, `summarize_weights` |
| Utilities | `trim_weights`, `stabilize_weights` |
| Replicate weights | `create_bootstrap_weights`, `create_brr_weights`, `create_gen_boot_weights`, `create_gen_rep_weights`, `create_sdr_weights`, `create_replicate_weights`, `as_taylor_design` |
| Propensity | `ipw` |

---

## Two-Phase Structure

### Phase 1 — Structural Docs

Pure text changes to all 21 functions. Zero R CMD check risk. One PR to `develop`.

**Changes applied to every function:**

1. `@return` → `@returns` (13 affected functions)
2. `@seealso` — add to all dispatchers, sibling functions, and canonical companions per rule:
   - Dispatchers (`calibrate`, `create_replicate_weights`): must link every dispatched function
   - Siblings: all functions within the same `@family` must cross-link
   - Canonical companions: e.g., `ipw()` → `summarize_weights()`
3. Titles — enforce active-verb present-tense phrase; each sibling title must be distinct from every other sibling
4. Descriptions — enforce: adds information the title doesn't contain; no formula; 1–3 sentences max
5. `@param data` — enforce type annotation lead; add forward reference to Replicate Weights section where applicable
6. `@param` defaults — state the default first and explicitly label it "the default"

**Changes applied to specific functions:**

| Function | Additional structural change |
|---|---|
| `calibrate` | Add `@details` method overview (Tier 4 requirement); add `@references` for rake + linear + logit |
| `create_replicate_weights` | Add `@details` method overview (Tier 4 requirement); add `@references` for each resampling method; expand `@param` docs to match dispatched functions |
| `effective_sample_size` | Add `@references` (Kish 1965); add Algorithm section with `\deqn{}` |
| `trim_weights` | Add `@references` block (Potter & Zheng 2015 already cited in description text) |
| `create_bootstrap_weights`, `create_brr_weights`, `create_gen_boot_weights`, `create_gen_rep_weights`, `create_sdr_weights` | Verify `@references` present and populated |
| `calibrate_linear`, `calibrate_logit`, `poststratify` | Verify `@references` populated (stubs exist) |
| `redistribute_weights` | Populate empty `@return` and `@details` stubs |

**End of phase:** run `devtools::document()`, confirm 0 errors/warnings in check, open PR.

---

### Phase 2 — Examples

Family-by-family. Each family block is verified with `devtools::run_examples()` before moving to the next. One combined PR after all families are verified.

**Key rules enforced:**
- All examples use package data (no inline `data.frame`, no `data(x, package = "other")`)
- Every function that accepts survey objects gets at least one survey-object example demonstrating unique behavior
- `\dontrun{}` only for genuine external resource requirements — none expected here
- Comments use section-header format: `# Brief label --------------------------------`

---

## Dataset Mapping

| Function(s) | Dataset(s) | Notes |
|---|---|---|
| `effective_sample_size`, `weight_variability`, `summarize_weights` | `ns_wave1`, `ns_wave1_svy` | `summarize_weights` shows `by = gender` |
| `trim_weights`, `stabilize_weights` | `ns_wave1`, `ns_wave1_svy`, `acs_wy_2022_svy` | `acs_wy_2022_svy` demonstrates replicate weight path |
| `calibrate`, `calibrate_rake`, `calibrate_linear`, `calibrate_logit`, `poststratify` | `ns_wave1`, `ns_wave1_svy` | hardcoded US population margins for `gender`, `age_group` |
| `adjust_nonresponse`, `redistribute_weights` | `gss_2024_svy` + `sample()` inline for `response_status` | `gss_2024_svy` is a probability sample — correct context for nonresponse adjustment |
| `calibrate_to_estimate` | `ns_wave1_svy` + hardcoded estimates | |
| `ipw` | `pew_2016_optin` + `pew_2016_synth_pop_svy` | datasets designed for this workflow |
| `create_bootstrap_weights` | `gss_2024_svy` (probability), `ns_wave1_svy` (non-probability) | follow model from `create_jackknife_weights` |
| `create_gen_boot_weights`, `create_gen_rep_weights`, `create_replicate_weights` | `gss_2024_svy` | survey_taylor input |
| `create_brr_weights` | `scd` from `survey` pkg | ⚠ exception: requires 2-PSU/stratum structure not present in package data; verify `survey_taylor` conversion path during implementation |
| `create_sdr_weights` | `as_taylor_design(acs_wy_2022_svy)` | shows functions in natural sequence |
| `as_taylor_design` | `acs_wy_2022_svy` | survey_replicate → survey_taylor |

---

## Tier Classifications

Per `function-documentation.md`, each function's tier determines which sections are required.

| Tier | Functions |
|---|---|
| Tier 1 — Utility | `effective_sample_size`, `weight_variability`, `summarize_weights`, `stabilize_weights`, `as_taylor_design` |
| Tier 2 — Standard | `adjust_nonresponse`, `redistribute_weights`, `calibrate_to_estimate` |
| Tier 3 — Algorithmic | `trim_weights`, `calibrate_rake`, `calibrate_linear`, `calibrate_logit`, `poststratify`, `create_bootstrap_weights`, `create_brr_weights`, `create_gen_boot_weights`, `create_gen_rep_weights`, `create_sdr_weights`, `ipw` |
| Tier 4 — Dispatcher | `calibrate`, `create_replicate_weights` |

---

## Implementation Order

### Phase 1 order (structural)

1. Diagnostics family — `effective_sample_size`, `weight_variability`, `summarize_weights`
2. Utilities family — `trim_weights`, `stabilize_weights`
3. Calibration family — `calibrate_rake`, `calibrate_linear`, `calibrate_logit`, `poststratify`, then `calibrate` (dispatcher last, after siblings are done)
4. Sample calibration — `calibrate_to_estimate`
5. Nonresponse family — `adjust_nonresponse`, `redistribute_weights`
6. Replicate weights — individual functions first, then `create_replicate_weights` (dispatcher last)
7. Propensity — `ipw`
8. `devtools::document()` + `devtools::check()` → PR

### Phase 2 order (examples)

Same family order. After each family:
- Run `devtools::run_examples(package = "surveywts")` scoped to the family's functions
- Fix any warnings/errors before moving to next family
- If a dataset produces spurious warnings, use the nearest clean alternative and note the deviation

---

## Known Risks

| Risk | Mitigation |
|---|---|
| `create_brr_weights` example requires `survey::scd` → `survey_taylor` conversion | Verify conversion path exists before writing example; flag for new package dataset if not |
| Examples on large datasets (`pew_2016_optin`, `npors_2025_svy`) may be slow | Subset rows in example if needed; `\donttest{}` is available as fallback (not `\dontrun{}`) |
| `adjust_nonresponse` / `redistribute_weights`: synthesized `response_status` via `sample()` may produce edge-case cells | Use `set.seed()` in example and verify no zero-weight cells |
