source('IfThenElse.R')
DataSynthetic <- function(obs.per.day, first.date, last.date) {
    # generate random synthetic data set
    # RETURNS list
    # $data : data.frame
    # $coefficients : list of actual coefficients used to generate the data
    # ARGS
    # obs.per.day : num, positive, number of observations in each day
    # first.date  : Date, first saleDate generated
    # last.date   : Date, last saleDate generated
    #
    # call set.seed() before calling me, if you want reproducability
    #cat('starting DataSynthetic\n'); browser()
    
    inflation.rate.yearly <- .1  # percent per 365 days
    coefficients <- list( intercept = 10000
                         ,land.size = 100
                         ,latitude = 20
                         ,has.pool = 20000
                         )

    # model
    TrueValue <- function(land.size, latitude, has.pool, saleDate) {
        #cat('starting TrueValue', land.size, latitude, has.pool, saleDate, '\n'); browser()

        beta <- c(10000, 100, 20, 20000)
        true.value.no.inflation <-
            coefficients$intercept +
            coefficients$land.size * land.size +
            coefficients$latitude * latitude +
            coefficients$has.pool * has.pool

        # add in inflation
        elapsed.days <- saleDate - first.date
        days.per.year <- 365
        inflation.factor <- 
            (1 + inflation.rate.yearly) ^ as.numeric(elapsed.days / days.per.year)
        true.value.inflated <- inflation.factor * true.value.no.inflation

        true.value.inflated
    }

    # generate data frame with randomly selected regressors
    #cat('start of loop\n'); browser()
    all.rows <- NULL  # a data.frame   
    elapsed.days <- last.date - first.date + 1
    for (day.number in 1:elapsed.days) {
        for (obs in 1:obs.per.day) {
            saleDate <- as.Date(day.number, origin = first.date)
            # generate transaction on specified date
            land.size <- runif(1, min = 1, max = 100)
            latitude <- runif(1, min = 1, max = 90)
            has.pool <- ifelse(runif(1, min = 0, max = 1) > .5, TRUE, FALSE)
            true.value <- TrueValue(land.size, latitude, has.pool, saleDate)

            # append to data.frame all.rows
            next.row <- data.frame( saleDate = saleDate
                                   ,recordingDate = saleDate + 14  # recorded 2 weeks after sale
                                   ,land.size = land.size
                                   ,log.land.size = log(land.size)
                                   ,latitude = latitude
                                   ,has.pool = has.pool
                                   ,true.value = true.value
                                   )
            all.rows <- IfThenElse(is.null(all.rows), next.row, rbind(all.rows, next.row))
        }
    }

    # add in normalized errors
    #cat('after loop\n'); browser()
    mean.true.value <- mean(all.rows$true.value)
    error <- rnorm( n = nrow(all.rows)
                    ,mean = 0
                    ,sd = mean.true.value * .1
                    )
    price <- all.rows$true.value + error
    log.price <- log(price)

    data <- cbind( all.rows
                    ,error = error
                    ,price = price
                    ,log.price = log.price
                    )

    result <- list( data = data
                   ,coefficients = coefficients
                   )
    result
}

DataSynthetic.test <- function() {
    # test for run to completion for now
    #cat('starting DataSynthetic.test\n'); browser()
    #data <- DataSynthetic(10, as.Date('2007-01-01'), as.Date('2008-12-31'))  # big test set
    data <- DataSynthetic(1, as.Date('2007-01-01'), as.Date('2007-01-01'))  # tiny test set
}

DataSynthetic.test()
