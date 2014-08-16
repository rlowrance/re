# e-avm-variants-loglevel10.R
# main program to produce file OUTPUT/e-avm-variants-loglevel10.rsave
# issue resolved: The AVM model performs better than the assessor model. How much
# of the better performance is caused by using the assessment?
# Approach: Use k-fold cross validation to compare estimated generalization errors for
# model variants


# specify input files, which are splits of OUTPUT/transactions-subset
# The splits are makefile dependencies
split.names <- list( predictor.names = c(# continuous size positive
                                         'land.square.footage'
                                         ,'living.area'
                                         # continuous size nonnegative
                                         ,'bedrooms'
                                         ,'bathrooms'
                                         ,'parking.spaces'
                                         # continuous non size
                                         ,'median.household.income'
                                         ,'year.built'
                                         ,'fraction.owner.occupied'
                                         ,'avg.commute.time'
                                         # discrete
                                         ,'factor.is.new.construction'
                                         ,'factor.has.pool'
                                         )
                    ,assessment.names = c( 'improvement.value'
                                          ,'land.value'
                                          ,'fraction.improvement.value'
                                          )
                    ,other = c(# dates
                               'saleDate'
                               ,'recordingDate'
                               # prices
                               ,'price'
                               ,'log.price'
                               # apn
                               ,'apn'
                               )
                    )

library(devtools)
load_all('/Users/roy/Dropbox/lowranceutilitiesr')
load_all('/Users/roy/Dropbox/lowrancerealestater')

DefineModelsNames <- function(control, data) {
    # build parallel arrays
    #cat('start DefineModelsNames\n'); browser()
    MakeModel <- function(scenario, predictors) {
        #cat('start MakeModel', scenario, '\n'); browser()
        Model <- MakeModelLinear( scenario = scenario
                                 ,predictors = predictors
                                 # other args are common
                                 ,response = 'log.price'
                                 ,testing.period = control$testing.period
                                 ,data = data
                                 ,num.training.days = control$num.training.days
                                 ,verbose = TRUE
                                 )
    }

    Models <- list( MakeModel('assessor', control$predictors.without.assessment)
                   ,MakeModel('avm', control$predictors.without.assessment)
                   ,MakeModel('avm', control$predictors.with.assessment)
                   ,MakeModel('mortgage', control$predictors.with.assessment)
                   )
    names <- c( 'assessor with assessment'
               ,'avm without assessment'
               ,'avm with assessment'
               ,'mortgage with assessment'
               )
             
    models.names <- list(Models = Models ,names = names)
    models.names
}
 
ExperimentResult <- function(cv.result, experiment.names) {
    #cat('start ExperimentResult\n'); browser()
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

    num.models <- max(fold.assessment$model.index)
    experiment.result <- data.frame( stringsAsFactors = FALSE
                                    ,experiment.name = experiment.names
                                    ,mean.RMSE = sapply(1:num.models, MeanRmse)
                                    ,median.RMedianSE = sapply(1:num.models, MedianRmse)
                                    )

    experiment.result
}

Main <- function(split.names) {
    #cat('start Main'); browser()

    path.output = '../data/v6/output/'
    me <- 'e-avm-variants-loglevel10' # response/predictors.form/nfolds
    control <- list( response = 'log.price'
                    ,path.in.base = paste0(path.output, 'transactions-subset1')
                    ,path.out.log = paste0(path.output, me, '.log')
                    ,path.out.save = paste0(path.output, me, '.rsave')
                    ,predictors.without.assessment = c(split.names$predictor.names)
                    ,predictors.with.assessment = c( split.names$predictor.names
                                                    ,split.names$assessment.names)
                    ,response = 'log.price'
                    ,split.names = c( split.names$predictor.names
                                     ,split.names$assessment.names
                                     ,split.names$other)
                    ,nfolds = 10
                    ,testing.period = list( first.date = as.Date('2008-01-01')
                                           ,last.date = as.Date('2008-01-31')
                                           )
                    ,num.training.days = 60
                    )

    InitializeR(duplex.output.to = control$path.out.log)
    print(control)

    data <- ReadTransactionSplits( path.in.base = control$path.in.base
                                  ,split.names = control$split.names
                                  ,verbose = TRUE
                                  )
    
    models.names <- DefineModelsNames( control = control
                                      ,data = data)
    cv.result <-  # 
        CrossValidate( data = data
                      ,nfolds = control$nfolds
                      ,Models = models.names$Models
                      ,Assess = Assess
                      ,experiment = models.names$experiment.names
                      )
    experiment.result <- ExperimentResult( cv.result = cv.result
                                          ,experiment.names = models.names$names
                                          )

    # print results of the experiment
    Printf( 'Experiment Results for reponse variable %s predictors %s nfolds %d\n'
           ,control$response
           ,control$predictors
           ,control$nfolds
           )
    
    print(experiment.result)

    # save results
    description <- 'Cross Validation Result\nLog-Level model\nPredict Jan 2008 transactions using 60 days of training data'
    save(description, control, cv.result, experiment.result, file = control$path.out.save)

    print(control)
}



Main(split.names)
cat('done\n')
