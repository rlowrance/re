# impute-foundation-code.R
# Print coefficients for FOUNDATION CODE imputation
# When starting R the location of the data directory must be specfied via:

# on local
#  cd src.git/R
#  R --args ../../data/

# on a NYU compute server
#  ssh server
#  cd .../scr.git/R
#  R --args /scratch/lowrance/nyu-thesis-project/data/


library("mlogit")

# set mlogit.optim method
# default is "nr" (newton-raphson)
# choices: "bfgs" | "nr" | "bhhh"
methodname="nr"
print(paste("mlogit.method name =",methodname))

#projectdir <- "/home/roy/Dropbox/nyu-thesis-project/data/"
datadir <- commandArgs(TRUE)[1]  # first argument after --args
obs1featuresdir <- paste(datadir, "generated-v4/obs1A/features/", sep="")

# convert file name to field name
#filename.to.fieldname <- function(filename) {
#  gsub("-", ".", filename)
#}

# return vector from csv file
# filename is also the only column in the file
read.feature <- function(filename) {
  filepath <- paste(obs1featuresdir, filename, ".csv", sep="")
  df <- read.csv(filepath, sep="|")
  df[,1]
}

# return vector from a FOUNDATION-CODE-is-<code>.csv file
read.foundation.feature <- function(code) {
  filename <- paste("FOUNDATION-CODE-is-", code, sep="")
  read.feature(filename)
}

# print indices that contain a 1
one.indices <- function(x) {
  for (i in 1:217376) {
    if (x[[i]] == 1) print(i)
  }
}

# Read in all the features used in Obs 2R but from obs 1A
acres       <- read.feature("ACRES-log-std")
bedrooms    <- read.feature("BEDROOMS-std")
commute     <- read.feature("census-avg-commute-std")
income      <- read.feature("census-income-log-std")
ownership   <- read.feature("census-ownership-std")
day         <- read.feature("day-std")
improvement <- read.feature("IMPROVEMENT-VALUE-CALCULATED-log-std")
land        <- read.feature("LAND-VALUE-CALCULATED-log-std")
latitude    <- read.feature("latitude-std")
living      <- read.feature("LIVING-SQUARE-FEET-log-std")
longitude   <- read.feature("longitude-std")
parking     <- read.feature("PARKING-SPACES-std")
percent     <- read.feature("percent-improvement-value-std")
pool        <- read.feature("POOL-FLAG-is-1")
price       <- read.feature("SALE-AMOUNT-log-std")
baths       <- read.feature("TOTAL-BATHS-CALCULATED-std")
type        <- read.feature("TRANSACTION-TYPE-CODE-is-3")
year        <- read.feature("YEAR-BUILT-std")

# Read in FOUNDATION CODE levels from files FOUNDATION-CODE-is-<level>.csv
# where <level> is in { 001, CRE, MSN, PIR, RAS, SLB, UCR};
# level numbers:          1    2    3    4    5    6    7
# each vector value is either 0 or 1
# numbers in comments are the percent with the given level
print("starting to read features")
foundation.code.is.001 <- read.foundation.feature("001")  # <0.01%
foundation.code.is.cre <- read.foundation.feature("CRE")  # <0.01%
foundation.code.is.msn <- read.foundation.feature("MSN")  # <0.01%
foundation.code.is.pir <- read.foundation.feature("PIR")  # 1.7%
foundation.code.is.ras <- read.foundation.feature("RAS")  # 57%
foundation.code.is.slb <- read.foundation.feature("SLB")  # 41%
foundation.code.is.ucr <- read.foundation.feature("UCR")  # <0.01%

# Combine FOUNDATION CODE levels into one categorial feature FOUNDATION CODE with level 1 .. 7
#foundation.code <- (foundation.code.is.001 * 1) +
#                   (foundation.code.is.cre * 2) +
#                   (foundation.code.is.msn * 3) +
#                   (foundation.code.is.pir * 4) +
#                   (foundation.code.is.ras * 5) +
#                   (foundation.code.is.slb * 6) +
#                   (foundation.code.is.ucr * 7)
# only model 2 levels
foundation.code <- (foundation.code.is.ras * 1) +
                   (foundation.code.is.slb * 2) 
# only model 3 levels
foundation.code <- (foundation.code.is.pir * 1) +
                   (foundation.code.is.ras * 2) +
                   (foundation.code.is.slb * 3)
print("foundation codes modeled")
print(" level 1: PIR")
print(" level 2: RAS")
print(" level 3: SLB")
print(" level 0: all others (not distinguished)")
  
# convert data into form suitable for mlogit
# ref: www.ats.ucle.edu/stat/r/dae/mlogit.htm
print("starting to convert data to mlogit form")
df <- data.frame(
        acres=acres,
        bedrooms=bedrooms,
        commute=commute,
        income=income,
        ownership=ownership,
        day=day,
        improvement=improvement,
        land=land,
        latitude=latitude,
        living=living,
        longitude=longitude,
        parking=parking,
        percent=percent,
        pool=pool,
        price=price,
        baths=baths,
        type=type,
        year=year,
        foundation.code=foundation.code)
df$foundation.code <- as.factor(df$foundation.code)
mldata<-mlogit.data(df, varying=NULL, choice="foundation.code", shape="wide")

# Run the logit model
print("starting to run mlogit model")
mlogit.model <-
  mlogit(foundation.code ~1|
         acres+bedrooms+commute+income+ownership+day+improvement+land+
         latitude+living+longitude+parking+percent+pool+price+baths+type+year,
         data=mldata,
         reflevel="0",
         method=methodname)

# Print the model summary, which contains the coefficients
print(summary(mlogit.model))

# TODO: estimate in the obs 2R data set


# (maybe) Print decoder ring for the level numbers, if not estimating all values
