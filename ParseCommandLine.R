ParseCommandLine <- function(cl, keywords, ignoreUnexpected = FALSE, verbose = TRUE) {
    # parse a command line object into a list of keyword/value pairs
    # ARGS
    # cl              : char vector, perhaps the result of a call to commandArgs()
    # keywords        : char vector of keywords
    #                   only args of form --KEYWORD are allowed
    #                   each of these must have a value
    # allowUnexpected : logical

    InList <- function(str) {
        # is the str in the keyword char vector?
        for (keyword in keywords) {
            if (keyword == str) {
                return(TRUE)
            }
        }
        return(FALSE)
    }

    Keyword <- function(str) {
        # remove the -- prefix from a keyword argument
        result <- substr(str, 3, nchar(str))
        result
    }

    IsKeyword <- function(str) {
        # a keyword starts with '--' and is in the list of keywords
        result <- substr(str, 1, 2) == '--' & InList(Keyword(str))
        result
    }

    result <- list()
    cl.index <- 1
    while (cl.index < length(cl)) {
        possible.keyword <- cl[[cl.index]]
        if (IsKeyword(possible.keyword)) {
            value <- cl[[cl.index + 1]]
            result[[Keyword(possible.keyword)]] <- value
            cl.index <- cl.index +2
        } else if (ignoreUnexpected) {
            if (verbose) {
                cat('ignoring unexpected argument', possible.keyword, '\n')
            }
            cl.index <- cl.index + 1
        } else {
            stop(paste('unexpected argument', possible.keyword))
        }

    }
    result
}

ParseCommandLine.test <- function() {
    verbose <- FALSE
    cl <- list('--a', 'b', '--c', 'dd')
    r <- ParseCommandLine(cl, c('c'), ignoreUnexpected = TRUE, verbose = verbose)
    if (verbose) print(r)
    stopifnot(length(r) == 1)
    stopifnot(r$c == 'dd')

    r <- ParseCommandLine(cl, c('a', 'c'), ignoreUnexpected = TRUE, verbose = verbose)
    if (verbose) print(r)
    stopifnot(length(r) == 2)
    stopifnot(r$a == 'b')
    stopifnot(r$c == 'dd')
}

ParseCommandLine.test()
