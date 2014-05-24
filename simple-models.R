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
source('NumberFeaturesWithAnNA.R')
source('Printf.R')
source('ReadAndTransformTransactions.R')
source('SplitDate.R')

#library(rpart)
#library(tree)

###############################################################################
# Utility
###############################################################################

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
## ChopraLinear
###############################################################################

Accuracy <- function(actual.prices, estimated.prices) {
    # return fraction within 10 percent, dropping NA values from either input
    errors <- actual.prices - estimated.prices
    abs.relative.error <- abs(errors) / actual.prices
    within.10.percent <- abs.relative.error <= .10
    fraction.within.10.percent <- sum(within.10.percent, na.rm=TRUE) / sum(!is.na(within.10.percent))
    fraction.within.10.percent
}


PredictionAccuracy <- function(fitted.model, df, SelectTesting) {
    # return fraction of testing sample predictions with 10% of true price
    # ARGS:
    # fitted.model  : a fitted model (e.g, result of lm())
    # df            : data.frame with all observations
    # SelectTesting : function(df) --> selector vector
    # Returns fraction of predicted prices within 10% of actual price
    cat('starting PredictionAccuracy\n')
    testing.df <- df[SelectTesting(df), ]
    str(testing.df)
    print(levels(testing.df$factor.parking.type))
    log.estimated.price <- predict(fitted.model, 
                                   newdata = testing.df)
    Accuracy(exp(testing.df$log.price),
             exp(log.estimated.price))
}

LinearModelLogPrices <- function(df, SelectTraining, SelectTesting, predictors) {
    # return fraction of testing samples within 10% of true value of price
    # ARGS:
    # df : data.frame
    # SelectTraining : function(df) --> observations in training set
    # SelectTesting  : function(df) --> observations in testing set
    # predictors     : chr vector, the predictor variable names (features in df)
    # RETURN fraction of estimates within testing set that are within 10% of the actual prices
    cat('starting LinearModelLogPrices\n')
    the.formula <- as.formula(paste0(paste0('log.price', '~'),
                                     paste(predictors, collapse='+')))
    cat('the.formula\n')
    print(the.formula)

    training.df <- df[SelectTraining(df), ]
    str(training.df)
    print(levels(training.df$factor.parking.type))

    fitted.model <- lm(formula = the.formula,
                       data = training.df)
    summary(fitted.model)

    PredictionAccuracy(fitted.model, df, SelectTesting)
}

LinearModelLogPricesForward <- function(df, SelectTraining, SelectTesting, predictors) {
    # return fraction of testing samples within 10% of true value of price
    # using forward stepwise model
    # NOTE: backward model fails with an error around dataset size changing
    # ARGS:
    # df : data.frame
    # SelectTraining : function(df) --> observations in training set
    # SelectTesting  : function(df) --> observations in testing set
    # predictors     : chr vector, the predictor variable names (features in df)
    # RETURN fraction of estimates within testing set that are within 10% of the actual prices
    cat('starting LinearModelLogPricesForward\n')


    # select relevant observations and features in training set
    data <- df[SelectTraining(df), c(predictors, 'log.price') ] 

    # drop observations with an NA value
    cat('number of observations with an NA value', NumberFeaturesWithAnNA(data), '\n')
    data <- na.omit(data)  # drop observations with any NA value

    # drop predictor factors with only one level
    data <- DropFactorsWithOneLevel(data)
    
    # train the simpliest model
    min.model <- lm(formula = log.price ~ 1, 
                    data = data)
    cat('min.model\n')
    print(summary(min.model))

    # add in predictors one by one
    scope.f <- as.formula(paste0('~',
                                 paste(predictors, collapse='+')))
    str(scope.f)

    step.model <- step(min.model,
                       direction='forward',
                       scope=scope.f)
    cat('step.model\n')
    print(summary(step.model))

    PredictionAccuracy(step.model, df, SelectTesting)
}

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

