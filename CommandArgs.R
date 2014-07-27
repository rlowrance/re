CommandArgs <- function(defaultArgs, verbose = TRUE) {
    # return command args if present, otherwise return defaultArg
    command.args <- commandArgs()
    for (command.arg in command.args) {
        if (command.arg == '--args') {
            # this happens if started with Rscript and arguments are supplied
            if (verbose) {
                print('CommandArgs returning actual args, which are')
                print(command.args)
            }
            return(command.args)
        }
    }

    if (verbose) {
        print('CommandArgs returning defaultArgs, which are')
        print(defaultArgs)
    }
    return(defaultArgs)
}
