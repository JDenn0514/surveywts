# Replay message collapse — implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use
> superpowers:subagent-driven-development (recommended) or
> superpowers:executing-plans to implement this plan task-by-task. Steps use
> checkbox (`- [ ]`) syntax for tracking.

**Goal:** Muffle the per-replicate calibration replay message, count it, and
print one summary line after each replicate loop. Fixes
[#111](https://github.com/JDenn0514/surveywts/issues/111).

**Architecture:** Three internal helpers in `R/replicate-utils.R`. A
`withCallingHandlers()` handler keyed on the condition class
`surveywts_message_already_calibrated` increments a counter and calls
`invokeRestart("muffleMessage")`. The handler wraps the `tryCatch()` that forms
each replicate body, so it covers all four replay sites. After the loop, one
helper prints the count.

**Tech Stack:** R, S7, cli, testthat 3 (edition 3, `>= 3.2.0`), air formatter.

Spec: `plans/spec-replay-message-collapse.md`.

## Global Constraints

- Message classes follow `surveywts_message_{snake_case_condition}`.
- `class=` is required on every `cli_abort()`, `cli_warn()`, and `cli_inform()`
  call. No exceptions.
- Internal helpers carry a `.` prefix and are never exported.
- New message classes go into `plans/error-messages.md` first.
- Commits use Conventional Commits. The scope for this work is `replicate`.
- Run `devtools::document()` before committing any file with roxygen2 changes.
- Run `devtools::check()` before opening the PR.
- Work stays on the current branch,
  `JDenn0514/grouped-jackknife-replay-narrates-every-replicat`.

---

## Measured facts

Every number below was measured on this branch before the plan was written. Do
not re-derive them; do confirm them when a step says to.

**The muffle mechanism**

| Check | Result |
|---|---|
| `invokeRestart("muffleMessage")` catches a `cli_inform()` condition | 3 of 3 muffled |
| Loop assignments reach the caller frame through the helper promise | 4 of 4 kept |
| The message still prints when no handler is present | prints |

**Which fixtures fire the message**

| Design | Loop | Replicates | Messages |
|---|---|---|---|
| `make_dagjk_datasets()$B` | DAGJK | 10 | 0 |
| `make_dagjk_datasets()$B` | DAGJK | 25 | 0 |
| Exact-margin, default `improvement` | DAGJK | 25 | 14 |
| Exact-margin, default `improvement` | DAGJK | 50 | 44 |
| Exact-margin, default `improvement` | bootstrap | 25 | 0 |
| Exact-margin, `improvement = 5` | bootstrap | 25 | 25 |
| IPW + rake, `improvement = 5` | bootstrap | 25 | 25 |
| IPW + rake, `improvement = 5` | DAGJK | 25 | 25 |

Two consequences shape the tests:

1. The existing fixtures do not fire. `make_dagjk_datasets()$B` gives 0.
2. `control = list(improvement = 5)` saturates the count: every replicate
   fires. Saturated fixtures carry no borderline chi-square comparison, so the
   assertions stay stable. Use them. Do not assert the un-saturated count of
   14 of 25.

The default raking algorithm is `"classic_ipf"`, and only that algorithm emits
the message.

---

## File structure

| File | Change | Responsibility |
|---|---|---|
| `R/replicate-utils.R` | Modify | The three helpers, and the two bootstrap loop wraps |
| `R/create_jackknife_weights.R` | Modify | The DAGJK loop wrap, and one example comment |
| `R/create_replicate_weights.R` | Modify | One example comment |
| `plans/error-messages.md` | Modify | One row for the new message class |
| `tests/testthat/helper-test-data.R` | Modify | `make_replay_message_datasets()` |
| `tests/testthat/test-replay-messages.R` | Create | Unit tests for the helpers, integration tests for the three loops |
| `man/create_jackknife_weights.Rd`, `man/create_replicate_weights.Rd` | Regenerate | `devtools::document()` output |

---

## Task 1: the helpers

**Files:**
- Modify: `plans/error-messages.md` (append one row to the `## Messages` table at the end of the file)
- Modify: `R/replicate-utils.R` (index block at lines 7-14; append helpers at end of file, currently 919 lines)
- Test: `tests/testthat/test-replay-messages.R` (create)

**Interfaces:**
- Consumes: nothing from earlier tasks.
- Produces:
  - `.new_replay_counter()` -> environment with `$n` set to `0L`
  - `.muffle_replay_messages(expr, counter)` -> the value of `expr`
  - `.report_replay_messages(counter, replicates)` -> `invisible(NULL)`
  - Message class `surveywts_message_replay_already_calibrated`

- [ ] **Step 1: Register the message class**

Append this row to the `## Messages` table at the end of
`plans/error-messages.md`:

```markdown
| `surveywts_message_replay_already_calibrated` | `create_jackknife_weights()`, `create_bootstrap_weights()` | One or more replicates of a calibration replay already met their margins; replaces the per-replicate `surveywts_message_already_calibrated` |
```

- [ ] **Step 2: Write the failing tests**

Create `tests/testthat/test-replay-messages.R`:

```r
# test-replay-messages.R
#
# Tests for the calibration replay message helpers (issue #111).
# The grouped jackknife and the quasi-randomization bootstrap re-run the
# stored calibration once per replicate. Each replay used to announce its own
# convergence. These tests pin the muffle-and-count behaviour that replaced it.

emit_already_calibrated <- function() {
  cli::cli_inform(
    c("i" = "all variables already met their margins"),
    class = "surveywts_message_already_calibrated"
  )
  invisible(TRUE)
}

# ============================================================================
# .new_replay_counter()
# ============================================================================

test_that(".new_replay_counter() starts at zero", {
  expect_identical(.new_replay_counter()$n, 0L)
})

test_that(".new_replay_counter() returns an independent counter each call", {
  a <- .new_replay_counter()
  b <- .new_replay_counter()
  a$n <- 5L
  expect_identical(b$n, 0L)
})

# ============================================================================
# .muffle_replay_messages()
# ============================================================================

test_that(".muffle_replay_messages() muffles the per-replicate message", {
  counter <- .new_replay_counter()
  expect_no_message(
    .muffle_replay_messages(
      for (i in 1:3) emit_already_calibrated(),
      counter = counter
    )
  )
})

test_that(".muffle_replay_messages() counts every muffled message", {
  counter <- .new_replay_counter()
  .muffle_replay_messages(
    for (i in 1:7) emit_already_calibrated(),
    counter = counter
  )
  expect_identical(counter$n, 7L)
})

test_that(".muffle_replay_messages() keeps loop side effects in the caller frame", {
  counter <- .new_replay_counter()
  acc <- integer(0)
  .muffle_replay_messages(
    for (i in 1:4) {
      emit_already_calibrated()
      acc <- c(acc, i)
    },
    counter = counter
  )
  expect_identical(acc, 1:4)
})

test_that(".muffle_replay_messages() returns the value of expr", {
  counter <- .new_replay_counter()
  out <- .muffle_replay_messages(
    {
      emit_already_calibrated()
      42L
    },
    counter = counter
  )
  expect_identical(out, 42L)
})

test_that(".muffle_replay_messages() leaves an unrelated message alone", {
  counter <- .new_replay_counter()
  expect_message(
    .muffle_replay_messages(
      cli::cli_inform(
        c("i" = "unrelated"),
        class = "surveywts_message_unrelated_for_test"
      ),
      counter = counter
    ),
    class = "surveywts_message_unrelated_for_test"
  )
  expect_identical(counter$n, 0L)
})

# ============================================================================
# .report_replay_messages()
# ============================================================================

test_that(".report_replay_messages() prints nothing when the count is zero", {
  counter <- .new_replay_counter()
  expect_no_message(.report_replay_messages(counter, replicates = 25L))
})

test_that(".report_replay_messages() emits the summary class above zero", {
  counter <- .new_replay_counter()
  counter$n <- 22L
  expect_message(
    .report_replay_messages(counter, replicates = 25L),
    class = "surveywts_message_replay_already_calibrated"
  )
})

test_that(".report_replay_messages() names the count and the replicate total", {
  counter <- .new_replay_counter()
  counter$n <- 22L
  msg <- NULL
  withCallingHandlers(
    .report_replay_messages(counter, replicates = 25L),
    surveywts_message_replay_already_calibrated = function(m) {
      msg <<- conditionMessage(m)
      invokeRestart("muffleMessage")
    }
  )
  expect_match(msg, "22 of 25 replicates", fixed = TRUE)
})

test_that(".report_replay_messages() returns invisible NULL", {
  counter <- .new_replay_counter()
  expect_null(.report_replay_messages(counter, replicates = 25L))
})
```

- [ ] **Step 3: Run the tests to verify they fail**

```r
devtools::load_all(); testthat::test_file("tests/testthat/test-replay-messages.R")
```

Expected: every test errors with `could not find function ".new_replay_counter"`.

- [ ] **Step 4: Add the helpers**

Append to the end of `R/replicate-utils.R`:

```r
# ============================================================================
# .new_replay_counter()
# ============================================================================

# Create a fresh counter for the calibration replay message. One counter per
# call to the enclosing weighting function, so a second call starts at zero.
#
# Returns: an environment with $n set to 0L
.new_replay_counter <- function() {
  counter <- new.env(parent = emptyenv())
  counter$n <- 0L
  counter
}

# ============================================================================
# .muffle_replay_messages()
# ============================================================================

# Muffle and count the already-calibrated message that a calibration replay
# emits inside a replicate loop.
#
# The grouped jackknife and the quasi-randomization bootstrap re-run the stored
# calibration once per replicate. A replicate whose subsample already meets its
# margins emits surveywts_message_already_calibrated. At 25 replicates that is
# up to 25 identical lines, so this helper muffles each one and counts it.
# .report_replay_messages() prints the count once after the loop.
#
# `expr` is a promise, so assignments inside it write to the caller's frame.
# suppressMessages() behaves the same way.
#
# Arguments:
#   expr    : the replicate body to evaluate
#   counter : environment from .new_replay_counter()
#
# Returns: the value of expr
.muffle_replay_messages <- function(expr, counter) {
  withCallingHandlers(
    expr,
    surveywts_message_already_calibrated = function(m) {
      counter$n <- counter$n + 1L
      invokeRestart("muffleMessage")
    }
  )
}

# ============================================================================
# .report_replay_messages()
# ============================================================================

# Print one line naming how many replicates already met their margins. Print
# nothing when no replicate emitted the message.
#
# Arguments:
#   counter    : environment from .new_replay_counter()
#   replicates : integer(1) — the number of replicates the caller requested
#
# Returns: invisible(NULL); called for the message
.report_replay_messages <- function(counter, replicates) {
  if (counter$n == 0L) {
    return(invisible(NULL))
  }
  cli::cli_inform(
    c(
      "i" = paste0(
        "Raking converged in 1 sweep in {counter$n} of {replicates} ",
        "replicates: those replicates already met their margins."
      )
    ),
    class = "surveywts_message_replay_already_calibrated"
  )
  invisible(NULL)
}
```

- [ ] **Step 5: Add the helpers to the file index**

In `R/replicate-utils.R`, the comment block at lines 7-14 lists every helper.
Append three lines after the `.reestimate_margins_from_reference()` line:

```r
# .new_replay_counter()             — fresh counter for the replay message
# .muffle_replay_messages()         — muffle & count the per-replicate message
# .report_replay_messages()         — print one summary line after the loop
```

- [ ] **Step 6: Run the tests to verify they pass**

```r
devtools::load_all(); testthat::test_file("tests/testthat/test-replay-messages.R")
```

Expected: PASS, 11 tests.

- [ ] **Step 7: Commit**

```bash
git add R/replicate-utils.R tests/testthat/test-replay-messages.R plans/error-messages.md
git commit -m "feat(replicate): add calibration replay message helpers"
```

Commit body:

```
Muffle and count surveywts_message_already_calibrated inside a replicate
loop, and report the count once. Groundwork for #111; no loop uses the
helpers yet.
```

---

## Task 2: wire the three loops

**Files:**
- Modify: `R/create_jackknife_weights.R:651`, `:654`, `:696`, `:700` (the DAGJK loop)
- Modify: `R/replicate-utils.R:436`, `:472`, `:547`, `:593`, `:651`, `:655` (both bootstrap loops)
- Modify: `tests/testthat/helper-test-data.R` (append `make_replay_message_datasets()`)
- Test: `tests/testthat/test-replay-messages.R` (append the integration section)

**Interfaces:**
- Consumes: `.new_replay_counter()`, `.muffle_replay_messages(expr, counter)`,
  `.report_replay_messages(counter, replicates)` from Task 1.
- Produces: `make_replay_message_datasets()` -> `list(ipw_cal, cal_only, quiet, ref)`.

**Why the wrap goes on `tryCatch()`.** `.dagjk_single_replicate()` calls
`surveywts::calibrate_rake()` directly at `R/jackknife-dagjk-utils.R:198`. It
does not go through `.dispatch_calibration_replay()`. There are four replay
sites, and a handler on the dispatch helper misses one. The `tryCatch()` call
is the whole replicate body, so a handler on it covers all four and needs no
re-indentation of the loop.

- [ ] **Step 1: Add the test fixture**

Append to `tests/testthat/helper-test-data.R`:

```r
# Designs that fire the calibration replay message (issue #111).
#
# control = list(improvement = 5) makes every replicate pass the raking
# improvement threshold, so every replicate emits
# surveywts_message_already_calibrated. That saturates the count and keeps the
# assertions clear of borderline chi-square comparisons.
#
# Returns a list:
#   ipw_cal  : ipw() then calibrate_rake(); fires on the IPW replay paths
#   cal_only : calibrate_rake() only; fires on the calibration-only paths
#   quiet    : same data, default threshold; fires on no bootstrap replicate
#   ref      : the reference survey_taylor
make_replay_message_datasets <- function() {
  d <- make_dagjk_datasets()

  targets <- list(
    age_group = c("18-34" = 0.30, "35-54" = 0.40, "55+" = 0.30),
    sex = c("M" = 0.48, "F" = 0.52)
  )

  ipw_fit <- suppressWarnings(surveywts::ipw(
    data = d$A@data[, c("age_group", "sex")],
    reference = d$ref,
    selection = ~ age_group + sex,
    estimating_eq = "mle",
    adjust_reference = FALSE
  ))
  ipw_cal <- suppressMessages(suppressWarnings(surveywts::calibrate_rake(
    ipw_fit,
    targets = targets,
    type = "prop",
    control = list(improvement = 5)
  )))

  # A design sitting exactly on its margins, calibration only.
  age <- rep(c("18-34", "35-54", "55+"), times = c(3L, 4L, 3L) * 100L)
  set.seed(7L)
  sex <- sample(rep(c("M", "F"), times = c(480L, 520L)))
  df <- data.frame(
    age_group = age,
    sex = sex,
    w = rep(1, 1000L),
    stringsAsFactors = FALSE
  )
  svy <- surveycore::as_survey_nonprob(df, weights = w)

  cal_only <- suppressMessages(suppressWarnings(surveywts::calibrate_rake(
    svy,
    targets = targets,
    type = "prop",
    control = list(improvement = 5)
  )))
  quiet <- suppressMessages(suppressWarnings(surveywts::calibrate_rake(
    svy,
    targets = targets,
    type = "prop"
  )))

  list(ipw_cal = ipw_cal, cal_only = cal_only, quiet = quiet, ref = d$ref)
}
```

- [ ] **Step 2: Write the failing integration tests**

Append to `tests/testthat/test-replay-messages.R`:

```r
# ============================================================================
# Integration — the three replicate loops
# ============================================================================

replay <- make_replay_message_datasets()

# Count the per-replicate messages that escape a call. After the fix this is
# always 0; before the fix it was one per replicate.
count_escaped <- function(expr) {
  n <- 0L
  withCallingHandlers(
    force(expr),
    surveywts_message_already_calibrated = function(m) {
      n <<- n + 1L
      invokeRestart("muffleMessage")
    }
  )
  n
}

# Capture the text of the one summary message.
capture_summary <- function(expr) {
  msg <- NULL
  withCallingHandlers(
    force(expr),
    surveywts_message_replay_already_calibrated = function(m) {
      msg <<- conditionMessage(m)
      invokeRestart("muffleMessage")
    }
  )
  msg
}

test_that("DAGJK IPW path emits the summary, not one message per replicate", {
  expect_message(
    suppressWarnings(create_jackknife_weights(
      replay$ipw_cal,
      replicates = 25L,
      type = "grouped",
      seed = 42L
    )),
    class = "surveywts_message_replay_already_calibrated"
  )
})

test_that("DAGJK IPW path lets no per-replicate message escape", {
  n <- count_escaped(suppressWarnings(suppressMessages(
    create_jackknife_weights(
      replay$ipw_cal,
      replicates = 25L,
      type = "grouped",
      seed = 42L
    )
  )))
  expect_identical(n, 0L)
})

test_that("DAGJK calibration-only path lets no per-replicate message escape", {
  n <- count_escaped(suppressWarnings(suppressMessages(
    create_jackknife_weights(
      replay$cal_only,
      replicates = 25L,
      type = "grouped",
      seed = 42L
    )
  )))
  expect_identical(n, 0L)
})

test_that("bootstrap IPW path emits the summary, not one per replicate", {
  expect_message(
    suppressWarnings(create_bootstrap_weights(
      replay$ipw_cal,
      replicates = 25L,
      type = "quasi-randomization",
      seed = 42L,
      reference_sample = replay$ref
    )),
    class = "surveywts_message_replay_already_calibrated"
  )
})

test_that("bootstrap calibration-only path emits the summary", {
  expect_message(
    suppressWarnings(create_bootstrap_weights(
      replay$cal_only,
      replicates = 25L,
      type = "quasi-randomization",
      seed = 42L
    )),
    class = "surveywts_message_replay_already_calibrated"
  )
})

test_that("the summary names the count when every replicate met its margins", {
  msg <- capture_summary(suppressWarnings(create_bootstrap_weights(
    replay$cal_only,
    replicates = 25L,
    type = "quasi-randomization",
    seed = 42L
  )))
  expect_match(msg, "25 of 25 replicates", fixed = TRUE)
})

test_that("no summary fires when no replicate meets its margins", {
  expect_no_message(
    suppressWarnings(create_bootstrap_weights(
      replay$quiet,
      replicates = 25L,
      type = "quasi-randomization",
      seed = 42L
    )),
    class = "surveywts_message_replay_already_calibrated"
  )
})

test_that("a direct calibrate_rake() call still emits the per-replicate message", {
  df <- data.frame(
    g = rep(c("a", "b"), each = 50L),
    w = rep(1, 100L),
    stringsAsFactors = FALSE
  )
  svy <- surveycore::as_survey_nonprob(df, weights = w)
  expect_message(
    suppressWarnings(calibrate_rake(
      svy,
      targets = list(g = c("a" = 0.5, "b" = 0.5)),
      type = "prop"
    )),
    class = "surveywts_message_already_calibrated"
  )
})
```

- [ ] **Step 3: Run the tests to verify they fail**

```r
devtools::load_all(); testthat::test_file("tests/testthat/test-replay-messages.R")
```

Expected: the five loop tests fail. The `expect_message(class = "…replay…")`
tests fail because no summary is emitted. The two `count_escaped()` tests fail
with `25 not identical to 0`.

If the last test — the direct `calibrate_rake()` call — fails, the fixture is
wrong, not the code. Replace its `df` with one that already meets its margins.
`tests/testthat/test-03-rake.R:788` has a working fixture for the same class.

- [ ] **Step 4: Wire the DAGJK loop**

In `R/create_jackknife_weights.R`, insert after line 651 (`repwt_list <- list()`):

```r
  replay_counter <- .new_replay_counter()
```

Change line 654 from:

```r
    rep_ok <- tryCatch(
```

to:

```r
    rep_ok <- .muffle_replay_messages(tryCatch(
```

Change lines 693-696 from:

```r
      error = function(e) {
        FALSE
      }
    )
```

to:

```r
      error = function(e) {
        FALSE
      }
    ), counter = replay_counter)
```

Insert after line 700, the `}` that closes `for (g in seq_len(replicates))`,
and before the `# ---- Post-loop checks` comment:

```r

  .report_replay_messages(replay_counter, replicates)
```

- [ ] **Step 5: Wire both bootstrap loops**

In `R/replicate-utils.R`, insert after line 436 (`B <- replicates`):

```r
  replay_counter <- .new_replay_counter()
```

One counter serves both loops. The IPW path and the calibration-only path are
the two arms of one `if`/`else`, so exactly one of them runs per call.

Both loops carry identical text, so replace every occurrence. Change both
occurrences of:

```r
      draw_ok <- tryCatch(
```

to:

```r
      draw_ok <- .muffle_replay_messages(tryCatch(
```

Change both occurrences of:

```r
        error = function(e) FALSE
      )
```

to:

```r
        error = function(e) FALSE
      ), counter = replay_counter)
```

Insert after line 655, the `}` that closes the `if`/`else`, and before the
`# ---- Post-loop checks` comment:

```r
  .report_replay_messages(replay_counter, B)
```

- [ ] **Step 6: Run the tests to verify they pass**

```r
devtools::load_all(); testthat::test_file("tests/testthat/test-replay-messages.R")
```

Expected: PASS, 19 tests.

- [ ] **Step 7: Run the neighbouring suites**

```r
devtools::load_all()
testthat::test_file("tests/testthat/test-nps-jackknife.R")
testthat::test_file("tests/testthat/test-08-nps-bootstrap.R")
testthat::test_file("tests/testthat/test-03-rake.R")
testthat::test_file("tests/testthat/test-replicate-weights.R")
```

Expected: PASS. `test-03-rake.R:788` asserts the per-replicate message on a
direct call and must still pass untouched.

- [ ] **Step 8: Confirm the reproduction from the issue is quiet**

```r
devtools::load_all()
targets_a <- list(
  sex    = c("Male" = 0.49, "Female" = 0.51),
  age_f3 = c("18-34" = 0.30, "35-54" = 0.33, "55+" = 0.37)
)
ns_svy <- surveycore::as_survey_nonprob(ns_wave1, weights = weight)
ns_cal <- calibrate_rake(ns_svy, targets = targets_a)
create_jackknife_weights(ns_cal, replicates = 25L, type = "grouped", seed = 42L)
```

Expected: at most one `i` line about replicates meeting their margins. Not 22
identical lines. Record the actual line in the commit body.

- [ ] **Step 9: Format and commit**

```bash
air format R/replicate-utils.R R/create_jackknife_weights.R
git add R/replicate-utils.R R/create_jackknife_weights.R tests/testthat/
git commit -m "fix(replicate): collapse the calibration replay message"
```

Commit body:

```
The grouped jackknife and the quasi-randomization bootstrap replay the
stored calibration inside every replicate, and each replay announced its
own convergence. At 25 replicates that was up to 25 identical lines.

Each replicate body now runs under a handler that muffles and counts
surveywts_message_already_calibrated. One line after the loop names the
count.

The handler wraps the tryCatch() that forms the replicate body, not
.dispatch_calibration_replay(). .dagjk_single_replicate() calls
calibrate_rake() directly at R/jackknife-dagjk-utils.R:198, so a handler
on the dispatch helper would miss one of the four replay sites.

Fixes #111
```

---

## Task 3: documentation and gates

**Files:**
- Modify: `R/create_jackknife_weights.R:299-301` (example comment)
- Modify: `R/create_replicate_weights.R:164-166` (example comment)
- Regenerate: `man/create_jackknife_weights.Rd`, `man/create_replicate_weights.Rd`

**Interfaces:**
- Consumes: the behaviour from Task 2. Nothing new is produced.

- [ ] **Step 1: Replace the stopgap comment in `create_jackknife_weights()`**

`R/create_jackknife_weights.R:299-301` currently reads:

```r
#' # This path replays the calibration inside every replicate and announces
#' # each one, so expect a block of convergence messages. Real analyses use
#' # more replicates; 25 keeps `R CMD check` fast.
```

Replace with:

```r
#' # This path replays the calibration inside every replicate. Replicates that
#' # already met their margins are named in one summary line. Real analyses use
#' # more replicates; 25 keeps `R CMD check` fast.
```

- [ ] **Step 2: Replace the same comment in `create_replicate_weights()`**

`R/create_replicate_weights.R:164-166` carries identical text. Apply the
identical replacement.

- [ ] **Step 3: Regenerate the documentation**

```r
devtools::document()
```

Expected: `man/create_jackknife_weights.Rd` and
`man/create_replicate_weights.Rd` change. No other `.Rd` file changes, and
`NAMESPACE` does not change — all three helpers are internal.

- [ ] **Step 4: Run the full test suite**

```r
devtools::test()
```

Expected: 0 failures.

- [ ] **Step 5: Run the check gate**

```r
devtools::check()
```

Expected: 0 errors, 0 warnings, 0 notes. Confirm that `checking examples`
still passes and that the two changed example blocks stay under 5 seconds.

- [ ] **Step 6: Commit**

```bash
git add R/create_jackknife_weights.R R/create_replicate_weights.R man/
git commit -m "docs(replicate): drop the replay message stopgap comments"
```

Commit body:

```
Both examples told the reader to expect a block of convergence messages
and cited #111. The replay now prints one summary line, so the comments
name that instead.
```

- [ ] **Step 7: Hand off to the PR**

Run `/commit-and-pr`. It writes the changelog entry, opens the PR against
`develop`, and monitors CI. The PR body closes #111.

---

## Self-review

**Spec coverage**

| Spec section | Task |
|---|---|
| 2. Decision — muffle, count, one summary line | Task 1 Step 4, Task 2 Steps 4-5 |
| 3. Mechanism — `withCallingHandlers()` on the class | Task 1 Step 4 |
| 4. Placement — three loops, wrap the loop not the dispatch | Task 2 Steps 4-5 |
| 5. Helpers | Task 1 Step 4; index block Step 5 |
| 6. Message class and `plans/error-messages.md` row | Task 1 Step 1 |
| 7. Scope — remove the two stopgap comments, `document()` | Task 3 Steps 1-3 |
| 7. Scope — warnings stay out | Not implemented, by design |
| 8. Tests — all six rows | Task 1 Step 2, Task 2 Step 2 |
| 9. Gates | Task 3 Steps 4-5 |

**Deviations from the spec, resolved here**

1. The spec named two helpers. This plan adds a third,
   `.new_replay_counter()`, so the reset to `0L` lives in one place instead of
   being repeated at each of the two call sites.
2. The spec said each loop gets its own counter. The two bootstrap loops are
   the arms of one `if`/`else`, so one counter per call to
   `.quasi_randomization_bootstrap()` covers both. The reset-per-call
   guarantee the spec wanted still holds.
3. The spec's test row "the count equals `replicates`" needed a fixture that
   saturates. `control = list(improvement = 5)` does, measured at 25 of 25.

Fold all three back into `plans/spec-replay-message-collapse.md` before Task 1.

**Type consistency**

`.new_replay_counter()`, `.muffle_replay_messages(expr, counter)`, and
`.report_replay_messages(counter, replicates)` carry the same names and
argument names in Task 1 and Task 2. The counter is always named
`replay_counter` at the call sites. `.report_replay_messages()` takes
`replicates` in `create_jackknife_weights()` and `B` in
`.quasi_randomization_bootstrap()`; both are the requested replicate count.
