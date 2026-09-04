# Plan review — sdr-normal-hadamard

## Plan Review: sdr-normal-hadamard — Pass 1 (2026-09-04)

Five lenses, run over `plans/impl-sdr-normal-hadamard.md` revision 1. Lenses 1
and 2 ran together, lenses 3, 4 and 5 each ran alone. Every finding below was
re-checked against the file it cites before it entered this document.

### New Issues

#### Section: PR 1 — tasks

**Issue 1: Task 27 asserts a result that Stage F has not produced yet**
Severity: REQUIRED
Task-level ordering. A verification step must be true at the point it runs.

Task 27 reads "Run `devtools::document()`. Confirm `NAMESPACE` does not change
and seven man pages do." At that point only `R/create_sdr_weights.R` has been
edited. `R/create_gen_boot_weights.R`, which defines the shared Messages
section the other six pages inherit, is not touched until task 29. roxygen2
rewrites an `.Rd` file only when its content changes, so exactly one page
changes at task 27. Task 30 already confirms all seven, in the right place.

Options:
- **[A]** Reword task 27 to confirm `NAMESPACE` unchanged and
  `man/create_sdr_weights.Rd` changed — one page. Leave the seven-page check
  at task 30. — Effort: low, Risk: low, Impact: the intermediate check becomes
  true.
- **[B]** Move Stage F before Stage E so one `document()` call covers both. —
  Effort: low, Risk: medium, Impact: breaks the per-file staging the rest of
  the plan uses, and task 28 would move with it.
- **[C] Do nothing** — the builder hits a checklist item that does not match
  what they see, and either reports a false failure or waves it through.

**Recommendation: A** — smallest change, and it keeps the stage boundaries.

**Issue 2: Quality gates 12 and 18 have no verification task**
Severity: REQUIRED
Spec §Quality gates, items 12 and 18. Gate 18 names its own grep.

Gates 10, 13 and 16 are all "no text says X" claims, and task 45 gives each one
a grep. Gates 12 and 18 are the same shape — 12 forbids text that says the
normal path produces one inactive replicate or caps the count at one; 18
forbids a closed list of the orders the default setting reaches and the word
"only", and the spec states the check as "a grep over `R/` and `man/` returns
no sentence that ends the list at 256". Neither appears in task 45, and no
other task checks them. Both are Track 1 checkboxes, so the plan implies
evidence that nothing produces.

Options:
- **[A]** Extend task 45 from three greps to five. — Effort: low, Risk: low,
  Impact: closes both gates with the mechanism the sibling gates already use.
- **[B]** Leave both to the read check at task 62 and drop the two Track 1
  checkboxes. — Effort: low, Risk: medium, Impact: a weaker guarantee than the
  sibling gates get, and a later doc edit could reintroduce either claim
  undetected.
- **[C] Do nothing** — two named gates ship with nothing behind them.

**Recommendation: A** — the spec already names the grep for gate 18.

**Issue 3: No task for the general no-warning assertion**
Severity: REQUIRED
Test-spec §Warning paths: "Assert `expect_no_warning()` on one default call and
one `TRUE` call."

The only `expect_no_warning()` in the plan is task 38, scoped to `mse = FALSE`
with `use_normal_hadamard = TRUE`. The test-spec asks separately for the plain
case, at `mse = TRUE` on both settings. Every other subsection of the
test-spec's per-function plan has a Track 2 counterpart; Warning paths is the
one orphan.

Options:
- **[A]** Add a task to Stage G and a Track 2 bullet: `expect_no_warning()` on
  one plain default call and one plain `TRUE` call. — Effort: low, Risk: low,
  Impact: closes a gap the test-spec names outright.
- **[B]** Rely on task 38 and on the absence of warnings elsewhere. — Effort:
  none, Risk: medium, Impact: the tester works from the test-spec alone and
  will write this block; the builder would not have, so the two converge only
  by the tester's initiative.
