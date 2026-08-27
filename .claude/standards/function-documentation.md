# Function Documentation Standards

**Version:** 1.0
**Created:** June 2026
**Status:** Decided — applies to all exported functions in surveywts

This document defines how every exported function in surveywts must be
documented. It is the authoritative reference for documentation audits and
new function implementations.

**Related rules:**
- `r-package-conventions.md` — codoc requirements for datasets, NAMESPACE, export policy
- `code-style.md` — `cli_abort()` / `cli_warn()` structure, S7 patterns
- `surveywts-conventions.md` — `@family` tags, file organization, argument order

---

## Universal Rules

These rules apply to every exported function, regardless of tier.

### Title

- Write as an active verb phrase in the present tense: "Clip weights to a
  range", not "Clipping of weights" or "Weight clipping"
- Do not repeat the function name's verb — use a synonym to give a second angle
  on intent (`ipw()` → "Estimate inverse probability weights", not "Compute IPW
  weights")
- Drop "survey weights" from the title — it is implicit from package context
  and wastes space
- Describe what is unique about this function versus its siblings in the same
  family: if two functions share a title, one of them is wrong
- Must be informative when skimming the pkgdown reference index in isolation

### Description

- Must add information the title does not contain — do not restate the title in
  prose
- Title = high-level summary; description = mechanism, key nuance, or an
  important behavioral constraint
- No formulas in `@description` — formulas belong in the Algorithm section
- Keep to 1–3 sentences; longer explanatory content belongs in `@details` or
  named `@section` blocks

### `@param` format

**Type annotation.** Lead every `@param` with a type annotation:

```r
#' @param data A `survey_taylor`, `survey_nonprob`, or `survey_replicate`.
```

**Defaults.** State the default first and explicitly call it the default:

```r
#' @param method `"logit"` (the default), `"probit"`, or `"cloglog"`.
```

**Inline vs. bullets (complexity-based):**

- Inline if each option fits a single-phrase description (as in the `method`
  example above)
- Bullet list or fenced code block if any option requires its own sentence or
  sub-structure

**Content rule.** `@param` describes the effect of the argument on behavior or
output — not the internal mechanism. Mechanism content belongs in `@details` or
named `@section` blocks.

**`@param data` specifically.** Lead with the accepted classes. When
class-specific behavior routes to another section, include a forward reference
rather than an inline description:

```r
#' @param data A `survey_taylor`, `survey_nonprob`, or `survey_replicate`. For
#'   inputs containing replicate weight columns, see the **Replicate Weights**
#'   section.
```

Name the classes the function actually accepts, and say what happens to the
rest. Every weighting function rejects a plain `data.frame`, so the accepted
list never includes one:

```r
#' @param data A `survey_taylor` or `survey_nonprob`. Must include BOTH
#'   respondents and nonrespondents. `survey_replicate` -> error. Any other
#'   class -> error.
```

**`@inheritParams`.** Use only when the argument is genuinely identical in
behavior — not just in name — across the inheriting and source functions. Always
place a code comment above the tag identifying the source:

```r
# x and weights are identical in behavior to effective_sample_size()
#' @inheritParams effective_sample_size
```

### `@returns`

Use `@returns` (not `@return`) on every exported function.

- Describe the output's **shape** (class, class-preservation rule) and
  **behavioral guarantees** (properties that hold on the output)
- Enumerate by input class only when behavior meaningfully differs across
  classes; if every class produces the same output class with the same
  properties, a single-sentence description is correct — do not enumerate for
  its own sake
- **Class-specific routing:** output differences (what the returned object
  contains or how it differs from the input) belong here; algorithm differences
  belong in the Algorithm section; replicate-weight-scope differences belong in
  the Replicate Weights section
- When the input may contain replicate weight columns, document that all
  replicate weight columns are updated by the same method:

```r
#' @returns A `survey_nonprob` with updated weights. If the input contains
#'   replicate weight columns, all replicate weight columns are updated by
#'   the same method.
```

- Do not define package-level concepts (e.g., weighting history) inside
  `@returns` — reference them with standard phrasing
- **Standard phrasing for weighting history entries:** "A new entry with
  `operation = "fn_name"` is appended to the weighting history." Quote the
  string the function actually writes, which is usually the function name but
  not always — `adjust_nonresponse()` writes
  `"nonresponse_weighting_class"`, `"nonresponse_propensity"`, or
  `"nonresponse_propensity_cell"` depending on `method`, and the
  `create_*_weights()` functions write `"bootstrap_weights"`,
  `"jackknife_weights"`, or `"replicate_creation"`.

### `@details`

- Use for content that cannot be captured in `@description`
- Formulas go in `@details` (specifically in the Algorithm section), never in
  `@description`
- Mechanism and algorithm logic go in `@details`, not in `@param`
- Whether `@details` is required depends on tier (see tier-specific rules below)

### Named `@section` blocks

Use the six canonical sections below when applicable, in this canonical order.
Custom sections are permitted when content is genuinely distinct from all six
canonical sections — this list is not exhaustive. Example: a function that
exposes weighting history structure might warrant a "Weighting History" section.

**Format:** `@section Section Name:` for top-level sections; `**Bold text**`
for sub-sections within a section (roxygen2 does not support nested `@section`).

1. **Algorithm** — statistical algorithm(s), formulas, mathematical details.
   For multi-algorithm functions, use `**Bold sub-headers**` per algorithm
   within the same section.

2. **Convergence** — convergence criterion, tolerance parameters, and what
   happens when the algorithm fails to converge (error vs. warning, what is
   returned or not returned).

3. **Missing Data** — how NAs in predictors, weights, or strata are handled.
   Include if the behavior is non-obvious or if the function exposes a
   `missing_method` argument.

4. **Replicate Weights** — behavior when the input contains replicate weight
   columns. Documents scope differences (the method is applied to all replicate
   weight columns in addition to the main weight), not algorithm differences.
   Include whenever the function accepts objects that may carry replicate
   weights and the handling differs from the scalar-weight path.

5. **Limitations** — known failure modes, cases where results are unreliable
   without an error being thrown, when to prefer an alternative function.

6. **Warnings** — when warnings may occur and how to resolve them. Plain
   language only — no warning class names.

### `@references`

- Required for any function implementing a published method
- Use standard academic citation format:

```
Kish, L. (1965). _Survey Sampling_. John Wiley & Sons.
```

- **In-line citations** (e.g., "Kish (1965)" within description or section
  text): optional, and only if verified against the `comprehension.md` for the
  relevant spec. If no `comprehension.md` exists for the spec, omit in-line
  citations entirely. Incorrect in-line citations are worse than none.

### `@seealso`

Required (not optional) in three cases:

1. **Dispatchers** — must link to every function the dispatcher routes to
2. **Sibling functions** — must link to all other functions in the same
   `@family`
3. **Canonical companions** — closely related functions a user would naturally
   reach for next (e.g., `ipw()` → `summarize_weights()`)

### `@examples`

**Package data required.** All examples must use package data. If a function's
examples cannot use existing package data as-is, flag the relevant dataset for
remediation in planning docs — do not substitute inline data as a workaround.

**`\dontrun{}`** Do not use `\dontrun{}` except for examples that genuinely
require external resources (e.g., a live database connection or network call).
Every other example must run successfully during `R CMD check`.

**Examples must load Imports packages explicitly.** `R CMD check` runs
examples in a fresh session with only `library(surveywts)` loaded. If an
example calls a bare function from an Imports package, add `library(pkg)` at
the top of the block.

**Required content:**

- Always: the simplest working call, over a survey object built from package
  data. A plain `data.frame` cannot be the input — every weighting function
  rejects one
- Always: one example per input class the function accepts, demonstrating the
  unique behavior of that class, not just that it compiles
- When an argument accepts multiple formats (e.g., two `targets` formats in
  calibration functions): show each format
- When a function has a `method` or `algorithm` argument: demonstrate each
  method
- When a `by` argument is present: show its effect on output structure

**Comment style:**

- Comments explain **why**, not what — "what" comments are noise; the code
  itself shows what
- Section headers are the exception: use them to label the scenario being
  demonstrated
- Section header format: `# Brief scenario label ---------------------------`
  (dashes fill to ~76 characters, consistent with air formatter style)

**Length.** If the example block exceeds ~25 lines, consider whether the longer
cases belong in a vignette rather than `@examples`.

### Errors and warnings in help pages

- **Input validation errors:** do not document in help pages — this is
  redundant with `@param`
- **Algorithmic errors** (e.g., convergence failure, rank-deficient system):
  document in the Convergence section or the relevant named section
- **Warnings:** document in the Warnings section — plain language description
  of when the warning occurs and how to resolve it; no warning class names

### Mathematical notation

- **Inline code** (backticks) for simple arithmetic and ratios with no
  subscripts, superscripts, Greek letters, or summation notation:
  - `sd(w) / mean(w)` — acceptable as inline code
  - `w / mean(w)` — acceptable as inline code
  - `[lower, upper]` — acceptable as inline code
- **`\eqn{}`** for inline mathematical expressions containing subscripts,
  superscripts, Greek letters, or summation notation
- **`\deqn{}`** for display (standalone) mathematical equations containing any
  of the above
- When uncertain: if the formula renders ambiguously as monospace code, use
  `\eqn{}` or `\deqn{}`

### Internal Function Documentation

| Helper complexity | Documentation |
|-------------------|---------------|
| Obvious one-liner | No roxygen at all |
| Complex enough to need explanation | `@keywords internal` + `@noRd` |

```r
# One-liner — no roxygen needed
.get_col <- function(x, col) x[[col]]

# Complex helper — document but suppress .Rd
#' Validate survey design structure
#'
#' @param x A survey design object.
#' @returns Invisibly, `TRUE` on success (errors otherwise).
#' @keywords internal
#' @noRd
.validate_design <- function(x) { ... }
```

---

## Tier 1 — Utility

> All Universal Rules (see preamble) apply.

### Criteria

Tier 1 functions are single-purpose transformations or extractions. They apply
a defined operation — possibly a published formula — but involve no iterative
algorithm, no optimization, and no statistical model fitting.

**`@details` / Algorithm section.** Required only if the function has a formula.
If the operation can be described in `@description` without a formula, `@details`
is likely not needed.

**`@section Convergence`.** Not applicable.

**`@section Missing Data`.** Include if NAs in the input produce non-obvious
behavior.

**`@section Replicate Weights`.** Include if the function accepts objects that
may contain replicate weight columns and the behavior on those columns differs
from the scalar-weight path.

**`@references`.** Required if the function implements a published formula.
Simple rescaling or structural conversion does not require a reference.

### Illustrative examples

- `effective_sample_size()` — has a formula (Kish 1965); requires an Algorithm
  section with `\deqn{}` and a `@references` entry
- `rescale_weights()` — rescales weights; simple enough that `@description`
  alone covers the mechanism; no Algorithm section needed
- `as_taylor_design()` — structural conversion of a `survey_replicate` to a
  `survey_taylor`; no formula; minimal `@details`; no `@references`

---

## Tier 2 — Standard

> All Universal Rules (see preamble) apply.

### Criteria

Tier 2 functions involve multiple steps or decision paths but implement no
iterative statistical algorithm or optimization. The mechanism matters enough
to require explanation beyond `@description`, but a full Algorithm section is
not always warranted.

**`@details` / Algorithm section.** Required when the mechanism cannot be
captured in 2–3 sentences in `@description`. When multiple method paths exist,
describe each briefly; include formulas only if the method has a named
published formula.

**`@section Convergence`.** Not applicable (Tier 2 functions are not iterative).

**`@section Missing Data`.** Include when missing data handling is non-obvious
or when the function accepts a `missing_method` or equivalent argument.

**`@section Replicate Weights`.** Include if the function accepts objects that
may contain replicate weight columns and the behavior on those columns differs
from the scalar-weight path.

**`@references`.** Required if based on a published method.

### Illustrative examples

- `adjust_nonresponse()` — multiple adjustment methods (`method` argument);
  Algorithm section describing each method; no Convergence section
- `summarize_weights()` — descriptive output; `@description` likely sufficient
  without a full Algorithm section
- `redistribute_weights()` — procedural; brief Algorithm section if the
  redistribution rule requires more than 2–3 sentences to explain

---

## Tier 3 — Algorithmic

> All Universal Rules (see preamble) apply.

### Criteria

Tier 3 functions implement a statistical algorithm with a defined formula,
optimization procedure, or resampling scheme. They may be iterative with
convergence criteria.

**`@section Algorithm`.** Required. Include formulas using `\eqn{}` / `\deqn{}`
wherever notation requires subscripts, superscripts, Greek letters, or summation.
For functions that implement multiple algorithms (distinguished by a `method`
argument), use `**Bold sub-headers**` per algorithm within the same section.

**`@section Convergence`.** Required for any iterative method. Document: the
convergence criterion, the relevant tolerance parameter(s), and what happens
when the algorithm fails to converge (error vs. warning, and what if anything
is returned).

**`@section Missing Data`.** Required for any function with a `missing_method`
argument or where NAs in predictors or weights produce non-obvious behavior.

**`@section Replicate Weights`.** Include if the function accepts objects that
may contain replicate weight columns and the behavior on those columns differs
from the scalar-weight path.

**`@details`.** Required. Statistical details that cannot be captured in
`@description` must appear here, organized into named sections.

**`@references`.** Required. Every Tier 3 function implements a published method
and must cite its source(s).

### Illustrative examples

- `ipw()` — Algorithm section with the propensity model and weight formula;
  Convergence section for the IWLS fitting procedure; Missing Data section for
  `missing_method`; `@references`
- `calibrate_rake()` — Algorithm section with iterative proportional fitting;
  Convergence section; `@references`
- `calibrate_linear()` — Algorithm section with the GREG estimator equations;
  Convergence section (Newton-Raphson or equivalent); `@references`
- `calibrate_logit()` — Algorithm section with logit-bounded calibration;
  Convergence section; `@references`
- `poststratify()` — Algorithm section with the cell-factor formula; no
  Convergence section (direct calculation, not iterative); `@references`
- `create_bootstrap_weights()` — Algorithm section with the bootstrap resampling
  scheme using `\deqn{}` for the variance estimator; no Convergence section (not
  iterative); `@references`
- `trim_weights()` — Algorithm section describing the trimming and redistribution
  procedure; no Convergence section; `@references`

---

## Tier 4 — Dispatcher

> All Universal Rules (see preamble) apply.

### Criteria

Tier 4 functions route to other functions based on an argument value. They
implement no algorithm of their own.

**`@description`.** Follow the Universal Rules: describe the mechanism, key
nuance, or an important behavioral constraint — not just "routes to X, Y, Z".
End with a sentence naming the dispatched functions and the argument that
controls dispatch. For example: "Routes to `calibrate_rake()`,
`calibrate_linear()`, or `calibrate_logit()` based on `method`."

**`@param`.** Write full, substantive documentation using the same language as
the dispatched functions. When an argument behaves consistently across all
dispatched functions, document it fully — including class-specific behavior,
replicate weight handling, and behavioral guarantees. When an argument's
behavior genuinely differs across methods, write a summary description that
applies across all methods and direct to the specific functions for the
differences.

The dispatch argument (`method`, `type`, etc.) lists all accepted values with a
brief characterization of each — enough for a user to choose without reading
the dispatched functions.

**`@details`.** Required. Provide a high-level overview of each method:
enough to understand the differences and choose between them, including math
notation where it helps distinguish methods. Each method description uses an
inline citation to tie references to the relevant method (e.g., "Linear
calibration (Deville & Särndal, 1992) minimizes..."). End by directing to
the specific dispatched functions for full algorithm documentation.

Do not replicate the full Algorithm sections of the dispatched functions.

**`@section Algorithm`.** Do not use — the high-level method overview lives in
`@details`; full algorithm documentation lives in the dispatched functions.

**`@section Convergence`.** Do not use.

**`@references`.** Required. The `@details` inline citations provide the
contextual signal for which reference belongs to which method; the `@references`
block is the complete list that backs them up. Because inline citations in
`@details` are load-bearing for dispatchers, if citations cannot be verified
(no `comprehension.md` exists for the relevant spec), the `@details` method
overview and `@references` block must both wait until verification is possible
rather than being written without citations.

**`@seealso`.** Required. Must link to every function the dispatcher routes to.

### Illustrative examples

- `calibrate()` — full `@param` docs matching the dispatched functions; `@details`
  with a high-level overview of `"rake"`, `"linear"`, and `"logit"` using inline
  citations to tie each method to its reference; `@references` block; `@seealso`
  listing all three dispatched functions; note that `poststratify()` is a separate
  function not routed through `calibrate()`
- `create_replicate_weights()` — same pattern; `@details` overviews each
  resampling scheme (bootstrap, BRR, jackknife, etc.) with inline citations

---

## Dataset Documentation

Dataset documentation is governed by the codoc rule in
`r-package-conventions.md`: a single `\describe{}` block in `@format`, every
column documented with a `\item{}` entry, no splitting into multiple
`\describe{}` blocks. Read that document for the full codoc rule.

The following rules supplement it for surveywts datasets:

**`@source`.** Required. Cite the data source with enough detail to locate the
original data: survey name, sponsoring organization, year, and a stable URL if
one exists.

**`@description`.** Describe: (1) the population the dataset represents, (2) the
sampling design if known, and (3) the purpose of the dataset within the package —
which exported functions it is intended to support as example data.

**`@examples`.** Not required for datasets. If included, demonstrate the primary
use case (typically: calling the function the dataset was created to support).
