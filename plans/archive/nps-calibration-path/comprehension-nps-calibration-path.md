# Comprehension — nps-calibration-path

## Problem

Both `create_bootstrap_weights(type = "quasi-randomization")` and
`create_group_jackknife_weights()` currently require an IPW weighting
history entry and refit the propensity model in every replicate. The
underlying methods — the quasi-randomization (QR) bootstrap and the
delete-a-group jackknife (DAGJK) — are actually general NPS variance
estimators: the refit step should replay *whatever weighting pipeline
produced the original weights*, not specifically a propensity model. For
a calibration-only (raking-only) NPS, "refit per replicate" means re-rake
to the stored population targets. No propensity model is involved. The fix
is to make the IPW refit step conditional on the presence of an IPW history
entry, and add a parallel calibration-only branch that re-runs
`calibrate_rake()` on the resampled or group-deleted data.

## Formulas

### QR Bootstrap — calibration-only path

For b = 1, …, B:

1. Draw S_A^(b): SRSWR of size n_A from the NPS rows (same as IPW path).
2. *(Skip IPW — no propensity model.)*
3. Calibration replay:
   - Level A (fixed targets): Run raking on S_A^(b) with equal initial
     weights and targets T from `calib_entry$parameters$targets`.
   - Level B (targets from reference): SRSWR of size n_ref from the
     reference rows → ref^(b). Re-estimate margin targets T^(b) from
     ref^(b) weights. Run raking on S_A^(b) with equal initial weights
     and targets T^(b).
4. Extract the final raked weight vector w^(b) for S_A^(b) as the b-th
   replicate weight vector.

Equal initial weights for S_A^(b): each unit starts with weight 1 (or
1/n_A if proportions are needed), because SRSWR assigns equal selection
probability to every NPS unit in each replicate.

### DAGJK — calibration-only path

Divide the combined dataset (NPS ∪ reference, if Level B; NPS only, if
Level A) into G random groups.

For g = 1, …, G:

1. Form the reduced NPS: S_A^(-g) = S_A \ group-g NPS rows.
2. Scale adjustment factor: a_g = n_A / (n_A − n_{Ag}), where n_{Ag} is
   the count of NPS units in group g.
3. Apply the scale factor to the current (raked) weights of S_A^(-g):
   w_i^(adj) = w_i · a_g for all i ∈ S_A^(-g).
4. Calibration replay (same Level A / Level B logic as bootstrap):
   - Level A: Re-rake the adjusted weights w^(adj) to fixed targets T.
   - Level B: Form ref^(-g) = reference \ group-g reference rows.
     Re-estimate margins T^(-g) from ref^(-g). Re-rake w^(adj) to T^(-g).
5. Extract the final raked weight vector w^(g) as the g-th replicate.

Variance estimator (same formula as IPW-path DAGJK):

  V(θ̂) = ((G−1)/G) · Σ_{g=1}^{G} (θ̂^(g) − θ̂)²

where θ̂^(g) is the estimate computed with replicate g weights and θ̂ is
the full-sample estimate.

### "No weighting history" edge case

If `data@metadata@weighting_history` contains neither an `"ipw"` entry nor
a `"calibrate_rake"` entry, there is no weighting model to replay. Both
functions must error with a clear, classed message.

## Gotchas

- **Starting weights in QR bootstrap calibration-only**: Must use *equal*
  initial weights for S_A^(b), not carry forward the original raked weights.
  SRSWR gives each NPS unit equal selection probability per replicate.
  Carrying forward original raked weights would double-count calibration.

- **Starting weights in DAGJK calibration-only**: Apply the multiplicative
  scale factor n_A/(n_A − n_{Ag}) to the *current (raked)* weights of the
  retained units, then re-rake. The scale factor propagates the group-deletion
  uncertainty before re-calibration.

- **Reference sample requirement — calibration-only Level B**: If the
  calibration history entry has `targets_from_reference = TRUE`, a reference
  design is needed to re-estimate margins per replicate. The reference is
  taken from `calib_entry$parameters$reference_design` or the
  `reference_sample` argument (argument takes precedence). If neither is
  available, error clearly.

