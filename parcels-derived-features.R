# features-zip.R
# Create files OUTPUT/feature-zip-5.R and features-zip-9.R containing zipcode features
# 
# Files read and the deeds files the Laufer directory. This directory contains
# the file Steve Laufer used in his experiments.


# set the control variables
control <- list()
control$me <- 'parcels-derived-features'
control$laufer.dir <-'../data/raw/from-laufer-2010-05-11'
control$dir.output <- "../data/v6/output/"

control$path.zip5 <- paste0(control$dir.output, control$me, '-', "zip5.csv")
control$path.census.tract <- paste0(control$dir.output, control$me, '-', "census-tract.csv")

control$path.log <- paste0(control$dir, control$me, '.txt')
control$return.all.fields <- TRUE
control$testing <- TRUE
control$testing <- FALSE


# Initialize R.
source('InitializeR.R')
InitializeR(start.JIT = FALSE,
            duplex.output.to = control$path.log)

# source other files now that JIT is running
source('LUSEI.R')
source('PROPN.R')
source('Printf.R')

## Define function to read a taxroll file

ReadParcelsFile <- function(num, control) {
    # read  features in a taxroll file
    # ARGS:
    # num              : number of the file
    # return.all.field : logical
    # RETURNS a data.frame
    path <- paste(control$laufer.dir,
                  "/tax/CAC06037F",
                  num,
                  ".txt.gz",
                  sep="")
    cat("reading tax file", path, "\n")
    df <- read.table(path,
                     header=TRUE,
                     sep="\t",
                     quote="",
                     comment="",
                     stringsAsFactors=FALSE,
                     na.strings="",
                     nrows=ifelse(control$testing,1000,-1))

    # analyze raw data
    cat("records in", path, nrow(df), "\n")
    for (name in names(df)) {
        Printf('%30s', name)
        str(df[[name]])
    }

    if (TRUE) print(summary(df))
    


    # select the fields we want
    df <- data.frame(UNIVERSAL.LAND.USE.CODE = df$UNIVERSAL.LAND.USE.CODE,
                     PROPERTY.INDICATOR.CODE = df$PROPERTY.INDICATOR.CODE,
                     PROPERTY.ZIPCODE = df$PROPERTY.ZIPCODE,
                     CENSUS.TRACT = df$CENSUS.TRACT,
                     stringsAsFactors=FALSE)
    df
}

ReadAll <- function(control) {
    # Read all the parcels into one huge data.frame
    # ARGS: none
    # RETURNS: list
    # $df : data.frame with lots of rows
    df <- NULL
    for (file.number in 1:8) {
        a.list <- ReadParcelsFile(file.number, control)
        df <- rbind(df, a.list)
    }
    df
}

###############################################################################
## Misc function
###############################################################################



ParcelIndicators <- function(df) {
    data.frame(is.industry = PROPN(df$PROPERTY.INDICATOR.CODE, 'any.industrial'),
               is.park = LUSEI(df$UNIVERSAL.LAND.USE.CODE, 'park'),
               is.retail = PROPN(df$PROPERTY.INDICATOR.CODE, 'retail'),
               is.school = LUSEI(df$UNIVERSAL.LAND.USE.CODE, 'any.school'))
}

Has <- function(location, indicator.column.name, parcels.coded) {
    right.location <- location == parcels.coded$location
    sum(parcels.coded[right.location, indicator.column.name]) > 0
}

CreateLocationFeatures <- function(control, parcels.coded) {
    cat('starting CreateLocationFeatures\n')
    #browser()
    str(parcels.coded)
    print(summary(parcels.coded))

    unique.locations <- unique(parcels.coded$location)
    location.df <- data.frame(location = unique.locations,
                              has.industry = vapply(unique.locations, Has, FALSE, 'is.industry', parcels.coded),
                              has.park = vapply(unique.locations, Has, FALSE, 'is.park', parcels.coded),
                              has.retail = vapply(unique.locations, Has, FALSE, 'is.retail', parcels.coded),
                              has.school = vapply(unique.locations, Has, FALSE, 'is.school', parcels.coded))
}

AnalyzeZip9 <- function(control, parcels.coded) {
    cat('starting AnalyzeZip9\n')
    #browser()
    # We don't create features for the 9-digit zipcode, as there are only about 5
    # parcels per 9-digit zip code
    parcels.coded <- na.omit(parcels.coded)
    n.unique.zip9 <- length(unique(parcels.coded$zip9))
    parcels.coded.per.zip9 <- nrow(parcels.coded) / n.unique.zip9
    cat('number of unique zip9 values', n.unique.zip9, '\n')
    cat('average parcels per zip9', parcels.coded.per.zip9, '\n')
    if (!control$testing) {
        # a testing subset may not satisfy this condition
        # but a production subset must satisfy this condition
        stopifnot(parcels.coded.per.zip9 < 5)
    }  
}

