# Examples overhaul (Section A)

**Created:** 2026-09-01
**Parent:** `plans/doc-improvements.md` Section A ("Examples: Show What
Comes Next"), priority highest, the last major open initiative.
**Status:** Drafted 2026-09-01, adversarially reviewed the same day, and
revised against the review. Not started. **Blocked on one code fix** —
see the blocking prerequisite below.
**Scope:** The `@examples` block of all 23 exported functions. No other
roxygen section, no R source outside roxygen comments, no vignette.

Section A's 2026-08-31 narrowing came from spot checks of five families.
This plan opens with the full sweep of all 23 blocks (Task 0, complete —
results below), then fixes them in five PRs.

Implementation runs as Sonnet 5 implementers, one per PR, with a review
between tasks (`superpowers:subagent-driven-development`). The
orchestrator keeps every judgment call in this file; implementers execute
the acceptance criteria and report measurements.

---

## Inputs consumed

| Source | What this plan takes from it |
|---|---|
| `plans/doc-improvements.md` §A | The five-item standard, the workflow-hints table, the two standing decisions |
| `plans/doc-improvements.md` §H "Dataset docs / examples" | The deferred `ipw()` GEE example (closed by D4 below) |
| `vignettes/articles/getting-started.Rmd` | The two canonical workflows and the step-order rule; every downstream step here agrees with it |
| `.claude/standards/function-documentation.md` §`@examples` | Package data only, no `\dontrun`, explicit `library()`, comment style, ~25-line guideline |
| `.claude/standards/engineering-preferences.md` | DRY, explicit over clever, handle edge cases |

## The five-item standard

Restated from `doc-improvements.md:130-142`, unchanged:

1. Assign the result: `result <- fn(...)`.
2. Include at least one downstream step showing what to do with the output.
3. Use `set.seed()` before any random call.
4. For diagnostic functions: include a commented expected value.
5. For functions with notable warnings: show the warning in a comment.

Two standing decisions carry forward unchanged:

- **No-seed exception** (decided 2026-08-28): `adjust_nonresponse()` and
  `redistribute_weights()` keep the no-seed svrep convention. They are
  exempt from item 3.
- **`\dontrun` ban**: no `\dontrun{}` except for genuine external
  resources. No example in this package qualifies. The audit found no
  `\dontrun{}` anywhere in the 23 blocks, so the ban costs nothing to
  hold.

---

## Task 0 — the audit (complete, 2026-09-01)

Six Sonnet 5 subagents, one per family, read every block and every
function body. Every row below was spot-checked against source by the
orchestrator before it entered this table. The reports themselves are
not retained; this table is the record.

### Checklist columns

The audit used a fixed schema so the six reports could be merged without
reconciliation. The columns are: function, items 1-5 with a line
reference for the evidence, the current downstream step if any, and the
example line count. Two columns were added during the sweep because they
turned out to drive plan decisions: the replicate count each example
passes, and the measured example time.

`I1`-`I5` are the five standard items. `-` means the item does not apply.
`ex` is the example line count: every `#'` line from after the
`@examples` tag to the next roxygen tag, including the blank separator
line that ends the block. One rule for all 23 rows.
`s` is the measured elapsed example time (see the runtime baseline below).

| Function | I1 | I2 | I3 | I4 | I5 | Current downstream step | ex | s |
|---|:--:|:--:|:--:|:--:|:--:|---|--:|--:|
| `calibrate()` | ✗ | ✗ | - | - | - | none | 23 | 0.32 |
| `calibrate_rake()` | ✗ | ✗ | - | - | - | none | 20 | 0.18 |
| `calibrate_linear()` | ✗ | ✗ | - | - | - | none | 17 | 0.03 |
| `calibrate_logit()` | ✗ | ✗ | - | - | - | none | 16 | 0.05 |
| `poststratify()` | ✗ | ✗ | - | - | - | none | 17 | 0.04 |
| `calibrate_to_survey()` | ✓ | ✗ | ✗ | - | - | none | 9 | 4.83 |
| `calibrate_to_estimate()` | ✓ | ✗ | ✗ | - | - | none | 32 | 66.86 |
| `create_replicate_weights()` | ✗ | ✗ | ✗ | - | - | none | 20 | 5.25 |
| `create_bootstrap_weights()` | ✗ | ✗ | ✗ | - | - | none | 19 | 41.34 |
| `create_jackknife_weights()` | ✓ | ✗ | ✓ | - | - | none — 3 dead-end assignments | 28 | 3.89 |
| `create_brr_weights()` | ✗ | ✗ | - | - | - | none | 9 | 0.16 |
| `create_gen_boot_weights()` | ✗ | ✗ | ✓ | - | - | none | 6 | 2.09 |
| `create_gen_rep_weights()` | ✗ | ✗ | ✓ | - | - | none | 6 | 0.53 |
| `create_sdr_weights()` | ✗ | ✗ | - | - | - | none | 4 | 1.24 |
| `as_taylor_design()` | ✗ | ✗ | ✗ | - | ✗ | none | 7 | 1.26 |
| `adjust_nonresponse()` | ✓ | ✗ | exempt | - | - | none — dead-end assignment | 10 | 0.05 |
| `redistribute_weights()` | ✗ | ✗ | exempt | - | - | none | 13 | 0.13 |
| `effective_sample_size()` | idiom | ✗ | - | ✗ | - | none | 2 | 0.01 |
| `weight_variability()` | idiom | ✗ | - | ✗ | - | none | 2 | 0.03 |
| `summarize_weights()` | idiom | ✗ | - | ✗ | - | none | 7 | 0.11 |
| `trim_weights()` | ✗ | ✗ | - | - | ✗ | none | 22 | 0.56 |
| `rescale_weights()` | ✓ | ✓ | - | - | - | `summarize_weights()` before and after | 11 | 0.22 |
| `ipw()` | ✓ | partial | ✗ | - | ✗ | `effective_sample_size(result1)`, `weight_variability(result1)`; 6 of 8 results are dead ends | 111 | 1.16 |

**Totals.** Item 1: 6 pass, 14 fail, 3 pass by idiom. Item 2: 1 pass, 1
partial, 21 fail. Item 3: 3 pass, 6 fail, 2 exempt, 12 not applicable.
Item 4: 3 fail, 20 not applicable. Item 5: 3 fail, 20 not applicable.

**Item 1 for the three diagnostics.** `effective_sample_size()`,
`weight_variability()`, and `summarize_weights()` make a bare call. For a
function whose whole output is a printed value, that is the natural
idiom, and item 2's downstream step is the printed value itself once item
4 supplies the expected-output comment. These three are exempt from item
1. Item 4 is the substantive requirement for them.

**Item 5 across the package.** Only three functions emit a warning on a
successful call under the arguments their examples pass. Every other
`cli_warn()` in the package is conditional on an argument the examples do
not use, a data condition the bundled datasets do not create, or a
failure path. The audit checked each one against the function body, so
item 5 touches exactly three files. See D6.

### Defects found outside the five-item standard

The sweep, and the adversarial review that followed it, turned up eight
facts that the five-item standard does not cover. Five are in scope
because the same edit fixes them; three are not.

**In scope for this plan:**

1. `calibrate_to_survey()` demonstrates the crossover trap. Its example
   builds a `survey_nonprob` and then calls
   `create_bootstrap_weights(ns_svy, replicates = 50L)` with no `type =`
   (`R/calibrate_to_survey.R:209`). That is the exact silent SRS-wrap
   path the Getting Started article warns against, so `primary` is a
   `survey_replicate` and the function's `survey_nonprob` branch
   (`R/calibrate_to_survey.R:268-290`) never runs. The header comment
   calls it an "NPS" design. PR 1 fixes it.
2. `ipw()`'s GEE scenario builds inline synthetic data, and its comment
   claims "population-scale reference weights" while `base_weight = 1`
   for all 500 rows (`R/ipw.R:610-630`). Both the data and the claim go.
   See D4.
3. Redundant `data()` calls. `DESCRIPTION:54` sets `LazyData: true`, so
   package data is already attached in examples. Five calls are dead
   code: `R/ipw.R:537`, `:541`, `:562`, `:581`, and
   `R/trim_weights.R:99`. Remove all five. (`R/data.R` carries more, in
   dataset examples — out of scope.)
4. `ipw()`'s example block is 111 lines, 4.4x the ~25-line guideline. D2
   cuts it.

5. Repeated third-party messages. Four examples print messages from
   surveycore, svrep, or survey that the item-5 audit did not cover,
   because they are messages and not warnings. Two of them repeat once
   per replicate:

   | Function | Message | Count |
   |---|---|--:|
   | `create_jackknife_weights()` | "Raking converged in 1 sweep: all variables already met their margins." | 50 |
   | `create_replicate_weights()` | the same | 50 |
   | `create_gen_rep_weights()` | "For `variance_estimator='SD2', assumes rows of data are sorted..." | 1 |
   | `create_sdr_weights()` | "Using Hadamard matrix of order 128..." | 1 |

   Plus `create_gen_boot_weights()`'s SD1 message and
   `calibrate_to_estimate()`'s svrep column-selection message, both
   already recorded elsewhere in this plan.

   The repeated one comes from the DAGJK replay: the grouped jackknife
   re-runs the calibration inside every replicate, and each run announces
   its own convergence. Cutting the count to 25L cuts the block to 22
   lines — measured — which is still the largest single block of output
   either help page produces. **Do not wrap the example in
   `suppressMessages()`**; an example must not hide what the function
   really prints. Accept the block, and file the per-replicate
   announcement as a code issue: a replay should not narrate each
   replicate. That fix belongs with the prerequisite defect above, in the
   same code PR.

**Out of scope — record, do not fix here:**

6. `rescale_weights()` documents replicate behavior
   (`R/rescale_weights.R:37-42`) but shows no `survey_replicate`
   scenario. That is the "one example per input class" rule in
   `.claude/standards/function-documentation.md`, not Section A's
   standard. Add it to the `doc-improvements.md` Section H checklist.
7. `adjust_nonresponse()` demonstrates only `method = "weighting-class"`.
   `"propensity-cell"` and `"propensity"` have no example, which the
   "demonstrate each method" rule requires. Already an open row in the
   Per-Function Issue Reference. Leave it there.
8. `create_jackknife_weights()` passes `replicates = 2L` on its
   grouped-on-Taylor scenario (`R/create_jackknife_weights.R:280`). Two
   replicates is below any recommended minimum. The Per-Function
   reference already carries "verify example `replicates` value meets
   recommended minimum" for this function. Leave it there.

---

## Measured runtime baseline (2026-09-01)

`R CMD check --timings`, examples only, `_R_CHECK_FORCE_SUGGESTS_=false`,
R 4.6.1 on Windows 11. The full log stays out of the repo; Task 1's gate
command reproduces the numbers.

**Totals: 115 to 130 s elapsed across 23 examples.** Two runs on the same
machine, same R, same flags gave user 111.58 / system 16.97 / elapsed
130.34, and user 105.96 / system 7.84 / elapsed 114.82. System time is
the unstable part. Treat the range, not either number, as the baseline —
see Task 1.

Two examples exceed the 5 s threshold that `R CMD check` reports on every
run, and a third straddles it, before this plan adds anything:

```
* checking examples ... OK
Examples with CPU (user + system) or elapsed time > 5s
                          user system elapsed
calibrate_to_estimate    59.83   5.87   66.86
create_bootstrap_weights 35.28   5.67   41.34
create_replicate_weights  3.47   1.78    5.25
```

`create_replicate_weights()` is the straddler: 5.25 s on that run,
4.42 s on the next.

Four examples hold about 90% of the total. The cost of each is attributed
to a single line:

| Function | s | Cause, measured separately |
|---|--:|---|
| `calibrate_to_estimate()` | 66.86 | `survey::as.svrepdesign(type = "JKn")` on `npors_2025_clean` with `ids = ~1` builds one replicate per row — 4,814 columns — and takes 65.0 s of the 66.9 s |
| `create_bootstrap_weights()` | 41.34 | the quasi-randomization bootstrap at `replicates = 200L`; measured 41.47 s standalone |
| `create_replicate_weights()` | 5.25 | the probability bootstrap at its 500 default, plus DAGJK at `replicates = 50L` |
| `calibrate_to_survey()` | 4.83 | two 50-replicate bootstraps plus a 3.54 s calibration call |

### Cost per replicate, measured

| Path | Cost |
|---|---|
| Probability bootstrap, `gss_2024` (3,309 rows) | R=100: 0.08 s. R=500: 1.67 s. Near-free below 500 |
| Quasi-randomization bootstrap, `ns_wave1` (6,422 rows) | Linear at about 0.19 s per replicate. R=10: 1.72 s. R=20: 3.56 s. R=25: 4.63 s. R=200: 41.47 s |
| DAGJK (grouped jackknife), `ns_wave1` | R=10: 0.47 s. R=25: 1.30 s. R=50: 2.70 s |
| Generalized bootstrap, `gss_2024` | R=100: 0.57 s. R=500: 2.11 s |
| JKn jackknife, `gss_2024` | 0.44 s. The count is design-determined; no argument to set |
| BRR, SDR | 0.16 s and 1.24 s. BRR has no count; SDR's 100 default is cheap |

The quasi-randomization bootstrap is the only path where the replicate
count decides whether an example clears 5 s. It replays the whole
weighting pipeline inside every replicate, which is the behavior the
Getting Started article describes and the reason it is expensive.

---

---

## Blocking prerequisite — replicate variance is wrong (found 2026-09-01)

The adversarial review of this plan found a package defect while checking
the downstream step this plan wanted to prescribe. It is not a
documentation problem, it is not this plan's to fix, and it changes what
this plan may prescribe. **File it as a code issue before PR 2 ships.**

**The replicate columns hold resampling multipliers, not finished
replicate weights.** surveycore reads `@variables$repweights` as finished
weights, so every variance estimate from a surveywts-created replicate
design is wrong.

Measured on a 50-replicate bootstrap of `gss_2024` (3,197 rows, seed 1):

| Quantity | Value |
|---|---|
| `rep_1` column | values in {0, 1, 2}, mean 1.02, sd 1.00 — a resampling count |
| `cor(rep_1, base weight)` | -0.04. The columns do not carry the base weight |
| `surveycore::get_means(rep_design, age)` | mean 48.0, CI **42.9 to 53.0** |
| `survey::svymean()` on the Taylor design | mean 47.95, SE 0.4834, CI 47.00 to 48.90 |
| `svrep::as_bootstrap_design()`, 50 replicates | SE 0.4786 — agrees with Taylor |
| Replicate means, columns used as stored | 49.53 to 51.30, mean 50.50, against a full sample of 47.95 |
| Replicate means, columns used as multipliers (`rep * base`) | mean 48.04, sd **0.4835** — matches Taylor |

The offset is systematic and one-directional across every column, so with
`mse = TRUE` it becomes the whole variance. The jackknife is worse: all
134 `type = "jkn"` replicate means sit at 50.4032 — exactly the
**unweighted** mean age — and `get_means()` returns CI 8.62 to 87.3.
`create_gen_rep_weights()` gives 8.60 to 87.28.

Reordering rows recovers nothing, and `@data` comes back in the input
order with the base weight untouched, so this is not a row-alignment bug.
Multiplying each column by the base weight recovers the correct SE to
four digits. One side is missing that multiplication. The bundled
`cps_2023` `repwtp*` columns are finished population-scale weights, which
is evidence the convention is finished weights and surveywts is the side
that is wrong.

**What this costs the plan.** D2 originally prescribed
`surveycore::get_means(result, age)` as the replicate family's downstream
step, on seven help pages. That would publish "mean age 48.0, 95% CI 8.6
to 87.3". D2 now prescribes `summarize_weights(result)` for the whole
family instead — it reports the weight distribution, which is correct
today. Revisit the estimation call after the defect is fixed.

---

## Decisions

### D1. The audit lives in this file

The 23-row table above is the audit record. The six subagent reports are
discarded. Reasons: a table in the plan is what an implementer reads, the
reports carry per-family formatting that does not merge, and keeping both
would leave two records to drift apart.

Each PR's acceptance criteria name the rows that PR closes, so the table
doubles as the progress tracker. An implementer marks a row done by
striking the ✗ in its own PR, not by editing another PR's rows.

### D2. Per-function downstream step

The estimation call depends on the class and on the outcome variable's
type. Four facts settle every case, and all four are run-verified:

- **No estimation call goes on a replicate help page.** The blocking
  prerequisite above explains why: `get_means()` on a surveywts replicate
  design returns a wrong confidence interval, as wide as 8.6 to 87.3.
  The whole replicate family ends at `summarize_weights(result)`.
- `surveycore::get_means()` rejects a factor: "`x` must be numeric, not
  <factor>." It is unusable on this package's factor outcomes anyway.
- `surveycore::get_freqs()` handles factors, and `pid_f3` is the factor
  outcome the Getting Started article uses.
- `surveycore::get_freqs()` on a `survey_nonprob` with no replicate
  weights emits a surveycore warning three times over — "Standard errors
  use an SRS approximation that underestimates calibration uncertainty."

That last fact decides the calibration family. Their examples build a
`survey_nonprob` from `ns_wave1` with no replicates, so an estimation
call would bury the example in three repeated warnings. Those examples
end at `summarize_weights(result)`, which is what the Section A
workflow-hints table already prescribes.

The result: `summarize_weights()` is the downstream step almost
everywhere. That is a narrower outcome than Section A's workflow-hints
table imagined, and it is what the code currently supports. An example
that shows a correct weight distribution teaches more than one that
shows a wrong standard error.

| Function | Downstream step | Verified |
|---|---|---|
| `calibrate()`, `calibrate_rake()`, `calibrate_linear()`, `calibrate_logit()`, `poststratify()` | `summarize_weights(result)` | 0.02 s, silent |
| `calibrate_to_survey()`, `calibrate_to_estimate()` | `summarize_weights(result)` | verified on both fixed shapes |
| `create_bootstrap_weights()`, `create_jackknife_weights()`, `create_brr_weights()`, `create_gen_boot_weights()`, `create_gen_rep_weights()`, `create_sdr_weights()`, `create_replicate_weights()` — both paths | `summarize_weights(result)` | silent on a `survey_replicate`; no estimation call until the prerequisite defect is fixed |
| `as_taylor_design()` | the warning in a comment, then `class(result)[1]` | see D6 |
| `adjust_nonresponse()` | `summarize_weights(result)`, then `nrow()` before and after | 3,290 rows in; the out-count moves every run — see below |
| `redistribute_weights()` | `summarize_weights(result)` | the function always drops the `reduce_if` rows |
| `effective_sample_size()`, `weight_variability()`, `summarize_weights()` | the printed value, with item 4's expected-output comment | see D5 |
| `trim_weights()` | `summarize_weights()` before and after | mirrors `rescale_weights()` |
| `rescale_weights()` | already compliant — do not touch | `R/rescale_weights.R:49-60` |
| `ipw()` | `summarize_weights(result)`, then `calibrate(result, targets)` | full chain 0.30 s, silent |

**Row counts, not just weights, for the nonresponse family.** On a
`survey_taylor`, `adjust_nonresponse()` drops the nonrespondent rows,
because that class's validator requires strictly positive weights
(`R/adjust_nonresponse.R:861-871`). On a `survey_nonprob` it keeps them
at weight zero (`:856-859`). Both examples build a `survey_taylor`, so
`nrow()` before and after shows a real change and is worth a line.

**Do not document the out-count.** The input is 3,290 rows
(`gss_2024[!is.na(gss_2024$sex), ]`), and the example draws
`prob = c(0.2, 0.8)` with no seed, so the output moves every run — three
draws gave 2,602, 2,679, and 2,600. The comment names the mechanism, not
a number. This is a direct consequence of the no-seed exception, and it
is why item 4's expected-output comments are confined to the three
diagnostics.

**`ipw()` at 111 lines.** Cut it to five scenarios in about 40 lines: GSS
reference with both interfaces, CPS `survey_replicate` reference, NPORS
with the three `missing_method` values, GEE (D4), and known population
size. Every scenario assigns and every assignment is used. 40 lines still
exceeds the ~25-line guideline, and that is deliberate: `ipw()` accepts
three reference classes and has four arguments whose behavior only an
example makes concrete. The guideline says "consider whether the longer
cases belong in a vignette"; the answer here is that they belong in
`ipw()`'s own help page, and 40 lines is the cost. Record the reason in
the PR body.

### D3. Runtime budget

**Per-family replicate counts.** Set every count explicitly, including
where the default would do. Explicit beats clever
(`engineering-preferences.md` §5), the number is part of what the example
teaches, and an implicit 500 is what makes
`create_bootstrap_weights()`'s first scenario slower than it looks.

| Path | Count | Measured |
|---|--:|--:|
| Probability bootstrap | `100L` | 0.08 s |
| Quasi-randomization bootstrap, standalone | `20L` | 3.56 s |
| Quasi-randomization bootstrap, inside `calibrate_to_survey()` | `10L` | whole example 3.86 s |
| DAGJK / grouped jackknife | `25L` | 1.30 s |
| Generalized bootstrap | `100L` | 0.57 s |
| SDR | `50L` | under 1 s |
| BRR, JKn | no argument | design-determined |
| `survey::as.svrepdesign()` control design in `calibrate_to_estimate()` | `type = "bootstrap", replicates = 50L` | 0.22 s, replacing 65.0 s |

Every count carries the article's comment convention: a note that real
analyses use more, and that the low count keeps `R CMD check` fast. The
article uses `replicates = 100L` with exactly that comment, so the
examples and the article agree on the practice even where the number
differs.

**The gate.** Two conditions, both measured, both reported in the PR body:

1. No single example exceeds 5 s user + system.
2. Total example time is 45 s elapsed or less, against the 130.34 s
   baseline.

Projected total after the changes: about 30 s. The 45 s ceiling leaves
room for the downstream steps, which cost 0.02 s to 0.30 s each.

The gate is a hard stop. An implementer who cannot meet it lowers a
replicate count further and says so, rather than shipping over the line.

### D4. The `ipw()` GEE example — dataset gap closed, not flagged

The Section H deferral asked for either a bundled dataset with
population-scale reference weights that converges under GEE, or a formal
dataset-gap flag. Run-tested 2026-09-01: the dataset exists.

```r
ns_complete <- ns_wave1[!is.na(ns_wave1$race_f4), ]
ref <- surveycore::as_survey(npors_2025_clean, weights = wt_pop, strata = stratum)
ipw(ns_complete, ref,
    predictors = c("sex", "age_f3", "race_f4", "edu_f3"),
    estimating_eq = "gee")
```

Converges in **0.15 s**. Result class `survey_nonprob`, **6,302 rows**,
weight mean 39,659, and no warning.

**The filter is `race_f4`, not the article's `pid_f3`.** Those are two
different choices and the plan picks one deliberately. The article drops
NA in `pid_f3` because `pid_f3` is the outcome it estimates; `ipw()` then
drops the 120 `race_f4` NA rows itself and warns, which the article's own
comment describes. Here `pid_f3` is not the subject, and D6 wants the GEE
scenario quiet, so the example drops the predictor NAs up front instead.
Measured both ways:

| Filter | Rows in | Rows out | Warnings |
|---|--:|--:|--:|
| `!is.na(race_f4)` — this plan | 6,302 | 6,302 | 0 |
| `!is.na(pid_f3)` — the article's | 6,415 | 6,295 | 1 |

`npors_2025_clean$wt_pop` sums to 249,929,567 — population scale. It is
the same reference design the Getting Started article already builds, so
the example and the article agree.

Three candidates were tested. The failure is as instructive as the pass:

| Candidate | Result |
|---|---|
| `npors_2025_clean` + `wt_pop` | converges, 0.15 s |
| `gss_2024` + `wt_pop` (sums to 260,000,000) | converges, 0.04 s. A second viable choice |
| `npors_2025_clean` + `weight` (sums to 4,827) | the solver diverges: "6295 propensity score(s) saturate at the floating-point boundary." Three warnings first |

The third case is why the original author reached for synthetic data. The
scale of the reference weights, not their provenance, is what GEE needs:
the estimating equation solves `sum(w * x) = sum(d * x)`, so a reference
whose weights sum to less than the sample size has no valid solution.
That is a real constraint and it belongs in the example's comment.

Pick `npors_2025_clean` over `gss_2024`. It is the article's reference
design, and `gss_2024` is already the reference in the first `ipw()`
scenario — reusing it would make the GEE scenario look like a repeat
rather than a contrast.

Close the Section H row when PR 5 merges. Do not flag a dataset gap.

### D5. Expected-output comments for the three diagnostics

**The format.** `#>` prefix, matching the article's knitr `comment`
setting and the convention every R user reads as console output. Put the
comment directly under the call, and paste the real printed output rather
than paraphrasing it.

`effective_sample_size()` and `weight_variability()` return a **named
numeric scalar**, not a tibble — verified by running them. So:

```r
effective_sample_size(ns_wave1_svy)
#>    n_eff
#> 2254.539
```

`summarize_weights()` returns a 1x11 tibble, and 2 rows by 12 columns
with `by = sex`. Paste each tibble as printed. They are wide, so let them
wrap the way the console wraps them. D5's table below gives the ungrouped
values; measure the grouped ones when writing the block.

**The workflow-hints table is wrong on one point.** It says the
diagnostics family should "show `by =` effect on output tibble shape."
Only `summarize_weights()` has a `by` argument.
`effective_sample_size(x, weights)` and `weight_variability(x, weights)`
do not — `effective_sample_size(svy, by = sex)` fails with "unused
argument (by = sex)". Item 4 applies to all three; the `by` half of the
hint applies to `summarize_weights()` alone, where the example already
shows it (`R/summarize_weights.R:44`).

**Keeping the values current.** Add one test file,
`tests/testthat/test-example-values.R`, that recomputes each documented
value from the same package data and asserts it against the number in the
roxygen comment. A dataset update or an algorithm change then fails a
test that names the file and the function, instead of leaving a wrong
number on a help page. Round each assertion to the precision the comment
shows.

The measured values, for the implementer to check against:

| Call | Value |
|---|---|
| `effective_sample_size(ns_wave1_svy)` | `n_eff` = 2254.539 |
| `weight_variability(ns_wave1_svy)` | `cv` = 1.359692 |
| `summarize_weights(ns_wave1_svy)` | n 6422, n_positive 6422, n_zero 0, mean 1.00, cv 1.36, min 0.00382, p25 0.153, p50 0.400, p75 1.13, max 4.78, ess 2255 |

This is the only test file this plan adds. It is not a coverage test; it
guards documentation.

### D6. Which functions show their warning

Three, and only three. Each was verified by reading the `cli_warn()` call
and by running the example.

| Function | Warning | Fires because |
|---|---|---|
| `as_taylor_design()` | `surveywts_warning_taylor_loses_variance` (`R/as_taylor_design.R:135-140`) | unguarded after every early exit — every successful conversion warns |
| `trim_weights()` | `surveywts_warning_no_weights_trimmed` (`R/trim_weights.R:269-274`) | fires when nothing falls outside the bounds, which is true of the IQR-default scenario and the `survey_replicate` scenario on the bundled data |
| `ipw()` | `surveywts_warning_ipw_data_na_omitted` (x2), `surveywts_warning_ipw_reference_na_omitted` (x3), `surveywts_warning_ipw_reference_unadjusted_large_nps` (x1) | `missing_method = "omit"` drops 120 `ns_wave1` rows with NA in `race_f4`; `gss_2024` has NA in `sex` and `age_f3` (112 rows); the third comes from the GEE scenario's `adjust_reference = FALSE`, and goes with that scenario |

**`as_taylor_design()`.** Show the warning text in a comment, then show
`class(result)[1]` changing from `survey_replicate` to `survey_taylor`.

Do **not** demonstrate the warning with a pair of confidence intervals.
An earlier draft of this plan proposed exactly that, on the grounds that
the interval narrows from 42.9-53.0 to 47.0-48.9 after conversion. Both
numbers reproduce, and the reading was backwards: the Taylor interval is
the correct one. `survey::svymean()` on the Taylor design gives SE
0.4832, and a correct svrep 50-replicate bootstrap gives SE 0.4809 — the
same interval. The wide replicate interval is the prerequisite defect
above, not variance capability being discarded. A correctly built
replicate design and its Taylor conversion give nearly the same interval,
so there is no two-number demonstration to make here.

**`trim_weights()`.** Two scenarios warn on the bundled data. Rather than
comment the warning twice, change one scenario so the bounds actually
bite and comment it on the other. The percentile scenario
(`lower = 0.05, upper = 0.95`) already trims — measured, no warning. Keep
the IQR-default scenario as the one that shows the warning, since a user
reaching for the default is exactly who needs to know.

**`ipw()`.** Two routes, and they point opposite ways. D4 chose to
pre-drop the NA rows so the GEE scenario runs silent. For the NPORS
scenario, `missing_method` is the thing being demonstrated, so the
warning is the point: comment it there. Net: the `"omit"` sub-case of the
NPORS scenario carries the warning comment; the other scenarios
pre-filter and stay quiet.

**Everything else is not applicable.** The audit checked every remaining
`cli_warn()` in the package against the arguments its examples pass. Each
is conditional on an argument the example does not use, a data condition
the bundled data does not create, or a failure path. Two cases are worth
naming so nobody re-opens them:

- `adjust_nonresponse()` and `redistribute_weights()` can fire
  `surveywts_warning_class_near_empty`, but whether it fires depends on
  the unseeded `sample()` draw. A comment claiming a warning that appears
  on some runs and not others is worse than no comment. Both stay
  uncommented, which is consistent with the no-seed exception.
- `calibrate_to_estimate()` emits an svrep **message**, not a warning:
  "Selection of replicate columns whose control totals will be perturbed
  will be done at random." Item 5 covers warnings. The message is a
  reproducibility signal, and item 3 handles it — see the note below.

**Item 3's two hidden random calls.** `calibrate_to_survey()` and
`calibrate_to_estimate()` both draw a random replicate-column mapping
when `control_col_matches` / `col_selection` is unset.
`calibrate_to_survey()` does it at `R/calibrate_to_survey.R:553`;
`calibrate_to_estimate()` inherits it from
`svrep::calibrate_to_estimate()`. Neither example seeds. Both need
`set.seed()` before the call, not only before the replicate creation.
This is the audit's least obvious finding and the easiest to miss on
implementation.

### D7. PR strategy — five PRs

One PR would put 23 files and a 100 s runtime change in a single diff.
Six per-family PRs would split the runtime work across four of them, so
no single PR could state a meaningful before-and-after. Five PRs, grouped
by what a reviewer checks rather than by family:

| PR | Branch | Functions | What the reviewer checks |
|---|---|---|---|
| 1 | `docs/examples-runtime` | `calibrate_to_estimate()`, `calibrate_to_survey()`, `create_bootstrap_weights()`, `create_replicate_weights()` | the measured before-and-after, and the crossover-trap fix |
| 2 | `docs/examples-replicate` | `create_jackknife_weights()`, `create_brr_weights()`, `create_gen_boot_weights()`, `create_gen_rep_weights()`, `create_sdr_weights()`, `as_taylor_design()` | that no estimation call slipped in; the `as_taylor_design()` warning comment and class change |
| 3 | `docs/examples-calibration` | `calibrate()`, `calibrate_rake()`, `calibrate_linear()`, `calibrate_logit()`, `poststratify()` | 5 mechanical `summarize_weights()` additions |
| 4 | `docs/examples-nonresponse-utils` | `adjust_nonresponse()`, `redistribute_weights()`, `trim_weights()`, `rescale_weights()` | the no-seed exception is preserved; `rescale_weights()` is untouched |
| 5 | `docs/examples-diagnostics-ipw` | `effective_sample_size()`, `weight_variability()`, `summarize_weights()`, `ipw()` | the expected-output comments, the new test file, the `ipw()` rewrite |

**Order.** PR 1 lands first, alone. It resets the runtime baseline that
PRs 2-5 measure against, and it carries the two changes most likely to
need a second pass. PRs 2-5 touch disjoint files and may then run in
parallel.

**Gates, every PR:**

- `devtools::document()` before the commit. Every change here is roxygen,
  so `man/` moves in every PR.
- `devtools::check()` before the PR. Zero new warnings, zero new notes.
- The example-time measurement from Task 1, in the PR body.

`_R_CHECK_FORCE_SUGGESTS_=false` is required locally: `anesrake`, `mice`,
and `nonprobsvy` are in Suggests and are not installed in this worktree,
and without the variable the check errors before it reaches the examples.

Commit scope is `docs` for all five (`.claude/rules/core.md` §6). Branch
prefix `docs/`. Base `develop`.

---

## Task 1 — the measurement command

Every PR reports example time with the same command, so the numbers
compare. Establish it first; it is the gate for all five PRs.

```r
Sys.setenv("_R_CHECK_FORCE_SUGGESTS_" = "false")
res <- rcmdcheck::rcmdcheck(
  ".",
  args = c("--no-tests", "--no-vignettes", "--no-manual",
           "--no-build-vignettes", "--timings"),
  build_args = c("--no-build-vignettes"),
  error_on = "never",
  check_dir = "<scratchpad>/chk"
)
# Every data row of the timings file ends in a trailing tab, so
# read.delim() sees 5 fields against a 4-name header and shifts the
# first column into row.names. Read it positionally instead.
f <- "<scratchpad>/chk/surveywts.Rcheck/surveywts-Ex.timings"
tm <- read.table(
  f, sep = "\t", header = FALSE, skip = 1, fill = TRUE,
  col.names = c("name", "user", "system", "elapsed", "x")
)[, 1:4]
tm <- tm[order(-tm$elapsed), ]
print(tm, row.names = FALSE)
cat("total elapsed:", sum(tm$elapsed), "\n")
cat("over 5s (user+system):", sum(tm$user + tm$system > 5), "\n")
```

`read.delim()` on that file prints `total elapsed: NA` and a wrong count
for the second line. An implementer who sees `NA` is running the unfixed
command.

**Acceptance criteria**

- [ ] The command runs and produces `surveywts-Ex.timings`.
- [ ] The ranking reproduces: `calibrate_to_estimate()` first at 60 s or
      more, `create_bootstrap_weights()` second at 33 s or more, and
      those two holding more than 80% of the total.
- [ ] The check directory is under the scratchpad, not the repo.

**Do not gate on the absolute total.** Two runs on this machine gave
130.34 s and 114.82 s elapsed, with system time differing by more than
2x. `create_replicate_weights()` straddles the 5 s line — 5.25 s on one
run, 4.42 s on the other — so "three examples over 5 s" is a two-or-three
depending on the run. The ranking and the ratios are stable; the totals
are not. Compare each PR against a baseline measured on the same machine
in the same session, not against a number in this file.

---

## Task 2 — PR 1, the runtime hot spots

Branch `docs/examples-runtime`. Four files.

### 2a. `calibrate_to_estimate()` — `R/calibrate_to_estimate.R:81-112`

- [ ] Replace `survey::as.svrepdesign(type = "JKn")` with
      `survey::as.svrepdesign(type = "bootstrap", replicates = 50L)`.
      Measured: 0.22 s against 65.0 s.
- [ ] Comment why the count is 50, in the article's phrasing.
- [ ] Add `set.seed()` before the `calibrate_to_estimate()` call — the
      random column selection comes from svrep, not from this package
      (D6).
- [ ] Add `summarize_weights(result)`.
- [ ] Keep the example under 5 s. Measured on the fixed shape: 2.22 s.

**Acceptance:** the example runs under 5 s and `summarize_weights()`
prints an 11-column tibble with `n` = 3185. Measured on the fixed shape:
2.04 to 2.22 s. It is **not** silent — svrep prints "Selection of
replicate columns whose control totals will be perturbed will be done at
random" on every call, and `set.seed()` does not suppress it. Only
passing `col_selection` would, and this example does not. Expect the one
message.

### 2b. `calibrate_to_survey()` — `R/calibrate_to_survey.R:206-214`

- [ ] Fix the crossover trap. Calibrate the `survey_nonprob` first, then
      call `create_bootstrap_weights(..., type = "quasi-randomization",
      replicates = 10L, seed = 1L)`. The result stays `survey_nonprob`,
      which is what the header comment already claims. Note the modest
      gain: `R/calibrate_to_survey.R:268-290` is a guard that aborts when
      a `survey_nonprob` primary carries no replicate weights, not a
      separate computation path. The reason to fix this is that the
      example currently teaches the trap, not that it unlocks new code.
- [ ] Control design: `replicates = 20L`.
- [ ] `set.seed()` before the `calibrate_to_survey()` call — the random
      replicate mapping is at `R/calibrate_to_survey.R:553`.
- [ ] Add `summarize_weights(result)`.
- [ ] Comment that the quasi-randomization type is required on a
      non-probability sample, and link the trap to the article.

**Acceptance:** the example runs silent; `class(result)[1]` is
`surveycore::survey_nonprob`; total 3.86 s as measured.

### 2c. `create_bootstrap_weights()` — `R/create_bootstrap_weights.R:114-133`

- [ ] Scenario 1: pass `replicates = 100L, seed = 1L` explicitly instead
      of falling through to the 500 default. Assign; then
      `summarize_weights(result)`. No estimation call — see the blocking
      prerequisite.
- [ ] Scenario 2: `replicates = 200L` becomes `15L`, add `seed = 1L`.
      Assign; then `summarize_weights(result)`. Measured end-to-end at
      `20L`: 4.57 s elapsed, 4.36 s user+system — a 13% margin against a
      hard 5 s stop, on the plan's least stable number (the QR
      per-replicate cost spans 0.172 to 0.207 s). `15L` removes the risk.
