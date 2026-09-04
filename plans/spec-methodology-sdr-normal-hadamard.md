# Methodology Review: sdr-normal-hadamard — Pass 1 (2026-09-03)

Three reviewers: lenses 1–3, lenses 4–6, and the orchestrator. Every numeric
claim below was measured against svrep 0.9.1. Per-reviewer detail is in
`.surveywts-workspace/runs/2026-09-03-sdr-normal-hadamard/lens-1-3.md`,
`lens-4-6.md` and `lens-orchestrator.md`.

Issues 4 and 5 were rewritten on 2026-09-03 by corrections pass 2. Pass 1
measured both on a design with singleton PSUs, and the PSU count is the
variable that drives SDR. The corrections and their evidence are in
`.surveywts-workspace/runs/2026-09-03-sdr-normal-hadamard/corrections-pass-2.md`.
Issues 1, 2, 3, 6, 7 and 8 stand as Pass 1 recorded them.

## New Issues

### Lens 1 — Method Validity

**Issue 1: the single-row edge case is unreachable**
Severity: REQUIRED · Resolution type: UNAMBIGUOUS

The edge-case table says a single-row design gives every replicate factor
equal to 1 and a variance estimate of 0, with no error. Measured,
`surveycore::as_survey()` rejects the input first:

```
Error: `data` has only 1 row. A survey design requires at least 2 observations.
```

A tester cannot construct this input. `comprehension.md` carries the same
wrong claim in its Gotchas section.

**Fix.** Rewrite the row to match the 0-row row: unreachable, rejected by
`surveycore::as_survey()`. Correct the gotcha in `comprehension.md`.

### Lens 2 — Variance Estimation Validity

**Issue 2: the variance-neutrality claim is false at `mse = FALSE`**
Severity: BLOCKING · Resolution type: UNAMBIGUOUS

The spec states, unqualified, that the new argument "changes the column count
and nothing else about the method" and that "the variance at a shared order is
the same on both paths". That holds only at `mse = TRUE`. `mse` is a public
argument. Measured, 500-row design, `svytotal(~y)` variance, `mse = FALSE`:

| Order | `use_normal_hadamard = FALSE` | `TRUE` | Difference |
|---|---|---|---|
| 64 | 11924.444027 | 13184.223986 | 11% |
| 128 | 14301.662601 | 11493.099572 | 20% |

The inactive replicate is the cause: at `mse = FALSE` deviations are centred
on the mean of the replicate estimates, and a replicate equal to the full
sample pulls that mean.

The spec's edge-case table separately routes this combination to "Out of
scope. Not specified here." One document cannot both claim neutrality and
decline to specify the case that breaks it. The blanket claim is the one a
builder reads.

**Fix.** Qualify every statement of variance-neutrality with "at `mse = TRUE`,
the default" — the Arguments section, the Measured facts section, the
Algorithm section and the `NEWS.md` entry all carry it. Replace the edge-case
row: state that the paths give different variance estimates at a shared order
when `mse = FALSE`, name the inactive replicate as the cause, and state
whether the function warns or documents only.

**Issue 3: the two paths give different degrees of freedom at the same order**
Severity: REQUIRED · Resolution type: UNAMBIGUOUS

Raised as an open question by the Lens 1–3 reviewer; measured here. At a
shared order and identical variance, `survey::degf()` differs:

| Order | `FALSE` | `TRUE` |
|---|---|---|
| 64 | 62 | 63 |
| 128 | 126 | 127 |

The confidence interval therefore differs even where the variance does not.
Measured, `svymean(~y)` at order 64: `[11.914415, 12.101576]` against
`[11.914444, 12.101546]`, a width difference of 0.03%.

So "changes the column count and nothing else" is false in a second way, and
a quality gate asserting equal confidence intervals at a shared order would
fail. A gate asserting equal variance for a total passes; see Issue 4 for why
a mean does not.

**Fix.** State the degrees-of-freedom difference in the Returns contract.
Scope the quality gate to variance, not to confidence intervals.

