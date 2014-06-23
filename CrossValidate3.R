source('AppendEach.R')
CrossValidate3 <- function(data, nfolds, models.params, verbose) {
    # perform cross validation
    # ARGS
    # data           : a data frame
    # nfolds         : numeric scalar, number of folds (ex: 10)
    # models.params  : a list of Models and parameters such that
    #   models.params[[i]] = $Model, $param; and
    #   $Model(data, training.indices, testing.indices, $param) returns a list of evaluations of model i
    #   The first such evalution is called the error.rate
    #   The model with the lowest error.rate is selected as the best model
    # verbose        : logical scalar, if true, we print more
    # RETURNS a list
    # $best.model.index : index i of model with lowest error.rate
    # $all.results      : data.frame with $fold, $model.index, $error.rate $evaluation

    cat('starting CrossValidate3', nrow(data), nfolds, length(models.params), '\n'); browser()

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
    all.evaluation <- NULL

    # examine each fold and each model
    for (this.fold in 1:nfolds) {
        is.testing <- fold == this.fold
        is.training <- !is.testing
        for (this.model.index in 1:nmodels) {
            if (verbose) {
                cat(sprintf('CrossValidate3: determining error rate on model %d fold %d\n',
                            this.model.index, this.fold))
            }
            Model.param <- models.params[[this.model.index]]
            Model <- Model.param$Model
            param <- Model.param$param
            this.evaluation <- Model(data, is.training, is.testing, param)

            # the first evaluation is the one we use to decide the best model
            this.error.rate <- this.evaluation[[1]]
            if (verbose) {
                cat(sprintf('CrossValidate3: error rate on model %d fold %d is %f\n',
                            this.model.index, this.fold, this.error.rate))
            }

            # accumlate results
            all.fold <- c(all.fold, this.fold)
            all.model.index <- c(all.model.index, this.model.index)
            all.error.rate <- c(all.error.rate, this.error.rate)
            all.evaluation <- AppendEach(all.evaluation, this.evaluation)
        }
    }   

    # create data frame with all results for all models and folds
    #cat('in CV: building all.results\n'); browser()
    all.results <- data.frame(fold = all.fold,
                              model.index = all.model.index,
                              error.rate = all.error.rate,
                              evaluation = all.evaluation)
    if (verbose) {
        cat('all.results\n')
        str(all.results)
        print(all.results)
    }

    # determine best model to be the one with the lowest error rate on average across the folds
    best.average.error.rate <- Inf
    for (this.model.index in 1:nmodels) {
        in.model <- all.results$model.index == this.model.index
        this.average.error.rate <- mean(all.results$error.rate[in.model])
        if (this.average.error.rate < best.average.error.rate) {
            best.average.error.rate <- this.average.error.rate
            best.model.index <- this.model.index
        }
    }

    result <- list (best.model.index = best.model.index,
                    all.results = all.results)
    result
}

