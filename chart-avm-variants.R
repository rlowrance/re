# chart-avm-variants.R
# main program to produce all the charts for experiment e-avm-variants

library(devtools)
load_all('/Users/roy/Dropbox/lowranceutilitiesr')
load_all('/Users/roy/Dropbox/lowrancerealestater')

ReadRsave <- function(control) {
    #cat('start ReadRsave', control$path.in, '\n'); browser()
    variables.loaded <- load(control$path.in)
    stopifnot(length(variables.loaded) == 4)
    stopifnot(!is.null(description))
    stopifnot(!is.null(control))
    stopifnot(!is.null(all.result))
    stopifnot(!is.null(strata.results))
    result <- list( description = description
                   ,control = control  # not the arg, but the value from load
                   ,all.result = all.result
                   ,strata.results = strata.results
                   )
    result
}

CreateChart1Body <- function(control, all.result) {
    #cat('start CreateChart1Body\n'); browser()
    result <- sprintf(control$chart1.format.header, 'scenario', 'mean RMSE', 'median RMedianSE')

    for (row.index in 1:nrow(all.result)) {
        result <- c( result
                    ,sprintf( control$chart1.format.data
                             ,all.result$experiment.name[[row.index]]
                             ,all.result$mean.RMSE[[row.index]]
                             ,all.result$median.RMedianSE[[row.index]]
                             )
                    )
    }

    result
}

CreateChart1 <- function(control, description, all.result) {
    # return a vector of lines, the txt for chart 1
    #cat('start CreateChart1\n'); browser()

    result <- c( description
                ,' '
                ,CreateChart1Body(control, all.result)
                )

    result
}

CreateChart2 <- function(control, experiment.control, description, strata.results) {
    # return a vector of lines, the txt for chart 2
    #cat('start CreateChart2\n'); browser()

    header <- c( 'AVM Variants by Strata'
                ,'Strata defined by median household income in census tract'
                )

    CreateStrataChart <- function(strata.info) {
        StrataHeader <- function () {
            paste0('results for strata: ', strata.info$strata.name)
        }
        result <- c( ' '
                    ,' '
                    ,StrataHeader()
                    ,' '
                    ,CreateChart1Body(control, strata.info$experiment.result)
                    )
        result
    }

    body <- sapply(strata.results, CreateStrataChart)

    Legend <- function() {
        c( 'Legend:'
          ,sprintf( 'wealthy neighborhood: census tract with median household income %4.2f x average household income'
                   ,experiment.control$rich
                   )
          ,sprintf( 'poor neighborhood: census tract with median household income %4.2f x average household income'
                   ,experiment.control$poor
                   )
          ,'middle class neighborhood: all other census tracts'
          )
    }

    result <- c( header
                ,' '
                ,body
                ,' '
                ,Legend()
                )
    result
}


Main <- function() {
    #cat('start Main'); browser()

    path.output = '../data/v6/output/'
    my.name <- 'chart-avm-variants'
    experiment.name <- 'e-avm-variants'

    PathIn <- function() {
        final.version.available <- TRUE
        if (final.version.available) {
            paste0(path.output, experiment.name, '.rsave')
        } else {
            paste0(path.output, experiment.name, '.2014-08-20', '.rsave')
        }
    }
    
    control <- list( response = 'log.price'
                    ,path.in = PathIn()
                    ,path.out.log = paste0(path.output, my.name, '.log')
                    ,path.out.chart1 = paste0(path.output, my.name, '-chart1.txt')
                    ,path.out.chart2 = paste0(path.output, my.name, '-chart2.txt')
                    ,chart1.format.header = '%27s | %20s %20s'
                    ,chart1.format.data =   '%27s | %20.0f %20.0f'
                    )
    
    InitializeR(duplex.output.to = control$path.out.log)
    print(control)


    rs <- ReadRsave(control)
    chart1 <- CreateChart1( control = control
                           ,description = rs$description
                           ,all.result = rs$all.result
                           )
    writeLines( text = chart1
               ,con = control$path.out.chart1
               )

    chart2 <- CreateChart2( control = control
                           ,experiment.control = rs$control
                           ,description = rs$description
                           ,strata.results = rs$strata.results
                           )
    writeLines( text = chart2
               ,con = control$path.out.chart2
               )

    print(control)
}



Main()
cat('done\n')