**Issue 4: variance-neutrality holds for a total, not for a mean**
Severity: REQUIRED · Resolution type: UNAMBIGUOUS · **Resolved by correction C2**

The Lens 1–3 reviewer noted correctly that every neutrality measurement used
`svytotal()`, while quality gate 6 asserts the property for a mean, which is
nonlinear. Pass 1 answered that by measuring a mean on a 480-row design with
singleton PSUs and constant base weights, found equality, and marked the issue
closed. That closure was wrong. The design does not exercise the difference,
because with one PSU per row there are no inactive replicates on either path.

Re-measured at `mse = TRUE` on the package's own test design,
`make_taylor_design(n = 500L, n_strata = 4L, psus_per_stratum = 5L, seed = 42L)`
— 500 rows in 20 PSUs:

| Order | var(total), both paths | var(mean), `FALSE` | var(mean), `TRUE` |
|---|---|---|---|
| 20 | 742.9939387275 | 0.002537678051 | 0.002537864713 |
| 32 | 742.9939387275 | 0.002537678051 | 0.002549751870 |
| 64 | 742.9939387275 | 0.002537678051 | 0.002549751870 |
| 128 | 742.9939387275 | 0.002537678051 | 0.002549751870 |

The total is identical to every digit. The mean differs by 0.48%.

A total is linear in the weights, so the Hadamard orthogonality identity
applies exactly and the inactive replicates contribute zero. A mean is a ratio
whose denominator is the replicate weight sum, and that sum varies by
replicate, so the inactive replicates enter it. The two paths carry different
numbers of inactive replicates, so their mean variances differ. The reviewer's
original concern was correct.

**Fix.** Scope quality gate 6 to a total, and state the mechanism in one
sentence beside it. A gate written on a mean fails on the package's own test
design. Every statement of variance-neutrality in the spec, the roxygen and
`NEWS.md` names a linear statistic.

### Lens 3 — Algorithmic Correctness

No issues found. The order search is delegated to svrep and survey. The spec
does not fabricate a closed form and does not describe the search as
iterative.

### Lens 4 — Statistical Assumptions

**Issue 5: the spec sells a column-count saving and does not state its cost**
Severity: BLOCKING · Resolution type: UNAMBIGUOUS

The issue and the spec both frame `use_normal_hadamard = TRUE` as an
efficiency win: 56 columns in place of 64, about 12% fewer passes over the
data. Every measurement behind that framing came from designs with no strata
and no PSU column. The Lens 1–3 reviewer flagged that gap.

Pass 1 read a 28% standard-error gap on a stratified design and attributed it
to stratification. That attribution is wrong. The design behind the 28% had
four strata and singleton PSUs, so it had 480 PSUs. The PSU count relative to
the Hadamard order is the operative variable, not stratification.

Measured with four strata held fixed throughout, `replicates = 50`,
`mse = TRUE`, `svytotal(~y)`, the row count held at 480 while
`psus_per_stratum` varies. The `FALSE` path takes order 64 and the `TRUE` path
order 56:

| PSUs | SE, order 64 | SE, order 56 | Ratio |
|---|---|---|---|
| 20 | 29.250458 | 29.250458 | 1.0000 |
| 40 | 27.108206 | 27.108206 | 1.0000 |
| 80 | 25.978664 | 25.433342 | 0.9790 |
| 160 | 24.381831 | 23.093513 | 0.9472 |
| 240 | 24.539916 | 23.794741 | 0.9696 |
| 480 | 26.646328 | 22.709446 | 0.8523 |

Neither number is wrong — both are valid SDR estimates at different Hadamard
orders — and it is not noise: SDR is deterministic.

**Fix.** Add the PSU sweep to the Measured facts section. Rewrite the `@param`
text and the Algorithm sub-section around an actionable rule, in place of the
stratification framing: while the PSU count does not exceed the smaller order,
both paths give the same answer and the saving is free; above that the two
diverge, and the gap grows with the PSU count — about 2% at 80 PSUs, 5% at 160
and 15% at 480. The check a caller makes is their PSU count against the order
they would land on. State that the default `FALSE` is the reproducible choice
for existing work.

