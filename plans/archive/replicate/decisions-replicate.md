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

`create_*_weights()` adds a `"replicate_creation"` history entry with a full
snapshot of the input design's `@variables` list (per Q22, widened from the
original `ids`/`strata`/`fpc`/`nest` subset). `as_taylor_design()` reads
from the most recent `"replicate_creation"` entry.

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
| `use_normal_hadamard` | **Expose** on create_sdr_weights() — reversed 2026-09-03, #119 |

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

---

## Follow-up Decisions (resolved 2026-04-18)

Q11–Q22 are ergonomic follow-ups to the §XI decisions above. Full rationale
lives in `plans/open-questions-replicate.md`.

---

## Q11: Accepted Input Classes for `data`

**Decision:** surveycore classes only.

Do not accept raw `survey::svydesign` or `srvyr::tbl_svy`. Users wrap once
with `surveycore::from_svydesign()`.

---

## Q12: Call Ergonomics — Method Strings, Defaults, Positionality

**Decision:**

- Dispatcher method strings use full names: `"generalized-bootstrap"`,
  `"generalized-replicate"`, `"successive-difference"`, plus the common
  short names `"bootstrap"`, `"jackknife"`, `"brr"`.
- `replicates` default is method-specific: `500L` for bootstrap and gen-boot;
  `100L` for SDR; no default for BRR and jackknife.
- Only `data` and `replicates` are positional. All other arguments are
  name-only, enforced by placing them after `...` in the signature.

---

## Q13: Dispatcher `...` Passthrough

**Decision:** Option A — `...` forwarded as-is.

Invalid arguments for the selected method surface as R's native
"unused argument" error from the target function. No duplicate validation
in the dispatcher.

---

## Q14: NSE vs. String for Column Name Arguments

**Decision:** Option B — NSE / tidy-select.

- `sort_var` in `create_sdr_weights()` — single bare name
- `aux_var_names` in gen-boot / gen-rep — tidy-select expression

Resolve to strings internally via `rlang::as_name(rlang::enquo(...))` or
`tidyselect::eval_select()` before the backend call.

---

## Q15: Seed Control for Stochastic Methods

**Decision:** Option B — `seed = NULL` argument via `withr::local_seed()`.

Applies to `create_bootstrap_weights()`, `create_gen_boot_weights()`, and
`create_jackknife_weights()` (active only for `type = "random-groups"`).
`seed = NULL` uses the caller's current RNG state; an integer sets the seed
internally and restores the previous state on exit.

---

## Q16: Backend Error Wrapping

**Decision:** Option C — wrap known failure modes reactively.

Phase 1 ships with zero wrapped modes. Named `surveywts_error_*` classes and
focused `tryCatch()` blocks are added as integration tests surface backend
errors whose messages we can improve.

---

## Q17: `replicates` Numeric Coercion

**Decision:** Option A — accept numeric whole numbers, coerce silently to
integer.

`replicates = 200` and `replicates = 200L` behave identically. Fractional
input errors with `surveywts_error_replicates_not_whole_number`.

---

## Q18: `survey_nonprob` + Jackknife Scope

**Decision:** Option A — delete-1 only.

`create_jackknife_weights(data, type = "random-groups")` with a
`survey_nonprob` errors with
`surveywts_error_jackknife_type_unsupported_for_nonprob`. Message points
the user at delete-1.

---

## Q20: Replicate Weight Column Naming

**Decision:** Option A — uniform `rep_1, rep_2, …, rep_N`.

surveywts renames the backend's replicate columns post-conversion so column
naming is consistent across methods. Method is already recorded in history,
so encoding it in the column name is redundant.

---

## Q21: Progress Messaging

**Decision:** Option A — silent.

Matches Phase 0 functions. Adding an opt-in verbose mode later is
non-breaking if demand emerges.

---

## Q22: `as_taylor_design()` on Calibrated Replicate Designs

**Decision:** Phase 1 errors with
`surveywts_error_taylor_from_calibrated_replicate`. Behavioral choice
(pre-calibration Taylor vs. calibrated Taylor vs. permanent error) is
deferred to the replicate-calibration phase.

**Structural requirement for Phase 1:** the `"replicate_creation"` history
entry stores a snapshot of the input design's `@variables` list, preserving
all three future options without schema change.

---

## [2026-04-18] — Spec-review Pass 1 resolution (Issues 1–16)

### Context

Worked through 16 issues from `plans/spec-review-replicate.md` (2 BLOCKING,
11 REQUIRED, 3 SUGGESTION) in Stage 4 of spec-workflow. The spec went from
v1.1 → v1.2.

