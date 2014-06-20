# transaction-subset1.R
# Create output file transactions-subset1.csv.

# Also create two output analysis files:
# * transactions-subset1-ranges.tex : ranges of features used to create the subset
# * transactions-subset1-excluded.tex: number of observations excluded by each criterion in isolation
# 
# The input file is transactions-al-sfr.csv. 

## Initialize

# Set control variables.
control <- list()
control$me <- 'transactions-subset1'
control$output.dir <- "../data/v6/output/"
control$path.input <- paste(control$output.dir, "transactions-al-sfr.csv.gz", sep="")
control$path.output <- paste(control$output.dir, "transactions-subset1.csv", sep="")
control$path.log <- paste0(control$output.dir, control$me, '.txt')
control$path.ranges <- paste(control$output.dir, "transactions-subset1-ranges.tex", sep="")
control$path.excluded <- paste(control$output.dir, "transactions-subset1-excluded.tex", sep="")
control$compress <- 'only' # choices: 'also', 'no', 'only'
control$testing.nrow <- 1000
control$testing <- TRUE
control$testing <- FALSE
control$debugging <- FALSE

source('InitializeR.R')
InitializeR(start.JIT = FALSE,
            duplex.output.to = control$path.log)

# Source other files here, now that the JIT level is set.
source('CompressFile.R')
source('Printf.R')

source('DEEDC.R')
source('LUSEI.R')
source('PRICATCODE.R')
source('PROPN.R')
source('SCODE.R')
source('SLMLT.R')
source('TRNTP.R')


ReadAllTransactions <- function(control) {
    # return everything in the input file
    # ARGS:
    # control : list of control values
    # RETURNS data.frame
    #cat('starting ReadAllTransactions\n'); browser()
    all <- read.csv(control$path.input,
                    check.name=FALSE,
                    header=TRUE,
                    quote='',
                    comment='',
                    stringsAsFactors=FALSE,
                    sep='\t',
                    nrows=ifelse(control$testing, control$testing.nrow, -1)) 
    cat('ending ReadAllTransactions', nrow(all), '\n')# browser()
    all
}

TransactionDate <- function(df) {
    # create transaction.date field (possibly NA)
    # ARGS:
    # df : data.frame with features SALE.DATE and RECORDING.DATE
    # RESULT: vector of transaction dates, some possible NA

    # If SALE.DATE is present and valid, use it for the transaction date.
    # Otherwise use the RECORDING.DATE less then average difference between
    # sale dates and recording dates

    ToDate <- function(v) {
        # Value: vector of adjusted sales dates
        c <- as.character(v)
        c2 <- gsub("00$", "15", c) # move dates like 1991-01-00 to 1991-01-15
        dates <- as.Date(c2, "%Y%m%d")
        dates
    }
    
    # convert dates encoded as character strings to date class objects
    adjusted.sale.date <- ToDate(df$SALE.DATE)
    adjusted.recording.date <- ToDate(df$RECORDING.DATE)
    
    # mean days between known sales dates and their corresponding recording dates
    # NOTE: the recording date is always present
    adjusted.sale.date.present <- !is.na(adjusted.sale.date)
    diff <- adjusted.recording.date[adjusted.sale.date.present] - adjusted.sale.date[adjusted.sale.date.present] 
    mean.diff <- mean(diff)

    transaction.date <- as.Date(ifelse(is.na(adjusted.sale.date),
                                         adjusted.recording.date - mean.diff,
                                         adjusted.sale.date),
                                  origin="1970-01-01")
    transaction.date
}

OkSaleAmount <- function(df) {
    # determine which sale amounts are valid
    # ARGS
    # df : data.fram with feature SALE.AMOUNT
    # RETURNS logical vector, TRUE, for observations with valid sale amounts
    
    # A valid sale amount is positive and less than $85 million
    # $85 million is believed to be the highest price every recorded in Los Angeles
    # for a residential real estate transaction

    (df$SALE.AMOUNT > 0) & (df$SALE.AMOUNT <= 85e6)
}

