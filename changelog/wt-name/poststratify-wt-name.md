# poststratify() — `wt_name` argument

## New features

- `poststratify()` gains a `wt_name` argument (default `"wts"`) that controls
  the name of the output weight column when the input is a `data.frame` or
  `weighted_df`. The previous hardcoded default was `".weight"`.
- Input weight columns are preserved when `wt_name` differs from the input
  column name.
- `wt_name` is silently ignored for survey object inputs.

## Breaking changes

- The default output weight column name changes from `".weight"` to `"wts"`
  for plain `data.frame` inputs with `weights = NULL`.
