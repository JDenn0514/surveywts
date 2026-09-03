# Back-end message classes — implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use
> superpowers:subagent-driven-development (recommended) or
> superpowers:executing-plans to implement this plan task-by-task. Steps use
> checkbox (`- [ ]`) syntax for tracking.

**Goal:** Re-emit every message the replicate weight back end prints under a
`surveywts_message_*` class, rewriting the three known texts in the voice of
this package. Fixes
[#114](https://github.com/JDenn0514/surveywts/issues/114).

**Architecture:** Four internal helpers in `R/replicate-utils.R`. A
`withCallingHandlers()` handler on `message` collects each condition into a
store and calls `invokeRestart("muffleMessage")`. It wraps one line,
`svyrep_obj <- backend_fn(svydesign_obj)`, which is the only place any of the
six creators reaches svrep or survey. After the replicate matrix is built, a
second helper translates each collected message and emits it with
`cli::cli_inform(class = )`. An unrecognised message is re-emitted verbatim
under one generic class, so a wording change upstream degrades the message
rather than silencing it.

**Tech Stack:** R, S7, cli, testthat 3 (edition 3, `>= 3.2.0`), air formatter.

Spec: `plans/spec-backend-message-classes.md`.

## Global Constraints

- Message classes follow `surveywts_message_{snake_case_condition}`.
- `class=` is required on every `cli_abort()`, `cli_warn()`, and
  `cli_inform()` call. No exceptions.
- Internal helpers carry a `.` prefix and are never exported.
- New message classes go into `plans/error-messages.md` first.
- Commits use Conventional Commits. The scope for this work is `replicate`.
- Run `devtools::document()` before committing any file with roxygen2 changes.
- Run `devtools::check()` before opening the PR.
- Work stays on the current branch,
  `JDenn0514/three-replicate-creators-pass-through-unclassed`.

---

## Measured facts

Every number and string below was measured on this branch before the plan was
written. Do not re-derive them; do confirm them when a step says to.

**Which creators emit, and what**

| Call | Messages emitted |
|---|---|
| `create_gen_boot_weights(gss, replicates = 20L, seed = 1L)` | 1 — the SD1 row-order text |
| `create_gen_rep_weights(gss, max_replicates = 20L, seed = 1L)` | 2 — the SD2 row-order text, then the truncation text |
| `create_gen_rep_weights(gss)` | 1 — the SD2 row-order text only |
| `create_sdr_weights(cps, replicates = 100L)` | 1 — the Hadamard text |
| `create_brr_weights(gss)` | 0 |
| `create_jackknife_weights(gss, type = "jkn")` | 0 |
| `create_bootstrap_weights(gss, replicates = 20L, seed = 1L)` | 0 |

`gss` is `gss_2024` with
`weights = wtssps, strata = vstrat, ids = vpsu, nest = TRUE`. `cps` is
`cps_2023` with `weights = wtfinl`.

`create_gen_rep_weights()` emits two messages when `max_replicates`
truncates, in that order. Both must come out classed.

**The exact upstream texts**

All three come from `svrep`, not `survey`. Every one is a plain `message()`,
so the condition class is `simpleMessage/message/condition`.

| Source | Text |
|---|---|
| `svrep:::get_design_quad_form.survey.design` | ``For `variance_estimator='SD1', assumes rows of data are sorted in the same order used in sampling.`` |
| `svrep:::make_sdr_replicate_factors` | ``Using Hadamard matrix of order 128. If `use_normal_hadamard=TRUE`, the smallest possible order is 104.`` |
| `svrep:::as_fays_gen_rep_design.survey.design` | ``The number of replicates needed for fully efficient replication is 68, but `max_replicates` is set to 20. Only a random sample of replicates will be retained.`` |

The row-order `message()` sits behind
`if (variance_estimator %in% c("SD1", "SD2"))`. No other estimator reaches it.

**Which non-SD estimator the fixtures accept**

The negative tests need an estimator that is not `"SD1"` or `"SD2"` and that
runs on `gss_2024` as a stratified multistage design. Measured on that
fixture:

| `variance_estimator` | `create_gen_boot_weights()` | `create_gen_rep_weights()` |
|---|---|---|
| `"Ultimate Cluster"` | 20 columns, 0 messages, 0 warnings | 68 columns, 0 messages, 0 warnings |
| `"Horvitz-Thompson"` | errors: must use a PPS design | errors: must use a PPS design |
| `"Yates-Grundy"` | errors: must use a PPS design | errors: must use a PPS design |
| `"Stratified Multistage SRS"` | errors: must supply a matrix or data frame | same error |
| `"Deville-1"`, `"Deville-2"` | run, but report "not positive semidefinite" | same report |

The "not positive semidefinite" line from the Deville estimators is a
`message()` in `svrep:::get_design_quad_form.survey.design`, not a
`warning()`. Since this branch classes every back-end message, those users
now see it as `surveywts_message_backend_note`, prefixed with "The replicate
weight back end reported:". Either way it is output the negative tests must
not carry.

Use `"Ultimate Cluster"`. It reads no row order, it is the natural estimator
for this design, and it is the only clean option. `surveycore::as_survey()`
has no `pps` argument, so nothing here can build the PPS design the
Horvitz-Thompson family requires, and the Deville estimators break the
pristine-output rule.

**SDR replicate counts on `cps_2023`**

| `replicates` | Columns returned | Order svrep names as reachable at `use_normal_hadamard = TRUE` |
|---|---|---|
| 20 | 32 | 20 |
| 50 | 64 | 56 |
| 100 | 128 | 104 |
| 128 | 128 | 128 |

At `replicates = 128` the counts match and svrep still prints. That is why
the translation returns `NULL` in that case.

**The mechanism, verified in R**

| Check | Result |
|---|---|
| `withCallingHandlers(message = )` plus `invokeRestart("muffleMessage")` catches svrep's `message()` | 2 of 2 muffled |
| The value of `expr` reaches the caller through the helper promise | returns 42 of 42 |
| A condition carrying `surveywts_message_*` is left alone and reaches an outer handler | collected 0, propagated 1 |
| `cli_inform()` accepts a named vector with two `"i"` entries | all three bullets render |
| `{.val {estimator}}` resolves through `.envir` | renders `"SD1"` |
| `list2env(list(), envir = new.env(...))` on an empty data list | no error |
| An upstream text with backticks passed as `{txt}` | renders verbatim, no markup re-parsing |

**The four regexes, run against the live texts**

| Pattern | Matches | Extracts |
|---|---|---|
| `grepl("assumes rows of data are sorted", fixed = TRUE)` | SD1 and SD2 texts | `sub(".*variance_estimator='([^']+)'.*", "\\1", txt)` gives `SD1`, `SD2` |
| `grepl("Using Hadamard matrix of order", fixed = TRUE)` | Hadamard text | nothing; `n_rep` is authoritative |
| `grepl("fully efficient replication", fixed = TRUE)` | truncation text | `sub(".*replication is ([0-9]+).*", "\\1", txt)` gives `68` |
| none of the three | everything else | falls to the generic class |

`svrep::as_sdr_design()` has a fourth message,
``Since `sort_variable = NULL`, assuming rows of data are sorted...``. It
never fires from surveywts, because `create_sdr_weights()` always passes a
sort column. It says "assuming", not "assumes", so pattern A does not catch
it. If it ever fires it lands on the generic class. Verified.

**No handler nesting**

`.muffle_replay_messages()` wraps three replicate loops
(`R/create_jackknife_weights.R:663`, `R/replicate-utils.R:476`,
`R/replicate-utils.R:600`). None of those loops calls
`.convert_and_call()`, so the new handler never sits inside the old one.
Verified by reading the three loop bodies.

---

## File structure

| File | Change | Responsibility |
|---|---|---|
| `plans/error-messages.md` | Modify | Four rows in the `## Messages` table |
| `R/replicate-utils.R` | Modify | The four helpers; the index block; the two lines in `.convert_and_call()` |
| `tests/testthat/test-backend-messages.R` | Create | Unit tests for the helpers, integration tests for the six creators |
| `R/create_gen_boot_weights.R` | Modify | Owns the one shared `@section Messages:` |
| `R/create_gen_rep_weights.R` | Modify | One `@inheritSection` line; the row-order note in `@details`; the Ash (2014) reference |
| `R/create_sdr_weights.R` | Modify | One `@inheritSection` line; one example comment fix |
| `NEWS.md` | Modify | One entry under 0.2.1 |
| `man/create_gen_boot_weights.Rd`, `man/create_gen_rep_weights.Rd`, `man/create_sdr_weights.Rd` | Regenerate | `devtools::document()` output |

---

## Task 1: the four helpers

**Files:**
- Modify: `plans/error-messages.md` (the `## Messages` table at line 209, currently 216 lines)
- Modify: `R/replicate-utils.R` (index block at lines 7-17; append helpers at end of file, currently 1012 lines)
- Test: `tests/testthat/test-backend-messages.R` (create)

**Interfaces:**
- Consumes: nothing from earlier tasks.
- Produces:
  - `.new_backend_message_store()` -> environment with `$msgs` set to `list()`
  - `.collect_backend_messages(expr, store)` -> the value of `expr`
  - `.translate_backend_message(cnd, n_rep, params, seed)` -> `list(bullets = <named character>, class = <character(1)>, data = <named list>)`, or `NULL`
  - `.backend_note(txt)` -> the generic payload, same three-element shape
  - `.report_backend_messages(store, n_rep, params, seed)` -> `invisible(NULL)`
  - Message classes `surveywts_message_row_order_assumed`,
    `surveywts_message_replicates_rounded_up`,
    `surveywts_message_replicates_subsampled`,
    `surveywts_message_backend_note`

- [ ] **Step 1: Register the four message classes**

Append these four rows to the `## Messages` table at the end of
`plans/error-messages.md`:

```markdown
| `surveywts_message_row_order_assumed` | `create_gen_boot_weights()`, `create_gen_rep_weights()` | `variance_estimator` is `"SD1"` or `"SD2"`, which read the row order of the data; replaces an unclassed svrep message |
| `surveywts_message_replicates_rounded_up` | `create_sdr_weights()` | The Hadamard matrix order is above `replicates`, so the result carries more replicate columns than the caller asked for |
| `surveywts_message_replicates_subsampled` | `create_gen_rep_weights()` | `max_replicates` is below the fully efficient replicate count, so the back end keeps a random sample of the replicates |
| `surveywts_message_backend_note` | Any `create_*_weights()` that calls `.convert_and_call()` | The svrep or survey back end emitted a message this package does not recognise; re-emitted verbatim under a class |
```

- [ ] **Step 2: Write the failing tests**

Create `tests/testthat/test-backend-messages.R`:

```r
# test-backend-messages.R
#
# Tests for the back-end message helpers (issue #114).
# svrep prints a plain message() on some successful calls. Those messages
# carry no class, so a caller could only quiet them with a blanket
# suppressMessages(), which also swallowed every surveywts message. These
# tests pin the collect-translate-re-emit behaviour that replaced it.

# The three texts svrep emits, verbatim. The unbalanced quoting in the first
# one is svrep's, not a typo: it opens a backtick and never closes it.
svrep_row_order <- function(estimator = "SD1") {
  paste0(
    "For `variance_estimator='", estimator,
    "', assumes rows of data are sorted in the same order used in sampling."
  )
}
svrep_hadamard <- paste0(
  "Using Hadamard matrix of order 128. ",
  "If `use_normal_hadamard=TRUE`, the smallest possible order is 104."
)
svrep_truncated <- paste0(
  "The number of replicates needed for fully efficient replication is 68, ",
  "but `max_replicates` is set to 20. ",
  "Only a random sample of replicates will be retained."
)