- **[C] Do nothing** — same as B.

**Recommendation: A** — one line closes a named gap.

**Issue 4: Task 29 miscounts the replacement block and does not say "verbatim"**
Severity: REQUIRED
Spec §Messages. The replacement block is five roxygen lines.

Task 29 says "the four-line conditional bullet from the spec". The spec's block
runs five lines. Every other task that transcribes spec text — 15, 21, 22, 23,
24, 47, 48 — says "verbatim from the spec"; task 29 does not. The block backs
quality gate 17, which spans seven help pages, so a paraphrase here fails a
named gate.

Options:
- **[A]** Reword to "the five-line conditional bullet from the spec, section
  Messages, verbatim". — Effort: low, Risk: low, Impact: removes both the wrong
  count and the ambiguity.
- **[B]** Leave it; the target block is unambiguous in the spec. — Effort:
  none, Risk: low to medium.
- **[C] Do nothing** — a plan-against-spec discrepancy a reviewer has to
  reconcile mid-build.

**Recommendation: A**.

**Issue 5: Task 37 omits its tolerance**
Severity: REQUIRED
Test-spec §Tolerances: a mean variance pinned against a measured value uses
1e-8.

Tasks 36 and 38 both state "at tolerance 1e-8" inline. Task 37 pins three mean
variances and states no tolerance, and the Track 2 bullet repeats the silence.
A builder following the task text would fall back to `expect_equal()`'s
default, which is about 1.5e-8 — close, but not the number the tester asserts.

Options:
- **[A]** Add "at tolerance 1e-8" to task 37 and to the Track 2 bullet. —
  Effort: low, Risk: low, Impact: the one silent tolerance in Stage G becomes
  explicit.
- **[B]** Rely on the package default in `testing-surveywts.md`. — Effort:
  none, Risk: low to medium, Impact: works only if the builder reads the
  standards file rather than the task.
- **[C] Do nothing** — same as B.

**Recommendation: A**.

**Issue 6: The documentation-check row count is wrong**
Severity: REQUIRED
Test-spec §Documentation checks. The `create_sdr_weights()` table has ten rows.

Task 62 and the Track 2 bullet both say "the eleven documentation-check rows".
The table holds ten. The Messages check is row ten of that table, not a
separate item, and the inheriting-page check below it is prose, not a row. The
plan double-counts the Messages check.

Options:
- **[A]** Correct both places to ten rows plus the inheriting-page prose check.
  — Effort: low, Risk: low, Impact: the checklist matches the table.
- **[B]** Leave the miscount. — Effort: none, Risk: low, Impact: a reader
  recounts the table to find the missing row.
- **[C] Do nothing** — same as B.

**Recommendation: A**.

**Issue 7: No criterion holds the seven existing error snapshots still**
Severity: REQUIRED
Test-spec §Error paths: "The existing error blocks on this function must all
still pass unchanged … Their snapshots must not move."

The spec lists seven other error classes on `create_sdr_weights()`, and the
test-spec requires their snapshots to stay put. Quality gate 15 covers print
snapshots only, and the Track 2 error-path bullet covers the four new blocks
only. Nothing in the plan says the seven existing snapshots must not move.
Inserting a validation branch is exactly the change that could move one: the
new check runs between `.validate_replicates_arg()` and the `sort_var` NA
check, so a misplaced insertion changes which error fires first.

Options:
- **[A]** Add a Track 2 criterion naming the seven classes, and a line in task
  12 stating that only four snapshots are new and no existing one moves. —
  Effort: low, Risk: low, Impact: pins the risk the validation insertion
  carries.
- **[B]** Rely on the full-suite run at task 56 to catch a moved snapshot. —
  Effort: none, Risk: medium, Impact: a moved snapshot fails the suite, but the
  builder may accept it as an expected update rather than treating it as a
  defect.
- **[C] Do nothing** — same as B.

**Recommendation: A** — the whole point of the ordering constraint in the spec
is that these seven do not move.

