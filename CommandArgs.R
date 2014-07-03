CommandArgs <- function(ifR) {
    # if started from R, return command args in argument ifR
    # otherwise (if started from Rscript), return command args from command line
    Require('ExecutableName')
    if (ExecutableName() == 'R') {
        result <- ifR
    } else {
        result <- commandArgs()
    }
    result
}
