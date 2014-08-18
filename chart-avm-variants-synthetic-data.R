# chart-avm-variants-synthetic-data.R
# main program to produce all the charts for experiment e-avm-variants-synthetic-data

library(devtools)
load_all('/Users/roy/Dropbox/lowranceutilitiesr')
load_all('/Users/roy/Dropbox/lowrancerealestater')

ReadRsave <- function(control) {
    # return the only variable saved by the experiment
    #cat('start ReadRsave', control$path.in, '\n'); browser()

    result.df <- NULL
    variables.loaded <- load(control$path.in)
    stopifnot(length(variables.loaded) == 2)
    stopifnot(variables.loaded[[1]] == 'control')
    stopifnot(variables.loaded[[2]] == 'result.df')
    result <- list(control = control, result.df = result.df)
    result
}

CreateChart1 <- function(control, rsave) {
    # return a vector of lines, the txt for chart 1
    #cat('start CreateChart1\n'); browser()
    result.df <- rsave$result.df

    # format of the header and data lines in the report
    format.header <- '%12s %12s %12s %12s %12s %12s'
    format.data <-   '%12s %12s %12.0f %12.0f %12.0f %12.0f'

    # identify key choices in the experiment
    inflation.rate <- sprintf( 'ASSUMING INFLATION RATE OF %0.2f ANNUALLY'
                              ,100 * rsave$control$inflation.annual.rate
                              )
    prefix <- c( 'COMPARISON OF ROOT MEAN SQUARED ERRORS'
                ,'BY SCENARIO'
                ,'BY BIAS IN THE ASSESSMENT'
                ,'BY ACCURACY OF THE ASSESSMENT RELATIVE TO THE MARKET'
                ,inflation.rate
                ,' '
                )
    
    Header <- function(a,b,c,d,e,f) {
        sprintf(format.header, a, b, c, d, e, f)
    }


    report <- c( Header(' ',          ' ',          ' ' ,       'RMSE',       'RMSE',       ' ')
                ,Header(' ',          'assessment', ' ' ,       'avm',        'avm',        ' ' )
                ,Header('assessment', 'relative',   'RMSE',     'w/o',        'w/',         'RMSE')
                ,Header('bias',       'error',      'assessor', 'assessment', 'assessment', 'mortgage')
                ,Header(' ',          ' ',          ' ',        ' ',          ' ',          ' ')
                )

    Data <- function(assessment.bias.name, assessment.relative.sd.name) {
        Rmse <- function(scenario) {
            #cat('start Rmse', assessment.bias, assessment.relative.error, scenario, '\n'); browser()
            result.df[result.df$assessment.bias.name== assessment.bias.name &
                      result.df$assessment.relative.sd.name == assessment.relative.sd.name &
                      result.df$scenario == scenario, 'rmse']
        }
        sprintf( format.data
                ,assessment.bias.name
                ,assessment.relative.sd.name
                ,Rmse('assessor')
                ,Rmse('avm w/o assessment')
                ,Rmse('avm w/ assessment')
                ,Rmse('mortgage')
                )
    }

    for (assessment.bias.name in unique(result.df$assessment.bias.name)) {
        for (assessment.relative.sd.name in unique(result.df$assessment.relative.sd.name)) {
            line <- Data(assessment.bias.name, assessment.relative.sd.name)
            report <- c(report, line)
        }
        report <- c(report, ' ')
    }
    c(prefix, report)
}


Main <- function() {
    #cat('start Main\n'); browser()

    path.output = '../data/v6/output/'
    my.name <- 'chart-avm-variants-synthetic-data'
    experiment.name <- 'e-avm-variants-synthetic-data'
    control <- list( path.in = paste0(path.output, experiment.name, '.rsave')
                    ,path.out.log = paste0(path.output, my.name, '.log')
                    ,path.out.chart1 = paste0(path.output, my.name, '-chart1.txt')
                    )
    
    InitializeR(duplex.output.to = control$path.out.log)
    print(control)


    rsave <- ReadRsave(control)
    chart1 <- CreateChart1( control = control
                           ,rsave = rsave
                           )
    #cat('about to write\n'); browser()
    writeLines( text = chart1
               ,con = control$path.out.chart1
               )
    writeLines( text=chart1)

    print(control)
}



Main()
cat('done\n')
