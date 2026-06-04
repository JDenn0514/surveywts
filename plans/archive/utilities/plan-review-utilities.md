## Plan Review: utilities — Pass 1 (2026-05-18)

### New Issues

#### Section: PR Map

No issues found.

---

#### Section: PR 1 — Weight Utilities Infrastructure

**Issue 1: PR 1 missing changelog entry — both file list and acceptance criteria**
Severity: REQUIRED
[Violates stage-2-review Lens 5 file completeness and Lens 3 standard acceptance criteria: "Changelog entry written and committed on this branch"]

The PR 1 file list enumerates three files (`plans/error-messages.md`,
`.claude/rules/surveywts-conventions.md`, `R/utils.R`) but omits a changelog
entry. Every prior infrastructure PR in this repo has a changelog file (e.g.,
`changelog/nonresponse/feature-infrastructure.md`,
`changelog/replicate/feature-replicate-infrastructure.md`). The PR 1 acceptance
criteria also does not include a "Changelog entry written and committed" checkbox,
while PR 2 acceptance criteria does.

Options:
- **[A]** Add `changelog/utilities/feature-weight-utils-infra.md` to the PR 1
  file list and add a changelog-entry checkbox to PR 1 acceptance criteria. Create
  the `changelog/utilities/` directory if it doesn't exist. — Effort: low, Risk: low,
  Impact: consistent history, no surprise at PR review
- **[B]** Consolidate: omit a PR 1 changelog entry, rely on the PR 2 entry to cover
  both. Document this explicitly in the plan. — Effort: low, Risk: low, Impact: slightly
  thinner audit trail but not harmful
- **[C] Do nothing** — PR 1 will ship without a changelog entry, inconsistent with
  every other infrastructure PR in the repo.

**Recommendation: A** — Takes 2 minutes; matches established pattern for infra PRs.

---

**Issue 2: Changelog file path not specified for either PR**
Severity: REQUIRED
[Violates stage-2-review Lens 5 file completeness — file paths must be concrete]

Neither PR's file list nor the pre-PR checklist specifies where the changelog
entry file lives. PR 2 acceptance criteria says "Changelog entry written and
committed on this branch" but gives no path. The existing pattern is
`changelog/{phase}/{feature-name}.md` but the phase directory `changelog/utilities/`
doesn't exist yet and the plan doesn't say to create it.

Options:
- **[A]** Add explicit changelog file paths to both PR file lists:
  - PR 1: `changelog/utilities/feature-weight-utils-infra.md` (create dir)
  - PR 2: `changelog/utilities/feature-weight-utils.md`
  — Effort: low, Risk: low, Impact: implementer has a concrete target
- **[B] Do nothing** — implementer infers the path from other phases, which works
  but leaves ambiguity about naming convention.

**Recommendation: A** — Two lines in the plan; eliminates a lookup step during
implementation.

---

**Issue 3: `.get_weight_vec()` function-level argument comment not updated**
Severity: SUGGESTION
[Violates code-style.md — internal documentation should be accurate]

Task 3 correctly says to update the file-level comment table at the top of
`R/utils.R`. But `.get_weight_vec()` has its own embedded comment (lines ~158–162)
that documents accepted input types: "data.frame, weighted_df, survey_taylor, or
survey_nonprob". After the extension, this comment will be stale — `survey_replicate`
is now also accepted. The plan does not mention updating this function-level comment.

Options:
- **[A]** Add to task 3: "Also update the `.get_weight_vec()` embedded comment to
  list `survey_replicate` as a supported class." — Effort: low, Risk: low, Impact:
  accurate internal documentation
- **[B] Do nothing** — stale comment, minor confusion for future readers of utils.R.

**Recommendation: A** — One-line addition to task 3; prevents stale comment from
the start.

---

#### Section: PR 2 — `trim_weights()` and `stabilize_weights()`

**Issue 4: `weights_vec_orig` referenced in task 19 but never assigned**
Severity: REQUIRED
[Plan has an unresolvable cross-task reference — implementer cannot follow the plan literally]

