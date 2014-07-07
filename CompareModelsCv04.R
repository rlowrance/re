CompareModelsCv04 <- function(testing.period, transformed.data) {
    # define models for experiment: compare across scenarios of best of linear models in log-log form
    # ARGS
    # testing.period   : list($first.date,$last.date) list of Date 
    #                    first and last dates for the testing period
    # transformed.data : data.frame
    # RETURN list(Model=<list of functions>, description=<list of char vector>)
    # $Model       : list of functions
    # $description : list of chr vectors
    # $Test        : list of functions
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

    cat('starting CompareModelsCv04', testing.period$first.date, testing.period$last.date, nrow(transformed.data), '\n'); browser()

    Require('PredictorsChopraCenteredLogAssessor')
    Require('PredictorsChopraCenteredLogAvm')
    Require('PredictorsChopraCenteredLogMortgage')
    Require('MakeTestBestModelIndex')
    Require('MakeModelLinear')

    # force args
    testing.period
    transformed.data

    # features of the best models
    best.num.training.days <- list(assessor = 270,  # from CV01
                                   avm      = 60,   # from CV02
                                   mortgage = 150)  # from CV03

    MyMakeModel <- function(model.index) {
        #cat('starting MyMakeModel', model.index, '\n'); browser()
        Model <- switch(model.index,
                        MakeModelLinear(testing.period = testing.period,
                                        data = transformed.data,
                                        num.training.days = best.num.training.days$assessor,
                                        scenario = 'assessor',
                                        response = 'log.price',
                                        predictors = PredictorsChopraCenteredLogAssessor()),
                        MakeModelLinear(testing.period = testing.period,
                                        data = transformed.data,
                                        num.training.days = best.num.training.days$avm,
                                        scenario = 'avm',
                                        response = 'log.price',
                                        predictors = PredictorsChopraCenteredLogAvm()),
                        MakeModelLinear(testing.period = testing.period,
                                        data = transformed.data,
                                        num.training.days = best.num.training.days$mortgage,
                                        scenario = 'mortgage',
                                        response = 'log.price',
                                        predictors = PredictorsChopraCenteredLogMortgage()))
        stopifnot(!is.null(Model))
        Model
    }

    MyDescription <- function(model.index) {
        #cat('starting MyDescription', model.index, '\n'); browser()
        result <- switch(model.index,
                         list(name = sprintf('log-log assessor %d training days',
                                             best.num.training.days$assessor)),
                         list(name = sprintf('log-log avm %d training days',
                                             best.num.training.days$avm)),
                         list(name = sprintf('log-log mortgage %d training days',
                                             best.num.training.days$mortgage)))
        stopifnot(!is.null(result))
        result
    }

    # assemble outputs
    nModels <- 3
    Model <- lapply(1:nModels, MyMakeModel)
    description <- lapply(1:nModels, MyDescription)
    Test <- list(MakeTestBestModelIndex(expected.best.model.index = 3)) 

    result <- list(Model = Model, description = description, Test = Test)
    result
}
