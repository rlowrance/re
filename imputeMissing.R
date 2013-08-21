# createObservations.R
# Create output/observations.csv from transactions.csv
# - impute missing certain variables
# - add obsId
# - add urand field (used later to separate testing/training)
# - drop columns that are all the same
# - drop factor columns that are incomplete and not imputed
#   These have two few known values

require(nnet)          # for multinom()

source("MakeCat.R")
source("SetJITLevel.R")
source("TimeStamp.R")

################################################################################
## SETTINGS
################################################################################

settings = list()
settings$testing=TRUE
settings$JIT.level=3 # in {0, 1, 2, 3}

settings$script.name="createObservations.R"

# output paths
settings$dir.output="../data/v6/output/"
settings$path.observations <- paste(settings$dir.output,
                                    "observations.csv",
                                    sep="")

# input paths
settings$path.transactions <- paste(settings$dir.output,
                                    "transactions.csv",
                                    sep="")

# working directory (create in Finder if necessary)
settings$run.name <- paste(Sys.Date(), "/", settings$script.name, sep="")
settings$dir.working <- paste("../data/v6/working/", settings$run.name,
                              sep="")
settings$path.logfile <- paste(settings$dir.working, "/log.txt", sep="")

# max iterations for multinom solver
settings$maxit <- 1000

# set R options
options(warn=2)  # turn warnings into errors

# set random number seed
set.seed(1)

# make sure working directory has been created
if (!file.exists(settings$dir.working)) {
  cat("create directory", settings$dir.working, "and restart\n")
  stop()
}

# copy this script file to working directory
file.copy(from=settings$script.name,
          to=paste(settings$dir.working, "/", settings$script.name,
                   sep=""),
          overwrite=TRUE)

# maybe turn on the JIT compiler
SetJITLevel(settings$JIT.level)

# delete any existing log file
if (file.exists(settings$path.logfile))
    file.remove(settings$path.logfile)

# redefine cat() to write to both stdout and the log file
cat <- MakeCat(settings$path.logfile)

# write the settings
cat("started at", TimeStamp(), "\n")
if (settings$testing)
  cat("WARNING: TESTING; DISCARD RESULTS\n")
for (name in names(settings)) {
  cat("settings", name, settings[[name]], "\n")
}

################################################################################
## IMPUTATION OF MISSING VALUES
################################################################################

StandardizeVector <- function(v) {
  # standardize vector by substracting mean and dividing by standard deviation
  #
  # Args:
  #   v: numeric vector without any NA values
  #
  # Returns:
  #   vector that is standardized
  num.nas <- sum(is.na(v))
  if (num.nas > 0)
    stop("v has an NA value")
  
  num.nans <- sum(is.nan(v))
  if (num.nans > 0)
    stop("v has a NaN value")

  mean <- mean(v, na.rm=FALSE)
  sd <- sd(v, na.rm=FALSE)
  result <- (v - mean) / sd

  if (sum(is.nan(result)) > 0)
    stop("result has a NaN value")
  result
}

StandardizeDf <- function(t) {
  # standardize the relevant columns in a transactions data frame
  #
  # Args:
  #   t: data frame of transactions with known column names
  #
  # Returns:
  #   new data frame with all values of roughly similar magnitues
  #   - For columns containing sizes, take log then standardize
  #   - For columns containing sizes where value could be zero,
  #     take log of value + 1 then standardize
  #   - For other numeric columns, just standardize
  #   - For factor columns, don't do anything (distance function must knows how
  #     to compute these distances)
  sv <- StandardizeVector  # short name to make code more compact
  df <- data.frame(land.square.footage.log.std=sv(log(t$LAND.SQUARE.FOOTAGE))
                   ,living.square.feet.log.std=sv(log(t$LIVING.SQUARE.FEET))
                   ,effective.year.built.std=sv(t$EFFECTIVE.YEAR.BUILT)
                   ,bedrooms.log.std=sv(log(t$BEDROOMS))
                   ,total.rooms.log.std=sv(log(t$TOTAL.ROOMS))
                   ,total.baths.log.std=sv(log(t$TOTAL.BATHS))
                   ,fireplace.number.log.std=sv(log(1 + t$FIREPLACE.NUMBER))
                   ,stories.number.log.std=sv(log(t$STORIES.NUMBER))
                   ,latitude.std=sv(t$G.LATITUDE)
                   ,longitude.std=sv(t$G.LONGITUDE)
                   ,pool.flag.is.Y=
                      ifelse(is.na(t$POOL.FLAG), 0, t$POOL.FLAG == "Y")
                   )
  df
}

