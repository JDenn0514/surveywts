## Plan Review: dataset-revamp — Pass 1 (2026-06-14) — RESOLVED

---

### New Issues

#### Section: PR 1 — Acceptance Criteria

**Issue 1: Spec §V.2 still says ns_wave1 has 175 cols; §III.7 and test-spec say 174**
Severity: REQUIRED
Violates Spec Coverage lens — internal spec inconsistency unresolved in the documentation-contracts section.

The spec §V.2 reads:
> "For `ns_wave1` (175 cols = 171 original + 4 derived): same `codoc` compliance required.
> Terse entries for the 171 original cols; full entries for 4 derived cols."

But spec §III.7 (corrected in spec-review Pass 1, Issue 2) says:
> "total columns = 171 (original) + 3 (new: `age_group`, `race_ethn`, `educ`) = **174**"

And test-spec checks `ncol(ns_wave1) == 174`.

When the builder writes `R/data.R`, they read §V.2 (the documentation contract) to know how many `\item{}` entries to write. If they follow §V.2 and write 175 items, `codoc` will flag a "code/documentation mismatch" warning (one extra item, no matching column), which the acceptance criteria define as a CI-blocking failure.

The plan notes say "174, not 175" and reference the spec-review resolution, but the spec §V.2 itself was not updated. A builder following the spec would see 175 in the authoritative documentation contract section.

Options:
- **[A]** Update spec §V.2 to read "174 cols = 171 original + 3 new cols; `gender` overwritten in-place." Effort: low, Risk: low, Impact: eliminates codoc mismatch risk.
- **[B]** Add an explicit override note in the plan task 7 (`R/data.R`): "Write exactly 174 `\item{}` entries for ns_wave1 — NOT 175 despite §V.2 wording." Effort: low, Risk: low, Impact: guides builder without touching spec.
- **[C] Do nothing** — builder reads §V.2, writes 175 items, codoc warning blocks CI.

**Recommendation: [A]** — fix the spec at source; a note in the plan is a workaround for a bug in the spec.

---

**Issue 2: `npors_2025_svy` and `npors_2025_clean_svy` have no explicit structural acceptance criteria**
Severity: REQUIRED
Violates Acceptance Criteria lens — verifiable test-spec checks not surfaced as plan acceptance criteria.

The test-spec has explicit structural checks for both objects:

`npors_2025_svy`:
- `S7::S7_inherits(npors_2025_svy, surveycore::survey_taylor)` is `TRUE`
- `nrow(npors_2025_svy@data) == 5022`
- `npors_2025_svy@variables$weights == "weight"`

`npors_2025_clean_svy`:
- `S7::S7_inherits(npors_2025_clean_svy, surveycore::survey_taylor)` is `TRUE`
- `nrow(npors_2025_clean_svy@data) == nrow(npors_2025_clean)`

The plan's acceptance criteria cover `gss_2024_svy`, `acs_wy_2022_svy`, `pew_2016_optin_svy`, `pew_2016_synth_pop_svy`, and `ns_wave1_svy` explicitly. Both npors svy objects are absent — they appear only in the generic "All 14 new objects loadable" criterion, which tests loadability but not structural correctness.

The tester agent gates against the acceptance criteria. Without these, a builder who produces `npors_2025_svy` with the wrong weight column or wrong class would pass the plan gates but fail test-spec.

Options:
- **[A]** Add two explicit acceptance criteria entries for these objects, mirroring the gss_2024_svy pattern. Effort: low, Risk: none.
- **[C] Do nothing** — structural failures not caught at plan gate; tester catches them later.

**Recommendation: [A]**

---

**Issue 3: No `devtools::document()` task step in the task sequence**
Severity: REQUIRED
Violates File Completeness lens — NAMESPACE and man/ files must be generated after R/data.R is rewritten; this step is missing from the 12-task sequence.

The plan tasks are:
1. Write test file
2–4. Rewrite/modify data-raw scripts
5. Run scripts (generate .rda files)
6. Delete old .rda files
7. Rewrite `R/data.R` ← roxygen2 source changed
8–12. Other file updates and NEWS.md

There is no step between 7 and 8 to run `devtools::document()`. After rewriting `R/data.R`, the `man/` pages are stale — `devtools::check()` (acceptance criterion) will regenerate them internally, but the builder needs to run `devtools::document()` explicitly to (a) verify no errors in the roxygen2 markup, (b) commit the updated `man/data.Rd` files as part of the PR.

The acceptance criterion "NAMESPACE and man/ unchanged after run (no drift)" tests that a *second* run produces no drift — it does not tell the builder to run it *once* initially. Without the task step, the man/ files may never be committed to the branch.

Options:
- **[A]** Add a task step after task 7: "Run `devtools::document()`. Verify man/data.Rd is updated and commit it." Effort: trivial, Risk: none.
- **[C] Do nothing** — man/ files stay stale; `devtools::check()` may catch it but man/ won't be in the PR branch.

