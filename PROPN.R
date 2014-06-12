PROPN <- function(code, kind) {
    # determine if PROPN code has specific value
    # ARGS
    # code : integer vector
    # kind  : optional chr scalar

    with.na <- 
    switch(kind,
           single.family.residence = code == 10,
           condominium             = code == 11,
           duplex                  = code == 21,  # or triple or quadplex
           apartment               = code == 22,
           hotel                   = code == 23,  # or motel
           commercial              = code == 24,
           retail                  = code == 25,
           service                 = code == 26,  # general public
           office.building         = code == 27,
           warehouse               = code == 28,
           financial.insitution    = code == 29,
           hospital                = code == 30,  # medical complex, clinic
           parking                 = code == 31,
           amusement               = code == 32,  # or recruition
           industrial              = code == 50,
           industrial.light        = code == 51,
           industrial.heavy        = code == 52,
           transport               = code == 53,
           utilities               = code == 54,
           agricultural            = code == 70,
           vacant                  = code == 80,
           exempt                  = code == 90,
           missing                 = code == 0,  # or miscellaneous or not available or none
           # composite kinds (not directly coded)
           any.residential         = code == 10 | code == 11 | code == 12 | code == 22,
           any.industrial          = code == 50 | code == 51 | code == 52,
           retail.or.service       = code == 25 | code == 26,
           ... = stop(paste('bad kind', kind)))

    result <- ifelse(is.na(with.na), FALSE, with.na)
    result
}
