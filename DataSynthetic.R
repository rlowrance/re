source('Assess.R')
DataSynthetic <- function( obs.per.day
                          ,first.date
                          ,last.date
                          ,market.bias
                          ,market.sd
                          ,assessment.bias
                          ,assessment.sd
                          ) {
    # generate random synthetic data set
    # RETURNS list
    # $data         : data.frame
    # $coefficients : list of actual pre-inflation coefficients used to generate the data
    # ARGS
    # obs.per.day              : num, positive, number of observations in each day
    # first.date               : Date, first saleDate generated
    # last.date                : Date, last saleDate generated
    # market.bias              : num, mean ratio of true value to market value
    # market.sd                : num, market standard deviation as a fraction of mean true value
    # assessment.bias          : num
    # assessment.sd            : num, assessment standard deviation as a farction of the mean true value
    #
    # call set.seed() before calling me, if you want reproducability
    # NOTE: set the coefficients to give an average price of about $500,000

    GenerateFeatures <- function( land.size.min, land.size.max
                                 ,latitude.min, latitude.max
                                 ,has.pool.frequency) {
        # return data frame
        #cat('start GeneratedFeatures\n'); browser()
        elapsed.days <- last.date - first.date + 1
        n <- elapsed.days * obs.per.day
        result.1 <- data.frame( stringsAsFactors = FALSE
                               ,saleDate = seq(from = first.date, to = last.date, length.out = n)
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

    GenerateTrueValues <- function(coefficients, features) {
        # return vector of true values
        #cat('start GenerateTrueValues\n'); browser()
        true.values <- 
            coefficients$intercept +
            coefficients$land.size * features$land.size +
            coefficients$latitude  * features$latitude +
            coefficients$has.pool  * features$has.pool
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
    
    true.values <- GenerateTrueValues(coefficients, features)
    mean.true.value <- mean(true.values)

    GenerateFromTrueValues <- function(bias, sd) {
        #cat('start GenerateFromTrueValues', bias, sd, '\n'); browser()
        errors <- rnorm( length(true.values)
                        ,mean = mean.true.value * (bias - 1)
                        ,sd = mean.true.value * sd
                        )
        result <- true.values + errors
        result
    }

    prices <- GenerateFromTrueValues(market.bias, market.sd)
    assessments <- GenerateFromTrueValues(assessment.bias, assessment.sd)

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

    set.seed(123)

    data <- DataSynthetic( obs.per.day = 10
                          ,first.date = as.Date('2007-01-01')
                          ,last.date =  as.Date('2007-01-06')
                          ,market.bias = 1
                          ,market.sd = .10
                          ,assessment.bias = 2
                          ,assessment.sd = 0
                          )
}

DataSynthetic.test()
