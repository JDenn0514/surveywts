# create_brr_weights() replaces survey's untyped FPC warning with a typed one

    Code
      result <- create_brr_weights(d$fpc)
    Condition
      Warning:
      ! `create_brr_weights()` does not apply the finite population correction in N.
      i Standard errors from the returned design do not include this correction.
      i To apply it, use `create_jackknife_weights(type = "jkn")` or `create_bootstrap_weights(type = "Rao-Wu-Yue-Beaumont")`.

# create_brr_weights(rho > 0) replaces survey's untyped FPC warning with a typed one

    Code
      result <- create_brr_weights(d$fpc, rho = 0.3)
    Condition
      Warning:
      ! `create_brr_weights(rho = 0.3)` does not apply the finite population correction in N.
      i Standard errors from the returned design do not include this correction.
      i To apply it, use `create_jackknife_weights(type = "jkn")` or `create_bootstrap_weights(type = "Rao-Wu-Yue-Beaumont")`.

# create_bootstrap_weights(type = 'Rao-Wu') warns that the FPC is not applied

    Code
      result <- create_bootstrap_weights(d$fpc, type = "Rao-Wu", replicates = 20L)
    Condition
      Warning:
      ! `create_bootstrap_weights(type = "Rao-Wu")` does not apply the finite population correction in N.
      i Standard errors from the returned design do not include this correction.
      i To apply it, use `create_jackknife_weights(type = "jkn")` or `create_bootstrap_weights(type = "Rao-Wu-Yue-Beaumont")`.

# create_bootstrap_weights(type = 'Antal-Tille') warns that the FPC is not applied

    Code
      result <- create_bootstrap_weights(d$fpc, type = "Antal-Tille", replicates = 20L)
    Condition
      Warning:
      ! `create_bootstrap_weights(type = "Antal-Tille")` does not apply the finite population correction in N.
      i Standard errors from the returned design do not include this correction.
      i To apply it, use `create_jackknife_weights(type = "jkn")` or `create_bootstrap_weights(type = "Rao-Wu-Yue-Beaumont")`.

# create_jackknife_weights(type = 'grouped') replaces svrep's untyped FPC warning with a typed one

    Code
      result <- create_jackknife_weights(d$fpc, type = "grouped", replicates = 4L,
      seed = 1L)
    Condition
      Warning:
      ! `create_jackknife_weights(type = "grouped")` does not apply the finite population correction in N.
      i Standard errors from the returned design do not include this correction.
      i To apply it, use `create_jackknife_weights(type = "jkn")` or `create_bootstrap_weights(type = "Rao-Wu-Yue-Beaumont")`.

