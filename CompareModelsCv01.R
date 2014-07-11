CompareModelsCv01 <- function(testing.period, transformed.data) {
    # define models for experiment: assessor linear log-log form chopra
    # Per Shasha:
    # - also determine if models with high fraction.within.10 were trained with more observations
    #   requires: determining number of observations used for training and analyzing these
    # ARGS
    # testing.period   : list($first.date,$last.date) list of Date 
    #                    first and last dates for the testing period
    # transformed.data : data.frame
    # RETURN list(Model=<list of functions>, description=<list of char vector>)
    # $Model       : list of functions
    # $description : list of chr vectors
    # $Test        : list of functions
    # ModelIndexToTrainingDays : function(model.index) --> number of days in training period
    # where
    #   Model and description are parallel lists such that
    #     Model[[i]]: is a function(data, training.indices, testing.indices)
    #                 --> $actual = <vector of actual prices for the testing period>
    #                     $predicted <vector of predicted prices or NA values> for corresponding transactions
    #     description[[i]]: a vector of lists of chr, a description of the model
    #  Test is a list of functions such that
    #     Test[[j]] is a function(cv.result)
    #               --> $hypothesis : chr scalar, description of the test
    #                   $passed     : logical scalar, TRUE or FALSE
    #                   $support    : any object, provides evidence for $passed

    #cat('starting CompareModelsCv01', testing.period$first.date, testing.period$last.date, nrow(transformed.data), '\n'); browser()

    Require('PredictorsChopraCenteredLogAssessor')
    Require('MakeTestBestModelIndex')
    Require('MakeTestHigherWithinMoreObservations')
    Require('MakeModelLinear')

    MyTrainingDays <- function(model.index) {
        30 * model.index  # 30 days per model index
    }

    my.scenario <- 'assessor'
    my.response.var <- 'log.price'
    my.predictors <- PredictorsChopraCenteredLogAssessor()
    my.predictors.name <- 'chopra centered log assessor'

    MyMakeModel <- function(model.index) {
        Model <- MakeModelLinear(testing.period = testing.period,
                                 data = transformed.data,
                                 num.training.days = MyTrainingDays(model.index),
                                 scenario = my.scenario,
                                 response = my.response.var,
                                 predictors = my.predictors)
        Model
    }

    MyDescription <- function(model.index) {
        # return description of model
        #cat('starting CompareModelsCv02::MyDescription', model.index, '\n'); browser()
        result <- 
            list(scenario = my.scenario,
                 testing.period = testing.period,
                 training.period = sprintf('%d days before Oct 1', MyTrainingDays(model.index)),
                 model = 'ModelLinear',
                 response = my.response.var,
                 predictors = my.predictors.name)
        result
    }


    # assemble outputs
    nModels <- 10
    Model <- lapply(1:nModels, MyMakeModel)
    description <- lapply(1:nModels, MyDescription)
    Test <- list(MakeTestBestModelIndex(expected.best.model.index = 2),
                 MakeTestHigherWithinMoreObservations())

    result <- list( Model = Model
                   ,description = description
                   ,Test = Test
                   ,ModelIndexToTrainingDays = MyTrainingDays
                   )
    result
}