# A plain message() condition, the shape svrep raises. simpleMessage() gives
# exactly simpleMessage/message/condition, which is what was measured.
plain_message <- function(text) {
  simpleMessage(text)
}

# ============================================================================
# .new_backend_message_store()
# ============================================================================

test_that(".new_backend_message_store() starts empty", {
  expect_identical(.new_backend_message_store()$msgs, list())
})

test_that(".new_backend_message_store() returns a fresh store each call", {
  first <- .new_backend_message_store()
  first$msgs <- list(plain_message("x"))
  expect_identical(.new_backend_message_store()$msgs, list())
})

# ============================================================================
# .collect_backend_messages()
# ============================================================================

test_that(".collect_backend_messages() returns the value of expr", {
  store <- .new_backend_message_store()
  expect_identical(
    .collect_backend_messages(
      {
        message("upstream")
        42L
      },
      store
    ),
    42L
  )
})

test_that(".collect_backend_messages() collects and muffles every message", {
  store <- .new_backend_message_store()
  expect_no_message(
    .collect_backend_messages(
      {
        message("one")
        message("two")
        NULL
      },
      store
    )
  )
  expect_length(store$msgs, 2L)
  expect_identical(trimws(conditionMessage(store$msgs[[1]])), "one")
})

test_that(".collect_backend_messages() leaves a surveywts message alone", {
  store <- .new_backend_message_store()
  expect_message(
    .collect_backend_messages(
      cli::cli_inform(
        c("i" = "mine"),
        class = "surveywts_message_already_calibrated"
      ),
      store
    ),
    class = "surveywts_message_already_calibrated"
  )
  expect_identical(store$msgs, list())
})

