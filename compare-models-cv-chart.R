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



Varying <- function(descriptions) {
    # return chr vector of varying portions of names
    #cat('starting Varying\n'); browser()

    # pull out each field
    scenario <- lapply(descriptions, function(x) x$scenario)
    testing.period.first.date <- lapply(descriptions, function(x) x$testing.period$first.date)
    testing.period.last.date <- lapply(descriptions, function(x) x$testing.period$last.date)
    training.period <- lapply(descriptions, function(x) x$training.period)
    model <- lapply(descriptions, function(x) x$model)
    response <- lapply(descriptions, function(x) x$response)
    predictors <- lapply(descriptions, function(x) x$predictors)

    varying.values <- NULL
    varying.names <- NULL

    MaybeAppend <- function(name, values) {
        #cat('starting MaybeAppend\n'); browser()
        AllSame <- function(values) {
            #cat('starting AllSame\n'); browser()
            result <- all(values == values[[1]])
            result
        }
        if (!AllSame(values)) {
            #cat('not all same'); browser()
            n <- length(values)
            if (is.null(varying.values)) {
                lapply(1:n, function(i) varying.values[[i]] <<- values[[i]])
            } else {
                lapply(1:n, function(i) varying.values[[i]] <<- paste(varying.values[[i]], values[[i]]))
            }
            varying.names <<- paste(varying.names, name)
            if (FALSE) {
                print('varying.values'); print(varying.values)
                print('varying.names'); print(varying.names)
            }
        }
    }

    # build up varying and varying.names to be just the fields that are not all the same
    MaybeAppend('scenario', scenario)
    MaybeAppend('testing.period.first.date', testing.period.first.date)
    MaybeAppend('testing.period.last.date', testing.period.last.date)
    MaybeAppend('training.period', training.period)
    MaybeAppend('model', model)
    MaybeAppend('response', response)
    MaybeAppend('predictors', predictors)

    result <- list(values = varying.values, names = varying.names)
    result
}

CvChart <- function(driver.result) {
    # produce plot showing descriptions, mean RMSEs, and fractions within 10 percent
    cat('starting CvChart\n'); print(names(driver.result)); browser()
    cv.result <- driver.result$cv.result

    # pull out each description component
    descriptions <- driver.result$descriptions
    varying <- Varying(descriptions)
    varying.values <- varying$values
    varying.names <- varying$names
    

    best.model.index <- cv.result$best.model.index
    all.results <- cv.result$all.results

    nmodels <- max(all.results$model.index)
    mean.rmse <- 
        lapply(1:nmodels,
               function(x) mean(all.results[all.results$model.index == x, 'evaluation.rmse']))
    mean.within.10.percent <- 
        lapply(1:nmodels,
               function(x) mean(all.results[all.results$model.index == x, 'evaluation.within.10.percent']))

    
    cat('in CvChart: create chart!\n'); browser()


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
