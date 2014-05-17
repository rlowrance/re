# parcels-sfr.Rmd
# Create the output file holding single-family-residential parcels

# Create the output file holding the single-family-residential parcels. 
# 
# In order to cope with having only 16 GB of RAM on my system, only features 
# needed downstream in the pipeline are retained.
# 
# Files read and the deeds files the Laufer directory. This directory contains
# the file Steve Laufer used in his experiments.

# set the control variables
control <- list()
control$me <- 'parcels-sfr'
control$laufer.dir <-'../data/raw/from-laufer-2010-05-11'
control$dir.output <- "../data/v6/output/"
control$path.out <- paste0(control$dir.output, "parcels-sfr.csv")
control$path.log <- paste0(control$dir, control$me, '.txt')
control$testing <- TRUE
control$testing <- FALSE

# Initialize R.
source('InitializeR.R')
InitializeR(start.JIT = ifelse(control$testing, FALSE< TRUE),
            duplex.output.to = control$path.log)

# source other files now that JIT is running

## Define function to read a taxroll file

ReadParcelsFile <- function(num) {
    # read some of the features in a payroll file
    # ARGS:
    # num : number of the file
    # RETURNS a list
    # $df : data.frame with selected features
    # $num.dropped :number of rercords dropped (as not for single family residences)
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
    cat("records in", path, nrow(df), "\n")

    # select the fields we want
    df <- data.frame(APN.UNFORMATTED=df$APN.UNFORMATTED,
                     APN.FORMATTED=df$APN.FORMATTED,
                     CENSUS.TRACT=df$CENSUS.TRACT,
                     ZONING=df$ZONING,
                     UNIVERSAL.LAND.USE.CODE=df$UNIVERSAL.LAND.USE.CODE,
                     VIEW=df$VIEW,
                     LOCATION.INFLUENCE.CODE=df$LOCATION.INFLUENCE.CODE,
                     NUMBER.OF.BUILDINGS=df$NUMBER.OF.BUILDINGS,
                     PROPERTY.CITY=df$PROPERTY.CITY,
                     PROPERTY.ZIPCODE=df$PROPERTY.ZIPCODE,
                     TOTAL.VALUE.CALCULATED=df$TOTAL.VALUE.CALCULATED,
                     LAND.VALUE.CALCULATED=df$LAND.VALUE.CALCULATED,
                     IMPROVEMENT.VALUE.CALCULATED=df$IMPROVEMENT.VALUE.CALCULATED,
                     TAX.YEAR=df$TAX.YEAR,
                     LAND.SQUARE.FOOTAGE=df$LAND.SQUARE.FOOTAGE,
                     UNIVERSAL.BUILDING.SQUARE.FEET=df$UNIVERSAL.BUILDING.SQUARE.FEET,
                     LIVING.SQUARE.FEET=df$LIVING.SQUARE.FEET,
                     YEAR.BUILT=df$YEAR.BUILT,
                     EFFECTIVE.YEAR.BUILT=df$EFFECTIVE.YEAR.BUILT,
                     BEDROOMS=df$BEDROOM,
                     TOTAL.ROOMS=df$TOTAL.ROOMS,
                     TOTAL.BATHS.CALCULATED=df$TOTAL.BATHS.CALCULATED,
                     AIR.CONDITIONING.CODE=df$AIR.CONDITIONING.CODE,
                     BASEMENT.FINISH.CODE=df$BASEMENT.FINISH.CODE,
                     BLDG.CODE=df$BLDG.CODE,
                     BLDG.IMPROVEMENT.CODE=df$BLDG.IMPROVEMENT.CODE,
                     CONDITION.CODE=df$CONDITION.CODE,
                     CONSTRUCTION.TYPE.CODE=df$CONSTRUCTION.TYPE.CODE,
                     EXTERIOR.WALLS.CODE=df$EXTERIOR.WALLS.CODE,
                     FIREPLACE.INDICATOR.FLAG=df$FIREPLACE.INDICATOR.FLAG,
                     FIREPLACE.NUMBER=df$FIREPLACE.NUMBER,
                     FIREPLACE.TYPE.CODE=df$FIREPLACE.TYPE.CODE,
                     FOUNDATION.CODE=df$FOUNDATION.CODE,
                     FLOOR.CODE=df$FLOOR.CODE,
                     FRAME.CODE=df$FRAME.CODE,
                     GARAGE.CODE=df$GARAGE.CODE,
                     HEATING.CODE=df$HEATING.CODE,
                     MOBILE.HOME.INDICATOR.FLAG=df$MOBILE.HOME.INDICATOR.FLAG,
                     PARKING.SPACES=df$PARKING.SPACE,
                     PARKING.TYPE.CODE=df$PARKING.TYPE.CODE,
                     POOL.FLAG=df$POOL.FLAG,
                     POOL.CODE=df$POOL.CODE,
                     QUALITY.CODE=df$QUALITY.CODE,
                     ROOF.COVER.CODE=df$ROOF.COVER.CODE,
                     ROOF.TYPE.CODE=df$ROOF.TYPE.CODE,
                     STORIES.CODE=df$STORIES.CODE,
                     STYLE.CODE=df$STYLE.CODE,
                     UNITS.NUMBER=df$UNITS.NUMBER,
                     ELECTRIC.ENERGY.CODE=df$ELECTRIC.ENERGY.CODE,
                     FUEL.CODE=df$FUEL.CODE,
                     SEWER.CODE=df$SEWER.CODE,
                     WATER.CODE=df$WATER.CODE,
                     parcel.file.number=rep(num,nrow(df)),
                     parcel.record.number=1:nrow(df),
                     stringsAsFactors=FALSE)

    # keep only single-family residence parcels
    # CHECK FOR NAs
    original.num.rows = nrow(df)
    sfr <- df$UNIVERSAL.LAND.USE.CODE == 163
    df <- df[sfr, ]
    list(df=df, num.dropped = original.num.rows - nrow(df))
}

ReadAll <- function() {
    # Read all the parcels into one hug data.frame
    # ARGS: none
    # RETURNS: list
    # $df : data.frame with lots of rows
    # $num.dropped : number of non-single family residences found
    df <- NULL
    num.dropped <- 0
    for (file.number in 1:8) {
        a.list <- ReadParcelsFile(file.number)
        df <- rbind(df, a.list$df)
        num.dropped <- num.dropped + a.list$num.dropped
    }
    list(df=df, num.dropped=num.dropped)
}

###############################################################################
## Main program
###############################################################################

Main <- function(control) {
    # write control variables
    for (name in names(control)) {
        cat('control ', name, ' = ', control[[name]], '\n')
    }

    # read all the parcels
    all <- ReadAll()
    cat('number of single-family residential parcels', nrow(all$df), '\n')
    cat('number of non SFR parcels', all$num.dropped, '\n')

    str(all$df)
    print(summary(all$df))
    
    write.csv(all$df,
              file=control$path.out,
              quote=FALSE,
              row.names=FALSE)
    cat('done\n')
}

Main(control)


