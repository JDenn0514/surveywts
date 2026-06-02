# File Organization Redesign

**Date:** 2026-06-02
**Status:** Approved

## Goal

Establish a consistent file organization where every exported function has a
`.R` file named after it (matching its `.Rd`), helpers are positioned below
their owning export, and helpers shared within a family live in a dedicated
`{family}-utils.R` file. Update `.claude/rules/` so this convention is
enforced for all future function additions and edits.

---

## Governing Rules

1. Every exported function lives in a `.R` file named identically to it
   (matching its `.Rd` filename without the extension).
2. The exported function appears at the top of its file; helpers used only by
   that function appear below it.
3. Helpers shared by 2+ functions in the same family go to `{family}-utils.R`.
4. Helpers used across different families stay in `utils.R`.
5. Structural/role-based files are exempt from rule 1:
   `utils.R`, `methods-print.R`, `zzz.R`, `data.R`, `surveywts-package.R`.

---

## Changes

### Renames (content unchanged)

| Old | New |
|-----|-----|
| `classes.R` | `weighted-df-dplyr.R` |
| `nonprob-ipw.R` | `ipw.R` |
| `nps-group-jackknife.R` | `create_group_jackknife_weights.R` |

### Merges

- **`print.weighted_df`** moves from `classes.R` → `methods-print.R`
- **`replicate-print.R`** merges into `methods-print.R`; `replicate-print.R` is
  deleted
- **`rake-anesrake-engine.R`** merges into `rake.R` below `rake()`, under a
  prominent attribution header; `rake-anesrake-engine.R` is deleted

  Attribution header format:
  ```r
  # ---------------------------------------------------------------------------
  # Ported from the anesrake R package (CRAN: anesrake), GPL-2
  # Original author: Cole Rauwerda. Logic unchanged from upstream.
  # ---------------------------------------------------------------------------
  ```

### Splits

#### Replicate family
`replicate-weights.R` + `replicate-dispatch.R` → 8 function files + 1 utils
file. The two source files are deleted after splitting.

| New file | Export |
|----------|--------|
| `create_bootstrap_weights.R` | `create_bootstrap_weights()` |
| `create_jackknife_weights.R` | `create_jackknife_weights()` |
| `create_brr_weights.R` | `create_brr_weights()` |
| `create_gen_boot_weights.R` | `create_gen_boot_weights()` |
| `create_gen_rep_weights.R` | `create_gen_rep_weights()` |
| `create_sdr_weights.R` | `create_sdr_weights()` |
| `create_replicate_weights.R` | `create_replicate_weights()` |
| `as_taylor_design.R` | `as_taylor_design()` |
| `replicate-utils.R` | helpers shared by 2+ of the above |

#### Nonresponse family
`nonresponse.R` → 2 function files + 1 utils file. Source file deleted.

| New file | Export |
|----------|--------|
| `adjust_nonresponse.R` | `adjust_nonresponse()` |
| `redistribute_weights.R` | `redistribute_weights()` |
| `nonresponse-utils.R` | helpers shared by both |

#### Sample-calibration family
`sample-calibration.R` → 2 function files. Source file deleted. A
`sample-calibration-utils.R` is created only if shared helpers exist between
the two functions; otherwise helpers inline in each file.

| New file | Export |
|----------|--------|
| `calibrate_to_survey.R` | `calibrate_to_survey()` |
| `calibrate_to_estimate.R` | `calibrate_to_estimate()` |

#### Diagnostics family
`diagnostics.R` → 3 function files + 1 utils file. Source file deleted.
`.diag_validate_input` is shared by all three exports and moves to the utils
file.

| New file | Export |
|----------|--------|
| `effective_sample_size.R` | `effective_sample_size()` |
| `weight_variability.R` | `weight_variability()` |
| `summarize_weights.R` | `summarize_weights()` |
| `diagnostics-utils.R` | `.diag_validate_input` and any other shared helpers |

#### Weight utilities family
`weight-utils.R` → 2 function files. Source file deleted. `.check_weight_utils_class`
is assessed during implementation: if it is a simple one-liner it is inlined
in each file; if it is substantive it moves to a `weight-utils.R` (repurposed
as the utils file for this family).

| New file | Export |
|----------|--------|
| `trim_weights.R` | `trim_weights()` |
| `stabilize_weights.R` | `stabilize_weights()` |

---

## Target File Structure

After all changes, `R/` contains:

```
R/
  # One-export-per-file (alphabetical within family)
  adjust_nonresponse.R
  as_taylor_design.R
  calibrate.R                        # already correct
  calibrate_to_estimate.R
  calibrate_to_survey.R
  create_bootstrap_weights.R
  create_brr_weights.R
  create_gen_boot_weights.R
  create_gen_rep_weights.R
  create_group_jackknife_weights.R   # renamed from nps-group-jackknife.R
  create_jackknife_weights.R
  create_replicate_weights.R
  create_sdr_weights.R
  effective_sample_size.R
  ipw.R                              # renamed from nonprob-ipw.R
  poststratify.R                     # already correct
  rake.R                             # gains anesrake engine helpers
  redistribute_weights.R
  stabilize_weights.R
  summarize_weights.R
  trim_weights.R
  weight_variability.R

  # Family utils files
  diagnostics-utils.R
  nonresponse-utils.R
  replicate-utils.R
  sample-calibration-utils.R        # only if shared helpers exist
  weight-utils.R                    # only if .check_weight_utils_class is substantive

  # Structural files (exempt from rule 1)
  data.R
  methods-print.R                   # gains print.weighted_df + survey_replicate print
  surveywts-package.R
  utils.R
  weighted-df-dplyr.R               # renamed from classes.R; loses print.weighted_df
  zzz.R
```

---

## Rules File Updates

### `code-style.md` — Section 4 "Internal helper placement"

Replace the current two-row table with a three-tier rule:

| Helper used by... | Lives in... |
|-------------------|-------------|
| Exactly 1 exported function | Inline in that function's `.R` file, below the export |
| 2+ functions in the same family | `{family}-utils.R` |
| 2+ functions across different families | `utils.R` |

Also update the placement note: helpers go **below** the exported function,
not above it (current wording says "before its first call site").

### `surveywts-conventions.md` — new "File Organization" section

Add a section documenting:
- Rule: one export per `.R` file, filename = function name
- Rule: exported function at top, helpers below
- Rule: `{family}-utils.R` for family-shared helpers; `utils.R` for
  cross-cutting helpers
- Table: exempt structural files and their purpose
- Updated file mapping table reflecting the target structure above

### `testing-surveywts.md` — File Mapping table

Update the "File Mapping" table to replace `R/classes.R` with
`R/weighted-df-dplyr.R` and reflect any other renamed source files. No
structural changes to test files are required as part of this spec.

### `r-package-conventions.md`

No changes required.