- [ ] Remove the redundant `data()` call if one is present.

**Acceptance:** both scenarios assign and use their result; the example
is under 5 s, against 41.34 s.

### 2d. `create_replicate_weights()` — `R/create_replicate_weights.R:133-153`

- [ ] Scenario 1 (bootstrap): `replicates = 100L, seed = 1L`. Assign;
      then `summarize_weights(result)`.
- [ ] Scenario 2 (jackknife, jkn): assign; then
      `summarize_weights(result)`. The count is design-determined — no
      argument.
- [ ] Scenario 3 (DAGJK): `replicates = 50L` becomes `25L`, add
      `seed = 42L`. Assign; then `summarize_weights(result)`. Expect the
      22-line raking-message block (Task 0, in-scope item 5).

**Acceptance:** three scenarios, three assignments, three used; under 5 s
against 5.25 s.

### PR 1 gates

- [ ] `devtools::document()`; `man/` changes committed.
- [ ] `devtools::check()` clean — no new warning, no new note.
- [ ] Task 1's measurement in the PR body: the full timings table, the
      new total, and the count of examples over 5 s, which must be 0.
- [ ] The PR body states that the runtime baseline for PRs 2-5 is now
      this PR's total, not 130.34 s.

---

## Task 3 — PR 2, the replicate family and `as_taylor_design()`

