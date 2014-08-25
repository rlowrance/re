SCODE <- function(code, kind) {
    # determine if a sale code is a specified level, treating NA is not at level
    # ARGS
    # code  : character vector
    # kind  : chr scalar

    Match <-function(code, kind) {
        with.na <- 
            switch( kind
                   ,confirmed            = code == 'C'
                   ,estimated            = code == 'E'
                   ,sale.price.full      = code == 'F'
                   ,sale.price.partial.1 = code == 'L'
                   ,not.of.public.record = code == 'N'
                   ,sale.price.partial.2 = code == 'P'
                   ,lease                = code == 'R'
                   ,unknown              = code == 'U'
                   ,verified             = code == 'V'
                   # composite types NONE FOR NOW
                   ,sale.price.partial   = (code == 'L') | (code == 'P')

                   # default
                   ,...                             = stop(sprintf('bad kind = %s', kind))
                   )
        ifelse(is.na(with.na), FALSE, with.na)
    }

    LookupCode <- function(code) {
        # lookup 1 or more codes
        LookupOneCode <- function(one.code) {
            switch( one.code
                   ,'C' = 'confirmed'
                   ,'E' = 'estimated'
                   ,'F' = 'sale.price.full'
                   ,'L' = 'sale.price.partial.1'
                   ,'N' = 'not.of.public.record'
                   ,'P' = 'sale.price.partial.2'
                   ,'R' = 'lease'
                   ,'U' = 'unknown'
                   ,'V' = 'verified'
                   ,'L' = 'sale.price.partial'
                   ,'P' = 'sale.price.partial'
                   ,'unknown code'
                   )
        }
        if (length(code) == 1) LookupOneCode(code) else sapply(code, LookupOneCode)
    }

    stopifnot(all(is.character(code)))
    
    #cat('start SCODE\n'); browser()
    result <- 
        if (hasArg('code') && hasArg('kind')) 
            Match(code, kind)
        else if (hasArg('code'))
            LookupCode(code)
        else
            stop('bad call')
    result
}