test_that(".collect_backend_messages() writes assignments to the caller frame", {
  store <- .new_backend_message_store()
  captured <- NULL
  .collect_backend_messages(
    {
      captured <- "written"
      NULL
    },
    store
  )
  expect_identical(captured, "written")
})

# ============================================================================
# .translate_backend_message()
# ============================================================================

test_that(".translate_backend_message() classes the row-order message", {
  out <- .translate_backend_message(
    plain_message(svrep_row_order("SD1")),
    n_rep = 20L,
    params = list(variance_estimator = "SD1", replicates = 20L),
    seed = 1L
  )
  expect_identical(out$class, "surveywts_message_row_order_assumed")
  expect_identical(out$data$estimator, "SD1")
})

test_that(".translate_backend_message() reads the estimator out of the text", {
  out <- .translate_backend_message(
    plain_message(svrep_row_order("SD2")),
    n_rep = 68L,
    params = list(variance_estimator = "SD2"),
    seed = NULL
  )
  expect_identical(out$data$estimator, "SD2")
})

test_that(".translate_backend_message() classes the Hadamard message", {
  out <- .translate_backend_message(
    plain_message(svrep_hadamard),
    n_rep = 128L,
    params = list(replicates = 100L),
    seed = NULL
  )
  expect_identical(out$class, "surveywts_message_replicates_rounded_up")
  expect_identical(out$data$requested, 100L)
  expect_identical(out$data$n_rep, 128L)
})

test_that(".translate_backend_message() drops the Hadamard message when the counts match", {
  expect_null(
    .translate_backend_message(
      plain_message(svrep_hadamard),
      n_rep = 128L,
      params = list(replicates = 128L),
      seed = NULL
    )
  )
})

test_that(".translate_backend_message() classes the truncation message", {
  out <- .translate_backend_message(
    plain_message(svrep_truncated),
    n_rep = 20L,
    params = list(max_replicates = 20L),
    seed = NULL
  )
  expect_identical(out$class, "surveywts_message_replicates_subsampled")
  expect_identical(out$data$natural, 68L)
  expect_identical(out$data$requested, 20L)
})

test_that(".translate_backend_message() names seed only when seed is NULL", {
  with_seed <- .translate_backend_message(
    plain_message(svrep_truncated),
    n_rep = 20L,
    params = list(max_replicates = 20L),
    seed = 1L
  )
  without_seed <- .translate_backend_message(
    plain_message(svrep_truncated),
    n_rep = 20L,
    params = list(max_replicates = 20L),
    seed = NULL
  )
  expect_false(any(grepl("seed", with_seed$bullets, fixed = TRUE)))
  expect_true(any(grepl("seed", without_seed$bullets, fixed = TRUE)))
})

test_that(".translate_backend_message() falls back to the generic class", {
  out <- .translate_backend_message(
    plain_message("Something svrep has not said before."),
    n_rep = 20L,
    params = list(),
    seed = NULL
  )
  expect_identical(out$class, "surveywts_message_backend_note")
  expect_identical(out$data$txt, "Something svrep has not said before.")
})

test_that(".translate_backend_message() falls back when the Hadamard params are absent", {
  out <- .translate_backend_message(
    plain_message(svrep_hadamard),
    n_rep = 128L,
    params = list(),
    seed = NULL
  )
  expect_identical(out$class, "surveywts_message_backend_note")
})

test_that(".translate_backend_message() sends the sort_variable note to the generic class", {
  sort_note <- paste0(
    "Since `sort_variable = NULL`, assuming rows of data are sorted in the ",
    "same order used in sampling."
  )
  out <- .translate_backend_message(
    plain_message(sort_note),
    n_rep = 32L,
    params = list(replicates = 20L),
    seed = NULL
  )
  expect_identical(out$class, "surveywts_message_backend_note")
})

# ============================================================================
# .report_backend_messages()
# ============================================================================

test_that(".report_backend_messages() prints nothing for an empty store", {
  expect_no_message(
    .report_backend_messages(
      .new_backend_message_store(),
      n_rep = 20L,
      params = list(),
      seed = NULL
    )
  )
})

test_that(".report_backend_messages() emits one classed message per collected message", {
  store <- .new_backend_message_store()
  store$msgs <- list(
    plain_message(svrep_row_order("SD2")),
    plain_message(svrep_truncated)
  )
  seen <- character()
  withCallingHandlers(
    .report_backend_messages(
      store,
      n_rep = 20L,
      params = list(max_replicates = 20L),
      seed = NULL
    ),
    message = function(m) {
      seen <<- c(seen, class(m)[[1]])
      invokeRestart("muffleMessage")
    }
  )
  expect_identical(
    seen,
    c(
      "surveywts_message_row_order_assumed",
      "surveywts_message_replicates_subsampled"
    )
  )
})

