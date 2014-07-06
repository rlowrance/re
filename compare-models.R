# compare-models.R
# Main program to compare models
# driven by command line arguments, which have this syntax
# Rscript compare-models.R --what cv   --choice NUM --> produce file OUTPUT/compare-models-NUM.txt
#                          --what plot --choice NUM --> produce file OUTPUT/compare-models-plot-NUM.pdf

source('Require.R')  # read function definition file if function does not exist

library(ggplot2)

Require('Assess')
Require('CommandArgs')
Require('CrossValidate')
Require('ExecutableName')
Require('InitializeR')
Require('Printf')
Require('ReadAndTransformTransactions')
Require('Rmse')
Require('WithinXPercent')

ParseCommandLineArguments <- function(cl) {
    # parse command line into a list
    # ARGS
    # cl : chr vector of arguments in form --KEYWORD value
    #cat('starting ParseCommandLineArguments\n'); browser()
    result <- list()
    cl.index <- 1
    while (cl.index < length(cl)) {
        keyword <- cl[[cl.index]]
        value <- cl[[cl.index + 1]]
        if (keyword == '--what') {
            result$what <- value
        } else if (keyword == '--choice') {
            result$choice <- as.numeric(value)
        } else {
            # to facilite debugging via source(), allow unexpected arguments
            cat('unexpected keyword and its value skipped\n')
            cat(' keyword = ', keyword, '\n')
            cat(' value   = ', valye, '\n')
        }
        cl.index <- cl.index + 2
    }
    result
}

AugmentControlVariables <- function(control) {
    # add additional control variables to list of control variables
    #cat('starting AugmentControlVariables\n'); browser()
    result <- control
    result$me <- 'compare-models'

    # input/output
    result$dir.output <- '../data/v6/output/'

    result$path.in.subset1 <- paste0(result$dir.output, 'transactions-subset1.csv.gz')

    prefix <- paste0(result$dir.output, 
                     result$me, 
                     '-', 
                     control$what, 
                     '-', 
                     sprintf('%02d', control$choice))
    result$path.out.log <- paste0(prefix, '-log.txt')
    result$path.out.driver.result <- paste0(prefix, '-', 'driver.result', '.rsave')
    result$path.out.driver.result <- paste0(prefix, '.rsave')


    # control variables for all the experiments
    result$nfolds <- 10
    result$testing.period <- list(first.date = as.Date('2008-01-01'),
                                  last.date  = as.Date('2008-01-31'))

    # whether testing
    result$testing <- TRUE
    result$testing <- FALSE
    result
}


Cv <- function(control, transformed.data) {
    # perform one cross validation experiment and return NULL
    #cat('starting Cv', control$choice, nrow(transformed.data), '\n'); browser()

    PrintCvResult <- function(cv.result, description) {
        Printf('Cross Validation results\n')

        Printf('Experiment description\n')
        lapply(names(description),
               function(name) Printf(' %15s : %s\n', name, description[[name]]))

        Printf('best model index %d\n', cv.result$best.model.index)
        Printf('models compared\n')
        print(cv.result)
        NULL
    }

    TestHypotheses <- function(Tests, cv.result) {
        # Test hypotheses in the model
        #cat('compare-models::Cv::TestHypotheses', length(Tests), '\n'); browser()
        Print.Test.Result <- function(test.result) {
            cat('Test hypothesis:', test.result$hypothesis, '\n')
            cat('Passed?        :', test.result$passed, '\n')
            cat('Support\n')
            print(support)
        }

        Test.passed <- function(n) {
            test.result <- Test[[n]](cv.result)
            Print.Test.Result(test.result)
            test.result$test.passed
        }

        test.results <- lapply(Tests, function(Test) Test(cv.result))
        #cat('in CV after running all Tests\n'); browser()
        passed <- sapply(test.results, function(test.result) test.result$passed)


        if (!all(passed)) {
            msg <- 'AT LEAST ONE TEST FAILED'
            cat(msg, '\n')
            PrintFailedTest <- function(test.result) {
                print('Failing Test')
                print(test.result)
            }
            sapply(test.results, function(test.result) if (!test.result$passed) {PrintFailedTest(test.results)})
            stop(msg)
        }

        test.results
    }

    Require('CompareModelsCv01')
    Require('CompareModelsCv02')
    Require('CompareModelsCv03')
    Require('CompareModelsCv04')

    Driver <-
        switch(control$choice,
               CompareModelsCv01,  # assessor linear log-log chopra
               CompareModelsCv02,  # avm      linear log-log-chopra
               CompareModelsCv03,  # mortgage linear log-log chopra
               CompareModelsCv04)  # best of log-log chopra
    stopifnot(!is.null(Driver))

    Model.description.Test <- Driver(control$testing.period, transformed.data)

    Model <- Model.description.Test$Model
    description <- Model.description.Test$description
    Test <- Model.description.Test$Test

    cv.result <- CrossValidate(data = transformed.data,
                               nfolds = control$nfolds,
                               Models = Model,
                               Assess = Assess,
                               verbose = TRUE)
    PrintCvResult(cv.result, description)
    test.results <- TestHypotheses(Test, cv.result)

    # write models and results to file
    save(cv.result, Model, description, Test, test.results,
         file = control$path.out.driver.result)

    # return NULL
    NULL
}

