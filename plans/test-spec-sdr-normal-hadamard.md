# Test-spec — sdr-normal-hadamard

**Status**: DRAFT
**Revision**: 4 — spec review resolved, 2026-09-03. Revision 3 made the
property blocks name their design and pin measured values. Revision 4 fixes the
degrees-of-freedom block, which built two designs and asserted four rows;
removes a duplicated fixture and a duplicated oracle block; pins the PSU sweep,
whose seed is recorded; and states every design-dependent number as an
invariant with the design attached.
**Scope**: `create_sdr_weights()` gains a `use_normal_hadamard` argument,
`logical(1)`, default `FALSE`. The published SDR variance formula on the help
page is corrected from `1/(2R)` to `4/R`.

Standards read:

- `.claude/standards/function-documentation.md`
- `.claude/standards/surveywts-conventions.md`
- `.claude/standards/testing-standards.md`
- `.claude/standards/testing-surveywts.md`
- `.claude/standards/engineering-preferences.md`
- `.claude/standards/code-style.md`

## Where the tests go

SDR tests live in `tests/testthat/test-replicate-weights.R`, in the
`create_sdr_weights() tests` section. Put every block below there, except the
message blocks, which go in `tests/testthat/test-backend-messages.R` next to
the two `create_sdr_weights()` blocks already there.

`impact.md` names `tests/testthat/test-create_sdr_weights.R`. That file does
not exist. Ignore it.

## Reference oracle

| Oracle | Version | Used for |
|---|---|---|
| `svrep::as_sdr_design()` | svrep 0.9.1 | The replicate factor matrix on both settings. Call it directly on a `svydesign` and compare. |
| `survey::SE(survey::svytotal(...))`, `survey::SE(survey::svymean(...))` | survey, installed build | The agreement on a total and the gap on a mean at `mse = TRUE`, the `mse = FALSE` divergence, and the size of the order trade across the PSU sweep. |
| `survey::degf()` | survey, installed build | The degrees-of-freedom difference between the two settings at a shared order. |

Wrap every block that calls either oracle in
`skip_if_not_installed("svrep")` or `skip_if_not_installed("survey")`, inside
the block, never at file level.

The column-count table below is not derived from an oracle. It was measured
against svrep 0.9.1 on `cps_2023`, over `replicates` 20 to 128. Treat it as
fixed expected values over that range, and do not read a ceiling into it: the
default setting reaches 256, 512 and every higher order that is four times a
power of two.

## Datasets

**The PSU count decides what these blocks measure, not the row count.** SDR
assigns as many Hadamard rows as there are first-stage units. Two designs with
the same row count and a different PSU count give different inactive replicate
counts, different degrees of freedom, and a different size of order trade.
Every block below therefore names its design in full, with the PSU count it
carries. A pinned value belongs to the design it was measured on. Where a block
asserts a general property, it asserts the property, not the reading.

| Dataset or fixture | PSUs | Purpose |
|---|---|---|
| `cps_2023`, as `surveycore::as_survey(cps_2023, weights = wtfinl)` | 9999 (no PSU column, so one per row) | The column-count table, the message blocks, the inactive-replicate block for many PSUs, and the degrees-of-freedom block. 9999 rows, no strata. This is where those values were measured, so it is where they are pinned. |
| `make_taylor_design()` — that is `n = 500L, n_strata = 4L, psus_per_stratum = 5L, seed = 42L` | 20 | The inactive replicate counts, the variance blocks at `mse = TRUE`, and the `mse = FALSE` divergence. Pass no arguments: the pinned values were measured at the defaults. |
| `make_taylor_design(n = 480L, n_strata = 4L, psus_per_stratum = k, seed = 42L)`, `k` in 5, 10, 20, 40, 60, 120 | 20, 40, 80, 160, 240, 480 | The PSU sweep block. The row count stays at 480 and the strata stay at four, so the PSU count is the only variable. |
| `make_taylor_design(seed = 1L)` | 20 | The oracle comparison and the validation-error blocks. Small and fast. |
| `make_taylor_design(n = 10L, seed = 1L)` | 10 | The "fewer units than the order" edge case. |

Every design above comes from a fixture with a recorded seed, so every pinned
value in this document is reproducible. Do not build a design inline for these
blocks, and do not add parameters to the fixture.

