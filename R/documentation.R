#' @useDynLib smashr
#' 
#' @title smashr: Smoothing using Adaptive SHrinkage in R
#' 
#' @description This package performs nonparametric regression on
#'   univariate Poisson or Gaussian data using multi-scale methods. For
#'   the Poisson case, the data \eqn{x} is a vector, with \eqn{x_j \sim
#'   Poi(\mu_j)} where the mean vector \eqn{\mu} is to be estimated.
#'   For the Gaussian case, the data \eqn{x} are a vector with \eqn{x_j
#'   \sim N(\mu_j, \sigma^2_j)}. Where the mean vector \eqn{\mu} and
#'   variance vector \eqn{\sigma^2} are to be estimated. The primary
#'   assumption is that \eqn{\mu} is spatially structured, so \eqn{\mu_j
#'   - \mu_{j+1}} will often be small (that is, roughly, \eqn{\mu} is
#'   smooth). Also \eqn{\sigma} is spatially structured in the Gaussian
#'   case (or, optionally, \eqn{\sigma} is constant, not depending on
#'   \eqn{j}).
#' 
#' @details The function \code{\link{smash}} provides a minimal
#'   interface to perform simple smoothing.  It is actually a wrapper to
#'   \code{\link{smash.gaus}} and \code{\link{smash.poiss}} which
#'   provide more options for advanced use.  The only required input is
#'   a vector of length 2^J for some integer J.  Other options include
#'   the possibility of returning the posterior variances, specifying a
#'   wavelet basis (default is Haar, which performs well in general due
#'   to the fact that smash uses the translation-invariant transform)
#' 
#' @author Matthew Stephens and Zhengrong Xing
#' 
#' @docType package
#' 
#' @name smashr
NULL
