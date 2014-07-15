LoadColumns <- function(path.base, column.names) {
    # load the specified column names and create a data frame from them
    #cat('starting LoadColumns', path.base, length(column.names), '\n'); browser()

    # build up the dataframe row by row
    all.data <- NULL
    for (column.name in column.names) {
        path.in <- sprintf('%s-%s.rsave', path.base, column.name)
        loaded.variables <- load(path.in)
        stopifnot(length(loaded.variables) == 1)
        stopifnot(loaded.variables[[1]] == 'data')
        #all.data <- IfThenElse(is.null(all.data), data, cbind(all.data, data))
        if (is.null(all.data)) {
            all.data <- data
        } else {
            all.data <- cbind(all.data, data)
        }
    }
    all.data
}