**The `cps_2023` design gets one definition, in `helper-test-data.R`.** Five
blocks in `test-replicate-weights.R` need it — the two column-count blocks, the
regression block, the second inactive-replicate block and the
degrees-of-freedom block — and three blocks in `test-backend-messages.R` need
it too. `test-backend-messages.R` defines a local helper for it today, at the
top of that file. testthat sources each test file in its own environment, so
that definition is not visible in `test-replicate-weights.R`.

Move the helper to `tests/testthat/helper-test-data.R`, alongside the other
survey object fixtures, and call it from both files. Delete the local
definition. Do not write the construction inline in any block:
`engineering-preferences.md` §1 puts repeated test setup in `helper-*.R`, and
eight inline copies would drift the first time the design gains a `strata` or
`ids` argument.

Build the design once per `test_that()` block by calling that helper.

Pass no `sort_var` to `create_sdr_weights()` in the pinned blocks. The function
supplies a row counter when `sort_var` is `NULL`, and that is the path the
measurements used.

## Per-function test plan

### `create_sdr_weights()`

#### Happy path — the measured column-count table

Two blocks, one per setting. Each block builds the `cps_2023` design once and
asserts five column counts. `test_invariants()` runs first, on the first
object each block builds.

Assert with `expect_length()` on the replicate weight name vector, or
`expect_identical()` against an integer. No tolerance — these are counts.

**`use_normal_hadamard = FALSE` (the default). Do not pass the argument.**

| `replicates` | Expected replicate columns |
|---|---|
| 20L | 32 |
| 40L | 64 |
| 50L | 64 |
| 100L | 128 |
| 128L | 128 |

**`use_normal_hadamard = TRUE`.**

| `replicates` | Expected replicate columns |
|---|---|
| 20L | 20 |
| 40L | 40 |
| 50L | 56 |
| 100L | 104 |
| 128L | 128 |

#### Regression — the argument reaches the back end

One block. Before this change the function declared `... Must be empty` and
did not enforce it, so `use_normal_hadamard = TRUE` was swallowed in silence
and no error was raised. A test that asserts "no error" therefore passes both
before and after the change and proves nothing.

Assert the **column count**:

| Scenario | Expected |
|---|---|
| `replicates = 100L`, `use_normal_hadamard = TRUE`, on the `cps_2023` design | 104 replicate columns, not 128 |

This block is the one that fails on the unfixed code. Confirm that it does
before the fix lands.

#### Happy path — the inactive replicate count

An inactive replicate is a replicate weight column that equals the base weight
column at every row. Count them by comparing each replicate column to the base
weight column with tolerance `1e-10`.

**The count is not capped at one.** It rises as the PSU count falls relative to
the Hadamard order. Two blocks pin that, one per design.

**Block 1 — few PSUs.** `make_taylor_design()`, 500 rows in 20 PSUs. Every cell
is an exact integer; use `expect_identical()` after coercing to integer.

| `replicates` | Setting | Columns | Inactive replicates |
|---|---|---|---|
| 20L | `TRUE` | 20 | 1 |
| 32L | `TRUE` | 32 | 1 |
| 40L | `TRUE` | 40 | 2 |
| 64L | `TRUE` | 64 | 2 |
| 128L | `TRUE` | 128 | 4 |
| 32L | default | 32 | 0 |
| 64L | default | 64 | 0 |
| 128L | default | 128 | 0 |

The rising count at 40, 64 and 128 is the load-bearing part of this block. A
test that asserts the count is 0 or 1 fails here.

**Block 2 — many PSUs.** The `cps_2023` design, 9999 rows and no PSU column, so
9999 PSUs. Far above every order tested, and there the count is 0 or 1.

| `replicates` | Setting | Inactive replicates |
|---|---|---|
| 100L | `TRUE` | 1 |
| 50L | `TRUE` | 0 |
| 100L | default | 0 |

The two blocks together are what make the "may produce inactive replicates"
wording in the documentation true, and what rule out both "produces one" and
"one at most".

#### Numerical correctness against the oracle

**One new block**, on `make_taylor_design(seed = 1L)` with `sort_var = id` and
`replicates = 40L`. Call `svrep::as_sdr_design()` directly on
`surveycore::as_svydesign(td)` with `sort_variable = "id"`, `mse = TRUE`, and
`use_normal_hadamard = TRUE`. Fold in the base weight the same way the existing
SDR oracle block in the file does.

