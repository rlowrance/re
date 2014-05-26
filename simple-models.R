# simple-models.R
# implement some simple price estimatation model

# scenario: forecast prices for last 36 days of 2004
# figure of merit: fraction within 10% of true price

# Simple models to consider include:
# - linear regression
# - weighted linear regression
# - linear regression by neighborhood (zip code, zip +4, census tract)
# - CART
# - random forest
# - houses near open space
# - houses near shopping (use tax roll to identify shopping)
# - houses near factories

# set control variables
control <- list()
control$me <- 'simple-models'
control$dir.output <- '../data/v6/output/'
control$path.subset1 <- paste0(control$dir.output, 'transactions-subset1.csv')
control$path.log <- paste0(control$dir.output, control$me, '.txt')
control$testing <- TRUE
#control$testing <- FALSE

# initialize
source('InitializeR.R')
if (TRUE) {
    InitializeR(start.JIT = FALSE,
                duplex.output.to = control$path.log)
    #InitializeR(start.JIT = ifelse(control$testing, FALSE, TRUE),
    #            duplex.output.to = control$path.log)
} else {
    #options(error=recover)
}

# source files now that JIT is set
source('Center.R')
source('CrossValidate2.R')
source('NumberFeaturesWithAnNA.R')
source('Printf.R')
source('ReadAndTransformTransactions.R')
source('SplitDate.R')

#library(rpart)
library(tree)
library(randomForest)

###############################################################################
# Utility
###############################################################################

# RenameColumns

RenameColumns <- function(df, old.names, new.names) {
    for (index in 1:length(old.names)) {
        new.name <- new.names[[index]]
        old.name <- old.names[[index]]
        df[[new.name]] <- df[[old.name]]
        df[[old.name]] <- NULL
    }
    df
}

RenameColumns.Test <- function() {
    df <- data.frame(a <- c(1,2,3),
                     b <- c(10,20,30),
                     c <- c(100, 200, 300))
    renamed <- RenameColumns(df, c('a', 'c'), list('A', 'C'))
    stopifnot(renamed$A != NULL)
    stopifnot(all(renamed$A == c(1,2,3)))
    stopifnot(all(renamed$b == c(10,20,30)))
    stopifnot(all(renamed$C == c(100,200,300)))
}

RenameColumns.Test()

# Rmse

Rmse <- function(actual, estimated) {
    # return square root of mean squared error
    stopifnot(length(actual) == length(estimated))
    stopifnot(length(actual) > 0)
    error <- actual - estimated
    mse <- sum(error * error) / length(actual)
    sqrt(mse)
}

Rmse.test <- function() {
    actual <- c(10, 20, 30)
    estimated <- c(11, 21, 31)
    mse <- Rmse(actual, estimated)
    stopifnot(mse == 1)
}

Rmse.test()

# Within10Percent

Within10Percent <- function(actual, estimated, precision = .10) {
    # return fraction of estimates that are within 10 percent of the actuals
    stopifnot(length(actual) == length(estimated))
    stopifnot(length(actual) > 0)
    stopifnot(sum(actual == 0) == 0)  # at least one actual is zero
    na.indices <- is.na(actual) | is.na(estimated)  # find NAs in either arg
    actual <- actual[!na.indices]
    estimated <- estimated[!na.indices]
    error <- actual - estimated
    relative.error <- error / actual
    sum(abs(relative.error) <= precision) / length(actual)
}

Within10Percent.test <- function() {
    actual <- c(1,2,3)
    estimated <- c(1.05, 20, NA)
    within <- Within10Percent(actual, estimated)
    cat('within', within, '\n')
    stopifnot(all.equal(within, 1/2))
}

Within10Percent.test()

# Substitute

Substitute <- function(v, old.values, new.values) {
    for (index in 1:length(old.values)) {
        selected <- v == old.values[index]
        if (sum(selected) > 0) {
            v[which(selected)] <- new.values[index]
        }
    }
    v
}

