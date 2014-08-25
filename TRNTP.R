TRNTP <- function(code, kind) {
    # determine if a transaction type code is a specified level, treating NA is not at level
    # ARGS
    # code : integer vector
    # kind  : optional chr scalar

    Match <- function(code, kind) {
        with.na <- 
            switch( kind
                   ,resale            = code == 1
                   ,refinance         = code == 2
                   ,new.construction  = code == 3
                   ,timeshare         = code == 4
                   ,construction.loan = code == 6
                   ,seller.carryback  = code == 7
                   ,nominal           = code == 9
                   # composite types NONE FOR NOW

                   # default
                   ,...                             = stop(sprintf('bad kind = %s', kind))
                   )
        ifelse(is.na(with.na), FALSE, with.na)
    }

    LookupCode <- function(code) {
        # lookup one or more codes
        OneCode <- function(one.code) {
            if (1 <= one.code && one.code <= 9)  {
                switch( one.code
                       ,'resale'            # 1
                       ,'refinance'         # 2
                       ,'new.construction'  # 3
                       ,'timeshare'         # 4
                       ,'unknown code'
                       ,'construction.loan' # 6
                       ,'seller.caryback'   # 7
                       ,'unknown code'
                       ,'nominal'           # 9
                       )
            } else {
                'unknown code'
            }
        }
        if (length(code) == 1) OneCode(code) else sapply(code, OneCode)
    }

    stopifnot(all(is.numeric(code)))

    result <- 
        if (hasArg('code') && hasArg('kind')) 
            Match(code, kind)
        else if (hasArg('code'))
            LookupCode(code)
        else
            stop('bad call')
    result
}
