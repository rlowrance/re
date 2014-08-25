# deeds-al-rsave.R
# create file OUTPUT/deeds-al.rsave
# containing data.frame deeds.al

library(devtools)
load_all('/Users/roy/Dropbox/lowranceutilitiesr')


Main <- function() {
    #cat('start Main\n'); browser()
    path.output <- '../data/v6/output/'
    me <- 'deeds-al-rsave'
    control <- list( path.in = paste0(path.output, 'deeds-al.csv.gz')
                    ,path.out.save = paste0(path.output, 'deeds-al.rsave')
                    ,path.out.log = paste0(path.output, me, '.log')
                    ,testing = FALSE
                    )

    InitializeR(duplex.output.to = control$path.out.log)
    print(control)

    start.time <- proc.time()

    deeds.al <- read.csv(control$path.in,
                      sep='\t',
                      check.names = FALSE,
                      header=TRUE,
                      quote="",
                      comment="",
                      stringsAsFactors=FALSE,
                      nrows=ifelse(control$testing, 1000, -1))

    elapsed.time <- proc.time() - start.time
    print(elapsed.time)

    save(deeds.al, file = control$path.out.save)
}

Main()
cat('done\n')

