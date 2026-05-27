# R Package Profile — surveywts

R-specific commands, gates, and CRAN-compliance rules. The tester agent runs
these in order; builder respects them during implementation.

## Validation commands (tester runs in order)

| # | Command | Gate | On fail |
|---|---------|------|---------|
| 1 | `Rscript -e "devtools::document()"` | NAMESPACE/man/ unchanged after run | BLOCK (builder forgot `document()`) |
| 2 | `Rscript -e "devtools::test()"` | all tests pass | BLOCK (numerical-miss or contract-miss) |
| 3 | `Rscript -e "devtools::run_examples()"` | all `@examples` run clean | BLOCK (examples use unloaded Imports or broken syntax) |
| 4 | `R CMD build . 2>&1` | tarball produced | BLOCK (build failure) |
| 5 | `R CMD check --as-cran <tarball> 2>&1` | 0 ERRORs, 0 WARNINGs; NOTEs reviewed | BLOCK on ERROR/WARNING |
| 6 | `Rscript -e "pkgdown::build_site(preview = FALSE)"` | site builds, no errored pages | BLOCK (unless skipped, see below) |
| 7 | `Rscript -e "covr::package_coverage()"` | ≥ 95% (target 98%) | BLOCK if < 95%; HOLD if 95–98% and dropped vs baseline |

### pkgdown skip condition

Tester MAY skip gate 6 when the PR's write surface does not touch:
- `R/` (any source file)
- `vignettes/`
- `README.Rmd`, `README.md`
- `_pkgdown.yml`
- `DESCRIPTION` (Title, Description, Imports)

Skip is logged in `audit.md` Profile gates table with `SKIPPED — scope`.

**No skip when exports change.** If the PR adds, removes, or renames any
exported function, pkgdown MUST run — NAMESPACE diff non-empty → no exception.

Note: during pre-Polish phases, pkgdown may be SKIPPED — Polish if pkgdown CI
is not yet wired up. Log as `SKIPPED — pre-pkgdown` and log in audit.md.

## Pre-approved NOTEs

These NOTEs do NOT block:

| NOTE | Reason |
|------|--------|
| `no visible binding for global variable 'X'` | Tidy-select bare names; pre-approved in `r-package-conventions.md` |
| `checking CRAN incoming feasibility` | Package is not on CRAN yet |

Any other NOTE is reviewed by tester. Reviewer escalates to STOP if a new
NOTE pattern appears that isn't in the pre-approved list.

## CRAN cookbook scan

Tester greps for these in all changed `.R` files (implementation.md write surface):

| Violation | Pattern | BLOCK class |
|-----------|---------|-------------|
| `T`/`F` as logicals | bare `T` or `F` in code context | `surveywts_error_tf_abbrev` |
| Hardcoded `set.seed()` in non-test code | `set\.seed\(` in `R/` without a `seed` arg | `surveywts_error_hardcoded_seed` |
| Bare `print()` or `cat()` | `^\s*(print\|cat)\(` in `R/` outside print/summary methods | `surveywts_error_bare_print` |
| `options(warn = -1)` | `options\(warn\s*=\s*-1` | `surveywts_error_suppress_warn_global` |
| `installed.packages()` | `installed\.packages\(` | `surveywts_error_installed_packages` |
| `<<-` outside Shiny | `<<-` | `surveywts_error_global_assign` |
| Unrestored `par()` / `options()` | `par\(\|options\(` without `on.exit()` in same fn | `surveywts_error_unrestored_state` |
| More than 2 cores | `mc.cores\s*=\s*[3-9]` or `makeCluster\([3-9]` | `surveywts_error_cores_gt_2` |
| `@importFrom` in source | `^#' @importFrom` in `R/` | `surveywts_error_importfrom` |

Each hit is a BLOCK. Tester reports in `audit.md`:

```
## CRAN cookbook violations
| File | Line | Violation | Class |
|------|------|-----------|-------|
| R/check_balance.R | 42 | T as logical | surveywts_error_tf_abbrev |
```

## DESCRIPTION checks

Tester validates against `rules/r-package-conventions.md`:

- **Description field**: ≥ 2 sentences
- **Title**: Title Case
- **Authors@R**: `person()` format; no deprecated `Author`/`Maintainer`
- **Imports versions**: lower-bound pins (`(>= x.y.z)`) on all entries
- **No `@importFrom`**: grep `^#' @importFrom` across `R/` → any hit is BLOCK
  (surveywts convention: use `::` everywhere; only exception is S3 method
  registration as per `r-package-conventions.md`)

## Builder compliance rules

Builder MUST follow these during implementation:

1. Use `TRUE`/`FALSE`, never `T`/`F`
2. Call external functions with `::` (no `@importFrom` except S3 method registration)
3. Use `message()` for informational output, not `print()`/`cat()`
4. Provide a `seed = NULL` arg for any function using randomness
5. Restore `par()` / `options()` with `on.exit()`
6. Use `tempdir()` for I/O; clean up with `on.exit(unlink(...))`
7. Cap parallel workers at 2 in examples/tests
8. Run `devtools::document()` before committing roxygen changes
9. Use `requireNamespace("pkg", quietly = TRUE)` not `installed.packages()`
10. Every `cli_abort()` and `cli_warn()` must have `class =` — verify against `plans/error-messages.md`

Builder's `implementation.md` notes compliance at the bottom:

```
## CRAN compliance
- [x] TRUE/FALSE used throughout
- [x] :: used for external calls (no @importFrom except S3 registration)
- [x] No bare print()/cat()
- [x] devtools::document() run
- [x] All cli_abort()/cli_warn() have class=
```
