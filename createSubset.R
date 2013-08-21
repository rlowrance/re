# createSubset.R
# Create a subset from the transactions.
# - select rows considered to be valid transactions
# - add original transaction id before rows were deleted
# - add identification back to source files
# - add urand field (used later to separate testing/training)
# - select columns to be used for models
# - screen some of these columns against reasonable values

################################################################################
## SETTINGS
################################################################################

settings = list()
settings$testing <- FALSE

settings$JIT.level=3 # in {0, 1, 2, 3}
settings$script.name <- "createSubset.R"

# num transactions read if testing
settings$read.limit <- 100

# output paths
settings$dir.output <- "../data/v6/output/"
settings$path.subset <- paste(settings$dir.output,
                              "transactions-subset.csv",
                              sep="")

# input paths
settings$path.transactions <- paste(settings$dir.output,
                                    "transactions-al-sfr.csv",
                                    sep="")

# cache paths: 
settings$cache.subset <- "/tmp/createSubset-subset.csv"

# working directory (create in Finder if necessary)
settings$run.name <- paste(Sys.Date(), "/", settings$script.name, sep="")
settings$dir.working <- paste("../data/v6/working/",
                              settings$run.name,
                              ifelse(settings$testing, "-testing", "")
                              sep="")
settings$path.logfile <- paste(settings$dir.working, "/log.txt", sep="")

################################################################################
# INITIATIZE
################################################################################

# maybe turn on the JIT compiler
source("SetJITLevel.R")
SetJITLevel(settings$JIT.level)

# set R options
options(warn=2)  # turn warnings into errors

# set random number seed
settings$random.seed <- 1
set.seed(settings$random.seed)

# make sure working directory has been created
create.dir(settings$dir.working,
           showWarnings=FALSE,
           recursive=TRUE)
if (!file.exists(settings$dir.working)) {
  stop("should have created working directory")
  cat("create directory", settings$dir.working, "and restart\n")
  stop()
}

# copy this script file to working directory
file.copy(from=settings$script.name,
          to=paste(settings$dir.working, "/", settings$script.name,
                   sep=""),
          overwrite=TRUE)


# delete any existing log file
if (file.exists(settings$path.logfile))
    file.remove(settings$path.logfile)

# redefine cat() to write to both stdout and the log file
source("MakeCat.R")
cat <- MakeCat(settings$path.logfile)

# write the settings
source("TimeStamp.R")
cat("started at", TimeStamp(), "\n")
if (settings$testing)
  cat("WARNING: TESTING; DISCARD RESULTS\n")
for (name in names(settings)) {
  cat("settings", name, settings[[name]], "\n")
}

################################################################################
# REQUIRE/SOURCE
################################################################################

require(nnet)          # for multinom()

source("RemoveNonInformative.R")


################################################################################
## Subset and related functions
################################################################################

Std <- function(v) {
  # Standardize a vector by subtracting the mean and dividing by the std
  #
  # Args:
  # v: numeric vector
  #
  # Value:
  # vector of same length as (v)

  # make sure there are no NAs or NaNs
  if (any(is.na(v)))  # also checks for NaN
    stop("v contains at least one NA")
  r <- (v - mean(v)) / sd(v)
  r
}


SplitDate <- function(c) {}

DateOk <- function(c) {
  # Determine if an integer could represent a date in form YYYYDDMM
  #
  # Args:
  # c: vector of int
  #
  # Value:
  # vector of boolean

  d <- SplitDate(c)
  
}

ToDate <- function(v) {
  c <- as.character(v)
  dates <- as.Date(c, "%Y%m%d")
  dates
}

expect.all.ok <- TRUE
ExpectAll <- function(list, name, cat) {
  # Verify that there are no NO values
  #
  # Args
  # list: list
  # name: character
  # cat: function used for printing
  #
  # Value:
  # list[[name]]
  cat("Checking for no missing values", name, "\n")
  values <- list[[name]]
  if (sum(is.na(values) != 0)) {
    cat(" **ERROR**: found unexpected NA values\n")
    expect.all.ok <- FALSE
  }
  else {
    cat(" OK\n")
  }
  values
}

