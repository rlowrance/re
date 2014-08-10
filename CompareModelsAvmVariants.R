CompareModelsAvmVariants <- function(control, transformed.data) {
    # execute AvmVariants command as part of the compare-models main program
    # compare accuracy of models
    # scenarios: assessor, avm w/assessment, avm w/o assessment, mortgage
    # for one time period and form:
    # form: log-level
    # time period: Jan 2008

    cat('start CompareModelsAvmVariants'); print(control); browser()
    stopifnot(control$choice == 'NONE')  # no variants for now

    # setup call to CrossValidate to do the comparisons
    testing.period <- list(first.date = as.Date('2008-01-01'), last.date = as.Date('2008-01-31'))
    num.training.days <- 60
    response = 'log.price'

    MakeAssessorModel <- function() {
        # return linear model for the assessor scenario
        Model <- MakeModelLinear( scenario = 'assessor'
                                 ,testing.period = testing.period
                                 ,data = transformed.data
                                 ,num.training.days = num.training.days
                                 ,response = response
                                 ,predictors = Predictors( set = 'Chopra'
                                                          ,form = 'level'
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
                                 ,response = response
                                 ,predictors = Predictors( set = 'Chopra'
                                                          ,form = 'level'
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
                                 ,response = response
                                 ,predictors = Predictors( set = 'Chopra'
                                                          ,form = 'level'
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
    nfolds <- 10
    #nfolds <- 2; print('TESTING')
             
    cv.result <-  # a list $best.model.index $all.assessment
        CrossValidate( data = transformed.data
                      ,nfolds = nfolds
                      ,Models = parallel$Models
                      ,Assess = Assess
                      ,experiment = parallel$experiment.names
                      )

    # report on results
    cat('report CompareModelsAvmVariants\n'); browser()
    
    fold.assessment <- cv.result$fold.assessment

    MeanRmse <- function(model.index) {
        #cat('start MeanRmse', model.index, '\n'); browser()
        in.model <- fold.assessment$model.index == model.index
        fold.rmse <- fold.assessment$assessment.rmse[in.model]
        result <- mean(fold.rmse)
        result
    }

    experiment.result <- data.frame( stringsAsFactors = FALSE
                                    ,experiment.name = parallel$experiment.names
                                    ,mean.RMSE = sapply(1:length(parallel$Models), MeanRmse)
                                    )
    print('Experiment Results\n')
    print(experiment.result)
    save(cv.result, experiment.result, file = control$path.out.driver.result)
}
