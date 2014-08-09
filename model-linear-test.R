# model-linear-test.R
# main program to test ModelLinear
# Approach: use synthetic data

source('Assess.R')
source('DataSynthetic.R')
source('InitializeR.R')
source('MakeModelLinear.R')
source('Printf.R')

Main <- function() {
    #cat('start Main\n'); browser()
    first.date <- as.Date('2007-01-01')
    last.date <- as.Date('2008-01-31')
    obs.per.day <- 10
    #obs.per.day <- 1; cat('TESTING\n')
    ds <- DataSynthetic( obs.per.day = obs.per.day
                        ,first.date = first.date
                        ,last.date = last.date
                        ,inflation.annual.rate = 0
                        )
    data <- ds$data
    coefficients <- ds$coefficients

    #cat('in Main\n'); browser()
    
    Run <- function(name, ModelCv) {
        # return RMSE for trained and tested ModelCv (that uses the CrossValidate API)
        PrintFitted <- function(fitted) {
            CoefficientsToString <- function(one.fitted) {
                # return string
                #cat('start CoefficientsToString\n'); print(str(one.fitted)); browser()
                coefficients <- one.fitted$coefficients
                ToString <- function(name) {
                    value <- coefficients[[name]]
                    result <- 
                        switch( name
                               ,"(Intercept)" = sprintf('%s %7.0f', name, value)
                               ,has.poolTRUE = sprintf('%s %5f', name, value)
                               ,sprintf('%s %7.1f', name, value)
                               )
                    result
                }

                s <- Map(ToString, names(coefficients))
                reduction <- Reduce(paste, s, '')
                reduction
            }
            PrintDateCoefficients <- function(name) {
                #cat('start PrintDateCoefficients\n'); print(name); browser()
                one.fitted <- fitted[[name]]
                Printf('%s: %s\n', as.character(name), CoefficientsToString(one.fitted))
            }

            #cat('start PrintFitted\n'); browser()
            if (is.null(fitted$coefficients)) {
                # a nested structure with many fitted models
                Map(PrintDateCoefficients, names(fitted))
            } else {
                Printf('%s\n', CoefficientsToString(fitted))
            }
        }

        #cat('start Run\n'); browser()
        model.result <- ModelCv( data = data
                                ,training.indices = 1:nrow(data)
                                ,testing.indices = 1:nrow(data)
                                )
        assess <- Assess(model.result)
        fitted <- model.result$fitted

        cat('\n************** Result for', name, '\n')
        cat('mean price', mean(data$price), '\n')
        print(str(assess))
        #print(model.result)
        PrintFitted(fitted)
        print('Actual coefficients\n'); print(coefficients)

        list( name = name
             ,rmse = assess$rmse
             )
    }

    ParseAndRun <- function(lst) {
        #cat('start ParseAndRun\n'); print(lst); browser()
        run <- Run(lst$name, lst$Model)
        list( scenario = lst$scenario
             ,response.name = lst$response.name
             ,predictors.name = lst$predictors.name
             ,name = run$name
             ,rmse = run$rmse
             )
    }

    NameAndModel <- function(scenario, response.name, predictors.name) {

        Response <- function(response.name) {
            switch( response.name
                   ,level = 'price'
                   ,log = 'log.price'
                   ,stop('bad response.name')
                   )
        }

        Predictors <- function(predictors.name) {
            #cat('start Predictors', predictors.name, '\n'); browser()
            switch( predictors.name
                   ,level = c('land.size', 'latitude', 'has.pool')
                   ,levelAssessment = c('land.size', 'latitude', 'has.pool', 'assessment')
                   ,log = c('log.land.size', 'latitude', 'has.pool')
                   ,logAssessment = c('log.land.size', 'latitude', 'has.pool', 'log.assessment')
                   ,stop('bad predictors.name')
                   )
        }
        
        testing.period <- list(first.date = as.Date('2008-01-01'), last.date = as.Date('2008-01-31'))
        num.training.days <- 60
        list( name = paste(scenario, response.name, predictors.name)
             ,scenario = scenario
             ,response.name = response.name
             ,predictors.name = predictors.name
             ,Model = MakeModelLinear( scenario = scenario
                                      ,response = Response(response.name)
                                      ,predictors = Predictors(predictors.name)
                                      ,testing.period = testing.period
                                      ,data = data
                                      ,num.training.days = num.training.days
                                      ,verbose.model = TRUE
                                      )
             )
    }
    
    all.results <- 
        Map( ParseAndRun
            ,list( NameAndModel('assessor', 'log', 'level')
                  ,NameAndModel('avm', 'log', 'levelAssessment')
                  ,NameAndModel('avm', 'log', 'level')
                  ,NameAndModel('mortgage', 'log', 'levelAssessment')

                  ,NameAndModel('assessor', 'log', 'log')
                  ,NameAndModel('avm', 'log', 'logAssessment')
                  ,NameAndModel('avm', 'log', 'log')
                  ,NameAndModel('mortgage', 'log', 'logAssessment')

                  ,NameAndModel('assessor', 'level', 'level')
                  ,NameAndModel('avm', 'level', 'levelAssessment')
                  ,NameAndModel('avm', 'level', 'level')
                  ,NameAndModel('mortgage', 'level', 'levelAssessment')

                  ,NameAndModel('assessor', 'level', 'log')
                  ,NameAndModel('avm', 'level', 'logAssessment')
                  ,NameAndModel('avm', 'level', 'log')
                  ,NameAndModel('mortgage', 'level', 'logAssessment')
                  )
            )
    PrintResult <- function(result) {
        Printf('use case: %40s  RMSE: %.0f\n', result$name, result$rmse)
    }

    PrintTable <- function(all.results) {
        #cat('start PrintTable\n'); browser()
        cat('RMSE\n')

        format.header <- '%19s | %15s %15s %15s %15s\n'
        format.data <- '%19s | %15.0f %15.0f %15.0f %15.0f\n'

        Printf(format.header, 'scenario', 'level-level', 'level-log', 'log-level', 'log-log')

        Rmse <- function(scenario, response.name, predictors.name) {
            for (result in all.results) {
                if (result$scenario == scenario &&
                    result$response.name == response.name &&
                    result$predictors.name == predictors.name) {
                    return(result$rmse)
                }
            }
            cat('in Rmse; about to fail', scenario, response.name, predictors.name, '\n'); browser()
            stop('bad')
        }


        Printf( format.data
               ,'assessor'
               ,Rmse('assessor', 'level', 'level'), Rmse('assessor', 'level', 'log')
               ,Rmse('assessor', 'log', 'level'), Rmse('assessor', 'log', 'log')
               )
        Printf( format.data
               ,'avm w/o assessment'
               ,Rmse('avm', 'level', 'level'), Rmse('avm', 'level', 'log')
               ,Rmse('avm', 'log', 'level'), Rmse('avm', 'log', 'log')
               )
        Printf( format.data
               ,'avm w/ assessment'
               ,Rmse('avm', 'level', 'levelAssessment'), Rmse('avm', 'level', 'logAssessment')
               ,Rmse('avm', 'log', 'levelAssessment'), Rmse('avm', 'log', 'logAssessment')
               )
        Printf( format.data
               ,'mortgage'
               ,Rmse('mortgage', 'level', 'levelAssessment'), Rmse('mortgage', 'level', 'logAssessment')
               ,Rmse('mortgage', 'log', 'levelAssessment'), Rmse('mortgage', 'log', 'logAssessment')
               )
        

    }



    #cat('about to PrintResults\n'); browser()
    cat('\n\n\n************* SUMMARY ******************\n')
    Map(PrintResult, all.results)
    PrintTable(all.results)
    

    #cat('end of Main\n'); browser()
}

InitializeR()
Main()
