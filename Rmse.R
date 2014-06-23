Rmse <- function(actual, estimated) {
    # return square root of mean squared error
    #cat('starting Rmse', length(actual), length(estimated), '\n'); browser()
    stopifnot(length(actual) == length(estimated))
    stopifnot(length(actual) > 0)
    na.indices <- is.na(actual) | is.na(estimated)
    actual.ok <- actual[!na.indices]
    estimated.ok <- estimated[!na.indices]
    error <- actual.ok - estimated.ok
    mse <- sum(error * error) / length(actual.ok)
    sqrt(mse)
}

Rmse.test <- function() {
    actual <- c(10, 20, 30, 40)
    estimated <- c(11, 21, 31, NA)
    mse <- Rmse(actual, estimated)
    stopifnot(mse == 1)
}

Rmse.test()
