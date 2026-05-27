# Test Spec: NPS Bootstrap — `create_bootstrap_weights()` NPS Types

**Version:** 1.0
**Date:** 2026-05-27
**Status:** SPEC_READY
**Source spec:** `plans/spec-nps-bootstrap.md` §X (v1.1)
**Target file:** `tests/testthat/test-08-nps-bootstrap.R`
**Function under test:** `create_bootstrap_weights()` with `type = "quasi-randomization"`

This document is the tester's standalone input. It contains all test blocks
needed to validate the NPS bootstrap implementation. For the full behavioral
contract, algorithm details, and error class definitions, see
`plans/spec-nps-bootstrap.md`.

---

## Test Infrastructure

**Synthetic data generator:** `make_surveywts_data(n, seed)` — see `tests/testthat/helper-test-data.R`

**Helper objects needed (define in test file or `helper-*.R`):**
```r
# Probability-sample reference design
make_nps_ref <- function(seed = 42) {
  ref_df <- make_surveywts_data(n = 200, seed = seed)
  surveycore::as_survey(ref_df, weights = base_weight)
}

# NPS with ipw + rake history (Level A: targets_from_reference = FALSE)
make_nps_level_a <- function(seed = 1, n = 500) {
  nps_df <- make_surveywts_data(n = n, seed = seed)
  ref    <- make_nps_ref(seed = seed + 100)
  nps_df |>
    ipw(reference = ref, selection = ~age_group + sex) |>
    rake(margins = list(age_group = c(...), sex = c(...)))
    # margins are fixed population counts, NOT from ref → targets_from_reference = FALSE
}

# NPS with ipw + rake history (Level B: targets_from_reference = TRUE)
make_nps_level_b <- function(seed = 2, n = 500) {
  ref <- make_nps_ref(seed = seed + 100)
  make_surveywts_data(n = n, seed = seed) |>
    ipw(reference = ref, selection = ~age_group + sex) |>
    rake(margins = ..., reference_design = ref)
    # reference_design passed → targets_from_reference = TRUE
}
```

---

## Happy-Path Tests

**Block 1: quasi-randomization Level A — `survey_nonprob` with ipw + rake history**
```
data    : make_nps_level_a(seed=1)
type    : "quasi-randomization"
replicates : 50L
seed    : 1L
Expected:
  - Return class is survey_nonprob
  - test_invariants(result) passes
  - @data has columns repwt_1 ... repwt_50 (all numeric, all > 0)
  - names(@data) includes all original columns plus repwt_1...repwt_50
  - @variables$repweights == c("repwt_1", ..., "repwt_50")
  - @variables$weights unchanged from input
  - @metadata@weighting_history has one new "bootstrap_weights" entry
  - new history entry: operation="bootstrap_weights", type="quasi-randomization",
    replicates=50, level="A", draws_used <= 50
```

**Block 2: quasi-randomization Level B — `survey_nonprob` with ipw + rake history, `targets_from_reference = TRUE`**
```
data    : make_nps_level_b(seed=2)
type    : "quasi-randomization"
replicates : 50L
seed    : 2L
Expected:
  - history entry level = "B"
  - repwt columns present as in Block 1
```

**Block 3: `replicates = NULL` default resolution**
```
- NULL + "quasi-randomization" → resolves to 200L
  (check @metadata@weighting_history last entry: replicates = 200)
- NULL + "Rao-Wu" (prob-sample type) → resolves to 500L
  (check the svrep-created survey_replicate: ncol(repweights) = 500)
```

**Block 4: `seed` reproducibility**
```
call1 <- create_bootstrap_weights(data, type="quasi-randomization",
                                  replicates=20L, seed=42L)
call2 <- create_bootstrap_weights(data, type="quasi-randomization",
                                  replicates=20L, seed=42L)
call3 <- create_bootstrap_weights(data, type="quasi-randomization",
                                  replicates=20L, seed=99L)
→ call1@data[repwt cols] identical to call2@data[repwt cols]
→ call1@data[repwt cols] NOT identical to call3@data[repwt cols]
```

**Block 5: `reference_sample` override**
```
data has ipw history with ref design A (stored in history).
Call with reference_sample = ref_B (a different survey_taylor).
→ repwt columns differ from a call without reference_sample override
  (confirms ipw() used ref_B, not ref design A from history).
```

