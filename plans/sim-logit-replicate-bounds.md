# Simulation: absolute logit bounds on replicate weights

Date: 2026-11-17. Script: `plans/sim-logit-replicate-bounds.R`. Context: issue #144, PR #145.

## Result

Bound each draw (rule 2) gives correct replicate SEs. Bound the replicate weight (rule 1, PR #145) does not. Under rule 1, most bootstrap and BRR replicates cannot meet the targets, and the SE is 1.7 to 2.2 times too large when the bounds bind. Recommendation: change the replicate rule to rule 2 for all replicate types, not only bootstrap.

## Rules compared

A replicate weight is `rep_wt_k = a_k * d_k`, where `d_k` is the full-sample base weight and `a_k` is the replicate factor (0 or 2 for BRR, `m_k * n_h / (n_h - 1)` for the Rao-Wu bootstrap).

| Rule | Per-unit g-bounds in the replicate | Replicate weight range |
|---|---|---|
| 0 (develop today) | `abs_L / rep_wt`, `abs_U / rep_wt`; a pole when `rep_wt >= abs_U` | `[abs_L, abs_U]` by the clamp |
| 1 (PR #145) | units with `rep_wt >= abs_U` held at `abs_U` (`<= abs_L` at `abs_L`); others as rule 0 | `[abs_L, abs_U]` |
| 2 (bound each draw) | `abs_L / d_k`, `abs_U / d_k` from the full sample | `[a_k * abs_L, a_k * abs_U]` |
| Baseline | linear (GREG), no bounds | none |

Rule 1 in the script gives the same replicate weights as `calibrate_logit()` on the PR #145 branch (50 bootstrap replicates: max difference 0, the same 11 replicates converge).

## Design

- Population: 10 strata, 30 PSUs each, PSU sizes 40 to 200 (N = 34,606). `x` has 3 levels and its mix changes by PSU. `y` depends on `x`, a PSU effect, and noise.
- Sample: SRS of `n_h` PSUs per stratum, then SRS of `b` units per PSU. Base weight `d = (30 / n_h) * (B / b)`, from 30 to 150.
- Nonresponse by `x`: response rates 0.85, 0.70, 0.50. Respondents keep `d`. Calibration to the population counts of `x` restores the `x = 3` group, so its weights must go up by about 2.
- Absolute bounds: `abs_L = 0.8 * min(d)`, `abs_U = k * max(d)`, with `k` = 1.5 (bounds bind), 2.5, and 4 (bounds do not bind).
- Scenario A: `n_h = 2`, `b = 20`. Bootstrap (Rao-Wu, 200 replicates), BRR, JKn.
- Scenario B: `n_h = 4`, `b = 10`. Bootstrap (200 replicates), JKn.
- Estimate: weighted mean of `y`. Replicate totals are the population totals times `sum(rep_wt) / sum(d)`.
- A replicate that does not converge keeps its uncalibrated weights. `calibrate_logit()` does the same.
- 1000 samples per scenario. Samples whose full-sample calibration failed are dropped (42 at `k = 1.5`, 1 to 17 at the others).

SE ratio = mean replicate SE / Monte Carlo SD of the estimate. Coverage is for the normal 95% interval. Rule 0 is left out. It gave the same SE ratio as rule 1 to 2 decimals in all rows but two, and in those two its SE was larger: JKn in scenario A at `k = 1.5` (1.37 against 1.14) and bootstrap in scenario B at `k = 2.5` (1.44 against 1.37).

## Results: bounds bind (`k = 1.5`)

| Scenario | Method | Rule 1 SE ratio | Rule 1 coverage | Rule 1 failed reps | Rule 2 SE ratio | Rule 2 coverage | Rule 2 failed reps | Linear SE ratio | Linear coverage |
|---|---|---|---|---|---|---|---|---|---|
| A | bootstrap | 1.73 | 0.99 | 99% | 1.19 | 0.96 | 11% | 0.98 | 0.92 |
| A | BRR | 1.73 | 0.99 | 99% | 1.18 | 0.95 | 11% | 0.98 | 0.93 |
| A | JKn | 1.14 | 0.90 | 4% | 1.13 | 0.93 | 2% | 0.96 | 0.92 |
| B | bootstrap | 2.15 | 1.00 | 95% | 1.31 | 0.98 | 9% | 1.04 | 0.95 |
| B | JKn | 1.34 | 0.95 | 1% | 1.23 | 0.96 | 0.5% | 1.05 | 0.96 |

## Results: `k = 2.5` and `k = 4`

| Scenario | Method | k | Rule 1 SE ratio | Rule 1 failed reps | Rule 2 SE ratio | Rule 2 failed reps | Linear SE ratio |
|---|---|---|---|---|---|---|---|
| A | bootstrap | 2.5 | 1.38 | 36% | 1.02 | 3% | 0.96 |
| A | BRR | 2.5 | 1.37 | 35% | 1.02 | 3% | 0.96 |
| A | JKn | 2.5 | 0.91 | 0.4% | 0.99 | 0.5% | 0.94 |
| B | bootstrap | 2.5 | 1.37 | 15% | 1.12 | 2% | 1.03 |
| B | JKn | 2.5 | 1.04 | 0.02% | 1.07 | 0.03% | 1.04 |
| A | bootstrap | 4 | 1.00 | 1% | 1.02 | 2% | 0.96 |
| B | bootstrap | 4 | 1.04 | 0.4% | 1.12 | 1.6% | 1.05 |

At `k = 4` the bounds do not bind, and the rules agree with each other and with the baseline.

## Failed replicates explain what is left

A second run (bootstrap only, 1000 samples) computed the SE from the converged replicates only, rescaled to 200 replicates.

| Scenario | k | Rule 1 SE ratio | Rule 1 coverage | Rule 2 SE ratio | Rule 2 coverage | Linear SE ratio |
|---|---|---|---|---|---|---|
| A | 1.5 | 0.99 (from 0.5 replicates per sample on average) | 0.85 | 0.99 | 0.92 | 0.98 |
| B | 1.5 | 0.82 | 0.82 | 1.04 | 0.95 | 1.04 |
| B | 2.5 | 0.93 | 0.93 | 1.04 | 0.96 | 1.03 |

With the failed replicates dropped, rule 2 agrees with the linear baseline. Rule 1 is too small in scenario B. In scenario A it rests on so few replicates that coverage is 0.85.

## Why rule 1 fails

A replicate weight is about `a_k` times the full-sample weight, and the replicate totals stay about the same as the full-sample totals. Where `a_k = 2` (BRR, or a bootstrap PSU drawn once with `n_h = 2`), the replicate needs weights about twice the full-sample calibrated weights. If the full-sample weight of a unit is near `abs_U`, the replicate needs about `2 * abs_U`. Rule 1 does not allow this, so the replicate cannot meet the targets or meets them with a different estimator. This happens at `k = 2.5` even when no unit is held at the bound (scenario A: 0 held units, 36% failed replicates). The pole in issue #144 is a symptom of this, not the cause.

Rule 2 gives each replicate the same g-bounds as the full sample. The replicate estimator is then the full-sample estimator applied to the resampled data, which is what replicate variance theory assumes. This argument does not depend on the replicate type, and the BRR and jackknife results agree with it. The argument in PR #145 that holding at the bound is faithful for BRR and jackknife does not hold: the half-sample with weights `2d` is a different estimator from the full sample with weights `d` when the bound is a fixed number.

## Recommendation

1. Change the replicate branch of `calibrate_logit(bounds_scale = "absolute")` to rule 2 for all replicate types: per-unit g-bounds `abs_L / d_k` and `abs_U / d_k` from the full-sample base weights. A unit with `rep_wt = 0` stays out (issue #139). Every unit with `d_k` inside `(abs_L, abs_U)` then has `L_k < 1 < U_k`, so issue #144 has no pole to handle. The full-sample check already makes sure of that.
2. Document that absolute bounds limit each full-sample weight, and that a replicate weight can reach `a_k * abs_U`.
3. Separate question: a replicate that fails keeps its uncalibrated weights. At `k = 1.5` that is 9 to 11% of rule 2 bootstrap replicates, and it makes the SE about 20 to 30% too large. For bootstrap, dropping failed replicates gave correct SEs here. For BRR and jackknife, dropping a replicate is not valid.
4. `calibrate_linear()` with absolute bounds may need the same review (issue #144, question 2).

## Limits

- One population, one calibration variable, and one estimator (a mean).
- `n_h = 2` with 10 strata gives few degrees of freedom. The linear baseline covers 92% in scenario A for this reason.
- The replicate totals are the population counts times `sum(rep_wt) / sum(d)`, with the intercept scaled the same way. The `type = "count"` path in the package does not scale the intercept this way, which is a separate bug (issue #148).
- Run time: about 23 minutes on 14 cores.