**Issue 8: "Why one PR" overstates the case for the formula fix**
Severity: SUGGESTION
Spec §Scope/In calls the formula bug "a separate, pre-existing documentation
bug", in scope "because this spec edits the same roxygen block".

The plan's fact 3 says the documentation corrections "cannot ship separately".
That holds for one ordering only. Shipping the `\deqn` fix first, in its own
docs PR, is self-consistent the moment it merges, and the forwarding PR then
adds a sub-section that agrees with an already-correct formula. The
non-separable half of fact 3 — the message text, the `NEWS.md` bullet and the
retired test block under gate 16 — is sound as written.

Options:
- **[A]** Split the `\deqn` fix into a preceding docs-only PR. — Effort: low,
  Risk: low, Impact: two PRs where the spec asks for one, against a binding
  spec field (`PR range: PR 1–1`).
- **[B]** Keep one PR and rewrite fact 3 to state the real reason: the spec
  binds the fix to this PR because the same roxygen block is being edited and
  the new sub-section asserts `4/R`. — Effort: low, Risk: low, Impact: the plan
  record stops carrying a necessity claim that only holds one way round.
- **[C] Do nothing** — a later reader cites fact 3 as proof the PR cannot be
  split, on an incomplete argument.

**Recommendation: B** — the spec sets the PR range, and a second PR for a
two-line LaTeX fix costs more process than it buys.

**Issue 9: Tasks 20, 25 and 26 do not say "verbatim"**
Severity: SUGGESTION
Consistency with tasks 15, 21, 22, 23, 24, 47 and 48.

Task 20 says "Use the two-line block from the spec"; tasks 25 and 26 point at
spec text the same way. None says "verbatim". Task 20 is the `\deqn` LaTeX
fix — the one place where a builder tidying the notation could reintroduce the
bug the PR exists to fix.

Options:
- **[A]** Add "verbatim" to tasks 20, 25 and 26. — Effort: low, Risk: low.
- **[B]** Leave them; the file and line pointers name the target. — Effort:
  none, Risk: low.
- **[C] Do nothing** — same as B.

**Recommendation: A**.

**Issue 10: A citation is off by one line**
Severity: SUGGESTION

The Notes section says `make_gss_taylor()` is defined at
`test-backend-messages.R:329`. `grep -n "^make_gss_taylor"` gives 328. The
citation is informational — the duplicate is out of scope and no task depends
on it.

Options:
- **[A]** Correct it to 328. — Effort: low, Risk: low.
- **[B]** Leave it. — Effort: none, Risk: low.
- **[C] Do nothing** — same as B.

**Recommendation: A**.

#### Section: PR map

No issues found. One PR matches the spec's binding `PR range: PR 1–1`. The
branch name `fix/sdr-forward-use-normal-hadamard` matches the prefix list in
`.claude/rules/core.md` §6 and in `github-strategy.md`.

#### Section: Files touched

No issues beyond Issue 10. The write surface matches the spec's Architecture
table row for row, including the seven regenerated man pages and the four plan
records. Verified against the repository: every cited line holds the text the
plan says it holds, `DESCRIPTION` is already at the target `0.2.0.9000` and
needs no bump, `NAMESPACE` carries 23 exports, the changelog directory and
naming convention exist, and `tests/testthat/_snaps/replicate-weights.md` is
the one snapshot file that receives the new error snapshots. No vignette and no
`_pkgdown.yml` edit is needed: their `create_sdr_weights` and Hadamard mentions
carry none of the stale claims.

### Counter-findings — recorded so a later pass does not re-open them

1. **Stage H failing until Stage I lands is deliberate.** It is the same
   red-then-green shape as Stage B into Stage C. Task 53 re-runs task 45 and
   all three greps pass. Nothing is left red when Stage J runs. Not a defect.
2. **The changelog entry is not scope creep.** The spec's Architecture table
   does not list it and the spec never says "changelog", but
   `github-strategy.md:150` requires an entry before every PR. It is a repo
   process artifact, not functional scope.
