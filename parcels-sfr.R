# parcels-sfr.Rmd
# Create the output file holding single-family-residential parcels
# File layout is in 2580...


# set the control variables
control <- list()
control$me <- 'parcels-sfr'
control$laufer.dir <-'../data/raw/from-laufer-2010-05-11'
control$dir.output <- "../data/v6/output/"
control$path.out <- paste0(control$dir.output, "parcels-sfr.csv")
control$compress <- 'only'  # choices: 'no', 'only', 'also'
control$path.log <- paste0(control$dir, control$me, '.txt')
control$testing <- TRUE
control$testing <- FALSE

# Initialize R.
source('InitializeR.R')
InitializeR(start.JIT = FALSE,
            duplex.output.to = control$path.log)

# source other files now that JIT is running
source('Informative.R')
source('LUSEI.R')
source('Printf.R')

## Define function to read a taxroll file

ReadParcelsFile <- function(num) {
    # read some of the features in a payroll file
    # ARGS:
    # num : number of the file
    # RETURNS a list
    # $df : data.frame with selected features
    # $num.dropped :number of rercords dropped (as not for single family residences)
    path <- paste(control$laufer.dir,
                  "/tax/CAC06037F",
                  num,
                  ".txt.gz",
                  sep="")
    cat("reading tax file", path, "\n")
    df <- read.table(path,
                     header=TRUE,
                     sep="\t",
                     quote="",
                     comment="",
                     stringsAsFactors=FALSE,
                     na.strings="",
                     nrows=ifelse(control$testing,1000,-1))
    #cat("records in", path, nrow(df), "\n"); browser()
    
    # track original source
    df$parcel.file.number <- rep(num,nrow(df))
    df$parcel.record.number <- 1:nrow(df)

    # keep only single-family residence parcels
    is.sfr = LUSEI(df$UNIVERSAL.LAND.USE.CODE, 'sfr')
    
    original.num.rows = nrow(df)

    #informative <- c(Informative(df), 
    #                 'PRIOR.SALE.DOCUMENT.YEAR',  # missing from file 1
    #                 'parcel.file.number')
    #cat('in reader', sum(is.sfr), length(informative), '\n'); browser()

    # create subset we want
    # NOTE: this algo will fail if some files have non-informative columns that
    # are informative in other files
    interesting <- subset(df, subset = is.sfr)  # all columns
    #interesting <- subset(df,
    #                      subset = is.sfr,
    #                      select = informative)
    num.dropped <- original.num.rows - nrow(interesting)

    Printf('input file %d had %d records that were not single family residential\n',
           num, num.dropped)

    #cat('check parcel.file.number record 24\n'); browser()


    list(df=interesting, 
         num.dropped = num.dropped)
}

ReadAll <- function() {
    # Read all the parcels into one hug data.frame
    # ARGS: none
    # RETURNS: list
    # $df : data.frame with lots of rows
    # $num.dropped : number of non-single family residences found
    df <- NULL
    num.dropped <- 0
    for (file.number in 1:8) {
        a.list <- ReadParcelsFile(file.number)
        if (FALSE) {
            cat('names(a.list)\n')
            print(names(a.list$df))
            cat('names(df)\n')
            print(names(df))
            # check for new names
            num.new.names <- 0
            for (new.name in names(a.list$df)) {
                if (name %in% names(df)) {
                }
                else {
                    cat('new name', new.name, '\n')
                    num.new.names <- num.new.names + 1
                }
            }
            stopifnot(num.new.names == 0)
            cat('about to rbind\n', nrow(df), nrow(a.list$df), '\n'); browser()
        }
        df <- rbind(df, a.list$df)
        num.dropped <- num.dropped + a.list$num.dropped
    }
    list(df=df, num.dropped=num.dropped)
}

###############################################################################
## Main program
###############################################################################

Main <- function(control) {
    # write control variables
    for (name in names(control)) {
        cat('control ', name, ' = ', control[[name]], '\n')
    }

    # read all the parcels
    all <- ReadAll()
    cat('number of single-family residential parcels', nrow(all$df), '\n')
    cat('number of non SFR parcels', all$num.dropped, '\n')

    str(all$df)
    print(summary(all$df))

    #cat('check parcel.file.number\n'); browser()
    
    # write uncompressed version
    write.table(all$df,
                file=control$path.out,    # not compressed
                sep='\t',
                quote=FALSE,
                row.names=FALSE)

    # maybe compress the output
    if (control$compress == 'only') {
        command <- paste('gzip', control$path.out)
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


