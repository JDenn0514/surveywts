# Spec Review: sdr-normal-hadamard — Pass 1 (2026-09-03)

Six lenses, two reviewers, plus an orchestrator verification pass. Detail:

- `.surveywts-workspace/runs/2026-09-03-sdr-normal-hadamard/review-1-3.md` —
  DRY, Test Completeness, Contract Completeness
- `.surveywts-workspace/runs/2026-09-03-sdr-normal-hadamard/review-4-6.md` —
  Edge Cases, Engineering Level, API Coherence
- `.surveywts-workspace/runs/2026-09-03-sdr-normal-hadamard/review-orchestrator-checks.md`
  — three findings re-measured and confirmed
- `.surveywts-workspace/runs/2026-09-03-sdr-normal-hadamard/corrections-pass-2.md`
  §C4 — a fourth correction found during the cross-artifact check

## Summary

| Severity | Lenses 1–3 | Lenses 4–6 | Total |
|---|---|---|---|
| BLOCKING | 0 | 0 | **0** |
| REQUIRED | 6 | 6 | **12** |
| SUGGESTION | 8 | 5 | **13** |

**Verdict: BLOCK** — no blocking issue, but twelve REQUIRED findings, all
UNAMBIGUOUS. The design is sound and implementable. Every finding is in the
stated facts, the documentation weight, or the test plan.

## The one pattern behind most of it

Six of the twelve REQUIRED findings share a cause. A number was measured on
one design, or across one sweep range, and then written into the spec as
though it were a property of the method.

| Claim | Measured on | True range |
|---|---|---|
| Inactive count is 0 or 1 | singleton PSUs | 1, 1, 2, 2, 4 on 20 PSUs |
| Variance-neutral | a total | fails for a mean |
| 28% gap, "stratified" | 480 singleton PSUs | set by PSU count, not strata |
| `degf` is 62/63 and 126/127 | 9999 PSUs | 18/19 on 20 PSUs |
| Reaches 4…256 "only" | a sweep stopping at 256 | `4 x 2^k`, no bound |
| `mse = FALSE` gap of 11–20% | unreproducible design | 0.041% on the fixture |

**Rule for the resolve pass: every table names the design it was measured on
and the range it covers. Every claim states the invariant, not the reading.**
The invariant for `degf` is a difference of one, not the pair 62 and 63.

## REQUIRED findings

Fix each in the file named. Full text in the two detail documents.

### Wrong or unqualified facts

1. **Issue 1 (L6)** — "reaches 4, 8, 16, 32, 64, 128 and 256 **only**" is
   false. Measured: `replicates = 260` returns 512. Drop "only"; state
   `4 x 2^k`. Ships in `@param`, the Algorithm sub-section and `NEWS.md`.
2. **Issue 11 (L3)** — measured fact 6 and the Returns contract give bare
   `degf` numbers with no design named. They hold on `cps_2023`; the fixture
   gives 18 and 19. State the invariant: the normal path gives one more.
3. **Issue 12 (L3)** — measured fact 4's first column is headed "Order" but
   holds `replicates`, which contradicts measured fact 1. The test-spec is
   right; the spec is mislabelled.
4. **C4** — replace the four unreproducible `mse = FALSE` variances with the
   fixture measurements: 742.9117643034 against 742.6073120709, ratio
   0.99959019, constant across orders 20 to 128. Drop the 11% and 20% figures.

### Unreachable or contradictory contract rows

5. **Issue 2 (L4)** — the zero-base-weight row is unreachable;
   `surveycore::as_survey()` rejects non-positive weights. Split the row: zero
   unreachable, NA reachable and unchanged.
6. **Issue 8 (L6)** — `create_sdr_weights()` inherits its Messages section
   from `create_gen_boot_weights.R:90`, which states "`replicates = 100` gives
   128" without condition. That becomes false at `use_normal_hadamard = TRUE`,
   where it gives 104 — the number the test-spec pins. Add
   `R/create_gen_boot_weights.R` to the Architecture table and make the
   sentence conditional. The section renders on six help pages. This is the
   same test that pulled the `\deqn` bug into scope.
7. **Issue 6 (L4)** — quality gate 16 has no Architecture row. `NEWS.md:96-99`
   still says the function "does not forward" the argument.

### Documentation weight

8. **Issue 9 (L6)** — the proposed `@param` runs 13 lines against a family
   maximum of 6, carries three measured percentages and a recommendation, and
   inlines content it then forward-references. The family's shape for this kind
   of argument is `variance_estimator`: a short `@param`, with the decision
   content in its own section.
9. **Issue 13 (L3)** — the spec gives verbatim code for eight cosmetic edits
   and for the `params` list, which reaches only the weighting history, while
   the `svrep::as_sdr_design()` call that actually fixes #119 is left in prose.
   Invert that.
10. **Repetition (L5)** — the PSU-count rule appears six times, four of them in
    shipped text. Say it once in the Algorithm section.

### Test plan

11. **Issue 5 (L2)** — the only executability defect. The `degf` block builds
    two designs at `replicates = 128L` and then asserts four rows, two of them
    at order 64. Build four designs. The pinned values are correct.
12. **Issues 1 and 2 (L1)** — `make_cps_taylor()` is duplicated inline across
    five blocks; `helper-test-data.R` is where the standard puts it. The
    "Positional safety" block is a verbatim copy of the default oracle block,
    itself a third copy of `test-replicate-weights.R:1160`, and it passes every
    argument by name, so it tests nothing positional.

## Verified clean

- **No cross-artifact drift.** Every pinned number appears with identical
  digits in the spec and the test-spec. The Lens 1–3 reviewer reproduced all of
  them against svrep 0.9.1, independently of the orchestrator.
- **No assertion would fail on a correct implementation.** Every tolerance is
  looser than the precision of the value it pins. The `as_svydesign()` round
  trip preserves `mse`, `scale` and `degf`.
- **Tier 3 is the right assignment.** `@section Algorithm`, `@details` and
  `@references` are all present. No `@section Convergence` is needed.
- **The new error class row** is present and well formed at
  `plans/error-messages.md:144`.
- **API surface is coherent.** Placement, `params`, return class and the
  dispatcher forwarding match `tau` and `balanced` exactly. The break is in
  documentation register, not in the API.
- **Engineering level is right-sized.** The code the spec asks for is
  proportionate. Only the documentation is over-weight.

## Two counter-findings

- **The sweep seed is recorded.** The test-spec declines to pin the six sweep
  standard errors because "the record does not name the seed". It does now —
  `seed = 42L`, added to `corrections-pass-2.md` after the resolve pass ran —
  and all twelve values reproduce exactly. As it stands, the three percentages
  in the help page and `NEWS.md` are asserted by no test. Pin them, but assert
  the boundary rather than a monotone rule: the ratios are 1.0000, 1.0000,
  0.9790, 0.9472, 0.9696, 0.8523, and 240 PSUs reads above 160.
- **The `.validate_logical_flag()` deferral is sound on scope**, but its stated
  reason — `ipw()` snapshot churn — is avoidable with
  `call = rlang::caller_env()`. Unlike the `check_dots_empty()` gap it carries
  no issue number, so it cannot be found again. File one or state the real
  reason.
