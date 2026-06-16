# Comprehension — jackknife-merge

## Problem

The merged `create_jackknife_weights()` solves a single practical problem — constructing
replicate weights for jackknife variance estimation — but across three mathematically
distinct scenarios that share a common interface. For probability samples
(`survey_taylor`), the delete-one JKn and unstratified JK1 variants drop one PSU at a
time and are handled entirely by the `survey` package; the grouped variant
(`type = "grouped"`) delegates to `svrep::as_random_group_jackknife_design()`, which
handles scale factors and weight adjustments internally. For nonprobability samples
(`survey_nonprob`), no PSU structure exists, so the delete-a-group jackknife (DAGJK)
treats randomly assigned groups as stand-ins for the absent PSU structure and requires
the full estimation pipeline — IPW propensity fitting and/or calibration — to be
replayed inside every replicate. The core implementation challenges are: (1) the mse
centering convention differs between the DAGJK path (hardcoded `mse = TRUE`, centering
on the full-sample estimate) and the probability paths (user-controlled); (2) the
extended DAGJK formula for strata with fewer PSUs than groups can produce negative
replicate weights when `n_h = 2`; (3) single-PSU strata cause divide-by-zero in all
jackknife formulas and must be caught before any computation; (4) the `replicates`
argument has a meaningful default only for the DAGJK nonprob path (50L) and is required
but has no default for the `survey_taylor` grouped path; and (5) jackknife is not
consistent for quantile variance — a limitation that must be documented regardless of
which path is used.

---

## Formulas

### JKn (stratified delete-one jackknife)

Variance estimator (Wolter 2007 eq. 4.6.4a; Valliant, Dever & Kreuter 2018 eq. 15.12):

$$
v_J(\hat{\theta}) = \sum_{h=1}^{H} \frac{n_h - 1}{n_h} \sum_{i=1}^{n_h}
  \left( \hat{\theta}_{(hi)} - \hat{\theta} \right)^2
$$

