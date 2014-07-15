# main program to create file transactions-subset-sale.year.rsave

source('FileInput.R')
source('FileOutput.R')
source('InitializeR.R')

control <- list( testing = FALSE
                ,path.in =          FileInput('../data/v6/output/transactions-subset1.csv.gz')
                ,path.out.result = FileOutput('../data/v6/output/transactions-subset1-price.rsave')
                ,path.out.log =               '../data/v6/output/transactions-subset1-price-log.txt'
                )

InitializeR(duplex.output.to = control$path.out.log)

print('control variables')
print(control)

raw <- read.table( control$path.in
                  ,header=TRUE
                  ,sep="\t"
                  ,quote=""
                  ,comment=""
                  ,stringsAsFactors=TRUE
                  ,na.strings="NA"
                  ,nrows=ifelse(control$testing, 1000, -1)
                  )

data <- data.frame(price = raw$SALE.AMOUNT)

save(data, file = control$path.out.result)
cat('number of rows written', nrow(data), '\n')

print('control variables')
print(control)

print('done')