expect.some.ok <- TRUE
ExpectSome <- function(list, name, cat) {
  # Verify that there are some NA values, print table of values & occurrences
  #
  # Args
  # list: list
  # name: character
  # cat: function used for printing
  #
  # Value:
  # list[[name]]
  cat("Checking for some missing values", name, "\n")
  values <- list[[name]]
  if (sum(is.na(values)) == 0) {
    cat(" **ERROR**: found no NA values\n")
    expect.missing.ok <- FALSE
  }
  t <- table(values, useNA="ifany")
  if (length(t) > 100) {
    cat(sprintf("table not printed, since has %d entries\n",
                length(t)))
  }
  else {
    for (i in 1:length(t)) {
      content <- names(t[i])
      count <- t[i]
      cat(" ", content, "occurs", count, "\n")
    }
  }
  cat(" OK\n")
  values
}

expect.none.ok <- TRUE
ExpectNone <- function(list, name, cat) {
  cat("Checking for all missing values", name, "\n")
  values <- list[[name]]
  if (!all(is.na(values))) {
    cat(" **ERROR**: found some non-NA values\n")
    expect.none.ok <- FALSE
  }
  else {
    cat(" OK\n")
  }
  values
}

NeverSee <- function(list, name, value, cat) {
  cat(sprintf("Check that %s is never in %s\n",
              value, name))
  values <- list[[name]]
  has.some <- any(values == value, na.rm=TRUE)
  if (has.some) {
    stop("the value occurs")
  }
  else {
    cat(" OK")
  }
  values
}

