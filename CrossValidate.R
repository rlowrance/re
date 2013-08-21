# CrossValidate.R edited on isolde

CrossValidate <- function(df, nfolds, alphas, train, predict, loss, 
                          extra=NULL, 
                          verbose=1) {
  # Perform cross validation to select best parameters.
  #
  # Args:
  #
  # df:  a data frame containing both input and target variables.
  #
  # nfolds: scalar number, the number of folds
  #
  # alphas: a list or vector; each element is an arbitrary object;
  #   An element of alphas is passed to the train and predict functions.
  #
  # train(dfTrainingSubset, alpha, extra): Train a model with kth part of data
  # removed.
  #   dfTrainingSubset is the subset of rows in df not containing the kth fold.
  #   alpha is one of the alphas.
  #   extra is the argument passed to CrossValidate.
  #   Value: an arbitrary object called "trained". #
  # predict(trained, dfTestingSubset, alpha, extra): Predict using trained
  # model
  #   trained is a value returned by the train function.
  #   dfTestingSubset is the subset of rows in df containing the kth fold.
  #   alpha is one of the alphas.
  #   extra is the argument passed to CrossValidate.
  #   Value: a vector of predictions. The class of each element is arbitrary.
  #
  # loss(dfTestingSubset, predictions, extra): Determine losses from the
  # predictions.
  #   dfTestingSubset is the subset of rows in df containing the kth fold. It
  #     contains the target feature.
  #   predictions is the value of the predict function. It is a vector of 
  #     predicted target values.
  #   extra is the argument passed to CrossValidate.
  #   Value: a vector of numbers, each a loss determined from the target
  #     and prediction value.
  #
  # verbose: scalar integer, verbosity level; 
  #   0 means no printing
  #   1 means print average loss for each value of alpha
  #   2 means print trace of computation
  #
  # Value: the element of the alphas that had the lowest average loss across
  #   folds.

  nfolds <- round(nfolds)
  if (!(nfolds > 1))
    stop("nfolds must be at least one")
  n = nrow(df)
  if (nfolds > n)
    stop("nfolds is larger than number of observations")
  
  # randomly assign each observation in df to a fold numbered 1, 2, ..., nfolds
  folds <- rep(1:nfolds, ceiling(n / nfolds))[1:n]
  folds <- sample(folds)  # randomly permute
  if (verbose >= 2) 
    cat("CrossValidate: folds", folds, "\n")
  
  cv <- function(alpha) {
    # determine average loss across folds using parameter alpha
    # Args:
    # alpha: one of the alphas
    #
    # Value: the average loss across the folds using parameter alpha

    if (verbose >= 1)
      cat("CrossValidate: starting cv with alpha = ", alpha, "\n")
    totalLoss <- 0
    for (f in 1:nfolds) {
      # determine loss across all observations in fold f
      if (verbose >= 1)
        cat("CrossValidate: cv working on fold", f, "\n")
      
      dfTrainingSubset <- df[folds != f, ]     # train on data not in the fold
      dfTestingSubset <- df[folds == f, ]   # validate on data in the fold
      if (verbose >= 2) {
        cat(sprintf("CrossValidate: cv alpha %s f %d\n", alpha, f))
        print("CrossValidate: dfTrainingSubset")
        print(dfTrainingSubset)
        print("CrossValidate: dfTestingSubset")
        print(dfTestingSubset)
      } 
      trainedModel <- train(dfTrainingSubset, alpha, extra)
      if (verbose >= 2) {
        cat("CrossValidate: trainedModel\n")
        browser()
        print(trainedModel)
      }
      predictions <- predict(trainedModel, dfTestingSubset, alpha, extra)
      if (verbose >= 2) {
        cat("CrossValidate: head(predictions)\n")
        print(head(predictions))
      }
      losses <- loss(dfTestingSubset, predictions, extra)
      if (verbose >= 2) {
        cat("CrossValidate: head(losses)\n")
        print(head(losses))
        cat("CrossValidate: total loss", sum(losses), "\n")
      }
      totalLoss <- totalLoss + sum(losses)
    }
    averageLoss <- totalLoss / n
    if (verbose >= 1) {
      cat(sprintf(paste("CrossValidate:",
                        "average loss across folds for alpha = %s is %f\n"),
                  alpha, averageLoss))
    }
    averageLoss
  }
  #debug(cv)
  
  # determine alpha with lowest average loss
  bestAlpha <- NULL
  minAverageLoss <- Inf
  for (alphaIndex in 1:length(alphas)) {
    alpha <- alphas[alphaIndex]
    avgLoss <- cv(alpha)
    if (avgLoss < minAverageLoss) {
      bestAlpha <- alpha
      minAverageLoss <- avgLoss
    }
  }
  
  if (verbose >= 1) {
    cat(sprintf("CrossValidate: alpha with lowest average loss is %s\n",
                bestAlpha)) 
  }
  
  bestAlpha
}

