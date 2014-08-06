source('Rmse.R')
source('WithinXPercent.R')
Assess <- function(model.result) {
    # return assessment of the model.result
    # ARG:
    # model.result : a list with at least these named elements
    # $actual     : num vector of actual values, some of which may be NA
    # $prediction : num vector of predicted values, some of which may be NA
    # Return list with these values in this order (the order matters to some callers!)
    # $rmse                   : num scalar
    # $within.10.percent      : num scalar
    # $num.training.samples   : num scalar or NULL, if present in model.result
    # $coverage               : num scalar, num($prediction) / num($actual)

    #cat('starting Assess\n'); browser()


    actual <- model.result$actual
    prediction <- model.result$prediction

    Coverage <- function(actual, prediction) {
        has.actual <- !is.na(actual)
        has.prediction <- has.actual & !is.na(prediction)
        result <- sum(has.prediction) / sum(has.actual)
        result
    }

    # the first result must be the rmse (in order to conform to CrossValidate)
    result <- list(rmse = Rmse(actual = actual,
                                prediction = prediction),
                   within.10.percent = WithinXPercent(actual = actual, 
                                                       prediction = prediction, 
                                                       precision = .10),
                   num.training.samples = model.result$num.training.sample,
                   coverage = Coverage(actual, prediction))


    result
}

Assess.test <- function() {
    # unit test
    Test1 <- function() {
        actual <- c(10,20,30)
        prediction <- c(10,20,30)
        model.result <- list(actual = actual, prediction = prediction)
        r <- Assess(model.result)
        stopifnot(r$rmse == 0)
        stopifnot(r$within.10.percent == 1)
        stopifnot(r$num.training.samples == NULL)
        stopifnot(r$coverage == 1)
        stopifnot(r[[1]] == 0)
    }
    Test1()

    Test2 <- function() {
        actual <- c(NA, 20, 30)
        prediction <- c(10, 21, NA)
        model.result <- list(actual = actual,
                             prediction = prediction,
                             num.training.samples = 123)
        r <- Assess(model.result)
        stopifnot(r$rmse == 1)
        stopifnot(r$within.10.percent == 1)
        stopifnot(r$num.training.samples == 123)
        stopifnot(r$coverage == .5)
        stopifnot(r[[1]] == r$rmse)
    }
    Test2()
}

Assess.test()
