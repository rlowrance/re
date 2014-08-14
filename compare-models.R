# compare-models.R
# Main program to compare models
# driven by command line arguments, which have this syntax
# Rscript compare-models.R --what cv   --choice NUM --> produce file OUTPUT/compare-models-NUM.txt
#                          --what plot --choice NUM --> produce file OUTPUT/compare-models-plot-NUM.pdf


#library(ggplot2)

# must source Require.R first
source('Require.R')  # read function definition file if function does not exist

source('Assess.R')
source('CommandArgs.R')

source('CompareModelsAn01.R')

source('CompareModelsAvmVariants.R')

source('CompareModelsCv01.R')
source('CompareModelsCv02.R')
source('CompareModelsCv03.R')
source('CompareModelsCv04.R')
source('CompareModelsCv05.R')


source('CompareModelsSfpLinear.R')

source('CrossValidate.R')
source('DaysInMonth.R')
source('DivisibleBy.R')

source('ExecutableName.R')
source('IfThenElse.R')
source('InitializeR.R')

source('ListAppend.R')
source('MakeModelLinear.R')
source('ModelLinear.R')
source('ParseCommandLine.R')
source('Predictors.R')

source('Printf.R')
source('ReadAndTransformTransactions.R')
source('ReadSplit.R')
source('Rmse.R')
source('RootMedianSquaredError.R')

source('TestingPeriods.R')
source('WithinXPercent.R')

## handle command line, explicit and implicit

ParseCommandLineArguments <- function(cl) {
    # parse command line into a list
    # ARGS
    # cl : chr vector of arguments in form --KEYWORD value
    #cat('starting ParseCommandLineArguments\n'); browser()
    result <- ParseCommandLine( cl
                               ,keywords = c('what', 'choice', 'index')
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

    result$path.in.base <- paste0(result$dir.output, 'transactions-subset1')
    result$path.in.subset1 <- paste0(result$path.in.base, '.csv.gz')


    prefix <- paste0(result$dir.output, 
                     result$me, 
                     '-', 
                     tolower(control$what), 
                     '-', 
                     sprintf('%s', control$choice))
    result$path.out.log <- paste0(prefix, '-log.txt')
    result$path.out.driver.result <- paste0(prefix, '.rsave')


    # control variables for all the experiments
    result$nfolds <- 10

    # whether testing
    result$testing <- TRUE
    result$testing <- FALSE
    result
}

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

    #cat('starting Bmtp', control$choice, nrow(transformed.data), '\n'); browser()

    verbose <- TRUE

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
        all.row <- IfThenElse(is.null(all.row), next.row, rbind(all.row, next.row))

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


SfpLinear <- function(control, transformed.data) {
    # dispatch based on control$choice

    result <- CompareModelsSfpLinear(control, transformed.data)
    result
}

AvmVariants <- function(control, transformed.data) {
    # dispatch based on control$choice

    result <- CompareModelsAvmVariants(control, transformed.data)
    result
}


Main <- function(control, transformed.data) {
    # execute one command, return NULL
    #cat('starting Main', control$what, control$which, nrow(transformed.data), '\n'); browser()


    switch( control$what
           ,cv = Cv(control, transformed.data)
           ,an = An(control, transformed.data)
           ,bmpt = Bmtp(control, transformed.data)
           ,sfpLinear = SfpLinear(control, transformed.data)
           ,avmVariants = AvmVariants(control, transformed.data)
           )

    NULL
}

###############################################################################
# EXECUTION STARTS HERE
###############################################################################

# handle command line and setup control variables
#command.args <- CommandArgs(ifR = list('--what', 'an', '--choice', '01'))
#command.args <- CommandArgs(ifR = list('--what', 'bmpt', '--choice', 'assessor'))
#command.args <- CommandArgs(ifR = list('--what', 'cv', '--choice', '01'))
#command.args <- CommandArgs(ifR = list('--what', 'cv', '--choice', '02'))
#command.args <- CommandArgs(ifR = list('--what', 'cv', '--choice', '03'))
#command.args <- CommandArgs(ifR = list('--what', 'cv', '--choice', '04'))
#command.args <- CommandArgs(ifR = list('--what', 'cv', '--choice', '05'))
#command.args <- CommandArgs(defaultArgs = list( '--what',       'sfpLinear'
#                                               ,'--choice',     'shard'
#                                               ,'--index',      '1'
#                                               )
#)
#command.args <- CommandArgs(defaultArg = list( '--what',       'sfpLinear'
#                                              ,'--choice',     'combine'
#                                              )
#)
command.args <- CommandArgs(defaultArg = list( '--what',       'avmVariants'
                                              ,'--choice',     'loglevel10'
                                              )
)
#print('command.args')
print(command.args) 

control <- AugmentControlVariables(ParseCommandLineArguments(command.args))

# initilize R
InitializeR(start.JIT = FALSE,
            duplex.output.to = control$path.out.log)

# speed up debugging by caching the transformed data
force.refresh.transformed.data <- FALSE 
force.refresh.transformed.data <- TRUE
if(force.refresh.transformed.data || !exists('transformed.data')) {
    ReadSplits <- function() {
        cat('building transformed data for sfpLinear\n')
        #browser()
        split.names <- c( 'saleDate'  # dates are used to select testing and training data
                         ,'recordingDate'
                         ,'price'
                         ,'log.price'
                         ,'apn'
                         ,Predictors('Chopra', form = 'log', center = TRUE, useAssessment = TRUE)
                         ,Predictors('Chopra', form = 'log', center = FALSE, useAssessment = TRUE)
                         ,Predictors('Chopra', form = 'level', center = TRUE, useAssessment = TRUE)
                         ,Predictors('Chopra', form = 'level', center = FALSE, useAssessment = TRUE)
                         ,Predictors('Chopra', form = 'log', center = TRUE, useAssessment = FALSE)
                         ,Predictors('Chopra', form = 'log', center = FALSE, useAssessment = FALSE)
                         ,Predictors('Chopra', form = 'level', center = TRUE, useAssessment = FALSE)
                         ,Predictors('Chopra', form = 'level', center = FALSE, useAssessment = FALSE)
                         )
        split.names.unique <- unique(split.names)
        transformed.data <- NULL 
        for (split.name in split.names.unique) {
            new.column <- ReadSplit( path.in = control$path.in.base
                                    ,split.name = split.name
                                    ,nrow = ifelse(control$testing, 1000, -1)
                                    ,verbose = TRUE
                                    )
            cat('new.column', split.name, '\n')
            transformed.data <- IfThenElse(is.null(transformed.data),
                                           new.column,
                                           cbind(transformed.data, new.column))
        }
        #cat('transformed.data\n'); browser()
        transformed.data
    }
    transformed.data <- ReadSplits()
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
