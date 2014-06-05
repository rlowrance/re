# assessor-assessment.R
# assess accuracy of tax assessor's valuations.
# 
# Approach
# 1. Read taxroll for 2008.
# 2. Read parcels. Retain 2008 and 2009 sales. Retain arms-length transactions.
# 3. Determine mean error and std. dev for errors for
#    - sales in 2008 and 2009
#    - by zip code
#    - by town
#    - by assesses vale

control <- list()
control$me <- 'assessor-assessment'
control$output.dir <- '../data/v6/output/'
control$testing <- TRUE
control$testing <- FALSE


source('InitializeR.R')
InitializeR(duplex.output.to=paste0(control$output.dir, control$me, '.txt'))

source('BestApns.R')
source('Printf.R')
source('ReadCaseShiller.R')
source('ReadDeedsFile.R')
source('ReadParcelsFile.R')
source('SplitDate.R')

CreateApnRecoded <- function(df) {
    # replace APN.UNFORMATTED and APN.FORMATTED with apn.recoded,
    # which is the best of the two in-file APNs

    df$apn.recoded = BestApns(apns.unformatted = df$APN.UNFORMATTED,
                              apns.formatted = df$APN.FORMATTED)
    df$APN.UNFORMATTED <- NULL
    df$APN.FORMATTED <- NULL
    df
}

ReadAllDeeds <- function(control) {
    # Create data.frame with all arms-length deeds in 2008 and 2009
    SelectFields <- function(df) {
        #cat('starting SelectFields\n'); browser()
        data.frame(stringsAsFactors = FALSE,
                   APN.UNFORMATTED = df$APN.UNFORMATTED,
                   APN.FORMATTED = df$APN.FORMATTED,
                   SALE.CODE = df$SALE.CODE,
                   SALE.AMOUNT = df$SALE.AMOUNT,
                   SALE.DATE = df$SALE.DATE,
                   PRI.CAT.CODE = df$PRI.CAT.CODE)
    }

    SelectRecords <- function(df) {
        # select arms-length deeds for full parcels with sale date >= 2008
        arms.length <- df$PRI.CAT.CODE == 'A'  # just arms-length deeds
        full.parcel <- df$SALE.CODE == 'F'     # full sale
        af <- df[arms.length & full.parcel, ]
        #cat('in SelectRecords\n'); browser()

        # work on dates, now that there are no NA dates
        ok.date <- (round(af$SALE.DATE / 10000) >= 2008) & (!is.na(af$SALE.DATE))

        cat('number of good dates', sum(ok.date), '\n')
        result <- af[ok.date, ]
        result
    }

    df <- NULL
    for (num in 1:8) {
        cat('reading deeds file', num, '\n')
        nrow <- ifelse(control$testing, 800000, -1)
        file <- 
            SelectRecords(SelectFields(ReadDeedsFile(num = num, 
                                                     nrow = nrow)))
        

        #str(file)

        # accumulate output
        df <- rbind(df, file)
        if (control$testing) {
            break
        }
    }
    cat('total number of deeds retained', nrow(df), '\n')
    CreateApnRecoded(df)
}