| Setting | Expected | Tolerance |
|---|---|---|
| `use_normal_hadamard = TRUE` | Matrix equals the oracle called with `use_normal_hadamard = TRUE` | 1e-10 |

**Do not add a default-setting oracle block.** `test-replicate-weights.R`
already carries one, named "create_sdr_weights() matches svrep::as_sdr_design()
directly". It uses `make_taylor_design(n = 80L, seed = 7L)`,
`replicates = 40L`, `sort_var = id` and tolerance `1e-10`, and it compares the
matrix against the same oracle at the default setting. That block is the
"nothing moved" proof, and it must pass unchanged. A second block asserting the
same fact on a different seed adds no coverage.

#### Property — the two settings agree on a total at `mse = TRUE`, and can differ on a mean

Two blocks, both on `make_taylor_design()` — 500 rows in 20 PSUs — at
`mse = TRUE`, the default. Build the `svydesign` for each SDR design with
`surveycore::as_svydesign()` and estimate on the `y` column.

**Block 1 — the total agrees.** `survey::svytotal(~y, ...)` variance, at four
values of `replicates`, on both settings:

| `replicates` | var(total), both settings |
|---|---|
| 20L | 742.9939387275 |
| 32L | 742.9939387275 |
| 64L | 742.9939387275 |
| 128L | 742.9939387275 |

Pin each cell with `expect_equal()` at tolerance `1e-8`, and assert the two
settings against each other at the same tolerance. The design carries 20 PSUs,
at or below every order in the table, so the total variance does not move with
the order either.

The `replicates = 20L` row compares different orders: the default path lands on
32 and the `TRUE` path on 20. It still matches, because 20 PSUs sits at or
below both orders. The other three rows are shared orders.

**Block 2 — the mean can differ.** `survey::svymean(~y, ...)` variance, same
design, same four values:

| `replicates` | var(mean), default | var(mean), `TRUE` |
|---|---|---|
| 20L | 0.002537678051 | 0.002537864713 |
| 32L | 0.002537678051 | 0.002549751870 |
| 64L | 0.002537678051 | 0.002549751870 |
| 128L | 0.002537678051 | 0.002549751870 |

Pin each cell with `expect_equal()` at tolerance `1e-8`. Then assert that the
two settings are **not** equal at each of the four values, with
`expect_false(isTRUE(all.equal(...)))`. The gap at `replicates = 32L`, 64L and
128L is 0.48%.

The mechanism, for the block comment: a total is linear in the weights, so the
Hadamard orthogonality identity applies exactly and the inactive replicates
contribute zero. A mean is a ratio whose denominator is the replicate weight
sum, and that sum varies by replicate, so the inactive replicates enter it. The
two settings carry different numbers of inactive replicates.

Three scoping rules on both blocks:

1. **Assert on the standard error or the variance. Do not assert on a
   confidence interval.** The two settings report different degrees of freedom
   at a shared order — the `TRUE` setting reports one more — so the `t`
   multiplier differs and a confidence interval built on either design differs
   too. The size of that difference depends on the design and is small; the
   difference itself always holds. An interval assertion would fail on a
   correct implementation. See the degrees-of-freedom block below, which pins
   that difference on purpose.
2. **`mse = TRUE` only.** The agreement on a total is false at `mse = FALSE`.
   The `mse = FALSE` block below pins that divergence.
3. **Do not compare the replicate weight matrices.** They differ. Only the
   total variance matches.

Do not write a block that asserts the two settings give the same variance for a
**mean**. Block 2 is the evidence that such a block fails on the package's own
test design.

#### Property — the settings diverge on a total at `mse = FALSE`

One block, on `make_taylor_design()`. This is the counterpart to the total
block above: it proves the agreement on a total is bounded by `mse = TRUE` and
does not hold generally.

Create two SDR designs at `mse = FALSE`, one at the default setting and one at
`TRUE`, at each of four values of `replicates`. Assert
`survey::svytotal(~y, ...)` variance.

Measured on this design, the variance is constant across all four values on
each setting:

| `replicates` | var(total), default | var(total), `TRUE` |
|---|---|---|
| 20L | 742.9117643034 | 742.6073120709 |
| 32L | 742.9117643034 | 742.6073120709 |
| 64L | 742.9117643034 | 742.6073120709 |
| 128L | 742.9117643034 | 742.6073120709 |

