# Pre-submission Checklist

Everything `devtools::check()` won't catch. Work through these items
systematically before running any `--as-cran` checks.

## Checklist order

1. Create `NEWS.md` if absent: `usethis::use_news_md()`
2. Create `cran-comments.md` if absent: `usethis::use_cran_comments()`
3. Review README (see below)
4. Proofread DESCRIPTION `Title:` and `Description:` fields (see below)
5. Verify all exported functions have `@return` and `@examples` (see below)
6. Confirm `Authors@R:` has a copyright holder with `[cph]` role
7. Update LICENSE year to current submission year
8. Run `urlchecker::url_check()` and fix issues

---

## DESCRIPTION — Title field

**Use title case.** Capitalize all words except articles (a, the, of, for).
Use `tools::toTitleCase()` to help.

**No redundant phrases.** CRAN flags these:
- "A Toolkit for" → remove
- "Tools for" → remove
- "for R" → remove
- "with R" → remove

**Quote software and package names** in single quotes.
**Keep under 65 characters.**

```r
# Bad
Title: A Toolkit for the Construction of Modeling Packages for R

# Good
Title: Construct Modeling Packages

# Bad
Title: Command Argument Parsing for R

# Good — software name quoted
Title: Interface to 'Tiingo' Stock Price API
```

---

## DESCRIPTION — Description field

**Never start with these phrases:**
- "This package"
- The package name
- "Functions for"

**Write 3–4 sentences** covering what the package does, why it's useful, and
what types of problems it solves.

**Quote software, package, and API names** (including 'R') in single quotes.
**Do not quote function names.**

**Expand all acronyms** on first mention.

**Use double quotes only for publication titles**, not for phrases or emphasis.

```r
# Bad
Description: This package provides functions for rendering slides.

# Bad
Description: Functions for rendering slides to different formats.

# Good
Description: Render slides to different formats including HTML and PDF.
    Supports custom themes and progressive disclosure patterns. Integrates
    with 'reveal.js' for interactive presentations.

# Bad — function name quoted
Description: Uses 'case_when()' to process data.

# Good — package name quoted, function name unquoted
Description: Uses case_when() to process data with 'dplyr'.

# Bad — unexpanded acronym
Description: Implements X-SAMPA processing.

# Good
Description: Implements Extended Speech Assessment Methods Phonetic
    Alphabet (X-SAMPA) processing.
```

---

## Documentation requirements

### `@return` — strictly enforced

CRAN requires `@return` on **every exported function**, including:
- Functions that return nothing: `@return None, called for side effects`
- Functions marked `@keywords internal`

```r
# Missing @return — will be rejected
#' Calculate sum
#' @export
my_sum <- function(x, y) x + y

# Correct
#' @param x First number
#' @param y Second number
#' @return A numeric value
#' @export
my_sum <- function(x, y) x + y
```

### `@examples` — required for meaningful returns

All exported functions with a meaningful return value need `@examples`.
Examples must be executable — no placeholders, no commented-out code.

```r
# Bad — commented-out code will be rejected
#' @examples
#' # my_function(x)

# Good
#' @examples
#' my_function(1:10)
```

### `\dontrun{}` — use sparingly

Only use `\dontrun{}` when an example genuinely cannot execute (missing
external software, API keys required). Alternatives:

- Showing an error: wrap in `try()` instead
- Slow examples (> 5 sec): use `\donttest{}`
- Conditional on a suggested package: use `@examplesIf` or an `if` guard

### Guarding examples that need suggested packages

```r
# Entire section requires suggested package
#' @examplesIf rlang::is_installed("dplyr")
#' library(dplyr)
#' my_data |> my_function()

# Individual block within examples
#' @examples
#' if (rlang::is_installed("dplyr")) {
#'   library(dplyr)
#'   my_data |> my_function()
#' }
```

### Un-exported functions with examples

If writing roxygen examples for un-exported functions, either:
1. Call with `:::` notation: `pkg:::my_fun()`
2. Use `@noRd` to suppress `.Rd` file creation

---

## URL validation

**All URLs must use `https://`**. HTTP links will be rejected.

**No redirecting URLs.** Run `urlchecker::url_check()` to find them and
`urlchecker::url_update()` to fix them automatically.

**Exception — aspirational URLs.** Some URLs don't resolve yet but will once
the package is on CRAN. Leave these as-is:
- CRAN badge URLs: `https://cran.r-project.org/package=pkgname`
- CRAN status badges: `https://www.r-pkg.org/badges/version/pkgname`
- pkgdown or r-universe URLs that deploy after release

---

## README

- Include install instructions valid after CRAN acceptance:
  `install.packages("pkgname")`
- No relative links — use full URLs or remove the links. Relative links
  work on GitHub but CRAN's checker flags them.
- If `README.Rmd` exists: edit `README.Rmd` only (never `README.md` directly),
  then run `devtools::build_readme()` to re-render.

---

## Administrative

### Copyright holder

`Authors@R:` must include at least one person with the `[cph]` role:

```r
# Minimum — add cph to your own roles
person("Jane", "Doe", role = c("aut", "cre", "cph"))
```

### LICENSE year

Update the LICENSE file year to match the current submission year.

### Method references

CRAN may ask: *"If there are references describing the methods in your
package, please add these in the description field."* If none exist, add a
preemptive note in `cran-comments.md`:

```markdown
## Method references

There are no published references describing the methods in this package.
```

---

## Useful tools

| Tool | Purpose |
|------|---------|
| `tools::toTitleCase()` | Format Title with proper capitalization |
| `urlchecker::url_check()` | Find problematic URLs |
| `urlchecker::url_update()` | Fix redirecting URLs automatically |
| `usethis::use_news_md()` | Create NEWS.md |
| `usethis::use_cran_comments()` | Create cran-comments.md |
| `devtools::build_readme()` | Re-render README.md from README.Rmd |
| `usethis::use_tidy_description()` | Tidy up DESCRIPTION formatting |
| `spelling::spell_check_package()` | Catch spelling errors |

---

## Final verification checklist

### Files

- [ ] `NEWS.md` exists and documents changes for this version
- [ ] `cran-comments.md` exists with submission notes
- [ ] README includes `install.packages("pkgname")` instructions
- [ ] README has no relative links
- [ ] If `README.Rmd` exists: edited (not `README.md`) and `build_readme()` run

### DESCRIPTION

- [ ] `Title:` uses title case
- [ ] `Title:` has no redundant phrases ("A Toolkit for", "for R", etc.)
- [ ] `Title:` quotes all software/package names in single quotes
- [ ] `Title:` is under 65 characters
- [ ] `Description:` does not start with "This package", package name, or "Functions for"
- [ ] `Description:` is 3–4 sentences
- [ ] `Description:` quotes software/package/API names but not function names
- [ ] `Description:` expands all acronyms on first mention
- [ ] `Description:` uses double quotes only for publication titles
- [ ] `Authors@R:` includes a copyright holder with `[cph]` role
- [ ] LICENSE year matches current submission year

### Documentation

- [ ] All exported functions have `@return`
- [ ] All exported functions with meaningful returns have `@examples`
- [ ] No example sections contain commented-out code
- [ ] `\dontrun{}` used only where truly necessary
- [ ] Examples requiring suggested packages use `@examplesIf` or `if` guards

### URLs

- [ ] `urlchecker::url_check()` run and issues resolved
- [ ] All URLs use `https://` (no `http://`)
- [ ] No redirecting URLs (aspirational CRAN badge URLs excepted)
