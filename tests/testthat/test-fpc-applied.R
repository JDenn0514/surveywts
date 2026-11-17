# tests/testthat/test-fpc-applied.R
#
# @variables$fpc_applied on the designs create_*_weights() builds, and
# surveywts_warning_fpc_not_applied (issue #130).
#
# Every row of .fpc_applied_map is pinned by a measured test: the standard
# error of a total, built with and without the FPC under the same seed. A
# method that applies the FPC moves the ratio to the Taylor ratio. A method
# that does not leaves it at exactly 1.
#
# make_fpc_designs() (helper-test-data.R) samples 4 of N = 8 PSUs in each
# stratum by default, so f = 0.5 and the Taylor ratio is sqrt(0.5).
#
# Sections:
#   1. The recorded value, one block per map row
#   2. Measured SE ratios that pin each row
#   3. No FPC on the source: both keys NULL, no warning
#   4. surveywts_warning_fpc_not_applied
#   5. as_svydesign() on a design built from an FPC source

# Build a design twice, with and without the FPC, quietly. The FPC warning is
# tested in section 4; here only the numbers matter.
.build_pair <- function(fn, designs) {
  list(
    fpc = suppressWarnings(fn(designs$fpc)),
    none = fn(designs$none)
  )
}

.se_ratio <- function(pair) {
  rep_se_total(pair$fpc) / rep_se_total(pair$none)
}

# ============================================================================
# 1. The recorded value
# ============================================================================

test_that("create_jackknife_weights(type = 'jkn') records fpc_applied = 'rscales'", {
  d <- make_fpc_designs()
  result <- create_jackknife_weights(d$fpc, type = "jkn")
  test_invariants(result)
  expect_identical(result@variables$fpc, "N")
  expect_identical(result@variables$fpc_applied, "rscales")
})

test_that("create_jackknife_weights(type = 'jk1') records fpc_applied = 'rscales'", {
  d <- make_fpc_designs(
    n_strata = 1L,
    psus_per_stratum = 20L,
    N = 50L,
    strata = FALSE
  )
  result <- create_jackknife_weights(d$fpc, type = "jk1")
  test_invariants(result)
  expect_identical(result@variables$fpc, "N")
  expect_identical(result@variables$fpc_applied, "rscales")
})

test_that("create_jackknife_weights(type = 'grouped') records fpc_applied = 'none'", {
  d <- make_fpc_designs()
  expect_warning(
    result <- create_jackknife_weights(
      d$fpc,
      type = "grouped",
      replicates = 4L,
      seed = 1L
    ),
    class = "surveywts_warning_fpc_not_applied"
  )
  test_invariants(result)
  expect_identical(result@variables$fpc, "N")
  expect_identical(result@variables$fpc_applied, "none")
})

test_that("create_bootstrap_weights() records the mapped fpc_applied for each type", {
  d <- make_fpc_designs()
  expected <- c(
    `Rao-Wu-Yue-Beaumont` = "repweights",
    Preston = "repweights",
    `Canty-Davison` = "repweights",
    `Rao-Wu` = "none",
    `Antal-Tille` = "none"
  )
  for (ty in names(expected)) {
    result <- suppressWarnings(
      create_bootstrap_weights(d$fpc, type = ty, replicates = 20L, seed = 1L)
    )
    test_invariants(result)
    expect_identical(result@variables$fpc, "N")
    expect_identical(result@variables$fpc_applied, expected[[ty]])
  }
})

test_that("create_gen_boot_weights() records fpc_applied = 'repweights'", {
  d <- make_fpc_designs()
  result <- suppressMessages(
    create_gen_boot_weights(d$fpc, replicates = 20L, seed = 1L)
  )
  test_invariants(result)
  expect_identical(result@variables$fpc, "N")
  expect_identical(result@variables$fpc_applied, "repweights")
})

test_that("create_gen_rep_weights() records fpc_applied = 'repweights'", {
  d <- make_fpc_designs()
  result <- suppressMessages(create_gen_rep_weights(d$fpc, seed = 1L))
  test_invariants(result)
  expect_identical(result@variables$fpc, "N")
  expect_identical(result@variables$fpc_applied, "repweights")
})

test_that("create_sdr_weights() records fpc_applied = 'repweights'", {
  d <- make_fpc_designs()
  result <- suppressMessages(create_sdr_weights(d$fpc, replicates = 20L))
  test_invariants(result)
  expect_identical(result@variables$fpc, "N")
  expect_identical(result@variables$fpc_applied, "repweights")
})