Pin each cell with `expect_equal()` at tolerance `1e-8`. Then assert that the
two settings are **not** equal at each of the four values, with
`expect_false(isTRUE(all.equal(...)))`. `all.equal()` carries a default
tolerance of about `1.5e-8`, far below the gap on this design.

Also assert the column counts: 32 and 20 at `replicates = 20L`, then 32, 64 and
128 on both settings at the other three values.

**The invariant is the inequality. The size is a reading.** The gap here is
0.041%, and it tracks the inactive replicate count against the PSU count, so it
does not transfer to a design with a different PSU count. Do not assert a
percentage, and do not carry a gap size measured on any other design.

Note the `replicates = 20L` row compares different orders: the default setting
lands on 32 and the `TRUE` setting on 20. The other three rows are shared
orders.

The cause, for the block comment: at `mse = FALSE` the deviations are centred
on the mean of the replicate estimates, and each inactive replicate on the
`TRUE` path equals the full sample, so it pulls that mean.

No warning is expected on this combination. Assert `expect_no_warning()` on one
`mse = FALSE`, `use_normal_hadamard = TRUE` call.

#### Property — degrees of freedom differ at a shared order

One block, on the `cps_2023` design, 9999 PSUs. **Build four SDR designs**, all
at `mse = TRUE`:

1. `replicates = 64L`, default setting — lands on order 64.
2. `replicates = 64L`, `use_normal_hadamard = TRUE` — lands on order 64.
3. `replicates = 128L`, default setting — lands on order 128.
4. `replicates = 128L`, `use_normal_hadamard = TRUE` — lands on order 128.

Both settings land on the requested value at 64 and at 128, so each pair shares
an order. Four designs are needed for four rows; two designs at
`replicates = 128L` cannot produce the order-64 rows.

| Assertion | Expected |
|---|---|
| `survey::degf()` on design 1 | 62 |
| `survey::degf()` on design 2 | 63 |
| `survey::degf()` on design 3 | 126 |
| `survey::degf()` on design 4 | 127 |

Exact. Use `expect_identical()` after coercing to integer, or `expect_equal()`
with no tolerance — these are counts, not estimates.

**Assert the difference as well as the four values.** The invariant is that the
`TRUE` setting reports exactly one more than the default at a shared order.
Write that as two assertions: design 2 minus design 1 is 1L, and design 4 minus
design 3 is 1L. The four absolute values are a property of `cps_2023`, whose
PSU count is far above both orders. On a design with 20 PSUs the same
comparison gives 18 against 19 at both orders, because the PSU count caps the
value. A test written on 62 and 126 alone would fail on most designs.

The inactive replicates are the reason `survey` counts a different number of
usable contrasts.

This block is why the `mse = TRUE` blocks are scoped to the variance of a
total. All three must pass together: the total variance is equal, the mean
variance is not, and the degrees of freedom are not.

Wrap in `skip_if_not_installed("survey")`.

#### Property — the PSU count sets the size of the order trade

One block. This is the block that tells a caller when the smaller column count
is free and when it is not.

Build six designs with
`make_taylor_design(n = 480L, n_strata = 4L, psus_per_stratum = k, seed = 42L)`
for `k` in 5, 10, 20, 40, 60 and 120. That gives 20, 40, 80, 160, 240 and 480
PSUs. The row count stays at 480 and the strata stay at four, so the PSU count
is the only variable. On each design create two SDR designs at
`replicates = 50L`, `mse = TRUE`, one at the default setting and one at `TRUE`,
and take `survey::SE(survey::svytotal(~y, ...))`.

The default setting lands on order 64 and the `TRUE` setting on order 56, at
every PSU count.

**First, assert the boundary.** This is the invariant: both settings give the
same answer while the PSU count is at or below the smaller order, 56, and they
differ above it. It follows from the row assignment and holds on any seed.

| Assertion | Expected |
|---|---|
| Column count, default, at every PSU count | 64 |
| Column count, `TRUE`, at every PSU count | 56 |
| The two standard errors at 20 PSUs | Equal, tolerance 1e-8 |
| The two standard errors at 40 PSUs | Equal, tolerance 1e-8 |
| The two standard errors at 80 PSUs | **Not** equal |
| The two standard errors at 160 PSUs | **Not** equal |
| The two standard errors at 240 PSUs | **Not** equal |
| The two standard errors at 480 PSUs | **Not** equal |

