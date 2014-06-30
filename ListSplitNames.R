ListSplitNames <- function(alist) {
    # convert alist[[i]]$name1, $name2 to $name1=, $name2=

    result <- NULL
    for (name in names(alist[[1]])) {
        result[[name]] <- sapply(alist, function(x) x[[name]])
    }
    result
}

ListSplitNames.test <- function() {
    verbose <- TRUE
    lst <- list(list(a = 1, b = 10),
                list(a = 2, b = 20),
                list(a = 3, b = 30))
    print(lst)
    r <- ListSplitNames(lst)
    print(r)
    stopifnot(length(r) == 2)
    stopifnot(r$a[[1]] == 1)
    stopifnot(r$b[[3]] == 30)
}

ListSplitNames.test()
