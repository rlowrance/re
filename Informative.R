Informative <- function(df) {
    # determine columns in a data.frame that contain more than one value
    # ARGS
    # df : a data.frame
    # RETURNS vector of char, names of columns with more than one value
    result <- NULL
    for (name in names(df)) {
        num.unique <- length(unique(df[[name]]))
        if (num.unique > 1) {
            result <- c(result, name)
        }
    }
    result
}
