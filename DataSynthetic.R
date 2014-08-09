source('IfThenElse.R')
DataSynthetic <- function(obs.per.day, first.date, last.date, inflation.annual.rate) {
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
    
    stopifnot(inflation.annual.rate >= 0)
    stopifnot(inflation.annual.rate <= 1)

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
            (1 + inflation.annual.rate) ^ as.numeric(elapsed.days / days.per.year)
        true.value.inflated <- inflation.factor * true.value.no.inflation

        true.value.inflated
    }

    # generate data frame with randomly selected regressors
    #cat('start of loop\n'); browser()
    all.rows <- NULL  # a data.frame   
    elapsed.days <- last.date - first.date + 1
    set.seed(123)
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

    # price := true.value + market.error
    # assessment := price + assessment.error
    #cat('after loop\n'); browser()
    mean.true.value <- mean(all.rows$true.value)
    market.error <- rnorm( n = nrow(all.rows)
                   ,mean = 0
                   ,sd = mean.true.value * .1
                   )
    price <- all.rows$true.value + market.error
    log.price <- log(price)

    mean.price <- mean(price)
    assessment.error <- rnorm( n = nrow(all.rows)
                              ,mean = 0
                              ,sd = mean.price * .1 
                              )
    assessment <- price + assessment.error




    data <- cbind( all.rows
                  ,price = price
                  ,log.price = log.price
                  ,assessment = assessment
                  )

    # check how accurate the assessments are vs. the prices
    if (FALSE) {
        model <- lm( formula = price ~ assessment + 0
                    ,data = data
                    )
        print(summary(model))
        predicted <- predict(model, data)
        actual <- data$price
        error <- predicted - actual
    }
    if (FALSE) {
        # determine how close the assessments are to actual prices
        error <- assessment - price
        relative.abs.error <- abs(error / price)
        is.close <- relative.abs.error < .10
        fraction.is.close <- sum(is.close) / length(price)
        cat('fraction of assessments within 10 percent', fraction.is.close, '\n')
    }

    result <- list( data = data
                   ,coefficients = coefficients
                   )
    result
}

DataSynthetic.test <- function() {
    # test for run to completion for now
    #cat('starting DataSynthetic.test\n'); browser()
    #data <- DataSynthetic(10, as.Date('2007-01-01'), as.Date('2008-12-31'))  # big test set

    if (FALSE) { # big test set
        data <- DataSynthetic( obs.per.day = 10
                              ,first.date = as.Date('2007-01-01')
                              ,last.date =  as.Date('2008-01-01')
                              ,inflation.annual.rate = .1
                              )
    }

    data <- DataSynthetic( obs.per.day = 1
                          ,first.date = as.Date('2007-01-01')
                          ,last.date =  as.Date('2007-01-01')
                          ,inflation.annual.rate = .1
                          )  # tiny test set
}

DataSynthetic.test()
