PredictorsChopraCenteredLog <- function() {
    # return chr vector of predictors used by Chopra that we have access to
    # NOTE: Chopra had school district quality, which we don't have
    c('centered.log.land.square.footage',
      'centered.log.living.area',
      'centered.log.land.value',
      'centered.log.improvement.value',
      'centered.year.built',
      'centered.log1p.bedrooms',
      'centered.log1p.bathrooms',
      'centered.log1p.parking.spaces',
      'centered.log.median.household.income',
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
