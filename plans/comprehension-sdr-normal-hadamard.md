# Comprehension — sdr-normal-hadamard

Standards read:

- `.claude/standards/function-documentation.md`
- `.claude/standards/surveywts-conventions.md`
- `.claude/standards/testing-standards.md`
- `.claude/standards/testing-surveywts.md`
- `.claude/standards/engineering-preferences.md`

## Problem

`create_sdr_weights()` builds successive difference replication weights through
`svrep::as_sdr_design()`. It forwards three arguments: `replicates`,
`sort_variable`, and `mse` (`R/create_sdr_weights.R:130-135`). It does not
forward `use_normal_hadamard`, so the back end always runs at the svrep default
`FALSE`. On that path svrep starts from a fixed 4-by-4 non-normal Hadamard
matrix and doubles it until the order reaches the requested count, so the only
reachable orders are 4, 8, 16, 32, 64, 128, 256. A caller who asks for 50
replicates gets 64 columns. The `TRUE` path draws the matrix from
`survey::hadamard()`, which supplies a far finer grid of orders, so the same
request gives 56, and a request for 20 gives exactly 20. The finer grid costs
inactive replicates: a replicate whose factors all equal 1. The count is not
capped. It rises as the PSU count falls relative to the Hadamard order. The
user must decide whether to add `use_normal_hadamard` as a named argument, or
to change the default, or both. This document lays out the evidence, and does
not make that choice.

## Formulas

### Symbol binding

| Symbol | Bound to |
|---|---|
| `n` | Number of first-stage units after `svrep:::compress_design()`. For a design with `ids = ~1` this is `nrow(data@data)`. |
| `replicates` | The `create_sdr_weights()` argument; svrep's `target_number_of_replicates`. |
| \(R\) | The Hadamard order = the returned column count = `length(result@variables$repweights)`. |
| \(H\) | The \(R \times R\) Hadamard matrix in \(\pm 1\) form. Satisfies \(H H^{\top} = R I_R\). |
| \((a_i, b_i)\) | The two Hadamard row indices assigned to unit \(i\) by `svrep:::assign_hadamard_rows()`. |
| \(f_{ir}\) | Replicate factor for unit \(i\), replicate \(r\). One cell of `result$repweights`. |
| \(w_i\) | The base weight; the column named by `data@variables$weights`. |
| \(4/R\) | The variance scale; `result@variables$scale`. |

### F1 — Order selection, `use_normal_hadamard = FALSE`

svrep starts from the fixed non-normal matrix

\[
H_4 = \begin{pmatrix}
 1 & -1 &  1 &  1\\
-1 & -1 & -1 &  1\\
 1 & -1 & -1 & -1\\
 1 &  1 & -1 &  1
\end{pmatrix}
\]

and applies the Sylvester doubling
\(H \mapsto \begin{pmatrix} H & H \\ H & -H\end{pmatrix}\)
while `ncol(H) < replicates`. Therefore

\[
R = 4 \cdot 2^{k}, \qquad
k = \max\left(0,\ \left\lceil \log_2 \frac{\texttt{replicates}}{4} \right\rceil\right).
\]

### F2 — Order selection, `use_normal_hadamard = TRUE`

svrep calls `survey::hadamard(replicates - 1)` and converts the 0/1 result with
\(H \mapsto 2H - 1\). `survey::hadamard(m)` returns a matrix of order at least
\(m+1\). It first looks for a stored matrix in the half-open band
\((m - (m \bmod 4),\ m - (m \bmod 4) + 4]\); if none, it picks the starting size
whose smallest power-of-two multiple is closest to \(m\), tries the Paley
construction, and falls back to repeated doubling of a stored matrix. There is
no closed form. The reachable orders are given in §Q6.

### F3 — Replicate factor

\[
f_{ir} = 1 + \frac{H[a_i, r] - H[b_i, r]}{2^{3/2}}.
\]

Entries of \(H\) are \(\pm 1\), so
\(f_{ir} \in \{1 - 2^{-1/2},\ 1,\ 1 + 2^{-1/2}\}\).
All three values are strictly positive, so the replicate weights \(w_i f_{ir}\)
stay strictly positive whenever \(w_i > 0\). This holds on both paths.

With a finite population correction, svrep shrinks the factors toward 1:
\(f_{ir} \mapsto 1 + c_h (f_{ir} - 1)\) with
\(c_h = \sqrt{1 - n_h/N_h}\). Positivity survives that.

### F4 — Variance estimator (`mse = TRUE`, the surveywts default)

