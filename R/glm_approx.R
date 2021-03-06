# @description Compute approximately unbiased variance estimates for
#   the estimators for logit(p) when n is small.
# @param n number of trials
# @param s number of successes
# @param f number of failures
v3 = function (n, s, f)
  return((n + 1)/n * (1/(s + 1) + 1/(f + 1)))

# @description Compute approximately unbiased variance estimates for
#   the estimators for logit(p) when n is small.
# @param n number of trials
# @param s number of successes
# @param f number of failures
vs = function (n, s, f) {
  vv = v3(n, s, f)
  return(vv * (1 - 2/n + vv/2))
}

# @description Compute approximately unbiased variance estimates for
#   the estimators for logit(p) when n is small.
# @param n number of trials
# @param s number of successes
# @param f number of failures
vss = function (n, s, f) {
  vv = v3(n, s, f)
  return(vs(n, s, f) - 1/2 * vv^2 * (vv - 4/n))
}

# @description Modified glm function to return relevant outputs, not
#   allowing for underdispersion.
# @param x covariante
# @param y response
# @param forcebin See glm.approx.
# @param repara See glm.approx.
# @return A vector of intercept and slope estimates and their SEs.
#
#' @importFrom stats glm.fit
#' @importFrom stats binomial
#' @importFrom stats quasibinomial
safe.quasibinomial.glm.fit = function (x, y, forcebin = FALSE,
                                       repara = FALSE, ...) {
    if (forcebin) {
        z = glm.fit(x, y, family = binomial(), ...)
        p1 = 1L:z$rank
        covmat = chol2inv(z$qr[[1]][p1, p1, drop = FALSE])
        se = sqrt(diag(covmat))
        if (repara == TRUE) {
            if (length(covmat) <= 1) {
                covmubeta = NA
            } else {
                covmubeta = covmat[2, 1]
            }
            mbvar = covmubeta/se[2]^2
            z$coef[1] = z$coef[1] - z$coef[2] * mbvar
            se[1] = sqrt(se[1]^2 + mbvar^2 * se[2]^2 - 2 * mbvar * covmubeta)
        }
    } else {
        z = glm.fit(x, y, family = quasibinomial(), ...)
        p1 = 1L:z$rank
        covmat.i = chol2inv(z$qr[[1]][p1, p1, drop = FALSE])
        df = z$df.residual
        if (df == 0) {
            d = 1
        } else {
            d = sum((z$weights * z$residuals^2)[z$weights > 0])/df
            d = d * (d >= 1) + 1 * (d < 1)
        }
        covmat = covmat.i * d
        se = sqrt(diag(covmat))
        if (repara == TRUE) {
            if (length(covmat) <= 1) {
                covmubeta = NA
            } else {
                covmubeta = covmat[2, 1]
            }
            mbvar = covmubeta/se[2]^2
            z$coef[1] = z$coef[1] - z$coef[2] * mbvar
            se[1] = sqrt(se[1]^2 + mbvar^2 * se[2]^2 - 2 * mbvar * covmubeta)
        }
    }
    if (repara == FALSE) {
        return(c(z$coef[1], se[1], z$coef[2], se[2]))
    } else {
        return(c(z$coef[1], se[1], z$coef[2], se[2], mbvar))
    }
}

