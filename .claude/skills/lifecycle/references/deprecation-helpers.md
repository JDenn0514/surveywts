# Deprecation Helpers

## Helper for Deprecations Affecting Many Functions

For deprecations affecting many functions (e.g., removing a common argument),
create an internal helper:

```r
warn_for_verbose <- function(
  verbose = TRUE,
  env = rlang::caller_env(),
  user_env = rlang::caller_env(2)
) {
  if (!lifecycle::is_present(verbose) || isTRUE(verbose)) {
    return(invisible())
  }

  lifecycle::deprecate_warn(
    when = "2.0.0",
    what = I("The `verbose` argument"),
    details = c(
      "Set `options(mypkg_quiet = TRUE)` to suppress messages.",
      "The `verbose` argument will be removed in a future release."
    ),
    user_env = user_env
  )

  invisible()
}
```

Then use in affected functions:

```r
my_function <- function(..., verbose = deprecated()) {
  warn_for_verbose(verbose)
  # ...
}
```

## Custom Deprecation Messages

For non-standard deprecations, use `I()` to wrap custom text:

```r
lifecycle::deprecate_warn(
  when = "1.0.0",
  what = I('Setting option "pkg.opt" to "foo"'),
  with = I('"pkg.new_opt"')
)
```

The `what` fragment must work with "was deprecated in..." appended.
