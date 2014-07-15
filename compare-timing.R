# main program to compare timing
# v1: use ReadAndTransformedTransactions
# v2: read just specific column

source('LoadColumns.R')
source('ReadAndTransformTransactions.R')

CompareTiming <- function() {
    cat('starting CompareTiming\n'); browser()
    ReadAll <- function() {
        transformed.data <- ReadAndTransformTransactions( path.in = control$path.in
                                                         ,nrows = ifelse(control$testing, 1000, -1)
                                                         ,verbose = FALSE)
    }

    ReadSome <- function() {
        #cat('starting ReadSome\n'); browser()
        transformed.data <- LoadColumns( path.base = '../data/v6/output/transactions-subset1'
                                        ,column.names = c('price', 'sale.year', 'sale.month')
                                        )
    }

    timing.some <- system.time(ReadSome())
    print('timing.some')
    print(timing.some)

    timing.all <- system.time(ReadAll())
    print('timing.all')
    print(timing.all)
}
CompareTiming()
