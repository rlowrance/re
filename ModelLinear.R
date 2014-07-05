Require('Formula')
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
    # training.period  : list of Date, $first.date, $last.date
    # testing.period   : list of Date, $first.date, $last.date
    # features         : list of $response (chr scalar) $predictors (chr vector)
    # verbose.model    : logical, if true, print as we go

    if (FALSE) {
        cat('starting ModelLinear',
            nrow(data), sum(training.indices), sum(testing.indices),
            scenario,
            training.period$first.date, training.period$last.date,
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
        cat('starting ModelLinear::Mortgage\n'); browser()
        in.training.period <- 
            data$saleDate >= training.period$first.date &
            data$saleDate <= training.period$last.date
        selected.for.training <- training.indices & in.training.period
        stopifnot(sum(selected.for.training) > 0)

        the.formula = Formula(model.response, model.predictors)


        # select samples in test period
        in.testing.period <- 
            data$saleDate >= testing.period$first.date &
            data$saleDate <= testing.period$last.date
        selected.for.testing <- testing.indices & in.testing.period
        stopifnot(sum(selected.for.testing) > 0)

        # predict for the sample data[index]
        Test1Mortgage <- function(index) {
            fitted <- lm(data,
                         formula = the.formula,
                         subset = selected.for.training)
            newdata <- data[index,]
            actuals <- data[index, 'SALE.AMOUNT']
            predictions <- predict.lm(fitted, newdata = newdata)
            predictions.returned <- ifelse(features$response == 'log.price', exp(predictions), predictions)

            result <- list(actuals = actuals, predictions = returned.predictions)
            result
        }

        Rewrap <- function(lst) {
            # convert list of elements $actuals $predictions to 2 lists
            cat('starting Rewrap', length(lst), '\n'); browser()
            actuals <- NULL
            predictions <- NULL
            for (element in lst) {
                actuals <- c(actuals, element$actuals)
                predictions <- c(predictions, element$predictions)
            }
            result <- list(actuals = actuals, predictions = predictions)
            result
        }

        # predict each test sample using a model just for the sample
        result <- lapply(which(selected.for.testing), Test1Mortgage)
        result2 <- Rewrap(result)  # convert [[i]]$actuals $predictions to $actuals[[i]] $predictions[[i]]
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
