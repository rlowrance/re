Require <- function(functionName) {
    # source a file if a function is not defined
    # ex: Require('Myfunction') --> source('Myfunction.R') if !exists(Myfunction, mode = 'function')
    if (!exists(functionName, mode = 'function')) {
        source(paste0(functionName, '.R'))
    }
}