**Block 6: probability-sample types unchanged**
```
Existing test patterns for Rao-Wu, Canty-Davison, etc. still pass.
No behavioral change — regression guard.
```

**Block 7: Level B differential — confirm reference is actually resampled**
```
# Level A/B detection depends solely on calib_entry$parameters$targets_from_reference.
# Passing reference_sample does NOT change the detection outcome.
# Compare Level A data (rake without reference_design) vs Level B data
# (rake with reference_design) at the same seed to confirm the two code paths
# produce different replicate weights.

data_level_a <- make_nps_level_a(seed=3)   # rake history: targets_from_reference = FALSE
data_level_b <- make_nps_level_b(seed=3)   # rake history: targets_from_reference = TRUE

level_a_result <- create_bootstrap_weights(data_level_a,
  type="quasi-randomization", replicates=30L, seed=77L)

level_b_result <- create_bootstrap_weights(data_level_b,
  type="quasi-randomization", replicates=30L, seed=77L)

→ level_a_result@metadata@weighting_history last entry: level = "A"
→ level_b_result@metadata@weighting_history last entry: level = "B"
→ level_a_result@data[repwt cols] NOT identical to level_b_result@data[repwt cols]
  (Confirms Level B re-estimates calibration targets from the resampled reference,
   producing different weights than Level A's fixed-target calibration.)
```

**Block 8: Print snapshot — `survey_nonprob` with repweights**
```
result <- create_bootstrap_weights(make_nps_level_a(seed=1),
            type="quasi-randomization", replicates=10L, seed=1L)
expect_snapshot(print(result))
→ output includes line "Bootstrap replicates: 10 (quasi-randomization, level A)"
```

**Block 9: Print snapshot — plain `survey_nonprob` (no repweights)**
```
plain_nonprob <- make_nps_level_a(seed=1)
expect_snapshot(print(plain_nonprob))
→ output does NOT include "Bootstrap replicates" line
```

**Block 10: Second-call overwrites existing repweights**
```
result1 <- create_bootstrap_weights(make_nps_level_a(seed=1),
             type="quasi-randomization", replicates=5L, seed=1L)

expect_warning(
  result2 <- create_bootstrap_weights(result1,
               type="quasi-randomization", replicates=10L, seed=2L),
  class = "surveywts_warning_repweights_overwritten"
)
→ result2@data has exactly 10 repwt columns (not 15)
→ result2@variables$repweights == c("repwt_1", ..., "repwt_10")
→ No repwt_6 ... repwt_10 column name overlap confusion (columns 1-5 are overwritten)
```

---

## Error-Path Tests (dual pattern: `class=` + `expect_snapshot(error=TRUE)`)

Each block uses both assertions per `testing-standards.md §2`.

| Block | Call | Expected class |
|-------|------|---------------|
| E1 | `create_bootstrap_weights(survey_taylor_obj, type="quasi-randomization")` | `surveywts_error_qr_bootstrap_requires_nonprob` |
| E2 | `create_bootstrap_weights(weighted_df_obj, type="quasi-randomization")` | `surveywts_error_qr_bootstrap_requires_nonprob` |
| E3 | `create_bootstrap_weights(survey_taylor_obj, type="hybrid")` | `surveywts_error_hybrid_bootstrap_requires_nonprob` |
| E4 | `create_bootstrap_weights(nonprob_no_ipw_history, type="quasi-randomization")` | `surveywts_error_qr_bootstrap_no_ipw_history` |
| E5 | `create_bootstrap_weights(nonprob_with_ipw_no_ref, type="quasi-randomization")` (no `reference_sample`) | `surveywts_error_qr_bootstrap_no_reference` |
| E6 | `create_bootstrap_weights(nonprob, type="hybrid")` | `surveywts_error_hybrid_bootstrap_not_implemented` |
| E7 | `create_bootstrap_weights(nonprob, type="quasi-randomization", reference_sample=survey_replicate_obj)` | `surveywts_error_reference_sample_class` |
| E8 | `create_bootstrap_weights(nonprob, type="quasi-randomization", reference_sample=list())` | `surveywts_error_reference_sample_class` |
| E9 | `create_bootstrap_weights(survey_taylor_obj, type="Rao-Wu", mse="chrostowski")` | `surveywts_error_chrostowski_prob_sample` |
| E10 | `create_bootstrap_weights(nonprob, type="quasi-randomization", mse=TRUE)` | `surveywts_error_mse_not_character` |
| E11 | `create_bootstrap_weights(nonprob, type="quasi-randomization", mse=FALSE)` | `surveywts_error_mse_not_character` |

