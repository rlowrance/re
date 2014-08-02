# CompareModelsChartSfpLinear.R

SfpLinearChart01 <- function(all.rows, path.out.base) {
    # write csv file
    #cat('starting SpfLinearChart01\n'); browser()
    path.out <- paste0(path.out.base, '.csv')
    write.csv( all.rows
              ,file=path.out)
}

SfpLinearChart <- function(control, all.rows) {
    # write file OUTPUT/compare-models-chart-sfplinear-NN.KIND
    # where NN is control$choice

    path.out.base <- paste0(control$dir.output, control$me, '-sfplinear-combine-chart', control$choice)
    switch( control$choice
           ,'01' = SfpLinearChart01(all.rows, path.out.base)
           ,stop('bad control$choice')
           )
}

CompareModelsChartSfpLinear <- function(control) {
    ReadAllRows <- function(path) {
        # return all.rows data frame in saved file
        #cat('starting ReadAllRows', path, '\n'); browser()
        variables.loaded <- load(path)
        stopifnot(length(variables.loaded) == 1)
        stopifnot(variables.loaded[[1]] == 'all.rows')
        all.rows
    }

    cat('starting SfpLinear\n'); browser()
    verbose <- TRUE
    path.combine <- paste0(control$dir.output, 'compare-models-sfplinear-combine.rsave')
    all.rows <- ReadAllRows(path.combine)
    if (verbose) {
        print(str(all.rows))
    }
    result <- SfpLinearChart(control, all.rows)
    result
}

