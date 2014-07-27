source('CompareModelsSfpLinearCombine.R')
source('CompareModelsSfpLinearShard.R')

CompareModelsSfpLinear <- function(control, transformed.data, TestingPeriods) {
    # execute the SfpLinear command as part of the compare-models main program


    PathCombined <- function(control) {
        # return path to the combined file (that holds all the shard)
        result <- paste0( control$dir.output
                         ,control$me
                         ,'-', 'sfplinear'
                         ,'-', 'combined'
                         ,'.rsave'
                         )
        result
    }

    PathShard <- function(control, index) {
        # return path to shard
        result <- paste0( control$dir.output
                         ,control$me
                         ,'-', 'sfplinear'
                         ,'-', 'shard'
                         ,sprintf('-%02d', index)
                         ,'.rsave'
                         )
        result
    }

    result <- 
        switch( control$choice
               ,combine = CompareModelsSfpLinearCombine( control = control
                                                        ,transformed.data = transformed.data
                                                        ,num.testing.periods = length(TestingPeriods())
                                                        ,PathShard = PathShard
                                                        ,PathCombined = PathCombined
                                                        )
               ,shard = CompareModelsSfpLinearShard( control = control
                                                    ,transformed.data = transformed.data
                                                    ,PathShard = PathShard
                                                    )
               ,stop(sprintf('bad choice: %s', control$choice))
               )
    result
}