Branch `docs/examples-replicate`. Six files. Every one gets an assignment
and a downstream step; the counts follow D3.

- [ ] `create_jackknife_weights()` — three assignments already exist and
      all three are dead ends. Add `summarize_weights()` to each. DAGJK
      count 50L becomes 25L; expect the raking-message block (Task 0,
      in-scope item 5). Leave `replicates = 2L` on the grouped-on-Taylor scenario
      alone — it is a separate open item (Task 0, out-of-scope item 8).
- [ ] `create_brr_weights()` — assign both scenarios; add
      `summarize_weights(result)` to each. No count to set.
- [ ] `create_gen_boot_weights()` — assign; `replicates = 100L`
      explicitly; add `summarize_weights(result)`. Keep `seed = 42L`.
- [ ] `create_gen_rep_weights()` — assign; add
      `summarize_weights(result)`. Keep `seed = 42L`, and
      comment that the construction is deterministic at the default
      `max_replicates = Inf`, so the seed is defensive. That resolves the
      "deterministic vs. seed" confusion the Per-Function reference
      records for this function.
- [ ] `create_sdr_weights()` — assign; `replicates = 50L` explicitly; add
      `summarize_weights(result)`. Note that `cps_2023` carries no strata
      or PSU columns, which is why this example's design construction
      differs from the rest of the family.