ImputeOne <- function(t, column.name) {
  # return new column containing known values or imputed values
  #
  # Args:
  #   t : date frame
  #   column.name : chr. Name of column in t
  #
  # Returns:
  #   numeric vector v
  #   v[i] == t[column.name, i] if that value is not NA
  #   v[i] == imputed value if t[column.name, i] is NA
  
  # standardize columns that we use to model the missing values
  all.data <- StandardizeDf(t)
  
  # create training subset containing just the training data
  column <- t[[column.name]]
  known.row.indices <- !is.na(column)
  training.data <- all.data[known.row.indices, ]    
  training.data$known.values <- column[known.row.indices]
  
  # fit with logistic regression
  # covariates are features of the house
  model <- multinom(formula=known.values ~
                    land.square.footage.log.std + living.square.feet.log.std +
                    effective.year.built.std + bedrooms.log.std +
                    total.rooms.log.std + total.baths.log.std +
                    fireplace.number.log.std + stories.number.log.std +
                    latitude.std + longitude.std +
                    pool.flag.is.Y,
                    data=training.data,
                    maxit=ifelse(settings$testing,10,settings$maxit)
                    )
  
  # determine accuracy on the training data
  training.predictions <- predict(model, newdata=training.data)
  num.accurate <- sum(training.predictions == training.data$known.values)
  accuracy <-num.accurate / length(known.row.indices)
  cat(sprintf("accuracy for imputation of %s is %f\n",
              column.name, accuracy))
  
  # predict values when original value is missing
  predictions <- predict(model, newdata=all.data[!known.row.indices,])
  
  # return known values or imputed values
  result <- replace(column, !known.row.indices, predictions)
  result
}

# example from stack overflow
# http://stackoverflow.com/questions/14250015/how-to-impute-missing-value-using-rs-multinom
# example was modified for the code below
# I generated the stack overflow question
example <- function() {
  set.seed(1)
  A = factor(sample(letters[1:5], 30, replace=TRUE))
  B = sample(c(letters[24:26],NA), 30, replace=TRUE)
  df = data.frame(A = A, B = B, stringsAsFactors=FALSE)
  df$B.factor = factor(df$B)
  model <- multinom(B.factor ~ A, data=df)
  predictions <- predict(model, newdata = df[is.na(df$B),])
  df$B.complete <- replace(df$B, is.na(df$B), as.character(predictions))
  print("example finishing")
}


ImputeAll <- function(t) {
  # Impute missing values in certain factor columns in transactions
  # Args:
  #   t: data.frame containing the transactions
  #
  # Returns:
  #   new data frame with only additional columns
  
  result <- t
  
  # impute columns
  result$air.conditioning.code <- ImputeOne(t, "AIR.CONDITIONING.CODE")
  result$condition.code <- ImputeOne(t, "CONDITION.CODE")
  result$construction.type.code <- ImputeOne(t, "CONSTRUCTION.TYPE.CODE")
  result$exterior.wall.code <- ImputeOne(t, "EXTERIOR.WALLS.CODE")
  result$foundation.code <- ImputeOne(t, "FOUNDATION.CODE")
  result$garage.code <- ImputeOne(t, "GARAGE.CODE")
  result$heating.code <- ImputeOne(t, "HEATING.CODE")
  result$location.influence.code <- ImputeOne(t, "LOCATION.INFLUENCE.CODE")
  result$parking.type.code <- ImputeOne(t, "PARKING.TYPE.CODE")
  result$quality.code <- ImputeOne(t, "QUALITY.CODE")
  result$roof.cover.code <- ImputeOne(t, "ROOF.COVER.CODE")
  browser()
  result$roof.type.code <- ImputeOne(t, "ROOF.TYPE.CODE")
  result$style.code <- ImputeOne(t, "STYLE.CODE")
  result$view <- ImputeOne(t, "VIEW")

  # drop the original columns
  # NOTE: Must do this after all the imputation is done
  result$AIR.CONDITIONING.CODE <- NULL
  result$CONDITION.CODE <- NULL
  result$CONSTRUCTION.TYPE.CODE <- NULL
  result$EXTERIOR.WALL.CODE <- NULL
  result$FOUNDATION.CODE <- NULL
  result$GARAGE.CODE <- NULL
  result$HEATING.CODE <- NULL
  result$LOCATION.INFLUENCE.CODE <- NULL
  result$PARKING.TYPE.CODE <- NULL
  result$QUALITY.CODE <- NULL
  result$ROOF.COVER.CODE <- NULL
  result$STYLE.CODE <- NULL
  result$VIEW <- NULL

  # return new data.frame
  result
}

