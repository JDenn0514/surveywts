# Function Documentation — Worked Examples and Per-Tier Detail

Detail moved out of `.claude/rules/function-documentation.md`. The rules
themselves live there; this file shows how to apply them. Read this when
documenting a new exported function and the correct format is not obvious
from the rule tables.

---

## `@param` examples

```r
#' @param data A data.frame, weighted_df, or survey_nonprob.
#' @param method `"logit"` (the default), `"probit"`, or `"cloglog"`.
```

`@param data` forward-references class-specific behavior rather than
describing it inline:

```r
#' @param data A data.frame, weighted_df, or survey_nonprob. For inputs
#'   containing replicate weight columns, see the **Replicate Weights** section.
```

`@inheritParams` — a code comment above the tag identifies the source:

```r
# x and weights are identical in behavior to effective_sample_size()
#' @inheritParams effective_sample_size
```

## `@returns` example

```r
#' @returns A `survey_nonprob` with updated weights. If the input contains
#'   replicate weight columns, all replicate weight columns are updated by
#'   the same method.
```

## `@references` format

```
Kish, L. (1965). _Survey Sampling_. John Wiley & Sons.
```

In-line citations ("Kish (1965)" within prose) are optional and only used
when verified against a `comprehension.md` for the relevant spec.

## `@examples` comment style

Comments explain why, not what. Section headers label the scenario:

```r
#' @examples
#' # Rake to margins on a data.frame -------------------------------------
#' result <- calibrate_rake(nps_2025, targets = age_targets)
#'
#' # Rake on a survey_nonprob, showing the count-type target format -------
#' result <- calibrate_rake(nonprob_design, targets = age_counts, type = "count")
```

## Internal function documentation

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

Single-purpose transformations or extractions. A defined operation —
possibly a published formula — with no iterative algorithm, optimization,
or model fitting.

- `@details`/Algorithm required only if the function has a formula.
- Convergence: not applicable.
- Missing Data: include if NAs in the input produce non-obvious behavior.
- Replicate Weights: include if the function accepts objects that may carry
  replicate weight columns and the behavior differs from the scalar path.
- `@references`: required only if the function implements a published
  formula.

Illustrative:
- `effective_sample_size()` — has a formula (Kish 1965); Algorithm section
  with `\deqn{}` and a `@references` entry
- `rescale_weights()` — simple enough for `@description` alone; no
  Algorithm section
- `as_taylor_design()` — structural conversion, no formula, minimal
  `@details`, no `@references`

## Tier 2 — Standard

Multiple steps or decision paths, no iterative algorithm or optimization.

- `@details`/Algorithm required when the mechanism cannot be captured in
  2-3 `@description` sentences. Describe each method path briefly; formulas
  only if named and published.
- Convergence: not applicable — Tier 2 is not iterative.
- Missing Data: include when non-obvious or when a `missing_method`
  argument exists.
- Replicate Weights: same rule as Tier 1.
- `@references`: required if based on a published method.

Illustrative:
- `adjust_nonresponse()` — multiple adjustment methods; Algorithm section
  per method; no Convergence section
- `summarize_weights()` — descriptive output; `@description` likely
  sufficient
- `redistribute_weights()` — procedural; brief Algorithm section if the
  rule needs more than 2-3 sentences

## Tier 3 — Algorithmic

A statistical algorithm with a defined formula, optimization procedure, or
resampling scheme — may be iterative with convergence criteria.

- `@section Algorithm`: required, with `\eqn{}`/`\deqn{}` wherever notation
  needs sub/superscripts, Greek letters, or summation. Bold sub-headers per
  algorithm for multi-method functions.
- `@section Convergence`: required for any iterative method — criterion,
  tolerance parameter(s), and failure behavior (error vs. warning, what if
  anything is returned).
- `@section Missing Data`: required for any `missing_method` argument or
  non-obvious NA behavior.
- Replicate Weights: same rule as Tier 1.
- `@details`: required.
- `@references`: required — every Tier 3 function implements a published
  method.

Illustrative:
- `ipw()` — Algorithm (propensity model, weight formula); Convergence
  (IWLS fitting); Missing Data (`missing_method`); `@references`
- `calibrate_rake()` — Algorithm (iterative proportional fitting);
  Convergence; `@references`
- `calibrate_linear()` — Algorithm (GREG estimator equations); Convergence
  (Newton-Raphson or equivalent); `@references`
- `calibrate_logit()` — Algorithm (logit-bounded calibration); Convergence;
  `@references`
- `poststratify()` — Algorithm (cell-factor formula); no Convergence
  (direct calculation); `@references`
- `create_bootstrap_weights()` — Algorithm with `\deqn{}` for the variance
  estimator; no Convergence (not iterative); `@references`
- `trim_weights()` — Algorithm (trimming and redistribution procedure); no
  Convergence; `@references`

## Tier 4 — Dispatcher

Routes to other functions based on an argument value; implements no
algorithm of its own.

- `@description`: names the dispatched functions and the controlling
  argument, e.g. "Routes to `calibrate_rake()`, `calibrate_linear()`, or
  `calibrate_logit()` based on `method`."
- `@param`: full, substantive docs matching the dispatched functions. When
  behavior differs genuinely across methods, write a summary applying
  across all methods and direct to the specific functions for differences.
  The dispatch argument (`method`, `type`, ...) lists every accepted value
  with a brief characterization.
- `@details`: required — a high-level overview per method, with an inline
  citation per method (e.g., "Linear calibration (Deville & Särndal, 1992)
  minimizes..."), ending with a pointer to the dispatched functions for full
  algorithm documentation. Never replicate their Algorithm sections.
- `@section Algorithm` / `@section Convergence`: do not use — the overview
  lives in `@details`; full algorithm docs live in the dispatched functions.
- `@references`: required — the complete list backing the `@details`
  citations. If citations can't be verified (no `comprehension.md` exists),
  both the `@details` overview and `@references` wait until verification is
  possible, rather than shipping without citations.
- `@seealso`: required — link every function the dispatcher routes to.

Illustrative:
- `calibrate()` — full `@param` docs matching the dispatched functions;
  `@details` overviewing `"rake"`, `"linear"`, `"logit"` with inline
  citations; `@references`; `@seealso` to all three; note that
  `poststratify()` is a separate function, not routed through `calibrate()`
- `create_replicate_weights()` — same pattern; `@details` overviews each
  resampling scheme (bootstrap, BRR, jackknife, ...) with inline citations

---

## Dataset documentation detail

`@source` cites the survey name, sponsoring organization, year, and a
stable URL if one exists. `@description` covers: (1) the population the
dataset represents, (2) the sampling design if known, (3) which exported
functions the dataset supports as example data. `@examples` are not
required for datasets — if included, demonstrate the primary use case.
