CompareModelsCvLinear <- function(testing.period, transformed.data, model.form, scenario, Tests) {
    # define models for experiment: linear form chopra
    # varying months of training data
    # ARGS
    # testing.period   : list($first.date,$last.date) list of Date 
    #                    first and last dates for the testing period
    # transformed.data : data.frame
    # model.form       : chr scalar, form of the linear model
    #                    one of 'level.level', 'level.log', 'log.level', 'log.log'
    # scenario         : chr scalar, modeling scenario
    #                    one of 'assessor', 'avm', mortgage'
    # Test             : list of functions, passed directly as an output
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

    #cat('starting CompareModelCvLinear', model.form, scenario, '\n'); browser()

    Require('ModelLinear')
    Require('PredictorsChopraCenteredLevelAssessor')
    Require('PredictorsChopraCenteredLevelAvm')
    Require('PredictorsChopraCenteredLevelMortgage')
    Require('PredictorsChopraCenteredLogAssessor')
    Require('PredictorsChopraCenteredLogAvm')
    Require('PredictorsChopraCenteredLogMortgage')

    split <- strsplit(model.form, '.', fixed = TRUE)[[1]]
    model.form.response = split[[1]]
    model.form.predictors = split[[2]]

    response.var <- 
        switch(model.form.response,
               level = 'price',
               log   = 'log.price',
               stop('bad model.form.response'))

    predictor.name.features <-
        switch(model.form.predictors,
               level = switch(scenario,
                              assessor = list('Chopra centered level assessor',
                                              PredictorChopraCenteredLevelAssesor()),
                              avm      = list('Chopra centered level avm',
                                              PredictorsChopraCenteredLevelAvm()),
                              mortgage = list('Chopra centered level mortgage',
                                              PredictorsChopraCenteredLevelMorgage()),
                              stop('bad scenario')),
               log =   switch(scenario,
                              assessor = list('Chopra centered log assessor',
                                              PredictorsChopraCenteredLogAssessor()),
                              avm      = list('Chopra centered log avm',
                                              PredictorsChopraCenteredLogAvm()),
                              mortgage = list('Chopra centered log mortgage',
                                              PredictorsChopraCenteredLogMortgage()),
                              stop('bad scenario')),
               stop('bad model.form.predictors'))
    stopifnot(!is.null(predictor.name.features))
    predictor.name <- predictor.name.features[[1]]
    predictor.features <- predictor.name.features[[2]]

    base.description <- 
        list(scenario = scenario,
             testing.period = testing.period,
             model = 'ModelLinear',
             response = response.var,
             predictors = predictor.name)
    stopifnot(!is.null(base.description))

    features <- list(response = response.var,
                     predictors = predictor.features)

    DaysBefore <- function(model.index) {
        30 * model.index
    }

    TrainingPeriodAssessor <- function(model.index) {
        # train for model.index months before the cutoff date
        assessor.mailing.date <- as.Date('2008-10-1')
        stop('bad assessor mailing date: should be in 2007')
        last.assessor.analysis.date <- assessor.mailing.date - 1
        days.before <- DaysBefore(model.index)
        training.period <- list(first.date = last.assessor.analysis.date - days.before,
                                last.date = last.assessor.analysis.date)
    }

    TrainingPeriodAvm <- function(model.index) {
        # train for model.index months before the first test date
        # NOTE: An actual AVM could training for days up until the transaction date
        #cat('starting TrainingPeriodAvm', model.index, '\n'); browser()
        first.testing.date <- testing.period$first.date
        last.avm.analysis.date <- first.testing.date - 1
        days.before <- DaysBefore(model.index)
        training.period <- list(first.date = last.avm.analysis.date - days.before,
                                last.date  = last.avm.analysis.date)
        training.period
    }

    TrainingPeriodMortgage <- function(model.index) {
        # train for model.index months around the transaction date
        # approximate the transaction date as being the midpoint of the testing period
        cat('starting TrainingPeriodMortgage', model.index, '\n'); browser()
        transaction.date <- round((testing.period$first.date + testing.period$last.date) / 2)
        training.period <- list(first.date = transaction.date - 15 * model.index,
                                last.date  = transaction.date + 15 * model.index)
        training.period
    }

    MakeModel <- function(model.index) {
        # determine training period
        #cat('starting MakeModel', model.index, '\n'); browser()
        training.period <- switch(scenario,
                                  assessor = TrainingPeriodAssessor(model.index),
                                  avm      = TrainingPeriodAvm(model.index),
                                  mortgage = TrainingPeriodMortgage())

        Model <- function(data, training.indices, testing.indices) {
            # return $actual $prediction
            # use training.period set just above
            if (FALSE) {
                cat('starting Cv01::Model', 
                    nrow(data), sum(training.indices), sum(testing.indices),
                    training.period$first.date, training.period$last.date,
                    '\n')
                browser()
            }

            verbose.model <- TRUE
            model.linear <- 
                ModelLinear(data = data,
                            training.indices = training.indices,
                            testing.indices = testing.indices,
                            scenario = scenario,
                            training.period = training.period,
                            testing.period = testing.period,
                            features = features,
                            verbose.model = verbose.model)
            stopifnot(!is.null(model.linear$actual))
            stopifnot(!is.null(model.linear$prediction))
            model.linear
        }
        Model
    }

    MakeDescription <- function(model.index) {
        training.period.description <-
            switch(scenario,
                   assessor = sprintf('%d days before Oct 1', DaysBefore(model.index)),
                   avm      = sprintf('%d days before Dec 31', DaysBefore(model.index)),
                   mortgage = sprintf('%d days around mid-point of testing period', 
                                      DaysBefore(model.index)))
        description <- c(base.description,
                         training.period <- training.period.description)
        description
    }

    nModels <- 10
    result <- list(Model = lapply(1:nModels,MakeModel),
                   description = lapply(1:nModels, MakeDescription),
                   Tests = Tests)
    result
}
