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

# source files needed to set controls
source('DateTime.R')

# set control variables
control <- list()

# pick computation to do
control$which <- 'cross.validate'

control$which.cross.validate <- 'all'
control$which.cross.validate <- 'each.once'
#control$which.cross.validate <- 'random.forest.nmonth'
#control$which.cross.validate <- 'random.forest.hp.search'
#control$which.cross.validate <- 'location.features'
#control$which.cross.validate <- 'hpi'

control$me <- 'simple-models'
control$dir.output <- '../data/v6/output/'
control$path.subset1 <- paste0(control$dir.output, 'transactions-subset1.csv')
control$path.log <- paste0(control$dir.output, 
                           control$me, 
                           '-',
                           control$which,
                           '-',
                           control$which.cross.validate,
                           '-', 
                           DateTime(), 
                           '.txt')
control$testing <- TRUE
control$testing <- FALSE


# override control using values from command line
command.line.args <- commandArgs(trailingOnly = TRUE)  # return only args after --args
stopifnot(length(command.line.args) == 0)  # for now, don't handle command line args

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
source('DuplexOutputTo.R')
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
      #'factor.foundation.type',
      'factor.roof.type',
      #'factor.parking.type',
      'factor.has.pool')
}

PredictorsChopraCenteredLogLocation <- function() {
    c(PredictorsChopraCenteredLog(),
      PredictorsLocationRaw())
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
      #'factor.foundation.type',
      'factor.roof.type',
      #'factor.parking.type',
      'factor.has.pool')
}

