# Simulation: replicate rules for calibrate_logit(bounds_scale = "absolute").
# Rule 0: develop today (per-unit g-bounds abs / rep_wt, pole for rep_wt >= abs_U).
# Rule 1: PR #145 (hold rep_wt >= abs_U at abs_U, rep_wt <= abs_L at abs_L).
# Rule 2: bound each draw (per-unit g-bounds abs / d_k from the full sample).
# Baseline: unbounded linear (GREG) calibration of the same sample.
args <- commandArgs(trailingOnly = TRUE)
nsim <- if (length(args) >= 1) as.integer(args[[1]]) else 20L
ncores <- if (length(args) >= 2) as.integer(args[[2]]) else 12L
out_file <- if (length(args) >= 3) args[[3]] else "sim_results.rds"
pkg_dir <- normalizePath(".")

worker_init <- function(pkg_dir) {
  suppressMessages(devtools::load_all(pkg_dir, quiet = TRUE))
  # Same engine, but errors use stop() instead of cli_abort(): cli message
  # formatting was 80% of run time when replicates fail.
  src <- deparse(get(".calibrate_nr_engine", envir = asNamespace("surveywts")))
  src <- gsub("cli::cli_abort(", "fast_abort(", src, fixed = TRUE)
  fe <- eval(parse(text = src))
  environment(fe) <- asNamespace("surveywts")
  assign("fast_engine", fe, envir = globalenv())
  assign("fast_abort", function(...) stop("calibration failed", call. = FALSE),
         envir = globalenv())
  NULL
}

make_pop <- function(seed = 2026L, H = 10L, M = 30L) {
  set.seed(seed)
  B <- sample(40:200, H * M, replace = TRUE)
  psu <- rep(seq_len(H * M), B)
  stratum <- rep(rep(seq_len(H), each = M), B)
  # PSU-level shift in the x mix and a PSU random effect on y
  psu_tilt <- rnorm(H * M, 0, 0.5)[psu]
  eta2 <- -0.2 + psu_tilt
  eta3 <- -0.5 + psu_tilt
  p1 <- 1 / (1 + exp(eta2) + exp(eta3))
  p2 <- exp(eta2) * p1
  u <- runif(length(psu))
  x <- ifelse(u < p1, 1L, ifelse(u < p1 + p2, 2L, 3L))
  y <- c(0, 1.5, 3)[x] + rnorm(H * M, 0, 0.7)[psu] + rnorm(length(psu))
  data.frame(stratum, psu, B = B[psu], x = factor(x, 1:3), y)
}

draw_sample <- function(pop, nh, b, M, resp = c(0.85, 0.7, 0.5)) {
  idx <- unlist(lapply(split(seq_len(nrow(pop)), pop$stratum), function(rows) {
    psus <- unique(pop$psu[rows])
    chosen <- psus[sample.int(length(psus), nh)]
    unlist(lapply(chosen, function(p) {
      r <- rows[pop$psu[rows] == p]
      r[sample.int(length(r), b)]
    }))
  }))
  s <- pop[idx, ]
  s$d <- (M / nh) * (s$B / b)
  s[runif(nrow(s)) < resp[as.integer(s$x)], ]
}

cal_logit <- function(X, w, pop_vec, L, U) {
  calfun <- .make_calfun_logit(L = L, U = U)
  fast_engine(X, w, calfun, pop_vec, epsilon = 1e-7, maxit = 50L,
                       q_weights = rep(1, length(w)))$weights
}

cal_linear <- function(X, w, pop_vec) {
  lam <- solve(crossprod(X * w, X), pop_vec - colSums(X * w))
  w * (1 + drop(X %*% lam))
}

