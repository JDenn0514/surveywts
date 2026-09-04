# Spec — sdr-normal-hadamard

**Status**: DRAFT
**Revision**: 4 — spec review resolved, 2026-09-03. Revision 2 resolved all
eight issues in `plans/spec-methodology-sdr-normal-hadamard.md`. Revision 3
re-measured three of those facts on a clustered design. Revision 4 applies the
twelve REQUIRED findings of `plans/spec-review-sdr-normal-hadamard.md` and the
two counter-findings. One rule drives most of them: every table names the
design it was measured on and the range it covers, and every claim states the
invariant rather than the reading.
**Target version**: 0.2.0.9000 (ships in 0.2.1)
**PR range**: PR 1–1
**Source**: issue [#119](https://github.com/JDenn0514/surveywts/issues/119)

Standards read:

- `.claude/standards/function-documentation.md`
- `.claude/standards/surveywts-conventions.md`
- `.claude/standards/testing-standards.md`
- `.claude/standards/testing-surveywts.md`
- `.claude/standards/engineering-preferences.md`
- `.claude/standards/code-style.md`

## Document purpose

This document is the source of truth for the behaviour of
`create_sdr_weights()` after issue #119. It is a targeted fix outside the
phase structure.

`create_sdr_weights()` calls `svrep::as_sdr_design()` and forwards three
arguments: `replicates`, `sort_variable`, and `mse`. It does not forward
`use_normal_hadamard`, so the back end always runs at the svrep default
`FALSE`. On that path the Hadamard order is `4 x 2^k` — four times a power of
two — so a caller who asks for 50 replicates gets 64 columns. This spec adds
`use_normal_hadamard` as a named argument with default `FALSE`.

## Binding decisions

Both were resolved by the user on 2026-09-03. They are not re-opened here.

| ID | Decision |
|---|---|
| D1 | Add `use_normal_hadamard` as a named argument, default `FALSE`. Existing behaviour does not change. No existing caller moves. |
| D2 | Name the argument exactly `use_normal_hadamard`, matching svrep. |

## Measured facts

These were measured against svrep 0.9.1. Do not re-derive them.

**Two rules govern every table and every claim below.**

1. **Each table names the design it was measured on and the range it covers.**
   A value read on one design, or across one sweep, is a reading. It is not a
   property of the method.
2. **Each claim states the invariant, not the reading.** The invariant for
   degrees of freedom is "the normal path gives one more", not the pair 62 and
   63. The invariant for the default order grid is `4 x 2^k`, not a list that
   stops at 256.

**The PSU count drives SDR, not the row count.** The row assignment uses as
many Hadamard rows as there are first-stage units. Two designs with the same
row count and a different PSU count give different inactive replicate counts,
different degrees of freedom, and a different size of order trade.

Three designs are named repeatedly:

- **The `cps_2023` design**, 9999 rows and no PSU column, so 9999 PSUs.
- **The clustered design**, 500 rows in 20 PSUs, four strata, log-normal base
  weights and a standard-normal outcome column `y`. This is
  `make_taylor_design()` at its defaults, seed `42L`.
- **The PSU sweep**, 480 rows and four strata throughout, seed `42L`, with the
  PSUs per stratum varied so the PSU count runs 20, 40, 80, 160, 240 and 480.

The column-count table comes from the `cps_2023` design, with `mse = TRUE`. It
covers `replicates` 20 to 128; it bounds nothing above 128. Columns returned:

| `replicates` | `use_normal_hadamard = FALSE` | `use_normal_hadamard = TRUE` |
|---|---|---|
| 20 | 32 | 20 |
| 40 | 64 | 40 |
| 50 | 64 | 56 |
| 100 | 128 | 104 |
| 128 | 128 | 128 |

The column count depends on `replicates` and on the path, and on nothing else.
Re-measured on the clustered design, every cell holds.

An **inactive replicate** is a replicate column whose replicate factors all
equal 1, so the replicate weights equal the base weights. The count of them is
a separate table; see measured fact 3.

Eight further measured facts:

1. **The `FALSE` path returns `4 x 2^k`** — four times a power of two — and it
   returns the smallest such order at or above `replicates`. The rule has no
   upper bound. Measured on a 600-row design: `replicates = 200` returns 256,
   `260` returns 512, `300` returns 512 and `500` returns 512.

   Do not write a closed list of reachable orders, and do not write "only". An
   earlier sweep stopped at 256 and the list entered the spec as a property of
   the method; 512 and every higher `4 x 2^k` are reachable. Where a list helps
   a reader, write it as examples: "4, 8, 16, 32, 64, 128, 256, 512 and so on".

   The path does **not** reach the powers of four. The svrep help page for
   `as_sdr_design()` says "power of 4" and is wrong. Do not repeat that claim
   anywhere in surveywts.
2. The `TRUE` path reaches, in the range 4 to 140: 4, 8, 12, 16, 20, 24, 28,
   32, 36, 40, 44, 48, 56, 60, 64, 68, 72, 80, 84, 88, 96, 104, 108, 112, 120,
   128, 132, 136 and 140. It does not reach 52, 76, 92, 100, 116 or 124. The
   `TRUE` path therefore still rounds up sometimes: a request for 52 returns
   56.
3. **The inactive replicate count is not capped.** It rises as the PSU count
   falls relative to the Hadamard order. Measured on the clustered design at
   `use_normal_hadamard = TRUE`:

   | `replicates` | Order | Inactive replicates |
   |---|---|---|
   | 20 | 20 | 1 |
   | 32 | 32 | 1 |
   | 40 | 40 | 2 |
   | 64 | 64 | 2 |
   | 128 | 128 | 4 |

   The mechanism: the row assignment uses as many Hadamard rows as there are
   PSUs, and any column that is constant across those rows gives an inactive
   replicate. Fewer PSUs relative to the order leaves more columns constant.

   On the `cps_2023` design, where the PSU count is far above every order, the
   count is 0 or 1: it is 1 at `replicates` of 20, 40, 100 and 128, and 0 at 50.
   The `FALSE` path gives 0 at every order on both designs.

   Every user-facing sentence must say the normal path **may** produce inactive
   replicates. It must never say the path produces one, and it must never cap
   the count at one.
4. **At `mse = TRUE`, the default, the two paths give the same variance at a
   shared order for a linear statistic such as a total. A mean can differ.**
   A total is linear in the weights, so the Hadamard orthogonality identity
   applies exactly and the inactive columns contribute zero. A mean is a ratio
   whose denominator is the replicate weight sum, and that sum varies by
   replicate, so the inactive replicates enter it. The two paths carry
   different numbers of inactive replicates, so their mean variances differ.
   Measured on the clustered design, 20 PSUs, at `mse = TRUE`:

   | `replicates` | var(total), both paths | var(mean), `FALSE` | var(mean), `TRUE` |
   |---|---|---|---|
   | 20 | 742.9939387275 | 0.002537678051 | 0.002537864713 |
   | 32 | 742.9939387275 | 0.002537678051 | 0.002549751870 |
   | 64 | 742.9939387275 | 0.002537678051 | 0.002549751870 |
   | 128 | 742.9939387275 | 0.002537678051 | 0.002549751870 |

   **The first column is `replicates`, not the order.** The `replicates = 20`
   row compares two different orders: the default path lands on 32 and the
   `TRUE` path on 20. The default path has no order 20, so a header reading
   "Order" would contradict measured fact 1. The other three rows are shared
   orders, because both paths land on the requested value there.

   The total is identical to every digit. The mean differs by 0.48% on this
   design. Every
   assertion of equal variance at a shared order must name a total, or another
   linear statistic. An earlier measurement found equality for a mean on a
   design with singleton PSUs and constant base weights; that design does not
   exercise the difference.
5. **At `mse = FALSE` the two paths do not agree at a shared order.** Measured
   on the clustered design, 500 rows in 20 PSUs, `svytotal(~y)` variance,
   `mse = FALSE`:

   | `replicates` | `use_normal_hadamard = FALSE` | `use_normal_hadamard = TRUE` | Ratio |
   |---|---|---|---|
   | 20 | 742.9117643034 | 742.6073120709 | 0.99959019 |
   | 32 | 742.9117643034 | 742.6073120709 | 0.99959019 |
   | 64 | 742.9117643034 | 742.6073120709 | 0.99959019 |
   | 128 | 742.9117643034 | 742.6073120709 | 0.99959019 |

   The first column is `replicates`, not the order, on the same reading as
   measured fact 4: at `replicates = 20` the default path lands on order 32 and
   the `TRUE` path on order 20.

   The inactive replicates are the cause. At `mse = FALSE` the deviations are
   centred on the mean of the replicate estimates, and a replicate that equals
   the full sample pulls that mean. Every statement of variance-neutrality in
   this spec, in the roxygen, and in `NEWS.md` must carry the qualifier "at
   `mse = TRUE`, the default".

   **The invariant is the inequality, not its size.** The gap is 0.041% on this
   design. It tracks the inactive replicate count against the PSU count, so it
   does not transfer to a design with a different PSU count. Assert the
   inequality only. An earlier record carried four variances at orders 64 and
   128, showing a much larger gap. They came from a design with singleton PSUs,
   built in a script that drew other designs from the same seed first, so
   nobody can reproduce them. They are deleted, not corrected. The table above
   replaces them. Do not restore them, and do not quote a gap size that is not
   in the table above.
6. **The `TRUE` path reports one more degree of freedom than the default at a
   shared order.** That difference of one is the invariant. The absolute values
   are set by the design: `survey::degf()` cannot report more than the PSU
   count supports, the way the PSU count caps the inactive count in fact 3.

   Measured with `survey::degf()` on the `cps_2023` design, 9999 PSUs:

   | Order | `FALSE` | `TRUE` |
   |---|---|---|
   | 64 | 62 | 63 |
   | 128 | 126 | 127 |

   Measured on the clustered design, 20 PSUs: 18 on the default path and 19 on
   the `TRUE` path, at order 64 and at order 128 alike. The absolute values
   move with the design; the difference of one does not.

   The consequence holds on every design: a confidence interval built from the
   returned design differs between the paths at a shared order, even where the
   variance does not. The size of that difference falls as the degrees of
   freedom rise. One reading gives about 0.03% of the interval width, but the
   run did not record the design it came from, so treat the size as
   illustrative and the difference itself as the fact.
7. **The PSU count sets the size of the order trade, not stratification.**
   Measured on the PSU sweep: 480 rows, four strata and seed `42L` throughout,
   `replicates = 50`, `mse = TRUE`, `svytotal(~y)`, with `psus_per_stratum`
   varied so only the PSU count moves. The sweep covers 20 to 480 PSUs at one
   value of `replicates`; it bounds nothing outside that. The `FALSE` path
   takes order 64 and the `TRUE` path order 56:

   | PSUs | SE, order 64 | SE, order 56 | Ratio |
   |---|---|---|---|
   | 20 | 29.250458 | 29.250458 | 1.0000 |
   | 40 | 27.108206 | 27.108206 | 1.0000 |
   | 80 | 25.978664 | 25.433342 | 0.9790 |
   | 160 | 24.381831 | 23.093513 | 0.9472 |
   | 240 | 24.539916 | 23.794741 | 0.9696 |
   | 480 | 26.646328 | 22.709446 | 0.8523 |

   The rule this gives the caller: while the PSU count does not exceed the
   smaller order, both paths give the same answer and the smaller order is
   free. Above that the two estimates diverge, and the gap grows with the PSU
   count — about 2% at 80 PSUs, 5% at 160 and 15% at 480.

   The boundary is the invariant. It follows from the row assignment and holds
   on any seed. The six standard errors do not: they depend on this draw. The
   growth is also not monotone across the sweep — the ratios run 1.0000,
   1.0000, 0.9790, 0.9472, 0.9696 and 0.8523, so 240 PSUs sits at 3% and reads
   above 160 PSUs. State the three cited figures with the design attached; do
   not state a monotone rule.

   The check a caller makes is one comparison: their PSU count against the
   order they would land on. Neither number is wrong: both are valid SDR
   estimates at different Hadamard orders. SDR is deterministic, so this is not
   noise.

   An earlier measurement read 28% on a stratified design whose PSUs were all
   singletons, so it had 480 PSUs, and attributed the gap to stratification.
   Stratification was not the operative variable. The sweep above holds the
   strata fixed at four and moves only the PSU count.
8. SDR is approximate, not exact, SD2 when the unit count exceeds the Hadamard
   order. That is the ordinary case, including the bundled `cps_2023` example.
   Neither path is uniformly closer to SD2.

## Scope

### In

- One new argument on `create_sdr_weights()`, forwarded to
  `svrep::as_sdr_design()`.
- Validation of that argument, with one new error class.
- The argument joins the `params` list that becomes the `parameters` field of
  the `"replicate_creation"` weighting history entry.
- One reworded bullet in the `surveywts_message_replicates_rounded_up` text,
  and one reworded comment in the `@examples` block. Both carry the same false
  claim today.
- One reworded sentence in the shared `@section Messages` block in
  `R/create_gen_boot_weights.R`. It states without condition that
  `replicates = 100` gives 128 replicate columns. This change makes that
  conditional: at `use_normal_hadamard = TRUE` the same request gives 104.
  `create_sdr_weights()` inherits the section, so without the rewording one
  help page would state an unconditional column count two sections above the
  rule that makes it conditional. That is the same test this spec applies to
  the `\deqn` bug.
- Roxygen for the new argument, plus a new bold sub-section inside the
  existing `@section Algorithm`.
- A correction to the published SDR variance formula in `@section Algorithm`.
  The `\deqn` block prints the scale factor as `1 / (2R)`; the scale factor is
  `4 / R`. This is a separate, pre-existing documentation bug. It is in scope
  because this spec edits the same roxygen block and asserts `4 / R` elsewhere
  in the same help page.
- One sentence in `@section Algorithm` stating that SDR is approximate, not
  exact, SD2 once the unit count exceeds the Hadamard order.
- A reworded clause in `@details`: the estimator "matches" the variance of a
  systematic random sample becomes a qualified verb, tied to the sentence
  above.
- The reversal record for decision Q8 of the replicate phase.
- Two `NEWS.md` entries: one for the new argument, one for the corrected
  formula.

### Out

- Changing the default to `TRUE`. D1 settles this.
- `rlang::check_dots_empty()` on `create_sdr_weights()`. Five creators declare
  `... Must be empty` and only `create_jackknife_weights()` enforces it. Filed
  as [#120](https://github.com/JDenn0514/surveywts/issues/120).
- Validation of `mse` on `create_sdr_weights()`, or of `balanced` on
  `create_gen_rep_weights()`. Neither is validated today. See the GAP below.
- Reading the alternative Hadamard order out of the svrep message text. svrep
  computes it with `find_minimum_hadamard_order()`, which is internal and not
  exported, so the number is reachable only by a regex over svrep's raw text.
  The new message wording does not need the number.
- Any change to `mse = FALSE` behaviour, and any warning on the
  `mse = FALSE` plus `use_normal_hadamard = TRUE` combination. The combination
  is documented, not warned about. See the edge-case table and the rationale
  under it.

> ⚠️ GAP: `ipw()` validates its `adjust_reference` logical flag with the same
> five-line `cli_abort()` shape this spec asks for on `use_normal_hadamard`.
> Two call sites of the same shape is a DRY violation under
> `engineering-preferences.md` §1. The fix is a shared
> `.validate_logical_flag(value, arg_name, class)` helper in `R/utils.R`.
>
> **The deferral is on scope.** This PR is a targeted fix on one function, and
> the helper would add a diff on `R/ipw.R` to it. Snapshot churn is *not* the
> reason: the helper renders byte-identical text — `{.arg adjust_reference}`
> interpolated from `arg_name` and `{.cls {class(value)}}` from `value` — and
> `call = rlang::caller_env()` keeps the reported call at `ipw()`, so no
> `ipw()` snapshot moves.
>
> **Filed as [#123](https://github.com/JDenn0514/surveywts/issues/123)**
> (2026-09-04). That issue carries the helper signature, the reason no `ipw()`
> snapshot moves, and the three logical arguments that are not validated at all
> today — `mse` on `create_sdr_weights()`, `balanced` and `mse` on
> `create_gen_rep_weights()`, and `trim` on `ipw()`. Each of those needs its own
> error class row, so they are a decision in their own right rather than part of
> the refactor.

### Class and design support matrix

Unchanged by this spec.

| Input class | Behaviour |
|---|---|
| `survey_taylor` | Supported. |
| `survey_nonprob` | Error `surveywts_error_nonprob_requires_probability_design`. |
| `survey_replicate` | Error `surveywts_error_already_replicate`. |
| `data.frame`, tibble | Error `surveywts_error_not_survey_design`. |
| Any other class | Error `surveywts_error_unsupported_class`. |

## Architecture

Files touched:

| File | Change |
|---|---|
| `R/create_sdr_weights.R` | Signature, argument validation, back-end call, `params`, roxygen, `@examples`. In the roxygen: the new `@param`, the corrected `\deqn` scale factor, the SD2 sentence, the reworded `@details` verb, and the new Algorithm sub-section. |
| `R/replicate-utils.R` | The second bullet of the `surveywts_message_replicates_rounded_up` branch of `.translate_backend_message()`. |
| `R/create_gen_boot_weights.R` | One sentence in the shared `@section Messages` block, on the `surveywts_message_replicates_rounded_up` bullet. It reads `` asked for: `replicates = 100` gives 128. `` today. Replacement text below. Six pages inherit the section and this page defines it, so seven regenerate. |
| `plans/error-messages.md` | One new row. Already added by this spec. |
| `plans/spec-backend-message-classes.md` | The message block in §5, rewritten in place to the new wording. |
| `plans/archive/replicate/decisions-replicate.md` | The Q8 row, rewritten in place. |
| `plans/archive/replicate/spec-replicate.md` | Line 1085, rewritten in place. |
| `NEWS.md` | Three edits in the unreleased 0.2.1 section. Two new entries under `## Bug fixes`: the forwarded argument, and the corrected variance formula. Plus one rewrite in place: the existing replicate-message bullet says "The `create_sdr_weights()` message named `use_normal_hadamard`, which that function does not forward to `svrep::as_sdr_design()`". That clause is false once this PR lands. Rewrite it so it describes only what the message text changed to. This is what quality gate 16 checks. |
| `tests/testthat/test-replicate-weights.R` | New blocks. |
| `tests/testthat/test-backend-messages.R` | One block retired, others updated. |
| `tests/testthat/helper-test-data.R` | The `cps_2023` design fixture moves here, so both test files share one definition. |
| `man/create_sdr_weights.Rd` | Regenerated by `devtools::document()`. |
| `man/create_bootstrap_weights.Rd`, `man/create_brr_weights.Rd`, `man/create_gen_boot_weights.Rd`, `man/create_gen_rep_weights.Rd`, `man/create_jackknife_weights.Rd`, `man/create_replicate_weights.Rd` | Regenerated by `devtools::document()`. They inherit the reworded Messages section. |

Functions added: none.

Functions modified:

```r
create_sdr_weights(
  data,
  replicates = 100L,
  ...,
  sort_var = NULL,
  use_normal_hadamard = FALSE,
  mse = TRUE
)
```

Class changes: none. `NAMESPACE` is unchanged — the export list keeps its 23
entries and `create_sdr_weights()` is already one of them.

## Function contracts

### `create_sdr_weights()`

- **Documentation tier**: Tier 3 — Algorithmic. It implements a published
  resampling scheme with a variance formula. `@section Algorithm` and
  `@references` are both required and both already present.
- **Family**: `@family replicate-weights`.
- **Return visibility**: visible.

#### Signature

```r
create_sdr_weights(
  data,
  replicates = 100L,
  ...,
  sort_var = NULL,
  use_normal_hadamard = FALSE,
  mse = TRUE
)
```

`data` is first. `...` stays exactly where it is today, after `replicates`, so
every later argument must be named. `sort_var` is the optional tidy-select
argument and stays first after `...`. `use_normal_hadamard` and `mse` are
optional scalar control arguments. `use_normal_hadamard` shapes the method, so
it goes before `mse`, matching `create_gen_rep_weights()`, where `balanced`
sits before `mse`.

This deviates from `code-style.md` §4, which puts `...` last. The deviation is
deliberate and pre-existing: all six replicate creators put `...` early, and
moving it would make `sort_var`, `use_normal_hadamard` and `mse` reachable by
position. Keeping `...` where it is makes D1's "no existing caller moves"
true.

No existing caller moves. Every argument after `...` must already be passed by
name.

#### Arguments

| Argument | Type | Default | Semantics |
|---|---|---|---|
| `data` | `survey_taylor` | — | The design. PSUs should be in systematic selection order, or `sort_var` gives the order. |
| `replicates` | `integer(1)` | `100L` | Target replicate count, at least 4. The returned count is a Hadamard order at or above this value. |
| `...` | — | — | Must be empty. Not enforced today; see Out of scope. |
| `sort_var` | tidy-select, one bare column name | `NULL` | The systematic selection order. `NULL` uses row order. |
| `use_normal_hadamard` | `logical(1)` | `FALSE` | Selects which family of Hadamard matrix supplies the order. `FALSE` gives `4 x 2^k`. `TRUE` gives a finer grid, so the column count sits closer to `replicates`, and some replicates may be inactive. A different order is a different variance estimate once the PSU count exceeds it; see the trade below. |
| `mse` | `logical(1)` | `TRUE` | Centres each replicate deviation on the full-sample estimate (`TRUE`) or on the mean of the replicate estimates (`FALSE`). |

`use_normal_hadamard` is forwarded to `svrep::as_sdr_design()` under the same
name. It selects the matrix family, and the matrix family sets the column
count. The row assignment call inside svrep is identical on both paths.

The argument is a trade above one threshold and free below it. Two facts bound
it:

- **At a shared order and `mse = TRUE`, the default, the two paths give the
  same variance for a linear statistic such as a total.** Measured fact 4. For
  a mean, a ratio or a quantile the two can differ, because the paths carry
  different numbers of inactive replicates. The degrees of freedom also differ
  by one; see Returns.
- **The two paths usually land on different orders, and the order matters once
  the PSU count exceeds it.** Measured fact 7 states the rule and the measured
  gap sizes. Do not restate the percentages here; fact 7 and the Algorithm
  sub-section are the two places they belong.

So the caller makes one comparison: their PSU count against the order they
would land on. At or below that order the smaller column count costs nothing.
Above it the two paths report different standard errors. Both estimates are
valid. The default `FALSE` is the reproducible choice for existing work.

At `mse = FALSE` the two paths differ even at a shared order. Measured fact 5.

#### Returns

A `survey_replicate` with `@variables$type = "successive-difference"`.
Unchanged in class and shape.

`length(@variables$repweights)` is the Hadamard order, which depends on both
`replicates` and `use_normal_hadamard`, and on nothing else. The measured table
above is the contract over `replicates` 20 to 128. Above that range the rules
still hold: the default setting returns `4 x 2^k` and the `TRUE` setting
returns the smallest order its finer grid supplies at or above `replicates`.

`@variables$scale` is `4 / R`, where `R` is the full column count including
every inactive replicate. This is correct, not a compromise: an inactive column
contributes a zero term to the sum over replicates, while the orthogonality
identity that produces the SD2 quadratic form runs over all `R` columns.

**At a shared order, `survey::degf()` on the returned design gives one more on
the `TRUE` path than on the default.** That difference of one is the contract.
The absolute value is not: it is capped by the PSU count, so it changes with
the design. On the `cps_2023` design, 9999 PSUs, it is 62 against 63 at order
64 and 126 against 127 at order 128; on a 20-PSU design it is 18 against 19 at
both orders. Measured fact 6.

The consequence: a confidence interval built from the returned design differs
between the two paths at a shared order, even where the variance is identical.
Any assertion of equality between the paths must be written on the variance of
a total, not on the confidence interval and not on the variance of a mean.

A new entry with `operation = "replicate_creation"` is appended to the
weighting history.

#### The back-end call — this is the edit that fixes #119

`create_sdr_weights()` passes a closure to `.convert_and_call()`. The closure
captures `replicates`, `sort_col` and `mse` and calls `svrep::as_sdr_design()`
with them. **That call is the only place anything reaches svrep.** Add the
argument there, forwarded under the same name:

```r
result <- svrep::as_sdr_design(
  d,
  replicates = replicates,
  sort_variable = effective_sort,
  use_normal_hadamard = use_normal_hadamard,
  mse = mse
)
```

The closure captures `use_normal_hadamard` the same way it captures the other
three. The precedent is `create_gen_rep_weights()`, which passes `balanced` to
the back-end call and also records it in `params` — two separate edits, in two
places.

#### `params` and the weighting history

**`params` is not the forwarding path.** It is a separate argument to
`.convert_and_call()`, and `.convert_and_call()` writes it to the `parameters`
field of the `"replicate_creation"` history entry. Nothing in it reaches svrep.
A change here alone leaves #119 unfixed.

Add `use_normal_hadamard = use_normal_hadamard` as a fourth key of the `params`
list, after `mse`. The precedent is `create_gen_rep_weights()`, which puts its
`balanced` logical in `params`.

Two consequences to check, both benign:

- The printed history line reads only `method`, `type` and `replicates` from
  `parameters`. A new key does not change any print output, so no print
  snapshot moves.
- `as_taylor_design()` reconstructs the Taylor design from the
  `source_design` snapshot, not from `parameters`. A new key does not reach
  it.

#### Errors

| Class | Trigger condition |
|---|---|
| `surveywts_error_use_normal_hadamard_invalid` | `use_normal_hadamard` is not a single non-NA `TRUE` or `FALSE`: not logical, length not 1, or `NA`. |

Message template, matching the shape `ipw()` already uses for
`adjust_reference`:

```r
cli::cli_abort(
  c(
    "x" = "{.arg use_normal_hadamard} must be TRUE or FALSE.",
    "i" = paste0(
      "Got {.cls {class(use_normal_hadamard)}} of ",
      "length {length(use_normal_hadamard)}."
    ),
    "v" = paste0(
      "Set {.code use_normal_hadamard = FALSE} (default) or ",
      "{.code use_normal_hadamard = TRUE}."
    )
  ),
  class = "surveywts_error_use_normal_hadamard_invalid"
)
```

The check runs after `.validate_replicates_arg()` and before the `sort_var`
NA check, so the ordering of the existing errors does not move.

Without the check, `NA` and a length-2 vector both reach svrep and fail there
in an unclassed base R condition from an `if ()` test. That gives no class to
key on and a traceback into another package.

All other error classes on this function are unchanged:
`surveywts_error_not_survey_design`, `surveywts_error_already_replicate`,
`surveywts_error_unsupported_class`,
`surveywts_error_nonprob_requires_probability_design`,
`surveywts_error_replicates_invalid`,
`surveywts_error_replicates_not_positive`,
`surveywts_error_replicates_not_whole_number`,
`surveywts_error_sort_var_has_na`.

#### Warnings

None. This function emits no warning class today and adds none.

#### Messages

`surveywts_message_replicates_rounded_up` is unchanged in when it fires. The
branch compares `params$replicates` with the real column count and stays
silent when the two agree. That rule is correct on both paths, because it
reads the count the back end actually returned. Silence holds at
`replicates = 128` on both paths, and additionally at `replicates = 20` and
`replicates = 40` on the `TRUE` path.

The **text** changes. Bullet 1 stays exactly as it is — the upstream spec
`plans/spec-backend-message-classes.md` §5 rewrote it to name `replicates`,
the argument the caller has, and that fix stands. Bullet 2 carries a claim
that is false on the `FALSE` path: it says the returned order is "the smallest
order that fits" the request, but 64 is returned for a request of 50 while 56
exists.

New bullet 2, verbatim:

```r
"i" = paste0(
  "Successive difference replication takes the column count from the ",
  "order of a Hadamard matrix, and {.arg use_normal_hadamard} controls ",
  "which orders are reachable."
)
```

Rendered at `replicates = 100L` on the default path, bullet 1 reports that
`replicates` is 100 and the result has 128 replicate columns, and bullet 2
follows with the text above.

The new bullet states the mechanism and names the lever. It makes no claim
about which order is smallest, so it is true on both paths and needs no
branch on `params$use_normal_hadamard`. A path-dependent bullet, or a `v`
bullet that promises a smaller order, was considered and rejected: the smaller
order is not always available, so the promise would sometimes be false. A
request for 5 returns 8 on both paths.

Naming `use_normal_hadamard` in the message is now correct. §5 of the upstream
spec kept the name out only because the function did not forward it. That
reason is gone.

`plans/spec-backend-message-classes.md` §5 holds the old wording. Rewrite that
block in place to the new wording.

**The shared `@section Messages` block also goes stale.**
`create_sdr_weights()` carries `@inheritSection create_gen_boot_weights
Messages`, and that section describes this message with an unconditional
example: "The result then carries more replicate columns than you asked for:
`replicates = 100` gives 128." After this change, 128 is the count on the
default path only. At `use_normal_hadamard = TRUE` the same request gives 104 —
the number the column-count table above records.

Replace that sentence in `R/create_gen_boot_weights.R` with:

```
#' - `surveywts_message_replicates_rounded_up` — from
#'   [create_sdr_weights()], when the Hadamard matrix order is above
#'   `replicates`. The result then carries more replicate columns than you
#'   asked for, and `use_normal_hadamard` selects which orders are reachable:
#'   at the default, `replicates = 100` gives 128.
```

Six pages inherit this section — `create_bootstrap_weights`,
`create_brr_weights`, `create_gen_rep_weights`, `create_jackknife_weights`,
`create_replicate_weights` and `create_sdr_weights` — and
`create_gen_boot_weights` defines it, so the sentence renders on seven help
pages. Check the replacement against all of them. It holds,
because the bullet makes only two claims and both are about
`create_sdr_weights()`: the message comes from that function, and at the
default that function turns a request for 100 into 128 columns. Neither claim
depends on which page renders the sentence, and the other five bullets in the
section are untouched. The condition "at the default" is what makes the
sentence true after this change, on every page.

#### Edge cases

| Case | Behaviour |
|---|---|
| `use_normal_hadamard = FALSE` (the default) | Byte-for-byte the behaviour that ships today, on every input. This is the quality gate below. |
| `use_normal_hadamard = TRUE`, `replicates` a reachable order | The result has exactly `replicates` columns and the message stays silent. Measured at 20, 40 and 128. |
| `use_normal_hadamard = TRUE`, `replicates` not a reachable order | The result has the next reachable order above `replicates` and the message fires. Measured at 50 (56) and 100 (104). |
| `replicates = 4L`, the validated floor | Both paths supply order 4. The floor stays reachable on both. |
| `use_normal_hadamard = NA` | Error `surveywts_error_use_normal_hadamard_invalid`. |
| `use_normal_hadamard = c(TRUE, TRUE)` | Same error. |
| `use_normal_hadamard = "TRUE"` or `1` | Same error. `1` is not logical, so it is rejected rather than coerced. |
| Fewer units than the Hadamard order | Not an error on either path. The full order of columns is returned. svrep's row assignment closes the circle, and factors repeat. This is the extreme of the regime that produces inactive replicates, so both paths may return them here. Measured fact 3's "0 on the `FALSE` path" is scoped to the two designs it names, both of which carry at least 20 PSUs. Do not carry that 0 into this row. |
| A single-row design | Unreachable. `surveycore::as_survey()` rejects 1-row data with `` `data` has only 1 row. A survey design requires at least 2 observations. `` The failure happens before `create_sdr_weights()` is reached. Unchanged. |
| Empty (0-row) input | Unreachable. `surveycore::as_survey()` rejects 0-row data, so the design cannot be built. The failure happens before `create_sdr_weights()` is reached. Unchanged. |
| A zero or negative base weight | Unreachable. `surveycore::as_survey()` rejects a non-positive weight column with `` Weight column w has 1 non-positive value(s). All non-NA weights must be strictly greater than 0. ``, and `surveycore::survey_taylor()` rejects it too. The failure happens before `create_sdr_weights()` is reached. Unchanged. |
| An NA base weight | Reachable. `surveycore::as_survey()` accepts an NA weight. The SDR factors multiply the base weight, so the NA propagates to every replicate column at that row. Identical on both paths and unchanged by this spec. |
| Negative replicate weights | Cannot occur, for two reasons together. The base weight is strictly positive, because `surveycore` refuses a non-positive weight column — see the row above. And the replicate factors lie in `{1 - 2^-0.5, 1, 1 + 2^-0.5}`, all positive, with a finite population correction that shrinks them toward 1. True on both paths. |
| `mse = FALSE` with `use_normal_hadamard = TRUE` | The two paths give different variance estimates at a shared order. Measured fact 5. The cause is the inactive replicates: at `mse = FALSE` the deviations are centred on the mean of the replicate estimates, and a replicate that equals the full sample pulls that mean. The gap is 0.041% on the clustered design, 20 PSUs; its size tracks the inactive replicate count against the PSU count, so it does not transfer to another design. The function **does not warn**. It returns the estimate and documents the divergence. |

**Why no warning class on `mse = FALSE`.** Decided 2026-09-03. Three reasons,
recorded so a later reader does not re-open this:

1. The combination produces a different valid estimator, not an invalid one.
   Both paths are legitimate SDR variance estimates. A warning class is for a
   result the caller should not trust, and this is not one.
2. `create_sdr_weights()` emits no warning class today. Adding the first one
   for a valid combination sets the wrong bar for every later warning on this
   function.
3. The divergence is a property of `mse = FALSE`, which the caller sets
   deliberately, against a package default of `TRUE`. The documentation is the
   right place to state it.

The Warnings contract stays as it is: none.

## Documentation

### `@param`

```
#' @param use_normal_hadamard `logical(1)`, default `FALSE`. Selects which
#'   Hadamard orders the replicate count can take. `FALSE` gives orders that
#'   double from 4; `TRUE` gives a finer grid, so the count sits closer to
#'   `replicates`. The two settings give different variance estimates once the
#'   PSU count exceeds the smaller order — see the **Hadamard order and the
#'   column count** part of the Algorithm section.
```

Place it between `@param sort_var` and `@param mse`, matching the signature
order.

Six lines, which is the family maximum. `variance_estimator` on
`create_gen_boot_weights()` is the shape copied here: it is the other advanced
back-end argument whose choice changes the variance estimate, its `@param`
lists the options and stops, and its decision content sits in a named section
that `create_gen_rep_weights()` points at by name. `tau`, `balanced` and
`aux_var_names` run two lines each; `rho` runs three.

Three things stay **out** of the `@param`, per `function-documentation.md`'s
content rule that `@param` describes the effect and sends mechanism to a
`@section`:

- **The measured percentages.** No `@param` in this family carries one. They
  live in the Algorithm sub-section, stated once.
- **The decision rule.** "Compare your PSU count against the order you would
  land on" is the choosing guide, and it goes in the same sub-section.
- **The recommendation.** "Keep the default `FALSE` to reproduce existing
  work" is guidance. In this family guidance lives in `@details` or a named
  section — `rho` puts the option in `@param` and "Set `rho > 0` when you
  estimate a ratio" in `@details`. This one goes in the Algorithm sub-section
  with the rest.

Do not write "12% fewer columns", in the `@param` or anywhere else. Every
sentence about the smaller column count names the condition under which it is
free.

### Algorithm section

Three changes to the existing `@section Algorithm`: correct the variance
formula, add one sentence on SD2, and add one bold sub-section at the end.

#### The variance formula is wrong today

`R/create_sdr_weights.R:41` publishes the scale factor as `1 / (2R)`. The
scale factor is `4 / R`.

The invariant is algebraic and holds on every design and every order:
`(4/R) / (1/(2R))` is 8, so the published formula understates the variance by
exactly 8, and a reader who implements it — or who checks surveywts against it
— gets a standard error too small by a factor of `sqrt(8)`, about 2.83.

One reading confirms it. Measured on a 300-row design, `svytotal(~y)`,
R = 64: `survey` reports a variance of 1374.900221, `design$scale` is
0.0625 = 4/64, `(4/R)` times the sum of squares gives 1374.900221, and
`(1/(2R))` times the same sum gives 171.862528 — the same figure divided by 8.
The two variances are readings on that design; the factor of 8 is the fact.

The bug is pre-existing, not introduced by this change. It is fixed here
because this spec edits the same roxygen block and states `4 / R` in the
Returns contract and in the new sub-section. Shipping the change without the
fix would leave one help page carrying two contradictory scale factors for the
same estimator.

Replace the `\deqn` block with:

```
#' \deqn{\hat{V}_{SDR} = \frac{4}{R} \sum_{r=1}^{R}
#'   (\hat{\theta}^{(r)} - \hat{\theta}_{\text{full}})^2.}
```

`R` is the full column count, including every inactive replicate. This matches
`@variables$scale`, which `survey::svrepdesign()` sets to `4/ncol(repweights)`
for `type = "successive-difference"`.

#### The SD2 qualification

`@section Algorithm` must state, in one sentence, that the SD2 match is
approximate in the ordinary case. Add it directly after the `\deqn` block:

```
#' The match to SD2 is exact only while the unit count does not exceed
#' \eqn{R}. Above that the row assignment recycles row pairs, so SDR
#' approximates SD2 rather than reproducing it. The bundled `cps_2023` example
#' is in that regime.
```

#### The `@details` claim

`@details` today says the estimator "matches the variance of a systematic
random sample when PSUs are in selection order (Ash, 2014; Fay & Train,
1995)". Measurement contradicts the word "matches" in the ordinary case: on
one design the ratio to an SD2 target ran from 0.855 at order 20 to 1.344 at
order 32, and the departure was not monotone in the order. The run did not
record which design those ratios came from, so they are a reading, not a
contract. The fact that carries the verb change is measured fact 8: the match
is exact only while the unit count does not exceed the order.

Change the verb and tie the clause to the SD2 sentence above:

```
#' This estimator targets the variance of a systematic random sample when
#' PSUs are in selection order (Ash, 2014; Fay & Train, 1995). See the
#' Algorithm section for when the match is exact.
```

Do not cite an equation number or a page of Ash (2014). Nobody in this
pipeline read it, and the comprehension pass marks the DOI `[NOT FOUND]`.

#### The new sub-section

Add one bold sub-section at the end of `@section Algorithm`. The standard
permits `**Bold text**` sub-sections inside a section, and this content is part
of the matrix construction, so it belongs there rather than in a new top-level
section. It is not a `@section Limitations`: an inactive replicate is valid for
variance estimation, not a failure mode.

```
#' **Hadamard order and the column count.** The number of replicate columns is
#' the order of the Hadamard matrix, not `replicates`. `use_normal_hadamard`
#' selects which orders are reachable. At `FALSE`, the default, the order
#' doubles from 4 — 4, 8, 16, 32, 64, 128, 256, 512 and so on — and the
#' smallest such order at or above `replicates` is the one returned. At `TRUE`
#' the order comes from [survey::hadamard()], which supplies a finer grid: 20,
#' 40, 56, 104 and 128 are all reachable, so the count sits closer to
#' `replicates`. A request the finer grid cannot meet still rounds up — 52
#' returns 56. At `TRUE` some replicates may be inactive: all of their
#' replicate factors equal 1, so each equals the full sample. The count of
#' them rises as the PSU count falls relative to the order, and it is not
#' capped. An inactive replicate is valid. It contributes a zero term to the
#' variance sum, and the scale \eqn{4/R} counts it, which is what keeps the
#' estimator unbiased.
#'
#' The check to run is your PSU count against the order you would land on.
#' While the PSU count does not exceed the smaller order, both settings give
#' the same answer and the smaller order is free. Above that the two settings
#' give different variance estimates, and the gap grows with the PSU count.
#' Measured at `replicates = 50` on a design of 480 rows in four strata, the
#' standard error moved by about 2% at 80 PSUs, 5% at 160 and 15% at 480. Both
#' estimates are valid. Keep the default `FALSE` to reproduce existing work.
#'
#' Two further differences. At the same order and `mse = TRUE`, the default,
#' both settings give the same variance for a total, but a mean can differ,
#' because a mean is a ratio whose denominator varies by replicate and the
#' inactive replicates enter it. At `mse = FALSE` the two settings differ even
#' at the same order, for the same reason.
```

**This sub-section is the one home for the PSU-count rule in shipped text.**
The `@param` gives the effect in one sentence and points here. `NEWS.md` gives
the effect and points at the help page. Neither repeats the rule or the
percentages. A later correction to those figures then has one site to find, not
four.

Do not write "the normal path produces one inactive replicate", and do not
write "one at most". The count is not capped: measured 1, 1, 2, 2 and 4 at
`replicates` of 20, 32, 40, 64 and 128 on the clustered design, 20 PSUs.

Do not write a closed list of reachable orders on the default path, and do not
write "only". The rule is `4 x 2^k` with no upper bound; 512 is reachable and
so is every higher such order. Measured fact 1.

Do not write "power of 4" anywhere. That claim comes from the svrep help page
and is wrong.

Do not present the smaller column count as a saving on its own. Every sentence
about it names the condition under which it is free.

Every measured figure in this sub-section names the design it came from. The
2%, 5% and 15% readings are a property of the sweep in measured fact 7, not of
the method.

### `@examples`

Two changes.

**First**, the existing comment carries the same false claim as the message
bullet. The number 64 is correct and stays. The rationale is wrong and
changes:

```
#' # `replicates = 50L` returns 64 columns: the count is a Hadamard matrix
#' # order, and the default path doubles from 4 until it reaches 50.
```

**Second**, add one block that exercises the new argument. Measured:
`replicates = 50L` with `use_normal_hadamard = TRUE` on `cps_2023` returns 56
columns, with no inactive replicate. The comments must state only that.

```
#' # ask for a count closer to `replicates` --------------------------------
#' # The finer grid of Hadamard orders reaches 56, so the same request
#' # returns 56 columns rather than 64.
#' sdr_normal <- create_sdr_weights(
#'   cps_design,
#'   replicates = 50L,
#'   use_normal_hadamard = TRUE
#' )
#' length(sdr_normal@variables$repweights)
```

The block reuses `cps_design` from the existing example, so the whole
`@examples` stays under 25 lines. Both calls emit
`surveywts_message_replicates_rounded_up`, which is a message and does not
fail `devtools::run_examples()`.

### `@references`

The two entries stay as they are. They match records 1 and 2 of the
comprehension pass:

```
#' @references
#'   Ash, S. (2014). Using successive difference replication for
#'   estimating variances. *Survey Methodology, Statistics Canada*,
#'   40(1), 47--59. DOI: [unavailable]
#'
#'   Fay, R.E. and Train, G.F. (1995). Aspects of survey and model-based
#'   postcensal estimation of income and poverty characteristics for
#'   states and counties. *Joint Statistical Meetings, Proceedings of
#'   the Section on Government Statistics*, 154--159. DOI: [unavailable]
```

Leave the rendered `@references` block exactly as it stands in `R/`. The
`[unavailable]` markers above record what the comprehension pass could not
find; do not add them to the roxygen, and do not fabricate a DOI to fill them.

What changes is the **in-line** citation in `@details`, not this block. The
verb before the citation moves from "matches" to "targets", because
measurement contradicts "matches" in the ordinary case. Neither paper was read
in this pipeline, so no page number and no equation number is added anywhere.

## Reversal record

Q8 of the replicate phase set `use_normal_hadamard` to **Hide**. D1 reverses
that on exposure, not on the default value. The reversal is recorded in three
places, each rewritten in place rather than annotated:

1. `plans/archive/replicate/decisions-replicate.md`, the Q8 table. Change the
   `use_normal_hadamard` row from `**Hide**` to
   `**Expose** on create_sdr_weights() — reversed 2026-09-03, #119`.
2. `plans/archive/replicate/spec-replicate.md:1085`. Two corrections in one
   line. The "What it does" cell reads "Normal vs power-of-4 Hadamard
   matrix"; the rounding rule is four times a power of **two**, not a power of
   four, so that cell is wrong on the fact. The "Proposed" cell reads
   "**Hide** — default `FALSE` is standard"; change it to
   "**Expose** — reversed 2026-09-03, #119; the default stays `FALSE`".
3. `NEWS.md`, which is what a user reads.

Q8's stated rationale rests on the corrected fact. "Default `FALSE` is
standard" is still true, and D1 keeps that default. What Q8 got wrong is the
size of the gap the hidden argument left: it described the alternative as a
choice between a normal matrix and a power-of-4 matrix, which understates the
gap, because the default path skips every order between consecutive powers of
two.

## `NEWS.md`

Three edits in `# surveywts 0.2.1 (development)`. Two new bullets under
`## Bug fixes`, and one rewrite of an existing bullet in the same section.

The two new bullets are separate. The second is a documentation correction that
stands on its own, and a reader should see it whether or not they use the new
argument.

First bullet — the forwarded argument:

```markdown
* `create_sdr_weights()` did not forward `use_normal_hadamard` to
  `svrep::as_sdr_design()` (#119), so the back end always ran at the svrep
  default `FALSE`. On that path the Hadamard order doubles from 4 — 4, 8, 16,
  32, 64, 128, 256 and on up — so a request for 50 returned 64.

  `use_normal_hadamard` is now an argument, with the same default `FALSE`. No
  existing call changes. At `TRUE` the order comes from a finer grid, so a
  request for 50 returns 56 and a request for 20 returns 20. The finer grid
  costs inactive replicates — columns whose replicate factors all equal 1. The
  count rises as the PSU count falls relative to the order. An inactive
  replicate is valid for variance estimation.

  The two settings give different variance estimates once the PSU count
  exceeds the smaller order, and the gap grows with the PSU count. Both are
  valid. Keep the default to reproduce existing results. The Algorithm section
  of `?create_sdr_weights` gives the check to run and the measured sizes.

  Two further differences at the same order. For a total both settings give
  the same variance at `mse = TRUE`; for a mean they can differ. At
  `mse = FALSE` they differ for a total as well.

  This reverses decision Q8 of the replicate phase, which hid the argument.
```

The measured percentages do not appear here. They live in the Algorithm
sub-section of the help page, and this bullet points a reader at it.

Third edit — the stale bullet already in the same section. It reads:

> The `create_sdr_weights()` message named `use_normal_hadamard`, which that
> function does not forward to `svrep::as_sdr_design()`; it now names
> `replicates` and the real column count, and it fires only when the two
> differ.

The clause "which that function does not forward" is false once this PR lands.
Rewrite the bullet in place so it describes only what the message text changed
to: the message names `replicates` and the real column count, and it fires only
when the two differ. Drop the clause about forwarding. Do not append a
correction line, and do not leave the old text with a note beside it. This is
what quality gate 16 checks.

Second bullet — the corrected formula:

```markdown
* The SDR variance formula in the `create_sdr_weights()` help page printed the
  scale factor as `1 / (2R)`. The scale factor is `4 / R`, which is what the
  function has always computed. The published formula understated the variance
  by a factor of 8, so a reader who reimplemented it, or who checked surveywts
  against it, got a standard error too small by a factor of about 2.83. No
  computed result changes; only the documented formula does.
```

## Quality gates

Objectively verifiable. Items 1 to 4 hold at the default. Items 5 to 19 cover
both paths and the corrected documentation.

1. `create_sdr_weights(cps_design, replicates = 50L)` returns 64 replicate
   columns, and the `@examples` comment still says 64.
2. `create_sdr_weights(cps_design, replicates = 100L)` returns 128 replicate
   columns. This is the count pinned in the back-end message tests.
3. `create_sdr_weights(cps_design, replicates = 128L)` emits no message. This
   is the silence pinned in the back-end message tests.
4. At the default, the replicate weight matrix is identical to what
   `svrep::as_sdr_design()` returns when called directly with
   `use_normal_hadamard = FALSE`. Nothing on the default path moves.
5. Every measured cell of the column-count table holds, on both paths.
6. At a shared order and `mse = TRUE`, the two paths give the same **variance
   for a total**. Evidence: measured fact 4. The gate is scoped to a total
   because a total is linear, so the orthogonality identity applies exactly and
   the inactive replicates contribute zero; a mean is a ratio whose denominator
   varies by replicate, and the inactive replicates enter it. A gate written on
   a mean fails on the package's own test design, where the two mean variances
   differ by 0.48%. The gate is also **not** on the confidence interval:
   `survey::degf()` differs by one between the paths at a shared order, so a
   confidence-interval gate would fail on a correct implementation.
7. Every statement of variance-neutrality, in the spec, the roxygen and
   `NEWS.md`, carries two qualifiers: "at `mse = TRUE`, the default" and "for a
   total". No unqualified statement of neutrality survives, and no statement
   claims it for a mean.
8. No user-facing text presents the smaller column count as a saving without
   naming the condition in the same passage. The rule and the measured gap
   sizes of measured fact 7 appear in exactly one place in shipped text: the
   Algorithm sub-section. The `@param` states the effect in one sentence and
   points there; `NEWS.md` states the effect and points at the help page.
   Neither carries a percentage. No user-facing text attributes the gap to
   stratification, and every passage that quotes a gap size names the design
   it was measured on.
9. `@section Algorithm` states that SDR is approximate, not exact, SD2 once
   the unit count exceeds the Hadamard order.
10. The `\deqn` in `@section Algorithm` reads `\frac{4}{R}`. No text in `R/`
    or `man/` still carries `\frac{1}{2R}` for the SDR variance estimator.
11. `@details` does not say the estimator "matches" the variance of a
    systematic random sample. No page number or equation number of Ash (2014)
    appears anywhere.
12. No user-facing text says the normal path produces one inactive replicate,
    and none caps the count at one. Every such sentence says "may", and the
    Algorithm sub-section states that the count rises as the PSU count falls
    relative to the order.
13. No user-facing text says "power of 4".
14. `NAMESPACE` is unchanged.
15. No print snapshot moves.
16. Nothing in the repository still asserts that the rounded-up message keeps
    `use_normal_hadamard` out of its text. The function now forwards the
    argument and the message now names it, so that claim is stale wherever it
    appears. Two sites carry it: the replicate-message bullet in the 0.2.1
    section of `NEWS.md`, which the Architecture table quotes, and the
    `test-backend-messages.R` block that asserts the text does not contain the
    name, which is retired.
17. The shared `@section Messages` bullet for
    `surveywts_message_replicates_rounded_up` states its column-count example
    with a condition. No help page carries an unconditional
    "`replicates = 100` gives 128". Check the rendered page for
    `create_sdr_weights()` and for one function that inherits the section.
18. No user-facing text gives a closed list of the orders the default path
    reaches, and none says "only". A grep over `R/` and `man/` returns no
    sentence that ends the list at 256.
19. Every measured number in the roxygen, in `NEWS.md` and in this spec names
    the design it was measured on, and every claim built on one states the
    invariant rather than the reading. The three that this rule governs:
    degrees of freedom (the normal path gives one more), the order grid
    (`4 x 2^k`, no bound), and the size of any variance gap (design-dependent;
    assert the direction).

## Pipeline split

**recommended.** The signature of an exported function changes, a new error
class is added, and the number of replicate columns that downstream variance
estimates are built from changes on the opt-in path. `man/` is regenerated,
so the change is CRAN-relevant.
