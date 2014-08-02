# main program to run analysis 01 (median price by month)
# input files OUTPUT/transactions-subset1-price.rsave
#                                        -sale-year.rsave
#                                        -sale-month.rsave
#                         
# write files OUTPUT/an-01.rsave
#                    an-01-log.txt

source('FileInput.R')
source('FileOutput.R')
source('InitializeR.R')
source('LoadColumns.R')

# declare input and output files
# NOTE: these declarations are used in part to form the makefile
control <- list( testing = FALSE
                ,path.in         = FileInput ('../data/v6/output/transactions-subset1.csv.gz')
                ,path.out.result = FileOutput('../data/v6/output/an-01.rsave')
                ,path.out.log    =            '../data/v6/output/an-01-log.txt'
                )

InitializeR(duplex.output.to = control$path.out.log)

print('control variables')
print(control)


Main <- function(control) {
    #cat('starting Main\n'); browser()

    data <- LoadColumns( path.base = '../data/v6/output/transactions-subset1'
                        ,column.names = c('price', 'sale.year', 'sale.month')
                        )

    MedianPrice <- function(year, month) {
        # return median price in data fro year and month
        #cat('starting MedianPrice\n', year, month, '\n'); browser()
        selected <- data$sale.year == year & data$sale.month == month
        price <- data[selected, 'price']
        median.price <- median(price, na.rm = TRUE)
        median.price
    }

    # build up data.frame row by row
    analysis <- NULL

    for (sale.year in 2006:2009) {
        last.sale.month <- ifelse(sale.year == 2009, 11, 12)
        for (sale.month in 1:last.sale.month) {
            median.price <- MedianPrice(sale.year, sale.month)
            next.row <- data.frame( stringsAsFactors = FALSE
                                   ,sale.year = sale.year
                                   ,sale.month = sale.month
                                   ,median.price = median.price
                                   )
            analysis <- rbind(analysis, next.row)
        }
    }

    print('analysis')
    print(analysis)

    save(analysis, file = control$path.out.result)

    NULL
}

Main(control)

print('control variables')
print(control)

cat('done\n')
