# code-style.md Rewrite Plan

**Goal:** Rewrite `.claude/rules/code-style.md` to be accurate for surveywts rather than
surveycore. The current doc describes a package that *defines* S7 classes; surveywts *consumes*
S7 classes from surveycore and defines none of its own.

**Architecture:** Single markdown file edit. Seven targeted changes: strip surveycore class
definition content, reframe S7 usage as "consuming imported objects," add `weighted_df` S3
patterns, add three-path input handling pattern, and replace all examples with surveywts
functions.

---

## Audit: What's Wrong Now

### Surveycore-specific content that doesn't apply to surveywts

| Current content | Problem |
|-----------------|---------|
| "S7 method file org: Methods grouped by type in dedicated files (`04-methods-print.R`, etc.)" | File names are surveycore's — surveywts has `methods-print.R` (no numeric prefix) |
| Comment rule: "must include a comment pointing to the class definition" | surveywts has no class definitions to point to |
| Property access examples: `x@metadata@variable_labels`, `x@metadata@weighting_history` | These reference surveycore's `metadata` structure |
| Setter/Getter return values: `set_var_label()`, `extract_var_label()` | These are surveycore functions, not surveywts |
| Constructor examples: `as_survey()`, `as_survey_rep()` | These are surveycore constructors |
| Dispatch rule: UseMethod examples | surveywts never uses UseMethod for anything |
| Class membership example: `S7::S7_inherits(x, survey_taylor)` | Bare `survey_taylor` is a surveycore namespace object — in surveywts, it must be `surveycore::survey_taylor` |

### What's missing (surveywts-specific)

| Missing content | Why it matters |
|-----------------|----------------|
| `weighted_df` S3 class patterns | surveywts's only home-grown class; completely absent |
| `inherits(x, "weighted_df")` vs `S7::S7_inherits()` | Different check idioms for the two class systems used |
| Three-path input handling | Every function handles `data.frame` / `weighted_df` / S7 object — the pattern is consistent but undocumented |
| History entry construction | Documented nowhere but used in every calibration/weighting function |
| Fully qualified class references: `surveycore::survey_nonprob` | Classes come from another package; bare names only resolve because of `.onLoad()` — `::` is safer in examples |
| `S7::methods_register()` in `.onLoad()` | How surveywts's two print methods work |

### What's correct and should stay unchanged

