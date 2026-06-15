## Spec Review: calibration-nps-compat — Pass 1 (2026-05-19)

### New Issues

#### Section: II — Architecture

**Issue 1: Shared validation helper omitted despite two call sites in two files**
Severity: REQUIRED
Violates `code-style.md §4`: "When a single-use inline helper grows a second call site, promote it to `utils.R` in the same PR that adds the second call." Also violates `engineering-preferences.md §1`: repeated patterns in 2+ functions → extract a shared internal helper.

The spec explicitly states "No changes to `R/utils.R`... No shared helpers needed" and lists only three steps for each function. But the validation block:

```r
if (!is.null(reference_design) && !S7::S7_inherits(reference_design, surveycore::survey_taylor)) {
  cli::cli_abort(c("x" = "...", "i" = "..."), class = "surveywts_error_reference_design_not_taylor")
}
```

is identical in both `rake.R` and `calibrate.R` — two separate source files. This is precisely the case `code-style.md §4` addresses. The spec overrides the rule without justifying the exception.

Options:
- **[A]** Add `.validate_reference_design(reference_design)` to `R/utils.R`; each function calls it once immediately after argument capture. — Effort: low, Risk: low, Impact: eliminates duplication and the divergence risk if message text is updated in one place but not the other, Maintenance: none
- **[B]** Keep inline in both files but add an explicit rule-exception note in the spec. — Effort: low, Risk: low, Impact: the violation stays but is acknowledged, Maintenance: must keep two copies in sync
- **[C] Do nothing** — Rule violation goes undocumented; message text may diverge between functions over time.

**Recommendation: A** — The helper is trivial; adding it to `utils.R` costs nothing and follows the project's established pattern (e.g., `.validate_weights()`).

---

#### Section: III — Changes to `rake()`

**Issue 2: `type` missing from `rake()` history entry — bootstrap replay cannot correctly replay `rake()`**
Severity: REQUIRED
Violates the bootstrap replay contract stated in §VIII. The spec is written to enable quasi-randomization bootstrap replay of `rake()`. Replay requires knowing whether `margins` were proportions (`type = "prop"`) or counts (`type = "count"`), since the same numeric values mean different things under each interpretation.

The current `rake()` parameters list (confirmed in source) stores `variables`, `margins`, `method`, `cap`, `control` — but not `type`. `calibrate()` does store `type`. The spec's §III parameters list adds `targets_from_reference` and `reference_design` but continues to omit `type`:

```r
parameters = list(
  variables            = margin_var_names,
  margins              = margins_a,          # Format A — no type context
  method               = method,
  cap                  = cap,
  control              = control_resolved,
  targets_from_reference = ...,              # new
  reference_design     = reference_design    # new
)
```

The bootstrap replay pseudo-code in §VIII says:
> `rake(resampled_nonprob, margins = entry$parameters$margins, method = entry$parameters$method, ...)`

Without `type` in `...`, the bootstrap always defaults to `type = "prop"`. A `rake()` call originally made with `type = "count"` would be replayed incorrectly with no error.

Options:
- **[A]** Add `type = type` to the `parameters` list in §III alongside the new fields. — Effort: trivial, Risk: low, Impact: bootstrap replay is correct for all users; §VIII pseudo-code updated to include `type = entry$parameters$type`, Maintenance: none
- **[B]** Declare the bootstrap replay contract assumes `type = "prop"` and document it. — Effort: low, Risk: medium (silently wrong for count users), Impact: restricts the API, Maintenance: ongoing restriction
- **[C] Do nothing** — Bootstrap silently replays with wrong `type` for any user who raked to count targets.

**Recommendation: A** — This is a one-line addition that closes a silent correctness hole. Since the spec is already modifying the `parameters` list, this is the right moment to fix it.

---

#### Section: VI — Testing

**Issue 3: `test_invariants()` absent from happy-path test blocks**
Severity: REQUIRED
Violates `testing-surveywts.md`: "Every `test_that()` block that creates a `weighted_df` or `survey_nonprob` object must call `test_invariants(obj)` as its **first** assertion."