- [ ] `as_taylor_design()` — assign. Add `seed = 1L` to the setup
      bootstrap, which is currently the block's only unseeded random
      call. Show the warning text in a comment. Then show
      `class(result)[1]` moving from `survey_replicate` to
      `survey_taylor`. **No confidence-interval demonstration** — D6
      explains why the earlier proposal was backwards.

**Acceptance criteria**

- [ ] Each of the six examples assigns every result and uses every
      assignment.
- [ ] No `get_means()` or `get_freqs()` call appears in any of the six.
      A reviewer who finds one rejects the PR — see the blocking
      prerequisite.
- [ ] `as_taylor_design()`'s comment reproduces the warning text from
      `R/as_taylor_design.R:135-140`.
- [ ] `devtools::document()`, `devtools::check()` clean, timings in the
      PR body, no example over 5 s.

---

## Task 4 — PR 3, the calibration family

Branch `docs/examples-calibration`. Five files, five mechanical edits.
Each example currently makes 2 to 4 bare calls on a `survey_nonprob`
built from `ns_wave1`.

- [ ] `calibrate()` — four scenarios. Assign the first (Format A + rake)
      and add `summarize_weights(result)`. Leave the other three bare:
      the point of those three is that the same `targets` object routes
      to three methods, and four `summarize_weights()` calls would bury
      it. One assignment, one downstream step, per D2.