This is the `mse = TRUE` form (centers on full-sample estimate `hat_theta`). For
`mse = FALSE`, substitute the within-stratum mean `hat_theta_{(h·)} = (1/n_h) sum_i
hat_theta_{(hi)}` as the centering point per stratum (Wolter's v_1 form).

Replicate weight construction — drop PSU `i` in stratum `h` (Wolter 2007 eq. 4.6.7;
Valliant, Dever & Kreuter 2018 eq. 15.11):

$$
w_{k(hi)} = \begin{cases}
0 & \text{if unit } k \text{ is in PSU } i \text{ of stratum } h \\
\dfrac{n_h}{n_h - 1}\, w_k & \text{if unit } k \text{ is in stratum } h,\; k \neq i \\
w_k & \text{if unit } k \text{ is not in stratum } h
\end{cases}
$$

Total replicates = `sum_h n_h` (one per PSU across all strata).

Delegated to `survey::as.svrepdesign(type = "JKn", mse = mse)`.

### JK1 (unstratified delete-one jackknife)

Special case of JKn with `H = 1` (one stratum spanning the entire sample)
(Valliant, Dever & Kreuter 2018 §15.4.1 "Special Cases"; Wolter 2007 §4.3.1):

$$
v_J(\hat{\theta}) = \frac{n - 1}{n} \sum_{i=1}^{n}
  \left( \hat{\theta}_{(i)} - \hat{\theta} \right)^2
$$

Scale factor `(n-1)/n`. Weight rule: retained units scaled up by `n/(n-1)`, deleted
unit gets 0. Total replicates = `n`.

Delegated to `survey::as.svrepdesign(type = "JK1", mse = mse)`.

### DAGJK (delete-a-group jackknife for nonprobability samples)

Variance estimator (Kott 2001 eq. 1; Valliant 2020 eq. 3;
Valliant, Brick & Dever 2008 eq. 11):

$$
v_J(\hat{\theta}) = \frac{G - 1}{G} \sum_{g=1}^{G}
  \left( \hat{\theta}_{(g)} - \hat{\theta} \right)^2
$$

The centering point is the full-sample estimate `hat_theta` — not the mean of replicate
estimates. This is the only valid centering for DAGJK; `mse` is hardcoded `TRUE` on
this path. The scale factor `(G-1)/G` is constant across all groups (no group-varying
scale). When `G_success < G` (some replicates failed), the scale factor is adjusted to
`(G_success - 1) / G_success`.

**Note — v_DAGJK is a special case of v_GJ3 (Valliant, Brick & Dever 2008 §5):**
v_DAGJK arises from v_GJ3 when (1) exactly one VarStrat spans the entire sample,
(2) groups are equal in size across all design strata, and (3) sampling fractions are
negligible. The weight adjustment formula is identical to v_GJ3: `n_h / (n_h - n_hg)`
per design stratum. The scale factor differs: v_GJ3 uses a group-varying scale
`(n_hat_h - n_hat_hg) / n_hat_h` while v_DAGJK uses the constant `(G-1)/G`.

### Replicate weight construction (DAGJK)

For element `k` in PSU `j` of design stratum `h` (Kott 2001 §1, inline; eq. 1):

$$
w_{k(g)} = \begin{cases}
0 & \text{if PSU } j \text{ is in group } g \\
\dfrac{n_h}{n_h - n_{hg}}\; w_k & \text{if PSU } j \text{ is not in group } g
\end{cases}
$$

where `n_h` is the number of PSUs in design stratum `h` and `n_hg` is the number of
PSUs from stratum `h` that fall in group `g`.

Step-by-step:

1. Randomly assign PSUs to `G` groups (with `seed` for reproducibility). When
   `survey_nonprob` has no explicit PSU column, each row is treated as its own PSU.
2. For replicate `g`, set weights to zero for all rows in groups `g`; multiply weights
   of all other rows in the same stratum `h` by `n_h / (n_h - n_hg)`.
3. For the IPW path: refit the propensity model on the leave-group-out subsample and
   recompute pseudo-weights. For the calibration-only path: replay calibration on the
   leave-group-out subsample.
4. Compute `hat_theta_{(g)}` from the replicate weights.
5. Scale squared deviations from `hat_theta` (not the mean of `hat_theta_{(g)}`) by
   `(G-1)/G`. This centering is not optional; Kott (2001) §1 derives unbiasedness
   under this convention.

### Extended DAGJK (for n_h < G)

When any design stratum has `n_h < G`, the standard DAGJK produces upward-biased
variance. Kott (2001) §3, eq. 2 gives a correction:

$$
w_{k(g)}^{(E)} = \begin{cases}
w_k & \text{if no PSU from stratum } h \text{ is in group } g
       \text{ (}S_{hg} = \emptyset\text{)} \\
w_k \bigl(1 - (n_h - 1)\, Z\bigr)
  & \text{if PSU containing } k \text{ is in group } g \\
w_k (1 + Z)
  & \text{if PSU containing } k \text{ is in stratum } h,
    \text{ not in group } g
\end{cases}
$$

where:

$$
Z = \sqrt{\frac{G}{(G-1)\, n_h\, (n_h - 1)}}
$$

**Negative-weight trap:** When `n_h = 2`, the multiplier for the deleted PSU's units is:

$$
1 - (n_h - 1)\, Z = 1 - Z = 1 - \sqrt{\frac{G}{G - 1}} < 0
\quad \text{for all finite } G
$$

Because `sqrt(G/(G-1)) > 1` always holds for finite `G`, the deleted-PSU weight is
negative whenever `n_h = 2`. The paper (Kott 2001 §3) does not address this; it is an
implementation trap. The spec must decide: emit a warning and retain the negative weight,
or error.

**Boundary continuity:** When `n_h = G`, exactly one PSU falls in each group, so
`n_hg = 1` and `Z = 1/(n_h - 1)`. The extended formula reduces identically to the
standard DAGJK at this boundary (Kott 2001 §3, verified analytically).

When `n_h >= G`, the standard formula (zero-and-rescale) applies. When `n_h < G`, the
extended formula applies. The dispatch is per-stratum.

### MSE vs variance centering

Wolter (2007) §4.5 defines four estimators that differ only in centering:

- **v_1** — centers each stratum's replicates on the within-stratum mean of replicate
  estimates: `hat_theta_{(h·)} = (1/n_h) sum_i hat_theta_{(hi)}`. This is
  `mse = FALSE` behavior.
- **v_4** — centers every replicate deviation on the full-sample estimate `hat_theta`:
  `hat_theta_{(hi)} - hat_theta`. This is `mse = TRUE` behavior.

Algebraic ordering: `v_4 >= v_1` always; the difference equals a non-negative extra
term `sum_h ((hat_theta_{(h·)} - hat_theta)^2 / (n_h - 1))`. Both are unbiased to
second-order moments (Wolter 2007 Theorem 4.5.3). The `mse = TRUE` form is "more
conservative" (Valliant, Dever & Kreuter 2018 §15.4.1).

For the DAGJK nonprob path, only the `mse = TRUE` centering is mathematically
consistent with Kott (2001) eq. 1 — the formula is written with `hat_theta` as the
center, not the mean of replicate estimates. The mse argument is therefore silently
fixed to `TRUE` on the `"grouped"` + `survey_nonprob` path.

For `"jkn"`, `"jk1"`, and `"grouped"` + `survey_taylor`, the `mse` argument is passed
through to the backend and the user controls the centering convention.

| Symbol | Meaning | Bound to |
|--------|---------|----------|
| `H` | Number of design strata | `length(unique(strata_column))` |
| `h` | Stratum index | Stratum column value for a given row |
| `n_h` | Number of sampled PSUs in stratum `h` | Count of distinct PSU IDs within stratum `h` |
| `n_hg` | Number of PSUs from stratum `h` in group `g` | Count of PSUs in the deleted group belonging to stratum `h` |
| `i` | PSU index within stratum `h` (for JKn/JK1) | Implicit via PSU ID column |
| `G` | Number of jackknife groups (replicates) | `replicates` argument |
| `g` | Group (replicate) index, `g = 1, ..., G` | Column index in replicate weight matrix |
| `G_success` | Count of replicates that converged | Derived after replicate construction |
| `w_k` | Original survey weight for element `k` | Weight column in `@data` |
| `w_{k(g)}` | Replicate-`g` weight for element `k` (standard DAGJK) | One column per replicate |
| `w_{k(g)}^(E)` | Extended DAGJK replicate weight (strata with `n_h < G`) | One column per replicate |
| `w_{k(hi)}` | Replicate weight for JKn, dropping PSU `i` from stratum `h` | One column per replicate |
| `hat_theta` | Full-sample estimate | Computed from final weights |
| `hat_theta_{(g)}` | Replicate-`g` estimate | Computed from replicate-`g` weights |
| `hat_theta_{(hi)}` | JKn replicate estimate, dropping PSU `i` from stratum `h` | Computed from replicate weights |
| `hat_theta_{(h·)}` | Within-stratum mean of replicate estimates for stratum `h` | `(1/n_h) * sum_i hat_theta_{(hi)}` |
| `v_J` | Jackknife variance estimate | Value returned by the variance formula |
| `Z` | Scale parameter for extended DAGJK | `sqrt(G / ((G-1) * n_h * (n_h - 1)))` |
| `mse` | Boolean; `TRUE` = center on `hat_theta`; `FALSE` = center on replicate mean | `mse` argument |

---

## Gotchas

1. **Single-PSU strata (`n_h = 1`) — divide-by-zero in all paths.** The scale factor
   `(n_h - 1) / n_h = 0` and the weight multiplier `n_h / (n_h - 1)` is undefined.
   The extended DAGJK formula produces `Z = sqrt(G / ((G-1) * 1 * 0))` which is `Inf`.
   Wolter (2007) §4.5 documents "collapsing" strata as the practical remedy; the paper
   does not guard against this. The implementation must error with a named class
   (e.g., `surveywts_error_jackknife_single_psu_stratum`) before any computation.

2. **Extended DAGJK negative weights when `n_h = 2`.** Because
   `sqrt(G/(G-1)) > 1` for all finite `G`, the deleted-PSU multiplier
   `1 - (n_h-1)*Z = 1 - sqrt(G/(G-1))` is always negative when `n_h = 2`.
   Kott (2001) §3 does not address this. The implementation must decide:
   warn and retain (allowing downstream use of negative weights) or error
   out. The spec should pick one behavior and enforce it consistently.

3. **Pseudo-weights must be recomputed per replicate iteration, not just rescaled.**
   Elliott & Valliant (2017) §3.1 and Valliant (2020) §3.2.1 both state explicitly that
   the propensity model must be refit inside each jackknife iteration, not just the
   weight application. Omitting the refit captures only sampling variability in the
   point estimate, not variability in the weight estimation step, producing understated
   variance. Similarly, calibration steps must be replayed inside each replicate
   (Valliant, Dever & Kreuter 2018 §15.4.1).

4. **Jackknife is not consistent for quantile variance.** Elliott & Valliant (2017)
   §4.1 state the bootstrap is consistent for quantile variance but jackknife is not.
   Valliant, Dever & Kreuter (2018) §15.4.1 confirm: "Neither JKn nor JK2 converges to
   the correct variance for quantiles." Wolter (2007) §4.2.4 shows the jackknife
   breaks down for order statistics. This applies to all three `type` values. The
   function must document this limitation; it need not error (analysis choice is the
   user's), but the documentation must be explicit.

5. **`G = 50` default for `survey_nonprob` is a simulation choice, not an
   analytically derived optimum.** Valliant (2020) §3.2.1 uses `G = 50` in one
   simulation and never derives a minimum, recommends a specific value, or discusses
   sensitivity to `G` for nonprobability samples. The decision doc calls this the
   "Valliant 2020 validated default" — this overstates the evidence. The default is
   reasonable (consistent with the degrees-of-freedom reasoning in Valliant, Dever &
   Kreuter 2018 Table 15.2, which suggests at least 50 df) but should be documented
   as a practical convention, not a formally derived recommendation.

6. **Unequal group sizes with the standard v_GJ1 weight adjustment produce
   `O(1)` squared bias for total estimators.** Valliant, Brick & Dever (2008)
   Table 2 shows overestimates of 200–2000%+ when group sizes differ by even one PSU.
   The DAGJK path uses the v_GJ3 weight adjustment `n_h/(n_h - n_hg)`, which is
   approximately unbiased when the sufficient condition `a_{h(hg)} * (1 - p_{hg}) = 1`
   is satisfied. The implementation must ensure groups are as equal in size as possible
   and warn when group size variation is large.

7. **All PSUs from one design stratum in a single group.** If `n_hg = n_h` for some
   `(h, g)`, then `n_h - n_hg = 0` and the weight multiplier `n_h / (n_h - n_hg)` is
   undefined (division by zero). Valliant, Brick & Dever (2008) §5 state this must
   be avoided: dropping such a group removes an entire stratum's representation.
   The implementation must validate the group assignment and reject configurations
   where any group contains all PSUs of any stratum.

8. **`mse = FALSE` silently forced to `TRUE` on the DAGJK nonprob path.** The
   DAGJK variance formula (Kott 2001 eq. 1; Valliant 2020 eq. 3) is written with
   centering on `hat_theta`. Using `mse = FALSE` (replicate mean centering) would
   produce a different estimator whose bias properties are not established in any of
   the six papers. Users who pass `mse = FALSE` to the DAGJK path must receive a
   warning that the argument was overridden, not silently ignored.

9. **FPC not applicable to DAGJK.** Kott (2001) §2 explicitly assumes FPC is
   negligible. Valliant, Brick & Dever (2008) Table 2 shows DAGJK overestimates
   8–34% when strata have non-negligible sampling fractions precisely because the
   constant `(G-1)/G` scale does not incorporate stratum-level fpc corrections.
   The DAGJK path must not apply any FPC.

10. **Degrees of freedom.** With `G` groups the DAGJK has `G - 1` df
    (Kott 2001 §4; Valliant, Dever & Kreuter 2018 Table 15.2). For JKn the df
    equals `sum_h n_h - H` (total PSUs minus strata count). With
    `replicates = 50L` the DAGJK has 49 df, which is near the threshold for
    reliable SE estimation (Valliant, Dever & Kreuter 2018 Table 15.2 estimates
    CV(SE) ≈ 10% at 50 df).

---

## Reference mapping

**Decision: `type = "jkn"` → `survey::as.svrepdesign(type = "JKn")`**
- Wolter (2007) §4.6, eq. 4.6.4a, 4.6.7 — the JKn weight rule and variance formula
  are standard; delegation to the `survey` package is the correct implementation path.
- Valliant, Dever & Kreuter (2018) §15.4.1, eq. 15.11–15.12 — confirms the formula
  and the `mse` centering convention as implemented in the `survey` package.

**Decision: `type = "jk1"` → `survey::as.svrepdesign(type = "JK1")`**
- Valliant, Dever & Kreuter (2018) §15.4.1 "Special Cases" — JK1 is JKn with one
  stratum. The `survey` package handles this correctly.

**Decision: `type = "grouped"` + `survey_taylor` → `svrep::as_random_group_jackknife_design()`**
- Valliant, Dever & Kreuter (2018) §15.5.1, eq. 15.16–15.17 — grouped jackknife
  formula, equal vs. unequal group sizes. The `svrep` package implements these;
  delegation avoids reimplementing the weight adjustment logic.

**Decision: `type = "grouped"` + `survey_nonprob` → DAGJK engine**
- Kott (2001) eq. 1, §1 (inline) — the DAGJK variance formula and weight construction
  rule are the canonical reference.
- Valliant (2020) §3.2.1 and eq. 3 — validates the DAGJK formula for nonprobability
  samples and provides simulation evidence.
- Elliott & Valliant (2017) §3.1 — motivates the DAGJK approach for nonprobability
  samples; requires pseudo-weight recomputation per replicate.
- Valliant, Brick & Dever (2008) §5 — provides the theoretical connection: v_DAGJK
  is v_GJ3 with one VarStrat and equal-sized groups; confirms the v_GJ3 weight
  adjustment `n_h/(n_h - n_hg)` is the correct formula.

**Decision: `mse` hardcoded `TRUE` for DAGJK**
- Kott (2001) §1 — the formula writes `(t_{(r)} - t)^2` where `t` is the full-sample
  estimate, not the mean of replicate estimates. The centering is load-bearing in the
  unbiasedness proof.
- Wolter (2007) §4.5 — distinguishes v_1 (replicate mean centering) from v_4
  (full-sample centering); the DAGJK corresponds to v_4 (here called `mse = TRUE`).

**Decision: `replicates = 50L` default for `survey_nonprob`**
- Valliant (2020) §3.2.1 — uses `G = 50` in simulation. This is a practical
  convention consistent with the 50-df guidance in Valliant, Dever & Kreuter (2018)
  Table 15.2. The default is defensible but not formally derived.
- Valliant, Dever & Kreuter (2018) Table 15.2 — `G - 1 >= 50` df recommended
  for CV(SE) ≤ 10%; `G = 50` is the minimum that meets this threshold.

**Decision: No `replicates` default for `survey_taylor` + `grouped`**
- Kott (2001) §4 — NASS uses `G = 15` for computational convenience; this is not
  a statistical recommendation. No authoritative default exists for arbitrary cluster
  designs.
- Valliant, Dever & Kreuter (2018) §15.5.2 — target of `>= 50` df but the PSU count
  varies too widely across designs for a single default.

**Decision: Extended DAGJK for `n_h < G`**
- Kott (2001) §3, eq. 2 — the extended formula is the only theoretically supported
  path when `n_h < G`. The standard formula is upward-biased for such strata.

**Decision: Jackknife not valid for quantile variance (documented limitation)**
- Elliott & Valliant (2017) §4.1 — bootstrap is consistent for quantile variance;
  jackknife is not.
- Valliant, Dever & Kreuter (2018) §15.4.1 — explicit statement: "Neither JKn nor
  JK2 converges to the correct variance for quantiles."
- Wolter (2007) §4.2.4 — counterexamples for order statistics.

**Decision: Error on `type = "jkn"` or `"jk1"` for `survey_nonprob` input**
- Elliott & Valliant (2017) §3.1 — delete-one jackknife is appropriate only in the
  absence of design structure and then only at the subject level as a fallback; grouped
  deletion is preferred when any structure is present.
- Valliant, Dever & Kreuter (2018) — all formal JKn/JK1 theory assumes probability
  sample PSU structure.

**Decision: Scale factor `(G_success - 1) / G_success` when replicates fail**
- Kott (2001) §1 — the formula requires the scale to match the number of groups
  actually contributing to the sum. Adjusting to `G_success` rather than `G` is a
  natural extension; no paper addresses this directly, but using the wrong denominator
  would introduce bias proportional to the failure rate.

---

## Assumptions

1. **With-replacement first-stage sampling (or negligible FPC).** All jackknife
   formulas are derived under WR or near-WR conditions. Kott (2001) §2 states FPC
   must be negligible. Wolter (2007) §4.3.3 shows JKn is upward biased for WOR designs
   by a factor of `f / (1-f)` when sampling fractions are non-trivial. For the DAGJK
   nonprob path this is always satisfied (no FPC). For the `survey_taylor` paths, it is
   the user's responsibility.

2. **Calibration-replay and IPW-replay are required for correct variance on the DAGJK
   path.** If calibration or propensity estimation was performed before replicate
   construction, those steps must be repeated inside each replicate using that
   replicate's base weights. Replaying only the final weight application understates
   variance by ignoring weight-estimation variability (Valliant 2020 §3.2.1–3.2.3;
   Elliott & Valliant 2017 §3.1; Valliant, Dever & Kreuter 2018 §15.4.1).

3. **Estimator is a smooth function of expansion estimators.** The jackknife
   is asymptotically unbiased and consistent for smooth statistics (Krewski & Rao
   1981, cited by Valliant, Dever & Kreuter 2018 §15.4.1 and Valliant 2020 §2.1.4).
   It is not consistent for quantiles or other non-smooth estimators. The function
   does not enforce this; the limitation is documented.

4. **Random group formation (DAGJK).** Valliant (2020) §3.2.1 requires "equal-sized
   random groups." Non-random or sorted group assignment introduces bias not captured
   by any of the formulas. The implementation must shuffle PSUs randomly (using the
   `seed` argument for reproducibility) before assigning to groups.

5. **No group spans an entire design stratum.** Valliant, Brick & Dever (2008) §5
   prohibit any group from containing all PSUs of a design stratum, because the
   replicate estimate would not be a legitimate full-population estimate for that
   stratum. The implementation must validate group assignments before proceeding.

6. **Selection on observables (MAR) for the nonprobability path.** Elliott & Valliant
   (2017) §3.1 require the quasi-randomization approach to hold conditional on observed
   covariates. If inclusion depends on the outcome (NMAR), pseudo-weights and their
   variance estimates are both biased. The DAGJK cannot detect or correct NMAR.

7. **Groups are equal in size.** Valliant 2020 eq. 3 and Kott (2001) eq. 1 both assume
   equal group sizes. When `n` is not divisible by `G`, some groups will have one extra
   unit. Neither paper specifies a rounding rule. Valliant, Brick & Dever (2008)
   Eq. 10 and Fig. 2 show the squared-bias term increases with the size of the
   remainder `r = n mod G`, though this primarily affects v_GJ1, not v_GJ3/DAGJK.
   The implementation should minimize the remainder and warn if unequal sizes arise.

---

## Cross-paper conflicts

**Conflict 1 — Centering convention for JKn: v_1 vs. v_4**

Wolter (2007) §4.5 presents four variance estimators (v_1 through v_4) with different
centering. v_1 centers per-stratum on the within-stratum mean of replicate estimates;
v_4 centers on the full-sample estimate. Both are unbiased to second-order moments
(Theorem 4.5.3). The NLSY97 example in Wolter §4.7 uses the v_4 form but labels it
`v_j(hat_R)` without distinguishing it from v_1. Valliant, Dever & Kreuter (2018)
§15.4.1 equate `mse = TRUE` with centering on the full-sample estimate and `mse =
FALSE` with centering on the mean of replicates. Kott (2001) §1 uses the full-sample
centering exclusively (identical to v_4 / `mse = TRUE`).

**Resolution:** The Kott / Valliant, Dever & Kreuter convention maps cleanly to the
`survey` package's `mse` parameter: `mse = TRUE` = v_4 = full-sample centering
(conservative); `mse = FALSE` = v_1 = replicate-mean centering. For the DAGJK nonprob
path, `mse = TRUE` is hardcoded because the formula derivation requires it. For the
probability paths, the user controls `mse` and both are valid.

**Conflict 2 — Recommended number of groups `G` for nonprobability samples**

The decisions document refers to `replicates = 50L` as the "Valliant 2020 validated
default." The extraction from Valliant (2020) documents explicitly that `G = 50` is
the value used in one simulation with no theoretical derivation, no sensitivity
analysis, and no formal recommendation. Valliant, Dever & Kreuter (2018) Table 15.2
provides a degrees-of-freedom argument (50 df ≈ CV(SE) of 10%), which supports `G =
51` or more as a threshold.

**Resolution:** The default `50L` is defensible via degrees-of-freedom reasoning but
should not be described as a "Valliant 2020 recommended value." Documentation should
attribute the default to the df threshold from Valliant, Dever & Kreuter (2018) Table
15.2 and note that Valliant (2020) used 50 groups in simulation.

**Conflict 3 — Standard DAGJK vs v_GJ3 for the nonprobability path**

Valliant, Brick & Dever (2008) §6 and Table 2 show v_DAGJK overestimates variance by
8–34% when sampling fractions are non-trivial (they are non-negligible in the
simulation) because the constant `(G-1)/G` scale omits stratum-level fpc. They
recommend v_GJ3 over v_DAGJK. However, the nonprobability sample context has no
sampling design and no FPC — the nonprobability sample has no finite-population
correction to apply. The overestimation documented by Valliant, Brick & Dever is an
artifact of applying v_DAGJK to a design-based probability sample with substantial
sampling fractions.

**Resolution:** For `survey_nonprob`, the DAGJK formula is appropriate. The Valliant,
Brick & Dever (2008) recommendation of v_GJ3 over v_DAGJK applies to probability
samples with non-negligible fpc; it is not a critique of using DAGJK on nonprobability
samples. The simulation result in Valliant (2020) — using DAGJK on nonprobability
samples and finding only 3–5% overestimation — is the relevant evidence base.

**Conflict 4 — Whether JK1 can be applied to stratified designs**

Kott (2001) §flags that WesVar documentation warns "jackknife 1 should not be used
with a stratified sample," but argues this applies only to an incorrectly specified
version. Valliant, Dever & Kreuter (2018) §15.4.1 present JK1 as JKn with one
stratum, used deliberately when all PSUs are collapsed into a single pseudo-stratum.
They show it applied to a multi-stratum design in Example 15.12 as a deliberate
choice, not as an error.

**Resolution:** JK1 is valid when the user explicitly wants to treat all PSUs as
coming from one stratum. The merged function exposes JK1 as a user-specified `type`;
it does not auto-detect whether JK1 is appropriate. Documentation should note that
JK1 ignores stratification and will generally overestimate variance when applied to
a multi-stratum design.

---

## Citations

Kott, P.S. (2001). The Delete-a-Group Jackknife. _Journal of Official Statistics_,
17(4), 521–526. DOI/URL: [unavailable]

Valliant, R.; Brick, J.M.; Dever, J.A. (2008). Weight Adjustments for the Grouped
Jackknife Variance Estimator. _Journal of Official Statistics_, 24(3), 469–488.
DOI/URL: [unavailable]

Wolter, K.M. (2007). _Introduction to Variance Estimation_ (Second Edition), Chapter 4:
The Jackknife Method. Springer. Chapter page numbers: [unavailable]
DOI/URL: [unavailable]

Valliant, R.; Dever, J.A.; Kreuter, F. (2018). _Practical Tools for Designing and
Weighting Survey Samples_ (2nd ed.). Springer (Statistics for Social and Behavioral
Sciences). Volume/Issue/Pages: [unavailable]
DOI/URL: [unavailable]

Elliott, M.R.; Valliant, R. (2017). Inference for Nonprobability Samples.
_Statistical Science_, 32(2), 249–264. DOI: 10.1214/16-STS598

Valliant, R. (2020). Comparing Alternatives for Estimation from Nonprobability Samples.
_Journal of Survey Statistics and Methodology_, 8, 231–263.
DOI: 10.1093/jssam/smz003