test_that(".report_backend_messages() re-emits an unrecognised text verbatim", {
  store <- .new_backend_message_store()
  store$msgs <- list(plain_message(svrep_hadamard))
  expect_message(
    .report_backend_messages(
      store,
      n_rep = 128L,
      params = list(),
      seed = NULL
    ),
    "use_normal_hadamard",
    class = "surveywts_message_backend_note"
  )
})

test_that(".report_backend_messages() returns invisible NULL", {
  expect_null(
    suppressMessages(
      .report_backend_messages(
        .new_backend_message_store(),
        n_rep = 20L,
        params = list(),
        seed = NULL
      )
    )
  )
})
```

- [ ] **Step 3: Run the tests to verify they fail**

Run:

```r
devtools::load_all(); testthat::test_file("tests/testthat/test-backend-messages.R")
```

Expected: every test errors with
`could not find function ".new_backend_message_store"` or the equivalent for
the other three helpers.

- [ ] **Step 4: Add the four helpers**

Append to the end of `R/replicate-utils.R`:

```r
# ============================================================================
# .new_backend_message_store()
# ============================================================================

# Create a fresh store for the messages the replicate weight back end emits.
# One store per call to .convert_and_call(), so a second call starts empty.
#
# Returns: an environment with $msgs set to list()
.new_backend_message_store <- function() {
  store <- new.env(parent = emptyenv())
  store$msgs <- list()
  store
}

# ============================================================================
# .collect_backend_messages()
# ============================================================================

# Collect and muffle the messages svrep and survey print on a successful call.
#
# svrep raises them with message(), so they carry simpleMessage/message/
# condition and nothing else. A caller who wanted to quiet one had to use a
# blanket suppressMessages(), which also swallowed every surveywts message
# (issue #114). This helper takes them out of the back end's hands, and
# .report_backend_messages() re-emits each one under a surveywts class.
#
# `expr` is a promise, so it is evaluated inside the handler and assignments
# in it write to the caller's frame. .muffle_replay_messages() behaves the
# same way.
#
# A condition that already carries a surveywts_message_* class is left alone.
# The handler returns without calling invokeRestart(), so the message prints
# where it was raised. No surveywts code emits from inside backend_fn() today;
# the branch keeps a later one from disappearing.
#
# Arguments:
#   expr  : the back-end call to evaluate
#   store : environment from .new_backend_message_store()
#
# Returns: the value of expr
.collect_backend_messages <- function(expr, store) {
  withCallingHandlers(
    expr,
    message = function(m) {
      if (any(grepl("^surveywts_message_", class(m)))) {
        return(invisible(NULL))
      }
      store$msgs <- c(store$msgs, list(m))
      invokeRestart("muffleMessage")
    }
  )
}

# ============================================================================
# .translate_backend_message()
# ============================================================================

# Turn one collected back-end message into a payload for cli::cli_inform().
#
# svrep emits plain message() calls, so there is no class to key on and the
# match is on the message text. A wording change upstream stops the match and
# the message arrives under surveywts_message_backend_note instead: still
# visible, still classed, no longer rewritten. Nothing goes silent.
#
# The returned `data` list holds the values the bullets interpolate.
# .report_backend_messages() binds them into the .envir it passes to
# cli_inform(), because the bullets are built here and emitted there.
#
# Arguments:
#   cnd    : a condition collected by .collect_backend_messages()
#   n_rep  : integer(1) -- replicate columns the back end returned
#   params : the params list .convert_and_call() received
#   seed   : integer(1) or NULL -- the seed .convert_and_call() received
#
# Returns: list(bullets =, class =, data =), or NULL when the message carries
#          nothing the caller needs
.translate_backend_message <- function(cnd, n_rep, params, seed) {
  txt <- trimws(conditionMessage(cnd))

  # svrep:::get_design_quad_form.survey.design, for SD1 and SD2 only.
  if (grepl("assumes rows of data are sorted", txt, fixed = TRUE)) {
    return(list(
      bullets = c(
        "i" = paste0(
          "{.arg variance_estimator} is {.val {estimator}}, which reads the ",
          "row order of the data. It assumes the rows are still in the order ",
          "the sample was drawn in."
        ),
        "v" = paste0(
          "Sort the rows into selection order before you call this function."
        )
      ),
      class = "surveywts_message_row_order_assumed",
      data = list(
        estimator = sub(".*variance_estimator='([^']+)'.*", "\\1", txt)
      )
    ))
  }

  # svrep:::make_sdr_replicate_factors. n_rep is authoritative, so the order
  # is not read out of the text. Nothing is worth saying when the count the
  # caller asked for is the count they got.
  if (grepl("Using Hadamard matrix of order", txt, fixed = TRUE)) {
    requested <- params$replicates
    # Two separate exits, not one. A missing `replicates` is an unrecognised
    # shape and goes to the generic class, per spec section 5. Only a count
    # that matches the request is dropped. Collapsing these into
    # `is.null(requested) || identical(...)` sends missing params to NULL and
    # contradicts the "params absent" test below.
    if (is.null(requested)) {
      return(.backend_note(txt))
    }
    if (identical(as.integer(requested), as.integer(n_rep))) {
      return(NULL)
    }
    return(list(
      bullets = c(
        "i" = paste0(
          "{.arg replicates} is {requested}, and the result has {n_rep} ",
          "replicate columns."
        ),
        "i" = paste0(
          "Successive difference replication builds the columns from a ",
          "Hadamard matrix, and {n_rep} is the smallest order that fits ",
          "{requested} replicates."
        )
      ),
      class = "surveywts_message_replicates_rounded_up",
      data = list(
        requested = as.integer(requested),
        n_rep = as.integer(n_rep)
      )
    ))
  }

  # svrep:::as_fays_gen_rep_design.survey.design. The fully efficient count is
  # not available from the design, so it is read out of the text.
  if (grepl("fully efficient replication", txt, fixed = TRUE)) {
    requested <- params$max_replicates
    if (is.null(requested)) {
      return(.backend_note(txt))
    }
    advice <- if (is.null(seed)) {
      paste0(
        "Set {.arg seed} to make the draw reproducible, or raise ",
        "{.arg max_replicates}."
      )
    } else {
      "Raise {.arg max_replicates} for the fully efficient count."
    }
    return(list(
      bullets = c(
        "i" = paste0(
          "{.arg max_replicates} is {requested}, below the {natural} ",
          "replicates that generalized replication needs to be fully ",
          "efficient."
        ),
        "i" = paste0(
          "The back end keeps a random sample of {requested} of the {natural}."
        ),
        "v" = advice
      ),
      class = "surveywts_message_replicates_subsampled",
      data = list(
        requested = as.integer(requested),
        natural = as.integer(sub(".*replication is ([0-9]+).*", "\\1", txt))
      )
    ))
  }

  .backend_note(txt)
}

