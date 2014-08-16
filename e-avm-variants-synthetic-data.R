# e-avm-variants-synthetic-data.R
# Determine if avm with assessment outperforms avm without assessment for synthetic data
# Test cases designed around the relative accuracies of the market and assessment:
# - assessment is more accurate than the market
# - assessment is exactly as accurate as the market
# - assessment is less accurate than the market
# 
# Accuracy here means the size of the standard deviation of the noise applied to the
# true value, as defined by the arguments market.sd.fraction and assessment.sd.fraction
# to the function DataSynthetic.

source('DataSynthetic.R')
#source('EAvmVariantsSyntheticDataReport.R')

library(devtools)
load_all('/Users/roy/Dropbox/lowranceutilitiesr')
load_all('/Users/roy/Dropbox/lowrancerealestater')


MakeSyntheticData <- function(assessment.bias, assessment.relative.error, control) {
    # return synthetic data in a data.frame and also the coefficients used to generate that data
    #cat('start MakeSyntheticData', assessment.bias, assessment.relative.error, '\n'); browser()

    assessment.bias <- 
        switch( assessment.bias
               ,low = control$assessment.bias.low
               ,zero = control$assessment.bias.zero
               ,high = control$assessment.bias.high
               )

    assessment.ds.fraction <- 
        switch( assessment.relative.error
               ,lower = control$market.sd.fraction * control$assessment.relative.sd.lower
               ,same = control$market.sd.fraction * control$assessment.relative.sd.same
               ,higher = control$market.sd.fraction * control$assessment.relative.sd.higher
               )

    ds <- DataSynthetic( obs.per.day = 100
                        ,first.date = as.Date('2007-01-01')
                        ,last.date = as.Date('2008-01-31')
                        ,market.bias = control$market.bias
                        ,market.sd.fraction = control$market.sd.fraction
                        ,assessment.bias = assessment.bias
                        ,assessment.sd.fraction = assessment.ds.fraction
                        )
    ds
}

TestScenarios <- function(data, actual.coefficients, control) {
    # return a data.frame containing the results of testing on each of the 4 scenarios
    # The test is to determine the error on the January transaction after training for 60 days
    # The model formula is price ~ <predictors>

    TranslateScenarioName <- function(scenario) {
        # translate local scenario name into name used by MakeModelLinear
        switch( scenario
               ,'assessor' = scenario
               ,'avm w/o assessment' = 'avm'
               ,'avm w/ assessment' = 'avm'
               ,'mortgage' = scenario
               )
    }

    Predictors <- function(scenario) {
        # return the predictors that we use for the specified scenario
        switch( scenario
               ,'assessor' =
               ,'avm w/o assessment' = c('land.size', 'latitude', 'has.pool')
               ,'avm w/ assessment' =
               ,'mortgage' = c('land.size', 'latitude', 'has.pool', 'assessment')
               ,stop('bad scenario')
               )
    }

    ExtractCoefficients <- function(cv.result) {
        # return coefficients in the fitted model
        #cat('start ExtractCoefficients\n'); browser()
        result <- cv.result$fitted$coefficients
        result
    }

    CheckCoefficients <- function(fitted.coefficients, actual.coefficients) {
        # error if the predicted coefficients are not sufficiently close to the actual coefficients
        #cat('start CheckCoefficients\n'); browser()
        verbose <- FALSE
        if (verbose) {
            print(fitted.coefficients)
            print(actual.coefficients)
        }
        for (name in names(fitted.coefficients)) {
            if (name != '(Intercept)') {
                actual <- switch( name
                                 ,'has.poolTRUE' = actual.coefficients$has.pool
                                 ,actual.coefficients[[name]]
                                 )
                fitted <- fitted.coefficients[[name]]
                relative.abs.error <- (abs(actual - fitted) / actual) 
                limit <- .4
                if (relative.abs.error > limit) {
                    print(fitted.coefficients)
                    print(actual.coefficients)
                    print(relative.abs.error)
                    print(name)
                }
                stopifnot(relative.abs.error <= limit)
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
        all <- IfThenElse(is.null(all), next.row, rbind(all, next.row))
    }
    all
}

Experiment <- function(assessment.bias, assessment.relative.error, control) {
    # return data frame with these columns
    # $scenario = name of scenario, in 'assessor', 'avm w/o assessment', 'avm w/ assessment', 'mortgage'
    # $rmse = error from a log-log model, trained for 60 days and testing on Jan 2008 data



    # BODY BEGINS HERE
    #cat('start Experiment', assessment.bias, assessment.relative.error, '\n')
    #browser()

    sd <- MakeSyntheticData(assessment.bias, assessment.relative.error, control)
    df <- TestScenarios(sd$data, sd$coefficients)
    df # return data frame containing result of test, one row per test
}


Sweep <- function(f, assessment.biases, assessment.relative.errors, control) {
    # return data.frame containing a row for each element in cross product of list1 and list2
    # and scenario and rmse for that scenario on appropriate synthetic data
    #cat('Sweep\n'); browser()

    # build up a data.frame
    all <- NULL
    for (assessment.bias in assessment.biases) {
        for (assessment.relative.error in assessment.relative.errors) {
            one <- f(assessment.bias, assessment.relative.error, control)
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
    #cat('start Main'); browser()

    path.output = '../data/v6/output/'
    me <- 'e-avm-variants-synthetic-data' 
    control <- list( response = 'price'
                    ,path.out.log = paste0(path.output, me, '.log')
                    ,path.out.save = paste0(path.output, me, '.rsave')
                    ,testing.period = list( first.date = as.Date('2008-01-01')
                                           ,last.date = as.Date('2008-01-31')
                                           )
                    ,market.bias = 1
                    ,market.sd.fraction = .2
                    ,assessment.bias.low = .8
                    ,assessment.bias.zero = 1
                    ,assessment.bias.high = 1.2
                    ,assessment.relative.sd.lower = .5
                    ,assessment.relative.sd.same = 1
                    ,assessment.relative.sd.higher = 2
                    ,num.training.days = 60
                    ,random.seed = 123
                    )

    InitializeR(duplex.output.to = control$path.out.log, random.seed = control$andom.seed)
    print(control)

    result.df <- Sweep( f = Experiment
                       ,assessment.biases = c('zero', 'low', 'high')
                       ,assessment.relative.errors = c('lower', 'same', 'higher')
                       ,control = control
                       )
    cat('main, after Sweep\n'); browser()
    save(result.df, file = control$path.out.save)

    # write a report to the console
    print(result.df)
#    report.lines <- EAvmVariantsSyntheticDataReport(result.df)
#    writeLines( text = report.lines
#               ,sep  = '\n'
#               )

    print(control)
}




Main()
cat('done\n')
