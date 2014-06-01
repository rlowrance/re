# transactions-al-sfr.R
# Create the transactions-al-sfr.csv file containing all transactions for
# arms-length deeds for single-family-residential parcels.

# Join these files:
# census.csv   : census records
# deeds-al.csv : selected deeds data for arms-length deeds
# geocoding.tsv : geocodes for residences
# parcels-sfr.csv : selected parcels data for single-family-residences
# parcels-derived-features-census-tract.csv : features of census tracts
# parcels-derived-features-zip5.csv : features of 5-digit zip codes

# Join the deeds and parcels fileson the best APN (defined below), not the
# formatted or unformatted APN.

# set control variables
control <- list()
control$me <- 'transactions-al-sfr'
control$dir.output <- "../data/v6/output/"
control$path.census <- paste(control$dir.output, "census.csv", sep="")
control$path.deeds <- paste(control$dir.output, "deeds-al.csv", sep="")
control$path.parcels <- paste(control$dir.output, "parcels-sfr.csv", sep="")
control$path.parcels.census.tract <- paste(control$dir.output, "parcels-derived-features-census-tract.csv", sep="")
control$path.parcels.zip5 <- paste(control$dir.output, "parcels-derived-features-zip5.csv", sep="")
control$path.geocoding <- "../data/raw/geocoding.tsv"
control$path.out <- paste(control$dir.output, "transactions-al-sfr.csv", sep="")
control$path.log <- paste0(control$dir.output, control$me, '.txt')
control$testing <- TRUE
control$testing <- FALSE

source('InitializeR.R')
InitializeR(start.JIT = ifelse(control$testing, FALSE, TRUE),
            duplex.output.to = control$path.log)

# Source other files here

source("BestApns.R")
source("RemoveNonInformative.R")

ReadCensus <- function(control) {
    # Read input files
    # ARGS:
    # control : list of control vars
    # RETURNS: data.frame
    census <- read.table(control$path.census,
                         header=TRUE,
                         sep="\t",
                         quote="",
                         comment.char="",
                         stringsAsFactors=FALSE,
                         nrows=ifelse(control$testing, 1000, -1))                  
    cat("number of census records read", nrow(census), "\n")
    str(census)
    census
}

ReadDeeds <- function(control) {
    # Read deeds file
    # ARGS:
    # control : list of control vars
    # RETURNS data.frame
    deeds <- read.csv(control$path.deeds,
                      check.names = FALSE,
                      header=TRUE,
                      quote="",
                      comment="",
                      stringsAsFactors=FALSE,
                      nrows=ifelse(control$testing, 1000, -1))
    cat("number of deeds records read", nrow(deeds), "\n")
    str(deeds)
    deeds
}

ReadGeocoding <- function(control) {
    # Read geocoding file
    # ARGS:
    # control : list of control variables
    # RETURNS data.frame
    geocoding <- read.table(control$path.geocoding,
                            header=TRUE,
                            sep="\t",
                            quote="",
                            comment="",
                            stringsAsFactor=FALSE,
                            na.strings="",
                            nrows=ifelse(control$testing, 1000, -1))
    cat("number of geocoding records read", nrow(geocoding), "\n")
    str(geocoding)
    geocoding
}

ReadParcels <- function(control) {
    # read parcels file into a data.frame
    # ARGS:
    # control : list of control variables
    # RETURNS data.frame
    parcels <- read.csv(control$path.parcels,
                        check.names=FALSE,
                        header=TRUE,
                        quote="",
                        comment="",
                        stringsAsFactors=FALSE,
                        nrows=ifelse(control$testing, 1000, -1))
    cat("number of parcels records read", nrow(parcels), "\n")
    str(parcels)
    parcels
}

ReadParcelsCensusTract <- function(control) {
    # Read census tract data derived from parcels
    # ARGS:
    # control : list of control vars
    # RETURNS: data.frame
    df <- read.csv(control$path.parcels.census.tract,
                   check.names=FALSE,
                   header=TRUE,
                   sep=",",
                   quote="",
                   comment.char="",
                   stringsAsFactors=FALSE,
                   nrows=ifelse(control$testing, 1000, -1))                  
    cat("number of parcel df records read", nrow(df), "\n")
    # fix up the column names
    df <- data.frame(census.tract              = df[['"census.tract"']],
                     census.tract.has.industry = df[['"has.industry"']],
                     census.tract.has.park     = df[['"has.park"']],
                     census.tract.has.retail   = df[['"has.retail"']],
                     census.tract.has.school   = df[['"has.school"']])
    str(df)
    df
}

