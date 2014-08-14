CompareModelsAvmVariants <- function(control, transformed.data) {
    # execute AvmVariants command as part of the compare-models main program
    # compare accuracy of models
    # scenarios: assessor, avm w/assessment, avm w/o assessment, mortgage
    # for one time period and form:
    # form: log-level
    # time period: Jan 2008

    #cat('start CompareModelsAvmVariants'); print(control); browser()
    # coding: RESPONSE.PREDICTORS.NFOLDS
    option <- switch( control$choice
                     ,loglevel10 = list(response = 'log.price', predictors = 'level', nfolds = 10)
                     ,linearlinear10 = list(response = 'log', predictors = 'level', nfolds = 10)
                     ,loglevel50 = list(response = 'log.price', predictors = 'level', nfolds = 50)
                     ,stop('bad control$choice')
                     )

    # setup call to CrossValidate to do the comparisons
    testing.period <- list(first.date = as.Date('2008-01-01'), last.date = as.Date('2008-01-31'))
    num.training.days <- 60

    MakeAssessorModel <- function() {
        # return linear model for the assessor scenario
        Model <- MakeModelLinear( scenario = 'assessor'
                                 ,testing.period = testing.period
                                 ,data = transformed.data
                                 ,num.training.days = num.training.days
                                 ,response = option$response
                                 ,predictors = Predictors( set = 'ChopraNoGeocoding'
                                                          ,form = option$predictors
                                                          ,center = FALSE
                                                          ,useAssessment = FALSE
                                                          )
                                 ,verbose.model = TRUE
                                 )
    }

    MakeAvmModel <- function(use.assessment) {
        # return linear model for the assessor scenario
        Model <- MakeModelLinear( scenario = 'avm'
                                 ,testing.period = testing.period
                                 ,data = transformed.data
                                 ,num.training.days = num.training.days
                                 ,response = option$response
                                 ,predictors = Predictors( set = 'ChopraNoGeocoding'
                                                          ,form = option$predictors
                                                          ,center = FALSE
                                                          ,useAssessment = use.assessment
                                                          )
                                 ,verbose.model = TRUE
                                 )
    }

    MakeMortgageModel <- function() {
        # return linear model for the assessor scenario
        Model <- MakeModelLinear( scenario = 'mortgage'
                                 ,testing.period = testing.period
                                 ,data = transformed.data
                                 ,num.training.days = num.training.days
                                 ,response = option$response
                                 ,predictors = Predictors( set = 'ChopraNoGeocoding'
                                                          ,form = option$predictors
                                                          ,center = FALSE
                                                          ,useAssessment = FALSE
                                                          )
                                 ,verbose.model = TRUE
                                 )
    }

    # build 2 parallel lists
    parallel <- 
        list( Models = list(assessor = MakeAssessorModel()
                            ,avmNoAssessment = MakeAvmModel(use.assessment = FALSE)
                            ,avmWithAssessment = MakeAvmModel(use.assessment = TRUE)
                            ,mortgage = MakeMortgageModel()
                            )
             ,experiment.names = c( 'assessor'
                                   ,'avm without assessment'
                                   ,'avm with assessment'
                                   ,'mortgage'
                                   )
             )
             
    cv.result <-  # a list $best.model.index $all.assessment
        CrossValidate( data = transformed.data
                      ,nfolds = option$nfolds
                      ,Models = parallel$Models
                      ,Assess = Assess
                      ,experiment = parallel$experiment.names
                      )

    # report on results
    #cat('report CompareModelsAvmVariants\n'); browser()
    
    fold.assessment <- cv.result$fold.assessment

    MeanRmse <- function(model.index) {
        #cat('start MeanRmse', model.index, '\n'); browser()
        in.model <- fold.assessment$model.index == model.index
        fold.error <- fold.assessment$assessment.rmse[in.model]
        result <- mean(fold.error)
        result
    }

    MedianRmse <- function(model.index) {
        #cat('start Median Rmse', model.index, '\n'); browser()
        in.model <- fold.assessment$model.index == model.index
        fold.error <- fold.assessment$assessment.root.median.squared.error[in.model]
        result <- median(fold.error)
        result
    }

    experiment.result <- data.frame( stringsAsFactors = FALSE
                                    ,experiment.name = parallel$experiment.names
                                    ,mean.RMSE = sapply(1:length(parallel$Models), MeanRmse)
                                    ,median.RMedianSE = sapply(1:length(parallel$Models), MedianRmse)
                                    )
    Printf( 'Experiment Results for reponse variable %s predictors %s nfolds %d\n'
           ,option$response
           ,option$predictors
           ,option$nfolds
           )
    
    print(experiment.result)
    description <- 'Cross Validation Result\nLog-Level model\nPredict Jan 2008 transactions using 60 days of training data'
    save(description, control, cv.result, experiment.result, file = control$path.out.driver.result)
}
