# e-assessment-attractor.R
# main program to produce file OUTPUT/e-assessment-attractor.rsave
# issue explored: Does the assessment act as an attractor for prices
# main program to produce file OUTPUT/e-avm-variants-loglevel10.rsave
# Approach: ???


# specify input files, which are splits of OUTPUT/transactions-subset
# The splits are makefile dependencies
split.names <- list( 'apn'
                    ,'fraction.improvement.value'
                    ,'improvement.value'
                    ,'land.value'
                    ,'price'
                    ,'saleDate'
                    ,'sale.month'
                    ,'sale.year'
                    ,'recordingDate'
                    )

library(devtools)
load_all('../../lowranceutilitiesr')
load_all('../../lowrancerealestater')

library(ggplot2)

source('BestApns.R')
source('DEEDC.R')
source('SCODE.R')
source('TRNTP.R')

PrintHistograms <- function(data) {
    # histogram : distribution of errors
    g.errors <- 
        ggplot(data[data$abs.error < 100000,], aes(x = error)) + 
        geom_histogram(binwidth = 10000)
    print(g.errors)

    # histogram : distribution of prices for errors = 0
    g.prices.error.0 <- 
        ggplot(data[data$error == 0 & data$price < 1000000,], aes(x = price)) + 
        geom_histogram(binwidth = 10000)
    print(g.prices.error.0)
 }

BuildDataframeByRow1 <- function(Row, list1) {
    # return data.frame by applying f to each pairwise element of list1
    # ARGS
    # Row   : function(list1.element, list2.element) --> one-row data.frame
    # list1 : a list or vector
    #cat('start BuildDataframeByRow1\n'); browser()
    all <- NULL
    for (list1.element in list1) {
        next.row <- Row(list1.element)
        all <- if (is.null(all)) next.row else rbind(all, next.row)
    }
    all
}

BuildDataframeByRow2 <- function(Row, list1, list2) {
    # return data.frame by applying f to each pairwise element of list1 x list2
    # ARGS
    # Row   : function(list1.element, list2.element) --> one-row data.frame
    # list1 : a list or vector
    # list2 : a list or vector
    #cat('start BuildDataframeByRow2\n'); browser()
    all <- NULL
    for (list1.element in list1) {
        for (list2.element in list2) {
            next.row <- Row(list1.element, list2.element)
            all <- if (is.null(all)) next.row else rbind(all, next.row)
        }
    }
    all
}

MapRows <- function(ProcessOneRow, df) {
    # return list
    #cat('MapRows\n'); browser()
    result <- NULL
    for (row.index in 1:nrow(df)) {
        one.row <- df[row.index,]
        result <- c(result, ProcessOneRow(one.row))
    }
    result
}

PrintZeroFrequency <- function(data) {
    # fraction zero in each month

    DetermineFractionWithZeroError <- function(data) {
        Row <- function(sale.year, sale.month) {
            # return data.frame counting errors with zero value
            #cat('start Row', sale.year, sale.month, '\n'); browser()
            monthly.data <- data[data$sale.year == sale.year & data$sale.month == sale.month,]
            num.transactions <- nrow(monthly.data)

            num.error.negative <- sum(monthly.data$error < 0)
            num.error.zero <- sum(monthly.data$error == 0)
            num.error.positive <- sum(monthly.data$error > 0)

            result <- data.frame( sale.year = sale.year
                                 ,sale.month = sale.month
                                 ,num.transactions = num.transactions
                                 ,num.error.negative = num.error.negative
                                 ,num.error.zero = num.error.zero
                                 ,num.error.positive = num.error.positive
                                 ,fraction.error.negative = num.error.negative / num.transactions
                                 ,fraction.error.zero = num.error.zero / num.transactions
                                 ,fraction.error.positive = num.error.positive / num.transactions
                                 )
            result
        }

        fraction.zero <- BuildDataframeByRow2(Row, c(2007, 2008), c(1,2,3,4,5,6,7,8,9,10,11,12))
        fraction.zero
    }

    PrintReport <- function(fraction.zero) {
        # print nicely 
        fraction.zero.report <-
            fraction.zero[
                          ,c( 'sale.year'
                             ,'sale.month'
                             ,'fraction.error.negative'
                             ,'fraction.error.zero'
                             ,'fraction.error.positive'
                             )
                          ]
        Printf( '%15s %15s %25s %25s %25s\n'
               ,'sale.year'
               ,'sale.month'
               ,'fraction.error.negative'
               ,'fraction.error.zero'
               ,'fraction.error.positive'
               )

        PrintRow <- function(df) {
            Printf('%15d %15d %25.2f %25.2f %25.2f\n'
                   ,df$sale.year
                   ,df$sale.month
                   ,df$fraction.error.negative
                   ,df$fraction.error.zero
                   ,df$fraction.error.positive
                   )
        }

        MapRows(PrintRow, fraction.zero.report)
    }

    fraction.zero <- DetermineFractionWithZeroError(data)
    PrintReport(fraction.zero)

    fraction.zero
}

