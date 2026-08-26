# Function Documentation Standards

**Version:** 1.1
**Status:** Decided — applies to all exported functions in surveywts

Authoritative reference for documentation audits and new function
implementations. Related: `r-package-conventions.md` (codoc, NAMESPACE,
export policy), `code-style.md` (error structure, S7 patterns),
`surveywts-conventions.md` (`@family` tags, file organization).

## Universal Rules (every exported function)

- **Title** — active verb phrase, present tense; use a synonym for the
  function's own verb; drop "survey weights" (implicit); must be
  informative in isolation on the pkgdown index.
- **Description** — adds information the title doesn't have; no formulas
  (those go in `@details` Algorithm); 1-3 sentences.
- **`@param`** — lead with a type annotation; state the default and call it
  the default explicitly; inline for single-phrase options, a bullet list or
  fenced block for options needing their own sentence; describe effect on
  behavior, not internal mechanism. `@param data` leads with accepted
  classes and forward-references class-specific sections instead of
  describing them inline.
- **`@inheritParams`** — only when the argument is identical in behavior
  (not just name); always with a code comment above naming the source.
- **`@returns`** (not `@return`) — required on every export; describe shape
  (class, class-preservation) and behavioral guarantees; enumerate by input
  class only when behavior meaningfully differs; use the standard phrasing
  "A new entry with `operation = "fn_name"` is appended to the weighting
  history" for history-appending functions.
- **`@details`** — mechanism/algorithm content that doesn't fit
  `@description`; formulas live here, in the Algorithm section.
- **Named `@section` blocks** — six canonical sections, in this order, when
  applicable: **Algorithm** (formulas; bold sub-headers per algorithm for
  multi-method functions) → **Convergence** (criterion, tolerance, failure
  behavior) → **Missing Data** (non-obvious NA handling or a
  `missing_method` arg) → **Replicate Weights** (scope difference: method
  applies to all replicate weight columns too) → **Limitations** (known
  failure modes, when to prefer an alternative) → **Warnings** (plain
  language, no class names). Custom sections are allowed when content is
  genuinely distinct from all six. Use `**Bold text**` for sub-sections —
  roxygen2 has no nested `@section`.
- **`@references`** — required for any published method; standard academic
  format. In-line citations are optional, and only if verified against a
  `comprehension.md` for the spec; omit if none exists.
- **`@seealso`** — required for dispatchers (every routed function), sibling
  functions (all of the same `@family`), and canonical companions.
- **`@examples`** — always use package data; no `\dontrun{}` except genuine
  external resources; show every accepted `targets`/argument format and
  every `method`/`algorithm` value; show a `by` argument's effect on output
  structure; keep to ~25 lines, else move the long case to a vignette.
  Comments explain why, not what; section headers label the scenario
  (`# Brief scenario label ---------------------------`).
- **Errors and warnings** — do not document input-validation errors (that's
  `@param`'s job); document algorithmic errors (convergence failure,
  rank-deficient system) in the relevant named section; document warnings in
  the Warnings section, plain language, no class names.
- **Mathematical notation** — inline code for simple arithmetic/ratios with
  no sub/superscripts or Greek letters; `\eqn{}` for inline expressions that
  have them; `\deqn{}` for display equations.
- **Internal helpers** — obvious one-liners get no roxygen; complex helpers
  get `@keywords internal` + `@noRd`.

## Tiers

| Tier | Criteria | Required beyond the Universal Rules |
|---|---|---|
| 1 Utility | Single transformation, no iteration | Algorithm section only if it has a formula; `@references` only if the formula is published |
| 2 Standard | Multiple steps or method paths, no iteration | Algorithm section when 2-3 sentences cannot carry the mechanism; Missing Data when a `missing_method` arg exists |
| 3 Algorithmic | Statistical algorithm, formula, or optimisation | Algorithm, `@details`, `@references` always; Convergence when iterative; Missing Data when NAs are non-obvious |
| 4 Dispatcher | Routes on an argument value | Full `@param` docs; `@details` method overview with inline citations; `@references`; `@seealso` to every routed function. No Algorithm or Convergence section. |

Tier 4 dispatchers additionally: describe the mechanism in `@description`,
not just "routes to X, Y, Z"; write full `@param` docs matching the
dispatched functions; `@details` gives a high-level overview of each method
with inline citations, ending with a pointer to the dispatched functions for
full algorithm documentation — never replicate their Algorithm sections.

## Dataset documentation

Governed by the codoc rule in `r-package-conventions.md`: one `\describe{}`
block in `@format`, every column documented. `@source` is required (survey
name, sponsor, year, stable URL). `@description` covers the population, the
sampling design if known, and which exported functions the dataset supports.
`@examples` are not required for datasets.

---
Worked examples and rationale: `.claude/references/function-documentation-detail.md`.
Read it when documenting a new exported function and the tier's requirements
or the section format are not obvious from the tables above.
