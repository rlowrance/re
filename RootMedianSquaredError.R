RootMedianSquaredError <- function(actual, prediction) {
    # return square root of the median squared error
    #cat('start RootMedianSquaredError\n'); browser()
    stopifnot(length(actual) == length(prediction))
    stopifnot(length(actual) > 0)
    na.indices <- is.na(actual) | is.na(prediction)
    actual.ok <- actual[!na.indices]
    prediction.ok <- prediction[!na.indices]
    error <- actual.ok - prediction.ok
    median.value <- median(error * error)
    sqrt(median.value)
}

RootMedianSquaredError.test <- function() {
    actual <- c(10, 20, 311, 40)
    prediction <- c(11, 20, 30, NA)
    rmse <- RootMedianSquaredError(actual, prediction)
    stopifnot(rmse == 1)
}

RootMedianSquaredError.test()
