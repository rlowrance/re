# DistancesEuclidean.R

DistancesEuclidean <- function(df, query, featureNames) {
  # Determine Euclidean distances from all observations in a data frame
  # to a query observation.
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
  # Value: numeric vector containing the Euclidean distance from each
  # observation in df to the query point

  if (nrow(query) != 1)
    stop("query must have one row")
  if (class(featureNames) != "character")
    stop("featureNames class must be character")
  sum <- 0
  for (featureName in featureNames) {
  	distances <- df[[featureName]] - query[[featureName]]
  	sum <- sum + distances * distances
  }
  result <- sqrt(sum)
  if (length(result) == 0) {
    print("DistancesEuclidean: result has zero length")
    browser()
  }
  result
}

DistancesEuclidean.Test <- function() {
  # Unit test of DistancesEuclidean
  df <- data.frame(x=c(1,2),
                   y=c(3,4))
  query <- data.frame(x=4,
                      y=5)
  featureNames <- c("x", "y")
  distances <- DistancesEuclidean(df, query, featureNames)
  # distances[1] = sqrt((1-4)^2 + (3-5)^2) = sqrt(9 + 4)
  # distances[2] = sqrt((2-4)^2 + (4-5)^2) = sqrt(4 + 1)
  tolerance <- 1e-6
  Near <- function(expected, actual) {
    if (abs(expected - actual) > tolerance)
      stop(sprintf("unit test error; expected=%f actual=%f",
                   expected, actual))
  }
  Near(sqrt(13), distances[1])
  Near(sqrt(5), distances[2])
}

DistancesEuclidean.Test()
