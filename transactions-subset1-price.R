# main program to create file transactions-subset-price.rsave

source('InitializeR.R')
source('Require.R')
source('SplitDate.R')
source('SplitSubset1Column.R')

control <- list( testing = FALSE
                ,path.out.log = '../data/v6/output/transactions-subset1-price-log.txt'
                )
print(control)

InitializeR(duplex.output.to = control$path.out.log)

Transform <- function(current.value) {
    #cat('starting Transform', length(current.value), '\n'); browser()
    result <- current.value  # just rename 
    result
}

SplitSubset1Column( current.name = 'SALE.AMOUNT'
                   ,new.name     = 'price'
                   ,transform    = Transform
                   ,testing      = control$testing
                   )
print(control)
cat('done\n')
