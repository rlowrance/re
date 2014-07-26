TestingPeriods <- function() {
    # return list of testing period, each element a list (first.date, last.date)
    #cat('starting TestingPeriods\n'); browser()
    result <- NULL
    for (year in c(2008, 2009)) {
         last.month <- ifelse(year == 2008, 12, 11)
         for (month in 1:last.month) {
             first.date <- as.Date(sprintf('%4d-%2d-%2d', year, month, 1))
             last.date <- first.date + DaysInMonth(year, month) - 1
             result <- ListAppend(result, 
                                  list( year = year
                                       ,month = month
                                       ,first.date = first.date
                                       ,last.date = last.date
                                       )
                                  )
         }
    }
    result
}

TestingPeriods.test <- function() {
    #cat('starting TestingPeriods.test\n'); browser()
    testing.periods <- TestingPeriods()
    stopifnot(length(testing.periods) == 23)

    first <- testing.periods[[1]]
    stopifnot(first$year == 2008)
    stopifnot(first$month == 1)
    stopifnot(first$first.date == as.Date('2008-01-01'))
    stopifnot(first$last.date == as.Date('2008-01-31'))

    last <- testing.periods[[length(testing.periods)]]
    stopifnot(last$year == 2009)
    stopifnot(last$month == 11)
    stopifnot(last$first.date == as.Date('2009-11-01'))
    stopifnot(last$last.date == as.Date('2009-11-30'))
}

TestingPeriods.test()
