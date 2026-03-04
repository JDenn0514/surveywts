# surveyweights GitHub Strategy

<!-- Applies to the surveyweights package. Adapted from the surveycore version. -->
<!-- Read on-demand when creating PRs or setting up CI — not auto-loaded. -->

**Version:** 2.0
**Status:** Decided — do not re-litigate without updating this document

---

## Quick Reference

| Decision | Choice |
|----------|--------|
| Branching model | `develop` integration branch — features → `develop`; `develop` → `main` for releases |
| Branch naming | `feature/`, `fix/`, `hotfix/`, `docs/`, `chore/`, `refactor/` |
| Merge strategy | Squash and merge everywhere |
| Commit format | Conventional Commits (`feat:`, `fix:`, `docs:`, `test:`, `chore:`) |
| PR granularity | One PR per logical unit of work |
| Versioning | `X.Y.Z.9000` on `develop`; `X.Y.Z` on `main` after release |
| CI | R-CMD-check required on `main` and `develop`; all PRs |
| Release workflow | Use `/merge-main` |

---

## Workflow Tiers

Choose the tier based on change size. When in doubt, go one tier higher.

| Tier | When to use | Workflow |
|------|-------------|----------|
| **1 — Full** | New phases, new exported functions, new S7 classes, anything where correct behavior is undecided | spec → implementation plan → `/r-implement` → `/commit-and-pr` |
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
feature/phase0-rake
fix/weighted-df-history
test/calibrate-edge-cases
chore/ci-coverage-workflow
docs/readme-examples
```

---

## Commit Format (Conventional Commits)

```
{type}({scope}): {short description}
```

### Types

| Type | Use for |
|------|---------|
| `feat` | New exported function, new class, new property |
| `fix` | Bug fix (behavioral change to existing code) |
| `docs` | Roxygen comments, README, vignettes, plans |
| `test` | Adding or updating tests (no production code change) |
| `chore` | CI config, DESCRIPTION, NAMESPACE, build tooling |
| `refactor` | Internal restructuring with no behavioral change |
| `perf` | Performance improvement |

### Scopes

`classes`, `constructors`, `validators`, `weights`, `calibration`, `utils`, `ci`

### Examples

```
feat(calibration): implement rake() with iterative proportional fitting
feat(classes): add weighted_df S3 class with weighting_history attribute
fix(calibration): handle single-level target variable in poststratify()
test(calibration): add edge case tests for zero-weight rows in rake()
docs(calibration): add tidy-select examples to calibrate() roxygen
chore(ci): add test-coverage GitHub Actions workflow
chore(description): bump version to 0.1.0 for Phase 0 release
```

### Squash merge commit message

Write it as a conventional commit summarizing the whole PR:
```
feat(calibration): implement rake() with iterative proportional fitting (#12)
```
GitHub auto-appends `(#PR_NUMBER)` if you set the PR title as a conventional commit.

---

## PR Template

`.github/PULL_REQUEST_TEMPLATE.md`:

```markdown
## What

<!-- One sentence: what does this PR add or fix? -->

## Checklist

- [ ] Tests written and passing (`devtools::test()`)
- [ ] R CMD check: 0 errors, 0 warnings (`devtools::check()`)
- [ ] Roxygen docs updated and `devtools::document()` run
- [ ] `plans/error-messages.md` updated (if new errors/warnings added)
- [ ] PR title is a valid Conventional Commit (`feat(scope): description`)
```

Changelog entry format (required before every PR) is defined in
`.claude/skills/changelog-workflow.md`.

---

## Merge Strategy

**Squash and merge** on all PRs. Configure in GitHub → Settings → Pull Requests:
- [x] Allow squash merging
- [ ] Allow merge commits *(disable)*
- [ ] Allow rebase merging *(disable)*
- [x] Automatically delete head branches

---

## Versioning

| Context | Format | Example |
|---------|--------|---------|
| Active development on `develop` | `X.Y.Z.9000` | `0.1.0.9000` |
| Released on `main` | `X.Y.Z` | `0.1.0` |

### Phase → version mapping

| Tag | DESCRIPTION version | What it means |
|-----|---------------------|---------------|
| `v0.1.0` | `0.1.0` | Phase 0 complete — `weighted_df`, `survey_calibrated`, `calibrate()`, `rake()`, `poststratify()`, basic diagnostics |
| `v0.2.0` | `0.2.0` | Phase 1 complete — replicate weight generation + bootstrap variance |
| `v0.3.0` | `0.3.0` | Phase 2 complete — propensity score weighting |
| `v0.4.0` | `0.4.0` | Phase 3 complete — advanced calibration |
| `v0.5.0` | `0.5.0` | Phase 4 complete — diagnostics, `trim_weights()`, `stabilize_weights()` |
| `v1.0.0` | `1.0.0` | Phase 5 complete — vignettes, CRAN submission |

### Dev version during a phase

Between tags, DESCRIPTION carries the `.9000` suffix:
```
Version: 0.1.0.9000  # during Phase 0 development
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
| `R-CMD-check.yaml` | Push to any branch, PR to `main` or `develop` |
| `test-coverage.yaml` | Push to `main` or `develop`, PRs |
| `pkgdown.yaml` | Push to `main` only |

### R-CMD-check matrix

```yaml
# Matrix: {os: [ubuntu-latest, windows-latest, macos-latest], r: [release, devel]}
```

### Required status checks for branch protection

Set `R-CMD-check (ubuntu-latest, release)` as the required status check for
both `main` and `develop`. Windows and macOS checks are informational.

### Branch protection settings

For both `main` and `develop` (GitHub → Settings → Branches):
- **Require status checks to pass before merging:** ✅
- **Require branches to be up to date before merging:** ✅
- **Require pull request reviews before merging:** ❌ (solo author)
- **Allow force pushes:** ❌
- **Allow deletions:** ❌
