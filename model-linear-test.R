# model-linear-test.R DEPRECATED
# main program to test ModelLinear
# Approach: use synthetic data

stop('DEPRECATED; use e-avm-variants-synthetics-data.R instead')

library(devtools)
load_all('/Users/roy/Dropbox/lowranceutilitiesr')

source('Assess.R')
source('DataSynthetic.R')
source('MakeModelLinear.R')
source('ModelLinearTestMakeReport.R')

Sweep <- function(f, assessment.biases, assessment.relative.errors) {
    # return data.frame containing a row for each element in cross product of list1 and list2
    # and scenario and rmse for that scenario on appropriate synthetic data
    #cat('Sweep\n'); browser()

    # build up a data.frame
    all <- NULL
    for (assessment.bias in assessment.biases) {
        for (assessment.relative.error in assessment.relative.errors) {
            one <- f(assessment.bias, assessment.relative.error)
            new.row <- data.frame( stringsAsFactors = FALSE
                                  ,assessment.bias = assessment.bias
                                  ,assessment.relative.error = assessment.relative.error
                                  ,scenario = one$scenario
                                  ,rmse = one$rmse
                                  )
            all <- if(is.null(all)) new.row else rbind(all, new.row)
        }
    }
    all
}

Main <- function() {
    # Run experiments over cross product of situations, return df containing RMSE values
    
    #cat('start Main\n'); browser()
    result.df <- Sweep( f = Experiment
                       ,assessment.biases = c('zero', 'low')
                       ,assessment.relative.errors = c('lower', 'same', 'higher')
                       )
    save(result.df, file = '../data/v6/output/model-linear-test.rsave')

    # write a report to the console
    report <- ModelLinearTestMakeReport(result.df)
    writeLines( text = report
               ,sep  = '\n'
               )

    return(result.df)
}

InitializeR(duplex.output.to = '../data/v6/output/model-linear-test-log.txt')
Main()