### Questions & Decisions

**Q: §II.a pseudocode drops the `"replicate_creation"` history entry (Issue 1).**
- **Decision:** Option A — rewrite the pseudocode to show metadata copy,
  history-entry append with `source_design = .snapshot_variables_for_history(data)`,
  and column rename via `.rename_rep_cols()`.
- **Rationale:** Pseudocode is load-bearing for implementers; it must
  reflect the §II.e + Q9 + Q22 resolution.

**Q: `surveycore` minimum version unstated (Issue 2).**
- **Decision:** Option A — add a `surveycore (>= X.Y.Z)` bump note to §II.c;
  implementer pins the exact value at implementation time.
- **Rationale:** `r-package-conventions.md` §3 requires minimum versions for
  new feature dependencies.

**Q: Error tables omit `surveywts_error_replicates_not_whole_number` (Issue 3).**
- **Decision:** Option A — add the row to §III, §VI, §VIII error tables.

**Q: Output `@variables` contracts cover only a subset of the eight keys
(Issues 4 & 5).**
- **Decision:** Option B — add a cross-cutting §II.h table listing
  post-conversion values for all eight keys across all six methods.
  Subsumes Issue 5.
- **Rationale:** DRY (engineering-preferences §1); one table is easier to
  audit than six per-function subsections.

**Q: `create_brr_weights()` and `create_gen_rep_weights()` signatures omit
`...`, violating Q12 (Issue 6).**
- **Decision:** Option A — insert `...` after `data` in both signatures.
- **Rationale:** Q12 is the canonical call-ergonomics rule; exceptions
  would require amending it.

**Q: BRR PSU-count-per-stratum validation path unspecified (Issue 7).**
- **Decision:** Option A — add a §V Validation block with a four-step
  pre-backend procedure (nonprob rejection → missing strata/ids →
  unique-PSU counts per stratum → `rho` range).
- **Rationale:** §II.f already commits to pre-backend validation; the spec
  has to say how.

**Q: `sort_var = NULL` NSE resolution under-specified (Issue 8).**
- **Decision:** Option A — use `rlang::quo_is_null()` to branch; pass NULL
  through to `svrep`'s `sort_variable`.
- **Rationale:** `rlang::as_name(rlang::enquo(NULL))` returns the literal
  string `"NULL"`, which would fail downstream.

**Q: Dispatcher test plan uses stale method strings (Issue 9).**
- **Decision:** Option A — update §XIII block 14 to Q12 canonical names
  (`"generalized-bootstrap"`, `"generalized-replicate"`,
  `"successive-difference"`).

**Q: `as_taylor_design()` behavior on nonprob-sourced replicate undefined
(Issue 10).**
- Options considered:
  - **A1:** Error in Phase 1 with `surveywts_error_taylor_from_nonprob_replicate`;
    defer symmetric nonprob inverse to a future phase.
  - **A2:** Same error, no deferred note.
  - **B:** Extend `as_taylor_design()` to return `survey_nonprob` when
    source was nonprob — breaks the §X return-type contract.
- **Decision:** A1.
- **Rationale:** Preserves the §X "returns `survey_taylor`" contract.
  Reconstruction is safe for nonprob (base weights are preserved through
  the round-trip) but belongs in a separate, symmetrically named inverse,
  which is out of Phase 1 scope.

**Q: Error-class test coverage incomplete across five functions (Issue 11).**
- **Decision:** Option A — expand §XIII so every error-table row gets a
  class + snapshot test. Added blocks 3e, 5c/d/e, 9E, 10E, 12b/c, 13c/d,
  17c/d.
- **Rationale:** `testing-standards.md` §2 requires coverage for every
  typed error class.

**Q: No numerical-equivalence tests for JK, gen-boot, gen-rep, SDR
(Issue 12).**
- **Decision:** Option A — add equivalence blocks (4.E, 9.X, 10.X, 11.E)
  for all six backends at tolerance `1e-10`.
- **Rationale:** §XV quality gate mandates equivalence verification for
  all backends.

**Q: No test for `surveywts_error_taylor_from_calibrated_replicate`
(Issue 13).**
- **Decision:** Subsumed by Issue 11 (§XIII.17c now covers it).

**Q: Q10 approved a print method but spec has no section for it
(Issue 14).**
- **Decision:** Option A — add §X.5 with output contract, verbatim example,
  test block §XIII.18, and a new `R/replicate-print.R` file in §II.d.
- **Rationale:** Q10 already committed to the method; the spec must close
  the loop.

