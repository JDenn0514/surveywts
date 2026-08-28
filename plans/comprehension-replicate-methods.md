# Comprehension — replicate methods

**Status:** complete. **Written:** 2026-08-28.
**Approved in:** `plans/doc-improvements.md` Section H, `[decided 2026-08-28]`.

## Purpose

This doc has two consumers.

1. The `@details` block for `create_replicate_weights()`. That function is a
   Tier 4 dispatcher. `.claude/standards/function-documentation.md` requires
   `@details` and `@references` for Tier 4, and it makes the inline citations
   load-bearing: "if citations cannot be verified (no `comprehension.md` exists
   for the relevant spec), the `@details` method overview and `@references`
   block must both wait until verification is possible." This doc is that
   verification.
2. Section C of `plans/doc-improvements.md` — the replicate-family
   method-choice table, written for an R-fluent analyst who is not a survey
   methodologist.

Sources come from `.claude/reference-map.yaml`. That file maps 14 citations to
`create_replicate_weights()` and its siblings. 13 are in the knowledge base.
Wolter (2007) is not. See "Unverified sources".

**Read "Citation verification" before you copy any citation into
`@references`.** Two of the 14 citations were wrong enough to mislead a reader,
and one named co-authors who did not write the paper.

**Applied 2026-08-28.** The corrections below are now in
`.claude/reference-map.yaml`, so that file is the corrected source. This
section stays as the record of what was checked, and of what remains
unconfirmed — Fay (1989)'s page range and the Chrostowski year and venue still
need a printed copy to settle.

---

## Problem

A user who calls `create_replicate_weights()` must pick one of six methods. The
help page names the six and stops. Nothing tells the user which one fits their
data.

The methods are not interchangeable. Each one assumes something about how the
sample was drawn. Three examples of what goes wrong:

- The jackknife never converges to the correct variance for a median. A user who
  wants a quantile and picks the jackknife gets a standard error that does not
  improve as the sample grows.
- Successive difference replication reads the row order of the data. A user who
  sorts the rows differently gets a different, and wrong, answer. The function
  raises no error.
- Balanced repeated replication needs exactly two first-stage units per stratum.
  A design with one unit in any stratum cannot use it.

None of this is in the docs today. The code survey confirms the gap: not one of
the seven functions in this family uses an `@details` tag.

Two terms recur below. A **PSU** (primary sampling unit) is the first thing the
design selects — often a county, a school, or a city block, not a person. A
**Hadamard matrix** is a square grid of +1 and -1 values arranged so that any
two rows agree in exactly half their positions. Several methods use one to
decide which units to up-weight in each replicate.

---

## Scope: six methods, seven profiles

The dispatcher accepts six `method` strings. Verbatim from
`R/create_replicate_weights.R:56-63`:

```r
method = c(
  "bootstrap",
  "jackknife",
  "brr",
  "generalized-bootstrap",
  "generalized-replicate",
  "successive-difference"
)
```

Two naming traps follow.

**Trap 1 — the strings do not match the function names.** The dispatcher maps
`"generalized-bootstrap"` to `create_gen_boot_weights()`,
`"generalized-replicate"` to `create_gen_rep_weights()`, and
`"successive-difference"` to `create_sdr_weights()`
(`R/create_replicate_weights.R:67-75`). The short form "SDR" is never a valid
`method` value.

**Trap 2 — group jackknife is not a dispatcher method.** No
`create_group_jackknife_weights()` function exists. The jackknife-merge
refactor moved delete-a-group jackknife into `create_jackknife_weights()` as
`type = "grouped"`. The dispatcher roxygen says so
(`R/create_replicate_weights.R:17-20`): "For delete-a-group jackknife on a
`survey_nonprob`, use `method = "jackknife"` with `type = "grouped"`."

So this doc covers **six methods across seven profiles**. The jackknife carries
three profiles — `"jk1"`, `"jkn"`, and `"grouped"` — and the grouped profile is
a separate method in the literature, with its own papers and its own traps.

The dispatcher owns only `data` and `method`. Every other argument travels
through `...` to the selected sibling, with no checking on the way
(`R/create_replicate_weights.R:21-22`): "Invalid arguments for the selected
method produce R's native \"unused argument\" error."

---

## Method 1 — Bootstrap

`method = "bootstrap"` → `create_bootstrap_weights()`

### Mechanism

The method draws the sample again with replacement, once per replicate, and
rebuilds the estimate on each draw. The spread of the replicate estimates gives
the variance.

For a non-probability sample the method rebuilds the whole weighting pipeline
inside every replicate. It resamples the non-probability sample, resamples the
reference probability sample under its own design, refits the model that makes
the pseudo-weights, then recomputes the estimate. The refit is the point: the
model itself carries estimation error. A bootstrap that reuses the full-sample
weights misses that error and reports a variance that is too small.

$$\hat{V}_{\text{boot}} = \frac{1}{B-1}\sum_{b=1}^{B}\left(\hat{\mu}_{y}^{(b)} - \hat{\mu}_{y}\right)^2$$

| Symbol | Meaning | Bound to (R) |
|---|---|---|
| $B$ | number of bootstrap replicates | `replicates` |
| $\hat{\mu}_{y}^{(b)}$ | estimate from replicate $b$, after the refit | one replicate column |
| $\hat{\mu}_{y}$ | full-sample estimate | estimate before resampling |

**Source:** Chrostowski et al. §2.2, Eq. 5. Note that this form centers on the
full-sample estimate but divides by $B-1$. Most texts either center on the full
estimate and divide by $B$, or center on the replicate mean and divide by
$B-1$. The package exposes both conventions through `mse`.

### Design it suits

- A probability sample, through the `svrep` back end. `type` picks the scheme:
  `"Rao-Wu-Yue-Beaumont"` (the default), `"Rao-Wu"`, `"Antal-Tille"`,
  `"Preston"`, or `"Canty-Davison"`.
- A non-probability sample with a reference probability sample, through
  `type = "quasi-randomization"`. The reference sample supplies the covariates
  that model the chance of entering the non-probability sample.

### Prefer it over the siblings when

- **The estimand is a quantile.** This is the one clean, sourced win. Elliott &
  Valliant (2017): "The bootstrap should also be consistent for estimating the
  variance of estimated quantiles, unlike the jackknife."
- **The estimator has no closed-form variance.** Wu (2022) §6.3: "A doubly
  robust variance estimator for the commonly used $\hat{\mu}_{DR2}$ is not
  available in the literature. A practical solution is to use bootstrap
  methods." Wu §6.1 adds: "A bootstrap variance estimator turns out to be more
  attractive for practical applications."
- **The estimator is doubly robust.** Chrostowski et al. §2.4: the bootstrap
  "performs well in terms of the coverage rate when one of the working models is
  correctly specified. This is why this approach is recommended for all users."

No sourced comparison against BRR, generalized replication, or successive
difference replication. None of the four bootstrap papers mention them.

### Key parameters

| Parameter | Code | Literature |
|---|---|---|
| `replicates` | default `NULL`, resolving to `200L` for non-probability types and `500L` for probability types. Minimum 2. | Chrostowski's example uses `B = 50`. No source gives a rule for choosing $B$. |
| `mse` | **A string, not a logical.** `c("mse", "chrostowski", "uncentered")`, resolving to `"mse"`. `TRUE` raises `surveywts_error_mse_not_character`. | `"mse"` centers on the full-sample estimate. `"uncentered"` centers on the bootstrap mean. `"chrostowski"` is the Eq. 5 form above, and is legal only for non-probability types. |
| `tau` | Not an argument. | — |
| `variance_estimator` | Not an argument. | — |

### Gotchas

1. **`mse` breaks the family pattern.** Every other sibling takes
   `mse = TRUE`. This one takes a string and rejects the logical outright, so an
   example copied from a sibling fails (`create_bootstrap_weights.R:135-151`).
2. **A stale model understates the variance.** Elliott & Valliant (2017): "for
   each bootstrap or jackknife iteration, the pseudo-weights should be
   recomputed as well as the point estimator using the dropped-out or resampled
   data."
3. **A stratified multi-stage reference sample is not covered.** Wu (2022) §6.3
   gives the result for single-stage unequal probability designs, then warns:
   "Complications will arise when the probability sample $S_B$ uses stratified
   multi-stage sampling methods, a known challenge for variance estimation with
   complex surveys."
4. **Clustering in the panel is assumed away.** Chrostowski's Assumption A3
   requires independent inclusion given the covariates. Elliott & Valliant note
   that recruiting websites can behave as clusters. If they do, the bootstrap
   standard error is too small.
5. **`type = "hybrid"` always fails.** It is a listed, documented option that
   raises `surveywts_error_hybrid_bootstrap_not_implemented` on every call. It
   needs `mass_imputation()`, which does not exist yet
   (`create_bootstrap_weights.R:222-237`).
6. **`mse = "chrostowski"` is non-probability only.** It raises
   `surveywts_error_chrostowski_prob_sample` on a probability sample.
7. **Zero coverage cannot be fixed with more replicates.** Wu (2022) §7.2: if
   some population units have no chance at all of entering the sample, the
   bootstrap variance describes only the reachable part of the population.
8. **The model-based path has no proven theory.** Elliott & Valliant: "finite
   population, model-based theory has not been worked-out for the bootstrap."

---

## Method 2 — Jackknife (`jk1`, `jkn`)

