# surveywts GitHub Strategy

<!-- Applies to the surveywts package. Adapted from the surveycore version. -->
<!-- Read on-demand when creating PRs or setting up CI — not auto-loaded. -->

---

## Quick Reference

| Decision | Choice |
|----------|--------|
| Merge strategy | Squash for feature PRs; merge commit for release PRs |
| PR granularity | One PR per logical unit of work |
| Versioning | `X.Y.Z.9000` on `develop`; `X.Y.Z` on `main` after release |
| CI | R-CMD-check required on `main` and `develop`; all PRs |
| Release workflow | Use `/merge-main` |

`core.md` §6 has the branch-prefix list and the Conventional Commits format.

---

## Workflow Tiers

Choose the tier based on change size. When in doubt, go one tier higher.

| Tier | When to use | Workflow |
|------|-------------|----------|
| **1 — Full** | New releases, new exported functions, new statistical methods, anything where correct behavior is undecided | spec → implementation plan → `/r-implement` → `/commit-and-pr` |
| **2 — Plan only** | Medium bug fixes, new arguments, edge case additions — behavior obvious, approach isn't | implementation plan → `/r-implement` → `/commit-and-pr` |
| **3 — Direct** | Clear bug fixes localized to 1–2 functions, test additions, roxygen changes | branch → `/r-implement` → `/commit-and-pr` |
| **0 — Commit** | Typos, comments, `.gitignore`, README tweaks | direct commit to `develop` (no branch) |

---

## Branching Model

```
main          ← always stable; every commit is a tagged release
  ↑
develop       ← integration branch; all feature work lands here first
  ↑
feature/*     ← individual units of work; branch from develop
hotfix/*      ← urgent fixes only; branch from main
```

Feature branches always cut from `develop` and merge back to `develop`.
Never open a feature PR directly against `main`.

Hotfixes branch from `main`, merge to `main`, then **immediately** open a
second PR from the hotfix branch (or `main`) into `develop` to stay in sync.
Do not leave `main` ahead of `develop` — this causes merge conflicts at
release time.

**Required check before any release PR:** run
`git log origin/develop..origin/main --oneline`. If it shows anything, sync
`develop` first.

### What gets a branch vs. direct push

| Change type | Branch needed? |
|-------------|----------------|
| New R source file | Yes |
| New test file | Yes |
| Any change to exported function | Yes |
| README / docs update | No |
| Comment or typo fix | No |
| `.Rbuildignore` / `.gitignore` | No |
| Version bump + NEWS.md (release prep) | Direct commit to `develop` |

---

## Branch Naming

Format: `{type}/{short-description}`

| Prefix | Target | Use for |
|--------|--------|---------|
| `feature/` | `develop` | New functionality |
| `fix/` | `develop` | Bug fix in existing implementation |
| `hotfix/` | `main` | Urgent fix that can't wait for next release |
| `docs/` | `develop` | Documentation-only changes |
| `test/` | `develop` | Test-only additions or fixes |
| `chore/` | `develop` | Maintenance (CI config, build tooling) |
| `refactor/` | `develop` | Internal restructuring, no behavioral change |

### Examples

```
feature/calibration-core
feature/calibration-rake
fix/history-timestamp
test/calibrate-edge-cases
chore/ci-coverage-workflow
docs/readme-examples
```

---

## Commit Format (Conventional Commits)

```
{type}({scope}): {short description}
```

`core.md` §6 has the valid scope list.

### Types

| Type | Use for |
|------|---------|
| `feat` | New exported function, new argument, new bundled dataset |
| `fix` | Bug fix (behavioral change to existing code) |
| `docs` | Roxygen comments, README, vignettes, plans |
| `test` | Adding or updating tests (no production code change) |
| `chore` | CI config, DESCRIPTION, NAMESPACE, build tooling |
| `refactor` | Internal restructuring with no behavioral change |
| `perf` | Performance improvement |

### Scopes

`classes` and `constructors` are retired scopes. surveywts defines no classes
and no constructors — see `surveywts-conventions.md` §6.

### Examples

```
feat(calibration): implement calibrate_rake() with iterative proportional fitting
feat(propensity): add ipw() with calibration GEE for exact covariate balance
fix(calibration): handle single-level target variable in poststratify()
test(calibration): add edge case tests for zero-weight rows in calibrate_rake()
docs(calibration): add targets format examples to calibrate() roxygen
chore(ci): add test-coverage GitHub Actions workflow
chore(description): bump version to 0.1.0 for Calibration release
```

### Squash merge commit message (feature PRs)

Write it as a conventional commit summarizing the whole PR:
```
feat(calibration): implement calibrate_rake() with iterative proportional fitting (#12)
```
GitHub auto-appends `(#PR_NUMBER)` if you set the PR title as a conventional commit.

---

## PR Template

See `.github/PULL_REQUEST_TEMPLATE.md` for the checklist every PR uses.

Changelog entry format (required before every PR) is defined in
`.claude/skills/changelog-workflow.md`.

---

## Merge Strategy

| PR type | Strategy | Why |
|---------|----------|-----|
| Feature → `develop` | **Squash and merge** | Consolidates WIP commits into a clean single commit |
| `develop` → `main` (release) | **Merge commit** | Preserves git ancestry between branches; prevents divergence |

The `/merge-main` skill handles choosing the correct strategy automatically.

---

## Versioning

| Context | Format | Example |
|---------|--------|---------|
| Active development on `develop` | `X.Y.Z.9000` | `0.1.0.9000` |
| Released on `main` | `X.Y.Z` | `0.1.0` |

### Release → version mapping

| Tag | DESCRIPTION version | What it means |
|-----|---------------------|---------------|
| `v0.1.0` | `0.1.0` | Calibration complete — `calibrate()`, `calibrate_rake()`, `poststratify()`, basic diagnostics |
| minor bump | minor bump | Replicate complete — replicate weight generation + bootstrap variance |
| minor bump | minor bump | Utilities complete — `trim_weights()`, `rescale_weights()` |
| minor bump | minor bump | Nonresponse complete — sample-based calibration, advanced nonresponse |
| minor bump | minor bump | Propensity complete — propensity score weighting |
| minor bump | minor bump | Diagnostics complete — balance assessment, visual diagnostics |
| minor bump | minor bump | Polish complete — vignettes, CRAN submission |

### Dev version during a release

Between tags, DESCRIPTION carries the `.9000` suffix:
```
Version: 0.1.0.9000  # during Calibration development
```

---

## Release Preparation

Use `/merge-main`. It handles: NEWS.md update → version bump → `devtools::check()` →
PR `develop` → `main` → tag → post-release `.9000` bump.

---

## CI/CD Workflows

### Active workflows

| Workflow | Trigger |
|----------|---------|
| `R-CMD-check.yaml` | Push to `main` or `develop`; PR to `main` or `develop` |
| `test-coverage.yaml` | Push to `main` or `develop`; PR to `main` or `develop` |
| `pkgdown.yaml` | Push to `main`; any PR; published release; manual dispatch |

R-CMD-check does **not** run on a push to a feature branch. It runs when the
PR opens. Run `devtools::check()` locally before pushing.

### R-CMD-check matrix

Four configurations, not the full os x version cross product. Only Ubuntu
runs R-devel. See `.github/workflows/R-CMD-check.yaml` for the matrix.

The check runs with `args: 'c("--as-cran", "--no-manual")'`.

### Required status checks for branch protection

The workflow names each job `${{ matrix.config.os }} (${{ matrix.config.r }})`,
so the status check to require is `R-CMD-check / ubuntu-latest (release)`, for
both `main` and `develop`. Windows and macOS checks are informational.
