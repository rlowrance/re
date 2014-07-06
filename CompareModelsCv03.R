CompareModelsCv03 <- function(testing.period, transformed.data) {
    # define models for experiment: mortgage linear log-log form chopra
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

    cat('starting CompareModelsCv03', testing.period$first.date, testing.period$last.date, nrow(transformed.data), '\n'); browser()

    Require('PredictorsChopraCenteredLogMortgage')
    Require('MakeTestBestModelIndex')
    Require('ModelLinear')

    MyTrainingDays <- function(model.index) {
        30 * model.index  # 30 days per model index
    }

    my.scenario <- 'mortgage'
    my.response.var <- 'log.price'
    my.predictors <- PredictorsChopraCenteredLogMortgage()
    my.predictors.name <- 'chopra centered log mortgage'

    MyMakeModel <- function(model.index) {
        # return Model satisfying API for CrossValidate
        # NOTE: model is local (one for each testing sample), so that
        # the testing.period must be computed for each testing sample
        #cat('starting CompareModelsCv03::MyMakeModel', model.index, '\n'); browser()

        model.index  # force evaluation, otherwise, get last value

        TrainingPeriod <- function(testing.date) {
            #cat('CompareModelCv03::TrainingPeriod', testing.date, '\n'); browser()
            # TODO: find a way to make sure that testing.date is a Date
            # code below doesn't work because there is no function is.Date or isDate
            #stopifnot(isDate(testing.date))

            span <- MyTrainingDays(model.index) / 2
            training.period <- list(first.date = testing.date - span,
                                    last.date  = testing.date + span)
            training.period
        }

        my.features <- list(response = my.response.var,
                            predictors = my.predictors)

        Model <- function(data, training.indices, testing.indices) {
            #cat('starting CompareModelsCv03:Model\n'); browser()
            my.verbose.model <- TRUE
            result <- ModelLinear(data = data,
                                  training.indices = training.indices,
                                  testing.indices = testing.indices,
                                  scenario = my.scenario,
                                  training.period = TrainingPeriod,
                                  testing.period = testing.period,
                                  features = my.features,
                                  verbose.model = my.verbose.model)
            result
        }
        Model
    }

    MyDescription <- function(model.index) {
        # return description of model
        #cat('starting CompareModelsCv02::MyDescription', model.index, '\n'); browser()
        result <- 
            list(scenario = my.scenario,
                 testing.period = testing.period,
                 training.period = sprintf('%d days around transaction date', MyTrainingDays(model.index)),
                 model = 'ModelLinear',
                 response = my.response.var,
                 predictors = my.predictors.name)
        result
    }

    nModels <- 10
    Model <- lapply(1:nModels, MyMakeModel)
    description <- lapply(1:nModels, MyDescription)
    Test <- list(MakeTestBestModelIndex(expected.best.model.index = 5))  

    result <- list(Model = Model, description = description, Test = Test)
    result
}
