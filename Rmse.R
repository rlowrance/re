Rmse <- function(actual, prediction) {
    # return square root of mean squared error
    #cat('starting Rmse', length(actual), length(prediction), '\n'); browser()
    stopifnot(length(actual) == length(prediction))
    stopifnot(length(actual) > 0)
    na.indices <- is.na(actual) | is.na(prediction)
    actual.ok <- actual[!na.indices]
    prediction.ok <- prediction[!na.indices]
    error <- actual.ok - prediction.ok
    mse <- sum(error * error) / length(actual.ok)
    sqrt(mse)
}

Rmse.test <- function() {
    actual <- c(10, 20, 30, 40)
    prediction <- c(11, 21, 31, NA)
    mse <- Rmse(actual, prediction)
    stopifnot(mse == 1)
}

Rmse.test()
