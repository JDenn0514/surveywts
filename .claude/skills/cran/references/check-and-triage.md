# Running Checks and Triaging Results

## Part 1 — Running checks as CRAN

CRAN explicitly requires running `R CMD check --as-cran` on the source tarball
before submission. This section covers the workflow that gets as close as
possible to what CRAN will actually do.

### Recommended workflow

**1. Start from a clean state**

Work from a clean git checkout with no uncommitted changes. A clean library
helps you catch missing dependency declarations early.

**2. Build a source tarball**

```sh
R CMD build .
```

This produces `pkg_1.2.3.tar.gz`.

**3. Run `R CMD check --as-cran` on the tarball**

```sh
R CMD check --as-cran pkg_1.2.3.tar.gz
```

Why check the tarball rather than the source directory?
- Checks exactly what you will upload
- Avoids "works locally, fails from tarball" differences
- Mirrors CRAN's expectation

For faster iteration during development, use:
```r
devtools::check(args = "--as-cran")
```

But do the tarball check at least once before submission.

**4. Read the first real problem**

When checks fail, later messages are often cascading effects of the first one.

- Scan for the first ERROR
- Inspect the relevant log in `pkg.Rcheck/`:
  - `pkg.Rcheck/00check.log` — overall summary
  - `pkg.Rcheck/00install.out` — installation failures
  - `pkg.Rcheck/tests/testthat.Rout` — test failures

**5. Fix one issue at a time, re-run**

Fix the first problem, rebuild the tarball, re-run the check. Repeat.

### Platform preflight

Even with a clean local tarball check, test on other platforms before
submitting:

| Service | What it checks | How to use |
|---------|---------------|-----------|
| win-builder | Windows + R-devel | `devtools::check_win_devel()` |
| macbuilder | macOS | Submit tarball at https://mac.r-project.org/macbuilder/submit.html |
| R-hub | Multiple platforms + R versions | `rhub::check_for_cran()` |

At minimum, run `devtools::check_win_devel()`. Windows is a common source of
check failures that pass cleanly on macOS/Linux.

---

## Part 2 — Common NOTEs and what they mean

NOTEs require human review from CRAN. Fix actionable ones; explain contextual
ones in `cran-comments.md`.

### "CRAN incoming feasibility … NOTE" (new submissions only)

This NOTE is standard for first submissions and is purely informational if
your checks are otherwise clean. Read it carefully — if it points at
something actionable (URLs, size, missing metadata), fix the root cause.
Otherwise, note it briefly in `cran-comments.md`.

### "Possibly mis-spelled words in DESCRIPTION"

Cause: proper nouns, package names, acronyms, domain-specific terms.

Fix: verify the Description is well-written prose, not a keyword list.
For legitimate technical terms that aren't typos, explain briefly in
`cran-comments.md`.

### "Found the following (possibly) invalid URLs"

Causes: redirecting URL, temporarily down, authentication required, unusual
characters.

Fix:
- Use stable canonical URLs
- Replace brittle "latest release" links with stable permalinks
- Run `urlchecker::url_update()` to resolve redirects automatically
- Remove URLs requiring authentication

### "Namespace in Imports field not imported from"

Cause: a package is in `Imports` but nothing from it is actually used (or
it is only used conditionally).

Fix: if it's a hard runtime dependency, verify the code actually uses it.
If it's optional, move to `Suggests` and guard calls with
`requireNamespace("pkg", quietly = TRUE)`.

### "Package has a 'License' field that is not a standard CRAN license"

Cause: incomplete or non-standard license metadata.

Fix: use a standard SPDX identifier. If using `MIT + file LICENSE`, ensure
the LICENSE file is present and correctly formatted. If changing the license
between releases, highlight it in the submission.

### "Package size" / "installed size" notes

Causes: large embedded datasets, large PDF vignettes.

Fixes:
- Compress data; keep only what's necessary for the package to work
- Consider a companion data package for large datasets
- Keep vignettes lightweight; heavy computations belong in articles, not
  vignettes that run during `R CMD check`

### "Examples … too long" / timeouts

Causes: network calls, long computations, or real database queries in examples.

Fixes:
- Make examples fast and deterministic (a few seconds each)
- Move heavy demonstrations to vignettes with `\donttest{}`
- Guard slow examples with `\donttest{}` so CRAN skips them while still
  allowing local execution

---

## Part 3 — Policy gotchas

These are recurring policy violations that produce failures or reviewer
feedback even when `devtools::check()` is green.

### Examples and vignettes

Avoid code in examples/tests/vignettes that is:
- Network-dependent
- Non-deterministic (unseeded randomness, time/date assumptions)
- Long-running
- Interactive (menus, prompts)
- Writing outside `tempdir()`

Prefer:
- Small, deterministic examples
- `set.seed()` wherever randomness is used
- Guarding optional features: `if (requireNamespace("pkg", quietly = TRUE))`
- `\donttest{}` for anything that can't be made fast (not `\dontrun{}` — that
  signals "never run this", which CRAN dislikes)

### Files, paths, and side effects

- Never write to the working directory
- Never write to the user's home directory or any user-writable location
  outside `tempdir()`
- Use `tempdir()` / `withr::local_tempdir()` for all temporary files
- Clean up any files you create

### Dependency declarations

- If code uses a package at runtime → `Imports`
- Optional features, optional examples, testing only → `Suggests`

Packages in `Suggests` must be used conditionally. CRAN checks whether your
package fails gracefully when a `Suggests` package is not installed.

### Package size and long runtimes

Common triggers:
- Large embedded data (> 1–2 MB)
- Large PDF vignettes
- Long-running examples or vignettes

Mitigations:
- Compress data; keep it minimal
- Keep examples short — they demonstrate usage, not functionality
- Make expensive computations optional (but keep enough tests to validate
  correctness)

CRAN's policy: data and documentation should not exceed 5MB each; the full
source tarball should ideally stay under 10MB.

### External software and downloads

- Source packages cannot contain binary executables
- Downloading at install time is strongly discouraged; use secure `https://`
  URLs and fixed versions if you must
- Packages must fail gracefully when internet resources are unavailable
  (wrap network calls in `tryCatch` with informative messages)

### Portability

Cross-platform failures that only appear on one OS are bugs, not check noise:
- Windows path separators and encoding differences
- Case-insensitive file systems (macOS) vs. case-sensitive (Linux)
- Locale differences (sorting, character encoding)
- Missing system libraries on certain platforms

If CI passes on Linux but fails on Windows, treat it as a portability bug.

### Policy-shaped NOTEs that need immediate attention

Some NOTEs are effectively enforcement notices, not just informational:
- "uses the internet" — wrap network calls defensively
- "writing outside the package installation directory" — use `tempdir()`
- Timeouts / long runtimes — trim examples and vignettes
- Missing or inconsistent DESCRIPTION metadata — fix before submission

---

## References

- CRAN policy: https://cran.r-project.org/web/packages/policies.html
- CRAN submission checklist: https://cran.r-project.org/web/packages/submission_checklist.html
- Writing R Extensions: https://cran.r-project.org/doc/manuals/r-release/R-exts.html
