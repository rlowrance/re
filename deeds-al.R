# deeds-al.Rmd
# Program to create file deeds-al.csv, holding certain features of arms-length deeds.

# I would have retained all features, but my system has only 15 GB RAM, not enough
# to keep all the features using this programmatic approach. Instead, could have
# created 8 files with just certain deeds and merged them all.
# 
# Retain only features of deeds, not features of the parcels. The idea is to
# rely on the parcels file exclusive for parcels features.
# 
# An earlier versions dropped features that were all missing and always had the
# same value. This was an attempt to remove non-informative features, but it
# complicates my ability to understand what the programs are doing.
# 
# An earlier version also attempted to remove duplicated deeds, but that code was 
# broken. Now all arms-length deeds are passed on.
# 
# Files read and the deeds files the Laufer directory. This directory contains
# the file Steve Laufer used in his experiments.
# 
# Record layout for the input is in 1080_Record_layout.csv

# set variable that control the script
control <- list()
control$me <- 'deeds-al'
control$laufer.dir="../data/raw/from-laufer-2010-05-11"
control$dir.output="../data/v6/output/"
control$path.deeds.out <- paste0(control$dir.output, "deeds-al.csv")
control$path.log <- paste0(control$dir.output, control$me, '.txt')
control$testing <- TRUE
control$testing <- FALSE


# Turn on the JIT compiler and source files
source('InitializeR.R')  # must be first, since starts the JIT compiler
InitializeR(start.JIT = ifelse(control$testing, FALSE, TRUE),
            duplex.output.to = control$path.log) 


# source other files, now that the JIT may be running
source("RemoveNonInformative.R")

ReadDeedsFile <- function(num) {
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

    # keep the features we want
    # add features to trace back to original source
    which.features <- 'some'
    #which.features <- 'all'
    if (which.features == 'some') {
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


ReadAll <- function() {
    # Read all the deeds files into one big data.frame
    # RETURN: list
    # $df : data frame containing only arms-length deeds and certain features
    # $num.dropped : number of non arms-length deeds found and dropped
    df <- NULL
    num.dropped <- 0
    for (file.number in 1:8) {
        a.list<- ReadDeedsFile(file.number)
        df <- rbind(df, a.list$df)
        num.dropped <- num.dropped + a.list$num.dropped
    }
    list(df = df, num.dropped = num.dropped)
}

###############################################################################
# Main program
###############################################################################

Main <- function(control) {
    # write control variables
    for (name in names(control)) {
        cat('control ', name, ' = ', control[[name]], '\n')
    }

    # Read all the deeds
    all <- ReadAll()
    cat('total number of arms-length deeds', nrow(all$df), '\n')
    cat('total number of non-arms length deeds', all$num.dropped, '\n')
    str(all$df)
    print(summary(all$df))
    cat('names(all$df)')
    print(names(all$df))

    ## Write deeds to csv

    cat("writing arms-length deeds to", control$path.deeds.out, "\n")
    write.csv(all$df,
              file=control$path.deeds.out,
              quote=FALSE,
              row.names = FALSE)
    cat('done\n')
}

Main(control)
