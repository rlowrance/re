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

ChartComponents <- function(control, rsave) {
    # return a list, each element a vector of lines, for the components in a chart
    #cat('start ChartComponents\n'); browser()
    result.df <- rsave$result.df

    # format of the header and data lines in the report
    format.header <- '   %12s %12s %12s %12s %12s %12s'
    format.data <-   '%12s %12s %12.0f %12.0f %12.0f %12.0f'  # line numbers NN_ are prepended

    # identify key choices in the experiment
    inflation.rate <- sprintf( 'ASSUMING INFLATION RATE OF %0.2f ANNUALLY'
                              ,100 * rsave$control$inflation.annual.rate
                              )
    title <- c( 'COMPARISON OF ROOT MEAN SQUARED ERRORS'
                ,'BY SCENARIO'
                ,'BY BIAS IN THE ASSESSMENT'
                ,'BY ACCURACY OF THE ASSESSMENT RELATIVE TO THE MARKET'
                ,inflation.rate
                )
    
    Header <- function(a,b,c,d,e,f) {
        sprintf(format.header, a, b, c, d, e, f)
    }


    header <- c( Header(' ',          ' ',          ' ' ,       'RMSE',       'RMSE',       ' ')
                ,Header(' ',          'assessment', ' ' ,       'avm',        'avm',        ' ' )
                ,Header('assessment', 'relative',   'RMSE',     'w/o',        'w/',         'RMSE')
                ,Header('bias',       'error',      'assessor', 'assessment', 'assessment', 'mortgage')
                )

    Data <- function(assessment.bias.name, assessment.relative.sd.name, body.line.number) {
        # return data line 
        Rmse <- function(scenario) {
            #cat('start Rmse', assessment.bias, assessment.relative.error, scenario, '\n'); browser()
            result.df[result.df$assessment.bias.name== assessment.bias.name &
                      result.df$assessment.relative.sd.name == assessment.relative.sd.name &
                      result.df$scenario == scenario, 'rmse']
        }
        line.without.number <- sprintf( format.data
                                       ,assessment.bias.name
                                       ,assessment.relative.sd.name
                                       ,Rmse('assessor')
                                       ,Rmse('avm w/o assessment')
                                       ,Rmse('avm w/ assessment')
                                       ,Rmse('mortgage')
                                       )
        line.with.number <- sprintf('%02d %s', body.line.number, line.without.number)
        line.with.number
    }

    body <- NULL
    body.line.number <- 0
    for (assessment.bias.name in unique(result.df$assessment.bias.name)) {
        for (assessment.relative.sd.name in unique(result.df$assessment.relative.sd.name)) {
            body.line.number <- body.line.number + 1  
            line <- Data(assessment.bias.name, assessment.relative.sd.name, body.line.number)
            body <- c(body, line)
        }
        body <- c(body, ' ')
    }

    ARE <- function(name) {
        sprintf( 'assessment relative error: %s --> sd(assessment error) = %0.2f x true value'
                ,name
                ,rsave$control$assessment.relative.sd.values[[name]]
                )
    }

    AREM <- function(name) {
        value <- rsave$control$assessment.relative.sd.values[[name]]
        multiplier <- value / rsave$control$market.sd.fraction
        sprintf( 'assessment relative error: %s --> sd(assessment error) = %4.2f x sd(market value)'
                ,name
                ,multiplier
                )
    }

    legend <- c( 'assessment bias: zero --> mean(assessment) == mean(true value)'
                ,'assessment bias: lower --> mean(assessment) < mean(true value)'
                ,'assessment bias: higher --> mean(assessment) > mean(true value)'
                ,ARE('nearzero')
                ,AREM('lower')
                ,AREM('same')
                ,AREM('higher')
                ,sprintf('where sd market value = %4.2f', rsave$control$market.sd.fraction)
                )

    result <- list( title = title
                   ,header = header
                   ,body = body
                   ,legend = legend
                   )
    result
}

Chart1 <- function(components) {
    result <- c( components$title
                ,' '
                ,components$header
                ,' '
                ,components$body
                )
    result
}

Chart2 <- function(components) {
    #cat('start CreateChart2\n'); browser()
    result <- c( Chart1(components)
                ,' '
                ,components$legend
                )
    result
}
    
Main <- function() {
    #cat('start Main\n'); browser()

    path.output = '../data/v6/output/'
    my.name <- 'chart-avm-variants-synthetic-data'
    experiment.name <- 'e-avm-variants-synthetic-data'
    control <- list( path.in = paste0(path.output, experiment.name, '.rsave')
                    ,path.out.log = paste0(path.output, my.name, '.log')
                    ,path.out.chart1 = paste0(path.output, my.name, '-chart1.txt')
                    ,path.out.chart2 = paste0(path.output, my.name, '-chart2.txt')
                    )
    
    InitializeR(duplex.output.to = control$path.out.log)
    print(control)


    rsave <- ReadRsave(control)
    
    chart.components <- ChartComponents( control = control
                                        ,rsave = rsave
                                        )

    chart1 <- Chart1(chart.components)
    writeLines( text = chart1
               ,con = control$path.out.chart1
               )

    chart2 <- Chart2(chart.components)
    writeLines( text = chart2
               ,con = control$path.out.chart2
               )

    writeLines( text = chart2)  # append to stdout

    print(control)
}



Main()
cat('done\n')
