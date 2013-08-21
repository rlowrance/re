# FeatureScale.R
# source: http://al3xandr3.github.com/2011/03/08/ml-ex3.html

FeatureScale <- function(df, column.names) {
  # Scale specified column in a data frame
  #
  # Args:
  # df: a data frame
  # column.names: vector of column names to be scaled
  #
  # Value:
  # new data frame with added columns
  #  feature.scale = (feature - mean) / stdv
  for (column.name in column.names) {
    mu <- mean(df[column.name])
    sigma <- st(df[column.name])
    df[paste(names(df[column.name]), ".scale", sep="")] <-
      (df[column.name] - mu) / sigma
  }
  df
}
