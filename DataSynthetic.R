DataSynthetic <- function( obs.per.day
                          ,inflation.annual.rate = 0
                          ,first.date
                          ,last.date
                          ,market.bias
                          ,market.sd.fraction
                          ,assessment.bias
                          ,assessment.sd.fraction
                          ) {
    # generate random synthetic data set
    # RETURNS list
    # $data         : data.frame
    # $coefficients : list of actual pre-inflation coefficients used to generate the data
    # ARGS
    # obs.per.day              : num, positive, number of observations in each day
    # inflation.annual.rate    : num in [0,1], annual rate of inflation (ex: .10 for 10 percent per year)
    # first.date               : Date, first saleDate generated
    # last.date                : Date, last saleDate generated
    # market.bias              : num, mean ratio of true value to market value to true value
    #                            market.value = true.value * bias + market.error
    # market.sd.fraction       : num, market standard deviation as a fraction of true value
    #                            market.error is drawn from N(0, true.value * market.sd.fraction)
    # assessment.bias          : num, mean ratio of true value to assessment
    # assessment.sd.fraction   : num, assessment standard deviation as a fraction of the true value
    #                            assessment.value = like market.value
    #
    # call set.seed() before calling me, if you want reproducability
    #
    # NOTE: Generating assessment from true values is a problem if the assessment := true.value,
    # because then a linear model is colinear.


    GenerateFeatures <- function( land.size.min, land.size.max
                                 ,latitude.min, latitude.max
                                 ,has.pool.frequency) {
        # return data frame
        #cat('start GeneratedFeatures\n'); browser()
        elapsed.days <- last.date - first.date + 1
        n <- elapsed.days * obs.per.day
        dates <- seq(first.date, last.date, by = 1)
        result.1 <- data.frame( stringsAsFactors = FALSE
                               ,saleDate = rep(dates, obs.per.day)
                               ,land.size = runif(n, min = land.size.min, max = land.size.max)
                               ,latitude  = runif(n, min = latitude.min,  max = latitude.max)
                               ,has.pool  = ifelse( runif(n, min = 0, max = 1) > has.pool.frequency
                                                   ,TRUE
                                                   ,FALSE
                                                   )
                             )
        result <- cbind( result.1
                        ,recordingDate = result.1$saleDate + 14  # allow 2 weeks to record the deed
                        )
        result
    }

    GenerateTrueValues <- function(coefficients, features, inflation.annual.rate) {
        # return vector of true values
        #cat('start GenerateTrueValues\n'); browser()
        
        true.values.no.inflation <- 
            coefficients$intercept +
            coefficients$land.size * features$land.size +
            coefficients$latitude  * features$latitude +
            coefficients$has.pool  * features$has.pool

        # apply inflation
        inflation.daily.rate <- (1 + inflation.annual.rate) ^ (1 / 365) - 1
        lowest.date <- min(features$saleDate)
        elapsed.days <- as.numeric(features$saleDate - lowest.date)
        inflation.factors <- (1 + inflation.daily.rate) ^ elapsed.days
        inflated.values <- true.values.no.inflation * inflation.factors
        inflated.values
    }
    
    GenerateFromKnownValues <- function(known.values, bias, sd.fraction) {
        # return vector of values that randomly differ from the known.values
        #cat('start GenerateFromKnownValues', bias, sd.fraction, '\n'); browser()

        DriftedValue <- function(known.value) {
            # return one error
            #cat('start DriftedValue', known.value, '\n'); browser()
            drifted <- known.value * bias + rnorm(1, mean = 0, sd = sd.fraction * known.value)
            drifted
        }

        result <- sapply( known.values
                         ,DriftedValue
                         )
        result
    }


    # MAIN BODY STARTS HERE
    #cat('starting DataSynthetic\n'); browser()
    
    coefficients <- list( intercept = 0
                         ,land.size = 10000
                         ,latitude = 2000
                         ,has.pool = 20000
                         )

    features <- GenerateFeatures( land.size.min = 1
                                 ,land.size.max = 100
                                 ,latitude.min = 0
                                 ,latitude.max = 90
                                 ,has.pool.frequency = .5
                                 )
    
    true.values <- GenerateTrueValues(coefficients, features, inflation.annual.rate)

    prices <- GenerateFromKnownValues(true.values, market.bias, market.sd.fraction)
    assessments <- GenerateFromKnownValues(true.values, assessment.bias, assessment.sd.fraction)

    # some prices and assessments may be negative
    # when that is so, drop those observations

    is.valid.obs <- (prices > 0) & (assessments > 0)

    df.valid <- cbind( features
                      ,true.value = true.values
                      ,price = prices
                      ,assessment = assessments
                      )[is.valid.obs,]
    df.result <- cbind( df.valid
                       ,log.prices = log(df.valid$price)
                       )

    if (FALSE) {
        # check accuracy of market and assessment
        assess.market <- Assess(list(actual = df.result$true.value, prediction = df.result$price))
        assess.assessment <- Assess(list(actual = df.result$true.value, prediction = df.result$assessment))
        Printf('fraction of prices within 10 percent of true value = %f\n', 
               assess.market$within.10.percent)
        Printf('fraction of assessments within 10 percent of true value = %f\n', 
               assess.assessment$within.10.percent)
    }

    result <- list(data = df.result, coefficients = coefficients)
}

DataSynthetic.test <- function() {
    # test for run to completion for now
    #cat('starting DataSynthetic.test\n'); browser()
    #data <- DataSynthetic(10, as.Date('2007-01-01'), as.Date('2008-12-31'))  # big test set

    # NOTE: no random seed is set, because this code is run during load time

    data <- DataSynthetic( obs.per.day = 10
                          ,inflation.annual.rate = 1.00  # 100% inflation
                          ,first.date = as.Date('2007-01-01')
                          ,last.date =  as.Date('2007-01-06')
                          ,market.bias = 1
                          ,market.sd.fraction = .10
                          ,assessment.bias = 2
                          ,assessment.sd.fraction = 0
                          )
}

DataSynthetic.test()