Both happy-path blocks in §VI produce a result from `rake()` or `calibrate()` and then immediately inspect `attr(result, "weighting_history")[[1L]]`. Neither block calls `test_invariants(result)` first. Example from spec:

```r
test_that("rake() records reference_design and targets_from_reference = TRUE in history", {
  result <- rake(data, margins = margins, reference_design = ref_taylor)
  entry <- attr(result, "weighting_history")[[1L]]
  expect_true(entry$parameters$targets_from_reference)     # ← no test_invariants() call
  expect_identical(entry$parameters$reference_design, ref_taylor)
})
```

Options:
- **[A]** Add `test_invariants(result)` as the first assertion in all four happy-path blocks specified in §VI. — Effort: trivial, Risk: none, Impact: complies with the project testing standard, Maintenance: none
- **[B] Do nothing** — Test blocks violate the documented testing invariant; any future invariant regression on these code paths goes undetected.

**Recommendation: A** — Mandatory per project standards; trivial to add.

---

#### Section: V — Error Table

**Issue 4: `"i"` bullet wording inconsistent with codebase style; no `"v"` bullet**
Severity: SUGGESTION
`code-style.md §3` examples show the `"i"` bullet as `"Got class {.cls ...}."` (with the word "class" before the markup). The spec omits "class":

```
"i" = "Got {.cls {class(reference_design)[[1L]]}}."
```

Existing error messages in the codebase consistently use `"Got class {.cls {class(...)}}."`. Additionally, the error is fixable: the user knows exactly what to pass (`survey_taylor`). A `"v"` bullet is recommended by `code-style.md §3` "when fixable."

Options:
- **[A]** Change `"i"` to `"Got class {.cls {class(reference_design)[[1L]]}}."` and add `"v" = "Pass the {.cls survey_taylor} object used to compute the targets."` — Effort: trivial, Risk: none, Impact: consistent with codebase style and `code-style.md §3`, Maintenance: none
- **[B]** Keep as is — Effort: none, Impact: minor inconsistency with message style across the codebase
- **[C] Do nothing** — Same as B.

**Recommendation: A** — Trivial fix; no reason to diverge from the established message style.

---

#### Section: II — Architecture / Section: III, IV — Parameters

**Issue 5: Spec does not explicitly state that `reference_design` content is not validated**
Severity: SUGGESTION
The spec says "reference_design participates in no computation; it is recorded only" and "No behavioral change." This implies no content validation (e.g., `reference_design` with 0 rows, or whose variables don't overlap with the margin/calibration variables, is accepted silently). But it is not stated explicitly.

A future implementer reading only §III/IV might add "helpful" content validation (e.g., checking that `reference_design` has the variables named in `margins`). This would be incorrect over-engineering that also creates a false dependency between `reference_design` and the specific variables being raked.

Additionally, a user passing the wrong `survey_taylor` (one that doesn't contain the needed variables) will not get an error at `rake()` time — they will fail later inside `create_bootstrap_weights()`. The spec should acknowledge this tradeoff explicitly so the bootstrapper knows where to validate.

Options:
- **[A]** Add a sentence to §II and §III/IV: "No content validation of `reference_design` is performed beyond the class check. Mis-specified `reference_design` objects are detected at bootstrap-replay time, not at recording time." — Effort: trivial, Risk: none, Impact: prevents future over-engineering; documents the validation boundary, Maintenance: none
- **[B] Do nothing** — Implementers may add unneeded validation; the boundary between recording-time and replay-time validation stays implicit.

**Recommendation: A** — One sentence; eliminates an implementation guess.

---

### Summary (Pass 1)

| Severity | Count |
|---|---|
| BLOCKING | 0 |
| REQUIRED | 3 |
| SUGGESTION | 2 |

**Total issues:** 5

**Overall assessment:** The spec is nearly implementable — the change is small, well-scoped, and backward-compatible. Three required issues must be resolved before coding begins: the shared validation helper (rules compliance), the missing `type` field in the rake history (silent correctness hole for bootstrap replay), and the missing `test_invariants()` calls. The two suggestions are trivial and can be bundled into Stage 4 resolution.