ReadAllParcels <- function(control) {
    SelectFields <- function(df) {
        cat('starting SelectFields', nrow(df), '\n')
        data.frame(stringsAsFactors = FALSE,
                   APN.UNFORMATTED = df$APN.UNFORMATTED,
                   APN.FORMATTED = df$APN.FORMATTED,
                   UNIVERSAL.LAND.USE.CODE = df$UNIVERSAL.LAND.USE.CODE, # SFR == 163
                   PROPERTY.CITY = df$PROPERTY.CITY,
                   PROPERTY.ZIPCODE = df$PROPERTY.ZIPCODE,
                   TOTAL.VALUE.CALCULATED = df$TOTAL.VALUE.CALCULATED,
                   TAX.AMOUNT = df$TAX.AMOUNT,
                   TAX.YEAR = df$TAX.YEAR,
                   YEAR.BUILT = df$YEAR.BUILT,
                   EFFECTIVE.YEAR.BUILT = df$EFFECTIVE.YEAR.BUILT
                   )
    }

    SelectRecords <- function(df) {
        # keep parcels only with a value
        has.value = df$TOTAL.VALUE.CALCULATED > 0
        cat('number of records with zero assessed values', nrow(df) - sum(has.value), '\n')
        df[has.value, ]
    }

    cat('starting ReadAllParcels\n')
    df <- NULL
    for (num in 1:8) {
        cat('reading parcels file', num, '\n')
        nrow = ifelse(control$testing, 1000, -1)
        file <- 
            SelectRecords(SelectFields(ReadParcelsFile(num, nrow)))
        df <- rbind(df, file)
    }
    cat('total number of parcels retained', nrow(df), '\n')
    CreateApnRecoded(df)
}

AnalyzeError <- function(transactions) {
    # determine error vs. tax roll
    excess <- transactions$SALE.AMOUNT - transactions$TOTAL.VALUE.CALCULATED
    relative.excess <- excess / transactions$SALE.AMOUNT
    within.10 <- abs(relative.excess) <= .10
    fraction.within.10 <- sum(within.10) / nrow(transactions)
    stopifnot(sum(is.na(excess)) == 0)
    list(excess.mean = mean(excess),
         excess.sd = sd(excess),
         excess.median = median(excess),
         fraction.within.10 = fraction.within.10)
}

AnalyzeYear <- function(year, transactions) {
    selected.year = transactions$sale.year == year
    subset <- transactions[selected.year, ]
    result <- AnalyzeError(subset)
    Printf('for year %d,          N %5d excess.median %7.0f excess.mean %7.0f excess.sd %7.0f within.10 %4.2f\n',
           year, nrow(subset), 
           result$excess.median, result$excess.mean, result$excess.sd, result$fraction.within.10)
}

AnalyzeMonth <- function(year, month, transactions) {
    selected.year = transactions$sale.year == year
    selected.month = transactions$sale.month == month

    subset <- transactions[selected.year & selected.month, ]
    result <- AnalyzeError(subset)
    Printf('for year %d month %2d, N %5d excess.median %7.0f excess.mean %7.0f excess.sd %7.0f within.10 %4.2f\n',
           year, month, nrow(subset), 
           result$excess.median, result$excess.mean, result$excess.sd, result$fraction.within.10)
}

Model <- function(year, transactions) {
    selected.year = transactions$sale.year == year
    for.year <- transactions[selected.year, ]
    price <- for.year$SALE.AMOUNT
    excess <- price - for.year$TOTAL.VALUE.CALCULATED

    # use any intercept
    cat('\nAllow any intercept\n')
    fitted <- lm(price ~ TOTAL.VALUE.CALCULATED, for.year)
    cat('Model', year, '\n')
    print(summary(fitted))

    # force zero intercept
    cat('\nForce zero intercept\n')
    fitted <- lm(price ~ TOTAL.VALUE.CALCULATED + 0, for.year)
    cat('Model', year, '\n')
    print(summary(fitted))
}

PriceYearMonth <- function(year, month, transactions) {
    # return vector of transaction prices for specified year and month
    selected.year = transactions$sale.year == year
    selected.month = transactions$sale.month == month
    transactions[selected.year & selected.month, 'SALE.AMOUNT']
}

Excess <- function(df) {
    # return vector of excess values (price - assessed value)
    df$SALE.AMOUNT - df$TOTAL.VALUE.CALCULATED
}

SelectYear <- function(df, year) {
    # return data.frame containing transactions only in selected year
    df[df$sale.year == year, ]
}

CitiesForZip5 <- function(df, zip5) {
    # return vector of cities with the zip5
    df <- df[df$zip5 == zip5, ]
    cities <- unique(df[, 'PROPERTY.CITY'])
    cities
}