# One replicate under one rule. Returns calibrated rep weights, or NULL on
# failure (caller keeps the uncalibrated weights, like the package does).
rep_calibrate <- function(rule, X, rep_wt, d, rep_pop, abs_L, abs_U) {
  in_rep <- rep_wt != 0
  out <- numeric(length(rep_wt))
  res <- tryCatch({
    if (rule == 0L) {
      out[in_rep] <- cal_logit(X[in_rep, , drop = FALSE], rep_wt[in_rep],
                               rep_pop, abs_L / rep_wt[in_rep],
                               abs_U / rep_wt[in_rep])
    } else if (rule == 1L) {
      hi <- in_rep & rep_wt >= abs_U
      lo <- in_rep & rep_wt <= abs_L
      free <- in_rep & !hi & !lo
      out[hi] <- abs_U
      out[lo] <- abs_L
      held <- hi | lo
      free_pop <- rep_pop - colSums(X[held, , drop = FALSE] * out[held])
      out[free] <- cal_logit(X[free, , drop = FALSE], rep_wt[free], free_pop,
                             abs_L / rep_wt[free], abs_U / rep_wt[free])
    } else if (rule == 2L) {
      out[in_rep] <- cal_logit(X[in_rep, , drop = FALSE], rep_wt[in_rep],
                               rep_pop, abs_L / d[in_rep], abs_U / d[in_rep])
    } else {
      out <- cal_linear(X, rep_wt, rep_pop)
    }
    out
  }, error = function(e) NULL)
  res
}

hajek <- function(w, y) sum(w * y) / sum(w)

one_sim <- function(sim, sc, pop, pop_vec) {
  set.seed(1e5 * sc$id + sim)
  s <- draw_sample(pop, sc$nh, sc$b, sc$M)
  X <- stats::model.matrix(~x, s)
  d <- s$d
  abs_L <- sc$abs_L
  abs_U <- sc$abs_U
  w <- tryCatch(cal_logit(X, d, pop_vec, abs_L / d, abs_U / d),
                error = function(e) NULL)
  if (is.null(w)) return(data.frame(sim = sim, ok = FALSE))
  w_lin <- cal_linear(X, d, pop_vec)
  th <- hajek(w, s$y)
  th_lin <- hajek(w_lin, s$y)
  des <- surveycore::as_survey(s, ids = psu, strata = stratum, weights = d)
  makers <- list(
    boot = function() create_bootstrap_weights(des, replicates = sc$R_boot,
                                               seed = sim),
    jkn = function() create_jackknife_weights(des),
    brr = function() create_brr_weights(des)
  )[sc$methods]
  rows <- list()
  for (m in names(makers)) {
    rd <- suppressWarnings(makers[[m]]())
    A <- as.matrix(rd@data[, rd@variables$repweights])
    scl <- rd@variables$scale
    rsc <- rd@variables$rscales
    for (rule in 0:3) {
      est_full <- if (rule == 3L) th_lin else th
      reps <- numeric(ncol(A))
      nfail <- 0L
      nheld <- 0L
      ok_r <- rep(TRUE, ncol(A))
      for (r in seq_len(ncol(A))) {
        rep_wt <- A[, r]
        rep_pop <- pop_vec * (sum(rep_wt) / sum(d))
        wr <- rep_calibrate(rule, X, rep_wt, d, rep_pop, abs_L, abs_U)
        if (is.null(wr)) {
          nfail <- nfail + 1L
          ok_r[r] <- FALSE
          wr <- rep_wt
        }
        nheld <- nheld + sum(rep_wt != 0 & (rep_wt >= abs_U | rep_wt <= abs_L))
        reps[r] <- hajek(wr, s$y)
      }
      se <- sqrt(scl * sum(rsc * (reps - est_full)^2))
      # Bootstrap only: SE from the replicates that calibrated, rescaled to R.
      se_drop <- if (any(ok_r)) {
        sqrt(scl * ncol(A) / sum(ok_r) *
               sum(rsc[ok_r] * (reps[ok_r] - est_full)^2))
      } else NA_real_
      rows[[length(rows) + 1L]] <- data.frame(
        method = m, rule = rule, est = est_full, se = se, se_drop = se_drop,
        nfail = nfail, R = ncol(A), held_per_rep = nheld / ncol(A)
      )
    }
  }
  out <- do.call(rbind, rows)
  out$sim <- sim
  out$ok <- TRUE
  out$n <- nrow(s)
  # Share of units whose full-sample weight is within 10% of abs_U, and the
  # gap between the bounded and the unbounded (linear) estimate.
  out$frac_near_bound <- mean(w > 0.9 * abs_U)
  out$bound_shift <- th - th_lin
  out
}

