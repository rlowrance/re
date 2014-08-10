# model-linear-test-chart.R
# main program to produce all charts associated with model-linear-test.R
# that program compares results on a synthetic data set

source('InitializeR.R')
source('ModelLinearTestPrintAllResults.R')
source('Printf.R')


Main <- function() {
    #cat('start Main\n'); browser()
    path.in  <- '../data/v6/output/model-linear-test.rsave'
    path.out.txt <- '../data/v6/output/model-linear-test-chart1.txt'
    #path.out.tex <- '../data/v6/output/model-linear-test-chart2.tex'

    loaded.variables <- load(path.in)
    stopifnot(length(loaded.variables) == 1)
    stopifnot(loaded.variables[[1]] == 'all.results')

    ModelLinearTestPrintAllResults( all.results
                                   ,file = path.out.txt
                                   )

}

InitializeR()
Main()
