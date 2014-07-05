PredictorsChopraCenteredLevelAssessor <- function() {
    # return chr vector of predictors used by Chopra that we have access to
    # NOTE: Chopra had school district quality, which we don't have
    c('centered.land.square.footage',
      'centered.living.area',
      'centered.year.built',
      'centered.bedrooms',
      'centered.bathrooms',
      'centered.parking.spaces',
      'centered.median.household.income',
      'centered.fraction.owner.occupied',
      'centered.avg.commute.time',
      'centered.latitude',
      'centered.longitude',
      'factor.is.new.construction',
      #'factor.foundation.type',  # this is only sparcely present in our data set
      'factor.roof.type',
      #'factor.parking.type',     # this is only sparcely present in our data set
      'factor.has.pool')
}