- [ ] `calibrate_rake()` — assign the default-algorithm scenario; add
      `summarize_weights(result)`.
- [ ] `calibrate_linear()` — assign the Format A scenario; add
      `summarize_weights(result)`.
- [ ] `calibrate_logit()` — assign the Format A scenario; add
      `summarize_weights(result)`.
- [ ] `poststratify()` — assign the `type = "prop"` scenario; add
      `summarize_weights(result)`.

**On leaving some scenarios bare.** Item 2 asks for "at least one
downstream step," not one per scenario. Where scenarios exist to contrast
argument formats or methods, one assignment with one downstream step
satisfies the standard and reads better. Where a scenario demonstrates a
different input class or a different behavior, it gets its own — that is
why PR 2 adds a downstream step to all three of
`create_jackknife_weights()`'s scenarios.

**Acceptance criteria**

- [ ] Each of the five examples has at least one assignment followed by
      `summarize_weights()`.
- [ ] No estimation call is added to these five. A reviewer who sees
      `get_freqs()` here should reject the PR — see D2.
- [ ] `devtools::document()`, `devtools::check()` clean, timings in the
      PR body. These five total under 1 s; the number is still reported.

---

## Task 5 — PR 4, nonresponse and utilities

Branch `docs/examples-nonresponse-utils`. Four functions, three files
changed — `rescale_weights()` is reviewed and left alone.

