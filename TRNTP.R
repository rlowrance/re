TRNTP <- function(code, kind) {
    # determine if a transaction type code is a specified level, treating NA is not at level
    # ARGS
    # code : integer vector
    # kind  : optional chr scalar

    stopifnot(all(is.numeric(code)))
    with.na <- 
    switch(kind,
           resale            = code == 1,
           refinance         = code == 2,
           new.construction  = code == 3,
           timeshare         = code == 4,
           construction.loan = code == 6,
           seller.carryback  = code == 7,
           nominal           = code == 9,
           # composite types NONE FOR NOW

           # default
           ...                             = stop(sprintf('bad kind = %s', kind))
           )
    result <- ifelse(is.na(with.na), FALSE, with.na)
    result
}