Preface <- function(question, analysis.title) {
    cat('\n****************************\n')
    cat('question:', question, '\n')
    cat(analysis.title, '\n')
    cat('\n')
}


AccuracyByZipcode <- function(control, transactions) {
    Preface('To what extent are assessments biased in favor of certain zip codes?',
            'Relative excess by zip code\n')
    cat('Definitions\n')
    cat(' excess := (price - assessed value)\n')
    cat(' relative excess := excess / assessed value\n')
    cat('\n')

    # Are some zip codes more favorably assessed
    subset <- transactions[!is.na(transactions$PROPERTY.ZIPCODE), ] #screen out missing zipcodes
    subset$zip5 <- round(subset$PROPERTY.ZIPCODE / 10000)
    subset <- subset[subset$zip5 >= 90000, ] # screen out small (invalid) zip5's
    zip5 <- unique(subset$zip5)
    
    MedianExcess2008 <- function(zip5) {
        # print median relative excess
        df <- SelectYear(subset[subset$zip5 == zip5,], 2008)
        if (nrow(df) == 0)
            return(0)
        relative.excess <- Excess(df) / df$TOTAL.VALUE.CALCULATED
        median.excess <- median(relative.excess)
        mean.excess <- mean(relative.excess)
        if (is.na(median.excess)) browser()

        Print <- function() {
            cities <- CitiesForZip5(subset, zip5)
            N <- length(relative.excess)
            switch(length(cities),
                   Printf('zip5 %5d N %4d median relative excess %5.2f mean relative excess %5.2f %s\n', 
                          zip5, N, median.excess, mean.excess, cities[[1]]),
                   Printf('zip5 %5d N %4d median relative excess %5.2f mean relative excess %5.2f %s, %s\n', 
                          zip5, N, median.excess, mean.excess, cities[[1]], cities[[2]])
                   )
        }

        Print()
        median.excess
    }

    cat('all zip codes\n')
    errors <- vapply(zip5, MedianExcess2008, 0)
    sorted <- sort(errors, index.return = TRUE)
    sorted.values <- sorted$x
    sorted.indices <- sorted$ix
    zero.values <- sorted.values != 0
    sorted.zip5 <- zip5[sorted.indices[sorted.values != 0]]

    cat('\nonly zip codes with non-zero median relative excess; sorted\n')
    vapply(sorted.zip5, MedianExcess2008, 0)
    
    cat('\nDescriptions of selected zip codes\n')
    cat(' ', '90014', 'downtown near skid row\n')
    cat(' ', '90210', 'Beverly Hills including Rodeo Drive shopping district\n')
    cat(' ', '90271', 'Maywood\n')
    cat(' ', '91709', 'also partly in San Bernardino County\n')
}


MedianPrice <- function(year, month, transactions) {
    median(PriceYearMonth(year, month, transactions))
}

MedianPricesToCSIndex <- function(control, transactions) {
    Preface('How well did after-the-fact CS track actual median prices in LA?',
            'Median prices indices relative to Case-Shiller indices')
    RetrieveCaseShiller <- ReadCaseShiller('LosAngeles')$Retrieve
    base.cs <- RetrieveCaseShiller(2008, 1)
    base.median <- MedianPrice(2008, 1, transactions)

    cs.indices <- c()
    median.indices <- c()

    for (year in 2008:2009) {
        for (month in 1:12) {
            if (year == 2009 & month == 12) break
            new.cs <- RetrieveCaseShiller(year, month)
            new.median <- MedianPrice(year, month, transactions)

            cs.index <- (100 * new.cs / base.cs)
            median.index <- (100 * new.median) / base.median

            cs.indices <- c(cs.indices, cs.index)
            median.indices <- c(median.indices, median.index)

            Printf('year %4d month %2d median price %7.0f (%3d) cs index %4.1f (%3d)\n',
                   year, month, 
                   new.median, round(median.index), 
                   new.cs, round(cs.index))
        }
    }
    median.indices.lower <- median.indices < cs.indices
    cat('\nmedian price index as fraction of median cs index', 
        sum(median.indices.lower) / length(median.indices.lower), '\n')
}