# @description Returns estimates of intercept and slope as well as
#   their SEs, given other input options. Called in glm.approx.
# @param x A 2n by 1 vector, with first n observations giving number
#   of successes, and next n giving number of failures in a series of
#   binomial experiments.
# @param g covariate. Can be null, in which case only the intercept
#   estimate and its SE is returned.
# @param minobs See glm.approx.
# @param pseudocounts See glm.approx.
# @param all See glm.approx.
# @param forcebin See glm.approx.
# @param repara See glm.approx.
# @return A vector of intercept and slope estimates and their SEs.
#
#' @importFrom stats sd
bintest = function (x, g, minobs = 1, pseudocounts = 0.5, all = FALSE,
                    forcebin = FALSE, repara = FALSE) {
    xmat = matrix(x, ncol = 2)
    zerosum = (apply(xmat, 1, sum) == 0)
    if (sum(!zerosum) > (minobs - 1)) {
        
        # check for enough observations
        ind1 = (xmat[, 1] == 0)
        ind2 = (xmat[, 2] == 0)
        if (all == TRUE) {
            xmat = xmat[!zerosum, , drop = F] + pseudocounts
        } else {
            xmat[ind1, 1] = xmat[ind1, 1] + pseudocounts
            xmat[ind1, 2] = xmat[ind1, 2] + pseudocounts
            xmat[ind2, 1] = xmat[ind2, 1] + pseudocounts
            xmat[ind2, 2] = xmat[ind2, 2] + pseudocounts
            xmat = xmat[!zerosum, , drop = F]
        }
        # Check if there is enough variance in g among informative
        # individuals.
        g = g[!zerosum]
        ng = sum(!zerosum)
        dm = matrix(c(rep(1, ng), g), ncol = 2)
        if (!is.na(sd(g)) & (sd(g) > 0.1)) {
            dm[, 2] = g
            return(safe.quasibinomial.glm.fit(dm, xmat, forcebin,
                                              repara = repara))
        } else {
            if (repara == FALSE) {
                return(c(safe.quasibinomial.glm.fit(dm, xmat, forcebin,
                                                    repara = repara)[1:2],
                         NA, NA))
            } else {
                return(c(safe.quasibinomial.glm.fit(dm, xmat, forcebin,
                                                    repara = repara)[1:2],
                         NA, NA, NA))
            }
        }
    } else {
        
        # Not enough observations, so just return NAs.
        if (repara == FALSE) {
            return(c(NA, NA, NA, NA))
        } else {
            return(c(NA, NA, NA, NA, NA))
        }
    }
}

# Returns a list with elements x.s and x.f.
extract.sf = function (x, n)
  list(x.s = as.vector(t(x[, (1:(2 * n))%%2 == 1])),
       x.f = as.vector(t(x[, (1:(2 * n))%%2 == 0])))

# Returns a list with elements x.s and x.f.
add.counts = function (x.s, x.f, eps, pseudocounts, all, index1, index2,
                       indexn = NULL) {
    if (pseudocounts == 0) {
        x.s[index1] = x.s[index1] + eps
        x.f[index2] = x.f[index2] + eps
    } else if (pseudocounts != 0 & all == TRUE) {
        x.s = x.s + pseudocounts
        x.f = x.f + pseudocounts
    } else {
        x.s[index1] = x.s[index1] + pseudocounts
        x.f[index1] = x.f[index1] + pseudocounts
        x.s[index2] = x.s[index2] + pseudocounts
        x.f[index2] = x.f[index2] + pseudocounts
    }
    if (!is.null(indexn)) {
        x.s[indexn] = 0
        x.f[indexn] = 0
    }
    return(list(x.s = x.s, x.f = x.f))
}

# Compute a vector of logit(p) given a vector of successes and
# failures, as well as its variance estimates (MLE with approximation
# at endpoints for mean; a mix of Berkso's estimator and Tukey's
# estimator for variance). Returns a list with elements "mu", "var"
# and, optionally, "p".
compute.approx.z = function (x.s, x.f, bound, eps, pseudocounts, all,
                             indexn = NULL, return.p = FALSE) {
    
    # Compute mu. First, find indices for which binomial success or
    # failures are too small.
    index1 = (x.s/x.f) <= bound  
    index2 = (x.f/x.s) <= bound
    index1[is.na(index1)] = FALSE
    index2[is.na(index2)] = FALSE  # This is the same as above!!!

    # Add pseudocounts.
    x = add.counts(x.s, x.f, eps, pseudocounts, all, index1, index2, indexn)  
    s = x$x.s + x$x.f

    # Compute logit(p) to be used as observations.
    mu = log(x$x.s/x$x.f)  
    mu[index1] = mu[index1] - 0.5 # End-point correction.
    mu[index2] = mu[index2] + 0.5
    
    # Compute var compute var(logit(p)).
    if (all == FALSE) {
        var = vss(s, x$x.s, x$x.f)
        var[index1] = vss(s[index1] - 2 * pseudocounts, x$x.s[index1] -
               pseudocounts, x$x.f[index1] - pseudocounts)
        var[index2] = vss(s[index2] - 2 * pseudocounts, x$x.s[index2] -
               pseudocounts, x$x.f[index2] - pseudocounts)
    } else {
        var = vss(s - 2 * pseudocounts, x$x.s - pseudocounts,
                  x$x.f - pseudocounts)
    }
    var[var == Inf] = 1e+20
    if (return.p == TRUE) 
      return(list(mu = mu, var = var, p = x$x.s/s))
    else
      return(list(mu = mu, var = var))
}

