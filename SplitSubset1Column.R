SplitSubset1Column <- function(current.name, new.name, transform, testing = FALSE) {
    # save transformed column from transactions-subset1 file as variable "data"
    #cat('starting SplitSubset1Column', current.name, new.name, testing, '\n'); browser()
    Require('FileInput')

    path.input.base <- FileInput('../data/v6/output/transactions-subset1')
    raw <- read.table( file = sprintf('%s.csv.gz', path.input.base)
                      ,header = TRUE
                      ,sep = "\t"
                      ,quote = ""
                      ,comment = ""
                      ,stringsAsFactors = TRUE
                      ,na.strings = "NA"
                      ,nrows = ifelse(testing, 1000, -1)
                      )

    current.value <- raw[[current.name]]
    new.value <- transform(current.value)
    data <- data.frame(new.value)
    colnames(data) <- new.name
    file <- sprintf('%s-%s.rsave', path.input.base, new.name)
    save( data  # other code expects the name to be "data"
         ,file = file
         )
}
