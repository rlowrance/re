ReadSplit <- function(path.in, split.name, nrows, verbose) {
    # read and return a one-column data frame from an rsave file
    #cat('starting Readplit', path.in, split.name, nrows, verbose, '\n'); browser()
    path <- paste0(path.in, '-', split.name, '.rsave')
    loaded <- load(file = path)
    stopifnot(loaded[[1]] == 'data')
    data
}