`method = "jackknife"` → `create_jackknife_weights()`, `type = "jk1"` or
`"jkn"`

### Mechanism

The method drops one PSU, then raises the weights of the remaining PSUs in that
same stratum so they stand in for the whole stratum. It repeats this once per
PSU. The spread of the resulting estimates gives the variance.

`"jkn"` drops one PSU at a time inside each stratum. `"jk1"` treats the whole
sample as a single stratum and drops one unit at a time. `"jk1"` is `"jkn"` with
one stratum.

JKn variance (Valliant, Dever & Kreuter 2018, §15.4.1, Eq. 15.12):

$$v_J(\hat\theta) = \sum_{h=1}^{H} \frac{m_h - 1}{m_h} \sum_{i \in s_h} \left(\hat\theta_{(hi)} - \hat\theta\right)^2$$

JKn replicate weight rule (VDK 2018, §15.4.1, Eq. 15.11):

$$
d_{k(hi)} = \begin{cases}
0 & k \text{ in PSU } i \text{ of stratum } h \\
\dfrac{m_h}{m_h-1}\, d_k & k \text{ in stratum } h,\ k \notin \text{PSU } i \\
d_k & k \text{ outside stratum } h
\end{cases}
$$

JK1 is the $H=1$ case (VDK 2018, §15.4.1, Eq. 15.10):

$$v_J(\hat t) = \frac{n-1}{n}\sum_{i=1}^{n}\left(\hat t_{(i)}-\hat t\right)^2, \qquad d_{k(i)} = \frac{n}{n-1}d_k$$

| Symbol | Meaning | Bound to (R) |
|---|---|---|
| $H$ | number of design strata | count of distinct stratum IDs |
| $m_h$ | number of sampled PSUs in stratum $h$ | count of PSU IDs within stratum $h$ |
| $n$ | total sample size, JK1 only | number of rows treated as PSUs |
| $d_k$ | full-sample weight for unit $k$ | weight column |
| $d_{k(hi)}$ | replicate weight for unit $k$ | one column per replicate |
| $\hat\theta_{(hi)}$ | estimate with PSU $i$ of stratum $h$ dropped | per-replicate estimate |

Scaling factor by profile: $(n-1)/n$ across the whole sample for JK1;
$(m_h-1)/m_h$ applied inside each stratum, then summed, for JKn.

### Design it suits

- `"jk1"` — a simple random sample, with no clustering and no strata.
- `"jkn"` — a stratified sample with PSUs drawn per stratum, including
  multi-stage designs. VDK 2018 §15.4.1: "if a multistage sample is selected,
  'deleting a unit' means 'delete a PSU'."

Unequal PSU counts across strata are handled correctly by construction. Each
stratum uses its own $m_h$ in both the weight adjustment and the scale factor.

A stratum with one PSU breaks the method outright. There is no other PSU to
carry the stratum, so no replicate can be formed. VDK 2018 gives two remedies:
collapse the stratum with a neighbour (§15.5.3), or mark the PSU a certainty and
let lonely-PSU handling drop it from the variance without dropping it from the
estimate (§15.6).

### Prefer it over the siblings when

The honest answer is that the sources give the jackknife few positive
recommendations. They mostly mark its limits.

- **Over BRR:** only because the jackknife does not need two PSUs per stratum.
  Dippo, Fay & Morganstein (1984) §5.4: "Other replication methods, such as the
  Jackknife, would not require two selections per first stage stratum."
- **Against BRR, when the design does have two PSUs per stratum:** prefer BRR.
  VDK 2018 §15.4.1 is blunt: "there seems to be no good reason to use JK2 in any
  application."
- **Against BRR and the bootstrap for any quantile:** prefer either of them. VDK
  2018 §15.4.1: "Neither JKn nor JK2 converges to the correct variance for
  quantiles." The same passage notes BRR "has been proven to work for nonlinear
  estimators and for quantiles like the median."

No sourced comparison against generalized bootstrap, generalized replication, or
successive difference replication.

### Key parameters

| Parameter | Code | Literature |
|---|---|---|
| `replicates` | default `NULL`, and **unused for `"jk1"` and `"jkn"`**. The count comes from the design. | VDK 2018 §15.4.1: "the total number of replicates in JKn equals the number of sample PSUs." Not tunable. |
| `mse` | `logical(1)`, default `TRUE`. Fully documented already (`create_jackknife_weights.R:38-43`). | `TRUE` centers on the full-sample estimate and gives "a somewhat larger and more conservative precision estimate" (VDK 2018, Example 15.10). `FALSE` centers on the within-stratum mean of replicate estimates. |
| `tau` | Not an argument. | — |
| `variance_estimator` | Not an argument. | The `"jk1"` / `"jkn"` choice *is* the estimator choice, and the design settles it. |

### Gotchas

1. **A single-PSU stratum gives a crash or a silently low variance.** Which one
   depends on the code path. The stratum contributes nothing, so the variance is
   understated. Remedies: VDK 2018 §15.5.3 and §15.6.
2. **Quantiles never converge.** VDK 2018 §15.4.1: "Neither JKn nor JK2
   converges to the correct variance for quantiles." The standard error does not
   improve with sample size.
3. **Adjustments must be replayed per replicate.** VDK 2018 §15.4.1: "It is not
   enough to simply create replicate weights by adjusting the final full-sample
   weight alone." A nonresponse or calibration step applied once to the
   full-sample weight, then scaled mechanically, drops the variance that step
   contributes.
4. **For a domain estimate, set the weight to zero. Do not filter the rows.**
   VDK 2018 §15.4.1 calls zero-coding "the standard way of computing the
   jackknife" and says working from a physically subset file "would generally be
   a mistake." Any code that strips zero-weight rows before the replicate
   computation corrupts domain results.
5. **A low PSU count destabilises the variance itself.** VDK 2018 Eq. 15.9 gives
   $df = \sum_h m_h - H$. At $df=10$ the standard error estimate has a
   coefficient of variation near 22%, falling to about 10% only near $df=50$
   (Table 15.2).
6. **Without-replacement designs need a finite-population correction.** The
   theory assumes with-replacement PSU selection. Valliant, Brick & Dever (2008)
   §2 give the corrected form with a $(1-f_h)$ term. Omitting it on a large
   sampling fraction inflates the standard error.
7. **`var_strat`, `var_strat_frac`, and `sort_var` are silent no-ops here.**
   They are "Silently ignored for `\"jkn\"` and `\"jk1\"`"
   (`create_jackknife_weights.R:44-55`). Passing one does nothing and says
   nothing.

---

## Method 2b — Group jackknife (`type = "grouped"`)

`method = "jackknife"`, `type = "grouped"`, on a `survey_nonprob` design

This profile is a different method from `"jk1"` and `"jkn"`. It has its own
papers and its own full comprehension doc at
`plans/archive/group-jackknife/comprehension-group-jackknife.md`. What follows
is the dispatcher-level summary.

### Mechanism

The method splits the combined data — the non-probability sample plus the
reference sample — into $G$ random groups of roughly equal size. Each replicate
drops one group, refits the whole weighting pipeline on what remains, and
recomputes the estimate.

$$v_J(\hat{\theta}) = \frac{G-1}{G} \sum_{g=1}^{G} \left(\hat{\theta}_{(g)} - \hat{\theta}\right)^2$$

| Symbol | Meaning | Bound to (R) |
|---|---|---|
| $G$ | number of random deletion groups | `replicates` |
| $\hat{\theta}_{(g)}$ | estimate refit on all data outside group $g$ | one replicate column |
| $\hat{\theta}$ | full-sample estimate | estimate before deletion |

**Source:** Valliant (2020), Eq. 3, §2.1.4. The factor is $(G-1)/G$ with $G$ the
number of *groups*, never $(n-1)/n$ with $n$ the sample size.

### Design it suits

A non-probability sample — an opt-in panel, a volunteer registry, a convenience
sample — combined with a probability-based reference sample that covers the
target population. The groups are random partitions of the combined data, not
design PSUs.

### Prefer it over the siblings when

- **Over the ungrouped jackknife:** to cut computation. Valliant (2020) §2.1.4:
  "Grouping of units to form deletion groups can be used to reduce the amount of
  computation."
- **Over the bootstrap, for a prediction-type estimator:** the bootstrap has no
  theory here at all. Elliott & Valliant (2017): "The bootstrap is another
  replication estimator that should be equally robust, although, to our
  knowledge, finite population, model-based theory has not been worked-out for
  the bootstrap."
- **Not over the bootstrap for a quantile.** The same paper reverses there. See
  "Cross-paper conflicts".

### Key parameters

| Parameter | Code | Literature |
|---|---|---|
| `replicates` | **Required.** `NULL` raises `surveywts_error_jackknife_replicates_required`. Must be a whole number, at least 2, and no greater than the combined row count. | Valliant (2020) §3.2.1 used $G = 50$ for $n = 500$ and $n = 1000$. No rule is given for scaling $G$ with $n$. |
| `mse` | Forced to `TRUE`. `FALSE` is overridden with `surveywts_warning_jackknife_mse_overridden`. | Eq. 3 centers on the full-sample estimate, so `TRUE` is the only form that matches the source. |
| `tau` | Not an argument. | — |
| `variance_estimator` | Not an argument. | Valliant (2020) compares the grouped jackknife against a with-replacement linearized estimator, and finds the jackknife tracks the true standard error better for quasi-randomization and doubly robust estimators (§3, Tables 8-9). |