ReadParcelsZip5 <- function(control) {
    # Read census tract data derived from parcels
    # ARGS:
    # control : list of control vars
    # RETURNS: data.frame
    df <- read.csv(control$path.parcels.zip5,
                   check.names=FALSE,
                   header=TRUE,
                   sep=",",
                   quote="",
                   comment.char="",
                   stringsAsFactors=FALSE,
                   nrows=ifelse(control$testing, 1000, -1))                  
    cat("number of parcel df records read", nrow(df), "\n")
    # fix up the column names
    df <- data.frame(zip5              = df[['"zip5"']],
                     zip5.has.industry = df[['"has.industry"']],
                     zip5.has.park     = df[['"has.park"']],
                     zip5.has.retail   = df[['"has.retail"']],
                     zip5.has.school   = df[['"has.school"']])
    str(df)
    df
}

MergeDeedsParcels <- function(control) {
    # merge the deeds and parcels into one data frame
    # ARGS
    # control : list of control variables
    # RETURNS data.frame with deeds, parcels, and best APNs
    deeds <- ReadDeeds(control)
    parcels <- ReadParcels(control)

    # we will merge on the APN fields, so we need to find the best APNs
    deeds$apn.recoded <- BestApns(deeds$APN.UNFORMATTED, deeds$APN.FORMATTED)
    parcels$apn.recoded <- BestApns(parcels$APN.UNFORMATTED, parcels$APN.FORMATTED)

    # merge deeds and parcels
    merged <- merge(deeds, parcels, by="apn.recoded",
                    suffixes=c(".deeds", ".parcels"))
    cat("number of deeds and parcels with common recoded.apn",
        nrow(merged),
        "\n")

    merged
}

MergeCensus <- function(df, control) {
    # merge the census data into a data.frame
    # ARGS:
    # df : data frame containing census tract feature
    # control : control variables list
    # RETURNS: data.frame augmented with census data
    census <- ReadCensus(control)
    cat('df\n'); str(df)
    cat('census\n'); str(census)
    merged <- merge(df, census, by.x="CENSUS.TRACT", by.y = "census.tract")
    cat("number of common deeds and parcels with known CENSUS.TRACT",
        nrow(merged),
        "\n")
    merged
}

MergeGeocoding <- function(df, control) {
    # merge geocoding data into a data.frame
    # ARGS:
    # df: data.frame containing recoded APNs
    # control: list of control variables
    # RETURNS: data.frame augmented with latitudes and longitudes
    geocoding <- ReadGeocoding(control)
    merged <- merge(df, geocoding, by.x="apn.recoded", by.y="G.APN")
    cat("number of transactions, after considering geocoding",
        nrow(merged),
        "\n")
    merged
}

MergeParcelsCensusTract <- function(df, control) {
    # merge census tract data into a data.frame
    census.tract <- ReadParcelsCensusTract(control)
    merged <- merge(df, census.tract,
                    by.x = 'CENSUS.TRACT', 
                    by.y = 'census.tract')
}

MergeParcelsZip5 <- function(df, control) {
    # merge census tract data into a data.frame
    zip5 <- ReadParcelsZip5(control)
    df$zip5 <- round(df$PROPERTY.ZIPCODE / 10000)
    merged <- merge(df, zip5,
                    by.x = 'zip5', 
                    by.y = 'zip5')
}

MergeAll <- function(control) {
    # merge all 4 files and return merged data.frame
    deedsParcels <- MergeDeedsParcels(control)
    deedsParcelsCensus <- MergeCensus(deedsParcels, control)
    transactions.geocoded <- MergeGeocoding(deedsParcelsCensus, control)
    transactions.derived.census.tract <- MergeParcelsCensusTract(transactions.geocoded, control)
    transactions.all.derived <- MergeParcelsZip5(transactions.derived.census.tract, control)
}

Main <- function(control) {
    # this gradual approach is designed to minimize RAM usage by
    # allowing the garbage collector to free data.frames as we build
    # up the final result 

    # write control variables
    for (name in names(control)) {
        cat('control ', name, ' = ', control[[name]], '\n')
    }

    # build up the fully-merged data.frame
    merged <- MergeAll(control)


    # Drop extraneous features.
    str('merged\n'); str(merged)
    merged$APN.UNFORMATTED.deeds <- NULL
    merged$APN.FORMATTED.deeds <- NULL
    merged$APN.UNFORMATTED.parcels <- NULL
    merged$APN.FORMATTED.parcels <- NULL

    # Write transactions file
    write.csv(merged, 
              quote=FALSE,
              file=control$path.out, 
              row.names=FALSE)
    cat("number of transactions written:", nrow(merged), "\n")
}

Main(control)


cat('done\n')