# Compute estimates and standard errors for mu and beta when fitting
# WLS, as well as the covariance between mu and beta. Return a list
# elements "coef", "se" and "mbvar".
wls.coef = function (z, disp, indexnm, n, ng, forcebin, g = NULL,
                     repara = NULL) {
    
    # Compute vector of dfs for all n linear models (disregarding obs
    # with missing data).
    if (is.null(g)) 
      df = pmax(colSums(!indexnm) - 1, 0)
    else
      df = pmax(colSums(!indexnm) - 2, 0)

    # Create ng*n matrix of logit(p).
    zm = matrix(z$mu, ncol = n, byrow = T)
    zm[indexnm] = 0

    # Create ng*n matrix of var(logit(p)).
    vm = matrix(z$var, ncol = n, byrow = T)
    res = wls.mb(zm, vm, disp, indexnm, ng, df, forcebin, g, n)
    if (disp == "add") {

        # Return estimates if multiplicative dispersion is assumed.
        vm[indexnm] = NA

        # Computes crude estimate of sigma_u^2 as in documentation.
        vv = pmax((res$wrse2 - 1) * colMeans(vm, na.rm = T), 0)
        res = wls.mb(zm, vm, disp, indexnm, ng, df, forcebin, g, n, vv)
    }
    if (is.null(g)) 
        return(list(coef = res$coef, se = res$se, mbvar = NULL)) else {
        coef = c(res$muhat, res$betahat)
        se = c(res$semuhat, res$sebetahat)
        if (repara == TRUE) {
            
            # Return reparametrized muhat and behat as well as their
            # SEs, together with gamma as defined in documentation.
            mbvar = res$covmubeta/res$sebetahat^2
            coef[1:n] = res$muhat - res$betahat * mbvar
            se[1:n] = sqrt(res$semuhat^2 + mbvar^2 * res$sebetahat^2 -
                      2 * mbvar * res$covmubeta)
        } else {
            if (repara == FALSE) 
                mbvar = NULL else stop("Error: invalid argument 'repara'")
        }
        return(list(coef = coef, se = se, mbvar = mbvar))
    }
}