Task 17 code defines `outside_initial <- weights_vec < lower_abs | weights_vec > upper_abs`
(capturing the pre-loop state of `weights_vec`) and then modifies `weights_vec` inside
the trimming loop. Task 19 then uses `weights_vec_orig` to compute `n_trimmed_lower`
and `n_trimmed_upper`:

```r
n_trimmed_lower = sum(outside_initial & weights_vec_orig < lower_abs),
n_trimmed_upper = sum(outside_initial & weights_vec_orig > upper_abs)
```

`weights_vec_orig` is never assigned anywhere in the plan. The note in task 19
says "where `weights_vec_orig` is the weight vector captured before trimming" —
acknowledging the capture is needed but not saying where to add it. An implementer
following the plan literally gets a "object 'weights_vec_orig' not found" error.

The fix belongs in task 17: add `weights_vec_orig <- weights_vec` as the first
line before `outside_initial <- ...`. Additionally, note that the formula can be
simplified: since `outside_initial` is `weights_vec_orig < lower_abs | weights_vec_orig > upper_abs`,
`outside_initial & weights_vec_orig < lower_abs` reduces to `weights_vec_orig < lower_abs`
(and similarly for upper). The `outside_initial &` is redundant.

Options:
- **[A]** Add `weights_vec_orig <- weights_vec` as the first line of task 17 code,
  before `outside_initial`. Update task 19 formula to use the simpler
  `n_trimmed_lower = sum(weights_vec_orig < lower_abs)` and
  `n_trimmed_upper = sum(weights_vec_orig > upper_abs)`.
  — Effort: low, Risk: low, Impact: plan is now self-consistent
- **[B]** Keep the `outside_initial &` redundancy; just add the assignment in
  task 17 — Effort: low, Risk: low, Impact: correct but redundant formula
- **[C] Do nothing** — implementer discovers the missing variable at runtime;
  adds a `# TODO` in the code.

**Recommendation: A** — Clearest fix; removes the redundancy at the same time.

---

**Issue 5: Task 15 uses `nrow(data)` rather than `nrow(data_df)` — inconsistent with established pattern**
Severity: REQUIRED
[Violates established codebase pattern; may fail silently for S7 objects]

Task 15 says: "Step 1: `.check_weight_utils_class(data)`; also check
`nrow(data) == 0` → `surveywts_error_empty_data`"

Every existing implementation in this codebase extracts `data_df` first and then
checks `nrow(data_df) == 0L`:
- `calibrate.R` line 95: `if (nrow(data_df) == 0L)`
- `nonresponse.R` line 144: `if (nrow(data_df) == 0L)`

The plan doesn't extract `data_df` until task 16, step 4. Using `nrow(data)` on
an S7 survey object without extraction may work (if `survey_base` defines `nrow()`)
or may fail — this depends on `surveycore` internals not visible in the plan.
More importantly, deviating from the established `data_df <- ...; nrow(data_df)`
pattern without justification is a correctness risk.

The clean fix: extract `data_df` at the start of task 15 (or task 16 step 3,
which the plan already says constructs the data frame), and use `nrow(data_df)` for
the empty check. Since task 16 already says "use `@data` for S7 objects, plain `data`
for data frames", the extraction logic is already there — it just needs to be moved
earlier (before the nrow check) or the nrow check moved later (after extraction).

