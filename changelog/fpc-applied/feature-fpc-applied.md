---
pr: feature/fpc-applied
type: feat
scope: replicate
---

## feat(replicate): record fpc_applied; warn when a method drops the FPC

Issue: JDenn0514/surveywts#130.

### Behavior change

Every `survey_replicate` that `create_*_weights()` builds from a source
design with an `fpc` now sets surveycore's `@variables$fpc_applied`.
`@variables$fpc` still names the source column. With no `fpc` on the source,
both keys are `NULL`. surveycore 1.2.0's `as_svydesign()` reads the key, so
it no longer raises `surveycore_warning_replicate_fpc_dropped` on these
designs.

BRR, Fay, `type = "Rao-Wu"`, `type = "Antal-Tille"` and `type = "grouped"`
record `"none"` and raise the new warning `surveywts_warning_fpc_not_applied`.
The untyped `survey` warning ("Finite population correction dropped in
conversion", BRR and Fay) and the untyped `svrep` warning ("Ignoring finite
population corrections in `design`", grouped) are muffled by text in
`.collect_backend_messages()`.

No replicate weight column, `scale`, `rscales` or standard error changes.

### Measured map

From `make_fpc_designs()`: 8 strata, 4 PSUs of 3 units each, `N_h` from 6
to 40, weight `N_h / n_h`, same seed with and without the FPC, SE of a total.
Taylor ratio 0.919 (0.967 on the paired BRR frame, 0.775 on the unstratified
JK1 frame).

| Method and type | SE ratio | `fpc_applied` |
|---|--:|---|
| jackknife `jkn` | 0.919, equals Taylor | `rscales` |
| jackknife `jk1` | 0.775, equals Taylor | `rscales` (survey puts it in `scale`) |
| jackknife `grouped` | 1.000 | `none` |
| bootstrap `Rao-Wu-Yue-Beaumont` | 0.919 | `repweights` |
| bootstrap `Preston` | 0.918 | `repweights` |
| bootstrap `Canty-Davison` | 0.915 | `repweights` |
| bootstrap `Rao-Wu` | 1.000 | `none` |
| bootstrap `Antal-Tille` | 1.000 | `none` |
| generalized bootstrap (SD1) | 0.922 | `repweights` |
| generalized replication (SD2) | 0.920 | `repweights` |
| SDR, 20 replicates | 0.927 | `repweights` |
| BRR | 1.000 | `none` |
| Fay, `rho = 0.3` | 1.000 | `none` |

Canty-Davison is `survey`'s `type = "bootstrap"`: it draws `n_h` PSUs
without replacement from a pseudo-population of `N_h` copies. With
`fpc = n_h` every replicate equals the full sample and the SE is exactly 0.
The test pins that.

The Rao-Wu-Yue-Beaumont bootstrap and the generalized estimators
Deville-1, Deville-2, Beaumont-Emond and Poisson Horvitz-Thompson read the
sampling fraction from 1 / weight, not from the `fpc` column. They match the
column only when the weights are design weights.

### Files

- `R/replicate-utils.R`: `.fpc_applied_map`, `.warn_fpc_not_applied()`,
  `.is_backend_fpc_warning()`; `.convert_and_call()` takes `fpc_applied` and
  `fpc_call`; `.collect_backend_messages()` muffles the two FPC warnings.
- `R/create_*_weights.R`: each call passes its map value; roxygen inherits a
  new "Finite population correction" section from
  `create_replicate_weights()`.
- `plans/error-messages.md`: register row for
  `surveywts_warning_fpc_not_applied`.
- `tests/testthat/test-fpc-applied.R`, `helper-test-data.R`
  (`make_fpc_designs()`, `rep_se_total()`, `taylor_se_total()`).
- `NEWS.md`, `man/`.