PredictorsChopraCenteredLocation <- function() {
    c(PredictorsChopraCentered(),
      PredictorsLocationRaw())   # no need to center, as these are factors
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

PredictorsLocationRaw <- function() {
    c('census.tract.has.industry',
      'census.tract.has.park',
      'census.tract.has.retail',
      'census.tract.has.school',
      'zip5.has.industry',
      'zip5.has.park',
      'zip5.has.retail',
      'zip5.has.school')
}

PredictorsChopraRawLocation <- function() {
    # return chr vector of raw predictors used by Chopra that we have access to
    # NOTE: Chopra had school district quality, which we don't have
    c(PredictorsChopraRaw(),
      PredictorsLocationRaw())
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


# NEW STUFF STARTS HERE

Formula <- function(response, predictors) {
    as.formula(paste0(paste0(response, '~'),
                      paste(predictors, collapse = '+')))
}

MakeModelLinear <- function(response, predictors, transform.response = 'no') {
    # return list of functions
    # $Fit(df, training.indices) --> fitted model
    # $Predict(fitted, df, testing.index) --> transformed predictions
    # $description : char

    Fit <- function(df, training.indices) {
        the.formula <- Formula(response, predictors)
        # NOTE; supplying parameter subset = trainng.indices does not work
        fitted <- lm(formula = the.formula,
                     data = df[training.indices,])
    }

    Predict <- function(fitted, df, testing.indices) {
        newdata <- na.omit(df[testing.indices, predictors])
        predicted <- predict.lm(fitted, newdata)
        switch(transform.response,
               no = predicted,
               exp = exp(predicted))
    }

    list(Fit = Fit, 
         Predict = Predict, 
         description = ifelse(transform.response == 'no', 
                              sprintf('linear %s %d predictors', 
                                      response, length(predictors)),
                              sprintf('linear %s(%s) %d predictors', 
                                      transform.response, response, length(predictors))))
}

MakeModelTree <- function(response, predictors) {
    # return list of functions
    # $Fit(df, training.indices) --> fitted model
    # $Predict(fitted, df, testing.index) --> transformed predictions
    # $description : char

    verbose <- TRUE

    Fit <- function(df, training.indices) {
        the.formula <- Formula(response, predictors)
        # NOTE; supplying parameter subset = trainng.indices does not work
        fitted <- tree(formula = the.formula,
                       data = df[training.indices,],
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

    Predict <- function(fitted, df, testing.indices) {
        newdata <- na.omit(df[testing.indices, predictors])
        predicted <- predict(fitted, newdata)
    }

    list(Fit = Fit, 
         Predict = Predict,
         description = sprintf('tree %s %d predictors', response, length(predictors)))
}

MakeModelRandomForest <- function(response, predictors, ntree) {
    # return list of functions
    # $Fit(df, training.indices) --> fitted model
    # $Predict(fitted, df, testing.index) --> transformed predictions
    # $description : chr

    verbose <- TRUE

    Fit <- function(df, training.indices) {
        the.formula <- Formula(response, predictors)
        reduced.data <- na.omit(df[training.indices, ])
        fitted <- randomForest(x = reduced.data[,predictors],
                               y = reduced.data[,'price'],
                               do.trace = 1,
                               ntree = ntree,
                               importance = TRUE)
        if (verbose) {
            cat('fitted random forest\n')
            print(fitted)
            cat('summary fitted\n')
            print(summary(fitted))
        }
        fitted
    }

    Predict <- function(fitted, df, testing.indices) {
        newdata <- na.omit(df[testing.indices, predictors])
        predicted <- predict(fitted, newdata)
    }

    list(Fit = Fit, 
         Predict = Predict,
         description = sprintf('random forest %s %d predictors %d trees', 
                               response, length(predictors), ntree))
}

first.testing.date <- as.Date('2009-01-01')
last.testing.date <- first.testing.date + 30

ErrorRateModel <- function(model, 
                           df, training.indices, testing.indices,
                           training.months.before, response, predictors) {
    first.training.date <- first.testing.date - training.months.before * 30
    selected.training <- training.indices & df$saleDate >= first.training.date & df$saleDate < first.testing.date

    selected.testing <- testing.indices & df$saleDate >= first.testing.date & df$saleDate <= last.testing.date

    fitted <- model$Fit(df, selected.training)
    estimated <- model$Predict(fitted, df, selected.testing)  # estimates are for price (never log.price)
    
    # reconstruct data frame used for estimated
    newdata <- na.omit(df[selected.testing, c('price', predictors)])
    actual <- newdata$price

    list(rmse = Rmse(actual = actual, estimated = estimated),
         within.10.percent = Within10Percent(actual = actual, estimated = estimated),
         description = paste(model$description, 
                             sprintf('%d months', training.months.before)))
}

ErrorRateLinear <- function(df, training.indices, testing.indices,
                            training.months.before, response, predictors) {
    # return $rmse and $within.10.percent for linear model training and fitted
    #model <- MakeModelLinear(response, predictor)
    model <- MakeModelLinear(response, predictors, transform.response = 'no')
    ErrorRateModel(model, 
                   df, training.indices, testing.indices,
                   training.months.before, response, predictors)
}



ErrorRateLinearLog <- function(df, training.indices, testing.indices,
                               training.months.before, response, predictors) {
    # return $rmse and $within.10.percent for log linear model training and fitted
    model <- MakeModelLinear(response, predictors, transform.response = 'exp')
    ErrorRateModel(model, 
                   df, training.indices, testing.indices,
                   training.months.before, response, predictors)
}

ErrorRateTree <- function(df, training.indices, testing.indices,
                          training.months.before, response, predictors) {
    # return $rmse and $within.10.percent for tree model training and fitted
    model <- MakeModelTree(response, predictors)
    ErrorRateModel(model, 
                   df, training.indices, testing.indices,
                   training.months.before, response, predictors)
}

ErrorRateRandomForest <- function(df, training.indices, testing.indices,
                                  training.months.before, response, ntree, predictors) {
    # return $rmse and $within.10.percent for tree model training and fitted
    model <- MakeModelRandomForest(response, predictors, ntree)
    ErrorRateModel(model, 
                   df, training.indices, testing.indices,
                   training.months.before, response, predictors)
}

SummarizeCrossValidationResult <- function(result, nfolds, nmodels) {
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
            description <- df[this.model.indices, 'description'][1]
            Printf('model %2d mean (RMSE %f within 10 percent %f) %s\n',
                   model.index,
                   rmse,
                   within,
                   description)
        }
        Summarize(model.index)
    }
    cat('end of cross validation summary\n')
}

RandomForestHpSearchPrep <- function(nsamples) {
    # return two vectors of length 10
    # $samples.training.months
    # $samples.ntrees
    # Randomly sample from 
    #  training.months in {1, 2, ..., 12}
    #  ntrees in {2^0,2^2, 2^2, 2^3, 2^4, 2^5, 2^6, 2^7, 2^8} = (1,2,4,7,16,32,64,128,256}
    result <- list()
    result$training.months <- sample(seq(from=1, to=12, by=1), nsamples, replace = TRUE)
    result$ntrees <- sample(2^(sample(seq(from=0, to=8, by=1), nsamples, replace = TRUE)))
    result
}

random.forest.samples <- RandomForestHpSearchPrep(10)

CompareViaCrossValidation <- function(control, transformed.data) {
    # cross validate models named via control$which.cross.validate chr

    ErrorRate <- function(model.number, df, training.indices, testing.indices) {
        # return $error.rate and $other.info

        Rename <- function(lst, features.name) {
            # rename list of results to conform to API for CrossValidate2
            # also propogate the feature name into the description
            list(error.rate = lst$rmse,
                 other.info = lst$within.10.percent,
                 description = paste(lst$description, features.name))
        }

        Features <- function(features.name) {
            # return feature set
            switch(features.name,
                   centered = PredictorsChopraCentered(),
                   centered.location = PredictorsChopraCenteredLocation(),
                   centered.log = PredictorsChopraCenteredLog(),
                   centered.log.location = PredictorsChopraCenteredLogLocation(),
                   raw = PredictorsChopraRaw(),
                   raw.location = PredictorsChopraRawLocation(),
                   ... = stop(paste('bad features.name', features.name)))
        }




        A <- function(training.months, features.name = 'centered') {
            Rename(ErrorRateLinear(df, training.indices, testing.indices, 
                                   training.months, 'price', 
                                   Features(features.name)),
                   features.name)
                   
        }

        B <- function(training.months, features.name = 'centered.log') {
            Rename(ErrorRateLinearLog(df, training.indices, testing.indices, 
                                      training.months, 'log.price', 
                                      Features(features.name)),
                   features.name)



        }

        C <- function(training.months, features.name = 'raw') {
            Rename(ErrorRateTree(df, training.indices, testing.indices,
                                 training.months, 'price',
                                 Features(features.name)),
                   features.name)

        }
                    
        D <- function(training.months, ntree = 100, features.name = 'raw') {
            Rename(ErrorRateRandomForest(df, training.indices, testing.indices,
                                         training.months, 'price', ntree,
                                         Features(features.name)),
                   features.name)
        }

        HPI <- function(prior.index.months, index.name) {
            Rename(ErrorRateIndex(df, training.indices, testing.indices,
                                  prior.index.months, index.name),
                   paste('index', index.name))
        }

        RandomForestHpSearch <- function(model.number) {
            # NOTE: THIS FUNCTION FAILS BECAUSE
            #  the first set of hyperparameters leads to a model with 5 or fewer responses
            # This model hadl 11 months and 64 trees
            # Instead randomly sample from 
            #  training.months in {1, 2, ..., 12}
            #  ntrees in {2^0,2^1, 2^2, 2^2, 2^3, 2^4, 2^5, 2^6, 2^7, 2^8} = (1,2,4,7,16,32,64,128,256}
            training.months <- random.forest.samples$training.month[[model.number]]
            ntree <- random.forest.samples$ntree[[model.number]]
            cat('RandomForestHpSearch', 'training.months', training.months, 'ntree', ntree, '\n')
            Rename(D(training.months, ntree))
        }


        switch(control$which.cross.validate,

               hpi = switch(model.number,
                            HPI(prior.index.months = 3, index.name = 'CS'),
                            HPI(prior.index.months = 3, index.name = 'Zip5')),

               location.features = switch(model.number,  # compare best model form w and wo location features
                                          A(1, 'centered.location'), A(1, 'centered'),
                                          B(2, 'centered.log.location'), B(2, 'centered.log'),
                                          C(7, 'raw.location'), C(7, 'raw'),
                                          D(11, 256, 'raw.location'), D(11, 256, 'raw')
                                          ),

               all =  # all models without location features
                   switch(model.number,   
                          A(1), A(2), A(3), A(4), A(5), A(6), A(7), A(8), A(9), A(10), A(11), A(12),
                          B(1), B(2), B(3), B(4), B(5), B(6), B(7), B(8), B(9), B(10), B(11), B(12),
                          C(1), C(2), C(3), C(4), C(5), C(6), C(7), C(8), C(9), C(10), C(11), C(12),
                          D(9,64), D(10,64), D(11,64),      # implicitly raw
                          D(9,256), D(10,256), D(11,256),   # implicitly raw
                          D(9,64,'raw.location'),  D(10,64,'raw.location'),  D(11,64,'raw.location'),
                          D(9,256,'raw.location'), D(10,256,'raw.location'), D(11,256,'raw.location')
                          ),
               
               each.once =
                   switch(model.number,
                          A(1), B(1),C(1), D(1, 10)
                          ),

               random.forest.nmonth =
                   # RESULT: For 100 trees, RMSE is minimized when using 2 months of training data
                   switch(model.number,
                                 D(1,100), D(2,100), D(3,100), D(4,100), D(5,100), D(6,100),
                                 D(7,100), D(8,100), D(9,100), D(10,100), D(11,100), D(12,100)
                                 ),

               random.forest.hp.search = # Search randomly over two hyperparmaters
                   # RESULT: best is 256 trees using 8 months of training data

                   # good performance with 9 - 11 months
                   # months    |   1   3   3   3   8   8   9  11  11  12
                   # RMSE/1000 | 221 209 206 213 202 233 206 206 208 222
                
                  # good performance with 64 trees
                  # best performance with more trees
                  #  trees     |   2   8   8  16  32  64  64  64 256 256
                  #  RMSE/1000 | 233 222 213 209 221 206 208 206 202 206
               
                   RandomForestHpSearch(model.number)
               )
    }

    nfolds <- 5
    nmodels <- switch(control$which.cross.validate, # must match switch statement in ErrorRate above
                      location.features = 8,
                      all = 12 * 3 + 6 *2,
                      each.once = 4,
                      random.forest.nmonth = 12,
                      random.forest.hp.search = 10)
    result <- CrossValidate2(transformed.data, nfolds, nmodels, ErrorRate)
    SummarizeCrossValidationResult(result, nfolds, nmodels)
    result
}


###############################################################################
## Main program
###############################################################################

Main <- function(control, transformed.data) {
    verbose <- TRUE
    verbose <- FALSE

    cat('control list\n')
    str(control)

    if (verbose) {
        str(transformed.data)
        print(summary(transformed.data))
        is.2009 <- transformed.data$sale.year == 2009
        print('summary of transaction in year 2009')
        print(summary(transformed.data[is.2009, ]))
    }

    # Sumit's results: train on first 90% of 2004, predict last 10%
    # Fraction of test transactions predicted within 10% of true value
    # algo                                     fraction
    # K nearest neighbors (k=90)                  47.44%
    # Linear regression (regularized)             48.11
    # Weighted local linear regression (k=70)     58.46
    # Neural network                              60.55
    # Relational factor graph                     65.76
    #
    # TODO: ADD SUMIT's RESULTS FOR 2009

    if (control$which == 'cross.validate') {
        result <- CompareViaCrossValidation(control, transformed.data)
        cat('Main result\n'); print(result)
    } else {
        stop(paste('bad control$which', control$which))
    }

}

# speed up debugging by caching the transformed data
force.refresh.transformed.data <- TRUE
force.refresh.transformed.data <- FALSE
if(force.refresh.transformed.data | !exists('transformed.data')) {
    transformed.data <- ReadAndTransformTransactions(control$path.subset1,
                                                     ifelse(FALSE & control$testing, 1000, -1),
                                                     TRUE)  # TRUE --> verbose
}
CvAll <- function(control, transformed.data) {
    # cross validate all models to select best model
}

CvEachOne <- function(control, transformed.data) {
    # run each model once, to check syntax
}

CvRandomForestnTrees <- function(control, transformed.data) {
    # cv to select best number of trees in random forest models
}





Main(control, 
     transformed.data)

cat('control variables\n')
str(control)

if (control$testing) {
    cat('DISCARD RESULTS: TESTING\n')
}

cat('done\n')
