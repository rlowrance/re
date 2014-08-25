DEEDC <- function(code, kind) {
    # determine if a DEEDC code is a specified level, treating NA is not at level
    # ARGS
    # code : integer vector
    # kind  : optional chr scalar


    # definitions:
    # promissory note := obligation to the bank to pay back the money with interest
    # mortgage        := collateral for a promissory note

    # typical foreclosure processs
    # 1. Bank lends money using a promissory note with the collateral provided by a mortgage.
    # 2. Borrows fails to pay promissory note on time (called "default").
    # 3. Bank files 3 documents with the court.
    #    a: A Complaint: a suit (an ation) on the non-payment of the promissory note
    #    b: A Summons: directs borrower to answer the complaint
    #    c: A Lis Pendens: notice to public that there is a claim on the property in the mortgage
    # 4. The bank wins and the court issues a final judgement of foreclosure. The final judgement
    #    says that if the note is not repaid in say 30 days, the clerk of the court will sell the
    #    property to the highest bidder. If the amount received is less than what is due, the bank
    #    can return to the court to request a deficiency judgement. The bank usually bids on the
    #    house in order to protects its collateral. It will bid up to the amount of the 
    #    judgement it was awarded. Often the bank buys the house for $100.
    # 5. The bank obtains a deficiency judgement based on the appraised value of the property
    #    on the day of the foreclosure sale.

    result <-
    if (hasArg('kind')) {
        with.na <- 
            switch( kind
                   ,construction.loan               = code == 'C'
                   ,correction.deed                 = code == 'CD'  # coorects a previous mistake
                   ,final.judgement                 = code == 'F'   # the bank has won its case
                   ,grant.deed                      = code == 'G'   # sale or transfer
                   ,lis.pendens                     = code == 'L'   # notify public of claim against the property
                   ,notice.of.default               = code == 'N'
                   ,quit.claim                      = code == 'Q'   # disdain any interest in a property
                   ,release                         = code == 'R'   # release a lien on a property
                   ,loan.assignment                 = code == 'S'   # transfers lien to a new lender
                   ,deed.of.trust                   = code == 'T'   # gives mortgage lender a lien on a property
                   ,foreclosure                     = code == 'U'   # grants ownership to the purchaser at a 
                   # foreclosure sale
                   ,multi.cnty.or.open.end.mortgage = code == 'X'
                   ,nominal                         = code == 'Z'
                   # composite types NONE FOR NOW

                   # default
                   ,...                             = stop(sprintf('bad kind = %s', kind))
                   )
        ifelse(is.na(with.na), FALSE, with.na)
    } else if (hasArg('code')) {
        #cat('in DEEDC\n'); browser()
        OneCode <- function(one.code) {
            #cat('start OneCode\n'); browser()
            switch( one.code
                   ,'C'   = 'construction.loan'
                   ,'CD'  = 'correction.deed'
                   ,'F'   = 'final.judgement'
                   ,'G'   = 'grant.deed'
                   ,'L'   = 'lis.pendens'
                   ,'N'   = 'notice.of.default'
                   ,'Q'   = 'quit.claim'
                   ,'R'   = 'release'
                   ,'S'   = 'loan.assignment'
                   ,'T'   = 'deed.of.trust'
                   ,'U'   = 'foreclosure'
                   ,'X'   = 'multi.city.or.open.end.mortgage'
                   ,'Z'   = 'nominal'
                   ,'unknown code'
                   )
        }
        result <- if (length(code) == 1) OneCode(code) else sapply(code, OneCode)
        result
    } else {
        stop('bad call')
    }


    result
}