OkDocumentTypeCode <- function(df) {
    # determine which deed types are valid
    # ARGS:
    # df : data.frame with DOCUMENT.TYPE.CODE field
    # RETURNS: logical vector of observations considered valid

    # Valid codes are for grant deed and trust deeds

    # All codes:
    # Code|Meaning
    # ----|-------
    # C|CONSTRUCTION LOAN
    # CD|CORRECTION DEED
    # F|FINAL JUDGEMENT
    # G|GRANT DEED
    # L|LIS PENDENS - NON CALIFORNIA
    # L|LIENS (STATEWIDE CA)
    # N|NOTICE OF DEFAULT
    # Q|QUIT CLAIM
    # R|RELEASE
    # S|LOAN ASSIGNMENT 
    # T|DEED OF TRUST
    # U|FORECLOSURE
    # X|MULTI CNTY/ST OR OPEN-END MORTGAGE
    # Z|NOMINAL

    dtc <- df$DOCUMENT.TYPE.CODE
    DEEDC(dtc, 'grant.deed') |   # sale or transfer
    DEEDC(dtc, 'deed.of.trust')  # gives mortgage lend a lien on the property
}

OkTransactionTypeCode <- function(df) {
    # determine valid transaction types
    # ARG:
    # df: data.frame containing TRANSACTION.TYPE.CODE field
    # RETURNS logical vector, TRUE, when observation considered valid

    # A valid transaction type is a resale or new construction

    ttc <- df$TRANSACTION.TYPE.CODE

    TRNTP(ttc, 'resale') |
    TRNTP(ttc, 'new.construction')
}

OkSaleCode <- function(df) {
    # determine valid sales code (financial consideration)
    # ARG
    # df : data.frame with feature SALE.CODE
    # RETURNS logical vector, TRUE, if sales code is valid

    SCODE(df$SALE.CODE, 'sale.price.full')
}

IsOneParcel <- function(df) {
    # determine whether sale is for all of one parcel
    # ARGS
    # df : data.frame with features MULTI.APN.FLAG.CODE and MULTI.APN.COUNT
    # RETURNS logical vector TRUE when observation is OK

    is.na(df$MULTI.APN.FLAG.CODE) & df$MULTI.APN.COUNT <= 1
}

IsOneBuilding <- function(df) {
    df$NUMBER.OF.BUILDINGS == 1
}

OkAssessedValue <- function(df) {
    #The value of the property is estimated by the tax assessor. It's broken down into the land 
    #value and the improvement value. 

    # accept zero values and values not exceeding the $85 million max sales price
    not.zero <- (df$TOTAL.VALUE.CALCULATED > 0) & 
        (df$LAND.VALUE.CALCULATED > 0) & 
        (df$IMPROVEMENT.VALUE.CALCULATED > 0)

    max.value <- 85e6
    not.too.large <- df$TOTAL.VALUE.CALCULATED < max.value & 
            df$LAND.VALUE.CALCULATED < max.value & 
            df$IMPROVEMENT.VALUE.CALCULATED < max.value
            
    not.zero & not.too.large
}

PositiveNotHuge <- function(v) {
    # return selector vector for entries in v > 0 and <= 99th percentile of values in v
    q <- quantile(v, probs=seq(.95, 1, .01))
    max <- q[5]
    (v > 0) & (v <= max)
}

OkLandSquareFootage <- function(df) {
    # accept land size with up to 99th percentile
    # some land sizes are huge and some are zero
    PositiveNotHuge(df$LAND.SQUARE.FOOTAGE)
}

OkUniversalBuildingSquareFeet <- function(df) {
    # Some buildings are huge
    # Accept building size up to the 99th percentile
    PositiveNotHuge(df$UNIVERSAL.BUILDING.SQUARE.FEET)
}

OkLivingSquareFeet <- function(df) {
    # accept positive and up to 99th percentile
    PositiveNotHuge(df$LIVING.SQUARE.FEET)
}

OkYearBuilt <- function(df) {
    # accept any positive value
    df$YEAR.BUILT > 0
}

OkEffectiveYearBuilt <- function(df) {
    # accept any positive value
    # NOTE; could make sure effective year built is not before year built
    df$EFFECTIVE.YEAR.BUILT > 0
}

OkTotalRooms <- function(df) {
    # allow 0 bedrooms, 0 bathrooms (could be an outhouse), but require at least one room
    df$TOTAL.ROOMS > 0
}

OkUnitsNumber <- function(df) {
    # require exactly one unit (otherwise, don't know what the features are for)
    df$UNITS.NUMBER == 1
}

OkGeocoding <- function(df) {
    # require both latitude and longitude
    # missing values have a zero
    (df$G.LATITUDE != 0) & (df$G.LONGITUDE != 0)
}

