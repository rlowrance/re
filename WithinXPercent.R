WithinXPercent <- function(actual, prediction, precision = .10) {
    # return fraction of estimates that are within (say) 10 percent of the actuals
    #cat('starting WithinXPercent', length(actual), length(prediction), precision, '\n'); browser()
    if (is.null(actual)) {
        # no actuals are known
        result <- 1
    } else {
        stopifnot(length(actual) == length(prediction))
        stopifnot(length(actual) > 0)
        na.indices <- is.na(actual) | is.na(prediction)  # find NAs in either arg
        if (sum(na.indices) == length(actual)) {
            # no comparisons are possible
            result <- 1
        } else {
            actual.ok <- actual[!na.indices]
            prediction.ok <- prediction[!na.indices]
            error <- actual.ok - prediction.ok
            relative.error <- error / actual.ok
            result <- sum(abs(relative.error) <= precision) / length(actual.ok)
        }
    }
    result
}

WithinXPercent.test <- function() {
    Test1 <- function() {
        actual <- c(1,2,3)
        prediction <- c(1.05, 20, NA)
        within <- WithinXPercent(actual, prediction)
        stopifnot(length(within) == 1)
        stopifnot(within == 1/2)
    }
    Test1()

    Test2 <- function() {
        actual = c(1,1,1,1,1)
        prediction = c(1,2,.5,1.09,.91)
        within <- WithinXPercent(actual, prediction)
        stopifnot(within == .6)
    }
    Test2()

    Test3 <- function() {
        actual = c(NA, 20, 30)
        prediction = c(10, 21, NA)
        within <- WithinXPercent(actual, prediction)
        stopifnot(within == 1)
    }
    Test3()

    Test4 <- function() {
        actual = c(NA, NA)
        prediction = c(1, 2)
        within <- WithinXPercent(actual, prediction)
        stopifnot(within == 1)
    }
    Test4()

    Test5 <- function() {
        actual <- NULL
        prediction <- c(1)
        within <- WithinXPercent(actual, prediction)
        stopifnot(within == 1)
    }
    Test5()
}

WithinXPercent.test()
