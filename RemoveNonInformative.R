# RemoveNonInformative.R

RemoveNonInformative <- function(df, write) {
  # remove columsn from a data frame that have no information
  #
  # Args:
  # df: a data frame
  # write: a function to write messages; has same API as built-in cat()
  #
  # Value:
  # data frame with possibly some columns removed

  HasNoInfo <- function(column.name) {
    # Return TRUE iff df$column.name has no information
    values <- df[[column.name]]
    if (all(is.na(values))) {
      write(sprintf("dropping column %s because is all NA\n",
                    column.name))
      return(TRUE)
    }
    uniques <- unique(values, drop.na=TRUE)
    if (length(uniques) == 1) {
      write(sprintf("dropping column %s because there is only 1 non-NA value\n",
                    column.name))
      return(TRUE)
    }
    return(FALSE)
  }
  names <- colnames(df)
  for (name in names) {
    if (HasNoInfo(name)) {
      cat('removing non-informative feature', name, '\n')
      df[name] <- NULL
    }
  }
  df
}



################################################################################
## DEBUGGING RUNNING
################################################################################

go <- function() {
  source("createTransactions.R", echo=FALSE)
  run()
}

run <- function() {
  #debug(example)
  #example()
  #debug(read.deeds)
  #read.deeds()
  #census <- CensusCreate()
  t <- TransactionsCreate()
  cat("finished at", TimeStamp(), "\n")
}

