# Feature PR Template

Used for all PRs targeting `develop`.

---

## What

<!-- One sentence: what does this PR add or fix? -->

## Checklist

- [ ] Tests written and passing (`devtools::test()`)
- [ ] R CMD check: 0 errors, 0 warnings (`devtools::check()`)
- [ ] Roxygen docs updated and `devtools::document()` run
- [ ] `plans/error-messages.md` updated (if new errors/warnings added)
- [ ] `VENDORED.md` updated (if variance code vendored in this PR)
- [ ] PR title is a valid Conventional Commit (`feat(scope): description`)
- [ ] PR targets `develop`, not `main`