#' Returns a list with elements "coef", "se", "wrse2" if g is not
#' specified, or a list with elements "muhat", "semuhat", "betahat",
#' "sebetahat", "covmubeta", "wrse2" otherwise.
wls.mb = function (z, v, disp, indexnm, ng, df, forcebin, g = NULL,
                   n = NULL, vv = NULL) {
    if (is.null(vv)) {
        
        # Compute weights for each of the n models.
        w = 1/v
    } else {
        w = 1/(v + rep(1, ng) %o% vv)
    }
    w[indexnm] = 0

    # Define sum of weights for each of the n models (to be used later).
    ws = colSums(w)  
    if (is.null(g)) {

        # Compute muhat for each of the n models using formula in
        # documentation.
        muhat = colSums(w * z)/ws

        # Compute residual standard error.
        wrse = sqrt(colSums((z - rep(1, ng) %o% muhat)^2 * w)/df)  
    } else {

        # Define weighted center of g for each of the n models (to be
        # used later).
        gwmean = colSums(w * g)/ws

        # Define weighted difference between each g and its weighted
        # center for each of the n models (to be used later).
        ggwmeanm = g %o% rep(1, n) - rep(1, ng) %o% gwmean

        # Compute sum_j w_j^2*(g_j-gwmean)^2 (to be used later).
        wgg = colSums(w * ggwmeanm^2)  
        wgg.ind = wgg < 1e-06
        wgg[wgg.ind] = 0

        # Compute betahat using formula in documentation.
        betahat = colSums(w * z * ggwmeanm)/colSums(w * ggwmeanm^2)  
        g.betahat = g %o% betahat
        
        # Compute betahat*g and residual standard errorfor each of the
        # n models.
        muhat = colSums(w * (z - g.betahat))/ws  
        wrse = sqrt(colSums((z - rep(1, ng) %o% muhat - g.betahat)^2 * w)/df)
    }
    wrse[is.na(wrse)] = 1
    if (forcebin | (is.null(g) & (ng == 2)) |
        (!is.null(g) & (ng == length(unique(g))))) {
        
        # Force dispersion to be absent (also in the case with only 1
        # observation in each group).
        wrse = 1
    } else {
        if (is.null(vv)) {

            # Do not allow for "underdispersion".
            wrse[(wrse == Inf) | (wrse < 1)] = 1  
        } else {
            wrse[(wrse == Inf) | (vv == 0)] = 1
        }
    }
    wrse2 = wrse^2
    if (is.null(g)) {
        semuhat = sqrt(wrse2/ws)
        return(list(coef = muhat, se = semuhat, wrse2 = wrse2))
    } else {

        # Compute se(betahat) using formula in documentation.
        sebetahat = sqrt(wrse2/wgg)  
        sebetahat[wgg.ind] = NA

        # Compute se(muhat) using formula in documentation.
        semuhat = sqrt((1/ws + gwmean^2/wgg) * wrse2) 
        semuhat[wgg.ind] = NA

        #compute covariance between muhat and betahat.
        covmubeta = colSums(w * ggwmeanm)/ws/wgg * wrse2 -
            gwmean * sebetahat^2  
        return(list(muhat = muhat, semuhat = semuhat,
                    betahat = betahat, sebetahat = sebetahat,
                    covmubeta = covmubeta, 
                    wrse2 = wrse2))
    }
}

# Computes the dispersion parameter when fitting glm. Returns a vector
# of dispersion parameters for each fitted model, or 1 if dispersion
# is absent.
compute.dispersion = function (p, n, ng, indexnm, forcebin, ind = NULL,
                               ord = NULL, lg = NULL, x = NULL, x.s = NULL, 
                               x.f = NULL) {
    if (is.null(lg)) {
        if (forcebin | ng == 1) {
            # force dispersion to be absent
            return(1)
        }
    } else {
        if (forcebin | (ng == lg)) {
            
            # (or if there is 1 obs in each group)
            return(1)
        }
    }
    
    # Find effective number of observations after getting rid of
    # missing data.
    ngn = !indexnm
    ngn = colSums(ngn)
    ngn = rep(ngn, times = ng)
    
    if (is.null(lg)) {
        ss = x.s + x.f
        p = rep(p, times = ng)

        # Compute dispersion factor as in McC and Nelder.
        d.ini = 1/(ngn - 1) * (x.s - p * ss)^2/(ss * p * (1 - p))  
        d.ini[d.ini == Inf] = 0
        d.ini[is.na(d.ini)] = 0
        d.m = matrix(d.ini, ncol = ng)
        d = rowSums(d.m)

        # Do not allow underdispersion.
        d[d < 1] = 1  
    } else {
        x = x[ord, ]
        x.sf = extract.sf(x, n)
        s = x.sf$x.s + x.sf$x.f
        pn = NULL
        for (i in 1:lg) {
            pn = c(pn, rep(p[(n * (i - 1) + 1):(n * i)],
                   times = sum(ind[[i]])))
        }

        # Compute dispersion factor as in McC and Nelder.
        d.ini = 1/(ngn - lg) * (x.sf$x.s - pn * s)^2/(s * pn * (1 - pn))  
        d.ini[d.ini == Inf] = 0
        d.ini[is.na(d.ini)] = 0
        d.m = matrix(d.ini, ncol = ng)
        d = rowSums(d.m)

        # Do not allow underdispersion.
        d[d < 1] = 1  
        d = rep(d, times = lg)
    }
    return(d)
}

