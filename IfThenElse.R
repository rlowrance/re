IfThenElse <- function(bool, value1, value2) {
    # evaluate and return either value1 or value2
    if (bool) {
        value1
    }
    else {
        value2
    }
}

IfThenElse.test <- function() {
    # unit test
    r <- IfThenElse(TRUE, 1, 2)
    stopifnot(r == 1)

    r <- IfThenElse(FALSE, 1, 2)
    stopifnot(r == 2)

    all <- NULL
    some <- data.frame(x = 1)
    all <- IfThenElse(is.null(all), some, rbind(all, some))
    stopifnot(!is.null(all))
    stopifnot(nrow(all) == 1)

    some <- data.frame(x = 2)
    all <- IfThenElse(is.null(all), some, rbind(all, some))
    stopifnot(!is.null(all))
    stopifnot(nrow(all) == 2)
}

IfThenElse.test()
