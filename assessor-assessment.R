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
control$path.subset1 <- paste0(control$output.dir,
                               'transactions-subset1.csv.gz')
control$path.taxroll <- paste0(control$output.dir,
                               'parcels-sfr.csv.gz')
control$do.analyze.parcels <- TRUE
control$do.analyze.transactions <- TRUE
control$testing <- TRUE
control$testing <- FALSE


source('InitializeR.R')
InitializeR(duplex.output.to=paste0(control$output.dir, control$me, '.txt'))

source('BestApns.R')
source('DEEDC.R')
source('Printf.R')
source('PROPN.R')
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
    # File layout is 1080
    SelectFields <- function(df) {
        # retain most fields in order to diagnose no-excess problem
        #cat('starting SelectFields\n'); browser()
        result <- 
            data.frame(stringsAsFactors = FALSE,

                   apn.recoded = BestApns(apns.unformatted = df$APN.UNFORMATTED,
                                          apns.formatted = df$APN.FORMATTED),

                   SALE.AMOUNT = df$SALE.AMOUNT,
                   MORTGAGE.AMOUNT = df$MORTGAGE.AMOUNT,
                   
                   SALE.DATE = df$SALE.DATE,  # often missing
                   RECORDING.DATE = df$RECORDING.DATE,
                   DOCUMENT.YEAR = df$DOCUMENT.YEAR,

                   MULTI.APN.COUNT = df$MULTI.APN.COUNT,
                   DOCUMENT.TYPE.CODE = df$DOCUMENT.TYPE.CODE,
                   TRANSACTION.TYPE.CODE = df$TRANSACTION.TYPE.CODE,
                   SALE.CODE = df$SALE.CODE,   # F ==> full sale
                   PRI.CAT.CODE = df$PRI.CAT.CODE  # A ==> arms length
                   )
        result
    }

    SelectRecords <- function(df) {
        # select arms-length deeds for full parcels with sale date >= 2006
        if (FALSE) {
            # select just arms-length and full sale deeds for 2008 and later 
            arms.length <- df$PRI.CAT.CODE == 'A'  # just arms-length deeds
            full.parcel <- df$SALE.CODE == 'F'     # full sale
            af <- df[arms.length & full.parcel, ]
            #cat('in SelectRecords\n'); browser()

            # work on dates, now that there are no NA dates
            ok.date <- (round(af$SALE.DATE / 10000) >= 2006) & (!is.na(af$SALE.DATE))

            cat('number of good dates', sum(ok.date), '\n')
            result <- af[ok.date, ]
            result
        }

        if (TRUE) {
            # select all dates recorded in 2006 or later
            nice.year <- df$DOCUMENT.YEAR >= 2006
            result <- df[nice.year, ]
            cat('number of deeds recorded in 2006 or later', nrow(result), '\n')
            result
        }
    }


    df <- NULL
    for (num in 1:8) {
        cat('reading deeds file', num, '\n')
        nrow <- ifelse(control$testing, 800000, -1)
        nrow <- 1000
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
    df
}

