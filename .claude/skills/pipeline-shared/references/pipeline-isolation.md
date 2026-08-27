# Pipeline Isolation

Information barriers between the code, test, and convergence roles. The
orchestrating skill enforces these at dispatch time — if an agent is given the
wrong artifact, the barrier has been violated.

## Why isolation matters

If the builder knows exactly which scenarios the tester will run, it can "teach
to the test" — ship code that passes specified inputs without implementing the
behavior correctly. If the tester knows how the code works internally, it can't
provide independent verification. The separation forces each side to converge on
the same answer from independent premises.

For survey statistics, this matters more than in most packages. Calibration,
variance estimation, and propensity weighting can produce plausible-looking but
wrong numbers. The only protection is independent verification.

## Who receives what

| Agent | Reads | Never reads | Writes |
|-------|-------|-------------|--------|
| planner | `request.md`, `impact.md`, `comprehension.md` (its own), target repo | `implementation.md`, `audit.md` | `comprehension.md`, `spec-{id}.md`, `test-spec-{id}.md`, `impl-{id}.md` |
| builder | `spec-{id}.md`, `impact.md`, `request.md`, `CLAUDE.md`/`core.md` (auto-loaded), its standards files (read via its own Step 0 — not auto-loaded) | `test-spec-{id}.md`, `audit.md`, `review.md` | code, `implementation.md` |
| tester | `test-spec-{id}.md`, `impact.md`, `request.md`, `CLAUDE.md`/`core.md` (auto-loaded), its standards files (read via its own Step 0 — not auto-loaded) | `spec-{id}.md`, `implementation.md`, `review.md` | `audit.md` |
| reviewer | ALL artifacts | — | `review.md` |
| shipper | `review.md` (verdict=PASS), branch metadata, CI status | `spec-{id}.md`, `test-spec-{id}.md`, `implementation.md`, `audit.md` | commit, PR, `shipper.md` |

## Enforcement rules

1. **Planner produces two independent documents.** `spec-{id}.md` and
   `test-spec-{id}.md` must each be sufficient on its own. No cross-references
   like "see test-spec for scenarios" or "see spec for function contract." Each
   reader must be able to do their job with only the artifact they were given.

2. **Orchestrating skills include only the permitted artifacts in the dispatch
   prompt.** When dispatching builder, the skill MUST include `spec-{id}.md`
   path and MUST NOT mention `test-spec-{id}.md` exists. Same for tester in
   reverse.

3. **Tester writes what it observed, not what it expected the code to do.**
   `audit.md` describes the system under test's behavior against
   `test-spec-{id}.md` scenarios. It does not say "the function probably
   computes X" — that would require knowing the implementation.

4. **Builder does not read `audit.md` after a BLOCK.** Only the BLOCK message
   itself (failing scenario, observed vs expected, classification) is passed
   back. See `signals.md` BLOCK section.

5. **Reviewer is the single convergence point.** Only the reviewer is allowed
   to read `implementation.md` AND `audit.md` together. This is what makes
   convergence checks meaningful.

## Violations

If an agent is found to have read a forbidden artifact (inferred from its output
mentioning specifics only available there), the orchestrating skill MUST:

1. Discard the agent's output
2. Re-dispatch with a fresh session (no continued context)
3. Log the violation in `decisions-{id}.md`

## Simplified workflow exception

In simplified mode (see `skills/pipeline-simplified/SKILL.md`), there is no
`spec-{id}.md` / `test-spec-{id}.md` split. Builder and tester both read
`request.md` (with acceptance criteria). Pipeline isolation is relaxed because
the change is small and isolation's value is smaller than its friction.

The reviewer role is also skipped in simplified mode; tester is the quality
gate. This is acceptable only because the smallness criteria exclude algorithmic
and numerical changes where independent convergence matters most.
