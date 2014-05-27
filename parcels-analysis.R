# parcels-analysis.R
# Create file OUTPUT/parcels-analysis.R containing analyses of all the parcels
# 
# Files read and the deeds files the Laufer directory. This directory contains
# the file Steve Laufer used in his experiments.


# set the control variables
control <- list()
control$me <- 'parcels-analysis'
control$laufer.dir <-'../data/raw/from-laufer-2010-05-11'
control$dir.output <- "../data/v6/output/"
control$path.out <- paste0(control$dir.output, "parcels-sfr.csv")
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
    cat("records in", path, nrow(df), "\n")

    # select the fields we want
    if (!control$return.all.fields) {
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
    }
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
## Main program
###############################################################################

Main <- function(control, all.parcels) {
    # write control variables
    for (name in names(control)) {
        cat('control ', name, ' = ', control[[name]], '\n')
    }

    for (name in names(all.parcels)) {
        Printf('%30s', name)
        str(all.parcels[[name]])
    }

    if (TRUE) print(summary(all.parcels))
    
    
    PS <- function(column.name, all.parcels) {
        values <- all.parcels[[column.name]]
        
        cat('str of', column.name, '\n')
        str(values)

        cat('summary of', column.name, '\n')
        print(summary(values))

        cat('number of unique value', length(unique(values)), '\n')
    }

    PST <- function(column.name, all.parcels) {
        PS(column.name, all.parcels)
        values <- all.parcels[[column.name]]
        cat('table of values for', column.name, '\n')
        t <- table(values)
        print(table(values))
    }

    AnalyzeTaxYear <- function() {
        cat('\n********************** distribution of TAX.YEAR\n')
        PS('TAX.YEAR', all.parcels)
        #PS('SALE.DATE')
        cat('number of zero SALE.DATE', sum(all.parcels$SALE.DATE == 0, na.rm=TRUE), '\n')
        all.parcels$sale.year <- floor(all.parcels$SALE.DATE / 10000)
        all.parcels$sale.month <- floor((all.parcels$SALE.DATE - 10000 * all.parcels$sale.year) / 100)
        str(all.parcels$sale.month)
        PST('sale.year', all.parcels)
        PST('sale.month', all.parcels)
        cat('month of sale for sale.year == 2009\n')
        sale.year.2009 <- all.parcels[all.parcels$sale.year == 2009, 'sale.month']
        print(table(sale.year.2009))
    }


    AnalyzePropertyTypes <- function() {
        cat('\n********************** types of properties\n')
        PST('UNIVERSAL.LAND.USE.CODE', all.parcels)
        Lusei <- function(kind) {
            is.kind <- LUSEI(all.parcels$UNIVERSAL.LAND.USE.CODE, kind)
            cat('number of LUSEI properties of kind', kind,'is', sum(is.kind), '\n')
        }
        Lusei('any.school')
        Lusei('park')
        Lusei('police.fire.civil.defense')

        PST('PROPERTY.INDICATOR.CODE', all.parcels)
        Propn <- function(kind) {
            is.kind <- PROPN(all.parcels$PROPERTY.INDICATOR.CODE, kind)
            cat('number of PROPN properties of kind', kind,'is', sum(is.kind), '\n')
        }
        Propns <- function(vec) {
            for (i in 1:length(vec)) {
                Propn(vec[i])
            }
        }
        cat('num of each PROPN kind\n')
        Propns(c('single.family.residence', 'condominium', 'duplex', 'apartment',
                 'hotel', 'commercial', 'retail', 'service', 'office.building',
                 'warehouse', 'financial.insitution', 'hospital', 'parking', 
                 'amusement', 'industrial', 'industrial.light', 'industrial.heavy',
                 'transport', 'utilities', 'agriculture', 'vacant', 'empty',
                 'missing'))

        cat('\nnumber of aggregated PROPN kinds\n')
        Propn('any.residential')
        Propn('any.industrial')
        Propn('retail.or.service')
    }
    
    AnalyzeSaleInfo <- function() {
        cat('\n********************** sale info in taxroll file\n')
        PS('SALE.DATE', all.parcels)
        PS('SALE.AMOUNT', all.parcels)
        PS('PRIOR.SALE.DATE', all.parcels)
        PS('PRIOR.SALE.AMOUNT', all.parcels)
    }

    AnalyzeLocationInfo <- function() {
        cat('\n********************** location info in taxroll file\n')
        all.parcels$zip5 <- floor(all.parcels$PROPERTY.ZIPCODE / 10000)
        browser()

        LOC <- function(column.names) {

            PS.all <- function(column.names) {
                PS.1 <- function(column.name) {
                    cat('\n', column.name, '\n')
                    PS(column.name, all.parcels)
                }
                lapply(column.names, PS.1)
            }

            Count.all <- function(column.names) {
                Count.1 <- function(column.name) {
                    cat('number of unique', column.name, length(unique(all.parcels[[column.name]])), '\n')
                }
                lapply(column.names, Count.1)
            }

            PS.all(column.names)
            cat('\n')
            Count.all(column.names)
            NULL
        }

        LOC(c('MAP.REFERENCE.1', 'MAP.REFERENCE.2', 
              'CENSUS.TRACT', 'CENSUS.BLOCK.GROUP', 'CENSUS.BLOCK', 'CENSUS.BLOCK.SUFFIX',
              'ZONING', 
              'BLOCK.NUMBER', 'LOT.NUMBER', 'RANGE',
              'TOWNSHIP', 'SECTION', 'QUARTER.SECTION', 
              'THOMAS.BROS.MAP.NUMBER',
              'FLOOD.ZONE.COMMUNITY.PANEL.ID',
              'LATITUDE', 'LONGITUDE',
              'CENTROID.CODE', 'MUNICIPALITY.NAME',
              'SUBDIVISION.TRACT.NUMBER', 'SUBDIVISION.PLAT.BOOK', 'SUBDIVISION.PLAT.PAGE', 'SUBDIVISION.NAME',
              'PROPERTY.CITY', 'PROPERTY.ZIPCODE', 'zip5'))
    }

    AnalyzeAll <- function() {
        AnalyzeTaxYear()
        AnalyzePropertyTypes()
        AnalyzeSaleInfo()
        AnalyzeLocationInfo()
    }

    # do the work
    selected <- 'locationinfo'
    selected <- 'all'
    switch(selected,
           taxyear = AnalyzeTaxYear(),
           propertytypes = AnalyzePropertyTypes(),
           saleinfo = AnalyzeSaleInfo(),
           locationinfo = AnalyzeLocationInfo(),
           all = AnalyzeAll())
}

force.read <- FALSE
if (force.read | !exists('all.parcels')) {
    all.parcels <- ReadAll(control)
}
Main(control, all.parcels)
cat('done\n')