# Compute estimates and standard errors for mu and beta when fitting
# WLS, as well as the covariance between mu and beta. Returns a list
# elements "coef", "se" and optionally "mbvar" if lg=2 and
# repara=TRUE, or "covv" if lg=3.
glm.coef = function(z, g, n, center, repara) {
    lg = length(levels(g))
    mbvar = NULL
    if (lg == 2) {
        
        # Two categories.
        covv = NULL
        if (center == TRUE) {
            
            # Considered centered and uncentered covariate separately.
            g.num = sort(as.numeric(levels(g))[g])
            g.num = unique(g.num - mean(g.num))
            w1 = g.num[1]  # Weights come in because covariate is centered.
            w2 = g.num[2]

            # Compute logit(p) for each group.
            coef = w2 * z$mu[1:n] - w1 * z$mu[(n + 1):(2 * n)]

            # Compute intercept and slope.
            coef = c(coef, z$mu[(n + 1):(2 * n)] - z$mu[1:n])

            # Compute var(logit(p)) for each group.
            var = w2^2 * z$var[1:n] + w1^2 * z$var[(n + 1):(2 * n)]

            # Compute var for intercept and slope.
            var = c(var, z$var[(n + 1):(2 * n)] + z$var[1:n])  
        } else {

            # Compute intercept and slope.
            coef = z$mu - c(rep(0, n), rep(z$mu[1:n], times = (lg - 1)))

            # Compute var of intercept and slope.
            var = z$var + c(rep(0, n), rep(z$var[1:n], times = (lg - 1)))  
        }
        if (repara == TRUE) {
          if (center == TRUE) {

            # Compute gamma as in documentation if reparametrization
            # is used.
            mbvar = -(w2 * z$var[1:n] + w1 * z$var[(n + 1):(2 * n)])/
                var[(n + 1):(2 * n)]

            # Reparametrized estimates.
            coef[1:n] = coef[1:n] - coef[(n + 1):(2 * n)] * mbvar

            # Reparametrized Ses.
            var[1:n] = var[1:n] -
                (w2 * z$var[1:n] + w1 * z$var[(n + 1):(2 * n)])^2/
                  var[(n + 1):(2 * n)]  
          } else {
            mbvar = -var[1:n]/var[(n + 1):(2 * n)]

            # Reparametrized estimates.
            coef[1:n] = coef[1:n] - coef[(n + 1):(2 * n)] * mbvar  
            
            # Reparametrized Ses.
            var[1:n] = var[1:n] - var[1:n]^2/var[(n + 1):(2 * n)]  
          }
        } 
    } else if (lg == 3) {
        
        # Three groups case as in PoissonBinomial_etc considered
        # centered and uncentered covariate separately.
        if (center == TRUE) {
            g.num = sort(as.numeric(levels(g))[g])
            g.num[g.num != 1] = 0
            g.num[g.num == 1] = 1
            g.num = unique(g.num - mean(g.num))
            w1.1 = g.num[1]
            w1.2 = g.num[2]
            g.num = sort(as.numeric(levels(g))[g])
            g.num[g.num != 2] = 0
            g.num[g.num == 2] = 1
            g.num = unique(g.num - mean(g.num))
            w2.1 = g.num[1]
            w2.2 = g.num[2]
            coef = (w1.2 + w2.1) * z$mu[1:n] - w1.1 * z$mu[(n + 1):(2 * n)] -
                   w2.1 * z$mu[(2 * n + 1):(3 * n)]
            coef = c(coef, z$mu[(n + 1):(3 * n)] - rep(z$mu[1:n],
                                                       times = (lg - 1)))
            var = (w1.2 + w2.1)^2 * z$var[1:n] +
                  (w1.1)^2 * z$var[(n + 1):(2 * n)] +
                    (w2.1)^2 * z$var[(2 * n + 1):(3 * n)]
            var = c(var, z$var[(n + 1):(3 * n)] + rep(z$var[1:n],
                                                       times = (lg - 1)))
            covv = z$var[1:n]
        } else {
            
            # Three groups case.
            coef = z$mu - c(rep(0, n), z$mu[1:(2 * n)])
            var = z$var + c(rep(0, n), z$var[1:(2 * n)])
            covv = -z$var[(n + 1):(2 * n)]
        }
    }
    return(list(mu = coef, var = var, mbvar = mbvar, covv = covv))
}

