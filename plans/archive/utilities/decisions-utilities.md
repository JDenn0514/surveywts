# Decisions Log — surveywts utilities

This file records planning decisions made during the Utilities phase.
Each entry corresponds to one planning session.

---

## 2026-05-18 — Methodology lock: trim_weights() and stabilize_weights()

### Context

Resolved all 9 methodology issues from Passes 1 and 2 of the utilities
methodology review. Seven issues were unambiguous; two required judgment calls.

### Questions & Decisions

**Q: How much variance documentation should the spec add for `trim_weights()` and `stabilize_weights()`?**
- Options considered:
  - **Option A (full paragraph):** Add a "Variance Implications" section to §III and §IV explaining direction and magnitude of SE changes.
  - **Option B (two sentences per function):** Add concise, actionable sentences to the Purpose text — enough to guide informed users without restating survey methods basics.
  - **Option C (do nothing):** Leave variance implications undocumented.
- **Decision:** Two sentences per function (between A and B).
- **Rationale:** Users trimming weights typically understand the bias-variance tradeoff. A full paragraph would over-explain known concepts. Two sentences convey the practical implications (SE direction for Taylor; automatic capture for replicate) without being redundant.

**Q: Replicate column sum-preservation gap (Issue 8) — document the exception only (A) or also emit a warning (B)?**
- Options considered:
  - **Option A:** Amend step 7's closing sentence and the test plan to document the edge case. No new warning class.
  - **Option B:** Same documentation fix, plus a new warning when `sum(!outside_j) == 0` for any replicate column.
- **Decision:** Option A — document the exception only.
- **Rationale:** The all-outside-bounds replicate column case is pathological and extremely rare in practice. The main weight analogue (`surveywts_warning_trimming_failed`) already covers the visible failure mode. Adding a new warning class for the replicate-column edge case would add implementation overhead for a case users would almost never encounter; the documented exception in the contract is sufficient.

### Outcome

The spec is methodology-locked at version 0.4. All 9 issues resolved: 7 unambiguous
documentation fixes applied directly; 2 judgment calls resolved with lightweight
documentation additions. No implementation logic changes required.

---

## 2026-05-18 — Code-review resolve: utilities spec (Stage 4)

### Context

Worked through all 11 issues from the Stage 3 spec review. Three were blocking gaps
in the `survey_replicate` path of `trim_weights()`; the rest were one-sentence
clarifications. Two design questions required judgment calls.

### Questions & Decisions

**Q: Should `stabilize_weights()` support `survey_replicate` input?**
- Options considered:
  - **Remove replicate support (original spec):** Error on replicate input, simplifying scope.
  - **Add replicate support:** Apply the same scale factor uniformly to main weights and
    all replicate columns, preserving design consistency.
- **Decision:** Support `survey_replicate` — apply scale factor uniformly to main and
  all replicate weight columns.
- **Rationale:** The user identified that the original error was an arbitrary scope
  limitation, not a technical constraint. The safe approach (same factor everywhere) is
  straightforward and mirrors how `trim_weights()` already handles replicates. `survey`
  not having this function is not a reason to restrict it.

**Q: How should both functions validate input class, given neither can use `.check_input_class()` (which errors on replicate)?**
- Options considered:
  - **Shared file-local helper:** Define `.check_weight_utils_class()` at the top of
    `R/weight-utils.R`, used by both functions in that file.
  - **Inline check per function:** Each function does its own `S7::S7_inherits()` check.
  - **Extend `.check_input_class()`:** Add `allow_replicate =` parameter.
- **Decision:** Shared file-local helper `.check_weight_utils_class()` at the top of
  `R/weight-utils.R`.
- **Rationale:** Both functions are in the same file and have identical acceptance rules
  (all 5 classes). DRY applies within-file; no need to touch `utils.R` or the existing
  `.check_input_class()` helper.

### Outcome

Spec updated to v0.5 (code-review approved). All 11 issues resolved: 3 blocking gaps
in `survey_replicate` support closed; `stabilize_weights()` extended to support all
5 input classes; `wt_name` validation placement added; attribution corrected to
"adapted from"; warning behavior for `upper = Inf` documented.

---

## 2026-05-18 — Spec review resolve Pass 2: utilities (Stage 4)

### Context

Resolved 5 issues from Pass 2 of the Stage 3 spec review. All were driven by
existing conventions or test-plan precision gaps; no new scope or behavior changes.

### Questions & Decisions

**Q: Should `trim_weights()` and `stabilize_weights()` follow `code-style.md` §4 argument order (`weights` before optional scalars)?**
- Options considered:
  - **Reorder to convention:** `weights = NULL` immediately after `data`, before all scalar options.
  - **Keep as-is with documented exception:** Accept the deviation.
- **Decision:** Reorder both signatures to convention.
- **Rationale:** `code-style.md` §4 is explicit. Every other surveywts function with `weights` and scalar options (`calibrate()`, `rake()`, `poststratify()`, `adjust_nonresponse()`) follows the same order. No reason for an exception.

**Q: For `stabilize_weights()`, should `weights` or `by` come first (both are optional NSE/Category 4)?**
- Options considered:
  - **`(data, weights, by, wt_name)`:** Matches `summarize_weights()` precedent.
  - **`(data, by, weights, wt_name)`:** Keep existing order.
- **Decision:** `(data, weights, by, wt_name)` — matches `summarize_weights()`.
- **Rationale:** `code-style.md` doesn't specify within-Category 4 order, but `summarize_weights()` is the closest analogous function. Consistency with it is cheap and prevents user confusion when comparing signatures.

### Outcome

Spec updated to v1.0 (approved for implementation). All 5 Pass 2 issues resolved:
argument order corrected for both functions; `k = c(1, 2)` test case added;
explicit per-group replicate formula added to numerical tests; no-op test block
updated to note expected warning.

---

## 2026-05-18 — Implementation plan review resolve: utilities (Stage 3)

### Context

Worked through all 8 issues from the Stage 2 plan review. Four were REQUIRED fixes
(missing changelog entries, unassigned variable, wrong nrow pattern); four were
SUGGESTIONS. All resolved in one pass with no new scope changes.

### Questions & Decisions

No judgment calls required — all 8 issues had unambiguous recommended fixes (Option A)
that the user approved. Changes were mechanical plan corrections: adding missing file
paths, fixing a variable assignment, aligning with the established `data_df` extraction
pattern, qualifying an ambiguous acceptance criterion, adding example guidance for
consistency with `trim_weights()`, and adding the `error-class-auditor` quality gate.

### Outcome

Implementation plan approved at `plans/impl-utilities.md`. All 8 issues resolved.
Ready to hand off to `/r-implement` starting with PR 1 (`feature/weight-utils-infra`).

---