ReadDeeds <- function() {
    # read deeds file augmented with best apn field
    cat('start ReadDeeds\n')
    start.time <- proc.time()
    load(file = '../data/v6/output/deeds-al.rsave')
    elapsed.time <- proc.time() - start.time
    print(elapsed.time)  # read the csv.gz file takes CPU time 173
    stopifnot(!is.null(deeds.al))

    # create numeric best APN column
    deeds.al$best.apn <- BestApns( apns.unformatted = deeds.al$APN.UNFORMATTED
                                  ,apns.formatted = deeds.al$APN.FORMATTED
                                  )
    cat('best.apn set\n'); browser()
    deeds.al[!is.na(deeds.al$best.apn), ]  # drop obs with NA for best.apn
}

ReadParcels <- function(control) {
    # read parcels file into a data.frame
    # ARGS:
    # control : list of control variables
    # RETURNS data.frame
    cat('start ReadParcels\n')
    start.time <- proc.time()
    load(file = '../data/v6/output/parcels-sfr.rsave')
    elapsed.time <- proc.time() - start.time
    print(elapsed.time)  # reading the csv.gz file takes CPU 178 seconds
    stopifnot(!is.null(parcels.sfr))

    parcels.sfr
}

ThereAreSomeForeclosures <- function(deeds) {
    # Q: Are there any foreclosure deeds?
    # (perhaps the zero-priced sales are actually foreclosures, not sales)
    deedc <- unique(deeds$DOCUMENT.TYPE.CODE)
    print(deedc)

    Map( function(code) cat('code', code, 'occurs', sum(deeds$DOCUMENT.TYPE.CODE == code), '\n')
        ,deedc
        )

    cat('G --> Grant\n')
    cat('U --> Foreclosure\n')
    cat('Q --> Quit claim\n')
    cat('X --> Mulit city or open-ended mortgage\n')
    cat('T --> Deed of trust (lein for mortgage lender)\n')

    stopifnot(any(deedc == 'U'))  # A: there are some foreclosures
}

TransactionsForZeroErrors2008 <- function(nsamples, data, deeds) {
    # return data.frame containing all sales transactions for observations with
    # a zero error in 2008

    TransactionHistory <- function(apn) {
        # return data.frame containing the ordered transaction history for the apn
        #cat('start TransactionHistory', apn, '\n'); browser()
        has.apn <- deeds[ deeds$best.apn == apn &
                          !is.na(deeds$SALE.DATE) &  # drop observations without a SALE.DATE
                          !is.na(deeds$SALE.CODE)    # drop observations without a SALE.CODE
                        ,
                        ]
        # include just some features in the history
        #cat('about to fail\n'); browser()
        some <- data.frame( stringsAsFactors = FALSE

                           ,apn = has.apn$best.apn
                           ,sale.date = has.apn$SALE.DATE
                           ,price = has.apn$SALE.AMOUNT

                           ,deedc.code = has.apn$DOCUMENT.TYPE.CODE
                           ,deedc.name = DEEDC(code = has.apn$DOCUMENT.TYPE.CODE)
                           ,is.grant.deed = DEEDC( kind = 'grant.deed'
                                                  ,code = has.apn$DOCUMENT.TYPE.CODE
                                                  )

                           ,trntp.code = has.apn$TRANSACTION.TYPE.CODE
                           ,trntp.name = TRNTP(code = has.apn$TRANSACTION.TYPE.CODE)
                           ,is.resale     = TRNTP( kind = 'resale'
                                                  ,code = has.apn$TRANSACTION.TYPE.CODE
                                                  )

                           ,scode.code = has.apn$SALE.CODE
                           ,scode.name = SCODE(code = has.apn$SALE.CODE)
                           ,is.sale.price.full  = SCODE( kind = 'sale.price.full'
                                                        ,code = has.apn$SALE.CODE
                                                        )
                           )
        result <- some[order(some$sale.date),]
        result
    }

    PrintTransactionHistory <- function(df) {
        # print a data frame containing a transaction history
        # print only selected fields in order to make the stdout easier to read
        #cat('start PrintTransactionHistory\n'); browser()
        
        pretty <- data.frame( stringsAsFactors = FALSE
                             ,apn = df$apn
                             ,sale.date = df$sale.date
                             ,price = df$price
                             ,deed = df$deedc.name
                             )
        print(pretty)
    }

    TransactionHistoryAndPrint <- function(apn) {
        # return transaction history; also print it
        #cat('start TransactionHistoryAndPrint', apn, '\n'); browser()
        cat('apn', apn, '\n')
        th <- TransactionHistory(apn)
        stopifnot(ncol(th) > 5)  # track down a bug
        PrintTransactionHistory(th)
        th
    }

    #cat('start TransactionsForZeroError2008\n'); browser()

    # determine APNs that had a sale in 2008 with a zero error
    zero.apns <- data$apn[data$error == 0 & data$sale.year == 2008]
    Printf('Number of transactions in 2008 with zero errors = %d\n', length(zero.apns))

    Printf('Transaction history for randomly-selected parcels with a zero assessment error in 2008\n')
    Printf('%d randomly-selected samples\n', nsamples)
    #BuildDataframeByRow1(TransactionHistoryAndPrint, c(8074001029)) # test bad apn
    result <- 
        BuildDataframeByRow1(TransactionHistoryAndPrint, sample(zero.apns, nsamples))

    result
}

