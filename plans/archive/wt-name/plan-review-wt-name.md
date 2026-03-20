# Plan Review: wt-name

---

## Plan Review: wt-name — Pass 1 (2026-03-20)

### New Issues

#### Section: PR 2 — `calibrate()` — Add `wt_name`

**Issue 1: Chain test in Task 7 contradicts notes**
Severity: BLOCKING
Violates engineering-preferences.md §5 (explicit over clever)

PR 2 Task 7 (lines 268–286) includes a chain test
`calibrate() |> rake()` and a history test. The notes section (lines 405–412)
then says "**Move the chain test to PR 3 instead.**" The implementer sees both
the task and the note — the task list says "write this test" and the notes say
"don't." This is a direct contradiction.

The chain test *might* pass in PR 2 because `rake()` reads `weight_col` from
the `weighted_df` attribute (which would be `"wts"` after calibrate), but it
would pass for the wrong reason — `rake()` doesn't have `wt_name` yet.

Options:
- **[A] Remove Task 7 chain test from PR 2; keep history test only.** Move
  the chain test verbatim to PR 3 Task 7. — Effort: low, Risk: low,
  Impact: eliminates ambiguity
- **[B] Keep Task 7 as-is, delete the contradicting note.** The chain test
  passes in PR 2 because `rake()` auto-reads the attribute. —
  Effort: low, Risk: medium (test passes for wrong reason; masks future bugs)
- **[C] Do nothing** — implementer has to guess which instruction to follow

**Recommendation: [A]** — Task lists are the source of truth for the
implementer. Notes should clarify, not contradict.

---

**Issue 2: Missing `test-06-diagnostics.R` in file list**
Severity: REQUIRED
Violates Lens 5 — File Completeness

PR 2 changes `calibrate()` default output from `".weight"` to `"wts"`.
Diagnostic tests at `test-06-diagnostics.R:85` and `:97` create `weighted_df`
objects via `calibrate()` and then pass `weights = .weight` (tidy-eval
reference to a column named `".weight"`). After PR 2, that column no longer
exists — these lines must change to `weights = wts`.

The plan's Cross-cutting Concerns section (lines 639–645) notes this
possibility but says "Handle in whichever function PR causes the first
diagnostic test breakage." This is ambiguous. PR 2 *is* the first PR to
cause the breakage (diagnostics tests call `calibrate()`, not `rake()`).

Options:
- **[A] Add `test-06-diagnostics.R` to PR 2's file list.** Add an explicit
  task: "Update lines 85 and 97 from `weights = .weight` to `weights = wts`."
  Add to acceptance criteria: "Diagnostic tests pass with updated weight
  column references." — Effort: low, Risk: low, Impact: no surprise test
  failures
- **[B] Create a separate PR for diagnostics updates.** — Effort: medium,
  Risk: low, Impact: over-splits the work
- **[C] Do nothing** — `devtools::check()` will fail in PR 2

**Recommendation: [A]** — Two lines to change; belongs with the PR that causes
the breakage.

---

**Issue 3: `plain_df` sync concern left unresolved**
Severity: REQUIRED
Violates engineering-preferences.md §5 (explicit over clever)

The notes section (lines 413–415) flags that the `plain_df` sync block (lines
111–117 in `calibrate.R`) "may need updating" after `weight_col` is reassigned
to `wt_name`. This is left as "Verify that `.validate_weights()` receives the
correct data frame." The implementer doesn't know whether action is needed.

Actual analysis: after Task 11, `weight_col <- wt_name` in the
`weights = NULL` branch. `data_df[[wt_name]]` contains uniform weights (1/n).
Line 111 sets `plain_df <- data_df`. Line 119 calls
`.validate_weights(plain_df, weight_col)` which validates
`plain_df[[wt_name]]` — the uniform weights. These are all positive, non-NA,
so validation passes. **No code change is needed**, but the plan should say
this explicitly instead of leaving an open question.

For the `weighted_df` input branch, `weight_col` is NOT reassigned (no uniform
weight creation occurs). `weight_col` still points to the input attribute, and
`.validate_weights()` validates the input weights. Also correct — no change
needed.

Options:
- **[A] Replace the note with an explicit statement in the tasks:** "No change
  needed to the `plain_df` sync block. After Task 11, `.validate_weights()`
  receives the `wt_name` column containing uniform weights (all positive),
  which passes validation." — Effort: low, Risk: low, Impact: removes
  ambiguity
- **[B] Do nothing** — implementer spends time analyzing code that needs no
  change

**Recommendation: [A]** — Notes that pose questions must resolve them.

---

#### Section: PR Map / Cross-cutting

**Issue 4: No PR includes 98%+ line coverage in acceptance criteria**
Severity: REQUIRED
Violates testing-standards.md ("98%+ line coverage; PRs blocked below 95%")
and Stage 2 Lens 3

The spec's Quality Gate §VIII includes "98%+ line coverage maintained." None
of the five PRs' acceptance criteria mention it. Per testing-standards.md, 95%
is the CI-blocking threshold and 98% is the project target. All new code paths
(validation, output construction, history recording) need coverage.

Options:
- **[A] Add "98%+ line coverage maintained" to acceptance criteria on PRs 2–5.**
  PR 1 is internal-only infrastructure with no new testable public paths, so
  it can be exempted. — Effort: low, Risk: low, Impact: matches spec quality
  gates
- **[B] Do nothing** — CI catches it anyway at the 95% threshold, but the
  plan doesn't reflect the project standard

