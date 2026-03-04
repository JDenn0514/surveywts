# R/vendor-calibrate-greg.R
#
# VENDORED CODE — do not edit the algorithm without updating VENDORED.md
#
# Source package : survey
# Source version : 4.4-8
# Author         : Thomas Lumley, Peter Gao
# License        : GPL-2+ (compatible with this package's GPL-3)
# Source function: survey:::grake() (logit engine)
#                  survey:::regcalibrate.survey.design2() (linear engine)
# CRAN URL       : https://cran.r-project.org/package=survey
#
# Adaptations from source:
#   - Removed svydesign object dependency; functions accept plain numeric
#     vectors and matrices only.
#   - Replaced MASS::ginv() with .gram_solve() (SVD-based pseudoinverse,
#     mathematically equivalent; avoids the MASS dependency).
#   - Linear and logit calibration split into two separate functions
#     (.greg_linear and .greg_logit) for clarity.
#   - Removed survey-internal class checks and formula machinery.
#   - Return value is a g-weight vector (multipliers); caller computes
#     new_weights = starting_weights * g_weights.
#
# Algorithm is mathematically identical to the source. Numerical output
# is verified to match survey::calibrate() within 1e-8 in the package's
# correctness tests (test-02-calibrate.R, test-03-rake.R).
# ---------------------------------------------------------------------------


# .gram_solve -----------------------------------------------------------------
# SVD-based pseudoinverse solve: computes pinv(A) %*% b.
# Replaces MASS::ginv(A) %*% b. Mathematically identical for all matrices.
# Used internally by .greg_logit().

.gram_solve <- function(A, b) {
  sv <- svd(A)
  tol <- max(dim(A)) * max(sv$d) * .Machine$double.eps * 256
  inv_d <- ifelse(sv$d > tol, 1 / sv$d, 0)
  sv$v %*% (inv_d * (t(sv$u) %*% b))
}


# .greg_linear ----------------------------------------------------------------
# One-step exact GREG (linear) calibration.
# Based on: survey:::regcalibrate.survey.design2(), stage = 0 branch.
#
# Arguments:
#   mm         - numeric matrix (n x p): model matrix of auxiliary variables
#   ww         - numeric vector (n): starting survey weights (all > 0)
#   population - numeric vector (p): population totals for each column of mm
#   sigma2     - numeric vector (n) or NULL: variance-model weights.
#                NULL → uniform (sigma2 = 1 for all observations).
#
# Returns: numeric vector of g-weights (length n); new_weights = ww * g.
# Errors with a condition of class "surveyweights_error_calibration_singular"
# if the calibration matrix is computationally singular.

.greg_linear <- function(mm, ww, population, sigma2 = NULL) {
  if (is.null(sigma2)) sigma2 <- rep(1, nrow(mm))

  whalf <- sqrt(ww)
  sample_total <- colSums(mm * ww)

  # Build and solve the normal equations: (X'WX) tT = (T - X'w)
  Tmat <- crossprod(mm * whalf / sqrt(sigma2))
  # Use SVD-based pseudoinverse (matches survey:::regcalibrate's use of
  # qr.coef / MASS::ginv for rank-deficient model matrices). The full
  # indicator matrix (all levels of each categorical variable) has rank
  # p - (number_of_variables - 1) due to the all-ones dependence among
  # within-variable level columns; .gram_solve() handles this transparently.
  tT <- drop(.gram_solve(Tmat, population - sample_total))

  g <- drop(1 + mm %*% tT / sigma2)
  g
}


# .greg_logit -----------------------------------------------------------------
# Iterative logit calibration via IRLS (iteratively reweighted least squares).
# Based on: survey:::grake(), logit calfun branch.
#
# Arguments:
#   mm         - numeric matrix (n x p): model matrix of auxiliary variables
#   ww         - numeric vector (n): starting survey weights (all > 0)
#   population - numeric vector (p): population totals for each column of mm
#   bounds     - list(lower, upper): logit bound multipliers (default: c(0, Inf))
#   sigma2     - numeric vector (n) or NULL: variance-model weights
#   epsilon    - double: convergence tolerance
#   maxit      - integer: maximum IRLS iterations
#   verbose    - logical: print misfit after each iteration
#
# Returns: numeric vector of g-weights (length n); new_weights = ww * g.
# On non-convergence: returns g with attribute "failed" = achieved epsilon.
#
# Logit calfun (matches survey:::cal.raking structure):
#   Fm1(u, bounds) = pmin(pmax(exp(u), bounds$lower), bounds$upper) - 1
#   dF(u, bounds)  = ifelse(u < log(bounds$upper) & u > log(bounds$lower),
#                           exp(u), 0)

.greg_logit <- function(
  mm,
  ww,
  population,
  bounds = list(lower = 0, upper = Inf),
  sigma2 = NULL,
  epsilon = 1e-7,
  maxit = 50L,
  verbose = FALSE
) {
  if (is.null(sigma2)) sigma2 <- rep(1, nrow(mm))

  Fm1 <- function(u, b) pmin(pmax(exp(u), b$lower), b$upper) - 1
  dF <- function(u, b) {
    ifelse(
      exp(u) < b$upper & exp(u) > b$lower,
      exp(u),
      0
    )
  }

  eta <- rep(0, ncol(mm))
  sample_total <- colSums(mm * ww)

  SOMETHRESHOLD <- 20
  scales <- population / sample_total
  scale <- NULL
  if (min(scales) > SOMETHRESHOLD) {
    scale <- mean(scales)
    ww <- ww * scale
    sample_total <- sample_total * scale
    if (verbose) {
      message(paste("Sampling weights rescaled by", signif(scale, 3)))
    }
  }

  xeta <- drop(mm %*% eta / sigma2)
  g <- 1 + Fm1(xeta, bounds)
  deriv <- dF(xeta, bounds)
  iter <- 1L

  repeat({
    Tmat <- crossprod(mm * ww / sqrt(sigma2) * deriv, mm / sqrt(sigma2))
    misfit <- population - sample_total - colSums(mm * ww * Fm1(xeta, bounds))
    deta <- .gram_solve(Tmat, misfit)
    eta <- eta + deta
    xeta <- drop(mm %*% eta / sigma2)
    g <- 1 + Fm1(xeta, bounds)
    deriv <- dF(xeta, bounds)

    # Step-halving if g or deriv goes non-finite
    while (iter < maxit && any(!is.finite(g), !is.finite(deriv))) {
      iter <- iter + 1L
      deta <- deta / 2
      eta <- eta - deta
      xeta <- drop(mm %*% eta / sigma2)
      g <- 1 + Fm1(xeta, bounds)
      deriv <- dF(xeta, bounds)
      if (verbose) message("Step halving")
    }

    misfit <- population - sample_total - colSums(mm * ww * Fm1(xeta, bounds))
    if (verbose) print(misfit)

    cur_max_error <- max(abs(misfit) / (1 + abs(population)))
    if (cur_max_error < epsilon) {
      attr(g, "iterations") <- iter
      attr(g, "max_error") <- cur_max_error
      break
    }

    iter <- iter + 1L
    if (iter > maxit) {
      attr(g, "failed") <- cur_max_error
      attr(g, "iterations") <- iter
      attr(g, "max_error") <- cur_max_error
      break
    }
  })

  if (!is.null(scale)) g <- g * scale
  attr(g, "eta") <- eta
  g
}
