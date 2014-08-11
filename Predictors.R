source('IfThenElse.R')
Predictors <- function(set, form, center, useAssessment) {
    # return set of predictors
    # ARGS
    # set : always 'Chopra' for now
    # form : 'log' or 'level'
    # center : TRUE or FALSE
    # useAssessment: TRUE or FALSE

    # categorization of features
    # - continuous
    #   -- size: for size features, the caller may want to use the log of the feature
    #      --- positive (>0), so that taking log is possible
    #      --- nonnegative (>=0), so that taking log is not possible, but can take log(x+1)
    #   -- non-size
    # - discrete

    # These function all accept a feature name (as a string) and prepend centerd and log/log1p as appropriate

    ContinuousSizePositive <- function(chr) {
        v <- switch( form
                    ,log = sprintf('log.%s', chr)
                    ,level = chr
                    )
        IfThenElse(center, sprintf('centered.%s', v), v)
    }

    ContinuousSizeNonnegative <- function(chr) {
        v <- switch( form
                    ,log = sprintf('log1p.%s', chr)
                    ,level = chr
                    )
        IfThenElse(center, sprintf('centered.%s', v), v)
    }

    ContinuousNonsize <- function(chr) {
        IfThenElse(center, sprintf('centered.%s', chr), chr)
    }

    Discrete <- function(chr) {
        chr
    }

    #cat('starting Predictors\n', set, form, center, '\n'); browser()

    predictors <- 
        switch( set
               ,Chopra = 
                   c( ContinuousSizePositive('land.square.footage')
                     ,ContinuousSizePositive('living.area')
                     ,ContinuousSizeNonnegative('bedrooms')
                     ,ContinuousSizeNonnegative('bathrooms')
                     ,ContinuousSizeNonnegative('parking.spaces')
                     ,IfThenElse(useAssessment, ContinuousSizePositive('improvement.value'), NULL)
                     ,IfThenElse(useAssessment, ContinuousSizePositive('land.value'), NULL)
                     ,ContinuousNonsize('median.household.income')
                     ,ContinuousNonsize('year.built')
                     ,ContinuousNonsize('fraction.owner.occupied')
                     ,ContinuousNonsize('avg.commute.time')
                     ,ContinuousNonsize('latitude')
                     ,ContinuousNonsize('longitude')
                     ,IfThenElse(useAssessment, ContinuousNonsize('fraction.improvement.value'), NULL)
                     ,Discrete('factor.is.new.construction')
                     ,Discrete('factor.has.pool')
                     )
               ,ChopraNoGeocoding = 
                   c( ContinuousSizePositive('land.square.footage')
                     ,ContinuousSizePositive('living.area')
                     ,ContinuousSizeNonnegative('bedrooms')
                     ,ContinuousSizeNonnegative('bathrooms')
                     ,ContinuousSizeNonnegative('parking.spaces')
                     ,IfThenElse(useAssessment, ContinuousSizePositive('improvement.value'), NULL)
                     ,IfThenElse(useAssessment, ContinuousSizePositive('land.value'), NULL)
                     ,ContinuousNonsize('median.household.income')
                     ,ContinuousNonsize('year.built')
                     ,ContinuousNonsize('fraction.owner.occupied')
                     ,ContinuousNonsize('avg.commute.time')
                     ,IfThenElse(useAssessment, ContinuousNonsize('fraction.improvement.value'), NULL)
                     ,Discrete('factor.is.new.construction')
                     ,Discrete('factor.has.pool')
                     )
               ,stop('bad set')
               )
    predictors

}

Predictors.test <- function() {
    verbose <- FALSE
    V <- function(chr) {
        if (verbose) {
            cat(chr, '\n')
        }
    }

    #cat('starting Predictors.test\n'); browser()
    p <- Predictors(set = 'Chopra', form='log', center=TRUE, useAssessment=TRUE)
    if (verbose) print(p)
    stopifnot(length(p) == 16)

    p <- Predictors(set = 'Chopra', form='level', center=FALSE, useAssessment=FALSE)
    if (verbose) print(p)
    stopifnot(length(p) == 13)
}

Predictors.test()