**Recommendation: [A]** — Acceptance criteria should mirror quality gates.

---

**Issue 5: PR 1 acceptance criteria mention changelog but file list omits it**
Severity: REQUIRED
Violates Lens 5 — File Completeness

PR 1's acceptance criteria (line 93) say "Changelog entry written and
committed." But the file list (lines 37–38) includes only `R/utils.R` and
`plans/error-messages.md`. No changelog file is listed.

PR 1 adds `.validate_wt_name()` and a new parameter to
`.make_history_entry()` — both internal. Internal-only infrastructure changes
typically don't get user-facing changelog entries.

Options:
- **[A] Remove "Changelog entry" from PR 1 acceptance criteria.** The
  user-facing changelog entries belong in PRs 2–5, which each add `wt_name`
  to a public function. — Effort: low, Risk: low, Impact: accurate criteria
- **[B] Add a changelog file to PR 1's file list.** Content:
  "Internal infrastructure for `wt_name` feature." — Effort: low, Risk: low,
  Impact: consistent but noisy
- **[C] Do nothing** — implementer must decide whether to write a changelog
  for internal changes

**Recommendation: [A]** — Internal helpers don't warrant user-facing changelog
entries. PRs 2–5 already have changelog files.

---

#### Section: PR 5 — `adjust_nonresponse()` — Add `wt_name`

**Issue 6: Output construction difference buried in notes, not task list**
Severity: REQUIRED
Violates engineering-preferences.md §5 (explicit over clever)

PR 5 says "Same implementation pattern as PR 2: validate, Rule 1b, output
construction, history, roxygen." But `adjust_nonresponse()` assigns weights
at a different point in the control flow than the other three functions:

```r
# nonresponse.R lines 341-343 — BEFORE the output branch
new_weights[!is_respondent] <- 0
out_df <- plain_df
out_df[[weight_col]] <- new_weights
```

The other three functions assign weights INSIDE the `data.frame` output branch:
```r
# calibrate.R lines 227-228 — INSIDE the output branch
out_df <- plain_df
out_df[[weight_col]] <- new_weights
```

The plan's "Implementation detail for output" section (lines 596–600) correctly
notes this, but Tasks 9–14 say "Same implementation pattern as PR 2." The
implementer following the numbered task list would apply the calibrate pattern
(change the output branch) and miss the pre-branch assignment at line 343.

Options:
- **[A] Add an explicit Task in PR 5's task list:** "Task 11b. Update
  pre-output weight assignment. Change line 343 from
  `out_df[[weight_col]] <- new_weights` to `out_df[[wt_name]] <- new_weights`."
  Also update the `.make_weighted_df()` call at line 365 from `weight_col` to
  `wt_name`. — Effort: low, Risk: low, Impact: unambiguous task list
- **[B] Do nothing** — implementer must read the notes section to catch this

**Recommendation: [A]** — Task lists must be self-sufficient. Notes supplement
but don't substitute.

---

#### Section: PR 3 — `rake()` — Add `wt_name`

**Issue 7: `.weight` reference count mismatch in test-03-rake.R**
Severity: SUGGESTION

PR 3 Task 15 lists 12 line numbers for `.weight` references: "lines 61, 62,
122, 151, 200, 810, 813, 836, 877, 878, 904, 919." Actual `grep` shows 11
occurrences — line 151 does not contain `".weight"`.

Similarly, PR 4 Task 15 lists "lines 75, 76, 561, 614" (4 locations) but
actual grep shows 3 — line 614 does not contain `".weight"`.

Options:
- **[A] Correct the line numbers.** Remove line 151 from PR 3 list; remove
  line 614 from PR 4 list. — Effort: low, Risk: low, Impact: accurate
  reference
- **[B] Replace specific line numbers with "search for `.weight` in file".**
  Line numbers drift anyway. — Effort: low, Risk: low, Impact: more robust
- **[C] Do nothing** — implementer should verify by searching anyway

**Recommendation: [B]** — Specific line numbers are fragile. A search
instruction is more reliable.

---

#### Section: Spec vs Plan

**Issue 8: Spec Deliverable 4 still lists `.get_weight_col_name()` change**
Severity: SUGGESTION

Spec §I Deliverables table lists:
> `4 | Update .get_weight_col_name() default from ".weight" to "wts" | Low`

But Spec §III Rule 5 and §V both say `.get_weight_col_name()` is **not
changed**, and the decisions log confirms "Option B — don't change." The plan
correctly follows the decisions log and Rule 5. However, the spec's
Deliverables table is misleading.

Options:
- **[A] Update Spec §I Deliverables table** to mark Deliverable 4 as "Decided
  against — see decisions-wt-name.md" or remove it. — Effort: low, Risk: low,
  Impact: internal consistency
- **[B] Do nothing** — decisions log is authoritative; anyone reading in depth
  will find the resolution

**Recommendation: [A]** — Specs should not contradict themselves. A one-line
update is cheap.

---

### Summary (Pass 1)

| Severity | Count |
|---|---|
| BLOCKING | 1 |
| REQUIRED | 5 |
| SUGGESTION | 2 |

**Total issues:** 8

**Overall assessment:** The plan is well-structured with correct PR boundaries,
accurate dependency ordering, and comprehensive test coverage of the spec.
One blocking issue (chain test contradiction in PR 2) must be resolved before
implementation. The five REQUIRED issues are all low-effort fixes — mostly
missing files, unresolved notes, and missing acceptance criteria. After
resolving these, the plan is ready to implement.
