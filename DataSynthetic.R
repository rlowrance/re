source('Assess.R')
source('Printf.R')
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

    GenerateFeatures <- function( coefficients
                                 ,land.size.min, land.size.max
                                 ,latitude.min, latitude.max
                                 ,has.pool.frequency) {
        # return data frame
        #cat('start GeneratedFeatures\n'); browser()
        elapsed.days <- last.date - first.date + 1
        one.obs.per.day <- data.frame( stringsAsFactors = FALSE
                                      ,saleDate = first.date + 0:(elapsed.days - 1)
                                      ,land.size = runif( elapsed.days
                                                         ,min = land.size.min
                                                         ,max = land.size.max
                                                         )
                                      ,latitude  = runif( elapsed.days
                                                         ,min = latitude.min
                                                         ,max = latitude.max
                                                         )
                                      ,has.pool  = 
                                         ifelse( runif(elapsed.days, min = 0, max = 1) > has.pool.frequency
                                                ,TRUE
                                                ,FALSE
                                                )
                                      )
        many.obs.per.day <- data.frame( stringsAsFactors = FALSE
                                       ,saleDate = rep(one.obs.per.day$saleDate, obs.per.day)
                                       ,recordingDate = rep(one.obs.per.day$saleDate + 14, obs.per.day)
                                       ,land.size = rep(one.obs.per.day$land.size, obs.per.day)
                                       ,latitude = rep(one.obs.per.day$latitude, obs.per.day)
                                       ,has.pool = rep(one.obs.per.day$has.pool, obs.per.day)
                                       )
        many.obs.per.day
    }

    GenerateTrueValues <- function(coefficients, features) {
        # return vector of true values
        #cat('start GenerateTrueValues\n'); browser()
        true.value <- 
            coefficients$intercept +
            coefficients$land.size * features$land.size +
            coefficients$latitude  * features$latitude +
            coefficients$has.pool  * features$has.pool
    }
    

    # MAIN BODY STARTS HERE
    #cat('starting DataSynthetic\n'); browser()
    
    coefficients <- list( intercept = 10000
                         ,land.size = 100
                         ,latitude = 20
                         ,has.pool = 20000
                         )

    generated.features <- GenerateFeatures( coefficients
                                           ,land.size.min = 1
                                           ,land.size.max = 100
                                           ,latitude.min = 0
                                           ,latitude.max = 90
                                           ,has.pool.frequency = .5
                                           )
    
    generated.true.values <- GenerateTrueValues(coefficients, generated.features)

    GeneratePrices <- function(true.values, bias, sd) {
        mean.true.values <- mean(true.values)
        prices <- rnorm( length(true.values)
                        ,mean = mean.true.values * bias
                        ,sd = mean.true.values * sd)
        prices
    }

    generated.prices <- GeneratePrices(generated.true.values, market.bias, market.sd)
    generated.assessments <- GeneratePrices(generated.true.values, assessment.bias, assessment.sd)

    result <- cbind( generated.features
                    ,true.value = generated.true.values
                    ,price = generated.prices
                    ,log.price = log(generated.prices)
                    ,assessment = generated.assessments
                    )

    if (FALSE) {
        # check accuracy of market and assessment
        assess.market <- Assess(list(actual = result$true.value, prediction = result$price))
        assess.assessment <- Assess(list(actual = result$true.value, prediction = result$assessment))
        Printf('fraction of prices within 10 percent of true value = %f\n', 
               assess.market$within.10.percent)
        Printf('fraction of assessments within 10 percent of true value = %f\n', 
               assess.assessment$within.10.percent)
    }

    result
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
