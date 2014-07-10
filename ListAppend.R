ListAppend <- function(lst, obj) {
    # return new list with obj appended to lst
    lst[[(length(lst)) + 1]] <- obj
    lst
}

ListAppend.test <- function() {
    r <- ListAppend(NULL, list(a=1,b=2))
    stopifnot(length(r) == 1)
    r2 <- ListAppend(r, list(x=10,y=20))
    stopifnot(length(r2) == 2)
    stopifnot(r2[[1]]$a == 1)
    stopifnot(r2[[2]]$y == 20)
}

ListAppend.test()
