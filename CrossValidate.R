source('AppendEach.R')
CrossValidate <- function(data, nfolds, models.params, Assess, verbose) {
    # perform cross validation
    # ARGS
    # data           : a data frame
    # nfolds         : numeric scalar, number of folds (ex: 10)
    # models.params  : a list of Models and parameters such that
    #   models.params[[i]] = $Model, $param; and
    #   $Model(data, training.indices, testing.indices, $param) returns a list $actual $prediction
    #      where $actual     : numeric vector of values in the training set (never NA)
    #            $prediction : numeric vector of predicts (possibly, NA)
    # Assess         : function(actual, prediction) --> list $error.rate, $<other1>, ...
    #                  evaluations of the actual and prediction results from a model
    #                  the best model is the one with the lowest error.rate
    #                  other values are returned in the data.frame all.result
    # verbose        : logical scalar, if true, we print more
    # RETURNS a list
    # $best.model.index : index i of model with lowest error.rate
    # $all.assessment   : data.frame with $fold, $model.index, $error.rate $assessment.<Assess result name>

    cat('starting CrossValidate', nrow(data), nfolds, length(models.params), '\n'); browser()

    stopifnot(nfolds <= nrow(data))

    nmodels <- length(models.params)

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
    for (this.fold in 1:nfolds) {
        is.testing <- fold == this.fold
        is.training <- !is.testing
        for (this.model.index in 1:nmodels) {
            if (verbose) {
                cat(sprintf('CrossValidate: determining error rate on model %d fold %d\n',
                            this.model.index, this.fold))
            }
            Model.param <- models.params[[this.model.index]]
            Model <- Model.param$Model
            param <- Model.param$param
            model.result <- Model(data, is.training, is.testing, param)

            actual <- model.result$actual
            prediction <- model.result$prediction
            this.assessment <- Assess(actual = actual, prediction = prediction)

            # the first assessment is the one we use to decide the best model
            this.error.rate <- this.assessment$error.rate
            if (verbose) {
                cat(sprintf('CrossValidate: error rate on model %d fold %d is %f\n',
                            this.model.index, this.fold, this.error.rate))
            }

            # accumlate results
            all.fold <- c(all.fold, this.fold)
            all.model.index <- c(all.model.index, this.model.index)
            all.error.rate <- c(all.error.rate, this.error.rate)
            all.assessment <- AppendEach(all.assessment, this.assessment)
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
    verbose <- FALSE
    data <- data.frame(x = c(1,2,3),
                       y = c(10,20,30))
    nfolds <- 2
    nModels <- 3

    Model <- function(model.data, training.indices, testing.indices, n) {
        #cat('entering Model\n'); browser()
        if (verbose) {
            print(data)
            print(training.indices)
            print(testing.indices)
        }
        stopifnot(all(training.indices | testing.indices))
        stopifnot(nrow(data) == nrow(model.data))
        stopifnot(n <= nModels && n >= 1)


        Prediction <- function() {
            #cat('starting Predition\n'); browser()
            result <- switch(n,
                             rep(n, 3),
                             c(n, n, NA),
                             c(n, NA, n))
            result
        }

        result <- list(actual = data$x, prediction = Prediction())
        result
    }

    models.params <- list(list(Model=Model, param = 1),
                          list(Model=Model, param = 2),
                          list(Model=Model, param = 3))

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

    Assess <- function(actual, prediction) {
        #cat('entering Assess\n'); browser()
        if (verbose) {
            print(actual)
            print(prediction)
        }
        result <- list(error.rate = MeanAbsError(actual = actual, prediction = prediction),
                       coverage = Coverage(actual = actual, prediction = prediction))
        result
    }

    cv.result <- CrossValidate(data = data,
                                nfolds = nfolds,
                                models.params = models.params,
                                Assess = Assess,
                                verbose = verbose)

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

CrossValidate.test()
