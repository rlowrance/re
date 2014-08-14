source('Require.R')
Require('ListAppendEach')
CrossValidate <- function(data, nfolds, Models, Assess, experiment) {
    # perform cross validation
    # ARGS
    # data           : a data frame
    # nfolds         : numeric scalar, number of folds (ex: 10)
    # Models         : a list of functions such that calling the call
    #                  Models[[i]](data, training.indices, testing.indices) yields
    #                  a list with elements $actual and $prediction
    #                  where $actual     : numeric vector of values in the training set (never NA)
    #                        $prediction : numeric vector of predicts (possibly NA)
    # Assess         : function(<Models[[i]] returned value>) --> list <error rates>
    #                  yields evaluations of the actual and prediction results from a model
    #                  the best model is the one with the lowest <error rates>[[1]]
    #                  all <error rates> are returned in the data.frame all.result
    # experiment     : chr scalar, vector of names for experiments
    # RETURNS a list
    # $best.model.index : index i of model with lowest error.rate
    # $all.assessment   : data.frame with $fold, $model.index, $error.rate $assessment.<Assess result name>

    #cat('starting CrossValidate', nrow(data), nfolds, length(Models), '\n'); browser()

    stopifnot(nfolds <= nrow(data))

    verbose <- TRUE

    nmodels <- length(Models)

    fold.indices = rep(1:nfolds, length.out=nrow(data))  # 1 2 ... nfold 1 2 ... nfold ...

    # assign each sample randomly to a fold
    fold.1.to.n <- rep(1:nfolds, length.out=nrow(data))  # 1 2 ... nfold 1 2 ... nfold ...
    fold <- sample(fold.1.to.n, nrow(data))

    # accumulate results in these parallel vectors
    all.fold <- NULL
    all.model.index <- NULL
    all.error.rate <- NULL
    all.assessment <- NULL

    # examine each fold and each model
    debugging <- TRUE
    debugging <- FALSE
    for (this.fold in 1:nfolds) {
        if (debugging && this.fold != 5 && this.fold != 9) {
            cat('skipping this.fold', this.fold, '\n');
            next
        }
        is.testing <- fold == this.fold
        is.training <- !is.testing
        for (this.model.index in 1:nmodels) {
            if (debugging && this.model.index != 2 && this.model.index != 3) {
                cat('skipping this.model.index', this.model.index, '\n')
                next
            }

            if (verbose) {
                cat(sprintf('CrossValidate %s: determining error rate on model %d fold %d\n',
                            experiment[[this.model.index]], this.model.index, this.fold))
            }

            Model <- Models[[this.model.index]]
            model.result <- Model(data, is.training, is.testing)
            #cat('model.result\n'); browser()
            this.assessment <- Assess(model.result)
            #cat('examine this.assessment in CrossValidate\n'); browser()
            stopifnot(is.list(this.assessment))

            # the first assessment is the one we use to decide the best model
            #cat('in CV, checking assessment\n'); browser()
            this.error.rate <- this.assessment[[1]]  
            stopifnot(length(this.error.rate) == 1)
            if (verbose) {
                cat(sprintf('CrossValidate %s: error rate on model %d fold %d is %f\n',
                            experiment[[this.model.index]], this.model.index, this.fold, this.error.rate))
            }

            # accumlate results
            # NOTE: we throw away the model.result, relying on the Assess function to
            # reduce the model.result to a list of scalar values
            #cat('in CrossValidate, accumulate results\n'); browser()
            all.fold <- c(all.fold, this.fold)
            all.model.index <- c(all.model.index, this.model.index)
            all.error.rate <- c(all.error.rate, this.error.rate)
            all.assessment <- ListAppendEach(all.assessment, this.assessment)
        }
    }   

    # create data frame with all results for all models and folds
    #cat('in CV: building all.results\n'); browser()

    fold.assessment <- data.frame(fold = all.fold,
                                  model.index = all.model.index,
                                  error.rate = all.error.rate,
                                  assessment = all.assessment)
    if (verbose) {
        cat('fold.assessment\n')
        str(fold.assessment)
        print(fold.assessment)
    }

    # determine best model to be the one with the lowest error rate on average across the folds
    best.average.error.rate <- Inf
    for (this.model.index in 1:nmodels) {
        in.model <- fold.assessment$model.index == this.model.index
        this.average.error.rate <- mean(fold.assessment$error.rate[in.model])
        if (this.average.error.rate < best.average.error.rate) {
            best.average.error.rate <- this.average.error.rate
            best.model.index <- this.model.index
        }
    }

    result <- list (best.model.index = best.model.index,
                    fold.assessment = fold.assessment)
    result
}

CrossValidate.test <- function() {
    # unit test

    experiment <- NULL 
    #experiment <- 'unit test'
    verbose <- is.character(experiment)

    data <- data.frame(x = c(1,2,3),
                       y = c(10,20,30))
    nfolds <- 2
    nModels <- 3

    MakeModel <- function(model.index) {
        n <- model.index  # force evaluation, or this code doesn't work

        Model <- function(model.data, training.indices, testing.indices) {
            if (verbose) {
                cat('entering Model\n'); browser()
                print(data)
                print(training.indices)
                print(testing.indices)
            }
            stopifnot(all(training.indices | testing.indices))
            stopifnot(nrow(data) == nrow(model.data))

            Prediction <- function() {
                #cat('starting Predition\n'); browser()
                result <- switch(model.index,
                                 rep(n, 3),
                                 c(n, n, NA),
                                 c(n, NA, n))
                result
            }

            result <- list(actual = data$x, prediction = Prediction())
            result
        }

        Model
    }

    Models <- lapply(1:nModels, MakeModel)


    MeanAbsError <- function(actual, prediction) {
        #cat('entering MeanAbsError\n'); browser()
        good.prediction <- !is.na(prediction)
        abs.error <- abs(actual[good.prediction] - prediction[good.prediction])
        result <- mean(abs.error)
        result
    }

    Coverage <- function(actual, prediction) {
        #cat('entering Coverage\n'); browser()
        result <- sum(!is.na(prediction)) / sum(!is.na(actual))
        result
    }

    Assess <- function(model.result) {
        #cat('entering Assess\n'); browser()
        if (verbose) {
            print('Assess')
            print(model.result)
        }
        actual <- model.result$actual
        prediction <- model.result$prediction
        result <- list(error.rate = MeanAbsError(actual = actual, prediction = prediction),
                       coverage = Coverage(actual = actual, prediction = prediction))
        if (verbose) {print(result$error.rate)}
        result
    }

    cv.result <- CrossValidate(data = data,
                               nfolds = nfolds,
                               Models = Models,
                               Assess = Assess,
                               experiment = NULL)

    if (verbose) {
        print('cv.result')
        print(cv.result)
    }
    best.model.index <- cv.result$best.model.index
    fold.assessment <- cv.result$fold.assessment
    stopifnot(best.model.index == 2)
    stopifnot(nrow(fold.assessment) == nfolds * nModels)
    if (verbose) {
        fold.assessment.names <- names(fold.assessment)
        print(fold.assessment.names)
    }

    HasName <- function(str) {
        stopifnot(!is.null(fold.assessment[[str]]))
    }

    HasName('fold')
    HasName('model.index')
    HasName('error.rate')
    HasName('assessment.error.rate')
    HasName('assessment.coverage')
}

#CrossValidate.test()