Use `expect_false(isTRUE(all.equal(...)))` for the four inequality rows. The
two equality rows are the load-bearing ones: 20 and 40 PSUs both sit at or
below 56, so the smaller column count is free there.

**Second, pin the twelve standard errors.** The fixture carries `seed = 42L`,
so all twelve reproduce exactly. Pin each with `expect_equal()` at tolerance
`1e-8`.

| PSUs | SE, order 64 | SE, order 56 | Ratio |
|---|---|---|---|
| 20 | 29.250458 | 29.250458 | 1.0000 |
| 40 | 27.108206 | 27.108206 | 1.0000 |
| 80 | 25.978664 | 25.433342 | 0.9790 |
| 160 | 24.381831 | 23.093513 | 0.9472 |
| 240 | 24.539916 | 23.794741 | 0.9696 |
| 480 | 26.646328 | 22.709446 | 0.8523 |

Pinning them binds the gap sizes the help page quotes. Without it, a change
that preserved the equal/unequal boundary but moved the magnitudes would leave
the documented figures asserted by nothing.

**Do not assert that the gap grows monotonically with the PSU count.** It does
not. The ratios run 1.0000, 1.0000, 0.9790, 0.9472, 0.9696 and 0.8523, so the
240-PSU value reads above the 160-PSU value. Assert the boundary and the pinned
values, and nothing about the shape between them.

SDR is deterministic, so the gap is not sampling noise. Both estimates are
valid. All six designs are asserted; none is built and left unused.

Wrap in `skip_if_not_installed("survey")`.

#### Positional safety

One block, on `make_taylor_design(seed = 1L)`. The new argument sits after
`...`, so it cannot be reached by position and no existing call moves.
`replicates` is the one argument a caller can still pass positionally, so that
is what this block must exercise. **Write the call with `replicates`
positional:** `create_sdr_weights(td, 40L, sort_var = id)`.

| Assertion | Expected |
|---|---|
| Replicate column count from `create_sdr_weights(td, 40L, sort_var = id)` | 64 |
| The same object against `create_sdr_weights(td, replicates = 40L, sort_var = id)` | Identical replicate weight matrices |

A block that passes every argument by name tests nothing positional. Do not
write one, and do not repeat the oracle comparison here — the oracle blocks
above and the existing block in the file already carry it.

#### Weighting history

One block. The `"replicate_creation"` history entry records the setting.

| Assertion | Expected |
|---|---|
| The last history entry's `parameters$use_normal_hadamard`, after a default call | `FALSE` |
| The same field after a `use_normal_hadamard = TRUE` call | `TRUE` |
| `operation` on that entry | `"replicate_creation"` |

Use `expect_identical()` — these are exact logical values.

Also assert that no print snapshot moves. The printed history line reads the
method, the type and the replicate count, and none of those change at the
default. If a print snapshot changes, that is a failure, not a snapshot to
accept.

#### Error paths

Dual pattern for each: `expect_error(class = ...)` **and**
`expect_snapshot(error = TRUE, ...)`. Use `make_taylor_design(seed = 1L)`.

| Error class | Trigger | Pattern |
|---|---|---|
| `surveywts_error_use_normal_hadamard_invalid` | `use_normal_hadamard = NA` | `expect_error(class=)` + snapshot |
| `surveywts_error_use_normal_hadamard_invalid` | `use_normal_hadamard = c(TRUE, TRUE)` | `expect_error(class=)` + snapshot |
| `surveywts_error_use_normal_hadamard_invalid` | `use_normal_hadamard = "TRUE"` | `expect_error(class=)` + snapshot |
| `surveywts_error_use_normal_hadamard_invalid` | `use_normal_hadamard = 1` | `expect_error(class=)` + snapshot |

Four separate `test_that()` blocks, one observable behaviour each. The
snapshots differ between them, because the message reports the class and the
length of what was passed. The numeric row needs its own snapshot: the message
renders "numeric" where the character row renders "character", and that
snapshot is the only evidence that `1` is rejected rather than coerced.

