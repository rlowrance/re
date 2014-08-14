# compare-model-chart.R
# Main program to create charts from the results of running compare-models
# driven by command line arguments, which have this syntax
# Rscript compare-models.R --what cv   --choice NUM   -->  (OLD)
#   produce file OUTPUT/compare-models-cv-chart-chart-NUM.pdf
# Rscript compare-models-chart.R --what XXX -- choice YYY -->
#   produce file OUTPUT/compare-models-chart-XXX-YYY.pdf

library(ggplot2)


source('CommandArgs.R')

source('CompareModelsChartAvmVariants.R')
source('CompareModelsChartBmtp.R')
source('CompareModelsChartCv.R')
source('CompareModelsChartSfpLinear.R')

source('InitializeR.R')
source('ParseCommandLine.R')
source('Printf.R')

ParseCommandLineArguments <- function(cl) {
    # parse command line into a list
    # ARGS
    # cl : chr vector of arguments in form --KEYWORD value
    #cat('starting ParseCommandLine\n'); browser()
    result <- ParseCommandLine( cl
                               ,keywords = c('what', 'choice')
                               ,ignoreUnexpected = TRUE
                               ,verbose = TRUE
                               )
    result
}

AugmentControlVariables <- function(control) {
    # add additional control variables to list of control variables
    #cat('starting AugmentControlVariables\n'); browser()
    result <- control
    result$me <- 'compare-models-chart'

    # input/output
    result$dir.output <- '../data/v6/output/'
    
    Prefix <- function(program.name) {
        paste0(result$dir.output,
               program.name,
               '-', control$what,
               '-', control$choice)
    }

    prefix.in <- Prefix('compare-models')
    prefix.out <-Prefix(result$me)

    result$path.in.driver.result <- paste0(prefix.in, '.rsave')

    result$path.out.log <- paste0(prefix.out, '-log.txt')
    result$path.out.chart1 <- paste0(prefix.out, '-chart-1.pdf')

    # control variables for all the experiments

    result$testing <- TRUE
    result$testing <- FALSE
    result
}








Main <- function(control) {
    # execute one command, return NULL
    #cat('starting Main', control$what, '\n'); browser()

    driver <- switch( control$what
                     ,cv = CompareModelsChartCv
                     ,bmtp = CompareModelsChartBmtp
                     ,sfpLinear = CompareModelsChartSfpLinear
                     ,avmvariants = CompareModelsChartAvmVariants
                     ,stop('bad control$what')
                     )
    driver(control)
}


###############################################################################
# EXECUTION STARTS HERE
###############################################################################

# handle command line and setup control variables
#command.args <- CommandArgs(defaultArgs = list('--what', 'cv', '--choice', '01'))
#command.args <- CommandArgs(defaultArgs = list('--what', 'bmtp', '--choice', 'assessor'))
#command.args <- CommandArgs(defaultArgs = list('--what', 'sfpLinear', '--choice', '01'))
#command.args <- CommandArgs(defaultArgs = list('--what', 'sfpLinear', '--choice', '02'))
#command.args <- CommandArgs(defaultArgs = list('--what', 'sfpLinear', '--choice', '03'))
command.args <- CommandArgs(defaultArgs = list('--what', 'avmvariants', '--choice', 'loglevel10'))

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
