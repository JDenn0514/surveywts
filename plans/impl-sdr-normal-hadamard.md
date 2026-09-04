# Implementation plan — sdr-normal-hadamard

**Status**: DRAFT
**Revision**: 1 — drafted 2026-09-04 from `plans/spec-sdr-normal-hadamard.md`
revision 4 and `plans/test-spec-sdr-normal-hadamard.md` revision 4.
**Spec**: `plans/spec-sdr-normal-hadamard.md`
**Test-spec**: `plans/test-spec-sdr-normal-hadamard.md`
**Source**: issue [#119](https://github.com/JDenn0514/surveywts/issues/119)

## Overview

This plan delivers the whole of `spec-sdr-normal-hadamard.md` in one PR.
`create_sdr_weights()` gains a `use_normal_hadamard` argument, `logical(1)`,
default `FALSE`, forwarded to `svrep::as_sdr_design()`. The same PR corrects
the published SDR variance formula from `1/(2R)` to `4/R`, rewords the
rounded-up message and the shared Messages section, and records the reversal
of decision Q8 of the replicate phase.

## PR map

- [ ] PR 1: `fix/sdr-forward-use-normal-hadamard` — forward
      `use_normal_hadamard` to the SDR back end, and correct the published
      variance formula

### PR 1: Forward `use_normal_hadamard`, and correct the variance formula

**Branch:** `fix/sdr-forward-use-normal-hadamard`
**Depends on:** none

#### Why one PR

The PR touches 20 files, which is above the usual bar. Three facts hold it
together:

1. **Seven of the 20 files are generated.** `devtools::document()` writes
   `man/create_sdr_weights.Rd` and the six pages that inherit the Messages
   section. Nobody edits them.
2. **Four are plan records rewritten in place.** The reversal record for Q8
   and the upstream message spec are two-line and one-block edits.
3. **The spec binds the documentation corrections to this PR.** The formula
   bug is pre-existing and separable in principle: a docs-only PR that changes
   `1/(2R)` to `4/R` is self-consistent the moment it merges. The spec puts it
   here for a stated reason — this PR edits the same roxygen block, and the new
   Algorithm sub-section asserts `4/R` two sections above the `\deqn`. In the
   order the plan runs, the argument lands first, so a second PR for the
   formula would leave one help page carrying two contradictory scale factors
   for one estimator for the length of that PR. Quality gate 16 is
   non-separable outright: the `NEWS.md` bullet, the retired test block and the
   forwarded argument are one claim, and any two of the three without the third
   is false.

The hand-written surface is 9 files: one source file for the argument, two
for text, three test files, `NEWS.md`, the changelog entry and the snapshot
file.

#### Tasks

Each task is 2 to 5 minutes. The stages run in order. Stage H fails until
Stage I lands; that is deliberate.

**Stage A — preflight**

1. Rename the local branch:
   `git branch -m fix/sdr-forward-use-normal-hadamard`. The branch has no
   upstream and is not pushed, so nothing else moves.
2. Confirm `plans/error-messages.md:144` already carries the row for
   `surveywts_error_use_normal_hadamard_invalid`. No edit is needed. The row
   is an uncommitted change on this branch.
3. Move `make_cps_taylor()` from `tests/testthat/test-backend-messages.R:338`
   into `tests/testthat/helper-test-data.R`, next to `make_gss_taylor()`.
   Delete the local copy. Run `devtools::test(filter = "backend-messages")`
   and confirm every existing block still passes.

**Stage B — red: the block that fails on the unfixed code**

4. Write the regression block in
   `tests/testthat/test-replicate-weights.R`, in the
   `create_sdr_weights() tests` section: `make_cps_taylor()`,
   `replicates = 100L`, `use_normal_hadamard = TRUE`, then
   `expect_length(result@variables$repweights, 104L)`. Put
   `test_invariants(result)` first.
5. Run it. Confirm it fails, and that the observed count is 128 rather than
   an error. A block that asserts "no error" passes on the unfixed code and
   proves nothing.
6. Write the four validation blocks on `make_taylor_design(seed = 1L)`, one
   each for `use_normal_hadamard = NA`, `c(TRUE, TRUE)`, `"TRUE"` and `1`.
   Each carries
   `expect_error(class = "surveywts_error_use_normal_hadamard_invalid")` and
   `expect_snapshot(error = TRUE, ...)`.
7. Run them. Confirm all four fail: no condition of that class exists yet.

**Stage C — the argument**

8. Add `use_normal_hadamard = FALSE` to the signature of
   `create_sdr_weights()`, between `sort_var` and `mse`.
9. Add the validation block after `.validate_replicates_arg()` and before the
   `sort_var` NA check. Copy the five-line `cli::cli_abort()` from the spec,
   section Errors, verbatim, including `class =`.
10. Add `use_normal_hadamard = use_normal_hadamard` to the
    `svrep::as_sdr_design()` call inside the `backend_fn` closure. This is
    the edit that fixes #119.
11. Add `use_normal_hadamard = use_normal_hadamard` as the fourth key of the
    `params` list, after `mse`. This is a second edit, not a substitute for
    task 10.
12. Run tasks 4 to 7. All five blocks pass. Accept the four new snapshots in
    `tests/testthat/_snaps/replicate-weights.md`. Exactly four snapshots are
    new. None of the seven existing error snapshots on this function moves —
    `surveywts_error_not_survey_design`,
    `surveywts_error_already_replicate`,
    `surveywts_error_unsupported_class`,
    `surveywts_error_nonprob_requires_probability_design`,
    `surveywts_error_replicates_not_positive`,
    `surveywts_error_replicates_not_whole_number` and
    `surveywts_error_sort_var_has_na`. A moved one means the new check landed
    in the wrong place in the validation order. Treat it as a defect, not a
    snapshot to accept.
13. Run the whole of `tests/testthat/test-replicate-weights.R`. The existing
    block "create_sdr_weights() matches svrep::as_sdr_design() directly" must
    pass unchanged. It is the proof that nothing on the default path moved.

**Stage D — the message text**

14. Write the two message-wording blocks in
    `tests/testthat/test-backend-messages.R`: at `replicates = 100L` on the
    default the text contains `use_normal_hadamard`, and the same text does
    not contain the phrase "smallest order". Run them and confirm both fail.
15. Replace bullet 2 of the `surveywts_message_replicates_rounded_up` branch
    of `.translate_backend_message()`, at `R/replicate-utils.R:1148-1153`,
    with the `paste0()` from the spec, section Messages, verbatim. Leave
    bullet 1 exactly as it is.
16. Run task 14. Both blocks pass.
17. Delete the block at `tests/testthat/test-backend-messages.R:465`,
    "create_sdr_weights() never mentions an argument it does not forward".
    The function now forwards the argument, so the block asserts a false
    claim. Quality gate 16.
18. Add four message-path blocks: `replicates = 50L` with
    `use_normal_hadamard = TRUE` fires and the text names 50 and 56; and
    `expect_no_message()` at `replicates` of 128L, 20L and 40L, all with
    `use_normal_hadamard = TRUE`. Leave the two existing default blocks
    unchanged.
19. Run the whole of `tests/testthat/test-backend-messages.R`. The block
    ".report_backend_messages() re-emits an unrecognised text verbatim" must
    still pass. It feeds svrep's own text to the translator and is not a
    claim about surveywts wording.

**Stage E — roxygen on `create_sdr_weights()`**

20. Replace the `\deqn` scale factor at `R/create_sdr_weights.R:41`. Copy the
    two-line block from the spec verbatim. Do not retype the LaTeX and do not
    tidy the notation — this is the one place where a paraphrase reintroduces
    the bug the PR exists to fix.
21. Add the SD2 qualification directly after the `\deqn` block, verbatim from
    the spec.
22. Rewrite the `@details` clause: the verb "matches" becomes "targets", and
    the sentence points at the Algorithm section. Verbatim from the spec.
23. Add `@param use_normal_hadamard` between `@param sort_var` and
    `@param mse`, verbatim from the spec. Six lines. No percentage, no
    decision rule, no recommendation.
24. Append the bold sub-section "Hadamard order and the column count", three
    paragraphs, to the end of `@section Algorithm`, verbatim from the spec.
25. Rewrite the `@examples` comment at `R/create_sdr_weights.R:63-64` to the
    two lines in the spec, verbatim. The number 64 stays; the rationale
    changes.
26. Add the second `@examples` block from the spec, verbatim, reusing
    `cps_design`. Confirm the whole `@examples` stays under 25 lines.
27. Run `devtools::document()`. Confirm `NAMESPACE` does not change and that
    `man/create_sdr_weights.Rd` does. One page changes here, not seven:
    `R/create_gen_boot_weights.R` is not edited until task 29, and roxygen2
    rewrites an `.Rd` file only when its content changes. Task 30 checks the
    other six.
28. Run `devtools::run_examples()`. Both SDR calls run clean. The rounded-up
    message is a message, not a failure.

**Stage F — the shared Messages section**

29. Replace the `surveywts_message_replicates_rounded_up` bullet at
    `R/create_gen_boot_weights.R:87-90` with the five-line conditional bullet
    from the spec, section Messages, verbatim. Leave the other five bullets
    untouched.
30. Run `devtools::document()`. Confirm the conditional sentence renders on
    all seven pages.

**Stage G — the property blocks**

All go in `tests/testthat/test-replicate-weights.R`. Every block that
constructs a `survey_replicate` puts `test_invariants()` first. Pass no
`sort_var` in the pinned blocks except where a task names one.

31. Column-count table, default setting: one block on `make_cps_taylor()`,
    five rows — 20 to 32, 40 to 64, 50 to 64, 100 to 128, 128 to 128.
    `expect_length()`, no tolerance.
32. Column-count table, `use_normal_hadamard = TRUE`: same shape, five rows —
    20 to 20, 40 to 40, 50 to 56, 100 to 104, 128 to 128.
33. Inactive replicate count, block 1: `make_taylor_design()`, 20 PSUs, eight
    rows. Count a replicate column as inactive when it equals the base weight
    at every row, at tolerance 1e-10. Expect 1, 1, 2, 2 and 4 at `replicates`
    of 20L, 32L, 40L, 64L and 128L on the `TRUE` setting, and 0 at 32L, 64L
    and 128L on the default. Counts are exact integers.
34. Inactive replicate count, block 2: `make_cps_taylor()`, three rows —
    100L on `TRUE` gives 1, 50L on `TRUE` gives 0, 100L on the default gives
    0.
35. Oracle block, `TRUE` setting only: `make_taylor_design(seed = 1L)`,
    `sort_var = id`, `replicates = 40L`. Call `svrep::as_sdr_design()`
    directly on `surveycore::as_svydesign(td)` with `sort_variable = "id"`,
    `mse = TRUE` and `use_normal_hadamard = TRUE`. Fold in the base weight
    the way the existing oracle block in the file does. Tolerance 1e-10.
    Put `skip_if_not_installed("svrep")` inside the block. Do not add a
    default-setting oracle block — the file already carries one.
36. Variance at `mse = TRUE`, block 1, the total: `make_taylor_design()`,
    four `replicates` values — 20L, 32L, 64L and 128L. Pin
    `742.9939387275` on both settings at tolerance 1e-8. Put
    `skip_if_not_installed("survey")` inside the block.
37. Variance at `mse = TRUE`, block 2, the mean: same design and same four
    values, every pin at tolerance 1e-8. Pin `0.002537678051` on the default;
    pin `0.002537864713` at 20L and `0.002549751870` at 32L, 64L and 128L on
    the `TRUE` setting. Then assert the two are not equal at each of the four
    values, with
    `expect_false(isTRUE(all.equal(...)))`. Assert on the variance, never on
    a confidence interval.
38. Divergence at `mse = FALSE`: `make_taylor_design()`, four rows. Pin
    `742.9117643034` on the default and `742.6073120709` on the `TRUE`
    setting, at tolerance 1e-8. Add `expect_no_warning()` on one
    `mse = FALSE` plus `use_normal_hadamard = TRUE` call.
39. Degrees of freedom: build four designs on `make_cps_taylor()`, all at
    `mse = TRUE` — 64L default, 64L on `TRUE`, 128L default, 128L on `TRUE`.
    Pin `survey::degf()` at 62, 63, 126 and 127. Then assert the invariant
    twice: design 2 minus design 1 is `1L`, and design 4 minus design 3 is
    `1L`. Put `skip_if_not_installed("survey")` inside the block.
40. PSU sweep: six designs from
    `make_taylor_design(n = 480L, n_strata = 4L, psus_per_stratum = k, seed = 42L)`
    with `k` in 5, 10, 20, 40, 60 and 120, at `replicates = 50L` and
    `mse = TRUE`. Assert 64 columns on the default and 56 on the `TRUE`
    setting at every PSU count. Assert the two standard errors are equal at
    20 and 40 PSUs, tolerance 1e-8, and not equal at 80, 160, 240 and 480.
    Pin all twelve standard errors at tolerance 1e-8. Assert nothing about
    the shape between the boundary and 480 PSUs — the ratios are not
    monotone. Put `skip_if_not_installed("survey")` inside the block.
41. Positional safety: `make_taylor_design(seed = 1L)`. Write the call with
    `replicates` positional — `create_sdr_weights(td, 40L, sort_var = id)` —
    and assert 64 columns and a replicate weight matrix identical to the
    named call.
42. Weighting history: `parameters$use_normal_hadamard` on the last entry is
    `FALSE` after a default call and `TRUE` after a `TRUE` call, and
    `operation` is `"replicate_creation"`. Use `expect_identical()`.
43. Edge cases, six rows: `replicates = 4L` gives 4 columns on both settings;
    `replicates = 3L` still throws
    `surveywts_error_replicates_not_positive` on both settings;
    `make_taylor_design(n = 10L, seed = 1L)` at `replicates = 20L` returns a
    valid `survey_replicate` on both settings, with no error and no
    inactive-count assertion; `replicates = 52L` with
    `use_normal_hadamard = TRUE` gives 56 columns and fires the message;
    `sort_var = id` with `use_normal_hadamard = TRUE` and `replicates = 40L`
    gives 40 columns.
    **Task 43a — the no-warning block.** A separate `test_that()` block:
    `expect_no_warning()` on one plain default call and one plain
    `use_normal_hadamard = TRUE` call, both at `mse = TRUE` on
    `make_taylor_design(seed = 1L)`. This is the general contract — the
    function emits no warning class and this change adds none. It is separate
    from task 38, which covers `mse = FALSE` only.
44. Run the full suite. Confirm no print snapshot moved. A moved print
    snapshot is a failure, not a snapshot to accept.

**Stage H — the mechanical documentation checks**

45. Write one `test_that()` block with five greps over the source tree:
    - no `1/(2R)` scale factor for the SDR estimator in `R/` or `man/` —
      quality gate 10;
    - no "power of 4" in `R/` or `man/` — quality gate 13;
    - no surviving claim that `create_sdr_weights()` does not forward
      `use_normal_hadamard`, in `R/`, `man/` or `NEWS.md` — quality gate 16;
    - no sentence in `R/` or `man/` that says the normal path "produces" an
      inactive replicate, and none that caps the count — match "produces one
      inactive", "at most one" and "only one inactive" — quality gate 12;
    - no sentence in `R/` or `man/` that ends a list of Hadamard orders at
      256, and no "only" before such a list — quality gate 18. The spec names
      this grep.

    Guard the block with
    `skip_if_not(dir.exists(test_path("..", "..", "man")))`. Under
    `R CMD check` the tests run from the check directory and the package
    source tree is absent, so an unguarded block errors there.
46. Run the block. The third grep fails until Stage I lands. The other four
    pass once Stage E is in.

**Stage I — `NEWS.md`, the reversal record, the changelog**

47. Add the first new bullet under `## Bug fixes` in
    `# surveywts 0.2.1 (development)`, verbatim from the spec, section
    `NEWS.md`.
48. Add the second new bullet — the corrected formula — verbatim from the
    spec.
49. Rewrite the existing replicate-message bullet at `NEWS.md:95-99` in
    place. Drop the clause that says the function does not forward the
    argument. Do not append a correction line, and do not leave the old text
    with a note beside it.
50. Rewrite `plans/spec-backend-message-classes.md` section 5 in place: the
    message block at lines 186-190 to the new wording, and the bullet at
    line 195 that says the function does not forward the argument.
51. Rewrite the `use_normal_hadamard` row of the Q8 table at
    `plans/archive/replicate/decisions-replicate.md:92` from Hide to
    Expose on `create_sdr_weights()`, reversed 2026-09-03, #119.
52. Rewrite `plans/archive/replicate/spec-replicate.md:1085`. Two cells: the
    "What it does" cell, which says power-of-4 and is wrong on the fact, and
    the "Proposed" cell, which becomes Expose, reversed 2026-09-03, #119,
    with the default still `FALSE`.
53. Run task 45. All five greps pass.
54. Write `changelog/replicate/fix-sdr-normal-hadamard.md`, in the format
    `.claude/skills/changelog-workflow.md` defines.

**Stage J — gates**

55. `devtools::document()`. `git diff --stat NAMESPACE` is empty.
56. `devtools::test()` — every test passes.
57. `devtools::run_examples()` — every `@examples` block runs clean.
58. `air format --check .` — every R file is already formatted.
59. `R CMD build .`, then `R CMD check --as-cran` — 0 errors, 0 warnings,
    notes reviewed.
60. `pkgdown::build_site()` — the site builds. No skip: the signature of an
    exported function changes and `man/` is regenerated.
61. `covr::package_coverage()` — at or above 95%, target 98%.
62. Read the rendered `man/create_sdr_weights.Rd` against the ten
    documentation-check rows of the test-spec. Row ten is the Messages check
    on that page. Then read one inheriting page — `create_gen_boot_weights()`
    or `create_replicate_weights()` — against the prose check below the
    table: the same conditional wording renders and no other bullet in the
    section changed.

#### Acceptance criteria — track 1, the spec contract

Every item cites `plans/spec-sdr-normal-hadamard.md`.

- [ ] **Signature.**
      `create_sdr_weights(data, replicates = 100L, ..., sort_var = NULL, use_normal_hadamard = FALSE, mse = TRUE)`.
      `...` does not move, so no existing caller moves. Section Signature.
- [ ] **Forwarding.** `svrep::as_sdr_design()` receives
      `use_normal_hadamard` under the same name, from inside the
      `backend_fn` closure. Section The back-end call.
- [ ] **`params`.** `use_normal_hadamard` is the fourth key of the `params`
      list, after `mse`, and reaches the `parameters` field of the
      `"replicate_creation"` history entry. Section `params` and the
      weighting history.
- [ ] **Error class.** `surveywts_error_use_normal_hadamard_invalid` fires
      when the value is not a single non-NA `TRUE` or `FALSE`. The check runs
      after `.validate_replicates_arg()` and before the `sort_var` NA check,
      so the order of the existing errors does not move. Section Errors.
- [ ] **Warnings.** None added. The `mse = FALSE` plus
      `use_normal_hadamard = TRUE` combination does not warn. Section
      Warnings.
- [ ] **Return.** A `survey_replicate` with
      `@variables$type = "successive-difference"`, unchanged in class and
      shape. `@variables$scale` is `4 / R` over the full column count.
      Section Returns.
- [ ] Quality gate 1 — `replicates = 50L` at the default returns 64 columns,
      and the `@examples` comment still says 64.
- [ ] Quality gate 2 — `replicates = 100L` at the default returns 128
      columns.
- [ ] Quality gate 3 — `replicates = 128L` at the default emits no message.
- [ ] Quality gate 4 — at the default, the replicate weight matrix matches
      `svrep::as_sdr_design()` called directly with
      `use_normal_hadamard = FALSE`.
- [ ] Quality gate 5 — every cell of the column-count table holds on both
      settings.
- [ ] Quality gate 6 — at a shared order and `mse = TRUE`, the two settings
      give the same variance for a total. The gate is not on a mean and not
      on a confidence interval.
- [ ] Quality gate 7 — every statement of variance-neutrality in the roxygen
      and in `NEWS.md` carries both qualifiers: at `mse = TRUE`, the default,
      and for a total. None claims it for a mean.
- [ ] Quality gate 8 — the PSU-count rule and the measured gap sizes appear
      in exactly one place in shipped text: the Algorithm sub-section. The
      `@param` and `NEWS.md` carry no percentage. No text attributes the gap
      to stratification.
- [ ] Quality gate 9 — `@section Algorithm` states that SDR is approximate,
      not exact, SD2 once the unit count exceeds the Hadamard order.
- [ ] Quality gate 10 — the `\deqn` reads the scale factor `4/R`, and no text
      in `R/` or `man/` still carries `1/(2R)` for the SDR estimator.
- [ ] Quality gate 11 — `@details` does not say the estimator matches the
      variance of a systematic random sample. No page or equation number of
      Ash (2014) appears.
- [ ] Quality gate 12 — no user-facing text says the normal path produces
      one inactive replicate, and none caps the count at one.
- [ ] Quality gate 13 — no user-facing text says "power of 4".
- [ ] Quality gate 14 — `NAMESPACE` is unchanged, with 23 exports.
- [ ] Quality gate 15 — no print snapshot moves.
- [ ] Quality gate 16 — nothing live in the repository still asserts that the
      rounded-up message keeps `use_normal_hadamard` out of its text. The
      three sites are the `NEWS.md` bullet, the retired test block and
      `plans/spec-backend-message-classes.md` section 5.
- [ ] Quality gate 17 — the shared Messages bullet states its column-count
      example with a condition. No help page carries an unconditional claim
      that `replicates = 100` gives 128.
- [ ] Quality gate 18 — no user-facing text gives a closed list of the orders
      the default setting reaches, and none says "only".
- [ ] Quality gate 19 — every measured number in the roxygen and in `NEWS.md`
      names the design it came from, and every claim built on one states the
      invariant rather than the reading.
- [ ] The reversal record for Q8 is written in all three places, each
      rewritten in place. Section Reversal record.

#### Acceptance criteria — track 2, the test-spec scenarios

Every item cites `plans/test-spec-sdr-normal-hadamard.md`. The tester runs
these without reading the spec.

- [ ] **Regression block** — `replicates = 100L` with
      `use_normal_hadamard = TRUE`, on the `cps_2023` design, gives 104
      columns. Confirmed failing before the fix landed.
- [ ] **Column-count blocks** — two blocks, one per setting, ten rows,
      `expect_length()`, exact.
- [ ] **Inactive replicate blocks** — two blocks. Block 1 on
      `make_taylor_design()`, 20 PSUs, pins 1, 1, 2, 2 and 4 on the `TRUE`
      setting and 0 on the default. Block 2 on `cps_2023` pins 1, 0 and 0.
- [ ] **Oracle block** — one new block, `TRUE` setting, tolerance 1e-10. No
      second default-setting oracle block was added, and the existing one
      passes unchanged.
- [ ] **`mse = TRUE` blocks** — the total is equal on both settings at
      tolerance 1e-8; the mean is pinned on both settings at tolerance 1e-8
      and asserted unequal. Neither block asserts on a confidence interval.
- [ ] **`mse = FALSE` block** — both totals pinned at tolerance 1e-8 and
      asserted unequal, plus `expect_no_warning()`.
- [ ] **Degrees-of-freedom block** — four designs on `cps_2023`; 62, 63, 126
      and 127 pinned, plus the two difference-of-one assertions.
- [ ] **PSU sweep block** — six designs; column counts 64 and 56 at every PSU
      count; equality at 20 and 40 PSUs and inequality at 80, 160, 240 and
      480; all twelve standard errors pinned at tolerance 1e-8; no monotone
      rule asserted.
- [ ] **Positional safety block** —
      `create_sdr_weights(td, 40L, sort_var = id)` gives 64 columns and a
      matrix identical to the named call.
- [ ] **Weighting history block** — `parameters$use_normal_hadamard` is
      `FALSE` then `TRUE`; `operation` is `"replicate_creation"`;
      `expect_identical()` throughout.
- [ ] **Error-path blocks** — four blocks, one per invalid input, each with
      `expect_error(class = )` and a snapshot.
- [ ] **The seven existing error snapshots do not move.**
      `surveywts_error_not_survey_design`,
      `surveywts_error_already_replicate`,
      `surveywts_error_unsupported_class`,
      `surveywts_error_nonprob_requires_probability_design`,
      `surveywts_error_replicates_not_positive`,
      `surveywts_error_replicates_not_whole_number` and
      `surveywts_error_sort_var_has_na` all still fire on the same input and
      render the same text. Exactly four snapshots are new.
- [ ] **No-warning block** — `expect_no_warning()` on one plain default call
      and one plain `TRUE` call, both at `mse = TRUE`. Separate from the
      `mse = FALSE` block.
- [ ] **Message-path blocks** — six rows: 100L on the default fires and names
      100 and 128; 128L on the default is silent; 50L on `TRUE` fires and
      names 50 and 56; 128L, 20L and 40L on `TRUE` are all silent.
- [ ] **Message-wording block** — the text at 100L on the default contains
      `use_normal_hadamard` and does not contain the phrase "smallest order".
- [ ] **Edge-case block** — six rows, per task 43.
- [ ] **Invariants** — `test_invariants()` is the first assertion in every
      block that constructs a `survey_replicate`.
- [ ] **The five mechanical grep checks** pass — quality gates 10, 12, 13, 16
      and 18 — and the block skips cleanly when the source tree is absent.
- [ ] **Documentation read checks** — the ten rows on the
      `create_sdr_weights()` page, the inheriting-page wording check below
      that table, and the three `NEWS.md` rows.
- [ ] **Tolerances** — every block uses the value the test-spec Tolerances
      table gives it. No deviation.
- [ ] **Profile gates** — `devtools::document()`, `devtools::test()`,
      `devtools::run_examples()`, `R CMD build .`, `R CMD check --as-cran`,
      `pkgdown::build_site()`, `covr::package_coverage()` at or above 95%,
      and `air format --check .`.

#### Files touched — the exact write surface

Hand-written:

| File | Change |
|---|---|
| `R/create_sdr_weights.R` | modified — signature, validation, back-end call, `params`, and six roxygen edits |
| `R/replicate-utils.R` | modified — bullet 2 of the `surveywts_message_replicates_rounded_up` branch |
| `R/create_gen_boot_weights.R` | modified — one bullet of the shared `@section Messages` |
| `tests/testthat/helper-test-data.R` | modified — `make_cps_taylor()` moves here |
| `tests/testthat/test-replicate-weights.R` | modified — new blocks from tasks 4, 6, 31 to 43a, and 45 |
| `tests/testthat/test-backend-messages.R` | modified — one block retired, six added, the local fixture deleted |
| `tests/testthat/_snaps/replicate-weights.md` | modified — four new error snapshots |
| `NEWS.md` | modified — two new bullets, one rewritten in place |
| `changelog/replicate/fix-sdr-normal-hadamard.md` | created |

Generated by `devtools::document()`:

| File | Change |
|---|---|
| `man/create_sdr_weights.Rd` | regenerated |
| `man/create_bootstrap_weights.Rd` | regenerated — inherits the Messages section |
| `man/create_brr_weights.Rd` | regenerated — same |
| `man/create_gen_boot_weights.Rd` | regenerated — defines the section |
| `man/create_gen_rep_weights.Rd` | regenerated — same |
| `man/create_jackknife_weights.Rd` | regenerated — same |
| `man/create_replicate_weights.Rd` | regenerated — same |
| `NAMESPACE` | unchanged. Quality gate 14. |

Plan records, each rewritten in place:

| File | Change |
|---|---|
| `plans/error-messages.md` | one new row, already written on this branch |
| `plans/spec-backend-message-classes.md` | the section 5 message block, and the bullet at line 195 |
| `plans/archive/replicate/decisions-replicate.md` | the Q8 row |
| `plans/archive/replicate/spec-replicate.md` | line 1085, two cells |

Pipeline artifacts already written on this branch, committed with the PR:

- `plans/spec-sdr-normal-hadamard.md`
- `plans/test-spec-sdr-normal-hadamard.md`
- `plans/impl-sdr-normal-hadamard.md`
- `plans/comprehension-sdr-normal-hadamard.md`
- `plans/spec-methodology-sdr-normal-hadamard.md`
- `plans/spec-review-sdr-normal-hadamard.md`

#### Notes

**`params` is not the forwarding path.** It feeds the weighting history
entry. Nothing in it reaches svrep. Task 11 alone leaves #119 unfixed. Task
10 alone leaves the history entry silent about the setting. Both are
required.

**Only one block fails on the unfixed code.** Task 4. Before this change the
function declared that `...` must be empty and did not enforce it, so
`use_normal_hadamard = TRUE` was swallowed without an error. A test that
asserts no error passes before and after. Assert the column count.

**Do not add a default-setting oracle block.**
`tests/testthat/test-replicate-weights.R` already carries one, on
`make_taylor_design(n = 80L, seed = 7L)`. It must pass unchanged, and a
second block on a different seed adds no coverage.

**Do not assert on a confidence interval anywhere.** `survey::degf()` differs
by one between the settings at a shared order, so the `t` multiplier differs
and an interval assertion fails on a correct implementation.

**Do not assert a monotone gap in the sweep.** The ratios run 1.0000, 1.0000,
0.9790, 0.9472, 0.9696 and 0.8523, so the 240-PSU value reads above the
160-PSU value. Assert the boundary and the pinned values, and nothing about
the shape.

**The grep block needs a guard.** Under `R CMD check` the tests run from the
check directory, and `R/`, `man/` and `NEWS.md` are not reachable two levels
up. Without `skip_if_not(dir.exists(...))` the block errors in the
`--as-cran` gate. There is no source-tree test in this package today, so
there is nothing to copy.

**`plans/impl-backend-message-classes.md` stays as it is.** It carries the
claim that the function does not forward the argument, at three lines. It is
the task log of a merged PR, and its code blocks quote the message text as it
shipped then. A log is not a live claim. The live sites are the three that
quality gate 16 names. Rewriting a merged PR's log would falsify the record.

**Do not add `.validate_logical_flag()`.** The DRY gap the spec records is
deferred to [#123](https://github.com/JDenn0514/surveywts/issues/123). Write
the `cli_abort()` inline, matching the shape `ipw()` uses for
`adjust_reference`.

**Do not validate `mse`.** Out of scope, and part of #123.

**Do not add `rlang::check_dots_empty()`.** Out of scope, filed as
[#120](https://github.com/JDenn0514/surveywts/issues/120).

**`make_gss_taylor()` is defined twice**, at `helper-test-data.R:507` and at
`test-backend-messages.R:328`. Out of scope. The test-spec asks only for the
`cps_2023` fixture to move.

**The `@examples` block must stay under 25 lines.** Reuse `cps_design` from
the existing block. Do not build a second design.

**Every pinned variance block needs a skip.** Put
`skip_if_not_installed("survey")` inside each block that calls
`survey::svytotal()`, `survey::svymean()` or `survey::degf()`, and
`skip_if_not_installed("svrep")` inside the oracle block. Never at file
level.