AnalyzeParcelIndicators <- function(control, parcels.coded) {
    #cat('starting AnalyzeParcelIndicators\n'); browser()
    debug <- FALSE

    # does any park have a zip code?
    if (debug) print(summary(parcels.coded))
    
    is.na.zip5 <- is.na(parcels.coded$zip5)
    is.na.census.tract <- is.na(parcels.coded$census.tract)

    CountPresent <- function(column.name) {
        sum(parcels.coded[[column.name]])
    }

    CountMissing <- function(column.name, is.na.location) {
        present.in.all <- sum(parcels.coded[[column.name]])
        present.in.some <- sum(parcels.coded[!is.na.location, column.name])
        present.in.all - present.in.some
    }

    AnalyzeMissing <- function(column.name, is.na.location, location.feature.name) {
        #cat('starting AnalyzeMissing\n'); browser()
        Printf('number of %s\n', column.name)
        Printf(' with a %s     %7d\n', location.feature.name, CountPresent(column.name))
        Printf(' without a %s  %7d\n', location.feature.name, CountMissing(column.name, is.na.location))
    }

    AnalyzeMissingZip5 <- function(column.name) {
        AnalyzeMissing(column.name, is.na.zip5, 'zip5')
    }

    AnalyzeMissingCensusTract <- function(column.name) {
        AnalyzeMissing(column.name, is.na.census.tract, 'census tract')
    }


    features <- c('is.industry', 'is.park', 'is.retail', 'is.school')

    lapply(features, AnalyzeMissingZip5)
    lapply(features, AnalyzeMissingCensusTract)

}

ValidZip5 <- function(df) {
    # return data.frame with valid zip5 fields (which are in the location feature)
    # some 9-digit zip codes are coded 9, so we need to observations with these bad zip codes
    is.valid <- df$location >= 90000  # eliminate value 9
    df[is.valid,]
}

ValidCensusTract <- function(df) {
    # return data.frame containing only observations with a valid census.tract feature
    #cat('starting ValidCensusTract\n'); browser()
    # all census tract features are valid
    df
}

###############################################################################
## Main program
###############################################################################

Main <- function(control, parcels) {
    cat('starting Main\n')
    #browser()
    # write control variables
    for (name in names(control)) {
        cat('control ', name, ' = ', control[[name]], '\n')
    }

    parcels.coded <- cbind(ParcelIndicators(parcels),
                           zip9 = parcels$PROPERTY.ZIPCODE,
                           zip5 = round(parcels$PROPERTY.ZIPCODE / 10000),
                           census.tract = parcels$CENSUS.TRACT)

    if (TRUE) {
        cat('analyze parcel indicators\n')
        AnalyzeParcelIndicators(control, parcels.coded)
    }

    if (control$testing)
        parcels.coded <- parcels.coded[1:10000,]


    str(parcels.coded)
    print(summary(parcels.coded))

    if (TRUE) {
        cat('justify not determining features for zip9\n')
        AnalyzeZip9(control, parcels.coded)
    }

    if (TRUE) {
        cat('determine by zip5\n')
        #browser()
        zip.df <- ValidZip5(na.omit(data.frame(is.industry = parcels.coded$is.industry,
                                               is.park = parcels.coded$is.park,
                                               is.retail = parcels.coded$is.retail,
                                               is.school = parcels.coded$is.school,
                                               location = parcels.coded$zip5)))
        #AnalyzeZip9(control, no.census.tract)
        location.df <- CreateLocationFeatures(control, zip.df)

        # rename feature location to zip5
        location.df$zip5 <- location.df$location
        location.df$location <- NULL

        cat('zip5  output\n')
        str(location.df)
        print(summary(location.df))

        write.csv(location.df, file=control$path.zip5, row.names=FALSE)
    }

    if (TRUE) {
        cat('determine by census tract\n')
        #browser()

        census.tract.df <- ValidCensusTract(na.omit(data.frame(is.industry = parcels.coded$is.industry,
                                                               is.park = parcels.coded$is.park,
                                                               is.retail = parcels.coded$is.retail,
                                                               is.school = parcels.coded$is.school,
                                                               location = parcels.coded$census.tract)))
        location.df <- CreateLocationFeatures(control, census.tract.df)
        
        # rename
        location.df$census.tract <- location.df$location
        location.df$location <- NULL

        cat('census tract output\n')
        str(location.df)
        print(summary(location.df))

        write.csv(location.df, file=control$path.census.tract, row.names=FALSE)
    }
}

# read data if its not in the workspace
force.read <- FALSE
#force.read <- TRUE
if (force.read | !exists('parcels.selected.fields')) {
    parcels.selected.fields <- ReadAll(control)
}

# process the data
Main(control, parcels.selected.fields)

if (control$testing)
    cat('TESTING: DISCARD RESULTS\n')
cat('done\n')

