# census.R
# Create file census.csv

# set variable that control the script
control <- list()
control$me <- 'census'
control$dir.output="../data/v6/output/"
control$path.census.in <- "../data/raw/neighborhood-data/census.csv"
control$path.census.out <- paste0(control$dir.output, "census.csv")
control$path.log <- paste0(control$dir.output, control$me, '.txt')
control$testing <- TRUE
control$testing <- FALSE

# initialize R
source('InitializeR.R')
InitializeR(start.JIT = ifelse(control$testing, FALSE, TRUE), 
            duplex.output.to = control$path.log)

# Source files here, now that the JIT level is set

ReadRawCensus <- function(control) {
    # Read the raw census data into a data.frame
    # ARGS:
    # control : control variables, including path to input
    # RETURNS: data.frame

    # skip first line, as it contains hard-to-interpret feature names
    # and easy-to-interpret feature names are in the second line
    df <- read.table(control$path.census.in,
                     header=TRUE,
                     skip=1, 
                     sep="\t",
                     comment.char="",
                     stringsAsFactors=FALSE,
                     na.strings="")
}

CensusTract <- function(df) {
    # isolate the census tract feature
    # ARGS:
    # df : data.frame of raw data
    # RETURNS: vector of census tract codes 999999

    geo.id2 <- df$Geography.Identifier2
    fips.code <- floor(geo.id2/1000000)
    census.tract <-geo.id2 - fips.code * 1000000
}

AvgCommute <- function(df) {
    # determine average commute time for works 16 years and older who commute
    # ARGS:
    # df : data.frame
    # RETURNS vector of average times in minutes
    not.home = "Workers.16.years.and.over..Did.not.work.at.home"
    workers.not.at.home <- df[[not.home]]

    time <- function(specification) {
        result <- paste(not.home,
                        "..Travel.time.to.work..",
                        specification,
                        ".minutes",
                        sep="")
        result
    }

    # number of commuters
    commute.less.5 <- df[[time("Less.than.5")]]
    commute.5.to.9 <- df[[time("5.to.9")]]
    commute.10.to.14 <- df[[time("10.to.14")]]
    commute.15.to.19 <- df[[time("15.to.19")]]
    commute.20.to.24 <- df[[time("20.to.24")]]
    commute.25.to.29 <- df[[time("25.to.29")]]
    commute.30.to.34 <- df[[time("30.to.34")]]
    commute.35.to.39 <- df[[time("35.to.39")]]
    commute.40.to.44 <- df[[time("40.to.44")]]
    commute.45.to.59 <- df[[time("45.to.59")]]
    commute.60.to.89 <- df[[time("60.to.89")]]
    commute.more.90 <- df[[time("90.or.more")]]

    # weighted average commute time
    avg.commute <-
        ((commute.less.5 * ((0 + 5) / 2)) +
         (commute.5.to.9 * ((5 + 9) / 2)) +
         (commute.10.to.14 * ((10 + 14) / 2)) +
         (commute.15.to.19 * ((15 + 19) / 2)) +
         (commute.20.to.24 * ((20 + 24) / 2)) +
         (commute.25.to.29 * ((25 + 29) / 2)) +
         (commute.30.to.34 * ((30 + 34) / 2)) +
         (commute.35.to.39 * ((35 + 39) / 2)) +
         (commute.40.to.44 * ((40 + 44) / 2)) +
         (commute.45.to.59 * ((45 + 59) / 2)) +
         (commute.60.to.89 * ((60 + 89) / 2)) +
         (commute.more.90 * 120)
         ) /
    workers.not.at.home
}

MedianHouseholdIncome <- function(df) {
    # determine median household income
    # ARGS
    # df : data frame of raw data
    # RETURNS vector of median household incomes 
    df$Households..Median.household.income.in.1999
}

FractionOwnerOccupied <- function(df) {
    # determine fraction of houses occupied by owners
    # ARGS
    # df : data frame of raw data
    # RETURNS vector of fractions
    occupied.housing.units <- df$Occupied.housing.units..Total
    owner.occupied.units <- df$Occupied.housing.units..Owner.occupied
    owner.occupied.units / occupied.housing.units
}

###############################################################################
## Main program
###############################################################################

Main <- function(control) {
    # write control variables
    for (name in names(control)) {
        cat('control ', name, ' = ', control[[name]], '\n')
    }

    # read the raw data
    df <- ReadRawCensus(control)

    # create output data.frame
    r <- data.frame(census.tract = CensusTract(df),
                    avg.commute = AvgCommute(df),
                    median.household.income = MedianHouseholdIncome(df),
                    fraction.owner.occupied = FractionOwnerOccupied(df))
    str(r)

    # drop records with NaN values in the newly-created variables
    missing.commute <- is.na(r$avg.commute)
    missing.income <- is.na(r$median.household.income)
    missing.occupied <- is.na(r$fraction.owner.occupied)

    cat("# of missing commute", sum(missing.commute), "\n")
    cat("# of missing income", sum(missing.income), "\n")
    cat("# of missing occupied", sum(missing.occupied), "\n")

    some.missing <- missing.commute | missing.income | missing.occupied
    cat("# with some missing", sum(some.missing), "\n")

    a <- r[!some.missing,]  # drop observations with any missing value
    cat("# obs retained", nrow(a), '\n')

    write.table(a,
                control$path.census.out,
                row.names=FALSE,
                quote=FALSE,
                sep="\t")  # same separator as original file
}


Main(control)
cat('done\n')
