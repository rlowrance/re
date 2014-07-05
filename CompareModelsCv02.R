CompareModelsCv02 <- function(testing.period, transformed.data) {
    # define models for experiment: avm linear log-log form chopra
    # ARGS
    # testing.period   : list($first.date,$last.date) list of Date 
    #                    first and last dates for the testing period
    # transformed.data : data.frame
    # RETURN list(Model=<list of functions>, description=<list of char vector>)
    # $Model       : list of functions
    # $description : list of chr vectors
    # $Test        : list of functions
    # where
    #   Model and description are parallel lists such that
    #     Model[[i]]: is a function(data, training.indices, testing.indices)
    #                 --> $actual = <vector of actual prices for the testing period>
    #                     $predicted <vector of predicted prices or NA values> for corresponding transactions
    #     description[[i]]: a vector of lists of chr, a description of the model
    #  Test is a list of functions such that
    #     Test[[j]] is a function(cv.result)
    #               --> $hypothesis : chr scalar, description of the test
    #                   $passed     : logical scalar, TRUE or FALSE
    #                   $support    : any object, provides evidence for $passed

    #cat('starting CompareModelsCv02', testing.period$first.date, testing.period$last.date, nrow(transformed.data), '\n'); browser()

    Require('CompareModelsCvLinear')
    Require('MakeTestBestModelIndex')
    

    expected.best.model.index <- 2 
    Test1 <- MakeTestBestModelIndex(expected.best.model.index = expected.best.model.index,
                                    verbose = TRUE)
    Test <- list(Test1)

    result <- CompareModelsCvLinear(testing.period = testing.period,
                                    transformed.data = transformed.data,
                                    model.form = 'log.log',
                                    scenario = 'avm',
                                    Test = Test)
    result
}
