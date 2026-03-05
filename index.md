# surveywts

surveywts provides tidy tools for calibrating survey weights to known
population totals, adjusting for nonresponse, and diagnosing weight
quality — all with full weighting history tracking for reproducible
survey analysis.

## Installation

``` r
# From GitHub (development version)
pak::pak("JDenn0514/surveywts")

# From r-universe (pre-built binaries, no GitHub PAT needed)
install.packages("surveywts", repos = "https://jdenn0514.r-universe.dev")
```

## Overview

surveywts is part of the [surveyverse](https://github.com/JDenn0514)
ecosystem. It provides three calibration methods, nonresponse
adjustment, and weight diagnostics — all using tidy, formula-free
syntax.

| Function                                                                                              | Purpose                                           |
|-------------------------------------------------------------------------------------------------------|---------------------------------------------------|
| [`calibrate()`](https://jdenn0514.github.io/surveywts/reference/calibrate.md)                         | GREG calibration to population totals             |
| [`rake()`](https://jdenn0514.github.io/surveywts/reference/rake.md)                                   | Raking (iterative proportional fitting)           |
| [`poststratify()`](https://jdenn0514.github.io/surveywts/reference/poststratify.md)                   | Post-stratification to cell counts or proportions |
| [`adjust_nonresponse()`](https://jdenn0514.github.io/surveywts/reference/adjust_nonresponse.md)       | Nonresponse adjustment via weighting classes      |
| [`effective_sample_size()`](https://jdenn0514.github.io/surveywts/reference/effective_sample_size.md) | ESS (Kish approximation)                          |
| [`weight_variability()`](https://jdenn0514.github.io/surveywts/reference/weight_variability.md)       | CV and design effect of weights                   |
| [`summarize_weights()`](https://jdenn0514.github.io/surveywts/reference/summarize_weights.md)         | Summary statistics, optionally by group           |

Every function tracks the full weighting history so you can audit
exactly what transformations were applied and in what order.

## Usage

``` r
library(surveywts)
```

## Learn more

Full documentation is available at
<https://jdenn0514.github.io/surveywts/>.