ReadAllParcels <- function(path) {
    SelectFields <- function(df) {
        cat('starting SelectFields', nrow(df), '\n')
        #print(names(df[,1:ncol(df)]))
        result <-
            data.frame(stringsAsFactors = FALSE,
                   
                       # parcel identification
                       apn.recoded = BestApns(apns.unformatted = df$APN.UNFORMATTED,
                                              apns.formatted = df$APN.FORMATTED),

                       # parcel information
                       CENSUS.TRACT = df$CENSUS.TRACT,
                       ZONING = df$ZONING,
                       UNIVERSAL.LAND.USE.CODE = df$UNIVERSAL.LAND.USE,
                       PROPERTY.INDICATOR.CODE = df$PROPERTY.INDICATOR.CODE,
                       LOCATION.INFLUENCE.CODE = df$LOCATION.INFLUENCE.CODE,

                       # property address information
                       PROPERTY.ZIPCODE = df$PROPERTY.ZIPCODE,

                       # values information
                       TOTAL.VALUE.CALCULATED = df$TOTAL.VALUE.CALCULATED,
                       LAND.VALUE.CALCULATED = df$LAND.VALUE.CALCULATED,
                       IMPROVEMENT.VALUE.CALCULATED = df$IMPROVEMENT.VALUE.CALCULATED,

                       TOTAL.VALUE.CALCULATED.INDICATOR.FLAG = df$TOTAL.VALUE.CALCULATED.INDICATOR.FLAG,
                       LAND.VALUE.CALCULATED.INDICATOR.FLAG = df$LAND.VALUE.CALCULATED.INDICATOR.FLAG,
                       IMPROVEMENT.VALUE.CALCULATED.INDICATOR.FLAG = df$IMPROVEMENT.VALUE.CALCULATED.INDICATOR.FLAG,
                       
                       ASSD.TOTAL.VALUE = df$ASSD.TOTAL.VALUE,
                       ASSD.LAND.VALUE = df$ASSD.LAND.VALUE,
                       ASSD.IMPROVEMENT.VALUE = df$ASSD.IMPROVEMENT.VALUE,

                       MKT.TOTAL.VALUE = df$MKT.TOTAL.VALUE,
                       MKT.LAND.VALUE = df$MKT.LAND.VALUE,
                       MKT.IMPROVEMENT.VALUE = df$MKT.IMPROVEMENT.VALUE,

                       APPR.TOTAL.VALUE = df$APPR.TOTAL.VALUE,
                       APPR.LAND.VALUE = df$APPR.LAND.VALUE,
                       APPR.IMPROVEMENT.VALUE = df$APPR.IMPROVEMENT.VALUE,

                       TAX.YEAR = df$TAX.YEAR,

                       # current sale informatoin
                       DOCUMENT.YEAR = df$DOCUMENT.YEAR,
                       SALES.DOCUMENT.TYPE.CODE = df$SALES.DOCUMENT.TYPE.CODE,
                       RECORDING.DATE = df$RECORDING.DATE,
                       SALE.DATE = df$SALE.DATE,
                       SALE.AMOUNT = df$SALE.AMOUNT,
                       SALE.CODE = df$SALE.CODE,
                       SALES.TRANSACTION.TYPE.CODE = df$SALES.TRANSACTION.TYPE.CODE,
                       MULTI.APN.COUNT = df$MULTI.APN.COUNT,
                       RESIDENTIAL.MODEL.INDICATOR.FLAG = df$RESIDENTIAL.MODEL.INDICATOR.FLAG,

                       # current trust deed information
                       X1ST.MORTGAGE.AMOUNT = df$X1ST.MORTGAGE.AMOUNT,
                       X1ST.MORTGAGE.DATE = df$X1ST.MORTGAGE.DATE,
                       X1ST.MORTGAGE.LOAN.TYPE.CODE = df$X1ST.MORTGAGE.LOAN.TYPE.CODE,
                       X1ST.MORTGAGE.DEED.TYPE.CODE = df$X1ST.MORTGAGE.DEED.TYPE.CODE,

                       X2ND.MORTGAGE.AMOUNT = df$X2ND.MORTGAGE.AMOUNT,
                       X2ND.MORTGAGE.LOAN.TYPE.CODE = df$X2ND.MORTGAGE.LOAN.TYPE.CODE,
                       X2ND.DEED.TYPE.CODE = df$X2ND.DEED.TYPE.CODE,

                       # prior sale information
                       PRIOR.SALE.DOCUMENT.YEAR = df$PRIOR.SALE.DOCUMENT.YEAR,
                       PRIOR.SALE.RECORDING.DATE = df$PRIOR.SALE.RECORDING.DATE,
                       PRIOR.SALE.DATE = df$PRIOR.SALE.DATE,
                       PRIOR.SALE.AMOUNT = df$PRIOR.SALE.AMOUNT,
                       PRIOR.SALE.CODE = df$PRIOR.SALE.CODE,
                       PRIOR.SALE.TRANSACTION.TYPE.CODE = df$PRIOR.SALE.TRANSACTION.TYPE.CODE,
                       PRIOR.SALE.MULTI.APN.COUNT = df$PRIOR.SALE.MULTI.APN.COUNT

                       # many parcel description fields are also available
                       )
        result
    }

    SelectFieldsOLD <- function(control) {
        result <-
            data.frame(
                       UNIVERSAL.LAND.USE.CODE = df$UNIVERSAL.LAND.USE.CODE, # SFR == 163

                       PROPERTY.CITY = df$PROPERTY.CITY,
                       PROPERTY.ZIPCODE = df$PROPERTY.ZIPCODE,
                       TAX.AMOUNT = df$TAX.AMOUNT,
                       TAX.YEAR = df$TAX.YEAR,
                       YEAR.BUILT = df$YEAR.BUILT,
                       EFFECTIVE.YEAR.BUILT = df$EFFECTIVE.YEAR.BUILT
                       )
        result
    }

    SelectRecords <- function(df) {
        # keep parcels only for tax year 2008
        # keep parcels only with a value
        if (FALSE) {
            # old version
            has.value = df$TOTAL.VALUE.CALCULATED > 0
            cat('number of records with zero assessed values', nrow(df) - sum(has.value), '\n')
            df[has.value, ]
        }
        if (TRUE) {
            tax.year.2008 = df$TAX.YEAR == 2008
            # return all records
            result <- df[tax.year.2008, ]
            result
        }
    }

    cat('starting ReadAllParcels\n')
    df <- NULL
    for (num in 1:8) {
        cat('reading parcels file', num, path, '\n')
        nrow = ifelse(control$testing, 1000, -1)
        file <- 
            SelectRecords(SelectFields(ReadParcelsFile(num, nrow, path = path)))
        df <- rbind(df, file)
    }
    cat('total number of parcels retained', nrow(df), '\n')
    #browser()
    df
}

