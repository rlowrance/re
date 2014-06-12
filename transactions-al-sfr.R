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
control$testing.nrow <- 100000
control$testing.nrow <- 200000
control$testing <- TRUE
control$testing <- FALSE

source('InitializeR.R')
InitializeR(start.JIT = FALSE,
            duplex.output.to = control$path.log)

# Source other files here

source("BestApns.R")
source("RemoveNonInformative.R")

ReadCensus <- function(control) {
    # Read input files
    # ARGS:
    # control : list of control vars
    # RETURNS: data.frame
    cat('starting ReadCensus\n')
    census <- read.table(control$path.census,
                         header=TRUE,
                         sep="\t",
                         quote="",
                         comment.char="",
                         stringsAsFactors=FALSE,
                         nrows=ifelse(control$testing, control$testing.nrow, -1))                  
    cat("number of census records read", nrow(census), "\n")
    str(census)
    census
}

ReadDeeds <- function(control) {
    # Read deeds file
    # ARGS:
    # control : list of control vars
    # RETURNS data.frame
    cat('starting ReadDeeds\n')
    deeds <- read.csv(control$path.deeds,
                      check.names = FALSE,
                      header=TRUE,
                      quote="",
                      comment="",
                      stringsAsFactors=FALSE,
                      nrows=ifelse(control$testing, control$testing.nrow, -1))
    cat("number of deeds records read", nrow(deeds), "\n")
    cat('deeds column names\n')
    print(names(deeds))
    # drop all fields except those related to the deed itself
    only.deed.fields <-
        subset(deeds,
               select = c(APN.UNFORMATTED, APN.FORMATTED,
                          DOCUMENT.YEAR,
                          SALE.AMOUNT, SALE.DATE, RECORDING.DATE,
                          DOCUMENT.TYPE.CODE, TRANSACTION.TYPE.CODE, SALE.CODE,
                          MULTI.APN.FLAG.CODE, MULTI.APN.COUNT,
                          TITLE.COMPANY.CODE, 
                          RESIDENTIAL.MODEL.INDICATOR.FLAG,
                          MORTGAGE.DATE, MORTGAGE.LOAN.TYPE.CODE,
                          MORTGAGE.DEED.TYPE.CODE, MORTGAGE.TERM.CODE, MORTGAGE.TERM,
                          MORTGAGE.DUE.DATE, MORTGAGE.ASSUMPTION.AMOUNT,
                          X2ND.MORTGAGE.AMOUNT, X2ND.MORTGAGE.LOAN.TYPE.CODE,
                          X2ND.MORTGAGE.DEED.TYPE.CODE,
                          # don't keep prior sale info
                          # don't keep taxroll data
                          deed.file.number, deed.record.number)
               )
    cat('only.deed.fields\n')
    print(names(only.deed.fields))
    only.deed.fields
}

ReadGeocoding <- function(control) {
    # Read geocoding file
    # ARGS:
    # control : list of control variables
    # RETURNS data.frame
    cat('starting ReadGeocoding\n')
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
    cat('starting ReadParcels\n')
    parcels <- read.csv(control$path.parcels,
                        check.names=FALSE,
                        header=TRUE,
                        quote="",
                        comment="",
                        stringsAsFactors=FALSE,
                        nrows=ifelse(control$testing, control$testing.nrow, -1))
    cat("number of parcels records read", nrow(parcels), "\n")
    cat('parcel column names\n')
    print(names(parcels))
    
    StartsWith <- function(name.prefix) {
        result <- NULL
        for (name in names(parcels)) {
            components <- strsplit(name, '.', fixed = TRUE) [[1]]
            if (components[[1]] == name.prefix) {
                result <- c(result, name)
            }
        }
        result
    }

    to.drop <- c('DOCUMENT.YEAR', 'SALES.DOCUMENT.TYPE.CODE', 'RECORDING.DATE',
                 'SALE.DATE', 'SALE.AMOUNT', 'SALE.CODE', 'SALES.TRANSACTION.TYPE.CODE',
                 'MULTI.APN.FLAG.CODE', 'MULTI.APN.COUNT', 'RESIDENTIAL.MODEL.INDICATOR.FLAG',
                 StartsWith('X1ST'), 
                 StartsWith('X2ND'),
                 StartsWith('PRIOR'))

    for (name in to.drop) {
        parcels[[name]] <- NULL
    }


    cat('parcel column names after dropping sales data\n')
    print(names(parcels))

    # convert zipcode from char to numeric
    # drop those that do not convert
    #browser()

    parcels$PROPERTY.ZIPCODE <- suppressWarnings(as.numeric(parcels$PROPERTY.ZIPCODE))
    has.numeric.zipcode <- !is.na(parcels$PROPERTY.ZIPCODE)
    parcels <- parcels[has.numeric.zipcode, ]

    # create zip 5 field
    #browser()
    parcels$zip5 <- ifelse(parcels$PROPERTY.ZIPCODE <= 99999,
                           parcels$PROPERTY.ZIPCODE,  # some are coded 91234, not 912345678
                           round(parcels$PROPERTY.ZIPCODE / 10000))

    #cat('check zip5 field\n'); browser()
    
    parcels
}

