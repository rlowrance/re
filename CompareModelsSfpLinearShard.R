CompareModelsSfpLinearShard <- function(control, transformed.data, PathShard) {
    # create the shard specified in control$index
    
    MyPredictors <- function(scenario.name, predictors.name) {
        result <- switch( scenario.name
                         ,mortgage =  # fall through 
                         ,avm      = Predictors( set = 'Chopra'
                                                ,form = predictors.name
                                                ,center = FALSE
                                                ,useAssessment = TRUE
                                                )
                         ,assessor  = Predictors( set = 'Chopra'
                                                ,form = predictors.name
                                                ,center = FALSE
                                                ,useAssessment = FALSE
                                                )
                         )
        result
    }

    MyResponse <- function(response.name) {
        result <- switch( response.name
                         ,level = 'price'
                         ,log   = 'log.price'
                         )
       result
    }

    DetermineBestNumTrainingDays <- function( scenario.name
                                             ,response.name
                                             ,predictors.name
                                             ,testing.period
                                             ,transformed.data
                                             ,experiment.name) {
        # use cross validation to determine best number of testing months
        #cat('starting CompareModelsSfpLinear::DetermineBestNumTrainingMonths', experiment.name, '\n'); browser()

        my.response <- MyResponse(response.name)
        my.predictors <- MyPredictors(scenario.name, predictors.name)


        ModelIndexToTrainingDays <- function(model.index) {
            #cat('starting ModelIndexToTrainingDays', model.index, '\n'); browser()
            result <- 30 * model.index
            result
        }

        MyModel <- function(model.index) {
            #cat('starting MyModel', model.index, '\n'); browser()

            Model <- MakeModelLinear( testing.period = testing.period
                                     ,data = transformed.data
                                     ,num.training.days = ModelIndexToTrainingDays(model.index)
                                     ,scenario = scenario.name
                                     ,response = my.response
                                     ,predictors = my.predictors
                                     ,verbose.model = FALSE
                                     )
            Model
        }

        num.models <- 10
        Models <- lapply(1:num.models, MyModel)

        if (DEBUGGING) {
            print('DEBUGGING 2 folds RERUN')
            control$nfolds <- 2
        }
        cv.result <- CrossValidate( data = transformed.data
                                   ,nfolds = control$nfolds
                                   ,Models = Models
                                   ,Assess = Assess
                                   ,experiment = experiment.name
                                   )

        best.model.index <- cv.result$best.model.index
        best.num.training.days <- ModelIndexToTrainingDays(best.model.index)
        best.num.training.days
    }

    Evaluate <- function( scenario.name
                         ,response.name
                         ,predictors.name
                         ,testing.period
                         ,num.training.days
                         ,transformed.data
                         ,experiment.name) {
        # fit and predict; return RMSE, fraction with 10 percent, and coverage
        #cat('starting CompareModelsSfpLinear::Evaluate', experiment.name, '\n'); browser()
        verbose <- TRUE

        my.response <- MyResponse(response.name)
        my.predictors <- MyPredictors(scenario.name, predictors.name)

        Model <- MakeModelLinear( scenario = scenario.name
                                 ,testing.period = testing.period
                                 ,data = transformed.data
                                 ,num.training.days = num.training.days
                                 ,response = my.response
                                 ,predictors = my.predictors
                                 ,verbose.model = verbose
                                 )

        # include all transactions in possible training and testing sets
        n <- nrow(transformed.data)
        my.training.indices <- 1:n
        my.testing.indices <- 1:n

        model.result <- Model( data=transformed.data
                              ,training.indices = my.training.indices
                              ,testing.indices = my.testing.indices
                              )
        assess <- Assess(model.result)
        if (verbose) {
            print('evaluation')
            print(experiment.name)
            print(assess)
        }
        assess
    }

    # BODY BEGINS HERE

    #cat('starting CompareModelsSfpLinearShard\n'); browser()
    DEBUGGING <- FALSE
    all.row <- NULL
    testing.period.index <- 0
    control.index <- as.numeric(control$index)  # convert from chr
    for (testing.period in TestingPeriods()) {
        testing.period.index <- testing.period.index + 1
        if (testing.period.index != control.index) {
            next
        }
        for (scenario.name in list('assessor', 'avm', 'mortgage')) {
            for (response.name in list('log', 'level')) {
                for (predictors.name in list('log', 'level')) {
                    experiment.name <- 
                        sprintf('%s %s %s %s %s',
                                scenario.name, response.name, predictors.name, 
                                testing.period$first.date, testing.period$last.date)
                    Printf('experiment: %s\n', experiment.name)
                    if (DEBUGGING) {
                        if (scenario.name != 'avm' |
                            response.name != 'log' |
                            predictors.name != 'level') {
                            print('DEBUGGING ONLY assessor log level: RERUN')
                            next
                        }
                    }
                    #cat('in SpfLinearShard\n'); browser()

                    best.num.training.days <- 
                        DetermineBestNumTrainingDays( scenario.name = scenario.name
                                                     ,response.name = response.name
                                                     ,predictors.name = predictors.name
                                                     ,testing.period = testing.period
                                                     ,transformed.data = transformed.data
                                                     ,experiment.name = experiment.name
                                                     )
                    # fit and predict using the best model
                    evaluation <- 
                        Evaluate( scenario.name = scenario.name
                                 ,response.name = response.name
                                 ,predictors.name = predictors.name
                                 ,testing.period = testing.period
                                 ,num.training.days = best.num.training.days
                                 ,transformed.data = transformed.data
                                 ,experiment.name = experiment.name
                                 )

                    next.row <- data.frame( stringsAsFactors = FALSE
                                           ,scenario.name = scenario.name
                                           ,response.name = response.name
                                           ,predictors.name = predictors.name
                                           ,testing.period.index = testing.period.index
                                           ,testing.period.first.date = testing.period$first.date
                                           ,testing.period.last.date = testing.period$last.date
                                           ,best.num.training.days = best.num.training.days
                                           ,rmse = evaluation$rmse
                                           ,within.10.percent = evaluation$within.10.percent
                                           ,coverage = evaluation$coverage
                                           )
                    all.row <- IfThenElse(is.null(all.row), next.row, rbind(all.row, next.row))
                }
            }
        }
    }

    path.out <- PathShard(control, control.index)
    save(all.row, file=path.out)
    cat('wrote', path.out)
}
