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

    cat('starting CompareModelsCv01', testing.period$first.date, testing.period$last.date, nrow(transformed.data), '\n'); browser()

    Require('CompareModelsCvLinear')
    Require('MakeTestBestModelIndex')

    # define test 1
    expected.best.model.index <- 9
    Test1 <- MakeTestBestModelIndex(expected.best.model.index = expected.best.model.index,
                                    verbose = TRUE)

    # define test 2
    Test2 <- function(cv.result) {
        # verify that models with higher (mean.within.10.percent) have more observations
        # ARG:
        # cv.result : the returned value from CrossValidate, which has these fields
        #   $best.model.index : num scalar
        #   $all.assessment   : data.frame
        # RETURN a list satisfying the API for function Cv in compare-models.R
        #   $hypothesis : char scalar
        #   $passed     : logical scalar, TRUE caller will stop if not TRUE
        #   $support    : arbitrary object that justified value of $passed

        #cat('starting Test2\n'); browser()
        verbose <- FALSE

        # determine statistics for each model across folds
        fold.assessment <- cv.result$fold.assessment

        MeanWithin10Percent <- function(model.index) {
            values <- fold.assessment[model.index == fold.assessment$model.index,
                                      'assessment.within.10.percent']
            result <- mean(values)
            result
        }

        MeanNumTrainingSamples <- function(model.index) {
            values <- fold.assessment[model.index == fold.assessment$model.index,
                                      'assessment.num.training.samples']
            result <- mean(values)
            result
        }

        nModels <- max(fold.assessment$model.index)
        mean.within.10.percent <- sapply(1:nModels, MeanWithin10Percent)
        mean.num.training.samples <- sapply(1:nModels, MeanNumTrainingSamples)

        reduced.data <- data.frame(model.index = 1:nModels,
                                   mean.within.10.percent = mean.within.10.percent,
                                   mean.num.training.samples = mean.num.training.samples)
        if (verbose) {
            print(reduced.data)
        }

        # regress mean.num.training.samples ~ mean.within.10.percent
        fitted.lm <- lm(formula = mean.num.training.samples ~ 0 + mean.within.10.percent,
                        data = reduced.data)
        if (verbose) {
            print(fitted.lm)
        }
        coefficient <- fitted.lm$coefficients  # there is only one coefficient
        passed <- coefficient > 0 

        result = list(hypothesis = 'models with higher mean within 10 percent have more observations',
                      passed = passed,
                      support = list(cv.result = cv.result,
                                     reduced.data = reduced.data,
                                     fitted.lm = fitted.lm))
        result
    }

    result <- CompareModelsCvLinear(testing.period = testing.period,
                                    transformed.data = transformed.data,
                                    model.form = 'log.log',
                                    scenario = 'assessor',
                                    Test = list(Test1, Test2))

    return(result)


    # OLD CODE BELOW ME
    
    Require('ModelLinear')
    Require('PredictorsChopraCenteredLogNoAssessor')

    base.description <- list(scenario = 'assessor',
                             testing.period = testing.period,
                             model = 'ModelLinear',
                             response = 'log.price',
                             predictors = 'Chopra centered log no assessor')
    
    features <- list(response = 'log.price',
                     predictors = PredictorsChopraCenteredLogNoAssessor())

    DaysBefore <- function(model.index) {
        30 * model.index
    }

    MakeModel <- function(model.index) {
        # determine training period
        assessor.mailing.date <- as.Date('2008-10-1')
        last.assessor.analysis.date <- assessor.mailing.date - 1
        days.before <- DaysBefore(model.index)
        training.period <- list(first.date = last.assessor.analysis.date - days.before,
                                last.date = last.assessor.analysis.date)

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
                            scenario = 'assessor',
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
        description <- c(base.description,
                         training.period = sprintf('%d days before Oct 1', DaysBefore(model.index)))
        description
    }

    Test1 <- function(cv.result) {
        # verify that best model has index 1
        # ARG:
        # cv.result : the returned value from CrossValidate, which has these fields
        #   $best.model.index : num scalar
        #   $all.assessment   : data.frame
        # RETURN a list satisfying the API for function Cv in compare-models.R
        #   $hypothesis : char scalar
        #   $passed     : logical scalar, TRUE caller will stop if not TRUE
        #   $support    : arbitrary object that justified value of $passed

        #cat('starting Test1\n'); browser()
        verbose <- TRUE

        if (verbose) {
            fold.assessment <- cv.result$fold.assessment

            MeanRmse <- function(model.index) {
                values <- fold.assessment[model.index == fold.assessment$model.index,
                                          'assessment.rmse']
                result <- mean(values)
                result
            }

            nModels <- max(fold.assessment$model.index)
            mean.rmse <- sapply(1:nModels, MeanRmse)
            for (i in 1:nModels) {
                Printf('Test1: model %d mean.rmse %f\n', i, mean.rmse[[i]])
            }
        }
        result <- list(hypothesis = 'best model is model # 9',
                       passed = cv.result$best.model.index == 9,
                       support = cv.result)
    }

    Test2 <- function(cv.result) {
        # verify that models with higher (mean.within.10.percent) have more observations
        # ARG:
        # cv.result : the returned value from CrossValidate, which has these fields
        #   $best.model.index : num scalar
        #   $all.assessment   : data.frame
        # RETURN a list satisfying the API for function Cv in compare-models.R
        #   $hypothesis : char scalar
        #   $passed     : logical scalar, TRUE caller will stop if not TRUE
        #   $support    : arbitrary object that justified value of $passed

        #cat('starting Test2\n'); browser()
        verbose <- FALSE

        # determine statistics for each model across folds
        fold.assessment <- cv.result$fold.assessment

        MeanWithin10Percent <- function(model.index) {
            values <- fold.assessment[model.index == fold.assessment$model.index,
                                      'assessment.within.10.percent']
            result <- mean(values)
            result
        }

        MeanNumTrainingSamples <- function(model.index) {
            values <- fold.assessment[model.index == fold.assessment$model.index,
                                      'assessment.num.training.samples']
            result <- mean(values)
            result
        }

        nModels <- max(fold.assessment$model.index)
        mean.within.10.percent <- sapply(1:nModels, MeanWithin10Percent)
        mean.num.training.samples <- sapply(1:nModels, MeanNumTrainingSamples)

        reduced.data <- data.frame(model.index = 1:nModels,
                                   mean.within.10.percent = mean.within.10.percent,
                                   mean.num.training.samples = mean.num.training.samples)
        if (verbose) {
            print(reduced.data)
        }

        # regress mean.num.training.samples ~ mean.within.10.percent
        fitted.lm <- lm(formula = mean.num.training.samples ~ 0 + mean.within.10.percent,
                        data = reduced.data)
        if (verbose) {
            print(fitted.lm)
        }
        coefficient <- fitted.lm$coefficients  # there is only one coefficient
        passed <- coefficient > 0 

        result = list(hypothesis = 'models with higher mean within 10 percent have more observations',
                      passed = passed,
                      support = list(cv.result = cv.result,
                                     reduced.data = reduced.data,
                                     fitted.lm = fitted.lm))
        result
    }


    MakeModelDescription <- function(model.index) {
        # return list $Model $description
        #cat('starting MakeModelDescription', model.index, '\n'); browser()

        # determine training period
        assessor.mailing.date <- as.Date('2008-10-1')
        last.assessor.analysis.date <- assessor.mailing.date - 1
        days.before <- 30 * model.index
        training.period <- list(first.date = last.assessor.analysis.date - days.before,
                                last.date = last.assessor.analysis.date)

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
                            scenario = 'assessor',
                            training.period = training.period,
                            testing.period = testing.period,
                            features = features,
                            verbose.model = verbose.model)
            stopifnot(!is.null(model.linear$actuals))
            stopifnot(!is.null(model.linear$predictions))
            cat('in Model, about to return'); browser()
            model.linear
        }

        description <- c(base.description,
                         training.period = sprintf('%d days before Oct 1', days.before))

        result <- list(Model = Model, description = description)
        result
    }

    nModels <- 10

    result <- NULL
    result$Model <- lapply(1:nModels, MakeModel)
    result$description <- lapply(1:nModels, MakeDescription)
    result$Tests <- list(Test1, Test2)
    result
}