3. **Quality gate 16 undercounts its own sites.** The gate names two;
   `plans/spec-backend-message-classes.md` carries a third instance of the
   stale claim. Task 50 rewrites it anyway. The plan is right and the gate text
   is one short; no plan change follows.
4. **`plans/archive/doc-rewrite/2026-06-22-doc-rewrite-impl.md:1009` carries
   the `1/(2R)` scale factor.** It is the task log of a merged PR, on the same
   reading the plan's Notes apply to `plans/impl-backend-message-classes.md`.
   Gate 10 is scoped to `R/` and `man/`. No plan change follows.
5. **`fix/` against `feat/` is defensible either way.** The change adds an
   argument, which reads as `feat`, and fixes a forwarding bug, which reads as
   `fix`. The issue and both `NEWS.md` bullets are filed under bug fixes, so
   `fix/` matches the record. Not a finding.

---

## Summary (Pass 1)

| Severity | Count |
|---|---|
| BLOCKING | 0 |
| REQUIRED | 6 |
| SUGGESTION | 3 |

**Total issues:** 9, plus one raised by the orchestrator during verification
(Issue 7), for 10.

**Verdict: BLOCK.**

**Overall assessment:** The plan's structure, PR boundary, write surface and
task ordering are sound, and every pinned number in it matches the test-spec
digit for digit. All ten findings are corrections to the plan document — a
wrong line count, a silent tolerance, two missing greps, one missing test
block, one missing criterion, and three citation or wording slips. None
requires rethinking the approach.

---

## Plan Review: sdr-normal-hadamard — Pass 2 (2026-09-04)

Delta pass. Scope: the sections the resolver changed, named at the top of the
Stage 3 record — "Why one PR", tasks 12, 20, 25, 26, 27, 29, 37, 43a, 45, 62,
both acceptance tracks, and the Notes. The rest of the document was not
re-read, per the review-loop budget.

### Prior Issues (Pass 1)

| # | Title | Status |
|---|---|---|
| 1 | Task 27 asserts a result Stage F has not produced | ✅ Resolved — task 27 now confirms one page; the seven-page check stays at task 30 |
| 2 | Gates 12 and 18 have no verification task | ✅ Resolved — task 45 now runs five greps, and the two new patterns are stated |
| 3 | No task for the general no-warning assertion | ✅ Resolved — task 43a added, with a Track 2 bullet |
| 4 | Task 29 miscounts the block and omits "verbatim" | ✅ Resolved — five lines, verbatim |
| 5 | Task 37 omits its tolerance | ✅ Resolved — 1e-8 stated in the task and in the Track 2 bullet |
| 6 | The documentation-check row count is wrong | ✅ Resolved — ten rows plus the inheriting-page check, in both places |
| 7 | No criterion holds the seven existing error snapshots still | ✅ Resolved — named in task 12 and in a Track 2 bullet |
| 8 | "Why one PR" overstates the case for the formula fix | ✅ Resolved — fact 3 now states the spec's own reason |
| 9 | Tasks 20, 25 and 26 do not say "verbatim" | ✅ Resolved |
| 10 | A citation is off by one line | ✅ Resolved — 328 |

### New Issues

No new issues found in the changed sections. The two new greps in task 45 name
the pattern they look for rather than the sentence they forbid, which is what
gate 18's own wording asks for. Task 43a sits at `mse = TRUE` on both
settings, so it does not duplicate task 38. The new snapshot criterion names
all seven classes the test-spec lists.

---

## Summary (Pass 2)

| Severity | Count |
|---|---|
| BLOCKING | 0 |
| REQUIRED | 0 |
| SUGGESTION | 0 |

**Total issues:** 0

**Verdict: PASS.**

**Overall assessment:** Every Pass 1 finding is resolved in the plan document
and the changed sections raise nothing new. The plan is ready to implement.
