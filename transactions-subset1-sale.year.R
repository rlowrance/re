# main program to create file transactions-subset-sale.year.R

source('InitializeR.R')
source('Require.R')
source('SplitDate.R')
source('SplitSubset1Column.R')

control <- list( testing = FALSE
                ,path.out.log = '../data/v6/output/transactions-subset1-sale.year-log.txt'
                )

InitializeR(duplex.output.to = control$path.out.log)

Transform <- function(current.value) {
    #cat('starting Transform', length(current.value), '\n'); browser()
    splitDate <- SplitDate(current.value)
    result <- splitDate$year
    result
}

SplitSubset1Column( current.name = 'transaction.date'
                   ,new.name     = 'sale.year'
                   ,transform    = Transform)
cat('done\n')