- All of Section 1 (indentation, line length, air, pipe, assignment) — matches actual code exactly
- Section 3 (error & warning conventions) — `cli_abort()` structure, class= requirement, inline markup — all verified correct
- `S7::S7_inherits()` rule itself — keep, just fix examples and add namespace qualification
- Direct `@` access rule — keep, just reframe (we access surveycore objects' properties, not our own)
- Internal helper placement rule — matches actual code exactly
- Import style (`::`/no `@importFrom`) — matches actual code exactly

---

## Change Plan

### Change 1: Quick Reference table

**Remove these rows:**
```
| S7 method file org | Methods grouped by type in dedicated files (`04-methods-print.R`, etc.) |
```

**Replace with:**
```
| Print method file | `methods-print.R`; registered via `S7::methods_register()` in `.onLoad()` |
```

**Replace these rows:**
```
| Class membership test | `S7::S7_inherits(x, survey_taylor)` — class object, never a string |
| Setter return values  | `invisible(x)` |
| Getter return values  | Visible (no `invisible()`) |
```

**With:**
```
| Type check (S7 objects) | `S7::S7_inherits(x, surveycore::survey_taylor)` — fully qualified, never a string |
| Type check (weighted_df) | `inherits(x, "weighted_df")` — bare inherits() for the S3 class |
| Weighting function returns | Visible (the updated `data.frame`, `weighted_df`, or survey object) |
| Diagnostic function returns | Visible (named scalar or tibble) |
| Print/summary methods | `invisible(x)` |
| Validators (internal) | `invisible(TRUE)` on success |
```

---

### Change 2: Rewrite Section 2 — "S7-Specific Patterns"

Rename to **"Working with S7 Objects"** to reflect that surveywts consumes, not defines.

#### 2a. Property access — keep but reframe

Current text says "accessor functions for @data and @metadata." Keep the direct `@` rule since we
access surveycore objects' properties everywhere. Remove the "accessor functions" exception — those
functions live in surveycore, not here. The rule in surveywts is simply: use `@` directly.

**Replace the current accessor function example block** (which shows `survey_data()` and
`survey_metadata()` as if they're defined here) with a surveywts-relevant example:

```r
# Accessing properties of a surveycore object in surveywts internal code
wt_vec   <- data@data[[data@variables$weights]]
meta     <- data@metadata
history  <- meta@weighting_history

# Then to write back (surveywts pattern for updating history):
meta@weighting_history <- c(history, list(new_entry))
data@metadata <- meta
```

#### 2b. S7 method file organization — REMOVE this subsection

The entire "S7 method file organization" subsection and its table reference surveycore file names.
Replace with a single paragraph:

> **Print method registration.** surveywts registers exactly two S7 print methods — for
> `survey_nonprob` and `survey_replicate` — both in `R/methods-print.R`. Registration happens
> via `S7::methods_register()` called from `.onLoad()` in `R/zzz.R`. If adding a new print
> method, add it to `methods-print.R` and ensure `.onLoad()` still calls
> `S7::methods_register()`.

#### 2c. Class membership testing — keep rule, fix examples

The `S7::S7_inherits()` rule is correct and widely used (42 call sites). Fix two things:

1. Use fully-qualified class names since surveycore classes must be namespaced in documentation
   and examples:

```r
# Correct — fully qualified when the class comes from another package
if (!S7::S7_inherits(data, surveycore::survey_nonprob)) {
  cli::cli_abort(
    c("x" = "{.arg data} must be a {.cls survey_nonprob}."),
    class = "surveywts_error_not_nonprob"
  )
}

# Also correct — bare name works at runtime (surveycore is imported),
# but use :: in examples and documentation
if (!S7::S7_inherits(data, surveycore::survey_taylor)) { ... }
```

2. Contrast with the `weighted_df` S3 check:

```r
# weighted_df uses base inherits() — it's an S3 class, not S7
if (inherits(data, "weighted_df")) {
  # weighted_df path
} else if (S7::S7_inherits(data, surveycore::survey_nonprob)) {
  # survey_nonprob path
} else if (is.data.frame(data)) {
  # plain data.frame path
}
```

---

### Change 3: Add Section 2d — `weighted_df` S3 Class

Add a new subsection after class membership testing:

**Content to add:**

```markdown
### weighted_df S3 class

`weighted_df` is surveywts's only home-grown class — an S3 subclass of tibble returned
from all calibration, nonresponse, and utility functions when the input is a plain
data.frame or weighted_df.

**Type check:** Use base `inherits()`, not `S7::S7_inherits()` — it is an S3 class:
```r
inherits(x, "weighted_df")      # correct
S7::S7_inherits(x, weighted_df) # wrong — weighted_df is not an S7 class
```

**Attributes:**
```r
attr(x, "weight_col")          # character(1) — name of the weight column
attr(x, "weighting_history")   # list — ordered history entries
```

**Never construct directly.** Users receive `weighted_df` as output; they never build
one themselves. Internally, use `.make_weighted_df()` from `utils.R`.
```

---

### Change 4: Add Section 2e — Three-Path Input Handling

Add a new subsection. Every weighting function accepts three input types and follows a
consistent dispatch pattern.

**Content to add:**

```markdown
### Three-path input handling

Every weighting function in surveywts accepts `data.frame`, `weighted_df`, and S7 survey
objects. The canonical dispatch order is:

```r
if (S7::S7_inherits(data, surveycore::survey_nonprob)) {
  # S7 path: extract @data, operate, write back, update @metadata@weighting_history
} else if (inherits(data, "weighted_df")) {
  # weighted_df path: update weight column, append to attr(, "weighting_history")
} else {
  # plain data.frame path: create a new weighted_df via .make_weighted_df()
}
```

Check S7 objects before weighted_df because survey_nonprob inherits from data.frame and
would pass the `is.data.frame()` check if checked last.

**History entry construction** (all paths):
```r
new_entry <- list(
  step      = length(.get_history(result)) + 1L,
  timestamp = Sys.time(),
  operation = "fn_name",          # name of the calling function
  # function-specific fields follow
)
# For weighted_df:
attr(result, "weighting_history") <- c(
  attr(result, "weighting_history"),
  list(new_entry)
)
# For survey_nonprob:
meta <- result@metadata
meta@weighting_history <- c(meta@weighting_history, list(new_entry))
result@metadata <- meta
```
```

---

### Change 5: Update Section 4 — Return Value Visibility

**Replace the table entirely.** Current table lists surveycore functions. Replace with
surveywts-specific entries:

| Function type | Return |
|---------------|--------|
| Calibration functions: `calibrate_rake()`, `poststratify()`, etc. | Visible (updated object, same class as input) |
| Nonresponse functions: `adjust_nonresponse()`, `redistribute_weights()` | Visible (updated object, same class as input) |
| Utility functions: `trim_weights()`, `stabilize_weights()` | Visible (updated object, same class as input) |
| Diagnostic functions: `effective_sample_size()`, `weight_variability()`, `summarize_weights()` | Visible (named scalar or tibble) |
| `ipw()` — always returns `survey_nonprob` regardless of input class | Visible (`survey_nonprob`) |
| Print methods: `S7::method(print, survey_nonprob)`, etc. | `invisible(x)` |
| Internal validators: `.validate_weights()`, `.validate_wt_name()`, etc. | `invisible(TRUE)` on success |
| Internal constructors: `.make_weighted_df()` | Visible (the new object) |

**Replace the code example block** — current block shows `set_var_label.survey_base` and
`extract_var_label.survey_base` (surveycore). Replace with surveywts examples:

```r
# Weighting function — always returns visible, same class as input
trim_weights <- function(data, weights = NULL, lower = NULL, upper = NULL, ...) {
  # ... implementation ...
  result  # visible — no invisible()
}

# Diagnostic function — visible scalar or tibble
effective_sample_size <- function(x, weights = NULL) {
  # ...
  ess  # visible
}

# Internal validator — invisible(TRUE) on success, cli_abort() on failure
.validate_wt_name <- function(wt_name) {
  if (!is.character(wt_name) || length(wt_name) != 1L) {
    cli::cli_abort(
      c("x" = "{.arg wt_name} must be a single character string."),
      class = "surveywts_error_wt_name_invalid"
    )
  }
  invisible(TRUE)
}
```

---

### Change 6: Update Section 4 — Dispatch Rule

**Keep the table** but simplify: surveywts has only one real dispatch pattern (plain function
+ `S7::S7_inherits()`) and one method registration pattern. Remove the UseMethod rows and
the detailed "why UseMethod fails" explanation — that's surveycore's concern.

**Replace the entire dispatch rule subsection** with a leaner version:

```markdown
### Dispatch rule

surveywts functions are plain R functions — not S7 generics, not S3 generics. Type dispatch
is always explicit via `S7::S7_inherits()` or `inherits()`.

| Situation | Use |
|-----------|-----|
| Type checking a surveycore S7 object | `S7::S7_inherits(x, surveycore::survey_nonprob)` |
| Type checking `weighted_df` | `inherits(x, "weighted_df")` |
| Registering a print method for a surveycore class | `S7::method(print, surveycore::survey_nonprob) <- function(x, ...) { }` in `methods-print.R` |

Never use `UseMethod()` in surveywts — S3 dispatch does not work for S7 objects.
```

---

### Change 7: Fix Argument Order Example

The current example uses `as_survey_rep()` (a surveycore function). Replace with a
surveywts function. `ipw()` is the most complex and representative:

```r
# ipw: data (1), reference (2, required), selection (3, optional NSE),
#      then optional scalars
ipw <- function(
  data,
  reference,
  selection = NULL,
  predictors = NULL,
  missing_method = c("omit", "separate", "impute"),
  method = "logit",
  estimating_eq = c("mle", "gee"),
  maxit = 25L,
  epsilon = 1e-8,
  trim = FALSE,
  population_size = NULL,
  wt_name = "ipw_weight"
)

# calibrate_rake: data (1), targets (2, required), weights (3, optional NSE),
#                 then optional scalars
calibrate_rake <- function(
  data,
  targets,
  weights = NULL,
  wt_name = "wts",
  type = c("prop", "count"),
  algorithm = c("classic_ipf", "nr"),
  cap = NULL,
  control = list(),
  reference_design = NULL
)
```

---

## Sections That Stay Unchanged

- **Section 1** (General R Style) — indentation, line length, air, pipe, assignment operator
- **Section 3** (Error & Warning Conventions) — `cli_abort()` structure verified correct
- **Section 5** (Roxygen & Package Check) — no surveycore-specific content
- **Section 6** (Tooling Configuration) — no surveycore-specific content
- **Internal helper placement** rule in Section 4 — matches actual code exactly

---

## Order of Edits

Edit the file in this order to avoid context drift between changes:

1. Quick Reference table (top of file) — small, sets the tone
2. Section 2 subsection: rename + reframe "Property access"
3. Section 2 subsection: replace "S7 method file organization"
4. Section 2 subsection: fix class membership testing examples
5. Section 2: insert new "weighted_df S3 class" subsection
6. Section 2: insert new "Three-path input handling" subsection
7. Section 4: replace return value table and examples
8. Section 4: replace dispatch rule subsection
9. Section 4: fix argument order example