- **calibrate_rake() on a plain data.frame returns weighted_df, not
  survey_nonprob**: The current bootstrap loop extracts replicate weights
  using `calib_result_b@data[[wt_col]]`. For the calibration-only path where
  the starting object is a data.frame, `calibrate_rake()` returns a
  `weighted_df`. Weight extraction must branch on the output class, or the
  starting object must be a `survey_nonprob` (so the output is too).

- **IPW history precedence**: When both IPW and calibration entries exist,
  the IPW path takes precedence (current behavior, unchanged).

- **DAGJK: no reference for calibration-only Level A**: For a calibration-only
  object with Level A targets (`targets_from_reference = FALSE`), no reference
  sample is needed for the DAGJK. The current mandatory reference requirement
  must become conditional on whether the history implies Level B.

- **Error class update**: The current `surveywts_error_dagjk_requires_nonprob`
  error message says "requires an IPW weighting history" — this wording is
  wrong and must be updated to describe the actual requirement.

- **"No history" case**: A `survey_nonprob` with no weighting history at all
  (empty `@metadata@weighting_history`) should produce a distinct, informative
  error from both functions, not fall through to a confusing downstream error.

## Reference mapping

- Elliott & Valliant (2017) p.234 → "pseudo-weights should be recomputed
  each replicate" justifies applying the same logic to calibration weights
  as to IPW weights. The term "pseudo-weights" is generic.
- Kolenikov (2014) §4.6 → Bootstrap + re-rake algorithm: resample, re-rake
  to same population constraints; validates calibration-only QR bootstrap path.
- Valliant (2020) §2.1.4 → "the binary regression model refitted in every
  group" describes the IPW variant; Section 2.2 extends the same replication
  logic to superpopulation models (calibration). DAGJK is general.
- Chrostowski (2025) §2.2 → Bootstrap steps: SRSWR, then "estimate using an
  appropriate approach." Includes calibrated IPW as a valid weighting method.
- Wu (2022) §6 → Quasi-randomization through post-stratification/raking achieves
  the same inferential goals as propensity IPW; bootstrap applies uniformly.

## Assumptions

- A `survey_nonprob` with no weighting history (neither IPW nor calibration)
  has no model to replay and cannot produce replicate weights — error, not
  fallback.
- Level B raking (calibration history entry with `targets_from_reference =
  TRUE`) requires a reference design in the calibration-only path, just as
  it does in the IPW path.
- The SRSWR resampling step itself is identical for all paths; only the
  re-weighting sub-step differs.
- The DAGJK scale factor (n_A/(n_A − n_{Ag})) is applied to the *current*
  weights (whatever they are after the original weighting pipeline ran),
  not to equal starting weights.
- `calibrate_rake()` can accept the resampled/group-deleted data; failed
  calibration convergence per replicate is handled by the existing failed-draw
  counting mechanism.

## Citations

- Elliott, M.R. and Valliant, R. (2017). Inference for nonprobability samples.
  *Statistical Science* **32**(2), 249–264.
- Wu, C. (2022). Statistical inference with non-probability survey samples.
  *Survey Methodology* **48**(2), 283–311.
- Chrostowski, M.J., Guzman, C.A. and Malm, L. (2025). Variance estimation
  for non-probability surveys. *Journal of Survey Statistics and Methodology*
  (forthcoming).
- Kolenikov, S. (2014). Calibrating survey data using iterative proportional
  fitting (raking). *Survey Methodology* **40**(1), 21–38.
- Valliant, R. (2020). Comparing alternatives for estimation from nonprobability
  samples. *Journal of Survey Statistics and Methodology* **8**, 231–263.
- Valliant, R. (2009). Model-based prediction of finite population totals. In
  Pfeffermann, D. and Rao, C.R. (Eds.), *Handbook of Statistics, Sample
  Surveys: Inference and Analysis* (Vol. 29B). Elsevier.