OkRecordingDate <- function(df) {
    # there is a recorded date
    !is.na(df$RECORDING.DATE)
}

FormSubset <- function(df) {
    # form the subset we are interested in
    # ARGS
    # df : data.frame with all rows
    # RETURNS df with additional features and fewer rows

    df$transaction.date <- TransactionDate(df)

    # determine observations to exclude based on values of certain features

    nrow.df <- nrow(df)

    cat('number of observations before checking values', nrow.df, '\n')

    c <- function(name, selector.vector) {
        cat(' field', name, 'excluded', nrow.df - sum(selector.vector), '\n')
        selector.vector
    }

    ok.recording.date <- c('recorded date', OkRecordingDate(df))
    ok.sale.amount <- c('sale amount', OkSaleAmount(df))
    ok.document.type.code <- c('doc type', OkDocumentTypeCode(df))
    ok.transaction.type.code <- c('tran type', OkTransactionTypeCode(df))
    ok.sale.code <- c('sale code', OkSaleCode(df))
    is.one.parcel <- c('one parcel', IsOneParcel(df))
    is.one.building <- c('one building', IsOneBuilding(df))
    ok.assessed.value <- c('assessed value', OkAssessedValue(df))
    ok.land.square.footage <- c('land', OkLandSquareFootage(df))
    ok.universal.building.square.feet <- c('building', OkUniversalBuildingSquareFeet(df))
    ok.living.square.feet <- c('living', OkLivingSquareFeet(df))
    ok.year.built <- c('built', OkYearBuilt(df))
    ok.effective.year.built <- c('effective year', OkEffectiveYearBuilt(df))
    ok.total.rooms <- c('rooms', OkTotalRooms(df))
    ok.units.number <- c('units', OkUnitsNumber(df))
    ok.geocoding <- c('geocoding', OkGeocoding(df))

    # determine all observations excluded
    all.good <- 
        ok.recording.date &
        ok.sale.amount & 
        ok.document.type.code &
        ok.transaction.type.code &
        ok.sale.code &
        is.one.parcel &
        is.one.building &
        ok.assessed.value &
        ok.land.square.footage &
        ok.universal.building.square.feet &
        ok.living.square.feet &
        ok.year.built &
        ok.effective.year.built &
        ok.total.rooms &
        ok.units.number &
        ok.geocoding

    cat(' ALL FIELDS EXCLUDED', nrow.df - sum(all.good), '\n')

    df[all.good, ]
}

WriteControl <- function(control) {
    # write control values
    for (name in names(control)) {
        cat('control ', name, ' = ' , control[[name]], '\n')
    }
}

RecodeRecordingDate <- function(recordingDate) {
    # replace YYYYMM00 with YYYYMM15 where recordingDate is an int
    day <- recordingDate %% 100
    result <- ifelse(day == 0, recordingDate + 15, recordingDate)
    result
}

Main <- function(control) {
    #cat('starting Main\n') ; browser()
    WriteControl(control)

    # read all transactions
    df <- ReadAllTransactions(control)
    cat('all transactions\n')
    str(df)
    print(summary(df))
    cat('read all transactions', nrow(df), '\n')

    # recoded RECORDING.DATE
    df$RECORDING.DATE <- RecodeRecordingDate(df$RECORDING.DATE)

    # form the subset we are interested in
    df <- FormSubset(df)
    cat('subset transactions\n')
    str(df)
    print(summary(df))

    # eliminate duplicate transactions
    num.with.dups = nrow(df)
    df <- unique(df)
    num.dropped = num.with.dups - nrow(df)


    cat('number of duplicate observations eliminated', num.dropped, '\n')
    stopifnot(num.dropped == 0)

    # write the uncompressed result
    write.table(df, 
                file=control$path.output, 
                sep='\t',
                quote=FALSE,
                row.names=FALSE)

    # maybe compress the output
    #cat('maybe compress output', nrow(all$df), '\n'); browser()
    if (control$compress == 'only') {
        CompressFile(old.name = control$path.out,
                     new.name = control$path.out)
    } else if (control$compress == 'also') {
        CompressFile(old.name = control$path.out,
                     new.name = paste0(control$path.out, '.gz'))
    }

    Printf('wrote %d observations\n', nrow(df))
    WriteControl(control)
}

Main(control)
cat('done\n')
