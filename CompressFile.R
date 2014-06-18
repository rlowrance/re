CompressFile <- function(old.name, new.name) {
    # compress a file using gzip
    # ARGS:
    # old.name : chr, path to old file
    # new.name : chr, path to new file
    #            if old.name == new.name then compress in place, otherwise copy
    # results: NULL
    if (old.name == new.name) {
        # compress in place
        command <- paste('gzip', '--force', control$path.out)
        system(command)
    } else {
        # make a compressed copy 
        command.1 <- paste('gzip --to-stdout', control$path.out) 
        command.2 <- paste('cat - >', paste0(control$path.out, '.gz'))
        command <- paste(command.1, '|', command.2)
        system(command)
    }
    NULL
}
