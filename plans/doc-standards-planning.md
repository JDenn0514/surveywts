# Documentation Standards Planning

## Context and Goal

The surveywts package documentation feels inconsistent across functions — depth, structure,
and content vary without a principled system behind them. The goal is to build a
comprehensive rule document (`.claude/rules/function-documentation.md`) that defines
exactly how every exported function should be documented, so that:

1. **Immediately**: each existing function can be audited against the standard and
   updated to fix inconsistencies
2. **Long-term**: every new function written has a clear, agent-readable reference
   for what its documentation should look like

This document records all decisions made during the brainstorming session, plus
unresolved questions to be answered before the rule document is written.

---

## Structural Decisions

### Artifact type
A **rule document** (not an audit checklist or skill). Lives in `.claude/rules/`
alongside `testing-standards.md`, `r-package-conventions.md`, etc. Referenced from
`CLAUDE.md`. Always loaded into agent context — documentation is a constant constraint
on every implementation, not a phase-specific workflow.

### Document structure
**Universal preamble + self-contained tier criteria.**

- The universal preamble defines format/structure rules that apply identically at every tier.
- Each tier section defines depth/content requirements specific to that tier.
- Each tier section begins with a single reminder line: "All Universal Rules (see preamble) apply."
- No cross-referencing within tier sections — a tier section must be self-contained
  for its own criteria.
- Rationale: agents follow self-contained instructions better than cross-referenced ones;
  the preamble stays warm in context when reading tier criteria.

### Tier system
Four tiers plus a separate dataset documentation section:

| Tier | Label | Functions |
|------|-------|-----------|
| 1 | Utility | `effective_sample_size`, `weight_variability`, `stabilize_weights` |
| 2 | Standard | `summarize_weights`, `adjust_nonresponse`, `redistribute_weights` |
| 3 | Algorithmic | `calibrate_rake`, `calibrate_linear`, `calibrate_logit`, `ipw`, `trim_weights` |
| 4 | Dispatcher | `calibrate`, `create_replicate_weights` |
| — | Dataset | Separate section; not a tier |

**Uncertain assignments** (unresolved — see below):
- `calibrate_to_survey`, `calibrate_to_estimate` — probably Tier 3
- `as_taylor_design` — probably Tier 1 or 2
- `create_bootstrap_weights`, `create_brr_weights`, `create_jackknife_weights`,
  `create_gen_boot_weights`, `create_gen_rep_weights`, `create_sdr_weights`,
  `create_group_jackknife_weights` — probably Tier 2 or 3

---

## Universal Rules (Fully Resolved)

These apply to every exported function regardless of tier.

### Title
- Active verb phrase, present tense ("Clip weights to a range", not "Clipping of weights")
- Do not repeat the function name's verb — use synonyms to give a second angle on intent
- Drop "survey weights" — implicit from the package context, wastes space
- Describe what is unique about this function vs. its siblings in the same family
- Must be informative when skimming the reference index
- Follow r-pkgs.org title guidance: https://r-pkgs.org/man.html#title

### Description
- Must add information the title does not contain — no restating the title in prose
- Title = high-level summary; description = mechanism, key nuance, or important behavior
- No formulas in `@description` — formulas belong in the Algorithm section
- Follow r-pkgs.org description guidance

### `@param` format
- Lead with the type annotation (e.g., `A data.frame, weighted_df, or survey_taylor.`)
- When documenting defaults: state the default first and explicitly call it the default
- **Inline vs. bullets (Option C — complexity-based)**:
  - Inline if each option fits a single-phrase description
  - Bullets or fenced code blocks if any option requires its own sentence or sub-structure
- `@param` describes the **effect** of the argument on behavior/output — not the internal
  mechanism. Mechanism content belongs in `@details` / named `@section` blocks.

### `@returns` (preferred over `@return`)
- Required on all exported functions
- Describe the output's **shape** (class, class-preservation) AND **behavioral guarantees**
  (what properties hold on the output — e.g., "weights sum to `n`")
- Enumerate by input class only when behavior meaningfully differs across classes;
  if every class produces the same class of output with the same properties, a one-liner
  is correct — do not enumerate for its own sake
- Do not define package-level concepts (weighting history) inside `@returns` — reference
  them consistently with standard phrasing
- **Standard phrasing for history entries**: "A new entry with
  `operation = "fn_name"` is appended to the weighting history."

### `@details`
- For content that cannot be captured in `@description`
- Formulas belong here (specifically in the Algorithm section), not in `@description`
- Mechanism / algorithm logic belongs here, not in `@param`
- Whether `@details` is required depends on tier (see tier-specific rules)

### Named `@section` blocks
Six canonical sections — use when applicable, in this canonical order:

1. **Algorithm** — statistical algorithm(s), formulas, mathematical details. For
   multi-algorithm functions, use bold sub-headers per algorithm.
2. **Convergence** — criteria, tolerance parameters, what happens on failure.
3. **Missing Data** — how NAs in predictors or weights are handled.
4. **Replicate Weights** — how `survey_replicate` input is handled; behavioral differences
   from the main weight path.
5. **Limitations** — known failure modes, cases where results are unreliable without an
   error being thrown, when to prefer an alternative.
6. **Warnings** — when warnings may occur and how to resolve them. No warning class names —
   describe the condition and resolution in plain language.

