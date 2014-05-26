# ReadAndTransformTransaction.R
ReadAndTransformTransactions <- function(path.in, nrows, verbose) {
  # read a transactions CSV file and transform its features
  # ARGS:
  # path.in : string, the path to the CSV file
  # nrows   : number of rows to read (-1 for all)
  # verbose : if TRUE, print analyses of the pre-transformed input
  #
  # RETURNS: data.frame with raw and transformed feature
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
    cat('reading all transactions\n')
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
        print(summary(raw))
    }
 
    splitDate <- SplitDate(raw$transaction.date)

    # recode POOL.FLAG: this fields is populated with a "Y" if a pool is present on the parcel
    # Because we converted strings to factors and how the input file is coded,
    #   2 ==> a pool
    #  NA ==> no pool
    has.pool = ifelse(is.na(raw$POOL.FLAG), FALSE, TRUE)

    # check of PRIOR SALE AMOUNT
    stopifnot(is.null(raw$PRIOR.SALE.AMOUNT))

    # RESALE NEW CONSTRUCTION CODE
    # N ==> New construction sale
    # M ==> resale

    # check for valid values
    stopifnot(all(raw$bedrooms > 0))
    stopifnot(all(raw$bathrooms > 0))

    # NOTE: Sumit used these fields which we do not have
    # PRIOR.SALE.AMOUNT : could be reconstructed for many deeds
    # rating for school district : we don't have school district in the taxroll file
    # LOCAL.INFLUENCE.CODE : I have missing values, I could recode the missing values to a new category


    fraction.improvement.value <- (raw$IMPROVEMENT.VALUE.CALCULATED / 
                                   (raw$IMPROVEMENT.VALUE.CALCULATED + raw$LAND.VALUE.CALCULATED))

    # return just the features needed, to reduce memory requirements
    data.frame(sale.day = splitDate$day,
               sale.month = splitDate$month,
               sale.year = splitDate$year,

               price = raw$SALE.AMOUNT,
               log.price = log(raw$SALE.AMOUNT),

               land.square.footage = raw$LAND.SQUARE.FOOTAGE,
               centered.log.land.square.footage = Center(log(raw$LAND.SQUARE.FOOTAGE)),
               centered.land.square.footage = Center(raw$LAND.SQUARE.FOOTAGE),

               living.area = raw$LIVING.SQUARE.FEET,
               centered.log.living.area = Center(log(raw$LIVING.SQUARE.FEET)),
               centered.living.area = Center(raw$LIVING.SQUARE.FEET),

               bedrooms = raw$BEDROOMS,
               centered.log1p.bedrooms = Center(log1p(raw$BEDROOMS)),
               centered.bedrooms = Center(raw$BEDROOMS),

               bathrooms = raw$TOTAL.BATHS.CALCULATED,
               centered.log1p.bathrooms = Center(log1p(raw$TOTAL.BATHS.CALCULATED)),
               centered.bathrooms = Center(raw$TOTAL.BATHS.CALCULATED),

               parking.spaces = raw$PARKING.SPACES,
               centered.log1p.parking.spaces = Center(log1p(raw$PARKING.SPACES)),
               centered.parking.spaces = Center(raw$PARKING.SPACES),

               land.value = raw$LAND.VALUE.CALCULATED,
               centered.log.land.value = Center(log(raw$LAND.VALUE.CALCULATED)),
               centered.land.value = Center(raw$LAND.VALUE.CALCULATED),

               improvement.value = raw$IMPROVEMENT.VALUE.CALCULATED,
               centered.log.improvement.value = Center(log(raw$IMPROVEMENT.VALUE.CALCULATED)),
               centered.improvement.value = Center(raw$IMPROVEMENT.VALUE.CALCULATED),

               factor.parking.type = raw$PARKING.TYPE.CODE,
               factor.has.pool = has.pool,
               factor.foundation.type = raw$FOUNDATION.CODE,
               factor.roof.type = raw$ROOF.TYPE.CODE,
               factor.heating.code = raw$HEATING.CODE,
               factor.is.new.construction = factor(raw$RESALE.NEW.CONSTRUCTION.CODE == 'N'),

               avg.commute.time = raw$avg.commute,
               centered.avg.commute.time = Center(raw$avg.commute),

               median.household.income = raw$median.household.income,
               centered.log.median.household.income = Center(log(raw$median.household.income)),
               centered.median.household.income = Center(raw$median.household.income),

               year.built = raw$YEAR.BUILT,
               centered.year.built = Center(raw$YEAR.BUILT),

               latitude = raw$G.LATITUDE,
               centered.latitude = Center(raw$G.LATITUDE),

               longitude = raw$G.LONGITUDE,
               centered.longitude = Center(raw$G.LONGITUDE),

               fraction.owner.occupied = raw$fraction.owner.occupied,
               centered.fraction.owner.occupied = Center(raw$fraction.owner.occupied),

               fraction.improvement.value = fraction.improvement.value,
               centered.fraction.improvement.value = Center(fraction.improvement.value)
               )
}
