# InitializeR.R
InitializeR <- function(start.JIT=FALSE, duplex.output.to=NULL) {
    # setup R's execution environment
    # ARGS: None
    # RETURNS: NULL

    options(warn=2)  # turn warnings into errors
    options(error=dump.frames)  # after a crash run command debugger()

    set.seed(1)      # random number generator seed

    if (start.JIT) {
        require('compiler')
        enableJIT(3)  # 3 ==> max JIT level
        # now sourced file are compiled with JIT enabled
    }

    if (!is.null(duplex.output.to)) {
        if (sink.number() > 0) {
            # end last diversion
            # if debugging by sourcing a script, the diversion stack can overflow
            # ending the last diversion fixes that problem
            sink(file = NULL,
                 type = 'output')   
        }

        # start new diversion
        sink(file = duplex.output.to, 
             type = 'output', 
             split = TRUE)  # send output to console and the file specified
    }
}