**Custom sections are permitted** when content is genuinely distinct from all six canonical
sections. This list is not exhaustive. Example: a weighting history viewer function might
warrant a "Weighting History" section.

**Format**: `@section` for top-level named sections; `**bold text**` for sub-sections
within a section. (Roxygen2 does not support nested `@section` — bold headers are the
only structural option for sub-sections.)

### `@references`
- Required for any function implementing a published method
- Standard academic citation format
- **In-line citations** (e.g., "Potter & Zheng (2015)" in description text): optional.
  If included, must be verified against the relevant `comprehension.md` for that spec.
  If no `comprehension.md` exists, omit in-line citations entirely.
- Rationale: incorrect in-line citations are worse than none. The `@references` section
  is the authoritative source.

### `@seealso`
Required (not optional) in three cases:
1. **Dispatchers** → all functions the dispatcher routes to
2. **Sibling functions** within the same `@family`
3. **Canonical companions** — closely related functions a user would naturally reach for
   next (e.g., `npors_2025_ref` / `npors_2025_clean_ref`, `ipw` / `summarize_weights`)

### `@examples`
Examples are based on **argument complexity and output variability**, not tier.

**Required content:**
- Always: simplest working call with package data (`data.frame` input)
- Always (for functions accepting survey objects): at least one survey object example
  that demonstrates the **unique behavior** of that input class, not just that it compiles
- When an argument accepts multiple formats: show each format (e.g., `targets` Format A
  and Format B in calibration functions)
- When a function has a `method` or `algorithm` argument: demonstrate each
- When a `by` argument is present: show its effect on output structure

**Package data rule**: package data is required in all examples. If a function's examples
cannot use package data as-is, flag the dataset for remediation in planning docs — do not
substitute inline data as a workaround.

**Comment style**:
- Comments explain **why**, not what
- "What" comments are noise — if the code needs a what comment, the issue is the code
- Section headers are the exception: they label the scenario being demonstrated
- Section header format: `# Brief scenario label --------------------------`
  (dashes fill to ~76 characters, consistent with air formatter style)

**Length check**: if the example block exceeds ~25 lines, consider whether longer cases
belong in a vignette rather than `@examples`.

### Errors and warnings
- **Input validation errors**: not documented in help pages (redundant with `@param`)
- **Algorithmic errors** (e.g., convergence failure): documented in the relevant named
  section (Convergence)
- **Warnings**: documented in the dedicated Warnings section — plain language description
  of when the warning occurs and how to resolve it; no class names

### Dispatcher tier specifics
- No `@details`
- `@seealso` required, pointing to all dispatched functions
- `@param` docs are thin, explicitly cross-referencing dispatched functions for full details

---

## Tier-Specific Criteria (Resolved Portion)

### Tier 1 — Utility
- `@details` / Algorithm section: required only if the function has a formula
- If no formula: `@details` is likely not needed
- `@references`: required if based on a published method (Kish's ESS formula → yes)

### Tier 2 — Standard
- `@details` / Algorithm section: when mechanism cannot be captured in 2–3 sentences
- `@references`: required if based on a published method

### Tier 3 — Algorithmic
- `@section Algorithm`: **required** — formulas, algorithm descriptions, bold sub-headers
  for multiple algorithms
- `@section Convergence`: required for any iterative method
- `@details` explicitly required for statistical details
- `@references`: required

### Tier 4 — Dispatcher
- `@details`: not used
- `@seealso`: required → all dispatched functions
- `@param`: thin; cross-references dispatched functions for full argument documentation

### Dataset Documentation
Covered by existing rules in `r-package-conventions.md` (single `\describe{}` block,
all columns documented). Any additional dataset-specific rules to be determined when
writing the rule document.

---

## Unresolved Questions

These must be answered before the rule document is written.

1. **Function-to-tier assignment table**: Should the rule document include a table
   assigning every current function to its tier? Or just the criteria, with tier
   assignment left implicit?

2. **Uncertain tier assignments**: Confirm which tier each of the following belongs to:
   - `calibrate_to_survey`, `calibrate_to_estimate`
   - `as_taylor_design`
   - `create_bootstrap_weights`, `create_brr_weights`, `create_jackknife_weights`,
     `create_gen_boot_weights`, `create_gen_rep_weights`, `create_sdr_weights`,
     `create_group_jackknife_weights`

3. **`@inheritParams`**: When should it be used vs. writing out param docs directly?
   (e.g., `summarize_weights` uses `@inheritParams effective_sample_size` for the
   shared `x` and `weights` params, but the three diagnostic functions don't
   cross-inherit consistently)

4. **Mathematical notation**: Should `\deqn{}` / `\eqn{}` be required in Algorithm
   sections for any formula? Or is inline code sufficient for simple formulas?

5. **Class-specific behavior in `@param data`**: Some functions describe class-specific
   behavior inside `@param data` (e.g., "for `survey_replicate`, all replicate columns
   are also trimmed"). Should this move to the Replicate Weights section, or stay in
   `@param data`?

---

## Next Steps

1. Open a new session with the continuation prompt below
2. Answer the five unresolved questions above (one at a time)
3. Write the rule document to `.claude/rules/function-documentation.md`
4. Do **not** update any existing function documentation yet — the rule document
   is the only artifact from this phase; applying it is a separate implementation task