# ============================================================================
# .backend_note()
# ============================================================================

# Build the generic payload, for any text .translate_backend_message() does
# not recognise and for a recognised text whose params are missing. The text
# travels in `data` so cli interpolates it as a value: an upstream message
# with braces in it is never re-parsed as markup.
#
# Arguments:
#   txt : character(1) -- the back-end message text, already trimmed
#
# Returns: list(bullets =, class =, data =), the same shape as the three
#          recognised payloads
.backend_note <- function(txt) {
  list(
    bullets = c("i" = "The replicate weight back end reported: {txt}"),
    class = "surveywts_message_backend_note",
    data = list(txt = txt)
  )
}

# ============================================================================
# .report_backend_messages()
# ============================================================================

# Re-emit every collected back-end message under a surveywts class. Emit
# nothing when the store is empty.
#
# The .envir binds the payload's data values, because the bullets are built in
# .translate_backend_message() and interpolated here. Its parent is this
# frame, so cli's own lookups still resolve.
#
# Arguments:
#   store  : environment from .new_backend_message_store()
#   n_rep  : integer(1) -- replicate columns the back end returned
#   params : the params list .convert_and_call() received
#   seed   : integer(1) or NULL -- the seed .convert_and_call() received
#
# Returns: invisible(NULL); called for the messages
.report_backend_messages <- function(store, n_rep, params, seed) {
  for (cnd in store$msgs) {
    payload <- .translate_backend_message(cnd, n_rep, params, seed)
    if (is.null(payload)) {
      next
    }
    cli::cli_inform(
      payload$bullets,
      class = payload$class,
      .envir = list2env(
        payload$data,
        envir = new.env(parent = environment())
      )
    )
  }
  invisible(NULL)
}
```

- [ ] **Step 5: Add the helpers to the index block**

`R/replicate-utils.R` opens with a comment index at lines 7 to 17. Append
these five lines to it, after the `.report_replay_messages()` line:

```r
# .new_backend_message_store()       — fresh store for the back-end messages
# .collect_backend_messages()        — muffle & collect the svrep/survey messages
# .translate_backend_message()       — one message -> a classed cli payload
# .backend_note()                    — the generic payload for an unknown text
# .report_backend_messages()         — re-emit each one under a surveywts class
```

- [ ] **Step 6: Run the tests to verify they pass**

Run:

```r
devtools::load_all(); testthat::test_file("tests/testthat/test-backend-messages.R")
```

Expected: PASS, 0 failures. Nothing is wired into `.convert_and_call()` yet,
so no creator behaviour has changed.

- [ ] **Step 7: Run the full suite to confirm nothing regressed**

Run:

```r
devtools::test()
```

Expected: PASS. The three creators still print svrep's unclassed messages at
this point; that is Task 2.

- [ ] **Step 8: Format and commit**

```bash
air format R/replicate-utils.R tests/testthat/test-backend-messages.R
git add plans/error-messages.md R/replicate-utils.R tests/testthat/test-backend-messages.R
git commit -m "feat(replicate): add the back-end message helpers

Four internal helpers collect the messages svrep prints on a successful
call, translate the three known texts, and re-emit each one under a
surveywts class. Nothing calls them yet.

Refs #114"
```

---

## Task 2: wire the helpers into `.convert_and_call()`

**Files:**
- Modify: `R/replicate-utils.R:154` and `R/replicate-utils.R:171`
- Test: `tests/testthat/test-backend-messages.R` (append)

**Interfaces:**
- Consumes: `.new_backend_message_store()`, `.collect_backend_messages(expr, store)`, `.report_backend_messages(store, n_rep, params, seed)` from Task 1.
- Produces: no new names. Every `create_*_weights()` that calls `.convert_and_call()` now emits classed messages only.

- [ ] **Step 1: Write the failing integration tests**

Append to `tests/testthat/test-backend-messages.R`:

```r
# ============================================================================
# Integration: the six creators that call .convert_and_call()
# ============================================================================

make_gss_taylor <- function() {
  surveycore::as_survey(
    gss_2024,
    weights = wtssps,
    strata = vstrat,
    ids = vpsu,
    nest = TRUE
  )
}

make_cps_taylor <- function() {
  surveycore::as_survey(cps_2023, weights = wtfinl)
}

test_that("create_gen_boot_weights() classes the row-order message", {
  expect_message(
    create_gen_boot_weights(make_gss_taylor(), replicates = 20L, seed = 1L),
    class = "surveywts_message_row_order_assumed"
  )
})

test_that("create_gen_boot_weights() emits nothing unclassed", {
  seen <- character()
  withCallingHandlers(
    create_gen_boot_weights(make_gss_taylor(), replicates = 20L, seed = 1L),
    message = function(m) {
      seen <<- c(seen, class(m)[[1]])
      invokeRestart("muffleMessage")
    }
  )
  expect_true(all(grepl("^surveywts_message_", seen)))
})

test_that("create_gen_boot_weights() names the estimator it was given", {
  expect_message(
    create_gen_boot_weights(make_gss_taylor(), replicates = 20L, seed = 1L),
    "SD1",
    class = "surveywts_message_row_order_assumed"
  )
})