\[
\hat{V} = \frac{4}{R} \sum_{r=1}^{R}
\left(\hat{\theta}^{(r)} - \hat{\theta}_{\text{full}}\right)^2 .
\]

`survey::svrepdesign()` sets the scale from the column count:
`scale <- 4/ncol(repweights)`, for `type %in% c("ACS", "successive-difference")`.
So \(R\) is the full order, including any inactive replicate.

### F5 — The SD2 identity, and why it does not depend on the matrix family

Write \(z_i = w_i y_i\) and \(D = F - 1\) (an \(n \times R\) matrix). For a total,
\(\hat{\theta}^{(r)} - \hat{\theta}_{\text{full}} = \sum_i D_{ir} z_i\), so
\(\hat{V} = \frac{4}{R} z^{\top} D D^{\top} z\).

Row orthogonality gives \(\sum_r H[u,r] H[v,r] = R \cdot \mathbb{1}\{u = v\}\).
Substituting F3,

\[
(D D^{\top})_{ij} = \frac{R}{8}\left(
\mathbb{1}\{a_i = a_j\} - \mathbb{1}\{a_i = b_j\}
- \mathbb{1}\{b_i = a_j\} + \mathbb{1}\{b_i = b_j\}\right),
\]

\[
\frac{4}{R} D D^{\top} = \frac{1}{2}\left(
\mathbb{1}\{a_i = a_j\} - \mathbb{1}\{a_i = b_j\}
- \mathbb{1}\{b_i = a_j\} + \mathbb{1}\{b_i = b_j\}\right).
\]

The diagonal is 1, because \(a_i \neq b_i\). A chained neighbouring pair
(\(b_i = a_{i+1}\)) gives \(-1/2\). That is the SD2 quadratic form.

Two consequences matter here.

1. The only property of \(H\) the identity uses is \(H H^{\top} = R I\). Both
   matrix families have it. The family therefore does not enter the identity.
2. The scale \(4/R\) uses the full order. An inactive column contributes a zero
   term to the sum over \(r\), so counting it in \(R\) is exactly right, not an
   approximation.

The identity is exact only while every Hadamard row index is used by the units
it should be. See §Q3 for the case where `n` exceeds the available rows.

## Answers to the six questions

### Q1 — Order selection on each path, and the contradiction in the help page

**The svrep help page for `as_sdr_design()` is wrong.** Its `@param replicates`
says the `FALSE` path gives "the smallest *power* of 4 that is greater or equal
to the specified value of `replicates`". Powers of 4 are 4, 16, 64, 256. The
code gives 4, 8, 16, 32, 64, 128, 256 — powers of 2 from 4 up.

The line that settles it is the doubling loop in
`svrep:::make_sdr_replicate_factors()`, `R/successive-difference-replication.R`:

```r
H_A <- H_4
while (ncol(H_A) < target_number_of_replicates) {
  H_A <- rbind(cbind(H_A, H_A),
               cbind(H_A, -H_A))
}
```

Each pass doubles the order. The loop exits at the first order that is not below
the target. That is \(4 \cdot 2^k\), not \(4^k\).