- [ ] `adjust_nonresponse()` — the assignment exists and is a dead end.
      Add `summarize_weights(result)` and an `nrow()` comparison. Record
      the row change in a comment: on a `survey_taylor` the nonrespondent
      rows are dropped, because that class requires strictly positive
      weights. **Do not add `set.seed()`** — the no-seed exception holds.
- [ ] `redistribute_weights()` — assign the bare call; add
      `summarize_weights(result)`. **Do not add `set.seed()`.**
- [ ] `trim_weights()` — assign all four scenarios. Add
      `summarize_weights()` before and after, mirroring
      `rescale_weights()`. Show `surveywts_warning_no_weights_trimmed` in
      a comment on the IQR-default scenario. Remove the redundant
      `data(cps_2023)` at `R/trim_weights.R:99`. Watch the length: the
      block is 22 lines and the `survey_replicate` setup is 8 of them.
- [ ] `rescale_weights()` — **no change.** It already meets all five
      items (`R/rescale_weights.R:49-60`) and is the model the other
      utilities copy.

**Acceptance criteria**

- [ ] Neither nonresponse example gains a `set.seed()`. A reviewer who
      finds one rejects the PR.
- [ ] `R/rescale_weights.R` is not in the diff.
- [ ] `trim_weights()`'s warning comment reproduces the text from
      `R/trim_weights.R:269-274`, and its `survey_replicate` scenario
      still runs.
- [ ] `devtools::document()`, `devtools::check()` clean, timings in the
      PR body.

---

## Task 6 — PR 5, diagnostics and `ipw()`

Branch `docs/examples-diagnostics-ipw`. Four files plus one new test file.

### 6a. The three diagnostics

- [ ] `effective_sample_size()` — add the `#>` expected-output comment.
      Keep the bare call.
