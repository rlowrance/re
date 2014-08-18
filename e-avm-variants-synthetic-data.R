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


MakeSyntheticData <- function(assessment.bias.name, assessment.relative.sd.name, control) {
    # return synthetic data in a data.frame and also the coefficients used to generate that data
    #cat('start MakeSyntheticData', assessment.bias.name, assessment.relative.sd.name, '\n'); browser()

    assessment.bias <- control$assessment.bias.values[[assessment.bias.name]]
    assessment.ds.fraction <- control$assessment.relative.sd.values[[assessment.relative.sd.name]]

    ds <- DataSynthetic( obs.per.day = control$obs.per.day
                        ,inflation.annual.rate = control$inflation.annual.rate
                        ,first.date = as.Date('2007-01-01')
                        ,last.date = as.Date('2008-01-31')
                        ,market.bias = control$market.bias
                        ,market.sd.fraction = control$market.sd.fraction
                        ,assessment.bias = assessment.bias
                        ,assessment.sd.fraction = assessment.ds.fraction
                        )

    debugging <- FALSE
    if (debugging) {
        browser()
        dataframe <- ds$data

        Hash <- function(dataframe) {
            element.sum <- 0
            for (column.name in names(dataframe)) {
                print(column.name)
                element.sum <- element.sum + sum(as.numeric(dataframe[[column.name]]))
            }

            element.sum
        }

        cat('synthetic data hash value', Hash(dataframe), '\n')
        head(dataframe)
    }
    ds
}

TestScenarios <- function(data, actual.coefficients, control) {
    # return a data.frame containing the results of testing on each of the 4 scenarios
    # The test is to determine the error on the January transaction after training for 60 days
    # The model formula is price ~ <predictors>

    Scenario <- function(case.name) {
        # translate local scenario name into name used by MakeModelLinear
        switch( case.name
               ,'assessor' = 'assessor'
               ,'avm w/o assessment' = 'avm'
               ,'avm w/ assessment' = 'avm'
               ,'mortgage' = 'mortgage'
               )
    }

    Predictors <- function(case.name) {
        # return the predictors that we use for the specified scenario
        switch( case.name
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


    all.data.indices <- rep(TRUE, nrow(data))
    all <- NULL
    for (case.name in c('assessor', 'avm w/o assessment', 'avm w/ assessment', 'mortgage')) {
        cat('scenario', case.name, '\n')
        #browser()
        CvModel <- MakeModelLinear( scenario = Scenario(case.name)
                                   ,response = 'price'
                                   ,predictors = Predictors(case.name)
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
        if (FALSE && case.name == 'assessor') {
            # the coefficients should be close to what was used to generate the data
            CheckCoefficients(ExtractCoefficients(cv.result), actual.coefficients)
        }
        assess <- Assess(cv.result)
        next.row <- data.frame( stringsAsFactors = FALSE
                               ,scenario = case.name
                               ,rmse = assess$rmse
                               )
        all <- IfThenElse(is.null(all), next.row, rbind(all, next.row))
    }
    all
}

Experiment <- function(assessment.bias.name, assessment.relative.sd.name, control) {
    # return data frame with these columns
    # $scenario = name of scenario, in 'assessor', 'avm w/o assessment', 'avm w/ assessment', 'mortgage'
    # $rmse = error from a log-log model, trained for 60 days and testing on Jan 2008 data

    cat('start Experiment', assessment.bias.name, assessment.relative.sd.name, '\n')
    #browser()

    sd <- MakeSyntheticData(assessment.bias.name, assessment.relative.sd.name, control)
    df <- TestScenarios(sd$data, sd$coefficients)
    df # return data frame containing result of test, one row per test
}


Sweep <- function(f, assessment.bias.names, assessment.relative.sd.names, control) {
    # return data.frame containing a row for each element in cross product of list1 and list2
    # and scenario and rmse for that scenario on appropriate synthetic data
    #cat('Sweep\n'); browser()

    # build up a data.frame
    all <- NULL
    for (assessment.bias.name in assessment.bias.names) {
        for (assessment.relative.sd.name in assessment.relative.sd.names) {
            one <- f(assessment.bias.name, assessment.relative.sd.name, control)
            new.row <- data.frame( stringsAsFactors = FALSE
                                  ,assessment.bias.name = assessment.bias.name
                                  ,assessment.relative.sd.name = assessment.relative.sd.name
                                  ,scenario = one$scenario
                                  ,rmse = one$rmse
                                  )
            all <- if(is.null(all)) new.row else rbind(all, new.row)
            if (control$testing) break
        }
        if (control$testing) break
    }
    all
}

Main <- function() {
    #cat('start Main'); browser()

    path.output = '../data/v6/output/'
    me <- 'e-avm-variants-synthetic-data' 
    market.sd.fraction = .2
    control <- list( response = 'price'
                    ,path.out.log = paste0(path.output, me, '.log')
                    ,path.out.save = paste0(path.output, me, '.rsave')
                    ,obs.per.day = 10
                    ,inflation.annual.rate = .10
                    ,testing.period = list( first.date = as.Date('2008-01-01')
                                           ,last.date = as.Date('2008-01-31')
                                           )
                    ,market.bias = 1
                    ,market.sd.fraction = market.sd.fraction
                    ,assessment.bias.names = c('zero', 'lower', 'higher')
                    ,assessment.bias.values = list( lower = .8
                                                   ,zero  = 1
                                                   ,higher = 1.2
                                                   )
                    ,assessment.relative.sd.names = c('nearzero', 'lower', 'same', 'higher')
                    ,assessment.relative.sd.values = list( nearzero = .01
                                                          ,lower = .5 * market.sd.fraction
                                                          ,same = market.sd.fraction
                                                          ,higher = 2 * market.sd.fraction
                                                          )
                    ,num.training.days = 60
                    ,random.seed = 123
                    ,testing = FALSE
                    )

    #cat('in Main\n'); browser()
    InitializeR(duplex.output.to = control$path.out.log, random.seed = control$random.seed)
    print(control)

    result.df <- Sweep( f = Experiment
                       ,assessment.bias.names = control$assessment.bias.names
                       ,assessment.relative.sd.names = control$assessment.relative.sd.names
                       ,control = control
                       )


    #cat('main, after Sweep\n'); browser()
    save(control, result.df, file = control$path.out.save)

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