### Gotchas

1. **Refit, do not just re-weight.** The model that makes the pseudo-weights
   must be refit inside every replicate.
2. **The scale factor ties to the group count, not the sample size.** Using
   $(n-1)/n$ inflates the variance badly.
3. **The variance runs high for doubly robust estimators, and nobody knows why.**
   Valliant (2020) Table 8: relative bias of the standard error runs about
   2.7% to 4.6% at $n=500$ and about 1.7% to 3.2% at $n=1000$, across all seven
   estimands, and it does not shrink as $n$ grows. The cause is not established
   in the literature. Treat these estimates as slightly conservative.
4. **No formal consistency proof exists for the doubly robust case.** Valliant
   (2020) §2.4: "A formal proof of the consistency of such a replication
   estimator does not appear to exist in the literature for a nonprobability
   sample." Consistency for the quasi-randomization-only case rests on Krewski
   and Rao (1981) and Wolter (2007), the second of which this repo cannot verify.
5. **Small groups can stop the model from converging.** Dropping a group can
   remove the only case at some covariate level. Neither paper gives a fallback.
   The code warns through `surveywts_warning_jackknife_small_groups` when the
   average group size falls below 5.
6. **Negative replicate weights can appear after the calibration step**, though
   not from the inverse-probability step itself. The code raises
   `surveywts_warning_jackknife_negative_replicate_weights`.

---

## Method 3 — BRR

`method = "brr"` → `create_brr_weights()`

### Mechanism

The design must have two PSUs per stratum. Each replicate keeps one PSU per
stratum at a raised weight and the other at a lowered weight. A Hadamard matrix
decides which PSU gets which weight in each replicate, so that the set of
replicates stays balanced across strata.

Classic BRR uses factors 2 and 0 — one PSU per stratum drops to zero weight.
Fay's variant replaces them with 1.5 and 0.5, so no PSU is ever zeroed, and
puts a 4 in front of the sum instead of a 1 (Fay 1989 §3, Eq. 3.1; Dippo, Fay &
Morganstein 1984 §4).

Half-sample form, centered on the full-sample statistic (Fay 1984, Eq. 2.18):

$$\operatorname{Var}_{HS2}(S_n) = \frac{1}{J}\sum_{j=1}^{J}\left\{S_k\!\left(X_{1h(1,j)},\ldots,X_{kh(k,j)}\right) - S_n(X_{11},\ldots,X_{k2})\right\}^2$$

Fay's modified form (Fay 1989, Eq. 3.1):

$$\operatorname{Var}^{*}_r(Y(0)) = \frac{4}{k}\sum_{r=1}^{k}\left(Y(r) - Y(0)\right)^2$$

| Symbol | Meaning | Bound to (R) |
|---|---|---|
| $J$, $k$ | number of half-sample replicates | fixed by the design, not an argument |
| $h(i,j)$ | which of the two PSUs in stratum $i$ replicate $j$ keeps | the Hadamard pattern |
| $Y(0)$ | full-sample weighted estimate | estimate before perturbation |
| $Y(r)$ | replicate $r$ estimate | one replicate column |

The perturbation size sits in `rho`, **not** in `tau`. `rho = 0` gives the
classic 2-and-0 factors. A positive `rho` moves toward Fay's variant and keeps
every weight above zero.

### Design it suits

Exactly two PSUs per stratum — the NHANES-style paired design. Dippo, Fay &
Morganstein (1984) §5.4 state the requirement and the workaround for a design
that misses it: "the strata are paired into pseudo-strata so that half sample
may be taken." The two PSUs are assumed drawn with replacement, which Fay (1984)
§2 needs "in order to give the necessary independence."

The code enforces this. A stratum without exactly 2 PSUs raises
`surveywts_error_brr_requires_paired_design`
(`create_brr_weights.R:74, 91, 122`).

### Prefer it over the siblings when

- **The design is paired and the estimand is a quantile or another nonlinear
  statistic.** VDK 2018 §15.4.1: BRR "has been proven to work for nonlinear
  estimators and for quantiles like the median," while no jackknife variant
  converges for a quantile. This is the strongest sourced reason to choose BRR.
- **The design is paired at all.** VDK 2018 §15.4.1: "there seems to be no good
  reason to use JK2 in any application."

Replicate-count economy is often claimed for BRR over the jackknife. **None of
the three Fay-family sources state it.** Do not put it in the docs.

No sourced comparison against generalized bootstrap or successive difference
replication.

### Key parameters

| Parameter | Code | Literature |
|---|---|---|
| `replicates` | **Not an argument.** The count follows from the paired-PSU structure. | Fay (1989) §3: SIPP used $k=100$; "most current surveys" used $k=48$. |
| `mse` | `logical(1)`, default `TRUE`. Type-only roxygen — needs prose. | Fay (1984) gives both forms: center on the replicate mean (Eq. 2.15) or on the full-sample statistic (Eq. 2.18). Fay's applied formula uses the second. That form additionally needs the statistic to be symmetric under swapping the two PSUs in a stratum (Eq. 2.17). |
| `tau` | **Not an argument. `rho` plays this role.** Default `0`, validated to $0 \le \rho < 1$; outside that range raises `surveywts_error_brr_rho_invalid`. | Fay's concrete instance is factors 1.5 and 0.5, that is $1 \pm 0.5$, with the matching $4/k$ constant (Fay 1989 §3). The sources never name this quantity $\tau$ or $\rho$. |
| `variance_estimator` | Not an argument. | The $d_r$ coefficient family in Dippo, Fay & Morganstein (1984) Eq. 2.3 covers it: $d_r = 1/R$ for the classic factors, $4/R$ for Fay's. |

### Gotchas

1. **The default `rho = 0` gives zero-weight replicates.** That is classic BRR,
   and Dippo, Fay & Morganstein (1984) §4 built the fractional factors
   specifically to avoid it: positive replicate weights "insured that complex
   functions built from ratios would be defined whenever the function could be
   computed for the whole sample." With `rho = 0`, a ratio or log statistic can
   be undefined in a replicate even though it is fine on the full sample. Set
   `rho > 0` when the estimand is a ratio.
2. **BRR runs high, by design.** Fay (1984) §2: "half-sample replication, using
   (2.15) or (2.18), generally tends to produce overestimates of variance in the
   sense of expectation." The overestimate can be "substantial."
3. **An asymmetric statistic voids the guarantee.** The full-sample-deviation
   form holds its bound only when the statistic is symmetric under swapping the
   two PSUs in a stratum (Fay 1984, Eq. 2.17).
4. **Non-smooth statistics are an open question, not a solved one.** Dippo, Fay
   & Morganstein (1984) §2 decline to settle it: "it is a matter of current
   research to determine situations in which specific replication-based estimates
   of variance ... may give suitable estimates of variance for some specific
   non-smooth functions."
5. **No source gives a rule for choosing `rho`.** Only Fay's single worked value
   of 0.5 exists. An ad hoc value is unsupported by these papers.

---

## Method 4 — Generalized bootstrap

`method = "generalized-bootstrap"` → `create_gen_boot_weights()`

### Mechanism

The method starts from a target variance formula — the one an analyst would get
from Taylor linearization for a simple total. It writes that formula as a
quadratic form with a matrix $\Sigma$. It then draws random multipliers whose
mean and variance reproduce $\Sigma$, and multiplies the base weights by them.
No derivatives are needed. The `variance_estimator` argument picks the target,
and that one choice drives everything else.

Target, as a quadratic form (Beaumont & Patak 2012, §2, Eq. 1):

$$\hat{m}_2 = \sum_{k \in s}\sum_{l \in s} \sigma_{kl}\bar y_k \bar y_l = \bar{\mathbf y}'\Sigma\bar{\mathbf y}$$

The two conditions the multipliers must meet (§3, p. 131):

$$E_*(\mathbf a) = \mathbf 1_n, \qquad E_*(\mathbf a - \mathbf 1_n)(\mathbf a - \mathbf 1_n)' = \Sigma$$

Replicate weight and variance (§3, p. 130; §3.2, Eq. 6):

$$w_k^* = w_k a_k, \qquad v_B(\hat T_y) = \frac{1}{B}\sum_{b=1}^{B}\left(\hat T_y^{*(b)} - \hat T_y\right)^2$$

| Symbol | Meaning | Bound to (R) |
|---|---|---|
| $w_k$ | base weight, $1/\pi_k$ | input weight column |
| $a_k$ | random multiplier for unit $k$ | computed internally |
| $w_k^*$ | replicate weight | one replicate column |
| $\Sigma$ | the target variance matrix | set by `variance_estimator` |
| $B$ | number of replicates | `replicates` |
| $\tau$ | rescaling constant for negative multipliers | `tau` |

### Design it suits

Any design where a design-unbiased variance formula for the simple total exists,
fits the quadratic form, and yields a $\Sigma$ that can never imply a negative
variance. Beaumont & Patak (2012) §9 give the three conditions: computable for
every sample, never negative-variance-implying, and design-consistent.

The paper pays special attention to **Poisson sampling** — a design where each
unit enters independently, so the sample size is random. There $\Sigma$ collapses
to a simple diagonal, which is automatically safe (§4, Eq. 12).

This is also the general-purpose fallback for designs that fit none of the named
methods. Fay (1984) Theorem 1 supplies the licence: "there is no variance
estimator based on sums of squares and cross-products that cannot be represented
by a resampling plan."

