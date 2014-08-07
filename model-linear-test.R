# model-linear-test.R
# main program to test ModelLinear
# Approach: use synthetic data

source('Assess.R')
source('DataSynthetic.R')
source('InitializeR.R')
source('MakeModelLinear.R')
source('Printf.R')

PrefixLog <- function(var) {
    #cat('start PrefixLog', var, '\n'); browser()
    result <- sprintf('log.%s', var)
    result
}

TransformSizeToLog <- function(vars) {
    #cat('start TransformSizeToLog\n'); browser()
    Transform <- function(var) {
        IfThenElse(var == 'land.size', PrefixLog(var), var)
    }
    result <- Map(Transform, vars)
    result
}

ModelAssessorLevelLevel <- function(data, testing.period, response, predictors, num.training.days) {
    #cat('start MakeAssessorLogLevel\n'); browser()
    ModelCv <- MakeModelLinear( scenario = 'assessor'
                               ,testing.period = testing.period
                               ,data = data
                               ,num.training.days = num.training.days
                               ,response = response
                               ,predictors = predictors
                               ,verbose.model = FALSE
                               )
    ModelCv
}

ModelAssessorLogLevel <- function(data, testing.period, response, predictors, num.training.days) {
    #cat('start MakeAssessorLogLevel\n'); browser()
    ModelCv <- MakeModelLinear( scenario = 'assessor'
                               ,testing.period = testing.period
                               ,data = data
                               ,num.training.days = num.training.days
                               ,response = PrefixLog(response)
                               ,predictors = predictors
                               ,verbose.model = FALSE
                               )
    ModelCv
}

ModelAvmLevelLevel <- function(data, testing.period, response, predictors, num.training.days) {
    #cat('start MakeAvmLevelLevel\n'); browser()
    ModelCv <- MakeModelLinear( scenario = 'avm'
                               ,testing.period = testing.period
                               ,data = data
                               ,num.training.days = num.training.days
                               ,response = response
                               ,predictors = c(predictors, 'true.value')
                               ,verbose.model = FALSE
                               )
    ModelCv
}

ModelAvmLevelLevelNoAssessment <- function(data, testing.period, response, predictors, num.training.days) {
    #cat('start MakeAvmLevelLevelNoAssessment\n'); browser()
    ModelCv <- MakeModelLinear( scenario = 'avm'
                               ,testing.period = testing.period
                               ,data = data
                               ,num.training.days = num.training.days
                               ,response = response
                               ,predictors = predictors
                               ,verbose.model = FALSE
                               )
    ModelCv
}

ModelMortgageLevelLevel <- function(data, testing.period, response, predictors, num.training.days) {
    #cat('start MakeMortgageLevelLevel\n'); browser()
    ModelCv <- MakeModelLinear( scenario = 'mortgage'
                               ,testing.period = testing.period
                               ,data = data
                               ,num.training.days = num.training.days
                               ,response = response
                               ,predictors = c(predictors, 'true.value')
                               ,verbose.model = FALSE
                               )
    ModelCv
}

ModelResult <- function(ModelMaker, testing.period, response, predictors, num.training.days, data) {
    ModelCv <- ModelMaker( data = data
                          ,testing.period = testing.period
                          ,response = response
                          ,predictors = predictors
                          ,num.training.days = num.training.days
                          )

    training.indices <- 1:nrow(data)
    testing.indices <- 1:nrow(data)
    model.result <- ModelCv( data = data
                            ,training.indices = training.indices
                            ,testing.indices = testing.indices
                            )
    model.result
}

Main <- function() {
    #cat('start Main\n'); browser()
    first.date <- as.Date('2007-01-01')
    last.date <- as.Date('2008-12-31')
    obs.per.day <- 10
    #obs.per.day <- 1; cat('TESTING\n')
    ds <- DataSynthetic( obs.per.day = obs.per.day
                        ,first.date = first.date
                        ,last.date = last.date
                        )
    data <- ds$data
    coefficients <- ds$coefficients

    cat('in Main\n'); browser()
    testing.period <- list(first.date = as.Date('2008-01-01'), last.date = as.Date('2008-01-31'))
    response = 'price'
    predictors = c('recordingDate', 'land.size', 'latitude', 'has.pool')
    num.training.days <- 60
    
    Run <- function(name, ModelMaker) {
        # return RMSE for trained and tested ModelMaker
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
        model.result <- ModelResult( ModelMaker = ModelMaker
                                    ,testing.period = testing.period
                                    ,response = response
                                    ,predictors = predictors
                                    ,num.training.days = num.training.days
                                    ,data = data
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

    Accumulate <- function(left, right) {
        name <- right[[1]]
        Model <- right[[2]]
        run <- Run(name, Model)
        ListAppend(left, run)
    }

    all.results <- 
        Reduce( Accumulate
               ,list( list('assessor level level', ModelAssessorLevelLevel)
                     ,list('avm level level', ModelAvmLevelLevel)
                     ,list('avm level level no assessment', ModelAvmLevelLevelNoAssessment)
                     ,list('mortgage level level', ModelMortgageLevelLevel)
                     )
               ,NULL
               )

    PrintResult <- function(result) {
        Printf('use case: %40s  RMSE: %.0f\n', result$name, result$rmse)
    }

    #cat('about to PrintResults\n'); browser()
    Map(PrintResult, all.results)
    

    #cat('end of Main\n'); browser()
}

InitializeR()
Main()
