# CrossValidate2.R
CrossValidate2 <- function(data, nfolds, nmodels, ErrorRate, random.seed = 1) {
    # determine index of function with lowest error rate uisng nfold cross validation
    # ARGS:
    # data        : data.frame
    # nfolds      : integer > 1, number of folds
    # nmodels     : integer > 1, number of models
    # ErrorRate   : function(model.number, data, training.indices, testing.indices) value = error rate on test set
    # random.seed : integer or NULL, seed for random number generator
    # Value: list
    # $best.model.index : integer
    # $error.rates      : matrix of error rates for each model; size nfolds x nModels
    verbose <- FALSE
    stopifnot(nfolds <= nrow(data))

    if (!is.null(random.seed)) {
        set.seed(random.seed)
    }

    random.obs.indices <- sample(1:nfolds, nrow(data), replace=TRUE)

    errors <- matrix(rep(0, nfolds * nmodels),
                     nrow = nfolds,
                     ncol = nmodels)
    for (fold in 1:nfolds) {
        is.testing <- random.obs.indices == fold
        is.training <- !is.testing
        for (model.index in 1:nmodels) {
            if (verbose) {
                cat('about to call ErrorRate; fold', fold, 'model.index', model.index, '\n')
            }
            errors[fold, model.index] <- ErrorRate(model.index, data, is.training, is.testing)
        }
    }   
    # determine index of model with lowest total error
    best.model.index <- 0
    best.total.error <- Inf
    for (model.index in 1:nmodels) {
        model.error <- 0
        for (fold in 1:nfolds) {
            model.error <- model.error + errors[fold, model.index]
        }
        if (model.error < best.total.error) {
            best.model.index <- model.index
            best.total.error <- model.error
        }  
    }
    list (best.model.index = best.model.index,
          errors = errors)
}

CrossValidate2Test <- function() {

    ModelErrorRate <- function(model.number, data, is.training, is.testing) {
        if (FALSE) {
            cat('model.number', model.number, '\n')
            cat('data\n')
            str(data)
            cat('is.training', is.training, '\n')
            cat('is.testing', is.testing, '\n')
        }
        model.number
    }

    df <- data.frame(a = c(1,2,3),
                     b = c(10,20,30))
    nfolds <- 3
    nmodels <- 4
    result <- CrossValidate2(df, nfolds, nmodels, ModelErrorRate)
    if (FALSE) {
        cat('result\n')
        print(result)
    }
    stopifnot(result$best.model.index == 1)
}

CrossValidate2Test()
