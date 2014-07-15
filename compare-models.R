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
Require('ListAppend')
Require('ParseCommandLine')
Require('Printf')
Require('ReadAndTransformTransactions')
Require('Rmse')
Require('WithinXPercent')

## handle command line, explicit and implicit

ParseCommandLineArguments <- function(cl) {
    # parse command line into a list
    # ARGS
    # cl : chr vector of arguments in form --KEYWORD value
    #cat('starting ParseCommandLineArguments\n'); browser()
    result <- ParseCommandLine( cl
                               ,keywords = c('what', 'choice')
                               ,ignoreUnexpected = TRUE
                               ,verbose = TRUE)  # show unexpected args
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
                     sprintf('%s', control$choice))
    result$path.out.log <- paste0(prefix, '-log.txt')
    result$path.out.driver.result <- paste0(prefix, '-', 'driver.result', '.rsave')
    result$path.out.driver.result <- paste0(prefix, '.rsave')


    # control variables for all the experiments
    result$nfolds <- 10

    # whether testing
    result$testing <- TRUE
    result$testing <- FALSE
    result
}

## suppport functions

DivisibleBy <- function(n, k) {
    # return TRUE iff n is exaclty divisible by k
    0 == (n %% k)   # %% is mod
}

DivisibleBy.test <- function() {
    stopifnot(DivisibleBy(2008, 4))
    stopifnot(!DivisibleBy(2009, 4))
}

DivisibleBy.test()

DaysInMonth <- function(year, month) {
    # return number of days in month, accounting for leap years
    #cat('starting DaysInMonth', year, month, '\n'); browser()

    result.no.leap.year <- c(31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31)[[month]]
    is.leap.year <- DivisibleBy(year, 4) & (!DivisibleBy(year, 100))
    result <- ifelse(is.leap.year & month == 2, 29, result.no.leap.year)
    result
}

DaysInMonth.test <- function() {
    stopifnot(DaysInMonth(2008,1) == 31)
    stopifnot(DaysInMonth(2008,2) == 29)
    stopifnot(DaysInMonth(2008,12) == 31)
    stopifnot(DaysInMonth(2009, 2) == 28)
}

DaysInMonth.test()

TestingPeriods <- function() {
    # return list of testing period, each element a list (first.date, last.date)
    #cat('starting TestingPeriods\n'); browser()
    result <- NULL
    for (year in c(2008, 2009)) {
         last.month <- ifelse(year == 2008, 12, 11)
         for (month in 1:last.month) {
             first.date <- as.Date(sprintf('%4d-%2d-%2d', year, month, 1))
             last.date <- first.date + DaysInMonth(year, month) - 1
             result <- ListAppend(result, 
                                  list( year = year
                                       ,month = month
                                       ,first.date = first.date
                                       ,last.date = last.date
                                       )
                                  )
         }
    }
    result
}

TestingPeriods.test <- function() {
    #cat('starting TestingPeriods.test\n'); browser()
    testing.periods <- TestingPeriods()
    stopifnot(length(testing.periods) == 23)

    first <- testing.periods[[1]]
    stopifnot(first$year == 2008)
    stopifnot(first$month == 1)
    stopifnot(first$first.date == as.Date('2008-01-01'))
    stopifnot(first$last.date == as.Date('2008-01-31'))

    last <- testing.periods[[length(testing.periods)]]
    stopifnot(last$year == 2009)
    stopifnot(last$month == 11)
    stopifnot(last$first.date == as.Date('2009-11-01'))
    stopifnot(last$last.date == as.Date('2009-11-30'))
}

TestingPeriods.test()

## control$what implementations