- [ ] `weight_variability()` — same.
- [ ] `summarize_weights()` — add a `#>` block under each of the two
      scenarios. Keep the `by = sex` scenario; it is the only place in
      the package where `by` appears on a diagnostic.
- [ ] Paste real printed output. Check each against D5's table. If a
      value differs, the data or the code changed since 2026-09-01 —
      report it rather than adjusting the comment silently.

### 6b. The guard test

- [ ] Add `tests/testthat/test-example-values.R`. It rebuilds
      `ns_wave1_svy` the way the examples do, recomputes all three
      values, and asserts them against the documented numbers at the
      documented precision.
- [ ] Cover the `by = sex` call too, not only the ungrouped one. D5's
      measured-values table gives the ungrouped row; the grouped call
      returns 2 rows and 12 columns, and the implementer measures its
      values when pasting the `#>` block. Both blocks get a guard.
- [ ] Each expectation's failure message names the roxygen file and the
      function whose comment is now wrong.

### 6c. `ipw()` — `R/ipw.R:536-647`

- [ ] Cut 111 lines to about 40. Five scenarios, each assigning and each
      using its result.
- [ ] Replace the GEE scenario's inline synthetic data with
      `npors_2025_clean` + `wt_pop` + `strata = stratum`, per D4. Delete
      `nps_gee`, `ref_gee_df`, and `ref_gee`, and the direct
      `surveycore::survey_taylor()` constructor call with them.
- [ ] Delete the comment claiming "population-scale reference weights"
      about a flat `base_weight = 1`. Replace it with the real
      constraint: GEE solves `sum(w * x) = sum(d * x)`, so the reference
      weights must be on a population scale. Name the failure — a
      sample-scale reference makes the solver diverge.
- [ ] Downstream: `summarize_weights(result)`, then
      `calibrate(result, targets)`. Measured chain: 0.30 s, silent.
- [ ] Show `surveywts_warning_ipw_data_na_omitted` in a comment on the
      NPORS `"omit"` sub-case, where `missing_method` is the subject.
      Pre-filter the NA rows in the other scenarios so they stay quiet.
- [ ] Remove `data(ns_wave1)` at `R/ipw.R:537` and `data(gss_2024)` at
      `:541`. `LazyData: true` makes both dead code.
- [ ] Keep the `requireNamespace()` guard on the `mice` sub-case. `mice`
      is in Suggests and is not installed here, so the guard is
      load-bearing.
- [ ] **Seed the `mice` sub-case.** `missing_method = "impute"` reaches
      `mice::mice()` at `R/ipw.R:1122`; surveywts forwards only
      `mice_args`, and mice's own `seed` defaults to `NA`. The block's
      only `set.seed(42L)` sits at `R/ipw.R:614`, *after* that call, so
      the sub-case is unseeded on any machine where `mice` is installed —
      this worktree simply never runs it. Pass
      `mice_args = list(seed = 42L)`, or `set.seed()` before the call.
      This is why the audit table marks `ipw()` item 3 as failing.

**Acceptance criteria**

- [ ] `ipw()`'s block is 45 lines or fewer; the PR body records the count
      and why it exceeds 25.
- [ ] No inline data.frame construction remains anywhere in `R/ipw.R`'s
      examples.
- [ ] The GEE scenario converges and returns a `survey_nonprob`.
- [ ] `tests/testthat/test-example-values.R` passes.
- [ ] `devtools::document()`, `devtools::check()` clean, timings in the
      PR body.

---

## Task 7 — close the parent plan

After PR 5 merges. `plans/` edits go straight to `develop` with a
`docs(plans):` message (`.claude/rules/core.md` §6).

- [ ] `plans/doc-improvements.md` Section A: mark done, name the five PRs
      and their dates.
- [ ] Section H "Dataset docs / examples": close the `ipw()` GEE row.
      Record that the gap was closed with `npors_2025_clean` + `wt_pop`,
      not flagged.
- [ ] Section H: add the `rescale_weights()` missing `survey_replicate`
      scenario as a new quick win (Task 0, out-of-scope item 6).
- [ ] The "Issues at a Glance" table and the suggested sequencing:
      Section A becomes Done.
- [ ] The Per-Function Issue Reference: its staleness note says the
      examples column is the last reliable one. After PR 5 that column is
      stale too. Rewrite the note, or refresh the table.
- [ ] This file: mark implemented, and record the final measured example
      time against the 130.34 s baseline.

---

## Verified claim ledger

Every claim this plan asserts, with how it was checked on 2026-09-01.
"Measured" means a number this session produced. "Read" means a line this
session read. PRs #97-#100 all landed in the last two days, so nothing
here rests on older plan prose.

| # | Claim | Source |
|---|---|---|
| A1 | 23 exported functions | `NAMESPACE`, 23 `export()` lines |
| A2 | Baseline is a range, 115 to 130 s elapsed, 23 examples | Measured twice: 130.34 s and 114.82 s on the same machine. System time varies more than 2x |
| A3 | Two examples exceed 5 s on every run; `create_replicate_weights()` straddles (5.25 s, then 4.42 s) | Measured — `00check.log:65-70` |
| A4 | `calibrate_to_estimate()` costs 66.86 s; 65.0 s of it is `as.svrepdesign(type = "JKn")` building 4,814 replicates | Measured, step by step |
| A5 | A bootstrap control design at 50 replicates takes 0.22 s; the whole fixed example takes 2.22 s and runs silent | Measured end to end |
| A6 | The quasi-randomization bootstrap costs about 0.19 s per replicate on `ns_wave1` | Measured at R = 10, 15, 20, 25, 50, 100, 200 |
| A7 | `create_bootstrap_weights()`'s 41.34 s is its `replicates = 200L` QR scenario | Measured: 41.47 s standalone |
| A8 | `calibrate_to_survey()`'s example hits the crossover trap — `create_bootstrap_weights()` with no `type =` on a `survey_nonprob` | Read `R/calibrate_to_survey.R:209`; the trap is documented in the article and at `R/create_bootstrap_weights.R:75-79` |
| A9 | The fixed `calibrate_to_survey()` shape returns a `survey_nonprob` and runs in 3.86 s at QR R=10 | Measured |
| A10 | `surveycore::get_means()` rejects a factor | Measured: "`x` must be numeric, not <factor>" |
| A11 | `surveycore::get_freqs()` on a `survey_nonprob` with no replicates warns three times about the SRS approximation | Measured on `ns_wave1` |
| A12 | The same call on a `survey_replicate` is silent | Measured on a 50-replicate bootstrap of `gss_2024` |
| A13 | `surveycore::get_means()` on a surveywts replicate design runs and is silent, but returns a wrong interval — the replicate columns are resampling multipliers, not finished weights | Measured; see the blocking prerequisite. Multiplying each column by the base weight recovers SE 0.4835 against Taylor's 0.4834 |
| A14 | `as_taylor_design()` warns on every successful conversion | Read `R/as_taylor_design.R:135-140`, unguarded after the early exits; observed at runtime |
| A15 | Both intervals reproduce (42.9-53.0 replicate, 47.0-48.9 Taylor), but the Taylor one is correct and the gap is the A13 defect, not discarded variance capability | Measured; `survey::svymean()` SE 0.4832, correct svrep bootstrap SE 0.4809 |
| A16 | `trim_weights()` fires `surveywts_warning_no_weights_trimmed` on its IQR-default and `survey_replicate` scenarios | Read `R/trim_weights.R:269-274`; observed at runtime |
| A17 | `effective_sample_size()` and `weight_variability()` return a named scalar and have no `by` argument | Read both signatures; `by = sex` fails with "unused argument" |
| A18 | Diagnostic values: `n_eff` 2254.539, `cv` 1.359692, `summarize_weights()` an 11-column tibble | Measured on `ns_wave1` |
| A19 | `adjust_nonresponse()` drops nonrespondent rows on a `survey_taylor`, keeps them at weight 0 on a `survey_nonprob` | Read `R/adjust_nonresponse.R:855-871`. Input 3,290 rows; output moves every run (2,602 / 2,679 / 2,600 over three unseeded draws) |
| A20 | `ipw()` under GEE converges on `npors_2025_clean` + `wt_pop` in 0.15 s; 6,302 rows, silent, with the `race_f4` NA rows pre-dropped | Measured |
| A21 | `npors_2025_clean$wt_pop` sums to 249,929,567; `gss_2024$wt_pop` to 260,000,000; `npors_2025_clean$weight` to 4,827 | Measured |
| A22 | GEE diverges on a sample-scale reference — "propensity score(s) saturate at the floating-point boundary" | Measured |
| A23 | GEE solves `sum(w * x) = sum(d * x)`, which is why the reference scale matters | Read `R/ipw.R:202-203` |
| A24 | `ipw()`'s GEE scenario builds inline data and its comment about population-scale weights is wrong — `base_weight = 1` | Read `R/ipw.R:610-630` |
| A25 | `ipw()`'s example block is 111 lines | Read `R/ipw.R:537-647`, counted |
| A26 | `ipw()` → `calibrate()` → `summarize_weights()` runs silent in 0.30 s with the `race_f4` NA rows pre-dropped | Measured |
| A27 | `LazyData: true`, so `data()` calls in examples are dead code — five of them in the two files this plan touches | Read `DESCRIPTION:54`; `R/ipw.R:537, 541, 562, 581`, `R/trim_weights.R:99` |
| A28 | `calibrate_to_survey()` draws a random replicate mapping at `R/calibrate_to_survey.R:553` when `control_col_matches` is unset | Read |
| A29 | `calibrate_to_estimate()` inherits the same random draw from svrep, and emits a message about it | Read; observed at runtime |
| A30 | `rescale_weights()` meets all five items | Read `R/rescale_weights.R:49-60` |
| A31 | No `\dontrun{}` anywhere in the 23 blocks | Audited across all six families |
| A32 | `anesrake`, `mice`, `nonprobsvy` are in Suggests and absent here; the check errors before examples without `_R_CHECK_FORCE_SUGGESTS_=false` | Measured — the first check run failed exactly this way |

