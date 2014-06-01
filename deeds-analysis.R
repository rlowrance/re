# deeds-analysis.R
# Create file OUTPUT/deeds-analysis.txt containing analysi of all the deeds
# 
# Record layout for the input is in 1080_Record_layout.csv

# set variable that control the script
control <- list()
control$me <- 'deeds-analysis'
control$laufer.dir="../data/raw/from-laufer-2010-05-11"
control$dir.output="../data/v6/output/"
control$path.log <- paste0(control$dir.output, control$me, '.txt')
control$return.all.fields <- TRUE
control$testing <- TRUE
control$testing <- FALSE


# Turn on the JIT compiler and source files
source('InitializeR.R')  # must be first, since starts the JIT compiler
InitializeR(start.JIT = FALSE,
            duplex.output.to = control$path.log) 


# source other files, now that the JIT may be running
source("RemoveNonInformative.R")
source('Printf.R')

ReadDeedsFile <- function(num, control) {
    # Read the deeds file containing num in its name
    # ARGS:
    # num: number of input file; in {1, 2, ..., 8}
    #
    # VALUE: a list
    # $df : data.frame containing selected features for arms-length deeds
    # $num.dropped : number of non-arms-length deeds dropped from $df

    # read the deeds file
    # Note: In file 5, data record 945 has an NA value for APN.FORMATTED
    path <- paste(control$laufer.dir,
                  "/deeds/CAC06037F",
                  num,
                  ".txt.gz",
                  sep="")
    cat("\nreading deeds file", path, "\n")
    # NOTE: Don't convert strings to factors, because the other input
    # files may have different values than this file
    df <- read.table(path,
                     header=TRUE,
                     sep="\t",
                     quote="",
                     comment.char="",
                     stringsAsFactors=FALSE,
                     na.strings="",
                     nrows=ifelse(control$testing,1000,-1))

    cat("records in", path, nrow(df), "\n")

    # select fields to return
    if (!control$return.all.fields) {
        # pick features most likely to be needed downstream
        df <- data.frame(APN.UNFORMATTED=df$APN.UNFORMATTED, 
                         APN.FORMATTED=df$APN.FORMATTED,
                         SALE.AMOUNT=df$SALE.AMOUNT,
                         SALE.DATE=df$SALE.DATE,
                         RECORDING.DATE=df$RECORDING.DATE,
                         DOCUMENT.TYPE.CODE=df$DOCUMENT.TYPE.CODE,
                         TRANSACTION.TYPE.CODE=df$TRANSACTION.TYPE.CODE,
                         SALE.CODE=df$SALE.CODE,
                         MULTI.APN.FLAG.CODE=df$MULTI.APN.FLAG.CODE,
                         MULTI.APN.COUNT=df$MULTI.APN.COUNT,
                         PRIOR.SALES.DATE=df$PRIOR.SALES.DATE,
                         PRIOR.SALES.AMOUNT=df$PRIOR.SALES.AMOUNT,
                         PRIOR.MULTI.APN.FLAG.CODE=df$PRIOR.MULTI.APN.FLAG.CODE,
                         PRIOR.MULTI.APN.COUNT=df$PRIOR.MULTI.APN.COUNT,
                         PRI.CAT.CODE=df$PRI.CAT.CODE,
                         RESALE.NEW.CONSTRUCTION.CODE=df$RESALE.NEW.CONSTRUCTION.CODE,
                         deed.file.number=rep(num, nrow(df)),
                         deed.record.number=1:nrow(df),
                         stringsAsFactors=FALSE)
    }
    else {
        # pick all features
        # NOT: does not work with 16GB RAM
        df <- cbind(df, 
                    deed.file.number=rep(num, nrow(df)),
                    deed.record.number=1:nrow(df),
                    stringsAsFactors=FALSE)

    }


    # keep only arms-length deeds and deeds with numeric apns
    original.num.rows = nrow(df)
    arms.length <- df$PRI.CAT.CODE == "A"  # arms-length deeds
    df <- df[arms.length, ]

    list(df=df, num.dropped=original.num.rows - nrow(df))
}


ReadAll <- function(control) {
    # Read all the deeds files into one big data.frame
    # RETURN: list
    # $df : data frame containing only arms-length deeds and certain features
    # $num.dropped : number of non arms-length deeds found and dropped
    df <- NULL
    num.dropped <- 0
    for (file.number in 1:8) {
        a.list<- ReadDeedsFile(file.number, control)
        df <- rbind(df, a.list$df)
    }
    df
}

###############################################################################
# Main program
###############################################################################

Main <- function(control, all.deeds) {
    # write control variables
    for (name in names(control)) {
        cat('control ', name, ' = ', control[[name]], '\n')
    }
    
    # str(all.parcels) will truncate output if too many fields, so this:
    for (name in names(all.deeds)) {
        Printf('%30s', name)
        str(all.deeds[[name]])
    }

    if (TRUE) {
        print(summary(all.deeds))
    }

    cat('number unique PROPERTY.CITY', length(unique(all.deeds$PROPERTY.CITY)), '\n')

}

force.read <- FALSE
if (force.read | !exists('all.deeds')) {
    all.deeds <- ReadAll(control)
}

Main(control, all.deeds)
cat('done\n')