ReadAllTransactions <- function(control) {
    # return transactions with known sale date in 2006 or later and certain features
    cat('starting ReadAllTransactions\n')
    control$testing <- FALSE
    all.transactions <- read.csv(control$path.subset1,
                                 quote = '',
                                 sep = '\t',
                                 nrow = ifelse(control$testing, 200000, -1)
                                 )
    #cat('finished reading transactions.dataframe\n'); browser()
    stopifnot(all(all.transactions$TAX.YEAR == 2008))

    # create subset with known dates
    has.sale.date <- !is.na(all.transactions$SALE.DATE)
    valid <- all.transactions[has.sale.date, ]
    splitDate <- SplitDate(valid$SALE.DATE, format = 'YYYYMMDD')
    valid$sale.year <- splitDate$year
    valid$sale.month <- splitDate$month

    # select just certain fields and sale dates >= 2006
    result <- subset(valid,
                     subset = valid$sale.year >= 2006,
                     select = c(apn.recoded,
                                PROPERTY.CITY, PROPERTY.ZIPCODE,
                                sale.year, sale.month, 
                                SALE.AMOUNT,
                                MORTGAGE.AMOUNT, X2ND.MORTGAGE.AMOUNT,
                                MORTGAGE.DATE,  # 2nd mortgage date is not available
                                TOTAL.VALUE.CALCULATED)
                     )
    #cat('ending ReadAllTransactions', nrow(result), '\n'); browser()
    result
}

