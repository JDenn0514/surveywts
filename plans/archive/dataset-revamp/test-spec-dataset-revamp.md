# Test-spec — dataset-revamp

---

## Reference oracle

No numerical oracle (no statistical estimators implemented). Structural
verification uses direct inspection of dataset attributes and classes.

---

## Datasets

- All 14 new objects loaded via `data()`: each test block calls `data()` at
  the top to ensure the object is loadable from the package.
- Inline edge-case data: not applicable (no functions added).

---

## Per-Object Test Plan

### Presence / absence of objects

**Happy path — new objects loadable:**

| Test | Check |
|---|---|
| `data("gss_2024")` succeeds | `exists("gss_2024")` is `TRUE` |
| `data("gss_2024_svy")` succeeds | `exists("gss_2024_svy")` is `TRUE` |
| `data("npors_2025")` succeeds | `exists("npors_2025")` is `TRUE` |
| `data("npors_2025_svy")` succeeds | `exists("npors_2025_svy")` is `TRUE` |
| `data("npors_2025_clean")` succeeds | `exists("npors_2025_clean")` is `TRUE` |
| `data("npors_2025_clean_svy")` succeeds | `exists("npors_2025_clean_svy")` is `TRUE` |
| `data("acs_wy_2022")` succeeds | `exists("acs_wy_2022")` is `TRUE` |
| `data("acs_wy_2022_svy")` succeeds | `exists("acs_wy_2022_svy")` is `TRUE` |
| `data("pew_2016_optin_svy")` succeeds | `exists("pew_2016_optin_svy")` is `TRUE` |
| `data("pew_2016_synth_pop_svy")` succeeds | `exists("pew_2016_synth_pop_svy")` is `TRUE` |
| `data("ns_wave1")` succeeds | `exists("ns_wave1")` is `TRUE` |
| `data("ns_wave1_svy")` succeeds | `exists("ns_wave1_svy")` is `TRUE` |

**Retired objects gone:**

| Test | Check |
|---|---|
| `gss_ipw_ref` not loadable | `data("gss_ipw_ref", package = "surveywts")` throws an error |
| `npors_2025_ref` not loadable | `data("npors_2025_ref", package = "surveywts")` throws an error |
| `npors_2025_clean_ref` not loadable | `data("npors_2025_clean_ref", package = "surveywts")` throws an error |
| `acs_ipw_ref` not loadable | `data("acs_ipw_ref", package = "surveywts")` throws an error |
| `ns_wave1_ipw` not loadable | `data("ns_wave1_ipw", package = "surveywts")` throws an error |

---

### `gss_2024`

**Structural:**
- `inherits(gss_2024, "data.frame")` is `TRUE`
- `ncol(gss_2024) == 30` (27 original + gender + age_group + wt_pop)
- `nrow(gss_2024) == nrow(surveycore::gss_2024)` (all rows retained)
- `"gender" %in% names(gss_2024)` is `TRUE`
- `"age_group" %in% names(gss_2024)` is `TRUE`
- `"wt_pop" %in% names(gss_2024)` is `TRUE`
- `is.factor(gss_2024$gender)` is `TRUE`
- `is.factor(gss_2024$age_group)` is `TRUE`
- `is.numeric(gss_2024$wt_pop)` is `TRUE`
- `all(gss_2024$wt_pop[!is.na(gss_2024$wtssps)] > 0)` is `TRUE`
- `levels(gss_2024$gender)` is `c("Male", "Female")`
- `levels(gss_2024$age_group)` is `c("18-34", "35-54", "55+")`
- `"vpsu" %in% names(gss_2024)` is `TRUE` (original col preserved)
- `"vstrat" %in% names(gss_2024)` is `TRUE` (original col preserved)
- `"wtssps" %in% names(gss_2024)` is `TRUE` (original col preserved)
- `wt_pop` relationship to `wtssps`: `sum(gss_2024$wt_pop, na.rm = TRUE) / sum(gss_2024$wtssps, na.rm = TRUE)` ≈ `260000000 / sum(gss_2024$wtssps, na.rm = TRUE)` (tolerance `1e-3`)

**Derived column correctness:**
- For rows where `gss_2024$sex == 1L` and `!is.na(gss_2024$sex)`:
  `gss_2024$gender[gss_2024$sex == 1L & !is.na(gss_2024$sex)]` are all `"Male"`
- For rows where `gss_2024$sex == 2L` and `!is.na(gss_2024$sex)`:
  all `"Female"`
- `sum(!is.na(gss_2024$gender)) == sum(gss_2024$sex %in% c(1L, 2L), na.rm = TRUE)`

---

