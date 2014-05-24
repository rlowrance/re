# DropFactorsWithOneLevel.R
DropFactorsWithOneLevel <- function(df) {
    # drop factors from data.frame df that contain only one level
    has.one.level <- sapply(df, function(x) nlevels(x) == 1)
    df[, !has.one.level]
}

Test <- function() {
    df <- data.frame(v1 = c('a', 'b', 'a'),
                     v2 = c('one', 'one', 'one'),
                     v3 = c(1,2,3),
                     stringsAsFactors = TRUE)
    reduced <- DropFactorsWithOneLevel(df)
    for (name in names(reduced)) 
        stopifnot(name == 'v1' | name == 'v3')
}

Test()
