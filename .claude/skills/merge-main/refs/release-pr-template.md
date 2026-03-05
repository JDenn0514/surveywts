# Release PR Template

Title: `chore(release): bump version to X.Y.Z`

---

## Release: vX.Y.Z

## What's in this release

<!-- Paste the new NEWS.md section here -->

## Release checklist

- [ ] All planned feature PRs are merged to `develop`
- [ ] NEWS.md updated with all `feat:` and `fix:` entries since last release
- [ ] DESCRIPTION version bumped: `X.Y.Z.9000` → `X.Y.Z`
- [ ] `devtools::check()` passes: 0 errors, 0 warnings, ≤2 notes
- [ ] After merge: tag `vX.Y.Z` on main
- [ ] After tagging: bump `develop` to `X.Y.Z.9000`
