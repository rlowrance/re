# ReadParcelsFile.R
ReadParcelsFile <- function(num, nrow=-1, path='../data/raw/from-laufer-2010-05-11/tax/') {
    # return data.frame containing all rows and columns from a parcels file
    # ARGS
    # num : integer, number of the file (1, 2, ... 8)
    # nrow : number of rows to read, -1 for all
    # path : path to directory containing the parcels files
    # RETURNS a data.frame
    path <- paste0(path,
                  "CAC06037F",
                  num,
                  ".txt.gz")
    df <- read.table(path,
                     header=TRUE,
                     sep="\t",
                     quote="",
                     comment="",
                     stringsAsFactors=FALSE,
                     na.strings="",
                     nrows=nrow)
    df
}
