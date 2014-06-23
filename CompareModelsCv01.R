CompareModelsCv01 <- function(control, transformed.data) {
    # implement cross validation for assessor linear model for log.price using chopra's predictors
    # ARGS
    # control          : list of control variables
    # transformed.data : data.frame
    # RETURN list($result = <result from CrossValidate3>, description = chr scalar)
    cat('starting CompareModelsCv01', control$nfolds, nrow(transformed.data), '\n'); browser()
    
    Require('Assess')
    Require('CrossValidate3')
    Require('ModelLinear')
    Require('PredictorsChopraCenteredLog')

    base.description <- list(scenario = 'assessor',
                             testing.period = control$testing.period,
                             model = 'ModelLinear',
                             response = 'log.price',
                             predictors = 'Chopra centered log')

    Model.param.description <- function(model.index) {
        # return list $Model $param which will be called by 
        # CV3 via $Model(data, training.indices, testing.indices, param)
        #cat('starting CvAssessorLinearLogPriceChopra::Model.param.description', model.index, '\n'); browser()
        testing.period <- control$testing.period
        features <- list(response = 'log.price',
                         predictors = PredictorsChopraCenteredLog())
        verbose.model <- TRUE
        Model <- function(data, training.indices, testing.indices, param) {
            # return evaluations (which is a list of scalars)
            if (FALSE) {
                cat('starting Cv01::Model', 
                    nrow(data), sum(training.indices), sum(testing.indices),
                    param$training.period$first.date, param$training.period$last.date,
                    '\n')
                browser()
            }
            actuals.predictions <- 
                ModelLinear(data = data,
                            training.indices = training.indices,
                            testing.indices = testing.indices,
                            scenario = 'assessor',
                            training.period = param$training.period,
                            testing.period = testing.period,
                            features = features,
                            verbose.model = TRUE)
            result <- Assess(actuals = actuals.predictions$actuals,
                             predictions = actuals.predictions$predictions)
            result
        }

        assessor.mailing.date <- as.Date('2008-10-1')
        last.assessor.analysis.date <- assessor.mailing.date - 1
        days.before <- 30 * model.index
        training.period <- list(first.date = last.assessor.analysis.date - days.before,
                                last.date = last.assessor.analysis.date)
        param <- list(training.period = training.period)
        model.description <- c(base.description,
                               training.period = sprintf('%d days before Oct 1', days.before))

        result <- list(Model = Model,
                       param = param,
                       description = model.description)
        result
    }

    mpd <- lapply(1:10, Model.param.description)

    models.params <- lapply(mpd,
                            function(x) list(Model = x$Model, param = x$param))
    descriptions <- lapply(mpd,
                           function(x) x$description)

    cv.result <- CrossValidate3(data = transformed.data,
                                nfolds = control$nfolds,
                                models.params = models.params,
                                verbose = TRUE)
    result <- list(cv.result = cv.result,
                   descriptions = descriptions)
    result
}
