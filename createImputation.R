# createImputation.R
# Impute missing values in the subset

################################################################################
## SETTINGS
################################################################################

settings = list()
settings$testing <- FALSE

settings$JIT.level=3  # in {0, 1, 2, 3}
settings$script.name <- "createImputation.R"

# num transactions read if testing
settings$read.limit <- 100

# output paths
settings$dir.output <- "../data/v6/output/"
settings$path.imputed <- paste(settings$dir.output,
                              "transactions-subset-imputed.csv",
                              sep="")

# input paths
settings$path.subset <- paste(settings$dir.output,
                              "transactions-subset.csv",
                              sep="")

# cache paths: NONE

# working directory (create in Finder if necessary)
settings$run.name <- paste(Sys.Date(),
                           "/",
                           settings$script.name,
                           ifelse(settings$testing,"-testing",""),
                           sep="")
settings$dir.working <- paste("../data/v6/working/", settings$run.name,
                              sep="")
settings$path.logfile <- paste(settings$dir.working, "/log.txt", sep="")

################################################################################
# INITIALIZE
################################################################################

# maybe turn on the JIT compiler
source("SetJITLevel.R")
SetJITLevel(settings$JIT.level)

# set R options
options(warn=2)  # turn warnings into errors

# set random number seed
settings$random.seed <- 1
set.seed(settings$random.seed)

# make sure working directory has been created
dir.create(settings$dir.working,
           showWarnings=FALSE,
           recursive=TRUE)
if (!file.exists(settings$dir.working)) {
  stop("should have created directory")
  cat("create directory", settings$dir.working, "and restart\n")
  stop()
}

# copy this script file to working directory
file.copy(from=settings$script.name,
          to=paste(settings$dir.working, "/", settings$script.name,
                   sep=""),
          overwrite=TRUE)


# delete any existing log file
if (file.exists(settings$path.logfile))
    file.remove(settings$path.logfile)

# redefine cat() to write to both stdout and the log file
source("MakeCat.R")
cat <- MakeCat(settings$path.logfile)

# write the settings
source("TimeStamp.R")
cat("started at", TimeStamp(), "\n")
if (settings$testing)
  cat("WARNING: TESTING; DISCARD RESULTS\n")
for (name in names(settings)) {
  cat("settings", name, settings[[name]], "\n")
}

################################################################################
# REQUIRE/SOURCE
################################################################################

require(nnet)          # for multinom()

#source("RemoveNonInformative.R")

################################################################################
# Imputation and related functions
################################################################################

ImputeOneFeatureNA <- function(df, featurename, index) {
  # Use local logistic regression to impute one missing feaure
  # Weights are based on distances from the query observation
  cat("STUB: ImputeOneFeatureNA", featurename, index, "\n")
  browser()
}

ImputeOneFeature <- function(df, featurename) {
  # Impute via a local logistic regression
  # Weights are based on the distances
  newvalues <- df[[featurename]]
  for (i in 1:length(newvalues))
    if (is.na(newvalues[i])) {
      newvalue <- ImputeOneNA(df, featurename, i)
      newvalues[i] <- newvalue
    }
  newvalues
}

Impute <- function(df) {
  # Impute NAs in certain columns of a data frame.
  #
  # Arg:
  # df: a data frame with column names such that a column name ending in
  #     ".imputed" is to have its NA values replaced with imputed values
  #
  # Value:
  # new: a data frame with same column names as df, but with all NAs replaced

  # Determine columns that will get imputed
  colnames <- names(df)
  imputed.colnames <- list()
  browser()
  for (colname in colnames) {
    # select the colname if it ends in ".imputed"

  }

  allnewvalues <- list()
  for (colname in imputed.colnames) {
    newvalues <- ImputeOneFeature(df, colname)
    allnewvalues <- list(allnewvalues, newvalues)
  }
  
  cat("STUB: Impute\n")
  df
}

Houses <- function(subset) {
  # Determine houses in the subset
  #
  # Args:
  # subset: data frame
  #
  # Value:
  # data frame with one row for each house and all house features
  apns <- subset$APN.UNFORMATTED
  apns <- unique(apns)
  nUnique <- length(apns)
  cat("number of records in subset =", nrow(subset), "\n")
  cat("number of unique apns =", length(apns), "\n")

  # create result r containing just those unique APNs
  keep <- rep(FALSE, nUnique)
  max.count <- 100
  count <- rep(0, max.count)
  for (i in 1:nUnique) {
    if (i %% 1000 == 1)
      cat("on", i, "\n")
    apn = apns[i]
    matches <- which(apn == subset$APN.UNFORMATTED)
    nMatches <- length(matches)
    if (nMatches == 0)
      stop(sprintf("no matches for %s", apn))
    count[nMatches] <- count[nMatches] + 1
    first.index <-matches[1]
    keep[first.index] <- TRUE
    #browser()
  }
  r <- subset[keep, ]
  cat(sprintf("kept %d rows\n", nrow(r)))
  r
}

################################################################################
## SubsetRead
################################################################################

SubsetRead <- function() {
  # Read subset csv and return equivalent data frame
  path <- settings$path.subset
  nrows <- ifelse(settings$testing, settings$read.limit, -1)
  cat("reading subset from", path, "\n")
  subset <- read.csv(path
                     ,fill=FALSE,
                     ,stringsAsFactors=TRUE,
                     nrows=nrows
                     )
  cat(sprintf("read %d transactions from subset file %s\n",
              nrow(subset), path))
  subset
}
                     

################################################################################
## MAIN
################################################################################

Load <- function() {
  source(settings$script.name)
}

Go <- function() {
  Load()
  Run()
}


Run <- function() {
  # Do the work.
  
  # Value: NULL
  s <-  SubsetRead()
  h <- Houses(s)
  imputed <- Impute(h)

  out <- settings$path.imputed
  cat("writing imputed file", out, "\n")
  write.csv(subset,
            file=out,
            quote=FALSE)
  cat("number of records written:", nrow(subset), "\n")
  cat("number of features written:", ncol(subset), "\n")

  
  cat("\nending at", TimeStamp(), "\n")
  if (settings$testing)
    cat("TESTING: DISCARD OUTPUT\n")
}

