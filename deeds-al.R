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
control$path.out <- paste0(control$dir.output, "deeds-al.csv")
control$compress <- 'only' # choices: 'also', 'no', 'only'
control$path.log <- paste0(control$dir.output, control$me, '.txt')
control$testing <- TRUE
control$testing <- FALSE


# Turn on the JIT compiler and source files
source('InitializeR.R')  # must be first, since starts the JIT compiler
InitializeR(start.JIT = FALSE,
            duplex.output.to = control$path.log) 


# source other files, now that the JIT may be running
source('PRICATCODE.R')
source('Printf.R')

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
    
    # track original source
    df$deed.file.number=rep(num, nrow(df))
    df$deed.record.number=1:nrow(df)

    # keep only arms-length deeds
    is.arms.length <- PRICATCODE(df$PRI.CAT.CODE, 'arms.length.transaction')
    
    original.num.rows = nrow(df)

    # create subset we want
    interesting <- subset(df, subset = is.arms.length)

    num.dropped = original.num.rows - nrow(interesting)
    Printf('input file %d had %d records that were not arms-length deeds\n',
           num, num.dropped)

    list(df = interesting,
         num.dropped = num.dropped)

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
        #cat('after file.number', file.number, '\n'); browser()
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

    ## Write uncompressed output

    cat("writing arms-length deeds to", control$path.out, "\n")
    write.table(all$df,
                file=control$path.out,
                sep='\t',
                quote=FALSE,
                row.names = FALSE)
    

    # maybe compress the output
    #cat('maybe compress output', nrow(all$df), '\n'); browser()
    if (control$compress == 'only') {
        command <- paste('gzip', '--force', control$path.out)
        system(command)
    } else if (control$compress == 'also') {
        command.1 <- paste('gzip --to-stdout', control$path.out) 
        command.2 <- paste('cat - >', paste0(control$path.out, '.gz'))
        command <- paste(command.1, '|', command.2)
        system(command)
    }

    # write control variables
    for (name in names(control)) {
        cat('control ', name, ' = ', control[[name]], '\n')
    }

    cat('done\n')
}

Main(control)