**Q: `surveywts_warning_delete1_many_replicates` is orphaned (Issue 15).**
- **Decision:** Option B — drop the class from §XII.
- **Rationale:** No trigger was decided, no test written, no roxygen note.
  Non-breaking to add later if demand appears.

**Q: Three shared errors duplicated across six function tables
(Issue 16).**
- **Decision:** Option A — add §II.i "Shared Input-Class Errors" with the
  three rows (`not_survey_design`, `unsupported_class`, `already_replicate`);
  per-function tables drop those rows and cite §II.i.
- **Rationale:** DRY (engineering-preferences §1); paired naturally with
  Issue 4's §II.h adoption.

### Outcome

Spec is at v1.2 with all 16 issues resolved. Two new error classes
(`surveywts_error_taylor_from_nonprob_replicate`) and one removed warning
class (`surveywts_warning_delete1_many_replicates`). Two new §II
subsections (§II.h output contract, §II.i shared errors). New §X.5 print
method section and §XIII.18 test block. Spec is code-quality-locked and
ready for `/implementation-workflow`.

---

## 2026-04-18 — Spec-Review Pass 2 Resolution (Issues 17–22)

### Context

Second adversarial spec-review pass after Pass 1 edits. Six new issues
surfaced: one blocking (nonprob detection mis-identifies SRS Taylor), one
required (missing nonprob rejection path for gen-boot/gen-rep/SDR), four
suggestions. All resolved; spec advanced from v1.2 to v1.3.

### Questions & Decisions

**Q: Nonprob detection in `as_taylor_design()` false-positives on SRS
`survey_taylor` (Issue 17, BLOCKING).**
- Options considered:
  - **A:** Store `source_class` tag in history snapshot; detect by class
    name. Identity-based, not shape-based.
  - **B:** Schema-shape heuristic (only `@variables$weights` set). Fragile;
    couples to surveycore internals.
  - **C:** Do nothing.
- **Decision:** Option A.
- **Rationale:** `engineering-preferences §5` (explicit over clever). An SRS
  Taylor design has the same `ids = NULL`/`strata = NULL` shape as a
  `survey_nonprob`; only the stored class tag can disambiguate. Also adds
  test block 17e verifying SRS round-trip succeeds.

**Q: No typed error class for `survey_nonprob` passed to gen-boot /
gen-rep / SDR (Issue 18, REQUIRED).**
- Options considered:
  - **A:** Add shared `surveywts_error_nonprob_requires_probability_design`;
    route three methods through it as step 1 of method-specific validation.
  - **B:** Overload `surveywts_error_unsupported_class` to cover "not
    supported by this method."
  - **C:** Do nothing.
- **Decision:** Option A.
- **Rationale:** Matches BRR's method-specific-class pattern; keeps
  `unsupported_class` semantically narrow. Added row to §II.i, §XII, and
  test blocks 9Ed, 10Eb, 12d.

**Q: Block 17b ("no history entry") test precondition unspecified
(Issue 19, SUGGESTION).**
- **Decision:** Option A — add a one-sentence construction note
  (`rep@metadata@weighting_history <- list()`).
- **Rationale:** Removes guesswork; the test is the only guard against a
  future refactor that relies on the history entry always being present.

**Q: No explicit edge-case test blocks (Issue 20, SUGGESTION).**
- Options considered:
  - **A:** Per-function edge-case blocks (19a–19f), one per
    `create_*_weights()`. Method-specific edge cases documented
    individually.
  - **B:** Single shared block covering common cases.
  - **C:** Do nothing.
- **Decision:** Option A — added §XIII.19 with sub-blocks 19a–19f.
- **Rationale:** User chose per-function granularity. Each method has
  distinct edge-case behavior (single-PSU for bootstrap, single-stratum
  paired for BRR, `tau = "auto"` for gen-boot) that warrants explicit
  coverage. Block notes that backend-error propagation uses
  `expect_error()` without `class =`, per Q16.

**Q: Coverage gate omits `R/replicate-print.R` (Issue 21, SUGGESTION).**
- **Decision:** Option A — added `replicate-print.R` to §XV coverage gate.
- **Rationale:** Keeps §XV consistent with §II.d; trivial edit.

**Q: Print example renders "N = 1 observations" ungrammatically
(Issue 22, SUGGESTION).**
- **Decision:** Option B — do nothing.
- **Rationale:** Single-row replicate designs are nonsensical; not worth
  the cli pluralization complexity. Noted for future polish phase if ever
  relevant.

### Outcome

Spec is at v1.3 with all 22 issues (Pass 1 + Pass 2) resolved. One new
error class (`surveywts_error_nonprob_requires_probability_design`). §II.e
`.snapshot_variables_for_history()` now records a `source_class` tag.
§XIII gains test blocks 17e, 9Ed, 10Eb, 12d, and new edge-case block 19
(19a–19f). Spec is code-quality-locked and ready for
`/implementation-workflow`.

