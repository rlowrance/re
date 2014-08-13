# model-linear-test.R
# main program to test ModelLinear
# Approach: use synthetic data

source('Assess.R')
source('DataSynthetic.R')
source('InitializeR.R')
source('MakeModelLinear.R')
source('ModelLinearTestPrintAllResults.R')
source('Printf.R')

Experiment <- function(assessment.bias, relative.assessment.accuracy) {
    # return data frame with these columns
    # $scenario = name of scenario, in 'assessor', 'avm w/o assessment', 'avm w/ assessment', 'mortgage'
    # $rmse = error from a log-log model, trained for 60 days and testing on Jan 2008 data
    #cat('start Experiment', assessment.bias, relative.assessment.accuracy, '\n'); browser()

    market.sd = .1
    data <- DataSynthetic( obs.per.day = 10
                          ,first.date = as.Date('2007-01-01')
                          ,last.date = as.Date('2008-01-31')
                          ,market.bias = 1
                          ,market.sd = market.sd
                          ,assessment.bias = switch( assessment.bias
                                                    ,low = .8
                                                    ,zero = 1
                                                    )
                          ,assessment.sd = switch( relative.assessment.accuracy
                                                  ,more = .5 * market.sd
                                                  ,same = market.sd
                                                  ,less = 2 * market.sd
                                                  )
                          )

    MakeModelLinearScenario <- function(scenario) {
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

    all <- NULL
    for (scenario in c('assessor', 'avm w/o assessment', 'avm w/ assessment', 'mortgage')) {
        #cat('new scenario', scenario, '\n'); browser()
        CvModel <- MakeModelLinear( scenario = MakeModelLinearScenario(scenario)
                                   ,response = 'price'
                                   ,predictors = Predictors(scenario)
                                   ,testing.period = list( first.date = as.Date('2008-01-01')
                                                          ,last.date = as.Date('2008-01-31')
                                                          )
                                   ,data = data
                                   ,num.training.days = 60
                                   ,verbose.model = TRUE
                                   )
        all.data.indices <- 1:nrow(data)
        cv.result <- CvModel( data = data
                             ,training.indices = all.data.indices
                             ,testing.indices = all.data.indices
                             )
        assess <- Assess(cv.result)
        next.row <- data.frame( stringsAsFactors = FALSE
                               ,scenario = scenario
                               ,rmse = assess$rmse
                               )
        all <- if (is.null(all)) next.row else rbind(all, next.row)
    }

    all
    
}

Sweep <- function(f, list1, list2) {
    # return data.frame containing a row for each element in cross product of list1 and list2
    # and scenario and rmse for that scenario on appropriate synthetic data
    #cat('Sweep\n'); browser()
    all <- NULL
    for (element1 in list1) {
        for (element2 in list2) {
            one <- f(element1, element2)
            new.row <- data.frame( stringsAsFactors = FALSE
                                  ,assessment.bias = element1
                                  ,assessment.relative.error = element2
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
    
    cat('start Main\n'); browser()
    result.df <- Sweep( Experiment
                            ,c('low', 'zero')
                            ,c('more', 'same', 'less')
                            )
    save(result.df, file = '../data/v6/output/model-linear-test.rsave')
    ModelLinearTestPrintAllResults(result.df)


    return(result.df)
    
    # OLD BELOW ME
                    
    experiment.result <- list( Experiment(bias = 'no', accuracy = 'perfect')
                              ,Experiment(bias = 'no', accuracy = 'more')
                              ,Experiment(bias = 'no', accuracy = 'equal')
                              ,Experiment(bias = 'no', accuracy = 'less')

                              ,Experiment(bias = 'less', accuracy = 'perfect')
                              ,Experiment(bias = 'less', accuracy = 'more')
                              ,Experiment(bias = 'less', accuracy = 'equal')
                              ,Experiment(bias = 'less', accuracy = 'less')
                              )

    PrintExperimentResult <- function(experiment.result) {
    }

    Map(PrintExperimentResult, experiment.result)

    save(experiment.result, file = '../data/v6/output/model-linear-test.rsave')



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

    # save to output
    print('all.results\n')
    print(all.results)
    save(all.results, file='../data/V6/output/model-linear-test.rsave')

    PrintResult <- function(result) {
        Printf('use case: %40s  RMSE: %.0f\n', result$name, result$rmse)
    }



    #cat('about to PrintResults\n'); browser()
    cat('\n\n\n************* SUMMARY ******************\n')
    Map(PrintResult, all.results)
    ModelLinearTestPrintAllResults(all.results)
    #PrintTable(all.results)
    

    #cat('end of Main\n'); browser()
}

InitializeR(duplex.output.to = '../data/v6/output/model-linear-test-log.txt')
Main()
