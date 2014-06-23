ExecutableName <- function() {
    # return name of executable (examples: 'R', 'Rscript')

    # the name of the executable is at the end of the first command argument
    command.args <- commandArgs()
    command.name.split <- strsplit(command.args[[1]], split = '/', fixed = TRUE)[[1]]
    executable.name <- command.name.split[[length(command.name.split)]]
    executable.name
}
