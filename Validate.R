# Validate.R

Validate <- function(dfTraining, dfValidation, alphas,
                     Train, Predict, Loss,
                     extra=NULL,
                     verbose=1) {
  # Perform validation to select best parameters.
  #
  # Args:
  #
  # dfTraining:  a data frame containing both input and target variables. Used
  # for training the models.
  #
  # dfValidation: a data frame containing both input and target variables. Used
  # for validation the trained models.
  #
  # alphas: a list or vector; each element is an arbitrary object;
  #   An element of alphas is passed to the train and predict functions.
  #
  # Train(dfTraining, alpha, extra): Train a model using parameters alpha.
  #   dfTraining is the value passed to Validate.
  #   alpha is one of the alphas.
  #   extra is the argument passed to Validate.
  #   Value: an arbitrary object called "trained".
  #
  # Predict(trained, dfValidation, alpha, extra): Predict using trained
  # model
  #   trained is a value returned by the Train function.
  #   dfValidation is the value passed to Validate.
  #   alpha is one of the alphas.
  #   extra is the argument passed to CrossValidate.
  #   Value: a vector of predictions. The class of each element is arbitrary.
  #
  # Loss(dfValidation, predictions, extra): Determine losses from the
  # predictions.
  #   dfValidation is the value passed to Validate.
  #   predictions is the value of the Predict function.
  #   extra is the argument passed to Validate.
  #   Value: a vector of numbers, each a loss determined from the target
  #     and prediction value.
  #
  # verbose: scalar integer, verbosity level; 
  #   0 means no printing
  #   1 means print average loss for each value of alpha
  #   2 means print trace of computation
  #
  # Value: a list
  # $bestAlpha:        the element of the alphas that had the lowest loss among
  #                    the trained models
  # $bestTrainedModel: the fitted model for the best alpha
  # $bestPredictions:  the vector of predictions for the best alpha
  # $bestLoss:         the loss for the best alpha

  # determine alpha with lowest average loss
  bestAlpha <- NULL
  bestTrainedModel <- NULL
  bestPredictions <- NULL
  bestLoss <- NULL
  minLoss <- Inf
  allLosses <- NULL
  for (alpha in alphas) {
    trainedModel <- Train(dfTraining, alpha, extra)
    predictions <- Predict(trainedModel, dfValidation, alpha, extra)
    loss <- Loss(dfValidation, predictions, alpha, extra)
    allLosses <- c(allLosses, loss)
    if (verbose >= 1) {
      cat(sprintf("Validate: loss is %f for alpha\n",
                  loss))
      print(alpha)
    }

    if (loss < minLoss) {
      bestAlpha <- alpha
      bestTrainedModel <- trainedModel
      bestPredictions <- predictions
      minLoss <- loss
    }
  }
  
  if (verbose >= 1) {
    cat(sprintf("Validate: lowest loss is %f for alpha\n",
                minLoss))
    print(bestAlpha)
  }

  list(bestAlpha=bestAlpha,
       bestTrainedModel=bestTrainedModel,
       bestPredictions=bestPredictions,
       bestLoss=minLoss,
       allLosses=allLosses)
}