ExamineParcels <- function(control, data, parcels) {
    cat('start ExamineParcels\n'); browser()
}

ExamineDeeds <- function(control, data, deeds) {
    # ARGS:
    # control : list of control vars
    # deeds   : data.frame of deeds with valid numeric APNS in field best.apn
    # RETURNS data.frame
    cat('start ExamineDeeds\n'); browser()

    ThereAreSomeForeclosures(deeds)
    transactions.for.zero.error.2008 <- TransactionsForZeroErrors2008( nsamples = 100
                                                                      ,data = data
                                                                      ,deeds = deeds
                                                                      )
    return(transactions.for.zero.error.2008)
}

ExamineDups <- function(data.all) {
    #cat('ExamineDups\n'); browser()
    data <- data.frame( saleDate = data.all$saleDate
                       ,price = data.all$price
                       ,assessment = data.all$assessment
                       ,error = data.all$error
                       ,apn = data.all$apn
                       )
    apns <- data$apn
    unique.apns <- unique(apns)
    Printf('%d unique APNS out of %d\n', length(unique.apns), length(apns))
    duplicated.apns <- data$apn[which(duplicated(apns))]
    Printf('%d duplicated apns\n', length(duplicated.apns))

    Examine <- function(duplicated.apn) {
        #cat('Examine', duplicated.apn, '\n'); browser()
        this.apn <- data[data$apn == duplicated.apn,]
        if (any(this.apn$error == 0)) print(this.apn)
        NULL
    }

    Printf('transactions for duplicated apns with a zero error\n')
    Map(Examine, head(duplicated.apns, n = 30))
    cat('in ExamineDups\n'); browser()
}


Main <- function(split.names, deeds.al, parcels.sfr) {
    #cat('start Main'); browser()

    path.output = '../data/v6/output/'
    me <- 'e-assessment-attractor' 
    control <- list( response = 'log.price'
                    ,path.in.deeds = paste0(path.output, 'deeds-al.rsave')
                    ,path.in.base = paste0(path.output, 'transactions-subset1')
                    ,path.out.log = paste0(path.output, me, '.log')
                    ,path.out.save = paste0(path.output, me, '.rsave')
                    ,random.seed = 123
                    ,split.names = split.names
                    ,testing.period = list( first.date = as.Date('2008-01-01')
                                           ,last.date = as.Date('2008-01-31')
                                           )
                    ,testing = TRUE
                    )

    InitializeR( duplex.output.to = control$path.out.log
                ,random.seed = control$random.seed)
    print(control)

    data.file <- ReadTransactionSplits( path.in.base = control$path.in.base
                                       ,split.names = control$split.names
                                       ,verbose = TRUE
                                       )
    assessment = data.file$improvement.value + data.file$land.value
    error = data.file$price - assessment
    data <- data.frame( stringsAsFactors = FALSE
                       ,saleDate = data.file$saleDate
                       ,sale.year = data.file$sale.year
                       ,sale.month = data.file$sale.month
                       ,price = data.file$price
                       ,error = error
                       ,abs.error = abs(error)
                       ,assessment = assessment
                       ,apn = data.file$apn
                       )[data.file$sale.year == 2008 | data.file$sale.year == 2007,]

    print(summary(data))
    Printf('%d of %d errors are zero\n', sum(data$error == 0), nrow(data))

    #cat('in Main\n'); browser()

    if (FALSE) PrintHistograms(data[data$sale.year == 2008,])
    fraction.zero <- if (FALSE) PrintZeroFrequency(data) else NULL
    examine.dups <- if (FALSE) ExamineDups(data) else NULL
    examine.deeds <- if (FALSE) ExamineDeeds(control, data, deeds.al) else NULL
    examine.parcels <- if (TRUE) ExamineParcels(control, data, parcels.sfr) else NULL


    # save results
    save(control, fraction.zero, examine.dups, examine.deeds, file = control$path.out.save)

    print(control)
    if (control$testing) cat('DISCARD RESULTS: TESTING\n')
}

# cache the deeds.al file (it takes about a minute to read it)
if (!exists('deeds.al')) {
    deeds.al <- ReadDeeds()
}

# cache the parcels.sfr file
if (!exists('parcels.sfr')) {
    parcels.sfr <- ReadParcels()
}
    

Main(split.names, deeds.al, parcels.sfr)
cat('done\n')
