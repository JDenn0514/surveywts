# surveywts Package Development

**Part of the surveyverse ecosystem.**

surveywts provides tools for survey weighting and calibration.

---

## Release Status

| Release | Tag | Status | Notes |
|---------|-----|--------|-------|
| Calibration | `v0.1.0` | ✅ Complete | `calibrate()`, `calibrate_rake()`, `calibrate_linear()`, `calibrate_logit()`, `poststratify()`, basic diagnostics |
| Replicate | minor bump | ✅ Complete | All `create_*_weights()` functions; `as_taylor_design()` |
| Utilities | minor bump | ✅ Complete | `trim_weights()`, `rescale_weights()` |
| Nonresponse | minor bump | ✅ Complete | `calibrate_to_survey()`, `calibrate_to_estimate()`, `adjust_nonresponse()`, `redistribute_weights()` |
| Propensity | minor bump | ✅ Complete | Non-probability sample IPW; unlocks propensity nonresponse |
| Diagnostics | minor bump | 🔜 Next | Balance assessment, `check_balance()`, `diagnose_propensity()`, `compare_weighted_estimates()` |
| Polish | minor bump | ⬜ Pending | Vignettes, `--as-cran` clean, pkgdown |

Full roadmap at `plans/roadmap.md`.

---

## Where Things Live

- `plans/error-messages.md` — canonical error/warning class names and CLI
  message templates
- `.claude/WORKFLOW.md` — how the skills fit together (planning arc →
  implementation loop)
- `.claude/rules/core.md` — cross-role rules that auto-load; its pointer
  table names the one standards file for each concern
- `.claude/standards/` — the 8 role-scoped standards files (code style,
  documentation, package conventions, testing, GitHub strategy, engineering
  preferences); read on demand, not auto-loaded

## Before You Write or Review R Code

Read the standards file for what you are writing or reviewing. The pointer
table in `.claude/rules/core.md` names which one.
