# compare-models.R
# Main program to create charts from the results of running compare-models
# driven by command line arguments, which have this syntax
# Rscript compare-models.R --what cv   --choice NUM   --> produce file OUTPUT/compare-models-NUM.txt
#                          --what plot --choice NUM --> produce file OUTPUT/compare-models-plot-NUM.pdf

library(ggplot2)

source('Require.R')  # read function definition file if function does not exist

Require('InitializeR')
Require('Printf')

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
            cat('unexpected argument and its value skipped', keyword, '\n')
        }
        cl.index <- cl.index + 2
    }
    result
}

AugmentControlVariables <- function(control) {
    # add additional control variables to list of control variables
    #cat('starting AugmentControlVariables\n'); browser()
    result <- control
    result$me <- 'compare-models-cv-chart'

    # input/output
    result$dir.output <- '../data/v6/output/'
    
    Prefix <- function(program.name) {
        paste0(result$dir.output,
               program.name,
               '-', control$what,
               '-', sprintf('%02d', control$choice))
    }

    prefix.in <- Prefix('compare-models')
    prefix.out <-Prefix(result$me)

    result$path.in.driver.result <- paste0(prefix.in, '-driver.result.rsave')

    result$path.out.log <- paste0(prefix.out, '-log.txt')
    result$path.out.chart1 <- paste0(prefix.out, '-chart1.pdf')

    # control variables for all the experiments

    result$testing <- TRUE
    #result$testing <- FALSE
    result
}

CvChart <- function(driver.result) {
    # produce plot showing descriptions, mean RMSEs, and fractions within 10 percent
    cat('starting CvChart\n'); print(names(driver.result)); browser()
    cv.result <- driver.result$cv.result
    descriptions <- driver.result$descriptions

    best.model.index <- cv.result$best.model.index
    all.results <- cv.result$all.results

    nmodels <- max(all.results$model.index)
    mean.rmse <- 
        lapply(1:nmodels,
               function(x) mean(all.results[all.results$model.index == x, 'evaluation.rmse']))
    mean.within.10.percent <- 
        lapply(1:nmodels,
               function(x) mean(all.results[all.results$model.index == x, 'evaluation.within.10.percent']))


    cat('in CvChart\n'); browser()
    
}


Cv <- function(control) {
    # create all the charts for experiment control$what control$choice
    #cat('starting Cv', control$choice, '\n'); browser()

    variables.loaded <- load(control$path.in.driver.result)
    stopifnot(variables.loaded[[1]] == 'driver.result')
    CvChart(driver.result)
    NULL
}


Main <- function(control) {
    # execute one command, return NULL
    #cat('starting Main', control$what, '\n'); browser()

    switch(control$what,
           cv = Cv(control))

    NULL
}


###############################################################################
# EXECUTION STARTS HERE
###############################################################################

# handle command line and setup control variables
ignore.command.line <- TRUE
if (ignore.command.line) {
    command.args <- list('--what', 'cv', '--choice', 1)
} else {
    command.args <- commandArgs()
}

control <- AugmentControlVariables(ParseCommandLineArguments(command.args))

# initilize R
InitializeR(start.JIT = FALSE,
            duplex.output.to = control$path.out.log)

# do the work
Main(control)

cat('control variables\n')
str(control)

if (control$testing) {
    cat('DISCARD RESULTS: TESTING\n')
}

cat('done\n')