PredictorsChopra <- function() {
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

ChopraLinearOLD <- function(control, df, SelectTrainingSet, step = FALSE) {
    # variations on Chopra's linear model
    cat('starting ChopraLinear\n')
    verbose <- TRUE
    # model: unweighted linear regression
    # training data: first 90% for 2004


    # some features are commented out.

    # factor.is.new.contruction:
    #  error message: contrasts can be applied only to factors with 2 or more levels
    #  hyp: this problem occurs because some observations must have NA values
    #    the test below shows that this hypothesis is false
    # factor.foundation.type
    #  error in predictions: new level UCR, but this seems like an error in R
    cat('levels in factor.is.new.construction', levels(df$factor.is.new.construction), '\n')
    cat('nlevels', nlevels(df$factor.is.new.construction), '\n')
    stopifnot(nlevels(df$factor.is.new.construction) == 2)
    cat('nlevels with na omitted', nlevels((na.omit(df))$factor.is.new.construction), '\n')
    
    # Training the model with data = df and selecting the training set does
    # not work, because some levels in some factors may be only in the test
    # data frame, resulting in an error when the predictions are made

    is.training <- SelectTrainingSet(df)
    is.testing <- Is2004Last10(df) 

    training.set <- df[is.training, ]
    testing.set <- df[is.testing, ]

    # make sure factor levels in training and testing sets are the same
    for (factor.name in c('factor.is.new.construction',
                          'factor.foundation.type',
                          'factor.roof.type',
                          'factor.parking.type',
                          'factor.has.pool')) {
        all.levels <- levels(df[[factor.name]])
        training.set[[factor.name]] <- factor(df[[factor.name]][is.training], all.levels)
        testing.set[[factor.name]] <- factor(df[[factor.name]][is.testing], all.levels)
    }

    cat('num training before dropping obs with NA values', sum(is.training), '\n')
    cat('num testing', sum(is.testing), '\n')
    stopifnot(length(is.training) > 1)
    stopifnot(length(is.testing) > 0)

    response <- 'log.price'
    predictors <- c('centered.log.land.square.footage',
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
                    
    RunModel <- function(training.set) {
        model.formula <- as.formula(paste0(paste0(response, '~'),
                                           paste(predictors, collapse='+')))
        cat('model.formula\n')
        print(model.formula)
        str(training.set)

        lm(model.formula, training.set)
    }

    m <- RunModel(training.set)
    # str(m)
    print(summary(m))

    if (step) {
        # follow cookbook p 281 to select best regression variables
        cat('starting stepBackward\n')
        # remove all the missing values in features used and re-run the base model
        # http://stackoverflow.com/questions/11819472/why-does-the-number-of-rows-change-during-aic-in-r-how-to-ensure-that-this-does
        relevant.features <- training.set[, c(predictors, response)]
        cat('relevant.features\n')
        str(relevant.features)
        cat('number of rows with na before omitting them', NumberFeaturesWithAnNA(df), '\n')
        df <- na.omit(relevant.features)  
        stopifnot(NumberFeaturesWithAnNA(df) == 0)

        # drop predictors with only one level
        # http://stackoverflow.com/questions/18171246/error-in-contrasts-when-defining-a-linear-model-in-ractor.names <- sapply(df, function(x) is.factor(x))
        df <- DropFactorsWithOneLevel(df)
        stopifnot(NumberFeaturesWithAnNA(df) == 0)
        cat('df\n')
        summary(df)

        method <- 'forward'  # NOTE: backward does not work
        if (method == 'forward') {
            f <- as.formula(paste0(response, '~ 1'))
            str(f)
            min.model <- lm(formula=f, data=df)
            summary(min.model)
            scope.f <- as.formula(paste0('~',
                                         paste(predictors, collapse='+')))
            str(scope.f)
            step.model <- step(min.model,
                               direction='forward',
                               scope=scope.f)

        } else {
            full.model <- RunModel(df)
            cat('starting stepBackward\n')
            step.model <- step(full.model,
                               direction='backward',
                               )
        }
        print(summary(step.model))
        stop('check result')
    }

    log.estimated.price <- predict(m, 
                                   newdata = testing.set)

    analysis <- data.frame(log.estimated.price = log.estimated.price)

    analysis$actual.price <- exp(df$log.price[is.testing])
    analysis$estimated.price <- exp(analysis$log.estimated.price)
    analysis$error <- analysis$actual.price - analysis$estimated.price
    analysis$abs.relative.error <- abs(analysis$error) / analysis$actual.price
    analysis$within.10.percent <- analysis$abs.relative.error <= .1

    if (FALSE) {
        cat('analysis of test set\n')
        print(analysis)
    }

    fraction.within.10.percent <- sum(analysis$within.10.percent, na.rm=TRUE) / nrow(analysis)
}

###############################################################################
## Experiment based on Chopra's linear model
###############################################################################

Experiment1 <- function(control, df) {
    # train on first 90% of transaction in 2004
    cat('starting Experiment1\n')
    list(experiment.number = 1,
         train = 'first 90% of 2004',
         test = 'last 10% of 2004',
         predictors = 'most of Chopra',
         accuracy = LinearModelLogPrices(df,
                                         SelectTraining = Is2004First90,
                                         SelectTesting = Is2004Last10,
                                         predictors = PredictorsChopra()))
}

Experiment2 <- function(control, df) {
    # train on every transaction before last 10% of 2004
    cat('starting Experiment2\n')
    list(experiment.number = 2,
         train = 'all before last 10% of 2004',
         test = 'last 10% of 2004',
         predictors = 'most of Chopra',
         accuracy = LinearModelLogPrices(df,
                                         SelectTraining = Before2004Last10,
                                         SelectTesting = Is2004Last10,
                                         predictors = PredictorsChopra()))

}

Experiment3 <- function(control, df) {
    # train on every transaction in 2003 or before last 10% of 2004
    cat('starting Experiment3\n')
    list(experiment.number = 3,
         train = '2003 or 2004 before last 10%',
         test = 'last 10% of 2004',
         predictors = 'most of Chopra',
         accuracy = LinearModelLogPrices(df,
                                         SelectTraining = Is2003OrBefore2004Last10,
                                         SelectTesting = Is2004Last10,
                                         predictors = PredictorsChopra()))
}

Experiment4 <- function(control, df) {
    # train on transations in Apr - most of Nov in 2004
    cat('starting Experiment4\n')
    list(experiment.number = 4,
         train = '2004 April until before last 10%',
         test = 'last 10% of 2004',
         predictors = 'most of Chopra',
         accuracy = LinearModelLogPrices(df,
                                         SelectTraining = Is2004AprilUntilLast10,
                                         SelectTesting = Is2004Last10,
                                         predictors = PredictorsChopra()))
}

Experiment5 <- function(control, df) {
    # train on Jan - Nov 24, then Feb - Nov 24, etc.
    # select most accurate model and return predictions from it
    # use only the features found by the forward step-wise regression to be useful
    cat('starting Experiment5\n')

    # select training data start month with highest accuracy
    best.start.month <- 0
    best.accuracy <- 0
    accuracies <- rep(0, 11)
    for (start.month in 1:11) {
        IsTraining <- function(df) {
            Is2004First90(df) & (df$sale.month >= start.month)
        }
        cat('starting experiment 5 for start.month', start.month, '\n')
        accuracy <- LinearModelLogPrices(df,
                                         SelectTraining = IsTraining,
                                         SelectTesting = Is2004Last10,
                                         predictors = PredictorsForward())
        accuracies[start.month] <- accuracy
        if (accuracy > best.accuracy) {
            best.accuracy <- accuracy
            best.start.month <- start.month
        }
    }
    cat('accuracies', accuracies, '\n')
    # NOTE: accuracy improves with shorter training period except for one month

    list(experiment.number = 5,
         train = paste('first 90% of 2004, starting in month', start.month),
         test = 'last 10% of 2004',
         predictors = 'features found significant in step-wise forward procedure',
         accuracy = best.accuracy)
}

Experiment6 <- function(control, df) {
    # select best regression variables using forward procedure
    # follow cookbook p.281 forward procedure
    # NOTE: backward procedure does not work, failing with a message about reduced number of rows
    # NOTE: should do cross-validation (see james-13 or write own)
    cat('starting Experiment6\n')
    list(experiment.number = 6,
         train = 'first 90% of 2004',
         test = 'last 10% of 2004',
         predictors = 'as selected by forward stepwise regression',
         accuracy = LinearModelLogPricesForward(df,
                                                SelectTraining = Is2004First90,
                                                SelectTesting = Is2004Last10,
                                                predictors = PredictorsChopra()))
}

###############################################################################
# Tree-based models (CART, etc.)
###############################################################################

TreeModel <- function(which, df, SelectTraining, SelectTesting, predictors) {
    if (TRUE) {
        # shorten names so that tree plot will be easier to read
        old.names <- c('avg.commute.time', 'median.household.income', 'factor.has.pool',
                       'land.value', 'improvement.value')
        new.names <- c('commute', 'income', 'pool',
                       'land', 'bldg')
        predictors <- Substitute(predictors, old.names, new.names)
        df <- RenameColumns(df, old.names, new.names)
    }

    # rescale the price by dividing by 1000
    df$price <- df$price / 1000

    the.formula <- as.formula(paste0('price ~',
                                     paste(predictors, collapse = '+')))
    cat('the.formula\n')
    print(the.formula)

    FitTree <- function() {
        fitted <- tree(formula = the.formula,
                       data = df,
                       subset = SelectTraining(df),
                       #control = tree.control(nrow(data), minsize = 2, mindev = 0),
                       split = 'deviance')
        cat('fitted\n')
        print(fitted)
        cat('str(fitted)\n')
        str(fitted)
        cat('summary(fitted)')
        print(summary(fitted))
        plot(fitted, type ='uniform')
        text(fitted, pretty=0)
        title(main='Price/1000')
        if (FALSE) {
            # cross validate to find best tree (see james-13 p 326)
            # this code fails, though it mimics james-13 p 326
            browser()
            cv.fitted <- cv.tree(fitted)  # will pruning the tree help performance?
            plot(cv.fitted$size, cv.fitted$dev, type='b')
            # Should return the tree selected by cross validation
            stop('examine cv')
        }
        fitted
    }

    FitRandomForest <- function(num.predictors.tried) {
        cat('random forest; num.predictors.tried', num.predictors.tried, '\n')
        library(randomForest)
        set.seed(1)  # for reproducability
        cat('num predictors', length(predictors), '\n')
        df <- df[SelectTraining(df), ]
        reduced.data <- na.omit(df)
        cat('nrows', nrow(reduced.data), '\n')
        fitted <- randomForest(x = reduced.data[, predictors],
                               y = reduced.data[, 'price'],
                               do.trace = 1,
                               ntree = 10,
                               importance = TRUE)
        cat('fitted\n')
        print(fitted)
        cat('summary\n')
        print(summary(fitted))
        fitted
    }

    fitted <- switch(which,
                     tree = FitTree(),
                     bag = FitRandomForest(length(predictors)),
                     randomForest = FitRandomForest(1), # default # features
                     randomForest = FitRandomForest(length(predictors) / 3), # default # features
                     stop(paste('which', which)))

    
    # predict
    features <- c(predictors, 'price')
    new.data <- na.omit(df[SelectTesting(df), features])
    str(new.data)
    predictions <- predict(fitted, newdata = new.data)
    str(predictions)
    str(new.data$price)
    cat('predictions', predictions[1:10], '\n')
    cat('actuals    ', new.data$price[1:10], '\n')
    Printf('ndx predict actual\n')
    for (i in 1:10) {
        Printf('%3d %5.1f %5.1f\n', i, predictions[i], new.data$price[i])
    }
    fraction.within.10.percent <- Accuracy(new.data$price, predictions)
    print(fraction.within.10.percent)
}

Experiment7 <- function(control, df) {
    # tree regression using library(tree)
    # Part 1: simple fit
    # Part 2: with cross validation to assess effect of pruning the tree
    # NOTE: follow james-13 p 324 (339 in pdf)
    cat('starting Experiment7\n')

    list(experiment.number = 7,
         description = 'tree',
         train = '2004: Juyly - Nov 24',
         test = 'last 10% of 2004',
         predictors = 'most of Chopra',
         accuracy = TreeModel(which = 'tree',
                              df = df,
                              SelectTraining = Is2004JulyUntilLast10,
                              SelectTesting = Is2004Last10,
                              predictors = PredictorsChopraRaw()))
}

Experiment8 <- function(control, df) {
    # tree regression using library(tree)
    # Part 1: simple fit
    # Part 2: with cross validation to assess effect of pruning the tree
    # NOTE: follow james-13 p 324 (339 in pdf)
    cat('starting Experiment8\n')
    list(experiment.number = 8,
         description = 'random forest',
         train = '2004: July - Nov 24',
         test = 'last 10% of 2004',
         predictors = 'most of Chopra',
         accuracy = TreeModel(which = 'randomForest',
                              df = df,
                              SelectTraining = Is2004JulyUntilLast10,
                              SelectTesting = Is2004Last10,
                              predictors = PredictorsChopraRaw()))
}

ExperimentsFuture <- function(control, df) {
    # zip-code based model  without latitude and longitude
    # census-track based model "
    # cross validation to find best number of months of training data
    #  -- select this variable based on whether market is rising, falling, or stable
    stop('write me')
}


###############################################################################
## Experiment based on CART
## see BetterDoctor.pdf from Stern for ideas
## consider using rpart library
## also partykit (which reads rpart models)
## also randomForest
###############################################################################

Experiment2b <- function(control, df) {
    # simple CART using best training set months
    stop('write me')
}

Experiment <- function(control, df) {
    # random forest
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


    experiments <- list(Experiment1,
                        Experiment2, 
                        Experiment3,
                        Experiment4,
                        Experiment5,
                        Experiment6,
                        Experiment7,
                        Experiment8)


    run <- 1:length(experiments)  # run all experiments
    #run <- c(4)                   # run just one experiment
    run <- c(1, 2, 3, 4, 5)
    run <- c(1, 4, 5)
    run <- c(6)
    run <- c(8)

    PrintOne <- function(result) {
        cat('experiment.number', result$experiment.number, '\n')
        cat('  description', result$description, '\n')
        cat('  train', result$train, '\n')
        cat('  test', result$test, '\n')
        cat('  predictors', result$predictors, '\n')
        cat('  fraction with 10%', result$accuracy, '\n')

    }

    results <- list()
    
    for (i in 1:length(run)) {
        experiment.number <- run[[i]]
        result <- (experiments[[experiment.number]])(control, transformed.data)
        PrintOne(result)
        results[[i]] <- result
    }

    str(run)
    for (i in 1:length(run)) {
        PrintOne(results[[i]])
    }
        

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
