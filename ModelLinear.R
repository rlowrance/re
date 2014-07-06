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

    Lm <- function(is.visible) {
        # return list $predictions $actuals
        #cat('starting ModelLinear::Lm', sum(is.visible), '\n'); browser()

        in.training.period <- 
            data$saleDate >= training.period$first.date &
            data$saleDate <= training.period$last.date
        selected.for.training <- training.indices & in.training.period & is.visible
        num.training.samples <- sum(selected.for.training)
        stopifnot(sum(selected.for.training) > 0)

        the.formula <- Formula(features$response, features$predictors)

        fitted <- lm(data = data[selected.for.training,],
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

    Mortgage <- function() {
        # return list $prediction $actuals for the mortgage scenario
        # NOTE: another design choice is to implement a local model for each testing transaction
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

            fitted <- lm(data[selected.for.training,],
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
        result2 <- list(actual = actual, prediction = prediction)
        result2
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
