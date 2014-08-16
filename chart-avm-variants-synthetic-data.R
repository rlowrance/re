# chart-avm-variants-synthetic-data.R
# main program to produce all the charts for experiment e-avm-variants-synthetic-data

library(devtools)
load_all('/Users/roy/Dropbox/lowranceutilitiesr')
load_all('/Users/roy/Dropbox/lowrancerealestater')

ReadRsave <- function(control) {
    # return the only variable saved by the experiment
    cat('start ReadRsave', control$path.in, '\n'); browser()

    result.df <- NULL
    variables.loaded <- load(control$path.in)
    stopifnot(length(variables.loaded) == 1)
    stopifnot(!is.null(result.df))
    result.df
}

CreateChart1 <- function(control, result.df) {
    # return a vector of lines, the txt for chart 1
    cat('start CreateChart1\n'); browser()

    # format of the header and data lines in the report
    format.header <- '%12s %12s %12s %12s %12s %12s'
    format.data <-   '%12s %12s %12.0f %12.0f %12.0f %12.0f'
    
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
            result.df[result.df$assessment.bias == assessment.bias &
                      result.df$assessment.relative.error == assessment.relative.error &
                      result.df$scenario == scenario, 'rmse']
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

    for (assessment.bias in unique(result.df$assessment.bias)) {
        for (assessment.relative.error in unique(result.df$assessment.relative.error)) {
            line <- Data(assessment.bias, assessment.relative.error)
            report <- c(report, line)
        }
        report <- c(report, ' ')
    }
    report
}


Main <- function() {
    cat('start Main'); browser()

    path.output = '../data/v6/output/'
    my.name <- 'chart-avm-variants-synthetic-data'
    experiment.name <- 'e-avm-variants-synthetic-data'
    control <- list( path.in = paste0(path.output, experiment.name, '.rsave')
                    ,path.out.log = paste0(path.output, my.name, '.log')
                    ,path.out.chart1 = paste0(path.output, my.name, '-chart1.txt')
                    )
    
    InitializeR(duplex.output.to = control$path.out.log)
    print(control)


    result.df <- ReadRsave(control)
    chart1 <- CreateChart1( control = control
                           ,result.df = result.df
                           )
    cat('about to write\n'); browser()
    writeLines( text = chart1
               ,con = control$path.out.chart1
               )

    print(control)
}



Main()
cat('done\n')
