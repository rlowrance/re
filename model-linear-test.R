# model-linear-test.R
# main program to test ModelLinear
# Approach: use synthetic data

source('Assess.R')
source('DataSynthetic.R')
source('InitializeR.R')
source('MakeModelLinear.R')
source('ModelLinearTestMakeReport.R')
source('Printf.R')

Experiment <- function(assessment.bias, assessment.relative.error) {
    # return data frame with these columns
    # $scenario = name of scenario, in 'assessor', 'avm w/o assessment', 'avm w/ assessment', 'mortgage'
    # $rmse = error from a log-log model, trained for 60 days and testing on Jan 2008 data


    MakeSyntheticData <- function(assessment.bias, assessment.relative.error) {
        # return synthetic data in a data.frame and also the coefficients used to generate that data
        #cat('start MakeSyntheticData', assessment.bias, assessment.relative.error, '\n'); browser()
        market.sd = .2  # standard deviation of market prices as a fraction of mean market price
        ds <- DataSynthetic( obs.per.day = 100
                            ,first.date = as.Date('2007-01-01')
                            ,last.date = as.Date('2008-01-31')
                            ,market.bias = 1
                            ,market.sd = market.sd
                            ,assessment.bias = switch( assessment.bias
                                                      ,low = .8
                                                      ,zero = 1
                                                      )
                            ,assessment.sd = switch( assessment.relative.error
                                                    ,lower  = 0.5 * market.sd
                                                    ,same   = 1.0 * market.sd
                                                    ,higher = 2.0 * market.sd
                                                    )
                            )
        ds
    }

    TestScenarios <- function(data, actual.coefficients) {
        # return a data.frame containing the results of testing on each of the 4 scenarios
        # The test is to determine the error on the January transaction after training for 60 days
        # The model formula is price ~ <predictors>

        TranslateScenarioName <- function(scenario) {
            # translate local scenario name into name used by MakeModelLinear
            switch( scenario
                   ,'assessor' = scenario
                   ,'avm w/o assessment' = 'avmnoa'
                   ,'avm w/ assessment' = 'avm'
                   ,'mortgage' = scenario
                   )
        }

        Predictors <- function(scenario) {
            switch( scenario
                   ,'assessor' =
                   ,'avm w/o assessment' = c('land.size', 'latitude', 'has.pool')
                   ,'avm w/ assessment' =
                   ,'mortgage' = c('land.size', 'latitude', 'has.pool', 'assessment')
                   ,stop('bad scenario')
                   )
        }

        ExtractCoefficients <- function(cv.result) {
            #cat('start ExtractCoefficients\n'); browser()
            result <- cv.result$fitted$coefficients
            result
        }

        CheckCoefficients <- function(fitted.coefficients, actual.coefficients) {
            #cat('start CheckCoefficients\n'); browser()
            print(fitted.coefficients)
            print(actual.coefficients)
            for (name in names(fitted.coefficients)) {
                if (name != '(Intercept)') {
                    actual <- switch( name
                                     ,'has.poolTRUE' = actual.coefficients$has.pool
                                     ,actual.coefficients[[name]]
                                     )
                    fitted <- fitted.coefficients[[name]]
                    relative.abs.error <- (abs(actual - fitted) / actual) 
                    stopifnot(relative.abs.error <= 0.2)
                }
            }
        }

        # BODY START HERE
        #cat('start TestScenarios', nrow(data), '\n'); browser()
        

        all.data.indices <- 1:nrow(data)
        all <- NULL
        for (scenario in c('assessor', 'avm w/o assessment', 'avm w/ assessment', 'mortgage')) {
            cat('scenario', scenario, '\n')
            #browser()
            CvModel <- MakeModelLinear( scenario = TranslateScenarioName(scenario)
                                       ,response = 'price'
                                       ,predictors = Predictors(scenario)
                                       ,testing.period = list( first.date = as.Date('2008-01-01')
                                                              ,last.date = as.Date('2008-01-31')
                                                              )
                                       ,data = data
                                       ,num.training.days = 60
                                       ,verbose.model = FALSE
                                       )
            cv.result <- CvModel( data = data
                                 ,training.indices = all.data.indices
                                 ,testing.indices = all.data.indices
                                 )
            if (scenario == 'assessor') {
                # the coefficients should be close to what was used to generate the data
                CheckCoefficients(ExtractCoefficients(cv.result), actual.coefficients)
            }
            assess <- Assess(cv.result)
            next.row <- data.frame( stringsAsFactors = FALSE
                                   ,scenario = scenario
                                   ,rmse = assess$rmse
                                   )
            all <- if (is.null(all)) next.row else rbind(all, next.row)
        }
        all
    }

    # BODY BEGINS HERE
    cat('start Experiment', assessment.bias, assessment.relative.error, '\n')
    #browser()

    sd <- MakeSyntheticData(assessment.bias, assessment.relative.error)
    df <- TestScenarios(sd$data, sd$coefficients)
    df # return data frame containing result of test, one row per test


    # generate synthetic data
    # define and test models for 4 scenarios on the synthetic data
    
}

Sweep <- function(f, assessment.biases, assessment.relative.errors) {
    # return data.frame containing a row for each element in cross product of list1 and list2
    # and scenario and rmse for that scenario on appropriate synthetic data
    #cat('Sweep\n'); browser()

    # build up a data.frame
    all <- NULL
    for (assessment.bias in assessment.biases) {
        for (assessment.relative.error in assessment.relative.errors) {
            one <- f(assessment.bias, assessment.relative.error)
            new.row <- data.frame( stringsAsFactors = FALSE
                                  ,assessment.bias = assessment.bias
                                  ,assessment.relative.error = assessment.relative.error
                                  ,scenario = one$scenario
                                  ,rmse = one$rmse
                                  )
            all <- if(is.null(all)) new.row else rbind(all, new.row)
        }
    }
    all
}

Main <- function() {
    # Run experiments over cross product of situations, return df containing RMSE values
    
    #cat('start Main\n'); browser()
    result.df <- Sweep( f = Experiment
                       ,assessment.biases = c('zero', 'low')
                       ,assessment.relative.errors = c('lower', 'same', 'higher')
                       )
    save(result.df, file = '../data/v6/output/model-linear-test.rsave')
    report <- ModelLinearTestMakeReport(result.df)
    print(report)

    return(result.df)
}

InitializeR(duplex.output.to = '../data/v6/output/model-linear-test-log.txt')
Main()
