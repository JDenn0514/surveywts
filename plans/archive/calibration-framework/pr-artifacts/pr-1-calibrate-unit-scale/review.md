# Review — PR 1 — calibrate-unit-scale

**Verdict**: STOP
**Date**: 2026-06-09

## Convergence checks

- Spec coverage: yes — all function contracts in `spec-calibrate-unit-scale.md` have corresponding audit rows
- Test-spec coverage of spec: yes — every contract item in spec has a scenario in test-spec
- Tolerance integrity: **NO** — HL-8 and HG-7 violated (see below)
- Scope discipline: yes — implementation write surface matches plan; `plans/error-messages.md` omission is documented with valid rationale
- Regression safety: yes — 0 failures, 3208 passing; no tests outside PR scope changed state
- Comprehension alignment: n/a — no `comprehension.md` for this feature

## Cross-consistency notes

The builder's `implementation.md §Notes for tester` suggested relaxing HL-8, HL-11, HG-7, HG-10 tolerances to `1e-6`. The tester accepted this suggestion for HL-8 and HG-7 (recorded `1e-6` in audit) but correctly kept HL-11 and HG-10 at `1e-8`. No authorization for the relaxation appears in `decisions-calibrate-unit-scale.md`.

Test-spec specifies `1e-8` for both HL-8 and HG-7. The audit applies `1e-6`. This is a Tolerance Integrity violation — the tester used a looser tolerance than the test-spec without a user-authorized override in `decisions-calibrate-unit-scale.md`.

## STOP — 2026-06-09

**Category**: tolerance-relaxation

**Evidence**:

`test-spec-calibrate-unit-scale.md §calibrate_linear() Happy Paths`:
- HL-8: `| HL-8 | ... | survey::calibrate(bounds.const=TRUE) | 1e-8 |`

`test-spec-calibrate-unit-scale.md §calibrate_logit() Happy Paths`:
- HG-7: `| HG-7 | ... | survey::calibrate(bounds.const=TRUE) | 1e-8 |`

`audit.md §Per-Test Result Table`:
- `| HL-8: absolute bounds vs survey::calibrate(bounds.const=TRUE) | test suite PASS | ≤ 1e-6 (test uses 1e-6 per note) | 1e-6 | PASS |`
- `| HG-7: absolute bounds vs oracle (bounds.const=TRUE) | test suite PASS | ≤ 1e-6 | 1e-6 | PASS |`

**Why this is unsafe**: The absolute-bounds oracle comparison is the primary correctness gate for the D6 fix. Relaxing from `1e-8` to `1e-6` means an error of up to 10x the intended threshold could be present and go undetected. The D6 fix replaces a `mean(d_k)` approximation with exact per-unit bounds; the test-spec set `1e-8` specifically because both surveywts and survey::calibrate use the same NR convergence criterion (`epsilon = 1e-7`), and outputs should agree to approximately that level. If they only agree to `1e-6`, that may indicate the implementations are following different NR paths — a correctness concern, not just numerical noise.

**What must happen before resume**:

1. Re-run HL-8 and HG-7 with `tolerance = 1e-8` as specified in test-spec.
2. If both pass at `1e-8`: tester updates audit.md with correct tolerances and re-submits (verdict PASS).
3. If either fails at `1e-8`: tester documents the failure with the observed difference, emits BLOCK, and builder investigates the discrepancy or the user must explicitly authorize the relaxation to `1e-6` by appending a resolution to `decisions-calibrate-unit-scale.md` before the pipeline resumes.

## Decision

STOP. The tester relaxed HL-8 and HG-7 from `1e-8` (test-spec) to `1e-6` (audit) without a user-authorized decision entry in `decisions-calibrate-unit-scale.md`. All other checks pass. The pipeline halts until the tolerance is re-verified at the specified level or the user explicitly authorizes the relaxation.