pop <- make_pop()
N <- nrow(pop)
pop_vec <- c(N, sum(pop$x == "2"), sum(pop$x == "3"))
theta <- mean(pop$y)
M <- 30L
B_rng <- c(40, 200)
R_boot <- if (length(args) >= 4) as.integer(args[[4]]) else 100L
mk_sc <- function(id, nh, b, methods, k) {
  dmin <- (M / nh) * (B_rng[1] / b)
  dmax <- (M / nh) * (B_rng[2] / b)
  list(id = id, nh = nh, b = b, M = M, methods = methods, R_boot = R_boot,
       k = k, abs_L = 0.8 * dmin, abs_U = k * dmax)
}
scenarios <- list()
for (k in c(1.5, 2.5, 4)) {
  scenarios[[paste0("A_k", k)]] <- mk_sc(length(scenarios) + 1L, nh = 2L,
    b = 20L, methods = c("boot", "brr", "jkn"), k = k)
  scenarios[[paste0("B_k", k)]] <- mk_sc(length(scenarios) + 1L, nh = 4L,
    b = 10L, methods = c("boot", "jkn"), k = k)
}

only <- Sys.getenv("SIM_ONLY")
if (nzchar(only)) {
  scenarios <- scenarios[strsplit(only, ",")[[1]]]
  for (nm in names(scenarios)) scenarios[[nm]]$methods <- "boot"
}

cl <- parallel::makeCluster(ncores)
invisible(parallel::clusterCall(cl, worker_init, pkg_dir))
parallel::clusterExport(cl, c("draw_sample", "cal_logit", "cal_linear",
                              "rep_calibrate", "hajek", "one_sim"))
res <- list()
for (nm in names(scenarios)) {
  sc <- scenarios[[nm]]
  t0 <- Sys.time()
  out <- parallel::parLapplyLB(cl, seq_len(nsim), function(i, sc, pop, pop_vec) {
    environment(one_sim) <- globalenv()
    one_sim(i, sc, pop, pop_vec)
  }, sc = sc, pop = pop, pop_vec = pop_vec)
  out <- do.call(rbind, lapply(out, function(z) {
    if (!isTRUE(z$ok[1])) return(NULL)
    z
  }))
  out$scenario <- nm
  res[[nm]] <- out
  message(nm, ": ", length(unique(out$sim)), "/", nsim, " samples ok, ",
          format(Sys.time() - t0))
}
parallel::stopCluster(cl)
saveRDS(list(res = res, theta = theta, scenarios = scenarios, N = N), out_file)

summ <- do.call(rbind, lapply(res, function(o) {
  do.call(rbind, lapply(split(o, list(o$method, o$rule), drop = TRUE), function(g) {
    sd_mc <- sd(g$est)
    data.frame(
      scenario = g$scenario[1], method = g$method[1], rule = g$rule[1],
      nsim = nrow(g), rel_bias = mean(g$est - theta) / theta,
      mc_sd = sd_mc, mean_se = mean(g$se),
      se_ratio = mean(g$se) / sd_mc,
      var_ratio = mean(g$se^2) / sd_mc^2,
      coverage = mean(abs(g$est - theta) <= 1.96 * g$se),
      se_ratio_drop = mean(g$se_drop, na.rm = TRUE) / sd_mc,
      cov_drop = mean(abs(g$est - theta) <= 1.96 * g$se_drop, na.rm = TRUE),
      fail_rate = sum(g$nfail) / sum(g$R),
      held_per_rep = mean(g$held_per_rep),
      near_bound = mean(g$frac_near_bound)
    )
  }))
}))
summ <- summ[order(summ$scenario, summ$method, summ$rule), ]
print(format(summ, digits = 3), row.names = FALSE)
