Require('Formula')
Require('Printf')
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

    Lm <- function(is.visible) {
        # return list $predictions $actuals
        #cat('starting ModelLinear::Lm', sum(is.visible), '\n'); browser()

        in.training.period <- 
            data$saleDate >= training.period$first.date &
            data$saleDate <= training.period$last.date
        selected.for.training <- training.indices & in.training.period & is.visible
        num.training.samples <- sum(selected.for.training)
        stopifnot(sum(selected.for.training) > 0)

        training.data <- data[selected.for.training,]

        # Do not use predictors that have only one unique value
        reduced.predictors <- DropFeaturesWithOneUniqueValue(training.data, features$predictors)
        the.formula <- Formula(features$response, reduced.predictors)

        #cat('in Lm about to call lm()\n'); browser()
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

        # adjust log.price to price
        if (features$response == 'log.price') {
            prediction.returned <- exp(prediction)
        }  else {
            prediction.returned <- prediction
        }
        
        result <- list(actual = actual, 
                       prediction = prediction.returned, 
                       num.training.samples = num.training.samples)
        result
    }

    Assessor <- function() {
        # return list $predictions $actuals for the assessor scenario
        #cat('starting ModelLinear::Assessor\n'); browser()
        visible.to.assessor <- data$recordingDate <= training.period$last.date
        result <- Lm(visible.to.assessor)
        result
    }

    Avm <- function() {
        # return list $predictions $actuals for the AVM scenario
        #cat('starting ModelLinear::Avm\n'); browser()
        visible.to.avm <- data$recordingDate <= training.period$last.date
        result <- Lm(visible.to.avm)
        result
    }

    MortgageVersion1 <- function() {
        # return list $prediction $actuals for the mortgage scenario
        # implement a local model for each test transaction
        #cat('starting ModelLinear::Mortgage\n'); browser()

        the.formula <- Formula(features$response, features$predictors)

        # select samples in test period
        in.testing.period <- 
            data$saleDate >= testing.period$first.date &
            data$saleDate <= testing.period$last.date
        selected.for.testing <- testing.indices & in.testing.period
        stopifnot(sum(selected.for.testing) > 0)

        # predict for the sample data[index] (a local model)
        Test1Mortgage <- function(index) {
            #cat('starting ModelLinear::Test1Mortgage', index, '\n'); browser()
            my.training.period <- training.period(data$saleDate[[index]])
            in.training.period <- 
                data$saleDate >= my.training.period$first.date &
                data$saleDate <= my.training.period$last.date
               
            selected.for.training <- training.indices & in.training.period
            training.data <- data[selected.for.training,]

            reduced.predictors <- DropFeaturesWithOneUniqueValue(training.data, features$predictors)

            the.formula <- Formula(features$response, reduced.predictors)

            fitted <- lm(training.data,
                         formula = the.formula)
            newdata <- data[index,]
            actual <- data[index, 'price']
            prediction <- predict.lm(fitted, newdata = newdata)
            prediction.returned <- ifelse(features$response == 'log.price', exp(prediction), prediction)

            result <- list(actual = actual, prediction = prediction.returned)
            if (verbose.model) {
                Printf('mortgage index %d actual %7.0f prediction %7.0f\n',
                       index, result$actual, result$prediction)
            }
            result
        }

        # predict each test sample using a model just for the sample
        testing.indices <- which(selected.for.testing)
        if (verbose.model) {
            Printf('mortgage has %d testing indices\n', length(testing.indices))
        }
        result <- lapply(testing.indices, Test1Mortgage)
        actual <- sapply(result, function(x) x$actual)
        prediction <- sapply(result, function(x) x$prediction)
        result2 <- list(actual = actual, prediction = prediction, num.training.samples = 0)
        result2
    }

    Mortgage <- function() {
        # return list $prediction $actuals for the mortgage scenario
        # implement a local model for each test transaction
        #cat('starting ModelLinear::Mortgage\n'); browser()
        verbose <- FALSE

        # select samples in test period
        in.testing.period <- 
            data$saleDate >= testing.period$first.date &
            data$saleDate <= testing.period$last.date
        selected.for.testing <- testing.indices & in.testing.period
        stopifnot(sum(selected.for.testing) > 0)


        FitModel <- function(test.index) {
            # fit model for sale date of the test.index transaction
            #cat('FitModel', test.index, '\n'); browser()
            my.training.period <- training.period(data$saleDate[[test.index]]) # training period for the date

            in.training.period <- 
                data$saleDate >= my.training.period$first.date &
                data$saleDate <= my.training.period$last.date

               
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
            #cat('Predict', test.index, '\n'); browser()
            newdata <- data[test.index,]
            actual <- data[test.index, 'price']
            prediction <- predict.lm(fitted, newdata = newdata)
            prediction.returned <- ifelse(features$response == 'log.price', exp(prediction), prediction)

            result <- list(actual = actual, prediction = prediction.returned)
            if (verbose.model) {
                Printf('mortgage index %d actual %7.0f prediction %7.0f\n',
                       index, result$actual, result$prediction)
            }
            result  
        }

        # predict each test sample using a model just for the sample
        testing.indices <- which(selected.for.testing)
        if (verbose.model) {
            Printf('mortgage has %d testing indices\n', length(testing.indices))
        }

        # build list of predictions
        # memoize fitted models
        #cat('ModelLinear::Mortgage memorize\n'); browser()
        fitted.models <- list()
        actual.prediction <- NULL
        for (testing.index in testing.indices) {
            saleDate <- as.character(data$saleDate[[testing.index]])
            if(is.null(fitted.models[[saleDate]])) {
                fitted <- FitModel(testing.index)
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
        switch(scenario,
               assessor = Assessor(),
               avm = Avm(),
               mortgage = Mortgage())
    stopifnot(actuals.predictors != NULL)  # if NULL then scenario had unexpected value
    
    actuals.predictors
}
