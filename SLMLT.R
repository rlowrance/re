SLMLT <- function(code, kind) {
    # determine if a multi-apn flag code is a specified level, treating NA as not at level
    # ARGS
    # code  : character vector
    # kind  : chr scalar

    stopifnot(all(is.character(code)))

    with.na <- 
    switch(kind,
           detail.parcel.sale   = code == 'D',
           multiple.parcel.sale = code == 'M',
           split.parcel.sale    = code == 'S',
           multi.county         = code == 'X',
           # composite types NONE FOR NOW

           # default
           ...                             = stop(sprintf('bad kind = %s', kind))
           )
    result <- ifelse(is.na(with.na), FALSE, with.na)
    result
}