---

## Warning-Path Tests

| Block | Call | Expected class |
|-------|------|---------------|
| W1 | `create_bootstrap_weights(nonprob, type="Rao-Wu", reference_sample=ref)` | `surveywts_warning_reference_sample_ignored` |
| W2 | Degenerate NPS that forces >10% draw failures (see EC2) | `surveywts_warning_bootstrap_draws_failed` |
| W3 | Second call on same object (Block 10 above) | `surveywts_warning_repweights_overwritten` |

---

## Edge-Case Tests

**Block EC1: Very small NPS (n = 10)**
```
A survey_nonprob with 10 rows + ipw + rake history.
create_bootstrap_weights(..., type="quasi-randomization", replicates=20L)
→ completes without error; 20 repwt columns present (up to draw failures).
test_invariants(result) passes.
```

**Block EC2: All draws fail → `surveywts_error_bootstrap_all_draws_failed`**
```
Construction: NPS of 3 rows where selection = ~x and x is a factor with two
levels but only one level appears in all rows (x = "A" for all 3 rows).
Every resample produces a degenerate design matrix; every within-draw ipw()
call fails with the propensity hessian error.
→ expect_error(..., class = "surveywts_error_bootstrap_all_draws_failed")
expect_snapshot(error = TRUE, ...)
```

**Block EC3: `mse` variants stored in history**
```
For each:
  - mse = "mse": history entry records mse = "mse"
  - mse = "chrostowski": history entry records mse = "chrostowski"
  - mse = "uncentered": history entry records mse = "uncentered"
Assert: result@metadata@weighting_history[[last]]$mse == mse
```

**Block EC4: `seed = NULL` completes without error**
```
create_bootstrap_weights(data, type="quasi-randomization", seed=NULL, replicates=10L)
→ completes; result is non-deterministic but valid.
test_invariants(result) passes.
```

**Block EC5: `ipw` only (no calibration in history)**
```
data = make_surveywts_data(seed=5) |> ipw(reference=ref, selection=~age_group+sex)
No rake/calibrate step in history.
create_bootstrap_weights(data, type="quasi-randomization", replicates=20L, seed=1L)
→ completes; history entry level = "A"; draws use ipw weights only (no in-loop rake).
```

---

## Numerical Correctness Test

**Block N1: Bootstrap SE within expected range**
```
DGP  : Known population (n_pop = 10000), known propensities.
NPS  : n = 500, reference: n = 200.
B    : 500 quasi-randomization bootstrap draws.
Seed : fixed for reproducibility.

Bootstrap SE for population mean must fall within
  [0.5 * theoretical_SE, 2 * theoretical_SE].

Tolerance: wide (bootstrap is stochastic by design).
skip_if_not_installed() inside block if needed.
```

---

## History Entry Correctness

**Block H1: History entry structure**
```
result <- create_bootstrap_weights(make_nps_level_a(seed=1),
            type="quasi-randomization", replicates=30L, seed=7L)
entry  <- tail(result@metadata@weighting_history, 1)[[1]]

expect_identical(entry$operation, "bootstrap_weights")
expect_identical(entry$type, "quasi-randomization")
expect_identical(entry$replicates, 30L)
expect_true(entry$draws_used <= 30L)
expect_true(entry$level %in% c("A", "B"))
expect_identical(entry$mse, "mse")
expect_identical(entry$seed, 7L)
expect_s3_class(entry$timestamp, "POSIXct")
```

---

## Quality Gate Checklist (Tester)

- [ ] All happy-path blocks pass (Blocks 1–10)
- [ ] All error-path blocks pass with dual pattern (E1–E11)
- [ ] All warning-path blocks pass (W1–W3)
- [ ] All edge-case blocks pass (EC1–EC5)
- [ ] Numerical correctness block passes (N1)
- [ ] History entry structure block passes (H1)
- [ ] Print snapshots approved and committed to `tests/testthat/_snaps/`
- [ ] No new snapshot failures
- [ ] Test coverage ≥ 98% on `R/replicate-weights.R` new code
