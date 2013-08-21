# MakeCat.R

MakeCat <- function(file) {
  # override the built-in cat function so that it prints also to a file
  # Args:
  # file: scalar chr, path to the file
  #
  # Returns:
  # the new cat function

  cat <- function(..., sep=" ", fill=FALSE, labels=NULL, append=FALSE) {
    # print to stdout and to a file
    # Args: identical to built-in cat()
    # Result: same as built-in cat
    
    base::cat(..., sep=sep, fill=fill, labels=labels, append=append)
    # output file is closed after each write
    base::cat(..., sep=sep, fill=fill, labels=labels, append=TRUE,
              file=file)
  }

  cat
}
