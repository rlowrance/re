ModelLinear <- function(data, 
                        training.indices, 
                        testing.indices,
                        scenario,
                        training.period, 
                        testing.period,
                        features,
                        verbose.model) {
    # linear model
    # - train on data selected by training.indices and in training.period
    # - test on data selected by testing.indices and in testing.period
    # - for specified scenario and features

    # Return list: 
    # $actual               : num vector, possibly with NAs, actual values if available
    # $prediction           : num vector, possibly with NAs, predicted values if available
    # $num.training.samples : num scalar, number of training samples
    #   for linear model trained and tested on specified observations in data
    #   for the specified scenario. training period, testing period, and feature set
    # ARGS:
    # data             : data.frame
    # training.indices : selector vector; only these observations in data can be used for training
    # testing.indices  : selector vector; only these observations in data can be used for testing
    # scenario         : chr scalar, one of 'assessor', 'avm', 'mortgage'
    # training.period  : list of Date, $first.date, $last.date or
    #                    function(transaction.date) --> training.period for the transaction date
    # testing.period   : list of Date, $first.date, $last.date
    # features         : list of $response (chr scalar) $predictors (chr vector)
    # verbose.model    : logical, if true, print as we go

    if (FALSE) {
        cat('starting ModelLinear',
            nrow(data), sum(training.indices), sum(testing.indices),
            scenario,
            class(training.period),
            testing.period$first.date, testing.period$last.date,
            features$response, length(features$predictors),
            '\n')
        browser()
    }

    DropFeaturesWithOneUniqueValue <- function(data, feature.names) {
        # return list of feature names, dropping any features that are factors and have one level
        #cat('starting DropFactorsWithOneUniqueValue\n'); browser()

        Keep <- function(feature.name) {
            # return list of feature.names with more than one unique value
            num.uniques <- length(unique(data[[feature.name]]))
            result <- num.uniques > 1
            result
        }

        result <- Filter(Keep, feature.names)
        result
    }

    Assessor <- function() {
        #cat('starting ModelLinear::Assessor\n'); browser()
        visible.to.assessor <- data$recordingDate <= training.period$last.date

        in.training.period <- 
            data$saleDate >= training.period$first.date &
            data$saleDate <= training.period$last.date
        selected.for.training <- training.indices & in.training.period & visible.to.assessor
        num.training.samples <- sum(selected.for.training)
        stopifnot(sum(selected.for.training) > 0)

        training.data <- data[selected.for.training,]

        # Do not use predictors that have only one unique value
        reduced.predictors <- DropFeaturesWithOneUniqueValue(training.data, features$predictors)
        the.formula <- Formula(features$response, reduced.predictors)

        fitted <- lm(data = training.data,
                     formula = the.formula)
        if (verbose.model) {
            print(summary(fitted))
        }

        # select samples in test period
        in.testing.period <- 
            data$saleDate >= testing.period$first.date &
            data$saleDate <= testing.period$last.date
        selected.for.testing <- testing.indices & in.testing.period
        stopifnot(sum(selected.for.testing) > 0)

        newdata <- data[selected.for.testing,]
        actual <- newdata$price
        prediction <- predict.lm(fitted, newdata)
        DEBUGGING <- FALSE
        if (DEBUGGING) {
            cat('debugging ModelLinear\n'); browser()
            has.large.error <- 73731
            has.large.error <- 2543
            newdata2 <- data[has.large.error,]  # transaction with error 1.4 million
            prediction2 <- predict.lm(fitted, newdata2)
        }

        # adjust log.price to price
        if (features$response == 'log.price') {
            prediction.returned <- exp(prediction)
        }  else {
            prediction.returned <- prediction
        }
        
        result <- list( actual = actual
                       ,prediction = prediction.returned
                       ,num.training.samples = num.training.samples
                       ,fitted = fitted)
        result
    }

    SelectedForTesting <- function(data, testing.indices, testing.period) {
        #cat('starting SelectedForTesting\n'); browser()
        in.testing.period <- 
            data$saleDate >= testing.period$first.date &
            data$saleDate <= testing.period$last.date
        selected.for.testing <- testing.indices & in.testing.period
        stopifnot(sum(selected.for.testing) > 0)
        selected.for.testing
    }

    FitModel <- function(in.training.period) {
        #cat('startingFitModel\n'); browser()
        selected.for.training <- training.indices & in.training.period
        training.data <- data[selected.for.training,]

        reduced.predictors <- DropFeaturesWithOneUniqueValue(training.data, features$predictors)

        the.formula <- Formula(features$response, reduced.predictors)

        fitted <- lm(training.data,
                     formula = the.formula)
        fitted
    }

    Predict <- function(fitted, test.index) {
        # return prediction for the test.index transaction
        #cat('starting Predict', test.index, '\n'); browser()
        newdata <- data[test.index,]
        actual <- data[test.index, 'price']
        prediction <- predict.lm(fitted, newdata = newdata)
        prediction.returned <- ifelse(features$response == 'log.price', exp(prediction), prediction)

        result <- list(actual = actual, prediction = prediction.returned)
        if (verbose.model) {
            Printf('index %d actual %7.0f prediction %7.0f\n',
                   test.index, result$actual, result$prediction)
        }
        result  
    }

    LmDiagnose <- function(fitted, newdata) {
        # print diagnostic
        cat('start LmDiagnose\n'); browser()
        stopifnot(nrow(newdata) == 1)
        prediction <- predict.lm(fitted, newdata = newdata)
        betas <- fitted$coefficients
        features.used <- names(betas)
        Printf('The training set had %d observations\n', nrow(fitted$model))
        cat('contribution to prediction\n')

        PrintRow <- function(feature.name) {
            PrintContribution <- function(beta, value) {
                #cat('start PrintContribution', feature.name, beta, value, '\n'); browser()
                Printf('%26s: %15.6f x %11.2f = %8.2f\n', feature.name, beta, value, beta * value)
            }
            PrintContribution(betas[[feature.name]],
                              if (feature.name == '(Intercept)') 1 else newdata[[feature.name]])
        }

        Map(PrintRow, features.used)
        Printf('overall prediction %7.2f (exp = %f)\n', prediction, exp(prediction))
    }

    Avm <- function() {
    # ARGS:
    # data             : data.frame
    # training.indices : selector vector; only these observations in data can be used for training
    # testing.indices  : selector vector; only these observations in data can be used for testing
    #                    function(transaction.date) --> training.period for the transaction date
    # testing.period   : list of Date, $first.date, $last.date
    # features         : list of $response (chr scalar) $predictors (chr vector)
    # verbose.model    : logical, if true, print as we go
        FitModelAvm <- function(test.index) {
            # fit model for sale date of the test.index transaction
            #cat('ModelLinear::Avm::FitModel', test.index, '\n'); browser()
            my.training.period <- training.period(data$saleDate[[test.index]]) # training period for the date

            in.training.period <- 
                data$recordingDate >= my.training.period$first.date &
                data$recordingDate <= my.training.period$last.date

            FitModel(in.training.period)
        }

        IsSpecialApn <- function(apn) {
            apn == '4470013020' || apn == '5561007004' || apn == '4451005012'
        }

        # BODY STARTS HERE
        #cat('starting ModelLinear::Avm\n'); browser()
        verbose <- FALSE 
        debugging <- TRUE
        debugging <- FALSE

        selected.for.testing <- SelectedForTesting( data = data
                                                   ,testing.indices = testing.indices
                                                   ,testing.period = testing.period
                                                   )
        testing.indices <- which(selected.for.testing)
        if (verbose) {
            Printf('avm model has %d testing indices\n', length(testing.indices))
        }

        # Accumulate the actual prediction for each testing index
        fitted.models <- list()
        actual.prediction <- NULL
        for (testing.index in testing.indices) {
            if (FALSE && debugging && testing.index == 220507) {cat('found it\n'); browser() }
            apn <- data$apn[[testing.index]]
            if (debugging && !IsSpecialApn(apn)) next
            saleDate <- as.character(data$saleDate[[testing.index]])
            if(is.null(fitted.models[[saleDate]])) {
                fitted <- FitModelAvm(testing.index)
                fitted.models[[saleDate]] <- fitted
            } else {
                if (verbose) {
                    cat('reused memoized fitted model', saleDate, '\n')
                }
            }
            fitted <- fitted.models[[saleDate]]

            next.actual.prediction <- Predict(fitted, testing.index)
            if (FALSE && IsSpecialApn(apn)) {
                cat( 'found special apn', apn
                    ,'saleDate', data$saleDate[[testing.index]]
                    ,'actual', next.actual.prediction$actual
                    ,'prediction', next.actual.prediction$prediction
                    ,'\n'
                    )
                LmDiagnose(fitted, data[testing.index,]) 
                browser()
            }
            if (debugging) {
                error <- next.actual.prediction$actual - next.actual.prediction$prediction
                if (abs(error) > 10e6) {
                    cat( 'large error', error
                        ,'apn', data$apn[[testing.index]]
                        ,'saleDate', data$saleDate[[testing.index]]
                        ,'actual', next.actual.prediction$actual
                        ,'prediction', next.actual.prediction$prediction
                        ,'\n'
                        )
                    browser()
                }
            }
            actual.prediction <- ListAppend(actual.prediction, next.actual.prediction)
        }

        # Build lists for actuals and predicted values
        actual <- sapply(actual.prediction, function(x) x$actual)
        prediction <- sapply(actual.prediction, function(x) x$prediction)
        result <- list( actual = actual
                       ,prediction = prediction
                       ,num.training.samples = 0
                       ,fitted = fitted.models
                       )
        result
    }


    Mortgage <- function() {
        # return list $prediction $actuals for the mortgage scenario
        # implement a local model for each test transaction

        FitModelMortgage <- function(test.index) {
            # fit model for sale date of the test.index transaction
            #cat('FitModel', test.index, '\n'); browser()
            my.training.period <- training.period(data$saleDate[[test.index]]) # training period for the date

            in.training.period <- 
                data$saleDate >= my.training.period$first.date &
                data$saleDate <= my.training.period$last.date

            FitModel(in.training.period)
        }


        #cat('starting ModelLinear::Mortgage\n'); browser()
        verbose <- FALSE

        # select samples in test period
        selected.for.testing <- SelectedForTesting( data = data
                                                   ,testing.indices = testing.indices
                                                   ,testing.period = testing.period
                                                   )
        testing.indices <- which(selected.for.testing)
        if (verbose.model) {
            Printf('mortgage model has %d testing indices\n', length(testing.indices))
        }

        # build list of predictions
        # memoize fitted models
        #cat('ModelLinear::Mortgage memorize\n'); browser()
        fitted.models <- list()
        actual.prediction <- NULL
        for (testing.index in testing.indices) {
            saleDate <- as.character(data$saleDate[[testing.index]])
            if(is.null(fitted.models[[saleDate]])) {
                fitted <- FitModelMortgage(testing.index)
                fitted.models[[saleDate]] <- fitted
            } else {
                if (verbose) {
                    cat('reused memoized fitted model', saleDate, '\n')
                }
            }
            fitted <- fitted.models[[saleDate]]
            actual.prediction <- ListAppend(actual.prediction, Predict(fitted, testing.index))
        }

        actual <- sapply(actual.prediction, function(x) x$actual)
        prediction <- sapply(actual.prediction, function(x) x$prediction)
        result <- list(actual = actual, prediction = prediction, num.training.samples = 0)
        result
    }

    # determine $actuals $predictors
    actuals.predictors <- 
        switch( scenario
               ,assessor = Assessor()
               ,avm = Avm()
               ,avmnoa = Avm()
               ,mortgage = Mortgage()
               ,stop(paste('bad scenario', scenario))
               )
    stopifnot(actuals.predictors != NULL)  # if NULL then scenario had unexpected value
    
    actuals.predictors
}