The existing error blocks on this function must all still pass unchanged:
`surveywts_error_not_survey_design`, `surveywts_error_already_replicate`,
`surveywts_error_unsupported_class`,
`surveywts_error_nonprob_requires_probability_design`,
`surveywts_error_replicates_not_positive`,
`surveywts_error_replicates_not_whole_number`,
`surveywts_error_sort_var_has_na`. Their snapshots must not move.

#### Warning paths

None. `create_sdr_weights()` emits no warning class, and this change adds
none. Assert `expect_no_warning()` on one default call and one `TRUE` call.

#### Message paths

These blocks go in `tests/testthat/test-backend-messages.R`.

| Scenario | Expected |
|---|---|
| `replicates = 100L`, default | Emits `surveywts_message_replicates_rounded_up`; the text contains `100` and `128`; the result has 128 replicate columns |
| `replicates = 128L`, default | `expect_no_message()` |
| `replicates = 50L`, `use_normal_hadamard = TRUE` | Emits `surveywts_message_replicates_rounded_up`; the text contains `50` and `56` |
| `replicates = 128L`, `use_normal_hadamard = TRUE` | `expect_no_message()` |
| `replicates = 20L`, `use_normal_hadamard = TRUE` | `expect_no_message()` — the count matches the request exactly |
| `replicates = 40L`, `use_normal_hadamard = TRUE` | `expect_no_message()` — same reason |

The silence rule compares the request with the real column count, so it must
hold on both settings.

**Message wording.** The second bullet changes. Its old text claimed the
returned order was "the smallest order that fits" the request, which is false
on the default path: 64 is returned for a request of 50 while 56 exists. The
new text names the mechanism and the argument that controls it.

| Assertion | Expected |
|---|---|
| The message text at `replicates = 100L`, default | Contains `use_normal_hadamard` |
| The message text at `replicates = 100L`, default | Does **not** contain the phrase `smallest order` |

**One existing block must be retired.** `test-backend-messages.R` holds a
block named "create_sdr_weights() never mentions an argument it does not
forward". It asserts the message text does not contain `use_normal_hadamard`.
That premise is gone: the function forwards the argument and the message now
names it. Replace that block with the two wording rows above. Do not weaken
it into a block that asserts nothing.

#### Edge cases

Use `make_taylor_design(seed = 1L)`, 20 PSUs, for every row that does not name
its own design. The column count does not depend on the design, so these rows
pass on any fixture; naming one keeps the block consistent with the rule at the
top of this document.

| Case | Input | Expected behaviour |
|---|---|---|
| The validated floor, default path | `make_taylor_design(seed = 1L)`, `replicates = 4L` | 4 replicate columns; no error |
| The validated floor, normal path | `make_taylor_design(seed = 1L)`, `replicates = 4L, use_normal_hadamard = TRUE` | 4 replicate columns; no error |
| Below the floor | `make_taylor_design(seed = 1L)`, `replicates = 3L` with either setting | `surveywts_error_replicates_not_positive`; the new argument does not change which error fires or its order |
| Fewer units than the order | `make_taylor_design(n = 10L, seed = 1L)`, `replicates = 20L`, both settings | Returns a valid `survey_replicate` with the full order of columns. No error. `test_invariants()` passes. Do not assert an inactive replicate count here: 10 PSUs sits far below the order, which is the regime that produces the most inactive columns, and no count was measured on this design |
| A count the finer grid cannot reach | `make_taylor_design(seed = 1L)`, `replicates = 52L, use_normal_hadamard = TRUE` | 56 replicate columns, and the rounding message fires. The normal path still rounds up sometimes |
| `sort_var` and the new argument together | `sort_var = id, use_normal_hadamard = TRUE, replicates = 40L` | 40 replicate columns; the two arguments do not interact |

#### Invariants

`test_invariants(obj)` is the **first** assertion in every block that
constructs a `survey_replicate`. That is every block above except the error
blocks and the message-text blocks that discard the object.

`test_invariants()` asserts strict positivity of the main weight column on the
`survey_replicate` branch. The SDR replicate factors are bounded below by
about 0.293 on both settings, so a positive base weight gives positive
replicate weights and the invariant holds on both paths.

#### Documentation checks

These are read checks on the rendered help pages, not `test_that()` blocks. Run
them after `devtools::document()`.

