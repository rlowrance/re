# compare-models.R
# Main program to compare models
# driven by command line arguments, which have this syntax
# Rscript compare-models.R --what cv   --choice NUM   --> produce file OUTPUT/compare-models-NUM.txt
#                          --what plot --choice NUM --> produce file OUTPUT/compare-models-plot-NUM.pdf

source('Require.R')  # read function definition file if function does not exist

Require('Assess')
Require('CompareModelsCv01')
Require('CrossValidate')
Require('ExecutableName')
Require('InitializeR')
Require('ListAppendEach')
Require('ListSplitNames')
Require('Printf')
Require('ReadAndTransformTransactions')
Require('Rmse')
Require('WithinXPercent')

ParseCommandLineArguments <- function(cl) {
    # parse command line into a list
    # ARGS
    # cl : chr vector of arguments in form --KEYWORD value
    #cat('starting ParseCommandLine\n'); browser()
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
    control$choice <- 1  # while testing, select the first experiment
    #cat('starting Cv', control$choice, nrow(transformed.data), '\n'); browser()

    Driver <-
        switch(control$choice,
               CompareModelsCv01)  # assessor linear logprice chopra
    stopifnot(!is.null(Driver))

    Model.description <- Driver(control$testing.period, transformed.data)

    Models <- lapply(Model.description, function(x) x$Model)
    descriptions <- lapply(Model.description, function(x) x$description)

    cv.result <- CrossValidate(data = transformed.data,
                               nfolds = control$nfolds,
                               Models = Models,
                               Assess = Assess,
                               verbose = TRUE)

    Printf('Cross Validation results\n')

    Printf('Experiment description\n')
    lapply(names(descriptions),
           function(name) Printf(' %15s : %s\n', name, description[[name]]))
    
    Printf('best model index %d\n', cv.result$best.model.index)
    Printf('models compared\n')
    print(cv.result)

    # write models and results to file
    save(cv.result, Models, descriptions,
         file = control$path.out.driver.result)

    # return NULL
    NULL
}

Main <- function(control, transformed.data) {
    # execute one command, return NULL
    control$what <- 'cv'  # while debugging
    #cat('starting Main', control$what, nrow(transformed.data), '\n'); browser()


    switch(control$what,
           cv = Cv(control, transformed.data),
           plot = Plot(control, transformed.data))

    NULL
}


###############################################################################
# EXECUTION STARTS HERE
###############################################################################

# handle command line and setup control variables
executable.name <- ExecutableName()
if (executable.name == 'R') {
    # create the command args
    new.command.args <- list('--what', 'cv', '--choice', '1')
} else if (executable.name == 'Rscript') {
    # use actual command line
    new.command.args <- commandArgs()
} else {
    print(commandArgs())
    print(executable.name)
    stop('unable to handle executable.name')
}

# setup control variables
control <- AugmentControlVariables(ParseCommandLineArguments(new.command.args))

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