Substitute.Test <- function() {
    Test1 <- function() {
        v <- c('a', 'b', 'c')
        v.s <- Substitute(v, c('a', 'c'), c('A', 'C'))
        stopifnot(v.s[1] == 'A')
        stopifnot(v.s[2] == 'b')
        stopifnot(v.s[3] == 'C')
        stopifnot(length(v.s) == 3)
    }
    Test2 <- function() {
        v <- c('avg.commute.time', 'x')
        old.values <- c('avg.commute.time')
        new.values <- c('commute')
        v.s <- Substitute(v, old.values, new.values)
        stopifnot(v.s[1] == 'commute')
        stopifnot(v.s[2] == 'x')
    }
    Test1()
    Test2()
}

Substitute.Test()

###############################################################################
# Subset selection
###############################################################################
Is2003OrBefore2004Last10 <- function(df) {
    (df$sale.year == 2003) | Is2004First90(df)
}

Is2004AprilUntilLast10 <- function(df) {
    # return selector vector for transactions in April, May, ..., Nov 24 of 2004
    Is2004First90(df) & df$sale.month >= 4
}

Is2004JulyUntilLast10 <- function(df) {
    # return selector vector for transactions in July, Aug, ..., Nov 24 of 2004
    Is2004First90(df) & df$sale.month >= 7
}

Is2004First90 <- function(df) {
    # return selector vector for transactions in first 90% of 2004
    (df$sale.year == 2004) &
    ((df$sale.month <= 11) & (df$sale.day <= 24) | (df$sale.month <= 10))
}

Is2004Last10 <- function(df) {
    # return selector vector for transactions in last 10% of 2004
    # 2004 had 366 days, so first date in last 10% was Nov 25
    (df$sale.year == 2004) & 
    ((df$sale.month == 12) | ((df$sale.month == 11) & (df$sale.day >= 25)))
}

IsBefore2004Last10 <- function(df) {
    (df$sale.year < 2004) | Is2004First90(df)
}

test.subset.selectors <- function() {
    df <- data.frame(sale.year =  c( 2002, 2003,  2004,   2004,   2004, 2004,  2004,  2004,  2005),
                     sale.month = c(    1,   12,     1,     04,     10,   11,    11,    12,     1),
                     sale.day   = c(    1,   31,     1,     01,     31,   24,    25,    31,     1))

    is2003OrBefore2004Last10 <-   c(FALSE,  TRUE,  TRUE,  TRUE,  TRUE,  TRUE, FALSE, FALSE, FALSE)
    is2004AprilUntilLast10 <-     c(FALSE, FALSE, FALSE,  TRUE,  TRUE,  TRUE, FALSE, FALSE, FALSE)
    is2004JulyUntilLast10 <-      c(FALSE, FALSE, FALSE, FALSE,  TRUE,  TRUE, FALSE, FALSE, FALSE)
    is2004First90 <-              c(FALSE, FALSE,  TRUE,  TRUE,  TRUE,  TRUE, FALSE, FALSE, FALSE)
    is2004Last10  <-              c(FALSE, FALSE, FALSE, FALSE, FALSE, FALSE,  TRUE,  TRUE, FALSE)
    isBefore2004Last10 <-         c( TRUE,  TRUE,  TRUE,  TRUE,  TRUE,  TRUE, FALSE, FALSE, FALSE)

    stopifnot(all(is2003OrBefore2004Last10 == Is2003OrBefore2004Last10(df)))
    stopifnot(all(is2004AprilUntilLast10 == Is2004AprilUntilLast10(df)))
    stopifnot(all(is2004JulyUntilLast10 == Is2004JulyUntilLast10(df)))
    stopifnot(all(is2004First90 == Is2004First90(df)))
    stopifnot(all(is2004Last10  == Is2004Last10(df)))
    stopifnot(all(isBefore2004Last10 == IsBefore2004Last10(df)))
}
test.subset.selectors()