On the `create_sdr_weights()` page:

| Check | Expected |
|---|---|
| The SDR variance equation in the Algorithm section | Shows the scale factor `4/R`. Does **not** show `1/(2R)` anywhere on the page |
| The Algorithm section | States that the match to SD2 is exact only while the unit count does not exceed the Hadamard order |
| The `use_normal_hadamard` parameter entry | Six lines or fewer. States the effect — which orders the count can take, and that the two settings differ once the PSU count exceeds the smaller order — and points at the Algorithm section. Carries no percentage, no decision rule and no recommendation |
| The Algorithm section | Carries the decision rule once: compare the PSU count with the order you would land on; the smaller order is free at or below that count; above it the gap grows with the PSU count. Quotes the measured sizes and names the design they were measured on |
| The `use_normal_hadamard` parameter entry and the Algorithm section | Neither attributes the size of the gap to stratification |
| The Algorithm section, on the two settings | Every statement that the settings give the same variance carries two qualifiers: `mse = TRUE`, and a total or another linear statistic. No statement claims the same variance for a mean |
| The Details section | Does not say the estimator "matches" the variance of a systematic random sample. No page number or equation number from Ash (2014) appears |
| The whole page | Does not say "power of 4". Does not say the normal path "produces" one inactive replicate — it says "may". Does not cap the count at one |
| The whole page | Gives no closed list of the orders the default setting reaches, and does not say "only". Where a list appears it reads as examples and continues past 256 |
| The Messages section | Its column-count example carries a condition — at the default, `replicates = 100` gives 128. No unconditional claim that `replicates = 100` gives 128 |

On one page that inherits the Messages section — for example
`create_gen_boot_weights()` or `create_replicate_weights()`: the same
conditional wording renders, and no other bullet in the section changed.

In `NEWS.md`, the unreleased 0.2.1 section:

| Check | Expected |
|---|---|
| The new bullet for the forwarded argument | Every statement that the two settings agree carries "at `mse = TRUE`, the default" and names a total. Gives no closed list of reachable orders and does not say "only". Carries no percentage; points at the help page instead |
| The existing replicate-message bullet | No longer says `create_sdr_weights()` does not forward `use_normal_hadamard`. Rewritten in place, with no correction line appended |
| The whole section | Nothing anywhere in the repository still asserts that the rounded-up message keeps `use_normal_hadamard` out of its text |

Three of these are mechanical string checks and can be a `test_that()` block of
`grep` over `R/` and `man/` rather than a reader check: no `\frac{1}{2R}` for
the SDR estimator, no "power of 4", and no surviving claim that the argument is
not forwarded. Write them that way. The `\deqn` bug shipped once already
because nothing checked it.

#### Gotchas covered, and gotchas out of scope