test_that("create_brr_weights() records fpc_applied = 'none' for BRR and Fay", {
  d <- make_fpc_designs(psus_per_stratum = 2L)
  for (rho in c(0, 0.3)) {
    expect_warning(
      result <- create_brr_weights(d$fpc, rho = rho),
      class = "surveywts_warning_fpc_not_applied"
    )
    test_invariants(result)
    expect_identical(result@variables$fpc, "N")
    expect_identical(result@variables$fpc_applied, "none")
  }
})

# ============================================================================
# 2. Measured SE ratios
# ============================================================================

test_that("JKn replicate SE with the FPC equals the Taylor SE with the FPC", {
  skip_if_not_installed("survey")
  d <- make_fpc_designs()
  result <- create_jackknife_weights(d$fpc, type = "jkn")
  test_invariants(result)
  expect_equal(
    rep_se_total(result),
    taylor_se_total(d$fpc),
    tolerance = 1e-8
  )
})

test_that("JK1 replicate SE with the FPC equals the Taylor SE with the FPC", {
  skip_if_not_installed("survey")
  d <- make_fpc_designs(
    n_strata = 1L,
    psus_per_stratum = 20L,
    N = 50L,
    strata = FALSE
  )
  result <- create_jackknife_weights(d$fpc, type = "jk1")
  test_invariants(result)
  expect_equal(
    rep_se_total(result),
    taylor_se_total(d$fpc),
    tolerance = 1e-8
  )
})

test_that("Rao-Wu-Yue-Beaumont, Preston, gen-boot, gen-rep and SDR apply the FPC", {
  skip_if_not_installed("survey")
  d <- make_fpc_designs()
  taylor_ratio <- taylor_se_total(d$fpc) / taylor_se_total(d$none)
  expect_equal(taylor_ratio, sqrt(0.5), tolerance = 1e-8)
  builders <- list(
    rwyb = function(x) {
      create_bootstrap_weights(
        x,
        type = "Rao-Wu-Yue-Beaumont",
        replicates = 200L,
        seed = 3L
      )
    },
    preston = function(x) {
      create_bootstrap_weights(
        x,
        type = "Preston",
        replicates = 200L,
        seed = 3L
      )
    },
    gen_boot = function(x) {
      suppressMessages(create_gen_boot_weights(x, replicates = 200L, seed = 3L))
    },
    gen_rep = function(x) {
      suppressMessages(create_gen_rep_weights(x, seed = 3L))
    },
    sdr = function(x) suppressMessages(create_sdr_weights(x, replicates = 20L))
  )
  for (nm in names(builders)) {
    pair <- .build_pair(builders[[nm]], d)
    test_invariants(pair$fpc)
    expect_equal(.se_ratio(pair), taylor_ratio, tolerance = 1e-6, label = nm)
  }
})

test_that("gen-rep estimators that read the fraction from the weights put the FPC in the replicates", {
  skip_if_not_installed("survey")
  # Deville-1 reads each sampling fraction from 1 / weight, so the fpc column
  # changes nothing, and the SE matches the Taylor SE with the FPC.
  d <- make_fpc_designs()
  result <- suppressMessages(
    create_gen_rep_weights(d$fpc, variance_estimator = "Deville-1")
  )
  test_invariants(result)
  expect_identical(result@variables$fpc_applied, "repweights")
  expect_equal(
    rep_se_total(result),
    taylor_se_total(d$fpc),
    tolerance = 1e-6
  )
})

test_that("Canty-Davison applies the FPC: a census stratum gives every replicate the full-sample weight", {
  # With fpc = n_h in every stratum, the without-replacement draw from the
  # pseudo-population takes every PSU once, so every replicate weight equals
  # the full-sample weight and the SE is 0. Without the FPC it is positive.
  d <- make_fpc_designs(N = 4L)
  pair <- .build_pair(
    function(x) {
      create_bootstrap_weights(
        x,
        type = "Canty-Davison",
        replicates = 50L,
        seed = 1L
      )
    },
    d
  )
  test_invariants(pair$fpc)
  rep_mat <- as.matrix(pair$fpc@data[pair$fpc@variables$repweights])
  expect_equal(
    rep_mat,
    matrix(
      pair$fpc@data$w,
      nrow = nrow(rep_mat),
      ncol = ncol(rep_mat)
    ),
    tolerance = 1e-10,
    ignore_attr = TRUE
  )
  expect_identical(rep_se_total(pair$fpc), 0)
  expect_gt(rep_se_total(pair$none), 0)
})

