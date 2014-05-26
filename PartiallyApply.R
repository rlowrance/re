# PartiallyApply.R
# ref: rosettacode.org/wiki/Partial_function_application
PartiallyApply <- function(f, ...) {
    # If f(a, b, c, d, x, y) is defined, then
    # PartiallyApply(f, a, b, c, d) (x, y) == f(a, b, c, d, x, y)
    # so that
    #  g <- PartiallyApply(f, 1, 2, 3, 4)
    #  g(20, 30) has the same value as f(1, 2, 3, 4, 20, 30)
    capture <- list(...)
    function(...) 
        do.call(f, c(capture, list(...)))
}

PartiallyApply.Test <- function() {
    verbose <- FALSE
    #verbose <- TRUE
    test1 <- function() {
        # example from ref
        fs <- function(f, ...) sapply(list(...), f)
        f1 <- function(x) 2*x
        f2 <- function(x) x^2

        fsf1 <- PartiallyApply(fs, f1)
        if (verbose) cat('fsf1\n'); print(fsf1)
        fsf2 <- PartiallyApply(fs, f2)

        r.1 <- fsf1(0:3)
        if (verbose) cat('r.1', r.1, '\n')
        stopifnot(r.1[4] == 6)

        r.2 <- fsf2(0:3)
        if (verbose) cat('r.2', r.2, '\n')
        stopifnot(r.2[4] == 9)
    }

    test1()

    test2 <- function() {
        f <- function(what, x, y) {
            if (what == 'sum') 
                x + y
            else
                x * y
        }
        g.sum <- PartiallyApply(f, 'sum')
        g.mul <- PartiallyApply(f, 'mul')

        r.sum <- g.sum(1, 3)
        if (verbose) cat('r.sum', r.sum, '\n')
        stopifnot(r.sum == 4)

        r.mul <- g.mul(1, 3)
        if (verbose) cat('r.mul', r.mul, '\n')
        stopifnot(r.mul == 3)
    }

    invisible(test2())
}

#PartiallyApply.Test()