Two cautions for whoever writes the text. The growth is not monotone across the
sweep: 240 PSUs sits at 3%, below the 5% at 160. State the three cited figures
and no monotone rule. And do not present the smaller column count as a free
saving in general — it is free only at or below the smaller order.

**Issue 6: the "approximate SD2" finding never reaches the user**
Severity: REQUIRED · Resolution type: UNAMBIGUOUS

The spec's own Measured facts record that SDR is approximate, not exact, SD2
once the unit count exceeds the Hadamard order — the ordinary case, including
the bundled `cps_2023` example. The spec uses this only as private
justification for the default. No user-facing documentation carries it.

**Fix.** State the qualification in `@section Algorithm`, in one sentence.

### Lens 5 — Formula Integrity

**Issue 7: the published SDR variance formula is wrong by a factor of 8**
Severity: BLOCKING · Resolution type: UNAMBIGUOUS

`R/create_sdr_weights.R:41` publishes:

```
\deqn{\hat{V}_{SDR} = \frac{1}{2R} \sum_{r=1}^{R}
  (\hat{\theta}^{(r)} - \hat{\theta}_{\text{full}})^2.}
```

The scale factor is `4/R`. Measured, 300-row design, `svytotal(~y)`, R = 64:

| Quantity | Value |
|---|---|
| Variance `survey` reports | 1374.900221 |
| `design$scale` | 0.0625 = 4/64 |
| `(4/R) x SS` | 1374.900221 |
| `(1/(2R)) x SS`, as published | 171.862528 |

The published formula understates the variance by exactly 8. A reader who
implements it, or who checks surveywts against it, gets a standard error too
small by a factor of about 2.83.

Pre-existing, not introduced here. It lands in this spec because the spec
edits that same `@section Algorithm` block while asserting `4/R` elsewhere.
Applying the spec as written ships one function documenting two contradictory
scale factors for the same estimator.

**Fix.** Correct the `\deqn` to `\frac{4}{R}`. Give it a quality-gate row and
its own `NEWS.md` line under a bug-fix heading.

### Lens 6 — Literature Cross-Check

**Issue 8: the Ash / Fay & Train equivalence claim is stated unqualified**
Severity: REQUIRED · Resolution type: UNAMBIGUOUS

The existing `@details` says the estimator "matches the variance of a
systematic random sample when PSUs are in selection order (Ash, 2014; Fay &
Train, 1995)". Measurement contradicts the word "matches" in the ordinary
case. Against an SD2 target, ratios run 0.855 at order 20 to 1.344 at order
32, and the departure is not monotone in the order.

The spec's `@references` note — "Unchanged, adds no method" — sidesteps this
rather than addressing it.

**Fix.** Change "matches" to a qualified verb, and tie the qualification to
Issue 6's sentence. Do not cite an equation or page number of Ash (2014):
nobody in this pipeline read it, and `comprehension.md` marks it `[NOT FOUND]`.

Citation specificity is otherwise clean. No fabricated equation or page
citations. All `comprehension.md` gotchas are covered or explicitly scoped
out, except the single-row gotcha in Issue 1.

---

## Summary (Pass 1)

| Severity | Count |
|---|---|
| BLOCKING | 3 |
| REQUIRED | 5 |
| SUGGESTION | 0 |

**Total issues:** 8. All eight need a change to the spec. Issue 4 was recorded
in Pass 1 as closed by measurement; correction C2 reopened it, because the
measurement used a design that does not exercise the difference.

**Verdict: BLOCK.**

**Overall assessment.** The spec implements both binding decisions correctly,
and its architecture, argument placement, error class and message wording are
sound. It fails on what it tells the caller. It publishes a variance formula
that is wrong by a factor of 8, it claims a neutrality that holds only at the
default `mse` and only for a linear statistic, and it presents the new argument
as a free 12% saving when the saving is free only while the PSU count stays at
or below the smaller Hadamard order. All three are fixable in the documentation
and the contract, with no change to the design.
