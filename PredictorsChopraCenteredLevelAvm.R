PredictorsChopraLevelAvm <- function() {
    # return chr vector of predictors used by Chopra that we have access to
    # NOTE: Chopra had school district quality, which we don't have
    c(PredictorsChopraLevelAssessor(),
      'land.value',
      'improvement.value')
}
