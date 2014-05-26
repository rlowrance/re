# CrossValidate2.R
CrossValidate2 <- function(data, nfolds, nmodels, ErrorRate, random.seed = 1) {
    # determine index of function with lowest error rate uisng nfold cross validation
    # ARGS:
    # data        : data.frame
    # nfolds      : integer > 1, number of folds
    # nmodels     : integer > 1, number of models
    # ErrorRate   : function(model.number, data, training.indices, testing.indices) 
    #               return results from training on data[training.indices,] and 
    #               testing on data[testing.indices,]
    #               value = list with elements $error.rate $other.info
    # random.seed : integer or NULL, seed for random number generator if not NULL
    # Value: list
    # $best.model.index : integer, index of model with lowest total $error.rate across folds
    # $results          : data.from with columns $fold, $model.index, $error.rate, $other.info
    verbose <- FALSE
    stopifnot(nfolds <= nrow(data))

    if (!is.null(random.seed)) {
        set.seed(random.seed)
    }

    fold.indices = rep(1:nfolds, length.out=nrow(data))  # 1 2 ... nfold 1 2 ... nfold ...
    random.obs.indices <- sample(fold.indices, nrow(data))  # randomly permute by sampling without replacement

    errors <- matrix(rep(0, nfolds * nmodels),
                     nrow = nfolds,
                     ncol = nmodels)
    all.folds <- list()
    all.model.indices <- list()
    all.results <- list()
    # start with dummy row 
    all.results <- data.frame(fold = c(0),
                              model.index = c(0),
                              error.rate = c(0),
                              other.info = c(0))
    if (verbose) {
        cat('initial all.results\n')
        str(all.results)
    }
    for (fold in 1:nfolds) {
        is.testing <- random.obs.indices == fold
        is.training <- !is.testing
        for (model.index in 1:nmodels) {
            all.model.indices <- list(all.model.indices, model.index)
            Printf('determining error rate on model %d fold %d\n', model.index, fold)
            if (verbose) {
                cat('about to call ErrorRate; fold', fold, 'model.index', model.index, '\n')
            }
            results <- ErrorRate(model.index, data, is.training, is.testing)
            if (verbose) {
                cat('CrossValidate2 ErrorRate results\n')
                print(results)
            }
            Printf(' error rate %f other info %f\n', results$error.rate, results$other.info)
            all.results <- rbind(all.results,
                                 c(fold, model.index, results$error.rate, results$other.info))
        }
    }   
    all.results <- all.results[2:nrow(all.results), ]  # drop initial dummy row
    if (verbose) {
        cat('all.results\n')
        str(all.results)
    }

    # determine index of model with lowest total error across all the folds
    best.model.index <- 0
    best.total.error <- Inf
    for (model.index in 1:nmodels) {
        this.model.indices <- all.results$model.index == model.index
        model.error <- sum(all.results[this.model.indices, 'error.rate'])
        stopifnot(!is.nan(model.error))
        if (model.error < best.total.error) {
            best.model.index <- model.index
            best.total.error <- model.error
        }  
    }
    list (best.model.index = best.model.index,
          results = all.results)
}

CrossValidate2Test <- function() {
    verbose <- FALSE

    ErrorRate <- function(model.number, data, is.training, is.testing) {
        if (FALSE & verbose) {
            cat('model.number', model.number, '\n')
            cat('data\n')
            str(data)
            cat('is.training', is.training, '\n')
            cat('is.testing', is.testing, '\n')
        }
        list(error.rate = model.number,
             other.info = model.number * 100)
    }

    df <- data.frame(a = c(1,2,3),
                     b = c(10,20,30))
    nfolds <- 3
    nmodels <- 4
    result <- CrossValidate2(df, nfolds, nmodels, ErrorRate)
    if (verbose) {
        cat('result\n')
        print(result)
    }
    stopifnot(result$best.model.index == 1)
}

CrossValidate2Test()
