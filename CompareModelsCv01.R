CompareModelsCv01 <- function(testing.period, transformed.data) {
    # define models for experiment: assessor linear logprice chopra
    # ARGS
    # testing.period   : list($first.date,$last.date) list of Date 
    #                    first and last dates for the testing period
    # transformed.data : data.frame
    # RETURN list(Model=<list of functions>, description=<list of char vector>)
    #   2 parallel lists where
    #   Model[[i]]: is a function(data, training.indices, testing.indices)
    #               --> $actual = <vector of actual prices for the testing period>
    #                   $predicted <vector of predicted prices or NA values> for corresponding transactions
    #   description[[i]]: a vector of lists of chr, a description of the model
    #cat('starting CompareModelsCv01', testing.period$first.date, testing.period$last.date, nrow(transformed.data), '\n'); browser()
    
    Require('ModelLinear')
    Require('PredictorsChopraCenteredLog')

    base.description <- list(scenario = 'assessor',
                             testing.period = testing.period,
                             model = 'ModelLinear',
                             response = 'log.price',
                             predictors = 'Chopra centered log')
    features <- list(response = 'log.price',
                     predictors = PredictorsChopraCenteredLog())


    MakeModelDescription <- function(model.index) {
        # return list $Model $description
        #cat('starting MakeModelDescription', model.index, '\n'); browser()

        # determine training period
        assessor.mailing.date <- as.Date('2008-10-1')
        last.assessor.analysis.date <- assessor.mailing.date - 1
        days.before <- 30 * model.index
        training.period <- list(first.date = last.assessor.analysis.date - days.before,
                                last.date = last.assessor.analysis.date)

        Model <- function(data, training.indices, testing.indices) {
            # return $actual $prediction
            # use training.period set just above
            if (FALSE) {
                cat('starting Cv01::Model', 
                    nrow(data), sum(training.indices), sum(testing.indices),
                    training.period$first.date, training.period$last.date,
                    '\n')
                browser()
            }
            # training.period <- params (but I want to me explicit)
            verbose.model <- TRUE
            actual.prediction <- 
                ModelLinear(data = data,
                            training.indices = training.indices,
                            testing.indices = testing.indices,
                            scenario = 'assessor',
                            training.period = training.period,
                            testing.period = testing.period,
                            features = features,
                            verbose.model = verbose.model)
            stopifnot(length(actual.prediction) == 2)
            actual.prediction
        }

        description <- c(base.description,
                         training.period = sprintf('%d days before Oct 1', days.before))

        result <- list(Model = Model, description = description)
        result
    }

    result <- lapply(1:10, MakeModelDescription)
    result
}
