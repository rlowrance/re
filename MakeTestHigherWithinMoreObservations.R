MakeTestHigherWithinMoreObservations <- function() {
    # Return a test function that verifies that models with higher (mean.within.10.percent) tend
    # to have more observations

    Test <- function(cv.result) {
        # verify that models with higher (mean.within.10.percent) have more observations
        # ARG:
        # cv.result : the returned value from CrossValidate, which has these fields
        #   $best.model.index : num scalar
        #   $all.assessment   : data.frame
        # RETURN a list satisfying the API for function Cv in compare-models.R
        #   $hypothesis : char scalar
        #   $passed     : logical scalar, TRUE caller will stop if not TRUE
        #   $support    : arbitrary object that justified value of $passed

        #cat('starting Test2\n'); browser()
        verbose <- FALSE

        # determine statistics for each model across folds
        fold.assessment <- cv.result$fold.assessment

        MeanWithin10Percent <- function(model.index) {
            values <- fold.assessment[model.index == fold.assessment$model.index,
                                      'assessment.within.10.percent']
            result <- mean(values)
            result
        }

        MeanNumTrainingSamples <- function(model.index) {
            values <- fold.assessment[model.index == fold.assessment$model.index,
                                      'assessment.num.training.samples']
            result <- mean(values)
            result
        }

        nModels <- max(fold.assessment$model.index)
        mean.within.10.percent <- sapply(1:nModels, MeanWithin10Percent)
        mean.num.training.samples <- sapply(1:nModels, MeanNumTrainingSamples)

        reduced.data <- data.frame(model.index = 1:nModels,
                                   mean.within.10.percent = mean.within.10.percent,
                                   mean.num.training.samples = mean.num.training.samples)
        if (verbose) {
            print(reduced.data)
        }

        # regress mean.num.training.samples ~ mean.within.10.percent
        fitted.lm <- lm(formula = mean.num.training.samples ~ 0 + mean.within.10.percent,
                        data = reduced.data)
        if (verbose) {
            print(fitted.lm)
        }
        coefficient <- fitted.lm$coefficients  # there is only one coefficient
        passed <- coefficient > 0 

        result = list(hypothesis = 'models with higher mean within 10 percent have more observations',
                      passed = passed,
                      support = list(cv.result = cv.result,
                                     reduced.data = reduced.data,
                                     fitted.lm = fitted.lm))
        result
    }
    Test
}
