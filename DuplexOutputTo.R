# DuplexOutputTo.R
DuplexOutputTo <- function(duplex.output.to=NULL) {
    # setup R's execution environment
    # ARGS: 
    # duplex.output.to : LOGI
    # RETURNS: NULL

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

        cat('duplexing output to', duplex.output.to, '\n')
    }
}
