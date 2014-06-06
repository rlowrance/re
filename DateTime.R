DateTime <- function(basename) {
    # date.time as a string
    date.time <- strsplit(as.character(Sys.time()), split = ' ', fixed=TRUE)
    paste0(date.time[[1]][[1]], '.', date.time[[1]][[2]])
}
