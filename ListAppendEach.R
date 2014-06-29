ListAppendEach <- function(x, values) {
    # append named elements in values to named elements in x
    # example: ListAppendEach(NULL, list(a=1,b=2)) --> list(a=1,b=2)
    # example: ListAppendEach(list(a=1,b=2), list(a=10,b=20)) --> list(a=list(1,10), b=list(2,20))
    if (is.null(x)) {
        values
    } else {
        for (name in names(values)) {
            x[[name]] <- append(x[[name]], values[[name]])
        }
        x
    }
}

ListAppendEach.test <- function() {
    x <- NULL
    v1 <- list(a=1, b=2)
    v2 <- list(a=10, b=20)
    xx <- ListAppendEach(ListAppendEach(x, v1), v2)
    n <- names(xx)
    stopifnot(n[1] == 'a')
    stopifnot(n[2] == 'b')
    stopifnot(length(xx$a) == 2)
    stopifnot(length(xx$b) == 2)
}

ListAppendEach.test()
