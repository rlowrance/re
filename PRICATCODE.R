PRICATCODE <- function(code, kind) {
    # determine if PRICATCODE code has specific value
    # ARGS
    # code : integer vector
    # kind  : optional chr scalar

    with.na <- 
    switch(kind,
           arms.length.transaction      = code == 'A',
           non.arms.length.purchase     = code == 'B',
           non.arms.length.non.purchase = code == 'C',
           non.purchase                 = code == 'D',
           timeshare                    = code == 'E',
           notice.of.default            = code == 'F',
           assignment                   = code == 'G',
           release                      = code == 'H',
           # composite kinds (not directly coded)
           # catch all
           ... = stop(paste('bad kind', kind)))

    result <- ifelse(is.na(with.na), FALSE, with.na)
    result
}