SubsetCreate <- function(t) {
  # Retain a relevant subset of all arms-length single-family residential
  # transactions.
  #
  # Args:
  # t: data frame of transactions transformed
  #
  # Details:
  # This logic follow transactios-al-sfr-explore.html in the output folder.
  #
  # Value:
  # data frame with
  # - a subset of the observations
  # - a subset of the potentially transformed features.
  # - with duplicate elements removed

  # add unique identifier
  t$transaction.record.number <- 1:nrow(t)

  # constrain on availability of a transaction date
  # There are many missing SALE DATE values.
  # Substitute an adjusted RECORDING DATE when SALE DATE is missing.
  adjusted.sale.date <- ToDate(t$SALE.DATE)            # many are NA
  adjusted.recording.date <- ToDate(t$RECORDING.DATE)  # None of NA
  cat("number of missing SALE DATE values:",
      sum(is.na(adjusted.sale.date)),
      "\n")
  cat("number of missing RECORDING DATE values:",
      sum(is.na(adjusted.recording.date)),
      "\n")

  adjusted.sale.date.present <- !is.na(sale.date)
  diff <-
    adjusted.recording.date[adjusted.sale.date.present] -
      adjusted.sale.date[adjusted.sale.date.present]
  mean.diff <- mean(diff)
  cat(sprintf(paste(" mean difference when both SALE DATE and RECORDING DATE",
                    "are present = %f\n"),
              mean.diff))
  if (mean.diff <= 0)
    stop("mean.diff must be positive")
  t$transaction.date <- as.Date(ifelse(is.na(adjusted.sale.date),
                                       adjusted.recording.date - mean.diff,
                                       adjusted.sale.date),
                                origin="1970-01-01")
  transaction.date.present <- !is.na(t$transaction.date)
  cat(sprintf(" %d have missing Sale.DATE\n",
              sum(is.na(t$sale.date))))
  cat(sprintf(" %d have missing SALE.DATE and missing RECORDING.DATE\n",
              sum(!date.present)))
  

  # constrain on reasonable SALE.AMOUNT
  # at least 0
  # not more than $85,000,000 (the largest LA price up until Jan 2013)
  sale.amount.reasonable <- t$SALE.AMOUNT > 0 & t$SALE.AMOUNT < 85000000
  cat(sprintf("% d have an unreasonable sale amount",
              sum(!sale.amount.reasonable)))


  # SALE.DATE or RECORDING.DATE present
  # NOTE; keep all dates for training purposes
  # NOTE: Dates are stored as number of days past 1970-01-01 but print
  # as YYYY-MM-DD

  # DOCUMENT.TYPE.CODE: Grant or Trust deed
  grant.or.trust <- t$DOCUMENT.TYPE.CODE == "G" | t$DOCUMENT.TYPE.CODE == "T"
  cat(sprintf("% d are not grant or trust deeds via DOCUMENT.TYPE.CODE\n",
              sum(!grant.or.trust)))

  # TRANSACTION.TYPE.CODE: Resale or New Construction
  resale <- ifelse(is.na(t$TRANSACTION.TYPE.CODE),
                   FALSE,
                   t$TRANSACTION.TYPE.CODE == 1)
  new <-    ifelse(is.na(t$TRANSACTION.TYPE.CODE),
                   FALSE,
                   t$TRANSACTION.TYPE.CODE == 3)
  resale.or.new <- resale | new
  cat(sprintf(paste(" %d are not resale or new construction",
                    "via TRANSACTION.TYPE.CODE\n"),
              sum(!resale.or.new)))
      
  # SALE.CODE: Full sale (instead of partial)
  full.sale <- !is.na(t$SALE.CODE) & t$SALE.CODE == "F"
  cat(sprintf(" %d are not full sales via SALE.CODE\n",
              sum(!full.sale)))

  # MULTI.APN.FLAG.CODE and MULT.APN.COUNT
  one.parcel <- is.na(t$MULTI.APN.FLAG.CODE) & t$MULTI.APN.COUNT <= 1
  cat(sprintf(paste(" %d are not for one APN",
                    "via MULTI.APN.FLAG.CODE and MULT.APN.COUNT\n"),
              sum(!one.parcel)))

  # NUMBER.OF.BUILDINGS
  at.least.one.building <- t$NUMBER.OF.BUILDINGS >= 1
  cat(sprintf(" %d do not have at least one building\n",
              sum(!at.least.one.building)))

  # positive value
  positive.value <-
    t$TOTAL.VALUE.CALCULATED > 0 &
    t$LAND.VALUE.CALCULATED > 0 &
    t$IMPROVEMENT.VALUE.CALCULATED
  cat(sprintf(" %d do not have a positive total, land, or improvement value\n",
              sum(!positive.value)))

  # not too high value
  max.value <- 85000000
  reasonable.value <-
    t$TOTAL.VALUE.CALCULATED <= max.value &
    t$LAND.VALUE.CALCULATED <= max.value &
    t$IMPROVEMENT.VALUE.CALCULATED <= max.value
  cat(sprintf(" %d have too high a total, land, or improvement value\n",
              sum(!reasonable.value)))
   
   

  # UNIVERSAL.BUILDING.SQUARE.FEET
  some.building.square.feet <- t$UNIVERSAL.BUILDING.SQUARE.FEET
  cat(sprintf(" %d do not have at least some building square feet\n",
              sum(!some.building.square.feet)))

  # LIVING.SQUARE.FEET
  some.living.square.feet <- t$LIVING.SQUARE.FEET
  cat(sprintf(" %d do not have at least some living square feet\n",
              sum(!some.living.square.feet)))

  # TOTAL.ROOMS
  some.rooms <- t$TOTAL.ROOMS > 0
  cat(sprintf(" %d do not have at least 1 room\n",
              sum(!some.rooms)))

  # BEDROOMS : allow zero bedrooms
  some.bedrooms <- t$BEDROOM > 0
  cat(sprintf(" %d not have have at least 1 bedroom\n",
              sum(!some.bedrooms)))

  # TOTAL.BATHS.CALCULATED: allow zero bathrooms
  some.bathrooms <- t$TOTAL.BATHS.CALCULATED > 0
  cat(sprintf(" %d did not have at least 1 bathroom\n",
              sum(!some.bathrooms)))

  # EFFECTIVE.YEAR.BUILT
  known.effective.year.built <- t$EFFECTIVE.YEAR.BUILT != 0
  cat(sprintf(" %d did not have a know effective year built\n",
              sum(!known.effective.year.built)))
      
  # drop rows we don't want
  t <- t[transaction.date.present
         & sale.amount.reasonable
         & grant.or.trust 
         & resale.or.new 
         & full.sale
         & one.parcel
         & at.least.one.building
         & positive.value
         & reasonable.value
         & some.building.square.feet
         & some.living.square.feet
         & some.rooms
         & known.effective.year.built
         , ]

  
  cat(sprintf("%d rows remain after eliminating unreasonable values and NAs\n",
              nrow(t)))

  
  # identification of transaction
  
  r <- data.frame(deed.file.number=t$deed.file.number
                  ,deed.record.number=t$deed.record.number
                  ,parcel.file.number=t$parcel.file.number
                  ,parcel.record.number=t$parcel.record.number
                  ,CENSUS.TRACT=t$CENSUS.TRACT
                  ,transaction.record.number=t$transaction.record.number
                  ,APN.UNFORMATTED=t$APN.UNFORMATTED
                  )

  # basic information on transaction
  
  r$date <- t$date  # number of days since 1970-01-01, can be < 0
  cat("mean date", format(mean(r$date)), "\n")
  cat("min date", format(min(r$date)), "\n")
  cat("max date", format(max(r$date)), "\n")
  r$day.std <- Std(r$date)
  
  r$SALE.AMOUNT <- t$SALE.AMOUNT
  cat("mean SALE AMOUNT in subset", mean(r$SALE.AMOUNT), "\n")
  cat("min SALE AMOUNT in subset", min(r$SALE.AMOUNT), "\n")
  cat("max SALE AMOUNT in subset", max(r$SALE.AMOUNT), "\n")
  for (amount in c(1000000, 10000000, 100000000)) {
    cat(sprintf("number of transactions with SALE.AMOUNT >= %f = %d\n",
                amount, sum(t$SALE.AMOUNT > amount)))
  }


  
  r$SALE.AMOUNT.log <- log(t$SALE.AMOUNT)
  
  # support functions
  All <- function(name) {
    r[name] <<- ExpectAll(t, name, cat)
  }
  Code <- function(name) {
   r[name] <<- ExpectSome(t, name, cat)
   cat(sprintf(" fraction with missing values = %f\n",
               sum(is.na(t[[name]]))/ nrow(r)))
  }
  Continuous <- function(name) {
    r[[name]] <<- t[[name]]
    r[paste(name, ".std", sep="")] <<- Std(ExpectAll(t, name, cat))
    cat(sprintf(" %d observations have %s == 0\n",
                 sum(t[[name]] == 0), name))
  }
  Size <- function(name) {
    r[name] <<- t[[name]]
    r[paste(name, ".log1p.std", sep="")] <<- Std(log1p(ExpectAll(t, name, cat)))
    cat(sprintf(" %d observations have %s == 0\n",
                sum(t[[name]] == 0), name))
  }
  Some <- function(name) {
    r[name] <<- ExpectSome(t, name, cat)
  }
  None <- function(name) {
    ExpectNone(t, name, cat)
  }

  # size features (always continuous)
  
  Size("NUMBER.OF.BUILDINGS")
  cat("number of obs with more than one building",
      sum(t$NUMBER.OF.BUILDINGS > 1),
      "\n")

  # Don't use total value since redundant with land and improvement value
  #Size("TOTAL.VALUE.CALCULATED")
  Size("LAND.VALUE.CALCULATED")
  cat("mean SALE AMOUNT", mean(r$SALE.AMOUNT), "\n")
  Size("IMPROVEMENT.VALUE.CALCULATED")

  Size("LAND.SQUARE.FOOTAGE")
  Size("UNIVERSAL.BUILDING.SQUARE.FEET")
  #Size("BUILDING.SQUARE.FEET")  use UNIVERSAL instead, it's present more often
  Size("LIVING.SQUARE.FEET")

  Size("TOTAL.ROOMS")
  Size("BEDROOMS")
  Size("TOTAL.BATHS.CALCULATED")
  Size("FIREPLACE.NUMBER")
  Size("PARKING.SPACES")

  Size("median.household.income")

  # Non-size continuous featurs

  Continuous("EFFECTIVE.YEAR.BUILT")
  Continuous("avg.commute")
  Continuous("fraction.owner.occupied")
  Continuous("G.LATITUDE")
  Continuous("G.LONGITUDE")
  r$fraction.improvement.value.std <-
    Std(t$IMPROVEMENT.VALUE.CALCULATED /
        (t$IMPROVEMENT.VALUE.CALCULATED + t$LAND.VALUE.CALCULATED))
  
  # qualtiative variables (CODES)

  potential.codes <- 
    c("RESALE.NEW.CONSTRUCTION.CODE"
      ,"ZONING"
      ,"VIEW"
      ,"LOCATION.INFLUENCE.CODE"
      ,"AIR.CONDITIONING.CODE"
      ,"CONDITION.CODE"
      ,"CONSTRUCTION.TYPE.CODE"
      ,"EXTERIOR.WALLS.CODE"
      ,"FIREPLACE.TYPE.CODE"
      ,"FOUNDATION.CODE"
      ,"FLOOR.CODE"
      ,"FRAME.CODE"
      # Drop GARAGE.CODE because
      # - its redundant with PARKING.TYPE.CODE
      # - PARKING.TYPE.CODE has fewer NAs
      ,"HEATING.CODE"
      # PARKING.TYPE.CODE is usually NA when # of PARKING SPACES is 0
      # So recode the NA's to NONE
      ,"PARKING.TYPE.CODE"
      #r$PARKING.TYPE.CODE <- ifelse(is.NA(r$PARKING.TYPE.CODE,
      ,"POOL.FLAG"  # TODO: recode to has.pool
      ,"POOL.CODE"
      ,"QUALITY.CODE"
      ,"ROOF.COVER.CODE"
      ,"ROOF.TYPE.CODE"
      ,"STYLE.CODE"
      ,"SEWER.CODE"
      ,"WATER.CODE"
      )

  
  cat("\nANALYSIS OF POTENTIAL CODES\n")
  cat(sprintf("%30s  %11s  %11s  %11s\n",
              "Code", "Num Uniques", "Num NA", "Fraction NA"))
  for (code in potential.codes) {
    values <- t[[code]]
    num.uniques <- length(unique(values))
    num.na = sum(is.na(values))
    fraction.na <- num.na / length(values)
    cat(sprintf("%30s  %11d  %11d  %11.2f\n",
                code, num.uniques, num.na, fraction.na))
  }
  cat("\n")

  r$RESALE.NEW.CONSTRUCTION.CODE <- ExpectAll(t,
                                              "RESALE.NEW.CONSTRUCTION.CODE",
                                              cat)
  r$ZONING.imputed <- ExpectSome(t, "ZONING", cat)
  ExpectSome(t, "VIEW", cat)
  #r$VIEW.recoded <- ifelse(is.NA(t$VIEW,
  #                               "000",  # None
  #
  ExpectSome(t, "LOCATION.INFLUENCE.CODE", cat)
  t$LOCATION.INFLUENCE.CODE.recoded <- ifelse(is.na(t$LOCATION.INFLUENCE.CODE),
                                              "I01",
                                              t$LOCATION.INFLUENCE.CODE)
  
  ExpectSome(t, "AIR.CONDITIONING.CODE", cat)
  NeverSee(t, "AIR.CONDITIONING.CODE", "000", cat)
  t$AIR.CONDITIONING.CODE.recoded <- ifelse(is.na(t$AIR.CONDITIONING.CODE),
                                            "000",
                                            t$AIR.CONDITIONING.CODE)
  
  r$CONDITION.CODE.imputed <- ExpectSome(t, "CONDITION.CODE", cat)
  r$CONSTRUCTION.TYPE.CODE.imputed <-
    ExpectSome(t, "CONSTRUCTION.TYPE.CODE", cat)
  r$EXTERIOR.WALLS.CODE.imputed <- ExpectSome(t, "EXTERIOR.WALLS.CODE", cat)
  ExpectSome(t, "FIREPLACE.TYPE.CODE", cat)
  ExpectSome(t, "FOUNDATION.CODE", cat)
  r$FOUNDATION.CODE.recoded.imputed <- ifelse(t$FOUNDATION.CODE == "001",
                                              NA,
                                              t$FOUNDATION.CODE)
  ExpectSome(t, "FLOOR.CODE", cat)
  ExpectSome(t, "FRAME.CODE", cat)
  # Drop GARAGE.CODE because
  # - its redundant with PARKING.TYPE.CODE
  # - PARKING.TYPE.CODE has fewer NAs
  r$HEATING.CODE.imputed <- ExpectSome(t, "HEATING.CODE", cat)
  # PARKING.TYPE.CODE is usually NA when # of PARKING SPACES is 0
  # So recode the NA's to NONE
  ExpectSome(t, "PARKING.TYPE.CODE", cat)
  r$PARKING.TYPE.CODE.recoded.imputed <-
    ifelse(is.na(t$PARKING.TYPE.CODE) && (t$PARKING.SPACES == 0),
           "000",  # None
           t$PARKING.TYPE.CODE)
  
                                      
                                            
  #r$PARKING.TYPE.CODE <- ifelse(is.NA(r$PARKING.TYPE.CODE,
                                      
  ExpectSome(t, "POOL.FLAG", cat) 
  r$has.pool <- ifelse(is.na(t$POOL.FLAG),
                       "N",
                       t$POOL.FLAG)
  # pool code is present whenever pool flag is present
  has.pool.flag <- !is.na(t$POOL.FLAG)
  has.pool.code <- !is.na(t$POOL.CODE)
  if (!all(has.pool.flag == has.pool.code))
    stop("not true that pool code is present whenever pool flag is present")
  # recode NA to 000 (no pool)
  ExpectSome(t, "POOL.CODE", cat)
  r$POOL.CODE.recoded <- ifelse(is.na(t$POOL.CODE),
                                "000",
                                t$POOL.FLAG)

  ExpectSome(t, "QUALITY.CODE", cat)
  r$QUALITY.CODE.imputed <- t$QUALITY.CODE
  
  ExpectSome(t, "ROOF.COVER.CODE", cat)
  r$ROOF.COVER.CODE.imputed <- t$ROOF.COVER.CODE

  ExpectSome(t, "ROOF.TYPE.CODE", cat)
  r$ROOF.TYPE.CODE.imputed <- t$ROOF.TYPE.CODE
  
  ExpectSome(t, "STYLE.CODE", cat)
  r$STYLE.CODE.imputed <- t$STYLE.CODE
  
  ExpectSome(t, "SEWER.CODE", cat)
  
  ExpectSome(t, "WATER.CODE", cat)

  if (!expect.all.ok)
    stop("One more more ExpectAll assertions failed")
  if (!expect.some.ok)
    stop("One or more ExpectSome assertions failed")
  if (!expect.none.ok)
    stop("One or more ExpectNone assertions failed")
  cat("all tests for code variables were passed\n")

  cat("dropping non-informative columns")
  r <- RemoveNonInformative(r, cat)

  cat("dropping duplicate observations in the subset\n")
  nondups <- unique(r)
  cat(sprintf("dropped %d duplicate observations\n",
              nrow(r) - nrow(nondups)))

  nondups$runif <- runif(nrow(nondups), min=0, max=1)

  nondups
}

