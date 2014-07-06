MakeTestBestModelIndex <- function(expected.best.model.index, verbose = TRUE) {
    # return function that verifies an Cv experiment results in the expected best model index
    # ARGS:
    # expected.best.model.index : int, index of model expected to be best
    # verbose                   : logical, whether to print info when running the test
    # RETURNS function Test satisfying
    #   ARG:
    #   cv.result : the returned value from CrossValidate, which has these fields
    #     $best.model.index : num scalar
    #     $all.assessment   : data.frame
    #   RETURN a list satisfying the API for function Cv in compare-models.R
    #     $hypothesis : char scalar
    #     $passed     : logical scalar, TRUE caller will stop if not TRUE
    #     $support    : arbitrary object that justified value of $passed

    Test <- function(cv.result) {
        #cat('starting MakeTestBestModelIndex::Test\n'); browser()

        if (verbose) {
            fold.assessment <- cv.result$fold.assessment

            MeanRmse <- function(model.index) {
                values <- fold.assessment[model.index == fold.assessment$model.index,
                                          'assessment.rmse']
                result <- mean(values)
                result
            }

            nModels <- max(fold.assessment$model.index)
            mean.rmse <- sapply(1:nModels, MeanRmse)
            for (i in 1:nModels) {
                Printf('Test1: model %2d mean.rmse %f\n', i, mean.rmse[[i]])
            }
        }

        result <- list(hypothesis = sprintf('best model is model # %d', expected.best.model.index),
                       passed = cv.result$best.model.index == expected.best.model.index,
                       support = cv.result)
        if (verbose) {
            print('Result from MakeTestBestModelIndex::Test\n')
            print(result)
        }
    }

    Test
}