---

## 2026-05-04 — Implementation Plan Review Stage 3 (Issues 1–15)

### Context

Worked through 15 issues from `plans/plan-review-replicate.md` (3 BLOCKING,
9 REQUIRED, 3 SUGGESTION). The implementation plan went from v0.2.0 draft
to approved.

### Questions & Decisions

**Q: `as_taylor_design()` NSE bug — stored character column names passed to tidy-select arguments (Issue 5, BLOCKING).**
- **Decision:** Use `!!rlang::sym(col_name)` inside `rlang::inject()` to convert stored character strings to symbols. Optional args (`strata`, `fpc`) only added to the call when non-NULL via a constructed `optional` list spliced with `!!!optional`.
- **Rationale:** User confirmed `as_survey()` uses tidy-select; `{{ }}` requires a function argument being forwarded, not a character string. `!!rlang::sym()` is the standard programmatic tidy-eval pattern for character → symbol conversion.

**Q: `source_class` string construction fragile — use boolean instead (Issue 6, REQUIRED).**
- **Decision:** Replace `source_class = paste0(attr(cls, "package"), "::", cls@name)` with `is_nonprob = S7::S7_inherits(data, surveycore::survey_nonprob)`. Check in `as_taylor_design()` becomes `isTRUE(last_creation$source_design$is_nonprob)`.
- **Rationale:** `attr(cls, "package")` is unreliable for S7 classes; a boolean is simpler, guaranteed correct, and consistent with every other class check in the codebase.

**Q: Edge cases 19a–19f allocated per-PR vs. dedicated PR 10 (Issue 12, BLOCKING).**
- **Decision:** Option A — allocated to the same PR as the function they test (19a → PR 2, 19b → PR 3, 19c → PR 4, 19d → PR 5, 19e → PR 6, 19f → PR 7). Removed the "if coverage is below 98%" conditionality from the post-PR section entirely.
- **Rationale:** Edge cases are spec requirements with the same standing as any numbered block. They belong with the function they test, consistent with how other error paths are organized in the plan.

**Q: Spec §II.a pseudocode still references `from_svydesign()` after the plan documented the bypass (Issue 13, REQUIRED).**
- **Decision:** Updated `plans/spec-replicate.md` §II.a to replace the `from_svydesign()` pseudocode with the manual construction approach and added a block-quoted bug note explaining the bypass.
- **Rationale:** The spec is the authoritative reference; a plan-level note is not sufficient when the spec contradicts it.

### Outcome

All 15 plan-review issues resolved. Plan approved and ready for `/r-implement`. Start with PR 1 in the PR map.

---

## 2026-05-04 — Implementation Plan Review Stage 3, Pass 2 (Issues 16–21)

### Context

Worked through 6 new issues from Pass 2 of `plans/plan-review-replicate.md` (0 BLOCKING, 5 REQUIRED, 1 SUGGESTION). All mechanical except for the `@family` grouping decision for `as_taylor_design()`.

### Questions & Decisions

**Q: Which `@family` tag should `as_taylor_design()` use — `@family conversion` or `@family replicate-weights`? (Issue 20)**
- Options considered:
  - **A:** `@family conversion` — emphasizes that it changes the class of the object.
  - **B:** `@family replicate-weights` — groups it alongside all `create_*_weights()` functions; emphasizes it operates on `survey_replicate` objects and belongs to the replicate weights workflow.
- **Decision:** `@family replicate-weights`.
- **Rationale:** `as_taylor_design()` is the inverse of `create_*_weights()` — it is the "exit" from the replicate weights workflow. Grouping it with the functions users pair it with is more useful than grouping it with hypothetical future conversion utilities. This also eliminates the `@family conversion` group entirely (no other function was assigned to it), reducing cognitive overhead.

### Outcome

All 6 Pass 2 issues resolved. Specific fixes: `surveywts_error_unsupported_class` added to Task 1.3 table; PR 8 switched from `test-replicate-weights.R` to a new `test-replicate-print.R`; `test_invariants()` added to 18 test blocks across PRs 2–9; `as_taylor_design()` `ids` NULL guard added with SRS round-trip test; `.claude/rules/surveywts-conventions.md` update step added to PR 2; both `@family conversion` tags changed to `@family replicate-weights`; `create_gen_boot_weights()` `replicates = 1L` boundary test added. Plan is fully approved — hand off to `/r-implement`, start with PR 1.

---