###############################################################################
# Create lists of predictors
###############################################################################

PredictorsForward <- function() {
    # return chr vector of predictors find by experiment 6 (a forward step-wise regression)
    # to be of significance
    c('centered.log.land.square.footage',
      'centered.log.living.area',
      'centered.log.land.value',
      'centered.log.improvement.value',
      'centered.year.built',
      'centered.log1p.bedrooms',
      'centered.log1p.bathrooms',
      'centered.log1p.parking.spaces',
      'centered.log.median.household.income',
      'centered.fraction.owner.occupied',
      'centered.avg.commute.time',
      'centered.latitude',
      'centered.longitude',
      'factor.is.new.construction',
      #'factor.foundation.type',
      #'factor.roof.type',
      #'factor.parking.type',
      'factor.has.pool')
}

PredictorsChopraCenteredLog <- function() {
    # return chr vector of predictors used by Chopra that we have access to
    # NOTE: Chopra had school district quality, which we don't have
    c('centered.log.land.square.footage',
      'centered.log.living.area',
      'centered.log.land.value',
      'centered.log.improvement.value',
      'centered.year.built',
      'centered.log1p.bedrooms',
      'centered.log1p.bathrooms',
      'centered.log1p.parking.spaces',
      'centered.log.median.household.income',
      'centered.fraction.owner.occupied',
      'centered.avg.commute.time',
      'centered.latitude',
      'centered.longitude',
      'factor.is.new.construction',
      'factor.foundation.type',
      'factor.roof.type',
      'factor.parking.type',
      'factor.has.pool')
}

PredictorsChopraCentered <- function() {
    # return chr vector of centered predictors used by Chopra that we have access to
    # NOTE: Chopra had school district quality, which we don't have
    c('centered.land.square.footage',
      'centered.living.area',
      'centered.land.value',
      'centered.improvement.value',
      'centered.year.built',
      'centered.bedrooms',
      'centered.bathrooms',
      'centered.parking.spaces',
      'centered.median.household.income',
      'centered.fraction.owner.occupied',
      'centered.avg.commute.time',
      'centered.latitude',
      'centered.longitude',
      'factor.is.new.construction',
      'factor.foundation.type',
      'factor.roof.type',
      'factor.parking.type',
      'factor.has.pool')
}

PredictorsChopraRaw <- function() {
    # return chr vector of raw predictors used by Chopra that we have access to
    # NOTE: Chopra had school district quality, which we don't have
    c('land.square.footage',
      'living.area',
      'land.value',
      'improvement.value',
      'year.built',
      'bedrooms',
      'bathrooms',
      'parking.spaces',
      'median.household.income',
      'fraction.owner.occupied',
      'avg.commute.time',
      'latitude',
      'longitude',
      'factor.is.new.construction',
      'factor.foundation.type',
      'factor.roof.type',
      'factor.parking.type',
      'factor.has.pool')
}

PredictorsBCHRaw <- function() {
    # return chr vector of raw predictors used by Chopra that we have access to
    # NOTE: Chopra had school district quality, which we don't have
    # Exclude tax assessor's value estimates
    c('land.square.footage',
      'living.area',
      'year.built',
      'bedrooms',
      'bathrooms',
      'parking.spaces',
      'median.household.income',
      'fraction.owner.occupied',
      'avg.commute.time',
      'latitude',
      'longitude',
      'factor.is.new.construction',
      'factor.foundation.type',
      'factor.roof.type',
      'factor.parking.type',
      'factor.has.pool')
}




###############################################################################
## Create models of price and log(price)
###############################################################################

