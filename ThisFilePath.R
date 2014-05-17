# ThisFilePath.R
# determine path to script that was started
ThisFilePath <- function() {
    cmdArgs <- commandArgs(trailingOnly = FALSE)
    cat('cmdArgs', cmdArgs, '\n')
    needle <- '--file='
    match <- grep(needle, cmdArgs)
    if (length(match) > 0) {
        # Rscript
        sub(needle, '', cmdArgs[match])
    } else {
        # source'd via R console
        normalizePath(sys.frames()[[1]]$ofile)
    }
}
