# Signal System

Three named signals govern all inter-agent and agent-to-user communication.
Every pause, block, or halt in the pipeline MUST use one of these. No ad-hoc
`AskUserQuestion` calls.

## HOLD

**Emitted by:** any agent (planner, builder, tester, reviewer, shipper)
**Means:** I cannot proceed without a decision from the user.
**Outcome:** pipeline pauses at current state. User resolves. Pipeline resumes.

### Valid triggers

- **planner**: methodology ambiguity; user must choose between two defensible designs
- **builder**: spec is silent on a behavioral decision the implementation forces
- **tester**: test-spec is silent on how to handle an unanticipated numerical result
- **reviewer**: cross-artifact inconsistency that may reflect a genuine choice, not a bug
- **shipper**: CI failure whose cause is unclear (flake vs real); user approval needed

### Required body

Write to `decisions-{id}.md` AND return to leader:

```
## HOLD — {agent} — {YYYY-MM-DD HH:MM}

**Where**: {stage, file, PR, test name as applicable}
**What**: One-sentence description of the open question
**Why I can't decide**: Which authority or input is missing
**Options** (if any): Enumerate with tradeoffs
**What I need**: One sentence — the exact input required to resume
```

## BLOCK

**Emitted by:** tester only
**Means:** Code does not satisfy the test-spec.
**Outcome:** builder is re-dispatched for this PR with the `audit.md` BLOCK body
(NOT the full audit.md, NOT the test-spec — isolation preserved). Max 3 BLOCK
cycles per PR.

### Valid triggers

- A numerical test failed outside tolerance
- A named error class test failed (wrong class thrown, or no error thrown)
- `R CMD check --as-cran` has ERROR or WARNING
- `pkgdown::build_site()` errored (when not skipped)
- Coverage dropped below 95%

### Required body

Tester writes `audit.md` with verdict=BLOCK and:

```
## BLOCK — {YYYY-MM-DD HH:MM}

**Failing scenario**: {name from test-spec, or profile command}
**Observed**: {value, class, message}
**Expected**: {value, class, tolerance}
**Classification**: numerical-miss | contract-miss | profile-fail | coverage-drop
**What builder must fix**: One sentence
```

Tester does NOT tell builder *how* to fix. Tester does NOT suggest code.
Tester reports what failed against what was specified.

### Escalation

After 3 BLOCKs on the same PR, tester escalates to HOLD with classification
`repeated-block` and the user decides: extend cycles, re-spec, or abandon.

## STOP

**Emitted by:** reviewer only
**Means:** The change is unsafe to ship.
**Outcome:** pipeline halts entirely. User must explicitly override in
`decisions-{id}.md` with justification.

### Valid triggers

- Tester relaxed a tolerance below what `test-spec-{id}.md` specified (Tolerance
  Integrity violation)
- Tester skipped a required test
- Builder implemented behavior not in the spec (scope creep)
- Builder implemented spec but audit shows a regression in a test NOT in scope
- Coverage dropped below 95% AND the uncovered lines are in new code
- Profile gate failed in a way that audit labeled as non-blocking (reviewer disagrees)

### Required body

Reviewer writes `review.md` with verdict=STOP and:

```
## STOP — {YYYY-MM-DD HH:MM}

**Category**: {tolerance-relaxation | test-skip | scope-creep | unflagged-regression | coverage-floor | gate-misclassification}
**Evidence**: direct quote or diff from the offending artifact
**Why this is unsafe**: One paragraph
**What must happen before resume**: Exact fix, as a list
```

Shipper refuses to run when the latest `review.md` verdict is STOP. Period.

## Resume protocol

After the user resolves a HOLD or overrides a STOP, the resolving decision is
appended to `decisions-{id}.md`:

```
## Resolution — {YYYY-MM-DD HH:MM}

**Signal resolved**: {HOLD or STOP reference}
**Decision**: One sentence
**Authorized by**: user
**Resume from state**: {state name}
```

The skill then advances the pipeline from the recorded state.