MakeModelForward <- function() {
    # create linear model that fits on Nov 2004 and tests on Dec 2004
    # Value: list(Fit=,Predict=,description=), such that
    # $Fit(df, training.indices) --> fitted
    # $Predict(fitted, df, testing.indices) --> list(predicted= [,actual=])
    # $description : chr, informal description

    # ref: cookbook p 281

    Fit <- function(df, training.indices) {
        training.data <- df[training.indices & df$sale.year == 2004 & df$sale.month == 11, ]
        min.model <- lm(formula = 'log.price ~ 1',
                        data = training.data)
        all.features <- paste('~ land.square.footage',
                              '+ centered.log.land.square.footage',
                              '+ living.area',
                              '+ centered.log.living.area')
        scope.formula <- as.formula(all.features)
        step.model <- step(min.model,
                           direction = 'forward',
                           scope = scope.formula)
        if (verbose) {
            cat('step.model\n')
            step.model
            print(summary(step.model))
        }
        step.model
    }

    Predict <- function(fitted, df, training.indices) {
        stop('write me')
    }

    list(Fit = Fit,
         Predict = Predict,
         description = 'select best model using step-wise forward procedure')
}

MakeModelRandomForest <- function(training.start.month, response, predictors) {
    verbose <- TRUE

    Fit <- function(df, training.indices) {
        if (verbose) {
            cat('fitting random forest with starting month', training.start.month, '\n')
        }
        the.formula <- as.formula(paste0(paste0(response, '~'),
                                         paste(predictors, collapse = '+')))
        subset.training.indices <- (df$sale.year == 2004 & 
                                    df$sale.month >= training.start.month &
                                    df$sale.month <= 10 &
                                    training.indices)
        reduced.data <- na.omit(df[subset.training.indices, ])
        fitted <- randomForest(x = reduced.data[, predictors],
                               y = reduced.data[, 'price'],
                               do.trace = 1,
                               ntree = 10,
                               importance = TRUE)
        if (verbose) {
            cat('fitted\n')
            print(fitted)
            cat('summary\n')
            print(summary(fitted))
        }
        fitted
    }

    modelTree <- MakeModelTree(training.start.month, response, predictors)
    
    list(Fit = Fit,
         Predict = modelTree$Predict,
         description = sprintf('random forest %s start %d', response, training.start.month))
}

MakeModelTree <- function(training.start.month, response, predictors) {
    verbose <- TRUE

    Fit <- function(df, training.indices) {
        if (verbose) {
            cat('fitting tree model with starting month', training.start.month, '\n')
        }
        the.formula <- as.formula(paste0(paste0(response, '~'),
                                         paste(predictors, collapse = '+')))
        subset.training.indices <- (df$sale.year == 2004 & 
                                    df$sale.month >= training.start.month &
                                    df$sale.month <= 10 &
                                    training.indices)
        fitted <- tree(formula = the.formula,
                       data = df,
                       subset = subset.training.indices,
                       split = 'deviance')
        if (verbose) {
            cat('fitted tree\n')
            print(fitted)
            cat('summary fitted\n')
            print(summary(fitted))
            plot(fitted, type = 'uniform')
            text(fitted, pretty = 0)
            title(main = 'Price')
        }
        if (FALSE) {
            # cross validate to find best tree variables
            cv.fitted <- cv.tree(fitted) # prune tree
            if (verbose) {
                cat('cv.fitted tree\n')
                print(cv.fitted)
                print('summary cv.fitted\n')
                print(summary(cv.fitted))
            }
            stop('examine cv.fitted')
        }
        fitted
    }

    response.is.missing <- missing(response)

    Predict <- function(fitted, df, testing.indices) {
        if (verbose) {
            cat('predicting tree model with training.start.month', training.start.month, '\n')
        }
        subset.testing.indices <- (df$sale.year == 2004 &
                                   df$sale.month == 12 &
                                   testing.indices)
        if (response.is.missing) {
            newdata <- na.omit(df[subset.testing.indices, predictors])
            predicted <- predict(fitted, newdata)
            list(predicted = predicted)
        } else {
            # newdata here and above may be different, because of the inclusiong of
            # the response variable here (which is omitted above)
            newdata <- na.omit(df[subset.testing.indices, c(response, predictors)])
            predicted <- predict(fitted, newdata)
            list(predicted = predicted,
                 actual = newdata[[response]])
        }
    }

    list(Fit = Fit,
         Predict = Predict,
         description = sprintf('tree %s start %d', response, training.start.month))
}