PriceTrendsByMonth <- function(control, transactions) {
    Preface('What happened to prices in LA',
            'Average prices and standard deviations by month')
    median.prices <- c()
    for (year in 2008:2009) {
        for (month in 1:12) {
            price <- PriceYearMonth(year, month, transactions)
            median.prices <- c(median.prices, median(price))
            Printf('for year %d month %2d, N %5d median = %7.0f mean = %7.0f sd = %7.0f\n',
                   year, month, length(price), median(price), mean(price), sd(price))
        }
    }
    good.medians <- na.omit(median.prices)
    n <- length(good.medians)
    lagged.ratio <- good.medians[2:n] / good.medians[1 : (n-1)]
    Printf('\nmedian prices declined in %d of %d months\n', sum(lagged.ratio < 1), length(good.medians))

}

PriceVsAssessedValue <- function(control, transactions) {
    Preface('How well are prices modeled as a linear function of assessed value',
            'price ~ assessed.value [+ 0], for all transactions in 2008')
    Model(2008, transactions)
}

AccuracyForYearAndMonth <- function(control, transactions) {
    Preface('How accurate were assessment on average for a year and by month',
            'Excess by year and by month')
    cat('\nExcess for year\n')
    AnalyzeYear(2008, transactions)
    AnalyzeYear(2009, transactions)

    cat('\nExcess for month\n')
    for (year in 2008:2009) {
        for (month in 1:12) {
            AnalyzeMonth(year, month, transactions)
        }
    }
}

Main <- function(control, transactions) {
    cat('starting Main\n')

    if (TRUE) AccuracyForYearAndMonth(control, transactions)
    if (TRUE) MedianPricesToCSIndex(control, transactions)
    if (TRUE) PriceTrendsByMonth(control, transactions)
    if (TRUE) AccuracyByZipcode(control, transactions)
    # MAYBE: accuracy by city
    if (TRUE) PriceVsAssessedValue(control, transactions)

    #cat('in Main\n'): browser()

    
    
}

force.read.deeds <- FALSE
#force.read.deeds <- TRUE
if (force.read.deeds || !exists('deeds.dataframe')) {
    deeds.dataframe <- ReadAllDeeds(control)
}

force.read.taxroll <- FALSE
#force.read.taxroll <- TRUE
if (force.read.taxroll || !exists('taxroll.dataframe')) {
    taxroll.dataframe <- ReadAllParcels(control)
}

force.transactions <- FALSE
force.transactions <- TRUE
if (force.transactions || !exits('transactions.dataframe')) {
    # drop unneeded fields
    str(deeds.dataframe)
    deeds.dataframe$SALE.CODE <- NULL
    deeds.dataframe$PRI.CAT.CODE <- NULL
    transactions.dataframe <- merge(x = deeds.dataframe, by.x = 'apn.recoded',
                                    y = taxroll.dataframe, by.y = 'apn.recoded')
    # remove redundant and unneeded fields
    # add fields
    sale.date <- transactions.dataframe$SALE.DATE
    sale.year <- round(sale.date / 10000)
    sale.month <- round((sale.date - 10000 * sale.year) / 100)
    stopifnot(sum(is.na(sale.year)) == 0)
    transactions.dataframe$sale.year <- sale.year
    transactions.dataframe$sale.month <- sale.month

    cat('transactions.dataframe fields\n')
    str(transactions.dataframe)
}


cat('nrow deeds', nrow(deeds.dataframe), '\n')
cat('nrow taxroll', nrow(taxroll.dataframe), '\n')
cat('nrow transactions', nrow(transactions.dataframe), '\n')

Main(control, transactions.dataframe)

if (control$testing) {
    cat('\n********************** TESTING: DISCARD OUTPUT ***************************\n')
}

cat('done\n')


