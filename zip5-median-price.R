# zip5-median-price.R
# determine median price in every month for every zip5

control <- list()
control$me <- 'zip5-median-price'
control$output.dir <- '../data/v6/output/'
control$path.input <- paste0(control$output.dir, 'transactions-subset1.csv')
control$path.output <- paste0(control$output.dir, control$me, 'csv')
control$testing <- TRUE
control$testing <- FALSE


source('InitializeR.R')
InitializeR(duplex.output.to=paste0(control$output.dir, control$me, '.txt'))

source('Printf.R')
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

ReadTransactions <- function(control) {
    # create data.frame will year, month, price
    #cat('starting ReadTransactions\n'); browser()

    df <- read.csv(file = control$path.input,
                   nrow = ifelse(control$testing, 10000, -1),
                   header = TRUE)
    cat('df nrow', nrow(df), '\n')

    # select valid records
    sale.date   <- !is.na(df$SALE.DATE)
    sale.amount <- df$SALE.AMOUNT > 0
    is.valid    <- sale.date & sale.amount
    valid <- df[is.valid, c('zip5', 'SALE.AMOUNT', 'SALE.DATE') ]

    # slit date into year and month
    split <- SplitDate(valid$SALE.DATE, format = 'YYYYMMDD')

    # return only fields we use subsequently
    result <- data.frame(zip5  = valid$zip5,
                         price = valid$SALE.AMOUNT,
                         year  = split$year,
                         month = split$month)
    #cat('ending ReadTransactions', nrow(valid), '\n')
    result
}


PriceZipYearMonth <- function(zip5, year, month, transactions) {
    # return vector of transaction prices for specified year and month
    selected.zip5 <- transactions$zip5 == zip5
    selected.year <- transactions$sale.year == year
    selected.month <- transactions$sale.month == month
    transactions[selected.zip5 & selected.year & selected.month, 'price']
}

MedianPrice <- function(zip5, year, month, transactions) {
    # TODO: incorprate zip5
    median(PriceZipYearMonth(year, month, transactions))
}


Main <- function(control, transactions) {
    cat('starting Main\n'); browser()
    # TODO: determine first and last years
    df <- NULL

    for (zip5 in unique(df$zip5)) {
         for (year in first.year:last.year) {
             for (month in 1:12) {
                 median.price <- MeanPrice(zip5, year, month, transactions)
                 new.df <- data.frame(zip5 = zip5,
                                      year = year,
                                      month = month,
                                      median.prie = median.price)
                 df <- rbind(df, new.df)
             }
         }
    }

}

force.read.transactions <- FALSE
#force.read.transactions <- TRUE
if (force.read.transactions || !exists('transactions.dataframe')) {
    transactions.dataframe <- ReadTransactions(control)
}

Main(control, transactions.dataframe)

if (control$testing) {
    cat('\n********************** TESTING: DISCARD OUTPUT ***************************\n')
}

cat('done\n')


