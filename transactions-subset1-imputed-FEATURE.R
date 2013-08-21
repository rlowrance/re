# transactions-subset1-imputed-FEATURE.Rmd

# Deduce the imputed values for all the to-impute features.


# TODO
# TODO: implement Yann's idea; see 2/27 meeting journal
# TODO: experiment, is my standardized distance metric better or worse than
#       the one with exact distances and the time-to-meters conversion
# TODO: compare Guassian kernel to linear kernel
# TODO: rename algo WeightedAverage to GaussianWeightedAverage (GWA)

#  Break input into test/training.
#  Use cross validation to estimate hyperparameters.
#  Compare the estimate of the generalization error to the error
#  on the test data.
#  After finding best hp, use it to fit using the entire dataset.
#  Extend to test select among models. See lab book 2/28.

rm(list=ls())    # clear the workspace
options(warn=2)  # turn warnings into errors

require("compiler")
enableJIT(3)     # 3 ==> maximum JIT level

# Source files here, now that the JIT level is set.
  
source("BestApns.R")
source("CrossValidate.R")
source("DistancesEuclidean.R")
source("KernelGaussian.R")
source("Validate.R")

Initialize <- function() {
  # Return control variables as a list

  # Initialize R.
  
  
  set.seed(1)      # random number generator seed

  P <- function(name, value) {
    # print and return argument
    cat(name, value, "\n")
    value
  }
  
  # Define and return control parameters
  dirOutput <- "../data/v6/output/"
  targetFeature = "CONDITION.CODE"
  # for WeightedAverage, the minimize is in [0, 0.1]
  alphas <- list()
  alphas[[1]] <- list(algo="WeightedAverage", hp=0.01)
  alphas[[2]] <- list(algo="WeightedAverage", hp=0.03)  
  #alphas[[1]] <- list(algo="WeightedAverage", hp=0.1)
  #alphas[[2]] <- list(algo="WeightedAverage", hp=0.3)
  #alphas[[3]] <- list(algo="WeightedAverage", hp=1.0)
  #alphas[[4]] <- list(algo="WeightedAverage", hp=3.0)
  #alphas[[5]] <- list(algo="WeightedAverage", hp=10.0)
  list(testing=P("testing", FALSE),
       targetFeature=P("targetFeature", targetFeature),
       alphas=alphas,
       selectionApproach=P("selectionApproach", "Validation"),
       fractionValidation=0.25,
       fractionTesting=0.25,
       testingInputLimit=1000,
       parcelFeaturesUsed=c(
         "YEAR.BUILT",
         "LAND.SQUARE.FOOTAGE",
         "UNIVERSAL.BUILDING.SQUARE.FEET",
         "LIVING.SQUARE.FEET",
         "PARKING.SPACES"),
       dirOutput=dirOutput,
       pathToImpute=paste(
         dirOutput,
         "transactions-subset1-to-impute.csv",
         sep=""),
       pathParcels=paste(
         dirOutput,
         "parcels-sfr.csv",
         sep=""),
       pathTransactions=paste(
         dirOutput,
         "transactions-al-sfr.csv",
         sep=""),
       pathGeocoding="../data/raw/geocoding.tsv",
       pathOutput=paste(
         dirOutput,
         "transactions-subset1-imputed-",
         targetFeature,
         ".csv",
         sep="")
       )
}     
       


###############################################################################
## global closures: define and create
###############################################################################

MakeScaledLocations <- function(df) {
  # Make a function that puts a data frame's latitude, longitude, and year on a
  # common scale.
  #
  # ARGS
  #
  # df a data frame
  #
  # Value
  # function ScaleLocations(newDf) with
  #   ARGS: newDf, a data frame
  #   Value: a data frame with the [latitude, longitude, year] features scaled
  #   according to the same features in df

  if (sum(is.na(df$G.LATITUDE)) > 0) {
    cat("MakeScaleLocations: G.LATITUDE has NA\n")
    browser()
  }
  meanLatitude <- mean(df$G.LATITUDE)
  sdLatitude <- sd(df$G.LATITUDE)
  
  if (sum(is.na(df$G.LONGITUDE)) > 0) {
    cat("MakeScaleLocations: G.LATITUDE has NA\n")
    browser()
  }
  meanLongitude <- mean(df$G.LONGITUDE)
  sdLongitude <- sd(df$G.LONGITUDE)
  
  if (sum(is.na(df$YEAR.BUILT)) > 0) {
    cat("MakeScaleLocations: G.LATITUDE has NA\n")
    browser()
  }
  meanYearBuilt <- mean(df$YEAR.BUILT)
  sdYearBuilt <- sd(df$YEAR.BUILT)
  
  ScaleLocations <- function(newDf) {
    newDf$x <- (newDf$G.LATITUDE - meanLatitude) / sdLatitude
    newDf$y <- (newDf$G.LONGITUDE - meanLongitude) / sdLongitude
    newDf$t <- (newDf$YEAR.BUILT - meanYearBuilt) / sdYearBuilt
    
    newDf
  }

  ScaleLocations
}


