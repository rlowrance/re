# parcels-sfr-rsave.R
# create file OUTPUT/parcels-sfr.rsave
# containing data.frame parcels-sfr

library(devtools)
load_all('../../lowranceutilitiesr')


Main <- function() {
    #cat('start Main\n'); browser()
    path.output <- '../data/v6/output/'
    me <- 'parcels-sfr-rsave'
    control <- list( path.in = paste0(path.output, 'parcels-sfr.csv.gz')
                    ,path.out.save = paste0(path.output, 'parcels-sfr.rsave')
                    ,path.out.log = paste0(path.output, me, '.log')
                    ,testing = FALSE
                    )

    InitializeR(duplex.output.to = control$path.out.log)
    print(control)

    start.time <- proc.time()

    # from transactions-al-sfr.R
#    parcels <- read.csv(control$path.parcels,
#                        check.names=FALSE,
#                        na.string = c('NA', ''),
#                        header=TRUE,
#                        quote="",
#                        comment="",
#                        stringsAsFactors=FALSE,
#                        sep='\t',
#                        nrows=ifelse(control$testing, control$testing.nrow, -1))
    parcels.sfr <- read.csv(control$path.in,
                            sep='\t',
                            check.names = FALSE,
                            header=TRUE,
                            quote="",
                            comment="",
                            stringsAsFactors=FALSE,
                            nrows=ifelse(control$testing, 1000, -1))

    elapsed.time <- proc.time() - start.time
    print(elapsed.time)

    save(parcels.sfr, file = control$path.out.save)
}

Main()
cat('done\n')

