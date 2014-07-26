Require('DivisibleBy')
DaysInMonth <- function(year, month) {
    # return number of days in month, accounting for leap years
    #cat('starting DaysInMonth', year, month, '\n'); browser()

    result.no.leap.year <- c(31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31)[[month]]
    is.leap.year <- DivisibleBy(year, 4) & (!DivisibleBy(year, 100))
    result <- ifelse(is.leap.year & month == 2, 29, result.no.leap.year)
    result
}

DaysInMonth.test <- function() {
    stopifnot(DaysInMonth(2008,1) == 31)
    stopifnot(DaysInMonth(2008,2) == 29)
    stopifnot(DaysInMonth(2008,12) == 31)
    stopifnot(DaysInMonth(2009, 2) == 28)
}

DaysInMonth.test()