CrossValidate.Test <- function() {
  # Unit test
  # Guess the majority color without looking at the training data
  verbose <- FALSE
  
  set.seed(1)

  # df:  a data frame containing both input and target variables
  # the majority are red
  df <- data.frame(x=1:10,
                   target=c(rep("red", 6), rep("blue", 4)))
  df

  # nfolds: scalar number, number of folds
  nfolds <- 3
  
  # alphas: a list or vector; each element is an arbitrary object;  
  alphas <- c("red", "blue")   # red is the better guess (as its the majority)
                   
  # train(dfTrainingSubset, alpha, extra): Train a model with kth part of data
  # removed
  #   dfTrainingSubset is the subset of df not containing the kth fold.
  #   alpha is one of the alphas.
  #   extra is the argument passed to CrossValidate.
  #   Value: an arbitrary object called "trained".
  
  trainingCall <- 0
  train <- function(dfTrainingSubset, alphaValue, extra) {
    # the trained model just memorizes the parameters
    trainingCall <<- trainingCall + 1
    if (extra != "abc")
      stop("train: bad extra")
    if (verbose) {
      cat(sprintf("train call %d with alpha=%s\n", trainingCall, alphaValue))
      print("dfTrainingSubset")
      print(dfTrainingSubset)
    }
    trained <- list(guess=alphaValue)  # the guess is alpha
    if (verbose) {
      print("trained")
      print(trained)
    }
    trained
  }
  
  # predict(trained, dfTestingSubset, alpha, extra): Predict using trained
  # model.
  #   trained is a value returned by the train function.
  #   dfTestingSubset is the subset of df in the fold.
  #   alpha is one of the alphas.
  #   extra is the argument passed to CrossValidate.
  #   Value: a vector of predictions. The class of element is arbitrary.
  predictCall <- 0
  predict <- function(trained, dfTestingSubset, alpha, extra) {
    predictCall <<- predictCall + 1
    if (verbose) {
      cat(sprintf("predict call %d with alpha=%s\n", predictCall, alpha))
      print("trained")
      print(trained)
      print("dfTestingSubset")
      print(dfTestingSubset)
    }
    if (extra != "abc")
      stop("predict: bad extra")
    predictions <- rep(trained$guess, nrow(dfTestingSubset))
    if (verbose) {
      print("predictions")
      print(predictions)
    }
    predictions
  }
  
  # loss(dfTestingSubset, predictions): Determine losses from the
  # predictions.
  #   dfTestingSubset is the subset of df in the fold. Because df contains
  #     the target feature, so does this variable.
  #   predictions is the value of the predict function.
  #   Value: a vector of numbers, each a loss determined from the target
  #     and prediction value.
  lossCall <- 0
  loss <- function(dfTestingSubset, predictions, extra) {
    lossCall <<- lossCall + 1
    # use 0/1 loss
    if (verbose) {
      cat("loss function")
      print("targets") 
      print(dfTestingSubset$target)
      print("predictions") 
      print(predictions)
    }
    
    errors <- dfTestingSubset$target != predictions
    if (verbose) {
      print("errors")
      print(errors)
    }
    sum(errors)
  }
  
  #debug(train)
  #debug(predict)
  #debug(loss) 
  
  extra <- "abc"
  bestAlpha <-
    CrossValidate(df, nfolds, alphas, train, predict, loss, extra, verbose=0)
  if (verbose) cat("bestAlpha", bestAlpha, "\n")
  if (bestAlpha != "red")
    stop("FAILED UNIT TEST")
}

#debug(CrossValidate)
#debug(CrossValidate.Test)
CrossValidate.Test()