An <- function(control, transformed.data) {
    # perform one analysis
    control$choice <- 1  # while developing, select the first analysis
    #cat('starting An', control$choice, nrow(transformed.data), '\n'); browser()

    Require('CompareModelsAn01')

    Driver <- 
        switch(control$choice,
               CompareModelsAn01)  # median price by month
    stopifnot(!is.null(Driver))

    an.result <- Driver(transformed.data)
    #cat('in An\n'); browser()
    Printf('Analysis results\n')
    print(an.result)


    if (is(an.result, 'ggplot')) {
        #cat('in An\n'); browser()
        path.base <- paste0(control$dir.output,
                           control$me,
                           '-an',
                           sprintf('-%02d', control$choice))
        # print the plot 
        pdf(file = paste0(path.base, '.pdf'), width = 14, height = 10)
        print(an.result)
        dev.off()

        # save the an result
        save(an.result, file = paste0(path.base, '.rsave'))
    } else {
        stop('class of an.result is not handled')
    }
}

Main <- function(control, transformed.data) {
    # execute one command, return NULL
    #cat('starting Main', control$what, control$which, nrow(transformed.data), '\n'); browser()


    switch(control$what,
           cv = Cv(control, transformed.data),
           an = An(control, transformed.data),
           plot = Plot(control, transformed.data))

    NULL
}

###############################################################################
# EXECUTION STARTS HERE
###############################################################################

# handle command line and setup control variables
#command.args <- CommandArgs(ifR = list('--what', 'cv', '--choice', '01'))
#command.args <- CommandArgs(ifR = list('--what', 'cv', '--choice', '02'))
#command.args <- CommandArgs(ifR = list('--what', 'cv', '--choice', '03'))
#command.args <- CommandArgs(ifR = list('--what', 'cv', '--choice', '04'))
control <- AugmentControlVariables(ParseCommandLineArguments(command.args))

# initilize R
InitializeR(start.JIT = FALSE,
            duplex.output.to = control$path.out.log)

# speed up debugging by caching the transformed data
force.refresh.transformed.data <- FALSE 
#force.refresh.transformed.data <- TRUE
if(force.refresh.transformed.data | !exists('transformed.data')) {
    transformed.data <- ReadAndTransformTransactions(control$path.in.subset1,
                                                     ifelse(control$testing, 1000, -1),
                                                     TRUE)  # TRUE --> verbose
}


# do the work
Main(control, 
     transformed.data)

cat('control variables\n')
str(control)

if (control$testing) {
    cat('DISCARD RESULTS: TESTING\n')
}

cat('done\n')