test_that("Rao-Wu, Antal-Tille, grouped, BRR and Fay leave the SE unchanged", {
  d <- make_fpc_designs()
  dp <- make_fpc_designs(psus_per_stratum = 2L)
  cases <- list(
    rao_wu = list(d, function(x) {
      create_bootstrap_weights(x, type = "Rao-Wu", replicates = 50L, seed = 3L)
    }),
    antal_tille = list(d, function(x) {
      create_bootstrap_weights(
        x,
        type = "Antal-Tille",
        replicates = 50L,
        seed = 3L
      )
    }),
    grouped = list(d, function(x) {
      create_jackknife_weights(x, type = "grouped", replicates = 4L, seed = 3L)
    }),
    brr = list(dp, function(x) create_brr_weights(x)),
    fay = list(dp, function(x) create_brr_weights(x, rho = 0.3))
  )
  for (nm in names(cases)) {
    pair <- .build_pair(cases[[nm]][[2]], cases[[nm]][[1]])
    test_invariants(pair$fpc)
    expect_equal(.se_ratio(pair), 1, tolerance = 1e-10, label = nm)
  }
})

# ============================================================================
# 3. No FPC on the source
# ============================================================================

test_that("every create_*_weights() leaves fpc and fpc_applied NULL without an FPC", {
  d <- make_fpc_designs()
  dp <- make_fpc_designs(psus_per_stratum = 2L)
  d1 <- make_fpc_designs(
    n_strata = 1L,
    psus_per_stratum = 20L,
    N = 50L,
    strata = FALSE
  )
  results <- suppressMessages(list(
    create_jackknife_weights(d$none, type = "jkn"),
    create_jackknife_weights(d1$none, type = "jk1"),
    create_jackknife_weights(d$none, type = "grouped", replicates = 4L),
    create_bootstrap_weights(d$none, replicates = 20L, seed = 1L),
    create_bootstrap_weights(d$none, type = "Preston", replicates = 20L),
    create_bootstrap_weights(d$none, type = "Canty-Davison", replicates = 20L),
    create_gen_boot_weights(d$none, replicates = 20L, seed = 1L),
    create_gen_rep_weights(d$none, seed = 1L),
    create_sdr_weights(d$none, replicates = 20L),
    create_brr_weights(dp$none)
  ))
  for (result in results) {
    test_invariants(result)
    expect_null(result@variables$fpc)
    expect_null(result@variables$fpc_applied)
  }
})

test_that("BRR, Fay, Rao-Wu, Antal-Tille and Preston raise no warning without an FPC", {
  d <- make_fpc_designs()
  dp <- make_fpc_designs(psus_per_stratum = 2L)
  expect_no_warning(result <- create_brr_weights(dp$none))
  test_invariants(result)
  expect_no_warning(create_brr_weights(dp$none, rho = 0.3))
  expect_no_warning(
    create_bootstrap_weights(d$none, type = "Rao-Wu", replicates = 20L)
  )
  expect_no_warning(
    create_bootstrap_weights(d$none, type = "Antal-Tille", replicates = 20L)
  )
  # survey:::mrbweights() warns "Design is sampled with replacement: only
  # first stage used" here, untyped. .collect_backend_messages() muffles it
  # with no replacement (issue #136).
  expect_no_warning(
    create_bootstrap_weights(d$none, type = "Preston", replicates = 20L)
  )
})

# ============================================================================
# 4. surveywts_warning_fpc_not_applied
# ============================================================================

test_that("create_brr_weights() replaces survey's untyped FPC warning with a typed one", {
  d <- make_fpc_designs(psus_per_stratum = 2L)
  # expect_warning() takes only the typed warning; any other warning, such as
  # survey's untyped "Finite population correction dropped in conversion",
  # reaches expect_no_warning() and fails it.
  expect_no_warning(
    expect_warning(
      result <- create_brr_weights(d$fpc),
      class = "surveywts_warning_fpc_not_applied"
    )
  )
  test_invariants(result)
  expect_snapshot(result <- create_brr_weights(d$fpc))
})

test_that("create_brr_weights(rho > 0) replaces survey's untyped FPC warning with a typed one", {
  d <- make_fpc_designs(psus_per_stratum = 2L)
  expect_no_warning(
    expect_warning(
      result <- create_brr_weights(d$fpc, rho = 0.3),
      class = "surveywts_warning_fpc_not_applied"
    )
  )
  test_invariants(result)
  expect_snapshot(result <- create_brr_weights(d$fpc, rho = 0.3))
})

