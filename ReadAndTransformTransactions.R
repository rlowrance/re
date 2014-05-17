# ReadAndTransformTransaction.R
ReadAndTransformTransactions <- function(path.in, nrows, verbose) {
  # read a transactions CSV file and transform its features
  # ARGS:
  # path.in : string, the path to the CSV file
  # nrows   : number of rows to read (-1 for all)
  # verbose : if TRUE, print analyses of the pre-transformed input
  #
  # RETURNS: data.frame with transformed features
  #
  # Chopra's description of his processing
  # Data was transactions and tax roll for 2004. Only transactions for single 
  # family was used. Processing steps:
  # • remove records with one or more missing values. The reduced data set had
  #   42,025 transactions.
  # • transform into log space all features corresponding to price, area, and
  #   income
  # • tranform to 1-of-K encoding all discrete features
  # • normalize all variables to have mean 0 and a standard deviation between
  #   -1 and 1
  #
  # Chopra's features before transformations [page 87 in his thesis]
  # PRICE
  # LIVING.AREA
  # YEAR.BUILT
  # BEDROOMS
  # BATHROOMS
  # HAS.POOL
  # PRIOR.PRICE  Not in the transaction file
  # PARKING.SPACES
  # PARKING.TYPE
  # LOT ACERAGE Not in the transaction file
  # LAND.VALUE
  # IMPROVEMENT.VALUE
  # PERCENT.IMPROVEMENT.VALUE
  # IS.NEW.CONSTUCTION  
  # FOUNDATION.TYPE
  # ROOF.TYPE
  # HEATING.TYPE
  # SITE.INFLUENCE  Used location influence code
  # LATITUDE
  # LONGITUDE
  # MEDIAN.HOUSEHOLD.INCOME
  # FRACTION.OWNER.OCCUPIED
  # AVG.COMMUTE.TIME
  # school district academic performance index (Not in our data)
  #
  # In addition to Chopra's features, also return these features
  # SALE.DAY, SALE.MONTH, SALE.YEAR
   raw <- read.table(path.in,
                     header=TRUE,
                     sep=",",
                     quote="",
                     comment="",
                     stringsAsFactors=TRUE,
                     na.strings="NA",
                     nrows=nrows)
   if (verbose) {
       cat('raw structure\n')
       str(raw)
   }
 
   splitDate <- SplitDate(raw$X.transaction.date)

  # replace NA with N
   pool.flag.recoded <- ifelse(is.na(raw$X.POOL.FLAG), 'N', raw$X.POOL.FLAG)

   # RESALE NEW CONSTRUCTION CODE
   # N ==> New construction sale
   # M ==> resale

   data.frame(sale.date = splitDate$day,
              sale.month = splitDate$month,
              sale.year = splitDate$year,
              log.price = log(raw$X.SALE.AMOUNT),
              centered.log1p.prior.price = Center(log1p(raw$X.PRIOR.SALE.AMOUNT)),
              centered.log.land.square.footage = Center(log(raw$X.LAND.SQUARE.FOOTAGE)),
              centered.log.living.area = Center(log(raw$X.LIVING.SQUARE.FEET)),
              centered.year.built = Center(raw$X.YEAR.BUILT),
              centered.log.bedrooms = Center(log(raw$X.BEDROOMS)),
              centered.log.bathrooms = Center(log(raw$X.TOTAL.BATHS.CALCULATED)),
              centered.log1p.parking.spaces = Center(log1p(raw$X.PARKING.SPACES)),
              centered.log.land.value = Center(log(raw$X.LAND.VALUE.CALCULATED)),
              centered.log.improvement.value = 
                Center(log(raw$X.IMPROVEMENT.VALUE.CALCULATED)),
              centered.fraction.improvement.value = 
                Center(raw$X.LAND.VALUE.CALCULATED / 
                  (raw$X.LAND.VALUE.CALCULATED + raw$X.IMPROVEMENT.VALUE.CALCULATED)),
              factor.parking.type = raw$X.PARKING.TYPE.CODE,
              factor.has.pool = (pool.flag.recoded == 2),
              factor.is.new.construction = 
                raw$X.RESALE.NEW.CONSTRUCTION.CODE == '"N"',
              factor.foundation.type = raw$X.FOUNDATION.CODE,
              factor.roof.type = raw$X.ROOF.TYPE.CODE,
              factor.heating.type = raw$X.HEATING.CODE,
              factor.site.influence = raw$X.LOCATION.INFLUENCE.CODE,
              centered.latitude = Center(raw$X.G.LATITUDE),
              centered.longitude = Center(raw$X.G.LONGITUDE),
              centered.log.median.household.income = 
                Center(log(raw$X.median.household.income)),
              centered.fraction.owner.occupied = 
                Center(raw$X.fraction.owner.occupied),
              centered.avg.commute.time = Center(raw$X.avg.commute))
}