Cv <- function(control, transformed.data) {
    # perform one cross validation experiment and return NULL
    # use the testing period 2008-Jan
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
    Require('CompareModelsCv05')

    Driver <-
        switch( as.numeric(control$choice)
               ,CompareModelsCv01  # assessor linear log-log chopra
               ,CompareModelsCv02  # avm      linear log-log-chopra
               ,CompareModelsCv03  # mortgage linear log-log chopra
               ,CompareModelsCv04  # best of log-log chopra
               ,CompareModelsCv05  # avm vs. assessor w/o assessor's estimates:w
               )

    stopifnot(!is.null(Driver))

    testing.period <- list( first.date = as.Date('2008-01-01')
                           ,last.date  = as.Date('2009-01-31')
                           )
    Model.description.Test <- Driver(control$testing.period, transformed.data)

    Model <- Model.description.Test$Model
    description <- Model.description.Test$description
    Test <- Model.description.Test$Test

    experiment <- sprintf('CV%02d', control$choice)
    cv.result <- CrossValidate(data = transformed.data,
                               nfolds = control$nfolds,
                               Models = Model,
                               Assess = Assess,
                               experiment = experiment)
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
    cat('starting An', control$choice, nrow(transformed.data), '\n'); browser()

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


Bmtp <- function(control, transformed.data) {
    # determine best model for each testing period in scenario control$choice
    # the testing periods are the months 2008-Jan, 2008-Feb, ..., 2009-Nov
    # follow the protocol from Cv as much as possible

    cat('starting Bmtp', control$choice, nrow(transformed.data), '\n'); browser()

    verbose <- TRUE

    Require('CompareModelsCv01')
    Require('CompareModelsCv02')
    Require('CompareModelsCv03')
    Driver <- switch( control$choice
                     ,assessor = CompareModelsCv01
                     ,avm      = CompareModelsCv02
                     ,mortgage = CompareModelsCv03
                     )
    stopifnot(!is.null(Driver))

    all.row <- NULL
    testing.period.index <- 0
    for (testing.period in TestingPeriods()) {
        #cat('in BMPT at top of loop\n'); browser()
        testing.period.index <- testing.period.index + 1

        testing.period.dates <- list( first.date = testing.period$first.date
                                     ,last.date = testing.period$last.date
                                     )

        mdti <- Driver(testing.period.dates, transformed.data)
        Model <- mdti$Model
        ModelIndexToTrainingDays <- mdti$ModelIndexToTrainingDays

        experiment.name <- sprintf( 'Bmtp %s testing period %d'
                                   ,control$choice
                                   ,testing.period.index
                                   )
        cv.result <- CrossValidate( data = transformed.data
                                   ,nfolds = control$nfolds
                                   ,Models = Model
                                   ,Assess = Assess
                                   ,experiment = experiment.name
                                   )

        #cat('in Bmpt after cv.result\n'); browser()
        best.model.index <- cv.result$best.model.index
        next.row <- data.frame( stringsAsFactors = FALSE
                               ,first.testing.date = testing.period$first.date
                               ,last.testing.date = testing.period$last.date
                               ,year = testing.period$year
                               ,month = testing.period$month
                               ,best.model.index = best.model.index
                               ,training.days = ModelIndexToTrainingDays(best.model.index)
                               )

        if (is.null(all.row)) {
            all.row <- next.row
        } else {
            all.row <- rbind(all.row, next.row)
        }

        if (verbose) {
            print('testing period')
            print(testing.period)
            print('all.row')
            print(all.row)
        }

    }


    file = paste0( control$dir.output
                  ,control$me
                  ,'-bmtp-'
                  ,control$choice
                  ,'.rsave'
                  )
    save( all.row
         ,file = file
         )
}


Main <- function(control, transformed.data) {
    # execute one command, return NULL
    #cat('starting Main', control$what, control$which, nrow(transformed.data), '\n'); browser()


    switch( control$what
           ,cv = Cv(control, transformed.data)
           ,an = An(control, transformed.data)
           ,bmpt = Bmtp(control, transformed.data)
           )

    NULL
}

###############################################################################
# EXECUTION STARTS HERE
###############################################################################

# handle command line and setup control variables
#command.args <- CommandArgs(ifR = list('--what', 'an', '--choice', '01'))
command.args <- CommandArgs(ifR = list('--what', 'bmpt', '--choice', 'assessor'))
#command.args <- CommandArgs(ifR = list('--what', 'cv', '--choice', '01'))
#command.args <- CommandArgs(ifR = list('--what', 'cv', '--choice', '02'))
#command.args <- CommandArgs(ifR = list('--what', 'cv', '--choice', '03'))
#command.args <- CommandArgs(ifR = list('--what', 'cv', '--choice', '04'))
#command.args <- CommandArgs(ifR = list('--what', 'cv', '--choice', '05'))
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