################################################################################
# global functions
################################################################################

Split2 <- function(df, fractionTesting) {
  # Split data frame into testing and training subsets.
  # 
  # ARGS
  # 
  # df: data frame to be split
  # 
  # fractionTesting: fraction of rows that are in the testing set, remainder are
  # in the training set.
  # 
  # Value: list containing two data frames $testing and $training.
  
  n <- nrow(df)
  testingIndices <- sample(1:n, round(fractionTesting * n))
  list(testing=df[testingIndices, ],
       training=df[-testingIndices, ])
}

Split3 <- function(df, fractionValidation, fractionTesting) {
  # Split data frame into training, validation, and testing
  #
  # ARGS
  #
  # df: data frame to be split
  #
  # fractionValidation: fraction of observations to validation portion
  #
  # fractionTesting: fraction of observations to testing portion
  #
  # Value: a list of data frames with components $training, $validation,
  # $testing

  if (fractionValidation + fractionTesting > 1.0)
    stop("no training data defined")
  
  first <- Split2(df, fractionTesting)
  second <-
    Split2(first$training, fractionValidation / (1 - fractionTesting))
  list(training=second$training,
       validation=second$testing,
       testing=first$testing)
}

Train <- function(df, alpha, extra) {
  # Train by dispatching to the algorithm specified in alpha
  #
  # df: data frame
  # passed to the training function for the algorithms
  #
  # alpha: list
  # $algo: char scalar, name of algorithm; e.g., "WeightedAverage"
  # $hp: arbitary, hyperparameters for that algorithm
  #
  # extra: arbitrary
  # passed to the training function for the algorithm
  
  algo <- alpha$algo
  hp <- alpha$hp
  if (algo == "WeightedAverage")
    result <- TrainWeightedAverage(df, hp, extra)
  else {
    cat("alpha:", alpha, "\n")
    stop("alpha$algo is not known")
  }
  result
}

TrainWeightedAverage <- function(dfTraining, sigma, extra) { 
  # train a model with kth part of data removed
  #
  # ARGS:
  #
  # dfTraining: data frame containing inputs and target
  #
  # sigma: numeric scalar
  # standard deviation of the Gaussian kernel
  # not used for training for this algorithm
  #
  # extra is the argument passed to CrossValidate.
  # 
  # Value: simply memorize and return the training data

  verbose <- 1
  result <- list(dfTraining=dfTraining)
  if (verbose >= 2) {
    cat("TrainWeightedAverage: trained model\n")
    cat(" head($dfTraining)\n")
    print(head(result$dfTraining))
  }
  result
}

Predict <- function(trainedModel, dfNewdata, alpha, extra) {
  # Predict by dispatching to the algorithm specified in alpha
  #
  # trainedModel: arbitrary
  # The value from calling Train()
  #
  # dfNewdata: data frame
  # Contains the inputs.
  #
  # alpha: list
  # $algo: char scalar, name of algorithm; e.g., "WeightedAverage"
  # $hp: arbitary, hyperparameters for that algorithm
  #
  # extra: arbitrary
  # passed to the predict function for the algorithm
  
  algo <- alpha$algo
  hp <- alpha$hp
  if (algo == "WeightedAverage")
    result <- PredictWeightedAverage(trainedModel, dfNewdata, hp, extra)
  else {
    cat("alpha:", alpha, "\n")
    stop("alpha$algo is not known")
  }
  result
}

