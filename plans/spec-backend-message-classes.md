# Spec — give the back-end messages a class

Fixes [#114](https://github.com/JDenn0514/surveywts/issues/114).

---

## 1. Problem

Three of the seven replicate creators print a message from `svrep` on every
successful call. The messages are plain `message()` calls, so they carry the
class `simpleMessage/message/condition` and nothing else. A caller who wants
to quiet one of them has to wrap the call in a blanket `suppressMessages()`,
which also swallows every surveywts message. Every other diagnostic this
package emits carries a `surveywts_*` class (`.claude/rules/core.md` §4).

Measured on `develop`, one message each:

| Function | Message |
|---|---|
| `create_gen_boot_weights()` | ``For `variance_estimator='SD1', assumes rows of data are sorted in the same order used in sampling.`` |
| `create_gen_rep_weights()` | ``For `variance_estimator='SD2', assumes rows of data are sorted in the same order used in sampling.`` |
| `create_sdr_weights()` | ``Using Hadamard matrix of order 64. If `use_normal_hadamard=TRUE`, the smallest possible order is 56.`` |

`create_brr_weights()`, `create_jackknife_weights(type = "jkn")`, and
`create_bootstrap_weights()` emit nothing.

### Corrections to the issue

The issue attributes the Hadamard message to `survey`. All three come from
`svrep`:

| Message | Source |
|---|---|
| Row order | `svrep:::get_design_quad_form.survey.design` |
| Hadamard order | `svrep:::make_sdr_replicate_factors` |

### A fourth message

`create_gen_rep_weights()` emits a second message when `max_replicates` sits
below the fully efficient replicate count:

```
The number of replicates needed for fully efficient replication is 68, but
`max_replicates` is set to 20. Only a random sample of replicates will be
retained.
```

The default `max_replicates = Inf` hides it. `@param seed` documents the
behaviour. The message is unclassed like the other three, so it is in scope.

### The three messages are not alike

Two of them report a fact about the call that nothing else reports:

- `create_sdr_weights(replicates = 100L)` returns **128** replicate columns.
  `replicates = 20L` returns 32, and `replicates = 50L` returns 64. The
  `@param replicates` text says the count "may be slightly larger". The
  message is the only place the real count appears at run time.
- The `max_replicates` message names the natural replicate count, which the
  design does not otherwise expose.

One of them is a disclaimer. The row-order message fires whether or not the
rows are in sampling order. Nothing in surveywts checks the order.

### The Hadamard message names an argument that does not exist

It tells the reader to set `use_normal_hadamard = TRUE`.
`create_sdr_weights()` declares `... Must be empty` and forwards only
`replicates`, `sort_variable`, and `mse` to `svrep::as_sdr_design()`. The
advice cannot be followed.

## 2. Decision

Re-emit every back-end message as a classed surveywts message. Rewrite the
three known texts in the voice of this package. Pass anything unrecognised
through under one generic class.

Keep the row-order message. It is the only run-time notice of a precondition
the package cannot check, and a class makes it suppressible on its own.

Two alternatives were rejected:

- **Suppress the messages and rely on the prose.** It loses the replicate
  count and the natural replicate count, neither of which the prose carries.
- **Classify without rewriting.** It keeps the unreachable
  `use_normal_hadamard` advice and svrep's quoting style.

## 3. Mechanism

Every call that reaches svrep or survey goes through one line,
`svyrep_obj <- backend_fn(svydesign_obj)` at `R/replicate-utils.R:154`. Wrap
that line only.

Six functions call `.convert_and_call()`: `create_bootstrap_weights()`,
`create_brr_weights()`, `create_jackknife_weights()`,
`create_sdr_weights()`, `create_gen_boot_weights()`, and
`create_gen_rep_weights()`. `create_replicate_weights()`, the seventh, is a
dispatcher; it adds no back-end call of its own.

Two paths do not pass through the wrap and do not need to. Both build their
replicates in surveywts loops rather than in one back-end call:

- `create_jackknife_weights(type = "grouped")` on a `survey_nonprob` design,
  the delete-a-group jackknife.
- The quasi-randomization bootstrap.

The grouped jackknife on a `survey_taylor` design is not one of them. It
reaches `svrep::as_random_group_jackknife_design()` through
`.convert_and_call()` at `R/create_jackknife_weights.R:407`, so it passes
through the wrap like the other five. It emits nothing at svrep 0.9.1.

Those two loop paths emit surveywts messages, which already carry a class,
and #116 collapsed the one that repeated.

`withCallingHandlers()` on `message` collects each condition into a list,
then calls `invokeRestart("muffleMessage")`. The report comes after the call
returns, not from inside the handler, for two reasons:

- A handler cannot catch its own output. Emitting from inside the handler
  needs a recursion guard.
- The replicate count is known only after the back end returns.

The trade-off: if `backend_fn()` throws, the collected messages are lost. The
error is the useful output in that case.

svrep emits plain `message()`, so there is no class to key on. The match is on
the message text. Section 5 covers what happens when svrep rewords a message.

## 4. Placement and helpers

The report goes after `n_rep <- ncol(rep_matrix)` at `R/replicate-utils.R:171`,
so the translation can compare `n_rep` against `params$replicates`.

Four internal helpers go in `R/replicate-utils.R`, next to the replay-message
helpers at lines 934 to 1012. Add a row for each to the index block at lines 7
to 17.

They follow the shape `.new_replay_counter()` and
`.muffle_replay_messages(expr, counter)` already set: a store built by one
helper, and a second helper that takes `expr` as a promise and returns its
value. The call site then reads as one assignment, with no list to unpack.

- `.new_backend_message_store()` — returns an environment with `$msgs` set to
  `list()`.
- `.collect_backend_messages(expr, store)` — evaluates `expr`, appends each
  message condition to `store$msgs`, muffles it, and returns the value of
  `expr`. A condition that already carries a `surveywts_message_*` class is
  left alone: the handler returns without muffling, so the message prints
  where it was raised.
- `.translate_backend_message(cnd, n_rep, params, seed)` — returns
  `list(bullets = , class = )` for `cli::cli_inform()`. It returns the
  generic payload of §5 when no pattern matches, and `NULL` only when the
  message should be dropped, which happens for one case: the Hadamard message
  when `n_rep` equals `params$replicates`.
- `.report_backend_messages(store, n_rep, params, seed)` — loops over
  `store$msgs`, calls `.translate_backend_message()`, and emits each non-`NULL`
  payload. Emits nothing when the store is empty.

## 5. Message classes

Four new classes. Add one row for each to the `## Messages` table at
`plans/error-messages.md:209`.

### `surveywts_message_row_order_assumed`

From `create_gen_boot_weights()` and `create_gen_rep_weights()`.

```
i `variance_estimator = "SD1"` reads the row order of the data. It assumes the
  rows are still in the order the sample was drawn in.
v Sort the rows into selection order before you call this function.
```

The message fires for `"SD1"` and `"SD2"` only. In
`svrep:::get_design_quad_form.survey.design` the `message()` call sits behind
`if (variance_estimator %in% c("SD1", "SD2"))`. No other estimator reaches it.
The regex captures the estimator name.

The `v` bullet says "sort before you call" and names no argument. Neither
function has a `sort_var`. Only `create_sdr_weights()` does.

### `surveywts_message_replicates_rounded_up`

From `create_sdr_weights()`.

```
i `replicates` is 100, and the result has 128 replicate columns.
i Successive difference replication takes the column count from the order of
  a Hadamard matrix, and `use_normal_hadamard` controls which orders are
  reachable.
```

Two changes from svrep's text:

- It names `replicates`, the argument the caller has, and states the
  mechanism in place of svrep's claim about the smallest order. Reworded
  again on 2026-09-03 (#119), once `create_sdr_weights()` gained
  `use_normal_hadamard`, so the second bullet names that argument.
- It fires only when `n_rep` differs from `params$replicates`. svrep prints
  the message on every call. At `replicates = 128` this one prints nothing.

### `surveywts_message_replicates_subsampled`

From `create_gen_rep_weights()`.

```
i `max_replicates = 20` is below the 68 replicates that generalized
  replication needs to be fully efficient. The back end keeps a random sample
  of 20 of the 68.
v Set `seed` to make the draw reproducible, or raise `max_replicates`.
```

The natural count (68) is not available from the design, so the regex captures
it out of svrep's text. A `v` bullet always appears, and its advice depends
on `seed`: without a seed it says to set one or raise `max_replicates`, and
with a seed it says only to raise `max_replicates`.
`.convert_and_call()` already takes `seed`, so the check needs no new
argument.

### `surveywts_message_backend_note`

The fallback, for any message `.translate_backend_message()` does not match.

```
i The replicate weight back end reported: {conditionMessage(cnd)}
```

The text names no package. `conditionCall()` gives the call, not the
namespace, and walking `sys.frames()` to recover the namespace is more
machinery than the line is worth.

This class is what makes the text matching safe. If svrep rewords the
row-order message, it stops matching and arrives here — still visible, still
classed, no longer rewritten. Nothing goes silent.

It also covers two svrep messages that exist but never fire from surveywts
today:

- The `sort_variable = NULL` note in `as_sdr_design()`. surveywts always
  passes a sort column: `sort_var` when the caller gives one, and a temporary
  `.row_order` column when the caller does not.
- Anything a later svrep or survey release adds to one of the six back-end
  calls.

## 6. Documentation

One `@section Messages:`, owned by `create_gen_boot_weights()` and pulled into
the other two pages with `@inheritSection create_gen_boot_weights Messages`.
Decided 2026-09-03, overriding an earlier draft of this section that wrote the
block out three times: the three copies would have differed only in which
class each named, and the suppression recipe repeated verbatim.

`@inheritSection` copies a section whole, so the shared text has to read
correctly on all three pages. It therefore covers the family rather than one
function: a bulleted list of the four classes, each naming the function that
emits it and the condition that fires it, then the handler.

Use a bulleted list, not a markdown table. `Roxygen: list(markdown = TRUE)` is
set in `DESCRIPTION`, but no roxygen block in the package uses a table yet and
no `.Rd` file carries a `\tabular`. Bullets need no new machinery.

```r
withCallingHandlers(
  create_sdr_weights(design, replicates = 100L),
  surveywts_message_replicates_rounded_up = function(cnd) {
    invokeRestart("muffleMessage")
  }
)
```

Separately, and still per page: `create_gen_rep_weights()` states the
row-order precondition in its own `@details`, in place of the pointer to
`@section Choosing a target` at `R/create_gen_boot_weights.R:55`. That is the
part of #114 the shared section cannot carry, because it is about the
statistical method rather than the message.

One documentation bug to fix in the same file: the `create_sdr_weights()`
example says "computed from the 50 replicate columns" for `replicates = 50L`.
That call returns 64 columns on `cps_2023`. Measured.

Add one entry to `NEWS.md` under 0.2.1.

## 7. Scope

In scope:

- The three helpers, the wrap at `R/replicate-utils.R:154`, and the report at
  `R/replicate-utils.R:171`.
- The four message classes, and their rows in `plans/error-messages.md`.
- The three `@section Messages:` blocks, the row-order note on the
  `create_gen_rep_weights()` page, and the example comment fix on the
  `create_sdr_weights()` page. Run `devtools::document()` to rebuild the
  `.Rd` files.
- The `NEWS.md` entry.

Out of scope:

- Exposing `use_normal_hadamard` on `create_sdr_weights()`, which would make
  the smaller Hadamard orders reachable: 20 in place of 32, 56 in place of 64,
  104 in place of 128. Filed as
  [#119](https://github.com/JDenn0514/surveywts/issues/119).
- The missing `rlang::check_dots_empty()`. Five creators declare
  `... Must be empty` and only `create_jackknife_weights()` enforces it.
  Filed as [#120](https://github.com/JDenn0514/surveywts/issues/120).
- Warnings. This spec covers messages only.

## 8. Tests

New file `tests/testthat/test-backend-messages.R`, next to
`test-replay-messages.R`.

| Test | Expectation |
|---|---|
| `create_gen_boot_weights()` at the default estimator | Emits `surveywts_message_row_order_assumed` once |
| `create_gen_rep_weights()` at the default estimator | Emits `surveywts_message_row_order_assumed` once |
| `create_gen_boot_weights(variance_estimator = "Ultimate Cluster")` | No row-order message |
| `create_sdr_weights(replicates = 100L)` | Emits `surveywts_message_replicates_rounded_up`; the result has 128 columns |
| `create_sdr_weights(replicates = 128L)` | No rounding message |
| `create_gen_rep_weights(max_replicates = 20L)` | Emits `surveywts_message_replicates_subsampled`; the `seed` bullet is present |
| The same call with `seed = 1L` | Emits the message; no `seed` bullet |
| `create_brr_weights()` | `expect_no_message()` |
| `create_jackknife_weights(type = "jkn")` | `expect_no_message()` |
| `create_bootstrap_weights()` | `expect_no_message()` |
| `.convert_and_call()` with a `backend_fn` that calls `message("x")` | Emits `surveywts_message_backend_note` |
| Each of the three creators | No unclassed message survives |

Fixtures. The row-order and Hadamard tests need only the designs the examples
already build:

- `gss_2024` with `weights = wtssps, strata = vstrat, ids = vpsu, nest = TRUE`
  for the two generalized creators. It gives a natural replicate count of 68,
  so `max_replicates = 20L` fires the subsample message.
- `cps_2023` with `weights = wtfinl` for `create_sdr_weights()`.

## 9. Gates

- `devtools::document()`
- `devtools::test()`
- `devtools::check()` — 0 errors, 0 warnings, 0 notes
