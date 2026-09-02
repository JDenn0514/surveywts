# Spec — collapse the calibration replay message

Fixes [#111](https://github.com/JDenn0514/surveywts/issues/111).

---

## 1. Problem

`create_jackknife_weights(type = "grouped")` and the quasi-randomization
bootstrap replay the stored calibration inside every replicate. Each replay
announces its own convergence. At 25 replicates on a calibrated
non-probability design, 22 replicates print the same line:

```
i Raking converged in 1 sweep: all variables already met their margins. Weights
  were not adjusted.
```

The message comes from the calibration call, not from the replicate code. The
fix belongs at the replay site.

## 2. Decision

Muffle the message inside every replicate. Count how many replicates emit it.
After the loop, print one line that names the count:

```
i Raking converged in 1 sweep in 22 of 25 replicates: those replicates already
  met their margins.
```

The count carries information the individual lines do not. A high count means
the replay changed almost nothing, so the variance estimate may be near zero.
When no replicate emits the message, the loop prints nothing.

Two alternatives were rejected:

- **Print nothing at all.** Simpler, but it drops the signal that most
  replicates did no work.
- **Let the first message through and muffle the rest.** A single unlabelled
  line reads as if it describes the whole call, not one replicate out of 25.

## 3. Mechanism

`withCallingHandlers()` with a handler named for the condition class. The
handler increments a counter, then calls `invokeRestart("muffleMessage")`.

The message surface is small. `cli_inform()` appears at two places in the
package, `R/calibrate-utils.R:986` and `R/calibrate-utils.R:1042`. Both emit
the class `surveywts_message_already_calibrated`. A handler keyed on that
class catches this message and nothing else. Warnings stay untouched.

Verified in R before this spec was written:

| Check | Result |
|---|---|
| `invokeRestart("muffleMessage")` catches a `cli_inform()` condition | 3 of 3 muffled |
| Loop assignments reach the caller frame through the helper promise | 4 of 4 kept |
| The message still prints when no handler is present | prints |

## 4. Placement

The handler wraps the replicate loop, not the replay call.

`.dagjk_single_replicate()` calls `surveywts::calibrate_rake()` directly at
`R/jackknife-dagjk-utils.R:198`. It does not go through
`.dispatch_calibration_replay()`. There are four replay sites, and a handler on
the dispatch helper misses one of them. A handler on the loop covers all four,
and covers any site added later.

Three loops, each wrapped once:

| Loop | File |
|---|---|
| DAGJK, covers the IPW path and the calibration-only path | `R/create_jackknife_weights.R:653` |
| Quasi-randomization bootstrap, IPW path | `R/replicate-utils.R:471` |
| Quasi-randomization bootstrap, calibration-only path | `R/replicate-utils.R:592` |

## 5. Helpers

Two internal helpers go in `R/replicate-utils.R`, with the other shared
replicate helpers. Add a row for each to the index block at lines 7 to 14.

- `.muffle_replay_messages(expr, counter)` — evaluates `expr`, and muffles and
  counts the message. `expr` is a promise, so assignments in the loop body
  write to the caller frame. This is how `suppressMessages()` behaves.
- `.report_replay_messages(counter, replicates)` — prints one line when the
  count is above zero. Prints nothing when the count is zero. Called
  immediately after the loop closes.

The caller creates `counter` before the loop, with
`new.env(parent = emptyenv())`, and sets the count to `0L`. This matches the
idiom already used at `R/calibrate_to_survey.R:1205`. Each loop gets its own
counter, so a second call starts from zero.

The denominator is `replicates`, the number the caller asked for. A replicate
that fails emits no message, so the count can be lower than the number of
replicates that ran.

## 6. Message class

New class: `surveywts_message_replay_already_calibrated`. The name keeps it
apart from the per-replicate class it replaces.

Add one row to the `## Messages` table in `plans/error-messages.md:209`.

## 7. Scope

In scope:

- The two helpers, and the three loop wraps.
- The new message class, and its row in `plans/error-messages.md`.
- Remove the two stopgap comments that cite this issue,
  `R/create_jackknife_weights.R:300` and `R/create_replicate_weights.R:164`.
  Run `devtools::document()` to rebuild the `.Rd` files.

Out of scope:

- Warnings. `ipw()` warns from inside the bootstrap loop, and those warnings
  repeat. That is a separate problem and a separate issue.
- The per-replicate message itself. A direct `calibrate_rake()` call still
  prints it. Only the replay sites muffle it.

## 8. Tests

| Test | Expectation |
|---|---|
| Grouped jackknife on a calibrated non-probability design | Emits `surveywts_message_replay_already_calibrated` once |
| The same call | Does not emit `surveywts_message_already_calibrated` |
| Replay where every replicate meets its margins | The count in the message equals `replicates` |
| Quasi-randomization bootstrap on the same design | Emits the summary once |
| Replay where no replicate meets its margins | Emits no summary |
| Direct `calibrate_rake()` on already-calibrated data | Still emits `surveywts_message_already_calibrated` |

The last row is the existing test at `tests/testthat/test-03-rake.R:788`. It
must keep passing without a change.

## 9. Gates

- `devtools::document()`
- `devtools::test()`
- `devtools::check()` — 0 errors, 0 warnings, 0 notes