test_that("create_gen_boot_weights() stays quiet for an estimator that ignores row order", {
  expect_no_message(
    create_gen_boot_weights(
      make_gss_taylor(),
      replicates = 20L,
      variance_estimator = "Ultimate Cluster",
      seed = 1L
    )
  )
})

test_that("create_gen_rep_weights() classes the row-order message", {
  expect_message(
    create_gen_rep_weights(make_gss_taylor(), seed = 1L),
    class = "surveywts_message_row_order_assumed"
  )
})

test_that("create_gen_rep_weights() classes both messages when max_replicates truncates", {
  seen <- character()
  withCallingHandlers(
    create_gen_rep_weights(make_gss_taylor(), max_replicates = 20L),
    message = function(m) {
      seen <<- c(seen, class(m)[[1]])
      invokeRestart("muffleMessage")
    }
  )
  expect_identical(
    seen,
    c(
      "surveywts_message_row_order_assumed",
      "surveywts_message_replicates_subsampled"
    )
  )
})

test_that("create_gen_rep_weights() names the fully efficient count", {
  # Read the subsample message on its own, with the row-order one muffled.
  txt <- NULL
  withCallingHandlers(
    create_gen_rep_weights(make_gss_taylor(), max_replicates = 20L),
    surveywts_message_replicates_subsampled = function(m) {
      txt <<- conditionMessage(m)
      invokeRestart("muffleMessage")
    },
    surveywts_message_row_order_assumed = function(m) {
      invokeRestart("muffleMessage")
    }
  )
  expect_match(txt, "68")
  expect_match(txt, "seed")
})

test_that("create_gen_rep_weights() drops the seed advice when seed is given", {
  txt <- NULL
  withCallingHandlers(
    create_gen_rep_weights(make_gss_taylor(), max_replicates = 20L, seed = 1L),
    surveywts_message_replicates_subsampled = function(m) {
      txt <<- conditionMessage(m)
      invokeRestart("muffleMessage")
    },
    surveywts_message_row_order_assumed = function(m) {
      invokeRestart("muffleMessage")
    }
  )
  expect_no_match(txt, "seed")
})

test_that("create_gen_rep_weights() stays quiet at the default max_replicates for a non-SD estimator", {
  expect_no_message(
    create_gen_rep_weights(
      make_gss_taylor(),
      variance_estimator = "Ultimate Cluster",
      seed = 1L
    )
  )
})

test_that("create_sdr_weights() classes the rounding message and names both counts", {
  txt <- NULL
  design <- withCallingHandlers(
    create_sdr_weights(make_cps_taylor(), replicates = 100L),
    surveywts_message_replicates_rounded_up = function(m) {
      txt <<- conditionMessage(m)
      invokeRestart("muffleMessage")
    }
  )
  expect_match(txt, "100")
  expect_match(txt, "128")
  expect_length(design@variables$repweights, 128L)
})

test_that("create_sdr_weights() stays quiet when the count matches the request", {
  expect_no_message(create_sdr_weights(make_cps_taylor(), replicates = 128L))
})

test_that("create_sdr_weights() never mentions an argument it does not forward", {
  txt <- NULL
  withCallingHandlers(
    create_sdr_weights(make_cps_taylor(), replicates = 100L),
    surveywts_message_replicates_rounded_up = function(m) {
      txt <<- conditionMessage(m)
      invokeRestart("muffleMessage")
    }
  )
  expect_no_match(txt, "use_normal_hadamard")
})

test_that("the three silent creators stay silent", {
  gss <- make_gss_taylor()
  expect_no_message(create_brr_weights(gss))
  expect_no_message(create_jackknife_weights(gss, type = "jkn"))
  expect_no_message(
    create_bootstrap_weights(gss, replicates = 20L, seed = 1L)
  )
})

test_that(".convert_and_call() classes a message no pattern matches", {
  # The backend_fn mirrors create_sdr_weights(): it adds a .row_order column
  # so svrep does not emit its own `sort_variable = NULL` note on top of the
  # one this test raises. params carries `replicates = 32L`, the count svrep
  # returns for 20, so the Hadamard message translates to NULL and only the
  # unrecognised text reaches the caller.
  expect_message(
    .convert_and_call(
      data = make_cps_taylor(),
      backend_fn = function(d) {
        message("A back end said something new.")
        d$variables[[".row_order"]] <- seq_len(nrow(d$variables))
        out <- svrep::as_sdr_design(
          d,
          replicates = 20L,
          sort_variable = ".row_order",
          mse = TRUE
        )
        out$variables[[".row_order"]] <- NULL
        out
      },
      method = "successive-difference",
      params = list(replicates = 32L, sort_var = NULL, mse = TRUE)
    ),
    "A back end said something new",
    class = "surveywts_message_backend_note"
  )
})
```

- [ ] **Step 2: Run the tests to verify they fail**

Run:

```r
devtools::load_all(); testthat::test_file("tests/testthat/test-backend-messages.R")
```

Expected: the Task 1 unit tests still PASS. The integration tests FAIL,
because svrep's unclassed message still reaches the caller. Expect failures
of the form `Expected a message with class 'surveywts_message_row_order_assumed'`
and `expect_no_message() failed`.

- [ ] **Step 3: Wrap the back-end call**

In `R/replicate-utils.R`, replace line 154:

```r
  svyrep_obj <- backend_fn(svydesign_obj)
```

with:

```r
  # svrep prints an unclassed message() on some successful calls. Collect them
  # here and re-emit each one under a surveywts class below, once the
  # replicate count is known (issue #114).
  msg_store <- .new_backend_message_store()
  svyrep_obj <- .collect_backend_messages(
    backend_fn(svydesign_obj),
    msg_store
  )
```

- [ ] **Step 4: Report after the replicate count is known**

In `R/replicate-utils.R`, find:

```r
  n_rep <- ncol(rep_matrix)
```

and insert immediately after it:

```r
  .report_backend_messages(msg_store, n_rep, params, seed)
