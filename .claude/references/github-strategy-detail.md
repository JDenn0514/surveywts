# GitHub Strategy — Worked Examples and Release Detail

Detail moved out of `.claude/rules/github-strategy.md`. The decision tables
live there; this file shows how to apply them. Read this when choosing a
workflow tier for a borderline change, or when preparing a release.

---

## Branch name examples

```
feature/calibration-core
feature/calibration-rake
fix/weighted-df-history
test/calibrate-edge-cases
chore/ci-coverage-workflow
docs/readme-examples
```

## Commit message examples

```
feat(calibration): implement rake() with iterative proportional fitting
feat(classes): add weighted_df S3 class with weighting_history attribute
fix(calibration): handle single-level target variable in poststratify()
test(calibration): add edge case tests for zero-weight rows in rake()
docs(calibration): add tidy-select examples to calibrate() roxygen
chore(ci): add test-coverage GitHub Actions workflow
chore(description): bump version to 0.1.0 for Calibration release
```

Squash merge commit message (feature PRs) — write it as a conventional
commit summarizing the whole PR:

```
feat(calibration): implement rake() with iterative proportional fitting (#12)
```

GitHub auto-appends `(#PR_NUMBER)` when the PR title is a conventional
commit.

## PR template

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

## GitHub settings

Configure in GitHub → Settings → Pull Requests:
- [x] Allow squash merging
- [x] Allow merge commits
- [ ] Allow rebase merging *(disable)*
- [x] Automatically delete head branches

The `/merge-main` skill chooses the correct merge strategy automatically.

## Release → version mapping

| Tag | DESCRIPTION version | What it means |
|-----|---------------------|---------------|
| `v0.1.0` | `0.1.0` | Calibration complete — `weighted_df`, `survey_nonprob`, `calibrate()`, `rake()`, `poststratify()`, basic diagnostics |
| minor bump | minor bump | Replicate complete — replicate weight generation + bootstrap variance |
| minor bump | minor bump | Utilities complete — `trim_weights()`, `rescale_weights()` |
| minor bump | minor bump | Nonresponse complete — sample-based calibration, advanced nonresponse |
| minor bump | minor bump | Propensity complete — propensity score weighting |
| minor bump | minor bump | Diagnostics complete — balance assessment, visual diagnostics |
| minor bump | minor bump | Polish complete — vignettes, CRAN submission |

Between tags, DESCRIPTION carries the `.9000` suffix:

```
Version: 0.1.0.9000  # during Calibration development
```

---

## CI/CD workflows

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
- **Require status checks to pass before merging:** yes
- **Require branches to be up to date before merging:** yes
- **Require pull request reviews before merging:** no (solo author)
- **Allow force pushes:** no
- **Allow deletions:** no