### `gss_2024_svy`

- `S7::S7_inherits(gss_2024_svy, surveycore::survey_taylor)` is `TRUE`
- `nrow(gss_2024_svy@data) == nrow(gss_2024)` (same rows)
- `gss_2024_svy@variables$weights == "wtssps"` (uses normalized weight, not wt_pop)
- All weights strictly positive: `all(gss_2024_svy@data[["wtssps"]] > 0, na.rm = TRUE)`

---

### `npors_2025`

**Structural:**
- `inherits(npors_2025, "data.frame")` is `TRUE`
- `nrow(npors_2025) == 5022`
- `ncol(npors_2025) == 69` (64 original + gender + age_group + race_ethn + educ + wt_pop)
- Derived columns present: `all(c("gender", "age_group", "race_ethn", "educ", "wt_pop") %in% names(npors_2025))` is `TRUE`
- `gender`, `age_group`, `race_ethn`, `educ` are factors; `wt_pop` is numeric
- Level sets:
  - `levels(npors_2025$gender)` == `c("Male", "Female")`
  - `levels(npors_2025$age_group)` == `c("18-34", "35-54", "55+")`
  - `levels(npors_2025$race_ethn)` == `c("White", "Black", "Hispanic", "Asian", "Other")`
  - `levels(npors_2025$educ)` == `c("Less than HS", "HS/Some college", "College+")`
- Original columns preserved: `"weight" %in% names(npors_2025)` is `TRUE`
- NA rates in derived cols ≤ 1%: `mean(is.na(npors_2025$gender)) < 0.01` etc.
- `wt_pop` all positive for non-NA `weight` rows

---

### `npors_2025_svy`

- `S7::S7_inherits(npors_2025_svy, surveycore::survey_taylor)` is `TRUE`
- `nrow(npors_2025_svy@data) == 5022`
- `npors_2025_svy@variables$weights == "weight"` (normalized weight, not wt_pop)
- All weights positive (where non-NA)

---

### `npors_2025_clean`

- `inherits(npors_2025_clean, "data.frame")` is `TRUE`
- `nrow(npors_2025_clean) < nrow(npors_2025)` (rows with NA removed)
- `nrow(npors_2025_clean) > 4700` (sanity: fewer than 400 rows dropped)
- All of `gender`, `age_group`, `race_ethn`, `educ` have zero NAs:
  `sum(is.na(npors_2025_clean$gender)) == 0L` etc.
- Same columns as `npors_2025`

---

### `npors_2025_clean_svy`

- `S7::S7_inherits(npors_2025_clean_svy, surveycore::survey_taylor)` is `TRUE`
- `nrow(npors_2025_clean_svy@data) == nrow(npors_2025_clean)`

---

### `acs_wy_2022`

**Structural:**
- `inherits(acs_wy_2022, "data.frame")` is `TRUE`
- `nrow(acs_wy_2022) == 4736` (adults only)
- All adults: `all(acs_wy_2022$agep >= 18L)` is `TRUE`
- Original replicate columns present: `"pwgtp" %in% names(acs_wy_2022)` is `TRUE`
- `"pwgtp1" %in% names(acs_wy_2022)` is `TRUE`
- `"pwgtp80" %in% names(acs_wy_2022)` is `TRUE`
- Derived columns present and factored:
  - `is.factor(acs_wy_2022$gender)` is `TRUE`
  - `is.factor(acs_wy_2022$age_group)` is `TRUE`
  - `is.factor(acs_wy_2022$race_ethn)` is `TRUE`
  - `is.factor(acs_wy_2022$educ)` is `TRUE`
- No NAs in derived cols: `sum(is.na(acs_wy_2022$educ)) == 0L` etc.

---

### `acs_wy_2022_svy`

- `S7::S7_inherits(acs_wy_2022_svy, surveycore::survey_replicate)` is `TRUE`
- `nrow(acs_wy_2022_svy@data) == 4736`
- Weight column is `"pwgtp"` or equivalent: `gss_2024_svy@variables$weights` check pattern applies
- Replicate weights present: verify number of replicate columns (should be 80)

---

### `pew_2016_optin_svy`