Options:
- **[A]** Move `data_df` extraction to task 15, immediately after
  `.check_weight_utils_class()`, and check `nrow(data_df) == 0L`. Remove the
  redundant extraction note from task 16 step 4 (it's now done in task 15).
  — Effort: low, Risk: low, Impact: matches codebase pattern exactly
- **[B]** Keep extraction in task 16, move the nrow check there too (after
  extraction). The class check remains in task 15, nrow check moves to task 16.
  — Effort: low, Risk: low, Impact: slightly later fail for empty data; acceptable
- **[C] Do nothing** — rely on S7 `nrow()` dispatch working correctly; leaves
  a latent risk if surveycore doesn't define it.

**Recommendation: A** — Matches the codebase pattern; eliminates the S7 nrow
uncertainty entirely.

---

**Issue 6: `test_invariants()` acceptance criterion is ambiguous for `survey_replicate` output**
Severity: SUGGESTION
[Lens 3 — acceptance criterion is not fully verifiable as stated]

The PR 2 acceptance criteria includes: "test_invariants() called in every constructor
test block". But `test_invariants()` (defined in `testing-surveywts.md`) only checks
`weighted_df` and `survey_nonprob` objects — it's a no-op for `survey_replicate` output.
Task 7 correctly doesn't say to call `test_invariants()` for the `survey_replicate` block,
but the acceptance criterion says "every constructor test block" without qualification.

This creates ambiguity: is the `survey_replicate` happy-path block supposed to call
`test_invariants()` (a no-op) or skip it? Either is defensible, but the criterion should
be explicit.

Options:
- **[A]** Qualify the acceptance criterion: "test_invariants() called in every
  constructor test block that produces `weighted_df` or `survey_nonprob` output;
  skipped for `survey_replicate` output (no-op)." — Effort: low, Impact: clear criterion
- **[B]** Note in task 7 that `test_invariants()` is called for the `survey_replicate`
  block (harmless no-op) to satisfy the "every block" criterion literally.
- **[C] Do nothing** — minor ambiguity; implementer likely infers correct behavior.

**Recommendation: A** — One-sentence clarification; prevents a question at code review.

---

**Issue 7: Task 31 (`stabilize_weights()` documentation) is underspecified relative to task 20**
Severity: SUGGESTION
[Lens 3 — acceptance criterion not fully verifiable; task 31 gives no example guidance]

Task 20 (`trim_weights()` documentation) is specific: "use `make_surveywts_data(seed = 1)`,
run at least 3 example forms (default, explicit upper, percentile). Add `library(survey)` if
needed." Task 31 (`stabilize_weights()` documentation) says only "Required tags: @title,
@description, @param (all 4 args), @return, @family utilities, @export, @examples" — no
guidance on example forms or number.

The spec §IV example shows two forms (global, by = age_group) and includes `library(survey)`.
Without this guidance in the plan, the implementation might produce a single minimal example
that fails R CMD check or omits the `by` case.

Options:
- **[A]** Add to task 31: "use `make_surveywts_data(seed = 1)`, run at least 2 example
  forms (global stabilization, by-group stabilization). Add `library(survey)` if the
  example creates survey objects." — Effort: low, Impact: example quality consistent
  with trim_weights()
- **[B] Do nothing** — implementer follows spec §IV example; minor spec-to-plan gap.

**Recommendation: A** — Keeps documentation tasks at consistent specificity.

---

**Issue 8: Quality gates don't mention `error-class-auditor` agent**
Severity: SUGGESTION
[Lens 3 — available project tool not referenced for a directly applicable quality gate]

The spec quality gate "Every new `cli_abort()` and `cli_warn()` call has a `class=`
argument" is listed as an acceptance criterion. The project has a dedicated
`error-class-auditor` agent for exactly this check. Steps 32–36 (quality gates) don't
mention running it, relying instead on manual review.

Options:
- **[A]** Add to Group E: a step to run the `error-class-auditor` agent after
  implementation is complete and before `devtools::check()`. — Effort: low, Impact:
  automated verification of a spec requirement
- **[B] Do nothing** — `devtools::check()` and test failures will catch missing
  `class=` arguments indirectly.

**Recommendation: A** — The agent exists for this purpose; takes 10 seconds to invoke.

---

### Summary (Pass 1)

| Severity | Count |
|---|---|
| BLOCKING | 0 |
| REQUIRED | 4 |
| SUGGESTION | 4 |

**Total issues:** 8

**Overall assessment:** The plan is structurally sound and covers the full spec with
correct TDD ordering. Four required issues need resolution before implementing: PR 1
needs a changelog entry, both PRs need explicit changelog file paths, `weights_vec_orig`
must be added to task 17, and the `nrow()` pattern must match the codebase convention.
None of these require spec changes — all are plan-level fixes.