PredictWeightedAverage <-function(trainedModel, dfNewdata, sigma, extra){
  # predict using trained model
  #
  # ARGS
  #
  # trainedModel is a value returned by the Train function
  # Here it is the training data.
  #
  # dfNewdata is the subset of rows in df containing the kth fold. The
  # targets for these observations are predicted using the trained model.
  #
  # sigma: numeric scalar
  # the standard deviation of the Gaussian used to weight the observations
  #
  # extra is a list
  #  $distanceFeatures: character vector of names of distance features
  #  $targetFeature: character scalar, name of target feature
  #
  # Value: a vector of character values selected from a
  # weight k-nearest neighbors algorithm

  verbose <- 1
  me <- "PredictWeightedAverage:"
  procTimeStart <- proc.time()

  nPredictions <- nrow(dfNewdata)
  if (verbose >= 1)
    cat("PredictWeightedAverage: # of predictions", nPredictions, "\n")

  targetFeatureName <- extra$targetFeature
  targetValues <- unique(trainedModel$dfTraining[[targetFeatureName]])
  if (verbose >= 1)
    cat(sprintf("target feature %s has %d distinct values\n",
                targetFeatureName, length(targetValues)))
  targets <- trainedModel$dfTraining[[targetFeatureName]]

  PredictWeightedAverageOne <- function(index) {
    # predict the target for observation dfNewdata[index,]
    me <- paste("PredictWeightedAverageOne(index=", index, ")", sep="")
    procTimeStart <- proc.time()
    if ((verbose >= 1) && (index %% 10000 == 1))
      cat(sprintf("%s index %d of %d\n",
                  me, index, nPredictions))
    theWeights <-
      KernelGaussian(df=trainedModel$dfTraining,
                     query=dfNewdata[index, ],
                     featureNames=extra$distanceFeatures,
                     sigma=sigma)
    # pick the target in the training subset with the greatest weight
    maxWeight <- 0
    bestTarget <- NULL
    if (verbose >= 2) {
      cat(sprintf(paste(me,
                        "for target feature %s, ",
                        "there are %d unique target values\n"),
                  targetFeatureName, length(targetValues)))
    }
    #browser()
    for (targetValue in targetValues) {
      if (is.na(targetValue)) {
        print(targetValues)
        stop("targetValues contains NA. Should not happen.")
      }
      procTimeLoop <- proc.time()
      targetWeight <-
        sum(theWeights[targets == targetValue])
      if (verbose >= 2) {
        cat(sprintf(paste(me, "target weight for target %s is %f\n"),
                    targetValue, targetWeight))
        cat(sprintf(paste(me, "current maxWeight is %f\n"), maxWeight))
      }
      if (is.na(targetWeight)) {
        cat(me, "na found\n")
        browser()
      }
      if (targetWeight > maxWeight) {
        maxWeight <- targetWeight
        bestTarget <- targetValue
      }
      if (verbose >= 2) {
        cat(me, "time for one loop\n")
        print(proc.time() - procTimeLoop)
      }
    }
    if ((verbose >= 1) && (index %% 10000 == 1)) {
      cat(sprintf("%s: prediction for index %d of %d is %s\n",
                  me, index, nPredictions, bestTarget))
      print(proc.time() - procTimeStart)
    }
    bestTarget
  }
  
  # Predict target for each validation observations
  #cat("about to call PredictOne\n")
  #debug(PredictWeightedAverageOne)
  predictions <- sapply(1:nPredictions, PredictWeightedAverageOne)
  if (verbose >= 1) {
    cat("PredictWeightedAverage: finished. head(predictions) = \n")
    print(head(predictions))
    print(proc.time() - procTimeStart)
  }
  predictions
}

Loss <- function(dfNewdata, predictions, alpha, extra) {
  # Predict by dispatching to the algorithm specified in alpha
  #
  # dfNewdata: data frame
  # Contains the targets
  #
  # predictions: vector containing the predictions
  #
  # alpha: list
  # $algo: char scalar, name of algorithm; e.g., "WeightedAverage"
  # $hp: arbitary, hyperparameters for that algorithm
  #
  # extra: arbitrary
  # passed to the predict function for the algorithm
  
  algo <- alpha$algo
  hp <- alpha$hp
  if (algo == "WeightedAverage")
    result <- LossWeightedAverage(dfNewdata, predictions, hp, extra)
  else {
    cat("alpha:", alpha, "\n")
    stop("alpha$algo is not known")
  }
  result
}

LossWeightedAverage <- function(dfNewdata, predictions, sigma, extra) {
  # determine 0/1 loss rate from the predictions.
  #
  # ARGS:
  #
  # dfNewdata: a data frame containing the target feature
  #
  # predictions: vector of values (typically from the predict functin)
  #
  # sigma: numeric scalar
  # standard deviation of the Gaussian kernel
  #
  # extra: list containing $targetFeature
  # $targetFeature is a char scalar containing the name of the
  # target feature
  #
  # Value: a vector of numbers, each a loss determined from the target
  # and prediction value. Use the 0/1 loss (0 if perfect, 1 otherwise).
  
  # check parameters
  verbose <- 1
  
  if (nrow(dfNewdata) != length(predictions))
    stop("arguments are different lengths")

  targetFeatureName <- extra$targetFeature
  result <-
    sum(dfNewdata[[targetFeatureName]] != predictions) / length(predictions)
  if (verbose >= 1) {
    cat("LossWeightedAverage: result=", result, "\n")
  }
  result
}

