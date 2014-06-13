SCODE <- function(code, kind) {
    # determine if a sale code is a specified level, treating NA is not at level
    # ARGS
    # code  : character vector
    # kind  : chr scalar

    stopifnot(all(is.character(code)))
    with.na <- 
    switch(kind,
           confirmed            = code == 'C',
           estimated            = code == 'E',
           sale.price.full      = code == 'F',
           sale.price.partial.1 = code == 'L',
           not.of.public.record = code == 'N',
           sale.price.partial.2 = code == 'P',
           lease                = code == 'R',
           unknown              = code == 'U',
           verified             = code == 'V',
           # composite types NONE FOR NOW
           sale.price.partial   = (code == 'L') | (code == 'P'),

           # default
           ...                             = stop(sprintf('bad kind = %s', kind))
           )
    result <- ifelse(is.na(with.na), FALSE, with.na)
    result
}