MakeModelLinear <- function(training.start.month, response, predictors) {
    # create linear model that tests on Nov 2004 data
    # Arguments:
    # response   : chr scalar, column name of response feature
    # predictors : chr vector, column names of predictors
    # Value: list(Fit=,Predict=,description=), such that
    # $Fit(df, training.indices) --> fitted
    # $Predict(fitted, df, testing.indices) --> list(predicted= [,actual=])
    # $description : chr, informal description

    verbose <- FALSE
    verbose <- TRUE

    if (verbose) {
        cat('starting MakeModelLinear\n')
        cat('respone', response, '\n')
        cat('predictors', predictors, '\n')
    }

    Fit <- function(df, training.indices) {
        if (verbose) {
            cat('fitting linear model with training.start.month', training.start.month, '\n')
        }
        the.formula <- as.formula(paste0(paste0(response, '~'),
                                         paste(predictors, collapse = '+')))
        subset.training.indices <- (df$sale.year == 2004 & 
                                    df$sale.month >= training.start.month &
                                    df$sale.month <= 10 &
                                    training.indices)
        fitted <- lm(formula = the.formula,
                     data = df,
                     subset = subset.training.indices)
        if (verbose) {
            cat('fitted model\n')
            fitted
            print(summary(fitted))
        }
        fitted
    }

    response.is.missing <- missing(response)

    Predict <- function(fitted, df, testing.indices) {
        if (verbose) {
            cat('predicting linear model with training.start.month', training.start.month, '\n')
        }
        subset.testing.indices <- (df$sale.year == 2004 &
                                   df$sale.month == 12 &
                                   testing.indices)
        if (response.is.missing) {
            newdata <- na.omit(df[subset.testing.indices, predictors])
            predicted <- predict.lm(fitted, newdata)
            list(predicted = predicted)
        } else {
            # newdata here and above may be different, because of the inclusiong of
            # the response variable here (which is omitted above)
            newdata <- na.omit(df[subset.testing.indices, c(response, predictors)])
            predicted <- predict.lm(fitted, newdata)
            list(predicted = predicted,
                 actual = newdata[[response]])
        }
    }

    list(Fit = Fit,
         Predict = Predict,
         description = paste('linear trained from month', training.start.month))
}

MakeModelLinearLogPrice <- function(training.start.month) {
    modelLinear <- MakeModelLinear(training.start.month = training.start.month,
                                   response = 'log.price',
                                   predictor = PredictorsChopraCenteredLog())

    Predict <- function(fitted, df, testing.indices) {
        # return prices and actuals, not log(prices) and log(actuals)
        result <- modelLinear$Predict(fitted, df, testing.indices)
        list(predicted = exp(result$predicted),
             actual = exp(result$actual))
    }

    list(Fit = modelLinear$Fit,
         Predict = Predict,
         description = sprintf('linear log.price start %d',
                               training.start.month))
}

###############################################################################
# Select models to compare
###############################################################################

ModelsLinearLogPrice <- function() {
    list(MakeModelLinearLogPrice(1),  # training data starts in Jan 2004
         MakeModelLinearLogPrice(2),  # training data starts in Feb 2004
         MakeModelLinearLogPrice(3),  # training data starts in Mar 2004
         MakeModelLinearLogPrice(4),  # training data starts in Apr 2004
         MakeModelLinearLogPrice(5),  # training data starts in May 2004
         MakeModelLinearLogPrice(6),  # training data starts in Jun 2004
         MakeModelLinearLogPrice(7),  # training data starts in Jul 2004
         MakeModelLinearLogPrice(8),  # training data starts in Aug 2004
         MakeModelLinearLogPrice(9))  # training data starts in Sep 2004
    #MakeModelLinearLogPrice(10))  # training data starts in Oct 2004
}