ImputeCrossValidate <- function(method,
                                fractionTesting, fractionValidation,
                                nfolds,
                                distanceFeatures, targetFeature, alphas) {
  # Impute values for target featue with hyperparameter choices in alpha using
  # the parcels. Use trained model to impute missing features in transactions.
  # 
  # ARGS:
  #
  # method: character scalar
  #  if "crossvalidate" perform cross validation
  #  if "validate"      perform validation
  #
  # fractionTesting: numeric scalar
  #  fraction of dfTraining put into testing set
  #
  # fraction
  # nFolds: cross-validation parameter. Number of folds create for data.
  #
  # distanceFeatures: character vector or list, names of the features in
  # data and newData that are used to compute the distance. A Euclidean
  # distance is used, so these features should have a common scale.
  #
  # targetFeature: scalar character, name of the target feature in parcels
  # and transactions data frames.
  #
  # alphas: list or vector of hyperpameters. Each element is arbitrary.
  #
  # Value: data frame newData with added feature "targetFeature"

  cat("imputing", targetFeature,  "\n")
  
  # determine best value for hyperparameter sigma
  extra <- list(distanceFeatures=distanceFeatures,
                targetFeature=targetFeature)
  split <- Split2(data, fractionTesting)
  bestAlpha <- CrossValidate(split$training, 
                             nfolds, 
                             alphas, 
                             TrainWeightedAverage,
                             PredictWeightedAverage,
                             LossWeightedAverage, 
                             extra=extra, 
                             verbose=1)
  testingTrained <- TrainWeightedAverage(split$testing, bestAlpha, extra)
  testingPredictions <- 
    PredictWeightedAverage(testingTrained, split$testing, bestAlpha, extra)
  nAccurate <- sum(testingPredictions == split$testing[[targetFeature]])
  cat(sprintf("accuracy on best sigma for the test data = %f\n",
              nAccurate/nrow(split$testing)))
  
  # estimate generalization error using the test data

  testingTrained <- NULL
  testingPredictions <- NULL
  
  # predict missing values after training on all data
  allTrained <- TrainWeightedAverage(parcels, bestAlpha, extra)
  transactions <- BuildTransactions()
  transactions <- transactions[is.na(transactions[[targetFeature]]), ]
  cat(sprintf("predicting missing values for %d transactions\n",
              nrow(transactions)))
  newDataPredictions <-
    PredictWeightedAverage(allTrained, transactions, result$bestAlpha, extra)
  result <- data.frame(apn.recoded=newData$apn.recoded,
                       predictedTarget=newDataPredictions)
  result
}