# Returns a matrix with estimates for mu and beta, as well as their
# SEs. Optionally returns "mbvar" if specified.
compute.lm = function(g, coef, se, mbvar, n, index, repara) {
    if (is.null(g)) {
        na.ind = is.na(coef[1:n]) | is.na(se[1:n])

        # Set muhat and se(muhat) to NA for those models with
        # insufficiant data or NAs.
        coef[na.ind | index] = NA  
        se[na.ind | index] = NA
        return(matrix(c(coef, se), nrow = 2, byrow = T))
    } else {
        index = rep(index, times = 2)
        na.ind = is.na(coef[1:n]) | is.na(se[1:n]) | is.na(coef[(n + 1):(2 * n)]) | is.na(se[(n + 1):(2 * n)])
        na.ind2 = rep(na.ind, times = 2)

        # Set muhat and se(muhat) to NA for those models with
        # insufficiant data or NAs.
        coef[na.ind2 | index] = NA  
        se[na.ind2 | index] = NA
        toreturn = array(rbind(coef, se), dim = c(2, n, 2))
        if (repara == TRUE) {
            mbvar[index[1:n]] = NA
            mbvar[na.ind] = NA
            return(matrix(rbind(apply(toreturn, 2, rbind), mbvar), ncol = n))
        }
        else

          # Should this be return(apply(toreturn,2,rbind))?
          return(matrix(rbind(apply(toreturn, 2, rbind), mbvar), ncol = n))  
    }
}

# Returns a matrix with estimates for mu and beta, as well as their
# SEs. Optionally returns "mbvar" if specified.
compute.glm = function(x, g, d, n, na.index, repara) {

    # Dispersion.
    se = sqrt(x$var * d)  
    mu = x$mu

    # Set muhat and se(muhat) to NA for those models with insufficiant
    # data.
    mu[na.index] = NA  
    se[na.index] = NA
    
    if (is.null(g)) 
        return(matrix(c(mu, se), nrow = 2, byrow = T)) else {
        if (is.factor(g)) {
            lg = length(levels(g))
            toreturn = array(rbind(mu, se), dim = c(2, n, lg))
            if (lg == 3) {
                if (length(d) == 1)
                  covv = x$covv * d  
                else
                  covv = x$covv * d[1:n]  

                # Check that this is correct (?).
                covv[na.index[1:n]] = NA  
                return(matrix(rbind(apply(toreturn,2,rbind),covv),ncol = n))
            } else if (lg == 2) {
                if (repara == FALSE) 
                  return(apply(toreturn, 2, rbind)) else {
                  mbvar = x$mbvar
                  mbvar[na.index[1:n]] = NA
                  return(matrix(rbind(apply(toreturn, 2, rbind), mbvar),
                                ncol = n))
                }
            }
        }
    }
}