ReadParcelsCensusTract <- function(control) {
    # Read census tract data derived from parcels
    # ARGS:
    # control : list of control vars
    # RETURNS: data.frame
    cat('starting ReadParcelsCensusTract\n')
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
    cat('starting ReadParcelsZip5\n')
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
    cat('starting MergeDeedsParcels\n')
    deeds <- ReadDeeds(control)
    parcels <- ReadParcels(control)

    # we will merge on the APN fields, so we need to find the best APNs
    deeds$apn.recoded <- BestApns(deeds$APN.UNFORMATTED, deeds$APN.FORMATTED)
    parcels$apn.recoded <- BestApns(parcels$APN.UNFORMATTED, parcels$APN.FORMATTED)

    # merge deeds and parcels
    #cat('in MergeDeedsParcels; about to merge\n'); browser()
    #cat('about to merge\n'); browser()
    merged <- merge(deeds, parcels, by="apn.recoded",
                    suffixes=c(".deeds", ".parcels"))
    cat("number of deeds and parcels with common recoded.apn",
        nrow(merged),
        "\n")
    #browser()

    # drop redundant fields
    merged$APN.UNFORMATTED.deeds <- NULL
    merged$APN.FORMATTED.deeds <- NULL
    merged$APN.UNFORMATTED.parcels<- NULL
    merged$APN.FORMATTED.parcels <- NULL

    BaseName <- function(components, last.index) {
        base.name <- components[[1]] [[1]]
        for (component in components[[1]] [2:(last.index - 1)]) {
            base.name <- paste0(base.name, '.', component)
        }
        base.name
    }

    RecodeNA <- function(v) {
        ifelse(is.na(v),
               NA,
               ifelse(v == 'N/AVAIL',
                      NA,
                      v)
               )
    }

    BestValue <- function(deeds.value, parcels.value) {
        ifelse(is.na(deeds.value),
               ifelse(is.na(parcels.value),
                      NA,
                      parcels.value),
               deeds.value)
    }

    cat('merging fields with redundant content\n')
    for (name in names(merged)) {
        #cat('top of name loop\n'); browser()
        components <- strsplit(name, '.', fixed=TRUE)
        last.index <- length(components[[1]])
        last.component <- components[[1]][[last.index]]

        if (last.component == 'deeds') {
            # elimate redundant .deeds and .parcels columns
            base.name <- BaseName(components, last.index)
            deeds.name <- paste0(base.name, '.deeds')
            parcels.name <- paste0(base.name, '.parcels')

            deeds.value.recoded <- RecodeNA(merged[[deeds.name]])
            parcels.value.recoded <- RecodeNA(merged[[parcels.name]])

            best.value <- BestValue(deeds.value.recoded, parcels.value.recoded)

            either.is.na <- is.na(deeds.value.recoded) | is.na(parcels.value.recoded)
            significant.difference <- (deeds.value.recoded != parcels.value.recoded)[!either.is.na]

            if (all(!significant.difference)) {
                cat(' using best value to remove duplicate', base.name, '\n')
                #browser()
                merged[[base.name]] <- best.value
                merged[[deeds.name]] <- NULL
                merged[[parcels.name]] <- NULL
                #browser()
            }
        }
    }
    #cat('review merged\n'); browser()

    merged
}

MergeCensus <- function(df, control) {
    # merge the census data into a data.frame
    # ARGS:
    # df : data frame containing merged deeds and parcels features
    # control : control variables list
    # RETURNS: data.frame augmented with census data
    cat('starting MergeCensus', nrow(df), '\n') 
    #browser()
    census <- ReadCensus(control)
    cat('names in df\n')
    print(names(df))
    print('names in census\n')
    print(names(census))
    #cat('about to merge in MergeCensus\n'); browser()
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
    cat('starting MergeCoding', nrow(df), '\n')
    geocoding <- ReadGeocoding(control)
    merged <- merge(df, geocoding, by.x="apn.recoded", by.y="G.APN")
    cat("number of transactions, after considering geocoding",
        nrow(merged),
        "\n")
    merged
}

MergeParcelsCensusTract <- function(df, control) {
    # merge census tract data into a data.frame
    cat('starting MergeParcelsCensusTract', nrow(df), '\n')
    census.tract <- ReadParcelsCensusTract(control)
    merged <- merge(df, census.tract,
                    by.x = 'CENSUS.TRACT', 
                    by.y = 'census.tract')
}

MergeParcelsZip5 <- function(df, control) {
    # merge census tract data into a data.frame
    cat('starting MergeParcelsZip5', nrow(df), '\n')
    zip5 <- ReadParcelsZip5(control)
    #browser()
    df$zip5 <- round(df$PROPERTY.ZIPCODE / 10000)
    merged <- merge(df, zip5,
                    by.x = 'zip5', 
                    by.y = 'zip5')
}

MergeAll <- function(control) {
    # merge all 4 files and return merged data.frame
    #cat('starting MergeAll\n'); browser()
    deedsParcels <- MergeDeedsParcels(control)
    deedsParcelsCensus <- MergeCensus(deedsParcels, control)
    transactions.geocoded <- MergeGeocoding(deedsParcelsCensus, control)
    transactions.derived.census.tract <- MergeParcelsCensusTract(transactions.geocoded, control)
    transactions.all.derived <- MergeParcelsZip5(transactions.derived.census.tract, control)
}

WriteControl <- function(control) {
    # write control variables
    cat('\ncontrol variables\n')
    for (name in names(control)) {
        cat('control ', name, ' = ', control[[name]], '\n')
    }
}

Main <- function(control) {
    # this gradual approach is designed to minimize RAM usage by
    # allowing the garbage collector to free data.frames as we build
    # up the final result 

    # write control variables
    WriteControl(control)

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
    cat('\nfields in merged csv\n')
    print(names(merged))

    # write control variables
    WriteControl(control)
}

Main(control)


cat('done\n')