ImputeValidate <- function(data, 
                           GetNewdata,  
                           fractionValidation,
                           fractionTesting,
                           distanceFeatures,
                           targetFeature,
                           alphas,
                           ScaleParcelsLocations,
                           control) {
  # Impute values for target featue with hyperparameter choices in alpha using
  # the parcels. Use trained model to impute missing features in transactions.
  # 
  # ARGS:
  #
  # data: data frame containing all observations (e.g., the parcels)
  # Split into train-validate-test subsets for the purposes of selecting the
  # best model (using the alphas) and estimating the generalization error
  # on the best model. The best model is then fit to all the data.
  #
  # GetNewdata: function(control, ScaleParcelsLocations)
  # Value is a data frame of the transactions to be estimated. Only the
  # observations missing the targetValue are estimated and returned.
  #
  # fractionValidation: numeric scalar
  # fraction of data put into validate subset
  #
  # fractionTesting: numeric scalar
  # fraction of data put into test subset.
  #
  # distanceFeatures: character vector or list,
  # names of the features used to compute the distance. This version always
  # uses the Euclidean distance, hence the features should be on a common
  # scale.
  #
  # targetFeature: scalar character, name of the target feature to impute.
  #
  # alphas: list or vector of hyperpameters. Each element is arbitrary.
  #
  # ScaleParcelsLocations: function(df) --> create features x, y, t
  #
  # control: list of control parameters
  #
  # Value: data frame with imputed feature. Has these columns:
  # apn.recoded: numeric apn value from data
  # imputedTarget: character value that was imputed

  cat(sprintf("imputing %s using validation\n", targetFeature))
  
  # determine best value for hyperparameter sigma
  extra <- list(distanceFeatures=distanceFeatures,
                targetFeature=targetFeature)
  split <- Split3(data, fractionValidation, fractionTesting)
  val1 <- Validate(split$training,
                   split$validation,
                   alphas,
                   Train,
                   Predict,
                   Loss,
                   extra=extra,
                   verbose=1)
  cat("results from validation for feature", targetFeature, "\n")
  cat("best alpha\n")
  print(val1$bestAlpha)
  cat("loss for best alpha", val1$bestLoss, "\n")


  # estimate generalization error using the test data
  predictions <- Predict(val1$bestTrainedModel,
                         split$testing,
                         val1$bestAlpha,
                         extra)
  estimatedGeneralizationError <- Loss(split$testing,
                                       predictions,
                                       val1$bestAlpha,
                                       extra)
  cat(sprintf("estimated generalization error (on test set) is %f\n",
              estimatedGeneralizationError))

  # drop the splits, as no longer needed
  split <- NULL
  
  # predict missing values after training on all data
  allTrained <- Train(data, val1$bestAlpha, extra)
  newdata <- BuildTransactions(ScaleParcelsLocations, control)
  newdata <- unique(newdata)  # drop duplicate apn.recoded values
  newdata <- newdata[is.na(newdata[[control$targetFeature]]), ]
  cat(sprintf("predicting missing values for %d transactions\n",
              nrow(newdata)))
  newdataPredictions <-
    Predict(allTrained, newdata, val1$bestAlpha, extra)
  #print("in ImputeValidate"); browser()
  
  cat("all alphas and associated losses\n")
  #browser()
  for (i in 1:length(alphas)) {
    cat(sprintf("algo %s sigma %f loss %f\n",
                alphas[[i]]$algo,
                alphas[[i]]$hp,
                val1$allLosses[i]))
  }
  
  result <- data.frame(apn.recoded=newdata$apn.recoded,
                       predictedTarget=newdataPredictions)
  result
}

Impute.Test <- function() {
  # Unit test of ImputeOne
  verbose <- TRUE
  source("CrossValidate.R")
  #debug("CrossValidate")
  set.seed(1)

  data <- data.frame(apn.recoded = c(1,2,3,4,5,6,7,8),
                     x=c(-0.1, -0.1, 0.1, 0.1, .9, .9, 1.1, 1.1),
                     y=c(0.1, -0.1, 0.1, -0.1, 0.9, 1.1, 0.9, 1.1),
                     t=c(0, 1, 0, 1, 0, 1, 0, 1),
                     mark=c("o", "o", "o", "o", "x", "x", "x", "x"))
  newData <- data.frame(apn.recoded=c(11,12,13,14),
                        x=c(0, 0, 1, 1),
                        y=c(0, 0, 1, 1),
                        t=c(0, 1, 0, 1))
  fractionTesting <- 0.2
  nFolds <- 3
  distanceFeatures = c("x", "y", "t")
  targetFeature <- "mark"
  alphas = c(.1, .3, 1)
  imputed <- Impute(data,
                    newData,
                    fractionTesting,
                    nFolds,
                    distanceFeatures,
                    targetFeature,
                    alphas)
  Match <- function(expected, actual) {
    if (expected != actual)
      stop(sprintf("expecting %s but found %s", expected, actual))
  }
  Match("o", imputed$predictedTarget[1])
  Match("o", imputed$predictedTarget[2])
  Match("x", imputed$predictedTarget[3])
  Match("x", imputed$predictedTarget[4])
  if (verbose)
    cat("passed unit test\n")                                     
}