#' @title Model fitting using weighted least squares or a GLM approach.
#' 
#' @description Fit the model specified in documentation, using either
#'   a weighted least squares approach or a generalized linear model
#'   approach, with some modifications. This function fits many "simple"
#'   logistic regressions (ie zero or one covariate) simultaneously,
#'   allowing for the possibility of small sample sizes with low or zero
#'   counts. In addition, an alternative model in the form of a weighted
#'   least squares regression can also be fit in place of a logistic
#'   regression.
#' 
#' @param x A matrix of N (# of samples) by 2*B (B: # of WCs or, more
#'   precisely, of different scales and locations in multi-scale space);
#'   Two consecutive columns correspond to a particular scale and
#'   location; The first column (the second column) contains # of
#'   successes (# of failures) for each sample at the corresponding
#'   scale and location.
#' 
#' @param g A vector of covariate values. Can be a factor (2 groups
#'   only) or quantitative. For a 2-group categorical covariate, provide
#'   \code{g} as a 0-1 factor instead of a 0-1 numeric vector for faster
#'   computation.
#' 
#' @param minobs Minimum number of non-zero required for each model to
#'   be fitted (otherwise NA is returned for that model).
#' 
#' @param pseudocounts A number to be added to counts when counts are
#'   zero (or possibly extremely small).
#' 
#' @param all Bool, if TRUE pseudocounts are added to all entries, if
#'   FALSE (default) pseudocounts are added only to cases when either
#'   number of successes or number of failures (but not both) is 0.
#' 
#' @param center Bool, indicating whether to center \code{g}. If
#'   \code{g} is a 2-group categorical variable and centering is
#'   desired, use \code{center=TRUE} instead of treating \code{g} as
#'   numeric and centering manually to avoid slower computation.
#' 
#' @param repara Bool, indicating whether to reparameterize
#'   \code{alpha} and \code{beta} so that their likelihoods can be
#'   factorized.
#' 
#' @param forcebin Bool, if TRUE don't allow for
#'   overdipersion. Defaults to TRUE if \code{nsig=1}, and FALSE
#'   otherwise.
#' 
#' @param lm.approx Bool, indicating whether a WLS alternative should
#'   be used. Defaults to FALSE.
#' 
#' @param disp A string, can be either "add" or "mult", indicating the
#'   form of overdispersion assumed when \code{lm.approx=TRUE}.
#' 
#' @param bound Numeric, indicates the threshold of the success vs
#' failure ratio below which pseudocounts will be added.
#'
#' @return A matrix of 2 (or 5 if g is provided) by T (# of WCs); Each
#'   row contains alphahat (1st row), standard error of alphahat (2nd),
#'   betahat (3rd), standard error of betahat (4th), covariance between
#'   alphahat and betahat (5th) for each WC.
#' 
#' @export
#' 
glm.approx = function(x, g = NULL, minobs = 1, pseudocounts = 0.5,
                      all = FALSE, eps = 1e-08, center = FALSE,
                      repara = FALSE, forcebin = FALSE, lm.approx = FALSE,
                      disp = c("add", "mult"), bound = 0.02) {
    disp = match.arg(disp)

    # If x is a vector convert to matrix.
    if (is.vector(x)) {
      dim(x) <- c(1, length(x))
    }  
    n = ncol(x)/2
    ng = nrow(x)

    # If x has 1 row don't use the lm approximation.
    if (ng == 1) {
        lm.approx = FALSE  
        forcebin = TRUE
    } else {

        # Extract success and failure counts separately.
        x.sf = extract.sf(x, n)

        # Find indices for which there is no data.
        indexn = (x.sf$x.s == 0 & x.sf$x.f == 0)  
        indexnm = matrix(indexn, nrow = ng, byrow = T)
    }
    if (lm.approx == TRUE) {
        
        # Use WLS approximation. Find indices for which there is
        # insufficient data.
        na.index = colSums(matrix((x.sf$x.s + x.sf$x.f) != 0, ncol = n,
            byrow = T)) < minobs

        # Obtain estimates for logit(p) and var(logit(p)).
        z = compute.approx.z(x.sf$x.s, x.sf$x.f, bound, eps,
                             pseudocounts, all, indexn)  
        if (is.null(g)) {
            
            # Smoothing multiple signals without covariate.
            res = wls.coef(z, disp, indexnm, n, ng, forcebin)
            return(compute.lm(g, res$coef, res$se, res$mbvar, n,
                              na.index, repara))
        } else {
            if (is.factor(g))

              # If g is a 2-level factor convert to numeric.
              g = as.numeric(levels(g))[g] 
            if (center == TRUE) 
                g = g - mean(g)
            res = wls.coef(z, disp, indexnm, n, ng, forcebin, g, repara)
            return(compute.lm(g, res$coef, res$se, res$mbvar, n, na.index,
                              repara))
        }
    } else {
        
        # Use GLM case where g is absent smoothing multiple signals.
        if (is.null(g)) {
            if (ng > 1) {
                x = colSums(x)  # Pool data together as in GLM.
            }
            x = matrix(x, ncol = n)
            na.index = (colSums(x) == 0)

            # Obtain estimates for logit(p) and var(logit(p))
            #indexn = NULL?
            z = compute.approx.z(x[1, ], x[2, ], bound, eps,
                                 pseudocounts, all, NULL, TRUE)

            # Computes dispersion.
            d = compute.dispersion(z$p, n, ng, indexnm, forcebin,
                                   x.s = x.sf$x.s, x.f = x.sf$x.f) 
            return(compute.glm(z, g, d, n, na.index, repara))
        } else {
            
            # Case where g is present first consider case where g is
            # factor, and hence with closed form solution.
            if (is.factor(g)) {
                lg = length(levels(g))
                ord = sort.list(g)
                if (ng > lg) {
                    
                  # Pool successes and failures in the same category,
                  # depending on if there are more obs than no. of
                  # categories or not.
                  x.mer = matrix(0, nrow = lg, ncol = 2 * n)
                  ind = list(0)
                  for (i in 1:lg) {
                    ind[[i]] = (g == levels(g)[i])
                    x.mer[i, ] = colSums(matrix(x[ind[[i]], ],
                                         nrow = sum(ind[[i]])))
                  }
                } else {
                  ind = NULL
                  x.mer = x[ord, ]
                }

                # Now consider pooled data as effective raw data and
                # extract successes and failures.
                x.mer.s = x.mer[,(1:(2 * n))%%2 == 1]
                x.mer.f = x.mer[,(1:(2 * n))%%2 == 0]

                # Find indices with insufficient data since data are
                # pooled, min no. of obs cannot be less than number of
                # groups in g.
                na.index = colSums(matrix((x.mer.s + x.mer.f) != 0,
                                   ncol = n)) < pmin(minobs, lg)  
                na.index = rep(na.index, times = lg)

                # Extract successes and failures from pooled data.
                x.s.m = as.vector(t(x.mer.s)) 
                x.f.m = as.vector(t(x.mer.f))

                # Define indices where pooled data still has no data.
                indexn = (x.s.m == 0 & x.f.m == 0)

                # Obtain estimates for logit(p) and var(logit(p)).
                # indexn?
                z = compute.approx.z(x.s.m, x.f.m, bound, eps,
                                     pseudocounts, all, indexn, TRUE)  
                res = glm.coef(z, g, n, center, repara)

                # Computes dispersion.
                d = compute.dispersion(z$p, n, ng, indexnm, forcebin,
                                       ind, ord, lg, x) 
                return(compute.glm(res, g, d, n, na.index, repara))
            } else {
                
                # Now consider the case when g is quantitative.
                x = matrix(x, ncol = n)
                if (center == TRUE) 
                  g = g - mean(g)
                
                # Use the bintest function to fit a GLM separately to
                # each case for quantitative covariate.
                return(apply(x, 2, bintest, g = g, minobs = minobs,
                             pseudocounts = pseudocounts, all = all,
                             forcebin = forcebin, repara = repara))
            }
        }
    }
} 
