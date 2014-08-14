ModelLinearTestMakeReport <- function(all.results) {
    # return list of character lines that summarize results in all.result
    cat('start ModelLinearTestMakeReport\n'); browser()

    # format of the header and data lines in the report
    format.header <- '%15s %15s %15s %15s %15s %15s'
    format.data <-   '%15s %15s %15.0f %15.0f %15.0f %15.0f'
    
    Header <- function(a,b,c,d,e,f) {
        sprintf(format.header, a, b, c, d, e, f)
    }


    report <- c( Header(' ',          ' ',          ' ' ,       'RMSE',       'RMSE',       ' ')
                ,Header(' ',          'assessment', ' ' ,       'avm',        'avm',        ' ' )
                ,Header('assessment', 'relative',   'RMSE',     'w/o',        'w/',         'RMSE')
                ,Header('bias',       'error',      'assessor', 'assessment', 'assessment', 'mortgage')
                ,Header(' ',          ' ',          ' ',        ' ',          ' ',          ' ')
                )

    Data <- function(assessment.bias, assessment.relative.error) {
        Rmse <- function(scenario) {
            #cat('start Rmse', assessment.bias, assessment.relative.error, scenario, '\n'); browser()
            all.results[all.results$assessment.bias == assessment.bias &
                        all.results$assessment.relative.error == assessment.relative.error &
                        all.results$scenario == scenario, 'rmse']
        }
        sprintf( format.data
                ,assessment.bias
                ,assessment.relative.error
                ,Rmse('assessor')
                ,Rmse('avm w/o assessment')
                ,Rmse('avm w/ assessment')
                ,Rmse('mortgage')
                )
    }

    for (assessment.bias in unique(all.results$assessment.bias)) {
        for (assessment.relative.error in unique(all.results$assessment.relative.error)) {
            line <- Data(assessment.bias, assessment.relative.error)
            report <- c(report, line)
        }
    }
    report
}


