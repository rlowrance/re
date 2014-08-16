# chart-avm-variants.R
# main program to produce all the charts for experiment e-avm-variants

library(devtools)
load_all('/Users/roy/Dropbox/lowranceutilitiesr')
load_all('/Users/roy/Dropbox/lowrancerealestater')

ReadRsave <- function(control) {
    #cat('start ReadRsave', control$path.in, '\n'); browser()
    cv.result <- NULL
    description <- NULL
    experiment.result <- NULL
    variables.loaded <- load(control$path.in)
    stopifnot(length(variables.loaded) == 4)
    stopifnot(!is.null(control))
    stopifnot(!is.null(cv.result))
    stopifnot(!is.null(description))
    stopifnot(!is.null(experiment.result))
    result <- list( description = description
                   ,cv.result = cv.result
                   ,experiment.result = experiment.result
                   )
    result
}

CreateChart1 <- function(control, description, experiment.result) {
    # return a vector of lines, the txt for chart 1
    #cat('start CreateChart1\n'); browser()
    format.header <- '%25s | %20s %20s'
    format.data <-   '%25s | %20.0f %20.0f'

    #result <- 'Prediction log(price) using level predictors and 10-fold cross validation'
    result <- description
    result <- c(result, ' ' )
    result <- c(result, sprintf(format.header, 'scenario', 'mean RMSE', 'median RMedianSE'))

    for (row.index in 1:nrow(experiment.result)) {
        result <- c( result
                    ,sprintf( format.data
                             ,experiment.result$experiment.name[[row.index]]
                             ,experiment.result$mean.RMSE[[row.index]]
                             ,experiment.result$median.RMedianSE[[row.index]]
                             )
                    )
    }

    result
}


Main <- function() {
    cat('start Main'); browser()

    path.output = '../data/v6/output/'
    my.name <- 'chart-avm-variants'
    experiment.name <- 'e-avm-variants'
    control <- list( response = 'log.price'
                    ,path.in = paste0(path.output, experiment.name, '.rsave')
                    ,path.in.base = paste0(path.output, 'transactions-subset1')
                    ,path.out.log = paste0(path.output, my.name, '.log')
                    ,path.out.chart1 = paste0(path.output, my.name, '-chart1.txt')
                    )
    
    InitializeR(duplex.output.to = control$path.out.log)
    print(control)


    rs <- ReadRsave(control)
    chart1 <- CreateChart1( control = control
                           ,description = rs$description
                           ,experiment.result = rs$experiment.result
                           )
    writeLines( text = chart1
               ,con = control$path.out.chart1
               )

    print(control)
}



Main()
cat('done\n')