## Must-not-assert list

This plan, and the examples it produces, must not state:

- That `get_freqs()` or `get_means()` is the right downstream step for
  the calibration family. It is not — see A11.
- That a replicate count is statistically adequate. Every low count in
  these examples exists to keep `R CMD check` fast, and each says so. The
  article's phrasing is the model: "real analyses use more."
- Any claim about how the diagnostics behave with `by`, except for
  `summarize_weights()`, the only one that has the argument.
- That `adjust_nonresponse()` or `redistribute_weights()` warns
  predictably. Whether `surveywts_warning_class_near_empty` fires depends
  on the unseeded draw.
- That `ipw()`'s GEE path requires synthetic data. It does not — A20.
- A dataset gap for the GEE example. There is none.
- Any statement about the `>5s` threshold being a CRAN NOTE. What this
  session measured is that `R CMD check` lists the examples; whether the
  list becomes a NOTE under `--as-cran` was not verified, because the
  `--as-cran` run failed on the missing Suggests packages before reaching
  the examples. State the measured fact, not the CRAN policy.
- That any surveywts replicate design yields a correct standard error, or
  that converting one to Taylor loses precision. Both are wrong until the
  blocking prerequisite is fixed.
- A fixed row count for `adjust_nonresponse()`'s output. The draw is
  unseeded by standing decision, so the number moves.

---

## Adversarial review log (2026-09-01)

A fresh subagent re-verified every audit row and every ledger entry
against source and by running R, not against the audit reports. Verdict:
3 blocking, 7 major, 6 minor. All were confirmed independently by the
orchestrator before the plan was revised. What changed:

**Blocking**

1. The `get_means()` downstream step would have published wrong
   confidence intervals on seven help pages. Root cause traced to a
   package defect — the replicate columns are resampling multipliers, not
   finished weights. D2 now prescribes `summarize_weights()` for the
   whole replicate family, and the defect is a blocking prerequisite.
2. D6's interval-collapse demonstration for `as_taylor_design()` read the
   numbers backwards: the Taylor interval is the correct one. The
   demonstration is removed.
3. Task 1's gate command could not produce either gate number —
   `read.delim()` mis-parses the timings file's trailing tabs. Fixed, with
   the symptom named so an implementer notices the unfixed version.

**Major**

4. `adjust_nonresponse()`'s row counts were wrong (3,290 in, not 3,197)
   and no out-count can be documented under the no-seed exception.
5. Task 2a's "runs silent" contradicted D6's own note about the svrep
   message. Corrected.
6. `ipw()` item 3 was marked passing; the `mice` sub-case is unseeded on
   any machine where `mice` is installed. Cell flipped, totals corrected,
   Task 6c gained a seed step.
7. Five redundant `data()` calls in scope, not three.
8. D4 contradicted itself on which NA filter to use and misattributed the
   choice to the article. One filter picked, both measured, attribution
   dropped.
9. Four examples print repeated third-party messages the item-5 audit did
   not cover; two repeat once per replicate. Recorded as in-scope item 5.
10. The runtime baseline does not reproduce to a fixed number. Restated as
    a range; Task 1 now gates on ranking and ratios.

**Minor** — the `ex` column used two counting rules (one rule now, two
cells corrected); D6's `ipw()` warning list was one class short; Task 2c
had only a 13% margin against a hard gate (count lowered from 20L to
15L); Task 2b overstated what the crossover fix exercises; Task 5 said
four files when three change; the `by = sex` output block had no guard.

Two review findings were checked and left alone: the 45-line `ipw()`
block is permitted, because `function-documentation.md` says "consider"
rather than "must"; and leaving three `calibrate()` scenarios bare
violates no rule, since nothing requires every scenario to assign.

## Handoff — the code issue this plan needs

File before PR 2. Not part of any PR in this plan.

- [ ] Replicate columns hold resampling multipliers where surveycore
      expects finished weights. Every variance estimate from a
      surveywts-created replicate design is wrong. Evidence and the
      four-digit reproduction are in the blocking prerequisite above.
- [ ] The DAGJK replay emits one convergence message per replicate — 22
      identical lines at 25 replicates. A replay should not narrate each
      replicate.

Both belong in the same code PR. This plan's PRs 1 and 3-5 do not depend
on either; PR 2 depends on the first.

## Found while planning, not this plan's scope

- `cps_2023` has 9,999 rows; `R/data.R` says "approximately 10,000."
  Inside its own hedge. Not a defect.
- `calibrate_logit()`'s example defines `targets_a` before the survey
  object, the reverse of the other four calibration files. Cosmetic.
- `redistribute_weights()` and `adjust_nonresponse()` each carry their own
  copy of the near-empty-cell warning logic
  (`R/redistribute_weights.R:344-358`, `R/adjust_nonresponse.R:814-828`).
  A DRY finding for a code PR, not a docs PR.
- `create_gen_boot_weights()` prints an svrep message on every call: "For
  `variance_estimator='SD1', assumes rows of data are sorted in the same
  order used in sampling." It is a message, not a warning, so item 5 does
  not reach it. It may still surprise a reader of the help page.