DropNotRelevant <- function(t) {
  # drop columns that have no information and those we aren't planning to use
  result <- t

  result$X <- NULL       # added by reading process
  result$APN.FORMATTED.x <- NULL  # use only formatted version
  result$APN.FORMATTED.y <- NULL
  result$CENSUS.BLOCK.GROUP <- NULL
  result$CENSUS.BLOCK <- NULL
  result$CENSUS.BLOCK.SUFFIX <- NULL
  result$RECORDING.DATE <- NULL   # use only SALE.DATE
  result$SUBDIVISION.TRACT.NUMBER <- NULL
  result$SUBDIVISION.NAME <- NULL
  result$YEAR.BUILT <- NULL  # use EFFECTIVE.YEAR.BUILT

  # drop columns that always have the same value
  TestAndDrop <- function(column.name) {
    first.value = t[[column.name]][1]
    if (all(t[[column.name]] == first.value, na.rm=TRUE)) {
      cat(sprintf("dropping column %s, as has no information\n",
                  column.name))
      result[[column.name]] <<- NULL
    }
    NULL  # return nothing, run for side effect of updating result
  }
}

################################################################################
## TRANSACTIONS.READ
################################################################################

TransactionsRead <- function(path, nrows) {
  # Read some or all of the transactions file.
  #
  # Args:
  #   path: scalar character, path to csv file containing transactions
  #   nrows: scalar number
  #   - if < 0, then return all transactions
  #   - if >=0, return first nrows transactions
  #
  # Returns:
  #   data.frame with transactions and these additional columns
  #   - transactionId: integer vector, unique IDs, 1:nrows
  #   - runif: numeric vector, drawns from random uniform distribution over
  #     [0,1]
  t <- read.csv(path
                ,fill=FALSE
                ,row.names=NULL
                ,stringsAsFactors=TRUE
                ,nrows=nrows
                )
  n = nrow(t)
  cat(sprintf("read %d transactions from %s\n",
              n, settings$path.transactions))
  
  # create transaction id
  # NOTE: t$X is also a transaction id, but is not used, because its
  # not documented
  t$transactionId <- 1:n  # NOTE: t$X is also a transaction id

  # create uniform random numbers that can later be used to
  # classify observations into testing and training
  t$runif <- runif(n, min=0, max=1)

  t
}

################################################################################
## UTILITY
################################################################################

################################################################################
## MAIN
################################################################################

Go <- function() {
  # Reload source file and do the work.
  source("createObservations.R", echo=FALSE)
  Run()
}

go <- Go  # short cut for using from commannd line

Run <- function() {
  # Do the work.
  #debug(TransactionsRead)
  #debug(ImputeAll)
  #debug(ImputeOne)
  #debug(StandardizeDf)
  t <- TransactionsRead(path=settings$path.transactions,
                        nrows=ifelse(settings$testing, 1000, -1))
  print(summary(t))

  imputed <- ImputeAll(t)
  relevant <- DropNotRelevant(t)
  
  cat("\nending at", TimeStamp(), "\n")
  if (settings$testing)
    cat("TESTING: DISCARD OUTPUT\n")
}

