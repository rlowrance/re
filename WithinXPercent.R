WithinXPercent <- function(actual, estimated, precision = .10) {
    # return fraction of estimates that are within (say) 10 percent of the actuals
    #cat('starting WithinXPercent', length(actual), length(estimated), precision, '\n'); browser()
    stopifnot(length(actual) == length(estimated))
    stopifnot(length(actual) > 0)
    stopifnot(sum(actual == 0) == 0)  # at least one actual is zero
    na.indices <- is.na(actual) | is.na(estimated)  # find NAs in either arg
    actual.ok <- actual[!na.indices]
    estimated.ok <- estimated[!na.indices]
    error <- actual.ok - estimated.ok
    relative.error <- error / actual.ok
    sum(abs(relative.error) <= precision) / length(actual.ok)
}

WithinXPercent.test <- function() {
    actual <- c(1,2,3)
    estimated <- c(1.05, 20, NA)
    within <- WithinXPercent(actual, estimated)
    #cat('within', within, '\n')
    stopifnot(all.equal(within, 1/2))
}

WithinXPercent.test()
