Assess <- function(actuals, predictions) {
    # return RMSE and fraction within 10 percent for available values
    rmse <- Rmse(actual = actuals, 
                 estimated = predictions)
    within.10.percent <- WithinXPercent(actual = actuals, 
                                        estimated = predictions, 
                                        precision = .10)
    result <- list(rmse = rmse,
                   within.10.percent = within.10.percent)
    result
}
