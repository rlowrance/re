source('IfThenElse.R')
Predictors <- function(set, form, center) {
    # return set of predictors
    # ARGS
    # set : always 'Chopra' for now
    # form : 'log' or 'level'
    # center : TRUE or FALSE

    Prefix <- function(chr, a.list) {
        PrefixChr <- function(x) {
            sprintf('%s.%s', chr, x)
        }
        result <- sapply(a.list, PrefixChr)
        result
    }

    MaybeCenter <- function(vars) {
        IfThenElse(center, Prefix('centered', vars), vars)
    }

    MaybeLog <- function(vars) {
        switch( form
               ,log = Prefix('log', vars)
               ,level = vars
               ,stop('bad form')
               )
    }
        

    MaybeCenterLog <- function(vars) {
        MaybeCenter(MaybeLog(vars))
    }

    #cat('starting Predictors\n', set, form, center, '\n'); browser()

    stopifnot(set == 'Chopra')

    continuous.size.vars <- c( 'land.square.footage'
                        ,'living.area'
                        ,'bedrooms'
                        ,'bathrooms'
                        ,'parking.spaces'
                        ,'median.household.income'
                        )

    continuous.non.size.vars <- c( 'year.built'
                            ,'fraction.owner.occupied'
                            ,'avg.commute.time'
                            ,'latitude'
                            ,'longitude'
                            )

    discrete.vars <- c('is.new.construction'
                       ,'has.pool'
                       )

    all.vars <- c( MaybeCenterLog(continuous.size.vars)
                  ,MaybeCenter(continuous.non.size.vars)
                  ,discrete.vars)
    all.vars
}

Predictors.test <- function() {
    verbose <- TRUE
    V <- function(chr) {
        if (verbose) {
            cat(chr, '\n')
        }
    }

    cat('starting Predictors.test\n'); browser()
    V(Predictors('Chopra', 'log', FALSE))
    V(Predictors('Chopra', 'log', TRUE))
    V(Predictors('Chopra', 'level', FALSE))
    V(Predictors('Chopra', 'level', TRUE))
}

Predictors.test()