################################################################################
## TRANSACTIONS.READ
################################################################################

TransactionsRead <- function() {
  # Read some or all of the transactions file.
  #
  # Returns:
  #   data.frame with transactions and these additional columns
  #   - transactionId: integer vector, unique IDs, 1:nrows
  #   - runif: numeric vector, drawns from random uniform distribution over
  #     [0,1]
  path <- settings$path.transactions
  nrows <- ifelse(settings$testing, settings$read.limit, -1)
  cat("reading transactions from", path, "\n")
  t <- read.csv(path
                ,fill=FALSE
                ,row.names=NULL
                ,stringsAsFactors=TRUE
                ,nrows=nrows
                )
  n = nrow(t)
  cat(sprintf("read %d transactions from %s\n",
              n, settings$path.transactions))
  
  t
}

################################################################################
## UTILITY
################################################################################

################################################################################
## MAIN
################################################################################

Load <- function() {
  source(settings$script.name)
}

Go <- function() {
  Load()
  Run()
}

go <- Go  # short cut for using from commannd line

Run <- function() {
  # Do the work.
  
  # Value: NULL
  t <-  TransactionsRead()
  s <- SubsetCreate(t)

  cat("writing subset file", settings$path.subset, "\n")
  write.csv(s,
            file=settings$path.subset,
            quote=FALSE)
  cat("number of records written:", nrow(s), "\n")
  cat("number of features written:", ncol(s), "\n")

  
  cat("\nending at", TimeStamp(), "\n")
  if (settings$testing)
    cat("TESTING: DISCARD OUTPUT\n")
}

Go()


