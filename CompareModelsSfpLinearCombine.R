CompareModelsSfpLinearCombine <- function( control
                                          ,transformed.data
                                          ,num.testing.periods
                                          ,PathShard
                                          ,PathCombined
                                          ) {
    # combine shards OUTPUT/compare-models-shard-SCENARIO-RESPONSE-PREDICTORS.rsave
    # into           OUTPUT/compare-models-combined.rsave
    #cat('starting CompareModelsSfpLinearCombine\n'); browser()
    testing <- FALSE
    if (testing) {
        num.testing.periods <- 12
    }

    all.rows <- NULL
    for (testing.period.index in 1:num.testing.periods) {
        path.in <- PathShard(control, testing.period.index)
        names.loaded <- load(path.in)
        stopifnot(length(names.loaded) == 1)
        stopifnot(names.loaded[[1]] == 'all.row')
        all.rows <- IfThenElse(is.null(all.rows), all.row, rbind(all.rows, all.row))
    }

    cat('Combine about to write\n'); browser()
    path.out <- PathCombined(control)
    save(all.rows, file = path.out)
}
