CompareModelsSfpLinearCombine <- function( control
                                          ,transformed.data
                                          ,num.testing.periods
                                          ,PathShard
                                          ,PathCombined
                                          ) {
    # combine shards OUTPUT/compare-models-shard-SCENARIO-RESPONSE-PREDICTORS.rsave
    # into           OUTPUT/compare-models-combined.rsave
    cat('starting CompareModelsSfpLinearCombine\n'); browser()

    all.rows <- NULL
    for (testing.period.index in 1:num.testing.periods) {
        path.in <- PathShard(control, testing.period.index)
        names.loaded <- load(path.in)
        stopifnot(length(names.loaded) == 1)
        stopifnot(names.loaded[[1]] == 'data')
        all.rows <- IfThenElse(is.null(all.rows), data, rbind(all.rows, data))
    }

    cat('Combine about to write\n'); browser()
    path.out <- PathCombined(control)
    save(all.rows, file = path.out)
}
