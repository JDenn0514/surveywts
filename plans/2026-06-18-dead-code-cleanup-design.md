# Dead Code Cleanup — `utils.R` and `calibrate-utils.R`

**Date:** 2026-06-18
**Scope:** `R/utils.R`, `R/calibrate-utils.R`, `R/calibrate_rake.R` (call sites only)
**Type:** Chore — no behavioral changes

---

## Background

Several dead code artifacts accumulated when `calibrate_greg.R` was deleted in PR 4
(commit a603ecc). The `calibrate_greg()` implementation was replaced with
`calibrate_linear()`, `calibrate_logit()`, and a refactored `calibrate_rake()` that
owns its own anesrake engine helpers directly. The old code paths in `.calibrate_engine()`
were left in place with `# nocov` markers but never removed.

A secondary issue: `.validate_reference_design()` was defined in both `calibrate-utils.R`
and `utils.R`. Because there is no `Collate:` field in DESCRIPTION, R loads files
alphabetically and `utils.R` silently overwrites the `calibrate-utils.R` copy. The
`calibrate-utils.R` copy is dead.

---

## Dead Code Criteria

Five lenses, from most to least certain:

1. **Explicit `# nocov start/end` with "unreachable via any current public API" comment** —
   delete without further verification.

2. **Same function name defined in two files in the same package** — identify which is live
   (last file alphabetically wins when no `Collate:` is present), delete the shadowed copy.

3. **Stale comments referencing deleted functions** — update to name current callers.

4. **Function arguments unused after dead branch removal** — drop the argument from
   internal (`.`-prefixed) functions; flag for review if exported.

5. **Functions whose only callers are themselves dead** — transitively dead; remove.

---

## Section 1: What to Delete

### 1a. Dead branches in `.calibrate_engine()` — `R/utils.R`

All three blocks are wrapped in `# nocov start/end` with the comment:
> "These branches (linear, logit, ipf, poststratify) were called exclusively by
> calibrate_greg.R, which was deleted in PR 4."

| Branch | Lines (approx) | Mechanism |
|--------|----------------|-----------|
| `type %in% c("linear", "logit")` | ~150 | Called `survey::calibrate()` via `cal.linear`/`cal.logit` |
| `type == "ipf"` | ~72 | Called `survey::rake()` |
| `type == "poststratify"` | ~30 | Called `survey::postStratify()` |
| Catch-all `cli_abort` at end | ~9 | Only reachable via the above dead branches |

After deletion, `.calibrate_engine()` contains only:
- The `maxit == 0` guard → `.throw_not_converged_zero_maxit()`
- The `anesrake` branch (the only live path)

### 1b. Dead branch in `.throw_not_converged_zero_maxit()` — `R/utils.R`

The `if (method %in% c("linear", "logit"))` block (~8 lines) is wrapped in
`# nocov start/end`. After removal, `method` is no longer used and must be dropped
from the function signature.

### 1c. Shadowed `.validate_reference_design()` — `R/calibrate-utils.R`

This function (~22 lines) is defined in both `calibrate-utils.R` and `utils.R`.
Since `utils.R` loads after `calibrate-utils.R` alphabetically, only the `utils.R`
version is ever called. Delete the `calibrate-utils.R` copy.

### 1d. Stale header comment — `R/calibrate-utils.R`

Line 4: `"Used by calibrate_greg() and calibrate_rake()."` → `calibrate_greg()` no
longer exists. Update to name the current callers.

---

## Section 2: What to Rename and Move

### 2a. Rename `.calibrate_engine()` → `.anesrake_engine()`

After removing the dead branches, `.calibrate_engine()` is exclusively an anesrake
wrapper. Renaming it `.anesrake_engine()` makes its relationship to `.calibrate_nr_engine()`
explicit (both are algorithm-specific engines) and eliminates the misleading implication
that it is a general-purpose dispatcher.

### 2b. Move `.anesrake_engine()` to `calibrate-utils.R`

It belongs alongside `.calibrate_nr_engine()` in the calibration-family utils file,
not in the cross-family `utils.R`.

### 2c. Move `.throw_not_converged_zero_maxit()` to `calibrate-utils.R`

This function's only caller is `.anesrake_engine()`. It is a calibration-family
internal. Move it with `.anesrake_engine()`.

### 2d. Drop `method =` argument from both functions

`.anesrake_engine()` no longer uses `method` (the dead branch was the only user).
`.throw_not_converged_zero_maxit()` no longer needs `method` either.

**Call sites to update in `calibrate_rake.R`:**
- Line 401: `.calibrate_engine(data_df, ..., method = engine_method, ...)` →
  `.anesrake_engine(data_df, ..., ...)` (drop `method =`, no other changes)
- Line 589 (inside replicate loop): same pattern

### 2e. Update comments

| File | What |
|------|------|
| `utils.R` — table-of-contents | Remove `.calibrate_engine()` entry; it no longer lives here |
| `calibrate-utils.R` — header | Replace `"Used by calibrate_greg() and calibrate_rake()"` with `"Used by calibrate_rake(), calibrate_linear(), and calibrate_logit()"` |
| `calibrate-utils.R` | Add `.anesrake_engine()` and `.throw_not_converged_zero_maxit()` to the function list |

---

## Section 3: What Does NOT Change

- `.calibrate_nr_engine()` — live, unchanged
- All `calibrate-utils.R` functions other than `.validate_reference_design()` — unchanged
- All `utils.R` functions other than the two being moved — unchanged
- `calibrate_rake.R` — only the two `.calibrate_engine()` call sites are touched (rename + drop arg)
- No behavioral changes anywhere — this is pure dead code removal and reorganization
- No tests need to change (the dead branches had no test coverage by design)
- No exports change
- No roxygen changes needed (all affected functions are internal with `@noRd`)

---

## Verification Checklist (post-implementation)

- [ ] `grep -r "calibrate_engine" R/` returns no results
- [ ] `grep -r "calibrate_greg" R/` returns no results
- [ ] `.validate_reference_design` appears in exactly one file in `R/`
- [ ] `devtools::check()` passes with 0 errors, 0 warnings
- [ ] `devtools::test()` passes (no test changes expected)
- [ ] Coverage does not drop (no tested code was removed)
