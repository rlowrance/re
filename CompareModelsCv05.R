CompareModelsCv05 <- function(testing.period, transformed.data) {
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

    cat('starting CompareModelsCv05', testing.period$first.date, testing.period$last.date, nrow(transformed.data), '\n'); browser()

    Require('PredictorsChopraCenteredLogAssessor')
    Require('MakeTestBestModelIndex')
    Require('MakeModelLinear')

    # force args
    testing.period
    transformed.data

    best.num.training.days <- list( assessor = 270 # from CV01
                                   ,avm      = 60  # from CV02
                                   )

    MyMakeModel <- function(model.index) {
        #cat('starting MyMakeModel', model.index, '\n'); browser()

        MakeModelAvm <- function(num.training.days, predictors = PredictorsChopraCenteredLogAssessor()) {
            #cat('starting CompareModelsCv05::MakeModelAvm', num.training.days, '\n'); browser()
            Model <- MakeModelLinear(testing.period = testing.period,
                                     data = transformed.data,
                                     num.training.days = num.training.days,
                                     scenario = 'assessor',
                                     response = 'log.price',
                                     predictors = predictors)
            Model
        }

        Model <- switch(model.index,
                        MakeModelLinear(testing.period = testing.period,
                                        data = transformed.data,
                                        num.training.days = best.num.training.days$assessor,
                                        scenario = 'assessor',
                                        response = 'log.price',
                                        predictors = PredictorsChopraCenteredLogAssessor()),
                        MakeModelAvm(best.num.training.days$avm,
                                     predictors=PredictorsChopraCenteredLogAvm()),
                        MakeModelAvm(30),
                        MakeModelAvm(60),
                        MakeModelAvm(90),
                        MakeModelAvm(120),
                        MakeModelAvm(150),
                        MakeModelAvm(180),
                        MakeModelAvm(210),
                        MakeModelAvm(240),
                        MakeModelAvm(270),
                        MakeModelAvm(300))
        stopifnot(!is.null(Model))
        Model
    }

    MyDescription <- function(model.index) {
        #cat('starting MyDescription', model.index, '\n'); browser()

        NameAvm <- function(num.training.days) {
            #cat('starting NameAvm', num.training.days, '\n'); browser()
            result <- list(name = sprintf('log-log avm no assessment %d training days',
                                          num.training.days))
            result
        }

        result <- switch(model.index,
                         list(name = sprintf('log-log assessor %d training days',
                                             best.num.training.days$assessor)),
                         list(name = sprintf('log-log avm all features %d training days',
                                             best.num.training.days$avm)),
                         NameAvm(30),
                         NameAvm(60),
                         NameAvm(90),
                         NameAvm(120),
                         NameAvm(150),
                         NameAvm(180),
                         NameAvm(210),
                         NameAvm(240),
                         NameAvm(270),
                         NameAvm(300))
        stopifnot(!is.null(result))
        result
    }

    # assemble outputs
    nModels <- 12
    Model <- lapply(1:nModels, MyMakeModel)
    description <- lapply(1:nModels, MyDescription)
    Test <- list(MakeTestBestModelIndex(expected.best.model.index = 2))

    result <- list(Model = Model, description = description, Test = Test)
    result
}