MakeModelLinearPrice <- function(training.start.month) {
    modelLinear <- MakeModelLinear(training.start.month = training.start.month,
                                   response = 'price',
                                   predictor = PredictorsChopraCentered())
    list(Fit = modelLinear$Fit,
         Predict = modelLinear$Predict,
         description = sprintf('linear price start %d',
                               training.start.month))
}

ModelsLinearPrice <- function() {
    # MAYBE FIX: fails if training data is month 10 only
    list(MakeModelLinearPrice(1),  # training data starts in Jan 2004
         MakeModelLinearPrice(2),  # training data starts in Feb 2004
         MakeModelLinearPrice(3),  # training data starts in Mar 2004
         MakeModelLinearPrice(4),  # training data starts in Apr 2004
         MakeModelLinearPrice(5),  # training data starts in May 2004
         MakeModelLinearPrice(6),  # training data starts in Jun 2004
         MakeModelLinearPrice(7),  # training data starts in Jul 2004
         MakeModelLinearPrice(8),  # training data starts in Aug 2004
         MakeModelLinearPrice(9))  # training data starts in Sep 2004
}

MakeModelTreePrice <- function(training.start.month) {
    modelTree <- MakeModelTree(training.start.month = training.start.month,
                               response = 'price',
                               predictor = PredictorsChopraRaw())
    list(Fit = modelTree$Fit,
         Predict = modelTree$Predict,
         description = sprintf('tree price start %d', training.start.month))
}

ModelsTreePrice <- function() {
    list(MakeModelTreePrice(1),
         MakeModelTreePrice(2),
         MakeModelTreePrice(3),
         MakeModelTreePrice(4),
         MakeModelTreePrice(5),
         MakeModelTreePrice(6),
         MakeModelTreePrice(7),
         MakeModelTreePrice(8),
         MakeModelTreePrice(9))
}

MakeModelRandomForestPrice <- function(training.start.month) {
    modelRandomForest <- MakeModelRandomForest(training.start.month = training.start.month,
                                               response = 'price',
                                               predictor = PredictorsChopraRaw())
    list(Fit = modelRandomForest$Fit,
         Predict = modelRandomForest$Predict,
         description = sprintf('random forest price start %d', training.start.month))
}

ModelsRandomForestPrice <- function() {
    list(MakeModelRandomForestPrice(1),
         MakeModelRandomForestPrice(2),
         MakeModelRandomForestPrice(3),
         MakeModelRandomForestPrice(4),
         MakeModelRandomForestPrice(5),
         MakeModelRandomForestPrice(6),
         MakeModelRandomForestPrice(7),
         MakeModelRandomForestPrice(8),
         MakeModelRandomForestPrice(9))
}

MakeModelBCH <- function(training.start.month) {
    modelLinear <- MakeModelLinear(training.start.month = training.start.month,
                                   response = 'price',
                                   predictor = PredictorsBCHRaw())
    list(Fit = modelLinear$Fit,
         Predict = modelLinear$Predict,
         description = sprintf('linear BCH price start %d', training.start.month))

}

ModelsLinearBCHPrice <- function() {
    cat('STUB: ModelsLinearBCHPrice\n')
    list(MakeModelBCH(5))
}

ModelsOneOfEach <- function() {
    list(MakeModelLinearLogPrice(8),
         MakeModelLinearPrice(8),
         MakeModelTreePrice(8),
         MakeModelRandomForestPrice(8))
}

#models <- c(MakeModelBCH(5))
SelectModelsToTest <- function(name) {
    # return list of models to test. Each model has $Fit, $Predict, and $description
    switch(name,
           models.linear.log.price = ModelsLinearLogPrice(),
           models.linear.price = ModelsLinearPrice(),
           models.tree.price = ModelsTreePrice(),
           models.random.forest.price = ModelsRandomForestPrice(),
           models.linear.BCH.price = ModelsLinearBCHPrice(),
           models.one.of.each = ModelsOneOfEach(),
           models.all = c(ModelsLinearLogPrice(),
                          ModelsLinearPrice(),
                          ModelsTreePrice(),
                          ModelsRandomForestPrice(),
                          ModelsLinearBCHPrice()),
           ... = stop(name))

}

