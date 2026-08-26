# surveywts GitHub Strategy

**Version:** 2.1
**Status:** Decided — do not re-litigate without updating this document

## Quick Reference

| Decision | Choice |
|----------|--------|
| Branching model | `develop` integration branch — features → `develop`; `develop` → `main` for releases |
| Branch naming | `feature/`, `fix/`, `hotfix/`, `docs/`, `chore/`, `refactor/` |
| Merge strategy | Squash for feature PRs; merge commit for release PRs |
| Commit format | Conventional Commits (`feat:`, `fix:`, `docs:`, `test:`, `chore:`) |
| PR granularity | One PR per logical unit of work |
| Versioning | `X.Y.Z.9000` on `develop`; `X.Y.Z` on `main` after release |
| CI | R-CMD-check required on `main` and `develop`; all PRs |
| Release workflow | Use `/merge-main` |

## Workflow tiers

Choose by change size. When in doubt, go one tier higher.

| Tier | When to use | Workflow |
|------|-------------|----------|
| **1 — Full** | New releases, new exported functions, new S7 classes, anything where correct behavior is undecided | spec → implementation plan → `/r-implement` → `/commit-and-pr` |
| **2 — Plan only** | Medium bug fixes, new arguments, edge case additions — behavior obvious, approach isn't | implementation plan → `/r-implement` → `/commit-and-pr` |
| **3 — Direct** | Clear bug fixes localized to 1–2 functions, test additions, roxygen changes | branch → `/r-implement` → `/commit-and-pr` |
| **0 — Commit** | Typos, comments, `.gitignore`, README tweaks | direct commit to `develop` (no branch) |

## Branching model

```
main          ← always stable; every commit is a tagged release
  ↑
develop       ← integration branch; all feature work lands here first
  ↑
feature/*     ← individual units of work; branch from develop
hotfix/*      ← urgent fixes only; branch from main
```

Feature branches always cut from `develop` and merge back to `develop`.
Never open a feature PR directly against `main`. Hotfixes branch from
`main`, merge to `main`, then immediately open a second PR into `develop` to
stay in sync — never leave `main` ahead of `develop`.

**Required check before any release PR:** run
`git log origin/develop..origin/main --oneline`. If it shows anything, sync
`develop` first.

### What gets a branch vs. direct push

| Change type | Branch needed? |
|-------------|----------------|
| New R source file, new test file, any exported-function change | Yes |
| README/docs update, comment or typo fix, `.Rbuildignore`/`.gitignore` | No |
| Version bump + NEWS.md (release prep) | Direct commit to `develop` |

## Branch naming

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

## Commit format (Conventional Commits)

`{type}({scope}): {short description}`

| Type | Use for |
|------|---------|
| `feat` | New exported function, new class, new property |
| `fix` | Bug fix (behavioral change to existing code) |
| `docs` | Roxygen comments, README, vignettes, plans |
| `test` | Adding or updating tests (no production code change) |
| `chore` | CI config, DESCRIPTION, NAMESPACE, build tooling |
| `refactor` | Internal restructuring with no behavioral change |
| `perf` | Performance improvement |

Scopes: `classes`, `constructors`, `validators`, `weights`, `calibration`,
`utils`, `ci`.

## Merge strategy and versioning

- **Feature → `develop`:** squash and merge — consolidates WIP commits into
  one clean commit. The squash message is a conventional commit summarizing
  the whole PR; GitHub auto-appends `(#PR_NUMBER)`.
- **`develop` → `main` (release):** merge commit — preserves git ancestry
  and prevents divergence.
- Versions: `X.Y.Z.9000` during development on `develop`; `X.Y.Z` on `main`
  after release, via `/merge-main`.

| Tag | DESCRIPTION version |
|-----|---------------------|
| `v0.1.0` | `0.1.0` — Calibration complete |
| minor bump | Replicate, Utilities, Nonresponse, Propensity, Diagnostics, Polish — one minor bump each, in that order |

Release prep: `/merge-main` handles NEWS.md update → version bump →
`devtools::check()` → PR `develop` → `main` → tag → post-release `.9000` bump.

---
Worked commit/branch examples, the PR template body, GitHub settings
checklists, and the CI matrix/branch-protection detail:
`.claude/references/github-strategy-detail.md`. Read it when choosing a
workflow tier for a borderline change or preparing a release.
