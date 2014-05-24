# NumberFeaturesWithAnNA.R
NumberFeaturesWithAnNA <- function(df) {
    # determine number of rows in a data.frame that contain an NA value
    # ARGS:
    # df : data.frame
    # RETURNS: scalar, number of rows with an NA value
    sum(sapply(df, function(feature) any(is.na(feature))))
}

Test <- function() {
    df <- data.frame(a = c(1,2,3),
                     b = c(10,11,NA))
    stopifnot(NumberFeaturesWithAnNA(df) == 1)
    df <- na.omit(df)
    stopifnot(NumberFeaturesWithAnNA(na.omit(df)) == 0)
}

Test()