### The `variance_estimator` choice

This is the central decision, and the option list outruns the papers. The code
accepts 12 strings, hardcoded in surveywts and forwarded to `svrep`
(`create_gen_boot_weights.R:96-109`, and the identical list at
`create_gen_rep_weights.R:90-103`):

```r
c("SD1", "SD2", "Horvitz-Thompson", "Yates-Grundy",
  "Poisson Horvitz-Thompson", "Stratified Multistage SRS",
  "Ultimate Cluster", "Deville-1", "Deville-2", "Deville-Tille",
  "BOSB", "Beaumont-Emond")
```

What the sources cover:

- **Horvitz-Thompson.** $\sigma_{kl} = (\pi_{kl}-\pi_k\pi_l)/\pi_{kl}$ off the
  diagonal, $(1-\pi_k)$ on it (Beaumont & Patak 2012 §2, Eq. 2). Works for any
  design with computable inclusion probabilities. **Can yield a $\Sigma$ that
  implies a negative variance** for some designs — the paper flags this (§2,
  p. 130).
- **Yates-Grundy** (the Sen-Yates-Grundy estimator). Safe when its off-diagonal
  terms are non-positive, but **restricted to fixed-size designs**. The paper is
  explicit that it is "not appropriate for Poisson sampling" (§2, p. 130).
- **Poisson Horvitz-Thompson.** The diagonal $\Sigma$, and the only valid choice
  under Poisson sampling (§4, Eq. 12).
- **SD1 and SD2**, the two defaults, are the successive-difference estimators.
  Ash (2014) §1.1 defines them, and his simulation results bear directly on
  these defaults. See "Method 6" and "Cross-paper conflicts".

What the sources do **not** cover: `"Ultimate Cluster"`, `"Deville-1"`,
`"Deville-2"`, `"Deville-Tille"`, `"BOSB"`, and `"Beaumont-Emond"` appear in
none of the four papers mapped to this function. `"Stratified Multistage SRS"`
appears in Bellhouse (1985) only as an exact recursive computation, never as a
generalized-bootstrap target. Bellhouse never mentions bootstrap weights at all.
**The `@details` block must not imply the literature backs all 12.**

Consequence of a mismatch: if $\Sigma$ can imply a negative variance, the matrix
square root needed to build the multipliers cannot be computed. The only
documented repair is to zero the offending components, which the authors say
"leads to overestimation of the variance" (§9, p. 146). It is a named bias, not
a silent one.

### Prefer it over the siblings when

- **Over the jackknife, to control the replicate count.** Beaumont & Patak
  (2012) §1: "Unlike other replication methods, such as the jackknife, the
  number of replicates can be easily controlled with the bootstrap, which makes
  it even more attractive."
- **Not against the plain bootstrap.** Gen-boot is the framework that contains
  it. The Rao-Wu bootstrap is presented as a special case (§3.4).
- **Under Poisson sampling, over anything built on a fixed sample size.** The
  Sen-Yates-Grundy estimator "cannot be used" there (§4, p. 135).

### Key parameters

| Parameter | Code | Literature |
|---|---|---|
| `replicates` | default `500L`, minimum 2. | **At least 750, whenever possible.** Table 1 gives 768 for a 5% tolerance at 95% confidence. The paper explicitly rejects the 100 or 200 "sometimes chosen in practice" (§3.3, §9). The shipped default of 500 sits below the recommendation. |
| `mse` | `logical(1)`, default `TRUE`. Type-only roxygen. | Not addressed by name. Eq. 6 centers on the full-sample estimate. |
| `tau` | default `1`. **No validation at all** — no type check, no range check, no handling of `"auto"`. Forwarded verbatim to `svrep::as_gen_boot_design()` (`create_gen_boot_weights.R:140`). | Rescales the multipliers to clear negative weights: $a_k^S = (a_k+\tau-1)/\tau$, and **the variance must then be multiplied by $\tau^2$** (§6, Eq. 26-27). Choose the smallest $\tau \ge 1$ that makes every multiplier non-negative. |
| `variance_estimator` | default `"SD1"`; 12 options. `"Deville-Tille"` needs `aux_var_names` or raises `surveywts_error_variance_estimator_requires_aux`. | See above. |

### Gotchas

1. **Never discard a negative replicate weight.** Beaumont & Patak (2012) say a
   negative weight "is not a problem per se provided that they are not
   discarded." Their §7 illustration shows relative bias of 294.54% from one
   extreme negative weight, falling to 28.15% after rescaling with `tau`.
2. **`tau` without the $\tau^2$ correction gives a wrong variance.** The
   rescaling and the correction are one operation, not two options.
3. **`tau = "auto"` is documented but not implemented.** The roxygen offers it
   (`create_gen_boot_weights.R:22-23`); the code forwards the string to `svrep`
   untouched. Whatever it does comes from `svrep`. Do not claim surveywts
   resolves it.
4. **The default 500 replicates is below the sourced floor of 750.** Simulation
   error in the variance estimate scales as $2/B$.
5. **A target that does not match the design fails loudly or biases high.**
   See "The `variance_estimator` choice".
6. **The two GREG targets are not interchangeable.** Beaumont & Patak §5.2 state
   directly that one Monte Carlo version cannot be obtained from the other's
   construction.
7. **A skewed multiplier distribution needs far more replicates.** §8, Table 5:
   for one distribution the design coefficient of variation had still not
   settled at $B=500{,}000$, against stable results near $B=1{,}000$ for
   symmetric ones. Coverage fell to 73.3% at $n=50$ (§7, Table 4).
8. **The return type reads `"bootstrap"`, not `"generalized-bootstrap"`.** The
   code sets `type_override = "bootstrap"` deliberately
   (`create_gen_boot_weights.R:153`). Do not read `@variables$type` as the
   method name.

---

## Method 5 — Generalized replication

`method = "generalized-replicate"` → `create_gen_rep_weights()`

### Mechanism

The method starts from any symmetric matrix $C(s)$ that already gives a valid
variance estimator for a weighted total. It decomposes that matrix into its
component directions, and turns each direction into a weight perturbation.

Fay (1989) §2 gives two constructions. The first uses one direction per
replicate. The second spreads every direction across every replicate through a
Hadamard matrix — and that second construction is BRR's own logic, generalized.
Fay states it plainly: the option "resembles half-sampling replication, in the
sense that each eigenvector participates in each replicate, just as half-sample
replication selects one of two halves from each of the strata in forming each
replicate sample."

Definition and the exact identity (Fay 1989, Eq. 2.1, 2.2, 2.4):

