# KernelGaussian.R

KernelGaussian <- function(df, query, featureNames, sigma) {
  # return kernel values using Gaussian kernel with hp sigma
  #
  # ARGS
  #
  # df: data frame containing the observations
  #
  # query: a data frame with one observations
  #
  # featureNames: vector or list of character, the names of the features in df
  # and query to use
  #
  # sigma: scalar numeric, the standard deviation for the kernel (aka,
  # the kernel width)
  #
  # Value: numeric vector containing the weight from each observation in 
  # df to the query point. The weights sum to one.
	
  #print("in KernelGaussian"); browser()
  if (class(featureNames) != "character")
    stop("class of featureNames must be character")
  if (class(sigma) != "numeric")
    stop("class of sigma must be numeric")
  distances <- DistancesEuclidean(df, query, featureNames)
  tSquared <- distances * distances
  weights <- exp(- tSquared / (2 * sigma * sigma)) / (sqrt(2 * pi) * sigma)
  # normalize weights to one
  sumWeights <- sum(weights)
  if (sumWeights == 0) {
    normalizedWeights <- rep(1 / length(weights), length(weights))
    #cat("found sumWeights == 0\n")
    #browser()
  } else {
    normalizedWeights <- weights / sumWeights
  }
  if (length(normalizedWeights) == 0) {
    cat("KernelGaussian: weights have zero length\n")
    browser()
  }
  if (sum(is.nan(normalizedWeights)) > 0) {
    cat("KernelGaussian: one or more weights is NaN\n")
    browser()
  }
  normalizedWeights
}