- `S7::S7_inherits(pew_2016_optin_svy, surveycore::survey_nonprob)` is `TRUE`
- `nrow(pew_2016_optin_svy@data) == 31863`
- Weight column all equal to 1L: `all(pew_2016_optin_svy@data[[pew_2016_optin_svy@variables$weights]] == 1L)` is `TRUE`
- The underlying data does NOT contain `equal_wt` as a column name in
  `pew_2016_optin` tibble (only in the svy companion's data): confirm
  `"equal_wt" %in% names(pew_2016_optin)` is `FALSE`

---

### `pew_2016_synth_pop_svy`

- `S7::S7_inherits(pew_2016_synth_pop_svy, surveycore::survey_taylor)` is `TRUE`
- `nrow(pew_2016_synth_pop_svy@data) == 20000`
- Weight column all equal to 1L: same check as above

---

### `ns_wave1`

**Structural:**
- `inherits(ns_wave1, "data.frame")` is `TRUE`
- `nrow(ns_wave1) == 6422`
- `ncol(ns_wave1) == 174` (171 original cols with `gender` overwritten in-place
  + 3 new cols: `age_group`, `race_ethn`, `educ`)
- `is.factor(ns_wave1$gender)` is `TRUE`
- `levels(ns_wave1$gender)` == `c("Male", "Female")`
- `is.factor(ns_wave1$age_group)` is `TRUE`
- `is.factor(ns_wave1$race_ethn)` is `TRUE`
- `is.factor(ns_wave1$educ)` is `TRUE`
- `"weight" %in% names(ns_wave1)` is `TRUE` (original weight col preserved)
- `sum(is.na(ns_wave1$race_ethn)) > 0L` (expected ~419 NAs from race code 15)

---

### `ns_wave1_svy`

- `S7::S7_inherits(ns_wave1_svy, surveycore::survey_nonprob)` is `TRUE`
- `nrow(ns_wave1_svy@data) == 6422`
- Weight column is `"weight"`: `ns_wave1_svy@variables$weights == "weight"`
- All weights positive: `all(ns_wave1_svy@data[["weight"]] > 0)`

---

## Documentation tests (R CMD check)

- `devtools::check()` must produce 0 errors, 0 warnings.
- In particular: NO `code/documentation mismatches` warning from `codoc`.
  This requires every column in each tibble to have a matching `\item{}`
  entry in the `@format` `\describe{}` block.
- `devtools::document()` run produces no NAMESPACE/man/ drift.

---

## Example tests

- `devtools::run_examples()` runs clean (no errors, no unexpected warnings)
  for `ipw.Rd` (the updated examples).
- The example that previously used `acs_ipw_ref` now uses `acs_wy_2022`
  tibble inline-wrapped as a `survey_taylor` — verify it runs without error.

---

## `acs_wy_2022_svy` incompatibility with `ipw()`

`ipw()` requires a `survey_taylor` reference; `acs_wy_2022_svy` is
`survey_replicate`. Test that the expected error is thrown:

```r
data(acs_wy_2022_svy)
data(ns_wave1)
expect_error(
  ipw(ns_wave1, acs_wy_2022_svy, selection = ~gender + age_group),
  class = "surveywts_error_svydesign_not_taylor"
)
```

---

## Integration: `ipw()` still works with new reference datasets

Users construct IPW reference designs using the `wt_pop` column from tibbles:

```r
data(ns_wave1); data(gss_2024)
gss_ref <- surveycore::as_survey(gss_2024, weights = wt_pop,
                                  strata = vstrat, ids = vpsu, nest = TRUE)
result <- ipw(ns_wave1, gss_ref, selection = ~gender + age_group)
```

- `ipw(ns_wave1, gss_ref, selection = ~gender + age_group)` completes without
  error (no warnings about `nps_fraction > 1`); returns `survey_nonprob` with
  non-trivial, non-equal weights
- `S7::S7_inherits(result, surveycore::survey_nonprob)` is `TRUE`
- `"ipw_weight" %in% names(result@data)` is `TRUE`

Same check for NPORS:
```r
data(npors_2025_clean)
npors_ref <- surveycore::as_survey(npors_2025_clean, weights = wt_pop)
result2 <- ipw(ns_wave1, npors_ref,
               selection = ~gender + age_group + race_ethn + educ,
               missing_method = "omit")
```
Completes without error; returns valid `survey_nonprob`.

---

## Tolerances

N/A — no numerical quantities computed. All assertions are structural
(`expect_identical`, `expect_true`, `expect_equal` on integers/logicals).

---

## Profile gates (tester runs ALL)

- [ ] `devtools::document()` — NAMESPACE/man/ unchanged after run
- [ ] `devtools::test()` — all tests pass
- [ ] `devtools::run_examples()` — all `@examples` run clean
- [ ] `devtools::check()` — 0 errors, 0 warnings, ≤2 pre-approved notes;
      `codoc` warning is a BLOCK
- [ ] `pkgdown::build_reference()` — reference index renders without errors
- [ ] `covr::package_coverage()` — coverage maintained (data-only change;
      coverage may not change materially)
