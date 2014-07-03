# make-dependencies.R
# Program to find all *.R source files and create a makefile with dependencies
#
# Dependencies are identified through either sourceX('blah.R') or RequireX('blah') statements
# on separate lines (but without the X, written to prevent identification)
#
# invoking
# Rscript make-dependencies.R --filename DEPENDENCIES_FILE_NAME

source('Require.R')

Require('ExecutableName')
Require('InitializeR')

ParseCommandLineArguments <- function(cl) {
    # parse command line into a list with named element path.output
    # ARGS
    # cl : chr vector of arguments
    #cat('starting ParseCommandLine\n'); browser()
    result <- list()
    cl.index <- 1
    while (cl.index < length(cl)) {
        keyword <- cl[[cl.index]]
        value <- cl[[cl.index + 1]]
        if (keyword == '--filename') {
            result$filename <- value
        } else {
            # to facilite debugging via source(), allow unexpected arguments
            cat('unexpected keyword and its value skipped\n')
            cat(' keyword = ', keyword, '\n')
            cat(' value   = ', valye, '\n')
        }
        cl.index <- cl.index + 2
    }
    result
}

AugmentControlVariables <- function(control) {
    # add additional control variables to list of control variables
    #cat('starting AugmentControlVariables\n'); browser()
    result <- control
    result$me <- 'make-dependencies'

    # input/output
    result$dir.output <- '../data/v6/output/'
    result$path.out.dependencies <- paste0(control$filename)  # write to the src directory
    result$path.out.log <- paste0(result$dir.output, result$me, '-log.txt')


    # whether testing
    result$testing <- TRUE
    result$testing <- FALSE
    result
}

IsRFilename <- function(filename) {
    # return TRUE iff filename is a string of form *.R
    #cat('starting IsRFilename', filename, '\n'); browser()
    split.filename <- strsplit(filename, split = '.', fixed = TRUE)[[1]]

    if (length(split.filename) == 1) {
        # did not find a dot
        result <- FALSE
    } else {
        suffix <- split.filename[[length(split.filename)]]
        result <- suffix == 'R'
    }

    result
}

IsRFilename.test <- function() {
    stopifnot(IsRFilename('blah.R'))
    stopifnot(!IsRFilename('something.lua'))
    stopifnot(!IsRFilename('blah'))
}

IsRFilename.test()

MaybeDependency  <- function(line) {
    # if source code line contains source(...) or Require(...),
    # return the sourced or Required file name 
    # else return NULL
    #cat('starting MaybeDependency', line, '\n'); browser()

    Find <- function(pattern) {
        # return found$value and found$match
        #cat('starting Find', pattern, '\n'); browser()
        found.source <- sub(pattern = pattern,
                            replacement = '\\1',  # replace with itself
                            x = line)
        if (found.source != line) {
            # found source('blah.R')
            result <- list(value = TRUE, match = found.source)
        } else {
            result <- list(value = FALSE, match = NULL)
        }

        result
    }

    pattern.source.1 <- "^[[:blank:]]*source\\('(.*)'\\).*"
    pattern.source.2 <- '^[[:blank:]]*source\\("(.*)"\\).*'

    found.source.1 <- Find(pattern.source.1)
    if (found.source.1$value) {
        return(found.source.1$match)
    }

    found.source.2 <- Find(pattern.source.2)
    if (found.source.2$value) {
        return(found.source.2$match)
    }

    pattern.require.1 <- "^[[:blank:]]*Require\\('(.*)'\\).*"
    pattern.require.2 <- '^[[:blank:]]*Require\\("(.*)"\\).*'

    found.require.1 <- Find(pattern.require.1)
    if (found.require.1$value) {
        return(paste0(found.require.1$match, '.R'))
    }

    found.require.2 <- Find(pattern.require.2)
    if (found.require.2$value) {
        return(paste0(found.require.2$match, '.R'))
    }

    NULL
}

MaybeDependency.test <- function() {
    #cat('starting MaybeDependcy.test\n'); browser()
    r <- MaybeDependency("     # found source('blah.R')")
    stopifnot(is.null(r))

    r <- MaybeDependency("  source('abc.X') ")
    stopifnot(r == 'abc.X')

    r <- MaybeDependency('  Require("abc") ')
    stopifnot(r == 'abc.R')

    r <- MaybeDependency("")
    stopifnot(is.null(r))

    r <- MaybeDependency("abc.R")
    stopifnot(is.null(r))
}

MaybeDependency.test()

AllDependencies <- function(lines) {
    # return list of all files that are sourced are Required by the source lines
    #cat('AllDependencies', length(lines), '\n'); browser()
    maybe.dependencies <- lapply(lines, MaybeDependency)
    is.not.null <- sapply(maybe.dependencies, function(x) !is.null(x))
    actual.dependencies <- maybe.dependencies[is.not.null]
    actual.dependencies
}

AllDependencies.test <- function() {
    #cat('staring AllDependencies.test\n'); browser()
    lines <- list('abc', "source('abc.R')", 'def', 'Require("def")')
    all.dependencies <- AllDependencies(lines)
    stopifnot(length(all.dependencies) == 2)
    stopifnot(all.dependencies[[1]] == 'abc.R')
    stopifnot(all.dependencies[[2]] == 'def.R')
}

AllDependencies.test()



Main <- function(control) {
    # confine I/O to the main function
    #cat('starting Main', length(control), '\n'); browser()

    # determine names of all *.R files
    all.filenames <- list.files()
    is.r.filename <- sapply(all.filenames, IsRFilename)
    r.filenames <- all.filenames[is.r.filename]
    

    # determine dependencies in each *.R file
    dependencies <- NULL
    output.connection <- file(description = control$path.out.dependencies, 
                              open = 'w')
    FindAndSaveDependencies <- function(filename) {
        # mutate dependencies by appending a line with all the dependencies for filename
        if (FALSE && filename == 'make-dependencies.R') {
            cat('starting FindAndSaveDependencies', filename, '\n'); browser()
        }
            
        all.lines <- readLines(con = filename)
        all.dependencies <- AllDependencies(all.lines)
        if (length(all.dependencies) > 0 ) {
            #cat('found dependencies\n'); browser()
            all.dependencies.string <- paste0(all.dependencies, collapse = ' ' )
            makefile.line <- paste0(filename, ': ', all.dependencies.string)
            cat(makefile.line, '\n')
            writeLines(makefile.line,
                       con = output.connection,
                       sep = '\n')
        }
    }

    lapply(r.filenames, FindAndSaveDependencies)
    close(output.connection)
}

###############################################################################
# EXECUTION STARTS HERE
###############################################################################

#cat('starting execution\n'); browser()

# handle command line and setup control variables
executable.name <- ExecutableName()
new.command.args <-
    switch(executable.name,
           R = list('--filename', 'dependencies-in-R-sources.generated'),
           Rscript = commandArgs(),  # actual command line
           stop('unable to handle executable.name'))

# setup control variables
control <- AugmentControlVariables(ParseCommandLineArguments(new.command.args))
print('control\n')
print(control)

# initilize R
InitializeR(start.JIT = FALSE,
            duplex.output.to = control$path.out.log)


# do the work
Main(control)

cat('control variables\n')
str(control)

if (control$testing) {
    cat('DISCARD RESULTS: TESTING\n')
}

cat('done\n')
