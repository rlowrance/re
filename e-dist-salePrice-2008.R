# e-dist-salePrice-2008.R
# main program to determine empirical distribution of sale prices for 2008
# perhaps fit a distribution and deduce its parameters

split.names <- c('price', 'saleDate')  # these are makefile dependencies
library(devtools)
load_all('/Users/roy/Dropbox/lowranceutilitiesr')
load_all('/Users/roy/Dropbox/lowrancerealesatater')

library(ggplot)

Histogram <- function(control, data) {
    # return ggplot2 graph
}


Main <- function(split.names) {
    cat('start Main'); browser()

    path.output = '../data/v6/output/'
    me <- 'e-dist-salePrice-2008' 
    control <- list( path.in.base = paste0(path.output, 'transactions-subset1')
                    ,path.out.log = paste0(path.output, me, '.log')
                    ,path.out.save = paste0(path.output, me, '.rsave')
                    ,sample.period = list( first.date = as.Date('2008-01-01')
                                           ,last.date = as.Date('2008-12-31')
                                           )
                    ,split.names = split.names
                    )

    InitializeR(duplex.output.to = control$path.out.log)
    print(control)

    data <- ReadTransactionSplits( path.in.base = control$path.in.base
                                  ,split.names = control$split.names
                                  ,verbose = TRUE
                                  )

    histogram <- Histogram(data)
    # print results of the experiment

    # save results
    description <- 'Cross Validation Result\nLog-Level model\nPredict Jan 2008 transactions using 60 days of training data'
    save(data, file = control$path.out.save)

    print(control)
}



Main(split.names)
cat('done\n')
