DivisibleBy <- function(n, k) {
    # return TRUE iff n is exaclty divisible by k
    0 == (n %% k)   # %% is mod
}

DivisibleBy.test <- function() {
    stopifnot(DivisibleBy(2008, 4))
    stopifnot(!DivisibleBy(2009, 4))
}

DivisibleBy.test()
