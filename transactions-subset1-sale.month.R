# main program to create file transactions-subset-sale.month.R

source('InitializeR.R')
source('Require.R')
source('SplitDate.R')
source('SplitSubset1Column.R')

control <- list( testing = FALSE
                ,path.out.log = '../data/v6/output/transactions-subset1-sale.month-log.txt'
                )
print(control)

InitializeR(duplex.output.to = control$path.out.log)

Transform <- function(current.value) {
    #cat('starting Transform', length(current.value), '\n'); browser()
    splitDate <- SplitDate(current.value)
    result <- splitDate$month
    result
}

SplitSubset1Column( current.name = 'transaction.date'
                   ,new.name     = 'sale.month'
                   ,transform    = Transform
                   ,testing      = control$testing
                   )
print(control)
cat('done\n')