svrep's own two help pages disagree with each other. The `@param
target_number_of_replicates` block on `make_sdr_replicate_factors()` says the
actual count "will be \(4 \times 2^k\) for some integer \(k\)", which matches
the code. The `as_sdr_design()` page is the one in error.

The `TRUE` path is one line in the same function:

```r
H_A <- survey::hadamard(target_number_of_replicates - 1)
H_A <- 2*H_A - 1
```

so the order is whatever `survey::hadamard()` supplies for `replicates - 1`.

### Q2 — The inactive replicates

**How many. Measured: the count is not capped. It rises as the PSU count falls
relative to the Hadamard order.** The trace predicted exactly one on the `TRUE`
path. Two measured runs disprove that, in two different ways.

The first run used a design with singleton PSUs (`ids = ~1`), 400 rows and so
400 PSUs. There the PSU count is far above every order tested, and the count is
zero or one: `use_normal_hadamard = TRUE` gives one inactive replicate at orders
4, 8, 12, 16, 20, 24, 32, 40, 44, 48, 60, 64, 104 and 128, and **zero** at
orders 28, 36 and 56. So the count is not always one.

The second run used the clustered design
`make_taylor_design(n = 500L, n_strata = 4L, psus_per_stratum = 5L, seed = 42L)`
— 500 rows in 20 PSUs. There the count goes above one:

| Requested | Order | Inactive replicates |
|---|---|---|
| 20 | 20 | 1 |
| 32 | 32 | 1 |
| 40 | 40 | 2 |
| 64 | 64 | 2 |
| 128 | 128 | 4 |

The `FALSE` path gives zero at every order measured, on both designs.

So the user-facing statement must be "the normal-matrix path **may** produce
inactive replicates", never "produces one" and never "one at most".

From F3, replicate \(r\) is inactive when column \(r\) of \(H\) takes the same
value at rows \(a_i\) and \(b_i\) for every unit. The row assignment uses as
many Hadamard rows as there are PSUs. Any column of \(H\) that is constant
across those rows makes \(r\) inactive for every unit. An all-one column is one
such column, and it is present at most once — that is what the trace counted.
Fewer PSUs relative to the order leaves more columns constant across the rows
in use, so the count rises.

The reason the trace over-predicted at orders 28, 36 and 56:
`survey::hadamard()` does not always return the matrix in normal form.
`survey::paley()` returns `cbind(1, rbind(1, m))`, whose first row and column
are all ones, but the doubling and the stored matrices do not all preserve that
form, and `is.hadamard(..., full.orthogonal.balance = TRUE)` does not require an
all-one first column of the matrix svrep ends up using.

On the `FALSE` path there are none. No column of \(H_4\) is constant, and
Sylvester doubling maps a column \(c\) to \([c; c]\) and \([c; -c]\), neither of
which is constant when \(c\) is not.

**Counted in R?** Yes. `survey::svrepdesign()` sets
`scale <- 4/ncol(repweights)` and `ncol` is the full order. The inactive columns
are among the columns counted.

**Unbiased?** Yes, and the counting is not a compromise. F5 shows an inactive
column contributes a zero term to the sum over \(r\), while the orthogonality
identity that produces the SD2 quadratic form runs over all \(R\) columns
including the inactive ones. Dropping the dead columns and rescaling to
\(4/(R - k)\) would break the identity, not repair it.

svrep says the same in words on the `as_sdr_design()` help page: "Inactive
replicates are perfectly valid for variance estimation, though some users may
find them confusing." svrep also ships `add_inactive_replicates()`, so it treats
inactive replicates as a deliberate and valid device.

### Q3 — Does the normal-matrix path still give SD2?

**On the identity: yes, the family does not matter.** F5 uses only
\(H H^{\top} = R I\), which both families satisfy. The row assignment call is
byte-for-byte identical on the two paths — `make_sdr_replicate_factors()` calls
`assign_hadamard_rows(n, hadamard_order, number_of_cycles = ceiling(n /
hadamard_order), use_first_row = TRUE, circular = TRUE)` regardless of
`use_normal_hadamard`. Only `H_A` changes. So the Ash "RA1" row assignment and
the SD2 target are the same on both paths.

**Measured, and it settles the family question for a linear statistic.** At a
given order the two paths give the *same* variance estimate for a total, to
every digit printed. On a 500-row design with singleton PSUs, `svytotal(~y)`
variance: order 64 gives 2109.308897 on both paths; order 128 gives 2405.257833
on both; order 256 gives 2306.438945 on both. Order 128 on the `TRUE` path
carries an inactive replicate and the `FALSE` path carries none, and the total
variance is still identical. Re-measured on the clustered design
`make_taylor_design(n = 500L, n_strata = 4L, psus_per_stratum = 5L, seed = 42L)`
at `mse = TRUE`, the total variance is 742.9939387275 on both paths at orders
20, 32, 64 and 128.

**The family is variance-neutral for a linear statistic only.** A total is
linear in the weights, so the orthogonality identity in F5 applies exactly and
the inactive columns contribute zero. A mean is a ratio. Its denominator is the
replicate weight sum, which varies by replicate, and the inactive replicates
enter that ratio. The two paths carry different numbers of inactive replicates,
so the two mean variances differ. Measured on the same clustered design,
`svymean(~y)` variance:

| Order | `FALSE` | `TRUE` |
|---|---|---|
| 20 | 0.002537678051 | 0.002537864713 |
| 32 | 0.002537678051 | 0.002549751870 |
| 64 | 0.002537678051 | 0.002549751870 |
| 128 | 0.002537678051 | 0.002549751870 |

A gap of 0.48%. Any statement of variance-neutrality must name a total, or
another linear statistic.

**Measured, and it settles the exactness question too: SDR is approximate, not
exact, SD2 when `n` exceeds the order.** Against an SD2 target of 2141.811092
(from `as_gen_boot_design(variance_estimator = "SD2", exact_vcov = TRUE)`,
n = 500):

| Order | SDR variance | Ratio to SD2 | Cycles |
|---|---|---|---|
| 20 | 1831.838004 | 0.855 | 25 |
| 32 | 2879.098475 | 1.344 | 16 |
| 56 | 2071.236176 | 0.967 | 9 |
| 64 | 2109.308897 | 0.985 | 8 |
| 104 | 2192.524435 | 1.024 | 5 |
| 128 | 2405.257833 | 1.123 | 4 |
| 256 | 2306.438945 | 1.077 | 2 |

So svrep's unqualified claim of SD2 equivalence does not hold in this regime.
The departure is not monotone in the order: 64 is closer to the target than 256
is. Neither path is uniformly closer to SD2. Ash (2014) is still not read, so
the reason for the non-monotone pattern stays open; the fact of the departure no
longer does.

**Original trace-based reasoning, kept because it predicts the two regimes.**
`assign_hadamard_rows()` has two regimes:

- `n` at most the number of available rows: the assignment is a simple chain
  with a circular closure, and the SD2 identity is exact.
- `n` above that: the RA1 cycling method runs, and the assignment matrix is
  recycled when it still does not cover `n` rows. Row indices then repeat across
  non-neighbouring units, so the indicator terms in F5 fire off the SD2 pattern
  and the estimator only approximates SD2.

svrep's help asserts equivalence with no qualification: "The method of Ash (2014)
referred to as 'RA1' is used for row assignments, which means that the
replication-based variance estimates for totals will be equivalent to the SD2
variance estimator". My derivation says exact equivalence needs the first
regime. **I could not settle this.** Ash (2014) is not attached and I did not
read it. Settling it needs Ash (2014) §RA1, to see whether RA1 is claimed exact
or claimed to be the assignment that minimises the departure.

This matters for the request because `cps_2023` has roughly 10,000 rows and no
PSU or stratum columns, so `n` is roughly 10,000 and every order in 20–128 sits
in the second regime.

**Separate caveat, both paths.** The identity in F5 is for `mse = TRUE`, which
is the surveywts default. Under `mse = FALSE` the deviations are taken about the
mean of the replicate estimates. That mean does not equal the full-sample
estimate on either path, because the Hadamard row sums are not all zero. I did
not verify what `mse = FALSE` estimates.

### Q4 — Efficiency cost: R = 56 with dead columns against R = 64 with none

`n` here is the PSU count, not the row count. See §Assumptions. It is the
variable that decides which regime the caller is in.

**When `n` is at most the smaller order.** Both column counts produce exactly
the SD2 quadratic form (F5). The two variance estimates are the same number, so
the smaller order is free. Neither is more stable, because in this regime the
replicate estimator is an algebraic identity, not a resampling estimator with
its own sampling variability. The only difference is 8 fewer columns to compute,
store, and carry in `@data`. Measured, four strata, `replicates = 50`,
`mse = TRUE`, `svytotal(~y)`, 480 rows: the two paths agree to every digit at 20
PSUs and at 40 PSUs, both at or below the smaller order 56.

**When `n` exceeds the smaller order** — the case for `cps_2023`, which has no
PSU column, so `n` is roughly 10,000. The control is the cycle count
\(\lceil n/R \rceil\): 179 cycles at \(R = 56\) against 157 at \(R = 64\).
Fewer cycles means less recycling of row pairs and a closer match to SD2.
Distinct row pairs available before recycling are bounded by roughly \(R^2\):
3,080 at \(R = 56\) against 4,032 at \(R = 64\). So 64 live columns is weakly
better than 56 with dead columns, and each dead column costs one contrast on
top. Measured on the same sweep, the standard error at order 56 runs below the
standard error at order 64 by about 2% at 80 PSUs, 5% at 160 and 15% at 480.
The growth is not monotone: 240 PSUs sits at 3%.

**Conclusion.** The smaller order is free while `n` is at or below it, and it is
not a statistical win above that. What the finer grid buys is control: the
caller can get the column count they asked for, when that count is a reachable
order (20 gives 20, 128 gives 128). Do not state the smaller column count as a
saving on its own. The check a caller makes is their PSU count against the order
they would land on.

The request framing "the smaller Hadamard orders are unreachable" is accurate,
but the benefit is a finer grid of column counts, not a better estimator.

### Q5 — Interaction with `surveywts_message_replicates_rounded_up`

The current branch is at `R/replicate-utils.R:1135-1161`. It keys on the text
`"Using Hadamard matrix of order"`, reads `params$replicates`, and returns
`NULL` — silent — when `as.integer(requested)` equals `as.integer(n_rep)`.
Otherwise it emits two bullets.

What that gives on each path:

| `replicates` | `FALSE` path | `TRUE` path |
|---|---|---|
| 20 | 32 — fires | 20 — silent |
| 50 | 64 — fires | 56 — fires |
| 100 | 128 — fires | 104 — fires |
| 128 | 128 — silent | 128 — silent |

The silence rule needs no change. It already compares the request with the real
column count, so it is correct on both paths.

The **text** does need attention. The second bullet says:

> Successive difference replication builds the columns from a Hadamard matrix,
> and {n_rep} is the smallest order that fits {requested} replicates.

On the normal path that sentence is true: 56 is the smallest available order at
or above 50. On the current path it is false: 64 is returned, but 56 exists. The
accurate statement for the current path is "the smallest order of the form
\(4 \times 2^k\)". The message is therefore already inaccurate today, and it
becomes visibly inaccurate once both paths are reachable and the caller can see
the difference.

Two further facts the spec will need.

- svrep's raw text carries the alternative order as its second value: ``Using
  Hadamard matrix of order 128. If `use_normal_hadamard=TRUE`, the smallest
  possible order is 104.`` So the smaller order is available to surveywts from
  the message text.
- svrep computes it with `find_minimum_hadamard_order()`, which is
  `@keywords internal` and not exported. surveywts cannot call it without `:::`.

### Q6 — Reachable orders, 4 to 256

**`use_normal_hadamard = FALSE`.** Seven orders:

`4, 8, 16, 32, 64, 128, 256`

**`use_normal_hadamard = TRUE`.** `survey::hadamard()` builds from starting
sizes \(S\) and doubles them. \(S\) is the stored sizes `c(2, 4, 16, 28, 36)`
together with \(p+1\) for each prime \(p\) in survey's `small.primes` list (the
primes with \(p+1\) a multiple of 4). The orders those constructions can supply
in 4–256 are:

`4, 8, 12, 16, 20, 24, 28, 32, 36, 40, 44, 48, 56, 60, 64, 68, 72, 80, 84, 88,
96, 104, 108, 112, 120, 128, 132, 136, 140, 144, 152, 160, 164, 168, 176, 180,
192, 200, 208, 212, 216, 224, 228, 240, 252, 256`

The multiples of 4 in 4–256 that are **not** reachable:

`52, 76, 92, 100, 116, 124, 148, 156, 172, 184, 188, 196, 204, 220, 232, 236,
244, 248`

Read that as the set of orders the constructions can supply, not as a
target-to-order map. `survey::hadamard()` chooses with a
`which.min(sizes - n)` heuristic and a `paley()` fallback, so a given target does
not always land on the nearest reachable order. A measured target-to-order table
is still needed before the spec states a mapping.

## Measurement — what I did and did not do

**The trace has since been checked by measurement.** The agent that wrote this
document could not run R, and hand-traced the `svrep` and `survey` source. The
orchestrator then ran the traced cases. The trace was right on every order and
wrong on one count of inactive replicates; see Q2. The measured runs are below,
after the trace table.

| `replicates` | `FALSE` path | How the trace gets there | `TRUE` path | How the trace gets there |
|---|---|---|---|---|
| 20 | 32 | 4→8→16→32; 32 is the first order not below 20 | 20 | `hadamard(19)`: no stored size in (16, 20]; best fit 28; `28 - 19 = 9 > 4` so `paley(19, 28)`; `p = 19`, builds order 20 |
| 50 | 64 | 4→8→16→32→64 | 56 | `hadamard(49)`: best fit 28→56; `paley(49, 56)` returns `NULL` because `p = 59 > nmax = 56`; falls back to doubling the stored 28 once |
| 100 | 128 | 4→…→128 | 104 | `hadamard(99)`: best fit 28→112; `112 - 99 = 13 > 4` so `paley(99, 112)`; `p = 103`, builds order 104 |
| 128 | 128 | loop exits at once, 128 is not below 128 | 128 | `hadamard(127)`: best fit 2→128; `128 - 127 = 1`, not above 4, so no Paley; doubles the stored 2 six times |

All eight numbers reproduce the issue's measured table. I also traced
`replicates = 40`, which gives 64 on the `FALSE` path and 40 on the `TRUE` path
(`paley(39, 56)` takes the `(n %% 4) + 4 == (n %% 8)` branch, builds order 20
from `p = 19`, then doubles to 40). That value matters because
`tests/testthat/test-replicate-weights.R:1048` calls
`create_sdr_weights(td, replicates = 40L, sort_var = id)`.

### Measured — `cps_2023`, 9999 rows, svrep 0.9.1

`svrep::as_sdr_design()` called directly, `mse = TRUE`, `sort_variable` a row
counter. Columns, and inactive replicates in brackets:

| `replicates` | `FALSE` path | `TRUE` path |
|---|---|---|
| 20 | 32 [0] | 20 [1] |
| 40 | 64 [0] | 40 [1] |
| 50 | 64 [0] | 56 [0] |
| 100 | 128 [0] | 104 [1] |
| 128 | 128 [0] | 128 [1] |

`cps_2023` carries no PSU column, so every row is a PSU and the PSU count is far
above every order in the table. The bracketed counts hold in that regime only.
On a design with few PSUs the counts are higher; see §Q2.

Every trace prediction holds. The `replicates = 40L` case that
`tests/testthat/test-replicate-weights.R:1048` depends on gives 64 columns at
the current default, so that test does not move if the default stays `FALSE`.

### Measured — target-to-order map, 400-row design

`FALSE` path reaches only 4, 8, 16, 32, 64, 128, 256.

`TRUE` path reaches every order `survey::hadamard()` can supply. Measured
reachable orders in 4–140: 4, 8, 12, 16, 20, 24, 28, 32, 36, 40, 44, 48, 56, 60,
64, 68, 72, 80, 84, 88, 96, 104, 108, 112, 120, 128, 132, 136, 140. The
multiples of 4 that are **not** reachable in that range are 52, 76, 92, 100, 116
and 124. So the `TRUE` path still rounds up sometimes: a request for 52 returns
56.

### Still unmeasured
- A target-to-order table across the range the documentation will state.

## Gotchas

- **`...` is not checked.** `create_sdr_weights()` declares `... Must be empty`
  and never calls `rlang::check_dots_empty()` (issue #120). A caller who writes
  `create_sdr_weights(d, use_normal_hadamard = TRUE)` today has the argument
  swallowed by `...` in silence. Any test that asserts the argument reaches the
  back end must check the column count, not the absence of an error.

- **The example comment is pinned to 64.** `R/create_sdr_weights.R:63-68` says
  `replicates = 50L` returns 64 columns, and the closing comment says the
  interval comes from "the 64 replicate columns". A default change to the normal
  path makes both wrong (56). An added argument at the current default leaves
  both correct.

- **`test-backend-messages.R` pins the counts.** Line 458 asserts 128 columns at
  `replicates = 100L`; line 462 asserts silence at `replicates = 128L`. A default
  change breaks the first (104) and leaves the second correct (128 on both
  paths).

- **The rounded-up message text is already inaccurate.** See §Q5. It claims the
  returned order is the smallest that fits.

- **`find_minimum_hadamard_order()` is internal to svrep.** surveywts cannot call
  it. The alternative order is reachable only by parsing svrep's raw message
  text, which surveywts already collects.

- **A single-row design is unreachable.** `surveycore::as_survey()` rejects
  1-row data before any surveywts function runs:

  ```
  Error: `data` has only 1 row. A survey design requires at least 2 observations.
  ```

  So the `n = 1` branch of `assign_hadamard_rows()` — which closes the circle
  with `row_assignment_matrix[n, 2] <- row_assignment_matrix[1, 1]` and sets
  \(a_1 = b_1\) — cannot be reached from surveywts. A tester cannot construct
  the input. Treat it the same way as a 0-row design: unreachable, rejected by
  `surveycore::as_survey()`. Small `n` above 1, with a large order, is a softer
  form of the same degeneracy and **is** reachable.

- **Zero and NA base weights.** SDR factors multiply the base weight, so a zero
  base weight stays zero in every replicate column, and an NA stays NA.
  `test_invariants()` asserts strict positivity of the main weight column on the
  `survey_replicate` branch, so a zero weight fails there rather than in the
  method.

- **Negative replicate weights cannot occur.** F3 bounds the factors below by
  \(1 - 2^{-1/2} \approx 0.293\), and the FPC shrinks toward 1. Positive base
  weights give positive replicate weights on both paths.

- **`mse = FALSE` is a different estimand.** See the caveat at the end of §Q3.
  The inactive replicates enter the mean of the replicate estimates, so
  `mse = FALSE` behaves differently on the two paths. The size of the gap
  depends on the design: about 11–20% with singleton PSUs, about 0.04% at 20
  PSUs.

- **`replicates = 4L` is the validated floor**
  (`.validate_replicates_arg(replicates, min_val = 4L)`). Both paths supply
  order 4 there, so the floor stays reachable either way.

- **Argument placement.** Any new argument goes after `...`, next to `sort_var`
  and `mse`, to match the other `create_*_weights()` functions. Placing it before
  `...` would move `sort_var` and change positional matching for existing calls.

- **`impact.md` names a test file that does not exist.** It lists
  `tests/testthat/test-create_sdr_weights.R`. SDR tests live in
  `tests/testthat/test-replicate-weights.R` (§File Mapping in
  `testing-surveywts.md`, and confirmed on disk).

## Reference mapping

| Source | What it settles |
|---|---|
| svrep 0.9.1, `R/successive-difference-replication.R`, `make_sdr_replicate_factors()` doubling loop | The `FALSE` path gives \(4 \cdot 2^k\), not powers of 4 (§Q1). The `as_sdr_design()` help page is wrong. |
| Same file, `H_A <- survey::hadamard(target_number_of_replicates - 1)` | The `TRUE` path delegates order choice to `survey` (§Q1, §Q6). |
| Same file, the `1 + hadamard_entries %*% c(1,-1) * 2^(-3/2)` line | F3, and the positivity bound in Gotchas. |
| Same file, `assign_hadamard_rows()` call with `use_first_row = TRUE, circular = TRUE`, unchanged across paths | The row assignment does not depend on the matrix family (§Q3). |
| svrep `as_sdr_design()` help, "Details on Row Assignments" | The inactive replicate is stated and called valid (§Q2). RA1 and SD2 equivalence are claimed there (§Q3). |
| svrep `as_sdr_design()` help, "Statistical Overview" | The \(4/R\) scale, and the SD2 rather than SD1 target. |
| svrep 0.9.1, `R/hadamard-matrix-helpers.R`, `find_minimum_hadamard_order()` | The starting sizes `c(2, 4, 16, 28, 36)` and the small-prime list; the reachable-order set in §Q6; the fact that the helper is internal (§Q5). |
| survey, `R/paley.R`, `paley()` and `is.hadamard()` | The Paley construction returns a normal matrix, so the `TRUE` path always has the all-one first column (§Q2). |
| survey, `R/surveyrep.R`, `hadamard()` | The order search traced in §Measurement. |
| survey, `R/surveyrep.R`, `scale <- 4/ncol(repweights)` for `type = "successive-difference"` | The inactive replicate is counted in \(R\) (§Q2). |
| Ash (2014) | Named as the source of the RA1 row assignment and the SD1/SD2 distinction. Not read. The open question in §Q3 needs it. |
| Fay & Train (1995) | Named as the origin of the SDR method. Not read. |
| `plans/archive/replicate/decisions-replicate.md` §Q8 | The prior decision: `use_normal_hadamard` = **Hide**. The rationale in `plans/archive/replicate/spec-replicate.md:1085` is "default `FALSE` is standard", and it describes the choice as "Normal vs power-of-4 Hadamard matrix" — which repeats svrep's incorrect power-of-4 claim. The reversal therefore rests partly on a corrected fact. |
| `plans/spec-backend-message-classes.md` §7 | Where this was cut as out of scope, with the three order pairs named. |
| `plans/error-messages.md:218` | The existing row for `surveywts_message_replicates_rounded_up`. Its condition text — "The Hadamard matrix order is above `replicates`" — stays correct on both paths. |
| `.claude/standards/function-documentation.md` | `create_sdr_weights()` is Tier 3, Algorithmic: it has an `@section Algorithm` with `\deqn{}`, a published method, and required `@references`. A new argument needs a typed `@param` that states the default first, and the inactive replicate belongs in a `@section Limitations` or in `@details`, not in `@param`. |
| `.claude/standards/surveywts-conventions.md` | `@family replicate-weights`; the file is `R/create_sdr_weights.R`; the return is visible; no new class. |

## Assumptions

- **`survey`'s stored Hadamard sizes are `c(2, 4, 16, 28, 36)`.** They live in
  `sysdata.rda`, which I could not read. I took them from the comment in svrep's
  `find_minimum_hadamard_order()`. My traces reproduce all four measured counts
  from the issue, which supports the value but does not prove it.

- **The source I read matches the installed build.** `DESCRIPTION` requires
  `svrep (>= 0.9.1)` and the package cache holds `svrep_0.9.1.zip`. I read
  `R/successive-difference-replication.R` at the `v0.9.1` tag, but
  `R/hadamard-matrix-helpers.R` at `main`. The `survey` files came from the
  `cran/survey` GitHub mirror at `master`, with no version pinned. A drift in any
  of the three would change the order tables.

- **The two order rules are not the same function.**
  `make_sdr_replicate_factors()` gets its order from
  `survey::hadamard(replicates - 1)`, while the message text gets its number from
  `find_minimum_hadamard_order(replicates)`. svrep's helper is a model of the
  `survey` search, not the search itself. They agreed on all five targets I
  traced. The spec should state the rule and a measured table, not a formula.

- **`create_sdr_weights()` always passes a sort column.** When `sort_var` is
  `NULL` it writes a temporary `.row_order` column and removes it afterwards
  (`R/create_sdr_weights.R:124-136`). So svrep's `sort_variable = NULL` note
  never fires, and the sort path is the same on both Hadamard paths.

- **`n` is the compressed unit count, not the row count.** For a design with
  clusters, `svrep:::compress_design()` reduces to unique cluster combinations
  first. `cps_2023` carries no PSU column, so there `n` equals the row count.
  This is the variable that drives every result in this document. A design with
  singleton PSUs and a clustered design of the same row count give different
  inactive replicate counts (§Q2) and a different size of order trade (§Q4).
  Record the PSU count with every measurement.

- **The user's decision is not made here.** The two levers and what each rests
  on:
  - *Add the argument, keep the default `FALSE`.* No existing caller changes
    behavior. The example comment, the two pinned counts in
    `test-backend-messages.R`, and any user snapshot all stay valid. The caller
    must know the term "normal Hadamard matrix" to find the smaller orders.
  - *Change the default to `TRUE`.* Every existing caller silently gets a
    different column count and a different variance estimate. The example
    comment and one pinned test break. The dead replicate becomes the default,
    which is the thing svrep's own default avoids. In exchange, the default
    returns close to what the caller asked for.
  - *Both.* Expose and flip.

  §Q4 is the load-bearing evidence: the smaller order is a control and size win,
  not a statistical one.

## Citations

Formal records for every source read or named. Fields not findable in the
sources I read are marked `[NOT FOUND]`.

1. **Ash, S. (2014).** "Using successive difference replication for estimating
   variances." *Survey Methodology*, Statistics Canada, 40(1), 47–59.
   DOI/URL: `[NOT FOUND]`.
   Read: **no**. Taken from the citation block in svrep's
   `R/successive-difference-replication.R` and from
   `R/create_sdr_weights.R:50-52`. To settle §Q3 I would need the RA1 section
   and whether Ash claims exact SD2 equivalence when `n` exceeds the available
   Hadamard rows.

2. **Fay, R.E. and Train, G.F. (1995).** "Aspects of Survey and Model-Based
   Postcensal Estimation of Income and Poverty Characteristics for States and
   Counties." *Joint Statistical Meetings, Proceedings of the Section on
   Government Statistics*, 154–159. DOI/URL: `[NOT FOUND]`.
   Read: **no**. Taken from the same two citation blocks.

3. **U.S. Census Bureau (2022).** "American Community Survey and Puerto Rico
   Community Survey Design and Methodology, Version 3.0." Publisher: U.S. Census
   Bureau. DOI/URL: `[NOT FOUND]`.
   Read: **no**. Cited by svrep for the finite population correction handling,
   at p. 12-8. Relevant only if the spec documents FPC behavior.

4. **svrep 0.9.1 source.** Files `R/successive-difference-replication.R` (read at
   tag `v0.9.1`) and `R/hadamard-matrix-helpers.R` (read at `main`).
   `https://github.com/bschneidr/svrep`. Read 2026-09-03.

5. **svrep `as_sdr_design()` help page**, as embedded in the roxygen of file 4.
   The installed `.Rd` could not be rendered — no shell in this session.

6. **survey package source.** Files `R/paley.R` and `R/surveyrep.R`, read from
   the `cran/survey` mirror at `master`.
   `https://github.com/cran/survey`. Read 2026-09-03. Version: `[NOT FOUND]` —
   the mirror `master` branch is not tagged to the installed build.

The two roxygen `@references` entries already on `create_sdr_weights()` (Ash
2014, Fay & Train 1995) match records 1 and 2 and need no change.
