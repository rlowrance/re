# knn.R
# copied from
# http://tolstoy.newcastle.edu.au/R/help/04/02/0089.html

require (class) 
nearest <- function (X, n, k=3) 
## Find k nearest neighbors of X[n, ] in the data frame 
## or matrix X, utilizing function knn1 k-times. 
{ 
    N <- nrow(X) 
    # inds contains the indices of nearest neighbors 
    inds <- c(n); i <- 0 
    while (i < k) { 
        # use knn1 for one index... 
        j <- as.integer(knn1(X [-inds, ], X[n, ], 1:(N-length(inds)))) 
        # ...and change to true index of neighbor 
        inds <- c(inds, setdiff(1:N, inds)[j]) 
        i <- i+1 
    } 
    # return nearest neighbor indices (without n, of course) 
    return(inds[-1]) 
} 