test_that("create_bootstrap_weights(type = 'Rao-Wu') warns that the FPC is not applied", {
  d <- make_fpc_designs()
  expect_no_warning(
    expect_warning(
      result <- create_bootstrap_weights(
        d$fpc,
        type = "Rao-Wu",
        replicates = 20L
      ),
      class = "surveywts_warning_fpc_not_applied"
    )
  )
  test_invariants(result)
  expect_snapshot(
    result <- create_bootstrap_weights(d$fpc, type = "Rao-Wu", replicates = 20L)
  )
})

test_that("create_bootstrap_weights(type = 'Antal-Tille') warns that the FPC is not applied", {
  d <- make_fpc_designs()
  expect_no_warning(
    expect_warning(
      result <- create_bootstrap_weights(
        d$fpc,
        type = "Antal-Tille",
        replicates = 20L
      ),
      class = "surveywts_warning_fpc_not_applied"
    )
  )
  test_invariants(result)
  expect_snapshot(
    result <- create_bootstrap_weights(
      d$fpc,
      type = "Antal-Tille",
      replicates = 20L
    )
  )
})

test_that("create_jackknife_weights(type = 'grouped') replaces svrep's untyped FPC warning with a typed one", {
  d <- make_fpc_designs()
  expect_no_warning(
    expect_warning(
      result <- create_jackknife_weights(
        d$fpc,
        type = "grouped",
        replicates = 4L,
        seed = 1L
      ),
      class = "surveywts_warning_fpc_not_applied"
    )
  )
  test_invariants(result)
  expect_snapshot(
    result <- create_jackknife_weights(
      d$fpc,
      type = "grouped",
      replicates = 4L,
      seed = 1L
    )
  )
})

test_that("methods that apply the FPC raise no warning", {
  d <- make_fpc_designs()
  expect_no_warning(result <- create_jackknife_weights(d$fpc, type = "jkn"))
  test_invariants(result)
  expect_no_warning(
    create_bootstrap_weights(d$fpc, replicates = 20L, seed = 1L)
  )
  expect_no_warning(
    create_bootstrap_weights(d$fpc, type = "Canty-Davison", replicates = 20L)
  )
  expect_no_warning(
    suppressMessages(create_sdr_weights(d$fpc, replicates = 20L))
  )
})

# ============================================================================
# 5. as_svydesign()
# ============================================================================

test_that("as_svydesign() raises no FPC warning on a design built from an FPC source", {
  skip_if_not_installed("survey")
  d <- make_fpc_designs()
  dp <- make_fpc_designs(psus_per_stratum = 2L)
  # surveycore 1.2.0 warns only when fpc is set and fpc_applied is NULL. For
  # "none" it raises nothing either: nothing was applied, so nothing drops.
  designs <- suppressWarnings(suppressMessages(list(
    jkn = create_jackknife_weights(d$fpc, type = "jkn"),
    grouped = create_jackknife_weights(
      d$fpc,
      type = "grouped",
      replicates = 4L,
      seed = 1L
    ),
    rwyb = create_bootstrap_weights(d$fpc, replicates = 20L, seed = 1L),
    rao_wu = create_bootstrap_weights(
      d$fpc,
      type = "Rao-Wu",
      replicates = 20L,
      seed = 1L
    ),
    preston = create_bootstrap_weights(
      d$fpc,
      type = "Preston",
      replicates = 20L,
      seed = 1L
    ),
    antal_tille = create_bootstrap_weights(
      d$fpc,
      type = "Antal-Tille",
      replicates = 20L
    ),
    canty_davison = create_bootstrap_weights(
      d$fpc,
      type = "Canty-Davison",
      replicates = 20L
    ),
    gen_boot = create_gen_boot_weights(d$fpc, replicates = 20L, seed = 1L),
    gen_rep = create_gen_rep_weights(d$fpc, seed = 1L),
    sdr = create_sdr_weights(d$fpc, replicates = 20L),
    brr = create_brr_weights(dp$fpc),
    fay = create_brr_weights(dp$fpc, rho = 0.3)
  )))
  for (nm in names(designs)) {
    test_invariants(designs[[nm]])
    expect_no_warning(surveycore::as_svydesign(designs[[nm]]))
  }
})
