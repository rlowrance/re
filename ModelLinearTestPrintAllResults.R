ModelLinearTestPrintAllResults <- function(all.results, file='') {
    # write txt file using Printf()
    cat('start ModelLinearTestPrintAllResults', file, '\n'); browser()

    if (file != '') {
        connection <- file(file, 'w')
    }

    P <- function(...) {
        if (file == '') {
            Printf(...) 
        } else {
            Printf(..., file = connection)  # append to cat file
        }
    }

    assessment.biases <- unique(all.results$assessment.bias)

    format.header <- '%15s %15s %15s %15s %15s %15s\n'
    format.data <-   '%15s %15s %15.0f %15.0f %15.0f %15.0f\n'

    PrintHeader <- function(a,b,c,d,e,f) {
        P(format.header, a, b, c, d, e, f)
    }

    PrintHeader(' ',          ' ',          ' ' ,       'RMSE',       'RMSE',       ' ')
    PrintHeader(' ',          'assessment', ' ' ,       'avm',        'avm',        ' ' )
    PrintHeader('assessment', 'relative',   'RMSE',     'w/o',        'w/',         'RMSE')
    PrintHeader('bias',       'error',      'assessor', 'assessment', 'assessment', 'mortgage')
    PrintHeader(' ',          ' ',          ' ',        ' ',          ' ',          ' ')

    PrintData <- function(assessment.bias, assessment.relative.error) {
        Rmse <- function(scenario) {
            #cat('start Rmse', assessment.bias, assessment.relative.error, scenario, '\n'); browser()
            all.results[all.results$assessment.bias == assessment.bias &
                        all.results$assessment.relative.error == assessment.relative.error &
                        all.results$scenario == scenario, 'rmse']
        }
        P( format.data
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
            PrintData(assessment.bias, assessment.relative.error)
        }
    }

    if (file != '') {
        close(connection)
    }
}
