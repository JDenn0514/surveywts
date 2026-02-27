# surveyweights GitHub Strategy

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

Hotfixes branch from `main`, merge to `main`, then also merge to `develop` to stay in sync.

### What gets a branch vs. direct push

| Change type | Branch needed? |
|-------------|----------------|
| New R source file | Yes |
| New test file | Yes |
| Any change to exported function | Yes |
| Vendor code addition | Yes |
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

---

## Commit Format (Conventional Commits)

```
{type}({scope}): {short description}
```

| Type | Use for |
|------|---------|
| `feat` | New exported function, new class, new property |
| `fix` | Bug fix (behavioral change to existing code) |
| `docs` | Roxygen comments, README, vignettes, plans |
| `test` | Adding or updating tests (no production code change) |
| `chore` | CI config, DESCRIPTION, NAMESPACE, build tooling |
| `refactor` | Internal restructuring with no behavioral change |

Scopes: `classes`, `constructors`, `validators`, `weights`, `calibration`, `utils`

Squash merge commit = one conventional commit summarizing the whole PR:
```
feat(calibration): implement rake() with iterative proportional fitting (#12)
```

---

## Merge Strategy

**Squash and merge** on all PRs. GitHub settings: allow squash only; auto-delete head branches.

`main` history = one commit per release. `develop` history = one commit per feature PR.

---

## Versioning

| Context | Format | Example |
|---------|--------|---------|
| Active development on `develop` | `X.Y.Z.9000` | `0.3.0.9000` |
| Released on `main` | `X.Y.Z` | `0.3.0` |

| Tag | Milestone |
|-----|-----------|
| `v0.1.0` | Phase 0 complete — calibration core (`survey_calibrated`, `calibrate`, `rake`, `poststratify`, basic diagnostics) |
| `v0.2.0` | Phase 1 complete — replicate weight generation + bootstrap variance for `survey_calibrated` |
| `v0.3.0` | Phase 2 complete — sample-based calibration + weighting-class nonresponse |
| `v0.4.0` | Phase 3 complete — propensity score weighting |
| `v0.5.0` | Phase 4 complete — diagnostics, `trim_weights()`, `stabilize_weights()` |
| `v1.0.0` | Phase 5 complete — vignettes, CRAN submission |

---

## Release Preparation

Use `/merge-main`. It handles: NEWS.md update → version bump → `devtools::check()` →
PR `develop` → `main` → tag → post-release `.9000` bump.

PR template for feature PRs lives in `.github/PULL_REQUEST_TEMPLATE.md`.