$$\operatorname{Var}^{*}(\mathbf{1}'\mathbf{x_W}) = \mathbf{x_W}' C(s) \mathbf{x_W}$$

$$\sum_{r=1}^{k} b_r\left(\mathbf{w_r}'x - \mathbf{w}'x\right)^2 = \mathbf{x_W}' C(s) \mathbf{x_W}$$

One direction per replicate (Eq. 2.3), and the Hadamard construction (§2, p. 3):

$$\mathbf{f}_r = \mathbf{1} + c_r \mathbf{v}_{(r)}, \quad b_r = \lambda_r c_r^{-2}
\qquad\qquad
\mathbf{f}_r = \mathbf{1} + c\sum_{m=1}^{k} H_{mr}\,\lambda_m^{1/2}\,\mathbf{v}_{(m)}, \quad b_r = \frac{1}{k'c^2}$$

| Symbol | Meaning | Bound to (R) |
|---|---|---|
| $C(s)$ | the target variance matrix for sample $s$ | set by `variance_estimator` |
| $\lambda_r, \mathbf{v}_{(r)}$ | component $r$ of $C(s)$ and its direction | computed internally |
| $\mathbf{f}_r$ | replicate factors for replicate $r$ | multiplier on the weight column |
| $c_r$, $c$ | free positive scaling constant | no surveywts argument exposes it |
| $H_{mr}$ | Hadamard matrix entry, order $k' \ge k$ | replicate pattern |

### Design it suits

Any design whose variance estimator for a total can be written as that quadratic
form. Fay's worked example (the 1985 SIPP panel) covers unequal-probability
selection of 2 PSUs per stratum by Durbin's method with the Yates-Grundy
estimator (§3.1), collapsing groups of 3 or 4 strata (§3.2), combining
between-stratum, between-PSU and within-PSU components in one scheme (§3.3-3.4),
and adding a component for multiple imputation (§4).

### BRR, gen-rep, and gen-boot — the real lineage

The draft table in `plans/doc-improvements.md` Section C calls gen-rep a
"deterministic alternative to gen-boot." That is imprecise, and it gets the
direction backwards. The sourced lineage is:

1. **Fay (1984)** builds the general theory of resampling plans, and shows BRR
   is a special case of it: BRR "is a special case of the random group method
   described by (2.12) and (2.13) with $r=2$" (§2). Theorem 1 proves any
   sums-of-squares variance estimator has some resampling plan.
2. **BRR** is that theory instantiated for the narrow two-PSU-per-stratum case.
3. **Gen-rep** (Fay 1989) generalizes it by decomposing an arbitrary $C(s)$.
   Its Hadamard construction is BRR's balancing rule, with the components of
   $C(s)$ standing in for BRR's stratum pairs.
4. **Gen-boot** is gen-rep's bootstrap counterpart. Beaumont & Patak (2012) §1:
   "The generalized bootstrap can also be viewed as a bootstrap version of the
   replication method described in Fay (1989)."

So gen-boot is the newer, randomized cousin of gen-rep, not the other way
round. The sources give no head-to-head performance claim between them.

One gap: Fay (1989) never ties BRR's fractional perturbation (§3) to the free
constant $c_r$ of the general construction (§2), even though both appear in the
same paper.

### Prefer it over the siblings when

- **Over Taylor linearization**, for a complex statistic. Dippo, Fay &
  Morganstein (1984) §1: replication "may be far less 'person-intensive' than
  methods based on linearization ... may facilitate the estimation of variance
  for highly complex functions for which linearization becomes a practical
  impossibility."
- **When many degrees of freedom must compress into few replicates.** Fay (1989)
  §3.4 folded "several hundred possible degrees of freedom" into $k=100$
  replicates with "only modest losses in efficiency."

No sourced comparison against gen-boot, SDR, or the group jackknife.

### Key parameters

| Parameter | Code | Literature |
|---|---|---|
| `replicates` | **Not an argument.** `max_replicates` exists instead, default `Inf`, **with no validation in surveywts**. The real count is $R \ge H$, set by `svrep`'s generalized Hadamard construction (`create_gen_rep_weights.R:33-34`). | Fay (1989) sets the minimum at the rank of $C(s)$, or the Hadamard order actually used. |
| `mse` | `logical(1)`, default `TRUE`. Type-only roxygen. | Every gen-rep formula in these sources centers on the full-sample estimate, never on the replicate mean. |
| `tau` | Not an argument. | The free constant $c_r$ is the analogue, chosen per application. In SIPP it came from the design's inclusion probabilities, as $1 \pm (\pi_{is}\pi_{js}/\pi_{ijs}-1)^{1/2}$ (§3.1). There is no single recommended number. |
| `variance_estimator` | default `"SD2"` — **not `"SD1"`**, though the 12-option list is identical to gen-boot's. | See gen-boot. |

### Gotchas

1. **The defaults differ between gen-boot and gen-rep.** Gen-boot defaults to
   `"SD1"`, gen-rep to `"SD2"`, from the same 12-option list. Easy to state
   backwards.
2. **An arbitrary subset of replicates is invalid.** For the one-direction-per-
   replicate construction, Fay (1989) §2: "this method should not be used unless
   all $k$ replicates are included or a random selection of replicates is
   carried out. In other words, a variance estimate based on an arbitrary subset
   of the $k$ replicates may prove unsatisfactory." The Hadamard construction is
   free of this restriction.
3. **Negative leading coefficients destabilise the estimate.** For general
   unequal-probability schemes the Yates-Grundy coefficient can go negative, and
   Fay (1989) §3.1 says "negative values for this coefficient can contribute to
   instability." Durbin's scheme is used because it avoids them.
4. **Zero components must be excluded.** Collapsing strata produces genuine
   zero-valued directions; only the non-zero ones belong in the construction
   (§3.2).
5. **`max_replicates` is unchecked.** A nonsense value is not caught by
   surveywts.
6. **Non-smooth statistics are unresolved**, exactly as for BRR.

---

## Method 6 — Successive difference replication

`method = "successive-difference"` → `create_sdr_weights()`

### Mechanism

The method estimates variance by comparing each unit with its neighbour in sort
order. That is the right comparison for a systematic sample, where the design
itself walks down an ordered list at a fixed interval.

Each unit takes two rows of a Hadamard matrix, chosen by its position in the
sort order. Combining the values in those two rows gives that unit's factor for
one replicate. The base weight times the factor is the replicate weight. Because
the row pairing follows the sort order, each replicate perturbs a unit against
its list neighbour.

Successive-difference variance, open chain — SD1 (Ash 2014 §1.1; Fay & Train
1995 §2.2):

$$v_2 = (1-f)\,\frac{n}{2(n-1)}\sum_{i=2}^{n}\left(y_i - y_{i-1}\right)^2$$

Circular form, which adds the first-against-last term — SD2:

$$v_{2m} = \tfrac{1}{2}(1-f)\left[\left(y_n - y_1\right)^2 + \sum_{i=2}^{n}\left(y_i - y_{i-1}\right)^2\right]$$

Replicate factor and the SDR estimator (Fay & Train 1995 §2.2; Ash 2014
Theorem 1):

$$f_{i,r} = 1 + 2^{-3/2}\,a_{i+1,r} - 2^{-3/2}\,a_{i+2,r}$$

$$\hat{v}_{\mathrm{SDR}}(\hat{Y}) = (1-f)\,\frac{4}{k}\sum_{r=1}^{k}\left(\hat{Y}_r - \hat{Y}\right)^2$$

Hadamard requirement (Ash 2014, Theorem 1(a)):

$$\mathbf{H}\mathbf{H}' = k\mathbf{I}, \qquad n \le k$$

| Symbol | Meaning | Bound to (R) |
|---|---|---|
| $n$ | sample size | number of rows, **in sort order** |
| $f = n/N$ | sampling fraction | finite-population correction |
| $a_{i,r}$ | Hadamard entry, row $i$, column $r$ | built internally |
| $k$ | Hadamard order, and the replicate count | `replicates` |
| $f_{i,r}$ | replicate factor for unit $i$ | multiplier on the weight |
| $\hat{Y}_r$, $\hat{Y}$ | replicate and full-sample totals | per-replicate and base estimates |

### Design it suits

Systematic sampling from an ordered list — one unit taken per fixed interval
down a sorted frame. Ash (2014) §1 uses "sys" throughout for exactly this.

**The row order is part of the method, not an incidental detail.** Ash's
Theorem 1 requires that "the order of the observations reflects the sort order
of sys." If the list arrives unordered, the reason to use SDR disappears: Ash
notes systematic sampling from an unordered list "can be shown to be equivalent
to simple random sampling (Madow and Madow 1944)."

The sort variable should be the one that ordered the frame before selection —
not a row ID, and not the outcome. Fay & Train (1995) §2.1 sorted the CPS frame
"by characteristics associated with labor force participation" before selecting.
That sort is what gives systematic sampling its advantage, and what SDR is built
to capture.

### Prefer it over the siblings when

The sources support only one direct contrast, and it is against a variance
estimator that ignores sort order entirely.

Ash (2014) Table A2, for a population with a linear trend: expected relative
bias of -0.960 for SD1 and 1.417 for SD2, against 25.317 for the
simple-random-sampling estimator; RMSE of 0.921 and 2.008 against 640.916. When
the sort order carries real information, a method that does not difference
adjacent units is far worse.

**Against BRR: no sourced claim of superiority.** Ash (2014) §2.1 shows the two
assigned to different parts of one design — SDR for the systematic
self-representing PSUs, BRR for the non-self-representing ones. That is division
of labour, not a ranking. Both use Hadamard matrices, and neither source
discusses a structural link between the two uses.

No sourced comparison against the jackknife, the bootstrap, the group jackknife,
gen-boot, or gen-rep. None of those methods are named in either source.

### Key parameters

| Parameter | Code | Literature |
|---|---|---|
| `replicates` | default `100L`, **minimum 4**. The roxygen already warns that the "Actual count may be slightly larger due to Hadamard matrix sizing." | The count must be a Hadamard order at or above $n$ (Ash, Theorem 1(a)), or above $n+2$ (Fay & Train §2.2, whose construction gives orders that are multiples of 4). CPS uses $k=160$ for roughly 54,000 systematic units — deliberately reduced. Ash's simulations used 16, 32, 48, or 64 against $n=64$. |
| `mse` | `logical(1)`, default `TRUE`. Type-only roxygen. | Not addressed. The estimator always centers on the full-sample total. |
| `tau` | Not an argument. | Not addressed. |
| `variance_estimator` | Not an argument. | The SD1-against-SD2 choice is the real variant here, and it is governed by how many connected loops the row assignment makes (Ash §2.1-§3). |

### Gotchas

1. **Wrong row order, wrong answer, no error.** The factors pair each unit with
   its neighbours by sort position. Re-sorted or randomly ordered rows destroy
   the correspondence to the real design, and nothing complains. This is the
   first thing to document.
2. **A "dead" replicate is correct. Do not drop it.** A replicate column where
   every factor equals 1.0 arises when the all-ones Hadamard row is assigned.
   Ash (2014) §2.1: "There is nothing wrong with dead replicates ... all the
   replicates, even the dead replicates, are needed in estimation." Filtering a
   column that looks identical to the base weights breaks the $4/k$
   normalisation.
3. **A reduced replicate set is approximate.** Ash §2.1: "Only with all the
   replicates of $\tilde{\mathbf{H}}$ will the remainder term $R$ equal 0."
   Treating a truncated count as exactly equal to SD2 overstates precision.
4. **The circular term can inflate the variance badly.** Fay & Train §2.2 warn
   against including $(y_n - y_1)^2$ "in applications where the order of the
   sort is highly informative and $y_1$ and $y_n$ are likely to be highly
   dissimilar." Ash's Table A2 shows it concretely.
5. **A Hadamard order below $n$ needs the cycling construction** of Ash's
   Theorem 2. Going below it without that machinery gives an undefined row
   assignment.
6. **`sort_var` must have no missing values** — `surveywts_error_sort_var_has_na`
   (`create_sdr_weights.R:93`).

---

## Parameter reference across the family

The four parameters the brief names do not appear uniformly. This table is the
corrective.

| | `replicates` | `mse` | `tau` | `variance_estimator` |
|---|---|---|---|---|
| dispatcher | pass-through | pass-through | pass-through | pass-through |
| bootstrap | `NULL` → 200 or 500 | **string**: `"mse"` | — | — |
| jackknife `jk1`/`jkn` | unused; design sets it | `TRUE` | — | — |
| jackknife `grouped` | **required** | forced `TRUE` | — | — |
| brr | **absent** | `TRUE` | **absent — uses `rho = 0`** | — |
| generalized-bootstrap | `500L` | `TRUE` | `1` | `"SD1"` |
| generalized-replicate | **absent — `max_replicates = Inf`** | `TRUE` | — | `"SD2"` |
| successive-difference | `100L`, min 4 | `TRUE` | — | — |

Four warnings for the doc author.

1. **`tau` exists on exactly one function.** It is Beaumont & Patak's rescaling
   constant for negative multipliers, and it carries a mandatory $\tau^2$
   variance correction. BRR's perturbation is a different quantity with a
   different name, `rho`, and a different meaning. Do not describe them together.
2. **`mse` is a string on the bootstrap and a logical everywhere else.**
3. **Two functions have no `replicates` argument.** BRR takes its count from the
   design; gen-rep uses `max_replicates`.
4. **`mse` prose exists for only two functions.** `create_bootstrap_weights()`
   and `create_jackknife_weights()` describe the behaviour. BRR, gen-boot,
   gen-rep, and SDR give the type and default only. The doc plan's claim in
   Section H is correct.

---

## Method-choice table (feeds Section C)

For an R-fluent analyst who is not a survey methodologist. This replaces the
draft table in `plans/doc-improvements.md` Section C.

| `method =` | Choose it when | Do not choose it when |
|---|---|---|
| `"bootstrap"` | Your estimand is a median or another quantile. Your estimator has no textbook variance formula. You have a non-probability sample plus a reference sample. | Your reference sample is stratified and multi-stage — that case is unproven. |
| `"jackknife"` (`"jkn"`) | You have a stratified, possibly multi-stage probability sample, every stratum holds 2 or more PSUs, and your estimand is a total, mean, or ratio. | Your estimand is a quantile. Any stratum holds one PSU. Every stratum holds exactly 2 PSUs — use `"brr"` instead. |
| `"jackknife"` (`"jk1"`) | You have a simple random sample with no strata and no clusters. | Same quantile limit as `"jkn"`. |
| `"jackknife"` (`"grouped"`) | You have a non-probability sample plus a reference sample, and you want fewer replicates than the ungrouped jackknife. Set `replicates` yourself. | Your estimand is a quantile. You need a proven consistency result for a doubly robust estimator — none exists. |
| `"brr"` | Every stratum holds exactly 2 PSUs, and especially when your estimand is a quantile or another nonlinear statistic. | Any stratum does not hold exactly 2 PSUs. Also set `rho > 0` if your estimand is a ratio. |
| `"generalized-bootstrap"` | Your design fits none of the above — Poisson sampling, an unusual multi-stage structure, or a case where you must name the target variance estimator yourself. | You cannot say which `variance_estimator` matches your design. Raise `replicates` to 750 or more. |
| `"generalized-replicate"` | You want the deterministic counterpart of generalized bootstrap, built from the same target variance estimators. | You planned to pass `replicates` — the argument does not exist. |
| `"successive-difference"` | Your sample was drawn systematically from a sorted list, and the rows still carry that sort order. | The rows are not in the original sort order. The sort variable carried no information — then the design was effectively a simple random sample. |

---

## Draft `@details` block

House style follows `R/calibrate.R:85-117`: bold method name, an inline citation
per method, and a closing pointer to the dispatched functions. Do not put the
full algorithm here — Tier 4 forbids duplicating the siblings' Algorithm
sections.

```r
#' @details
#' All six methods estimate variance by rebuilding the estimate on many
#' perturbed copies of the weights, then measuring the spread across
#' those copies. They differ in how the perturbation is built, and each
#' one assumes something about the sample design. Replication avoids the
#' derivatives that Taylor linearization needs, which makes variance
#' available for complex statistics (Dippo, Fay & Morganstein 1984).
#'
#' **Bootstrap** (`method = "bootstrap"`) resamples with replacement and
#' recomputes the estimate. It is the only method here that is consistent
#' for quantiles (Elliott & Valliant 2017), and the practical choice when
#' an estimator has no closed-form variance (Wu 2022). On a
#' non-probability sample with `type = "quasi-randomization"`, the
#' pseudo-weight model refits inside every replicate. Note that `mse` is
#' a string here, not a logical.
#'
#' **Jackknife** (`method = "jackknife"`) drops one PSU at a time and
#' reweights the rest of its stratum (Valliant, Dever & Kreuter 2018,
#' Section 15.4). Use `type = "jk1"` for a simple random sample and
#' `type = "jkn"` for a stratified or multi-stage design; the replicate
#' count follows from the design. No jackknife variant converges to the
#' correct variance for a quantile. For delete-a-group jackknife on a
#' `survey_nonprob` design, use `type = "grouped"` and set `replicates`
#' (Valliant 2020).
#'
#' **BRR** (`method = "brr"`) needs exactly two PSUs per stratum, and
#' uses a Hadamard matrix to keep the half-samples balanced across strata
#' (Fay 1984). Unlike the jackknife, it is proven for nonlinear
#' estimators and quantiles. The default `rho = 0` gives classic BRR,
#' which zeroes one PSU per stratum in each replicate; set `rho > 0` for
#' Fay's variant, which keeps every weight positive and so keeps ratio
#' statistics defined (Dippo, Fay & Morganstein 1984).
#'
#' **Generalized bootstrap** (`method = "generalized-bootstrap"`) draws
#' random weight multipliers that reproduce a target variance estimator
#' you name through `variance_estimator` (Beaumont & Patak 2012). It is
#' the general-purpose choice for designs the named methods do not fit,
#' and the documented approach for Poisson sampling. Use `tau` to clear
#' negative multipliers; the variance then carries a matching \eqn{\tau^2}
#' correction. Beaumont & Patak recommend at least 750 replicates.
#'
#' **Generalized replication** (`method = "generalized-replicate"`) is
#' the deterministic counterpart. It decomposes the same target variance
#' matrix into components and turns each into a weight perturbation
#' (Fay 1989). Its balanced construction extends BRR's logic beyond the
#' two-PSU case. There is no `replicates` argument; use `max_replicates`.
#'
#' **Successive difference replication**
#' (`method = "successive-difference"`) estimates variance by comparing
#' each unit with its neighbour in sort order, which is the right
#' comparison for a systematic sample (Fay & Train 1995; Ash 2014). The
#' row order of the data is part of the method: re-sorted rows give a
#' different and incorrect answer, with no error raised.
#'
#' For full algorithm documentation, parameter behavior, and
#' replicate-weight handling, see [create_bootstrap_weights()],
#' [create_jackknife_weights()], [create_brr_weights()],
#' [create_gen_boot_weights()], [create_gen_rep_weights()], and
#' [create_sdr_weights()].
```

---

## Assumptions

- **The design is known, or a reference sample stands in for it.** Every method
  except the grouped jackknife and the quasi-randomization bootstrap needs real
  inclusion probabilities.
- **With-replacement PSU selection.** JK1, JKn, and BRR are built on it. Without
  a finite-population correction, a large sampling fraction makes them
  conservative (Valliant, Brick & Dever 2008 §2).
- **Smooth statistics.** Totals, means, and ratios are covered. Quantiles are
  covered only by the bootstrap and BRR. Other non-smooth statistics are an open
  question that Dippo, Fay & Morganstein (1984) §2 explicitly decline to settle.
- **Adjustment steps replay inside every replicate.** A nonresponse or
  calibration step applied once to the full-sample weight, then scaled, loses
  the variance it contributes.
- **The sort order survives, for SDR only.** SDR reads it; the other five
  methods ignore it.
- **Independence given covariates, for the non-probability methods.** Untestable
  in practice, and the function cannot check it.

---

## Cross-paper conflicts

- **Bootstrap against jackknife for non-probability samples: which is on firmer
  ground?** Elliott & Valliant (2017) say model-based bootstrap theory "has not
  been worked-out," which reads as a point for the jackknife. The same paper says
  the bootstrap "should also be consistent for estimating the variance of
  estimated quantiles, unlike the jackknife," which reverses it.
  **Resolution:** both hold, for different estimands. Prefer the jackknife for a
  prediction-type total or mean. Prefer the bootstrap for a quantile. The
  archived group-jackknife doc records the first half of this and omits the
  second; the omission is worth fixing there.
- **Scale factor $(G-1)/G$ against $(n-1)/n$.** Valliant (2020) uses the first,
  Valliant (2009) the second. **Resolution:** the same formula at different
  units of deletion. For the grouped profile the factor is always $(G-1)/G$ with
  $G$ the number of groups.
- **SD1 against SD2 inside Ash (2014).** §3 says more connected loops make the
  estimator "act more like SD1, which generally has less bias and variance than
  SD2." §4 says "SD1 usually has larger biases and RMSEs than SD2" — the
  opposite. **Resolution:** §3 is right and §4 is a wording error in the source.
  Ash's own Table A2 shows SD1 RMSE at or below SD2's throughout (0.921 against
  2.008; 0.049 against 0.176). Do not propagate the §4 sentence. This matters
  beyond SDR, because `"SD1"` and `"SD2"` are the defaults for
  `create_gen_boot_weights()` and `create_gen_rep_weights()`.
- **Doubly robust variance runs high under the grouped jackknife, and no source
  explains it.** Valliant (2020) Table 8. **[UNRESOLVED]** Document it as a known
  empirical limitation. The estimates are slightly conservative.
- **Bootstrap endorsement against bootstrap caveat.** Wu (2022) and Chrostowski
  et al. recommend the bootstrap for mass-imputation and doubly robust
  estimators without repeating Elliott & Valliant's theory caveat.
  **Resolution:** carry the caveat. Simulation support is not a proof.

---

## Code and literature gaps

Things the papers cannot tell a doc author, and the code can.

1. **`create_group_jackknife_weights()` does not exist.** Use
   `create_jackknife_weights(type = "grouped")`.
2. **`plans/error-messages.md` was stale on this family — fixed 2026-08-28.**
   12 live rows named the non-existent function (8 errors, 4 warnings). Every
   class is real; the thrower is `create_jackknife_weights()`, directly or
   through `jackknife-dagjk-utils.R`. The struck-through RETIRED rows keep the
   old name on purpose, as a record of what was true when they were retired.
3. **Two error classes in that plan existed nowhere in `R/` — removed
   2026-08-28.** They were `surveywts_error_replicates_required_for_jkn` and
   `surveywts_error_jackknife_type_unsupported_for_nonprob`, both keyed to a
   `type = "random-groups"` value that is not an accepted value. The accepted
   values are `"jkn"`, `"jk1"`, and `"grouped"`.
4. **`tau = "auto"` is documented but unimplemented in surveywts.**
5. **Six of the 12 `variance_estimator` options have no support in the mapped
   papers** — `"Ultimate Cluster"`, `"Deville-1"`, `"Deville-2"`,
   `"Deville-Tille"`, `"BOSB"`, `"Beaumont-Emond"`.
6. **The gen-boot default of 500 replicates sits below the sourced floor of
   750.** Not a defect, but the `@details` block should give the recommendation.
7. **`type = "hybrid"` on the bootstrap is a dead option** that always errors.
8. **No function in this family has an `@details` tag.** The dispatcher also has
   no `@references`; it defers to the siblings through `@seealso`.

Items 2 and 3 are fixed, and so are the citation corrections in
`.claude/reference-map.yaml`. Items 1, 4, 5, 6, 7, and 8 all live in `R/` and
stay open — they need a branch that may touch package source, followed by
`devtools::document()` and `devtools::check()`.

---

## Reference mapping

- Elliott & Valliant (2017) §"Estimation Using Pseudo-Weights" → pseudo-weights
  and the point estimator must be recomputed in every replicate.
- Elliott & Valliant (2017) §"Variance Estimation for Prediction Estimators" →
  bootstrap is consistent for quantiles, unlike the jackknife; model-based
  bootstrap theory is not worked out.
- Wu (2022) §6.1, §6.3 → bootstrap preferred where an analytic variance is
  intractable or absent; stratified multi-stage reference samples are a known
  open problem.
- Wu (2022) §7.2 → zero-coverage units limit what any resampling can recover.
- Chrostowski et al. §2.2, Eq. 5 → the bootstrap variance formula, and the
  `"chrostowski"` centering option.
- Chrostowski et al. §2.4 → bootstrap recommended for doubly robust estimators.
- Valliant, Dever & Kreuter (2018) §15.4.1, Eq. 15.10-15.12 → JK1 and JKn
  formulas, weight rules, and the design-determined replicate count.
- Valliant, Dever & Kreuter (2018) §15.4.1 → no jackknife variant converges for
  quantiles; BRR is proven for them; no good reason to use JK2.
- Valliant, Dever & Kreuter (2018) §15.3.2 Eq. 15.9, §15.5.2 Table 15.2 →
  degrees of freedom rule, and the instability of the variance estimate at low
  degrees of freedom.
- Valliant, Dever & Kreuter (2018) §15.5.3, §15.6 → remedies for a single-PSU
  stratum.
- Valliant, Brick & Dever (2008) §2 → finite-population-corrected jackknife for
  a non-negligible sampling fraction.
- Valliant (2020) Eq. 3, §2.1.4 → grouped jackknife formula and $(G-1)/G$ scale.
- Valliant (2020) §2.4 → no consistency proof for the doubly robust replicate.
- Valliant (2020) §3.2.1, §3.3, Table 8 → $G = 50$ in simulation; the positive
  standard-error bias for doubly robust estimators.
- Valliant (2009) §5, Eq. 22 → the delete-one-cluster shortcut, and its limit to
  linear working models.
- Fay (1984) §2, Eq. 2.12-2.18 → BRR as the $r=2$ special case of the
  random-group method; both centering forms; the overestimation property.
- Fay (1984) §3, Theorem 1 → any sums-of-squares variance estimator has a
  resampling plan. The licence for generalized methods.
- Fay (1989) §2, Eq. 2.1-2.4 → generalized replication by decomposition of
  $C(s)$; the Hadamard construction as BRR's logic generalized.
- Fay (1989) §3, Eq. 3.1 → Fay's modified BRR: factors 1.5 and 0.5, constant
  $4/k$; $k=48$ or $k=100$ in practice.
- Fay (1989) §3.1, §3.2 → Durbin's scheme avoids negative coefficients; zero
  components excluded when collapsing strata.
- Dippo, Fay & Morganstein (1984) §1 → the practical case for replication over
  linearization.
- Dippo, Fay & Morganstein (1984) §2, Eq. 2.3-2.4 → the $d_r$ coefficient family
  common to BRR and gen-rep; non-smooth statistics left open.
- Dippo, Fay & Morganstein (1984) §4 → positive replicate factors keep ratio
  statistics defined.
- Dippo, Fay & Morganstein (1984) §5.4 → BRR's two-PSU requirement and the
  pseudo-stratum workaround.
- Beaumont & Patak (2012) §2, Eq. 1-2 → the quadratic form; Horvitz-Thompson and
  Sen-Yates-Grundy as targets, with their limits.
- Beaumont & Patak (2012) §3, Conditions 1-2 → the two moment conditions on the
  multipliers.
- Beaumont & Patak (2012) §3.3, Table 1 → at least 750 replicates.
- Beaumont & Patak (2012) §3.4 → the Rao-Wu bootstrap as a special case.
- Beaumont & Patak (2012) §4, Eq. 12 → the diagonal target under Poisson
  sampling.
- Beaumont & Patak (2012) §6, Eq. 26-27, §7 → `tau` rescaling, the $\tau^2$
  correction, and the 294.54% to 28.15% bias illustration.
- Beaumont & Patak (2012) §9 → the three-point test for a valid target, and the
  overestimation caused by repairing an invalid one.
- Bellhouse (1985) §2.1, §5 → a catalogue of named variance formulas per design.
  Background only; the paper never discusses bootstrap weights.
- Ash (2014) §1.1 → SD1 and SD2 definitions. These are the `variance_estimator`
  defaults for gen-boot and gen-rep.
- Ash (2014) §2.1, Theorem 1 → the Hadamard requirement, the row-pairing rule,
  and the sort-order requirement.
- Ash (2014) §2.1, Theorem 2 → the cycling construction when the Hadamard order
  falls below $n$.
- Ash (2014) §2.1 Example 2 → CPS uses $k=160$ for the systematic PSUs and BRR
  for the rest.
- Ash (2014) §3, Table A2 → SD1 and SD2 far outperform a sort-blind estimator
  under trend or periodic structure.
- Fay & Train (1995) §2.1 → the CPS sort variable, chosen for its link to the
  outcome.
- Fay & Train (1995) §2.2 → the original replicate factor, and the warning about
  the circular first-against-last term.

---

## Citation verification

Every citation below was checked against the paper's own title page or masthead.
**Four needed correction, and one cannot be checked at all.** All four
corrections were applied to `.claude/reference-map.yaml` on 2026-08-28; the
verdicts below describe what was found there before the fix.

| Source | Verdict |
|---|---|
| Elliott & Valliant (2017) | **VERIFIED.** "Statistical Science 2017, Vol. 32, No. 2, 249-264," DOI 10.1214/16-STS598. |
| Wu (2022) | **VERIFIED.** "Survey Methodology, December 2022, Vol. 48, No. 2, pp. 283-311." |
| Chrostowski et al. (2025) | **WRONG — see below.** |
| Kolenikov (2014) | **WRONG — see below.** |
| Fay (1984) | **VENUE INCOMPLETE.** Title and author match. The venue should name the section: "Proceedings of the Section on Survey Research Methods, American Statistical Association," per Fay (1989)'s own reference list. Pages 495-500 are corroborated by that same list, not by the extract's own front matter. |
| Fay (1989) | **PAGES WRONG — see below.** Venue also incomplete, as above. |
| Dippo, Fay & Morganstein (1984) | **VENUE INCOMPLETE**, pages verified. In-document markers 492 and 493 fall inside 489-494, and Fay (1989) cites the same range. Venue needs the section name. |
| Ash (2014) | **VERIFIED.** "Survey Methodology, June 2014, Vol. 40, No. 1, pp. 47-59," Statistics Canada Catalogue no. 12-001-X. |
| Fay & Train (1995) | **CORROBORATED INDIRECTLY.** Title and authors match. The paper's own front matter says only "Presented at the American Statistical Association Conference Annual Meeting in Orlando, Florida on August 13-17, 1995." The venue and pages in our citation appear verbatim in Ash (2014)'s reference list, not in the paper itself. |
| Beaumont & Patak (2012) | **VERIFIED.** "International Statistical Review (2012), 80, 1, 127-148," DOI 10.1111/j.1751-5823.2011.00166.x. |
| Bellhouse (1985) | **VERIFIED, pages added.** "Journal of Official Statistics Vol. 1, No. 3, 1985, pp. **323-329**." Our citation omits the page range. |
| Valliant, Dever & Kreuter (2018) | **NOT SELF-VERIFYING.** The chapter extract has no front matter; it opens at "Chapter 15 Variance Estimation." Authors, year, and publisher cannot be confirmed from the document. Section 15.5 exists and covers the cited topic. |
| Valliant, Brick & Dever (2008) | **VERIFIED.** "Journal of Official Statistics, Vol. 24, No. 3, 2008, pp. 469-488." The byline reads "Vaillant" but the running header throughout reads "Valliant" — an OCR artifact, not a name discrepancy. |
| Wolter (2007) | **NOT CHECKABLE.** Not in the knowledge base. See "Unverified sources". |

### Correction 1 — Chrostowski et al. is largely fabricated

`.claude/reference-map.yaml` carries, under both `create_replicate_weights` and
`create_bootstrap_weights`:

> Chrostowski, M.J., Guzman, C.A. and Malm, L. (2025). Variance estimation for
> non-probability surveys. Journal of Survey Statistics and Methodology
> (forthcoming).

The paper's own title page reads:

> nonprobsvy – An R package for modern methods for non-probability surveys.
> Łukasz Chrostowski (Analyx), Piotr Chlebicki (Stockholm University), Maciej
> Beręsewicz (Poznań University of Economics and Business; Statistical Office in
> Poznań).

"Guzman, C.A." and "Malm, L." are not authors of this paper. The title and the
venue are both invented. Only the first author's surname is right, and even the
initial is wrong. The filename `chrostowski_2025_nonprobsvy.md` matches the real
title, which corroborates the extract.

**Corrected form, with what remains unverified marked:**

> Chrostowski, Ł., Chlebicki, P. and Beręsewicz, M. nonprobsvy — An R package
> for modern methods for non-probability surveys. *[Year and venue not stated in
> the knowledge-base copy; confirm before publishing.]*

### Correction 2 — Kolenikov (2014) has the right author and nothing else

`reference-map.yaml` carries, under the same two functions:

> Kolenikov, S. (2014). Calibrating variance estimation with proxy variables.
> Survey Methodology 40(1), 21-38.

The paper's own masthead reads:

> The Stata Journal (2014) 14, Number 1, pp. 22-59. Calibrating survey data
> using iterative proportional fitting (raking). Stanislav Kolenikov, Abt SRBI.

Title, journal, volume, and pages are all wrong. The filename
`kolenikov_2014_raking.md` matches the real title.

**Corrected form:**

> Kolenikov, S. (2014). Calibrating survey data using iterative proportional
> fitting (raking). *The Stata Journal*, 14(1), 22-59.

Note also that this paper is about raking, not about bootstrap variance. Its
only bearing on this family is a passing pointer in §1.5 that variance
estimation with calibrated data "usually proceeds along the lines of replicate
variance-estimation methods." It is weak support for `create_bootstrap_weights()`
and should probably be dropped from that function's `@references`.

### Correction 3 — Fay (1989)'s page range belongs to Fay (1984)

`reference-map.yaml` gives **495-500 for both** Fay (1984) and Fay (1989). Two
different papers five years apart cannot share a page range. The 1989 extract
carries no page numbers of its own, and 495-500 is the range that Fay (1989)'s
own reference list assigns to the 1984 paper.

**Resolution:** 495-500 belongs to Fay (1984) only. Fay (1989)'s true range is
not recoverable from the knowledge base. Confirm it against the printed
Proceedings before it enters `@references`; do not carry the duplicated range
forward.

### Correction 4 — Valliant (2020) is cited under two venues in one file

Not a replicate-family defect, but found during this work and worth recording.
`reference-map.yaml` points two functions at the same file,
`valliant_2020_comparing_alternatives_nonprobability.md`, with different venues:

- under `ipw`: "Survey Methods: Insights from the Field 16(1)"
- under `create_group_jackknife_weights`: "Journal of Survey Statistics and
  Methodology 8, 231-263"

The extract's masthead reads "Journal of Survey Statistics and Methodology
(2020) 8, 231-263." The second is right; the `ipw` entry's venue is wrong.

---

## Unverified sources

**Wolter, K. (2007). Introduction to Variance Estimation. New York: Springer.**

Mapped to `create_replicate_weights()` and `create_jackknife_weights()`. Not in
the knowledge base. It is **not dropped** — it is recorded here as unverified.

No formula or gotcha in this doc rests on Wolter. Every one comes from a paper
that was read. Wolter appears only as a citation those papers make in passing:

- The general delete-one jackknife formula (Valliant, Brick & Dever 2008 §2,
  citing "Krewski and Rao 1981, Expression 2.4; Wolter 2007, Section 4.5").
- Supporting theory for grouping and replication methods (VBD 2008 §1).
- Collapsing single-PSU strata, and the bias of the collapsed-stratum variance
  (VDK 2018 §15.5.3, citing Wolter 2007 §2.5).
- The formal definition of a linear estimator (VDK 2018 §15.2, citing Wolter
  2007 Chapter 1).
- Consistency of the grouped and ungrouped jackknife under the
  pseudo-probability distribution (Valliant 2020 §2.1.4, citing Krewski and Rao
  1981 and Wolter 2007).

One existing roxygen reference leans on it directly:
`create_jackknife_weights.R:38-43` describes `mse = TRUE` as the "Wolter 2007
v_4 form" and `mse = FALSE` as the "v_1 form." Those labels are **not verified**.
Either obtain the book, or restate the two forms in the package's own words —
they are fully described by VDK 2018 Example 15.10 without the Wolter labels.

Two further sources are only partly checkable. The Valliant, Dever & Kreuter
(2018) chapter extract has no front matter, so its authors, year, and publisher
rest on the filename alone. The Valliant (2009) extract confirms the title,
author, volume, chapter number, and DOI, but never names the editors
"Pfeffermann, D. and Rao, C.R." that our citation supplies.

---

## Citations

Ready for `@references` **after** the four corrections above are applied. Each
entry is the form this doc verified, not the form currently in
`reference-map.yaml`.

Ash, S. (2014). Using successive difference replication for estimating
variances. *Survey Methodology*, 40(1), 47-59. Statistics Canada.

Beaumont, J.-F. and Patak, Z. (2012). On the generalized bootstrap for sample
surveys with special attention to Poisson sampling. *International Statistical
Review*, 80(1), 127-148.

Bellhouse, D.R. (1985). Computing methods for variance estimation in complex
surveys. *Journal of Official Statistics*, 1(3), 323-329.

Chrostowski, Ł., Chlebicki, P. and Beręsewicz, M. nonprobsvy — An R package for
modern methods for non-probability surveys. [Year and venue unconfirmed.]

Dippo, C., Fay, R.E. and Morganstein, D. (1984). Computing variances from
complex samples with replicate weights. *Proceedings of the Section on Survey
Research Methods*, American Statistical Association, 489-494.

Elliott, M.R. and Valliant, R. (2017). Inference for nonprobability samples.
*Statistical Science*, 32(2), 249-264.

Fay, R.E. (1984). Some properties of estimates of variance based on replication
methods. *Proceedings of the Section on Survey Research Methods*, American
Statistical Association, 495-500.

Fay, R.E. (1989). Theory and application of replicate weighting for variance
calculations. *Proceedings of the Section on Survey Research Methods*, American
Statistical Association. [Page range unconfirmed; not 495-500.]

Fay, R.E. and Train, G.F. (1995). Aspects of survey and model-based postcensal
estimation of income and poverty characteristics for states and counties. *Joint
Statistical Meetings, Proceedings of the Section on Government Statistics*,
154-159.

Kolenikov, S. (2014). Calibrating survey data using iterative proportional
fitting (raking). *The Stata Journal*, 14(1), 22-59.

Valliant, R. (2009). Model-based prediction of finite population totals. In
Pfeffermann, D. and Rao, C.R. (Eds.), *Handbook of Statistics, Sample Surveys:
Inference and Analysis* (Vol. 29B, Chapter 26). Elsevier.

Valliant, R. (2020). Comparing alternatives for estimation from nonprobability
samples. *Journal of Survey Statistics and Methodology*, 8, 231-263.

Valliant, R., Brick, M. and Dever, J. (2008). Weight adjustments for the grouped
jackknife variance estimator. *Journal of Official Statistics*, 24(3), 469-488.

Valliant, R., Dever, J. and Kreuter, F. (2018). *Practical Tools for Designing
and Weighting Survey Samples*, 2nd edition. New York: Springer. Chapter 15.

Wolter, K. (2007). *Introduction to Variance Estimation*. New York: Springer.
[Not in the knowledge base. Unverified.]

Wu, C. (2022). Statistical inference with non-probability survey samples.
*Survey Methodology*, 48(2), 283-311.