| Gotcha | Disposition |
|---|---|
| `...` is not checked, so the argument was swallowed in silence | Covered by the regression block, which asserts a column count rather than the absence of an error |
| The `@examples` comment pins 64 columns | Covered by the profile gate `devtools::run_examples()`, plus the `replicates = 50L` row of the default table |
| The back-end message tests pin 128 columns and silence at 128 | Covered by the message paths above; both hold at the default |
| The message text claimed the returned order is the smallest that fits | Covered by the message wording rows |
| A zero or negative base weight | Untestable. `surveycore::as_survey()` rejects a non-positive weight column, so the design cannot be built. Same disposition as 0-row and 1-row data |
| An NA base weight | Out of scope. The design can be built, and the SDR factors multiply the base weight, so the NA propagates to every replicate column. The behaviour is identical on both settings and unchanged by this argument |
| A single-row design | Untestable. `surveycore::as_survey()` rejects 1-row data with `` `data` has only 1 row. A survey design requires at least 2 observations. `` The input cannot be constructed, so no test is written. Same disposition as 0-row data |
| `mse = FALSE` on the normal path | **Covered.** See the `mse = FALSE` divergence block. The two settings give different variance estimates for a total at a shared order. The function does not warn; the block asserts `expect_no_warning()` |
| Degrees of freedom differ between the settings at a shared order | **Covered.** See the degrees-of-freedom block. This is also why the variance blocks assert on the variance and not on a confidence interval |
| The inactive replicate count is not capped at one | **Covered.** See the two inactive replicate count blocks. Block 1, on a design with 20 PSUs, pins counts of 1, 1, 2, 2 and 4 |
| A mean can differ between the settings at a shared order, even at `mse = TRUE` | **Covered.** Block 2 of the variance section pins the two mean variances and asserts they differ |
| The column count saving is free only while the PSU count is at or below the smaller order | **Covered.** See the PSU sweep block, which asserts equality at 20 and 40 PSUs and inequality at 80, 160 and 480 |
| The size of the gap above that threshold | **Covered.** The sweep fixture carries `seed = 42L`, so all twelve standard errors reproduce and the sweep block pins them at tolerance `1e-8`. That binds the gap sizes the help page quotes. The boundary is asserted separately, and no monotone rule is asserted |
| The degrees of freedom depend on the design | **Covered.** The degrees-of-freedom block pins the four values on `cps_2023`, 9999 PSUs, and separately asserts the invariant — the `TRUE` setting reports exactly one more than the default at a shared order. On a 20-PSU design the values are 18 and 19, so a test on 62 and 126 alone would not generalise |
| The default setting reaches orders above 256 | Out of scope as a numerical assertion. `replicates = 260L` returns 512 and `500L` returns 512, but nothing in this change moves that behaviour and a 512-column design is slow to build. It is covered as a **documentation** requirement: no page gives a closed list of reachable orders, and none says "only" |
| SDR is approximate, not exact, SD2 when the unit count exceeds the order | Out of scope as a numerical assertion. It is a property of the method, true before and after this change, and neither setting is uniformly closer to SD2, so no assertion distinguishes the two settings. It is covered as a **documentation** requirement: the rendered help page must state the qualification. `devtools::run_examples()` and `pkgdown::build_site()` in the profile gates confirm the page renders; a reader check confirms the sentence is present |
| The published variance formula printed the wrong scale factor | **Covered by a documentation check.** The rendered help page for `create_sdr_weights()` must show the scale factor `4/R` in the SDR variance equation, and must not show `1/(2R)`. Check the generated `.Rd` and the built pkgdown page. No numerical assertion applies: the function always computed `4/R`; only the printed formula was wrong |
| svrep's `find_minimum_hadamard_order()` is internal | Out of scope. Nothing in surveywts calls it and the new message wording does not need the number |

## Tolerances

| Estimand | Tolerance |
|---|---|
| Replicate weight matrix against the svrep oracle | 1e-10 |
| Inactive replicate detection (a column equals the base weight) | 1e-10 |
| Variance of a total and of a mean, pinned against a measured value, at `mse = TRUE` and at `mse = FALSE` | 1e-8 |
| Variance of a total, the two settings against each other at `mse = TRUE` | 1e-8 |
| Standard error, the two settings against each other at 20 and 40 PSUs | 1e-8 |
| The twelve sweep standard errors, pinned against their measured values | 1e-8 |
| Inequality rows — the mean at `mse = TRUE`, the total at `mse = FALSE`, the standard error above 56 PSUs | No tolerance. Use `expect_false(isTRUE(all.equal(...)))`, which carries its own default of about 1.5e-8 |
| Inactive replicate counts | Exact. Integer counts, no tolerance |
| Degrees of freedom | Exact. Integer counts, no tolerance |
| Replicate column counts | Exact. Use `expect_length()` or `expect_identical()`, no tolerance |
| History `parameters$use_normal_hadamard` | Exact. Use `expect_identical()` |

Every row follows the defaults in `testing-surveywts.md`: weight computations
use 1e-10 and reference-package comparisons use 1e-8. **No deviation.** Every
block names a fixture with a recorded seed, so every measured value is
reproducible and the inequality rows need no tolerance at all.

## Profile gates (tester runs ALL unless skip condition applies)

- [ ] `devtools::document()` — NAMESPACE/man/ unchanged after run
- [ ] `devtools::test()` — all tests pass
- [ ] `devtools::run_examples()` — all `@examples` run clean
- [ ] `R CMD build .` — tarball produced
- [ ] `R CMD check --as-cran` — 0 errors, 0 warnings, notes reviewed
- [ ] `pkgdown::build_site()` — site builds. No skip: the signature of an
      exported function changes and `man/` is regenerated
- [ ] `covr::package_coverage()` — >= 95% (target 98%)
- [ ] `air format --check .` — every R file already formatted