BuildParcels <- function(control) {
  # Build the parcels data frame by merging in the geocoding and dropping
  # features we are not going to use
  # read parcels observations
  # Value: a list with these members
  # $parcel: data frame containing selected columns in parcels with
  #  geocoding that has been scaled
  # $ScaleParcelsLocations: function that will convert latitude, longitude,
  #  and year built to scaled versions in columns x, y, t

  parcels <- read.csv(control$pathParcels,
                      nrows=ifelse(
                        control$testing,
                        control$testingInputLimit,
                        -1))
  cat(sprintf("read %d observations from %s\n",
              nrow(parcels), control$pathParcels))

  # keep only parcels features that are used in some model
  featuresToKeep <- c(control$parcelFeaturesUsed,
                      control$targetFeature,
                      "APN.UNFORMATTED",
                      "APN.FORMATTED")
  parcels <- parcels[featuresToKeep] 
  
  # read geocoding observations
  geocoding <- read.table(control$pathGeocoding,
                          header=TRUE,
                          sep="\t",
                          quote="",
                          comment="",
                          stringsAsFactor=FALSE,
                          na.strings="",
                          nrows=ifelse(
                            control$testing,
                            control$testingInputLimit,
                            -1))
  cat(sprintf("read %d observations from %s\n",
              nrow(geocoding), control$pathGeocoding))
  
  # merge the geocoding into the parcels
  cat("number of parcels before merging in geocoding", nrow(parcels), "\n")
  parcels$apn.recoded <-
    BestApns(parcels$APN.UNFORMATTED, parcels$APN.FORMATTED)
  parcels <- merge(parcels, geocoding, by.x="apn.recoded", by.y="G.APN")
  cat("number of parcels after merging in geocoding", nrow(parcels), "\n")

  parcels$APN.UNFORMATTED <- NULL
  parcels$APN.FORMATTED <- NULL

  geocoding <- NULL  # no longer needed

  # scale the Latitude, Longitude, and Year.Built features
  ScaleParcelsLocations <- MakeScaledLocations(parcels)
  parcels <- ScaleParcelsLocations(parcels)

  parcels$G.LATITUDE <- NULL
  parcels$G.LONGITUDE <- NULL
  parcels$YEAR.BUILT <- NULL

  list(parcels=parcels,
       ScaleParcelsLocations=ScaleParcelsLocations)
}

BuildTransactions <- function(ScaleParcelsLocations, control) {
  # read transactions observations
  # need > 1000 observations to find a missing ZONING feature
  #
  # ScaleParcelsLocation: function that converts latitude, longitude, and
  # year built to standardized x, y, and t features.
  #
  # control: list of control parameters
  #
  # Value: data frame with x, y, and t features 

  transactions <- read.csv(control$pathTransactions,
                           nrows=ifelse(
                             control$testing,
                             2 * control$testingInputLimit,
                             -1))
  cat(sprintf("read %d observations from %s\n",
              nrow(transactions), control$pathTransactions))
  featuresKept <- c(control$parcelFeaturesUsed,
                    "G.LATITUDE",  # GPS coordinates are not in parcels
                    "G.LONGITUDE",
                    control$targetFeature,
                    "apn.recoded")
  transactions <- transactions[featuresKept]
  transactions <- ScaleParcelsLocations(transactions)
  transactions$G.LATITUDE <- NULL
  transactions$G.LONGITUDE <- NULL
  transactions$G.YEAR.BUILT <- NULL
  transactions
}


################################################################################
## main
################################################################################

Main <- function() {
  control <- Initialize()

  if (FALSE)
    Impute.Test()
  
  # read the observations unless not testing and they already exists
  if (TRUE ||   # always read parcels for now
      control$testing ||
      !exists("parcels") ||
      nrow(parcels) <= control$testingInputLimit) {
    
    # read names of feature to impute
    toImpute <- read.csv(control$pathToImpute)
    cat(sprintf("read %d observations from %s\n",
              nrow(toImpute), control$pathToImpute))
    
    result <- BuildParcels(control)
    parcels <- result$parcels
    ScaleParcelsLocations <- result$ScaleParcelsLocations
  }

  # Impute targetFeature

  haveFeature <- parcels[!is.na(parcels[[control$targetFeature]]), ]
  distanceFeatures <- c("x", "y", "t")
  imputed <- ImputeValidate(haveFeature,
                            BuildTransactions,
                            control$fractionValidation,
                            control$fractionTesting,
                            distanceFeatures,
                            control$targetFeature,
                            control$alphas,
                            ScaleParcelsLocations,
                            control)

  cat("imputed missing Feature head(df)\n")
  print(head(imputed))
  cat(sprintf("imputed missing features has %d rows\n", nrow(imputed)))
  write.csv(imputed, control$pathOutput, quote=FALSE)
  cat("wrote file", control$pathOutput, "\n")
  cat("finished\n")
}

#debug(BuildParcels)
#debug(BuildTransactions)
#debug(ImputeValidate)
#debug(Train)
#debug(TrainWeightedAverage)
#debug(Predict)
#debug(PredictWeightedAverage)
#debug(Loss)
#debug(LossWeightedAverage)
#debug(Validate)  
debug(Main)


Main()



