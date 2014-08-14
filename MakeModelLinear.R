source('ModelLinear.R')
MakeModelLinear <- function(scenario, testing.period, data, num.training.days,
                            response, predictors, verbose.model = TRUE) {
    # return Model(data, training.indices, testing.indices)
    # NOTE: The returned Model() has an API appropriate for CrossValidate()

    #cat('starting MakeModelLinear', scenario, response, '\n'); browser()

    # force all args
    force(scenario)
    force(testing.period)
    force(num.training.days)
    force(response)
    force(predictors)

    stopifnot(!is.null(num.training.days))  # this failed during testing

    features <- list(response = response,
                     predictors = predictors)


    MyTrainingPeriodAssessor <- function(testing.period.first.date) {
        # training period is n days ending 92 days before the testing period starts
        #cat('starting MyTrainingPeriodAssessor\n'); browser()
        # allow 91 days from mailing date to assessment date
        first.assessor.mailing.date <- testing.period.first.date - 91
        last.training.date = first.assessor.mailing.date - 1
        my.training.period <- list(first.date = last.training.date - num.training.days,
                                   last.date  = last.training.date)
        my.training.period
    }

    MyTrainingPeriodAvm <- function() {
        # training period is n days just before the transaction
        TrainingPeriodAvm <- function(testing.date) {
            #cat('starting TrainingPeriodAvm\n'); browser()
            training.period <- list(first.date = testing.date - num.training.days - 1,
                                    last.date = testing.date - 1)
            training.period
        }

        TrainingPeriodAvm
    }

    MyTrainingPeriodMortgage <- function() {
        # training period is n days around the date of the sale transaction
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
               ,avm      = MyTrainingPeriodAvm()  # return a function(testing.date) --> training.period
               ,avmnoa   = MyTrainingPeriodAvm()  # return a function(testing.date) --> training.period
               ,mortgage = MyTrainingPeriodMortgage()  # return a function(testing.date) --> training.period
               ,stop('bad scenario value')
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

MakeModelLinear.test <- function() {
    # unit test
    # just test if runs to completion
    for (scenario in c('assessor', 'avm', 'amvnoa', 'mortgage')) {
        Model <- MakeModelLinear( scenario = scenario
                                 ,testing.period = list( first.date = as.Date('2008-01-01')
                                                        ,last.date = as.Date('2008-01-31'))
                                 ,data = DataRandom(nrow = 100)
                                 )
        model.result <- Model()
    }
}

#MakeModelLinear.test()
