Require('ModelLinear')
MakeModelLinear <- function(scenario, testing.period, data, num.training.days,
                            response, predictors, verbose.model = TRUE) {
    # return Model(data, training.indices, testing.indices)
    #cat('starting MakeModelLinear', scenario, response, '\n'); browser()

    # force all args
    scenario
    testing.period
    num.training.days
    response
    predictors

    stopifnot(!is.null(num.training.days))  # this failed during testing


    features <- list(response = response,
                     predictors = predictors)

    DetermineTrainingPeriod <- function(scenario, test.period.first.date) {
        # return start and stop dates for the training period


        my.training.period <-
            switch(scenario,
                   assessor = MyTrainingPeriodAssessor(),
                   avm      = MyTrainingPeriodAvm(),
                   mortgage = MyTrainingPeriodMortgage())
        my.training.period
    }

    MyTrainingPeriodAssessor <- function(testing.period.first.date) {
        #cat('starting MyTrainingPeriodAssessor\n'); browser()
        # allow 91 days from mailing date to assessment date
        first.assessor.mailing.date <- testing.period.first.date - 91
        last.training.date = first.assessor.mailing.date - 1
        my.training.period <- list(first.date = last.training.date - num.training.days,
                                   last.date  = last.training.date)
        my.training.period
    }

    MyTrainingPeriodAvm <- function(testing.period.first.date) {
        #cat('starting MyTrainingPeriodAvm\n'); browser()
        last.training.date = testing.period$first.date - 1
        my.training.period <- list(first.date = last.training.date - num.training.days,
                                   last.date  = last.training.date)
        my.training.period
    }

    MyTrainingPeriodMortgage <- function() {
        #cat('starting MyTrainingPeriodMortgage\n'); browser()
        TrainingPeriodMortgage <- function(testing.date) {
            #cat('starting TrainingPeriodMortgage', testing.date, '\n'); browser()
            # TODO: find a way to make sure that testing.date is a Date
            # code below doesn't work because there is no function is.Date or isDate
            #stopifnot(isDate(testing.date))

            span <- num.training.days / 2
            training.period <- list(first.date = testing.date - span,
                                    last.date  = testing.date + span)
            training.period
        }
        TrainingPeriodMortgage
    }

    my.training.period <- 
        switch( scenario
               ,assessor = MyTrainingPeriodAssessor(testing.period$first.date)
               ,avm      = MyTrainingPeriodAvm(testing.period$first.date)
               ,mortgage = MyTrainingPeriodMortgage()  # return a function(testing.date) --> training.period
               )
    stopifnot(!is.null(my.training.period))

    Model <- function(data, training.indices, testing.indices) {
        #cat('starting MakeModelLinear::Model\n'); browser()
                
        result <- ModelLinear(data = data,
                              training.indices = training.indices,
                              testing.indices = testing.indices,
                              scenario = scenario,
                              training.period = my.training.period,  # sometimes a function
                              testing.period = testing.period,
                              features = features,
                              verbose.model = verbose.model)
        result
    }

    Model
}