**Recommendation: [A]**

---

#### Section: PR 1 — Miscellaneous

**Issue 4: "14 new objects loadable" count is imprecise — only 12 are new .rda files**
Severity: SUGGESTION
Minor clarity issue; could confuse the tester counting new files.

The acceptance criterion says "All 14 new objects loadable via `data()`." But of the 14 objects that will exist post-PR, only 12 are new `.rda` files added in this PR:
- 5 new tibbles: `gss_2024`, `npors_2025`, `npors_2025_clean`, `acs_wy_2022`, `ns_wave1`
- 7 new svy companions: `gss_2024_svy`, `npors_2025_svy`, `npors_2025_clean_svy`, `acs_wy_2022_svy`, `pew_2016_optin_svy`, `pew_2016_synth_pop_svy`, `ns_wave1_svy`

The 2 pew tibbles (`pew_2016_optin`, `pew_2016_synth_pop`) already exist in `data/` and are unchanged. They are not "new" objects — they're in the spec's KEEP list, not ADD list.

Options:
- **[A]** Change to "All 12 new objects loadable via `data()` (plus 2 existing pew tibbles)." Effort: trivial.
- **[B]** Change to "All 14 dataset objects loadable via `data()` — 12 new + 2 existing pew tibbles." Effort: trivial.
- **[C] Do nothing** — low risk; both counts enumerate the same test-spec §Presence checks.

**Recommendation: [B]** — preserves the 14 total while clarifying which are new.

---

**Issue 5: HOLD #1 unresolved in pipeline bookkeeping — no `decisions-dataset-revamp.md`**
Severity: SUGGESTION
Traceability gap; doesn't affect implementation but leaves audit trail incomplete.

The spec-review Pass 1 says:
> "HOLD #1 (weight column for gss/npors svy objects): OPEN — see `decisions-dataset-revamp.md`."

No `decisions-dataset-revamp.md` exists. The impl plan notes resolve HOLD #1 in favor of Option A (normalized weight in `_svy`, `wt_pop` in tibble), and the spec §III.1/§III.2 + test-spec are unambiguous about this. But the formal decision record is missing, which means the spec-review document still shows OPEN.

Options:
- **[A]** Create `plans/decisions-dataset-revamp.md` logging: "HOLD #1 resolved — Option A: `_svy` companions use normalized weight (`wtssps`/`weight`); `wt_pop` column in tibble for IPW construction." Effort: low.
- **[C] Do nothing** — no functional impact; impl plan notes cover the resolution.

**Recommendation: [A]** — closes the loop and keeps the spec-review audit trail accurate.

---

**Issue 6: `acs_wy_2022_svy` weight column name not in acceptance criteria**
Severity: SUGGESTION
Acceptance Criteria lens — test-spec checks the weight column name but plan criteria do not surface it.

Test-spec has: "Weight column is `'pwgtp'` or equivalent: `gss_2024_svy@variables$weights` check pattern applies." The plan's acceptance criterion for `acs_wy_2022_svy` covers only row count and replicate column count. The weight column name (`pwgtp`) is not verified by any plan criterion.

This is covered by the test file (task 1) but not surfaced as a named acceptance criterion, which means the builder/shipper gate is incomplete for this object.

Options:
- **[A]** Add to the `acs_wy_2022_svy` acceptance criterion: "weight column is `pwgtp`." Effort: trivial.
- **[C] Do nothing** — test file covers it; minor gap.

**Recommendation: [A]**

---

**Issue 7: README.md not listed as a file to stage/commit**
Severity: SUGGESTION
File Completeness lens — generated file may be overlooked in the commit step.

Task 11 says "run `devtools::build_readme()`" but does not mention committing the regenerated `README.md`. Since `README.md` is a generated artifact committed to version control, it needs to be staged and committed. The plan notes say "README.md is generated. Do not manually edit" but don't include an explicit "git add README.md" reminder in the task.

Options:
- **[A]** Update task 11 to: "run `devtools::build_readme()` to regenerate `README.md`; verify the updated `README.md` is staged for the PR commit." Effort: trivial.
- **[C] Do nothing** — builder will likely notice it when running `git status`.

**Recommendation: [A]** — explicit is better than relying on git status awareness.

---

### Summary (Pass 1)

| Severity | Count |
|---|---|
| BLOCKING | 0 |
| REQUIRED | 3 |
| SUGGESTION | 4 |

**Total issues:** 7

**Overall assessment:** The plan is coherent — the single-PR mandate is well-justified, the TDD task ordering is correct, and the coverage of acceptance criteria is thorough for most objects. Three REQUIRED issues must be resolved before implementation: an unresolved spec inconsistency that will cause a codoc CI failure (§V.2 says 175 cols for ns_wave1, should be 174), two svy objects missing explicit acceptance criteria, and a missing `devtools::document()` task step. None require architectural changes — all are small, targeted fixes.
