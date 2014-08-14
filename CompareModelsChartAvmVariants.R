CompareModelsChartAvmVariants <- function(control) {
    # product charts for Avm Variants

    ChartLogLevel10 <- function(experiment.result) {
        # return list of char vector lines
        #cat('start ChartLogLevel10\n'); browser()

        format.header <- '%25s | %20s %20s'
        format.data <-   '%25s | %20.0f %20.0f'

        result <- 'Prediction log(price) using level predictors and 10-fold cross validation'
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

    WriteLogLevel10 <- function(control, cv.result, description, experiment.result) {
        # write txt file
        #cat('start WriteLogLevel10\n'); browser()

        # create the lines
        lines <- ChartLogLevel10(experiment.result)

        # write the lines 
        path.out <- paste0(control$dir.out, 'compare-models-chart-avmvariants-loglevel10-chart1.txt')
        connection <- file(path.out, 'w')
        writeLines( text = lines
                   ,con = connection
                   ,sep = '\n'
                   )
        close(connection)
    }

    #cat('start CompareModelsChartAvmVariants\n'); browser()

    # read input variables
    path.in <- paste0( control$dir.output
                      ,'compare-models-avmvariants-'
                      ,control$choice
                      ,'.rsave'
                      )
    control <- NULL
    cv.result <- NULL
    description <- NULL
    experiment.result <- NULL
    variables.loaded <- load(path.in)
    stopifnot(length(variables.loaded) == 3)
    stopifnot(!is.null(control))
    stopifnot(!is.null(cv.result))
    stopifnot(!is.null(description))
    stopifnot(!is.null(experiment.result))

    switch( control$choice
           ,loglevel10 = WriteLogLevel10(control, cv.result, description, experiment.result)
           ,stop('bad control$choice')
           )
}
