PredictorsChopraCenteredLevelAvm <- function() {
    # return chr vector of predictors used by Chopra that we have access to
    # NOTE: Chopra had school district quality, which we don't have
    c(PredictorsChopraCenteredLevelAssessor(),
      'centered.land.value',
      'centered.improvement.value')
}