```

The report has to come after `n_rep`, because the rounding message compares
`n_rep` against `params$replicates`.

- [ ] **Step 5: Run the tests to verify they pass**

Run:

```r
devtools::load_all(); testthat::test_file("tests/testthat/test-backend-messages.R")
```

Expected: PASS, 0 failures.

- [ ] **Step 6: Run the full suite**

Run:

```r
devtools::test()
```

Expected: PASS. Watch for tests elsewhere that used `suppressMessages()`
around one of the three creators, or that asserted a message count. If one
fails, the messages moved from unclassed to classed and the assertion needs
the new class name, not a change to the helpers.

- [ ] **Step 7: Format and commit**

```bash
air format R/replicate-utils.R tests/testthat/test-backend-messages.R
git add R/replicate-utils.R tests/testthat/test-backend-messages.R
git commit -m "fix(replicate): class the messages the back end prints

Three creators printed a plain svrep message() on every successful call.
The messages carried no class, so a caller could only quiet them with a
blanket suppressMessages(), which also swallowed every surveywts message.

.convert_and_call() now collects them at the one line where any creator
reaches svrep, and re-emits each under a surveywts class. Two of the three
texts are rewritten: the Hadamard message names replicates, the argument
the caller has, in place of use_normal_hadamard, which
create_sdr_weights() does not forward, and it now fires only when the
replicate count differs from the request. An unrecognised message keeps
its text and gains surveywts_message_backend_note.

Fixes #114"
```

---

## Task 3: the documentation

**Files:**
- Modify: `R/create_gen_boot_weights.R` (roxygen block, lines 9-121)
- Modify: `R/create_gen_rep_weights.R` (roxygen block, lines 9-94)
- Modify: `R/create_sdr_weights.R` (roxygen block, lines 9-74)
- Modify: `NEWS.md` (under `# surveywts 0.2.1 (development)`)
- Regenerate: `man/create_gen_boot_weights.Rd`, `man/create_gen_rep_weights.Rd`, `man/create_sdr_weights.Rd`

**Interfaces:**
- Consumes: the four class names from Task 1.
- Produces: the Rd section `Messages` on topic `create_gen_boot_weights`, which the other two pages inherit by name. Documentation only.

- [ ] **Step 1: Add the one shared Messages section to `create_gen_boot_weights()`**

`create_gen_boot_weights()` owns the section. The other two pages inherit it
in Steps 2 and 3, so the text has to read correctly on all three: it covers
the family, not this one function.

Use the bulleted list below, not a markdown table.
`Roxygen: list(markdown = TRUE)` is set in `DESCRIPTION`, but no roxygen
block in this package uses a table yet and no `.Rd` file carries a
`\tabular`. Bullets need no new machinery.

In `R/create_gen_boot_weights.R`, insert this block after the
`@section Choosing a target:` block and before `@references`:

```r
#' @section Messages:
#' The replicate weight creators re-emit the svrep back end's notices under
#' their own classes, so you can quiet one without quieting the rest. Which
#' message you see depends on the function and the arguments.
#'
#' - `surveywts_message_row_order_assumed` — from
#'   [create_gen_boot_weights()] and [create_gen_rep_weights()], when
#'   `variance_estimator` is `"SD1"` or `"SD2"`. Both estimators read the
#'   row order of the data, and nothing here checks that order.
#' - `surveywts_message_replicates_rounded_up` — from
#'   [create_sdr_weights()], when the Hadamard matrix order is above
#'   `replicates`. The result then carries more replicate columns than you
#'   asked for: `replicates = 100` gives 128.
#' - `surveywts_message_replicates_subsampled` — from
#'   [create_gen_rep_weights()], when `max_replicates` is below the fully
#'   efficient replicate count. The back end keeps a random sample of the
#'   replicates, so set `seed` to make the draw reproducible.
#' - `surveywts_message_backend_note` — from any of them, when the back end
#'   emits a message this package does not recognise. The text is unchanged.
#'
#' To quiet one message and leave the rest alone:
#'
#' ```r
#' withCallingHandlers(
#'   create_sdr_weights(design, replicates = 100L),
#'   surveywts_message_replicates_rounded_up = function(cnd) {
#'     invokeRestart("muffleMessage")
#'   }
#' )
#' ```
```

- [ ] **Step 2: Add the Messages section to `create_gen_rep_weights()`, and the row-order note**

In `R/create_gen_rep_weights.R`, find this sentence in `@details`:

```r
#' matrix into fixed components instead of drawing random multipliers
#' (Fay 1989). There is no `replicates` argument — the construction
#' sets the count, and `max_replicates` caps it. For choosing
#' `variance_estimator`, see the **Choosing a target** section of
#' [create_gen_boot_weights()]; note the defaults differ (`"SD2"`
#' here, `"SD1"` there).
```

and append one sentence to it, so the page states the precondition instead of
pointing at another page for it:

```r
#' matrix into fixed components instead of drawing random multipliers
#' (Fay 1989). There is no `replicates` argument — the construction
#' sets the count, and `max_replicates` caps it. For choosing
#' `variance_estimator`, see the **Choosing a target** section of
#' [create_gen_boot_weights()]; note the defaults differ (`"SD2"`
#' here, `"SD1"` there).
#'
#' **Row order.** The default `"SD2"` reads the row order of the data.
#' It assumes the rows are still in the order the sample was drawn in
#' (Ash 2014). Re-sorted rows give a different and incorrect answer, and
#' no error is raised. Sort the rows into selection order before you
#' call this function. `"SD1"` reads the row order in the same way; no
#' other `variance_estimator` does.
```

Then insert this one line after `@section Algorithm:` and before
`@references`, to pull in the shared section from Step 1:

```r
#' @inheritSection create_gen_boot_weights Messages
```

`Ash (2014)` is already in the `@references` of
`create_gen_boot_weights()` and `create_sdr_weights()`. Add it to
`create_gen_rep_weights()` too, so the new citation resolves on this page:

```r
#'   Ash, S. (2014). Using successive difference replication for
#'   estimating variances. *Survey Methodology, Statistics Canada*,
#'   40(1), 47--59.
```

- [ ] **Step 3: Inherit the Messages section on `create_sdr_weights()`**

In `R/create_sdr_weights.R`, insert this one line after
`@section Algorithm:` and before `@references`:

```r
#' @inheritSection create_gen_boot_weights Messages
```

- [ ] **Step 4: Fix the wrong count in the `create_sdr_weights()` example**

The example says the interval comes from 50 replicate columns.
`replicates = 50L` on `cps_2023` returns 64. Measured. Replace:

```r
#' sdr_design <- create_sdr_weights(cps_design, replicates = 50L)
#' summarize_weights(sdr_design)
#' # The confidence interval below is computed from the 50 replicate
#' # columns rather than by Taylor linearization.
#' surveycore::get_means(sdr_design, age)
```

with:

```r
#' # `replicates = 50L` returns 64 columns: the Hadamard matrix order sets
#' # the count, and 64 is the smallest order that fits 50.
#' sdr_design <- create_sdr_weights(cps_design, replicates = 50L)
#' summarize_weights(sdr_design)
#' # The confidence interval below is computed from the 64 replicate
#' # columns rather than by Taylor linearization.
#' surveycore::get_means(sdr_design, age)
```

- [ ] **Step 5: Add the NEWS entry**

Under `# surveywts 0.2.1 (development)`, in the `## Bug fixes` section of
`NEWS.md`, add:

