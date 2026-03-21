# Decisions Log — surveywts wt-name

This file records planning decisions made during wt-name.
Each entry corresponds to one planning session.

---

## 2026-03-19 — Spec review resolution (Stage 4)

### Context

Resolving 8 issues from the adversarial spec review (`plans/spec-review-wt-name.md`)
before handing off to implementation.

### Questions & Decisions

**Q: How should uniform weights be created when `weights = NULL` + custom `wt_name`?**
- Options considered:
  - **[A] Create in `data_df[[wt_name]]` directly:** No phantom column. Simple, correct.
  - **[B] Remove phantom column after calibration:** Fragile if user data already has a `"wts"` column.
- **Decision:** Option A — create uniform weights directly in `wt_name` column.
- **Rationale:** Simplest fix with no edge case risk. Uniform weights are an internal detail that should never leak into user-visible output. (engineering-preferences.md §4: handle more edge cases)

**Q: Should `.make_history_entry()` get a new `weight_col` field, or should Section VI be removed?**
- Options considered:
  - **[A] Add `weight_col` to history entries:** Valuable metadata for multi-step workflows.
  - **[B] Remove Section VI:** Column name is recoverable from `weighted_df` attribute.
- **Decision:** Option A — add the field.
- **Rationale:** In multi-step workflows where `wt_name` changes between steps, the history should record which column held weights at each step. The metadata cost is trivial.

**Q: Should `wt_name` go before or after `by` in `adjust_nonresponse()`?**
- Options considered:
  - **[A] After `by`:** Follows code-style.md §4 (optional NSE before optional scalar).
  - **[B] After `weights` (same as other functions):** Uniform position across the family.
- **Decision:** Option A — `wt_name` goes after `by`.
- **Rationale:** Convention exists for a reason; `adjust_nonresponse()` is the only function affected and the position shift is minor. Consistency with convention > consistency within function family.

**Q: Should `.get_weight_col_name()` default change from `".weight"` to `"wts"`?**
- Options considered:
  - **[A] Change for consistency:** Aesthetically consistent with `wt_name` default.
  - **[B] Don't change:** Decoupled defaults, no maintenance trap.
- **Decision:** Option B — don't change.
- **Rationale:** With Rule 1b (uniform weights created in `wt_name` directly), the fallback is no longer involved in output naming. Coupling two defaults creates a maintenance trap where changing one requires remembering to change the other.

### Outcome

Spec updated to version 0.2 with all 8 review issues resolved. Ready for
`/implementation-workflow`.

---

## 2026-03-20 — Plan review resolution (Stage 3)

### Context

Resolving 8 issues from the adversarial plan review (`plans/plan-review-wt-name.md`)
before handing off to implementation.

### Questions & Decisions

**Q: Where does the chain test (`calibrate() |> rake()`) belong — PR 2 or PR 3?**
- Options considered:
  - **[A] Move to PR 3:** Chain test only makes sense when both functions have `wt_name`.
  - **[B] Keep in PR 2:** Test passes because `rake()` reads the `weighted_df` attribute, but for the wrong reason.
- **Decision:** Option A — move chain test to PR 3 Task 7.
- **Rationale:** Task lists are the source of truth. A test that passes for the wrong reason masks future bugs. (engineering-preferences.md §5: explicit over clever)

**Q: Which PR handles `test-06-diagnostics.R` breakage from `.weight` → `wts`?**
- Options considered:
  - **[A] PR 2 (first PR to cause breakage):** Two lines to change; belongs with the cause.
  - **[B] Separate PR:** Over-splits the work.
- **Decision:** Option A — added as Task 15b in PR 2.
- **Rationale:** PR 2 changes `calibrate()` output, which diagnostics tests call directly. Fix belongs with the cause.

**Q: Should PR 1 have a changelog entry?**
- Options considered:
  - **[A] No:** Internal-only infrastructure (`.validate_wt_name()`, `.make_history_entry()` param). User-facing changelogs in PRs 2–5.
  - **[B] Yes:** Consistency, but noisy for internal changes.
- **Decision:** Option A — removed changelog from PR 1 acceptance criteria.
- **Rationale:** Changelog entries are user-facing; internal helpers don't warrant them.

**Q: How should `.weight` line references be listed in PR 3 and PR 4 task lists?**
- Options considered:
  - **[A] Correct the inaccurate line numbers:** Accurate but still fragile.
  - **[B] Replace with search instruction:** "Search for `.weight` in file and replace all occurrences."
- **Decision:** Option B — search instruction instead of line numbers.
- **Rationale:** Line numbers drift as tests are added. A search instruction is more robust.

### Outcome

Implementation plan updated with all 8 issues resolved. Plan approved for
`/r-implement`.

---