AnalyzeError <- function(transactions) {
    #cat('starting AnalyzeError', nrow(transactions), '\n'); browser()
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
    #cat('starting AnalyzeYear', year, '\n')
    #if (year == 2008) browser()
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
    #if (year == 2008 & month == 6) browser()
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
    for (year in 2006:2009) {
        Printf('\n')
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

DistributionOfExcess <- function(control, transactions) {
    Preface('What is the distribution of the excess (price - assessed value) in Jan 2008?',
            'Distribution(excess)')

    period.selector <- transactions$sale.year == 2008 & transactions$sale.month == 1

    price <- transactions$SALE.AMOUNT[period.selector]
    assessment <- transactions$TOTAL.VALUE.CALCULATED[period.selector]
    excess <- price - assessment
    relative.excess <- excess / assessment
    abs.relative.excess <- abs(relative.excess)

    cat('summary(excess)\n')
    print(summary(excess))

    FractionWithin <- function(x) {
        # fraction within x% 
        is.within <- abs.relative.excess <= x
        sum(is.within) / length(abs.relative.excess)
    }

    PrintFractionWithin <- function(x) {
        Printf('fraction within %4.2f percent = %4.2f\n', x, FractionWithin(x))
    }

    for (wi in c(0, .10, .20, .30, .40, .50)) {
        PrintFractionWithin(wi)
    }
}

AccuracyForYearAndMonth <- function(control, transactions) {
    Preface('How accurate were assessment on average for a year and by month',
            'Excess by year and by month')

    cat('\nExcess for year\n')
    AnalyzeYear(2006, transactions)
    AnalyzeYear(2007, transactions)
    AnalyzeYear(2008, transactions)
    AnalyzeYear(2009, transactions)

    cat('\nExcess for month\n')
    for (year in 2006:2009) {
        for (month in 1:12) {
            AnalyzeMonth(year, month, transactions)
        }
        Printf('\n')
    }
}

AnalyzeSecondMortgage <- function(control, transactions) {


}

AnalyzeZeroExcess <- function(control, transactions) {
    Preface('Are transactions with negative and zero excess more likely to have mortgages?',
            'Pr(has mortgage | excess)')
    #cat('starting AnalyzeZeroExcess', nrow(transactions), '\n'); browser()
    
    Period <- function(period.year, period.month) {
        # pr(has 1st mortgage | (excess status & in selected period))
        period.selector <- transactions$sale.year == period.year & transactions$sale.month == period.month
        t <- transactions[period.selector, ]

        t$has.1st.mortgage <- t$MORTGAGE.AMOUNT > 0
        t$total.mortgage <- t$MORTGAGE.AMOUNT + ifelse(is.na(t$X2ND.MORTGAGE.AMOUNT), 0, t$X2ND.MORTGAGE.AMOUNT)

        t$excess <- t$SALE.AMOUNT - t$TOTAL.VALUE.CALCULATED
        excess.is.zero <- t$excess == 0
        excess.is.positive <- t$excess > 0
        excess.is.negative <- t$excess < 0

        n <- nrow(t)

        show.distribution <- FALSE
        if (show.distribution) {
            Printf('Have %d transactions in tax year 2008\n', n)

            cat('\nDistribution of has excess\n')
            Printf('Pr(excess == 0) = %f\n', sum(excess.is.zero) / n)
            Printf('Pr(excess > 0)  = %f\n', sum(excess.is.positive) / n)
            Printf('Pr(excess < 0)  = %f\n', sum(excess.is.negative) / n)
        }


        FractionWithMortgage <- function(name) {
            # return fraction of selected transactions that have a mortgage
            selector <- switch(name,
                               negative.or.zero = excess.is.negative | excess.is.zero,
                               negative = excess.is.negative,
                               zero = excess.is.zero,
                               positive = excess.is.positive)
            relevant.1st.mortgage <- t[selector, 'MORTGAGE.AMOUNT']
            has.1st.mortgage <- relevant.1st.mortgage > 0
            n <- length(has.1st.mortgage)
            result <- sum(has.1st.mortgage) / n
            Printf('Pr(has 1st mortgage | excess %17s & year = %d & month = %d) =  %5.3f (N = %4d)\n',
                   name,
                   period.year,
                   period.month,
                   result,
                   n)
            result
        }

        cat('\n')
        fraction.if.negative <- FractionWithMortgage('negative')
        fraction.if.zero <- FractionWithMortgage('zero')
        fraction.if.positive <- FractionWithMortgage('positive')
        fraction.if.negative.or.zero <- FractionWithMortgage('negative.or.zero')

        result1 <- (fraction.if.zero >= fraction.if.negative) & (fraction.if.zero >= fraction.if.positive)
        if (result1) {
            cat('zero excess more likely to have mortgage\n')
        }

        result <- fraction.if.negative.or.zero > fraction.if.positive
        if (result) {
            cat('supports hypothesis (more like to have mortgage if excess <= 0)\n')
        }
        result
    }

    #for (month in 1:12) Period(2007, month)
    for (month in 1:12) Period(2008, month)
    #for (month in 1:11) Period(2009, month)

    
}

Summarize <- function(name, value) {
    Printf('%25s min %10.0f median %10.0f mean %10.0f max %11.0f nzero %7.0f\n',
           name, 
           min(value), median(value), mean(value), max(value), 
           sum(value == 0))
}


AnalyzeTaxrollValid <- function(df) {
    # df restricted to grant deeds in 2006 or later with positive prices
    cat('starting AnalyzeTaxrollValid', nrow(df), '\n')
    browser()

    cat('number of valid taxroll records', nrow(df), '\n')
    Summarize('RECORDING.DATE', df$RECORDING.DATE)
    Summarize('ASSD.TOTAL.VALUE', df$ASSD.TOTAL.VALUE)
    Summarize('SALE.AMOUNT', df$SALE.AMOUNT)

    excess <- df$SALE.AMOUNT - df$ASSD.TOTAL.VALUE
    Summarize('excess', excess)
    browser()

    for (year in 2006:2009) {
        for (month in 1:12) {
            AnalyzeMonth(year, month, df)
        }
    }
    browser()


    cat('ending AnalyzeTaxrollValid\n')
}

AnalyzeTaxroll <- function(df) {
    # figure out why so many transactions in 2008 sale price = total assessed value
    # file layout is 2580
    cat('starting AnalyzeTaxroll', nrow(df), '\n'); browser()
    stopifnot(all(df$TAX.YEAR == 2008))
    
    cat('number of taxroll records', nrow(df), '\n')
    Summarize('RECORDING.DATE', df$RECORDING.DATE)
    Summarize('ASSD.TOTAL.VALUE', df$ASSD.TOTAL.VALUE)
    Summarize('SALE.AMOUNT', df$SALE.AMOUNT)
    #Summarize('SALE.DATE', df$SALE.DATE)
    #Summarize('SALE.AMOUNT', df$SALE.AMOUNT)
    #Summarize('PRIOR.SALE.RECORDING.DATE', df$PRIOR.SALE.RECORDING.DATE)
    #Summarize('PRIOR.SALE.DATE', df$PRIOR.SALE.DATE)

    splitDate <- SplitDate(df$RECORDING.DATE, format = 'YYYYMMDD')
    sale.year <- splitDate$year
    sale.month <- splitDate$month
    is.good.year <- sale.year >= 2006

    is.good.total.value <- df$TOTAL.VALUE.CALCULATED > 0
    
    is.good.sale.amount <- df$SALE.AMOUNT > 0

    is.grant.deed <- DEEDC(df$SALES.DOCUMENT.TYPE.CODE, 'grant.deed')

    is.sfr <- PROPN(df$PROPERTY.INDICATOR.CODE, 'single.family.residence')

    cat('number with year >= 2006         ', sum(is.good.year), '\n')
    cat('number with non-zero assessments ', sum(is.good.total.value), '\n')
    cat('number of grant deeds            ', sum(is.grant.deed), '\n')
    cat('number of non-zero prices        ', sum(is.good.sale.amount), '\n')
    cat('number of single family residence', sum(is.sfr), '\n')
    # NOTE: Would be ideal to analyze only arms-length deeds (using the PRICATCODE field)
    # However, that information is not in the taxroll files (its only in the deeds file)

    to.analyze <- 
        is.good.year & is.good.total.value & is.grant.deed & is.good.sale.amount & is.sfr
    cat('number of sales to analyze       ', sum(to.analyze), '\n')

    # add transaction date fields
    df$sale.year <- sale.year
    df$sale.month <- sale.month

    AnalyzeTaxrollValid(df[to.analyze,])


    cat('ending AnalyzeTaxroll\n'); browser()
}

Main <- function(control, transactions) {
    cat('starting Main', nrow(transactions), '\n')

    if (TRUE) DistributionOfExcess(control, transactions)
    if (TRUE) PriceTrendsByMonth(control, transactions)

    if (TRUE) AccuracyForYearAndMonth(control, transactions)
    if (TRUE) AnalyzeZeroExcess(control, transactions)
    #cat('find error in median (why zero for 2008?) \n') ; browser()
    if (FALSE) MedianPricesToCSIndex(control, transactions)
    if (FALSE) AccuracyByZipcode(control, transactions)
    # MAYBE: accuracy by city
    if (FALSE) PriceVsAssessedValue(control, transactions)

    #cat('in Main\n'): browser()
}

if (FALSE) {
    # reconstruct transactions files
    force.read.deeds <- FALSE
    #force.read.deeds <- TRUE
    if (FALSE & force.read.deeds || !exists('deeds.dataframe')) {
        deeds.dataframe <- ReadAllDeeds(control)
    }

    force.read.taxroll <- FALSE
    force.read.taxroll <- TRUE
    if (force.read.taxroll || !exists('taxroll.dataframe')) {
        taxroll.dataframe <- ReadAllParcels(control$path.taxroll)
    }
    AnalyzeTaxroll(taxroll.dataframe)

    force.transactions <- FALSE
    #force.transactions <- TRUE
    if (FALSE & force.transactions || !exists('transactions.dataframe')) {
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
} 

if (TRUE) {
    # use the existing transactions file
    force.read.transactions <- FALSE
    #force.read.transactions <- TRUE
    if (force.read.transactions || !exists('transactions.dataframe')) {
        transactions.dataframe <- ReadAllTransactions(control)
    }
}


Main(control, transactions.dataframe)

if (control$testing) {
    cat('\n********************** TESTING: DISCARD OUTPUT ***************************\n')
}

cat('done\n')