```markdown
* `create_gen_boot_weights()`, `create_gen_rep_weights()`, and
  `create_sdr_weights()` printed an unclassed `svrep` message on every
  successful call (#114). The messages were plain `message()` calls, so the
  only way to quiet one was a blanket `suppressMessages()`, which also
  swallowed every surveywts message.

  All three now carry a class: `surveywts_message_row_order_assumed`,
  `surveywts_message_replicates_rounded_up`, and
  `surveywts_message_replicates_subsampled`. A message from the back end
  that surveywts does not recognise keeps its text and arrives as
  `surveywts_message_backend_note`.

  Two of the texts changed. The `create_sdr_weights()` message named
  `use_normal_hadamard`, which that function does not forward to
  `svrep::as_sdr_design()`; it now names `replicates` and the real column
  count, and it fires only when the two differ. `create_gen_rep_weights()`
  now points at `seed` when it keeps a random sample of the replicates and
  no seed was given.
```

- [ ] **Step 6: Rebuild the documentation**

Run:

```r
devtools::document()
```

Expected: `man/create_gen_boot_weights.Rd`,
`man/create_gen_rep_weights.Rd`, and `man/create_sdr_weights.Rd` change. No
`NAMESPACE` change — none of the new helpers is exported.

Then confirm the inherited section actually landed on all three pages.
`@inheritSection` fails silently if the section name does not match, so check
rather than assume:

```bash
grep -c "surveywts_message_replicates_rounded_up"   man/create_gen_boot_weights.Rd man/create_gen_rep_weights.Rd   man/create_sdr_weights.Rd
```

Expected: a non-zero count for each of the three files. A zero means the
`@inheritSection create_gen_boot_weights Messages` line did not resolve.

- [ ] **Step 7: Check that the examples run and print what the pages claim**

Run:

```r
devtools::run_examples(c(
  "create_gen_boot_weights",
  "create_gen_rep_weights",
  "create_sdr_weights"
))
```

Expected: all three run. Each prints its classed message. Confirm the
`create_sdr_weights()` example reports 64 columns, not 50.

- [ ] **Step 8: Run the full gates**

Run:

```r
devtools::test()
devtools::check()
```

Expected: `devtools::test()` PASS. `devtools::check()` reports 0 errors,
0 warnings, 0 notes.

- [ ] **Step 9: Commit**

```bash
air format R/create_gen_boot_weights.R R/create_gen_rep_weights.R R/create_sdr_weights.R
git add R/create_gen_boot_weights.R R/create_gen_rep_weights.R R/create_sdr_weights.R man NEWS.md
git commit -m "docs(replicate): document the back-end messages

create_gen_boot_weights() carries one Messages section naming all four
classes and showing how to quiet one without quieting the rest.
create_gen_rep_weights() and create_sdr_weights() inherit it by name.

create_gen_rep_weights() states the SD1/SD2 row-order precondition itself
in place of pointing at create_gen_boot_weights() for it, and gains the
Ash (2014) reference the new text cites.

Also fixes a wrong count in the create_sdr_weights() example. It said the
interval came from 50 replicate columns; replicates = 50L returns 64 on
cps_2023.

Refs #114"
```

---

## Self-review against the spec

| Spec section | Task |
|---|---|
| §2 decision: re-emit classed, rewrite the known three, generic fallback | 1, 2 |
| §3 mechanism: `withCallingHandlers` at `R/replicate-utils.R:154`, collect then emit | 2 steps 3-4 |
| §4 placement after `n_rep`; the four helpers | 1 step 4, 2 step 4 |
| §5 `surveywts_message_row_order_assumed` | 1 step 4, tested 1 step 2 and 2 step 1 |
| §5 `surveywts_message_replicates_rounded_up`, fires only when the counts differ | 1 step 4, tested 1 step 2 and 2 step 1 |
| §5 `surveywts_message_replicates_subsampled`, seed bullet conditional | 1 step 4, tested 1 step 2 and 2 step 1 |
| §5 `surveywts_message_backend_note` | 1 step 4, tested 1 step 2 and 2 step 1 |
| §5 the `sort_variable = NULL` note lands on the generic class | tested 1 step 2 |
| §6 one shared `@section Messages:` on `create_gen_boot_weights()`, inherited by the other two | 3 steps 1-3, verified 3 step 6 |
| §6 row-order note on the `create_gen_rep_weights()` page | 3 step 2 |
| §6 the 50-versus-64 example fix | 3 step 4 |
| §6 the NEWS entry | 3 step 5 |
| §7 four rows in `plans/error-messages.md` | 1 step 1 |
| §8 every test row | 1 step 2, 2 step 1 |
| §9 `document()`, `test()`, `check()` | 3 steps 6, 8 |

Out of scope and not in any task, as §7 says: #119
(`use_normal_hadamard`), #120 (`rlang::check_dots_empty()`), and warnings.