CompareViaCrossValidation <- function(control, transformed.data) {
    # return whatever CrossValidate2 returns
    verbose <- TRUE
    # TODO: check that log.price models are best if trained only in Oct DONE
    # TODO: compare price ~ models to log.price models
    # TODO: implement forward procedure (or backward)
    # TODO: implement tree and random forest

    models <- SelectModelsToTest('models.one.of.each')

    ErrorRate <- function(model.number, df, training.indices, testing.indices) {
        # Return error rate for model indexed by model.number after testing and fitting
        verbose <- TRUE
        if (verbose) {
            cat('\n****************************************** ')
            cat('ErrorRate started\n')
            cat(' model.number', model.number, '\n')
            cat(' df\n'); str(df)
            cat(' training.indices\n'); str(training.indices)
            cat(' testing.indices\n'); str(testing.indices)
            cat(' description', models[[model.number]]$description, '\n')
        }

        Fit <- models[[model.number]]$Fit
        Predict <- models[[model.number]]$Predict

        fitted <- Fit(df, training.indices)
        result <- Predict(fitted, df, testing.indices)
        rmse <- Rmse(actual = result$actual,
                     estimated = result$predicted)
        stopifnot(!is.nan(rmse))
        within.10.percent <- Within10Percent(actual = result$actual, 
                                             estimated = result$predicted, 
                                             precision = .10)
        list(error.rate = rmse,
             other.info = within.10.percent)
    }


    nfolds <- 5
    nmodels <- length(models) 
    result <- CrossValidate2(transformed.data, nfolds, nmodels, ErrorRate)
    cat('result\n'); str(result)
    cat('index of best model', result$best.model.index, '\n')

    # summarize predictions for generalized error
    Printf('summary for cross validation with %d folds\n', nfolds)
    df <- result$result
    for (model.index in 1:nmodels) {
        this.model.indices <- df$model.index == model.index
        Summarize <- function(model.index) {
            rmse <- mean(df[this.model.indices, 'error.rate'])
            within <- mean(df[this.model.indices, 'other.info'])
            Printf('model %2d %30s mean RMSE %f mean fraction within 10 percent %f\n',
                   model.index,
                   models[[model.index]]$description,
                   rmse,
                   within)
        }
        Summarize(model.index)
    }
    cat('end of cross validation summary\n')

    result
}

###############################################################################
## Main program
###############################################################################

Main <- function(control, transformed.data) {
    control$testing <- FALSE
    #control$testing <- TRUE
    cat('control list\n')
    str(control)

    str(transformed.data)
    print(summary(transformed.data))

    # Sumit's results: train on first 90% of 2004, predict last 10%
    # Fraction of test transactions predicted within 10% of true value
    # algo                                     fraction
    # K nearest neighbors (k=90)                  47.44%
    # Linear regression (regularized)             48.11
    # Weighted local linear regression (k=70)     58.46
    # Neural network                              60.55
    # Relational factor graph                     65.76

    result <- CompareViaCrossValidation(control, transformed.data)
    cat('Main result\n'); print(result)

    if (control$testing) {
        cat('DISCARD RESULTS: TESTING\n')
    }
}

# speed up debugging by caching the transformed data
force.refresh.transformed.data <- FALSE
if(force.refresh.transformed.data | !exists('transformed.data')) {
    transformed.data <- ReadAndTransformTransactions(control$path.subset1,
                                                     ifelse(FALSE & control$testing, 1000, -1),
                                                     TRUE)  # TRUE --> verbose
}

Main(control, transformed.data)

cat('done\n')
