# Submitting and Responding to CRAN

## The submission workflow

### Before you submit

- All checks pass: 0 errors, 0 warnings, NOTEs explained or fixed
- Preflight checklist complete
- `cran-comments.md` written and reviewed
- Version bumped: `usethis::use_version()` (removes `.9000` dev suffix)
- NEWS.md updated for this version

### Submitting

```r
devtools::submit_cran()
```

This builds the source tarball, posts it to CRAN's submission form, and
writes a `CRAN-SUBMISSION` file recording the commit SHA and submission
timestamp. Do not delete this file — it's used by post-acceptance steps.

Alternatively, submit manually at https://cran.r-project.org/submit.html.

### Email confirmation

After submission you will receive a confirmation email from CRAN. You must
click the link in that email to complete the submission. Without this step,
CRAN never receives your package.

### What happens next

1. Automated checks run on CRAN's infrastructure (Windows, Linux). Results
   appear within a few hours at https://cran.r-project.org/incoming/.
2. A human reviewer examines the package, typically within 1–5 business days.
3. CRAN emails you: accepted, accepted with comments, or rejected with
   required changes.

### Spacing between submissions

Do not submit more than once every 30 days for the same package, and not
more than once per 24 hours. Resubmissions for fixing reviewer feedback are
exempt from the 30-day rule, but bump the version (`0.1.0` → `0.1.1`) and
include a resubmission section in `cran-comments.md`.

---

## `cran-comments.md`

Keep it crisp, factual, and minimal. CRAN reviewers read many of these.

### Template

```markdown
## Test environments
* local macOS, R x.y.z
* GitHub Actions (ubuntu-latest, macos-latest, windows-latest)
* win-builder (R-devel)

## R CMD check results
0 errors | 0 warnings | 0 notes

## Reverse dependencies
None. This is a new package with no dependents.

## Comments
- [1–3 bullets summarizing what changed or what this submission is]
- [Any NOTE with explanation: what it is, why it's expected, what you did]
```

For resubmissions, add:

```markdown
## Resubmission

This is a resubmission. Changes in response to reviewer feedback:

* Reviewer comment 1:
  - Action taken: [what you changed]
  - Where to see it: [file/function, e.g., DESCRIPTION, man/foo.Rd]

* Reviewer comment 2:
  - Action taken:
  - Where to see it:
```

### Writing NOTEs in cran-comments.md

Keep a NOTE only if it is genuinely unavoidable. For each retained NOTE:

1. **What is the NOTE?** Quote it briefly.
2. **Why does it happen?** One sentence.
3. **Why is it safe / expected?** One sentence.
4. **What did you do to minimize it?** One sentence, or "N/A".

```markdown
## Notes

* "checking installed package size ... NOTE"
  The package includes example datasets totalling 2.3 MB. These are required
  for the vignettes to run without network access. We have compressed all
  datasets to the minimum usable size.
```

---

## Responding to reviewer feedback

CRAN reviewers send their feedback by email. The tone is terse; this is normal.

**The goal of a response is not to argue — it is to demonstrate that every
point has been addressed.**

For each reviewer comment:
1. Quote the request briefly (one line or a few words)
2. State exactly what you changed
3. Point to the file and function where the change is visible

```markdown
## Resubmission

> Please add \value tags to exported functions.

Added @return documentation to all 12 exported functions. See man/*.Rd.

> The Description field starts with the package name.

Rewrote Description field. See DESCRIPTION.

> Examples write to the current directory.

Replaced write.csv() with withr::local_tempfile() in all three examples.
See R/export.R lines 42–56.
```

**Avoid:**
- Explaining why you originally did it the way you did
- Asking for clarification via email (fix the most likely interpretation, note
  your interpretation in cran-comments.md)
- Waiting more than 48 hours to respond

---

## Post-acceptance

Once CRAN accepts the package:

**1. Create a GitHub release**

```r
usethis::use_github_release()
```

This uses the `CRAN-SUBMISSION` file to tag the exact commit that was accepted.

**2. Bump to a dev version**

```r
usethis::use_dev_version(push = TRUE)
```

This sets DESCRIPTION to `0.1.0.9000` (or whatever the next dev version is),
committing and pushing so it's clear the main branch is now ahead of CRAN.

**3. Monitor CRAN checks**

CRAN continues running checks on accepted packages across platforms. Watch
the package's CRAN check page for the first few days. Failures that appear
post-acceptance require a patch release.

**4. Notify reverse dependencies (updates only)**

If your update changes exported APIs in a breaking way, notify maintainers of
affected packages at least two weeks before submission. CRAN expects this.
Use `revdepcheck::revdep_check()` to identify affected packages.
